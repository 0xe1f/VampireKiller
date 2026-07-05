# Vampire Killer — gameplay notes

Reverse-engineering reference. These are observed/known behaviours of the game,
used to name routines, states and data as the disassembly progresses. Anything
not yet confirmed in code is marked *(unconfirmed)*.

## Boot / attract flow

1. **Konami logo** on a white background.
2. **Title screen.**
3. If the player presses **space** (joystick trigger also supported *(unconfirmed)*),
   the game starts. Otherwise a short **attract-mode demo** plays, then loops back
   to the title.
4. Game start plays an **intro animation**: Simon arriving at the castle.
5. Play proceeds through the **courtyard**, then the **castle interior**.

## Levels / bosses

- Roughly every third level ends in a **boss battle** *(exact cadence unconfirmed)*.
- Boss order:
  1. Giant bat
  2. Medusa
  3. Mummies
  4. Frankenstein's monster
  5. Grim reaper
  6. Dracula
- When a boss dies an **orb descends**:
  - Pick it up → **life refills** and advance to the next level.
  - Leave it → still advance, but **life is not refilled**.

## World structure (hubs / stages / rooms)

The world is a hierarchy: **hub → stage → room**.

- **Hubs** — a hub is a themed area of ~3 stages ending in a boss. Stages in a hub
  mostly share an aesthetic: **tile set** and **enemy set** (though some enemies are
  common enough to be reused across hubs). This is the level of the boss cadence in
  *Levels / bosses* above.
- **Stages** — a stage is a set of connected rooms, usually ending in a **door**.
  Exiting the door requires a **large white key** (see below); without it Simon
  can't leave the stage. Exception: the **courtyard** has an open doorway (no door,
  no key needed).
- **Rooms** — MSX has no smooth hardware scrolling, so (like most MSX games) VK does
  **not scroll**; the world is split into single-screen rooms. Transitions:
  - **Walk off** a screen edge that has no wall → adjacent room.
  - **Diagonal staircase** → climb into another room.
  - **Drop down** → fall into the room below (if one exists). Rooms on the lowest
    level have nothing below → **dropping is instant death**.

### Keys, doors, chests, destructibles

- **Large white key** — one per stage, needed to open the stage-exit **door**. Keys
  are deliberately **hidden / awkward to reach**: behind walls, or requiring a tricky
  jump. *Runtime:* held as **0xC701 bit 0**. Entering a white-key door runs the
  handler at **seg0 0x438B**, which spends the key (`and 0FEh` → clears bit 0) and
  falls into **advance_stage** (0x434E): stage id **0xD000 ++**, room id **0xD001 =
  0** (confirmed stage1/room7 → stage2/room0).
- **Destructible walls** — some walls can be destroyed; a destroyed wall **sometimes
  reveals a bonus**, including keys.
- **Small yellow key** — unlocks a **chest** (chests hold bonuses; a chest can't be
  opened without one). Simon can carry **only 1** yellow key at a time. *Runtime:*
  the yellow key is **bonus id 0x17 (23)**; picking it up (from the 0xC500 pickup
  list) sets **0xC701 bit 1** (white key = bit 0) and **0xC700 = 1** (the key/staff
  charge count). Opening a chest consumes it: **0xC701 bit 1 cleared, 0xC700 -> 0**;
  the chest's reward latches as its own bonus id (observed **0x13 / 19** once) and
  spawns into the object (0xC490) + pickup (0xC500) lists.
- **Staff** — an alternative to the yellow key: a staff opens **3 chests** before it
  disappears (expected to seed **0xC700 = 3** instead of 1 — unconfirmed).

*Reversing hooks:* expect per-stage state for **key held (white / yellow / staff
charges)**, **door locked/unlocked**, **chest opened** flags, and a **room/stage/hub
index** driving which tile set + enemy set + room layout loads. Destructible-wall and
chest contents are likely table-driven per room. Instant-death-on-drop implies a
"no room below" check in the fall/room-transition code.

*CONFIRMED (runtime + static, see progress.md "Eighth session"):* the hub/stage/room
index is a RAM trio:
- **0xD002 = hub** (6 hubs, 0-5) - selects the packed object dataset in seg14
  (pointer table @ 0x8668); chosen from the stage via the seg0 0x5E71 table which
  groups stages in 3s (so ~3 stages per hub, matching the design).
- **0xD000 = stage** (0 = courtyard, 1-18 = the 18 stages).
- **0xD001 = room** within the stage (increments walking right).
Each hub's data holds 3 stages x up to 16 rooms x up to 4 objects; per object,
id bit7 = scenery flag, low 7 bits = sprite id, and one attr byte packs the in-room
cell position (hi nibble X, lo nibble Y, each *16 px). Stage 0 (courtyard) has no
object-list entries. `tools/roommap.py` decodes and renders all of this
(`gfx/map_*.png`). NOTE this is the object LAYOUT only - the visible wall/floor
geometry is separate per-room RLE bitmap data, and room-to-room connectivity
(stairs/drops/key-doors) lives in the still-INCBIN seg13 transition code (0xB98A).

## Player (Simon)

### Movement / action states (RAM 0xC420, runtime-confirmed)

`0xC420` is Simon's action state; `simon_action_tick` (seg1 0x6B40) dispatches an
8-entry handler table by it. Confirmed values:

| 0xC420 | handler | meaning |
| --- | --- | --- |
| 0 | 0x6B59 | grounded (walk / idle). Whipping does **not** change this byte. |
| 1 | 0x6CC7 | **jump / airborne** (Y arc 0xC0→0xA0→0xC0; X free for directional jumps) |
| 2 | 0x6DB0 | **crouch** (DOWN held; Simon X is locked — cannot move) |
| 3 | 0x6DE4 | **on stairs / climbing** (diagonal travel; can whip while climbing) |
| 4 | 0x6F44 | **falling / dropping** off a ledge |
| 5 | 0x6F8C | hurt / knockback (shallow airborne launch — not a jump) |
| 6 | 0x709A | dying / respawn (enemy spawner is suppressed while ==6) |
| 7 | 0x7102 | unconfirmed |

`0xC423` tracks the air sub-phase during jumps/falls (e.g. 2→1 rising→falling).

### Score (RAM 0xC405–0xC407)

Score is a **3-byte packed BCD** counter, little-endian: `0xC405` = low pair,
`0xC406` = mid pair (hundreds/thousands — the main visible byte), `0xC407` = high
pair. The on-screen number strips leading zeros (e.g. `00 82 00` → "8200"). Awards
are always multiples of 100. Written by `add_score` (seg0 0x44F5), which takes the
amount in `C:D:E` (hi:mid:lo BCD pairs) and adds it with `daa`; enemy kills go
through `award_kill_score` (seg2 0x81B2, per-type value table). Observed values:
**chest = +5400**, whipping a candle/destructible = **+100**, heart pickup = **+0**.
When investigating any pickup/attack, diff `0xC405–0xC407` to see its point value.

### Damage (taken and dealt)

HP bars are `0xC415` = **Simon health** (full `0x20` = 32) and `0xC418` = the
on-screen **ENEMY/BOSS energy** (full `0x80`, used by HP-bar enemies, types ≥ 0x11).

**Simon takes damage** (both floor at 0 via `damage_health`, seg0 0x4632):
- **Enemy contact** — `hurt_simon_contact` (seg2 0x8173). Damage = `2 ×` the *odd*
  byte of the enemy type's `l81d5h` entry. Confirmed: zombie = **2**, dog = **6**.
  A raised shield (`0xC701` bit 4) halves it and spends a shield charge (`0xC441`);
  when charges run out the shield drops.
- **Hazard / enemy projectile** — `hurt_simon_projectile` (seg2 0x85AD). Fixed
  **8**, or **16** if the slot's flag bit is set. Also forces the hurt state
  (`0xC420 = 5`). Ignored during i-frame/freeze timers (`0xC42D`, `0xC43A`).

**Simon deals damage** to HP-bar enemies via `weapon_hit_damage` (seg1 0x7E33) →
`damage_enemy` (seg0 0x4643, `0xC418 -= B`). B comes from a per-weapon table indexed
by `(enemy type − 0x11)`:
- leather whip / knife → base `04 08 08 04 04 04 10` (types 0x11..0x17)
- chain / cross / axe → strong `06 0C 0C 06 06 06 18` (≈1.5×)
- vs type 0x17 with weapon ≥ 2 the hit is quartered.

Lesser enemies (type < 0x11) have no HP bar and die on the first successful hit.

### Equippable weapons (strength tiers, per design)

- **lowest**: leather whip, thrown knife
- **normal**: chain whip, boomerang cross
- **strong**: boomerang axe

Weapon behaviour specifics:
- **Whips** (leather, chain) stay with Simon - not thrown.
- **Boomerang cross** flies across the whole room damaging enemies it passes, then
  returns to Simon. If Simon is not in its return path it is LOST and the leather
  whip is re-equipped.
- **Boomerang axe** reaches ~half the room, same catch-or-lose rule as the cross.
- **Thrown knife** has unlimited ammo.

### Weapon state (RAM - runtime + static confirmed)

- **0xC416 = equipped weapon id.** Confirmed: **0 = leather whip, 1 = chain whip**
  (runtime: picking up the chain whip flipped 0xC416 0 -> 1). Weapons 0 and 1 take
  the **whip attack path** (seg1 ~0x7D80: `ld a,(0c416h) / cp 002h / jr nc` -> whip
  if <2), weapons **>= 2 take the projectile path** (thrown knife / cross / axe).
  Exact ids for knife/cross/axe still to confirm by recording each (hypothesis:
  2 = knife, 3 = cross, 4 = axe).
- **Weapon pickups arrive via collect_bonus (seg2 0x8D33) with bonus id >= 0x1A**:
  the fallthrough `l8d77h` does `sub 0x19` and stores the result in 0xC416, so
  weapon id = bonus id - 0x19 (chain whip = bonus 0x1A -> weapon 1, confirmed).
- **Damage table split** (seg1 `sub_7e33h` 0x7E33): weapon 0 (leather) and weapon 2
  use the base damage table `l7e60h`; other weapons use the stronger table at
  0x7E67 - consistent with the strength tiers. Damage is indexed by enemy type
  (type-0x11); enemy type 0x17 halves projectile damage twice. (Full table values
  TBD.)
- On death / per-life reset (seg1 sub_70e3h) and room entry, 0xC416 is cleared to 0
  (back to the leather whip).

Other pickups replace the weapon:

- Chain whip (upgraded whip)
- Throwable axe
- Throwable cross
- Knives

Sub-items / consumables:

- **Hourglass** — pauses/freezes the game.
- **Holy water** — thrown, high damage.
- **Shields** — two types: one absorbs damage, one reflects it.
- **Rosaries** — a **temporary "no new enemies" power-up** (two types). NOT a
  weapon and NOT a persistent inventory item. Runtime (frame 493): collected as a
  normal 0xC500 pickup (its 0x84 slot cleared), bonus id **0x06** latched to 0xC419.
  Static trace of the effect (confirmed, immediate, not next-room):
    - Handler `collect_bonus[6]` (seg2 **0x8D83**) arms a countdown timer at
      **0xC440** to **0xF0** (240 frames ≈ 4 s) or **0x96** (150 frames ≈ 2.5 s),
      selected by 0xC431 bit 2 (likely the two-rosary difference). It does NOT touch
      0xC700-0xC70F inventory or the 0xC416 weapon (hence "temporary"). The weapon
      pickup path (`l8d77h`, bonus >= 0x1A) falls straight through into this same
      code, so grabbing a whip upgrade also arms a short no-spawn window.
    - 0xC440 is a per-frame countdown: `sub_75c7h` (seg1) decrements it each frame in
      the timer bank (`sub_7682h/75c7/75e9/...`).
    - The enemy spawner (seg0 **room_spawner @0x5EBF**) is called every frame from the
      actor-update loop (seg2 0x98F0) whenever 0xD010==0 (normal play). Its first act
      is `ld a,(0c440h) / and a / ret nz` -> while the rosary timer is nonzero it
      spawns nothing. When 0==C440, it reads the per-(stage 0xD000, room 0xD001)
      descriptor via seg14 table 0x85A6 and calls spawn generators (0x9CED, 0x9D52,
      ...) that place actors via spawn_actor into the 0xC800 slots.
    - **Effect is immediate and current-room** (the gate is checked per frame in
      whatever room you're in), not deferred to the next room. It only suppresses
      *new* spawns; enemies already in the 0xC800 slots are untouched.
  - NOTE: 0xC5E5/0xC5E6 (00->FF/20 at pickup) is the generic pickup-popup message +
    timer set by 0x8F2A for *every* pickup, NOT a rosary-specific state.
  - Still TODO: confirm which of the two rosary types this is and the second's bonus id.
- **Hearts** — currency for vendors; also power the hourglass / holy water
  activation *(the heart↔sub-weapon coupling is unconfirmed)*.
- **Life refills** — small orbs during play, or **vials** bought from vendors.

### Vendors (runtime-confirmed, seg2 @ 0x92AE–0x9552)

A vendor is a hidden "cloaked sitting person" revealed by whipping a wall. He is
**not** a normal 0xC800 actor — he lives in the special-object list at 0xC5B5
(2 slots of 0x10 bytes) and keeps his transaction state in the 0xC700 block:

| Addr   | Meaning |
|--------|---------|
| 0xC702 | bible price-modifier flags: bit6 = **black bible** (id 0x10, doubles price), bit7 = **white bible** (id 0x11, halves). Mutually exclusive — each bible clears the other's bit. Set by the collect_bonus handlers at 0x8E24 / 0x8E2D; cleared on reset. |
| 0xC703 | latched vendor object id |
| 0xC704/5 | vendor on-screen position |
| 0xC706 | **offer countdown timer** (armed to 0x14 = 20; ticks every 0x20 frames) |
| 0xC707 | **price in hearts** (packed BCD, e.g. 0x50 = 50) |
| 0xC708 | **offered item** = bonus id (0x1B = knife) |
| 0xC709 | previous button state (edge detection for buy/refuse) |
| 0xC70B | reaction/animation id (from state via table 0x9327) |
| 0xC70C | **whip-outcome state** (0..6) driving the dispatch |
| 0xD012 | persistent vendor "mood" tier (0..3), raised/lowered by whips |

**Whipping the vendor** runs a small state machine. Each hit calls
`vendor_pick_outcome` (0x92C2): it walks a transition table (0x9307, 8-byte rows
selected by the vendor variant), and for the "random" states (≥7) flips a coin
using the Z80 **R refresh register** as an RNG — this is why the same actions
produce different results run to run. The resulting state 0xC70C is executed by
`vendor_outcome_dispatch` (0x92AE):

| 0xC70C | Outcome |
|--------|---------|
| 0 | register the hit (set 0xC40C, latch vendor id) |
| 1 | raise mood 0xD012 (cap 3) |
| 2 | lower mood 0xD012 (floor 0) |
| 3 | **give Simon +5 hearts** (sfx 0x0F) |
| 4 | **take 5 hearts from Simon** (sfx 0x1D) |
| 5 | **nothing** (points at a bare `ret`) |
| 6 | **vendor leaves** (sfx 0x10, then **awards +5000 points**) |

So the full spectrum a player sees while whipping: hearts added, hearts removed,
nothing, an offer appears, or he leaves. Score only changes on **departure**
(+5000 via `ld de,0x5000 / jp 0x44F3` → `add_score`); individual whips do not add
score (a whip that "does nothing" is outcome 5).

**Making / taking an offer** (`vendor_make_offer` 0x938E, reached from the reveal
path): picks the item (`vendor_set_offer_item` 0x9406 → 0xC708) and its price, and
starts the 0xC706 timer. Price comes from `vendor_price_tbl` (0x942F), 9 rows of
`{item id, normal, halved, doubled}`; `vendor_select_price` (0x941F) picks the
column from the 0xC702 bible flags:

| Item (bonus id) | normal | white bible (½) | black bible (×2) |
|-----------------|--------|-----------------|------------------|
| 0x1B (knife)    | 50     | 30              | 90               |
| 0x0E            | 20     | 15              | 60               |
| 0x12            | 30     | 20              | 60               |
| 0x03            | 20     | 10              | 60               |
| 0x04            | 20     | 10              | 80               |
| 0x0A            | 40     | 20              | 80               |
| 0x16            | 40     | 15              | 80               |
| 0x1E            | 30     | 10              | 50               |
| 0x1D            | 20     | 10              | 80               |

While an offer is on screen, `vendor_purchase_tick` (0x94BE) counts the 0xC706
timer down and polls the controls via `vendor_read_buttons` (0x9526, joystick
triggers + keyboard **SPACE row 8 = confirm**, **SHIFT row 6 = refuse**,
edge-detected through 0xC709):

- **SPACE / trigger** and hearts ≥ price → deduct the price (`spend_hearts`) and
  grant the item (`collect_bonus`), sfx 0x12.
- **SHIFT / refuse**, can't afford, or timer expires → offer withdrawn, sfx 0x02.
- nothing pressed → offer stays open.

## Text encoding (CRACKED + converted to ASCII)

DONE: added a `vk()` helper (sjasmplus Lua, in VampireKiller.asm) so text is now
authored as readable ASCII and still assembles byte-exact. Usage:
`LUA ALLPASS vk({0x48,0xA0,"PUSH SPACE KEY",0xFF}) ENDLUA`
- a Lua string -> each char as (char-0x10); a space -> 0x00 (blank tile)
- a Lua number -> emitted verbatim (VDP position/attr, 0xFE field sep, 0xFF end)
The HUD set (`l4c07h`) and title/front-end strings (`l4d0fh`,`l4d30h`,`l4d41h`)
in seg00 are converted. NOTE: every vk-emitting LUA block MUST use `LUA ALLPASS`
(plain `LUA` emits only on the last pass -> label drift -> wrong bytes).
Still-as-data-misdisassembled: 0x4C3F-0x4D0E (tile-layout, marked with a comment;
convert to `db` later).

## Sprites (format understood; data still in banked ROM)

- VK uses MSX2 hardware sprites; seg00 sets VDP regs (see `sub_47d6`/`sub_481bh`)
  and the title builder loads graphics from pointers into the 0x8000-0xBFFF banks
  (e.g. `ld hl,0x930b` / `0xb70b` at 0x4557/0x4562) - so sprite/tile BITMAPS live
  in the graphics segments (4-15), not seg00.
- Konami actor/OBJ struct (from Metal Gear `constants/structures.asm`) is the
  template for VK's ix-based entity record (entity dispatch at 0x5FD0): fields
  like ID/Status/Y/X/Speed/SpriteId/ANIM/LIFE/Direction + trailing per-sprite
  sub-records (Spr*Layer/Y/X/Pattern/Color). VK entity uses ix offsets up to
  ~0x7f, so its record is similarly large.
- NEXT for sprites: disassemble a graphics bank, locate the sprite pattern
  generator data, and emit it as 32-byte (16x16) pattern arrays (optionally in
  binary rows) for easy editing - mirroring MG's `gfx/sprites.asm` layout.

### Text encoding details

Text is stored as **tile codes = ASCII - 0x10** (so decode with `+0x10`).
Cross-checked against the Metal Gear disassembly (which stores text as plain
ASCII); Vampire Killer offsets that by 0x10 because its font is loaded into VRAM
starting at tile 0x10. Digits '0'-'9' = tiles 0x20-0x29 (confirmed by the score
renderer `sub_458fh`: `and 0x0F / add 0x20`). `0x00` = space/blank tile between
words; `0xFE` and `0xFF` are line/record control bytes; other high bytes
(0x48,0xA0,0x58,0xD1...) are VDP position/attribute prefixes.

### Front-end / HUD strings found in segment 0 (runtime addresses)
- 0x4C09 `SCORE`, 0x4C11 `PLAYER`, 0x4C19 `<icon>ENEMY`, 0x4C2D `STAGE`
- 0x4C3F-0x4D08: tile-layout / logo arrangement data (NOT text)
- 0x4D13 `KONAMI`, 0x4D1A `1986`
- 0x4D21 `PUSH`, 0x4D26 `SPACE`, 0x4D2C `KEY`
- 0x4D34 `PLAY`, 0x4D39 `START`
- 0x4D43 `GAME`, 0x4D49 `OVER`
Data region is `l4c07h` .. 0x4D4D (right before `sub_4d4eh`, the title builder).
`0x4C00-0x4C06` is real code (a keyboard-read routine).

TODO (next session): add an sjasmplus macro to author these as readable ASCII
(emit char-0x10) and convert the region to a data block byte-exactly; mark
`l4c07h..0x4D4D` in segments/seg00.blocks as data.

## Code layout & where the "main loop" is

There is no classic `while(1)` loop. Boot parks the CPU in a spin (`jr $` at
0x40C3); everything runs off the 60 Hz timer interrupt `H.TIMI` -> `int_handler`
(0x4028), which each frame calls the game tick `sub_414dh`. That tick is the
master state machine (primary state 0xC000 -> `main_state_tbl`).

Segment 0 is the resident **kernel/orchestrator** only: interrupt handler, frame
tick + state dispatch, graphics/RLE loaders, bank switching, and the
entity-dispatch shell at 0x5FD0. All 14 `main_state_tbl` handlers live in seg0
(0x417D-0x441B) but are thin - they call out into banked ROM:
- state 0 (logo): `call 0x6253`   state 3 (in-game): `call 0x63DA`
- per-entity behaviour (player/enemy AI) via `entity_tbl` -> 0xA000+

During normal play the default banks (set by `sub_533dh`) are seg 1 @ 0x6000,
seg 2 @ 0x8000, seg 3 @ 0xA000. So the substantive gameplay (movement, AI,
collision, item logic) lives in **code segments 1/2/3**, still `INCBIN`'d and not
yet disassembled - that's the next disassembly target, followed from seg0's
state handlers and `entity_tbl`.

## Graphics format (sprite/tile hunt)

Video mode is **SCREEN 5** (VDP mode G4: 256x212, 16 colours, 4 bits/pixel
bitmap). Set in `sub_4b60h`: `ld a,5 / call CHGMOD (0x005f)`. Consequences:

- Backgrounds/tiles/logos are stored as **4bpp bitmap data** (high nibble = left
  pixel, colour index 0-15, colour 0 = transparent/background). They are copied
  to VRAM with the **VDP command engine** (`out (c)` streams to R17-indirect +
  the command registers) via `sub_48e3h`, `l4911h`, and helpers `sub_48fdh` /
  `sub_4907h` / `sub_487ch` / `sub_485ch` - NOT as 1bpp pattern tables.
- Actors (Simon, enemies, items) are drawn with **hardware sprites** (mode 2,
  16x16, **1bpp** patterns). A multicolour character is built from several 1bpp
  planes the VDP OR-combines (the `CC` bit, 0x40, in the sprite colour byte);
  the sprite attribute table is assembled by `sub_554fh` (nested 4x4 loops
  writing 4-byte OAM records via `sub_4a58h`), so large characters are grids of
  hardware sprites. Only the background is 4bpp - the sprites are never 4bpp.
  Evidence: seg13/0xA319 patterns alternate sparse/dense pixel counts
  (52,164, 49,145, ...), each sparse plane nearly a subset of the next dense
  one - so `intro_simon` is 8 two-plane sprites, not 16 frames. The
  catalogue's `planes` column composites planes in the `.png` preview while the
  `.txt`/`.bin` keep each plane separate for editing.

Bank classification (by entropy / zero-fill, `tools/gfxview.py` + a quick scan):
- **seg 0-3**: code (entropy ~7, top byte 0xCD/0xC4/0xDD opcodes).
- **seg 4-9, 15**: 4bpp bitmap graphics (low entropy 4.3-5.5, zero-heavy, a
  single dominant background colour). These hold the title logo, HUD, stage and
  actor artwork.
- **seg 10-14**: mixed code + data tables.

Title graphics load (`sub_454ch`, called from the title builder): copies from
ROM `0x7F0B`, `0x930B`, `0xB70B` (banked pages 1b/2a/2b) to VRAM `0x1212`,
`0x2212`, `0x4212` with `c` = block count via `sub_48e3h`.

### Graphics are RLE-compressed (format cracked)

Graphics ROM data is **not** raw pixels - it is packed with a small RLE scheme
and unpacked straight into VRAM by the decompressor `sub_46f8h` / `l46f2h`
(0x46F2). `sub_46b6h` sets the VRAM write pointer from HL; the stream is then
streamed to data port 0x98. Control-byte grammar:

| byte        | meaning                                        |
|-------------|------------------------------------------------|
| `0x00`      | end of stream                                  |
| `0x80 lo hi`| set VRAM write pointer = `hi<<8 | lo`           |
| `0x01..0x7F`| RUN: repeat the next single byte N times       |
| `0x81..0xFF`| LITERAL: copy `N & 0x7F` bytes verbatim         |

Callers pass `HL` = VRAM dest, `DE` = ROM source, e.g. (segment 0, ~0x5688):

```
call sub_5369h            ; page seg 13 into 0xA000-0xBFFF
ld hl,0f800h ; ld de,0a319h ; call sub_46f8h   ; -> sprite pattern gen table
ld hl,0f840h ; ld de,0a351h ; call sub_46f8h   ; next 2 sprites ...
```

`0xF800` = VRAM page 1, offset `0x7800` = the **sprite pattern generator table**
(SCREEN 5, sprite mode 2). Each stream unpacks 64 bytes = **two 16x16 sprites**
(32 bytes each). The 8-call block at 0x5688 fills 0xF800-0xFA00 = 16 sprites
(one actor's animation set). Confirmed by decompressing and rendering: clean
walking-creature frames.

### Bank switching for graphics loads

Konami mapper windows: writes to `0x6000`/`0x8000`/`0xA000` select the segment
paged into page 1b / 2a / 2b. Helper routines (each also shadows the value at
0xF0F1-0xF0F3 for int_handler to restore):
- `sub_5369h` -> seg 11 @ 0x6000, seg 12 @ 0x8000, seg 13 @ 0xA000  (level/sprite gfx)
- `sub_5381h` -> seg  9 @ 0x8000, seg 10 @ 0xA000                   (front-end/title gfx)
- `sub_533dh` -> seg  1 @ 0x6000, seg  2 @ 0x8000, seg  3 @ 0xA000  (default/game banks)

So a page-2b source `0xAxxx` read right after `sub_5369h` maps to file offset
`13*0x2000 + (addr-0xA000)` (e.g. 0xA319 -> file 0x1A319).

### Tools for the graphics pipeline

- `tools/rledec.py <rom> <src-off> --dest 0xF800 --out x.bin` replays the RLE
  grammar above to extract a decompressed block.
- `tools/gfxview.py x.bin 0 --bpp 1 --size 16 --count 16 --cols 8` renders 16x16
  1bpp sprites as ASCII art (also `--bpp 4` for SCREEN 5 tiles, `--raw` bitmaps).
- `tools/rleenc.py x.bin --verify <rom> <src-off>` re-packs a flat buffer. It is
  an optimal-length packer and always round-trips, but does NOT always reproduce
  Konami's exact bytes (their packer uses a specific tie-break for equal-cost
  run/literal splits; measured ~1-3/10 exact). This is why the catalogue keeps
  the original compressed bytes authoritative rather than assembling from source.

### Editable graphics catalogue (chosen workflow: "path A")

The ROM stays guaranteed byte-exact because the graphics banks remain the
original compressed bytes (`INCBIN` of the split segment binaries). Editable
copies live in `gfx/`, generated by `tools/gfxdump.py` from `gfx/manifest.tsv`
(run `make gfx`):
- `gfx/<name>.bin` - decompressed raw pixels (edit these)
- `gfx/<name>.txt` - ASCII-art preview (definitive human-readable source)
- `gfx/<name>.png` - scaled PNG sheet, for extra clarity (via the dependency-free
  writer `tools/pngwrite.py`)
- `gfx/index.md`   - table of all catalogued sets (embeds the PNG previews)
Only `gfx/manifest.tsv` is committed; the dumps are ROM-derived and regenerated.
To mod a sprite: edit its `.bin`, re-pack with `tools/rleenc.py`, and patch the
stream into the ROM (the base build stays byte-exact until you patch).

Catalogued so far (extend `manifest.tsv` as more sets are identified):
- `intro_simon` - seg13, 8 streams 0x1A319-0x1A4BC, 8 two-plane Simon sprites
  (intro: Simon arriving at the castle).
- `intro_sky` - seg13, 0x1B895, 8 cloud patterns + a 2-frame bat flap.
- `simon_cell0` - seg13, 40 two-plane frames via pointer table 0xA281 (indexed by
  0xC42E). Simon's **lower body** (legs): walk/jump/crouch/climb poses.
- `simon_cell1` - seg13, 36 frames via pointer table 0xA2D1 (indexed by 0xC42F).
  Simon's **upper body**: torso/head/arm and the **whip** (whip-crack arcs).

In-game Simon is two stacked, independently-animated 16x16 hardware-sprite cells
(legs + torso/whip), refreshed each frame by `load_simon_sprites` (seg0 0x56E8):
it reads the two frame indices (0xC42E legs, 0xC42F torso), looks up the seg13
pointer tables (0xA281 / 0xA2D1), and RLE-decompresses the chosen streams into the
sprite pattern generator (0xF800 = cell 0, 0xF840 = cell 1).  The two-table design
is why legs and upper body can animate on different cadences (e.g. whipping while
standing still).

TODO (next): map the remaining sprite/tile sets - which streams belong to each
enemy/boss/item. Simon's two pointer tables are now resolved (0xA281 legs / 0xA2D1
torso+whip, via load_simon_sprites 0x56E8 -> simon_cell0/1). Still to resolve:
the per-level/per-actor tables (e.g. l55deh; the seg13 stream region 0xA319-0xBFFF
holds more actor art beyond Simon) and the enemy sprite loaders.

## Reference: Metal Gear disassembly

Cloned to `references/MetalGear` (GuillianSeed/MetalGear). Same Konami MSX2 engine
era; very useful for shared idioms. Notable files:
- `data/texts.asm`, `gfx/font.asm` - text/charset (confirmed ASCII scheme)
- `constants/structures.asm` - sprite/object (OBJ) struct layout
- `data/spritesets.asm`, `data/*spriteattr*.asm`, `gfx/sprites.asm` - sprite data
Use these to guide VK's sprite/OBJ format next (the entity struct is the `ix`-based
record used by the entity dispatch at 0x5FD0 / `entity_tbl`).

## Open questions to resolve in code

- Input read path (keyboard SPACE vs joystick trigger) and where the
  title→game vs title→attract branch is decided.
- State machine for logo → title → attract → intro → play → boss → next level.
- Weapon/sub-item inventory representation in RAM.
- Heart counter and vendor transaction logic.
- Per-level / per-boss data tables (which bank they live in).

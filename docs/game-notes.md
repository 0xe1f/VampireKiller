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
  jump.
- **Destructible walls** — some walls can be destroyed; a destroyed wall **sometimes
  reveals a bonus**, including keys.
- **Small yellow key** — unlocks a **chest** (chests hold bonuses; a chest can't be
  opened without one). Simon can carry **only 1** yellow key at a time.
- **Staff** — an alternative to the yellow key: a staff opens **3 chests** before it
  disappears.

*Reversing hooks:* expect per-stage state for **key held (white / yellow / staff
charges)**, **door locked/unlocked**, **chest opened** flags, and a **room/stage/hub
index** driving which tile set + enemy set + room layout loads. Destructible-wall and
chest contents are likely table-driven per room. Instant-death-on-drop implies a
"no room below" check in the fall/room-transition code.

## Player (Simon)

Default weapon: **leather whip**. Can be replaced by pickups:

- Chain whip (upgraded whip)
- Throwable axe
- Throwable cross
- Knives

Sub-items / consumables:

- **Hourglass** — pauses/freezes the game.
- **Holy water** — thrown, high damage.
- **Shields** — two types: one absorbs damage, one reflects it.
- **Hearts** — currency for vendors; also power the hourglass / holy water
  activation *(the heart↔sub-weapon coupling is unconfirmed)*.
- **Life refills** — small orbs during play, or **vials** bought from vendors.

Vendors sell items in exchange for **hearts**.

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
`l4c07h..0x4D4D` in tools/seg00.blocks as data.

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

TODO (next): map the remaining sprite/tile sets - which streams belong to Simon
vs each enemy/boss/item - many are reached through per-level/per-actor pointer
tables (e.g. l55deh, 0xA281+A, 0xA2D1+A); resolve those tables to fill out the
catalogue.

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

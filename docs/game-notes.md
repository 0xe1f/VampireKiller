# Vampire Killer — gameplay notes

Reverse-engineering reference. These are observed/known behaviours of the game,
used to name routines, states and data as the disassembly progresses. Anything
not yet confirmed in code is marked *(unconfirmed)*.

## Boot / attract flow

1. **Konami logo** on a white background.
2. **Title screen.** Regional: the title logo depends on the machine's MSX BIOS
   character-set nibble (low nibble of `0x002B`; 0 = Japanese, non-zero =
   international/other). `title_build` (seg0 0x4D4E) and `title_load_tiles`
   (0x5A02) both branch on it. A Japanese machine draws the kana
   **"Akumajo Dracula"** (`title_logo_jp` 0x4C5A + `title_logo_jp_tiles` and
   SAT from `title_jp_sprites`); any other machine draws **"VAMPIRE KILLER"**
   (`title_logo_intl` 0x4CA0 + `title_logo_en_tiles`). Castle and both logo
   tilesets live in `title_tiles.asm`; the JP SAT stream is bank 13.
   This is the ROM's only region difference (confirmed by rendering both
   tilesets straight from the ROM).
3. **Title input** (`frontend_input`, seg0 0x4398) runs after logo / title /
   attract. Same `read_buttons` mask as play, latched at **0xC401** held /
   **0xC400** new-press (play uses C007/C006).
   - On the **title** (state 1), only bits **4** (keyboard SPACE **or** joystick
     TRG1) and **5** (joystick TRG2 **or** keyboard UP) start. Other keys are
     ignored. Start sets `0xC002` bit 6, then: `0xE600 == 0` (normal) →
     **intro** (state 3); `0xE600 != 0` (a **Game Master** cartridge was found at
     boot) → `state_game_master_menu` (13), the hidden stage/lives select,
     skipping the intro. See "Game Master cartridge" below.
   - On **logo** or **attract**, any new press returns to the title
     (`title_build`).
   - No start on the title: `state_title` counts down `0xC004` (first frame
     wraps 0→255, ~4s at 60 Hz), then `title_set_color2` and `inc 0xC000` →
     **attract** (state 2).
4. Game start plays an **intro animation**: Simon walking up to the castle
   (fence/gate, moon, distant castle, garden wall). Tileset is `intro_tiles`
   (seg9 0x8000), loaded by `load_intro_tileset`; colours from `intro_palette_load`
   (HUD-fixed, then `intro_palette` at 0xBFA1 — not the title extras). Sprites
   are `intro_simon` + `intro_sky`. Map is `mtile_stream_intro` (`0xC41A`).
5. Play proceeds through the **courtyard**, then the **castle interior**.

## Game Master cartridge (hidden cheat features)

Konami sold a companion "cheat" cartridge, the **Game Master** (product code
**RC-735**; Konami prefixed all its releases with `RC-`), and Vampire Killer
unlocks three hidden features when it is plugged in alongside the game.
Everything hangs off one flag, `0xE600`.

**Detection** — `game_master_detect` (seg0 0x5C99) runs once from the boot path.
It walks `EXPTBL` (0xFCC1, four primary slots, recursing into subslots via
`gm_scan_expanded`) and `RDSLT`s six bytes at CPU **0x7FFA** in each, comparing
them against `game_master_sig` (0x5CF0: `00 30 31 13 35 AA`). Match →
`0xE600 = 0xFF`, no match → `0`. Nothing else ever writes `0xE600`, so all three
features below are strictly gated on the cartridge being present.

Confirmed against a 16 KB RC-735 dump: those six bytes **are** the tail of
Game Master (file offset 0x3FFA = CPU 0x7FFA when the cart is mapped at
0x4000). The last two, `35 AA`, are Konami's standard 16K product stamp —
BCD last-two-digits of RC-735 plus the 0xAA marker, the same scheme as
Yie Ar Kung-Fu (`0A 25 AA`), King's Valley (`06 27 AA`), and the rest of
the 16K lineup. The four bytes in front are just whatever preceded that
stamp in the ROM (0x30 0x31 happen to read as ASCII `"01"`). VK tests the
whole six-byte window.

**The cart does not poke Vampire Killer.** Game Master 1 identifies later
games by a word at CPU 0x4010 (`"AB"` = 0x4241 or `"CD"` = 0x4443) or, failing
that, by summing 256 bytes at 0x5000 against a built-in table. VK's
`gm_opt_tbl` (0x4010) is a CD-relative option table written with extra
zeroes (`43 00 44 00 07 00 44 00` …) so the word at 0x4010 is 0x0043, not
0x4443; the checksum 0x7B24 is not in GM's list either. If Game Master
boots in slot 1 it will not recognise this ROM. The working setup is the
inverse: Vampire Killer boots, fingerprints the other slot, and runs its
own pause / menu / continue code. The table still names the RAM that
menu writes (`0xC411` HUD STAGE, `0xD000` stage max 18, `0xC410` lives,
`0xC405` score) — a handshake GM1 never reads.

The 4th word of that table is BCD **44**. Published catalog numbers are
RC-745 (Japan) / RC-749 (Europe); the in-ROM Game Master field does not
match either.

**1. Pause / frame advance** — `gm_pause_check` (seg0 0x40C5) gets first look at
the keyboard from `int_handler`, ahead of the game tick:

- **STOP** (row 7 bit 4) toggles pause. Entering pause stashes PSG volume
  registers 8-10 in `0xE611`-`0xE613`, silences them, and returns *without*
  running `main_tick`, so the frame freezes. `0xE601` holds the pause state.
- **`;`** (row 1 bit 7) while paused runs exactly one tick and stays paused —
  frame-by-frame stepping.
- Both keys are edge-detected through the `0xE610` latch.

**2. Stage / lives select** — pressing start on the title goes to
`state_game_master_menu` (state 13, seg0 0x441B) instead of the intro. The menu
text (`gm_menu_text`, 0x5D1D) reads:

```
---MENU---
> START GAME
  MODIFY STAGE NUMBER
  MODIFY PLAYER NUMBER
```

Picking a MODIFY item swaps the item rows for a prompt — `STAGE NUMBER=` or
`PLAYER NUMBER=` — and takes two digits from the number keys (`gm_digit_entry`,
RLD-ing each digit into the `0xE60F` BCD accumulator, with `gm_bcd_to_bin`
keeping `0xE60E` as the binary value). **RETURN** commits. START GAME just sets
state 3 (intro); the typed values are pushed into the run later by
`gm_apply_values` (0x5E38): stage → `0xD000` (clamped to < 19) with `0xD002`
re-derived from `gm_stage_hub_tbl` and the room reset to 0, lives → `0xC410`.

Menu RAM: `0xE60B` = highlighted item 0-2, `0xE604` = which fields were edited,
`0xE605`/`0xE606` = stage (BCD / binary), `0xE607` = lives, `0xE602` = where the
current prompt prints its digits, `0xE615` = "a value was typed",
`0xE608`-`0xE60A` = key edge latches.

**3. Continue on game over** — `state_game_over` draws an extra line,
`gm_continue_text` (0x4300): `F5 -> CONTINUE` (again the arrow glyph, not `_`).
`gm_continue_key` (0x4314) edge-detects **F5** (row 7 bit 1, latched through
`0xE614`) and restarts the run
instead of dropping back to the title.

**Font gotcha.** The HUD font's punctuation slots are not ASCII shapes, which is
why these strings look odd in the source: glyph `@` (stream byte 0x30) is a
horizontal rule, `_` (0x4F) is a right-pointing arrow (the menu cursor), and `?`
(0x2F) is an **equals sign**. So `vk "@@@MENU@@@"` renders `---MENU---` and
`vk "STAGE NUMBER?"` renders `STAGE NUMBER=`, with the typed digits butting up
against the `=` at x=0xB0.

## Levels / bosses

- Every third stage ends in a **boss battle** (event table `cell_event_tbl`: packed
  `room<<4 | event`). Hitting types **0x11–0x17** subtracts from the shared
  meter `0xC418` (`weapon_hit_damage`); type **0x12** is dual-use (bar in a
  boss room, per-actor HP when `0xCE00==0`).

  | event | stage | room | type(s) | boss |
  | ---: | ---: | ---: | --- | --- |
  | 1 | 3 | 5 | 18 | giant bat |
  | 2 | 6 | 5 | 19 | medusa |
  | 3 | 9 | 7 | 20, 20 | mummies (two of the same type) |
  | 4 | 12 | 6 | 21 + 24 | Frankenstein + Igor |
  | 5 | 15 | 9 | 22 | grim reaper |
  | 6 | 18 | 9 | 17 | Dracula (`event_dracula`) |

  CE01 machines (seg3 except event 6 in seg1): `event_giant_bat`,
  `event_medusa`, `event_mummies`, `event_frankenstein`, `event_grim_reaper`,
  `event_dracula`. Shared epilogue `event_ce01_next`; other bosses then
  `boss_clear_arm` → `room_event_ce10`. Dracula raises CE40 for credits
  instead.

  Frankenstein (`actor_frankenstein`) walks with shapes `0x79/0x7A/0x7B` and is
  on the bar. Igor (`actor_igor`, overflow, not in the 1–22 sheet) uses the same
  `0x67` hunchback frames as `actor_hunchback`; the whip path treats him as 1-HP
  fodder, not metered. `actor_giant_bat` is also placed as a regular enemy on
  stage 16.

### Enemy types 1–22 + blob (`gfx/enemy_sheet.png`, `gfx/sheet_enemy_*.png`)

`actor_*` names live in `segments/actors.inc`. Pictures are from the sheet
(play + SAT); behaviour is the ROM handler. HP is `0x60E9[type]` (`ix+0D`);
unshielded contact is **2×** the odd byte of `actor_value_tbl`. Types **17–22** (and
type 18 in a boss room) use the shared meter `0xC418`; the rest die when
`ix+0D` hits 0. Leather whip subtracts 1 from fodder HP, other weapons 2.

| # | Name | In-game behaviour |
| ---: | --- | --- |
| 1 | `actor_zombie` | Walks in from a screen edge toward centre/Simon. 1 HP, 100 pts. Spawn bit 0. |
| 2 | `actor_merman_green` | Walk/pounce. Closed-mouth frames `0x0B`/`0x08`. 1 HP, 200 pts. Spawn bit 1. Shared handler with 3 (`enemy_merman_tick`). When `ix+1B` is set and Simon’s Y is within ±8 it writes type 3 and pose `0x12` (open mouth), then the type-3 spit path runs. |
| 3 | `actor_merman_red` | Open-mouth spit. Frames `0x12`/`0x0F`. Same walk/pounce, then state 2 hides and fires `0x9F74` kind 2 from Y−0x14 (the mouth). 2 HP. Bit 0 of the type id selects the spit countdown. Spawn bit 2 jumps out of the water (splash pair). Object-list id `actor_placed_merman` is the same spit enemy already standing on the platform — stage 10 rooms 6–8, play-confirmed, no water exit. |
| 4 | `actor_hanging_bat` | Hangs (shape `0x1A`) until Simon is close (Y window `0x50`, X `0x40`), then flies at him. 1 HP, 100 pts. Spawn bit 3 flies in already moving. Object-list id `actor_placed_bat` is the same enemy already hanging — s3r2, s4r1, s4r3, play-confirmed. |
| 5 | `actor_dog` | Idles; charges when Simon is within 64 px. 1 HP, 100 pts, 6 contact unshielded. Object list. |
| 6 | `actor_pikeman` | Walking spear knight. Turns at ledges/walls; walks toward Simon when Y overlaps. 4 HP, 200 pts. Stages 4–5 object list. No projectile. |
| 7 | `actor_flying_skull` | Homes on Simon X **and** Y from off-screen. 2 HP, 200 pts. Spawn bit 4. |
| 8 | `actor_ghost_head` | Flies across, bobbing around spawn Y. 1 HP, 200 pts. Spawn bit 5. |
| 9 | `actor_red_skeleton` | Fast walk (`0x0220`), **no** projectile. 2 HP, 200 pts. Stage 13 object list (same skeleton script as 11; SAT `02 45`). |
| 10 | `actor_skull_pile` | Stationary; faces Simon and shoots (`shot_spawn` 0x9F74, kind `0x0A`). 8 HP, 300 pts. Object list. |
| 11 | `actor_white_skeleton` | Same 0x9FB2 skeleton art as 9, SAT `02 4C`. Kites Simon (walk toward if far, away if close); hops a gap (`Yvel 0xFB8F`) when the floor probe ahead is empty; throws a spinning bone (`shot_throw` 0x9F68, shot type 4, shapes `0x4B–0x4E`). 4 HP, 200 pts. Stages 7–9, 13, 17. |
| 12 | `actor_raven` | Flies, then stalls (Yvel→0) and hovers mid-flight; strafes when Simon’s Y is close. Not the type-8 sine bob. 1 HP, 100 pts. Object list, stages 7–8. |
| 13 | `actor_hunchback` | Jumps toward Simon. 1 HP, 200 pts. Object list. `actor_igor` reuses pose `0x67`. |
| 14 | `actor_bone_dragon` | 8 SAT cells (custom tick, skips `0x644C`). 12 HP, 1000 pts. Stages 11–12. |
| 15 | `actor_roc` | Large 6-cell flyer (phoenix-like). Flies across, pauses to drop `actor_roc_drop`, then continues off. 8 HP, 400 pts. Spawn bit 6. Not the small raven (`actor_raven`). |
| 16 | `actor_axe_knight` | Same SAT layout as 9, but stage 14+ VRAM is the knight. Throws (`shot_throw` 0x9F68). 8 HP, 300 pts, slower walk (`0x0140`). |
| 17 | `actor_dracula` | Event 6, stage 18 room 9. 32 HP on the bar, +30000. SAT is head + cape; sheet composites the 32×32 torso from `dracula_body_closed` via `dracula_blit_torso` (page-1 Y=`0x80`). Portrait 16×16s at Y=`0xA0` are eyes/mouth, not the figure. |
| 18 | `actor_giant_bat` | Event 1 boss; also a normal enemy on stage 16 when `CE00==0` (per-actor HP). 16 HP, 2000 pts. |
| 19 | `actor_medusa` | Event 2, stage 6 room 5. 16 HP, 2000 pts. |
| 20 | `actor_mummy` | Event 3, two of them in stage 9 room 7. 16 HP, 2000 pts. Walk `0x33–0x38`. |
| 21 | `actor_frankenstein` | Event 4 with `actor_igor`. Walk `0x79/0x7A/0x7B`. 32 HP on the bar, 3000 pts. |
| 22 | `actor_grim_reaper` | Event 5, stage 15 room 9. 32 HP, 12 cells, 7000 pts. |
| 0x1A | `actor_blob_blue` | Candle blob. Bonus-21 slime hatches this if left to land. First in stage 4 (hub 1). 1 HP, 2 SAT cells (shape `0x9B`/`0x9C`). SAT `0F 42`. Sprites `spr_blob` / `spr_blob_cc`. |
| 0x1B | `actor_blob_red` | Same tick; hub 3+ (stages 10+). SAT `08 42`. |
| 0x1C | `actor_blob_white` | Same tick; hub 2 (stages 7–9). SAT `0E 42`. |
| 0x26 | `actor_reward` | Non-heart candle/chest drop. Cycles SAT colour, falls, then `drop_spawn` with bonus id in `+0x1F`. Hearts use `actor_flame` instead. Not on the enemy sheet. |
| 0x27–0x2A | intro SAT | `actor_intro_sky` / `_sky_a` / `_sky_b` / `_simon`. Spawned by `intro_scene_build`; poses `0x94`, `0x92`/`0x93`, `0x98`. |

Per-frame `ix+1` machines (DISPATCH_A or `dec a`/`jr z`) are named in
`segments/banks_0123.asm` (bank 3): raven wait/coast/hover/pick/strafe, dog idle/run/air,
bone dragon form/idle/spit, red skeleton wake/walk/pause, hunchback
wait/drop/crouch/jump/hide, blob hatch/fall/pause/hop, merman
fall/walk/spit, hanging bat hang/swoop/bob, skull pile idle/windup/recover.
White skeleton was already walk/air/throw; bosses have their own `*_go`
states.

When a boss dies an **orb descends** (`actor_orb`, not bonus id 22):
  - Pick it up (`0xCE11=1`) → life drip-fills (+1 HP/frame via `0x4658`)
    until full, then advance to the next level.
  - Leave it → still advance after the timer, but **life is not refilled**.

### Ending / credits

Beating **event 6** (Dracula, stage 18 room 9) is the only path into the
credits. `room_event_tick` runs `event_dracula` (the CE01 machine); the last
handler clears `CE00` and raises **`CE40=1`**. The play tick (`play_tick`)
then calls `credits_tick` (seg1 0x66C1) instead of the normal loop:

1. **CE40=1** `credits_start` — `play_sound 0x8E` (ending theme), `credits_init`
   (load `credits_font`, clear CE30–CE34, CE34=1 so `event_vscroll` writes
   CE33 to VDP R23).
2. **CE40=2** `credits_pump` — each frame `credits_clock` bumps CE33 every 4th
   frame (byte, wraps). `credits_keyframe` pages **seg8 @ 0xA000** and
   **seg5 @ 0x8000**, looks up `credits_script_ptr[CE31]`, and if the
   record's tick equals CE33 blits it via `hud_string_glyphs` (C=0xFF).
   `credits_wipe` FILVRMs the strip two ticks behind so scrolled-off glyphs
   don't wrap. Format `{tick, x, chars..., 0xFF}`; letters are ASCII, space
   is `0x00` (not `0x20`); X is
   SCREEN 5 X (`inc a` to test the 0xFF end-of-roll marker, so blit starts
   at X+1). Apostrophe in this font is **`;`** (`LET;S`).
3. **CE40=3/4** wait, then **C409** → `state_hub_advance` (hub wrap / second
   loop), `D012++` (capped at 3), R23=0.

Other bosses never raise CE40; they use `room_event_ce10` → C409 directly.

**Ending paragraph** (seg8, `data/credits_ending.asm` @ 0xBF20, last line in seg5):

> SO THE BRAVE YOUNG MAN PUT DRACULA INTO DEEP SLEEP AGAIN AND THE TOWN
> RESTORED ITS PEACE: LET;S PRAY THAT THE EVIL MIND OF **HUMANBEINGS** WILL
> NOT LET DRACULA COME TO LIFE EVER AGAIN::::

**Staff** (seg5, `data/credits_staff.asm` @ 0x82C0): STAFF; GAME DESIGNER A:NAGATA;
PROGRAMMER A:HARIMA / I:AKADA / K:NAGAE; SOUND PROGRAMMER H:SHIKAMA;
GRAPHIC DESIGNER S:IWAMOTO / N:MATSUI / K:MIZUTANI / A:FUJIMOTO; SOUND
EFFECT BY K:UEHARA; MUSIC BY K:YAMASHITA / S:TERASHIMA; ART DESIGNER
F:HAYAKAWA; ASSISTANT PROGRAMMER K:TOYOHARA / T:OKA / H:EDA / T:OHTSUKA /
T:DANJYO; SPECIAL THANKS K:HIRAOKA / FC:TEAM; PRODUCED BY AKIHIKO NAGATA;
PRESENTED BY KONAMI. End marker `{0x20, 0xFF}` at 0x8491 (table's last two
entries both point here). The `cr` macro writes these (`"SO THE BRAVE"` with
spaces becoming `0x00`); do **not** use `vk` (that is HUD ASCII−0x10).

CE30–CE34: CE30 cleared unused; CE31 = line index; CE32 = done; CE33 =
tick + R23; CE34 = player active.

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

- **Large white key** — one per stage, needed to open that stage's **door**. Keys
  are deliberately **hidden / awkward to reach**: behind walls, or requiring a tricky
  jump. *Runtime:* held as **0xC701 bit 0**. Spent by `door_interact` (seg1 0x771F)
  when Simon overlaps the door (`res 0,(0xC701)`; courtyard / stage 0 opens freely).
- **Every stage 0–18 has exactly one white-key door, from one table.** Seg13
  **`door_tbl` at 0xBB61** (now `segments/banks_bcd.asm`): 19 records of 3 bytes `(room | vert<<7), Y, X`.
  `door_load_coords` (0xBB37) indexes it by stage `0xD000`; if `0xD001` matches
  the room nibble it writes **`0xC5AD = Y`, `0xC5AE = X`** (`ld (0xC5AD),hl` with
  L=Y, H=X — **not** X then Y) and arms **`0xC5AC`** (`0xFF` if bit7 / vertical so
  `door_blit_tiles` paints the 6-tile graphic; `0x04` on the courtyard). Proximity
  (`door_proximity` 0x8587) compares C5AD to Simon Y (`0xC425`) and C5AE to Simon X
  (`0xC427`). All 19 records sit on a left (`X=0x0C`) or right (`X=0xEC`/`0xE0`)
  wall. Stage 0's first byte is `0x42` (room 2, bit6 set, bit7 clear); the loader
  only uses the low nibble and bit7.
- **Two layers, not two kinds of door.** (1) **Object:** the table places the door;
  the key opens it. (2) **Post-open walk** (`door_open_exit`): the connectivity nibble on
  that edge is the *destination*. `0xF` → `set_stage_boundary` (`0xC408`) →
  `advance_stage` (seg0 0x438B then 0x434E: `0xD000++`, `0xD001=0`; 438B also
  clears bit0 if still set). Valid room → intra-stage wrap. Intra-stage key doors
  (decoded, not all play-verified): stages **3, 6, 9, 12, 15, 18**. Stage 15 room 8
  left → isolated room 9; stage 18 room 8 left → room 9 (Dracula). Stage 15 is not
  a unique mechanism — it is the intra-stage case we traced live (`C5AD=0x80`,
  `C5AE=0x0C`).
- **Display-type `0x1F` is not this door.** `scenery_break_result` → `scenery_reveal` → `vendor_spawn` is the
  vendor / brazier-reveal special-object path (`0xC5B5`/`0xC5C5`). An earlier A/B
  scan that "ruled out" placed-object doors was right to reject 0x1F as the
  *white-key door*, but it never found `door_tbl` either. `tools/roomperm.py`
  overlays the table by default (red bar); `--compare-doors` still emits the old
  edge-heuristic / object sheets. List-id `0x1F` on those object sheets is a
  placed hanging bat (s3r2, s4r1, s4r3), not this vendor path.

  `door_tbl` (room, vert, Y, X; post-open = CONN nibble on that edge):

  | stage | room | vert | Y | X | post-open |
  | ---: | ---: | ---: | ---: | ---: | --- |
  | 0 | 2 | 0 | 90 | E0 | right blocked → stage |
  | 1 | 7 | 1 | 30 | EC | right blocked → stage |
  | 2 | 1 | 1 | 30 | EC | right blocked → stage |
  | 3 | 4 | 1 | 80 | EC | right → room 5 |
  | 4 | 3 | 1 | 30 | 0C | left blocked → stage |
  | 5 | 5 | 1 | 50 | 0C | left blocked → stage |
  | 6 | 4 | 1 | 50 | 0C | left → room 5 |
  | 7 | 6 | 1 | 60 | EC | right blocked → stage |
  | 8 | 7 | 1 | 40 | EC | right blocked → stage |
  | 9 | 8 | 1 | 80 | 0C | left → room 7 |
  | 10 | 8 | 1 | 80 | EC | right blocked → stage |
  | 11 | 5 | 1 | 80 | EC | right blocked → stage |
  | 12 | 5 | 1 | 80 | EC | right → room 6 |
  | 13 | 8 | 1 | 80 | 0C | left blocked → stage |
  | 14 | 7 | 1 | 80 | 0C | left blocked → stage |
  | 15 | 8 | 1 | 80 | 0C | left → room 9 |
  | 16 | 5 | 1 | 40 | 0C | left blocked → stage |
  | 17 | 11 | 1 | 40 | 0C | left blocked → stage |
  | 18 | 8 | 1 | 80 | 0C | left → room 9 (Dracula) |
- **Destructible walls** — some walls can be destroyed; a destroyed wall **sometimes
  reveals a bonus**, including keys.
- **Small yellow key** — unlocks a **chest** (chests hold bonuses; a chest can't be
  opened without one). Simon can carry **only 1** yellow key at a time. *Runtime:*
  the yellow key is **bonus id 0x17 (23)**; picking it up (from the 0xC500 pickup
  list) sets **0xC701 bit 1** (white key = bit 0) and **0xC700 = 1** (the key/lockpick
  charge count). Opening a chest consumes it: **0xC701 bit 1 cleared, 0xC700 -> 0**;
  the chest's reward latches as its own bonus id (observed **0x13 / 19** once) and
  spawns into the object (0xC490) + pickup (0xC500) lists.
- **Lockpick** — an alternative to the yellow key: a lockpick opens **3 chests** before it
  disappears (`bonus_lockpick` writes **0xC700 = 3**).

*Reversing hooks:* expect per-stage state for **key held (white / yellow / lockpick
charges)**, **door locked/unlocked**, **chest opened** flags, and a **room/stage/hub
index** driving which tile set + enemy set + room layout loads. Destructible-wall and
chest contents are likely table-driven per room. Instant-death-on-drop implies a
"no room below" check in the fall/room-transition code.

*CONFIRMED (runtime + static, see progress.md "Eighth session"):* the hub/stage/room
index is a RAM trio:
- **0xD002 = hub** (6 hubs, 0-5) - selects the packed datasets in seg14
  (`scenery_list_ptr` @ 0x8000, `object_list_ptr` @ 0x8668); chosen from the stage via the seg0 0x5E71 table which
  groups stages in 3s (so ~3 stages per hub, matching the design).
- **0xD000 = stage** (0 = courtyard, 1-18 = the 18 stages).
- **0xD001 = room** within the stage (increments walking right).
Each hub's packed stream holds 3 stages × up to 16 room slots × up to 4 objects.
Per object: **list-id = actor type** (`object_list_spawn` → `spawn_actor_ab` with
`C = id&0x7F`; names in `segments/actors.inc`). Bit7 is stored then stripped;
only `actor_dog` ever sets it (3 of 6; role unknown — not facing in the actor
slot). Attr packs the in-room cell the same way as scenery: **Y<<4|X**, each
nibble ×16 px. `object_list_spawn` loads high→E (Y / `spawn_actor` +03) and low→D (X /
+05). A decoder that treated it as X<<4|Y swapped the axes — dogs and bats
looked one cell off on Y whenever the nibbles differed by 1.
Stage 0 (courtyard) has no object-list entries — `object_list_spawn` does `dec a; ret m`.
`D000`/`D001` are stage/room **indices**,
not map coordinates — room positions come from `minimap_room_pos` (see below).
`tools/roomperm.py` is the map (`gfx/minimap_s<NN>.png`); its `decode_objects`
reads this list for the `--compare-doors` overlay.

**Scenery list** (seg14 **`scenery_list_ptr` @ 0x8000**, sibling of the enemy
list): candles, breakable blocks, floor pickups, chests, and vendors. Same 6
hubs; stage 0 is **`scenery_list_s00` @ 0x800C** (the courtyard is not in the
hub table — `scenery_list_lookup` 0x5A9F returns it when `D000==0`). Grammar is
**not** the enemy list's: `0xFE` next room, `0xFF` next stage, `0x00` end hub.
`scenery_unpack` (0x5A63) expands into **0xE000** (3×16×24 bytes); `scenery_room_load`
(0x5B22) instantiates the current room into **0xC470** (8 candle/block slots), **0xC500**
(floor items/chests), and **0xC5B5**/**0xC5C5** (vendors). Record: pos (hi
nibble Y, lo nibble X, ×16 px), attr; attr `0x7F` is a 32×32 covering wall
plus a third reveal byte (whipped block → chest or vendor). **attr bits7-5**:
`000` floor pickup, `001` candle/brazier, `010` 16×16 block (engine-ready,
unused in the packed stream), `011` 32×32 breakable block (stamped over the
nametable). bits7-6 `10` = chest; `11` = vendor. bits4-0 = bonus id. Stage 18
room 9 (Dracula) is omitted and stays empty. ~620 records.

**Breakable walls** are scenery blocks (`attr 0x60–0x7F`), not extra tile types.
`scenery_room_load` sets C470 `+04=3`; the first `brazier_tick` saves the
nametable under the slot (`block_save_under` → 0xE4A0) then `block_stamp`s a
4×4 of brick ids (`block_tiles_castle`: 01/02/0A/0B) into VRAM **and** D100,
so the wall is solid. **`attr 0x7F` is still this wall** (bits7–5 = `011`,
bonus `0x1F`, bit7 clear): load stamps the bricks and stores the extra byte
in C470 `+09`. Whip → `brazier_destroyed` restores the saved tiles, then
spawns the reveal: a chest at **Y+16** (bottom half of the 4×4, same offset
as a kind-3 drop) or a vendor at the stamp origin (32×32 LMMM, no offset).
Ordinary whip drops also use Y+16 on kind 3. `010` would be a 16×16 stamp
(kind 2); the packed stream never uses it.

Whip of a non-reveal wall zeros the E000 pos byte and `drop_spawn`s the
bonus. Slime (`0x15`) skips the flame and goes to a C500
slot that hatches `actor_blob_blue` / `_red` / `_white` if left to land.

Wall-slime (`attr 0x75`) rooms: **s06r0** (6,10)/(8,10)/(10,10); **s08r0**
five-block cluster; **s08r7** (12,4); **s16r9** (8,5). **s04r0** has a
candle-slime at (8,4) and a white-key wall at (2,4) — not a hidden blob.

Spawn-bit types (`actor_zombie`/`actor_merman_green`/`actor_merman_red`/
`actor_hanging_bat`/`actor_flying_skull`/`actor_ghost_head`/`actor_roc`) and
bosses (`actor_dracula`, `actor_medusa`–`actor_grim_reaper`) are **not** in this
list; they come from `room_spawner` or the event table. Two extra list-ids reuse
those handlers with a different spawn-init (overflow of `entity_tbl` into seg1
`data_6000`):

| list-id | n | name | vs generator type |
| ---: | ---: | --- | --- |
| 0x05 | 6 | `actor_dog` | — |
| 0x06 | 11 | `actor_pikeman` | — |
| 0x09 | 13 | `actor_red_skeleton` | — |
| 0x0A | 6 | `actor_skull_pile` | — |
| 0x0B | 23 | `actor_white_skeleton` | — |
| 0x0C | 4 | `actor_raven` | — |
| 0x0D | 36 | `actor_hunchback` | not scenery |
| 0x0E | 8 | `actor_bone_dragon` | — |
| 0x10 | 28 | `actor_axe_knight` | not scenery |
| 0x12 | 6 | `actor_giant_bat` | regular enemy on stage 16; boss s3r5 is event-spawned |
| 0x1F | 3 | `actor_placed_bat` | Play-confirmed: hangs, then flies at Simon on approach. `enemy_placed_bat_init` 0xB0D5 skips `actor_hanging_bat`'s fly-in state so it starts hanging. s3r2, s4r1, s4r3 |
| 0x21 | 5 | `actor_placed_merman` | Play-confirmed: already on the platform, does not jump out of water. `enemy_placed_merman_init` 0xA2CE skips the `actor_merman_splash` pair and jumps into the walk. Stage 10 rooms 6–8 |

**Not** white-key doors and **not** the vendor: display-type `0x1F` on a brazier
(`scenery_break_result`) is a different field. An earlier overlay treated list-id `0x1F` as a
door candidate because those 3 rooms matched a scan — they are the placed bats.

### Spike bars (the 0xC580 hazard pool)

The three chain-hung spike bars of **stage 6 room 1** are the only thing that
ever occupies the 0xC580 pool — `spike_bars_seed` (seg2 0x8FA6) refuses to seed
unless `0xD000`/`0xD001` = stage 6 / room 1, and nothing else writes those
slots. They are **not enemies**: no C500/C800 actor slot, no HP, no death
state, and they cannot be destroyed. They are also **not sprites** — each is a
32×16 4bpp *background* block moved with `vdp_hmmm`, so there is nothing to add
to `gfx/enemy_sheet.png`.

`hazard_tick` (0x8FD6) → `spike_bars_run` → `spike_bar_slot_tick` (0x8FF1) per
live slot. Slot layout (8 bytes, `spike_bar_seeds` at 0x8FC4 seeds `+0..+5`):

| off | meaning |
| ---: | --- |
| +0 | state: 1 = descending (+4px/step), 2 = retracting (−4px/step), 0 = free |
| +1 | Y (the bar/collision row) |
| +2 | X (fixed column) |
| +3 | extra rate gate while descending: 0 = every tick, 1 = every 2nd |
| +4 | free-running tick counter |
| +5 | steps per sweep, then toggle state (`0x0B × 4` = 44px of travel) |
| +6 | steps taken this sweep |

Seeds are X = `0x3C` / `0x7C` / `0xBC` at Y = `0x60` — the three arches — with
tick phases 0/1/2 so they do not move in lockstep, and the right-hand bar
gated to half rate. Descending is gated by `+4 & +3` and retracting by
`+4 & 3`, so a bar **drops fast and crawls back up**. Contact damage comes
from `hurt_simon_spikes` (0x85AD) over a 32×8 box: **16** while descending,
**8** while retracting (it reads bit 0 of the state byte, which is what makes
the two directions differ).

The graphic is staged once by the HUD/bonus loader at seg0 0x5494, which builds
the picture in **VRAM page 1 at (0x80, 0x70)** out of two seg9 fragments:
`spike_bar_mount` (8×4, one chain link) centred at X=140, and `spike` (8×8, a
bar segment with one downward spike) blitted four times at X = `0x80`/`0x88`/
`0x90`/`0x98` to span 32px. Source fragments are `data/spike_bar.asm`
(`gfx/tilesets/spike_bar.png`; cell header = CPU address). Note the pixel
indices are 4/6/0xB, all **stage-overlay** slots, so the same bytes are gold
here but would come out pink or cyan under another stage's palette.

**The chain is a smear, not artwork.** The copied block is 16 rows but the art
is only 12 — rows 0–3 are the chain link, 4–11 the bar and spikes, 12–15 blank
— and it is drawn at `Y−4` with a 4px step. So every descending step leaves
rows 0–3 uncovered and the links stack into a seamless vertical rod, while
retracting paints the bar back over them (and the blank rows wipe the spike
tips). That is why the three bars in the room have visibly different chain
lengths: chain length *is* the drop distance. `spike_bars_restore` (0x902E)
repaints them after the F2 map screen, reseeding so the sweep restarts.

### Moving platforms (the 0xC598 pool)

Two slots of 7 bytes, seeded per room by `platform_load` (0x9034) from
`platform_tbl` (0x9073) and ticked by `platform_tick` (0x90A2). Unlike the
spike bars these are **hardware sprites**, not background: each deck is 32×16
built from four 16×16 SAT cells. They exist only on **stages 5 and 10**.

| off | meaning |
| ---: | --- |
| +0 | slot id, 1 or 2; 0 = free |
| +1 | Y, the visual row (SAT writes this minus 1) |
| +2 | X, the only thing that moves |
| +3 | step, signed px/tick, negated at each end point |
| +4 | span, ticks per sweep before reversing |
| +5 | free-running tick counter, incremented but unread in `platform_move` |
| +6 | ticks elapsed in the current sweep |

`platform_move` (0x90BF) adds `+3` to `+2` each tick; when `+6` reaches `+4` it
zeroes the counter and does `neg` on `+3` instead of moving, so the deck pauses
one frame at each end. `platform_tbl` records are `{Y, X, step, span}` after a
`{stage, room, count}` header, `0xFF`-terminated: stage 5 room 1 gets one deck
(`5F 60 01 40`), stage 5 room 4 gets a **pair moving apart** (`5F 20 01 30` and
`5F B8 FF 38`, the only negative step in the table), and stage 10 rooms 0/2/3/4
get one each at Y `0x8F` or `0xA7` with spans 64–160.

Note `platform_load` writes `+0` then `ldir`s four bytes into `+1..+4` and skips
`+5`/`+6` with two `inc de`. That is fine: `actor_state_reset` (seg1 0x63BA)
already zeroed `0xC470..0xC6FF` on room load, which includes the C598 pool.

`platform_sat_build` (0x90DF) emits slot 1 to SAT `0xD638` with colours at
`0xD4E0`, slot 2 to `0xD648`/`0xD520`. Cell geometry comes from
`platform_sat_ofs` — `{0,D0} {0,D4} {0x10,D0} {0x10,D4}` — so the four cells are
two X positions × two patterns, and the pattern is shifted by `+8` off stage 5
to give each hub its own deck artwork (`gfx_rle_a066` @ FE80 for D0/D4;
`gfx_rle_a0a8` @ FEC0 for D8/DC). The colour bytes alternate with the CC
bit (`0x40`) set on the second of each pair, so cells 0+1 and 2+3 OR together
into one two-colour 16×16 half each: **2/4 on stage 5, 9/0xC on stage 10**.
SAT Y is table Y−1 (MSX SAT is the line above the sprite); `platform_overlap`
compares Simon against table Y, the visual top. Guide maps blit at table Y
minus `playfield_draw`'s dest Y (`0x20`), with a white box from spawn X to
spawn + step×(span−1) — the reverse tick does not move. The box is drawn on
top of the deck, top edge inset 1 px.

Simon's side runs from `platform_stand_test` (0x852B), called by
`simon_action_tick` every frame *before* the action-state dispatch so `0xC439`
is fresh. It tests both slots with `platform_overlap` (0x8556) over a 32×8 box —
Simon within 8px above the deck row, either foot (X ±7) inside the 32px deck —
and stores the matching slot id in `0xC439`. While falling (`0xC420 == 4`) with
jump phase `0xC428 < 3` the test is skipped entirely, so Simon rises *through* a
deck instead of catching on its underside. `simon_grounded` then calls
`platform_carry_simon` (seg1 0x6BB6), which nudges his X by one pixel in the
direction of the slot's step byte, cancelled by a wall probe on that side so a
deck cannot shove him into geometry.

## Room geometry / tile map (CONFIRMED, static + runtime, byte-exact)

Every room is an **8 wide x 6 tall grid of METATILES**; each metatile is a **4x4
block of 8x8 tile ids (16 bytes)**, so a room expands to a **32x24 tile-name map**
held in work RAM at **0xD100** (rows 0-1 are the HUD; the drawer seg0 0x4f98
paints the playfield from 0xD140). `seg0 room_map_build` (0x4fb6) does the
expansion on room entry; `seg1 map_cell_at` (0x7d36) reads it for collision.

Storage (during the build the mapper pages bank 0x0b->0x6000, 0x0c->0x8000,
0x0d->0xA000, then restores banks 1/2/3).  Banks 0x0B/0x0C are source in
`segments/banks_bcd.asm`:
- **`mtile_rowbase`** - byte table at bank 0x0b **0x6000**; index = rowbase[row]+col.
  Rooms in a world row = rowbase[row+1]-rowbase[row] (row 1 / stage 1 = 8 rooms;
  stage 18 uses `minimap_room_count` because the next byte is not a count).
- **`mtile_roomptr`** = word at bank 0x0b **0x6013 + 2*index** -> the room's
  **48-byte metatile-id stream** (row-major 8x6) in `mtile_streams` (e.g. stage 1
  streams start at 0x620b, stride 0x30).
- **`mtile_defbase`** = per-row word table at bank 0x0b **0x7EBB**; def(id)
  = 16 bytes at defbase + id*16 (`mtile_defs_s01` 0x80B1 = bank 0x0c). The special
  path (0xC41A!=0, e.g. intro) uses `mtile_stream_intro` 0x614B + `mtile_def_intro`
  0xA041 (bank 0x0d).  Stage 0/18 def tables straddle the 0x8000/0xA000 boundaries.
  `make gfx` writes one sheet per def table under `gfx/metatiles/` (cell header
  = CPU address of the def) and stream catalogues `mtile_streams.png` /
  `mtile_stream_intro.png` (one stage per row; cell header = CPU of the
  48-byte stream).

**Tile id classes (stage 1).** Walls and floors are the **structural brick family**
**01..04** (solid SURFACE) + **09..0b** (brick BODY under/behind the surface),
laid out as a repeating (surface, body) metatile - so a wall column reads
01/09/01/09... top to bottom. Passable ids: **0x0e..0x17** (open air + far-wall
decoration); **stairs** - paired tiles **06/0c** (ascending one way) and **07/0d**
(the mirror), climbable; the **08/05** pair (a fixed 2-tile background graphic
near the pillar tops - NOT wall/floor and NOT an enemy generator, see below;
exact depiction unconfirmed); and the decorative blocks **0x2c+** (background
windows, columns). The permeability map treats 01..04 as always solid and 09..0b
as solid only when 4-adjacent to an 01..04 surface (a lone 09 next to 05-08
wallpaper is passable).  **Stairs** are climbable 0c/0d only (the engine tests);
06/07 are decoration (stage 1 stair trim, wallpaper elsewhere).  Stage 18 room 9
is a per-room override.

**Engine collision** is stricter than the drawn geometry: `seg1 tile_is_solid`
(0x7c65) blocks Simon only when **(id-1) < row_solid_thresh[0xD000]** (byte table
0x7c7f; stage 1 -> 4; "event 6" cells force 6) - i.e. only the 01..04 SURFACES.
The brick body never needs to be solid because Simon can't get inside a wall, and
horizontal bounds also come from screen edges / room transitions. (Decorative
0x2c+ columns are pass-through: e.g. room 0 has no real walls, only a floor.)

`tools/roomperm.py` decodes any stage straight from ROM and renders one per-stage
minimap (`gfx/minimap_s<NN>.png`, each room labelled with its number); `--all`
renders all **19 stages (0..18)**, driven by the game's minimap room-count table
(stage 18/Dracula's rowbase delta is a garbage sentinel, so its room count comes
from that table; its room pointers/geometry still decode normally).
Stage 18 room 9 (Dracula's arena) is a **per-room override**: tile IDs cannot
separate the decorative columns from the floor (same `06`–`0b`), so the minimap
paints only the floor plus the 2×1 jump ledges flanking each column.
`--collision` shows the strict 01..04-surface view, `--visual` adds the 0x2c+
scenery. Validated byte-exact against 0xD100 RAM snapshots for all 7 recorded
stage-1 rooms. Note metatile-definition tables can straddle the seg12/seg13
(0x8000/0xA000) window boundary, so the decoder treats banks 0x0b/0x0c/0x0d as one
flat 0x6000-0xBFFF buffer.  Body-tile specks that used to read as solid noise
(stage 6 room 5, stage 10 wallpaper, stage 15 rooms 6-9, stage 17 rooms 7/10,
stage 0 room 2 gate) were 09 counted solid because 05-08 decoration was treated
as a surface; the 01-04 adjacency rule clears them.

**Room-to-room connectivity (CONFIRMED, byte-exact + runtime-validated).** The
transition graph is a per-stage table in bank 13 (`segments/banks_bcd.asm`): `conn_ptr` word table at **0xB9D3**
(19 entries, one pointer per stage 0xD000 0..18). For a room it points at a 2-byte
record = **4 nibbles: up, down, left, right** = the DESTINATION room index for
that exit (`0xF` = blocked). On an edge/stair transition the engine looks this up
(seg13 0xB963/0xB9BD) and writes the result to 0xD001 (**seg13 0xB987**); the
per-frame edge/stair detector `room_edge_detect` (seg1 0x7682) sets the pending-exit
direction in 0xC41B (1=up,2=down,3=left,4=right; **0xFF** = spot/portal warp), and the four RAM permit bytes
0xC41C-0xC41F are loaded from the same nibbles (seg13 0xB99A). Stage advance
(0xD000++, 0xD001=0) is separate: `advance_stage` (seg0 0x434E), reached via the
white-key door (`0xC408` / `state_stage_exit`) or after a boss (`0xC409` / `state_hub_advance`). `0xD000` is never
changed by the connectivity path - vertical moves stay within the stage.
- Verified: decode matches all 6 recorded consecutive stage-1 transitions and the
  stage-1 horizontal loop (room 3 right->0, room 0 left->3).
- This is a **navigation graph, not a spatial one**: exits can wrap or teleport in
  BOTH axes. E.g. stage 8 has a **vertical loop** (`4.down->7` and `7.down->4`
  point at each other, though 7 sits above 4), and stages 12/13 have portal edges.
  So it **cannot** be trusted to reconstruct 2D geography (an earlier BFS heuristic
  that assumed "horizontal can loop, vertical can't" got a few stages wrong), and
  `roomperm.py` uses it for post-open destinations and `--compare-doors` edge
  mode, not for default door overlay (that is `door_tbl`). Room POSITIONS come entirely from
  the game's own hand-authored layout table (`minimap_room_pos` 0x9681 / tables at
  0x969C, 0x975E; see the Map item above) - the authoritative in-ROM geography, which
  reproduces the true portal/loop stages (8's vertical loop, 12/13 portals, Dracula's
  stage 18). The old BFS reconstruction has been dropped.

**Stage-12 spots (`spot_tbl` at 0xBBCD, in `segments/banks_bcd.asm`).** `door_load`
(0xBB31, via `door_load_paged`) also runs `spot_load_coords` (0xBB9A): a 0xFF-ended
list of `(stage, dest<<4|room, Y, X)`. The current ROM has 10 records, all stage
12, in two-way pairs (0↔3, 1↔4, 2↔11, 5↔8, 7↔10). A match arms **0xC5B1=1**,
stores Y/X at **0xC5B2/C5B3** (same L=Y H=X as the door), and the dest nibble at
**0xC5B4**. Play-verified: crouch **on the pad** (DOWN), then UP (0xC006 bit 5,
same bit as jump). `simon_crouch` (0x6DB0) calls `spot_proximity` (seg2 0x85FB);
on carry + UP it enters action state 7 (`simon_portal_wait` 0x7102), queues
effect 0x15 via `play_sound` (the flash), waits **0xC42D = 0x40**, then writes
**0xC41B = 0xFF**. `conn_lookup` / `conn_from_spot` then set 0xD001 from C5B4.
Trace (room 0 pad Y/X = A8/58): crouch → state 7 → C41B=FF → D001=3; room 3
re-arms the return pad with dest 0. Off-pad crouch never takes this path.
`tools/roomperm.py` overlays each pad as a teal 2×2 sitting on the floor, with
the dest-room digit in the same colour beside it (`--no-spots` to skip).

## Player (Simon)

### Movement / action states (RAM 0xC420, runtime-confirmed)

`0xC420` is Simon's action state; `simon_action_tick` (seg1 0x6B40) dispatches an
8-entry handler table by it. Confirmed values:

| 0xC420 | handler | meaning |
| --- | --- | --- |
| 0 | `simon_grounded` 0x6B59 | grounded (walk / idle). Whipping does **not** change this byte. |
| 1 | `simon_jump_tick` 0x6CC7 | **jump / airborne** (Y arc via `jump_y_delta`; `simon_jump_dir` 0 aim / 1 up / 2 left / 3 right — not `dir_*`) |
| 2 | `simon_crouch` 0x6DB0 | **crouch** (DOWN held; Simon X is locked — cannot move) |
| 3 | `simon_stairs` 0x6DE4 | **on stairs / climbing** (diagonal travel; can whip while climbing) |
| 4 | `simon_fall` 0x6F44 | **falling / dropping** off a ledge |
| 5 | `simon_hurt` 0x6F8C | hurt / knockback (shallow airborne launch — not a jump) |
| 6 | `simon_dying` 0x709A | dying / respawn (enemy spawner is suppressed while ==6) |
| 7 | `simon_portal_wait` 0x7102 | pad crouch+UP wind-up: wait 0xC42D, then C41B=0xFF warp |

`0xC423` is the `simon_hurt` DISPATCH_A index (`simon_hurt_step`); jump/fall
arc phase is `simon_arc` (`0xC428`).

### Input (RAM 0xC006 / 0xC007)

`read_buttons` (seg0 0x4BC2) samples the joystick (PSG port A) and keyboard row 8
(arrows + SPACE). `input_edge` (0x4BBB) latches the held mask at **0xC007** and
the rising edge at **0xC006** during play. The title uses a separate pair:
**0xC401** held / **0xC400** new-press (`frontend_input`). Bits: 0=UP, 1=DOWN,
2=LEFT, 3=RIGHT, 4=SPACE **or** joystick TRG1 (whip / title start), 5=keyboard
UP **or** joystick TRG2 (jump, portal new-press, and also title start). Crouch
is DOWN *held* (C007 bit 1); jump/portal is UP *new-press* (C006 bit 5).

### Player stats / HUD (RAM 0xC400–0xC41F)

New-game seeds `0xC410–0xC412` from `run_seed_tbl` (lives=3, STAGE=0, C412=1).
Score, hearts, lives, HP, weapon, and the enemy meter were already named from
play traces; the leftover bytes in this block are flags, not a second inventory
(keys/map/bibles live in `0xC700–0xC70F`).

| addr | meaning |
| ---: | --- |
| `0xC400` / `0xC401` | title start: new-press / held (bit4 SPACE\|TRG1, bit5 TRG2\|kbd UP) |
| `0xC402–0xC404` | unread. `add_score` overflow writes `0x99` here; visible score is C405–C407 |
| `0xC405–0xC407` | score, 3-byte packed BCD (low/mid/high). HUD draws C407→C405 |
| `0xC408` | stage-boundary / white-key door → `state_stage_exit` |
| `0xC409` | hub-advance (boss-clear or ending credits) → `state_hub_advance` |
| `0xC40A` | F1 pause latch → `state_pause` (frozen; F1 again resumes, BGM `0xFD`/`0xFE`) |
| `0xC40C` | vendor whip-hit → `state_vendor` |
| `0xC40D` | force stage BGM replay (death respawn / password) |
| `0xC410` | lives, packed BCD |
| `0xC411` | HUD STAGE, packed BCD |
| `0xC412` | seeded `1` at new game; no readers |
| `0xC413` | stay-in-play (`1`); `0` leaves play (attract end / death) |
| `0xC415` | Simon HP (`0x20` full) |
| `0xC416` | equipped weapon (0 leather … 4 cross) |
| `0xC417` | hearts, packed BCD |
| `0xC418` | enemy/boss meter (`0x80` full) |
| `0xC419` | last-collected bonus id |
| `0xC41A` | intro: nonzero → `mtile_stream_intro` |
| `0xC41B` | pending exit (1–4 dir, `0xFF` spot) |
| `0xC41C–0xC41F` | exit permits up/down/left/right (`0xFF` = blocked) |

`0xC40B`, `0xC40E–0xC40F`, `0xC414` have no code xrefs.

Callers that only need a 4-digit award `jp add_score_c0` (`0x44F3`: `ld c,0` then `add_score`).

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
  byte of the enemy type's `actor_value_tbl` entry. Confirmed: zombie = **2**, dog = **6**.
  A raised **red shield** (`0xC701` bit 4, bonus id 3) uses table damage instead
  of 2× when Simon is facing the hit, and spends a shield charge (`0xC441`);
  when charges run out the shield drops.  The **yellow shield** (id 4, bit 5)
  absorbs enemy shots instead.
- **Hazard** — `hurt_simon_spikes` (seg2 0x85AD), a 32×8 overlap test against
  the three 0xC580 spike-bar slots (`spike_bar_overlap`). Fixed **8**, or **16**
  when bit 0 of the slot's state byte is set. Nothing else ever seeds that pool
  (`spike_bars_seed` is the only writer, and only on stage 6 room 1); enemy shots
  live in the 8 D700 slots. State is 1 while descending and 2 while retracting —
  so the 16 is the falling bar and the 8 is the rising one. Also forces the hurt
  state (`0xC420 = 5`). Ignored during i-frame/invis timers (`simon_invuln`, `blue_gem`).
  See [Spike bars](#spike-bars-the-0xc580-hazard-pool).

**Simon deals damage** to HP-bar enemies via `weapon_hit_damage` (seg1 0x7E33) →
`damage_enemy` (seg0 0x4643, `0xC418 -= B`). B comes from a per-weapon table indexed
by `(enemy type − 0x11)`:
- leather whip / knife → base `04 08 08 04 04 04 10` (types 0x11..0x17)
- chain / axe / cross → strong `06 0C 0C 06 06 06 18` (≈1.5×)
- vs type 0x17 with weapon ≥ 2 the hit is quartered.

Lesser enemies (type < 0x11) have no HP bar; they use per-actor HP at `ix+0D`
(`actor_hp_tbl` at 0x60E9). Leather whip subtracts 1 per connected hit, other weapons 2.

Hit tests pick a **box size by type** then overlap Simon / whip / C450–C460 /
the yellow shield. C800 actors use `hit_class_c800_tbl` (classes 1–7: fodder
5×24, flyers 8×16, dog 12×10, roc/axe/bat/medusa 12×24, Dracula 16×48 with
whip/proj at Y−0x20, mummy/Frank 5×40, grim 8×48). Shots (8 slots at 0xD700)
use three smaller classes (`hit_class_shot_tbl`). Wrappers: `actor_vs_whip` /
`actor_vs_simon` / `actor_vs_proj`, `shot_vs_*`.

Shot **kind** (spawn A) maps through `shot_kind_type` to a slot type. Merman,
skull pile, bone dragon, giant bat, Igor, and Dracula all spawn the same
**fireball** (`fireball`: a `ret`, coast on spawn velocity). Shared sprite:
pose 3, SAT pattern `0xF0`, colours 0/8; pixels from `gfx_rle_a185` at VRAM
`0xFF80` (HUD load, not per-room). Slot types: pile 3; white-skeleton bone 4;
Dracula 5 (same tick/sprite as type 1); medusa snake 6 (`medusa_snake`); mummy
bandage 7 (`mummy_bandage`); grim sickle 8; axe 9; Igor 10. Kind `0xFF` is the
death flame (type 12).

### Equippable weapons (strength tiers, per design)

- **lowest**: leather whip, thrown knife
- **normal**: chain whip, boomerang cross
- **strong**: boomerang axe

The HP-bar table (`hpbar_dmg_weak` / `hpbar_dmg_strong`) treats **axe and cross both as strong**
(same 1.5× row as the chain whip). Fodder (`fodder_dmg_tbl`) is knife 1 / axe 4 / cross 2
/ holy 2 per connected hit.

Weapon behaviour (ROM):
- **Whips** (leather `C416=0`, chain `=1`) stay with Simon — SPACE is the whip.
- **Knife** (`C416=2`, bonus `0x1B`, vendor 50 hearts). SPACE, unlimited ammo,
  straight `velX` ±5, no return. `projectile_alloc` may fill **both** C450 and
  C460. A hit despawns that knife (`projectile_clear_hl`); missing just leaves
  the screen. Does not spend hearts.
- **Axe** (`C416=3`, bonus `0x1C`, world drop — not in the vendor table).
  SPACE, `velX` ±3, 24-frame outbound then the shared boomerang (`boomerang_back`
  decelerates and reverses). Overlap Simon (`proj_overlap_simon`) = catch (keep
  `C416`). Flying into the X wrap zone = `lose_weapon` (back to leather).
  `axe_drop_unequip` can also spawn bonus `0x1C` at the projectile and unequip when `C433`
  is 2 or 3 that frame.
- **Cross** (`C416=4`, bonus `0x1D`, vendor 20 hearts). Same boomerang as the
  axe but `velX` ±5, so the 24-frame outbound covers more of the screen
  (~120 px from a centred throw vs ~72 px). Same catch-or-lose. SAT colours
  `0x0F`/`0x0E` (type 4 only).
- **Holy water** is not `C416`; jump+LEFT/RIGHT, see below.

### Weapon state (RAM - runtime + static confirmed)

- **0xC416 = equipped weapon id:** **0 leather, 1 chain, 2 knife, 3 axe, 4
  cross.** Weapons 0 and 1 take the whip path (`cp 002h / jr nc`); **>= 2** take
  the projectile path on **SPACE**. Holy water is `C701` bit 3.
- **Weapon pickups** via `collect_weapon`: `C416 = bonus id - 0x19`, except **`0x1E`**
  (holy water). Chain `0x1A` → 1 was runtime-confirmed; knife `0x1B` → 2 is the
  vendor dagger (despawn-on-hit, two slots). Axe vs cross is **3 = axe
  (`0x1C`), 4 = cross (`0x1D`)** from throw speed + vendor stock (the cross is
  the one for sale; type 4 is the faster ±5 boomerang). HUD tiles agree
  (`gfx/tilesets/hud_weapon_key_tiles.png`): axe is a hand-axe, cross is the
  diagonal four-arm cross with a **blue** fill (palette index 15, same slot as
  the thrown SAT `0x0F`). Type 3's lose path hardcodes a `0x1C` world drop —
  that is this weapon's own bonus id, not a second item.
- **Damage table split** (`weapon_hit_damage` 0x7E33): leather and knife use
  `hpbar_dmg_weak` (`04 08 08 04 04 04 10`); chain/axe/cross use `hpbar_dmg_strong`
  (`06 0C 0C 06 06 06 18`). Index = enemy type − 0x11. Type 0x17 with weapon
  ≥ 2 quarters the hit.
- On death (`inv_reset_life`) `C416` is cleared to 0. Missing a cross/axe catch also
  returns to leather (`lose_weapon` 0x8E9A) without waiting for death.
- Thrown-weapon **patterns** come from seg10 via `load_weapon_sprites` (0x559A)
  / `weapon_sprite_ptr` (0x55DE). Packed order in `data/enemy_sprite_rle.asm`
  is knife, cross, skull pile, flying skull, then axe — not a contiguous
  weapons block. Sheet: `gfx/sprites/enemy_sprite_rle.png`.

Other pickups replace the weapon:

- Chain whip (upgraded whip)
- Throwable axe
- Throwable cross
- Knives

Sub-items / consumables:

- **Map item** — picked up in-stage; sets **0xC701 bit 7** (map held) and seeds
  **0xC70F = 3** uses. Pressing **F2** toggles a whole-stage minimap on/off, spending
  one use per open. Driven by seg2 **minimap_driver (0x9559)** off F-key edges in
  **0xC00B** (bit 1 = F2); the map-screen state is **0xCF38** (0 = playing, 1 = build,
  2 = shown). The map layout is **hand-authored, not derived from connectivity**:
  **minimap_room_pos (0x9681)** reads a per-room *position code* from the per-stage
  table at **0x969C** and maps it via **0x975E** to a 6×5 grid cell (hi byte = X, lo
  byte = Y). This table is the authoritative room geography for all 19 stages (0–18)
  and is available in `tools/roomperm.py` via `--minimap` (default placement is the
  BFS spatial reconstruction; the two are generated side by side for comparison).
- **Hourglass** — bonus id **10** (`C701` bit 6). Use: while **jumping** (C420==1),
  **DOWN** new-press, spend **5 hearts**. Arms `hourglass_timer` (`C43B`; 90 frames ~1.5s, or 150
  ~2.5s with the tipped-hourglass flag below) and `D010` bit0, which skips enemy
  AI/movement. Not 5 seconds in the ROM; not a grounded UP+DOWN chord.

### Holy water

Holy water is a **sub-weapon bit**, not a whip replacement. Bonus id **`0x1E`**
(`bonus_holy_water` 0x8D94) ORs **`C701` bit 3**. It never writes `C416`, so
SPACE is still whatever whip/knife/cross/axe you have. Death (`inv_reset_life`)
keeps only `C701` bit 7 (map); the vial is lost. Vendor row **`0x1E`** is this
item (30 / 10 / 50 hearts).

**How to throw.** While **jumping** (`C420==1`) and SPACE is **not** a new-press
(`simon_try_air_item`), **LEFT** or **RIGHT** new-press (`C006` bits 2/3). Costs **5 hearts**
(BCD) and needs `C461==0` (one vial at a time). `holy_water_use` (seg1 **0x7154**)
writes throw dir to `C468` (1=left, 0=right), sets projectile slot `C460` type
**5**, and spends the hearts. Jump+DOWN is the hourglass if you also have bit 6.

**Arc and flame.** `holy_water_tick` (0x73AB) on the **C460** slot (type at
`C461`). Spawn copies Simon (`C425`/`C427`) with `velX` ±2 and `velY` 0. In flight
(state 2) each frame does `Y += 2*arc_dy_tbl[phase]` — `arc_dy_tbl` is the signed dY
table also used by hurt knockback — and `X += velX` (`projectile_integrate`). It lands when
`map_solid_pair` sees a solid tile, plays sfx `0x18`, and goes to state 3: a **24-frame
flame** on the floor (SAT patterns `0xF4`/`0xF8`, same `actor_flame` sheet as a falling heart;
pixels in `gfx_rle_a185`). SAT path `projectile_sat_ink` paints that state **colour 8** (red).

**Damage.** Unlike the knife (type 2), a hit does **not** despawn the vial
(`projectile_after_hit`). Fodder uses `fodder_dmg_tbl` byte 3 = **2** HP per connected hit
(knife/axe/cross/holy = 1/4/2/2). The flame can connect more than once: a hit
clears enemy `+0x0E` bit 0, and `actors_rearm_hittable` (called from the flame flicker) restores
it on actors that still have bit 2. HP-bar types `0x11–0x17` go through
`weapon_hit_damage` / `C416` (the equipped whip), not that 2.

### Tipped hourglass (secret)

The world hourglass pickup can be whipped before you grab it. That is a hidden
second item, not a glitch. Period guides called the result "1.5× timed-item
duration"; the ROM is slightly more generous than that.

**How.** Whip the hourglass **once**. `hourglass_tip` (seg2 **0x8C4B**) rewrites the
pickup type (`ix+4`) from **0x0A → 0x0B**, nudges it up 8 pixels (`chest_spill`),
and the 4bpp blit switches to the sideways graphic (the tile next to the upright
hourglass in `gfx/tilesets/bonus_hud_tiles.png`). Collecting that form
runs `bonus_tipped_hourglass` (id **11**, 0x8DFC) which does only
`set 2,(bonus_flags)`. Whip it a **second** time and `ix+6` is set to 1, so the
pickup despawns on the next tick — the item is gone.

This is world-pickups only (the 0xC500 list). Buying the hourglass from a vendor
calls `collect_bonus(0x0A)` immediately; there is nothing to whip.

**What it does.** `bonus_flags` (`0xC431`) bit 2 is a persistent "longer timed bonuses" flag. It
is **not** a second hourglass. The tipped collect path does **not** set `C701`
bit 6, so this pickup does not grant freeze — you spent the hourglass on the
duration buff. An hourglass you already held is left alone (bit 6 is not
cleared).

The flag is read when a timed effect is **armed**, not while it is ticking.
Picking up the tipped hourglass does not extend a rosary / gem / ring / freeze
that is already counting down. Seconds below assume 60 Hz.

| Effect | RAM | Default | With bit 2 | Ratio |
|--------|-----|---------|------------|-------|
| Rosary (no new enemy spawns) | `rosary_timer` (`C440`) | `0x96` (150 frames ≈ 2.5 s) | `0xF0` (240 frames ≈ 4 s) | 1.6× |
| Blue gem (invisibility) | `blue_gem` (`C43A`) | `0x96` | `0xF0` | 1.6× |
| Sapphire ring (touch-kills) | `sapphire_ring` (`C434`) | `0x96` | `0xF0` | 1.6× |
| Hourglass freeze | `hourglass_timer` (`C43B`) | `0x5A` (90 frames ≈ 1.5 s) | `0x96` (150 frames ≈ 2.5 s) | 1.67× |

Weapon pickups fall through into `bonus_rosary`, so grabbing a whip upgrade also
gets the long 240-frame no-spawn window if the flag is set.

**What it does not lengthen.** Instant pickups (white cross, potion, hearts,
score bags) and the persistent inventory bits (boots, wings, candle, map, bibles,
keys, lockpick, shields).

**How long it lasts.** Until death. The life-lost reset (`inv_reset_life`) zeros all
of `bonus_flags`, so this flag, boots, and wings go together. It survives room and
stage changes.

- **Life orbs / potion** restore `0xC415` (not heart currency). **7** small orb
  = +8 (1/4 of the 32-point bar). **22** is a **bottle/potion** (`bonus_hud_potion`
  on `gfx/tilesets/bonus_hud_tiles.png`; vendor price-tbl id `0x16`) that instant-fills +32. Same full-bar
  end state as picking up the boss orb, but a different graphic and collect
  path — the descending boss orb is `actor_orb`, not this bonus id.
- **Shields** — **3** red (`C701` bit 4): facing the hit takes table damage
  instead of 2×. **4** yellow (`C701` bit 5): absorbs enemy shots. Mutually
  exclusive; 16 charges in `C441`.
- **Rosaries** — a **temporary "no new enemies" power-up** (id **6**). NOT a
  weapon and NOT a persistent inventory item. Runtime (frame 493): collected as a
  normal 0xC500 pickup (its 0x84 slot cleared), bonus id **0x06** latched to 0xC419.
  Static trace of the effect (confirmed, immediate, not next-room):
    - Handler `collect_bonus[6]` (seg2 **0x8D83**) arms a countdown timer at
      **0xC440** to **0xF0** (240 frames ≈ 4 s) or **0x96** (150 frames ≈ 2.5 s),
      selected by `bonus_flags` bit 2 (tipped hourglass; see that section). Same bit
      lengthens the blue gem, sapphire ring, and hourglass freeze. It does NOT touch
      0xC700-0xC70F inventory or the 0xC416 weapon (hence "temporary"). The weapon
      pickup path (`collect_weapon`, bonus >= 0x1A) falls straight through into this same
      code, so grabbing a whip upgrade also arms a short no-spawn window.
    - 0xC440 is a per-frame countdown: `timers_tick` (seg1) decrements it each frame in
      the timer bank (`room_edge_detect/75c7/75e9/...`).
    - The enemy spawner (seg0 **room_spawner @0x5EBF**) is called every frame from the
      actor-update loop (seg2 0x98F0) whenever 0xD010==0 (normal play). Its first act
      is `ld a,(rosary_timer) / and a / ret nz` -> while the rosary timer is nonzero it
      spawns nothing. When 0==C440, it reads a per-room **spawn bitmask** and
      dispatches one generator per set bit (see below).
    - **Effect is immediate and current-room** (the gate is checked per frame in
      whatever room you're in), not deferred to the next room. It only suppresses
      *new* spawns; enemies already in the 0xC800 slots are untouched.

`collect_bonus_tbl` (seg2 **0x8D45**) is the 25-entry handler table for pickup
ids 1–25 (index = id−1; id ≥ 0x1A goes through `collect_weapon`). Confirmed: **1/2**
small/large heart, **3** red shield (face-on contact uses table damage, not 2×),
**4** yellow shield (absorbs enemy shots), **5** white cross (kill on-screen
actors), **6** rosary, **7** small life orb (+8 HP), **8** blue gem (C43A invis, sprite
flash white), **9** sapphire ring (C434, sprite flash red, touch-kills), **10**
hourglass (jump+DOWN, 5 hearts → freeze), **11** tipped hourglass (secret:
whip the id-10 world pickup once; see section above),
**12** boots, **13** wings, **14** candle (white outlines on breakable blocks),
**15** map, **16/17** black/white bible, **18** lockpick (C700=3), **19/20**
white/blue money bag (+5000/+1000), **21** slime (fake candle drop; collecting
it is a no-effect stub, leaving it hatches `actor_blob_blue` / `_red` / `_white` by hub), **22**
potion/bottle (+32 = full bar; vendor 0x16; not the boss orb), **23** yellow
key, **24** white key, **25** treasure chest (container; `chest_open` spends key/lockpick
and reveals the contents id at `ix+0x0D`). Bonus **`0x1E`** (holy water) is not
in this 1–25 table; `collect_weapon` takes `id - 0x19 == 5` to `bonus_holy_water`.

### HUD bonus tiles (uncompressed 16×16 4bpp)

Pickup popup (`hud_bonus_tile`) and the equipped-weapon icon (`hud_weapon_icon`) HMMM these
tiles from VRAM page 1. Loaded at the HUD init copy (seg0 ~0x548C):

| ids | CPU source | ROM file | VRAM dest | dump |
|-----|------------|----------|-----------|------|
| 1–20 | seg9 `0x9000` | `0x13000` | Y=`0x50`, then Y=`0x60` X=0..48 | `gfx/tilesets/bonus_hud_tiles.png` |
| 21 (slime) | — | — | no dedicated tile | — |
| 22 (potion) | seg9 `0x9A00` | `0x13A00` | Y=`0x60` X=80 | same sheet (`bonus_hud_potion`) |
| 23–30 | seg6 `0xB9C8` (after `page_tileset_banks`) | `0xD9C8` | Y=`0x60` X=96..208 | `gfx/tilesets/hud_weapon_key_tiles.png` |

`bonus_hud_tiles.png` is ids `01`–`14` then the potion (5 columns, CPU-address
headers). Per-tile labels in `data/bonus_hud_tiles.asm` match `collect_bonus`
names (`bonus_hud_small_heart`, …; `BONUS_HUD_16X16` in `tools/emit_identified_data.py`).
`hud_weapon_key_tiles.png` is ids **`17`–`1E`**: yellow key, white key,
chest, chain whip, knife, **axe**, **cross**, holy water, then candle flames.

**Palette.** `palette_set` writes one MSX2 entry (A=index, D=`0rrr0bbb`, E=`00000ggg`);
`palette_apply` walks an (index, rb, g)+ table ending in `0xFF`. `palette_hud_load` loads the
**8 fixed HUD/sprite colours** from seg10 `0xBF88` (file `0x15F88`):

| idx | 3-bit RGB | role |
|-----|-----------|------|
| 0 | 000 | black / background |
| 1 | 754 | peach (outlines, hourglass frame, yellow key, potion glass) |
| 2 | 111 | dark grey (linework) |
| 3 | 623 | magenta (red shield, lockpick, money-bag tie) |
| 8 | 701 | red (hearts, sand, whip stripe, flames) |
| 12 | 555 | grey (axe head, knife guard) |
| 14 | 777 | white |
| 15 | 007 | **blue** (cross fill, potion liquid, gems) |

Stage palettes (pointer table seg10 `0xBEA7`) only overlay indices
**4, 5, 6, 7, 9, 10, 11, 13**. Room entry (`0x5787`) then applies that room's
table from `9AB0[stage-1][room].palette` — typically 4+6 or 5+7 — so leftover
BIOS values for 4/6 do not survive into play. HUD bonus tiles never use those
slots, so they look the same in every stage. Dumps use `gfxdump.vk_play_palette`
(0xBF6F extras then 0xBF88 fixed). `hud_weapon_icon` maps `C416` 1–4 → bonus
`0x1A`–`0x1D`. Leather (`C416=0`) is a separate tile at VRAM `(80, 0x70)`, not
in these sheets.

### Continuous enemy generators (spawn bitmask)  (CONFIRMED, byte-exact)
- `room_spawner` (seg0 0x5EBF) indexes seg14 **`spawn_bitmask_ptr`** (0x85A6) by stage
  (0xD000), then indexes the resulting byte table by room (0xD001) to fetch a
  **spawn bitmask**. Stage 1's byte table is at **0x85CF**. Bits **0–6** each fire
  one rate-gated generator in seg2 (LSB first). **Bit 7** appears in some mask
  bytes (`0x80`) but is never dispatched.

  | bit | generator (seg2) | actor type | handler (seg3) | enemy |
  |-----|------------------|------------|----------------|-------|
  | 0 | `zombie_generator` 0x9CED | `actor_zombie` | `enemy_zombie_tick` 0xA93B | zombie (100 pts) |
  | 1 | `merman_generator` 0x9D52 | `actor_merman_green` | `enemy_merman_tick` 0xA2E7 | green merman, 1 HP (200 pts) |
  | 2 | `merman_generator_3` 0x9D59 | `actor_merman_red` | same 0xA2E7 | red merman, 2 HP (open-mouth spit) |
  | 3 | `hanging_bat_generator` 0x9D9E | `actor_hanging_bat` | `enemy_hanging_bat_tick` 0xB0D1 | hanging bat (100 pts; generator fly-in. Placed bats that hang first are `actor_placed_bat`) |
  | 4 | `flying_skull_generator` 0x9DCA | `actor_flying_skull` | `enemy_flying_skull_tick` 0xB068 | flying skull (200 pts; homes on Simon X and Y) |
  | 5 | `ghost_head_generator` 0x9DDC | `actor_ghost_head` | `enemy_ghost_head_tick` 0xA502 | ghost head (200 pts; flies across, bobs around spawn Y) |
  | 6 | `roc_generator` 0x9DEE | `actor_roc` | `enemy_roc_tick` 0xB19A | roc (400 pts, 8 HP; flies, pauses, drops `actor_roc_drop`). Manual lists 300. The small hovering raven is `actor_raven`. |

  `spawn_actor` takes **D = X** (slot+05), **E = Y** (slot+03). Zombies typically
  enter at X=0xF0 (right edge) or 0x10 (left), Y=0xC0. Mermen spawn at Y=0xC8
  with X from table `merman_spawn_x`. Hanging bats / flying skulls / ghost heads share `flyer_spawn`: X at
  the screen edge, Y = SimonY−8. The roc is fixed at X=0xE0, Y=0x30 or 0x40,
  and skips the spawn if Simon X ≥ 0xC0.
- Each generator is rate-gated by `spawn_rate_gate` (per-generator 0xCF00+ counter vs a
  threshold table, scaled by the 0xD012 difficulty tier). The spawn **position is
  hardcoded** — it is **NOT** read from the tile map. This is why the small 08/05
  tile pair (see "Room geometry") is *not* a generator: its positions don't line
  up with spawns, and rooms spawn regardless of whether the pair is present.
  Stage 1: rooms 0/1/5/6 spawn zombies (bit0), room 4 spawns bats (bit3).
- Other enemies come from the per-room **object list** (list-id = actor type;
  see "World structure" for the full catalogue). Dogs, pikemen, skeletons,
  ravens, hunchbacks, bone dragons, axe knights, and stage-16 giant bats are
  placed. Spawn-bit types (`actor_zombie`/`actor_merman_green`/`actor_merman_red`/
  `actor_hanging_bat`/`actor_flying_skull`/`actor_ghost_head`/`actor_roc`) are
  not in the list; placed bats and mermen use `actor_placed_bat` and
  `actor_placed_merman` instead (different spawn-init).
  - NOTE: 0xC5E5/0xC5E6 (00->FF/20 at pickup) is the generic pickup-popup message +
    timer set by 0x8F2A for *every* pickup, NOT a rosary-specific state.
- **Hearts** — currency for vendors; also power the hourglass (jump+DOWN) and
  holy water (jump+LEFT/RIGHT), 5 each.
- **Life refills** — small orbs during play, or **vials** bought from vendors.

### Vendors

Full map (whip scripts, `0xD012` difficulty, shop, catalogue): **[docs/vendor.md](vendor.md)**.

A vendor is a hidden cloaked figure, not a `0xC800` actor — two slots at
`0xC5B5`/`0xC5C5`. Attr bits1–0 pick one of four 8-whip scripts. Outcomes
are mutually exclusive: shop, ±5 hearts, shrug, leave (+5000), or ±1 on
the global difficulty byte `0xD012` (same tier hub-clear already bumps;
speed/spawn only, not damage). Script 1 is +5, +5, then one difficulty-up;
script 2 has one difficulty-down on whip 7. Preview: `gfx/vendor.png`.

## Actors (C800 / D700)

Seven **C800** slots (stride `0x80`: C800, C880, … CB80) plus eight **D700**
shot slots of the same layout. `spawn_actor` (seg0 0x5F24) takes C=type,
D=X, E=Y. Type 0 is free. C450/C460 (thrown knife/axe/cross) is a
**different** struct — do not mix (there `ix+3` is velocity).

Shared physics header (`actor_integrate` 0x99C0, velocity helpers in seg3):

| off | meaning |
| ---: | --- |
| +00 | type (0 = free) |
| +01 | per-type sub-state |
| +02 / +03 | Y 16-bit fixed (frac / pixel) |
| +04 / +05 | X 16-bit fixed (frac / pixel) |
| +06 | physics alive (`actor_integrate` skips if 0; spawn writes 0, init usually sets 1) |
| +07 / +08 | signed Y velocity |
| +09 / +0A | signed X velocity |
| +0B | pose id (`pose_*` in `poses.inc`; stream is `shape_*` in `data/actor_shape.asm` / `actor_shape_ptr`). Unused (no store): **0x0A, 0x0D, 0x2D–0x32, 0x76–0x78, 0x8E, 0xA3–0xA4**. **0x58** is intro_0 left (`dracula_intro` stores 0x56+2). Event 6: **0x02 / 0xA5** robe and **0xA6** open / **0xA7** closed head (`actor_dracula_bat`); **0x57 / 0x59** flying SAT head (`actor_dracula_head`); **0x5A** `actor_dracula_chunk`. |
| +0C | timer |
| +0D | HP from `actor_hp_tbl` (0x60E9; spawn indexes as 0x60E8+type) |
| +0E | flags. **bit 0 = hittable** this frame (`rra`/`jr nc` in whip/proj tests; `res 0` on a hit). **bit 1 = contact** vs Simon (`rra`/`rra`/`jr nc` in `actors_vs_simon`). **bit 2** = rearm hittable (`actors_rearm_hittable`). Spawn writes 7. |
| +0F | copied from CFFA at spawn (spawn zeros CFFA first; unused on C800) |
| +10..+1E | per-type scratch (merman spit at +1B, facing, saved Y, …) |
| +1F | drop gate. Spawn copies CFFB (always 0); callers write `ix+1F` after `spawn_actor`. Flame→pickup uses this. |
| +7E | respect Simon-attack freeze: when D010 is set (whip wind-up), `actor_freeze_check` skips type tick + integrate if +7E ≠ 0. Spawn sets 1; flames/pickups clear it. |
| +7F | spawn / `shot_alloc` write 1; no readers found yet |

Hardware SAT is **Y then X**. `actor_sat_build` adds `ix+3` to Y and `ix+5` to
X. Spawn pixel is the feet / hook: walker shapes sit at dy=-16 or -32, 16×16
hang and fly poses use stream `0x81` (dy=-15, dx=-8). Object-list Attr is
**Y<<4|X** (same as scenery); `object_list_spawn` loads high→E (Y) and low→D (X). A
decoder that treated it as X<<4|Y swapped the axes — dogs/bats looked one
cell off on Y whenever the nibbles differed by 1.

Actor Y is screen space (`playfield_draw` paints nametable row 2 at Y=0x20).
`map_cell_at` is `(Y-0x10)>>3`, so Y=0x20 → row 2. Guide maps crop nametable
rows 0–1 then blit the SAT composite at spawn + min(dx,dy) using that same
row formula; subtracting only the 16px HUD crop parked walkers in the floor.
An F8 dump that showed the dog's "X" at +02/+03 was a mis-index of the Y
pixel, not a per-type layout.

SAT sub-block at `slot|0x20`, stride 5 (`actor_sat_patterns` 0x6030,
`actor_sat_assign` 0x604F, `actor_sat_build` / `actor_sat_emit`):

| off | meaning |
| ---: | --- |
| +20 | sprite count (`actor_spr_count`; spawn indexes 0x605E+type; type 1 = 4) |
| +21 + n×5 | SAT index, Y, X, pattern, colour/attr (colour 0 → hide with Y=0xE1) |

`actor_free` walks that block and writes Y=0xE0 into each claimed D638 cell
(`set 5,l` is +0x20, not a linked sub-slot at +0x25).

## Text encoding (CRACKED + converted to ASCII)

DONE: HUD/title strings use the `vk` macro (`vk "PUSH SPACE KEY"`): each
char is (ASCII−0x10), space is 0x00. Position/attr bytes and 0xFE/0xFF
stay as `defb`. Credits use `cr` (ASCII letters, space still 0x00).
The HUD set (`hud_status_str`) and title strings (`title_prompt_str`, `play_start_str`, `game_over_str`)
in seg00 are converted, as are the Game Master menu strings (`gm_menu_text`,
`gm_stage_text`, `gm_player_text`, `gm_continue_text`). `title_layout`
0x4C3F-0x4D0E is `defb`.

**The font's punctuation slots are not ASCII shapes.** `hud_font` covers ASCII
`'0'`-`'_'`, but three of those slots hold symbols rather than the matching
character, so a `vk` string can read very differently from what it draws:

| `vk` char | stream byte | actually drawn |
| --- | --- | --- |
| `@` | 0x30 | a horizontal rule / dash |
| `_` | 0x4F | a right-pointing arrow (used as the menu cursor) |
| `?` | 0x2F | an equals sign |

So `vk "@@@MENU@@@"` renders `---MENU---` and `vk "STAGE NUMBER?"` renders
`STAGE NUMBER=`. Keep the `vk` spelling (it is what reproduces the bytes) and
note the real glyph in a comment.

## Sprites (format understood; data still in banked ROM)

- VK uses MSX2 hardware sprites; seg00 sets VDP regs (see `sub_47d6`/`palette_set`)
  and the title builder loads graphics from pointers into the 0x8000-0xBFFF banks
  (e.g. `ld hl,0x930b` / `0xb70b` at 0x4557/0x4562) - so sprite/tile BITMAPS live
  in the graphics segments (4-15), not seg00.
- Actor SAT comes from the C800/D700 slot: pose `ix+0B` selects a seg6 shape
  stream via `actor_shape_ptr`; `actor_sat_build` writes Y/X/pattern into the 5-byte cells
  at `slot|0x20`. See [Actors (C800 / D700)](#actors-c800--d700).
- Pixel patterns are 1bpp RLE into VRAM 0xF800+ (per-room gfx scripts), not a
  Metal Gear-style 32-byte pattern array in ROM.

### Text encoding details

Text is stored as **tile codes = ASCII - 0x10** (so decode with `+0x10`).
Cross-checked against the Metal Gear disassembly (which stores text as plain
ASCII); Vampire Killer offsets HUD/title text by 0x10 because `hud_font`
(seg8 0xBD80) is the ASCII range `'0'`–`'_'` uploaded at atlas ids 0x20+.
Digits '0'-'9' = tiles 0x20-0x29 (confirmed by the score renderer `hud_draw_digit`:
`and 0x0F / add 0x20`). `0x00` = space/blank (HMMM from VRAM (0,0), the
ink-0 blit of `hud_font_solid`); `0xFE` and `0xFF` are line/record control
bytes; other high bytes (0x48,0xA0,0x58,0xD1...) are VDP position/attribute
prefixes. The `vk` macro in `VampireKiller.asm` authors these.

**Exception: ending credits** store letters as ASCII (no −0x10), but space
is still `0x00` and the record ends with `0xFF`. The `cr` macro maps spaces
to NUL; a raw `defb "..."` would emit `0x20` and be wrong. See *Ending /
credits* above.

### Front-end / HUD strings found in segment 0 (runtime addresses)
- 0x4C09 `SCORE`, 0x4C11 `PLAYER`, 0x4C19 `<icon>ENEMY`, 0x4C2D `STAGE`
- 0x4C3F-0x4D08: tile-layout / logo arrangement data (NOT text)
- 0x4D13 `KONAMI`, 0x4D1A `1986`
- 0x4D21 `PUSH`, 0x4D26 `SPACE`, 0x4D2C `KEY`
- 0x4D34 `PLAY`, 0x4D39 `START`
- 0x4D43 `GAME`, 0x4D49 `OVER`
Data region is `hud_status_str` .. 0x4D4D (right before `title_build`, the title builder).
`0x4C00-0x4C06` is real code (a keyboard-read routine).

HUD/title strings are authored with `vk` (ASCII−0x10) in seg0 `hud_status_str` /
`title_prompt_str`. The HUD/title glyphs are seg8 `hud_font` (0xBD80: 48 × 8×8 1bpp,
ASCII `'0'`–`'_'`), one `defb %xxxxxxxx` row per scanline in
`segments/data/font_hud.asm`. `hud_font_load` (seg0 0x53BD, from
`title_build`) expands them via `glyph_blit_run` (ink C=0x0E) onto VRAM
page 1 at Y=`0x40`. Drawing is HMMM from that atlas (`hud_glyph_blit`, source Y
+= `0x38`). Sheet: `gfx/fonts/font_hud.png` (`make gfx`). The 8x8 1bpp
ending-credits glyphs are a different sheet in `segments/data/font_credits.asm`:
seg14 `credits_font` (0x8824: digits 0-9 then `. ' : ,`) and `credits_font_az`
(0x8894: A-Z). `credits_font_load` (seg0 0x53E5) is called from `credits_init`
and blits them via `glyph_blit_run` (ink C=0x0E). Sheet: `gfx/fonts/font_credits.png`.
The boot Konami logo is a third 1bpp sheet: seg13 `logo_font` (0xBE59: 52 × 8×8,
tile ids `0x01`–`0x34`) in `segments/data/font_logo.asm`. `logo_font_load`
(seg0 0x5316, from `konami_logo_draw`) blits three ink groups onto page 0 at
Y=0; `tile_string_draw` copies them with no HUD `+0x38`. Logo ids `0x2C`–
`0x2E` are wordmark cells, not `hud_font` `'<'` `'='` `'>'`. Sheet:
`gfx/fonts/font_logo.png`.

### PSG driver (seg14)

`int_handler` pages segs 14+15 and calls `sound_tick` (0x8964). `play_sound`
ids: 0 stop, 1-0x1D sfx (`sfx_tbl`), 0x80-0x8F music (`music_ptr`, 3 channel
pointers each; stage table is seg1 `stage_bgm_tbl`), 0xFB/0xFD overlays
(hourglass freeze / death-style), 0xFC/0xFE restore, 0xFF fade. Packed
streams (`data/psg_sfx.asm` / `data/psg_music.asm`) use the WAV
catalogue names: `sfx_{id}_{name}` and `music_{id}_{name}_{a,b,c}`
(hyphens in stems become `_`). Id 0x89 is Simon death; 0x8B is GAME OVER.
`tools/psgplay.py` (`make music` / `make sfx`) drives `tools/workbench/konami/psgplay.py`
with VK table addresses / names and writes `music/*.wav` (ids `0x80`–`0x8E`;
`0x8F` is silence) and `sfx/*.wav` (play_sound 1–0x1D; `{id}_{name}` like BGM).
After the last
channel stream (`music_8f_silence`) sit `music_phrases` (0xA820–0xAAD5): 43
`sound_cmd_call` (`ED`) / `sound_cmd_return` (`EE`) bodies that `music_ptr`
tracks jump into; they are not channel starts. SFX ids are
named from call sites in `sfx_tbl`. The renderer uses AY-3-8910 timing
(fmaster/8, 16-step hardware envelope); still no speaker filter, and BGM
loop/fade is heuristic. Channel RAM:
C010..C016 tick pointers, 20-byte blocks at C01C/C030/C044/C058/C06C/C080,
C097 mixer shadow, C098 overlay flags, C0A5 fade. Music bytecode commands
are named in the driver (`sound_cmd_scale` / `_ext` / `_octave` / `_jump` /
`_call` / `_return` / `_stop`, `sound_loop_set`); sfx ops likewise
(`sound_sfx_op`, `_loop`, `_mix`).

## Code layout & where the "main loop" is

There is no classic `while(1)` loop. Boot parks the CPU in a spin (`jr $` at
0x40C3); everything runs off the 60 Hz timer interrupt `H.TIMI` -> `int_handler`
(0x4028), which each frame calls the game tick `main_tick`. That tick is the
master state machine (primary state 0xC000 -> `main_state_tbl`).

Segment 0 is the resident **kernel/orchestrator** only: interrupt handler, frame
tick + state dispatch, graphics/RLE loaders, bank switching, and the
entity-dispatch shell at 0x5FD0. All 14 `main_state_tbl` handlers live in seg0
(0x417D-0x441B) but are thin - they call out into banked ROM:
- state 0 (logo): `call 0x6253`   state 3 (intro): `intro_scene_build` 0x63DA
- per-entity behaviour (player/enemy AI) via `entity_tbl` -> 0xA000+ (spawn
  init). Per-frame C800 ticks go through `actor_type_tick` / `actor_tick_tbl`
  (seg2 0x9942; most entries skip the spawn-init/splash). Boss-clear after
  `CE0B` is `room_event_ce10` (`DISPATCH_A` on `CE10`: cull, orb, heal, done).

During normal play the default banks (set by `page_play_banks`) are seg 1 @ 0x6000,
seg 2 @ 0x8000, seg 3 @ 0xA000. So the substantive gameplay (movement, AI,
collision, item logic) lives in **code segments 1/2/3** (`INCLUDE`'d, still being
annotated).  Map tables are banks 11-12; tileset banks 4-8 are labeled source.
Seg 15 is labeled music tails / env tables / Dracula portrait.  Segs 9-10 are
labeled gfx-script / palette / enemy+weapon RLE / vendor 32x32 source.

## Graphics format (sprite/tile hunt)

Video mode is **SCREEN 5** (VDP mode G4: 256x212, 16 colours, 4 bits/pixel
bitmap). Set in `video_init`: `ld a,5 / call CHGMOD (0x005f)`. Consequences:

- Backgrounds/tiles/logos are stored as **4bpp bitmap data** (high nibble = left
  pixel, colour index 0-15, colour 0 = transparent/background) and reach VRAM
  two ways. Bulk pixels go through `vram_write` (OTIR) wrapped by the tile
  blitters `vram_blit_tile8` / `vram_blit_tile16` / `vram_blit_tile_run`
  (0x80-byte scanline stride), and `vendor_blit_32` stamps a 32x32 as a 4x4
  grid of them. Everything else uses the **VDP command engine** (`out (c)`
  streams to R17-indirect + the command registers): `vdp_hmmm` / `vdp_lmmm`
  copy VRAM to VRAM, `vdp_hmmc` pushes CPU bytes in, `vdp_hmmv` fills a
  rectangle, and `vdp_line_h` / `vdp_line_v` / `vdp_box` draw the HUD and panel
  borders. All of them wait on `vdp_cmd_wait` (S#2 CE via `vdp_status_read`)
  first. Nothing here is a 1bpp pattern table.
- Actors (Simon, enemies, items) are drawn with **hardware sprites** (mode 2,
  16x16, **1bpp** patterns). A multicolour character is built from several 1bpp
  planes the VDP OR-combines (the `CC` bit, 0x40, in the sprite colour byte), so
  large characters are grids of hardware sprites; the sprite attribute table is
  assembled in seg1 (`simon_sat_build` / `actor_sat_build`). Only the background
  is 4bpp - the sprites are never 4bpp.
  Evidence: seg13/0xA319 patterns alternate sparse/dense pixel counts
  (52,164, 49,145, ...), each sparse plane nearly a subset of the next dense
  one - so `intro_simon` is 8 two-plane sprites, not 16 frames. PNG previews
  keep each plane as its own cell so dest ids stay 1:1 with the stream.

The 16-colour VDP palette is programmed by `palette_set` / `palette_apply`. Eight indices
(0, 1, 2, 3, 8, 12, 14, 15) are fixed by `palette_hud_load` (seg10 `0xBF88`) and never
changed by stage palettes — HUD bonus tiles use only those. See *HUD bonus tiles*.

Bank classification (by entropy / zero-fill, `tools/workbench/msx/gfxview.py` + a quick scan):
- **seg 0-3**: code (entropy ~7, top byte 0xCD/0xC4/0xDD opcodes).
- **seg 4-9, 15**: 4bpp bitmap graphics (low entropy 4.3-5.5, zero-heavy, a
  single dominant background colour). These hold the title logo, HUD, stage and
  actor artwork.
- **seg 10-14**: mixed code + data tables.

(Earlier note corrected: `hud_panel_frames` at 0x454C is not a graphics copy.
Its `0x7F0B` / `0x930B` / `0xB70B` and `0x1212` / `0x2212` / `0x4212` operands are
`vdp_box` coordinates — three HUD panel outlines on the top row, not ROM
addresses and VRAM destinations.)

### Graphics are RLE-compressed (format cracked)

Graphics ROM data is **not** raw pixels - it is packed with a small RLE scheme
and unpacked straight into VRAM by the decompressor `rle_dec` / `rle_dec_addr`
(0x46F2). `vdp_set_write` sets the VRAM write pointer from HL; the stream is then
streamed to data port 0x98. Control-byte grammar:

| byte        | meaning                                        |
|-------------|------------------------------------------------|
| `0x00`      | end of stream                                  |
| `0x80 lo hi`| set VRAM write pointer = `hi<<8 | lo`           |
| `0x01..0x7F`| RUN: repeat the next single byte N times       |
| `0x81..0xFF`| LITERAL: copy `N & 0x7F` bytes verbatim         |

Callers pass `HL` = VRAM dest, `DE` = ROM source, e.g. (segment 0, ~0x5688):

```
call page_map_banks            ; page seg 13 into 0xA000-0xBFFF
ld hl,0f800h ; ld de,0a319h ; call rle_dec   ; -> sprite pattern gen table
ld hl,0f840h ; ld de,0a351h ; call rle_dec   ; next 2 sprites ...
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
- `page_map_banks` -> seg 11 @ 0x6000, seg 12 @ 0x8000, seg 13 @ 0xA000  (level/sprite gfx)
- `page_title_banks` -> seg  9 @ 0x8000, seg 10 @ 0xA000                   (front-end/title gfx)
- `page_tileset_banks` -> seg  4 @ 0x6000, seg  5 @ 0x8000, seg  6 @ 0xA000  (tileset banks; `actor_shape_ptr` at 0xB473, HUD keys/weapons at 0xB9C8)
- `page_play_banks` -> seg  1 @ 0x6000, seg  2 @ 0x8000, seg  3 @ 0xA000  (default/game banks)

So a page-2b source `0xAxxx` read right after `page_map_banks` maps to file offset
`13*0x2000 + (addr-0xA000)` (e.g. 0xA319 -> file 0x1A319).

### Per-room gfx scripts (enemy sprite VRAM)

`room_gfx_load` (seg0 0x5787), called from the screen builder, pages seg9/10
then indexes `room_gfx_ptr` (`9AB0[D000-1]`) + `4*D001`. Four bytes per room:
script word, then palette table (fed to `palette_apply`). Stage 0 skips. The script
is walked by `gfx_script_run` (0x471B):

| cmd | payload | handler |
|-----|---------|---------|
| `0xFF` | — | end |
| `0` | src word, VRAM dest word | `gfx_script_rle` → `rle_dec` (seg9 if src `0x8000-9FFF`, seg10 if `0xA000-BFFF`) |
| `1` | src, count, dest | `gfx_script_convert` 1bpp quadrant convert |
| else | 6 bytes | `gfx_script_copy` VRAM blit — unused by the 21 room scripts |

There are **24 back-to-back scripts** at `0x9D38-0x9FFE` (21 used by rooms,
plus two unused and frontend `gfx_script_9fed`). **30 unique cmd-0 RLE
sources** plus weapons/vdoor/orphans live in `data/enemy_sprite_rle.asm`
(pixel payloads as `defb %xxxxxxxx`, same as the credits font; run/literal
counts stay hex). Every dest is sprite-generator VRAM (`FA00`, `FB80`, `FBC0`, `FC00`,
`FC80`, `FD00`, `FD40`, `FE00`, `FE40`, `FE80`, `FEC0`) — not Simon (`F800`) or
projectile weapons (`F8C0`). Playfield tilesets are a separate load (seg4-6 via
`page_tileset_banks`), not these scripts. Packed 1bpp sprite asms dump to
`gfx/sprites/<stem>.png` (`enemy_sprite_rle`, `simon_rle`, `intro_sky`,
`title_jp_sprites`): every 16×16 plane, SAT colour, labelled by VRAM dest.
Seg13 `0xA319+` is
`intro_simon` then the `simon_cell0/1` streams, not leftover enemy art.

### Playfield tilesets

`load_stage_tileset` (seg0 0x5653), first call in the screen builder, pages
seg 4/5/6 (`page_tileset_banks`; stage ≥ 13 overlays seg 7/8 via `page_tileset_late`) and blits
**0xBF uncompressed 8×8 4bpp** tiles from `tileset_ptr[D000]` into SCREEN 5
VRAM starting `0x8004` (`vram_blit_tile_run` / `vram_blit_tile8`, 32 bytes/tile). That dest is
X=8 on page 1, so nametable id 0 samples unloaded VRAM (blank / colour 0) and
id N is ROM tile N−1 (`tile_atlas_pos`: SX=(A&0x1F)*8, SY=(A&0xE0)>>2). The
playfield drawer (`0x4F98`) paints 22 rows from `0xD140` (map rows 2–23).
Eight unique sources (courtyard; stages 1-3 / 4-6 / 7-9 / 10-12 / 13-15 /
16-17; Dracula). Sets overlap in ROM, so each `segments/data/tileset_*.asm`
is a unique byte range, not a full 0xBF-tile copy (s04's blit continues
through `tileset_s10`). `page_tileset_banks` maps segs 4–6 as one 24K
window, so spilling sets are one file (`tileset_s01` crosses 0x8000,
`tileset_s10` crosses 0xA000); segs 7–8 are the same for `tileset_s16`.
`make gfx` writes one sheet per 4bpp tileset asm under `gfx/tilesets/`
(same stem as the `.asm`; cell header is the CPU address) and one sheet
per metatile-def table under `gfx/metatiles/` (4×4 composed from the
tileset; s00 / s18 are one file each) plus 8×6 stream catalogues
(`mtile_streams.png`, one stage per row; `mtile_stream_intro.png`). Playfield files
and `intro_tiles` are 8×8 (32 bytes/tile). `bonus_hud_tiles` (seg9 `0x9000`)
and `dracula_portrait_parts` (seg15 `0xBBD8`) and `hud_weapon_key_tiles`
(seg6 `0xB9C8`) are 16×16 (`vram_blit_tile16`, 128 bytes each). Pixel rooms: `gfx/stage_sNN.png` (nametable
ids, HUD rows cropped). Event 6 (`dracula_portrait_load` 0x5887) then overlays
seg15 frame tiles plus 108 face tiles at atlas ids 0x1E–0x89, H-mirrors them
to 0x8A–0xF5, and V-mirrors the frame for the bottom edge. Tileset banks 4–8
are labeled source (`tileset_s00` at 0x6000, overlapping/spilling sets in
`segments/data/tileset_sNN.asm`, `actor_shape_ptr` at 0xB473, `hud_weapon_key_tiles` at 0xB9C8). Each 8×8
tile is eight `defb` rows (4 bytes = 8 pixels; high nibble = left); each 16×16
is sixteen 8-byte rows. `make gfx` PNG previews are derived, not the assemble
source.

### Tools for the graphics pipeline

- `tools/workbench/konami/rledec.py <rom> <src-off> --dest 0xF800 --out x.bin` replays the RLE
  grammar above to extract a decompressed block.
- `tools/workbench/msx/gfxview.py x.bin 0 --bpp 1 --size 16 --count 16 --cols 8` renders 16x16
  1bpp sprites as ASCII art (also `--bpp 4` for SCREEN 5 tiles, `--raw` bitmaps).
- `tools/workbench/konami/rleenc.py x.bin --verify <rom> <src-off>` re-packs a flat buffer. It is
  an optimal-length packer and always round-trips, but does NOT always reproduce
  Konami's exact bytes (their packer uses a specific tie-break for equal-cost
  run/literal splits; measured ~1-3/10 exact). This is why the catalogue keeps
  the original compressed bytes authoritative rather than assembling from source.

### Editable graphics catalogue (chosen workflow: "path A")

The committed build stays byte-exact because identified graphics are stored as
the original bytes (labeled `defb` for uncompressed tilesets / metatiles; packed
1bpp sprite RLE with `%xxxxxxxx` pixel rows; hex PSG / unidentified slices).
PNG copies live in `gfx/`, generated by `tools/gfxdump.py` (`make gfx`):
- `gfx/<name>.png` - derived sheets (composites, `unused_poses.png`)
- `gfx/fonts/<stem>.png` - 1bpp font asms (`font_credits`, `font_hud`,
  `font_logo`)
- `gfx/sprites/<stem>.png` - packed 1bpp sprite-asm sheets
  (`enemy_sprite_rle`, `simon_rle`, `intro_sky`, `title_jp_sprites`) plus
  `unused_*.png` orphans / unid
- `gfx/tilesets/<stem>.png` - 4bpp tileset sheets plus `unused_tiles.png`
- `gfx/metatiles/<stem>.png` - 4x4 metatile-def sheets and 8x6 room streams
PNG sheets are committed; the packed/uncompressed bytes in `segments/data/`
are the assemble source. Unused inventory: `docs/unused.md`.

Catalogued so far:
- `intro_simon` / `simon_cell0` / `simon_cell1` / `intro_sky` — packed streams
  in `data/simon_rle.asm` and `data/intro_sky.asm` (sheets
  `gfx/sprites/simon_rle.png`, `gfx/sprites/intro_sky.png`). Intro: 8 two-plane
  Simon sprites then clouds/bat at VRAM 0xFA00. Cell 0 = legs (`0xA281` /
  `0xC42E`); cell 1 = torso/whip (`0xA2D1` / `0xC42F`).
- `weapon_knife` / `weapon_axe` / `weapon_cross` - seg10 streams in
  `data/enemy_sprite_rle.asm` (`weapon_sprite_ptr`, seg0 0x55DE).
  `load_weapon_sprites` (0x559A) RLE-decompresses to VRAM 0xF8C0 then
  `gfx_script_convert` converts 1bpp quadrants. Knife = 2 patterns; axe/cross
  = 4. In-game SAT for Simon's body is `simon_sat_cell0/1` (seg1 0x798C/0x79DC).
- `gfx/fonts/font_credits.png` - 40 x 8x8 1bpp ending-credits glyphs from seg14
  `credits_font` (`data/font_credits.asm`; 0-9 `. ' : ,` A-Z). Raw, not RLE;
  loaded by `credits_init`.
- `gfx/fonts/font_hud.png` - 48 x 8x8 1bpp HUD/title glyphs from seg8 `hud_font`
  (`data/font_hud.asm`; `'0'`–`'_'`). Raw, not RLE; loaded by `hud_font_load`
  from `title_build`.
- `gfx/sprites/title_jp_sprites.png` - every 16×16 plane in
  `data/title_jp_sprites.asm`. JP `title_load_tiles` only (`rle_dec_addr` to
  VRAM 0xF800). SAT colour 8 (hud_fixed red) or 2 (forced black), not stacked.
- `gfx/fonts/font_logo.png` - 52 x 8x8 1bpp boot Konami-logo glyphs from seg13 `logo_font`
  (`data/font_logo.asm`; tile ids `01`–`34`). Raw, not RLE; loaded by
  `logo_font_load` from `konami_logo_draw`. Not `hud_font` (overlapping ids
  `2C`–`2E` are a different bitmap).
- `gfx/enemy_sheet.png` - one labelled frame per `entity_tbl` type `01`–`22`, plus
  candle-blob recolours **1A/1B/1C** (`make gfx`). Each frame is cropped to
  the SAT cells it actually occupies (16×16, 16×32, 32×16, … — type `16` is
  40×48) and packed, rather than a uniform 64×64 cell. The label is
  `HH WxH` (hex type id, decimal SAT size in source pixels).
  Layout from `actor_shape_ptr` (`ix+0B`); pixels from the per-room
  gfx-script RLE into VRAM 0xF800+ (plus the 0x4745 1bpp convert). Two-plane SAT
  colours with CC (`0x40`) OR the colour indices (2+4→6). Palette is the
  playfield sequence: HUD-fixed (`palette_hud_load`) + `0xBEA7[stage]` + the per-room
  overlay at `9AB0[stage][room]` (same room that supplied the sprite VRAM).
  Types 7/10 only use HUD-fixed 2/12/14, so they ignore the overlay. Type **9**
  is the red skeleton (stage 13; SAT `02 45`; faster walk, no projectile). Type
  **11** is the white skeleton (`02 4C`, same 0x9FB2 sprite script): kites Simon,
  hops gaps, throws a spinning bone (shot type 4, shapes `0x4B–0x4E`). Type **16**
  is the axe knight (stages 14+; same SAT layout as 9, throws via `shot_throw`
  0x9F68). Type **14**
  bypasses `0x644C` (custom SAT in its tick). Type **17** is figure Dracula
  (stage 18 room 9, then portrait Dracula is a separate wall event): standing
  shape `0x5B` is SAT head + cape; the 32×32 middle is `dracula_blit_torso`
  (LMMM from `dracula_torso_src` onto `(X-16, Y=0x91)`). Those slots are packed
  4bpp `dracula_body_closed` / `dracula_body_open` (seg13 0xB5A1 / 0xB719)
  loaded to page-1 Y=`0x80` by `dracula_body_load`. The 16×16s at page-1 Y=`0xA0`
  (`dracula_portrait_parts`) are the wall portrait's eyes and mouth — closed
  during the figure fight, then animated after he dies (`dracula_ce35_tick`:
  `dracula_blit_eyes_open`/`_closed`, mouth closed/open; the in-between frame
  composites those two, there is no mid-mouth tile). Event 6 also spawns
  **type 0x2E** `actor_dracula_chunk` (six debris chunks after type 17 dies; shape `0x5A`), **type
  0x2D** `actor_dracula_head` (intro SAT head `0x57`/`0x59` arcs away after `dracula_summon`), and **type
  0x2C** `actor_dracula_bat` (robe `0x02` / `0xA5`, then head `0xA6` open /
  `0xA7` closed, then hanging-bat fly `0x1B–0x20`). `make gfx` composites
  the standing cloak into `enemy_sheet.png`.  The two stored 32×32 frames
  are also `gfx/tilesets/dracula_body.png`.
  Type **21** is Frankenstein (`0x79`); type 13/24 share the hunchback pose
  `0x67`. Types **0x1A/0x1B/0x1C** are `actor_blob_blue` / `_red` / `_white`
  (`spr_blob` fill / `spr_blob_cc` outline at FE80+; SAT `0F 42` / `08 42` /
  `0E 42` — HUD-fixed indices 15/8/14), appended as **1A/1B/1C**.
  Boss types use the event-room tileset. Derived (`make gfx`).
- `gfx/sheet_enemy_<name>_<id>.png` - every `ix+0B` pose for one actor (same
  compositor as `enemy_sheet.png`). Filename id is the hex type (`sheet_enemy_axe_knight_10`);
  the cell label is the hex shape id only (no `WxH`). Type 14 labels are SAT
  head patterns (`80` idle / `70` spit). Types **14** and **21** have no
  convert facing (Frankenstein reuses `0x79–0x7B` both ways; the bone dragon
  SAT is always the stored layout). Skull pile is `04`/`05` (the
  FE00 pair); `06`/`07` are the same art at FE40. Raven includes `8C` (convert
  of `89`). Blob `0x9D–0xA2` are dest retargets of `0x9B/0x9C`.
  Igor (`actor_igor`, type `18`) gets his own sheet; he is not on the group
  sheet. Defeat chunk `0x5A` is on the type-17 sheet. Same `make gfx` pass.
- `vendor.png` - the cloaked sitting vendor as five 32×32 colour variants
  (C70B 0..4: hearts / hit / flash / idle / difficulty). Assembled from
  `data/vendor_tiles.asm` plus `vendor_tile_ptr` / `vendor_recolor_tbl`.
  Palette is HUD-fixed. Derived (`make gfx`); the 8 source 8×8s are also
  `gfx/tilesets/vendor_tiles.png`.
- `gfx/fonts/<stem>.png` - 1bpp glyph asms (`font_credits`, `font_hud`,
  `font_logo`). Cell header is the hex tile id. HUD-fixed ink 14.
  Same `make gfx` pass.
- `gfx/sprites/<stem>.png` - one sheet per packed 1bpp sprite asm
  (`enemy_sprite_rle`, `simon_rle`, `intro_sky`, `title_jp_sprites`).
  Cell header is the VRAM dest. One 16×16 plane per cell (no CC overlay).
  Enemy streams use that actor's SAT index in the room playfield palette;
  Simon is HUD-fixed 1 (peach) / 2 (grey); intro sky is intro-palette white;
  JP title is SAT 8 / 2. Same `make gfx` pass as the tileset sheets.
- `tilesets/<stem>.png` - one sheet per 4bpp tileset asm
  (`tileset_s00.asm` → `tilesets/tileset_s00.png`, plus `tileset_s08_pad`,
  `intro_tiles`, `bonus_hud_tiles`, `hud_weapon_key_tiles`,
  `dracula_portrait`, `dracula_portrait_parts`, `vendor_tiles`,
  `spike_bar`, `dracula_body`). Cell header is the CPU
  address (4 hex digits).
  Playfield files use that stage's palette; intro uses `intro_palette_load`;
  bonus HUD and HUD keys/weapons / vendor 8×8s use HUD-fixed; portrait uses HUD-fixed then
  `0xBF6F`; `spike_bar` uses stage 6 room 1 playfield; `dracula_body` uses
  stage 18 room 9. 8×8 files are every 32-byte tile; `bonus_hud_tiles`,
  `hud_weapon_key_tiles`, and `dracula_portrait_parts` are 16×16.
  `spike_bar` is the 8×4 mount (padded to 8×8) plus the 8×8 spike.
  `dracula_body` is two packed 32×32 frames (cloak / chest-open).
- `palettes/<stem>.png` - one sheet per palette_apply asm
  (`stage_palettes.asm`, `room_palettes.asm`). 16 columns = VDP indices
  0–F, one row per table. Defined slots are a solid 8×8 of that entry's
  RGB; cell header is the CPU address of the 3-byte record. Unused slots
  are `OFF` / unlabeled. `pal_9ffe` is stitched from `room_gfx.asm`.
- `metatiles/<stem>.png` - one sheet per 4×4 metatile-def table
  (`mtile_defs_s00` → `metatiles/mtile_defs_s00.png`, plus `s01`..`s18`
  and `mtile_def_intro`). Bank-straddle tables (`s00`, `s18`) are one
  file each. Cell header is the CPU address of the def. Each cell is
  the 32×32 composed from the matching tileset (nametable id 0 blank,
  id N = ROM tile N−1). Playfield tables use that stage's palette;
  `mtile_def_intro` uses the intro palette. Stage 18 Dracula-room defs
  compose from `dracula_portrait_load` (frame overlay from nametable id 6),
  not the title-tiles tail of s18's 0xBF blit.
- `metatiles/mtile_streams.png` - 156 rooms, one stage per row, rooms
  left to right (12 columns; unused cells unlabeled). Each cell is the
  256×192 nametable (HUD not cropped) from that 48-byte stream; header
  is the CPU address (`617B`, …). Per-room `vk_playfield_palette`;
  stage 18 room 9 uses the event-6 portrait atlas.
  `metatiles/mtile_stream_intro.png` is the 0xC41A walk-up (`614B`).
  Geographic/minimap composites stay on `stage_sNN.png` (HUD cropped).
- `stage_sNN.png` - per-stage playfield (`roomperm.py --composite` via `make gfx`;
  `--pixels` is the same rooms with no scenery/enemy overlay):
  nametable id N → ROM tile N−1 (id 0 blank — blit starts at VRAM 0x8004),
  per-room playfield palette, HUD rows cropped. `make gfx` emits these
  alongside the tileset sheets. Stage 18 room 9 overlays `dracula_portrait_load`
  (seg0 0x5887): seg15 frame + 108 face tiles, H-mirrored to ids 0x8A–0xF5.
  Palette is `dracula_portrait_palette` (0x59F3): HUD-fixed then 0xBF6F
  pink/flesh, which replaces stage 18's purple on indices 4–7.

In-game Simon is two stacked, independently-animated 16x16 hardware-sprite cells
(legs + torso/whip), refreshed each frame by `load_simon_sprites` (seg0 0x56E8):
it reads the two frame indices (0xC42E legs, 0xC42F torso), looks up the seg13
pointer tables (0xA281 / 0xA2D1), and RLE-decompresses the chosen streams into the
sprite pattern generator (0xF800 = cell 0, 0xF840 = cell 1).  The two-table design
is why legs and upper body can animate on different cadences (e.g. whipping while
standing still).

Pixel room sheets are `gfx/stage_sNN.png` (`roomperm.py --all --composite`;
also `make gfx`). `--pixels` is the unannotated playfield. Candle blob is on `enemy_sheet.png` as **1A/1B/1C**. Gfx banks
4–10 and 15 are labeled dumps.

## Reference: Metal Gear disassembly

[GuillianSeed/MetalGear](https://github.com/GuillianSeed/MetalGear). Same Konami MSX2 engine
era; very useful for shared idioms. Notable files:
- `data/texts.asm`, `gfx/font.asm` - text/charset (confirmed ASCII scheme)
- `constants/structures.asm` - sprite/object (OBJ) struct layout
- `data/spritesets.asm`, `data/*spriteattr*.asm`, `gfx/sprites.asm` - sprite data
Use these to guide VK's sprite/OBJ format next (the entity struct is the `ix`-based
record used by the entity dispatch at 0x5FD0 / `entity_tbl`).

## Open questions to resolve in code

- **Play-window `lXXXXh` locals** — banks 0–3 still have 795 z80dasm local
  labels (no `sub_XXXXh` left). Tackle in `docs/progress.md` “Play-window
  labels”; rename only with a confirmed purpose.
- Graphics / map / sound banks are labelled `.asm` end to end. Leftover
  identification (orphans, `seg10_unid_b50b`, unused poses, bank-end pads)
  is inventoried in **[docs/unused.md](unused.md)**; dumpable slices are
  `gfx/sprites/unused_*.png`, `gfx/tilesets/unused_tiles.png`,
  `gfx/unused_poses.png`.
- Per-level / per-boss data tables (which bank they live in). Boss CE01
  machines for events 1–6 are named; leftover is other unnamed tables.

### Deferred constants / naming (do not put in `msx.sym`)

Small numeric `equ`s live in `segments/*.inc`. Packed data already uses
them: `actors.inc` (types + spawn bits), `items.inc`, `weapon.inc`
(`equip_*`), `sfx.inc`, `poses.inc`, `scenery.inc`, `event.inc`
(`evt_*`), `state.inc` (`main_*` / `act_*`), `dir.inc` (`dir_*`). Id prefixes were chosen so they
do **not** collide with ROM labels:

| Ids | Prefix | Do not reuse |
|-----|--------|----------------|
| pickup / drop | `item_*` | `bonus_*` collect handlers in `banks_0123` |
| C416 equipped | `equip_*` | `weapon_*` thrown-sprite streams in `enemy_sprite_rle.asm` |
| ix+0B pose | `pose_*` | `shape_*` SAT streams in `data/actor_shape.asm` |
| `play_sound` | `sfx_*` / `bgm_*` | `sfx_NN_*` bytecode streams |
| CE00 cell event | `evt_*` | `event_*` CE01 machines (`event_giant_bat`, …) |
| C000 primary | `main_*` | `state_*` handlers (`state_play`, …) |
| C420 action | `act_*` | `simon_*` handlers (`simon_dying`, …) |
| C41B pending exit | `dir_*` | `permit_*` RAM; `room_edge_*` labels |

`collect_bonus_tbl` stays handler addresses (`defw bonus_small_heart`), not
item ids. Vendor scenery attrs stay hex (bits5–2 = offer slot, not `item_*`).

**Skip / return later — constants**

- **Jump tables that are already ROM labels** (`entity_tbl`, `actor_hp_tbl`,
  `collect_bonus_tbl`, `main_state_tbl`, `simon_action_tbl`) stay in
  `msx.sym` and next to their dispatchers. Do not duplicate them as `equ`s
  or peel them into `data/`.
- **RAM / play-bank immediates** — `segments/ram.inc` covers the confirmed
  cluster (`lives`, `weapon_id`, `health`, `stage`, `simon_action`,
  `simon_whip`, `simon_jump_dir`, `simon_hurt_step`, `simon_arc`, `simon_facing`,
  `simon_invuln`, `bonus_flags`, `sapphire_ring`, `swing_weapon`, `blue_gem`,
  `hourglass_timer`, `hurt_facing`, `rosary_timer`, `simon_on_plat`,
  `cell_event`, `scenery_slots`, `pickup_slots`, `spike_slots`,
  `platform_slots`, `door_state`, `actor_slots`,
  `shot_slots`, `spawn_slot_*`, …).
  Play banks use `sfx_*` / `equip_*` / `pose_*` / `actor_*` / `item_*` /
  `evt_*` / `main_*` / `act_*` / `dir_*` at call sites (`evt_*` at `cell_event_tbl`
  and CE00 compares; `main_*` / `act_*` at the two jump tables and the
  id loads that feed them; `dir_*` at `room_edge_detect` stores and
  `dir_portal` at the spot write). Regen still emits hex; re-apply after
  regen-bank. Leftover hex is on purpose (ambiguous small literals,
  unnamed SAT ids).  CE03 has a `shot_alloc` reader and no ROM writer
  (always 0 after the run wipe); CE08 is `flame_spawn++` / `cell_event_set`
  zero with no reader. `0xC000` is not a ram.inc name: VRAM HUD cells use
  the same numeric address.

**Skip / return later — data left in the bank files**

Code stays in the bank asms (`conn_lookup`, `door_load`, `spot_load_coords`,
`sound_tick`). Also left in place on purpose:

- **`sfx_tbl` / `sfx_ptr` / `music_ptr`** — pointer tables glued to
  `sound_tick` (same pattern as `entity_tbl` next to spawn). Peel only if
  we want `banks_ef` to be driver-only.
- **Door 8×8 tiles** in `banks_0123` — tiny; they live next to
  `door_blit_tiles`.
- **Do not merge** `mtile_stream_intro` and `mtile_streams`. They are
  contiguous in ROM (`0x614B` / `0x617B`) but different loaders (`0xC41A`
  vs `mtile_roomptr`).
- **Emitters** for the hand-extracted tables (`scenery_lists`,
  `spawn_masks`, `object_lists`, `mtile_index`, `mtile_defbase`,
  `conn_tbl`, `door_tbl`, `spot_tbl`) are not in
  `tools/emit_identified_data.py`. A full emit would not regenerate them;
  add emitters if we want ROM-round-trip dumps.
- **Named zeros** — empty spawn masks are still `000h` (could be
  `spawn_none`); bare `scenery_block32` is kind with item 0 (could OR
  `item_none`). Cosmetic.

- **Symbol collisions across banks — handled at regen.** `segments/msx.sym` stays
  one catalog, but z80dasm `-S` is flat, so 48 CPU addresses are shared by two
  banks (21 of them with a real name on both sides). The known case that started
  the audit is still the type specimen: seg2 `spike_bars_restore` (0x902E) vs.
  seg14 `sfx_0e_block_break`. `tools/workbench/msx/regen-bank.sh` now filters through
  `tools/workbench/msx/bank_sym.py` so each bank keeps its own name. Re-run
  `tools/workbench/msx/bank_sym.py --audit` after a regen or a bulk rename.

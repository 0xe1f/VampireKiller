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

- Every third stage ends in a **boss battle** (event table `l6376h`: packed
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
  | 6 | 18 | 9 | (via `sub_65b7h`) | Dracula |

  Frankenstein (type 21) walks with shapes `0x79/0x7A/0x7B` and is on the bar.
  Igor (type 24, not in the 1–22 sheet) uses the same `0x67` hunchback frames as
  type 13; the whip path treats him as 1-HP fodder, not metered. Type 18 is
  also placed as a regular enemy on stage 16.

### Enemy types 1–22 (`gfx/enemy_sheet.png`)

Names from the sheet (play + SAT). Behaviour is the ROM handler, for checking
that the picture is the right enemy. HP is `0x60E9[type]` (`ix+0D`); unshielded
contact is **2×** the odd byte of `l81d5h`. Types **17–22** (and type 18 in a
boss room) use the shared meter `0xC418`; the rest die when `ix+0D` hits 0.
Leather whip subtracts 1 from fodder HP, other weapons 2.

| # | Name | In-game behaviour |
| ---: | --- | --- |
| 1 | Zombie | Walks in from a screen edge toward centre/Simon. 1 HP, 100 pts. Spawn bit 0. |
| 2 | Green merman | Walk/pounce. Closed-mouth frames `0x0B`/`0x08`. 1 HP, 200 pts. Spawn bit 1. Shared handler with 3 (`enemy_merman_tick`). When `ix+1B` is set and Simon’s Y is within ±8 it writes type 3 and pose `0x12` (open mouth), then the type-3 spit path runs. |
| 3 | Red merman | Open-mouth spit. Frames `0x12`/`0x0F`. Same walk/pounce, then state 2 hides and fires `0x9F74` kind 2 from Y−0x14 (the mouth). 2 HP. Spawn bit 2. Bit 0 of the type id is what selects the spit countdown, so a spawned 3 does not need the morph. |
| 4 | Hanging bat | Hangs (shape `0x1A`) until Simon is close (Y window `0x50`, X `0x40`), then flies toward him. 1 HP, 100 pts. Spawn bit 3. |
| 5 | Sitting dog | Idles; charges when Simon is within 64 px. 1 HP, 100 pts, 6 contact unshielded. Object list. |
| 6 | Pikeman | Walking spear knight. Turns at ledges/walls; walks toward Simon when Y overlaps. 4 HP, 200 pts. Stages 4–5 object list. No projectile. |
| 7 | Flying skull | Homes on Simon X **and** Y from off-screen. 2 HP, 200 pts. Spawn bit 4. |
| 8 | Ghost head | Flies across, bobbing around spawn Y. 1 HP, 200 pts. Spawn bit 5. |
| 9 | Red skeleton | Fast walk (`0x0220`), **no** projectile. 2 HP, 200 pts. Stage 13 object list (same skeleton script as 11; SAT `02 45`). |
| 10 | Skull pile | Stationary; faces Simon and shoots (`0x9F74`, projectile `0x0A`). 8 HP, 300 pts. Object list. |
| 11 | White skeleton | Same 0x9FB2 skeleton art as 9, SAT `02 4C`. Walks, then throws (`0x9F68`). 4 HP, 200 pts. Stages 7–9, 13, 17. |
| 12 | Raven | Flies, then stalls (Yvel→0) and hovers mid-flight; strafes when Simon’s Y is close. Not the type-8 sine bob. 1 HP, 100 pts. Object list, stages 7–8. |
| 13 | Hunchback | Jumps toward Simon. 1 HP, 200 pts. Object list. Type 24 (Igor) reuses pose `0x67`. |
| 14 | Bone dragon | 8 SAT cells (custom tick, skips `0x644C`). 12 HP, 1000 pts. Stages 11–12. |
| 15 | Roc | Large 6-cell flyer (phoenix-like). Flies across, pauses to drop a type `0x23` hunchback, then continues off. 8 HP, 400 pts. Spawn bit 6. Not the small raven (12). |
| 16 | Axe knight | Same SAT layout as 9, but stage 14+ VRAM is the knight. Throws (`0x9F68`). 8 HP, 300 pts, slower walk (`0x0140`). |
| 17 | Dracula | Event 6, stage 18 room 9. 32 HP on the bar, +30000. SAT is head + cape; 32×32 torso blit is **PARKED** (sheet shows the gap). |
| 18 | Giant bat | Event 1 boss; also a normal enemy on stage 16 when `CE00==0` (per-actor HP). 16 HP, 2000 pts. |
| 19 | Medusa | Event 2, stage 6 room 5. 16 HP, 2000 pts. |
| 20 | Mummy | Event 3, two of type 20 in stage 9 room 7. 16 HP, 2000 pts. Walk `0x33–0x38`. |
| 21 | Frankenstein | Event 4 with Igor. Walk `0x79/0x7A/0x7B`. 32 HP on the bar, 3000 pts. |
| 22 | Grim reaper | Event 5, stage 15 room 9. 32 HP, 12 cells, 7000 pts. |

When a boss dies an **orb descends** (C800 actor type **0x22**, not
  bonus id 22):
  - Pick it up (`0xCE11=1`) → life drip-fills (+1 HP/frame via `0x4658`)
    until full, then advance to the next level.
  - Leave it → still advance after the timer, but **life is not refilled**.

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
  **`door_tbl` at 0xBB61** (now `segments/seg13.asm`): 19 records of 3 bytes `(room | vert<<7), Y, X`.
  `door_load_coords` (0xBB37) indexes it by stage `0xD000`; if `0xD001` matches
  the room nibble it writes **`0xC5AD = Y`, `0xC5AE = X`** (`ld (0xC5AD),hl` with
  L=Y, H=X — **not** X then Y) and arms **`0xC5AC`** (`0xFF` if bit7 / vertical so
  `door_blit_tiles` paints the 6-tile graphic; `0x04` on the courtyard). Proximity
  (`door_proximity` 0x8587) compares C5AD to Simon Y (`0xC425`) and C5AE to Simon X
  (`0xC427`). All 19 records sit on a left (`X=0x0C`) or right (`X=0xEC`/`0xE0`)
  wall. Stage 0's first byte is `0x42` (room 2, bit6 set, bit7 clear); the loader
  only uses the low nibble and bit7.
- **Two layers, not two kinds of door.** (1) **Object:** the table places the door;
  the key opens it. (2) **Post-open walk** (`l77d8h`): the connectivity nibble on
  that edge is the *destination*. `0xF` → `set_stage_boundary` (`0xC408`) →
  `advance_stage` (seg0 0x438B then 0x434E: `0xD000++`, `0xD001=0`; 438B also
  clears bit0 if still set). Valid room → intra-stage wrap. Intra-stage key doors
  (decoded, not all play-verified): stages **3, 6, 9, 12, 15, 18**. Stage 15 room 8
  left → isolated room 9; stage 18 room 8 left → room 9 (Dracula). Stage 15 is not
  a unique mechanism — it is the intra-stage case we traced live (`C5AD=0x80`,
  `C5AE=0x0C`).
- **Display-type `0x1F` is not this door.** `l87f6h` → `l881bh` → `l9180h` is the
  vendor / brazier-reveal special-object path (`0xC5B5`/`0xC5C5`). An earlier A/B
  scan that "ruled out" placed-object doors was right to reject 0x1F as the
  *white-key door*, but it never found `door_tbl` either. `tools/roomperm.py`
  overlays the table by default (red bar); `--compare-doors` still emits the old
  edge-heuristic / object sheets.

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
Each hub's packed stream holds 3 stages × up to 16 room slots × up to 4 objects;
per object, id bit7 = scenery flag, low 7 bits = sprite id, and one attr byte
packs the in-room cell (hi nibble X, lo nibble Y, each *16 px). Stage 0
(courtyard) has no object-list entries. `D000`/`D001` are stage/room **indices**,
not map coordinates — room positions come from `minimap_room_pos` (see below).
`tools/roomperm.py` is the map (`gfx/minimap_s<NN>.png`); its `decode_objects`
reads this list for the `--compare-doors` overlay.

## Room geometry / tile map (CONFIRMED, static + runtime, byte-exact)

Every room is an **8 wide x 6 tall grid of METATILES**; each metatile is a **4x4
block of 8x8 tile ids (16 bytes)**, so a room expands to a **32x24 tile-name map**
held in work RAM at **0xD100** (rows 0-1 are the HUD; the drawer seg0 0x4f98
paints the playfield from 0xD140). `seg0 room_map_build` (0x4fb6) does the
expansion on room entry; `seg1 map_cell_at` (0x7d36) reads it for collision.

Storage (during the build the mapper pages bank 0x0b->0x6000, 0x0c->0x8000,
0x0d->0xA000, then restores banks 1/2/3).  Banks 0x0B/0x0C are source in
`segments/seg11.asm` / `seg12.asm`:
- **`mtile_rowbase`** - byte table at bank 0x0b **0x6000**; index = rowbase[row]+col.
  Rooms in a world row = rowbase[row+1]-rowbase[row] (row 1 / stage 1 = 8 rooms;
  stage 18 uses `minimap_room_count` because the next byte is not a count).
- **`mtile_roomptr`** = word at bank 0x0b **0x6013 + 2*index** -> the room's
  **48-byte metatile-id stream** (row-major 8x6) in `mtile_streams` (e.g. stage 1
  streams start at 0x620b, stride 0x30).
- **`mtile_defbase`** = per-row word table at bank 0x0b **0x7EBB**; def(id)
  = 16 bytes at defbase + id*16 (`mtile_defs_s01` 0x80B1 = bank 0x0c). The special
  path (0xC41A!=0, e.g. intro) uses `mtile_stream_c41a` 0x614B + `mtile_def_c41a`
  0xA041 (bank 0x0d).  Stage 0/18 def tables straddle the 0x8000/0xA000 boundaries.

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
transition graph is a per-stage table in seg13 (`segments/seg13.asm`): `conn_ptr` word table at **0xB9D3**
(19 entries, one pointer per stage 0xD000 0..18). For a room it points at a 2-byte
record = **4 nibbles: up, down, left, right** = the DESTINATION room index for
that exit (`0xF` = blocked). On an edge/stair transition the engine looks this up
(seg13 0xB963/0xB9BD) and writes the result to 0xD001 (**seg13 0xB987**); the
per-frame edge/stair detector `sub_7682h` (seg1 0x7682) sets the pending-exit
direction in 0xC41B (1=up,2=down,3=left,4=right; **0xFF** = spot/portal warp), and the four RAM permit bytes
0xC41C-0xC41F are loaded from the same nibbles (seg13 0xB99A). Stage advance
(0xD000++, 0xD001=0) is separate: `advance_stage` (seg0 0x434E), reached via the
white-key door (0xC409) or the castle-boundary flag (0xC408). `0xD000` is never
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

**Stage-12 spots (`spot_tbl` at 0xBBCD, in `segments/seg13.asm`).** `door_load`
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
| 1 | `simon_jump_tick` 0x6CC7 | **jump / airborne** (Y arc via `jump_y_delta`; C421 = up/left/right) |
| 2 | `simon_crouch` 0x6DB0 | **crouch** (DOWN held; Simon X is locked — cannot move) |
| 3 | `simon_stairs` 0x6DE4 | **on stairs / climbing** (diagonal travel; can whip while climbing) |
| 4 | `simon_fall` 0x6F44 | **falling / dropping** off a ledge |
| 5 | `simon_hurt` 0x6F8C | hurt / knockback (shallow airborne launch — not a jump) |
| 6 | `simon_dying` 0x709A | dying / respawn (enemy spawner is suppressed while ==6) |
| 7 | `simon_portal_wait` 0x7102 | pad crouch+UP wind-up: wait 0xC42D, then C41B=0xFF warp |

`0xC423` tracks the air sub-phase during jumps/falls (e.g. 2→1 rising→falling).

### Input (RAM 0xC006 / 0xC007)

`read_buttons` (seg0 0x4BC2) samples the joystick (PSG port A) and keyboard row 8
(arrows + SPACE). `input_edge` (0x4BBB) latches the held mask at **0xC007** and
the rising edge at **0xC006**. Bits: 0=UP, 1=DOWN, 2=LEFT, 3=RIGHT, 4=SPACE/trig
(whip), 5=UP (jump and portal new-press). Crouch is DOWN *held* (C007 bit 1);
jump/portal is UP *new-press* (C006 bit 5).

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
  A raised **red shield** (`0xC701` bit 4, bonus id 3) uses table damage instead
  of 2× when Simon is facing the hit, and spends a shield charge (`0xC441`);
  when charges run out the shield drops.  The **yellow shield** (id 4, bit 5)
  absorbs D700 projectiles instead.
- **Hazard / enemy projectile** — `hurt_simon_projectile` (seg2 0x85AD). Fixed
  **8**, or **16** if the slot's flag bit is set. Also forces the hurt state
  (`0xC420 = 5`). Ignored during i-frame/freeze timers (`0xC42D`, `0xC43A`).

**Simon deals damage** to HP-bar enemies via `weapon_hit_damage` (seg1 0x7E33) →
`damage_enemy` (seg0 0x4643, `0xC418 -= B`). B comes from a per-weapon table indexed
by `(enemy type − 0x11)`:
- leather whip / knife → base `04 08 08 04 04 04 10` (types 0x11..0x17)
- chain / axe / cross → strong `06 0C 0C 06 06 06 18` (≈1.5×)
- vs type 0x17 with weapon ≥ 2 the hit is quartered.

Lesser enemies (type < 0x11) have no HP bar; they use per-actor HP at `ix+0D`
(table `0x60E9`). Leather whip subtracts 1 per connected hit, other weapons 2.

### Equippable weapons (strength tiers, per design)

- **lowest**: leather whip, thrown knife
- **normal**: chain whip, boomerang cross
- **strong**: boomerang axe

The HP-bar table (`l7e60h` / `l7e67h`) treats **axe and cross both as strong**
(same 1.5× row as the chain whip). Fodder (`l804fh`) is knife 1 / axe 4 / cross 2
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
  `l74ach` can also spawn bonus `0x1C` at the projectile and unequip when `C433`
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
- **Weapon pickups** via `l8d77h`: `C416 = bonus id - 0x19`, except **`0x1E`**
  (holy water). Chain `0x1A` → 1 was runtime-confirmed; knife `0x1B` → 2 is the
  vendor dagger (despawn-on-hit, two slots). Axe vs cross is **3 = axe
  (`0x1C`), 4 = cross (`0x1D`)** from throw speed + vendor stock (the cross is
  the one for sale; type 4 is the faster ±5 boomerang). HUD tiles agree
  (`gfx/bonus_hud_items.png`, bottom row): axe is a hand-axe, cross is the
  diagonal four-arm cross with a **blue** fill (palette index 15, same slot as
  the thrown SAT `0x0F`). Type 3's lose path hardcodes a `0x1C` world drop —
  that is this weapon's own bonus id, not a second item.
- **Damage table split** (`weapon_hit_damage` 0x7E33): leather and knife use
  `l7e60h` (`04 08 08 04 04 04 10`); chain/axe/cross use `l7e67h`
  (`06 0C 0C 06 06 06 18`). Index = enemy type − 0x11. Type 0x17 with weapon
  ≥ 2 quarters the hit.
- On death (`sub_70e3h`) `C416` is cleared to 0. Missing a cross/axe catch also
  returns to leather (`lose_weapon` 0x8E9A) without waiting for death.

Other pickups replace the weapon:

- Chain whip (upgraded whip)
- Throwable axe
- Throwable cross
- Knives

Sub-items / consumables:

- **Map item** — picked up in-stage; sets **0xC701 bit 7** (map held) and seeds
  **0xC70F = 3** uses. Pressing **F2** toggles a whole-stage minimap on/off, spending
  one use per open. Driven by seg2 **minimap_driver (0x955A)** off F-key edges in
  **0xC00B** (bit 1 = F2); the map-screen state is **0xCF38** (0 = playing, 1 = build,
  2 = shown). The map layout is **hand-authored, not derived from connectivity**:
  **minimap_room_pos (0x9681)** reads a per-room *position code* from the per-stage
  table at **0x969C** and maps it via **0x975E** to a 6×5 grid cell (hi byte = X, lo
  byte = Y). This table is the authoritative room geography for all 19 stages (0–18)
  and is available in `tools/roomperm.py` via `--minimap` (default placement is the
  BFS spatial reconstruction; the two are generated side by side for comparison).
- **Hourglass** — bonus id **10** (`C701` bit 6). Use: while **jumping** (C420==1),
  **DOWN** new-press, spend **5 hearts**. Arms `C43B` (90 frames ~1.5s, or 150
  ~2.5s with the tipped-hourglass flag below) and `D010` bit0, which skips enemy
  AI/movement. Not 5 seconds in the ROM; not a grounded UP+DOWN chord.

### Holy water

Holy water is a **sub-weapon bit**, not a whip replacement. Bonus id **`0x1E`**
(`bonus_holy_water` 0x8D94) ORs **`C701` bit 3**. It never writes `C416`, so
SPACE is still whatever whip/knife/cross/axe you have. Death (`sub_70e3h`)
keeps only `C701` bit 7 (map); the vial is lost. Vendor row **`0x1E`** is this
item (30 / 10 / 50 hearts).

**How to throw.** While **jumping** (`C420==1`) and SPACE is **not** a new-press
(`l713dh`), **LEFT** or **RIGHT** new-press (`C006` bits 2/3). Costs **5 hearts**
(BCD) and needs `C461==0` (one vial at a time). `holy_water_use` (seg1 **0x7154**)
writes throw dir to `C468` (1=left, 0=right), sets projectile slot `C460` type
**5**, and spends the hearts. Jump+DOWN is the hourglass if you also have bit 6.

**Arc and pool.** `holy_water_tick` (0x73AB) on the **C460** slot (type at
`C461`). Spawn copies Simon (`C425`/`C427`) with `velX` ±2 and `velY` 0. In flight
(state 2) each frame does `Y += 2*l7084h[phase]` — `l7084h` is the signed dY
table also used by hurt knockback — and `X += velX` (`projectile_integrate`). It lands when
`sub_7b9fh` sees a solid tile, plays sfx `0x18`, and goes to state 3: a **24-frame
pool** on the floor. SAT path `l759ch` paints that state **colour 8** (red).

**Damage.** Unlike the knife (type 2), a hit does **not** despawn the vial
(`l807fh`). Fodder uses `l804fh` byte 3 = **2** HP per connected hit
(knife/axe/cross/holy = 1/4/2/2). The pool can connect more than once: a hit
clears enemy `+0x0E` bit 0, and `0x99A6` (called from the pool flicker) restores
it on actors that still have bit 2. HP-bar types `0x11–0x17` go through
`weapon_hit_damage` / `C416` (the equipped whip), not that 2.

### Tipped hourglass (secret)

The world hourglass pickup can be whipped before you grab it. That is a hidden
second item, not a glitch. Period guides called the result "1.5× timed-item
duration"; the ROM is slightly more generous than that.

**How.** Whip the hourglass **once**. `l8c4bh` (seg2 **0x8C4B**) rewrites the
pickup type (`ix+4`) from **0x0A → 0x0B**, nudges it up 8 pixels (`sub_8c36h`),
and the 4bpp blit switches to the sideways graphic (the tile next to the upright
hourglass in `gfx/bonus_hud_sheet.png`). Collecting that form
runs `bonus_tipped_hourglass` (id **11**, 0x8DFC) which does only
`set 2,(0xC431)`. Whip it a **second** time and `ix+6` is set to 1, so the
pickup despawns on the next tick — the item is gone.

This is world-pickups only (the 0xC500 list). Buying the hourglass from a vendor
calls `collect_bonus(0x0A)` immediately; there is nothing to whip.

**What it does.** `0xC431` bit 2 is a persistent "longer timed bonuses" flag. It
is **not** a second hourglass. The tipped collect path does **not** set `C701`
bit 6, so this pickup does not grant freeze — you spent the hourglass on the
duration buff. An hourglass you already held is left alone (bit 6 is not
cleared).

The flag is read when a timed effect is **armed**, not while it is ticking.
Picking up the tipped hourglass does not extend a rosary / gem / ring / freeze
that is already counting down. Seconds below assume 60 Hz.

| Effect | RAM | Default | With bit 2 | Ratio |
|--------|-----|---------|------------|-------|
| Rosary (no new enemy spawns) | `C440` | `0x96` (150 frames ≈ 2.5 s) | `0xF0` (240 frames ≈ 4 s) | 1.6× |
| Blue gem (invisibility) | `C43A` | `0x96` | `0xF0` | 1.6× |
| Sapphire ring (touch-kills) | `C434` | `0x96` | `0xF0` | 1.6× |
| Hourglass freeze | `C43B` | `0x5A` (90 frames ≈ 1.5 s) | `0x96` (150 frames ≈ 2.5 s) | 1.67× |

Weapon pickups fall through into `bonus_rosary`, so grabbing a whip upgrade also
gets the long 240-frame no-spawn window if the flag is set.

**What it does not lengthen.** Instant pickups (white cross, potion, hearts,
score bags) and the persistent inventory bits (boots, wings, candle, map, bibles,
keys, staff, shields).

**How long it lasts.** Until death. The life-lost reset (`sub_70e3h`) zeros all
of `0xC431`, so this flag, boots, and wings go together. It survives room and
stage changes.

- **Life orbs / potion** restore `0xC415` (not heart currency). **7** small orb
  = +8 (1/4 of the 32-point bar). **22** is a **bottle/potion** (first tile of
  `gfx/bonus_hud_items.png`; vendor price-tbl id `0x16`) that instant-fills +32. Same full-bar
  end state as picking up the boss orb, but a different graphic and collect
  path — the descending boss orb is actor type 0x22, not this bonus id.
- **Shields** — **3** red (`C701` bit 4): facing the hit takes table damage
  instead of 2×. **4** yellow (`C701` bit 5): absorbs D700 projectiles. Mutually
  exclusive; 16 charges in `C441`.
- **Rosaries** — a **temporary "no new enemies" power-up** (id **6**). NOT a
  weapon and NOT a persistent inventory item. Runtime (frame 493): collected as a
  normal 0xC500 pickup (its 0x84 slot cleared), bonus id **0x06** latched to 0xC419.
  Static trace of the effect (confirmed, immediate, not next-room):
    - Handler `collect_bonus[6]` (seg2 **0x8D83**) arms a countdown timer at
      **0xC440** to **0xF0** (240 frames ≈ 4 s) or **0x96** (150 frames ≈ 2.5 s),
      selected by `0xC431` bit 2 (tipped hourglass; see that section). Same bit
      lengthens the blue gem, sapphire ring, and hourglass freeze. It does NOT touch
      0xC700-0xC70F inventory or the 0xC416 weapon (hence "temporary"). The weapon
      pickup path (`l8d77h`, bonus >= 0x1A) falls straight through into this same
      code, so grabbing a whip upgrade also arms a short no-spawn window.
    - 0xC440 is a per-frame countdown: `sub_75c7h` (seg1) decrements it each frame in
      the timer bank (`sub_7682h/75c7/75e9/...`).
    - The enemy spawner (seg0 **room_spawner @0x5EBF**) is called every frame from the
      actor-update loop (seg2 0x98F0) whenever 0xD010==0 (normal play). Its first act
      is `ld a,(0c440h) / and a / ret nz` -> while the rosary timer is nonzero it
      spawns nothing. When 0==C440, it reads a per-room **spawn bitmask** and
      dispatches one generator per set bit (see below).
    - **Effect is immediate and current-room** (the gate is checked per frame in
      whatever room you're in), not deferred to the next room. It only suppresses
      *new* spawns; enemies already in the 0xC800 slots are untouched.

`collect_bonus_tbl` (seg2 **0x8D45**) is the 25-entry handler table for pickup
ids 1–25 (index = id−1; id ≥ 0x1A goes through `l8d77h`). Confirmed: **1/2**
small/large heart, **3** red shield (face-on contact uses table damage, not 2×),
**4** yellow shield (absorbs D700 projectiles), **5** white cross (kill on-screen
actors), **6** rosary, **7** small life orb (+8 HP), **8** blue gem (C43A invis, sprite
flash white), **9** sapphire ring (C434, sprite flash red, touch-kills), **10**
hourglass (jump+DOWN, 5 hearts → freeze), **11** tipped hourglass (secret:
whip the id-10 world pickup once; see section above),
**12** boots, **13** wings, **14** candle (white outlines on breakable blocks),
**15** map, **16/17** black/white bible, **18** staff (C700=3), **19/20**
white/blue money bag (+5000/+1000), **21** slime (fake candle drop; collecting
it is a no-effect stub, leaving it hatches actor 0x1A/0x1B/0x1C by hub), **22**
potion/bottle (+32 = full bar; vendor 0x16; not the boss orb), **23** yellow
key, **24** white key, **25** treasure chest (container; `l8c1bh` spends key/staff
and reveals the contents id at `ix+0x0D`). Bonus **`0x1E`** (holy water) is not
in this 1–25 table; `l8d77h` takes `id - 0x19 == 5` to `bonus_holy_water`.

### HUD bonus tiles (uncompressed 16×16 4bpp)

Pickup popup (`l8eadh`) and the equipped-weapon icon (`sub_8ea1h`) HMMM these
tiles from VRAM page 1. Loaded at the HUD init copy (seg0 ~0x548C):

| ids | CPU source | ROM file | VRAM dest | dump |
|-----|------------|----------|-----------|------|
| 1–20 | seg9 `0x9000` | `0x13000` | Y=`0x50`, then Y=`0x60` X=0..48 | `gfx/bonus_hud_sheet.png` |
| 21 (slime) | — | — | no dedicated tile | — |
| 22 (potion) | seg9 `0x9A00` | `0x13A00` | Y=`0x60` X=80 | `gfx/bonus_hud_items.png` (3×3) |
| 23–30 | seg6 `0xB9C8` (after `sub_53a5h`) | `0xD9C8` | Y=`0x60` X=96..208 | same grid, tiles 1–8 |

`bonus_hud_sheet.png` is ids 1–20 in order (5×4). `bonus_hud_items.png` is a 3×3
of ids **22–30**: potion, yellow key, white key, chest, chain whip, knife, **axe**,
**cross**, holy water. Each cell is labelled with its bonus id in a dark band
(same 3×5 digits as the minimap renderer).

**Palette.** `sub_481bh` writes one MSX2 entry (A=index, D=`0rrr0bbb`, E=`00000ggg`);
`l4845h` walks an (index, rb, g)+ table ending in `0xFF`. `sub_572eh` loads the
**8 fixed HUD/sprite colours** from seg10 `0xBF88` (file `0x15F88`):

| idx | 3-bit RGB | role |
|-----|-----------|------|
| 0 | 000 | black / background |
| 1 | 754 | peach (outlines, hourglass frame, yellow key, potion glass) |
| 2 | 111 | dark grey (linework) |
| 3 | 623 | magenta (red shield, staff, money-bag tie) |
| 8 | 701 | red (hearts, sand, whip stripe, flames) |
| 12 | 555 | grey (axe head, knife guard) |
| 14 | 777 | white |
| 15 | 007 | **blue** (cross fill, potion liquid, gems) |

Stage palettes (pointer table seg10 `0xBEA7`) only overlay indices
**4, 5, 6, 7, 9, 10, 11, 13**. Room entry (`0x5787`) then applies that room's
table from `9AB0[stage-1][room].palette` — typically 4+6 or 5+7 — so leftover
BIOS values for 4/6 do not survive into play. HUD bonus tiles never use those
slots, so they look the same in every stage. Dumps use `gfxdump.vk_play_palette`
(0xBF6F extras then 0xBF88 fixed). `sub_8ea1h` maps `C416` 1–4 → bonus
`0x1A`–`0x1D`. Leather (`C416=0`) is a separate tile at VRAM `(80, 0x70)`, not
in these sheets.

### Continuous enemy generators (spawn bitmask)  (CONFIRMED, byte-exact)
- `room_spawner` (seg0 0x5EBF) indexes seg14 word table **0x85A6** by stage
  (0xD000), then indexes the resulting byte table by room (0xD001) to fetch a
  **spawn bitmask**. Stage 1's byte table is at **0x85CF**. Bits **0–6** each fire
  one rate-gated generator in seg2 (LSB first). **Bit 7** appears in some mask
  bytes (`0x80`) but is never dispatched.

  | bit | generator (seg2) | actor type | handler (seg3) | enemy |
  |-----|------------------|------------|----------------|-------|
  | 0 | `zombie_generator` 0x9CED | 0x01 | `enemy_zombie_tick` 0xA93B | zombie (100 pts) |
  | 1 | `merman_generator` 0x9D52 | 0x02 | `enemy_merman_tick` 0xA2E7 | green merman, 1 HP (200 pts) |
  | 2 | `merman_generator_3` 0x9D59 | 0x03 | same 0xA2E7 | red merman, 2 HP (open-mouth spit) |
  | 3 | `hanging_bat_generator` 0x9D9E | 0x04 | `enemy_hanging_bat_tick` 0xB0D1 | hanging bat (100 pts; hangs, then flies at Simon) |
  | 4 | `flying_skull_generator` 0x9DCA | 0x07 | `enemy_flying_skull_tick` 0xB068 | flying skull (200 pts; homes on Simon X and Y) |
  | 5 | `ghost_head_generator` 0x9DDC | 0x08 | `enemy_ghost_head_tick` 0xA502 | ghost head (200 pts; flies across, bobs around spawn Y) |
  | 6 | `roc_generator` 0x9DEE | 0x0F | `enemy_roc_tick` 0xB19A | roc (400 pts, 8 HP; flies, pauses, drops type 0x23). Manual lists 300. The small hovering raven is type 12. |

  `spawn_actor` takes **D = X** (slot+05), **E = Y** (slot+03). Zombies typically
  enter at X=0xF0 (right edge) or 0x10 (left), Y=0xC0. Mermen spawn at Y=0xC8
  with X from table `l9d8eh`. Hanging bats / flying skulls / ghost heads share `flyer_spawn`: X at
  the screen edge, Y = SimonY−8. The roc is fixed at X=0xE0, Y=0x30 or 0x40,
  and skips the spawn if Simon X ≥ 0xC0.
- Each generator is rate-gated by `sub_9ccah` (per-generator 0xCF00+ counter vs a
  threshold table, scaled by the 0xD012 difficulty/mood). The spawn **position is
  hardcoded** — it is **NOT** read from the tile map. This is why the small 08/05
  tile pair (see "Room geometry") is *not* a generator: its positions don't line
  up with spawns, and rooms spawn regardless of whether the pair is present.
  Stage 1: rooms 0/1/5/6 spawn zombies (bit0), room 4 spawns bats (bit3).
- Other enemies (e.g. the dog, type 0x05, and the leopard) come from the per-room
  **object list**, not this continuous spawner.
  - NOTE: 0xC5E5/0xC5E6 (00->FF/20 at pickup) is the generic pickup-popup message +
    timer set by 0x8F2A for *every* pickup, NOT a rosary-specific state.
- **Hearts** — currency for vendors; also power the hourglass (jump+DOWN) and
  holy water (jump+LEFT/RIGHT), 5 each.
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

**Making / taking an offer** (`vendor_make_offer` 0x938E, called by the resident
vendor state machine at seg0 `l4411h` while seg2 is paged in): picks the item
(`vendor_set_offer_item` 0x9406 → 0xC708) and its price, and starts the 0xC706
timer. Price comes from `vendor_price_tbl` (0x942F), 9 rows of
`{item id, normal, halved, doubled}`; `vendor_select_price` (0x941F) picks the
column from the 0xC702 bible flags:

| Item (bonus id) | normal | white bible (½) | black bible (×2) |
|-----------------|--------|-----------------|------------------|
| 0x0E (candle)   | 20     | 15              | 60               |
| 0x12 (staff)    | 30     | 20              | 60               |
| 0x03 (red shield)| 20    | 10              | 60               |
| 0x04 (yellow shield)| 20 | 10              | 80               |
| 0x0A (hourglass)| 40     | 20              | 80               |
| 0x16 (potion)   | 40     | 15              | 80               |
| 0x1E (holy water)| 30    | 10              | 50               |
| 0x1D (cross)    | 20     | 10              | 80               |
| 0x1B (knife)    | 50     | 30              | 90               |

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
Still-as-data-misdisassembled: (none in the title/HUD path; `title_layout` 0x4C3F-0x4D0E is now `defb`).

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
collision, item logic) lives in **code segments 1/2/3** (`INCLUDE`'d, still being
annotated).  Map tables are banks 11-12; remaining `INCBIN` banks are 4-10 and
14-15 (graphics / object lists).

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

The 16-colour VDP palette is programmed by `sub_481bh` / `l4845h`. Eight indices
(0, 1, 2, 3, 8, 12, 14, 15) are fixed by `sub_572eh` (seg10 `0xBF88`) and never
changed by stage palettes — HUD bonus tiles use only those. See *HUD bonus tiles*.

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
- `sub_53a5h` -> seg  4 @ 0x6000, seg  5 @ 0x8000, seg  6 @ 0xA000  (tileset banks; HUD keys/weapons at 0xB9C8)
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
- `enemy_sheet.png` - one labelled frame per `entity_tbl` type 1–22 (`make gfx`).
  Layout from the seg6 shape table at 0xB473 (`ix+0B`); pixels from the per-room
  gfx-script RLE into VRAM 0xF800+ (plus the 0x4745 1bpp convert). Two-plane SAT
  colours with CC (`0x40`) OR the colour indices (2+4→6). Palette is the
  playfield sequence: HUD-fixed (`sub_572eh`) + `0xBEA7[stage]` + the per-room
  overlay at `9AB0[stage][room]` (same room that supplied the sprite VRAM).
  Types 7/10 only use HUD-fixed 2/12/14, so they ignore the overlay. Type **9**
  is the red skeleton (stage 13; SAT `02 45`; faster walk, no projectile). Type
  **11** is the white skeleton (`02 4C`, same 0x9FB2 sprite script). Type **16**
  is the axe knight (stages 14+; same SAT layout as 9, throws via `0x9F68`).
  Type **14**
  bypasses `0x644C` (custom SAT in its tick). Type **17** is Dracula: standing
  shape `0x5B` is SAT head + cape only. The 32×32 middle is a SCREEN 5 blit
  (`sub_ad87h` / `ladc3h`, dest `(X-16, Y=0x91)`, sources assembled from page-1
  16×16s at Y=`0xA0`). **PARKED:** compositing that blit from the s18r9
  playfield (crop 64,88) pulled title-screen kana (Akumajō Dracula), not the
  cloak; the sheet leaves the SAT gap until the real VRAM source is found.
  Type **21** is Frankenstein (`0x79`); type 13/24 share the hunchback pose
  `0x67`. Boss types use the event-room tileset. Not in `manifest.tsv`
  (derived, like the HUD bonus sheets).

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

- Input poller is `read_buttons` (0xC007 held / 0xC006 new-press). Remaining:
  title→game vs title→attract branch, and keyboard SPACE vs joystick trigger at
  the title (`l4398h` tests bits 4 and 5).
- State machine for logo → title → attract → intro → play → boss → next level.
- Weapon/sub-item inventory representation in RAM.
- Heart counter and vendor transaction logic.
- Per-level / per-boss data tables (which bank they live in).

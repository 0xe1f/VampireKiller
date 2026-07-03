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

## Reference: Metal Gear disassembly

Cloned to `reference/MetalGear` (GuillianSeed/MetalGear). Same Konami MSX2 engine
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

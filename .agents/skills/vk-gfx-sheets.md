---
name: vk-gfx-sheets
description: >-
  Vampire Killer catalogue sheets: stem tables, SAT composites, stage palettes,
  simon_rle/intro_sky anti-patterns, gfxdump.py hooks. Generic cell/header rules
  are the MSXDAW skill msx-gfx-sheets.
---

# MSX gfx contact sheets

Canonical sheets: `gfx/tilesets/tileset_s01.png`,
`gfx/metatiles/mtile_defs_s01.png`, `gfx/metatiles/mtile_streams.png`,
`gfx/sprites/enemy_sprite_rle.png`,
and `gfx/palettes/stage_palettes.png`.
New *catalog* dumps must match those, not `simon_rle` / `intro_sky`.
Implement in `tools/gfxdump.py`; `make gfx` regenerates. Compressed bytes
in `segments/data/*.asm` stay authoritative (`make verify`). PNG is preview
only.

## Where files go

| Dir | Contents |
|-----|----------|
| `gfx/sprites/` | The four packed 1bpp sprite asms only (`ASM_SPRITE_STEMS`): `enemy_sprite_rle`, `simon_rle`, `intro_sky`, `title_jp_sprites`. |
| `gfx/tilesets/` | 4bpp tileset asms (`tileset_*`, intro/title, bonus HUD, HUD keys, portrait, `spike_bar`, `dracula_body`). |
| `gfx/palettes/` | palette_apply tables (`stage_palettes`, `room_palettes`). Solid 8×8 swatches, not tiles. |
| `gfx/metatiles/` | 4x4 metatile-def tables (`mtile_defs_sNN`, `mtile_def_intro`) and 8x6 room streams (`mtile_streams`, `mtile_stream_intro`). Geographic/minimap composites stay `gfx/stage_sNN.png`. |
| `gfx/fonts/` | The three 1bpp font asms (`ASM_FONT_STEMS`): `font_credits`, `font_hud`, `font_logo`. |
| `gfx/` | Everything else: SAT composites (`enemy_sheet.png`, `sheet_enemy_*.png`), vendor, stage/minimap sheets. |

Do not put composites or fonts in `gfx/sprites/`. Do not put palette
swatches in `gfx/tilesets/`. A new packed sprite asm
sheet goes in `sprites/` (add its stem to `ASM_SPRITE_STEMS`); a new font
asm sheet goes in `fonts/` (add its stem to `ASM_FONT_STEMS`); a new
composed pose sheet goes in `gfx/`.

## Cell

One atom per cell, uniform grid (`render_png`). Do not pack a SAT figure
or animation into one cell (that is `gfx/enemy_sheet.png` /
`gfx/sheet_enemy_*`, a different family).

| Kind | Atom | Bytes | Output dir | Grid |
|------|------|-------|------------|------|
| 4bpp playfield / HUD tile | one 8×8 | 32 | `gfx/tilesets/` | 16 cols, `size=8` |
| 4bpp 8×4 fragment | one 8×4, padded to 8×8 | 16 | `gfx/tilesets/` | 2 cols (`spike_bar` mount) |
| 4bpp 16×16 blit | one 16×16 | 128 | `gfx/tilesets/` | 8 cols (5 for bonus HUD, 4 for HUD keys / portrait parts), `size=16` |
| 4bpp packed 32×32 | one 32×32 | packed | `gfx/tilesets/` | 2 cols (`dracula_body`), `size=32` |
| palette_apply entry | one 8×8 solid | 3 | `gfx/palettes/` | 16 cols (VDP index 0–F; one row per table), `size=8` |
| 4×4 metatile def | one 32×32 (4×4 nametable tiles) | 16 | `gfx/metatiles/` | 8 cols, `size=32` |
| 8×6 room stream | one 256×192 nametable (HUD not cropped) | 48 | `gfx/metatiles/` | one stage per row, `size=(256, 192)`, scale 1 |
| 1bpp hardware sprite | one 16×16 plane | 32 | `gfx/sprites/` | 8 cols, `size=16` |
| 1bpp font glyph | one 8×8 | 8 | `gfx/fonts/` | 10 or 16 cols, `size=8`, scale 12 |

Transparent / unused pixels are `OFF` `(0x30, 0x3a, 0x44)` so the cell
bounds stay visible. Scale **8** (fonts **12**; 8×6 streams **1** so a
room cell is as wide as a scale-8 metatile def). Gap / canvas from `GAP` /
`BG` in `gfxdump.py`. Do not CC-overlay two SAT planes: the third in-game tone is
`index_a | index_b` at overlap; compositing would make the dest header lie.
Composited poses belong on `gfx/sheet_enemy_*`.

## Header

Dark band above every cell (`roomperm.draw_text`). The string is the
object's identifier, **4 uppercase hex digits, no `0x`**. Lowercase `x`
is drawn as ×.

- Tiles: CPU address of that tile in the asm (`; 0x7220  s01 tile 0x00`
  → `7220`). Unique per cell.
- Palettes: CPU address of that 3-byte `(index, rb, g)` record
  (`s00_palette` idx 4 at 0xBECD → `BECD`). Unique per cell. Column is
  the VDP index (0–F); unused slots in that table are unlabeled.
- Metatiles: CPU address of that 16-byte def (`mtile_defs_s01` def 0x00
  at 0x80B1 → `80B1`). Unique per cell.
- Streams: CPU address of that 48-byte stream (`mtile_stream_s00_r00`
  at 0x617B → `617B`; intro `614B`). Unique per cell. Empty pads
  (a stage with fewer rooms than the widest) are unlabeled.
- Sprite planes: VRAM dest of that 32-byte pattern (`FA00`, `FA20`, …).
  Unique within the load. Pattern *N* is `0xF800 + N*8`.
- Fonts: 2-digit hex glyph id (`_hex_id`). Credits: ASCII of the character.
  HUD: vk id `0x20+`. Logo: tile ids `01`–`34`. Unique per cell.

Do not use a dest every stream shares (`F800` for a whole sheet of
different art).

## Palette

Paint with the VDP palette the game uses when that object is on screen.
Index 0 stays off (`OFF`), not pal[0] — except palette sheets, which
paint the table's own RGB (hud_fixed index 0 is black, not `OFF`).
Unused slots in a palette_apply table stay `OFF`.

- Playfield tileset `tileset_sNN`: `vk_stage_palette(data, N)` (BIOS +
  HUD-fixed + `stage_palette_ptr[N]`). `_tileset_asm_palette` already
  does this.
- Metatile defs `mtile_defs_sNN`: same stage palette as that tileset
  (first stage of the shared set: s01 → stage 1). `mtile_def_intro`:
  `vk_intro_palette`. Compose from the stage / intro tileset; nametable
  id 0 is blank, id N is ROM tile N−1 (`load_stage_tileset` at VRAM
  0x8004).  Stage 18 Dracula-room defs use the event-6 portrait overlay
  (frame from nametable id 6, face from 0x1E), not the title-tiles tail of
  the 0xBF blit.
- Room streams `mtile_streams`: `vk_playfield_palette(data, stage, room)`
  per cell. One stage per row, rooms left to right. Compose the 8×6 from
  that stage's def table / tileset. Stage 18 room 9 uses the event-6
  portrait atlas and `_s18_portrait_palette`. `mtile_stream_intro`:
  `vk_intro_palette` and intro defs. Full nametable (HUD not cropped);
  `gfx/stage_sNN.png` is the geographic/minimap composite (HUD cropped).
- Enemy sprite planes: that actor's SAT colour (`col & 0x0F`) in
  `vk_playfield_palette` for a room that actually loads the stream
  (`_sat_plane_map`). HUD-fixed 2/12/14 stay HUD-fixed; 4/5/6/7 come
  from the room overlay.
- Thrown weapons at `F8C0`: knife/axe `02` then `0C`, cross `0F`/`0E`,
  HUD-fixed pal (`_weapon_plane_map`).
- HUD / bonus / title tiles: HUD-fixed (`vk_play_palette`), not a stage
  overlay.
- Intro tiles: `vk_intro_palette`. Portrait: HUD-fixed then `0xBF6F`.
- `spike_bar`: `vk_playfield_palette(data, 6, 1)` (the room that draws it).
- `dracula_body`: `vk_playfield_palette(data, 18, 9)` (figure fight).
- Fonts: HUD-fixed ink 14 (the `glyph_blit_run` ink).
- Palette sheets: the table's own `(index, rb, g)` RGB, not a composed
  BIOS+HUD overlay. Column N is VDP index N. Empty tables (`pal_a04a`)
  are a row of `OFF`.

Do not invent even/odd inks, and do not paint every cell with one index.

## Anti-patterns (do not copy)

**`simon_rle.png`** — headers repeat `F800`/`F840` across unrelated
frames, so a cell is not an identified object. Colour is even-plane HUD
1 / odd-plane HUD 2, not SAT `01`+`42` (overlap 3).

**`intro_sky.png`** — backdrop strip, every plane intro-palette 14.
Not discrete objects and not per-cell colour.

Also skip: plane-OR compositing, unlabelled strips, greyscale
stand-ins, compositing CC pairs onto this sheet type.

## Adding a dump

1. Identify the asm (`segments/data/`) and the atom (8×8 tile, 8×4
   fragment, 16×16 tile, packed 32×32, 4×4 metatile def, 8×6 room stream,
   16×16 sprite plane, 8×8 glyph, or 3-byte palette_apply record).
2. Parse that file. Tiles: `parse_asm_tile8` (`; 0xXXXX  … tile …` or
   `… 16x16 …`; `… 8x4 …` is 16 bytes padded to 8×8; skip `rest of`
   prefixes). Packed 32×32 (`dracula_body`): `_unpack_dracula_body`.
   Metatile defs:
   `parse_asm_mtile_defs` (16-byte groups; s00/s18 are one file each).
   Room streams: `parse_asm_mtile_streams` (48-byte groups, one stage per
   row) and `parse_asm_mtile_stream_intro`. Sprite RLE:
   `_parse_asm_sprite_rle` + `rledec.decompress`; skip
   `*unid*` (not a valid stream). Split on 32-byte (or 128-byte)
   boundaries; do not emit a cell for a partial leftover. Fonts: 8-byte
   glyphs from the asm / ROM slice (`dump_credits_font` / `dump_hud_font`
   / `dump_logo_font`). Palettes: `parse_asm_palette_tables` (3-byte
   records until `0xFF`; stitch pal_9ffe from room_gfx into
   room_palettes).
3. Resolve dest (scripts / loaders) and palette as above. Unnamed enemy
   streams: match decompressed dests against SAT maps for a type.
   Metatiles: compose the 4×4 from the matching tileset (`_stage_tileset_cells`
   / `_intro_tileset_cells`). Streams: stitch 8×6 of those defs; pad
   unused columns with `None` cells. Palettes: fill an 8×8 with that record's
   RGB; unused indices in the 16-wide row stay `OFF`.
4. `render_png(..., labels=..., scale=8)` into `SPRITE_DIR` (packed
   sprite asm), `TILESET_DIR` (4bpp tiles), `PALETTE_DIR` (solid
   swatches, `size=8`), or `METATILE_DIR` (4×4 defs, `size=32`; 8×6
   streams, `size=(256, 192)`, scale 1). Fonts:
   `FONT_DIR`, scale 12. Packed SAT composites use `render_packed_png`
   into `GFX`. Hook from `main()` / `dump_asm_sprite_rles` /
   `dump_asm_tilesets` / `dump_dracula_body` / `dump_asm_palettes` / `dump_asm_metatiles` /
   `dump_asm_mtile_streams` / `dump_enemy_frames`.
5. File header comment on the asm: `Preview: gfx/…/<stem>.png`; cell
   header meaning. One line in `docs/game-notes.md` gfx catalogue.
6. `make gfx` and check: every cell labelled (palette unused slots are
   the exception), colours match in-game, no duplicate header for
   different art.

Reuse `_paint_plane`, `_dump_sprite_rle_asm`, `_enemy_colour_maps`.
Do not add PIL/Pillow; `pngwrite.write_rgb` only.

## Asm ↔ PNG sync

Catalog sheets are 1:1 with their asms. Edit the asm → regenerate the PNG
(`make gfx` or `python3 tools/gfxdump.py`). Add / rename / delete the asm
→ the PNG goes with it. Do not commit a catalog PNG with no asm, or an
asm whose sheet is stale.

- **Tiles** — `gfx/tilesets/<stem>.png` ↔ `segments/data/<stem>.asm`
  (`dump_asm_tilesets`: `tileset_*.asm` plus intro/title/bonus HUD/HUD
  keys/portrait/vendor/`spike_bar`; `dump_dracula_body` for the packed
  32×32 frames). Trailing `0xFF` bank pads and partial last tiles are
  leftover, not missing cells; do not invent a header for them.
  `spike_bar` mount is 8×4 padded to an 8×8 cell. `dracula_body`
  H-mirrors are generated at load, not stored.
- **Palettes** — `gfx/palettes/<stem>.png` ↔ `segments/data/<stem>.asm`
  (`dump_asm_palettes`: `stage_palettes`, `room_palettes`). pal_9ffe's
  first two bytes live in `room_gfx.asm`; the sheet stitches them.
  Trailing `0xFF` pad after `intro_palette` is leftover. Pointer table
  `stage_palette_ptr` is not a row.
- **Metatiles** — `gfx/metatiles/<stem>.png` ↔ the def table
  (`dump_asm_metatiles`: `mtile_defs_s00`..`s18`, `mtile_def_intro`)
  or the 8×6 stream table (`dump_asm_mtile_streams`: `mtile_streams`,
  `mtile_stream_intro`). Bank-straddle def tables (`s00`, `s18`) are
  one file each, like `tileset_s01` crossing 0x8000. `stage_sNN.png` is
  the geographic/minimap composite (HUD cropped), not this set.
- **Sprites** — `gfx/sprites/<stem>.png` ↔ `segments/data/<stem>.asm` for
  exactly `ASM_SPRITE_STEMS` (`enemy_sprite_rle`, `simon_rle`,
  `intro_sky`, `title_jp_sprites`). `dump_asm_sprite_rles`. A new packed
  sprite asm needs its stem added to that set.
- **Fonts** — `gfx/fonts/<stem>.png` ↔ `segments/data/<stem>.asm` for
  exactly `ASM_FONT_STEMS` (`font_credits`, `font_hud`, `font_logo`).
  `dump_credits_font` / `dump_hud_font` / `dump_logo_font`. A new font
  asm needs its stem added to that set.

Composites (`gfx/enemy_sheet.png`, `gfx/sheet_enemy_*.png`) are derived
from SAT + VRAM, not a single asm; still regenerate them when those
inputs or the compositor change.

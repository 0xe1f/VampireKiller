---
name: vk-gfx-sheets
description: >-
  Vampire Killer catalogue sheets: stem tables, SAT composites, stage palettes,
  simon_rle/intro_sky anti-patterns, gfxdump.py hooks. Generic cell/header rules
  are the MSXDAW skill msx-gfx-sheets.
---

# Vampire Killer gfx sheets

Cell, header, off-colour, 1bpp `%xxxxxxxx`, no PIL, and PNG-is-preview are
`msx-gfx-sheets`. Implement in `tools/gfxdump.py`; `make gfx` regenerates.
Bytes live in `segments/data/*.asm`.

Canonical catalog look: `gfx/tilesets/tileset_s01.png`,
`gfx/metatiles/mtile_defs_s01.png`, `gfx/metatiles/mtile_streams.png`,
`gfx/sprites/enemy_sprite_rle.png`, `gfx/palettes/stage_palettes.png`.
New catalog dumps match those, **not** `simon_rle` / `intro_sky`.

## Stems and directories

| Dir | This cart |
|-----|-----------|
| `gfx/sprites/` | `ASM_SPRITE_STEMS`: `enemy_sprite_rle`, `simon_rle`, `intro_sky`, `title_jp_sprites` |
| `gfx/fonts/` | `ASM_FONT_STEMS`: `font_credits`, `font_hud`, `font_logo` |
| `gfx/tilesets/` | `tileset_*`, intro/title, bonus HUD, HUD keys, portrait, `spike_bar`, `dracula_body`, vendor |
| `gfx/palettes/` | `stage_palettes`, `room_palettes` |
| `gfx/metatiles/` | `mtile_defs_sNN`, `mtile_def_intro`, `mtile_streams`, `mtile_stream_intro` |
| `gfx/` | SAT composites (`enemy_sheet.png`, `sheet_enemy_*`), vendor, `stage_sNN.png` (geographic, HUD cropped) |

A new packed sprite / font asm must be added to `ASM_SPRITE_STEMS` /
`ASM_FONT_STEMS`. Composites are SAT+VRAM, not a single asm.

## This cart’s atoms

Generic 8×8 / 16×16 / glyph / swatch sizes are `msx-gfx-sheets`. Extra here:

| Kind | Notes |
|------|--------|
| 8×4 fragment | `spike_bar` mount: 16 bytes, pad to 8×8; 2 cols |
| packed 32×32 | `dracula_body`; `_unpack_dracula_body`; 2 cols; H-mirrors are generated at load |
| 4×4 metatile def | 16 bytes → 32×32; 8 cols; nametable id 0 blank, id N = ROM tile N−1 |
| 8×6 room stream | 48 bytes → 256×192; one stage per row; scale 1; HUD **not** cropped |

Fonts: scale 12. Streams: scale 1 so a room cell is as wide as a scale-8
metatile def.

## Headers (this ROM)

4-digit hex, unique per cell: `msx-gfx-sheets`. This cart’s meaning:

- Tiles / palettes / metatile defs / streams: CPU of that atom in the asm
  (`7220`, `BECD`, `80B1`, `617B`; intro stream `614B`). Empty stream pads
  unlabeled. Palette unused slots unlabeled.
- Sprite planes: VRAM dest (`FA00`…). Pattern *N* is `0xF800 + N*8`.
- Fonts: 2-digit glyph id. Credits: ASCII. HUD: vk id `0x20+`. Logo: `01`–`34`.

Do not header a whole sheet of different art with shared `F800`.

## Palette (this ROM)

Paint with the VDP palette in force for that object (`msx-gfx-sheets`). Resolvers:

- `tileset_sNN` / `mtile_defs_sNN`: `vk_stage_palette(data, N)` (first stage
  of a shared set: s01 → 1). `mtile_def_intro`: `vk_intro_palette`. Stage 18
  Dracula-room defs: event-6 portrait overlay (frame from nametable id 6,
  face from 0x1E), not the title-tiles tail of the 0xBF blit.
- `mtile_streams`: `vk_playfield_palette(data, stage, room)` per cell.
  Stage 18 room 9: event-6 portrait atlas + `_s18_portrait_palette`.
  `mtile_stream_intro`: `vk_intro_palette`.
- Enemy planes: SAT `col & 0x0F` via `_sat_plane_map` for a room that loads
  the stream. Shot poses packed in the same RLE (`ENEMY_SHOT_FRAMES`: mummy
  bandage, bone, axe, snake, sickle) use `shot_sat_ptr`, not actor SAT.
  HUD-fixed 2/12/14 stay HUD-fixed; 4/5/6/7 from the room overlay.
- Thrown weapons at `F8C0`: knife/axe `02`/`0C`, cross `0F`/`0E`, HUD-fixed
  (`_weapon_plane_map`).
- HUD / bonus / title tiles: `vk_play_palette`. Intro tiles: `vk_intro_palette`.
  Portrait: HUD-fixed then `0xBF6F`. `spike_bar`: stage 6 room 1. `dracula_body`:
  stage 18 room 9. Fonts: HUD-fixed ink 14 (`glyph_blit_run`).
- Palette sheets: the table’s own RGB. Column N = VDP index N. Empty
  (`pal_a04a`): a row of `OFF`. pal_9ffe’s first two bytes live in
  `room_gfx.asm`; the sheet stitches them. `stage_palette_ptr` is not a row.

## Anti-patterns (do not copy)

**`simon_rle.png`** — headers repeat `F800`/`F840` across unrelated frames.
Colour is even-plane HUD 1 / odd-plane HUD 2, not SAT `01`+`42` (overlap 3).

**`intro_sky.png`** — backdrop strip, every plane intro-palette 14. Not
discrete objects and not per-cell colour.

## Dumper hooks (`tools/gfxdump.py`)

Parse: `parse_asm_tile8` (skip `rest of` prefixes), `_unpack_dracula_body`,
`parse_asm_mtile_defs` (s00/s18 are one file each), `parse_asm_mtile_streams`
/ `parse_asm_mtile_stream_intro`, `_parse_asm_sprite_rle` + `rledec.decompress`
(skip `*unid*`; no cell for a partial leftover), `dump_credits_font` /
`dump_hud_font` / `dump_logo_font`, `parse_asm_palette_tables`.

Compose metatiles from `_stage_tileset_cells` / `_intro_tileset_cells`.
Reuse `_paint_plane`, `_dump_sprite_rle_asm`, `_enemy_colour_maps`.
Hook from `main()` / `dump_asm_sprite_rles` / `dump_unused` /
`dump_asm_tilesets` / `dump_dracula_body` / `dump_asm_palettes` /
`dump_asm_metatiles` / `dump_asm_mtile_streams` / `dump_enemy_frames`.

Enemy SAT sheets replay `gfx_script_convert`. Do not H-flip (or otherwise
invent) pixels the ROM does not produce — types **14** / **21** have no
convert facing.

Trailing `0xFF` bank pads and partial last tiles are leftover, not missing
cells. File header on the asm: `Preview: gfx/…/<stem>.png`. One line in
`docs/game-notes.md` gfx catalogue (orphans: `docs/unused.md`).

## Unused extra sheets (`dump_unused`)

Not 1:1 with an asm. Prefix `unused_`. Inventory: `docs/unused.md`.

- `gfx/sprites/unused_simon.png` — 6 orphan `simon_rle_*` streams
- `gfx/sprites/unused_enemy.png` — `gfx_rle_aee0` / `gfx_rle_af96`
- `gfx/sprites/unused_unid_b50b.png` — raw 64 bytes at 0xB50B as 1bpp planes
- `gfx/tilesets/unused_tiles.png` — blank portrait gap + complete `0xFF` pad tiles
- `gfx/unused_poses.png` — SAT composites for never-stored `ix+0B` ids

Orphan sprite headers: packed-stream CPU + unpacked plane offset (plane 1
is not a second ROM stream). Unid headers: real CPU of each 32-byte slice
(0xB50B / 0xB52B).

# Unused ROM assets

Graphics the game never loads, or bank-end filler that is not artwork.
Sheets are `make gfx` (`tools/gfxdump.py`). Cell header is 4 uppercase hex
digits (packed-stream CPU + plane offset for orphan sprites; CPU of the
tile; pose id for `unused_poses.png`).

## Dumped (`unused_` prefix)

### Sprites (`gfx/sprites/`)

| Sheet | What | Why unused |
|-------|------|------------|
| `unused_simon.png` | 6 packed RLE streams (0xA671, 0xA6E4, 0xA759, 0xAF78, 0xAFEA, 0xB05F). Each unpacks to two 16×16 planes. | Not in `simon_cell0_ptr` / `simon_cell1_ptr` / intro load. Second plane after a listed frame. |
| `unused_enemy.png` | `gfx_rle_aee0` (6 planes) and `gfx_rle_af96` (8 planes). | Not in any room gfx-script or `load_weapon_sprites` / `load_vdoor_sprites` / frontend dest. |
| `unused_unid_b50b.png` | 64 bytes at 0xB50B as two raw 16×16 1bpp planes (HUD ink 14). | Not a valid RLE stream (`rle_dec` overruns into `spr_hanging_bat`). Plane 0 looks like a silhouette; plane 1 is sparse. Reading the same bytes as 4bpp 8×8 or as 8×8 glyphs is noise — not dumped. |

Address-named `gfx_rle_*` other than AEE0/AF96 **are** loaded (pads, frontend, fireball/flame, vdoor, weapons). They stay on `enemy_sprite_rle.png`.

### Tiles (`gfx/tilesets/unused_tiles.png`)

| CPU | Bytes | Looks like |
|-----|-------|------------|
| 0xBB18 | 6 × 8×8 (blank / index 0) | Gap in `dracula_portrait` before the 16×16 parts. Never blitted. |
| 0xBFD2 | 1 × 8×8 of `0xFF` (colour 15) | Bank 8 end. Complete tile of ROM fill. |
| 0xBFC8 | 1 × 8×8 of `0xFF` | Bank 6 end (`hud_weapon_key_tiles`). First 32 of 56 pad bytes. |

### Poses (`gfx/unused_poses.png`)

SAT composites for `ix+0B` ids the tick **never stores**. Art is copies of used poses (open-mouth merman, hunchback/Igor duplicates, fourth roc flap). Ids: **0x0A, 0x0D, 0x2D–0x32, 0x76–0x78, 0x8E**.

## Not dumped (not artwork, or no pixels to blit)

### Incomplete bank-end pads

All `0xFF` (or one `0x00`) fill to the next 8 KiB boundary. Not a complete atom except the two 8×8s above.

| Where | CPU | Length | Incomplete as |
|-------|-----|--------|----------------|
| `tileset_s08_pad.asm` after the 32-byte tile | 0xBFF6 | 14 | “rest of” 8×8 |
| `hud_weapon_key_tiles.asm` after 0xBFC8 | 0xBFE8 | 24 | 8×8 |
| `dracula_portrait_parts.asm` | 0xBFD8 | 40 | 16×16 (need 128) |
| `stage_palettes.asm` after `0xFF` terminator | 0xBFC0 | 64 | not a palette table |
| `font_logo.asm` | 0xBFF9 | 7 | 8×8 glyph (need 8) |
| `title_jp_sprites.asm` | 0xBE58 | 1 × `0x00` | align to `logo_font` |

### Unused pose ids with no room VRAM

**0xA3** `shape_pickup_single` and **0xA4** `shape_fireball_single` are 1-cell SAT records (patterns 0xEC / 0xF0). Those patterns are not in any room gfx-script, so there is nothing to composite. Used pickup / fireball art is already on `enemy_sprite_rle.png` (`gfx_rle_a185` @ FF00).

### Not graphics

| Item | Notes |
|------|--------|
| PSG 2 bytes at 0x8E29 (`1F A8`) | Dummy before `sfx_01`; not a stream. |
| `music_8f_silence` | Table slot; three pointers at the same dummy. |
| `spawn_bit7` | Bit in spawn masks; never dispatched. |

`sfx_tbl` / `music_ptr` and the door 8×8 tiles in `banks_0123` are used; they stay next to their consumers on purpose.

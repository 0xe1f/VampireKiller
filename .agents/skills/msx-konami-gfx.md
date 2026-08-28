---
name: msx-konami-gfx
description: >-
  Inspect Konami MSX graphics: decompress and repack VRAM RLE (rledec.py /
  rleenc.py) and render 1bpp or 4bpp patterns as ASCII (gfxview.py). Use when
  hunting sprites, tiles, fonts, SCREEN 5 bitmaps, packed RLE streams, or
  identifying graphics at a ROM or VRAM offset. Not for labelled PNG catalogue
  sheets (that is msx-gfx-sheets / gfxdump.py).
---

# Konami MSX gfx (ASCII / RLE)

Need a built `<Game>.rom` (`make`). File offsets are **ROM file** offsets, not
CPU addresses, unless the region is already a flat dump. Committed source keeps
original packed bytes; PNG/`rleenc` is preview or modding.

## Hunt by eye

```
tools/disasm/gfxview.py <file> <hex-off> [--count N] [--size 8|16] [--cols C] [--bpp 1|4]
tools/disasm/gfxview.py <file> <hex-off> --bpp 4 --raw --width W --rows R
```

| `--bpp` | Use for | Layout |
|---|---|---|
| `1` (default) | hardware sprites, SCREEN 1/2 patterns | 8x8 = 8 bytes/row; 16x16 = 32 bytes, quadrants TL BL TR BR |
| `4` | SCREEN 5/7 bitmaps | N rows of N/2 bytes, linear, high nibble = left pixel |

`--raw` is a whole loaded image, not a tile grid. Colour 0 prints as `.`.

## Konami VRAM RLE

Grammar (linear source, moving VRAM pointer):

| Op | Meaning |
|---|---|
| `00` | end |
| `80 lo hi` | VRAM write pointer = `hi<<8\|lo` |
| `01..7F` | RUN: next byte repeated N times |
| `81..FF` | LITERAL: copy `(N & 0x7F)` bytes |

The loader is entered with HL = initial dest (`--dest`, often `0xF800`).

```
tools/disasm/rledec.py <rom> <src-hex> [--dest 0xF800] [--out out.bin]
tools/disasm/gfxview.py out.bin 0 --bpp 1 --size 16 --count 16 --cols 8
```

`<src-hex>` is the file offset of the packed stream.

## Repack (not always byte-exact)

```
tools/disasm/rleenc.py flat.bin [--out packed.rle]
tools/disasm/rleenc.py flat.bin --verify <rom> <src-hex>
```

Does not emit `0x80` set-addr (one contiguous pixel run). Round-trips pixels;
may differ from the original stream. Do not replace assemble-source RLE with
packer output unless the user asked to edit the asset.

`pngwrite.py` is a library (`write_rgb`); game sheet dumpers import it. Contact
sheets: `msx-gfx-sheets`.

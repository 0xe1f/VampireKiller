# MSX disassembly helpers

Reusable Konami/MSX MegaROM tools. For a new game, copy this directory to
`tools/disasm/` and keep game-specific dump/sheet/handbook scripts in `tools/`.

Expected layout:

```
<repo>/
  tools/
    disasm/          this kit
    sjasmplus        assembler binary
  segments/          asm, msx.sym, *.blocks
  generated/         gitignored scratch
```

## Regen / static analysis

| Script | Role |
|---|---|
| `regen-seg.sh` | Slice an 8 KiB bank from the ROM, run z80dasm, strip listing comments |
| `seg_sym.py` | Per-bank z80dasm `-S` file from a flat `msx.sym` (banked CPU addresses collide) |
| `strip-listing.py` | Drop z80dasm `;addr bytes ascii` tails; keep hand-written comments |
| `split-rom.sh` | Drop leftover `segments/segNN.bin` after a bank is fully migrated |
| `romscan.py` | Xref (`call`/`jp`/`jr` vs bare word) and dispatch-table decode |

`regen-seg.sh` and `romscan.py` look for `$ROM`, then `<Game>.rom` in the repo
root. Override with `ROM=path` or `romscan.py --rom path`.

## Graphics (generic)

| Script | Role |
|---|---|
| `rledec.py` | Konami VRAM RLE decompressor |
| `rleenc.py` | Inverse packer (not always byte-exact vs original streams) |
| `gfxview.py` | ASCII 1bpp / 4bpp pattern viewer |
| `pngwrite.py` | Stdlib-only RGB PNG writer (used by game-specific sheet dumpers) |

Runtime tracing (instrumented CocoaMSX, `snapdiff.py`) lives in
`~/code/cocoamsx-disasm`, not this directory.

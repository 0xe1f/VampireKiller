# Vampire Killer (MSX2) — disassembly

> This project is a human-guided, largely AI-executed workflow.

A work-in-progress, **byte-exact and reassemblable** disassembly of Konami's
*Vampire Killer* (*Akumajō Dracula*, 1986) for the MSX2 — a 128 KiB Konami
MegaROM (Konami4, no SCC).

The goal is a readable, commented, buildable source that reproduces the original
ROM exactly, so the game can be understood and modified.

## What's here

```
VampireKiller.asm   master file: stitches the 16 segments into the ROM image
segments/           one file per 8 KiB segment
  seg00.asm         segment 0 (resident bank) — disassembled & annotated
  seg01..15         included as binary (regenerated from the ROM; not committed)
tools/              helper scripts + symbol/block files (see below)
docs/               notes (game behaviour, text encoding, sprites) + progress
gfx/                readable graphics catalogue (manifest committed; dumps regen)
Makefile            build / verify
```

No copyrighted game data is committed. The original ROM and the per-segment
binaries are excluded via `.gitignore`; you supply your own ROM to build.

## Building

You need two things that are not in the repo:

1. **sjasmplus** — the assembler. Build it from source
   ([z00m128/sjasmplus](https://github.com/z00m128/sjasmplus)) and place the
   binary at `tools/sjasmplus`.
2. **An original `VampireKiller.rom`** (128 KiB) placed one directory above this
   repo (`../VampireKiller.rom`).

Then:

```sh
make segments   # split the ROM into segments/seg01..15.bin (run once)
make verify     # assemble and confirm the output is byte-identical to the ROM
```

`make` alone produces `VampireKiller.rom` in the repo root.

## How it works

128 KiB = 16 × 8 KiB segments (Konami4 mapping). Segment 0 is always resident at
`0x4000-0x5FFF`; segments are converted from raw binary into commented
disassembly one at a time, and after every change the ROM is rebuilt and compared
against the original so it stays byte-for-byte identical.

Text is stored as `ASCII - 0x10`; a small `vk()` helper (in `VampireKiller.asm`)
lets strings be written as readable ASCII while emitting the exact original bytes.

Graphics are SCREEN 5 (4bpp) bitmaps and 16×16 hardware sprites, stored
RLE-compressed. `make gfx` decompresses the streams listed in `gfx/manifest.tsv`
into readable `.bin`/`.txt` dumps (plus `.png` sheets for clarity) for
inspection/editing; `tools/rleenc.py` re-packs them. The committed build keeps
the original compressed bytes, so it stays byte-exact.

See `docs/` for reverse-engineering notes and `docs/progress.md` for current
status and next steps.

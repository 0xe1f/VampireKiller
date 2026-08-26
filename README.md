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
  seg00..03.asm     code banks — INCLUDE'd, being annotated
  seg04..10.asm     INCLUDE stitchers (tilesets, gfx scripts, palettes, RLE)
  seg11..15.asm     map / scenery / credits font / PSG / portrait — INCLUDE'd
  data/             metatiles, tilesets, 1bpp sprite RLE, PSG, gfx scripts
tools/              helper scripts + symbol/block files (see below)
docs/               notes (game behaviour, text encoding, sprites) + progress
gfx/                readable graphics catalogue (PNG sheets committed; `make gfx`)
music/              BGM catalogue (WAV; `make music` from the ROM bytecode;
                    recognizable, not fully hardware-accurate yet)
sfx/                SFX catalogue (WAV; `make sfx`; `05_whip.wav`, etc.)
Makefile            build / verify
```

The original ROM is still required for `make verify`. All banks assemble from
labeled `.asm` (no leftover `.bin`).
Tilesets, gfx scripts, RLE, and PSG assemble from labeled `.asm`;
`tools/emit_identified_data.py` regenerates those dumps from the ROM.

## Building

You need two things that are not in the repo:

1. **sjasmplus** — the assembler. Build it from source
   ([z00m128/sjasmplus](https://github.com/z00m128/sjasmplus)) and place the
   binary at `tools/sjasmplus`.
2. **An original `VampireKiller.rom`** (128 KiB) placed at
   `references/VampireKiller.rom`. It is gitignored and is used to verify
   the build.

Then:

```sh
make verify     # assemble and confirm the output is byte-identical to the ROM
```

`make` alone produces `VampireKiller.rom` in the repo root (gitignored build
output; the reference ROM lives in `references/`).

## How it works

128 KiB = 16 × 8 KiB segments (Konami4 mapping). Segment 0 is always resident at
`0x4000-0x5FFF`; segments are converted from raw binary into commented
disassembly one at a time, and after every change the ROM is rebuilt and compared
against the original so it stays byte-for-byte identical.

Text is stored as `ASCII - 0x10` (HUD/title) or plain ASCII (credits); the
`vk` / `cr` macros in `VampireKiller.asm` let strings be written as readable
ASCII while emitting the exact original bytes (space → 0x00).

Graphics: uncompressed playfield tilesets are hex `defb` (one 4-byte row per
scanline). Sprites stay RLE-packed in source (`rleenc.py` is not byte-exact).
`make gfx` writes PNG previews from the ROM.

See `docs/` for reverse-engineering notes and `docs/progress.md` for current
status and next steps.

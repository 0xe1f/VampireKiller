# Vampire Killer (MSX2) — disassembly

[![verify](https://github.com/0xe1f/VampireKiller/actions/workflows/verify.yml/badge.svg)](https://github.com/0xe1f/VampireKiller/actions/workflows/verify.yml)
[![in source](https://img.shields.io/endpoint?style=flat&url=https://raw.githubusercontent.com/0xe1f/VampireKiller/badges/in-source.json)](https://github.com/0xe1f/VampireKiller/actions/workflows/verify.yml)
[![named](https://img.shields.io/endpoint?style=flat&url=https://raw.githubusercontent.com/0xe1f/VampireKiller/badges/named.json)](https://github.com/0xe1f/VampireKiller/actions/workflows/verify.yml)
[![comments](https://img.shields.io/endpoint?style=flat&url=https://raw.githubusercontent.com/0xe1f/VampireKiller/badges/commented.json)](https://github.com/0xe1f/VampireKiller/actions/workflows/verify.yml)
[![subs](https://img.shields.io/endpoint?style=flat&url=https://raw.githubusercontent.com/0xe1f/VampireKiller/badges/subs.json)](https://github.com/0xe1f/VampireKiller/actions/workflows/verify.yml)

> This project is a human-guided, largely AI-executed workflow.

A work-in-progress, **byte-exact and reassemblable** disassembly of Konami's
*Vampire Killer* (*Akumajō Dracula*, 1986) for the MSX2 — a 128 KiB Konami
MegaROM (Konami4, no SCC).

The goal is a readable, commented, buildable source that reproduces the original
ROM exactly, so the game can be understood and modified.

You can find random interesting facts from the disassembly at
[@msxti.me](https://bsky.app/profile/msxti.me) on Bluesky.

## What's here

```
VampireKiller.asm   master file: stitches paging windows into the ROM image
VampireKiller.sha1  SHA-1 of the original 128 KiB ROM (`make verify`)
segments/           one file per paging window (fills through 0xC000)
  banks_0123.asm    banks 0-3: resident + play (32K @ 0x4000)
  banks_456.asm     banks 4-6: tileset window (24K @ 0x6000)
  banks_78.asm      banks 7-8: late tilesets / HUD font / ending
  banks_9a.asm      banks 9-a: title gfx / palettes / enemy RLE
  banks_bcd.asm     banks b-d: map tables / metatile defs / transitions
  banks_ef.asm      banks e-f: scenery / PSG / Dracula portrait
  data/             metatiles, tilesets, fonts, 1bpp sprite RLE, PSG, gfx scripts,
                    scenery/spawn/object lists, conn/door/spot tables
  actors.inc etc.   small numeric ids (actor/item/weapon/sfx/pose/scenery/event/state/dir)
tools/              game-specific helpers (gfx sheets, maps, PSG)
  workbench/        MSXDAW submodule (regen, romscan, RLE, PSG)
docs/               reverse-engineering notes (`game-notes.md`, `vendor.md`, `progress.md`, `unused.md`)
gfx/                readable graphics catalogue (PNG sheets committed; `make gfx`)
                    sprites/ packed 1bpp sprite-asm sheets; tilesets/ 4bpp
                    playfield/title; palettes/ palette_apply swatches;
                    metatiles/ 4x4 def sheets and 8x6 room streams; fonts/ 1bpp glyph sheets;
                    composites at gfx/ root (`stage_sNN.png` annotated playfields,
                    `minimap_sNN.png` schematic layouts)
music/              BGM catalogue (WAV; `make music` from the ROM bytecode;
                    recognizable, not fully hardware-accurate yet)
sfx/                SFX catalogue (WAV; `make sfx`; `05_whip.wav`, etc.)
Makefile            build / verify
```

All banks assemble from labeled `.asm` (no leftover `.bin`).
Tilesets, gfx scripts, RLE, and PSG assemble from labeled `.asm`;
`tools/emit_identified_data.py` regenerates those dumps from a ROM image.

## Building

You need **sjasmplus**, built from source
([z00m128/sjasmplus](https://github.com/z00m128/sjasmplus)) and placed at
`tools/sjasmplus`. No original ROM and no MSXDAW workbench checkout are
required to assemble or verify. (`make gfx` / `make music` / `make sfx` and
bank regen use the `tools/workbench` submodule.)

After a clone with the submodule, link generic agent skills into this repo
(not `~/.cursor/skills`):

```sh
make skills     # tools/workbench/bin/install-skills -> .cursor/skills/
make verify     # assemble, then SHA-1 check against VampireKiller.sha1
make coverage   # local Shields JSON under generated/badges/
```

`make` alone produces `VampireKiller.rom` in the repo root (gitignored).
`VampireKiller.sha1` is the SHA-1 of the original 128 KiB MSX2 ROM; `make verify`
rebuilds and confirms the output matches it.

## How it works

128 KiB = 16 × 8 KiB segments (Konami4 mapping). Segment 0 is always resident at
`0x4000-0x5FFF`; segments are converted from raw binary into commented
disassembly one at a time, and after every change the ROM is rebuilt and SHA-1
checked so it stays byte-for-byte identical.

Text is stored as `ASCII - 0x10` (HUD/title) or plain ASCII (credits); the
`vk` / `cr` macros in `VampireKiller.asm` let strings be written as readable
ASCII while emitting the exact original bytes (space → 0x00).

Graphics: uncompressed playfield tilesets are hex `defb` (one 4-byte row per
scanline). Sprites stay RLE-packed in source (`tools/workbench/konami/rleenc.py` is not byte-exact).
`make gfx` writes PNG previews from the ROM, including `gfx/enemy_sheet.png`
and a full-frame sheet per enemy (`gfx/sheet_enemy_zombie_01.png`, …).
Packed 1bpp sprite asms dump to `gfx/sprites/<stem>.png`.
Orphan / unused slices: `gfx/sprites/unused_*.png`,
`gfx/tilesets/unused_tiles.png`, `gfx/unused_poses.png`
(`docs/unused.md`).
Each 4bpp tileset asm has a sheet at `gfx/tilesets/<stem>.png`.
Each palette_apply asm has a sheet at `gfx/palettes/<stem>.png`
(16 columns = VDP index; cell header = CPU address of the 3-byte record).
Each metatile-def table has a sheet at `gfx/metatiles/<stem>.png`
(4×4 tiles, cell header = CPU address of the def).
Room streams are `gfx/metatiles/mtile_streams.png` (one stage per row)
and `gfx/metatiles/mtile_stream_intro.png` (cell header = CPU of the
48-byte stream). `gfx/stage_sNN.png` is the annotated playfield composite
(`roomperm.py --composite`; rooms, scenery, enemies, vendors). `gfx/minimap_sNN.png` is the schematic
F2-minimap layout.

See `docs/game-notes.md` for reverse-engineering notes, `docs/vendor.md` for
the vendor / difficulty-tier map, `docs/unused.md` for leftover ROM assets,
and `docs/progress.md` for current status
and next steps.

## License

Original work in this repository (tools, comments, documentation, labels,
and project structure) is licensed under the Apache License, Version 2.0.
See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).

*Vampire Killer* (*Akumajō Dracula*) is © 1986 Konami. This project does
not relicense the original game, ROM, graphics, or music.

#!/usr/bin/env python3
"""Render regions of the ROM as MSX patterns (ASCII art) to hunt for graphics
(font glyphs, sprites, tiles, bitmaps) by eye.

Two pixel formats:
  --bpp 1  1 bit per pixel, MSB = leftmost pixel (hardware sprites, SCREEN 1/2
           patterns).  '#' = set, '.' = clear.
      8x8   tile/sprite pattern : 8 bytes, one byte per row.
      16x16 sprite pattern      : 32 bytes, four 8x8 quadrants ordered
                                  TL(0..7) BL(8..15) TR(16..23) BR(24..31).
  --bpp 4  4 bits per pixel, high nibble = left pixel (SCREEN 5/7 bitmaps, which
           is what Vampire Killer uses).  Each pixel prints as its colour index
           0-F, with colour 0 shown as '.' (transparent/background).
      A NxN tile is N rows of N/2 bytes, stored top-to-bottom (no quadrants).

  --raw    Treat the region as a linear bitmap --width pixels wide and --rows
           tall (best for whole loaded images rather than tile arrays).

Usage:
  tools/gfxview.py <file> <hex-offset> [--count N] [--size 8|16]
                   [--cols C] [--bpp 1|4] [--raw --width W --rows R]

Examples:
  tools/gfxview.py references/VampireKiller.rom 0x8000 --bpp 4 --size 16 --count 8 --cols 8
  tools/gfxview.py references/VampireKiller.rom 0x8000 --bpp 4 --raw --width 64 --rows 32
"""
import argparse

ON, OFF = "#", "."
HEX = "0123456789ABCDEF"

def nib(v):                            # 4bpp colour index -> char
    return "." if v == 0 else HEX[v]

def row_bits(b):
    return "".join(ON if (b >> (7 - i)) & 1 else OFF for i in range(8))

def row_nibs(bs):                      # bytes -> 2 chars per byte
    return "".join(nib(b >> 4) + nib(b & 0xF) for b in bs)

def tile8_1bpp(data):
    return [row_bits(data[r]) for r in range(8)]

def sprite16_1bpp(data):
    tl, bl, tr, br = data[0:8], data[8:16], data[16:24], data[24:32]
    return ([row_bits(tl[r]) + row_bits(tr[r]) for r in range(8)] +
            [row_bits(bl[r]) + row_bits(br[r]) for r in range(8)])

def tile_4bpp(data, size):             # size rows of size/2 bytes, linear
    bpr = size // 2
    return [row_nibs(data[r * bpr:(r + 1) * bpr]) for r in range(size)]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("offset")
    ap.add_argument("--count", type=int, default=16)
    ap.add_argument("--size", type=int, choices=(8, 16), default=8)
    ap.add_argument("--cols", type=int, default=8)
    ap.add_argument("--bpp", type=int, choices=(1, 4), default=1)
    ap.add_argument("--raw", action="store_true")
    ap.add_argument("--width", type=int, default=64)
    ap.add_argument("--rows", type=int, default=32)
    a = ap.parse_args()

    off = int(a.offset, 0)
    data = open(a.file, "rb").read()

    if a.raw:
        bpr = a.width if a.bpp == 1 else a.width // 2
        for r in range(a.rows):
            bs = data[off + r * bpr: off + (r + 1) * bpr]
            if len(bs) < bpr:
                break
            print(row_bits_line(bs) if a.bpp == 1 else row_nibs(bs))
        return

    if a.bpp == 1:
        step = 8 if a.size == 8 else 32
        render = tile8_1bpp if a.size == 8 else sprite16_1bpp
    else:
        step = a.size * a.size // 2
        render = lambda d: tile_4bpp(d, a.size)

    tiles = []
    for i in range(a.count):
        chunk = data[off + i * step: off + i * step + step]
        if len(chunk) < step:
            break
        tiles.append((off + i * step, render(chunk)))

    for base in range(0, len(tiles), a.cols):
        group = tiles[base: base + a.cols]
        print("  ".join("%-*s" % (a.size, "0x%X" % addr) for addr, _ in group))
        for r in range(a.size):
            print("  ".join(rows[r] for _, rows in group))
        print()

def row_bits_line(bs):
    return "".join(row_bits(b) for b in bs)

if __name__ == "__main__":
    main()

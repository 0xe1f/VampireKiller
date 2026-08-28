#!/usr/bin/env python3
# Copyright 2026 Akop Karapetyan
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Decompress a Konami MSX graphics RLE stream (VK: VRAM loader rle_dec /
rle_dec_addr at 0x46F2 in segment 0) into a flat binary.

Control-byte grammar (source is read linearly; the decompressed bytes are
written to a moving VRAM pointer):
  0x00            end of stream
  0x80  lo hi     set VRAM write pointer = hi<<8 | lo
  0x01..0x7F  N   RUN    : the next single byte, repeated N times
  0x81..0xFF  N   LITERAL: copy (N & 0x7F) bytes verbatim

The loader is entered with an initial VRAM destination (the caller's HL), so
pass it with --dest.  The output .bin is the contiguous VRAM region that was
written, so it can be fed straight to tools/disasm/gfxview.py.

Usage:
  tools/disasm/rledec.py <romfile> <src-hex-offset> [--dest 0xF800] [--out out.bin]

Example (Simon/enemy sprite patterns, seg13 @ file 0x1A319 -> VRAM 0xF800):
  tools/disasm/rledec.py VampireKiller.rom 0x1A319 --dest 0xF800 --out /tmp/spr.bin
  tools/disasm/gfxview.py /tmp/spr.bin 0 --bpp 1 --size 16 --count 16 --cols 8
"""
import argparse

def decompress(data, src, dest):
    """Return (bytearray_image, base_addr, end_src) for the VRAM region written."""
    mem = {}                            # addr -> byte
    p = src
    ptr = dest
    while True:
        c = data[p]; p += 1
        if c == 0x00:                   # end
            break
        if c == 0x80:                   # set VRAM pointer
            ptr = data[p] | (data[p + 1] << 8); p += 2
            continue
        if c & 0x80:                    # literal run of (c & 0x7f) bytes
            n = c & 0x7F
            for _ in range(n):
                mem[ptr] = data[p]; ptr += 1; p += 1
        else:                           # RLE run: next byte repeated c times
            b = data[p]; p += 1
            for _ in range(c):
                mem[ptr] = b; ptr += 1
    lo, hi = min(mem), max(mem)
    out = bytearray(hi - lo + 1)
    for a, v in mem.items():
        out[a - lo] = v
    return out, lo, p

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("romfile")
    ap.add_argument("offset")
    ap.add_argument("--dest", default="0xF800")
    ap.add_argument("--out", default=None)
    a = ap.parse_args()

    data = open(a.romfile, "rb").read()
    src = int(a.offset, 0)
    dest = int(a.dest, 0)
    out, base, end = decompress(data, src, dest)

    print("source 0x%X .. 0x%X  (%d compressed bytes)" % (src, end, end - src))
    print("VRAM   0x%X .. 0x%X  (%d bytes decompressed)" % (base, base + len(out) - 1, len(out)))
    if a.out:
        open(a.out, "wb").write(out)
        print("wrote %s" % a.out)

if __name__ == "__main__":
    main()

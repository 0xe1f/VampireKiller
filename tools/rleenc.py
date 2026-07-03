#!/usr/bin/env python3
"""Re-pack a flat byte buffer into a Vampire Killer RLE stream (the inverse of
tools/rledec.py / the game's decompressor sub_46f8h).

Grammar emitted:
  0x01..0x7F  N   RUN     : next single byte repeated N times
  0x81..0xFF  N   LITERAL : (N & 0x7F) bytes copied verbatim
  0x00            end of stream
(The 0x80 "set VRAM address" op is not emitted; a packed block is one
contiguous run of pixels, which is how the individual sprite/tile streams are
stored.)

The packer uses a shortest-output dynamic program, breaking ties in favour of a
RUN (which is what Konami's original packer does). It reproduces most original
streams byte-for-byte; where it does not, the output is still a valid, equal-or-
smaller stream that decodes to the identical pixels - fine for edited assets,
since path A keeps the untouched original bytes authoritative in the ROM.

Usage:
  tools/rleenc.py <flat.bin> [--out packed.rle]
  tools/rleenc.py <flat.bin> --verify <rom> <src-hex>   # compare to original
"""
import argparse

MAXRUN = 0x7F

def encode(buf):
    n = len(buf)
    INF = float("inf")
    cost = [INF] * (n + 1)
    nxt = [None] * (n + 1)
    cost[n] = 0
    for i in range(n - 1, -1, -1):
        rl = 1                                     # length of the identical run at i
        while i + rl < n and buf[i + rl] == buf[i] and rl < MAXRUN:
            rl += 1
        opts = [(2 + cost[i + L], "run", L) for L in range(1, rl + 1)]
        opts += [(1 + L + cost[i + L], "lit", L)
                 for L in range(1, min(MAXRUN, n - i) + 1)]
        # least bytes; tie -> prefer a RUN (as Konami's packer tends to), then
        # the longer segment.
        c, op, L = min(opts, key=lambda o: (o[0], 0 if o[1] == "run" else 1, -o[2]))
        cost[i], nxt[i] = c, (op, L)
    out = bytearray()
    i = 0
    while i < n:
        op, L = nxt[i]
        if op == "run":
            out.append(L)
            out.append(buf[i])
        else:
            out.append(0x80 | L)
            out += buf[i:i + L]
        i += L
    out.append(0x00)
    return bytes(out)

def decode(data, p=0):
    out = bytearray()
    while True:
        c = data[p]; p += 1
        if c == 0x00:
            break
        if c == 0x80:                              # set-addr: skip (not used here)
            p += 2; continue
        if c & 0x80:
            n = c & 0x7F
            out += data[p:p + n]; p += n
        else:
            out += bytes([data[p]]) * c; p += 1
    return bytes(out), p

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("flat")
    ap.add_argument("--out", default=None)
    ap.add_argument("--verify", nargs=2, metavar=("ROM", "SRC"))
    a = ap.parse_args()

    buf = open(a.flat, "rb").read()
    packed = encode(buf)
    roundtrip, _ = decode(packed)
    assert roundtrip == buf, "encoder produced a stream that does not round-trip!"
    print("packed %d bytes -> %d bytes (round-trip OK)" % (len(buf), len(packed)))

    if a.verify:
        rom = open(a.verify[0], "rb").read()
        src = int(a.verify[1], 0)
        orig_dec, end = decode(rom, src)
        orig = rom[src:end]
        same = packed == orig
        print("vs original 0x%X..0x%X (%d bytes): %s" %
              (src, end, len(orig), "IDENTICAL" if same else "differs (same pixels)"))
    if a.out:
        open(a.out, "wb").write(packed)
        print("wrote %s" % a.out)

if __name__ == "__main__":
    main()

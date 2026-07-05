#!/usr/bin/env python3
"""Render Vampire Killer's room/object maps from the packed object data in ROM
segment 14.

The world is a grid of single-screen rooms indexed by (row 0xD000, col 0xD001).
The per-room object list (enemies, braziers, doors, pickups, ...) is unpacked
from seg14 by seg1 sub_615bh into 0xDB00/0xDC00/0xDD00 (three rows).  The dataset
used for a given row is chosen by the row->dataset table at seg0 0x5E71
(rows 0-3 -> ds0, 4-6 -> ds1, ... 16-18 -> ds5).  Each dataset therefore covers
world rows  D000 = ds*3 + stream + 1  (stream 0..2), i.e. rows 1..18.  Row 0 is
the courtyard, drawn by a different path (no object-list entries).

Object stream grammar (per stream, see sub_6188h):
  0xFF            end of stream
  0x00            end of cell -> advance to the next column (rooms are 0x10 apart)
  id attr         one object: id bit7 = scenery flag, low 7 bits = sprite id;
                  attr high nibble = X cell (0-15), low nibble = Y cell (0-15)
                  -> screen position (X*16, Y*16) within the 256x212 room.

This is the LAYOUT map (where things are), not the wall/floor artwork (that is
separate RLE bitmap data loaded per room).

Usage:
  tools/roommap.py [--rom references/VampireKiller.rom] [--out-dir gfx]
                   [--datasets 0] [--cell 48]
  (--datasets accepts a comma list, or 'all'.  ds0 = stage 1 / castle entrance.)
"""
import argparse
from pngwrite import write_rgb

TABLE = 0x8668            # seg14 word table of dataset pointers (CPU addr)
ROWTBL = 0x5E71           # seg0 row->dataset byte table (CPU addr)

# Stable-ish colours per object id (low 7 bits).  Unknown ids get a hashed hue.
NAMED = {
    0x05: ((255,  80,  80), "enemy: dog (type 5)"),
    0x06: ((255, 140,  60), "enemy/actor 06"),
    0x09: ((255, 210,  60), "actor 09"),
    0x0a: ((190, 230,  70), "actor 0a"),
    0x0b: ((110, 220,  90), "actor 0b"),
    0x0c: (( 70, 220, 160), "actor 0c"),
    0x0d: (( 70, 200, 230), "scenery 0d (common)"),
    0x0e: (( 90, 150, 240), "actor 0e"),
    0x10: (( 90, 110, 240), "scenery 10 (common)"),
    0x12: ((160, 110, 240), "actor 12"),
    0x1f: ((230, 100, 230), "object 1f"),
    0x21: ((240, 100, 170), "object 21"),
}

def hued(i):
    if i in NAMED:
        return NAMED[i][0]
    import colorsys
    r, g, b = colorsys.hsv_to_rgb((i * 47 % 256) / 256.0, 0.6, 0.95)
    return (int(r * 255), int(g * 255), int(b * 255))

def decode_dataset(seg14, ptr):
    off = ptr - 0x8000
    rows = []
    for _ in range(3):
        cells, cur = [], []
        while True:
            b = seg14[off]; off += 1
            if b == 0xFF:
                break
            if b == 0x00:
                cells.append(cur); cur = []; continue
            attr = seg14[off]; off += 1
            cur.append((b, attr))
        if cur:
            cells.append(cur)
        rows.append(cells)
    return rows

class Canvas:
    def __init__(self, w, h, bg=(20, 22, 30)):
        self.w, self.h = w, h
        self.buf = bytearray(bg * (w * h))
    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            o = (y * self.w + x) * 3
            self.buf[o:o+3] = bytes(c)
    def rect(self, x0, y0, x1, y1, c):
        for y in range(max(0, y0), min(self.h, y1)):
            for x in range(max(0, x0), min(self.w, x1)):
                self.px(x, y, c)
    def frame(self, x0, y0, x1, y1, c):
        for x in range(x0, x1):
            self.px(x, y0, c); self.px(x, y1 - 1, c)
        for y in range(y0, y1):
            self.px(x0, y, c); self.px(x1 - 1, y, c)

def render(rows_data, cell, cols=16):
    """rows_data: list of (label, cells-list).  Returns a Canvas."""
    nrows = len(rows_data)
    pad = 1
    W = cols * cell + pad
    H = nrows * cell + pad
    cv = Canvas(W, H)
    marker = max(3, cell // 8)
    for ri, (_, cells) in enumerate(rows_data):
        for ci in range(cols):
            x0 = ci * cell + pad
            y0 = ri * cell + pad
            occupied = ci < len(cells) and len(cells[ci]) > 0
            cv.rect(x0, y0, x0 + cell - pad, y0 + cell - pad,
                    (34, 38, 52) if occupied else (26, 28, 38))
            cv.frame(x0, y0, x0 + cell - pad, y0 + cell - pad, (60, 66, 86))
            if ci >= len(cells):
                continue
            for (oid, attr) in cells[ci]:
                sid = oid & 0x7F
                ox = (attr >> 4) & 0x0F
                oy = attr & 0x0F
                px = x0 + int(ox * (cell - pad - marker) / 15)
                py = y0 + int(oy * (cell - pad - marker) / 15)
                c = hued(sid)
                cv.rect(px, py, px + marker, py + marker, c)
                if oid & 0x80:            # scenery flag: white corner pip
                    cv.px(px, py, (255, 255, 255))
    return cv

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rom", default="references/VampireKiller.rom")
    ap.add_argument("--out-dir", default="gfx")
    ap.add_argument("--datasets", default="0",
                    help="comma list of dataset indices, or 'all'")
    ap.add_argument("--cell", type=int, default=48)
    a = ap.parse_args()

    rom = open(a.rom, "rb").read()
    seg0 = rom[0x0000:0x2000]
    seg14 = rom[0x1C000:0x1E000]
    def ptr(L):
        o = (TABLE - 0x8000) + 2 * L
        return seg14[o] | (seg14[o + 1] << 8)

    if a.datasets == "all":
        dss = list(range(6))
    else:
        dss = [int(x, 0) for x in a.datasets.split(",")]

    rows_data = []
    used = set()
    for ds in dss:
        rows = decode_dataset(seg14, ptr(ds))
        for s in range(3):
            d000 = ds * 3 + s + 1
            rows_data.append((f"ds{ds} row D000={d000}", rows[s]))
            for cells in [rows[s]]:
                for objs in cells:
                    for oid, _ in objs:
                        used.add(oid & 0x7F)

    cv = render(rows_data, a.cell)
    tag = "world" if a.datasets == "all" else "ds" + "_".join(str(d) for d in dss)
    out = f"{a.out_dir}/map_{tag}.png"
    write_rgb(out, cv.w, cv.h, bytes(cv.buf))
    print(f"wrote {out}  ({cv.w}x{cv.h})")

    # text breakdown
    print("\nrow layout (D000 -> room columns with objects):")
    for label, cells in rows_data:
        occ = [(ci, objs) for ci, objs in enumerate(cells) if objs]
        if not occ:
            print(f"  {label}: (empty)")
            continue
        print(f"  {label}:")
        for ci, objs in occ:
            desc = ", ".join(f"{o&0x7f:02x}@({(a>>4)&0xf},{a&0xf})"
                             + ("*" if o & 0x80 else "") for o, a in objs)
            print(f"      col {ci:2}: {desc}")
    print("\nlegend (id -> meaning):")
    for i in sorted(used):
        name = NAMED.get(i, (None, "?"))[1]
        print(f"  {i:02x}: {name}")

if __name__ == "__main__":
    main()

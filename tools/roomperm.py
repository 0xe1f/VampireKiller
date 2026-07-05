#!/usr/bin/env python3
"""Decode Vampire Killer room geometry from ROM and render PERMEABILITY maps.

HOW ROOMS ARE STORED (all offsets are CPU addresses within an 8KB bank window):

  A room is an 8x6 grid of 4x4-tile METATILES -> 32x24 tile-name cells, expanded
  by seg0 0x4fb6 into work RAM at 0xD100 (the same map the collision helper
  seg1 sub_7d36h and the drawer seg0 0x4f98 read).  During the build the mapper
  pages bank 0x0b -> 0x6000, 0x0c -> 0x8000, 0x0d -> 0xA000, then restores bank 1.

  bank 0x0b (seg11), window 0x6000:
    0x6000  rowbase[row]          one byte per world row; index = rowbase[row]+col
    0x6013  roomptr[index]        word: pointer to that room's 48-byte metatile
                                  stream (8 wide x 6 tall, row-major)
    0x7ebb  defbase[row]          word: base of this row's metatile definitions
  metatile definition = 16 bytes = 4x4 tile ids (row-major); def(id) at
  defbase + id*16 in whichever bank the defbase address window selects
  (0x8000 -> seg12, 0xA000 -> seg13, 0x6000 -> seg11).

  Rooms in a row = rowbase[row+1] - rowbase[row].  World row 1 = stage 1 (8 rooms).

PERMEABILITY (default) = the structural floor/wall brick family: solid surfaces
01..04 and the brick BODY under/behind them 09..0b, laid out as a repeating
(surface, body) metatile - so a wall column alternates 01/09/01/09..., which is
why classifying only the surface produced horizontal stripes.  Everything else is
passable: air 0x0e..0x17; the decorative blocks 0x2c+ (background windows,
columns); and the passable decoration ids 05..08 (05/08 = the inert 2-tile pair;
06/07 = stage 1's wide-stair edge / background wallpaper elsewhere).  Stairs are
the CLIMBABLE diagonal tiles 0c (one way) and 0d (mirror) - drawn amber - which is
exactly what the engine's stair-step code tests; other stages draw 1-tile-wide
stairs (0c/0d only), while stage 1 pairs each step with a decorative 06/07 half
(hence its "fat" 2-wide stairs).
Colours: walls/floors white, empty black, climbable stairs amber.

Two other views:
  --collision : the engine's OWN feet/head test (seg1 tile_is_solid): solid iff
                (id-1) < row_solid_thresh[0xD000] (stage 1 -> 4).  This is exactly
                what blocks Simon, but only marks the 01..04 SURFACES (stripes).
  --visual    : structural family PLUS the 0x2c+ decorative blocks (shows the
                drawn artwork, but paints background scenery as if solid).

Output: one minimap (contact sheet) per stage, gfx/minimap_s<NN>.png (the default
permeability view; --collision/--visual add a _coll/_vis suffix), each cell
labelled with its room number in a dark-gray band.

Usage:
  tools/roomperm.py [--rom references/VampireKiller.rom] [--row 1 | --all]
                    [--scale 6] [--out-dir gfx] [--collision | --visual]
                    [--validate generated/disasmsnap.bin] [--ascii]
"""
import argparse, os

COLS, ROWS = 32, 24
PLAY_TOP = 2                    # rows 0-1 = HUD
STAIRS = {0x0c, 0x0d}   # the CLIMBABLE diagonal tiles (0c one way, 0d the mirror);
                        # this is what the engine's stair-step routines actually
                        # test (seg1 sub_7ce2h checks 0x0d, sub_7d0ch checks 0x0c).
DECOR = {0x05, 0x06, 0x07, 0x08}     # passable decoration, never solid or climbable:
                                     # 05/08 = the inert 2-tile pair; 06/07 = the
                                     # decorative half of stage 1's 2-wide stairs
                                     # (0c06/070d) and elsewhere just background
                                     # wallpaper (e.g. stage 10) - NOT stairs.
AIR = set(range(0x0e, 0x18)) | {0x00} | STAIRS | DECOR
COLL_THRESH = {0: 2, 1: 4, 2: 4, 3: 4, 4: 4, 5: 4, 6: 4, 7: 4, 8: 4, 9: 4,
               10: 9, 11: 9, 12: 9, 13: 4, 14: 4, 15: 4, 16: 9, 17: 9, 18: 8}

def is_solid(tid, row, mode):
    if mode == "collision":
        return (tid - 1) < COLL_THRESH.get(row, 4)   # matches seg1 tile_is_solid
    if tid in STAIRS or tid in DECOR:
        return False
    structural = 0x01 <= tid <= 0x0d                  # floor/wall brick family
    if mode == "visual":
        return structural or tid >= 0x2c              # + decorative scenery blocks
    return structural                                 # default: walls & floors only

class Rom:
    """During a room build the mapper pages three banks into a CONTIGUOUS CPU
    window: 0x0b->0x6000, 0x0c->0x8000, 0x0d->0xA000.  Tables (and even a single
    16-byte metatile def) can straddle the 0x8000/0xA000 boundary, so we present
    the whole 0x6000-0xBFFF range as one flat buffer."""
    def __init__(self, path):
        self.rom = open(path, "rb").read()
        self.win = self.bank(0x0b) + self.bank(0x0c) + self.bank(0x0d)
    def bank(self, n):
        return self.rom[n * 0x2000:(n + 1) * 0x2000]
    def read(self, addr, n=1):
        o = addr - 0x6000
        return self.win[o:o + n]
    def word(self, addr):
        lo, hi = self.read(addr, 2)
        return lo | (hi << 8)

def num_rooms(rom, row):
    base = rom.read(0x6000 + row)[0]
    nxt = rom.read(0x6000 + row + 1)[0]
    return nxt - base

def decode_room(rom, row, col):
    idx = rom.read(0x6000 + row)[0] + col
    sp = rom.word(0x6013 + 2 * idx)
    stream = rom.read(sp, 48)
    db = rom.word(0x7ebb + 2 * row)
    grid = [[0] * COLS for _ in range(ROWS)]
    for mr in range(6):
        for mc in range(8):
            mid = stream[mr * 8 + mc]
            d = rom.read(db + mid * 16, 16)
            for k in range(16):
                grid[mr * 4 + k // 4][mc * 4 + k % 4] = d[k]
    return grid

SOLID_RGB = (235, 235, 235)
EMPTY_RGB = (12, 12, 16)
STAIR_RGB = (240, 170, 40)      # climbable stairs (06/0c)

def tile_rgb(tid, row, mode):
    if tid in STAIRS:
        return STAIR_RGB
    return SOLID_RGB if is_solid(tid, row, mode) else EMPTY_RGB

def render(grid, row, scale, mode, top=PLAY_TOP):
    from pngwrite import write_rgb
    rows = ROWS - top
    W, H = COLS * scale, rows * scale
    buf = bytearray(W * H * 3)
    for r in range(rows):
        for c in range(COLS):
            col = tile_rgb(grid[r + top][c], row, mode)
            for yy in range(scale):
                o = ((r * scale + yy) * W + c * scale) * 3
                for xx in range(scale):
                    buf[o:o + 3] = bytes(col); o += 3
    return W, H, bytes(buf)

# 3x5 bitmap digits for the room-number labels
FONT3x5 = {
    "0": ("111", "101", "101", "101", "111"),
    "1": ("010", "110", "010", "010", "111"),
    "2": ("111", "001", "111", "100", "111"),
    "3": ("111", "001", "111", "001", "111"),
    "4": ("101", "101", "111", "001", "001"),
    "5": ("111", "100", "111", "001", "111"),
    "6": ("111", "100", "111", "101", "111"),
    "7": ("111", "001", "010", "100", "100"),
    "8": ("111", "101", "111", "101", "111"),
    "9": ("111", "101", "111", "001", "111"),
}
LABEL_RGB = (200, 200, 205)

def draw_text(buf, W, x, y, text, scale, color):
    for chr_ in text:
        glyph = FONT3x5.get(chr_)
        if glyph:
            for gy, row in enumerate(glyph):
                for gx, px in enumerate(row):
                    if px == "1":
                        for yy in range(scale):
                            base = ((y + gy * scale + yy) * W + x + gx * scale) * 3
                            for xx in range(scale):
                                o = base + xx * 3
                                buf[o:o + 3] = bytes(color)
        x += 4 * scale               # 3px glyph + 1px spacing

def contact_sheet(images, cols, gap, bg=(40, 44, 56), lab_scale=2):
    cw = max(w for w, h, _ in images)
    ch = max(h for w, h, _ in images)
    lab_h = 5 * lab_scale + 4        # digit height + padding (the dark-gray band)
    cell_h = lab_h + ch
    n = len(images)
    ncol = cols
    nrow = (n + ncol - 1) // ncol
    W = ncol * cw + (ncol + 1) * gap
    H = nrow * cell_h + (nrow + 1) * gap
    buf = bytearray(bytes(bg) * (W * H))
    for i, (w, h, data) in enumerate(images):
        r, c = divmod(i, ncol)
        x0 = gap + c * (cw + gap)
        y0 = gap + r * (cell_h + gap)
        draw_text(buf, W, x0 + 2, y0 + 2, str(i), lab_scale, LABEL_RGB)
        iy = y0 + lab_h              # image sits below the label band
        for y in range(h):
            src = y * w * 3
            dst = ((iy + y) * W + x0) * 3
            buf[dst:dst + w * 3] = data[src:src + w * 3]
    return W, H, bytes(buf)

def ascii_grid(grid, row, mode, top=PLAY_TOP):
    def ch(tid):
        if tid in STAIRS: return "/"
        return "#" if is_solid(tid, row, mode) else "."
    return "\n".join("".join(ch(grid[r][c]) for c in range(COLS))
                     for r in range(top, ROWS))

def stage_rows(rom):
    """World rows that have a valid (positive) room count; the last rowbase
    entry is an end sentinel, so the final row can't be sized and is skipped."""
    rows = []
    for row in range(64):
        try:
            if num_rooms(rom, row) > 0:
                rows.append(row)
            else:
                break
        except Exception:
            break
    return rows

def render_stage(rom, row, scale, mode, tag, out_dir, ascii_dump=False):
    from pngwrite import write_rgb
    images = []
    for col in range(num_rooms(rom, row)):
        grid = decode_room(rom, row, col)
        images.append(render(grid, row, scale, mode))
        if ascii_dump:
            print(f"row {row} room {col}:")
            print(ascii_grid(grid, row, mode)); print()
    if not images:
        return
    W, H, buf = contact_sheet(images, cols=4, gap=8)
    suffix = "" if tag == "perm" else f"_{tag}"
    sheet = f"{out_dir}/minimap_s{row:02d}{suffix}.png"
    write_rgb(sheet, W, H, buf)
    print(f"contact sheet -> {sheet} ({W}x{H})")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rom", default="references/VampireKiller.rom")
    ap.add_argument("--row", type=int, default=1, help="world row (stage 1 = 1)")
    ap.add_argument("--all", action="store_true",
                    help="render a sheet for every stage/world row")
    ap.add_argument("--scale", type=int, default=6)
    ap.add_argument("--out-dir", default="gfx")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--collision", action="store_true",
                   help="engine feet/head test only (01..04 surfaces; stripes)")
    g.add_argument("--visual", action="store_true",
                   help="structural family PLUS 0x2c+ decorative scenery blocks")
    ap.add_argument("--ascii", action="store_true")
    ap.add_argument("--validate", metavar="SNAPFILE",
                    help="byte-check ROM decode against RAM snapshots")
    a = ap.parse_args()
    mode = "collision" if a.collision else "visual" if a.visual else "perm"
    rom = Rom(a.rom)
    os.makedirs(a.out_dir, exist_ok=True)
    tag = {"collision": "coll", "visual": "vis", "perm": "perm"}[mode]
    rows = stage_rows(rom) if a.all else [a.row]
    for row in rows:
        render_stage(rom, row, a.scale, mode, tag, a.out_dir, a.ascii)

    if a.validate:
        import snapdiff as sd
        snaps = sd.load(a.validate)
        def V(s, addr): return s[2][addr - s[1]]
        # pick the middle of each room's longest dwell (map fully built)
        runs, prev, start = [], None, 0
        for i, s in enumerate(snaps):
            k = (V(s, 0xD000), V(s, 0xD001))
            if k != prev:
                if prev is not None: runs.append((prev, start, i - 1))
                prev, start = k, i
        runs.append((prev, start, len(snaps) - 1))
        seen = {}
        for (d0, d1), aa, bb in runs:
            if d0 != a.row: continue
            if d1 not in seen or (bb - aa) > seen[d1][1]:
                seen[d1] = ((aa + bb) // 2, bb - aa)
        seen = {k: v[0] for k, v in seen.items()}
        bad = 0
        for col, idx in sorted(seen.items()):
            g = decode_room(rom, a.row, col)
            d = sum(1 for r in range(ROWS) for c in range(COLS)
                    if g[r][c] != V(snaps[idx], 0xD100 + r * COLS + c))
            bad += d
            print(f"  validate room {col} vs snap idx{idx}: {d} mismatches")
        print(f"  total mismatches: {bad}")

if __name__ == "__main__":
    main()

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
why classifying only the surface produced horizontal stripes.  The body ids 09..0b
are therefore counted solid ONLY when 4-adjacent to a 01..08 surface (see
is_solid_ctx): real walls/floors stay solid (incl. stage 18's 06-surface/0b-body
floor), but a standalone body tile - e.g. a decorative support beside a staircase
(stage 18) - is passable, not a stray 1x1 block.
Everything else is
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

White-key doors (drawn as a red bar; --no-doors to skip): EVERY stage 0-18 has
exactly one, from seg13 door_tbl at 0xBB61 (3 bytes/stage: room|vert<<7, Y, X).
door_load_coords (0xBB37) copies Y,X into 0xC5AD,0xC5AE when 0xD001 matches the
room.  After the door opens, walking that edge uses the CONN permit: 0xF ->
advance_stage, else wrap to that room (intra-stage on 3,6,9,12,15,18).  Default
overlay is that table; door_rects() (blocked-edge heuristic) is only for
--compare-doors.  Display-type 0x1F objects are vendors, not these doors.

Output: one minimap per stage, gfx/minimap_s<NN>.png (default permeability view;
--collision/--visual add a _coll/_vis suffix), for all 19 stages 0..18.  Rooms are
placed SPATIALLY using the GAME'S OWN hand-authored F2-minimap position table
(layout(), seg2 sub_9681h) - the authoritative in-ROM geography.  (The room
connectivity graph is navigation-only: it has wrap/portal edges on both axes and is
used solely for --compare-doors edge mode, not for placement.)  Each cell is
labelled with its room number in a dark-gray band.  Stage 18 room 9 (Dracula)
uses a hand-authored PERM_OVERRIDE: floor + 2x1 jump ledges; tile IDs cannot
separate those from the decorative columns.

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

# Per-room permeability override: (stage, room) -> frozenset of solid (row, col).
# Used when tile IDs cannot tell decoration from geometry.  Stage 18 room 9
# (Dracula): side columns share 06-0b with the floor, 0c/0d pillars are decor
# not stairs, and 09-0b speckle next to those 06s is "dotted ledge" artwork.
# Ground truth: floor + 2x1 jump ledges flanking each column.  Perm mode only;
# --collision stays the engine test.
def _dracula_room9_solid():
    s = {(r, c) for r in (22, 23) for c in range(COLS)}
    for r, cols in (
        (8, (0, 1, 30, 31)),     # outer ledges, mid
        (16, (0, 1, 30, 31)),    # outer ledges, low
        (4, (4, 5, 26, 27)),     # inner ledges, high
        (12, (4, 5, 26, 27)),    # inner ledges, mid
    ):
        for c in cols:
            s.add((r, c))
    return frozenset(s)

PERM_OVERRIDE = {
    (18, 9): _dracula_room9_solid(),
}

def is_solid_ctx(grid, r, c, row, mode, room=None):
    """Per-cell solidity WITH neighbour context.  Identical to is_solid for tiles that
    are unambiguous, but the brick-BODY family 0x09-0x0b counts as solid only when it
    is 4-adjacent to a SURFACE tile 0x01-0x08 (the structural surfaces 01-04 AND the
    05-08 pair, which act as floor/wall surfaces in some stages - e.g. Dracula's stage
    18 floor is a 06 surface over a 0b body).  Walls/floors are built by pairing
    surface+body, so real ones stay solid, while a STANDALONE body tile - e.g. a
    decorative support beside a staircase (stage 18) - is passable instead of
    rendering as a stray 1x1 block."""
    ov = PERM_OVERRIDE.get((row, room)) if room is not None and mode == "perm" else None
    if ov is not None:
        return (r, c) in ov
    tid = grid[r][c]
    if mode == "collision":
        return (tid - 1) < COLL_THRESH.get(row, 4)
    if tid in STAIRS or tid in DECOR:
        return False
    if 0x09 <= tid <= 0x0b:
        for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nr, nc = r + dr, c + dc
            if 0 <= nr < ROWS and 0 <= nc < COLS and 0x01 <= grid[nr][nc] <= 0x08:
                return True
        return False
    structural = 0x01 <= tid <= 0x0d
    if mode == "visual":
        return structural or tid >= 0x2c
    return structural

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
    # seg2 (ROM bank 2) is paged into the 0x8000 window; the F2 minimap layout
    # tables live here.  Read them by CPU address (0x8000..0x9fff).
    def seg2(self, addr, n=1):
        o = 0x4000 + (addr - 0x8000)
        return self.rom[o:o + n]
    def seg2b(self, addr):
        return self.rom[0x4000 + (addr - 0x8000)]
    def seg2w(self, addr):
        b = self.seg2(addr, 2)
        return b[0] | (b[1] << 8)

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
DOOR_RGB = (220, 40, 40)        # white-key (stage-exit) door
DOOR_W = 2                      # rendered door width in tiles (edge wall thickness)

def tile_rgb(grid, r, c, row, mode, room=None):
    ov = PERM_OVERRIDE.get((row, room)) if room is not None and mode == "perm" else None
    if ov is not None:
        return SOLID_RGB if (r, c) in ov else EMPTY_RGB
    tid = grid[r][c]
    if tid in STAIRS:
        return STAIR_RGB
    return SOLID_RGB if is_solid_ctx(grid, r, c, row, mode, room) else EMPTY_RGB

def door_rects(grid, row, conn_room):
    """Blocked-edge OPENING heuristic (--compare-doors only).  This is the
    POST-OPEN walk, not door placement: a nibble 0xF edge with a passable gap.
    It matches stage-exit doors and misses intra-stage ones (permit is a real
    room).  Real placement is door_tbl; see door_table_rects()."""
    if conn_room is None:
        return []
    out = []
    # left / right: vertical opening at the edge column
    for side, ec in (("left", 0), ("right", COLS - 1)):
        if conn_room[side] != 0xf:
            continue
        sol = [is_solid_ctx(grid, r, ec, row, "perm") for r in range(ROWS)]
        r = PLAY_TOP
        while r < ROWS:
            if sol[r]:
                r += 1; continue
            s = r
            while r < ROWS and not sol[r]:
                r += 1
            e = r
            if any(sol[k] for k in range(PLAY_TOP, s)) and e < ROWS and sol[e] \
                    and 2 <= e - s <= 8:
                x0 = 0 if side == "left" else COLS - DOOR_W
                out.append((x0, s, DOOR_W, e - s))
    # up only: horizontal opening at the top edge row.  (DOWN is deliberately
    # excluded: falling off the bottom is a DEATH PIT, not a door - the engine's
    # sub_7682h has a separate bottomless-pit path.  E.g. stage 15 room 6's bottom
    # gap is death, not an exit.)
    for side, er in (("up", PLAY_TOP),):
        if conn_room[side] != 0xf:
            continue
        sol = [is_solid_ctx(grid, er, c, row, "perm") for c in range(COLS)]
        c = 0
        while c < COLS:
            if sol[c]:
                c += 1; continue
            s = c
            while c < COLS and not sol[c]:
                c += 1
            e = c
            # enclosed: solid on both horizontal sides of the gap
            if s > 0 and e < COLS and sol[s - 1] and sol[e] and 2 <= e - s <= 10:
                y0 = PLAY_TOP if side == "up" else ROWS - DOOR_W
                out.append((s, y0, e - s, DOOR_W))
    return out

def decode_objects(rom, row, col):
    """Per-room placed-object list from seg14 (--compare-doors object overlay).
    These are NOT white-key doors (display-type 0x1F is vendor/reveal).
    row->dataset/stream: ds=(row-1)//3, stream=(row-1)%3.
    Returns [(sid, scenery, x_tile, y_tile), ...]; object cell (X,Y) is *16px = *2
    tiles."""
    seg14 = rom.rom[0x1C000:0x1E000]
    if row < 1:
        return []
    ds, stream = (row - 1) // 3, (row - 1) % 3
    to = (0x8668 - 0x8000) + 2 * ds
    ptr = seg14[to] | (seg14[to + 1] << 8)
    off = ptr - 0x8000
    cells_per_stream = []
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
        cells_per_stream.append(cells)
    cells = cells_per_stream[stream]
    if col >= len(cells):
        return []
    out = []
    for oid, attr in cells[col]:
        sid = oid & 0x7F
        x = ((attr >> 4) & 0xF) * 2
        y = (attr & 0xF) * 2
        out.append((sid, bool(oid & 0x80), x, y))
    return out

OBJ_DOOR_RGB = (220, 40, 40)    # id-0x1f object = door candidate (mechanism B)
OBJ_OTHER_RGB = (70, 120, 210)  # any other placed object (dimmed context)

def render(grid, row, scale, mode, top=PLAY_TOP, doors=None, objects=None,
           room=None):
    from pngwrite import write_rgb
    rows = ROWS - top
    W, H = COLS * scale, rows * scale
    buf = bytearray(W * H * 3)
    for r in range(rows):
        for c in range(COLS):
            col = tile_rgb(grid, r + top, c, row, mode, room)
            for yy in range(scale):
                o = ((r * scale + yy) * W + c * scale) * 3
                for xx in range(scale):
                    buf[o:o + 3] = bytes(col); o += 3
    for (dx, dy, dw, dh) in doors or []:
        for ty in range(dy - top, dy - top + dh):
            if not 0 <= ty < rows:
                continue
            for yy in range(scale):
                for tx in range(dx, dx + dw):
                    o = ((ty * scale + yy) * W + tx * scale) * 3
                    for xx in range(scale):
                        buf[o:o + 3] = bytes(DOOR_RGB); o += 3
    # Mechanism-B overlay: outline each placed object at its cell; a door (0x1f)
    # is filled red, everything else is a dim blue outline for context.
    for (sid, scenery, ox, oy) in objects or []:
        is_door = (sid == 0x1f)
        col = OBJ_DOOR_RGB if is_door else OBJ_OTHER_RGB
        x0, y0 = ox * scale, (oy - top) * scale
        w, h = 2 * scale, 2 * scale        # object footprint ~16px = 2 tiles
        for yy in range(h):
            py = y0 + yy
            if not 0 <= py < H:
                continue
            for xx in range(w):
                px = x0 + xx
                if not 0 <= px < W:
                    continue
                edge = is_door or xx < 1 or xx >= w - 1 or yy < 1 or yy >= h - 1
                if edge:
                    o = (py * W + px) * 3
                    buf[o:o + 3] = bytes(col)
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

# --- Room connectivity (doors) -----------------------------------------------
# Per-stage room-transition graph (seg13): CONN_PTR is a per-stage word table of
# pointers; each room is 2 bytes = 4 nibbles (up, down, left, right) giving the
# DESTINATION room index for that exit (0xF = blocked/no exit).  This is what the
# engine writes to 0xD001 on a transition (seg13 0xB987).  Verified byte-exact
# against recorded stage-1 transitions.  It is a NAVIGATION graph (exits can WRAP or
# TELEPORT rather than step to a physical neighbour on either axis), so it is NOT
# used to place rooms.  Default door overlay uses door_tbl (below); connectivity
# is kept for --compare-doors edge mode and for classifying post-open destinations.
CONN_PTR = 0xB9D3

# --- White-key door table (seg13, bank 0x0D @ CPU 0xA000) -------------------
# door_load_coords (0xBB37): HL = 0xBB61 + stage*3; if (byte0 & 0x0F) == 0xD001,
# writes Y,X to 0xC5AD,0xC5AE (ld (0xC5AD),hl with L=Y H=X) and arms 0xC5AC
# (0xFF if byte0 bit7 / vertical, else 0x04).  One record per stage 0-18.
DOOR_TBL = 0xBB61

def door_table_entry(rom, stage):
    b0, y, x = rom.read(DOOR_TBL + 3 * stage, 3)
    return {"room": b0 & 0x0F, "vert": bool(b0 & 0x80), "y": y, "x": x}

def door_table_rects(entry, room):
    """Tile rect for the per-stage door object.  Only the matching room gets one.
    Pixel (X,Y)=(byte2,byte1)->(C5AE,C5AD).  Every record sits on a left or right
    wall (X=0x0C or 0xEC/0xE0); snap to that edge.  Height 6 = the 6-tile blit;
    Y origin is shifted up 16px so the overlay covers the visible opening
    (stage 15: Y=0x80 -> rows 14-19)."""
    if room != entry["room"]:
        return []
    y0 = max(PLAY_TOP, (entry["y"] - 0x10) // 8)
    h = 6
    if entry["x"] < 0x20:
        return [(0, y0, 4, h)]
    if entry["x"] > 0xD0:
        return [(COLS - DOOR_W, y0, DOOR_W, h)]
    return [(entry["x"] // 8, y0, DOOR_W, h)]

# --- Minimap layout table: the GAME'S OWN authored room positions -------------
# The in-game F2 minimap (seg2 sub_9681h, 0x9681) draws each room at a HAND-
# AUTHORED cell.  Per stage it looks up a pointer (MINIMAP_PTR table, indexed by
# stage 0xD000) to a per-room array of one-byte POSITION CODES, then maps each code
# -> a packed screen coord via MINIMAP_COORD: high byte = X (0x20 + 0x20*col, 6
# columns), low byte = Y (0x38 + 0x15*row, 5 rows).  MINIMAP_COUNT gives the room
# count per stage (covers all 19 stages 0..18, incl. Dracula's stage 18).
MINIMAP_PTR   = 0x969c   # seg2: word[stage] -> room position-code array
MINIMAP_COORD = 0x975e   # seg2: word[code]  -> packed coord (hi=X, lo=Y)
MINIMAP_COUNT = 0x95fd   # seg2: byte[stage] = room count

def connectivity(rom, stage, n):
    base = rom.word(CONN_PTR + 2 * stage)
    rec = []
    for r in range(n):
        b0, b1 = rom.read(base + 2 * r, 2)
        rec.append({"up": b0 >> 4, "down": b0 & 0xf,
                    "left": b1 >> 4, "right": b1 & 0xf})
    return rec

def minimap_room_count(rom, stage):
    """Room count for a stage, from the game's minimap table (MINIMAP_COUNT).
    Matches the geometry rowbase deltas for stages 0..17 but is also correct for
    stage 18 (Dracula), whose rowbase delta is a garbage sentinel (-23)."""
    return rom.seg2b(MINIMAP_COUNT + stage)

def minimap_stages(rom):
    """Stages that have an authored minimap layout (pointer in range) = 0..18."""
    out = []
    for s in range(32):
        p = rom.seg2w(MINIMAP_PTR + 2 * s)
        if 0x9600 <= p <= 0x9800:
            out.append(s)
        else:
            break
    return out

def layout(rom, stage, n):
    """Room index -> (grid_x, grid_y) from the GAME'S OWN F2-minimap position table
    (seg2 sub_9681h): each room's authored position code -> a 6x5 grid cell via
    MINIMAP_COORD (hi byte=X 0x20+0x20*col, lo byte=Y 0x38+0x15*row).  Returns
    (pos, grid_w, grid_h), normalized so the top-left occupied cell is 0,0.  This is
    the game's authoritative geography; the room-connectivity graph is navigation-only
    (wrap/portal edges) and is not used for placement."""
    ptr = rom.seg2w(MINIMAP_PTR + 2 * stage)
    pos = {}
    for r in range(n):
        code = rom.seg2b(ptr + r)
        w = rom.seg2w(MINIMAP_COORD + 2 * code)
        col = ((w >> 8) - 0x20) // 0x20
        row = ((w & 0xff) - 0x38) // 0x15
        pos[r] = (col, row)
    xs = [p[0] for p in pos.values()]
    ys = [p[1] for p in pos.values()]
    minx, miny = min(xs), min(ys)
    pos = {r: (x - minx, y - miny) for r, (x, y) in pos.items()}
    gw = max(x for x, _ in pos.values()) + 1
    gh = max(y for _, y in pos.values()) + 1
    return pos, gw, gh

def contact_sheet(images, pos, gw, gh, gap, bg=(40, 44, 56), lab_scale=2):
    cw = max(w for w, h, _ in images)
    ch = max(h for w, h, _ in images)
    lab_h = 5 * lab_scale + 4        # digit height + padding (the dark-gray band)
    cell_h = lab_h + ch
    W = gw * cw + (gw + 1) * gap
    H = gh * cell_h + (gh + 1) * gap
    buf = bytearray(bytes(bg) * (W * H))
    for i, (w, h, data) in enumerate(images):
        if i not in pos:
            continue
        gx, gy = pos[i]
        x0 = gap + gx * (cw + gap)
        y0 = gap + gy * (cell_h + gap)
        draw_text(buf, W, x0 + 2, y0 + 2, str(i), lab_scale, LABEL_RGB)
        iy = y0 + lab_h              # image sits below the label band
        for y in range(h):
            src = y * w * 3
            dst = ((iy + y) * W + x0) * 3
            buf[dst:dst + w * 3] = data[src:src + w * 3]
    return W, H, bytes(buf)

def ascii_grid(grid, row, mode, top=PLAY_TOP, room=None):
    def ch(r, c):
        ov = PERM_OVERRIDE.get((row, room)) if room is not None and mode == "perm" else None
        if ov is not None:
            return "#" if (r, c) in ov else "."
        if grid[r][c] in STAIRS: return "/"
        return "#" if is_solid_ctx(grid, r, c, row, mode, room) else "."
    return "\n".join("".join(ch(r, c) for c in range(COLS))
                     for r in range(top, ROWS))

def render_stage(rom, row, scale, mode, tag, out_dir, ascii_dump=False,
                 show_doors=True, door_model="table"):
    from pngwrite import write_rgb
    n = minimap_room_count(rom, row)
    conn = connectivity(rom, row, n)
    entry = door_table_entry(rom, row)
    images = []
    for col in range(n):
        grid = decode_room(rom, row, col)
        doors, objects = None, None
        if not show_doors:
            pass
        elif door_model == "edge":                  # blocked-edge heuristic
            doors = door_rects(grid, row, conn[col])
        elif door_model == "object":                # placed objects (not doors)
            objects = decode_objects(rom, row, col)
        else:                                       # default: ROM door_tbl
            doors = door_table_rects(entry, col)
        images.append(render(grid, row, scale, mode, doors=doors, objects=objects,
                             room=col))
        if ascii_dump:
            print(f"row {row} room {col}:")
            print(ascii_grid(grid, row, mode, room=col)); print()
    if not images:
        return
    pos, gw, gh = layout(rom, row, len(images))
    W, H, buf = contact_sheet(images, pos, gw, gh, gap=8)
    suffix = "" if tag == "perm" else f"_{tag}"
    model_suffix = {"edge": "_doorA", "object": "_doorB"}.get(door_model, "")
    sheet = f"{out_dir}/minimap_s{row:02d}{suffix}{model_suffix}.png"
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
    ap.add_argument("--no-doors", action="store_true",
                    help="skip the white-key door overlay")
    ap.add_argument("--compare-doors", action="store_true",
                    help="also emit _doorA (blocked-edge heuristic) and _doorB "
                         "(placed objects, not doors) sheets per stage")
    ap.add_argument("--validate", metavar="SNAPFILE",
                    help="byte-check ROM decode against RAM snapshots")
    a = ap.parse_args()
    mode = "collision" if a.collision else "visual" if a.visual else "perm"
    rom = Rom(a.rom)
    os.makedirs(a.out_dir, exist_ok=True)
    tag = {"collision": "coll", "visual": "vis", "perm": "perm"}[mode]
    rows = minimap_stages(rom) if a.all else [a.row]
    for row in rows:
        render_stage(rom, row, a.scale, mode, tag, a.out_dir, a.ascii,
                     not a.no_doors)
        if a.compare_doors:
            render_stage(rom, row, a.scale, mode, tag, a.out_dir, False,
                         True, door_model="edge")
            render_stage(rom, row, a.scale, mode, tag, a.out_dir, False,
                         True, door_model="object")

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

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
are therefore counted solid ONLY when 4-adjacent to a 01..04 surface (see
is_solid_ctx): real walls/floors stay solid, but a standalone body tile — or a
09 speck next to 05-08 wallpaper — is passable, not a stray 1x1 block.
Stage 18 room 9 (Dracula, event 6) uses tile_is_solid's threshold 6
(ids 1-6 solid) for both perm and --collision; there is no hand overlay.
Everything else is passable: air 0x0e..0x17; the decorative blocks 0x2c+
(background windows, columns); and the passable decoration ids 05..08
(05/08 = the inert 2-tile pair; 06/07 = stage 1's wide-stair edge /
background wallpaper elsewhere).  Stairs are the CLIMBABLE diagonal
tiles 0c (one way) and 0d (mirror) - drawn amber - which is exactly what
the engine's stair-step code tests; other stages draw 1-tile-wide stairs
(0c/0d only), while stage 1 pairs each step with a decorative 06/07 half
(hence its "fat" 2-wide stairs).
Colours: walls/floors white, empty black, climbable stairs amber.

Three other views:
  --collision : the engine's OWN feet/head test (seg1 tile_is_solid): solid iff
                (id-1) < row_solid_thresh[0xD000] (stage 1 -> 4).  Event 6
                (stage 18 room 9) forces threshold 6.  This is exactly
                what blocks Simon, but only marks the 01..04 SURFACES (stripes)
                on other stages.
  --visual    : structural family PLUS the 0x2c+ decorative blocks (shows the
                drawn artwork, but paints background scenery as if solid).
  --pixels    : paint each 8x8 from the stage tileset (load_stage_tileset /
                tileset_ptr) in the per-room playfield palette. Nametable id 0
                is blank (blit starts at VRAM 0x8004; id N = ROM tile N-1).
                HUD rows 0-1 cropped like the other views. Stage 18 room 9
                overlays dracula_portrait_load (seg15 face + mirrors). No
                door/spot/object overlay. Default --scale is 2.

White-key doors (drawn as a red bar; --no-doors to skip): EVERY stage 0-18 has
exactly one, from seg13 door_tbl at 0xBB61 (3 bytes/stage: room|vert<<7, Y, X).
door_load_coords (0xBB37) copies Y,X into 0xC5AD,0xC5AE when 0xD001 matches the
room.  After the door opens, walking that edge uses the CONN permit: 0xF ->
advance_stage, else wrap to that room (intra-stage on 3,6,9,12,15,18).  Default
overlay is that table; door_rects() (blocked-edge heuristic) is only for
--compare-doors.  Display-type 0x1F objects are vendors, not these doors.

Stage-12 spots (teal 2x2 pad on the floor + dest digit beside it; --no-spots
to skip): seg13 spot_tbl at 0xBBCD, records (stage, dest<<4|room, Y, X) until
0xFF.  Current ROM has 10 records, all stage 12, in two-way pairs (0↔3, 1↔4,
2↔11, 5↔8, 7↔10).  CONN has no up/down on this stage; crouch-on-pad then UP
warps via C41B=0xFF.  Stored Y is the floor BODY; the overlay snaps up to sit
on the walkable surface (empty tiles immediately above).  Decoder is generic.

Output: one sheet per stage. Permeability (default) and --collision/--visual
are schematic maps at gfx/minimap_s<NN>.png (optional _coll/_vis suffix).
--pixels is the assembled playfield (not a minimap) at gfx/stage_s<NN>.png.
For all 19 stages 0..18.  Rooms are
placed SPATIALLY using the GAME'S OWN hand-authored F2-minimap position table
(layout(), seg2 minimap_room_pos) - the authoritative in-ROM geography.  (The room
connectivity graph is navigation-only: it has wrap/portal edges on both axes and is
used solely for --compare-doors edge mode, not for placement.)  Each cell is
labelled with its room number in a dark-gray band.  Stage 18 room 9 (Dracula)
uses the event-6 solidity test (ids 1-6), same as tile_is_solid.

Usage:
  tools/roomperm.py [--rom references/VampireKiller.rom] [--row 1 | --all]
                    [--scale 6] [--out-dir gfx]
                    [--collision | --visual | --pixels]
                    [--validate generated/disasmsnap.bin] [--ascii]
                    [--no-doors] [--no-spots] [--compare-doors]
"""
import argparse, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

COLS, ROWS = 32, 24
PLAY_TOP = 2                    # rows 0-1 = HUD
STAIRS = {0x0c, 0x0d}   # the CLIMBABLE diagonal tiles (0c one way, 0d the mirror);
                        # this is what the engine's stair-step routines actually
                        # test (seg1 stair_probe_up_right checks 0x0d,
                        # stair_probe_up_left checks 0x0c).
DECOR = {0x05, 0x06, 0x07, 0x08}     # passable decoration, never solid or climbable:
                                     # 05/08 = the inert 2-tile pair; 06/07 = the
                                     # decorative half of stage 1's 2-wide stairs
                                     # (0c06/070d) and elsewhere just background
                                     # wallpaper (e.g. stage 10) - NOT stairs.
AIR = set(range(0x0e, 0x18)) | {0x00} | STAIRS | DECOR
COLL_THRESH = {0: 2, 1: 4, 2: 4, 3: 4, 4: 4, 5: 4, 6: 4, 7: 4, 8: 4, 9: 4,
               10: 9, 11: 9, 12: 9, 13: 4, 14: 4, 15: 4, 16: 9, 17: 9, 18: 8}

def is_solid(tid, row, mode, room=None):
    if mode == "collision":
        thresh = 6 if (row, room) == (18, 9) else COLL_THRESH.get(row, 4)
        return (tid - 1) < thresh   # matches seg1 tile_is_solid
    if tid in STAIRS or tid in DECOR:
        return False
    structural = 0x01 <= tid <= 0x0d                  # floor/wall brick family
    if mode == "visual":
        return structural or tid >= 0x2c              # + decorative scenery blocks
    return structural                                 # default: walls & floors only

def is_solid_ctx(grid, r, c, row, mode, room=None):
    """Per-cell solidity WITH neighbour context.  Identical to is_solid for tiles that
    are unambiguous, but the brick-BODY family 0x09-0x0b counts as solid only when it
    is 4-adjacent to a structural SURFACE 0x01-0x04.  05-08 are passable
    decoration (and stage-1 stair trim); treating them as surfaces made 09
    specks next to wallpaper render as solid noise (stages 6, 10, 15, 17).
    Event 6 (s18r9) uses threshold 6 for perm and collision (tile_is_solid
    l7c7ah).  Walls/floors are built by pairing 01-04 with 09-0b, so real
    ones stay solid, while a standalone body tile is passable instead of a
    stray 1x1 block."""
    tid = grid[r][c]
    if (row, room) == (18, 9) and mode in ("perm", "collision"):
        return bool(tid) and (tid - 1) < 6
    if mode == "collision":
        return (tid - 1) < COLL_THRESH.get(row, 4)
    if tid in STAIRS or tid in DECOR:
        return False
    if 0x09 <= tid <= 0x0b:
        for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nr, nc = r + dr, c + dc
            if 0 <= nr < ROWS and 0 <= nc < COLS and 0x01 <= grid[nr][nc] <= 0x04:
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
STAIR_RGB = (240, 170, 40)      # climbable stairs (0c/0d)
DOOR_RGB = (220, 40, 40)        # white-key (stage-exit) door
DOOR_W = 2                      # rendered door width in tiles (edge wall thickness)
SPOT_RGB = (64, 186, 176)       # teal pad + dest digit (not door red, not stair amber)

def tile_rgb(grid, r, c, row, mode, room=None):
    tid = grid[r][c]
    if tid in STAIRS and not ((row, room) == (18, 9) and mode in ("perm", "collision")):
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
    # room_edge_detect has a separate bottomless-pit path.  E.g. stage 15 room 6's bottom
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
    List-id = actor type (l61c2h -> spawn_actor). NOT white-key doors (those
    are door_tbl). List-id 0x1F is a placed hanging bat, not vendor/reveal
    (display-type 0x1F on a brazier is that path).
    row->dataset/stream: ds=(row-1)//3, stream=(row-1)%3.
    Returns [(sid, bit7, x_tile, y_tile), ...]; object cell (X,Y) is *16px = *2
    tiles. bit7 is stored then stripped at spawn (dogs only; role unknown)."""
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

OBJ_BAT_RGB = (220, 40, 40)     # id-0x1f = placed hanging bat (was door-candidate overlay)
OBJ_OTHER_RGB = (70, 120, 210)  # any other placed object (dimmed context)

def blit_rects(buf, W, rows, scale, top, rects, rgb):
    """Paint axis-aligned tile rects (dx, dy, dw, dh, ...) in the cropped room."""
    for item in rects or []:
        dx, dy, dw, dh = item[:4]
        for ty in range(dy - top, dy - top + dh):
            if not 0 <= ty < rows:
                continue
            for yy in range(scale):
                for tx in range(dx, dx + dw):
                    if not 0 <= tx < COLS:
                        continue
                    o = ((ty * scale + yy) * W + tx * scale) * 3
                    for xx in range(scale):
                        buf[o:o + 3] = bytes(rgb); o += 3

def render(grid, row, scale, mode, top=PLAY_TOP, doors=None, objects=None,
           room=None, spots=None):
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
    blit_rects(buf, W, rows, scale, top, doors, DOOR_RGB)
    blit_rects(buf, W, rows, scale, top, spots, SPOT_RGB)
    dscale = max(1, scale // 3)
    for item in spots or []:
        dx, dy, dw, dh, dest = item
        text = str(dest)
        th = 5 * dscale
        tw = len(text) * 4 * dscale - dscale
        pad_y = (dy - top) * scale
        y0 = pad_y + max(0, (dh * scale - th) // 2)
        x0 = (dx + dw) * scale + dscale
        if x0 + tw > W:
            x0 = dx * scale - tw - dscale
        if 0 <= y0 < H and x0 + tw > 0:
            draw_text(buf, W, max(0, x0), y0, text, dscale, SPOT_RGB)
    # Object overlay: outline each placed actor at its cell. 0x1F (placed
    # hanging bat) is filled red so the old --compare-doors sheets stay readable.
    for (sid, bit7, ox, oy) in objects or []:
        is_bat = (sid == 0x1f)
        col = OBJ_BAT_RGB if is_bat else OBJ_OTHER_RGB
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
                edge = is_bat or xx < 1 or xx >= w - 1 or yy < 1 or yy >= h - 1
                if edge:
                    o = (py * W + px) * 3
                    buf[o:o + 3] = bytes(col)
    return W, H, bytes(buf)

# --- Pixel rooms (stage tileset + playfield palette) -------------------------
# load_stage_tileset (seg0 0x5653) blits tileset_ptr[D000] — 0xBF uncompressed
# 8x8 4bpp tiles — into SCREEN 5 page 1 via l4a6dh starting at VRAM 0x8004
# (X=8,Y=0). sub_4b48h looks up nametable id A as SX=(A&0x1F)*8, SY=(A&0xE0)>>2,
# so id 0 samples the unloaded column at (0,0) = blank, and id N is ROM tile
# N-1. Playfield drawer (0x4F98) paints 22 rows from 0xD140 (map rows 2-23).
# Palette is vk_playfield_palette.
TILESET_PTR = 0x5749            # seg0 word[stage]; file off = CPU - 0x4000
_EMPTY_TILE = [[0] * 8 for _ in range(8)]

def tileset_cells(rom, stage):
    """0xBF uncompressed 8x8 4bpp tiles for this stage (ROM order, id 0 = first)."""
    cache = getattr(rom, "_tileset_cache", None)
    if cache is None:
        rom._tileset_cache = cache = {}
    if stage in cache:
        return cache[stage]
    import gfxdump
    off = TILESET_PTR - 0x4000
    cpu = rom.rom[off + stage * 2] | (rom.rom[off + stage * 2 + 1] << 8)
    fo = gfxdump._tileset_file(stage, cpu)
    n = min(gfxdump.NTILES, max(0, (len(rom.rom) - fo) // 32))
    cells = gfxdump.tile_grids(rom.rom[fo:fo + n * 32], "tile8")
    cache[stage] = cells
    return cells

def nametable_cell(tiles, tid):
    """Nametable byte -> 8x8. Id 0 is blank (never loaded at 0x8004)."""
    if 0 <= tid < len(tiles):
        return tiles[tid]
    return _EMPTY_TILE

def _tile8_grid(raw):
    import gfxdump
    cells = gfxdump.tile_grids(bytes(raw), "tile8")
    return cells[0] if cells else _EMPTY_TILE

def _flip_h8(raw):
    """Horizontal flip of one 8x8 4bpp tile (sub_5919h / sub_5873h)."""
    out = bytearray(32)
    for r in range(8):
        row = raw[r * 4:(r + 1) * 4]
        out[r * 4:(r + 1) * 4] = bytes(
            ((b & 0x0F) << 4) | (b >> 4) for b in reversed(row))
    return bytes(out)

def _vram_tile_id(de):
    """Page-1 VRAM address -> nametable id (sub_4b48h inverse)."""
    off = de - 0x8000
    y, xb = divmod(off, 128)
    return (y // 8) * 32 + (xb // 4)

def _l4a6d_advance(de):
    e = (de + 4) & 0xFF
    d = de >> 8
    if e == 0x80:
        return ((d + 4) << 8) & 0xFF00
    return (d << 8) | e

def _place_rom_tiles(atlas, data, file_off, dest, n, flip_h=False):
    de = dest
    for i in range(n):
        raw = data[file_off + i * 32:file_off + i * 32 + 32]
        if len(raw) < 32:
            break
        if flip_h:
            raw = _flip_h8(raw)
        tid = _vram_tile_id(de)
        if 0 <= tid < len(atlas):
            atlas[tid] = _tile8_grid(raw)
        de = _l4a6d_advance(de)

def _place_vflip(atlas, src_de, dest_de, n):
    s, d = src_de, dest_de
    for _ in range(n):
        sid, did = _vram_tile_id(s), _vram_tile_id(d)
        if 0 <= sid < len(atlas) and 0 <= did < len(atlas):
            atlas[did] = list(reversed(atlas[sid]))
        s, d = _l4a6d_advance(s), _l4a6d_advance(d)

def _overlay_dracula_portrait(atlas, data):
    """dracula_portrait_load (seg0 0x5887): seg15 frame + 108-tile face, then
    H-mirror (0x1E-0x89 -> 0x8A-0xF5) and V-mirror the frame."""
    s15 = lambda cpu: 15 * 0x2000 + (cpu - 0xA000)
    _place_rom_tiles(atlas, data, s15(0xABF8), 0x8018, 8)
    _place_rom_tiles(atlas, data, s15(0xACF8), 0x8040, 2)
    _place_rom_tiles(atlas, data, s15(0xAD38), 0x8060, 2)
    _place_rom_tiles(atlas, data, s15(0xAD78), 0x8070, 1)
    _place_rom_tiles(atlas, data, s15(0xAD98), 0x8078, 0x6C)
    _place_rom_tiles(atlas, data, s15(0xAD78), 0x8074, 1, flip_h=True)
    _place_rom_tiles(atlas, data, s15(0xAD98), 0x9028, 0x6C, flip_h=True)
    _place_rom_tiles(atlas, data, s15(0xACF8), 0x8048, 2, flip_h=True)
    _place_vflip(atlas, 0x8048, 0x8058, 2)
    _place_vflip(atlas, 0x8040, 0x8050, 2)
    _place_vflip(atlas, 0x8060, 0x8068, 2)

def playfield_atlas(rom, stage, room):
    """256-slot page-1 tile atlas after load_stage_tileset (+ event-6 overlay)."""
    cache = getattr(rom, "_atlas_cache", None)
    if cache is None:
        rom._atlas_cache = cache = {}
    key = (stage, room)
    if key in cache:
        return cache[key]
    import gfxdump
    atlas = [_EMPTY_TILE] * 256
    de = 0x8004
    for cell in tileset_cells(rom, stage)[:gfxdump.NTILES]:
        tid = _vram_tile_id(de)
        if 0 <= tid < len(atlas):
            atlas[tid] = cell
        de = _l4a6d_advance(de)
    if stage == 18 and room == 9:
        _overlay_dracula_portrait(atlas, rom.rom)
    cache[key] = atlas
    return atlas

def render_pixels(rom, grid, stage, room, scale, top=PLAY_TOP):
    """Paint the room from 8x8 tileset cells in the per-room playfield palette.
    Crops HUD rows 0-1 like the other views. No door/spot/object overlay."""
    import gfxdump
    pal = gfxdump.vk_playfield_palette(rom.rom, stage, room)
    if stage == 18 and room == 9:
        # dracula_portrait_palette (0x59F3): 0xBF88 then 0xBF6F (pink/flesh)
        gfxdump._apply_palette_overlay(
            pal, gfxdump.load_palette_table(rom.rom, 0x15F88))
        gfxdump._apply_palette_overlay(
            pal, gfxdump.load_palette_table(rom.rom, 0x15F6F))
    pal_b = [bytes(pal[i]) for i in range(16)]
    tiles = playfield_atlas(rom, stage, room)
    rows = ROWS - top
    tw = 8 * scale
    W, H = COLS * tw, rows * tw
    buf = bytearray(W * H * 3)
    for r in range(rows):
        for c in range(COLS):
            cell = nametable_cell(tiles, grid[r + top][c])
            x0 = c * tw
            y0 = r * tw
            for y in range(8):
                prow = cell[y]
                for x in range(8):
                    rgb = pal_b[prow[x] & 15]
                    for yy in range(scale):
                        o = ((y0 + y * scale + yy) * W + x0 + x * scale) * 3
                        for xx in range(scale):
                            buf[o:o + 3] = rgb
                            o += 3
    return W, H, bytes(buf)

# 3x5 bitmap for sheet labels (room numbers, credits-font chars)
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
    ".": ("000", "000", "000", "000", "010"),
    "'": ("010", "010", "000", "000", "000"),
    ":": ("000", "010", "000", "010", "000"),
    ",": ("000", "000", "000", "010", "100"),
    "A": ("010", "101", "111", "101", "101"),
    "B": ("110", "101", "110", "101", "110"),
    "C": ("011", "100", "100", "100", "011"),
    "D": ("110", "101", "101", "101", "110"),
    "E": ("111", "100", "110", "100", "111"),
    "F": ("111", "100", "110", "100", "100"),
    "G": ("011", "100", "101", "101", "011"),
    "H": ("101", "101", "111", "101", "101"),
    "I": ("111", "010", "010", "010", "111"),
    "J": ("001", "001", "001", "101", "010"),
    "K": ("101", "101", "110", "101", "101"),
    "L": ("100", "100", "100", "100", "111"),
    "M": ("101", "111", "101", "101", "101"),
    "N": ("101", "111", "111", "101", "101"),
    "O": ("010", "101", "101", "101", "010"),
    "P": ("110", "101", "110", "100", "100"),
    "Q": ("010", "101", "101", "111", "001"),
    "R": ("110", "101", "110", "101", "101"),
    "S": ("011", "100", "010", "001", "110"),
    "T": ("111", "010", "010", "010", "010"),
    "U": ("101", "101", "101", "101", "111"),
    "V": ("101", "101", "101", "101", "010"),
    "W": ("101", "101", "101", "111", "101"),
    "X": ("101", "101", "010", "101", "101"),
    "Y": ("101", "101", "010", "010", "010"),
    "Z": ("111", "001", "010", "100", "111"),
}
LABEL_RGB = (200, 200, 205)
# 3x3 multiply, drawn at half scale and vertically centered in the 5-row
# cap-height so "16x16" does not read as a capital X.
TIMES = ("101", "010", "101")

def draw_text(buf, W, x, y, text, scale, color):
    def blit(glyph, px, py, gs):
        for gy, row in enumerate(glyph):
            for gx, bit in enumerate(row):
                if bit != "1":
                    continue
                for yy in range(gs):
                    base = ((py + gy * gs + yy) * W + px + gx * gs) * 3
                    for xx in range(gs):
                        o = base + xx * 3
                        buf[o:o + 3] = bytes(color)

    for chr_ in text:
        if chr_ == "x":
            gs = max(1, scale // 2)
            gh = 3 * gs
            blit(TIMES, x, y + (5 * scale - gh) // 2, gs)
            x += 3 * gs + gs          # 3px glyph + 1px gap, at half scale
            continue
        glyph = FONT3x5.get(chr_)
        if glyph:
            blit(glyph, x, y, scale)
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

# --- Spot / portal pads (seg13, bank 0x0D @ CPU 0xA000) ----------------------
# spot_load_coords (0xBB9A): scan until 0xFF for (D000, D001).  On match arms
# C5B1=1, stores Y,X at C5B2/C5B3, dest nibble at C5B4.  Play-verified: crouch
# on the pad then UP -> simon_portal_wait -> C41B=0xFF -> conn_from_spot.
SPOT_TBL = 0xBBCD

def parse_spots(rom):
    """spot_tbl: (stage, dest<<4|room, Y, X) records until 0xFF."""
    out = []
    addr = SPOT_TBL
    for _ in range(64):
        stage = rom.read(addr)[0]
        if stage == 0xFF:
            break
        packed, y, x = rom.read(addr + 1, 3)
        out.append({
            "stage": stage,
            "room": packed & 0x0F,
            "dest": packed >> 4,
            "y": y,
            "x": x,
        })
        addr += 4
    return out

def spot_floor_row(grid, stage, room, tx, ty, mode="perm"):
    """Topmost solid tile at/below the stored pad Y.  spot_tbl Y is the floor
    BODY; the walkable surface is the 01/02 row immediately above it."""
    for r in range(max(PLAY_TOP, ty - 4), ROWS):
        if 0 <= tx < COLS and is_solid_ctx(grid, r, tx, stage, mode, room):
            return r
    return ty

def spot_table_rects(spots, stage, room, grid, mode="perm"):
    """2x2 pad sitting on the floor (empty tiles immediately above the surface)
    plus dest room.  Snaps up from the stored body Y so the marker is not in
    the void under the platform."""
    out = []
    for s in spots:
        if s["stage"] != stage or s["room"] != room:
            continue
        tx = s["x"] // 8
        surf = spot_floor_row(grid, stage, room, tx, s["y"] // 8, mode)
        dy = max(PLAY_TOP, surf - 2)
        out.append((tx, dy, 2, 2, s["dest"]))
    return out

# --- Minimap layout table: the GAME'S OWN authored room positions -------------
# The in-game F2 minimap (seg2 minimap_room_pos, 0x9681) draws each room at a HAND-
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
    (seg2 minimap_room_pos): each room's authored position code -> a 6x5 grid cell via
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
        if grid[r][c] in STAIRS and not ((row, room) == (18, 9) and mode in ("perm", "collision")):
            return "/"
        return "#" if is_solid_ctx(grid, r, c, row, mode, room) else "."
    return "\n".join("".join(ch(r, c) for c in range(COLS))
                     for r in range(top, ROWS))

def render_stage(rom, row, scale, mode, tag, out_dir, ascii_dump=False,
                 show_doors=True, door_model="table", show_spots=True):
    from pngwrite import write_rgb
    n = minimap_room_count(rom, row)
    conn = connectivity(rom, row, n)
    entry = door_table_entry(rom, row)
    spots = parse_spots(rom) if show_spots else []
    images = []
    pixels = mode == "pixels"
    for col in range(n):
        grid = decode_room(rom, row, col)
        if pixels:
            images.append(render_pixels(rom, grid, row, col, scale))
        else:
            doors, objects = None, None
            if not show_doors:
                pass
            elif door_model == "edge":              # blocked-edge heuristic
                doors = door_rects(grid, row, conn[col])
            elif door_model == "object":            # placed objects (not doors)
                objects = decode_objects(rom, row, col)
            else:                                   # default: ROM door_tbl
                doors = door_table_rects(entry, col)
            pad = spot_table_rects(spots, row, col, grid, mode) if show_spots else None
            images.append(render(grid, row, scale, mode, doors=doors, objects=objects,
                                 room=col, spots=pad))
        if ascii_dump:
            ascii_mode = "perm" if pixels else mode
            print(f"row {row} room {col}:")
            print(ascii_grid(grid, row, ascii_mode, room=col)); print()
    if not images:
        return
    pos, gw, gh = layout(rom, row, len(images))
    W, H, buf = contact_sheet(images, pos, gw, gh, gap=8)
    if pixels:
        sheet = f"{out_dir}/stage_s{row:02d}.png"
    else:
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
    ap.add_argument("--scale", type=int, default=None,
                    help="pixels per source pixel (perm/coll/vis default 6; "
                         "--pixels default 2)")
    ap.add_argument("--out-dir", default="gfx")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--collision", action="store_true",
                   help="engine feet/head test only (01..04 surfaces; stripes)")
    g.add_argument("--visual", action="store_true",
                   help="structural family PLUS 0x2c+ decorative scenery blocks")
    g.add_argument("--pixels", action="store_true",
                   help="paint rooms from the stage tileset (8x8 4bpp, "
                        "playfield palette)")
    ap.add_argument("--ascii", action="store_true")
    ap.add_argument("--no-doors", action="store_true",
                    help="skip the white-key door overlay")
    ap.add_argument("--no-spots", action="store_true",
                    help="skip the stage-12 spot/portal pad overlay")
    ap.add_argument("--compare-doors", action="store_true",
                    help="also emit _doorA (blocked-edge heuristic) and _doorB "
                         "(placed objects, not doors) sheets per stage")
    ap.add_argument("--validate", metavar="SNAPFILE",
                    help="byte-check ROM decode against RAM snapshots")
    a = ap.parse_args()
    mode = ("pixels" if a.pixels else
            "collision" if a.collision else
            "visual" if a.visual else "perm")
    scale = a.scale if a.scale is not None else (2 if mode == "pixels" else 6)
    rom = Rom(a.rom)
    os.makedirs(a.out_dir, exist_ok=True)
    tag = {"collision": "coll", "visual": "vis", "perm": "perm",
           "pixels": "pix"}[mode]
    rows = minimap_stages(rom) if a.all else [a.row]
    for row in rows:
        render_stage(rom, row, scale, mode, tag, a.out_dir, a.ascii,
                     not a.no_doors, show_spots=not a.no_spots)
        if a.compare_doors and mode != "pixels":
            render_stage(rom, row, scale, mode, tag, a.out_dir, False,
                         True, door_model="edge", show_spots=False)
            render_stage(rom, row, scale, mode, tag, a.out_dir, False,
                         True, door_model="object", show_spots=False)

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

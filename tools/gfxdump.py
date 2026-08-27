#!/usr/bin/env python3
"""Build PNG graphics sheets in gfx/ from identified asm / ROM tables.

  gfx/sprites/<stem>.png  - packed 1bpp sprite asms (ASM_SPRITE_STEMS)
  gfx/tilesets/<stem>.png - 4bpp tileset asms
  gfx/fonts/<stem>.png    - 1bpp font asms (ASM_FONT_STEMS)
  gfx/<name>.png          - derived sheets (composites, hazards, vendor)

Tileset cell header is the CPU address. Sprite-asm cell header is the VRAM
dest. Font cell header is the hex glyph id. One 16x16 plane per sprite
cell (no CC overlay). Composited SAT poses (enemy_sheet, sheet_enemy_*)
live in gfx/.

Usage:  tools/gfxdump.py            (run from the repo root)
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
import rledec, gfxview, pngwrite

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROM = os.path.join(ROOT, "VampireKiller.rom")
GFX = os.path.join(ROOT, "gfx")
SPRITE_DIR = os.path.join(GFX, "sprites")
TILESET_DIR = os.path.join(GFX, "tilesets")
FONT_DIR = os.path.join(GFX, "fonts")
# Asm sheets only. Composites / hazards go in GFX.
ASM_SPRITE_STEMS = frozenset(
    ("enemy_sprite_rle", "simon_rle", "intro_sky", "title_jp_sprites"))
ASM_FONT_STEMS = frozenset(("font_credits", "font_hud", "font_logo"))

# Sheet PNG appearance.
SCALE = 6                       # pixels per source pixel
GAP = 2                         # gap (in scaled px) between tiles
BG = (0x20, 0x28, 0x30)         # canvas / gap colour
OFF = (0x30, 0x3a, 0x44)        # sprite "off" pixel (shows tile bounds)

# MSX2 palette encoding: port 9A gets (0rrr0bbb, 00000ggg), 3-bit channels.
# Expand 0-7 -> 0-255 the same way openMSX does.
def msx2_channel(n):
    n &= 7
    return (n << 5) | (n << 2) | (n >> 1)

def load_palette_table(data, file_off):
    """Parse an palette_apply table: (index, rb, g)+ terminated by 0xFF. Missing
    indices stay (0,0,0)."""
    pal = [(0, 0, 0)] * 16
    i = file_off
    while i + 2 < len(data) and data[i] != 0xFF:
        idx = data[i]
        if idx > 15:
            break
        rb, g = data[i + 1], data[i + 2]
        pal[idx] = (msx2_channel(rb >> 4), msx2_channel(g), msx2_channel(rb))
        i += 3
    return pal

def vk_play_palette(data):
    """In-game 16-colour VDP palette: title extras at seg10 0xBF6F, then the
    8 fixed HUD/sprite colours at 0xBF88 (`palette_hud_load`). Stage palettes overlay
    indices 4,5,6,7,9,10,11,13 only; HUD bonus tiles never use those."""
    pal = load_palette_table(data, 0x15F6F)   # CPU 0xBF6F
    fixed = load_palette_table(data, 0x15F88)  # CPU 0xBF88
    for i, rgb in enumerate(fixed):
        # 0xBF88 writes 0,1,2,3,8,12,14,15 — all non-black except index 0.
        if i == 0 or rgb != (0, 0, 0):
            pal[i] = rgb
    return pal

# MSX2 BIOS SCREEN 5 default (3-bit RGB). Stage palettes and the HUD table
# overlay this; leftover indices (often 4 and 6) stay on these values.
MSX2_DEFAULT_RGB = [
    (0, 0, 0), (0, 0, 0), (6, 1, 1), (7, 3, 3),
    (1, 1, 7), (3, 2, 7), (1, 1, 1), (6, 3, 7),
    (1, 1, 1), (3, 3, 3), (6, 6, 1), (6, 6, 4),
    (1, 4, 1), (2, 6, 7), (5, 5, 5), (7, 7, 7),
]

def _apply_palette_overlay(pal, overlay):
    """palette_apply only writes listed indices; omitted slots keep the previous RGB."""
    for i, rgb in enumerate(overlay):
        if rgb != (0, 0, 0):
            pal[i] = rgb

def _palette_file_off(cpu):
    if 0xA000 <= cpu < 0xC000:
        return 0x14000 + (cpu - 0xA000)
    if 0x8000 <= cpu < 0xA000:
        return 0x12000 + (cpu - 0x8000)
    return None

def vk_stage_palette(data, stage):
    """Play-mode palette after `0x5714`: BIOS default, then the 8 HUD-fixed
    colours (`palette_hud_load`), then that row of the 0xBEA7 table. Room entry then
    overlays 9AB0[stage][room].palette via `0x5787` (see vk_playfield_palette)."""
    pal = [(msx2_channel(r), msx2_channel(g), msx2_channel(b))
           for r, g, b in MSX2_DEFAULT_RGB]
    fixed = load_palette_table(data, 0x15F88)
    for i, rgb in enumerate(fixed):
        if i == 0 or rgb != (0, 0, 0):
            pal[i] = rgb
    if 0 <= stage <= 18:
        ptrs = 0x15EA7                  # CPU 0xBEA7 in seg10
        cpu = data[ptrs + stage * 2] | (data[ptrs + stage * 2 + 1] << 8)
        fo = _palette_file_off(cpu)
        if fo is not None:
            _apply_palette_overlay(pal, load_palette_table(data, fo))
    return pal

def vk_playfield_palette(data, stage, room):
    """In-game sprite/BG palette for one room: 0x5714 (HUD + BEA7[stage]) then
    the per-room table at 9AB0[stage-1][room].palette. Enemy SAT colours 4/5/6/7
    are these overlay slots; 2/12/14 (ghost, bone pillar) are HUD-fixed."""
    pal = vk_stage_palette(data, stage)
    _, palcpu = _room_record(data, stage, room)
    fo = _palette_file_off(palcpu) if palcpu else None
    if fo is not None:
        _apply_palette_overlay(pal, load_palette_table(data, fo))
    return pal

def tile_grids(buf, kind):
    """Return a list of 8x8 or 16x16 grids of 4bpp colour indices."""
    grids = []
    if kind == "tile8":
        step = 32
        for i in range(0, len(buf) - step + 1, step):
            chunk = buf[i:i + step]
            grid = []
            for r in range(8):
                row = chunk[r * 4:(r + 1) * 4]
                px = []
                for b in row:
                    px += [b >> 4, b & 0xF]
                grid.append(px)
            grids.append(grid)
    elif kind == "tile4":
        step = 128
        for i in range(0, len(buf) - step + 1, step):
            chunk = buf[i:i + step]
            grid = []
            for r in range(16):
                row = chunk[r * 8:(r + 1) * 8]
                px = []
                for b in row:
                    px += [b >> 4, b & 0xF]
                grid.append(px)
            grids.append(grid)
    else:
        raise SystemExit("unknown kind %r" % kind)
    return grids


def _hex_id(n):
    """Two-digit hex as drawn on sheets (matches defb / equ values)."""
    return "%02X" % n


def _label_band(labels, lab_scale):
    if not labels:
        return 0
    return 5 * lab_scale + 4          # digit height + padding


def render_png(path, cells, palette, cols=8, labels=None, lab_scale=2, size=16,
               scale=None):
    """Write a scaled contact sheet.  `labels` (optional) adds a dark band
    above each tile with a 3x5 bitmap id, same treatment as the minimap
    renderer in roomperm.py (`contact_sheet`).  `size` is the tile edge in
    source pixels (8 for glyphs/tilesets, 16 for HUD/Simon sprites).  `scale`
    defaults to SCALE (6); 8x8 glyphs use 12 so cells match 16x16 HUD tiles.
    Returns (W, H, rgb) or None.  `path` None skips the write."""
    if not cells:
        return None
    scale = SCALE if scale is None else scale
    lab_h = _label_band(labels, lab_scale)
    rows_of = (len(cells) + cols - 1) // cols
    tile_s = size * scale
    cell_w = tile_s
    cell_h = lab_h + tile_s
    W = cols * cell_w + (cols + 1) * GAP
    H = rows_of * cell_h + (rows_of + 1) * GAP
    buf = bytearray(W * H * 3)
    for i in range(0, W * H):
        buf[i * 3], buf[i * 3 + 1], buf[i * 3 + 2] = BG
    for idx, grid in enumerate(cells):
        x0 = GAP + (idx % cols) * (cell_w + GAP)
        y0 = GAP + (idx // cols) * (cell_h + GAP)
        _blit_cell(buf, W, grid, palette, x0, y0, scale, lab_h,
                   None if not labels or idx >= len(labels) else labels[idx],
                   lab_scale, size, size)
    rgb = bytes(buf)
    if path:
        pngwrite.write_rgb(path, W, H, rgb)
    return W, H, rgb


def _stack_rgb(path, parts):
    """Stack (W, H, rgb) buffers vertically, padding to the widest."""
    parts = [p for p in parts if p]
    if not parts:
        return
    W = max(p[0] for p in parts)
    H = sum(p[1] for p in parts)
    out = bytearray(W * H * 3)
    for i in range(W * H):
        out[i * 3], out[i * 3 + 1], out[i * 3 + 2] = BG
    y = 0
    for w, h, rgb in parts:
        for row in range(h):
            dst = ((y + row) * W) * 3
            src = row * w * 3
            out[dst:dst + w * 3] = rgb[src:src + w * 3]
        y += h
    pngwrite.write_rgb(path, W, H, bytes(out))


def _blit_cell(buf, W, grid, palette, x0, y0, scale, lab_h, label, lab_scale,
               max_w=None, max_h=None):
    def put(px, py, rgb):
        o = (py * W + px) * 3
        buf[o], buf[o + 1], buf[o + 2] = rgb

    if label is not None:
        from roomperm import draw_text, LABEL_RGB
        draw_text(buf, W, x0 + 2, y0 + 2, str(label), lab_scale, LABEL_RGB)
    ty = y0 + lab_h
    h = len(grid) if max_h is None else min(max_h, len(grid))
    w = (len(grid[0]) if grid else 0) if max_w is None else min(
        max_w, len(grid[0]) if grid else 0)
    for y in range(h):
        for x in range(w):
            pix = grid[y][x]
            rgb = pix if isinstance(pix, tuple) else palette[pix]
            for dy in range(scale):
                for dx in range(scale):
                    put(x0 + x * scale + dx, ty + y * scale + dy, rgb)


def _pack_slot(w, h, scale, lab_h):
    """Output size of one labelled cell. Width is quantized to 16-pixel columns
    so a 32-wide sprite is exactly two 16-wide slots (GAP is per column, not
    per sprite — otherwise two 16s are 2px wider than one 32 and cannot sit
    under the dog)."""
    cols = max(1, (w + 15) // 16)
    return cols * (16 * scale + GAP), lab_h + h * scale + GAP


def _rects_overlap(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return not (ax + aw <= bx or bx + bw <= ax or ay + ah <= by or by + bh <= ay)


def _gravity(pos, sizes, bin_w):
    """Slide each item up, then left, into any hole that fits."""
    n = len(pos)
    moved = True
    while moved:
        moved = False
        for i in sorted(range(n), key=lambda k: (pos[k][1], pos[k][0])):
            x, y = pos[i]
            w, h = sizes[i]
            others = [(pos[j][0], pos[j][1], sizes[j][0], sizes[j][1])
                      for j in range(n) if j != i]
            cands_y = {0}
            cands_x = {0}
            for ox, oy, ow, oh in others:
                cands_y.add(oy + oh)
                cands_x.add(ox + ow)
            nx, ny = x, y
            for y2 in sorted(cands_y):
                if y2 >= ny or x + w > bin_w:
                    continue
                if all(not _rects_overlap((x, y2, w, h), r) for r in others):
                    ny = y2
                    break
            for x2 in sorted(cands_x):
                if x2 >= nx or x2 + w > bin_w:
                    continue
                if all(not _rects_overlap((x2, ny, w, h), r) for r in others):
                    nx = x2
                    break
            if (nx, ny) != (x, y):
                pos[i] = (nx, ny)
                moved = True
    return pos


def _maxrects_pack(sizes, bin_w):
    """MaxRects BSSF. `sizes` is [(w, h), ...]; gravity then slides leftovers up."""
    # Infinite-height bin; crop to used height after placing.
    free = [(0, 0, bin_w, 1 << 20)]

    def fits(i, w, h):
        fx, fy, fw, fh = free[i]
        if w > fw or h > fh:
            return None
        leftover_w, leftover_h = fw - w, fh - h
        # Prefer a snug leftover so a 16x16 stacks under another 16x16 (beside
        # a 16x32) instead of occupying the left of a merged 16+32 hole, which
        # would push the 16x32s out from under the dog.
        return (min(leftover_w, leftover_h), max(leftover_w, leftover_h), fy, fx)

    def split(fr, used):
        fx, fy, fw, fh = fr
        ux, uy, uw, uh = used
        if ux >= fx + fw or ux + uw <= fx or uy >= fy + fh or uy + uh <= fy:
            return [fr]
        out = []
        if uy > fy and uy < fy + fh:
            out.append((fx, fy, fw, uy - fy))
        if uy + uh < fy + fh:
            out.append((fx, uy + uh, fw, fy + fh - (uy + uh)))
        if ux > fx and ux < fx + fw:
            out.append((fx, fy, ux - fx, fh))
        if ux + uw < fx + fw:
            out.append((ux + uw, fy, fx + fw - (ux + uw), fh))
        return out

    def prune(rects):
        keep = [True] * len(rects)
        for i, a in enumerate(rects):
            if not keep[i]:
                continue
            ax, ay, aw, ah = a
            for j, b in enumerate(rects):
                if i == j or not keep[j]:
                    continue
                bx, by, bw, bh = b
                if ax >= bx and ay >= by and ax + aw <= bx + bw and ay + ah <= by + bh:
                    keep[i] = False
                    break
        return [r for r, k in zip(rects, keep) if k]

    pos = []
    for w, h in sizes:
        best_i, best_score = None, None
        for i in range(len(free)):
            score = fits(i, w, h)
            if score is not None and (best_score is None or score < best_score):
                best_i, best_score = i, score
        if best_i is None:
            raise ValueError("item %dx%d does not fit in bin width %d" % (w, h, bin_w))
        x, y = free[best_i][0], free[best_i][1]
        used = (x, y, w, h)
        nxt = []
        for fr in free:
            nxt.extend(split(fr, used))
        free = prune(nxt)
        pos.append((x, y))
    pos = _gravity(pos, sizes, bin_w)
    height = max(y + h for (x, y), (w, h) in zip(pos, sizes))
    return pos, height


def render_packed_png(path, cells, labels=None, lab_scale=2, scale=None,
                      col_units=8, groups=None):
    """Contact sheet of mixed-size cells packed into `col_units` 16-pixel
    columns.  Each cell is drawn at its own source width/height (SAT occupancy)
    so a 16x32 can sit beside two stacked 16x16s instead of a uniform grid.
    `groups` is a list of index lists packed as one horizontal strip (blob
    recolours stay together instead of filling distant leftover holes)."""
    if not cells:
        return
    scale = SCALE if scale is None else scale
    lab_h = _label_band(labels, lab_scale)
    grouped = set()
    for g in groups or []:
        grouped.update(g)
    # Super-items: a group is one strip; ungrouped cells are 1-wide items.
    items = []          # (pack_w, pack_h, [cell indices])
    i = 0
    while i < len(cells):
        in_group = None
        for g in groups or []:
            if i == g[0] and all(j < len(cells) for j in g):
                in_group = g
                break
        if in_group:
            slots = [_pack_slot(len(cells[j][0]), len(cells[j]), scale, lab_h)
                     for j in in_group]
            items.append((sum(s[0] for s in slots), max(s[1] for s in slots),
                          list(in_group)))
            i = max(in_group) + 1
            continue
        if i in grouped:
            i += 1
            continue
        h = len(cells[i])
        w = len(cells[i][0]) if cells[i] else 0
        items.append((*_pack_slot(w, h, scale, lab_h), [i]))
        i += 1
    sizes = [(w, h) for w, h, _ in items]
    widest = max(w for w, _ in sizes)
    bin_w = max(widest, col_units * (16 * scale + GAP))
    pos, used_h = _maxrects_pack(sizes, bin_w)
    # Expand strips to per-cell coordinates.
    cell_pos = [None] * len(cells)
    for (x, y), (pw, ph, idxs) in zip(pos, items):
        if len(idxs) == 1:
            cell_pos[idxs[0]] = (x, y)
            continue
        ox = x
        for j in idxs:
            cw, _ = _pack_slot(len(cells[j][0]), len(cells[j]), scale, lab_h)
            cell_pos[j] = (ox, y)
            ox += cw
    W = GAP + bin_w
    H = GAP + used_h
    buf = bytearray(W * H * 3)
    for i in range(0, W * H):
        buf[i * 3], buf[i * 3 + 1], buf[i * 3 + 2] = BG
    for idx, grid in enumerate(cells):
        x, y = cell_pos[idx]
        label = None if not labels or idx >= len(labels) else labels[idx]
        _blit_cell(buf, W, grid, None, GAP + x, GAP + y, scale, lab_h,
                   label, lab_scale)
    pngwrite.write_rgb(path, W, H, bytes(buf))

def main():
    os.makedirs(GFX, exist_ok=True)
    os.makedirs(SPRITE_DIR, exist_ok=True)
    os.makedirs(FONT_DIR, exist_ok=True)
    data = open(ROM, "rb").read()
    dump_credits_font(data)
    dump_hud_font(data)
    dump_logo_font(data)
    dump_enemy_sheet(data)
    dump_enemy_frames(data)
    dump_hazards(data)
    dump_vendor(data)
    dump_asm_sprite_rles(data)
    dump_asm_tilesets(data)

# First *recognisable* pose (ix+0B) for entity_tbl types 1-22.
# Type 9's spawn state uses 0x26 (2-cell wait, legs only); the walk frame is 0x21.
# Type 9 is the red skeleton (fast, no throw). Type 11 is the white skeleton
# (kite + ledge hop + spinning bone). Type 16 shares that SAT layout
# but stage 14+ VRAM is the axe knight (throws). Colour 0x45 = overlay index 5.
# Type 12 is the small perching raven (shape 0x89), not a bat.
# Type 14 is skipped by the SAT builder (0x644C); its tick writes SAT itself.
# Type 15 is the roc: 6-cell flyer (0x6D); init shares type 13's 0x67 then flaps.
# Type 17 intro is 0x56 (2-cell); standing 0x5B is SAT head+cape, torso is a 32x32 blit.
# Type 20 walk cycle is 0x33-0x38 (0x82 6-cell); 0x35 is a full stride, not the thin-waist 0x36.
# Type 21 walk cycle is 0x79/0x7A/0x7B (Frankenstein); 0x67 is type 24 (Igor).
# Types 0x1A/1B/1C are actor_blob_blue/_red/_white (SAT 0x81, shapes 0x9B-0xA0).
# Recolour is HUD-fixed SAT 0F/08/0E = blue/red/white, not the stage palette.
ENEMY_SHAPE_ID = {
    1: 0x3D, 2: 0x0B, 3: 0x12, 4: 0x1A, 5: 0x3F,
    6: 0x50, 7: 0x16, 8: 0x71, 9: 0x21, 10: 0x05,
    11: 0x49, 12: 0x89, 13: 0x67, 14: None, 15: 0x6D,
    16: 0x5F, 17: 0x5B, 18: 0x4F, 19: 0x2B, 20: 0x35,
    21: 0x79, 22: 0x7C,
    0x1A: 0x9B, 0x1B: 0x9B, 0x1C: 0x9B,
}
# actor_* stem (segments/actors.inc) for gfx/sheet_enemy_<name>_<id>.png.
ENEMY_NAME = {
    1: "zombie", 2: "merman_green", 3: "merman_red", 4: "hanging_bat",
    5: "dog", 6: "pikeman", 7: "flying_skull", 8: "ghost_head",
    9: "red_skeleton", 10: "skull_pile", 11: "white_skeleton", 12: "raven",
    13: "hunchback", 14: "bone_dragon", 15: "roc", 16: "axe_knight",
    17: "dracula", 18: "giant_bat", 19: "medusa", 20: "mummy",
    21: "frankenstein", 22: "grim_reaper",
    0x18: "igor",
    0x1A: "blob_blue", 0x1B: "blob_red", 0x1C: "blob_white",
}
# Every ix+0B pose the tick actually writes.  Type 14 has no 0x644C shape
# cycle; labels 0x80/0x70 are the SAT head patterns (idle closed / spit open).
# Blob 0x9D-0xA2 are the same two frames retargeted to other VRAM dests, so
# 0x9B/0x9C is the whole anim.  Roc init pose 0x67 is the hunchback sheet,
# not roc VRAM.  Skull pile 0x04/0x05 are the FE00 facing pair (vertical
# swap of the two 16x16s = H-flip); 0x06/0x07 are the same art at FE40
# (s9r4) and read as blob if composited from an FE00 room.
ENEMY_FRAMES = {
    1: (0x3B, 0x3C, 0x3D, 0x3E),
    2: (0x08, 0x09, 0x0B, 0x0C),
    3: (0x0F, 0x10, 0x11, 0x12, 0x13, 0x14),
    4: (0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20),
    5: (0x3F, 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46),
    6: (0x50, 0x51, 0x52, 0x53, 0x54, 0x55),
    7: (0x16, 0x17, 0x18, 0x19),
    8: (0x71, 0x72, 0x73, 0x74),
    9: (0x21, 0x22, 0x23, 0x24, 0x25, 0x26),
    10: (0x04, 0x05),
    11: (0x47, 0x48, 0x49, 0x4A),
    12: (0x87, 0x88, 0x89, 0x8A, 0x8B, 0x8C),
    13: (0x67, 0x68, 0x6A, 0x6B),
    14: (0x80, 0x70),
    15: (0x6D, 0x6E, 0x8D),
    16: (0x5F, 0x60, 0x61, 0x62),
    17: (0x56, 0x57, 0x5B, 0x5C, 0x5D, 0x5E),
    18: (0x4E, 0x4F),
    19: (0x2B, 0x2C),
    20: (0x33, 0x34, 0x35, 0x36, 0x37, 0x38),
    21: (0x79, 0x7A, 0x7B),
    22: (0x7C,),
    0x18: (0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C),
    0x1A: (0x9B, 0x9C), 0x1B: (0x9B, 0x9C), 0x1C: (0x9B, 0x9C),
}
# ROM has no gfx_script_convert facing.  Sheets append an H-flip of each cell.
ENEMY_SYNTH_MIRROR = frozenset((14, 21))
# room_spawner bit -> actor type (bits 0-6).
SPAWN_BIT_TYPE = {0: 1, 1: 2, 2: 3, 3: 4, 4: 7, 5: 8, 6: 15}
# Types with no spawn bit: rooms that actually host them (object list / boss
# event). Without this, max-ink picks a later tileset that reuses the same SAT
# pattern numbers and the sprite looks like scrambled knight parts.
# Type 9 must stay on stage 13 (script 0x9FB2, pal index 5 = red). The same
# pattern numbers on stage 14 room 0 are the axe knight (type 16).
# Boss event rooms (l6376h): s3r5 / s6r5 / s9r7 / s12r6 / s15r9 / s18r9.
ENEMY_ROOMS = {
    5: [(1, 2), (1, 3), (1, 7)],
    # Pikeman 0x53-55 is the FC00→FD00 convert. Stage-2 room 0 parks flying
    # skull at FD00 and max-ink would pick that for the right-facing poses.
    6: [(4, 0), (4, 1), (4, 2), (5, 0)],
    9: [(13, 0), (13, 4), (13, 8), (13, 9)],
    # Full 4-sprite pile at FE00, no convert clobber of FE40. 0x07's extra
    # cells are FE80 (blob / other) on these scripts.
    10: [(2, 0), (2, 1), (2, 3), (3, 2), (3, 4)],
    11: [(7, 2), (7, 3), (7, 4), (8, 2), (8, 3), (13, 0)],
    12: [(7, 7), (7, 8), (8, 5), (8, 6)],
    # Hunchback FD40→FE00 convert. 0x6B is FE40; without a pin, max-ink
    # picks a skull-pile room that also uses those pattern numbers.
    13: [(7, 0), (7, 4), (11, 2), (12, 6)],
    14: [(11, 5), (12, 0), (12, 4), (12, 5)],
    16: [(14, 0), (14, 1), (14, 2), (15, 1)],
    17: [(18, 9)],
    18: [(3, 5), (16, 1), (16, 2)],
    19: [(6, 5)],
    20: [(9, 7)],
    21: [(12, 6)],
    22: [(15, 9)],
    0x18: [(12, 6)],
    # Blob SAT is 2 CC cells (0x81, pats D0/D8 = FE80/FEC0). Fill/outline are
    # spr_blob / spr_blob_cc (loaded on most rooms; s4 parks them at FB80 when
    # FE80 is taken). SAT 0F/08/0E are HUD-fixed blue / red / white.
    0x1A: [(1, 0)],
    0x1B: [(1, 0)],
    0x1C: [(1, 0)],
}
# Type 14 custom SAT (handler 0xAAD4): 4 columns of 2-plane 16x16.
# lab25h X offsets; lab15h pattern/colour pairs.  spr_bone_dragon at FB80
# is 6 sprites: 70/74 open head, 78/7C body, 80/84 closed head.
TYPE14_DX = (0xD0, 0xE0, 0xF0, 0x00)
TYPE14_HEAD = {0x80: (0x80, 0x84), 0x70: (0x70, 0x74)}
TYPE14_BODY = ((0x78, 0x02), (0x7C, 0x4C))
# 0x80/0x81/0x82 offset lists at l64d4h / l64dch / l64e0h (dy, dx) pairs.
SHAPE_OFS = {
    0x80: [(0xE0, 0xF8), (0xE0, 0xF8), (0xF0, 0xF8), (0xF0, 0xF8)],
    0x81: [(0xF1, 0xF8), (0xF1, 0xF8)],
    0x82: [(0xD1, 0xF8), (0xD1, 0xF8), (0xE1, 0xF8),
           (0xE1, 0xF8), (0xF1, 0xF8), (0xF1, 0xF8)],
}
# Type 17 standing (0x5B): SAT is only the head (dy=-64) and cape/legs (dy=-16).
# The 32x32 middle is a SCREEN 5 LMMM (dracula_blit_torso) onto (X-16, Y=0x91)
# from page-1 Y=0x80.  Those slots are packed 4bpp in seg13 (dracula_body_closed
# at 0xB5A1 = cloak; dracula_body_open at 0xB719 = chest cavity).  The 16x16s
# at page-1 Y=0xA0 are portrait eyes/mouth, not the figure (that cache
# holds the vendor 32x32s until event 6 overwrites it).
DRACULA_BODY_FILE = 13 * 0x2000 + (0xB5A1 - 0xA000)
DRACULA_BODY_OPEN_FILE = 13 * 0x2000 + (0xB719 - 0xA000)
DRACULA_STAND = frozenset((0x5B, 0x5C, 0x5D, 0x5E))

def _s8(b):
    return b - 256 if b >= 128 else b

def _word(data, file_off):
    return data[file_off] | (data[file_off + 1] << 8)

def _cpu_file(seg, cpu, win):
    return seg * 0x2000 + (cpu - win)

def dump_enemy_sheet(data):
    """One labelled frame per entity_tbl type (1-22), plus the candle-blob
    recolours (0x1A/1B/1C).  Composited from the seg6 shape stream + the
    1bpp sprite patterns the per-room gfx script RLE-loads into VRAM 0xF800+.
    Type 17 also blits the 32x32 4bpp cloak from dracula_body_closed.
    Each frame is cropped to its SAT occupancy (16x16 / 16x32 / …) and the
    mixed sizes are packed instead of a uniform 64x64 grid.
    Written to gfx/enemy_sheet.png (not gfx/sprites/)."""
    types = list(range(1, 23)) + [0x1A, 0x1B, 0x1C]
    cells = []
    vram_cache = {}
    for typ in types:
        cells.append(_composite_enemy(data, typ, vram_cache))
    labels = []
    for t, grid in zip(types, cells):
        h = len(grid)
        w = len(grid[0]) if grid else 0
        labels.append("%s %dx%d" % (_hex_id(t), w, h))
    n = len(cells)
    # Blobs 1A-1C are the last three; pack as one strip so they stay together.
    render_packed_png(os.path.join(GFX, "enemy_sheet.png"), cells, labels=labels,
                      groups=[[n - 3, n - 2, n - 1]])
    print("enemy_sheet.png          entity types 01-22 + blob 1A-1C")

def dump_enemy_frames(data):
    """One packed sheet per enemy of every ix+0B pose
    (gfx/sheet_enemy_<name>_<id>.png).  Labels are hex shape ids only.
    Same compositor as enemy_sheet.png; the group sheet is unchanged.
    VRAM is pinned once from the canonical pose so convert-dest frames
    (hunchback 0x6B, pikeman 0x53-55) cannot pick a later tileset that
    reuses those pattern numbers."""
    types = list(range(1, 23)) + [0x18, 0x1A, 0x1B, 0x1C]
    vram_cache = {}
    n_sheets = 0
    for typ in types:
        name = ENEMY_NAME.get(typ)
        if not name:
            continue
        frames = ENEMY_FRAMES.get(typ, (ENEMY_SHAPE_ID.get(typ),))
        cells, labels, seen = [], [], set()
        vram_info = _vram_info_for_type(data, typ, vram_cache)
        if frames is None:
            frames = (None,)
        for sid in frames:
            grid = _composite_enemy(data, typ, vram_cache, sid,
                                    vram_info=vram_info)
            if _cell_ink(grid) < 8:
                continue
            key = _cell_key(grid)
            if key in seen:
                continue
            seen.add(key)
            cells.append(grid)
            if sid is not None:
                labels.append(_hex_id(sid))
        if typ in ENEMY_SYNTH_MIRROR:
            extra_c, extra_l = [], []
            for grid, lab in zip(cells, labels or [None] * len(cells)):
                flipped = _hflip_grid(grid)
                key = _cell_key(flipped)
                if key in seen:
                    continue
                seen.add(key)
                extra_c.append(flipped)
                extra_l.append(lab)
            cells.extend(extra_c)
            if labels:
                labels.extend(extra_l)
        if not cells:
            continue
        fname = "sheet_enemy_%s_%02x.png" % (name, typ)
        render_packed_png(os.path.join(GFX, fname), cells,
                          labels=labels or None)
        n_sheets += 1
        print("%-28s %d frames" % (fname, len(cells)))
    print("sheet_enemy_*.png         %d per-enemy sheets" % n_sheets)

def _cell_ink(grid):
    return sum(1 for row in grid for px in row if px != OFF)

def _cell_key(grid):
    return tuple(tuple(px for px in row) for row in grid)

def _hflip_grid(grid):
    return [list(reversed(row)) for row in grid]

def _sat_bbox(typ, parts, shape_id=None):
    """Bounding box of unique 16x16 SAT cells (plus type 17's 32x32 torso)."""
    dxs = [p[1] for p in parts]
    dys = [p[0] for p in parts]
    x0, y0 = min(dxs), min(dys)
    x1, y1 = max(dxs) + 16, max(dys) + 16
    if typ == 17 and (shape_id is None or shape_id in DRACULA_STAND):
        x0, y0 = min(x0, -16), min(y0, -48)
        x1, y1 = max(x1, 16), max(y1, -16)
    return x0, y0, x1 - x0, y1 - y0

def _composite_enemy(data, typ, vram_cache, shape_id=None, vram_info=None):
    ncells = data[_cpu_file(1, 0x605E, 0x6000) + typ]
    if typ == 14:
        parts, colors = _type14_parts(shape_id)
        sid = shape_id
    else:
        sid = ENEMY_SHAPE_ID.get(typ) if shape_id is None else shape_id
        if sid is None or not ncells:
            return [[OFF]]
        parts = _parse_shape(data, sid, ncells)
        colors = _type_colors(data, typ, ncells)
        if typ == 17 and sid in DRACULA_STAND:
            # spawn table only colours 2 cells (intro 0x56). Standing 0x5B
            # fills all 8 from dracula_sat_cols (02 48 repeated).
            colors = [0x02, 0x48] * 4
    if not parts:
        return [[OFF]]
    if vram_info is None:
        vram, stage, room = _vram_for_type(data, typ, parts, vram_cache)
    else:
        vram, stage, room = vram_info
    pal = vk_playfield_palette(data, stage, room)
    if typ == 17:
        _apply_palette_overlay(pal, load_palette_table(data, 0x15F88))
        _apply_palette_overlay(pal, load_palette_table(data, 0x15F6F))
    x0, y0, bw, bh = _sat_bbox(typ, parts, sid)
    # OFF fills the occupied SAT rectangle so cell bounds read like the
    # 16x16 / 8x8 sheets (empty pixels are visible, not sheet-BG).
    grid = [[OFF] * bw for _ in range(bh)]
    index = [[0] * bw for _ in range(bh)]
    ox, oy = -x0, -y0
    if typ == 17 and sid in DRACULA_STAND:
        # Playfield LMMM sits behind SAT head/cape.
        _blit_dracula_torso(data, grid, pal, ox, oy, sid)
    for i, (dy, dx, pat) in enumerate(parts):
        src = 0xF800 + (pat * 8)
        raw = bytes(vram[src + k] for k in range(32))
        spr = gfxview.sprite16_1bpp(raw)
        col = colors[i] if i < len(colors) else 0x02
        if (col & 0x0F) == 0:
            continue                  # extra==0 -> SAT Y=0xE1 (hidden)
        idx = col & 0x0F
        cc = bool(col & 0x40)
        py, px = oy + dy, ox + dx
        for y in range(16):
            for x in range(16):
                if spr[y][x] != "#":
                    continue
                yy, xx = py + y, px + x
                if 0 <= yy < bh and 0 <= xx < bw:
                    if cc and index[yy][xx]:
                        index[yy][xx] |= idx
                    elif not cc or index[yy][xx] == 0:
                        index[yy][xx] = idx
    for y in range(bh):
        for x in range(bw):
            if index[y][x]:
                grid[y][x] = pal[index[y][x]]
    return grid

def _unpack_dracula_body(data, file_off):
    """dracula_body_unpack (0x5834): 32 rows of N zeros + (12-N) bytes + 4 zeros."""
    p = file_off
    rows = []
    for _ in range(32):
        n = data[p]
        p += 1
        nbytes = 12 - n
        payload = data[p:p + nbytes]
        p += nbytes
        rows.append(bytes(n) + bytes(payload) + bytes(4))
    return rows, p

def _blit_dracula_torso(data, grid, pal, ox, oy, shape_id=0x5B):
    """Standing 32x32 cloak/chest into the SAT gap.  0x5B/0x5D = closed,
    0x5C/0x5E = open; 0x5D/0x5E are the H-mirrors from dracula_body_load."""
    fo = DRACULA_BODY_OPEN_FILE if shape_id in (0x5C, 0x5E) else DRACULA_BODY_FILE
    rows, _ = _unpack_dracula_body(data, fo)
    h, w = len(grid), len(grid[0])
    x0, y0 = ox - 16, oy - 48
    flip = shape_id in (0x5D, 0x5E)
    for y, row in enumerate(rows):
        pix = []
        for b in row:
            pix.append(b >> 4)
            pix.append(b & 0x0F)
        if flip:
            pix.reverse()
        for x, nibble in enumerate(pix):
            if not nibble:
                continue
            yy, xx = y0 + y, x0 + x
            if 0 <= yy < h and 0 <= xx < w:
                grid[yy][xx] = pal[nibble]

def _parse_shape(data, shape_id, ncells):
    tbl = _cpu_file(6, 0xB473, 0xA000)
    ptr = _word(data, tbl + shape_id * 2)
    if not (0xA000 <= ptr <= 0xBFFF):
        return []
    st = _cpu_file(6, ptr, 0xA000)
    first = data[st]
    if first in SHAPE_OFS:
        # 0x80/81/82: one pattern byte per offset-list slot. ncells from
        # 0x605E is the SAT *allocation*; using it past the list reads the
        # next 0x81 prefix as a pattern (type 17/21 garbage).
        pairs = SHAPE_OFS[first]
        n = min(ncells, len(pairs))
        pats = [data[st + 1 + i] for i in range(n)]
        return [(_s8(dy), _s8(dx), pats[i]) for i, (dy, dx) in enumerate(pairs[:n])]
    out = []
    p = st
    for _ in range(ncells):
        out.append((_s8(data[p]), _s8(data[p + 1]), data[p + 2]))
        p += 3
    return out

def _type14_parts(shape_id=None):
    """Type 14 bypasses 0x644C; tick 0xAAD4 writes 8 SAT cells itself."""
    head = TYPE14_HEAD.get(shape_id, TYPE14_HEAD[0x80])
    sat = ((head[0], 0x02), (head[1], 0x4C)) + TYPE14_BODY * 3
    parts, colors = [], []
    for i, (pat, col) in enumerate(sat):
        parts.append((0, _s8(TYPE14_DX[i // 2]), pat))
        colors.append(col)
    return parts, colors

def _vram_info_for_type(data, typ, cache):
    """One tileset for every frame of `typ`, scored on the canonical pose."""
    ncells = data[_cpu_file(1, 0x605E, 0x6000) + typ]
    if typ == 14:
        parts, _ = _type14_parts()
    else:
        sid = ENEMY_SHAPE_ID.get(typ)
        if sid is None or not ncells:
            return None
        parts = _parse_shape(data, sid, ncells)
        if not parts:
            return None
    return _vram_for_type(data, typ, parts, cache)

def _type_colors(data, typ, ncells):
    # spawn_actor_init: DE=0x608B, A=type -> word table of per-cell colour bytes.
    ptr = _word(data, _cpu_file(1, 0x608B, 0x6000) + typ * 2)
    fo = _cpu_file(1, ptr, 0x6000)
    return list(data[fo:fo + ncells])

def _vram_for_type(data, typ, parts, cache):
    bit = {v: k for k, v in SPAWN_BIT_TYPE.items()}.get(typ)
    if typ in ENEMY_ROOMS:
        candidates = list(ENEMY_ROOMS[typ])
    elif bit is not None:
        candidates = _rooms_with_spawn_bit(data, bit)
    else:
        candidates = [(s, 0) for s in range(1, 19)]
    best, best_ink, best_stage, best_room = None, -1, 1, 0
    seen = set()
    for stage, room in candidates:
        key = _script_key(data, stage, room)
        if key is None or key in seen:
            continue
        seen.add(key)
        if key not in cache:
            cache[key] = _load_script_vram(data, key)
        vram = cache[key]
        ink = 0
        for _, _, pat in parts:
            src = 0xF800 + pat * 8
            ink += sum(vram[src:src + 32])
        if ink > best_ink:
            best, best_ink, best_stage, best_room = vram, ink, stage, room
    if best is None:
        return bytearray(0x10000), 1, 0
    return best, best_stage, best_room

def _rooms_with_spawn_bit(data, bit):
    tbl = _cpu_file(14, 0x85A6, 0x8000)
    out = []
    for stage in range(1, 19):
        ptr = _word(data, tbl + stage * 2)
        nxt = _word(data, tbl + (stage + 1) * 2) if stage < 18 else ptr + 16
        n = max(1, min(16, nxt - ptr))
        fo = _cpu_file(14, ptr, 0x8000)
        for room in range(n):
            if data[fo + room] & (1 << bit):
                out.append((stage, room))
    return out

def _room_record(data, stage, room):
    """9AB0[stage-1] -> 4 bytes/room: gfx-script word, palette-table word."""
    if stage < 1:
        return None, None
    base_tbl = _cpu_file(9, 0x9AB0, 0x8000)
    rec_ptr = _word(data, base_tbl + (stage - 1) * 2)
    rec = rec_ptr + room * 4
    if not (0x8000 <= rec < 0xA000 - 4):
        return None, None
    fo = _cpu_file(9, rec, 0x8000)
    return _word(data, fo), _word(data, fo + 2)

def _script_key(data, stage, room):
    script, _pal = _room_record(data, stage, room)
    if script is None or not (0x8000 <= script <= 0xBFFF):
        return None
    return script

def _stage_nrooms(data, stage):
    """minimap_room_count (seg2 0x95FD), indexed by D000 stage 0..18."""
    return data[_cpu_file(2, 0x95FD, 0x8000) + stage]

def _iter_script(data, script_cpu):
    """Yield gfx_script_run ops: (0, src, dest, None), (1, src, dest, count),
    or (cmd, None, None, None) for cmd>=2. Stops at 0xFF."""
    cpu = script_cpu
    for _ in range(80):
        if 0x8000 <= cpu < 0xA000:
            fo = _cpu_file(9, cpu, 0x8000)
        elif 0xA000 <= cpu < 0xC000:
            fo = _cpu_file(10, cpu, 0xA000)
        else:
            return
        cmd = data[fo]
        cpu += 1
        fo += 1
        if cmd == 0xFF:
            return
        if cmd == 0:
            src = _word(data, fo)
            dest = _word(data, fo + 2)
            cpu += 4
            yield 0, src, dest, None
        elif cmd == 1:
            src = _word(data, fo)
            cnt = data[fo + 2]
            dest = _word(data, fo + 3)
            cpu += 5
            yield 1, src, dest, cnt
        else:
            cpu += 6
            yield cmd, None, None, None

def _load_script_vram(data, script_cpu):
    vram = bytearray(0x10000)
    if not script_cpu:
        return vram
    for cmd, src, dest, extra in _iter_script(data, script_cpu):
        if cmd == 0:
            src_off = _rle_src_file(src)
            if src_off is None:
                continue
            try:
                out, base, _end = rledec.decompress(data, src_off, dest)
                for i, b in enumerate(out):
                    addr = base + i
                    if addr < 0x10000:
                        vram[addr] = b
            except Exception:
                pass
        elif cmd == 1:
            _apply_sprite_conv(vram, src, extra, dest)
    return vram

def _bitrev(b):
    r = 0
    for _ in range(8):
        r = (r << 1) | (b & 1)
        b >>= 1
    return r

def _apply_sprite_conv(vram, src, count, dest):
    """Replay gfx_script_convert / sub_4786h: bit-reverse 16-byte halves and copy
    count*32 bytes from VRAM src to dest (linear 16x16 -> sprite quadrants)."""
    e800 = bytes(vram[src:src + count * 32])
    if len(e800) < count * 32:
        e800 = e800 + bytes(count * 32 - len(e800))
    ec = bytearray(0x400)
    hl = 0
    de = 0x10                          # EC10 relative to EC00
    for _ in range(count):
        for i in range(16):
            if 0 <= de < len(ec) and hl < len(e800):
                ec[de] = _bitrev(e800[hl])
            de += 1
            hl += 1
        e = de & 0xFF
        new_e = (e + 0xE0) & 0xFF
        de = (de & ~0xFF) | new_e
        if e + 0xE0 < 0x100:
            de -= 0x100
        for i in range(16):
            if 0 <= de < len(ec) and hl < len(e800):
                ec[de] = _bitrev(e800[hl])
            de += 1
            hl += 1
        de += 0x20
    n = count * 32
    for i in range(n):
        addr = dest + i
        if addr < 0x10000:
            vram[addr] = ec[i] if i < len(ec) else 0

def _rle_src_file(cpu):
    if 0xA000 <= cpu < 0xC000:
        return _cpu_file(10, cpu, 0xA000)
    if 0x8000 <= cpu < 0xA000:
        return _cpu_file(9, cpu, 0x8000)
    return None

# seg14 credits_font @ CPU 0x8824 (file 0x1C824): 40 x 8x8 1bpp, MSB = left.
# Order: 0-9 . ' : , then A-Z.  Colour 0x0E is the C register
# credits_font_load passes (SCREEN 5 ink).  Loaded by credits_init for the
# ending message + credits, not the in-game HUD.
CREDITS_FONT_FILE = 14 * 0x2000 + 0x0824
CREDITS_FONT_CHARS = "0123456789.':," + "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

def dump_hazards(data):
    """Environmental hazards - things that damage Simon but are not actors.
    The 0xC580 spike bars of stage 6 room 1 are the only one: no C500/C800
    slot, no HP, and drawn as a 4bpp *background* block rather than sprites,
    so they are absent from enemy_sheet.png.

    seg0 0x5494 assembles the picture in VRAM page 1 at (0x80, 0x70) out of two
    seg9 fragments, and spike_bar_slot_tick (seg2 0x8FF1) HMMMs a 32x16 window
    of it into the playfield.  The top 4 rows are one chain link: the copy is
    drawn at Y-4 with a 4px step, so descending leaves a link behind each step
    and the chain is a smear, not stored artwork."""
    pal = vk_playfield_palette(data, 6, 1)

    def frag(cpu, w, h):
        fo = _cpu_file(9, cpu, 0x8000)
        return [[data[fo + y * (w // 2) + x // 2] >> 4 if x % 2 == 0
                 else data[fo + y * (w // 2) + x // 2] & 0x0F
                 for x in range(w)] for y in range(h)]

    link = frag(0x9A80, 8, 4)          # spike_bar_mount
    unit = frag(0x9A90, 8, 8)          # spike (tiled x4 across the 32px bar)
    bar = [[0] * 32 for _ in range(12)]
    for y in range(4):                 # link centred over the bar
        for x in range(8):
            bar[y][12 + x] = link[y][x]
    for i in range(4):
        for y in range(8):
            for x in range(8):
                bar[4 + y][i * 8 + x] = unit[y][x]

    def rgb(grid):
        return [[pal[v] if v else OFF for v in row] for row in grid]

    cells = [rgb(bar), rgb(unit), rgb(link)]
    labels = ["SPIKE BAR 32x12", "SPIKE 8x8", "CHAIN 8x4"]
    render_packed_png(os.path.join(GFX, "hazards.png"), cells, labels=labels,
                      col_units=4)
    print("hazards.png              spike bar (stage 6 room 1) + its fragments")


def dump_vendor(data):
    """Vendor 32x32: 8 x 8x8 tiles at seg10 0xBDA7, assembled by
    vendor_tile_ptr, with nibble 0xF recoloured from vendor_recolor_tbl.
    Staged at page-1 Y=0xA0; vendor_draw LMMMs one slot onto the playfield.
    Event-6 portrait parts overwrite that cache (no vendors in that room)."""
    pal = vk_play_palette(data)
    fo = _cpu_file(10, 0xBDA7, 0xA000)
    src = data[fo:fo + 256]
    ptrs = [_word(data, 0x1575 + i * 2) for i in range(16)]
    fills = list(data[0x1595:0x159A])

    def tile(addr):
        if addr == 0xE900:
            return bytes(32)
        return src[addr - 0xE800:addr - 0xE800 + 32]

    def assemble(fill):
        img = [[0] * 32 for _ in range(32)]
        for ty in range(4):
            for tx in range(4):
                t = tile(ptrs[ty * 4 + tx])
                for r in range(8):
                    row = t[r * 4:(r + 1) * 4]
                    for c, b in enumerate(row):
                        hi, lo = b >> 4, b & 0x0F
                        if hi == 0x0F:
                            hi = fill
                        if lo == 0x0F:
                            lo = fill
                        img[ty * 8 + r][tx * 8 + c * 2] = hi
                        img[ty * 8 + r][tx * 8 + c * 2 + 1] = lo
        return img

    def rgb(grid):
        return [[pal[v] if v else OFF for v in row] for row in grid]

    labels = ["0 HEARTS 32x32", "1 HIT 32x32", "2 FLASH 32x32",
              "3 IDLE 32x32", "4 MOOD 32x32"]
    cells = [rgb(assemble(c)) for c in fills]
    render_packed_png(os.path.join(GFX, "vendor.png"), cells, labels=labels,
                      col_units=10, groups=[list(range(5))])
    print("vendor.png               5 recolored vendor 32x32s (C70B 0..4)")


def dump_credits_font(data):
    """Uncompressed 8x8 1bpp ending-credits font (raw, not RLE)."""
    pal = vk_play_palette(data)
    raw = data[CREDITS_FONT_FILE:CREDITS_FONT_FILE + 40 * 8]
    cells = []
    for i in range(40):
        glyph = raw[i * 8:(i + 1) * 8]
        cells.append([[(row >> (7 - x)) & 1 for x in range(8)] for row in glyph])
    render_png(os.path.join(FONT_DIR, "font_credits.png"), cells, [OFF, pal[14]],
               cols=10, size=8, scale=12,
               labels=[_hex_id(ord(c)) for c in CREDITS_FONT_CHARS])
    print("fonts/font_credits.png   40 x 8x8 1bpp (0-9 . ' : , A-Z)")

# seg8 hud_font @ CPU 0xBD80 (file 0x11D80): 48 x 8x8 1bpp, MSB = left.
# ASCII '0'..'_' (vk ids 0x20+).  hud_font_load ink 0x0E.  Not credits_font.
HUD_FONT_FILE = 8 * 0x2000 + 0x1D80
HUD_FONT_CHARS = "".join(chr(c) for c in range(0x30, 0x60))

def dump_hud_font(data):
    """Uncompressed 8x8 1bpp HUD/title font (raw, not RLE)."""
    pal = vk_play_palette(data)
    raw = data[HUD_FONT_FILE:HUD_FONT_FILE + 48 * 8]
    cells = []
    for i in range(48):
        glyph = raw[i * 8:(i + 1) * 8]
        cells.append([[(row >> (7 - x)) & 1 for x in range(8)] for row in glyph])
    render_png(os.path.join(FONT_DIR, "font_hud.png"), cells, [OFF, pal[14]],
               cols=16, size=8, scale=12,
               labels=[_hex_id(0x20 + i) for i in range(48)])
    print("fonts/font_hud.png       48 x 8x8 1bpp ('0'-'_')")

# seg13 logo_font @ CPU 0xBE59 (file 0x1BE59): 52 x 8x8 1bpp, MSB = left.
# Tile ids 0x01-0x34 (id 0x00 is blank at X=0).  logo_font_load three inks
# onto page 0 at Y=0; tile_string_draw copies with no HUD +0x38.
LOGO_FONT_FILE = 13 * 0x2000 + 0x1E59

def dump_logo_font(data):
    """Uncompressed 8x8 1bpp boot Konami-logo font (raw, not RLE)."""
    pal = vk_play_palette(data)
    raw = data[LOGO_FONT_FILE:LOGO_FONT_FILE + 52 * 8]
    cells = []
    for i in range(52):
        glyph = raw[i * 8:(i + 1) * 8]
        cells.append([[(row >> (7 - x)) & 1 for x in range(8)] for row in glyph])
    render_png(os.path.join(FONT_DIR, "font_logo.png"), cells, [OFF, pal[14]],
               cols=16, size=8, scale=12,
               labels=[_hex_id(0x01 + i) for i in range(52)])
    print("fonts/font_logo.png      52 x 8x8 1bpp (Konami logo ids 01-34)")

# Packed 1bpp streams in enemy_sprite_rle.asm (seg10).  Label comment
# "type N SAT" maps to entity_tbl for SAT colours + room playfield palette.
SPRITE_RLE_TYPE = {
    "spr_zombie": 1, "spr_merman": 2, "spr_hanging_bat": 4, "spr_dog": 5,
    "spr_pikeman": 6, "spr_flying_skull": 7, "spr_ghost_head": 8,
    "spr_skeleton": 11, "spr_skull_pile": 10, "spr_raven": 12,
    "spr_hunchback": 13, "spr_bone_dragon": 14, "spr_roc": 15,
    "spr_axe_knight": 16, "spr_dracula": 17, "spr_giant_bat": 18,
    "spr_medusa": 19, "spr_mummy": 20, "spr_frankenstein": 21,
    "spr_grim_reaper": 22, "spr_blob": 0x1A, "spr_blob_cc": 0x1A,
}
# Streams not in room gfx-scripts (load_weapon_sprites / load_vdoor / frontend).
SPRITE_RLE_DEST = {
    0xA0EA: 0xF900, 0xA147: 0xF9C0, 0xA185: 0xFF00,
    0xA24E: 0xF8C0, 0xA272: 0xF8C0, 0xA4C9: 0xF8C0, 0xB0AA: 0xFA00,
}
# load_intro_sprites: intro_simon_0..7 at F800 + n*0x40.
INTRO_SIMON_DEST = {
    0xA319: 0xF800, 0xA351: 0xF840, 0xA38C: 0xF880, 0xA3CA: 0xF8C0,
    0xA40B: 0xF900, 0xA447: 0xF940, 0xA480: 0xF980, 0xA4BC: 0xF9C0,
}
SIMON_RLE_ORPHANS = (0xA671, 0xA6E4, 0xA759, 0xAF78, 0xAFEA, 0xB05F)
_RE_RLE_HDR = re.compile(
    r"^(\w+):\s*;\s*0x([0-9A-Fa-f]{4})"
)
_RE_BARE_LABEL = re.compile(r"^(\w+):\s*$")
_RE_DEFB_TOK = re.compile(r"0x([0-9A-Fa-f]{2})|%([01]{8})")


def _parse_asm_sprite_rle(path, default_cpu=None):
    """Yield (name, cpu, packed_bytes) for each packed stream in the asm."""
    streams, name, cpu, buf = [], None, None, bytearray()

    def flush():
        nonlocal name, cpu, buf
        if name is not None and buf:
            streams.append((name, cpu, bytes(buf)))
        name, cpu, buf = None, None, bytearray()

    for line in open(path):
        hdr = _RE_RLE_HDR.match(line)
        if hdr:
            flush()
            if "unid" in hdr.group(1):
                continue
            name = hdr.group(1)
            cpu = int(hdr.group(2), 16)
            continue
        bare = _RE_BARE_LABEL.match(line)
        if bare:
            flush()
            if default_cpu is not None:
                name = bare.group(1)
                cpu = default_cpu
            continue
        if re.match(r"^\w+:", line):
            flush()
            continue
        if name is None or not _RE_DEFB.match(line):
            continue
        payload = line.split(";")[0]
        for tok in _RE_DEFB_TOK.finditer(payload):
            if tok.group(1):
                buf.append(int(tok.group(1), 16))
            else:
                buf.append(int(tok.group(2), 2))
    flush()
    return streams


def _sprite_rle_dests(data):
    dest_of = dict(SPRITE_RLE_DEST)
    for stage in range(1, 19):
        for room in range(_stage_nrooms(data, stage)):
            script, _pal = _room_record(data, stage, room)
            if script is None or not (0x8000 <= script <= 0xBFFF):
                continue
            for cmd, src, dest, _extra in _iter_script(data, script):
                if cmd == 0 and dest >= 0xF800:
                    dest_of.setdefault(src, dest)
    return dest_of


def _sat_plane_map(data, typ, vram_cache):
    """Pattern VRAM address -> SAT colour index for all poses of typ."""
    vram_info = _vram_info_for_type(data, typ, vram_cache)
    if vram_info is None:
        return vk_play_palette(data), {}, None
    _vram, stage, room = vram_info
    pal = vk_playfield_palette(data, stage, room)
    if typ == 17:
        _apply_palette_overlay(pal, load_palette_table(data, 0x15F88))
        _apply_palette_overlay(pal, load_palette_table(data, 0x15F6F))
    ncells = data[_cpu_file(1, 0x605E, 0x6000) + typ]
    cmap = {}
    frames = ENEMY_FRAMES.get(typ, (ENEMY_SHAPE_ID.get(typ),))
    if frames is None:
        frames = (None,)
    converts = []
    script, _ = _room_record(data, stage, room)
    if script:
        for cmd, src, dest, extra in _iter_script(data, script):
            if cmd == 1:
                converts.append((src, dest, extra))
    for sid in frames:
        if typ == 14:
            parts, colors = _type14_parts(sid)
        else:
            if sid is None or not ncells:
                continue
            parts = _parse_shape(data, sid, ncells)
            colors = _type_colors(data, typ, ncells)
            if typ == 17 and sid in DRACULA_STAND:
                colors = [0x02, 0x48] * 4
        for i, (_dy, _dx, pat) in enumerate(parts):
            col = colors[i] if i < len(colors) else 0x02
            idx = col & 0x0F
            if idx:
                cmap[0xF800 + pat * 8] = idx
    for src, dest, count in converts:
        for i in range(count):
            d, s = dest + i * 32, src + i * 32
            if d in cmap and s not in cmap:
                cmap[s] = cmap[d]
            if s in cmap and d not in cmap:
                cmap[d] = cmap[s]
    return pal, cmap, (stage, room)


def _weapon_plane_map(name, dest, pal):
    """Thrown-weapon SAT: knife/axe 02 then 0C, cross 0F/0E."""
    cmap = {}
    if name == "weapon_cross":
        cols = (0x0F, 0x0E, 0x0F, 0x0E)
    else:
        n = 2 if name == "weapon_knife" else 4
        cols = tuple(0x02 if i % 2 == 0 else 0x0C for i in range(n))
    for i, idx in enumerate(cols):
        cmap[dest + i * 32] = idx
    return pal, cmap


def _paint_plane(raw, pal, idx):
    """One 16x16 1bpp pattern in a single SAT colour."""
    spr = gfxview.sprite16_1bpp(raw)
    rgb = pal[idx] if idx else OFF
    return [[rgb if ch == "#" else OFF for ch in row] for row in spr]


def _simon_rle_dests(data):
    dest_of = dict(INTRO_SIMON_DEST)
    base = _cpu_file(13, 0xA281, 0xA000)
    for i in range(40):
        dest_of.setdefault(_word(data, base + i * 2), 0xF800)
    base = _cpu_file(13, 0xA2D1, 0xA000)
    for i in range(36):
        dest_of.setdefault(_word(data, base + i * 2), 0xF840)
    for cpu in SIMON_RLE_ORPHANS:
        dest_of.setdefault(cpu, 0xF820)
    return dest_of


def _enemy_colour_maps(data, streams, dest_of, vram_cache, type_maps, hud_pal):
    """Per-stream (pal, cmap) for enemy_sprite_rle.asm."""
    out = []
    for name, cpu, packed in streams:
        dest = dest_of.get(cpu, 0xF800)
        typ = SPRITE_RLE_TYPE.get(name)
        if name.startswith("weapon_") and dest == 0xF8C0:
            pal, cmap = _weapon_plane_map(name, dest, hud_pal)
        elif typ is not None:
            if typ not in type_maps:
                type_maps[typ] = _sat_plane_map(data, typ, vram_cache)
            pal, cmap, _room = type_maps[typ]
        else:
            pal, cmap = hud_pal, {}
            try:
                dec, base, _end = rledec.decompress(packed, 0, dest)
            except Exception:
                out.append((pal, cmap))
                continue
            best, hit = None, 0
            for t in list(range(1, 23)) + [0x18, 0x1A, 0x1B, 0x1C]:
                if t not in type_maps:
                    type_maps[t] = _sat_plane_map(data, t, vram_cache)
                _p, cm, _r = type_maps[t]
                n = sum(1 for a in cm if base <= a < base + len(dec))
                if n > hit:
                    best, hit = t, n
            if best is not None and hit:
                pal, cmap, _room = type_maps[best]
        out.append((pal, cmap))
    return out


def _dump_sprite_rle_asm(data, fname, dest_of, pal_for, idx_for, default_cpu=None,
                         skip_prefix=0, force_pal2_black=False):
    """One sheet: every 32-byte plane, labelled with VRAM dest."""
    path = os.path.join(DATA_DIR, fname)
    if not os.path.isfile(path):
        return
    streams = _parse_asm_sprite_rle(path, default_cpu=default_cpu)
    cells, labels = [], []
    n_skip = 0
    for i, (name, cpu, packed) in enumerate(streams):
        if skip_prefix:
            packed = packed[skip_prefix:]
        dest = dest_of.get(cpu, 0xF800)
        try:
            out, base, _end = rledec.decompress(packed, 0, dest)
        except Exception:
            n_skip += 1
            continue
        pal = pal_for
        cmap = idx_for
        if not callable(idx_for):
            pal = pal_for[i]
            cmap = idx_for[i]
        if force_pal2_black:
            pal = list(pal)
            pal[2] = (0, 0, 0)
        for off in range(0, len(out) - 31, 32):
            addr = base + off
            if callable(cmap):
                idx = cmap(addr, off)
            else:
                idx = cmap.get(addr, 14)
            cells.append(_paint_plane(bytes(out[off:off + 32]), pal, idx))
            labels.append("%04X" % addr)
    stem = os.path.splitext(fname)[0]
    render_png(os.path.join(SPRITE_DIR, stem + ".png"), cells, [OFF],
               cols=8, labels=labels, size=16, scale=8)
    print("%-28s %d streams, %d cells (skip %d)"
          % (stem + ".png", len(streams), len(cells), n_skip))


def dump_asm_sprite_rles(data):
    """One sheet per packed 1bpp sprite asm (same idea as dump_asm_tilesets).

    Output is gfx/sprites/<stem>.png for the four asms in ASM_SPRITE_STEMS.
    One cell per 32-byte plane, header = VRAM dest.  No CC overlay.
    """
    hud = vk_play_palette(data)
    vram_cache, type_maps = {}, {}

    dest_of = _sprite_rle_dests(data)
    path = os.path.join(DATA_DIR, "enemy_sprite_rle.asm")
    streams = _parse_asm_sprite_rle(path)
    maps = _enemy_colour_maps(data, streams, dest_of, vram_cache, type_maps, hud)
    _dump_sprite_rle_asm(
        data, "enemy_sprite_rle.asm", dest_of,
        [m[0] for m in maps], [m[1] for m in maps])

    simon_dest = _simon_rle_dests(data)
    def simon_idx(addr, off):
        return 1 if (off // 32) % 2 == 0 else 2
    _dump_sprite_rle_asm(data, "simon_rle.asm", simon_dest, hud, simon_idx)

    intro_pal = vk_intro_palette(data)
    _dump_sprite_rle_asm(
        data, "intro_sky.asm", {0xB895: 0xFA00}, intro_pal,
        lambda addr, off: 14, default_cpu=0xB895)

    def title_idx(addr, off):
        return 8 if (off // 32) % 2 == 0 else 2
    _dump_sprite_rle_asm(
        data, "title_jp_sprites.asm", {0xBBF6: 0xF800}, hud, title_idx,
        skip_prefix=2, force_pal2_black=True)


# 8x8 4bpp tileset dumps live in segments/data/*.asm.  make gfx writes one
# sheet per file to gfx/tilesets/<stem>.png; cell header is the CPU address
# (4 hex digits, no 0x — roomperm.draw_text treats lowercase x as multiply).
DATA_DIR = os.path.join(ROOT, "segments", "data")
_RE_DEFB = re.compile(r"^\s*defb\b", re.I)
_RE_HEXB = re.compile(r"0x([0-9A-Fa-f]{2})\b")
_RE_ADDR_LABEL = re.compile(r"^\s*\w+:\s*;\s*0x([0-9A-Fa-f]{4})\b")
_RE_ADDR_CMT = re.compile(r"^\s*;\s*0x([0-9A-Fa-f]{4})\b")
_RE_ADDR_INLINE = re.compile(r";\s*0x([0-9A-Fa-f]{4})\b")
# Full 8x8 tile headers (`s07 tile 0x00`).  "rest of s10 tile 0x0C" prefixes
# are skipped: do not use a lookahead after `\s+` (backtracking would still match).
_RE_TILE_HDR = re.compile(r"^\s*;\s*0x([0-9A-Fa-f]{4})\s+(.*)")

_ASM_PAL_CACHE = None


def vk_intro_palette(data):
    """Intro walk-up palette: HUD-fixed, then intro_palette (0xBFA1) over 4-13
    (including 8 and 12).  Not title_extra_palette."""
    pal = [(0, 0, 0)] * 16
    _apply_palette_overlay(pal, load_palette_table(data, 0x15F88))
    _apply_palette_overlay(pal, load_palette_table(data, 0x15FA1))
    return pal


def _asm_palette_tables():
    """label -> 16-colour overlay, parsed from stage_palettes.asm."""
    global _ASM_PAL_CACHE
    if _ASM_PAL_CACHE is not None:
        return _ASM_PAL_CACHE
    tables = {}
    current = None
    buf = bytearray()

    def flush():
        nonlocal current, buf
        if current is not None and buf:
            tables[current] = load_palette_table(bytes(buf), 0)
        current = None
        buf = bytearray()

    path = os.path.join(DATA_DIR, "stage_palettes.asm")
    for line in open(path):
        m = re.match(r"^([A-Za-z_][\w]*):", line)
        if m:
            flush()
            current = m.group(1)
            continue
        if current is None or not _RE_DEFB.match(line):
            continue
        payload = line.split(";")[0]
        for hx in _RE_HEXB.findall(payload):
            buf.append(int(hx, 16))
    flush()
    _ASM_PAL_CACHE = tables
    return tables


def _stage_palette_labels():
    """19 entries of stage_palette_ptr (defw sNN_palette)."""
    labels = []
    in_ptr = False
    path = os.path.join(DATA_DIR, "stage_palettes.asm")
    for line in open(path):
        if line.startswith("stage_palette_ptr:"):
            in_ptr = True
            continue
        if not in_ptr:
            continue
        m = re.match(r"\s*defw\s+(\w+)", line)
        if m:
            labels.append(m.group(1))
            continue
        break
    return labels


def _bios_plus_hud(tables):
    pal = [(msx2_channel(r), msx2_channel(g), msx2_channel(b))
           for r, g, b in MSX2_DEFAULT_RGB]
    _apply_palette_overlay(pal, tables["hud_fixed_palette"])
    return pal


def _tileset_asm_palette(fname, data):
    """Playfield sheets use the stage palette; intro / HUD / portrait are special."""
    m = re.match(r"tileset_s(\d+)", fname)
    if m:
        stage = int(m.group(1))
        if data is not None:
            return vk_stage_palette(data, stage)
        tables = _asm_palette_tables()
        pal = _bios_plus_hud(tables)
        labels = _stage_palette_labels()
        if 0 <= stage < len(labels):
            _apply_palette_overlay(pal, tables[labels[stage]])
        return pal
    tables = _asm_palette_tables()
    if fname == "title_tiles.asm":
        if data is not None:
            return load_palette_table(data, 0x15F88)
        pal = [(0, 0, 0)] * 16
        _apply_palette_overlay(pal, tables["hud_fixed_palette"])
        return pal
    if fname == "intro_tiles.asm":
        if data is not None:
            return vk_intro_palette(data)
        pal = [(0, 0, 0)] * 16
        _apply_palette_overlay(pal, tables["hud_fixed_palette"])
        _apply_palette_overlay(pal, tables["intro_palette"])
        return pal
    if fname in ("hud_weapon_key_tiles.asm", "bonus_hud_tiles.asm",
                 "vendor_tiles.asm"):
        if data is not None:
            return vk_play_palette(data)
        pal = [(0, 0, 0)] * 16
        _apply_palette_overlay(pal, tables["title_extra_palette"])
        _apply_palette_overlay(pal, tables["hud_fixed_palette"])
        return pal
    if fname in ("dracula_portrait.asm", "dracula_portrait_parts.asm"):
        if data is not None:
            pal = vk_play_palette(data)
            _apply_palette_overlay(pal, load_palette_table(data, 0x15F6F))
            return pal
        pal = _bios_plus_hud(tables)
        _apply_palette_overlay(pal, tables["title_extra_palette"])
        return pal
    # Fallback: HUD-fixed then title extras (0xBF6F pink/flesh).
    if data is not None:
        pal = vk_play_palette(data)
        _apply_palette_overlay(pal, load_palette_table(data, 0x15F6F))
        return pal
    pal = _bios_plus_hud(tables)
    _apply_palette_overlay(pal, tables["title_extra_palette"])
    return pal


def _asm_tileset_files():
    names = [fn for fn in os.listdir(DATA_DIR)
             if fn.startswith("tileset_") and fn.endswith(".asm")]
    for extra in ("intro_tiles.asm", "title_tiles.asm", "bonus_hud_tiles.asm",
                  "hud_weapon_key_tiles.asm", "dracula_portrait.asm",
                  "dracula_portrait_parts.asm", "vendor_tiles.asm"):
        if extra not in names and os.path.isfile(os.path.join(DATA_DIR, extra)):
            names.append(extra)
    return sorted(names)


def parse_asm_tile8(path):
    """4bpp tiles in an asm file, driven by `; 0xXXXX  …` headers.

    `… tile …` is one 8x8 (32 bytes); `… 16x16 …` is one 16x16 (128 bytes,
    vram_blit_tile16).  `rest of …` prefixes and trailing incomplete tiles
    count as leftover so a continuation that starts mid-tile aligns to the
    first complete tile, not the file start.
    """
    cells, labels, sizes = [], [], []
    leftover = 0
    kind = None  # 8 or 16
    cpu = None
    pending = bytearray()

    def flush_incomplete():
        nonlocal leftover, pending, kind, cpu
        leftover += len(pending)
        pending = bytearray()
        kind = None
        cpu = None

    def emit_if_ready():
        nonlocal leftover, pending, kind, cpu
        need = 32 if kind == 8 else 128
        if kind is None or len(pending) < need:
            return
        raw = bytes(pending[:need])
        pending = bytearray(pending[need:])
        if kind == 8:
            cells.extend(tile_grids(raw, "tile8"))
        else:
            cells.extend(tile_grids(raw, "tile4"))
        labels.append("%04X" % cpu)
        sizes.append(kind)
        leftover += len(pending)
        pending = bytearray()
        kind = None
        cpu = None

    with open(path) as f:
        for line in f:
            th = _RE_TILE_HDR.match(line)
            if th:
                rest = th.group(2).strip().lower()
                if rest.startswith("rest of"):
                    flush_incomplete()
                    continue
                if "16x16" in rest:
                    flush_incomplete()
                    kind = 16
                    cpu = int(th.group(1), 16)
                    continue
                if "tile" in rest:
                    flush_incomplete()
                    kind = 8
                    cpu = int(th.group(1), 16)
                    continue
            if not _RE_DEFB.match(line):
                continue
            payload = line.split(";")[0]
            row = [int(hx, 16) for hx in _RE_HEXB.findall(payload)]
            if not row:
                continue
            if kind is None:
                leftover += len(row)
                continue
            pending.extend(row)
            emit_if_ready()
    leftover += len(pending)
    return cells, labels, leftover, sizes


def dump_asm_tilesets(data):
    """One sheet per tileset asm. Cell header = CPU address.

    Uniform 8x8 files stay a 16-column grid.  16x16 files (bonus HUD)
    use an 8-column (or 5-column) grid.  Mixed files stack an 8x8 band
    above a 16x16 band.
    """
    os.makedirs(TILESET_DIR, exist_ok=True)
    for fname in _asm_tileset_files():
        path = os.path.join(DATA_DIR, fname)
        cells, labels, leftover, sizes = parse_asm_tile8(path)
        if not cells:
            print("%-28s (no complete tiles)" % fname)
            continue
        pal = _tileset_asm_palette(fname, data)
        out = os.path.join(TILESET_DIR, os.path.splitext(fname)[0] + ".png")
        c8 = [c for c, s in zip(cells, sizes) if s == 8]
        l8 = [lab for lab, s in zip(labels, sizes) if s == 8]
        c16 = [c for c, s in zip(cells, sizes) if s == 16]
        l16 = [lab for lab, s in zip(labels, sizes) if s == 16]
        if c8 and not c16:
            cols8 = 8 if fname == "vendor_tiles.asm" else 16
            render_png(out, c8, pal, cols=cols8, labels=l8, size=8, scale=8)
        elif c16 and not c8:
            cols16 = 5 if fname == "bonus_hud_tiles.asm" else (
                4 if fname in (
                    "dracula_portrait_parts.asm",
                    "hud_weapon_key_tiles.asm",
                ) else 8)
            render_png(out, c16, pal, cols=cols16, labels=l16, size=16, scale=8)
        else:
            _stack_rgb(out, [
                render_png(None, c8, pal, cols=16, labels=l8, size=8, scale=8),
                render_png(None, c16, pal, cols=8, labels=l16, size=16, scale=8),
            ])
        extra = "  +%d leftover bytes" % leftover if leftover else ""
        rel = os.path.relpath(out, ROOT)
        if c16 and c8:
            desc = "%3d 8x8 + %2d 16x16" % (len(c8), len(c16))
        elif c16:
            desc = "%3d 16x16" % len(c16)
        else:
            desc = "%3d tiles" % len(c8)
        print("%-36s %s  %s%s" % (rel, desc, labels[0], extra))

if __name__ == "__main__":
    main()

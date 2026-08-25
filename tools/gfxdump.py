#!/usr/bin/env python3
"""Build the readable graphics catalogue in gfx/ from gfx/manifest.tsv.

For each manifest entry it decompresses the RLE stream(s) (via rledec), writes:
  gfx/<name>.bin  - the decompressed raw pixels (feed to tools/rleenc.py to
                    re-pack an edited version)
  gfx/<name>.txt  - ASCII-art preview (16x16 1bpp sprites or 4bpp tiles); this
                    is the definitive human-readable source
  gfx/<name>.png  - scaled PNG sheet of the same tiles, for extra clarity
and regenerates gfx/index.md summarising every entry.

manifest.tsv columns (tab-separated; '#' comment lines and blanks ignored):
  name    sources                 dest     kind      planes   notes
where 'sources' is a comma-separated list of hex ROM file offsets that are
decompressed and concatenated (each stream ends at its own 0x00), 'dest' is the
VRAM destination (informational), 'kind' is 'sprite16' or 'tile4', and 'planes'
is the number of consecutive 1bpp planes OR-combined into one visible multicolor
sprite (1 = plain monochrome). The .png composites planes; the .txt does not.

Usage:  tools/gfxdump.py            (run from the repo root)
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import rledec, gfxview, pngwrite

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROM = os.path.join(ROOT, "VampireKiller.rom")
GFX = os.path.join(ROOT, "gfx")

# Sheet PNG appearance.
SCALE = 6                       # pixels per source pixel
GAP = 2                         # gap (in scaled px) between tiles
BG = (0x20, 0x28, 0x30)         # canvas / gap colour
OFF = (0x30, 0x3a, 0x44)        # sprite "off" pixel (shows tile bounds)
FG = (0xe8, 0xe8, 0xe8)         # sprite "on" pixel (1-plane sprites)
# Illustrative colours for OR-combined sprite planes (NOT the game's real
# palette, which lives in the per-line sprite colour table). Index = plane
# bitmask: bit0 = plane 0 set, bit1 = plane 1 set, ...
PLANE_COLS = [OFF, (0x6f, 0xb8, 0xff), (0xe8, 0xe8, 0xe8), (0xff, 0xdd, 0x55),
              (0xff, 0x7a, 0x7a), (0x8a, 0xff, 0x9a), (0xc9, 0x8a, 0xff), FG]
# Generic 16-colour palette for 4bpp tile previews (index 0 = transparent-ish).
PAL4 = [(0x00, 0x00, 0x00), (0x20, 0x20, 0x20), (0x24, 0x6b, 0x3a), (0x4c, 0xa8, 0x5e),
        (0x55, 0x4c, 0xd8), (0x76, 0x71, 0xe6), (0xb5, 0x4a, 0x3f), (0x5c, 0xc8, 0xe6),
        (0xd8, 0x55, 0x4c), (0xf6, 0x8a, 0x82), (0xc8, 0xc0, 0x5e), (0xdc, 0xd4, 0x94),
        (0x3b, 0x8e, 0x33), (0xb5, 0x62, 0xb5), (0xcc, 0xcc, 0xcc), (0xff, 0xff, 0xff)]

# MSX2 palette encoding: port 9A gets (0rrr0bbb, 00000ggg), 3-bit channels.
# Expand 0-7 -> 0-255 the same way openMSX does.
def msx2_channel(n):
    n &= 7
    return (n << 5) | (n << 2) | (n >> 1)

def load_palette_table(data, file_off):
    """Parse an l4845h table: (index, rb, g)+ terminated by 0xFF. Missing
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
    8 fixed HUD/sprite colours at 0xBF88 (`sub_572eh`). Stage palettes overlay
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
    """l4845h only writes listed indices; omitted slots keep the previous RGB."""
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
    colours (`sub_572eh`), then that row of the 0xBEA7 table. Room entry then
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
    """Return a list of 16x16 grids of colour indices (sprite16: 0/1)."""
    grids = []
    if kind == "sprite16":
        step = 32
        for i in range(0, len(buf) - step + 1, step):
            rows = gfxview.sprite16_1bpp(buf[i:i + step])
            grids.append([[1 if ch == "#" else 0 for ch in r] for r in rows])
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

def combine_planes(grids, planes):
    """Group 'planes' consecutive 1bpp grids into one grid of plane-bitmask
    values (bit i set if plane i has a pixel there)."""
    cells = []
    for base in range(0, len(grids) - planes + 1, planes):
        cell = [[0] * 16 for _ in range(16)]
        for p in range(planes):
            g = grids[base + p]
            for y in range(16):
                for x in range(16):
                    if g[y][x]:
                        cell[y][x] |= (1 << p)
        cells.append(cell)
    return cells

def render_png(path, cells, palette, cols=8, labels=None, lab_scale=2, size=16):
    """Write a scaled contact sheet.  `labels` (optional) adds a dark band
    above each tile with a 3x5 bitmap id, same treatment as the minimap
    renderer in roomperm.py (`contact_sheet`).  `size` is the tile edge in
    source pixels (16 for HUD tiles, 64 for enemy composites)."""
    if not cells:
        return
    if labels:
        from roomperm import draw_text, LABEL_RGB
        lab_h = 5 * lab_scale + 4      # digit height + padding
    else:
        lab_h = 0
    rows_of = (len(cells) + cols - 1) // cols
    tile_s = size * SCALE
    cell_w = tile_s
    cell_h = lab_h + tile_s
    W = cols * cell_w + (cols + 1) * GAP
    H = rows_of * cell_h + (rows_of + 1) * GAP
    buf = bytearray(W * H * 3)
    for i in range(0, W * H):
        buf[i * 3], buf[i * 3 + 1], buf[i * 3 + 2] = BG

    def put(px, py, rgb):
        o = (py * W + px) * 3
        buf[o], buf[o + 1], buf[o + 2] = rgb

    for idx, grid in enumerate(cells):
        x0 = GAP + (idx % cols) * (cell_w + GAP)
        y0 = GAP + (idx // cols) * (cell_h + GAP)
        if labels and idx < len(labels) and labels[idx] is not None:
            draw_text(buf, W, x0 + 2, y0 + 2, str(labels[idx]), lab_scale, LABEL_RGB)
        ty = y0 + lab_h
        h = min(size, len(grid))
        w = min(size, len(grid[0]) if grid else 0)
        for y in range(h):
            for x in range(w):
                pix = grid[y][x]
                rgb = pix if isinstance(pix, tuple) else palette[pix]
                for dy in range(SCALE):
                    for dx in range(SCALE):
                        put(x0 + x * SCALE + dx, ty + y * SCALE + dy, rgb)
    pngwrite.write_rgb(path, W, H, bytes(buf))

def render_sheet(buf, kind, cols=8):
    lines = []
    if kind == "sprite16":
        size, step, fn = 16, 32, gfxview.sprite16_1bpp
    elif kind == "tile4":
        size, step, fn = 16, 128, lambda d: gfxview.tile_4bpp(d, 16)
    else:
        raise SystemExit("unknown kind %r" % kind)
    tiles = [fn(buf[i:i + step]) for i in range(0, len(buf) - step + 1, step)]
    for base in range(0, len(tiles), cols):
        group = tiles[base:base + cols]
        for r in range(size):
            lines.append("  ".join(g[r] for g in group))
        lines.append("")
    return "\n".join(lines)

def main():
    os.makedirs(GFX, exist_ok=True)
    data = open(ROM, "rb").read()
    manifest = os.path.join(GFX, "manifest.tsv")
    rows = []
    for raw in open(manifest):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        name, sources, dest, kind, planes, notes = (line.split("\t") + [""] * 6)[:6]
        planes = int(planes) if planes.strip() else 1
        srcs = [int(s, 0) for s in sources.split(",")]
        buf = bytearray()
        comp = 0
        for s in srcs:
            out, base, end = rledec.decompress(data, s, int(dest, 0))
            buf += out
            comp += end - s
        open(os.path.join(GFX, name + ".bin"), "wb").write(buf)
        header = ("# %s\n# sources: %s\n# vram dest: %s   kind: %s   planes: %d\n"
                  "# %d compressed bytes -> %d decompressed\n# %s\n\n"
                  % (name, sources, dest, kind, planes, comp, len(buf), notes))
        open(os.path.join(GFX, name + ".txt"), "w").write(header + render_sheet(buf, kind))

        grids = tile_grids(buf, kind)
        if kind == "sprite16" and planes > 1:
            cells = combine_planes(grids, planes)
            palette = PLANE_COLS
            pcols = 8
        elif kind == "sprite16":
            cells = grids
            palette = [OFF, FG]
            pcols = 8
        else:
            cells = grids
            palette = PAL4
            pcols = 8
        render_png(os.path.join(GFX, name + ".png"), cells, palette, pcols)
        rows.append((name, sources, dest, kind, planes, comp, len(buf), notes))
        print("%-22s %5d -> %5d bytes  %s x%d planes" % (name, comp, len(buf), kind, planes))

    with open(os.path.join(GFX, "index.md"), "w") as f:
        f.write("# Graphics catalogue\n\n")
        f.write("Generated by `tools/gfxdump.py` from `gfx/manifest.tsv`. Each entry has a\n")
        f.write("`.bin` (decompressed pixels), a `.txt` (definitive ASCII-art source) and a\n")
        f.write("`.png` (scaled preview). To mod a\n")
        f.write("sprite: edit the `.bin`, re-pack with `tools/rleenc.py`, and patch the\n")
        f.write("resulting stream into the ROM (the untouched original bytes stay in the\n")
        f.write("committed build, so `make verify` remains byte-exact until you patch).\n\n")
        f.write("| name | preview | sources (file offset) | vram dest | kind | planes | packed | raw | notes |\n")
        f.write("|------|---------|-----------------------|-----------|------|-------:|-------:|----:|-------|\n")
        for name, sources, dest, kind, planes, comp, raw, notes in rows:
            f.write("| %s | ![%s](%s.png) | `%s` | `%s` | %s | %d | %d | %d | %s |\n"
                    % (name, name, name, sources, dest, kind, planes, comp, raw, notes))

    dump_bonus_hud(data)
    dump_enemy_sheet(data)

# First *recognisable* pose (ix+0B) for entity_tbl types 1-22.
# Type 9's spawn state uses 0x26 (2-cell wait, legs only); the walk frame is 0x21.
# Type 9 is the red skeleton (fast, no throw). Type 16 shares that SAT layout
# but stage 14+ VRAM is the axe knight (throws). Colour 0x45 = overlay index 5.
# Type 14 is skipped by the SAT builder (0x644C); its tick writes SAT itself.
# Type 15's shared init writes 0x67 (type 13's shape); the sitting cannon is 0x6D.
# Type 17 intro is 0x56 (2-cell); standing 0x5B is SAT head+cape, torso is a 32x32 blit.
# Type 20 walk cycle is 0x33-0x38 (0x82 6-cell); 0x35 is a full stride, not the thin-waist 0x36.
# Type 21 walk cycle is 0x79/0x7A/0x7B (Frankenstein); 0x67 is type 24 (Igor).
ENEMY_SHAPE_ID = {
    1: 0x3D, 2: 0x0B, 3: 0x12, 4: 0x1A, 5: 0x3F,
    6: 0x50, 7: 0x16, 8: 0x71, 9: 0x21, 10: 0x05,
    11: 0x49, 12: 0x89, 13: 0x67, 14: None, 15: 0x6D,
    16: 0x5F, 17: 0x5B, 18: 0x4F, 19: 0x2B, 20: 0x35,
    21: 0x79, 22: 0x7C,
}
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
    9: [(13, 0), (13, 4), (13, 8), (13, 9)],
    11: [(7, 2), (7, 3), (7, 4), (8, 2), (8, 3), (13, 0)],
    12: [(7, 7), (7, 8), (8, 5), (8, 6)],
    14: [(11, 5), (12, 0), (12, 4), (12, 5)],
    16: [(14, 0), (14, 1), (14, 2), (15, 1)],
    17: [(18, 9)],
    18: [(3, 5), (16, 1), (16, 2)],
    19: [(6, 5)],
    20: [(9, 7)],
    21: [(12, 6)],
    22: [(15, 9)],
}
# Type 14 custom SAT (handler 0xAAD4): 4 columns of 2-plane 16x16.
# lab25h X offsets; lab15h pattern/colour pairs.
TYPE14_DX = (0xD0, 0xE0, 0xF0, 0x00)
TYPE14_SAT = (
    (0x80, 0x02), (0x84, 0x4C),
    (0x78, 0x02), (0x7C, 0x4C),
    (0x78, 0x02), (0x7C, 0x4C),
    (0x78, 0x02), (0x7C, 0x4C),
)
# 0x80/0x81/0x82 offset lists at l64d4h / l64dch / l64e0h (dy, dx) pairs.
SHAPE_OFS = {
    0x80: [(0xE0, 0xF8), (0xE0, 0xF8), (0xF0, 0xF8), (0xF0, 0xF8)],
    0x81: [(0xF1, 0xF8), (0xF1, 0xF8)],
    0x82: [(0xD1, 0xF8), (0xD1, 0xF8), (0xE1, 0xF8),
           (0xE1, 0xF8), (0xF1, 0xF8), (0xF1, 0xF8)],
}
ENEMY_CANVAS = 64
# Type 17 standing (0x5B): SAT is only the head (dy=-64) and cape/legs (dy=-16).
# The 32x32 middle is a SCREEN 5 LMMM (sub_ad87h / ladc3h) onto (X-16, Y=0x91),
# assembled from page-1 16x16s at Y=0xA0. PARKED: a s18r9 playfield crop at
# (64, 88) was title kana (Akumajo Dracula), not the cloak. Sheet is SAT-only
# until the real blit source is found.

def _s8(b):
    return b - 256 if b >= 128 else b

def _word(data, file_off):
    return data[file_off] | (data[file_off + 1] << 8)

def _cpu_file(seg, cpu, win):
    return seg * 0x2000 + (cpu - win)

def dump_enemy_sheet(data):
    """One labelled frame per entity_tbl type (1-22), composited from the
    seg6 shape stream + the 1bpp sprite patterns the per-room gfx script
    RLE-loads into VRAM 0xF800+."""
    cells = []
    vram_cache = {}
    for typ in range(1, 23):
        cells.append(_composite_enemy(data, typ, vram_cache))
    render_png(os.path.join(GFX, "enemy_sheet.png"), cells, None, cols=6,
               labels=[str(i) for i in range(1, 23)], size=ENEMY_CANVAS)
    print("enemy_sheet.png          entity types 1-22")

def _composite_enemy(data, typ, vram_cache):
    grid = [[BG] * ENEMY_CANVAS for _ in range(ENEMY_CANVAS)]
    ncells = data[_cpu_file(1, 0x605E, 0x6000) + typ]
    if typ == 14:
        parts, colors = _type14_parts()
    else:
        sid = ENEMY_SHAPE_ID.get(typ)
        if sid is None or not ncells:
            return grid
        parts = _parse_shape(data, sid, ncells)
        colors = _type_colors(data, typ, ncells)
        if typ == 17:
            # spawn table only colours 2 cells (intro 0x56). Standing 0x5B
            # fills all 8 from lad5ah (02 48 repeated) via sub_ad4ch.
            colors = [0x02, 0x48] * 4
    if not parts:
        return grid
    vram, stage, room = _vram_for_type(data, typ, parts, vram_cache)
    pal = vk_playfield_palette(data, stage, room)
    index = [[0] * ENEMY_CANVAS for _ in range(ENEMY_CANVAS)]
    dys = [p[0] for p in parts]
    dxs = [p[1] for p in parts]
    oy = 8 - min(dys)
    ox = 8 - min(dxs)
    if ox + max(dxs) + 16 > ENEMY_CANVAS:
        ox = max(0, ENEMY_CANVAS - 16 - max(dxs))
    if oy + max(dys) + 16 > ENEMY_CANVAS:
        oy = max(0, ENEMY_CANVAS - 16 - max(dys))
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
                if 0 <= yy < ENEMY_CANVAS and 0 <= xx < ENEMY_CANVAS:
                    if cc and index[yy][xx]:
                        index[yy][xx] |= idx
                    elif not cc or index[yy][xx] == 0:
                        index[yy][xx] = idx
    for y in range(ENEMY_CANVAS):
        for x in range(ENEMY_CANVAS):
            if index[y][x]:
                grid[y][x] = pal[index[y][x]]
    return grid

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

def _type14_parts():
    """Type 14 bypasses 0x644C; tick 0xAAD4 writes 8 SAT cells itself."""
    parts, colors = [], []
    for i, (pat, col) in enumerate(TYPE14_SAT):
        parts.append((0, _s8(TYPE14_DX[i // 2]), pat))
        colors.append(col)
    return parts, colors

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

def _load_script_vram(data, script_cpu):
    vram = bytearray(0x10000)
    if not script_cpu:
        return vram
    cpu = script_cpu
    for _ in range(80):
        if 0x8000 <= cpu < 0xA000:
            fo = _cpu_file(9, cpu, 0x8000)
        elif 0xA000 <= cpu < 0xC000:
            fo = _cpu_file(10, cpu, 0xA000)
        else:
            break
        cmd = data[fo]
        cpu += 1
        fo += 1
        if cmd == 0xFF:
            break
        if cmd == 0:
            src = _word(data, fo)
            dest = _word(data, fo + 2)
            cpu += 4
            src_off = _rle_src_file(src)
            if src_off is not None:
                try:
                    out, base, _end = rledec.decompress(data, src_off, dest)
                    for i, b in enumerate(out):
                        addr = base + i
                        if addr < 0x10000:
                            vram[addr] = b
                except Exception:
                    pass
        elif cmd == 1:
            src = _word(data, fo)
            cnt = data[fo + 2]
            dest = _word(data, fo + 3)
            cpu += 5
            _apply_sprite_conv(vram, src, cnt, dest)
        else:
            cpu += 6
    return vram

def _bitrev(b):
    r = 0
    for _ in range(8):
        r = (r << 1) | (b & 1)
        b >>= 1
    return r

def _apply_sprite_conv(vram, src, count, dest):
    """Replay sub_4745h / sub_4786h: bit-reverse 16-byte halves and copy
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

def dump_bonus_hud(data):
    """Uncompressed HUD bonus tiles (not in manifest.tsv — they are raw 4bpp,
    not RLE).  Two labelled sheets: ids 1-20 and ids 22-30."""
    pal = vk_play_palette(data)

    def cells_at(off, n):
        return tile_grids(data[off:off + n * 128], "tile4")

    ids_1_20 = cells_at(0x13000, 20)
    items = cells_at(0x13A00, 1) + cells_at(0xD9C8, 8)
    render_png(os.path.join(GFX, "bonus_hud_sheet.png"), ids_1_20, pal, cols=5,
               labels=[str(i) for i in range(1, 21)])
    render_png(os.path.join(GFX, "bonus_hud_items.png"), items, pal, cols=3,
               labels=[str(i) for i in range(22, 31)])
    print("bonus_hud_sheet.png      ids 1-20")
    print("bonus_hud_items.png      ids 22-30")

if __name__ == "__main__":
    main()

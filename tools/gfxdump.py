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

def render_png(path, cells, palette, cols=8):
    if not cells:
        return
    rows_of = (len(cells) + cols - 1) // cols
    tile_px = 16 * SCALE + GAP
    W = cols * tile_px + GAP
    H = rows_of * tile_px + GAP
    buf = bytearray(W * H * 3)
    for i in range(0, W * H):
        buf[i * 3], buf[i * 3 + 1], buf[i * 3 + 2] = BG

    def put(px, py, rgb):
        o = (py * W + px) * 3
        buf[o], buf[o + 1], buf[o + 2] = rgb

    for idx, grid in enumerate(cells):
        cx = (idx % cols) * tile_px + GAP
        cy = (idx // cols) * tile_px + GAP
        for y in range(16):
            for x in range(16):
                rgb = palette[grid[y][x]]
                for dy in range(SCALE):
                    for dx in range(SCALE):
                        put(cx + x * SCALE + dx, cy + y * SCALE + dy, rgb)
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

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Player-guide graphics (and stage-page inventories) for docs/manual/.

Imports roomperm / gfxdump. Does not write into gfx/.

  tools/guide_assets.py            (run from the repo root)
"""
from __future__ import annotations

import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gfxdump
import pngwrite
import roomperm

# roomperm.render_pixels / tileset_cells call gfxdump._tileset_file and
# gfxdump.NTILES, which gfxdump never exported. Patch locally rather than
# changing the technical dump tools.
gfxdump.NTILES = 0xBF


def _tileset_file(stage, cpu):
    """ROM file offset of a tileset pointer (page_tileset_banks + late)."""
    if cpu < 0x8000:
        bank, base = 4, 0x6000
    elif cpu < 0xA000:
        bank, base = (7 if stage >= 13 else 5), 0x8000
    else:
        bank, base = (8 if stage >= 13 else 6), 0xA000
    return bank * 0x2000 + (cpu - base)


gfxdump._tileset_file = _tileset_file

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "segments", "data")
MANUAL = os.path.join(ROOT, "docs", "manual")
ASSETS = os.path.join(MANUAL, "assets")
IMG = os.path.join(ASSETS, "images")
AUDIO = os.path.join(ASSETS, "audio")
STAGES_MD = os.path.join(MANUAL, "stages")

SCALE_ICON = 6
SCALE_MAP = 2
BG = (12, 14, 20)
GOLD = (212, 180, 90)
DOOR_RGB = (220, 40, 40)
SPOT_RGB = (64, 186, 176)
SPIKE_RGB = (180, 70, 70)

VENDOR_OFFER = {
    0: 0x0E, 1: 0x12, 2: 0x03, 3: 0x04, 4: 0x0A,
    5: 0x16, 6: 0x1E, 7: 0x1D, 8: 0x1B,
}
VENDOR_PRICE = {
    0x0E: (20, 15, 60), 0x12: (30, 20, 60), 0x03: (20, 10, 60),
    0x04: (20, 10, 80), 0x0A: (40, 20, 80), 0x16: (40, 15, 80),
    0x1E: (30, 10, 50), 0x1D: (20, 10, 80), 0x1B: (50, 30, 90),
}
SPAWN_BIT = {
    0: "zombie", 1: "merman-green", 2: "merman-red", 3: "hanging-bat",
    4: "flying-skull", 5: "ghost-head", 6: "roc",
}
OBJECT_SLUG = {
    0x05: "dog", 0x06: "pikeman", 0x09: "red-skeleton", 0x0A: "skull-pile",
    0x0B: "white-skeleton", 0x0C: "raven", 0x0D: "hunchback",
    0x0E: "bone-dragon", 0x10: "axe-knight", 0x12: "giant-bat",
    0x1F: "hanging-bat", 0x21: "merman-red", 0x18: "igor",
}
ENEMY_TITLE = {
    "zombie": "Zombie", "merman-green": "Green merman", "merman-red": "Red merman",
    "hanging-bat": "Hanging bat", "dog": "Dog", "pikeman": "Pikeman",
    "flying-skull": "Flying skull", "ghost-head": "Ghost head",
    "red-skeleton": "Red skeleton", "skull-pile": "Skull pile",
    "white-skeleton": "White skeleton", "raven": "Raven", "hunchback": "Hunchback",
    "bone-dragon": "Bone dragon", "roc": "Roc", "axe-knight": "Axe knight",
    "dracula": "Dracula", "giant-bat": "Giant bat", "medusa": "Medusa",
    "mummy": "Mummy", "frankenstein": "Frankenstein", "grim-reaper": "Grim Reaper",
    "igor": "Igor", "blob-blue": "Blue blob", "blob-red": "Red blob",
    "blob-white": "White blob", "spike-bars": "Spike bars",
}
ITEM_META = {
    1: ("small-heart", "Small heart"),
    2: ("large-heart", "Large heart"),
    3: ("red-shield", "Red shield"),
    4: ("yellow-shield", "Yellow shield"),
    5: ("white-cross", "White cross"),
    6: ("rosary", "Rosary"),
    7: ("small-orb", "Life orb"),
    8: ("blue-gem", "Blue gem"),
    9: ("sapphire-ring", "Sapphire ring"),
    10: ("hourglass", "Hourglass"),
    11: ("tipped-hourglass", "Tipped hourglass"),
    12: ("boots", "Boots"),
    13: ("wings", "Wings"),
    14: ("candle", "Candle"),
    15: ("map", "Map"),
    16: ("black-bible", "Black bible"),
    17: ("white-bible", "White bible"),
    18: ("lockpick", "Lockpick"),
    19: ("white-bag", "White money bag"),
    20: ("blue-bag", "Blue money bag"),
    21: ("slime", "Slime"),
    22: ("potion", "Potion"),
    23: ("yellow-key", "Yellow key"),
    24: ("white-key", "White key"),
    25: ("chest", "Chest"),
}
WEAPON_META = {
    0: ("leather-whip", "Leather whip"),
    1: ("chain-whip", "Chain whip"),
    2: ("knife", "Knife"),
    3: ("axe", "Axe"),
    4: ("cross", "Cross"),
    5: ("holy-water", "Holy water"),
}
WEAPON_BONUS = {0x1A: 1, 0x1B: 2, 0x1C: 3, 0x1D: 4, 0x1E: 5}
STAGE_BGM = [
    0x80, 0x80, 0x80, 0x80, 0x81, 0x81, 0x81, 0x82, 0x82, 0x82,
    0x85, 0x81, 0x81, 0x84, 0x84, 0x84, 0x83, 0x83, 0x85,
]
BGM_FILE = {
    0x80: "80_bgm_s00-03.wav", 0x81: "81_bgm_s04-06_11_12.wav",
    0x82: "82_bgm_s07-09.wav", 0x83: "83_bgm_s16-17.wav",
    0x84: "84_bgm_s13-15.wav", 0x85: "85_bgm_s10_18.wav",
    0x86: "86_bgm_boss_dracula.wav", 0x87: "87_bgm_boss.wav",
    0x88: "88_bgm_boss_dracula_portrait.wav", 0x89: "89_simon_death.wav",
    0x8A: "8A_enter_castle.wav", 0x8B: "8B_game_over.wav",
    0x8C: "8C_boss_defeated.wav", 0x8D: "8D_dracula_defeated.wav",
    0x8E: "8E_credits.wav",
}
BOSS = {
    3: ("giant-bat", "Giant Bat", 5),
    6: ("medusa", "Medusa", 5),
    9: ("mummy", "the Mummies", 7),
    12: ("frankenstein", "Frankenstein and Igor", 6),
    15: ("grim-reaper", "the Grim Reaper", 9),
    18: ("dracula", "Dracula", 9),
}
UNIQUE_NOTES = {
    0: "The courtyard door opens on its own — no white key.",
    6: "Room 1 hangs three spike bars from the arches. They are scenery, not enemies: you cannot whip them away. The falling stroke hits harder than the crawl back up.",
    8: "Rooms 4 and 7 loop vertically. Dropping here is not a pit; it dumps you onto the other floor of the loop.",
    10: "Water, and mermen who already stand on the platforms in rooms 6–8 (they do not climb out of the drink first).",
    12: "No up/down exits. Crouch on a floor pad, then tap up, to warp to its twin. The pairs are 0↔3, 1↔4, 2↔11, 5↔8, 7↔10.",
    15: "The door on the left of room 8 opens onto an isolated room 9 — the Reaper's chamber, not the next stage.",
    18: "The door on the left of room 8 is Dracula's chamber.",
}

BLOCK_CASTLE = bytes([
    0x01, 0x02, 0x01, 0x02,
    0x0A, 0x0B, 0x0A, 0x0B,
    0x01, 0x02, 0x01, 0x02,
    0x0A, 0x0B, 0x0A, 0x0B,
])
BLOCK_COURT = bytes([
    0x01, 0x02, 0x01, 0x02,
    0x09, 0x0B, 0x0A, 0x09,
    0x01, 0x02, 0x01, 0x02,
    0x09, 0x0B, 0x0A, 0x09,
])


def find_rom():
    for path in (
        os.path.join(ROOT, "references", "VampireKiller.rom"),
        os.path.join(ROOT, "VampireKiller.rom"),
    ):
        if os.path.isfile(path):
            return path
    sys.exit("need references/VampireKiller.rom (or VampireKiller.rom)")


def ensure_dirs():
    for sub in ("items", "weapons", "enemies", "hazards", "stages"):
        os.makedirs(os.path.join(IMG, sub), exist_ok=True)
    os.makedirs(AUDIO, exist_ok=True)
    os.makedirs(STAGES_MD, exist_ok=True)


def is_ink(px):
    if isinstance(px, tuple):
        return px != gfxdump.OFF and px != (0, 0, 0) and px != BG
    return px not in (0, None)


def crop_grid(grid, pad=1):
    h, w = len(grid), len(grid[0]) if grid else 0
    ys = [y for y in range(h) if any(is_ink(grid[y][x]) for x in range(w))]
    xs = [x for x in range(w) if any(is_ink(grid[y][x]) for y in range(h))]
    if not xs or not ys:
        return grid
    x0, x1 = max(0, xs[0] - pad), min(w, xs[-1] + 1 + pad)
    y0, y1 = max(0, ys[0] - pad), min(h, ys[-1] + 1 + pad)
    return [row[x0:x1] for row in grid[y0:y1]]


def to_rgb(grid, pal):
    out = []
    for row in grid:
        out.append([
            px if isinstance(px, tuple) else (pal[px] if px else BG)
            for px in row
        ])
    return out


def recolor(grid, mapping):
    return [[mapping.get(v, v) for v in row] for row in grid]


def write_icon(path, grid, pal=None, scale=SCALE_ICON):
    rgb = to_rgb(crop_grid(grid), pal or [(0, 0, 0)] * 16)
    if not rgb or not rgb[0]:
        return
    h, w = len(rgb), len(rgb[0])
    W, H = w * scale, h * scale
    buf = bytearray(bytes(BG) * (W * H))
    for y, row in enumerate(rgb):
        for x, col in enumerate(row):
            if col == gfxdump.OFF:
                col = BG
            for yy in range(scale):
                o = ((y * scale + yy) * W + x * scale) * 3
                for xx in range(scale):
                    buf[o:o + 3] = bytes(col)
                    o += 3
    pngwrite.write_rgb(path, W, H, bytes(buf))
    print("  " + os.path.relpath(path, ROOT))


def tiles16_by_label(asm_name):
    path = os.path.join(DATA, asm_name)
    cells, labels, leftover, sizes = gfxdump.parse_asm_tile8(path)
    out = {}
    ci = 0
    for lab, kind in zip(labels, sizes):
        if kind != 16:
            if kind == 8:
                ci += 1
            continue
        out[lab] = cells[ci]
        ci += 1
    # parse_asm_tile8 labels 16x16 by CPU address hex
    named = {}
    with open(path) as f:
        cpu = None
        stem = None
        for line in f:
            if line.startswith("bonus_hud_") or line.startswith("hud_") or line.startswith("candle_"):
                stem = line.split(":")[0].strip()
            th = gfxdump._RE_TILE_HDR.match(line)
            if th and "16x16" in th.group(2).lower():
                cpu = "%04X" % int(th.group(1), 16)
                if stem and cpu in out:
                    named[stem] = out[cpu]
                stem = None
    return named, out


def bonus_by_id(named):
    """bonus id -> 16x16 index grid."""
    table = {
        1: "bonus_hud_small_heart", 2: "bonus_hud_large_heart",
        3: "bonus_hud_red_shield", 4: "bonus_hud_yellow_shield",
        5: "bonus_hud_white_cross", 6: "bonus_hud_rosary",
        7: "bonus_hud_small_orb", 8: "bonus_hud_blue_gem",
        9: "bonus_hud_sapphire_ring", 10: "bonus_hud_hourglass",
        11: "bonus_hud_tipped_hourglass", 12: "bonus_hud_boots",
        13: "bonus_hud_wings", 14: "bonus_hud_candle",
        15: "bonus_hud_map", 16: "bonus_hud_black_bible",
        17: "bonus_hud_white_bible", 18: "bonus_hud_lockpick",
        19: "bonus_hud_white_bag", 20: "bonus_hud_blue_bag",
        22: "bonus_hud_potion",
        23: "hud_yellow_key", 24: "hud_white_key", 25: "hud_chest",
        0x1A: "hud_chain_whip", 0x1B: "hud_knife", 0x1C: "hud_axe",
        0x1D: "hud_cross", 0x1E: "hud_holy_water",
    }
    out = {}
    for bid, stem in table.items():
        if stem in named:
            out[bid] = named[stem]
    return out


def dump_icons(data, named):
    pal = gfxdump.vk_play_palette(data)
    by_id = bonus_by_id(named)
    for bid, (slug, title) in ITEM_META.items():
        grid = by_id.get(bid)
        if bid == 21:
            continue
        if grid is None:
            print("missing item tile", bid, slug)
            continue
        write_icon(os.path.join(IMG, "items", slug + ".png"), grid, pal)
    # leather: same HUD tile as the chain, white metal (index 14) -> peach
    chain = by_id.get(0x1A)
    if chain:
        leather = recolor(chain, {14: 1})
        write_icon(os.path.join(IMG, "weapons", "leather-whip.png"), leather, pal)
        write_icon(os.path.join(IMG, "weapons", "chain-whip.png"), chain, pal)
    for bid, slug in ((0x1B, "knife"), (0x1C, "axe"), (0x1D, "cross"),
                      (0x1E, "holy-water")):
        if bid in by_id:
            write_icon(os.path.join(IMG, "weapons", slug + ".png"), by_id[bid], pal)
    flame = named.get("candle_0")
    brazier = named.get("candle_2")
    if flame is not None:
        write_icon(os.path.join(IMG, "items", "candle-flame.png"), flame, pal)
    return by_id, pal, flame, brazier


def dump_enemies(data):
    types = list(range(1, 23)) + [0x18, 0x1A, 0x1B, 0x1C]
    cache = {}
    slug_of = {
        1: "zombie", 2: "merman-green", 3: "merman-red", 4: "hanging-bat",
        5: "dog", 6: "pikeman", 7: "flying-skull", 8: "ghost-head",
        9: "red-skeleton", 10: "skull-pile", 11: "white-skeleton", 12: "raven",
        13: "hunchback", 14: "bone-dragon", 15: "roc", 16: "axe-knight",
        17: "dracula", 18: "giant-bat", 19: "medusa", 20: "mummy",
        21: "frankenstein", 22: "grim-reaper", 0x18: "igor",
        0x1A: "blob-blue", 0x1B: "blob-red", 0x1C: "blob-white",
    }
    portraits = {}
    for typ in types:
        grid = gfxdump._composite_enemy(data, typ, cache)
        slug = slug_of[typ]
        write_icon(os.path.join(IMG, "enemies", slug + ".png"), grid)
        portraits[slug] = grid
        if typ == 0x1A:
            write_icon(os.path.join(IMG, "items", "slime.png"), grid)
    return portraits


def dump_vendor(data):
    pal = gfxdump.vk_play_palette(data)
    fo = gfxdump._cpu_file(10, 0xBDA7, 0xA000)
    src = data[fo:fo + 256]
    ptrs = [gfxdump._word(data, 0x1575 + i * 2) for i in range(16)]
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

    idle = assemble(fills[3])
    write_icon(os.path.join(IMG, "vendor.png"), idle, pal)
    return idle


def dump_hazards(data):
    pal = gfxdump.vk_playfield_palette(data, 6, 1)

    def frag(cpu, w, h):
        fo = gfxdump._cpu_file(9, cpu, 0x8000)
        return [[data[fo + y * (w // 2) + x // 2] >> 4 if x % 2 == 0
                 else data[fo + y * (w // 2) + x // 2] & 0x0F
                 for x in range(w)] for y in range(h)]

    link = frag(0x9A80, 8, 4)
    unit = frag(0x9A90, 8, 8)
    bar = [[0] * 32 for _ in range(12)]
    for y in range(4):
        for x in range(8):
            bar[y][12 + x] = link[y][x]
    for i in range(4):
        for y in range(8):
            for x in range(8):
                bar[4 + y][i * 8 + x] = unit[y][x]
    write_icon(os.path.join(IMG, "hazards", "spike-bars.png"), bar, pal)
    return bar


def parse_stream(seg14, ptr):
    off = ptr - 0x8000
    stages, room = [[]], []
    while 0 <= off < len(seg14):
        b = seg14[off]
        off += 1
        if b == 0x00:
            if room:
                stages[-1].append(room)
            break
        if b == 0xFF:
            if room:
                stages[-1].append(room)
                room = []
            stages.append([])
            continue
        if b == 0xFE:
            stages[-1].append(room)
            room = []
            continue
        attr = seg14[off]
        off += 1
        extra = None
        if attr == 0x7F:
            extra = seg14[off]
            off += 1
        room.append(((b & 0x0F), (b >> 4), attr, extra))
    return stages


def classify(attr, extra):
    hidden = extra is not None
    a = extra if hidden else attr
    hi6 = a >> 6
    if hi6 == 3:
        return "vendor", VENDOR_OFFER.get((a >> 2) & 0xF, 0), hidden
    if hi6 == 2:
        return "chest", a & 0x1F, hidden
    kind = (a >> 5) & 7
    bonus = a & 0x1F
    if kind == 0:
        return "floor", bonus, hidden
    if kind == 1:
        return "candle", bonus, hidden
    if kind == 3:
        return "block", bonus, hidden
    return "other", bonus, hidden


def scenery_for_stage(rom, stage):
    seg14 = rom.rom[0x1C000:0x1E000]
    if stage == 0:
        stages = parse_stream(seg14, 0x800C)
        return stages[0] if stages else []
    hub = (stage - 1) // 3
    idx = (stage - 1) % 3
    to = (0x8000 - 0x8000) + 2 * hub
    ptr = seg14[to] | (seg14[to + 1] << 8)
    stages = parse_stream(seg14, ptr)
    if idx >= len(stages):
        return []
    return stages[idx]


def spawn_mask(rom, stage, room):
    seg14 = rom.rom[0x1C000:0x1E000]
    to = (0x85A6 - 0x8000) + 2 * stage
    ptr = seg14[to] | (seg14[to + 1] << 8)
    off = ptr - 0x8000 + room
    if 0 <= off < len(seg14):
        return seg14[off]
    return 0


def blit_rgb(buf, W, H, x0, y0, rgb_grid, scale, skip=None):
    skip = skip or {gfxdump.OFF, BG, (0, 0, 0)}
    for y, row in enumerate(rgb_grid):
        for x, col in enumerate(row):
            if col in skip:
                continue
            for yy in range(scale):
                py = y0 + y * scale + yy
                if not 0 <= py < H:
                    continue
                for xx in range(scale):
                    px = x0 + x * scale + xx
                    if not 0 <= px < W:
                        continue
                    o = (py * W + px) * 3
                    buf[o:o + 3] = bytes(col)


def outline_rect(buf, W, H, x0, y0, w, h, rgb, t=2):
    for i in range(t):
        for x in range(x0, x0 + w):
            for py in (y0 + i, y0 + h - 1 - i):
                if 0 <= py < H and 0 <= x < W:
                    o = (py * W + x) * 3
                    buf[o:o + 3] = bytes(rgb)
        for y in range(y0, y0 + h):
            for px in (x0 + i, x0 + w - 1 - i):
                if 0 <= y < H and 0 <= px < W:
                    o = (y * W + px) * 3
                    buf[o:o + 3] = bytes(rgb)


def blit_badge(buf, W, H, x0, y0, rgb_grid, scale):
    """Item icon centred in a 16x16 (game px) filled circle."""
    d = 16 * scale
    fill, rim = (10, 12, 18), GOLD
    r = (d - 1) * 0.5
    r2, rim2 = r * r, (r - max(1.5, scale * 0.85)) ** 2
    for yy in range(d):
        dy = yy - r
        for xx in range(d):
            dist = (xx - r) * (xx - r) + dy * dy
            if dist > r2:
                continue
            px, py = x0 + xx, y0 + yy
            if not (0 <= px < W and 0 <= py < H):
                continue
            o = (py * W + px) * 3
            buf[o:o + 3] = bytes(rim if dist > rim2 else fill)
    if not rgb_grid or not rgb_grid[0]:
        return
    ih, iw = len(rgb_grid), len(rgb_grid[0])
    tw, th = iw * scale, ih * scale
    ix = x0 + (d - tw) // 2
    iy = y0 + (d - th) // 2
    skip = {gfxdump.OFF, BG, (0, 0, 0)}
    for y, row in enumerate(rgb_grid):
        for x, col in enumerate(row):
            if col in skip:
                continue
            dx = ix + x * scale + (scale - 1) * 0.5 - (x0 + r)
            dy = iy + y * scale + (scale - 1) * 0.5 - (y0 + r)
            if dx * dx + dy * dy > r2:
                continue
            for yy in range(scale):
                py = iy + y * scale + yy
                if not 0 <= py < H:
                    continue
                for xx in range(scale):
                    px = ix + x * scale + xx
                    if 0 <= px < W:
                        o = (py * W + px) * 3
                        buf[o:o + 3] = bytes(col)


def cell_px(cx, cy, scale):
    """Scenery cell (16px) -> pixel in the cropped playfield buffer.

    scenery_pos_xy stores (X,Y)=(cx,cy)*16. map_cell_at drops the 16px HUD
    margin before the nametable row, so a naive (Y - HUD) blit sits one
    cell too low — inside the floor the object stands on.
    """
    nt_row = cy * 2 - 2
    return cx * 16 * scale, (nt_row - roomperm.PLAY_TOP) * 8 * scale


def stamp_block(rom, buf, W, H, stage, room, cx, cy, scale):
    tiles = roomperm.playfield_atlas(rom, stage, room)
    pal = gfxdump.vk_playfield_palette(rom.rom, stage, room)
    ids = BLOCK_COURT if stage == 0 else BLOCK_CASTLE
    tw = 8 * scale
    x0, y0 = cell_px(cx, cy, scale)
    for i, tid in enumerate(ids):
        tr, tc = divmod(i, 4)
        cell = roomperm.nametable_cell(tiles, tid)
        px, py = x0 + tc * tw, y0 + tr * tw
        for y in range(8):
            for x in range(8):
                col = pal[cell[y][x] & 15]
                for yy in range(scale):
                    for xx in range(scale):
                        qx, qy = px + x * scale + xx, py + y * scale + yy
                        if 0 <= qx < W and 0 <= qy < H:
                            o = (qy * W + qx) * 3
                            buf[o:o + 3] = bytes(col)
    outline_rect(buf, W, H, x0, y0, 32 * scale, 32 * scale, GOLD, t=max(2, scale))


def icon_rgb(grid, pal):
    return to_rgb(crop_grid(grid, pad=0), pal)


def render_annotated(rom, data, stage, by_id, pal, enemy_grids,
                     spike_grid=None, candle=None, brazier=None):
    n = roomperm.minimap_room_count(rom, stage)
    scenery = scenery_for_stage(rom, stage)
    entry = roomperm.door_table_entry(rom, stage)
    spots = [s for s in roomperm.parse_spots(rom) if s["stage"] == stage]
    stand = brazier if stage == 0 else candle
    images = []
    for col in range(n):
        grid = roomperm.decode_room(rom, stage, col)
        W, H, raw = roomperm.render_pixels(rom, grid, stage, col, SCALE_MAP)
        buf = bytearray(raw)
        recs = scenery[col] if col < len(scenery) else []
        for cx, cy, attr, extra in recs:
            kind, bonus, hidden = classify(attr, extra)
            x0, y0 = cell_px(cx, cy, SCALE_MAP)
            g = by_id.get(bonus)
            if kind == "block":
                stamp_block(rom, buf, W, H, stage, col, cx, cy, SCALE_MAP)
                if g is not None:
                    blit_badge(buf, W, H, x0 + 8 * SCALE_MAP, y0 + 8 * SCALE_MAP,
                               icon_rgb(g, pal), SCALE_MAP)
            elif kind == "candle":
                if stand is not None:
                    blit_rgb(buf, W, H, x0, y0, icon_rgb(stand, pal), SCALE_MAP)
                if g is not None and bonus:
                    bx = x0 + 16 * SCALE_MAP
                    if bx + 16 * SCALE_MAP > W:
                        bx = x0 - 16 * SCALE_MAP
                    blit_badge(buf, W, H, bx, y0, icon_rgb(g, pal), SCALE_MAP)
            elif kind == "chest":
                if 25 in by_id:
                    blit_rgb(buf, W, H, x0, y0, icon_rgb(by_id[25], pal), SCALE_MAP)
                if g is not None:
                    bx = x0 + 16 * SCALE_MAP
                    if bx + 16 * SCALE_MAP > W:
                        bx = x0 - 16 * SCALE_MAP
                    blit_badge(buf, W, H, bx, y0, icon_rgb(g, pal), SCALE_MAP)
            elif kind == "floor":
                if g is not None:
                    blit_badge(buf, W, H, x0, y0, icon_rgb(g, pal), SCALE_MAP)
            elif kind == "vendor":
                if g is not None:
                    blit_badge(buf, W, H, x0, y0, icon_rgb(g, pal), SCALE_MAP)
                else:
                    outline_rect(buf, W, H, x0, y0, 16 * SCALE_MAP, 16 * SCALE_MAP,
                                 (200, 200, 240), t=2)
        for sid, bit7, ox, oy in roomperm.decode_objects(rom, stage, col):
            slug = OBJECT_SLUG.get(sid)
            eg = enemy_grids.get(slug) if slug else None
            x0 = ox * 8 * SCALE_MAP
            y0 = (oy - roomperm.PLAY_TOP) * 8 * SCALE_MAP
            if eg:
                rgb = to_rgb(crop_grid(eg, pad=0), None)
                # shrink tall bosses: blit at 1:1 source pixel inside scale-2 map
                blit_rgb(buf, W, H, x0, y0, rgb, 1)
            else:
                outline_rect(buf, W, H, x0, y0, 16 * SCALE_MAP, 16 * SCALE_MAP,
                             (70, 120, 210), t=2)
        for rect in roomperm.door_table_rects(entry, col):
            dx, dy, dw, dh = rect[:4]
            outline_rect(buf, W, H,
                         dx * 8 * SCALE_MAP,
                         (dy - roomperm.PLAY_TOP) * 8 * SCALE_MAP,
                         dw * 8 * SCALE_MAP, dh * 8 * SCALE_MAP, DOOR_RGB, t=2)
        for tx, dy, dw, dh, dest in roomperm.spot_table_rects(
                spots, stage, col, grid):
            sx = tx * 8 * SCALE_MAP
            sy = (dy - roomperm.PLAY_TOP) * 8 * SCALE_MAP
            outline_rect(buf, W, H, sx, sy,
                         dw * 8 * SCALE_MAP, dh * 8 * SCALE_MAP, SPOT_RGB, t=2)
            tw = len(str(dest)) * 4 * SCALE_MAP
            th = 5 * SCALE_MAP
            pad = SCALE_MAP
            tx_text = sx + dw * 8 * SCALE_MAP + 3 * SCALE_MAP
            if tx_text + tw + pad > W:
                tx_text = max(pad, sx - tw - 3 * SCALE_MAP)
            ty_text = sy + max(0, (dh * 8 * SCALE_MAP - th) // 2)
            bx0, by0 = tx_text - pad, ty_text - pad
            bw, bh = tw + 2 * pad, th + 2 * pad
            for yy in range(bh):
                py = by0 + yy
                if not 0 <= py < H:
                    continue
                for xx in range(bw):
                    px = bx0 + xx
                    if 0 <= px < W:
                        o = (py * W + px) * 3
                        buf[o:o + 3] = bytes((10, 12, 18))
            roomperm.draw_text(buf, W, tx_text, ty_text, str(dest),
                               SCALE_MAP, SPOT_RGB)
        if stage == 6 and col == 1 and spike_grid is not None:
            pal6 = gfxdump.vk_playfield_palette(rom.rom, 6, 1)
            rgb = icon_rgb(spike_grid, pal6)
            y0 = (0x60 - roomperm.PLAY_TOP * 8) * SCALE_MAP
            for x in (0x3C, 0x7C, 0xBC):
                blit_rgb(buf, W, H, x * SCALE_MAP, y0, rgb, SCALE_MAP)
        images.append((W, H, bytes(buf)))
    pos, gw, gh = roomperm.layout(rom, stage, n)
    W, H, sheet = roomperm.contact_sheet(images, pos, gw, gh, gap=8,
                                         bg=(24, 26, 34), lab_scale=2)
    path = os.path.join(IMG, "stages", "s%02d.png" % stage)
    pngwrite.write_rgb(path, W, H, sheet)
    print("  " + os.path.relpath(path, ROOT))


def copy_audio():
    n = 0
    for folder in ("music", "sfx"):
        src = os.path.join(ROOT, folder)
        if not os.path.isdir(src):
            continue
        for name in os.listdir(src):
            if name.endswith(".wav"):
                shutil.copy2(os.path.join(src, name), os.path.join(AUDIO, name))
                n += 1
    print("audio: %d wavs -> docs/manual/assets/audio/" % n)


def item_slug(bonus):
    if bonus in WEAPON_BONUS:
        return WEAPON_META[WEAPON_BONUS[bonus]][0]
    if bonus in ITEM_META:
        return ITEM_META[bonus][0]
    return None


def item_href(bonus):
    if bonus in WEAPON_BONUS:
        slug, title = WEAPON_META[WEAPON_BONUS[bonus]]
        return "/manual/weapons/#" + slug, title, "weapons", slug
    if bonus in ITEM_META:
        slug, title = ITEM_META[bonus]
        return "/manual/items/#" + slug, title, "items", slug
    return None


def portrait_md(kind, slug, title, href):
    return (
        '{%% include portrait.html kind="%s" slug="%s" name="%s" href="%s" %%}'
        % (kind, slug, title, href)
    )


def emit_stage_page(rom, stage, scenery):
    n = roomperm.minimap_room_count(rom, stage)
    items, weapons, enemies = {}, {}, {}
    vendors = []
    for col, recs in enumerate(scenery):
        for cx, cy, attr, extra in recs:
            kind, bonus, hidden = classify(attr, extra)
            if kind == "vendor":
                href = item_href(bonus)
                vendors.append((col, bonus, href))
            elif bonus:
                href = item_href(bonus)
                if href:
                    path, title, kind_dir, slug = href
                    if kind_dir == "weapons":
                        weapons[slug] = (title, path, kind_dir)
                    else:
                        items[slug] = (title, path, kind_dir)
        mask = spawn_mask(rom, stage, col)
        for bit, slug in SPAWN_BIT.items():
            if mask & (1 << bit):
                enemies.setdefault(slug, set()).add(col)
        for sid, bit7, ox, oy in roomperm.decode_objects(rom, stage, col):
            slug = OBJECT_SLUG.get(sid)
            if slug:
                enemies.setdefault(slug, set()).add(col)
    if stage in BOSS:
        enemies.setdefault(BOSS[stage][0], set()).add(BOSS[stage][2])
        if stage == 12:
            enemies.setdefault("igor", set()).add(6)
    if stage == 6:
        enemies.setdefault("spike-bars", set()).add(1)

    title = "Courtyard" if stage == 0 else "Stage %02d" % stage
    if stage in BOSS:
        title += " — " + BOSS[stage][1]
    lines = [
        "---",
        "layout: default",
        "title: %s" % title,
        "permalink: /manual/stages/%02d/" % stage,
        "---",
        "",
        "# %s" % title,
        "",
    ]
    note = UNIQUE_NOTES.get(stage)
    if note:
        lines += [note, ""]
    lines += [
        '<p class="stage-map">',
        '<img src="{{ \'/manual/assets/images/stages/s%02d.png\' | relative_url }}" alt="Stage %02d map">' % (stage, stage),
        "</p>",
        "",
        "## Music",
        "",
        '<audio controls src="{{ \'/manual/assets/audio/%s\' | relative_url }}"></audio>' % BGM_FILE[STAGE_BGM[stage]],
        "",
    ]
    if items:
        lines += ["## Items", "", '<div class="roster">']
        for slug, (name, path, kind) in sorted(items.items()):
            lines.append(portrait_md(kind, slug, name, path))
        lines += ["</div>", ""]
    if weapons:
        lines += ["## Weapons", "", '<div class="roster">']
        for slug, (name, path, kind) in sorted(weapons.items()):
            lines.append(portrait_md(kind, slug, name, path))
        lines += ["</div>", ""]
    if enemies:
        lines += ["## Enemies", "", '<div class="roster">']
        for slug in sorted(enemies, key=lambda s: ENEMY_TITLE.get(s, s)):
            kind = "hazards" if slug == "spike-bars" else "enemies"
            name = ENEMY_TITLE.get(slug, slug)
            rooms = ", ".join(str(r) for r in sorted(enemies[slug]))
            href = "/manual/bestiary/#" + slug
            extra = " rooms " + rooms if len(enemies[slug]) <= 8 else ""
            lines.append(portrait_md(kind, slug, name + extra, href))
        lines += ["</div>", ""]
        lines.append("Wanderers (edge spawns) and placed creatures share this list. Room numbers match the map labels.")
        lines.append("")
    if vendors:
        lines += ["## Vendors", "", "Heart prices: normal / with the white bible / with the black bible.", ""]
        for col, bonus, href in vendors:
            if not href:
                continue
            path, name, kind, slug = href
            prices = VENDOR_PRICE.get(bonus, ("?", "?", "?"))
            lines.append(
                "- Room %d: %s — **%s / %s / %s** hearts"
                % (col, portrait_md(kind, slug, name, path), prices[0], prices[1], prices[2])
            )
        lines.append("")
    if stage in BOSS:
        slug, bname, room = BOSS[stage]
        lines += [
            "## Boss",
            "",
            "Room %d. Pick up the orb when it drops if you want a full life refill before the next stage." % room,
            "",
            '<div class="roster">',
            portrait_md("enemies", slug, bname, "/manual/bestiary/#" + slug),
            "</div>",
            "",
        ]
    path = os.path.join(STAGES_MD, "%02d.md" % stage)
    open(path, "w").write("\n".join(lines))
    print("  " + os.path.relpath(path, ROOT))


def main():
    ensure_dirs()
    rom_path = find_rom()
    data = open(rom_path, "rb").read()
    rom = roomperm.Rom(rom_path)
    print("icons")
    named_b, _ = tiles16_by_label("bonus_hud_tiles.asm")
    named_h, _ = tiles16_by_label("hud_weapon_key_tiles.asm")
    named = {}
    named.update(named_b)
    named.update(named_h)
    by_id, pal, candle, brazier = dump_icons(data, named)
    print("enemies")
    enemy_grids = dump_enemies(data)
    print("vendor / hazards")
    dump_vendor(data)
    spike_grid = dump_hazards(data)
    blob = enemy_grids.get("blob-blue")
    if blob is not None:
        by_id[21] = blob
    print("stage maps")
    for stage in range(19):
        scenery = scenery_for_stage(rom, stage)
        render_annotated(rom, data, stage, by_id, pal, enemy_grids, spike_grid,
                         candle, brazier)
        emit_stage_page(rom, stage, scenery)
    copy_audio()
    print("done")


if __name__ == "__main__":
    main()

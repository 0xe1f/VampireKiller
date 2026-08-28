#!/usr/bin/env python3
"""One-shot: dump identified ROM blobs to labeled .asm (Metal Gear-style).

Reads VampireKiller.rom (run `make` first).  The generated files are the assemble
source; the ROM is not needed to *build*, only to regenerate this dump.

  python3 tools/emit_identified_data.py
"""
from __future__ import annotations

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROM_PATH = os.path.join(ROOT, "VampireKiller.rom")
DATA = os.path.join(ROOT, "segments", "data")
SEGS = os.path.join(ROOT, "segments")

# rledec.py lives in tools/disasm/.
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "disasm"))
from rledec import decompress  # noqa: E402

COLS = 16
TILE = 32
TILE16 = 128  # vram_blit_tile16: 16 rows of 8 bytes
NTILES = 0xBF
TILESET_BYTES = NTILES * TILE  # 0x17E0

# Bonus HUD 16x16s (seg9 0x9000): ids 1-20 then potion (id 22).  Labels
# match collect_bonus handlers with a bonus_hud_ prefix so they don't
# collide.  Id 21 (slime) has no tile here.  HUD init blits 20 icons to
# Y=0x50, then potion to (X=80, Y=96).
BONUS_HUD_16X16 = [
    (0x9000, "bonus_hud_small_heart", "bonus 0x01"),
    (0x9080, "bonus_hud_large_heart", "bonus 0x02"),
    (0x9100, "bonus_hud_red_shield", "bonus 0x03"),
    (0x9180, "bonus_hud_yellow_shield", "bonus 0x04"),
    (0x9200, "bonus_hud_white_cross", "bonus 0x05"),
    (0x9280, "bonus_hud_rosary", "bonus 0x06"),
    (0x9300, "bonus_hud_small_orb", "bonus 0x07"),
    (0x9380, "bonus_hud_blue_gem", "bonus 0x08"),
    (0x9400, "bonus_hud_sapphire_ring", "bonus 0x09"),
    (0x9480, "bonus_hud_hourglass", "bonus 0x0A"),
    (0x9500, "bonus_hud_tipped_hourglass", "bonus 0x0B"),
    (0x9580, "bonus_hud_boots", "bonus 0x0C"),
    (0x9600, "bonus_hud_wings", "bonus 0x0D"),
    (0x9680, "bonus_hud_candle", "bonus 0x0E"),
    (0x9700, "bonus_hud_map", "bonus 0x0F"),
    (0x9780, "bonus_hud_black_bible", "bonus 0x10"),
    (0x9800, "bonus_hud_white_bible", "bonus 0x11"),
    (0x9880, "bonus_hud_lockpick", "bonus 0x12"),
    (0x9900, "bonus_hud_white_bag", "bonus 0x13"),
    (0x9980, "bonus_hud_blue_bag", "bonus 0x14"),
    (0x9A00, "bonus_hud_potion", "bonus 0x16"),
]

# First-tile CPU of each section comment in bonus_hud_tiles.asm.
BONUS_HUD_GROUPS = [
    (0x9000, "hearts"),
    (0x9100, "shields"),
    (0x9200, "white cross / rosary"),
    (0x9300, "life orb / gems"),
    (0x9480, "hourglasses"),
    (0x9580, "boots / wings"),
    (0x9680, "candle / map"),
    (0x9780, "bibles"),
    (0x9880, "lockpick"),
    (0x9900, "money bags"),
    (0x9A00, "potion"),
]

# HUD init copy (seg0 after page_tileset_banks): 8 x 16x16 item icons at
# 0xB9C8 -> VRAM Y=0x60 X=96 (bonus 0x17-0x1E), then 4 candle flames at
# 0xBDC8 -> Y=0x70 (playfield, l8991h A=0..3).  Each entry is one 16x16.
HUD_16X16 = [
    (0xB9C8, "hud_yellow_key", "bonus 0x17"),
    (0xBA48, "hud_white_key", "bonus 0x18"),
    (0xBAC8, "hud_chest", "bonus 0x19"),
    (0xBB48, "hud_chain_whip", "bonus 0x1A"),
    (0xBBC8, "hud_knife", "bonus 0x1B"),
    (0xBC48, "hud_axe", "bonus 0x1C"),
    (0xBCC8, "hud_cross", "bonus 0x1D"),
    (0xBD48, "hud_holy_water", "bonus 0x1E"),
    (0xBDC8, "candle_0", "playfield flame 0 (l8991h A=0, Y=0x70)"),
    (0xBE48, "candle_1", "playfield flame 1"),
    (0xBEC8, "candle_2", "playfield flame 2"),
    (0xBF48, "candle_3", "playfield flame 3"),
]

# Seg6 SAT layout after the s10 tileset tail: word[shape id] -> stream.
# Packed against the first stream; HUD tiles start at 0xB9C8.
ACTOR_SHAPE_CPU = 0xB473
ACTOR_SHAPE_HUD = 0xB9C8  # hud_weapon_key_tiles
# 0x80/81/82: one pattern byte per slot of the fixed dy/dx lists in actor_sat_build.
SHAPE_PREFIX_NPAT = {0x80: 4, 0x81: 2, 0x82: 6}


def load_rom() -> bytes:
    with open(ROM_PATH, "rb") as f:
        data = f.read()
    if len(data) != 0x20000:
        sys.exit("expected 128 KiB ROM at %s (got %d)" % (ROM_PATH, len(data)))
    return data


def bank(rom: bytes, n: int) -> bytes:
    return rom[n * 0x2000 : (n + 1) * 0x2000]


def defb_lines(buf: bytes) -> list[str]:
    lines = []
    for i in range(0, len(buf), COLS):
        chunk = buf[i : i + COLS]
        lines.append("\tdefb " + ",".join("0x%02x" % b for b in chunk))
    return lines


def bits_byte(b: int) -> str:
    """One 8px 1bpp row; MSB = left. Required form for every 1bpp sheet."""
    return "%%%s" % format(b, "08b")


def append_1bpp_glyph(lines: list[str], rows: bytes, comment: str) -> None:
    """One 8x8 1bpp glyph as 8 binary rows. comment is the hex id / note."""
    lines.append("; %s" % comment)
    for b in rows:
        lines.append("\tdefb %s" % bits_byte(b))
    lines.append("")


def emit_rle_1bpp(packed: bytes) -> list[str]:
    """Packed sprite RLE with pixel payloads as binary rows.

    Control bytes stay hex (run count, 0x80|n literal header, 0x00 end).
    Each payload byte is one 8px row (MSB=left), VRAM order TL/BL/TR/BR
    per 16x16 cell.  Byte-exact: this is the original packed stream.
    """
    lines: list[str] = []
    p = 0
    vram = 0
    while p < len(packed):
        c = packed[p]
        p += 1
        if c == 0x00:
            lines.append("\tdefb 0x00")
            break
        if c == 0x80:
            lo, hi = packed[p], packed[p + 1]
            p += 2
            lines.append(
                "\tdefb 0x80, 0x%02x, 0x%02x  ; VRAM 0x%02X%02X" % (lo, hi, hi, lo)
            )
            vram = 0
            continue
        if vram and vram % 32 == 0:
            lines.append("; 16x16 +0x%02X" % vram)
        if c & 0x80:
            n = c & 0x7F
            lines.append("\tdefb 0x%02x" % c)
            for _ in range(n):
                b = packed[p]
                p += 1
                lines.append("\tdefb %s" % bits_byte(b))
                vram += 1
        else:
            b = packed[p]
            p += 1
            lines.append("\tdefb 0x%02x, %s" % (c, bits_byte(b)))
            vram += c
    if p != len(packed):
        raise ValueError("RLE parse left %d bytes" % (len(packed) - p))
    return lines


def pix4_row(row: bytes) -> str:
    """One SCREEN 5 pixel-row (4 bytes = 8px, 8 bytes = 16px; high nibble = left)."""
    return "\tdefb " + ",".join("0x%02x" % b for b in row)


# HUD/title font: 48 x 8x8 1bpp at seg8 0xBD80 (ASCII '0'..'_').
# title_load_tiles' 0x59 English glyphs end exactly here; the old 4bpp dump
# kept walking and labelled these "en tile 0x59+".
HUD_FONT_CPU = 0xBD80
HUD_FONT_N = 48
HUD_FONT_NOTES = {
    ":": "  (face)",
    "[": "  (all-1s; hud_font_load blits ink 0 to (0,0) for space)",
    "^": "  (heart left)",
    "_": "  (heart right)",
}


def emit_hud_font(rom: bytes) -> None:
    """48 1bpp HUD glyphs + the 8x8 4bpp follow-on at 0xBF00."""
    b8 = bank(rom, 8)
    raw = b8[0x1D80:0x1F00]
    assert len(raw) == HUD_FONT_N * 8
    lines = [
        "; HUD / title font (seg8 0xBD80): 48 x 8x8 1bpp glyphs, ASCII '0'..'_'.",
        "; HUD/title strings are vk (ASCII-0x10); space is 0x00 (copies the",
        "; ink-0 blit of hud_font_solid at VRAM (0,0)).  hud_font_load",
        "; (seg0 0x53BD) expands these via glyph_blit_run to page 1 at Y=0x40,",
        "; ink 0x0E.  Drawing is HMMM from that atlas (hud_glyph_blit, Y += 0x38).",
        "; Each defb is one row, MSB = left pixel.  Not the credits font.",
        "; Preview: gfx/fonts/font_hud.png.  Source: data/font_hud.asm.",
        "hud_font:",
        "",
    ]
    for i in range(HUD_FONT_N):
        cpu = HUD_FONT_CPU + i * 8
        ch = chr(0x30 + i)
        note = HUD_FONT_NOTES.get(ch, "")
        if ch == "'":
            lines.append("; \"'\"%s" % note)
        else:
            lines.append("; '%s'%s" % (ch, note))
        if cpu == 0xBED8:
            lines.append("hud_font_solid:")
        for b in raw[i * 8 : (i + 1) * 8]:
            lines.append("\tdefb %s" % bits_byte(b))
        lines.append("")
    tile = b8[0x1F00:0x1F20]
    assert len(tile) == TILE
    lines.append("; 0xBF00  one 8x8 4bpp tile (vram_blit_tile_run dest 0xA440).")
    lines.append("hud_tile_bf00:  ; 0xBF00")
    for r in range(8):
        lines.append(pix4_row(tile[r * 4 : r * 4 + 4]))
    write_lines(os.path.join(DATA, "font_hud.asm"), lines)


CREDITS_FONT_CPU = 0x8824
CREDITS_FONT_CHARS = "0123456789.':," + "ABCDEFGHIJKLMNOPQRSTUVWXYZ"


def emit_credits_font(rom: bytes) -> None:
    """40 1bpp ending-credits glyphs at seg14 0x8824."""
    raw = bank(rom, 14)[0x0824 : 0x0824 + 40 * 8]
    assert len(raw) == 40 * 8
    lines = [
        "; credits_font (seg14 0x8824): 40 x 8x8 1bpp glyphs for the ending message",
        "; and credits.  Loaded by credits_font_load (seg0 0x53E5) from credits_init.",
        "; First 14 at VRAM dest DE=0x8040 (digits 0-9, then . ' : ,); A-Z at",
        "; DE=0x0848.  Each defb is one row, MSB = left pixel.",
        "; Preview: gfx/fonts/font_credits.png.  Source: data/font_credits.asm.",
        "credits_font:",
    ]
    for i, ch in enumerate(CREDITS_FONT_CHARS):
        if i == 14:
            lines.append("; A-Z (seg14 0x8894)")
            lines.append("credits_font_az:")
        if ch == "'":
            lines.append("; \"'\"")
        else:
            lines.append("; '%s'" % ch)
        for b in raw[i * 8 : (i + 1) * 8]:
            lines.append("\tdefb %s" % bits_byte(b))
        lines.append("")
    # drop the trailing blank so the file ends on the last glyph row
    if lines[-1] == "":
        lines.pop()
    write_lines(os.path.join(DATA, "font_credits.asm"), lines)


# Boot Konami-logo font: 52 x 8x8 1bpp at seg13 0xBE59.  logo_font_load
# (seg0 0x5316, from konami_logo_draw) blits three ink groups onto page 0
# at Y=0 (no HUD +0x38).  tile_string_draw ids 0x01-0x34; 0x00 is blank.
LOGO_FONT_CPU = 0xBE59
LOGO_FONT_GROUPS = (
    (0x01, 13, "logo_font", "ink 1 at (8,0); ids 01-0D"),
    (0x0E, 13, "logo_font_ink2", "ink 2 at (0x70,0); ids 0E-1A"),
    (0x1B, 26, "logo_font_ink3", "ink 3 at (0xD8,0), wraps to Y=8 at id 20; ids 1B-34"),
)


def emit_logo_font(rom: bytes) -> None:
    """52 1bpp Konami-logo glyphs at seg13 0xBE59 plus 0xFF pad to 0xC000."""
    b13 = bank(rom, 13)
    raw = b13[0x1E59:0x1E59 + 52 * 8]
    assert len(raw) == 52 * 8
    pad = b13[0x1FF9:]
    assert pad == b"\xff" * 7
    lines = [
        "; logo_font (seg13 0xBE59): 52 x 8x8 1bpp glyphs for the boot Konami",
        "; logo.  Loaded by logo_font_load (seg0 0x5316) from konami_logo_draw",
        "; via glyph_blit_run onto page 0 at Y=0 (tile ids 0x01-0x34; X=0 /",
        "; id 0x00 is blank).  Different sheet from hud_font: logo ids 0x2C-",
        "; 0x2E are wordmark cells, not HUD '<' '=' '>'.  Each defb is one",
        "; row, MSB = left pixel.",
        "; Preview: gfx/fonts/font_logo.png.  Source: data/font_logo.asm.",
    ]
    off = 0
    for first_id, count, label, note in LOGO_FONT_GROUPS:
        cpu = LOGO_FONT_CPU + off
        lines.append("%s:  ; 0x%04X  %s" % (label, cpu, note))
        for i in range(count):
            append_1bpp_glyph(
                lines,
                raw[off + i * 8 : off + (i + 1) * 8],
                "0x%02X" % (first_id + i),
            )
        off += count * 8
    if lines[-1] == "":
        lines.pop()
    lines.append("")
    lines.append("; 0xFF pad to end of seg13 (0xBFF9).")
    lines.append("\tdefb " + ",".join("0x%02x" % b for b in pad))
    write_lines(os.path.join(DATA, "font_logo.asm"), lines)


def append_mtile_def(lines: list[str], chunk: bytes, comment: str) -> None:
    """Complete defs are 4 rows of 4 tile ids (readable 4x4)."""
    if len(chunk) == 16:
        if comment:
            lines.append("; %s" % comment)
        for r in range(4):
            row = chunk[r * 4 : r * 4 + 4]
            lines.append("\tdefb " + ",".join("0x%02x" % b for b in row))
    else:
        extra = "  ; %s" % comment if comment else ""
        lines.append("\tdefb " + ",".join("0x%02x" % b for b in chunk) + extra)


def emit_4bpp(
    buf: bytes,
    cpu0: int,
    origins: list[tuple],
    labels: list[tuple[int, str, str]] | None = None,
    sections: list[tuple[int, str]] | None = None,
) -> list[str]:
    """Emit 4bpp tiles as hex pixel-rows.  origins: (cpu, name) or
    (cpu, name, nbytes) with nbytes 32 (8x8) or 128 (16x16).  labels:
    (cpu, name, comment); several labels may share a cpu.  sections:
    (cpu, title) -> `; --- title ---` before that tile."""
    lab: dict[int, list[tuple[str, str]]] = {}
    for cpu, name, comment in labels or []:
        lab.setdefault(cpu, []).append((name, comment))
    sec = dict(sections or [])
    orig_norm = []
    for o in origins or [(cpu0, "raw")]:
        orig_norm.append((o[0], o[1], o[2] if len(o) > 2 else TILE))
    orig_sorted = sorted(orig_norm)
    lines: list[str] = []
    i = 0
    while i < len(buf):
        cpu = cpu0 + i
        if cpu in sec:
            if lines and lines[-1] != "":
                lines.append("")
            lines.append("; --- %s ---" % sec[cpu])
        for name, comment in lab.get(cpu, []):
            lines.append("%s:  ; 0x%04X  %s" % (name, cpu, comment))
        origin, tname, tsize = orig_sorted[0]
        for o, n, z in orig_sorted:
            if o <= cpu:
                origin, tname, tsize = o, n, z
        row_bytes = 8 if tsize == TILE16 else 4
        nrows = tsize // row_bytes
        rel = cpu - origin
        left = len(buf) - i
        if rel >= 0 and rel % tsize == 0 and left >= tsize:
            tid = rel // tsize
            if tsize == TILE16:
                extra = "%s 16x16 0x%02X" % (tname, tid)
            elif tid < NTILES:
                extra = "%s tile 0x%02X" % (tname, tid)
            else:
                extra = "%s +0x%02X (past 0xBF blit)" % (tname, tid)
            lines.append("; 0x%04X  %s" % (cpu, extra))
            for r in range(nrows):
                o0 = i + r * row_bytes
                lines.append(pix4_row(buf[o0 : o0 + row_bytes]))
            i += tsize
            continue
        # File starts (or resumes) mid-tile: emit the rest of this tile as
        # short rows, then the next tile boundary can use the full form.
        if rel > 0 and rel % tsize != 0:
            take = min(tsize - (rel % tsize), left)
            tid = rel // tsize
            if tsize == TILE16:
                extra = "%s 16x16 0x%02X" % (tname, tid)
            elif tid < NTILES:
                extra = "%s tile 0x%02X" % (tname, tid)
            else:
                extra = "%s +0x%02X (past 0xBF blit)" % (tname, tid)
            lines.append("; 0x%04X  rest of %s" % (cpu, extra))
            j = 0
            while j < take:
                n = min(row_bytes, take - j)
                chunk = buf[i + j : i + j + n]
                addr = cpu + j
                if n == row_bytes:
                    lines.append(pix4_row(chunk) + "  ; 0x%04X" % addr)
                else:
                    lines.append(
                        "\tdefb "
                        + ",".join("0x%02x" % b for b in chunk)
                        + "  ; 0x%04X" % addr
                    )
                j += n
            i += take
            continue
        if left >= row_bytes:
            lines.append(pix4_row(buf[i : i + row_bytes]) + "  ; 0x%04X" % cpu)
            i += row_bytes
        else:
            chunk = buf[i:]
            lines.append(
                "\tdefb "
                + ",".join("0x%02x" % b for b in chunk)
                + "  ; 0x%04X" % cpu
            )
            i = len(buf)
    return lines


def write_lines(path: str, lines: list[str]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    text = "\n".join(lines) + "\n"
    with open(path, "w") as f:
        f.write(text)
    print("wrote %s (%d lines)" % (os.path.relpath(path, ROOT), len(lines)))


# --- metatile streams -------------------------------------------------------

ROWBASE = [
    0x00, 0x03, 0x0B, 0x11, 0x17, 0x1D, 0x23, 0x29, 0x32, 0x3A,
    0x43, 0x4C, 0x52, 0x5E, 0x6A, 0x72, 0x7C, 0x86, 0x92,
]
NROOMS = 156  # stages 0-17 = 146, stage 18 = 10


def room_stage_local(index: int) -> tuple[int, int]:
    ends = ROWBASE[1:] + [NROOMS]
    for stage, (lo, hi) in enumerate(zip(ROWBASE, ends)):
        if lo <= index < hi:
            return stage, index - lo
    raise ValueError(index)


def emit_mtile_streams(rom: bytes) -> None:
    b11 = bank(rom, 11)
    c41a = b11[0x014B : 0x014B + 48]
    lines = [
        "; 8x6 metatile ids used when C41A != 0 (room_map_build).",
        "; 48 bytes, row-major.  Included at mtile_stream_c41a (seg11 0x614B).",
        "mtile_stream_c41a:",
    ]
    for row in range(6):
        chunk = c41a[row * 8 : row * 8 + 8]
        lines.append(
            "\tdefb "
            + ",".join("0x%02x" % b for b in chunk)
            + "  ; row %d" % row
        )
    write_lines(os.path.join(DATA, "mtile_stream_c41a.asm"), lines)

    streams = b11[0x017B : 0x017B + 0x1D40]
    assert len(streams) == NROOMS * 48
    lines = [
        "; Packed 8x6 metatile streams, index order (mtile_roomptr).",
        "; 156 rooms x 48 bytes.  Included at mtile_streams (seg11 0x617B).",
        "mtile_streams:",
    ]
    for i in range(NROOMS):
        stage, local = room_stage_local(i)
        blob = streams[i * 48 : (i + 1) * 48]
        cpu = 0x617B + i * 48
        lines.append(
            "mtile_stream_s%02d_r%02d:  ; cpu 0x%04X  roomptr[%d]"
            % (stage, local, cpu, i)
        )
        for row in range(6):
            chunk = blob[row * 8 : row * 8 + 8]
            lines.append("\tdefb " + ",".join("0x%02x" % b for b in chunk))
    write_lines(os.path.join(DATA, "mtile_streams.asm"), lines)


def emit_mtile_defs_slice(
    path: str, header: list[str], buf: bytes, cpu0: int, def0: int | None
) -> None:
    """def0 = first complete 16-byte def index at cpu0, or None if mid-def."""
    lines = list(header)
    off = 0
    # If cpu0 is not 16-aligned from table start, just dump with cpu comments.
    while off < len(buf):
        cpu = cpu0 + off
        n = min(COLS, len(buf) - off)
        # Prefer 16-byte groups when aligned to a def.
        if def0 is not None:
            rel = off
            # Caller guarantees comments; 16-byte rows when possible.
        if n == COLS or off + n == len(buf):
            pass
        lines.append(
            "\tdefb "
            + ",".join("0x%02x" % b for b in buf[off : off + n])
            + "  ; 0x%04X" % cpu
        )
        off += n
    write_lines(path, lines)


def emit_mtile_defs(rom: bytes) -> None:
    b11 = bank(rom, 11)
    b12 = bank(rom, 12)
    b13 = bank(rom, 13)

    # Stage 0: 0x7EE1, 0x1D0 bytes (29 defs), split 0x11F / 0xB1 at 0x8000.
    s00a = b11[0x1EE1:0x2000]
    s00b = b12[0:0x00B1]
    assert len(s00a) == 0x11F and len(s00b) == 0x00B1

    def dump_defs(path, title, buf, cpu0, first_id, note, label=None):
        lines = [title, note]
        if label:
            lines.append("%s:" % label)
        lines.append("")
        # Align comments to 16-byte defs relative to table origin first_id at cpu_table.
        # We only know first_id at cpu0 if cpu0 is the table start.
        off = 0
        while off < len(buf):
            cpu = cpu0 + off
            take = min(16, len(buf) - off)
            chunk = buf[off : off + take]
            comment = ""
            rel = cpu - cpu0
            if take == 16 and rel % 16 == 0:
                comment = "def 0x%02X" % (first_id + rel // 16)
            elif take != 16:
                comment = "0x%04X" % cpu
            append_mtile_def(lines, chunk, comment)
            off += take
        write_lines(path, lines)

    dump_defs(
        os.path.join(DATA, "mtile_defs_s00_a.asm"),
        "; Stage 0 metatile defs, body (seg11 0x7EE1).  Tail in mtile_defs_s00_b.",
        s00a,
        0x7EE1,
        0,
        "; 4x4 tile ids, 16 bytes/def.  Last def straddles 0x8000.",
        label="mtile_defs_s00",
    )
    lines = [
        "; Stage 0 metatile defs, tail (seg12 0x8000).",
        "; Completes the def that straddles 0x8000, then defs through 0x1C (29 defs).",
        "",
    ]
    table0 = 0x7EE1
    off = 0
    while off < len(s00b):
        cpu = 0x8000 + off
        rel = cpu - table0
        take = min(16 - (rel % 16), len(s00b) - off) if rel % 16 else min(16, len(s00b) - off)
        chunk = s00b[off : off + take]
        comment = ""
        if rel % 16 == 0:
            comment = "def 0x%02X" % (rel // 16)
        elif off == 0:
            comment = "rest of def 0x%02X" % (rel // 16)
        append_mtile_def(lines, chunk, comment)
        off += take
    write_lines(os.path.join(DATA, "mtile_defs_s00_b.asm"), lines)

    slices = [
        ("mtile_defs_s01.asm", "mtile_defs_s01", "stages 1-3 (0x80B1)", b12[0x00B1:0x04D1], 0x80B1),
        ("mtile_defs_s04.asm", "mtile_defs_s04", "stages 4-6 (0x84D1)", b12[0x04D1:0x0791], 0x84D1),
        ("mtile_defs_s07.asm", "mtile_defs_s07", "stages 7-9 (0x8791)", b12[0x0791:0x0D21], 0x8791),
        ("mtile_defs_s10.asm", "mtile_defs_s10", "stages 10-12 (0x8D21)", b12[0x0D21:0x1121], 0x8D21),
        ("mtile_defs_s13.asm", "mtile_defs_s13", "stages 13-15 (0x9121)", b12[0x1121:0x1651], 0x9121),
        ("mtile_defs_s16.asm", "mtile_defs_s16", "stages 16-17 (0x9651)", b12[0x1651:0x1AC1], 0x9651),
        ("mtile_defs_s18_a.asm", "mtile_defs_s18", "stage 18 body (0x9AC1), tail in seg13", b12[0x1AC1:0x2000], 0x9AC1),
    ]
    for fname, label, desc, buf, cpu0 in slices:
        n = len(buf) // 16
        rem = len(buf) % 16
        lines = [
            "; 4x4 metatile defs, 16 bytes/def.  %s." % desc,
            "; %d complete def(s)%s."
            % (n, ("" if rem == 0 else ", then %d-byte straddle" % rem)),
            "%s:" % label,
        ]
        off = 0
        while off < len(buf):
            take = min(16, len(buf) - off)
            chunk = buf[off : off + take]
            if take == 16:
                comment = "def 0x%02X" % (off // 16)
            elif off == 0:
                comment = "def 0x00"
            else:
                comment = "start of last def (tail in next bank)"
            append_mtile_def(lines, chunk, comment)
            off += take
        write_lines(os.path.join(DATA, fname), lines)

    s18b = b13[0:0x0041]
    lines = [
        "; Stage 18 metatile defs, tail (seg13 0xA000).  Completes mtile_defs_s18.",
        "",
    ]
    table0 = 0x9AC1
    off = 0
    while off < len(s18b):
        cpu = 0xA000 + off
        rel = cpu - table0
        take = min(16 - (rel % 16), len(s18b) - off) if rel % 16 else min(16, len(s18b) - off)
        chunk = s18b[off : off + take]
        comment = ""
        if rel % 16 == 0:
            comment = "def 0x%02X" % (rel // 16)
        elif off == 0:
            comment = "rest of def 0x%02X" % (rel // 16)
        append_mtile_def(lines, chunk, comment)
        off += take
    write_lines(os.path.join(DATA, "mtile_defs_s18_b.asm"), lines)

    c41a = b13[0x0041 : 0x0041 + 0x0240]
    assert len(c41a) == 0x240
    lines = [
        "; Metatile defs used with mtile_stream_c41a (seg13 0xA041).",
        "; 36 x 16-byte 4x4 defs.",
        "mtile_def_c41a:",
    ]
    for i in range(36):
        append_mtile_def(lines, c41a[i * 16 : (i + 1) * 16], "def 0x%02X" % i)
    write_lines(os.path.join(DATA, "mtile_def_c41a.asm"), lines)


# --- tileset banks ----------------------------------------------------------

def write_tile_file(
    fname: str,
    header: list[str],
    buf: bytes,
    cpu0: int,
    origins: list[tuple],
    labels: list[tuple[int, str, str]] | None = None,
    sections: list[tuple[int, str]] | None = None,
) -> None:
    lines = list(header)
    if lines and lines[-1] != "":
        lines.append("")
    lines += emit_4bpp(buf, cpu0, origins, labels, sections)
    write_lines(os.path.join(DATA, fname), lines)


# ix+0B pose -> stream label.  Shared pointer-table slots (6F/70=71, 81-84=85,
# 95/96=97) pick the first named id on that stream.  Unused holes stay
# actor_shape_%04x — see the actor_shape.asm header.
SHAPE_ID_NAME = {
    0x00: "shape_pickup_fall",
    0x01: "shape_pickup",
    0x02: "shape_dracula_robe_0",
    0x03: "shape_fireball",
    0x04: "shape_skull_pile_l",
    0x05: "shape_skull_pile_r",
    0x06: "shape_skull_pile_fe40_l",
    0x07: "shape_skull_pile_fe40_r",
    0x08: "shape_merman_green_walk_l0",
    0x09: "shape_merman_green_walk_l1",
    0x0A: "shape_merman_open",  # unused; open-mouth in spr_merman load
    0x0B: "shape_merman_green_walk_r0",
    0x0C: "shape_merman_green_walk_r1",
    0x0E: "shape_merman_splash",
    0x0F: "shape_merman_red_walk_l0",
    0x10: "shape_merman_red_walk_l1",
    0x11: "shape_merman_red_spit_l",
    0x12: "shape_merman_red_walk_r0",
    0x13: "shape_merman_red_walk_r1",
    0x14: "shape_merman_red_spit_r",
    0x15: "shape_merman_splash_s10",
    0x16: "shape_flying_skull_l0",
    0x17: "shape_flying_skull_l1",
    0x18: "shape_flying_skull_r0",
    0x19: "shape_flying_skull_r1",
    0x1A: "shape_hanging_bat_hang",
    0x1B: "shape_hanging_bat_fly_l0",
    0x1C: "shape_hanging_bat_fly_l1",
    0x1D: "shape_hanging_bat_fly_l2",
    0x1E: "shape_hanging_bat_fly_r0",
    0x1F: "shape_hanging_bat_fly_r1",
    0x20: "shape_hanging_bat_fly_r2",
    0x21: "shape_red_skel_walk_r0",
    0x22: "shape_red_skel_walk_r1",
    0x23: "shape_red_skel_walk_l0",
    0x24: "shape_red_skel_walk_l1",
    0x25: "shape_red_skel_wake",
    0x26: "shape_red_skel_wait",
    0x27: "shape_medusa_snake_l0",
    0x28: "shape_medusa_snake_l1",
    0x29: "shape_medusa_snake_r0",
    0x2A: "shape_medusa_snake_r1",
    0x2B: "shape_medusa_0",
    0x2C: "shape_medusa_1",
    0x33: "shape_mummy_walk_l0",
    0x34: "shape_mummy_walk_l1",
    0x35: "shape_mummy_walk_l2",
    0x36: "shape_mummy_walk_r0",
    0x37: "shape_mummy_walk_r1",
    0x38: "shape_mummy_walk_r2",
    0x39: "shape_mummy_bandage_0",
    0x3A: "shape_mummy_bandage_1",
    0x3B: "shape_zombie_walk_l0",
    0x3C: "shape_zombie_walk_l1",
    0x3D: "shape_zombie_walk_r0",
    0x3E: "shape_zombie_walk_r1",
    0x3F: "shape_dog_idle_near",
    0x40: "shape_dog_run_l2",
    0x41: "shape_dog_run_l0",
    0x42: "shape_dog_run_l1",
    0x43: "shape_dog_idle_far",
    0x44: "shape_dog_run_r2",
    0x45: "shape_dog_run_r0",
    0x46: "shape_dog_run_r1",
    0x47: "shape_white_skel_walk_l0",
    0x48: "shape_white_skel_walk_l1",
    0x49: "shape_white_skel_walk_r0",
    0x4A: "shape_white_skel_walk_r1",
    0x4B: "shape_bone_0",
    0x4C: "shape_bone_1",
    0x4D: "shape_bone_2",
    0x4E: "shape_giant_bat_0",  # shot_bone's 4th frame also indexes this id
    0x4F: "shape_giant_bat_1",
    0x50: "shape_pikeman_walk_l0",
    0x51: "shape_pikeman_walk_l1",
    0x52: "shape_pikeman_walk_l2",
    0x53: "shape_pikeman_walk_r0",
    0x54: "shape_pikeman_walk_r1",
    0x55: "shape_pikeman_walk_r2",
    0x56: "shape_dracula_intro_0",
    0x57: "shape_dracula_intro_1",
    0x59: "shape_dracula_intro_1_l",
    0x5A: "shape_dracula_chunk",
    0x5B: "shape_dracula_stand_l",
    0x5C: "shape_dracula_stand_l_open",
    0x5D: "shape_dracula_stand_r",
    0x5E: "shape_dracula_stand_r_open",
    0x5F: "shape_axe_knight_walk_l0",
    0x60: "shape_axe_knight_walk_l1",
    0x61: "shape_axe_knight_walk_r0",
    0x62: "shape_axe_knight_walk_r1",
    0x63: "shape_axe_0",
    0x64: "shape_axe_1",
    0x65: "shape_axe_2",
    0x66: "shape_axe_3",
    0x67: "shape_hunchback_l0",
    0x68: "shape_hunchback_l1",
    0x69: "shape_igor_land_l",
    0x6A: "shape_hunchback_r0",
    0x6B: "shape_hunchback_r1",
    0x6C: "shape_igor_land_r",
    0x6D: "shape_roc_flap_0",
    0x6E: "shape_roc_flap_1",
    0x71: "shape_ghost_head_l0",
    0x72: "shape_ghost_head_l1",
    0x73: "shape_ghost_head_r0",
    0x74: "shape_ghost_head_r1",
    0x75: "shape_ghost_head_s15_r1",
    0x79: "shape_frankenstein_0",
    0x7A: "shape_frankenstein_1",
    0x7B: "shape_frankenstein_2",
    0x7C: "shape_grim_reaper",
    0x7D: "shape_sickle_0",
    0x7E: "shape_sickle_1",
    0x7F: "shape_sickle_2",
    0x80: "shape_sickle_3",
    0x85: "shape_flame_0",
    0x86: "shape_flame_1",
    0x87: "shape_raven_fly_l0",
    0x88: "shape_raven_fly_l1",
    0x89: "shape_raven_perch",
    0x8A: "shape_raven_fly_r0",
    0x8B: "shape_raven_fly_r1",
    0x8C: "shape_raven_perch_conv",
    0x8D: "shape_roc_flap_2",
    0x8F: "shape_orb_0",
    0x90: "shape_orb_1",
    0x91: "shape_orb_2",
    0x92: "shape_intro_sky_a",
    0x93: "shape_intro_sky_b",
    0x94: "shape_intro_sky",
    0x97: "shape_intro_simon_0",
    0x98: "shape_intro_simon_1",
    0x99: "shape_intro_simon_2",
    0x9A: "shape_intro_simon_3",
    0x9B: "shape_blob_0",
    0x9C: "shape_blob_1",
    0x9D: "shape_blob_fe00_0",
    0x9E: "shape_blob_fe00_1",
    0x9F: "shape_blob_fb80_0",
    0xA0: "shape_blob_fb80_1",
    0xA1: "shape_blob_fd00_0",
    0xA2: "shape_blob_fd00_1",
    0xA5: "shape_dracula_robe_1",
    0xA6: "shape_dracula_head_open",
    0xA7: "shape_dracula_head_closed",
}


def shape_stream_name(cpu: int, ids: list[int] | None = None) -> str:
    if ids:
        for i in ids:
            if i in SHAPE_ID_NAME:
                return SHAPE_ID_NAME[i]
    return "actor_shape_%04x" % cpu


# Contiguous ix+0B ranges for section comments.  Word/byte order stays id /
# CPU order (roc flap 2 and white-skeleton sit where the table puts them).
SHAPE_GROUPS = (
    (0x00, 0x01, "pickup"),
    (0x02, 0x02, "dracula robe"),
    (0x03, 0x03, "fireball"),
    (0x04, 0x07, "skull pile"),
    (0x08, 0x15, "merman"),
    (0x16, 0x19, "flying skull"),
    (0x1A, 0x20, "hanging bat"),
    (0x21, 0x26, "skeleton (red)"),
    (0x27, 0x2C, "medusa"),
    (0x2D, 0x32, "unused"),
    (0x33, 0x3A, "mummy"),
    (0x3B, 0x3E, "zombie"),
    (0x3F, 0x46, "dog"),
    (0x47, 0x4D, "skeleton (white + bone)"),
    (0x4E, 0x4F, "giant bat"),
    (0x50, 0x55, "pikeman"),
    (0x56, 0x5E, "dracula"),
    (0x5F, 0x62, "axe knight"),
    (0x63, 0x66, "axe (thrown)"),
    (0x67, 0x6C, "hunchback / igor"),
    (0x6D, 0x6E, "roc"),
    (0x6F, 0x75, "ghost head"),
    (0x76, 0x78, "unused"),
    (0x79, 0x7B, "frankenstein"),
    (0x7C, 0x7C, "grim reaper"),
    (0x7D, 0x80, "sickle"),
    (0x81, 0x86, "flame"),
    (0x87, 0x8C, "raven"),
    (0x8D, 0x8D, "roc"),
    (0x8E, 0x8E, "unused"),
    (0x8F, 0x91, "orb"),
    (0x92, 0x9A, "intro"),
    (0x9B, 0xA2, "blob"),
    (0xA3, 0xA4, "unused"),
    (0xA5, 0xA5, "dracula robe"),
    (0xA6, 0xA7, "dracula head"),
)


def _shape_group_at(sid: int) -> tuple[int, int, str]:
    for lo, hi, title in SHAPE_GROUPS:
        if lo <= sid <= hi:
            return lo, hi, title
    raise KeyError("shape id 0x%02X has no group" % sid)


def _shape_id_note(ids: list[int]) -> str:
    if len(ids) == 1:
        return "id 0x%02X" % ids[0]
    if ids == list(range(ids[0], ids[-1] + 1)):
        return "ids 0x%02X-0x%02X" % (ids[0], ids[-1])
    return "ids " + ",".join("0x%02X" % i for i in ids)


def _stream_kind(data: bytes) -> str:
    n = SHAPE_PREFIX_NPAT.get(data[0])
    if n is not None:
        return "0x%02X + %d pats" % (data[0], n)
    return "%d x (dy,dx,pat)" % (len(data) // 3)


def format_actor_shapes(raw: bytes) -> list[str]:
    """raw = seg6[0xB473:0xB9C8].  Table is packed against the first stream."""
    first = raw[0] | (raw[1] << 8)
    n = (first - ACTOR_SHAPE_CPU) // 2
    ptrs = [raw[i] | (raw[i + 1] << 8) for i in range(0, n * 2, 2)]
    assert min(ptrs) == first
    assert first == ACTOR_SHAPE_CPU + n * 2
    assert SHAPE_GROUPS[0][0] == 0 and SHAPE_GROUPS[-1][1] == n - 1
    for a, b in zip(SHAPE_GROUPS, SHAPE_GROUPS[1:]):
        assert a[1] + 1 == b[0], (a, b)
    id_of: dict[int, list[int]] = {}
    for i, p in enumerate(ptrs):
        id_of.setdefault(p, []).append(i)
    starts = sorted(id_of) + [ACTOR_SHAPE_HUD]

    lines = [
        "; Actor SAT shape streams (seg6 0xB473-0xB9C7).  actor_sat_build pages",
        "; this bank and looks up ix+0B in actor_shape_ptr (word[0..0xA7]).",
        "; A leading 0x80/0x81/0x82 selects a fixed (dy,dx) list in seg1; the",
        "; following bytes are SAT patterns.  Otherwise the stream is explicit",
        "; (dy,dx,pat) triples.  load_stage_tileset still copies 0xBF tiles from",
        "; tileset_s10 (0x9E73), so VRAM ids 0xB0-0xBE on stages 10-12 overlay",
        "; this table; nametables do not use those ids.  HUD tiles follow at 0xB9C8.",
        "; Names live in tools/emit_identified_data.py SHAPE_ID_NAME (regen this",
        "; file from there).  shape_* prefix avoids colliding with spr_* RLE.",
        "; Unused (no store): 0x0D 0x2D-0x32 0x58 0x76-0x78 0x8E 0xA3-0xA4.",
        "; 0x0A is named (open-mouth merman) but unused.  Event 6: 0x02/0xA5",
        "; are robe, 0xA6 open / 0xA7 closed head (actor_dracula_bat); 0x57/0x59",
        "; are the flying SAT head (actor_dracula_head); 0x5A is actor_dracula_chunk.",
        "; Shared slots: 0x6F/0x70 = ghost 0x71; 0x81-0x84 = flame 0x85;",
        "; 0x95/0x96 = intro simon 0x97.  shot_bone's 4th frame is giant-bat 0x4E.",
        "; Sections group by actor; defw / stream order is still id / CPU order.",
        "",
        "actor_shape_ptr:  ; 0xB473  word[shape id] -> stream",
    ]
    sid = 0
    while sid < n:
        lo, hi, title = _shape_group_at(sid)
        assert lo == sid
        lines.append("")
        lines.append("; --- %s ---" % title)
        while sid <= hi:
            take = min(4, hi - sid + 1)
            chunk = ptrs[sid : sid + take]
            names = ", ".join(shape_stream_name(p, id_of[p]) for p in chunk)
            lines.append("\tdefw %s  ; 0x%02X" % (names, sid))
            sid += take
    lines.append("")
    prev_title = None
    for s, e in zip(starts, starts[1:]):
        data = raw[s - ACTOR_SHAPE_CPU : e - ACTOR_SHAPE_CPU]
        title = _shape_group_at(min(id_of[s]))[2]
        if title != prev_title:
            lines.append("; --- %s ---" % title)
            prev_title = title
        lines.append(
            "%s:  ; 0x%04X  %s  %s"
            % (shape_stream_name(s, id_of[s]), s, _shape_id_note(id_of[s]), _stream_kind(data))
        )
        lines.extend(defb_lines(data))
        lines.append("")
    if lines[-1] == "":
        lines.pop()
    return lines


def emit_actor_shapes(rom: bytes) -> None:
    b6 = bank(rom, 6)
    raw = b6[ACTOR_SHAPE_CPU - 0xA000 : ACTOR_SHAPE_HUD - 0xA000]
    write_lines(os.path.join(DATA, "actor_shape.asm"), format_actor_shapes(raw))


def emit_tileset_banks(rom: bytes) -> None:
    """Unique tileset byte ranges into data/ files; banks 4-6 and 7-8 are
    one PHASE / one stitch file each (banks_456.asm, banks_78.asm).
    Files are non-overlapping ROM slices, not complete 0xBF-tile copies.
    """
    b4 = bank(rom, 4)
    b5 = bank(rom, 5)
    b6 = bank(rom, 6)
    b7 = bank(rom, 7)
    b8 = bank(rom, 8)

    pixnote = [
        "; Uncompressed 8x8 4bpp (SCREEN 5).  Each defb is one pixel-row",
        "; (4 bytes, high nibble = left).  Eight rows = one tile (32 bytes).",
        "; Preview: gfx/tilesets/<stem>.png (`make gfx`); cell header = CPU address.",
    ]
    slicenote = pixnote + [
        "; load_stage_tileset blits 0xBF tiles from tileset_ptr[D000].",
        "; Sets overlap; this file is the unique ROM slice, not a full copy.",
    ]

    write_tile_file(
        "tileset_s00.asm",
        ["; Courtyard tileset (seg4 0x6000).  s01 overlaps at 0x7220."] + slicenote,
        b4[0:0x1220],
        0x6000,
        [(0x6000, "s00")],
        [(0x6000, "tileset_s00", "courtyard; 0xBF tiles; s01 overlaps at 0x7220")],
    )
    write_tile_file(
        "tileset_s01.asm",
        [
            "; Stages 1-3 tileset (0x7220-0x82BF).  Crosses 0x8000 (seg4 into",
            "; seg5); staff roll follows at 0x82C0.",
        ]
        + slicenote,
        b4[0x1220:] + b5[0:0x02C0],
        0x7220,
        [(0x7220, "s01")],
        [(0x7220, "tileset_s01", "stages 1-3; 0xBF tiles; s00 overlaps at 0x7220")],
    )
    write_tile_file(
        "tileset_s07.asm",
        ["; Stages 7-9 tileset (seg5 0x8493).  Fits in this bank."] + slicenote,
        b5[0x0493:0x15B3],
        0x8493,
        [(0x8493, "s07")],
        [(0x8493, "tileset_s07", "stages 7-9; 0xBF tiles")],
    )
    write_tile_file(
        "tileset_s04.asm",
        [
            "; Stages 4-6 tileset unique prefix (seg5 0x95B3-0x9E73).",
            "; The 0xBF blit continues through tileset_s10 (shared bytes).",
        ]
        + slicenote,
        b5[0x15B3:0x1E73],
        0x95B3,
        [(0x95B3, "s04")],
        [(0x95B3, "tileset_s04", "stages 4-6; tail overlaps tileset_s10")],
    )
    write_tile_file(
        "tileset_s10.asm",
        [
            "; Stages 10-12 tileset (0x9E73-0xB472).  Crosses 0xA000 (seg5 into",
            "; seg6).  Also the tail of s04's 0xBF blit.  Last pixel 0xB472;",
            "; actor_shape_ptr follows at 0xB473.",
        ]
        + slicenote,
        b5[0x1E73:] + b6[0 : ACTOR_SHAPE_CPU - 0xA000],
        0x9E73,
        [(0x95B3, "s04"), (0x9E73, "s10")],
        [(0x9E73, "tileset_s10", "stages 10-12; s04 overlaps; 176 tiles then SAT")],
    )
    emit_actor_shapes(rom)
    pixnote16 = [
        "; Uncompressed 16x16 4bpp (SCREEN 5).  Each defb is one pixel-row",
        "; (8 bytes, high nibble = left).  Sixteen rows = one tile (128 bytes).",
        "; Preview: gfx/tilesets/<stem>.png (`make gfx`); cell header = CPU address.",
    ]
    hud_tiles = b6[0x19C8:0x1FC8]
    hud_pad = b6[0x1FC8:]
    assert len(hud_tiles) == len(HUD_16X16) * TILE16
    assert hud_pad == b"\xff" * (0x2000 - 0x1FC8)
    hlines = [
        "; HUD 16x16 4bpp (seg6 0xB9C8): bonus ids 0x17-0x1E (keys, chest,",
        "; chain/knife/axe/cross, holy water) then 4 candle flame frames.",
        "; HUD init (seg0 after page_tileset_banks) blits 8 icons to VRAM",
        "; Y=0x60 X=96, then B=5 from candle_0 to Y=0x70 X=0 (4 playfield",
        "; flames; the 5th slot is 0xFF pad).  Leather whip is a separate",
        "; source at (80, 0x70), not this bank.",
    ] + pixnote16 + [""]
    hlines += emit_4bpp(
        hud_tiles,
        0xB9C8,
        [
            (cpu, name[4:] if name.startswith("hud_") else name, TILE16)
            for cpu, name, _c in HUD_16X16
        ],
        [(0xB9C8, "hud_weapon_key_tiles", "8 item icons + 4 candle flames")]
        + list(HUD_16X16),
    )
    hlines.append("")
    hlines.append("; 0xFF pad to end of seg6 (0xBFC8).")
    hlines.extend(defb_lines(hud_pad))
    write_lines(os.path.join(DATA, "hud_weapon_key_tiles.asm"), hlines)
    write_tile_file(
        "tileset_s13.asm",
        ["; Stages 13-15 tileset (seg7 0x8000).  s16 overlaps at 0x9640."] + slicenote,
        b7[0:0x1640],
        0x8000,
        [(0x8000, "s13")],
        [(0x8000, "tileset_s13", "stages 13-15; 0xBF tiles")],
    )
    write_tile_file(
        "tileset_s16.asm",
        [
            "; Stages 16-17 tileset (0x9640-0xA4BF).  Crosses 0xA000 (seg7 into",
            "; seg8); stage 18 tileset follows at 0xA4C0.",
        ]
        + slicenote,
        b7[0x1640:] + b8[0:0x04C0],
        0x9640,
        [(0x9640, "s16")],
        [(0x9640, "tileset_s16", "stages 16-17; 0xBF tiles")],
    )
    write_tile_file(
        "tileset_s18.asm",
        [
            "; Stage 18 tileset unique prefix (seg8 0xA4C0-0xAC7F).",
            "; load_stage_tileset's 0xBF blit continues through title_tiles.asm.",
        ]
        + slicenote,
        b8[0x04C0:0x0C80],
        0xA4C0,
        [(0xA4C0, "s18")],
        [(0xA4C0, "tileset_s18", "stage 18 (Dracula); tail is title_tiles")],
    )
    write_tile_file(
        "title_tiles.asm",
        [
            "; Title-screen 8x8 4bpp (seg8 0xAC80-0xBD7F).  High ids of the",
            "; stage-18 tileset: castle, kana, then VAMPIRE KILLER.",
            "; title_load_tiles blits these after page_tileset_late.",
            "; HUD/title 1bpp font follows in font_hud.asm at 0xBD80.",
        ]
        + pixnote,
        b8[0x0C80:0x1D80],
        0xAC80,
        [
            (0xAC80, "castle"),
            (0xAEA0, "jp"),
            (0xB260, "en"),
        ],
        [
            (0xAC80, "title_castle_tiles", "shared castle emblem (title_load_tiles)"),
            (0xAEA0, "title_logo_jp_tiles", "title kana glyphs"),
            (0xB260, "title_logo_en_tiles", "title CASTLEVANIA glyphs"),
        ],
    )
    emit_hud_font(rom)
    write_tile_file(
        "tileset_s08_pad.asm",
        ["; 0xFF pad to end of seg8 (0xBFD2)."],
        b8[0x1FD2:],
        0xBFD2,
        [(0xBFD2, "pad")],
    )

    def stitch(path: str, header: list[str], includes: list[str]) -> None:
        lines = list(header) + [""]
        for inc in includes:
            lines.append('    INCLUDE "%s"' % inc)
            lines.append("")
        lines.append("    ASSERT $ == 0xC000")
        write_lines(path, lines)

    stitch(
        os.path.join(SEGS, "banks_456.asm"),
        [
            "; ===========================================================================",
            ";  banks 4-6 - 24K tileset window @ 0x6000-0xBFFF (page_tileset_banks).",
            ";  Courtyard, stages 1-12 tilesets, staff roll, actor SAT, HUD icons.",
            ";  tileset_s01 crosses 0x8000; tileset_s10 crosses 0xA000.",
            "; ===========================================================================",
        ],
        [
            "data/tileset_s00.asm",
            "data/tileset_s01.asm",
            "credits_staff.asm",
            "data/tileset_s07.asm",
            "data/tileset_s04.asm",
            "data/tileset_s10.asm",
            "data/actor_shape.asm",
            "data/hud_weapon_key_tiles.asm",
        ],
    )
    stitch(
        os.path.join(SEGS, "banks_78.asm"),
        [
            "; ===========================================================================",
            ";  banks 7-8 - 16K late-game window @ 0x8000-0xBFFF (page_tileset_late).",
            ";  Stages 13-18 tilesets, title 4bpp glyphs, HUD font, ending text.",
            ";  tileset_s16 crosses 0xA000; s18's 0xBF blit continues through title_tiles.",
            "; ===========================================================================",
        ],
        [
            "data/tileset_s13.asm",
            "data/tileset_s16.asm",
            "data/tileset_s18.asm",
            "data/title_tiles.asm",
            "data/font_hud.asm",
            "credits_ending.asm",
            "data/tileset_s08_pad.asm",
        ],
    )


# --- Simon / intro sprite RLE (seg13) ---------------------------------------

INTRO_SIMON = [
    (0xA319, "intro_simon_0"),
    (0xA351, "intro_simon_1"),
    (0xA38C, "intro_simon_2"),
    (0xA3CA, "intro_simon_3"),
    (0xA40B, "intro_simon_4"),
    (0xA447, "intro_simon_5"),
    (0xA480, "intro_simon_6"),
    (0xA4BC, "intro_simon_7"),
]

# Packed streams that tile 0xA319-0xB5A1 but are not in the cell/intro
# pointer tables (second 16x16 plane after a listed frame).
SIMON_RLE_ORPHANS = (0xA671, 0xA6E4, 0xA759, 0xAF78, 0xAFEA, 0xB05F)


def _rle_end(rom: bytes, file_off: int) -> int:
    _out, _base, end = decompress(rom, file_off, 0xF800)
    return end


def _words(rom: bytes, file_off: int, n: int) -> list[int]:
    return [rom[file_off + i] | (rom[file_off + i + 1] << 8) for i in range(0, n * 2, 2)]


def emit_simon_rle(rom: bytes) -> None:
    """Labeled packed RLE streams at simon_cell0/1_ptr + intro_simon + orphans.

    Covers CPU 0xA319-0xB5A1 exactly.  intro_sky is a separate file (0xB895).
    0xB5A1-0xB894 is figure Dracula body (dracula_body.asm); title_jp_sprites
    at 0xBBF6; logo_font at 0xBE59.
    """
    b13 = 13 * 0x2000
    cell0 = _words(rom, b13 + (0xA281 - 0xA000), 40)
    cell1 = _words(rom, b13 + (0xA2D1 - 0xA000), 36)
    intro = {cpu: name for cpu, name in INTRO_SIMON}
    starts = sorted(set(cell0 + cell1 + list(intro) + list(SIMON_RLE_ORPHANS)))
    assert starts[0] == 0xA319

    def label_for(cpu: int) -> str:
        if cpu in intro:
            return intro[cpu]
        return "simon_rle_%04x" % cpu

    lines = [
        "; Packed 1bpp sprite RLE (rle_dec), CPU 0xA319-0xB5A1.",
        "; Pixel bytes are defb %xxxxxxxx (MSB=left, one 8px row of an 8x8",
        "; cell; VRAM order TL/BL/TR/BR per 16x16).  Run/literal counts stay",
        "; hex so the packed stream is byte-exact.",
        "; Pointers: simon_cell0_ptr (0xA281), simon_cell1_ptr (0xA2D1),",
        "; intro load at 0x5682 (intro_simon_0..7).  Six orphan streams are",
        "; the second 16x16 plane after a listed frame; not in those tables.",
        "; PNG preview: gfx/sprites/simon_rle.png (`make gfx`); cell header = VRAM dest.",
        "",
    ]
    cpu = 0xA319
    for start in starts:
        assert start == cpu, "gap/overlap at 0x%04X vs 0x%04X" % (start, cpu)
        fo = b13 + (start - 0xA000)
        end_fo = _rle_end(rom, fo)
        packed = rom[fo:end_fo]
        extra = ""
        if start in SIMON_RLE_ORPHANS:
            extra = "; not in cell/intro ptrs (orphan plane)"
        elif start in intro:
            extra = "; intro_simon + reused by cell ptrs"
        else:
            extra = "; simon_cell0/1_ptr"
        lines.append(
            "%s:  ; 0x%04X  packed %d%s" % (label_for(start), start, len(packed), extra)
        )
        lines.extend(emit_rle_1bpp(packed))
        cpu = start + len(packed)
    assert cpu == 0xB5A1, hex(cpu)
    write_lines(os.path.join(DATA, "simon_rle.asm"), lines)

    sky_fo = b13 + (0xB895 - 0xA000)
    sky_end = _rle_end(rom, sky_fo)
    sky = rom[sky_fo:sky_end]
    assert sky_end - sky_fo == 0x00CE
    lines = [
        "; Intro sky RLE (seg13 0xB895), loaded to VRAM 0xFA00.",
        "; 8 cloud patterns + 2-frame bat flap.  gfx/sprites/intro_sky.png (`make gfx`).",
        "; Pixel bytes are defb %xxxxxxxx (MSB=left); counts stay hex.",
        "intro_sky:",
    ]
    lines.extend(emit_rle_1bpp(sky))
    write_lines(os.path.join(DATA, "intro_sky.asm"), lines)


def emit_seg13_gaps(rom: bytes) -> None:
    """Figure-Dracula 32x32 body (packed 4bpp) plus JP title sprite RLE."""
    b13 = 13 * 0x2000
    closed = rom[b13 + (0xB5A1 - 0xA000) : b13 + (0xB719 - 0xA000)]
    opened = rom[b13 + (0xB719 - 0xA000) : b13 + (0xB895 - 0xA000)]
    assert len(closed) == 0x0178
    assert len(opened) == 0x017C
    lines = [
        "; Figure Dracula 32x32 body (seg13 0xB5A1-0xB894).  Packed 4bpp,",
        "; unpacked by dracula_body_unpack (0x5834): 32 rows of N leading",
        "; zeros + (12-N) payload + 4 trailing zeros = 16 bytes / 32px.",
        "; dracula_body_load HMMCs closed to page-1 (0,0x80) + H-mirror at",
        "; (0x40,0x80), open to (0x20,0x80) + H-mirror at (0x60,0x80).",
        "dracula_body_closed:  ; 0xB5A1  cloak (shape 0x5B)",
    ]
    lines.extend(defb_lines(closed))
    lines.append("dracula_body_open:  ; 0xB719  chest-open (shape 0x5C)")
    lines.extend(defb_lines(opened))
    write_lines(os.path.join(DATA, "dracula_body.asm"), lines)

    fo = b13 + (0xBBF6 - 0xA000)
    logo_fo = b13 + (0xBE59 - 0xA000)
    dest = rom[fo] | (rom[fo + 1] << 8)
    assert dest == 0xF800
    _out, _base, end_fo = decompress(rom, fo + 2, dest)
    packed = rom[fo + 2 : end_fo]
    pad = rom[end_fo:logo_fo]
    assert pad == b"\x00"
    lines = [
        "; Japanese title sprites (seg13 0xBBF6). Packed 1bpp.  Only caller is",
        "; title_load_tiles JP path (rle_dec_addr -> VRAM 0xF800).  title_sat_init",
        "; places 11 SAT pairs (colour 8 then 2; palette index 2 forced black).",
        "; Pixel bytes are defb %xxxxxxxx (MSB=left); counts stay hex.",
        "; Preview: gfx/sprites/title_jp_sprites.png (`make gfx`); cell header = VRAM dest.",
        "title_jp_sprites:  ; 0xBBF6",
        "\tdefb 0x00, 0xf8  ; VRAM dest 0xF800 (rle_dec_addr)",
    ]
    lines.extend(emit_rle_1bpp(packed))
    lines.append("; 0x00 pad to logo_font (0xBE59).")
    lines.append("\tdefb 0x00")
    write_lines(os.path.join(DATA, "title_jp_sprites.asm"), lines)
    emit_logo_font(rom)


# Packed PSG (sfx + music that still fits in seg14).  label "" = no label.
# (label, cpu, size, comment) — ROM order, contiguous 0x8E29-0xA000.
# Labels match music/ sfx/ WAV stems (hyphen -> _; music channels _a/_b/_c).
PSG_STREAMS = [
    ("", 0x8E29, 0x0002, "unused 1F A8 (= 0xA81F dummy)"),
    ("sfx_01_boss_heal", 0x8E2B, 0x002D, "boss HP drip-fill"),
    ("sfx_02_vendor_withdraw", 0x8E58, 0x0011, "vendor offer withdrawn"),
    ("sfx_1d_vendor_hearts", 0x8E69, 0x0021, "vendor take hearts"),
    ("sfx_03_cross_fly", 0x8E8A, 0x000F, "cross fly tick"),
    ("sfx_04_knife_throw", 0x8E99, 0x0015, "knife throw"),
    ("sfx_05_whip", 0x8EAE, 0x001D, "whip swing"),
    ("sfx_06_axe_fly", 0x8ECB, 0x0019, "axe fly"),
    ("sfx_07_land", 0x8EE4, 0x000F, "land from height"),
    ("sfx_08_merman_out", 0x8EF3, 0x0032, "merman emerge"),
    ("sfx_09_water_in", 0x8F25, 0x0031, "merman dive / water pit"),
    ("sfx_0a_mummy_shot", 0x8F56, 0x001F, "mummy bandage"),
    ("sfx_0b_shield_block", 0x8F75, 0x0044, "yellow shield absorb"),
    ("sfx_0c_hit", 0x8FB9, 0x0024, "hit"),
    ("sfx_0d_ring_kill", 0x8FDD, 0x0051, "sapphire ring kill"),
    ("sfx_0e_block_break", 0x902E, 0x0037, "breakable block"),
    ("sfx_0f_heart", 0x9065, 0x0035, "heart"),
    ("sfx_10_money_bag", 0x909A, 0x002D, "money bag / vendor leave"),
    ("sfx_11_chest", 0x90C7, 0x001F, "chest unlock"),
    ("sfx_12_collect", 0x90E6, 0x0051, "collect / purchase"),
    ("sfx_13_simon_hurt", 0x9137, 0x001B, "Simon hurt"),
    ("sfx_14_key", 0x9152, 0x0027, "key"),
    ("sfx_15_portal", 0x9179, 0x0099, "portal / vertical door"),
    ("sfx_16_blue_gem", 0x9212, 0x0063, "blue gem pickup"),
    ("sfx_17_gem_warn", 0x9275, 0x0063, "blue gem expire warn"),
    ("sfx_18_holy_water", 0x92D8, 0x0042, "holy water break"),
    ("sfx_1a_door", 0x931A, 0x0085, "horizontal door"),
    ("sfx_1c_boss_clear", 0x939F, 0x002B, "HP-bar enemy death"),
    ("sfx_1b_white_cross", 0x93CA, 0x0099, "white cross"),
    ("snd_fd_seq", 0x9463, 0x000D, ""),
    ("sfx_19_vendor_offer", 0x9470, 0x001B, "vendor offer"),
    ("snd_fb_seq", 0x948B, 0x0010, ""),
    ("music_80_bgm_s00_03_a", 0x949B, 0x0066, "stages 0-3"),
    ("music_80_bgm_s00_03_b", 0x9501, 0x0097, "stages 0-3"),
    ("music_80_bgm_s00_03_c", 0x9598, 0x00D1, "stages 0-3"),
    ("music_81_bgm_s04_06_11_12_a", 0x9669, 0x005E, "stages 4-6 and 11-12"),
    ("music_81_bgm_s04_06_11_12_b", 0x96C7, 0x00A6, "stages 4-6 and 11-12"),
    ("music_81_bgm_s04_06_11_12_c", 0x976D, 0x006D, "stages 4-6 and 11-12"),
    ("music_82_bgm_s07_09_a", 0x97DA, 0x00B7, "stages 7-9"),
    ("music_82_bgm_s07_09_b", 0x9891, 0x00AC, "stages 7-9"),
    ("music_82_bgm_s07_09_c", 0x993D, 0x011B, "stages 7-9"),
    ("music_83_bgm_s16_17_a", 0x9A58, 0x0060, "stages 16-17"),
    ("music_83_bgm_s16_17_b", 0x9AB8, 0x00B2, "stages 16-17"),
    ("music_83_bgm_s16_17_c", 0x9B6A, 0x00AB, "stages 16-17"),
    ("music_84_bgm_s13_15_a", 0x9C15, 0x00C6, "stages 13-15"),
    ("music_84_bgm_s13_15_b", 0x9CDB, 0x011D, "stages 13-15"),
    ("music_84_bgm_s13_15_c", 0x9DF8, 0x00C9, "stages 13-15"),
    ("music_85_bgm_s10_18_a", 0x9EC1, 0x00C8, "stages 10 and 18"),
    ("music_85_bgm_s10_18_b", 0x9F89, 0x0077, "stages 10 and 18; continues at music_85_bgm_s10_18_b_cont"),
]


def emit_psg_streams(rom: bytes) -> None:
    """Labeled packed PSG sequences (sfx_tbl / music_ptr bodies in seg14)."""
    b14 = 14 * 0x2000
    lines = [
        "; Packed PSG streams (seg14 0x8E29-0x9FFF).  sfx_tbl / music_ptr /",
        "; snd_fb_seq / snd_fd_seq.  music_85_bgm_s10_18_b continues in psg_seg15.asm;",
        "; ids 85c and 86-8F live there too.",
        "",
    ]
    cpu = 0x8E29
    for label, start, size, comment in PSG_STREAMS:
        assert start == cpu, "PSG gap/overlap at 0x%04X vs 0x%04X" % (start, cpu)
        fo = b14 + (start - 0x8000)
        buf = rom[fo : fo + size]
        assert len(buf) == size
        extra = ("  ; %s" % comment) if comment else ""
        if label:
            lines.append("%s:  ; 0x%04X  packed %d%s" % (label, start, size, extra))
        else:
            lines.append("; 0x%04X  packed %d%s" % (start, size, extra))
        lines.extend(defb_lines(buf))
        cpu = start + size
    assert cpu == 0xA000, hex(cpu)
    write_lines(os.path.join(DATA, "psg_streams.asm"), lines)


# --- banks 9 / 10 (gfx scripts, palettes, enemy/weapon RLE, HUD tiles) ------

RLE_NAMES = {
    0xA066: "gfx_rle_a066",
    0xA0A8: "gfx_rle_a0a8",
    0xA0EA: "vdoor_rle",
    0xA147: "gfx_rle_a147",
    0xA185: "gfx_rle_a185",
    0xA24E: "weapon_knife",
    0xA272: "weapon_cross",
    0xA2E5: "spr_skull_pile",
    0xA367: "spr_flying_skull",
    0xA4C9: "weapon_axe",
    0xA54A: "spr_skeleton",
    0xA646: "spr_mummy",
    0xA896: "spr_bone_dragon",
    0xA951: "spr_hunchback",
    0xAA05: "spr_frankenstein",
    0xABAF: "spr_roc",
    0xACE3: "spr_axe_knight",
    0xADE5: "spr_pikeman",
    0xB051: "spr_blob",
    0xB07A: "spr_blob_cc",
    0xB0AA: "gfx_rle_b0aa",
    0xB120: "spr_ghost_head",
    0xB1EA: "spr_medusa",
    0xB3E8: "spr_zombie",
    0xB54B: "spr_hanging_bat",
    0xB62D: "spr_raven",
    0xB6D8: "spr_giant_bat",
    0xB836: "spr_dracula",
    0xB97D: "spr_merman",
    0xBAB9: "spr_dog",
    0xBC5A: "spr_grim_reaper",
}

# Packed order is not grouping order: knife/cross, then skull pile /
# flying skull, then gfx_rle_a3de, then axe.  Section comments only.
RLE_GROUPS = (
    (0xA066, "moving pads / vdoor / fireball"),
    (0xA24E, "thrown knife / cross"),
    (0xA2E5, "skull pile / flying skull"),
    (0xA3DE, "room extra"),
    (0xA4C9, "thrown axe"),
    (0xA54A, "enemies"),
)

PAL_NAMES = {
    0xBECD: "s00_palette",
    0xBEE3: "s01_palette",
    0xBEF6: "s02_palette",
    0xBF09: "s04_palette",
    0xBF1C: "s07_palette",
    0xBF2F: "s10_palette",
    0xBF3C: "s13_palette",
    0xBF4F: "s16_palette",
    0xBF62: "s18_palette",
    0xBF6F: "title_extra_palette",
    0xBF88: "hud_fixed_palette",
    0xBFA1: "intro_palette",
}

# Extra comment after "0xXXXX" on the label line (stage grouping, intro note).
PAL_NOTES = {
    0xBECD: "courtyard (stage 0)",
    0xBEE3: "stages 1, 3",
    0xBEF6: "stage 2",
    0xBF09: "stages 4-6",
    0xBF1C: "stages 7-9",
    0xBF2F: "stages 10-12",
    0xBF3C: "stages 13-15",
    0xBF4F: "stages 16-17",
    0xBF62: "stage 18 (Dracula)",
    0xBFA1: "intro walk-up (after hud_fixed); overwrites 8 and 12",
}

# Packed streams not referenced by room_gfx_ptr scripts (fill AEE0-B051).
ORPHAN_RLE = (0xAEE0, 0xAF96)


def cpu_fo(cpu: int) -> int:
    if 0x8000 <= cpu < 0xA000:
        return 9 * 0x2000 + (cpu - 0x8000)
    if 0xA000 <= cpu < 0xC000:
        return 10 * 0x2000 + (cpu - 0xA000)
    raise ValueError(hex(cpu))


def peek(rom: bytes, cpu: int) -> int:
    return rom[cpu_fo(cpu)]


def word_at(rom: bytes, cpu: int) -> int:
    return peek(rom, cpu) | (peek(rom, cpu + 1) << 8)


def rle_name(cpu: int) -> str:
    return RLE_NAMES.get(cpu, "gfx_rle_%04x" % cpu)


def pal_name(cpu: int) -> str:
    return PAL_NAMES.get(cpu, "pal_%04x" % cpu)


def script_name(cpu: int) -> str:
    return "gfx_script_%04x" % cpu


def rle_packed_len(rom: bytes, cpu: int, dest: int = 0xF800) -> int:
    _out, _base, end = decompress(rom, cpu_fo(cpu), dest)
    return end - cpu_fo(cpu)


def walk_script(rom: bytes, start: int) -> tuple[int, list]:
    """Return (end_cpu, ops). ops: ('rle', src, dest) | ('cvt', src, cnt, dest)."""
    cpu = start
    ops: list = []
    for _ in range(80):
        cmd = peek(rom, cpu)
        cpu += 1
        if cmd == 0xFF:
            return cpu, ops
        if cmd == 0:
            src, dest = word_at(rom, cpu), word_at(rom, cpu + 2)
            cpu += 4
            ops.append(("rle", src, dest))
        elif cmd == 1:
            src, cnt, dest = word_at(rom, cpu), peek(rom, cpu + 2), word_at(rom, cpu + 3)
            cpu += 5
            ops.append(("cvt", src, cnt, dest))
        else:
            raise ValueError("script cmd %d at 0x%04X" % (cmd, cpu - 1))
    raise ValueError("script overrun at 0x%04X" % start)


def emit_pal_bytes(rom: bytes, start: int, end: int) -> list[str]:
    """Decode palette_apply palettes from start until end (exclusive)."""
    lines: list[str] = []
    cpu = start
    while cpu < end:
        name = pal_name(cpu)
        rows = []
        p = cpu
        while p < end and peek(rom, p) != 0xFF:
            idx = peek(rom, p)
            if idx > 15:
                break
            rows.append((idx, peek(rom, p + 1), peek(rom, p + 2)))
            p += 3
        if p < end and peek(rom, p) == 0xFF:
            p += 1
        else:
            # leftover non-palette bytes
            chunk = bytes(peek(rom, i) for i in range(cpu, end))
            lines.extend(defb_lines(chunk))
            break
        extra = "" if rows else "  empty (just 0xFF)"
        note = PAL_NOTES.get(cpu)
        if note:
            extra = extra + "  " + note if extra else "  " + note
        lines.append("%s:  ; 0x%04X%s" % (name, cpu, extra))
        for idx, rb, g in rows:
            lines.append("\tdefb 0x%02x,0x%02x,0x%02x  ; idx %d" % (idx, rb, g, idx))
        lines.append("\tdefb 0xff")
        cpu = p
    return lines


def emit_script_body(ops: list) -> list[str]:
    lines = []
    for op in ops:
        if op[0] == "rle":
            _kind, src, dest = op
            lines.append("\tdefb 0x00")
            lines.append("\tdefw %s, 0x%04x" % (rle_name(src), dest))
        else:
            _kind, src, cnt, dest = op
            lines.append("\tdefb 0x01")
            lines.append("\tdefw 0x%04x" % src)
            lines.append("\tdefb 0x%02x" % cnt)
            lines.append("\tdefw 0x%04x" % dest)
    lines.append("\tdefb 0xff")
    return lines


def emit_seg9_10(rom: bytes) -> None:
    """Whole banks 9 and 10 as labeled source (no .bin)."""
    b9 = bank(rom, 9)
    b10 = bank(rom, 10)
    nrooms = [rom[2 * 0x2000 + (0x95FD - 0x8000) + s] for s in range(19)]

    # --- intro walk-up 8x8 0x8000-0x9000; bonus HUD 16x16 0x9000-0x9A80 ---
    pixnote8 = [
        "; Uncompressed 8x8 4bpp (SCREEN 5).  Each defb is one pixel-row",
        "; (4 bytes, high nibble = left).  Eight rows = one tile (32 bytes).",
        "; Preview: gfx/tilesets/intro_tiles.png (`make gfx`); cell header = CPU address.",
    ]
    pixnote16 = [
        "; Uncompressed 16x16 4bpp (SCREEN 5).  Each defb is one pixel-row",
        "; (8 bytes, high nibble = left).  Sixteen rows = one tile (128 bytes).",
        "; Preview: gfx/tilesets/bonus_hud_tiles.png (`make gfx`); cell header = CPU address.",
    ]
    write_tile_file(
        "intro_tiles.asm",
        [
            "; Intro cutscene 8x8 4bpp (seg9 0x8000): Simon walking up to the castle",
            "; (fence/gate, moon, distant castle, garden wall).  load_intro_tileset",
            "; (seg0 0x5677) pages title banks and tileset_blit copies 0xBF tiles to",
            "; VRAM 0x8004, overlapping bonus_hud_tiles (VRAM ids 0x80+).",
            "; Palette is intro_palette_load (HUD-fixed, then intro_palette at",
            "; 0xBFA1) — not title_extra_palette.",
        ]
        + pixnote8,
        b9[0:0x1000],
        0x8000,
        [(0x8000, "intro")],
        [(0x8000, "intro_tiles", "0x80 8x8 tiles for the intro walk-up")],
    )
    bonus_hud = b9[0x1000:0x1A80]
    assert len(bonus_hud) == len(BONUS_HUD_16X16) * TILE16
    write_tile_file(
        "bonus_hud_tiles.asm",
        [
            "; Bonus HUD 16x16 4bpp (seg9 0x9000): ids 1-20 then potion (id 22).",
            "; HUD init (seg0 after page_title_banks) blits 20 icons via",
            "; vram_blit_tile16 / l4a97h to Y=0x50, then potion to (X=80, Y=96).",
            "; Names live in tools/emit_identified_data.py BONUS_HUD_16X16",
            "; (regen this file from the ROM; do not hand-edit).  Id 21",
            "; (slime) has no tile here; ids 23-30 are hud_weapon_key_tiles.",
        ]
        + pixnote16,
        bonus_hud,
        0x9000,
        [
            (
                cpu,
                name[10:] if name.startswith("bonus_hud_") else name,
                TILE16,
            )
            for cpu, name, _c in BONUS_HUD_16X16
        ],
        [(0x9000, "bonus_hud_tiles", "bonus ids 1-20 (vram_blit_tile16)")]
        + list(BONUS_HUD_16X16),
        BONUS_HUD_GROUPS,
    )
    tail = b9[0x1A80:0x1AB0]
    assert len(tail) == 0x30
    tlines = [
        "; 0x9A80-0x9AAF: stage spike-bar scenery (vdp_hmmc from 0x9A80 / 0x9A90).",
        "spike_bar_mount:  ; 0x9A80",
    ]
    tlines.extend(defb_lines(tail[:0x10]))
    tlines.append("spike:  ; 0x9A90")
    tlines.extend(defb_lines(tail[0x10:]))
    write_lines(os.path.join(DATA, "spike_bar.asm"), tlines)

    # --- room_gfx_ptr + records + scripts + pal_9ffe prefix ---
    ptrs = [word_at(rom, 0x9AB0 + s * 2) for s in range(18)]
    used_scripts: dict[int, list] = {}
    used_pals = set()
    for s in range(18):
        rec = ptrs[s]
        for r in range(nrooms[s + 1]):
            sc, pal = word_at(rom, rec + r * 4), word_at(rom, rec + r * 4 + 2)
            used_scripts.setdefault(sc, []).append((s + 1, r))
            used_pals.add(pal)

    lines = [
        "; room_gfx_ptr (seg9 0x9AB0): word[stage-1] -> 4 bytes/room",
        "; {gfx_script, palette}.  Stage 0 skips.  Walked by room_gfx_load.",
        "room_gfx_ptr:",
    ]
    for s in range(18):
        lines.append(
            "\tdefw room_gfx_s%02d  ; stage %d  %d rooms"
            % (s + 1, s + 1, nrooms[s + 1])
        )
    rec_cpu = 0x9AD4
    assert ptrs[0] == rec_cpu
    for s in range(18):
        rec = ptrs[s]
        assert rec == rec_cpu, hex(rec)
        lines.append("")
        lines.append(
            "room_gfx_s%02d:  ; 0x%04X  stage %d"
            % (s + 1, rec, s + 1)
        )
        for r in range(nrooms[s + 1]):
            sc = word_at(rom, rec + r * 4)
            pal = word_at(rom, rec + r * 4 + 2)
            lines.append(
                "\tdefw %s, %s  ; r%d"
                % (script_name(sc), pal_name(pal), r)
            )
            rec_cpu = rec + (r + 1) * 4
        assert rec_cpu == rec + nrooms[s + 1] * 4
    assert rec_cpu == 0x9D38

    # 24 back-to-back scripts 0x9D38-0x9FFE
    cpu = 0x9D38
    while cpu < 0x9FFE:
        end, ops = walk_script(rom, cpu)
        rooms = used_scripts.get(cpu, [])
        if cpu == 0x9FED:
            note = "  frontend (ld hl,gfx_script_9fed)"
        elif rooms:
            st, rm = rooms[0]
            note = "  %d rooms, first s%dr%d" % (len(rooms), st, rm)
        else:
            note = "  not in room_gfx_ptr"
        lines.append("")
        lines.append("%s:  ; 0x%04X%s" % (script_name(cpu), cpu, note))
        lines.extend(emit_script_body(ops))
        cpu = end
    assert cpu == 0x9FFE, hex(cpu)

    # pal_9ffe first 2 bytes (table continues at 0xA000)
    pal_prefix = bytes(peek(rom, 0x9FFE + i) for i in range(2))
    assert pal_prefix == bytes([peek(rom, 0x9FFE), peek(rom, 0x9FFF)])
    lines.append("")
    lines.append("pal_9ffe:  ; 0x9FFE  2 bytes here, rest at 0xA000")
    lines.append("\tdefb " + ",".join("0x%02x" % b for b in pal_prefix))
    write_lines(os.path.join(DATA, "room_gfx.asm"), lines)

    # --- seg10: pal remainder 0xA000-0xA065 ---
    pal_rest = bytes(b10[0:0x0066])
    # 0xA000 continues pal_9ffe (5 bytes) then pal_a005 ... pal_a059
    plines = [
        "; Room palettes continued from pal_9ffe (seg9 0x9FFE).",
        "; palette_apply tables: (index, rb, g)+ 0xFF.  Ends where gfx RLE starts (0xA066).",
        "; pal_9ffe continued (idx 4 already emitted in seg9)",
        "\tdefb "
        + ",".join("0x%02x" % b for b in pal_rest[0:5])
        + "  ; 0xA000",
    ]
    plines.extend(emit_pal_bytes(rom, 0xA005, 0xA066))
    write_lines(os.path.join(DATA, "room_palettes.asm"), plines)

    # --- RLE streams 0xA066-0xBDA7 ---
    script_srcs = set()
    cpu = 0x9D38
    while cpu < 0x9FFE:
        end, ops = walk_script(rom, cpu)
        for op in ops:
            if op[0] == "rle":
                script_srcs.add(op[1])
        cpu = end
    starts = sorted(script_srcs | set(RLE_NAMES) | set(ORPHAN_RLE))
    starts = [s for s in starts if 0xA066 <= s < 0xBDA7]
    dest_of: dict[int, int] = {
        0xA0EA: 0xF900,
        0xA147: 0xF9C0,
        0xA185: 0xFF00,
        0xA24E: 0xF8C0,
        0xA272: 0xF8C0,
        0xA4C9: 0xF8C0,  # load_weapon_sprites; rooms also copy to FC00
        0xB0AA: 0xFA00,
    }
    cpu_s = 0x9D38
    while cpu_s < 0x9FFE:
        end, ops = walk_script(rom, cpu_s)
        for op in ops:
            if op[0] == "rle" and op[1] not in dest_of:
                dest_of[op[1]] = op[2]
        cpu_s = end

    rlines = [
        "; Packed 1bpp sprite RLE (seg10).  Room gfx-scripts, weapons, vdoor,",
        "; and two orphan streams (0xAEE0 / 0xAF96) that fill a hole.",
        "; Pixel bytes are defb %xxxxxxxx (MSB=left, 8px row, TL/BL/TR/BR).",
        "; Run/literal counts stay hex (byte-exact packed stream).",
        "; Dest is sprite-generator VRAM (0xF800+).  Unidentified 0xB50B-0xB54A",
        "; is not a valid stream (decompressor overruns into spr_hanging_bat).",
        "; Preview: gfx/sprites/enemy_sprite_rle.png (`make gfx`); cell header = VRAM dest.",
        "; Packed order sandwiches knife/cross, skull pile, flying skull, then",
        "; the axe (load_weapon_sprites dest 0xF8C0; some rooms also load it at",
        "; 0xFC00).  Do not split this file to group weapons — bytes stay here.",
        "",
    ]
    cpu = 0xA066
    rle_group_at = dict(RLE_GROUPS)
    for start in starts:
        if start > cpu:
            gap = bytes(peek(rom, i) for i in range(cpu, start))
            rlines.append("seg10_unid_%04x:  ; 0x%04X  %d bytes" % (cpu, cpu, len(gap)))
            rlines.extend(defb_lines(gap))
            cpu = start
        assert start == cpu, "RLE overlap/gap at 0x%04X vs 0x%04X" % (start, cpu)
        dest = dest_of.get(start, 0xF800)
        plen = rle_packed_len(rom, start, dest)
        packed = bytes(peek(rom, start + i) for i in range(plen))
        extra = ""
        extra_cmt = {
            0xA066: "moving pad (stage 5 SAT D0/D4 @ FE80)",
            0xA0A8: "moving pad (stage 10 SAT D8/DC @ FEC0)",
            0xB051: "actor_blob_blue/_red/_white fill (FE80/FE00/FB80/FD00)",
            0xB07A: "actor_blob_blue/_red/_white SAT CC outline",
            0xA0EA: "vertical door (load_vdoor_sprites)",
            0xA147: "title/frontend (VRAM 0xF9C0)",
            0xA185: "VRAM 0xFF00 (fireball SAT 0xF0; flame SAT 0xF4/0xF8)",
            0xA24E: "thrown knife",
            0xA272: "thrown cross",
            0xA2E5: "type 10 SAT (skull pile)",
            0xA367: "type 7 SAT (flying skull)",
            0xA4C9: "thrown axe + room script FC00",
            0xA54A: "types 9+11 SAT (red/white skeleton)",
            0xA646: "type 20 SAT (mummy)",
            0xA896: "type 14 SAT (bone dragon)",
            0xA951: "type 13 SAT (hunchback)",
            0xAA05: "type 21 SAT (Frankenstein)",
            0xABAF: "type 15 SAT (roc)",
            0xACE3: "type 16 SAT (axe knight)",
            0xADE5: "type 6 SAT (pikeman)",
            0xB0AA: "frontend (ld de,gfx_rle_b0aa -> FA00)",
            0xB120: "type 8 SAT (ghost head)",
            0xB1EA: "type 19 SAT (Medusa)",
            0xB3E8: "type 1 SAT (zombie)",
            0xB54B: "type 4 SAT (hanging bat)",
            0xB62D: "type 12 SAT (raven)",
            0xB6D8: "type 18 SAT (giant bat)",
            0xB836: "type 17 SAT (figure Dracula head/cape; body is 4bpp)",
            0xB97D: "types 2+3 SAT (merman)",
            0xBAB9: "type 5 SAT (dog)",
            0xBC5A: "type 22 SAT (grim reaper)",
        }
        if start in extra_cmt:
            extra = "  ; " + extra_cmt[start]
        elif start in ORPHAN_RLE:
            extra = "  ; not in room scripts (orphan)"
        if start in rle_group_at:
            if rlines and rlines[-1] != "":
                rlines.append("")
            rlines.append("; --- %s ---" % rle_group_at[start])
        rlines.append(
            "%s:  ; 0x%04X  packed %d%s" % (rle_name(start), start, plen, extra)
        )
        rlines.extend(emit_rle_1bpp(packed))
        cpu = start + plen
    if cpu < 0xBDA7:
        gap = bytes(peek(rom, i) for i in range(cpu, 0xBDA7))
        rlines.append("seg10_unid_%04x:  ; 0x%04X  %d bytes" % (cpu, cpu, len(gap)))
        rlines.extend(defb_lines(gap))
        cpu = 0xBDA7
    assert cpu == 0xBDA7, hex(cpu)
    write_lines(os.path.join(DATA, "enemy_sprite_rle.asm"), rlines)

    # --- 0xBDA7-0xBEA6 vendor 8x8 tiles, then BEA7 palettes + 0xFF pad ---
    write_tile_file(
        "vendor_tiles.asm",
        [
            "; Vendor 32x32 (seg10 0xBDA7): 8 x 8x8 4bpp tiles.  hud_cache_load",
            "; (seg0 0x5494) pages title banks and vendor_cache_load copies these",
            "; to 0xE800, replacing nibble 0xF with vendor_recolor_tbl[0..4], then",
            "; vendor_blit_32 stamps a 4x4 of vendor_tile_ptr into page-1 Y=0xA0",
            "; (five colour variants at X=0,32,64,96,128).  Idle blit is slot 3",
            "; (white); whip reactions pick C70B.  Colour 0 is transparent (LMMM).",
            "; Uncompressed 8x8 4bpp (SCREEN 5).  Each defb is one pixel-row",
            "; (4 bytes, high nibble = left).  Eight rows = one tile (32 bytes).",
            "; Preview: gfx/vendor.png (assembled 32x32 x5); gfx/tilesets/vendor_tiles.png",
            "; (`make gfx`); cell header = CPU address.",
        ],
        bytes(peek(rom, i) for i in range(0xBDA7, 0xBEA7)),
        0xBDA7,
        [(0xBDA7, "vendor")],
        [(0xBDA7, "vendor_tiles", "8 x 8x8; nibble 0xF is the cloak colour key")],
    )

    slines = [
        "; Stage palette pointer table (seg10 0xBEA7) + palette_apply tables.",
        "; Labels sNN_palette match tileset_sNN grouping (stage 2 has its own table).",
        "; palette_hud_load loads hud_fixed_palette; title extras at 0xBF6F.",
        "stage_palette_ptr:",
    ]
    pal_ptr_note = {0: "courtyard", 18: "Dracula"}
    for st in range(19):
        cpu_p = word_at(rom, 0xBEA7 + st * 2)
        extra = pal_ptr_note.get(st)
        slines.append(
            "\tdefw %s  ; stage %d%s"
            % (pal_name(cpu_p), st, ("  " + extra) if extra else "")
        )
    slines.append("")
    slines.extend(emit_pal_bytes(rom, 0xBECD, 0xBFC0))
    pad = bytes(peek(rom, i) for i in range(0xBFC0, 0xC000))
    assert pad == b"\xff" * 0x40
    slines.append("")
    slines.append("; 0xFF pad to end of seg10 (0xBFC0).")
    slines.extend(defb_lines(pad))
    write_lines(os.path.join(DATA, "stage_palettes.asm"), slines)

    def stitch(path: str, header: list[str], includes: list[str]) -> None:
        out = list(header) + [""]
        for inc in includes:
            out.append('    INCLUDE "%s"' % inc)
            out.append("")
        out.append("    ASSERT $ == 0xC000")
        write_lines(path, out)

    stitch(
        os.path.join(SEGS, "banks_9a.asm"),
        [
            "; ===========================================================================",
            ";  banks 9-a - 16K front-end window @ 0x8000-0xBFFF (page_title_banks).",
            ";  Intro tiles, bonus HUD, room gfx-scripts, palettes, enemy/weapon RLE.",
            "; ===========================================================================",
        ],
        [
            "data/intro_tiles.asm",
            "data/bonus_hud_tiles.asm",
            "data/spike_bar.asm",
            "data/room_gfx.asm",
            "data/room_palettes.asm",
            "data/enemy_sprite_rle.asm",
            "data/vendor_tiles.asm",
            "data/stage_palettes.asm",
        ],
    )


# Packed music tails + env tables (seg15 0xA000-0xABF8).  ROM order.
MUSIC_SEG15 = [
    ("music_85_bgm_s10_18_b_cont", 0xA000, "tail of music_85_bgm_s10_18_b (EA 0x9F9C)"),
    ("music_85_bgm_s10_18_c", 0xA051, "85 C; stages 10 and 18"),
    ("music_86_bgm_boss_dracula_a", 0xA157, "86 A; Dracula boss"),
    ("music_86_bgm_boss_dracula_c", 0xA1B9, "86 C"),
    ("music_86_bgm_boss_dracula_b", 0xA217, "86 B"),
    ("music_87_bgm_boss_a", 0xA2C5, "87 A; boss"),
    ("music_87_bgm_boss_b", 0xA303, "87 B"),
    ("music_87_bgm_boss_c", 0xA35B, "87 C"),
    ("music_88_bgm_boss_dracula_portrait_a", 0xA39E, "88 A; Dracula portrait (CE01=4)"),
    ("music_88_bgm_boss_dracula_portrait_b", 0xA3E4, "88 B"),
    ("music_88_bgm_boss_dracula_portrait_c", 0xA43C, "88 C"),
    ("music_89_simon_death_a", 0xA49B, "89 A; Simon death"),
    ("music_89_simon_death_b", 0xA4B0, "89 B"),
    ("music_89_simon_death_c", 0xA4C4, "89 C"),
    ("music_8a_enter_castle_a", 0xA4D1, "8A A; enter castle"),
    ("music_8a_enter_castle_b", 0xA506, "8A B"),
    ("music_8a_enter_castle_c", 0xA51D, "8A C"),
    ("music_8b_game_over_a", 0xA54E, "8B A; game over"),
    ("music_8b_game_over_b", 0xA573, "8B B"),
    ("music_8b_game_over_c", 0xA5A5, "8B C"),
    ("music_8c_boss_defeated_a", 0xA5DF, "8C A; boss defeated"),
    ("music_8c_boss_defeated_b", 0xA5FD, "8C B"),
    ("music_8c_boss_defeated_c", 0xA621, "8C C"),
    ("music_8d_dracula_defeated_a", 0xA671, "8D A; Dracula defeated"),
    ("music_8d_dracula_defeated_b", 0xA68F, "8D B"),
    ("music_8d_dracula_defeated_c", 0xA6AA, "8D C"),
    ("music_8e_credits_a", 0xA6C4, "8E A; credits"),
    ("music_8e_credits_b", 0xA764, "8E B"),
    ("music_8e_credits_c", 0xA7FE, "8E C"),
    ("music_8f_silence", 0xA81F, "dummy silence (all three channels)"),
]

ENV_PTR_MAIN = [
    0xAB06, 0xAB0C, 0xAB1C, 0xAB2F, 0xAB45, 0xAB60,
    0xAB60, 0xAB60, 0xAB60, 0xAB60, 0xAB60, 0xAB60,
]
ENV_PTR_ALT = [
    0xAB60, 0xAB73, 0xAB73, 0xAB86, 0xAB99, 0xABAC,
    0xABBF, 0xABBF, 0xABD2, 0xABE5, 0xABF8, 0xABF8,
]


def env_name(cpu: int) -> str:
    if cpu == 0xABF8:
        return "dracula_frame_abf8"
    return "sound_env_%04x" % cpu


def emit_defw_names(ptrs: list[int]) -> list[str]:
    lines = []
    for i in range(0, len(ptrs), 4):
        chunk = ptrs[i : i + 4]
        lines.append("\tdefw " + ",".join(env_name(w) for w in chunk))
    return lines


def emit_seg15(rom: bytes) -> None:
    """Seg15: music tails, env tables, Dracula portrait, leftover tiles."""
    b15 = 15 * 0x2000
    bank15 = rom[b15 : b15 + 0x2000]
    assert len(bank15) == 0x2000

    def slurp(cpu: int, n: int) -> bytes:
        o = cpu - 0xA000
        return bank15[o : o + n]

    lines = [
        "; Packed PSG music tails (seg15 0xA000-0xA81F) + unused blob +",
        "; 12-word env pointer tables (sound_env_ptr / sound_env_ptr_alt)",
        "; and their 0xFF-ended streams.  music_85_bgm_s10_18_b_cont continues music_85_bgm_s10_18_b",
        "; from seg14.  Unidentified 0xA820-0xAAD5 is not in music_ptr.",
        "",
    ]
    cpu = 0xA000
    ends = [start for _, start, _ in MUSIC_SEG15[1:]] + [0xA820]
    for (label, start, comment), end in zip(MUSIC_SEG15, ends):
        assert start == cpu, "music gap at 0x%04X vs 0x%04X" % (start, cpu)
        size = end - start
        buf = slurp(start, size)
        extra = ("  ; %s" % comment) if comment else ""
        lines.append("%s:  ; 0x%04X  packed %d%s" % (label, start, size, extra))
        lines.extend(defb_lines(buf))
        cpu = end
    assert cpu == 0xA820, hex(cpu)

    unid = slurp(0xA820, 0xAAD6 - 0xA820)
    lines.append("")
    lines.append(
        "seg15_unid_a820:  ; 0xA820  %d bytes (not in music_ptr)" % len(unid)
    )
    lines.extend(defb_lines(unid))
    cpu = 0xAAD6

    def words_at(addr: int, n: int) -> list[int]:
        out = []
        for i in range(n):
            lo = slurp(addr + i * 2, 2)
            out.append(lo[0] | (lo[1] << 8))
        return out

    assert words_at(0xAAD6, 12) == ENV_PTR_MAIN
    assert words_at(0xAAEE, 12) == ENV_PTR_ALT
    lines.append("")
    lines.append("; 12 words; hi nibble of the env note * 2 indexes this.")
    lines.append("sound_env_ptr:  ; 0xAAD6")
    lines.extend(emit_defw_names(ENV_PTR_MAIN))
    lines.append("sound_env_ptr_alt:  ; 0xAAEE")
    lines.extend(emit_defw_names(ENV_PTR_ALT))

    env_starts = sorted(set(ENV_PTR_MAIN + ENV_PTR_ALT) - {0xABF8})
    cpu = 0xAB06
    assert env_starts[0] == cpu
    for i, start in enumerate(env_starts):
        assert start == cpu, "env gap at 0x%04X vs 0x%04X" % (start, cpu)
        end = env_starts[i + 1] if i + 1 < len(env_starts) else 0xABF8
        buf = slurp(start, end - start)
        assert buf[-1] == 0xFF
        lines.append(
            "%s:  ; 0x%04X  packed %d" % (env_name(start), start, len(buf))
        )
        lines.extend(defb_lines(buf))
        cpu = end
    assert cpu == 0xABF8, hex(cpu)
    write_lines(os.path.join(DATA, "psg_seg15.asm"), lines)

    n_face_tiles = 8 + 2 + 2 + 1 + 0x6C  # 121
    n_blank = 6
    portrait = slurp(0xABF8, (n_face_tiles + n_blank) * TILE)
    parts = slurp(0xBBD8, 8 * TILE16)
    pad = slurp(0xBFD8, 0xC000 - 0xBFD8)
    assert pad == b"\xff" * (0xC000 - 0xBFD8)
    assert 0xABF8 + len(portrait) == 0xBBD8
    assert 0xBBD8 + len(parts) == 0xBFD8

    write_tile_file(
        "dracula_portrait.asm",
        [
            "; Dracula portrait 8x8 4bpp (seg15 0xABF8): frame pieces then 108",
            "; face tiles, blit by dracula_portrait_load (seg0 0x5887) then",
            "; H-mirror.  6 blank 8x8 at 0xBB18 (gap before the 16x16 parts).",
            "; Uncompressed 8x8 4bpp (SCREEN 5).  Each defb is one pixel-row",
            "; (4 bytes, high nibble = left).  Eight rows = one tile (32 bytes).",
            "; Preview: gfx/tilesets/dracula_portrait.png (`make gfx`); cell header = CPU address.",
        ],
        portrait,
        0xABF8,
        [(0xABF8, "portrait"), (0xBB18, "unused")],
        [
            (0xABF8, "dracula_frame_abf8", "8 tiles -> VRAM 0x8018"),
            (0xACF8, "dracula_frame_acf8", "2 tiles -> VRAM 0x8040"),
            (0xAD38, "dracula_frame_ad38", "2 tiles -> VRAM 0x8060"),
            (0xAD78, "dracula_frame_ad78", "1 tile -> VRAM 0x8070 / mirror"),
            (0xAD98, "dracula_face", "108 tiles -> VRAM 0x8078"),
            (0xBB18, "dracula_unused_bb18", "6 blank 8x8; 16x16 parts follow"),
        ],
    )
    plines = [
        "; Dracula portrait 16x16 4bpp (seg15 0xBBD8): 4 eye + 4 mouth tiles.",
        "; Loaded to page-1 Y=0xA0 (eyes X=0..0x30, mouths X=0x40..0x70);",
        "; mouth copies are H-mirrored to X=128.",
        "; User-confirmed: 0xBBD8/0xBC58 eyes open, 0xBCD8/0xBD58 eyes closed,",
        "; 0xBDD8/0xBE58 mouth closed, 0xBED8/0xBF58 mouth open.  No mid-mouth tile.",
        "; Uncompressed 16x16 4bpp (SCREEN 5).  Each defb is one pixel-row",
        "; (8 bytes, high nibble = left).  Sixteen rows = one tile (128 bytes).",
        "; Preview: gfx/tilesets/dracula_portrait_parts.png (`make gfx`); cell header = CPU address.",
        "",
    ]
    plines.extend(
        emit_4bpp(
            parts,
            0xBBD8,
            [(0xBBD8, "eye", TILE16), (0xBDD8, "mouth", TILE16)],
            [
                (0xBBD8, "dracula_portrait_parts", "4 x 16x16 eyes -> page-1 Y=0xA0"),
                (0xBDD8, "dracula_portrait_parts_hi", "4 x 16x16 mouth; H-mirrored to X=128"),
            ],
        )
    )
    plines.append("")
    plines.append("; 0xFF pad to end of seg15 (0xBFD8).")
    plines.extend(defb_lines(pad))
    write_lines(os.path.join(DATA, "dracula_portrait_parts.asm"), plines)
    # Banks 14-15 are one PHASE in VampireKiller.asm; INCLUDEs live at the
    # end of banks_ef.asm (hand-maintained).


def main() -> None:
    rom = load_rom()
    os.makedirs(DATA, exist_ok=True)
    emit_mtile_streams(rom)
    emit_mtile_defs(rom)
    emit_tileset_banks(rom)
    emit_credits_font(rom)
    emit_simon_rle(rom)
    emit_seg13_gaps(rom)
    emit_psg_streams(rom)
    emit_seg9_10(rom)
    emit_seg15(rom)


if __name__ == "__main__":
    main()

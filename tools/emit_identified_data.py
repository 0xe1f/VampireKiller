#!/usr/bin/env python3
"""One-shot: dump identified ROM blobs to labeled .asm (Metal Gear-style).

Reads references/VampireKiller.rom.  The generated files are the assemble
source; the ROM is not needed to *build*, only to regenerate this dump or
to `make verify`.

  python3 tools/emit_identified_data.py
"""
from __future__ import annotations

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROM_PATH = os.path.join(ROOT, "references", "VampireKiller.rom")
DATA = os.path.join(ROOT, "segments", "data")
SEGS = os.path.join(ROOT, "segments")

# rledec.py lives next to this script.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rledec import decompress  # noqa: E402

COLS = 16
TILE = 32
NTILES = 0xBF
TILESET_BYTES = NTILES * TILE  # 0x17E0


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
    """One 8px 1bpp row; MSB = left. Same form as credits_font."""
    return "%%%s" % format(b, "08b")


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


def pix4_row(four: bytes) -> str:
    """One SCREEN 5 8-pixel row as 4 bytes (high nibble = left)."""
    return "\tdefb " + ",".join("0x%02x" % b for b in four)


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
    origins: list[tuple[int, str]],
    labels: list[tuple[int, str, str]] | None = None,
) -> list[str]:
    """Emit 8x8 4bpp tiles as hex pixel-rows.  labels: (cpu, name, comment)."""
    lab = {cpu: (name, comment) for cpu, name, comment in (labels or [])}
    orig_sorted = sorted(origins) or [(cpu0, "raw")]
    lines: list[str] = []
    i = 0
    while i < len(buf):
        cpu = cpu0 + i
        if cpu in lab:
            name, comment = lab[cpu]
            lines.append("%s:  ; 0x%04X  %s" % (name, cpu, comment))
        origin, tname = orig_sorted[0]
        for o, n in orig_sorted:
            if o <= cpu:
                origin, tname = o, n
        rel = cpu - origin
        left = len(buf) - i
        if rel >= 0 and rel % TILE == 0 and left >= TILE:
            tid = rel // TILE
            if tid < NTILES:
                extra = "%s tile 0x%02X" % (tname, tid)
            else:
                extra = "%s +0x%02X (past 0xBF blit)" % (tname, tid)
            lines.append("; 0x%04X  %s" % (cpu, extra))
            for r in range(8):
                lines.append(pix4_row(buf[i + r * 4 : i + r * 4 + 4]))
            i += TILE
            continue
        if left >= 4:
            lines.append(pix4_row(buf[i : i + 4]) + "  ; 0x%04X" % cpu)
            i += 4
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
    origins: list[tuple[int, str]],
    labels: list[tuple[int, str, str]] | None = None,
) -> None:
    lines = list(header)
    if lines and lines[-1] != "":
        lines.append("")
    lines += emit_4bpp(buf, cpu0, origins, labels)
    write_lines(os.path.join(DATA, fname), lines)


def emit_tileset_banks(rom: bytes) -> None:
    """Split overlapping tilesets into data/ files; segs become INCLUDE stitchers.

    Sets overlap and spill across banks, so files are non-overlapping ROM
    slices, not complete 0xBF-tile copies.
    """
    b4 = bank(rom, 4)
    b5 = bank(rom, 5)
    b6 = bank(rom, 6)
    b7 = bank(rom, 7)
    b8 = bank(rom, 8)

    pixnote = [
        "; Uncompressed 8x8 4bpp (SCREEN 5).  Each defb is one pixel-row",
        "; (4 bytes, high nibble = left).  Eight rows = one tile (32 bytes).",
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
        ["; Stages 1-3 tileset start (seg4 0x7220).  Continues in tileset_s01_cont."]
        + slicenote,
        b4[0x1220:],
        0x7220,
        [(0x7220, "s01")],
        [(0x7220, "tileset_s01", "stages 1-3; continues into seg5")],
    )
    write_tile_file(
        "tileset_s01_cont.asm",
        ["; tileset_s01 continued (seg5 0x8000-0x82BF).  Staff text follows."] + slicenote,
        b5[0:0x02C0],
        0x8000,
        [(0x7220, "s01")],
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
        ["; Stages 4-6 tileset start (seg5 0x95B3).  Continues in tileset_s10_cont."]
        + slicenote,
        b5[0x15B3:0x1E73],
        0x95B3,
        [(0x95B3, "s04")],
        [(0x95B3, "tileset_s04", "stages 4-6; spills into seg6")],
    )
    write_tile_file(
        "tileset_s10.asm",
        ["; Stages 10-12 tileset start (seg5 0x9E73).  Continues in tileset_s10_cont."]
        + slicenote,
        b5[0x1E73:],
        0x9E73,
        [(0x9E73, "s10")],
        [(0x9E73, "tileset_s10", "stages 10-12; spills into seg6")],
    )
    write_tile_file(
        "tileset_s10_cont.asm",
        [
            "; tileset_s10 continued (seg6 0xA000-0xB9C7), including s04 tail overlap",
            "; then leftover bytes before HUD keys/weapons.",
        ]
        + slicenote,
        b6[0:0x19C8],
        0xA000,
        [(0x95B3, "s04"), (0x9E73, "s10")],
    )
    write_tile_file(
        "hud_weapon_key_tiles.asm",
        ["; HUD keys/weapons (seg6 0xB9C8), copied to VRAM 0xD9C8 after sub_53a5h."]
        + pixnote,
        b6[0x19C8:],
        0xB9C8,
        [(0xB9C8, "hud")],
        [(0xB9C8, "hud_weapon_key_tiles", "HUD keys/weapons 8x8 4bpp")],
    )
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
        ["; Stages 16-17 tileset start (seg7 0x9640).  Continues in tileset_s16_cont."]
        + slicenote,
        b7[0x1640:],
        0x9640,
        [(0x9640, "s16")],
        [(0x9640, "tileset_s16", "stages 16-17; spills into seg8")],
    )
    write_tile_file(
        "tileset_s16_cont.asm",
        ["; tileset_s16 continued (seg8 0xA000-0xA4BF)."] + slicenote,
        b8[0:0x04C0],
        0xA000,
        [(0x9640, "s16")],
    )
    write_tile_file(
        "tileset_s18.asm",
        [
            "; Stage 18 tileset (seg8 0xA4C0) plus title glyphs overlaid on high ids:",
            "; castle 0xAC80 (0x11), kana 0xAEA0 (0x1E), CASTLEVANIA 0xB260 (0x59).",
        ]
        + slicenote,
        b8[0x04C0:0x1F20],
        0xA4C0,
        [
            (0xA4C0, "s18"),
            (0xAC80, "castle"),
            (0xAEA0, "jp"),
            (0xB260, "en"),
        ],
        [
            (0xA4C0, "tileset_s18", "stage 18 (Dracula); 0xBF tiles"),
            (0xAC80, "title_castle_tiles", "shared castle emblem (title_load_tiles)"),
            (0xAEA0, "title_logo_jp_tiles", "title kana glyphs"),
            (0xB260, "title_logo_en_tiles", "title CASTLEVANIA glyphs"),
        ],
    )
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
        write_lines(path, lines)

    stitch(
        os.path.join(SEGS, "seg04.asm"),
        [
            "; ===========================================================================",
            ";  SEGMENT 4 - tileset bank, paged at 0x6000 by sub_53a5h (page 1b).",
            ";  Pixel source: data/tileset_s00.asm + data/tileset_s01.asm.",
            "; ===========================================================================",
        ],
        ["data/tileset_s00.asm", "data/tileset_s01.asm"],
    )
    stitch(
        os.path.join(SEGS, "seg05.asm"),
        [
            "; ===========================================================================",
            ";  SEGMENT 5 - tileset bank, paged at 0x8000 by sub_53a5h / credits_keyframe.",
            ";  s01 tail, staff roll (unused high tile ids), then s07 / s04 / s10.",
            "; ===========================================================================",
        ],
        [
            "data/tileset_s01_cont.asm",
            "credits_staff.asm",
            "data/tileset_s07.asm",
            "data/tileset_s04.asm",
            "data/tileset_s10.asm",
        ],
    )
    stitch(
        os.path.join(SEGS, "seg06.asm"),
        [
            "; ===========================================================================",
            ";  SEGMENT 6 - tileset bank, paged at 0xA000 by sub_53a5h (page 2b).",
            ";  s10 tail, then HUD weapon/key tiles at 0xB9C8.",
            "; ===========================================================================",
        ],
        ["data/tileset_s10_cont.asm", "data/hud_weapon_key_tiles.asm"],
    )
    stitch(
        os.path.join(SEGS, "seg07.asm"),
        [
            "; ===========================================================================",
            ";  SEGMENT 7 - late-game tileset bank, paged at 0x8000 by sub_5393h",
            ";  (stage >= 13 overlays the 0x8000 window).",
            "; ===========================================================================",
        ],
        ["data/tileset_s13.asm", "data/tileset_s16.asm"],
    )
    stitch(
        os.path.join(SEGS, "seg08.asm"),
        [
            "; ===========================================================================",
            ";  SEGMENT 8 - late-game tileset + title glyphs + ending paragraph.",
            ";  Paged at 0xA000 by sub_5393h (tiles) and credits_keyframe (text).",
            "; ===========================================================================",
        ],
        [
            "data/tileset_s16_cont.asm",
            "data/tileset_s18.asm",
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
    0xB5A1-0xB894 is figure Dracula body (dracula_body_closed/open); the 0xBBF6 tail is hex in emit_seg13_gaps.
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
        "; Packed 1bpp sprite RLE (sub_46f8h), CPU 0xA319-0xB5A1.",
        "; Pixel bytes are defb %xxxxxxxx (MSB=left, one 8px row of an 8x8",
        "; cell; VRAM order TL/BL/TR/BR per 16x16).  Run/literal counts stay",
        "; hex so the packed stream is byte-exact.",
        "; Pointers: simon_cell0_ptr (0xA281), simon_cell1_ptr (0xA2D1),",
        "; intro load at 0x5682 (intro_simon_0..7).  Six orphan streams are",
        "; the second 16x16 plane after a listed frame; not in those tables.",
        "; PNG previews: gfx/intro_simon, gfx/simon_cell0, gfx/simon_cell1.",
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
        "; 8 cloud patterns + 2-frame bat flap.  gfx/intro_sky.",
        "; Pixel bytes are defb %xxxxxxxx (MSB=left); counts stay hex.",
        "intro_sky:",
    ]
    lines.extend(emit_rle_1bpp(sky))
    write_lines(os.path.join(DATA, "intro_sky.asm"), lines)


def emit_seg13_gaps(rom: bytes) -> None:
    """Figure-Dracula 32x32 body (packed 4bpp) plus the unidentified tail."""
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
    write_lines(os.path.join(DATA, "seg13_b5a1.asm"), lines)

    tail = rom[b13 + (0xBBF6 - 0xA000) : b13 + 0x2000]
    assert len(tail) == 0x040A
    lines = [
        "; Remainder of seg13 after spot_tbl (0xBBF6-0xBFFF). Unreversed.",
        "seg13_tail_bbf6:  ; 0xBBF6",
    ]
    lines.extend(defb_lines(tail))
    write_lines(os.path.join(DATA, "seg13_bbf6.asm"), lines)


# Packed PSG (sfx + music that still fits in seg14).  label "" = no label.
# (label, cpu, size, comment) — ROM order, contiguous 0x8E29-0xA000.
PSG_STREAMS = [
    ("", 0x8E29, 0x0002, "unused 1F A8 (= 0xA81F dummy)"),
    ("sfx_01", 0x8E2B, 0x002D, "placed-enemy / grunt"),
    ("sfx_02", 0x8E58, 0x0011, "vendor offer withdrawn"),
    ("sfx_1d", 0x8E69, 0x0021, "vendor take hearts"),
    ("sfx_03", 0x8E8A, 0x000F, "projectile tick"),
    ("sfx_04", 0x8E99, 0x0015, "axe throw"),
    ("sfx_05", 0x8EAE, 0x001D, "whip"),
    ("sfx_06", 0x8ECB, 0x0019, "axe fly"),
    ("sfx_07", 0x8EE4, 0x000F, "jump"),
    ("sfx_08", 0x8EF3, 0x0032, ""),
    ("sfx_09", 0x8F25, 0x0031, "door / stair"),
    ("sfx_0a", 0x8F56, 0x001F, ""),
    ("sfx_0b", 0x8F75, 0x0044, "Simon hurt"),
    ("sfx_0c", 0x8FB9, 0x0024, "hit"),
    ("sfx_0d", 0x8FDD, 0x0051, "kill"),
    ("sfx_0e", 0x902E, 0x0037, ""),
    ("sfx_0f", 0x9065, 0x0035, "heart"),
    ("sfx_10", 0x909A, 0x002D, "vendor leave / money bag"),
    ("sfx_11", 0x90C7, 0x001F, ""),
    ("sfx_12", 0x90E6, 0x0051, "collect / purchase"),
    ("sfx_13", 0x9137, 0x001B, ""),
    ("sfx_14", 0x9152, 0x0027, "yellow key"),
    ("sfx_15", 0x9179, 0x0099, "portal flash"),
    ("sfx_16", 0x9212, 0x0063, "blue gem"),
    ("sfx_17", 0x9275, 0x0063, ""),
    ("sfx_18", 0x92D8, 0x0042, "stair / land"),
    ("sfx_1a", 0x931A, 0x0085, ""),
    ("sfx_1c", 0x939F, 0x002B, ""),
    ("sfx_1b", 0x93CA, 0x0099, "white cross"),
    ("snd_fd_seq", 0x9463, 0x000D, ""),
    ("sfx_19", 0x9470, 0x001B, "vendor offer"),
    ("snd_fb_seq", 0x948B, 0x0010, ""),
    ("music_80a", 0x949B, 0x0066, "stages 0-3"),
    ("music_80b", 0x9501, 0x0097, "stages 0-3"),
    ("music_80c", 0x9598, 0x00D1, "stages 0-3"),
    ("music_81a", 0x9669, 0x005E, "stages 4-6 and 11-12"),
    ("music_81b", 0x96C7, 0x00A6, "stages 4-6 and 11-12"),
    ("music_81c", 0x976D, 0x006D, "stages 4-6 and 11-12"),
    ("music_82a", 0x97DA, 0x00B7, "stages 7-9"),
    ("music_82b", 0x9891, 0x00AC, "stages 7-9"),
    ("music_82c", 0x993D, 0x011B, "stages 7-9"),
    ("music_83a", 0x9A58, 0x0060, "stages 16-17"),
    ("music_83b", 0x9AB8, 0x00B2, "stages 16-17"),
    ("music_83c", 0x9B6A, 0x00AB, "stages 16-17"),
    ("music_84a", 0x9C15, 0x00C6, "stages 13-15"),
    ("music_84b", 0x9CDB, 0x011D, "stages 13-15"),
    ("music_84c", 0x9DF8, 0x00C9, "stages 13-15"),
    ("music_85a", 0x9EC1, 0x00C8, "stages 10 and 18"),
    ("music_85b", 0x9F89, 0x0077, "stages 10 and 18; continues at music_85b_cont"),
]


def emit_psg_streams(rom: bytes) -> None:
    """Labeled packed PSG sequences (sfx_tbl / music_ptr bodies in seg14)."""
    b14 = 14 * 0x2000
    lines = [
        "; Packed PSG streams (seg14 0x8E29-0x9FFF).  sfx_tbl / music_ptr /",
        "; snd_fb_seq / snd_fd_seq.  Music 85b continues in data/psg_seg15.asm;",
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

PAL_NAMES = {
    0xBF6F: "title_extra_palette",
    0xBF88: "hud_fixed_palette",
    0xBFA1: "pal_bfa1",
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
    """Decode l4845h palettes from start until end (exclusive)."""
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

    # --- frontend 4bpp 0x8000-0x9A80 + 0x9A80-0x9AB0 tail ---
    write_tile_file(
        "frontend_tiles.asm",
        [
            "; Frontend / HUD 8x8 4bpp (seg9 0x8000).  load after sub_5381h:",
            "; `ld hl,frontend_tiles` / tileset_blit copies 0xBF tiles (to 0x97E0).",
            "; Bonus HUD ids 1-20 reuse tile 0x80+ (0x9000); potion at 0x9A00.",
        ]
        + [
            "; Uncompressed 8x8 4bpp (SCREEN 5).  Each defb is one pixel-row",
            "; (4 bytes, high nibble = left).  Eight rows = one tile (32 bytes).",
        ],
        b9[0:0x1A80],
        0x8000,
        [(0x8000, "frontend"), (0x9000, "bonus"), (0x9A00, "potion")],
        [
            (0x8000, "frontend_tiles", "0xBF tiles for title/HUD blit"),
            (0x9000, "bonus_hud_tiles", "bonus ids 1-20 (16x16 = 4 tiles each)"),
            (0x9A00, "bonus_hud_potion", "bonus id 22"),
        ],
    )
    tail = b9[0x1A80:0x1AB0]
    assert len(tail) == 0x30
    tlines = [
        "; 0x9A80-0x9AAF: extra HUD blits (sub_4991h from 0x9A80 / 0x9A90).",
        "bonus_hud_9a80:  ; 0x9A80",
    ]
    tlines.extend(defb_lines(tail[:0x10]))
    tlines.append("bonus_hud_9a90:  ; 0x9A90")
    tlines.extend(defb_lines(tail[0x10:]))
    write_lines(os.path.join(DATA, "bonus_hud_9a80.asm"), tlines)

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
        "; l4845h tables: (index, rb, g)+ 0xFF.  Ends where gfx RLE starts (0xA066).",
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
        "",
    ]
    cpu = 0xA066
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
            0xB051: "actor_blob_blue/_red/_white fill (FE80/FE00/FB80/FD00)",
            0xB07A: "actor_blob_blue/_red/_white SAT CC outline",
            0xA0EA: "vertical door (load_vdoor_sprites)",
            0xA147: "title/frontend (VRAM 0xF9C0)",
            0xA185: "VRAM 0xFF00 (fireball at +0x80 = SAT 0xF0)",
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

    # --- 0xBDA7-0xBEA6 unidentified, then BEA7 palettes + 0xFF pad ---
    unid = bytes(peek(rom, i) for i in range(0xBDA7, 0xBEA7))
    ulines = [
        "; Unidentified (seg10 0xBDA7-0xBEA6).  Not a valid RLE stream.",
        "seg10_unid_bda7:  ; 0xBDA7",
    ]
    ulines.extend(defb_lines(unid))
    write_lines(os.path.join(DATA, "seg10_bda7.asm"), ulines)

    slines = [
        "; Stage palette pointer table (seg10 0xBEA7) + l4845h tables.",
        "; sub_572eh loads hud_fixed_palette; title extras at 0xBF6F.",
        "stage_palette_ptr:",
    ]
    for st in range(19):
        cpu_p = word_at(rom, 0xBEA7 + st * 2)
        slines.append(
            "\tdefw %s  ; stage %d" % (pal_name(cpu_p), st)
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
        write_lines(path, out)

    stitch(
        os.path.join(SEGS, "seg09.asm"),
        [
            "; ===========================================================================",
            ";  SEGMENT 9 - front-end gfx bank, paged at 0x8000 by sub_5381h.",
            ";  HUD/frontend tiles, room_gfx_ptr + scripts, pal_9ffe prefix.",
            "; ===========================================================================",
        ],
        [
            "data/frontend_tiles.asm",
            "data/bonus_hud_9a80.asm",
            "data/room_gfx.asm",
        ],
    )
    stitch(
        os.path.join(SEGS, "seg10.asm"),
        [
            "; ===========================================================================",
            ";  SEGMENT 10 - front-end gfx bank, paged at 0xA000 by sub_5381h.",
            ";  Room palettes, enemy/weapon RLE, stage palettes.",
            "; ===========================================================================",
        ],
        [
            "data/room_palettes.asm",
            "data/enemy_sprite_rle.asm",
            "data/seg10_bda7.asm",
            "data/stage_palettes.asm",
        ],
    )


# Packed music tails + env tables (seg15 0xA000-0xABF8).  ROM order.
MUSIC_SEG15 = [
    ("music_85b_cont", 0xA000, "tail of music_85b (EA 0x9F9C)"),
    ("music_85c", 0xA051, "85 C; stages 10 and 18"),
    ("music_86a", 0xA157, "86 A; Dracula boss"),
    ("music_86c", 0xA1B9, "86 C"),
    ("music_86b", 0xA217, "86 B"),
    ("music_87a", 0xA2C5, "87 A; boss"),
    ("music_87b", 0xA303, "87 B"),
    ("music_87c", 0xA35B, "87 C"),
    ("music_88a", 0xA39E, "88 A; Dracula portrait (CE01=4)"),
    ("music_88b", 0xA3E4, "88 B"),
    ("music_88c", 0xA43C, "88 C"),
    ("music_89a", 0xA49B, "89 A; game over (simon_dying)"),
    ("music_89b", 0xA4B0, "89 B"),
    ("music_89c", 0xA4C4, "89 C"),
    ("music_8aa", 0xA4D1, "8A A; enter castle"),
    ("music_8ab", 0xA506, "8A B"),
    ("music_8ac", 0xA51D, "8A C"),
    ("music_8ba", 0xA54E, "8B A; game over"),
    ("music_8bb", 0xA573, "8B B"),
    ("music_8bc", 0xA5A5, "8B C"),
    ("music_8ca", 0xA5DF, "8C A; boss defeated"),
    ("music_8cb", 0xA5FD, "8C B"),
    ("music_8cc", 0xA621, "8C C"),
    ("music_8da", 0xA671, "8D A; Dracula defeated"),
    ("music_8db", 0xA68F, "8D B"),
    ("music_8dc", 0xA6AA, "8D C"),
    ("music_8ea", 0xA6C4, "8E A; credits"),
    ("music_8eb", 0xA764, "8E B"),
    ("music_8ec", 0xA7FE, "8E C"),
    ("music_8f", 0xA81F, "dummy silence (all three channels)"),
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
        "; and their 0xFF-ended streams.  music_85b_cont continues music_85b",
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
    portrait = slurp(0xABF8, n_face_tiles * TILE)
    unused_n = 38
    unused = slurp(0xBB18, unused_n * TILE)
    pad = slurp(0xBFD8, 0xC000 - 0xBFD8)
    assert pad == b"\xff" * (0xC000 - 0xBFD8)
    assert 0xABF8 + len(portrait) == 0xBB18
    assert 0xBB18 + len(unused) == 0xBFD8

    plines = [
        "; Dracula portrait (seg15).  Uncompressed 8x8 4bpp, blit by",
        "; dracula_portrait_load (seg0 0x5887): frame pieces then 108 face",
        "; tiles, then H-mirror.  6 blank 8x8 at 0xBB18, then 8 x 16x16",
        "; eye/mouth 16x16s at 0xBBD8 (page-1 Y=0xA0).  0xFF pad to end of bank.",
        "",
    ]
    plines.extend(
        emit_4bpp(
            portrait,
            0xABF8,
            [(0xABF8, "portrait")],
            [
                (0xABF8, "dracula_frame_abf8", "8 tiles -> VRAM 0x8018"),
                (0xACF8, "dracula_frame_acf8", "2 tiles -> VRAM 0x8040"),
                (0xAD38, "dracula_frame_ad38", "2 tiles -> VRAM 0x8060"),
                (0xAD78, "dracula_frame_ad78", "1 tile -> VRAM 0x8070 / mirror"),
                (0xAD98, "dracula_face", "108 tiles -> VRAM 0x8078"),
            ],
        )
    )
    plines.append("")
    plines.extend(
        emit_4bpp(
            unused,
            0xBB18,
            [(0xBB18, "unused"), (0xBBD8, "parts")],
            [
                (0xBB18, "dracula_unused_bb18", "6 blank 8x8; eye/mouth 16x16s follow"),
                (0xBBD8, "dracula_portrait_parts", "8 x 16x16 4bpp eyes/mouth -> page-1 Y=0xA0"),
                (0xBDD8, "dracula_portrait_parts_hi", "tiles 4-7 (mouth); H-mirrored to X=128"),
            ],
        )
    )
    plines.append("")
    plines.append("; 0xFF pad to end of seg15 (0xBFD8).")
    plines.extend(defb_lines(pad))
    write_lines(os.path.join(DATA, "dracula_portrait.asm"), plines)

    stitch_lines = [
        "; ===========================================================================",
        ";  SEGMENT 15 - paged at 0xA000 by int_handler / play_sound (with seg14",
        ";  at 0x8000).  Music tails, env tables, Dracula portrait.",
        "; ===========================================================================",
        "",
        '    INCLUDE "data/psg_seg15.asm"',
        "",
        '    INCLUDE "data/dracula_portrait.asm"',
        "",
    ]
    write_lines(os.path.join(SEGS, "seg15.asm"), stitch_lines)


def main() -> None:
    rom = load_rom()
    os.makedirs(DATA, exist_ok=True)
    emit_mtile_streams(rom)
    emit_mtile_defs(rom)
    emit_tileset_banks(rom)
    emit_simon_rle(rom)
    emit_seg13_gaps(rom)
    emit_psg_streams(rom)
    emit_seg9_10(rom)
    emit_seg15(rom)


if __name__ == "__main__":
    main()

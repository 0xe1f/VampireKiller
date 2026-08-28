#!/usr/bin/env python3
# Copyright 2026 Akop Karapetyan
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Render Vampire Killer BGM and SFX via tools/disasm/psgplay.py.

Reads the rebuilt VampireKiller.rom (segs 14/15 paged at 0x8000/0xA000)
and writes 16-bit mono WAVs into music/ (BGM) or sfx/ (ids 1-0x1D).

Usage (from repo root):
  python3 tools/psgplay.py              # all ids 0x80-0x8E -> music/
  python3 tools/psgplay.py --id 0x80
  python3 tools/psgplay.py --sfx         # all sfx 0x01-0x1D -> sfx/
  python3 tools/psgplay.py --sfx --id 5
"""
from __future__ import annotations

import argparse
import os
import sys

_TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_TOOLS, "disasm"))
import psgplay  # noqa: E402

ROOT = os.path.dirname(_TOOLS)
MUSIC = os.path.join(ROOT, "music")
SFX_DIR = os.path.join(ROOT, "sfx")

# play_sound tables while segs 14/15 are paged at 0x8000/0xA000.
MAP = psgplay.BankMap([(0x8000, 14), (0xA000, 15)])
TABLES = psgplay.Tables(
    music_ptr=0x8DC9,   # music_ptr; id 0x80 is record 0
    sfx_ptr=0x8D8D,     # play_sound indexes id*2; id 1 -> sfx_tbl
    env_ptr=0xAAD6,
    env_ptr_alt=0xAAEE,
    note_tbl=0x8B81,    # sound_note_tbl (odd-aligned; add nibble*2 to L)
)

# Call-site names (play_sound).  Every 1..0x1D is used.
SFX = {
    0x01: "01_boss_heal",
    0x02: "02_vendor_withdraw",
    0x03: "03_cross_fly",
    0x04: "04_knife_throw",
    0x05: "05_whip",
    0x06: "06_axe_fly",
    0x07: "07_land",
    0x08: "08_merman_out",
    0x09: "09_water_in",
    0x0A: "0A_mummy_shot",
    0x0B: "0B_shield_block",
    0x0C: "0C_hit",
    0x0D: "0D_ring_kill",
    0x0E: "0E_block_break",
    0x0F: "0F_heart",
    0x10: "10_money_bag",
    0x11: "11_chest",
    0x12: "12_collect",
    0x13: "13_simon_hurt",
    0x14: "14_key",
    0x15: "15_portal",
    0x16: "16_blue_gem",
    0x17: "17_gem_warn",
    0x18: "18_holy_water",
    0x19: "19_vendor_offer",
    0x1A: "1A_door",
    0x1B: "1B_white_cross",
    0x1C: "1C_boss_clear",
    0x1D: "1D_vendor_hearts",
}

TRACKS = {
    0x80: "80_bgm_s00-03",
    0x81: "81_bgm_s04-06_11_12",
    0x82: "82_bgm_s07-09",
    0x83: "83_bgm_s16-17",
    0x84: "84_bgm_s13-15",
    0x85: "85_bgm_s10_18",
    0x86: "86_bgm_boss_dracula",
    0x87: "87_bgm_boss",
    0x88: "88_bgm_boss_dracula_portrait",
    0x89: "89_simon_death",
    0x8A: "8A_enter_castle",
    0x8B: "8B_game_over",
    0x8C: "8C_boss_defeated",
    0x8D: "8D_dracula_defeated",
    0x8E: "8E_credits",
}


def load_rom() -> bytes:
    path = os.path.join(ROOT, "VampireKiller.rom")
    if not os.path.isfile(path):
        sys.exit("no ROM: run make to produce VampireKiller.rom")
    data = open(path, "rb").read()
    if len(data) != 0x20000:
        sys.exit("expected 128 KiB ROM at %s (got %d)" % (path, len(data)))
    return data


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--sfx", action="store_true", help="render sfx ids 0x01-0x1D into sfx/")
    ap.add_argument("--id", type=lambda s: int(s, 0), help="single id (0x80-0x8E, or 1-0x1D with --sfx)")
    ap.add_argument("--loops", type=int, default=2, help="EA-loop repeats before fade (BGM)")
    ap.add_argument("--min-seconds", type=float, default=20.0, help="play at least this long if the track loops")
    ap.add_argument("--seconds", type=float, default=None, help="hard cap (default 90 BGM / 4 sfx)")
    ap.add_argument("--rate", type=int, default=22050)
    ap.add_argument("-o", "--out", default=None)
    args = ap.parse_args()

    rom = load_rom()
    if args.sfx:
        ids = [args.id] if args.id is not None else list(range(1, 0x1E))
        for i in ids:
            if not 1 <= i <= 0x1D:
                sys.exit("sfx id 0x%02X out of range 0x01-0x1D" % i)
        psgplay.run(
            rom, MAP, TABLES, ids,
            sfx=True, names=SFX, out_dir=args.out or SFX_DIR,
            rate=args.rate, seconds=args.seconds,
        )
        return

    ids = [args.id] if args.id is not None else sorted(TRACKS)
    for i in ids:
        if i == 0x8F:
            continue
        if i not in TRACKS:
            sys.exit("unknown id 0x%02X (want 0x80-0x8E, or --sfx)" % i)
    ids = [i for i in ids if i in TRACKS]
    psgplay.run(
        rom, MAP, TABLES, ids,
        names=TRACKS, out_dir=args.out or MUSIC,
        rate=args.rate, loops=args.loops,
        min_seconds=args.min_seconds, seconds=args.seconds,
    )


if __name__ == "__main__":
    main()

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

"""Per-segment z80dasm symbol files, because segments/msx.sym is flat.

z80dasm -S maps CPU address -> one name. The ROM is banked, so two different
things at 0x902E (seg2 spike_bars_restore vs. the seg14 SFX stream) cannot both
win in a single file. This tool emits a filtered .sym for one segment:

  * BIOS (addr < 0x4000) always, so call RDSLT still names.
  * msx.sym names whose address sits *outside* this bank's 8 KiB window, so
    cross-bank `call hurt_simon_spikes` still names when regenerating seg1.
  * Real labels defined in this segment (and its INCLUDEs), looked up in the
    assembled symbol table — including names that were kept out of msx.sym
    because of a collision.

Auto labels (lXXXXh / sub_XXXXh) are left to z80dasm.

Usage:
  tools/disasm/seg_sym.py 2                 # write generated/seg02.z80dasm.sym
  tools/disasm/seg_sym.py --audit           # print cross-bank collisions
"""
from __future__ import annotations

import argparse
import collections
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SEGMENTS = ROOT / "segments"
GENERATED = ROOT / "generated"
MSX_SYM = SEGMENTS / "msx.sym"
ALL_SYM = GENERATED / "all.sym"
LISTING = GENERATED / "vk.lst"
ASM = ROOT / "VampireKiller.asm"
SJASM = ROOT / "tools" / "sjasmplus"

# PHASE origin per 8 KiB segment (VampireKiller.asm). Window = origin .. +0x2000.
SEG_ORG = {
    0: 0x4000, 1: 0x6000, 2: 0x8000, 3: 0xA000,
    4: 0x6000, 5: 0x8000, 6: 0xA000, 7: 0x8000,
    8: 0xA000, 9: 0x8000, 10: 0xA000, 11: 0x6000,
    12: 0x8000, 13: 0xA000, 14: 0x8000, 15: 0xA000,
}

INCLUDE_RE = re.compile(r'^\s*INCLUDE\s+"([^"]+)"', re.I | re.M)
LABEL_RE = re.compile(r"^[ \t]*([A-Za-z_][A-Za-z0-9_]*):")
EQU_RE = re.compile(r"^([A-Za-z_][\w]*):\s*equ\s+0x([0-9a-fA-F]+)", re.I)
AUTO_RE = re.compile(r"^(l|sub_)[0-9a-f]{4}h$", re.I)
LST_OPEN = re.compile(r"^# file opened:\s+(\S+)")
LST_CLOSE = re.compile(r"^# file closed:\s+(\S+)")
LST_LABEL = re.compile(r"^\s*\d+\++\s*([0-9A-Fa-f]{4})\s+([A-Za-z_][\w]*):")


def is_auto(name: str) -> bool:
    return bool(AUTO_RE.match(name))


def window(seg: int) -> tuple[int, int]:
    org = SEG_ORG[seg]
    return org, org + 0x2000


def assemble(need_lst: bool = False) -> None:
    GENERATED.mkdir(exist_ok=True)
    cmd = [str(SJASM), "--longptr", f"--sym={ALL_SYM}", str(ASM)]
    if need_lst:
        cmd[2:2] = [f"--lst={LISTING}"]
    subprocess.check_call(cmd, cwd=ROOT, stdout=subprocess.DEVNULL)


def load_all_sym() -> dict[str, int]:
    if not ALL_SYM.exists():
        assemble()
    out: dict[str, int] = {}
    for line in ALL_SYM.read_text().splitlines():
        m = EQU_RE.match(line)
        if m:
            out[m.group(1)] = int(m.group(2), 16)
    return out


def load_msx_sym() -> list[tuple[str, int, str]]:
    """[(name, addr, original_line_without_newline), ...]"""
    rows = []
    for line in MSX_SYM.read_text().splitlines():
        m = EQU_RE.match(line)
        if not m:
            continue
        rows.append((m.group(1), int(m.group(2), 16), line))
    return rows


def iter_segment_files(seg: int):
    start = SEGMENTS / f"seg{seg:02d}.asm"
    seen: set[Path] = set()
    stack = [start]
    while stack:
        path = stack.pop()
        if path in seen or not path.exists():
            continue
        seen.add(path)
        yield path
        text = path.read_text(errors="replace")
        for m in INCLUDE_RE.finditer(text):
            stack.append((path.parent / m.group(1)).resolve())


def local_labels(seg: int) -> set[str]:
    names: set[str] = set()
    for path in iter_segment_files(seg):
        for line in path.read_text(errors="replace").splitlines():
            m = LABEL_RE.match(line)
            if m:
                names.add(m.group(1))
    return names


def emit_segment(seg: int) -> str:
    lo, hi = window(seg)
    all_sym = load_all_sym()
    local = local_labels(seg)
    msx = load_msx_sym()
    chosen: dict[int, tuple[str, str]] = {}
    msx_names_at: dict[int, list[str]] = collections.defaultdict(list)
    for name, addr, _orig in msx:
        msx_names_at[addr].append(name)

    def put(name: str, addr: int, comment: str = "") -> None:
        if addr >= 0xC000:
            return
        line = f"{name}: equ 0x{addr:04x}"
        if comment:
            line += "\t" + comment
        chosen[addr] = (name, line)

    for name, addr, orig in msx:
        if addr < 0x4000:
            put(name, addr)
            continue
        if lo <= addr < hi:
            continue  # local window: only this bank's labels, below
        # Ambiguous out-of-window: two msx.sym names share the address
        # (pickup_tick vs sound_mix_both_tbl). Leave it numeric.
        if len(msx_names_at[addr]) > 1:
            continue
        put(name, addr)

    for name in sorted(local):
        if is_auto(name) or name not in all_sym:
            continue
        addr = all_sym[name]
        if not (lo <= addr < hi):
            continue
        put(name, addr)

    lines = [
        f"; z80dasm -S file for segment {seg} (CPU 0x{lo:04X}-0x{hi-1:04X}).",
        f"; Generated by tools/disasm/seg_sym.py — do not edit. BIOS + out-of-window",
        f"; names come from segments/msx.sym; in-window names are this bank's",
        f"; labels (so 0x902E is spike_bars_restore here and sfx_0e_block_break",
        f"; when regenerating seg14).",
        "",
    ]
    for addr in sorted(chosen):
        lines.append(chosen[addr][1])
    lines.append("")
    return "\n".join(lines)


def write_segment(seg: int) -> Path:
    GENERATED.mkdir(exist_ok=True)
    path = GENERATED / f"seg{seg:02d}.z80dasm.sym"
    path.write_text(emit_segment(seg))
    return path


def audit() -> str:
    assemble(need_lst=True)
    stack: list[tuple[str, int | None]] = [("VampireKiller.asm", None)]
    at: dict[int, list[tuple[int, str, str]]] = collections.defaultdict(list)

    def bank_of(fname: str, parent: int | None) -> int | None:
        m = re.match(r"seg(\d{2})\.asm$", os.path.basename(fname))
        return int(m.group(1)) if m else parent

    for line in LISTING.read_text(errors="replace").splitlines():
        m = LST_OPEN.match(line)
        if m:
            fname = m.group(1)
            parent = stack[-1][1]
            stack.append((fname, bank_of(fname, parent)))
            continue
        m = LST_CLOSE.match(line)
        if m:
            if len(stack) > 1:
                stack.pop()
            continue
        m = LST_LABEL.match(line)
        if not m:
            continue
        addr = int(m.group(1), 16)
        name = m.group(2)
        _fname, bank = stack[-1]
        if bank is None or addr < 0x4000 or addr >= 0xC000:
            continue
        at[addr].append((bank, name, os.path.basename(_fname)))

    coll = []
    for addr, hits in sorted(at.items()):
        banks = {b for b, n, f in hits}
        if len(banks) < 2:
            continue
        by_bank: dict[int, list[tuple[str, str]]] = collections.defaultdict(list)
        seen = set()
        for b, n, f in hits:
            if (b, n) in seen:
                continue
            seen.add((b, n))
            by_bank[b].append((n, f))
        coll.append((addr, by_bank))

    named_named = []
    named_auto = []
    for addr, by_bank in coll:
        named = [b for b, ns in by_bank.items() if any(not is_auto(n) for n, _ in ns)]
        if len(named) >= 2:
            named_named.append((addr, by_bank))
        elif len(named) == 1:
            named_auto.append((addr, by_bank))

    out = []
    out.append(f"cross-bank CPU-address collisions: {len(coll)}")
    out.append(f"  named vs named: {len(named_named)}")
    out.append(f"  named vs auto:  {len(named_auto)}")
    out.append("")
    out.append("regen-seg.sh now filters msx.sym per bank (tools/disasm/seg_sym.py), so")
    out.append("each of these keeps its own name on regen. Named-vs-named:")
    out.append("")
    for addr, by_bank in named_named:
        bits = []
        for b in sorted(by_bank):
            ns = ", ".join(n for n, _ in by_bank[b] if not is_auto(n))
            bits.append(f"seg{b:02d} {ns}")
        out.append(f"  0x{addr:04X}  " + "  |  ".join(bits))
    return "\n".join(out) + "\n"


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("seg", nargs="?", type=int, help="segment number 0..15")
    p.add_argument("--audit", action="store_true", help="print cross-bank collisions")
    p.add_argument("--stdout", action="store_true", help="print the .sym instead of writing generated/")
    args = p.parse_args(argv)
    if args.audit:
        sys.stdout.write(audit())
        return 0
    if args.seg is None:
        p.error("segment number required (or --audit)")
    if args.seg not in SEG_ORG:
        p.error("segment must be 0..15")
    text = emit_segment(args.seg)
    if args.stdout:
        sys.stdout.write(text)
    else:
        path = write_segment(args.seg)
        print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

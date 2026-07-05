#!/usr/bin/env python3
"""Static-analysis helper for the banked Vampire Killer ROM.

Two things this automates that we otherwise do by hand every session:

  xref  - find who references an address: real control-transfers (call/jp/jr/
          djnz, absolute + relative) vs. bare little-endian word matches (which
          are usually pointer-table entries, but can be coincidental data - the
          tool labels them so you don't mistake one for the other).

  table - decode a dispatch/jump table into its entries (byte or word), with the
          optional `dec a` / base-offset adjustments the game's dispatchers use.

Banking note: the ROM is 8 KiB banks.  Segments 0..3 are the ones we disassemble
and they sit at fixed windows (seg0=0x4000, seg1=0x6000, seg2=0x8000, seg3=
0xA000); those four are always the useful scan set because seg0/1 are resident
and seg2/3 are both mapped at once.  Paged banks 4..15 default to base 0x8000 -
pass --base if a bank is mapped at 0xA000.

Examples:
  tools/romscan.py xref 0x434e                 # who jumps to advance_stage
  tools/romscan.py xref 0x938e --segs 2,3       # (finds only a data coincidence)
  tools/romscan.py table 0x92b4 --words 7        # vendor state->handler table
  tools/romscan.py table 0x8d45 --words 0x19     # collect_bonus handlers (id-1)
"""
import argparse, os, sys

SEG_BASE = {0: 0x4000, 1: 0x6000, 2: 0x8000, 3: 0xA000}
ROM_CANDIDATES = ["references/VampireKiller.rom", "VampireKiller.rom"]

# absolute control-transfer opcodes -> mnemonic
ABS_OPS = {0xC3: "jp", 0xCD: "call",
           0xC2: "jp nz", 0xCA: "jp z", 0xD2: "jp nc", 0xDA: "jp c",
           0xE2: "jp po", 0xEA: "jp pe", 0xF2: "jp p", 0xFA: "jp m"}
REL_OPS = {0x18: "jr", 0x20: "jr nz", 0x28: "jr z", 0x30: "jr nc",
           0x38: "jr c", 0x10: "djnz"}


def repo_root():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_rom():
    root = repo_root()
    for c in ROM_CANDIDATES:
        p = os.path.join(root, c)
        if os.path.isfile(p):
            return open(p, "rb").read()
    sys.exit("no ROM found (looked for %s)" % ", ".join(ROM_CANDIDATES))


def seg_bytes(rom, seg):
    off = seg * 0x2000
    if off + 0x2000 > len(rom):
        sys.exit(f"seg {seg} out of range for {len(rom)}-byte ROM")
    return rom[off:off + 0x2000]


def base_of(seg, override):
    if override is not None:
        return override
    return SEG_BASE.get(seg, 0x8000)


def parse_int(s):
    return int(s, 0)


def cmd_xref(args):
    rom = load_rom()
    target = parse_int(args.addr)
    segs = [int(x) for x in args.segs.split(",")] if args.segs else [0, 1, 2, 3]
    lo, hi = target & 0xFF, target >> 8
    found = 0
    for seg in segs:
        data = seg_bytes(rom, seg)
        base = base_of(seg, args.base)
        hits = []
        for i in range(len(data) - 2):
            op = data[i]
            if op in ABS_OPS and data[i + 1] == lo and data[i + 2] == hi:
                hits.append((base + i, f"{ABS_OPS[op]} {target:#06x}", "code"))
        # relative jumps that land on target (only if target is in this window)
        if base <= target < base + 0x2000:
            for i in range(len(data) - 1):
                op = data[i]
                if op in REL_OPS:
                    disp = data[i + 1] - 256 if data[i + 1] > 127 else data[i + 1]
                    if base + i + 2 + disp == target:
                        hits.append((base + i, f"{REL_OPS[op]} {target:#06x}", "code"))
        # bare word matches (potential pointer-table entry OR data coincidence)
        for i in range(len(data) - 1):
            if data[i] == lo and data[i + 1] == hi:
                abs_i = base + i
                # skip if it's the operand of an abs-op we already reported
                if not (i >= 1 and data[i - 1] in ABS_OPS):
                    hits.append((abs_i, f"word {target:#06x}", "data?"))
        for addr, desc, kind in sorted(hits):
            print(f"  seg{seg:<2} {addr:#06x}  [{kind:5}] {desc}")
            found += 1
    if not found:
        print("  (no references found)")
    else:
        print(f"\n{found} reference(s). 'code' = real transfer; "
              "'data?' = word match (verify: may be a pointer table or coincidence).")


def cmd_table(args):
    rom = load_rom()
    addr = parse_int(args.addr)
    seg = args.seg if args.seg is not None else {0x4000: 0, 0x6000: 1,
                                                  0x8000: 2, 0xA000: 3}.get(addr & 0xE000, 2)
    data = seg_bytes(rom, seg)
    base = base_of(seg, args.base)
    off = addr - base
    if not (0 <= off < 0x2000):
        sys.exit(f"addr {addr:#06x} not inside seg{seg} ({base:#06x}..)")
    n = parse_int(str(args.words if args.words is not None else args.bytes))
    width = 2 if args.words is not None else 1
    idx_base = args.index_base
    print(f"table @ {addr:#06x} (seg{seg}), {n} x {width}-byte"
          + (f", index+{idx_base}" if idx_base else "") + ":")
    for k in range(n):
        e = off + k * width
        if width == 2:
            val = data[e] | (data[e + 1] << 8)
            print(f"  [{k + idx_base:#04x}] -> {val:#06x}")
        else:
            print(f"  [{k + idx_base:#04x}] = {data[e]:#04x} ({data[e]})")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    x = sub.add_parser("xref", help="find references to an address")
    x.add_argument("addr")
    x.add_argument("--segs", help="comma list of segs to scan (default 0,1,2,3)")
    x.add_argument("--base", type=parse_int, help="override base addr for paged segs")
    x.set_defaults(func=cmd_xref)

    t = sub.add_parser("table", help="decode a dispatch/jump table")
    t.add_argument("addr")
    g = t.add_mutually_exclusive_group(required=True)
    g.add_argument("--words", help="decode N little-endian word entries")
    g.add_argument("--bytes", help="decode N byte entries")
    t.add_argument("--seg", type=int, help="segment (default inferred from addr)")
    t.add_argument("--base", type=parse_int, help="override base addr")
    t.add_argument("--index-base", type=parse_int, default=0,
                   help="starting index label (e.g. 1 if dispatcher does dec a)")
    t.set_defaults(func=cmd_table)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()

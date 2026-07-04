#!/usr/bin/env python3
"""Diff RAM snapshots captured by the disasmtrace F9 hotkey.

The emulator writes each F9 press as a record to the snapshot file (default
generated/disasmsnap.bin):

    'S', seq(u32 LE), base(u16 LE), len(u16 LE), then <len> raw bytes.

Typical use: capture once before an action and once after, then

    tools/snapdiff.py generated/disasmsnap.bin

which lists every byte that changed between consecutive snapshots as
"addr: old -> new".  Pick specific snapshots with -a/-b, and restrict the view
to a range with -r (e.g. -r c400-c4ff).
"""
import argparse
import struct
import sys

HDR = struct.Struct("<cIHH")  # 'S', seq, base, len


def load(path):
    snaps = []
    with open(path, "rb") as f:
        blob = f.read()
    off = 0
    while off + HDR.size <= len(blob):
        magic, seq, base, length = HDR.unpack_from(blob, off)
        if magic != b"S":
            raise SystemExit(f"bad record magic {magic!r} at offset {off}")
        off += HDR.size
        data = blob[off:off + length]
        if len(data) != length:
            raise SystemExit(f"truncated snapshot {seq} (want {length}, got {len(data)})")
        off += length
        snaps.append((seq, base, data))
    return snaps


def parse_range(spec):
    lo, _, hi = spec.partition("-")
    lo = int(lo, 16)
    hi = int(hi, 16) if hi else lo
    return lo, hi


def diff(a, b, rng):
    (_, base_a, da), (_, base_b, db) = a, b
    if base_a != base_b:
        raise SystemExit(f"snapshots cover different bases ({base_a:04x} vs {base_b:04x})")
    base = base_a
    out = []
    n = min(len(da), len(db))
    for i in range(n):
        if da[i] == db[i]:
            continue
        addr = base + i
        if rng and not (rng[0] <= addr <= rng[1]):
            continue
        out.append((addr, da[i], db[i]))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("file", nargs="?", default="generated/disasmsnap.bin",
                    help="snapshot file (default generated/disasmsnap.bin)")
    ap.add_argument("-l", "--list", action="store_true", help="list snapshots and exit")
    ap.add_argument("-a", type=int, default=None, help="index of 'before' snapshot")
    ap.add_argument("-b", type=int, default=None, help="index of 'after' snapshot")
    ap.add_argument("-r", "--range", default=None, help="restrict to hex range, e.g. c400-c4ff")
    args = ap.parse_args()

    snaps = load(args.file)
    if not snaps:
        raise SystemExit(f"no snapshots in {args.file}")

    if args.list:
        for i, (seq, base, data) in enumerate(snaps):
            print(f"[{i}] seq={seq} {base:04x}-{base + len(data) - 1:04x} ({len(data)} bytes)")
        return

    rng = parse_range(args.range) if args.range else None

    if args.a is not None or args.b is not None:
        ia = args.a if args.a is not None else 0
        ib = args.b if args.b is not None else len(snaps) - 1
        pairs = [(ia, ib)]
    else:
        # default: every consecutive pair
        pairs = [(i, i + 1) for i in range(len(snaps) - 1)]
        if not pairs:
            raise SystemExit("only one snapshot present; capture a second (F9) to diff")

    for ia, ib in pairs:
        a, b = snaps[ia], snaps[ib]
        changes = diff(a, b, rng)
        print(f"== snapshot [{ia}] (seq {a[0]}) -> [{ib}] (seq {b[0]}): "
              f"{len(changes)} byte(s) changed"
              + (f" in {args.range}" if rng else ""))
        for addr, old, new in changes:
            print(f"  {addr:04x}: {old:02x} -> {new:02x}  ({old:3d} -> {new:3d})")


if __name__ == "__main__":
    sys.exit(main())

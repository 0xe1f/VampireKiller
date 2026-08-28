#!/usr/bin/env bash
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

# Regenerate an 8 KiB bank disassembly from the original ROM.
#
#   tools/disasm/regen-seg.sh <bank-number> <origin-hex> [blockfile]
#
# Example:  tools/disasm/regen-seg.sh 0 0x4000 segments/banks_0123.blocks
#
# blockfile is a paging-window map (same stem as banks_*.asm).  Ranges whose
# start falls outside [org, org+0x2000) are dropped so z80dasm only sees the
# 8K being disassembled.
#
# Produces two scratch files in generated/ (the whole dir is gitignored):
#   generated/segNN.raw.asm        raw z80dasm listing WITH the address + opcode
#                                  comments (";<addr>  <hex>  <ascii>"), kept only
#                                  as a temporary byte/address reference.
#   generated/segNN.generated.asm  the same disassembly with those listing comments
#                                  stripped - fold THIS into the committed
#                                  banks_*.asm window that contains that bank.
#
# The committed banks_*.asm must never contain z80dasm's trailing address/opcode
# comments.  z80dasm can only emit them or not, so we always generate the full
# listing (handy while reversing) and strip it automatically here; that way the
# noise can never leak into the working source.
set -euo pipefail
DISASM="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DISASM/../.." && pwd)"
cd "$ROOT"

seg="$1"; org="$2"; blocks="${3:-}"
segnn=$(printf "%02d" "$seg")
rom="${ROM:-VampireKiller.rom}"
[ -f "$rom" ] || { echo "no ROM at $rom (run make, or set ROM=)" >&2; exit 1; }

tmpbin="$(mktemp)"
tmpblocks=""
cleanup() { rm -f "$tmpbin" ${tmpblocks:+"$tmpblocks"}; }
trap cleanup EXIT
dd if="$rom" of="$tmpbin" bs=8192 skip="$seg" count=1 status=none

# Flat msx.sym cannot name two things at the same CPU address in different
# banks.  seg_sym.py emits a per-segment file: BIOS + out-of-window
# names from msx.sym, in-window names from this bank's labels.
mkdir -p generated
python3 "$DISASM/seg_sym.py" "$seg"
sym="generated/seg${segnn}.z80dasm.sym"

args=(-a -t -l -g "$org" -S "$sym")
if [ -n "$blocks" ]; then
  tmpblocks="$(mktemp)"
  python3 - "$org" "$blocks" "$tmpblocks" <<'PY'
import re, sys
org = int(sys.argv[1], 0)
end = org + 0x2000
src, dst = sys.argv[2], sys.argv[3]
pat = re.compile(r"start\s+(0x[0-9a-fA-F]+)", re.I)
with open(src) as f, open(dst, "w") as out:
    for line in f:
        m = pat.search(line)
        if m and not (org <= int(m.group(1), 0) < end):
            continue
        out.write(line)
PY
  args+=(-b "$tmpblocks")
fi

raw="generated/seg${segnn}.raw.asm"
gen="generated/seg${segnn}.generated.asm"

z80dasm "${args[@]}" "$tmpbin" -o "$raw"
# strip the org line (the master's PHASE provides the base address)
sed -i '' 's/^\torg .*/; (org set by PHASE in VampireKiller.asm)/' "$raw"

# clean working copy: drop the address/opcode listing comments automatically
cp "$raw" "$gen"
python3 "$DISASM/strip-listing.py" "$gen"
echo "wrote $gen (clean, fold this)  +  $raw (raw listing, temporary reference)"

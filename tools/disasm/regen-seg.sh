#!/usr/bin/env bash
# Regenerate a segment disassembly from the original ROM.
#
#   tools/disasm/regen-seg.sh <segment-number> <origin-hex> [blockfile]
#
# Example:  tools/disasm/regen-seg.sh 0 0x4000 segments/seg00.blocks
#
# Produces two scratch files in generated/ (the whole dir is gitignored):
#   generated/segNN.raw.asm        raw z80dasm listing WITH the address + opcode
#                                  comments (";<addr>  <hex>  <ascii>"), kept only
#                                  as a temporary byte/address reference.
#   generated/segNN.generated.asm  the same disassembly with those listing comments
#                                  stripped - fold THIS into the committed
#                                  banks_*.asm window that contains that bank.
#
# The committed segNN.asm must never contain z80dasm's trailing address/opcode
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
dd if="$rom" of="$tmpbin" bs=8192 skip="$seg" count=1 status=none

# Flat msx.sym cannot name two things at the same CPU address in different
# banks.  seg_sym.py emits a per-segment file: BIOS + out-of-window
# names from msx.sym, in-window names from this bank's labels.
mkdir -p generated
python3 "$DISASM/seg_sym.py" "$seg"
sym="generated/seg${segnn}.z80dasm.sym"

args=(-a -t -l -g "$org" -S "$sym")
[ -n "$blocks" ] && args+=(-b "$blocks")

raw="generated/seg${segnn}.raw.asm"
gen="generated/seg${segnn}.generated.asm"

z80dasm "${args[@]}" "$tmpbin" -o "$raw"
rm -f "$tmpbin"
# strip the org line (the master's PHASE provides the base address)
sed -i '' 's/^\torg .*/; (org set by PHASE in VampireKiller.asm)/' "$raw"

# clean working copy: drop the address/opcode listing comments automatically
cp "$raw" "$gen"
python3 "$DISASM/strip-listing.py" "$gen"
echo "wrote $gen (clean, fold this)  +  $raw (raw listing, temporary reference)"

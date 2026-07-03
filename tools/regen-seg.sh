#!/usr/bin/env bash
# Regenerate a segment disassembly from the original ROM.
#
#   tools/regen-seg.sh <segment-number> <origin-hex> [blockfile]
#
# Example:  tools/regen-seg.sh 0 0x4000 tools/seg00.blocks
#
# Produces two scratch files in generated/ (the whole dir is gitignored):
#   generated/segNN.raw.asm        raw z80dasm listing WITH the address + opcode
#                                  comments (";<addr>  <hex>  <ascii>"), kept only
#                                  as a temporary byte/address reference.
#   generated/segNN.generated.asm  the same disassembly with those listing comments
#                                  stripped - fold THIS into the committed
#                                  segments/segNN.asm.
#
# The committed segNN.asm must never contain z80dasm's trailing address/opcode
# comments.  z80dasm can only emit them or not, so we always generate the full
# listing (handy while reversing) and strip it automatically here; that way the
# noise can never leak into the working source.
set -euo pipefail
cd "$(dirname "$0")/.."

seg="$1"; org="$2"; blocks="${3:-}"
segnn=$(printf "%02d" "$seg")
rom="VampireKiller.rom"
[ -f "$rom" ] || rom="../VampireKiller.rom"

tmpbin="$(mktemp)"
dd if="$rom" of="$tmpbin" bs=8192 skip="$seg" count=1 status=none

args=(-a -t -l -g "$org" -S tools/msx.sym)
[ -n "$blocks" ] && args+=(-b "$blocks")

mkdir -p generated
raw="generated/seg${segnn}.raw.asm"
gen="generated/seg${segnn}.generated.asm"

z80dasm "${args[@]}" "$tmpbin" -o "$raw"
rm -f "$tmpbin"
# strip the org line (the master's PHASE provides the base address)
sed -i '' 's/^\torg .*/; (org set by PHASE in VampireKiller.asm)/' "$raw"

# clean working copy: drop the address/opcode listing comments automatically
cp "$raw" "$gen"
python3 tools/strip-listing.py "$gen"
echo "wrote $gen (clean, fold this)  +  $raw (raw listing, temporary reference)"

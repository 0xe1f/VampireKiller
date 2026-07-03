#!/usr/bin/env bash
# Regenerate a segment disassembly from the original ROM.
#
#   tools/regen-seg.sh <segment-number> <origin-hex> [blockfile]
#
# Example:  tools/regen-seg.sh 0 0x4000 tools/seg00.blocks
#
# Writes a fresh segments/segNN.generated.asm so hand-edited segNN.asm is never
# clobbered.  Review it, fold in changes, then `make verify`.
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

z80dasm "${args[@]}" "$tmpbin" -o "segments/seg${segnn}.generated.asm"
rm -f "$tmpbin"
# strip the org line (the master's PHASE provides the base address)
sed -i '' 's/^\torg .*/; (org set by PHASE in VampireKiller.asm)/' "segments/seg${segnn}.generated.asm"
echo "wrote segments/seg${segnn}.generated.asm"

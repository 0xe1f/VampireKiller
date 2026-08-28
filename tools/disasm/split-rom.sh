#!/usr/bin/env bash
# Drop leftover segment .bin files.  All 16 banks assemble from .asm;
# nothing is INCBIN'd.  (Kept so `make segments` stays a valid no-op.)
#
#   tools/disasm/split-rom.sh
#
set -euo pipefail
cd "$(cd "$(dirname "$0")/../.." && pwd)"

mkdir -p segments
for n in {0..15}; do
  nn=$(printf "%02d" "$n")
  rm -f "segments/seg${nn}.bin"
done
echo "no leftover .bin (all banks are source)"

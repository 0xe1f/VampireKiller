#!/usr/bin/env bash
# Regenerate the per-segment binaries the build needs but that are NOT committed
# (they are copyrighted game data).  Splits an original Vampire Killer ROM into
# 8 KiB segments seg01.bin .. seg15.bin under segments/.
#
# Segment 0 is committed as disassembled source (segments/seg00.asm), so it is
# not produced here.
#
#   tools/split-rom.sh [path-to-VampireKiller.rom]
#
# Default ROM path is references/VampireKiller.rom (the gitignored reference ROM).
set -euo pipefail
cd "$(dirname "$0")/.."

rom="${1:-references/VampireKiller.rom}"
if [ ! -f "$rom" ]; then
  echo "error: ROM not found: $rom" >&2
  echo "usage: tools/split-rom.sh [path-to-VampireKiller.rom]" >&2
  exit 1
fi

size=$(wc -c < "$rom" | tr -d ' ')
if [ "$size" != "131072" ]; then
  echo "warning: expected a 131072-byte (128 KiB) ROM, got $size bytes" >&2
fi

mkdir -p segments
for n in $(seq 1 15); do
  nn=$(printf "%02d" "$n")
  dd if="$rom" of="segments/seg${nn}.bin" bs=8192 skip="$n" count=1 status=none
done
echo "wrote segments/seg01.bin .. segments/seg15.bin"

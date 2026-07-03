#!/usr/bin/env bash
# Run the DISASMTRACE-enabled CocoaMSX build and capture a trace log.
#
#   tools/trace-run.sh [rom]
#
# Environment knobs (all optional):
#   EXEC   exec address ranges to log, e.g. "6552-66c0,64ec-6551" (hex, CPU addrs)
#   WATCH  memory-write address ranges to log, e.g. "ce00-ce02,c00f"
#   LOG    output file (default generated/disasmtrace.log)
#   DEDUP  set to 0 to log every executed address (default 1: collapse repeats)
#
# The tracer tags every event with the ROM segment currently paged at that CPU
# address, so lines read "X 06:be44" = seg 6, PC 0xBE44.  Bank switches log as
# "B page=N seg=NN".  Load the ROM (if not passed / not auto-opened) via the GUI,
# then play to the moment of interest; the log streams live (line-buffered).
set -euo pipefail
cd "$(dirname "$0")/.."

app="generated/cocoamsx-dd/Build/Products/Debug/CocoaMSX.app/Contents/MacOS/CocoaMSX"
if [ ! -x "$app" ]; then
    echo "traced build not found - run tools/build-cocoamsx.sh first" >&2
    exit 1
fi

rom="${1:-../VampireKiller.rom}"
log="${LOG:-generated/disasmtrace.log}"
mkdir -p "$(dirname "$log")"

echo "tracing -> $log   (exec='${EXEC:-}' watch='${WATCH:-}')"
DISASM_TRACE=1 \
DISASM_DEDUP="${DEDUP:-1}" \
DISASM_EXEC="${EXEC:-}" \
DISASM_WATCH="${WATCH:-}" \
DISASM_LOG="$log" \
exec "$app" "$rom"

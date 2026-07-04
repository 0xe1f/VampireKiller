#!/usr/bin/env bash
# Run the DISASMTRACE-enabled CocoaMSX build and capture a trace log.
#
#   tools/trace-run.sh [rom]
#
# Environment knobs (all optional):
#   EXEC   exec address ranges to log, e.g. "6552-66c0,64ec-6551" (hex, CPU addrs)
#   WATCH  memory-write address ranges to log, e.g. "ce00-ce02,c00f"
#   LOG    output file (default generated/disasmtrace.log)
#   SNAP   snapshot file (default generated/disasmsnap.bin)
#   SNAPRANGE  RAM window per snapshot (default c000-dfff)
#   DEDUP  set to 0 to log every executed address (default 1: collapse repeats)
#   SOFTGL set to 0 to use hardware OpenGL (default 1: force Apple's software GL
#          renderer). On Apple Silicon the Metal-backed GL shim segfaults on the
#          emulator's immediate-mode draws, so software GL is required to run.
#
# The tracer tags every event with the ROM segment currently paged at that CPU
# address, so lines read "X 06:be44" = seg 6, PC 0xBE44.  Bank switches log as
# "B page=N seg=NN".  Load the ROM (if not passed / not auto-opened) via the GUI,
# then play to the moment of interest; the log streams live (line-buffered).
#
# NOTE: with EXEC and WATCH both empty the tracer logs ONLY bank switches. It
# reads the ranges once at launch, so changing them means relaunching.
#
# STATE SNAPSHOTS: press F9 in the emulator to dump the SNAPRANGE RAM window to
# the snapshot file (works even with EXEC/WATCH empty). Capture once before an
# action and once after; then diff them with:  tools/snapdiff.py <snapfile>
#
# Handy presets (see docs/progress.md "Next tracing session"):
#   inventory/counters:  WATCH=c400-c41f,c470-c4ff,c800-c8ff,d000-d0ff
#   player movement:     WATCH=c420-c4ff,c800-c8ff,d000-d0ff,d700-d7ff
#   top-level state:     WATCH=c000-c004,ce00-ce4f,d000-d02f  EXEC=41a0-4450,62d7-6820
#   death / boss event:  WATCH=c000-c004,c408-c41f,ce00-ce4f
#
# First-run gotcha: CocoaMSX reads the keyboard via IOHIDManager, so the built
# .app needs Input Monitoring permission (System Settings > Privacy & Security >
# Input Monitoring). Rebuilding changes the ad-hoc signature, so re-grant after a
# rebuild: `tccutil reset ListenEvent org.akop.CocoaMSX`, relaunch, allow.
set -euo pipefail
cd "$(dirname "$0")/.."

app="generated/cocoamsx-dd/Build/Products/Debug/CocoaMSX.app/Contents/MacOS/CocoaMSX"
if [ ! -x "$app" ]; then
    echo "traced build not found - run tools/build-cocoamsx.sh first" >&2
    exit 1
fi

rom="${1:-references/VampireKiller.rom}"
log="${LOG:-generated/disasmtrace.log}"
snap="${SNAP:-generated/disasmsnap.bin}"
mkdir -p "$(dirname "$log")" "$(dirname "$snap")"

echo "tracing -> $log   (exec='${EXEC:-}' watch='${WATCH:-}')"
echo "snapshots -> $snap (press F9 to capture; range ${SNAPRANGE:-c000-dfff})"
if [ "${SOFTGL:-1}" != "0" ]; then
    export COCOAMSX_SOFTWARE_GL=1
fi
export DISASM_TRACE=1
export DISASM_DEDUP="${DEDUP:-1}"
export DISASM_EXEC="${EXEC:-}"
export DISASM_WATCH="${WATCH:-}"
export DISASM_LOG="$log"
export DISASM_SNAP="$snap"
export DISASM_SNAP_RANGE="${SNAPRANGE:-c000-dfff}"
exec "$app" "$rom"

#!/usr/bin/env bash
# Build CocoaMSX (tools/CocoaMSX submodule) with the disassembly tracer enabled.
#
# The tracer hooks are compiled only when DISASMTRACE is defined; the remaining
# flags let the (old) blueMSX tree build against a modern macOS SDK / clang:
#   fdopen=fdopen         neutralises zutil.h's Classic-Mac fdopen->NULL redefine
#                         (TARGET_OS_MAC is 1 on all modern Apple platforms)
#   -Wno-c++11-narrowing  the OPL/YMF sound tables use narrowing initialisers
#   EXCLUDED ...iconset   skip the app-icon step (irrelevant here; also dodges a
#                         sandboxed iconutil XPC failure)
#   DEPLOYMENT_TARGET=11  the project's archived 10.7 target is below the SDK floor
#                         (10.13); arm64 needs >= 11.0
#
# Output: generated/cocoamsx-dd/Build/Products/Debug/CocoaMSX.app  (gitignored)
set -euo pipefail
cd "$(dirname "$0")/CocoaMSX"

xcodebuild -scheme CocoaMSX -configuration Debug \
  -derivedDataPath ../../generated/cocoamsx-dd \
  MACOSX_DEPLOYMENT_TARGET=11.0 \
  GCC_PREPROCESSOR_DEFINITIONS='$(inherited) DISASMTRACE fdopen=fdopen' \
  OTHER_CPLUSPLUSFLAGS='$(inherited) -Wno-c++11-narrowing' \
  CODE_SIGNING_ALLOWED=NO \
  EXCLUDED_SOURCE_FILE_NAMES='cocoamsx.iconset' \
  build

app="$(cd ../.. && pwd)/generated/cocoamsx-dd/Build/Products/Debug/CocoaMSX.app"
echo "built: $app"

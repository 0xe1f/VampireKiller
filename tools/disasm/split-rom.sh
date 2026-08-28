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

#!/usr/bin/env python3
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

"""Minimal dependency-free PNG writer (stdlib zlib only).

write_rgb(path, width, height, rgb) where rgb is a flat bytes-like of length
width*height*3 (8-bit R,G,B per pixel).
"""
import struct, zlib

def _chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data +
            struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

def write_rgb(path, width, height, rgb):
    assert len(rgb) == width * height * 3, "rgb size mismatch"
    raw = bytearray()
    stride = width * 3
    for y in range(height):
        raw.append(0)                         # filter type 0 (None)
        raw += rgb[y * stride:(y + 1) * stride]
    png = b"\x89PNG\r\n\x1a\n"
    png += _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += _chunk(b"IEND", b"")
    open(path, "wb").write(png)

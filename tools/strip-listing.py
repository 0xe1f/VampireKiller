#!/usr/bin/env python3
r"""Strip z80dasm's `-t` listing comments (";<addr>\t<hexbytes>\t<ascii>") from a
disassembly, while preserving any hand-written semantic comment.

Each affected line looks like:
    <code>\t;<4-hex-addr>\t<hex bytes>\t<ascii>
The trailing field is EITHER z80dasm's ASCII rendering of the bytes (dropped) OR
a real comment we added (kept). They are distinguished structurally: z80dasm's
ASCII art is space-separated single characters (e.g. ". .", "! . L", ">"), while
our comments start with ";" and contain at least one multi-character word.

Usage:  tools/strip-listing.py <file.asm> [more.asm ...]      (edits in place)
"""
import re, sys

# The listing comment is always the LAST comment on the line and has the rigid
# structure ";<4-hex-addr>\t<hex bytes>\t<ascii>".  Using `.*?` (rather than
# `[^;]*?`) for the code lets it span an earlier z80dasm comment such as
# "; illegal sequence" so that comment is preserved and only the trailing
# listing is dropped.
LINE = re.compile(
    r'^(?P<code>.*?)\s*;[0-9a-fA-F]{4}\t'
    r'(?P<bytes>[0-9a-fA-F]{2}(?: [0-9a-fA-F]{2})*)[ \t]*(?P<tail>.*)$')
COMMENT_COL = 32

def is_semantic(tail):
    return tail.startswith(";") and any(len(tok) > 1 for tok in tail.split())

def vis_width(s):
    w = 0
    for ch in s:
        w = w + (8 - w % 8) if ch == "\t" else w + 1
    return w

def transform(line):
    m = LINE.match(line)
    if not m:
        return line, None
    code = m.group("code").rstrip()
    tail = m.group("tail").strip()
    if is_semantic(tail):
        pad = max(1, COMMENT_COL - vis_width(code))
        return code + " " * pad + tail + "\n", "kept"
    return code + "\n", "dropped"

def main():
    for path in sys.argv[1:]:
        lines = open(path).readlines()
        out, dropped, kept = [], 0, 0
        for ln in lines:
            new, what = transform(ln)
            out.append(new)
            if what == "dropped":
                dropped += 1
            elif what == "kept":
                kept += 1
        open(path, "w").writelines(out)
        print("%s: dropped %d byte-listings, kept %d semantic comments"
              % (path, dropped, kept))

if __name__ == "__main__":
    main()

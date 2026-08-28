---
name: msx-romscan
description: >-
  Static xref and dispatch-table decode for banked Z80 ROMs via
  tools/disasm/romscan.py. Use when finding callers of an address, decoding a
  jump or handler table, asking who calls or jumps to a routine, grepping
  leftover bins for references, or writing ad-hoc xref python.
---

# MSX romscan

Prefer this over grepping `.bin` files or a one-off Python xref. Needs a built
`<Game>.rom` (`make`, or `--rom` / `$ROM`). Default scan set is segs 0–3
(resident 0x4000–0x7FFF plus the 0x8000/0xA000 pair).

```
tools/disasm/romscan.py xref 0xADDR
tools/disasm/romscan.py xref 0xADDR --segs 2,3
tools/disasm/romscan.py table 0xADDR --words N
tools/disasm/romscan.py table 0xADDR --bytes N
tools/disasm/romscan.py table 0xADDR --words N --index-base 1
tools/disasm/romscan.py --rom other.rom xref 0xADDR
```

`--index-base 1` when the dispatcher does `dec a` so printed ids match the game.

Paged banks 4+ default to base 0x8000; pass `--base 0xA000` when that bank is
mapped high.

## `code` vs `data?`

- **`code`** — real `call` / `jp` / `jr` / `djnz` (absolute + relative).
- **`data?`** — bare little-endian word. Often a pointer-table entry; can be a
  coincidence inside a curve. Verify in source before treating it as a call.

## Gotchas

- Migrated banks have no `.bin`. `romscan` reads the ROM, so it still sees them.
- No `code` xref ≠ dead: the entry may be a stored/computed pointer (handler
  written into an object field).
- Cross-bank `call` from the resident window into 0x8000/0xA000 is normal.
  Named labels stay byte-exact; comment the callee's bank.
- Default `--segs 0,1,2,3` misses a routine that only lives in a later bank —
  pass `--segs` for that bank (and `--base` if it is at 0xA000).

For naming after a hit: `konami-msx-disasm`.

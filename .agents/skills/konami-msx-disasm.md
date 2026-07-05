---
name: konami-msx-disasm
description: >-
  Methodology for producing a byte-exact, commented, reassemblable disassembly
  of a Konami MSX/MSX2 MegaROM (Konami4/SCC and similar mappers). Use when
  disassembling, reverse-engineering, or annotating an MSX ROM, adding a new
  game to this workspace, or working in a game repo laid out like vampirekiller/.
---

# Konami MSX disassembly

This repo (the Vampire Killer disassembly) is the reference implementation; these
skills ship inside it. Reuse its layout, tools, and conventions for every new game
instead of reinventing them. Read `docs/progress.md` (End goal + Working notes) and
`docs/game-notes.md` before starting a new game; copy `tools/` and the `Makefile`.
Paths below are relative to this repo root.

## Non-negotiables

- **Byte-exact round-trip at every step.** The build must reproduce the original
  ROM byte-for-byte (`make verify`). Run it after every edit. Never commit a
  change that breaks it.
- **No binaries in the final repo** (goal). Each 8 KiB segment starts as an
  `INCBIN` placeholder and graduates to annotated `.asm` (code) or extracted data
  assets (graphics/tables) as it's understood. Don't mass-convert bins to opaque
  `db` dumps; reverse incrementally.
- **Assembler = sjasmplus, disassembler = z80dasm.** Both built from source (not
  committed).

## Project scaffold (mirror vampirekiller/)

- Root: `<Game>.asm` (stitches segments via `PHASE`/`INCBIN`), `Makefile`,
  `README.md`, `.gitignore` (ignore `generated/`, built ROM, segment bins).
- `segments/` — per-segment `.asm` (disassembled) + `.bin` (not-yet-reversed);
  all hand-authored disassembly metadata lives here: `bios.inc` (MSX BIOS entry
  names), `msx.sym` (routine/label names for z80dasm regen), `seg*.blocks`
  (code/data split maps). Anything needed to reassemble or regenerate belongs here.
- `docs/` — `progress.md` (checklist + RAM map + working notes), `game-notes.md`
  (detailed findings).
- `tools/` — `regen-seg.sh`, `split-rom.sh`, `strip-listing.py`, `romscan.py`
  (static xref / table decode), gfx pipeline, and the tracing tools (see
  `msx-runtime-tracing`). Executable tooling only.
- `gfx/` — editable graphics assets (PNG + txt); original compressed bytes stay
  authoritative.

## Mapper first

Identify the mapper before anything else (size, segment count, switch
addresses, fixed vs paged pages). Konami4: 8 KiB banks, seg 0 fixed at
0x4000-0x5FFF (entry point + resident code/main loop/IRQ), pages switched by
writing the bank number to an address in the target page. Document it at the top
of `<Game>.asm`.

## Workflow per segment

1. `tools/regen-seg.sh <n> <org> [blocks]` → writes `generated/segNN.generated.asm`
   (listing comments already stripped) + `generated/segNN.raw.asm` (raw reference).
2. Fold the clean disassembly into `segments/segNN.asm` by hand and annotate.
   Switch `<Game>.asm` for that segment from `INCBIN` to `INCLUDE`.
3. Separate code vs data with a `tools/segNN.blocks` file (only changes
   rendering, never bytes). Mark mis-decoded tables and convert them to `db`.
4. `make verify` → must stay byte-identical.

## Conventions (enforced)

- **Never** leave z80dasm's trailing `;addr bytes ascii` listing comments in
  committed `.asm`. Regen strips them; `tools/strip-listing.py` is the safety net.
- **Annotate per-opcode**, not just block headers: comment VDP writes, magic
  constants, RAM addresses, branch conditions, loop counters. Inline comments at
  column 32.
- **Naming**: rename a `z80dasm` label (`sub_XXXXh`/`lXXXXh`) to a descriptive name
  as soon as its purpose is confirmed — proactively, never speculatively. Keep the
  original ROM address in the block-header comment (e.g. `(seg0 0x5F24)`) so names
  still match trace PCs, and add the name to `segments/msx.sym` so regen emits it.
  Update the definition + every reference in the `.asm` files (`INCBIN` segments
  reference code only by embedded address bytes, so nothing to change there);
  `make verify` catches inconsistencies. Casing: `UPPER_SNAKE` only for MSX BIOS
  and macro-like pseudo-instruction helpers (e.g. `DISPATCH_A`); `lower_snake` for
  all game code/data.
- **Text**: MSX games often store text as `(ASCII - offset)` because the font is
  loaded at a nonzero tile base. Crack the offset, then use an sjasmplus `LUA
  ALLPASS`/`ENDLUA` helper (see `vk()` in `VampireKiller.asm`) to
  spell strings in readable ASCII while emitting exact bytes. Use `LUA ALLPASS`
  (plain `LUA` runs only on the final pass and drifts labels).
- **Graphics**: usually custom RLE to VRAM (SCREEN 5 = 4bpp bitmap on MSX2, plus
  1bpp hardware sprites). Find the decompressor, then extract to editable assets
  with the gfx pipeline; keep compressed bytes authoritative.

## Konami idioms to expect

- Inline word-table dispatch by index in A (VK's `DISPATCH_A`): a `call` followed
  by an inline `dw` table, handler picked by A. Other dispatch shapes: `ld hl,tbl;
  ADD_HL_A; ld a,(hl)` (byte table → sub-index/action id), and `ld de,tbl;
  ADD_DE_A` with a multiply (`add a,a` x3 = ×8) for **row** tables (N-byte rows).
- **Off-by-one dispatch**: a `dec a` (or `sub base`) right before the dispatch means
  id N uses `table[N-1]`. Always check for it — decoding the table from the wrong
  base shifts every entry. (VK's `collect_bonus` does `dec a`; black bible id 0x10
  → `table[0x0f]`.)
- **RNG via `ld a,r`** (the refresh register) — a cheap pseudo-random source. If a
  mechanic behaves differently run-to-run for the same input, grep for `ld a,r`
  near its state machine; the branch after it is the coin-flip.
- **Packed BCD everywhere**: `add a,001h; daa` (and `daa` chains across bytes) =
  a BCD increment. Scores, heart/money counters, prices, and many on-screen numbers
  are stored packed-BCD, little-endian, often /100 (a table byte of 0x50 = "50").
- **Subsystem state blocks**: a feature usually parks all its state in one
  contiguous RAM block (VK vendor = 0xC700..0xC70F). Find the block by F8-diffing
  while the feature is active (see `msx-runtime-tracing`), then `romscan xref` /
  grep the block bytes to reach the handler.
- State machines driven by a per-frame tick off the 60 Hz timer IRQ (`H.TIMI`).
- Actor/object slot arrays (fixed count, fixed stride) with a type/active byte at
  offset 0; a per-type behaviour handler table indexed by type. Cross-reference
  Metal Gear's `references/MetalGear/constants/structures.asm` — Konami reused
  structures across games.

## Rooting out logic (static analysis)

`tools/romscan.py` automates the two look-ups we do constantly:

- `romscan xref 0xADDR [--segs a,b]` — every reference to an address, split into
  **`code`** (real `call`/`jp`/`jr`/`djnz`, absolute + relative) vs **`data?`**
  (bare little-endian word match). The `code`/`data?` split is the whole point: a
  word match is often a pointer-table entry but can be a coincidence inside a data
  curve — verify before trusting it.
- `romscan table 0xADDR --words N [--index-base 1]` (or `--bytes N`) — decode a
  dispatch/jump table into its entries; `--index-base 1` mirrors a `dec a`
  dispatcher so the printed indices match the real ids.

Gotchas this encodes (learned the hard way):

- **Search the resident bank too.** Seg 0 has no committed `.bin` (it's `INCLUDE`d),
  so grepping `segments/*.bin` silently misses every resident-bank caller. `romscan`
  reads each bank straight from the ROM, so it sees seg0. A routine that looks
  "never referenced" in the paged banks is often driven from seg0.
- **Cross-bank calls are normal.** The resident bank (0x4000-0x7FFF, always mapped)
  freely `call`s into whatever is paged at 0x8000/0xA000. When the callee is a named
  label, use it across banks — sjasmplus resolves the global label to the exact
  address, so `call vendor_make_offer` from seg0 stays byte-exact. Add a comment
  noting the callee's bank.
- "No `code` xref" ≠ dead code: an entry can be reached via a **stored/computed
  pointer** (handler written into an object field) rather than a static transfer.

## Cost discipline

- Prefer the existing tools over ad-hoc shell. Reuse `regen-seg.sh`, `snapdiff.py`,
  `romscan.py` (don't re-hand-roll xref/table-decode python each time).
- Don't read whole 5 KLOC segment files linearly; use Grep/semantic search to the
  region of interest.
- Batch independent shell/reads in one turn. `make verify` is fast (<1 s) — run it
  freely.

## Companion skill

For identifying variables/routines at runtime (which RAM = HP, which PC writes
it), use the `msx-runtime-tracing` skill.

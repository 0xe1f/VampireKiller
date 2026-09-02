---
name: vk-disasm
description: >-
  Vampire Killer–specific disassembly notes: window files banks_0123…,
  this cart’s RAM/GM/door/object-list bytes, and roomperm.
  Generic Konami/MSX conventions live in the MSXDAW skill konami-msx-disasm.
---

# Vampire Killer disassembly (this cart)

Methodology (byte-exact verify, naming, per-opcode comments at column 32,
DISPATCH_A, banks vs windows, false immediates) is MSXDAW
`konami-msx-disasm`. Do not restate it here. Workbench is `tools/workbench`.
New games: `msx-scaffold`, then `msx-bootstrap` — do not copy this repo’s
`tools/` or `segments/` tree. Game dumpers stay here (`gfxdump.py`,
`roomperm.py`, `psgplay.py`, `emit_identified_data.py`).

## Remaining (this cart)

Status only. How to rename and comment is `konami-msx-disasm`.

- **Play window (`banks_0123`).** All `sub_XXXXh` / `lXXXXh` are named.
  Status lives in `docs/progress.md` “Play-window labels”.
- **Graphics / map / sound windows.** Labelled `.asm` (no `INCBIN`). Orphan /
  unid / pad leftovers: `docs/unused.md` and `gfx/**/unused_*.png`.

Peel identified blobs: `msx-code-data`.

## On-disk layout (historical)

New carts use `banks/bankNN.asm`. This cart keeps `segments/` + window files
(`AGENTS.md`).

- Root: `VampireKiller.asm` (stitches windows via `PHASE` / `INCLUDE`),
  `Makefile`, `README.md`. No leftover `.bin`.
- `segments/` — one `.asm` per paging window: `banks_0123` (0–3 at
  `PHASE 0x4000`), `banks_456`, `banks_78`, `banks_9a`, `banks_bcd`,
  `banks_ef`. Metadata: `bios.inc`, `ram.inc`, type-id `*.inc` (`actors`,
  `items`, `weapon`, `sfx`, `poses`, `scenery`, `event`, `state`, `dir` —
  never `msx.sym`), `msx.sym`, `banks_*.blocks`.
- `docs/` — `progress.md`, `game-notes.md`, `vendor.md`, `unused.md`.
- `tools/` — VK dumpers + `sjasmplus`. Workbench is the submodule; do not copy it.
- `gfx/` / `music/` / `sfx/` — PNG/WAV catalogues (`vk-gfx-sheets`,
  `tools/psgplay.py`). Compressed `.asm` stays authoritative.

## Mapper and windows (this cart)

Konami4, 16 × 8 KiB, bank 0 fixed at 0x4000–0x5FFF. Documented at the top of
`VampireKiller.asm`. Generic mapper-first steps: `msx-bootstrap`.

Regen one 8 KiB slice: `tools/workbench/msx/regen-bank.sh <n> <org>
[blocks]` (`msx-regen`). Fold into the window file by hand.

Play bank 3 and map bank 13 both occupy CPU 0xA000. They cannot reuse
z80dasm `lXXXXh` / `sub_XXXXh` names. Do not put those overlapping addresses
in `msx.sym` (`konami-msx-disasm` MODULE rule). `bank_sym.py --audit` lists
this cart’s collisions (48: 21 named-vs-named, including 0x902E
`spike_bars_restore` vs `sfx_0e_block_break`). Keep one `msx.sym`; do not
split it per window.

VK windows are already `INCLUDE` source. 4bpp tiles stay hex pixel-rows.
Identified 1bpp: `hud_font`, `credits_font`, `logo_font`. Bank 15 continues
`psg_music` + `music_phrases` + env tables + 4bpp Dracula portrait.
`banks_ef` is scenery lists + spawn masks + enemy lists + sound.

## This cart’s deltas on the generic conventions

False immediates and `msx.sym` banking are `konami-msx-disasm`. After a play
regen, audit BIOS names on non-branch lines — this cart had **91** in banks
0–3 (`ld bc,l4206h` was a 66×6 rectangle). Text macros are `vk` / `cr` in
`VampireKiller.asm` (HUD ASCII−0x10, space → 0x00).

## Gotchas (this ROM)

- **`collect_bonus`:** `dec a` before `DISPATCH_A` — id N uses `table[N-1]`
  (black bible 0x10 → `table[0x0f]`).
- **`entity_tbl` overflow:** types 1–22 in bank 0; type 0x1E reads
  `flame_init` at 0x9B67 in the next page. Spawn-init ≠ per-frame tick;
  extra ids often enter mid-init.
- **Object list:** `C = id&0x7F` into `spawn_actor`. Attr is **Y<<4|X**
  (same packing as scenery pos); `object_list_spawn` loads high→E (Y),
  low→D (X). Bit7 on dogs is stripped at spawn. Generator-bit enemies are
  often absent from the list; the placed copy is a different id.
- **Scenery list is a different grammar** than the enemy list: `0xFE` /
  `0xFF` / `0x00`-end-hub, plus a 3-byte `0x7F` covering wall. Stage 0 may
  skip the hub pointer table. Display-type 0x1F is vendor/reveal, not the
  white-key door; list-id 0x1F in three rooms is a hanging bat.
- **White-key door:** `door_tbl` (seg13 0xBB61), 19×3 `(room|vert<<7, Y, X)`.
  `door_load_coords` writes `C5AD=Y`, `C5AE=X` (`ld (nn),hl` is L then H).
  After open, CONN on that edge is the destination (`door_open_exit`).
- **SAT / actors:** C800/D700 is a shared 0x80-byte record: pixel **Y at +3,
  X at +5**. SAT sub-block at `slot|0x20`, stride 5. Moving pads:
  `platform_tbl` Y vs SAT Y−1. Field table: `docs/game-notes.md` Actors.
- **Game Master:** 6 bytes at CPU 0x7FFA vs RC-735 (`00 30 31 13 35 AA`);
  flag 0xE600. `gm_opt_tbl` at 0x4010 is a failed CD handshake (word-padded
  `"CD"`). Features that work are the ones this ROM implements after the
  fingerprint.
- **HUD font:** `'0'`–`'_'` slots; `@` `_` `?` draw a rule, a cursor, and
  `=`. Render the glyph before trusting the `vk` spelling.
- **Vendor RAM:** 0xC700–0xC70F (`docs/vendor.md`).
- **Maps:** connectivity is navigation, not geography (stage 8 vertical
  loop). Ground truth for room positions is F2 `minimap_room_pos` (0x9681).
  Decode with `tools/roomperm.py`; s18r9 brick IDs are decoration and solid
  — per-room override, not a cleverer tile heuristic.

## Companion skills (workbench)

Linked by `make skills`. Generic methodology is not this file.

- `konami-msx-disasm` — procedure
- `msx-scaffold` / `msx-bootstrap` / `msx-code-data` / `msx-regen` / `msx-romscan`
- `msx-gfx` / `msx-gfx-sheets` — VK stems in `vk-gfx-sheets`
- `konami-psg` / `msx-psg-catalogue` — VK wrapper `tools/psgplay.py`
- `msx-cocoamsx` — research display (`msx-trace` is a stub). VK RAM / WATCH
  presets stay in `docs/progress.md`.

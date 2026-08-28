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
`docs/game-notes.md` before starting a new game; copy `tools/disasm/` and the
`Makefile`. Game-specific dump/sheet/handbook scripts stay in `tools/` (VK:
`gfxdump.py`, `roomperm.py`, `psgplay.py`, `emit_identified_data.py`,
`guide_assets.py`). Paths below are relative to this repo root.

## Non-negotiables

- **Byte-exact round-trip at every step.** The build must reproduce the original
  ROM byte-for-byte (`make verify` checks SHA-1 against a committed
  `<Game>.sha1`). Run it after every edit. Never commit a change that breaks it.
  An original ROM dump is not required to assemble or verify.
- **No binaries in the final repo** (goal). Each 8 KiB segment starts as an
  `INCBIN` placeholder and graduates to annotated `.asm` (code) or extracted data
  assets (graphics/tables) as it's understood. Don't mass-convert bins to opaque
  `db` dumps; reverse incrementally.
- **Assembler = sjasmplus, disassembler = z80dasm.** Both built from source (not
  committed).

## Project scaffold (mirror vampirekiller/)

- Root: `<Game>.asm` (stitches segments via `PHASE`/`INCBIN`), `Makefile`,
  `README.md`, `.gitignore` (ignore `generated/`, built ROM, segment bins).
- `segments/` — one `.asm` per paging window (VK: `banks_0123` 0–3 at
  `PHASE 0x4000`, `banks_456`, `banks_78`, `banks_9a`, `banks_bcd`, `banks_ef`).
  `.bin` only for banks still `INCBIN`'d (VK: none left).
  Fully migrated banks have no `.bin`;
  `split-rom.sh` emits the leftovers and deletes migrated ones. Regen of a
  migrated bank uses the original ROM (`regen-seg.sh` slices it itself).
  All hand-authored disassembly metadata lives here: `bios.inc` (MSX BIOS entry
  names), `ram.inc` (confirmed work-RAM), `*.inc` type ids (`actors.inc`,
  `items.inc`, `weapon.inc`, `sfx.inc`, `poses.inc`, `scenery.inc`,
  `event.inc`, `state.inc`, `dir.inc` — small numeric `equ`s, **not** in `msx.sym` or z80dasm
  rewrites every `0x01`), `msx.sym` (routine/label names for z80dasm regen),
  `banks_*.blocks` (code/data split maps, one per paging window). Anything needed to reassemble or
  regenerate belongs here.
- `docs/` — `progress.md` (checklist + RAM map + working notes), `game-notes.md`
  (detailed findings).
- `tools/disasm/` — reusable MSX/Konami helpers: `regen-seg.sh`, `split-rom.sh`,
  `strip-listing.py`, `romscan.py`, `seg_sym.py`, Konami RLE (`rledec.py` /
  `rleenc.py`), `gfxview.py`, `pngwrite.py`, `psgplay.py` (packed-PSG → WAV).
  Copy this directory for a new game.
- `tools/` — game-specific executable tooling (VK gfx sheets, room maps, PSG
  catalogue front-end, handbook art) plus `sjasmplus`.
- `gfx/` — editable graphics assets (PNG + txt); original compressed bytes stay
  authoritative.
- `music/` — rendered BGM WAVs from the PSG bytecode (`tools/psgplay.py`
  wrapping `tools/disasm/psgplay.py`). AY-3-8910 timing (fmaster/8); no
  speaker filter.
- `sfx/` — rendered SFX WAVs (`make sfx`); same `{id}_{name}.wav` convention
  as `music/`.

## Mapper first

Identify the mapper before anything else (size, segment count, switch
addresses, fixed vs paged pages). Konami4: 8 KiB banks, seg 0 fixed at
0x4000-0x5FFF (entry point + resident code/main loop/IRQ), pages switched by
writing the bank number to an address in the target page. Document it at the top
of `<Game>.asm`.

## Workflow per segment

1. `tools/disasm/regen-seg.sh <n> <org> [blocks]` → writes `generated/segNN.generated.asm`
   (listing comments already stripped) + `generated/segNN.raw.asm` (raw reference).
2. Fold the clean disassembly into the paging-window file (`banks_0123.asm`,
   `banks_456.asm`, …) by hand and annotate.
   Switch `<Game>.asm` for that window from `INCBIN` to `INCLUDE`.
   Once a bank has no remaining `INCBIN` slices, drop it from `split-rom.sh`
   and delete `segNN.bin`.
   `PHASE` the window to its CPU base.  Two windows that share CPU addresses
   (VK play bank 3 and map bank 13 both occupy 0xA000) cannot reuse z80dasm
   `lxxxh`/`sub_xxxh` names — give the second unique labels or the assembler
   will error on duplicates.
3. Separate code vs data with a `segments/banks_XXXX.blocks` file matching
   the paging-window `.asm` (only changes rendering, never bytes). Mark
   mis-decoded tables and convert them to `db`.
  Keep unreversed graphics as `INCBIN` slices of the bank `.bin`, not a mass
  `defb` dump. Identified blobs (tilesets, metatile tables, named RLE streams)
  graduate to labeled `defb` (Metal Gear style); 4bpp tiles are hex pixel-rows.
  **1bpp sheets** (uncompressed 8×8 glyph/tile bitmaps, typically consumed by
  `glyph_blit` / `glyph_blit_run`) are extracted the moment they are identified:
  one `defb %xxxxxxxx` row per scanline (MSB = left). Do not leave a known 1bpp
  sheet as hex in a leftover dump. Packed 1bpp sprite RLE uses the same `%`
  rows for pixel bytes (run/literal counts stay hex). PNG is preview-only
  (hex tile-id labels, not ASCII chars) until the packer is byte-exact. Mixed
  banks (named tables + hex leftover slices). VK bank 15 continues
  `psg_music` + shared `music_phrases` + env tables + 4bpp Dracula portrait.
  VK banks_ef is scenery
  lists + spawn masks + enemy lists + sound: emit the cracked tables as commented
  `defw`/`defb` once ids are named; packed PSG as labeled hex streams.
4. `make verify` → must stay byte-identical.

## Conventions (enforced)

- **Never** leave z80dasm's trailing `;addr bytes ascii` listing comments in
  committed `.asm`. Regen strips them; `tools/disasm/strip-listing.py` is the safety net.
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
  all game code/data. Small numeric type `equ`s (`actor_zombie: equ 0x01`) live in
  an `INCLUDE`d `.inc`, never `msx.sym` (VK: `actors.inc`, `items.inc`,
  `weapon.inc`, `sfx.inc`, `poses.inc`, `scenery.inc`, `event.inc`,
  `state.inc`, `dir.inc`).
- **A symbol in an immediate operand is usually a lie.** z80dasm substitutes a
  symbol for *any* matching value, so every small constant that collides with a
  low BIOS entry comes back as that name: `ld de,0` reads `ld de,CHKRAM`
  (0x0000), and 8/0x10/0x14/0x20/0x50 become SYNCHR/CHRGTR/WRSLT/DCOMPR/SETRD.
  Same trap for a code label whose address doubles as data (`ld bc,l4206h` was a
  66x6 rectangle size). Only `call`/`jp`/`jr` targets are real references —
  rewrite `ld rr,NAME` back to a hex literal (byte-identical, and `make verify`
  proves it). Audit with a regex for BIOS names on non-branch lines after every
  regen; VK had 91 of these hiding in segs 0-3.
- **`msx.sym` is flat, the ROM is banked.** One hand-maintained file covers every
  bank, but z80dasm `-S` can only attach one name to a CPU address. VK has 48 of
  these collisions (21 named-vs-named, including 0x902E `spike_bars_restore` vs
  `sfx_0e_block_break`). `tools/disasm/regen-seg.sh` therefore runs `tools/disasm/seg_sym.py N`
  first: BIOS + out-of-window names from `msx.sym`, in-window names from *this*
  bank's labels. Keep putting new names in `msx.sym` (the catalog); do not split
  it into per-segment files. `tools/disasm/seg_sym.py --audit` reprints the collision
  list. Cross-bank calls to a unique address still name; colliding addresses in
  a *different* bank are left numeric.
- **Text**: MSX games often store text as `(ASCII - offset)` because the font is
  loaded at a nonzero tile base. Crack the offset, then use an sjasmplus `MACRO`
  (`vk` / `cr` in `VampireKiller.asm`) so source strings stay readable ASCII
  while the bytes match the ROM (space → 0x00; HUD also subtracts 0x10).
  Position/control bytes stay as `defb`.
- **Graphics**: usually custom RLE to VRAM (SCREEN 5 = 4bpp bitmap on MSX2, plus
  1bpp hardware sprites). Find the decompressor, then extract to editable assets
  with the gfx pipeline; keep compressed bytes authoritative. Contact sheets
  (one tile or 16×16 sprite plane per cell, header id, in-game palette) follow
  `msx-gfx-sheets`.
- **1bpp sheets in binary**: any uncompressed 1bpp glyph/tile sheet we identify
  is committed as `defb %xxxxxxxx` (MSB = left, one row per line) plus a PNG
  contact sheet labelled with hex tile ids. Same `%` form for packed 1bpp RLE
  *pixel* bytes; control bytes stay hex. 4bpp tiles stay hex nibble-rows. VK's
  three raw 8×8 sheets are `hud_font`, `credits_font`, and `logo_font` (boot
  Konami logo; not the HUD `<` `=` `>` cells even though those tile ids overlap).

## Konami idioms to expect

- Inline word-table dispatch by index in A (VK's `DISPATCH_A`): a `call` followed
  by an inline `dw` table, handler picked by A. Other dispatch shapes: `ld hl,tbl;
  ADD_HL_A; ld a,(hl)` (byte table → sub-index/action id), and `ld de,tbl;
  ADD_DE_A` with a multiply (`add a,a` x3 = ×8) for **row** tables (N-byte rows).
- **Off-by-one dispatch**: a `dec a` (or `sub base`) right before the dispatch means
  id N uses `table[N-1]`. Always check for it — decoding the table from the wrong
  base shifts every entry. (VK's `collect_bonus` does `dec a`; black bible id 0x10
  → `table[0x0f]`.)
- **A jump table at the end of a bank can continue into the next page.** Extra
  indices are not automatically invalid. Mapper switch addresses (e.g. 0x6000) are
  typically **write-only**; a *read* returns the ROM currently paged there. Konami
  will put more handler words in that bank's head. Alignment follows the table, not
  the page: an odd table start plus a padding byte means type N's word begins at
  0x6001, so do not `defw` from 0x6000. Confirm overflow by matching words to
  known handlers (VK: spawn `entity_tbl` types 1–22 in seg0; type 0x1E reads
  `flame_init` at 0x9B67 exactly). Types that look "past the table" (flame, pickup,
  boss add-on, placed enemy) often live here.
- **Spawn-init table ≠ per-frame tick table.** `spawn_actor` `DISPATCH_A` is often
  first-time setup only; a second word table in another bank ticks every frame.
  Extra type ids reuse a tick and enter at a *later instruction* of the same init
  (skip "already flying", skip a water-splash spawn). One enemy on the sheet can
  have two type ids: generator vs authored placement.
- **Packed room object lists are usually actor type ids.** The emit path is
  `C = id&0x7F` into `spawn_actor`, not a separate sprite catalogue. Types that
  come from a continuous bitmask spawner are often **absent** from the list; the
  placed copy of the same enemy is a different id. A high bit on the stored byte
  may be stripped at spawn (not "scenery"). Name ids from that spawn call. The
  same numeric value in another table (display-type, drop-gate) is a different
  field — scan the field the code actually tests. VK's object-list Attr is
  **Y<<4|X** (same packing as the scenery pos byte); `object_list_spawn` loads high→E (Y)
  and low→D (X). Do not decode it as X<<4|Y — that swap looks like a 16px Y
  error on every record whose nibbles differ by 1.
- **A second packed list in the same bank often uses a different grammar.** VK's
  enemy `object_list` is `0x00` next-room / `0xFF` end-stage; the candle/scenery
  list is `0xFE` / `0xFF` / `0x00`-end-hub plus a 3-byte `0x7F` covering wall
  (still bits7-5=011 / 32x32; extra is the chest/vendor reveal — bit7 is clear
  so load stamps bricks, it does not spawn the reveal). Don't reuse the first
  decoder. Stage 0 may bypass the hub pointer table and
  point at a stream that sits *between* the words and hub 0.
- **MSX SAT Y is the line above the sprite.** Writers often store the visual
  row and `dec a` into SAT. VK's moving pads do this (`platform_tbl` Y vs SAT
  Y-1); the stand test compares Simon against the visual row, not the SAT byte.
- **RNG via `ld a,r`** (the refresh register) — a cheap pseudo-random source. If a
  mechanic behaves differently run-to-run for the same input, grep for `ld a,r`
  near its state machine; the branch after it is the coin-flip.
- **Packed BCD everywhere**: `add a,001h; daa` (and `daa` chains across bytes) =
  a BCD increment. Scores, heart/money counters, prices, and many on-screen numbers
  are stored packed-BCD, little-endian, often /100 (a table byte of 0x50 = "50").
- **A boot-time slot scan is usually companion-hardware detection, not a
  re-entrancy flag.** A routine that walks `EXPTBL` (0xFCC1), recurses into
  expanded subslots, and `RDSLT`s a handful of bytes at a fixed address in each
  is fingerprinting *another cartridge*. Konami's **Game Master** cheat cart
  (RC-735) is the common one: VK compares 6 bytes at CPU 0x7FFA — the last six
  of a 16 KB page at 0x4000, which on RC-735 are `00 30 31 13 35 AA`. The last
  two are Konami's standard 16K stamp (BCD last-two-digits of the RC-code +
  0xAA); the rest is the uniqueness window. The result parks in a single flag
  (0xE600) that gates a pause / frame-advance key pair in the interrupt
  handler, a hidden stage-and-lives select menu reached from the title, and a
  CONTINUE option on game over. The reverse direction also exists: later
  Konami titles advertise a `"CD"` / `"AB"` option table at 0x4010 for Game
  Master to parse (stage/lives/score addresses + max values). Writing those
  four header bytes as words (extra 0x00) makes the word at 0x4010 `0x0043`
  instead of `0x4443`, so Game Master 1 never sees it — VK's `gm_opt_tbl` is
  that failed handshake; the features that actually work are the ones the
  *game* implements after fingerprinting the cart. If you find one flag set
  at boot and read from unrelated places, look for the RDSLT compare before
  inventing a meaning for it — and expect its features to sit in ROM regions
  z80dasm mangled, since nothing in the normal flow reaches them.
- **In-house fonts reuse ASCII slots for symbols.** VK's HUD font spans ASCII
  `'0'`-`'_'`, but the `@`, `_` and `?` slots actually draw a horizontal rule, a
  right-pointing cursor arrow and an equals sign. A text macro that reproduces
  the bytes will therefore *read* as gibberish (`@@@MENU@@@`, `STAGE NUMBER?`)
  while drawing something sensible (`---MENU---`, `STAGE NUMBER=`). Render the
  glyph before trusting a decoded string, and comment the real shape next to the
  macro rather than "fixing" the spelling.
- **Subsystem state blocks**: a feature usually parks all its state in one
  contiguous RAM block (VK vendor = 0xC700..0xC70F). Find the block by snapshot-diffing
  while the feature is active, then `romscan xref` /
  grep the block bytes to reach the handler.
- State machines driven by a per-frame tick off the 60 Hz timer IRQ (`H.TIMI`).
- Actor/object slot arrays (fixed count, fixed stride) with a type/active byte at
  offset 0; a per-type behaviour handler table indexed by type. Cross-reference
  Metal Gear's `constants/structures.asm` ([GuillianSeed/MetalGear](https://github.com/GuillianSeed/MetalGear)) — Konami reused
  structures across games. VK C800/D700 is a shared 0x80-byte record: pixel **Y at
  +3, X at +5** (hardware SAT is Y then X — a RAM dump that "moves on +03" during
  a horizontal flee is Y, not a per-type layout). SAT sub-block at `slot|0x20`,
  stride 5. Field table: `docs/game-notes.md` Actors.

## Deriving level / map structure

Konami level data is layered pointer tables, not flat maps. Expect: a per-world
`rowbase[]`/count table → a per-room pointer table → a compact **metatile stream**
(e.g. VK: 8×6 metatiles, each a 4×4 block of 8×8 tile ids) that a build routine
expands into a work-RAM tile map on room entry. Find the build routine (it pages
the data banks in, expands, then restores banks), and mirror its exact indexing in
a decoder tool (VK: `tools/roomperm.py`). Cross-validate the decode **byte-exact
against RAM snapshots** of the live tile map.

- **Room-to-room movement is usually TABLE-driven, not arithmetic.** Don't assume
  "room id ± 1". VK uses a per-world connectivity table (nibbles up/down/left/right
  = destination room, 0xF = blocked); a per-frame edge/stair detector sets a
  pending-direction byte, and a "brain" routine looks up the table and writes the
  new room id.
- **A connectivity/transition graph is a NAVIGATION graph, not a spatial one — do
  not reconstruct geography from it.** Exits can wrap or teleport on *both* axes, so
  a BFS embedding is under-determined and will silently mis-place rooms. In VK I
  built a BFS layout on the axiom "horizontal links can loop, vertical can't" — and
  it was just false: stage 8 has a vertical loop (`4.down→7` **and** `7.down→4`,
  though 7 is physically above 4), and other stages have portal edges. The fix was
  not a smarter heuristic — after A/B comparison the BFS layout was dropped entirely
  in favour of the game's own authored table (next bullet); keep the graph only for
  what it actually models (navigation → door detection).
- **Look for the game's OWN authored data / in-game viewer before reconstructing.**
  If the game shows the thing you're trying to derive (a map screen, a level-select,
  a debug menu), that display is driven by an *authoritative* table — find it and
  decode it instead of inferring from a related-but-different structure. VK's F2
  "world map" item led straight to a hand-authored per-room position table (seg2
  `minimap_room_pos` 0x9681: stage→position-code array→coord), which is ground truth
  for all 19 stages and reproduced every layout the user had hand-corrected. The
  user's domain knowledge ("press F2") short-circuited a long, doomed static trace —
  ask what the game itself exposes.
- **Two distinct transition paths.** Normal in-stage moves (write the room id) vs
  stage-advance (bump the stage id, reset room, spend a key). They're gated by
  different flags — trace each separately.

## Render it to validate (and to catch your own mistakes)

Rendering ROM-derived structure to an image and eyeballing it against the real
game is one of the highest-leverage checks. It repeatedly caught classification
bugs in VK (which tile ids are solid vs decorative vs climbable stairs; where the
doors are) that looked fine in the raw bytes. Let the user compare against the
game and give per-stage/per-room feedback; fix the classification, re-render.

- **Geometry heuristics have hard limits — prefer the engine's own test.** A
  feature can be geometrically identical to a non-feature (VK: a white-key *door*
  opening is byte-for-byte identical to a plain walled recess — both are "wall,
  then a void gap, then floor"; a scenery column reads as passable). When a
  heuristic is provably ambiguous, stop guessing and find where the engine *itself*
  decides. Fall back to a small curated, human-verified table only as a stopgap;
  ship the heuristic behind a flag with a `TODO` listing the failing cases.
- **Sometimes the answer is "no rule can work here — use a per-instance override."**
  A tile-index heuristic is only valid when the ID carries the meaning. VK's Dracula
  boss room (stage 18 room 9) builds its purely-decorative side columns from the SAME
  brick tile IDs (`06`-`0b`) as its one real solid (the floor), so decoration and
  solid are byte-indistinguishable — DECOR sets, the engine's own per-stage solidity
  threshold, and context-adjacency all fail identically. Confirm the dead-end by
  measuring the blast radius of the "principled" fix (switching to the engine
  threshold changed stage 10 by 16%, room 9 still wrong) before shipping it, then take
  the cheap correct path: a hand-authored per-room override, not a cleverer global rule.
- **Watch the RAM the feature is supposed to fill, not the code you hypothesized.**
  In VK the 0x1F object path *could* have fed 0xC5AD/0xC5AE; a WATCH on those
  bytes showed the real writer was seg13 `door_load_coords` copying `door_tbl`.
  Coverage of a candidate (does it appear everywhere the feature does?) still
  matters; the watch is how you find the writer when the candidate is wrong.
- **`ld (nn),hl` stores L at nn and H at nn+1.** A table of `(room, Y, X)` loaded
  with L=Y, H=X looks like "X at C5AD" if you assume (X,Y) struct order. Confirm
  against a known axis (here: proximity compares C5AD to Simon Y at 0xC425).
- **When two mechanisms are plausible, render BOTH and let the human pick.** Don't
  commit to a static-analysis hypothesis before validating it. In VK I traced a
  slick object path (display-type 0x1F → seg2 `l881bh`/`vendor_spawn`) and was ready to
  call doors "placed objects." A/B renders (`roomperm.py --compare-doors`) correctly
  **rejected 0x1F** (those 3 rooms are placed hanging bats, list-id 0x1F; the
  vendor/reveal path is display-type 0x1F on a brazier) but the remaining gap was
  not "geometry is universal except one stage" — it was a per-stage 3-byte
  coordinate table (`door_tbl` 0xBB61) that the blocked-edge heuristic only
  partially overlapped (stage-exit doors, not intra-stage ones). Cheap comparison
  settles a wrong theory; WATCH the leftover RAM to find the right one.
- **A real signal from code can still be the WRONG feature.** The display-type
  0x1F brazier path was genuine engine code — vendor / reveal, not the white-key
  door. List-id `0x1F` in the same 3 rooms is a placed hanging bat (`object_list_spawn`
  list-id = actor type). Finding a mechanism that *could* explain something
  isn't proof it *does*; confirm coverage before trusting it.
- **Engine door placement can be a per-stage record, not room geometry.** VK's
  white-key door is 19×3 bytes: one room + pixel (Y,X) per stage. After it opens,
  connectivity says where walking that edge goes (blocked → next stage, else
  another room). Don't treat "blocked edge with a gap" as the door detector.

## Rooting out logic (static analysis)

Use the `msx-romscan` skill (`tools/disasm/romscan.py`). Do not grep leftover
`.bin` files or write ad-hoc xref python.

Gotchas:

- **Search source-only banks too.** Migrated banks have no `.bin`. `romscan`
  reads each bank from the ROM. A routine that looks "never referenced" in
  leftover bins is often driven from seg0.
- **Cross-bank calls are normal.** The resident bank (0x4000-0x7FFF) freely
  `call`s into whatever is paged at 0x8000/0xA000. Named labels stay byte-exact;
  comment the callee's bank.
- "No `code` xref" ≠ dead code: an entry can be reached via a **stored/computed
  pointer** (handler written into an object field) rather than a static transfer.

## Cost discipline

- Prefer the existing tools over ad-hoc shell. Reuse `regen-seg.sh` (`msx-regen`)
  and `romscan.py` (`msx-romscan`); don't re-hand-roll xref/table-decode python.
- Don't read whole 5 KLOC segment files linearly; use Grep/semantic search to the
  region of interest.
- Batch independent shell/reads in one turn. `make verify` is fast (<1 s) — run it
  freely.

## Companion skills

- `msx-regen` — `regen-seg.sh`, `seg_sym.py`, `strip-listing.py`, `split-rom.sh`
- `msx-romscan` — xref / jump-table decode
- `msx-konami-gfx` — RLE + ASCII `gfxview.py` (not labelled PNG sheets)
- `msx-gfx-sheets` — `gfxdump.py` contact sheets

Runtime tracing (instrumented CocoaMSX, snapshot diffs) lives in
`~/code/cocoamsx-disasm`, not this repo.

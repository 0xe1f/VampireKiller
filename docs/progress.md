# Progress

Running status of the disassembly. `docs/game-notes.md` holds the detailed
reverse-engineering findings; this file is the high-level checklist.

## Done

- Toolchain + build: `VampireKiller.asm` stitches 16 segments; `make verify`
  confirms the rebuilt ROM is byte-identical to the original.
- Segment 0 (resident bank) disassembled with MSX/MSX2 BIOS symbol names.
  Annotated: cartridge header, `INIT`, `INT_HANDLER` (H.TIMI), the dispatch
  helpers (`ADD_HL_A`, `ADD_DE_A`, `DISPATCH_A`), the main tick `sub_414dh`
  (two-level state machine + `main_state_tbl`), the front-end transition
  `l4398h`, and the entity dispatch/`entity_tbl` at `0x5FD0`.
- Text: encoding cracked (`ASCII - 0x10`). Added the `vk()` helper and converted
  the HUD and title/front-end strings to readable ASCII (byte-exact).
- Reference: Metal Gear disassembly used to confirm the text scheme and the
  Konami actor/OBJ struct (cloned locally to `references/`, not committed).
- Graphics: identified video mode as **SCREEN 5** (4bpp bitmap) in `sub_4b60h`;
  classified the banks (code = seg 0-3, graphics = seg 4-15). Added
  `tools/gfxview.py` (1bpp/4bpp ASCII-art viewer).
- Graphics format **cracked**: RLE decompressor `sub_46f8h`/`l46f2h` (grammar:
  end / set-addr / run / literal) unpacks all bitmaps + sprite patterns to VRAM.
  Bank switchers `sub_5369h`/`sub_5381h`/`sub_533dh` decoded. Added
  `tools/rledec.py`; extracted + rendered a 16-frame 16x16 sprite set from
  seg 13 (source 0xA319) into the sprite pattern generator table (0xF800).

- Editable graphics workflow ("path A") set up: original compressed bytes stay
  authoritative (ROM byte-exact), readable dumps live in `gfx/`. Added
  `tools/rleenc.py` (optimal RLE packer), `tools/gfxdump.py` + `gfx/manifest.tsv`
  + `make gfx`. Seeded catalogue with two confirmed sprite sets (seg 13).
- Segment 1 (banked code @ 0x6000) brought into the build as disassembled source
  (byte-exact), shared BIOS names moved to `segments/bios.inc`. Leading data map
  in `tools/seg01.blocks` (tables at 0x6000-0x602f, 0x605f-0x615a incl. a word
  table at 0x608d). Annotated so far:
  - `KONAMI_LOGO_DRAW`/`KONAMI_LOGO_STEP` (0x6209/0x6253): logo screen + the
    top-to-bottom wipe (confirmed by the author); `sub_6276h` tile-string interp.
  - Object-list loader cluster 0x615b-0x6208: `sub_615bh` unpacks the current
    cell's object list from seg 14 into the 4-byte-slot tables at 0xDB00/DC00/DD00
    (`sub_6188h` unpacker, `sub_61a5h` per-level pointer, `sub_61b0h` clear,
    `l61c2h` emits hardware sprites via seg0 0x5F26). RAM: 0xD000/D001/D002 =
    current row/col/level index.
  - `LOOKUP_WORD_TBL` (0x6549): generic word-table lookup (DE=table, A=index).
  - Screen/level build cluster (annotated):
    - 0x62d7: arms mode bytes 0xC415=0x20/0xC418=0x80, then jp seg0 0x53BD.
    - 0x62ed: full screen builder - clears state, paints tiles (seg2 helpers),
      sets cell event, loads object list (sub_615bh) + emits sprites (l61c2h).
    - 0x63da: centre view (0xC425/0xC427 = 0x80), hide sprites, redraw chain.
    - `sub_633ah` (0x633a): set current cell event 0xCE00 from l6376h[row]
      (byte = column<<4 | event; event 6 has an immediate handler).
    - `sub_6389h` (0x6389): reset object/actor state (clears 0xC470..0xC6FF +
      subsystems); `sub_63beh` clears 0xC420..0xC46F; `sub_63cch` hides all 32
      sprites (Y=0xE0 in 0xD600 shadow); `sub_63b8h` strided memory clear.
    - `sub_6409h` (0x6409): set screen position 0xC425/0xC427/flag 0xC42C from
      per-row table l6426h (2 bytes/row).
  - Actor->sprite rendering (annotated):
    - 0x644c: build one actor's hardware sprites from its shape stream; pages
      seg 6 (sprite shapes) into 0xA000, looks shape up in word table 0xB473 by
      (ix+0x0B), writes sprite attrs at (ix|0x20) offset by actor X/Y (ix+3/+5);
      stream codes 0x80/81/82 pick fixed (dx,dy) offset lists; restores seg 3.
    - 0x64ec / 0x64f3: render every active actor in a list (8 @ 0xD700 / 7 @
      0xC800, stride 0x80) via `sub_6508h`, which copies Y/X/pattern into the
      0xD638 sprite-attr shadow and fills the pattern from the l6a70h table.
    - 0x6552: per-frame VRAM refresh - re-uploads the animated tile/sprite
      patterns each frame; animation phase in 0xC00F. Falls back to the plain
      shadow blit l65abh (copy 0xD400 -> VRAM 0xF400) when idle.
  - Data tables marked in seg01.blocks this pass: logo layout 0x6296-0x62d6,
    event table 0x6376-0x6388, per-row pos table 0x6426-0x644b, sprite offset
    lists 0x64d4-0x64eb.
  - Remaining seg1 routines still to map; the seg0-reachable entry points
    are the priority (0x65b7, 0x66c1, 0x6848, 0x6b06, 0x783e, 0x7956,
    0x7ad6, 0x7aee, 0x7b39, 0x7d6f).

- Runtime tracer (CocoaMSX) wired up and used for the first time:
  - `tools/CocoaMSX` submodule (branch `disasm-tracing`) builds with the opt-in
    `disasmtrace` module (exec/write/bank logging tagged with the paged ROM
    segment). Build: `tools/build-cocoamsx.sh`; run + capture: `tools/trace-run.sh`
    (env: EXEC / WATCH addr ranges, LOG). Log lands in `generated/` (gitignored).
  - First traced session (logo -> title -> attract -> stage 1) confirmed:
    * 0x6552 is frame code (runs every frame); 0xC00F cycles the 16 phase values
      {00,08,..,78} in the exact scrambled order the `add 0x68 / and 0x78` step
      produces - validates that routine down to the arithmetic.
    * 0x644c really pages seg 6 for sprite shapes (page 2b showed seg 06).
    * bank schedule during play: page 1b = seg 01/0b, page 2a = seg 02/0e(/0c),
      page 2b = seg 03/0f/0d/06.
  - Correction from the trace: the 0xCE01 state machine at 0x65b7+ never ran
    during logo/title/attract/stage 1, so it is event-driven (boss / death /
    transition - TBD), NOT the intro cutscene. Left unlabelled pending a capture.

## In progress / next

1. Sprites/graphics: resolve the per-level/per-actor pointer tables (l55deh,
   0xA281+A, 0xA2D1+A, ...) to map the remaining streams to Simon / enemies /
   bosses / items / tiles, and add them to `gfx/manifest.tsv`.
2. Convert the tile-layout block `0x4C3F-0x4D0E` in seg00 from misdisassembled
   "code" to `db` data (currently marked with a comment; byte-exact).
3. Annotate the in-game state handlers (primary states 3-13 in `sub_414dh`).
4. Continue disassembling segments 1-15.

## Working notes

- Annotation style: favour per-opcode comments, not just block headers. A block
  header explaining a routine's purpose is welcome, but it must NOT replace
  inline comments on the individual instructions - annotate the important
  opcodes (VDP writes, magic constants, state/RAM addresses, branch conditions,
  loop counters) line by line so the logic can be followed without decoding the
  bytes by hand. Inline comments start at column 32 (see existing seg00/seg01).
- Regenerate a segment's disassembly: `tools/regen-seg.sh <n> <org> [blocks]`.
  It writes two scratch files into the gitignored `generated/` dir (which holds
  all temporarily generated files): `generated/segNN.generated.asm` (clean -
  z80dasm's `;<addr> <bytes> <ascii>` listing comments already stripped, fold THIS
  into the committed source) and `generated/segNN.raw.asm` (the full listing, kept
  only as a temporary byte/address reference while reversing). Fold changes into
  `segNN.asm` by hand so the annotated file is never clobbered.
- Rule: the committed `segNN.asm` must NEVER carry z80dasm's trailing address/opcode
  listing comments. Regen strips them automatically; `tools/strip-listing.py
  segments/segNN.asm` is still available as a safety net (it drops the byte-listing
  noise but keeps hand-written `; ...` comments and re-aligns them).
- Data regions go in a `.blocks` file (see `tools/seg00.blocks`, `tools/seg01.blocks`);
  a `.blocks` file only changes code-vs-data rendering, never the emitted bytes.
  BIOS names live once in `segments/bios.inc`; routine names go in `tools/msx.sym`.
- Every `vk()`-emitting Lua block MUST use `LUA ALLPASS` — plain `LUA` emits only
  on the final pass and drifts all later labels.
- After any edit, run `make verify` before moving on.

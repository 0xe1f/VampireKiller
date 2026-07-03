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
  Konami actor/OBJ struct (cloned locally to `reference/`, not committed).
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

## In progress / next

1. Sprites/graphics: resolve the per-level/per-actor pointer tables (l55deh,
   0xA281+A, 0xA2D1+A, ...) to map the remaining streams to Simon / enemies /
   bosses / items / tiles, and add them to `gfx/manifest.tsv`.
2. Convert the tile-layout block `0x4C3F-0x4D0E` in seg00 from misdisassembled
   "code" to `db` data (currently marked with a comment; byte-exact).
3. Annotate the in-game state handlers (primary states 3-13 in `sub_414dh`).
4. Continue disassembling segments 1-15.

## Working notes

- Regenerate a segment's raw disassembly: `tools/regen-seg.sh <n> <org> [blocks]`.
  This overwrites `segments/segNN.generated.asm`; fold changes in by hand so the
  annotated `segNN.asm` is never clobbered. The generated scratch keeps z80dasm's
  `;<addr> <bytes> <ascii>` listing comments (handy while placing annotations);
  strip them from the finalized file with `tools/strip-listing.py segments/segNN.asm`
  (it removes the byte-listing noise but keeps hand-written `; ...` comments and
  re-aligns them). Data regions go in a `.blocks` file
  (see `tools/seg00.blocks`); BIOS/routine names go in `tools/msx.sym`.
- Every `vk()`-emitting Lua block MUST use `LUA ALLPASS` — plain `LUA` emits only
  on the final pass and drifts all later labels.
- After any edit, run `make verify` before moving on.

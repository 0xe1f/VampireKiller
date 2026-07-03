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

## In progress / next

1. Sprites: disassemble a graphics bank (segments 4-15) to locate the sprite
   pattern data and emit it as editable 16x16 (32-byte) pattern arrays,
   mirroring Metal Gear's `gfx/sprites.asm`.
2. Convert the tile-layout block `0x4C3F-0x4D0E` in seg00 from misdisassembled
   "code" to `db` data (currently marked with a comment; byte-exact).
3. Annotate the in-game state handlers (primary states 3-13 in `sub_414dh`).
4. Continue disassembling segments 1-15.

## Working notes

- Regenerate a segment's raw disassembly: `tools/regen-seg.sh <n> <org> [blocks]`.
  This overwrites `segments/segNN.generated.asm`; fold changes in by hand so the
  annotated `segNN.asm` is never clobbered. Data regions go in a `.blocks` file
  (see `tools/seg00.blocks`); BIOS/routine names go in `tools/msx.sym`.
- Every `vk()`-emitting Lua block MUST use `LUA ALLPASS` — plain `LUA` emits only
  on the final pass and drifts all later labels.
- After any edit, run `make verify` before moving on.

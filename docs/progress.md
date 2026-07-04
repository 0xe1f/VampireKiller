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
  - Event/cutscene machinery (annotated; event-gated, not seen in normal play):
    - sub_65b7h (0x65b7): event sub-state machine, DISPATCH_A on 0xCE01 (11
      handlers, inline word table now decoded to defw). 0xCE02 = per-step timer;
      the last handler clears 0xCE00 and raises 0xCE40 (done).
    - sub_66c1h (0x66c1): post-event machine, DISPATCH_A on (0xCE40-1) (4
      handlers). Drives the cutscene script player, then bumps level counter
      0xD012 (cap 3) and writes VDP R23.
    - Cutscene sequencer: sub_6719h resets it; sub_6736h/sub_673fh advance a
      timeline tick 0xCE33 (every 4th frame); sub_674ah pages seg 8 + seg 5 and
      fires the keyframe due at the current tick from the script indexed by
      0xCE31 in script_ptr_6795 (entries {tick, action}; 0xFF action = end).
      Ramp table l6804h (triangle, 19 entries) animates via sub_67ebh/0x481b.
  - Data tables marked in seg01.blocks this session: the two event dispatch
    tables (0x65bd, 0x66c8), script_ptr_6795 (0x6795-0x67ea), ramp_tbl_6804.
  - Remaining seg1 routines still to map; seg0-reachable entry points next:
    0x6848, 0x6b06, 0x783e, 0x7956, 0x7ad6, 0x7aee, 0x7b39, 0x7d6f. The event
    machinery above wants a targeted trace (trigger a boss/death/transition) to
    confirm its purpose and get real names.

- Runtime tracer (CocoaMSX) wired up and used for the first time:
  - `tools/CocoaMSX` submodule (branch `disasm-tracing`) builds with the opt-in
    `disasmtrace` module (exec/write/bank logging tagged with the paged ROM
    segment). Build: `tools/build-cocoamsx.sh`; run + capture: `tools/trace-run.sh`
    (env: EXEC / WATCH addr ranges, LOG). Log lands in `generated/` (gitignored).
  - Apple Silicon crash fix: CocoaMSX's immediate-mode GL (`glBegin(GL_QUADS)` in
    `CMMsxDisplayView renderScreen`) segfaults inside Apple's Metal-backed GL shim
    (`AppleMetalOpenGLRenderer`/`AGXMetal`) on the first frame draw. Worked around by
    forcing Apple's software GL renderer via a pixel format with
    `kCGLRendererGenericFloatID`, gated on env `COCOAMSX_SOFTWARE_GL` (set by
    `trace-run.sh` unless `SOFTGL=0`). Also bumped `MACOSX_DEPLOYMENT_TARGET` to 11.0
    for the arm64 build. Slower but stable; the tracer is display-independent.
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
  - Second traced session (fresh start: logo -> title -> intro -> courtyard),
    watching 0xC000-0xC004 + 0xCE00-0xCE4F + 0xD000-0xD02F, pinned the top-level
    state machine (sub_414dh):
    * 0xC000 primary state walked 1 (title) -> 3 -> 4 -> 5.  State 3 = the intro
      cutscene (Simon nears the castle), a *timed* animation: its handler at
      0x41d1 steps sub-state 0xC001 0->4 and drives the 0xC004 phase counter
      (writers 0x41d7/0x4209/0x424e/0x41a4/0x4190/0x41cc).  State 4 = a brief
      bridge that builds the first stage; state 5 = in-stage play.
    * 0xC003 confirmed as the per-frame free-running counter (writer 0x4151).
    * On game start the intro handler calls RESET_RUN_STATE (sub_44cdh, writer
      0x44da): a single ldir zero-fills the whole run work block 0xC405..0xDFFF
      (event state 0xCE00+, actor arrays 0xD000+), then seeds 0xC410..0xC412 and
      view defaults 0xC415=0x20 / 0xC418=0x80.  seg1 sub_6389h (0x633e-0x634a)
      then re-clears 0xCE00/08/0B/15/40, exactly as read statically.
    * Entering the stage ran the full seg1 build+render pipeline in order:
      62d7 -> 62ed (build) -> 633a -> 6389 -> 63cc (hide sprites) -> 63da -> 6409
      -> 644c (actor->sprites) -> 64ec/64f3 (render) -> 6508 -> 6552 (frame
      refresh), confirming the static call graph.
    * State-5 handler reads game-event flags (0xC408/09/0A/0B/0C, 0xC413/1B) to
      choose the next primary state, so states 6..13 are death / level-clear /
      boss / game-over phases (exact roles still TBD - not hit by this trace).
  - Third traced session (courtyard, empty room; walk right -> walk left -> whip
    -> jump) mapped Simon's live state block.  All writers are seg1 player code
    in 0x6B00-0x7700:
      0xC425  Simon Y            (traced the jump Y-arc AA->90->B0)   6d67/6d49
      0xC426/0xC427  Simon X hi/lo (0xC427 +2/frame while walking)    6ca2
      0xC42C  facing 0=right/1=left (flipped between the two walks)   6c5e/6c3b
      0xC428  jump/step phase 01->13                                  6d55/6d53
      0xC422  whip attack phase 01->04->00                            7246/713c/7279
      0xC429  whip timer countdown 04->00                             7274/7242
      0xC42E/0xC42F  current anim-frame indices (scratch, base+facing) 6b81/6cc6/6d15/7681
      0xC470/0xC480(+76/+86)  background brazier flame animation (seg2, not Simon) 02:8695/86a5
    CORRECTION: 0xC425/0xC427/0xC42C were previously guessed (statically) to be
    a "view/camera position + flag".  They are Simon's Y / X / facing - there is
    no camera (room-based, non-scrolling).  Fixed the labels in seg01.asm at the
    0x63DA redraw and sub_6409h (per-room spawn Y/X/facing from l6426h).
  - Fourth/fifth sessions (whip braziers, collect pickups, change rooms):
    * 0xD001 = current room/screen index.  Walking into the next room bumped it
      0 -> 1 -> 2, always written by seg13 (0x0D) at 0xB98A, so seg13 owns room
      progression.  seg1 0x63BA then clears the actor lists (0xC800/0xD700/0xD780)
      on room entry.
    * Braziers are object structs at 0xC470/0xC480 (stride 0x10): +1 Y, +2 X (the
      two braziers sit at X=0x40 / 0xC0), +3 an alive/hit flag (1 -> 0 when whipped,
      writer 02:87c3 / 01:7fda), +7 sprite id 0xE0.  Populated by seg0 0x5B47-0x5B73
      from the room object list; init/cleared by seg1 0x6396.
    * Pickup items live in the 0xC800 actor slot.  The LARGE heart matches the
      observed orb->heart two-phase animation: 0xC801 = anim state (advanced by
      02:9C41), 0xC80C = 0x14-frame transition timer (20->0, then state flips).
      Small heart used a different seg2 animator (0x9B6B/0x9B8B, sprite 0x85/0x86).
    * STILL TBD: the heart/score/lives counters live below 0xC420 (~0xC40x), which
      the movement watch window did not cover, so pickup *values* (1 vs 5) weren't
      captured.  A 0xC400-0xC41F watch pass would pin them.

## In progress / next

1. Sprites/graphics: resolve the per-level/per-actor pointer tables (l55deh,
   0xA281+A, 0xA2D1+A, ...) to map the remaining streams to Simon / enemies /
   bosses / items / tiles, and add them to `gfx/manifest.tsv`.
2. Convert the tile-layout block `0x4C3F-0x4D0E` in seg00 from misdisassembled
   "code" to `db` data (currently marked with a comment; byte-exact).
3. Annotate the in-game state handlers in `sub_414dh`: 3 (intro), 4 (stage
   bridge) and 5 (play) are identified from the boot trace; still need 6-13
   (death / level-clear / boss / game-over) - capture each by triggering it.
4. Annotate the seg1 player routines the movement trace located: 0x6CA2 (horiz
   move), 0x6C3B/0x6C5E (facing), 0x6D15-0x6D67 (jump), 0x7213-0x728A (whip),
   0x7527 (whip multi-sprite emitter), 0x6B81/0x6CC6/0x7681 (anim frames).
5. Continue disassembling segments 1-15.

## Next tracing session (resume plan)

The setup works: `tools/build-cocoamsx.sh` then `tools/trace-run.sh` (software GL
is forced by default; Input Monitoring must be granted to the built .app once -
see the tracer notes below).  The tracer only logs bank switches unless EXEC
and/or WATCH ranges are given, and it reads them once at launch (change ranges =
relaunch = replay from the logo).

Highest-value next capture - pin the persistent inventory/counters, which sit
BELOW 0xC420 and every movement watch so far has missed:
  WATCH=c400-c41f,c470-c4ff,c800-c8ff,d000-d0ff   EXEC=  (off)
Then, from a fresh start, whip the first courtyard brazier (heart++), take one
hit, and note the on-screen hearts/score/lives/weapon so each byte in 0xC40x can
be labelled.  Weapon type is in this block too (leather -> chain whip changed a
byte we never watched).

After that, trigger the still-dark machinery:
  * death: WATCH=c000-c004,c408-c41f,ce00-ce4f  -> lights up a state 6-13 handler
    and possibly the 0x65b7 event machine (0xCE01), which has NEVER run in any
    normal-play trace (logo/title/attract/intro/stage/room/level).
  * boss fight: same WATCH plus the cutscene player - best shot at 0x65b7/0x66c1.

Known live RAM map (runtime-confirmed this session):
  0xC000 primary state  0xC001 sub-state  0xC003 frame ctr  0xC004 phase timer
  0xC425 Simon Y  0xC426/27 Simon X  0xC42C facing(0=R/1=L)  0xC428 jump phase
  0xC422 whip phase  0xC429 whip timer  0xC42E/2F anim frames (scratch)
  0xC450-C46F whip sprite buffer   0xC470/80 brazier objects (stride 0x10)
  0xC800 pickup/actor slot (0xC801 orb->item state, 0xC80C 0x14 timer)
  0xD000 room row  0xD001 room index (seg13 0xB98A)   level change = seg0 0x4362/65

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

# Progress

Running status of the disassembly. `docs/game-notes.md` holds the detailed
reverse-engineering findings; this file is the high-level checklist.

## End goal

The entire ROM should ultimately live in the repo as source: every byte is either
`.asm` or a data form that builds back into `.asm`/the ROM (e.g. our `gfx/` PNG+txt
-> RLE pipeline, the `vk()` text tables) - **no committed binaries in the final
state** (like Konamiman's Metal Gear disassembly, which has zero `incbin`). The
`segments/segNN.bin` + `INCBIN` in `VampireKiller.asm` are an interim "not yet
reversed" placeholder: each segment graduates incbin -> annotated disassembly (code)
or extracted data assets (graphics/tables) as it's understood, always keeping
`make verify` byte-exact. Postponed for now - we reverse segments incrementally
(seg0 done, seg1 largely done, seg2/seg3 now imported as disassembly and being
annotated; seg4-15 still INCBIN) rather than mass-converting bins to opaque `db`
dumps.

## Done

- Toolchain + build: `VampireKiller.asm` stitches 16 segments; `make verify`
  confirms the rebuilt ROM is byte-identical to the original.
- Segment 0 (resident bank) disassembled with MSX/MSX2 BIOS symbol names.
  Annotated: cartridge header, `init`, `int_handler` (H.TIMI), the dispatch
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
- Simon in-game sprites catalogued: `load_simon_sprites` (seg0 0x56E8) draws Simon
  as two stacked 16x16 cells, each animated independently - cell 0 = legs (seg13
  pointer table 0xA281, indexed by 0xC42E, 40 frames), cell 1 = torso+arm+whip
  (table 0xA2D1, 0xC42F, 36 frames). Tables bounded exactly (A281 ends where A2D1
  begins; A2D1 ends where stream data starts at 0xA319). Added to manifest as
  `simon_cell0` / `simon_cell1`; rendered previews confirm legs vs whip poses.
  Also fixed CRLF line endings on all tools/*.py (they broke direct `./tool`
  execution with `env: python3\r`).
- Segment 1 (banked code @ 0x6000) brought into the build as disassembled source
  (byte-exact), shared BIOS names moved to `segments/bios.inc`. Leading data map
  in `segments/seg01.blocks` (tables at 0x6000-0x602f, 0x605f-0x615a incl. a word
  table at 0x608d). Annotated so far:
  - `konami_logo_draw`/`konami_logo_step` (0x6209/0x6253): logo screen + the
    top-to-bottom wipe (confirmed by the author); `sub_6276h` tile-string interp.
  - Object-list loader cluster 0x615b-0x6208: `sub_615bh` unpacks the current
    cell's object list from seg 14 into the 4-byte-slot tables at 0xDB00/DC00/DD00
    (`sub_6188h` unpacker, `sub_61a5h` per-level pointer, `sub_61b0h` clear,
    `l61c2h` emits hardware sprites via seg0 0x5F26). RAM: 0xD000 = stage (0=court-
    yard, 1-18), 0xD001 = room within stage, 0xD002 = hub / seg14 object-dataset
    (6 hubs of 3 stages; row->hub table at seg0 0x5E71). See "Eighth session".
  - `lookup_word_tbl` (0x6549): generic word-table lookup (DE=table, A=index).
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
      handlers). Drives the cutscene script player, then bumps the progress /
      difficulty tier 0xD012 (incremented per level-advance, capped at 3) and
      resets VDP R23 (vertical offset) to 0.  0xD012 is read by enemy handlers to
      scale behaviour (e.g. actor_set_xvel_speedup adds 0xD012*32 to enemy speed).
      NOTE: VK does not scroll (room-based); 0xD012 is a speed/difficulty ramp.
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
    * On game start the intro handler calls reset_run_state (sub_44cdh, writer
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
    * RESOLVED (later): counters below 0xC420 - **score = 3-byte packed BCD at
      0xC405/0xC406/0xC407** (little-endian; 0xC406 = the hundreds/thousands pair =
      main visible byte; on-screen value strips leading zeros, e.g. 00 82 00 = 8200).
      Written by **add_score (seg0 0x44F5)** which adds C:D:E (hi:mid:lo BCD pairs)
      with daa; enemy kills route through seg2 award_kill_score (0x81B2, per-type
      value table l81d5h). Heart counter = 0xC417 (BCD, separate).
  - Sixth session (whip destructible wall -> grab white key -> whip candle -> grab
    small heart), via F8 snapshot timeline (baseline frame 357).  Pins the inventory
    that sat below 0xC420, plus the destructible-wall / pickup-actor mechanism:
    * **0xC417 = heart counter** - incremented 0x14 -> 0x15 exactly on the small-heart
      pickup (frame 501).  Confirmed BCD (seg0 0x834 already labelled it "packed BCD";
      the spend path seg1 sub_7166h/0x7176 does `sub 5 / daa`), so 0x15 = "15" hearts.
    * **0xC700-0xC70F = inventory / item block** (NOT a single flag).  0xC701 is an
      item *bitfield*: bit 0 = white key (0 -> 1 on the key pickup, frame 414); other
      bits are sub-weapons that cost hearts (seg1 l713dh shifts 0xC701 and does
      `call c,spend_5_hearts` on bit 3 / `call c,sub_7166h` on bit 6); bit 7 is a
      timed item (seg2 0x95C0-area counts 0xC70F down then `res 7,(0xC701)`).  The
      per-life reset sub_70e3h (seg1 0x70E3) keeps only bit 7 (`and 0x80`), so the
      white key etc. are lost on death but the bit-7 item persists.  Other bytes seen:
      0xC704 = vendor item, 0xC706 = vendor timer, 0xC707 = price, 0xC708 = item id
      (seg2 0x94C0 vendor-purchase compares 0xC417 hearts >= 0xC707 price).
      CORRECTION: earlier in this note 0xC701 was called a "white-key held flag" -
      it's the item bitfield; white key is specifically bit 0.
    * **Destructible scenery share the 0xC470 block** (stride 0x10, +0 = state
      2=present/0=gone) with braziers/candles: the WALL slot was 0xC490 (destroyed
      frame 390), the CANDLE slot 0xC4C0 (destroyed frame 459, its +6 flame phase at
      0xC4C6 free-running every frame).  So walls, braziers and candles are all the
      same "destructible object" type, differing only by contents/graphics.
    * **Pickup-item actor block at 0xC520** (separate from the 0xC800 actors): when the
      wall broke (frame 390) a pickup actor spawned here (+0 type/frame byte = 0x84 for
      the white key); touching it cleared the slot (0x84 -> 0) and set 0xC701.  So a
      destroyed wall's bonus is emitted as a 0xC520 pickup actor.
    * 0xC419 = **last-collected-bonus id latch** (RESOLVED): `collect_bonus` (seg2
      0x8D33) writes A here as its first act; it's the bonus id (1 small heart, 0x18
      staff, etc.), used to pick the pickup HUD/message. Not a toggle - it just holds
      whatever was collected last.

- Seventh session (whip brazier -> small heart undulates + falls -> collect, x2), via
  F8 snapshot timeline (fresh file). Nails the small-heart drop lifecycle AND the
  shared bonus-collect dispatcher, all statically corroborated:
    * **Heart drop actor chain** (all in the 0xC800 actor list, stride 0x80):
      type 0x1E (initial spawn, seg2 sub_9a5fh `ld c,01eh`) -> type **0x24** (the
      undulating faller) -> on landing, freed and re-emitted as a **0x84 settled
      pickup** in the 0xC500 pickup list (8 slots, stride 0x20) -> Simon touches it
      -> collected. (Runtime seq per cycle: 0x1E@f45 -> 0x24@f57 -> land/0x84@f82 ->
      pickup@f103; cycle 2 identical at f150/162/187/209.)
    * **Falling-heart (0x24) physics** decoded from the slot: +3 = Y integer (rises
      steadily = constant-speed fall), +5 = X integer which swings out then back
      (the side-to-side undulation), driven by a signed X-velocity at +9/+0xA that
      ramps down through zero, plus a phase counter at +0xC. So the "undulation" is
      a decaying/reversing horizontal velocity, not a sine LUT position.
    * **collect_bonus (seg2 0x8D33)** = the shared "apply bonus id A" routine: latches
      A -> 0xC419, then `DISPATCH_A` through a 25-entry word table at 0x8D45 (index
      A-1). Confirmed entries: **value 1 = small heart (+1)**, **value 2 = large
      heart (+5)** (both `call add_hearts` with B=1/5), health refills via
      restore_health (+8/+32), keys/sub-weapons OR a bit into 0xC701/0xC702.
      Reached from BOTH pickup paths: the mid-air 0x24 heart (seg2 sub_9a72h ->
      collect_bonus(1)) and the settled 0xC500 list (collision -> collect).
    * **add_hearts (seg0 0x459B)** / **spend_hearts (0x45A7)** now labelled: BCD add
      (clamp 99) / subtract (floor 0) on 0xC417; heart counter confirmed BCD again
      (small +1 gave 00->01->02, no binary carry weirdness).
    * NEXT: decode the rest of the collect_bonus table (values 3-25: which are keys,
      staff, sub-weapons, invincibility) and the 0x24->0x84 landing/convert routine.

- Eighth session (LOCATION / WORLD STRUCTURE - walk right through courtyard rooms
  0,1,2 then enter the castle), F8 timeline (baseline frame 275). Pins the
  hub/stage/room hierarchy so recordings can be tagged by location and we never
  conflate enemy/object positions between rooms. **KEY CORRECTION vs first pass:**
  the trio is a hub/stage/room hierarchy, NOT a raw pixel row/column:
    * **0xD002 = HUB** (object-data set), 6 hubs (0-5). Chosen from the stage via the
      seg0 row->dataset table at 0x5E71 = `0 0 0 0 |1 1 1|2 2 2|3 3 3|4 4 4|5 5 5`
      for stages 0..18 - i.e. stages are grouped in 3s per hub (matches "a hub has
      ~3 stages"). Each hub's packed object data is in seg14 (pointer table @ 0x8668).
    * **0xD000 = STAGE** number: 0 = courtyard, 1..18 = the 18 stages (3 per hub).
      Changed once during the walk (0->1) exactly at the courtyard->castle boundary
      (frame 585). Stage 0 (courtyard) carries NO object-list entries: the sprite
      emitter l61c2h does `dec a; ret m` on stage 0, so it draws nothing (consistent
      with "no animals in the courtyard").
    * **0xD001 = ROOM** index within the stage (walk right): stepped 0 ->1 (f377) ->2
      (f474) through the three courtyard rooms, then reset to 0 on entering the castle.
    * **0xC411 = stage/area label** (HUD "STAGE" value): 0 courtyard -> 1 castle at
      f585. Clamp range differs from D000 (C411 < 0x19, D000 < 0x13) so it is a
      separate counter, not identical to the stage number - exact relation TBD.
    * Data path (static): seg1 `sub_615bh` unpacks hub D002's data into 0xDB00/DC00/
      DD00 (3 streams = the hub's 3 stages); `sub_6188h` grammar = (id,attr) pairs,
      0x00 = next room cell (0x10 apart), 0xFF = end. Per object: id bit7 = scenery,
      low7 = sprite id; attr hi nibble = X cell, lo nibble = Y cell (x/y * 16 px).
      Reader `l61c2h`: stageStream = (D000-1) - D002*3; room = D001.
    * **Room/object map extracted for ALL 18 stages** -> `tools/roommap.py` (decodes
      seg14 + the row table, renders `gfx/map_*.png` + a per-room object breakdown).
      `--datasets all` = whole world (each row = a stage, each cell = a room, dots =
      objects); `--datasets N` = one hub. This is the OBJECT-LAYOUT layer only (not
      wall/floor artwork, which is separate per-room RLE bitmap data).
    * Transition frames this recording: f377 (room 0->1), f474 (room 1->2), f585
      (stage 0->1 = enter castle: C411 0->1, D000 0->1, D001 ->0).
    * WORKFLOW going forward: at the start of every recording, note (C411, D002 hub,
      D000 stage, D001 room) so each captured action is tagged with its location;
      re-check after any room/stage change before comparing actor/object slots.
    * NEXT to fully rebuild stages "with room relations": (1) disassemble seg13 (the
      room-transition brain, writer at 0xB98A - still INCBIN) for room bounds + exits
      (stairs/drops/key-doors); (2) map per-room background bitmaps for actual
      geometry; (3) name the object ids (0x0d/0x10 common scenery, 0x05 dog, ...).

- Ninth session (dog hits Simon -> knocked back across a room boundary), F8 timeline
  (frames ~628-732). Two useful results:
    * **Validates the object map**: Simon was in stage 1 (D000=1), room 3 (D001=3);
      roommap's decode of hub0/stage1 puts a dog (id 0x05) in room 3 (col 3) - exactly
      where the hit came from. So the seg14 object decode matches live play.
    * **Confirms horizontal room adjacency + transition trigger**: the dog hit (f664,
      health 0x1e->0x18) knocked Simon LEFT; his X counted down 0x30..0x08 then wrapped
      to 0xF6 (crossed the left screen edge, f681), and **D001 went 3 -> 2** - i.e.
      walking/knocked off the left edge enters room N-1 and re-enters at the right edge.
      So room links along a stage are D001 +/-1 via edge-crossing (D000 stage unchanged).
    * 0xC41B = candidate hit/knockback or transition-pending flag (0x03 during the
      knockback, cleared to 0 at the room transition, f682) - confirm next session.

- Tenth session (pick up chain whip; was leather). Pins the weapon system:
    * **0xC416 = equipped weapon id**: 0 = leather whip, 1 = chain whip (0xC416 flipped
      0 -> 1 on pickup, frame 78; 0xC419 latched bonus id 0x1A).
    * Weapon pickups: collect_bonus fallthrough l8d77h does `sub 0x19` -> 0xC416, so
      weapon id = bonus id - 0x19 (chain whip = bonus 0x1A).
    * Attack path split (seg1 ~0x7D80): weapon < 2 = whip (stays with Simon), >= 2 =
      projectile (knife/cross/axe). Damage tables (seg1 sub_7e33h): weapon 0 + 2 use
      base l7e60h, others use stronger 0x7E67. Full weapon-id map + damage values +
      the boomerang catch/lose logic still TBD. See game-notes "Equippable weapons".

- Eleventh session (stairs: climb up, whip a candle while on the stairway, climb
  back down and grab the heart). F8 recording, 1415 frames; only the LAST room is
  relevant - **stage 0xD000=1, room 0xD001=4, hub 0xD002=0** (idx 998..end). Pins
  Simon's action-state byte and the stair state:
    * **0xC420 = Simon action state** (dispatch `simon_action_tick` seg1 0x6B40, 8
      entries): now runtime-confirmed **3 = on stairs/climbing** (held ~159 frames
      idx 1110..1269 with diagonal Y 0x80<->0x4C), **4 = falling/drop off a ledge**
      (idx 1286, Y 0xB0->0xC2, no jump). Corrects the earlier guess "3=whip":
      whipping does NOT change 0xC420 - Simon whipped the candle at idx 1177 while
      still in state 3 (the destruction flame 0x1E appeared then). (NOTE: jump = state
      1, NOT 5 - see Twelfth session; the state-5 blip at idx 1074 was a hurt/other,
      not the plain jump.)
    * **Whip-on-stairs -> heart** seen in actor slot 0xC800: **0x1E** destruction
      flame at the whip (+0x0C counts 0x10->0, idx 1177..1189), then a **0x26**
      reward-spawn actor with **+0x0E = 0x02** (= the bonus id that later collected),
      which settles into the pickup list as an **0x84** entry. (Slot type 0x04 cycles
      through this slot too but its role here is unconfirmed.) Collected at idx 1295
      from **0xC530** (pickup entries are stride 0x10): 0xC417 hearts **0x25 -> 0x30
      (BCD, +5 = large heart)**, 0xC419 latched bonus id **0x02**, and the generic
      pickup popup fired (0xC5E5/0xC5E6 00 -> FF/0x1E) - consistent with the rosary
      session that 0xC5E5/6 is the per-pickup popup, not item-specific.
    * room_spawner's `0xC420 cp 006h` early-out now reads clearly: no enemy spawns
      while Simon is in state 6 (hurt / dying-respawn).

- Twelfth session (4 F8 recordings appended, one continuous stream to idx 2018;
  savestate reloads between them cause room/X discontinuities, so read each event
  locally): **yellow key pickup**, **chest open**, **crouch**, **jumps**.
    * **Yellow key** = bonus id **0x17 (23)**. Picked up from the 0xC500 pickup list
      (an 0x84 entry -> 0x00); sets inventory **0xC701 bit 1** (0xC701 0x01 -> 0x03,
      bit 0 was the earlier white key) and **0xC700 0x00 -> 0x01** (likely the yellow
      key / staff *charge count* - Simon carries 1 key, a staff would be 3). Confirmed
      at idx 1478 and 1587.
    * **Chest open** (use key) at idx ~1662: consumes the key - **0xC701 0x03 -> 0x01**
      (bit 1 cleared) and **0xC700 0x01 -> 0x00**. The chest's reward latched earlier
      as bonus id **0x13 (19)** (idx 1625) and populated a destructible/object slot
      (0xC490 block) + a 0xC500 pickup entry. Exact chest-object handler still TBD.
    * **Crouch** (DOWN) = action state **0xC420 = 2** (handler 0x6DB0). Held the whole
      time DOWN was pressed; **Simon X (0xC427) stayed locked at 0xCE** - confirms "can
      not move while crouching".
    * **Jump** = action state **0xC420 = 1** (handler 0x6CC7), NOT 5. Three jumps: up
      (X fixed at 0xCE, Y arc 0xC0->0xA0->0xC0 over ~15 frames), right (Xlo 0xCE->0xF6
      during the arc), left (Xlo 0xF4->0xCE). This corrects the Eleventh-session note.
      0xC423 tracks the air sub-phase during the arc.

- Thirteenth session (**stage 1, room 7**, idx 2019..2190): whip candle -> large
  heart; whip another candle -> nothing; dog approaches, Simon jumps over it, dog
  flees left off-screen.
    * **Score (0xC405-0xC407) unchanged the whole take (00 82 00)** - confirms large
      heart = **+0 points**, empty candle = 0, and the fled dog = 0 (not killed).
    * **Large heart** = bonus id **0x02**, **0xC417 hearts 0x15 -> 0x20 (BCD, +5)** at
      idx 2069; spawned via the 0x26 reward actor in slot 0xC880 (idx 2035..2052).
    * **Dog** = actor slot 0xC800 type **0x05** (`enemy_dog_tick`). Timeline: Simon
      approaches from the left (X 0x51->0x83); dog runs toward him (dogX +0x05
      0xC0->0x74), oscillates, then after Simon's jump (state 1, idx ~2126..2141) it
      reverses and runs left off-screen (dogX 0x84->0x30, slot freed idx 2158). No
      score (never killed) - consistent with the flee-right/left AI keyed on Simon's
      relative X.
    * Decoded the per-type score table **l81d5h** (seg2) and annotated it inline:
      zombie(t01)=100, dog(t05)=100, candle/destructible(t04)=100, up to bosses
      (t0e=1000, t12-14=2000, t11=+30000, t17=+50000).

- Damage model annotated (byte-exact) - Simon HP = 0xC415 (max 0x20), enemy/boss
  energy = 0xC418 (max 0x80):
    * **Simon takes damage** via damage_health (0x4632): `hurt_simon_contact`
      (seg2 0x8173) = 2x the *odd* byte of l81d5h[type] (zombie 2, dog 6; shield
      0xC701 bit4 halves + spends 0xC441 charge); `hurt_simon_projectile` (seg2
      0x85AD) = fixed 8 or 16 from a 0xC580 hazard slot, and sets hurt state
      0xC420=5.  l81d5h's odd byte is the per-type contact-damage field (its even
      byte is the kill score).
    * **Simon deals damage** via `weapon_hit_damage` (seg1 0x7E33) -> `damage_enemy`
      (0x4643, 0xC418 -= B).  Per-weapon table by (type-0x11): leather/knife =
      04 08 08 04 04 04 10; chain/cross/axe = 06 0C 0C 06 06 06 18; type 0x17 with
      weapon>=2 is quartered.  Lesser enemies (type<0x11) die on the first hit.
    * Names in segments/msx.sym: damage_enemy, hurt_simon_contact,
      hurt_simon_projectile, weapon_hit_damage.

- Fourteenth session (2 recordings appended to idx 2762): (1) dog hits Simon,
  (2) reveal a wall vendor, whip him repeatedly, refuse a 50-heart knife offer,
  keep whipping until he gives two +5 hearts and leaves.
    * **Dog contact damage = 6 confirmed**: 0xC415 0x20 -> 0x1A at idx 2200
      (matches l81d5h dog odd-byte 3 x2 = 6).
    * **Vendor fully mapped (seg2 0x92AE-0x9552).** Not a 0xC800 actor - lives in
      the special-object list at 0xC5B5; transaction state in the 0xC700 block:
      0xC706 offer timer, 0xC707 price (BCD), 0xC708 offered item (0x1B = knife),
      0xC702 bible flags, 0xC70C whip-outcome state, 0xD012 mood tier (0..3).
    * **Whip-outcome state machine**: each hit runs `vendor_pick_outcome` (0x92C2)
      - a transition table (0x9307, rows per vendor variant) plus the **R refresh
      register as RNG** for the branchy states (>=7); result 0xC70C executed by
      `vendor_outcome_dispatch` (0x92AE). Outcomes 0..6 = register-hit / mood++ /
      mood-- / **+5 hearts** (sfx 0x0F) / **-5 hearts** (sfx 0x1D) / **nothing**
      (bare ret) / **leave**. This is the full spectrum the player observes; the
      RNG is why timing/results vary run to run.
    * **Score**: only the **leave** path adds score - **+5000** via
      `ld de,0x5000 / jp 0x44F3` (add_score). Confirmed by 0xC405-07 00 00 00 ->
      00 50 00 at idx 2722, right after the vendor left (0xC70C=6 at idx 2697).
      Individual whips add 0 (a "did nothing" whip = outcome 5).
    * **Offer** armed by `vendor_make_offer` (0x938E): sets item/price and the
      0xC706 timer (=0x14). Empirically the first offer fired at reveal (idx 2331:
      0xC706=0x14, 0xC707=0x50, 0xC708=0x1B). [RESOLVED later via tools/romscan.py:
      the caller is the **resident** vendor state machine at seg0 l4411h
      (`call 0938eh`), which a `segments/*.bin` grep missed because seg0 has no bin.
      seg0 also calls 0x94C1 (vendor_purchase_tick body) and 0x950E (offer dismiss).]
    * **Price** = `vendor_price_tbl` (0x942F), 9 rows of {id, normal, half, double};
      `vendor_select_price` (0x941F) uses 0xC702 bit7 (white bible = halve) / bit6
      (black bible = double). Knife = 50 / 30 / 90 -> the "50 hearts" offer is the
      normal price (neither bible active, as the player noted).
    * **Buy/refuse**: `vendor_purchase_tick` (0x94BE) ticks 0xC706 and polls
      `vendor_read_buttons` (0x9526): joystick triggers + **SPACE (kbd row 8) =
      confirm**, **SHIFT (row 6) = refuse**, edge-detected via 0xC709. Confirm +
      hearts>=price -> spend_hearts + collect_bonus(item), sfx 0x12; refuse /
      unaffordable / timer-expiry -> withdraw, sfx 0x02.
    * Names in segments/msx.sym: vendor_outcome_dispatch, vendor_pick_outcome,
      vendor_make_offer, vendor_set_offer_item, vendor_select_price,
      vendor_price_tbl, vendor_purchase_tick, vendor_read_buttons.

- Fifteenth session (1 recording, idx 2846): pick up the **black bible**.
    * **Black bible = bonus id 0x10** (0xC419=0x10). Sets **0xC702 bit6** (0x00 ->
      0x40) -> vendor prices doubled. Confirms the price-modifier analysis.
    * collect_bonus dispatches `dec a` then DISPATCH_A, so id N uses table[N-1]
      (table base 0x8D45 = id 0x01). Black-bible handler = 0x8E24 (res bit7, set
      bit6); **white bible = id 0x11**, handler 0x8E2D (res bit6, set bit7 -> half
      price). The two bits are mutually exclusive (each handler clears the other).
      Both end at 0x8E34 -> popup message id 0x12.

- Sixteenth session (1 recording, idx 2890..3167): whip candle + grab heart, whip
  dog, open a white-key door -> **enter STAGE 2**.
    * **White-key door** (seg0 0x438B): clears **0xC701 bit0** (`and 0feh`) to spend
      the white key, then `jp advance_stage`. Confirmed: 0xC701 0x03 -> 0x02 at idx
      3072 (bit0 dropped), stage 0xD000 01 -> 02 at idx 3137.
    * **advance_stage** (seg0 0x434E, renamed from l434eh): 0xD000 (stage) ++,
      0xD001 (room) = 0, bump BCD counters 0xC410/0xC411, transition type 4.
    * Pickups this take reconfirm earlier IDs: **yellow key** = bonus 0x17 (0xC419
      0x17 @ idx 2971, sets 0xC701 bit1 + 0xC700=1); **large heart** = bonus 0x02
      (0xC417 0x35 -> 0x40, +5, @ idx 3023). Score +100 @ idx 2979 (candle
      destructible; boss energy 0xC418 untouched = one-hit kill, not a boss).

- Seventeenth session (ROOM GEOMETRY / MAP DATA - room-to-room transition
  recordings, idx up to 3167): found where rooms are stored and cracked the layout.
    * **Tile map = 0xD100** (32x24 tile-name bytes; rows 0-1 HUD). Found via a
      cross-room RAM page-diff (0xD100..0xD3FF changes wholesale per room), then
      confirmed by the collision reader `map_cell_at` (seg1 0x7d36, renamed) which
      indexes `0xD100 + ((Y-0x10)>>3)*32 + (X>>3)` (clamped to 0xD3FF) and the
      drawer seg0 0x4f98 (paints from 0xD140).
    * **Build = seg0 room_map_build** (0x4fb6, renamed from l4fb6h): a room is an
      **8x6 grid of metatiles**, each metatile a **4x4 tile block (16 bytes)**.
      Data banks (paged in during the build): rowbase[] byte table @ bank 0x0b
      0x6000 (index = rowbase[row]+col; rooms/row = rowbase[row+1]-rowbase[row]);
      room stream ptr = word @ 0x6013+2*index -> a 48-byte metatile-id stream (stage
      1 streams at 0x620b, stride 0x30); per-row metatile-def table @ 0x7ebb (stage
      1 -> 0x80b1 in bank 0x0c). NOTE `entity_tbl_end` is a misnomer - it is the
      Konami mapper register at 0x6000 (seg0 ends exactly there).
    * **Tile classes.** Walls/floors = the structural brick family **0x01..0x0d**
      (01..04 solid surface + 05..0d brick body, in a repeating (surface,body)
      metatile - so a wall column reads 01/09/01/09... top to bottom). Passable:
      air 0x0e..0x17, stairs (paired 06/0c and mirror 07/0d, drawn amber), and
      decorative blocks **0x2c+** (background
      windows/columns/curtains). User confirmed: room 0 has no walls (only a
      floor); room 4's left wall is solid top-to-bottom (classifying only the
      surface gave horizontal stripes - fixed by filling the whole 01..0d family).
    * **Engine collision** is stricter: `tile_is_solid` (seg1 0x7c65, renamed from
      l7c65h) blocks only when `(id-1) < row_solid_thresh[0xD000]` (byte table
      0x7c7f, renamed; stage 1 -> 4) = the 01..04 surfaces; the brick body needn't
      be solid since Simon can't enter a wall.
    * **Tool: `tools/roomperm.py`** decodes any world row straight from ROM and
      renders black/white permeability (`gfx/perm_s1_*.png` + contact sheet);
      `--collision` = strict surface view, `--visual` = + 0x2c+ scenery.
      `--validate` byte-checks the ROM decode against the 0xD100 RAM snapshots:
      **0 mismatches** across all 7 recorded stage-1 rooms; room 3 (never visited)
      now decodes from ROM too.
    * Renamed labels this session (seg0/seg1, all in-source + msx.sym):
      room_map_build, map_cell_at, tile_is_solid, row_solid_thresh. `make verify`
      still byte-identical.

- Eighteenth session (ENEMY GENERATORS + all-stage map rendering):
    * **Continuous enemy spawner cracked.** `room_spawner` (seg0 0x5EBF) indexes
      seg14 word table **0x85A6** by stage (0xD000), then the resulting byte table
      by room (0xD001) to fetch a per-room **spawn bitmask** (stage 1 bytes at
      **0x85CF**). Each set bit (LSB first) fires one rate-gated generator in seg2:
      bit0 `zombie_generator` 0x9CED -> type 01 (zombie); bit1 0x9D52 -> type 02;
      bit2 0x9D59 -> type 03; bit3 0x9D9E -> type 04 (bat: vertical undulation, one
      horizontal way); bits 4-6 0x9DCA/0x9DDC/0x9DEE (types unconfirmed). Stage 1
      confirmed: rooms 0/1/5/6 spawn zombies, room 4 spawns bats.
    * Each generator is rate-gated by `sub_9ccah` (per-generator 0xCF00+ counter vs
      a threshold table scaled by 0xD012 difficulty). **Spawn position is hardcoded
      per stage/room** in `sub_9d03h` (annotated) - NOT read from the tile map
      (stage-1 room-0 zombies enter at X=0xC0). Renamed `zombie_generator`
      (seg0 call site + msx.sym); `make verify` byte-identical.
    * **The 08/05 "artifacts" are inert background art, NOT generators.** Ruled out
      by: spawning is bitmask-driven, positions are hardcoded and don't line up with
      the 08/05 cells, and rooms spawn regardless of the pair's presence. Their
      actual picture is still unidentified - tile PATTERNS live in a VRAM page the
      game RLE-decodes from ROM per room (not captured by RAM snapshots), and the
      background tileset isn't in the gfx catalogue yet (only sprites are). Decoding
      the per-room tileset loader (seg0 l471bh/l4845h path) is the open next step.
    * **`roomperm.py` upgrades:** room-number labels drawn in a widened dark-gray
      band per cell (3x5 bitmap font); stopped writing per-room PNGs (one contact
      sheet per stage only); **`--all`** renders every stage - world rows **0..17**
      (the last rowbase entry, 146, is an end sentinel). Fixed a cross-bank read:
      metatile-def tables can straddle the seg12/seg13 (0x8000/0xA000) boundary, so
      the decoder now treats banks 0x0b/0x0c/0x0d as one flat 0x6000-0xBFFF buffer.
      Stage 1 still validates **0 mismatches**; stages 2-17 render but are not yet
      snapshot-validated (need transition recordings in those stages to confirm).
    * Room-index vs spatial layout: the geometry data stores **no (x,y) per room** -
      just a linear per-stage list (rowbase/roomptr). The contact sheet matching the
      real layout is because rooms were authored in physical reading order (so L/R
      neighbours are consecutive indices) AND the 4-column sheet happens to equal
      stage 1's physical width (T/B alignment is lucky, not guaranteed per stage).

- Tooling: added `tools/romscan.py` (static xref + dispatch-table decoder) to
  automate the two look-ups we do every session. `xref` splits real control
  transfers (`code`) from bare word matches (`data?`); `table` decodes jump/handler
  tables (with `--index-base 1` for `dec a` dispatchers). It reads each bank
  straight from the ROM, so it sees **seg0** (which has no committed `.bin`). First
  use immediately found the resident caller of `vendor_make_offer` (seg0 l4411h) that
  a `segments/*.bin` grep had missed. Recipes folded into the two skills.
- Segments 2 & 3 imported as disassembled source (byte-exact): both graduated
  from INCBIN to INCLUDE (org 0x8000 / 0xA000, pages 2a / 2b).  Raw disassembly
  folded into `segments/seg02.asm` / `seg03.asm` (equ block + z80dasm header
  stripped; `bios.inc` gained the missing `RIGHTC` 0x00FC).  Tooling fix:
  `strip-listing.py` now also cleans z80dasm's `;illegal sequence` defb lines
  (the code group is `.*?` so it spans that earlier comment).  First annotations
  in seg3 (confirmed via the enemy traces + entity_tbl):
  - `enemy_zombie_tick` (seg3 0xA93B, entity type 1): spawn/init path - marks the
    slot alive (+0x06=1), reads zombie X (+0x05), and picks walk direction from
    which half of the screen it's on (vel +0x0220 right / 0xFDE0 left, anim
    0x3d/0x3b, facing +0x10).  Confirms zombie logical X = +0x05.
  - `enemy_dog_tick` (seg3 0xA863, entity type 5): compares dog pos (+0x05) to
    Simon X (0xC427) to choose idle frame 0x43 (far) / 0x3f (near); stores anim
    (+0x0B), alive (+0x06), clears timer (+0x0C).  This is the flee-right dog.
  Both names added to `segments/msx.sym`; seg0 `entity_tbl[0]`/`[4]` now reference
  the labels (byte-exact).  NOTE the earlier dog/zombie X-offset puzzle: the code
  uses +0x05 as the AI/compare X for BOTH; runtime showed +0x03 moving for the dog
  - still worth a c800-c80f watch to see how +0x03 vs +0x05 relate during the flee.

- Seg2/seg3 annotation batch (all byte-exact, `make verify` clean).  Confirmed the
  candle -> flame -> heart chain AND the core actor slot layout straight from code:
  - Actor slot fields (nailed via the seg2 integrator `actor_integrate` 0x99C0):
    `+0x02/+0x03` = Y pos (frac/pixel), `+0x04/+0x05` = X pos (frac/pixel),
    `+0x06` = alive flag, `+0x07/+0x08` = Y velocity, `+0x09/+0x0A` = X velocity.
    (`+0x05`=X reconfirmed: `enemy_dog_tick` compares `+0x05` to Simon X 0xC427.)
  - Braziers/candles (seg2): `brazier_tick_all` (0x8678, loop over 8 slots @ 0xC470
    stride 0x10, called each frame from seg0/seg1) -> `brazier_tick` (0x8693, advances
    flame phase `+0x06`, hit test on `+0x03`) -> `brazier_destroyed` (0x87C1, clears
    the slot and runs the item drop; `+0x04` = drop selector, `+0x05` = param).
  - Destruction flame (seg2): `flame_init` (0x9B67, sprite 0x85 + lifetime 0x10) and
    `flame_tick` (0x9B78) - flickers 0x85<->0x86 on bit 2 of the countdown, then on
    expiry, if the drop gate `+0x1F` is set, `jp spawn_actor` with type 0x24 at its
    spot.  This is the runtime-observed candle -> flame(0x85/86) -> heart(0x24) chain;
    0x85/0x86 = the flame sprite, 0x24 = the settled small heart.
  - Physics core (seg2): `actor_integrate` (0x99C0), `actor_cull_offscreen` (0x99EC,
    frees when pixel pos leaves the field), `actor_free` (0x99FD).
  - Velocity helpers (seg3): `actor_set_yvel` (0xA564) / `actor_set_xvel` (0xA573)
    store DE; `actor_add_yvel` (0xA550) adds with a [0,0x7FF] clamp (gravity/terminal
    fall); `actor_add_xvel` (0xA56B); `actor_set_xvel_speedup` (0xA65A) sets X
    velocity plus a progress speed bias (0xD012 tier * 32, in the travel
    direction) so enemies get faster as the game advances - NOT scrolling (VK is
    room-based and does not scroll).
  All names in `segments/msx.sym`; cross-segment `call 0aXXXh` sites in seg0/1/2 now use
  the labels.  (Audit correction: the "0xB473 sprite-shape table" note was wrong -
  0xB473 is code, a `jr` target inside an actor routine, not data.)
  Tooling: fixed CRLF line endings in `tools/split-rom.sh` (it wouldn't run, which is
  what had left seg02-04.bin missing); it now regenerates seg01-15.bin cleanly.

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
6. Room-map renderer (`tools/roomperm.py`) per-stage tile-semantics cleanup.
   Tile-name id meaning is PER-STAGE (each stage's tileset reuses ids), so the
   global classification (validated only on stage 1) misfires elsewhere. Settled
   so far:
   - **Stairs = climbable tiles 0x0c (one way) / 0x0d (mirror) ONLY** - this is
     what the engine's stair-step code tests (seg1 sub_7ce2h=0x0d, sub_7d0ch=0x0c).
     `06`/`07` are NOT stairs: they are decoration (stage 1 pairs each step with a
     06/07 half -> its unique 2-wide "fat" stairs; other stages draw 1-wide 0c/0d;
     stage 10 uses 06/07 as background wallpaper = the old "stair noise"). `06/07`
     reclassified as passable decoration (with the inert 05/08 pair) in roomperm.py.
   - **Residual per-stage errata to isolate** (user review of all 18 sheets):
     * stage 0 - RESOLVED / not a bug: room 2's gate embeds a few genuine 0c/0d
       stair tiles (same ids the engine climbs) as decoration; they're just
       inaccessible in the intro. Decision: leave them coloured as stairs (a stair
       tile is a stair tile whether or not it's reachable).
     * stage 6 room 5 - one errant 0c.
     * stage 15 rooms 6-9 - errant 0c/0d AND errant solid tiles.
     * stage 10 rooms 2/3/4/6/7/8 - "solid noise": isolated 01-04/09-0b tiles used
       as background render white (same per-stage problem, one layer down in the
       SOLID classification, not stairs).
     * stage 17 - RESOLVED by the 0c/0d-only rule: its false stairs were 06/07
       (10 each), now reclassified as decoration.
   - Likely next step: derive per-stage tile classes from the actual per-stage
     tileset/metatile semantics rather than global id ranges (or gate solids by the
     per-stage row_solid_thresh and stairs by structure+tileset group).

## Next tracing session (resume plan)

The setup works: `tools/build-cocoamsx.sh` then `tools/trace-run.sh` (software GL
is forced by default; Input Monitoring must be granted to the built .app once -
see the tracer notes below).  The tracer only logs bank switches unless EXEC
and/or WATCH ranges are given, and it reads them once at launch (change ranges =
relaunch = replay from the logo).

**State snapshots (F9).** New this session: press **F9** in the emulator to dump
the whole work-RAM window (default 0xC000-0xDFFF, set `SNAPRANGE`) to the
snapshot file (`generated/disasmsnap.bin`, set `SNAP`).  This works with EXEC and
WATCH both empty, so it needs no pre-chosen ranges and no replay-on-change - just
play, snap, keep playing.  The intended workflow is "snap before an action, snap
after", then diff offline:

  tools/snapdiff.py generated/disasmsnap.bin        # diff each consecutive pair
  tools/snapdiff.py -l generated/disasmsnap.bin     # list captured snapshots
  tools/snapdiff.py -a 0 -b 1 -r c400-c4ff ...      # pick snaps + restrict range

Output is "addr: old -> new" per changed byte, which reads directly against the
live RAM map below.  This is the fastest way to find *where* a counter/flag lives
(snap, do the thing once, snap) before committing a WATCH range to it - and it
catches the persistent inventory bytes below 0xC420 that the movement watches
kept missing.

**Habit: always diff the score on every recording.**  Score is 3-byte BCD at
**0xC405-0xC407** (main byte 0xC406, value x100).  Track it across the whole take
with `tools/snapdiff.py -t c405-c407` and note the delta for each pickup / kill /
hit - it's a reliable, quantitative fingerprint of what an action was "worth"
(e.g. chest = +5400, whipping a candle/object = +100, heart pickup = +0).  Points
are always multiples of 100, so watch 0xC406.

**Habit: annotate score increments in code whenever found.**  All awards go through
`add_score` (seg0 0x44F5); enemy/destructible kills come via `award_kill_score`
(seg2 0x81B2) using the per-type value table `l81d5h` (already decoded inline).
When a recording shows a score delta, tie it back to the responsible code path and
add/confirm the point value in the annotation (and here).  (Impl: F9 is caught in CMKeyboardManager's IOHID callback under
`#ifdef DISASMTRACE` and swallowed; disasmTraceRequestSnapshot() sets a flag that
R800's fetch loop honours at the next opcode via the CPU's own RAM reader.)

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
  0xC411 stage/area number (0=courtyard, 1=castle; set with 0xD000/0xC413 at
         seg0 0x2286)
  0xC415 HEALTH / energy bar (full 0x20=32; zombie hit = -2; draw seg0 l45d8h
         bar=HP*2, restore l460ch clamp 0x20, damage l4632h).  health 0 -> death.
         Part of player-stats block 0xC410-C417 (lives/stage/?/?/HP/weapon/hearts).
  0xC418 ENEMY/BOSS energy meter (full 0x80; draw seg0 l45ech, restore at 0x461f
         clamp 0x80) - structural twin of the 0xC415 health bar.
  Death -> respawn (captured across the fatal hit): 0xC420 action state = 6 is
         DEATH/dying (set when 0xC415 reaches 0).  On respawn: 0xC410 lives -1,
         0xC415 -> full 0x20, 0xC427 X -> room-entry 0x10, 0xC416 weapon -> 0
         (chain whip lost), 0xC417 hearts 0x12 -> 0x05 (death penalty / restore).
  0xC416 equipped weapon/whip ID (0=leather, 1=chain, ...; cp 2/4/5 in attack
         code; reset via xor a at seg1 ~0x7148)
  0xC417 HEARTS, packed BCD, cap 0x99 (draw: seg0 sub_456dh -> VRAM 0xC000;
         add:  seg0 0x4596 add a,b/daa/clamp99;  spend-5: seg1 sub_7154h
         sub 5/daa).  Confirmed +1 small heart, +5 large heart.
  0xC410 LIVES, packed BCD (drawn by seg0 sub_4575h -> VRAM 0xE400); held at
         0x02 for the whole courtyard run (no death/1-up)
  0xC425 Simon Y  0xC426/27 Simon X  0xC42C facing(0=R/1=L)  0xC428 jump phase
  0xC422 whip phase  0xC429 whip timer  0xC42E/2F anim frames (scratch)
  Damage/knockback (zombie-hit before/after + two during-blink captures):
    0xC42D INVULN/BLINK timer, starts 0x4e=78, -1 per frame (verified against
      0xC003: 35 frames elapsed = 35 counts); blink ends at 0.
    0xC420 action state ->5 (hurt), 0xC423 ->1 hurt/invuln flag, 0xC42C facing,
      0xC42E/2F hurt-anim frames - all cleared to 0 on recovery.
    0xC42A knockback velocity/impulse (0->0b->0d->0, NOT the timer).
    knockback throws Simon back (0xC427 X down) and up (0xC425 Y down, restored
      to 0xC0 ground on recovery).
  0xC450-C46F whip sprite buffer
  0xC470 block: destructible scenery objects (braziers/candles), stride 0x10, up
         to 4 per room (0xC470/80/90/A0).  +0x00 = state (0x02 = lit/present ->
         0x00 the frame the whip destroys it); +0x06 = free-running flame-anim
         phase (increments every frame).  Runtime-confirmed (castle candle room,
         F8 recording): whipping candle 0xC490 cleared 0xC490 02->00 on the whip-
         contact frame, candle 0xC470 likewise; unwhipped candles stayed 0x02.
         (Writer PC not yet captured - WATCH this block next run to name the
         candle-hit routine.)
  0xC800 actor slots: 7 slots, stride 0x80 (0xC800, 0xC880, ...); also used for
         the orb->item pickup.  Allocated/initialised by seg0 l5f24h (0x5F24):
         scans the 7 slots for slot+0==0, fills the struct, then DISPATCH_A's the
         per-type behaviour handler (entity_tbl at ~0x5F8F, indexed by type-1).
         entity_tbl targets are banked addresses in page 2b (seg3 during play).
         Runtime-mapped handlers so far: type 1 (walking zombie) = entity_tbl[0] =
         0xA93B (seg3); type 5 (dog) = entity_tbl[4] = 0xA863 (seg3).  Both confirmed
         by the anim/mover writer PCs clustering just past those addresses (03:a9xx,
         03:a87x).  Seg3 is still INCBIN - annotate these when it's disassembled.
         (Generic per-frame writers 02:99xx = sprite-attr composer, 03:a9xx = shared
         actor animator/mover; they operate on any slot via IX/IY, so writer PCs
         alone do NOT identify an enemy - the per-type handler comes from entity_tbl.)
         Runtime-confirmed fields (2-zombie whip capture, 86-frame F8 recording):
           +0x00 actor TYPE id: 0=free, 1=walking zombie, 0x1E=FLAME.
                 0x1E is the generic destruction FLAME: when most objects are
                 whipped and their health drops below 0 they turn into this flame
                 before disappearing (game-mechanic confirmed by the author).  A
                 whipped zombie is converted IN PLACE to type 0x1E (written by the
                 spawner at 00:5f89), burns as a stationary flicker, then frees to
                 0.  (So "kill" = despawn enemy + spawn the 0x1E flame in the slot.)
           +0x04/+0x05 = 16-bit X (sub-pixel lo / screen-X hi; +05 counts DOWN as
                 the zombie walks left, e9->3f, frozen once dying)
           +0x0B animation frame (walk 0x3B/0x3C <-> death 0x85/0x86)
           +0x0C state/anim timer (walk-anim phase while alive; 0x10->0 dissolve
                 countdown while type==0x1E, then slot frees)
           +0x06 / +0x0E alive sub-flags (init 1 / 7; both drop to 0 on death)
         Zombies are 1-hit kills: no HP decrement was observed - +0x00 goes
         straight 1 -> 0x1E on the whip's contact frame (whip phase 0xC422 -> 2).
         DOG enemy (type 0x05; a DIFFERENT room from the zombie captures - a castle
         "sitting dog" room with NO zombies, not the original zombie room).  F8
         recording: idle actor that sits at fixed X=0x80 cycling an idle anim (+0x0B
         frames 0x43/0x45/0x46) until Simon approaches within ~0x26 (38px: Simon
         0xC427 walked 0xdc->0xa6), then FLEES right, accelerating (+0x03 X-hi
         7e->7f->81->83->85->8d->91, i.e. ~1,2,2,2,8,4 px/frame) and DESPAWNS
         (+0x00 05->00) once off-screen.  NOTE the dog's X was observed at
         +0x02(sub/vel)/+0x03(hi), whereas the zombie's X was recorded at +0x04/+0x05.
         These are separate enemy types captured in separate rooms, so the offset may
         legitimately differ per type (not necessarily a mis-index) - verify with a
         side-by-side WATCH=c800-c80f on each before assuming a single shared layout.
         Candle -> FLAME -> SMALL-heart DROP lifecycle (runtime-confirmed in slot
         0xC880; do NOT conflate with the large heart): whipping a candle spawns an
         actor in a free 0xC800-block slot via spawn_actor (seg0 0x5F8A):
           +0x00 = 0x1E = FLAME (destruction effect, same type as enemy death): X/Y
                 hold STATIONARY for ~13 frames while +0x0B flickers 0x85<->0x86
                 (seg2 animator 0x9B8B) - a burning-in-place flicker, NOT motion.
           +0x00 = 0x24 = the SMALL HEART itself: now X/Y move (X-hi b1->b4, X-lo
                 swings e0/a0/40/20/60/80, Y toggles) = the side-to-side UNDULATING
                 fall the author described.  Freed to 0x00 when Simon touches it ->
                 0xC417 += 1.
         So the visible order is candle -> flame (0x1E) -> undulating small heart
         (0x24) -> pickup.  Contrast the LARGE heart (slot 0xC800): appears as an
         ORB, drops quickly to the floor, then turns into the large heart (older
         0xC801 orb->heart two-phase / 0xC80C 0x14-frame timer, +5 hearts).
         (0x1E vs 0x24 flame-vs-heart split is inferred from the motion profile;
         WATCH=c880-c88f on a candle whip will confirm and give the handler PCs.)
  0xD000 stage row/flag  0xD001 room index (seg13 0xB98A)  level change = seg0
         0x4362/65

Snapshot session (F9 x7: baseline -> 5 braziers -> castle) nailed the inventory
block that every prior movement WATCH missed.  Method note: the F9 RAM-diff alone
identified 0xC417/0xC416/0xC411 (no EXEC/WATCH needed); static xref then found the
routines.  The `daa` after add/sub on 0xC417 is the proof it's BCD.

Candle/small-heart session (F8 recording, 176 frames, WATCH=c800-c8ff): whipped
two castle candles, each dropped a SMALL heart.  Pinned (a) the destructible-
scenery block at 0xC470 (+0x00 state, +0x06 flame anim; candles 0xC490 and 0xC470
cleared on whip-contact) and (b) the destroy->drop lifecycle: type 0x1E = FLAME
(stationary flicker 0x85<->0x86, the "objects turn into a flame when whipped"
effect) -> 0x24 = the small heart (undulates side-to-side as it falls) -> pickup
(+1 heart), reconfirming 0xC417 as BCD hearts (12->13->14).  (Large hearts differ:
orb -> quick drop -> large heart; not captured here.)
Next: rerun WATCH=c470-c4bf to capture the candle-hit writer PC and name the
routine; a WATCH on the pickup slot's +0x00 to get the 0x1E->0x24->free handler PCs.

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
- Data regions go in a `.blocks` file (see `segments/seg00.blocks`, `segments/seg01.blocks`);
  a `.blocks` file only changes code-vs-data rendering, never the emitted bytes.
  BIOS names live once in `segments/bios.inc`; routine names go in `segments/msx.sym`.
- File placement (STANDING PRACTICE): all hand-authored disassembly metadata lives
  in `segments/` (`bios.inc`, `msx.sym`, `seg*.blocks`) - anything needed to
  reassemble or to regenerate the disassembly faithfully. `tools/` is executable
  tooling only; `generated/` is gitignored derived scratch (never author there).
  How they're consumed: `bios.inc` is `INCLUDE`d by the build (symbol equates, not
  emitted); `msx.sym` (z80dasm `-S`) and `seg*.blocks` (z80dasm `-b`) are read only
  by `regen-seg.sh`. `bios.inc` and `msx.sym` overlap - keep them in sync.
- Naming (STANDING PRACTICE): as soon as we have enough context to be confident of
  a routine's (or label's) purpose, rename it - proactively, without being asked.
  Do NOT rename speculatively: keep the `z80dasm` name until the purpose is actually
  established (don't jump the gun on a guessed purpose).  Same rule applies to named
  RAM/data addresses where the role is confirmed.
  - When confident, the rename means renaming the actual in-source label in
    `segments/*.asm` (definition + every reference) - NOT merely adding the name to
    `segments/msx.sym` or writing it in a comment.  Adding a `msx.sym` entry / comment
    while leaving `sub_XXXXh`/`lXXXXh` in the source is the incomplete half; do both.
  - If the purpose is only partially understood, leave the auto-label and just add a
    comment describing what is known - a comment is the right home for a hypothesis,
    a name is a claim of confidence.
- Casing: `UPPER_SNAKE` is reserved for external/hardware and macro-like helpers
  only - MSX BIOS entry points and the pseudo-instruction helpers that read like
  opcodes (`ADD_HL_A`, `ADD_DE_A`, `DISPATCH_A`).  Everything that is our own game
  code/data uses `lower_snake` (e.g. `init`, `int_handler`, `konami_logo_draw`,
  `reset_run_state`, `draw_hearts_hud`, `simon_action_tick`).
- Renaming mechanics: rename its `z80dasm` label
  (`sub_XXXXh`/`lXXXXh`) to a descriptive `snake_case` name.  Labels are symbolic,
  so renaming (definition + every reference, all in the disassembled `.asm` files -
  the `incbin` segments only reference code by embedded address bytes) never changes
  the emitted ROM; `make verify` catches any inconsistency.  Keep the original ROM
  address in the block-header comment (e.g. `(seg0 0x5F24)`) so names still line up
  with WATCH-log PCs, and add the same name to `segments/msx.sym` so regen emits it.
  Renamed so far - seg0: draw_hearts_hud/draw_lives_hud/draw_health_bar/
  draw_enemy_meter/restore_health/damage_health/spawn_actor(+_init),
  advance_stage, room_map_build, zombie_generator;
  seg1: simon_action_tick, spend_5_hearts, map_cell_at, tile_is_solid,
  row_solid_thresh.
- Every `vk()`-emitting Lua block MUST use `LUA ALLPASS` — plain `LUA` emits only
  on the final pass and drifts all later labels.
- After any edit, run `make verify` before moving on.
- Reusable methodology (for disassembling OTHER Konami MSX games later) lives in
  workspace skills at `.agents/skills/` (`konami-msx-disasm`, `msx-runtime-tracing`).
  When we discover a generally-useful pattern/tool/gotcha, fold it into those skills
  (keep them lean - they load every session) and keep VK-specific findings here.

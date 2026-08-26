# Progress

Running status of the disassembly. `docs/game-notes.md` holds the detailed
reverse-engineering findings; this file is the high-level checklist.

## End goal

The entire ROM should ultimately live in the repo as source: every byte is either
`.asm` or a data form that builds back into `.asm`/the ROM (e.g. our `gfx/` PNG+txt
-> RLE pipeline, the `vk`/`cr` text macros) - **no committed binaries in the final
state** (like Konamiman's Metal Gear disassembly, which has zero `incbin`).
VK has no remaining `INCBIN`: every bank is `INCLUDE`'d source (code banks 0-3
and 11-14 still being annotated; data banks 4-10 and 15 are labeled dumps).
Seg14 is scenery / object-list / spawn-mask / `font_credits.asm` / PSG-driver source
(packed streams labeled hex); tileset banks 4-8 and metatile streams/defs are
labeled `.asm` (`tileset_s00`..`s18`, `mtile_stream_sNN_rNN`); Simon/intro sprite
RLE is labeled packed streams (`intro_simon_0`..`7`, `simon_rle_xxxx`, `intro_sky`).
Segs 9-10 are labeled gfx-script / palette / enemy+weapon RLE. Seg15 is labeled
music tails / env tables / Dracula portrait (`psg_seg15.asm`, `dracula_portrait.asm`).
Fully migrated banks (0-15) have no `.bin`.

## Done

- Toolchain + build: `VampireKiller.asm` stitches 16 segments; `make verify`
  confirms the rebuilt ROM is byte-identical to the original.
- Segment 0 (resident bank) disassembled with MSX/MSX2 BIOS symbol names.
  Annotated: cartridge header, `init`, `int_handler` (H.TIMI), the dispatch
  helpers (`ADD_HL_A`, `ADD_DE_A`, `DISPATCH_A`), the main tick `main_tick`
  (two-level state machine + `main_state_tbl`), the front-end transition
  `frontend_input` (0x4398), and the entity dispatch/`entity_tbl` at `0x5FD0`.
- Text: encoding cracked (`ASCII - 0x10` for HUD/title via the `vk` macro). Ending
  credits store letters as ASCII but space as `0x00` (`cr` macro); story + staff
  live in `segments/credits_ending.asm` / `credits_staff.asm`.
- Reference: Metal Gear disassembly used to confirm the text scheme and the
  Konami actor/OBJ struct (cloned locally to `references/`, not committed).
- Graphics: identified video mode as **SCREEN 5** (4bpp bitmap) in `video_init`;
  classified the banks (code = seg 0-3, graphics = seg 4-15). Added
  `tools/gfxview.py` (1bpp/4bpp ASCII-art viewer).
- PSG catalogue: `make music` / `make sfx` (`tools/psgplay.py`) render BGM and
  sfx ids 1–0x1D to `music/` and `sfx/` (`{id}_{name}.wav`). Stream labels in
  `data/psg_streams.asm` / `psg_seg15.asm` use those stems (`sfx_*`,
  `music_*_{a,b,c}`); 0x89 is Simon death, 0x8B is GAME OVER.
- Graphics format **cracked**: RLE decompressor `rle_dec`/`rle_dec_addr` (grammar:
  end / set-addr / run / literal) unpacks all bitmaps + sprite patterns to VRAM.
  Bank switchers `page_map_banks`/`page_title_banks`/`page_play_banks` decoded. Added
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
    top-to-bottom wipe (confirmed by the author); `logo_font_load` blits
    `logo_font`; `tile_string_draw` tile-string interp.
  - Object-list loader cluster 0x615b-0x6208: `object_list_load` unpacks the current
    cell's object list from seg 14 into the 4-byte-slot tables at 0xDB00/DC00/DD00
    (`object_list_unpack` unpacker, `object_list_lookup` per-level pointer, `object_list_clear` clear,
    (`l61c2h` spawns actors via seg0 0x5F26). RAM: 0xD000 = stage (0=court-
    yard, 1-18), 0xD001 = room within stage, 0xD002 = hub / seg14 scenery+object
    datasets (6 hubs of 3 stages; row->hub table at seg0 0x5E71). See "Eighth session".
  - `lookup_word_tbl` (0x6549): generic word-table lookup (DE=table, A=index).
  - Screen/level build cluster (annotated):
    - 0x62d7: arms mode bytes 0xC415=0x20/0xC418=0x80, then jp seg0 0x53BD.
    - 0x62ed: full screen builder - clears state, paints tiles (seg2 helpers),
      sets cell event, unpacks scenery (scenery_load), loads object list
      (object_list_load) + spawns actors (l61c2h).
    - 0x63da: centre view (0xC425/0xC427 = 0x80), hide sprites, redraw chain.
    - `cell_event_set` (0x633a): set current cell event 0xCE00 from l6376h[row]
      (byte = column<<4 | event; event 6 has an immediate handler).
    - `actor_state_reset` (0x6389): reset object/actor state (clears 0xC470..0xC6FF +
      subsystems); `simon_block_clear` clears 0xC420..0xC46F; `sprites_hide` hides all 32
      sprites (Y=0xE0 in 0xD600 shadow); `mem_clear_stride` strided memory clear.
    - `simon_spawn_pos` (0x6409): set screen position 0xC425/0xC427/flag 0xC42C from
      per-row table l6426h (2 bytes/row).
  - Actor->sprite rendering (annotated):
    - `actor_sat_build` (0x644C): one actor's hardware sprites from its shape
      stream; pages seg 6 (sprite shapes) into 0xA000, looks shape up in word
      table 0xB473 by (ix+0x0B), writes sprite attrs at (ix|0x20) offset by
      actor Y (ix+3) and X (ix+5); stream codes 0x80/81/82 pick fixed (dx,dy) offset
      lists; restores seg 3.
    - `shot_sat_emit` (0x64EC) / `c800_sat_emit` (0x64F3): render every active
      slot in a list (8 shots @ 0xD700 / 7 actors @ 0xC800, stride 0x80) via
      `actor_sat_emit` (0x6508), which copies Y/X/pattern into the 0xD638
      sprite-attr shadow and fills the pattern from the l6a70h table.
    - `frame_vram_refresh` (0x6552): per-frame VRAM refresh - re-uploads the
      animated tile/sprite patterns each frame; animation phase in 0xC00F.
      Falls back to the plain shadow blit pattern_shadow_blit (copy 0xD400 -> VRAM 0xF400)
      when idle.
  - Data tables marked in seg01.blocks this pass: logo layout 0x6296-0x62d6,
    event table 0x6376-0x6388, per-row pos table 0x6426-0x644b, sprite offset
    lists 0x64d4-0x64eb.
  - Event/cutscene machinery (annotated; event-gated, not seen in normal play):
    - event_dracula (0x65b7): event sub-state machine, DISPATCH_A on 0xCE01 (11
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
  - Remaining seg1 play-tick callees named: `event_vscroll` (0x6848),
    `player_tick` (0x6B06), `simon_sat_build` (0x783E), `stage_bgm_play`
    (0x7956), `title_fill_strips` (0x7AD6), `title_set_color2` (0x7AEE),
    `tile_layout_draw` (0x7B39, already named), `combat_tick` (0x7D6F).
    Play-loop tail in `play_tick` also named: `room_event_tick` (0xB6B2,
    CE00; event 6 = event_dracula), `actors_tick` (0x98EC), `shot_tick`
    (0x9E38), `vendor_tick` (0x91C5), `pickup_tick` (0x8A51),
    `break_spark_tick` (0x88DF), `hazard_tick` (0x8FD6), `platform_tick`
    (0x90A2), `c800_sat_build`/`shot_sat_build`, `c800_sat_emit`/`shot_sat_emit`,
    `frame_vram_refresh`.  Event 6 (`event_dracula`) is Dracula's CE01 machine;
    it raises CE40 → `credits_tick` (named; see game-notes Ending / credits).

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
    * 0x6552 (`frame_vram_refresh`) is frame code (runs every frame); 0xC00F cycles the 16 phase values
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
    state machine (main_tick):
    * 0xC000 primary state walked 1 (title) -> 3 -> 4 -> 5.  State 3 = the intro
      cutscene (Simon nears the castle), a *timed* animation: its handler at
      0x41d1 steps sub-state 0xC001 0->4 and drives the 0xC004 phase counter
      (writers 0x41d7/0x4209/0x424e/0x41a4/0x4190/0x41cc).  State 4 = a brief
      bridge that builds the first stage; state 5 = in-stage play.
    * 0xC003 confirmed as the per-frame free-running counter (writer 0x4151).
    * On game start the intro handler calls reset_run_state (sub_44cdh, writer
      0x44da): a single ldir zero-fills the whole run work block 0xC405..0xDFFF
      (event state 0xCE00+, actor arrays 0xD000+), then seeds 0xC410..0xC412 and
      view defaults 0xC415=0x20 / 0xC418=0x80.  seg1 actor_state_reset (0x633e-0x634a)
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
    0x63DA redraw and simon_spawn_pos (per-room spawn Y/X/facing from l6426h).
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
      the spend path seg1 hourglass_use/0x7176 does `sub 5 / daa`), so 0x15 = "15" hearts.
    * **0xC700-0xC70F = inventory / item block** (NOT a single flag).  0xC701 is an
      item *bitfield*: bit 0 = white key (0 -> 1 on the key pickup, frame 414); other
      bits are sub-weapons that cost hearts (seg1 l713dh shifts 0xC701 and does
      `call c,holy_water_use` on bit 3 / `call c,hourglass_use` on bit 6); bit 7 is a
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
      restore_health (7 small life orb +8 / 22 potion bottle +32; vendor 0x16, not the boss-clear orb), keys/sub-weapons OR a bit into 0xC701/0xC702.
      Reached from BOTH pickup paths: the mid-air 0x24 heart (seg2 sub_9a72h ->
      collect_bonus(1)) and the settled 0xC500 list (collision -> collect).
    * **add_hearts (seg0 0x459B)** / **spend_hearts (0x45A7)** now labelled: BCD add
      (clamp 99) / subtract (floor 0) on 0xC417; heart counter confirmed BCD again
      (small +1 gave 00->01->02, no binary carry weirdness).
    * NEXT (partially done in twenty-eighth): `collect_bonus_tbl` is `defw`.
      3-5/8-14 named from domain + code (red/yellow shield, white cross, blue
      gem, sapphire ring, hourglass, boots, wings, candle).  Id 11 is a
      **tipped hourglass** (whip the id-10 world pickup once — `l8c4bh`;
      write-up in `docs/game-notes.md`). C431 bit2 lengthens 6/8/9/10.  Also the
      0x24->0x84 landing path.

- Eighth session (LOCATION / WORLD STRUCTURE - walk right through courtyard rooms
  0,1,2 then enter the castle), F8 timeline (baseline frame 275). Pins the
  hub/stage/room hierarchy so recordings can be tagged by location and we never
  conflate enemy/object positions between rooms. **KEY CORRECTION vs first pass:**
  the trio is a hub/stage/room hierarchy, NOT a raw pixel row/column:
    * **0xD002 = HUB** (scenery + object-data set), 6 hubs (0-5). Chosen from the stage via the
      seg0 row->dataset table at 0x5E71 = `0 0 0 0 |1 1 1|2 2 2|3 3 3|4 4 4|5 5 5`
      for stages 0..18 - i.e. stages are grouped in 3s per hub (matches "a hub has
      ~3 stages"). Each hub's packed scenery is in seg14 @ 0x8000; packed enemy
      objects @ 0x8668. Stage 0 scenery is `scenery_list_s00` (not in the hub table).
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
    * Data path (static): seg1 `object_list_load` unpacks hub D002's data into 0xDB00/DC00/
      DD00 (3 streams = the hub's 3 stages); `object_list_unpack` grammar = (id,attr) pairs,
      0x00 = next room cell (0x10 apart), 0xFF = end. Per object: list-id =
      actor type (`and 0x7F` at spawn); bit7 stripped (dogs only; unknown).
      Attr hi nibble = X cell, lo nibble = Y cell (x/y * 16 px).
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
    * NEXT to fully rebuild stages "with room relations": (1) ~~disassemble seg13~~
      (done: conn_lookup / door_tbl / spot_tbl in `segments/seg13.asm`); (2) ~~map
      per-room background bitmaps for actual geometry~~ (done: `roomperm.py` +
      `mtile_*` tables in seg11/12); (3) name the object ids
      (`collect_bonus_tbl` annotated; seg14 list-ids named — 0x0d/0x10 are
      hunchback/axe knight, not scenery).

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
      weapon id = bonus id - 0x19 (chain whip = bonus 0x1A), except bonus 0x1E
      (index 5) which is holy water (`C701` bit 3) and does not write 0xC416.
    * Attack path split (seg1 ~0x7D80): weapon < 2 = whip (stays with Simon), >= 2 =
      projectile (2=knife, 3=axe, 4=cross). Damage tables (seg1 weapon_hit_damage):
      weapon 0 + 2 use l7e60h, others use l7e67h. Catch-or-lose is lose_weapon
      0x8E9A. See game-notes "Equippable weapons".

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
      0xC701 bit4 halves + spends 0xC441 charge); `hurt_simon_spikes` (seg2
      0x85AD) = fixed 8 or 16 from a 0xC580 spike-bar slot (16 while it
      descends, 8 while it retracts), and sets hurt state 0xC420=5.  l81d5h's odd byte is the per-type contact-damage field (its even
      byte is the kill score).
    * **Simon deals damage** via `weapon_hit_damage` (seg1 0x7E33) -> `damage_enemy`
      (0x4643, 0xC418 -= B).  Per-weapon table by (type-0x11): leather/knife =
      04 08 08 04 04 04 10; chain/axe/cross = 06 0C 0C 06 06 06 18; type 0x17 with
      weapon>=2 is quartered.  Lesser enemies (type<0x11) die on the first hit.
    * Names in segments/msx.sym: damage_enemy, hurt_simon_contact,
      hurt_simon_spikes, spike_bar_overlap, weapon_hit_damage.

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
    * **Buy/refuse**: `vendor_purchase_tick` (0x94C1) ticks 0xC706 and polls
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

- Twenty-eighth session (SEG11/12 MAP DATA + BODY-TILE ERRATA):
    * Graduated banks 0x0B/0x0C from `INCBIN` to `INCLUDE segments/seg11.asm` /
      `seg12.asm` (`PHASE` 0x6000 / 0x8000).  Unique labels (window shared with
      seg01/seg02): `mtile_rowbase` 0x6000, `mtile_roomptr` 0x6013 (156 rooms),
      `mtile_stream_c41a` 0x614B, `mtile_streams` 0x617B, `mtile_defbase` 0x7EBB,
      `mtile_defs_s00`..`s18` (defs still `INCBIN` slices; stage 0/18 straddle
      into the next bank).  `room_map_build` now references those names.
    * Minimap solid-noise errata: brick BODY 09-0b is solid only when 4-adjacent
      to a structural SURFACE 01-04 (was 01-08).  Wallpaper 05-08 next to a lone
      09 no longer paints as a 1x1 block.  Resolves stage 6 room 5, stage 10
      "sparkle", stage 15 rooms 6-9 solids, stage 17 leftover 09, and stage 0
      room 2 gate 09/0b specks.  Stage 15 0c/0d stay amber (real stairs).
      Dracula room 9 still `PERM_OVERRIDE`.
    * `collect_bonus_tbl` (seg2 0x8D45) converted from fake instructions to
      `defw`; confirmed ids annotated (hearts, rosary, map, bibles, staff, keys,
      score bags, health pots).  Seg14 list-ids named (see game-notes
      "World structure"): 0x0d hunchback, 0x10 axe knight, 0x1F placed bat,
      0x21 placed merman; 0x05 dog confirmed.

- Twenty-seventh session (annotate located player + state-machine code):
    * Converted title_layout 0x4C3F-0x4D0E from fake instructions to `defb`
      (0xFF=end, 0xFE=next row); named `tile_layout_draw` (0x7B39).
    * Named Simon's walk/jump/whip/frame-mirror path and the C420 action
      handlers (grounded/jump/crouch/stairs/fall/hurt/dying).  Jump and whip
      DISPATCH_A tables + `jump_y_delta` are now `defw`/`defb`.
    * Labeled main_state_tbl 0-13 from static reads of the play-flag fork
      (death, game-over, room-trans, stage-exit, vendor, game-start).  States 8
      and 11 still want a live trace.

- Twenty-seventh session (SEG13 OUT OF INCBIN):
    * Graduated bank 0x0D from `INCBIN segments/seg13.bin` to `INCLUDE
      segments/seg13.asm` (`PHASE 0xA000`).  Graphics/RLE stay as `INCBIN` slices
      of the bin (metatile defs, Simon streams, intro_sky); code + authored tables
      are source: `conn_lookup` / `conn_ptr` / per-stage nibble records, `door_tbl`
      (19x3), `spot_tbl` (stage-12 two-way warps into C5B1/C5B2/C5B4).  Labels are
      unique names so they don't collide with seg03 in the same CPU window.
    * Paged wrappers named: `conn_lookup_paged` (0x5A35), `conn_load_permits_paged`
      (0x5A3E), `door_load_paged` (0x5A47).

- Twenty-sixth session (DRACULA ROOM 9 permeability override):
    * Shipped `PERM_OVERRIDE[(18, 9)]`: floor (rows 22-23) plus four pairs of 2x1
      jump ledges flanking the decorative columns.  0c/0d pillars no longer paint
      as stairs; brick-ID side columns and dotted 09-0b speckle are empty.  Perm
      mode only; `--collision` stays the engine test.  Regenerated `gfx/minimap_s18.png`.

- Twenty-fifth session (WHITE-KEY DOOR TABLE: universal for stages 0-18):
    * **Placement is a per-stage ROM table, not geometry and not 0x1F.** Watch on
      0xC5AC-C5AE during a stage-15 warp showed writer `0d:bb55` = `door_load_coords`
      (seg13 0xBB37). `HL = 0xBB61 + stage*3`; each record is `(room | vert<<7), Y, X`.
      If `0xD001` matches the room nibble, `ld (0xC5AD),hl` stores **Y then X**
      (C5AD=Y, C5AE=X) and arms C5AC (`0xFF` if bit7, else `0x04`). Live stage 15:
      C5AD=`0x80`, C5AE=`0x0C` = flush-left door at tile row 16. This supersedes
      "0x1F is the door" and the C5AD=X / C5AE=Y comments.
    * **Two layers on EVERY stage.** (1) Table object + key (`door_interact` /
      `door_proximity`). (2) After open, `l77d8h` uses the CONN permit: blocked ->
      `set_stage_boundary` / `advance_stage`; valid room -> intra-stage wrap.
      Intra-stage (table edge is not 0xF): stages **3, 6, 9, 12, 15, 18**. Stage 15
      is not special except that we traced it (room 8 left -> isolated room 9).
      Stage 18 room 8 left -> room 9 is the Dracula door.
    * **Renames / annotations:** `door_blit_tiles` (0x5403), `door_interact`
      (0x771F), `door_proximity` (0x8587), `door_anim_tick` (0x914E),
      `door_begin_open` (0x9175); `door_load_coords` / `door_tbl` now live in
      `segments/seg13.asm`. `roomperm.py` default overlay is the table
      (dropped `DOOR_OVERRIDE`).
    * **Warp artifacts (stage-15 skip-intro ROM, not a door finding):** intro still
      queues BGM `0x8A`; `0xD012` difficulty left at 0 after `reset_run_state`, so
      hits felt weak (enemy speed = `tier*32`). CocoaMSX `saveStateOnExit` can ignore
      an argv ROM vs last cart.

- Twenty-fourth session (STAGE-15 DOOR reframed: intra-stage mechanism B, prior
  "ruled out" was a bad scan):
    * **Stage 15's door is INTRA-STAGE, not a stage exit.** Decoded stage-15
      connectivity: room 8 `left=9`, and **room 9 is fully isolated** (up/down/left/
      right all `F`) - a dead-end room reachable only through the room-8 door. The
      horizontal transition code (`seg1 l77d8h`) fires `set_stage_boundary` (-> 0xC408
      -> advance_stage) ONLY on a **blocked** left/right permit (0xFF); room 8's left
      permit is a valid room index, so mechanism A treats it as a FREE crossing and
      never gates it. Mechanism A (blocked-edge stage exit) therefore structurally
      cannot be stage 15's door.
    * **The type-0x1F special object is a brazier/block REVEAL.** `l87f6h` (checks
      display-type `0x1F` -> promoter `l881bh` -> spawner `l9180h` -> struct at
      0xC5B5/0xC5C5) lives inside `brazier_destroyed` (seg2 0x87C1). So a whippable
      object whose DEFINITION display-type is `0x1F` becomes an in-room special object
      at its spot; its position feeds 0xC5AD/0xC5AE, which `sub_771fh`/`0x8587`
      proximity-test to open with the white key (0xC701 bit0). This is exactly an
      intra-stage locked-door shape (open a path to another room, no stage advance).
    * **Correction: mechanism B was never actually ruled out.** The twenty-first-
      session A/B test scanned the raw object **list-id** `== 0x1f` (`decode_objects`
      `sid = oid & 0x7F`) and found "only 3 rooms (stages 3/4)". But door-ness is
      **display-type `0x1f`**, a property of the object DEFINITION, not the list id -
      the scan measured the wrong field. **Later:** those 3 rooms' list-id `0x1F`
      is a placed hanging bat (`enemy_placed_bat_init`), not vendor/reveal either
      — display-type `0x1F` on a brazier remains the vendor path.
    * **OPEN (linchpin, RESOLVED in twenty-fifth):** decode the object-id -> display-type definition table to
      enumerate display-type-`0x1F` rooms and confirm stage 15 room 8. It sits in a
      data region ~seg2 `0x8799`-`0x87c0` that z80dasm currently shows as instructions
      (needs a db pass). Alternative: empirically confirm in the emulator (walk to the
      room-8 door on stage 15, watch 0xC5AC/0xC5AD/0xC5AE + 0xC408/0xC41E).

- Twenty-third session (MINIMAP is now the ONLY layout; Dracula-room notes):
    * **Dropped BFS entirely.** After comparing both, the user chose the game's own
      authored geography. `tools/roomperm.py` now has a single `layout()` (the former
      `minimap_layout`, seg2 0x9681 table); removed `bfs_layout`, `DIR_DELTA`,
      `LAYOUT_OVERRIDE`, and the `--minimap` flag / `_gamemap` suffix. Connectivity
      (`CONN_PTR`) is retained ONLY for door detection, never for placement. Deleted
      the 19 `minimap_s*_gamemap.png` compare files and regenerated the full set
      (s00..s18) from the minimap table. `make verify` unaffected (tool-only change).
    * **Dracula's room (stage 18 room 9) = a heuristic dead-end (deferred).** Decoded
      the room's raw tile grid and correlated it against two in-game screenshots. The
      layout is: FLOOR at rows 22-23 (`06` surface / `0b` body); `0c/0d` decorative
      pillars at cols 2-3 & 28-29; a big central PICTURE FRAME (unique metatile run
      `0x10`..`0xf5`, cols 7-24) = Dracula's portrait; and brick strips (`06`-`0b`) down
      cols 0-1, 4-6, 25-27, 30-31.
        - **User ground truth: there are NO walls in this room.** Only the FLOOR is
          impermeable (plus a couple of scripted jump-block ledges Simon bounces between
          to climb). The picture frame and both side columns are background decoration.
        - **Why no tile heuristic can render it faithfully.** The decorative side columns
          are built from the SAME brick tile IDs (`06`-`0b`) as the real floor, so there
          is no per-tile signal separating decoration from solid. Every rule fails the
          same way: DECOR-set (`05`-`08` passable) drops the floor's `06` surface; the
          engine's own per-stage solidity threshold (`tile_is_solid`, stage 18 = `8` ->
          `01`-`08` solid) would paint all the side columns as WALLS that don't exist;
          context-adjacency can't tell a column apart from a floor edge. The boss room
          simply doesn't drive its geometry from tile collision (Simon is bounded by the
          screen + scripted platforms).
        - **Rejected** switching the permeability view to the engine collision threshold:
          it mis-renders room 9 AND regresses other higher-threshold stages (measured:
          stage 10 +16.1%, stage 18 +9.9%, stage 0 +4.6%), with no ground truth to
          justify those. `0c/0d` also still render amber ("staircases that aren't
          diagonal") because STAIRS is a global set.
        - **Path forward (PARKED):** `PERM_OVERRIDE[(18, 9)]` paints the floor plus
          2x1 jump ledges and looks right on the sheet, but it is hand-authored.
          Come back if we find a principled source.
          Also all-edges-blocked -> the door heuristic fires cosmetic false doors there.

- Twenty-second session (MINIMAP LAYOUT TABLE = ground-truth room geography):
    * **The game ships hand-authored room positions.** Chasing why the connectivity-
      BFS layout mis-placed rooms in stages 13/15, the user pointed at the in-game F2
      "world map" item. Followed F2: seg0 **read_fkeys (0x4BFB)** samples kbd row 6
      (F1/F2/F3 -> bits 0/1/2), edge-detected into **0xC00B**. seg2 **minimap_driver
      (0x9559)** dispatches on map-screen state **0xCF38**; F2 needs the map item
      (**0xC701 bit7**) and spends one of **0xC70F** uses (seeded to 3).
    * **minimap_room_pos (seg2 0x9681)** is authoritative geography: per stage 0xD000
      it indexes **0x969C** -> a per-room array of one-byte POSITION CODES, then maps
      each code via **0x975E** to a packed coord (**hi byte = X** 0x20+0x20*col, 6 cols;
      **lo byte = Y** 0x38+0x15*row, 5 rows) -> 0xCFF2. **minimap_room_count (0x95FD)**
      = rooms per stage. Decoded straight from ROM for all **19 stages (0..18)**.
    * **Offered as `--minimap` alongside the BFS default** in `tools/roomperm.py`
      (`minimap_layout` vs `bfs_layout`; `_gamemap` suffix). The BFS reconstruction
      stays the default - it reasons about physical adjacency, which is what a modder
      thinks in - and the game table is opt-in for comparison. **BFS agrees with the
      game map on 16/19 stages**; only portal/loop stages 12, 13, 18 differ (the game
      table reproduces the user's hand corrections there: stage 13 room 10 right of 9,
      etc.). `minimap_stages()`/`minimap_room_count()` drive `--all`, so both paths now
      render **stage 18 (Dracula)** - its geometry rowbase delta is a garbage sentinel
      (-23), so room count comes from the minimap table (10) while its room pointers/
      defbase decode normally.
    * **Why the heuristic was doomed (confirmed).** Connectivity is a NAVIGATION graph,
      not spatial: it has wrap/portal edges on BOTH axes. Proof: stage 8 has a genuine
      **vertical loop** (`4.down->7` AND `7.down->4`, yet 7 is above 4). The old rule
      "horizontal can loop, vertical can't" was simply false - hence the authored table.
    * Removed the now-dead BFS layout / `LAYOUT_OVERRIDE` (stage 12) / `stage_rows`;
      deleted the `_doorA`/`_doorB` comparison PNGs. Annotated seg0 `read_fkeys` and the
      seg2 minimap subsystem (driver, build loop, room_pos + tables); msx.sym updated.
      `make verify` still byte-exact.
    * **Context-aware solidity (fixed stage-18 stray blocks).** Stage 18's staircases
      pair each stair (0c/0d) with a brick-BODY tile (09-0b) as a decorative support;
      the permeability view painted those standalone bodies as stray 1x1 white blocks.
      `is_solid_ctx` now counts 09-0b solid only when 4-adjacent to a SURFACE tile
      01-08 (structural 01-04 plus the 05-08 pair, which is the floor/wall surface in
      some stages - e.g. Dracula room 9's floor is a 06 surface over a 0b body), so
      real walls/floors stay solid (no striping, unlike the engine-collision view)
      while lone supports become passable. Used by render, ascii, and door detection.
      (Chose this over the engine's raw per-stage collision threshold, which was
      correct for stage 18 but changed ~33% of the higher-threshold stages like 10.)
    * Open: stage 18 room 9 (Dracula's isolated arena) has all edges blocked, so the
      door heuristic fires on its edge gaps - cosmetic false doors, to revisit with the
      door work (door = blocked-edge + wall opening; not an object). Room 8's left
      nibble is 9 (not blocked), so mechanism A can't see its real door either - same
      class of miss as stage 15, for the door pass.
- Twenty-first session (DOOR = placed object, data path decoded):
    * **Key correction.** A door's TILES are universal: stage 15 room 8's door (left
      edge) is **byte-for-byte identical** to room 0's right-edge opening that is NOT a
      door - wall (01/02,0a/0b) rows 0-13, void (00) rows 14-19, floor below. Proof that
      geometry alone can never separate a real door from a walled recess; door-ness is
      DATA, not pixels.
    * **Door is a placed special object (type 0x1F).** Traced the runtime path end to
      end: the object renderer (seg2 ~0x87F6) treats display-type **0x1F** as a special
      object. seg2 `l881bh` reads its attribute `ix+009`; if bits7-6 are set (`&0xC0 ==
      0xC0`) it splits the attr into **subtype = bits5-2**, **slot = bits1-0** and calls
      the spawner **`l9180h`** (0x9180). The spawner writes a 16-byte struct into
      **0xC5B5** (or 0xC5C5): +0=active, +1/+2 = position, +4 = subtype, +5 = slot,
      +7/+8 = latched position. `0xC5AD/0xC5AE` (= 0xC5B5 slot +? / the door coords the
      proximity test reads) come straight from this object's placement.
    * **Door state machine (0xC5AC).** seg2 `l914eh`/`sub_9175h`/`l916f`: 0xC5AC = door
      sub-state (1 = armed, 0xFF = opening kicked off via 0x5403, 3 = fully open, 5 =
      vertical variant). While in state 3 it advances a frame counter (+3) blitting the
      opening frames via 0x494D until 0x2C. `sub_771fh` (seg1) dispatches on 0xC5AC and,
      on overlap (0x8587) + white key (0xC701 bit0), spends the key and opens.
    * **A/B comparison RULED OUT the placed-object door theory.** Added
      `roomperm.py --compare-doors` (emits `_doorA` = mechanism A edge/geometry and
      `_doorB` = placed-object overlay per stage). Result the user verified against the
      real game: **doors are mechanism A** (blocked edge + opening), correct for EVERY
      stage except 15. Mechanism B is a dead end for white-key doors: id-0x1f objects
      exist in only **3 rooms game-wide** (stages 3 and 4), none a white-key door. So
      the type-0x1F code path (seg2 `l881bh`/`l9180h`/`0xC5AC`) is real but it's the
      **vendor / a rare special object**, NOT the stage door. (Stage-15 room 8's list
      object `0x10 @ (11,10)` is the painting, confirming B doesn't mark the door.)
    * **Shipped: mechanism A is now the default door detector.** `door_rects()` rewritten
      to check all FOUR blocked edges (was left/right only) with an enclosed opening;
      `--compare-doors` kept for future A/B checks. All `gfx/minimap_s*.png` regenerated:
      stage 1 door = room 7 right edge (correct); stage 15 = room 8 only (via override).
    * **Stage 15 is the lone exception (to revisit).** Its real door (room 8, left-wall
      gap) is NOT a blocked edge (room 8 left → room 9), so A can't see it; it stays
      pinned in `DOOR_OVERRIDE`. Mechanism still open - user wants to discuss later.
    * **DOWN edges are NOT doors (fixed).** Falling off a bottom edge is a DEATH PIT
      (engine's room_edge_detect bottomless-pit path), not an exit - so `door_rects()` now
      checks left/right/up only, never down (stage 15 room 6's bottom gap is death).
    * **Layout: vertical-first placement (fixed circular rows).** Horizontal links can
      loop, making L/R ambiguous; vertical (up/down) links never loop. `layout()` now
      exhausts vertical before each single horizontal step, distinguishing two loop
      kinds: (a) a 2-room loop where a room's left AND right point to the same neighbour
      (stage 15: 4↔5, 2↔3) is DEFERRED so the room takes its column from its vertical
      parent (8 down→5 puts 5 under 8); (b) a longer cycle with distinct L/R (stage 1's
      0-1-2-3 bottom row) is unrolled RIGHT-before-LEFT so it grows forward and the
      wrap edge lands on an already-placed target. Results: stage 1 stays 4567/0123,
      stage 15 stacks 8-above-5 / 7-above-4, stage 13's 0-1-2 chain stays intact; no
      room overlaps on any stage. (User diagnosed the loop cause and the vertical rule.)
    * **Portal (asymmetric) links found.** Audited back-links (A d→B should give
      B opp→A). Most one-way links are consistent DROPS (X down→Y, Y up→blocked - you
      fall but can't climb back). Stage 13 is the only TRUE portal: 11 left→9 while
      9 right→10 (two rooms both claim 9's right), so it can't be a perfect grid - the
      portal edge is simply ignored for placement, which keeps the physical rooms sane.
    * **Source annotated** (seg2, byte-exact): the type-0x1F special-object promoter
      (0x881B / l8838h), the spawner `l9180h`, and the 0xC5AC door-open state machine
      (`l914eh`/`sub_9175h`) - now understood to be the vendor/special-object path.

- Twentieth session (STAGE-12 anchor + WHITE-KEY DOOR rendering):
    * **Stage 12 layout.** Portal labyrinth = four physically-disconnected segments
      ({0,1,2}, {3,4,5,6}, {7,8}, {9,10,11}, room 6 isolated); in-segment left/right
      edges are portals, not adjacency. `LAYOUT_OVERRIDE[12]="row"` now lays it out
      in index order anchored at room 0 (start room), keeping each segment contiguous.
    * **Door mechanism (confirmed).** A stage exit fires when Simon walks/climbs off a
      connectivity-blocked edge (nibble 0xF) → boundary flag **0xC408** → white-key
      check → `advance_stage` (0x434E). Routed through the seg13 brain (`conn_lookup_paged`
      seg0 0x5A35 → 0xB963), so it is **direction-agnostic**: stage 1's door is a
      horizontal walk-off (room 7 right); **stage 15's door is an UP exit** (room 8
      up=0xF) into a mid-room framed door. White-key check/consume: seg0 0x438B
      (`and 0FEh` on 0xC701 bit0).
    * **Door rendering (shipped, with a TODO).** `tools/roomperm.py door_rects()`
      draws a red bar at blocked edges with an enclosed passable opening, sized to
      the opening. Works for the common case; on by default (`--no-doors` to skip).
    * **TWO door mechanisms (confirmed).** (a) **Edge door** = walk off a blocked
      horizontal edge → 0xC408 boundary flag (stage 1 room 7; the geometric heuristic
      handles these). (b) **Special-object door** = a placed door you approach; the
      white-key check `sub_771fh` calls 0x8587, a PROXIMITY test vs the special object
      at 0xC5AD/0xC5AE (0xC5B5/0xC700 subsystem) - NOT a tile lookup (stage 15 room 8,
      an UP exit). Both spend the white key and advance the stage but via different code.
    * **Why the heuristic mis-fired on stage 15** (all now understood): it only checks
      left/right edges (missed room 8's UP/object door); a blocked edge + gap is not
      uniquely a door (room 0 = walled recess, geometrically identical to a real edge
      door); scenery columns (0x2c+, e.g. 0x6f) read as passable so the all-blocked
      isolated decoy room 9 lit up both sides. No universal door TILE - and BOTH
      framed boxes in room 8 (9c/9d-a1/a2 and 06/07-08/09 centres) are PAINTINGS (a
      portrait-gallery motif recurring in stage-15 rooms 6,7,8,9), not doors. The
      real door in room 8 is the empty (air) gap flush against the LEFT wall: cols
      0-3 solid down to row 13, then rows 14-19 open.
    * **Fix shipped: curated `DOOR_OVERRIDE` table** in roomperm.py (stage → {room:
      [rects]}) that REPLACES the heuristic for hand-verified stages; rect size still
      derived from the tile opening. Seeded stage 15 = room 8 only (the left-wall
      air gap, NOT the two paintings). Heuristic stays the default
      for un-curated stages (stage 1 etc.
      still correct). REMAINING: verify the other stages vs the game map and pin any
      the heuristic gets wrong; longer-term, decode the special-object door data
      source (feeds 0xC5AD/0xC5AE) for principled detection.
    * **Source annotated** (seg0/seg1, all in-source; `make verify` byte-identical):
      seg1 room-edge crossing handler l77d8h (+ renamed `set_stage_boundary` 0x7807),
      the edge/stair detector `room_edge_detect` (sets pending dir 0xC41B by direction, with
      the up/down/left/right cases + bottomless-pit path), the white-key door check
      `sub_771fh`, and seg0 `conn_lookup_paged` (the seg13-paged transition-brain wrappers:
      0xB963 lookup, 0xB99A permit load).
    * **Door-detection lead (NEW, changes the approach).** `sub_771fh` loads Simon's
      position (0xC425 Y, 0xC427 X) and calls **0x8587**, which is NOT a tile lookup -
      it is a PROXIMITY test (Simon ± facing vs a bounding box) against the current
      **special object** at **0xC5AD/0xC5AE**. So the white-key door is a *placed
      special object* (0xC5B5/0xC700 vendor/special-object subsystem), NOT a tile-map
      opening. That's exactly why the geometry heuristic mis-renders stage 15 (it
      hunts wall gaps). **To fix door rendering: find where the per-room door special
      object (0xC5AD/0xC5AE / 0xC5B5 list) is loaded from ROM** and mark that cell -
      likely a specific object id in the seg14 per-room object list (candidate: id
      0x10 sits alone in stage-15 room 8 @ cell (11,10)). Verify before trusting.

- Nineteenth session (ROOM CONNECTIVITY + spatial minimaps):
    * **Transition graph decoded (seg13).** Normal room-to-room movement is NOT
      0xD001 arithmetic - it's a per-stage table. `CONN_PTR` word table @ **0xB9D3**
      (18 entries by 0xD000) -> a per-room 2-byte record = **4 nibbles up/down/left/
      right = destination room index** (0xF = blocked). Engine reads it at seg13
      0xB963/0xB9BD and writes the result to 0xD001 at **seg13 0xB987**. Edge/stair
      detector `room_edge_detect` (seg1 0x7682) sets pending dir in 0xC41B (1=up 2=down
      3=left 4=right); permit bytes 0xC41C-0xC41F come from the same nibbles (seg13
      0xB99A). Stage advance (0xD000++) is separate (`advance_stage` 0x434E via the
      0xC408 boundary flag / white-key door). 0xD000 is never touched by the graph.
    * Validated byte-exact: decode matches all recorded consecutive stage-1
      transitions + the stage-1 horizontal loop (room3 right->0, room0 left->3).
    * **Spatial minimaps.** `tools/roomperm.py` now places rooms by BFS over the
      connectivity graph (right/down-first so room 0 stays top-left; horizontal
      loops unroll; disconnected components stack vertically) instead of a fixed
      4-wide index grid. Portal-labyrinth stages get `LAYOUT_OVERRIDE` - stage 12
      is physically one row (0..11) but its table encodes portal loops -> "row".
    * Placement bug fixed: a plain BFS rotated horizontal loops and dragged any
      linear row hanging off the loop out of alignment (stage 1 wrongly came out
      top 7,4,5,6 / bottom 3,0,1,2, with room 7 detached from its only neighbour
      6). Fix: exhaust right/down chains before each left/up step so loops unroll
      forward from the anchor. Stage 1 now correctly top 4,5,6,7 / bottom 0,1,2,3
      (5 above 1, 7 above 3). All 18 stages: no cell overlaps, no missing rooms.
    * Open: other portal stages, if any, still need identifying (user flags them
      per review).

- Eighteenth session (ENEMY GENERATORS + all-stage map rendering):
    * **Continuous enemy spawner cracked.** `room_spawner` (seg0 0x5EBF) indexes
      seg14 word table **0x85A6** by stage (0xD000), then the resulting byte table
      by room (0xD001) to fetch a per-room **spawn bitmask** (stage 1 bytes at
      **0x85CF**). Each set bit (LSB first) fires one rate-gated generator in seg2:
      bit0 `zombie_generator` 0x9CED -> type 01 (zombie); bit1 0x9D52 -> type 02;
      bit2 0x9D59 -> type 03; bit3 0x9D9E -> type 04 (bat: vertical undulation, one
      horizontal way); bits 4-6 0x9DCA/0x9DDC/0x9DEE (types unconfirmed). Stage 1
      confirmed: rooms 0/1/5/6 spawn zombies, room 4 spawns bats.
    * Each generator is rate-gated by `spawn_rate_gate` (per-generator 0xCF00+ counter vs
      a threshold table scaled by 0xD012 difficulty). **Spawn position is hardcoded
      per stage/room** in `spawn_pick_pos` (annotated) - NOT read from the tile map
      (stage-1 room-0 zombies enter at X=0xC0). Renamed `zombie_generator`
      (seg0 call site + msx.sym); `make verify` byte-identical.
    * **The 08/05 "artifacts" are inert background art, NOT generators.** Ruled out
      by: spawning is bitmask-driven, positions are hardcoded and don't line up with
      the 08/05 cells, and rooms spawn regardless of the pair's presence. Their
      actual picture is still unidentified - tile PATTERNS live in a VRAM page the
      game RLE-decodes from ROM per room (not captured by RAM snapshots), and the
      background tileset isn't in the gfx catalogue yet (only sprites are).
      Per-room gfx scripts (`room_gfx_load` / `gfx_script_run`) load enemy
      **sprite** VRAM (`FA00+`), not the 4bpp playfield; tilesets still come
      from seg4-6 (`page_tileset_banks`).
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
  the labels (byte-exact).  The earlier dog/zombie X-offset puzzle is closed:
  +0x05 is X and +0x03 is Y for every type. The F8 flee dump that "moved +0x03"
  was watching Y (hardware SAT is Y then X), not a per-type layout.

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
  the labels.  0xB473 is banked: with seg6 paged it is the actor shape-stream
  word table (`actor_sat_build`); with seg3 paged the same CPU address is code.
  Tooling: fixed CRLF line endings in `tools/split-rom.sh` (it wouldn't run, which is
  what had left seg02-04.bin missing); it now regenerates seg01-15.bin cleanly.

## In progress / next

Seg0 VDP layer named end to end: the command-engine primitives
(`vdp_cmd_wait` / `vdp_status_read` / `vdp_line_h` / `vdp_line_v` / `vdp_box` /
`vdp_hmmv` / `vdp_hmmc` alongside the existing `vdp_hmmm` / `vdp_lmmm`), the
`vram_write` tile blitters, the 1bpp glyph path (`glyph_blit_run` ->
`glyph_expand_4bpp` -> `vram_blit_tile8`), and the HUD painters
(`hud_draw_all`, `hud_panel_frames`, the bar frames).  Two stale claims in
game-notes corrected while doing it: `hud_panel_frames` (0x454C) draws three
`vdp_box` outlines rather than copying title graphics, and `sub_554fh` blits a
32x32 image as a 4x4 tile grid rather than assembling the sprite attribute
table (that is seg1 `simon_sat_build` / `actor_sat_build`).

Swept out every z80dasm symbol-for-immediate false xref in segs 0-3 (**91**
`ld rr,NAME` sites plus `ld bc,l4206h`, which was a 66x6 rectangle size, not an
address).  z80dasm substitutes a name for any matching value, so each small
constant that collides with a low BIOS entry came back as that entry:
`ld de,CHKRAM` for `ld de,0` (73 sites), plus SYNCHR 8 / CHRGTR 0x10 /
WRSLT 0x14 / OUTDO 0x18 / DCOMPR 0x20 / CALLF 0x30 / SETRD 0x50 and a few
higher ones (QINLIN, UPC, SCALXY, SETC) used as counters and velocities.  All
are hex literals now; only `call`/`jp` targets still carry BIOS names.  Two
values are worth remembering: the `ldir` at seg0 0x5150 copies **0x14 = 20**
bytes (the PSG channel block), and seg2 `shot_axe` adds **0x50**/frame.
Gotcha folded into the `konami-msx-disasm` skill — re-audit after every regen.

Spike bars (stage 6 room 1) identified and annotated end to end: the two seg9
fragments once labelled `bonus_hud_9a80`/`_9a90` are `spike_bar_mount` + `spike`
(now `data/spike_bar.asm`), staged by seg0 0x5494 into page 1 at (0x80,0x70) and
drawn by `hazard_tick` -> `spike_bar_slot_tick`.  The consumer had been invisible
because its source coordinate was disassembled as a code label (`ld hl,l8070h`,
now `08070h`) - another instance of the immediate-operand-is-a-lie trap, this one
a real seg2 label rather than a BIOS name.  The chain above each bar is a smear,
not artwork (16-row block, 12 rows of art, drawn at Y-4 with a 4px step).  Full
write-up in game-notes "Spike bars".

Seg0 `0x5428-0x5493` converted from misdisassembled "code" (it was the source of
13 bogus `jp 0003ch` lines) to the door graphic it really is: `door_tile_ptr`, 6
word pointers walked by `door_blit_tiles`, into three 8x8 4bpp tiles
(`door_tile_joint` / `_shaft` / `_joint_end`) that stack into an 8x48 vertical
bar, 4px wide, with a widened joint on three of the six tiles.  Block map +
`msx.sym` updated so a regen reproduces it.  This also caught a wrong address in
the notes: the HUD/bonus loader is at **0x5494**, not 0x54A6 (the spike-bar
staging blit inside it is 0x54AD).

Moving platforms annotated end to end (seg2 0x9034-0x914D plus the Simon side).
The 7-byte C598 layout, the reverse-at-each-end mover, the 4-cell CC sprite
build and `platform_tbl`'s `{Y,X,step,span}` records are all in game-notes now;
`platform_stand_test` (0x852B) was unlabelled because seg1 reaches it by a raw
cross-bank `call 0852bh`.  New `segments/seg02.blocks` covers the SAT cell table
at 0x9146, which z80dasm had decoded as `ret nc` / `call nc`.  The +5/+6
counters are never written by `platform_load` because `actor_state_reset`
already zeroed 0xC470-0xC6FF (which includes C598) on room load.

**Game Master cartridge pass - done.** The `0x5D1D` menu turned out to be one of
three hidden features unlocked by Konami's **Game Master** cheat cartridge, and
the whole subsystem is now traced, named and documented (game-notes has a
dedicated section).  `game_master_detect` (0x5C99) RDSLTs six bytes at CPU
0x7FFA in every slot/subslot against `game_master_sig` and sets `0xE600`; that
one flag gates:

1. **Pause / frame advance** (`gm_pause_check`, 0x40C5, ahead of the game tick):
   STOP pauses and mutes the PSG, `;` single-steps one frame.
2. **Stage / lives select** (`state_game_master_menu`, state 13): the `0x5D1D`
   menu, two-digit entry via `gm_digit_entry`, applied by `gm_apply_values`.
3. **Continue on game over** (`gm_continue_text` / `gm_continue_key`): F5.

Six data runs in seg0 were being decoded as code and now have block-map entries:
the three text streams (0x5D1D / 0x5D79 / 0x5D9F, converted to `vk`),
`gm_stage_hub_tbl` (0x5E71), `gm_cursor_y` (0x5EBC) and `gm_continue_text`
(0x4300).  Two comments were wrong and are fixed: the pause key is **STOP**
(row 7 bit 4), not SPACE, and state 13 is the Game Master menu, not a
"new game / password" screen.

Worth recording as a font gotcha: the HUD font's punctuation slots are not ASCII
shapes, so `@` is a horizontal rule, `_` is a right-pointing arrow (the menu
cursor) and `?` is an **equals sign** - `vk "STAGE NUMBER?"` actually renders
`STAGE NUMBER=`.

Two follow-ups left open by the spike-bar pass, both closed this pass:

1. **`hurt_simon_projectile` renamed to `hurt_simon_spikes`.** Confirmed: the
   only writer of 0xC580 is `spike_bars_seed` (stage 6 room 1), and the room-load
   wipe in `actor_state_reset` (seg1 0x63BA, 0xC470-0xC6FF) is why the pool
   starts empty — that same wipe is also why `platform_load` can skip +5/+6.
   Overlap helper named `spike_bar_overlap`. Enemy shots stay on the D700 path.
2. **`msx.sym` collisions audited and filtered at regen.** 48 CPU addresses are
   shared across banks (21 named-vs-named, 27 named-vs-auto). Splitting into
   committed per-segment `.sym` files would duplicate the catalog; instead
   `tools/seg_sym.py` builds a temp file per regen so 0x902E is
   `spike_bars_restore` in seg2 and `sfx_0e_block_break` in seg14. That name is
   now in `msx.sym` as well. `tools/seg_sym.py --audit` reprints the list.

Seg14 PSG driver internals renamed: the `snd_8xxx` placeholders (kept unique
vs seg2's `l8xxxh` in the shared 0x8000 window) are now `sound_*` names that
match the rest of the tick (`sound_cmd_scale` / `_ext` / `_octave` / `_jump` /
`_call` / `_return` / `_stop`, `sound_sfx_op` / `_loop` / `_mix`, fade and
note helpers). All 50 are in `msx.sym`.

Half-renames (comment/`msx.sym` name, still `sub_XXXXh` in source) folded in for
the graphics kernel, bank switchers, object-list loader, minimap, and the
confirmed gameplay helpers (`award_kill_score`, `collect_bonus_apply`, etc.).
`minimap_room_count` is `defb`. `vendor_purchase_tick` is labeled at 0x94C1
(the 0x94BE comment was the tail of `sub_94b6h`).

Parked: none (fodder `ix+1` machines named: raven wait/coast/hover/pick/strafe,
dog idle/run/air, bone dragon form/idle/spit, red skeleton wake/walk/pause,
hunchback wait/drop/crouch/jump/hide, blob hatch/fall/pause/hop, plus
merman fall/walk/spit, hanging bat hang/swoop/bob, skull pile idle/windup/recover).
Breakable
walls named (`block_stamp` / `block_save_under` / restore; C470 kind 3).
Candle blob named (`actor_blob_blue` / `_red` / `_white`; hatch `blob_hatch_type`;
sprites `spr_blob` / `spr_blob_cc`; sheet **1A/1B/1C**). Dracula `ix+1` and torso
blit named (`dracula_save_bg` / `dracula_blit_torso`; 32x32s are packed
4bpp `dracula_body_closed`/`open` at page-1 Y=0x80). Portrait eye/mouth
16x16s are `dracula_portrait_parts` at Y=0xA0.
s18r9 collision uses event-6 threshold 6 (`tile_is_solid` l7c7ah). Leftover
fake `DISPATCH_A`
in-lines converted to `defw` (seg1 `sub_6875h` / 0x6AB4). Seg2 hit-class
named: `hit_class_c800` / `_shot` tables, `actor_vs_*` / `shot_vs_*`,
`overlap_simon` / `_whip` / `_projectile` / `_shield`. Shot ticks named
(`fireball`, `medusa_snake`, `mummy_bandage`, `shot_sickle`, `shot_axe`, `shot_bone`);
kind table `shot_kind_type`.

Seg3 boss events 1–6 named: `event_giant_bat` / `event_medusa` /
`event_mummies` / `event_frankenstein` / `event_grim_reaper` /
`event_dracula`, plus their CE01 steps, `ix+1` machines (bat, medusa,
mummy, Frank/Igor, grim), `aim_at_simon`, `event_ce01_next`,
`boss_clear_arm`. Ending credits still: last `event_dracula` step raises
CE40; `credits_tick` (0x66C1) plays `cr` strings (seg8 story + seg5 staff;
**HUMANBEINGS** spelling, `LET;S` apostrophe). Other bosses skip this and
use `room_event_ce10` → C409.

1. Sprites/graphics: playfield tilesets mapped. `load_stage_tileset` (0x5653)
   blits `tileset_ptr[D000]` (0xBF uncompressed 8x8 4bpp tiles) to VRAM 0x8004.
   8 unique sources (hubs of 3 stages; s0 and s18 unique). `make gfx` writes
   `gfx/tileset_s00.png` … `tileset_s18.png`. Pixel room sheets:
   `tools/roomperm.py --all --pixels` → `gfx/stage_sNN.png` (nametable
   id N = ROM tile N−1, id 0 blank; HUD rows cropped). Banks 4–8 are labeled
   source (`tileset_s00`..`s18`). Packed Simon/intro RLE is `segments/data/simon_rle.asm`
   / `intro_sky.asm`. Seg9/10 are labeled (`room_gfx.asm`, `enemy_sprite_rle.asm`,
   palettes). Seg15 is labeled (`psg_seg15.asm`, `dracula_portrait.asm`).
   `actor_tick_tbl` now uses `enemy_*_go` / `merman_go` / `hanging_bat_go`
   mid-entries (spawn stays `enemy_*_tick`). `vendor_outcome_tbl` converted.
2. Convert the tile-layout block `0x4C3F-0x4D0E` in seg00 from misdisassembled
   "code" to `db` data - DONE (`l4c3fh` / `l4c5ah` / `l4ca0h` + `tile_layout_draw`).
3. Annotate the in-game state handlers in `main_tick`: 0-13 named.  8 =
   `state_hub_advance` (0xC409 from boss-clear / credits: 0xD002++ then
   `advance_stage`; hub wrap is game-complete / second loop).  11 =
   `state_pause` (F1 sets 0xC40A; play tick freezes; F1 resumes).
   Player-stats block 0xC400-0xC41F mapped (see game-notes); `run_seed_tbl`
   / `add_score_c0` split out of fake `l44f0h` code.
4. Annotate the seg1 player routines the movement trace located - DONE:
   `simon_walk_left/right`, `simon_add_x`, `simon_jump_*`, `simon_mirror_frames`,
   `whip_tick` / `simon_attack_tick`, action-state handlers 0-6 named.
   Play-loop tail in `play_tick` named: `room_event_tick`, `actors_tick`,
   `shot_tick`, `vendor_tick`, `pickup_tick`, `break_spark_tick`,
   `hazard_tick`, `platform_tick`, SAT build/emit, `frame_vram_refresh`.
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
     * stage 18 room 9 (Dracula) - event-6 `tile_is_solid` threshold 6 (ids
       1-6). `roomperm.py` uses that for perm and `--collision`; no overlay.
     * Type 17 (figure Dracula) on `enemy_sheet.png`: SAT head+cape plus the
       32x32 cloak from `dracula_body_closed` (page-1 Y=0x80,
       `dracula_blit_torso`). Portrait closed-mouth 16x16s at Y=0xA0 are
       the wall painting, not the figure.
     * stage 6 room 5 - RESOLVED: leftover white speck was a lone body-09 (the
       old "errant 0c" was already gone with the 06/07 decoration rule).
     * stage 15 rooms 6-9 - RESOLVED for solids (lone 09 next to wallpaper);
       remaining 0c/0d are real climbable stairs, left amber.
     * stage 10 rooms 2/3/4/6/7/8 - RESOLVED: wallpaper 06/07 next to body 09
       was counted as a surface, so the 09 sparkled as solid.  01-04-only
       adjacency clears it.
     * stage 17 - RESOLVED by the 0c/0d-only rule (false stairs were 06/07);
       leftover 09 specks in rooms 7/10 cleared by the 01-04 adjacency rule.
     * stage 0 room 2 gate - 09/0b specks next to decoration also cleared;
       inaccessible 0c/0d in the gate stay amber (real stair ids).
   - Tile-class errata for the permeability sheets are settled (01-04 body
     adjacency + 0c/0d stairs).  Seg14 list-ids named and the spawn-mask /
     object-list tables graduated from INCBIN (`scenery_list_ptr`,
     `spawn_bitmask_ptr`, `object_list_ptr` in `segments/seg14.asm`). The rest of
     the bank is now source too: `credits_font` / `sound_tick` / `sfx_tbl` /
     `music_ptr`, with packed PSG streams as labeled hex (some music tails
     in seg15).  `collect_bonus_tbl` ids are annotated in seg02.

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
  0xC010..C016 music A/B/C + sfx tick pointers (word); 0xC018/C01A = 0xFB/0xFD
         overlays.  20-byte channel blocks: C01C/C030/C044 music, C058 sfx,
         C06C 0xFB, C080 0xFD.  C094 = current PSG ch, C095 = slot, C096 =
         current sfx id, C097 = AY mixer shadow, C098 bit0=FD / bit1=FB,
         C0A5/C0A6 fade (play_sound 0xFF), C0A7 live-channel bits, C0A8 sfx lock.
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
         add:  seg0 0x4596 add a,b/daa/clamp99;  spend-5: holy_water_use 0x7154
         and hourglass_use 0x7166, each sub 5/daa).  Confirmed +1 small heart, +5 large heart.
  0xC410 LIVES, packed BCD (drawn by seg0 sub_4575h -> VRAM 0xE400); held at
         0x02 for the whole courtyard run (no death/1-up)
  0xC006 newly-pressed buttons (rising edge of 0xC007 via input_edge).  Bit 4 =
         SPACE/trig (whip), bit 5 = UP (jump and portal).
  0xC007 held buttons: bit0=UP bit1=DOWN bit2=LEFT bit3=RIGHT (read_buttons).
  0xC41B pending room-exit: 1=up 2=down 3=left 4=right, or 0xFF = spot warp.
  0xC425 Simon Y  0xC426/27 Simon X  0xC42C facing(0=R/1=L)  0xC428 jump phase
  0xC439 standing-on-moving-platform (nonzero = C598 slot id; `platform_tick`
         / `simon_grounded` carry Simon's X).
  0xC5AC door sub-state: loader 0xFF (vertical: blit closed graphic) or 0x04
         (courtyard); then 1 = armed, 3 = open.  0xC5AD = door pixel Y, 0xC5AE =
         door pixel X (from door_tbl; confirmed vs Simon Y/X and VDP SAT order).
  0xC5B1 spot armed (1) / 0xC5B2 = spot Y / 0xC5B3 = spot X / 0xC5B4 = dest room
         nibble from spot_tbl.  Play-verified: crouch on pad + UP -> state 7
         (`simon_portal_wait`) -> C41B=0xFF -> conn_from_spot writes C5B4 to D001.
         Table currently stage 12 only (two-way pairs).
  0xC422 whip phase  0xC429 whip timer  0xC42E/2F anim frames (scratch)
  Damage/knockback (zombie-hit before/after + two during-blink captures):
    0xC42D INVULN/BLINK timer, starts 0x4e=78, -1 per frame (verified against
      0xC003: 35 frames elapsed = 35 counts); blink ends at 0.  Reused as the
      portal wind-up (simon_crouch sets 0x40, simon_portal_wait waits it out).
    0xC420 action state ->5 (hurt), 0xC423 ->1 hurt/invuln flag, 0xC42C facing,
      0xC42E/2F hurt-anim frames - all cleared to 0 on recovery.
    0xC42A knockback velocity/impulse (0->0b->0d->0, NOT the timer).
    knockback throws Simon back (0xC427 X down) and up (0xC425 Y down, restored
      to 0xC0 ground on recovery).
  0xC450-C46F whip sprite buffer
  0xC470 block: destructible scenery (candles **and** 32×32 wall blocks),
         stride 0x10, 8 slots.  +00 state (1 first frame / 2 present / 0 gone);
         +01 Y +02 X; +03 hit; +04 kind (0 castle candle, 1 courtyard, 3 4x4
         block); +05 bonus id; +07/+08 E000 pos ptr.  First tick saves D100
         under the slot (E480/E4A0) and stamps brick tiles for kind 3.
  0xC500 floor pickups/chests: 8 slots, stride 0x10 (`pickup_tick`).
  0xC580 spike bars: 3 x 8 bytes (`hazard_tick`; `hurt_simon_spikes`
         overlap, 32x8 box). Stage 6 room 1 only - the pool holds nothing else.
         +0 state 1=descending/2=retracting, +1 Y, +2 X, +3 descend rate mask,
         +4 tick, +5 steps per sweep, +6 step count.  Drawn as a 32x16
         background block from page 1 (0x80,0x70); see game-notes "Spike bars".
  0xC598 moving platforms: 2 x 7 bytes (`platform_tick`; table `platform_tbl`
         stages 5 and 10). SAT at 0xD638/0xD648, colours 0xD4E0/0xD520.
         +0 slot id, +1 Y (fixed), +2 X (moves), +3 signed step, +4 span,
         +5 free tick, +6 sweep count.  32x16 deck = 4 SAT cells, two CC pairs
         (colours 2/4 on stage 5, 9/0xC on stage 10).  +5/+6 are skipped by
         platform_load because actor_state_reset already zeroed 0xC470-0xC6FF.
         See game-notes "Moving platforms".
  0xC5A6 whip-break sparks: 2 x 3 bytes (`break_spark_tick`).
  0xC800 actor slots: 7 slots, stride 0x80 (0xC800, 0xC880, … 0xCB80). Same
         0x80-byte layout as the 8 D700 shot slots. Allocated by `spawn_actor`
         (seg0 0x5F24); SAT helpers `actor_sat_patterns` / `actor_sat_assign`.
         Field table is in game-notes "Actors (C800 / D700)". Shared header:
           +00 type (0=free), +01 sub-state,
           +02/+03 Y frac/pixel, +04/+05 X frac/pixel,
           +06 physics alive, +07/+08 Y vel, +09/+0A X vel,
           +0B pose (seg6 0xB473), +0C timer, +0D HP (`actor_hp_tbl`),
           +0E flags (bit0 hittable, bit2 rearm), +1F drop gate,
           +20 SAT count then 5-byte cells (index, Y, X, pattern, colour),
           +7E freeze-with-whip. Hardware SAT is Y then X, so pixel Y is +03
           and pixel X is +05 for every type (the F8 dog "+02/+03 = X" note
           was a mis-index of Y).
         Heart drop chain (runtime, slot 0xC880): candle whip -> type 0x1E
         flame (stationary flicker 0x85/0x86, +0C countdown) -> type 0x24
         small heart if +1F set -> pickup (+1 heart). Large heart is a
         different C800 orb->drop path (+5 hearts).
  0xD000 stage row/flag  0xD001 room index (seg13 0xB98A)  level change = seg0
         0x4362/65
  0xD700 shot slots: 8 slots, stride 0x80, same actor struct as C800. Enemy-
         spawned flyers (fireballs, bones, axes, sickles, snakes,
         bandages) plus the death flame (type 12 / kind 0xFF). Ticked by
         `shot_tick`. Not Simon's thrown weapons (C450/C460 `projectile_*`)
         and not the 3-slot C580 spike-bar pool.

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
  BIOS names live once in `segments/bios.inc`; actor type ids in
  `segments/actors.inc`; routine names go in `segments/msx.sym`.
- Identified binary data (standing practice): dump known blobs to labeled
  `defb` (`tools/emit_identified_data.py` -> `segments/data/` and tileset
  banks), Metal Gear style. 4bpp tiles are hex `defb` pixel-rows. Identified
  uncompressed 1bpp sheets (`hud_font`, `credits_font`, `logo_font`) use
  `defb %xxxxxxxx` (MSB=left, one row per line) — extract as soon as the
  sheet is found; do not leave them as hex in a leftover dump. Packed sprite
  RLE uses `%` pixel rows (counts stay hex). PNG contact sheets label hex
  tile ids, not ASCII chars.
  PNG/`rleenc.py` is preview/modding, not the assemble source (packer is not
  byte-exact). Unidentified leftover slices are labeled
  hex once a bank is off `.bin`. Do not mass-convert a whole unknown bank to
  opaque `db`.
- File placement (STANDING PRACTICE): all hand-authored disassembly metadata lives
  in `segments/` (`bios.inc`, `actors.inc`, `msx.sym`, `seg*.blocks`) - anything
  needed to reassemble or to regenerate the disassembly faithfully. `tools/` is
  executable tooling only; `generated/` is gitignored derived scratch (never author
  there). How they're consumed: `bios.inc` and `actors.inc` are `INCLUDE`d by the
  build (symbol equates, not emitted); `msx.sym` is the name catalog,
  `seg*.blocks` the code/data maps. `regen-seg.sh` runs `tools/seg_sym.py` so
  z80dasm `-S` gets a *per-bank* view of `msx.sym` (flat file, banked ROM).
  `bios.inc` and `msx.sym` overlap
  - keep them in sync.  Do **not** put small numeric `equ`s (`actor_zombie: equ
  0x01` and friends) in `msx.sym` — z80dasm would rewrite every `0x01` in listings.
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
  draw_enemy_meter, restore_health/damage_health/spawn_actor(+_init),
  advance_stage, room_map_build, zombie_generator, merman_generator,
  merman_generator_3, hanging_bat_generator, flying_skull_generator, ghost_head_generator,
  roc_generator, door_blit_tiles, read_buttons, input_edge, play_sound,
  frontend_input, frontend_to_title, frontend_game_start,
  the Game Master cluster (game_master_detect/_sig, gm_scan_expanded, gm_sig_cmp,
  gm_pause_check, gm_psg_save_mute/_mute/_restore, gm_continue_text/_key,
  gm_menu_draw/_clear/_text/_move, gm_box_clear, gm_prompt_stage/_player/_draw/_clear,
  gm_stage_text, gm_player_text, gm_digit_entry, gm_digit_read, gm_bit_to_digit,
  gm_bcd_to_bin, gm_confirm_key, gm_apply_values, gm_stage_hub_tbl,
  gm_cursor_erase/_draw/_blit/_y, state_game_master_menu),
  credits_font_load, credits_font_blit, hud_font_load, logo_font_load, load_weapon_sprites, load_vdoor_sprites,
  gfx_script_run, gfx_script_rle, gfx_script_copy, gfx_script_convert, room_gfx_load,
  load_stage_tileset, tileset_ptr, dracula_portrait_load,
  dracula_portrait_palette, main_tick, play_tick, rle_dec, rle_dec_addr,
  vram_write, vdp_set_write, vdp_set_read, palette_set, palette_apply,
  video_init, page_play_banks, page_map_banks, page_title_banks,
  page_tileset_banks, page_tileset_late, page_sound_banks, palette_hud_load,
  vdp_cmd_wait, vdp_status_read, vdp_line_h/_v (+ _save), vdp_box, vdp_hmmv,
  vdp_hmmc, vram_blit_tile8/_tile16/_tile_run, glyph_blit, glyph_blit_run,
  glyph_expand_4bpp, tile_atlas_pos, blit_advance_x, hud_draw_all,
  draw_stage_hud, hud_panel_frames, hud_bars_redraw, health_bar_redraw,
  health_bar_frame, enemy_meter_frame;
  seg1: simon_action_tick, simon_walk_left/right, simon_jump_tick, simon_mirror_frames,
  simon_crouch, simon_stairs, simon_fall, simon_hurt, simon_dying,
  simon_portal_wait, simon_attack_tick, whip_tick, projectile_tick,
  knife_tick, cross_tick, axe_tick, tile_layout_draw, holy_water_use,
  holy_water_tick, map_cell_at, tile_is_solid, row_solid_thresh,
  set_stage_boundary, door_interact, door_try_open, door_open_walk,
  hourglass_use, stage_bgm_tbl, stage_bgm_play, stage_bgm_change,
  event_vscroll, credits_tick, credits_init, credits_frame, credits_clock,
  credits_keyframe, credits_script_ptr, credits_wipe, player_tick, simon_sat_build, simon_sat_cell0/1, combat_tick,
  title_fill_strips, title_set_color2, title_sat_init, actor_sat_build,
  actor_sat_emit, c800_sat_build/emit, shot_sat_build/emit, frame_vram_refresh,
  object_list_load/unpack/lookup/clear, tile_string_draw, cell_event_set,
  actor_state_reset, mem_clear_stride, simon_block_clear, sprites_hide,
  simon_spawn_pos, pattern_phase_upload, pattern_shadow_blit, room_edge_detect;
  seg2: door_proximity, door_anim_tick, door_begin_open, spot_proximity,
  collect_bonus_tbl, bonus_holy_water, yellow_shield_tick, projectile_hit_actors,
  actor_vs_whip/simon/proj, shot_vs_simon/proj/shield/whip, overlap_simon/whip/projectile/shield,
  lose_weapon, shot_throw, shot_spawn, shot_alloc, shot_bone, shot_tick,
  shot_type_tick, fireball, medusa_snake, mummy_bandage, shot_axe, shot_sickle,
  actors_tick, c800_tick, pickup_tick, vendor_tick, break_spark_tick,
  hazard_tick, hurt_simon_spikes, spike_bar_overlap,
  spike_bars_seed_once, spike_bars_seed, spike_bar_seeds,
  spike_bars_run, spike_bar_slot_tick, spike_bars_restore,
  platform_tick, platform_load, platform_tbl, platform_move,
  platform_sat_build, platform_sat_cells, platform_sat_ofs, platform_fill16,
  platform_stand_test, platform_overlap (seg1: platform_carry_simon),
  actor_type_tick, actor_tick_tbl, vendor_outcome_tbl, vendor_hit_latch,
  vendor_leave, award_kill_score, collect_bonus_apply, inv_or_c701/c702,
  hud_weapon_icon, hud_bonus_refresh, spawn_rate_gate, spawn_pick_pos,
  minimap_build, minimap_room_pos, minimap_stage_ptr, minimap_room_count;
  seg3: room_event_tick, shot_kind_type, mummy_bandage_init, shot_sickle_init, shot_axe_init,
  enemy_zombie_tick, enemy_dog_tick, enemy_merman_tick,
  enemy_hanging_bat_tick, enemy_flying_skull_tick, enemy_ghost_head_tick,
  enemy_roc_tick, enemy_pikeman_tick, enemy_raven_tick, enemy_skull_pile_tick,
  enemy_hunchback_tick, enemy_bone_dragon_tick, enemy_red_skeleton_tick,
  enemy_white_skeleton_tick, white_skel_set_pose, white_skel_walk,
  white_skel_air, white_skel_throw, enemy_raven_go, raven_wait, raven_coast,
  raven_hover, raven_pick, raven_strafe_init, raven_strafe, raven_recover,
  raven_hold, enemy_dog_go, dog_idle, dog_run, dog_air, enemy_bone_dragon_go,
  bone_dragon_follow, bone_dragon_form, bone_dragon_idle, bone_dragon_spit,
  enemy_red_skeleton_go, red_skel_wake, red_skel_walk, red_skel_pause,
  hunchback_wait, hunchback_drop, hunchback_crouch, hunchback_jump,
  hunchback_hide, blob_hatch, blob_fall, blob_pause, blob_hop, merman_fall,
  merman_walk, merman_spit, hanging_bat_hang, hanging_bat_swoop,
  hanging_bat_bob, enemy_skull_pile_go, skull_pile_idle, skull_pile_windup,
  skull_pile_recover, enemy_axe_knight_tick, enemy_dracula_tick,
  enemy_giant_bat_tick, enemy_medusa_tick, enemy_mummy_tick,
  enemy_frankenstein_tick, enemy_grim_reaper_tick, enemy_placed_merman_init,
  enemy_placed_bat_init, event_giant_bat, event_medusa, event_mummies,
  event_frankenstein, event_grim_reaper, event_dracula, event_ce01_next,
  boss_clear_arm, aim_at_simon, room_event_ce10, boss_clear_cull, boss_clear_wait,
  boss_clear_orb, boss_clear_orb_wait, boss_clear_heal, boss_clear_done;
  seg13: conn_lookup, conn_load_permits, conn_room_record, conn_ptr, door_load,
  door_load_coords, door_tbl, spot_load_coords, spot_tbl, simon_cell0_ptr,
  simon_cell1_ptr, intro_simon, intro_sky, logo_font, logo_font_ink2,
  logo_font_ink3;
  seg11/12: mtile_rowbase, mtile_roomptr, mtile_stream_c41a, mtile_streams,
  mtile_defbase, mtile_defs_s00..s18, mtile_def_c41a.
  tilesets: tileset_s00..s18 (in-source; s00/s13 omitted from msx.sym — CPU
  window collides with mtile_rowbase / scenery_list_ptr), hud_weapon_key_tiles,
  title_logo_jp_tiles, title_logo_en_tiles, title_castle_tiles, hud_font,
  hud_font_solid, hud_tile_bf00, logo_font, logo_font_ink2, logo_font_ink3.
  seg14: scenery_list_ptr, scenery_list_s00, scenery_list_h0..h5,
  spawn_bitmask_ptr, spawn_mask_s00..s18, object_list_ptr,
  object_list_h0..h5, credits_font, credits_font_az, sound_tick, sound_idle,
  sound_ch_a/b/c, sound_sfx, sound_cmd_*, sound_sfx_*, sfx_ptr, sfx_tbl, music_ptr.
  Actor type `equ`s: `segments/actors.inc` (`actor_zombie`..`actor_pickup`,
  `obj_next_room`/`obj_end_stream`); used in the packed object list and confirmed
  `spawn_actor` `ld c` sites.
- After any edit, run `make verify` before moving on.
- Reusable methodology (for disassembling OTHER Konami MSX games later) lives in
  workspace skills at `.agents/skills/` (`konami-msx-disasm`, `msx-runtime-tracing`).
  When we discover a generally-useful pattern/tool/gotcha, fold it into those skills
  (keep them lean - they load every session) and keep VK-specific findings here.

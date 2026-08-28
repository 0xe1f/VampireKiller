; ===========================================================================
;  banks 0-3 - 32K play window @ 0x4000-0xBFFF.
;  Bank 0 is always mapped at 0x4000 (header, IRQ, bank switchers, main loop).
;  Banks 1-3 are paged by page_play_banks at 0x6000 / 0x8000 / 0xA000.
;  One PHASE from 0x4000; entity_tbl straddles 0x5FFF -> 0x6000.
;  Regen one 8K bank at a time:
;    tools/disasm/regen-seg.sh 0 0x4000 segments/seg00.blocks
;    tools/disasm/regen-seg.sh 1 0x6000 segments/seg01.blocks
;    tools/disasm/regen-seg.sh 2 0x8000 segments/seg02.blocks
;    tools/disasm/regen-seg.sh 3 0xA000
;  BIOS names from bios.inc (included by VampireKiller.asm).
; ===========================================================================

; --- 16-byte MSX cartridge header (ROM offset 0) ---------------------------
;   +0  "AB"      magic identifying an MSX ROM cartridge
;   +2  init      entry point called at boot           -> 0x4075
;   +4  STATEMENT expansion BASIC statement handler    -> none (0)
;   +6  DEVICE    expansion device handler             -> none (0)
;   +8  TEXT      BASIC program pointer                -> none (0)
;   +10 reserved (6 bytes, 0)
rom_header_start:
	defb 041h               ; 'A'  cartridge magic
	defb 042h               ; 'B'
	defb 075h               ; init lo  \ entry = 0x4075
	defb 040h               ; init hi  /
	defb 000h
	defb 000h
	defb 000h
	defb 000h
	defb 000h
	defb 000h
	defb 000h
	defb 000h
	defb 000h
	defb 000h
	defb 000h
	defb 000h
rom_header_end:

; BLOCK 'gm_opt_tbl' (start 0x4010 end 0x4028)
;  Game Master relative-format option table.  Compact CD games store
;  'C','D',7,RC as four bytes so GM's word compare at 0x4010 sees 0x4443.
;  VK wrote those as words (extra 0x00), so the word is 0x0043 and Game
;  Master 1 never parses this table — VK is also absent from GM's 0x5000
;  checksum list.  The payload still names the RAM the in-game GM menu
;  writes: 0xC411 (HUD STAGE), 0xD000 (stage, max 18), 0xC410 (lives),
;  plus 0xC405 (score).
gm_opt_tbl:
	defw 00043h             ; 'C' as word; GM1 wants 0x4443
	defw 00044h             ; 'D'
	defw 00007h             ; 7
	defw 00044h             ; BCD 44 (RC last-two; catalog is RC-745/749)
	defb 0e8h,000h          ; option flags 0xE8 + pad
	defb 0c0h,004h,000h     ; remnant of a 0xC000 / max-4 stage slot
	defw 0c411h             ; HUD STAGE
	defb 000h
	defb 0d0h,012h          ; STAGE 0xD000, max 18 (as 00 D0 12)
	defw 0c410h             ; LIVES
	defb 000h,000h,005h,0c4h ; SCORE 0xC405
; ===========================================================================
;  int_handler - timer interrupt (H.TIMI hook, installed by init at 0xFD9F).
;  Runs once per VDP frame: PSG tick (`sound_tick` in segs 14/15), then
;  the game tick.  0xC005 bit0 skips a frame if the previous tick is still
;  running.  0xE600 is the Game Master detection flag, not a re-entrancy flag:
;  when set, gm_pause_check gets first look at the keyboard (STOP pause / ';'
;  frame advance) and then usually falls into int_tick anyway.
; ===========================================================================
int_handler:
	di
	ld a,(0e600h)           ; Game Master cartridge present?
	or a
	jp nz,gm_pause_check    ; yes -> pause/frame-advance keys get first look
int_tick:
	di
	ld a,00eh               ; page segment 14...
	ld (08000h),a           ; ...into 0x8000-0x9FFF
	ld a,00fh               ; page segment 15...
	ld (0a000h),a           ; ...into 0xA000-0xBFFF
	call sound_tick         ; per-frame PSG driver (seg14; segs 14+15 paged)
	di
	ld a,(0f0f2h)           ; restore game's page-2 segment...
	ld (08000h),a           ; ...(0f0f2 = current seg at 0x8000)
	ld a,(0f0f3h)           ; restore game's page-3 segment...
	ld (0a000h),a           ; ...(0f0f3 = current seg at 0xA000)
	ld hl,0c005h            ; soft guard: game-tick-in-progress flag
	bit 0,(hl)
	jp nz,int_tick_done            ; tick still running -> skip this frame
	inc (hl)                ; mark tick in progress
	ei
	call 04ba4h             ; input / timers update
	call main_tick          ; MAIN TICK (top-level state machine)
	xor a
	ld (0c005h),a           ; clear tick-in-progress flag
int_tick_done:
	ei
	ret
; ADD_HL_A - HL += A (unsigned), carry into H.  Indexes byte tables.
ADD_HL_A:
	add a,l
	ld l,a
	ret nc
	inc h
	ret
; ADD_DE_A - DE += A (unsigned), carry into D.
ADD_DE_A:
	add a,e
	ld e,a
	ret nc
	inc d
	ret
; DISPATCH_A - jump-table dispatch on A.  The word table is inlined right
; after the `call`; jumps to table[A].
DISPATCH_A:
	pop hl                  ; HL = address of inline word table
	add a,a                 ; A *= 2 (word index)
	call ADD_HL_A           ; HL += A -> &table[A]
	ld e,(hl)               ; DE = table[A]
	inc hl
	ld d,(hl)
	ex de,hl
	jp (hl)                 ; jump to selected handler
; ===========================================================================
;  init - cartridge entry point (from header +2).  Called by the BIOS at boot:
;  find this ROM's slot, page it into CPU page 2 (0x8000-0xBFFF), clear RAM,
;  init subsystems, install the interrupt hook, then idle - the game then runs
;  entirely from int_handler.
; ===========================================================================
init:
	di
	ld sp,0f0f0h            ; stack near top of RAM
	call RSLREG             ; A = primary slot select register
	rrca                    ; rotate page-2 slot bits (6,7)...
	rrca                    ; ...down to bits 0,1
	and 003h                ; C = this cartridge's primary slot #
	ld c,a
	ld b,000h
	ld hl,0fcc1h            ; EXPTBL: is that primary slot expanded?
	add hl,bc
	ld a,(hl)
	and 080h                ; bit7 = slot is expanded
	or c
	ld c,a                  ; C = slot id (primary + expanded flag)
	inc hl                  ; advance EXPTBL(0xFCC1) -> SLTTBL(0xFCC5)
	inc hl
	inc hl
	inc hl
	ld a,(hl)               ; SLTTBL: last value written to slot reg
	and 00ch                ; keep page-2 secondary-slot bits
	or c                    ; full slot id for ENASLT
	ld h,080h               ; H = 0x80 -> target CPU page 2 (0x8000)
	call ENASLT             ; page this ROM into 0x8000-0xBFFF
	ld hl,0c000h            ; clear work RAM 0xC000..0xF0EF:
	ld de,0c001h
	ld bc,030efh            ; length 0x30EF
	ld (hl),000h
	ldir                    ; (hl)=0 then propagate via LDIR
	call page_play_banks          ; init subsystem
	call game_master_detect ; E600=0xFF if a Game Master cartridge is plugged in
	call page_play_banks
	call video_init          ; init subsystem
	di
	ld a,0c3h               ; opcode for JP
	ld (0fd9fh),a           ; install timer-interrupt hook (H.TIMI)...
	ld hl,int_handler       ; ...JP int_handler (0x4028)
	ld (0fda0h),hl
	xor a
	ld (0f3dbh),a
	ei                      ; interrupts on: game now runs from the tick
l40c3h:
	jr l40c3h               ; idle forever; work happens in int_handler
; ===========================================================================
;  gm_pause_check (0x40C5) - the Game Master cartridge's pause / frame-advance
;  cheat, reached from int_handler only when 0xE600 is set.  Two edge-detected
;  keys (latched through 0xE610):
;    STOP (row 7 bit 4) toggles pause.  0xE601 holds the pause state; entering
;      pause saves the three PSG volume registers and silences them, then
;      returns without running main_tick, freezing the game mid-frame.
;    ';'  (row 1 bit 7) while paused runs exactly one tick and stays paused,
;      i.e. frame-by-frame stepping.
;  Not paused and STOP not pressed -> falls straight through to the normal tick.
; ===========================================================================
gm_pause_check:
	ld a,007h               ; scan keyboard matrix row 7...
	call SNSMAT
	cpl
	and 010h                ; ...bit 4 = STOP
	ld b,a
	ld a,001h               ; scan row 1...
	call SNSMAT
	cpl
	and 080h                ; ...bit 7 = ';'
	or b                    ; merge the two key bits
	ld hl,0e610h            ; previous sample (edge latch)
	ld c,(hl)
	ld (hl),a
	xor c
	and (hl)
	ld c,a                  ; C = keys pressed this frame
	ld hl,0e601h            ; pause state
	ld a,(hl)
	or a
	jr nz,gm_paused            ; already paused
	bit 4,c
	jp z,int_tick             ; running, no STOP -> normal tick
	ld (hl),c               ; STOP -> enter pause...
	call gm_psg_save_mute   ; ...silence the PSG and skip the tick
	ei
	ret
gm_paused:                         ; paused
	bit 7,c
	jp nz,gm_pause_step            ; ';' -> single-step one frame, stay paused
	bit 4,c
	jr z,gm_pause_hold             ; nothing pressed -> stay frozen
	xor a
	ld (hl),a               ; STOP again -> leave pause
gm_pause_step:
	call gm_psg_restore
	jp int_tick               ; run one tick
gm_pause_hold:
	call gm_psg_mute        ; hold the PSG silent while frozen
	ei
	ret
; gm_psg_save_mute (0x4107) - stash PSG volume registers 8-10 in 0xE611-0xE613,
; then fall through and silence them.
gm_psg_save_mute:
	ld a,008h
	call RDPSG
	ld (0e611h),a
	ld a,009h
	call RDPSG
	ld (0e612h),a
	ld a,00ah
	call RDPSG
	ld (0e613h),a
gm_psg_mute:
	ld e,000h
	ld a,008h
	call WRTPSG
	ld e,000h
	inc a
	call WRTPSG
	ld e,000h
	inc a
	jp WRTPSG
gm_psg_restore:
	ld a,(0e611h)
	ld e,a
	ld a,008h
	call WRTPSG
	ld a,(0e612h)
	ld e,a
	ld a,009h
	call WRTPSG
	ld a,(0e613h)
	ld e,a
	ld a,00ah
	jp WRTPSG
; ===========================================================================
;  main_tick - MAIN TICK / top-level game state machine.  Called once per
;  frame from int_handler.  Two-level state:
;     0xC000 = primary state  (C) -> selects a handler from main_state_tbl
;     0xC001 = secondary state (B) -> sub-phase, read by the `djnz` ladders
;              inside each handler (each `djnz` skips one sub-state).
;     0xC003 = free-running frame counter (bumped every tick).
;  For the three front-end states (0..2: logo / title / attract) the shared
;  post-handler frontend_input (0x4398) is pushed as a return address so it
;  runs after the handler: any press on logo/attract returns to the title;
;  SPACE/TRG1 or TRG2/UP on the title starts the game (or opens the Game Master
;  menu if E600 is set).
; ===========================================================================
main_tick:
	ld hl,0c003h            ; frame counter...
	inc (hl)                ; ...++
	ld bc,(0c000h)          ; C=primary state, B=secondary state
	ld a,c
	cp 003h                 ; front-end states 0..2?
	jr nc,l415eh            ; no -> in-game, skip post-handler
	ld hl,frontend_input    ; yes -> run front-end post-handler...
	push hl                 ; ...after the state handler returns
l415eh:
	call DISPATCH_A         ; jump to main_state_tbl[primary state]

; main_state_tbl - primary game-state handlers (indexed by 0xC000).
; Front-end trio (0..2) = logo -> title -> attract.  Runtime trace of a fresh
; start walked 1 -> 3 -> 4 -> 5.  State 5 (play) reads the game-event flags to
; pick 6..13: death, game-over, room/stage transitions, vendor, game-start.
main_state_tbl:
	defw state_logo             ; 0  Konami logo
	defw state_title            ; 1  title screen
	defw state_attract          ; 2  attract / demo
	defw state_intro            ; 3  intro cutscene (timed via 0xC004)
	defw state_stage_bridge     ; 4  build first/next stage, enter play
	defw state_play             ; 5  in-stage play + next-state select
	defw state_death            ; 6  lives left -> respawn (state 4); else game-over
	defw state_game_over        ; 7  draw GAME OVER (l4d41h)
	defw state_hub_advance      ; 8  from 0xC409 (boss-clear / credits): hub++ then advance_stage
	defw state_room_trans       ; 9  pending exit 0xC41B: conn_lookup_paged then back to play
	defw state_stage_exit       ; 10 from 0xC408: spend white key, advance_stage
	defw state_pause            ; 11 from 0xC40A: F1 freeze; F1 again resumes play
	defw state_vendor           ; 12 from 0xC40C: vendor offer / purchase
	defw state_game_master_menu ; 13 from title start (A=0x0D): Game Master menu
main_state_tbl_end:
state_logo:                    ; 0 (0x417D)
	djnz l418ah
	call konami_logo_step   ; wipe the Konami logo in one more row (seg1)
	ld a,(0c422h)           ; 0xC422 set once the reveal has finished
	or a
	ret z
	xor a
	jr main_timer_set
l418ah:
	djnz l4198h
	ld hl,0c004h
	dec (hl)
	ret nz
	call title_build
	xor a
	jp main_state_inc
l4198h:
	call video_reset
	call konami_logo_draw   ; draw Konami logo + start the top-to-bottom wipe (seg1)
	jr main_phase_next
state_title:                   ; 1 (0x41A0): idle until C004==0, then attract
	ld hl,0c004h
	dec (hl)               ; first entry C004=0 wraps to 0xFF (~4s @ 60Hz)
	ret nz
	call title_set_color2
	jp main_state_inc_20              ; C004=0x20, inc C000 -> state 2 attract
state_attract:                 ; 2 (0x41AB)
	djnz l41c1h
	call attract_tick
	ld a,(0c413h)
	or a
	ret nz
main_state_set_0:
	xor a
main_state_set:
	ld (0c000h),a
	ld a,020h
	ld (0c004h),a
	jp main_phase_reset
l41c1h:
	call video_reset
	call attract_run_init
	ld a,020h
main_timer_set:
	ld (0c004h),a
main_phase_next:
	ld hl,0c001h
	inc (hl)
	ret
state_intro:                   ; 3 (0x41D1)
	djnz l41e4h
	ld hl,0c004h
	dec (hl)
	jr z,main_phase_next
	bit 2,(hl)
	ld hl,l4d30h
	jp z,hud_string_draw
	jp hud_string_masked
l41e4h:
	djnz l41ech
	call reset_run_state   ; wipe run work RAM (0xC405..0xDFFF) + seed defaults
	jp main_phase_next
l41ech:
	djnz l41fbh
	ld a,001h
	ld (0c41ah),a          ; intro: use mtile_stream_intro
	call intro_scene_build
	ld a,0a0h
	jp main_timer_set
l41fbh:
	djnz l4222h
	call intro_actors_frame
	ld hl,0c004h
	ld a,(0c003h)
l4206h:
	rra
	ret c
	dec (hl)
	ret nz
	call sat_vram_hide
	xor a
	ld (0c41ah),a          ; intro map stream off
	call 062d7h
	ld hl,0e604h
	ld a,(hl)
	or a
	jr z,l4220h
	ld (hl),000h
	call gm_apply_values
l4220h:
	jr main_state_inc_20
l4222h:
	ld a,08ah
	call play_sound
	ld a,050h
	jp main_timer_set
state_stage_bridge:            ; 4 (0x422C)
	ld hl,0c410h
	ld a,(hl)
	sub 001h
	daa
	ld (hl),a
	call vdp_screen_off
	call hud_draw_all
	call 062edh
	ld hl,0c413h
	ld (hl),001h           ; stay in play (0 = attract/death leave-play)
	call stage_bgm_play
	xor a
	ld (0c40dh),a          ; clear BGM force-replay (set on death / GM stage jump)
main_state_inc_20:
	ld a,020h
main_state_inc:
	ld (0c004h),a
	ld hl,0c000h
	inc (hl)
main_phase_reset:
	xor a
	ld (0c001h),a
	ret
state_play:                    ; 5 (0x4257)
	call play_tick
	ld a,(0c40ch)
	or a
	ld a,00ch
	jp nz,main_state_set           ; 0xC40C -> vendor
	ld a,(0c40ah)
	and a
	jp nz,pause_enter           ; 0xC40A -> pause
	ld a,(0c41bh)
	and a
	ld a,009h
	jp nz,main_state_set           ; pending room exit (1-4 or 0xFF spot) -> room_trans
	ld a,(0c408h)
	or a
	ld a,00ah
	jp nz,main_state_set           ; stage-boundary -> spend key / advance_stage
	ld a,(0c409h)
	and a
	ld a,008h
	jp nz,main_state_set           ; 0xC409 -> hub_advance
	ld a,(0c413h)
	or a
	ret nz
	jr main_state_inc_20
pause_enter:
	call pause_panel_draw
	ld a,00bh
	jp main_state_set
state_death:                   ; 6 (0x4294): 0xC410 lives? respawn via state 4 : game-over
	ld hl,0c410h
	ld a,(hl)
	or a
	jr z,l42abh
l429bh:
	call 062d7h
	xor a
	ld (0c420h),a
	inc a
	ld (0c40dh),a          ; force stage BGM replay on respawn
	ld a,004h
	jp main_state_set
l42abh:
	ld a,08bh
	call play_sound
	jr main_state_inc_20
state_game_over:               ; 7 (0x42B2)
	djnz l42e3h
	ld a,(0e600h)          ; Game Master cartridge present?
	or a
	jr z,l42bfh            ; no -> plain GAME OVER, fall back to the title
	call gm_continue_key   ; yes -> F5 continues the run
	jr nz,l42d3h
l42bfh:
	ld a,(0c0a7h)
	and a
	ret nz
	ld hl,0c004h
	dec (hl)
	ret nz
	ld hl,0c002h
	ld a,(hl)
	and 0bfh
	ld (hl),a
	jp main_state_set_0
l42d3h:
	ld a,003h
	ld (0c410h),a
	xor a
	ld h,a
	ld l,a
	ld (0c405h),hl
	ld (0c407h),a
	jr l429bh
l42e3h:
	call video_reset
	ld hl,l4d41h           ; "GAME  OVER"
	call hud_string_draw
	ld a,(0e600h)          ; Game Master cartridge present?
	or a
	jr z,l42f8h
	ld hl,gm_continue_text ; yes -> add the "F5 -> CONTINUE" line
	call hud_string_draw
l42f8h:
	call hud_draw_all
	ld a,078h
	jp main_timer_set
; gm_continue_text (0x4300) - extra GAME OVER line, drawn only when a Game
; Master cartridge was detected (see game_master_detect).  Renders as
; "F5 <arrow> CONTINUE": glyph 0x4F is a right-pointing arrow, not "_".
gm_continue_text:
	defb 050h, 068h
	vk "F5"
	defb 0feh
	defb 064h, 068h
	vk "_"                     ; arrow glyph
	defb 0feh
	defb 070h, 068h
	vk "CONTINUE"
	defb 0ffh
; gm_continue_key (0x4314) - edge-detected F5 (keyboard row 7 bit 1), latched
; through 0xE614.  NZ on the frame F5 goes down -> state_game_over restarts the
; run instead of dropping back to the title.
gm_continue_key:
	ld a,007h
	call SNSMAT
	cpl
	and 002h               ; row 7 bit 1 = F5
	ld hl,0e614h           ; previous sample (edge latch)
	ld c,(hl)
	ld (hl),a
	xor c
	and (hl)               ; set only on the press edge
	ret
state_hub_advance:             ; 8 (0x4324): boss-clear/credits set 0xC409; hub 0xD002++ then advance_stage
	djnz l4377h
	ld hl,0d002h
	inc (hl)
	ld a,006h
	sub (hl)
	jr nz,l434bh
	ld (hl),a
	ld a,0ffh
	ld (0d000h),a
	ld a,020h
	ld (0c415h),a          ; Simon health = full (0x20)
	ld hl,0cf34h
	inc (hl)
	ld a,(hl)
	cp 002h
	jr nz,l434bh
	ld hl,0c002h
	res 6,(hl)
	jp main_state_set_0
l434bh:
	call 062dch
; advance_stage (0x434E): move to the next stage.  Bumps the two BCD progress
; counters 0xC410/0xC411, increments the stage id 0xD000, resets the room id
; 0xD001 to 0, clears 0xC408/0xC409, then runs transition type 4 (jp main_state_set).
; (Runtime-confirmed: stage1/room7 -> stage2/room0 on entering a door.)
advance_stage:
	ld hl,0c410h
	ld a,(hl)
	add a,001h
	daa
	ld (hl),a
	ld hl,0c411h
	ld a,(hl)
	add a,001h
	daa
	ld (hl),a
	ld hl,0d000h
	inc (hl)               ; stage id ++
	inc hl
	xor a
	ld (hl),a              ; room id (0xD001) = 0
	ld (0c409h),a          ; clear hub-advance (boss-clear) latch
	ld (0c408h),a          ; clear stage-boundary (white-key door) latch
	ld a,004h
	jp main_state_set
	ld hl,00000h
	ld (0c000h),hl
	ret
l4377h:
	call video_reset
	xor a
	jp main_timer_set
state_room_trans:              ; 9 (0x437E): 0xC41B pending exit
	call conn_lookup_paged
	ld a,006h
	jp nc,main_state_set           ; failed transition -> death
	call 062fch
	ld a,005h
	jp main_state_set              ; back to play
state_stage_exit:              ; 10 (0x438E): 0xC408, spend white key, next stage
	ld hl,0c701h
	ld a,(hl)
	and 0feh               ; clear bit0 = white key spent by the door
	ld (hl),a
	jp advance_stage
; ===========================================================================
;  frontend_input (seg0 0x4398) - front-end post-handler (after logo/title/
;  attract, states 0..2).  Same read_buttons mask as play, but input_edge
;  latches 0xC401 held / 0xC400 new-press (play uses C007/C006).
;    title (1): bits 4|5 only (SPACE/TRG1 or TRG2/kbd UP) start; else ignore.
;      E600==0 -> intro (state 3); E600!=0 -> state_game_master_menu (13).
;    logo (0) / attract (2): any new press -> title_build.
;  No press: state_title counts C004 down into attract (not this routine).
; ===========================================================================
frontend_input:
	call read_buttons       ; A = joystick|keyboard mask
	ld hl,0c401h            ; 0xC401 = title held; 0xC400 = new-press
	call input_edge         ; A = newly-pressed buttons this frame
	or a
	ret z                   ; nothing pressed -> stay in this state
	ld hl,0c004h            ; reset the sub-state timer...
	ld (hl),000h            ; ...(0xC004 = 0)
	ld hl,0c000h            ; HL -> primary state (0xC000)
	ld b,(hl)               ; B = current state
	djnz frontend_to_title  ; state != 1 (logo/attract) -> back to title
	and 030h                ; title: bit4=SPACE|TRG1, bit5=TRG2|kbd UP?
	ret z                   ; other key -> ignore
	ld a,040h
	ld (0c002h),a           ; C002 bit6: run active (score/minimap/start)
	ld a,(0e600h)           ; Game Master cartridge present?
	or a
	jr nz,frontend_game_start ; yes -> the hidden Game Master menu
	ld (hl),003h            ; else C000 = 3 (intro)
	inc hl
	ld (hl),b               ; C001 = 0 (djnz already counted B from 1)
	ret
; state 0 (logo) or 2 (attract) + any press -> return to the title screen.
frontend_to_title:
	ld (hl),001h            ; primary state = 1 (title)
	ld a,000h
	call play_sound          ; request sound/music change
	jp title_build          ; (re)build the title screen
; frontend_game_start (0x43CB) - Game Master path off the title.  Seeds the menu
; fields to their defaults and enters state 13 (state_game_master_menu).
frontend_game_start:
	xor a
	ld (0e604h),a           ; no fields edited yet
	ld a,001h
	ld (0e605h),a           ; stage 1 (BCD)...
	ld (0e606h),a           ; ...and binary
	ld a,003h
	ld (0e607h),a           ; 3 lives
	ld a,00dh               ; A = 0x0D -> state_game_master_menu
	jp main_state_set               ; enter via the state setter
state_pause:                   ; 11 (0x43E1): F1 froze play (0xC40A); wait F1 (0xC00B bit0) to resume
	ld a,(0c00bh)
	rra
	ret nc                 ; still held/not pressed -> stay frozen
	xor a
	ld (0c40ah),a          ; clear pause latch
	call pause_panel_restore         ; restore the blit rectangle paused over
	ld a,0feh              ; unpause BGM
	call play_sound
	ld a,005h
	jp main_state_set              ; back to play
state_vendor:                  ; 12 (0x43F7): 0xC40C whip-hit vendor
	djnz l4402h
	call vendor_purchase_tick  ; poll buy/refuse (seg2)
	ret nz
	ld a,00fh
	jp main_timer_set
; Vendor-interaction states (this resident state machine drives the vendor code
; in seg2, which is paged at 0x8000): 0x94C1 = vendor_purchase_tick body, 0x950E
; = offer dismiss, vendor_make_offer (0x938E) = arm a sale.
l4402h:
	djnz l4411h
	ld hl,0c004h
	dec (hl)               ; hold the offer for 0xC004 frames...
	ret nz
	call 0950eh            ; ...then run the vendor offer-dismiss (seg2)
	ld a,005h
	jp main_state_set
l4411h:
	xor a
	ld (0c40ch),a          ; clear the whip-hit flag
	call vendor_make_offer ; arm a sale (seg2 0x938E)
	jp main_phase_next
; ===========================================================================
;  state_game_master_menu - primary state 13 (0x441B), the hidden Game Master
;  menu.  Only reachable when game_master_detect found the cartridge (0xE600),
;  otherwise title start goes straight to the intro (state 3).  Secondary state
;  0xC001 walks the phases backwards, as usual for these handlers:
;    C001=2 -> draw the menu (gm_menu_draw) and clear the 0xE608-0xE615 scratch
;    C001=1 -> number-entry phase: RETURN commits, digits feed gm_digit_entry
;    C001=0 -> browsing: up/down moves the cursor, fire picks the item
;  Menu RAM: 0xE60B = highlighted item 0-2, 0xE604 = bitmask of which values the
;  player edited, 0xE605/E606 = stage (BCD / binary), 0xE607 = lives,
;  0xE602 = where the current prompt prints its digits, 0xE615 = "value typed".
;  Picking START GAME just sets state 3 (intro); the edited values are pushed
;  into the run later by gm_apply_values.
; ===========================================================================
state_game_master_menu:
	djnz l4453h
	ld a,(0c006h)          ; latched input
	and 033h
	ret z
	and 003h               ; up/down?
	jp nz,gm_menu_move
	ld a,(0e60bh)          ; fire: which item is highlighted?
	or a
	jp nz,l4439h           ; 1/2 -> a MODIFY prompt
	call gm_menu_clear     ; 0 = START GAME
	ld hl,00003h
	ld (0c000h),hl         ; -> intro (state 3), secondary 0
	ret
l4439h:
	dec a
	jr z,l4447h
	ld hl,0b8b8h           ; item 2: PLAYER NUMBER digit position
	ld (0e602h),hl
l4442h:
	call gm_prompt_player
	jr l4450h
l4447h:
	ld hl,0b0b8h           ; item 1: STAGE NUMBER digit position
	ld (0e602h),hl
	call gm_prompt_stage
l4450h:
	jp main_phase_next              ; -> number-entry phase (C001=1)
l4453h:
	djnz l4488h
	call gm_confirm_key    ; RETURN pressed?
	jr nz,l445dh
	jp gm_digit_entry      ; no -> keep taking digits
l445dh:
	ld a,(0e60bh)
	ld b,a
	ld hl,0e604h
	or (hl)
	ld (hl),a              ; remember that this field was edited
	ld a,(0e615h)
	or a
	jr z,l447eh            ; nothing typed -> just leave the prompt
	ld a,(0e60eh)
	ld d,a                 ; D = binary value
	ld a,(0e60fh)          ; A = BCD value
	bit 0,b
	jr z,l4483h
	ld (0e605h),a          ; stage: keep both forms
	ld a,d
	ld (0e606h),a
l447eh:
	xor a
	ld (0c001h),a          ; back to browsing
	ret
l4483h:
	ld (0e607h),a          ; lives
	jr l447eh
l4488h:
	call gm_menu_draw
	xor a
	ld hl,0e608h           ; clear the menu scratch (key latches, accumulators)
	ld de,0e609h
	ld bc,0000eh
	ld (hl),000h
	ldir
	jp main_phase_next
pause_panel_draw:
	ld hl,06854h
	ld bc,03010h
	ld de,0d070h
	ld a,004h
	push hl
	push bc
	call vdp_hmmm
	pop bc
	pop hl
	call panel_frame
	ld hl,pause_text
	jp hud_string_draw
pause_text:
	defb 06ch, 058h
	vk "PAUSE"
	defb 0ffh
pause_panel_restore:
	ld de,06854h
	ld bc,03010h
	ld hl,0d070h
	ld a,001h
	jp vdp_hmmm
; --- reset_run_state (sub_44cdh) - wipe the run's work RAM & seed defaults ------
;  Called from the intro handler (state 3) to start a fresh run.  Runtime trace
;  confirmed the ldir below zero-fills the entire game work block 0xC405..0xDFFF
;  in one sweep (event state 0xCE00+, actor arrays 0xD000+, etc.), then seeds the
;  starting counters at 0xC410..0xC412 from run_seed_tbl and the view defaults
;  0xC415=0x20 / 0xC418=0x80.
reset_run_state:
	ld hl,0c405h           ; HL -> first byte to clear
	ld bc,01bfbh           ; 0x1BFB bytes -> up through 0xE000 (exclusive)
	ld d,h
	ld e,l
	inc e                  ; DE = HL+1 (classic ldir zero-fill)
	ld (hl),000h
	ldir                   ; 0xC405..0xDFFF = 0
	ld hl,run_seed_tbl     ; seed the starting counters...
	ld de,0c410h           ; ...into 0xC410..0xC412
	ld bc,00003h
	ldir
	ld a,020h
	ld (0c415h),a          ; Simon health = full (0x20); runtime-confirmed HP
	ld a,080h
	ld (0c418h),a          ; enemy/boss energy meter = full (0x80)
	ret
run_seed_tbl:                  ; (0x44F0) new-game C410..C412: lives=3, STAGE=0, C412=1 (unread)
	defb 003h,000h,001h
add_score_c0:                  ; (0x44F3) callers jp here with DE=amount to force C=0
	ld c,000h
; --- add_score (seg0 0x44F5) - add points to Simon's score ---------------------
; Score is a 3-byte packed-BCD counter at 0xC405 (low pair) / 0xC406 (mid pair -
; the hundreds/thousands digits, i.e. the main visible byte) / 0xC407 (high pair).
; On-screen value = the 6 BCD digits with leading zeros stripped (e.g. 00 82 00 =
; "8200").  Award amount is passed in C:D:E = high:mid:low BCD pairs (points are
; always multiples of 100, so callers set E=0 and put the hundreds in D).  Adds
; with `daa` carry-chained across the 3 bytes; on overflow past 999999 it clamps.
; Guard: skipped (ret p) unless bit 6 of the 0xC002 frame counter is set.
; Overflow writes 0x99 into 0xC402-0xC404 (not the visible score); those bytes
; have no readers.
add_score:
	ld a,(0c002h)
	add a,a
	ret p
	ld hl,0c405h           ; HL -> score low byte
	ld a,(hl)
	add a,e                ; += E (low pair)
	daa
	ld (hl),a
	inc l
	ld a,(hl)
	adc a,d                ; += D (mid pair = hundreds/thousands)
	daa
	ld (hl),a
	inc hl
	ld a,(hl)
	adc a,c                ; += C (high pair)
	daa
	ld (hl),a
	jr nc,l4538h           ; no overflow -> done
	ld bc,09999h
	ld (0c402h),bc         ; unused (no readers); visible score is C405-C407
	ld (0c403h),bc
	jr l4538h
; --- hud_draw_all (seg0 0x451A) - paint the whole HUD from scratch: the static
;     labels, then every counter, meter, frame and icon.
hud_draw_all:
	ld hl,l4c07h           ; HUD label strings (vk-encoded)
	call hud_string_draw
	call draw_stage_hud
	call draw_hearts_hud
	call draw_lives_hud
	call hud_bars_redraw
	call hud_panel_frames
	call hud_weapon_icon
	call 08ebbh            ; seg2: HUD key/weapon tiles
	call hud_bonus_refresh
l4538h:
	ld hl,0c407h
	ld de,03800h
	ld b,003h
	jr hud_bcd_draw
; --- draw_stage_hud (seg0 0x4542) - draw the HUD STAGE number (0xC411, BCD).
draw_stage_hud:
	ld de,09c00h           ; HUD cell for the stage readout
	ld hl,0c411h           ; stage/area label (packed BCD)
	ld b,001h
	jr hud_bcd_draw
; --- hud_panel_frames (seg0 0x454C) - the three boxed HUD panels along the top
;     row (y=0x0B, 18 tall): 18 wide at x=0x7F in colour 8, then 34 wide at
;     x=0x93 and 66 wide at x=0xB7 in colour 14.  Outlines only; the counters
;     drawn above sit inside them.
hud_panel_frames:
	ld hl,07f0bh
	ld de,01212h           ; 18 x 18
	ld c,008h
	call vdp_box
	ld hl,0930bh
	ld de,02212h           ; 34 x 18
	ld c,00eh
	call vdp_box
	ld hl,0b70bh
	ld de,04212h           ; 66 x 18
	ld c,00eh
	jp vdp_box
; --- draw_hearts_hud (seg0 0x456D) - draw the HEART counter (0xC417, BCD) -----
;  hl -> BCD source, de -> VDP name-table cell; B counts source bytes (1 byte =
;  2 decimal digits).  Runtime-confirmed: 0xC417 is the heart total (cap 0x99).
;  draw_lives_hud (seg0 0x4575) is the same routine seeded for 0xC410 (lives).
draw_hearts_hud:
	ld hl,0c417h           ; hearts (packed BCD)
	ld de,0c000h           ; HUD cell for the heart readout
	jr l457bh
draw_lives_hud:
	ld hl,0c410h           ; lives (packed BCD)
	ld de,0e400h           ; HUD cell for the lives readout
l457bh:
	ld b,001h              ; 1 byte -> 2 digits
	jr hud_bcd_draw
hud_bcd_draw:
	ld a,(hl)
	rra                    ; isolate the high nibble (tens digit)
	rra
	rra
	rra
	call hud_draw_digit
	ld a,(hl)              ; low nibble (ones digit)
	call hud_draw_digit
	dec hl
	djnz hud_bcd_draw
	ret
; hud_draw_digit (seg0 0x458F): low nibble of A -> HUD numeral tile 0x20+ at DE.
hud_draw_digit:
	and 00fh               ; digit 0..9
	add a,020h             ; -> numeral tile code
	call hud_glyph_blit
	ld a,d
	add a,008h             ; advance to the next digit cell
	ld d,a
	ret
; add_hearts (seg0 0x459B) - add B hearts to 0xC417 (BCD), clamp at 99. The pickup
; path funnels here via collect_bonus (seg2): B=1 small heart, B=5 large heart
; (both increments runtime-confirmed).
add_hearts:
	ld hl,0c417h
	ld a,(hl)
	add a,b
	daa                    ; keep the total decimal (BCD)
	jr nc,l45a5h
	ld a,099h              ; clamp at 99 hearts
l45a5h:
	jr l45b0h
; spend_hearts (seg0 0x45A7) - subtract B hearts from 0xC417 (BCD), floor at 0.
spend_hearts:
	ld hl,0c417h
	ld a,(hl)
	cp b
	jr c,l45b4h
	sub b
	daa
l45b0h:
	ld (hl),a
	jp draw_hearts_hud
l45b4h:
	xor a
	jr l45b0h
; --- hud_bars_redraw (seg0 0x45B7) - repaint both HUD meters, frame and all.
;     health_bar_redraw (0x45C0) does just Simon's; the frame helpers below
;     clear the panel and draw its colour-14 border, then the bar is filled in.
;     Frame is 66x6 at (0x3B,0x0D) / (0x3B,0x16), one pixel around each 64x4 bar.
hud_bars_redraw:
	call health_bar_redraw
enemy_meter_redraw:
	call enemy_meter_frame
	jp draw_enemy_meter
health_bar_redraw:
	call health_bar_frame
	jp draw_health_bar
enemy_meter_frame:
	ld hl,03b16h           ; (X,Y) just outside the enemy meter
	ld bc,04206h           ; 66 x 6 (immediate, not a code address)
l45cch:
	jp panel_frame           ; clear the panel + draw its border
health_bar_frame:
	ld hl,03b0dh           ; (X,Y) just outside the health bar
	ld bc,04206h           ; 66 x 6
	jp l45cch
; draw_health_bar (seg0 0x45D8) - draw the HEALTH bar from 0xC415 (len = health*2).
draw_health_bar:
	ld hl,0c415h           ; Simon health (0..0x20)
	ld a,(hl)
	ld hl,03c0eh
	add a,a                ; bar length = health * 2
	or a
	ret z
	ld b,a
	ld c,004h
	ld d,000h
	ld a,011h
	jp vdp_hmmv
; draw_enemy_meter (seg0 0x45EC) - draw the ENEMY/BOSS energy meter from 0xC418 (cap 0x80).
draw_enemy_meter:
	ld hl,0c418h           ; enemy/boss energy (0..0x80)
	ld a,(hl)
	ld hl,03c17h
	ld b,a
	and 003h
	ld c,a
	ld a,b
	and 0fch
	rrca
	or a
	jr nz,l4602h
	or c
	ret z
	ld a,002h
l4602h:
	ld b,a
	ld c,004h
	ld d,000h
	ld a,088h
	jp vdp_hmmv
; restore_health (seg0 0x460C) - restore HEALTH: 0xC415 += B, clamped to 0x20 max.
restore_health:
	ld hl,0c415h           ; Simon health
	ld a,(hl)
	add a,b                ; add restore amount
	cp 021h
	jr c,l461bh
	ld a,020h              ; clamp to full (0x20)
	sub (hl)
	ld b,a
	ld a,020h
l461bh:
	ld (hl),a
	jp health_bar_redraw
; restore ENEMY/BOSS energy: 0xC418 += B, clamped to the 0x80 maximum.
	ld hl,0c418h           ; enemy/boss energy
	ld a,(hl)
	add a,b
	cp 081h
	jr c,l462eh
	ld a,080h              ; clamp to full (0x80)
	sub (hl)
	ld b,a
	ld a,080h
l462eh:
	ld (hl),a
	jp enemy_meter_redraw
; damage_health (seg0 0x4632) - subtract from HEALTH: 0xC415 -= B, floored at 0.
damage_health:
	ld hl,0c415h           ; Simon health
	ld a,(hl)
	cp b
	jr nc,l463ah
	ld b,a                 ; can't drop below 0: clamp damage to current HP
l463ah:
	ld a,b
	or a
	ret z
	ld a,(hl)
	sub b
	ld (hl),a
	jp health_bar_redraw
; damage_enemy (seg0 0x4643) - subtract B from the on-screen ENEMY/BOSS energy
; 0xC418 (the enemies/bosses that carry an HP bar, types >= 0x11), floored at 0.
; This is where Simon's whip/sub-weapon damage lands (see seg1 weapon_hit_damage).
damage_enemy:
	ld hl,0c418h
	ld a,(hl)
	cp b
	jr nc,l464bh
	ld b,a
l464bh:
	ld a,b
	or a
	ret z
	ld a,(hl)
	sub b
	ld (hl),a
	jp enemy_meter_redraw
	ld b,001h
	jr damage_health
	ld b,001h
	jp restore_health
	ld b,001h
	jr damage_enemy
vram_read:                     ; VRAM HL -> CPU DE (INIR); BC = count
	call vdp_set_read
	call vram_otir_count
	ex af,af'
	ld a,(00006h)          ; VDP data port
	ld c,a
	ex af,af'
l466dh:
	inir
	dec a
	jr nz,l466dh
	ex de,hl
	ret
vram_otir_count:               ; after ex de,hl: A=pages, B=remainder from BC
	ex de,hl
	ld a,c
	or a
	ld a,b
	ld b,c
	ret z
	inc a
	ret
vram_write:
	ex de,hl
	call vdp_set_write
	call vram_otir_count
	ex af,af'
	ld a,(00007h)
	ld c,a
	ex af,af'
l4689h:
	otir
	dec a
	jr nz,l4689h
	ret
vram_fill:                     ; fill VRAM HL with A; BC = count (B pages, C rem)
	push de
	push af
	call vdp_set_write
	ld d,c
	ld a,c
	or a
	jr z,l469ah
	inc b
l469ah:
	ld a,(00007h)
	ld c,a
	pop af
l469fh:
	out (c),a
	dec d
	jr nz,l469fh
	djnz l469fh
	pop de
	ret
vram_poke:                     ; write A to VRAM HL (one byte)
	push bc
	push af
	call vdp_set_write
	ld a,(00007h)
	ld c,a
	pop af
	out (c),a
	pop bc
	ret
; --- vdp_set_write - set the VDP VRAM write pointer to the 16-bit address in HL.
;     Programs R14 (A14-A16 = top 2 bits of H) then the auto-increment address
;     low/high via port 0x99, with bit6 set to select "write" mode.  Used before
;     streaming pixel data to the data port 0x98.
vdp_set_write:
	push bc
	ld a,(00007h)           ; c = VDP addr/ctrl port (0x99)
	inc a
	ld c,a
	ld a,h
	rlca                    ; A14-A16 = (H >> 6)
	rlca
	and 003h
	di
	out (c),a
	ld a,08eh
	out (c),a
	ld a,l
	out (c),a
	ld a,h
	and 03fh
	or 040h
	out (c),a
	pop bc
	ei
	ret
vdp_set_read:
	push bc
	ld a,(00007h)
	inc a
	ld c,a
	ld a,h
	rlca
	rlca
	and 003h
	di
	out (c),a
	ld a,08eh
	out (c),a
	ld a,l
	out (c),a
	ld a,h
	and 03fh
	out (c),a
	pop bc
	ei
	ret
; --- RLE graphics decompressor -> VRAM.  This is how ALL SCREEN 5 bitmaps and
;     the hardware-sprite patterns are unpacked from the banked graphics ROM.
;     Entry:  DE = compressed source stream, HL = initial VRAM dest address.
;       rle_dec_addr : variant that first reads the 2-byte dest address FROM the
;                stream (used when the caller doesn't set HL itself).
;       rle_dec : standard entry (HL already holds the dest address).
;     Control-byte grammar (source read linearly; output goes to the VRAM
;     write pointer set via vdp_set_write, streamed to data port 0x98):
;       0x00           -> end of stream (ret)
;       0x80  lo hi    -> set VRAM write pointer = hi<<8 | lo  (jump to rle_dec_addr)
;       0x01..0x7F  N  -> RUN     : next single byte repeated N times
;       0x81..0xFF  N  -> LITERAL : copy (N & 0x7F) bytes verbatim via OTIR
;     Tools: tools/disasm/rledec.py replays this exact grammar to extract graphics.
rle_dec_addr:
	ex de,hl                ; read a fresh 2-byte dest address...
	ld e,(hl)               ; ...from the source stream (0x80 command)
	inc hl
	ld d,(hl)
	inc hl
	ex de,hl
rle_dec:
	call vdp_set_write          ; point VDP at dest VRAM address (HL)
	ld a,(00007h)           ; c = VDP data port (0x98)
	ld c,a
l46ffh:
	ld a,(de)               ; fetch next control byte
	and a
	ret z                   ; 0x00 -> done
	inc de
	ld b,a
	and 07fh                ; test bit7...
	cp b                    ; bit7 clear (b <= 0x7F) -> RUN
	jr z,l4713h
	and a                   ; b == 0x80 -> set new dest address
	jr z,rle_dec_addr
	ex de,hl                ; else LITERAL: copy (b & 0x7F) bytes
	ld b,a
	otir                    ; stream b bytes -> VRAM data port
	ex de,hl
	jr l46ffh
l4713h:
	ld a,(de)               ; RUN: fetch the byte to repeat...
	inc de
l4715h:
	out (c),a               ; ...write it b times to VRAM
	djnz l4715h
	jr l46ffh
; ---------------------------------------------------------------------------
;  gfx_script_run (seg0 0x471B) - interpret a per-room gfx script (HL).
;  Cmd 0xFF ends; 0 = gfx_script_rle (src word, VRAM dest word);
;  1 = gfx_script_convert sprite convert; else gfx_script_copy (6-byte VRAM blit).
; ---------------------------------------------------------------------------
gfx_script_run:
	ld a,(hl)
	inc hl
	inc a
	ret z
	dec a
	or a
	jr z,l472bh
	dec a
	jr z,l4730h
	call gfx_script_copy
	jr gfx_script_run
l472bh:
	call gfx_script_rle
	jr gfx_script_run
l4730h:
	call gfx_script_convert
	jr gfx_script_run
gfx_script_rle:
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,(hl)
	inc hl
	ld b,(hl)
	inc hl
	push hl
	ld l,a
	ld h,b
	call rle_dec
	pop hl
	ret
gfx_script_convert:
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,(hl)
	inc hl
	push hl
	ld l,a
	ld h,000h
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld c,l
	ld b,h
	ex de,hl
	push bc
	push af
	ld de,0e800h
	call vram_read
	pop af
	call gfx_1bpp_expand
	pop bc
	pop hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	push hl
	ld hl,0ec00h
	call vram_write
	pop hl
	ret
gfx_script_copy:
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)
	inc hl
	ld a,(hl)
	inc hl
	push hl
	ld h,(hl)
	ld l,a
	ex de,hl
	call vram_write
	pop hl
	inc hl
	ret
gfx_1bpp_expand:
	ld hl,0e800h
	ld de,0ec10h
	ld c,a
l478dh:
	call gfx_1bpp_row
	ld a,0e0h
	add a,e
	ld e,a
	jr c,l4797h
	dec d
l4797h:
	call gfx_1bpp_row
	ld a,020h
	call ADD_DE_A
	dec c
	jp nz,l478dh
	ret
gfx_1bpp_row:
	ld b,010h
l47a6h:
	ld a,(hl)
	inc hl
	exx
	ld c,a
	ld a,001h
l47ach:
	rr c
	rla
	jp nc,l47ach
	exx
	ld (de),a
	inc de
	djnz l47a6h
	ret
video_clear_page:
	call sat_vram_hide
	ld bc,00000h
	jr l47c6h
video_reset:
	call sat_vram_hide
	ld bc,000d4h
l47c6h:
	push bc
	call vdp_screen_off
	pop bc
	call vdp_fill_origin
vdp_screen_on:
	ld a,(0f3e0h)
	or 040h
	ld b,a
	ld c,001h
	call WRTVDP
	jr vdp_sprites_on
vdp_screen_off:
	ld a,(0f3e0h)
	and 0bfh
	ld b,a
	ld c,001h
	call WRTVDP
	jr vdp_sprites_off
vdp_fill_origin:
	ld hl,00000h
	xor a
	ld d,a
	call vdp_hmmv
	ld b,000h
	ld c,017h
	jp WRTVDP
sat_vram_hide:
	ld hl,0f600h
	ld a,0e0h
	ld bc,00080h
	call vram_fill
	jp sprites_hide
vdp_sprites_off:
	ld a,(0ffe7h)
	or 002h
	ld b,a
	ld c,008h
	jp WRTVDP
vdp_sprites_on:
	ld a,(0ffe7h)
	and 0fdh
	ld b,a
	ld c,008h
	jp WRTVDP
; --- palette_set - write one MSX2 palette entry.  A = index 0-15, D = 0rrr0bbb,
;     E = 00000ggg (3-bit R/B then G).  Programs R16 then ports 0x9A; also
;     shadows the pair at VRAM 0xF680+A*2.
palette_set:
	push bc
	push hl
	ld b,a
	ld a,(00007h)
	inc a
	ld c,a
	di
	out (c),b               ; palette index -> R16
	ld a,090h
	out (c),a
	inc c                   ; C = palette data port 0x9A
	out (c),d
	push af
	pop af
	out (c),e
	dec c
	ld hl,0f680h
	ld a,b
	add a,a
	add a,l
	ld l,a
	call vdp_set_write
	dec c
	out (c),d
	out (c),e
	pop hl
	pop bc
	ei
	ret
; --- palette_apply - apply a palette table: records (index, rb, g)+ , 0xFF-terminated.
palette_apply:
	ld a,(hl)
	inc hl
	inc a
	ret z
	dec a
	ld d,(hl)
	inc hl
	ld e,(hl)
	inc hl
	call palette_set
	jr palette_apply
; --- vdp_cmd_wait (seg0 0x4853) - spin until the VDP command engine is idle.
;     Polls S#2 bit0 (CE, "command executing"); every command helper below
;     calls this first so it can safely reload the command registers.
vdp_cmd_wait:
	ld a,002h              ; status register 2
	call vdp_status_read
	rra                    ; bit0 -> carry = CE (still executing)
	jr c,vdp_cmd_wait
	ret
; --- vdp_status_read (seg0 0x485C) - read V9938 status register A into A.
;     R15 selects which of S#0..S#9 appears on the status port; it is put back
;     to 0 afterwards so the BIOS interrupt handler still reads S#0.  Port
;     numbers come from the BIOS VDP port bytes at 0x0006/0x0007 (+1 = 0x99).
vdp_status_read:
	push bc
	push hl
	ld hl,(00006h)         ; L = VDP read port, H = VDP write port (0x98)
	inc h                  ; 0x99 = register write / status read port
	inc l
	ld c,h
	di
	out (c),a              ; R15 = A (status register select)
	ld a,08fh
	out (c),a
	ld c,l
	in a,(c)               ; read the selected status register
	push af
	xor a
	ld c,h
	out (c),a              ; R15 = 0 again (BIOS/IRQ expects S#0)
	ld a,08fh
	out (c),a
	pop af
	pop hl
	pop bc
	ei
	ret
; --- vdp_line_h (seg0 0x487C) - V9938 LINE, horizontal run.
;     H = X, L = Y (page 0), B = length, C = colour.  R17 is pointed at R36
;     with auto-increment, so DX/DY/NX/NY/CLR/ARG/CMR go out as one stream on
;     the indirect data port (0x9B).  ARG bit0 (MAJ) = 0 -> long side is X.
vdp_line_h:
	call vdp_cmd_wait
	push bc                ; stash length/colour for the NX/CLR writes
	ld a,(00007h)
	inc a
	ld c,a                 ; 0x99 = register port
	ld a,024h
	di
	out (c),a              ; R17 = 36 (DX), auto-increment on
	ld a,091h
	out (c),a
	inc c
	inc c                  ; 0x9B = indirect register data
	out (c),h              ; R36 DX = X
	xor a
	out (c),a              ; R37
	out (c),l              ; R38 DY = Y
	out (c),a              ; R39 (page 0)
	pop hl                 ; H = length, L = colour
	dec h
	out (c),h              ; R40 NX = length-1 (long side)
	xor a
	out (c),a              ; R41
	xor a
	out (c),a              ; R42 NY = 0 (short side)
	out (c),a              ; R43
	out (c),l              ; R44 CLR = colour
	out (c),a              ; R45 ARG = 0 -> MAJ 0, long side is X
	ld a,070h
	out (c),a              ; R46 CMR = LINE, logic IMP
	ei
	ret
; --- vdp_line_v (seg0 0x48AF) - the same LINE command with ARG bit0 (MAJ) = 1,
;     so the long side runs down Y instead.  Same H/L/B/C convention.
vdp_line_v:
	call vdp_cmd_wait
	push bc
	ld a,(00007h)
	inc a
	ld c,a
	ld a,024h
	di
	out (c),a              ; R17 = 36 (DX), auto-increment on
	ld a,091h
	out (c),a
	inc c
	inc c
	out (c),h              ; R36 DX = X
	xor a
	out (c),a              ; R37
	out (c),l              ; R38 DY = Y
	out (c),a              ; R39 (page 0)
	pop hl                 ; H = length, L = colour
	dec h
	out (c),h              ; R40 NX = length-1
	xor a
	out (c),a              ; R41
	xor a
	out (c),a              ; R42 NY = 0
	out (c),a              ; R43
	out (c),l              ; R44 CLR = colour
	inc a
	out (c),a              ; R45 ARG = 1 -> MAJ 1, long side is Y
	ld a,070h
	out (c),a              ; R46 CMR = LINE, logic IMP
	ei
	ret
; --- vdp_box (seg0 0x48E3) - rectangle OUTLINE built from four LINE commands.
;     H = X, L = Y (top-left), D = width, E = height, C = colour.  Left and top
;     edges first, then the bottom at Y+height-1 and the right at X+width-1.
;     Draws the HUD bar frames (health_bar_frame) and the message-panel border.
vdp_box:
	ld b,e
	call vdp_line_v_save   ; left edge, height tall
	ld b,d
	call vdp_line_h_save   ; top edge, width wide
	push hl
	ld a,l
	dec a
	add a,e
	ld l,a                 ; Y += height-1
	ld b,d
	call vdp_line_h_save   ; bottom edge
	pop hl
	ld a,h
	dec a
	add a,d
	ld h,a                 ; X += width-1
	ld b,e
	jp vdp_line_v_save     ; right edge
; --- vdp_line_v_save / vdp_line_h_save (0x48FD / 0x4907) - the LINE helpers
;     with HL/DE/BC preserved, so vdp_box keeps its parameters across all four
;     edges (the primitives themselves clobber HL and B).
vdp_line_v_save:
	push hl
	push de
	push bc
	call vdp_line_v
	pop bc
	pop de
	pop hl
	ret
vdp_line_h_save:
	push hl
	push de
	push bc
	call vdp_line_h
	pop bc
	pop de
	pop hl
	ret
; --- vdp_hmmv (seg0 0x4911) - V9938 HMMV: fill a VRAM rectangle with one byte.
;     H = X, L = Y, D = VRAM page (DY high), B = width, C = height, A = the
;     fill byte (two 4bpp pixels, e.g. 0x11 = colour 1).  A width or height of
;     0 means 256: the NX/NY high bit is set instead.  Used for the HUD bars
;     (draw_health_bar / draw_enemy_meter), panel interiors, and the page 0/1
;     clears in video_init.
vdp_hmmv:
	ex af,af'              ; keep the fill byte
	call vdp_cmd_wait
	push bc
	ld a,(00007h)
	inc a
	ld c,a
	ld a,024h
	di
	out (c),a              ; R17 = 36 (DX), auto-increment on
	ld a,091h
	out (c),a
	inc c
	inc c
	out (c),h              ; R36 DX = X
	xor a
	out (c),a              ; R37
	out (c),l              ; R38 DY = Y
	out (c),d              ; R39 DY high = VRAM page
	pop hl                 ; H = width, L = height
	out (c),h              ; R40 NX = width
	cp h                   ; width 0 means 256 px...
	jr nz,l4936h
	inc a                  ; ...so carry it in the NX high bit
l4936h:
	out (c),a              ; R41
	xor a
	out (c),l              ; R42 NY = height
	cp l                   ; height 0 means 256 px
	jr nz,l493fh
	inc a
l493fh:
	out (c),a              ; R43
	ex af,af'
	out (c),a              ; R44 CLR = fill byte
	xor a
	out (c),a              ; R45 ARG = 0
	ld a,0c0h
	out (c),a              ; R46 CMR = HMMV
	ei
	ret
; vdp_hmmm (seg0 0x494D): V9938 HMMM. HL=(SX,SY), DE=(DX,DY), BC=(NX,NY).
; A bits 1-0 = source page, bits 3-2 = dest page. ARG=0 (no X/Y flip).
vdp_hmmm:
	ex af,af'
	call vdp_cmd_wait
	push bc
	ld a,(00007h)
	inc a
	ld c,a
	ld a,020h
	di
	out (c),a
	ld a,091h
	out (c),a
	inc c
	inc c
	out (c),h
	xor a
	out (c),a
	out (c),l
	ex af,af'
	ld l,a
	and 003h
	out (c),a
	out (c),d
	xor a
	out (c),a
	out (c),e
	ld a,l
	rra
	rra
	and 003h
	out (c),a
	pop hl
	out (c),h
	xor a
	out (c),a
	out (c),l
	out (c),a
	out (c),a
	out (c),a
	ld a,0d0h
	out (c),a
	ei
	ret
; --- vdp_hmmc (seg0 0x4991) - V9938 HMMC: push CPU bytes into a VRAM rectangle.
;     HL = source bytes, D = X, E = Y, A = VRAM page, B = width, C = height.
;     The first byte rides out with the command; R17 is then re-pointed at R44
;     with auto-increment OFF so the feed loop can keep writing CLR, waiting on
;     S#2 TR between bytes.  Ends when CE clears.  CMR 0xF0 = HMMC.
vdp_hmmc:
	ex af,af'              ; keep the destination page
	call vdp_cmd_wait
	push bc
	ld a,(00007h)
	inc a
	ld c,a
	ld a,024h
	di
	out (c),a              ; R17 = 36 (DX), auto-increment on
	ld a,091h
	out (c),a
	inc c
	inc c
	out (c),d              ; R36 DX = X
	xor a
	out (c),a              ; R37
	out (c),e              ; R38 DY = Y
	ex af,af'
	out (c),a              ; R39 DY high = VRAM page
	pop de                 ; D = width, E = height
	out (c),d              ; R40 NX = width
	xor a
	out (c),a              ; R41
	out (c),e              ; R42 NY = height
	out (c),a              ; R43
	ld a,(hl)              ; first data byte travels with the command
	inc hl
	out (c),a              ; R44 CLR
	xor a
	out (c),a              ; R45 ARG = 0
	ld a,0f0h
	out (c),a              ; R46 CMR = HMMC
	dec c
	dec c                  ; back to the register port
	ld a,0ach
	out (c),a              ; R17 = 44 (CLR), auto-increment OFF
	ld a,091h
	out (c),a
	inc c
	inc c
l49d1h:
	ld a,002h
	call vdp_status_read   ; S#2
	rra                    ; CE clear -> transfer done
	ret nc
	add a,a
	add a,a                ; carry = TR (S#2 bit7): VDP wants a byte
	jr nc,l49d1h
	ld a,(hl)
	inc hl
	out (c),a              ; feed the next byte through CLR
	jr l49d1h
; vdp_lmmm (seg0 0x49E2): V9938 LMMM (colour-0 skip). Same HL/DE/BC as vdp_hmmm.
; A is packed page + logic bits (0x48 = page-1 -> page-0, used for Dracula torso).
vdp_lmmm:
	ex af,af'
	call vdp_cmd_wait
	push bc
	ld a,(00007h)
	inc a
	ld c,a
	ld a,020h
	di
	out (c),a
	ld a,091h
	out (c),a
	inc c
	inc c
	out (c),h
	xor a
	out (c),a
	out (c),l
	ex af,af'
	rlca
	rlca
	ld l,a
	and 003h
	out (c),a
	out (c),d
	xor a
	out (c),a
	out (c),e
	ld a,l
	ld e,a
	rlca
	rlca
	and 003h
	out (c),a
	pop hl
	out (c),h
	xor a
	out (c),a
	out (c),l
	out (c),a
	out (c),a
	out (c),a
	ld a,e
	rra
	rra
	and 00fh
	or 090h
	out (c),a
	ei
	ret
; --- glyph_blit_run (seg0 0x4A2E) - blit B consecutive 8x8 1bpp glyphs.
;     HL = glyph bytes, D = X, E = Y, B = count, C = ink colour.  Used by
;     hud_font_load (0x53BD) for hud_font, credits_font_blit (0x53E8) for
;     credits_font / credits_font_az, and logo_font_load (0x5316) for
;     logo_font / logo_font_ink2 / logo_font_ink3.
glyph_blit_run:
	call glyph_blit
	call blit_advance_x
	djnz glyph_blit_run
	ret
; --- glyph_blit (seg0 0x4A37) - expand one 1bpp glyph to 4bpp and blit it.
;     D = X, E = Y, C = ink.  SCREEN 5 has no pattern table, so the glyph is
;     first painted into the 0xC110 scratch tile, then copied to the bitmap at
;     VRAM 0x8000 + Y*0x80 + X/2.  HL advances to the next glyph.
glyph_blit:
	push bc
	push de
	push hl
	push de
	call glyph_expand_4bpp
	pop de
	ld b,d                 ; swap to (Y,X) so the 16-bit shift below works
	ld d,e
	ld e,b
	srl d                  ; (Y<<8 | X) >> 1 = Y*0x80 + X/2
	rr e
	ld a,d
	add a,080h             ; + VRAM page-0 bitmap base (0x8000)
	ld d,a
	ld hl,0c110h           ; the expanded 4bpp tile
	call vram_blit_tile8
	pop hl
	ld bc,00008h           ; next glyph (8 bytes of 1bpp rows)
	add hl,bc
	pop de
	pop bc
	ret
; --- vram_blit_tile8 (seg0 0x4A58) - blit one 8x8 4bpp tile.  HL = source
;     (32 bytes: 8 rows of 4), DE = VRAM dest.  A SCREEN 5 scanline is 0x80
;     bytes, so each row advances the destination by 0x80.  DE comes back
;     unchanged, pointing at the tile's top-left again.
vram_blit_tile8:
	push de
	ld b,008h              ; 8 pixel rows
l4a5bh:
	push bc
	ld bc,00004h           ; 4 bytes = 8 pixels at 4bpp
	call vram_write
	ex de,hl
	ld bc,00080h           ; next scanline
	add hl,bc
	ex de,hl
	pop bc
	djnz l4a5bh
	pop de
	ret
; --- vram_blit_tile_run (seg0 0x4A6D) - blit B consecutive 8x8 tiles, laying
;     them left to right.  DE steps 4 bytes per tile and wraps at the end of
;     the 0x80-byte line, where it drops down one tile row (D += 4 = 8 lines).
;     This is the tile-atlas upload (dest 0x8004+, 32 tiles per row).
vram_blit_tile_run:
	push bc
	call vram_blit_tile8
	ld a,004h
	add a,e                ; next tile to the right
	cp 080h
	jr nz,l4a7dh
	ld a,004h
	add a,d                ; wrapped: down one tile row (8 scanlines)
	ld d,a
	xor a
l4a7dh:
	ld e,a
	pop bc
	djnz vram_blit_tile_run
	ret
; --- vram_blit_tile16 (seg0 0x4A82) - the same for one 16x16 4bpp tile
;     (16 rows of 8 bytes), and vram_blit_tile16_run for a run of them.
vram_blit_tile16:
	push de
	ld b,010h              ; 16 pixel rows
l4a85h:
	push bc
	ld bc,00008h           ; 8 bytes = 16 pixels at 4bpp
	call vram_write
	ex de,hl
	ld bc,00080h           ; next scanline
	add hl,bc
	ex de,hl
	pop bc
	djnz l4a85h
	pop de
	ret
vram_blit_tile16_run:
	push bc
	call vram_blit_tile16
	ld a,008h
	add a,e                ; next tile to the right
	cp 080h
	jr nz,l4aa7h
	ld a,008h
	add a,d                ; wrapped: down one tile row
	ld d,a
	xor a
l4aa7h:
	ld e,a
	pop bc
	djnz vram_blit_tile16_run
	ret
; --- glyph_expand_4bpp (seg0 0x4AAC) - expand an 8x8 1bpp glyph at HL into the
;     32-byte 4bpp scratch tile at 0xC110.  C is the ink colour; a 0 bit becomes
;     colour 0 (transparent).  Each source row shifts out 8 bits MSB-first and
;     `rld` packs them two pixels at a time into 4 destination bytes.
glyph_expand_4bpp:
	ld b,008h              ; 8 rows
	ld de,0c110h           ; 4bpp scratch tile
l4ab1h:
	push bc
	push hl
	ex de,hl
	ld a,(de)
	ld d,a                 ; D = this row's 8 source bits
	ld b,004h              ; 4 dest bytes = 8 pixels
l4ab8h:
	ld a,c                 ; ink for a set bit...
	rl d
	jr c,l4abeh
	xor a                  ; ...colour 0 for a clear bit
l4abeh:
	rld                    ; push the pixel into the high nibble
	ld a,c
	rl d
	jr c,l4ac6h
	xor a
l4ac6h:
	rld                    ; and the low nibble
	inc hl
	djnz l4ab8h
	ex de,hl
	pop hl
	inc hl
	pop bc
	djnz l4ab1h
	ret
hud_string_draw:
	ld c,0ffh
	jr l4ad8h
hud_string_masked:
	ld c,000h
l4ad8h:
	ld d,(hl)
	inc hl
	ld e,(hl)
	inc hl
hud_string_glyphs:
	ld a,(hl)              ; 0xFF end; 0xFE new (D,E); else glyph. C masks A
	inc hl                 ; (credits: C=0xFF, ASCII letters; space=0 skips)
	ld b,a
	inc b
	ret z
	inc b
	jr z,hud_string_draw
	and c
	call hud_glyph_blit
	ld a,d
	add a,008h
	ld d,a
	jr hud_string_glyphs
hud_glyph_blit:
	push bc
	push hl
	push de
	or a
	ld h,a
	jr z,l4afah
	call tile_atlas_pos
	add a,038h
l4afah:
	ld l,a
	ld bc,00808h
	ld a,001h
	call vdp_hmmm
	pop de
	pop hl
	pop bc
	ret
hud_glyph_run:
	push af
	call hud_glyph_blit
	call blit_advance_x
	pop af
	djnz hud_glyph_run
	ret
tile_blit:
	push bc
	push hl
	push de
	call tile_atlas_pos
	ld bc,00808h
	ld a,001h
	call vdp_hmmm
	pop de
	pop hl
	pop bc
	ret
tile_blit_skip0:
	push bc
	push hl
	push de
	call tile_atlas_pos
	ld bc,00808h
	ld a,048h
	call vdp_lmmm
	pop de
	pop hl
	pop bc
	ret
tile_blit_page1:
	push bc
	push hl
	push de
	call tile_atlas_pos
	ld bc,00808h
	ld a,005h
	call vdp_hmmm
	pop de
	pop hl
	pop bc
	ret
; --- tile_atlas_pos (seg0 0x4B48) - tile id A -> source position in the VRAM
;     atlas: H = SX = (A & 0x1F) * 8, L = SY = (A & 0xE0) >> 2.  32 tiles per
;     row, 8 scanlines per row.  Callers pass HL straight to vdp_hmmm/vdp_lmmm.
tile_atlas_pos:
	ld b,a
	and 01fh               ; column = id & 0x1F
	add a,a
	add a,a
	add a,a                ; * 8 pixels
	ld h,a
	ld a,b
	and 0e0h               ; row = id >> 5
	rrca
	rrca                   ; * 8 scanlines
	ld l,a
	ret
; --- blit_advance_x (seg0 0x4B56) - step a blit position one 8x8 cell right,
;     wrapping to the next row of cells (D = X, E = Y).  Shared by
;     glyph_blit_run and the HUD tile runs.
blit_advance_x:
	ld a,d
	add a,008h
	ld d,a
	ret nz                 ; wrapped past X=255 -> down one cell row
	ld a,e
	add a,008h
	ld e,a
	ret
; --- video_init - video subsystem init.  Selects SCREEN 5 (VDP mode G4:
;     256x212, 16 colours, 4 bits/pixel bitmap).  This is why the graphics
;     banks (seg 4-9, 15) hold 4bpp bitmap data blitted to VRAM with the VDP
;     command engine (see vdp_box / vdp_hmmv), rather than 1bpp tile patterns.
;     Actors are drawn with hardware sprites (mode 2, 16x16).  After the mode
;     switch it clears VRAM page 0/1 via the block-fill helper vdp_hmmv.
video_init:
	call psg_init
	call vdp_sprites_off
	ld a,005h               ; SCREEN 5 (G4, 256x212, 16 colours, 4bpp)
	call CHGMOD             ; set VDP mode via BIOS
	call vdp_screen_off          ; program remaining VDP regs (sprite/table bases)
	xor a
	ld h,a
	ld l,a
	ld b,a
	ld c,a
	ld d,a
	call vdp_hmmv
	xor a
	ld h,a
	ld l,a
	ld b,a
	ld c,a
	ld d,001h
	call vdp_hmmv
	call vdp_cmd_wait
	ld b,004h
	ld hl,l4b9ch
l4b89h:
	push bc
	ld c,(hl)
	inc hl
	ld b,(hl)
	inc hl
	push hl
	call WRTVDP
	pop hl
	pop bc
	djnz l4b89h
	call sat_vram_hide
	jp vdp_screen_on
l4b9ch:
	ld bc,00562h
	rst 28h
	ld b,01fh
	dec bc
	ld bc,0023ah
	ret nz
	and 040h
	jp z,l4e35h
	call read_fkeys
	ld hl,0c00ch
	call input_edge
	call read_buttons
input_edge_play:
	ld hl,0c007h           ; play: held at C007, rising edge at C006
input_edge:                    ; (seg0 0x4BBB) A=sample, (HL)=held, (HL-1)=new-press
	ld c,(hl)
	ld (hl),a              ; held = this frame
	xor c
	and (hl)               ; bits newly set
	dec hl
	ld (hl),a              ; rising-edge byte
	ret
; read_buttons (seg0 0x4BC2): joystick (PSG port A, bits 0-5) OR keyboard row 8
; (arrows + SPACE).  Result in A.  Play latches held into 0xC007 and the rising
; edge into 0xC006 via input_edge.  Title uses a separate pair: 0xC401 held /
; 0xC400 new-press (frontend_input).  Consumer bits: 0=UP 1=DOWN 2=LEFT 3=RIGHT
; 4=SPACE/joy TRG1 (whip / title start) 5=kbd UP/joy TRG2 (jump / title start).
read_buttons:
	ld e,08fh
	ld a,00fh
	call WRTPSG
	ld a,00eh
	di
	call RDPSG
	ei
	cpl
	and 03fh
	push af
	ld a,008h
	call SNSMAT
	cpl
	ld e,a
	and 020h
	ld e,a
	ld a,008h
	call SNSMAT
	cpl
	rrca
	rrca
	ld b,a
	and 004h
	or e
	ld c,a
	ld a,b
	rrca
	rrca
	ld b,a
	and 018h
	or c
	ld c,a
	ld a,b
	rrca
	and 003h
	or c
	pop bc
	or b
	ret
; read_fkeys (0x4BFB) - sample keyboard matrix row 6 (F1=bit5, F2=bit6, F3=bit7),
; return them right-justified: bit0=F1, bit1=F2, bit2=F3.  The caller input_edge's
; into 0xC00B (newly-pressed).  F2 drives the world-map feature (seg2 minimap_driver
; 0x9559); F1 is handled in seg0 (0x43E1 / 0x5C48).
read_fkeys:
	ld a,006h              ; keyboard matrix row 6 = function keys...
	call SNSMAT
	cpl                    ; active-high
	rlca                   ; rotate F1/F2/F3 (bits 5/6/7) down to bits 0/1/2
	rlca
	rlca
	and 007h
	ret
; --- HUD / status-bar text set (drawn via 0x451a).  vk "TEXT" is ASCII-0x10
;     (space = 0x00).  Leading numbers are VDP positions; 0xFE ends a field,
;     0xFF ends the set.  Byte-for-byte identical to the original.
l4c07h:
	defb 008h, 000h
	vk "SCORE"
	defb 030h, 0feh            ; + score-digit tile
	defb 008h, 00ch
	vk "PLAYER"
	defb 0feh
	defb 008h, 014h            ; 0x14 = HP-bar icon column
	vk "ENEMY"
	defb 0feh
	defb 0b0h, 000h, 050h, 030h, 0feh  ; enemy HP-bar cell
	defb 0d4h, 000h, 040h, 030h, 0feh  ; player HP-bar cell
	defb 06ch, 000h
	vk "STAGE"
	defb 030h, 0ffh            ; + number tile
	defb 060h, 038h
	vk "STAGE"
	defb 000h, 000h, 000h, 0ffh
; --- title_layout (0x4C3F-0x4D0E): tile-id streams for the title screen -----
;  Consumed by tile_layout_draw (seg1 0x7B39).  0xFF = end of stream; 0xFE =
;  next row (following byte is added to D, E += 8); any other byte is a tile
;  id blitted at the current (D,E).  title_build (0x4D4E) picks which pair to
;  draw from the MSX region: the low nibble of BIOS ID byte 0x002B is the
;  character set (0 = Japanese, non-zero = international/other), so the game
;  shows the Japanese title on a Japanese machine and the export title
;  elsewhere (the sole regional difference in the ROM):
;    nibble 0 (Japanese)     : title_castle + title_logo_jp   ("Akumajo Dracula")
;    nibble != 0 (intl/other): title_logo_intl + title_castle ("VAMPIRE KILLER")
;  The tile bitmaps for each logo are loaded to VRAM separately by
;  title_load_tiles (0x5A02), which selects on the same 0x002B nibble.
;  (Verified by rendering both tilesets from the ROM: 0x11260 spells VAMPIRE
;  KILLER, 0x10EA0 is the Akumajo Dracula kana.)
title_castle:                  ; 0x4C3F - castle emblem, drawn in BOTH regions
	defb 002h,0feh,0f8h,003h,004h,0feh,0f8h,005h,006h,007h,008h
	defb 0feh,000h,009h,00ah,00bh,00ch,00dh,0feh,0f8h,00eh,00fh
	defb 001h,001h,010h,011h,0ffh
title_logo_jp:                 ; 0x4C5A - Japanese title ("Akumajo Dracula" kana)
	defb 02fh,02fh,0feh,0b0h,016h,017h,018h,015h,001h,001h,001h,001h
	defb 028h,02fh,02fh,012h,013h,014h,015h,0feh,000h,026h,023h,024h
	defb 025h,001h,001h,001h,001h,019h,01ah,01bh,022h,023h,024h,025h
	defb 0feh,000h,01ch,01dh,01eh,01fh,001h,001h,001h,001h,029h,02ah
	defb 02bh,01ch,01dh,01eh,01fh,0feh,000h,020h,021h,02ch,001h,001h
	defb 001h,001h,001h,02dh,02eh,027h,020h,021h,02ch,0ffh
title_logo_intl:               ; 0x4CA0 - export title ("VAMPIRE KILLER")
	defb 067h,012h,013h,014h,015h,016h,017h,018h,019h,01ah,01bh,01ch
	defb 01dh,01eh,01fh,020h,021h,0feh,008h,022h,023h,024h,025h,026h
	defb 027h,028h,029h,02ah,02bh,02ch,02dh,02eh,02fh,030h,031h,0feh
	defb 000h,032h,033h,034h,035h,036h,037h,038h,039h,03ah,03bh,03ch
	defb 03dh,03eh,03fh,040h,041h,0feh,000h,0feh,0f8h,042h,043h,044h
	defb 045h,046h,047h,048h,047h,049h,04ah,04bh,04ch,04dh,0feh,000h
	defb 052h,053h,054h,055h,056h,057h,060h,057h,060h,061h,05bh,05ch
	defb 05dh,000h,000h,065h,065h,0feh,000h,04eh,04fh,050h,051h,058h
	defb 059h,05ah,059h,068h,069h,06ah,05eh,05fh,062h,063h,064h,063h
	defb 064h,066h,0ffh
; --- Title / front-end text (drawn by title_build).  vk "TEXT" is ASCII-0x10;
;     leading numbers are VDP position/attribute prefixes, 0xFE/0xFF separators.
l4d0fh:
	defb 048h, 088h, 02ah, 000h
	vk "KONAMI 1986"
	defb 0feh
	defb 048h, 0a0h
	vk "PUSH SPACE KEY"
	defb 0ffh
l4d30h:
	defb 048h, 0a0h, 000h, 000h
	vk "PLAY START"
	defb 000h, 000h, 0ffh
l4d41h:
	defb 058h, 058h
	vk "GAME  OVER"
	defb 0ffh
; title_build (0x4D4E) - build/redraw the title screen.  Regional: reads the
; MSX character-set nibble (0x002B) to pick the Japanese vs export title logo
; (see title_layout above); title_load_tiles (0x5A02) loads the matching glyphs.
title_build:
	call vdp_screen_off
	call vram_clear_page
	call vdp_cmd_wait
	call palette_hud_load
	ld b,003h
	ld de,06606h
l4d5fh:
	ld a,00fh
	call palette_set
	dec e
	dec e
	ld a,d
	sub 022h
	ld d,a
	ld hl,00800h
l4d6dh:
	dec hl
	ld a,h
	or l
	jr nz,l4d6dh
	djnz l4d5fh
	ld b,000h
	ld c,007h
	call WRTVDP
	ld a,00fh
	ld de,00700h
	call palette_set
	call sat_vram_hide
	call hud_font_load
	call title_load_tiles  ; load region-specific title glyphs into VRAM
	ld hl,00010h
	ld bc,00068h
	ld a,0ffh
	ld d,000h
	call vdp_hmmv
	ld hl,00516h
	call title_fill_strips
	ld hl,00569h
	call title_fill_strips
	ld a,(0002bh)          ; MSX BIOS ID byte 0x002B...
	and 00fh               ; ...low nibble = character set (0 = Japanese)
	jr nz,title_layout_intl           ; non-zero -> international title (VAMPIRE KILLER)
	ld de,0a818h           ; Japanese layout: castle...
	ld hl,title_castle
	call tile_layout_draw
	ld de,0a038h           ; ...+ "Akumajo Dracula" kana
	ld hl,title_logo_jp
	call tile_layout_draw
	call title_sat_init
	jr title_layout_finish
title_layout_intl:                        ; international/other machine
	ld de,03828h           ; "VAMPIRE KILLER" logo...
	ld hl,title_logo_intl
	call tile_layout_draw
	ld de,0b830h           ; ...+ castle
	ld hl,title_castle
	call tile_layout_draw
title_layout_finish:
	ld hl,l4d0fh
	call hud_string_draw
	jp vdp_screen_on
vram_clear_page1:
	ld d,001h
	jr vram_clear_page_go
vram_clear_page:
	ld d,000h
vram_clear_page_go:
	ld hl,00000h
	ld bc,00000h
	xor a
	jp vdp_hmmv
attract_run_init:
	ld hl,0c420h
	ld de,0c421h
	ld bc,01bdfh
	xor a
	ld (hl),a
	ldir
	ld (0c007h),a
	ld (0cf3dh),a
	ld (0d001h),a
	ld (0d002h),a
	inc a
	ld (0c413h),a
	ld (0c411h),a
	ld (0d000h),a
	ld (0cf3ah),a
	ld a,020h
	ld (0c415h),a          ; Simon health = full (0x20)
	ld a,080h
	ld (0c418h),a          ; enemy/boss energy meter = full (0x80)
	call 062d7h
	call 062edh
	jp hud_draw_all
attract_tick:
	call play_tick
	ld a,(0c41bh)
	and a
	ret z
	call conn_lookup_paged
	jp 062fch
l4e35h:
	ld hl,0cf3ah
	dec (hl)
	jr z,l4e4dh
l4e3bh:
	ld a,(0cf3bh)
	cp 0ffh
	jr z,l4e48h
	ld hl,0c007h
	jp input_edge_play
l4e48h:
	xor a
	ld (0c413h),a
	ret
l4e4dh:
	inc hl
	inc hl
	ld c,(hl)
	inc (hl)
	ld de,l4e64h
	ld l,c
	ld h,000h
	add hl,hl
	add hl,de
	ld a,(hl)
	ld (0cf3ah),a
	inc hl
	ld a,(hl)
	ld (0cf3bh),a
	jr l4e3bh
l4e64h:
	ld d,000h
	dec hl
	ex af,af'
	rlca
	jr l4e82h
	ex af,af'
	ex af,af'
	jr l4ec4h
	ex af,af'
	inc b
	nop
	djnz $+6
	add hl,bc
	nop
	ld b,c
	ld hl,02922h
	rlca
	add hl,sp
	dec h
	add hl,hl
	ld hl,(00408h)
	add hl,hl
l4e82h:
	ld c,l
	ex af,af'
	rrca
	nop
	ld a,(de)
	inc b
	add hl,bc
	inc d
	rrca
	inc b
	rlca
	nop
	ld e,(hl)
	ex af,af'
	ld c,000h
	inc d
	inc b
	rrca
	nop
	ld c,h
	ld hl,0ff01h
; intro_actors_frame (seg0 0x4E9A): intro C800 tick + SAT + pattern blit.
; Called from state_intro while Simon walks up to the castle.
intro_actors_frame:
	call c800_tick
	call c800_sat_build
	call c800_sat_emit
	jp pattern_shadow_blit
; intro_spawn_sky (seg0 0x4EA6): one actor_intro_sky at (X=0xE0, Y=0x48).
intro_spawn_sky:
	ld c,actor_intro_sky
	ld de,0e048h
	jp spawn_actor
intro_sky_init:
	ld (ix+006h),001h
	ld (ix+00bh),094h      ; shape_intro_sky
	ld (ix+00eh),a
	ret
intro_sky_go:
	xor a
	ld (ix+008h),a
	ld (ix+007h),a
	ld de,0ffe0h
l4ec4h:
	jp actor_set_xvel
; intro_spawn_sky_ab (seg0 0x4EC7): sky_a at (0x90,0x38) and sky_b at (0x30,0x68).
intro_spawn_sky_ab:
	ld c,actor_intro_sky_a
	ld de,09038h
	call spawn_actor
	ld c,actor_intro_sky_b
	ld de,03068h
	jp spawn_actor
intro_sky_ab_init:
	ld hl,0ffe0h
	ld de,00000h
	bit 0,(ix+000h)
	jr z,l4ee9h
	ld hl,00020h
	ld de,0fff0h
l4ee9h:
	call actor_set_yvel
	ex de,hl
	call actor_set_xvel
	ld (ix+006h),001h
	ld (ix+00bh),092h      ; shape_intro_sky_a
	xor a
	ld (ix+010h),a
	ld (ix+00eh),a
	ret
intro_sky_ab_go:
	inc (ix+010h)
	ld a,(ix+010h)
	cp 004h
	ret nz
	ld (ix+010h),000h
	inc (ix+011h)
	ld (ix+00bh),092h      ; shape_intro_sky_a
	bit 0,(ix+011h)
	ret z
	ld (ix+00bh),093h      ; shape_intro_sky_b
	ret
; intro_spawn_simon (seg0 0x4F1E): one actor_intro_simon at (X=0xF0, Y=0xC0).
intro_spawn_simon:
	ld c,actor_intro_simon
	ld de,0f0c0h
	jp spawn_actor
intro_simon_init:
	ld (ix+00bh),098h      ; shape_intro_simon_1
	xor a
	ld (ix+001h),a
	ld (ix+013h),a
	ld (ix+014h),a
	ld (ix+00eh),a
	ld (ix+006h),001h
	ret
intro_simon_go:
	ld a,(ix+001h)
	dec a
	jr z,intro_simon_idle
	call intro_simon_stride
	xor a
	ld (ix+00ah),0ffh
	ld (ix+009h),080h
	ld (ix+008h),a
	ld (ix+007h),a
	ld a,(ix+005h)
	cp 080h
	ret nc
	inc (ix+001h)
	ret
intro_simon_idle:              ; (0x4F5E) X < 0x80: stop, pose 0x97
	ld (ix+006h),000h
	ld (ix+00bh),097h      ; shape_intro_simon_0
	ret
; intro_simon_stride (seg0 0x4F67): walk-cycle pose from ix+13/14.
; ix+14 += 0x90; carry bumps ix+13.  Pose = tbl[(ix+13 >> 2) & 3].
intro_simon_stride:
	ld a,(ix+014h)
	add a,090h
	ld (ix+014h),a
	jr nc,l4f74h
	inc (ix+013h)
l4f74h:
	ld a,(ix+013h)
	rra
	rra
	and 003h
	ld hl,intro_simon_stride_tbl
	call ADD_HL_A
	ld a,(hl)
	ld (ix+00bh),a
	ret
intro_simon_stride_tbl:        ; (0x4F86) shapes 0x98,0x99,0x9A,0x99
	defb 098h,099h,09ah,099h
; --- room_map_load (0x4F8A) - expand the current room into 0xD100 ----------
;  HL = 0xD100 (destination tile-name map), B = world row (0xD000), C = column
;  (0xD001).  room_map_build expands the room's metatiles into 0xD100..0xD3FF.
room_map_load:
	ld hl,0d100h
	ld a,(0d000h)
	ld b,a
	ld a,(0d001h)
	ld c,a
	jp room_map_build
; --- playfield_draw (0x4F98) - paint the 32x22 playfield to the screen ------
;  Walks 0xD140 (map row 2, skipping the 2 HUD nametable rows) as 22 rows x
;  32 cols. Dest DE starts at X=0 Y=0x20: the HUD (score + meters) is 32px,
;  only 16px of it lives in D100 rows 0-1. Tile blit advances 8px/cell,
;  8px/row. Actor/SAT Y=0 is the top of the screen; Y=0x20 is nametable
;  row 2. map_cell_at uses (Y-0x10)>>3, so Y=0x20 -> row 2.
playfield_draw:
	ld hl,0d140h
	ld de,00020h
	ld b,016h
l4fa0h:
	push bc
	ld b,020h
l4fa3h:
	ld a,(hl)
	call tile_blit
	inc hl
	ld a,d
	add a,008h
	ld d,a
	djnz l4fa3h
	pop bc
	ld a,e
	add a,008h
	ld e,a
	djnz l4fa0h
	ret
; --- room_map_build (0x4fb6) - expand a room's metatiles into the 0xD100 map -
;  In: HL = dest (0xD100), B = world row (0xD000), C = column (0xD001).
;  A room = 8 wide x 6 tall METATILES; each metatile = 4x4 tile ids (16 bytes).
;  The build pages the map-data banks into the upper windows (mapper regs at
;  0x6000/0x8000/0xA000; entity_tbl_end is the 0x6000 mapper write).
;  then for the normal case (0xC41A==0):
;    stream ptr = mtile_roomptr[ mtile_rowbase[row] + col ]  (seg11 @ 0x6000)
;       stream = 48 metatile ids (row-major, 8x6).
;       rooms-in-row = rowbase[row+1]-rowbase[row] (stage 18: use minimap count).
;    def base  = mtile_defbase[row]  (seg11 0x7EBB; row 1 -> mtile_defs_s01
;       at 0x80B1 in seg12).  def(id) = 16 bytes at defbase + id*16.
;  (0xC41A!=0 uses mtile_stream_intro and mtile_def_intro in seg13.)
;  The 16 def bytes are copied as a 4x4 block (4 tiles, +0x20 to next map row).
;  Banks are restored (0x6000/0x8000/0xA000 <- 1/2/3) before returning.
;  See tools/roomperm.py for a byte-exact reimplementation of this decoder.
room_map_build:
	ld (0c5d5h),hl         ; 0xC5D5 = dest map ptr (0xD100)
	ld (0c5d7h),bc         ; 0xC5D7 = column, 0xC5D8 = world row
	di
	ld hl,0f0f1h           ; RAM shadow of the mapper bank registers
	ld a,00bh
	ld (entity_tbl_end),a  ; page bank 0x0b -> 0x6000 window (map tables/streams)
	ld (hl),a
	inc l
	inc a
	ld (08000h),a          ; page bank 0x0c -> 0x8000 window (row-1 metatile defs)
	ld (hl),a
	inc l
	inc a
	ld (0a000h),a          ; page bank 0x0d -> 0xA000 window (default metatile defs)
	ld (hl),a
	ei
	ld a,(0c41ah)
	ld hl,mtile_stream_intro
	and a
	jr nz,l4ff7h
	ld a,(0c5d8h)
	ld hl,mtile_rowbase
	call ADD_HL_A
	ld l,(hl)
	ld a,(0c5d7h)
	add a,l
	ld h,000h
	ld l,a
	add hl,hl
	ld de,mtile_roomptr
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
l4ff7h:
	ld de,(0c5d5h)
	ld a,006h
l4ffdh:
	ex af,af'
	ld b,008h
l5000h:
	ld a,(hl)
	push de
	exx
	push af
	ld a,(0c41ah)
	and a
	ld bc,mtile_def_intro
	jr nz,l501ah
	ld a,(0c5d8h)
	add a,a
	ld hl,mtile_defbase
	call ADD_HL_A
	ld c,(hl)
	inc hl
	ld b,(hl)
l501ah:
	pop af
	ld h,000h
	ld l,a
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,bc
	ld bc,01cffh
	pop de
	ldi
	ldi
	ldi
	ldi
	ld a,b
	add a,e
	ld e,a
	ldi
	ldi
	ldi
	ldi
	ld a,b
	add a,e
	ld e,a
	ldi
	ldi
	ldi
	ldi
	ld a,b
	add a,e
	ld e,a
	ldi
	ldi
	ldi
	ldi
	exx
	inc hl
	inc e
	inc e
	inc e
	inc de
	djnz l5000h
	ex de,hl
	ld bc,00060h
	add hl,bc
	ex de,hl
	ex af,af'
	dec a
	jp nz,l4ffdh
	di
	push hl
	ld hl,0f0f1h
	ld a,001h
	ld (entity_tbl_end),a
	ld (hl),a
	inc a
	ld (08000h),a
	inc hl
	ld (hl),a
	inc a
	ld (0a000h),a
	inc hl
	ld (hl),a
	pop hl
	ei
	ret
psg_init:
	ld a,0bch
	ld (0c097h),a
	xor a
	ld (0c0a5h),a
	ld (0c0a6h),a
	ld (0c0a7h),a
sound_halt:
	xor a
	ld (0c096h),a
	ld (0c098h),a
	ld (0c0a8h),a
	ld hl,sound_idle
	ld (0c010h),hl
	ld (0c012h),hl
	ld (0c014h),hl
	ld (0c016h),hl
sound_nop:
	ret
; play_sound (seg0 0x50A6): queue a sound.  A = id.
;   0         stop
;   1..0x7F   sfx (sfx_ptr/sfx_tbl; portal flash = 0x15)
;   0x80..8F  music (music_ptr 6-byte records, 3 channel ptrs)
;   0xFB      overlay (sound_ch_fb / snd_fb_seq); 0xFC restores
;   0xFD      overlay (sound_ch_fd / snd_fd_seq); 0xFE restores
;   0xFF      fade timer C0A5=0x3A
; Pages banks 0x0E/0x0F into 0x8000/0xA000, then restores 1/2/3.
play_sound:
	push hl
	push de
	push bc
	push af
	di
	ld a,00eh
	ld (08000h),a
	ld (0f0f2h),a
	ei
	di
	ld a,00fh
	ld (0a000h),a
	ld (0f0f3h),a
	ei
	pop af
	di
	or a
	jp z,play_sound_stop
	cp 0fbh
	jp nc,play_sound_special
	or a
	jp p,play_sound_sfx
	ld de,0c01ch
	ld hl,sound_ch_template
	ld bc,00014h
	ldir
	ld hl,sound_ch_template
	ld bc,00014h
	ldir
	ld hl,sound_ch_template
	ld bc,00014h
	ldir
	and 07fh
	rlca
	ld e,a
	rlca
	add a,e
	ld hl,music_ptr
	add a,l
	ld l,a
	jr nc,l50f6h
	inc h
l50f6h:
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (0c01ch),de
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (0c030h),de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld (0c044h),de
	ld hl,sound_ch_a
	ld (0c010h),hl
	ld hl,sound_ch_b
	ld (0c012h),hl
	ld hl,sound_ch_c
	ld (0c014h),hl
	xor a
	ld (0c096h),a
	ld hl,sound_nop
	ld (0c016h),hl
	ld a,(0c098h)
	and 0fdh
	ld (0c098h),a
play_sound_clear:
	xor a
	ld (0c0a5h),a
	ld (0c0a6h),a
	ld (0c0a8h),a
	ld a,007h
	ld (0c0a7h),a
play_sound_exit:
	di
	push hl
	ld hl,0f0f1h
	ld a,001h
	ld (entity_tbl_end),a
	ld (hl),a
	inc a
	ld (08000h),a
	inc hl
	ld (hl),a
	inc a
	ld (0a000h),a
	inc hl
	ld (hl),a
	pop hl
	ei
	pop bc
	pop de
	pop hl
	ret
sound_ch_template:
	nop
	nop
	ld bc,00000h
	nop
	nop
	nop
	nop
	ld bc,00000h
	nop
	nop
	ld bc,00001h
	nop
	nop
	nop
play_sound_sfx:
	ld c,a
	ld a,(0c0a8h)
	or a
	jp nz,play_sound_exit
	ld a,(0c096h)
	cp c
	jp z,play_sound_sfx_go
	jp nc,play_sound_exit
play_sound_sfx_go:
	ld a,c
	ld (0c096h),a
	ld de,0c058h
	ld hl,sound_ch_template
	ld bc,00014h
	ldir
	rlca
	ld hl,sfx_ptr
	add a,l
	ld l,a
	jr nc,l519bh
	inc h
l519bh:
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld (0c064h),de
	ld hl,sound_sfx
	ld (0c016h),hl
	jp play_sound_exit
play_sound_stop:
	call sound_halt
	jp play_sound_exit
play_sound_special:
	jp z,play_sound_fb
	cp 0fch
	jp z,play_sound_fc
	cp 0fdh
	jp z,play_sound_fd
	cp 0feh
	jp z,play_sound_fe
	ld a,03ah
	ld (0c0a5h),a
	jp play_sound_exit
play_sound_fd:
	ld a,(0c098h)
	or 001h
	ld (0c098h),a
	ld a,(0c0a5h)
	ld (0c099h),a
	ld a,(0c0a6h)
	ld (0c09ah),a
	ld a,(0c097h)
	ld (0c09bh),a
	ld a,0bfh
	ld (0c097h),a
	xor a
	call RDPSG
	ld (0c09ch),a
	ld a,001h
	call RDPSG
	ld (0c09dh),a
	ld a,008h
	call RDPSG
	ld (0c09eh),a
	ld a,009h
	call RDPSG
	ld (0c09fh),a
	ld a,00ah
	call RDPSG
	ld (0c0a0h),a
	xor a
	ld (0c094h),a
	ld a,005h
	ld (0c095h),a
	ld hl,sound_ch_fd
	ld (0c01ah),hl
	ld de,0c080h
	ld hl,sound_ch_template
	ld bc,00014h
	ldir
	ld hl,snd_fd_seq
	ld (0c080h),hl
	jp play_sound_clear
play_sound_fe:
	ld a,(0c098h)
	and 0feh
	ld (0c098h),a
	ld a,(0c099h)
	ld (0c0a5h),a
	ld a,(0c09ah)
	ld (0c0a6h),a
	ld a,(0c09bh)
	ld (0c097h),a
	ld a,(0c09ch)
	ld e,a
	xor a
	call WRTPSG
	ld a,(0c09dh)
	ld e,a
	ld a,001h
	call WRTPSG
	ld a,(0c09eh)
	ld e,a
	ld a,008h
	call WRTPSG
	ld a,(0c09fh)
	ld e,a
	ld a,009h
	call WRTPSG
	ld a,(0c0a0h)
	ld e,a
	ld a,00ah
	call WRTPSG
	jp play_sound_exit
play_sound_fb:
	ld a,(0c098h)
	or 002h
	ld (0c098h),a
	ld a,(0c097h)
	ld (0c0a1h),a
	ld a,(0c096h)
	or a
	jp nz,l5297h
	ld a,0bfh
	jp l529ch
l5297h:
	ld a,(0c097h)
	or 01bh
l529ch:
	ld (0c097h),a
	xor a
	call RDPSG
	ld (0c0a2h),a
	ld a,001h
	call RDPSG
	ld (0c0a3h),a
	ld a,008h
	call RDPSG
	ld (0c0a4h),a
	ld hl,sound_ch_fb
	ld (0c018h),hl
	ld de,0c06ch
	ld hl,sound_ch_template
	ld bc,00014h
	ldir
	ld hl,snd_fb_seq
	ld (0c078h),hl
	jp play_sound_exit
play_sound_fc:
	ld a,(0c098h)
	and 0fdh
	ld (0c098h),a
	ld a,(0c096h)
	or a
	ld a,(0c0a1h)
	jp z,l52f0h
	ld b,a
	ld a,(0c097h)
	or 0dbh
	and b
	ld b,a
	ld a,(0c097h)
	and 024h
	or b
l52f0h:
	ld (0c097h),a
	ld a,(0c0a2h)
	ld e,a
	xor a
	call WRTPSG
	ld a,(0c0a3h)
	ld e,a
	ld a,001h
	call WRTPSG
	ld a,(0c0a4h)
	ld e,a
	ld a,008h
	call WRTPSG
	jp play_sound_exit
	ld a,(0c0a6h)
	cp 0f8h
	ret
; logo_font_load (seg0 0x5316): page seg13 and blit the 8x8 1bpp Konami-logo
; font (logo_font at 0xBE59, 52 glyphs, tile ids 0x01-0x34) onto page 0 at
; Y=0 in inks 1/2/3.  Falls through into page_play_banks.  Called from
; konami_logo_draw; tile_string_draw then copies those cells with no HUD
; +0x38, so ids 0x2C-0x2E are logo wordmark tiles, not hud_font '<' '=' '>'.
logo_font_load:
	call page_map_banks
	ld hl,logo_font
	ld de,00800h           ; X=8, Y=0 (id 0x00 at X=0 is blank)
	ld bc,00d01h           ; B=13 glyphs, ink 1
	call glyph_blit_run
	ld hl,logo_font_ink2
	ld de,07000h           ; X=0x70, Y=0
	ld bc,00d02h           ; B=13 glyphs, ink 2
	call glyph_blit_run
	ld hl,logo_font_ink3
	ld de,0d800h           ; X=0xD8, Y=0 (wraps to Y=8 at id 0x20)
	ld bc,01a03h           ; B=26 glyphs, ink 3
	call glyph_blit_run
; --- page_play_banks - restore the default bank set after a graphics load: seg 1 @
;     0x6000 (page 1b), seg 2 @ 0x8000 (page 2a), seg 3 @ 0xA000 (page 2b).
;     These are the banks the running game code normally expects paged in.
page_play_banks:
	di
	push hl
	ld hl,0f0f1h
	ld a,001h               ; seg 1 -> page 1b (0x6000)
	ld (entity_tbl_end),a
	ld (hl),a
	inc a
	ld (08000h),a
	inc hl
	ld (hl),a
	inc a
	ld (0a000h),a
	inc hl
	ld (hl),a
	pop hl
	ei
	ret
page_sound_banks:
	di
	ld hl,0f0f2h
	ld a,00eh
	ld (08000h),a
	ld (hl),a
	inc l
	inc a
	ld (0a000h),a
	ld (hl),a
	ei
	ret
; --- page_map_banks - page in the "level/sprite graphics" bank set: seg 11 @ 0x6000
;     (page 1b), seg 12 @ 0x8000 (page 2a), seg 13 @ 0xA000 (page 2b).  Shadow
;     copies kept at 0xF0F1-0xF0F3 so int_handler can restore them.  Sources
;     like 0xA319 read after this call therefore live in segment 13.
page_map_banks:
	di
	ld hl,0f0f1h
	ld a,00bh               ; seg 11 -> page 1b (0x6000)
	ld (entity_tbl_end),a
	ld (hl),a
	inc l
	inc a
	ld (08000h),a
	ld (hl),a
	inc l
	inc a
	ld (0a000h),a
	ld (hl),a
	ei
	ret
; --- page_title_banks - page in the front-end/title graphics bank set: seg 9 @ 0x8000
;     (page 2a), seg 10 @ 0xA000 (page 2b).  Page 1b is left untouched.  Sources
;     like 0xA0EA read after this call live in segment 10.
page_title_banks:
	di
	ld hl,0f0f2h
	ld a,009h               ; seg 9 -> page 2a (0x8000)
	ld (08000h),a
	ld (hl),a
	inc l
	inc a
	ld (0a000h),a
	ld (hl),a
	ei
	ret
page_tileset_late:
	di
	ld hl,0f0f2h
	ld a,007h
	ld (08000h),a
	ld (hl),a
	inc l
	inc a
	ld (0a000h),a
	ld (hl),a
	ei
	ret
; --- page_tileset_banks - page in the level-tileset banks: seg 4 @ 0x6000 (page 1b),
;     seg 5 @ 0x8000 (page 2a), seg 6 @ 0xA000 (page 2b).  The HUD weapon/key
;     tiles at CPU 0xB9C8 and actor_shape_ptr at 0xB473 are read from segment 6 after this call.
page_tileset_banks:
	di
	ld hl,0f0f1h
	ld a,004h               ; seg 4 -> page 1b (0x6000)
	ld (entity_tbl_end),a
	ld (hl),a
	inc l
	inc a                   ; seg 5 -> page 2a (0x8000)
	ld (08000h),a
	ld (hl),a
	inc l
	inc a                   ; seg 6 -> page 2b (0xA000)
	ld (0a000h),a
	ld (hl),a
	ei
	ret
; hud_font_load (seg0 0x53BD): page seg7/8 and blit the 8x8 1bpp HUD/title
; font (hud_font at 0xBD80, 48 glyphs '0'-'_') into SCREEN 5 page 1 at
; Y=0x40, ink 0x0E.  The all-1s glyph at hud_font_solid is first painted
; ink 0 at (0,0) so vk space (0x00) HMMM-copies a blank.  Then one 8x8
; 4bpp tile at hud_tile_bf00.  Called from title_build; the atlas stays
; in page 1 through play (below the playfield tileset).
hud_font_load:
	call page_tileset_late
	ld de,00000h
	ld c,000h
	ld hl,hud_font_solid
	call glyph_blit
	ld de,00040h
	ld hl,hud_font
	ld bc,0300eh
	call glyph_blit_run
	ld hl,hud_tile_bf00
	ld de,0a440h
	ld b,001h
	call vram_blit_tile_run
	jp page_play_banks
; credits_font_load (seg0 0x53E5): page segs 14/15 and blit the 8x8 1bpp
; ending-credits font (digits+punct, then A-Z) into SCREEN 5 via glyph_blit_run.
; Called from credits_init (post-Dracula script player). credits_font_blit
; (0x53E8) skips the pager when those banks are already in.
credits_font_load:
	call page_sound_banks         ; page seg14/15
credits_font_blit:
	ld de,08040h
	ld hl,credits_font
	ld bc,00e0eh           ; B=14 glyphs 0-9 . ' : ,
	call glyph_blit_run
	ld de,00848h
	ld hl,credits_font_az
	ld bc,01a0eh           ; B=26 glyphs A-Z
	call glyph_blit_run
	jp page_play_banks
; door_blit_tiles (0x5403): paint the 6-tile door graphic.  HL is 0xC5AC on
; entry (from door_anim_tick when it was 0xFF).  ld de,(0xC5AD) loads E=Y
; (0xC5AD) and D=X (0xC5AE); E+=8 walks DOWN the door.  Source of those
; coords is seg13 door_tbl via door_load_coords, not a placed 0x1F object.
door_blit_tiles:
	ld (hl),001h           ; 0xC5AC := 1 (door armed / graphic on screen)
	ld de,(0c5adh)         ; E = door Y (0xC5AD), D = door X (0xC5AE)
	ld hl,door_tile_ptr
	ld b,006h              ; 6 stacked 8x8 tiles
l540eh:
	push bc
	push de
	push hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld bc,00808h
	xor a
	call vdp_hmmc
	pop hl
	inc hl
	inc hl
	pop de
	ld a,e
	add a,008h             ; next tile 8px down (Y)
	ld e,a
	pop bc
	djnz l540eh
	ret
; --- door graphic (0x5428-0x5493) -------------------------------------------
;  door_blit_tiles (0x5403) walks door_tile_ptr as 6 words, HMMC'ing each 8x8
;  4bpp tile at (X, Y+8n): an 8x48 vertical bar, 4px wide (colour 3 with a
;  0xC highlight down both edges), widened into a joint on three of the six
;  tiles.  Only three distinct tiles are stored and the table repeats them.
;  door_anim_tick (seg2 0x914E) then slides an 8x47 VRAM column to open it.
door_tile_ptr:                 ; 0x5428 - 6 tile pointers, top to bottom
	defw door_tile_joint, door_tile_shaft, door_tile_joint
	defw door_tile_shaft, door_tile_shaft, door_tile_joint_end
door_tile_joint:               ; 0x5434 - joint on rows 2-6
	defb 000h,0c3h,03ch,000h ; ..C33C..
	defb 000h,0c3h,03ch,000h ; ..C33C..
	defb 00ch,0c3h,03ch,0c0h ; .CC33CC.
	defb 003h,033h,033h,030h ; .333333.
	defb 003h,033h,033h,030h ; .333333.
	defb 003h,033h,033h,030h ; .333333.
	defb 003h,003h,030h,030h ; .3.33.3.
	defb 000h,0c3h,03ch,000h ; ..C33C..
door_tile_shaft:               ; 0x5454 - plain shaft, all 8 rows
	defb 000h,0c3h,03ch,000h ; ..C33C..
	defb 000h,0c3h,03ch,000h ; ..C33C..
	defb 000h,0c3h,03ch,000h ; ..C33C..
	defb 000h,0c3h,03ch,000h ; ..C33C..
	defb 000h,0c3h,03ch,000h ; ..C33C..
	defb 000h,0c3h,03ch,000h ; ..C33C..
	defb 000h,0c3h,03ch,000h ; ..C33C..
	defb 000h,0c3h,03ch,000h ; ..C33C..
door_tile_joint_end:           ; 0x5474 - joint one row up, blank last row
	defb 000h,0c3h,03ch,000h ; ..C33C..
	defb 00ch,0c3h,03ch,0c0h ; .CC33CC.
	defb 003h,033h,033h,030h ; .333333.
	defb 003h,033h,033h,030h ; .333333.
	defb 003h,033h,033h,030h ; .333333.
	defb 003h,003h,030h,030h ; .3.33.3.
	defb 000h,0c3h,03ch,000h ; ..C33C..
	defb 000h,000h,000h,000h ; ........
; hud_cache_load (seg0 0x5494): stage page-1 caches for HUD popups and
; playfield overlays — bonus 16x16s, spike bar, weapon/key icons, candle
; flames, then the five recolored vendor 32x32s at Y=0xA0.
hud_cache_load:
	call page_title_banks
	ld hl,bonus_hud_tiles  ; bonus ids 1-20 (16x16 4bpp)
	ld de,0a800h           ; VRAM page 1 Y=0x50 (wraps to Y=0x60 after 16)
	ld b,014h
	call vram_blit_tile16_run
	ld hl,bonus_hud_potion ; potion bottle (bonus id 22) -> VRAM (X=80,Y=96)
	ld de,0b028h
	ld b,001h
	call vram_blit_tile16_run
; Assemble the 32x16 spike-bar hazard in page 1 at (0x80, 0x70); hazard_tick
; (seg2 0x8FD6) HMMMs it from there into the playfield.
	ld hl,spike_bar_mount  ; bracket, centred over the bar at (X=140, Y=112)
	ld de,08c70h
	ld bc,00804h
	ld a,001h
	call vdp_hmmc
	ld de,08074h           ; bar+spike unit tiled x4 -> X=128..159, Y=116
	ld b,004h
l54c0h:
	push bc
	push de
	ld hl,spike
	ld bc,00808h
	ld a,001h
	call vdp_hmmc
	pop de
	pop bc
	ld a,d
	add a,008h
	ld d,a
	djnz l54c0h
	call page_tileset_banks         ; seg 6 @ 0xA000 for the next copy
	ld hl,hud_weapon_key_tiles  ; bonus 0x17-0x1E: keys, chest, weapons, holy
	ld de,0b030h           ; VRAM page 1 Y=0x60 X=96
	ld b,008h
	call vram_blit_tile16_run
	ld hl,candle_0         ; 4 playfield flame frames at Y=0x70; B=5 includes 0xFF pad
	ld de,0b800h
	ld b,005h
	call vram_blit_tile16_run
	call page_title_banks
	call vendor_cache_load
	jp page_play_banks
; vendor_cache_load (seg0 0x54F7): five 32x32 copies of vendor_tiles into
; page-1 Y=0xA0 at X=0,32,64,96,128.  Nibble 0xF is replaced from
; vendor_recolor_tbl (magenta/red/grey/white/blue).  vendor_blit LMMMs one
; slot onto the playfield; event-6 dracula_portrait_parts_load overwrites
; this cache (no vendors in that room).
vendor_cache_load:
	ld ix,vendor_recolor_tbl
	ld de,0d000h           ; VRAM page 1 Y=0xA0 X=0
	ld b,005h
l5500h:
	push bc
	push de
	call vendor_recolor_copy
	call vendor_blit_32
	pop de
	ld a,010h
	call ADD_DE_A          ; next variant 32px to the right
	pop bc
	inc ix
	djnz l5500h
	ret
; vendor_recolor_copy (0x5514): 256 bytes vendor_tiles -> 0xE800, swapping
; each 0xF nibble for (ix+0)&0xF; then 32 zero bytes at 0xE900 (empty tile).
vendor_recolor_copy:
	exx
	ld de,0e800h
	ld hl,vendor_tiles
	ld b,000h              ; 256 bytes
l551dh:
	push bc
	ld a,(hl)
	inc hl
	ld b,a
	rrca
	rrca
	rrca
	rrca
	and 00fh
	cp 00fh
	jr nz,l552eh
	and (ix+000h)
l552eh:
	add a,a
	add a,a
	add a,a
	add a,a
	ld c,a
	ld a,b
	and 00fh
	cp 00fh
	jr nz,l553dh
	and (ix+000h)
l553dh:
	or c
	ld (de),a
	inc de
	pop bc
	djnz l551dh
	xor a
	ld (de),a
	ld h,d
	ld l,e
	inc de
	ld bc,0001fh
	ldir
	exx
	ret
; vendor_blit_32 (0x554F): 4x4 of 8x8 tiles from vendor_tile_ptr into VRAM DE.
vendor_blit_32:
	ld hl,vendor_tile_ptr
	ld b,004h
l5554h:
	push bc
	push de
	ld b,004h
l5558h:
	push bc
	push hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	call vram_blit_tile8
	ld a,004h
	call ADD_DE_A
	pop hl
	inc hl
	inc hl
	pop bc
	djnz l5558h
	pop de
	ld a,d
	add a,004h
	ld d,a
	pop bc
	djnz l5554h
	ret
; vendor_tile_ptr (0x5575): 4x4 source words in the 0xE800 scratch (row-major).
; 0xE900 is the zero tile; 0xE800+n*0x20 are vendor_tiles 0..7.  Empty top
; row and the right/bottom gaps make the sitting figure 24x24 in a 32x32.
vendor_tile_ptr:
	defw 0e900h, 0e900h, 0e900h, 0e900h
	defw 0e900h, 0e800h, 0e820h, 0e840h
	defw 0e900h, 0e860h, 0e880h, 0e900h
	defw 0e8a0h, 0e8c0h, 0e8e0h, 0e900h
; vendor_recolor_tbl (0x5595): cloak colour for C70B 0..4 (HUD-fixed indices).
; 3=magenta (give/take hearts), 8=red (hit), 2=grey (flash), 0xE=white (idle),
; 0xF=blue (mood up/down).
vendor_recolor_tbl:
	defb 003h,008h,002h,00eh,00fh
; load_weapon_sprites (seg0 0x559A): RLE-decompress the equipped projectile
; (C416 2=knife / 3=axe / 4=cross) from seg10 into sprite gen 0xF8C0, then
; gfx_script_convert converts 1bpp quadrants.  Leather/chain (0/1) and 5 skip.
; Catalogued in gfx/sprites/enemy_sprite_rle.png (weapon_knife / _axe / _cross).
load_weapon_sprites:
	call page_title_banks          ; page seg 9/10 (front-end gfx)
	ld a,(0c416h)
	cp 005h
	jr z,l55dbh
	dec a
	jr z,l55dbh            ; chain whip: Simon's own cell, not this table
	dec a
	add a,a                 ; word[C416-2]
	ld hl,weapon_sprite_ptr
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)               ; DE = RLE stream in seg10
	ld hl,0f8c0h            ; sprite patterns after Simon's two cells
	call rle_dec
	ld a,(0c416h)
	cp 004h
	jr z,l55cfh
	cp 003h
	jr z,l55cfh
	cp 002h
	jr nz,l55dbh
	ld hl,weapon_cvt_knife
	call gfx_script_convert
	jr l55dbh
l55cfh:
	ld hl,weapon_cvt_boomerang
	call gfx_script_convert
	ld hl,weapon_cvt_boomerang2
	call gfx_script_convert
l55dbh:
	jp page_play_banks            ; restore default game banks
weapon_sprite_ptr:             ; (seg0 0x55DE) word[C416-2] -> seg10 RLE
	defw weapon_knife      ; 2 knife
	defw weapon_axe        ; 3 axe
	defw weapon_cross      ; 4 cross
weapon_cvt_boomerang:          ; axe/cross: F8C0 x2 -> F980
	defb 0c0h,0f8h,002h,080h,0f9h
weapon_cvt_boomerang2:         ; axe/cross: F900 x2 -> F940
	defb 000h,0f9h,002h,040h,0f9h
weapon_cvt_knife:              ; knife: F8C0 x2 -> F900
	defb 0c0h,0f8h,002h,000h,0f9h
; load_vdoor_sprites (seg0 0x55F3): extra patterns for a vertical door
; (C5AC==5), then fall through into the door SAT at 0xD600.
load_vdoor_sprites:
	call page_title_banks
	ld de,vdoor_rle         ; seg10 stream
	ld hl,0f900h
	call rle_dec
	call page_play_banks
	ld hl,0d600h
	ld bc,00808h
l5608h:
	ld de,0c5adh           ; door pixel Y,X (same order as VDP SAT: Y then X)
	ld a,b
	cp 005h
	ld a,(de)              ; A = door Y (0xC5AD)
	jr nc,l5613h
	add a,010h
l5613h:
	dec a
	ld (hl),a              ; SAT Y
	inc hl
	inc de
	ld a,(de)              ; A = door X (0xC5AE)
	ld (hl),a              ; SAT X
	inc hl
	ld a,c
	and 00bh
	add a,a
	add a,a
	ld (hl),a
	inc c
	inc hl
	inc hl
	djnz l5608h
	ld hl,0d400h
	ld c,00ch
	call sat_color_fill
	ld hl,0d410h
	ld c,00dh
	call sat_color_fill
	ld hl,0d420h
	ld c,00eh
	call sat_color_fill
	ld hl,0d430h
	ld c,002h
sat_color_fill:
	ld d,h
	ld e,l
	ld a,040h
	call ADD_DE_A
	ld b,010h
l564bh:
	ld a,c
	ld (hl),a
	ld (de),a
	inc hl
	inc de
	djnz l564bh
	ret
; ---------------------------------------------------------------------------
;  load_stage_tileset (seg0 0x5653) - page tileset banks and blit 0xBF 8x8
;  4bpp tiles from tileset_ptr[D000] into SCREEN 5 VRAM starting 0x8004.
;  Stages 0-12: seg 4/5/6. Stage >= 13: page_tileset_late overlays seg 7/8 on 8000/A000.
; ---------------------------------------------------------------------------
load_stage_tileset:
	call page_tileset_banks
	ld a,(0d000h)
	cp 00dh
	call nc,page_tileset_late
	ld a,(0d000h)
	add a,a
	ld hl,tileset_ptr
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
tileset_blit:
	ld de,08004h
	ld b,0bfh
	call vram_blit_tile_run
	jp page_play_banks
; load_intro_tileset (seg0 0x5677) - intro walk-up tileset (seg9 intro_tiles).
;  Only caller is intro_scene_build (0x63DA).
load_intro_tileset:
	call page_title_banks
	ld hl,intro_tiles
	jr tileset_blit
; load_intro_sprites (seg0 0x567F) - intro_simon_0..7 to VRAM 0xF800+, then
;  intro_sky to 0xFA00.  Same intro_scene_build path.
load_intro_sprites:
	call page_map_banks
	ld hl,0f800h
	ld de,0a319h
	call rle_dec
	ld hl,0f840h
	ld de,0a351h
	call rle_dec
	ld hl,0f880h
	ld de,0a38ch
	call rle_dec
	ld hl,0f8c0h
	ld de,0a3cah
	call rle_dec
	ld hl,0f900h
	ld de,0a40bh
	call rle_dec
	ld hl,0f940h
	ld de,0a447h
	call rle_dec
	ld hl,0f980h
	ld de,0a480h
	call rle_dec
	ld hl,0f9c0h
	ld de,0a4bch
	call rle_dec
	ld de,0b895h
	ld hl,0fa00h
	call rle_dec
	jp page_play_banks
	call page_map_banks
	ld de,0f880h
	ld hl,0ac93h
	ld bc,00180h
	call vram_write
	jp page_play_banks
; ---------------------------------------------------------------------------
;  load_simon_sprites (seg0 0x56E8) - refresh Simon's two hardware-sprite cells
;  from the current animation frame.  Simon is drawn as two stacked 16x16 cells,
;  each animated independently: cell 0 = legs/lower body, cell 1 = torso+arm+whip.
;  0xC42E indexes the leg-cell stream table (0xA281), 0xC42F the torso-cell table
;  (0xA2D1); both tables and their streams live in seg13.  Each selected stream is
;  RLE-decompressed into the sprite pattern generator (0xF800 / 0xF840).
;  Catalogued in gfx/sprites/simon_rle.png.
; ---------------------------------------------------------------------------
load_simon_sprites:
	call page_map_banks          ; page seg 11/12/13 (sprite gfx) in
	ld a,(0c42eh)           ; legs frame index
	add a,a                 ; *2 (word table)
	ld hl,simon_cell0_ptr   ; seg13 leg-cell pointer table
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)               ; DE = leg stream source
	ld hl,0f800h            ; sprite cell 0 (legs)
	call rle_dec          ; decompress into VRAM
	ld a,(0c42fh)           ; torso/whip frame index
	add a,a
	ld hl,simon_cell1_ptr   ; seg13 torso-cell pointer table
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)               ; DE = torso stream source
	ld hl,0f840h            ; sprite cell 1 (torso + whip)
	call rle_dec
	jp page_play_banks            ; restore default game banks
	call palette_hud_load
	call page_title_banks
	ld hl,stage_palette_ptr
	ld a,(0d000h)
	add a,a
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	call palette_apply
	jp page_play_banks
; --- palette_hud_load - load the 8 fixed HUD/sprite colours (0,1,2,3,8,12,14,15)
;     from hud_fixed_palette (seg10 0xBF88).  Stage palettes (stage_palette_ptr)
;     never overwrite these.
palette_hud_load:
	call page_title_banks
	ld hl,hud_fixed_palette
	call palette_apply
	jp page_play_banks
; intro_palette_load (seg0 0x573A) - HUD-fixed colours, then intro_palette
;  (0xBFA1) over indices 4-13 (including 8 and 12).  Night/garden colours;
;  title_extra_palette is the wrong table for these tiles.
intro_palette_load:
	call palette_hud_load
	call page_title_banks
	ld hl,intro_palette
	call palette_apply
	jp page_play_banks
; tileset_ptr (seg0 0x5749): word[stage 0..18] -> uncompressed 8x8 4bpp
; source in the tileset banks. 0xBF tiles blit to VRAM 0x8004.
tileset_ptr:
	defw 06000h            ; 0  courtyard (seg4)
	defw 07220h            ; 1-3
	defw 07220h
	defw 07220h
	defw 095b3h            ; 4-6 (seg5)
	defw 095b3h
	defw 095b3h
	defw 08493h            ; 7-9 (seg5)
	defw 08493h
	defw 08493h
	defw 09e73h            ; 10-12 (seg5)
	defw 09e73h
	defw 09e73h
	defw 08000h            ; 13-15 (seg7 after page_tileset_late)
	defw 08000h
	defw 08000h
	defw 09640h            ; 16-17 (seg7)
	defw 09640h
	defw 0a4c0h            ; 18 (seg8)
	call page_title_banks
	ld hl,0ff00h           ; shared sprites; fireball at +0x80 (SAT pat 0xF0)
	ld de,gfx_rle_a185
	call rle_dec
	ld de,gfx_rle_a147
	ld hl,0f9c0h
	call rle_dec
	jp page_play_banks
; ---------------------------------------------------------------------------
;  room_gfx_load (seg0 0x5787) - page seg9/10, then 9AB0[D000-1] + 4*D001:
;  word 0 = gfx script (gfx_script_run), word 1 = palette table (palette_apply).
;  Stage 0 (D000==0) skips. Called from the screen builder (seg1 0x62ED).
; ---------------------------------------------------------------------------
room_gfx_load:
	call vdp_sprites_off
	call page_title_banks
	ld hl,room_gfx_ptr      ; word[stage-1] -> {script, pal}
	ld a,(0d000h)
	or a
	jr z,l57b8h
	dec a
	add a,a
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,(0d001h)
	add a,a
	add a,a
	call ADD_DE_A
	ex de,hl
	ld a,(hl)
	inc hl
	push hl
	ld h,(hl)
	ld l,a
	call gfx_script_run
	pop hl
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	call palette_apply
l57b8h:
	jp page_play_banks
	call page_title_banks
	ld hl,gfx_script_9fed
l57c1h:
	call gfx_script_run
	jp page_play_banks
	call page_title_banks
	ld hl,0fa00h
	ld de,gfx_rle_b0aa
	call rle_dec
	ld a,(0d000h)
	sub 003h
	ld hl,0a01ah
	jr z,l57e0h
	ld hl,0a021h
l57e0h:
	call palette_apply
	jp page_play_banks
; dracula_body_load (seg0 0x57E6) - event-6 figure Dracula 32x32 frames.
; Pages seg11-13, unpacks dracula_body_closed / dracula_body_open (seg13
; 0xB5A1 / 0xB719) and HMMCs each 32x32 to page-1 Y=0x80: closed at X=0
; plus H-mirror at X=0x40, open at X=0x20 plus H-mirror at X=0x60.
; Called from cell_event_set after dracula_portrait_load.  dracula_blit_torso
; LMMMs slot CE0E-1 onto the playfield (0x5B=closed, 0x5C=chest-open,
; 0x5D/0x5E = facing mirrors).
dracula_body_load:
	call page_map_banks
	ld hl,dracula_body_closed
	call dracula_body_unpack
	ld de,0c000h
	call dracula_body_vram
	call dracula_body_hflip
	ld de,0c020h
	call dracula_body_vram
	ld hl,dracula_body_open
	call dracula_body_unpack
	ld de,0c010h
	call dracula_body_vram
	call dracula_body_hflip
	ld de,0c030h
	call dracula_body_vram
	jp page_play_banks
; dracula_body_vram (0x5816): 32 rows x 16 bytes (32px 4bpp) from 0xE800
; to VRAM DE (SCREEN 5 linear: 0xC000 = page-1 Y=0x80 X=0).
dracula_body_vram:
	ld b,020h
	ld hl,0e800h
l581bh:
	push bc
	push de
	push hl
	ld bc,00010h
	call vram_write
	pop hl
	pop de
	pop bc
	ld a,010h
	call ADD_HL_A
	ld a,080h
	call ADD_DE_A
	djnz l581bh
	ret
; dracula_body_unpack (0x5834): 32 rows into 0xE800.  First byte N is the
; count of leading 0s; then copy (12-N) payload bytes; then 4 trailing 0s.
dracula_body_unpack:
	ld b,020h
	ld de,0e800h
l5839h:
	push bc
	ld a,(hl)
	and a
	jr z,l5844h
	ld b,a
	xor a
l5840h:
	ld (de),a
	inc de
	djnz l5840h
l5844h:
	ld a,00ch
	sub (hl)
	inc hl
	ld c,a
	ld b,000h
	ldir
	xor a
	ld b,004h
l5850h:
	ld (de),a
	inc de
	djnz l5850h
	pop bc
	djnz l5839h
	ret
; dracula_body_hflip (0x5858): H-mirror the 32x32 at 0xE800 in place
; (nibble-swap via nibble_hflip, also used to H-mirror portrait 16x16s).
dracula_body_hflip:
	ld hl,0e800h
	ld de,0e80fh
	ld c,020h
l5860h:
	ld b,008h
	call nibble_hflip
	ld a,008h
	call ADD_HL_A
	ld a,018h
	call ADD_DE_A
	dec c
	jr nz,l5860h
	ret
nibble_hflip:
	ex af,af'
	ld a,(hl)
	ex af,af'
	ld a,(de)
	rrca
	rrca
	rrca
	rrca
	ld (hl),a
	ex af,af'
	rrca
	rrca
	rrca
	rrca
	ld (de),a
	inc hl
	dec de
	djnz nibble_hflip
	ret
; ---------------------------------------------------------------------------
;  dracula_portrait_load (seg0 0x5887) - event-6 immediate gfx (stage 18 room 9).
;  Pages seg14/15 and blits the picture-frame tiles plus 108 8x8 face tiles
;  from seg15 into the page-1 tile atlas, then H-mirrors the face (ids
;  0x1E-0x89 -> 0x8A-0xF5) and V-mirrors the frame (top -> bottom).  Also
;  loads 8 x 16x16 eye/mouth tiles (`dracula_portrait_parts`) to page-1
;  Y=0xA0.  Called from cell_event_set when CE00==6, after
;  dracula_portrait_palette; figure body frames follow via dracula_body_load.
; ---------------------------------------------------------------------------
dracula_portrait_load:
	call page_sound_banks
	call dracula_portrait_blit
	call dracula_portrait_hflip
	call dracula_portrait_vflip
	call dracula_portrait_parts_load
	call dracula_portrait_parts_mirror
	jp page_play_banks
dracula_portrait_blit:
	ld hl,dracula_frame_abf8
	ld b,008h
	ld de,08018h
	call vram_blit_tile_run
	ld hl,dracula_frame_acf8
	ld b,002h
	ld de,08040h
	call vram_blit_tile_run
	ld hl,dracula_frame_ad38
	ld b,002h
	ld de,08060h
	call vram_blit_tile_run
	ld hl,dracula_frame_ad78
	ld b,001h
	ld de,08070h
	call vram_blit_tile_run
	ld hl,dracula_face
	ld b,06ch
	ld de,08078h
	jp vram_blit_tile_run
dracula_portrait_hflip:
	ld hl,dracula_frame_ad78
	ld b,001h
	ld de,08074h
	call dracula_hflip_run
	ld hl,dracula_face
	ld b,06ch
	ld de,09028h
	call dracula_hflip_run
	ld hl,dracula_frame_acf8
	ld b,002h
	ld de,08048h
dracula_hflip_run:
	push bc
	push de
	push hl
	call dracula_tile8_hflip_blit
	pop hl
	ld de,00020h
	add hl,de
	pop de
	call atlas_advance_x4
	pop bc
	djnz dracula_hflip_run
	ret
dracula_tile8_hflip_blit:
	push de
	ld de,0e800h
	ld bc,00020h
	ldir
	call tile8_hflip
	pop de
	ld hl,0e800h
	ld b,001h
	jp vram_blit_tile_run
tile8_hflip:
	ld hl,0e800h
	ld de,0e803h
	ld c,008h
l5921h:
	ld b,002h
	call nibble_hflip
	inc hl
	inc hl
	ld a,006h
	call ADD_DE_A
	dec c
	jr nz,l5921h
	ret
dracula_portrait_vflip:
	ld hl,08048h
	ld b,002h
	ld de,08058h
	call dracula_vflip_run
	ld hl,08040h
	ld b,002h
	ld de,08050h
	call dracula_vflip_run
	ld hl,08060h
	ld b,002h
	ld de,08068h
dracula_vflip_run:
	push bc
	push de
	push hl
	call tile8_vflip_blit
	pop de
	call atlas_advance_x4
	ex de,hl
	pop de
	call atlas_advance_x4
	pop bc
	djnz dracula_vflip_run
	ret
atlas_advance_x4:
	ld a,e
	add a,004h
	and 07fh
	ld e,a
	ret nz
	ld a,d
	add a,004h
	and 0fch
	ld d,a
	ret
tile8_vflip_blit:
	push de
	ld de,0e818h
	ld b,008h
l5976h:
	push bc
	ld bc,00004h
	call vram_read
	ld a,e
	sub 008h
	ld e,a
	ld a,080h
	call ADD_HL_A
	pop bc
	djnz l5976h
	pop de
	ld hl,0e800h
	ld b,001h
	jp vram_blit_tile_run
dracula_portrait_parts_load:
	ld hl,dracula_portrait_parts
	ld de,0d000h
	ld b,008h
	jp vram_blit_tile16_run
dracula_portrait_parts_mirror:
	ld b,004h
	ld hl,dracula_portrait_parts_hi
	ld de,0d040h
l59a5h:
	push bc
	push de
	push hl
	call tile16_hflip_blit
	pop hl
	ld de,00080h
	add hl,de
	pop de
	ld a,e
	add a,008h
	and 07fh
	ld e,a
	jr nz,l59bfh
	ld a,d
	add a,008h
	and 0f8h
	ld d,a
l59bfh:
	pop bc
	djnz l59a5h
	ret
tile16_hflip_blit:
	push de
	ld de,0e800h
	ld bc,00080h
	ldir
	call tile16_hflip
	pop de
	ld hl,0e800h
	ld b,001h
	jp vram_blit_tile16_run
tile16_hflip:
	ld hl,0e800h
	ld de,0e807h
	ld c,010h
l59e0h:
	ld b,004h
	call nibble_hflip
	ld a,004h
	call ADD_HL_A
	ld a,00ch
	call ADD_DE_A
	dec c
	jr nz,l59e0h
	ret
; ---------------------------------------------------------------------------
;  dracula_portrait_palette (seg0 0x59F3) - event-6 palette.  HUD-fixed
;  (palette_hud_load / 0xBF88) then the title extras at 0xBF6F (pink/flesh; replaces
;  stage 18's purple overlay on indices 4-7).  Called from cell_event_set with
;  dracula_portrait_load.
; ---------------------------------------------------------------------------
dracula_portrait_palette:
	call palette_hud_load
	call page_title_banks
	ld hl,title_extra_palette
	call palette_apply
	jp page_play_banks
; title_load_tiles (0x5A02) - load the title-screen tile bitmaps into VRAM.
; The 0x11 shared glyphs (castle) load unconditionally; the region then selects
; the logo glyphs by the same 0x002B character-set nibble as title_build:
;   nibble 0 (Japanese)     -> 0x1E "Akumajo Dracula" kana glyphs (seg8 0xAEA0)
;                              then title_jp_sprites (seg13) to SAT patterns
;   nibble != 0 (intl/other)-> 0x59 "VAMPIRE KILLER" glyphs       (seg8 0xB260)
title_load_tiles:
	call page_tileset_late         ; page in the title graphics banks (seg7/seg8)
	ld hl,0ac80h           ; 0x11 shared castle glyphs (seg8 0xAC80)...
	ld de,08004h           ; ...to VRAM 0x8004
	ld b,011h
	call vram_blit_tile_run
	ld a,(0002bh)          ; MSX character set (0 = Japanese)...
	and 00fh
	jr nz,title_load_intl           ; non-zero -> international glyphs
	ld hl,0aea0h           ; Japanese: 0x1E "Akumajo Dracula" kana glyphs
	ld b,01eh
	call vram_blit_tile_run
	call page_map_banks
	ld de,title_jp_sprites
	call rle_dec_addr
	jr title_load_finish
title_load_intl:                        ; international/other machine
	ld hl,0b260h           ; 0x59 "VAMPIRE KILLER" glyphs (seg8 0xB260)
	ld b,059h
	call vram_blit_tile_run
title_load_finish:
	jp page_play_banks           ; restore default banks
; Paged-call wrappers into seg13 (bank 0x0d @ 0xA000).  page_map_banks pages it in,
; page_play_banks restores the banks.  Three sibling entry points:
;   0x5A35 conn_lookup_paged      -> conn_lookup
;   0x5A3E conn_load_permits_paged -> conn_load_permits
;   0x5A47 door_load_paged        -> door_load (door_tbl + spot_tbl)
conn_lookup_paged:             ; 0x5A35
	call page_map_banks         ; page in seg13 (bank 0x0d)
	call conn_lookup
	jp page_play_banks           ; restore banks
conn_load_permits_paged:       ; 0x5A3E
	call page_map_banks
	call conn_load_permits
	jp page_play_banks
door_load_paged:               ; 0x5A47
	call page_map_banks
	call door_load
	jp page_play_banks
; scenery_load (seg0 0x5A50) - on screen build, page seg14, unpack the current
; hub's scenery_list stream into 0xE000 (3 stages x 16 rooms x 24 bytes =
; 0x480), then compact vendor ids into 0xDE00 (scenery_vendor_index). Instantiation of
; the current room is scenery_room_load (from actor_state_reset).
scenery_load:                  ; 0x5A50
	ld hl,0e000h
	ld de,0e001h
	ld (hl),000h
	ld bc,0047fh           ; clear 0xE000..0xE47F
	ldir
	call scenery_unpack
	jp scenery_vendor_index
scenery_unpack:                ; 0x5A63
	call page_sound_banks         ; page seg14/15
	call scenery_list_lookup
	ld de,0e000h           ; dest: 16 room slots of 0x18 bytes per stage
l5a6ch:
	push de                ; save stage base
l5a6dh:
	push de                ; save room base
l5a6eh:
	ld a,(hl)
	or a
	jr z,l5a9ah            ; 0x00 = end hub
	inc a
	jr z,l5a8eh            ; 0xFF = next stage
	inc a
	jr z,l5a85h            ; 0xFE = next room
	ldi                    ; copy pos
	ld a,(hl)
	ldi                    ; copy attr
	cp 07fh
	jr nz,l5a83h
	ldi                    ; attr 0x7F: copy reveal byte
l5a83h:
	jr l5a6eh
l5a85h:
	pop de
	ld a,018h              ; next 24-byte room slot
	call ADD_DE_A
	inc hl
	jr l5a6dh
l5a8eh:
	pop de
	pop de
	push hl
	ld hl,00180h           ; next stage: 16 rooms * 0x18
	add hl,de
	ex de,hl
	pop hl
	inc hl
	jr l5a6ch
l5a9ah:
	pop de
	pop de
	jp page_play_banks           ; restore banks
scenery_list_lookup:           ; 0x5A9F
	ld a,(0d000h)
	or a
	ld hl,scenery_list_s00 ; stage 0 courtyard stream
	ret z
	ld a,(0d002h)          ; hub
	ld hl,scenery_list_ptr
	add a,a
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl               ; HL = scenery_list_hN
	ret
scenery_vendor_index:
	ld hl,0de00h           ; compact vendor-item index (48 rooms x 4 bytes)
	ld de,0de01h
	ld (hl),000h
	ld bc,000bfh
	push hl
	ldir
	pop de
	ld hl,0e000h           ; walk unpacked scenery, one 0x18-byte room per iter
	ld b,030h
l5acah:
	push bc
	push hl
	push de
	call scenery_vendors_compact
	pop hl
	ld bc,00004h
	add hl,bc
	ex de,hl
	pop hl
	ld c,018h
	add hl,bc
	pop bc
	djnz l5acah
	ret
; scenery_vendors_compact (seg0 0x5ADE): one 24-byte E000 room -> up to 2
; vendor offer ids in DE00. Attr bits7-6=11, or 0x7F covering walls.
scenery_vendors_compact:
	ld bc,00802h
l5ae1h:
	inc hl
	ld a,(hl)
	and 0e0h
	cp 060h
	jr z,l5b07h
l5ae9h:
	and 0c0h
	cp 0c0h
	jr nz,l5b03h
	ld a,(hl)
	push bc
	push hl
	ld hl,vendor_offer_id
	and 03ch
	rrca
	rrca
	call ADD_HL_A
	ldi
	inc de
	pop hl
	pop bc
	dec c
	ret z
l5b03h:
	inc hl
	djnz l5ae1h
	ret
l5b07h:
	ld a,(hl)
	and 01fh
	cp 01fh
	jr nz,l5b03h
	inc hl
	ld a,(hl)
	jr l5ae9h
; vendor_offer_id (seg0 0x5B12) - vendor attr bits5-2 -> bonus id.
; Walked by the 0xDE00 compact (scenery_vendor_index). Trailing zeros unused.
vendor_offer_id:
	defb 00eh              ; 0 candle
	defb 012h              ; 1 lockpick
	defb 003h              ; 2 red shield
	defb 004h              ; 3 yellow shield
	defb 00ah              ; 4 hourglass
	defb 016h              ; 5 potion
	defb 01eh              ; 6 holy water
	defb 01dh              ; 7 cross
	defb 01bh              ; 8 knife
	defb 000h,000h,000h,000h,000h,000h,000h
; scenery_room_load (seg0 0x5B22) - instantiate the current room's unpacked
; scenery (0xE000 slot) into C470 (8 candle/block slots), C500 (floor/chest),
; C5B5/C5C5 (vendors). Attr bits7-5: 000 floor, 001 candle, 010 16x16 block,
; 011 32x32 block, 10x chest, 11x vendor. bit7 set (chest/vendor) skips C470;
; attr 0x7F has bit7 clear, so it is a covering 32x32 wall (bonus 0x1F copies
; the reveal byte into +09). Block stamps brick tiles over the nametable.
scenery_room_load:
	call scenery_room_ptr
	ld de,0c470h
scenery_slots_fill:            ; (0x5B28) caller DE = dest (C470 play / EB00 map)
	ld b,008h
l5b2ah:
	ld a,(hl)
	inc hl
	or a
	jr z,l5b83h
	push bc
	push hl
	push de
	ld a,(hl)
	and 0e0h
	jr z,l5b8fh
	bit 7,(hl)
	jr nz,l5bach           ; chest / vendor (0x7F has bit7 clear -> wall)
	dec hl
	ld a,001h
	ld (de),a              ; +00 = 1 (first tick stamps tiles)
	inc de
	push hl
	push bc
	call scenery_pos_xy
	ld a,c
	ld (de),a              ; +01 Y
	inc de
	ld a,b
	ld (de),a              ; +02 X
	inc de
	pop bc
	xor a
	ld (de),a              ; +03 hit
	inc de
	ld a,(hl)
	ld b,a
	rlca
	rlca
	rlca
	and 007h               ; attr bits7-5
	dec a
	jr nz,l5b61h           ; 001 -> 0 (candle); 010 -> 1; 011 -> 2
	ld a,(0d000h)
	or a
	jr z,l5b61h            ; courtyard candle: kind 1
	ld a,0ffh              ; castle candle: kind 0
l5b61h:
	inc a
	ld (de),a              ; +04 kind: 0/1 candle, 2 = 16x16, 3 = 32x32
	inc e
	ld a,b
	and 01fh
	ld (de),a              ; +05 bonus id
	inc e
	ex af,af'
	ld a,l
	ld (de),a              ; +06 E000 attr ptr lo (tick overwrites as anim)
	inc e
	pop bc                 ; BC = saved HL (E000 pos ptr)
	ld a,b
	ld (de),a              ; +07 E000 pos ptr hi
	inc e
	ld a,c
	ld (de),a              ; +08 E000 pos ptr lo
	inc e
	ex af,af'
	cp 01fh
	jr nz,l5b7ch
	inc hl
	ldi                    ; +09 reveal byte (attr 0x7F)
l5b7ch:
	pop de
	ld a,e
	add a,010h
	ld e,a
	pop hl
	pop bc
l5b83h:
	ld a,(hl)
	inc hl
	and 01fh
	cp 01fh
	jr nz,l5b8ch
	inc hl
l5b8ch:
	djnz l5b2ah
	ret
l5b8fh:
	ld a,(0cf38h)
	and a
	jr nz,l5b7ch
	call scenery_item_xy
	call 08a04h
	jr l5b7ch
scenery_item_xy:
	dec l
	push hl
	push bc
	call scenery_pos_xy
	ld d,b
	ld e,c
	pop bc
	ld a,(hl)
	and 01fh
	ld b,a
	pop hl
	ret
l5bach:
	ld a,(0cf38h)
	and a
	jr nz,l5b7ch
	bit 6,(hl)
	jr nz,l5bbeh
	call scenery_item_xy
	call 08a1ah
	jr l5b7ch
l5bbeh:
	push hl
	pop ix
	call scenery_item_xy
	ld a,(ix+000h)
	ld c,a
	and 03ch
	rrca
	rrca
	ld b,a
	ld a,c
	and 003h
	ld c,a
	call 09180h
	jr l5b7ch
; scenery_room_ptr (seg0 0x5BD6) - HL -> this room's 24-byte slot in 0xE000.
; Stage 0 is slot 0; else scenery_stage_ofs[D000-1]<<4 + D001*24.
scenery_room_ptr:
	ld a,(0d001h)
scenery_room_ptr_a:            ; (0x5BD9) A already = room index
	ld (0cffeh),a
	push bc
	push de
	ld de,00000h
	ld a,(0d000h)
	or a
	jr z,l5bf5h
	dec a
	ld hl,scenery_stage_ofs
	call ADD_HL_A
	ld l,(hl)
	ld h,d
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ex de,hl
l5bf5h:
	ld hl,0e000h
	add hl,de
	ex de,hl
	ld a,(0cffeh)
	ld l,a
	ld h,000h
	add hl,hl
	add hl,hl
	add hl,hl
	ld b,h
	ld c,l
	add hl,hl
	add hl,bc
	add hl,de
	pop de
	pop bc
	ret
; (stage-within-hub)*0x18 for stages 1-18; *16 = 0x180 = 16 rooms * 24 bytes.
scenery_stage_ofs:
	defb 000h,018h,030h    ; hub 0  stages 1-3
	defb 000h,018h,030h    ; hub 1  stages 4-6
	defb 000h,018h,030h    ; hub 2  stages 7-9
	defb 000h,018h,030h    ; hub 3  stages 10-12
	defb 000h,018h,030h    ; hub 4  stages 13-15
	defb 000h,018h,030h    ; hub 5  stages 16-18
; scenery_pos_xy (seg0 0x5C1D) - pos byte (Yhi Xlo nibbles) -> C=Y, B=X pixels.
; Object-list Attr uses this same packing; object_list_spawn loads high->E (Y) low->D (X).
scenery_pos_xy:
	ld a,(hl)
	ld b,a
	and 0f0h
	ld c,a
	ld a,b
	and 00fh
	add a,a
	add a,a
	add a,a
	add a,a
	ld b,a
	inc hl
	ret
; play_tick (seg0 0x5C2C) - in-stage play loop.  Credits (CE40) divert to
; credits_tick; the F2 map (CF38) early-outs; otherwise events, actors, SAT.
play_tick:
	call event_vscroll
	call frame_vram_refresh
	ld a,(0ce40h)
	and a
	jp nz,credits_tick      ; CE40: ending credits after event 6
	call minimap_driver
	ld a,(0cf38h)
	and a
	ret nz
l5c41h:
	ld a,(0c002h)
l5c44h:
	and 040h
	jr z,l5c63h
	ld a,(0c00bh)
	rra
	jr nc,l5c63h
	ld a,(0ce00h)
	cp 006h
	call z,dracula_blit_torso
	ld a,001h
	ld (0c40ah),a          ; F1 pause latch -> state_pause
	call load_simon_sprites
	ld a,0fdh              ; pause BGM
	jp play_sound
l5c63h:
	call load_simon_sprites
	call player_tick
	call simon_sat_build
	call room_event_tick    ; CE00 boss/event (seg3 0xB6B2)
	call actors_tick        ; room_spawner + C800 (seg2 0x98EC)
	call shot_tick          ; enemy shots at 0xD700 (seg2 0x9E38)
	call combat_tick
	call brazier_tick_all   ; C470 candles (seg2 0x8678)
	call vendor_tick        ; C5B5/C5C5 (seg2 0x91C5)
	call pickup_tick        ; C500 floor items (seg2 0x8A51)
	call break_chip_tick   ; C5A6 wall-break chips (seg2 0x88DF)
	call hazard_tick        ; C580 (seg2 0x8FD6)
	call platform_tick      ; C598 moving platforms (seg2 0x90A2)
	call door_anim_tick
	call c800_sat_build     ; shape streams -> actor SAT
	call shot_sat_build
	call c800_sat_emit      ; actor SAT -> 0xD638 shadow
	jp shot_sat_emit
; ===========================================================================
;  Game Master detection (0x5C99) - called once from the boot path (0x40xx).
;  Konami's Game Master (RC-735) is a cheat/companion cartridge; when it is
;  plugged in alongside the game, Vampire Killer unlocks a hidden menu.  This
;  routine walks EXPTBL (0xFCC1, 4 primary slots, recursing into expanded
;  subslots via gm_scan_expanded) and RDSLTs 6 bytes at CPU 0x7FFA in each -
;  the last 6 bytes of the 16K RC-735 ROM (confirmed: 00 30 31 13 35 AA,
;  ending in the standard Konami 16K stamp BCD-35 + 0xAA) - against
;  game_master_sig.
;    match    -> 0xE600 = 0xFF; unlocks state_game_master_menu (stage / lives
;                select from the title) and the F5 CONTINUE option on GAME OVER,
;                and makes int_handler take the gm_pause_check key-sampling path first.
;    no match -> 0xE600 = 0 (plain standalone game: title start -> intro).
; ===========================================================================
game_master_detect:
	ld bc,00400h
	ld hl,0fcc1h
l5c9fh:
	push bc
	push hl
	ld a,(hl)
	bit 7,a                ; slot expanded?
	jr nz,l5cbah           ; yes -> check its subslots
	call gm_sig_cmp
l5ca9h:
	pop hl
	pop bc
	jr c,l5cb4h
	inc hl
	inc c
	djnz l5c9fh
	xor a
	jr l5cb6h
l5cb4h:
	ld a,0ffh              ; signature found -> Game Master present
l5cb6h:
	ld (0e600h),a
	ret
l5cbah:
	call gm_scan_expanded
	jr l5ca9h
; gm_scan_expanded (0x5CBF) - slot is expanded: try all 4 subslots.
gm_scan_expanded:
	and 080h
	or c
	ld c,a
	ld b,004h
l5cc5h:
	push bc
	call gm_sig_cmp
	pop bc
	ret c
	ld a,c
	add a,004h             ; next subslot
	ld c,a
	djnz l5cc5h
	and a
	ret
; gm_sig_cmp (0x5CD3) - RDSLT 6 bytes at 0x7FFA in slot C vs game_master_sig.
; Carry = match.
gm_sig_cmp:
	ld de,game_master_sig
	ld hl,07ffah
	ld b,006h
l5cdbh:
	push bc
l5cdch:
	push de
	ld a,c
	call RDSLT
	pop de
	pop bc
	ex de,hl
	cp (hl)
	ex de,hl
	jr nz,l5ceeh
	inc hl
	inc de
	djnz l5cdbh
	scf
	ret
l5ceeh:
	and a
	ret
game_master_sig:               ; RC-735 ROM tail at CPU 0x7FFA (confirmed)
	defb 000h,030h,031h,013h,035h,0aah  ; 35 AA = BCD 35 + 16K marker
; gm_menu_draw (0x5CF6) - clear the menu area, frame it, then print gm_menu_text.
gm_menu_draw:
	call gm_menu_clear
	ld c,00eh              ; frame ink 0x0E
	call vdp_box
	ld hl,gm_menu_text
	jp hud_string_draw
; gm_menu_clear (0x5D04) - HMMV the menu rectangle at (0x20,0x98), 0xC0 x 0x38.
gm_menu_clear:
	ld hl,02098h
	ld bc,0c038h
gm_box_clear:                  ; HL = (x,y), BC = (w,h): HMMV to 0, keep args
	xor a
	ld d,000h
	push bc
	push hl
	call vdp_hmmv
	pop hl
	pop de
	ret
panel_frame:
	call gm_box_clear
	ld c,00eh
	jp vdp_box
; gm_menu_text (0x5D1D) - the hidden Game Master menu, decoded as code by
; z80dasm.  Three items; the cursor row is redrawn by gm_cursor_draw.  Note the
; HUD font's punctuation slots are not ASCII shapes: "@" (0x30) is a horizontal
; rule and "_" (0x4F) is a right-pointing arrow, so this renders as
;     ---MENU---
;     > START GAME
;       MODIFY STAGE NUMBER
;       MODIFY PLAYER NUMBER
gm_menu_text:
	defb 058h, 0a0h
	vk "@@@MENU@@@"             ; rules either side of MENU
	defb 0feh
	defb 028h, 0b0h
	vk "_"                      ; cursor arrow, initially on item 0
	defb 0feh
	defb 030h, 0b0h
	vk "START GAME"
	defb 0feh
	defb 030h, 0b8h
	vk "MODIFY STAGE NUMBER"
	defb 0feh
	defb 030h, 0c0h
	vk "MODIFY PLAYER NUMBER"
	defb 0ffh
; gm_prompt_stage (0x5D68) - "STAGE NUMBER=" + the 2 BCD digits at 0xE605.
gm_prompt_stage:
	ld hl,gm_stage_text
	call gm_prompt_draw
	ld hl,0e605h           ; entered stage (BCD)
	ld de,0b0b8h           ; digits butt up against the "=" at x=0xB0
l5d74h:
	ld b,001h
	jp hud_bcd_draw              ; print B bytes as 2 BCD digits each
; "STAGE NUMBER=" - the font's "?" slot (0x2F) is an equals sign, not a question
; mark, so the typed digits read as a value assignment.
gm_stage_text:
	defb 048h, 0b8h
	vk "STAGE NUMBER?"          ; renders "STAGE NUMBER="
	defb 0ffh
; gm_prompt_player (0x5D89) - "PLAYER NUMBER=" + the 2 BCD digits at 0xE607.
gm_prompt_player:
	ld hl,gm_player_text
	call gm_prompt_draw
	ld hl,0e607h           ; entered lives count (BCD)
	ld de,0b8b8h
	jr l5d74h
; gm_prompt_draw (0x5D97) - clear the prompt strip, then print the caption.
gm_prompt_draw:
	push hl
	call gm_prompt_clear
	pop hl
	jp hud_string_draw
gm_player_text:
	defb 048h, 0b8h
	vk "PLAYER NUMBER?"         ; renders "PLAYER NUMBER="
	defb 0ffh
; gm_prompt_clear (0x5DB0) - HMMV away the three item rows at (0x24,0xB0),
; 0xB8 x 0x18, so the prompt can take their place.
gm_prompt_clear:
	ld hl,024b0h
	ld bc,0b818h
	jp gm_box_clear
; gm_digit_entry (0x5DB9) - number entry for the two MODIFY prompts.  Reads the
; digit keys, turns the pressed bit into a value 0-9, shifts it into the low
; nibble of the 0xE60F BCD accumulator (RLD), reprints the two digits at the
; position stashed in 0xE602, then re-derives the binary value.
gm_digit_entry:
	call gm_digit_read
	ret z                  ; no fresh keypress this frame
	ld hl,(0e608h)         ; L = row 0 edges ('0'-'7'), H = row 1 edges ('8','9')
	ld d,000h
	ld b,008h
	ld a,l
	call gm_bit_to_digit
	jr c,l5dd1h
	ld a,h
	ld b,002h
	call gm_bit_to_digit
	ret nc                 ; nothing in either row -> ignore
l5dd1h:
	ld hl,0e615h
	ld (hl),0ffh           ; mark "a value was typed"
	ld hl,0e60fh
	ld a,d                 ; A = digit 0-9
	rld                    ; shift it into the BCD accumulator
	ld de,(0e602h)         ; where this prompt prints its digits
	ld b,001h
	call hud_bcd_draw
	jp gm_bcd_to_bin
; gm_bit_to_digit (0x5DE8) - scan B bits of A; D counts up to the set bit's
; index, carry set if one was found.
gm_bit_to_digit:
	rra
	ret c
	inc d
	djnz gm_bit_to_digit
	ret
; gm_digit_read (0x5DEE) - edge-detected digit keys: keyboard row 0 ('0'-'7')
; latched through 0xE608, row 1 bits 0-1 ('8','9') through 0xE609.  Returns the
; new-press masks and NZ if anything was pressed this frame.
gm_digit_read:
	xor a
	call SNSMAT
	cpl
	ld d,a
	ld a,001h
	call SNSMAT
	cpl
	and 003h
	ld e,a
	ld a,d
	ld hl,0e608h
	ld c,(hl)
	ld (hl),a
	xor c
	and (hl)
	ld d,a
	ld a,e
	inc hl
	ld c,(hl)
	ld (hl),a
	xor c
	and (hl)
	ld e,a
	or d
	ret
; gm_bcd_to_bin (0x5E0F) - 0xE60F (two BCD digits) -> 0xE60E as tens*10 + ones.
gm_bcd_to_bin:
	ld hl,0e60fh
	ld a,(hl)
	ld c,a
	rrca
	rrca
	rrca
	rrca
	and 00fh
	add a,a
	ld b,a
	add a,a
	add a,a
	add a,b
	ld b,a
	ld a,c
	and 00fh
	add a,b
	ld (0e60eh),a
	ret
; gm_confirm_key (0x5E28) - edge-detected RETURN (keyboard row 7 bit 7), latched
; through 0xE60A: commits the current menu item / typed value.
gm_confirm_key:
	ld a,007h
	call SNSMAT
	cpl
	and 080h               ; row 7 bit 7 = RETURN
	ld hl,0e60ah
	ld c,(hl)
	ld (hl),a
	xor c
	and (hl)
	ret
; gm_apply_values (0x5E38) - push the typed numbers into the run.  Bit 0 of A:
; apply the stage (0xE606 -> 0xD000, clamped to < 19, with 0xD002 re-derived
; from gm_stage_hub_tbl and the room reset to 0).  Bit 1: apply the life count
; (0xE607 -> 0xC410).
gm_apply_values:
	rra
	push af
	jr nc,l5e67h
	ld a,(0e606h)
	cp 013h                ; stage < 19?
	jr c,l5e44h
	xor a                  ; out of range -> stage 0
l5e44h:
	ld (0d000h),a
	ld a,(0e605h)
	cp 019h
	jr c,l5e4fh
	xor a
l5e4fh:
	ld (0c411h),a          ; displayed STAGE number
	ld hl,gm_stage_hub_tbl
	ld a,(0d000h)
	call ADD_HL_A
	ld a,(hl)
	ld (0d002h),a          ; hub index for the new stage
	xor a
	ld (0d001h),a          ; room = 0
	inc a
	ld (0c40dh),a          ; force the stage BGM to (re)start
l5e67h:
	pop af
	rra
	ret nc
	ld a,(0e607h)
	ld (0c410h),a          ; lives
	ret
; gm_stage_hub_tbl (0x5E71) - stage 0-18 -> hub index (0xD002): stages 0-3 are
; hub 0, then three stages per hub.  Decoded as code it becomes nop/inc/dec runs.
gm_stage_hub_tbl:
	defb 000h,000h,000h,000h,001h,001h,001h,002h,002h,002h
	defb 003h,003h,003h,004h,004h,004h,005h,005h,005h
; gm_menu_move (0x5E84) - move the menu cursor.  A's bit 0 picks the direction
; (+1 / -1), 0xE60B is the item index, wrapped to 0-2.  Erases the arrow on the
; old row and draws it on the new one.
gm_menu_move:
	rra
	ld a,001h
	jr nc,l5e8bh
	ld a,0ffh              ; other direction -> -1
l5e8bh:
	ld b,a
	ld hl,0e60bh           ; current item index
	add a,(hl)
	and 003h
	cp 003h                ; 3 -> wrapped past an end
	jr nz,l5e9dh
	ld a,b
	add a,a
	ld a,002h              ; wrap to the last item...
	jr c,l5e9dh
	xor a                  ; ...or the first
l5e9dh:
	push af
	push hl
	ld a,(hl)
	call gm_cursor_erase   ; blank the arrow on the old row
	pop hl
	pop af
	ld (hl),a
	jp gm_cursor_draw      ; draw it on the new one
gm_cursor_erase:
	ld b,000h              ; glyph 0 = blank
	jr gm_cursor_blit
gm_cursor_draw:
	ld b,04fh              ; glyph 0x4F = right-pointing arrow
gm_cursor_blit:                ; A = item index 0-2
	ld hl,gm_cursor_y
	call ADD_HL_A
	ld e,(hl)
	ld d,028h              ; cursor column
	ld a,b
	jp hud_glyph_blit
gm_cursor_y:                   ; per-item cursor row, matching gm_menu_text
	defb 0b0h,0b8h,0c0h
; --- room_spawner (seg0 0x5EBF) - per-frame enemy spawner --------------------
; Called every frame from the actor-update loop (seg2 0x98F0) while 0xD010==0
; (normal play, not in a room transition/menu).  Gated by a series of early-outs;
; when they all pass it pages in seg14, reads the per-(stage 0xD000, room 0xD001)
; spawn descriptor from spawn_bitmask_ptr, and for each set bit 0-6 calls a
; spawn generator that drops an actor into a free 0xC800 slot via spawn_actor.
; Bit 7 shows up in some mask bytes but is never dispatched.  Existing actors
; are never touched here.
;   0xC440 - rosary / weapon-pickup "no-spawn" timer (nonzero -> suppress all new
;            spawns this frame; armed by collect_bonus, ticked down by seg1 0x75C7).
room_spawner:
	ld a,(0c440h)          ; rosary/pickup no-spawn timer active?
	and a
	ret nz                 ; yes -> spawn nothing this frame (immediate, current room)
	ld a,(0c420h)          ; Simon action state
	cp 006h
	ret z                  ; state 6 (hurt / dying-respawn) -> no spawns
	ld a,(0c5ach)
	sub 002h
	ret z
	dec a
	ret z
	cp 002h
	ret z
	di
	ld a,00eh
	ld (08000h),a
	ld (0f0f2h),a
	ei
	ld a,(0d000h)          ; stage row
	ld de,spawn_bitmask_ptr ; seg14 word table: per-stage spawn-bitmask pointer
	call 06549h            ; DE = spawn_bitmask_ptr[stage]  (stage 1 -> spawn_mask_s01)
	ld a,(0d001h)          ; room (column)
	call ADD_DE_A
	ld a,(de)              ; A = this room's spawn bitmask (bit N = generator N on)
	push af
	di
	ld a,002h              ; page seg2 into 0x8000 (the generator routines)
	ld (08000h),a
	ld (0f0f2h),a
	ei
	; dispatch one generator per set bit (LSB first, bits 0-6).  Bit 7 is
	; present in some mask bytes but never dispatched.  Each generator is
	; rate-gated and spawns a fixed actor type at a hardcoded position:
	pop af
	rra
	push af
	call c,zombie_generator ; bit0 -> actor_zombie
	pop af
	rra
	push af
	call c,merman_generator ; bit1 -> actor_merman_green
	pop af
	rra
	push af
	call c,merman_generator_3 ; bit2 -> actor_merman_red
	pop af
	rra
	push af
	call c,hanging_bat_generator ; bit3 -> actor_hanging_bat
	pop af
	rra
	push af
	call c,flying_skull_generator ; bit4 -> actor_flying_skull
	pop af
	rra
	push af
	call c,ghost_head_generator ; bit5 -> actor_ghost_head
	pop af
	rra
	jp c,roc_generator     ; bit6 -> actor_roc
	ret
; --- spawn_actor (seg0 0x5F24) - spawn an actor into a free slot ----------------
; Entry: C = actor type id (`actor_*` in segments/actors.inc), DE = spawn
; position (D = X, E = Y -> slot+05/+03).  Actors live in 7 slots at 0xC800
; with stride 0x80 (0xC800,0xC880,...,0xCB80); slot+0 holds the type (0 = free).
; A killed enemy is converted in-place to actor_flame (dissolve anim, +0C
; counting 0x10->0, then the slot frees back to 0).
; Returns with the new slot initialised and its per-type handler dispatched.
spawn_actor:
	xor a
	ld b,a
spawn_actor_ab:                    ; (seg0 0x5F26) keep A/B -> CFFA/CFFB
	ld (0cffah),a
	ld a,b
	ld (0cffbh),a
	xor a
	ld (0cf31h),a          ; spawn-succeeded flag = 0 (set to 1 once a slot is taken)
	ld a,c
	ld (0cff0h),a          ; stash requested type id
	ld (0cff1h),de         ; stash spawn position word
	ld hl,0c800h           ; scan the actor slot table...
	ld b,007h              ; ...7 slots...
	xor a
	ld de,00080h           ; ...stride 0x80
l5f42h:
	cp (hl)                ; slot+0 == 0 -> free slot found
	jr z,l5f49h
	add hl,de
	djnz l5f42h
	ret                    ; no free slot: give up
l5f49h:
	push hl
	pop ix
	ld (0cff3h),hl
	ld a,(0cff0h)
	ld hl,0605eh           ; actor_spr_count-1 (type 1 at 0x605F)
	call ADD_HL_A
	ld a,(hl)
	ld (ix+020h),a         ; SAT sprite count
	ld c,a
	and a
	jr z,spawn_actor_init
	ld de,00000h
	ld hl,0d638h
	ld b,00eh
l5f68h:
	ld a,(hl)
	cp 0e0h
	jr nz,l5f76h
	ld (hl),0e1h
	call actor_sat_assign  ; cell E gets SAT index D
	inc e
	dec c
	jr z,spawn_actor_init
l5f76h:
	inc d
	inc l
	inc l
	inc l
	inc l
	djnz l5f68h
	ret
; spawn_actor_init (seg0 0x5F7E) - initialise the chosen slot (HL/IX -> slot+0).
spawn_actor_init:
	ld a,001h
	ld (0cf31h),a          ; mark spawn as succeeded
	ld hl,(0cff3h)         ; HL = slot base (+0)
	ld a,(0cff0h)
	ld (hl),a              ; slot+00 = actor type id (runtime-confirmed; 0=free)
	inc l
	ld (hl),000h           ; slot+01 = 0 (sub-state)
	ld de,(0cff1h)         ; DE = spawn position word
	inc l
	ld (hl),000h           ; slot+02 = Y frac
	inc l
	ld (hl),e              ; slot+03 = Y pixel
	inc l
	ld (hl),000h           ; slot+04 = X frac
	inc l
	ld (hl),d              ; slot+05 = X pixel
	inc l
	ld (hl),000h           ; slot+06 = 0 (physics; init usually sets 1)
	ld a,(0cffah)
	ld (ix+00fh),a         ; +0F from CFFA (spawn zeros it)
	ld a,(0cffbh)
	ld (ix+01fh),a         ; +1F drop gate from CFFB (spawn zeros it)
	ld (ix+07eh),001h      ; freeze with Simon's whip (D010)
	ld (ix+07fh),001h
	ld (ix+00eh),007h      ; flags: bits 0-2 (hittable + rearm)
	ld de,0608bh           ; actor_sat_pat_ptr-2 (type 1 at 0x608D)
	call actor_sat_patterns
	ld a,(0cff0h)
	ld de,060e8h           ; actor_hp_tbl-1 (type 1 at 0x60E9)
	call ADD_DE_A
	ld a,(de)
	ld (ix+00dh),a         ; +0D HP
	ld hl,(0cff3h)
	ld a,(ix+000h)          ; A = entity type (ix+0)...
	dec a                   ; ...-1 -> 0-based index
	call DISPATCH_A         ; jump to entity_tbl[type-1]

; entity_tbl - per-object spawn-init handlers, indexed by entity type-1.
; Targets are all in 0xA000-0xBFFF, i.e. code in whichever segment is currently
; paged into page 2b - so these are addresses in banked ROM, not local labels.
; 22 entries for actor_zombie..actor_grim_reaper; the trailing 0x5FFF byte is
; padding. Types past the table overflow into page 1b (seg1 `data_6000`,
; odd-aligned from 0x6001) — confirmed actor_flame=flame_init,
; actor_placed_bat=enemy_placed_bat_init, actor_placed_merman=
; enemy_placed_merman_init, actor_orb, actor_roc_drop=enemy_hunchback_tick,
; actor_pickup, actor_igor, actor_blob_blue/_red/_white (0x19-0x1C). Per-frame tick is a
; separate table (`actor_type_tick`
; in seg2). Names live in segments/actors.inc.
entity_tbl:
	defw enemy_zombie_tick  ; actor_zombie
	defw enemy_merman_tick  ; actor_merman_green (1 HP)
	defw enemy_merman_tick  ; actor_merman_red (2 HP, spit)
	defw enemy_hanging_bat_tick ; actor_hanging_bat
	defw enemy_dog_tick     ; actor_dog
	defw enemy_pikeman_tick ; actor_pikeman
	defw enemy_flying_skull_tick ; actor_flying_skull
	defw enemy_ghost_head_tick ; actor_ghost_head
	defw enemy_red_skeleton_tick ; actor_red_skeleton
	defw enemy_skull_pile_tick ; actor_skull_pile
	defw enemy_white_skeleton_tick ; actor_white_skeleton
	defw enemy_raven_tick   ; actor_raven
	defw enemy_hunchback_tick ; actor_hunchback (also actor_igor pose)
	defw enemy_bone_dragon_tick ; actor_bone_dragon
	defw enemy_roc_tick     ; actor_roc (drops actor_roc_drop)
	defw enemy_axe_knight_tick ; actor_axe_knight
	defw enemy_dracula_tick ; actor_dracula
	defw enemy_giant_bat_tick ; actor_giant_bat
	defw enemy_medusa_tick  ; actor_medusa
	defw enemy_mummy_tick   ; actor_mummy
	defw enemy_frankenstein_tick ; actor_frankenstein
	defw enemy_grim_reaper_tick ; actor_grim_reaper
	defb 047h              ; type 0x17 lo; hi is data_6000[0] -> 0x6A47
entity_tbl_end:

; ===========================================================================
;  SEGMENT 1 - banked play code, paged at 0x6000-0x7FFF (page 1b).
;  Continues this window at CPU 0x6000 (8K into this PHASE).
;  entity_tbl above straddles the bank edge (last byte at 0x5FFF).
;  Regen: tools/disasm/regen-seg.sh 1 0x6000 segments/seg01.blocks
; ===========================================================================

; ---- MSX main-ROM BIOS jump table ----------------------------------------


; BLOCK 'data_6000' (start 0x6000 end 0x6030)
; Spawn-init overflow of entity_tbl (seg0 0x5FD3). The table is odd-aligned:
; type 0x17 reads 0x5FFF (047h) + 0x6000 (06ah) = 0x6A47. Type 0x18 starts
; at 0x6001. Do not word-align this block (the first byte is a high-byte
; leftover). Types 0x1D / 0x25 / 0x2B are spawn_nop (ret at 0x602F).
data_6000_start:
	defb 06ah              ; type 0x17 hi (lo 047h at 0x5FFF) -> 0x6A47
	defw igor_tick         ; 0x18 actor_igor
	defw enemy_blob_tick   ; 0x19 (same tick; not in hatch table)
	defw enemy_blob_tick   ; 0x1A actor_blob_blue
	defw enemy_blob_tick   ; 0x1B actor_blob_red
	defw enemy_blob_tick   ; 0x1C actor_blob_white
	defw spawn_nop         ; 0x1D unused
	defw flame_init        ; 0x1E actor_flame
	defw enemy_placed_bat_init ; 0x1F
	defw merman_splash_init ; 0x20
	defw enemy_placed_merman_init ; 0x21
	defw actor_orb_tick    ; 0x22 actor_orb
	defw enemy_hunchback_tick ; 0x23 actor_roc_drop
	defw actor_pickup_init ; 0x24
	defw spawn_nop         ; 0x25 unused
	defw actor_reward_init ; 0x26
	defw intro_sky_init    ; 0x27 actor_intro_sky
	defw intro_sky_ab_init ; 0x28 actor_intro_sky_a
	defw intro_sky_ab_init ; 0x29 actor_intro_sky_b
	defw intro_simon_init  ; 0x2A
	defw spawn_nop         ; 0x2B unused
	defw dracula_bat_init  ; 0x2C
	defw dracula_head_init ; 0x2D
	defw dracula_chunk_init ; 0x2E
spawn_nop:
	ret
data_6000_end:
; actor_sat_patterns (seg1 0x6030) - copy SAT colour/attr bytes from the
;  word table at actor_sat_pat_ptr (caller DE = 0x608B, indexed by type) into
;  each 5-byte cell's last byte (slot|0x20 + 5 + n*5).  Skips if +20 == 0.
actor_sat_patterns:
	ld a,(ix+020h)
	and a
	ret z
	ld a,(ix+000h)
	call lookup_word_tbl
	ld hl,(0cff3h)
	set 5,l                ; HL -> SAT sub-block (slot | 0x20)
	ld b,(hl)              ; B = sprite count
	ld a,005h
	add a,l
	ld l,a                 ; HL -> first cell colour (+0x25)
l6045h:
	ld a,(de)
	inc de
	ld (hl),a              ; cell+4 = colour/attr
	ld a,l
	add a,005h
	ld l,a
	djnz l6045h
	ret
; actor_sat_assign (seg1 0x604F) - store hardware SAT index D at cell E
;  (offset +0x21 + E*5 of the slot at 0xCFF3).  Spawn/shot_alloc claim a
;  free D638 slot (Y=0xE0) then call this.
actor_sat_assign:
	push hl
	ld hl,(0cff3h)
	ld a,e
	add a,a
	add a,a
	add a,e                ; A = E*5
	add a,021h             ; first cell at +0x21
	call ADD_HL_A
	ld (hl),d              ; cell+0 = SAT index
	pop hl
	ret

; BLOCK 'actor_spr_count' (start 0x605f end 0x608d)
;  Sprite counts per actor type. spawn_actor indexes as 0x605E+type
;  (type 0 would read the ret above; type 1 zombie = 4).
actor_spr_count:
	defb 004h
	defb 004h
	defb 004h
	defb 002h
	defb 004h
	defb 004h
	defb 002h
	defb 002h
	defb 004h
	defb 004h
	defb 004h
	defb 002h
	defb 002h
	defb 008h
	defb 006h
	defb 004h
	defb 008h
	defb 008h
	defb 008h
	defb 006h
	defb 006h
	defb 00ch
	defb 000h
	defb 002h
	defb 002h
	defb 002h
	defb 002h
	defb 002h
	defb 001h
	defb 002h
	defb 002h
	defb 002h
	defb 004h
	defb 006h
	defb 002h
	defb 002h
	defb 002h
	defb 002h
	defb 008h
	defb 001h
	defb 001h
	defb 004h
	defb 004h
	defb 002h
	defb 002h
	defb 002h
actor_spr_count_end:

; BLOCK 'actor_sat_pat_ptr' (start 0x608d end 0x60e9)
;  Word[type] -> SAT colour/attr stream (in actor_sat_colors). spawn_actor
;  calls lookup_word_tbl with DE=0x608B (type 1 reads this first word).
actor_sat_pat_ptr:
	defw 06119h
	defw 06119h
	defw 0612fh
	defw 06119h
	defw 06119h
	defw 0612fh
	defw 06145h
	defw 0612fh
	defw 0612fh
	defw 06145h
	defw 06145h
	defw 0611dh
	defw 0612fh
	defw 06145h
	defw 06127h
	defw 0612fh
	defw 0611fh
	defw 06127h
	defw 0612fh
	defw 06145h
	defw 0612fh
	defw 0612fh
	defw 0613bh
	defw 0612fh
	defw 06159h
	defw 06153h
	defw 06155h
	defw 06157h
	defw 0614eh
	defw 0613bh
	defw 06119h
	defw 0613dh
	defw 0612fh
	defw 0613fh
	defw 0612fh
	defw 0614fh
	defw 0605eh
	defw 06151h
	defw 06145h
	defw 0614dh
	defw 0614dh
	defw 06127h
	defw 06127h
	defw 06159h
	defw 06159h
	defw 06159h
actor_sat_pat_ptr_end:

; BLOCK 'actor_hp_tbl' (start 0x60e9 end 0x6119)
;  HP per actor type. spawn_actor indexes as 0x60E8+type (type 1 zombie = 1).
actor_hp_tbl:
	defb 001h
	defb 001h
	defb 002h
	defb 001h
	defb 001h
	defb 004h
	defb 002h
	defb 001h
	defb 002h
	defb 008h
	defb 004h
	defb 001h
	defb 001h
	defb 00ch
	defb 008h
	defb 008h
	defb 020h
	defb 010h
	defb 010h
	defb 010h
	defb 020h
	defb 020h
	defb 004h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 002h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
	defb 001h
actor_hp_tbl_end:

; BLOCK 'actor_sat_colors' (start 0x6119 end 0x615b)
;  SAT colour/attr init streams (one byte per sprite). Pointed at by
;  actor_sat_pat_ptr; actor_sat_patterns copies them into cell+4.
actor_sat_colors:
	defb 002h
	defb 044h
	defb 002h
	defb 044h
	defb 002h
	defb 041h
	defb 002h
	defb 048h
	defb 000h
	defb 000h
	defb 000h
	defb 000h
	defb 000h
	defb 000h
	defb 001h
	defb 042h
	defb 001h
	defb 042h
	defb 001h
	defb 042h
	defb 001h
	defb 042h
	defb 002h
	defb 045h
	defb 002h
	defb 045h
	defb 002h
	defb 045h
	defb 002h
	defb 045h
	defb 002h
	defb 045h
	defb 002h
	defb 045h
	defb 008h
	defb 000h
	defb 006h
	defb 000h
	defb 002h
	defb 006h
	defb 008h
	defb 00eh
	defb 000h
	defb 000h
	defb 002h
	defb 04ch
	defb 002h
	defb 04ch
	defb 002h
	defb 04ch
	defb 002h
	defb 04ch
	defb 002h
	defb 008h
	defb 008h
	defb 000h
	defb 00eh
	defb 000h
	defb 00fh
	defb 042h
	defb 008h
	defb 042h
	defb 00eh
	defb 042h
	defb 002h
	defb 048h
actor_sat_colors_end:

; --- object_list_load - load three tables from seg14 into RAM ----------------------
;  Pages seg 14 into page 2a (writes 0x0E to 0x8000 and to its shadow 0xF0F2),
;  copies three streams into the RAM buffers at 0xDB00 / 0xDC00 / 0xDD00 via
;  object_list_unpack, then restores seg 2 (0x02) before returning.  Interrupts are held
;  off (di/ei) around the bank switch.
; --- object_list_load - load the current screen's object list from seg14 ------------
;  Builds the 0xDB00 object/display list for the current cell, unpacking it from
;  data that lives in ROM segment 14.  Interrupts are held off around each bank
;  switch (the interrupt handler runs banked code).
object_list_load:
	di
	ld a,00eh              ; page ROM segment 14 ...
	ld (08000h),a          ; ... into page 2a (0x8000)
	ld (0f0f2h),a          ; keep the seg-2a shadow byte in step
	ei
	call object_list_clear         ; clear the 0xDB00 list to empty slots
	call object_list_lookup         ; HL -> this level's packed object data (in seg14)
	ld de,0db00h           ; unpack stream 0 -> object list at 0xDB00
	call object_list_unpack
	ld de,0dc00h           ; unpack stream 1 -> 0xDC00
	call object_list_unpack
	ld de,0dd00h           ; unpack stream 2 -> 0xDD00
	call object_list_unpack
	di
	ld a,002h              ; restore ROM segment 2 ...
	ld (08000h),a          ; ... into page 2a
	ld (0f0f2h),a
	ei
	ret

; --- object_list_unpack - unpack one object stream into a 4-byte-per-entry table -------
;  Source HL, destination DE.  Each source pair (id,attr) expands to a 4-byte
;  slot [id, attr, _, _].  id low 7 bits = actor type (same ids as entity_tbl);
;  bit7 is stored but stripped at spawn (only dogs ever set it; role unknown).
;  0x00 = end of row (jump DE to the next 0x10 boundary), 0xFF = end of stream.
object_list_unpack:
	ld (0cff0h),de         ; remember the row's base address
l618ch:
	ld a,(hl)              ; next source byte
	inc hl
	inc a                  ; 0xFF ?
	ret z                  ;   -> end of stream
	dec a                  ; 0x00 ?
	jr z,l619bh            ;   -> end of row
	ld (de),a              ; slot+0 = id
	inc de
	ldi                    ; slot+1 = next source byte (attr); HL++, DE++
	inc de                 ; skip slot+2, slot+3
	inc de
	jr l618ch
l619bh:
	ld de,(0cff0h)         ; back to row base ...
	ld a,e
	add a,010h             ; ... + 0x10 = next row
	ld e,a
	jr object_list_unpack
; --- object_list_lookup - find this level's packed object data in seg14 ---------------
object_list_lookup:
	ld a,(0d002h)          ; A = current cell/level index
	ld de,object_list_ptr  ; DE = hub -> packed object streams (seg14)
	call lookup_word_tbl         ; DE = table[A]
	ex de,hl               ; HL = pointer to the packed object data
	ret
; --- object_list_clear - clear the 0xDB00 object list --------------------------------
;  0xC0 slots of 4 bytes.  slot+0 = 0 (empty), slot+3 = running index 1..0xC0.
object_list_clear:
	ld hl,0db00h
	ld c,001h              ; running slot index
	ld b,0c0h              ; 0xC0 slots
l61b7h:
	ld (hl),000h           ; slot+0 = 0 (empty)
	inc hl
	inc hl
	inc hl
	ld (hl),c              ; slot+3 = index
	inc c
	inc hl
	djnz l61b7h
	ret
; --- object_list_spawn - spawn actors from the visible room's object list ---------------
;  Walks 4 slots of the 0xDB00 list at the current room and, for each live
;  slot, unpacks Attr (Y<<4|X, same nibble order as scenery_pos_xy) into
;  E=Y / D=X pixels and calls spawn_actor_ab (0x5F26) with C = id&0x7F
;  (the actor_* type). Stage 0 returns immediately (dec a; ret m).
object_list_spawn:
	ld a,(0d002h)          ; A = level index
	ld c,a
	add a,a
	add a,c                ; C = index*3 (stride of the row block)
	ld c,a
	ld a,(0d000h)          ; A = current row/scroll
	dec a
	ret m                  ; nothing above row 0
	sub c
	ld h,a
	ld l,000h              ; HL = (row-1 - index*3) * 0x100
	ld de,0db00h
	add hl,de              ; HL -> slot base in the object list
	ld a,(0d001h)          ; A = column within the row
	add a,a
	add a,a
	add a,a
	add a,a                ; A = column * 0x10 (slot stride)
	call ADD_HL_A          ; HL -> first slot to draw
	ld b,004h              ; up to 4 objects
object_list_spawn_loop:
	push bc
	push hl
	ld a,(hl)              ; slot+0 = id (0 = empty)
	and a
	jr z,object_list_spawn_next
	ld b,000h
	and 07fh               ; low 7 bits = actor type
	ld c,a
	inc hl
	ld a,(hl)              ; slot+1 = packed position
	and 0f0h               ; high nibble * 16 -> E (Y; spawn_actor +03)
	ld e,a
	ld a,(hl)
	and 00fh               ; low nibble ...
	add a,a
	add a,a
	add a,a
	add a,a                ; ... * 16 -> D (X; spawn_actor +05)
	ld d,a
	inc hl
	inc hl
	ld a,(hl)              ; slot+3 = attribute/index
	call spawn_actor_ab            ; C = type, DE = pixel pos, A = slot+3 -> CFFA
object_list_spawn_next:
	pop hl
	pop bc
	inc hl                 ; advance to the next slot (stride 4)
	inc hl
	inc hl
	inc hl
	djnz object_list_spawn_loop
	ret

; --- konami_logo_draw (0x6209) - set up the Konami logo screen ---------------
;  Boot front-end step, run from seg0's state machine.  Blits logo_font
;  (seg13 1bpp, inks 1/2/3) then draws the Konami logo (orange/red/grey) as a
;  tile layout (l6243h + l6296h via tile_string_draw) and sets
;  the VDP backdrop to white (R7 = 0x0F).  Then seeds the 3-byte block that the
;  per-frame stepper konami_logo_step (0x6253) uses to wipe the logo in:
;     0xC420 = 0x3C frame divider (advance the wipe every other frame)
;     0xC421 = 0x31 remaining rows of the top-to-bottom reveal (49 -> 0)
;     0xC422 = done flag (0 = revealing, 1 = finished; seg0 polls this)
konami_logo_draw:
	call 047dbh             ; seg0 helper (screen prep - purpose not yet mapped)
	call palette_hud_load   ; 8 fixed HUD/sprite colours
	ld hl,l6243h            ; HL -> parameter table l6243h
	call palette_apply      ; apply the table at HL
	ld b,00fh               ; value 0x0F ...
	ld c,007h               ; ... into VDP register 7 (backdrop colour = white)
	call WRTVDP
	ld hl,02840h            ; VDP dest / fill origin
	ld bc,0a848h            ; region size
	xor a                   ; fill/colour value 0
	ld d,001h
	call vdp_hmmv             ; seg0 VDP fill (clears the logo area to white)
	call logo_font_load     ; blit seg13 logo_font onto page 0 at Y=0
	ld de,04040h            ; screen position for the logo tiles
	ld hl,l6296h            ; HL -> logo tile-layout stream
	call tile_string_draw          ; paint the logo via the tile-string interpreter
	call 047ceh             ; seg0 helper (purpose not yet mapped)
	ld hl,0c420h            ; seed the 3-byte wipe-state block:
	ld (hl),03ch            ;   0xC420 = 0x3C  frame divider
	inc hl
	ld (hl),031h            ;   0xC421 = 0x31  rows left to reveal (49)
	inc hl
	ld (hl),000h            ;   0xC422 = 0     done flag (clear)
	ret
l6243h:
	nop
	nop
	nop
	ld bc,00370h
	ld (bc),a
	ld h,b
	ld bc,04403h
	inc b
	rrca
	ld (hl),a
	rlca
	rst 38h

; --- konami_logo_step (0x6253) - wipe the logo in by one row ----------------
;  Seg0 calls this each frame while the logo state waits, then reads 0xC422
;  (0 = still revealing, 1 = finished).  0xC420 halves the rate (acts every 2nd
;  frame); each active frame decrements the 0xC421 row counter and reveals the
;  next horizontal band top-to-bottom (VDP fill of the 0x31-0xC421 rows exposed
;  so far, height 0xA8 at 0x2840).  When 0xC421 hits 0 it sets 0xC422 = 1.
konami_logo_step:
	ld hl,0c420h            ; HL -> 0xC420 frame divider
	dec (hl)               ; tick it down every call
	ld a,(hl)
	and 001h               ; act only on every 2nd frame (bit 0 == 0)
	ret nz
	inc hl                 ; HL -> 0xC421 rows-remaining counter
	dec (hl)               ; reveal one more row
	jr nz,l6265h           ; more rows left -> draw the next band
	ld a,001h              ; last row done ...
	ld (0c422h),a          ; ... raise the done flag seg0 polls (0xC422 = 1)
	ret
l6265h:
	ld a,031h              ; rows revealed so far = 0x31 - rows_remaining
	sub (hl)
	ld c,a                 ; C = revealed row count (band height so far)
	ld b,0a8h              ; B = band width (0xA8 px)
	ld hl,02840h           ; VDP source
	ld de,02840h           ; VDP dest (reveal the exposed band at 0x2840)
	ld a,001h
	jp vdp_hmmm              ; seg0 VDP block copy -> tail-call (returns to caller)

; --- tile_string_draw - tile-string interpreter ------------------------------------
;  Walks a byte stream at HL, placing tiles at screen position DE:
;     0xFF = end of stream
;     0xFE = move to next row (D += following byte, E += 8)
;     else = draw the tile in the byte via 0x4B36 / 0x4B56
;  Used by konami_logo_draw to paint the logo layout (tile data at l6296h).
tile_string_draw:
	push de                ; save the current row's start position
l6277h:
	ld a,(hl)              ; fetch next stream byte
	inc hl
	ld c,a                 ; keep a copy (tile id for the draw path)
	inc a                  ; was it 0xFF?
	jr z,l6294h            ;   0xFF -> end of stream
	inc a                  ; was it 0xFE?
	jr nz,l628bh           ;   neither -> draw this tile
	pop de                 ; 0xFE: back to the saved row start
	ld a,(hl)              ; read the row's D delta
	inc hl
	add a,d                ; D += delta  (advance down the screen)
	ld d,a
	ld a,008h              ; E += 8      (fixed column step for the new row)
	add a,e
	ld e,a
	jr tile_string_draw           ; re-save the new row start and continue
l628bh:
	ld a,c                 ; A = tile id
	call tile_blit_page1            ; seg0: place tile A at DE
	call blit_advance_x            ; seg0: advance DE to the next cell
	jr l6277h
l6294h:
	pop de                 ; drop the saved row start
	ret
l6296h:
	ld bc,00302h
	cp 0f8h
	inc b
	dec b
	ld b,007h
	cp 0f0h
	ex af,af'
	add hl,bc
	ld a,(bc)
	dec bc
	ld c,00fh
	djnz l62bah
	dec de
	inc e
	dec e
	ld e,01fh
	jr nz,l62d1h
	ld (02423h),hl
	dec h
	ld h,0feh
	nop
	inc c
	ld (bc),a
	dec c
l62bah:
	ld (de),a
	inc de
	inc d
	dec d
	daa
	jr z,l62eah
	ld hl,(02c2bh)
	dec l
	ld l,02fh
	jr nc,$+51
	ld (03433h),a
	cp 010h
	ld d,019h
	rla
l62d1h:
	cp 0f8h
	jr $+27
	ld a,(de)
	rst 38h
; --- 0x62D7 - (seg0 state entry) arm a mode, then hand back to seg0 ----------
;  Sets the mode/flag bytes 0xC415 = 0x20 and 0xC418 = 0x80, runs three setup
;  helpers, then tail-jumps into seg0 at 0x53BD.
	ld a,020h
	ld (0c415h),a          ; Simon health = full (0x20)
	ld a,080h
	ld (0c418h),a          ; enemy/boss energy meter = full (0x80)
	call inv_reset_life
	call hud_cache_load
	call 0576fh
l62eah:
	jp 053bdh              ; -> seg0 (continue the state)

; --- 0x62ED - build a gameplay screen ---------------------------------------
;  Full screen/level construction, called from seg0 when entering a cell:
;  clears per-screen state, paints tiles (seg2 helpers), sets the cell event,
;  unpacks scenery (candles/blocks/chests/vendors), loads the packed object
;  list and spawns its actors (`object_list_spawn`).  Many steps are helpers in seg1/seg2
;  not yet mapped; the annotated ones below are the known pieces.
	call load_stage_tileset
	call 05714h
	call simon_block_clear         ; clear 0xC420..0xC46F per-screen state
	call simon_spawn_pos
	call scenery_load      ; unpack scenery_list into 0xE000 / 0xDE00
	call sprites_hide         ; hide all hardware sprites
	call actor_state_reset         ; reset the object/actor state area
	call room_gfx_load
	call 056e8h
	call room_map_load
	call 047dbh
	call cell_event_set         ; set the current cell's event type (0xCE00)
	call playfield_draw
	call vendor_tick       ; C5B5/C5C5 special objects (seg2 0x91C5)
	call brazier_tick_all  ; tick braziers/candles (seg2 0x8678)
	call door_anim_tick
	call hud_bonus_refresh
	ld a,(0ce00h)          ; event code for this cell
	cp 006h
	call z,dracula_face_rest       ; event 6 -> extra setup (dracula_blit_mouth_closed + dracula_blit_eyes_closed)
	call 047ceh
	call 09cb0h
	call object_list_load         ; load the packed object list into 0xDB00/DC00/DD00
	jp object_list_spawn              ; spawn actors from the room object list
dracula_face_rest:                 ; (seg1 0x6334) event 6: closed mouth + closed eyes
	call dracula_blit_mouth_closed
	jp dracula_blit_eyes_closed
; --- cell_event_set - set the current cell's "event" type ------------------------
;  Clears the event state (0xCE00 + flags 0xCE40/0CE0B/0CE08/0CE15), then looks
;  up the current map cell in l6376h[row=0xD000]: the byte's high nibble is the
;  column it applies to and the low nibble is the event code.  If the high nibble
;  matches the current column (0xD001) the event code is stored in 0xCE00; code 6
;  additionally kicks off its handler (seg0 dracula_portrait_load 0x5887, plus
;  0x59F3 / tail-call dracula_body_load 0x57E6).
;  Non-event cells hold 0xFF (high nibble 0xF never matches a real column).
cell_event_set:
	xor a
	ld (0ce40h),a
	ld (0ce00h),a          ; 0xCE00 = current event code (0 = none)
	ld (0ce0bh),a
	ld (0ce08h),a
	ld (0ce15h),a
	ld a,(0d000h)          ; A = current row
	ld hl,l6376h
	call ADD_HL_A          ; HL -> l6376h[row]
	ld a,(0d001h)          ; A = current column
	ld c,a
	ld a,(hl)              ; B = packed (column<<4 | event)
	ld b,a
	rra
	rra
	rra
	rra
	and 00fh               ; A = high nibble = column this event is on
	cp c
	ret nz                 ; not this column -> no event here
	ld a,b
	and 00fh               ; A = low nibble = event code
	ld l,a
	ld h,000h
	ld (0ce00h),hl         ; store event code
	cp 006h
	ret nz                 ; only code 6 has an immediate handler
	call dracula_portrait_palette
	call dracula_portrait_load
	jp dracula_body_load
; l6376h: per-row event table, one byte each (column<<4 | event); 0xFF = none.
l6376h:
	rst 38h
	rst 38h
	rst 38h
	ld d,c
	rst 38h
	rst 38h
	ld d,d
	rst 38h
	rst 38h
	ld (hl),e
	rst 38h
	rst 38h
	ld h,h
	rst 38h
	rst 38h
	sub l
	rst 38h
	rst 38h
	sub (hl)
; --- actor_state_reset - reset the big object/actor state area and its sub-systems ---
;  Clears 0xC470..0xC6FF (0x290 bytes) to 0, then calls the per-subsystem reset
;  helpers (scenery_room_load into C470, door_load_paged,
;  conn_load_permits_paged, platform_load/platform_tick, whip_slots_clear), then zeroes two
;  strided tables: 7 entries 0x80 apart from 0xC800, and 8 entries 0x80 apart
;  from 0xD700.  The wipe is also why the C580 spike bars and C598 platforms
;  start empty: spike_bars_seed / platform_load re-fill them after this, and
;  platform_load never writes +5/+6 because they are already 0 here.
actor_state_reset:
	ld hl,0c470h
	ld de,0c471h           ; dst = src+1
	ld (hl),000h
	ld bc,0028fh           ; clear 0xC470..0xC6FF (0x290 bytes)
	ldir
	call scenery_room_load
	call door_load_paged
	call platform_load
	call platform_tick
	call conn_load_permits_paged
	call whip_slots_clear
	ld hl,0c800h           ; zero 7 entries, 0x80 apart, from 0xC800
	ld de,00080h
	ld b,007h
	call mem_clear_stride
	ld hl,0d700h           ; zero 8 entries, 0x80 apart, from 0xD700
	ld b,008h
; --- mem_clear_stride - zero B entries starting at HL, stride DE -------------------
mem_clear_stride:
	ld (hl),000h
	add hl,de              ; next entry (DE apart)
	djnz mem_clear_stride
	ret
; --- simon_block_clear - clear the 0xC420..0xC46F state block (0x50 bytes) -----------
;  Includes the Konami-logo wipe counters (0xC420-0xC422) among other per-screen
;  state, reset before a new screen is built.
simon_block_clear:
	ld hl,0c420h
	ld d,h
	ld e,l
	inc de                 ; DE = 0xC421 (dst = src+1, classic ldir clear)
	ld (hl),000h           ; 0xC420 = 0
	ld bc,0004fh           ; propagate 0 across 0x4F more bytes
	ldir
l63cbh:
	ret
; --- sprites_hide - hide all hardware sprites ----------------------------------
;  The sprite attribute table shadow lives at 0xD600 (4 bytes/sprite: Y,X,pat,
;  colour).  Writing Y=0xE0 to all 0x20 sprites parks them off the bottom of the
;  screen (0xE0 is the "hide the rest" sentinel Y in MSX sprite mode).
sprites_hide:
	ld hl,0d600h           ; HL -> sprite attribute shadow (Y of sprite 0)
	ld b,020h              ; 32 sprites
l63d1h:
	ld (hl),0e0h           ; Y = 0xE0 -> off-screen
	inc l                  ; step to next sprite's Y (stride 4)
	inc l
	inc l
	inc l
	djnz l63d1h
	ret
; --- intro_scene_build (seg1 0x63DA) - intro walk-up: tiles, palette, sprites
;  Seeds Simon at (0x80,0x80), loads intro_tiles + intro_palette + intro_simon
;  / intro_sky, hides SAT, then the seg0 draw chain.  Called from state_intro
;  with C41A set (mtile_stream_intro).  Room-based; no camera.
intro_scene_build:
	call 047c0h
	ld a,080h
	ld (0c425h),a          ; Simon Y = 0x80
	ld (0c427h),a          ; Simon X = 0x80
	call load_intro_tileset
	call intro_palette_load
	call load_intro_sprites
	call sprites_hide         ; hide all hardware sprites
l63f1h:
	call intro_spawn_sky
l63f4h:
	call intro_spawn_sky_ab
	call intro_spawn_simon
	call 047dbh
	call 0451ah
	call room_map_load
	call playfield_draw
	jp 047ceh              ; -> seg0
; --- simon_spawn_pos - set Simon's spawn position + facing from the per-row table -
;  Looks up l6426h[row=0xD000] (2 bytes): byte0 with bit0 masked off -> Simon Y
;  (0xC425) and bit0 -> facing flag 0xC42C (0=right, 1=left); byte1 -> Simon X
;  (0xC427).  So each room row carries Simon's entry Y, X and facing.
simon_spawn_pos:
	ld a,(0d000h)          ; A = current row
	ld hl,l6426h
	add a,a                ; *2 (2 bytes per row)
	call ADD_HL_A          ; HL -> l6426h[row]
	ld a,(hl)
	inc hl
	ld c,a
	and 0feh               ; drop bit0 ...
	ld (0c425h),a          ; ... -> Simon Y (0xC425)
	ld a,(hl)
	ld (0c427h),a          ; byte1 -> Simon X (0xC427)
	ld a,c
	and 001h               ; bit0 ...
	ld (0c42ch),a          ; ... -> facing flag 0xC42C (0=right, 1=left)
	ret
l6426h:
	or b
	djnz $-62
	djnz l648bh
	djnz l648dh
	djnz $-62
	djnz $+99
	ret pe
	add a,c
	ret pe
	or c
	ret pe
	sub b
	djnz $+114
	djnz l63cbh
	jr nz,$-78
	djnz $-78
	djnz l63f1h
	jr c,l63f4h
	ret z
	or c
	ret pe
	or c
	ret pe
	ld d,c
	ret pe
	or c
	ret pe
; --- actor_sat_build (seg1 0x644C) - one actor's SAT from its seg6 shape ----
;  Input: IX -> actor struct.  Skips object types 0x0E and 0x17.  Pages seg 6
;  into page 2b (0xA000), looks up the actor's shape stream by (ix+0x0B) in
;  actor_shape_ptr, then writes sprite-attribute entries into the actor's
;  0x20-offset block, adding the actor position (ix+3 = Y, ix+5 = X).  A leading
;  stream code 0x80/0x81/0x82 selects a fixed (dx,dy) offset list for multi-part
;  sprites; otherwise the stream carries explicit offsets.  0x81 is the 16x16
;  slot (dy=-15, dx=-8): hanging-bat hang pose 0x1A, flyers, hunchbacks. Walkers
;  (dog, pikeman, skeleton) use explicit dy=-16 (16px) or -32 (32px). Spawn
;  pixel is the feet / hook; SAT cells sit above it.  Restores seg 3.
actor_sat_build:
	ld a,(ix+000h)         ; object type
	cp 00eh
	ret z                  ; type 0x0E: no sprites
	cp 017h
	ret z                  ; type 0x17: no sprites
	di
	ld a,006h              ; page ROM seg 6 (sprite shapes) ...
	ld (0a000h),a          ; ... into page 2b (0xA000)
	ld (0f0f3h),a          ; keep the seg-2b shadow in step
	ei
	ld a,(ix+00bh)         ; A = shape id
	ld de,actor_shape_ptr  ; word table of shape streams (in seg6)
	call lookup_word_tbl   ; DE -> this actor's shape stream
	push ix
	pop hl
	set 5,l                ; HL -> actor's sprite-attr block (ix | 0x20)
	ld b,(hl)              ; B = sprite count
	inc l
	inc l
	ld a,(de)              ; first stream byte
	cp 080h
	jr z,l64aah            ; 0x80 -> offset list l64d4h
	cp 081h
	jr z,l64a4h            ; 0x81 -> offset list l64dch
	cp 082h
	jr z,l649eh            ; 0x82 -> offset list l64e0h
l647dh:
	ld a,(de)
	inc de
	add a,(ix+003h)        ; Y = shape dy + pixel Y
	ld (hl),a
	inc l
	ld a,(de)
	add a,(ix+005h)        ; X = shape dx + pixel X
	ld (hl),a
	inc de
	inc l
l648bh:
	ld a,(de)
	ld (hl),a
l648dh:
	inc de
	inc l
	inc l
	inc l
	djnz l647dh
	di
	ld a,003h
	ld (0a000h),a
	ld (0f0f3h),a
	ei
	ret
l649eh:
	exx
	ld hl,l64e0h
	jr l64aeh
l64a4h:
	exx
	ld hl,l64dch
	jr l64aeh
l64aah:
	exx
	ld hl,l64d4h
l64aeh:
	exx
l64afh:
	exx
	ld a,(hl)
	inc hl
	add a,(ix+003h)
	exx
	ld (hl),a
	inc l
	exx
	ld a,(hl)
	inc hl
	add a,(ix+005h)
	exx
	ld (hl),a
	inc l
	inc de
	ld a,(de)
	ld (hl),a
	inc l
	inc l
	inc l
	djnz l64afh
	di
	ld a,003h
	ld (0a000h),a
	ld (0f0f3h),a
	ei
	ret
l64d4h:
	ret po
	ret m
	ret po
	ret m
	ret p
	ret m
	ret p
	ret m
l64dch:                        ; 0x81: two cells at (dy,dx)=(-15,-8); hang/fly 16x16
	pop af
	ret m
	pop af
	ret m
l64e0h:
	pop de
	ret m
	pop de
	ret m
	pop hl
	ret m
	pop hl
	ret m
	pop af
	ret m
	pop af
	ret m

; --- shot_sat_emit (0x64EC) / c800_sat_emit (0x64F3) -------------------------
;  Two entry points over the two actor arrays (stride 0x80 per actor):
;    shot_sat_emit: 8 shots at 0xD700    c800_sat_emit: 7 actors at 0xC800
;  Each non-empty slot (byte 0 != 0) is turned into sprites by actor_sat_emit.
shot_sat_emit:
	ld hl,0d700h           ; 8 shots from 0xD700
	ld b,008h
	jr l64f8h
c800_sat_emit:
	ld hl,0c800h           ; 7 actors from 0xC800
	ld b,007h
l64f8h:
	push bc
	push hl
	ld a,(hl)              ; slot occupied?
	and a
	call nz,actor_sat_emit ; yes -> emit its sprites
	pop hl
	pop bc
	ld de,00080h
	add hl,de              ; next actor (0x80 apart)
	djnz l64f8h
	ret
; --- actor_sat_emit (seg1 0x6508) - one actor's SAT block -> 0xD638 shadow --
;  HL -> actor slot.  Reads the sprite count from the 0x20-offset sub-block,
;  then for each sprite copies Y/X/pattern into the VDP sprite-attribute shadow
;  at 0xD638 + id*4 and fills the 0x10-byte pattern from the l6a70h table.
actor_sat_emit:
	set 5,l                ; HL -> sprite sub-block (slot | 0x20)
	ld b,(hl)              ; B = sprite count
	ld a,b
	and a
	ret z                  ; none
	inc l
l650fh:
	push bc
	ld a,(hl)
	ld b,a
	inc l
	add a,a
	add a,a
	ld de,0d638h
	add a,e
	ld e,a
	ld c,0ffh
	ldi
	ldi
	ldi
	ld a,(hl)
	and a
	jr nz,l652fh
	dec e
	dec e
	dec e
	ld a,0e1h
	ld (de),a
	inc e
	inc e
	inc e
l652fh:
	ex de,hl
	ld hl,l6a70h
	ld a,b
	add a,a
	add a,a
	add a,a
	ld c,a
	ld b,000h
	add hl,bc
	add hl,hl
	ex de,hl
	ld a,(hl)
	ld b,010h
l6540h:
	ld (de),a
	inc e
	djnz l6540h
	pop bc
	inc l
	djnz l650fh
	ret
; --- lookup_word_tbl - DE = ((word*)DE)[A] ----------------------------------
;  Generic word-table lookup: DE points at a table of little-endian words, A is
;  the index; returns the selected word in DE.  HL is clobbered.
lookup_word_tbl:
	ld l,a
	ld h,000h
	add hl,hl               ; HL = A*2
	add hl,de               ; HL -> &table[A]
	ld e,(hl)               ; DE = table[A] (lo)
	inc hl
	ld d,(hl)               ;      (hi)
	ret
; --- frame_vram_refresh (seg1 0x6552) - re-upload animated patterns ---------
;  When nothing special is going on (event 0xCE00 != 5, sub-state 0xC5AC != 5,
;  flag 0xCE0C == 0) this animates: it advances the phase in 0xC00F (cycles
;  0..0x78 in steps of 0x68 &0x78), then re-uploads the animated pattern tables
;  to VRAM.  Otherwise it falls back to the plain shadow blit at pattern_shadow_blit.
frame_vram_refresh:
	ld a,(0ce0ch)
	or a
	jp nz,pattern_shadow_blit           ; effect flag set -> plain blit
	ld a,(0ce00h)
	cp 005h
	jr z,pattern_shadow_blit            ; event 5 -> plain blit
	ld a,(0c5ach)
	cp 005h
	jr z,pattern_shadow_blit            ; sub-state 5 -> plain blit
	ld hl,0c00fh
	ld a,(hl)
	add a,068h
	and 078h               ; advance animation phase (wraps within 0..0x78)
	ld (hl),a
	ld a,(00007h)
	ld c,a
	call pattern_phase_upload         ; upload the phase-selected tile patterns
	ld hl,0f600h
	call vdp_set_write            ; set VRAM write pointer to 0xF600
	ld a,(0c00fh)
	ld d,010h              ; 16 rows
	ld h,0d6h              ; source high byte (0xD6xx pattern shadow)
l6584h:
	ld b,008h              ; 8 bytes per row
	ld l,a
	otir                   ; stream 8 bytes -> VDP data port
	add a,048h
	and 078h               ; next source slice (phase-stepped)
	dec d
	jr nz,l6584h
	ret
; --- pattern_phase_upload - upload the phase-selected pattern block to VRAM 0xF400 ------
pattern_phase_upload:
	ld hl,0f400h
	call vdp_set_write            ; set VRAM write pointer to 0xF400
	ld a,(0c00fh)
	ld d,010h              ; 16 rows
	add a,a
l659dh:
	ld h,06ah              ; source table base 0x6A00 (this seg)
	ld l,a
	add hl,hl              ; HL = 0x6A00 + phase*... (row source)
	ld b,020h              ; 32 bytes per row
	otir                   ; stream to VDP data port
	add a,090h
	dec d
	jr nz,l659dh
	ret
; --- pattern_shadow_blit - plain blit: copy the 0xD400 shadow (0x280 bytes) to VRAM 0xF400
pattern_shadow_blit:
	ld hl,0d400h
	ld de,0f400h
	ld bc,00280h
	jp vram_write              ; -> seg0 CPU->VRAM copy helper
; --- event_dracula (seg1 0x65B7) - event-6 CE01 sub-state machine ------------
;  room_event_tick dispatches event 6 here.  Does NOT run in logo/title/
;  attract/normal play.  CE01 selects one of 11 handlers; 0xCE02 is a per-step
;  timer.  The last handler clears CE00 and raises CE40=1, which the play tick
;  turns into credits_tick (ending message + staff).  Other bosses skip this
;  and go through room_event_ce10 -> C409.  Each step ends at event_ce01_next.
event_dracula:
	ld a,(0ce01h)          ; A = event sub-state index
	call DISPATCH_A
	defw event_dracula_init    ; 0  seed C0D0 (0x11 entries)
	defw event_dracula_wait    ; 1  wait CE16, re-run dracula_blit_torso
	defw event_dracula_chunks  ; 2  dracula_spawn_chunks; CE02 = 0x78
	defw event_dracula_quiet   ; 3  wait CE02 and C800==0, play_sound 0
	defw event_dracula_theme   ; 4  BGM 0x88, bar=0x80, falls into l662dh
	defw event_dracula_rise    ; 5  dracula_face_open until CE36==2
	defw event_dracula_fork    ; 6  branch on CE15
	defw event_dracula_drop    ; 7  dracula_face_close; BGM 0x8D, timer 0xB4
	defw event_dracula_wait2   ; 8  count CE02; 0x6A03
	defw event_dracula_fade    ; 9  dracula_palette_fade; 0x47B8/0x4805, timer 8
	defw event_dracula_done    ; 10 CE00=0, CE40=1 -> credits_tick
event_dracula_init:
	xor a
	ld (0ce16h),a          ; clear the "active" flag ...
	ld (0ce0eh),a          ; ... and its companion
	ld de,0c0d0h           ; DE -> 0xC0D0 work block
	ld c,011h              ; 0x11 entries
	call 05f24h            ; seg1 block-fill/setup helper
	jp event_ce01_next              ; -> shared epilogue (page 2b)
event_dracula_wait:
	call dracula_blit_torso    ; per-frame 32x32 torso blit (CE0E)
	ld a,(0ce16h)
	and a
	ret z                  ; not ready yet -> stay in this state
	xor a
	ld (0ce15h),a
	ld (0ce0eh),a
	call dracula_blit_torso
	jp event_ce01_next
event_dracula_chunks:
	xor a
	ld (0ce12h),a          ; chunk velocity-table index
	call dracula_spawn_chunks
	ld a,078h
	ld (0ce02h),a          ; frame timer = 0x78
	jp event_ce01_next
event_dracula_quiet:
	ld hl,0ce02h
	ld a,(hl)
	and a
	jr z,l6611h
	dec a                  ; tick the timer down (not below 0)
l6611h:
	ld (hl),a
	ret nz                 ; timer still running -> stay
	ld a,(0c800h)
	and a
	ret nz                 ; first actor slot still busy -> stay
	ld a,000h
	call play_sound            ; trigger action 0
	jp event_ce01_next
event_dracula_theme:
	ld a,088h
	call play_sound            ; trigger action 0x88
	ld a,080h
	ld (0c418h),a
	call draw_enemy_meter
l662dh:
	call dracula_blit_eyes_open
	ld c,017h              ; type 0x17: no SAT, tick_nop, +50000
	ld de,08049h           ; X=0x80, Y=0x49
	call spawn_actor
	call 057bbh
	xor a
	ld (0ce36h),a          ; reset the pair of progress counters
	ld (0ce37h),a
	jp event_ce01_next
event_dracula_rise:
	call dracula_face_open
	ld a,(0ce36h)
	sub 002h
	ret nz                 ; not at step 2 yet -> stay
	ld (0ce38h),a
	ld (0ce39h),a
	ld a,0c0h
	ld (0ce37h),a          ; arm counter 0xCE37 = 0xC0
	jp event_ce01_next
event_dracula_fork:
	ld a,(0ce15h)
	and a
	jr nz,l666eh
	call credits_palette_ramp         ; 0xCE15 == 0 path
	call dracula_ce35_tick
	call dracula_eyes_blink
	jp event_dracula_spawn_bat
l666eh:
	call dracula_blit_eyes_closed            ; 0xCE15 != 0 path
	call credits_palette_clear
	call actors_kill_all
	xor a
	ld (0ce37h),a
	jp event_ce01_next
event_dracula_drop:
	call dracula_face_close
	ld a,(0ce36h)
	and a
	ret nz                 ; not done yet -> stay
	ld a,08dh
	call play_sound            ; trigger action 0x8D
	ld a,0b4h
	ld (0ce02h),a          ; frame timer = 0xB4
	jp event_ce01_next
event_dracula_wait2:
	ld hl,0ce02h
	dec (hl)
	ret nz
	call 06a03h
	jp event_ce01_next
event_dracula_fade:
	call dracula_palette_fade
	ret nz                 ; dracula_palette_fade still working -> stay
	call 047b8h
	call 04805h
	ld a,008h
	ld (0ce02h),a          ; frame timer = 8
	jp event_ce01_next
event_dracula_done:
	ld hl,0ce02h
	dec (hl)
	ret nz
	ld hl,00000h            ; reset event pointer
	ld (0ce00h),hl         ; 0xCE00 = 0 (no event)
	ld a,001h
	ld (0ce40h),a          ; start credits_tick (ending only; other bosses use C409)
	ret
; --- credits_tick (seg1 0x66C1) - ending credits, dispatched on 0xCE40 ------
;  Event 6 (Dracula) finishes the CE01 machine by raising CE40=1.  Play tick
;  (play_tick) then calls here instead of the normal loop.  CE40 (1..4) minus
;  1 selects the step; each advances via credits_next.  Story + staff text
;  live in seg8 (0xBF20) and seg5 (0x82C0); see data/credits_ending.asm /
;  data/credits_staff.asm.
;  On done: C409 -> state_hub_advance (hub wrap / loop).
credits_tick:
	ld a,(0ce40h)          ; A = credits step (1..4)
	dec a                  ; -> 0-based index
	call DISPATCH_A        ; jump via the inline table below
	defw credits_start     ; 0 (CE40=1) BGM 0x8E, credits_init, advance
	defw credits_pump      ; 1 (CE40=2) run the roll until CE32
	defw credits_wait      ; 2 (CE40=3) wait on 0x5310, arm timer, advance
	defw credits_finish    ; 3 (CE40=4) dwell, C409, bump 0xD012, R23=0
credits_start:
	ld a,08eh
	call play_sound        ; ending theme (music_ptr 0x8E)
	call credits_init      ; load credits_font, clear CE30-CE34
credits_next:
	ld hl,0ce40h
	inc (hl)               ; advance to the next credits step
	ret
credits_pump:
	call credits_frame     ; one timeline + keyframe + wipe
	ld a,(0ce32h)
	and a
	ret z                  ; roll not finished -> stay
	jr credits_next        ; done -> advance
credits_wait:
	call 05310h
	ret nz                 ; not ready -> stay
	ld a,01eh
	ld (0ce02h),a          ; frame timer = 0x1E
	call 047b8h
	call 047dbh
	jr credits_next        ; advance
credits_finish:
	ld hl,0ce02h
	dec (hl)
	ret nz                 ; timer running -> stay
	xor a
	ld (0ce34h),a          ; stop event_vscroll
	ld (0ce40h),a          ; credits machine off
	inc a
	ld (0c409h),a          ; -> state_hub_advance (same latch as boss-clear)
	ld hl,0d012h
	ld a,(hl)
	inc a
	cp 003h
	jr nc,l6712h           ; cap the difficulty tier at 3
	ld (hl),a              ; 0xD012 = min(tier+1, 3)
l6712h:
	ld b,000h
	ld c,017h              ; VDP R23 = 0 (undo credits v-scroll)
	jp WRTVDP
; --- credits_init (seg1 0x6719) - reset the ending-credits script player ---
credits_init:
	call credits_font_load
	xor a
	ld (0ce30h),a          ; unused cursor (cleared, never read)
	ld (0ce33h),a          ; timeline tick (also VDP R23 via event_vscroll)
	ld (0ce31h),a          ; index into credits_script_ptr
	ld (0ce32h),a          ; done flag
	inc a
	ld (0ce34h),a          ; 1 = player active (gates event_vscroll)
	ld a,00eh
	ld d,0ffh
	ld e,00fh
	jp palette_set              ; seg0 VRAM setup/fill helper
; --- credits_frame (seg1 0x6736) - one credits frame -----------------------
credits_frame:
	call credits_clock     ; bump CE33 every 4th frame
	call credits_keyframe  ; blit the line due at this tick
	jp credits_wipe        ; FILVRM the strip 2 ticks behind
; --- credits_clock (seg1 0x673F) - CE33 += 1 every 4th frame ---------------
credits_clock:
	ld a,(0c003h)
	and 003h
	ret nz                 ; only act on 1 frame in 4
	ld hl,0ce33h
	inc (hl)               ; byte; wraps.  Also the scroll offset.
	ret
; --- credits_keyframe (seg1 0x674A) - blit the line due at CE33 ------------
;  Pages seg 8 @ 0xA000 (ending paragraph) and seg 5 @ 0x8000 (staff), then
;  looks up credits_script_ptr[CE31].  Record is {tick, x, chars..., 0xFF}.
;  If tick != CE33, restore banks (0x533D) and return.  x==0xFF is the end
;  of roll (CE32=1, play_sound 0xFF).  Else blit via hud_string_glyphs: C=0xFF so
;  letters pass as ASCII (space is already 0x00, not HUD ASCII-0x10).
;  `inc a` tests the 0xFF end marker, so D = X+1; E = CE33+0xD8 (Y).
credits_keyframe:
	di
	ld a,008h
	ld (0a000h),a          ; page seg 8 into page 2b (ending text)
	ld (0f0f3h),a
	ei
	di
	ld a,005h
	ld (08000h),a          ; page seg 5 into page 2a (staff text)
	ld (0f0f2h),a
	ei
	ld a,(0ce31h)          ; A = current line index
	ld de,credits_script_ptr
	call lookup_word_tbl   ; DE -> keyframe[index]
	ex de,hl               ; HL -> {tick, x, ...}
	ld a,(0ce33h)
	cp (hl)                ; timeline tick == this line's tick?
	jp nz,page_play_banks           ; not yet -> restore banks and return
	inc hl
	ld a,(hl)              ; X, or 0xFF = end of roll
	inc hl
	inc a
	jr z,credits_script_done ; 0xFF -> end
	ld d,a                 ; D = X+1 (inc a ate one pixel)
	ld a,(0ce33h)
	add a,0d8h
	ld e,a                 ; E = CE33+0xD8 (Y)
	ld c,0ffh              ; pass tile ids through (ASCII; space already 0)
	call 04adch            ; blit the line, +8 X per glyph
	ld hl,0ce31h
	inc (hl)               ; next credits_script_ptr entry
	jp page_play_banks              ; restore banks and return
credits_script_done:
	ld a,001h
	ld (0ce32h),a          ; raise "script finished" flag
	ld a,0ffh
	call play_sound        ; fade (play_sound 0xFF)
	jp page_play_banks              ; restore banks and return
; credits_script_ptr (seg1 0x6795): 43 words, indexed by CE31.  First 7 are
; the ending paragraph in seg8; the rest are the last line + staff in seg5.
credits_script_ptr:
	defw credits_msg_brave         ; SO THE BRAVE YOUNG MAN
	defw credits_msg_put           ; PUT DRACULA INTO DEEP
	defw credits_msg_sleep         ; SLEEP AGAIN AND THE TOWN
	defw credits_msg_peace         ; RESTORED ITS PEACE:
	defw credits_msg_pray          ; LET;S PRAY THAT THE EVIL
	defw credits_msg_humanbeings   ; MIND OF HUMANBEINGS WILL
	defw credits_msg_come          ; NOT LET DRACULA COME TO
	defw credits_msg_life          ; LIFE EVER AGAIN::::
	defw credits_staff             ; STAFF
	defw credits_game_designer     ; GAME DESIGNER
	defw credits_nagata            ; A:NAGATA
	defw credits_programmer        ; PROGRAMMER
	defw credits_harima            ; A:HARIMA
	defw credits_akada             ; I:AKADA
	defw credits_nagae             ; K:NAGAE
	defw credits_sound_programmer  ; SOUND PROGRAMMER
	defw credits_shikama           ; H:SHIKAMA
	defw credits_graphic_designer  ; GRAPHIC DESIGNER
	defw credits_iwamoto           ; S:IWAMOTO
	defw credits_matsui            ; N:MATSUI
	defw credits_mizutani          ; K:MIZUTANI
	defw credits_fujimoto          ; A:FUJIMOTO
	defw credits_sound_effect      ; SOUND EFFECT BY
	defw credits_uehara            ; K:UEHARA
	defw credits_music_by          ; MUSIC BY
	defw credits_yamashita         ; K:YAMASHITA
	defw credits_terashima         ; S:TERASHIMA
	defw credits_art_designer      ; ART DESIGNER
	defw credits_hayakawa          ; F:HAYAKAWA
	defw credits_assistant         ; ASSISTANT PROGRAMMER
	defw credits_toyohara          ; K:TOYOHARA
	defw credits_oka               ; T:OKA
	defw credits_eda               ; H:EDA
	defw credits_ohtsuka           ; T:OHTSUKA
	defw credits_danjyo            ; T:DANJYO
	defw credits_special_thanks    ; SPECIAL THANKS
	defw credits_hiraoka           ; K:HIRAOKA
	defw credits_fc_team           ; FC:TEAM
	defw credits_produced_by       ; PRODUCED BY
	defw credits_akihiko_nagata    ; AKIHIKO  NAGATA
	defw credits_presented_by      ; PRESENTED BY  KONAMI
	defw credits_script_end        ; {0x20, 0xFF}
	defw credits_script_end
credits_palette_ramp:
	ld hl,0ce39h
	ld a,(hl)
	inc a
	cp 013h
	jr c,l67f5h
	xor a
l67f5h:
	ld (hl),a
	ld hl,credits_ramp_tbl
	call ADD_HL_A
	ld d,(hl)
	ld e,005h
	ld a,006h
	jp palette_set
credits_ramp_tbl:
	defb 065h,075h,085h,095h,0a5h,0b5h,0c5h,0d5h,0e5h
	defb 0f5h,0e5h,0d5h,0c5h,0b5h,0a5h,095h,085h,075h,065h
credits_palette_clear:
	ld de,00000h
	ld a,006h
	jp palette_set
; dracula_eyes_blink (seg1 0x681F): CE38 counts; every 32 frames, at 0x1C
; swap in closed eyes (0xBCD8/0xBD58), at 0x1F restore open (0xBBD8/0xBC58).
dracula_eyes_blink:
	ld hl,0ce38h
	inc (hl)
	ld a,(hl)
	and 01fh
	cp 01ch
	jp z,dracula_blit_eyes_closed
	cp 01fh
	ret nz
	jp dracula_blit_eyes_open
credits_wipe:
	ld a,(0ce33h)
	sub 002h
	ld h,a
	ld l,000h
	srl h
	rr l
	ld de,00000h
	add hl,de
	ld bc,00080h
	xor a
	jp FILVRM
; event_vscroll (seg1 0x6848): if CE34 is set (credits_init), write CE33 to
; VDP R23.  First call in the play tick; the credits roll uses this as the
; vertical scroll while CE33 is also the keyframe timeline.
event_vscroll:
	ld a,(0ce34h)
	and a
	ret z
	ld a,(0ce33h)
	ld b,a
	ld c,017h              ; VDP R23
	jp WRTVDP
; dracula_spawn_chunks (seg1 0x6856): six actor_dracula_chunk (type 0x2E)
; around (CE0F, Y=0x98) after figure Dracula dies. shape_dracula_chunk; tick is ret.
dracula_spawn_chunks:
	ld b,006h
l6858h:
	push bc
	ld c,actor_dracula_chunk
	ld a,r
	and 00fh
	sub 008h
	ld d,a
	ld a,(0ce0fh)
	add a,d
	ld d,a
	ld a,r
	and 00fh
	add a,098h
	ld e,a
	call spawn_actor
	pop bc
	djnz l6858h
dracula_chunk_go:              ; type 0x2E tick: integrate only
	ret
; dracula_ce35_tick (seg1 0x6875): wall-portrait face state. DISPATCH_A on CE35:
; 0/2 wait CE37, 1 close until CE36=0, 3 open until CE36=2 then reset.
dracula_ce35_tick:
	ld a,(0ce35h)
	call DISPATCH_A
	defw dracula_ce35_wait            ; 0/2  wait CE37, then CE35++
	defw dracula_ce35_closing            ; 1  dracula_face_close until CE36=0
	defw dracula_ce35_wait
	defw dracula_ce35_opening            ; 3  dracula_face_open until CE36=2, reset
dracula_ce35_wait:
	ld hl,0ce37h
	dec (hl)
	ret nz
dracula_ce35_next:
	ld hl,0ce35h
	inc (hl)
	ret
dracula_ce35_closing:
	call dracula_face_close
	ld a,(0ce36h)
	and a
	ret nz
	ld a,040h
	ld (0ce37h),a
	jr dracula_ce35_next
dracula_ce35_opening:
	call dracula_face_open
	ld a,(0ce36h)
	cp 002h
	ret nz
	xor a
	ld (0ce35h),a
	ld a,0c0h
	ld (0ce37h),a
	ret
dracula_face_close:
	ld hl,0ce37h
	inc (hl)
	cp 010h
	jr z,dracula_face_close_half
	ld a,(hl)
	sub 010h
	ret nz
	ld (0ce36h),a
	jr dracula_blit_mouth_closed
dracula_face_close_half:
	ld hl,0ce36h
	ld a,(hl)
	ld (hl),001h
	cp 002h
	ret nz
	jr dracula_blit_mouth_half
dracula_face_open:
	ld hl,0ce37h
	inc (hl)
	ld a,(hl)
	cp 010h
	jr z,dracula_face_open_half
	cp 020h
	ret nz
	ld a,002h
	ld (0ce36h),a
	jr dracula_blit_mouth_open
dracula_face_open_half:
	ld a,001h
	ld (0ce36h),a
; HMMM 16x16s from page-1 Y=0xA0 onto the wall portrait.
; Mouth dest is a 32x32 at (0x70,0x80). Eyes dest: (0x68,0x58) and (0x88,0x58).
; vdp_hmmm: H=SX L=SY, D=DX E=DY.  Sheet (user-confirmed):
;   eyes 0+1 0xBBD8/0xBC58 open, 2+3 0xBCD8/0xBD58 closed;
;   mouths 0+1 0xBDD8/0xBE58 closed, 2+3 0xBED8/0xBF58 open.
; No mid-mouth tile: this blit composites open (upper) + closed (lower).
dracula_blit_mouth_half:       ; (0x68E3) open mouth 2 on top, closed mouth 1 below
	ld hl,060a0h           ; SX=0x60 mouth 2 open (0xBED8)
	ld de,07080h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,0a0a0h           ; SX=0xA0 H-mirror of mouth 2
	ld de,08080h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,050a0h           ; SX=0x50 mouth 1 closed (0xBE58)
	ld de,07090h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,090a0h           ; SX=0x90 H-mirror of mouth 1
	ld de,08090h
	ld bc,01010h
	ld a,001h
	jp vdp_hmmm
dracula_blit_mouth_closed:     ; (0x691B) mouths 0+1 closed (0xBDD8/0xBE58)
	ld hl,040a0h           ; SX=0x40 mouth 0 closed
	ld de,07080h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,080a0h           ; SX=0x80 H-mirror of mouth 0
	ld de,08080h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,050a0h           ; SX=0x50 mouth 1 closed
	ld de,07090h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,090a0h
	ld de,08090h
	ld bc,01010h
	ld a,001h
	jp vdp_hmmm
dracula_blit_mouth_open:       ; (0x6953) mouths 2+3 open (0xBED8/0xBF58)
	ld hl,060a0h           ; SX=0x60 mouth 2 open
	ld de,07080h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,0a0a0h
	ld de,08080h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,070a0h           ; SX=0x70 mouth 3 open
	ld de,07090h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,0b0a0h           ; SX=0xB0 H-mirror of mouth 3
	ld de,08090h
	ld bc,01010h
	ld a,001h
	jp vdp_hmmm
dracula_blit_eyes_open:        ; (0x698B) eyes 0+1 open (0xBBD8/0xBC58)
	ld hl,000a0h
	ld de,06858h           ; DX=0x68 DY=0x58
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,010a0h
	ld de,08858h           ; DX=0x88 DY=0x58
	ld bc,01010h
	ld a,001h
	jp vdp_hmmm
dracula_blit_eyes_closed:      ; (0x69A7) eyes 2+3 closed (0xBCD8/0xBD58)
	ld hl,020a0h
	ld de,06858h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,030a0h
	ld de,08858h
	ld bc,01010h
	ld a,001h
	jp vdp_hmmm
; dracula_chunk_init (seg1 0x69C3) - actor_dracula_chunk spawn. Physics on,
; shape_dracula_chunk, then Y/X vel from dracula_chunk_vel[CE12++] (6 direction pairs).
dracula_chunk_init:
	xor a
	ld (ix+07eh),a         ; ignore whip freeze
	ld (ix+00eh),a         ; not hittable
	ld (ix+006h),001h      ; physics on
	ld (ix+00bh),05ah      ; shape_dracula_chunk
	ld hl,0ce12h
	ld a,(hl)
	inc (hl)
	add a,a
	ld de,dracula_chunk_vel
	call lookup_word_tbl
	call actor_set_yvel
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	call actor_set_xvel
	jp lookup_word_tbl
dracula_chunk_vel:
	defb 040h,0fbh,000h,001h  ; Y=0xFB40 X=0x0100
	defb 080h,0fdh,000h,002h
	defb 080h,001h,020h,003h
	defb 000h,004h,000h,0ffh
	defb 080h,0ffh,000h,0fch
	defb 000h,0feh,040h,0fdh
; dracula_palette_stash (seg1 0x6A03): VRAM 0xF680 (16 palette words) -> CE60.
dracula_palette_stash:
	ld hl,0f680h
	ld de,0ce60h
	ld bc,00020h
	call vram_read
	ld a,080h
	ld (0ce13h),a
	ret
; dracula_palette_fade (seg1 0x6A15): decrement one CE60 entry per 16 frames
; of CE13 (starts at 0x80).  Returns Z when CE13 hits 0.
dracula_palette_fade:
	ld hl,0ce13h
	dec (hl)
	ld a,(hl)
	and 00fh
	ld c,a
	add a,a
	ld hl,0ce60h
	call ADD_HL_A
	ld a,(hl)
	and 0f0h
	jr z,l6a2bh
	sub 010h
l6a2bh:
	ld d,a
	ld a,(hl)
	and 00fh
	jr z,l6a32h
	dec a
l6a32h:
	or d
	ld (hl),a
	ld d,a
	inc hl
	ld a,(hl)
	and a
	jr z,l6a3bh
	dec a
l6a3bh:
	ld (hl),a
	inc hl
	ld e,a
	ld a,c
	call palette_set
	ld a,(0ce13h)
	and a
	ret
; type 0x17 spawn (seg1 0x6A47): no SAT (actor_sat_build skips it), physics
; off, +0E=5 hittable. event_dracula_theme spawns one at (0x80,0x49).
	ld (ix+00eh),005h
	ld (ix+006h),000h
tick_nop:
	ret
; event_dracula_spawn_bat (seg1 0x6A50): when CE36==2 and C003&7==0, one
; actor_dracula_bat at (X=0x80, Y=0x98).
event_dracula_spawn_bat:
	ld a,(0ce36h)
	cp 002h
	ret nz
	ld a,(0c003h)
	and 007h
	ret nz
	ld c,actor_dracula_bat
	ld de,08098h
	jp spawn_actor
; dracula_bat_init (seg1 0x6A64) - actor_dracula_bat spawn. Fall (Yvel 0x0300),
; home X at Simon. Poses robe 0x02/0xA5, then head open 0xA6 / closed 0xA7, then hanging_bat fly.
dracula_bat_init:
	ld (ix+006h),001h      ; physics on
	ld (ix+00ch),008h      ; 8 frames at pose 0
	ld (ix+011h),000h      ; fly-pose timer
l6a70h:
	ld (ix+00bh),002h      ; shape_dracula_robe_0
	ld de,00300h
	call actor_set_yvel
	ld hl,0cf32h
	inc (hl)
	ld a,(hl)
	and 007h
	ld de,l6a93h
	call lookup_word_tbl
	ld a,(0c427h)          ; Simon X
	sub (ix+005h)
	call c,neg_de
	jp actor_set_xvel
l6a93h:
	defw 00100h,00280h,00180h,00200h
	defw 00240h,00140h,00300h,001c0h
dracula_bat_go:                ; (0x6AA3)
	ld a,(ix+001h)
	cp 004h
	ld de,0ffd0h           ; gravity unless state 4
	call nz,actor_add_yvel
	ld a,(ix+001h)
	call DISPATCH_A
	defw l6abeh            ; 0  wait 8, robe 0xA5
	defw l6aceh            ; 1  wait 8, head open 0xA6 / closed 0xA7
	defw l6ae6h            ; 2  wait 0x18
	defw l6af2h            ; 3  hanging_bat fly (one rra)
	defw hanging_bat_pose         ; 4  keep flying
l6abeh:
	dec (ix+00ch)
	ret nz
	ld (ix+00bh),0a5h      ; shape_dracula_robe_1
	ld (ix+00ch),008h
	inc (ix+001h)
	ret
l6aceh:
	dec (ix+00ch)
	ret nz
	bit 7,(ix+00ah)        ; Xvel sign
	ld a,0a6h              ; shape_dracula_head_open
	jr nz,l6adbh
	inc a                  ; shape_dracula_head_closed
l6adbh:
	ld (ix+00bh),a
	ld (ix+00ch),008h
	inc (ix+001h)
	ret
l6ae6h:
	dec (ix+00ch)
	ret nz
	ld (ix+00ch),018h
	inc (ix+001h)
	ret
l6af2h:
	ld a,(ix+011h)
	call hanging_bat_pose
	dec (ix+00ch)
	ret nz
	inc (ix+001h)
	ret
hanging_bat_pose:                  ; (seg1 0x6B00) trampoline: one-rra flap (dracula_bat)
	ld a,(ix+011h)
	jp hanging_bat_flap_slow
; player_tick (seg1 0x6B06): per-frame player update during play.
; 0xCE11 (boss-orb collected) freezes input; then door, Simon action, attack
; (skipped while the door anims 2/3/5), edge detector, and the timer bank.
player_tick:
	ld a,(0ce11h)          ; boss-orb collected: freeze controls
	and a
	jr z,l6b13h
	xor a
	ld (0c007h),a          ; held
	ld (0c006h),a          ; new-press
l6b13h:
	call door_interact
	call simon_action_tick
	ld a,(0c5ach)
	cp 002h
	jr z,l6b2bh
	cp 003h
	jr z,l6b2bh
	cp 005h
	jr z,l6b2bh
	call simon_attack_tick
l6b2bh:
	call room_edge_detect
	call timers_tick
	call gem_timer_tick
	call hourglass_timer_tick
	call boss_flash_delay_tick
	call backdrop_flash_tick
	jp l761fh
; simon_action_tick (seg1 0x6B40) - Simon's per-frame action-state machine.
; 0xC420 = action state; DISPATCH_A jumps through simon_action_tbl.
;   0 simon_grounded   walk / idle (whipping does NOT change 0xC420)
;   1 simon_jump_tick  airborne (Y arc; C421 picks up/left/right)
;   2 simon_crouch     DOWN held; X locked
;   3 simon_stairs     climbing; can whip
;   4 simon_fall       dropping off a ledge
;   5 simon_hurt       knockback / i-frames (0xC42D)
;   6 simon_dying      death / respawn
;   7 simon_portal_wait  on-pad crouch+UP: wait 0xC42D, then C41B=0xFF warp
simon_action_tick:
	call platform_stand_test  ; refresh 0xC439 (moving-platform slot)
	ld a,(0c420h)          ; Simon action state
	call DISPATCH_A
simon_action_tbl:
	defw simon_grounded
	defw simon_jump_tick
	defw simon_crouch
	defw simon_stairs
	defw simon_fall
	defw simon_hurt
	defw simon_dying
	defw simon_portal_wait
simon_grounded:                ; 0 (0x6B59)
	call simon_floor_test
	jr c,l6b64h
	ld a,(0c439h)
	and a
	jr z,l6bach
l6b64h:
	ld a,(0c5ach)
	cp 004h
	jr z,l6b6eh
	cp 002h
	ret nc
l6b6eh:
	ld a,(0c439h)
	and a
	call nz,platform_carry_simon
	ld a,(0c422h)
	and a
	ret nz
	ld de,00000h
	ld (0c42eh),de         ; walk anim frames (legs, torso)
	call simon_mirror_frames
	ld a,(0c007h)          ; held: 0=UP 1=DOWN 2=LEFT 3=RIGHT
	rra
	jr c,simon_try_stairs_up            ; UP -> maybe mount stairs
l6b8ah:
	rra
	jp c,simon_try_stairs_down            ; DOWN held -> crouch (or down-stairs)
	rra
	push af
	call c,simon_walk_left
	pop af
	rra
	call c,simon_walk_right
	ld a,(0c006h)
	and 020h               ; UP new-press (jump; same bit as portal)
	ret z
	call simon_ceiling_test
	ret c
	ld a,001h
	ld (0c420h),a
	xor a
	ld (0c421h),a
	ret
l6bach:
	ld a,004h
	ld (0c420h),a
	xor a
	ld (0c421h),a
	ret
; platform_carry_simon (0x6BB6): A = 0xC439 (slot id).  Slide Simon 1px in the
; platform's travel direction, taken from the sign of the slot's step byte.
; A wall probe in that direction cancels the ride, so a platform pushing him
; into geometry leaves him behind instead of shoving him through it.
platform_carry_simon:
	dec a
	ld a,007h
	jr nz,l6bbch
	xor a                  ; slot 1 -> offset 0, slot 2 -> offset 7
l6bbch:
	ld hl,0c598h
	call ADD_HL_A
	inc hl
	inc hl
	inc hl                 ; -> +3 step
	ld a,(hl)
	rla
	ld d,000h
	jr c,l6bd3h            ; negative step -> travelling left
	call simon_wall_right         ; wall to the right?
	ret c
	ld d,001h
	jr l6bd9h
l6bd3h:
	call simon_wall_left         ; wall to the left?
	ret c
	ld d,0ffh
l6bd9h:
	ld a,(0c427h)
	add a,d
	ld (0c427h),a          ; Simon X += travel direction
	ret
simon_try_stairs_up:                        ; UP while grounded: try stairs
	ex af,af'
	call stair_probe_up_right
	ld bc,00001h
	jr z,l6bf5h
	call stair_probe_up_left
	ld bc,00101h
	jr z,l6bf5h
	ex af,af'
	jr l6b8ah
l6bf5h:
	ld a,003h
	ld (0c420h),a
	ld a,c
	ld (0c435h),a
	ld a,b
	ld (0c421h),a
	rra
	ld a,(0c427h)
	jr nc,l6c0ah
	add a,008h
l6c0ah:
	and 0f8h
	ld (0c427h),a
	xor a
	ld (0c424h),a
	ld (0c426h),a
	ret
simon_try_stairs_down:
	call stair_probe_down_right
	ld bc,00002h
	jr z,l6bf5h
	call stair_probe_down_left
	ld bc,00102h
	jr z,l6bf5h
	ld a,002h
	ld (0c420h),a
	ld de,00006h
	ld (0c42eh),de
	jp simon_mirror_frames
simon_walk_left:               ; (0x6C36) face left (0xC42C=1), try -X
	ld a,001h
	ld (0c42ch),a          ; facing = left
	ld a,(0c41eh)          ; left exit permit
	inc a
	jr nz,l6c47h
	ld a,(0c427h)
	cp 010h
	ret c
l6c47h:
	call simon_wall_left
	ret c
	ld a,(0c431h)
	and 008h               ; boots (id 12): faster walk
	ld bc,0fe00h
	jr z,l6c58h
	ld bc,0fd80h
l6c58h:
	jr l6c7ah
simon_walk_right:              ; (0x6C5A) face right (0xC42C=0), try +X
	xor a
	ld (0c42ch),a          ; facing = right
	ld a,(0c41fh)          ; right exit permit
	inc a
	jr nz,l6c6ah
	ld a,(0c427h)
	cp 0f0h
	ret nc
l6c6ah:
	call simon_wall_right
	ret c
	ld a,(0c431h)
	and 008h               ; boots (id 12): faster walk
	ld bc,00200h
	jr z,l6c7ah
	ld c,080h
l6c7ah:
	push bc
	ld a,(0c425h)
	ld b,a
	ld a,(0c427h)
	ld c,a
	call door_proximity    ; overlapping the white-key door?
	pop bc
	ret c
	ld a,(0c5ach)
	dec a
	dec a
	cp 002h
	ret c
	ld a,(0c420h)
	cp 005h
	jr z,simon_add_x
	dec a
	call nz,simon_walk_anim
simon_add_x:                   ; (0x6C9B) 0xC426 += BC (subpixel X)
	ld hl,(0c426h)
	add hl,bc
	ld (0c426h),hl
	ret
simon_walk_anim:               ; (0x6CA3) skip if L+R; else cycle C42E from frame ctr
	ld a,(0c007h)
	and 00ch
	cp 00ch
	ret z
simon_step_walk_frames:        ; (0x6CAB)
	ld a,(0c003h)
	rra
	rra
	rra
	ld de,00101h
	jr c,l6cbfh
	rra
	ld de,00000h
	jr c,l6cbfh
	ld de,00202h
l6cbfh:
	ld hl,(0c42eh)
	add hl,de
	ld (0c42eh),hl
	ret
simon_jump_tick:               ; 1 (0x6CC7) 0xC421 = 0 aim, 1 up, 2 left, 3 right
	ld a,(0c421h)
	call DISPATCH_A
	defw l6cd5h
	defw simon_jump_arc
	defw simon_jump_left
	defw simon_jump_right
l6cd5h:
	ld b,001h
	ld a,(0c007h)
	and 00ch
	jr z,l6ce9h
	rra
	rra
	cp 003h
	jr nc,l6ce9h
	rra
	inc b
	jr c,l6ce9h
	inc b
l6ce9h:
	ld hl,0c421h
	ld (hl),b
	ret
simon_jump_arc:                ; (0x6CEE) advance 0xC428 through jump_y_delta
	ld a,(0c431h)
	and 010h               ; wings (id 13): taller jump table
	ld bc,jump_y_delta+1
	ld d,013h
	jr z,l6cffh
	ld bc,jump_y_delta
	ld d,015h
l6cffh:
	ld hl,0c428h
	push hl
	call simon_jump_y_step
	pop hl
	ld a,(0c422h)
	and a
	jr nz,l6d1ah
	ld d,000h
	ld e,006h
	ld (0c42eh),de
	push hl
	call simon_mirror_frames
	pop hl
l6d1ah:
	ld a,(hl)
	cp 009h
	ret c
	ld de,0cff0h
	xor a
	ld (de),a
	ld a,(hl)
	dec a
	dec a
	cp 013h
	push hl
	call nc,simon_land_sfx_arm
	pop hl
	call simon_floor_test
	jr c,l6d37h
	ld a,(0c439h)
	and a
	ret z
l6d37h:
	ld a,(0cff0h)
	and a
	jr z,l6d42h
	ld a,007h
	call play_sound
l6d42h:
	ld hl,0c425h
	ld a,(hl)
	and 0f8h
	ld (hl),a
	xor a
	ld (0c420h),a
	ld (0c421h),a
	ld (0c428h),a
	ret
simon_jump_y_step:
	inc (hl)
	ld a,(hl)
	cp d
	jr c,l6d5ah
	ld a,d
l6d5ah:
	dec a
	ld h,b
	ld l,c
	call ADD_HL_A
	ld a,(0c425h)
	add a,(hl)
	ld (0c425h),a
	ret
simon_jump_left:               ; (0x6D68)
	call simon_walk_left
	jp simon_jump_arc
simon_jump_right:              ; (0x6D6E)
	call simon_walk_right
	jp simon_jump_arc
; simon_land_sfx_arm (seg1 0x6D74): late jump (C428 >= 0x15) sets CFF0 so
; landing plays sfx 7.  C420==1 (always, in jump) returns; C420==2 would
; add +(C428-0x13)*8 to X, else subtract — unused from simon_jump_arc.
simon_land_sfx_arm:
	ld a,001h
	ld (de),a              ; CFF0 = thud this landing
	ld a,(0c420h)
	dec a
	ret z                  ; jump: SFX only
	push af
	ld a,(hl)
	sub 013h
	add a,a
	add a,a
	add a,a
	ld e,a
	pop af
	dec a
	jr z,l6d91h            ; C420==2: +X
	dec a
	ld a,e
	neg
	ld d,0ffh
	ld e,a
	jr l6d93h
l6d91h:
	ld d,000h
l6d93h:
	ld hl,(0c426h)
	add hl,de
	ld (0c426h),hl
	ret
jump_y_delta:                  ; (0x6D9B) signed dY per jump phase (21 bytes)
	defb 0fah,0fah,0fah,0fbh,0fbh,000h,0fch,0fdh,0feh,0ffh
	defb 000h,000h,001h,002h,003h,004h,005h,005h,006h,006h,006h
simon_crouch:                  ; 2 (0x6DB0)
	call spot_proximity    ; carry = overlapping armed spot pad
	jr nc,l6dcfh           ; off-pad -> normal crouch
	ld a,(0c006h)
	and 020h               ; UP new-press (same bit as jump)
	jr z,l6dcfh            ; still holding DOWN only
	ld a,007h
	ld (0c420h),a          ; portal wind-up
	xor a
	ld (0c421h),a
	ld a,040h
	ld (0c42dh),a          ; flash/wait timer
	ld a,015h
	jp play_sound          ; sfx 0x15 (flash)
l6dcfh:
	ld a,(0c439h)
	and a
	call nz,platform_carry_simon
	ld a,(0c422h)
	and a
	ret nz
	ld a,(0c007h)
	rra
	rra
	ret c                  ; DOWN still held -> stay crouched
	jp l6efch
simon_stairs:                  ; 3 (0x6DE4)
	ld a,(0c422h)
	and a
	ret nz
	ld a,(0c435h)
	and a
	jr nz,l6df2h
	ld a,(0c007h)
l6df2h:
	ld b,a
	ld de,00100h
	ld a,(0c421h)
	and a
	ld a,b
	jr nz,l6e0eh
	rra
	jp c,l6ec3h
	rra
	jp c,l6e1bh
	rra
	jp c,l6ec3h
	rra
	jp c,l6e1bh
	ret
l6e0eh:
	rra
	jr c,l6e8bh
	rra
	jr c,l6e52h
	rra
	jr c,l6e52h
	rra
	jr c,l6e8bh
	ret
l6e1bh:
	ld hl,(0c424h)
	add hl,de
	ld (0c424h),hl
	ld hl,(0c426h)
	add hl,de
	ld (0c426h),hl
	xor a
	ld (0c42ch),a
	ld de,00103h
	ld (0c42eh),de
	call simon_stair_frames_down
	ld hl,0c42bh
	inc (hl)
	ld a,(hl)
	ld b,a
	and 007h
	ld a,008h
	jr nz,l6e44h
	xor a
l6e44h:
	ld (0c435h),a
	ld a,b
	cp 008h
	ret c
	call simon_floor_test
	ret nc
	jp l6efch
l6e52h:
	or a
	ld hl,(0c424h)
	add hl,de
	ld (0c424h),hl
	ld hl,(0c426h)
	sbc hl,de
	ld (0c426h),hl
	ld a,001h
	ld (0c42ch),a
	ld de,0100dh
	ld (0c42eh),de
	call simon_stair_frames_down
	ld hl,0c42bh
	inc (hl)
	ld a,(hl)
	ld b,a
	and 007h
	ld a,004h
	jr nz,l6e7eh
	xor a
l6e7eh:
	ld (0c435h),a
	ld a,b
	cp 008h
	ret c
	call simon_floor_test
	ret nc
	jr l6efch
l6e8bh:
	or a
	ld hl,(0c424h)
	sbc hl,de
	ld (0c424h),hl
	ld hl,(0c426h)
	add hl,de
	ld (0c426h),hl
	xor a
	ld (0c42ch),a
	ld de,00103h
	ld (0c42eh),de
	call simon_stair_frames_up
	ld hl,0c42bh
	inc (hl)
	ld a,(hl)
	ld b,a
	and 007h
	ld a,008h
	jr nz,l6eb6h
	xor a
l6eb6h:
	ld (0c435h),a
	ld a,b
	cp 008h
	ret c
	call simon_land_test
	ret nc
	jr l6efch
l6ec3h:
	or a
	ld hl,(0c424h)
	sbc hl,de
	ld (0c424h),hl
	or a
	ld hl,(0c426h)
	sbc hl,de
	ld (0c426h),hl
	ld a,001h
	ld (0c42ch),a
	ld de,0100dh
	ld (0c42eh),de
	call simon_stair_frames_up
	ld hl,0c42bh
	inc (hl)
	ld a,(hl)
	ld b,a
	and 007h
	ld a,004h
	jr nz,l6ef1h
	xor a
l6ef1h:
	ld (0c435h),a
	ld a,b
	cp 008h
	ret c
	call simon_land_test
	ret nc
l6efch:
	ld de,00000h
	ld (0c42eh),de
	xor a
	ld (0c435h),a
	ld (0c42bh),a
	call simon_mirror_frames
	jp l6d42h
; simon_stair_frames_down (seg1 0x6F10): descending.  bit2 of C42B picks
; +1 legs or +1 torso (B=1-C, C=0/1).
simon_stair_frames_down:
	ld a,(0c42bh)
	rra
	rra
	and 001h
	ld c,a
	neg
	inc a
	ld b,a
	ld a,(0c42eh)
	add a,b
	ld (0c42eh),a
	ld a,(0c42fh)
	add a,c
	ld (0c42fh),a
	ret
; simon_stair_frames_up (seg1 0x6F2B): ascending.  Same C; B=C+1 so legs
; step 1 or 2.
simon_stair_frames_up:
	ld a,(0c42bh)
	rra
	rra
	and 001h
	ld c,a
	inc a
	ld b,a
	ld a,(0c42eh)
	add a,b
	ld (0c42eh),a
	ld a,(0c42fh)
	add a,c
	ld (0c42fh),a
	ret
simon_fall:                    ; 4 (0x6F44)
	ld a,(0c439h)
	and a
	jr nz,l6f71h
	call simon_floor_test
	jr c,l6f71h
	ld de,00000h
	ld (0c42eh),de
	call simon_mirror_frames
	ld hl,0c428h
	ld a,(hl)
	inc (hl)
	cp 003h
	jr c,l6f63h
	dec (hl)
l6f63h:
	ld hl,l6f88h
	call ADD_HL_A
	ld a,(0c425h)
	add a,(hl)
	ld (0c425h),a
	ret
l6f71h:
	ld a,(0c425h)
	and 0f8h
	ld (0c425h),a
	xor a
	ld (0c428h),a
	ld (0c420h),a
	ld (0c421h),a
	ld a,007h
	jp play_sound
l6f88h:
	defb 002h,004h,006h,006h   ; fall dY
simon_hurt:                    ; 5 (0x6F8C)
	ld a,(0c423h)
	call DISPATCH_A
	defw l6f9ah
	defw l6fdbh
	defw l701eh
	defw l7024h
l6f9ah:
	ld a,(0c002h)
	and 040h
	ld a,013h
	call nz,play_sound
	ld a,05ah
	ld (0c42dh),a          ; arm state timer (0xC42D); in hurt = i-frame/blink
	ld a,(0c42bh)
	and a
	jp z,l6fc3h
	ld a,(0c415h)          ; Simon health
	and a
	jr z,l6fc3h            ; health 0 -> death/knockdown branch
	ld a,003h
	ld (0c420h),a
	ld a,002h
	ld (0c42fh),a
	jp simon_mirror_frames
l6fc3h:
	ld a,(0c43ch)
	ld (0c42ch),a
	inc a
	ld (0c423h),a
	xor a
	ld (0c42ah),a
	ld de,00307h
	ld (0c42eh),de
	jp simon_mirror_frames
l6fdbh:
	call simon_walk_left
l6fdeh:
	ld bc,l7084h
	ld d,015h
	ld hl,0c42ah
	push hl
	call simon_jump_y_step
	pop hl
	ld a,(hl)
	cp 00bh
	ret c
	call simon_floor_test
	jr c,l6ff9h
	ld a,(0c439h)
	and a
	ret z
l6ff9h:
	ld a,(0c425h)          ; Simon Y, snapped to an 8px grid on landing
	and 0f8h
	ld (0c425h),a
	ld a,003h
	ld (0c423h),a          ; hurt sub-state = 3
	ld a,(0c415h)          ; health: alive -> short knockback, dead -> long
	and a
	ld a,004h
	jr nz,l7010h
	ld a,010h
l7010h:
	ld (0c42ah),a          ; knockback velocity/timer (0xC42A)
	ld de,(0c42eh)
	inc d
	inc e
	ld (0c42eh),de
	ret
l701eh:
	call simon_walk_right
	jp l6fdeh
l7024h:
	ld a,(0c439h)
	and a
	call nz,platform_carry_simon
	ld hl,0c42ah           ; knockback counts down; while nonzero Simon slides
	dec (hl)
	ret nz
	xor a                  ; knockback done: clear the whole hurt state
	ld (0c420h),a          ; action state -> normal
	ld (0c421h),a
	ld (0c423h),a          ; hurt sub-state -> 0
	ld (0c422h),a
	ld (0c42ah),a
	ld (0c428h),a
	ld a,(0c5ach)
	cp 002h
	jr z,l705ah
	cp 003h
	jr z,l705ah
	cp 005h
	jr z,l705ah
	ld a,(0c42ch)
	xor 001h
	ld (0c42ch),a
l705ah:
	ld a,(0c415h)
	and a
	ret nz
	ld hl,0c427h
	ld a,(hl)
	cp 010h
	jr nc,l706ah
	add a,008h
	ld (hl),a
l706ah:
	xor a
	ld (0c42dh),a
	ld (0c421h),a
	inc a
	ld (0c428h),a
	ld a,006h
	ld (0c420h),a
	ld bc,00509h
	ld (0c42eh),bc
	jp simon_mirror_frames
; Signed dY (22 bytes).  Hurt knockback uses this via simon_jump_y_step;
; holy_water_tick doubles each entry for the vial's arc.  l7090h is also a
; VRAM dest (0x7090) in the HUD blits above — keep the label at this address.
l7084h:
	defb 0fdh,0fdh,0feh,0feh,0feh,0ffh,0ffh,0ffh,0ffh,000h,000h,000h
l7090h:
	defb 000h,001h,001h,001h,001h,002h,002h,002h,003h,003h
simon_dying:                   ; 6 (0x709A)
	ld a,(0c421h)
	ld hl,0c428h
l70a0h:
	and a
	jr nz,l70b6h
	dec (hl)
	ret nz
	ld (hl),05ah
	ld a,001h
	ld (0c421h),a
	ld a,000h
	call play_sound
	ld a,089h
	jp play_sound
l70b6h:
	ld hl,0c428h
	dec (hl)
	ret nz
	ld de,0c417h
	ld a,(de)
	cp 005h
	jr c,l70c6h
	ld a,005h
	ld (de),a
l70c6h:
	xor a
	ld (hl),a
	ld (0c421h),a
	ld (0c422h),a
	ld (0c434h),a
	ld (0c43ah),a
	ld (0c43bh),a
	ld (0c440h),a
	ld (0d010h),a
	ld (0d001h),a
	ld (0c413h),a          ; leave play (death)
; inv_reset_life (seg1 0x70E3): new-life / death fallthrough. Keep C701 bit7
; (map); clear weapon, keys, holy water, hourglass, C431/32, C441/42, C700/02.
inv_reset_life:
	ld a,(0c701h)
	and 080h               ; keep map (bit7); holy water/hourglass/keys go
	ld (0c701h),a
	xor a
	ld (0c416h),a
	ld (0c431h),a
	ld (0c432h),a
	ld (0c441h),a
	ld (0c442h),a
	ld (0c702h),a
	ld (0c700h),a
	ret
simon_portal_wait:             ; 7 (0x7102) pad crouch+UP: wait, then warp
	ld a,(0c42dh)
	and a
	ret nz
	xor a
	ld (0c420h),a          ; back to grounded
	ld (0c43dh),a
	ld a,0ffh
	ld (0c41bh),a          ; conn_from_spot: D001 = C5B4
	ret
; simon_attack_tick (0x7114): SPACE starts whip or C416>=2 throw; then whip
; phase + projectile_tick (C450/C460). Jump+dir is holy water / hourglass.
simon_attack_tick:
	call simon_attack_start
	call whip_tick
	jp projectile_tick
; simon_attack_start (seg1 0x711D): SPACE new-press starts whip (or throw if
; C416>=2). If SPACE is not new, jump+dir uses holy water / hourglass.
simon_attack_start:
	ld a,(0c006h)
	and 010h               ; SPACE/trig new-press
	jr z,l713dh
	ld hl,0c422h
	ld a,(hl)
	and a
	ret nz
	ld a,(0c416h)
	ld (0c436h),a
	cp 002h
	jr c,l713ah
	call projectile_alloc
	ld a,b
	and a
	ret z
l713ah:
	ld (hl),001h
	ret
l713dh:
	ld a,(0c420h)
	dec a
	ret nz                 ; hourglass/holy-water only while jumping
	ld a,(0c701h)
	push af
	rra
	rra
	rra
	rra                    ; C701 bit3 = holy water
	call c,holy_water_use
	pop af
	rla
	rla                    ; C701 bit6 = hourglass
	call c,hourglass_use
	ret
; holy_water_use (seg1 0x7154): C701 bit3 (bonus 0x1E).  Only while jumping
; (C420==1) and SPACE is not a new-press.  LEFT or RIGHT new-press, 5 hearts,
; and C461==0 (one vial in flight).  Does not replace C416.
holy_water_use:
	ld a,(0c417h)
	cp 005h
	ret c
	ld a,(0c006h)
	rra
	rra
	rra                    ; C006 bit2 = LEFT
	jr c,holy_water_throw_left
	rra                    ; C006 bit3 = RIGHT
	jr c,holy_water_throw_right
	ret
; hourglass_use (seg1 0x7166): C701 bit6 (bonus id 10).  Only reached from
; l713dh while jumping (C420==1) and SPACE is not a new-press.  Needs a DOWN
; new-press (C006 bit1), 5 hearts, and C43B==0.  Arms C43B (0x5A ~1.5s, or
; 0x96 ~2.5s with id 11) and D010 bit0, which skips enemy AI/movement.
hourglass_use:
	ld a,(0c43bh)
	and a
	ret nz
	ld a,(0c417h)
	cp 005h
	ret c
	ld a,(0c006h)
	rra
	rra
	ret nc
	ld a,(0c417h)
	sub 005h
	daa
	ld (0c417h),a
	call 0456dh
	ld a,(0c431h)
	and 004h
	ld a,096h
	jr nz,l718eh
	ld a,05ah
l718eh:
	ld (0c43bh),a
	ld hl,0d010h
	set 0,(hl)
	ld a,0fbh
	jp play_sound
holy_water_throw_left:         ; (0x719B) C468=1, then throw
	ld a,(0c461h)
	and a
	ret nz
	ld a,001h
	ld (0c468h),a
	jp holy_water_throw
holy_water_throw_right:        ; (0x71A8) C468=0, then throw
	ld a,(0c461h)
	and a
	ret nz
	xor a
	ld (0c468h),a
holy_water_throw:              ; (0x71B1) arm C460 slot as type 5, spend 5 hearts
	call actors_rearm_hittable
	ld a,005h
	ld (0c461h),a          ; projectile type 5 (one in flight)
	ld a,(0c417h)
	sub 005h
	daa
	ld (0c417h),a
	jp 0456dh
; projectile_alloc (0x71C5): find a free C450/C460 slot (+1==0), set +0=1.
; Knife (C436==2) may occupy both slots; axe/cross take one.
projectile_alloc:
	ld a,(0c436h)
	cp 002h
	ld b,002h
	jr z,l71cfh
	dec b
l71cfh:
	ld ix,0c450h
l71d3h:
	ld a,(ix+001h)
	and a
	jr nz,l71dfh
	ld a,001h
	ld (ix+000h),a
	ret
l71dfh:
	ld de,00010h
	add ix,de
	djnz l71d3h
	ret
; whip_tick (0x71E7): if 0xC422 (whip phase) is 1..4, dispatch the anim.
; Phase 0 = idle (ret).  0xC420>=4 (fall/hurt/dying) suppresses whipping.
whip_tick:
	ld a,(0c422h)
	and a
	ret z
	ld a,(0c420h)
	cp 004h
	ret nc
	ld a,(0c422h)
	dec a
	call DISPATCH_A
	defw l7201h
	defw l7247h
	defw l7257h
	defw l7269h
l7201h:
	ld a,(0c420h)
	cp 003h
	jr z,simon_torso_from_weapon
	cp 002h
	ld a,000h
	jr nz,l7210h
	ld a,006h
l7210h:
	ld (0c42eh),a
simon_torso_from_weapon:                        ; set torso frame 0xC42F from weapon 0xC436
	ld a,(0c436h)
	cp 002h
	jr nc,l7231h
	ld a,(0c436h)
	dec a
	ld a,006h
	jr nz,l7224h
	ld a,009h
l7224h:
	ld (0c42fh),a
	call simon_mirror_frames
	ld a,005h
	call play_sound
	jr l7242h
l7231h:
	call load_weapon_sprites
	ld a,00ch
	ld (0c42fh),a
	call simon_mirror_frames
	jr l7242h
	xor a
l723fh:
	ld (0c429h),a
l7242h:
	ld hl,0c422h
	inc (hl)
	ret
l7247h:
	ld hl,0c42fh
	inc (hl)
	call l7242h
	ld a,(0c436h)
	cp 002h
	ret c
	jp load_weapon_sprites
l7257h:
	ld a,(0c436h)
	cp 002h
	jr nc,l7247h
	call actors_rearm_hittable
	ld hl,0c42fh
	inc (hl)
	ld a,004h
	jr l723fh
l7269h:
	ld a,(0c436h)
	cp 002h
	jr nc,projectile_arm
	ld hl,0c429h
	dec (hl)
	ret nz
; simon_attack_end (seg1 0x7275): clear whip phase/timer; torso 0, or 2 on
; stairs.  Melee whip timeout and projectile_arm both land here.
simon_attack_end:
	xor a
	ld (0c422h),a          ; whip phase
	ld (0c429h),a          ; whip timer
	ld a,(0c420h)
	cp 003h
	ld a,000h
	jr nz,l7287h
	ld a,002h              ; on stairs: keep climb torso
l7287h:
	ld (0c42fh),a
	jp simon_mirror_frames
projectile_arm:                ; (0x728D) whip-phase 4: copy C436 into a waiting slot
	call actors_rearm_hittable
	call simon_attack_end
	ld ix,0c450h
	ld b,002h
l7299h:
	ld a,(ix+000h)
	dec a
	jr nz,l72b1h
	ld a,018h
	ld (ix+006h),a
	ld a,(0c42ch)
	ld (ix+008h),a
	ld a,(0c436h)
	ld (ix+001h),a
	ret
l72b1h:
	ld de,00010h
	add ix,de
	djnz l7299h
	ret
; C450 / C460 projectile slots (stride 0x10): +0 state, +1 type (C416 or 5),
; +2 velY, +3 velX, +4 Y, +5 X, +6 pattern, +7 phase, +8 facing.
projectile_tick:               ; (0x72B9) both slots: motion, integrate, clip, SAT
	ld ix,0c450h
	call projectile_tick_slot
	ld ix,0c460h
projectile_tick_slot:
	ld a,(ix+001h)
	and a
	ret z
	call projectile_motion
	call projectile_integrate
	call projectile_clip
	jp l753ch
projectile_motion:
	ld a,(ix+001h)
	dec a
	dec a                    ; type-2: 2=knife 3=axe 4=cross 5=holy
	call DISPATCH_A
	defw knife_tick
	defw axe_tick
	defw cross_tick
	defw holy_water_tick   ; type 5 (C461; not a C416 weapon)
cross_tick:                    ; (0x72E5) C416=4, bonus 0x1D; vel ±5, SAT 0x0F/0x0E
	ld a,(0c003h)
	ld c,a
	rra
	rra
	and 003h
	add a,a
	add a,a
	add a,a
	add a,018h
	ld (ix+006h),a
	ld a,c
	and 007h
	jr nz,l72ffh
	ld a,003h
	call play_sound
l72ffh:
	ld a,(ix+000h)
	dec a
	call DISPATCH_A
	defw boomerang_throw
	defw boomerang_out
	defw boomerang_back
	defw boomerang_catch
boomerang_throw:               ; (0x730E) copy Simon pos; velX ±3 (axe) / ±5 (cross)
	ld a,(0c420h)
	cp 002h
	ld a,(0c425h)
	ld b,0f0h
	jr nz,l731ch
	ld b,0f6h
l731ch:
	add a,b
	ld (ix+004h),a
	xor a
	ld (ix+002h),a
	ld a,(ix+001h)
	cp 003h
	ld b,003h
	jr z,l732fh
	ld b,005h
l732fh:
	ld a,(ix+008h)
	and a
	ld a,b
	jr z,l7338h
	neg
l7338h:
	ld (ix+003h),a
	ld a,(0c427h)
	ld (ix+005h),a
	jp l7356h
boomerang_out:                 ; (0x7344) 24 frames or screen-edge, then turn
	ld a,(ix+005h)
	sub 00ah
	cp 0ech
	jr nc,l7360h
	inc (ix+007h)
	ld a,(ix+007h)
	cp 018h
	ret c
l7356h:
	inc (ix+000h)
	ld (ix+007h),000h
	jp actors_rearm_hittable
l7360h:
	inc (ix+000h)
l7363h:
	inc (ix+000h)
	ld a,(ix+008h)
	and a
	ld a,005h
	jr nz,l7370h
	ld a,0fbh
l7370h:
	ld (ix+003h),a
	ld (ix+007h),000h
	jp actors_rearm_hittable
boomerang_back:                ; (0x737A) decelerate, reverse; overlap Simon = catch
	call proj_overlap_simon
	jp c,projectile_clear
	ld a,(ix+005h)
	sub 00ah
	cp 0ech
	jr nc,l7363h
	inc (ix+007h)
	ld a,(ix+007h)
	cp 017h
	jp nc,l7356h
	rra
	ret nc
	ld a,(ix+008h)
	and a
	jr nz,l73a0h
	dec (ix+003h)
	ret
l73a0h:
	inc (ix+003h)
	ret
boomerang_catch:               ; (0x73A4) overlap Simon -> despawn (keep C416)
	call proj_overlap_simon
	ret nc
	jp projectile_clear
; holy_water_tick (seg1 0x73AB): C460 slot type 5.  State 0/1 spawn at Simon
; (Y=C425+offset, X=C427, velX=±2 from C468, velY=0).  State 2 = arc
; (Y += 2*l7084h[phase], land via map_solid_pair tile_is_solid).  State 3 =
; floor flame (24 frames, SAT colour 8, patterns 0xF4/0xF8 — same
; actor_flame sheet as a falling heart; pixels in gfx_rle_a185).
holy_water_tick:
	ld a,(ix+000h)
	dec a
	dec a
	jr z,holy_water_arc    ; state 2
	dec a
	jr z,holy_water_flame  ; state 3
	ld a,(0c420h)
	cp 002h
	ld a,(0c425h)
	ld b,0f0h
	jr nz,l73c3h
	ld b,0f6h
l73c3h:
	add a,b
	ld (ix+004h),a
	xor a
	ld (ix+002h),a
	ld a,(ix+008h)
	and a
	ld a,002h
	jr z,l73d5h
	ld a,0feh
l73d5h:
	ld (ix+003h),a
	ld a,(0c427h)
	ld (ix+005h),a
	ld (ix+006h),038h
	jp l7356h
holy_water_arc:                ; (0x73E5) Y += 2*l7084h[ix+7]; land -> flame
	ld a,(ix+007h)
	ld hl,l7084h
	call ADD_HL_A
	ld c,(ix+004h)
	ld a,(hl)
	add a,a
	add a,c
	ld (ix+004h),a
	inc (ix+007h)
	ld a,(ix+007h)
	cp 016h
	jr c,l7404h
	dec (ix+007h)
l7404h:
	ld d,(ix+005h)
	ld e,(ix+004h)
	call map_solid_pair
	ret nc
	inc (ix+000h)
	xor a
	ld (ix+002h),a
	ld (ix+003h),a
	ld (ix+007h),a
	ld a,018h
	jp play_sound
holy_water_flame:              ; (0x7420) 0x18 frames burning on the floor, then despawn
	ld a,(0c003h)
	and 004h
	ld a,0f4h
	jr z,l742eh
	call actors_rearm_hittable
	ld a,0f8h
l742eh:
	ld (ix+006h),a
	inc (ix+007h)
	ld a,(ix+007h)
	cp 018h
	ret c
	jp projectile_clear
knife_tick:                    ; (0x743D) C416=2, bonus 0x1B; straight ±5, 1 or 2 slots
	ld a,(ix+000h)
	dec a
	ret nz
	ld a,(0c420h)
	cp 002h
	ld a,(0c425h)
	ld b,0f0h
	jr nz,l7450h
	ld b,0f6h
l7450h:
	add a,b
	ld (ix+004h),a
	xor a
	ld (ix+002h),a
	ld a,(ix+008h)
	and a
	ld a,005h
	ld b,020h
	jr z,l7466h
	ld a,0fbh
	ld b,018h
l7466h:
	ld (ix+003h),a
	ld (ix+006h),b
	ld a,(0c427h)
	ld (ix+005h),a
	inc (ix+000h)
	ld a,004h
	jp play_sound
axe_tick:                      ; (0x747A) C416=3, bonus 0x1C; vel ±3, smaller throw
	ld a,(0c003h)
	ld c,a
	rra
	and 003h
	add a,a
	add a,a
	add a,a
	add a,018h
	ld (ix+006h),a
	ld a,c
	and 007h
	jr nz,l7493h
	ld a,006h
	call play_sound
l7493h:
	ld hl,0c433h
	ld a,(hl)
	sub 002h
	cp 002h
	jr c,l74ach
	ld a,(ix+000h)
	dec a
	call DISPATCH_A
	defw boomerang_throw
	defw boomerang_out
	defw boomerang_back
	defw boomerang_catch
l74ach:
	ld (hl),000h           ; C433 in {2,3}: drop bonus 0x1C (this weapon) and unequip
	ld b,01ch
	ld d,(ix+005h)
	ld a,(ix+004h)
	sub 010h
	ld e,a
	call 08999h
	call projectile_clear
	jp lose_weapon
projectile_integrate:
	ld a,(ix+004h)
	add a,(ix+002h)
	ld (ix+004h),a
	ld a,(ix+005h)
	add a,(ix+003h)
	ld (ix+005h),a
	ret
projectile_clip:
	ld a,(ix+004h)
	sub 0d8h
	cp 010h
	jr c,projectile_clear
	ld a,(ix+005h)
	sub 0fbh
	cp 00ah
	ret nc
	ld a,(0c416h)
	sub 003h
	cp 002h
	call c,lose_weapon     ; cross/axe leaving the X wrap zone: lose the weapon
projectile_clear:
	push ix
	pop hl
projectile_clear_hl:
	push hl
	ld (hl),000h
	ld d,h
	ld e,l
	inc de
	ld bc,0000fh
	ldir
	pop hl
	ld a,l
	cp 050h
	ld a,0e0h
	jr nz,l750eh
	ld (0d618h),a
	ld (0d61ch),a
	jr l7514h
l750eh:
	ld (0d620h),a
	ld (0d624h),a
l7514h:
	inc l
	inc l
	inc l
	inc l
	ld (hl),a
	ret
whip_slots_clear:
	ld hl,0c450h
	ld (hl),000h
	ld d,h
	ld e,l
	inc de
	ld bc,0001fh
	ldir
	ld a,0e0h
	ld (0c454h),a
	ld (0c464h),a
	ld (0d618h),a
	ld (0d61ch),a
	ld (0d620h),a
	ld (0d624h),a
	ret
l753ch:
	ld a,(ix+000h)
	and a
	ret z
	push ix
	pop hl
	ld a,l
	cp 050h
	ld hl,0d618h
	jr z,l754fh
	ld hl,0d620h
l754fh:
	ld a,(ix+004h)
	sub 010h
	ld (hl),a
	inc hl
	ld a,(ix+005h)
	sub 008h
	ld (hl),a
	inc hl
	ld a,(ix+006h)
	ld (hl),a
	inc hl
	inc hl
	ld a,(ix+004h)
	sub 010h
	ld (hl),a
	inc hl
	ld a,(ix+005h)
	sub 008h
	ld (hl),a
	inc hl
	ld a,(ix+006h)
	add a,004h
	ld (hl),a
	push ix
	pop hl
	ld a,l
	cp 050h
	ld hl,0d460h
	jr z,l7585h
	ld hl,0d480h
l7585h:
	ld a,(ix+001h)
	cp 004h
	jr nz,l759ch           ; type 4 (cross): SAT colours 0x0F / 0x0E
	ld a,00fh
	ld b,010h
	call sat_fill
	ld a,00eh
	ld b,010h
sat_fill:                          ; fill B bytes at HL with A (SAT colour run)
	ld (hl),a
	inc hl
	djnz sat_fill
	ret
l759ch:
	ld a,002h
	ld b,010h
	call sat_fill
	ld a,04ch
	ld b,010h
	call sat_fill
	ld a,(ix+001h)
	cp 005h
	ret nz
	ld a,(ix+000h)
	cp 003h
	ret nz                 ; type 5 state 3 = holy-water flame: SAT colour 8
	ld hl,0d480h
	ld de,0d490h
	ld b,010h
l75beh:
	ld (hl),008h
	xor a
	ld (de),a
	inc hl
	inc de
	djnz l75beh
	ret
; Per-frame countdown bank: decrement each of these timers toward 0 (clamped).
;   0xC440 - enemy-spawn suppression (rosary / weapon-pickup grace); while nonzero
;            room_spawner (seg0 0x5EBF) spawns nothing.
;   0xC434 / 0xC42D - per-frame timers (C42D = i-frames, also portal wind-up).
timers_tick:
	ld hl,0c440h           ; rosary / weapon-pickup no-spawn
	call dec_nonzero
	ld hl,0c434h           ; sapphire ring
	call dec_nonzero
	ld hl,0c42dh           ; i-frames / portal wind-up (falls into dec_nonzero)
dec_nonzero:
	ld a,(hl)
	and a
	ret z
	dec (hl)
	ret
boss_flash_delay_tick:         ; C445; on 0 arm backdrop flash C43E=0x18
	ld hl,0c445h
	ld a,(hl)
	and a
	ret z
	dec (hl)
	ret nz
	ld a,018h
	ld (0c43eh),a
	ret
gem_timer_tick:                ; C43A invis; sfx 0x17 (gem warn) at 16 frames left
	ld hl,0c43ah
	ld a,(hl)
	and a
	ret z
	dec (hl)
	ld a,(hl)
	cp 010h
	ret nz
	ld a,017h
	jp play_sound
hourglass_timer_tick:          ; C43B freeze; on 0: res D010.0, restore BGM (0xFC)
	ld hl,0c43bh
	ld a,(hl)
	and a
	ret z
	dec (hl)
	ret nz
	ld hl,0d010h
	res 0,(hl)
	ld a,0fch
	jp play_sound
backdrop_flash_tick:           ; C43E: CHGCLR 0x0E/0 (white cross / boss-kill flash)
	ld hl,0c43eh
	ld a,(hl)
	and a
	ret z
	dec (hl)
	and 002h
	ld a,00eh
	jr nz,l7619h
	xor a
l7619h:
	ld (0f3ebh),a
	jp CHGCLR
l761fh:
	ld a,(0c422h)
	and a
	jr nz,l7655h
	ld a,(0c701h)
	and 030h
	ret z
	ld hl,0c42eh
	ld a,(hl)
	cp 014h
	jr nc,l7636h
	add a,014h
	ld (hl),a
l7636h:
	inc hl
	ld a,(hl)
	ld b,01eh
	and a
	jr z,l7653h
	inc b
	dec a
	jr z,l7653h
	inc b
	dec a
	jr z,l7653h
	ld a,(hl)
	ld b,021h
	sub 00fh
	jr z,l7653h
	inc b
	dec a
	jr z,l7653h
	inc b
	dec a
	ret nz
l7653h:
	ld (hl),b
	ret
l7655h:
	ld a,(0c420h)
	cp 003h
	ret nz
	ld hl,0c42eh
	ld a,(hl)
	cp 014h
	ret c
	sub 014h
	ld (hl),a
	ret
; simon_mirror_frames (0x7666): if facing left (0xC42C!=0), add 0x0A/0x0F to
; the walk/torso frame pair at 0xC42E/0xC42F so the left-facing cells are used.
simon_mirror_frames:
	ld a,(0c42ch)
	and a
	ret z
	ld hl,(0c42eh)
	ld a,l
	cp 00ah
	jr nc,l7676h
	add a,00ah
	ld l,a
l7676h:
	ld a,h
	cp 00fh
	jr nc,l767eh
	add a,00fh
	ld h,a
l767eh:
	ld (0c42eh),hl
	ret
; room_edge_detect (seg1 0x7682): per-frame room-EDGE / stair detector.  Compares
; Simon's Y (0xC425) and X (0xC427) against the screen bounds and, when he steps
; past an edge, records the pending-exit direction in 0xC41B (1=up 2=down 3=left
; 4=right) - which the transition brain (seg13 0xB963, via seg0 conn_lookup_paged) turns
; into the new 0xD001.  Horizontal exits also gate on the cached permit bytes
; 0xC41E/0xC41F (0xFF = blocked); a blocked horizontal edge is instead handled as
; a stage boundary at l77d8h/set_stage_boundary.  0xC420 = Simon's action state
; (3 = on stairs, 6 = mid-transition -> skip).
room_edge_detect:
	ld a,(0c420h)
	cp 006h
	ret z                  ; already transitioning -> nothing to do
	ld hl,0c41bh           ; hl -> pending-exit dir
	ld de,0c425h           ; de -> Simon Y
	ld bc,0c427h           ; bc -> Simon X
	ld a,(0c420h)
	cp 003h                ; on stairs?
	ld a,(de)              ; A = Y
	jr nz,l769dh
	cp 030h
	jr c,room_edge_up            ; on stairs & near top -> up exit
l769dh:
	cp 0e1h
	jr nc,room_edge_down           ; past bottom -> down exit
	ld a,(bc)              ; A = X
	cp 008h
	jr c,room_edge_left            ; past left -> left exit (if permitted)
	cp 0f8h
	jr nc,room_edge_right           ; past right -> right exit (if permitted)
	ret
room_edge_up:                        ; top edge (climbing off the top of a stairway)
	ld a,(0c420h)
	dec a
	ret z
	ld a,0e0h
	ld (de),a              ; wrap Y to bottom of the new (upper) room
	ld a,(0c42ch)
	and a
	ld d,0f0h
	jr z,l76bdh
	ld d,010h
l76bdh:
	ld a,(bc)
	add a,d                ; nudge X toward the stair landing
	ld (bc),a
	ld (hl),001h           ; pending dir = 1 (up)
	ret
room_edge_down:                        ; past the bottom edge
	ld a,(0c41dh)          ; down exit permit
	inc a
	jr nz,room_edge_down_go           ; there IS a room below -> normal down transition
	xor a                  ; no room below: bottomless pit -> fall to death
	ld (0c421h),a
	ld a,006h
	ld (0c420h),a          ; action state 6 (falling/dying)
	ld a,0fah
	ld (de),a
	ld hl,0c428h
	ld a,01eh
	ld (hl),a
	ld a,(0d000h)
	cp 002h
	jr z,l76eah
	cp 00ah
	jr z,l76eah
	ld a,001h
	ld (hl),a
	ret
l76eah:
	ld a,009h
	jp play_sound
room_edge_down_go:                        ; room below exists -> down transition
	ld a,030h
	ld (de),a              ; wrap Y to top of the new (lower) room
	ld a,(0c420h)
	cp 003h
	jr nz,l7706h
	ld a,(0c42ch)
	and a
	ld d,0f0h
	jr z,l7703h
	ld d,010h
l7703h:
	ld a,(bc)
	add a,d
	ld (bc),a
l7706h:
	ld (hl),002h           ; pending dir = 2 (down)
	ret
room_edge_left:                        ; left edge
	ld a,(0c41eh)          ; left exit permit
	inc a
	ret z                  ; 0xFF = blocked -> no horizontal room here
	ld a,0f6h
	ld (bc),a              ; wrap X to right side of the new room
	ld (hl),003h           ; pending dir = 3 (left)
	ret
room_edge_right:                        ; right edge
	ld a,(0c41fh)          ; right exit permit
	inc a
	ret z                  ; 0xFF = blocked -> no horizontal room here
	ld a,00ah
	ld (bc),a              ; wrap X to left side of the new room
	ld (hl),004h           ; pending dir = 4 (right)
	ret
; door_interact (seg1 0x771f): white-key door tick, dispatched by 0xC5AC
; through door_state_tbl.  Placement is NOT a 0x1F object:
; seg13 door_load_coords copies door_tbl[stage] into 0xC5AD=Y / 0xC5AE=X when
; 0xD001 matches the record's room nibble.  This handler proximity-tests Simon
; (0xC425=Y, 0xC427=X) against those coords via door_proximity; on overlap it
; spends the white key (0xC701 bit0; courtyard/stage 0 opens freely) and starts
; the open effect.  After the door is open, walking the edge is a SEPARATE
; layer (l77d8h): blocked permit -> set_stage_boundary / advance_stage; valid
; room -> intra-stage wrap (stages 3,6,9,12,15,18).
door_interact:
	ld a,(0c5ach)          ; door sub-state (armed=1, open=3, ...)
	call DISPATCH_A
door_state_tbl:
	defw door_idle         ; 0
	defw door_try_open     ; 1 armed
	defw door_idle         ; 2
	defw door_open_walk    ; 3 open
	defw door_try_open     ; 4
	defw door_open_walk    ; 5 vertical
door_try_open:
	ld de,0c425h           ; de -> Simon Y
	ld a,(de)
	ld b,a                 ; B = Y
	inc e
	inc e                  ; de -> 0xC427
	ld a,(de)
	ld c,a                 ; C = X
	call door_proximity    ; overlap door @ 0xC5AD=Y / 0xC5AE=X? carry=yes
	ret nc                 ; not at the door -> nothing to open
	ld hl,0c701h           ; inventory byte
	ld a,(0d000h)
	and a
	jr z,l774ah            ; stage 0 (courtyard): open freely, no key needed
	ld a,(hl)
	rra                    ; white key = bit 0 -> carry
	ret nc                 ; no white key -> door stays shut
l774ah:
	res 0,(hl)             ; spend the white key (clear bit 0)
	call 08ec1h            ; play door-open effect
	xor a
	ld (0c422h),a
	call actors_kill_all
	call whip_slots_clear
	ld hl,0c5ach
	inc (hl)
	ld a,(0d000h)
	ld de,stage_bgm_change
	call ADD_DE_A
	ld a,(de)
	and a
	jr z,l776fh
	ld a,0ffh
	call play_sound
l776fh:
	ld a,(hl)
	cp 005h
	jr z,l7779h
	ld a,01ah
	jp play_sound
l7779h:
	ld a,015h
	jp play_sound
; stage_bgm_change (seg1 0x777E): byte[stage 0..18].  1 = BGM changes
; leaving this stage (door_interact fades) / entering the next
; (stage_bgm_play indexes [stage-1]).
stage_bgm_change:
	defb 000h,000h,000h        ; 0-2 (courtyard..s2 share 0x80)
	defb 001h,000h,000h        ; 3-5 (s3 door -> 0x81)
	defb 001h,000h,000h        ; 6-8
	defb 001h,001h,000h        ; 9-11
	defb 001h,000h,000h        ; 12-14
	defb 001h,000h,001h        ; 15-17
	defb 001h                  ; 18
; door_open_walk (seg1 0x7791): C5AC 3/5.  Vertical door loads extra sprites,
; then if Simon is grounded auto-walk through the opening.
door_open_walk:
	ld a,(0c5ach)
	cp 005h
	call z,load_vdoor_sprites
	ld a,(0c420h)
	and a
	ret nz
	ld bc,00000h
	ld (0c42eh),bc
	call simon_mirror_frames
	ld a,(0c42ch)
	and a
	ld bc,00080h
	jr z,l77b4h
	ld bc,0ff80h
l77b4h:
	call simon_add_x
	call simon_step_walk_frames
	ld a,(0c5ach)
	cp 005h
	jr z,l77cbh
	ld a,(0c427h)
	sub 008h
	cp 0f0h
	ret c
	jr l77d8h
l77cbh:
	ld a,(0c5aeh)          ; door X
	add a,008h
	ld b,a
	ld a,(0c427h)          ; Simon X
	sub b
	cp 008h
	ret nc                 ; not standing in the open door -> stay
; Post-open walk: Simon reached a left/right edge (or the open-door X window
; above).  The connectivity permit decides the DESTINATION, not whether a door
; exists - the door object already opened.  Picks 0xC41E = left, 0xC41F = right
; (seg13 CONN nibbles, 0xB99A).  Heading is 0xC427 bit7 (rla: set = right).
; 0xFF = blocked -> set_stage_boundary / advance_stage; else wrap to that room
; (the intra-stage key-door cases: 3,6,9,12,15,18).
l77d8h:
	ld hl,0c41eh           ; hl -> left exit permit (0xC41E)
	ld de,0c427h           ; de -> Simon X / heading byte
	ld a,(de)
	rla                    ; carry = heading bit7 (set -> moving right)
	jr c,l77ebh            ; right edge -> use the right permit
	ld a,(hl)              ; left permit (0xC41E)
	inc a
	jr z,set_stage_boundary ; 0xFF = blocked edge -> STAGE EXIT
	ld bc,003f6h           ; b=3 pending dir "left"; c=0xF6 X-wrap to right side
	jr l77f3h
l77ebh:
	inc hl                 ; hl -> right exit permit (0xC41F)
	ld a,(hl)
	inc a
	jr z,set_stage_boundary ; 0xFF = blocked edge -> STAGE EXIT
	ld bc,0040ah           ; b=4 pending dir "right"; c=0x0A X-wrap to left side
l77f3h:
	ld a,b
	ld (0c41bh),a          ; pending-exit dir (1=up 2=down 3=left 4=right)
	ld a,c
	ld (de),a              ; wrap Simon's X to the far side of the new room
	ld a,(0d000h)
	cp 012h                ; stage 18? -> different transition action id
	ld a,087h
	jr nz,l7804h
	ld a,086h
l7804h:
	jp play_sound              ; queue the room-transition action
; set_stage_boundary (seg1 0x7807): walking a BLOCKED left/right edge after the
; door is open.  0xC408 is later seen by the frame dispatcher (seg0 0x424xh)
; which calls 0x438B (clears 0xC701 bit0 if still set) and advance_stage.
; The key was already spent by door_interact when the door opened.
set_stage_boundary:
	ld a,001h
	ld (0c408h),a          ; stage-boundary flag -> advance_stage
door_idle:
	ret
; actors_kill_all (seg1 0x780D): C800 via actor_cull (no drops) + D700 via
; shot_death_flame. White cross / boss kill.
actors_kill_all:
	ld ix,0c800h
	ld b,007h
l7813h:
	ld a,(ix+000h)
	and a
	push bc
	push ix
	call nz,actor_cull
	pop ix
	pop bc
	ld de,00080h
	add ix,de
	djnz l7813h
	ld ix,0d700h
	ld b,008h
l782dh:
	ld a,(ix+000h)
	and a
	push bc
	call nz,shot_death_flame
	pop bc
	ld de,00080h
	add ix,de
	djnz l782dh
	ret
; simon_sat_build (seg1 0x783E): emit Simon's hardware-sprite SAT from
; 0xC42E/0xC42F via simon_sat_cell0/1.  Hides unused slots (Y=0xE0);
; simon_sat_colour applies gem/ring flash colours.
simon_sat_build:
	call simon_sat_colour
	ld a,(0c5ach)
	cp 005h
	jr z,l785fh
	ld de,0d610h
	ld a,(0c416h)
	cp 002h
	ld b,004h
	jr c,l7856h
	ld b,002h
l7856h:
	ld a,0e0h
l7858h:
	ld (de),a
	inc de
	inc de
	inc de
	inc de
	djnz l7858h
l785fh:
	ld a,(0c42eh)
	add a,a
	ld hl,simon_sat_cell0
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	ld c,000h
	ld a,(0c5ach)
	cp 005h
	ld de,0d600h
	jr nz,l787ch
	ld de,0d620h
l787ch:
	ld b,(hl)
	inc hl
	call simon_sat_emit
	ld a,(0c42fh)
	add a,a
	ld hl,simon_sat_cell1
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	ld c,002h
	ld a,(0c5ach)
	cp 005h
	ld de,0d608h
	jr nz,l789eh
	ld de,0d628h
l789eh:
	ld b,(hl)
	inc hl
; simon_sat_emit (seg1 0x78A0): one SAT record (count already in B, HL at
; dy).  Y = C425+dy, crouch frames (C42E 6/10/1A/24) nudge ±6; i-frame
; blink hides (Y=0xE0).  SAT Y is visual-1.  dx bit7 = mirror vs C427.
simon_sat_emit:
	ld a,(0c425h)
	add a,(hl)
	push bc
	ld b,a
	ld a,(0c42eh)
	cp 006h
	jr z,l78b9h
	cp 010h
	jr z,l78b9h
	cp 01ah
	jr z,l78b9h
	cp 024h
	jr nz,l78d3h
l78b9h:
	ld a,(0c420h)
	dec a
	jr nz,l78cah
	ld a,c
	cp 002h
	jr nc,l78d3h
	ld a,b
	sub 006h
	ld b,a
	jr l78d3h
l78cah:
	ld a,c
	cp 002h
	jr c,l78d3h
	ld a,b
	add a,006h
	ld b,a
l78d3h:
	ld a,(0c42dh)
	and a
	jr z,l78e2h
	ld a,(0c003h)
	and 002h
	jr z,l78e2h
	ld b,0e0h              ; i-frame blink: hide this sprite
l78e2h:
	ld a,b
	pop bc
	sub 002h
	ld (de),a
	inc hl
	inc de
	push bc
	ld b,(hl)
	ld a,(0c427h)
	ld c,a
	rl b
	jr nc,l78fdh
	rr b
	ld a,b
	neg
	ld b,a
	ld a,c
	sub b
	jr l78feh
l78fdh:
	add a,(hl)
l78feh:
	jr nc,l7905h
	dec de
	ld a,0e0h
	ld (de),a
	inc de
l7905h:
	ld (de),a
	pop bc
	inc hl
	inc de
	ld a,c
	add a,a
	add a,a
	ld (de),a
	inc c
	inc de
	inc de
	djnz simon_sat_emit
	ret
; simon_sat_colour (seg1 0x7913): fill D400/D480 CC.  Leather/chain: 0x80
; bytes; subweapon: 0x40.  Blue gem (C43A) flashes white 0x0E; sapphire
; ring (C434) flashes red 0x08; else 0x01 / 0x42 by 16-byte band.
simon_sat_colour:
	ld a,(0c416h)
	cp 002h
	ld b,080h
	jr c,l791eh
	ld b,040h
l791eh:
	ld a,(0c5ach)
	cp 005h
	ld hl,0d400h
	jr nz,l792bh
	ld hl,0d480h
l792bh:
	ld a,(0c43ah)
	and a
	jr z,l7939h
	ld a,(0c003h)
	rra
	ld a,00eh              ; blue gem (id 8): flash sprite white
	jr c,l7951h
l7939h:
	ld a,(0c434h)
	and a
	jr z,l7947h
	ld a,(0c003h)
	rra
	ld a,008h              ; sapphire ring (id 9): flash sprite red
	jr c,l7951h
l7947h:
	ld a,b
	dec a
	and 010h
	ld a,001h
	jr nz,l7951h
	ld a,042h
l7951h:
	ld (hl),a
	inc hl
	djnz l792bh
	ret
; stage_bgm_play (seg1 0x7956): queue this stage's BGM.  Stage 0 always
; plays; otherwise stage_bgm_change[stage-1] must be nonzero.  0xC40D
; (set on death-respawn) forces a replay.
stage_bgm_play:
	ld a,(0c40dh)          ; force replay (death -> state_stage_bridge)
	and a
	jr nz,l796ch
	ld a,(0d000h)
	and a
	jr z,l796ch            ; courtyard always starts 0x80
	dec a
	ld hl,stage_bgm_change
	call ADD_HL_A
	ld a,(hl)
	and a
	ret z                  ; same track as previous stage
l796ch:
	ld a,(0d000h)
	ld hl,stage_bgm_tbl
	call ADD_HL_A
	ld a,(hl)
	jp play_sound
; stage_bgm_tbl (seg1 0x7979): music id per stage 0..18 (play_sound 0x80..).
stage_bgm_tbl:
	defb 080h,080h,080h,080h  ; stages 0-3
	defb 081h,081h,081h        ; 4-6
	defb 082h,082h,082h        ; 7-9
	defb 085h                  ; 10
	defb 081h,081h              ; 11-12
	defb 084h,084h,084h        ; 13-15
	defb 083h,083h              ; 16-17
	defb 085h                  ; 18
; simon_sat_cell0 (seg1 0x798C): word[0xC42E] -> SAT record (count, dy,dx...).
; 40 frames; indices 0x0A+ are the facing-left copies of 0-9.
simon_sat_cell0:
	defw simon_sat_7a24          ; 0
	defw simon_sat_7a24          ; 1
	defw simon_sat_7a24          ; 2
	defw simon_sat_7a24          ; 3
	defw simon_sat_7a24          ; 4
	defw simon_sat_7a24          ; 5
	defw simon_sat_7a29          ; 6
	defw simon_sat_7a2e          ; 7
	defw simon_sat_7a2e          ; 8
	defw simon_sat_7a33          ; 9
	defw simon_sat_7a38          ; 10
	defw simon_sat_7a38          ; 11
	defw simon_sat_7a38          ; 12
	defw simon_sat_7a38          ; 13
	defw simon_sat_7a38          ; 14
	defw simon_sat_7a38          ; 15
	defw simon_sat_7a3d          ; 16
	defw simon_sat_7a42          ; 17
	defw simon_sat_7a42          ; 18
	defw simon_sat_7a47          ; 19
	defw simon_sat_7a24          ; 20
	defw simon_sat_7a24          ; 21
	defw simon_sat_7a24          ; 22
	defw simon_sat_7a24          ; 23
	defw simon_sat_7a24          ; 24
	defw simon_sat_7a24          ; 25
	defw simon_sat_7a29          ; 26
	defw simon_sat_7a2e          ; 27
	defw simon_sat_7a2e          ; 28
	defw simon_sat_7a33          ; 29
	defw simon_sat_7a38          ; 30
	defw simon_sat_7a38          ; 31
	defw simon_sat_7a38          ; 32
	defw simon_sat_7a38          ; 33
	defw simon_sat_7a38          ; 34
	defw simon_sat_7a38          ; 35
	defw simon_sat_7a3d          ; 36
	defw simon_sat_7a42          ; 37
	defw simon_sat_7a42          ; 38
	defw simon_sat_7a47          ; 39

; simon_sat_cell1 (seg1 0x79DC): word[0xC42F] -> torso/whip SAT. 36 frames;
; indices 0x0F+ are the facing-left copies.
simon_sat_cell1:
	defw simon_sat_7a4c          ; 0
	defw simon_sat_7a4c          ; 1
	defw simon_sat_7a4c          ; 2
	defw simon_sat_7a56          ; 3
	defw simon_sat_7a56          ; 4
	defw simon_sat_7a5b          ; 5
	defw simon_sat_7a60          ; 6
	defw simon_sat_7a6d          ; 7
	defw simon_sat_7a76          ; 8
	defw simon_sat_7a60          ; 9
	defw simon_sat_7a6d          ; 10
	defw simon_sat_7a76          ; 11
	defw simon_sat_7a83          ; 12
	defw simon_sat_7a83          ; 13
	defw simon_sat_7a88          ; 14
	defw simon_sat_7a91          ; 15
	defw simon_sat_7a91          ; 16
	defw simon_sat_7a91          ; 17
	defw simon_sat_7a9b          ; 18
	defw simon_sat_7a9b          ; 19
	defw simon_sat_7aa0          ; 20
	defw simon_sat_7aa5          ; 21
	defw simon_sat_7ab2          ; 22
	defw simon_sat_7abb          ; 23
	defw simon_sat_7aa5          ; 24
	defw simon_sat_7ab2          ; 25
	defw simon_sat_7abb          ; 26
	defw simon_sat_7ac8          ; 27
	defw simon_sat_7ac8          ; 28
	defw simon_sat_7acd          ; 29
	defw simon_sat_7a4c          ; 30
	defw simon_sat_7a4c          ; 31
	defw simon_sat_7a4c          ; 32
	defw simon_sat_7a91          ; 33
	defw simon_sat_7a91          ; 34
	defw simon_sat_7a91          ; 35

simon_sat_7a24:
	defb 002h              ; 2 sprite(s)
	defb 0f2h, 0f8h
	defb 0f2h, 0f8h
simon_sat_7a29:
	defb 002h              ; 2 sprite(s)
	defb 0f8h, 0f8h
	defb 0f8h, 0f8h
simon_sat_7a2e:
	defb 002h              ; 2 sprite(s)
	defb 0f1h, 0f8h
	defb 0f1h, 0f8h
simon_sat_7a33:
	defb 002h              ; 2 sprite(s)
	defb 0f1h, 0f0h
	defb 0f1h, 0f0h
simon_sat_7a38:
	defb 002h              ; 2 sprite(s)
	defb 0f2h, 0f9h
	defb 0f2h, 0f9h
simon_sat_7a3d:
	defb 002h              ; 2 sprite(s)
	defb 0f8h, 0f9h
	defb 0f8h, 0f9h
simon_sat_7a42:
	defb 002h              ; 2 sprite(s)
	defb 0f1h, 0f9h
	defb 0f1h, 0f9h
simon_sat_7a47:
	defb 002h              ; 2 sprite(s)
	defb 0f1h, 001h
	defb 0f1h, 001h
simon_sat_7a4c:
	defb 002h              ; 2 sprite(s)
	defb 0e2h, 0f8h
	defb 0e2h, 0f8h
                          ; 0x7a51 not in pointer tables
	defb 002h              ; 2 sprite(s)
	defb 0e8h, 0f8h
	defb 0e8h, 0f8h
simon_sat_7a56:
	defb 002h              ; 2 sprite(s)
	defb 0e1h, 0f8h
	defb 0e1h, 0f8h
simon_sat_7a5b:
	defb 002h              ; 2 sprite(s)
	defb 0f1h, 000h
	defb 0f1h, 000h
simon_sat_7a60:
	defb 006h              ; 6 sprite(s)
	defb 0e2h, 0f0h
	defb 0e2h, 0f0h
	defb 0e2h, 0e0h
	defb 0e2h, 0e0h
	defb 0f2h, 0e0h
	defb 0f2h, 0e0h
simon_sat_7a6d:
	defb 004h              ; 4 sprite(s)
	defb 0e2h, 0f0h
	defb 0e2h, 0f0h
	defb 0e9h, 0e0h
	defb 0e9h, 0e0h
simon_sat_7a76:
	defb 006h              ; 6 sprite(s)
	defb 0e2h, 0f8h
	defb 0e2h, 0f8h
	defb 0e2h, 018h
	defb 0e2h, 018h
	defb 0e2h, 008h
	defb 0e2h, 008h
simon_sat_7a83:
	defb 002h              ; 2 sprite(s)
	defb 0e2h, 0f0h
	defb 0e2h, 0f0h
simon_sat_7a88:
	defb 004h              ; 4 sprite(s)
	defb 0e2h, 0f8h
	defb 0e2h, 0f8h
	defb 0e2h, 008h
	defb 0e2h, 008h
simon_sat_7a91:
	defb 002h              ; 2 sprite(s)
	defb 0e2h, 0f9h
	defb 0e2h, 0f9h
                          ; 0x7a96 not in pointer tables
	defb 002h              ; 2 sprite(s)
	defb 0e8h, 0f9h
	defb 0e8h, 0f9h
simon_sat_7a9b:
	defb 002h              ; 2 sprite(s)
	defb 0e1h, 0f9h
	defb 0e1h, 0f9h
simon_sat_7aa0:
	defb 002h              ; 2 sprite(s)
	defb 0f1h, 0f1h
	defb 0f1h, 0f1h
simon_sat_7aa5:
	defb 006h              ; 6 sprite(s)
	defb 0e2h, 001h
	defb 0e2h, 001h
	defb 0e2h, 011h
	defb 0e2h, 011h
	defb 0f2h, 011h
	defb 0f2h, 011h
simon_sat_7ab2:
	defb 004h              ; 4 sprite(s)
	defb 0e2h, 001h
	defb 0e2h, 001h
	defb 0e9h, 011h
	defb 0e9h, 011h
simon_sat_7abb:
	defb 006h              ; 6 sprite(s)
	defb 0e2h, 0f9h
	defb 0e2h, 0f9h
	defb 0e2h, 0d9h
	defb 0e2h, 0d9h
	defb 0e2h, 0e9h
	defb 0e2h, 0e9h
simon_sat_7ac8:
	defb 002h              ; 2 sprite(s)
	defb 0e2h, 001h
	defb 0e2h, 001h
simon_sat_7acd:
	defb 004h              ; 4 sprite(s)
	defb 0e2h, 0f9h
	defb 0e2h, 0f9h
	defb 0e2h, 0e9h
	defb 0e2h, 0e9h
; title_fill_strips (seg1 0x7AD6): HMMV-fill 16 strips (colour 2,
; NX=7 NY=9) via vdp_hmmv, stepping HL.Y by 0x10.  Caller sets HL dest
; (title uses 0x0516 and 0x0569).
title_fill_strips:
	ld e,010h              ; 16 strips
title_fill_loop:
	ld a,002h              ; fill colour
	ld d,000h
	ld bc,00709h           ; NX=7, NY=9
	push hl
	push de
	call vdp_hmmv            ; VDP HMMV
	pop de
	pop hl
	ld a,010h
	add a,h
	ld h,a                 ; next strip
	dec e
	jr nz,title_fill_loop
	ret
; title_set_color2 (seg1 0x7AEE): palette index 2 = (rb=0x11, g=0x01).
; Called when leaving the title screen.
title_set_color2:
	ld a,002h
	ld de,01101h
	jp palette_set              ; palette_set write one palette entry
; title_sat_init (seg1 0x7AF6): seed SAT shadow 0xD600 from
; title_sat_tmpl (11 two-byte Y,X pairs) and colour rows, then blit.
title_sat_init:
	ld de,0d600h
	ld hl,title_sat_tmpl
	ld b,00bh
	ld a,0fch
l7b00h:
	push bc
	ld b,002h
l7b03h:
	push bc
	ld bc,00002h
	ldir
	pop bc
	dec hl
	dec hl
	add a,004h
	ld (de),a
	inc de
	inc de
	djnz l7b03h
	inc hl
	inc hl
	pop bc
	djnz l7b00h
	ld hl,0d400h
	ld c,00bh
l7b1dh:
	ld b,010h
l7b1fh:
	ld (hl),008h
	inc hl
	djnz l7b1fh
	ld b,010h
l7b26h:
	ld (hl),002h
	inc hl
	djnz l7b26h
	dec c
	jr nz,l7b1dh
	ld a,002h
	ld de,00000h
	call palette_set
	jp pattern_shadow_blit
; tile_layout_draw (0x7B39): blit a title_layout stream.  HL -> stream, DE =
; start pos.  0xFF=end, 0xFE=next row (next byte added to D, E+=8), else tile id.
tile_layout_draw:
	push de
l7b3ah:
	ld a,(hl)
	inc hl
	ld c,a
	inc a
	jr z,l7b57h
	inc a
	jr nz,l7b4eh
	pop de
	ld a,(hl)
	inc hl
	add a,d
	ld d,a
	ld a,008h
	add a,e
	ld e,a
	jr tile_layout_draw
l7b4eh:
	ld a,c
	call tile_blit_skip0
	call blit_advance_x
	jr l7b3ah
l7b57h:
	pop de
	ret
; title_sat_tmpl (seg1 0x7B59): 11 (Y,X) pairs copied into the SAT shadow.
title_sat_tmpl:
	defb 027h,038h
	defb 027h,04ch
	defb 027h,060h
	defb 03fh,030h
	defb 03fh,040h
	defb 04fh,030h
	defb 04fh,040h
	defb 03fh,070h
	defb 03fh,080h
	defb 04fh,070h
	defb 04fh,080h
simon_land_test:               ; carry if (SimonX, SimonY+7) is solid (landing)
	ld a,(0c425h)
	add a,007h
	ld e,a
	ld a,(0c427h)
	ld d,a
	call map_cell_at
	jp tile_is_solid
simon_ceiling_test:            ; carry if (SimonX, SimonY-0x2C) is solid (no jump)
	ld a,(0c425h)
	sub 02ch
	ld e,a
	ld a,(0c427h)
	ld d,a
	call map_cell_at
	jp tile_is_solid
simon_floor_test:              ; grounded: map_solid_pair at feet; Y>=0xD0 = pit
	ld a,(0c425h)
	ld e,a
	cp 0d0h
	jr c,l7b99h
	or a
	ret
l7b99h:
	ld a,(0c427h)
	add a,005h
	ld d,a
; map_solid_pair (seg1 0x7B9F): carry if the tile at (D,E) or (D-10,E) is solid.
; Enemy floor test (feet + 10px toward the other side).
map_solid_pair:
	call map_cell_at
	call tile_is_solid
	ret c
	ld a,d
	sub 00ah
	ld d,a
map_solid_at:                  ; (0x7BAA) carry if tile at (D,E) is solid
	call map_cell_at
	jp tile_is_solid
; simon_wall_right (seg1 0x7BB0): probe +X from Simon Y/X (BC=0x0802, A=0).
simon_wall_right:
	ld a,(0c425h)
	ld e,a
	ld a,(0c427h)
	ld d,a
	ld bc,00802h
	xor a
	jr l7bc7h
actor_wall_right:              ; (0x7BBE) BC=0x1004 A=2; enemy-sized +X
	ld bc,01004h
	ld a,002h
	jr l7bc7h
; probe_wall_right (0x7BC5): A=1, BC from caller (often 0x0808). +X samples.
probe_wall_right:
	ld a,001h
l7bc7h:
	ld (0cff0h),a
	ld a,e
	sub c
	ld e,a
	ld a,d
	add a,b
	ld d,a
	call map_cell_at
	call tile_is_solid
	ret c
	ld a,e
	sub 008h
	ld e,a
	call map_cell_at
	call tile_is_solid
	ret c
	ld a,(0cff0h)
	cp 002h
	ret z
	ld a,e
	sub 008h
	ld e,a
	call map_cell_at
	call tile_is_solid
	ret c
	ld a,(0cff0h)
	and a
	jr nz,l7c02h
	ld a,(0c420h)
	cp 002h
	jr nz,l7c02h
	xor a
	ret
l7c02h:
	ld a,e
	sub 008h
	ld e,a
	call map_cell_at
	jp tile_is_solid
; simon_wall_left (seg1 0x7C0C): probe -X from Simon Y/X (BC=0x0802, A=0).
simon_wall_left:
	ld a,(0c425h)
	ld e,a
	ld a,(0c427h)
	ld d,a
	ld bc,00802h
	xor a
	jr l7c23h
actor_wall_left:               ; (0x7C1A) BC=0x1004 A=2; enemy-sized -X
	ld bc,01004h
	ld a,002h
	jr l7c23h
; probe_wall_left (0x7C21): A=1, BC from caller (often 0x0808). -X samples.
probe_wall_left:
	ld a,001h
l7c23h:
	ld (0cff0h),a
	ld a,e
	sub c
	ld e,a
	ld a,d
	sub b
	ld d,a
	call map_cell_at
	call tile_is_solid
	ret c
	ld a,e
	sub 008h
	ld e,a
	call map_cell_at
	call tile_is_solid
	ret c
	ld a,(0cff0h)
	cp 002h
	ret z
	ld a,e
	sub 008h
	ld e,a
	call map_cell_at
	call tile_is_solid
	ret c
	ld a,(0cff0h)
	and a
	jr nz,l7c5eh
	ld a,(0c420h)
	cp 002h
	jr nz,l7c5eh
	xor a
	ret
l7c5eh:
	ld a,e
	sub 008h
	ld e,a
	call map_cell_at
; --- tile_is_solid - classify a room tile id as blocking ---------------------
;  In:  A = tile id from map_cell_at (0 outside the 0xD100..0xD3FF window).
;  Out: carry set = solid (Simon's feet/head are blocked here).
;  A tile is solid iff (id-1) < threshold, where the threshold is per world row
;  (row_solid_thresh[0xD000]); the "event 6" cells (0xCE00==6) force threshold 6.
;  Stage 1 (row 1) threshold = 4, so only the floor/platform surface ids 01..04
;  block Simon - the thick wall/brick metatiles (ids 0x2c+) are visual only.
tile_is_solid:
	ld c,a
	ld a,(0ce00h)          ; current cell event code
	cp 006h
	jr z,l7c7ah            ; event-6 cells use a fixed threshold of 6
	ld a,(0d000h)          ; A = world row
	ld hl,row_solid_thresh
	call ADD_HL_A          ; HL -> threshold for this row
	ld a,c
	dec a
	cp (hl)                ; carry = (id-1) < threshold -> solid
	ret
l7c7ah:
	ld a,c
	dec a
	cp 006h                ; event-6: solid iff (id-1) < 6
	ret
;  row_solid_thresh: one byte per world row (0xD000); see tile_is_solid.
;  Event 6 (s18r9) ignores this table and uses threshold 6.
row_solid_thresh:
	defb 002h,004h,004h,004h,004h,004h,004h,004h,004h,004h
	defb 009h,009h,009h,004h,004h,004h,009h,009h,008h
; stair_probe_down_right (seg1 0x7C92): DOWN from ground. Tile 0x04; snap X +8.
; Event 6 skips (returns NZ). Z = boarded; C435/C421 get 2 / 0.
stair_probe_down_right:
	ld a,(0ce00h)
	cp 006h
	jr nz,l7c9bh
	and a
	ret
l7c9bh:
	ld bc,0c425h
	ld a,(bc)
	ld e,a
	inc c
	inc c
	ld a,(bc)
	ld d,a
	call map_cell_at
	cp 004h
	ret z
	ld a,(bc)
	add a,008h
	ld d,a
	call map_cell_at
	cp 004h
	ret nz
	ld a,(bc)
	add a,008h
	ld (bc),a
	xor a
	ret
; stair_probe_down_left (seg1 0x7CBA): DOWN from ground. Tile 0x03; snap X -8.
stair_probe_down_left:
	ld a,(0ce00h)
	cp 006h
	jr nz,l7cc3h
	and a
	ret
l7cc3h:
	ld bc,0c425h
	ld a,(bc)
	ld e,a
	inc c
	inc c
	ld a,(bc)
	ld d,a
	call map_cell_at
	cp 003h
	ret z
	ld a,(bc)
	sub 008h
	ld d,a
	call map_cell_at
	cp 003h
	ret nz
	ld a,(bc)
	sub 008h
	ld (bc),a
	xor a
	ret
; stair_probe_up_right (seg1 0x7CE2): UP from ground. Tile 0x0D; snap X +8.
; Event 6 skips. Z = boarded; C435/C421 get 1 / 0.
stair_probe_up_right:
	ld a,(0ce00h)
	cp 006h
	jr nz,l7cebh
	and a
	ret
l7cebh:
	ld bc,0c425h
	ld a,(bc)
	sub 008h
	ld e,a
	inc c
	inc c
	ld a,(bc)
	sub 008h
	ld d,a
	call map_cell_at
	cp 00dh
	ret z
	ld a,(bc)
	ld d,a
	call map_cell_at
	cp 00dh
	ret nz
	ld a,(bc)
	add a,008h
	ld (bc),a
	xor a
	ret
; stair_probe_up_left (seg1 0x7D0C): UP from ground. Tile 0x0C; snap X -8.
stair_probe_up_left:
	ld a,(0ce00h)
	cp 006h
	jr nz,l7d15h
	and a
	ret
l7d15h:
	ld bc,0c425h
	ld a,(bc)
	sub 008h
	ld e,a
	inc c
	inc c
	ld a,(bc)
	add a,008h
	ld d,a
	call map_cell_at
	cp 00ch
	ret z
	ld a,(bc)
	ld d,a
	call map_cell_at
	cp 00ch
	ret nz
	ld a,(bc)
	sub 008h
	ld (bc),a
	xor a
	ret
; --- map_cell_at - read the room tile id under a pixel position --------------
;  In:  E = Y pixel, D = X pixel.  Out: A = tile id at that cell (0 if outside).
;  The room tile-name map is a 32-wide x 24-tall grid of 8x8 cells at 0xD100
;  (rows 0-1 are the HUD; the drawer seg0 0x4f98 paints from 0xD140).  Cell:
;      cell = ((Y-0x10)>>3)*32 + (X>>3)   ->  addr = 0xD100 + cell
;  clamped to the 0xD100..0xD3FF window (returns 0 above/below it).  The map is
;  expanded from ROM metatiles by seg0 room_map_build; callers pair this with
;  tile_is_solid to test terrain.
map_cell_at:
	ld a,e
	sub 010h               ; drop the 0x10px top margin
	and 0f8h               ; align to 8px cell
	rrca
	rrca
	rrca                   ; A = (Y-0x10)/8 = tile row
	add a,a
	add a,a
	add a,a
	ld h,000h
	ld l,a
	add hl,hl
	add hl,hl
	ld a,d
	and 0f8h
	rrca
	rrca
	rrca
	call ADD_HL_A
	push de
	ld de,0d100h
	add hl,de
	ld a,(hl)
	ld e,a
	ld a,h
	cp 0d4h
	ld a,000h
	jr nc,l7d5eh
	ld a,e
l7d5eh:
	ld e,a
	ld a,h
	ld a,0d4h
	inc a
	cp h
	jr nc,l7d6ch
	cp 000h
	ld a,000h
	jr c,l7d6dh
l7d6ch:
	ld a,e
l7d6dh:
	pop de
	ret
; combat_tick (seg1 0x7D6F): per-frame hits.  Skipped while a room-exit is
; pending (0xC41B).  Whip (C416<2) runs the three whip-hit scans; knife/axe/
; cross (C416>=2) skip those and pad with combat_busy_wait instead, then the
; common projectile/vendor/hourglass/yellow-shield tail.
combat_tick:
	ld a,(0c41bh)
	and a
	ret nz
	call actors_vs_simon
	call shots_vs_simon
	call pickups_vs_simon
	call hurt_simon_spikes
	ld a,(0c416h)
	cp 002h
	jr nc,l7d92h           ; C416>=2: projectile weapons
	call whip_hit_actors         ; whip vs C800 actors (phase 3)
	call whip_hit_shots
	call whip_hit_candles
	jr l7d95h
l7d92h:
	call combat_busy_wait         ; pad: no whip scans this frame
l7d95h:
	call projectile_hit_actors
	call proj_hit_shots
	call proj_hit_candles
	call vendors_vs_attack
	call hourglass_vs_attack
	jp yellow_shield_tick
; combat_busy_wait (seg1 0x7DA7): 100x4 empty push/pop loop (~17k T).
; Knife/axe/cross skip the whip hit-tests; this burns time so that path is
; not much cheaper than a whip-hit tick.  No RAM side effects.  Same cost
; for all three weapons; not the throw windup (that is whip_tick phases 1-3
; before projectile_arm).
combat_busy_wait:
	ld b,064h
l7da9h:
	push bc
	ld b,004h
l7dach:
	push bc
	pop bc
	djnz l7dach
	pop bc
	djnz l7da9h
	ret
whip_hit_actors:
	ld a,(0c422h)
	cp 003h
	ret nz
	ld ix,0c800h
	ld b,007h
l7dc0h:
	ld a,(ix+000h)
	and a
	jr z,l7dd3h
	ld a,(ix+00eh)
	rra
	jr nc,l7dd3h
	push bc
	call actor_vs_whip
	pop bc
	jr c,l7ddbh
l7dd3h:
	ld de,00080h
	add ix,de
	djnz l7dc0h
	ret
l7ddbh:
	ld a,00ch
	call play_sound
	res 0,(ix+00eh)
	ld a,(ix+000h)
	sub 011h
	cp 007h
	jr c,l7e06h
l7dedh:
	ld a,(0c416h)
	and a
	jr z,l7df6h
	dec (ix+00dh)
l7df6h:
	dec (ix+00dh)
	jr z,l7e00h
	ld a,(ix+00dh)
	rla
	ret nc
l7e00h:
	call award_kill_score
	jp actor_kill
l7e06h:
	ld a,(ix+000h)
	cp 012h
	jr nz,l7e13h
	ld a,(0ce00h)
	and a
	jr z,l7dedh
l7e13h:
	call weapon_hit_damage
	ld a,(0c418h)
	and a
	jr z,boss_killed
	rla
	ret nc
boss_killed:
	ld a,014h
	ld (0c445h),a
	ld a,01ch
	call play_sound
	call award_kill_score
	ld a,001h
	ld (0ce15h),a
	jp actors_kill_all
; weapon_hit_damage (seg1 0x7E33) - Simon DISPENSES damage to the struck enemy in
; IX.  Picks a damage byte B from a per-weapon table indexed by (enemy type-0x11),
; then jp damage_enemy (0xC418 -= B).  Only the HP-bar enemies (types 0x11..0x17)
; take metered damage here; lesser enemies die outright on the hit test.
;   weapon 0xC416 = 0 (leather whip) or 2 (knife)  -> base table l7e60h
;   weapon = 1 (chain) / 3 (axe) / 4 (cross)        -> strong table l7e67h (1.5x)
;   Base   (types 0x11..0x17): 04 08 08 04 04 04 10
;   Strong (types 0x11..0x17): 06 0C 0C 06 06 06 18
; Special: vs type 0x17 with weapon >= 2 (knife/axe/cross) the damage is >>2 (/4).
weapon_hit_damage:
	ld hl,l7e60h
	ld a,(0c416h)          ; equipped weapon id
	and a
	jr z,l7e43h            ; leather whip -> base table
	cp 002h
	jr z,l7e43h            ; knife -> base table
	ld hl,l7e67h           ; chain/axe/cross -> strong table
l7e43h:
	ld a,(ix+000h)         ; struck enemy type
	ld c,a
	sub 011h               ; index = type - 0x11
	call ADD_HL_A
	ld b,(hl)              ; B = damage for this weapon vs this enemy
	ld a,c
	cp 017h
	jr nz,l7e5dh
	ld a,(0c416h)
	cp 002h
	jr c,l7e5dh
	srl b                  ; type 0x17 + weapon>=2: quarter the damage
	srl b
l7e5dh:
	jp damage_enemy        ; 0xC418 -= B
l7e60h:
	defb 004h,008h,008h,004h,004h,004h,010h
l7e67h:
	defb 006h,00ch,00ch,006h,006h,006h,018h
actors_vs_simon:
	ld a,(0c434h)
	and a
	jr nz,l7e84h
	ld a,(0c42dh)
	and a
	ret nz
	ld a,(0c43ah)
	and a
	ret nz
	ld a,(0c420h)
	cp 005h
	ret nc
l7e84h:
	ld ix,0c800h
	ld b,007h
l7e8ah:
	ld a,(ix+000h)
	and a
	jr z,l7ee3h
	ld a,(ix+00eh)
	rra
	rra
	jr nc,l7ee3h
	push bc
	call actor_vs_simon
	pop bc
	jr nc,l7ee3h
	ld a,(ix+000h)
	cp 024h
	jp z,09a45h
	cp 026h
	jp z,09a45h
	cp 022h                ; boss-clear orb (sprite 0x8F); not bonus id 22
	jr nz,l7eb7h
	ld a,001h
	ld (0ce11h),a          ; collected: drip-fill HP then advance stage
	jp actor_kill
l7eb7h:
	ld a,(0c434h)
	and a
	jr z,l7ec8h
	call award_kill_score
	call actor_kill
	ld a,00dh
	jp play_sound
l7ec8h:
	ld a,005h
	ld (0c420h),a
	xor a
	ld (0c423h),a
	ld (0c422h),a
	ld a,(ix+00ah)
	rla
	ld a,001h
	jr nc,l7eddh
	xor a
l7eddh:
	ld (0c43ch),a
	jp 08173h
l7ee3h:
	ld de,00080h
	add ix,de
	djnz l7e8ah
	ret
shots_vs_simon:
	ld a,(0c434h)
	and a
	jr nz,l7f01h
	ld a,(0c42dh)
	and a
	ret nz
	ld a,(0c43ah)
	and a
	ret nz
	ld a,(0c420h)
	cp 005h
	ret nc
l7f01h:
	ld ix,0d700h
	ld b,008h
l7f07h:
	push bc
	ld a,(ix+000h)
	and a
	jr z,l7f47h
	cp 00ch
	jr z,l7f47h
	call shot_vs_simon
	jr nc,l7f47h
	call actor_free
	pop bc
	ld a,(0c434h)
	and a
	jp nz,add_score_100
	ld a,005h
	ld (0c420h),a
	xor a
	ld (0c423h),a
	ld (0c422h),a
	ld a,(ix+00ah)
	rla
	ld a,001h
	jr nc,l7f37h
	xor a
l7f37h:
	ld (0c43ch),a
	ld a,(ix+000h)
	cp 009h
	ld b,001h
	jr nz,l7f44h
	inc b
l7f44h:
	jp 04632h
l7f47h:
	pop bc
	ld de,00080h
	add ix,de
	djnz l7f07h
	ret
whip_hit_shots:
	ld a,(0c422h)
	cp 003h
	ret nz
	ld ix,0d700h
	ld b,008h
l7f5ch:
	push bc
	ld a,(ix+000h)
	and a
	jr z,l7f77h
	cp 00ch
	jr z,l7f77h
	call shot_vs_whip
	jr nc,l7f77h
	ld a,00ch
	call play_sound
	call add_score_100
	call shot_death_flame
l7f77h:
	pop bc
	ld de,00080h
	add ix,de
	djnz l7f5ch
	ret
proj_hit_shots:
	ld a,(0c450h)
	ld b,a
	ld a,(0c460h)
	or b
	ret z
	ld ix,0d700h
	ld b,008h
l7f8fh:
	ld a,(ix+000h)
	and a
	jr z,l7fb6h
	cp 00ch
	jr z,l7fb6h
	push bc
	call shot_vs_proj
	pop bc
	jr nc,l7fb6h
	ld a,00ch
	call play_sound
	ld a,(iy+001h)
	cp 002h
	push iy
	pop hl
	call z,projectile_clear_hl
	call add_score_100
	jp shot_death_flame
l7fb6h:
	ld de,00080h
	add ix,de
	djnz l7f8fh
	ret
whip_hit_candles:
	ld a,(0c422h)
	cp 003h
	ret nz
	ld hl,0c470h
	ld b,008h
l7fc9h:
	ld a,(hl)
	and a
	jr z,l7fe2h
	push hl
	push bc
	call candle_vs_whip
	pop bc
	pop hl
	jr nc,l7fe2h
	inc l
	inc l
	inc l
	inc (hl)
	dec l
	dec l
	dec l
	ld a,00ch
	call play_sound
l7fe2h:
	ld a,010h
	add a,l
	ld l,a
	djnz l7fc9h
	ret
pickups_vs_simon:
	ld a,(0c422h)
	and a
	ret nz
	ld hl,0c500h
	ld b,008h
	push bc
	push hl
	ld a,(hl)
	rla
	jr nc,$+37
	push hl
	call pickup_vs_simon
	pop hl
	jr nc,$+30

; ===========================================================================
;  SEGMENT 2 - banked code, paged at 0x8000-0x9FFF (page 2a).
;  Continues this window at CPU 0x8000 (16K into this PHASE).
;  Regen: tools/disasm/regen-seg.sh 2 0x8000
; ===========================================================================

	inc l
	inc l
	inc l
	inc (hl)
	xor a
	ld (0c433h),a
	inc l
	ld a,(hl)
	cp 01bh
l800ch:
	jr nz,l801ch
	ld a,0e0h
	ld (0d618h),a
	ld (0d61ch),a
	ld (0d620h),a
	ld (0d624h),a
l801ch:
	pop hl
	pop bc
	ld a,010h
	add a,l
	ld l,a
	djnz $-47
	ret
projectile_hit_actors:         ; (0x8025) C450/C460 vs C800 if +0E bit0
	ld a,(0c450h)
	ld b,a
	ld a,(0c460h)
	or b
	ret z
	ld ix,0c800h
	ld b,007h
l8034h:
	ld a,(ix+000h)
	and a
	jr z,l8047h
	ld a,(ix+00eh)
	rra
	jr nc,l8047h
	push bc
	call actor_vs_proj
	pop bc
	jr c,l8053h
l8047h:
	ld de,00080h
	add ix,de
	djnz l8034h
	ret
l804fh:
	defb 001h,004h,002h,002h  ; fodder dmg: knife/axe/cross/holy (iy+1)-2
l8053h:
	ld a,00ch
	call play_sound
	ld a,(ix+000h)
	sub 011h
	cp 007h
	jr c,l808fh
l8061h:
	ld a,(iy+001h)
	sub 002h
	ld hl,l804fh
	call ADD_HL_A
	ld b,(hl)
	ld a,(ix+00dh)
l8070h:
	sub b
	ld (ix+00dh),a
	jr z,l8079h
	jp p,l807fh
l8079h:
	call award_kill_score
	call actor_kill
l807fh:
	ld a,(iy+001h)
	cp 002h
	push iy
	pop hl
	jp z,projectile_clear_hl  ; knife (type 2): despawn on hit
	res 0,(ix+00eh)        ; axe/cross/holy: keep projectile, drop hittable
	ret
l808fh:
	ld a,(ix+000h)
	cp 012h
	jr nz,l809ch
	ld a,(0ce00h)
	and a
	jr z,l8061h
l809ch:
	call weapon_hit_damage
	ld a,(0c418h)
	and a
	jr z,l80a8h
	rla
	jr nc,l807fh
l80a8h:
	call boss_killed
	jr l807fh
proj_hit_candles:              ; (0x80AD) C450/C460 vs C470 candles/blocks
	ld ix,0c470h
	ld b,008h
l80b3h:
	ld a,(ix+000h)
	and a
	jr z,l80dbh
	push bc
	call candle_vs_proj
	pop bc
	jr nc,l80dbh
	inc (ix+003h)
	ld a,(ix+004h)
	ld (0c433h),a
	ld a,(iy+001h)
	dec a
	dec a
	jr nz,l80d6h
	push iy
	pop hl
	call z,projectile_clear_hl
l80d6h:
	ld a,00ch
	jp play_sound
l80dbh:
	ld de,00010h
	add ix,de
	djnz l80b3h
	ret
vendors_vs_attack:             ; (0x80E3) both C5B5/C5C5 slots vs whip/proj
	ld hl,0c5b5h
	call vendor_vs_attack
	ld hl,0c5c5h
vendor_vs_attack:              ; (0x80EC) one vendor slot HL vs whip then proj
	ld a,(hl)
	rla
	ret nc
	ld a,(0c416h)
	cp 002h
	jr nc,l8104h
	ld a,(0c422h)
	cp 003h
	jr nz,l8104h
	push hl
	call obj_vs_whip_lo
	pop hl
	jr c,l8119h
l8104h:
	push hl
	call obj_vs_proj_lo
	pop hl
	ret nc
	ld a,(iy+001h)
	cp 002h
	jr nz,l8119h
	push hl
	push iy
	pop hl
	call projectile_clear_hl
	pop hl
l8119h:
	inc l
	inc l
	inc l
	inc (hl)
	ld a,00ch
	jp play_sound
hourglass_vs_attack:           ; (0x8122) C500 hourglass/tipped vs whip/proj
	ld hl,0c500h
	ld b,008h
l8127h:
	push bc
	push hl
	ld a,(hl)
	rla
	jr nc,l816ah
	push hl
	ld a,004h
	add a,l
	ld l,a
	ld a,(hl)
	pop hl
	cp 00ah
	jr z,l813ch
	cp 00bh
	jr nz,l816ah
l813ch:
	ld a,(0c416h)
	cp 002h
	jr nc,l8151h
	ld a,(0c422h)
	cp 003h
	jr nz,l8151h
	push hl
	call obj_vs_whip_hi
	pop hl
	jr c,l8160h
l8151h:
	push hl
	call obj_vs_proj_hi
	pop hl
	jr nc,l816ah
	push hl
	push iy
	pop hl
	call projectile_clear_hl
	pop hl
l8160h:
	inc l
	inc l
	inc l
	ld (hl),002h
	ld a,00ch
	call play_sound
l816ah:
	pop hl
	pop bc
	ld a,010h
	add a,l
	ld l,a
	djnz l8127h
	ret
; --- hurt_simon_contact (seg2 0x8173) - Simon TAKES contact damage from actor IX -
; Base damage B = the ODD byte of this actor type's l81d5h entry (the even byte is
; the kill score - see l81d5h below).  Then:
;   * Red shield (0xC701 bit 4, bonus id 3): if Simon is facing the hit, take B
;     as-is (not doubled) and spend a charge (0xC441--; at 0, res bit4 +
;     hud_bonus_refresh drops the HUD).  A backstab still takes the doubled hit.
;   * Otherwise (no red shield / not facing): B is DOUBLED, so unshielded
;     contact = 2 * (l81d5h odd byte).  Runtime-confirmed: zombie(t01) odd 1 -> 2,
;     dog(t05) odd 3 -> 6 (0x1E->0x18).  Then jp damage_health (0xC415 -= B).
hurt_simon_contact:
	ld a,(ix+000h)
	dec a
	add a,a
	ld hl,l81d5h
	call ADD_HL_A
	inc hl                 ; -> odd byte = base contact damage for this type
	ld b,(hl)
	ld a,(0c701h)
	bit 4,a                ; red shield (id 3)?
	jr z,l819ah            ; no shield -> full (doubled) damage
	ld a,(0c427h)
	sub (ix+005h)
	ld a,(0c42ch)
	jr nc,l8197h
	and a
	jr z,l819fh
	jr l819ah
l8197h:
	and a
	jr nz,l819fh
l819ah:
	ld a,b                 ; unshielded: double the base damage
	add a,a
	ld b,a
	jr l81afh
l819fh:
	ld hl,0c441h           ; shielded hit: spend a shield charge
	dec (hl)
	jr nz,l81afh
	ld hl,0c701h
	res 4,(hl)             ; charges gone -> drop the red shield
	push bc
	call hud_bonus_refresh
	pop bc
l81afh:
	jp damage_health       ; 0xC415 -= B
; award_kill_score (seg2 0x81B2): give points for killing the actor in IX.
; Looks up the per-type hundreds value D from table l81d5h[(type-1)] (E=0 low pair),
; then picks the high pair C by type (0x11 -> 3, 0x17 -> 5, else 0) and calls
; add_score with C:D:E.
award_kill_score:
	ld a,(ix+000h)
	ld b,a
	dec a
	add a,a
	ld hl,l81d5h
	call ADD_HL_A
	ld e,000h
	ld d,(hl)               ; D = hundreds pair for this enemy type
	ld a,b
	cp 011h
	ld c,003h
	jp z,add_score
	ld c,005h
	cp 017h
	jp z,add_score
	ld c,000h
	jp add_score
; l81d5h - per-actor-type table, 2 bytes/entry, indexed by (type - 1):
;   even byte = kill SCORE / 100 in BCD (read by award_kill_score above)
;   odd  byte = base CONTACT damage to Simon (read by hurt_simon_contact; the
;               real damage is 2x this when unshielded)
;         type: 01   02   03   04   05   06   07   08   09   0a   0b   0c   0d
;   score/100 :  1    2    2    1    1    2    2    2    2    3    2    1    2
;   contact dmg:  x2 of odd byte -> zombie(t01)=2, dog(t05)=6 (confirmed in play)
;   high types 0x0e=1000pts, 0x11 +30000, 0x12-14 2000, 0x17 +50000 [bosses].
; Confirmed: t01 zombie 100/2; t02/t03 merman 200/4; t04 hanging bat 100/2;
; t05 dog 100/6; t07 flying skull 200/2; t08 ghost head 200/4; t0F roc 400/4.
; Hearts/keys are pickups (collect_bonus), not kills, so they award 0 here.
l81d5h:
	defb 001h,001h, 002h,002h, 002h,002h, 001h,001h  ; t01-04
	defb 001h,003h, 002h,002h, 002h,001h, 002h,002h  ; t05-08
	defb 002h,001h, 003h,001h, 002h,001h, 001h,001h  ; t09-0c
	defb 002h,001h, 010h,003h, 004h,002h, 003h,003h  ; t0d-10
	defb 000h,003h, 020h,002h, 020h,002h, 020h,002h  ; t11-14
	defb 030h,003h, 070h,003h, 000h,000h, 002h,001h  ; t15-18
	defb 001h,002h, 001h,002h, 001h,002h, 001h,002h  ; t19-1c blob
	defb 000h,000h, 000h,000h, 001h,001h, 000h,000h  ; t1d-20
	defb 002h,001h, 000h,000h, 002h,001h, 000h,000h  ; t21-24
	defb 000h,000h, 000h,000h, 000h,000h, 000h,000h
	defb 000h,000h, 000h,000h, 000h,000h, 001h,001h
	defb 000h,000h, 000h,000h
add_score_100:                 ; (0x8231) +100 for destroying a shot
	ld de,00100h
	jp add_score_c0
pickup_vs_simon:               ; (0x8237) C500 slot HL vs Simon (Y+10, X+8, 10x8)
	inc l
	ld a,(hl)
	add a,010h
	ld e,a
	inc l
	ld a,(hl)
	add a,008h
	ld d,a
	ld hl,01008h
	jp overlap_simon
proj_overlap_simon:            ; (0x8247) projectile DE vs Simon box (catch)
	ld d,(ix+005h)
	ld e,(ix+004h)
	ld hl,01008h
	jp overlap_simon
; Hit-class overlap: look up a box size by actor/shot type, then test vs
; Simon / whip / projectile / yellow shield.  Shots use 3 classes (0..2);
; C800 uses 7 (table 1..7, then dec a).  Carry = overlap.
shot_vs_simon:                 ; (0x8253) shot vs Simon (hurt)
	call hit_class_shot
	call DISPATCH_A
	defw shot_box_0_simon, shot_box_1_simon, shot_box_2_simon
shot_vs_proj:                  ; (0x825F) C450/C460 vs shot
	call hit_class_shot
	call DISPATCH_A
	defw shot_box_0_proj, shot_box_1_proj, shot_box_2_proj
shot_vs_shield:                ; (0x826B) yellow shield vs shot
	call hit_class_shot
	call DISPATCH_A
	defw shot_box_0_shield, shot_box_1_shield, shot_box_2_shield
shot_vs_whip:                  ; (0x8277) whip vs shot
	call hit_class_shot
	call DISPATCH_A
	defw shot_box_0_whip, shot_box_1_whip, shot_box_2_whip
actor_vs_whip:                 ; (0x8283) whip vs C800
	call hit_class_c800
	call DISPATCH_A
	defw box_1_whip, box_2_whip, box_3_whip, box_4_whip
	defw box_5_whip, box_6_whip, box_7_whip
actor_vs_simon:                ; (0x8297) C800 vs Simon (contact)
	call hit_class_c800
	call DISPATCH_A
	defw box_1_simon, box_2_simon, box_3_simon, box_4_simon
	defw box_5_simon, box_6_simon, box_7_simon
actor_vs_proj:                 ; (0x82AB) C450/C460 vs C800
	call hit_class_c800
	call DISPATCH_A
	defw box_1_proj, box_2_proj, box_3_proj, box_4_proj
	defw box_5_proj, box_6_proj, box_7_proj
hit_class_c800:                ; (0x82BF) A = class 0..6; B=X C=Y
	ld a,(ix+000h)
	dec a
	ld hl,hit_class_c800_tbl
	call ADD_HL_A
	ld a,(hl)
	dec a
	ld b,(ix+005h)
	ld c,(ix+003h)
	ret
hit_class_c800_tbl:            ; (0x82D2) type-1 -> class 1..7 (then dec a)
	defb 001h,001h,001h,002h,003h,001h,002h,002h  ; 1-8
	defb 001h,001h,001h,002h,002h,002h,004h,004h  ; 9-16
	defb 005h,004h,004h,006h,006h,007h,002h,002h  ; 17-24
	defb 002h,002h,002h,002h,001h,001h,002h,001h  ; 25-32
	defb 001h,002h,002h,002h,001h,002h,001h,001h  ; 33-40
	defb 001h,001h,001h,002h,001h,001h,001h,001h  ; 41-48
hit_class_shot:                ; (0x8302) A = class 0..2; B=X C=Y
	ld a,(ix+000h)
	dec a
	ld hl,hit_class_shot_tbl
	call ADD_HL_A
	ld a,(hl)
	ld b,(ix+005h)
	ld c,(ix+003h)
	ret
hit_class_shot_tbl:            ; (0x8314) shot type-1 -> class 0..2
	defb 000h,000h,000h,002h,000h,001h,001h,002h,002h,000h,002h
shot_box_0_simon:                  ; 0x831F  3x6 vs Simon
	ld hl,00603h
	ld d,b
	ld e,c
	jp overlap_simon
shot_box_0_whip:                   ; 0x8327
	ld hl,00603h
	ld d,b
	ld e,c
	jp overlap_whip
shot_box_0_proj:                   ; 0x832F
	ld hl,00603h
	ld d,b
	ld e,c
	jp overlap_projectile
shot_box_0_shield:                 ; 0x8337
	ld hl,00603h
	ld d,b
	ld e,c
	jp overlap_shield
shot_box_1_simon:                  ; 0x833F  6x6
	ld hl,00606h
	ld d,b
	ld e,c
	jp overlap_simon
shot_box_1_whip:
	ld hl,00606h
	ld d,b
	ld e,c
	jp overlap_whip
shot_box_1_proj:
	ld hl,00606h
	ld d,b
	ld e,c
	jp overlap_projectile
shot_box_1_shield:
	ld hl,00606h
	ld d,b
	ld e,c
	jp overlap_shield
shot_box_2_simon:                  ; 0x835F  6x12 (bone / axe / sickle)
	ld hl,00c06h
	ld d,b
	ld e,c
	jp overlap_simon
shot_box_2_whip:
	ld hl,00c06h
	ld d,b
	ld e,c
	jp overlap_whip
shot_box_2_proj:
	ld hl,00c06h
	ld d,b
	ld e,c
	jp overlap_projectile
shot_box_2_shield:
	ld hl,00c06h
	ld d,b
	ld e,c
	jp overlap_shield
; C800 class 1 fodder (zombie, merman, pikeman, skels, pile): 5x24
box_1_simon:                   ; 0x837F
	ld hl,01805h
	ld d,b
	ld e,c
	jp overlap_simon
box_1_whip:
	ld hl,01805h
	ld d,b
	ld e,c
	jp overlap_whip
box_1_proj:
	ld hl,01805h
	ld d,b
	ld e,c
	jp overlap_projectile
; class 2 flyers (bat, skull, ghost, raven, hunch, dragon, blob, igor): 8x16
box_2_simon:                   ; 0x8397
	ld hl,01008h
	ld d,b
	ld e,c
	jp overlap_simon
box_2_whip:                    ; 0x839F -> shared 10x8 whip tail
	ld d,b
	ld e,c
	jr box_10x08_whip
obj_vs_whip_hi:                ; (0x83A3) HL slot Y+10, X+8 vs whip
	call obj_xy_10_8
	jr box_10x08_whip
obj_vs_whip_lo:                ; (0x83A8) HL slot Y+20, X+10 vs whip
	call obj_xy_20_10
box_10x08_whip:                ; 0x83AB
	ld hl,01008h
	jp overlap_whip
box_2_proj:                    ; 0x83B1
	ld d,b
	ld e,c
	jr box_10x08_proj
obj_vs_proj_hi:                ; (0x83B5)
	call obj_xy_10_8
	jr box_10x08_proj
obj_vs_proj_lo:                ; (0x83BA)
	call obj_xy_20_10
box_10x08_proj:                ; 0x83BD
	ld hl,01008h
	jp overlap_projectile
obj_xy_20_10:                  ; (0x83C3) E=Y+0x20, D=X+0x10 from HL
	inc l
	ld a,(hl)
	add a,020h
	ld e,a
	inc l
	ld a,(hl)
	add a,010h
	ld d,a
	ret
obj_xy_10_8:                   ; (0x83CE) E=Y+0x10, D=X+0x08 from HL
	inc l
	ld a,(hl)
	add a,010h
	ld e,a
	inc l
	ld a,(hl)
	add a,008h
	ld d,a
	ret
; class 3 dog: 12x10
box_3_simon:                   ; 0x83D9
	ld hl,00a0ch
	ld d,b
	ld e,c
	jp overlap_simon
box_3_whip:
	ld hl,00a0ch
	ld d,b
	ld e,c
	jp overlap_whip
box_3_proj:
	ld hl,00a0ch
	ld d,b
	ld e,c
	jp overlap_projectile
; class 4 roc / axe / giant bat / medusa: 12x24
box_4_simon:                   ; 0x83F1
	ld hl,0180ch
	ld d,b
	ld e,c
	jp overlap_simon
box_4_whip:
	ld hl,0180ch
	ld d,b
	ld e,c
	jp overlap_whip
box_4_proj:
	ld hl,0180ch
	ld d,b
	ld e,c
	jp overlap_projectile
; class 5 Dracula: 16x48 vs Simon; whip/proj use 5x24 at Y-0x20 (head)
box_5_simon:                   ; 0x8409
	ld hl,03010h
	ld d,b
	ld e,c
	jp overlap_simon
box_5_whip:                    ; 0x8411
	ld hl,01805h
	ld d,b
	ld a,c
	sub 020h
	ld e,a
	jp overlap_whip
box_5_proj:                    ; 0x841C
	ld hl,01805h
	ld d,b
	ld a,c
	sub 020h
	ld e,a
	jp overlap_projectile
; class 6 mummy / Frankenstein: 5x40
box_6_simon:                   ; 0x8427
	ld hl,02805h
	ld d,b
	ld e,c
	jp overlap_simon
box_6_whip:
	ld hl,02805h
	ld d,b
	ld e,c
	jp overlap_whip
box_6_proj:
	ld hl,02805h
	ld d,b
	ld e,c
	jp overlap_projectile
; class 7 grim reaper: 8x48
box_7_simon:                   ; 0x843F
	ld hl,03008h
	ld d,b
	ld e,c
	jp overlap_simon
box_7_whip:
	ld hl,03008h
	ld d,b
	ld e,c
	jp overlap_whip
box_7_proj:
	ld hl,03008h
	ld d,b
	ld e,c
	jp overlap_projectile
candle_vs_whip:                ; (0x8457) C470 slot HL vs whip
	inc hl
	ld a,(hl)
	add a,010h
	ld e,a
	inc hl
	ld a,(hl)
	add a,008h
	ld d,a
	ld hl,01008h
	jp overlap_whip
candle_vs_proj:
	ld a,(ix+004h)
	cp 002h
	ld hl,01008h
	jr c,l8474h
	ld hl,02010h
l8474h:
	ld a,(ix+001h)
	add a,h
	ld e,a
	ld a,(ix+002h)
	add a,l
	ld d,a
	jp overlap_projectile
overlap_simon:                 ; (0x8481) DE=actor XY, HL=box; vs Simon C427/C425
	ld a,005h
	add a,l
	ld l,a
	ld a,(0c427h)
	sub d
	jr nc,l848dh
	neg
l848dh:
	cp l
	ret nc
	ld c,h
	ld a,(0c420h)
	ld b,a
	dec a
	cp 002h
	ld a,012h
	jr c,l849dh
	ld a,01ah
l849dh:
	add a,h
	ld h,a
	ld a,b
	dec a
	ld a,(0c425h)
	jr nz,l84a8h
	sub 008h
l84a8h:
	sub 002h
	sub e
	add a,c
	cp h
	ret
overlap_whip:                  ; (0x84AE) DE=actor XY, HL=box; vs whip (facing + C416)
	ld a,(0c416h)
	dec a
	ld a,00ch
	jr nz,l84b8h
	ld a,010h
l84b8h:
	add a,l
	ld l,a
	call whip_reach_x
	jr nc,l84c1h
	xor a
	ret
l84c1h:
	sub d
	jr nc,l84c6h
	neg
l84c6h:
	cp l
	ret nc
	ld a,(0c420h)
	cp 002h
	ld b,012h
	jr nz,l84d3h
	ld b,00ah
l84d3h:
	ld c,h
	ld a,004h
	add a,h
	ld h,a
	ld a,(0c425h)
	sub b
	sub e
	add a,c
	cp h
	ret
whip_reach_x:
	ld a,(0c416h)
	dec a
	ld b,014h
	jr nz,l84eah
	ld b,018h
l84eah:
	ld a,(0c42ch)
	and a
	ld a,(0c427h)
	jr z,l84f5h
	sub b
	ret
l84f5h:
	add a,b
	ret
overlap_projectile:            ; (0x84F7) DE=actor XY, HL=box; vs C450 then C460
	ld iy,0c450h
	call proj_slot_overlap
	ret c
	ld iy,0c460h
	call proj_slot_overlap
	ret
proj_slot_overlap:
	ld a,006h
	add a,l
	ld l,a
	ld a,(iy+005h)
	sub d
	jr nc,l8513h
	neg
l8513h:
	cp l
	ret nc
	ld a,(iy+001h)
	cp 002h
	ld b,00ch
	jr nz,l8520h
	ld b,006h
l8520h:
	ld c,h
	ld a,b
	add a,h
	ld h,a
	ld a,(iy+004h)
	sub e
	add a,c
	cp h
	ret
; --- platform_stand_test (0x852B) - recompute 0xC439 ------------------------
;  Called from simon_action_tick (seg1 0x6B47) every frame, before the action
;  state dispatch, so 0xC439 is fresh for simon_grounded / simon_fall.
;  Result is the slot id (1 or 2) of the moving platform Simon is standing on,
;  or 0.  Rising through a platform is allowed: while falling (0xC420 == 4)
;  with jump phase 0xC428 < 3 the test is skipped entirely.
platform_stand_test:
	ld a,(0c420h)
	cp 004h
	jr nz,l8538h
	ld a,(0c428h)
	cp 003h
	ret c                  ; still rising -> don't land on anything
l8538h:
	ld hl,0c598h
	ld de,00000h           ; D = slot 2 result, E = slot 1 result
	ld b,002h
l8540h:
	ld a,(hl)
	and a
	push hl
	push bc
	call nz,platform_overlap       ; slot in use -> test it
	pop bc
	pop hl
	ld a,007h
	call ADD_HL_A          ; next slot (stride 7)
	djnz l8540h
	ld a,d
	or e
	ld (0c439h),a          ; 0 = airborne/ground, else the slot id
	ret
; platform_overlap (0x8556): HL = slot.  Carry Simon only when he is within 8px
; above the platform row and his X (+-7) lands in the 32px deck.  Writes the
; slot id into E for slot 1 (odd) or D for slot 2, and clears it on a miss.
platform_overlap:
	ld c,(hl)              ; C = +0 slot id
	inc hl
	ld a,(0c425h)          ; Simon Y
	sub (hl)               ; - platform Y (+1)
	cp 008h
	jr nc,l8575h           ; Y miss: not resting on the deck
	ld b,007h
	inc hl
	ld a,(0c427h)          ; Simon X
	sub b
	sub (hl)               ; - platform X (+2), left foot
	cp 020h
	jr c,l857fh            ; within the 32px deck
	ld a,(0c427h)
	add a,b
	sub (hl)               ; right foot
	cp 020h
	jr c,l857fh
l8575h:
	ld a,c
	rra
	jr c,l857ch
	ld d,000h
	ret
l857ch:
	ld e,000h
	ret
l857fh:
	ld a,c
	rra
	jr c,l8585h
	ld d,c
	ret
l8585h:
	ld e,c
	ret
; door_proximity (0x8587): carry set if Simon overlaps the white-key door.
; Entry: B = Simon Y (0xC425), C = Simon X (0xC427).  0xC5AD is door Y,
; 0xC5AE is door X (from door_tbl, NOT a 0x1F object).  Y window is 0x38
; after C5AD-8; X window is 8.  Facing (0xC42C) nudges C by +/-8 first.
door_proximity:
	ld a,(0c42ch)
	and a
	jr z,l8593h
	ld a,c
	sub 008h
	ld c,a
	jr l8597h
l8593h:
	ld a,c
	add a,008h
	ld c,a
l8597h:
	dec b
	dec b
	ld a,(0c5adh)          ; door Y
	sub 008h
	ld d,a
	ld a,b
	sub d
	cp 038h
	ret nc                 ; Y miss
	ld a,(0c5aeh)          ; door X
	ld d,a
	ld a,c
	sub d
	cp 008h
	ret                    ; carry = X overlap
; --- hurt_simon_spikes (seg2 0x85AD) - Simon TAKES damage from a spike bar ------
; Scans the 3 spike-bar slots at 0xC580; if Simon overlaps one (spike_bar_overlap
; returns carry) it puts Simon into the hurt/knockback state (0xC420=5) and deals
; fixed damage: B = 8, or B = 16 when bit 0 of the slot byte is set (descending).
; Nothing else ever seeds C580 (only spike_bars_seed, and only on stage 6 room 1);
; enemy shots live in the 8 D700 slots and hit Simon by a different path.
; Skipped while Simon is already dying (0xC420==6) or during the 0xC42D /
; 0xC43A i-frame / freeze timers.
hurt_simon_spikes:
	ld a,(0c420h)
	cp 006h
	ret z                  ; already dying -> ignore
	ld a,(0c42dh)
	and a
	ret nz
	ld a,(0c43ah)
	and a
	ret nz
	ld hl,0c580h           ; 3 spike-bar slots
	ld b,003h
l85c2h:
	ld a,(hl)
	and a
	jr z,l85ddh
	push hl
	call spike_bar_overlap ; overlap test vs Simon
	pop hl
	jr nc,l85ddh           ; no hit -> next slot
	ld a,005h
	ld (0c420h),a          ; hurt/knockback state
	ld a,(hl)
	rra
	ld b,008h              ; retracting = 8
	jr nc,l85dah
	ld b,010h              ; descending (bit 0 set) = 16
l85dah:
	jp damage_health       ; 0xC415 -= B
l85ddh:
	ld a,008h
	call ADD_HL_A
	djnz l85c2h
	ret
; spike_bar_overlap (0x85E5) - carry if Simon's feet overlap this bar's 32x8 box.
; HL -> slot; uses +1 Y and +2 X.  Y test is Simon Y - 0x1C vs the bar row.
spike_bar_overlap:
	inc hl
	ld a,(hl)
	ld d,a
	ld a,(0c425h)
	sub 01ch
	sub d
	cp 008h
	ret nc
	inc hl
	ld a,(hl)
	ld d,a
	ld a,(0c427h)
	sub d
	cp 020h
	ret
; spot_proximity (seg2 0x85FB): carry if Simon overlaps the armed spot
; (C5B1!=0, C5B2=Y, C5B3=X).  Box is 0x10 tall (vs Y-4) and 0x10 wide.
; simon_crouch: on-pad + UP -> portal wind-up (state 7).
spot_proximity:
	ld hl,0c5b1h
	ld a,(hl)              ; C5B1 armed?
	and a
	ret z                  ; NC: no pad in this room
	inc hl
	ld a,(hl)              ; C5B2 pad Y
	ld d,a
	ld a,(0c425h)          ; Simon Y
	sub 004h
	sub d
	cp 010h
	ret nc                 ; Y miss
	inc hl
	ld a,(hl)              ; C5B3 pad X
	ld d,a
	ld a,(0c427h)          ; Simon X
	sub d
	cp 010h
	ret                    ; CY if X in 0x10 box
; yellow_shield_tick (seg2 0x8617): if C701 bit5 (bonus id 4), overlap-test the
; shot slots and absorb hits: free the shot, spend a C441 charge,
; drop the yellow shield at 0.
yellow_shield_tick:
	ld a,(0c701h)
	and 020h               ; yellow shield (id 4)
	ret z
	ld ix,0d700h
	ld b,008h
l8623h:
	push bc
	ld a,(ix+000h)
	and a
	jr z,l8649h
	cp 00ch
	jr z,l8649h
	call shot_vs_shield
	jr nc,l8649h
	call shot_death_flame
	ld a,00bh
	call play_sound
	ld hl,0c441h
	dec (hl)
	jr nz,l8649h
	ld hl,0c701h
	res 5,(hl)             ; charges gone -> drop yellow shield
	call hud_bonus_refresh
l8649h:
	pop bc
	ld de,00080h
	add ix,de
	djnz l8623h
	ret
overlap_shield:                ; (0x8652) yellow shield: Simon X ±8 by facing
	ld a,004h
	add a,l
	ld l,a
	ld a,(0c42ch)
	and a
	ld a,008h
	jr z,l8660h
	neg
l8660h:
	ld b,a
	ld a,(0c427h)
	add a,b
	sub d
	jr nc,l866ah
	neg
l866ah:
	cp l
	ret nc
	ld c,h
	ld a,020h
	add a,h
	ld h,a
	ld a,(0c425h)
	sub e
	add a,c
	cp h
	ret
; ---------------------------------------------------------------------------
;  brazier_tick_all (seg2 0x8678) - per-frame update of the destructible light
;  scenery (braziers in the courtyard / candles in the castle).  Walks the 8
;  object slots at 0xC470 (stride 0x10) and ticks each active one.  Called each
;  frame from seg0 0x8656-area and seg1 0x628-area.
; ---------------------------------------------------------------------------
brazier_tick_all:
	ld bc,00800h            ; B = 8 slots, C = 0 (slot index)
	ld hl,0c470h            ; HL -> scenery object block
l867eh:
	push bc
	push hl
	push hl
	pop ix                  ; IX -> current object
	ld a,(hl)               ; A = +0x00 state
	ld b,a                  ; keep old state in B
	or a
	call nz,brazier_tick    ; tick it if active (state != 0)
	pop hl
	pop bc
	inc c                   ; next slot index
	ld a,l
	add a,010h              ; HL += 0x10 (next slot)
	ld l,a
	djnz l867eh
	ret

; ---------------------------------------------------------------------------
;  brazier_tick (seg2 0x8693) - update one C470 slot (candle or breakable
;  block).  First frame (old +00==1) saves the nametable under the object
;  (`block_save_under`) then either draws the flame or stamps bricks
;  (`block_stamp`: kind 2 = 2x2, kind 3 = 4x4).  Hit (+0x03 != 0) ->
;  brazier_destroyed.
; ---------------------------------------------------------------------------
brazier_tick:
	ld (hl),002h            ; +0x00 state = 2 (present/lit)
	inc l
	ld e,(hl)               ; E = +0x01  \ object word
	inc l
	ld d,(hl)               ; D = +0x02  / (screen pos)
	inc l
	ld a,(hl)               ; A = +0x03 hit flag
	or a
	jp nz,brazier_destroyed ; hit -> destroy + drop
	inc l
	ld a,(hl)               ; A = +0x04 kind
	ex af,af'
	inc l
	inc l
	inc (hl)                ; +0x06 anim
	ld a,b
	cp 001h
	jr nz,l86bah            ; already stamped
	ex af,af'
	push af
	push de
	call block_save_under  ; copy nametable under this slot to E480/E4A0
	pop de
	pop af
	cp 002h
	jp c,l86c2h             ; kind 0/1: candle flame
	jp block_stamp          ; kind 2/3: overlay brick tiles
l86bah:
	ld a,(hl)
	and 003h
	ret nz
	ex af,af'
	cp 002h
	ret nc                  ; blocks: stamp once
l86c2h:
	or a
	ld a,000h
	jr z,l86c9h
	ld a,002h
l86c9h:
	bit 3,(hl)
	jr z,l86ceh
	inc a
l86ceh:
	jp l8991h
; block_stamp (seg2 0x86D1) - blit brick tile ids to VRAM and into D100.
; kind 2 = 16x16 (2x2); kind 3 = 32x32 (4x4, skip the leading 2x2 bytes).
; Courtyard uses block_tiles_court; castle uses block_tiles_castle.
block_stamp:
	ld b,a
	ld a,(0d002h)
	or a
	ld hl,block_tiles_court
	jr z,l86deh
	ld hl,block_tiles_castle
l86deh:
	ld a,b
	ld bc,01002h
	cp 002h
	jr z,l86eeh
	ld bc,02004h
	ld a,004h
	call ADD_HL_A
l86eeh:
	push bc
	push de
	ld b,c
	push bc
	push hl
	push de
	call tiles_blit_vram
	pop de
	call map_cell_at            ; map_cell_at
	pop de
	pop bc
	ex de,hl
	call tiles_to_map
	pop hl
	pop de
	ld e,d
	ld a,(0c702h)
	rra
	ret nc
vdp_box_white:
	ld c,00eh              ; white (MSX colour 14) rectangle outline
	jp vdp_box
candle_outlines_if:
	ld a,(0c702h)
	rra
	ret nc
candle_outlines:
	ld bc,00800h
	ld hl,0c470h
l8719h:
	push bc
	push hl
	ld a,(hl)
	cp 002h
	jr nz,l8737h
	inc l
	ld e,(hl)
	inc l
	ld d,(hl)
	inc l
	inc l
	ld a,(hl)
	cp 002h
	jr c,l8737h
	ex de,hl
	ld de,01010h
	jr z,l8734h
	ld de,02020h
l8734h:
	call vdp_box_white
l8737h:
	pop hl
	pop bc
	inc c
	ld a,l
	add a,010h
	ld l,a
	djnz l8719h
	ret
; block_save_under (seg2 0x8741) - copy the nametable under this C470 slot
; into E480 (2x2, kind!=3) or E4A0 (4x4, kind 3), indexed by slot C.
block_save_under:
	cp 003h
	ld hl,0e4a0h
	jr z,l875eh
	ld hl,0e480h
l874bh:
	push hl
	push bc
	call map_cell_at
	pop bc
	pop de
	ld a,c
	add a,a
	add a,a
	call ADD_DE_A
	ld bc,00202h
	jp l8773h
l875eh:
	push hl
	push bc
	call map_cell_at
	pop bc
	pop de
	ld a,c
	add a,a
	add a,a
	add a,a
	add a,a
	call ADD_DE_A
	ld bc,00404h
	jp l8773h
l8773h:
	push bc
	ld b,000h
	push hl
	ldir
	pop hl
	pop bc
	ld a,020h
	call ADD_HL_A
	djnz l8773h
	ret
; tiles_blit_vram (seg2 0x8783) - B rows x C tile-ids from (HL) at pixel DE.
tiles_blit_vram:
	push bc
	push de
	ld b,c
l8786h:
	ld a,(hl)
	inc hl
	call tile_blit
	call blit_advance_x
	djnz l8786h
	pop de
	ld a,e
	add a,008h
	ld e,a
	pop bc
	djnz tiles_blit_vram
	ret
; 2x2 then 4x4 8x8 tile ids stamped over a breakable block (courtyard / castle).
block_tiles_court:
	defb 001h,002h,009h,00bh
	defb 001h,002h,001h,002h
	defb 009h,00bh,00ah,009h
	defb 001h,002h,001h,002h
	defb 009h,00bh,00ah,009h
block_tiles_castle:
	defb 001h,002h,00ah,00bh
	defb 001h,002h,001h,002h
	defb 00ah,00bh,00ah,00bh
	defb 001h,002h,001h,002h
	defb 00ah,00bh,00ah,00bh
; ---------------------------------------------------------------------------
;  brazier_destroyed (seg2 0x87C1) - candle or block hit.  HL -> +0x03.
;  Kind < 2: candle. Kind >= 2: restore nametable/VRAM from E480/E4A0, play
;  SFX 0x0E.  +05 bonus 0x1F = reveal (vendor/chest from +09); 0x18 = white
;  key floor spawn; else scenery_clear_rec + drop_spawn (slime = 0x15).
; ---------------------------------------------------------------------------
brazier_destroyed:
	ld (hl),000h            ; +0x03 hit flag = 0
	inc l
	ld (ix+000h),000h       ; +0x00 state = 0 (object gone)
	ld a,(hl)               ; A = +0x04 kind
	inc l
	ld b,(hl)               ; B = +0x05 bonus id
	cp 002h
	jp nc,l87d9h
	call block_restore_vram_2x2
	call scenery_clear_rec
	jp scenery_drop
l87d9h:
	push bc
	push de
	push bc
	ld c,a
	ld a,00eh
	call play_sound
	ld a,c
	pop bc
	cp 002h
	jr z,l87f0h
	call block_restore_vram_4x4
	call block_restore_map_4x4
	jr l87f6h
l87f0h:
	call block_restore_vram_2x2
	call block_restore_map_2x2
l87f6h:
	ld a,(ix+005h)         ; bonus id
	cp 01fh
	jr z,l881bh            ; 0x1F = reveal (third scenery byte)
	cp 018h
	jr z,l8845h            ; 0x18 = white key
	call scenery_clear_rec
	pop de
	pop bc
	ld a,b
	or a
	jr z,l8818h
	ld a,(ix+004h)
	cp 003h
	jr nz,l8815h
	ld a,e
	add a,010h             ; 4x4 block: drop at Y+16
	ld e,a
l8815h:
	call drop_spawn
l8818h:
	jp break_chip_spawn
; --- reveal (bonus 0x1F): +09 is the third scenery byte, +07/+08 -> E000 pos.
;  bits7-6 == 11 -> vendor at stamp Y (32x32 LMMM, no offset) via vendor_spawn.
;  otherwise -> chest at Y+16 (bottom half of the 4x4) via l8a1ah. Same
;  Y+16 as a kind-3 whip drop; scenery Y is the top of the stamp.
l881bh:
	pop de
	pop bc
	ld a,(ix+009h)         ; reveal byte
	ld b,a
	ld h,(ix+007h)         ; HL -> E000 pos
	ld l,(ix+008h)
	and 0c0h
	cp 0c0h
	ld a,b
	jr z,l8838h            ; vendor: keep stamp Y
	and 01fh
	ld b,a
	ld a,e
	add a,010h             ; chest: Y+16
	ld e,a
	jp l8a1ah
l8838h:
	ld c,a
	and 03ch
	rrca
	rrca
	ld b,a
	ld a,c
	and 003h
	ld c,a
	jp vendor_spawn
l8845h:
	ld b,a
	pop de
	pop bc
	ld h,(ix+007h)
	ld l,(ix+008h)
	jp l8a04h
block_restore_vram_2x2:
	ld hl,0e480h
tiles_blit_2x2:                     ; also: blit 2x2 from caller HL (door path)
	push bc
	push de
	ld a,c
	add a,a
	add a,a
	call ADD_HL_A
	ld bc,00202h
	call tiles_blit_vram
	pop de
	pop bc
	ret
block_restore_vram_4x4:
	ld hl,0e4a0h
tiles_blit_4x4:
	push bc
	push de
	ld a,c
	add a,a
	add a,a
	add a,a
	add a,a
	call ADD_HL_A
	ld bc,00404h
	call tiles_blit_vram
	pop de
	pop bc
	ret
scenery_clear_rec:
	ld h,(ix+007h)
	ld l,(ix+008h)
	ld (hl),000h           ; zero E000 pos (record gone)
	ret
block_restore_map_2x2:
	ld hl,0e480h
	push bc
	push de
	push hl
	push bc
	call map_cell_at
	pop bc
	pop de
	ld a,c
	add a,a
	add a,a
	call ADD_DE_A
	ex de,hl
	ld bc,00202h
	call tiles_to_map
	pop de
	pop bc
	ret
block_restore_map_4x4:
	ld hl,0e4a0h
tiles_to_map_4x4:                     ; also: 4x4 map restore from caller HL (vendor 0xE580)
	push bc
	push de
	push hl
	push bc
	call map_cell_at
	pop bc
	pop de
	ld a,c
	add a,a
	add a,a
	add a,a
	add a,a
	call ADD_DE_A
	ex de,hl
	ld bc,00404h
	call tiles_to_map
	pop de
	pop bc
	ret
tiles_to_map:
	push bc
	ld b,000h
	push de
	ldir
	pop de
	pop bc
	ld a,020h
	call ADD_DE_A
	djnz tiles_to_map
	ret
break_chip_spawn:                  ; (seg2 0x88CE) two chips at DE: right then left
	ld hl,0c5a6h
	ld bc,00201h
l88d4h:
	ld (hl),c
	inc l
	ld (hl),e
	inc l
	ld (hl),d
	inc l
	ld c,084h
	djnz l88d4h
	ret
break_chip_tick:                  ; (seg2 0x88DF) two C5A6 wall-break chips
	ld b,002h
	ld hl,0c5a6h
l88e4h:
	push bc
	push hl
	ld a,(hl)
	ld b,a
	or a
	jr z,l88f1h
	call break_chip_move
	call break_chip_sat
l88f1h:
	pop hl
	inc l
	inc l
	inc l
	pop bc
	djnz l88e4h
	ret
break_chip_move:                  ; (seg2 0x88F9) X ±2, Y += break_chip_dy[age]
	and 07fh
	ld c,a
	inc l
	inc l
	ld a,(hl)
	bit 7,b
	jr nz,l890ah
	add a,002h
	jr c,l8929h
	ld (hl),a
	jr l890fh
l890ah:
	sub 002h
	jr c,l8929h
	ld (hl),a
l890fh:
	dec l
	dec l
	ld a,c
	inc a
	ld de,break_chip_dy
	call ADD_DE_A
	ld a,(de)
	inc (hl)
	or a
	jr nz,l8921h
	dec (hl)
	ld a,00ah
l8921h:
	inc l
	add a,(hl)
	ld (hl),a
	cp 0d4h
	jr nc,l892ah
	ret
l8929h:
	dec l
l892ah:
	ld (hl),0e0h
	dec l
	ld (hl),000h
break_chip_dy:                    ; (seg2 0x892F) dY by chip age; 0-1 also `inc l; ret`
	defb 02ch,0c9h,0fah,0fch,0fch,0fch,0feh,0feh
	defb 0ffh,0ffh,001h,001h,002h,002h,004h,004h,004h,006h,000h
break_chip_sat:                   ; (seg2 0x8942) two chips -> SAT + colour lines
	ld hl,0c5a7h
	ld de,0d628h
	ld b,002h
l894ah:
	push bc
	push hl
	ld bc,002ffh
	ld a,0e0h
l8951h:
	push hl
	ldi
	ldi
	ld (de),a
	inc de
	inc de
	ld a,0e4h
	pop hl
	djnz l8951h
	pop hl
	inc hl
	inc hl
	inc hl
	pop bc
	djnz l894ah
	ld hl,0d4a0h
	ld a,002h
	call chip_fill16
	ld a,04ch
	call chip_fill16
	ld a,002h
	call chip_fill16
	ld a,04ch
chip_fill16:                      ; fill 16 colour bytes (break-chip SAT)
	ld b,010h
l897bh:
	ld (hl),a
	inc hl
	djnz l897bh
	ret
l8980h:
	ld a,005h              ; leather whip: source X = 5*16
	ld l,070h              ; source Y = 0x70
vram_hmmm16:                        ; HMMM 16x16 from VRAM page 1 at (A*16, L)
	add a,a
	add a,a
	add a,a
	add a,a
	ld h,a
	ld bc,01010h
	ld a,001h
	jp vdp_hmmm
l8991h:
	ld l,070h
	jp l8cd2h
scenery_drop:
	call drop_own_weapon_heart
scenery_drop_slot:
	ld a,b
	or a
	jr z,l89a5h
	cp 015h                ; slime: no flame, C500 hatches actor_blob_*
	jr z,l89a5h
	call drop_fx_spawn
	ret z
l89a5h:
	call pickup_slot_alloc
	ret nz
	ld (hl),001h
	inc l
	ld (hl),e
	inc l
	ld (hl),d
	inc l
	ld (hl),000h
	inc l
	ld (hl),b
	inc l
	ld (hl),000h
	ld a,b
	cp 015h
	jr z,l89c2h
	cp 002h
	jr c,l89c2h
	ld (hl),002h
l89c2h:
	inc l
	ld (hl),000h
	ret
drop_fx_spawn:                     ; (seg2 0x89C6) flame (heart) or actor_reward at DE
	push bc
	push de
	push ix
	ld a,e
	add a,010h
	ld e,a
	ld a,d
	add a,008h
	ld d,a
	ld a,b
	cp 001h
	jr nz,l89dbh
	ld c,actor_flame
	jr l89ddh
l89dbh:
	ld c,actor_reward
l89ddh:
	xor a
	call spawn_actor_ab
	ld a,(0cf31h)
	dec a
	pop ix
	pop de
	pop bc
	ret
drop_spawn:
	ld a,b
	cp 015h
	jp z,scenery_drop_slot
	call drop_own_weapon_heart
	call pickup_slot_alloc
	ret nz
pickup_slot_write:                 ; (seg2 0x89F7) C500: live 0x83, XY, bonus B, +5=FF
	ld (hl),083h
	inc l
	ld (hl),e
	inc l
	ld (hl),d
	inc l
	inc l
	ld (hl),b
	inc l
	ld (hl),0ffh
	ret
l8a04h:
	ld (0c70dh),hl
	call pickup_slot_alloc
	ret nz
	call pickup_slot_write
	ld a,l
	add a,009h
	ld l,a
l8a12h:
	ld de,(0c70dh)
	ld (hl),d
	inc l
	ld (hl),e
	ret
l8a1ah:
	ld (0c70dh),hl
	call pickup_slot_alloc
	ret nz
	push bc
	ld b,019h              ; chest container (bonus id 25)
	call pickup_slot_write
	pop bc
	ld a,l
	add a,008h
	ld l,a
	ld (hl),b              ; +0x0D = real contents id
	inc l
	jr l8a12h
drop_own_weapon_heart:             ; (seg2 0x8A30) dropping equipped subweapon -> small heart
	ld a,b
	cp 01ah
	ret c
	ld a,(0c416h)
	add a,019h
	cp b
	ret nz
	ld b,001h
	ret
pickup_slot_alloc:                 ; (seg2 0x8A3E) first free C500 slot; Z + HL, else NZ
	push bc
	ld hl,0c500h
	ld b,008h
l8a44h:
	ld a,(hl)
	or a
	jr z,l8a4fh
	ld a,010h
	add a,l
	ld l,a
	djnz l8a44h
	or a
l8a4fh:
	pop bc
	ret
pickup_tick:                       ; (seg2 0x8A51) 8 x C500 floor items/chests
	call pickup_popup_tick             ; pickup-popup timer
	ld bc,00800h
	ld hl,0c500h
l8a5ah:
	push hl
	pop ix
	push bc
	push hl
	ld a,(hl)
	ld b,a
	or a
	jr z,l8a6ah
	call pickup_state_tick
	call pickup_sat_draw
l8a6ah:
	pop hl
	pop bc
	ld a,010h
	add a,l
	ld l,a
	inc c
	djnz l8a5ah
	ret
pickup_state_tick:                 ; (seg2 0x8A74) C500 +0 dispatch; +3==1 -> pickup_try_collect
	ld e,(ix+001h)
	ld d,(ix+002h)
	ex af,af'
	ld a,(ix+003h)
	dec a
	jp z,pickup_try_collect
	ex af,af'
	dec a
	and 07fh
	exx
	ld hl,pickup_state_tbl
	add a,a
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)
	push de
	exx
	ret
pickup_state_tbl:                  ; (seg2 0x8A94) (state-1) -> handler; 1 and 6 share appear
	defw pickup_appear
	defw pickup_fall
	defw pickup_stamp
	defw pickup_idle
	defw pickup_hop
	defw pickup_appear
pickup_appear:                     ; (seg2 0x8AA0) 16-frame settle; slime hatches blob
	inc (ix+006h)
	ld a,(ix+006h)
	and 00fh
	ret nz
	inc (hl)
	ld a,(ix+004h)
	or a
	jp z,l8b22h
	cp 015h                ; slime fake-item: hatch instead of settling
	jr z,l8ad7h
	set 7,(hl)
	dec a
	ld a,001h
	jr z,l8abeh
	ld a,002h
l8abeh:
	ld (ix+005h),a
	ret nz
	ld (ix+006h),000h
	ld (ix+009h),002h
	ld (ix+00ah),000h
	ld (ix+00bh),000h
	ld (ix+00ch),020h
	ret
l8ad7h:
	ld a,(0d002h)          ; hub: 0 = courtyard (just despawn)
	or a
	ld b,a
	jr z,l8af4h
	ld a,b
	dec a
	and 007h
	ld hl,blob_hatch_type          ; hub-1 -> blue / white / red
	call ADD_HL_A
	ld c,(hl)
	push ix
	ld a,e
	add a,010h
	ld e,a
	call spawn_actor
	pop ix
l8af4h:
	jp l8b22h
blob_hatch_type:
	defb actor_blob_blue, actor_blob_white, actor_blob_red, actor_blob_red
	defb actor_blob_red, actor_blob_red, actor_blob_white, actor_blob_white
pickup_fall:                       ; (seg2 0x8AFF) +0x0810 gravity; bounce or land
	ld hl,00810h
	add hl,de
	ld a,0dbh
	cp l
	jr c,l8b22h
	ex de,hl
	call map_cell_at
	sub 001h
	cp 009h
	jr c,l8b6fh
	ld a,(ix+004h)
	dec a
	jp z,l8b29h
	ld a,(ix+001h)
	add a,008h
	ld (ix+001h),a
	ret
l8b22h:
	ld (ix+005h),0ffh
	jp l8bceh
l8b29h:
	push ix
	pop hl
	inc l
	inc (ix+006h)
	ld a,(0c003h)
	rra
	jr nc,l8b37h
	inc (hl)
l8b37h:
	inc l
	ld d,(hl)
	ld e,(ix+008h)
	ex de,hl
	ld b,(ix+009h)
	ld c,(ix+00ah)
	add hl,bc
	ex de,hl
	ld (ix+008h),e
	ld (hl),d
	ld h,b
	ld l,c
	ld b,(ix+00bh)
	ld c,(ix+00ch)
	and a
	sbc hl,bc
	ld (ix+009h),h
	ld (ix+00ah),l
	ld a,(ix+006h)
	sub 020h
	ret nz
	ld (ix+006h),a
	ld a,b
	cpl
	ld (ix+00bh),a
	ld a,c
	neg
	ld (ix+00ch),a
	ret
l8b6fh:
	ld (ix+005h),0ffh
	inc (ix+000h)
	ret
pickup_stamp:                      ; (seg2 0x8B77) snap to 8px, save under, blit icon
	ld a,e
	add a,004h
	and 0f8h
	ld e,a
	ld a,d
	add a,004h
	and 0f8h
	ld d,a
	ld (ix+001h),e
	ld (ix+002h),d
	push de
	call pickup_save_under
	pop de
	ld a,(ix+004h)
	dec a
	call bonus_icon_blit
	ld a,(ix+004h)
	sub 017h
	cp 003h
	ld a,008h
	jr nc,l8ba2h
	ld a,0ffh
l8ba2h:
	ld (ix+006h),a
	inc (ix+000h)
	ret
pickup_idle:                       ; (seg2 0x8BA9) floor wait; +3==2 whip; countdown despawn
	set 7,(hl)
	ld a,(ix+003h)
	cp 002h
	jp z,l8c4bh
	push de
	ld a,(ix+004h)
	dec a
	call bonus_icon_blit
	pop de
	ld a,(ix+006h)
	inc a
	ret z
	ld a,(0c003h)
	and 00fh
	ret nz
	dec (ix+006h)
	ret nz
	call pickup_restore_under
l8bceh:
	ld (ix+000h),000h
	ret
pickup_hop:                        ; (seg2 0x8BD3) chest-spill: every 32 frames -> fall
	inc (ix+006h)
	ld a,(ix+006h)
	and 01fh
	ret nz
	ld (hl),002h
	ld a,(ix+004h)
	or a
	jp z,l8b22h
	ret
pickup_try_collect:                ; (seg2 0x8BE6) Simon/key touch: collect or chest_spill
	ld (ix+003h),000h
	call chest_try_open
	ret nz
	ld a,(hl)
	and 07fh
	ld (hl),000h
	cp 004h
	jr nz,l8bfah
	call pickup_restore_under
l8bfah:
	ld a,(ix+004h)
	cp 019h                ; chest: don't collect_bonus(25); reveal contents
	jr z,l8c1bh
	ld (ix+005h),0ffh
	call pickup_collect
	ld a,(ix+004h)
	cp 017h
	jr z,l8c12h
	cp 018h
	ret nz
l8c12h:
	ld h,(ix+00eh)
	ld l,(ix+00fh)
	ld (hl),000h
	ret
l8c1bh:
	ld a,(ix+00dh)         ; contents id stashed when the chest spawned
	ld (ix+004h),a
	call chest_spill         ; hop it as a normal pickup
	ld a,(0c700h)
	or a
	jr nz,l8c12h
	ld hl,0c701h
	ld a,(hl)
	and 0f9h
	ld (hl),a
	call hud_chest_key_icon
	jr l8c12h
chest_spill:                       ; (seg2 0x8C36) hop opened chest contents as state 5
	ld a,(ix+001h)
	sub 008h
	ld (ix+001h),a
	ld (ix+000h),005h
	ld (ix+006h),000h
	ld (ix+005h),002h
	ret
; Whip-hit on a world pickup: hourglass (id 10) tips onto its side (id 11);
; a second hit on the tipped one starts its despawn timer (ix+6=1).
l8c4bh:
	ld (ix+003h),000h
	ld a,(ix+004h)
	cp 00ah                ; upright hourglass?
	jr nz,l8c5fh
	ld (ix+004h),00bh      ; -> tipped (bonus_tipped_hourglass)
	call pickup_restore_under
	jr chest_spill
l8c5fh:
	cp 00bh                ; already tipped: another whip deletes it
	ret nz
	ld (ix+006h),001h
	ret
pickup_sat_draw:                   ; (seg2 0x8C67) SAT/colour for live C500; skip chests
	ld a,(ix+004h)
	cp 019h
	ret z
	ld a,(ix+000h)
	and 00fh
	cp 004h
	ret z
	ld a,(ix+005h)
	or a
	jr z,l8c85h
	dec a
	jr z,l8c98h
	dec a
	jr z,l8c9dh
	ld a,0e0h
	jr l8cafh
l8c85h:
	ld a,(0c003h)
	ld b,a
	and 001h
	ret nz
	bit 2,b
	ld b,0f4h
	jr nz,l8c94h
	ld b,0f8h
l8c94h:
	ld c,008h
	jr l8cach
l8c98h:
	ld bc,0e808h
	jr l8cach
l8c9dh:
	ld bc,0ec0eh
	ld a,(0c003h)
	and 003h
	ld hl,l8cc4h
	call ADD_HL_A
	ld c,(hl)
l8cach:
	ld a,(ix+001h)
l8cafh:
	ld hl,0d628h
	ld (hl),a
	inc hl
	ld a,(ix+002h)
	ld (hl),a
	inc hl
	ld (hl),b
	ld hl,0d4a0h
	ld b,010h
l8cbfh:
	ld (hl),c
	inc hl
	djnz l8cbfh
	ret
l8cc4h:
	ex af,af'
	ld bc,0010eh
bonus_icon_blit:                   ; (seg2 0x8CC8) 16x16 LMMM from page-0 atlas (Y 0x50/0x60)
	ld l,050h
	cp 010h
	jr c,l8cd2h
	sub 010h
	ld l,060h
l8cd2h:
	add a,a
	add a,a
	add a,a
	add a,a
	ld h,a
	ld bc,01010h
	ld a,048h
	jp vdp_lmmm
pickup_save_under:                 ; (seg2 0x8CDF) nametable 2x2 under pickup -> E520
	push bc
	call map_cell_at
	pop bc
	ld (ix+007h),c
	ld hl,0e520h
	jp l874bh
pickup_restore_under:              ; (seg2 0x8CED) put the saved 2x2 back, then redraw overlays
	push ix
	push de
	push de
	ld c,(ix+007h)
	ld hl,0e520h
	push bc
	push hl
	call map_cell_at
	ld de,0e800h
	ld bc,00202h
	call l8773h
	pop hl
	pop bc
	push bc
	push hl
	ld a,c
	add a,a
	add a,a
	call ADD_HL_A
	ld b,004h
	ld de,0e800h
l8d14h:
	ld a,(de)
	cp (hl)
	jr z,l8d19h
	ld (hl),a
l8d19h:
	inc hl
	inc de
	djnz l8d14h
	pop hl
	pop bc
	pop de
	call tiles_blit_2x2
	call vendor_redraw_all
	call door_begin_open
	call candle_outlines_if
	pop de
	pop ix
	ret
pickup_collect:                    ; (seg2 0x8D30) A = slot+4, then collect_bonus
	ld a,(ix+004h)
; ---------------------------------------------------------------------------
;  collect_bonus (seg2 0x8D33) - apply a picked-up bonus whose id is in A.
;  Entry collect_bonus pushes the common tail play_sound; collect_bonus_apply is the bare entry
;  (caller supplies its own continuation).  Latches the bonus id into 0xC419
;  (last-pickup latch, drives the pickup HUD/message) then dispatches through the
;  25-entry word table collect_bonus_tbl at 0x8D45 (index = A-1; A>=0x1A falls through to l8d77h):
;    1/2 hearts, 3/4 shields, 5 white cross, 6 rosary, 7 small orb, 8 blue gem,
;    9 sapphire ring, 10/11 hourglass (upright / tipped), 12/13 boots/wings,
;    14 candle, 15 map, 16/17 bibles, 18 lockpick, 19/20 money bags,
;    21 slime (fake pickup; collect is a no-effect stub), 22 potion, 23/24 keys,
;    25 chest (container; world collect never reaches this stub).
;  Reached from both pickup paths: the mid-air 0xC800 heart (type 0x24, via
;  actor_kill_special) and the settled 0xC500 pickup list.
; ---------------------------------------------------------------------------
collect_bonus:
	ld hl,play_sound
	push hl
collect_bonus_apply:
	ld (0c419h),a          ; latch last-collected bonus id
	call 08f2ah
	cp 01ah
	jr nc,l8d77h
	dec a
	call DISPATCH_A
collect_bonus_tbl:             ; (seg2 0x8D45) word[id-1]; id>=0x1A -> l8d77h
	defw bonus_small_heart
	defw bonus_large_heart
	defw bonus_red_shield
	defw bonus_yellow_shield
	defw bonus_white_cross
	defw bonus_rosary
	defw bonus_small_orb
	defw bonus_blue_gem
	defw bonus_sapphire_ring
	defw bonus_hourglass
	defw bonus_tipped_hourglass
	defw bonus_boots
	defw bonus_wings
	defw bonus_candle
	defw bonus_map
	defw bonus_black_bible
	defw bonus_white_bible
	defw bonus_lockpick
	defw bonus_white_bag
	defw bonus_blue_bag
	defw bonus_slime
	defw bonus_potion
	defw bonus_yellow_key
	defw bonus_white_key
	defw bonus_chest
; --- weapon pickup (bonus id >= 0x1A) ---------------------------------------
; index = id - 0x19 -> C416: 0x1A chain (1), 0x1B knife (2), 0x1C axe (3),
; 0x1D cross (4). Index 5 is holy water (bonus_holy_water / C701 bit3), not a
; C416 weapon. Otherwise store the new weapon id, run hud_weapon_icon (HUD), then
; FALL THROUGH into bonus_rosary (brief C440 no-spawn window).
l8d77h:
	sub 019h
	cp 005h
	jr z,bonus_holy_water
	ld (0c416h),a          ; set equipped weapon id
	call hud_weapon_icon
; --- bonus_rosary (id 6, 0x8D83) - temporary "no new enemies" power-up ------
; Arms the enemy-spawn suppression timer 0xC440: while nonzero, room_spawner
; (seg0 0x5EBF) bails every frame and no new enemies spawn. Duration depends on
; bonus id 11 (0xC431 bit 2): 0xF0 (240 frames ~4s) if set, else 0x96 (150
; frames ~2.5s).  Same bit also lengthens the blue gem, sapphire ring, and
; hourglass.  0xC440 counts down each frame in
; seg1 0x75C7. Effect is immediate/current-room; existing 0xC800 actors are kept.
; Weapon pickups fall through into this same code (brief no-spawn window).
bonus_rosary:
	ld a,(0c431h)          ; id 11 (C431 bit2) selects the duration
	and 004h
	ld a,0f0h              ; -> 240-frame timer
	jr nz,l8d8eh
	ld a,096h              ; -> 150-frame timer
l8d8eh:
	ld (0c440h),a          ; arm the no-spawn timer
l8d91h:
	ld a,012h
	ret
bonus_holy_water:              ; id 0x1E (0x8D94): C701 bit3; jump+LEFT/RIGHT, 5 hearts
	ld b,008h
l8d96h:
	call inv_or_c701
	jr l8d91h
bonus_hourglass:               ; id 10 (0x8D9B): C701 bit6
	ld b,040h
	jr l8d96h
bonus_red_shield:              ; id 3 (0x8D9F): C701 bit4, drop bit5, C441=16
	ld hl,0c701h
	res 5,(hl)             ; drop yellow (mutually exclusive)
	ld b,010h              ; bit4 = red shield (face-on contact dmg not 2x)
	jr l8dafh
bonus_yellow_shield:           ; id 4 (0x8DA8): C701 bit5, drop bit4, C441=16
	ld hl,0c701h
	res 4,(hl)             ; drop red
	ld b,020h              ; bit5 = yellow (absorb enemy shots)
l8dafh:
	ld a,010h
	ld (0c441h),a          ; 16 charges
	jr l8d96h
bonus_small_heart:             ; id 1 (0x8DB6): +1 heart currency
	ld b,001h
l8db8h:
	call add_hearts         ; B=1 small (+1); B=5 large (+5)
	ld a,00fh
	ret
bonus_large_heart:             ; id 2 (0x8DBE): +5 heart currency
	ld b,005h
	jr l8db8h
bonus_white_cross:             ; id 5 (0x8DC2): despawn on-screen actors
	push ix
	call actors_kill_all            ; kill C800 actors and shots
	pop ix
	call vendor_force_hit
	ld a,018h
	ld (0c43eh),a          ; backdrop flash
	ld a,01bh
	ret
bonus_blue_gem:                ; id 8 (0x8DD4): invis; sprite flash white
	ld a,(0c431h)          ; id 11 -> longer
	and 004h
	ld a,0f0h              ; 240 frames ~4s
	jr nz,l8ddfh
	ld a,096h              ; 150 frames ~2.5s
l8ddfh:
	ld (0c43ah),a          ; skip contact + projectile hits while nonzero
	ld a,016h
	ret
bonus_small_orb:               ; id 7 (0x8DE5): +8 HP (1/4 of 0x20 bar)
	ld b,008h
	call restore_health
	jr l8e11h
bonus_sapphire_ring:           ; id 9 (0x8DEC): sprite flash red; touch-kills
	ld a,(0c431h)          ; id 11 -> longer
	and 004h
	ld a,0f0h
	jr nz,l8df7h
	ld a,096h
l8df7h:
	ld (0c434h),a
	jr l8e11h
bonus_tipped_hourglass:        ; id 11 (0x8DFC): C431 bit2, 1.5x timed bonuses
	ld hl,0c431h           ; whip the hourglass pickup once to get this
	set 2,(hl)
	jr l8e11h
bonus_boots:                   ; id 12 (0x8E03): C431 bit3 faster walk
	ld hl,0c431h
	set 3,(hl)
	jr l8e11h
bonus_wings:                   ; id 13 (0x8E0A): C431 bit4 higher jump
	ld hl,0c431h
	set 4,(hl)
	jr l8e11h
l8e11h:
	jp l8d91h
bonus_potion:                  ; id 22 (0x8E14): bottle, +32 HP = full bar
	ld b,020h              ; vendor sells this (price tbl 0x16); HUD tile @ 0x9A00
	call restore_health
	jr l8e11h
; Shared stub for slime (id 21) and chest (id 25).  collect_bonus has already
; latched C419 and shown the popup; this pops the play_sound continuation and
; returns with no effect.  World chests never get here (l8c1bh opens them).
bonus_slime:                   ; id 21 (0x8E1B): fake candle drop; hatches if left
bonus_chest:                   ; id 25: treasure-chest container (see l8a1ah)
	pop hl
	ret
bonus_candle:                  ; id 14 (0x8E1D): C702 bit0, white C470 outlines
	call candle_outlines         ; draw 0x0E rectangles on breakable blocks
	ld b,001h
	jr l8e34h
bonus_black_bible:             ; id 16 (0x8E24): C702 bit6, vendor price doubled
	ld hl,0c702h
	res 7,(hl)             ; drop the white-bible bit (mutually exclusive)
	ld b,040h
	jr l8e34h
bonus_white_bible:             ; id 17 (0x8E2D): C702 bit7, vendor price halved
	ld hl,0c702h
	res 6,(hl)             ; drop the black-bible bit (mutually exclusive)
	ld b,080h
l8e34h:
	call inv_or_c702         ; 0xC702 |= B
	ld a,012h              ; pickup popup message id
	ret
bonus_map:                     ; id 15 (0x8E3A): C431 bit6, C701 bit7, C70F=3
	ld hl,0c431h
	set 6,(hl)
	ld a,003h
	ld (0c70fh),a          ; 3 map uses (F2)
	ld b,080h
	jp l8d96h
bonus_white_bag:               ; id 19 (0x8E49): +5000 score
	ld de,05000h
l8e4ch:
	call add_score_c0
	ld a,010h
	ret
bonus_blue_bag:                ; id 20 (0x8E52): +1000 score
	ld de,01000h
	jr l8e4ch
bonus_yellow_key:              ; id 23 (0x8E57): C701 bit1, C700=1 (chests)
	ld b,002h
	call inv_or_c701
	ld hl,0c700h
	ld (hl),001h
	call hud_chest_key_icon
	ld a,014h
	ret
bonus_white_key:               ; id 24 (0x8E67): C701 bit0 (stage-exit door)
	ld b,001h
	call inv_or_c701
	call hud_white_key_icon
	ld a,014h
	ret
	pop hl
	ret
; OR bit-mask B into an inventory byte: inv_or_c701 -> 0xC701, inv_or_c702 -> 0xC702
inv_or_c701:
	ld hl,0c701h
	jr l8e7ch
inv_or_c702:
	ld hl,0c702h
l8e7ch:
	ld a,b
	or (hl)
	ld (hl),a
	ret
bonus_lockpick:                ; id 18 (0x8E80): C700=3, C701 bit2; drops yellow key
	ld hl,0c431h
	set 1,(hl)
	ld hl,0c701h
	res 1,(hl)             ; can't hold yellow key with the lockpick
	ld b,004h
	call inv_or_c701
	ld a,003h
	ld (0c700h),a
	call hud_chest_key_icon
	ld a,00fh
	ret
lose_weapon:                   ; (0x8E9A) C416=0 leather; refresh HUD (missed catch)
	xor a
	ld (0c416h),a
	jp hud_weapon_icon
hud_weapon_icon:                     ; HUD equipped-weapon icon from C416
	ld a,(0c416h)
	ld de,l800ch
	or a
	jp z,l8980h            ; 0 = leather (not in the bonus sheet)
	add a,019h             ; C416 1..4 -> bonus ids 0x1A..0x1D
hud_bonus_tile:                        ; A = bonus id -> blit that HUD tile
	dec a                  ; 0-based index
	ld l,050h              ; ids 1-16 at Y=0x50
	cp 010h
	jr c,l8eb8h
	sub 010h
	ld l,060h              ; ids 17+ at Y=0x60
l8eb8h:
	jp vram_hmmm16
hud_keys_refresh:
	call hud_chest_key_icon
	jp hud_white_key_icon
hud_white_key_icon:
	ld de,0a40ch
	ld a,(0c701h)
	and 001h
	jp z,l8980h
	ld a,018h
	jr hud_bonus_tile
hud_chest_key_icon:
	ld de,0940ch
	ld a,(0c701h)
	ld b,a
	and 006h
	jp z,l8980h
	ld a,(0c700h)
	or a
	jp z,l8980h
	bit 2,b                ; C701 bit2 = lockpick
	ld a,012h              ; bonus 0x12 lockpick
	jr nz,l8eebh
	ld a,017h              ; bonus 0x17 yellow key
l8eebh:
	jr hud_bonus_tile
hud_bonus_refresh:
	call hud_bonus_clear
	ld a,(0c701h)
	ld c,a
	ld b,005h              ; bits 7..3: map, hourglass, Y shield, R shield, holy
	xor a
l8ef7h:
	rl c
	call c,hud_bonus_icon
	inc a
	djnz l8ef7h
	ret
	ld c,b
	ld b,005h
	xor a
l8f04h:
	rl c
	jr c,hud_bonus_icon
	inc a
	djnz l8f04h
	ret
hud_bonus_icon:
	push af
	push bc
	ld hl,hud_bonus_pos
	add a,a
	call ADD_HL_A
	ld d,(hl)
	ld e,00ch
	inc hl
	ld a,(hl)
	call hud_bonus_tile
	pop bc
	pop af
	ret
hud_bonus_pos:                 ; X, bonus id for C701 bits 7..3
	defb 0e8h,00fh         ; map
	defb 0d8h,00ah         ; hourglass
	defb 0c8h,004h         ; yellow shield
	defb 0c8h,003h         ; red shield
	defb 0b8h,01eh         ; holy water
pickup_popup_show:
	cp 001h                ; small heart: no popup
	ret z
	cp 01eh                ; holy water: always popup
	jr z,pickup_popup_go
	cp 017h                ; keys/chest/weapons (>=0x17): no popup
	ret nc
pickup_popup_go:
	push ix
	push af
; Show the on-screen pickup popup (the little item name/message). This runs for
; EVERY pickup (via 0x8F2A), so 0xC5E5/0xC5E6 are generic - NOT rosary-specific.
	ld a,0ffh
	ld (0c5e5h),a          ; 0xC5E5 = popup active (0xFF)
	ld a,020h
	ld (0c5e6h),a          ; 0xC5E6 = popup display timer (0x20 frames)
	call hud_bonus_clear
	ld de,0d00ch
	ld a,(0c419h)
	call hud_bonus_tile
	pop af
	pop ix
	ret
hud_bonus_clear:
	ld hl,0b80ch
	ld bc,04010h
	xor a
	ld d,a
	jp vdp_hmmv
; Pickup-popup tick: if 0xC5E5==0xFF (active), every 0x40 frames decrement the
; 0xC5E6 timer; when it hits 0, tear the popup down (hud_bonus_refresh).
pickup_popup_tick:
	ld a,(0c5e5h)
	inc a
	ret nz                 ; not 0xFF -> no popup active
	ld a,(0c003h)
	and 03fh
	ret z
	ld hl,0c5e6h
	dec (hl)
	ret nz
	jp hud_bonus_refresh
chest_try_open:
	push hl
	ld a,(ix+004h)
	cp 019h                ; chest: need C700 (yellow key / lockpick charges)
	jr nz,l8f8ah
	ld hl,0c700h
	ld a,(hl)
	or a
	jr nz,l8f81h
	inc a                      ; NZ: no chest-key charges
	pop hl
	ret
l8f81h:
	dec (hl)
	ld a,011h
	call play_sound
l8f87h:
	xor a                      ; Z: ok to collect
	pop hl
	ret
l8f8ah:
	cp 017h                    ; yellow key: skip if bit1 or lockpick bit2
	ld b,006h
	jr z,l8f96h
	cp 018h                    ; white key: skip if bit0 already set
	ld b,001h
	jr nz,l8f87h
l8f96h:
	call already_have_key
	pop hl
	ret
already_have_key:                  ; (seg2 0x8F9B) NZ if C701 has any of B
	ld hl,0c701h
	ld a,(hl)
	and b
	ret
; --- the spike bars (0xC580 hazard pool) ------------------------------------
; The only thing that ever occupies the three 0xC580 slots: the chain-hung
; spike bars of stage 6 room 1.  They are *not* actors - no C500 slot, no HP,
; they cannot be killed - and they are *not* hardware sprites.  Each is a
; 32x16 4bpp background block HMMM'd out of the page-1 staging area that seg0
; 0x5494 assembles at (0x80, 0x70) from spike_bar_mount + 4x spike.
;
; 8-byte slot layout (only +0..+5 are seeded; +6/+7 are zeroed):
;   +0 state: 1 = descending (+4/step), 2 = retracting (-4/step); 0 = free.
;             bit 0 also picks the contact damage, so descending hurts more.
;   +1 Y     current position (the collision/bar row)
;   +2 X     fixed column
;   +3 mask  extra rate gate while descending (0 = every tick, 1 = every 2nd)
;   +4 tick  free-running frame counter, incremented every tick
;   +5 steps steps per sweep; toggles state on reaching it (0x0B*4 = 44px)
;   +6 count steps taken so far in this sweep
;
; Descending is gated by `+4 & +3` and retracting by `+4 & 3`, so a bar drops
; fast and crawls back up. Contact damage is dealt by hurt_simon_spikes
; (0x85AD) over a 32x8 box: 16 HP while descending, 8 HP while retracting.
;
; The chain the bar hangs from is not artwork - it is a deliberate smear.  The
; block is 16 rows but the art is only 12: rows 0-3 are the spike_bar_mount
; chain link, rows 4-11 the bar and spikes, rows 12-15 blank.  It is drawn at
; Y-4, and the step is also 4px, so each descending step leaves row 0-3 behind
; uncovered and the links stack into a seamless rod.  Retracting paints the bar
; over the links again (and the blank rows 12-15 wipe the spike tips), so the
; chain grows and shrinks with the drop, which is why the three bars in the
; room have visibly different chain lengths.
spike_bars_seed_once:              ; (0x8FA1) seed only if slot 0 is free
	ld a,(0c580h)
	or a
	ret nz
spike_bars_seed:                   ; (0x8FA6) seed unconditionally
	ld hl,(0d000h)
	ld de,00106h
	rst 20h
	ret nz                 ; D000/D001 = stage/room: stage 6 room 1 only
	ld hl,spike_bar_seeds
	ld de,0c580h
	ld b,003h
l8fb6h:
	push bc
	ld bc,00006h
	ldir                   ; 6 seed bytes -> slot
	xor a
	ld (de),a
	inc e
	inc e                  ; zero +6, skip +7 (stride 8)
	pop bc
	djnz l8fb6h
	ret
spike_bar_seeds:                   ; 3 x 6-byte C580 seeds (stage 6 room 1)
	defb 001h,060h,03ch,000h,000h,00bh ; left arch:   X=0x3C, every tick
	defb 001h,060h,07ch,000h,001h,00ah ; centre arch: X=0x7C, tick phase 1
	defb 001h,060h,0bch,001h,002h,00bh ; right arch:  X=0xBC, half rate
hazard_tick:                       ; (seg2 0x8FD6) tick the 3 spike bars
	call spike_bars_seed_once
spike_bars_run:                    ; (0x8FD9) walk the 3 slots, stride 8
	ld hl,0c580h
	ld b,003h
l8fdeh:
	push hl
	pop ix
	push bc
	push hl
	ld a,(hl)
	or a
	call nz,spike_bar_slot_tick    ; state != 0 -> live
	pop hl
	pop bc
	ld a,008h
	add a,l
	ld l,a
	djnz l8fdeh
	ret
; spike_bar_slot_tick (0x8FF1): advance and repaint one bar.  IX/HL = slot,
; A = state.  Falls through to the HMMM, so the bar is redrawn only on the
; ticks it actually moves.
spike_bar_slot_tick:
	inc hl
	ld e,(hl)              ; E = +1 Y
	inc hl
	ld d,(hl)              ; D = +2 X
	inc hl
	ld c,(hl)              ; C = +3 descend rate mask
	inc hl
	inc (hl)
	ld b,(hl)              ; B = +4 tick counter (post-increment)
	inc hl                 ; -> +5
	dec a
	jr nz,l9005h           ; state 2 -> retracting
	ld a,c
	and b
	ret nz                 ; descending: gate on tick & +3
	ld a,004h              ; +4 px (downwards)
	jr l900bh
l9005h:
	ld a,003h
	and b
	ret nz                 ; retracting: only every 4th tick
	ld a,0fch              ; -4 px (upwards)
l900bh:
	add a,e
	ld e,a                 ; E = new Y
	ld a,(hl)              ; A = +5 steps per sweep
	inc hl                 ; -> +6
	inc (hl)
	sub (hl)               ; steps - count
	jr nz,l901ch
	ld (hl),a              ; end of sweep: count = 0
	ld a,(ix+000h)
	xor 003h               ; state 1 <-> 2 (descend <-> retract)
	ld (ix+000h),a
l901ch:
	ld (ix+001h),e         ; commit Y
	ld a,e
	sub 004h
	ld e,a                 ; draw 4px high: block row 0 is the chain link
	ld hl,08070h           ; SX=0x80 SY=0x70: the spike-bar staging block, page 1
	ld bc,02010h           ; 32x16 (spike_bar_mount + 4x spike, staged by seg0 0x54AD)
	ld a,001h
	jp vdp_hmmm            ; src page 1 -> dest page 0 at (X, Y-4)
; spike_bars_restore (0x902E): repaint the bars after the F2 map screen has
; overwritten the playfield (reseeds, so the sweep restarts from the top).
spike_bars_restore:
	call spike_bars_seed
	jp spike_bars_run
; --- moving platforms (0xC598) ----------------------------------------------
;  Two slots of 7 bytes, present only on stages 5 and 10.  A platform is a
;  32x16 two-plane hardware-sprite deck that slides horizontally between two
;  end points and carries Simon with it.
;
;  7-byte slot layout (platform_load seeds +0..+4 from platform_tbl):
;    +0 slot id, 1 or 2; 0 = free
;    +1 Y      visual row (platform_overlap uses this; SAT writes Y-1)
;    +2 X      current position, the only thing that moves
;    +3 step   signed px/tick, negated at each end point
;    +4 span   ticks per sweep before reversing
;    +5 tick   free-running counter, incremented but unread here
;    +6 count  ticks elapsed in this sweep
;  Note +5/+6 are NOT seeded (platform_load skips them): actor_state_reset
;  already zeroed 0xC470-0xC6FF, which includes the C598 pool.
;
;  Simon's side: platform_stand_test (0x852B) sets 0xC439 to the slot id he is
;  standing on, and platform_carry_simon (seg1 0x6BB6) then nudges his X by the
;  sign of +3 each frame.
platform_load:                     ; (seg2 0x9034) seed C598 from platform_tbl
	ld hl,0c598h
	ld a,(hl)
	or a
	ret nz                 ; already seeded for this room
	ld hl,platform_tbl
l903dh:
	ld a,(hl)
	inc a
	ret z                  ; 0xFF terminator: no platforms in this room
	dec a
	push hl
	ld de,(0d000h)         ; E = stage (0xD000), D = room (0xD001)
	cp e
	jr nz,l9067h
	inc hl
	ld a,(hl)
	cp d
	jr nz,l9067h
	inc hl
	ld b,(hl)              ; B = platform count for this room
	inc hl
	ld de,0c598h
	ld c,001h              ; slot ids start at 1
l9056h:
	push bc
	ld a,c
	ld (de),a              ; +0 = slot id
	inc de
	ld bc,00004h
	ldir                   ; +1..+4 = Y, X, step, span
	inc de
	inc de                 ; leave +5/+6 alone, land on the next slot
	pop bc
	inc c
	djnz l9056h
	pop hl
	ret
l9067h:
	pop hl
	inc hl
	inc hl
	ld a,(hl)              ; skip this record: 3 header bytes + n*4
	inc hl
	add a,a
	add a,a
	call ADD_HL_A
	jr l903dh
platform_tbl:                      ; (seg2 0x9073) {stage,room,n} + n x {Y,X,step,span}; 0xFF end
	; Y is the visual top (stand test). SAT is Y-1 (VDP draws at SAT+1).
	defb 005h,001h,001h        ; stage 5 room 1
	defb 05fh,060h,001h,040h    ; Y=0x5F X=0x60 right, 64-tick sweep
	defb 005h,004h,002h        ; stage 5 room 4 - a pair, moving apart
	defb 05fh,020h,001h,030h    ; Y=0x5F X=0x20 right, 48
	defb 05fh,0b8h,0ffh,038h    ; Y=0x5F X=0xB8 left,  56
	defb 00ah,000h,001h        ; stage 10 rooms 0/2/3/4, one each
	defb 08fh,060h,001h,060h    ; Y=0x8F X=0x60 right, 96
	defb 00ah,002h,001h
	defb 0a7h,040h,001h,080h    ; Y=0xA7 X=0x40 right, 128
	defb 00ah,003h,001h
	defb 08fh,020h,001h,0a0h    ; Y=0x8F X=0x20 right, 160
	defb 00ah,004h,001h
	defb 0a7h,080h,001h,040h    ; Y=0xA7 X=0x80 right, 64
	defb 0ffh
platform_tick:                     ; (seg2 0x90A2) 2 x C598 moving platforms
	ld hl,0c598h
	ld b,002h
l90a7h:
	push bc
	push hl
	ld a,(hl)
	or a
	jr z,l90b5h            ; slot free
	push hl
	call platform_move
	pop hl
	call platform_sat_build
l90b5h:
	pop hl
	pop bc
	ld de,00007h
	add hl,de              ; next slot
	inc c
	djnz l90a7h
	ret
; platform_move (0x90BF): advance one platform.  HL = slot.  On the tick where
; the sweep counter reaches +4 it reverses (+3 = -+3) and does NOT move, so the
; deck pauses for a frame at each end point.
platform_move:
	inc hl
	inc hl
	ld d,(hl)              ; D = +2 X
	inc hl
	ld e,(hl)              ; E = +3 step
	inc hl
	ld c,(hl)              ; C = +4 span
	inc hl
	inc (hl)               ; ++ +5 free-running tick
	ld a,(hl)
	inc hl
	inc (hl)               ; ++ +6 sweep counter
	ld a,c
	sub (hl)               ; span - count
	jr nz,l90d0h
	ld (hl),a              ; end of sweep: count = 0
l90d0h:
	dec hl
	dec hl
	dec hl                 ; -> +3
	jr nz,l90dah
	ld a,(hl)
	neg
	ld (hl),a              ; reverse direction
	ret
l90dah:
	dec hl                 ; -> +2
	ld a,d
	add a,e
	ld (hl),a              ; X += step
	ret
; platform_sat_build (0x90DF): emit one platform's 4 sprite attribute entries
; and their per-line colours.  Slot 1 uses SAT 0xD638 / colours 0xD4E0, slot 2
; uses 0xD648 / 0xD520.  The two colours alternate per cell and the second of
; each pair has the CC bit (0x40), so cells 0+1 and 2+3 OR together into one
; two-colour 16x16 half each: 2/4 on stage 5, 9/0xC elsewhere.
platform_sat_build:
	ld a,(hl)              ; A = +0 slot id
	push af
l90e1h:
	inc hl                 ; -> +1 (Y), where platform_sat_cells starts reading
	ld de,0d638h
	dec a
	jr z,l90ebh
	ld de,0d648h
l90ebh:
	call platform_sat_cells
	pop af
	ld hl,0d4e0h
	dec a
	jr z,l90f8h
	ld hl,0d520h
l90f8h:
	ld de,00244h           ; stage 5: colour 2 + colour 4 with CC
	ld a,(0d000h)
	cp 005h
	jr z,l9105h
	ld de,0094ch           ; elsewhere: colour 9 + colour 0xC with CC
l9105h:
	ld a,d
	call platform_fill16
	ld a,e
	call platform_fill16
	ld a,d
	call platform_fill16
	ld a,e                 ; falls through for the fourth cell
platform_fill16:                   ; 16 colour bytes (one 16x16 sprite's lines)
	ld b,010h
l9114h:
	ld (hl),a
	inc hl
	djnz l9114h
	ret
; platform_sat_cells (0x9119): write 4 SAT entries at DE from the slot at HL.
; Y is the visual row minus 1 (MSX SAT Y is the line above the sprite, so
; writing table Y-1 puts the deck top on table Y). X is the slot X plus the
; cell's offset; the pattern comes from platform_sat_ofs, shifted by 8 off
; stage 5 so each hub gets its own deck artwork (D0/D4 vs D8/DC).  Colour
; is left to platform_sat_build.
platform_sat_cells:
	ld ix,platform_sat_ofs
	ld b,004h
l911fh:
	push bc
	push hl
	ld a,(hl)              ; A = +1 visual Y
	dec a                  ; SAT Y = visual-1 (VDP draws at SAT+1)
	ld (de),a              ; SAT Y
	inc hl
	inc de
	ld a,(ix+000h)         ; cell X offset (0 or 0x10)
	add a,(hl)             ; + +2 platform X
	ld (de),a              ; SAT X
	inc hl
	inc de
	ld c,(ix+001h)         ; cell pattern
	ld a,(0d000h)
	cp 005h
	ld a,c
	jr z,l913ah
	add a,008h             ; not stage 5 -> the other deck patterns
l913ah:
	ld (de),a              ; SAT pattern
	inc de
	inc de                 ; skip the colour byte -> next SAT entry
	inc ix
	inc ix
	pop hl
	pop bc
	djnz l911fh
	ret
platform_sat_ofs:                  ; 4 x {X offset, pattern}: two 16x16 halves,
	defb 000h,0d0h             ; each built from two OR'd planes (CC).
	defb 000h,0d4h             ; Both halves reuse D0/D4 (or D8/DC off s5).
	defb 010h,0d0h
	defb 010h,0d4h
; --- door_anim_tick (0x914E) - door-open animation driver (0xC5AC) ----------
;  0xC5AC is the door sub-state.  door_load_coords arms it to 0xFF (vertical
;  door: blit the closed graphic via door_blit_tiles) or 0x04 (courtyard).
;  door_begin_open sets 0xFF again to start the OPEN sequence.  Here:
;   0xC5AC == 0xFF -> jp door_blit_tiles (C5AC:=1, paint 6 tiles at Y,X)
;   0xC5AC   != 3  -> nothing to do yet
;  When == 3, 0xC5AD=Y / 0xC5AE=X give the door position; +3 is a frame
;  counter that advances each call, blitting opening frames via 0x494D
;  until it reaches 0x2C, then latches "open" (state stays 3 at l916fh).
door_anim_tick:
	ld hl,0c5ach
	ld a,(hl)
	inc a
	jp z,door_blit_tiles   ; 0xFF -> blit door graphic, C5AC:=1
	cp 003h
	ret nz                 ; only animate in the "open" state
	inc l
	ld e,(hl)              ; E = door Y (0xC5AD)
	inc l
	ld d,(hl)              ; D = door X (0xC5AE)
	inc l
	inc (hl)               ; advance the opening-frame counter (+3)
	ld a,(hl)
	cp 02ch
	jr nc,l916fh           ; done animating
	ld h,d
	ld l,e
	inc l
	ld bc,0082fh
	ld a,000h
	jp vdp_hmmm              ; blit the next open frame
l916fh:
	ld a,003h
	ld (0c5ach),a          ; hold "open" state
	ret
door_begin_open:
	ld hl,0c5ach
	ld a,(hl)
	dec a
	ret nz                 ; only when 0xC5AC == 1 (door armed)
	ld (hl),0ffh           ; -> 0xFF: begin opening
	jp door_anim_tick
; --- vendor_spawn - spawn a special object (vendor) into a 0xC5B5/0xC5C5 slot -----
;  On entry HL = object map position, B = subtype, C = slot/variant.  vendor_offer_match
;  classifies the subtype (via table 0x5B12) and returns the target slot in A
;  (1 -> 0xC5B5, else -> 0xC5C5), or NZ to reject.  The 16-byte struct is filled:
;    +0 = 1 (active)   +1/+2 = E,D (position)   +4 = B (subtype)   +5 = C (slot)
;    +7/+8 = 0xC70D (the position latched on entry).
;  This is NOT the white-key door; door coords live at 0xC5AD/0xC5AE from door_tbl.
vendor_spawn:
	ld (0c70dh),hl
	call vendor_offer_match
	ret nz
	ld hl,0c5b5h
	dec a
	jr nz,vendor_spawn_fill
	ld hl,0c5c5h
vendor_spawn_fill:
	ld (hl),001h           ; +0 = active
	inc l
	ld (hl),e              ; +1 = pos lo
	inc l
	ld (hl),d              ; +2 = pos hi
	inc l
	ld (hl),000h
	inc l
	ld (hl),b              ; +4 = subtype
	inc l
	ld (hl),c              ; +5 = slot/variant
	inc l
	ld (hl),000h
	inc l
	ld de,(0c70dh)
	ld (hl),d              ; +7 = latched pos hi
	inc l
	ld (hl),e              ; +8 = latched pos lo
	ret
vendor_offer_match:
	ld a,b
	exx
	ld hl,05b12h
	call ADD_HL_A
	ld c,(hl)
	ld b,002h
l91b4h:
	push bc
	ld a,002h
	sub b
	call vendor_de00_slot
	ld a,(hl)
	pop bc
	cp c
	jr z,l91c2h
	djnz l91b4h
l91c2h:
	ld a,b
	exx
	ret
vendor_tick:                       ; (seg2 0x91C5) 2 x C5B5/C5C5 vendor slots
	ld hl,0c5b5h
	ld bc,00200h
l91cbh:
	push bc
	push hl
	push hl
	pop ix
	ld a,(hl)
	or a
	call nz,vendor_slot_tick
	pop hl
	ld a,010h
	add a,l
	ld l,a
	pop bc
	inc c
	djnz l91cbh
	ret
vendor_slot_tick:
	inc l
	ld e,(hl)
	inc l
	ld d,(hl)
	dec l
	dec l
	and 00fh
	dec a
	jr z,l91f1h
	dec a
	jr z,l91f9h
	dec a
	jr z,l9230h
	ret
l91f1h:
	ld (ix+009h),c
	ld (hl),082h
	jp l9253h
l91f9h:
	inc l
	inc l
	inc l
	ld a,(hl)
	or a
	ret z
	ld (hl),000h
	inc l
	ld b,(hl)
	inc l
	ld c,(hl)
	inc l
	cp 0ffh
	jr z,l921ch
	call vendor_slot_ptr
	res 7,(hl)
	inc (hl)
	call vendor_pick_outcome
l9213h:
	ld (ix+00ah),020h
	ld (ix+000h),003h
	ret
l921ch:
	ld a,006h
	ld (0c70ch),a
	ld a,003h
	ld (0c70bh),a
	jr l9213h
vendor_slot_ptr:
	ld a,(ix+009h)
	call vendor_de00_slot
	inc hl
	ret
l9230h:
	dec (ix+00ah)
	ld a,(ix+00ah)
	push af
	rra
	ld a,002h              ; even frames: grey flash (C70B slot 2)
	jr c,l923fh
	ld a,(0c70bh)          ; odd frames: reaction colour
l923fh:
	push de
	call vendor_draw
	pop de
	pop af
	ret nz
	ld a,(0c70bh)
	call vendor_draw
	ld (ix+000h),082h
	jp vendor_outcome_dispatch
l9253h:
	push de
	ld hl,0e580h
	call l875eh
	pop de
	call vendor_slot_ptr
	bit 7,(hl)
	jr z,vendor_draw_idle
	dec (hl)
; vendor_draw_idle (0x9263): LMMM the white (slot 3) 32x32 at DE.
vendor_draw_idle:
	ld a,003h
; vendor_draw (0x9265): A = C70B 0..4 -> SX=A*32, SY=0xA0, 32x32 LMMM
; page-1 -> page-0 (colour 0 skip) at DE=(X,Y).
vendor_draw:
	rrca
	rrca
	rrca
	ld h,a
	ld l,0a0h
	ld a,048h
	ld bc,02020h
	jp vdp_lmmm
; vendor_redraw_all (0x9273): idle-blit every occupied C5B5/C5C5 slot
; (after a screen restore: pickup, F2 map close).
vendor_redraw_all:
	ld hl,0c5b5h
	ld bc,00200h
l9279h:
	push bc
	push hl
	push hl
	pop ix
	ld a,(hl)
	or a
	call nz,vendor_redraw
	pop hl
	ld a,010h
	add a,l
	ld l,a
	pop bc
	inc c
	djnz l9279h
	ret
vendor_redraw:
	inc l
	ld e,(hl)
	inc l
	ld d,(hl)
	jp vendor_draw_idle
vendor_force_hit:
	ld hl,0c5b5h
	ld b,002h
l9299h:
	push hl
	ld a,(hl)
	or a
	jr z,l92a6h
	add a,a
	jr nc,l92a6h
	inc l
	inc l
	inc l
	ld (hl),0ffh
l92a6h:
	pop hl
	ld a,010h
	add a,l
	ld l,a
	djnz l9299h
	ret
; --- vendor_outcome_dispatch (0x92AE) -----------------------------------------
; Execute the vendor's reaction to a whip hit, selected by state byte 0xC70C.
; DISPATCH_A jumps through the inlined word table that follows, indexed by 0xC70C:
;   0 -> 0x932E  register the hit (0xC40C=0xFF, latch vendor id -> 0xC703)
;   1 -> 0x933A  bump vendor "mood" 0xD012 up   (cap 3)
;   2 -> 0x9343  bump vendor "mood" 0xD012 down (floor 0)
;   3 -> 0x934B  GIVE +5 hearts   (add_hearts, sfx 0x0F)
;   4 -> 0x9355  TAKE -5 hearts   (spend_hearts, sfx 0x1D)
;   5 -> 0x934A  do NOTHING       (points at a bare `ret`)
;   6 -> 0x935F  LEAVE / vanish   (sfx 0x10, then awards +5000 via jp add_score_c0)
; This is why whipping the vendor sometimes gives hearts, sometimes takes them,
; sometimes does nothing, and eventually makes him leave.
vendor_outcome_dispatch:
	ld a,(0c70ch)
	call DISPATCH_A
vendor_outcome_tbl:
	defw vendor_hit_latch    ; 0  C40C=FF, latch vendor id
	defw vendor_mood_up      ; 1  D012++ (cap 3)
	defw vendor_mood_down    ; 2  D012-- (floor 0)
	defw vendor_give_hearts  ; 3  +5 hearts
	defw vendor_take_hearts  ; 4  -5 hearts
	defw vendor_noop         ; 5  ret (mood_down's ret)
	defw vendor_leave        ; 6  vanish, +5000
; --- vendor_pick_outcome (0x92C2) ---------------------------------------------
; Advance the vendor state machine to the next outcome after a whip hit.
; vendor_transition_tbl is a table of 8-byte rows; the row is chosen by ix+005 (vendor variant/
; phase), then indexed by the previous action (clamped to 0..7) to read the next
; state -> 0xC70C.  For "random" states >= 7 the low nibble of the R (refresh)
; register is used as a coin-flip to pick between two candidate states, which is
; the source of the run-to-run variation the player observes.  Finally the state
; is mapped through vendor_state_action_tbl (0x9327) into C70B (recolor slot 0..4).
vendor_pick_outcome:
	ld de,vendor_transition_tbl            ; vendor_transition_tbl (8-byte rows per ix+5)
	ld a,(ix+005h)
	add a,a
	add a,a
	add a,a
	call ADD_DE_A
	ld a,(hl)
	dec a
	cp 008h
	jr c,l92d6h
	ld a,007h
l92d6h:
	call ADD_DE_A
	ld a,(de)
	ld (0c70ch),a
	sub 007h
	jr c,l92f9h            ; states 0..6: use directly
	; states 7/8/9: coin-flip between two candidates via R register (RNG)
	ld hl,00305h
	jr z,l92efh
	dec a
	ld hl,00405h
	jr z,l92efh
	ld hl,00304h
l92efh:
	ld a,r
	rra
	ld a,h
	jr c,l92f6h
	ld a,l
l92f6h:
	ld (0c70ch),a
l92f9h:
	ld a,(0c70ch)
	ld hl,vendor_state_action_tbl
	call ADD_HL_A
	ld a,(hl)
	ld (0c70bh),a
	ret
; vendor_transition_tbl: 4 x 8-byte rows, values 0..9 (>=7 are RNG coin-flips)
vendor_transition_tbl:
	defb 000h,007h,007h,007h,008h,008h,005h,006h
	defb 000h,003h,003h,001h,005h,005h,005h,006h
	defb 009h,009h,000h,005h,005h,005h,002h,006h
	defb 005h,005h,005h,005h,000h,003h,005h,006h
vendor_state_action_tbl:       ; (0x9327) state 0..6 -> C70B recolor slot
	defb 001h,004h,004h,000h,000h,003h,003h  ; hit=red, mood=blue, hearts=magenta, idle=white
vendor_hit_latch:              ; (0x932E) register that the vendor was hit
	ld a,0ffh
	ld (0c40ch),a
	ld a,(ix+009h)
	ld (0c703h),a          ; latch vendor object id
	ret
vendor_mood_up:                ; (0x933A) raise D012 (cap 3)
	ld hl,0d012h
	ld a,(hl)
	cp 003h
	ret z
	inc (hl)
	ret
vendor_mood_down:              ; (0x9343) lower D012 (floor 0)
	ld hl,0d012h
	ld a,(hl)
	or a
	ret z
	dec (hl)
vendor_noop:                   ; (0x934A) outcome 5: do nothing
	ret
vendor_give_hearts:            ; (0x934B) +5 hearts (sfx 0x0F)
	ld a,00fh
	call play_sound
	ld b,005h
	jp add_hearts
vendor_take_hearts:            ; (0x9355) -5 hearts (sfx 0x1D)
	ld a,01dh
	call play_sound
	ld b,005h
	jp spend_hearts
; vendor_leave (0x935F): erase sprite, sfx 0x10, then +5000 (jp add_score_c0).
vendor_leave:
	ld (ix+000h),000h
	call vendor_restore_tiles
	ld hl,0e580h
	call tiles_to_map_4x4
	ld h,(ix+007h)
	ld l,(ix+008h)
	ld (hl),000h
	ld a,010h
	call play_sound
	ld de,05000h
	jp add_score_c0        ; add_score += 5000 (departure bonus)
vendor_restore_tiles:
	ld e,(ix+001h)
	ld d,(ix+002h)
	ld c,(ix+009h)
	ld hl,0e580h
	jp tiles_blit_4x4
; --- vendor_make_offer (0x938E) -----------------------------------------------
; Arm a sale: pick the item + price (vendor_set_offer_item -> 0xC708 item, 0xC707 price),
; start the 0xC706 offer countdown (0x14 = 20 ticks), play the "offer" jingle
; (sfx 0x19) and draw the price/item bubble (l939eh).  Called from the resident
; vendor state machine (seg0 l4411h) while seg2 is paged in.
vendor_make_offer:
	call vendor_set_offer_item
	ld a,014h
	ld (0c706h),a          ; offer timer = 0x14; decremented in vendor_purchase_tick
	ld a,019h
	call play_sound
	jp l939eh
l939eh:
	ld a,(0c703h)
	ld hl,0c5b5h
	add a,a
	add a,a
	add a,a
	add a,a
	call ADD_HL_A
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,d
	cp 080h
	jr nc,l93b8h
	sub 010h
	jr l93bah
l93b8h:
	sub 020h
l93bah:
	ld h,a
	ld a,e
	sub 018h
	ld l,a
	ld (0c704h),hl
	ld de,0b080h
	ld bc,05020h
	ld a,004h
	push hl
	push bc
	call vdp_hmmm
	pop bc
	pop hl
	call panel_frame
	ld bc,03806h
	call vendor_bubble_xy
	ld hl,01314h
	ex de,hl
	ld c,00eh
	call vdp_box
l93e3h:
	ld bc,00804h
	ld hl,vendor_offer_str0
	call vendor_glyphs
	ld bc,00810h
	ld hl,vendor_offer_str1
	call vendor_glyphs
	call vendor_price_draw
	ld bc,03908h
	call vendor_bubble_xy
	ld a,(0c708h)
	dec a
	call bonus_icon_blit
	ret
; --- vendor_set_offer_item (0x9406) -------------------------------------------
; Choose the item to sell (-> 0xC708) then look up its price in the price table.
vendor_set_offer_item:
	call vendor_de00_this
	ld a,(hl)
	ld (0c708h),a          ; offered item = bonus id (e.g. 0x1B = knife)
	inc hl
	set 7,(hl)
	ld hl,vendor_price_tbl            ; vendor_price_tbl (9 rows of 4: id,normal,half,double)
	ld b,009h
l9415h:
	cp (hl)
	inc hl
	jr z,vendor_select_price
	inc hl
	inc hl
	inc hl
	djnz l9415h
	ret
; vendor_select_price: high bits of 0xC702 (bible flags) pick the price variant.
;   no bible  -> +1 normal price     (knife = 0x50 = 50 hearts, BCD)
;   bit7 set  -> +2 halved  (white bible)   (knife = 0x30 = 30)
;   bit6 set  -> +3 doubled (black bible)    (knife = 0x90 = 90)
vendor_select_price:
	ld a,(0c702h)          ; bible price-modifier flags
	add a,a
	jr c,l9429h
	add a,a
	jr nc,l942ah
	inc hl
l9429h:
	inc hl
l942ah:
	ld a,(hl)
	ld (0c707h),a          ; price in hearts (BCD)
	ret
; vendor_price_tbl: 9 x { item id, normal, halved(white bible), doubled(black bible) }
vendor_price_tbl:
	defb 00eh,020h,015h,060h  ; candle
	defb 012h,030h,020h,060h  ; lockpick
	defb 003h,020h,010h,060h  ; red shield
	defb 004h,020h,010h,080h  ; yellow shield
	defb 00ah,040h,020h,080h  ; hourglass
	defb 016h,040h,015h,080h  ; potion
	defb 01eh,030h,010h,050h  ; holy water
	defb 01dh,020h,010h,080h  ; cross
	defb 01bh,050h,030h,090h  ; knife
vendor_de00_this:
	ld a,(0c703h)
vendor_de00_slot:
	push af
	ld bc,00000h
	ld a,(0d000h)
	or a
l945eh:
	jr z,l9468h
	dec a
	ld hl,vendor_de00_ofs
	call ADD_HL_A
	ld c,(hl)
l9468h:
	ld hl,0de00h
	add hl,bc
	ld a,(0d001h)
	add a,a
	add a,a
	call ADD_HL_A
	pop af
	or a
	ret z
	inc hl
	inc hl
	ret
vendor_de00_ofs:
	defb 000h,040h,080h,000h,040h,080h  ; stages 1-18: DE00 room-group base
	defb 000h,040h,080h,000h,040h,080h
	defb 000h,040h,080h,000h,040h,080h
vendor_offer_str0:
	defb 03fh,03bh,000h,04ch,0ffh
vendor_offer_str1:
	defb 050h,04dh,000h,000h,04eh,04fh,0ffh
vendor_price_draw:
	ld bc,01810h
l949bh:
	call vendor_bubble_xy
	ld hl,0c707h
	ld b,001h
	jp hud_bcd_draw
vendor_glyphs:
	call vendor_bubble_xy
l94a9h:
	ld a,(hl)
	inc a
	ret z
	dec a
	call hud_glyph_blit
	call blit_advance_x
	inc hl
	jr l94a9h
vendor_bubble_xy:
	ld de,(0c704h)
	ld a,d
	add a,b
	ld d,a
	ld a,e
	add a,c
	ld e,a
	ret
; --- vendor_purchase_tick (0x94C1) --------------------------------------------
; Runs while an offer is on screen.  Every 0x20 frames tick down the 0xC706 offer
; timer; when it hits 0 the offer is withdrawn (vendor_offer_withdraw).  Otherwise poll the
; buy/refuse buttons: nothing pressed -> keep waiting (ret 0xFF, vendor_offer_pending); SHIFT/
; refuse -> withdraw (vendor_offer_withdraw, sfx 0x02); SPACE/confirm -> buy only if Simon has
; enough hearts (0xC417 >= price 0xC707): deduct price (spend_hearts) and grant
; the item (collect_bonus / collect_bonus_apply), sfx 0x12.
vendor_purchase_tick:
	ld a,(0c003h)
	and 01fh
	jr nz,l94ceh
	ld hl,0c706h           ; offer countdown
	dec (hl)
	jr z,vendor_offer_withdraw            ; expired -> withdraw offer
l94ceh:
	call vendor_read_buttons         ; read confirm/refuse buttons (edge-detected)
	jr z,vendor_offer_pending            ; nothing pressed -> keep offer open
	rra
	jr nc,vendor_offer_withdraw           ; refuse (SHIFT / no confirm bit) -> withdraw
	ld a,(0c707h)
	ld b,a
	ld a,(0c417h)          ; Simon's hearts
	cp b
	jr c,vendor_offer_withdraw            ; can't afford -> withdraw
	ld a,(0c704h)
	cp 020h
	push af
	call c,vendor_offer_wipe
	call spend_hearts      ; pay the price in hearts
	ld a,(0c708h)
	call collect_bonus_apply         ; collect_bonus(item) -> give the purchased item
	pop af
	call c,l939eh
	ld a,012h
	call play_sound            ; purchase-confirmed jingle
	call vendor_de00_this
	inc hl
	res 7,(hl)
	xor a
	ret
vendor_offer_withdraw:                        ; offer declined / expired / unaffordable
	ld a,002h
	call play_sound
	xor a
	ret
vendor_offer_pending:                        ; no button this frame -> leave offer pending
	ld a,0ffh
	or a
	ret
	call vendor_offer_wipe
	jp candle_outlines_if
vendor_offer_wipe:
	push bc
	ld hl,0b080h
	ld de,(0c704h)
	ld bc,05020h
	ld a,001h
	call vdp_hmmm
	pop bc
	ret
; --- vendor_read_buttons (0x9526) ---------------------------------------------
; Build a "newly pressed" bitmask of the confirm/refuse controls and return it.
; Reads the two joystick triggers (PSG reg 0x0E bits 0x30) plus keyboard SPACE
; (row 8) and SHIFT (row 6) via SNSMAT.  0xC709 holds last frame's state so the
; final `xor c / and (hl)` yields only the freshly-pressed edges.  In
; vendor_purchase_tick bit0 (SPACE/trigger) = confirm/buy, the others = refuse.
vendor_read_buttons:
	ld e,08fh
	ld a,00fh
	call WRTPSG
	ld a,00eh
	di
	call RDPSG              ; PSG port B = joystick
	ei
	cpl
	and 030h               ; two fire buttons
	rrca
	rrca
	rrca
	rrca
	ld d,a
	ld a,006h
	call read_kbd_matrix_bit          ; keyboard row 6 -> SHIFT (refuse)
	add a,a
	or d
	ld d,a
	ld a,008h
	call read_kbd_matrix_bit          ; keyboard row 8 -> SPACE (confirm)
	or d
	ld hl,0c709h            ; previous button state (for edge detection)
	ld c,(hl)
	ld (hl),a
	xor c
	and (hl)
	ret
read_kbd_matrix_bit:                     ; read one keyboard-matrix bit (row in A) -> 0/1
	call SNSMAT
	cpl
	and 001h
	ret
; --- minimap_driver (0x9559) - the F2 "world map" feature.  Called every frame;
;     0xCF38 is the map-screen state (0 = playing, 1 = build, 2 = displayed).
;     The map item (picked up in-stage) sets 0xC701 bit7 and 0xC70F = 3 uses;
;     each F2 press while displayed<->hidden consumes one use.  F-key edges come
;     from 0xC00B (bit1 = F2 just pressed; see seg0 read_fkeys 0x4BFB).
minimap_driver:
	ld a,(0c002h)          ; input-enable flags...
	and 040h               ; ...bit6 = input allowed?
	ret z
	ld a,(0ce00h)          ; suppress while a transition/cutscene is active
	and a
	ret nz
	ld a,(0cf38h)          ; map-screen state
	dec a
	jr z,map_state_build            ; state 1 -> build the map (draw every room cell)
	dec a
	jr z,map_state_idle            ; state 2 -> displayed: wait for F2 to close it
	ld a,(0c00bh)          ; state 0 (playing): F-key edges
	bit 1,a                ; F2 just pressed?
	ret z
	ld a,(0c701h)          ; inventory flags...
	add a,a               ; ...bit7 -> carry = map item held?
	ret nc                 ; no map item -> ignore F2
	ld hl,0c70fh           ; remaining map uses (seeded to 3 on pickup)
	ld a,(hl)
	and a
	ret z                  ; none left -> ignore
	dec (hl)               ; spend one use
	jr nz,l9589h
	ld hl,0c701h           ; last use spent...
	res 7,(hl)             ; ...clear the map-held flag
	call hud_bonus_refresh
l9589h:
	call 04805h            ; switch to the map screen (VDP page/setup)
	ld hl,00020h
	ld bc,000b4h
	xor a
	ld d,000h
	call vdp_hmmv
	ld hl,01830h
	ld bc,0d07eh
	ld a,033h
	ld d,000h
	call vdp_hmmv
	ld a,019h
	call play_sound
map_state_advance:
	ld hl,0cf38h           ; advance map-screen state (0->1->2)
	inc (hl)
	ret
map_state_build:                    ; state 1: build the map, then advance to "displayed"
	call minimap_build         ; draw every room's cell (loops over all rooms)
	call minimap_blit_simon
	call minimap_palette
	jr map_state_advance
map_state_idle:                    ; state 2 (displayed): F2 again closes the map
	ld a,(0c00bh)
	bit 1,a                ; F2 pressed?
	ret z
	call playfield_draw            ; restore the play screen and resume
	call spike_bars_restore
	call door_begin_open
	call vendor_redraw_all
	call candle_outlines_if
	call 04810h
	xor a
	ld (0cf38h),a          ; back to state 0 (playing)
	ret
; --- minimap_build - build the whole minimap: loop room index 0xCFFD = 0..N-1,
;     drawing each room's cell.  minimap_room_pos places the cell; the loop ends when the
;     index reaches the per-stage room count in minimap_room_count (minimap_room_count[stage]).
minimap_build:
	xor a
	ld (0cffdh),a          ; room index = 0
l95dbh:
	call minimap_room_build
	call minimap_room_pos         ; look up + set this room's minimap cell position
	call minimap_pack
	call minimap_blit_room
	ld a,(0cffdh)
	inc a
	ld (0cffdh),a          ; ++room index
	ld c,a
	ld a,(0d000h)          ; stage
	ld hl,minimap_room_count           ; minimap_room_count[stage]
	call ADD_HL_A
	ld a,c
	cp (hl)
	jr nz,l95dbh           ; loop until all rooms drawn
	ret
; minimap_room_count (seg2 0x95FD): rooms per stage 0..18.
minimap_room_count:
	defb 003h,008h,006h,006h,006h,006h,006h,009h,008h
	defb 009h,009h,006h,00ch,00ch,008h,00ah,00ah,00ch,00ah
minimap_room_build:
	ld hl,0e800h
	ld a,(0d000h)
	ld b,a
	ld a,(0cffdh)
	ld c,a
	call room_map_build
	ld a,(0cffdh)
	call scenery_room_ptr_a
	ld de,0eb00h
	call scenery_slots_fill
	ld ix,0eb00h
	ld a,(0d001h)
	ld hl,0cffdh
	cp (hl)
	jr nz,l963bh
	ld ix,0c470h
l963bh:
	ld b,008h
l963dh:
	ld a,(ix+000h)
	and a
	jr z,l964bh
	ld a,(ix+004h)
	cp 003h
	call z,minimap_stamp_block
l964bh:
	ld de,00010h
	add ix,de
	djnz l963dh
	ret
minimap_stamp_block:
	ld a,(ix+001h)
	sub 010h
	ld h,(ix+002h)
	rra
	rra
	rra
	rra
	rr h
	rra
	rr h
	rra
	rr h
	ld l,h
	and 003h
	add a,0e8h
	ld h,a
	ld c,004h
l966fh:
	ld a,001h
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	ld a,01dh
	call ADD_HL_A
	dec c
	jr nz,l966fh
	ret
; --- minimap_room_pos - MINIMAP ROOM POSITION LOOKUP.  This is the authoritative room
;     geography: rooms are placed on the F2 map at HAND-AUTHORED cells, not derived
;     from the room-connectivity graph (which is a navigation graph with wrap/portal
;     edges).  Per stage 0xD000, minimap_stage_ptr[stage] points to an array of one-byte POSITION
;     CODES (one per room 0xCFFD); minimap_coord_tbl (0x975E) maps a code to a packed
;     screen coord (high byte X = 0x20+0x20*col over 6 columns, low byte Y = 0x38+
;     0x15*row over 5 rows).  Result stored at 0xCFF2 = this room's draw position.
;     Decoded for all 19 stages by tools/roomperm.py (its layout() reads this table).
minimap_room_pos:
	ld a,(0d000h)          ; stage
	ld de,minimap_stage_ptr           ; minimap_stage_ptr[]
	call lookup_word_tbl   ; de = this stage's position-code array
	ld a,(0cffdh)          ; room index
	call ADD_DE_A
	ld a,(de)              ; a = room's position code
	ld de,0975eh           ; minimap_coord_tbl
	call lookup_word_tbl   ; de = packed (X,Y) screen coord for that code
	ld (0cff2h),de         ; store as this room's minimap draw position
	ret
; minimap_stage_ptr: word[stage] -> per-room position-code array (see minimap_room_pos).
; z80dasm shows the following as instructions; it is DATA and never executed.
minimap_stage_ptr:
	jp nz,0c596h
	sub (hl)
	call 0d396h
	sub (hl)
	exx
	sub (hl)
	rst 18h
	sub (hl)
	push hl
	sub (hl)
	ex de,hl
	sub (hl)
	call p,0fc96h
	sub (hl)
	dec b
	sub a
	ld c,097h
	inc d
	sub a
	jr nz,$-103
	inc l
	sub a
	inc (hl)
	sub a
	ld a,097h
	ld c,b
	sub a
	ld d,h
	sub a
	dec c
	ld c,00fh
	dec c
	ld c,00fh
	djnz l96d1h
	ex af,af'
	add hl,bc
	ld a,(bc)
	ld c,00fh
	ex af,af'
	add hl,bc
l96d1h:
	inc d
	dec d
	rlca
	ex af,af'
	add hl,bc
	ld a,(bc)
	dec c
	ld c,00dh
	ld c,00fh
	rlca
	ex af,af'
	add hl,bc
	rrca
	ld c,00dh
	add hl,bc
	ex af,af'
	rlca
	rrca
l96e6h:
	ld c,00dh
	add hl,bc
	ex af,af'
	rlca
	dec d
	inc d
	inc de
	rrca
	ld c,00dh
	add hl,bc
	ex af,af'
	rlca
	inc c
	dec c
	ld c,00fh
	djnz l9702h
	add hl,bc
	ld a,(bc)
	inc c
	dec c
	ld c,00fh
	djnz $+19
l9702h:
	dec bc
	ld d,017h
	inc c
	dec c
	ld c,00fh
	djnz l971ch
	rlca
	ex af,af'
	dec bc
	inc c
	dec c
	ld c,00fh
	djnz $+19
	rlca
	ex af,af'
	add hl,bc
	dec c
	ld c,00fh
	djnz l9730h
l971ch:
	dec d
l971dh:
	add hl,de
	ld a,(de)
	dec de
	rlca
	ex af,af'
	add hl,bc
	ld bc,00302h
	inc b
	rrca
	inc d
	dec d
l972ah:
	ld d,01ch
	djnz l973dh
	ld c,00ah
l9730h:
	add hl,bc
	ex af,af'
	rlca
	ld b,015h
	inc d
	rrca
	ld c,009h
	ex af,af'
	inc b
	inc bc
	ld (bc),a
l973dh:
	ld bc,00a0bh
	add hl,bc
	ex af,af'
	rlca
	ld b,011h
	djnz l9756h
	ld c,016h
	dec d
	inc d
	djnz l975ch
	ld c,008h
	rlca
	ld b,002h
	ld bc,01c00h
	dec de
l9756h:
	ld a,(de)
	inc d
	rrca
	ld c,009h
	inc bc
l975ch:
	ld (bc),a
	ld bc,02038h
	jr c,$+66
	jr c,l97c4h
	jr c,l96e6h
	jr c,$-94
	jr c,l972ah
	ld c,l
	jr nz,$+79
	ld b,b
	ld c,l
	ld h,b
	ld c,l
	add a,b
	ld c,l
	and b
	ld c,l
	ret nz
	ld h,d
	jr nz,$+100
	ld b,b
	ld h,d
	ld h,b
	ld h,d
	add a,b
	ld h,d
	and b
	ld h,d
	ret nz
	ld (hl),a
	jr nz,l97fch
	ld b,b
	ld (hl),a
	ld h,b
	ld (hl),a
	add a,b
	ld (hl),a
	and b
	ld (hl),a
	ret nz
	adc a,h
	jr nz,l971dh
	ld b,b
	adc a,h
	ld h,b
	adc a,h
	add a,b
	adc a,h
	and b
	adc a,h
	ret nz
minimap_pack:
	ld de,0e840h
	ld hl,0eb00h
	ld bc,002c0h
l97a3h:
	call minimap_tile_class
	call minimap_plot_nibble
	bit 0,c
	jr z,l97aeh
	inc hl
l97aeh:
	inc de
	dec bc
	ld a,c
	or b
	jr nz,l97a3h
	ret
minimap_tile_class:
	ld a,(de)
	exx
	cp 00eh
	jr nc,l97d7h           ; id >= 0x0E: air / high scenery, skip
	ld hl,minimap_class_tbl
	ld e,a
	ld d,000h
	add hl,de
	ld a,(hl)
	ld c,a
l97c4h:
	dec a
	jp m,l97d7h            ; class 0: skip
	jr z,l97dah            ; class 1: paint 0x0E
	dec a
	jr z,l97deh            ; class 2: paint 0x0E (same colour as 1)
	ld a,(0d002h)          ; class 3/4: hub-gated
	cp 005h
	jr z,l97e9h            ; hub 5 (s16-18): 3 and 4
	and a
	jr z,l97e2h            ; hub 0 (s0-3): class 3 only
l97d7h:
	xor a
	exx
	ret
l97dah:
	ld a,00eh              ; white (MSX colour 14)
	exx
	ret
l97deh:
	ld a,00eh
	exx
	ret
l97e2h:
	ld a,c
	cp 003h
	jr z,l97dah            ; hub 0: also paint tile 0x09
	jr l97d7h
l97e9h:
	ld a,c
	sub 003h
	jr z,l97dah            ; hub 5: class 3 (0x09)
	dec a
	jr z,l97dah            ; hub 5: class 4 (0x05-0x08; structural there)
	jr l97d7h
; minimap_class_tbl (seg2 0x97F3): tile id 0..0x0D -> paint class for F2.
; 0 skip; 1/2 always white (same colour; 1 vs 2 unused); 3 = 0x09 on hub 0
; and 5; 4 = 0x05-0x08 on hub 5 only.  Not tile_is_solid; s18r9 has no extra
; override (hub 5 paints 01-0D, including the decorative columns).
minimap_class_tbl:
	defb 000h,001h,001h,002h,002h,004h,004h,004h  ; 00 skip, 01-02, 03-04, 05-08
	defb 004h
l97fch:                        ; 0x97FC: also a fake-code jr target in minimap_coord_tbl
	defb 003h,001h,001h,002h,002h  ; 09, 0A-0B, 0C-0D
minimap_plot_nibble:
	bit 0,c
	jr z,l9808h
	or (hl)
	ld (hl),a
	ret
l9808h:
	add a,a
	add a,a
	add a,a
	add a,a
	ld (hl),a
	ret
minimap_blit_room:
	ld de,(0cff2h)
	ld hl,0eb00h
	ld bc,02016h
	xor a
	jp vdp_hmmc
minimap_blit_simon:
	ld a,(0d001h)
	ld (0cffdh),a
	call minimap_room_pos
	ld hl,(0cff2h)
	ld a,(0c425h)
	sub 040h
	call c,minimap_simon_y_adj
	rra
	rra
	rra
	and 01fh
	add a,l
	ld e,a
	ld a,(0c427h)
	rra
	rra
	rra
	and 01fh
	add a,h
	ld d,a
	ld bc,00404h
	ld hl,minimap_simon_mark
	xor a
	jp vdp_hmmc
minimap_simon_y_adj:
	ex af,af'
	ld a,l
	sub 020h
	ld l,a
	ex af,af'
	ret
minimap_simon_mark:
	defb 008h,080h,088h,088h,088h,088h,008h,080h
minimap_palette:
	ld a,(0d000h)
	ld c,a
	add a,a
	add a,c
	ld hl,minimap_stage_gfx
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	bit 0,(hl)
	ld hl,minimap_icon_a
	jr z,minimap_icon_go
	ld hl,minimap_icon_b
minimap_icon_go:
	ld bc,00807h
	xor a
	jp vdp_hmmc
minimap_icon_a:
	defb 000h,008h,000h,000h,000h,008h,080h,000h
	defb 088h,088h,088h,000h,088h,088h,088h,080h
	defb 088h,088h,088h,000h,000h,008h,080h,000h
	defb 000h,008h,000h,000h
minimap_icon_b:
	defb 000h,000h,080h,000h,000h,008h,080h,000h
	defb 000h,088h,088h,088h,008h,088h,088h,088h
	defb 000h,088h,088h,088h,000h,008h,080h,000h
	defb 000h,000h,080h,000h
; 19 x {dest DE, flags}: bit0 picks icon A/B. Indexed by stage.
minimap_stage_gfx:
	defb 06ch,092h,000h
	defb 04eh,0b4h,000h
	defb 063h,094h,000h
	defb 06eh,054h,000h
	defb 04eh,045h,001h
	defb 052h,043h,001h
	defb 052h,065h,001h
	defb 054h,094h,000h
	defb 050h,0b4h,000h
	defb 082h,0c3h,001h
	defb 058h,0d4h,000h
	defb 06dh,0d4h,000h
	defb 06dh,094h,000h
	defb 082h,063h,001h
	defb 058h,024h,001h
	defb 043h,065h,001h
	defb 050h,025h,001h
	defb 03ah,025h,001h
	defb 043h,065h,001h
actors_tick:                       ; (seg2 0x98EC) room_spawner + C800 if D010==0
	ld a,(0d010h)
	and a                  ; 0==normal play
	call z,room_spawner    ; per-frame enemy spawner (seg0 0x5EBF), skipped mid-transition
c800_tick:                         ; (seg2 0x98F3) tick all 7 C800 actor slots
	ld ix,0c800h
	ld b,007h
l98f9h:
	ld a,(ix+000h)
	and a
	jr z,l990fh
	push bc
	call actor_freeze_check
	jr c,l990bh
	call actor_type_tick
	call actor_integrate
l990bh:
	call actor_cull_offscreen
	pop bc
l990fh:
	ld de,00080h
	add ix,de
	djnz l98f9h
	ret
shot_sat_build:                    ; (seg2 0x9917) shot shape streams -> actor SAT
	ld ix,0d700h
	ld b,008h
	jr l9925h
c800_sat_build:                    ; (seg2 0x991F) C800 shape streams -> actor SAT
	ld ix,0c800h
	ld b,007h
l9925h:
	push bc
	ld a,(ix+000h)
	and a
	call nz,actor_sat_build
	ld de,00080h
	add ix,de
	pop bc
	djnz l9925h
	ret
; actor_freeze_check (seg2 0x9936) - C if this actor should skip type tick
;  and integrate: D010 bit 0 is set during Simon's whip, and +7E != 0
;  (spawn default). Flames/pickups clear +7E so they keep animating.
actor_freeze_check:
	ld a,(0d010h)
	and a
	ret z
	ld a,(ix+07eh)
	and a
	ret z
	scf
	ret
; actor_type_tick (seg2 0x9942) - per-frame C800 tick. DISPATCH_A on type-1.
; Separate from spawn-time entity_tbl: most entries are a later instruction of
; the same enemy_*_tick (skip spawn pose / splash / fly-in). Types 0x17 and
; 0x1D are `ret` (no per-frame work). 0x1F shares type 4; 0x21 shares 2/3;
; 0x23 shares type 13 (hunchback). 0x26 is actor_reward_go; 0x27-0x2A are
; intro SAT. 0x2C is dracula_bat_go; 0x2D is dracula_head_go; 0x2E is ret.
actor_type_tick:
	ld a,(ix+000h)
	dec a
	call DISPATCH_A
actor_tick_tbl:
	defw enemy_zombie_go    ; 1
	defw merman_go          ; 2
	defw merman_go          ; 3  merman_red
	defw hanging_bat_go     ; 4  past fly-in
	defw enemy_dog_go       ; 5
	defw enemy_pikeman_go   ; 6
	defw enemy_flying_skull_go ; 7
	defw enemy_ghost_head_go ; 8
	defw enemy_red_skeleton_go ; 9
	defw enemy_skull_pile_go ; 10
	defw white_skel_go      ; 11
	defw enemy_raven_go     ; 12
	defw hunchback_go       ; 13
	defw enemy_bone_dragon_go ; 14
	defw enemy_roc_go       ; 15
	defw enemy_axe_knight_go ; 16
	defw enemy_dracula_go   ; 17
	defw enemy_giant_bat_go ; 18
	defw enemy_medusa_go    ; 19
	defw enemy_mummy_go     ; 20
	defw enemy_frankenstein_go ; 21
	defw enemy_grim_reaper_go ; 22
	defw tick_nop           ; 23 ret (no SAT; actor_sat_build skips 0x17)
	defw igor_go            ; 24
	defw enemy_blob_go      ; 25 type 0x19 (same tick; not in hatch table)
	defw enemy_blob_go      ; 26 actor_blob_blue
	defw enemy_blob_go      ; 27 actor_blob_red
	defw enemy_blob_go      ; 28 actor_blob_white
	defw tick_nop_seg2      ; 29 ret
	defw flame_tick         ; 30 actor_flame
	defw hanging_bat_go     ; 31 placed_bat
	defw merman_splash_go   ; 32
	defw merman_go          ; 33 placed_merman
	defw actor_orb_go       ; 34
	defw hunchback_go       ; 35 roc_drop
	defw actor_pickup_go    ; 36
	defw tick_nop_seg2      ; 37 type 0x25 unused
	defw actor_reward_go    ; 38 actor_reward
	defw intro_sky_go       ; 39 actor_intro_sky
	defw intro_sky_ab_go    ; 40 actor_intro_sky_a
	defw intro_sky_ab_go    ; 41 actor_intro_sky_b
	defw intro_simon_go     ; 42 actor_intro_simon
	defw tick_nop_seg2      ; 43 type 0x2B unused
	defw dracula_bat_go     ; 44 actor_dracula_bat
	defw dracula_head_go    ; 45 actor_dracula_head
	defw dracula_chunk_go   ; 46 actor_dracula_chunk
tick_nop_seg2:
	ret
actors_rearm_hittable:         ; (0x99A6) if actor +0E bit2, set bit0 (C800 then shots)
	ld de,00080h
	ld hl,0c80eh
	ld b,007h
	call hittable_rearm_scan
	ld hl,0d70eh
	ld b,008h
hittable_rearm_scan:               ; +0E bit2 -> set bit0; B slots, stride DE
	bit 2,(hl)
	jr z,l99bch
	set 0,(hl)
l99bch:
	add hl,de
	djnz hittable_rearm_scan
	ret
; ---------------------------------------------------------------------------
;  actor_integrate (seg2 0x99C0) - advance one actor by its velocity.  Skips
;  dead slots (+0x06 == 0).  Adds the 16-bit Y velocity (+0x07/+0x08) to the Y
;  position (+0x02/+0x03) and the X velocity (+0x09/+0x0A) to the X position
;  (+0x04/+0x05).  This is the physics step paired with the velocity helpers in
;  seg3 (actor_set_xvel / actor_set_yvel / actor_add_*).
; ---------------------------------------------------------------------------
actor_integrate:
	ld a,(ix+006h)
	and a
	ret z                   ; slot dead -> nothing to do
	ld e,(ix+007h)          ; DE = Y velocity
	ld d,(ix+008h)
	ld l,(ix+002h)          ; HL = Y position
	ld h,(ix+003h)
	add hl,de               ; Ypos += Yvel
	ld (ix+002h),l
	ld (ix+003h),h
	ld e,(ix+009h)          ; DE = X velocity
	ld d,(ix+00ah)
	ld l,(ix+004h)          ; HL = X position
	ld h,(ix+005h)
	add hl,de               ; Xpos += Xvel
	ld (ix+004h),l
	ld (ix+005h),h
	ret

; ---------------------------------------------------------------------------
;  actor_cull_offscreen (seg2 0x99EC) - free the actor if its pixel position has
;  left the play area: Y (+0x03) >= 0xE4, or X (+0x05) >= 0xF1 or < 0x07.
;  Falls through into actor_free.
; ---------------------------------------------------------------------------
actor_cull_offscreen:
	ld a,(ix+003h)
	cp 0e4h
	jr nc,actor_free        ; Y off the bottom
	ld a,(ix+005h)
	cp 0f1h
	jr nc,actor_free        ; X off the right
	cp 007h
	ret nc
; actor_free (seg2 0x99FD) - clear the actor slot (+0x00 type, +0x0E) and
;  hide every hardware sprite it claimed (SAT sub-block at slot|0x20: count
;  then 5-byte cells; each cell+0 is a D638 index, written Y=0xE0).
actor_free:
	xor a
	ld (ix+000h),a
	ld (ix+00eh),a
	push ix
	pop hl
	set 5,l
	ld c,(hl)
	ld a,c
	and a
	ret z
	inc l
l9a0eh:
	ld a,(hl)
	ld de,0d638h
	add a,a
	add a,a
	add a,e
	ld e,a
	ld a,0e0h
	ld (de),a
	ld a,l
	add a,005h
	ld l,a
	dec c
	jr nz,l9a0eh
	ret
shot_death_flame:
	call actor_free
	ld c,(ix+003h)
	ld b,(ix+005h)
	ld hl,00000h
	ld e,l
	ld d,h
	ld a,0ffh
	push ix
	call shot_spawn
	ld (ix+01fh),000h
	ld (ix+07eh),000h
	pop ix
	ret
actor_cull:                    ; (0x9A41) CFFF=1: free, skip random drops
	ld a,001h
	jr l9a46h
actor_kill:                    ; (0x9A45) CFFF=0: free and maybe drop
	xor a
l9a46h:
	ld (0cfffh),a
	push ix
	call actor_kill_go
	pop ix
	ret
actor_kill_go:
	call actor_kill_special
	ret c
	call actor_free
	call kill_drop_roll
	ret c
	call kill_drop_pos
flame_spawn:
	ld c,actor_flame
	push ix
	push bc
	call spawn_actor
	pop bc
	ld (ix+01fh),b
	pop ix
	ld hl,0ce08h
	inc (hl)
	ret
actor_kill_special:
	ld a,(ix+000h)
	ld (0cff0h),a
	cp 022h
	jp z,l9a94h
	cp 024h
	jr z,l9a9eh
	cp 026h
	jr z,l9a99h
	cp 011h
	jp z,l9aaah
	cp 009h
	jr z,l9ab0h
	cp 018h
	jr z,l9abah
	xor a
	ret
l9a94h:
	call actor_free
	scf
	ret
l9a99h:
	ld a,(ix+01fh)
	jr l9aa0h
l9a9eh:
	ld a,001h
l9aa0h:
	push af
	call actor_free
	pop af
	call collect_bonus      ; type 0x24 heart touched in mid-air -> +1 heart
	scf
	ret
l9aaah:
	ld (ix+001h),008h
	scf
	ret
l9ab0h:
	ld a,(0cfffh)
	and a
	ret nz
	call 0b04fh
	scf
	ret
l9abah:
	ld a,(0ce0bh)
	and a
	ret nz
	ld (ix+010h),008h
	scf
	ret
kill_drop_roll:
	ld b,000h
	ld a,(0ce00h)
	and a
	ret nz
	ld a,(0cff0h)
	cp 00eh
	jr z,l9afah
	ld a,(0cfffh)
	and a
	ret nz
	ld a,(ix+01fh)
	ld c,a
	and a
	jp nz,l9b1ah
	ld hl,0cf40h
	inc (hl)
	ld a,(hl)
	and 01fh
	ld c,013h
	jp z,l9b1ah
	ld a,r
	and 03fh
	ld c,002h
	jr z,l9b1ah
	and 003h
	ret nz
	ld b,001h
	ret
l9afah:
	ld e,(ix+003h)
	ld d,(ix+005h)
	ld b,004h
l9b02h:
	push bc
	push de
	ld b,001h
	ld a,(0cfffh)
	and a
	jr z,l9b0dh
	dec b
l9b0dh:
	call flame_spawn
	pop de
	pop bc
	ld a,d
	add a,010h
	ld d,a
	djnz l9b02h
	scf
	ret
l9b1ah:
	push bc
	call kill_drop_pos
	ld c,actor_reward
	call spawn_actor
	pop bc
	ld (ix+01fh),c         ; +0x1F = bonus id (drop gate for the pickup)
	scf
	ret
kill_drop_pos:
	ld a,(0cff0h)
	ld hl,kill_drop_dy
	call ADD_HL_A
	ld a,(ix+003h)
	sub (hl)
	ld e,a
	ld d,(ix+005h)
kill_drop_dy:
	; type 0's 0xC9 is also the `ret` that exits kill_drop_pos
	defb 0c9h,010h,010h,010h,000h,000h,010h,000h,000h,010h,010h,010h,000h,000h,000h,018h
	defb 010h,020h,018h,018h,018h,018h,018h,000h,000h,000h,000h,000h,000h,000h,000h,000h
	defb 000h,010h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h
; ---------------------------------------------------------------------------
;  flame_init (seg2 0x9B67) - initialise a "destruction flame" effect actor
;  (the flame that whipped objects/enemies turn into before vanishing).
;  Seeds the flame sprite frame and its lifetime countdown.
; ---------------------------------------------------------------------------
flame_init:
	ld (ix+00bh),085h       ; +0x0B anim frame = flame sprite 0x85
	ld (ix+00ch),010h       ; +0x0C lifetime timer = 0x10
	ld (ix+00eh),000h       ; +0x0E = 0
	ld (ix+07eh),000h       ; +0x7E = 0
	ret

; ---------------------------------------------------------------------------
;  flame_tick (seg2 0x9B78) - per-frame update of the destruction flame.  It
;  flickers the flame sprite (0x85 <-> 0x86 on bit 2 of the countdown) while the
;  lifetime timer (+0x0C) runs down.  When it expires, if the drop gate (+0x1F)
;  is set it spawns the settled pickup actor (type 0x24) at the flame's position
;  - runtime-confirmed as the candle -> flame -> small-heart(0x24) chain.
; ---------------------------------------------------------------------------
flame_tick:
	ld a,(ix+000h)
	ld (0cff0h),a           ; stash actor type in scratch 0xCFF0
	ld a,(ix+00ch)          ; A = lifetime timer
	and 004h                ; bit 2 -> flicker phase
	ld c,085h               ; flame frame 0x85
	jr z,l9b88h
	inc c                   ; ...or 0x86 (the flicker/undulation)
l9b88h:
	ld (ix+00bh),c          ; +0x0B anim frame = flame sprite
	dec (ix+00ch)           ; lifetime timer--
	ret nz                  ; keep burning until it hits 0
	call actor_free             ; flame expired: free/finalise the slot
	ld a,(ix+01fh)
	and a
	ret z                   ; +0x1F drop gate clear -> no pickup
	ld c,actor_pickup       ; drop = settled pickup at the flame spot
	ld e,(ix+003h)          ; DE = flame position (+0x03 / +0x05)
	ld d,(ix+005h)
	jp spawn_actor          ; spawn the settled pickup at that spot
actor_pickup_init:             ; (seg2 0x9BA2) fall + sway; pose 0x00
	ld (ix+00eh),002h
	ld (ix+00ch),001h
	ld (ix+006h),001h
	ld de,00080h
	call actor_set_yvel
	ld de,00200h
	call actor_set_xvel
	ld (ix+011h),0ffh
	ld (ix+010h),0e0h
	ld (ix+00bh),000h
	ld (ix+07eh),000h
	ret
; actor_reward_init (seg2 0x9BCB) - non-heart candle/chest drop. Physics off,
; pose 0x01 (shape_pickup). Tick cycles SAT colour, then falls, then
; drop_spawn with +0x1F. Hearts use actor_flame instead (drop_fx_spawn).
actor_reward_init:
	ld (ix+00ch),014h
	ld (ix+006h),000h
	ld (ix+00eh),002h
	ld (ix+00bh),001h
	ld (ix+07eh),000h
	ret
actor_pickup_go:
	call actor_floor_test
	jr c,l9c0ah
	inc (ix+00ch)
	ld e,(ix+010h)
	ld d,(ix+011h)
	call actor_add_xvel
	ld a,(ix+00ch)
	sub 020h
	ret nz
	ld (ix+00ch),a
	ld e,(ix+010h)
	ld d,(ix+011h)
	call neg_de
	ld (ix+010h),e
	ld (ix+011h),d
	ret
l9c0ah:
	call actor_free
	ld b,001h
	ld hl,00410h
l9c12h:
	ld a,(ix+003h)
	sub l
	and 0f8h
	ld e,a
	ld a,(ix+005h)
	sub h
	add a,004h
	and 0f8h
	ld d,a
	jp drop_spawn
; actor_reward_go (seg2 0x9C25): cycle SAT colour from reward_sat_col, then
; fall, then drop_spawn with B = +0x1F (the bonus id).
actor_reward_go:
	ld hl,reward_sat_col
	ld a,(0c003h)
	and 003h
	call ADD_HL_A
	ld a,(hl)
	ld (ix+025h),a
	ld a,(ix+001h)
	and a
	jr nz,l9c4dh
	dec (ix+00ch)
	ret nz
	inc (ix+001h)
	ld de,00000h
	call actor_set_xvel
	ld de,00800h
	jp actor_set_yvel
l9c4dh:
	ld (ix+006h),001h
	call actor_floor_test
	ret nc
	call actor_free
	ld b,(ix+01fh)
	ld hl,00810h
	jr l9c12h
reward_sat_col:                    ; (seg2 0x9C60) SAT colour cycle for actor_reward
	defb 008h,001h,00eh,001h
actor_floor_test:                  ; (seg2 0x9C64) map_solid_pair at actor (Y,X)
	ld e,(ix+003h)
	ld d,(ix+005h)
	jp map_solid_pair
; merman_splash_init (seg2 0x9C6D) - actor_merman_splash spawn. Pose 0x0E
; (0x15 on stage 10), then hop.
merman_splash_init:
	ld (ix+00eh),000h
	ld c,00eh
	ld a,(0d000h)
	cp 00ah
	jr nz,l9c80h
	ld c,015h
	ld (ix+025h),00bh
l9c80h:
	ld (ix+00bh),c
	ld (ix+00ch),01eh
	ld (ix+006h),001h
	ld (ix+07eh),000h
	ld hl,0cf30h
	inc (hl)
	ld a,(hl)
	ld hl,0fb00h
	ld de,00100h
	rra
	jr c,l9ca3h
	ld de,0ff00h
	ld hl,0fa00h
l9ca3h:
	call actor_set_xvel
	ex de,hl
	jp actor_set_yvel
merman_splash_go:
	ld de,00080h
	jp actor_add_yvel
	ld hl,0cf00h
	ld de,l9cc2h
	ld b,007h
l9cb8h:
	ld a,(de)
	ld (hl),a
	inc de
	inc l
	ld (hl),000h
	inc l
	djnz l9cb8h
	ret
l9cc2h:
	inc b
	inc b
	inc b
	ex af,af'
	ex af,af'
	ex af,af'
	ex af,af'
	ex af,af'
spawn_rate_gate:
	exx
	ld hl,0cf10h
	dec (hl)
	ld a,(hl)
	exx
	and 003h
	ret nz
	dec (hl)
	ret nz
	inc l
	ld a,(hl)
	inc (hl)
	dec l
	and 007h
	call ADD_DE_A
	ld a,(0d012h)
	add a,a
	ld c,a
	ld a,(de)
	sub c
	jr nc,l9ce9h
	xor a
l9ce9h:
	inc a
	ld (hl),a
	xor a
	ret
; --- zombie_generator (0x9ced) - continuous zombie spawner (room_spawner bit0) -
;  Rate-gated by spawn_rate_gate (0xCF00 counter, threshold table spawn_rate_zombie scaled by the
;  0xD012 difficulty/mood).  When it fires, spawn_pick_pos picks the spawn position
;  (hardcoded per stage/room - NOT read from the tile map), then spawns
;  actor_zombie.  Typical: X = 0xF0 (right edge) or 0x10 (left), Y = 0xC0.
zombie_generator:
	ld hl,0cf00h
	ld de,spawn_rate_zombie
	call spawn_rate_gate         ; time to spawn?
	ret nz
	call spawn_pick_pos         ; DE = spawn position (D=X, E=Y)
	call spawn_edge_gate
	ret c                  ; Simon crowding this spawn edge
	ld c,actor_zombie
	jp spawn_actor
; --- spawn_pick_pos - pick a ground-enemy spawn position by stage/room -------------
;  Out: D = X, E = Y.  D flips 0xF0 <-> 0x10 = right/left edge by a per-actor
;  flag.  Reads stage 0xD000 (L) and room 0xD001 (H).  Tile map is not consulted.
spawn_pick_pos:
	ld a,(0c425h)          ; Simon Y (used by some stage branches)
	ld c,a
	ld hl,(0d000h)         ; L = stage (0xD000), H = room (0xD001)
	ld a,l
	dec a
	jr z,l9d2fh            ; stage 1
	dec a
	jr z,l9d22h
	dec a
	jr z,l9d1eh
	cp 008h
	jr z,l9d1ah
	jr l9d33h
l9d1ah:
	ld e,0b0h
	jr l9d24h
l9d1eh:
	ld e,0c0h
	jr l9d24h
l9d22h:
	ld e,0a0h
l9d24h:
	ld d,0f0h
	ld a,(0cf01h)
	bit 1,a
	ret z
	ld d,010h
	ret
l9d2fh:
	ld a,h
	dec a
	jr z,l9d3fh
l9d33h:
	ld e,0c0h
l9d35h:
	ld d,0f0h
	ld a,(0c42ch)
	and a
	ret z
	ld d,010h
	ret
l9d3fh:
	ld e,0c0h
	ld a,c
	cp 088h
	jr nc,l9d35h
	ld de,0f060h
	ret
spawn_rate_zombie:                        ; zombie spawn-rate thresholds (8 bytes)
	defb 00ch,012h,00ch,00ch,00ch,012h,00ch,00ch
merman_generator:           ; (0x9D52) bit1, actor_merman_green (1 HP)
	ld hl,0cf02h
	ld c,actor_merman_green
	jr merman_spawn
merman_generator_3:         ; (0x9D59) bit2, actor_merman_red (spit, 2 HP)
	ld hl,0cf02h
	ld c,actor_merman_red
merman_spawn:
	ld de,spawn_rate_merman
	push bc
	call spawn_rate_gate
	pop bc
	ret nz
	ld e,0c8h              ; Y = 0xC8
	ld a,(0cf03h)
	and 007h
	ld hl,merman_spawn_x           ; X picks
	call ADD_HL_A
	ld d,(hl)
	ld a,(0c427h)          ; skip if Simon X is within 0x18 of spawn X
	sub d
	add a,018h
	cp 030h
	jp nc,spawn_actor
	ld a,d
	ld d,020h
	cp 080h
	jr c,l9d89h
	ld d,0e0h
l9d89h:
	add a,d
	ld d,a
	jp spawn_actor
merman_spawn_x:                        ; merman spawn X candidates
	defb 060h,0d0h,030h,090h,0a0h,040h,060h,0b0h
spawn_rate_merman:                        ; merman spawn-rate thresholds
	defb 001h,018h,018h,018h,018h,018h,018h,018h
hanging_bat_generator:         ; (0x9D9E) bit3, actor_hanging_bat
	ld hl,0cf06h
	ld de,spawn_rate_bat
	ld c,actor_hanging_bat
flyer_spawn:                   ; bats / ghosts / medusa heads: edge X, Y=SimonY-8
	push bc
	call spawn_rate_gate
	pop bc
	ret nz
	inc hl
	ld a,(hl)
	rr a
	ld d,0f0h              ; X = right edge
	jr c,l9db6h
	ld d,010h              ; X = left edge
l9db6h:
	call spawn_edge_gate
	ld a,(0c425h)
	sub 008h
	ld e,a                 ; Y = Simon Y - 8
	jp spawn_actor
spawn_rate_bat:                        ; bat spawn-rate thresholds
	defb 014h,014h,014h,028h,014h,014h,014h,028h
flying_skull_generator:        ; (0x9DCA) bit4, actor_flying_skull
	ld hl,0cf08h
	ld de,spawn_rate_ghost
	ld c,actor_flying_skull
	jr flyer_spawn
spawn_rate_ghost:                        ; ghost spawn-rate thresholds
	defb 01ch,01ch,01ch,048h,01ch,01ch,01ch,048h
ghost_head_generator:          ; (0x9DDC) bit5, actor_ghost_head
	ld hl,0cf0ah
	ld de,spawn_rate_medusa
	ld c,actor_ghost_head
	jr flyer_spawn
spawn_rate_medusa:                        ; medusa-head spawn-rate thresholds
	defb 00ch,00ch,00ch,018h,00ch,00ch,00ch,018h
roc_generator:                 ; (0x9DEE) bit6, actor_roc
	ld hl,0cf0ch
	ld de,spawn_rate_skull_cannon
	call spawn_rate_gate
	ret nz
	ld a,(0c427h)
	cp 0c0h
	jr c,l9e05h
	ld a,001h
	ld (0cf0ch),a          ; Simon already on the right -> don't spawn
	ret
l9e05h:
	ld de,0e030h           ; X=0xE0 Y=0x30
	ld a,(0cf0dh)
	rra
	jr c,l9e10h
	ld e,040h              ; or Y=0x40
l9e10h:
	ld c,actor_roc
	jp spawn_actor
spawn_rate_skull_cannon:                        ; skull-cannon spawn-rate thresholds
	defb 018h,018h,018h,018h,018h,018h,018h,018h
; spawn_edge_gate (seg2 0x9E1D): carry = don't spawn.  Simon in the middle
; (X 0x40..0xBF) always allows.  Near an edge, reject a spawn on that same
; side (left: D<0x40; right: D<0xC0).  The ld d,0xF0/0x10 is unused: callers
; ret c before using D.
spawn_edge_gate:
	ld a,(0c427h)
	cp 0c0h
	jr nc,l9e30h
	cp 040h
	jr c,l9e29h
	ret
l9e29h:
	ld a,d
	cp 040h
	ret nc
	ld d,0f0h
l9e2fh:
	ret
l9e30h:
	ld a,d
l9e31h:
	cp 0c0h
l9e33h:
	ccf
	ret nc
l9e35h:
	ld d,010h
	ret
shot_tick:                         ; (seg2 0x9E38) 8 shot slots at 0xD700
	ld ix,0d700h
	ld b,008h
l9e3eh:
	ld a,(ix+000h)
	and a
	jr z,l9e57h
	push bc
	call actor_freeze_check
	jr c,l9e50h
	call shot_type_tick
	call actor_integrate
l9e50h:
	call actor_sat_build
	call actor_cull_offscreen
	pop bc
l9e57h:
	ld de,00080h
	add ix,de
	djnz l9e3eh
	ret
shot_type_tick:                ; (seg2 0x9E5F) shot per-type tick (type-1)
	ld a,(ix+000h)
	dec a
	call DISPATCH_A
	defw fireball          ; 1  merman, dragon, g-bat
	defw fireball          ; 2
	defw fireball          ; 3  skull-pile
	defw shot_bone    ; 4  white-skeleton bone (kind 11)
	defw fireball          ; 5  Dracula
	defw medusa_snake  ; 6  kind 0x13
	defw mummy_bandage   ; 7  kind 0x14
	defw shot_sickle       ; 8  grim sickle (kind 0x16)
	defw shot_axe          ; 9  axe knight (kind 16)
	defw fireball          ; 10 igor (kind 24)
	defw shot_nop          ; 11 unused
	defw flame_tick        ; 12 kind 0xFF (death flame from shot_death_flame)
; fireball (seg2 0x9E7E) - types 1-3, 5, 10. Shared sprite: pose 3, SAT
; pattern 0xF0 (shape 0xB5CF), colours 0/8 from shot_sat_ptr 0xA0EA.
; Pixels are gfx_rle_a185 at VRAM 0xFF80 (loaded with the HUD sprites).
; Tick is ret; actor_integrate coasts on spawn velocity.
fireball:
	ret
medusa_snake:             ; (0x9E7F) poses 0x27-0x2A, facing
	inc (ix+00ch)
	bit 1,(ix+00ch)
	ld a,027h
	jr z,l9e8bh
	inc a
l9e8bh:
	bit 7,(ix+00ah)
	jr nz,l9e93h
	add a,002h
l9e93h:
	ld (ix+00bh),a
	ret
mummy_bandage:            ; (0x9E97) seek stored Y (ix+10/11), poses 0x39/0x3A
	ld e,(ix+012h)
	ld d,(ix+013h)
	ld l,(ix+010h)
	ld h,(ix+011h)
	add hl,de
	ld (ix+010h),l
	ld (ix+011h),h
	ld a,(ix+00ch)
	inc (ix+00ch)
	and 004h
	ld c,039h
	jr z,l9eb7h
	inc c
l9eb7h:
	ld (ix+00bh),c
	ld de,00030h
	ld a,(ix+003h)
	cp (ix+011h)
	jr c,l9ec8h
	ld de,0ffd0h
l9ec8h:
	jp actor_add_yvel
shot_nop:
	ret
shot_axe:                      ; (0x9ECC) poses 0x63-0x66; homing on thrower CFFC
	inc (ix+00ch)
	ld a,(ix+00ch)
	rra
	rra
	and 003h
	add a,063h
	ld (ix+00bh),a
	bit 7,(ix+010h)
	ld de,00018h
	jr nz,l9ee7h
	ld de,0ffe8h
l9ee7h:
	call actor_add_xvel
	ld a,(ix+013h)
	and a
	jr z,l9ef4h
	dec (ix+013h)
	ret
l9ef4h:
	ld l,(ix+011h)
	ld h,(ix+012h)
	ld a,(hl)
	cp 010h
	ret nz
	ld a,005h
	add a,l
	ld l,a
	ld a,(hl)
	sub (ix+005h)
	add a,010h
	cp 020h
	ret nc
	jp actor_free
; shot_bone (seg2 0x9F0E) - shot type 4, the white skeleton's bone.
; 4-frame spin (shapes 0x4B-0x4E, packed after the skeleton walk 0x47-0x4A)
; plus gravity 0x50/frame. Spawned by shot_throw with kind 11.
shot_bone:
	ld a,(ix+00ch)
	inc a
	cp 00ch                ; 12-step timer -> 4 poses x 3 frames
	jr c,l9f17h
	xor a
l9f17h:
	ld (ix+00ch),a
	rra
	rra
	and 003h
	add a,04bh             ; pose 0x4B / 4C / 4D / 4E
	ld (ix+00bh),a
	ld de,00050h            ; +0x50/frame
	jp actor_add_yvel
shot_sickle:                   ; (0x9F29) poses 0x7D-0x80; windup then fly 0x1E
	ld a,(ix+00ch)
	rra
	rra
	and 003h
	add a,07dh
	ld (ix+00bh),a
	ld a,(ix+001h)
	dec a
	jr z,l9f53h
	dec (ix+00ch)
	ret nz
	ld a,040h
	call aim_at_simon_xy
	call actor_set_xvel
	ex de,hl
	call actor_set_yvel
	ld (ix+00ch),01eh
	inc (ix+001h)
	ret
l9f53h:
	dec (ix+00ch)
	ret nz
	ld de,00000h
	call actor_set_xvel
	call actor_set_yvel
	ld (ix+00ch),03ch
	ld (ix+001h),e
	ret
; shot_throw (seg2 0x9F68) - spawn a shot from the current actor.
; Kind = ix+0 (via shot_kind_type -> shot type). Pos = (X, Y-16). Yvel HL, Xvel DE.
; White skeleton (type 11) -> shot type 4 (shot_bone). Axe (16) -> type 9.
shot_throw:
	ld a,(ix+003h)
	sub 010h               ; spawn 16 px above the actor
	ld c,a
	ld b,(ix+005h)         ; B = actor X
	ld a,(ix+000h)         ; A = actor type as kind
; shot_spawn (seg2 0x9F74) - A=kind, BC=pos, HL=yvel, DE=xvel. Allocates a
; shot slot. Kind 0xFF is type 12 (flame); else type = shot_kind_type[kind].
shot_spawn:
	ld (0cff9h),a          ; kind
	ld (0cff1h),bc         ; pixel pos
	ld (0cff5h),hl         ; Y velocity
	ld (0cff7h),de         ; X velocity
	push ix
	call shot_alloc
	pop ix
	ret
shot_alloc:                    ; (seg2 0x9F8A) find a free shot slot and arm it
	ld a,(0cff9h)
	cp 0ffh
	ld c,00ch              ; kind 0xFF -> shot type 12 (flame_tick)
	jr z,l9f9ah
	ld hl,shot_kind_type   ; kind -> shot type; [11]=4 bone, [16]=9 axe
	call ADD_HL_A
	ld c,(hl)
l9f9ah:
	ld a,c
	ld (0cff0h),a
	ld hl,0d700h
	ld b,008h
	xor a
	ld de,00080h
l9fa7h:
	cp (hl)
	jr z,l9faeh
	add hl,de
	djnz l9fa7h
	ret
l9faeh:
	push hl
	pop ix
	ld (0cff3h),hl
	ld c,002h
	ld (ix+020h),c
	ld (ix+07fh),001h
	ld (ix+07eh),001h
	ld de,01100h
	ld hl,0d67ch
	ld b,008h
	ld a,(0ce03h)
	and a
	jr z,l9fd1h
	ld b,002h
l9fd1h:
	ld a,(hl)
	cp 0e0h
	jr nz,l9fdfh
	ld (hl),0e1h
	call actor_sat_assign
	inc e
	dec c
	jr z,l9fe7h
l9fdfh:
	dec d
	dec l
	dec l
	dec l
	dec l
	djnz l9fd1h
	ret
l9fe7h:
	ld hl,(0cff3h)
	ld a,(0cff0h)
	ld (hl),a
	inc l
	ld (hl),000h
	ld de,(0cff1h)
	inc l
	ld (hl),000h
	inc l
	ld (hl),e
	inc l
	ld (hl),000h
	inc l
	ld (hl),d
	inc l

; ===========================================================================
;  SEGMENT 3 - banked code, paged at 0xA000-0xBFFF (page 2b).
;  Continues this window at CPU 0xA000 (24K into this PHASE).
;  Regen: tools/disasm/regen-seg.sh 3 0xA000
; ===========================================================================

	ld (hl),001h
	inc l
	ld de,(0cff5h)
	ld (hl),e
	inc l
	ld (hl),d
	ld de,(0cff7h)
	inc l
	ld (hl),e
	inc l
	ld (hl),d
	inc l
	ld (hl),003h           ; pose 3 = fireball (SAT pattern 0xF0)
	ld a,(ix+000h)
	ld de,0a0c4h
	call lookup_word_tbl
	ld hl,(0cff3h)
	set 5,l
	ld b,(hl)
	ld a,005h
	add a,l
	ld l,a
la028h:
	ld a,(de)
	ld (hl),a
	inc de
	ld a,l
	add a,005h
	ld l,a
	djnz la028h
	ld hl,(0cff3h)
	ld a,(ix+000h)
	dec a
	call DISPATCH_A
	defw shot_init_nop, shot_init_nop, shot_init_nop, shot_init_nop
	defw shot_init_nop, shot_init_nop
	defw mummy_bandage_init   ; 7
	defw shot_sickle_init  ; 8
	defw shot_axe_init     ; 9
	defw shot_init_nop, shot_init_nop  ; 10-11
	defw flame_init        ; 12 (seg2 0x9B67)
shot_init_nop:
	ret
mummy_bandage_init:            ; (0xA054) store Y, drop Yvel by 0x100
	ld (ix+010h),000h
	ld a,(ix+003h)
	ld (ix+011h),a
	ld l,(ix+007h)
	ld h,(ix+008h)
	ld de,00100h
	and a
	sbc hl,de
	ld (ix+012h),l
	ld (ix+013h),h
	ret
shot_sickle_init:              ; (0xA071) visible, timer 0x3C, vel 0
	ld (ix+006h),001h
	ld (ix+00ch),03ch
	ld de,00000h
	call actor_set_yvel
	jp actor_set_xvel
shot_axe_init:                 ; (0xA082) facing from Xvel; thrower ptr CFFC
	ld a,(ix+00ah)
	ld (ix+010h),a
	ld (ix+013h),018h
	ld hl,(0cffch)
	ld (ix+011h),l
	ld (ix+012h),h
shot_kind_type:                 ; (0xA095) kind -> shot type. Byte 0 is this RET
	ret                     ; kind 0 unused
	defb 001h,001h,002h,001h,001h,001h,001h,001h  ; 1-8
	defb 001h,003h,004h,001h,001h,001h,001h,009h  ; 9-16  0x0A pile=3, 11 bone=4, 16 axe=9
	defb 005h,001h,006h,007h,001h,008h,00bh,00ah  ; 17-24  0x11 fire=5, 13 snake=6, 14 bandage=7, 16 sickle=8, 24 igor=10
	defb 001h,001h,001h,001h,001h,001h,001h,001h  ; 25-32
	defb 001h,001h,001h,001h,001h,001h,001h,001h  ; 33-40
	defb 001h,001h,001h,001h,001h,001h            ; 41-46
shot_sat_ptr:                  ; (0xA0C4) word[type] SAT colours. 1-3,5,10 = fireball 00/08
	defw 00101h, 0a0eah, 0a0eah, 0a0eah, 0a0deh, 0a0eah
	defw 0a0e0h, 0a0e2h, 0a0e2h, 0a0e4h, 0a0eah, 0a0e6h
	defb 0e8h,0a0h, 042h,00ch, 045h,002h, 042h,005h
	defb 042h,005h, 048h,005h, 000h,008h, 000h,008h
; aim_at_simon (seg3 0xA0EC): vector from actor (Y=ix+3, X=ix+5) toward
; Simon.  Speed base 0x80 plus 8*D012.  Returns HL = packed vel; also
; fills CFF0-CFF9.  aim_at_simon_xy (0xA0EE) keeps A as speed.
; aim_at_simon_spd (0xA0F4) takes speed in A and Y/X already in E/D.
aim_at_simon:
	ld a,080h
aim_at_simon_xy:               ; (0xA0EE) A = speed; E/D from actor Y/X
	ld e,(ix+003h)
	ld d,(ix+005h)
aim_at_simon_spd:
	ld c,a
	ld a,(0d012h)
	add a,a
	add a,a
	add a,a
	add a,c
	ld (0cff0h),a
	call aim_octant
	ld a,(0cff8h)
	ld e,a
	ld d,000h
	ld a,e
	sub 03fh
	neg
	ld hl,aim_scale_tbl
	push hl
	add hl,de
	ld c,(hl)
	pop hl
	ld e,a
	add hl,de
	ld a,(hl)
	ld (0cff7h),a
	ld e,c
	call aim_scale
	ld a,(0cff1h)
	and a
	call nz,neg_de
	ld (0cff3h),de
	ld a,(0cff7h)
	ld e,a
	call aim_scale
	ld a,(0cff2h)
	and a
	call nz,neg_de
	ld hl,(0cff3h)
	ret
; aim_octant (seg3 0xA13B): from actor (E=Y, D=X) vs Simon, fill CFF1/2
; (Y/X signs), CFF8 = aim_octant_tbl[quantized dy,dx], CFF9 = facing byte.
aim_octant:
	ld hl,0cff1h
	ld (hl),000h
	ld a,(0c425h)
	sub e
	jr nc,la149h
	neg
	inc (hl)
la149h:
	inc hl
	ld (hl),000h
	rra
	rra
	and 038h
	ld e,a
	ld a,(0c427h)
	sub d
	jr nc,la15ah
	neg
	inc (hl)
la15ah:
	rra
	rra
	rra
	rra
	rra
	and 007h
	add a,e
	ld hl,aim_octant_tbl
	call ADD_HL_A
	ld a,(hl)
	ld (0cff8h),a
	ld c,a
	ld hl,(0cff1h)
	ld a,h
	ld b,000h
	and a
	jr z,la178h
	ld b,080h
la178h:
	cp l
	ld a,c
	jr z,la17eh
	neg
la17eh:
	add a,b
	ld (0cff9h),a
	ret
neg_de:                        ; (0xA183) DE = -DE (two's complement)
	ld a,d
	cpl
	ld d,a
	ld a,e
	cpl
	ld e,a
	inc de
	ret
; aim_scale (seg3 0xA18B): DE = CFF0 * E / 32 (speed * lut / 32).
aim_scale:
	ld a,(0cff0h)
	ld h,a
	call MUL_H_E
	xor a
	add hl,hl
	adc a,a
	add hl,hl
	adc a,a
	add hl,hl
	adc a,a
	ld l,h
	ld h,a
	ex de,hl
	ret
; MUL_H_E (seg3 0xA19D): HL = H * E (8x8 -> 16).  D is cleared.
MUL_H_E:
	ld b,008h
	ld l,000h
	ld d,l
la1a2h:
	add hl,hl
	jr nc,la1a6h
	add hl,de
la1a6h:
	djnz la1a2h
	ret
aim_octant_tbl:                ; (0xA1A9) 8x8 atan; index = (dy>>2)&0x38 | (dx>>5)&7
	defb 020h,008h,004h,003h,002h,002h,001h,001h
	defb 038h,020h,015h,00fh,00ch,009h,008h,007h
	defb 03bh,02bh,020h,019h,014h,010h,00eh,00ch
	defb 03dh,031h,027h,020h,01ah,016h,013h,011h
	defb 03dh,034h,02ch,025h,020h,01ch,018h,015h
	defb 03eh,036h,02fh,029h,024h,020h,01ch,019h
	defb 03eh,038h,032h,02ch,028h,023h,020h,01dh
	defb 03eh,039h,034h,02fh,02ah,026h,023h,020h
aim_scale_tbl:                 ; (0xA1E9) 64-byte magnitude lut (0..0xFF)
	defb 000h,006h,00ch,012h,019h,01fh,026h,02ch
	defb 032h,038h,03eh,044h,04ah,050h,056h,05ch
	defb 062h,068h,06dh,073h,079h,07eh,084h,089h
	defb 08eh,093h,099h,09eh,0a2h,0a7h,0ach,0b1h
	defb 0b5h,0b9h,0beh,0c2h,0c6h,0cah,0ceh,0d1h
	defb 0d5h,0d8h,0dch,0dfh,0e2h,0e5h,0e7h,0eah
	defb 0edh,0efh,0f1h,0f3h,0f5h,0f7h,0f8h,0fah
	defb 0fbh,0fch,0fdh,0feh,0feh,0ffh,0ffh,0ffh
; enemy_skull_pile_tick (seg3 0xA229) - type 10. Stationary; faces Simon
; (skull_pile_face) and shoots shot_spawn (0x9F74) kind 0x0A. 8 HP, 300 pts.
enemy_skull_pile_tick:
	call skull_pile_face          ; pick facing frame from Simon X
	ld (ix+010h),008h
	ld (ix+011h),020h
	ret
enemy_skull_pile_go:
	call skull_pile_face
	ld a,(ix+001h)
	dec a
	jr z,skull_pile_windup
	dec a
	jr z,skull_pile_recover
skull_pile_idle:
	dec (ix+010h)
	ret nz
	inc (ix+001h)
	ld (ix+011h),018h
	ld a,(0d012h)
	add a,a
	add a,a
	add a,a
	sub 028h
	neg
	ld (ix+010h),a
	ret
skull_pile_windup:
	ld a,04ch
	bit 0,(ix+011h)
	jr z,la264h
	ld a,048h
la264h:
	call skull_pile_sat_pat
	dec (ix+011h)
	ret nz
	ld (ix+013h),012h
	inc (ix+001h)
la272h:
	ld hl,00000h
	ld de,0fc00h
	bit 0,(ix+00bh)
	jr z,la281h
	ld de,00400h
la281h:
	ld a,(ix+003h)
	sub 014h
	ld c,a
	ld b,(ix+005h)
	ld a,00ah               ; shot_spawn kind 0x0A -> type 3
	call shot_spawn
	ld a,04ch
; skull_pile_sat_pat (seg3 0xA291): both SAT cells pattern A, colour 2.
skull_pile_sat_pat:
	ld (ix+025h),002h
	ld (ix+02ah),a
	ld (ix+02fh),002h
	ld (ix+034h),a
	ret
skull_pile_recover:
	call skull_pile_face
	dec (ix+013h)
	ret nz
	ld (ix+001h),000h
	jr la272h
	ld a,04ch
; skull_pile_face (seg3 0xA2AF): pose 5/4 from Simon X; 7/6 in s9r4.
skull_pile_face:
	ld b,005h
	ld a,(0d000h)
	cp 009h
	jr nz,la2c1h
	ld a,(0d001h)
	cp 004h
	jr nz,la2c1h
	ld b,007h
la2c1h:
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,la2cah
	dec b
la2cah:
	ld (ix+00bh),b
	ret
; enemy_placed_merman_init (seg3 0xA2CE) - object-list id 0x21 (stage 10).
; Play-confirmed: red mermen already standing on the platform; they do not
; jump out of the water. Skips the type-0x20 splash pair that generator
; mermen spawn, arms ix+1B, jumps into the walk at la36dh. Same per-frame
; tick as types 2/3 (`actor_type_tick` -> 0xA317). Type bit0 set so it spits like
; type 3; HP/SAT match type 3 (2 HP, 0x612F).
enemy_placed_merman_init:
	ld (ix+01bh),001h
	xor a
	ld (ix+01ch),a
	ld (ix+012h),a
	ld (ix+010h),002h
	ld (ix+019h),a
	ld (ix+015h),001h
	jp la36dh
; enemy_merman_tick (seg3 0xA2E7) - actor_merman_green (1 HP, closed mouth) and
; actor_merman_red (2 HP, open-mouth spit). Shared walk/pounce; type 3 (bit 0 of
; the type id) counts down ix+10 then enters state 2 and fires shot_spawn kind 2
; from Y-0x14. Type 2 can write type=3 + pose 0x12 when ix+1B is set and
; Simon's Y is within ±8.
enemy_merman_tick:
	call merman_pick_frame  ; 0x0B/0x08 (type 2) or 0x12/0x0F (type 3)
	xor a
	ld (ix+018h),a
	ld (ix+01bh),a
	inc a
	ld (ix+006h),a
	ld (ix+019h),a
	ld (ix+008h),0f4h
	ld (ix+007h),080h
	ld a,008h
	call play_sound_alive
	ld e,(ix+003h)
	ld d,(ix+005h)
	ld c,actor_merman_splash
	push de
	call spawn_actor
	pop de
	ld c,actor_merman_splash
	jp spawn_actor
merman_go:
	inc (ix+01dh)
	ld a,(ix+001h)
	dec a
	jp z,merman_walk
	dec a
	jp z,merman_spit
merman_fall:
	bit 0,(ix+018h)
	jr nz,la32eh
	call merman_pick_frame
la32eh:
	ld de,00000h
	call actor_set_xvel
	ld de,00080h
	call actor_add_yvel
	bit 7,(ix+008h)
	ret nz
	ld d,(ix+005h)
	ld e,(ix+003h)
	bit 0,(ix+012h)
	jr z,la34fh
	ld a,d
	add a,008h
	ld d,a
la34fh:
	call map_solid_pair
	jr nc,la387h
	ld a,007h
	call play_sound_alive
	ld a,(ix+003h)
	and 0f8h
	ld (ix+003h),a
	ld a,(0d012h)
	add a,a
	add a,a
	sub 030h
	neg
	ld (ix+010h),a
la36dh:
	ld (ix+011h),010h
	ld (ix+014h),000h
	ld (ix+015h),001h
	ld (ix+001h),001h
	ld (ix+013h),008h
	ld de,00000h
	jp actor_set_yvel
la387h:
	ld a,(ix+003h)
	cp 0c0h
	ret c
	ld a,009h
	call play_sound_alive
	call 099fdh
	ld e,(ix+003h)
	ld d,(ix+005h)
	ld c,actor_merman_splash
	push de
	call spawn_actor
	pop de
	ld c,actor_merman_splash
	jp spawn_actor
merman_walk:                    ; state 1: walk
	bit 0,(ix+01bh)
	jr z,la3d2h
	bit 0,(ix+01ch)
	jr nz,la3d2h            ; already latched this attack
	ld (ix+00bh),012h       ; open-mouth pose (type 3)
	ld a,(0c425h)           ; Simon Y
	ld b,a
	ld (ix+000h),003h       ; become type 3 (shooting form)
	ld a,(ix+003h)
	sub 008h
	cp b
	ret nc                  ; Simon above the ±8 Y window
	add a,010h
	cp b
	ret c                   ; Simon below it
	ld (ix+006h),001h
	ld (ix+01ch),001h       ; Y overlapped: arm the spit
la3d2h:
	bit 0,(ix+000h)         ; type 3 has bit 0 set; type 2 does not
	jr z,la3e5h             ; green: just walk
	dec (ix+010h)
	jr nz,la3e5h
	inc (ix+001h)           ; -> state 2 spit
	ld (ix+011h),018h
	ret
la3e5h:
	dec (ix+015h)
	jr nz,la40ah
	call merman_walk_period
	ld (ix+012h),000h
	ld de,0fe80h
	ld a,(0c427h)
	cp (ix+005h)
	jr c,la403h
	ld (ix+012h),001h
	ld de,00180h
la403h:
	call actor_set_xvel
	ld (ix+013h),001h
la40ah:
	ld hl,la459h
	bit 0,(ix+012h)
	jr z,la416h
	ld hl,la45dh
la416h:
	dec (ix+013h)
	jr nz,la436h
	ld (ix+013h),008h
	inc (ix+014h)
	ld a,(ix+014h)
	and 001h
	bit 0,(ix+000h)         ; type 3 uses frames +2 (open mouth)
	jr z,la42fh
	add a,002h
la42fh:
	call ADD_HL_A
	ld a,(hl)
	ld (ix+00bh),a
la436h:
	ld a,(ix+005h)
	bit 7,(ix+00ah)
	jr nz,la441h
	add a,008h
la441h:
	ld d,a
	ld e,(ix+003h)
	call map_solid_pair
	ret c
	ld (ix+008h),000h
	ld (ix+007h),000h
	dec (ix+001h)
	ld (ix+018h),001h
	ret
la459h:
	defb 008h,009h,00fh,010h ; type2/type3 walk, facing 0
la45dh:
	defb 00bh,00ch,012h,013h ; facing 1
merman_spit:                    ; state 2: open-mouth spit
	ld (ix+006h),000h       ; hide the body while the shot plays
	dec (ix+011h)
	jr z,la48dh
	ld a,(ix+011h)
	cp 008h
	jr z,la499h             ; mid-timer: fire
	ld hl,la4b6h
	cp 010h
	jr c,la489h
	ld c,000h
la47ah:
	bit 0,(ix+012h)
	jr z,la481h
	inc c
la481h:
	ld b,000h
	add hl,bc
	ld a,(hl)
	ld (ix+00bh),a
	ret
la489h:
	ld c,002h
	jr la47ah
la48dh:
	dec (ix+001h)
	ld (ix+010h),030h
	ld (ix+006h),001h
	ret
la499h:
	ld hl,00000h
	ld de,00300h            ; spit X vel right
	bit 7,(ix+00ah)
	jr z,la4a8h
	ld de,0fd00h            ; or left
la4a8h:
	ld a,(ix+003h)
	sub 014h                ; from the mouth (Y-0x14)
	ld c,a
	ld b,(ix+005h)
	ld a,002h               ; shot_spawn kind 2 -> type 1 (fireball)
	jp shot_spawn
la4b6h:
	defb 00fh,012h,011h,014h ; spit anim frames
merman_pick_frame:              ; (0xA4BA)
	ld b,00bh               ; type 2 closed-mouth
	ld c,008h
	bit 0,(ix+000h)
	jr z,la4c8h
	ld b,012h               ; type 3 open-mouth
	ld c,00fh
la4c8h:
	ld (ix+00bh),b
	ld a,(0c427h)
	cp (ix+005h)
	ret nc                  ; Simon to the right: keep B
	ld (ix+00bh),c          ; Simon to the left: use C
	ret
; merman_walk_period (seg3 0xA4D6): ix+15 from period tbl[ix+1D & 3].
merman_walk_period:
	ld hl,merman_period_long
	bit 0,(ix+019h)
	jr nz,la4e2h
	ld hl,merman_period_short
la4e2h:
	ld a,(ix+01dh)
	and 003h
	call ADD_HL_A
	ld a,(hl)
	ld (ix+015h),a
	ret
; play_sound_alive (seg3 0xA4EF): play_sound unless Simon is dying (C420==6).
play_sound_alive:
	ld c,a
	ld a,(0c420h)
	cp 006h
	ret z
	ld a,c
	jp play_sound
merman_period_long:            ; (0xA4FA) ix+19 set
	defb 010h,020h,018h,030h
merman_period_short:           ; (0xA4FE)
	defb 008h,010h,00bh,006h
; enemy_ghost_head_tick (seg3 0xA502) - type 08. Flies across, bobs around
; spawn Y (ix+10). X direction from which edge it entered.
enemy_ghost_head_tick:
	ld (ix+006h),001h
	ld a,(ix+003h)
	ld (ix+010h),a         ; remember spawn Y
	ld de,0fc80h
	call actor_set_yvel
	ld a,(ix+005h)
	cp 080h
	ld de,00280h           ; +X if spawned on the left
	jr c,la51fh
	ld de,0fd80h           ; -X if spawned on the right
la51fh:
	jp actor_set_xvel_speedup
enemy_ghost_head_go:
	ld c,071h
	ld a,(0d000h)
	cp 015h
	jr nz,la52dh
	ld c,072h
la52dh:
	inc (ix+00ch)
	bit 2,(ix+00ch)
	jr z,la537h
	inc c
la537h:
	bit 7,(ix+00ah)
	jr nz,la53fh
	inc c
	inc c
la53fh:
	ld (ix+00bh),c
	ld de,00040h
	ld a,(ix+003h)
	cp (ix+010h)
	jr c,actor_add_yvel
	ld de,0ffc0h
; ---------------------------------------------------------------------------
;  Actor velocity helpers.  Actor slot layout (confirmed via the seg2 integrator
;  at 0x99C0 and the dog/zombie AI):
;     +0x02/+0x03  Y position (16-bit fixed: +0x02 frac, +0x03 pixel)
;     +0x04/+0x05  X position (16-bit fixed: +0x04 frac, +0x05 pixel)
;     +0x07/+0x08  Y velocity (16-bit signed)
;     +0x09/+0x0A  X velocity (16-bit signed)
;  actor_add_yvel (0xA550): Yvel += DE, but clamp to [0, 0x07FF] - i.e. downward
;  only with a terminal fall speed (gravity).  Falls through to actor_set_yvel.
; ---------------------------------------------------------------------------
actor_add_yvel:
	ld l,(ix+007h)
	ld h,(ix+008h)
	add hl,de               ; Yvel += DE
	ex de,hl
	ld a,d
	and a
	jp m,actor_set_yvel     ; negative -> store as-is
	cp 008h
	jr c,actor_set_yvel     ; < 0x0800 -> store
	ld de,007ffh            ; clamp to terminal fall speed
actor_set_yvel:
	ld (ix+007h),e          ; +0x07/+0x08 = Y velocity
	ld (ix+008h),d
	ret

; actor_add_xvel (0xA56B): Xvel += DE.  Falls through to actor_set_xvel.
actor_add_xvel:
	ld l,(ix+009h)
	ld h,(ix+00ah)
	add hl,de               ; Xvel += DE
	ex de,hl
actor_set_xvel:
	ld (ix+009h),e          ; +0x09/+0x0A = X velocity
	ld (ix+00ah),d
	ret
; enemy_pikeman_tick (seg3 0xA57A) - type 06 walking spear knight. Turns at
; ledges/walls; walks toward Simon when Y overlaps (±8 via simon_y_overlap). 4 HP,
; 200 pts. No projectile. Shape 0x50.
enemy_pikeman_tick:
	ld (ix+006h),001h
	ld de,00000h
	ld (ix+010h),e
	ld (ix+011h),e
	call actor_set_yvel
	ld de,00160h
	call actor_set_xvel
	ld (ix+00bh),050h
	ld (ix+00ch),060h
	ret
enemy_pikeman_go:
	dec (ix+00ch)
	ld a,014h
	bit 7,(ix+00ah)
	jr z,la5a6h
	ld a,0f8h
la5a6h:
	add a,(ix+005h)
	ld d,a
	ld e,(ix+003h)
	call map_solid_pair
	jr nc,la613h
	ld d,(ix+005h)
	ld bc,00808h
	bit 7,(ix+00ah)
	jr nz,la5c3h
	call probe_wall_right
	jr la5c6h
la5c3h:
	call probe_wall_left
la5c6h:
	jr c,la613h
	ld a,(ix+005h)
	cp 0f0h
	jr c,la5d7h
	bit 7,(ix+00ah)
	jr z,la613h
	jr la5e3h
la5d7h:
	cp 00fh
	jp nc,la5e3h
	bit 7,(ix+00ah)
	jp nz,la613h
la5e3h:
	call simon_y_overlap
	jr nc,la605h
	bit 0,(ix+011h)
	jr nz,la609h
	ld de,00160h
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,la5fch
	ld de,0fea0h
la5fch:
	call actor_set_xvel_speedup
	ld (ix+011h),001h
	jr la616h
la605h:
	ld (ix+011h),000h
la609h:
	ld a,(ix+00ch)
	and a
	jr nz,la616h
	ld (ix+00ch),060h
la613h:
	call actor_flip_xvel
la616h:
	inc (ix+010h)
	ld a,(ix+010h)
	rra
	rra
	and 003h
	ld hl,la62eh
	bit 7,(ix+00ah)
	jr nz,la62bh
	add a,004h
la62bh:
	ld c,a
	jr actor_set_pose
la62eh:
	ld d,b
	ld d,c
	ld d,d
	ld d,c
	ld d,e
	ld d,h
	ld d,l
	ld d,h
; actor_set_pose (seg3 0xA636): ix+0B = (HL)[C].
actor_set_pose:
	ld b,000h
	add hl,bc
	ld a,(hl)
	ld (ix+00bh),a
	ret
; simon_y_overlap (seg3 0xA63E): NZ if Simon Y is within ±8 of actor Y.
simon_y_overlap:
	ld a,(0c425h)
	sub (ix+003h)
	add a,008h
	cp 010h
	ret
actor_flip_xvel:                   ; (seg3 0xA649) negate X velocity
	push af
	push de
	ld e,(ix+009h)
	ld d,(ix+00ah)
	call neg_de
	call actor_set_xvel
	pop de
	pop af
	ret
; ---------------------------------------------------------------------------
;  actor_set_xvel_speedup (0xA65A) - set X velocity (DE) with a progress-based
;  speed bias added in the direction of travel.  0xD012 is a game-progress /
;  difficulty tier (0..3, bumped each level-advance in seg1 0x66FC and capped at
;  3), so enemies move faster the deeper you get.  Adds 0xD012 * 32 to the speed:
;  when the velocity is negative (moving left) the addend is negated first
;  (neg_de) so the magnitude grows either way.  DE == 0 -> plain store.  Ends
;  by storing to +0x09/+0x0A via actor_set_xvel.  (VK does not scroll; this is a
;  speed ramp, not background scrolling.)
; ---------------------------------------------------------------------------
actor_set_xvel_speedup:
	ld a,d
	or e
	jp z,actor_set_xvel     ; zero velocity: just store
	push hl
	ex de,hl                ; HL = requested X velocity
	ld a,(0d012h)           ; A = progress/difficulty tier (0..3)
	add a,a
	add a,a
	add a,a
	add a,a
	add a,a                 ; A = tier * 32
	ld d,000h
	ld e,a
	bit 7,h
	call nz,neg_de       ; negate the bias when moving left
	add hl,de               ; add the speed bias in the travel direction
	ex de,hl
	pop hl
	jp actor_set_xvel
; enemy_raven_tick (seg3 0xA677) - type 12. Flies, damps Yvel to 0 (hover),
; then a new arc or a strafe when Simon's Y is within 0x18. Distinct from
; type 8's sine bob. Shape 0x89. 1 HP, 100 pts.
enemy_raven_tick:
	ld (ix+010h),018h
	ld (ix+00bh),089h
	ld (ix+012h),000h
	ret
enemy_raven_go:
	inc (ix+018h)
	ld a,(ix+001h)
	call DISPATCH_A
	defw raven_wait        ; 0  spawn timer, then fly
	defw raven_coast       ; 1  damp Xvel to 0
	defw raven_hover       ; 2  pause in place
	defw raven_pick        ; 3  Simon Y close -> strafe, else new coast
	defw raven_strafe_init ; 4  aim vertical at Simon
	defw raven_strafe      ; 5  cross Simon X
	defw raven_recover     ; 6  damp Yvel to the strafe cap
	defw raven_hold        ; 7  flap; off-screen -> hover
raven_wait:
	dec (ix+010h)
	ret nz
	ld (ix+006h),001h
	inc (ix+001h)
	call raven_pick_vel
	ret
raven_coast:
	call raven_bounds
	ret c
	call raven_flap
	ld a,0e0h
	bit 7,(ix+008h)
	jr z,la6bdh
	ld a,020h
la6bdh:
	ld h,(ix+008h)
	ld l,(ix+007h)
	call ADD_HL_A_SIGNED       ; Yvel += signed step (coast to 0)
	ld (ix+008h),h
	ld (ix+007h),l
	ld a,(ix+008h)
	and a
	ret nz
	ld a,(ix+007h)
	and a
	ret nz
	ld (ix+01eh),018h
	inc (ix+001h)
	ret
raven_hover:
	call raven_flap
	ld (ix+006h),000h
	dec (ix+01eh)
	ret nz
	ld (ix+006h),001h
	inc (ix+001h)
	ret
raven_pick:
	ld (ix+001h),001h
	ld a,(0c425h)
	sub (ix+003h)
	cp 018h
	jp nc,raven_pick_vel
	ld (ix+001h),004h
	ret
raven_strafe_init:
	ld (ix+00ah),003h
	ld (ix+009h),000h
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,la71dh
	ld (ix+00ah),0fdh
	ld (ix+009h),000h
la71dh:
	ld (ix+008h),000h
	ld (ix+007h),000h
	inc (ix+001h)
	ld (ix+010h),030h
	jp raven_flap
raven_strafe:
	call raven_bounds
	ret c
	call raven_flap
	dec (ix+010h)
	jr z,la763h
	bit 7,(ix+00ah)
	jr z,la752h
	ld (ix+011h),000h
	ld a,(0c427h)
	sub 008h
	cp (ix+005h)
	ret c
	inc (ix+001h)
	ret
la752h:
	ld (ix+011h),001h
	ld a,(0c427h)
	add a,008h
	cp (ix+005h)
	ret nc
	inc (ix+001h)
	ret
la763h:
	call raven_pick_vel
	ld (ix+001h),001h
	ret
raven_recover:
	call raven_bounds
	ret c
	call raven_flap
	ld a,0e0h
	ld e,0feh
	bit 0,(ix+011h)
	jr nz,la780h
	ld a,020h
	ld e,002h
la780h:
	ld h,(ix+00ah)
	ld l,(ix+009h)
	call ADD_HL_A_SIGNED       ; Xvel += signed step (toward ±0x02)
	ld (ix+00ah),h
	ld (ix+009h),l
	ld a,h
	cp e
	ret nz
	inc (ix+001h)
	ld (ix+009h),000h
	ret
raven_hold:
	call raven_bounds
	ret c
; raven_flap (seg3 0xA79E): pose 0x8A/8B (right) or 0x87/88 (left).
raven_flap:
	ld hl,raven_flap_r
	bit 7,(ix+00ah)
	jr z,la7aah
	ld hl,raven_flap_l
la7aah:
	inc (ix+012h)
	ld a,(ix+012h)
	and 008h
	sra a
	sra a
	sra a
	call ADD_HL_A
	ld a,(hl)
	ld (ix+00bh),a
	ret
raven_flap_r:                  ; (0xA7C0) 0x8A/8B
	defb 08ah,08bh
raven_flap_l:                  ; (0xA7C2) 0x87/88
	defb 087h,088h
; raven_pick_vel (seg3 0xA7C4): Xvel toward Simon (bounce at X 0x40/0xC0);
; Yvel from raven_coast_dy_* indexed by ix+18 & 3.
raven_pick_vel:
	ld de,0fe00h
	ld hl,00200h
	ld a,(0c427h)
	cp (ix+005h)
	jr c,la7d3h
	ex de,hl
la7d3h:
	ld a,(ix+005h)
	cp 0c0h
	jr nc,la7e3h
	cp 040h
	jr nc,la7e6h
	ld de,00200h
	jr la7e6h
la7e3h:
	ld de,0fe00h
la7e6h:
	call actor_set_xvel
	ld hl,raven_coast_dy_up
	ld a,(0c425h)
	cp (ix+003h)
	jr c,la7f7h
	ld hl,raven_coast_dy_down
la7f7h:
	ld a,(ix+018h)
	and 003h
	add a,a
	call ADD_HL_A
	ld d,(hl)
	inc hl
	ld e,(hl)
	ld a,(ix+003h)
	bit 7,d
	jr z,la812h
	cp 040h
	call c,neg_de
	jp actor_set_yvel
la812h:
	cp 0c0h
	call nc,neg_de
	jp actor_set_yvel
raven_coast_dy_up:             ; (0xA81A) 4 big-endian Yvel words (Simon above)
	defb 0fdh,0e0h, 0fdh,080h, 0fdh,000h, 0fbh,080h
raven_coast_dy_down:           ; (0xA822) Simon below
	defb 002h,020h, 002h,080h, 003h,000h, 003h,080h
; ADD_HL_A_SIGNED (seg3 0xA82A): HL += signed A.  Positive A is ADD_HL_A;
; negative A subtracts from L and borrows from H.
ADD_HL_A_SIGNED:
	bit 7,a
	jp z,ADD_HL_A
	add a,l
	ld l,a
	ret c
	dec h
	ret
; raven_bounds (seg3 0xA834): carry = hit screen edge; force hover (state 2).
raven_bounds:
	ld a,(ix+003h)
	bit 7,(ix+008h)
	jr nz,la843h
	cp 0c0h
	jr nc,la859h
	jr la847h
la843h:
	cp 020h
	jr c,la859h
la847h:
	ld a,(ix+005h)
	bit 7,(ix+00ah)
	jr nz,la856h
	cp 0e8h
	jr nc,la859h
	xor a
	ret
la856h:
	cp 010h
	ret nc
la859h:
	ld (ix+01eh),018h
	ld (ix+001h),002h
	scf
	ret

; ---------------------------------------------------------------------------
;  enemy_dog_tick (seg3 0xA863) - type 05 sitting dog. Idles until Simon is
;  within 64 px (0x40), then charges toward him. 1 HP, 100 pts, 6 contact
;  unshielded. Object list. This path picks the idle frame from proximity.
; ---------------------------------------------------------------------------
enemy_dog_tick:
	ld b,(ix+005h)          ; B = dog position byte (+0x05)
	ld a,(0c427h)           ; A = Simon X (screen)
	cp b                    ; Simon at/past the dog?
	ld a,043h               ; idle frame 0x43 (Simon still far)
	jr nc,la870h
	ld a,03fh               ; idle frame 0x3f (Simon near)
la870h:
	ld (ix+00bh),a          ; store animation frame (+0x0B)
	ld (ix+006h),001h       ; mark actor alive (+0x06 = 1)
	ld (ix+00ch),000h       ; clear anim/state timer (+0x0C)
	ld de,00000h            ; DE = 0 (offset, not the BIOS entry)
	call actor_set_xvel
	jp actor_set_yvel            ; chain to shared actor tail
enemy_dog_go:
	ld a,(ix+005h)
	cp 018h
	jp c,099fdh
	ld a,(ix+001h)
	call DISPATCH_A
	defw dog_idle          ; 0  sit until |Simon X| < 0x40
	defw dog_run           ; 1  charge; leap if no floor
	defw dog_air           ; 2  gravity until floor, then run
dog_idle:
	ld a,(0c427h)
	sub (ix+005h)
	ld de,00400h
	jr nc,la8a8h
	neg
	ld de,0fc00h
la8a8h:
	cp 040h
	ret nc
	call actor_set_xvel
	ld (ix+001h),001h
	ret
dog_run:
	call dog_run_pose
	ld e,(ix+003h)
	ld d,(ix+005h)
	call map_solid_pair
	ret c
	ld de,0fef8h
	call actor_set_yvel
	ld a,(ix+00ah)
	bit 7,a
	ld a,046h
	jr z,la8d1h
	ld a,042h
la8d1h:
	ld (ix+00bh),a
	ld (ix+001h),002h
	ret
dog_air:
	ld de,000a0h
	call actor_add_yvel
	ld e,(ix+003h)
	ld d,(ix+005h)
	call map_solid_pair
	ret nc
	ld b,(ix+005h)
	ld a,(0c427h)
	cp b
	ld de,00400h
	jr nc,la8f8h
	ld de,0fc00h
la8f8h:
	call actor_set_xvel
	ld (ix+00ch),000h
	ld (ix+001h),001h
	ld (ix+002h),000h
	call actor_snap_y8
	ld de,00000h
	jp actor_set_yvel
dog_run_pose:                  ; (0xA910) 3-frame run from facing
	ld a,(ix+00ch)
	inc a
	cp 00dh
	jr c,la91ah
	ld a,001h
la91ah:
	ld (ix+00ch),a
	bit 7,(ix+00ah)
	ld a,(ix+00ch)
	jr z,la92ah
	ld b,041h
	jr la92ch
la92ah:
	ld b,045h
la92ch:
	cp 004h
	jr c,la937h
	inc b
	cp 00ah
	jr c,la937h
	dec b
	dec b
la937h:
	ld (ix+00bh),b
	ret

; ---------------------------------------------------------------------------
;  enemy_zombie_tick (seg3 0xA93B) - behaviour handler for entity type 1, the
;  walking zombie.  Reached via seg0 entity_tbl[type-1] dispatch.  This entry
;  is the spawn/init path: it picks the walk direction from which side of the
;  screen the zombie is on, so it heads toward the centre/Simon.
; ---------------------------------------------------------------------------
enemy_zombie_tick:
	ld (ix+006h),001h       ; mark actor alive (+0x06 = 1)
	ld a,(ix+005h)          ; A = zombie X (+0x05)
	cp 080h                 ; left or right half of the screen?
	ld de,00220h            ; +X velocity (move right)  \ right half
	ld bc,03d00h            ; anim 0x3d, facing 0        /
	jr c,la952h
	ld de,0fde0h            ; -X velocity (move left)   \ left half
	ld bc,03b01h            ; anim 0x3b, facing 1        /
la952h:
	ld (ix+011h),e          ; store 16-bit X velocity (+0x11/+0x12)
	ld (ix+012h),d
	call actor_set_xvel_speedup
	ld (ix+00bh),b          ; walk anim frame (+0x0B = 0x3d / 0x3b)
	ld (ix+00ch),008h       ; anim timer (+0x0C = 8)
	ld (ix+010h),c          ; facing flag (+0x10 = 0 right / 1 left)
	ld de,00000h            ; DE = 0 (offset, not the BIOS entry)
	jp actor_set_yvel            ; chain to shared actor tail
enemy_zombie_go:
	dec (ix+00ch)
	jr nz,la98bh
	ld a,(ix+010h)
	or a
	ld bc,03d3eh
	jr z,la97ch
	ld bc,03b3ch
la97ch:
	ld a,(ix+00bh)
	cp b
	ld a,b
	jr nz,la984h
	ld a,c
la984h:
	ld (ix+00bh),a
	ld (ix+00ch),004h
la98bh:
	ld d,(ix+005h)
	ld e,(ix+003h)
	call map_solid_pair
	jr nc,la9b2h
	ld de,00000h
	call actor_set_yvel
	ld e,(ix+011h)
	ld d,(ix+012h)
	call actor_set_xvel_speedup
	ld (ix+006h),001h
actor_snap_y8:                 ; (0xA9A9) Y &= 0xF8
	ld a,(ix+003h)
	and 0f8h
	ld (ix+003h),a
	ret
la9b2h:
	ld de,00000h
	call actor_set_xvel
	ld de,00060h
	jp actor_add_yvel
enemy_bone_dragon_go:
	ld hl,bone_dragon_follow
	push hl
	ld a,(ix+001h)
	call DISPATCH_A
	defw bone_dragon_form  ; 0  interpolate SAT into place
	defw bone_dragon_idle  ; 1  undulate; then spit
	defw bone_dragon_spit  ; 2  shot_spawn kind 0x0E, loop to idle
bone_dragon_follow:
	ld a,(ix+022h)
	add a,010h
	ld (ix+003h),a
	ld a,(ix+023h)
	add a,008h
	ld (ix+005h),a
	ret
bone_dragon_form:
	push ix
	pop hl
	ld a,l
	add a,023h
	ld l,a
	push ix
	pop hl
	ld e,l
	ld d,h
	set 4,e
	ld a,023h
	add a,l
	ld l,a
	push hl
	push de
	call bone_dragon_sat_nudge
	pop de
	pop hl
	call bone_dragon_sat_nudge
	dec (ix+00ch)
	ret nz
	call bone_dragon_wiggle
	inc (ix+001h)
	ld (ix+00ch),01eh
	ld (ix+018h),020h
	ld (ix+019h),000h
	ret
bone_dragon_idle:
	ld (ix+024h),080h
	ld (ix+029h),084h
	call bone_dragon_wiggle_arm
	push ix
	pop hl
	ld e,l
	set 4,e
	ld d,h
	ld a,022h
	add a,l
	ld l,a
	push hl
	push de
	call bone_dragon_sat_nudge
	pop de
	pop hl
	call bone_dragon_sat_nudge
	dec (ix+00ch)
	ret nz
	ld (ix+00ch),018h
	inc (ix+001h)
	ret
bone_dragon_spit:
	ld (ix+024h),070h
	ld (ix+029h),074h
	dec (ix+00ch)
	jr z,laa65h
	ld a,(ix+00ch)
	cp 008h
	ret nz
	call aim_at_simon
	bit 7,d
	ret z
	ld a,(ix+022h)
	add a,00ch
	ld c,a
	ld b,(ix+023h)
	ld a,00eh
	jp shot_spawn
laa65h:
	ld (ix+00ch),01eh
	ld (ix+001h),001h
	ret
bone_dragon_sat_nudge:         ; (0xAA6E) 8 SAT bytes at HL, ±1 toward DE
	ld b,008h
laa70h:
	ld a,(de)
	inc de
	cp (hl)
	jr z,laa7dh
	ld a,001h
	jr nc,laa7bh
	ld a,0ffh
laa7bh:
	add a,(hl)
	ld (hl),a
laa7dh:
	ld a,005h
	add a,l
	ld l,a
	djnz laa70h
	ret
bone_dragon_wiggle_arm:        ; (0xAA84) RNG reload ix+18, then wiggle
	dec (ix+018h)
	ret nz
	ld a,r
	and 00fh
	add a,010h
	ld (ix+018h),a
bone_dragon_wiggle:            ; (0xAA91) 4 SAT Y pairs from wiggle_ofs
	ld a,(ix+019h)
	inc (ix+019h)
	and 007h
	add a,a
	add a,a
	ld hl,bone_dragon_wiggle_ofs
	call ADD_HL_A
	push ix
	pop de
	set 4,e
	ld b,004h
laaa8h:
	ld a,(hl)
	add a,(ix+01ah)
	ld (de),a
	inc de
	ld (de),a
	inc de
	inc hl
	djnz laaa8h
	ret
bone_dragon_wiggle_ofs:        ; (0xAAB4) 8 x 4 SAT Y offsets
	defb 000h,000h,000h,000h
	defb 0ech,0f2h,0f8h,0feh
	defb 020h,018h,010h,002h
	defb 010h,014h,00ch,002h
	defb 0fch,0fch,004h,0feh
	defb 004h,00ch,000h,002h
	defb 020h,018h,010h,002h
	defb 000h,0f4h,0fch,000h
; enemy_bone_dragon_tick (seg3 0xAAD4) - type 14. 8 SAT cells; this tick
; writes SAT itself (skips 0x644C). 12 HP, 1000 pts.
enemy_bone_dragon_tick:
	ld (ix+00ch),020h
	ld a,(ix+003h)
	ld (ix+01ah),a
	ld a,(ix+005h)
	ld (ix+01bh),a
	push ix
laae6h:
	pop de
	set 4,e
	ld hl,lab25h
	ld b,004h
laaeeh:
	ld a,(hl)
	add a,(ix+01bh)
	ld (de),a
	inc de
	ld (de),a
	inc de
	inc hl
	djnz laaeeh
	ld a,00ah
	add a,e
	ld e,a
	ld bc,008ffh
	ld hl,lab15h
lab03h:
	ld a,(ix+01ah)
	ld (de),a
	inc de
	ld a,(ix+01bh)
lab0bh:
	ld (de),a
	inc de
	ldi
	ldi
	inc e
	djnz lab03h
	ret
lab15h:
	add a,b
	ld (bc),a
	add a,h
	ld c,h
	ld a,b
	ld (bc),a
	ld a,h
	ld c,h
	ld a,b
	ld (bc),a
	ld a,h
	ld c,h
	ld a,b
	ld (bc),a
	ld a,h
	ld c,h
lab25h:
	ret nc
	ret po
	ret p
	nop
; enemy_dracula_tick (seg3 0xAB29) - type 17. Event 6, stage 18 room 9.
; SAT is head + cape (shape 0x56 intro / 0x5B stand). 32x32 body is a
; SCREEN 5 blit: dracula_save_bg stashes the playfield under him to page-1
; (0x80,0x80); dracula_blit_torso LMMMs a 32x32 from dracula_torso_src
; (page-1 Y=0x80: closed cloak / open chest / H-mirrors, filled by
; dracula_body_load).  Portrait eye/mouth 16x16s live at page-1 Y=0xA0
; (dracula_portrait_parts) and stamp the wall painting, not this figure.
; 32 HP on the bar.
enemy_dracula_tick:
	ld (ix+006h),000h
	ld de,0fe00h
	call actor_set_yvel
	ld de,00000h
	call actor_set_xvel
	ld (ix+00bh),056h
	ld (ix+00ch),01eh
	xor a
	ld (ix+010h),a
	ld (ix+00eh),a
	ret
enemy_dracula_go:
	ld hl,dracula_store_x
	push hl
	ld a,(ix+001h)
	call DISPATCH_A
	defw dracula_intro,dracula_drop,dracula_idle,dracula_idle_cast,dracula_fireballs
	defw dracula_rise,dracula_teleport,dracula_idle_post,dracula_summon,dracula_done
dracula_store_x:
	ld a,(ix+005h)
	ld (0ce0fh),a
	ret
dracula_intro:
	ld a,(0c427h)
	sub (ix+005h)
	ld c,056h
	jr c,lab7ah
	inc c
	inc c
lab7ah:
	ld (ix+00bh),c
	dec (ix+00ch)
	ret nz
	ld (ix+006h),001h
	ld a,(ix+003h)
	ld (ix+011h),a
	jr dracula_next
dracula_drop:
	ld a,(ix+011h)
	sub (ix+003h)
	cp 040h
	ret c
	ld a,(ix+003h)
	add a,030h
	ld (ix+003h),a
	ld (ix+006h),000h
	ld (ix+00bh),05bh
	ld a,01eh
	ld (ix+00ch),a
	call dracula_save_bg
dracula_next:
	inc (ix+001h)
	ret
dracula_idle:
	ld c,000h
	ld hl,dracula_pose_idle
	call actor_set_pose_facing
	call dracula_sat_color
	bit 0,(ix+00ch)
	call nz,dracula_sat_hide_body
	call dracula_torso_from_shape
	dec (ix+00ch)
	ret nz
	call dracula_sat_color
	call dracula_torso_select
	ld (ix+00ch),004h
	ld (ix+00eh),007h
	jr dracula_next
dracula_idle_cast:
	dec (ix+00ch)
	ret nz
	ld c,001h
	ld hl,dracula_pose_idle
	call actor_set_pose_facing
	call dracula_torso_select
	ld (ix+00ch),004h
	jr dracula_next
dracula_fireballs:
	dec (ix+00ch)
	ret nz
	ld hl,00000h
	call dracula_spawn_fireball
	ld hl,00180h
	call dracula_spawn_fireball
	ld hl,0fe80h
	call dracula_spawn_fireball
	ld (ix+00ch),01eh
	jr dracula_next
dracula_spawn_fireball:
	ld a,(0c427h)
	cp (ix+005h)
	ld de,00280h
	jr nc,lac1ah
	ld de,0fd80h
lac1ah:
	ld a,(ix+003h)
	sub 018h
	ld c,a
	ld b,(ix+005h)
	ld a,011h
	jp shot_spawn
dracula_rise:
	dec (ix+00ch)
	ret nz
	call dracula_sat_hide
	ld a,005h
	ld (0ce0eh),a
	ld a,(ix+003h)
	sub 040h
	ld (ix+003h),a
	ld (ix+00ch),05ah
	ld (ix+00eh),000h
	jp dracula_next
dracula_teleport:
	dec (ix+00ch)
	ret nz
	ld a,(ix+003h)
	add a,040h
	ld (ix+003h),a
	ld c,000h
	ld hl,dracula_pose_idle
	call actor_set_pose_facing
	ld hl,dracula_warp_x
	ld a,(ix+010h)
	cp 007h
	jr c,lac69h
	ld (ix+010h),0ffh
lac69h:
	call ADD_HL_A
	ld a,(hl)
	ld (ix+005h),a
	call dracula_save_bg
	inc (ix+010h)
	ld (ix+00ch),01eh
	jp dracula_next
dracula_warp_x:
	defb 030h,0d0h,050h,0a0h,040h,0c0h,080h,0b0h
dracula_idle_post:
	ld c,000h
	ld hl,dracula_pose_idle
	call actor_set_pose_facing
	call dracula_sat_color
	bit 0,(ix+00ch)
	call nz,dracula_sat_hide
	call dracula_torso_from_shape
	dec (ix+00ch)
	ret nz
	call dracula_sat_color
	call dracula_torso_select
	ld (ix+00ch),004h
	ld (ix+001h),003h
	ld (ix+00eh),007h
	ret
dracula_pose_idle:
	defb 05bh,05ch,05dh,05eh
dracula_summon:
	call dracula_torso_select
	xor a
	ld (ix+025h),a         ; hide SAT colours (cells 0-3)
	ld (ix+02ah),a
	ld (ix+02fh),a
	ld (ix+034h),a
	ld (ix+00eh),a         ; not hittable
	ld (ix+00ch),03ch
	inc (ix+001h)
	call shot_pool_clear
	ld a,(ix+003h)
	sub 02bh
	ld e,a                 ; Y - 0x2B
	ld d,(ix+005h)         ; X
	ld c,actor_dracula_head
	jp spawn_actor
dracula_done:
	dec (ix+00ch)
	ret nz
	ld a,001h
	ld (0ce16h),a          ; event_dracula_wait
	call dracula_torso_hide
	jp actor_free
; dracula_head_init (seg3 0xACEF) - actor_dracula_head spawn. Intro SAT
; head (0x57 / 0x59) arcs away from Simon (Yvel -0x0300, then gravity).
dracula_head_init:
	ld (ix+006h),001h      ; physics on
	ld (ix+00eh),000h      ; not hittable
	ld (ix+07eh),000h      ; no whip-freeze
	ld a,(0c427h)          ; Simon X
	cp (ix+005h)
	ld c,057h              ; shape_dracula_intro_1
	ld de,00300h           ; +X if Simon is left (away)
	jr c,lad0dh
	ld de,0fd00h           ; -X
	ld c,059h              ; shape_dracula_intro_1_l
lad0dh:
	ld (ix+00bh),c
	call actor_set_xvel
	ld de,0fd00h           ; launch up
	jp actor_set_yvel
dracula_head_go:               ; (0xAD19) gravity +0x50 / frame
	ld de,00050h
	jp actor_add_yvel
; shot_pool_clear (seg3 0xAD1F): free B slots from D700. summon does not
; load B; c800_tick left it as remaining C800 count (pushed around the tick).
shot_pool_clear:
	push ix
	ld ix,0d700h
	jr shot_pool_free_loop
; c800_pool_clear (seg3 0xAD26): free all 7 C800 slots. No caller.
c800_pool_clear:
	push ix
	ld ix,0c800h
	ld b,007h
shot_pool_free_loop:
	push bc
	call actor_free
	ld de,00080h
	add ix,de
	pop bc
	djnz shot_pool_free_loop
	pop ix
	ret
; actor_set_pose_facing (0xAD3E): ix+0B = (HL)[C] or (HL)[C+2] if Simon is
; to the right of the actor.  Shared by Dracula and the axe knight.
actor_set_pose_facing:
	ld a,(0c427h)
	cp (ix+005h)
	jp c,actor_set_pose
	inc c
lad48h:
	inc c
	jp actor_set_pose
dracula_sat_color:
	ld b,008h
	ld de,00025h
lad51h:
	ld hl,dracula_sat_cols
	call dracula_sat_color_from
	djnz lad51h
	ret
dracula_sat_cols:
	defb 002h,048h,002h,048h,002h,048h,002h,048h
; dracula_sat_hide (0xAD62): colour 0 on all 8 cells (rise / idle_post flicker).
dracula_sat_hide:
	ld b,008h
	ld e,025h
	jr lad6ch
; dracula_sat_hide_body (0xAD68): colour 0 on cells 4-7 (lower cape; idle flicker).
dracula_sat_hide_body:
	ld b,004h
	ld e,039h
lad6ch:
	ld c,000h
lad6eh:
	call dracula_sat_write_color
	djnz lad6eh
	ret
dracula_sat_color_from:
	ld a,d
	call ADD_HL_A
	ld c,(hl)
dracula_sat_write_color:
	push ix
	pop hl
	ld a,e
	call ADD_HL_A
	ld (hl),c
	inc d
	ld a,e
	add a,005h
	ld e,a
	ret
; dracula_save_bg (0xAD87): HMMM 32x32 from playfield (X-16, Y=0x91) page 0
; to page 1 (0x80,0x80), covering the last torso slot.  Called on land/teleport.
dracula_save_bg:
	ld a,(ix+005h)
	sub 010h
	ld h,a
	ld l,091h
	ld de,08080h
	ld bc,02020h
	ld a,004h
	jp vdp_hmmm
; dracula_blit_torso (0xAD9A): if CE0E was 1..5, copy that torso slot onto
; (CE0F-16, Y=0x91).  Index 5 (SX=0x80) is the saved background (HMMM);
; 0..3 are cloak/chest frames from dracula_body_load (LMMM, colour 0 skip).
dracula_blit_torso:
	ld hl,0ce0eh
	ld a,(hl)
	dec a
	ret m
	ld (hl),000h
	ld de,dracula_torso_src
	call lookup_word_tbl
	ex de,hl
	ld a,(0ce0fh)
	sub 010h
	ld d,a
	ld e,091h
	ld bc,02020h
	ld a,h
	cp 080h
	jr z,ladbeh
	ld a,048h
	jp vdp_lmmm
ladbeh:
	ld a,001h
	jp vdp_hmmm
dracula_torso_src:
	defw 00080h,02080h,04080h,06080h,08080h
dracula_torso_hide:
	ld a,005h
	ld (0ce0eh),a
	ret
dracula_torso_from_shape:
	bit 0,(ix+00ch)
	jr nz,dracula_torso_hide
dracula_torso_select:
	ld a,(ix+00bh)
	sub 05ah
	cp 005h
	ret nc
	ld (0ce0eh),a
	ret
; enemy_axe_knight_tick (seg3 0xADE5) - type 16. Same SAT layout as type 9,
; stage 14+ VRAM is the knight. Throws via shot_throw (0x9F68). 8 HP, 300
; pts, walk 0x0140. Shape 0x5F.
enemy_axe_knight_tick:
	ld (ix+006h),001h
	ld de,00000h
	call actor_set_yvel
	call actor_set_xvel_speedup
	ld (ix+00bh),05fh
	ld (ix+010h),000h
	ld (ix+011h),03ch
	ret
enemy_axe_knight_go:
	bit 0,(ix+001h)
	jr nz,lae3dh
	ld d,(ix+005h)
	ld e,(ix+003h)
	call map_solid_pair
	jr c,lae13h
	jp lb345h
lae13h:
	ld a,(ix+003h)
	and 0f0h
	ld (ix+003h),a
	inc (ix+001h)
	ld de,00140h
	ld (ix+00bh),061h
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,lae34h
	ld de,0fec0h
	ld (ix+00bh),05fh
lae34h:
	call actor_set_xvel_speedup
	ld de,00000h
	jp actor_set_yvel
lae3dh:
	call axe_knight_walk_pose
	ld a,010h
	bit 7,(ix+00ah)
	jr z,lae4ah
	ld a,0f8h
lae4ah:
	add a,(ix+005h)
	ld d,a
	ld e,(ix+003h)
	call map_solid_pair
	jp nc,laefdh
	ld d,(ix+005h)
	ld bc,00808h
	bit 7,(ix+00ah)
	jr nz,lae68h
	call probe_wall_right
	jr lae6bh
lae68h:
	call probe_wall_left
lae6bh:
	jp c,laefdh
	ld (ix+006h),001h
	call simon_dx_abs
	cp 02eh
	jr nc,lae90h
	ld de,00140h
	ld a,(0c427h)
	cp (ix+005h)
	jr c,lae87h
	ld de,0fec0h
lae87h:
	call actor_set_xvel_speedup
	ld (ix+010h),001h
	jr laea9h
lae90h:
	cp 05ch
	jr c,laea9h
	ld de,00140h
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,laea2h
	ld de,0fec0h
laea2h:
	call actor_set_xvel_speedup
	ld (ix+010h),000h
laea9h:
	ld a,(ix+005h)
	cp 0f0h
	call nc,actor_halt_if_rightward
	cp 00fh
	call c,actor_halt_if_leftward
laeb6h:
	bit 1,(ix+001h)
	jr nz,laef0h
	call simon_dx_abs
	cp 02ah
	jr nc,laee6h
	bit 0,(ix+010h)
	ret z
laec8h:
	set 1,(ix+001h)
	push ix
	pop hl
	ld (0cffch),hl
	ld hl,00000h
	ld de,00400h
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,laee3h
	ld de,0fc00h
laee3h:
	jp shot_throw
laee6h:
	cp 060h
	ret c
	bit 0,(ix+010h)
	ret nz
	jr laec8h
laef0h:
	dec (ix+011h)
	ret nz
	ld (ix+011h),03ch
	res 1,(ix+001h)
	ret
laefdh:
	ld (ix+006h),000h
	call simon_dx_abs
	cp 03eh
	jr c,laf13h
	cp 04ch
	jr nc,laf19h
	ld (ix+006h),001h
	jp actor_flip_xvel
laf13h:
	ld (ix+010h),001h
	jr laeb6h
laf19h:
	ld (ix+010h),000h
	jr laeb6h
axe_knight_walk_pose:          ; (0xAF1F) poses 0x5F-0x62 from frame + facing
	ld c,000h
	ld a,(0c003h)
	and 008h
	jr z,laf29h
	inc c
laf29h:
	ld hl,axe_knight_walk_tbl
	jp actor_set_pose_facing
axe_knight_walk_tbl:           ; (0xAF2F) poses 0x5F-0x62
	defb 05fh,060h,061h,062h
actor_halt_if_rightward:           ; (seg3 0xAF33) if Xvel >= 0, +6 = 0 (right-edge stop)
	bit 7,(ix+00ah)
	ret nz
	ld (ix+006h),000h
	ret
actor_halt_if_leftward:            ; (seg3 0xAF3D) if Xvel < 0, +6 = 0 (left-edge stop)
	bit 7,(ix+00ah)
	ret z
	ld (ix+006h),000h
	ret
simon_dx_abs:                      ; (seg3 0xAF47) A = |Simon X - actor X|
	ld a,(0c427h)
	sub (ix+005h)
	ret nc
	neg
	ret
; enemy_red_skeleton_tick (seg3 0xAF51) - type 09. Fast walk (0x0220), no
; projectile. 2 HP, 200 pts. Stage 13 (SAT 02 45). Same skeleton script as 11.
enemy_red_skeleton_tick:
	ld de,00000h
	call actor_set_yvel
	ld (ix+011h),030h
	xor a
	ld (ix+02fh),a
	ld (ix+034h),a
	ld (ix+00eh),a
	ret
enemy_red_skeleton_go:
	ld a,(ix+001h)
	call DISPATCH_A
	defw red_skel_wake     ; 0  pose 0x26 legs-only wait
	defw red_skel_walk     ; 1  fast walk, turn at walls
	defw red_skel_pause    ; 2  4-frame halt, then walk
red_skel_wake:
	dec (ix+011h)
	jr z,laf85h
	ld c,026h
	ld a,(ix+011h)
	cp 00ch
	jr nc,laf81h
	dec c
laf81h:
	ld (ix+00bh),c
	ret
laf85h:
	ld (ix+00eh),007h
	ld a,(ix+025h)
	ld (ix+02fh),a
	ld (ix+034h),045h
	call red_skel_face
	ld (ix+00ch),010h
	inc (ix+001h)
	ld (ix+006h),001h
	ret
red_skel_face:                 ; (0xAFA2) pose/Xvel toward Simon
	ld a,(0c427h)
	sub (ix+005h)
	jr c,lafb7h
	ld (ix+012h),000h
	ld (ix+00bh),021h
	ld de,00220h
	jr lafc2h
lafb7h:
	ld (ix+012h),001h
	ld (ix+00bh),023h
	ld de,0fde0h
lafc2h:
	jp actor_set_xvel_speedup
red_skel_walk:
	ld a,(ix+005h)
	bit 7,(ix+00ah)
	ld c,010h
	jr z,lafd2h
	ld c,0f0h
lafd2h:
	add a,c
	ld d,a
	ld e,(ix+003h)
	call map_solid_pair
	jr nc,lb004h
	ld d,(ix+005h)
	ld e,(ix+003h)
	ld b,008h
	ld c,008h
	ld a,(ix+012h)
	and a
	jr nz,laff8h
	ld a,(ix+005h)
	cp 0f0h
	jr nc,lb004h
	call probe_wall_right
	jr lb002h
laff8h:
	ld a,(ix+005h)
	cp 010h
	jr c,lb004h
	call probe_wall_left
lb002h:
	jr nc,lb018h
lb004h:
	ld a,(ix+012h)
	xor 001h
	ld (ix+012h),a
	ld e,(ix+009h)
	ld d,(ix+00ah)
	call neg_de
	call actor_set_xvel_speedup
lb018h:
	bit 2,(ix+00ch)
	ld c,021h
	jr z,lb021h
	inc c
lb021h:
	ld a,(ix+012h)
	and a
	jr nz,lb029h
	inc c
	inc c
lb029h:
	ld (ix+00bh),c
	dec (ix+00ch)
	ret nz
	ld (ix+006h),000h
	ld (ix+00ch),004h
	inc (ix+001h)
	ret
red_skel_pause:
	dec (ix+00ch)
	ret nz
	call red_skel_face
	ld (ix+00ch),030h
	ld (ix+006h),001h
	dec (ix+001h)
	ret
	ld (ix+011h),040h
	xor a
	ld (ix+006h),a
	ld (ix+00eh),a
	ld (ix+02fh),a
	ld (ix+034h),a
	ld (ix+00bh),026h
	ld (ix+001h),a
	ret
; enemy_flying_skull_tick (seg3 0xB068) - type 07. Homes on Simon X and Y.
enemy_flying_skull_tick:
	ld (ix+006h),001h
	ld (ix+010h),000h
	ld (ix+00ch),001h
	bit 7,(ix+00ah)
	ld c,016h
	jr nz,lb07dh
	inc c
lb07dh:
	ld (ix+00bh),c
	jr lb08dh
enemy_flying_skull_go:
	call flying_skull_pose
	dec (ix+00ch)
	ret nz
	ld (ix+00ch),010h
lb08dh:
	ld a,(0c425h)
	ld de,0ff00h
	inc a
	cp (ix+003h)
	jr c,lb0a6h
	ld de,00100h
	sub 018h
	cp (ix+003h)
	jr nc,lb0a6h
	ld de,00000h
lb0a6h:
	call actor_set_yvel
	ld de,0fee0h
	ld hl,0c427h
	ld a,(ix+005h)
	sub (hl)
	jr nc,lb0b8h
	ld de,00120h
lb0b8h:
	call actor_set_xvel
	ret
flying_skull_pose:             ; (0xB0BC) poses 0x16-0x19 from timer + facing
	ld a,016h
	bit 2,(ix+00ch)
	jr z,lb0c5h
	inc a
lb0c5h:
	bit 7,(ix+00ah)
	jr nz,lb0cdh
	add a,002h
lb0cdh:
	ld (ix+00bh),a
	ret
; enemy_hanging_bat_tick (seg3 0xB0D1) - type 04 (generator) and list-id 0x1F.
; Play-confirmed for 0x1F: hangs (pose 0x1A) until Simon is close (Y window
; 0x50, X 0x40), then flies at him. Type 4 sets state 2 (already flying in).
; Object-list 0x1F enters at enemy_placed_bat_init so ix+1 stays 0 (hang first).
; Shared tick 0xB0FF. 1 HP, 100 pts.
enemy_hanging_bat_tick:
	ld (ix+001h),002h      ; type 4: start in fly-in state
enemy_placed_bat_init:         ; type 0x1F (s3r2, s4r1, s4r3): hang first
	ld de,00180h
	call actor_set_yvel
	ld de,00300h
	ld a,(0c427h)
	sub (ix+005h)
	call c,neg_de
	call actor_set_xvel_speedup
	ld (ix+006h),001h
	ld (ix+011h),000h
	ld a,(ix+002h)
	ld (ix+012h),a
	ld a,(ix+003h)
	ld (ix+013h),a
	ret
hanging_bat_go:
	ld a,(ix+001h)
	dec a
	jr z,hanging_bat_swoop
	dec a
	jp z,hanging_bat_bob
hanging_bat_hang:
	ld (ix+00bh),01ah
	ld (ix+006h),000h
	ld a,(0c425h)
	sub (ix+003h)
	cp 050h
	ret nc
	ld c,01bh
	ld a,(0c427h)
	sub (ix+005h)
	ld de,00180h
	jr nc,lb12eh
	ld de,0fe80h
	neg
	ld c,01eh
lb12eh:
	cp 040h
	ret nc
	ld (ix+00bh),c
	call actor_set_xvel
	ld (ix+006h),001h
	ld de,00180h
	call actor_set_yvel
	inc (ix+001h)
	ret
hanging_bat_swoop:
	ld a,(0c425h)
	sub (ix+005h)
	sub 004h
	cp 010h
	jr nc,hanging_bat_flap
	ld a,(ix+003h)
	ld (ix+013h),a
	ld (ix+015h),000h
	ld (ix+001h),002h
hanging_bat_flap:                  ; (seg3 0xB15F) wing pose; three rras (placed bat)
	ld a,(ix+011h)
	rra
	rra
hanging_bat_flap_slow:             ; (seg3 0xB164) one rra (dracula_bat / hanging_bat_pose)
	rra
	inc (ix+011h)
	and 003h
	ld hl,hanging_bat_pose_r
	bit 7,(ix+00ah)
	jr z,lb176h
	ld hl,hanging_bat_pose_l
lb176h:
	call ADD_HL_A
	ld a,(hl)
	ld (ix+00bh),a
	ret
hanging_bat_pose_r:
	defb 01eh,01fh,01eh,020h
hanging_bat_pose_l:
	defb 01bh,01ch,01bh,01dh
hanging_bat_bob:
	call hanging_bat_flap
	ld de,00019h
	ld a,(ix+003h)
	cp (ix+013h)
	jr c,lb197h
	ld de,0ffe7h
lb197h:
	jp actor_add_yvel
; enemy_roc_tick (seg3 0xB19A) - actor_roc. 6-cell flyer; init reuses
; enemy_hunchback_tick (RNG timer + pose 0x67, skipped type-13 hide), then
; spawn_actor actor_roc_drop. Per-frame flaps 0x6D/0x6E/0x8D; pauses 8
; frames when Simon X is within 0x38, then continues off. 8 HP, 400 pts.
enemy_roc_tick:
	call enemy_hunchback_tick
	ld (ix+011h),000h
	ld c,actor_roc_drop
	ld a,(ix+003h)
	add a,00ch
	ld e,a
	ld a,(ix+005h)
	cp 080h
	ld b,0fdh
	jr c,lb1b4h
	ld b,004h
lb1b4h:
	add a,b
	ld d,a
	push ix
	call spawn_actor
	pop ix
	ld a,(0cf31h)
	and a
	ret nz
	ld a,001h
	ld (0cf0ch),a
	jp 099fdh
enemy_roc_go:
	call roc_flap
	bit 0,(ix+001h)
	jr nz,lb1e5h
	call simon_dx_abs
	cp 038h
	ret nc
	ld (ix+00ch),008h
	ld (ix+006h),000h
	inc (ix+001h)
	ret
lb1e5h:
	dec (ix+00ch)
	ret nz
	ld (ix+006h),001h
	ret
roc_flap:                      ; (0xB1EE) poses 0x6D/0x6E/0x8D
	inc (ix+011h)
	ld c,000h
	ld a,(ix+011h)
	cp 007h
	jr c,lb210h
	ld c,001h
	cp 00dh
	jr c,lb210h
	ld c,002h
	cp 013h
	jr c,lb210h
	ld c,001h
	cp 018h
	jr c,lb210h
	ld (ix+011h),000h
lb210h:
	ld hl,roc_flap_tbl
	jp actor_set_pose
roc_flap_tbl:                  ; (0xB216) poses 0x6D, 0x6E, 0x8D
	defb 06dh,06eh,08dh
; enemy_hunchback_tick (seg3 0xB219) - type 13. Jumps toward Simon (pose
; 0x67, shared with Igor type 24). Type 15 roc calls this as shared init
; (RNG timer); the cp 0x0D skip is so the roc does not take the type-13
; hide/state-4 path. 1 HP, 200 pts.
enemy_hunchback_tick:
	ld (ix+006h),001h
	ld a,r
	srl a
	srl a
	srl a
	ld b,a
	ld a,03ch
	sub b
	ld (ix+00ch),a
	ld a,(ix+000h)
	cp 00dh
	jr nz,lb23bh            ; not type 13 (roc shares this init): skip hide
	ld (ix+001h),004h
	ld (ix+006h),000h
lb23bh:
	ld de,0fd80h
	ld (ix+00bh),067h
	ld (ix+010h),001h
	call actor_set_xvel
	ld de,00000h
	jp actor_set_yvel
hunchback_go:
	ld a,(ix+001h)
	call DISPATCH_A
	defw hunchback_wait    ; 0  until |Simon X| < 0x3C
	defw hunchback_drop    ; 1  gravity, then crouch
	defw hunchback_crouch  ; 2  2-frame squat, then jump
	defw hunchback_jump    ; 3  air; land -> crouch
	defw hunchback_hide    ; 4  type-13 spawn: hidden until Simon close
hunchback_wait:
	call simon_dx_abs
	cp 03ch
	ret nc
	ld de,00000h
	call actor_set_xvel
	inc (ix+001h)
	ret
hunchback_drop:
	call lb345h
	ld d,(ix+005h)
	ld e,(ix+003h)
	call map_solid_pair
	jr c,lb27dh
lb27dh:
	inc (ix+001h)
lb280h:
	call actor_snap_y8
	ld (ix+006h),000h
	ld (ix+00ch),002h
	ret
hunchback_crouch:
	ld c,000h
	ld hl,lb341h
	call actor_set_pose_facing
	dec (ix+00ch)
	ret nz
	inc (ix+001h)
	ld de,0fda0h
	ld a,(ix+003h)
	cp 050h
	jr c,lb2aeh
	ld a,r
	and 003h
	jr nz,lb2aeh
	ld de,0f8e0h
lb2aeh:
	call actor_set_yvel
lb2b1h:
	ld (ix+006h),001h
	ld de,00220h
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,lb2c3h
	ld de,0fde0h
lb2c3h:
	call actor_set_xvel
	ld c,001h
	ld hl,lb341h
	jp actor_set_pose_facing
hunchback_jump:
	call lb345h
	call actor_wall_ahead
	ld de,00000h
	call c,actor_flip_xvel
	ld d,(ix+005h)
	ld e,(ix+003h)
	bit 7,(ix+008h)
	jr z,lb2f4h
	ld a,e
	sub 010h
	ld e,a
	call map_solid_pair
	ret nc
	ld de,00000h
	jp actor_set_yvel
lb2f4h:
	call map_solid_pair
	ret nc
	ld c,000h
	ld hl,lb341h
	call actor_set_pose_facing
	ld (ix+001h),002h
	jp lb280h
actor_wall_ahead:              ; (0xB307) probe wall in Xvel direction
	ld d,(ix+005h)
	ld e,(ix+003h)
	ld bc,00808h
	ld a,(ix+00ah)
	or (ix+009h)
	ret z
	bit 7,(ix+00ah)
	jp nz,actor_wall_left
	jp actor_wall_right
hunchback_hide:
	ld c,000h
	ld hl,lb341h
	call actor_set_pose_facing
	call simon_dx_abs
	cp 03ch
	jr c,lb334h
	dec (ix+00ch)
	ret nz
lb334h:
	ld de,0ffffh
	call actor_set_yvel
	ld (ix+001h),003h
	jp lb2b1h
lb341h:
	ld h,a
	ld l,b
	ld l,d
	ld l,e
lb345h:
	ld de,000a0h
	jp actor_add_yvel
; enemy_white_skeleton_tick (seg3 0xB34B) - type 11. Kites Simon (walk
; toward if far, away if close), hops a gap when the floor probe ahead is
; empty (Yvel 0xFB8F), then throws a spinning bone via shot_throw (kind 11
; -> shot type 4, shapes 0x4B-0x4E). 4 HP, 200 pts. SAT 02 4C. Walk poses
; 0x47-0x4A; same skeleton art as type 9. Stages 7-9, 13, 17.
; ix+01 states: 0 walk, 1 air, 2 throw windup.
enemy_white_skeleton_tick:
	ld a,(0c427h)          ; Simon X
	ld b,(ix+005h)         ; skeleton X
	cp b
	ld de,00240h           ; walk right if Simon is to the right
	jr nc,lb35ah
	ld de,0fdc0h           ; else left
lb35ah:
	call actor_set_xvel_speedup
	ld de,00000h            ; Yvel = 0
	call actor_set_yvel
	ld (ix+006h),001h      ; alive / visible
	ld (ix+011h),000h
white_skel_set_pose:           ; (0xB36B) walk frames 0x47/48 (left) or 0x49/4A
	ld a,(0c427h)
	cp (ix+005h)
	ld c,047h              ; facing left pair
	jr c,lb377h
	ld c,049h              ; facing right pair
lb377h:
	inc (ix+012h)          ; walk-anim counter
	bit 3,(ix+012h)
	jr nz,lb381h
	inc c                  ; alternate the pair every 8 frames
lb381h:
	ld (ix+00bh),c         ; pose
	ret
white_skel_go:
	call white_skel_set_pose
	ld a,(ix+001h)         ; per-frame: dispatch on walk / air / throw
	call DISPATCH_A
	defw white_skel_walk   ; 0  kite, throw trigger, ledge hop
	defw white_skel_air    ; 1  gravity until floor
	defw white_skel_throw  ; 2  16-frame windup, then shot_throw
white_skel_walk:               ; (0xB394)
	ld a,(0c427h)          ; Simon X
	ld b,a
	ld a,(ix+005h)
	add a,030h
	sub b
	cp 060h                ; |skelX+0x30 - SimonX| < 0x60 -> close: walk away
	jr nc,lb3b0h
	ld a,(ix+005h)
	cp b
	ld de,0fdc0h           ; Simon is to the right -> walk left
	jr c,lb3cah
	ld de,00240h           ; else walk right
	jr lb3cah
lb3b0h:
	ld a,(0c427h)
	ld b,a
	ld a,(ix+005h)
	add a,050h
	sub b
	cp 0a0h                ; mid range: skip the walk-toward, go to collision
	jr c,lb3e2h
	ld a,(ix+005h)
	cp b
	ld de,00240h           ; far: walk toward Simon
	jr c,lb3cah
	ld de,0fdc0h
lb3cah:
	call actor_set_xvel_speedup
	ld a,(ix+012h)
	and 006h               ; every 8 counts, 2 frames of the cycle
	jr nz,lb3e2h
	ld (ix+010h),010h      ; throw windup = 16 frames
	ld (ix+001h),002h      ; -> state 2
	ld (ix+006h),000h
	jr lb43eh
lb3e2h:
	ld e,(ix+003h)         ; wall probe at (X, Y)
	ld d,(ix+005h)
	ld bc,0080ch
	ld a,(ix+00ah)
	and 080h
	jr nz,lb3ffh
	call probe_wall_right            ; wall to the right?
	jr nc,lb40ah
	ld de,0fdc0h           ; bounce left
	call actor_set_xvel_speedup
	jr lb40ah
lb3ffh:
	call probe_wall_left            ; wall to the left?
	jr nc,lb40ah
	ld de,00240h           ; bounce right
	call actor_set_xvel
lb40ah:
	ld e,(ix+003h)         ; floor probe a few px ahead of travel
	ld a,(ix+00ah)
	or a
	ld b,004h              ; xvel 0: +4
	jr z,lb41ch
	ld b,009h              ; walking right: +9
	jp p,lb41ch
	ld b,0fch              ; walking left: -4
lb41ch:
	ld a,(ix+005h)
	add a,b
	ld d,a
	call map_solid_pair            ; carry = solid floor at (D, E)
	jr c,lb43eh            ; floor there: stay grounded
	ld de,00240h
	bit 7,(ix+00ah)
	call nz,neg_de      ; keep travel direction
	call actor_set_xvel
	ld de,0fb8fh           ; hop: Yvel ~ -4.5 px/frame
	call actor_set_yvel
	ld (ix+001h),001h      ; -> state 1 (air)
	ret
lb43eh:
	ld a,(ix+005h)         ; screen-edge clamp, else keep current xvel
	cp 010h
	ld de,00240h
	jr c,lb455h
	cp 0eeh
	ld de,0fdc0h
	jr nc,lb455h
	ld e,(ix+009h)
	ld d,(ix+00ah)
lb455h:
	jp actor_set_xvel_speedup
white_skel_air:                ; (0xB458)
	ld bc,0080ch
	ld e,(ix+003h)
	ld d,(ix+005h)
	bit 7,(ix+00ah)
	jr z,lb46eh
	call probe_wall_left            ; still facing a wall? stop xvel
	jr nc,lb479h
	jr lb473h
lb46eh:
	call probe_wall_right
	jr nc,lb479h
lb473h:
	ld de,00000h
	call actor_set_xvel
lb479h:
	ld de,00068h           ; gravity
	call actor_add_yvel
	bit 7,(ix+008h)
	ret nz                 ; still going up
	ld e,(ix+003h)
	ld a,(ix+00ah)
	bit 7,a
	ld b,008h              ; landing probe X offset from facing
	jr nz,lb497h
	ld b,0fdh
	and a
	jr nz,lb497h
	ld b,005h
lb497h:
	ld a,(ix+005h)
	add a,b
	ld d,a
	call map_solid_pair
	ret nc                 ; no floor yet
	xor a
	ld (ix+001h),a         ; landed -> walk
	ld (ix+002h),a
	call actor_snap_y8         ; snap Y to 8 px
	ld de,00000h
	jp actor_set_yvel
white_skel_throw:              ; (0xB4B0)
	dec (ix+010h)
	ret nz                 ; windup
	ld a,r
	rra                    ; coin-flip throw height
	ld hl,0fb00h           ; bone Yvel -5 px/frame
	jr nc,lb4bfh
	ld hl,0f800h           ; or -8 (higher arc)
lb4bfh:
	ld a,(0c427h)
	cp (ix+005h)
	ld de,00180h           ; bone Xvel toward Simon
	jr nc,lb4cdh
	ld de,0fe80h
lb4cdh:
	call shot_throw        ; kind 11 -> shot type 4 (shot_bone)
	ld (ix+001h),000h      ; back to walk
	ld (ix+006h),001h
	ret
; enemy_blob_tick (seg3 0xB4D9) - actor_blob_blue/_red/_white (also 0x19).
; Hatched from bonus-21 slime if the pickup is left to land.  2 SAT cells
; (shape 0x9B/0x9C anim, pats D0/D8 = spr_blob / spr_blob_cc).  1 HP.
; Recolour is the SAT pair: 0F 42 blue, 08 42 red, 0E 42 white (HUD-fixed).
enemy_blob_tick:
	call blob_set_pose
	ld (ix+006h),001h
	ld de,00000h
	ld (ix+00eh),e
	call actor_set_xvel
	call actor_set_yvel
	ld (ix+010h),008h
	ret
enemy_blob_go:
	call blob_set_pose
	ld a,(ix+001h)
	call DISPATCH_A
	defw blob_hatch        ; 0  wait ix+10, then fall
	defw blob_fall         ; 1  gravity until floor
	defw blob_pause        ; 2  grounded wait, then hop
	defw blob_hop          ; 3  hop; land -> pause
blob_hatch:
	call blob_hatch_wait
	ret nz
	ld de,00200h
	call actor_set_yvel
	ld (ix+00eh),007h
	inc (ix+001h)
	ret
blob_fall:
	call blob_fall_step
	ret nc
	jr lb552h
blob_pause:
	ld (ix+006h),000h
	dec (ix+010h)
	ret nz
	call blob_chase_x
	ld (ix+010h),01eh
	inc (ix+001h)
	ret
blob_hop:
	ld (ix+006h),001h
	call blob_set_pose
	call blob_can_rise
	jp nc,lb595h
	call blob_floor
	jp nc,lb5f6h
	call blob_wall_ahead
	ld de,00000h
	call c,actor_set_xvel
	call blob_at_edge
	jr c,lb552h
	dec (ix+010h)
	ret nz
lb552h:
	ld de,00000h
	call actor_set_yvel
	call actor_set_xvel
	ld a,(ix+003h)
	and 0f8h
	ld (ix+003h),a
	ld (ix+006h),000h
	ld (ix+010h),01eh
	ld (ix+001h),002h
	ret
blob_fall_step:                ; (0xB570) wall, floor, gravity; C = landed
	call blob_wall_ahead
	ld de,00000h
	call c,actor_set_xvel
	call blob_floor
	jr c,lb586h
	ld de,00040h
	call actor_add_yvel
	xor a
	ret
lb586h:
	ld a,(ix+003h)
	and 0f8h
	ld (ix+003h),a
	scf
	ret
blob_hatch_wait:               ; (0xB590) dec ix+10; Z when 0
	dec (ix+010h)
	ret nz
	ret
lb595h:
	ld (ix+001h),001h
	call blob_chase_x
	ld de,00200h
	ld de,0fd00h
	jp actor_set_yvel
blob_at_edge:                  ; (0xB5A5) C if X at 0x10/0xE8 in travel dir
	ld a,(ix+005h)
	bit 7,(ix+00ah)
	jr z,lb5b1h
	cp 010h
	ret
lb5b1h:
	cp 0e8h
	ccf
	ret
blob_wall_ahead:               ; (0xB5B5) actor_wall_* in Xvel direction
	ld e,(ix+003h)
	ld d,(ix+005h)
	ld a,d
	or e
	ret z
	bit 7,(ix+00ah)
	jp z,actor_wall_right
	jp actor_wall_left
blob_can_rise:                 ; (0xB5C8) NC if Simon >16px above and gap ahead
	ld a,(0c425h)
	sub 010h
	cp (ix+003h)
	ccf
	ret c
	ld e,(ix+003h)
	ld d,(ix+005h)
	ld a,008h
	bit 7,(ix+00ah)
	jr z,lb5e2h
	ld a,0f8h
lb5e2h:
	add a,d
	ld d,a
	jp map_solid_at
blob_floor:                    ; (0xB5E7) C if falling onto solid at feet
	xor a
	bit 7,(ix+008h)
	ret nz
	ld e,(ix+003h)
	ld d,(ix+005h)
	jp map_solid_at
lb5f6h:
	ld de,00000h
	call actor_set_xvel
	ld de,00200h
	call actor_set_yvel
	ld (ix+001h),001h
	ret
blob_chase_x:                  ; (0xB607) Xvel ±0x01C0 toward Simon
	ld a,(0c427h)
	cp (ix+005h)
	ld de,001c0h
	jr nc,lb615h
	ld de,0fe40h
lb615h:
	jp actor_set_xvel
blob_set_pose:
	ld a,(0d000h)
	ld de,lb645h+1
	call lookup_word_tbl
	ld a,(0d001h)
	srl a
	push af
	call ADD_DE_A
	pop af
	ld a,(de)
	jr c,lb632h
	rra
	rra
	rra
	rra
lb632h:
	and 00fh
	ld hl,lb649h
	call ADD_HL_A
	ld a,(hl)
	inc (ix+00ch)
	bit 4,(ix+00ch)
	jr z,lb645h
	inc a
lb645h:
	ld (ix+00bh),a
	ret
lb649h:
	nop
	sbc a,e
	sbc a,l
	sbc a,a
	and c
	ld l,h
	or (hl)
	ld l,a
	or (hl)
	ld (hl),d
	or (hl)
	ld (hl),l
	or (hl)
	ld a,d
	or (hl)
	ld a,(hl)
	or (hl)
	add a,e
	or (hl)
	adc a,b
	or (hl)
	adc a,e
	or (hl)
	sub c
	or (hl)
	sub a
	or (hl)
	sbc a,e
	or (hl)
	and b
	or (hl)
	and (hl)
	or (hl)
	xor h
	or (hl)
	ld (03332h),a
	inc sp
	inc sp
	inc sp
	ld de,03113h
	ld b,h
	ld de,01301h
	jr nc,lb6aeh
	ld bc,03113h
	inc sp
	inc sp
	inc b
	ld de,02000h
	nop
	nop
	inc sp
	jr nc,lb69dh
	nop
	inc b
	ld b,h
	ld b,h
	ld b,h
	ld b,h
	ld b,h
	ld b,h
	defb 010h,040h         ; was djnz lb6d3h (tile data)
	nop
	ld b,c
	ld de,04414h
	ld b,c
	ld b,h
	ld b,h
	ld b,h
	ld b,h
lb69dh:
	ld b,h
	ld b,h
	ld b,c
	ld de,01111h
	ld de,01111h
	ld de,04444h
	ld b,b
	ld b,h
	inc b
	ld b,h
	ld b,h
lb6aeh:
	ld b,h
	ld b,h
	ld b,h
	ld b,h
; --- room_event_tick (seg3 0xB6B2) - per-frame CE00 room-event dispatcher ----
;  CE00==0 -> ret.  Else DISPATCH_A on (CE00-1).  Events 1-5 spawn the
;  boss then wait CE15 and arm boss_clear (CE0B).  Event 6 is Dracula's
;  CE01 machine (event_dracula in seg1); its last step raises CE40 and
;  the play tick runs credits_tick.  When CE0B is set, tick CE10 instead
;  (boss-clear: orb spawn, HP refill, then C409).
room_event_tick:
	ld a,(0ce0bh)
	or a
	jr nz,room_event_ce10
	ld a,(0ce00h)
	dec a
	ret m
	call DISPATCH_A
	defw event_giant_bat    ; 1  s3r5 spawn type 18, wait CE15 -> boss_clear
	defw event_medusa       ; 2  s6r5
	defw event_mummies      ; 3  s9r7 two type 20
	defw event_frankenstein ; 4  s12r6 type 21 + igor
	defw event_grim_reaper  ; 5  s15r9 type 22 + sickles
	defw event_dracula      ; 6  s18r9 CE01 machine -> CE40 -> credits_tick
room_event_ce10:
	ld a,(0ce10h)
	call DISPATCH_A
	defw boss_clear_cull    ; 0  hide actors, timer 0x3C
	defw boss_clear_wait    ; 1
	defw boss_clear_orb     ; 2  spawn actor_orb
	defw boss_clear_orb_wait ; 3
	defw boss_clear_wait    ; 4  same wait as 1
	defw boss_clear_heal    ; 5  refill HP
	defw boss_clear_done    ; 6  C409, clear CE00
boss_clear_cull:
	call actors_kill_all
	ld a,03ch
	ld (0ce02h),a
	jr boss_clear_next
boss_clear_wait:
	ld hl,0ce02h
	dec (hl)
	ret nz
boss_clear_next:
	ld hl,0ce10h
	inc (hl)
	ret
boss_clear_orb:
	call 057c7h
	xor a
	ld (0ce11h),a
	ld (0ce14h),a
	ld c,actor_orb          ; boss-clear orb (descends; touch -> 0xCE11)
	ld de,07840h
	call spawn_actor
	ld a,0b4h
	ld (0ce02h),a
	jr boss_clear_next
boss_clear_orb_wait:
	ld a,(0ce11h)
	and a
	jr nz,lb72ch
	ld a,(0ce14h)
	and a
	ret z
	ld hl,0ce02h
	dec (hl)
	ret nz
	ld a,006h
	ld (0ce10h),a
	ld a,090h
	ld (0ce02h),a
	ld a,08ch
	jp play_sound
lb72ch:
	ld a,000h
	call play_sound
	ld a,08ch
	call play_sound
	ld a,096h
	ld (0ce02h),a
	jr boss_clear_next
boss_clear_heal:
	ld a,(0c003h)
	rra
	ret c
	ld a,(0c415h)
	cp 020h
	jr nc,lb751h
	ld a,001h
	call play_sound
	jp 04658h
lb751h:
	ld a,03ch
	ld (0ce02h),a
	jr boss_clear_next
boss_clear_done:
	ld hl,0ce02h
	dec (hl)
	ret nz
	ld a,0e0h
	ld (0c425h),a
	ld hl,0d600h
	ld b,080h
lb767h:
	ld (hl),0e0h
	inc hl
	djnz lb767h
	xor a
	ld (0ce0bh),a
	ld (0ce00h),a
	ld (0ce0ch),a
	ld (0ce11h),a
	inc a
	ld (0c409h),a          ; hub-advance -> state_hub_advance
	ret
; actor_orb_tick (seg3 0xB77E) - type 0x22. Boss-clear orb spawn-init.
actor_orb_tick:
	ld a,05ah
	ld (ix+010h),a
	ld a,001h
	ld (0ce0ch),a
	ld (ix+00bh),08fh
	ld (ix+006h),000h
	ld (ix+00eh),000h
	ld (ix+00ch),000h
	ld (ix+07eh),000h
	ld de,00000h
	call actor_set_xvel
	ld de,00100h
	jp actor_set_yvel
actor_orb_go:
	ld a,(ix+001h)
	call DISPATCH_A
	defw orb_flash, orb_settle, orb_spin
orb_flash:
	ld a,(0c003h)
	and 001h
	ld c,0ffh
lb7bbh:
	jr nz,lb7beh
	inc c
lb7beh:
	call orb_apply_sat
	dec (ix+010h)
	ret nz
	ld c,0ffh
	call orb_apply_sat
	ld (ix+006h),001h
	inc (ix+001h)
	ret
orb_apply_sat:
	ld a,(0d000h)
	ld de,lb801h
	sub 003h
	jr z,lb7dfh
	ld de,lb810h
lb7dfh:
	ld a,(ix+00bh)
	sub 08fh
	ld b,a
	add a,a
	add a,a
	add a,b
	call ADD_DE_A
	push ix
	pop hl
	ld a,025h
	add a,l
	ld l,a
	ld b,005h
lb7f4h:
	ld a,(de)
	inc de
	and c
	ld (hl),a
	ld a,005h
	add a,l
	ld l,a
	djnz lb7f4h
	ld (hl),000h
	ret
lb801h:
	ld c,008h
	ld b,002h
	nop
	ld c,008h
	ld b,004h
	ld (bc),a
	ex af,af'
	ld b,004h
	ld (bc),a
	nop
lb810h:
	ld c,008h
	rlca
	ld (bc),a
	nop
	ld c,008h
	rlca
	dec b
	ld (bc),a
	ex af,af'
	rlca
	dec b
	ld (bc),a
	nop
orb_settle:
	call orb_spin
	ld e,(ix+003h)
	ld d,(ix+005h)
	call map_solid_pair
	ret nc
	ld (ix+006h),000h
	ld (ix+00bh),08fh
	ld c,0ffh
	call orb_apply_sat
	ld (ix+00eh),002h
	ld a,001h
	ld (0ce14h),a
	inc (ix+001h)
	ret
orb_spin:
	ld a,(ix+00ch)
	inc (ix+00ch)
	rra
	and 003h
	ld hl,orb_frames
	call ADD_HL_A
	ld a,(hl)
	ld (ix+00bh),a
	ret
orb_frames:
	defb 08fh,090h,091h,090h
; event_mummies (seg3 0xB85E) - CE00=3, stage 9 room 7. Spawn a pair, wait CE15.
event_mummies:
	ld a,(0ce01h)
	call DISPATCH_A
	defw event_mummies_spawn, event_mummies_wait
event_mummies_spawn:
	ld c,actor_mummy
	ld de,030c5h
	call spawn_actor
	ld c,actor_mummy
	ld de,0d0c5h
	call spawn_actor
	jp event_ce01_next
event_mummies_wait:
	ld a,(0ce15h)
	and a
	ret z
	jp boss_clear_arm
; enemy_mummy_tick (seg3 0xB883) - type 20. Event 3 (two of them in s9r7).
; Walk 0x33-0x38. 16 HP, 2000 pts.
enemy_mummy_tick:
	ld (ix+00bh),036h
	ld (ix+010h),020h
	ld de,00000h
	call actor_set_yvel
	ld (ix+014h),002h
	ld (ix+015h),001h
	ret
enemy_mummy_go:
	ld a,(ix+001h)
	call DISPATCH_A
	defw mummy_idle, mummy_face, mummy_walk, mummy_spit
mummy_idle:
	dec (ix+010h)
	ret nz
	inc (ix+001h)
	ld (ix+006h),001h
	ret
mummy_face:
	ld de,0fdd0h
	ld (ix+012h),001h
	ld a,(0c427h)
	cp (ix+005h)
	jr c,lb8cah
	ld de,00230h
	ld (ix+012h),000h
lb8cah:
	call actor_set_xvel
	inc (ix+001h)
	ld (ix+013h),007h
	jp mummy_set_timer
mummy_walk:
	call mummy_walk_anim
	dec (ix+010h)
	jr nz,lb937h
	call mummy_set_timer
	ld (ix+013h),007h
	inc (ix+017h)
	bit 0,(ix+017h)
	jr z,lb8f7h
	bit 7,(ix+00ah)
	jr nz,lb914h
	jr lb8ffh
lb8f7h:
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,lb914h
lb8ffh:
	ld de,0fdd0h
	call actor_set_xvel
	ld (ix+012h),001h
	ld a,(0c427h)
	cp (ix+005h)
	jr c,lb929h
	call mummy_walk_anim
lb914h:
	ld de,00230h
	call actor_set_xvel
	ld (ix+012h),000h
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,lb929h
	jp mummy_walk_anim
lb929h:
	inc (ix+001h)
	ld (ix+006h),000h
	ld (ix+011h),030h
	jp mummy_walk_anim
lb937h:
	ld a,(ix+005h)
	cp 020h
	jr c,lb941h
	cp 0e1h
	ret c
lb941h:
	bit 7,(ix+00ah)
	ld de,00230h
	call actor_set_xvel
	ld (ix+012h),000h
	ld (ix+005h),020h
	jr nz,lb962h
	ld de,0fdd0h
	call actor_set_xvel
	ld (ix+005h),0e0h
	inc (ix+012h)
lb962h:
	call mummy_walk_anim
	jr mummy_set_timer
mummy_spit:
	dec (ix+011h)
	jr z,lb98ch
	ld a,008h
	bit 0,(ix+011h)
	jr z,lb976h
	ld a,04ch
lb976h:
	ld (ix+025h),002h
	ld (ix+02ah),a
	ld (ix+02fh),002h
	ld (ix+034h),a
	ld (ix+039h),002h
	ld (ix+03eh),a
	ret
lb98ch:
	ld a,(ix+003h)
	sub 038h
	ld e,a
	ld d,(ix+005h)
	ld a,040h
	call aim_at_simon_spd
	ld a,(ix+012h)
	rrca
	xor d
	call m,neg_de
	ld a,(ix+003h)
	sub 018h
	ld c,a
	ld b,(ix+005h)
	ld a,014h               ; kind 0x14 -> mummy_bandage
	call shot_spawn
	ld a,00ah
	call play_sound_alive
	dec (ix+001h)
	ld (ix+006h),001h
	ret
mummy_set_timer:
	ld a,r
	or 080h
	ld hl,mummy_timer_tbl
	and 007h
	call ADD_HL_A
	ld a,(hl)
	ld (ix+010h),a
	ret
mummy_timer_tbl:
	defb 040h,008h,030h,010h,020h,018h,038h,028h
mummy_walk_anim:
	ld hl,lba2ah
	bit 0,(ix+012h)
	jr z,lb9e2h
	ld hl,lba27h
lb9e2h:
	inc (ix+013h)
	ld a,(ix+013h)
	cp 008h
	jr nz,lba1ch
lb9ech:
	ld (ix+013h),000h
	bit 0,(ix+015h)
	jr z,lba0ah
	inc (ix+014h)
	ld a,(ix+014h)
	cp 003h
lb9feh:
	jr nz,lba1ch
	ld (ix+014h),001h
	ld (ix+015h),000h
	jr lba1ch
lba0ah:
	dec (ix+014h)
	ld a,(ix+014h)
	cp 0ffh
	jr nz,lba1ch
	ld (ix+014h),001h
	ld (ix+015h),001h
lba1ch:
	ld a,(ix+014h)
	call ADD_HL_A
	ld a,(hl)
	ld (ix+00bh),a
	ret
lba27h:
	defb 033h,034h,035h
lba2ah:
	defb 036h,037h,038h
; event_frankenstein (seg3 0xBA2D) - CE00=4, stage 12 room 6. Frank + Igor.
event_frankenstein:
	ld a,(0ce01h)
	call DISPATCH_A
	defw event_frankenstein_spawn, event_frankenstein_wait
event_frankenstein_spawn:
	xor a
	ld (0ce07h),a          ; Igor's jump trigger
	ld c,actor_frankenstein
	ld de,0d0c0h
	call spawn_actor
	ld c,actor_igor
	ld de,0d0a0h
	call spawn_actor
	jp event_ce01_next
event_frankenstein_wait:
	ld a,(0ce15h)
	and a
	ret z
	jp boss_clear_arm
; enemy_frankenstein_tick (seg3 0xBA56) - type 21. Event 4 with Igor.
; Walk 0x79/0x7A/0x7B. 32 HP on the bar, 3000 pts.
enemy_frankenstein_tick:
	ld (ix+011h),000h
	ld (ix+010h),030h
	ld (ix+006h),001h
	ld de,00000h
	call actor_set_xvel
lba68h:
	jp actor_set_yvel
enemy_frankenstein_go:
	ld a,(ix+010h)
	and a
	call nz,frank_arm_igor
	call frank_walk_anim
	ld a,(ix+001h)
	dec a
	jr z,frank_pace
frank_chase:
	ld (ix+00ch),020h
	ld a,(0c427h)
	sub (ix+005h)
	jr nc,lba90h
	add a,040h
	jr c,lba90h
	ld de,0fde0h
	jr lba93h
lba90h:
	ld de,00220h
lba93h:
	ld (0ce09h),de
	call actor_set_xvel
	inc (ix+001h)
	ret
frank_pace:
	call frank_clamp_x
	dec (ix+00ch)
	ret nz
	ld (ix+001h),000h
	ret
frank_clamp_x:
	ld a,(ix+005h)
	cp 0e0h
	jr nc,lbabah
	cp 010h
	ret nc
	ld de,00220h
	jp actor_set_xvel
lbabah:
	ld de,0fde0h
	jp actor_set_xvel
frank_walk_anim:
	ld hl,frank_poses
	inc (ix+011h)
	ld a,(ix+011h)
	rra
	rra
	rra
	and 003h
	call ADD_HL_A
	ld a,(hl)
	ld (ix+00bh),a
	ret
frank_poses:
	defb 079h,07ah,07bh,07ah
frank_arm_igor:
	dec (ix+010h)
	ret nz
	ld a,001h
	ld (0ce07h),a
	ret
igor_tick:
	ld (ix+006h),001h
	ld (ix+010h),000h
	ld de,00000h
	call actor_set_yvel
	call actor_set_xvel
	call igor_arm_throw
	xor a
	ld (ix+011h),a
	ret
igor_go:
	ld a,(ix+001h)
	dec a
	jr z,igor_air
	dec a
	jp z,igor_land
igor_wait:
	call igor_flash
	ret c
	ld a,(0ce07h)
	and a
	jr z,lbb1fh
	ld (ix+011h),000h
	ld de,0fa00h
	call actor_set_yvel
	inc (ix+001h)
	ret
lbb1fh:
	ld (ix+00bh),067h
	ld de,(0ce09h)
	jp actor_set_xvel
igor_air:
	call igor_flash
	ret c
	inc (ix+011h)
	ld a,(ix+011h)
	ld c,067h
	cp 004h
	jr c,lbb3bh
	inc c
lbb3bh:
	call igor_set_pose
	call igor_try_throw
	ld de,00060h
	call actor_add_yvel
	ld a,(ix+005h)
	cp 0e8h
	ld e,(ix+009h)
	ld d,(ix+00ah)
	push af
	call nc,igor_bounce_r
	pop af
	cp 014h
	call c,igor_bounce_l
	bit 7,(ix+008h)
	ret nz
	ld e,(ix+003h)
	ld d,(ix+005h)
	call map_solid_pair
	ret nc
	ld c,069h
	call igor_set_pose
	ld (ix+006h),000h
	ld a,(ix+003h)
	and 0f8h
	ld (ix+003h),a
	ld (ix+00ch),010h
	inc (ix+001h)
	ret
igor_bounce_r:
	bit 7,d
	ret nz
	call neg_de
	jp actor_set_xvel
igor_bounce_l:
	bit 7,d
	ret z
	call neg_de
	jp actor_set_xvel
igor_land:
	call igor_flash
	ld (ix+006h),000h
	ret c
	dec (ix+00ch)
	ret nz
	ld a,(ix+003h)
	ld de,0f880h
	cp 080h
	jr nc,lbbafh
	ld de,0fa80h
lbbafh:
	ld a,r
	or 080h
	ld l,a
	ld h,000h
	add hl,hl
	add hl,de
	call actor_set_yvel
	ld (ix+006h),001h
	xor a
	ld (ix+011h),a
	ld (ix+001h),a
	ret
igor_flash:
	ld a,(ix+010h)
	and a
	jr z,lbbd6h
	dec (ix+010h)
	ld (ix+006h),000h
	scf
	ret
lbbd6h:
	ld (ix+006h),001h
	ret
igor_try_throw:
	dec (ix+012h)
	ret nz
	call igor_arm_throw
	call aim_at_simon
	jp shot_throw
igor_arm_throw:
	ld (ix+012h),030h
	ret
igor_set_pose:
	bit 7,(ix+00ah)
	ld a,c
	jr nz,lbbf6h
	add a,003h
lbbf6h:
	ld (ix+00bh),a
	ret
; event_grim_reaper (seg3 0xBBFA) - CE00=5, stage 15 room 9.
; Spawn the reaper plus 4 sickles (shot kind 0x16 -> type 8); keep tossing while waiting.
event_grim_reaper:
	ld a,(0ce01h)
	call DISPATCH_A
	defw event_grim_reaper_spawn, event_grim_reaper_wait
event_grim_reaper_spawn:
	ld de,0a090h
	ld c,actor_grim_reaper
	call spawn_actor
	call grim_sickle_spawn
	call grim_sickle_spawn
	call grim_sickle_spawn
	call grim_sickle_spawn
	xor a
	ld (0ce02h),a
	jp event_ce01_next
event_grim_reaper_wait:
	ld a,(0ce15h)
	and a
	jp nz,boss_clear_arm
	ld hl,0ce02h
	dec (hl)
	ret nz
	ld (hl),080h
	jp grim_sickle_spawn
grim_sickle_spawn:
	ld hl,0cf20h
	ld a,(hl)
	inc (hl)
	and 007h
	add a,a
	ld hl,grim_sickle_xy
	call ADD_HL_A
	ld c,(hl)
	inc hl
	ld b,(hl)
	ld de,00000h
	ld h,e
	ld l,e
	ld a,016h
	jp shot_spawn
grim_sickle_xy:
	defw 03030h,0c080h,0c030h,030c0h,08048h,080a0h,03068h,0c068h
; enemy_grim_reaper_tick (seg3 0xBC5B) - type 22. Event 5, stage 15 room 9.
; 32 HP, 12 cells, 7000 pts. Shape 0x7C.
enemy_grim_reaper_tick:
	ld de,0fd80h
	call actor_set_xvel
	ld de,0fe00h
	call actor_set_yvel
	ld (ix+006h),000h
	ld (ix+00ch),01eh
	ld (ix+00bh),07ch
	ret
enemy_grim_reaper_go:
	ld a,(ix+001h)
	dec a
	jr z,grim_fly
grim_idle:
	dec (ix+00ch)
lbc7dh:
	ret nz
	inc (ix+001h)
	ld (ix+006h),001h
	ret
grim_fly:
	ld e,(ix+007h)
	ld d,(ix+008h)
	ld hl,00008h
	add hl,de
	ex de,hl
	call actor_set_yvel
	ld e,(ix+009h)
	ld d,(ix+00ah)
	ld a,(ix+005h)
	cp 0e8h
	push af
	call nc,grim_bounce_r
	pop af
	cp 018h
	call c,grim_bounce_l
	ld a,(ix+003h)
	cp 040h
	jr nc,lbcc0h
	ld e,(ix+007h)
	ld d,(ix+008h)
	bit 7,d
	jr z,lbcc0h
	call neg_de
	call actor_set_yvel
lbcc0h:
	ld e,(ix+003h)
	ld d,(ix+005h)
	call map_solid_pair
	ret nc
	ld de,0fd00h
	jp actor_set_yvel
grim_bounce_r:
	bit 7,d
	ret nz
	call neg_de
	jp actor_set_xvel
grim_bounce_l:
	bit 7,d
	ret z
	call neg_de
	jp actor_set_xvel
; event_medusa (seg3 0xBCE2) - CE00=2, stage 6 room 5. Dwell, spawn, wait CE15.
event_medusa:
	ld a,(0ce01h)
	call DISPATCH_A
	defw event_medusa_arm, event_medusa_dwell, event_medusa_spawn, event_medusa_wait
event_medusa_arm:
	ld a,078h
	ld (0ce02h),a
	jp event_ce01_next
event_medusa_dwell:
	ld hl,0ce02h
	dec (hl)
	ret nz
	jp event_ce01_next
event_medusa_spawn:
	ld de,09090h
	ld c,actor_medusa
	call spawn_actor
	ld hl,08070h
	ld bc,02020h
	ld a,000h
	ld d,000h
	call vdp_hmmv            ; fill a 32x32 SCREEN 5 rect (entrance hole)
	jp event_ce01_next
event_medusa_wait:
	ld a,(0ce15h)
	and a
	ret z
	jp boss_clear_arm
enemy_medusa_go:
	call medusa_try_spit
	ld a,(ix+001h)
	call DISPATCH_A
	defw medusa_cruise
	defw medusa_reverse
; enemy_medusa_tick (seg3 0xBD2D) - type 19. Event 2, stage 6 room 5.
; 16 HP, 2000 pts. Shape 0x2B.
enemy_medusa_tick:
	xor a
	ld (ix+009h),0f8h
	ld (ix+00ah),a
	ld (ix+007h),010h
	ld (ix+008h),a
	ld (ix+00bh),02bh
	ld (ix+006h),001h
	ld (ix+015h),03ch
	ld (ix+014h),008h
	ret
medusa_bob:
	dec (ix+014h)
	ld c,02bh
	bit 3,(ix+014h)
	jr z,lbd59h
	inc c
lbd59h:
	ld (ix+00bh),c
	ld de,00020h
	ld a,(ix+003h)
	cp 0a0h
	jr c,lbd69h
	ld de,0ffe0h
lbd69h:
	add hl,de
	jp actor_add_yvel
medusa_cruise:
	call medusa_bob
	ld a,(ix+005h)
	sub 010h
	cp 0e0h
	jr nc,lbd86h
	ld a,(0c427h)
	sub (ix+005h)
	jr nc,lbd83h
	neg
lbd83h:
	cp 008h
	ret nc
lbd86h:
	ld a,(ix+009h)
	cpl
	ld e,a
	ld a,(ix+00ah)
	cpl
	ld d,a
	inc de
	call actor_set_xvel
	ld (ix+012h),03fh
	ld (ix+013h),060h
	inc (ix+001h)
	ret
medusa_reverse:
	dec (ix+013h)
	ld a,(ix+013h)
	and a
	jr nz,lbde4h
	inc (ix+013h)
	ld (ix+006h),000h
	dec (ix+012h)
	jr nz,lbde3h
	xor a
	ld (ix+009h),0f8h
	ld (ix+00ah),a
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,lbdd3h
	ld a,(ix+009h)
	cpl
	ld e,a
	ld a,(ix+00ah)
	cpl
	ld d,a
	inc de
	call actor_set_xvel
lbdd3h:
	ld (ix+006h),001h
	ld (ix+001h),000h
	ld (ix+012h),02fh
	ld (ix+013h),04fh
lbde3h:
	ret
lbde4h:
	call medusa_bob
	ld a,(ix+005h)
	sub 010h
	cp 0e0h
	jr nc,lbdfdh
	ld a,(0c427h)
	sub (ix+005h)
	jr nc,lbdfah
	neg
lbdfah:
	cp 008h
	ret nc
lbdfdh:
	ld a,(ix+009h)
	cpl
	ld e,a
	ld a,(ix+00ah)
	cpl
	ld d,a
	inc de
	call actor_set_xvel
	ld (ix+012h),03fh
	ld (ix+013h),010h
	ret
medusa_try_spit:
	dec (ix+015h)
	ret nz
	ld (ix+015h),03ch
	call aim_at_simon
	ld a,(ix+003h)
	sub 010h
	ld c,a
	ld b,(ix+005h)
	push ix
	ld a,013h               ; kind 0x13 -> medusa_snake
	call shot_spawn
	pop ix
	ret
; event_giant_bat (seg3 0xBE32) - CE00=1, stage 3 room 5. Spawn, wait CE15.
; Spawn falls into event_ce01_next (the shared CE01++ lives here).
event_giant_bat:
	ld a,(0ce01h)
	call DISPATCH_A
	defw event_giant_bat_spawn, event_giant_bat_wait
event_giant_bat_spawn:
	ld c,actor_giant_bat
	ld de,07040h
	call spawn_actor
event_ce01_next:               ; (0xBE44) CE01++; also Dracula CE01 epilogue
	ld hl,0ce01h
	inc (hl)
	ret
event_giant_bat_wait:
	ld a,(0ce15h)
	and a
	ret z
boss_clear_arm:                ; (0xBE4E) CE10=0, CE0B=1 -> room_event_ce10
	xor a
	ld (0ce10h),a
	inc a
	ld (0ce0bh),a
	ret
; enemy_giant_bat_tick (seg3 0xBE57) - type 18. Event 1 boss; also a normal
; enemy on stage 16 when CE00==0 (per-actor HP). 16 HP, 2000 pts. Shape 0x4F.
enemy_giant_bat_tick:
	ld (ix+00bh),04fh
	ld (ix+006h),000h
	ld a,(0d000h)
	cp 003h
	ld (ix+013h),03ch
	jr z,lbe6eh
	ld (ix+013h),001h
lbe6eh:
	ld de,00000h
	call actor_set_xvel
	jp actor_set_yvel
enemy_giant_bat_go:
	inc (ix+014h)
	inc (ix+00ch)
	ld a,(ix+00ch)
	and 008h
	ld a,04eh
	jr z,lbe87h
	inc a
lbe87h:
	ld (ix+00bh),a
	ld a,(ix+001h)
	call DISPATCH_A
	defw giant_bat_idle, giant_bat_begin, giant_bat_aim, giant_bat_swoop, giant_bat_spit, giant_bat_climb
giant_bat_idle:
	dec (ix+013h)
	ret nz
	ld (ix+006h),001h
	ld (ix+001h),001h
	ret
giant_bat_begin:
	ld (ix+001h),002h
giant_bat_aim:
	ld a,(0c425h)
	sub 030h
	ld b,030h
	jr c,lbeb7h
	ld b,a
lbeb7h:
	ld (ix+011h),b
	ld a,(ix+014h)
	and 001h
	ld a,048h
	jr z,lbec5h
	neg
lbec5h:
	ld c,a
	ld a,(0c427h)
	add a,c
	ld c,a
	ld (ix+012h),c
	ld a,(0c427h)
	ld h,a
	ld a,(0c425h)
	ld l,a
	push hl
	ld a,c
	ld (0c427h),a
	ld a,b
	ld (0c425h),a
	call aim_at_simon
	call actor_set_xvel
	ex de,hl
	call actor_set_yvel
	pop hl
	ld a,l
	ld (0c425h),a
	ld a,h
	ld (0c427h),a
	ld (ix+001h),003h
	ret
giant_bat_swoop:
	bit 7,(ix+008h)
	ld a,(ix+003h)
	jr z,lbf04h
	cp 030h
	jr c,lbf30h
lbf04h:
	cp 090h
	jr nc,lbf30h
	ld a,(ix+005h)
	sub 020h
	cp 0b0h
	jr nc,lbf30h
	ld a,(ix+003h)
	add a,008h
	sub (ix+011h)
	cp 010h
	ret nc
	ld a,(ix+005h)
	add a,008h
	sub (ix+012h)
	cp 010h
	jr c,lbf30h
	ld a,(ix+005h)
	sub 020h
	cp 0c0h
	ret c
lbf30h:
	ld de,00000h
	call actor_set_xvel
	call actor_set_yvel
	ld a,r
	srl a
	srl a
	neg
	add a,040h
	ld (ix+010h),a
	ld (ix+001h),004h
	ret
giant_bat_throw:
	call aim_at_simon
	jp shot_throw
giant_bat_spit:
	ld a,(ix+010h)
	cp 018h
	call z,giant_bat_throw
	dec (ix+010h)
	ret nz
	ld de,00280h
	call actor_set_yvel
	ld a,(0c427h)
	ld b,(ix+005h)
	cp b
	jr nc,lbf6fh
	ld c,a
	ld a,b
	ld b,c
lbf6fh:
	sub b
	ld d,a
	ld e,000h
	srl d
	rr e
	srl d
	rr e
	srl d
	rr e
	srl d
	rr e
	srl d
	rr e
	ld a,(0c427h)
	ld b,(ix+005h)
	cp b
	call c,neg_de
	call actor_set_xvel
	ld (ix+001h),005h
	ret
giant_bat_climb:
	ld de,0fff0h
	call actor_add_yvel
	ld a,(ix+005h)
	cp 019h
	ld b,002h
	jr c,lbfaeh
	cp 0e7h
	ld b,0feh
	jr c,lbfb5h
lbfaeh:
	ld (ix+009h),000h
	ld (ix+00ah),b
lbfb5h:
	bit 7,(ix+008h)
	ret z
	ld a,(ix+003h)
	cp 041h
	ret nc
	ld (ix+001h),002h
	jp giant_bat_aim
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h

    ASSERT $ == 0xC000

; ===========================================================================
;  SEGMENT 0 - resident bank.  Paged at 0x4000-0x5FFF for the whole game and
;  holds the boot/init code, the interrupt handler, the bank-switch helpers
;  and the top-level game state machine.
;  (Origin is set by PHASE 0x4000 in VampireKiller.asm; regenerate the raw
;   disassembly with  tools/regen-seg.sh 0 0x4000 segments/seg00.blocks .)
;
;  MSX/MSX2 BIOS entry-point names used below (ENASLT, WRTVDP, ...) are defined
;  once in segments/bios.inc, included by VampireKiller.asm before this file.
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

; BLOCK 'data_4010' (start 0x4010 end 0x4028)
data_4010_start:
	defb 043h
	defb 000h
	defb 044h
	defb 000h
	defb 007h
	defb 000h
	defb 044h
	defb 000h
	defb 0e8h
	defb 000h
	defb 0c0h
	defb 004h
	defb 000h
	defb 011h
	defb 0c4h
	defb 000h
	defb 0d0h
	defb 012h
	defb 010h
	defb 0c4h
	defb 000h
	defb 000h
	defb 005h
	defb 0c4h
data_4010_end:
; ===========================================================================
;  int_handler - timer interrupt (H.TIMI hook, installed by init at 0xFD9F).
;  Runs once per VDP frame: PSG tick (`sound_tick` in segs 14/15), then
;  the game tick.  0xC005 bit0 skips a frame if the previous tick is still
;  running.  0xE600 is the Game Master detection flag, not a re-entrancy flag:
;  when set, gm_pause_check gets first look at the keyboard (STOP pause / ';'
;  frame advance) and then usually falls into l4030h anyway.
; ===========================================================================
int_handler:
	di
	ld a,(0e600h)           ; Game Master cartridge present?
	or a
	jp nz,gm_pause_check    ; yes -> pause/frame-advance keys get first look
l4030h:
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
	jp nz,l405fh            ; tick still running -> skip this frame
	inc (hl)                ; mark tick in progress
	ei
	call 04ba4h             ; input / timers update
	call main_tick          ; MAIN TICK (top-level state machine)
	xor a
	ld (0c005h),a           ; clear tick-in-progress flag
l405fh:
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
	ld hl,data_4010_end     ; ...JP int_handler (=data_4010_end, 0x4028)
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
	jr nz,l40f1h            ; already paused
	bit 4,c
	jp z,l4030h             ; running, no STOP -> normal tick
	ld (hl),c               ; STOP -> enter pause...
	call gm_psg_save_mute   ; ...silence the PSG and skip the tick
	ei
	ret
l40f1h:                         ; paused
	bit 7,c
	jp nz,l40fch            ; ';' -> single-step one frame, stay paused
	bit 4,c
	jr z,l4102h             ; nothing pressed -> stay frozen
	xor a
	ld (hl),a               ; STOP again -> leave pause
l40fch:
	call gm_psg_restore
	jp l4030h               ; run one tick
l4102h:
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
	jr l41c9h
l418ah:
	djnz l4198h
	ld hl,0c004h
	dec (hl)
	ret nz
	call title_build
	xor a
	jp l424bh
l4198h:
	call sub_47c0h
	call konami_logo_draw   ; draw Konami logo + start the top-to-bottom wipe (seg1)
	jr l41cch
state_title:                   ; 1 (0x41A0): idle until C004==0, then attract
	ld hl,0c004h
	dec (hl)               ; first entry C004=0 wraps to 0xFF (~4s @ 60Hz)
	ret nz
	call title_set_color2
	jp l4249h              ; C004=0x20, inc C000 -> state 2 attract
state_attract:                 ; 2 (0x41AB)
	djnz l41c1h
	call sub_4e27h
	ld a,(0c413h)
	or a
	ret nz
l41b5h:
	xor a
l41b6h:
	ld (0c000h),a
	ld a,020h
	ld (0c004h),a
	jp l4252h
l41c1h:
	call sub_47c0h
	call sub_4deeh
	ld a,020h
l41c9h:
	ld (0c004h),a
l41cch:
	ld hl,0c001h
	inc (hl)
	ret
state_intro:                   ; 3 (0x41D1)
	djnz l41e4h
	ld hl,0c004h
	dec (hl)
	jr z,l41cch
	bit 2,(hl)
	ld hl,l4d30h
	jp z,l4ad2h
	jp l4ad6h
l41e4h:
	djnz l41ech
	call reset_run_state   ; wipe run work RAM (0xC405..0xDFFF) + seed defaults
	jp l41cch
l41ech:
	djnz l41fbh
	ld a,001h
	ld (0c41ah),a          ; intro: use mtile_stream_c41a
	call 063dah
	ld a,0a0h
	jp l41c9h
l41fbh:
	djnz l4222h
	call sub_4e9ah
	ld hl,0c004h
	ld a,(0c003h)
l4206h:
	rra
	ret c
	dec (hl)
	ret nz
	call sub_47f7h
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
	jr l4249h
l4222h:
	ld a,08ah
	call play_sound
	ld a,050h
	jp l41c9h
state_stage_bridge:            ; 4 (0x422C)
	ld hl,0c410h
	ld a,(hl)
	sub 001h
	daa
	ld (hl),a
	call sub_47dbh
	call hud_draw_all
	call 062edh
	ld hl,0c413h
	ld (hl),001h           ; stay in play (0 = attract/death leave-play)
	call stage_bgm_play
	xor a
	ld (0c40dh),a          ; clear BGM force-replay (set on death / GM stage jump)
l4249h:
	ld a,020h
l424bh:
	ld (0c004h),a
	ld hl,0c000h
	inc (hl)
l4252h:
	xor a
	ld (0c001h),a
	ret
state_play:                    ; 5 (0x4257)
	call play_tick
	ld a,(0c40ch)
	or a
	ld a,00ch
	jp nz,l41b6h           ; 0xC40C -> vendor
	ld a,(0c40ah)
	and a
	jp nz,l428ch           ; 0xC40A -> pause
	ld a,(0c41bh)
	and a
	ld a,009h
	jp nz,l41b6h           ; pending room exit (1-4 or 0xFF spot) -> room_trans
	ld a,(0c408h)
	or a
	ld a,00ah
	jp nz,l41b6h           ; stage-boundary -> spend key / advance_stage
	ld a,(0c409h)
	and a
	ld a,008h
	jp nz,l41b6h           ; 0xC409 -> hub_advance
	ld a,(0c413h)
	or a
	ret nz
	jr l4249h
l428ch:
	call sub_449ch
	ld a,00bh
	jp l41b6h
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
	jp l41b6h
l42abh:
	ld a,08bh
	call play_sound
	jr l4249h
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
	jp l41b5h
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
	call sub_47c0h
	ld hl,l4d41h           ; "GAME  OVER"
	call l4ad2h
	ld a,(0e600h)          ; Game Master cartridge present?
	or a
	jr z,l42f8h
	ld hl,gm_continue_text ; yes -> add the "F5 -> CONTINUE" line
	call l4ad2h
l42f8h:
	call hud_draw_all
	ld a,078h
	jp l41c9h
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
	jp l41b5h
l434bh:
	call 062dch
; advance_stage (0x434E): move to the next stage.  Bumps the two BCD progress
; counters 0xC410/0xC411, increments the stage id 0xD000, resets the room id
; 0xD001 to 0, clears 0xC408/0xC409, then runs transition type 4 (jp l41b6h).
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
	jp l41b6h
	ld hl,00000h
	ld (0c000h),hl
	ret
l4377h:
	call sub_47c0h
	xor a
	jp l41c9h
state_room_trans:              ; 9 (0x437E): 0xC41B pending exit
	call conn_lookup_paged
	ld a,006h
	jp nc,l41b6h           ; failed transition -> death
	call 062fch
	ld a,005h
	jp l41b6h              ; back to play
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
	jp l41b6h               ; enter via the state setter
state_pause:                   ; 11 (0x43E1): F1 froze play (0xC40A); wait F1 (0xC00B bit0) to resume
	ld a,(0c00bh)
	rra
	ret nc                 ; still held/not pressed -> stay frozen
	xor a
	ld (0c40ah),a          ; clear pause latch
	call sub_44bfh         ; restore the blit rectangle paused over
	ld a,0feh              ; unpause BGM
	call play_sound
	ld a,005h
	jp l41b6h              ; back to play
state_vendor:                  ; 12 (0x43F7): 0xC40C whip-hit vendor
	djnz l4402h
	call vendor_purchase_tick  ; poll buy/refuse (seg2)
	ret nz
	ld a,00fh
	jp l41c9h
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
	jp l41b6h
l4411h:
	xor a
	ld (0c40ch),a          ; clear the whip-hit flag
	call vendor_make_offer ; arm a sale (seg2 0x938E)
	jp l41cch
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
	jp l41cch              ; -> number-entry phase (C001=1)
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
	jp l41cch
sub_449ch:
	ld hl,06854h
	ld bc,03010h
	ld de,0d070h
	ld a,004h
	push hl
	push bc
	call vdp_hmmm
	pop bc
	pop hl
	call sub_5d15h
	ld hl,l44b7h
	jp l4ad2h
l44b7h:
	ld l,h
	ld e,b
	ld b,b
	ld sp,04345h
	dec (hl)
	rst 38h
sub_44bfh:
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
	call l4ad2h
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
	jr l457fh
; --- draw_stage_hud (seg0 0x4542) - draw the HUD STAGE number (0xC411, BCD).
draw_stage_hud:
	ld de,09c00h           ; HUD cell for the stage readout
	ld hl,0c411h           ; stage/area label (packed BCD)
	ld b,001h
	jr l457fh
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
	jr l457fh
l457fh:
	ld a,(hl)
	rra                    ; isolate the high nibble (tens digit)
	rra
	rra
	rra
	call sub_458fh
	ld a,(hl)              ; low nibble (ones digit)
	call sub_458fh
	dec hl
	djnz l457fh
	ret
sub_458fh:
	and 00fh               ; digit 0..9
	add a,020h             ; -> numeral tile code
	call sub_4aeeh
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
l45bah:
	call enemy_meter_frame
	jp draw_enemy_meter
health_bar_redraw:
	call health_bar_frame
	jp draw_health_bar
enemy_meter_frame:
	ld hl,03b16h           ; (X,Y) just outside the enemy meter
	ld bc,04206h           ; 66 x 6 (immediate, not a code address)
l45cch:
	jp sub_5d15h           ; clear the panel + draw its border
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
	jp l45bah
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
	jp l45bah
	ld b,001h
	jr damage_health
	ld b,001h
	jp restore_health
	ld b,001h
	jr damage_enemy
sub_4661h:
	call vdp_set_read
	call sub_4674h
	ex af,af'
	ld a,(00006h)
	ld c,a
	ex af,af'
l466dh:
	inir
	dec a
	jr nz,l466dh
	ex de,hl
	ret
sub_4674h:
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
	call sub_4674h
	ex af,af'
	ld a,(00007h)
	ld c,a
	ex af,af'
l4689h:
	otir
	dec a
	jr nz,l4689h
	ret
sub_468fh:
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
;     Tools: tools/rledec.py replays this exact grammar to extract graphics.
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
	call sub_4661h
	pop af
	call sub_4786h
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
sub_4786h:
	ld hl,0e800h
	ld de,0ec10h
	ld c,a
l478dh:
	call sub_47a4h
	ld a,0e0h
	add a,e
	ld e,a
	jr c,l4797h
	dec d
l4797h:
	call sub_47a4h
	ld a,020h
	call ADD_DE_A
	dec c
	jp nz,l478dh
	ret
sub_47a4h:
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
	call sub_47f7h
	ld bc,00000h
	jr l47c6h
sub_47c0h:
	call sub_47f7h
	ld bc,000d4h
l47c6h:
	push bc
	call sub_47dbh
	pop bc
	call sub_47e8h
l47ceh:
	ld a,(0f3e0h)
	or 040h
	ld b,a
	ld c,001h
	call WRTVDP
	jr l4810h
sub_47dbh:
	ld a,(0f3e0h)
	and 0bfh
	ld b,a
	ld c,001h
	call WRTVDP
	jr l4805h
sub_47e8h:
	ld hl,00000h
	xor a
	ld d,a
	call vdp_hmmv
	ld b,000h
	ld c,017h
	jp WRTVDP
sub_47f7h:
	ld hl,0f600h
	ld a,0e0h
	ld bc,00080h
	call sub_468fh
	jp sprites_hide
l4805h:
	ld a,(0ffe7h)
	or 002h
	ld b,a
	ld c,008h
	jp WRTVDP
l4810h:
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
;     (16 rows of 8 bytes), and l4A97 for a run of them.
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
l4a97h:
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
	djnz l4a97h
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
l4ad2h:
	ld c,0ffh
	jr l4ad8h
l4ad6h:
	ld c,000h
l4ad8h:
	ld d,(hl)
	inc hl
	ld e,(hl)
	inc hl
l4adch:
	ld a,(hl)              ; 0xFF end; 0xFE new (D,E); else glyph. C masks A
	inc hl                 ; (credits: C=0xFF, ASCII letters; space=0 skips)
	ld b,a
	inc b
	ret z
	inc b
	jr z,l4ad2h
	and c
	call sub_4aeeh
	ld a,d
	add a,008h
	ld d,a
	jr l4adch
sub_4aeeh:
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
l4b07h:
	push af
	call sub_4aeeh
	call blit_advance_x
	pop af
	djnz l4b07h
	ret
sub_4b12h:
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
	call sub_507dh
	call l4805h
	ld a,005h               ; SCREEN 5 (G4, 256x212, 16 colours, 4bpp)
	call CHGMOD             ; set VDP mode via BIOS
	call sub_47dbh          ; program remaining VDP regs (sprite/table bases)
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
	call sub_47f7h
	jp l47ceh
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
l4bb8h:
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
	call sub_47dbh
	call sub_4de2h
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
	call sub_47f7h
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
	jr nz,l4dc3h           ; non-zero -> international title (VAMPIRE KILLER)
	ld de,0a818h           ; Japanese layout: castle...
	ld hl,title_castle
	call tile_layout_draw
	ld de,0a038h           ; ...+ "Akumajo Dracula" kana
	ld hl,title_logo_jp
	call tile_layout_draw
	call title_sat_init
	jr l4dd5h
l4dc3h:                        ; international/other machine
	ld de,03828h           ; "VAMPIRE KILLER" logo...
	ld hl,title_logo_intl
	call tile_layout_draw
	ld de,0b830h           ; ...+ castle
	ld hl,title_castle
	call tile_layout_draw
l4dd5h:
	ld hl,l4d0fh
	call l4ad2h
	jp l47ceh
	ld d,001h
	jr l4de4h
sub_4de2h:
	ld d,000h
l4de4h:
	ld hl,00000h
	ld bc,00000h
	xor a
	jp vdp_hmmv
sub_4deeh:
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
sub_4e27h:
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
	jp l4bb8h
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
sub_4e9ah:
	call c800_tick
	call c800_sat_build
	call c800_sat_emit
	jp pattern_shadow_blit
	ld c,027h
	ld de,0e048h
	jp spawn_actor
	ld (ix+006h),001h
	ld (ix+00bh),094h
	ld (ix+00eh),a
	ret
	xor a
	ld (ix+008h),a
	ld (ix+007h),a
	ld de,0ffe0h
l4ec4h:
	jp actor_set_xvel
	ld c,028h
	ld de,09038h
	call spawn_actor
	ld c,029h
	ld de,03068h
	jp spawn_actor
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
	ld (ix+00bh),092h
	xor a
	ld (ix+010h),a
	ld (ix+00eh),a
	ret
	inc (ix+010h)
	ld a,(ix+010h)
	cp 004h
	ret nz
	ld (ix+010h),000h
	inc (ix+011h)
	ld (ix+00bh),092h
	bit 0,(ix+011h)
	ret z
	ld (ix+00bh),093h
	ret
	ld c,02ah
	ld de,0f0c0h
	jp spawn_actor
	ld (ix+00bh),098h
	xor a
	ld (ix+001h),a
	ld (ix+013h),a
	ld (ix+014h),a
	ld (ix+00eh),a
	ld (ix+006h),001h
	ret
	ld a,(ix+001h)
	dec a
	jr z,l4f5eh
	call sub_4f67h
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
l4f5eh:
	ld (ix+006h),000h
	ld (ix+00bh),097h
	ret
sub_4f67h:
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
	ld hl,l4f86h
	call ADD_HL_A
	ld a,(hl)
	ld (ix+00bh),a
	ret
l4f86h:
	sbc a,b
	sbc a,c
	sbc a,d
	sbc a,c
; --- 0x4f8a - build + draw the current room (entry to room_map_build) --------
;  HL = 0xD100 (destination tile-name map), B = world row (0xD000), C = column
;  (0xD001).  room_map_build expands the room's metatiles into 0xD100..0xD3FF.
	ld hl,0d100h
	ld a,(0d000h)
	ld b,a
	ld a,(0d001h)
	ld c,a
	jp room_map_build
; --- 0x4f98 - paint the 32x22 playfield of the tile map to the screen --------
;  Walks 0xD140 (map row 2, skipping the 2 HUD rows) as 22 rows x 32 cols and
;  draws each tile via sub_4b12h (dest advances 8px per cell / 8px per row).
	ld hl,0d140h
	ld de,00020h
	ld b,016h
l4fa0h:
	push bc
	ld b,020h
l4fa3h:
	ld a,(hl)
	call sub_4b12h
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
;  (0xC41A!=0 uses mtile_stream_c41a and mtile_def_c41a in seg13.)
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
	ld hl,mtile_stream_c41a
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
	ld bc,mtile_def_c41a
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
sub_507dh:
	ld a,0bch
	ld (0c097h),a
	xor a
	ld (0c0a5h),a
	ld (0c0a6h),a
	ld (0c0a7h),a
sub_508ch:
	xor a
	ld (0c096h),a
	ld (0c098h),a
	ld (0c0a8h),a
	ld hl,sound_idle
	ld (0c010h),hl
	ld (0c012h),hl
	ld (0c014h),hl
	ld (0c016h),hl
l50a5h:
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
	jp z,l51abh
	cp 0fbh
	jp nc,l51b1h
	or a
	jp p,l5171h
	ld de,0c01ch
	ld hl,l515dh
	ld bc,00014h
	ldir
	ld hl,l515dh
	ld bc,00014h
	ldir
	ld hl,l515dh
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
	ld hl,l50a5h
	ld (0c016h),hl
	ld a,(0c098h)
	and 0fdh
	ld (0c098h),a
l5131h:
	xor a
	ld (0c0a5h),a
	ld (0c0a6h),a
	ld (0c0a8h),a
	ld a,007h
	ld (0c0a7h),a
l5140h:
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
l515dh:
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
l5171h:
	ld c,a
	ld a,(0c0a8h)
	or a
	jp nz,l5140h
	ld a,(0c096h)
	cp c
	jp z,l5183h
	jp nc,l5140h
l5183h:
	ld a,c
	ld (0c096h),a
	ld de,0c058h
	ld hl,l515dh
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
	jp l5140h
l51abh:
	call sub_508ch
	jp l5140h
l51b1h:
	jp z,l527dh
	cp 0fch
	jp z,l52d0h
	cp 0fdh
	jp z,l51cbh
	cp 0feh
	jp z,l5234h
	ld a,03ah
	ld (0c0a5h),a
	jp l5140h
l51cbh:
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
	ld hl,l515dh
	ld bc,00014h
	ldir
	ld hl,snd_fd_seq
	ld (0c080h),hl
	jp l5131h
l5234h:
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
	jp l5140h
l527dh:
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
	ld hl,l515dh
	ld bc,00014h
	ldir
	ld hl,snd_fb_seq
	ld (0c078h),hl
	jp l5140h
l52d0h:
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
	jp l5140h
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
;     tiles at CPU 0xB9C8 are read from segment 6 after this call.
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
	call page_title_banks
	ld hl,bonus_hud_tiles  ; bonus ids 1-20 (16x16 4bpp)
	ld de,0a800h           ; VRAM page 1 Y=0x50 (wraps to Y=0x60 after 16)
	ld b,014h
	call l4a97h
	ld hl,bonus_hud_potion ; potion bottle (bonus id 22) -> VRAM (X=80,Y=96)
	ld de,0b028h
	ld b,001h
	call l4a97h
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
	ld hl,0b9c8h           ; ids 23-30: keys, chest, chain, knife, axe, cross, holy
	ld de,0b030h           ; VRAM page 1 Y=0x60 X=96 (file 0xD9C8)
	ld b,008h
	call l4a97h
	ld hl,0bdc8h
	ld de,0b800h
	ld b,005h
	call l4a97h
	call page_title_banks
	call sub_54f7h
	jp page_play_banks
sub_54f7h:
	ld ix,l5595h
	ld de,0d000h
	ld b,005h
l5500h:
	push bc
	push de
	call sub_5514h
	call sub_554fh
	pop de
	ld a,010h
	call ADD_DE_A
	pop bc
	inc ix
	djnz l5500h
	ret
sub_5514h:
	exx
	ld de,0e800h
	ld hl,0bda7h
	ld b,000h
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
sub_554fh:
	ld hl,l5575h
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
l5575h:
	nop
	jp (hl)
	nop
	jp (hl)
	nop
	jp (hl)
	nop
	jp (hl)
	nop
	jp (hl)
	nop
	ret pe
	jr nz,$-22
	ld b,b
	ret pe
	nop
	jp (hl)
	ld h,b
	ret pe
	add a,b
	ret pe
	nop
	jp (hl)
	and b
	ret pe
	ret nz
	ret pe
	ret po
	ret pe
	nop
	jp (hl)
l5595h:
	defb 003h,008h,002h,00eh,00fh
; load_weapon_sprites (seg0 0x559A): RLE-decompress the equipped projectile
; (C416 2=knife / 3=axe / 4=cross) from seg10 into sprite gen 0xF8C0, then
; gfx_script_convert converts 1bpp quadrants.  Leather/chain (0/1) and 5 skip.
; Catalogued as gfx/weapon_knife, weapon_axe, weapon_cross.
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
	call sub_5642h
	ld hl,0d410h
	ld c,00dh
	call sub_5642h
	ld hl,0d420h
	ld c,00eh
	call sub_5642h
	ld hl,0d430h
	ld c,002h
sub_5642h:
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
	call page_title_banks
	ld hl,frontend_tiles
	jr tileset_blit
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
;  Catalogued as gfx/simon_cell0 + gfx/simon_cell1.
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
	call palette_hud_load
	call page_title_banks
	ld hl,pal_bfa1
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
	call l4805h
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
; (nibble-swap via sub_5873h, also used to H-mirror portrait 16x16s).
dracula_body_hflip:
	ld hl,0e800h
	ld de,0e80fh
	ld c,020h
l5860h:
	ld b,008h
	call sub_5873h
	ld a,008h
	call ADD_HL_A
	ld a,018h
	call ADD_DE_A
	dec c
	jr nz,l5860h
	ret
sub_5873h:
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
	djnz sub_5873h
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
	call sub_589ch
	call sub_58d3h
	call sub_5931h
	call dracula_portrait_parts_load
	call dracula_portrait_parts_mirror
	jp page_play_banks
sub_589ch:
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
sub_58d3h:
	ld hl,dracula_frame_ad78
	ld b,001h
	ld de,08074h
	call sub_58f1h
	ld hl,dracula_face
	ld b,06ch
	ld de,09028h
	call sub_58f1h
	ld hl,dracula_frame_acf8
	ld b,002h
	ld de,08048h
sub_58f1h:
	push bc
	push de
	push hl
	call sub_5904h
	pop hl
	ld de,00020h
	add hl,de
	pop de
	call sub_5962h
	pop bc
	djnz sub_58f1h
	ret
sub_5904h:
	push de
	ld de,0e800h
	ld bc,00020h
	ldir
	call sub_5919h
	pop de
	ld hl,0e800h
	ld b,001h
	jp vram_blit_tile_run
sub_5919h:
	ld hl,0e800h
	ld de,0e803h
	ld c,008h
l5921h:
	ld b,002h
	call sub_5873h
	inc hl
	inc hl
	ld a,006h
	call ADD_DE_A
	dec c
	jr nz,l5921h
	ret
sub_5931h:
	ld hl,08048h
	ld b,002h
	ld de,08058h
	call sub_594fh
	ld hl,08040h
	ld b,002h
	ld de,08050h
	call sub_594fh
	ld hl,08060h
	ld b,002h
	ld de,08068h
sub_594fh:
	push bc
	push de
	push hl
	call sub_5970h
	pop de
	call sub_5962h
	ex de,hl
	pop de
	call sub_5962h
	pop bc
	djnz sub_594fh
	ret
sub_5962h:
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
sub_5970h:
	push de
	ld de,0e818h
	ld b,008h
l5976h:
	push bc
	ld bc,00004h
	call sub_4661h
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
	jp l4a97h
dracula_portrait_parts_mirror:
	ld b,004h
	ld hl,dracula_portrait_parts_hi
	ld de,0d040h
l59a5h:
	push bc
	push de
	push hl
	call sub_59c3h
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
sub_59c3h:
	push de
	ld de,0e800h
	ld bc,00080h
	ldir
	call sub_59d8h
	pop de
	ld hl,0e800h
	ld b,001h
	jp l4a97h
sub_59d8h:
	ld hl,0e800h
	ld de,0e807h
	ld c,010h
l59e0h:
	ld b,004h
	call sub_5873h
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
;   nibble != 0 (intl/other)-> 0x59 "VAMPIRE KILLER" glyphs       (seg8 0xB260)
title_load_tiles:
	call page_tileset_late         ; page in the title graphics banks (seg7/seg8)
	ld hl,0ac80h           ; 0x11 shared castle glyphs (seg8 0xAC80)...
	ld de,08004h           ; ...to VRAM 0x8004
	ld b,011h
	call vram_blit_tile_run
	ld a,(0002bh)          ; MSX character set (0 = Japanese)...
	and 00fh
	jr nz,l5a2ah           ; non-zero -> international glyphs
	ld hl,0aea0h           ; Japanese: 0x1E "Akumajo Dracula" kana glyphs
	ld b,01eh
	call vram_blit_tile_run
	call page_map_banks
	ld de,0bbf6h
	call rle_dec_addr
	jr l5a32h
l5a2ah:                        ; international/other machine
	ld hl,0b260h           ; 0x59 "VAMPIRE KILLER" glyphs (seg8 0xB260)
	ld b,059h
	call vram_blit_tile_run
l5a32h:
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
; 0x480), then compact vendor ids into 0xDE00 (l5ab6h). Instantiation of
; the current room is scenery_room_load (from actor_state_reset).
scenery_load:                  ; 0x5A50
	ld hl,0e000h
	ld de,0e001h
	ld (hl),000h
	ld bc,0047fh           ; clear 0xE000..0xE47F
	ldir
	call scenery_unpack
	jp l5ab6h
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
l5ab6h:
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
	call sub_5adeh
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
sub_5adeh:
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
; Walked by the 0xDE00 compact (l5ab6h). Trailing zeros unused.
vendor_offer_id:
	defb 00eh              ; 0 candle
	defb 012h              ; 1 staff
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
; C5B5/C5C5 (vendors). Attr bits7-5: 000 floor, 001 candle, 011 32x32 block,
; 10x chest, 11x vendor. Block stamps 4x4 brick tiles over the nametable.
scenery_room_load:
	call scenery_room_ptr
	ld de,0c470h
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
	jr nz,l5bach
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
	jr nz,l5b61h           ; 001 candle -> 0, else block (011 -> 2)
	ld a,(0d000h)
	or a
	jr z,l5b61h            ; courtyard candle: kind 1
	ld a,0ffh              ; castle candle: kind 0
l5b61h:
	inc a
	ld (de),a              ; +04 kind (0 candle / 1 brazier / 3 4x4 block)
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
	call sub_5b9dh
	call 08a04h
	jr l5b7ch
sub_5b9dh:
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
	call sub_5b9dh
	call 08a1ah
	jr l5b7ch
l5bbeh:
	push hl
	pop ix
	call sub_5b9dh
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
	call break_spark_tick   ; C5A6 whip sparks (seg2 0x88DF)
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
;  the last 6 bytes of a 16K cartridge page - against game_master_sig.
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
game_master_sig:               ; Game Master ROM fingerprint: 6 bytes at 0x7FFA
	defb 000h,030h,031h,013h,035h,0aah
; gm_menu_draw (0x5CF6) - clear the menu area, frame it, then print gm_menu_text.
gm_menu_draw:
	call gm_menu_clear
	ld c,00eh              ; frame ink 0x0E
	call vdp_box
	ld hl,gm_menu_text
	jp l4ad2h
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
sub_5d15h:
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
	jp l457fh              ; print B bytes as 2 BCD digits each
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
	jp l4ad2h
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
	call l457fh
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
	jp sub_4aeeh
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
	defb 047h
entity_tbl_end:

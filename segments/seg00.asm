; ===========================================================================
;  SEGMENT 0 - resident bank.  Paged at 0x4000-0x5FFF for the whole game and
;  holds the boot/init code, the interrupt handler, the bank-switch helpers
;  and the top-level game state machine.
;  (Origin is set by PHASE 0x4000 in VampireKiller.asm; regenerate the raw
;   disassembly with  tools/regen-seg.sh 0 0x4000 tools/seg00.blocks .)
;
;  MSX/MSX2 BIOS entry-point names used below (ENASLT, WRTVDP, ...) are defined
;  once in segments/bios.inc, included by VampireKiller.asm before this file.
; ===========================================================================

; --- 16-byte MSX cartridge header (ROM offset 0) ---------------------------
;   +0  "AB"      magic identifying an MSX ROM cartridge
;   +2  INIT      entry point called at boot           -> 0x4075
;   +4  STATEMENT expansion BASIC statement handler    -> none (0)
;   +6  DEVICE    expansion device handler             -> none (0)
;   +8  TEXT      BASIC program pointer                -> none (0)
;   +10 reserved (6 bytes, 0)
rom_header_start:
	defb 041h               ; 'A'  cartridge magic
	defb 042h               ; 'B'
	defb 075h               ; INIT lo  \ entry = 0x4075
	defb 040h               ; INIT hi  /
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
;  INT_HANDLER - timer interrupt (H.TIMI hook, installed by INIT at 0xFD9F).
;  Runs once per VDP frame: per-frame sound/VDP work out of segs 14/15, then
;  the game tick.  Two guards keep a slow tick from re-entering itself.
; ===========================================================================
INT_HANDLER:
	di
	ld a,(0e600h)           ; hard re-entrancy guard (outer)
	or a
	jp nz,l40c5h            ; already inside a tick -> just read keys
l4030h:
	di
	ld a,00eh               ; page segment 14...
	ld (08000h),a           ; ...into 0x8000-0x9FFF
	ld a,00fh               ; page segment 15...
	ld (0a000h),a           ; ...into 0xA000-0xBFFF
	call 08964h             ; per-frame work in seg 14/15 (sound/VDP)
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
	call sub_414dh          ; MAIN TICK (top-level state machine)
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
;  INIT - cartridge entry point (from header +2).  Called by the BIOS at boot:
;  find this ROM's slot, page it into CPU page 2 (0x8000-0xBFFF), clear RAM,
;  init subsystems, install the interrupt hook, then idle - the game then runs
;  entirely from INT_HANDLER.
; ===========================================================================
INIT:
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
	call sub_533dh          ; init subsystem
	call sub_5c99h          ; init subsystem
	call sub_533dh
	call sub_4b60h          ; init subsystem
	di
	ld a,0c3h               ; opcode for JP
	ld (0fd9fh),a           ; install timer-interrupt hook (H.TIMI)...
	ld hl,data_4010_end     ; ...JP INT_HANDLER (=data_4010_end, 0x4028)
	ld (0fda0h),hl
	xor a
	ld (0f3dbh),a
	ei                      ; interrupts on: game now runs from the tick
l40c3h:
	jr l40c3h               ; idle forever; work happens in INT_HANDLER
; l40c5h - light path when INT_HANDLER re-enters during a busy tick: just
; sample the SPACE key / joystick trigger so input isn't missed.
l40c5h:
	ld a,007h               ; scan keyboard matrix row 7...
	call SNSMAT
	cpl
	and 010h                ; ...bit 4 = SPACE
	ld b,a
	ld a,001h               ; scan row 1...
	call SNSMAT
	cpl
	and 080h                ; ...bit 7
	or b                    ; merge the two key bits
	ld hl,0e610h
	ld c,(hl)
	ld (hl),a
	xor c
	and (hl)
	ld c,a
	ld hl,0e601h
	ld a,(hl)
	or a
	jr nz,l40f1h
	bit 4,c
	jp z,l4030h
	ld (hl),c
	call sub_4107h
	ei
	ret
l40f1h:
	bit 7,c
	jp nz,l40fch
	bit 4,c
	jr z,l4102h
	xor a
	ld (hl),a
l40fch:
	call sub_4132h
	jp l4030h
l4102h:
	call sub_411fh
	ei
	ret
sub_4107h:
	ld a,008h
	call RDPSG
	ld (0e611h),a
	ld a,009h
	call RDPSG
	ld (0e612h),a
	ld a,00ah
	call RDPSG
	ld (0e613h),a
sub_411fh:
	ld e,000h
	ld a,008h
	call WRTPSG
	ld e,000h
	inc a
	call WRTPSG
	ld e,000h
	inc a
	jp WRTPSG
sub_4132h:
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
;  sub_414dh - MAIN TICK / top-level game state machine.  Called once per
;  frame from INT_HANDLER.  Two-level state:
;     0xC000 = primary state  (C) -> selects a handler from main_state_tbl
;     0xC001 = secondary state (B) -> sub-phase, read by the `djnz` ladders
;              inside each handler (each `djnz` skips one sub-state).
;     0xC003 = free-running frame counter (bumped every tick).
;  For the three front-end states (0..2: logo / title / attract) the shared
;  post-handler l4398h is pushed as a return address so it runs after the
;  handler and drives the "press SPACE/trigger to start" transition.
; ===========================================================================
sub_414dh:
	ld hl,0c003h            ; frame counter...
	inc (hl)                ; ...++
	ld bc,(0c000h)          ; C=primary state, B=secondary state
	ld a,c
	cp 003h                 ; front-end states 0..2?
	jr nc,l415eh            ; no -> in-game, skip post-handler
	ld hl,l4398h            ; yes -> run front-end post-handler...
	push hl                 ; ...after the state handler returns
l415eh:
	call DISPATCH_A         ; jump to main_state_tbl[primary state]

; main_state_tbl - primary game-state handlers (indexed by 0xC000).
; Roles are inferred from the boot flow / behaviour (see docs/game-notes.md);
; the front-end trio matches logo -> title -> attract.
main_state_tbl:
	defw 0417dh             ; 0  front-end: Konami logo        (*)
	defw 041a0h             ; 1  front-end: title screen       (*)
	defw 041abh             ; 2  front-end: attract / demo     (*)
	defw 041d1h             ; 3  in-game phase
	defw 0422ch             ; 4  in-game phase
	defw 04257h             ; 5  in-game phase
	defw 04294h             ; 6  in-game phase
	defw 042b2h             ; 7  in-game phase
	defw 04324h             ; 8  in-game phase
	defw 0437eh             ; 9  in-game phase
	defw 0438eh             ; 10 in-game phase
	defw 043e1h             ; 11 in-game phase
	defw 043f7h             ; 12 in-game phase
	defw 0441bh             ; 13 in-game phase
main_state_tbl_end:
	djnz l418ah
	call KONAMI_LOGO_STEP   ; wipe the Konami logo in one more row (seg1)
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
	call sub_4d4eh
	xor a
	jp l424bh
l4198h:
	call sub_47c0h
	call KONAMI_LOGO_DRAW   ; draw Konami logo + start the top-to-bottom wipe (seg1)
	jr l41cch
	ld hl,0c004h
	dec (hl)
	ret nz
	call 07aeeh
	jp l4249h
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
	call sub_44cdh
	jp l41cch
l41ech:
	djnz l41fbh
	ld a,001h
	ld (0c41ah),a
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
	ld (0c41ah),a
	call 062d7h
	ld hl,0e604h
	ld a,(hl)
	or a
	jr z,l4220h
	ld (hl),000h
	call sub_5e38h
l4220h:
	jr l4249h
l4222h:
	ld a,08ah
	call sub_50a6h
	ld a,050h
	jp l41c9h
	ld hl,0c410h
	ld a,(hl)
	sub 001h
	daa
	ld (hl),a
	call sub_47dbh
	call sub_451ah
	call 062edh
	ld hl,0c413h
	ld (hl),001h
	call 07956h
	xor a
	ld (0c40dh),a
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
	call sub_5c2ch
	ld a,(0c40ch)
	or a
	ld a,00ch
	jp nz,l41b6h
	ld a,(0c40ah)
	and a
	jp nz,l428ch
	ld a,(0c41bh)
	and a
	ld a,009h
	jp nz,l41b6h
	ld a,(0c408h)
	or a
	ld a,00ah
	jp nz,l41b6h
	ld a,(0c409h)
	and a
	ld a,008h
	jp nz,l41b6h
	ld a,(0c413h)
	or a
	ret nz
	jr l4249h
l428ch:
	call sub_449ch
	ld a,00bh
	jp l41b6h
	ld hl,0c410h
	ld a,(hl)
	or a
	jr z,l42abh
l429bh:
	call 062d7h
	xor a
	ld (0c420h),a
	inc a
	ld (0c40dh),a
	ld a,004h
	jp l41b6h
l42abh:
	ld a,08bh
	call sub_50a6h
	jr l4249h
	djnz l42e3h
	ld a,(0e600h)
	or a
	jr z,l42bfh
	call sub_4314h
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
	ld hl,l4d41h
	call l4ad2h
	ld a,(0e600h)
	or a
	jr z,l42f8h
	ld hl,l4300h
	call l4ad2h
l42f8h:
	call sub_451ah
	ld a,078h
	jp l41c9h
l4300h:
	ld d,b
	ld l,b
	ld (hl),025h
	cp 064h
	ld l,b
	ld c,a
	cp 070h
	ld l,b
	inc sp
	ccf
	ld a,044h
	add hl,sp
	ld a,045h
	dec (hl)
	rst 38h
sub_4314h:
	ld a,007h
	call SNSMAT
	cpl
	and 002h
	ld hl,0e614h
	ld c,(hl)
	ld (hl),a
	xor c
	and (hl)
	ret
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
	ld (0c415h),a
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
l434eh:
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
	inc (hl)
	inc hl
	xor a
	ld (hl),a
	ld (0c409h),a
	ld (0c408h),a
	ld a,004h
	jp l41b6h
	ld hl,CHKRAM
	ld (0c000h),hl
	ret
l4377h:
	call sub_47c0h
	xor a
	jp l41c9h
	call sub_5a35h
	ld a,006h
	jp nc,l41b6h
	call 062fch
	ld a,005h
	jp l41b6h
	ld hl,0c701h
	ld a,(hl)
	and 0feh
	ld (hl),a
	jp l434eh
; ===========================================================================
;  l4398h - front-end post-handler (runs after the logo/title/attract handler,
;  states 0..2).  Reads the start input; on press it moves logo/attract back to
;  the title, or (from the title) begins the game.
; ===========================================================================
l4398h:
	call sub_4bc2h          ; front-end per-frame update (anim/timer)
	ld hl,0c401h            ; 0xC401 = start/trigger input state
	call sub_4bbbh          ; A = newly-pressed buttons this frame
	or a
	ret z                   ; nothing pressed -> stay in this state
	ld hl,0c004h            ; reset the sub-state timer...
	ld (hl),000h            ; ...(0xC004 = 0)
	ld hl,0c000h            ; HL -> primary state (0xC000)
	ld b,(hl)               ; B = current state
	djnz l43c1h             ; state != 1 (logo/attract) -> back to title
	and 030h                ; title: was it SPACE/trigger (bits 4,5)?
	ret z                   ; other key -> ignore
	ld a,040h
	ld (0c002h),a           ; flag "start pressed"
	ld a,(0e600h)           ; in a tick already? (demo/attract guard)
	or a
	jr nz,l43cbh            ; yes -> full game-start setup
	ld (hl),003h            ; else advance to state 3 (in-game)...
	inc hl
	ld (hl),b               ; ...0xC001 = old state as sub-state
	ret
; state 0 (logo) or 2 (attract) + any press -> return to the title screen.
l43c1h:
	ld (hl),001h            ; primary state = 1 (title)
	ld a,000h
	call sub_50a6h          ; request sound/music change
	jp sub_4d4eh            ; (re)build the title screen
; l43cbh - full game start: seed the run state then enter gameplay.
l43cbh:
	xor a
	ld (0e604h),a           ; clear a run flag
	ld a,001h
	ld (0e605h),a           ; initial lives / level counters...
	ld (0e606h),a
	ld a,003h
	ld (0e607h),a
	ld a,00dh               ; A = 0x0D -> next-state selector
	jp l41b6h               ; enter gameplay via the state setter
	ld a,(0c00bh)
	rra
	ret nc
	xor a
	ld (0c40ah),a
	call sub_44bfh
	ld a,0feh
	call sub_50a6h
	ld a,005h
	jp l41b6h
	djnz l4402h
	call 094c1h
	ret nz
	ld a,00fh
	jp l41c9h
l4402h:
	djnz l4411h
	ld hl,0c004h
	dec (hl)
	ret nz
	call 0950eh
	ld a,005h
	jp l41b6h
l4411h:
	xor a
	ld (0c40ch),a
	call 0938eh
	jp l41cch
	djnz l4453h
	ld a,(0c006h)
	and 033h
	ret z
	and 003h
	jp nz,l5e84h
	ld a,(0e60bh)
	or a
	jp nz,l4439h
	call sub_5d04h
	ld hl,00003h
	ld (0c000h),hl
	ret
l4439h:
	dec a
	jr z,l4447h
	ld hl,0b8b8h
	ld (0e602h),hl
l4442h:
	call sub_5d89h
	jr l4450h
l4447h:
	ld hl,0b0b8h
	ld (0e602h),hl
	call sub_5d68h
l4450h:
	jp l41cch
l4453h:
	djnz l4488h
	call sub_5e28h
	jr nz,l445dh
	jp l5db9h
l445dh:
	ld a,(0e60bh)
	ld b,a
	ld hl,0e604h
	or (hl)
	ld (hl),a
	ld a,(0e615h)
	or a
	jr z,l447eh
	ld a,(0e60eh)
	ld d,a
	ld a,(0e60fh)
	bit 0,b
	jr z,l4483h
	ld (0e605h),a
	ld a,d
	ld (0e606h),a
l447eh:
	xor a
	ld (0c001h),a
	ret
l4483h:
	ld (0e607h),a
	jr l447eh
l4488h:
	call sub_5cf6h
	xor a
	ld hl,0e608h
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
	call sub_494dh
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
	jp sub_494dh
sub_44cdh:
	ld hl,0c405h
	ld bc,01bfbh
	ld d,h
	ld e,l
	inc e
	ld (hl),000h
	ldir
	ld hl,l44f0h
	ld de,0c410h
	ld bc,00003h
	ldir
	ld a,020h
	ld (0c415h),a
	ld a,080h
	ld (0c418h),a
	ret
l44f0h:
	inc bc
	nop
	ld bc,0000eh
	ld a,(0c002h)
	add a,a
	ret p
	ld hl,0c405h
	ld a,(hl)
	add a,e
	daa
	ld (hl),a
	inc l
	ld a,(hl)
	adc a,d
	daa
	ld (hl),a
	inc hl
	ld a,(hl)
	adc a,c
	daa
	ld (hl),a
	jr nc,l4538h
	ld bc,09999h
	ld (0c402h),bc
	ld (0c403h),bc
	jr l4538h
sub_451ah:
	ld hl,l4c07h
	call l4ad2h
	call sub_4542h
	call sub_456dh
	call sub_4575h
	call sub_45b7h
	call sub_454ch
	call 08ea1h
	call 08ebbh
	call 08eedh
l4538h:
	ld hl,0c407h
	ld de,03800h
	ld b,003h
	jr l457fh
sub_4542h:
	ld de,09c00h
	ld hl,0c411h
	ld b,001h
	jr l457fh
sub_454ch:
	ld hl,07f0bh
	ld de,01212h
	ld c,008h
	call sub_48e3h
	ld hl,0930bh
	ld de,02212h
	ld c,00eh
	call sub_48e3h
	ld hl,0b70bh
	ld de,04212h
	ld c,00eh
	jp sub_48e3h
sub_456dh:
	ld hl,0c417h
	ld de,0c000h
	jr l457bh
sub_4575h:
	ld hl,0c410h
	ld de,0e400h
l457bh:
	ld b,001h
	jr l457fh
l457fh:
	ld a,(hl)
	rra
	rra
	rra
	rra
	call sub_458fh
	ld a,(hl)
	call sub_458fh
	dec hl
	djnz l457fh
	ret
sub_458fh:
	and 00fh
	add a,020h
	call sub_4aeeh
	ld a,d
	add a,008h
	ld d,a
	ret
	ld hl,0c417h
	ld a,(hl)
	add a,b
	daa
	jr nc,l45a5h
	ld a,099h
l45a5h:
	jr l45b0h
	ld hl,0c417h
	ld a,(hl)
	cp b
	jr c,l45b4h
	sub b
	daa
l45b0h:
	ld (hl),a
	jp sub_456dh
l45b4h:
	xor a
	jr l45b0h
sub_45b7h:
	call sub_45c0h
l45bah:
	call sub_45c6h
	jp l45ech
sub_45c0h:
	call sub_45cfh
	jp l45d8h
sub_45c6h:
	ld hl,03b16h
	ld bc,l4206h
l45cch:
	jp sub_5d15h
sub_45cfh:
	ld hl,03b0dh
	ld bc,l4206h
	jp l45cch
l45d8h:
	ld hl,0c415h
	ld a,(hl)
	ld hl,03c0eh
	add a,a
	or a
	ret z
	ld b,a
	ld c,004h
	ld d,000h
	ld a,011h
	jp l4911h
l45ech:
	ld hl,0c418h
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
	jp l4911h
l460ch:
	ld hl,0c415h
	ld a,(hl)
	add a,b
	cp 021h
	jr c,l461bh
	ld a,020h
	sub (hl)
	ld b,a
	ld a,020h
l461bh:
	ld (hl),a
	jp sub_45c0h
	ld hl,0c418h
	ld a,(hl)
	add a,b
	cp 081h
	jr c,l462eh
	ld a,080h
	sub (hl)
	ld b,a
	ld a,080h
l462eh:
	ld (hl),a
	jp l45bah
l4632h:
	ld hl,0c415h
	ld a,(hl)
	cp b
	jr nc,l463ah
	ld b,a
l463ah:
	ld a,b
	or a
	ret z
	ld a,(hl)
	sub b
	ld (hl),a
	jp sub_45c0h
l4643h:
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
	jr l4632h
	ld b,001h
	jp l460ch
	ld b,001h
	jr l4643h
sub_4661h:
	call sub_46d5h
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
sub_467ch:
	ex de,hl
	call sub_46b6h
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
	call sub_46b6h
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
	call sub_46b6h
	ld a,(00007h)
	ld c,a
	pop af
	out (c),a
	pop bc
	ret
; --- sub_46b6h - set the VDP VRAM write pointer to the 16-bit address in HL.
;     Programs R14 (A14-A16 = top 2 bits of H) then the auto-increment address
;     low/high via port 0x99, with bit6 set to select "write" mode.  Used before
;     streaming pixel data to the data port 0x98.
sub_46b6h:
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
sub_46d5h:
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
;       l46f2h : variant that first reads the 2-byte dest address FROM the
;                stream (used when the caller doesn't set HL itself).
;       sub_46f8h : standard entry (HL already holds the dest address).
;     Control-byte grammar (source read linearly; output goes to the VRAM
;     write pointer set via sub_46b6h, streamed to data port 0x98):
;       0x00           -> end of stream (ret)
;       0x80  lo hi    -> set VRAM write pointer = hi<<8 | lo  (jump to l46f2h)
;       0x01..0x7F  N  -> RUN     : next single byte repeated N times
;       0x81..0xFF  N  -> LITERAL : copy (N & 0x7F) bytes verbatim via OTIR
;     Tools: tools/rledec.py replays this exact grammar to extract graphics.
l46f2h:
	ex de,hl                ; read a fresh 2-byte dest address...
	ld e,(hl)               ; ...from the source stream (0x80 command)
	inc hl
	ld d,(hl)
	inc hl
	ex de,hl
sub_46f8h:
	call sub_46b6h          ; point VDP at dest VRAM address (HL)
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
	jr z,l46f2h
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
l471bh:
	ld a,(hl)
	inc hl
	inc a
	ret z
	dec a
	or a
	jr z,l472bh
	dec a
	jr z,l4730h
	call sub_4772h
	jr l471bh
l472bh:
	call sub_4735h
	jr l471bh
l4730h:
	call sub_4745h
	jr l471bh
sub_4735h:
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
	call sub_46f8h
	pop hl
	ret
sub_4745h:
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
	call sub_467ch
	pop hl
	ret
sub_4772h:
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
	call sub_467ch
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
	ld bc,CHKRAM
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
	ld hl,CHKRAM
	xor a
	ld d,a
	call l4911h
	ld b,000h
	ld c,017h
	jp WRTVDP
sub_47f7h:
	ld hl,0f600h
	ld a,0e0h
	ld bc,00080h
	call sub_468fh
	jp 063cch
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
sub_481bh:
	push bc
	push hl
	ld b,a
	ld a,(00007h)
	inc a
	ld c,a
	di
	out (c),b
	ld a,090h
	out (c),a
	inc c
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
	call sub_46b6h
	dec c
	out (c),d
	out (c),e
	pop hl
	pop bc
	ei
	ret
l4845h:
	ld a,(hl)
	inc hl
	inc a
	ret z
	dec a
	ld d,(hl)
	inc hl
	ld e,(hl)
	inc hl
	call sub_481bh
	jr l4845h
l4853h:
	ld a,002h
	call sub_485ch
	rra
	jr c,l4853h
	ret
sub_485ch:
	push bc
	push hl
	ld hl,(00006h)
	inc h
	inc l
	ld c,h
	di
	out (c),a
	ld a,08fh
	out (c),a
	ld c,l
	in a,(c)
	push af
	xor a
	ld c,h
	out (c),a
	ld a,08fh
	out (c),a
	pop af
	pop hl
	pop bc
	ei
	ret
sub_487ch:
	call l4853h
	push bc
	ld a,(00007h)
	inc a
	ld c,a
	ld a,024h
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
	out (c),a
	pop hl
	dec h
	out (c),h
	xor a
	out (c),a
	xor a
	out (c),a
	out (c),a
	out (c),l
	out (c),a
	ld a,070h
	out (c),a
	ei
	ret
sub_48afh:
	call l4853h
	push bc
	ld a,(00007h)
	inc a
	ld c,a
	ld a,024h
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
	out (c),a
	pop hl
	dec h
	out (c),h
	xor a
	out (c),a
	xor a
	out (c),a
	out (c),a
	out (c),l
	inc a
	out (c),a
	ld a,070h
	out (c),a
	ei
	ret
sub_48e3h:
	ld b,e
	call sub_48fdh
	ld b,d
	call sub_4907h
	push hl
	ld a,l
	dec a
	add a,e
	ld l,a
	ld b,d
	call sub_4907h
	pop hl
	ld a,h
	dec a
	add a,d
	ld h,a
	ld b,e
	jp sub_48fdh
sub_48fdh:
	push hl
	push de
	push bc
	call sub_48afh
	pop bc
	pop de
	pop hl
	ret
sub_4907h:
	push hl
	push de
	push bc
	call sub_487ch
	pop bc
	pop de
	pop hl
	ret
l4911h:
	ex af,af'
	call l4853h
	push bc
	ld a,(00007h)
	inc a
	ld c,a
	ld a,024h
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
	out (c),d
	pop hl
	out (c),h
	cp h
	jr nz,l4936h
	inc a
l4936h:
	out (c),a
	xor a
	out (c),l
	cp l
	jr nz,l493fh
	inc a
l493fh:
	out (c),a
	ex af,af'
	out (c),a
	xor a
	out (c),a
	ld a,0c0h
	out (c),a
	ei
	ret
sub_494dh:
	ex af,af'
	call l4853h
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
sub_4991h:
	ex af,af'
	call l4853h
	push bc
	ld a,(00007h)
	inc a
	ld c,a
	ld a,024h
	di
	out (c),a
	ld a,091h
	out (c),a
	inc c
	inc c
	out (c),d
	xor a
	out (c),a
	out (c),e
	ex af,af'
	out (c),a
	pop de
	out (c),d
	xor a
	out (c),a
	out (c),e
	out (c),a
	ld a,(hl)
	inc hl
	out (c),a
	xor a
	out (c),a
	ld a,0f0h
	out (c),a
	dec c
	dec c
	ld a,0ach
	out (c),a
	ld a,091h
	out (c),a
	inc c
	inc c
l49d1h:
	ld a,002h
	call sub_485ch
	rra
	ret nc
	add a,a
	add a,a
	jr nc,l49d1h
	ld a,(hl)
	inc hl
	out (c),a
	jr l49d1h
sub_49e2h:
	ex af,af'
	call l4853h
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
l4a2eh:
	call sub_4a37h
	call sub_4b56h
	djnz l4a2eh
	ret
sub_4a37h:
	push bc
	push de
	push hl
	push de
	call sub_4aach
	pop de
	ld b,d
	ld d,e
	ld e,b
	srl d
	rr e
	ld a,d
	add a,080h
	ld d,a
	ld hl,0c110h
	call sub_4a58h
	pop hl
	ld bc,SYNCHR
	add hl,bc
	pop de
	pop bc
	ret
sub_4a58h:
	push de
	ld b,008h
l4a5bh:
	push bc
	ld bc,00004h
	call sub_467ch
	ex de,hl
	ld bc,00080h
	add hl,bc
	ex de,hl
	pop bc
	djnz l4a5bh
	pop de
	ret
l4a6dh:
	push bc
	call sub_4a58h
	ld a,004h
	add a,e
	cp 080h
	jr nz,l4a7dh
	ld a,004h
	add a,d
	ld d,a
	xor a
l4a7dh:
	ld e,a
	pop bc
	djnz l4a6dh
	ret
sub_4a82h:
	push de
	ld b,010h
l4a85h:
	push bc
	ld bc,SYNCHR
	call sub_467ch
	ex de,hl
	ld bc,00080h
	add hl,bc
	ex de,hl
	pop bc
	djnz l4a85h
	pop de
	ret
l4a97h:
	push bc
	call sub_4a82h
	ld a,008h
	add a,e
	cp 080h
	jr nz,l4aa7h
	ld a,008h
	add a,d
	ld d,a
	xor a
l4aa7h:
	ld e,a
	pop bc
	djnz l4a97h
	ret
sub_4aach:
	ld b,008h
	ld de,0c110h
l4ab1h:
	push bc
	push hl
	ex de,hl
	ld a,(de)
	ld d,a
	ld b,004h
l4ab8h:
	ld a,c
	rl d
	jr c,l4abeh
	xor a
l4abeh:
	rld
	ld a,c
	rl d
	jr c,l4ac6h
	xor a
l4ac6h:
	rld
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
	ld a,(hl)
	inc hl
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
	call sub_4b48h
	add a,038h
l4afah:
	ld l,a
	ld bc,00808h
	ld a,001h
	call sub_494dh
	pop de
	pop hl
	pop bc
	ret
l4b07h:
	push af
	call sub_4aeeh
	call sub_4b56h
	pop af
	djnz l4b07h
	ret
sub_4b12h:
	push bc
	push hl
	push de
	call sub_4b48h
	ld bc,00808h
	ld a,001h
	call sub_494dh
	pop de
	pop hl
	pop bc
	ret
	push bc
	push hl
	push de
	call sub_4b48h
	ld bc,00808h
	ld a,048h
	call sub_49e2h
	pop de
	pop hl
	pop bc
	ret
	push bc
	push hl
	push de
	call sub_4b48h
	ld bc,00808h
	ld a,005h
	call sub_494dh
	pop de
	pop hl
	pop bc
	ret
sub_4b48h:
	ld b,a
	and 01fh
	add a,a
	add a,a
	add a,a
	ld h,a
	ld a,b
	and 0e0h
	rrca
	rrca
	ld l,a
	ret
sub_4b56h:
	ld a,d
	add a,008h
	ld d,a
	ret nz
	ld a,e
	add a,008h
	ld e,a
	ret
; --- sub_4b60h - video subsystem init.  Selects SCREEN 5 (VDP mode G4:
;     256x212, 16 colours, 4 bits/pixel bitmap).  This is why the graphics
;     banks (seg 4-9, 15) hold 4bpp bitmap data blitted to VRAM with the VDP
;     command engine (see sub_48e3h / l4911h), rather than 1bpp tile patterns.
;     Actors are drawn with hardware sprites (mode 2, 16x16).  After the mode
;     switch it clears VRAM page 0/1 via the block-fill helper l4911h.
sub_4b60h:
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
	call l4911h
	xor a
	ld h,a
	ld l,a
	ld b,a
	ld c,a
	ld d,001h
	call l4911h
	call l4853h
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
	call sub_4bfbh
	ld hl,0c00ch
	call sub_4bbbh
	call sub_4bc2h
l4bb8h:
	ld hl,0c007h
sub_4bbbh:
	ld c,(hl)
	ld (hl),a
	xor c
	and (hl)
	dec hl
	ld (hl),a
	ret
sub_4bc2h:
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
sub_4bfbh:
	ld a,006h
	call SNSMAT
	cpl
	rlca
	rlca
	rlca
	and 007h
	ret
; --- HUD / status-bar text set (drawn via 0x451a).  Text is ASCII-0x10, spelled
;     out here with vk(); leading numbers are VDP name-table positions, 0xFE ends
;     a field and 0xFF ends the set.  Byte-for-byte identical to the original.
l4c07h:
	LUA ALLPASS
	  vk({0x08,0x00,"SCORE",0x30,0xfe})           -- "SCORE" + score-digit tile
	  vk({0x08,0x0c,"PLAYER",0xfe})               -- "PLAYER"
	  vk({0x08,0x14,"ENEMY",0xfe})                -- "ENEMY" (0x14 = HP-bar icon)
	  vk({0xb0,0x00,0x50,0x30,0xfe})              -- enemy HP-bar cell position
	  vk({0xd4,0x00,0x40,0x30,0xfe})              -- player HP-bar cell position
	  vk({0x6c,0x00,"STAGE",0x30,0xff})           -- "STAGE" + number tile
	  vk({0x60,0x38,"STAGE",0x00,0x00,0x00,0xff}) -- "STAGE" (alternate position)
	ENDLUA
; --- 0x4C3F-0x4D0E: VDP name-table / tile-layout data for the title & HUD
;     screens (referenced by sub_4d4eh via l4c3fh/l4c5ah/l4ca0h).  This is DATA;
;     the instructions z80dasm shows below are a misdisassembly of that data and
;     are never executed.  TODO: convert to `db` (byte-exact) in a later pass.
l4c3fh:
	ld (bc),a
	cp 0f8h
	inc bc
	inc b
	cp 0f8h
	dec b
	ld b,007h
	ex af,af'
	cp 000h
	add hl,bc
	ld a,(bc)
	dec bc
	inc c
	dec c
	cp 0f8h
	ld c,00fh
	ld bc,01001h
	ld de,02fffh
	cpl
	cp 0b0h
	ld d,017h
	jr $+23
	ld bc,00101h
	ld bc,02f28h
	cpl
	ld (de),a
	inc de
	inc d
	dec d
	cp 000h
	ld h,023h
	inc h
	dec h
	ld bc,00101h
	ld bc,01a19h
	dec de
l4c7ah:
	ld (02423h),hl
	dec h
	cp 000h
	inc e
	dec e
	ld e,01fh
	ld bc,00101h
	ld bc,02a29h
	dec hl
	inc e
	dec e
	ld e,01fh
	cp 000h
	jr nz,$+35
	inc l
	ld bc,00101h
	ld bc,02d01h
	ld l,027h
	jr nz,l4cbfh
	inc l
	rst 38h
l4ca0h:
	ld h,a
	ld (de),a
	inc de
	inc d
	dec d
	ld d,017h
	jr $+27
	ld a,(de)
	dec de
	inc e
	dec e
	ld e,01fh
	jr nz,$+35
	cp 008h
	ld (02423h),hl
	dec h
	ld h,027h
	jr z,l4ce4h
	ld hl,(02c2bh)
	dec l
l4cbfh:
	ld l,02fh
	jr nc,l4cf4h
	cp 000h
	ld (03433h),a
	dec (hl)
	ld (hl),037h
	jr c,l4d06h
	ld a,(03c3bh)
	dec a
	ld a,03fh
	ld b,b
	ld b,c
	cp 000h
	cp 0f8h
	ld b,d
	ld b,e
	ld b,h
	ld b,l
	ld b,(hl)
	ld b,a
	ld c,b
	ld b,a
	ld c,c
	ld c,d
	ld c,e
l4ce4h:
	ld c,h
	ld c,l
	cp 000h
	ld d,d
	ld d,e
	ld d,h
	ld d,l
	ld d,(hl)
	ld d,a
	ld h,b
	ld d,a
	ld h,b
	ld h,c
	ld e,e
	ld e,h
l4cf4h:
	ld e,l
	nop
	nop
	ld h,l
	ld h,l
	cp 000h
	ld c,(hl)
	ld c,a
	ld d,b
	ld d,c
	ld e,b
	ld e,c
	ld e,d
	ld e,c
	ld l,b
	ld l,c
	ld l,d
l4d06h:
	ld e,(hl)
	ld e,a
	ld h,d
	ld h,e
	ld h,h
	ld h,e
	ld h,h
	ld h,(hl)
	rst 38h
; --- Title / front-end text (drawn by sub_4d4eh).  ASCII-0x10 via vk(); leading
;     numbers are VDP position/attribute prefixes, 0xFE/0xFF are separators.
l4d0fh:
	LUA ALLPASS
	  vk({0x48,0x88,0x2a,0x00,"KONAMI 1986",0xfe})  -- "KONAMI 1986"
	  vk({0x48,0xa0,"PUSH SPACE KEY",0xff})         -- "PUSH SPACE KEY"
	ENDLUA
l4d30h:
	LUA ALLPASS
	  vk({0x48,0xa0,0x00,0x00,"PLAY START",0x00,0x00,0xff})  -- "PLAY START"
	ENDLUA
l4d41h:
	LUA ALLPASS
	  vk({0x58,0x58,"GAME",0x00,0x00,"OVER",0xff})  -- "GAME OVER"
	ENDLUA
sub_4d4eh:
	call sub_47dbh
	call sub_4de2h
	call l4853h
	call sub_572eh
	ld b,003h
	ld de,06606h
l4d5fh:
	ld a,00fh
	call sub_481bh
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
	call sub_481bh
	call sub_47f7h
	call sub_53bdh
	call sub_5a02h
	ld hl,CHRGTR
	ld bc,00068h
	ld a,0ffh
	ld d,000h
	call l4911h
	ld hl,00516h
	call 07ad6h
	ld hl,00569h
	call 07ad6h
	ld a,(0002bh)
	and 00fh
	jr nz,l4dc3h
	ld de,0a818h
	ld hl,l4c3fh
	call 07b39h
	ld de,0a038h
	ld hl,04c5ah
	call 07b39h
	call 07af6h
	jr l4dd5h
l4dc3h:
	ld de,03828h
	ld hl,l4ca0h
	call 07b39h
	ld de,0b830h
	ld hl,l4c3fh
	call 07b39h
l4dd5h:
	ld hl,l4d0fh
	call l4ad2h
	jp l47ceh
	ld d,001h
	jr l4de4h
sub_4de2h:
	ld d,000h
l4de4h:
	ld hl,CHKRAM
	ld bc,CHKRAM
	xor a
	jp l4911h
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
	ld (0c415h),a
	ld a,080h
	ld (0c418h),a
	call 062d7h
	call 062edh
	jp sub_451ah
sub_4e27h:
	call sub_5c2ch
	ld a,(0c41bh)
	and a
	ret z
	call sub_5a35h
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
	call 098f3h
	call 0991fh
	call 064f3h
	jp 065abh
	ld c,027h
	ld de,0e048h
	jp l5f24h
	ld (ix+006h),001h
	ld (ix+00bh),094h
	ld (ix+00eh),a
	ret
	xor a
	ld (ix+008h),a
	ld (ix+007h),a
	ld de,0ffe0h
l4ec4h:
	jp 0a573h
	ld c,028h
	ld de,09038h
	call l5f24h
	ld c,029h
	ld de,03068h
	jp l5f24h
	ld hl,0ffe0h
	ld de,CHKRAM
	bit 0,(ix+000h)
	jr z,l4ee9h
	ld hl,DCOMPR
	ld de,0fff0h
l4ee9h:
	call 0a564h
	ex de,hl
	call 0a573h
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
	jp l5f24h
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
	ld hl,0d100h
	ld a,(0d000h)
	ld b,a
	ld a,(0d001h)
	ld c,a
	jp l4fb6h
	ld hl,0d140h
	ld de,DCOMPR
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
l4fb6h:
	ld (0c5d5h),hl
	ld (0c5d7h),bc
	di
	ld hl,0f0f1h
	ld a,00bh
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
	ld a,(0c41ah)
	ld hl,0614bh
	and a
	jr nz,l4ff7h
	ld a,(0c5d8h)
	ld hl,entity_tbl_end
	call ADD_HL_A
	ld l,(hl)
	ld a,(0c5d7h)
	add a,l
	ld h,000h
	ld l,a
	add hl,hl
	ld de,06013h
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
	ld bc,0a041h
	jr nz,l501ah
	ld a,(0c5d8h)
	add a,a
	ld hl,07ebbh
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
	ld hl,089ceh
	ld (0c010h),hl
	ld (0c012h),hl
	ld (0c014h),hl
	ld (0c016h),hl
l50a5h:
	ret
sub_50a6h:
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
	ld bc,WRSLT
	ldir
	ld hl,l515dh
	ld bc,WRSLT
	ldir
	ld hl,l515dh
	ld bc,WRSLT
	ldir
	and 07fh
	rlca
	ld e,a
	rlca
	add a,e
	ld hl,08dc9h
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
	ld hl,08a64h
	ld (0c010h),hl
	ld hl,08a6bh
	ld (0c012h),hl
	ld hl,08a72h
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
	ld bc,CHKRAM
	nop
	nop
	nop
	nop
	ld bc,CHKRAM
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
	ld bc,WRSLT
	ldir
	rlca
	ld hl,08d8dh
	add a,l
	ld l,a
	jr nc,l519bh
	inc h
l519bh:
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld (0c064h),de
	ld hl,08c9ch
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
	ld hl,08a5dh
	ld (0c01ah),hl
	ld de,0c080h
	ld hl,l515dh
	ld bc,WRSLT
	ldir
	ld hl,09463h
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
	ld hl,08c95h
	ld (0c018h),hl
	ld de,0c06ch
	ld hl,l515dh
	ld bc,WRSLT
	ldir
	ld hl,0948bh
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
	call sub_5369h
	ld hl,0be59h
	ld de,00800h
	ld bc,00d01h
	call l4a2eh
	ld hl,0bec1h
	ld de,07000h
	ld bc,00d02h
	call l4a2eh
	ld hl,0bf29h
	ld de,0d800h
	ld bc,01a03h
	call l4a2eh
; --- sub_533dh - restore the default bank set after a graphics load: seg 1 @
;     0x6000 (page 1b), seg 2 @ 0x8000 (page 2a), seg 3 @ 0xA000 (page 2b).
;     These are the banks the running game code normally expects paged in.
sub_533dh:
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
sub_5357h:
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
; --- sub_5369h - page in the "level/sprite graphics" bank set: seg 11 @ 0x6000
;     (page 1b), seg 12 @ 0x8000 (page 2a), seg 13 @ 0xA000 (page 2b).  Shadow
;     copies kept at 0xF0F1-0xF0F3 so INT_HANDLER can restore them.  Sources
;     like 0xA319 read after this call therefore live in segment 13.
sub_5369h:
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
; --- sub_5381h - page in the front-end/title graphics bank set: seg 9 @ 0x8000
;     (page 2a), seg 10 @ 0xA000 (page 2b).  Page 1b is left untouched.  Sources
;     like 0xA0EA read after this call live in segment 10.
sub_5381h:
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
sub_5393h:
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
sub_53a5h:
	di
	ld hl,0f0f1h
	ld a,004h
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
sub_53bdh:
	call sub_5393h
	ld de,CHKRAM
	ld c,000h
	ld hl,0bed8h
	call sub_4a37h
	ld de,00040h
	ld hl,0bd80h
	ld bc,0300eh
	call l4a2eh
	ld hl,0bf00h
	ld de,0a440h
	ld b,001h
	call l4a6dh
	jp sub_533dh
	call sub_5357h
	ld de,08040h
	ld hl,08824h
	ld bc,00e0eh
	call l4a2eh
	ld de,00848h
	ld hl,08894h
	ld bc,01a0eh
	call l4a2eh
	jp sub_533dh
	ld (hl),001h
	ld de,(0c5adh)
	ld hl,l5428h
	ld b,006h
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
	call sub_4991h
	pop hl
	inc hl
	inc hl
	pop de
	ld a,e
	add a,008h
	ld e,a
	pop bc
	djnz l540eh
	ret
l5428h:
	inc (hl)
	ld d,h
	ld d,h
	ld d,h
	inc (hl)
	ld d,h
	ld d,h
	ld d,h
	ld d,h
	ld d,h
	ld (hl),h
	ld d,h
	nop
	jp 0003ch
	nop
	jp 0003ch
	inc c
	jp 0c03ch
	inc bc
	inc sp
	inc sp
	jr nc,$+5
	inc sp
	inc sp
	jr nc,$+5
	inc sp
	inc sp
	jr nc,l5450h
	inc bc
	jr nc,$+50
l5450h:
	nop
	jp 0003ch
	nop
	jp 0003ch
	nop
	jp 0003ch
	nop
	jp 0003ch
	nop
	jp 0003ch
	nop
	jp 0003ch
	nop
	jp 0003ch
	nop
	jp 0003ch
	nop
	jp 0003ch
	nop
	jp 0003ch
	inc c
	jp 0c03ch
	inc bc
	inc sp
	inc sp
	jr nc,$+5
	inc sp
	inc sp
	jr nc,$+5
	inc sp
	inc sp
	jr nc,l548ch
	inc bc
	jr nc,$+50
l548ch:
	nop
	jp 0003ch
	nop
	nop
	nop
	nop
	call sub_5381h
	ld hl,09000h
	ld de,0a800h
	ld b,014h
	call l4a97h
	ld hl,09a00h
	ld de,0b028h
	ld b,001h
	call l4a97h
	ld hl,09a80h
	ld de,08c70h
	ld bc,00804h
	ld a,001h
	call sub_4991h
	ld de,08074h
	ld b,004h
l54c0h:
	push bc
	push de
	ld hl,09a90h
	ld bc,00808h
	ld a,001h
	call sub_4991h
	pop de
	pop bc
	ld a,d
	add a,008h
	ld d,a
	djnz l54c0h
	call sub_53a5h
	ld hl,0b9c8h
	ld de,0b030h
	ld b,008h
	call l4a97h
	ld hl,0bdc8h
	ld de,0b800h
	ld b,005h
	call l4a97h
	call sub_5381h
	call sub_54f7h
	jp sub_533dh
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
	call sub_4a58h
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
	inc bc
	ex af,af'
	ld (bc),a
	ld c,00fh
	call sub_5381h
	ld a,(0c416h)
	cp 005h
	jr z,l55dbh
	dec a
	jr z,l55dbh
	dec a
	add a,a
	ld hl,l55deh
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld hl,0f8c0h
	call sub_46f8h
	ld a,(0c416h)
	cp 004h
	jr z,l55cfh
	cp 003h
	jr z,l55cfh
	cp 002h
	jr nz,l55dbh
	ld hl,l55eeh
	call sub_4745h
	jr l55dbh
l55cfh:
	ld hl,l55e4h
	call sub_4745h
	ld hl,l55e9h
	call sub_4745h
l55dbh:
	jp sub_533dh
l55deh:
	ld c,(hl)
	and d
	ret
	and h
	ld (hl),d
	and d
l55e4h:
	ret nz
	ret m
	ld (bc),a
	add a,b
	ld sp,hl
l55e9h:
	nop
	ld sp,hl
	ld (bc),a
	ld b,b
	ld sp,hl
l55eeh:
	ret nz
	ret m
	ld (bc),a
	nop
	ld sp,hl
	call sub_5381h
	ld de,0a0eah
	ld hl,0f900h
	call sub_46f8h
	call sub_533dh
	ld hl,0d600h
	ld bc,00808h
l5608h:
	ld de,0c5adh
	ld a,b
	cp 005h
	ld a,(de)
	jr nc,l5613h
	add a,010h
l5613h:
	dec a
	ld (hl),a
	inc hl
	inc de
	ld a,(de)
	ld (hl),a
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
	call sub_53a5h
	ld a,(0d000h)
	cp 00dh
	call nc,sub_5393h
	ld a,(0d000h)
	add a,a
	ld hl,l5749h
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
l566ch:
	ld de,08004h
	ld b,0bfh
	call l4a6dh
	jp sub_533dh
	call sub_5381h
	ld hl,08000h
	jr l566ch
	call sub_5369h
	ld hl,0f800h
	ld de,0a319h
	call sub_46f8h
	ld hl,0f840h
	ld de,0a351h
	call sub_46f8h
	ld hl,0f880h
	ld de,0a38ch
	call sub_46f8h
	ld hl,0f8c0h
	ld de,0a3cah
	call sub_46f8h
	ld hl,0f900h
	ld de,0a40bh
	call sub_46f8h
	ld hl,0f940h
	ld de,0a447h
	call sub_46f8h
	ld hl,0f980h
	ld de,0a480h
	call sub_46f8h
	ld hl,0f9c0h
	ld de,0a4bch
	call sub_46f8h
	ld de,0b895h
	ld hl,0fa00h
	call sub_46f8h
	jp sub_533dh
	call sub_5369h
	ld de,0f880h
	ld hl,0ac93h
	ld bc,00180h
	call sub_467ch
	jp sub_533dh
sub_56e8h:
	call sub_5369h
	ld a,(0c42eh)
	add a,a
	ld hl,0a281h
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld hl,0f800h
	call sub_46f8h
	ld a,(0c42fh)
	add a,a
	ld hl,0a2d1h
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld hl,0f840h
	call sub_46f8h
	jp sub_533dh
	call sub_572eh
	call sub_5381h
	ld hl,0bea7h
	ld a,(0d000h)
	add a,a
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	call l4845h
	jp sub_533dh
sub_572eh:
	call sub_5381h
	ld hl,0bf88h
	call l4845h
	jp sub_533dh
	call sub_572eh
	call sub_5381h
	ld hl,0bfa1h
	call l4845h
	jp sub_533dh
l5749h:
	nop
	ld h,b
	jr nz,$+116
	jr nz,l57c1h
	jr nz,$+116
	or e
	sub l
	or e
	sub l
	or e
	sub l
	sub e
	add a,h
	sub e
	add a,h
	sub e
	add a,h
	ld (hl),e
	sbc a,(hl)
	ld (hl),e
	sbc a,(hl)
	ld (hl),e
	sbc a,(hl)
	nop
	add a,b
	nop
	add a,b
	nop
	add a,b
	ld b,b
	sub (hl)
	ld b,b
	sub (hl)
	ret nz
	and h
	call sub_5381h
	ld hl,0ff00h
	ld de,0a185h
	call sub_46f8h
	ld de,0a147h
	ld hl,0f9c0h
	call sub_46f8h
	jp sub_533dh
	call l4805h
	call sub_5381h
	ld hl,09ab0h
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
	call l471bh
	pop hl
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	call l4845h
l57b8h:
	jp sub_533dh
	call sub_5381h
	ld hl,09fedh
l57c1h:
	call l471bh
	jp sub_533dh
	call sub_5381h
	ld hl,0fa00h
	ld de,0b0aah
	call sub_46f8h
	ld a,(0d000h)
	sub 003h
	ld hl,0a01ah
	jr z,l57e0h
	ld hl,0a021h
l57e0h:
	call l4845h
	jp sub_533dh
	call sub_5369h
	ld hl,0b5a1h
	call sub_5834h
	ld de,0c000h
	call sub_5816h
	call sub_5858h
	ld de,0c020h
	call sub_5816h
	ld hl,0b719h
	call sub_5834h
	ld de,0c010h
	call sub_5816h
	call sub_5858h
	ld de,0c030h
	call sub_5816h
	jp sub_533dh
sub_5816h:
	ld b,020h
	ld hl,0e800h
l581bh:
	push bc
	push de
	push hl
	ld bc,CHRGTR
	call sub_467ch
	pop hl
	pop de
	pop bc
	ld a,010h
	call ADD_HL_A
	ld a,080h
	call ADD_DE_A
	djnz l581bh
	ret
sub_5834h:
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
sub_5858h:
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
	call sub_5357h
	call sub_589ch
	call sub_58d3h
	call sub_5931h
	call sub_5992h
	call sub_599dh
	jp sub_533dh
sub_589ch:
	ld hl,0abf8h
	ld b,008h
	ld de,08018h
	call l4a6dh
	ld hl,0acf8h
	ld b,002h
	ld de,08040h
	call l4a6dh
	ld hl,0ad38h
	ld b,002h
	ld de,08060h
	call l4a6dh
	ld hl,0ad78h
	ld b,001h
	ld de,08070h
	call l4a6dh
	ld hl,0ad98h
	ld b,06ch
	ld de,08078h
	jp l4a6dh
sub_58d3h:
	ld hl,0ad78h
	ld b,001h
	ld de,08074h
	call sub_58f1h
	ld hl,0ad98h
	ld b,06ch
	ld de,09028h
	call sub_58f1h
	ld hl,0acf8h
	ld b,002h
	ld de,08048h
sub_58f1h:
	push bc
	push de
	push hl
	call sub_5904h
	pop hl
	ld de,DCOMPR
	add hl,de
	pop de
	call sub_5962h
	pop bc
	djnz sub_58f1h
	ret
sub_5904h:
	push de
	ld de,0e800h
	ld bc,DCOMPR
	ldir
	call sub_5919h
	pop de
	ld hl,0e800h
	ld b,001h
	jp l4a6dh
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
	jp l4a6dh
sub_5992h:
	ld hl,0bbd8h
	ld de,0d000h
	ld b,008h
	jp l4a97h
sub_599dh:
	ld b,004h
	ld hl,0bdd8h
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
	call sub_572eh
	call sub_5381h
	ld hl,0bf6fh
	call l4845h
	jp sub_533dh
sub_5a02h:
	call sub_5393h
	ld hl,0ac80h
	ld de,08004h
	ld b,011h
	call l4a6dh
	ld a,(0002bh)
	and 00fh
	jr nz,l5a2ah
	ld hl,0aea0h
	ld b,01eh
	call l4a6dh
	call sub_5369h
	ld de,0bbf6h
	call l46f2h
	jr l5a32h
l5a2ah:
	ld hl,0b260h
	ld b,059h
	call l4a6dh
l5a32h:
	jp sub_533dh
sub_5a35h:
	call sub_5369h
	call 0b963h
	jp sub_533dh
	call sub_5369h
	call 0b99ah
	jp sub_533dh
	call sub_5369h
	call 0bb31h
	jp sub_533dh
	ld hl,0e000h
	ld de,0e001h
	ld (hl),000h
	ld bc,0047fh
	ldir
	call sub_5a63h
	jp l5ab6h
sub_5a63h:
	call sub_5357h
	call sub_5a9fh
	ld de,0e000h
l5a6ch:
	push de
l5a6dh:
	push de
l5a6eh:
	ld a,(hl)
	or a
	jr z,l5a9ah
	inc a
	jr z,l5a8eh
	inc a
	jr z,l5a85h
	ldi
	ld a,(hl)
	ldi
	cp 07fh
	jr nz,l5a83h
	ldi
l5a83h:
	jr l5a6eh
l5a85h:
	pop de
	ld a,018h
	call ADD_DE_A
	inc hl
	jr l5a6dh
l5a8eh:
	pop de
	pop de
	push hl
	ld hl,00180h
	add hl,de
	ex de,hl
	pop hl
	inc hl
	jr l5a6ch
l5a9ah:
	pop de
	pop de
	jp sub_533dh
sub_5a9fh:
	ld a,(0d000h)
	or a
	ld hl,0800ch
	ret z
	ld a,(0d002h)
	ld hl,08000h
	add a,a
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	ret
l5ab6h:
	ld hl,0de00h
	ld de,0de01h
	ld (hl),000h
	ld bc,000bfh
	push hl
	ldir
	pop de
	ld hl,0e000h
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
	ld hl,l5b12h
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
l5b12h:
	ld c,012h
	inc bc
	inc b
	ld a,(bc)
	ld d,01eh
	dec e
	dec de
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	call sub_5bd6h
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
	ld (de),a
	inc de
	push hl
	push bc
	call sub_5c1dh
	ld a,c
	ld (de),a
	inc de
	ld a,b
	ld (de),a
	inc de
	pop bc
	xor a
	ld (de),a
	inc de
	ld a,(hl)
	ld b,a
	rlca
	rlca
	rlca
	and 007h
	dec a
	jr nz,l5b61h
	ld a,(0d000h)
	or a
	jr z,l5b61h
	ld a,0ffh
l5b61h:
	inc a
	ld (de),a
	inc e
	ld a,b
	and 01fh
	ld (de),a
	inc e
	ex af,af'
	ld a,l
	ld (de),a
	inc e
	pop bc
	ld a,b
	ld (de),a
	inc e
	ld a,c
	ld (de),a
	inc e
	ex af,af'
	cp 01fh
	jr nz,l5b7ch
	inc hl
	ldi
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
	call sub_5c1dh
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
sub_5bd6h:
	ld a,(0d001h)
	ld (0cffeh),a
	push bc
	push de
	ld de,CHKRAM
	ld a,(0d000h)
	or a
	jr z,l5bf5h
	dec a
	ld hl,l5c0bh
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
l5c0bh:
	nop
	jr $+50
	nop
	jr l5c41h
	nop
	jr l5c44h
	nop
	jr $+50
	nop
	jr $+50
	nop
	jr $+50
sub_5c1dh:
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
sub_5c2ch:
	call 06848h
	call 06552h
	ld a,(0ce40h)
	and a
	jp nz,066c1h
	call 09559h
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
	call z,0ad9ah
	ld a,001h
	ld (0c40ah),a
	call sub_56e8h
	ld a,0fdh
	jp sub_50a6h
l5c63h:
	call sub_56e8h
	call 06b06h
	call 0783eh
	call 0b6b2h
	call 098ech
	call 09e38h
	call 07d6fh
	call 08678h
	call 091c5h
	call 08a51h
	call 088dfh
	call 08fd6h
	call 090a2h
	call 0914eh
	call 0991fh
	call 09917h
	call 064f3h
	jp 064ech
sub_5c99h:
	ld bc,00400h
	ld hl,0fcc1h
l5c9fh:
	push bc
	push hl
	ld a,(hl)
	bit 7,a
	jr nz,l5cbah
	call sub_5cd3h
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
	ld a,0ffh
l5cb6h:
	ld (0e600h),a
	ret
l5cbah:
	call sub_5cbfh
	jr l5ca9h
sub_5cbfh:
	and 080h
	or c
	ld c,a
	ld b,004h
l5cc5h:
	push bc
	call sub_5cd3h
	pop bc
	ret c
	ld a,c
	add a,004h
	ld c,a
	djnz l5cc5h
	and a
	ret
sub_5cd3h:
	ld de,l5cf0h
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
l5cf0h:
	nop
	jr nc,l5d24h
	inc de
	dec (hl)
	xor d
sub_5cf6h:
	call sub_5d04h
	ld c,00eh
	call sub_48e3h
	ld hl,l5d1dh
	jp l4ad2h
sub_5d04h:
	ld hl,02098h
	ld bc,0c038h
sub_5d0ah:
	xor a
	ld d,000h
	push bc
	push hl
	call l4911h
	pop hl
	pop de
	ret
sub_5d15h:
	call sub_5d0ah
	ld c,00eh
	jp sub_48e3h
l5d1dh:
	ld e,b
	and b
	jr nc,$+50
	jr nc,l5d60h
	dec (hl)
l5d24h:
	ld a,045h
	jr nc,$+50
l5d28h:
	jr nc,l5d28h
	jr z,l5cdch
	ld c,a
	cp 030h
	or b
	ld b,e
	ld b,h
	ld sp,l4442h
	nop
	scf
	ld sp,0353dh
	cp 030h
	cp b
	dec a
	ccf
	inc (hl)
	add hl,sp
	ld (hl),049h
	nop
	ld b,e
	ld b,h
	ld sp,03537h
	nop
	ld a,045h
	dec a
	ld (04235h),a
	cp 030h
	ret nz
	dec a
	ccf
	inc (hl)
	add hl,sp
	ld (hl),049h
	nop
	ld b,b
	inc a
	ld sp,03549h
	ld b,d
l5d60h:
	nop
	ld a,045h
	dec a
	ld (04235h),a
	rst 38h
sub_5d68h:
	ld hl,l5d79h
	call sub_5d97h
	ld hl,0e605h
	ld de,0b0b8h
l5d74h:
	ld b,001h
	jp l457fh
l5d79h:
	ld c,b
	cp b
	ld b,e
	ld b,h
	ld sp,03537h
	nop
	ld a,045h
	dec a
	ld (04235h),a
	cpl
	rst 38h
sub_5d89h:
	ld hl,l5d9fh
	call sub_5d97h
	ld hl,0e607h
	ld de,0b8b8h
	jr l5d74h
sub_5d97h:
	push hl
	call sub_5db0h
	pop hl
	jp l4ad2h
l5d9fh:
	ld c,b
	cp b
	ld b,b
	inc a
	ld sp,03549h
	ld b,d
	nop
	ld a,045h
	dec a
	ld (04235h),a
	cpl
	rst 38h
sub_5db0h:
	ld hl,024b0h
	ld bc,0b818h
	jp sub_5d0ah
l5db9h:
	call sub_5deeh
	ret z
	ld hl,(0e608h)
	ld d,000h
	ld b,008h
	ld a,l
	call sub_5de8h
	jr c,l5dd1h
	ld a,h
	ld b,002h
	call sub_5de8h
	ret nc
l5dd1h:
	ld hl,0e615h
	ld (hl),0ffh
	ld hl,0e60fh
	ld a,d
	rld
	ld de,(0e602h)
	ld b,001h
	call l457fh
	jp l5e0fh
sub_5de8h:
	rra
	ret c
	inc d
	djnz sub_5de8h
	ret
sub_5deeh:
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
l5e0fh:
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
sub_5e28h:
	ld a,007h
	call SNSMAT
	cpl
	and 080h
	ld hl,0e60ah
	ld c,(hl)
	ld (hl),a
	xor c
	and (hl)
	ret
sub_5e38h:
	rra
	push af
	jr nc,l5e67h
	ld a,(0e606h)
	cp 013h
	jr c,l5e44h
	xor a
l5e44h:
	ld (0d000h),a
	ld a,(0e605h)
	cp 019h
	jr c,l5e4fh
	xor a
l5e4fh:
	ld (0c411h),a
	ld hl,l5e71h
	ld a,(0d000h)
	call ADD_HL_A
	ld a,(hl)
	ld (0d002h),a
	xor a
	ld (0d001h),a
	inc a
	ld (0c40dh),a
l5e67h:
	pop af
	rra
	ret nc
	ld a,(0e607h)
	ld (0c410h),a
	ret
l5e71h:
	nop
	nop
	nop
	nop
	ld bc,00101h
	ld (bc),a
	ld (bc),a
	ld (bc),a
	inc bc
	inc bc
	inc bc
	inc b
	inc b
	inc b
	dec b
	dec b
	dec b
l5e84h:
	rra
	ld a,001h
	jr nc,l5e8bh
	ld a,0ffh
l5e8bh:
	ld b,a
	ld hl,0e60bh
	add a,(hl)
	and 003h
	cp 003h
	jr nz,l5e9dh
	ld a,b
	add a,a
	ld a,002h
	jr c,l5e9dh
	xor a
l5e9dh:
	push af
	push hl
	ld a,(hl)
	call sub_5ea9h
	pop hl
	pop af
	ld (hl),a
	jp l5eadh
sub_5ea9h:
	ld b,000h
	jr l5eafh
l5eadh:
	ld b,04fh
l5eafh:
	ld hl,l5ebch
	call ADD_HL_A
	ld e,(hl)
	ld d,028h
	ld a,b
	jp sub_4aeeh
l5ebch:
	or b
	cp b
	ret nz
	ld a,(0c440h)
	and a
	ret nz
	ld a,(0c420h)
	cp 006h
	ret z
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
	ld a,(0d000h)
	ld de,085a6h
	call 06549h
	ld a,(0d001h)
	call ADD_DE_A
	ld a,(de)
	push af
	di
	ld a,002h
	ld (08000h),a
	ld (0f0f2h),a
	ei
	pop af
	rra
	push af
	call c,09cedh
	pop af
	rra
	push af
	call c,09d52h
	pop af
	rra
	push af
	call c,09d59h
	pop af
	rra
	push af
	call c,09d9eh
	pop af
	rra
	push af
	call c,09dcah
	pop af
	rra
	push af
	call c,09ddch
	pop af
	rra
	jp c,09deeh
	ret
l5f24h:
	xor a
	ld b,a
	ld (0cffah),a
	ld a,b
	ld (0cffbh),a
	xor a
	ld (0cf31h),a
	ld a,c
	ld (0cff0h),a
	ld (0cff1h),de
	ld hl,0c800h
	ld b,007h
	xor a
	ld de,00080h
l5f42h:
	cp (hl)
	jr z,l5f49h
	add hl,de
	djnz l5f42h
	ret
l5f49h:
	push hl
	pop ix
	ld (0cff3h),hl
	ld a,(0cff0h)
	ld hl,0605eh
	call ADD_HL_A
	ld a,(hl)
	ld (ix+020h),a
	ld c,a
	and a
	jr z,l5f7eh
	ld de,CHKRAM
	ld hl,0d638h
	ld b,00eh
l5f68h:
	ld a,(hl)
	cp 0e0h
	jr nz,l5f76h
	ld (hl),0e1h
	call 0604fh
	inc e
	dec c
	jr z,l5f7eh
l5f76h:
	inc d
	inc l
	inc l
	inc l
	inc l
	djnz l5f68h
	ret
l5f7eh:
	ld a,001h
	ld (0cf31h),a
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
	ld (hl),000h
	ld a,(0cffah)
	ld (ix+00fh),a
	ld a,(0cffbh)
	ld (ix+01fh),a
	ld (ix+07eh),001h
	ld (ix+07fh),001h
	ld (ix+00eh),007h
	ld de,0608bh
	call 06030h
	ld a,(0cff0h)
	ld de,060e8h
	call ADD_DE_A
	ld a,(de)
	ld (ix+00dh),a
	ld hl,(0cff3h)
	ld a,(ix+000h)          ; A = entity type (ix+0)...
	dec a                   ; ...-1 -> 0-based index
	call DISPATCH_A         ; jump to entity_tbl[type-1]

; entity_tbl - per-object behaviour handlers, indexed by entity type-1.
; Targets are all in 0xA000-0xBFFF, i.e. code in whichever segment is currently
; paged into page 2b - so these are addresses in banked ROM, not local labels.
; (22 entries; the trailing 0x5FFF byte is padding to the segment boundary.)
entity_tbl:
	defw 0a93bh             ; entity type 1
	defw 0a2e7h
	defw 0a2e7h
	defw 0b0d1h
	defw 0a863h
	defw 0a57ah
	defw 0b068h
	defw 0a502h
	defw 0af51h
	defw 0a229h
	defw 0b34bh
	defw 0a677h
	defw 0b219h
	defw 0aad4h
	defw 0b19ah
	defw 0ade5h
	defw 0ab29h
	defw 0be57h
	defw 0bd2dh
	defw 0b883h
	defw 0ba56h
	defw 0bc5bh
	defb 047h
entity_tbl_end:

; ===========================================================================
;  SEGMENT 1 - banked code, paged at 0x6000-0x7FFF (page 1b) during play.
;  Reached from segment 0's state machine (see the call sites in seg00.asm);
;  holds main gameplay-loop routines.  BIOS names come from segments/bios.inc
;  and the seg0 helper labels (ADD_HL_A, DISPATCH_A, ...) resolve from seg00.asm.
;  Disassembly in progress: code/data split is described in tools/seg01.blocks.
;  (Regenerate raw disasm with  tools/regen-seg.sh 1 0x6000 tools/seg01.blocks .)
; ===========================================================================
; ---- MSX main-ROM BIOS jump table ----------------------------------------


; BLOCK 'data_6000' (start 0x6000 end 0x6030)
data_6000_start:
	defb 06ah
	defb 0e4h
	defb 0bah
	defb 0d9h
	defb 0b4h
	defb 0d9h
	defb 0b4h
	defb 0d9h
	defb 0b4h
	defb 0d9h
	defb 0b4h
	defb 02fh
	defb 060h
	defb 067h
	defb 09bh
	defb 0d5h
	defb 0b0h
	defb 06dh
	defb 09ch
	defb 0ceh
	defb 0a2h
	defb 07eh
	defb 0b7h
	defb 019h
	defb 0b2h
	defb 0a2h
	defb 09bh
	defb 02fh
	defb 060h
	defb 0cbh
	defb 09bh
	defb 0aeh
	defb 04eh
	defb 0d7h
	defb 04eh
	defb 0d7h
	defb 04eh
	defb 026h
	defb 04fh
	defb 02fh
	defb 060h
	defb 064h
	defb 06ah
	defb 0efh
	defb 0ach
	defb 0c3h
	defb 069h
	defb 0c9h
data_6000_end:
	ld a,(ix+020h)
	and a
	ret z
	ld a,(ix+000h)
	call LOOKUP_WORD_TBL
	ld hl,(0cff3h)
	set 5,l
	ld b,(hl)
	ld a,005h
	add a,l
	ld l,a
l6045h:
	ld a,(de)
	inc de
	ld (hl),a
	ld a,l
	add a,005h
	ld l,a
	djnz l6045h
	ret
	push hl
	ld hl,(0cff3h)
	ld a,e
	add a,a
	add a,a
	add a,e
	add a,021h
	call ADD_HL_A
	ld (hl),d
	pop hl
	ret

; BLOCK 'data_605f' (start 0x605f end 0x608d)
data_605f_start:
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
data_605f_end:

; BLOCK 'ptr_tbl_608d' (start 0x608d end 0x60e9)
ptr_tbl_608d_start:
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
ptr_tbl_608d_end:

; BLOCK 'data_60e9' (start 0x60e9 end 0x615b)
data_60e9_start:
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
data_60e9_end:

; --- sub_615bh - load three tables from seg14 into RAM ----------------------
;  Pages seg 14 into page 2a (writes 0x0E to 0x8000 and to its shadow 0xF0F2),
;  copies three streams into the RAM buffers at 0xDB00 / 0xDC00 / 0xDD00 via
;  sub_6188h, then restores seg 2 (0x02) before returning.  Interrupts are held
;  off (di/ei) around the bank switch.
; --- sub_615bh - load the current screen's object list from seg14 ------------
;  Builds the 0xDB00 object/display list for the current cell, unpacking it from
;  data that lives in ROM segment 14.  Interrupts are held off around each bank
;  switch (the interrupt handler runs banked code).
sub_615bh:
	di
	ld a,00eh              ; page ROM segment 14 ...
	ld (08000h),a          ; ... into page 2a (0x8000)
	ld (0f0f2h),a          ; keep the seg-2a shadow byte in step
	ei
	call sub_61b0h         ; clear the 0xDB00 list to empty slots
	call sub_61a5h         ; HL -> this level's packed object data (in seg14)
	ld de,0db00h           ; unpack stream 0 -> object list at 0xDB00
	call sub_6188h
	ld de,0dc00h           ; unpack stream 1 -> 0xDC00
	call sub_6188h
	ld de,0dd00h           ; unpack stream 2 -> 0xDD00
	call sub_6188h
	di
	ld a,002h              ; restore ROM segment 2 ...
	ld (08000h),a          ; ... into page 2a
	ld (0f0f2h),a
	ei
	ret

; --- sub_6188h - unpack one object stream into a 4-byte-per-entry table -------
;  Source HL, destination DE.  Each source pair (id,attr) expands to a 4-byte
;  slot [id, attr, _, _].  0x00 = end of row (jump DE to the next 0x10 boundary),
;  0xFF = end of stream.
sub_6188h:
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
	jr sub_6188h
; --- sub_61a5h - find this level's packed object data in seg14 ---------------
sub_61a5h:
	ld a,(0d002h)          ; A = current cell/level index
	ld de,08668h           ; DE = word-pointer table (in seg14)
	call LOOKUP_WORD_TBL         ; DE = table[A]
	ex de,hl               ; HL = pointer to the packed object data
	ret
; --- sub_61b0h - clear the 0xDB00 object list --------------------------------
;  0xC0 slots of 4 bytes.  slot+0 = 0 (empty), slot+3 = running index 1..0xC0.
sub_61b0h:
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
; --- l61c2h - emit hardware sprites for the visible objects ------------------
;  Walks 4 slots of the 0xDB00 list at the current scroll position and, for each
;  live slot, unpacks its byte-packed X/Y and calls the seg0 sprite composer.
l61c2h:
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
l61e2h:
	push bc
	push hl
	ld a,(hl)              ; slot+0 = id (0 = empty)
	and a
	jr z,l6200h
	ld b,000h
	and 07fh               ; low 7 bits = sprite id
	ld c,a
	inc hl
	ld a,(hl)              ; slot+1 = packed position
	and 0f0h               ; high nibble -> E (x)
	ld e,a
	ld a,(hl)
	and 00fh               ; low nibble ...
	add a,a
	add a,a
	add a,a
	add a,a                ; ... << 4 -> D (y)
	ld d,a
	inc hl
	inc hl
	ld a,(hl)              ; slot+3 = attribute/index
	call 05f26h            ; seg0: compose the hardware sprite (BC id, DE pos)
l6200h:
	pop hl
	pop bc
	inc hl                 ; advance to the next slot (stride 4)
	inc hl
	inc hl
	inc hl
	djnz l61e2h
	ret

; --- KONAMI_LOGO_DRAW (0x6209) - set up the Konami logo screen ---------------
;  Boot front-end step, run from seg0's state machine.  Draws the Konami logo
;  (orange/red/grey) as a tile layout (l6243h + l6296h via sub_6276h) and sets
;  the VDP backdrop to white (R7 = 0x0F).  Then seeds the 3-byte block that the
;  per-frame stepper KONAMI_LOGO_STEP (0x6253) uses to wipe the logo in:
;     0xC420 = 0x3C frame divider (advance the wipe every other frame)
;     0xC421 = 0x31 remaining rows of the top-to-bottom reveal (49 -> 0)
;     0xC422 = done flag (0 = revealing, 1 = finished; seg0 polls this)
KONAMI_LOGO_DRAW:
	call 047dbh             ; seg0 helper (screen prep - purpose not yet mapped)
	call 0572eh             ; seg0 helper (purpose not yet mapped)
	ld hl,l6243h            ; HL -> parameter table l6243h
	call 04845h             ; seg0 routine consuming the table at HL
	ld b,00fh               ; value 0x0F ...
	ld c,007h               ; ... into VDP register 7 (backdrop colour = white)
	call WRTVDP
	ld hl,02840h            ; VDP dest / fill origin
	ld bc,0a848h            ; region size
	xor a                   ; fill/colour value 0
	ld d,001h
	call 04911h             ; seg0 VDP fill (clears the logo area to white)
	call 05316h             ; seg0 helper (purpose not yet mapped)
	ld de,04040h            ; screen position for the logo tiles
	ld hl,l6296h            ; HL -> logo tile-layout stream
	call sub_6276h          ; paint the logo via the tile-string interpreter
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

; --- KONAMI_LOGO_STEP (0x6253) - wipe the logo in by one row ----------------
;  Seg0 calls this each frame while the logo state waits, then reads 0xC422
;  (0 = still revealing, 1 = finished).  0xC420 halves the rate (acts every 2nd
;  frame); each active frame decrements the 0xC421 row counter and reveals the
;  next horizontal band top-to-bottom (VDP fill of the 0x31-0xC421 rows exposed
;  so far, height 0xA8 at 0x2840).  When 0xC421 hits 0 it sets 0xC422 = 1.
KONAMI_LOGO_STEP:
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
	jp 0494dh              ; seg0 VDP block copy -> tail-call (returns to caller)

; --- sub_6276h - tile-string interpreter ------------------------------------
;  Walks a byte stream at HL, placing tiles at screen position DE:
;     0xFF = end of stream
;     0xFE = move to next row (D += following byte, E += 8)
;     else = draw the tile in the byte via 0x4B36 / 0x4B56
;  Used by KONAMI_LOGO_DRAW to paint the logo layout (tile data at l6296h).
sub_6276h:
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
	jr sub_6276h           ; re-save the new row start and continue
l628bh:
	ld a,c                 ; A = tile id
	call 04b36h            ; seg0: place tile A at DE
	call 04b56h            ; seg0: advance DE to the next cell
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
	call sub_70e3h
	call 05494h
	call 0576fh
l62eah:
	jp 053bdh              ; -> seg0 (continue the state)

; --- 0x62ED - build a gameplay screen ---------------------------------------
;  Full screen/level construction, called from seg0 when entering a cell:
;  clears per-screen state, paints tiles (seg2 helpers), sets the cell event,
;  loads the packed object list and emits its sprites.  Many steps are helpers
;  in seg1/seg2 not yet mapped; the annotated ones below are the known pieces.
	call 05653h
	call 05714h
	call sub_63beh         ; clear 0xC420..0xC46F per-screen state
	call sub_6409h
	call 05a50h
	call sub_63cch         ; hide all hardware sprites
	call sub_6389h         ; reset the object/actor state area
	call 05787h
	call 056e8h
	call 04f8ah
	call 047dbh
	call sub_633ah         ; set the current cell's event type (0xCE00)
	call 04f98h
	call 091c5h            ; seg2 helpers (tile/screen drawing)
	call 08678h
	call 0914eh
	call 08eedh
	ld a,(0ce00h)          ; event code for this cell
	cp 006h
	call z,sub_6334h       ; event 6 -> extra setup (sub_691bh + l69a7h)
	call 047ceh
	call 09cb0h
	call sub_615bh         ; load the packed object list into 0xDB00/DC00/DD00
	jp l61c2h              ; emit the visible objects as hardware sprites
sub_6334h:
	call sub_691bh
	jp l69a7h
; --- sub_633ah - set the current cell's "event" type ------------------------
;  Clears the event state (0xCE00 + flags 0xCE40/0CE0B/0CE08/0CE15), then looks
;  up the current map cell in l6376h[row=0xD000]: the byte's high nibble is the
;  column it applies to and the low nibble is the event code.  If the high nibble
;  matches the current column (0xD001) the event code is stored in 0xCE00; code 6
;  additionally kicks off its handler (seg1 0x59F3/0x5887, tail-call 0x57E6).
;  Non-event cells hold 0xFF (high nibble 0xF never matches a real column).
sub_633ah:
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
	call 059f3h
	call 05887h
	jp 057e6h
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
; --- sub_6389h - reset the big object/actor state area and its sub-systems ---
;  Clears 0xC470..0xC6FF (0x290 bytes) to 0, then calls the per-subsystem reset
;  helpers (seg1 0x5B22/0x5A47/0x5A3E, seg2 0x9034/0x90A2, sub_751ah), and finally
;  zeroes two strided tables: 7 entries 0x80 apart from 0xC800, and 8 entries
;  0x80 apart from 0xD700.
sub_6389h:
	ld hl,0c470h
	ld de,0c471h           ; dst = src+1
	ld (hl),000h
	ld bc,0028fh           ; clear 0xC470..0xC6FF (0x290 bytes)
	ldir
	call 05b22h
	call 05a47h
	call 09034h
	call 090a2h
	call 05a3eh
	call sub_751ah
	ld hl,0c800h           ; zero 7 entries, 0x80 apart, from 0xC800
	ld de,00080h
	ld b,007h
	call sub_63b8h
	ld hl,0d700h           ; zero 8 entries, 0x80 apart, from 0xD700
	ld b,008h
; --- sub_63b8h - zero B entries starting at HL, stride DE -------------------
sub_63b8h:
	ld (hl),000h
	add hl,de              ; next entry (DE apart)
	djnz sub_63b8h
	ret
; --- sub_63beh - clear the 0xC420..0xC46F state block (0x50 bytes) -----------
;  Includes the Konami-logo wipe counters (0xC420-0xC422) among other per-screen
;  state, reset before a new screen is built.
sub_63beh:
	ld hl,0c420h
	ld d,h
	ld e,l
	inc de                 ; DE = 0xC421 (dst = src+1, classic ldir clear)
	ld (hl),000h           ; 0xC420 = 0
	ld bc,0004fh           ; propagate 0 across 0x4F more bytes
	ldir
l63cbh:
	ret
; --- sub_63cch - hide all hardware sprites ----------------------------------
;  The sprite attribute table shadow lives at 0xD600 (4 bytes/sprite: Y,X,pat,
;  colour).  Writing Y=0xE0 to all 0x20 sprites parks them off the bottom of the
;  screen (0xE0 is the "hide the rest" sentinel Y in MSX sprite mode).
sub_63cch:
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
; --- 0x63DA - (seg0 entry) place Simon at the room centre and redraw ---------
;  Seeds Simon's position (0xC425=Y, 0xC427=X) to 0x80,0x80 - the room-entry
;  spawn - hides all sprites, then runs the seg0/seg1 draw chain (tail-jump to
;  seg0 0x47CE).  (Runtime-confirmed: 0xC425 traces the jump Y-arc and 0xC427
;  the walk X-ramp; there is no camera - the game is room-based, not scrolling.)
	call 047c0h
	ld a,080h
	ld (0c425h),a          ; Simon Y = 0x80
	ld (0c427h),a          ; Simon X = 0x80
	call 05677h
	call 0573ah
	call 0567fh
	call sub_63cch         ; hide all hardware sprites
l63f1h:
	call 04ea6h
l63f4h:
	call 04ec7h
	call 04f1eh
	call 047dbh
	call 0451ah
	call 04f8ah
	call 04f98h
	jp 047ceh              ; -> seg0
; --- sub_6409h - set Simon's spawn position + facing from the per-row table -
;  Looks up l6426h[row=0xD000] (2 bytes): byte0 with bit0 masked off -> Simon Y
;  (0xC425) and bit0 -> facing flag 0xC42C (0=right, 1=left); byte1 -> Simon X
;  (0xC427).  So each room row carries Simon's entry Y, X and facing.
sub_6409h:
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
; --- 0x644C - build an actor's hardware sprites from its seg6 shape table ----
;  Input: IX -> actor struct.  Skips object types 0x0E and 0x17.  Pages seg 6
;  into page 2b (0xA000), looks up the actor's shape stream by (ix+0x0B) in the
;  word table at 0xB473, then writes sprite-attribute entries into the actor's
;  0x20-offset block, adding the actor position (ix+3 = X, ix+5 = Y).  A leading
;  stream code 0x80/0x81/0x82 selects a fixed (dx,dy) offset list for multi-part
;  sprites; otherwise the stream carries explicit offsets.  Restores seg 3.
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
	ld de,0b473h           ; word table of shape streams (in seg6)
	call LOOKUP_WORD_TBL   ; DE -> this actor's shape stream
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
	add a,(ix+003h)
	ld (hl),a
	inc l
	ld a,(de)
	add a,(ix+005h)
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
l64dch:
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

; --- 0x64EC / 0x64F3 - render every active actor in a list ------------------
;  Two entry points over the two actor arrays (stride 0x80 per actor):
;    0x64EC: 8 actors at 0xD700    0x64F3: 7 actors at 0xC800
;  Each non-empty slot (byte 0 != 0) is turned into sprites by sub_6508h.
	ld hl,0d700h           ; 0x64EC: 8 actors from 0xD700
	ld b,008h
	jr l64f8h
	ld hl,0c800h           ; 0x64F3: 7 actors from 0xC800
	ld b,007h
l64f8h:
	push bc
	push hl
	ld a,(hl)              ; slot occupied?
	and a
	call nz,sub_6508h      ; yes -> emit its sprites
	pop hl
	pop bc
	ld de,00080h
	add hl,de              ; next actor (0x80 apart)
	djnz l64f8h
	ret
; --- sub_6508h - emit one actor's sprite-attribute entries ------------------
;  HL -> actor slot.  Reads the sprite count from the 0x20-offset sub-block,
;  then for each sprite copies Y/X/pattern into the VDP sprite-attribute shadow
;  at 0xD638 + id*4 and fills the 0x10-byte pattern from the l6a70h table.
sub_6508h:
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
; --- LOOKUP_WORD_TBL - DE = ((word*)DE)[A] ----------------------------------
;  Generic word-table lookup: DE points at a table of little-endian words, A is
;  the index; returns the selected word in DE.  HL is clobbered.
LOOKUP_WORD_TBL:
	ld l,a
	ld h,000h
	add hl,hl               ; HL = A*2
	add hl,de               ; HL -> &table[A]
	ld e,(hl)               ; DE = table[A] (lo)
	inc hl
	ld d,(hl)               ;      (hi)
	ret
; --- 0x6552 - refresh the on-screen sprite/pattern data in VRAM ------------
;  When nothing special is going on (event 0xCE00 != 5, sub-state 0xC5AC != 5,
;  flag 0xCE0C == 0) this animates: it advances the phase in 0xC00F (cycles
;  0..0x78 in steps of 0x68 &0x78), then re-uploads the animated pattern tables
;  to VRAM.  Otherwise it falls back to the plain shadow blit at l65abh.
	ld a,(0ce0ch)
	or a
	jp nz,l65abh           ; effect flag set -> plain blit
	ld a,(0ce00h)
	cp 005h
	jr z,l65abh            ; event 5 -> plain blit
	ld a,(0c5ach)
	cp 005h
	jr z,l65abh            ; sub-state 5 -> plain blit
	ld hl,0c00fh
	ld a,(hl)
	add a,068h
	and 078h               ; advance animation phase (wraps within 0..0x78)
	ld (hl),a
	ld a,(00007h)
	ld c,a
	call sub_6591h         ; upload the phase-selected tile patterns
	ld hl,0f600h
	call 046b6h            ; set VRAM write pointer to 0xF600
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
; --- sub_6591h - upload the phase-selected pattern block to VRAM 0xF400 ------
sub_6591h:
	ld hl,0f400h
	call 046b6h            ; set VRAM write pointer to 0xF400
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
; --- l65abh - plain blit: copy the 0xD400 shadow (0x280 bytes) to VRAM 0xF400
l65abh:
	ld hl,0d400h
	ld de,0f400h
	ld bc,00280h
	jp 0467ch              ; -> seg0 CPU->VRAM copy helper
; --- sub_65b7h - event sub-state machine (dispatched on 0xCE01) -------------
;  Event-driven: it does NOT run during logo/title/attract/normal stage play
;  (confirmed by tracing), so the trigger is a specific event - boss / death /
;  transition - still TBD.  0xCE01 selects one of 11 handlers through the inline
;  word table below; each handler tail-jumps to the shared epilogue 0xBE44 (in
;  page 2b).  0xCE02 serves as a per-step frame timer, and the last handler
;  clears 0xCE00 and raises the 0xCE40 "done" flag (same pattern as the logo).
sub_65b7h:
	ld a,(0ce01h)          ; A = event sub-state index
	call DISPATCH_A        ; jump via the inline word table that follows
	defw 065d3h            ; 0  init: seed the 0xC0D0 block (0x11 entries, 0x5F24)
	defw 065e5h            ; 1  wait on 0xCE16, then re-run 0xAD9A
	defw 065fah            ; 2  sub_6856h; arm frame timer 0xCE02 = 0x78
	defw 06609h            ; 3  count 0xCE02 down; when 0 and 0xC800==0 -> 0x50A6(0)
	defw 06620h            ; 4  0x50A6(0x88); 0xC418=0x80; falls into l662dh
	defw 06645h            ; 5  sub_68cbh; when 0xCE36==2, arm 0xCE37 = 0xC0
	defw 0665ch            ; 6  branch on 0xCE15 (two sub-flows)
	defw 0667eh            ; 7  sub_68afh; when 0xCE36==0, 0x50A6(0x8D), timer 0xB4
	defw 06693h            ; 8  count 0xCE02 down; then 0x6A03
	defw 0669eh            ; 9  sub_6a15h; then 0x47B8/0x4805, timer = 8
	defw 066b0h            ; 10 count down; then 0xCE00 = 0, 0xCE40 = 1 (done)
; --- CE01=0: initialise the event -------------------------------------------
	xor a
	ld (0ce16h),a          ; clear the "active" flag ...
	ld (0ce0eh),a          ; ... and its companion
	ld de,0c0d0h           ; DE -> 0xC0D0 work block
	ld c,011h              ; 0x11 entries
	call 05f24h            ; seg1 block-fill/setup helper
	jp 0be44h              ; -> shared epilogue (page 2b)
; --- CE01=1: wait for 0xCE16, then step ------------------------------------
	call 0ad9ah            ; seg2b per-frame update
	ld a,(0ce16h)
	and a
	ret z                  ; not ready yet -> stay in this state
	xor a
	ld (0ce15h),a
	ld (0ce0eh),a
	call 0ad9ah
	jp 0be44h
; --- CE01=2: arm the dwell timer -------------------------------------------
	xor a
	ld (0ce12h),a
	call sub_6856h
	ld a,078h
	ld (0ce02h),a          ; frame timer = 0x78
	jp 0be44h
; --- CE01=3: wait out the timer, gated on 0xC800 ---------------------------
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
	call 050a6h            ; trigger action 0
	jp 0be44h
; --- CE01=4: (then fall through to l662dh) ---------------------------------
	ld a,088h
	call 050a6h            ; trigger action 0x88
	ld a,080h
	ld (0c418h),a
	call 045ech
l662dh:
	call sub_698bh
	ld c,017h
	ld de,08049h           ; source table in seg2 (0x8049)
	call 05f24h
	call 057bbh
	xor a
	ld (0ce36h),a          ; reset the pair of progress counters
	ld (0ce37h),a
	jp 0be44h
; --- CE01=5: advance until 0xCE36 reaches 2 --------------------------------
	call sub_68cbh
	ld a,(0ce36h)
	sub 002h
	ret nz                 ; not at step 2 yet -> stay
	ld (0ce38h),a
	ld (0ce39h),a
	ld a,0c0h
	ld (0ce37h),a          ; arm counter 0xCE37 = 0xC0
	jp 0be44h
; --- CE01=6: branch on 0xCE15 ----------------------------------------------
	ld a,(0ce15h)
	and a
	jr nz,l666eh
	call sub_67ebh         ; 0xCE15 == 0 path
	call sub_6875h
	call sub_681fh
	jp l6a50h
l666eh:
	call l69a7h            ; 0xCE15 != 0 path
	call sub_6817h
	call sub_780dh
	xor a
	ld (0ce37h),a
	jp 0be44h
; --- CE01=7: advance until 0xCE36 reaches 0 --------------------------------
	call sub_68afh
	ld a,(0ce36h)
	and a
	ret nz                 ; not done yet -> stay
	ld a,08dh
	call 050a6h            ; trigger action 0x8D
	ld a,0b4h
	ld (0ce02h),a          ; frame timer = 0xB4
	jp 0be44h
; --- CE01=8: wait out the timer, then 0x6A03 -------------------------------
	ld hl,0ce02h
	dec (hl)
	ret nz
	call 06a03h
	jp 0be44h
; --- CE01=9: finish, then short dwell --------------------------------------
	call sub_6a15h
	ret nz                 ; sub_6a15h still working -> stay
	call 047b8h
	call 04805h
	ld a,008h
	ld (0ce02h),a          ; frame timer = 8
	jp 0be44h
; --- CE01=10: dwell, then end the event ------------------------------------
	ld hl,0ce02h
	dec (hl)
	ret nz
	ld hl,CHKRAM           ; 0x0000 (CHKRAM equ) -> reset event pointer
	ld (0ce00h),hl         ; 0xCE00 = 0 (no event)
	ld a,001h
	ld (0ce40h),a          ; raise the "event done" flag
	ret
; --- sub_66c1h - post-event sequence (dispatched on 0xCE40) -----------------
;  Runs once the 0xCE01 event machine has finished (it raises 0xCE40 = 1).
;  0xCE40 (1..4) minus 1 selects one of 4 handlers via the inline table; each
;  advances 0xCE40 (via l66d8h) to step to the next.  This drives the cutscene
;  script player and, at the end, bumps the level counter 0xD012 and pokes a
;  VDP register.  Also event-gated (does not run in normal play).
sub_66c1h:
	ld a,(0ce40h)          ; A = post-event step (1..4)
	dec a                  ; -> 0-based index
	call DISPATCH_A        ; jump via the inline table below
	defw 066d0h            ; 0 (0xCE40=1) start: init script player, advance
	defw 066ddh            ; 1 (0xCE40=2) run the script each frame until done
	defw 066e7h            ; 2 (0xCE40=3) wait on 0x5310, arm timer, advance
	defw 066f8h            ; 3 (0xCE40=4) dwell, then end + bump level 0xD012
; --- CE40=1: kick off the script player ------------------------------------
	ld a,08eh
	call 050a6h            ; trigger action 0x8E
	call sub_6719h         ; reset script-player state
l66d8h:
	ld hl,0ce40h
	inc (hl)               ; advance to the next post-event step
	ret
; --- CE40=2: pump the script until it flags completion ---------------------
	call sub_6736h         ; run one script step
	ld a,(0ce32h)
	and a
	ret z                  ; script not finished -> stay
	jr l66d8h              ; done -> advance
; --- CE40=3: wait on 0x5310, then arm a dwell timer ------------------------
	call 05310h
	ret nz                 ; not ready -> stay
	ld a,01eh
	ld (0ce02h),a          ; frame timer = 0x1E
	call 047b8h
	call 047dbh
	jr l66d8h              ; advance
; --- CE40=4: dwell, then finish and advance the level ----------------------
	ld hl,0ce02h
	dec (hl)
	ret nz                 ; timer running -> stay
	xor a
	ld (0ce34h),a
	ld (0ce40h),a          ; clear the post-event step (sequence over)
	inc a
	ld (0c409h),a          ; 0xC409 = 1 (signal next phase)
	ld hl,0d012h
	ld a,(hl)
	inc a
	cp 003h
	jr nc,l6712h           ; cap the level counter at 3
	ld (hl),a              ; 0xD012 = min(level+1, ...)
l6712h:
	ld b,000h
	ld c,017h              ; VDP register 23 (R23 = vertical scroll)
	jp WRTVDP
; --- sub_6719h - reset the cutscene script-player state --------------------
sub_6719h:
	call 053e5h
	xor a
	ld (0ce30h),a          ; clear the script cursors/counters ...
	ld (0ce33h),a          ; 0xCE33 = per-step tick
	ld (0ce31h),a          ; 0xCE31 = script index (into script_ptr_6795)
	ld (0ce32h),a          ; 0xCE32 = done flag
	inc a
	ld (0ce34h),a          ; 0xCE34 = 1 (player active)
	ld a,00eh
	ld d,0ffh
	ld e,00fh
	jp 0481bh              ; seg0 VRAM setup/fill helper
; --- sub_6736h - advance the cutscene sequencer one frame ------------------
sub_6736h:
	call sub_673fh         ; tick the timeline clock (every 4th frame)
	call sub_674ah         ; fire any keyframe due at this tick
	jp l6831h              ; refresh the on-screen effect (ramp/scroll)
; --- sub_673fh - timeline clock: bump 0xCE33 every 4th frame ---------------
sub_673fh:
	ld a,(0c003h)
	and 003h
	ret nz                 ; only act on 1 frame in 4 (slows the sequence)
	ld hl,0ce33h
	inc (hl)               ; 0xCE33 = timeline tick
	ret
; --- sub_674ah - keyframe player: fire the entry due at the current tick ----
;  Pages seg 8 (0xA000) and seg 5 (0x8000) - where the script + payload live -
;  then looks up the current script (0xCE31) in script_ptr_6795.  Each script
;  is a list of {tick, action} keyframes; if the head keyframe's tick matches
;  0xCE33 it fires: action 0xFF ends the script (raise done flag 0xCE32, call
;  0x50A6(0xFF)); otherwise it blits the payload row for this tick to 0xD8xx and
;  steps to the next script (0xCE31++).  0x533D restores the original banks.
sub_674ah:
	di
	ld a,008h
	ld (0a000h),a          ; page seg 8 into page 2b (script pointers/data)
	ld (0f0f3h),a
	ei
	di
	ld a,005h
	ld (08000h),a          ; page seg 5 into page 2a (payload)
	ld (0f0f2h),a
	ei
	ld a,(0ce31h)          ; A = current script index
	ld de,l6795h
	call LOOKUP_WORD_TBL   ; DE -> script[index]
	ex de,hl               ; HL -> keyframe {tick, action, ...}
	ld a,(0ce33h)
	cp (hl)                ; timeline tick == this keyframe's tick?
	jp nz,0533dh           ; not yet -> restore banks and return
	inc hl
	ld a,(hl)              ; action byte
	inc hl
	inc a
	jr z,l6788h            ; 0xFF -> end of script
	ld d,a                 ; D = payload source high byte
	ld a,(0ce33h)
	add a,0d8h
	ld e,a                 ; DE -> payload row (0xD8xx + tick)
	ld c,0ffh
	call 04adch            ; blit the keyframe payload
	ld hl,0ce31h
	inc (hl)               ; advance to the next script/keyframe
	jp 0533dh              ; restore banks and return
l6788h:
	ld a,001h
	ld (0ce32h),a          ; raise "script finished" flag
	ld a,0ffh
	call 050a6h            ; trigger the end-of-script action
	jp 0533dh              ; restore banks and return
l6795h:
	jr nz,$-63
	add hl,sp
	cp a
	ld d,c
	cp a
	ld l,h
	cp a
	add a,d
	cp a
	sbc a,l
	cp a
	cp b
	cp a
	ret nz
	add a,d
	sub 082h
	sbc a,082h
	xor 082h
	ld sp,hl
	add a,d
	ld b,083h
	ld de,01b83h
	add a,e
	dec h
	add a,e
	jr c,$-123
	ld b,h
	add a,e
	ld d,a
	add a,e
	ld h,e
	add a,e
	ld l,(hl)
	add a,e
	ld a,e
	add a,e
	adc a,b
	add a,e
	sbc a,d
	add a,e
	and l
	add a,e
	or b
	add a,e
	cp (hl)
	add a,e
	call z,0db83h
	add a,e
	ret pe
	add a,e
	rst 38h
	add a,e
	inc c
	add a,h
	inc d
	add a,h
	inc e
	add a,h
	jr z,$-122
	inc sp
	add a,h
	ld b,h
	add a,h
	ld d,b
	add a,h
	ld e,d
	add a,h
	ld l,b
	add a,h
	ld a,d
	add a,h
	sub c
	add a,h
	sub c
	add a,h
sub_67ebh:
	ld hl,0ce39h
	ld a,(hl)
	inc a
	cp 013h
	jr c,l67f5h
	xor a
l67f5h:
	ld (hl),a
	ld hl,l6804h
	call ADD_HL_A
	ld d,(hl)
	ld e,005h
	ld a,006h
	jp 0481bh
l6804h:
	ld h,l
	ld (hl),l
	add a,l
	sub l
	and l
	or l
	push bc
	push de
	push hl
	push af
	push hl
	push de
	push bc
	or l
	and l
	sub l
	add a,l
	ld (hl),l
	ld h,l
sub_6817h:
	ld de,CHKRAM
	ld a,006h
	jp 0481bh
sub_681fh:
	ld hl,0ce38h
	inc (hl)
	ld a,(hl)
	and 01fh
	cp 01ch
	jp z,l69a7h
	cp 01fh
	ret nz
	jp sub_698bh
l6831h:
	ld a,(0ce33h)
	sub 002h
	ld h,a
	ld l,000h
	srl h
	rr l
	ld de,CHKRAM
	add hl,de
	ld bc,00080h
	xor a
	jp FILVRM
	ld a,(0ce34h)
	and a
	ret z
	ld a,(0ce33h)
	ld b,a
	ld c,017h
	jp WRTVDP
sub_6856h:
	ld b,006h
l6858h:
	push bc
	ld c,02eh
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
	call 05f24h
	pop bc
	djnz l6858h
	ret
sub_6875h:
	ld a,(0ce35h)
	call DISPATCH_A
	add a,e
	ld l,b
	adc a,l
	ld l,b
	add a,e
	ld l,b
	sbc a,h
	ld l,b
	ld hl,0ce37h
	dec (hl)
	ret nz
l6888h:
	ld hl,0ce35h
	inc (hl)
	ret
	call sub_68afh
	ld a,(0ce36h)
	and a
	ret nz
	ld a,040h
	ld (0ce37h),a
	jr l6888h
	call sub_68cbh
	ld a,(0ce36h)
	cp 002h
	ret nz
	xor a
	ld (0ce35h),a
	ld a,0c0h
	ld (0ce37h),a
	ret
sub_68afh:
	ld hl,0ce37h
	inc (hl)
	cp 010h
	jr z,l68c0h
	ld a,(hl)
	sub 010h
	ret nz
	ld (0ce36h),a
	jr sub_691bh
l68c0h:
	ld hl,0ce36h
	ld a,(hl)
	ld (hl),001h
	cp 002h
	ret nz
	jr l68e3h
sub_68cbh:
	ld hl,0ce37h
	inc (hl)
	ld a,(hl)
	cp 010h
	jr z,l68deh
	cp 020h
	ret nz
	ld a,002h
	ld (0ce36h),a
	jr l6953h
l68deh:
	ld a,001h
	ld (0ce36h),a
l68e3h:
	ld hl,060a0h
	ld de,07080h
	ld bc,01010h
	ld a,001h
	call 0494dh
	ld hl,0a0a0h
	ld de,08080h
	ld bc,01010h
	ld a,001h
	call 0494dh
	ld hl,050a0h
	ld de,l7090h
	ld bc,01010h
	ld a,001h
	call 0494dh
	ld hl,090a0h
	ld de,08090h
	ld bc,01010h
	ld a,001h
	jp 0494dh
sub_691bh:
	ld hl,040a0h
	ld de,07080h
	ld bc,01010h
	ld a,001h
	call 0494dh
	ld hl,080a0h
	ld de,08080h
	ld bc,01010h
	ld a,001h
	call 0494dh
	ld hl,050a0h
	ld de,l7090h
	ld bc,01010h
	ld a,001h
	call 0494dh
	ld hl,090a0h
	ld de,08090h
	ld bc,01010h
	ld a,001h
	jp 0494dh
l6953h:
	ld hl,060a0h
	ld de,07080h
	ld bc,01010h
	ld a,001h
	call 0494dh
	ld hl,0a0a0h
	ld de,08080h
	ld bc,01010h
	ld a,001h
	call 0494dh
	ld hl,l70a0h
	ld de,l7090h
	ld bc,01010h
	ld a,001h
	call 0494dh
	ld hl,0b0a0h
	ld de,08090h
	ld bc,01010h
	ld a,001h
	jp 0494dh
sub_698bh:
	ld hl,000a0h
	ld de,l6858h
	ld bc,01010h
	ld a,001h
	call 0494dh
	ld hl,010a0h
	ld de,08858h
	ld bc,01010h
	ld a,001h
	jp 0494dh
l69a7h:
	ld hl,020a0h
	ld de,l6858h
	ld bc,01010h
	ld a,001h
	call 0494dh
	ld hl,030a0h
	ld de,08858h
	ld bc,01010h
	ld a,001h
	jp 0494dh
	xor a
	ld (ix+07eh),a
	ld (ix+00eh),a
	ld (ix+006h),001h
	ld (ix+00bh),05ah
	ld hl,0ce12h
	ld a,(hl)
	inc (hl)
	add a,a
	ld de,l69ebh
	call LOOKUP_WORD_TBL
	call 0a564h
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	call 0a573h
	jp LOOKUP_WORD_TBL
l69ebh:
	ld b,b
	ei
	nop
	ld bc,0fd80h
	nop
	ld (bc),a
	add a,b
	ld bc,00320h
	nop
	inc b
	nop
	rst 38h
	add a,b
	rst 38h
	nop
	call m,0fe00h
	ld b,b
	ld iy,0f680h
	ld de,0ce60h
	ld bc,DCOMPR
	call 04661h
	ld a,080h
	ld (0ce13h),a
	ret
sub_6a15h:
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
	call 0481bh
	ld a,(0ce13h)
	and a
	ret
	ld (ix+00eh),005h
	ld (ix+006h),000h
	ret
l6a50h:
	ld a,(0ce36h)
	cp 002h
	ret nz
	ld a,(0c003h)
	and 007h
	ret nz
	ld c,02ch
	ld de,08098h
	jp 05f24h
	ld (ix+006h),001h
	ld (ix+00ch),008h
	ld (ix+011h),000h
l6a70h:
	ld (ix+00bh),002h
	ld de,00300h
	call 0a564h
	ld hl,0cf32h
	inc (hl)
	ld a,(hl)
	and 007h
	ld de,l6a93h
	call LOOKUP_WORD_TBL
	ld a,(0c427h)
	sub (ix+005h)
	call c,0a183h
	jp 0a573h
l6a93h:
	nop
	ld bc,00280h
	add a,b
	ld bc,00200h
	ld b,b
	ld (bc),a
	ld b,b
	ld bc,00300h
	ret nz
	ld bc,l7eddh
	ld bc,004feh
	ld de,0ffd0h
	call nz,0a550h
	ld a,(ix+001h)
	call DISPATCH_A
	cp (hl)
	ld l,d
	adc a,06ah
	and 06ah
	jp p,0006ah
	ld l,e
	dec (ix+00ch)
	ret nz
	ld (ix+00bh),0a5h
	ld (ix+00ch),008h
	inc (ix+001h)
	ret
	dec (ix+00ch)
	ret nz
	bit 7,(ix+00ah)
	ld a,0a6h
	jr nz,l6adbh
	inc a
l6adbh:
	ld (ix+00bh),a
	ld (ix+00ch),008h
	inc (ix+001h)
	ret
	dec (ix+00ch)
	ret nz
	ld (ix+00ch),018h
	inc (ix+001h)
	ret
	ld a,(ix+011h)
	call sub_6b00h
	dec (ix+00ch)
	ret nz
	inc (ix+001h)
	ret
sub_6b00h:
	ld a,(ix+011h)
	jp 0b164h
	ld a,(0ce11h)
	and a
	jr z,l6b13h
	xor a
	ld (0c007h),a
	ld (0c006h),a
l6b13h:
	call sub_771fh
	call sub_6b40h
	ld a,(0c5ach)
	cp 002h
	jr z,l6b2bh
	cp 003h
	jr z,l6b2bh
	cp 005h
	jr z,l6b2bh
	call sub_7114h
l6b2bh:
	call sub_7682h
	call sub_75c7h
	call sub_75e9h
	call sub_75f9h
	call sub_75dbh
	call sub_760bh
	jp l761fh
; sub_6b40h - Simon's per-frame action-state machine.  0xC420 is the action
; state (runtime-confirmed: 0=normal, 3=whip, 5=hurt/knockback, 6=dead among
; others); DISPATCH_A jumps through the inline word table below by that index.
sub_6b40h:
	call 0852bh
	ld a,(0c420h)          ; Simon action state
	call DISPATCH_A
	ld e,c
	ld l,e
	rst 0
	ld l,h
	or b
	ld l,l
	call po,0446dh
	ld l,a
	adc a,h
	ld l,a
	sbc a,d
	ld (hl),b
	ld (bc),a
	ld (hl),c
	call sub_7b8fh
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
	call nz,sub_6bb6h
	ld a,(0c422h)
	and a
	ret nz
	ld de,CHKRAM
	ld (0c42eh),de
	call sub_7666h
	ld a,(0c007h)
	rra
	jr c,l6be1h
l6b8ah:
	rra
	jp c,l6c17h
	rra
	push af
	call c,sub_6c36h
	pop af
	rra
	call c,sub_6c5ah
	ld a,(0c006h)
	and 020h
	ret z
	call sub_7b7fh
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
sub_6bb6h:
	dec a
	ld a,007h
	jr nz,l6bbch
	xor a
l6bbch:
	ld hl,0c598h
	call ADD_HL_A
	inc hl
	inc hl
	inc hl
	ld a,(hl)
	rla
	ld d,000h
	jr c,l6bd3h
	call sub_7bb0h
	ret c
	ld d,001h
	jr l6bd9h
l6bd3h:
	call sub_7c0ch
	ret c
	ld d,0ffh
l6bd9h:
	ld a,(0c427h)
	add a,d
	ld (0c427h),a
	ret
l6be1h:
	ex af,af'
	call sub_7ce2h
	ld bc,00001h
	jr z,l6bf5h
	call sub_7d0ch
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
l6c17h:
	call sub_7c92h
	ld bc,00002h
	jr z,l6bf5h
	call sub_7cbah
	ld bc,UPC
	jr z,l6bf5h
	ld a,002h
	ld (0c420h),a
	ld de,00006h
	ld (0c42eh),de
	jp sub_7666h
sub_6c36h:
	ld a,001h
	ld (0c42ch),a
	ld a,(0c41eh)
	inc a
	jr nz,l6c47h
	ld a,(0c427h)
	cp 010h
	ret c
l6c47h:
	call sub_7c0ch
	ret c
	ld a,(0c431h)
	and 008h
	ld bc,0fe00h
	jr z,l6c58h
	ld bc,0fd80h
l6c58h:
	jr l6c7ah
sub_6c5ah:
	xor a
	ld (0c42ch),a
	ld a,(0c41fh)
	inc a
	jr nz,l6c6ah
	ld a,(0c427h)
	cp 0f0h
	ret nc
l6c6ah:
	call sub_7bb0h
	ret c
	ld a,(0c431h)
	and 008h
	ld bc,00200h
	jr z,l6c7ah
	ld c,080h
l6c7ah:
	push bc
	ld a,(0c425h)
	ld b,a
	ld a,(0c427h)
	ld c,a
	call 08587h
	pop bc
	ret c
	ld a,(0c5ach)
	dec a
	dec a
	cp 002h
	ret c
	ld a,(0c420h)
	cp 005h
	jr z,l6c9bh
	dec a
	call nz,sub_6ca3h
l6c9bh:
	ld hl,(0c426h)
	add hl,bc
	ld (0c426h),hl
	ret
sub_6ca3h:
	ld a,(0c007h)
	and 00ch
	cp 00ch
	ret z
sub_6cabh:
	ld a,(0c003h)
	rra
	rra
	rra
	ld de,00101h
	jr c,l6cbfh
	rra
	ld de,CHKRAM
	jr c,l6cbfh
	ld de,00202h
l6cbfh:
	ld hl,(0c42eh)
	add hl,de
	ld (0c42eh),hl
	ret
	ld a,(0c421h)
	call DISPATCH_A
	push de
	ld l,h
	xor 06ch
	ld l,b
	ld l,l
	ld l,(hl)
	ld l,l
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
l6ceeh:
	ld a,(0c431h)
	and 010h
	ld bc,l6d9bh+1
	ld d,013h
	jr z,l6cffh
	ld bc,l6d9bh
	ld d,015h
l6cffh:
	ld hl,0c428h
	push hl
	call sub_6d54h
	pop hl
	ld a,(0c422h)
	and a
	jr nz,l6d1ah
	ld d,000h
	ld e,006h
	ld (0c42eh),de
	push hl
	call sub_7666h
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
	call nc,sub_6d74h
	pop hl
	call sub_7b8fh
	jr c,l6d37h
	ld a,(0c439h)
	and a
	ret z
l6d37h:
	ld a,(0cff0h)
	and a
	jr z,l6d42h
	ld a,007h
	call 050a6h
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
sub_6d54h:
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
	call sub_6c36h
	jp l6ceeh
	call sub_6c5ah
	jp l6ceeh
sub_6d74h:
	ld a,001h
	ld (de),a
	ld a,(0c420h)
	dec a
	ret z
	push af
	ld a,(hl)
	sub 013h
	add a,a
	add a,a
	add a,a
	ld e,a
	pop af
	dec a
	jr z,l6d91h
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
l6d9bh:
	jp m,0fafah
	ei
	ei
	nop
	call m,0fefdh
	rst 38h
	nop
	nop
	ld bc,00302h
	inc b
	dec b
	dec b
	ld b,006h
	ld b,0cdh
	ei
	add a,l
	jr nc,l6dcfh
	ld a,(0c006h)
	and 020h
	jr z,l6dcfh
	ld a,007h
	ld (0c420h),a
	xor a
	ld (0c421h),a
	ld a,040h
	ld (0c42dh),a
	ld a,015h
	jp 050a6h
l6dcfh:
	ld a,(0c439h)
	and a
	call nz,sub_6bb6h
	ld a,(0c422h)
	and a
	ret nz
	ld a,(0c007h)
	rra
	rra
	ret c
	jp l6efch
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
	call sub_6f10h
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
	call sub_7b8fh
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
	call sub_6f10h
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
	call sub_7b8fh
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
	call sub_6f2bh
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
	call sub_7b6fh
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
	call sub_6f2bh
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
	call sub_7b6fh
	ret nc
l6efch:
	ld de,CHKRAM
	ld (0c42eh),de
	xor a
	ld (0c435h),a
	ld (0c42bh),a
	call sub_7666h
	jp l6d42h
sub_6f10h:
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
sub_6f2bh:
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
	ld a,(0c439h)
	and a
	jr nz,l6f71h
	call sub_7b8fh
	jr c,l6f71h
	ld de,CHKRAM
	ld (0c42eh),de
	call sub_7666h
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
	jp 050a6h
l6f88h:
	ld (bc),a
	inc b
	ld b,006h
	ld a,(0c423h)
	call DISPATCH_A
	sbc a,d
	ld l,a
	in a,(06fh)
	ld e,070h
	inc h
	ld (hl),b
	ld a,(0c002h)
	and 040h
	ld a,013h
	call nz,050a6h
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
	jp sub_7666h
l6fc3h:
	ld a,(0c43ch)
	ld (0c42ch),a
	inc a
	ld (0c423h),a
	xor a
	ld (0c42ah),a
	ld de,00307h
	ld (0c42eh),de
	jp sub_7666h
	call sub_6c36h
l6fdeh:
	ld bc,l7084h
	ld d,015h
	ld hl,0c42ah
	push hl
	call sub_6d54h
	pop hl
	ld a,(hl)
	cp 00bh
	ret c
	call sub_7b8fh
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
	call sub_6c5ah
	jp l6fdeh
	ld a,(0c439h)
	and a
	call nz,sub_6bb6h
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
	jp sub_7666h
l7084h:
	defb 0fdh,0fdh,0feh ;illegal sequence	;7084	fd fd fe	. . .
	cp 0feh
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	nop
	nop
	nop
l7090h:
	nop
	ld bc,00101h
	ld bc,00202h
	ld (bc),a
	inc bc
	inc bc
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
	call 050a6h
	ld a,089h
	jp 050a6h
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
	ld (0c413h),a
sub_70e3h:
	ld a,(0c701h)
	and 080h
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
	ld a,(0c42dh)
	and a
	ret nz
	xor a
	ld (0c420h),a
	ld (0c43dh),a
	ld a,0ffh
	ld (0c41bh),a
	ret
sub_7114h:
	call sub_711dh
	call sub_71e7h
	jp l72b9h
sub_711dh:
	ld a,(0c006h)
	and 010h
	jr z,l713dh
	ld hl,0c422h
	ld a,(hl)
	and a
	ret nz
	ld a,(0c416h)
	ld (0c436h),a
	cp 002h
	jr c,l713ah
	call sub_71c5h
	ld a,b
	and a
	ret z
l713ah:
	ld (hl),001h
	ret
l713dh:
	ld a,(0c420h)
	dec a
	ret nz
	ld a,(0c701h)
	push af
	rra
	rra
	rra
	rra
	call c,sub_7154h
	pop af
	rla
	rla
	call c,sub_7166h
	ret
sub_7154h:
	ld a,(0c417h)
	cp 005h
	ret c
	ld a,(0c006h)
	rra
	rra
	rra
	jr c,l719bh
	rra
	jr c,l71a8h
	ret
sub_7166h:
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
	jp 050a6h
l719bh:
	ld a,(0c461h)
	and a
	ret nz
	ld a,001h
	ld (0c468h),a
	jp l71b1h
l71a8h:
	ld a,(0c461h)
	and a
	ret nz
	xor a
	ld (0c468h),a
l71b1h:
	call 099a6h
	ld a,005h
	ld (0c461h),a
	ld a,(0c417h)
	sub 005h
	daa
	ld (0c417h),a
	jp 0456dh
sub_71c5h:
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
	ld de,CHRGTR
	add ix,de
	djnz l71d3h
	ret
sub_71e7h:
	ld a,(0c422h)
	and a
	ret z
	ld a,(0c420h)
	cp 004h
	ret nc
	ld a,(0c422h)
	dec a
	call DISPATCH_A
	ld bc,04772h
	ld (hl),d
	ld d,a
	ld (hl),d
	ld l,c
	ld (hl),d
	ld a,(0c420h)
	cp 003h
	jr z,l7213h
	cp 002h
	ld a,000h
	jr nz,l7210h
	ld a,006h
l7210h:
	ld (0c42eh),a
l7213h:
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
	call sub_7666h
	ld a,005h
	call 050a6h
	jr l7242h
l7231h:
	call 0559ah
	ld a,00ch
	ld (0c42fh),a
	call sub_7666h
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
	jp 0559ah
	ld a,(0c436h)
	cp 002h
	jr nc,l7247h
	call 099a6h
	ld hl,0c42fh
	inc (hl)
	ld a,004h
	jr l723fh
	ld a,(0c436h)
	cp 002h
	jr nc,l728dh
	ld hl,0c429h
	dec (hl)
	ret nz
sub_7275h:
	xor a
	ld (0c422h),a
	ld (0c429h),a
	ld a,(0c420h)
	cp 003h
	ld a,000h
	jr nz,l7287h
	ld a,002h
l7287h:
	ld (0c42fh),a
	jp sub_7666h
l728dh:
	call 099a6h
	call sub_7275h
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
	ld de,CHRGTR
	add ix,de
	djnz l7299h
	ret
l72b9h:
	ld ix,0c450h
	call sub_72c4h
	ld ix,0c460h
sub_72c4h:
	ld a,(ix+001h)
	and a
	ret z
	call sub_72d5h
	call sub_74c2h
	call sub_74d5h
	jp l753ch
sub_72d5h:
	ld a,(ix+001h)
	dec a
	dec a
	call DISPATCH_A
	dec a
	ld (hl),h
	ld a,d
	ld (hl),h
	push hl
	ld (hl),d
	xor e
	ld (hl),e
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
	call 050a6h
l72ffh:
	ld a,(ix+000h)
	dec a
	call DISPATCH_A
	ld c,073h
	ld b,h
	ld (hl),e
	ld a,d
	ld (hl),e
	and h
	ld (hl),e
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
	jp 099a6h
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
	jp 099a6h
	call 08247h
	jp c,l74f0h
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
	call 08247h
	ret nc
	jp l74f0h
	ld a,(ix+000h)
	dec a
	dec a
	jr z,l73e5h
	dec a
	jr z,l7420h
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
l73e5h:
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
	call sub_7b9fh
	ret nc
	inc (ix+000h)
	xor a
	ld (ix+002h),a
	ld (ix+003h),a
	ld (ix+007h),a
	ld a,018h
	jp 050a6h
l7420h:
	ld a,(0c003h)
	and 004h
	ld a,0f4h
	jr z,l742eh
	call 099a6h
	ld a,0f8h
l742eh:
	ld (ix+006h),a
	inc (ix+007h)
	ld a,(ix+007h)
	cp 018h
	ret c
	jp l74f0h
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
	jp 050a6h
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
	call 050a6h
l7493h:
	ld hl,0c433h
	ld a,(hl)
	sub 002h
	cp 002h
	jr c,l74ach
	ld a,(ix+000h)
	dec a
	call DISPATCH_A
	ld c,073h
	ld b,h
	ld (hl),e
	ld a,d
	ld (hl),e
	and h
	ld (hl),e
l74ach:
	ld (hl),000h
	ld b,01ch
	ld d,(ix+005h)
	ld a,(ix+004h)
	sub 010h
	ld e,a
	call 08999h
	call l74f0h
	jp 08e9ah
sub_74c2h:
	ld a,(ix+004h)
	add a,(ix+002h)
	ld (ix+004h),a
	ld a,(ix+005h)
	add a,(ix+003h)
	ld (ix+005h),a
	ret
sub_74d5h:
	ld a,(ix+004h)
	sub 0d8h
	cp 010h
	jr c,l74f0h
	ld a,(ix+005h)
	sub 0fbh
	cp 00ah
	ret nc
	ld a,(0c416h)
	sub 003h
	cp 002h
	call c,08e9ah
l74f0h:
	push ix
	pop hl
sub_74f3h:
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
sub_751ah:
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
	jr nz,l759ch
	ld a,00fh
	ld b,010h
	call sub_7597h
	ld a,00eh
	ld b,010h
sub_7597h:
	ld (hl),a
	inc hl
	djnz sub_7597h
	ret
l759ch:
	ld a,002h
	ld b,010h
	call sub_7597h
	ld a,04ch
	ld b,010h
	call sub_7597h
	ld a,(ix+001h)
	cp 005h
	ret nz
	ld a,(ix+000h)
	cp 003h
	ret nz
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
sub_75c7h:
	ld hl,0c440h
	call sub_75d6h
	ld hl,0c434h
	call sub_75d6h
	ld hl,0c42dh
sub_75d6h:
	ld a,(hl)
	and a
	ret z
	dec (hl)
	ret
sub_75dbh:
	ld hl,0c445h
	ld a,(hl)
	and a
	ret z
	dec (hl)
	ret nz
	ld a,018h
	ld (0c43eh),a
	ret
sub_75e9h:
	ld hl,0c43ah
	ld a,(hl)
	and a
	ret z
	dec (hl)
	ld a,(hl)
	cp 010h
	ret nz
	ld a,017h
	jp 050a6h
sub_75f9h:
	ld hl,0c43bh
	ld a,(hl)
	and a
	ret z
	dec (hl)
	ret nz
	ld hl,0d010h
	res 0,(hl)
	ld a,0fch
	jp 050a6h
sub_760bh:
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
sub_7666h:
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
sub_7682h:
	ld a,(0c420h)
	cp 006h
	ret z
	ld hl,0c41bh
	ld de,0c425h
	ld bc,0c427h
	ld a,(0c420h)
	cp 003h
	ld a,(de)
	jr nz,l769dh
	cp 030h
	jr c,l76abh
l769dh:
	cp 0e1h
	jr nc,l76c3h
	ld a,(bc)
	cp 008h
	jr c,l7709h
	cp 0f8h
	jr nc,l7714h
	ret
l76abh:
	ld a,(0c420h)
	dec a
	ret z
	ld a,0e0h
	ld (de),a
	ld a,(0c42ch)
	and a
	ld d,0f0h
	jr z,l76bdh
	ld d,010h
l76bdh:
	ld a,(bc)
	add a,d
	ld (bc),a
	ld (hl),001h
	ret
l76c3h:
	ld a,(0c41dh)
	inc a
	jr nz,l76efh
	xor a
	ld (0c421h),a
	ld a,006h
	ld (0c420h),a
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
	jp 050a6h
l76efh:
	ld a,030h
	ld (de),a
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
	ld (hl),002h
	ret
l7709h:
	ld a,(0c41eh)
	inc a
	ret z
	ld a,0f6h
	ld (bc),a
	ld (hl),003h
	ret
l7714h:
	ld a,(0c41fh)
	inc a
	ret z
	ld a,00ah
	ld (bc),a
	ld (hl),004h
	ret
sub_771fh:
	ld a,(0c5ach)
	call DISPATCH_A
	inc c
	ld a,b
	ld sp,00c77h
	ld a,b
	sub c
	ld (hl),a
	ld sp,09177h
	ld (hl),a
	ld de,0c425h
	ld a,(de)
	ld b,a
	inc e
	inc e
	ld a,(de)
	ld c,a
	call 08587h
	ret nc
	ld hl,0c701h
	ld a,(0d000h)
	and a
	jr z,l774ah
	ld a,(hl)
	rra
	ret nc
l774ah:
	res 0,(hl)
	call 08ec1h
	xor a
	ld (0c422h),a
	call sub_780dh
	call sub_751ah
	ld hl,0c5ach
	inc (hl)
	ld a,(0d000h)
	ld de,l777eh
	call ADD_DE_A
	ld a,(de)
	and a
	jr z,l776fh
	ld a,0ffh
	call 050a6h
l776fh:
	ld a,(hl)
	cp 005h
	jr z,l7779h
	ld a,01ah
	jp 050a6h
l7779h:
	ld a,015h
	jp 050a6h
l777eh:
	nop
	nop
	nop
	ld bc,CHKRAM
	ld bc,CHKRAM
	ld bc,00001h
	ld bc,CHKRAM
	ld bc,00100h
	ld bc,0ac3ah
	push bc
	cp 005h
	call z,055f3h
	ld a,(0c420h)
	and a
	ret nz
	ld bc,CHKRAM
	ld (0c42eh),bc
	call sub_7666h
	ld a,(0c42ch)
	and a
	ld bc,00080h
	jr z,l77b4h
	ld bc,0ff80h
l77b4h:
	call l6c9bh
	call sub_6cabh
	ld a,(0c5ach)
	cp 005h
	jr z,l77cbh
	ld a,(0c427h)
	sub 008h
	cp 0f0h
	ret c
	jr l77d8h
l77cbh:
	ld a,(0c5aeh)
	add a,008h
	ld b,a
	ld a,(0c427h)
	sub b
	cp 008h
	ret nc
l77d8h:
	ld hl,0c41eh
	ld de,0c427h
	ld a,(de)
	rla
	jr c,l77ebh
	ld a,(hl)
	inc a
	jr z,l7807h
	ld bc,003f6h
	jr l77f3h
l77ebh:
	inc hl
	ld a,(hl)
	inc a
	jr z,l7807h
	ld bc,0040ah
l77f3h:
	ld a,b
	ld (0c41bh),a
	ld a,c
	ld (de),a
	ld a,(0d000h)
	cp 012h
	ld a,087h
	jr nz,l7804h
	ld a,086h
l7804h:
	jp 050a6h
l7807h:
	ld a,001h
	ld (0c408h),a
	ret
sub_780dh:
	ld ix,0c800h
	ld b,007h
l7813h:
	ld a,(ix+000h)
	and a
	push bc
	push ix
	call nz,09a41h
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
	call nz,09a21h
	pop bc
	ld de,00080h
	add ix,de
	djnz l782dh
	ret
	call sub_7913h
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
	ld hl,l798ch
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
	call sub_78a0h
	ld a,(0c42fh)
	add a,a
	ld hl,l79dch
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
sub_78a0h:
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
	ld b,0e0h
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
	djnz sub_78a0h
	ret
sub_7913h:
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
	ld a,00eh
	jr c,l7951h
l7939h:
	ld a,(0c434h)
	and a
	jr z,l7947h
	ld a,(0c003h)
	rra
	ld a,008h
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
	ld a,(0c40dh)
	and a
	jr nz,l796ch
	ld a,(0d000h)
	and a
	jr z,l796ch
	dec a
	ld hl,l777eh
	call ADD_HL_A
	ld a,(hl)
	and a
	ret z
l796ch:
	ld a,(0d000h)
	ld hl,l7979h
	call ADD_HL_A
	ld a,(hl)
	jp 050a6h
l7979h:
	add a,b
	add a,b
	add a,b
	add a,b
	add a,c
	add a,c
	add a,c
	add a,d
	add a,d
	add a,d
	add a,l
	add a,c
	add a,c
	add a,h
	add a,h
	add a,h
	add a,e
	add a,e
	add a,l
l798ch:
	inc h
	ld a,d
	inc h
	ld a,d
	inc h
	ld a,d
	inc h
	ld a,d
	inc h
	ld a,d
	inc h
	ld a,d
	add hl,hl
	ld a,d
	ld l,07ah
	ld l,07ah
	inc sp
	ld a,d
	jr c,l7a1ch
	jr c,l7a1eh
	jr c,l7a20h
	jr c,l7a22h
	jr c,l7a24h
	jr c,$+124
	dec a
	ld a,d
	ld b,d
	ld a,d
	ld b,d
	ld a,d
	ld b,a
	ld a,d
	inc h
	ld a,d
	inc h
	ld a,d
	inc h
	ld a,d
	inc h
	ld a,d
	inc h
	ld a,d
	inc h
	ld a,d
	add hl,hl
	ld a,d
	ld l,07ah
	ld l,07ah
	inc sp
	ld a,d
	jr c,l7a44h
	jr c,l7a46h
	jr c,l7a48h
	jr c,$+124
	jr c,l7a4ch
	jr c,$+124
	dec a
	ld a,d
	ld b,d
	ld a,d
	ld b,d
	ld a,d
	ld b,a
	ld a,d
l79dch:
	ld c,h
	ld a,d
	ld c,h
	ld a,d
	ld c,h
	ld a,d
	ld d,(hl)
	ld a,d
	ld d,(hl)
	ld a,d
	ld e,e
	ld a,d
	ld h,b
	ld a,d
	ld l,l
	ld a,d
	halt
	ld a,d
	ld h,b
	ld a,d
	ld l,l
	ld a,d
	halt
	ld a,d
	add a,e
	ld a,d
	add a,e
	ld a,d
	adc a,b
	ld a,d
	sub c
	ld a,d
	sub c
	ld a,d
	sub c
	ld a,d
	sbc a,e
	ld a,d
	sbc a,e
	ld a,d
	and b
	ld a,d
	and l
	ld a,d
	or d
	ld a,d
	cp e
	ld a,d
	and l
	ld a,d
	or d
	ld a,d
	cp e
	ld a,d
	ret z
	ld a,d
	ret z
	ld a,d
	call 04c7ah
	ld a,d
	ld c,h
	ld a,d
l7a1ch:
	ld c,h
	ld a,d
l7a1eh:
	sub c
	ld a,d
l7a20h:
	sub c
	ld a,d
l7a22h:
	sub c
	ld a,d
l7a24h:
	ld (bc),a
	jp p,0f2f8h
	ret m
	ld (bc),a
	ret m
	ret m
	ret m
	ret m
	ld (bc),a
	pop af
	ret m
	pop af
	ret m
	ld (bc),a
	pop af
	ret p
	pop af
	ret p
	ld (bc),a
	jp p,0f2f9h
	ld sp,hl
	ld (bc),a
	ret m
	ld sp,hl
	ret m
	ld sp,hl
	ld (bc),a
	pop af
l7a44h:
	ld sp,hl
	pop af
l7a46h:
	ld sp,hl
	ld (bc),a
l7a48h:
	pop af
	ld bc,001f1h
l7a4ch:
	ld (bc),a
	jp po,0e2f8h
	ret m
	ld (bc),a
	ret pe
	ret m
	ret pe
	ret m
	ld (bc),a
	pop hl
	ret m
	pop hl
	ret m
	ld (bc),a
	pop af
	nop
	pop af
	nop
l7a60h:
	ld b,0e2h
l7a62h:
	ret p
	jp po,0e2f0h
	ret po
	jp po,0f2e0h
	ret po
	jp p,004e0h
	jp po,0e2f0h
	ret p
	jp (hl)
	ret po
	jp (hl)
	ret po
	ld b,0e2h
	ret m
	jp po,0e2f8h
	jr l7a60h
	jr l7a62h
	ex af,af'
	jp po,00208h
	jp po,0e2f0h
	ret p
	inc b
	jp po,0e2f8h
	ret m
	jp po,0e208h
	ex af,af'
	ld (bc),a
	jp po,0e2f9h
	ld sp,hl
	ld (bc),a
	ret pe
	ld sp,hl
	ret pe
	ld sp,hl
	ld (bc),a
	pop hl
	ld sp,hl
	pop hl
	ld sp,hl
	ld (bc),a
	pop af
	pop af
	pop af
	pop af
	ld b,0e2h
	ld bc,001e2h
	jp po,0e211h
	ld de,011f2h
	jp p,00411h
	jp po,0e201h
	ld bc,011e9h
	jp (hl)
	ld de,0e206h
	ld sp,hl
	jp po,0e2f9h
	exx
	jp po,0e2d9h
	jp (hl)
	jp po,002e9h
	jp po,0e201h
	ld bc,0e204h
	ld sp,hl
	jp po,0e2f9h
	jp (hl)
	jp po,01ee9h
	djnz $+64
	ld (bc),a
	ld d,000h
	ld bc,00709h
	push hl
	push de
	call 04911h
	pop de
	pop hl
	ld a,010h
	add a,h
	ld h,a
	dec e
	jr nz,$-19
	ret
	ld a,002h
	ld de,01101h
	jp 0481bh
	ld de,0d600h
	ld hl,l7b59h
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
	ld de,CHKRAM
	call 0481bh
	jp l65abh
l7b39h:
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
	jr l7b39h
l7b4eh:
	ld a,c
	call 04b24h
	call 04b56h
	jr l7b3ah
l7b57h:
	pop de
	ret
l7b59h:
	daa
	jr c,$+41
	ld c,h
	daa
	ld h,b
	ccf
	jr nc,$+65
	ld b,b
	ld c,a
	jr nc,$+81
	ld b,b
	ccf
	ld (hl),b
	ccf
	add a,b
	ld c,a
	ld (hl),b
	ld c,a
	add a,b
sub_7b6fh:
	ld a,(0c425h)
	add a,007h
	ld e,a
	ld a,(0c427h)
	ld d,a
	call sub_7d36h
	jp l7c65h
sub_7b7fh:
	ld a,(0c425h)
	sub 02ch
	ld e,a
	ld a,(0c427h)
	ld d,a
	call sub_7d36h
	jp l7c65h
sub_7b8fh:
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
sub_7b9fh:
	call sub_7d36h
	call l7c65h
	ret c
	ld a,d
	sub 00ah
	ld d,a
	call sub_7d36h
	jp l7c65h
sub_7bb0h:
	ld a,(0c425h)
	ld e,a
	ld a,(0c427h)
	ld d,a
	ld bc,00802h
	xor a
	jr l7bc7h
	ld bc,01004h
	ld a,002h
	jr l7bc7h
	ld a,001h
l7bc7h:
	ld (0cff0h),a
	ld a,e
	sub c
	ld e,a
	ld a,d
	add a,b
	ld d,a
	call sub_7d36h
	call l7c65h
	ret c
	ld a,e
	sub 008h
	ld e,a
	call sub_7d36h
	call l7c65h
	ret c
	ld a,(0cff0h)
	cp 002h
	ret z
	ld a,e
	sub 008h
	ld e,a
	call sub_7d36h
	call l7c65h
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
	call sub_7d36h
	jp l7c65h
sub_7c0ch:
	ld a,(0c425h)
	ld e,a
	ld a,(0c427h)
	ld d,a
	ld bc,00802h
	xor a
	jr l7c23h
	ld bc,01004h
	ld a,002h
	jr l7c23h
	ld a,001h
l7c23h:
	ld (0cff0h),a
	ld a,e
	sub c
	ld e,a
	ld a,d
	sub b
	ld d,a
	call sub_7d36h
	call l7c65h
	ret c
	ld a,e
	sub 008h
	ld e,a
	call sub_7d36h
	call l7c65h
	ret c
	ld a,(0cff0h)
	cp 002h
	ret z
	ld a,e
	sub 008h
	ld e,a
	call sub_7d36h
	call l7c65h
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
	call sub_7d36h
l7c65h:
	ld c,a
	ld a,(0ce00h)
	cp 006h
	jr z,l7c7ah
	ld a,(0d000h)
	ld hl,l7c7fh
	call ADD_HL_A
	ld a,c
	dec a
	cp (hl)
	ret
l7c7ah:
	ld a,c
	dec a
	cp 006h
	ret
l7c7fh:
	ld (bc),a
	inc b
	inc b
	inc b
	inc b
	inc b
	inc b
	inc b
	inc b
	inc b
	add hl,bc
	add hl,bc
	add hl,bc
	inc b
	inc b
	inc b
	add hl,bc
	add hl,bc
	ex af,af'
sub_7c92h:
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
	call sub_7d36h
	cp 004h
	ret z
	ld a,(bc)
	add a,008h
	ld d,a
	call sub_7d36h
	cp 004h
	ret nz
	ld a,(bc)
	add a,008h
	ld (bc),a
	xor a
	ret
sub_7cbah:
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
	call sub_7d36h
	cp 003h
	ret z
	ld a,(bc)
	sub 008h
	ld d,a
	call sub_7d36h
	cp 003h
	ret nz
	ld a,(bc)
	sub 008h
	ld (bc),a
	xor a
	ret
sub_7ce2h:
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
	call sub_7d36h
	cp 00dh
	ret z
	ld a,(bc)
	ld d,a
	call sub_7d36h
	cp 00dh
	ret nz
	ld a,(bc)
	add a,008h
	ld (bc),a
	xor a
	ret
sub_7d0ch:
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
	call sub_7d36h
	cp 00ch
	ret z
	ld a,(bc)
	ld d,a
	call sub_7d36h
	cp 00ch
	ret nz
	ld a,(bc)
	sub 008h
	ld (bc),a
	xor a
	ret
sub_7d36h:
	ld a,e
	sub 010h
	and 0f8h
	rrca
	rrca
	rrca
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
	ld a,(0c41bh)
	and a
	ret nz
	call sub_7e6eh
	call sub_7eebh
	call sub_7fe9h
	call 085adh
	ld a,(0c416h)
	cp 002h
	jr nc,l7d92h
	call sub_7db4h
	call sub_7f50h
	call sub_7fbeh
	jr l7d95h
l7d92h:
	call sub_7da7h
l7d95h:
	call 08025h
	call sub_7f80h
	call 080adh
	call 080e3h
	call 08122h
	jp 08617h
sub_7da7h:
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
sub_7db4h:
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
	call 08283h
	pop bc
	jr c,l7ddbh
l7dd3h:
	ld de,00080h
	add ix,de
	djnz l7dc0h
	ret
l7ddbh:
	ld a,00ch
	call 050a6h
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
	call 081b2h
	jp 09a45h
l7e06h:
	ld a,(ix+000h)
	cp 012h
	jr nz,l7e13h
	ld a,(0ce00h)
	and a
	jr z,l7dedh
l7e13h:
	call sub_7e33h
	ld a,(0c418h)
	and a
	jr z,l7e1eh
	rla
	ret nc
l7e1eh:
	ld a,014h
	ld (0c445h),a
	ld a,01ch
	call 050a6h
	call 081b2h
	ld a,001h
	ld (0ce15h),a
	jp sub_780dh
sub_7e33h:
	ld hl,l7e60h
	ld a,(0c416h)
	and a
	jr z,l7e43h
	cp 002h
	jr z,l7e43h
	ld hl,07e67h
l7e43h:
	ld a,(ix+000h)
	ld c,a
	sub 011h
	call ADD_HL_A
	ld b,(hl)
	ld a,c
	cp 017h
	jr nz,l7e5dh
	ld a,(0c416h)
	cp 002h
	jr c,l7e5dh
	srl b
	srl b
l7e5dh:
	jp 04643h
l7e60h:
	inc b
	ex af,af'
	ex af,af'
	inc b
	inc b
	inc b
	djnz sub_7e6eh
	inc c
	inc c
	ld b,006h
	ld b,018h
sub_7e6eh:
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
	call 08297h
	pop bc
	jr nc,l7ee3h
	ld a,(ix+000h)
	cp 024h
	jp z,09a45h
	cp 026h
	jp z,09a45h
	cp 022h
	jr nz,l7eb7h
	ld a,001h
	ld (0ce11h),a
	jp 09a45h
l7eb7h:
	ld a,(0c434h)
	and a
	jr z,l7ec8h
	call 081b2h
	call 09a45h
	ld a,00dh
	jp 050a6h
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
sub_7eebh:
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
	call 08253h
	jr nc,l7f47h
	call 099fdh
	pop bc
	ld a,(0c434h)
	and a
	jp nz,08231h
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
sub_7f50h:
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
	call 08277h
	jr nc,l7f77h
	ld a,00ch
	call 050a6h
	call 08231h
	call 09a21h
l7f77h:
	pop bc
	ld de,00080h
	add ix,de
	djnz l7f5ch
	ret
sub_7f80h:
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
	call 0825fh
	pop bc
	jr nc,l7fb6h
	ld a,00ch
	call 050a6h
	ld a,(iy+001h)
	cp 002h
	push iy
	pop hl
	call z,sub_74f3h
	call 08231h
	jp 09a21h
l7fb6h:
	ld de,00080h
	add ix,de
	djnz l7f8fh
	ret
sub_7fbeh:
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
	call 08457h
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
	call 050a6h
l7fe2h:
	ld a,010h
	add a,l
	ld l,a
	djnz l7fc9h
	ret
sub_7fe9h:
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
	call 08237h
	pop hl
	jr nc,$+30

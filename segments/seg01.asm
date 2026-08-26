; ===========================================================================
;  SEGMENT 1 - banked code, paged at 0x6000-0x7FFF (page 1b) during play.
;  Reached from segment 0's state machine (see the call sites in seg00.asm);
;  holds main gameplay-loop routines.  BIOS names come from segments/bios.inc
;  and the seg0 helper labels (ADD_HL_A, DISPATCH_A, ...) resolve from seg00.asm.
;  Disassembly in progress: code/data split is described in segments/seg01.blocks.
;  (Regenerate raw disasm with  tools/regen-seg.sh 1 0x6000 segments/seg01.blocks .)
; ===========================================================================
; ---- MSX main-ROM BIOS jump table ----------------------------------------


; BLOCK 'data_6000' (start 0x6000 end 0x6030)
; Spawn-init overflow of entity_tbl (seg0 0x5FD3). The table is odd-aligned:
; type 23 reads 0x5FFF (047h) + 0x6000, type 24 starts at 0x6001. Confirmed
; when page 1b is seg1: 0x18 Igor igor_tick 0xBAE4, 0x19-0x1C enemy_blob_tick
; 0xB4D9, 0x1E flame_init 0x9B67, 0x1F
; enemy_placed_bat_init 0xB0D5, 0x21 enemy_placed_merman_init 0xA2CE,
; 0x23 hunchback 0xB219, 0x24 heart 0x9BA2. Do not word-align this block.
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
	call lookup_word_tbl
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
; --- l61c2h - spawn actors from the visible room's object list ---------------
;  Walks 4 slots of the 0xDB00 list at the current room and, for each live
;  slot, unpacks its byte-packed X/Y and calls spawn_actor+2 (0x5F26) with
;  C = id&0x7F (the actor_* type). Stage 0 returns immediately (dec a; ret m).
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
	and 07fh               ; low 7 bits = actor type
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
	call 05f26h            ; spawn_actor+2: C = type, DE = pixel pos
l6200h:
	pop hl
	pop bc
	inc hl                 ; advance to the next slot (stride 4)
	inc hl
	inc hl
	inc hl
	djnz l61e2h
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
	call 04911h             ; seg0 VDP fill (clears the logo area to white)
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
;  unpacks scenery (candles/blocks/chests/vendors), loads the packed object
;  list and spawns its actors (`l61c2h`).  Many steps are helpers in seg1/seg2
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
	call 04f8ah
	call 047dbh
	call cell_event_set         ; set the current cell's event type (0xCE00)
	call 04f98h
	call vendor_tick       ; C5B5/C5C5 special objects (seg2 0x91C5)
	call brazier_tick_all  ; tick braziers/candles (seg2 0x8678)
	call door_anim_tick
	call hud_bonus_refresh
	ld a,(0ce00h)          ; event code for this cell
	cp 006h
	call z,sub_6334h       ; event 6 -> extra setup (sub_691bh + l69a7h)
	call 047ceh
	call 09cb0h
	call object_list_load         ; load the packed object list into 0xDB00/DC00/DD00
	jp l61c2h              ; spawn actors from the room object list
sub_6334h:
	call sub_691bh
	jp l69a7h
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
;  from 0xD700.
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
	call sprites_hide         ; hide all hardware sprites
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
;  into page 2b (0xA000), looks up the actor's shape stream by (ix+0x0B) in the
;  word table at 0xB473, then writes sprite-attribute entries into the actor's
;  0x20-offset block, adding the actor position (ix+3 = X, ix+5 = Y).  A leading
;  stream code 0x80/0x81/0x82 selects a fixed (dx,dy) offset list for multi-part
;  sprites; otherwise the stream carries explicit offsets.  Restores seg 3.
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
	ld de,0b473h           ; word table of shape streams (in seg6)
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
	defw event_dracula_sparks  ; 2  sub_6856h; CE02 = 0x78
	defw event_dracula_quiet   ; 3  wait CE02 and C800==0, play_sound 0
	defw event_dracula_theme   ; 4  BGM 0x88, bar=0x80, falls into l662dh
	defw event_dracula_rise    ; 5  sub_68cbh until CE36==2
	defw event_dracula_fork    ; 6  branch on CE15
	defw event_dracula_drop    ; 7  sub_68afh; BGM 0x8D, timer 0xB4
	defw event_dracula_wait2   ; 8  count CE02; 0x6A03
	defw event_dracula_fade    ; 9  sub_6a15h; 0x47B8/0x4805, timer 8
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
event_dracula_sparks:
	xor a
	ld (0ce12h),a
	call sub_6856h
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
	jp event_ce01_next
event_dracula_rise:
	call sub_68cbh
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
	jp event_ce01_next
event_dracula_drop:
	call sub_68afh
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
	call sub_6a15h
	ret nz                 ; sub_6a15h still working -> stay
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
;  live in seg8 (0xBF20) and seg5 (0x82C0); see credits_ending.asm /
;  credits_staff.asm.
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
;  of roll (CE32=1, play_sound 0xFF).  Else blit via l4adch: C=0xFF so
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
	jp palette_set
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
	ld de,00000h
	ld a,006h
	jp palette_set
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
	defw l6883h            ; 0/2  wait CE37, then CE35++
	defw l688dh            ; 1  sub_68afh until CE36=0
	defw l6883h
	defw l689ch            ; 3  sub_68cbh until CE36=2, reset
l6883h:
	ld hl,0ce37h
	dec (hl)
	ret nz
l6888h:
	ld hl,0ce35h
	inc (hl)
	ret
l688dh:
	call sub_68afh
	ld a,(0ce36h)
	and a
	ret nz
	ld a,040h
	ld (0ce37h),a
	jr l6888h
l689ch:
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
	call vdp_hmmm
	ld hl,0a0a0h
	ld de,08080h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,050a0h
	ld de,l7090h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,090a0h
	ld de,08090h
	ld bc,01010h
	ld a,001h
	jp vdp_hmmm
sub_691bh:
	ld hl,040a0h
	ld de,07080h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,080a0h
	ld de,08080h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,050a0h
	ld de,l7090h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,090a0h
	ld de,08090h
	ld bc,01010h
	ld a,001h
	jp vdp_hmmm
l6953h:
	ld hl,060a0h
	ld de,07080h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,0a0a0h
	ld de,08080h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,l70a0h
	ld de,l7090h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,0b0a0h
	ld de,08090h
	ld bc,01010h
	ld a,001h
	jp vdp_hmmm
sub_698bh:
	ld hl,000a0h
	ld de,l6858h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,010a0h
	ld de,08858h
	ld bc,01010h
	ld a,001h
	jp vdp_hmmm
l69a7h:
	ld hl,020a0h
	ld de,l6858h
	ld bc,01010h
	ld a,001h
	call vdp_hmmm
	ld hl,030a0h
	ld de,08858h
	ld bc,01010h
	ld a,001h
	jp vdp_hmmm
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
	call lookup_word_tbl
	call actor_set_yvel
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	call actor_set_xvel
	jp lookup_word_tbl
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
	ld bc,00020h
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
	call palette_set
	ld a,(0ce13h)
	and a
	ret
	ld (ix+00eh),005h
	ld (ix+006h),000h
tick_nop:
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
	call actor_set_yvel
	ld hl,0cf32h
	inc (hl)
	ld a,(hl)
	and 007h
	ld de,l6a93h
	call lookup_word_tbl
	ld a,(0c427h)
	sub (ix+005h)
	call c,neg_de
	jp actor_set_xvel
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
	call nz,actor_add_yvel
	ld a,(ix+001h)
	call DISPATCH_A
	defw l6abeh
	defw l6aceh
	defw l6ae6h
	defw l6af2h
	defw sub_6b00h
l6abeh:
	dec (ix+00ch)
	ret nz
	ld (ix+00bh),0a5h
	ld (ix+00ch),008h
	inc (ix+001h)
	ret
l6aceh:
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
l6ae6h:
	dec (ix+00ch)
	ret nz
	ld (ix+00ch),018h
	inc (ix+001h)
	ret
l6af2h:
	ld a,(ix+011h)
	call sub_6b00h
	dec (ix+00ch)
	ret nz
	inc (ix+001h)
	ret
sub_6b00h:
	ld a,(ix+011h)
	jp 0b164h
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
	call sub_75c7h
	call sub_75e9h
	call sub_75f9h
	call sub_75dbh
	call sub_760bh
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
	call 0852bh
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
	ld de,00000h
	ld (0c42eh),de         ; walk anim frames (legs, torso)
	call simon_mirror_frames
	ld a,(0c007h)          ; held: 0=UP 1=DOWN 2=LEFT 3=RIGHT
	rra
	jr c,l6be1h            ; UP -> maybe mount stairs
l6b8ah:
	rra
	jp c,l6c17h            ; DOWN held -> crouch (or down-stairs)
	rra
	push af
	call c,simon_walk_left
	pop af
	rra
	call c,simon_walk_right
	ld a,(0c006h)
	and 020h               ; UP new-press (jump; same bit as portal)
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
l6be1h:                        ; UP while grounded: try stairs
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
	call sub_7c0ch
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
	call sub_7bb0h
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
	call nz,sub_6bb6h
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
	ld de,00000h
	ld (0c42eh),de
	xor a
	ld (0c435h),a
	ld (0c42bh),a
	call simon_mirror_frames
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
simon_fall:                    ; 4 (0x6F44)
	ld a,(0c439h)
	and a
	jr nz,l6f71h
	call sub_7b8fh
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
l701eh:
	call simon_walk_right
	jp l6fdeh
l7024h:
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
sub_70e3h:
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
	call sub_711dh
	call whip_tick
	jp projectile_tick
sub_711dh:
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
	jr z,l7213h
	cp 002h
	ld a,000h
	jr nz,l7210h
	ld a,006h
l7210h:
	ld (0c42eh),a
l7213h:                        ; set torso frame 0xC42F from weapon 0xC436
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
	jp simon_mirror_frames
projectile_arm:                ; (0x728D) whip-phase 4: copy C436 into a waiting slot
	call actors_rearm_hittable
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
; (Y += 2*l7084h[phase], land via map_solid_pair tile_is_solid).  State 3 = pool
; (24 frames, SAT colour 8).
holy_water_tick:
	ld a,(ix+000h)
	dec a
	dec a
	jr z,holy_water_arc    ; state 2
	dec a
	jr z,holy_water_pool   ; state 3
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
holy_water_arc:                ; (0x73E5) Y += 2*l7084h[ix+7]; land -> pool
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
holy_water_pool:               ; (0x7420) 0x18 frames on the floor, then despawn
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
	ret nz                 ; type 5 state 3 = holy-water pool: SAT colour 8
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
sub_75c7h:
	ld hl,0c440h
	call sub_75d6h
	ld hl,0c434h
	call sub_75d6h
	ld hl,0c42dh
; sub_75d6h: dec (hl) unless already 0.
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
	jp play_sound
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
	jp play_sound
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
	jr c,l76abh            ; on stairs & near top -> up exit
l769dh:
	cp 0e1h
	jr nc,l76c3h           ; past bottom -> down exit
	ld a,(bc)              ; A = X
	cp 008h
	jr c,l7709h            ; past left -> left exit (if permitted)
	cp 0f8h
	jr nc,l7714h           ; past right -> right exit (if permitted)
	ret
l76abh:                        ; top edge (climbing off the top of a stairway)
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
l76c3h:                        ; past the bottom edge
	ld a,(0c41dh)          ; down exit permit
	inc a
	jr nz,l76efh           ; there IS a room below -> normal down transition
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
l76efh:                        ; room below exists -> down transition
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
l7709h:                        ; left edge
	ld a,(0c41eh)          ; left exit permit
	inc a
	ret z                  ; 0xFF = blocked -> no horizontal room here
	ld a,0f6h
	ld (bc),a              ; wrap X to right side of the new room
	ld (hl),003h           ; pending dir = 3 (left)
	ret
l7714h:                        ; right edge
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
	call sub_780dh
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
; simon_sat_build (seg1 0x783E): emit Simon's hardware-sprite SAT from
; 0xC42E/0xC42F via simon_sat_cell0/1.  Hides unused slots (Y=0xE0);
; sub_7913h applies gem/ring flash colours.
simon_sat_build:
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
	call sub_78a0h
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
	call 04911h            ; VDP HMMV
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
	call 04b24h
	call 04b56h
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
sub_7b6fh:
	ld a,(0c425h)
	add a,007h
	ld e,a
	ld a,(0c427h)
	ld d,a
	call map_cell_at
	jp tile_is_solid
sub_7b7fh:
	ld a,(0c425h)
	sub 02ch
	ld e,a
	ld a,(0c427h)
	ld d,a
	call map_cell_at
	jp tile_is_solid
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
; map_solid_pair (seg1 0x7B9F): carry if the tile at (D,E) or (D-10,E) is solid.
; Enemy floor test (feet + 10px toward the other side).
map_solid_pair:
	call map_cell_at
	call tile_is_solid
	ret c
	ld a,d
	sub 00ah
	ld d,a
	call map_cell_at
	jp tile_is_solid
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
; pending (0xC41B).  Whip (C416<2) vs projectile (C416>=2), then
; projectile_hit_actors and yellow_shield_tick.
combat_tick:
	ld a,(0c41bh)
	and a
	ret nz
	call sub_7e6eh
	call sub_7eebh
	call sub_7fe9h
	call hurt_simon_projectile
	ld a,(0c416h)
	cp 002h
	jr nc,l7d92h           ; C416>=2: projectile weapons
	call sub_7db4h         ; whip vs C800 actors (phase 3)
	call sub_7f50h
	call sub_7fbeh
	jr l7d95h
l7d92h:
	call sub_7da7h         ; busy-wait pad (projectile path)
l7d95h:
	call projectile_hit_actors
	call sub_7f80h
	call 080adh
	call 080e3h
	call 08122h
	jp yellow_shield_tick
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
	jp 09a45h
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
	jr z,l7e1eh
	rla
	ret nc
l7e1eh:
	ld a,014h
	ld (0c445h),a
	ld a,01ch
	call play_sound
	call award_kill_score
	ld a,001h
	ld (0ce15h),a
	jp sub_780dh
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
	jp 09a45h
l7eb7h:
	ld a,(0c434h)
	and a
	jr z,l7ec8h
	call award_kill_score
	call 09a45h
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
	call shot_vs_whip
	jr nc,l7f77h
	ld a,00ch
	call play_sound
	call add_score_100
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
	call pickup_vs_simon
	pop hl
	jr nc,$+30

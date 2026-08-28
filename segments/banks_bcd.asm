; ===========================================================================
;  banks b-d - 24K map window @ 0x6000-0xBFFF (page_map_banks).
;  Bank 11 at 0x6000 (metatile streams), bank 12 at 0x8000 (defs),
;  bank 13 at 0xA000 (sprite RLE, conn_lookup, doors).  Labels are unique
;  vs the play window (same CPU addresses, different banks).
;  Regen bank 13: tools/workbench/msx/regen-bank.sh 13 0xA000 segments/banks_bcd.blocks
; ===========================================================================

	INCLUDE "data/mtile_index.asm"

; mtile_stream_intro (seg11 0x614B): 8x6 metatile ids used when 0xC41A != 0
; (room_map_build takes this instead of mtile_roomptr[index]).
	INCLUDE "data/mtile_stream_intro.asm"

; Packed 8x6 streams for every room, index order, 48 bytes each.
	INCLUDE "data/mtile_streams.asm"

	INCLUDE "data/mtile_defbase.asm"

	INCLUDE "data/mtile_defs_s00.asm"

; ===========================================================================
;  SEGMENT 12 - bank 0x0C at 0x8000 (8K into this PHASE; s00 already crossed).
;  Per-stage 4x4 metatile definition tables.
; ===========================================================================

	INCLUDE "data/mtile_defs_s01.asm"
	INCLUDE "data/mtile_defs_s04.asm"
	INCLUDE "data/mtile_defs_s07.asm"
	INCLUDE "data/mtile_defs_s10.asm"
	INCLUDE "data/mtile_defs_s13.asm"
	INCLUDE "data/mtile_defs_s16.asm"
; Stage 18 metatile defs (88 x 16 bytes).  Crosses 0xA000 (seg12 into seg13).
	INCLUDE "data/mtile_defs_s18.asm"

; ===========================================================================
;  SEGMENT 13 - bank 0x0D at 0xA000 (16K into this PHASE; s18 already crossed).
;  Sprite RLE, conn_lookup, doors.  Regen: tools/workbench/msx/regen-bank.sh 13 0xA000 segments/banks_bcd.blocks
; ===========================================================================

; --- 0xA041-0xB962: intro defs + sprite RLE --------------------------------
;  Landmarks: 0xA041 = mtile_def_intro (room_map_build when 0xC41A != 0); 0xA281 /
;  0xA2D1 = Simon cell pointer tables (below); 0xA319 = packed sprite RLE
;  (intro_simon + in-game frames); 0xB5A1-0xB894 figure Dracula 32x32 body;
;  0xB895 = intro_sky; 0xBBF6 = title_jp_sprites; 0xBE59 = logo_font.
	INCLUDE "data/mtile_def_intro.asm"

; Packed sprite RLE 0xA319-0xB5A1 (intro_simon_0..7 + cell streams + 6 orphan planes).
	INCLUDE "data/simon_rle.asm"
	INCLUDE "data/dracula_body.asm"
	INCLUDE "data/intro_sky.asm"

; ---------------------------------------------------------------------------
;  conn_lookup (seg13 0xB963) - room-transition BRAIN.
;  Pending dir 0xC41B is dir_up..dir_right (from room_edge_detect / l77d8h).
;  Looks up conn_ptr[stage][room], picks the matching nibble, writes 0xD001.
;  0xF = blocked -> return without carry (state_room_trans treats that as death).
;  0xC41B == dir_portal (simon_portal_wait after crouch+UP on a pad) skips the
;  nibble and writes 0xD001 from 0xC5B4 (filled by spot_load_coords).
;  state_play treats any nonzero C41B as a pending exit (dir_* or dir_portal).
; ---------------------------------------------------------------------------
conn_lookup:
	ld a,(exit_dir)
	inc a
	jr z,conn_from_spot    ; dir_portal -> use 0xC5B4
	call conn_room_record  ; HL -> 2-byte record for D000/D001
	ld de,exit_dir
	ld a,(de)
	ld b,a
	xor a
	ld (de),a              ; consume pending dir
	dec b                  ; 0=up 1=down 2=left 3=right
	bit 1,b
	jr z,conn_pick_byte    ; up/down = first byte
	inc hl                 ; left/right = second byte
conn_pick_byte:
	bit 0,b
	ld a,(hl)
	jr nz,conn_nibble      ; down/right = low nibble
	rrca
	rrca
	rrca
	rrca                   ; up/left = high nibble
conn_nibble:
	and 00fh
	cp 00fh
	ret z                  ; blocked (0xF): NC, D001 unchanged
conn_write_room:
	ld (room),a          ; destination room
	scf
	ret
conn_from_spot:
	xor a
	ld (exit_dir),a
	ld a,(0c5b4h)          ; dest room from spot_tbl high nibble
	jr conn_write_room

; Banked ADD_HL_A (seg13 0xB995).  Same bytes as resident ADD_HL_A; this copy
; exists because the 0x4000 bank is not visible while we are paged at 0xA000.
add_hl_a_s13:
	add a,l
	ld l,a
	ret nc
	inc h
	ret

; conn_load_permits (seg13 0xB99A): unpack the 4 nibbles into 0xC41C-0xC41F
; (up/down/left/right).  0xF becomes 0xFF so edge tests can `inc a; jr z`.
conn_load_permits:
	call conn_room_record
	ld de,permit_up
	ld b,004h
conn_permit_loop:
	ld a,(hl)
	bit 0,b
	jr nz,conn_permit_lo   ; B odd (down/right) = low nibble
	rrca
	rrca
	rrca
	rrca
conn_permit_lo:
	and 00fh
	cp 00fh
	jr nz,conn_permit_store
	ld a,0ffh              ; blocked edge -> 0xFF sentinel
conn_permit_store:
	ld (de),a
	inc de
	bit 0,b
	jr z,conn_permit_next  ; after a high nibble, stay on this byte
	inc hl                 ; after a low nibble, next byte
conn_permit_next:
	djnz conn_permit_loop
	ret

; conn_room_record (seg13 0xB9BD): HL = conn_ptr[D000] + 2*D001.
conn_room_record:
	ld a,(stage)
	ld hl,conn_ptr
	add a,a
	call add_hl_a_s13
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld a,(room)
	add a,a
	call add_hl_a_s13
	ret

	INCLUDE "data/conn_tbl.asm"

door_load:
	call door_load_coords
	jp spot_load_coords

; door_load_coords (seg13 0xBB37): if D001 == door_tbl[D000].room (low nibble),
; write Y,X to C5AD,C5AE (ld (C5AD),hl with L=Y H=X) and arm C5AC
; (0xFF if byte0 bit7 / vertical blit; 0x04 courtyard / open doorway).
door_load_coords:
	ld a,(stage)
	ld hl,door_tbl
	ld b,a
	add a,a
	add a,b                ; stage * 3
	call add_hl_a_s13
	ld a,(hl)
	ld b,a
	and 00fh
	ld c,a                 ; room nibble
	ld a,(room)
	cp c
	ret nz                 ; this room has no door
	inc hl
	ld a,(hl)              ; Y
	inc hl
	ld h,(hl)              ; X
	ld l,a
	ld (door_y),hl         ; C5AD=Y, C5AE=X
	ld a,b
	add a,a                ; bit7 -> carry (vertical)
	ld a,0ffh
	jr c,door_arm_c5ac
	ld a,004h              ; courtyard / open
door_arm_c5ac:
	ld (door_state),a
	ret

	INCLUDE "data/door_tbl.asm"

; spot_load_coords (seg13 0xBB9A): scan spot_tbl for (D000, D001).  On match
; arm C5B1=1, store Y,X at C5B2 (same L=Y H=X as the door), and the dest-room
; nibble at C5B4 (consumed by conn_from_spot when C41B==dir_portal).  Current table
; is stage 12 only; pairs are two-way (0<->3, 1<->4, 2<->11, 5<->8, 7<->10).
spot_load_coords:
	ld de,(stage)         ; E=stage D000, D=room D001
	ld hl,spot_tbl
spot_scan:
	ld a,(hl)
	inc a
	ret z                  ; 0xFF terminator
	inc hl
	dec a
	cp e                   ; stage match?
	jr nz,spot_skip
	ld a,(hl)
	ld c,a
	and 00fh
	cp d                   ; room match?
	jr z,spot_found
spot_skip:
	inc hl
	inc hl
	inc hl
	jr spot_scan
spot_found:
	inc hl
	ld a,(hl)              ; Y
	inc hl
	ld h,(hl)              ; X
	ld l,a
	ld (0c5b2h),hl         ; C5B2=Y, C5B3=X
	ld a,001h
	ld (0c5b1h),a          ; armed (spot_proximity tests this)
	ld a,c
	rrca
	rrca
	rrca
	rrca
	and 00fh
	ld (0c5b4h),a          ; dest room for conn_from_spot
	ret

	INCLUDE "data/spot_tbl.asm"

	INCLUDE "data/title_jp_sprites.asm"
	INCLUDE "data/font_logo.asm"

    ASSERT $ == 0xC000

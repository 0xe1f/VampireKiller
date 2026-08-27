; ===========================================================================
;  banks b-d - 24K map window @ 0x6000-0xBFFF (page_map_banks).
;  Bank 11 at 0x6000 (metatile streams), bank 12 at 0x8000 (defs),
;  bank 13 at 0xA000 (sprite RLE, conn_lookup, doors).  Labels are unique
;  vs the play window (same CPU addresses, different banks).
;  Regen bank 13: tools/regen-seg.sh 13 0xA000 segments/seg13.blocks
; ===========================================================================

; mtile_rowbase (seg11 0x6000): byte[stage] = first room index for that stage.
; rooms-in-stage = rowbase[n+1]-rowbase[n] for stages 0..17.  Stage 18's next
; byte is the low byte of mtile_roomptr (delta -23); its count is 10 from
; minimap_room_count.  19 bytes covering stages 0..18.
mtile_rowbase:
	defb 000h,003h,00bh,011h,017h,01dh,023h,029h,032h,03ah,043h,04ch,052h,05eh,06ah,072h,07ch,086h,092h

; mtile_roomptr (seg11 0x6013): word[index] -> 48-byte metatile stream.
; 156 rooms (stages 0..17 = 146, stage 18 = 10), packed immediately after
; mtile_stream_c41a.  room_map_build: index = rowbase[D000]+D001.
mtile_roomptr:
	defw 0617bh,061abh,061dbh,0620bh,0623bh,0626bh,0629bh,062cbh
	defw 062fbh,0632bh,0635bh,0638bh,063bbh,063ebh,0641bh,0644bh
	defw 0647bh,064abh,064dbh,0650bh,0653bh,0656bh,0659bh,065cbh
	defw 065fbh,0662bh,0665bh,0668bh,066bbh,066ebh,0671bh,0674bh
	defw 0677bh,067abh,067dbh,0680bh,0683bh,0686bh,0689bh,068cbh
	defw 068fbh,0692bh,0695bh,0698bh,069bbh,069ebh,06a1bh,06a4bh
	defw 06a7bh,06aabh,06adbh,06b0bh,06b3bh,06b6bh,06b9bh,06bcbh
	defw 06bfbh,06c2bh,06c5bh,06c8bh,06cbbh,06cebh,06d1bh,06d4bh
	defw 06d7bh,06dabh,06ddbh,06e0bh,06e3bh,06e6bh,06e9bh,06ecbh
	defw 06efbh,06f2bh,06f5bh,06f8bh,06fbbh,06febh,0701bh,0704bh
	defw 0707bh,070abh,070dbh,0710bh,0713bh,0716bh,0719bh,071cbh
	defw 071fbh,0722bh,0725bh,0728bh,072bbh,072ebh,0731bh,0734bh
	defw 0737bh,073abh,073dbh,0740bh,0743bh,0746bh,0749bh,074cbh
	defw 074fbh,0752bh,0755bh,0758bh,075bbh,075ebh,0761bh,0764bh
	defw 0767bh,076abh,076dbh,0770bh,0773bh,0776bh,0779bh,077cbh
	defw 077fbh,0782bh,0785bh,0788bh,078bbh,078ebh,0791bh,0794bh
	defw 0797bh,079abh,079dbh,07a0bh,07a3bh,07a6bh,07a9bh,07acbh
	defw 07afbh,07b2bh,07b5bh,07b8bh,07bbbh,07bebh,07c1bh,07c4bh
	defw 07c7bh,07cabh,07cdbh,07d0bh,07d3bh,07d6bh,07d9bh,07dcbh
	defw 07dfbh,07e2bh,07e5bh,07e8bh

; mtile_stream_c41a (seg11 0x614B): 8x6 metatile ids used when 0xC41A != 0
; (room_map_build takes this instead of mtile_roomptr[index]).
	INCLUDE "data/mtile_stream_c41a.asm"

; Packed 8x6 streams for every room, index order, 48 bytes each.
	INCLUDE "data/mtile_streams.asm"

; mtile_defbase (seg11 0x7EBB): word[stage] -> 4x4 metatile-def table.
; Address window selects the bank: 0x6000=seg11, 0x8000=seg12, 0xA000=seg13.
; Tables can straddle the 0x8000/0xA000 boundary (roomperm treats 0x0B/0C/0D
; as one 0x6000-0xBFFF buffer).
mtile_defbase:
	defw 07ee1h,080b1h,080b1h,080b1h,084d1h,084d1h,084d1h,08791h
	defw 08791h,08791h,08d21h,08d21h,08d21h,09121h,09121h,09121h
	defw 09651h,09651h,09ac1h

; Stage 0 metatile defs (29 x 16 bytes), straddling into seg12 at 0x80B1.
	INCLUDE "data/mtile_defs_s00_a.asm"

; ===========================================================================
;  SEGMENT 12 - bank 0x0C at 0x8000 (8K into this PHASE).
;  Per-stage 4x4 metatile definition tables.
; ===========================================================================

; Tail of stage 0 defs (body starts at mtile_defbase[0] = 0x7EE1 in seg11).
	INCLUDE "data/mtile_defs_s00_b.asm"

	INCLUDE "data/mtile_defs_s01.asm"
	INCLUDE "data/mtile_defs_s04.asm"
	INCLUDE "data/mtile_defs_s07.asm"
	INCLUDE "data/mtile_defs_s10.asm"
	INCLUDE "data/mtile_defs_s13.asm"
	INCLUDE "data/mtile_defs_s16.asm"
	INCLUDE "data/mtile_defs_s18_a.asm"

; ===========================================================================
;  SEGMENT 13 - bank 0x0D at 0xA000 (16K into this PHASE).
;  Sprite RLE, conn_lookup, doors.  Regen: tools/regen-seg.sh 13 0xA000 segments/seg13.blocks
; ===========================================================================

; --- 0xA000-0xB962: metatile defs + sprite RLE -----------------------------
;  0xA000-0xA040 = tail of stage-18 defs (body at mtile_defs_s18 in seg12).
;  Landmarks: 0xA041 = mtile_def_c41a (room_map_build when 0xC41A != 0); 0xA281 /
;  0xA2D1 = Simon cell pointer tables (below); 0xA319 = packed sprite RLE
;  (intro_simon + in-game frames); 0xB5A1-0xB894 figure Dracula 32x32 body;
;  0xB895 = intro_sky; 0xBBF6 = title_jp_sprites; 0xBE59 = logo_font.
	INCLUDE "data/mtile_defs_s18_b.asm"
	INCLUDE "data/mtile_def_c41a.asm"

; simon_cell0_ptr (seg13 0xA281): 40 words, indexed by 0xC42E (legs).
; Consumed by load_simon_sprites; streams catalogued in gfx/sprites/simon_rle.png.
simon_cell0_ptr:
	defw 0acd1h,0ad4eh,0adc3h,0afb4h
	defw 0b026h,0b09bh,0b171h,0b1ffh
	defw 0b24bh,0b2bch,0a3cah,0a447h
	defw 0a4bch,0a6adh,0a720h,0a795h
	defw 0a869h,0a8f4h,0a941h,0a9b1h
	defw 0aebch,0aefdh,0af36h,0b0ceh
	defw 0b105h,0b13eh,0b19eh,0b1ffh
	defw 0b24bh,0b2bch,0a5b5h,0a5f6h
	defw 0a62fh,0a7c7h,0a7feh,0a837h
	defw 0a895h,0a8f4h,0a941h,0a9b1h

; simon_cell1_ptr (seg13 0xA2D1): 36 words, indexed by 0xC42F (torso/whip).
; Consumed by load_simon_sprites; streams catalogued in gfx/sprites/simon_rle.png.
simon_cell1_ptr:
	defw 0ac93h,0ad12h,0ad87h,0b1cch
	defw 0b235h,0b28ah,0b2edh,0b34ah
	defw 0b392h,0b3fbh,0b46bh,0b4beh
	defw 0b2edh,0b52dh,0b556h,0a38ch
	defw 0a40bh,0a480h,0a8c1h,0a92bh
	defw 0a980h,0a9e2h,0aa3fh,0aa87h
	defw 0aaeeh,0ab60h,0abb4h,0a9e2h
	defw 0ac21h,0ac4ch,0ae05h,0ae43h
	defw 0ae80h,0a4feh,0a53ch,0a579h

; Packed sprite RLE 0xA319-0xB5A1 (intro_simon_0..7 + cell streams + 6 orphan planes).
	INCLUDE "data/simon_rle.asm"
	INCLUDE "data/dracula_body.asm"
	INCLUDE "data/intro_sky.asm"

; ---------------------------------------------------------------------------
;  conn_lookup (seg13 0xB963) - room-transition BRAIN.
;  Pending dir 0xC41B is 1=up 2=down 3=left 4=right (from room_edge_detect / l77d8h).
;  Looks up conn_ptr[stage][room], picks the matching nibble, writes 0xD001.
;  0xF = blocked -> return without carry (state_room_trans treats that as death).
;  0xC41B == 0xFF (simon_portal_wait after crouch+UP on a pad) skips the
;  nibble and writes 0xD001 from 0xC5B4 (filled by spot_load_coords).
;  state_play treats any nonzero C41B as a pending exit (1-4 or 0xFF).
; ---------------------------------------------------------------------------
conn_lookup:
	ld a,(0c41bh)
	inc a
	jr z,conn_from_spot    ; was 0xFF -> use 0xC5B4
	call conn_room_record  ; HL -> 2-byte record for D000/D001
	ld de,0c41bh
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
	ld (0d001h),a          ; destination room
	scf
	ret
conn_from_spot:
	xor a
	ld (0c41bh),a
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
	ld de,0c41ch
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
	ld a,(0d000h)
	ld hl,conn_ptr
	add a,a
	call add_hl_a_s13
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld a,(0d001h)
	add a,a
	call add_hl_a_s13
	ret

conn_ptr:                        ; (seg13 0xB9D3) word[stage] -> conn_sNN
	defw conn_s00
	defw conn_s01
	defw conn_s02
	defw conn_s03
	defw conn_s04
	defw conn_s05
	defw conn_s06
	defw conn_s07
	defw conn_s08
	defw conn_s09
	defw conn_s10
	defw conn_s11
	defw conn_s12
	defw conn_s13
	defw conn_s14
	defw conn_s15
	defw conn_s16
	defw conn_s17
	defw conn_s18

; --- stage 0 (3 rooms) ---
conn_s00:
	defb 0ffh,0f1h         ; 0:  U=F D=F L=F R=1
	defb 0ffh,002h         ; 1:  U=F D=F L=0 R=2
	defb 0ffh,01fh         ; 2:  U=F D=F L=1 R=F
; --- stage 1 (8 rooms) ---
conn_s01:
	defb 0ffh,031h         ; 0:  U=F D=F L=3 R=1
	defb 05fh,002h         ; 1:  U=5 D=F L=0 R=2
	defb 0ffh,013h         ; 2:  U=F D=F L=1 R=3
	defb 07fh,020h         ; 3:  U=7 D=F L=2 R=0
	defb 0ffh,0f5h         ; 4:  U=F D=F L=F R=5
	defb 0f1h,046h         ; 5:  U=F D=1 L=4 R=6
	defb 0ffh,057h         ; 6:  U=F D=F L=5 R=7
	defb 0f3h,06fh         ; 7:  U=F D=3 L=6 R=F
; --- stage 2 (6 rooms) ---
conn_s02:
	defb 024h,0f1h         ; 0:  U=2 D=4 L=F R=1
	defb 0f5h,00fh         ; 1:  U=F D=5 L=0 R=F
	defb 0f0h,033h         ; 2:  U=F D=0 L=3 R=3
	defb 0ffh,022h         ; 3:  U=F D=F L=2 R=2
	defb 00fh,0f5h         ; 4:  U=0 D=F L=F R=5
	defb 01fh,04fh         ; 5:  U=1 D=F L=4 R=F
; --- stage 3 (6 rooms) ---
conn_s03:
	defb 0f4h,031h         ; 0:  U=F D=4 L=3 R=1
	defb 0ffh,002h         ; 1:  U=F D=F L=0 R=2
	defb 0ffh,013h         ; 2:  U=F D=F L=1 R=3
	defb 0ffh,020h         ; 3:  U=F D=F L=2 R=0
	defb 00fh,0f5h         ; 4:  U=0 D=F L=F R=5
	defb 0ffh,0ffh         ; 5:  U=F D=F L=F R=F
; --- stage 4 (6 rooms) ---
conn_s04:
	defb 0ffh,021h         ; 0:  U=F D=F L=2 R=1
	defb 04fh,002h         ; 1:  U=4 D=F L=0 R=2
	defb 05fh,010h         ; 2:  U=5 D=F L=1 R=0
	defb 0f0h,0f4h         ; 3:  U=F D=0 L=F R=4
	defb 0f1h,035h         ; 4:  U=F D=1 L=3 R=5
	defb 0f2h,04fh         ; 5:  U=F D=2 L=4 R=F
; --- stage 5 (6 rooms) ---
conn_s05:
	defb 0ffh,01fh         ; 0:  U=F D=F L=1 R=F
	defb 0ffh,020h         ; 1:  U=F D=F L=2 R=0
	defb 05fh,0f1h         ; 2:  U=5 D=F L=F R=1
	defb 0ffh,04fh         ; 3:  U=F D=F L=4 R=F
	defb 0f1h,053h         ; 4:  U=F D=1 L=5 R=3
	defb 0f2h,0f4h         ; 5:  U=F D=2 L=F R=4
; --- stage 6 (6 rooms) ---
conn_s06:
	defb 03fh,01fh         ; 0:  U=3 D=F L=1 R=F
	defb 0ffh,020h         ; 1:  U=F D=F L=2 R=0
	defb 0ffh,0f1h         ; 2:  U=F D=F L=F R=1
	defb 0f0h,04fh         ; 3:  U=F D=0 L=4 R=F
	defb 0ffh,053h         ; 4:  U=F D=F L=5 R=3
	defb 0ffh,0ffh         ; 5:  U=F D=F L=F R=F
; --- stage 7 (9 rooms) ---
conn_s07:
	defb 0ffh,01fh         ; 0:  U=F D=F L=1 R=F
	defb 0ffh,020h         ; 1:  U=F D=F L=2 R=0
	defb 05fh,0f1h         ; 2:  U=5 D=F L=F R=1
	defb 0ffh,04fh         ; 3:  U=F D=F L=4 R=F
	defb 0ffh,053h         ; 4:  U=F D=F L=5 R=3
	defb 082h,0f4h         ; 5:  U=8 D=2 L=F R=4
	defb 0f3h,07fh         ; 6:  U=F D=3 L=7 R=F
	defb 0f4h,086h         ; 7:  U=F D=4 L=8 R=6
	defb 0f5h,0f7h         ; 8:  U=F D=5 L=F R=7
; --- stage 8 (8 rooms) ---
conn_s08:
	defb 0ffh,0f1h         ; 0:  U=F D=F L=F R=1
	defb 0ffh,002h         ; 1:  U=F D=F L=0 R=2
	defb 05fh,01fh         ; 2:  U=5 D=F L=1 R=F
	defb 0ffh,0f4h         ; 3:  U=F D=F L=F R=4
	defb 0f7h,03fh         ; 4:  U=F D=7 L=3 R=F
	defb 0f2h,0f6h         ; 5:  U=F D=2 L=F R=6
	defb 0f3h,057h         ; 6:  U=F D=3 L=5 R=7
	defb 0f4h,06fh         ; 7:  U=F D=4 L=6 R=F
; --- stage 9 (9 rooms) ---
conn_s09:
	defb 0ffh,0f1h         ; 0:  U=F D=F L=F R=1
	defb 0ffh,002h         ; 1:  U=F D=F L=0 R=2
	defb 0ffh,013h         ; 2:  U=F D=F L=1 R=3
	defb 0ffh,024h         ; 3:  U=F D=F L=2 R=4
	defb 0ffh,035h         ; 4:  U=F D=F L=3 R=5
	defb 068h,04fh         ; 5:  U=6 D=8 L=4 R=F
	defb 0f5h,0ffh         ; 6:  U=F D=5 L=F R=F
	defb 0ffh,0ffh         ; 7:  U=F D=F L=F R=F
	defb 05fh,07fh         ; 8:  U=5 D=F L=7 R=F
; --- stage 10 (9 rooms) ---
conn_s10:
	defb 0ffh,051h         ; 0:  U=F D=F L=5 R=1
	defb 06fh,002h         ; 1:  U=6 D=F L=0 R=2
	defb 0ffh,013h         ; 2:  U=F D=F L=1 R=3
	defb 0ffh,024h         ; 3:  U=F D=F L=2 R=4
	defb 0ffh,035h         ; 4:  U=F D=F L=3 R=5
	defb 08fh,040h         ; 5:  U=8 D=F L=4 R=0
	defb 0f1h,077h         ; 6:  U=F D=1 L=7 R=7
	defb 0ffh,066h         ; 7:  U=F D=F L=6 R=6
	defb 0f5h,0ffh         ; 8:  U=F D=5 L=F R=F
; --- stage 11 (6 rooms) ---
conn_s11:
	defb 0ffh,0f1h         ; 0:  U=F D=F L=F R=1
	defb 0ffh,002h         ; 1:  U=F D=F L=0 R=2
	defb 0ffh,013h         ; 2:  U=F D=F L=1 R=3
	defb 0ffh,024h         ; 3:  U=F D=F L=2 R=4
	defb 0ffh,035h         ; 4:  U=F D=F L=3 R=5
	defb 0ffh,04fh         ; 5:  U=F D=F L=4 R=F
; --- stage 12 (12 rooms) ---
conn_s12:
	defb 0ffh,021h         ; 0:  U=F D=F L=2 R=1
	defb 0ffh,002h         ; 1:  U=F D=F L=0 R=2
	defb 0ffh,010h         ; 2:  U=F D=F L=1 R=0
	defb 0ffh,0f4h         ; 3:  U=F D=F L=F R=4
	defb 0ffh,035h         ; 4:  U=F D=F L=3 R=5
	defb 0ffh,046h         ; 5:  U=F D=F L=4 R=6
	defb 0ffh,0ffh         ; 6:  U=F D=F L=F R=F
	defb 0ffh,088h         ; 7:  U=F D=F L=8 R=8
	defb 0ffh,077h         ; 8:  U=F D=F L=7 R=7
	defb 0ffh,0bah         ; 9:  U=F D=F L=11 R=10
	defb 0ffh,09bh         ; 10: U=F D=F L=9 R=11
	defb 0ffh,0a9h         ; 11: U=F D=F L=10 R=9
; --- stage 13 (12 rooms) ---
conn_s13:
	defb 03fh,0f1h         ; 0:  U=3 D=F L=F R=1
	defb 0ffh,002h         ; 1:  U=F D=F L=0 R=2
	defb 057h,01fh         ; 2:  U=5 D=7 L=1 R=F
	defb 0f0h,064h         ; 3:  U=F D=0 L=6 R=4
	defb 0ffh,035h         ; 4:  U=F D=F L=3 R=5
	defb 0f2h,046h         ; 5:  U=F D=2 L=4 R=6
	defb 0bfh,053h         ; 6:  U=11 D=F L=5 R=3
	defb 029h,0ffh         ; 7:  U=2 D=9 L=F R=F
	defb 0ffh,0f9h         ; 8:  U=F D=F L=F R=9
	defb 07fh,08ah         ; 9:  U=7 D=F L=8 R=10
	defb 0fbh,09fh         ; 10: U=F D=11 L=9 R=F
	defb 0a6h,09fh         ; 11: U=10 D=6 L=9 R=F
; --- stage 14 (8 rooms) ---
conn_s14:
	defb 03fh,0ffh         ; 0:  U=3 D=F L=F R=F
	defb 0ffh,02fh         ; 1:  U=F D=F L=2 R=F
	defb 0f5h,0f1h         ; 2:  U=F D=5 L=F R=1
	defb 0f0h,04fh         ; 3:  U=F D=0 L=4 R=F
	defb 0f1h,053h         ; 4:  U=F D=1 L=5 R=3
	defb 0ffh,064h         ; 5:  U=F D=F L=6 R=4
	defb 0ffh,075h         ; 6:  U=F D=F L=7 R=5
	defb 0ffh,0f6h         ; 7:  U=F D=F L=F R=6
; --- stage 15 (10 rooms) ---
conn_s15:
	defb 02fh,01fh         ; 0:  U=2 D=F L=1 R=F
	defb 0ffh,0f0h         ; 1:  U=F D=F L=F R=0
	defb 040h,033h         ; 2:  U=4 D=0 L=3 R=3
	defb 0ffh,022h         ; 3:  U=F D=F L=2 R=2
	defb 072h,055h         ; 4:  U=7 D=2 L=5 R=5
	defb 0f3h,044h         ; 5:  U=F D=3 L=4 R=4
	defb 0ffh,07fh         ; 6:  U=F D=F L=7 R=F
	defb 0f4h,086h         ; 7:  U=F D=4 L=8 R=6
	defb 0f5h,097h         ; 8:  U=F D=5 L=9 R=7
	defb 0ffh,0ffh         ; 9:  U=F D=F L=F R=F
; --- stage 16 (10 rooms) ---
conn_s16:
	defb 0f6h,01fh         ; 0:  U=F D=6 L=1 R=F
	defb 0f7h,020h         ; 1:  U=F D=7 L=2 R=0
	defb 0f8h,031h         ; 2:  U=F D=8 L=3 R=1
	defb 0f9h,042h         ; 3:  U=F D=9 L=4 R=2
	defb 0ffh,053h         ; 4:  U=F D=F L=5 R=3
	defb 0ffh,0f4h         ; 5:  U=F D=F L=F R=4
	defb 00fh,07fh         ; 6:  U=0 D=F L=7 R=F
	defb 0ffh,086h         ; 7:  U=F D=F L=8 R=6
	defb 0ffh,097h         ; 8:  U=F D=F L=9 R=7
	defb 0ffh,0f8h         ; 9:  U=F D=F L=F R=8
; --- stage 17 (12 rooms) ---
conn_s17:
	defb 03fh,01fh         ; 0:  U=3 D=F L=1 R=F
	defb 04fh,020h         ; 1:  U=4 D=F L=2 R=0
	defb 05fh,0f1h         ; 2:  U=5 D=F L=F R=1
	defb 0f0h,04fh         ; 3:  U=F D=0 L=4 R=F
	defb 0f1h,053h         ; 4:  U=F D=1 L=5 R=3
	defb 062h,0f4h         ; 5:  U=6 D=2 L=F R=4
	defb 095h,07fh         ; 6:  U=9 D=5 L=7 R=F
	defb 0afh,086h         ; 7:  U=10 D=F L=8 R=6
	defb 0bfh,0f7h         ; 8:  U=11 D=F L=F R=7
	defb 0f6h,0afh         ; 9:  U=F D=6 L=10 R=F
	defb 0f7h,0b9h         ; 10: U=F D=7 L=11 R=9
	defb 0f8h,0ffh         ; 11: U=F D=8 L=F R=F
; --- stage 18 (10 rooms) ---
conn_s18:
	defb 0ffh,01fh         ; 0:  U=F D=F L=1 R=F
	defb 0ffh,020h         ; 1:  U=F D=F L=2 R=0
	defb 03fh,0f1h         ; 2:  U=3 D=F L=F R=1
	defb 052h,0ffh         ; 3:  U=5 D=2 L=F R=F
	defb 065h,055h         ; 4:  U=6 D=5 L=5 R=5
	defb 043h,044h         ; 5:  U=4 D=3 L=4 R=4
	defb 074h,0ffh         ; 6:  U=7 D=4 L=F R=F
	defb 0f6h,08fh         ; 7:  U=F D=6 L=8 R=F
	defb 0ffh,097h         ; 8:  U=F D=F L=9 R=7
	defb 0ffh,0ffh         ; 9:  U=F D=F L=F R=F

; door_load (seg13 0xBB31): paged entry from door_load_paged (seg0 0x5A47).
; Loads the white-key door (C5AC-C5AE) then the C5B1 spot, if any.
door_load:
	call door_load_coords
	jp spot_load_coords

; door_load_coords (seg13 0xBB37): if D001 == door_tbl[D000].room (low nibble),
; write Y,X to C5AD,C5AE (ld (C5AD),hl with L=Y H=X) and arm C5AC
; (0xFF if byte0 bit7 / vertical blit; 0x04 courtyard / open doorway).
door_load_coords:
	ld a,(0d000h)
	ld hl,door_tbl
	ld b,a
	add a,a
	add a,b                ; stage * 3
	call add_hl_a_s13
	ld a,(hl)
	ld b,a
	and 00fh
	ld c,a                 ; room nibble
	ld a,(0d001h)
	cp c
	ret nz                 ; this room has no door
	inc hl
	ld a,(hl)              ; Y
	inc hl
	ld h,(hl)              ; X
	ld l,a
	ld (0c5adh),hl         ; C5AD=Y, C5AE=X
	ld a,b
	add a,a                ; bit7 -> carry (vertical)
	ld a,0ffh
	jr c,door_arm_c5ac
	ld a,004h              ; courtyard / open
door_arm_c5ac:
	ld (0c5ach),a
	ret

door_tbl:                        ; (seg13 0xBB61) 19x3: (room | vert<<7), Y, X
	defb 042h,090h,0e0h    ;  0: room 2 open Y=0x90 X=0xE0  byte0=0x42
	defb 087h,030h,0ech    ;  1: room 7 vert Y=0x30 X=0xEC
	defb 081h,030h,0ech    ;  2: room 1 vert Y=0x30 X=0xEC
	defb 084h,080h,0ech    ;  3: room 4 vert Y=0x80 X=0xEC
	defb 083h,030h,00ch    ;  4: room 3 vert Y=0x30 X=0x0C
	defb 085h,050h,00ch    ;  5: room 5 vert Y=0x50 X=0x0C
	defb 084h,050h,00ch    ;  6: room 4 vert Y=0x50 X=0x0C
	defb 086h,060h,0ech    ;  7: room 6 vert Y=0x60 X=0xEC
	defb 087h,040h,0ech    ;  8: room 7 vert Y=0x40 X=0xEC
	defb 088h,080h,00ch    ;  9: room 8 vert Y=0x80 X=0x0C
	defb 088h,080h,0ech    ; 10: room 8 vert Y=0x80 X=0xEC
	defb 085h,080h,0ech    ; 11: room 5 vert Y=0x80 X=0xEC
	defb 085h,080h,0ech    ; 12: room 5 vert Y=0x80 X=0xEC
	defb 088h,080h,00ch    ; 13: room 8 vert Y=0x80 X=0x0C
	defb 087h,080h,00ch    ; 14: room 7 vert Y=0x80 X=0x0C
	defb 088h,080h,00ch    ; 15: room 8 vert Y=0x80 X=0x0C
	defb 085h,040h,00ch    ; 16: room 5 vert Y=0x40 X=0x0C
	defb 08bh,040h,00ch    ; 17: room 11 vert Y=0x40 X=0x0C
	defb 088h,080h,00ch    ; 18: room 8 vert Y=0x80 X=0x0C

; spot_load_coords (seg13 0xBB9A): scan spot_tbl for (D000, D001).  On match
; arm C5B1=1, store Y,X at C5B2 (same L=Y H=X as the door), and the dest-room
; nibble at C5B4 (consumed by conn_from_spot when C41B==0xFF).  Current table
; is stage 12 only; pairs are two-way (0<->3, 1<->4, 2<->11, 5<->8, 7<->10).
spot_load_coords:
	ld de,(0d000h)         ; E=stage D000, D=room D001
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

spot_tbl:                        ; (seg13 0xBBCD) (stage, dest<<4|room, Y, X), 0xFF end
	defb 00ch,030h,0a8h,058h ; stage 12 room 0 dest=3 Y=0xA8 X=0x58
	defb 00ch,041h,088h,0b8h ; stage 12 room 1 dest=4 Y=0x88 X=0xB8
	defb 00ch,0b2h,0a8h,098h ; stage 12 room 2 dest=11 Y=0xA8 X=0x98
	defb 00ch,003h,0a8h,058h ; stage 12 room 3 dest=0 Y=0xA8 X=0x58
	defb 00ch,014h,088h,0b8h ; stage 12 room 4 dest=1 Y=0x88 X=0xB8
	defb 00ch,085h,0a8h,058h ; stage 12 room 5 dest=8 Y=0xA8 X=0x58
	defb 00ch,0a7h,0a8h,038h ; stage 12 room 7 dest=10 Y=0xA8 X=0x38
	defb 00ch,058h,0a8h,058h ; stage 12 room 8 dest=5 Y=0xA8 X=0x58
	defb 00ch,07ah,0a8h,038h ; stage 12 room 10 dest=7 Y=0xA8 X=0x38
	defb 00ch,02bh,0a8h,098h ; stage 12 room 11 dest=2 Y=0xA8 X=0x98
	defb 0ffh                ; end

; Japanese title sprites, then the boot Konami-logo 1bpp font.
	INCLUDE "data/title_jp_sprites.asm"
	INCLUDE "data/font_logo.asm"

    ASSERT $ == 0xC000

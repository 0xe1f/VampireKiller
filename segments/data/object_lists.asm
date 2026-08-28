; Packed per-hub enemy object lists (seg14 0x8668).  ids are actor_* (actors.inc); obj_next_room / obj_end_stream.


; object_list_ptr (seg14 0x8668): word[hub 0..5] -> packed object streams.
; object_list_lookup indexes by 0xD002. Each hub has 3 streams (0xFF-terminated) =
; the hub's 3 castle stages (stage 0 shares hub 0 but object_list_spawn skips it).
; 0x00 advances to the next room (obj_next_room). List-id = actor_* type
; (segments/actors.inc); bit7 stripped at spawn (dogs only: actor_dog|080h).
; Attr = Y<<4 | X, cell*16 px (same nibble order as scenery). object_list_spawn
; loads high->E (Y) and low->D (X) into spawn_actor.
object_list_ptr:
	defw object_list_h0,object_list_h1,object_list_h2,object_list_h3,object_list_h4,object_list_h5

; hub 0 = stages 1-3 (0x8674)
object_list_h0:
	; stage 1
	defb obj_next_room
	defb obj_next_room
	defb actor_dog,088h                 ; r2 (8,8)
	defb obj_next_room
	defb actor_dog|080h,046h            ; r3 (6,4)
	defb obj_next_room
	defb obj_next_room
	defb obj_next_room
	defb obj_next_room
	defb actor_dog|080h,06ch            ; r7 (12,6)
	defb obj_end_stream
	; stage 2
	defb obj_end_stream
	; stage 3
	defb actor_dog,087h                 ; r0 (7,8)
	defb obj_next_room
	defb actor_dog,088h                 ; r1 (8,8)
	defb actor_dog|080h,0abh            ; r1 (11,10)
	defb obj_next_room
	defb actor_placed_bat,067h          ; r2 (7,6)
	defb obj_end_stream

; hub 1 = stages 4-6 (0x868E)
object_list_h1:
	; stage 4
	defb actor_pikeman,0ceh             ; r0 (14,12)
	defb actor_pikeman,069h             ; r0 (9,6)
	defb obj_next_room
	defb actor_pikeman,0c8h             ; r1 (8,12)
	defb actor_pikeman,064h             ; r1 (4,6)
	defb actor_placed_bat,034h          ; r1 (4,3)
	defb obj_next_room
	defb actor_pikeman,0cbh             ; r2 (11,12)
	defb actor_pikeman,064h             ; r2 (4,6)
	defb obj_next_room
	defb actor_placed_bat,033h          ; r3 (3,3)
	defb obj_next_room
	defb actor_pikeman,0cah             ; r4 (10,12)
	defb actor_pikeman,0a6h             ; r4 (6,10)
	defb obj_end_stream
	; stage 5
	defb obj_next_room
	defb obj_next_room
	defb actor_pikeman,065h             ; r2 (5,6)
	defb obj_next_room
	defb actor_pikeman,06ah             ; r3 (10,6)
	defb actor_pikeman,0aah             ; r3 (10,10)
	defb obj_end_stream
	; stage 6
	defb obj_next_room
	defb obj_next_room
	defb actor_skull_pile,05ch          ; r2 (12,5)
	defb obj_end_stream

; hub 2 = stages 7-9 (0x86B6)
object_list_h2:
	; stage 7
	defb obj_next_room
	defb actor_hunchback,095h           ; r1 (5,9)
	defb actor_hunchback,09ah           ; r1 (10,9)
	defb obj_next_room
	defb actor_white_skeleton,0b9h      ; r2 (9,11)
	defb obj_next_room
	defb actor_white_skeleton,0cbh      ; r3 (11,12)
	defb obj_next_room
	defb actor_white_skeleton,0cdh      ; r4 (13,12)
	defb actor_hunchback,08bh           ; r4 (11,8)
	defb actor_hunchback,055h           ; r4 (5,5)
	defb obj_next_room
	defb actor_white_skeleton,093h      ; r5 (3,9)
	defb obj_next_room
	defb actor_white_skeleton,0b9h      ; r6 (9,11)
	defb obj_next_room
	defb actor_raven,057h               ; r7 (7,5)
	defb obj_next_room
	defb actor_raven,057h               ; r8 (7,5)
	defb obj_end_stream
	; stage 8
	defb obj_next_room
	defb obj_next_room
	defb actor_white_skeleton,05dh      ; r2 (13,5)
	defb obj_next_room
	defb actor_white_skeleton,099h      ; r3 (9,9)
	defb obj_next_room
	defb obj_next_room
	defb actor_raven,055h               ; r5 (5,5)
	defb obj_next_room
	defb actor_skull_pile,099h          ; r6 (9,9)
	defb actor_raven,0c5h               ; r6 (5,12)
	defb obj_next_room
	defb actor_white_skeleton,0c8h      ; r7 (8,12)
	defb obj_end_stream
	; stage 9
	defb obj_next_room
	defb actor_skull_pile,07ch          ; r1 (12,7)
	defb obj_next_room
	defb actor_skull_pile,075h          ; r2 (5,7)
	defb actor_skull_pile,07bh          ; r2 (11,7)
	defb obj_next_room
	defb obj_next_room
	defb actor_skull_pile,075h          ; r4 (5,7)
	defb actor_white_skeleton,07bh      ; r4 (11,7)
	defb obj_next_room
	defb actor_hunchback,075h           ; r5 (5,7)
	defb actor_hunchback,057h           ; r5 (7,5)
	defb obj_next_room
	defb actor_white_skeleton,054h      ; r6 (4,5)
	defb obj_next_room
	defb obj_next_room
	defb actor_white_skeleton,0b3h      ; r8 (3,11)
	defb actor_hunchback,057h           ; r8 (7,5)
	defb obj_end_stream

; hub 3 = stages 10-12 (0x8706)
object_list_h3:
	; stage 10
	defb obj_next_room
	defb obj_next_room
	defb obj_next_room
	defb obj_next_room
	defb obj_next_room
	defb obj_next_room
	defb actor_placed_merman,0b3h       ; r6 (3,11)
	defb actor_placed_merman,0bch       ; r6 (12,11)
	defb obj_next_room
	defb actor_placed_merman,0b8h       ; r7 (8,11)
	defb obj_next_room
	defb actor_placed_merman,0b3h       ; r8 (3,11)
	defb actor_placed_merman,0bdh       ; r8 (13,11)
	defb obj_end_stream
	; stage 11
	defb obj_next_room
	defb actor_hunchback,059h           ; r1 (9,5)
	defb obj_next_room
	defb actor_hunchback,077h           ; r2 (7,7)
	defb obj_next_room
	defb obj_next_room
	defb obj_next_room
	defb actor_bone_dragon,07dh         ; r5 (13,7)
	defb obj_end_stream
	; stage 12
	defb actor_bone_dragon,09ch         ; r0 (12,9)
	defb obj_next_room
	defb obj_next_room
	defb obj_next_room
	defb obj_next_room
	defb actor_bone_dragon,065h         ; r4 (5,6)
	defb obj_next_room
	defb actor_bone_dragon,07dh         ; r5 (13,7)
	defb obj_next_room
	defb obj_next_room
	defb actor_bone_dragon,096h         ; r7 (6,9)
	defb obj_next_room
	defb actor_bone_dragon,099h         ; r8 (9,9)
	defb obj_next_room
	defb obj_next_room
	defb actor_bone_dragon,09ah         ; r10 (10,9)
	defb obj_next_room
	defb actor_bone_dragon,09eh         ; r11 (14,9)
	defb obj_end_stream

; hub 4 = stages 13-15 (0x873F)
object_list_h4:
	; stage 13
	defb actor_white_skeleton,0bch      ; r0 (12,11)
	defb actor_red_skeleton,05ch        ; r0 (12,5)
	defb obj_next_room
	defb actor_white_skeleton,054h      ; r1 (4,5)
	defb actor_hunchback,07bh           ; r1 (11,7)
	defb obj_next_room
	defb actor_hunchback,055h           ; r2 (5,5)
	defb actor_hunchback,05ah           ; r2 (10,5)
	defb actor_hunchback,097h           ; r2 (7,9)
	defb actor_hunchback,0beh           ; r2 (14,11)
	defb obj_next_room
	defb actor_white_skeleton,056h      ; r3 (6,5)
	defb actor_white_skeleton,05ch      ; r3 (12,5)
	defb actor_hunchback,09dh           ; r3 (13,9)
	defb obj_next_room
	defb actor_white_skeleton,09ch      ; r4 (12,9)
	defb actor_red_skeleton,0b2h        ; r4 (2,11)
	defb obj_next_room
	defb actor_white_skeleton,05ch      ; r5 (12,5)
	defb actor_white_skeleton,077h      ; r5 (7,7)
	defb actor_hunchback,0b6h           ; r5 (6,11)
	defb actor_hunchback,0bch           ; r5 (12,11)
	defb obj_next_room
	defb actor_hunchback,057h           ; r6 (7,5)
	defb obj_next_room
	defb actor_white_skeleton,056h      ; r7 (6,5)
	defb actor_white_skeleton,0b4h      ; r7 (4,11)
	defb obj_next_room
	defb actor_red_skeleton,05bh        ; r8 (11,5)
	defb actor_red_skeleton,074h        ; r8 (4,7)
	defb actor_red_skeleton,0bah        ; r8 (10,11)
	defb obj_next_room
	defb actor_red_skeleton,055h        ; r9 (5,5)
	defb actor_red_skeleton,07ch        ; r9 (12,7)
	defb actor_red_skeleton,0b4h        ; r9 (4,11)
	defb actor_red_skeleton,0b7h        ; r9 (7,11)
	defb obj_next_room
	defb actor_white_skeleton,079h      ; r10 (9,7)
	defb actor_white_skeleton,0b4h      ; r10 (4,11)
	defb obj_next_room
	defb actor_hunchback,05ah           ; r11 (10,5)
	defb actor_hunchback,075h           ; r11 (5,7)
	defb actor_hunchback,0b6h           ; r11 (6,11)
	defb obj_end_stream
	; stage 14
	defb actor_axe_knight,07ch          ; r0 (12,7)
	defb obj_next_room
	defb actor_axe_knight,072h          ; r1 (2,7)
	defb actor_axe_knight,0bah          ; r1 (10,11)
	defb obj_next_room
	defb actor_axe_knight,0b9h          ; r2 (9,11)
	defb obj_next_room
	defb actor_red_skeleton,056h        ; r3 (6,5)
	defb actor_red_skeleton,05ch        ; r3 (12,5)
	defb actor_red_skeleton,0b2h        ; r3 (2,11)
	defb actor_red_skeleton,0bah        ; r3 (10,11)
	defb obj_next_room
	defb actor_axe_knight,059h          ; r4 (9,5)
	defb actor_axe_knight,0b4h          ; r4 (4,11)
	defb obj_next_room
	defb actor_axe_knight,0bah          ; r5 (10,11)
	defb obj_next_room
	defb actor_axe_knight,074h          ; r6 (4,7)
	defb actor_axe_knight,0bch          ; r6 (12,11)
	defb obj_next_room
	defb actor_axe_knight,058h          ; r7 (8,5)
	defb actor_axe_knight,0bdh          ; r7 (13,11)
	defb obj_end_stream
	; stage 15
	defb obj_next_room
	defb actor_axe_knight,058h          ; r1 (8,5)
	defb actor_axe_knight,0b5h          ; r1 (5,11)
	defb obj_next_room
	defb actor_axe_knight,055h          ; r2 (5,5)
	defb actor_axe_knight,0b5h          ; r2 (5,11)
	defb obj_next_room
	defb actor_axe_knight,0bch          ; r3 (12,11)
	defb obj_next_room
	defb actor_axe_knight,079h          ; r4 (9,7)
	defb actor_axe_knight,0b6h          ; r4 (6,11)
	defb obj_next_room
	defb obj_next_room
	defb actor_axe_knight,0bah          ; r6 (10,11)
	defb obj_next_room
	defb actor_axe_knight,0bah          ; r7 (10,11)
	defb obj_next_room
	defb actor_axe_knight,0bah          ; r8 (10,11)
	defb obj_end_stream

; hub 5 = stages 16-18 (0x87CE)
object_list_h5:
	; stage 16
	defb obj_next_room
	defb actor_giant_bat,0b8h           ; r1 (8,11)
	defb obj_next_room
	defb actor_giant_bat,097h           ; r2 (7,9)
	defb obj_next_room
	defb actor_giant_bat,098h           ; r3 (8,9)
	defb obj_next_room
	defb actor_giant_bat,0bah           ; r4 (10,11)
	defb obj_next_room
	defb obj_next_room
	defb obj_next_room
	defb actor_giant_bat,056h           ; r7 (6,5)
	defb obj_next_room
	defb actor_giant_bat,058h           ; r8 (8,5)
	defb obj_end_stream
	; stage 17
	defb obj_next_room
	defb actor_white_skeleton,0b6h      ; r1 (6,11)
	defb obj_next_room
	defb actor_hunchback,07eh           ; r2 (14,7)
	defb obj_next_room
	defb actor_axe_knight,076h          ; r3 (6,7)
	defb obj_next_room
	defb actor_axe_knight,05bh          ; r4 (11,5)
	defb actor_axe_knight,0bah          ; r4 (10,11)
	defb obj_next_room
	defb actor_axe_knight,053h          ; r5 (3,5)
	defb obj_next_room
	defb actor_hunchback,079h           ; r6 (9,7)
	defb actor_hunchback,0b9h           ; r6 (9,11)
	defb obj_next_room
	defb obj_next_room
	defb actor_hunchback,053h           ; r8 (3,5)
	defb obj_next_room
	defb actor_hunchback,055h           ; r9 (5,5)
	defb obj_end_stream
	; stage 18
	defb obj_next_room
	defb actor_axe_knight,056h          ; r1 (6,5)
	defb obj_next_room
	defb actor_axe_knight,095h          ; r2 (5,9)
	defb obj_next_room
	defb actor_hunchback,07dh           ; r3 (13,7)
	defb actor_hunchback,077h           ; r3 (7,7)
	defb obj_next_room
	defb actor_hunchback,077h           ; r4 (7,7)
	defb actor_hunchback,053h           ; r4 (3,5)
	defb obj_next_room
	defb actor_hunchback,05ah           ; r5 (10,5)
	defb actor_hunchback,054h           ; r5 (4,5)
	defb obj_next_room
	defb actor_hunchback,07bh           ; r6 (11,7)
	defb actor_hunchback,0b4h           ; r6 (4,11)
	defb obj_next_room
	defb actor_hunchback,079h           ; r7 (9,7)
	defb actor_hunchback,055h           ; r7 (5,5)
	defb obj_next_room
	defb actor_axe_knight,0b6h          ; r8 (6,11)
	defb obj_end_stream


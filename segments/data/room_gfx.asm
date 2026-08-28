; room_gfx_ptr (seg9 0x9AB0): word[stage-1] -> 4 bytes/room
; {gfx_script, palette}.  Stage 0 skips.  Walked by room_gfx_load.
room_gfx_ptr:
	defw room_gfx_s01  ; stage 1  8 rooms
	defw room_gfx_s02  ; stage 2  6 rooms
	defw room_gfx_s03  ; stage 3  6 rooms
	defw room_gfx_s04  ; stage 4  6 rooms
	defw room_gfx_s05  ; stage 5  6 rooms
	defw room_gfx_s06  ; stage 6  6 rooms
	defw room_gfx_s07  ; stage 7  9 rooms
	defw room_gfx_s08  ; stage 8  8 rooms
	defw room_gfx_s09  ; stage 9  9 rooms
	defw room_gfx_s10  ; stage 10  9 rooms
	defw room_gfx_s11  ; stage 11  6 rooms
	defw room_gfx_s12  ; stage 12  12 rooms
	defw room_gfx_s13  ; stage 13  12 rooms
	defw room_gfx_s14  ; stage 14  8 rooms
	defw room_gfx_s15  ; stage 15  10 rooms
	defw room_gfx_s16  ; stage 16  10 rooms
	defw room_gfx_s17  ; stage 17  12 rooms
	defw room_gfx_s18  ; stage 18  10 rooms

room_gfx_s01:  ; 0x9AD4  stage 1
	defw gfx_script_9d38, pal_9ffe  ; r0
	defw gfx_script_9d38, pal_9ffe  ; r1
	defw gfx_script_9d4e, pal_a005  ; r2
	defw gfx_script_9d4e, pal_a005  ; r3
	defw gfx_script_9d64, pal_a00c  ; r4
	defw gfx_script_9d38, pal_9ffe  ; r5
	defw gfx_script_9d38, pal_9ffe  ; r6
	defw gfx_script_9d4e, pal_a005  ; r7

room_gfx_s02:  ; 0x9AF4  stage 2
	defw gfx_script_9d64, pal_a00c  ; r0
	defw gfx_script_9d64, pal_a00c  ; r1
	defw gfx_script_9d38, pal_9ffe  ; r2
	defw gfx_script_9d64, pal_a00c  ; r3
	defw gfx_script_9d8a, pal_a013  ; r4
	defw gfx_script_9d8a, pal_a013  ; r5

room_gfx_s03:  ; 0x9B0C  stage 3
	defw gfx_script_9d4e, pal_a005  ; r0
	defw gfx_script_9d4e, pal_a005  ; r1
	defw gfx_script_9d64, pal_a00c  ; r2
	defw gfx_script_9d38, pal_9ffe  ; r3
	defw gfx_script_9d64, pal_a00c  ; r4
	defw gfx_script_9da5, pal_a00c  ; r5

room_gfx_s04:  ; 0x9B24  stage 4
	defw gfx_script_9de0, pal_a028  ; r0
	defw gfx_script_9db5, pal_a028  ; r1
	defw gfx_script_9de0, pal_a028  ; r2
	defw gfx_script_9db5, pal_a028  ; r3
	defw gfx_script_9de0, pal_a028  ; r4
	defw gfx_script_9de0, pal_a028  ; r5

room_gfx_s05:  ; 0x9B3C  stage 5
	defw gfx_script_9de0, pal_a028  ; r0
	defw gfx_script_9de0, pal_a028  ; r1
	defw gfx_script_9de0, pal_a028  ; r2
	defw gfx_script_9de0, pal_a028  ; r3
	defw gfx_script_9de0, pal_a028  ; r4
	defw gfx_script_9de0, pal_a028  ; r5

room_gfx_s06:  ; 0x9B54  stage 6
	defw gfx_script_9d64, pal_a028  ; r0
	defw gfx_script_9d64, pal_a028  ; r1
	defw gfx_script_9d64, pal_a028  ; r2
	defw gfx_script_9de0, pal_a028  ; r3
	defw gfx_script_9de0, pal_a028  ; r4
	defw gfx_script_9e0b, pal_a02f  ; r5

room_gfx_s07:  ; 0x9B6C  stage 7
	defw gfx_script_9f44, pal_a036  ; r0
	defw gfx_script_9f44, pal_a036  ; r1
	defw gfx_script_9fb2, pal_a036  ; r2
	defw gfx_script_9fb2, pal_a036  ; r3
	defw gfx_script_9e62, pal_a036  ; r4
	defw gfx_script_9fb2, pal_a036  ; r5
	defw gfx_script_9fb2, pal_a036  ; r6
	defw gfx_script_9e83, pal_a036  ; r7
	defw gfx_script_9e83, pal_a036  ; r8

room_gfx_s08:  ; 0x9B90  stage 8
	defw gfx_script_9de0, pal_a028  ; r0
	defw gfx_script_9de0, pal_a028  ; r1
	defw gfx_script_9edb, pal_a028  ; r2
	defw gfx_script_9fb2, pal_a028  ; r3
	defw gfx_script_9fb2, pal_a028  ; r4
	defw gfx_script_9e83, pal_a036  ; r5
	defw gfx_script_9e83, pal_a036  ; r6
	defw gfx_script_9fb2, pal_a036  ; r7

room_gfx_s09:  ; 0x9BB0  stage 9
	defw gfx_script_9de0, pal_a028  ; r0
	defw gfx_script_9de0, pal_a028  ; r1
	defw gfx_script_9de0, pal_a028  ; r2
	defw gfx_script_9de0, pal_a028  ; r3
	defw gfx_script_9edb, pal_a028  ; r4
	defw gfx_script_9f44, pal_a036  ; r5
	defw gfx_script_9fb2, pal_a036  ; r6
	defw gfx_script_9ea4, pal_a028  ; r7
	defw gfx_script_9e62, pal_a036  ; r8

room_gfx_s10:  ; 0x9BD4  stage 10
	defw gfx_script_9db5, pal_a059  ; r0
	defw gfx_script_9eba, pal_a059  ; r1
	defw gfx_script_9eba, pal_a059  ; r2
	defw gfx_script_9eba, pal_a059  ; r3
	defw gfx_script_9eba, pal_a059  ; r4
	defw gfx_script_9eba, pal_a059  ; r5
	defw gfx_script_9fd2, pal_a059  ; r6
	defw gfx_script_9fd2, pal_a059  ; r7
	defw gfx_script_9fd2, pal_a059  ; r8

room_gfx_s11:  ; 0x9BF8  stage 11
	defw gfx_script_9d38, pal_9ffe  ; r0
	defw gfx_script_9f44, pal_a036  ; r1
	defw gfx_script_9f01, pal_a036  ; r2
	defw gfx_script_9f01, pal_a036  ; r3
	defw gfx_script_9f01, pal_a036  ; r4
	defw gfx_script_9f1e, pal_a036  ; r5

room_gfx_s12:  ; 0x9C10  stage 12
	defw gfx_script_9f1e, pal_a036  ; r0
	defw gfx_script_9f1e, pal_a036  ; r1
	defw gfx_script_9f1e, pal_a036  ; r2
	defw gfx_script_9f1e, pal_a036  ; r3
	defw gfx_script_9f1e, pal_a036  ; r4
	defw gfx_script_9f1e, pal_a036  ; r5
	defw gfx_script_9f44, pal_a036  ; r6
	defw gfx_script_9f1e, pal_a036  ; r7
	defw gfx_script_9f1e, pal_a036  ; r8
	defw gfx_script_9f1e, pal_a036  ; r9
	defw gfx_script_9f1e, pal_a036  ; r10
	defw gfx_script_9f1e, pal_a036  ; r11

room_gfx_s13:  ; 0x9C40  stage 13
	defw gfx_script_9fb2, pal_a052  ; r0
	defw gfx_script_9e62, pal_a036  ; r1
	defw gfx_script_9f1e, pal_a036  ; r2
	defw gfx_script_9e62, pal_a036  ; r3
	defw gfx_script_9e62, pal_a052  ; r4
	defw gfx_script_9e62, pal_a036  ; r5
	defw gfx_script_9f1e, pal_a036  ; r6
	defw gfx_script_9fb2, pal_a052  ; r7
	defw gfx_script_9fb2, pal_a052  ; r8
	defw gfx_script_9fb2, pal_a052  ; r9
	defw gfx_script_9fb2, pal_a052  ; r10
	defw gfx_script_9f1e, pal_a036  ; r11

room_gfx_s14:  ; 0x9C70  stage 14
	defw gfx_script_9f5f, pal_a028  ; r0
	defw gfx_script_9f5f, pal_a028  ; r1
	defw gfx_script_9f5f, pal_a028  ; r2
	defw gfx_script_9fb2, pal_a052  ; r3
	defw gfx_script_9f5f, pal_a028  ; r4
	defw gfx_script_9f5f, pal_a028  ; r5
	defw gfx_script_9f5f, pal_a028  ; r6
	defw gfx_script_9f5f, pal_a028  ; r7

room_gfx_s15:  ; 0x9C90  stage 15
	defw gfx_script_9f5f, pal_a028  ; r0
	defw gfx_script_9f5f, pal_a028  ; r1
	defw gfx_script_9f5f, pal_a028  ; r2
	defw gfx_script_9f5f, pal_a028  ; r3
	defw gfx_script_9f5f, pal_a028  ; r4
	defw gfx_script_9f5f, pal_a028  ; r5
	defw gfx_script_9f5f, pal_a028  ; r6
	defw gfx_script_9f5f, pal_a028  ; r7
	defw gfx_script_9f5f, pal_a028  ; r8
	defw gfx_script_9f91, pal_a028  ; r9

room_gfx_s16:  ; 0x9CB8  stage 16
	defw gfx_script_9da5, pal_a036  ; r0
	defw gfx_script_9da5, pal_a036  ; r1
	defw gfx_script_9da5, pal_a036  ; r2
	defw gfx_script_9da5, pal_a036  ; r3
	defw gfx_script_9da5, pal_a036  ; r4
	defw gfx_script_9da5, pal_a036  ; r5
	defw gfx_script_9da5, pal_a036  ; r6
	defw gfx_script_9da5, pal_a036  ; r7
	defw gfx_script_9da5, pal_a036  ; r8
	defw gfx_script_9da5, pal_a036  ; r9

room_gfx_s17:  ; 0x9CE0  stage 17
	defw gfx_script_9fb2, pal_a036  ; r0
	defw gfx_script_9fb2, pal_a036  ; r1
	defw gfx_script_9f44, pal_a036  ; r2
	defw gfx_script_9f5f, pal_a028  ; r3
	defw gfx_script_9f5f, pal_a028  ; r4
	defw gfx_script_9f5f, pal_a028  ; r5
	defw gfx_script_9f44, pal_a036  ; r6
	defw gfx_script_9f01, pal_a036  ; r7
	defw gfx_script_9f44, pal_a036  ; r8
	defw gfx_script_9f44, pal_a036  ; r9
	defw gfx_script_9f01, pal_a036  ; r10
	defw gfx_script_9f44, pal_a036  ; r11

room_gfx_s18:  ; 0x9D10  stage 18
	defw gfx_script_9f5f, pal_a028  ; r0
	defw gfx_script_9f5f, pal_a028  ; r1
	defw gfx_script_9f5f, pal_a028  ; r2
	defw gfx_script_9f44, pal_a036  ; r3
	defw gfx_script_9f44, pal_a036  ; r4
	defw gfx_script_9f44, pal_a036  ; r5
	defw gfx_script_9f44, pal_a036  ; r6
	defw gfx_script_9f44, pal_a036  ; r7
	defw gfx_script_9f5f, pal_a028  ; r8
	defw gfx_script_9fa6, pal_a04a  ; r9

gfx_script_9d38:  ; 0x9D38  7 rooms, first s1r0
	defb 0x00
	defw spr_zombie, 0xfa00
	defb 0x00
	defw spr_blob, 0xfe80
	defb 0x00
	defw spr_blob_cc, 0xfec0
	defb 0x01
	defw 0xfa00
	defb 0x06
	defw 0xfac0
	defb 0xff

gfx_script_9d4e:  ; 0x9D4E  5 rooms, first s1r2
	defb 0x00
	defw spr_dog, 0xfa00
	defb 0x00
	defw spr_blob, 0xfe80
	defb 0x00
	defw spr_blob_cc, 0xfec0
	defb 0x01
	defw 0xfa00
	defb 0x10
	defw 0xfc00
	defb 0xff

gfx_script_9d64:  ; 0x9D64  9 rooms, first s1r4
	defb 0x00
	defw spr_hanging_bat, 0xfa00
	defb 0x00
	defw spr_flying_skull, 0xfd00
	defb 0x00
	defw spr_skull_pile, 0xfe00
	defb 0x00
	defw spr_blob, 0xfe80
	defb 0x00
	defw spr_blob_cc, 0xfec0
	defb 0x01
	defw 0xfa40
	defb 0x06
	defw 0xfb00
	defb 0x01
	defw 0xfd00
	defb 0x04
	defw 0xfd80
	defb 0xff

gfx_script_9d8a:  ; 0x9D8A  2 rooms, first s2r4
	defb 0x00
	defw spr_merman, 0xfa00
	defb 0x00
	defw gfx_rle_a23b, 0xfc80
	defb 0x00
	defw spr_blob, 0xfe80
	defb 0x00
	defw spr_blob_cc, 0xfec0
	defb 0x01
	defw 0xfa00
	defb 0x0a
	defw 0xfb40
	defb 0xff

gfx_script_9da5:  ; 0x9DA5  11 rooms, first s3r5
	defb 0x00
	defw spr_giant_bat, 0xfa00
	defb 0x00
	defw spr_blob, 0xfe80
	defb 0x00
	defw spr_blob_cc, 0xfec0
	defb 0xff

gfx_script_9db5:  ; 0x9DB5  3 rooms, first s4r1
	defb 0x00
	defw spr_hanging_bat, 0xfa00
	defb 0x00
	defw spr_pikeman, 0xfc00
	defb 0x00
	defw spr_blob, 0xfe00
	defb 0x00
	defw spr_blob_cc, 0xfe40
	defb 0x00
	defw gfx_rle_a0a8, 0xfe80   ; pad art (s10 uses the FEC0 copy)
	defb 0x00
	defw gfx_rle_a0a8, 0xfec0   ; moving pad SAT D8/DC
	defb 0x01
	defw 0xfa40
	defb 0x06
	defw 0xfb00
	defb 0x01
	defw 0xfc00
	defb 0x08
	defw 0xfd00
	defb 0xff

gfx_script_9de0:  ; 0x9DE0  18 rooms, first s4r0
	defb 0x00
	defw spr_ghost_head, 0xfa00
	defb 0x00
	defw spr_pikeman, 0xfc00
	defb 0x00
	defw spr_skull_pile, 0xfe00
	defb 0x00
	defw gfx_rle_a066, 0xfe80   ; moving pad SAT D0/D4 (stage 5)
	defb 0x00
	defw spr_blob, 0xfb80
	defb 0x00
	defw spr_blob_cc, 0xfbc0
	defb 0x01
	defw 0xfa00
	defb 0x04
	defw 0xfa80
	defb 0x01
	defw 0xfc00
	defb 0x08
	defw 0xfd00
	defb 0xff

gfx_script_9e0b:  ; 0x9E0B  1 rooms, first s6r5
	defb 0x00
	defw spr_medusa, 0xfa00
	defb 0x00
	defw gfx_rle_b198, 0xfc00
	defb 0x00
	defw spr_blob, 0xfe80
	defb 0x00
	defw spr_blob_cc, 0xfec0
	defb 0x01
	defw 0xfc00
	defb 0x04
	defw 0xfc80
	defb 0xff

gfx_script_9e26:  ; 0x9E26  not in room_gfx_ptr
	defb 0x00
	defw spr_flying_skull, 0xfd00
	defb 0x00
	defw spr_skull_pile, 0xfe00
	defb 0x00
	defw spr_blob, 0xfe80
	defb 0x00
	defw spr_blob_cc, 0xfec0
	defb 0x01
	defw 0xfd00
	defb 0x04
	defw 0xfd80
	defb 0xff

gfx_script_9e41:  ; 0x9E41  not in room_gfx_ptr
	defb 0x00
	defw spr_skeleton, 0xfa00
	defb 0x00
	defw gfx_rle_b4a3, 0xfc00
	defb 0x00
	defw gfx_rle_a827, 0xfc80
	defb 0x00
	defw spr_raven, 0xfd40
	defb 0x01
	defw 0xfa00
	defb 0x08
	defw 0xfb00
	defb 0x01
	defw 0xfd40
	defb 0x06
	defw 0xfe00
	defb 0xff

gfx_script_9e62:  ; 0x9E62  6 rooms, first s7r4
	defb 0x00
	defw spr_skeleton, 0xfa00
	defb 0x00
	defw gfx_rle_b4a3, 0xfc00
	defb 0x00
	defw gfx_rle_a827, 0xfc80
	defb 0x00
	defw spr_hunchback, 0xfd40
	defb 0x01
	defw 0xfa00
	defb 0x08
	defw 0xfb00
	defb 0x01
	defw 0xfd40
	defb 0x06
	defw 0xfe00
	defb 0xff

gfx_script_9e83:  ; 0x9E83  4 rooms, first s7r7
	defb 0x00
	defw spr_raven, 0xfa00
	defb 0x00
	defw spr_skull_pile, 0xfe00
	defb 0x00
	defw spr_blob, 0xfb80
	defb 0x00
	defw spr_blob_cc, 0xfbc0
	defb 0x01
	defw 0xfa00
	defb 0x06
	defw 0xfac0
	defb 0x01
	defw 0xfe00
	defb 0x02
	defw 0xfe40
	defb 0xff

gfx_script_9ea4:  ; 0x9EA4  1 rooms, first s9r7
	defb 0x00
	defw spr_mummy, 0xfa00
	defb 0x00
	defw spr_blob, 0xfe80
	defb 0x00
	defw spr_blob_cc, 0xfec0
	defb 0x01
	defw 0xfa00
	defb 0x10
	defw 0xfc80
	defb 0xff

gfx_script_9eba:  ; 0x9EBA  5 rooms, first s10r1
	defb 0x00
	defw spr_hanging_bat, 0xfa00
	defb 0x00
	defw spr_merman, 0xfc00
	defb 0x00
	defw gfx_rle_a23b, 0xfe80
	defb 0x00
	defw gfx_rle_a0a8, 0xfec0   ; moving pad SAT D8/DC (stage 10)
	defb 0x01
	defw 0xfa40
	defb 0x06
	defw 0xfb00
	defb 0x01
	defw 0xfc00
	defb 0x0a
	defw 0xfd40
	defb 0xff

gfx_script_9edb:  ; 0x9EDB  2 rooms, first s8r2
	defb 0x00
	defw spr_skeleton, 0xfa00
	defb 0x00
	defw gfx_rle_b4a3, 0xfc00
	defb 0x00
	defw gfx_rle_a827, 0xfc80
	defb 0x00
	defw spr_ghost_head, 0xfd40
	defb 0x00
	defw spr_skull_pile, 0xfe40
	defb 0x01
	defw 0xfa00
	defb 0x08
	defw 0xfb00
	defb 0x01
	defw 0xfd40
	defb 0x04
	defw 0xfdc0
	defb 0xff

gfx_script_9f01:  ; 0x9F01  5 rooms, first s11r2
	defb 0x00
	defw spr_roc, 0xfa00
	defb 0x00
	defw spr_hunchback, 0xfd40
	defb 0x01
	defw 0xfa00
	defb 0x0c
	defw 0xfbc0
	defb 0x01
	defw 0xfd40
	defb 0x06
	defw 0xfe00
	defb 0x01
	defw 0xfb80
	defb 0x02
	defw 0xfec0
	defb 0xff

gfx_script_9f1e:  ; 0x9F1E  15 rooms, first s11r5
	defb 0x00
	defw spr_zombie, 0xfa00
	defb 0x00
	defw spr_bone_dragon, 0xfb80
	defb 0x00
	defw spr_hunchback, 0xfd40
	defb 0x00
	defw spr_blob, 0xfd00
	defb 0x00
	defw spr_blob_cc, 0xfec0
	defb 0x01
	defw 0xfa00
	defb 0x06
	defw 0xfac0
	defb 0x01
	defw 0xfd40
	defb 0x06
	defw 0xfe00
	defb 0xff

gfx_script_9f44:  ; 0x9F44  15 rooms, first s7r0
	defb 0x00
	defw spr_frankenstein, 0xfa00
	defb 0x00
	defw spr_hunchback, 0xfd40
	defb 0x00
	defw spr_blob, 0xfd00
	defb 0x00
	defw spr_blob_cc, 0xfec0
	defb 0x01
	defw 0xfd40
	defb 0x06
	defw 0xfe00
	defb 0xff

gfx_script_9f5f:  ; 0x9F5F  23 rooms, first s14r0
	defb 0x00
	defw spr_axe_knight, 0xfa00
	defb 0x00
	defw weapon_axe, 0xfc00
	defb 0x01
	defw 0xfc00
	defb 0x02
	defw 0xfcc0
	defb 0x01
	defw 0xfc40
	defb 0x02
	defw 0xfc80
	defb 0x00
	defw spr_ghost_head, 0xfd40
	defb 0x00
	defw spr_blob, 0xfd00
	defb 0x00
	defw spr_blob_cc, 0xfec0
	defb 0x01
	defw 0xfa00
	defb 0x08
	defw 0xfb00
	defb 0x01
	defw 0xfd40
	defb 0x06
	defw 0xfdc0
	defb 0xff

gfx_script_9f91:  ; 0x9F91  1 rooms, first s15r9
	defb 0x00
	defw spr_grim_reaper, 0xfa00
	defb 0x00
	defw gfx_rle_a3de, 0xfb80
	defb 0x00
	defw spr_blob, 0xfe80
	defb 0x00
	defw spr_blob_cc, 0xfec0
	defb 0xff

gfx_script_9fa6:  ; 0x9FA6  1 rooms, first s18r9
	defb 0x00
	defw spr_dracula, 0xfa00
	defb 0x01
	defw 0xfa00
	defb 0x0a
	defw 0xfb80
	defb 0xff

gfx_script_9fb2:  ; 0x9FB2  16 rooms, first s7r2
	defb 0x00
	defw spr_skeleton, 0xfa00
	defb 0x00
	defw gfx_rle_b4a3, 0xfc00
	defb 0x00
	defw gfx_rle_a827, 0xfc80
	defb 0x00
	defw spr_blob, 0xfe80
	defb 0x00
	defw spr_blob_cc, 0xfec0
	defb 0x01
	defw 0xfa00
	defb 0x08
	defw 0xfb00
	defb 0xff

gfx_script_9fd2:  ; 0x9FD2  3 rooms, first s10r6
	defb 0x00
	defw spr_merman, 0xfc00
	defb 0x00
	defw gfx_rle_a23b, 0xfe80
	defb 0x00
	defw spr_blob, 0xfb80
	defb 0x00
	defw spr_blob_cc, 0xfbc0
	defb 0x01
	defw 0xfc00
	defb 0x0a
	defw 0xfd40
	defb 0xff

gfx_script_9fed:  ; 0x9FED  frontend (ld hl,gfx_script_9fed)
	defb 0x00
	defw gfx_rle_aee0, 0xfa40
	defb 0x00
	defw gfx_rle_af96, 0xfbc0
	defb 0x01
	defw 0xfa40
	defb 0x06
	defw 0xfb00
	defb 0xff

pal_9ffe:  ; 0x9FFE  2 bytes here, rest at 0xA000
	defb 0x04,0x76

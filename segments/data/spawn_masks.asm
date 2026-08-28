; Per-room spawn bitmasks (seg14 0x85A6).  room_spawner: D000 then D001.
; Bits: spawn_zombie / _merman_green / _merman_red / _hanging_bat / _flying_skull / _ghost_head / _roc; spawn_bit7 unused.

; spawn_bitmask_ptr (seg14 0x85A6): word[stage 0..18] -> per-room spawn
; bitmask. room_spawner indexes by 0xD000 then 0xD001.
; Bits 0-6: zombie, green merman, red merman, hanging bat, flying skull,
; ghost head, roc. Bit 7 appears in some masks but is never dispatched.
spawn_bitmask_ptr:
	defw spawn_mask_s00     ; stage 0
	defw spawn_mask_s01     ; stage 1
	defw spawn_mask_s02     ; stage 2
	defw spawn_mask_s03     ; stage 3
	defw spawn_mask_s04     ; stage 4
	defw spawn_mask_s05     ; stage 5
	defw spawn_mask_s06     ; stage 6
	defw spawn_mask_s07     ; stage 7
	defw spawn_mask_s08     ; stage 8
	defw spawn_mask_s09     ; stage 9
	defw spawn_mask_s10     ; stage 10
	defw spawn_mask_s11     ; stage 11
	defw spawn_mask_s12     ; stage 12
	defw spawn_mask_s13     ; stage 13
	defw spawn_mask_s14     ; stage 14
	defw spawn_mask_s15     ; stage 15
	defw spawn_mask_s16     ; stage 16
	defw spawn_mask_s17     ; stage 17
	defw spawn_mask_s18     ; stage 18

; stage 0 (3 rooms)
spawn_mask_s00:
	defb 000h              ; r0 none
	defb 000h              ; r1 none
	defb 000h              ; r2 none

; stage 1 (8 rooms)
spawn_mask_s01:
	defb spawn_zombie              ; r0 zombie
	defb spawn_zombie              ; r1 zombie
	defb 000h              ; r2 none
	defb 000h              ; r3 none
	defb spawn_hanging_bat              ; r4 hangbat
	defb spawn_zombie              ; r5 zombie
	defb spawn_zombie              ; r6 zombie
	defb 000h              ; r7 none

; stage 2 (6 rooms)
spawn_mask_s02:
	defb spawn_hanging_bat              ; r0 hangbat
	defb spawn_hanging_bat              ; r1 hangbat
	defb spawn_zombie              ; r2 zombie
	defb spawn_hanging_bat              ; r3 hangbat
	defb spawn_merman_green              ; r4 merman
	defb spawn_merman_green              ; r5 merman

; stage 3 (6 rooms)
spawn_mask_s03:
	defb 000h              ; r0 none
	defb 000h              ; r1 none
	defb 000h              ; r2 none
	defb spawn_zombie | spawn_bit7              ; r3 zombie, bit7
	defb spawn_hanging_bat              ; r4 hangbat
	defb 000h              ; r5 none

; stage 4 (6 rooms)
spawn_mask_s04:
	defb spawn_bit7              ; r0 bit7
	defb 000h              ; r1 none
	defb 000h              ; r2 none
	defb 000h              ; r3 none
	defb spawn_ghost_head | spawn_bit7              ; r4 ghosthd, bit7
	defb spawn_bit7              ; r5 bit7

; stage 5 (6 rooms)
spawn_mask_s05:
	defb spawn_ghost_head | spawn_bit7              ; r0 ghosthd, bit7
	defb spawn_ghost_head              ; r1 ghosthd
	defb spawn_bit7              ; r2 bit7
	defb spawn_bit7              ; r3 bit7
	defb spawn_ghost_head              ; r4 ghosthd
	defb spawn_ghost_head | spawn_bit7              ; r5 ghosthd, bit7

; stage 6 (6 rooms)
spawn_mask_s06:
	defb spawn_flying_skull              ; r0 flyskull
	defb 000h              ; r1 none
	defb 000h              ; r2 none
	defb spawn_ghost_head | spawn_bit7              ; r3 ghosthd, bit7
	defb spawn_ghost_head              ; r4 ghosthd
	defb 000h              ; r5 none

; stage 7 (9 rooms)
spawn_mask_s07:
	defb spawn_bit7              ; r0 bit7
	defb spawn_bit7              ; r1 bit7
	defb spawn_bit7              ; r2 bit7
	defb spawn_bit7              ; r3 bit7
	defb 000h              ; r4 none
	defb spawn_bit7              ; r5 bit7
	defb 000h              ; r6 none
	defb 000h              ; r7 none
	defb 000h              ; r8 none

; stage 8 (8 rooms)
spawn_mask_s08:
	defb 000h              ; r0 none
	defb spawn_ghost_head              ; r1 ghosthd
	defb 000h              ; r2 none
	defb 000h              ; r3 none
	defb 000h              ; r4 none
	defb 000h              ; r5 none
	defb 000h              ; r6 none
	defb 000h              ; r7 none

; stage 9 (9 rooms)
spawn_mask_s09:
	defb spawn_ghost_head | spawn_bit7              ; r0 ghosthd, bit7
	defb spawn_ghost_head | spawn_bit7              ; r1 ghosthd, bit7
	defb spawn_ghost_head              ; r2 ghosthd
	defb spawn_ghost_head              ; r3 ghosthd
	defb 000h              ; r4 none
	defb 000h              ; r5 none
	defb 000h              ; r6 none
	defb 000h              ; r7 none
	defb 000h              ; r8 none

; stage 10 (9 rooms)
spawn_mask_s10:
	defb spawn_hanging_bat              ; r0 hangbat
	defb spawn_merman_red              ; r1 merman3
	defb spawn_merman_red              ; r2 merman3
	defb spawn_merman_red              ; r3 merman3
	defb spawn_merman_red              ; r4 merman3
	defb spawn_merman_red              ; r5 merman3
	defb 000h              ; r6 none
	defb 000h              ; r7 none
	defb 000h              ; r8 none

; stage 11 (6 rooms)
spawn_mask_s11:
	defb spawn_zombie | spawn_bit7              ; r0 zombie, bit7
	defb 000h              ; r1 none
	defb spawn_roc              ; r2 roc
	defb spawn_roc              ; r3 roc
	defb spawn_roc              ; r4 roc
	defb spawn_bit7              ; r5 bit7

; stage 12 (12 rooms)
spawn_mask_s12:
	defb 000h              ; r0 none
	defb 000h              ; r1 none
	defb 000h              ; r2 none
	defb 000h              ; r3 none
	defb 000h              ; r4 none
	defb 000h              ; r5 none
	defb 000h              ; r6 none
	defb 000h              ; r7 none
	defb 000h              ; r8 none
	defb 000h              ; r9 none
	defb 000h              ; r10 none
	defb 000h              ; r11 none

; stage 13 (12 rooms)
spawn_mask_s13:
	defb 000h              ; r0 none
	defb 000h              ; r1 none
	defb spawn_bit7              ; r2 bit7
	defb 000h              ; r3 none
	defb 000h              ; r4 none
	defb 000h              ; r5 none
	defb spawn_bit7              ; r6 bit7
	defb spawn_bit7              ; r7 bit7
	defb spawn_bit7              ; r8 bit7
	defb spawn_bit7              ; r9 bit7
	defb spawn_bit7              ; r10 bit7
	defb spawn_bit7              ; r11 bit7

; stage 14 (8 rooms)
spawn_mask_s14:
	defb spawn_bit7              ; r0 bit7
	defb spawn_bit7              ; r1 bit7
	defb spawn_bit7              ; r2 bit7
	defb spawn_bit7              ; r3 bit7
	defb spawn_bit7              ; r4 bit7
	defb spawn_bit7              ; r5 bit7
	defb spawn_bit7              ; r6 bit7
	defb spawn_bit7              ; r7 bit7

; stage 15 (10 rooms)
spawn_mask_s15:
	defb 000h              ; r0 none
	defb spawn_bit7              ; r1 bit7
	defb spawn_bit7              ; r2 bit7
	defb spawn_bit7              ; r3 bit7
	defb 000h              ; r4 none
	defb 000h              ; r5 none
	defb 000h              ; r6 none
	defb spawn_bit7              ; r7 bit7
	defb 000h              ; r8 none
	defb 000h              ; r9 none

; stage 16 (10 rooms)
spawn_mask_s16:
	defb 000h              ; r0 none
	defb 000h              ; r1 none
	defb 000h              ; r2 none
	defb 000h              ; r3 none
	defb 000h              ; r4 none
	defb 000h              ; r5 none
	defb 000h              ; r6 none
	defb 000h              ; r7 none
	defb 000h              ; r8 none
	defb 000h              ; r9 none

; stage 17 (12 rooms)
spawn_mask_s17:
	defb 000h              ; r0 none
	defb 000h              ; r1 none
	defb 000h              ; r2 none
	defb spawn_bit7              ; r3 bit7
	defb 000h              ; r4 none
	defb spawn_bit7              ; r5 bit7
	defb 000h              ; r6 none
	defb spawn_roc              ; r7 roc
	defb 000h              ; r8 none
	defb 000h              ; r9 none
	defb spawn_roc              ; r10 roc
	defb 000h              ; r11 none

; stage 18 (10 rooms)
spawn_mask_s18:
	defb 000h              ; r0 none
	defb spawn_bit7              ; r1 bit7
	defb 000h              ; r2 none
	defb 000h              ; r3 none
	defb 000h              ; r4 none
	defb 000h              ; r5 none
	defb 000h              ; r6 none
	defb spawn_bit7              ; r7 bit7
	defb spawn_bit7              ; r8 bit7
	defb 000h              ; r9 none


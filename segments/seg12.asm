; ===========================================================================
;  SEGMENT 12 - bank 0x0C, paged at 0x8000-0x9FFF (page 2a) by sub_5369h /
;  room_map_build.  Per-stage 4x4 metatile definition tables (16 bytes = one
;  metatile).  Origin is set by PHASE 0x8000 in VampireKiller.asm.
;
;  Shares the CPU window with seg02; labels here are unique.  Defs can
;  straddle out of seg11 (stage 0 tail) and into seg13 (stage 18 tail).
;  Starts of each table = mtile_defbase[stage] (see segments/seg11.asm).
; ===========================================================================

; Tail of stage 0 defs (body starts at mtile_defbase[0] = 0x7EE1 in seg11).
	INCBIN "seg12.bin", 0, 0x00B1

mtile_defs_s01:                  ; stages 1-3 (0x80B1)
	INCBIN "seg12.bin", 0x00B1, 0x0420

mtile_defs_s04:                  ; stages 4-6 (0x84D1)
	INCBIN "seg12.bin", 0x04D1, 0x02C0

mtile_defs_s07:                  ; stages 7-9 (0x8791)
	INCBIN "seg12.bin", 0x0791, 0x0590

mtile_defs_s10:                  ; stages 10-12 (0x8D21)
	INCBIN "seg12.bin", 0x0D21, 0x0400

mtile_defs_s13:                  ; stages 13-15 (0x9121)
	INCBIN "seg12.bin", 0x1121, 0x0530

mtile_defs_s16:                  ; stages 16-17 (0x9651)
	INCBIN "seg12.bin", 0x1651, 0x0470

; Stage 18 defs start at 0x9AC1 and straddle into seg13 (0xA000..0xA040).
mtile_defs_s18:                  ; stage 18 (0x9AC1), tail in seg13
	INCBIN "seg12.bin", 0x1AC1, 0x053F

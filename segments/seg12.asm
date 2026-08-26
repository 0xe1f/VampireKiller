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
	INCLUDE "data/mtile_defs_s00_b.asm"

	INCLUDE "data/mtile_defs_s01.asm"
	INCLUDE "data/mtile_defs_s04.asm"
	INCLUDE "data/mtile_defs_s07.asm"
	INCLUDE "data/mtile_defs_s10.asm"
	INCLUDE "data/mtile_defs_s13.asm"
	INCLUDE "data/mtile_defs_s16.asm"
	INCLUDE "data/mtile_defs_s18_a.asm"

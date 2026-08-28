; ===========================================================================
;  Packed scenery-list grammar (seg14 scenery_list_*).  Readability only.
;  Record: pos (Y<<4|X), attr; attr 0x7F adds a third reveal byte.
;  Punctuation is one byte.  attr bits7-5 = kind, bits4-0 = item_*.
;  bits7-6 10 = chest, 11 = vendor (vendor also uses bits5-2 as offer slot).
; ===========================================================================

; Stream punctuation (not attr).  scenery_end_hub is 0 like scenery_floor;
; arity distinguishes them (one byte vs pos+attr).
scenery_end_hub:         equ 0x00
scenery_next_room:       equ 0xfe
scenery_next_stage:      equ 0xff

; attr kind (OR with item_* 0..0x1F)
scenery_floor:           equ 0x00
scenery_candle:          equ 0x20
scenery_block16:         equ 0x40  ; engine-ready; unused in the packed stream
scenery_block32:         equ 0x60
scenery_cover:           equ 0x7f  ; 32x32 wall + reveal byte
scenery_chest:           equ 0x80
scenery_vendor:          equ 0xc0

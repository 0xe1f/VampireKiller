; ===========================================================================
;  Cell-event ids in 0xCE00 (low nibble of cell_event_tbl).  Readability
;  only — not emitted.  Named evt_* so they do not collide with the CE01
;  machines (event_giant_bat … event_dracula) in banks_0123.asm.
;  Use at cell_event_tbl / cell_event_set and CE00 compares, not every
;  small literal.  Do not add these to msx.sym.
; ===========================================================================

evt_giant_bat:           equ 0x01  ; stage 3 room 5
evt_medusa:              equ 0x02  ; stage 6 room 5
evt_mummies:             equ 0x03  ; stage 9 room 7
evt_frankenstein:        equ 0x04  ; stage 12 room 6
evt_grim_reaper:         equ 0x05  ; stage 15 room 9
evt_dracula:             equ 0x06  ; stage 18 room 9

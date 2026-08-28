; ===========================================================================
;  Pending-exit values in exit_dir (C41B).  Readability only — not
;  emitted.  Named dir_* so they do not collide with permit_up/down/…
;  or room_edge_*.  Use at room_edge_detect / conn_lookup stores and
;  the portal write, not every small literal.  Packed ld bc,003f6h /
;  0040ah stay hex.  Do not add these to msx.sym.
; ===========================================================================

dir_up:                  equ 0x01
dir_down:                equ 0x02
dir_left:                equ 0x03
dir_right:               equ 0x04
dir_portal:              equ 0xFF  ; spot warp (conn_from_spot)

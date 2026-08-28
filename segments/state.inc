; ===========================================================================
;  Main-state (C000) and Simon-action (C420) ids.  Readability only — not
;  emitted.  Named main_* / act_* so they do not collide with the handlers
;  (state_play, simon_dying, …).  Use at the two jump tables and the id
;  loads/compares that feed them, not every small literal.  Do not add
;  these to msx.sym.
; ===========================================================================

; C000 primary state -> main_state_tbl.  C001 is the sub-phase.
main_logo:               equ 0x00
main_title:              equ 0x01
main_attract:            equ 0x02
main_intro:              equ 0x03
main_stage_bridge:       equ 0x04
main_play:               equ 0x05
main_death:              equ 0x06
main_game_over:          equ 0x07
main_hub_advance:        equ 0x08
main_room_trans:         equ 0x09
main_stage_exit:         equ 0x0a
main_pause:              equ 0x0b
main_vendor:             equ 0x0c
main_game_master:        equ 0x0d

; C420 action state -> simon_action_tbl.  C420 is also the logo wipe
; divider; those sites stay hex / simon_action, not act_*.
act_grounded:            equ 0x00
act_jump:                equ 0x01
act_crouch:              equ 0x02
act_stairs:              equ 0x03
act_fall:                equ 0x04
act_hurt:                equ 0x05
act_dying:               equ 0x06
act_portal:              equ 0x07

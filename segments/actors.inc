; ===========================================================================
;  Actor type ids for spawn_actor (C) and the packed object list (id & 0x7F).
;  Readability only — not emitted.  Indexed 1-based into entity_tbl; types
;  0x18+ overflow into seg1 data_6000.  Object-list bit7 is stored then
;  stripped at spawn (dogs only: actor_dog|080h).
; ===========================================================================

; Stream punctuation in object_list (not actor ids).
obj_next_room:           equ 0x00
obj_end_stream:          equ 0xff

; entity_tbl types 1-22
actor_zombie:            equ 0x01  ; generator bit0
actor_merman_green:      equ 0x02  ; 1 HP, closed mouth; generator bit1
actor_merman_red:        equ 0x03  ; 2 HP, spit; generator bit2
actor_hanging_bat:       equ 0x04  ; generator fly-in; bit3
actor_dog:               equ 0x05
actor_pikeman:           equ 0x06
actor_flying_skull:      equ 0x07  ; generator bit4
actor_ghost_head:        equ 0x08  ; generator bit5
actor_red_skeleton:      equ 0x09
actor_skull_pile:        equ 0x0a
actor_white_skeleton:    equ 0x0b
actor_raven:             equ 0x0c
actor_hunchback:         equ 0x0d
actor_bone_dragon:       equ 0x0e
actor_roc:               equ 0x0f  ; generator bit6; drops actor_roc_drop
actor_axe_knight:        equ 0x10
actor_dracula:           equ 0x11
actor_giant_bat:         equ 0x12  ; event 1 boss; also placed on stage 16
actor_medusa:            equ 0x13
actor_mummy:             equ 0x14
actor_frankenstein:      equ 0x15
actor_grim_reaper:       equ 0x16

; Overflow / special (past entity_tbl)
actor_igor:              equ 0x18  ; Frankenstein add-on (event 4)
actor_blob_blue:         equ 0x1a  ; candle slime hatch; hub 1 (s4-6); SAT 0F 42
actor_blob_red:          equ 0x1b  ; same tick; hub 3+ (s10+); SAT 08 42
actor_blob_white:        equ 0x1c  ; same tick; hub 2 (s7-9); SAT 0E 42
actor_flame:             equ 0x1e  ; candle flame; then may drop actor_pickup
actor_placed_bat:        equ 0x1f  ; hangs first (skips type-4 fly-in)
actor_merman_splash:     equ 0x20  ; water-splash pair from generator mermen
actor_placed_merman:     equ 0x21  ; red spit, already on the platform (stage 10)
actor_orb:               equ 0x22  ; boss-clear orb
actor_roc_drop:          equ 0x23  ; roc projectile (hunchback tick)
actor_pickup:            equ 0x24  ; settled / falling heart pickup
actor_reward:            equ 0x26  ; candle/chest drop: sparkle, fall, then pickup
actor_intro_sky:         equ 0x27  ; intro SAT; pose shape_intro_sky
actor_intro_sky_a:       equ 0x28  ; intro SAT; poses 0x92/0x93
actor_intro_sky_b:       equ 0x29  ; same tick as 0x28; second spawn pos
actor_intro_simon:       equ 0x2A  ; intro SAT Simon; pose shape_intro_simon_1
actor_dracula_bat:       equ 0x2C  ; event 6: drop, then hanging-bat fly
actor_dracula_head:      equ 0x2D  ; event 6: SAT head arc after dracula_summon
actor_dracula_chunk:     equ 0x2E  ; event 6: six debris chunks after type 17 dies

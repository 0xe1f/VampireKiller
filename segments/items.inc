; ===========================================================================
;  Pickup / drop ids (collect_bonus A, scenery attr bits4-0, C419 latch).
;  Readability only — not emitted.  Named item_* so they do not collide
;  with the collect_bonus handlers (bonus_small_heart, …) in banks_0123.
;  collect_bonus_tbl is word[id-1] for 1..25; id >= 0x1A falls through to
;  collect_weapon (C416 = id-0x19, except 0x1E holy water).
; ===========================================================================

item_none:               equ 0x00  ; empty candle / no drop
item_small_heart:        equ 0x01
item_large_heart:        equ 0x02
item_red_shield:         equ 0x03
item_yellow_shield:      equ 0x04
item_white_cross:        equ 0x05
item_rosary:             equ 0x06
item_small_orb:          equ 0x07
item_blue_gem:           equ 0x08
item_sapphire_ring:      equ 0x09
item_hourglass:          equ 0x0a
item_tipped_hourglass:   equ 0x0b
item_boots:              equ 0x0c
item_wings:              equ 0x0d
item_candle:             equ 0x0e
item_map:                equ 0x0f
item_black_bible:        equ 0x10
item_white_bible:        equ 0x11
item_lockpick:           equ 0x12
item_white_bag:          equ 0x13
item_blue_bag:           equ 0x14
item_slime:              equ 0x15
item_potion:             equ 0x16
item_yellow_key:         equ 0x17
item_white_key:          equ 0x18
item_chest:              equ 0x19  ; container stub; world path opens separately

; Weapon pickups (not in collect_bonus_tbl).  C416 = id - 0x19.
item_chain_whip:         equ 0x1a  ; -> equip_chain
item_knife:              equ 0x1b  ; -> equip_knife
item_axe:                equ 0x1c  ; -> equip_axe
item_cross:              equ 0x1d  ; -> equip_cross
item_holy_water:         equ 0x1e  ; C701 bit3, not C416

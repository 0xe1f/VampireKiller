; ===========================================================================
;  Whip tier in weapon_id (0xC416): leather or chain.  Knife, axe, and
;  cross live in subweapon (0xC414).  Readability only — not emitted.
;  Named equip_* so they do not collide with thrown-weapon SAT streams
;  (weapon_knife / weapon_axe / weapon_cross in data/enemy_sprite_rle.asm).
;  Holy water is item_holy_water (C701 bit3), not either byte.
; ===========================================================================

equip_leather:           equ 0x00
equip_chain:             equ 0x01
equip_knife:             equ 0x02
equip_axe:               equ 0x03
equip_cross:             equ 0x04

; ===========================================================================
;  play_sound ids.  Readability only — not emitted.
;  1..0x1D index sfx_tbl (seg14 0x8D8F); 0x80..0x8F index music_ptr
;  (id & 0x7F)*6.  0xFF is the fade / stop command, not a table row.
;  Stream labels in data/psg_sfx.asm / psg_music.asm keep the sfx_NN_ / music_NN_ stems.
; ===========================================================================

sfx_boss_heal:           equ 0x01
sfx_vendor_withdraw:     equ 0x02
sfx_cross_fly:           equ 0x03
sfx_knife_throw:         equ 0x04
sfx_whip:                equ 0x05
sfx_axe_fly:             equ 0x06
sfx_land:                equ 0x07
sfx_merman_out:          equ 0x08
sfx_water_in:            equ 0x09
sfx_mummy_shot:          equ 0x0a
sfx_shield_block:        equ 0x0b
sfx_hit:                 equ 0x0c
sfx_ring_kill:           equ 0x0d
sfx_block_break:         equ 0x0e
sfx_heart:               equ 0x0f
sfx_money_bag:           equ 0x10
sfx_chest:               equ 0x11
sfx_collect:             equ 0x12
sfx_simon_hurt:          equ 0x13
sfx_key:                 equ 0x14
sfx_portal:              equ 0x15
sfx_blue_gem:            equ 0x16
sfx_gem_warn:            equ 0x17
sfx_holy_water:          equ 0x18
sfx_vendor_offer:        equ 0x19
sfx_door:                equ 0x1a
sfx_white_cross:         equ 0x1b
sfx_boss_clear:          equ 0x1c
sfx_vendor_hearts:       equ 0x1d

bgm_s00_03:              equ 0x80
bgm_s04_06_11_12:        equ 0x81
bgm_s07_09:              equ 0x82
bgm_s16_17:              equ 0x83
bgm_s13_15:              equ 0x84
bgm_s10_18:              equ 0x85
bgm_boss_dracula:        equ 0x86
bgm_boss:                equ 0x87
bgm_boss_dracula_portrait: equ 0x88
bgm_simon_death:         equ 0x89
bgm_enter_castle:        equ 0x8a
bgm_game_over:           equ 0x8b
bgm_boss_defeated:       equ 0x8c
bgm_dracula_defeated:    equ 0x8d
bgm_credits:             equ 0x8e
bgm_silence:             equ 0x8f

sound_fade:              equ 0xff  ; play_sound 0xFF: fade / stop

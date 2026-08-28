; ===========================================================================
;  Confirmed work-RAM addresses.  Readability only — not emitted, not in
;  msx.sym (z80dasm would rewrite every matching immediate).  Regen of a
;  play bank emits hex again; re-apply after regen-seg.
; ===========================================================================

; Play input (input_edge).  Bits: 0=UP 1=DOWN 2=LEFT 3=RIGHT
; 4=SPACE|TRG1 (whip) 5=kbd UP|TRG2 (jump / portal).
btn_edge:                equ 0xC006
btn_held:                equ 0xC007

; Title / attract (frontend_input).  Same bit layout as play.
title_btn_edge:          equ 0xC400
title_btn_held:          equ 0xC401

; Player stats (0xC400-0xC41F).  Unused holes C402-C404, C40B, C40E-C40F,
; C414 have no code xrefs and stay unnamed.
score:                   equ 0xC405  ; 3-byte packed BCD, low pair
score_mid:               equ 0xC406
score_hi:                equ 0xC407
door_exit:               equ 0xC408  ; white-key door -> state_stage_exit
hub_advance:             equ 0xC409  ; boss-clear / credits -> state_hub_advance
pause_latch:             equ 0xC40A  ; F1 -> state_pause
vendor_hit:              equ 0xC40C  ; whip-hit vendor -> state_vendor
replay_bgm:              equ 0xC40D  ; force stage BGM replay
lives:                   equ 0xC410  ; packed BCD
hud_stage:               equ 0xC411  ; packed BCD STAGE
stay_in_play:            equ 0xC413  ; 1 = play, 0 = leave (attract / death)
health:                  equ 0xC415  ; Simon HP, full 0x20
weapon_id:               equ 0xC416  ; equip_* (leather..cross)
hearts:                  equ 0xC417  ; packed BCD
enemy_meter:             equ 0xC418  ; enemy/boss bar, full 0x80
bonus_id:                equ 0xC419  ; last-collected item_*
flag_intro_map:          equ 0xC41A  ; nonzero -> mtile_stream_intro
exit_dir:                equ 0xC41B  ; 1-4 dir, 0xFF spot/portal
permit_up:               equ 0xC41C
permit_down:             equ 0xC41D
permit_left:             equ 0xC41E
permit_right:            equ 0xC41F

; Simon.  Pixel X is the high byte of the 16-bit value at simon_x16.
simon_action:            equ 0xC420  ; 0 grounded .. 7 portal wait
simon_y:                 equ 0xC425
simon_x16:               equ 0xC426
simon_x:                 equ 0xC427
simon_legs:              equ 0xC42E  ; cell-0 frame; word store also writes torso
simon_torso:             equ 0xC42F

; World index (not map coordinates).
stage:                   equ 0xD000  ; 0 courtyard, 1-18
room:                    equ 0xD001
hub:                     equ 0xD002  ; 0-5, selects seg14 datasets

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

; Cell event / boss (0xCE00-0xCE16).  Unused CE03-CE06, CE08, CE0A, CE0D
; have no named meaning yet (CE03/CE08 have xrefs; the rest have none).
cell_event:              equ 0xCE00  ; evt_* (0 = none)
event_step:              equ 0xCE01  ; CE01 machine index
event_timer:             equ 0xCE02
igor_jump:               equ 0xCE07  ; event 4: Igor's jump trigger
frank_xvel:              equ 0xCE09  ; event 4: Frankenstein chase vel (word)
boss_clear:              equ 0xCE0B  ; NZ -> room_event_ce10
event_fx:                equ 0xCE0C  ; NZ suppresses pattern_phase_upload
dracula_torso:           equ 0xCE0E  ; 1..5 blit slot (dracula_blit_torso)
dracula_x:               equ 0xCE0F  ; figure X; chunk scatter origin
boss_clear_step:         equ 0xCE10  ; DISPATCH_A for room_event_ce10
orb_got:                 equ 0xCE11  ; boss-clear orb collected
dracula_chunk_i:         equ 0xCE12  ; chunk velocity-table index
dracula_fade:            equ 0xCE13  ; palette-fade frame counter
orb_landed:              equ 0xCE14  ; orb settled (timeout path)
boss_dead:               equ 0xCE15  ; events 1-5: wait then boss_clear_arm
dracula_ready:           equ 0xCE16  ; event_dracula_wait gate
credits_step:            equ 0xCE40  ; 1..4 credits_tick; 0 = off

; Spawn-rate slots (stride 2: +0 counter, +1 phase/side).  spawn_rate_reset
; fills 7 slots from spawn_slot_zombie; CF04 is unused (mermen share CF02).
spawn_slot_zombie:       equ 0xCF00  ; bit0
spawn_slot_merman:       equ 0xCF02  ; green + red (bits 1-2)
spawn_slot_bat:          equ 0xCF06  ; hanging bat (bit3)
spawn_slot_skull:        equ 0xCF08  ; flying skull (bit4)
spawn_slot_ghost:        equ 0xCF0A  ; ghost head (bit5)
spawn_slot_roc:          equ 0xCF0C  ; roc (bit6)
spawn_slot_tick:         equ 0xCF10  ; shared gate divider

; Actor / shot pools (stride 0x80).  7 actors, 8 shots.
actor_slots:             equ 0xC800  ; C800, C880, … CB80
shot_slots:              equ 0xD700  ; D700 … DA80

; Destructible scenery / floor pickups (stride 0x10, 8 slots).
scenery_slots:           equ 0xC470  ; candles + 16x16 / 32x32 blocks
pickup_slots:            equ 0xC500  ; floor items / chests

; Hazards / movers / door (inside the 0xC470-0xC6FF wipe).
spike_slots:             equ 0xC580  ; 3 x 8 bytes; stage 6 room 1 only
platform_slots:          equ 0xC598  ; 2 x 7 bytes; stages 5 and 10
door_state:              equ 0xC5AC  ; 0xFF blit / 1 armed / 3 open / 0x04 court
door_y:                  equ 0xC5AD  ; pixel Y; word store also writes door_x
door_x:                  equ 0xC5AE

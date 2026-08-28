; ===========================================================================
;  banks e-f - 16K sound/portrait window @ 0x8000-0xBFFF (page_sound_banks).
;  Bank 0x0E at 0x8000 (scenery / spawn / objects / credits font / PSG driver);
;  bank 0x0F at 0xA000 (rest of psg_music, env tables, Dracula portrait).
;  Origin is set by PHASE 0x8000 in VampireKiller.asm.
;
;  Shares the CPU window with play bank 2; names here are unique (not z80dasm
;  lxxxh).  regen-seg.sh filters msx.sym per bank, so a collision at the
;  same CPU address in seg02 is fine.
;
;  Layout:
;    0x8000  scenery_list_ptr / packed per-hub candle, block, chest, vendor
;            streams (stage 0 courtyard is scenery_list_s00, not in the table)
;    0x85A6  spawn_bitmask_ptr / per-stage spawn masks
;    0x8668  object_list_ptr / packed per-hub enemy streams
;    0x8824  credits_font / credits_font_az (data/font_credits.asm)
;    0x8964  sound_tick (PSG driver; sfx_tbl 0x8D8F, music_ptr 0x8DC9)
;            then psg_sfx (to 0x949B) / psg_music (crosses 0xA000)
;    0xABF8  dracula_portrait / dracula_portrait_parts
; ===========================================================================

	INCLUDE "data/scenery_lists.asm"
	INCLUDE "data/spawn_masks.asm"
	INCLUDE "data/object_lists.asm"

    INCLUDE "data/font_credits.asm"

; ---------------------------------------------------------------------------
;  PSG driver.  play_sound (seg0) queues ids; this tick writes the AY.
;  Channel state is 20 bytes (template at seg0 0x515D).  Music bytecode
;  and sfx streams live at 0x8E2B+ (tails in seg15).
; ---------------------------------------------------------------------------

; sound_tick (seg14 0x8964): per-frame PSG driver.  int_handler pages
; segs 14+15 then calls here.  C010/C012/C014/C016 are channel ticks
; (music A/B/C + sfx); C018/C01A are the 0xFB/0xFD overlays.
; C097 = AY mixer shadow (reg 7); C098 bit0=FD, bit1=FB.
; C0A5/C0A6 = fade timer used by play_sound 0xFF.
sound_tick:
	ld a,(0c097h)                   ; AY mixer shadow
	ld e,a
	ld a,007h                       ; PSG reg 7 (mixer)
	call WRTPSG
	ld a,(0c098h)
	bit 0,a                         ; 0xFD overlay active?
	jp nz,sound_fd_tick
	bit 1,a                         ; 0xFB overlay active?
	jp nz,sound_fb_tick
	ld a,(0c0a5h)                   ; fade / 0xFF timer (lo)
	dec a
	jp m,sound_run_channels
	jp nz,sound_fade_store
	ld a,(0c0a6h)                   ; fade / 0xFF timer (hi-ish)
	dec a
	ld (0c0a6h),a
	cp 0f0h
	jp nz,sound_fade_reload
	ld hl,sound_idle
	ld (0c010h),hl
	ld (0c012h),hl
	ld (0c014h),hl
	xor a
	jp sound_fade_store
sound_fade_reload:
	ld a,03ah
sound_fade_store:
	ld (0c0a5h),a
sound_run_channels:
	xor a
	ld b,a
	ld hl,(0c010h)                  ; channel A tick
	call sound_ch_go
	ld a,001h
	ld b,a
	ld hl,(0c012h)                  ; channel B tick
	call sound_ch_go
	ld a,002h
	ld b,a
	ld hl,(0c014h)                  ; channel C tick
sound_ch_dispatch:
	call sound_ch_go
	ld a,002h
	ld b,003h
	ld hl,(0c016h)                  ; sfx tick (slot 3)

; sound_ch_go (0x89C6): A = PSG channel 0..2 (or 0 for sfx slot),
; B = slot id 0..3 (C095), HL = tick.  jp (HL).
sound_ch_go:
	ld (0c094h),a                   ; current PSG channel 0..2
	ld a,b
	ld (0c095h),a                   ; current slot 0..3
	jp (hl)                         ; run this channel's tick

; sound_idle (0x89CE): silent tick.  On the sfx slot (C095==3) it
; also clears current sfx id C096.  Replaces this slot's pointer
; with a one-shot ret and writes volume 0.
sound_idle:
	ld a,(0c095h)
	cp 003h
	jp nz,sound_idle_slot
	xor a
	ld (0c096h),a                   ; clear current sfx id
	ld a,(0c095h)
sound_idle_slot:
	rlca                            ; *2 -> word slot in C010..C016
	ld hl,0c010h
	add a,l
	ld l,a
	jr nc,sound_idle_arm
	inc h
sound_idle_arm:
	ld de,sound_idle_ret
	ld (hl),e
	inc hl
	ld (hl),d
	ld e,000h                       ; volume 0 / period 0
	jp sound_psg_vol
sound_idle_ret:
	ret

; play_sound 0xFD overlay (C098 bit0): jp (C01A) — usually sound_ch_fd.
sound_fd_tick:
	ld hl,(0c01ah)                  ; 0xFD tick pointer
	jp (hl)

; play_sound 0xFB overlay (C098 bit1): run C018 as slot 4.
sound_fb_tick:
	xor a
	ld b,004h
	ld hl,(0c018h)                  ; 0xFB tick pointer
	jp sound_ch_dispatch

; write 12-bit period DE to AY: fine = C094*2, coarse = fine+1.
sound_psg_period:
	ld a,(0c094h)
	rlca
	call WRTPSG
	inc a
	ld e,d
	jp WRTPSG

; write E to AY amplitude register 8+C094 (channels A/B/C).
sound_psg_vol:
	ld a,(0c094h)
	add a,008h                      ; amplitude regs 8/9/10
	jp WRTPSG

; mixer helpers: pick a 6-byte AND/OR table, index by C094, write AY 7.
sound_mix_mute:
	push hl
	ld hl,sound_mix_mute_tbl
	jp sound_mix_apply
sound_mix_both:
	push hl
	ld hl,sound_mix_both_tbl
	jp sound_mix_apply
sound_mix_noise:
	push hl
	ld hl,sound_mix_noise_tbl
	jp sound_mix_apply
sound_mix_tone:
	push hl
	ld hl,sound_mix_tone_tbl
sound_mix_apply:
	ld a,(0c094h)
	rlca
	add a,l
	ld l,a
	jr nc,sound_mix_pair
	inc h
sound_mix_pair:
	ld a,(0c097h)
	and (hl)               ; enable bits
	inc hl
	or (hl)                ; disable bits
	ld (0c097h),a
	pop hl
	ld e,a
	ld a,007h              ; AY mixer
	jp WRTPSG

; 3 x (AND, OR) for AY mixer reg 7.  0 = enable, 1 = disable.
; tone = enable tone / disable noise; noise = the inverse; both =
; enable both; mute = disable both.  Indexed by C094 (0=A,1=B,2=C).
sound_mix_tone_tbl:
	defb 0feh,008h         ; A enable tone, disable noise
	defb 0fdh,010h         ; B
	defb 0fbh,020h         ; C
sound_mix_noise_tbl:
	defb 0f7h,001h         ; A enable noise, disable tone
	defb 0efh,002h         ; B
	defb 0dfh,004h         ; C
sound_mix_both_tbl:
	defb 0f6h,000h         ; A tone+noise
	defb 0edh,000h         ; B
	defb 0dbh,000h         ; C
sound_mix_mute_tbl:
	defb 0ffh,009h         ; A mute
	defb 0ffh,012h         ; B
	defb 0ffh,024h         ; C

; Channel entry stubs.  20-byte state at IX; music uses C01C/C030/C044,
; sfx C058, 0xFB uses C06C, 0xFD uses C080.  +0/+1 = stream ptr,
; +2 flags, +3 duration scale, +7 octave (SRL count), +9 duration.
sound_ch_fd:
	ld ix,0c080h                    ; 0xFD state block
	jp sound_ch_tick
sound_ch_a:
	ld ix,0c01ch                    ; music A
	jp sound_ch_tick
sound_ch_b:
	ld ix,0c030h                    ; music B
	jp sound_ch_tick
sound_ch_c:
	ld ix,0c044h                    ; music C

; Common music tick.  Duration at IX+9; on expiry fetch next byte.
; Bit0 of IX+2 = tone note (vs rest/env).  If sfx id C096 is live on
; channel C, set IX+2 bit5 so music C yields the PSG to sfx.
sound_ch_tick:
	ld a,(0c095h)
	cp 002h                ; music C?
	jp nz,sound_ch_duration
	ld a,(0c096h)
	or a
	jp z,sound_ch_duration
	set 5,(ix+002h)        ; sfx live: yield PSG C
sound_ch_duration:
	dec (ix+009h)          ; duration
	jp z,sound_ch_next          ; expired -> fetch next bytecode
	bit 0,(ix+002h)        ; 1 = pitched note
	jp z,sound_ch_env_hold
	ld a,(ix+009h)
	cp (ix+00bh)           ; still in attack (before decay start)?
	jp nc,sound_ch_decay
	cp (ix+006h)           ; past decay end -> hold volume
	ret nc
sound_ch_decay:
	ld e,(ix+00ah)         ; current volume
	dec e                  ; decay 1 per tick
	ret m                  ; already 0
	ld (ix+00ah),e
	bit 5,(ix+002h)        ; sfx owns PSG C?
	ret nz
	jp sound_psg_vol
sound_ch_env_hold:
	bit 5,(ix+002h)        ; sfx owns PSG C?
	ret nz
	bit 7,(ix+002h)        ; env already finished?
	ret nz
	call sound_sfx_fetch   ; rest/env: sfx-style period stream
	ret nc                 ; NC = still holding
	set 7,(ix+002h)        ; done: mute
	ld e,000h
	jp sound_psg_vol
sound_ch_next:
	ld l,(ix+000h)         ; stream ptr
	ld h,(ix+001h)

; Music bytecode at (HL).  <0xC0 = note (hi nibble = index into the
; period table, lo = duration count * IX+3).  0xC0..CF = rest.
; >=0xD0 = command (see sound_cmd).
sound_fetch:
	ld a,(hl)
	inc hl
	ld c,a
	cp 0d0h                         ; >= 0xD0 -> command
	jp nc,sound_cmd
	ld (ix+000h),l
	ld (ix+001h),h
	cp 0c0h                         ; >= 0xC0 -> rest
	jp nc,sound_rest                ; rest, not a pitched note
	and 00fh               ; lo nibble = duration count
	inc a
	ld b,a
	ld e,(ix+003h)         ; duration scale (cmd 0xD0)
	xor a
sound_note_mul:
	add a,e                ; duration = (lo+1) * scale
	djnz sound_note_mul
	ld (ix+009h),a
	ld a,(0c095h)
	cp 002h                ; music C?
	jp nz,sound_note_go
	ld a,(0c096h)
	or a                   ; sfx live?
	jp nz,sound_note_go
	res 5,(ix+002h)        ; reclaim PSG C
sound_note_go:
	bit 0,(ix+002h)        ; 1 = pitched tone
	jp z,sound_note_env
	ld a,(ix+009h)
	sub (ix+005h)          ; decay-start offset
	ld (ix+00bh),a
	bit 5,(ix+002h)        ; sfx owns PSG C?
	ret nz
	ld a,c
	and 0f0h               ; hi nibble = note index
	rrca
	rrca
	rrca                   ; *2 -> word offset
	ld hl,sound_note_tbl
	add a,l
	ld l,a
	jr nc,sound_note_load
	inc h
sound_note_load:
	ld e,(hl)              ; period lo
	inc hl
	ld d,(hl)              ; period hi
	ld b,(ix+007h)         ; extra SRL = drop octaves
sound_note_shift:
	srl d
	rr e
	djnz sound_note_shift
	bit 6,(ix+002h)        ; detune?
	jp z,sound_note_out
	inc de                 ; +2 period
	inc de
sound_note_out:
	call sound_psg_period
	ld a,(0c0a6h)          ; fade offset
	add a,(ix+004h)        ; + base volume
	jp p,sound_note_vol
	xor a                  ; clamp 0
sound_note_vol:
	ld (ix+00ah),a         ; current volume
	ld e,a
	call sound_psg_vol
	jp sound_mix_tone
sound_note_env:
	bit 2,(ix+002h)        ; alt env table?
	jp nz,sound_env_alt
	ld hl,sound_env_ptr             ; seg15 env/period table
sound_env_index:
	ld a,c
	and 0f0h               ; hi nibble = env index
	rrca
	rrca
	rrca                   ; *2 -> word offset
	add a,l
	ld l,a
	jr nc,sound_env_write
	inc h
sound_env_write:
	ld a,(hl)
	ld (ix+00ch),a         ; env stream ptr lo
	inc hl
	ld a,(hl)
	ld (ix+00dh),a         ; env stream ptr hi
	res 7,(ix+002h)        ; not finished
	ld a,001h
	ld (ix+00eh),a         ; duration 1 -> fetch next tick
	ret
sound_env_alt:
	ld hl,sound_env_ptr_alt         ; seg15 alt env/period table
	jp sound_env_index
; One octave of AY periods (little-endian, 12 notes).  Hi nibble of a
; note byte * 2 indexes this; IX+7 extra SRL steps drop octaves.
; Noise/env notes instead use sound_env_ptr / sound_env_ptr_alt (seg15).
sound_note_tbl:
	defw 01ab8h,01938h,017d0h,01678h
	defw 01534h,01404h,012e4h,011d4h
	defw 010d4h,00fe4h,00f00h,00e28h

; Rest (bytecode 0xC0..CF): duration only, force period 0.
sound_rest:
	and 00fh               ; lo nibble = duration count
	inc a
	ld b,a
	ld e,(ix+003h)         ; duration scale
	xor a
sound_rest_mul:
	add a,e                ; duration = (lo+1) * scale
	djnz sound_rest_mul
	ld (ix+009h),a
	bit 5,(ix+002h)        ; sfx owns PSG C?
	ret nz
	ld e,000h
	ld (ix+00ah),e         ; volume 0
	jp sound_psg_vol

; Commands: 0xD0|n = duration scale (sound_cmd_scale); 0xE0|n = extended
; (sound_cmd_ext: octave / lock / detune / jump / call / return);
; lo=0xE = loop (count, addr); lo=0xF = end channel (sound_cmd_stop).
; Other lo nibbles load envelope (sound_cmd_vol -> IX+4/+5/+6).
sound_cmd:
	and 0f0h
	cp 0d0h                         ; 0xD0 | scale
	jp z,sound_cmd_scale
	cp 0e0h                         ; 0xE0 | sub-op
	jp z,sound_cmd_ext
	ld a,c
	and 00fh
	cp 00fh
	jp z,sound_cmd_stop
	cp 00eh
	jp nz,sound_cmd_vol         ; other lo = envelope params
	ld a,(ix+010h)
	dec a
	jp z,sound_loop_skip          ; loop count done -> skip addr
	jp p,sound_loop_set
	ld a,(hl)
	dec a
sound_loop_set:
	inc hl
	ld (ix+010h),a         ; loop count
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a                 ; jump to loop addr
	jp sound_fetch
sound_loop_skip:
	ld (ix+010h),a
	inc hl
	inc hl
	inc hl                 ; skip count + addr
	jp sound_fetch
sound_cmd_vol:
	inc a
	ld (ix+004h),a         ; base volume
	ld a,(hl)
	rrca
	rrca
	rrca
	rrca
	and 00fh
	dec a
	ld (ix+005h),a         ; decay start
	ld a,(hl)
	inc hl
	and 00fh
	ld (ix+006h),a         ; decay end
	jp sound_fetch
sound_cmd_scale:
	ld a,c
	and 00fh
	ld (ix+003h),a         ; duration scale
	jp sound_fetch
sound_cmd_ext:
	ld a,c
	and 00fh
	cp 006h
	jp c,sound_cmd_octave
	jp z,sound_cmd_lock
	cp 007h
	jp z,sound_cmd_detune
	cp 00ah
	jp z,sound_cmd_jump
	cp 00bh
	jp z,sound_cmd_unlock
	cp 00dh
	jp z,sound_cmd_call
	cp 00eh
	jp z,sound_cmd_return
	and 007h
	ld b,a
	ld a,(ix+002h)
	and 0f8h
	or b                   ; E0 | 8 / 9 / C: low 3 bits into IX+2 flags
	ld (ix+002h),a
	jp sound_fetch
sound_cmd_octave:
	neg
	add a,006h
	ld (ix+007h),a         ; octave = 6 - lo_nibble (SRL count)
	jp sound_fetch
sound_cmd_lock:
	ld a,001h
	ld (0c0a8h),a          ; lock (block new sfx)
	jp sound_fetch
sound_cmd_unlock:
	xor a
	ld (0c0a8h),a          ; unlock
	jp sound_fetch
sound_cmd_detune:
	set 6,(ix+002h)        ; detune (+2 period)
	jp sound_fetch
sound_cmd_jump:
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a                 ; jump to addr
	jp sound_fetch
sound_cmd_call:
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (ix+012h),l         ; call: save return
	ld (ix+013h),h
	ex de,hl
	jp sound_fetch
sound_cmd_return:
	ld l,(ix+012h)         ; return
	ld h,(ix+013h)
	jp sound_fetch
sound_cmd_stop:
	ld a,(0c095h)
	inc a
	ld b,a
	ld a,07fh
sound_cmd_stop_mask:
	rlca                   ; bit mask for this slot
	djnz sound_cmd_stop_mask
	ld b,a
	ld a,(0c0a7h)
	and b
	ld (0c0a7h),a          ; clear this channel's live bit
	jp sound_idle

; SFX / 0xFB channel.  Stream ptr at IX+0C; duration IX+0E/+0F.
; Byte 0xFF ends (CY -> idle); 0xFE = loop; 0x1x = noise period;
; 0x2x = mixer; else volume nibble + period byte.
sound_ch_fb:
	ld ix,0c06ch                    ; 0xFB state block
	jp sound_sfx_go
sound_sfx:
	ld ix,0c058h                    ; sfx state block
sound_sfx_go:
	call sound_sfx_fetch
	ret nc
	jp sound_idle
sound_sfx_fetch:
	dec (ix+00eh)
	jp nz,sound_sfx_hold
	ld a,(ix+00fh)
	ld (ix+00eh),a
	ld l,(ix+00ch)
	ld h,(ix+00dh)
sound_sfx_op:
	ld a,(hl)
	cp 0ffh                         ; 0xFF = end of sfx
	jp z,sfx_ptr                    ; CY = finished
	inc hl
	ld c,a
	cp 0feh                         ; 0xFE = sfx loop
	jp z,sound_sfx_loop
	and 0f0h
	cp 020h
	jp z,sound_sfx_mix
	cp 010h
	jp nz,sound_sfx_nibble
	ld a,c
	and 00fh
	rlca
	ld e,a
	ld a,006h              ; AY noise period
	call WRTPSG
	ld a,(hl)
	inc hl
	ld c,a
	and 0f0h
sound_sfx_nibble:
	rrca
	rrca
	rrca
	rrca
	ld e,a
	bit 4,(ix+00ah)
	jp z,sound_sfx_fade
	ld a,00dh              ; AY envelope shape
	call WRTPSG
	jp sound_sfx_tone
sound_sfx_fade:
	ld a,(0c095h)
	cp 003h
	jp nc,sound_sfx_amp
	ld a,(0c0a6h)
	add a,e
	jp p,sound_sfx_fade_ok
	xor a
sound_sfx_fade_ok:
	ld e,a
sound_sfx_amp:
	call sound_psg_vol
sound_sfx_tone:
	ld a,c
	and 00fh
	ld d,a
	ld e,(hl)
	inc hl
	ld (ix+00ch),l
	ld (ix+00dh),h
	jp sound_psg_period
sound_sfx_loop:
	ld a,(ix+011h)         ; 0xFE loop count
	dec a
	jp z,sound_sfx_loop_skip          ; count done -> skip addr
	jp p,sound_sfx_loop_set
	ld a,(hl)
	dec a
sound_sfx_loop_set:
	inc hl
	ld (ix+011h),a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a                 ; jump to loop addr
	jp sound_sfx_op
sound_sfx_loop_skip:
	ld (ix+011h),a
	inc hl
	inc hl
	inc hl                 ; skip count + addr
	jp sound_sfx_op
sound_sfx_mix:
	bit 0,c
	jp nz,sound_sfx_mix_noise
	bit 1,c
	jp nz,sound_sfx_mix_tone
	call sound_mix_mute    ; 0x20: mute
	jp sound_sfx_mix_done
sound_sfx_mix_tone:
	call sound_mix_tone    ; 0x22: tone
	jp sound_sfx_mix_done
sound_sfx_mix_noise:
	bit 1,c
	jp nz,sound_sfx_mix_both
	call sound_mix_noise   ; 0x21: noise
	jp sound_sfx_mix_done
sound_sfx_mix_both:
	call sound_mix_both    ; 0x23: tone+noise
sound_sfx_mix_done:
	ld a,c
	rlca
	and 010h
	ld (ix+00ah),a
	ld e,a
	call sound_psg_vol
	ld a,(hl)
	inc hl
	ld (ix+00eh),a
	ld (ix+00fh),a
	ld a,c
	cp 020h
	jp z,sound_sfx_hold
	cp 028h
	jp c,sound_sfx_op
	ld e,(hl)
	inc hl
	ld a,00ch              ; AY envelope period coarse
	call WRTPSG
	ld e,(hl)
	inc hl
	ld a,00bh              ; AY envelope period fine
	call WRTPSG
	jp sound_sfx_op

; NC = keep this sfx tick; CY (sfx_ptr) = finished -> idle.
sound_sfx_hold:
	or a
	ret
sfx_ptr:
	scf
	ret

; sfx_tbl (seg14 0x8D8F): word[id 1..0x1D].  play_sound does rlca
; (id*2) from sfx_ptr=0x8D8D, so id 0 would hit the `scf` byte.
sfx_tbl:
	defw sfx_01_boss_heal          ; boss_clear_heal HP drip
	defw sfx_02_vendor_withdraw
	defw sfx_03_cross_fly
	defw sfx_04_knife_throw
	defw sfx_05_whip
	defw sfx_06_axe_fly
	defw sfx_07_land               ; also merman land on solid
	defw sfx_08_merman_out
	defw sfx_09_water_in           ; merman dive; Simon pit s2/s10
	defw sfx_0a_mummy_shot
	defw sfx_0b_shield_block
	defw sfx_0c_hit                ; whip/weapon vs actor, candle, shot
	defw sfx_0d_ring_kill
	defw sfx_0e_block_break
	defw sfx_0f_heart              ; also lockpick pickup, vendor +5
	defw sfx_10_money_bag          ; also vendor leave +5000
	defw sfx_11_chest
	defw sfx_12_collect            ; default pickup / purchase
	defw sfx_13_simon_hurt
	defw sfx_14_key
	defw sfx_15_portal             ; also vertical door
	defw sfx_16_blue_gem
	defw sfx_17_gem_warn           ; C43A countdown to 0x10
	defw sfx_18_holy_water
	defw sfx_19_vendor_offer
	defw sfx_1a_door
	defw sfx_1b_white_cross
	defw sfx_1c_boss_clear         ; HP-bar enemy death; same clear as 1B
	defw sfx_1d_vendor_hearts

; music_ptr (seg14 0x8DC9): 16 records of 3 channel pointers (A,B,C).
; Index = (id & 0x7F)*6.  Ids 0x80..0x8F; 85c and 86-8F live in seg15.
music_ptr:
	defw music_80_bgm_s00_03_a,music_80_bgm_s00_03_b,music_80_bgm_s00_03_c  ; 80 bgm stages 0-3
	defw music_81_bgm_s04_06_11_12_a,music_81_bgm_s04_06_11_12_b,music_81_bgm_s04_06_11_12_c  ; 81 bgm stages 4-6 and 11-12
	defw music_82_bgm_s07_09_a,music_82_bgm_s07_09_b,music_82_bgm_s07_09_c  ; 82 bgm stages 7-9
	defw music_83_bgm_s16_17_a,music_83_bgm_s16_17_b,music_83_bgm_s16_17_c  ; 83 bgm stages 16-17
	defw music_84_bgm_s13_15_a,music_84_bgm_s13_15_b,music_84_bgm_s13_15_c  ; 84 bgm stages 13-15
	defw music_85_bgm_s10_18_a,music_85_bgm_s10_18_b,music_85_bgm_s10_18_c  ; 85 bgm stages 10 and 18
	defw music_86_bgm_boss_dracula_a,music_86_bgm_boss_dracula_b,music_86_bgm_boss_dracula_c  ; 86 Dracula boss
	defw music_87_bgm_boss_a,music_87_bgm_boss_b,music_87_bgm_boss_c  ; 87 boss
	defw music_88_bgm_boss_dracula_portrait_a,music_88_bgm_boss_dracula_portrait_b,music_88_bgm_boss_dracula_portrait_c  ; 88 Dracula portrait (CE01=4)
	defw music_89_simon_death_a,music_89_simon_death_b,music_89_simon_death_c  ; 89 Simon death
	defw music_8a_enter_castle_a,music_8a_enter_castle_b,music_8a_enter_castle_c  ; 8A enter castle
	defw music_8b_game_over_a,music_8b_game_over_b,music_8b_game_over_c  ; 8B game over
	defw music_8c_boss_defeated_a,music_8c_boss_defeated_b,music_8c_boss_defeated_c  ; 8C boss defeated
	defw music_8d_dracula_defeated_a,music_8d_dracula_defeated_b,music_8d_dracula_defeated_c  ; 8D Dracula defeated
	defw music_8e_credits_a,music_8e_credits_b,music_8e_credits_c  ; 8E credits
	defw music_8f_silence,music_8f_silence,music_8f_silence  ; 8F dummy silence

; Packed PSG: sfx then music (music_85_bgm_s10_18_b crosses 0xA000).
	INCLUDE "data/psg_sfx.asm"
	INCLUDE "data/psg_music.asm"

	INCLUDE "data/dracula_portrait.asm"

	INCLUDE "data/dracula_portrait_parts.asm"

    ASSERT $ == 0xC000


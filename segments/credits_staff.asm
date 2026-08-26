; Last ending line + staff roll (seg5 @ 0x82C0 when paged at 0x8000).
; credits_keyframe looks these up via credits_script_ptr[CE31].
;
; Keyframe: cr tick, x, "plain text"  ->  {tick, x, chars..., 0xFF}.
; Spaces in the string become 0x00 (not 0x20).  Letters/punct are ASCII
; (not HUD ASCII-0x10).  Apostrophe is ';' ("LET;S").
; tick matches CE33 (every 4th frame; also VDP R23).  x is SCREEN 5 X;
; the player `inc a`s it to test the 0xFF end-of-roll marker, so the blit
; starts at X+1.  End of roll is {0x20, 0xFF} (X slot = terminator).
;
; Story lines before this live in credits_ending.asm (seg8 @ 0xBF20).

credits_msg_life:              ; 0x82C0
	cr 0x88, 0x20, "LIFE EVER AGAIN::::"
credits_staff:                 ; 0x82D6
	cr 0x20, 0x68, "STAFF"
credits_game_designer:         ; 0x82DE
	cr 0x38, 0x28, "GAME DESIGNER"
credits_nagata:                ; 0x82EE
	cr 0x48, 0x80, "A:NAGATA"
credits_programmer:            ; 0x82F9
	cr 0x70, 0x28, "PROGRAMMER"
credits_harima:                ; 0x8306
	cr 0x80, 0x80, "A:HARIMA"
credits_akada:                 ; 0x8311
	cr 0x90, 0x80, "I:AKADA"
credits_nagae:                 ; 0x831B
	cr 0xa0, 0x80, "K:NAGAE"
credits_sound_programmer:      ; 0x8325
	cr 0xc0, 0x28, "SOUND PROGRAMMER"
credits_shikama:               ; 0x8338
	cr 0xd0, 0x80, "H:SHIKAMA"
credits_graphic_designer:      ; 0x8344
	cr 0xf0, 0x28, "GRAPHIC DESIGNER"
credits_iwamoto:               ; 0x8357
	cr 0x00, 0x80, "S:IWAMOTO"
credits_matsui:                ; 0x8363
	cr 0x10, 0x80, "N:MATSUI"
credits_mizutani:              ; 0x836E
	cr 0x20, 0x80, "K:MIZUTANI"
credits_fujimoto:              ; 0x837B
	cr 0x30, 0x80, "A:FUJIMOTO"
credits_sound_effect:          ; 0x8388
	cr 0x50, 0x28, "SOUND EFFECT BY"
credits_uehara:                ; 0x839A
	cr 0x60, 0x80, "K:UEHARA"
credits_music_by:              ; 0x83A5
	cr 0x80, 0x28, "MUSIC BY"
credits_yamashita:             ; 0x83B0
	cr 0x90, 0x80, "K:YAMASHITA"
credits_terashima:             ; 0x83BE
	cr 0xa0, 0x80, "S:TERASHIMA"
credits_art_designer:          ; 0x83CC
	cr 0xc0, 0x28, "ART DESIGNER"
credits_hayakawa:              ; 0x83DB
	cr 0xd0, 0x80, "F:HAYAKAWA"
credits_assistant:             ; 0x83E8
	cr 0xf0, 0x28, "ASSISTANT PROGRAMMER"
credits_toyohara:              ; 0x83FF
	cr 0x00, 0x80, "K:TOYOHARA"
credits_oka:                   ; 0x840C
	cr 0x10, 0x80, "T:OKA"
credits_eda:                   ; 0x8414
	cr 0x20, 0x80, "H:EDA"
credits_ohtsuka:               ; 0x841C
	cr 0x30, 0x80, "T:OHTSUKA"
credits_danjyo:                ; 0x8428
	cr 0x40, 0x80, "T:DANJYO"
credits_special_thanks:        ; 0x8433
	cr 0x60, 0x28, "SPECIAL THANKS"
credits_hiraoka:               ; 0x8444
	cr 0x70, 0x80, "K:HIRAOKA"
credits_fc_team:               ; 0x8450
	cr 0x80, 0x80, "FC:TEAM"
credits_produced_by:           ; 0x845A
	cr 0xd0, 0x50, "PRODUCED BY"
credits_akihiko_nagata:        ; 0x8468
	cr 0xe0, 0x40, "AKIHIKO  NAGATA"
credits_presented_by:          ; 0x847A
	cr 0xb0, 0x30, "PRESENTED BY  KONAMI"
credits_script_end:            ; 0x8491  {tick=0x20, 0xFF}
	defb 0x20, 0xFF

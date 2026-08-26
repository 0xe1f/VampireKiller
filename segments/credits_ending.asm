; Ending message (seg8 @ 0xBF20 when paged at 0xA000).
; credits_keyframe looks these up via credits_script_ptr[CE31].
;
; Keyframe: cr tick, x, "plain text"  ->  {tick, x, chars..., 0xFF}.
; Spaces in the string become 0x00 (not 0x20).  Letters/punct are ASCII
; (not HUD ASCII-0x10).  Apostrophe is ';' ("LET;S").
; tick matches CE33 (every 4th frame; also VDP R23).  x is SCREEN 5 X;
; the player `inc a`s it to test the 0xFF end-of-roll marker, so the blit
; starts at X+1.
;
; Last story line ("LIFE EVER AGAIN::::") and the staff roll live in
; credits_staff.asm (seg5 @ 0x82C0).

credits_msg_brave:             ; 0xBF20
	cr 0x08, 0x20, "SO THE BRAVE YOUNG MAN"
credits_msg_put:               ; 0xBF39
	cr 0x18, 0x20, "PUT DRACULA INTO DEEP"
credits_msg_sleep:             ; 0xBF51
	cr 0x28, 0x20, "SLEEP AGAIN AND THE TOWN"
credits_msg_peace:             ; 0xBF6C
	cr 0x38, 0x20, "RESTORED ITS PEACE:"
credits_msg_pray:              ; 0xBF82
	cr 0x58, 0x20, "LET;S PRAY THAT THE EVIL"
credits_msg_humanbeings:       ; 0xBF9D
	cr 0x68, 0x20, "MIND OF HUMANBEINGS WILL"
credits_msg_come:              ; 0xBFB8
	cr 0x78, 0x20, "NOT LET DRACULA COME TO"

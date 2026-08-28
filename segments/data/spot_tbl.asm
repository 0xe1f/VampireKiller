; Crouch-UP portal spots (seg13 0xBBCD).  (stage, dest<<4|room, Y, X), 0xFF end.

spot_tbl:                        ; (seg13 0xBBCD) (stage, dest<<4|room, Y, X), 0xFF end
	defb 00ch,030h,0a8h,058h ; stage 12 room 0 dest=3 Y=0xA8 X=0x58
	defb 00ch,041h,088h,0b8h ; stage 12 room 1 dest=4 Y=0x88 X=0xB8
	defb 00ch,0b2h,0a8h,098h ; stage 12 room 2 dest=11 Y=0xA8 X=0x98
	defb 00ch,003h,0a8h,058h ; stage 12 room 3 dest=0 Y=0xA8 X=0x58
	defb 00ch,014h,088h,0b8h ; stage 12 room 4 dest=1 Y=0x88 X=0xB8
	defb 00ch,085h,0a8h,058h ; stage 12 room 5 dest=8 Y=0xA8 X=0x58
	defb 00ch,0a7h,0a8h,038h ; stage 12 room 7 dest=10 Y=0xA8 X=0x38
	defb 00ch,058h,0a8h,058h ; stage 12 room 8 dest=5 Y=0xA8 X=0x58
	defb 00ch,07ah,0a8h,038h ; stage 12 room 10 dest=7 Y=0xA8 X=0x38
	defb 00ch,02bh,0a8h,098h ; stage 12 room 11 dest=2 Y=0xA8 X=0x98
	defb 0ffh                ; end


; White-key door placements (seg13 0xBB61).  19x3: (room | vert<<7), Y, X.

door_tbl:                        ; (seg13 0xBB61) 19x3: (room | vert<<7), Y, X
	defb 042h,090h,0e0h    ;  0: room 2 open Y=0x90 X=0xE0  byte0=0x42
	defb 087h,030h,0ech    ;  1: room 7 vert Y=0x30 X=0xEC
	defb 081h,030h,0ech    ;  2: room 1 vert Y=0x30 X=0xEC
	defb 084h,080h,0ech    ;  3: room 4 vert Y=0x80 X=0xEC
	defb 083h,030h,00ch    ;  4: room 3 vert Y=0x30 X=0x0C
	defb 085h,050h,00ch    ;  5: room 5 vert Y=0x50 X=0x0C
	defb 084h,050h,00ch    ;  6: room 4 vert Y=0x50 X=0x0C
	defb 086h,060h,0ech    ;  7: room 6 vert Y=0x60 X=0xEC
	defb 087h,040h,0ech    ;  8: room 7 vert Y=0x40 X=0xEC
	defb 088h,080h,00ch    ;  9: room 8 vert Y=0x80 X=0x0C
	defb 088h,080h,0ech    ; 10: room 8 vert Y=0x80 X=0xEC
	defb 085h,080h,0ech    ; 11: room 5 vert Y=0x80 X=0xEC
	defb 085h,080h,0ech    ; 12: room 5 vert Y=0x80 X=0xEC
	defb 088h,080h,00ch    ; 13: room 8 vert Y=0x80 X=0x0C
	defb 087h,080h,00ch    ; 14: room 7 vert Y=0x80 X=0x0C
	defb 088h,080h,00ch    ; 15: room 8 vert Y=0x80 X=0x0C
	defb 085h,040h,00ch    ; 16: room 5 vert Y=0x40 X=0x0C
	defb 08bh,040h,00ch    ; 17: room 11 vert Y=0x40 X=0x0C
	defb 088h,080h,00ch    ; 18: room 8 vert Y=0x80 X=0x0C


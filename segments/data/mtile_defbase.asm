; mtile_defbase (seg11 0x7EBB): word[stage] -> 4x4 metatile-def table.
; Address window selects the bank: 0x6000=seg11, 0x8000=seg12, 0xA000=seg13.
; Tables can straddle the 0x8000/0xA000 boundary (roomperm treats 0x0B/0C/0D
; as one 0x6000-0xBFFF buffer).
mtile_defbase:
	defw 07ee1h,080b1h,080b1h,080b1h,084d1h,084d1h,084d1h,08791h
	defw 08791h,08791h,08d21h,08d21h,08d21h,09121h,09121h,09121h
	defw 09651h,09651h,09ac1h


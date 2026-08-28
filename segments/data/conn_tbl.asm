; Room-transition nibble tables (seg13).  2 bytes per room: UD / LR.
; 0xF = blocked.  Indexed by conn_ptr[stage] + 2*D001.

conn_ptr:                        ; (seg13 0xB9D3) word[stage] -> conn_sNN
	defw conn_s00
	defw conn_s01
	defw conn_s02
	defw conn_s03
	defw conn_s04
	defw conn_s05
	defw conn_s06
	defw conn_s07
	defw conn_s08
	defw conn_s09
	defw conn_s10
	defw conn_s11
	defw conn_s12
	defw conn_s13
	defw conn_s14
	defw conn_s15
	defw conn_s16
	defw conn_s17
	defw conn_s18

; --- stage 0 (3 rooms) ---
conn_s00:
	defb 0ffh,0f1h         ; 0:  U=F D=F L=F R=1
	defb 0ffh,002h         ; 1:  U=F D=F L=0 R=2
	defb 0ffh,01fh         ; 2:  U=F D=F L=1 R=F
; --- stage 1 (8 rooms) ---
conn_s01:
	defb 0ffh,031h         ; 0:  U=F D=F L=3 R=1
	defb 05fh,002h         ; 1:  U=5 D=F L=0 R=2
	defb 0ffh,013h         ; 2:  U=F D=F L=1 R=3
	defb 07fh,020h         ; 3:  U=7 D=F L=2 R=0
	defb 0ffh,0f5h         ; 4:  U=F D=F L=F R=5
	defb 0f1h,046h         ; 5:  U=F D=1 L=4 R=6
	defb 0ffh,057h         ; 6:  U=F D=F L=5 R=7
	defb 0f3h,06fh         ; 7:  U=F D=3 L=6 R=F
; --- stage 2 (6 rooms) ---
conn_s02:
	defb 024h,0f1h         ; 0:  U=2 D=4 L=F R=1
	defb 0f5h,00fh         ; 1:  U=F D=5 L=0 R=F
	defb 0f0h,033h         ; 2:  U=F D=0 L=3 R=3
	defb 0ffh,022h         ; 3:  U=F D=F L=2 R=2
	defb 00fh,0f5h         ; 4:  U=0 D=F L=F R=5
	defb 01fh,04fh         ; 5:  U=1 D=F L=4 R=F
; --- stage 3 (6 rooms) ---
conn_s03:
	defb 0f4h,031h         ; 0:  U=F D=4 L=3 R=1
	defb 0ffh,002h         ; 1:  U=F D=F L=0 R=2
	defb 0ffh,013h         ; 2:  U=F D=F L=1 R=3
	defb 0ffh,020h         ; 3:  U=F D=F L=2 R=0
	defb 00fh,0f5h         ; 4:  U=0 D=F L=F R=5
	defb 0ffh,0ffh         ; 5:  U=F D=F L=F R=F
; --- stage 4 (6 rooms) ---
conn_s04:
	defb 0ffh,021h         ; 0:  U=F D=F L=2 R=1
	defb 04fh,002h         ; 1:  U=4 D=F L=0 R=2
	defb 05fh,010h         ; 2:  U=5 D=F L=1 R=0
	defb 0f0h,0f4h         ; 3:  U=F D=0 L=F R=4
	defb 0f1h,035h         ; 4:  U=F D=1 L=3 R=5
	defb 0f2h,04fh         ; 5:  U=F D=2 L=4 R=F
; --- stage 5 (6 rooms) ---
conn_s05:
	defb 0ffh,01fh         ; 0:  U=F D=F L=1 R=F
	defb 0ffh,020h         ; 1:  U=F D=F L=2 R=0
	defb 05fh,0f1h         ; 2:  U=5 D=F L=F R=1
	defb 0ffh,04fh         ; 3:  U=F D=F L=4 R=F
	defb 0f1h,053h         ; 4:  U=F D=1 L=5 R=3
	defb 0f2h,0f4h         ; 5:  U=F D=2 L=F R=4
; --- stage 6 (6 rooms) ---
conn_s06:
	defb 03fh,01fh         ; 0:  U=3 D=F L=1 R=F
	defb 0ffh,020h         ; 1:  U=F D=F L=2 R=0
	defb 0ffh,0f1h         ; 2:  U=F D=F L=F R=1
	defb 0f0h,04fh         ; 3:  U=F D=0 L=4 R=F
	defb 0ffh,053h         ; 4:  U=F D=F L=5 R=3
	defb 0ffh,0ffh         ; 5:  U=F D=F L=F R=F
; --- stage 7 (9 rooms) ---
conn_s07:
	defb 0ffh,01fh         ; 0:  U=F D=F L=1 R=F
	defb 0ffh,020h         ; 1:  U=F D=F L=2 R=0
	defb 05fh,0f1h         ; 2:  U=5 D=F L=F R=1
	defb 0ffh,04fh         ; 3:  U=F D=F L=4 R=F
	defb 0ffh,053h         ; 4:  U=F D=F L=5 R=3
	defb 082h,0f4h         ; 5:  U=8 D=2 L=F R=4
	defb 0f3h,07fh         ; 6:  U=F D=3 L=7 R=F
	defb 0f4h,086h         ; 7:  U=F D=4 L=8 R=6
	defb 0f5h,0f7h         ; 8:  U=F D=5 L=F R=7
; --- stage 8 (8 rooms) ---
conn_s08:
	defb 0ffh,0f1h         ; 0:  U=F D=F L=F R=1
	defb 0ffh,002h         ; 1:  U=F D=F L=0 R=2
	defb 05fh,01fh         ; 2:  U=5 D=F L=1 R=F
	defb 0ffh,0f4h         ; 3:  U=F D=F L=F R=4
	defb 0f7h,03fh         ; 4:  U=F D=7 L=3 R=F
	defb 0f2h,0f6h         ; 5:  U=F D=2 L=F R=6
	defb 0f3h,057h         ; 6:  U=F D=3 L=5 R=7
	defb 0f4h,06fh         ; 7:  U=F D=4 L=6 R=F
; --- stage 9 (9 rooms) ---
conn_s09:
	defb 0ffh,0f1h         ; 0:  U=F D=F L=F R=1
	defb 0ffh,002h         ; 1:  U=F D=F L=0 R=2
	defb 0ffh,013h         ; 2:  U=F D=F L=1 R=3
	defb 0ffh,024h         ; 3:  U=F D=F L=2 R=4
	defb 0ffh,035h         ; 4:  U=F D=F L=3 R=5
	defb 068h,04fh         ; 5:  U=6 D=8 L=4 R=F
	defb 0f5h,0ffh         ; 6:  U=F D=5 L=F R=F
	defb 0ffh,0ffh         ; 7:  U=F D=F L=F R=F
	defb 05fh,07fh         ; 8:  U=5 D=F L=7 R=F
; --- stage 10 (9 rooms) ---
conn_s10:
	defb 0ffh,051h         ; 0:  U=F D=F L=5 R=1
	defb 06fh,002h         ; 1:  U=6 D=F L=0 R=2
	defb 0ffh,013h         ; 2:  U=F D=F L=1 R=3
	defb 0ffh,024h         ; 3:  U=F D=F L=2 R=4
	defb 0ffh,035h         ; 4:  U=F D=F L=3 R=5
	defb 08fh,040h         ; 5:  U=8 D=F L=4 R=0
	defb 0f1h,077h         ; 6:  U=F D=1 L=7 R=7
	defb 0ffh,066h         ; 7:  U=F D=F L=6 R=6
	defb 0f5h,0ffh         ; 8:  U=F D=5 L=F R=F
; --- stage 11 (6 rooms) ---
conn_s11:
	defb 0ffh,0f1h         ; 0:  U=F D=F L=F R=1
	defb 0ffh,002h         ; 1:  U=F D=F L=0 R=2
	defb 0ffh,013h         ; 2:  U=F D=F L=1 R=3
	defb 0ffh,024h         ; 3:  U=F D=F L=2 R=4
	defb 0ffh,035h         ; 4:  U=F D=F L=3 R=5
	defb 0ffh,04fh         ; 5:  U=F D=F L=4 R=F
; --- stage 12 (12 rooms) ---
conn_s12:
	defb 0ffh,021h         ; 0:  U=F D=F L=2 R=1
	defb 0ffh,002h         ; 1:  U=F D=F L=0 R=2
	defb 0ffh,010h         ; 2:  U=F D=F L=1 R=0
	defb 0ffh,0f4h         ; 3:  U=F D=F L=F R=4
	defb 0ffh,035h         ; 4:  U=F D=F L=3 R=5
	defb 0ffh,046h         ; 5:  U=F D=F L=4 R=6
	defb 0ffh,0ffh         ; 6:  U=F D=F L=F R=F
	defb 0ffh,088h         ; 7:  U=F D=F L=8 R=8
	defb 0ffh,077h         ; 8:  U=F D=F L=7 R=7
	defb 0ffh,0bah         ; 9:  U=F D=F L=11 R=10
	defb 0ffh,09bh         ; 10: U=F D=F L=9 R=11
	defb 0ffh,0a9h         ; 11: U=F D=F L=10 R=9
; --- stage 13 (12 rooms) ---
conn_s13:
	defb 03fh,0f1h         ; 0:  U=3 D=F L=F R=1
	defb 0ffh,002h         ; 1:  U=F D=F L=0 R=2
	defb 057h,01fh         ; 2:  U=5 D=7 L=1 R=F
	defb 0f0h,064h         ; 3:  U=F D=0 L=6 R=4
	defb 0ffh,035h         ; 4:  U=F D=F L=3 R=5
	defb 0f2h,046h         ; 5:  U=F D=2 L=4 R=6
	defb 0bfh,053h         ; 6:  U=11 D=F L=5 R=3
	defb 029h,0ffh         ; 7:  U=2 D=9 L=F R=F
	defb 0ffh,0f9h         ; 8:  U=F D=F L=F R=9
	defb 07fh,08ah         ; 9:  U=7 D=F L=8 R=10
	defb 0fbh,09fh         ; 10: U=F D=11 L=9 R=F
	defb 0a6h,09fh         ; 11: U=10 D=6 L=9 R=F
; --- stage 14 (8 rooms) ---
conn_s14:
	defb 03fh,0ffh         ; 0:  U=3 D=F L=F R=F
	defb 0ffh,02fh         ; 1:  U=F D=F L=2 R=F
	defb 0f5h,0f1h         ; 2:  U=F D=5 L=F R=1
	defb 0f0h,04fh         ; 3:  U=F D=0 L=4 R=F
	defb 0f1h,053h         ; 4:  U=F D=1 L=5 R=3
	defb 0ffh,064h         ; 5:  U=F D=F L=6 R=4
	defb 0ffh,075h         ; 6:  U=F D=F L=7 R=5
	defb 0ffh,0f6h         ; 7:  U=F D=F L=F R=6
; --- stage 15 (10 rooms) ---
conn_s15:
	defb 02fh,01fh         ; 0:  U=2 D=F L=1 R=F
	defb 0ffh,0f0h         ; 1:  U=F D=F L=F R=0
	defb 040h,033h         ; 2:  U=4 D=0 L=3 R=3
	defb 0ffh,022h         ; 3:  U=F D=F L=2 R=2
	defb 072h,055h         ; 4:  U=7 D=2 L=5 R=5
	defb 0f3h,044h         ; 5:  U=F D=3 L=4 R=4
	defb 0ffh,07fh         ; 6:  U=F D=F L=7 R=F
	defb 0f4h,086h         ; 7:  U=F D=4 L=8 R=6
	defb 0f5h,097h         ; 8:  U=F D=5 L=9 R=7
	defb 0ffh,0ffh         ; 9:  U=F D=F L=F R=F
; --- stage 16 (10 rooms) ---
conn_s16:
	defb 0f6h,01fh         ; 0:  U=F D=6 L=1 R=F
	defb 0f7h,020h         ; 1:  U=F D=7 L=2 R=0
	defb 0f8h,031h         ; 2:  U=F D=8 L=3 R=1
	defb 0f9h,042h         ; 3:  U=F D=9 L=4 R=2
	defb 0ffh,053h         ; 4:  U=F D=F L=5 R=3
	defb 0ffh,0f4h         ; 5:  U=F D=F L=F R=4
	defb 00fh,07fh         ; 6:  U=0 D=F L=7 R=F
	defb 0ffh,086h         ; 7:  U=F D=F L=8 R=6
	defb 0ffh,097h         ; 8:  U=F D=F L=9 R=7
	defb 0ffh,0f8h         ; 9:  U=F D=F L=F R=8
; --- stage 17 (12 rooms) ---
conn_s17:
	defb 03fh,01fh         ; 0:  U=3 D=F L=1 R=F
	defb 04fh,020h         ; 1:  U=4 D=F L=2 R=0
	defb 05fh,0f1h         ; 2:  U=5 D=F L=F R=1
	defb 0f0h,04fh         ; 3:  U=F D=0 L=4 R=F
	defb 0f1h,053h         ; 4:  U=F D=1 L=5 R=3
	defb 062h,0f4h         ; 5:  U=6 D=2 L=F R=4
	defb 095h,07fh         ; 6:  U=9 D=5 L=7 R=F
	defb 0afh,086h         ; 7:  U=10 D=F L=8 R=6
	defb 0bfh,0f7h         ; 8:  U=11 D=F L=F R=7
	defb 0f6h,0afh         ; 9:  U=F D=6 L=10 R=F
	defb 0f7h,0b9h         ; 10: U=F D=7 L=11 R=9
	defb 0f8h,0ffh         ; 11: U=F D=8 L=F R=F
; --- stage 18 (10 rooms) ---
conn_s18:
	defb 0ffh,01fh         ; 0:  U=F D=F L=1 R=F
	defb 0ffh,020h         ; 1:  U=F D=F L=2 R=0
	defb 03fh,0f1h         ; 2:  U=3 D=F L=F R=1
	defb 052h,0ffh         ; 3:  U=5 D=2 L=F R=F
	defb 065h,055h         ; 4:  U=6 D=5 L=5 R=5
	defb 043h,044h         ; 5:  U=4 D=3 L=4 R=4
	defb 074h,0ffh         ; 6:  U=7 D=4 L=F R=F
	defb 0f6h,08fh         ; 7:  U=F D=6 L=8 R=F
	defb 0ffh,097h         ; 8:  U=F D=F L=9 R=7
	defb 0ffh,0ffh         ; 9:  U=F D=F L=F R=F

; door_load (seg13 0xBB31): paged entry from door_load_paged (seg0 0x5A47).
; Loads the white-key door (C5AC-C5AE) then the C5B1 spot, if any.


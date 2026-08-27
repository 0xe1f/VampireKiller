; credits_font (seg14 0x8824): 40 x 8x8 1bpp glyphs for the ending message
; and credits.  Loaded by credits_font_load (seg0 0x53E5) from credits_init.
; First 14 at VRAM dest DE=0x8040 (digits 0-9, then . ' : ,); A-Z at
; DE=0x0848.  Each defb is one row, MSB = left pixel.
; Preview: gfx/fonts/font_credits.png.  Source: data/font_credits.asm.
credits_font:
; '0'
	defb %01111100
	defb %11000100
	defb %10000110
	defb %10000010
	defb %11000010
	defb %01000110
	defb %01111100
	defb %00000000

; '1'
	defb %00011000
	defb %00110000
	defb %00010000
	defb %00010000
	defb %00010000
	defb %00100000
	defb %00111000
	defb %00000000

; '2'
	defb %01111100
	defb %10000010
	defb %11000010
	defb %00011100
	defb %01100000
	defb %10000010
	defb %11111110
	defb %00000000

; '3'
	defb %01111100
	defb %10000010
	defb %00000110
	defb %00011000
	defb %00000110
	defb %10000010
	defb %01111100
	defb %00000000

; '4'
	defb %00001110
	defb %00010010
	defb %00100100
	defb %01000100
	defb %10000110
	defb %11111010
	defb %00000110
	defb %00000000

; '5'
	defb %11111110
	defb %01000000
	defb %01111000
	defb %11000110
	defb %00000010
	defb %11000010
	defb %00111100
	defb %00000000

; '6'
	defb %00111100
	defb %01000000
	defb %10111100
	defb %11000110
	defb %10000010
	defb %10000110
	defb %01111100
	defb %00000000

; '7'
	defb %11111110
	defb %10000010
	defb %01000100
	defb %00001000
	defb %00001000
	defb %00010000
	defb %00011000
	defb %00000000

; '8'
	defb %01111100
	defb %10000110
	defb %10000010
	defb %01111100
	defb %10000010
	defb %11000010
	defb %01111100
	defb %00000000

; '9'
	defb %01111100
	defb %11000010
	defb %10000010
	defb %11000110
	defb %01111010
	defb %00000100
	defb %01111000
	defb %00000000

; '.'
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %01100000
	defb %01100000
	defb %00000000

; "'"
	defb %01100000
	defb %01100000
	defb %00100000
	defb %01000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000

; ':'
	defb %00000000
	defb %00011000
	defb %00011000
	defb %00000000
	defb %00011000
	defb %00011000
	defb %00000000
	defb %00000000

; ','
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00110000
	defb %00110000
	defb %00010000
	defb %00100000

; A-Z (seg14 0x8894)
credits_font_az:
; 'A'
	defb %00111000
	defb %01000100
	defb %01000100
	defb %10000010
	defb %11100010
	defb %10011110
	defb %11000110
	defb %00000000

; 'B'
	defb %11111100
	defb %10000010
	defb %01000100
	defb %01111000
	defb %01000100
	defb %10000010
	defb %11111100
	defb %00000000

; 'C'
	defb %00111100
	defb %01000110
	defb %10000000
	defb %10000000
	defb %10000000
	defb %01000110
	defb %00111100
	defb %00000000

; 'D'
	defb %11111000
	defb %10000100
	defb %01000010
	defb %01000010
	defb %01000010
	defb %10000100
	defb %11111000
	defb %00000000

; 'E'
	defb %11111100
	defb %10000110
	defb %01000000
	defb %01111000
	defb %01000000
	defb %10000110
	defb %11111100
	defb %00000000

; 'F'
	defb %11111100
	defb %10000110
	defb %01000000
	defb %01111000
	defb %01000000
	defb %10000000
	defb %11000000
	defb %00000000

; 'G'
	defb %00111100
	defb %01000110
	defb %10000000
	defb %10001110
	defb %10000010
	defb %01000110
	defb %00111100
	defb %00000000

; 'H'
	defb %11000110
	defb %10000010
	defb %01000100
	defb %01111100
	defb %01000100
	defb %10000010
	defb %11000110
	defb %00000000

; 'I'
	defb %00111000
	defb %00100000
	defb %00010000
	defb %00010000
	defb %00010000
	defb %00001000
	defb %00111000
	defb %00000000

; 'J'
	defb %00001110
	defb %00000010
	defb %00000100
	defb %10000100
	defb %10000100
	defb %11001100
	defb %01111000
	defb %00000000

; 'K'
	defb %11000110
	defb %10001100
	defb %01010000
	defb %01100000
	defb %01010000
	defb %10010000
	defb %11001110
	defb %00000000

; 'L'
	defb %11000000
	defb %10000000
	defb %01000000
	defb %01000000
	defb %01000010
	defb %10000110
	defb %11111100
	defb %00000000

; 'M'
	defb %11000110
	defb %01000100
	defb %01101100
	defb %01010100
	defb %01010100
	defb %10000010
	defb %11000110
	defb %00000000

; 'N'
	defb %11000110
	defb %01000010
	defb %01100100
	defb %01010100
	defb %01001100
	defb %10000100
	defb %11000110
	defb %00000000

; 'O'
	defb %00111100
	defb %01000110
	defb %11000010
	defb %10000010
	defb %10000110
	defb %11000100
	defb %01111000
	defb %00000000

; 'P'
	defb %11111100
	defb %10000110
	defb %01000010
	defb %01000110
	defb %01111100
	defb %10000000
	defb %11000000
	defb %00000000

; 'Q'
	defb %00111100
	defb %01000110
	defb %11000010
	defb %10000010
	defb %10011110
	defb %11000100
	defb %01111110
	defb %00000000

; 'R'
	defb %11111100
	defb %10000010
	defb %01000010
	defb %01111100
	defb %01001000
	defb %10001000
	defb %11000110
	defb %00000000

; 'S'
	defb %01111100
	defb %10000110
	defb %11000000
	defb %01111100
	defb %00000110
	defb %11000010
	defb %01111100
	defb %00000000

; 'T'
	defb %01111100
	defb %10010010
	defb %00010000
	defb %00010000
	defb %00010000
	defb %00001000
	defb %00111000
	defb %00000000

; 'U'
	defb %11000110
	defb %10000010
	defb %01000100
	defb %10000010
	defb %10000010
	defb %11000110
	defb %01111100
	defb %00000000

; 'V'
	defb %11000110
	defb %10000010
	defb %01000100
	defb %01000100
	defb %01101100
	defb %00101000
	defb %00111000
	defb %00000000

; 'W'
	defb %11000110
	defb %10010010
	defb %01010100
	defb %01010100
	defb %01101100
	defb %11000110
	defb %10000010
	defb %00000000

; 'X'
	defb %11000110
	defb %10000010
	defb %01000100
	defb %00111000
	defb %01000100
	defb %10000010
	defb %11000110
	defb %00000000

; 'Y'
	defb %11000110
	defb %10000010
	defb %01000100
	defb %00101000
	defb %00010000
	defb %00001000
	defb %00111000
	defb %00000000

; 'Z'
	defb %11111110
	defb %10000010
	defb %00011100
	defb %00010000
	defb %01110000
	defb %10000010
	defb %11111110
	defb %00000000

; Intro sky RLE (seg13 0xB895), loaded to VRAM 0xFA00.
; 8 cloud patterns + 2-frame bat flap.  gfx/intro_sky.
; Pixel bytes are defb %xxxxxxxx (MSB=left); counts stay hex.
intro_sky:
	defb 0x02, %00000000
	defb 0x89
	defb %00000001
	defb %00000111
	defb %00011111
	defb %00111111
	defb %01111111
	defb %01111111
	defb %00111111
	defb %00111100
	defb %00011110
	defb 0x06, %00000000
	defb 0x82
	defb %00000001
	defb %11100111
	defb 0x04, %11111111
	defb 0x8b
	defb %11111110
	defb %11111111
	defb %11111111
	defb %00111111
	defb %11111110
	defb %11011000
	defb %01100000
	defb %00000000
	defb %00000000
	defb %00001100
	defb %11011111
	defb 0x04, %11111111
	defb 0x84
	defb %11111011
	defb %01100111
	defb %10001111
	defb %11011111
	defb 0x03, %00011111
	defb 0x81
	defb %00001100
	defb 0x04, %00000000
	defb 0x02, %10000000
	defb 0x82
	defb %10001100
	defb %11011111
	defb 0x05, %11111111
	defb 0x84
	defb %10011111
	defb %00111110
	defb %00100100
	defb %00011000
	defb 0x03, %00000000
	defb 0x82
	defb %00011100
	defb %01111111
	defb 0x03, %11111111
	defb 0x86
	defb %01111111
	defb %00111111
	defb %00011111
	defb %10000111
	defb %01111101
	defb %01111000
	defb 0x05, %00000000
	defb 0x83
	defb %00111000
	defb %11111100
	defb %11111110
	defb 0x03, %11111111
	defb 0x84
	defb %10111111
	defb %11011111
	defb %11001111
	defb %10000000
	defb 0x09, %00000000
	defb 0x85
	defb %01110000
	defb %11111110
	defb %11111111
	defb %10111111
	defb %10011011
	defb 0x0d, %00000000
	defb 0x82
	defb %11111100
	defb %11100000
	defb 0x0f, %00000000
	defb 0x88
	defb %01000000
	defb %01000011
	defb %01100001
	defb %00111111
	defb %00011111
	defb %00000011
	defb %00000011
	defb %00000001
	defb 0x07, %00000000
	defb 0x89
	defb %00000001
	defb %00000000
	defb %00000000
	defb %11000000
	defb %00000001
	defb %00100111
	defb %10011110
	defb %11111100
	defb %11110000
; 16x16 +0xA0
	defb 0x06, %00000000
	defb 0x89
	defb %00000100
	defb %10011000
	defb %01110000
	defb %00100000
	defb %11100000
	defb %11100000
	defb %01100000
	defb %00110011
	defb %00011111
	defb 0x0c, %00000000
	defb 0x85
	defb %01100000
	defb %11000001
	defb %11011011
	defb %11100110
	defb %11111100
; 16x16 +0xC0
	defb 0x07, %00000000
	defb 0x87
	defb %10000000
	defb %11000000
	defb %11100000
	defb %01111000
	defb %10000010
	defb %10000110
	defb %01111100
	defb 0x0a, %00000000
	defb 0x85
	defb %01000000
	defb %00100000
	defb %00110000
	defb %00011111
	defb %00001111
	defb 0x0b, %00000000
	defb 0x84
	defb %01000000
	defb %01100100
	defb %11111111
	defb %11110000
	defb 0x0c, %00000000
	defb 0x82
	defb %00010000
	defb %11000000
	defb 0x0f, %00000000
	defb 0x87
	defb %00001100
	defb %00001110
	defb %00001110
	defb %00000110
	defb %00000011
	defb %00000011
	defb %00000001
	defb 0x09, %00000000
	defb 0x87
	defb %00110000
	defb %01110000
	defb %01110000
	defb %01100000
	defb %11000000
	defb %11000000
	defb %10000000
; 16x16 +0x120
	defb 0x0b, %00000000
	defb 0x85
	defb %00001010
	defb %00001111
	defb %00001111
	defb %00001101
	defb %00001000
	defb 0x0b, %00000000
	defb 0x85
	defb %01010000
	defb %11110000
	defb %11110000
	defb %10110000
	defb %00010000
	defb 0x00

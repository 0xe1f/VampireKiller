; HUD / title font (seg8 0xBD80): 48 x 8x8 1bpp glyphs, ASCII '0'..'_'.
; HUD/title strings are vk (ASCII-0x10); space is 0x00 (copies the
; ink-0 blit of hud_font_solid at VRAM (0,0)).  hud_font_load
; (seg0 0x53BD) expands these via glyph_blit_run to page 1 at Y=0x40,
; ink 0x0E.  Drawing is HMMM from that atlas (sub_4aeeh, Y += 0x38).
; Each defb is one row, MSB = left pixel.  Not the credits font.
; Preview: gfx/fonts/font_hud.png.  Source: data/font_hud.asm.
hud_font:

; '0'
	defb %00000000
	defb %00011100
	defb %00100010
	defb %01100011
	defb %01100011
	defb %01100011
	defb %00100010
	defb %00011100

; '1'
	defb %00000000
	defb %00011000
	defb %00111000
	defb %00011000
	defb %00011000
	defb %00011000
	defb %00011000
	defb %01111110

; '2'
	defb %00000000
	defb %00111110
	defb %01100011
	defb %00000011
	defb %00001110
	defb %00111100
	defb %01110000
	defb %01111111

; '3'
	defb %00000000
	defb %00111110
	defb %01100011
	defb %00000011
	defb %00001110
	defb %00000011
	defb %01100011
	defb %00111110

; '4'
	defb %00000000
	defb %00001110
	defb %00011110
	defb %00110110
	defb %01100110
	defb %01100110
	defb %01111111
	defb %00000110

; '5'
	defb %00000000
	defb %01111111
	defb %01100000
	defb %01111110
	defb %01100011
	defb %00000011
	defb %01100011
	defb %00111110

; '6'
	defb %00000000
	defb %00111110
	defb %01100011
	defb %01100000
	defb %01111110
	defb %01100011
	defb %01100011
	defb %00111110

; '7'
	defb %00000000
	defb %01111111
	defb %01100011
	defb %00000110
	defb %00001100
	defb %00011000
	defb %00011000
	defb %00011000

; '8'
	defb %00000000
	defb %00111110
	defb %01100011
	defb %01100011
	defb %00111110
	defb %01100011
	defb %01100011
	defb %00111110

; '9'
	defb %00000000
	defb %00111110
	defb %01100011
	defb %01100011
	defb %00111111
	defb %00000011
	defb %01100011
	defb %00111110

; ':'  (face)
	defb %00111100
	defb %01000010
	defb %10011001
	defb %10100001
	defb %10100001
	defb %10011001
	defb %01000010
	defb %00111100

; ';'
	defb %00000000
	defb %00000011
	defb %00000011
	defb %00000011
	defb %00000011
	defb %00000011
	defb %00000011
	defb %00000011

; '<'
	defb %00011100
	defb %00111000
	defb %01110000
	defb %11100001
	defb %11001101
	defb %11001101
	defb %11111101
	defb %01111001

; '='
	defb %00000000
	defb %00000000
	defb %00000000
	defb %11101110
	defb %01101011
	defb %01101011
	defb %01101011
	defb %11101011

; '>'
	defb %00000000
	defb %00000000
	defb %00000000
	defb %01110011
	defb %00011010
	defb %01111010
	defb %01011010
	defb %01111010

; '?'
	defb %00000000
	defb %00000000
	defb %00111100
	defb %00000000
	defb %00000000
	defb %00111100
	defb %00000000
	defb %00000000

; '@'
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %01111110
	defb %00000000
	defb %00000000
	defb %00000000

; 'A'
	defb %00000000
	defb %00011100
	defb %00110110
	defb %01100011
	defb %01100011
	defb %01111111
	defb %01100011
	defb %01100011

; 'B'
	defb %00000000
	defb %01111110
	defb %01100011
	defb %01100011
	defb %01111110
	defb %01100011
	defb %01100011
	defb %01111110

; 'C'
	defb %00000000
	defb %00111110
	defb %01100011
	defb %01100000
	defb %01100000
	defb %01100000
	defb %01100011
	defb %00111110

; 'D'
	defb %00000000
	defb %01111100
	defb %01100110
	defb %01100011
	defb %01100011
	defb %01100011
	defb %01100110
	defb %01111100

; 'E'
	defb %00000000
	defb %01111111
	defb %01100000
	defb %01100000
	defb %01111110
	defb %01100000
	defb %01100000
	defb %01111111

; 'F'
	defb %00000000
	defb %01111111
	defb %01100000
	defb %01100000
	defb %01111110
	defb %01100000
	defb %01100000
	defb %01100000

; 'G'
	defb %00000000
	defb %00111110
	defb %01100011
	defb %01100000
	defb %01100111
	defb %01100011
	defb %01100011
	defb %00111111

; 'H'
	defb %00000000
	defb %01100011
	defb %01100011
	defb %01100011
	defb %01111111
	defb %01100011
	defb %01100011
	defb %01100011

; 'I'
	defb %00000000
	defb %00111100
	defb %00011000
	defb %00011000
	defb %00011000
	defb %00011000
	defb %00011000
	defb %00111100

; 'J'
	defb %00000000
	defb %00011111
	defb %00000110
	defb %00000110
	defb %00000110
	defb %00000110
	defb %01100110
	defb %00111100

; 'K'
	defb %00000000
	defb %01100011
	defb %01100110
	defb %01101100
	defb %01111000
	defb %01111100
	defb %01101110
	defb %01100111

; 'L'
	defb %00000000
	defb %01100000
	defb %01100000
	defb %01100000
	defb %01100000
	defb %01100000
	defb %01100000
	defb %01111111

; 'M'
	defb %00000000
	defb %01100011
	defb %01110111
	defb %01111111
	defb %01111111
	defb %01101011
	defb %01100011
	defb %01100011

; 'N'
	defb %00000000
	defb %01100011
	defb %01110011
	defb %01111011
	defb %01111111
	defb %01101111
	defb %01100111
	defb %01100011

; 'O'
	defb %00000000
	defb %00111110
	defb %01100011
	defb %01100011
	defb %01100011
	defb %01100011
	defb %01100011
	defb %00111110

; 'P'
	defb %00000000
	defb %01111110
	defb %01100011
	defb %01100011
	defb %01100011
	defb %01111110
	defb %01100000
	defb %01100000

; 'Q'
	defb %00000000
	defb %00111110
	defb %01100011
	defb %01100011
	defb %01100011
	defb %01101111
	defb %01100110
	defb %00111101

; 'R'
	defb %00000000
	defb %01111110
	defb %01100011
	defb %01100011
	defb %01100010
	defb %01111100
	defb %01100110
	defb %01100011

; 'S'
	defb %00000000
	defb %00111110
	defb %01100011
	defb %01100000
	defb %00111110
	defb %00000011
	defb %01100011
	defb %00111110

; 'T'
	defb %00000000
	defb %01111110
	defb %00011000
	defb %00011000
	defb %00011000
	defb %00011000
	defb %00011000
	defb %00011000

; 'U'
	defb %00000000
	defb %01100011
	defb %01100011
	defb %01100011
	defb %01100011
	defb %01100011
	defb %01100011
	defb %00111110

; 'V'
	defb %00000000
	defb %01100011
	defb %01100011
	defb %01100011
	defb %01100011
	defb %00110110
	defb %00011100
	defb %00001000

; 'W'
	defb %00000000
	defb %01100011
	defb %01100011
	defb %01101011
	defb %01101011
	defb %01111111
	defb %01110111
	defb %00100010

; 'X'
	defb %00000000
	defb %01100011
	defb %01110110
	defb %00111100
	defb %00011100
	defb %00011110
	defb %00110111
	defb %01100011

; 'Y'
	defb %00000000
	defb %01100110
	defb %01100110
	defb %01111110
	defb %00111100
	defb %00011000
	defb %00011000
	defb %00011000

; 'Z'
	defb %00000000
	defb %01111111
	defb %00000111
	defb %00001110
	defb %00011100
	defb %00111000
	defb %01110000
	defb %01111111

; '['  (all-1s; hud_font_load blits ink 0 to (0,0) for space)
hud_font_solid:
	defb %11111111
	defb %11111111
	defb %11111111
	defb %11111111
	defb %11111111
	defb %11111111
	defb %11111111
	defb %11111111

; '\'
	defb %00000000
	defb %01111100
	defb %11000110
	defb %11000110
	defb %00011100
	defb %00010000
	defb %00000000
	defb %00010000

; ']'
	defb %00000000
	defb %01000010
	defb %00100100
	defb %00011000
	defb %00011000
	defb %00100100
	defb %01000010
	defb %00000000

; '^'  (heart left)
	defb %00000000
	defb %00000000
	defb %00000100
	defb %00001111
	defb %00011111
	defb %00001111
	defb %00000100
	defb %00000000

; '_'  (heart right)
	defb %00000000
	defb %00000000
	defb %00100000
	defb %11110000
	defb %11111000
	defb %11110000
	defb %00100000
	defb %00000000

; 0xBF00  one 8x8 4bpp tile (vram_blit_tile_run dest 0xA440).
hud_tile_bf00:  ; 0xBF00
	defb 0x08,0x80,0x08,0x80
	defb 0x88,0xe8,0x88,0x88
	defb 0x8e,0x88,0x88,0x88
	defb 0x8e,0x88,0x88,0x88
	defb 0x88,0x88,0x88,0x88
	defb 0x08,0x88,0x88,0x80
	defb 0x00,0x88,0x88,0x00
	defb 0x00,0x08,0x80,0x00

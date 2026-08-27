; ===========================================================================
;  banks 7-8 - 16K late-game window @ 0x8000-0xBFFF (page_tileset_late).
;  Stages 13-18 tilesets, title 4bpp glyphs, HUD font, ending text.
;  tileset_s16 crosses 0xA000; s18's 0xBF blit continues through title_tiles.
; ===========================================================================

    INCLUDE "data/tileset_s13.asm"

    INCLUDE "data/tileset_s16.asm"

    INCLUDE "data/tileset_s18.asm"

    INCLUDE "data/title_tiles.asm"

    INCLUDE "data/font_hud.asm"

    INCLUDE "credits_ending.asm"

    INCLUDE "data/tileset_s08_pad.asm"

    ASSERT $ == 0xC000


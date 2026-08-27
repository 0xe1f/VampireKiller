; ===========================================================================
;  banks 9-a - 16K front-end window @ 0x8000-0xBFFF (page_title_banks).
;  Intro tiles, bonus HUD, room gfx-scripts, palettes, enemy/weapon RLE.
; ===========================================================================

    INCLUDE "data/intro_tiles.asm"

    INCLUDE "data/bonus_hud_tiles.asm"

    INCLUDE "data/spike_bar.asm"

    INCLUDE "data/room_gfx.asm"

    INCLUDE "data/room_palettes.asm"

    INCLUDE "data/enemy_sprite_rle.asm"

    INCLUDE "data/vendor_tiles.asm"

    INCLUDE "data/stage_palettes.asm"

    ASSERT $ == 0xC000

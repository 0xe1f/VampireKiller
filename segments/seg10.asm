; ===========================================================================
;  SEGMENT 10 - front-end gfx bank, paged at 0xA000 by page_title_banks.
;  Room palettes, enemy/weapon RLE, stage palettes.
; ===========================================================================

    INCLUDE "data/room_palettes.asm"

    INCLUDE "data/enemy_sprite_rle.asm"

    INCLUDE "data/seg10_bda7.asm"

    INCLUDE "data/stage_palettes.asm"


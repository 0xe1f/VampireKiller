; ===========================================================================
;  banks 4-6 - 24K tileset window @ 0x6000-0xBFFF (page_tileset_banks).
;  Courtyard, stages 1-12 tilesets, staff roll, actor SAT, HUD icons.
;  tileset_s01 crosses 0x8000; tileset_s10 crosses 0xA000.
; ===========================================================================

    INCLUDE "data/tileset_s00.asm"

    INCLUDE "data/tileset_s01.asm"

    INCLUDE "credits_staff.asm"

    INCLUDE "data/tileset_s07.asm"

    INCLUDE "data/tileset_s04.asm"

    INCLUDE "data/tileset_s10.asm"

    INCLUDE "data/actor_shape.asm"

    INCLUDE "data/hud_weapon_key_tiles.asm"

    ASSERT $ == 0xC000

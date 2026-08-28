; ===========================================================================
;  VAMPIRE KILLER  (Akumajo Dracula)  -  Konami, 1986  -  MSX2 128 KiB MegaROM
; ===========================================================================
;
;  Assembler : sjasmplus  (see tools/).   Build:  make        -> VampireKiller.rom
;                                          Verify: make verify (byte-exact)
;
;  --- Cartridge / mapper -------------------------------------------------
;  128 KiB Konami MegaROM WITHOUT SCC ("Konami4"), 16 x 8 KiB segments.
;  Runtime memory layout (pages of the MSX slot the cartridge sits in):
;
;    Page      CPU range      switch address   initial segment
;    --------  -------------  ---------------   ---------------
;    page 1a   0x4000-0x5FFF  (none, fixed)     0
;    page 1b   0x6000-0x7FFF  write 0x6000      1
;    page 2a   0x8000-0x9FFF  write 0x8000      2
;    page 2b   0xA000-0xBFFF  write 0xA000      3
;
;  A segment is paged in by writing its number (0..15) to any address inside
;  the target page range (e.g. `ld a,segment / ld (0x6000),a`).  Segment 0 is
;  always visible at 0x4000 and holds the entry point + the code that stays
;  resident (init, interrupt, bank-switch helpers, main loop).
;
;  --- File layout --------------------------------------------------------
;  The .rom is the 16 segments concatenated (segment N at file offset N*0x2000).
;  Source is one file per paging window (each fills through CPU 0xC000):
;    banks_0123  play 32K @ 0x4000           (banks 0-3; 0 is always mapped)
;    banks_456   tilesets 24K @ 0x6000       (banks 4-6)
;    banks_78    late tilesets 16K @ 0x8000  (banks 7-8)
;    banks_9a    title gfx 16K @ 0x8000      (banks 9-10)
;    banks_bcd   map 24K @ 0x6000            (banks 11-13)
;    banks_ef    sound/portrait 16K @ 0x8000 (banks 14-15)
;  Data lives in `segments/data/`.  Small numeric ids are `segments/*.inc`
;  (actors, items, weapon, sfx, poses, scenery).
;  `PHASE` sets each block's runtime address while the output stays contiguous.
; ===========================================================================

    OUTPUT "VampireKiller.rom"
    ORG 0x0000

; Shared MSX/MSX2 BIOS entry-point names (readability only; not emitted).
    INCLUDE "segments/bios.inc"
; Actor type ids (spawn_actor C / object-list id).  Readability only.
    INCLUDE "segments/actors.inc"
; Pickup ids, C416 equip_*, play_sound, ix+0B pose_*, scenery grammar.
    INCLUDE "segments/items.inc"
    INCLUDE "segments/weapon.inc"
    INCLUDE "segments/sfx.inc"
    INCLUDE "segments/poses.inc"
    INCLUDE "segments/scenery.inc"

; --- text helpers -----------------------------------------------------------
;  HUD/title font (hud_font, seg8 0xBD80) is '0'-'_' at atlas ids 0x20+,
;  so those strings are (ASCII-0x10) with space -> 0x00.  Credits font is
;  1:1 ASCII, space still -> 0x00.
;    vk "SCORE"                      ; HUD/title glyph bytes
;    cr 0x08, 0x20, "SO THE BRAVE"   ; credits: tick, x, text, 0xFF
    MACRO vk str
        LUA ALLPASS
          local s = sj.get_define("str", true)
          if s:sub(1,1) == '"' then s = s:sub(2, -2) end
          for i = 1, #s do
            local c = s:byte(i)
            sj.add_byte(c == 32 and 0 or (c - 0x10) & 0xff)
          end
        ENDLUA
    ENDM
    MACRO cr tick, x, str
        defb tick, x
        LUA ALLPASS
          local s = sj.get_define("str", true)
          if s:sub(1,1) == '"' then s = s:sub(2, -2) end
          for i = 1, #s do
            local c = s:byte(i)
            sj.add_byte(c == 32 and 0 or c)
          end
        ENDLUA
        defb 0xFF
    ENDM

; --- banks 0-3 : 32K play window @ 0x4000 (fixed 0 + page_play_banks) ------
    PHASE 0x4000
    INCLUDE "segments/banks_0123.asm"
    DEPHASE

; --- banks 4-6 : 24K tileset window @ 0x6000 (page_tileset_banks) -----------
    PHASE 0x6000
    INCLUDE "segments/banks_456.asm"
    DEPHASE

; --- banks 7-8 : 16K late-game window @ 0x8000 (page_tileset_late) ----------
    PHASE 0x8000
    INCLUDE "segments/banks_78.asm"
    DEPHASE

; --- banks 9-a : 16K front-end window @ 0x8000 (page_title_banks) ----------
    PHASE 0x8000
    INCLUDE "segments/banks_9a.asm"
    DEPHASE

; --- banks b-d : 24K map window @ 0x6000 (page_map_banks) ------------------
    PHASE 0x6000
    INCLUDE "segments/banks_bcd.asm"
    DEPHASE

; --- banks e-f : 16K sound/portrait window @ 0x8000 (page_sound_banks) -----
    PHASE 0x8000
    INCLUDE "segments/banks_ef.asm"
    DEPHASE

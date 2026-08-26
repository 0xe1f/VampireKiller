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
;  This source is being converted segment-by-segment from raw `incbin` into
;  commented disassembly.  Segments 0-3 and 11-14 are INCLUDE'd; tileset
;  banks 4-8 stitch `data/tileset_*.asm` (hex 4bpp rows); segs 9-10 are
;  gfx scripts / palettes / enemy+weapon RLE; metatile streams/defs and
;  Simon/intro RLE live in `segments/data/`; ending
;  text is sliced from seg8 (`credits_ending.asm`) and staff from seg5
;  (`credits_staff.asm`).  Seg15 is music tails / env tables / Dracula
;  portrait.  Segs 9-10 are labeled gfx-script / palette / RLE.
;  `PHASE` sets each block's runtime address while the output stays contiguous.
; ===========================================================================

    OUTPUT "VampireKiller.rom"
    ORG 0x0000

; Shared MSX/MSX2 BIOS entry-point names (readability only; not emitted).
    INCLUDE "segments/bios.inc"
; Actor type ids (spawn_actor C / object-list id).  Readability only.
    INCLUDE "segments/actors.inc"

; --- text helpers -----------------------------------------------------------
;  HUD/title font is loaded at tile 0x10, so those strings are (ASCII-0x10)
;  with space -> 0x00.  Credits font is 1:1 ASCII, space still -> 0x00.
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

; --- segment 0 : resident bank, runs at 0x4000-0x5FFF (DISASSEMBLED) ---------
    PHASE 0x4000
    INCLUDE "segments/seg00.asm"
    DEPHASE

; --- segment 1 : initial 0x6000-0x7FFF (DISASSEMBLY IN PROGRESS) -------------
    PHASE 0x6000
    INCLUDE "segments/seg01.asm"
    DEPHASE

; --- segment 2 : initial 0x8000-0x9FFF (DISASSEMBLY IN PROGRESS) -------------
    PHASE 0x8000
    INCLUDE "segments/seg02.asm"
    DEPHASE

; --- segment 3 : initial 0xA000-0xBFFF (DISASSEMBLY IN PROGRESS) -------------
    PHASE 0xA000
    INCLUDE "segments/seg03.asm"
    DEPHASE

; --- segments 4..8 : playfield tilesets (labeled 8x8 4bpp) -----------------
; Paged by sub_53a5h (seg 4/5/6) and sub_5393h (seg 7/8, stage >= 13).
; Sets overlap and spill across banks; labels mark tileset_ptr starts.
; Staff / ending text are INCLUDE'd from the middle of seg5 / seg8.
    PHASE 0x6000
    INCLUDE "segments/seg04.asm"
    DEPHASE
    PHASE 0x8000
    INCLUDE "segments/seg05.asm"
    DEPHASE
    PHASE 0xA000
    INCLUDE "segments/seg06.asm"
    DEPHASE
    PHASE 0x8000
    INCLUDE "segments/seg07.asm"
    DEPHASE
    PHASE 0xA000
    INCLUDE "segments/seg08.asm"
    DEPHASE

; --- segments 9, 10 : gfx-script / palette / enemy+weapon RLE (labeled) ----
    PHASE 0x8000
    INCLUDE "segments/seg09.asm"
    DEPHASE
    PHASE 0xA000
    INCLUDE "segments/seg10.asm"
    DEPHASE

; --- segment 11 : bank 0x0B @ 0x6000 (room-map tables + metatile streams) ---
    PHASE 0x6000
    INCLUDE "segments/seg11.asm"
    DEPHASE

; --- segment 12 : bank 0x0C @ 0x8000 (per-stage metatile defs) --------------
    PHASE 0x8000
    INCLUDE "segments/seg12.asm"
    DEPHASE

; --- segment 13 : bank 0x0D @ 0xA000 (transition brain + door_tbl) -----------
    PHASE 0xA000
    INCLUDE "segments/seg13.asm"
    DEPHASE

; --- segment 14 : bank 0x0E @ 0x8000 (object lists + credits font + PSG) ---
    PHASE 0x8000
    INCLUDE "segments/seg14.asm"
    DEPHASE

; --- segment 15 : bank 0x0F @ 0xA000 (music tails + Dracula portrait) --------
    PHASE 0xA000
    INCLUDE "segments/seg15.asm"
    DEPHASE

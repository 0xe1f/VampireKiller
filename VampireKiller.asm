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
;  commented disassembly.  Segments not yet disassembled are included verbatim
;  so the rebuilt ROM stays byte-for-byte identical at every step.
;  `PHASE` sets each block's runtime address while the output stays contiguous.
; ===========================================================================

    OUTPUT "VampireKiller.rom"
    ORG 0x0000

; Shared MSX/MSX2 BIOS entry-point names (readability only; not emitted).
    INCLUDE "segments/bios.inc"

; --- vk() text helper -------------------------------------------------------
;  The game's font is loaded into VRAM starting at tile 0x10, so on-screen text
;  is stored as (ASCII - 0x10).  vk() lets the disassembly spell strings out in
;  readable ASCII and still emit the exact original bytes:
;    - a Lua string   -> each char emitted as (char-0x10); a space emits 0x00
;                        (words in the ROM are separated by the 0x00 blank tile)
;    - a Lua number   -> emitted verbatim (VDP position/attribute/control bytes,
;                        line separators 0xFE, record terminators 0xFF, ...)
;  Usage inside the disassembly:   LUA vk({0x48,0xA0,"PUSH SPACE KEY",0xFF}) ENDLUA
    LUA ALLPASS
      function vk(t)
        for _,v in ipairs(t) do
          if type(v)=="number" then sj.add_byte(v & 0xff)
          else for i=1,#v do local c=v:byte(i); sj.add_byte(c==32 and 0 or (c-0x10)&0xff) end end
        end
      end
    ENDLUA

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

; --- segments 4..15 : paged in on demand (page/role determined later) -------
; Included verbatim and emitted contiguously.  sjasmplus prints one harmless
; "RAM limit exceeded 0x10000" warning here because a single 128 KiB image is
; larger than the Z80's 64 KiB address space; the output file is still exact
; (verified by `make verify`).
    INCBIN "segments/seg04.bin"
    INCBIN "segments/seg05.bin"
    INCBIN "segments/seg06.bin"
    INCBIN "segments/seg07.bin"
    INCBIN "segments/seg08.bin"
    INCBIN "segments/seg09.bin"
    INCBIN "segments/seg10.bin"
    INCBIN "segments/seg11.bin"
    INCBIN "segments/seg12.bin"
    INCBIN "segments/seg13.bin"
    INCBIN "segments/seg14.bin"
    INCBIN "segments/seg15.bin"

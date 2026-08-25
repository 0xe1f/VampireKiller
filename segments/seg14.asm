; ===========================================================================
;  SEGMENT 14 - bank 0x0E, paged at 0x8000-0x9FFF (page 2a) by room_spawner,
;  sub_615bh, scenery_load, play_sound, and int_handler (with seg15 at 0xA000).
;  Origin is set by PHASE 0x8000 in VampireKiller.asm.
;
;  Shares the CPU window with seg02; labels here are unique names (not
;  z80dasm lxxxh) to avoid colliding with seg02.asm.
;
;  Layout:
;    0x8000  scenery_list_ptr / packed per-hub candle, block, chest, vendor
;            streams (stage 0 courtyard is scenery_list_s00, not in the table)
;    0x85A6  spawn_bitmask_ptr / per-stage spawn masks
;    0x8668  object_list_ptr / packed per-hub enemy streams
;    0x8824  sound/VDP (tick at 0x8964; sfx tbl 0x8D8D; music 0x8DC9)
; ===========================================================================

; scenery_list_ptr (seg14 0x8000): word[hub 0..5] -> packed scenery streams.
; scenery_list_lookup indexes by 0xD002; stage 0 returns scenery_list_s00.
; Unpacker scenery_unpack expands into 0xE000 (3 stages x 16 rooms x 24 bytes).
; 0xFE next room, 0xFF next stage, 0x00 end hub. Instantiator 0x5B22 fills
; 8 C470 candle/block slots, C500 floor items/chests, C5B5/C5C5 vendors.
; Record: pos (hi nibble Y, lo nibble X, cell*16 px), attr; attr 0x7F adds a
; third byte (reveal). attr bits7-6: 00 = candle (bits7-5==3 = breakable
; block) or floor pickup (bits7-5==0); 10 = chest; 11 = vendor. bits4-0 =
; bonus id (vendor uses bits5-2 as price-tbl index). Stage 18 room 9
; (Dracula) is omitted and stays empty.

scenery_list_ptr:
	defw scenery_list_h0     ; hub 0 = stages 1-3
	defw scenery_list_h1     ; hub 1 = stages 4-6
	defw scenery_list_h2     ; hub 2 = stages 7-9
	defw scenery_list_h3     ; hub 3 = stages 10-12
	defw scenery_list_h4     ; hub 4 = stages 13-15
	defw scenery_list_h5     ; hub 5 = stages 16-18

; stage 0 courtyard (0x800C). Not in the hub table.
scenery_list_s00:
	defb 094h,021h         ; r0 candle (4,9) small heart
	defb 09ch,021h         ; r0 candle (12,9) small heart
	defb 0feh              ; next room
	defb 094h,022h         ; r1 candle (4,9) large heart
	defb 09ch,022h         ; r1 candle (12,9) large heart
	defb 0feh              ; next room
	defb 094h,03ah         ; r2 candle (4,9) chain whip
	defb 000h              ; end

; hub 0 = stages 1-3 (0x8019)
scenery_list_h0:
	; stage 1
	defb 097h,029h         ; r0 candle (7,9) sapphire ring
	defb 09bh,021h         ; r0 candle (11,9) small heart
	defb 0feh              ; next room
	defb 093h,021h         ; r1 candle (3,9) small heart
	defb 097h,026h         ; r1 candle (7,9) rosary
	defb 049h,021h         ; r1 candle (9,4) small heart
	defb 08bh,029h         ; r1 candle (11,8) sapphire ring
	defb 0feh              ; next room
	defb 046h,021h         ; r2 candle (6,4) small heart
	defb 0b4h,017h         ; r2 floor (4,11) yellow key
	defb 0a8h,078h         ; r2 block (8,10) white key
	defb 0bbh,082h         ; r2 chest (11,11) large heart
	defb 04bh,021h         ; r2 candle (11,4) small heart
	defb 09dh,021h         ; r2 candle (13,9) small heart
	defb 0feh              ; next room
	defb 0a2h,021h         ; r3 candle (2,10) small heart
	defb 064h,03ah         ; r3 candle (4,6) chain whip
	defb 0a8h,021h         ; r3 candle (8,10) small heart
	defb 05bh,022h         ; r3 candle (11,5) large heart
	defb 073h,08dh         ; r3 chest (3,7) wings
	defb 0feh              ; next room
	defb 023h,020h         ; r4 candle (3,2) none
	defb 063h,021h         ; r4 candle (3,6) small heart
	defb 096h,021h         ; r4 candle (6,9) small heart
	defb 04bh,022h         ; r4 candle (11,4) large heart
	defb 09ah,020h         ; r4 candle (10,9) none
	defb 032h,08ch         ; r4 chest (2,3) boots
	defb 072h,083h         ; r4 chest (2,7) red shield
	defb 0b2h,017h         ; r4 floor (2,11) yellow key
	defb 0feh              ; next room
	defb 094h,020h         ; r5 candle (4,9) none
	defb 089h,03ah         ; r5 candle (9,8) chain whip
	defb 0feh              ; next room
	defb 087h,030h         ; r6 candle (7,8) black bible
	defb 05dh,021h         ; r6 candle (13,5) small heart
	defb 0feh              ; next room
	defb 0a6h,022h         ; r7 candle (6,10) large heart
	defb 0aah,020h         ; r7 candle (10,10) none
	defb 078h,017h         ; r7 floor (8,7) yellow key
	defb 0ach,07fh,0e1h    ; r7 reveal (12,10) vendor knife slot1
	defb 0ffh              ; end stream
	; stage 2
	defb 02ah,0d5h         ; r0 vendor (10,2) potion slot1
	defb 092h,021h         ; r0 candle (2,9) small heart
	defb 048h,021h         ; r0 candle (8,4) small heart
	defb 06ah,062h         ; r0 block (10,6) large heart
	defb 06ch,062h         ; r0 block (12,6) large heart
	defb 0a8h,077h         ; r0 block (8,10) yellow key
	defb 0aah,062h         ; r0 block (10,10) large heart
	defb 0ach,07fh,0ceh    ; r0 reveal (12,10) vendor yellow shield slot2
	defb 0feh              ; next room
	defb 062h,077h         ; r1 block (2,6) yellow key
	defb 064h,077h         ; r1 block (4,6) yellow key
	defb 066h,060h         ; r1 block (6,6) none
	defb 0a2h,07fh,08ah    ; r1 reveal (2,10) chest hourglass
	defb 0a4h,07fh,08ch    ; r1 reveal (4,10) chest boots
	defb 0a6h,077h         ; r1 block (6,10) yellow key
	defb 037h,027h         ; r1 candle (7,3) small orb
	defb 031h,091h         ; r1 chest (1,3) white bible
	defb 0feh              ; next room
	defb 034h,028h         ; r2 candle (4,3) blue gem
	defb 075h,021h         ; r2 candle (5,7) small heart
	defb 07ah,025h         ; r2 candle (10,7) white cross
	defb 03eh,022h         ; r2 candle (14,3) large heart
	defb 056h,08fh         ; r2 chest (6,5) map
	defb 04ah,07fh,0dbh    ; r2 reveal (10,4) vendor holy water slot3
	defb 0feh              ; next room
	defb 074h,022h         ; r3 candle (4,7) large heart
	defb 036h,022h         ; r3 candle (6,3) large heart
	defb 03ch,022h         ; r3 candle (12,3) large heart
	defb 08eh,029h         ; r3 candle (14,8) sapphire ring
	defb 0b8h,017h         ; r3 floor (8,11) yellow key
	defb 0feh              ; next room
	defb 052h,07ch         ; r4 block (2,5) axe
	defb 054h,029h         ; r4 candle (4,5) sapphire ring
	defb 04eh,021h         ; r4 candle (14,4) small heart
	defb 0feh              ; next room
	defb 045h,022h         ; r5 candle (5,4) large heart
	defb 04ch,030h         ; r5 candle (12,4) black bible
	defb 07ch,078h         ; r5 block (12,7) white key
	defb 0ffh              ; end stream
	; stage 3
	defb 068h,021h         ; r0 candle (8,6) small heart
	defb 093h,021h         ; r0 candle (3,9) small heart
	defb 098h,029h         ; r0 candle (8,9) sapphire ring
	defb 0b2h,017h         ; r0 floor (2,11) yellow key
	defb 074h,084h         ; r0 chest (4,7) yellow shield
	defb 0feh              ; next room
	defb 097h,034h         ; r1 candle (7,9) blue bag
	defb 05dh,028h         ; r1 candle (13,5) blue gem
	defb 09ch,017h         ; r1 floor (12,9) yellow key
	defb 0feh              ; next room
	defb 0a1h,03ah         ; r2 candle (1,10) chain whip
	defb 06ah,07fh,0dch    ; r2 reveal (10,6) vendor cross slot0
	defb 0aah,078h         ; r2 block (10,10) white key
	defb 077h,08ah         ; r2 chest (7,7) hourglass
	defb 0b7h,017h         ; r2 floor (7,11) yellow key
	defb 0bch,089h         ; r2 chest (12,11) sapphire ring
	defb 0feh              ; next room
	defb 053h,03ah         ; r3 candle (3,5) chain whip
	defb 093h,021h         ; r3 candle (3,9) small heart
	defb 096h,029h         ; r3 candle (6,9) sapphire ring
	defb 099h,021h         ; r3 candle (9,9) small heart
	defb 09ch,030h         ; r3 candle (12,9) black bible
	defb 05ch,017h         ; r3 floor (12,5) yellow key
	defb 0feh              ; next room
	defb 053h,085h         ; r4 chest (3,5) white cross
	defb 0b3h,083h         ; r4 chest (3,11) red shield
	defb 0feh              ; next room
	defb 087h,022h         ; r5 candle (7,8) large heart
	defb 08ah,021h         ; r5 candle (10,8) small heart
	defb 000h              ; end

; hub 1 = stages 4-6 (0x80e7)
scenery_list_h1:
	; stage 4
	defb 098h,021h         ; r0 candle (8,9) small heart
	defb 09eh,028h         ; r0 candle (14,9) blue gem
	defb 048h,035h         ; r0 candle (8,4) slime
	defb 05dh,017h         ; r0 floor (13,5) yellow key
	defb 042h,078h         ; r0 block (2,4) white key
	defb 0feh              ; next room
	defb 034h,026h         ; r1 candle (4,3) rosary
	defb 084h,029h         ; r1 candle (4,8) sapphire ring
	defb 089h,022h         ; r1 candle (9,8) large heart
	defb 07ch,017h         ; r1 floor (12,7) yellow key
	defb 03ch,035h         ; r1 candle (12,3) slime
	defb 0b9h,08fh         ; r1 chest (9,11) map
	defb 0ach,0c4h         ; r1 vendor (12,10) staff slot0
	defb 0feh              ; next room
	defb 035h,035h         ; r2 candle (5,3) slime
	defb 083h,021h         ; r2 candle (3,8) small heart
	defb 04ch,027h         ; r2 candle (12,4) small orb
	defb 0adh,028h         ; r2 candle (13,10) blue gem
	defb 07dh,017h         ; r2 floor (13,7) yellow key
	defb 044h,0d6h         ; r2 vendor (4,4) potion slot2
	defb 0feh              ; next room
	defb 034h,022h         ; r3 candle (4,3) large heart
	defb 03ah,022h         ; r3 candle (10,3) large heart
	defb 0b1h,091h         ; r3 chest (1,11) white bible
	defb 097h,017h         ; r3 floor (7,9) yellow key
	defb 0feh              ; next room
	defb 031h,035h         ; r4 candle (1,3) slime
	defb 037h,027h         ; r4 candle (7,3) small orb
	defb 03bh,021h         ; r4 candle (11,3) small heart
	defb 0bbh,017h         ; r4 floor (11,11) yellow key
	defb 072h,08ah         ; r4 chest (2,7) hourglass
	defb 07ah,09ch         ; r4 chest (10,7) axe
	defb 0feh              ; next room
	defb 036h,021h         ; r5 candle (6,3) small heart
	defb 07dh,022h         ; r5 candle (13,7) large heart
	defb 091h,083h         ; r5 chest (1,9) red shield
	defb 0ffh              ; end stream
	; stage 5
	defb 024h,035h         ; r0 candle (4,2) slime
	defb 028h,021h         ; r0 candle (8,2) small heart
	defb 02ch,021h         ; r0 candle (12,2) small heart
	defb 0feh              ; next room
	defb 047h,022h         ; r1 candle (7,4) large heart
	defb 04bh,021h         ; r1 candle (11,4) small heart
	defb 076h,017h         ; r1 floor (6,7) yellow key
	defb 09ah,017h         ; r1 floor (10,9) yellow key
	defb 0feh              ; next room
	defb 022h,026h         ; r2 candle (2,2) rosary
	defb 03bh,022h         ; r2 candle (11,3) large heart
	defb 07ah,089h         ; r2 chest (10,7) sapphire ring
	defb 0feh              ; next room
	defb 082h,022h         ; r3 candle (2,8) large heart
	defb 04ch,078h         ; r3 block (12,4) white key
	defb 08ch,07fh,0d3h    ; r3 reveal (12,8) vendor hourglass slot3
	defb 05bh,093h         ; r3 chest (11,5) white bag
	defb 09bh,09eh         ; r3 chest (11,9) holy water
	defb 0feh              ; next room
	defb 044h,021h         ; r4 candle (4,4) small heart
	defb 04dh,035h         ; r4 candle (13,4) slime
	defb 048h,021h         ; r4 candle (8,4) small heart
	defb 083h,021h         ; r4 candle (3,8) small heart
	defb 088h,021h         ; r4 candle (8,8) small heart
	defb 095h,017h         ; r4 floor (5,9) yellow key
	defb 09ch,017h         ; r4 floor (12,9) yellow key
	defb 0feh              ; next room
	defb 035h,035h         ; r5 candle (5,3) slime
	defb 03dh,035h         ; r5 candle (13,3) slime
	defb 094h,021h         ; r5 candle (4,9) small heart
	defb 099h,035h         ; r5 candle (9,9) slime
	defb 09ch,021h         ; r5 candle (12,9) small heart
	defb 0ffh              ; end stream
	; stage 6
	defb 067h,017h         ; r0 floor (7,6) yellow key
	defb 054h,029h         ; r0 candle (4,5) sapphire ring
	defb 02ch,07fh,0d5h    ; r0 reveal (12,2) vendor potion slot1
	defb 0a4h,062h         ; r0 block (4,10) large heart
	defb 0a6h,075h         ; r0 block (6,10) slime
	defb 0a8h,075h         ; r0 block (8,10) slime
	defb 0aah,075h         ; r0 block (10,10) slime
	defb 0ach,078h         ; r0 block (12,10) white key
	defb 0feh              ; next room
	defb 022h,03ah         ; r1 candle (2,2) chain whip
	defb 026h,035h         ; r1 candle (6,2) slime
	defb 02ah,021h         ; r1 candle (10,2) small heart
	defb 082h,035h         ; r1 candle (2,8) slime
	defb 086h,035h         ; r1 candle (6,8) slime
	defb 08ah,022h         ; r1 candle (10,8) large heart
	defb 09ch,017h         ; r1 floor (12,9) yellow key
	defb 0feh              ; next room
	defb 038h,022h         ; r2 candle (8,3) large heart
	defb 073h,021h         ; r2 candle (3,7) small heart
	defb 07bh,021h         ; r2 candle (11,7) small heart
	defb 032h,07fh,0e3h    ; r2 reveal (2,3) vendor knife slot3
	defb 044h,017h         ; r2 floor (4,4) yellow key
	defb 088h,07fh,089h    ; r2 reveal (8,8) chest sapphire ring
	defb 0a2h,09ah         ; r2 chest (2,10) chain whip
	defb 0feh              ; next room
	defb 062h,026h         ; r3 candle (2,6) rosary
	defb 066h,03ah         ; r3 candle (6,6) chain whip
	defb 09dh,017h         ; r3 floor (13,9) yellow key
	defb 0feh              ; next room
	defb 062h,021h         ; r4 candle (2,6) small heart
	defb 066h,035h         ; r4 candle (6,6) slime
	defb 06ah,022h         ; r4 candle (10,6) large heart
	defb 06eh,035h         ; r4 candle (14,6) slime
	defb 0feh              ; next room
	defb 062h,027h         ; r5 candle (2,6) small orb
	defb 06eh,021h         ; r5 candle (14,6) small heart
	defb 076h,021h         ; r5 candle (6,7) small heart
	defb 07ah,021h         ; r5 candle (10,7) small heart
	defb 000h              ; end

; hub 2 = stages 7-9 (0x81b3)
scenery_list_h2:
	; stage 7
	defb 09ah,021h         ; r0 candle (10,9) small heart
	defb 032h,0c0h         ; r0 vendor (2,3) candle slot0
	defb 0feh              ; next room
	defb 033h,021h         ; r1 candle (3,3) small heart
	defb 056h,022h         ; r1 candle (6,5) large heart
	defb 05ah,035h         ; r1 candle (10,5) slime
	defb 092h,021h         ; r1 candle (2,9) small heart
	defb 09eh,022h         ; r1 candle (14,9) large heart
	defb 084h,090h         ; r1 chest (4,8) black bible
	defb 04eh,017h         ; r1 floor (14,4) yellow key
	defb 0feh              ; next room
	defb 03eh,022h         ; r2 candle (14,3) large heart
	defb 056h,022h         ; r2 candle (6,5) large heart
	defb 064h,022h         ; r2 candle (4,6) large heart
	defb 099h,030h         ; r2 candle (9,9) black bible
	defb 0a2h,017h         ; r2 floor (2,10) yellow key
	defb 0feh              ; next room
	defb 051h,029h         ; r3 candle (1,5) sapphire ring
	defb 04ch,035h         ; r3 candle (12,4) slime
	defb 08ch,078h         ; r3 block (12,8) white key
	defb 06dh,083h         ; r3 chest (13,6) red shield
	defb 0feh              ; next room
	defb 024h,022h         ; r4 candle (4,2) large heart
	defb 02ch,034h         ; r4 candle (12,2) blue bag
	defb 081h,021h         ; r4 candle (1,8) small heart
	defb 094h,021h         ; r4 candle (4,9) small heart
	defb 044h,084h         ; r4 chest (4,4) yellow shield
	defb 04ah,017h         ; r4 floor (10,4) yellow key
	defb 07ah,09ch         ; r4 chest (10,7) axe
	defb 0feh              ; next room
	defb 039h,020h         ; r5 candle (9,3) none
	defb 055h,022h         ; r5 candle (5,5) large heart
	defb 098h,020h         ; r5 candle (8,9) none
	defb 082h,08fh         ; r5 chest (2,8) map
	defb 06bh,017h         ; r5 floor (11,6) yellow key
	defb 0feh              ; next room
	defb 044h,022h         ; r6 candle (4,4) large heart
	defb 094h,035h         ; r6 candle (4,9) slime
	defb 098h,022h         ; r6 candle (8,9) large heart
	defb 09bh,017h         ; r6 floor (11,9) yellow key
	defb 0feh              ; next room
	defb 091h,021h         ; r7 candle (1,9) small heart
	defb 094h,022h         ; r7 candle (4,9) large heart
	defb 098h,021h         ; r7 candle (8,9) small heart
	defb 07eh,017h         ; r7 floor (14,7) yellow key
	defb 0feh              ; next room
	defb 059h,021h         ; r8 candle (9,5) small heart
	defb 08ch,022h         ; r8 candle (12,8) large heart
	defb 094h,020h         ; r8 candle (4,9) none
	defb 092h,0c8h         ; r8 vendor (2,9) red shield slot0
	defb 0ffh              ; end stream
	; stage 8
	defb 075h,035h         ; r0 candle (5,7) slime
	defb 056h,075h         ; r0 block (6,5) slime
	defb 058h,075h         ; r0 block (8,5) slime
	defb 05ah,075h         ; r0 block (10,5) slime
	defb 076h,075h         ; r0 block (6,7) slime
	defb 078h,075h         ; r0 block (8,7) slime
	defb 07ah,07fh,089h    ; r0 reveal (10,7) chest sapphire ring
	defb 07ch,077h         ; r0 block (12,7) yellow key
	defb 0feh              ; next room
	defb 065h,02ch         ; r1 candle (5,6) boots
	defb 06ah,03ah         ; r1 candle (10,6) chain whip
	defb 06ch,021h         ; r1 candle (12,6) small heart
	defb 074h,07fh,092h    ; r1 reveal (4,7) chest staff
	defb 076h,07fh,08fh    ; r1 reveal (6,7) chest map
	defb 078h,060h         ; r1 block (8,7) none
	defb 07ch,077h         ; r1 block (12,7) yellow key
	defb 0feh              ; next room
	defb 02bh,021h         ; r2 candle (11,2) small heart
	defb 064h,021h         ; r2 candle (4,6) small heart
	defb 068h,030h         ; r2 candle (8,6) black bible
	defb 07ch,0cfh         ; r2 vendor (12,7) yellow shield slot3
	defb 0feh              ; next room
	defb 037h,022h         ; r3 candle (7,3) large heart
	defb 077h,035h         ; r3 candle (7,7) slime
	defb 07eh,020h         ; r3 candle (14,7) none
	defb 082h,08ch         ; r3 chest (2,8) boots
	defb 04ah,017h         ; r3 floor (10,4) yellow key
	defb 07ch,0d3h         ; r3 vendor (12,7) hourglass slot3
	defb 0feh              ; next room
	defb 026h,021h         ; r4 candle (6,2) small heart
	defb 02ah,021h         ; r4 candle (10,2) small heart
	defb 084h,022h         ; r4 candle (4,8) large heart
	defb 0a1h,017h         ; r4 floor (1,10) yellow key
	defb 0feh              ; next room
	defb 054h,02dh         ; r5 candle (4,5) wings
	defb 059h,035h         ; r5 candle (9,5) slime
	defb 0bbh,021h         ; r5 candle (11,11) small heart
	defb 05ah,07fh,082h    ; r5 reveal (10,5) chest large heart
	defb 0feh              ; next room
	defb 0feh              ; next room
	defb 072h,035h         ; r7 candle (2,7) slime
	defb 075h,035h         ; r7 candle (5,7) slime
	defb 042h,018h         ; r7 floor (2,4) white key
	defb 04ch,075h         ; r7 block (12,4) slime
	defb 08ch,07fh,09bh    ; r7 reveal (12,8) chest knife
	defb 0ach,062h         ; r7 block (12,10) large heart
	defb 0ffh              ; end stream
	; stage 9
	defb 068h,089h         ; r0 chest (8,6) sapphire ring
	defb 0feh              ; next room
	defb 05eh,021h         ; r1 candle (14,5) small heart
	defb 0feh              ; next room
	defb 043h,035h         ; r2 candle (3,4) slime
	defb 046h,035h         ; r2 candle (6,4) slime
	defb 049h,028h         ; r2 candle (9,4) blue gem
	defb 04ch,02ch         ; r2 candle (12,4) boots
	defb 0feh              ; next room
	defb 0feh              ; next room
	defb 046h,028h         ; r4 candle (6,4) blue gem
	defb 049h,022h         ; r4 candle (9,4) large heart
	defb 03ch,077h         ; r4 block (12,3) yellow key
	defb 0aeh,089h         ; r4 chest (14,10) sapphire ring
	defb 06bh,017h         ; r4 floor (11,6) yellow key
	defb 06eh,017h         ; r4 floor (14,6) yellow key
	defb 0feh              ; next room
	defb 091h,025h         ; r5 candle (1,9) white cross
	defb 097h,021h         ; r5 candle (7,9) small heart
	defb 06ah,017h         ; r5 floor (10,6) yellow key
	defb 0a9h,082h         ; r5 chest (9,10) large heart
	defb 0feh              ; next room
	defb 034h,028h         ; r6 candle (4,3) blue gem
	defb 03bh,021h         ; r6 candle (11,3) small heart
	defb 0a4h,021h         ; r6 candle (4,10) small heart
	defb 042h,085h         ; r6 chest (2,4) white cross
	defb 089h,017h         ; r6 floor (9,8) yellow key
	defb 0feh              ; next room
	defb 062h,034h         ; r7 candle (2,6) blue bag
	defb 096h,021h         ; r7 candle (6,9) small heart
	defb 099h,021h         ; r7 candle (9,9) small heart
	defb 09ch,021h         ; r7 candle (12,9) small heart
	defb 0feh              ; next room
	defb 039h,022h         ; r8 candle (9,3) large heart
	defb 089h,021h         ; r8 candle (9,8) small heart
	defb 06dh,018h         ; r8 floor (13,6) white key
	defb 09ch,07fh,0dch    ; r8 reveal (12,9) vendor cross slot0
	defb 047h,09eh         ; r8 chest (7,4) holy water
	defb 000h              ; end

; hub 3 = stages 10-12 (0x82b1)
scenery_list_h3:
	; stage 10
	defb 065h,029h         ; r0 candle (5,6) sapphire ring
	defb 07ah,026h         ; r0 candle (10,7) rosary
	defb 033h,018h         ; r0 floor (3,3) white key
	defb 08eh,09ah         ; r0 chest (14,8) chain whip
	defb 0feh              ; next room
	defb 038h,030h         ; r1 candle (8,3) black bible
	defb 03eh,022h         ; r1 candle (14,3) large heart
	defb 065h,021h         ; r1 candle (5,6) small heart
	defb 032h,0c5h         ; r1 vendor (2,3) staff slot1
	defb 069h,017h         ; r1 floor (9,6) yellow key
	defb 0feh              ; next room
	defb 062h,025h         ; r2 candle (2,6) white cross
	defb 07dh,029h         ; r2 candle (13,7) sapphire ring
	defb 0feh              ; next room
	defb 07ah,028h         ; r3 candle (10,7) blue gem
	defb 076h,077h         ; r3 block (6,7) yellow key
	defb 07dh,021h         ; r3 candle (13,7) small heart
	defb 0feh              ; next room
	defb 077h,034h         ; r4 candle (7,7) blue bag
	defb 07dh,021h         ; r4 candle (13,7) small heart
	defb 084h,091h         ; r4 chest (4,8) white bible
	defb 0feh              ; next room
	defb 035h,021h         ; r5 candle (5,3) small heart
	defb 03dh,02dh         ; r5 candle (13,3) wings
	defb 07dh,021h         ; r5 candle (13,7) small heart
	defb 08eh,017h         ; r5 floor (14,8) yellow key
	defb 046h,09ch         ; r5 chest (6,4) axe
	defb 087h,093h         ; r5 chest (7,8) white bag
	defb 0feh              ; next room
	defb 082h,021h         ; r6 candle (2,8) small heart
	defb 086h,022h         ; r6 candle (6,8) large heart
	defb 08ah,021h         ; r6 candle (10,8) small heart
	defb 08ch,022h         ; r6 candle (12,8) large heart
	defb 0feh              ; next room
	defb 092h,021h         ; r7 candle (2,9) small heart
	defb 084h,022h         ; r7 candle (4,8) large heart
	defb 086h,021h         ; r7 candle (6,8) small heart
	defb 089h,021h         ; r7 candle (9,8) small heart
	defb 09bh,021h         ; r7 candle (11,9) small heart
	defb 09eh,022h         ; r7 candle (14,9) large heart
	defb 0feh              ; next room
	defb 094h,021h         ; r8 candle (4,9) small heart
	defb 092h,0ceh         ; r8 vendor (2,9) yellow shield slot2
	defb 0ffh              ; end stream
	; stage 11
	defb 097h,022h         ; r0 candle (7,9) large heart
	defb 09ah,035h         ; r0 candle (10,9) slime
	defb 09dh,035h         ; r0 candle (13,9) slime
	defb 0feh              ; next room
	defb 048h,017h         ; r1 floor (8,4) yellow key
	defb 056h,078h         ; r1 block (6,5) white key
	defb 076h,07fh,09eh    ; r1 reveal (6,7) chest holy water
	defb 078h,07fh,091h    ; r1 reveal (8,7) chest white bible
	defb 07ah,07fh,092h    ; r1 reveal (10,7) chest staff
	defb 07ch,062h         ; r1 block (12,7) large heart
	defb 094h,060h         ; r1 block (4,9) none
	defb 096h,07fh,0c1h    ; r1 reveal (6,9) vendor candle slot1
	defb 0feh              ; next room
	defb 072h,022h         ; r2 candle (2,7) large heart
	defb 075h,021h         ; r2 candle (5,7) small heart
	defb 08dh,022h         ; r2 candle (13,8) large heart
	defb 0feh              ; next room
	defb 056h,07fh,092h    ; r3 reveal (6,5) chest staff
	defb 078h,062h         ; r3 block (8,7) large heart
	defb 07ch,07fh,083h    ; r3 reveal (12,7) chest red shield
	defb 094h,060h         ; r3 block (4,9) none
	defb 096h,07fh,09ch    ; r3 reveal (6,9) chest axe
	defb 098h,060h         ; r3 block (8,9) none
	defb 09ah,07fh,0d7h    ; r3 reveal (10,9) vendor potion slot3
	defb 0feh              ; next room
	defb 08bh,021h         ; r4 candle (11,8) small heart
	defb 08eh,03ah         ; r4 candle (14,8) chain whip
	defb 098h,07fh,085h    ; r4 reveal (8,9) chest white cross
	defb 0feh              ; next room
	defb 094h,035h         ; r5 candle (4,9) slime
	defb 097h,035h         ; r5 candle (7,9) slime
	defb 0ffh              ; end stream
	; stage 12
	defb 093h,021h         ; r0 candle (3,9) small heart
	defb 0feh              ; next room
	defb 089h,021h         ; r1 candle (9,8) small heart
	defb 08eh,021h         ; r1 candle (14,8) small heart
	defb 074h,077h         ; r1 block (4,7) yellow key
	defb 0feh              ; next room
	defb 082h,020h         ; r2 candle (2,8) none
	defb 097h,022h         ; r2 candle (7,9) large heart
	defb 09ch,020h         ; r2 candle (12,9) none
	defb 0aeh,092h         ; r2 chest (14,10) staff
	defb 0feh              ; next room
	defb 093h,021h         ; r3 candle (3,9) small heart
	defb 098h,021h         ; r3 candle (8,9) small heart
	defb 09bh,020h         ; r3 candle (11,9) none
	defb 09eh,022h         ; r3 candle (14,9) large heart
	defb 0feh              ; next room
	defb 08eh,021h         ; r4 candle (14,8) small heart
	defb 086h,091h         ; r4 chest (6,8) white bible
	defb 078h,0dfh         ; r4 vendor (8,7) cross slot3
	defb 0feh              ; next room
	defb 098h,022h         ; r5 candle (8,9) large heart
	defb 06ch,078h         ; r5 block (12,6) white key
	defb 092h,07fh,088h    ; r5 reveal (2,9) chest blue gem
	defb 09ah,060h         ; r5 block (10,9) none
	defb 0feh              ; next room
	defb 0feh              ; next room
	defb 091h,02ch         ; r7 candle (1,9) boots
	defb 07ah,035h         ; r7 candle (10,7) slime
	defb 07eh,020h         ; r7 candle (14,7) none
	defb 08ch,08fh         ; r7 chest (12,8) map
	defb 0feh              ; next room
	defb 072h,021h         ; r8 candle (2,7) small heart
	defb 079h,035h         ; r8 candle (9,7) slime
	defb 09ch,022h         ; r8 candle (12,9) large heart
	defb 0aeh,017h         ; r8 floor (14,10) yellow key
	defb 0feh              ; next room
	defb 072h,022h         ; r9 candle (2,7) large heart
	defb 077h,021h         ; r9 candle (7,7) small heart
	defb 07ah,035h         ; r9 candle (10,7) slime
	defb 074h,077h         ; r9 block (4,7) yellow key
	defb 0feh              ; next room
	defb 091h,021h         ; r10 candle (1,9) small heart
	defb 096h,028h         ; r10 candle (6,9) blue gem
	defb 08ch,022h         ; r10 candle (12,8) large heart
	defb 0feh              ; next room
	defb 097h,020h         ; r11 candle (7,9) none
	defb 084h,085h         ; r11 chest (4,8) white cross
	defb 000h              ; end

; hub 4 = stages 13-15 (0x8398)
scenery_list_h4:
	; stage 13
	defb 093h,022h         ; r0 candle (3,9) large heart
	defb 098h,021h         ; r0 candle (8,9) small heart
	defb 09eh,022h         ; r0 candle (14,9) large heart
	defb 032h,07fh,0e3h    ; r0 reveal (2,3) vendor knife slot3
	defb 0feh              ; next room
	defb 094h,021h         ; r1 candle (4,9) small heart
	defb 08ch,021h         ; r1 candle (12,8) small heart
	defb 0aeh,017h         ; r1 floor (14,10) yellow key
	defb 0feh              ; next room
	defb 087h,022h         ; r2 candle (7,8) large heart
	defb 08ch,021h         ; r2 candle (12,8) small heart
	defb 049h,017h         ; r2 floor (9,4) yellow key
	defb 0adh,017h         ; r2 floor (13,10) yellow key
	defb 0feh              ; next room
	defb 031h,021h         ; r3 candle (1,3) small heart
	defb 036h,022h         ; r3 candle (6,3) large heart
	defb 03bh,030h         ; r3 candle (11,3) black bible
	defb 049h,017h         ; r3 floor (9,4) yellow key
	defb 0feh              ; next room
	defb 035h,022h         ; r4 candle (5,3) large heart
	defb 03ah,027h         ; r4 candle (10,3) small orb
	defb 098h,020h         ; r4 candle (8,9) none
	defb 094h,07fh,08fh    ; r4 reveal (4,9) chest map
	defb 092h,0c6h         ; r4 vendor (2,9) staff slot2
	defb 0feh              ; next room
	defb 034h,029h         ; r5 candle (4,3) sapphire ring
	defb 039h,022h         ; r5 candle (9,3) large heart
	defb 03eh,021h         ; r5 candle (14,3) small heart
	defb 0feh              ; next room
	defb 049h,017h         ; r6 floor (9,4) yellow key
	defb 03ch,07fh,0d1h    ; r6 reveal (12,3) vendor hourglass slot1
	defb 07ah,078h         ; r6 block (10,7) white key
	defb 0feh              ; next room
	defb 083h,021h         ; r7 candle (3,8) small heart
	defb 089h,022h         ; r7 candle (9,8) large heart
	defb 08ch,03ah         ; r7 candle (12,8) chain whip
	defb 04bh,017h         ; r7 floor (11,4) yellow key
	defb 0a2h,017h         ; r7 floor (2,10) yellow key
	defb 0feh              ; next room
	defb 028h,021h         ; r8 candle (8,2) small heart
	defb 02bh,021h         ; r8 candle (11,2) small heart
	defb 02eh,020h         ; r8 candle (14,2) none
	defb 032h,07fh,091h    ; r8 reveal (2,3) chest white bible
	defb 052h,07fh,093h    ; r8 reveal (2,5) chest white bag
	defb 0feh              ; next room
	defb 05bh,022h         ; r9 candle (11,5) large heart
	defb 05eh,020h         ; r9 candle (14,5) none
	defb 0feh              ; next room
	defb 059h,021h         ; r10 candle (9,5) small heart
	defb 05ch,021h         ; r10 candle (12,5) small heart
	defb 09ch,07fh,0d8h    ; r10 reveal (12,9) vendor holy water slot0
	defb 0feh              ; next room
	defb 032h,07fh,09ch    ; r11 reveal (2,3) chest axe
	defb 0ffh              ; end stream
	; stage 14
	defb 023h,022h         ; r0 candle (3,2) large heart
	defb 083h,03ah         ; r0 candle (3,8) chain whip
	defb 06dh,017h         ; r0 floor (13,6) yellow key
	defb 0feh              ; next room
	defb 094h,02ch         ; r1 candle (4,9) boots
	defb 098h,022h         ; r1 candle (8,9) large heart
	defb 09ch,035h         ; r1 candle (12,9) slime
	defb 06dh,09ch         ; r1 chest (13,6) axe
	defb 064h,017h         ; r1 floor (4,6) yellow key
	defb 0feh              ; next room
	defb 064h,027h         ; r2 candle (4,6) small orb
	defb 08ch,021h         ; r2 candle (12,8) small heart
	defb 04bh,089h         ; r2 chest (11,4) sapphire ring
	defb 06eh,083h         ; r2 chest (14,6) red shield
	defb 0a6h,017h         ; r2 floor (6,10) yellow key
	defb 0feh              ; next room
	defb 024h,025h         ; r3 candle (4,2) white cross
	defb 029h,020h         ; r3 candle (9,2) none
	defb 0feh              ; next room
	defb 024h,035h         ; r4 candle (4,2) slime
	defb 02dh,021h         ; r4 candle (13,2) small heart
	defb 078h,021h         ; r4 candle (8,7) small heart
	defb 0a5h,017h         ; r4 floor (5,10) yellow key
	defb 0ach,017h         ; r4 floor (12,10) yellow key
	defb 0feh              ; next room
	defb 044h,060h         ; r5 block (4,4) none
	defb 064h,078h         ; r5 block (4,6) white key
	defb 04bh,08fh         ; r5 chest (11,4) map
	defb 0feh              ; next room
	defb 043h,021h         ; r6 candle (3,4) small heart
	defb 049h,025h         ; r6 candle (9,4) white cross
	defb 04ch,021h         ; r6 candle (12,4) small heart
	defb 0a3h,087h         ; r6 chest (3,10) small orb
	defb 096h,0c1h         ; r6 vendor (6,9) candle slot1
	defb 0feh              ; next room
	defb 037h,020h         ; r7 candle (7,3) none
	defb 03ah,021h         ; r7 candle (10,3) small heart
	defb 08ah,034h         ; r7 candle (10,8) blue bag
	defb 093h,021h         ; r7 candle (3,9) small heart
	defb 095h,021h         ; r7 candle (5,9) small heart
	defb 0ffh              ; end stream
	; stage 15
	defb 035h,021h         ; r0 candle (5,3) small heart
	defb 094h,030h         ; r0 candle (4,9) black bible
	defb 04bh,08fh         ; r0 chest (11,4) map
	defb 03ch,07fh,0d6h    ; r0 reveal (12,3) vendor potion slot2
	defb 0feh              ; next room
	defb 096h,022h         ; r1 candle (6,9) large heart
	defb 09ah,030h         ; r1 candle (10,9) black bible
	defb 08dh,022h         ; r1 candle (13,8) large heart
	defb 03bh,022h         ; r1 candle (11,3) large heart
	defb 0a4h,017h         ; r1 floor (4,10) yellow key
	defb 0feh              ; next room
	defb 081h,030h         ; r2 candle (1,8) black bible
	defb 085h,021h         ; r2 candle (5,8) small heart
	defb 089h,021h         ; r2 candle (9,8) small heart
	defb 08dh,029h         ; r2 candle (13,8) sapphire ring
	defb 04bh,091h         ; r2 chest (11,4) white bible
	defb 03ch,07fh,0dch    ; r2 reveal (12,3) vendor cross slot0
	defb 0feh              ; next room
	defb 089h,029h         ; r3 candle (9,8) sapphire ring
	defb 08dh,022h         ; r3 candle (13,8) large heart
	defb 042h,018h         ; r3 floor (2,4) white key
	defb 0feh              ; next room
	defb 04bh,017h         ; r4 floor (11,4) yellow key
	defb 0feh              ; next room
	defb 042h,022h         ; r5 candle (2,4) large heart
	defb 04ah,022h         ; r5 candle (10,4) large heart
	defb 062h,08ah         ; r5 chest (2,6) hourglass
	defb 06bh,083h         ; r5 chest (11,6) red shield
	defb 0ach,08fh         ; r5 chest (12,10) map
	defb 0feh              ; next room
	defb 087h,021h         ; r6 candle (7,8) small heart
	defb 08ch,022h         ; r6 candle (12,8) large heart
	defb 0a9h,017h         ; r6 floor (9,10) yellow key
	defb 0adh,092h         ; r6 chest (13,10) staff
	defb 0feh              ; next room
	defb 0feh              ; next room
	defb 0a4h,017h         ; r8 floor (4,10) yellow key
	defb 0feh              ; next room
	defb 062h,022h         ; r9 candle (2,6) large heart
	defb 076h,027h         ; r9 candle (6,7) small orb
	defb 079h,022h         ; r9 candle (9,7) large heart
	defb 06dh,022h         ; r9 candle (13,6) large heart
	defb 000h              ; end

; hub 5 = stages 16-18 (0x8497)
scenery_list_h5:
	; stage 16
	defb 068h,035h         ; r0 candle (8,6) slime
	defb 096h,021h         ; r0 candle (6,9) small heart
	defb 09bh,035h         ; r0 candle (11,9) slime
	defb 0feh              ; next room
	defb 06ch,017h         ; r1 floor (12,6) yellow key
	defb 0feh              ; next room
	defb 062h,089h         ; r2 chest (2,6) sapphire ring
	defb 0feh              ; next room
	defb 0feh              ; next room
	defb 0feh              ; next room
	defb 056h,022h         ; r5 candle (6,5) large heart
	defb 069h,018h         ; r5 floor (9,6) white key
	defb 0feh              ; next room
	defb 021h,028h         ; r6 candle (1,2) blue gem
	defb 036h,022h         ; r6 candle (6,3) large heart
	defb 094h,021h         ; r6 candle (4,9) small heart
	defb 098h,022h         ; r6 candle (8,9) large heart
	defb 0a6h,092h         ; r6 chest (6,10) staff
	defb 0feh              ; next room
	defb 0feh              ; next room
	defb 0ach,018h         ; r8 floor (12,10) white key
	defb 0feh              ; next room
	defb 057h,02dh         ; r9 candle (7,5) wings
	defb 059h,022h         ; r9 candle (9,5) large heart
	defb 066h,087h         ; r9 chest (6,6) small orb
	defb 068h,08ah         ; r9 chest (8,6) hourglass
	defb 06dh,018h         ; r9 floor (13,6) white key
	defb 0ffh              ; end stream
	; stage 17
	defb 025h,031h         ; r0 candle (5,2) white bible
	defb 058h,021h         ; r0 candle (8,5) small heart
	defb 091h,022h         ; r0 candle (1,9) large heart
	defb 098h,078h         ; r0 block (8,9) white key
	defb 0feh              ; next room
	defb 032h,021h         ; r1 candle (2,3) small heart
	defb 03dh,021h         ; r1 candle (13,3) small heart
	defb 058h,060h         ; r1 block (8,5) none
	defb 078h,060h         ; r1 block (8,7) none
	defb 098h,07fh,0dbh    ; r1 reveal (8,9) vendor holy water slot3
	defb 0a7h,083h         ; r1 chest (7,10) red shield
	defb 061h,017h         ; r1 floor (1,6) yellow key
	defb 0feh              ; next room
	defb 04dh,022h         ; r2 candle (13,4) large heart
	defb 09dh,021h         ; r2 candle (13,9) small heart
	defb 052h,09dh         ; r2 chest (2,5) cross
	defb 094h,060h         ; r2 block (4,9) none
	defb 096h,07fh,091h    ; r2 reveal (6,9) chest white bible
	defb 0a8h,08fh         ; r2 chest (8,10) map
	defb 0feh              ; next room
	defb 047h,030h         ; r3 candle (7,4) black bible
	defb 04ch,022h         ; r3 candle (12,4) large heart
	defb 094h,022h         ; r3 candle (4,9) large heart
	defb 09ch,035h         ; r3 candle (12,9) slime
	defb 06dh,017h         ; r3 floor (13,6) yellow key
	defb 0feh              ; next room
	defb 031h,021h         ; r4 candle (1,3) small heart
	defb 035h,026h         ; r4 candle (5,3) rosary
	defb 03ch,021h         ; r4 candle (12,3) small heart
	defb 084h,022h         ; r4 candle (4,8) large heart
	defb 08ch,022h         ; r4 candle (12,8) large heart
	defb 0aah,08ah         ; r4 chest (10,10) hourglass
	defb 0feh              ; next room
	defb 038h,035h         ; r5 candle (8,3) slime
	defb 03bh,021h         ; r5 candle (11,3) small heart
	defb 03eh,035h         ; r5 candle (14,3) slime
	defb 08eh,022h         ; r5 candle (14,8) large heart
	defb 042h,093h         ; r5 chest (2,4) white bag
	defb 0ach,017h         ; r5 floor (12,10) yellow key
	defb 0feh              ; next room
	defb 03ah,022h         ; r6 candle (10,3) large heart
	defb 084h,021h         ; r6 candle (4,8) small heart
	defb 04dh,08ch         ; r6 chest (13,4) boots
	defb 068h,089h         ; r6 chest (8,6) sapphire ring
	defb 0abh,084h         ; r6 chest (11,10) yellow shield
	defb 09ch,07fh,0e0h    ; r6 reveal (12,9) vendor knife slot0
	defb 090h,060h         ; r6 block (0,9) none
	defb 0feh              ; next room
	defb 08dh,09dh         ; r7 chest (13,8) cross
	defb 0aeh,082h         ; r7 chest (14,10) large heart
	defb 04eh,017h         ; r7 floor (14,4) yellow key
	defb 0feh              ; next room
	defb 038h,020h         ; r8 candle (8,3) none
	defb 078h,020h         ; r8 candle (8,7) none
	defb 04eh,017h         ; r8 floor (14,4) yellow key
	defb 032h,0cah         ; r8 vendor (2,3) red shield slot2
	defb 0feh              ; next room
	defb 044h,017h         ; r9 floor (4,4) yellow key
	defb 032h,0d4h         ; r9 vendor (2,3) potion slot0
	defb 058h,075h         ; r9 block (8,5) slime
	defb 05ah,07fh,085h    ; r9 reveal (10,5) chest white cross
	defb 076h,062h         ; r9 block (6,7) large heart
	defb 078h,062h         ; r9 block (8,7) large heart
	defb 0a9h,092h         ; r9 chest (9,10) staff
	defb 0feh              ; next room
	defb 04dh,018h         ; r10 floor (13,4) white key
	defb 0adh,017h         ; r10 floor (13,10) yellow key
	defb 0feh              ; next room
	defb 043h,034h         ; r11 candle (3,4) blue bag
	defb 0ffh              ; end stream
	; stage 18
	defb 0feh              ; next room
	defb 036h,022h         ; r1 candle (6,3) large heart
	defb 03eh,022h         ; r1 candle (14,3) large heart
	defb 084h,017h         ; r1 floor (4,8) yellow key
	defb 09ch,0e3h         ; r1 vendor (12,9) knife slot3
	defb 0feh              ; next room
	defb 075h,022h         ; r2 candle (5,7) large heart
	defb 07dh,022h         ; r2 candle (13,7) large heart
	defb 081h,092h         ; r2 chest (1,8) staff
	defb 044h,017h         ; r2 floor (4,4) yellow key
	defb 0feh              ; next room
	defb 046h,022h         ; r3 candle (6,4) large heart
	defb 04eh,035h         ; r3 candle (14,4) slime
	defb 091h,020h         ; r3 candle (1,9) none
	defb 096h,022h         ; r3 candle (6,9) large heart
	defb 09eh,021h         ; r3 candle (14,9) small heart
	defb 061h,088h         ; r3 chest (1,6) blue gem
	defb 0feh              ; next room
	defb 022h,035h         ; r4 candle (2,2) slime
	defb 069h,035h         ; r4 candle (9,6) slime
	defb 094h,035h         ; r4 candle (4,9) slime
	defb 09dh,021h         ; r4 candle (13,9) small heart
	defb 041h,08ch         ; r4 chest (1,4) boots
	defb 066h,017h         ; r4 floor (6,6) yellow key
	defb 0feh              ; next room
	defb 03ch,03ah         ; r5 candle (12,3) chain whip
	defb 048h,017h         ; r5 floor (8,4) yellow key
	defb 0b1h,017h         ; r5 floor (1,11) yellow key
	defb 042h,087h         ; r5 chest (2,4) small orb
	defb 0a7h,089h         ; r5 chest (7,10) sapphire ring
	defb 0feh              ; next room
	defb 03ah,020h         ; r6 candle (10,3) none
	defb 046h,021h         ; r6 candle (6,4) small heart
	defb 0bbh,021h         ; r6 candle (11,11) small heart
	defb 031h,018h         ; r6 floor (1,3) white key
	defb 0feh              ; next room
	defb 034h,021h         ; r7 candle (4,3) small heart
	defb 049h,022h         ; r7 candle (9,4) large heart
	defb 07dh,021h         ; r7 candle (13,7) small heart
	defb 091h,022h         ; r7 candle (1,9) large heart
	defb 0a3h,093h         ; r7 chest (3,10) white bag
	defb 066h,017h         ; r7 floor (6,6) yellow key
	defb 0feh              ; next room
	defb 035h,020h         ; r8 candle (5,3) none
	defb 038h,021h         ; r8 candle (8,3) small heart
	defb 03bh,021h         ; r8 candle (11,3) small heart
	defb 094h,020h         ; r8 candle (4,9) none
	defb 098h,022h         ; r8 candle (8,9) large heart
	defb 09ch,021h         ; r8 candle (12,9) small heart
	defb 032h,0d4h         ; r8 vendor (2,3) potion slot0
	defb 000h              ; end

; spawn_bitmask_ptr (seg14 0x85A6): word[stage 0..18] -> per-room spawn
; bitmask. room_spawner indexes by 0xD000 then 0xD001.
; Bits 0-6: zombie, green merman, red merman, hanging bat, flying skull,
; ghost head, roc. Bit 7 appears in some masks but is never dispatched.
spawn_bitmask_ptr:
	defw spawn_mask_s00     ; stage 0
	defw spawn_mask_s01     ; stage 1
	defw spawn_mask_s02     ; stage 2
	defw spawn_mask_s03     ; stage 3
	defw spawn_mask_s04     ; stage 4
	defw spawn_mask_s05     ; stage 5
	defw spawn_mask_s06     ; stage 6
	defw spawn_mask_s07     ; stage 7
	defw spawn_mask_s08     ; stage 8
	defw spawn_mask_s09     ; stage 9
	defw spawn_mask_s10     ; stage 10
	defw spawn_mask_s11     ; stage 11
	defw spawn_mask_s12     ; stage 12
	defw spawn_mask_s13     ; stage 13
	defw spawn_mask_s14     ; stage 14
	defw spawn_mask_s15     ; stage 15
	defw spawn_mask_s16     ; stage 16
	defw spawn_mask_s17     ; stage 17
	defw spawn_mask_s18     ; stage 18

; stage 0 (3 rooms)
spawn_mask_s00:
	defb 000h              ; r0 none
	defb 000h              ; r1 none
	defb 000h              ; r2 none

; stage 1 (8 rooms)
spawn_mask_s01:
	defb 001h              ; r0 zombie
	defb 001h              ; r1 zombie
	defb 000h              ; r2 none
	defb 000h              ; r3 none
	defb 008h              ; r4 hangbat
	defb 001h              ; r5 zombie
	defb 001h              ; r6 zombie
	defb 000h              ; r7 none

; stage 2 (6 rooms)
spawn_mask_s02:
	defb 008h              ; r0 hangbat
	defb 008h              ; r1 hangbat
	defb 001h              ; r2 zombie
	defb 008h              ; r3 hangbat
	defb 002h              ; r4 merman
	defb 002h              ; r5 merman

; stage 3 (6 rooms)
spawn_mask_s03:
	defb 000h              ; r0 none
	defb 000h              ; r1 none
	defb 000h              ; r2 none
	defb 081h              ; r3 zombie, bit7
	defb 008h              ; r4 hangbat
	defb 000h              ; r5 none

; stage 4 (6 rooms)
spawn_mask_s04:
	defb 080h              ; r0 bit7
	defb 000h              ; r1 none
	defb 000h              ; r2 none
	defb 000h              ; r3 none
	defb 0a0h              ; r4 ghosthd, bit7
	defb 080h              ; r5 bit7

; stage 5 (6 rooms)
spawn_mask_s05:
	defb 0a0h              ; r0 ghosthd, bit7
	defb 020h              ; r1 ghosthd
	defb 080h              ; r2 bit7
	defb 080h              ; r3 bit7
	defb 020h              ; r4 ghosthd
	defb 0a0h              ; r5 ghosthd, bit7

; stage 6 (6 rooms)
spawn_mask_s06:
	defb 010h              ; r0 flyskull
	defb 000h              ; r1 none
	defb 000h              ; r2 none
	defb 0a0h              ; r3 ghosthd, bit7
	defb 020h              ; r4 ghosthd
	defb 000h              ; r5 none

; stage 7 (9 rooms)
spawn_mask_s07:
	defb 080h              ; r0 bit7
	defb 080h              ; r1 bit7
	defb 080h              ; r2 bit7
	defb 080h              ; r3 bit7
	defb 000h              ; r4 none
	defb 080h              ; r5 bit7
	defb 000h              ; r6 none
	defb 000h              ; r7 none
	defb 000h              ; r8 none

; stage 8 (8 rooms)
spawn_mask_s08:
	defb 000h              ; r0 none
	defb 020h              ; r1 ghosthd
	defb 000h              ; r2 none
	defb 000h              ; r3 none
	defb 000h              ; r4 none
	defb 000h              ; r5 none
	defb 000h              ; r6 none
	defb 000h              ; r7 none

; stage 9 (9 rooms)
spawn_mask_s09:
	defb 0a0h              ; r0 ghosthd, bit7
	defb 0a0h              ; r1 ghosthd, bit7
	defb 020h              ; r2 ghosthd
	defb 020h              ; r3 ghosthd
	defb 000h              ; r4 none
	defb 000h              ; r5 none
	defb 000h              ; r6 none
	defb 000h              ; r7 none
	defb 000h              ; r8 none

; stage 10 (9 rooms)
spawn_mask_s10:
	defb 008h              ; r0 hangbat
	defb 004h              ; r1 merman3
	defb 004h              ; r2 merman3
	defb 004h              ; r3 merman3
	defb 004h              ; r4 merman3
	defb 004h              ; r5 merman3
	defb 000h              ; r6 none
	defb 000h              ; r7 none
	defb 000h              ; r8 none

; stage 11 (6 rooms)
spawn_mask_s11:
	defb 081h              ; r0 zombie, bit7
	defb 000h              ; r1 none
	defb 040h              ; r2 roc
	defb 040h              ; r3 roc
	defb 040h              ; r4 roc
	defb 080h              ; r5 bit7

; stage 12 (12 rooms)
spawn_mask_s12:
	defb 000h              ; r0 none
	defb 000h              ; r1 none
	defb 000h              ; r2 none
	defb 000h              ; r3 none
	defb 000h              ; r4 none
	defb 000h              ; r5 none
	defb 000h              ; r6 none
	defb 000h              ; r7 none
	defb 000h              ; r8 none
	defb 000h              ; r9 none
	defb 000h              ; r10 none
	defb 000h              ; r11 none

; stage 13 (12 rooms)
spawn_mask_s13:
	defb 000h              ; r0 none
	defb 000h              ; r1 none
	defb 080h              ; r2 bit7
	defb 000h              ; r3 none
	defb 000h              ; r4 none
	defb 000h              ; r5 none
	defb 080h              ; r6 bit7
	defb 080h              ; r7 bit7
	defb 080h              ; r8 bit7
	defb 080h              ; r9 bit7
	defb 080h              ; r10 bit7
	defb 080h              ; r11 bit7

; stage 14 (8 rooms)
spawn_mask_s14:
	defb 080h              ; r0 bit7
	defb 080h              ; r1 bit7
	defb 080h              ; r2 bit7
	defb 080h              ; r3 bit7
	defb 080h              ; r4 bit7
	defb 080h              ; r5 bit7
	defb 080h              ; r6 bit7
	defb 080h              ; r7 bit7

; stage 15 (10 rooms)
spawn_mask_s15:
	defb 000h              ; r0 none
	defb 080h              ; r1 bit7
	defb 080h              ; r2 bit7
	defb 080h              ; r3 bit7
	defb 000h              ; r4 none
	defb 000h              ; r5 none
	defb 000h              ; r6 none
	defb 080h              ; r7 bit7
	defb 000h              ; r8 none
	defb 000h              ; r9 none

; stage 16 (10 rooms)
spawn_mask_s16:
	defb 000h              ; r0 none
	defb 000h              ; r1 none
	defb 000h              ; r2 none
	defb 000h              ; r3 none
	defb 000h              ; r4 none
	defb 000h              ; r5 none
	defb 000h              ; r6 none
	defb 000h              ; r7 none
	defb 000h              ; r8 none
	defb 000h              ; r9 none

; stage 17 (12 rooms)
spawn_mask_s17:
	defb 000h              ; r0 none
	defb 000h              ; r1 none
	defb 000h              ; r2 none
	defb 080h              ; r3 bit7
	defb 000h              ; r4 none
	defb 080h              ; r5 bit7
	defb 000h              ; r6 none
	defb 040h              ; r7 roc
	defb 000h              ; r8 none
	defb 000h              ; r9 none
	defb 040h              ; r10 roc
	defb 000h              ; r11 none

; stage 18 (10 rooms)
spawn_mask_s18:
	defb 000h              ; r0 none
	defb 080h              ; r1 bit7
	defb 000h              ; r2 none
	defb 000h              ; r3 none
	defb 000h              ; r4 none
	defb 000h              ; r5 none
	defb 000h              ; r6 none
	defb 080h              ; r7 bit7
	defb 080h              ; r8 bit7
	defb 000h              ; r9 none

; object_list_ptr (seg14 0x8668): word[hub 0..5] -> packed object streams.
; sub_61a5h indexes by 0xD002. Each hub has 3 streams (0xFF-terminated) =
; the hub's 3 castle stages (stage 0 shares hub 0 but l61c2h skips it).
; 0x00 advances to the next room. List-id = actor type; bit7 stripped at
; spawn (dogs only). Attr = X<<4 | Y, cell*16 px.
object_list_ptr:
	defw object_list_h0,object_list_h1,object_list_h2,object_list_h3,object_list_h4,object_list_h5

; hub 0 = stages 1-3 (0x8674)
object_list_h0:
	; stage 1
	defb 000h              ; next room
	defb 000h              ; next room
	defb 005h,088h        ; r2 dog (8,8)
	defb 000h              ; next room
	defb 085h,046h        ; r3 dog bit7 (4,6)
	defb 000h              ; next room
	defb 000h              ; next room
	defb 000h              ; next room
	defb 000h              ; next room
	defb 085h,06ch        ; r7 dog bit7 (6,12)
	defb 0ffh              ; end stream
	; stage 2
	defb 0ffh              ; end stream
	; stage 3
	defb 005h,087h        ; r0 dog (8,7)
	defb 000h              ; next room
	defb 005h,088h        ; r1 dog (8,8)
	defb 085h,0abh        ; r1 dog bit7 (10,11)
	defb 000h              ; next room
	defb 01fh,067h        ; r2 hanging bat (6,7)
	defb 0ffh              ; end stream

; hub 1 = stages 4-6 (0x868E)
object_list_h1:
	; stage 4
	defb 006h,0ceh        ; r0 pikeman (12,14)
	defb 006h,069h        ; r0 pikeman (6,9)
	defb 000h              ; next room
	defb 006h,0c8h        ; r1 pikeman (12,8)
	defb 006h,064h        ; r1 pikeman (6,4)
	defb 01fh,034h        ; r1 hanging bat (3,4)
	defb 000h              ; next room
	defb 006h,0cbh        ; r2 pikeman (12,11)
	defb 006h,064h        ; r2 pikeman (6,4)
	defb 000h              ; next room
	defb 01fh,033h        ; r3 hanging bat (3,3)
	defb 000h              ; next room
	defb 006h,0cah        ; r4 pikeman (12,10)
	defb 006h,0a6h        ; r4 pikeman (10,6)
	defb 0ffh              ; end stream
	; stage 5
	defb 000h              ; next room
	defb 000h              ; next room
	defb 006h,065h        ; r2 pikeman (6,5)
	defb 000h              ; next room
	defb 006h,06ah        ; r3 pikeman (6,10)
	defb 006h,0aah        ; r3 pikeman (10,10)
	defb 0ffh              ; end stream
	; stage 6
	defb 000h              ; next room
	defb 000h              ; next room
	defb 00ah,05ch        ; r2 skull pile (5,12)
	defb 0ffh              ; end stream

; hub 2 = stages 7-9 (0x86B6)
object_list_h2:
	; stage 7
	defb 000h              ; next room
	defb 00dh,095h        ; r1 hunchback (9,5)
	defb 00dh,09ah        ; r1 hunchback (9,10)
	defb 000h              ; next room
	defb 00bh,0b9h        ; r2 white skeleton (11,9)
	defb 000h              ; next room
	defb 00bh,0cbh        ; r3 white skeleton (12,11)
	defb 000h              ; next room
	defb 00bh,0cdh        ; r4 white skeleton (12,13)
	defb 00dh,08bh        ; r4 hunchback (8,11)
	defb 00dh,055h        ; r4 hunchback (5,5)
	defb 000h              ; next room
	defb 00bh,093h        ; r5 white skeleton (9,3)
	defb 000h              ; next room
	defb 00bh,0b9h        ; r6 white skeleton (11,9)
	defb 000h              ; next room
	defb 00ch,057h        ; r7 raven (5,7)
	defb 000h              ; next room
	defb 00ch,057h        ; r8 raven (5,7)
	defb 0ffh              ; end stream
	; stage 8
	defb 000h              ; next room
	defb 000h              ; next room
	defb 00bh,05dh        ; r2 white skeleton (5,13)
	defb 000h              ; next room
	defb 00bh,099h        ; r3 white skeleton (9,9)
	defb 000h              ; next room
	defb 000h              ; next room
	defb 00ch,055h        ; r5 raven (5,5)
	defb 000h              ; next room
	defb 00ah,099h        ; r6 skull pile (9,9)
	defb 00ch,0c5h        ; r6 raven (12,5)
	defb 000h              ; next room
	defb 00bh,0c8h        ; r7 white skeleton (12,8)
	defb 0ffh              ; end stream
	; stage 9
	defb 000h              ; next room
	defb 00ah,07ch        ; r1 skull pile (7,12)
	defb 000h              ; next room
	defb 00ah,075h        ; r2 skull pile (7,5)
	defb 00ah,07bh        ; r2 skull pile (7,11)
	defb 000h              ; next room
	defb 000h              ; next room
	defb 00ah,075h        ; r4 skull pile (7,5)
	defb 00bh,07bh        ; r4 white skeleton (7,11)
	defb 000h              ; next room
	defb 00dh,075h        ; r5 hunchback (7,5)
	defb 00dh,057h        ; r5 hunchback (5,7)
	defb 000h              ; next room
	defb 00bh,054h        ; r6 white skeleton (5,4)
	defb 000h              ; next room
	defb 000h              ; next room
	defb 00bh,0b3h        ; r8 white skeleton (11,3)
	defb 00dh,057h        ; r8 hunchback (5,7)
	defb 0ffh              ; end stream

; hub 3 = stages 10-12 (0x8706)
object_list_h3:
	; stage 10
	defb 000h              ; next room
	defb 000h              ; next room
	defb 000h              ; next room
	defb 000h              ; next room
	defb 000h              ; next room
	defb 000h              ; next room
	defb 021h,0b3h        ; r6 red merman (11,3)
	defb 021h,0bch        ; r6 red merman (11,12)
	defb 000h              ; next room
	defb 021h,0b8h        ; r7 red merman (11,8)
	defb 000h              ; next room
	defb 021h,0b3h        ; r8 red merman (11,3)
	defb 021h,0bdh        ; r8 red merman (11,13)
	defb 0ffh              ; end stream
	; stage 11
	defb 000h              ; next room
	defb 00dh,059h        ; r1 hunchback (5,9)
	defb 000h              ; next room
	defb 00dh,077h        ; r2 hunchback (7,7)
	defb 000h              ; next room
	defb 000h              ; next room
	defb 000h              ; next room
	defb 00eh,07dh        ; r5 bone dragon (7,13)
	defb 0ffh              ; end stream
	; stage 12
	defb 00eh,09ch        ; r0 bone dragon (9,12)
	defb 000h              ; next room
	defb 000h              ; next room
	defb 000h              ; next room
	defb 000h              ; next room
	defb 00eh,065h        ; r4 bone dragon (6,5)
	defb 000h              ; next room
	defb 00eh,07dh        ; r5 bone dragon (7,13)
	defb 000h              ; next room
	defb 000h              ; next room
	defb 00eh,096h        ; r7 bone dragon (9,6)
	defb 000h              ; next room
	defb 00eh,099h        ; r8 bone dragon (9,9)
	defb 000h              ; next room
	defb 000h              ; next room
	defb 00eh,09ah        ; r10 bone dragon (9,10)
	defb 000h              ; next room
	defb 00eh,09eh        ; r11 bone dragon (9,14)
	defb 0ffh              ; end stream

; hub 4 = stages 13-15 (0x873F)
object_list_h4:
	; stage 13
	defb 00bh,0bch        ; r0 white skeleton (11,12)
	defb 009h,05ch        ; r0 red skeleton (5,12)
	defb 000h              ; next room
	defb 00bh,054h        ; r1 white skeleton (5,4)
	defb 00dh,07bh        ; r1 hunchback (7,11)
	defb 000h              ; next room
	defb 00dh,055h        ; r2 hunchback (5,5)
	defb 00dh,05ah        ; r2 hunchback (5,10)
	defb 00dh,097h        ; r2 hunchback (9,7)
	defb 00dh,0beh        ; r2 hunchback (11,14)
	defb 000h              ; next room
	defb 00bh,056h        ; r3 white skeleton (5,6)
	defb 00bh,05ch        ; r3 white skeleton (5,12)
	defb 00dh,09dh        ; r3 hunchback (9,13)
	defb 000h              ; next room
	defb 00bh,09ch        ; r4 white skeleton (9,12)
	defb 009h,0b2h        ; r4 red skeleton (11,2)
	defb 000h              ; next room
	defb 00bh,05ch        ; r5 white skeleton (5,12)
	defb 00bh,077h        ; r5 white skeleton (7,7)
	defb 00dh,0b6h        ; r5 hunchback (11,6)
	defb 00dh,0bch        ; r5 hunchback (11,12)
	defb 000h              ; next room
	defb 00dh,057h        ; r6 hunchback (5,7)
	defb 000h              ; next room
	defb 00bh,056h        ; r7 white skeleton (5,6)
	defb 00bh,0b4h        ; r7 white skeleton (11,4)
	defb 000h              ; next room
	defb 009h,05bh        ; r8 red skeleton (5,11)
	defb 009h,074h        ; r8 red skeleton (7,4)
	defb 009h,0bah        ; r8 red skeleton (11,10)
	defb 000h              ; next room
	defb 009h,055h        ; r9 red skeleton (5,5)
	defb 009h,07ch        ; r9 red skeleton (7,12)
	defb 009h,0b4h        ; r9 red skeleton (11,4)
	defb 009h,0b7h        ; r9 red skeleton (11,7)
	defb 000h              ; next room
	defb 00bh,079h        ; r10 white skeleton (7,9)
	defb 00bh,0b4h        ; r10 white skeleton (11,4)
	defb 000h              ; next room
	defb 00dh,05ah        ; r11 hunchback (5,10)
	defb 00dh,075h        ; r11 hunchback (7,5)
	defb 00dh,0b6h        ; r11 hunchback (11,6)
	defb 0ffh              ; end stream
	; stage 14
	defb 010h,07ch        ; r0 axe knight (7,12)
	defb 000h              ; next room
	defb 010h,072h        ; r1 axe knight (7,2)
	defb 010h,0bah        ; r1 axe knight (11,10)
	defb 000h              ; next room
	defb 010h,0b9h        ; r2 axe knight (11,9)
	defb 000h              ; next room
	defb 009h,056h        ; r3 red skeleton (5,6)
	defb 009h,05ch        ; r3 red skeleton (5,12)
	defb 009h,0b2h        ; r3 red skeleton (11,2)
	defb 009h,0bah        ; r3 red skeleton (11,10)
	defb 000h              ; next room
	defb 010h,059h        ; r4 axe knight (5,9)
	defb 010h,0b4h        ; r4 axe knight (11,4)
	defb 000h              ; next room
	defb 010h,0bah        ; r5 axe knight (11,10)
	defb 000h              ; next room
	defb 010h,074h        ; r6 axe knight (7,4)
	defb 010h,0bch        ; r6 axe knight (11,12)
	defb 000h              ; next room
	defb 010h,058h        ; r7 axe knight (5,8)
	defb 010h,0bdh        ; r7 axe knight (11,13)
	defb 0ffh              ; end stream
	; stage 15
	defb 000h              ; next room
	defb 010h,058h        ; r1 axe knight (5,8)
	defb 010h,0b5h        ; r1 axe knight (11,5)
	defb 000h              ; next room
	defb 010h,055h        ; r2 axe knight (5,5)
	defb 010h,0b5h        ; r2 axe knight (11,5)
	defb 000h              ; next room
	defb 010h,0bch        ; r3 axe knight (11,12)
	defb 000h              ; next room
	defb 010h,079h        ; r4 axe knight (7,9)
	defb 010h,0b6h        ; r4 axe knight (11,6)
	defb 000h              ; next room
	defb 000h              ; next room
	defb 010h,0bah        ; r6 axe knight (11,10)
	defb 000h              ; next room
	defb 010h,0bah        ; r7 axe knight (11,10)
	defb 000h              ; next room
	defb 010h,0bah        ; r8 axe knight (11,10)
	defb 0ffh              ; end stream

; hub 5 = stages 16-18 (0x87CE)
object_list_h5:
	; stage 16
	defb 000h              ; next room
	defb 012h,0b8h        ; r1 giant bat (11,8)
	defb 000h              ; next room
	defb 012h,097h        ; r2 giant bat (9,7)
	defb 000h              ; next room
	defb 012h,098h        ; r3 giant bat (9,8)
	defb 000h              ; next room
	defb 012h,0bah        ; r4 giant bat (11,10)
	defb 000h              ; next room
	defb 000h              ; next room
	defb 000h              ; next room
	defb 012h,056h        ; r7 giant bat (5,6)
	defb 000h              ; next room
	defb 012h,058h        ; r8 giant bat (5,8)
	defb 0ffh              ; end stream
	; stage 17
	defb 000h              ; next room
	defb 00bh,0b6h        ; r1 white skeleton (11,6)
	defb 000h              ; next room
	defb 00dh,07eh        ; r2 hunchback (7,14)
	defb 000h              ; next room
	defb 010h,076h        ; r3 axe knight (7,6)
	defb 000h              ; next room
	defb 010h,05bh        ; r4 axe knight (5,11)
	defb 010h,0bah        ; r4 axe knight (11,10)
	defb 000h              ; next room
	defb 010h,053h        ; r5 axe knight (5,3)
	defb 000h              ; next room
	defb 00dh,079h        ; r6 hunchback (7,9)
	defb 00dh,0b9h        ; r6 hunchback (11,9)
	defb 000h              ; next room
	defb 000h              ; next room
	defb 00dh,053h        ; r8 hunchback (5,3)
	defb 000h              ; next room
	defb 00dh,055h        ; r9 hunchback (5,5)
	defb 0ffh              ; end stream
	; stage 18
	defb 000h              ; next room
	defb 010h,056h        ; r1 axe knight (5,6)
	defb 000h              ; next room
	defb 010h,095h        ; r2 axe knight (9,5)
	defb 000h              ; next room
	defb 00dh,07dh        ; r3 hunchback (7,13)
	defb 00dh,077h        ; r3 hunchback (7,7)
	defb 000h              ; next room
	defb 00dh,077h        ; r4 hunchback (7,7)
	defb 00dh,053h        ; r4 hunchback (5,3)
	defb 000h              ; next room
	defb 00dh,05ah        ; r5 hunchback (5,10)
	defb 00dh,054h        ; r5 hunchback (5,4)
	defb 000h              ; next room
	defb 00dh,07bh        ; r6 hunchback (7,11)
	defb 00dh,0b4h        ; r6 hunchback (11,4)
	defb 000h              ; next room
	defb 00dh,079h        ; r7 hunchback (7,9)
	defb 00dh,055h        ; r7 hunchback (5,5)
	defb 000h              ; next room
	defb 010h,0b6h        ; r8 axe knight (11,6)
	defb 0ffh              ; end stream

; Sound / VDP remainder (seg14 0x8824). IRQ tick at 0x8964; play_sound
; sfx word table 0x8D8D, music 6-byte records 0x8DC9. Not yet reversed.
	INCBIN "seg14.bin", 0x0824, 0x17DC


; Packed scenery streams (seg14 0x8000).  Grammar: scenery_next_room / scenery_next_stage / scenery_end_hub;
; record = pos (Y<<4|X), attr (kind | item_*).  scenery_cover adds a reveal byte.
; Vendor attr stays hex (bits5-2 = offer slot, not item id).

; scenery_list_ptr (seg14 0x8000): word[hub 0..5] -> packed scenery streams.
; scenery_list_lookup indexes by 0xD002; stage 0 returns scenery_list_s00.
; Unpacker scenery_unpack expands into 0xE000 (3 stages x 16 rooms x 24 bytes).
; 0xFE next room, 0xFF next stage, 0x00 end hub. Instantiator 0x5B22 fills
; 8 C470 candle/block slots, C500 floor items/chests, C5B5/C5C5 vendors.
; Record: pos (hi nibble Y, lo nibble X, cell*16 px), attr; attr 0x7F adds a
; third byte (reveal). 0x7F is still a 32x32 covering wall: bits7-5 = 011,
; item 0x1F, bit7 clear, so scenery_room_load stamps C470 bricks and parks
; the extra byte in +09. Do not treat extra as the surface (that is a chest
; or vendor only after the wall is whipped). attr bits7-5: 000 floor pickup,
; 001 candle/brazier, 010 16x16 block (block_stamp kind 2; unused in the
; packed stream), 011 32x32 block; bits7-6 10 chest, 11 vendor. bits4-0 =
; item id (vendor uses bits5-2 as vendor_offer_id index). Stage 18 room 9
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
	defb 094h, scenery_candle | item_small_heart         ; r0 candle (4,9) small heart
	defb 09ch, scenery_candle | item_small_heart         ; r0 candle (12,9) small heart
	defb scenery_next_room              ; next room
	defb 094h, scenery_candle | item_large_heart         ; r1 candle (4,9) large heart
	defb 09ch, scenery_candle | item_large_heart         ; r1 candle (12,9) large heart
	defb scenery_next_room              ; next room
	defb 094h, scenery_candle | item_chain_whip         ; r2 candle (4,9) chain whip
	defb scenery_end_hub              ; end

; hub 0 = stages 1-3 (0x8019)
scenery_list_h0:
	; stage 1
	defb 097h, scenery_candle | item_sapphire_ring         ; r0 candle (7,9) sapphire ring
	defb 09bh, scenery_candle | item_small_heart         ; r0 candle (11,9) small heart
	defb scenery_next_room              ; next room
	defb 093h, scenery_candle | item_small_heart         ; r1 candle (3,9) small heart
	defb 097h, scenery_candle | item_rosary         ; r1 candle (7,9) rosary
	defb 049h, scenery_candle | item_small_heart         ; r1 candle (9,4) small heart
	defb 08bh, scenery_candle | item_sapphire_ring         ; r1 candle (11,8) sapphire ring
	defb scenery_next_room              ; next room
	defb 046h, scenery_candle | item_small_heart         ; r2 candle (6,4) small heart
	defb 0b4h, scenery_floor | item_yellow_key         ; r2 floor (4,11) yellow key
	defb 0a8h, scenery_block32 | item_white_key         ; r2 block (8,10) white key
	defb 0bbh, scenery_chest | item_large_heart         ; r2 chest (11,11) large heart
	defb 04bh, scenery_candle | item_small_heart         ; r2 candle (11,4) small heart
	defb 09dh, scenery_candle | item_small_heart         ; r2 candle (13,9) small heart
	defb scenery_next_room              ; next room
	defb 0a2h, scenery_candle | item_small_heart         ; r3 candle (2,10) small heart
	defb 064h, scenery_candle | item_chain_whip         ; r3 candle (4,6) chain whip
	defb 0a8h, scenery_candle | item_small_heart         ; r3 candle (8,10) small heart
	defb 05bh, scenery_candle | item_large_heart         ; r3 candle (11,5) large heart
	defb 073h, scenery_chest | item_wings         ; r3 chest (3,7) wings
	defb scenery_next_room              ; next room
	defb 023h, scenery_candle         ; r4 candle (3,2) none
	defb 063h, scenery_candle | item_small_heart         ; r4 candle (3,6) small heart
	defb 096h, scenery_candle | item_small_heart         ; r4 candle (6,9) small heart
	defb 04bh, scenery_candle | item_large_heart         ; r4 candle (11,4) large heart
	defb 09ah, scenery_candle         ; r4 candle (10,9) none
	defb 032h, scenery_chest | item_boots         ; r4 chest (2,3) boots
	defb 072h, scenery_chest | item_red_shield         ; r4 chest (2,7) red shield
	defb 0b2h, scenery_floor | item_yellow_key         ; r4 floor (2,11) yellow key
	defb scenery_next_room              ; next room
	defb 094h, scenery_candle         ; r5 candle (4,9) none
	defb 089h, scenery_candle | item_chain_whip         ; r5 candle (9,8) chain whip
	defb scenery_next_room              ; next room
	defb 087h, scenery_candle | item_black_bible         ; r6 candle (7,8) black bible
	defb 05dh, scenery_candle | item_small_heart         ; r6 candle (13,5) small heart
	defb scenery_next_room              ; next room
	defb 0a6h, scenery_candle | item_large_heart         ; r7 candle (6,10) large heart
	defb 0aah, scenery_candle         ; r7 candle (10,10) none
	defb 078h, scenery_floor | item_yellow_key         ; r7 floor (8,7) yellow key
	defb 0ach, scenery_cover, 0e1h    ; r7 reveal (12,10) vendor knife slot1
	defb scenery_next_stage              ; end stream
	; stage 2
	defb 02ah, 0d5h         ; r0 vendor (10,2) potion slot1
	defb 092h, scenery_candle | item_small_heart         ; r0 candle (2,9) small heart
	defb 048h, scenery_candle | item_small_heart         ; r0 candle (8,4) small heart
	defb 06ah, scenery_block32 | item_large_heart         ; r0 block (10,6) large heart
	defb 06ch, scenery_block32 | item_large_heart         ; r0 block (12,6) large heart
	defb 0a8h, scenery_block32 | item_yellow_key         ; r0 block (8,10) yellow key
	defb 0aah, scenery_block32 | item_large_heart         ; r0 block (10,10) large heart
	defb 0ach, scenery_cover, 0ceh    ; r0 reveal (12,10) vendor yellow shield slot2
	defb scenery_next_room              ; next room
	defb 062h, scenery_block32 | item_yellow_key         ; r1 block (2,6) yellow key
	defb 064h, scenery_block32 | item_yellow_key         ; r1 block (4,6) yellow key
	defb 066h, scenery_block32         ; r1 block (6,6) none
	defb 0a2h, scenery_cover, scenery_chest | item_hourglass    ; r1 reveal (2,10) chest hourglass
	defb 0a4h, scenery_cover, scenery_chest | item_boots    ; r1 reveal (4,10) chest boots
	defb 0a6h, scenery_block32 | item_yellow_key         ; r1 block (6,10) yellow key
	defb 037h, scenery_candle | item_small_orb         ; r1 candle (7,3) small orb
	defb 031h, scenery_chest | item_white_bible         ; r1 chest (1,3) white bible
	defb scenery_next_room              ; next room
	defb 034h, scenery_candle | item_blue_gem         ; r2 candle (4,3) blue gem
	defb 075h, scenery_candle | item_small_heart         ; r2 candle (5,7) small heart
	defb 07ah, scenery_candle | item_white_cross         ; r2 candle (10,7) white cross
	defb 03eh, scenery_candle | item_large_heart         ; r2 candle (14,3) large heart
	defb 056h, scenery_chest | item_map         ; r2 chest (6,5) map
	defb 04ah, scenery_cover, 0dbh    ; r2 reveal (10,4) vendor holy water slot3
	defb scenery_next_room              ; next room
	defb 074h, scenery_candle | item_large_heart         ; r3 candle (4,7) large heart
	defb 036h, scenery_candle | item_large_heart         ; r3 candle (6,3) large heart
	defb 03ch, scenery_candle | item_large_heart         ; r3 candle (12,3) large heart
	defb 08eh, scenery_candle | item_sapphire_ring         ; r3 candle (14,8) sapphire ring
	defb 0b8h, scenery_floor | item_yellow_key         ; r3 floor (8,11) yellow key
	defb scenery_next_room              ; next room
	defb 052h, scenery_block32 | item_axe         ; r4 block (2,5) axe
	defb 054h, scenery_candle | item_sapphire_ring         ; r4 candle (4,5) sapphire ring
	defb 04eh, scenery_candle | item_small_heart         ; r4 candle (14,4) small heart
	defb scenery_next_room              ; next room
	defb 045h, scenery_candle | item_large_heart         ; r5 candle (5,4) large heart
	defb 04ch, scenery_candle | item_black_bible         ; r5 candle (12,4) black bible
	defb 07ch, scenery_block32 | item_white_key         ; r5 block (12,7) white key
	defb scenery_next_stage              ; end stream
	; stage 3
	defb 068h, scenery_candle | item_small_heart         ; r0 candle (8,6) small heart
	defb 093h, scenery_candle | item_small_heart         ; r0 candle (3,9) small heart
	defb 098h, scenery_candle | item_sapphire_ring         ; r0 candle (8,9) sapphire ring
	defb 0b2h, scenery_floor | item_yellow_key         ; r0 floor (2,11) yellow key
	defb 074h, scenery_chest | item_yellow_shield         ; r0 chest (4,7) yellow shield
	defb scenery_next_room              ; next room
	defb 097h, scenery_candle | item_blue_bag         ; r1 candle (7,9) blue bag
	defb 05dh, scenery_candle | item_blue_gem         ; r1 candle (13,5) blue gem
	defb 09ch, scenery_floor | item_yellow_key         ; r1 floor (12,9) yellow key
	defb scenery_next_room              ; next room
	defb 0a1h, scenery_candle | item_chain_whip         ; r2 candle (1,10) chain whip
	defb 06ah, scenery_cover, 0dch    ; r2 reveal (10,6) vendor cross slot0
	defb 0aah, scenery_block32 | item_white_key         ; r2 block (10,10) white key
	defb 077h, scenery_chest | item_hourglass         ; r2 chest (7,7) hourglass
	defb 0b7h, scenery_floor | item_yellow_key         ; r2 floor (7,11) yellow key
	defb 0bch, scenery_chest | item_sapphire_ring         ; r2 chest (12,11) sapphire ring
	defb scenery_next_room              ; next room
	defb 053h, scenery_candle | item_chain_whip         ; r3 candle (3,5) chain whip
	defb 093h, scenery_candle | item_small_heart         ; r3 candle (3,9) small heart
	defb 096h, scenery_candle | item_sapphire_ring         ; r3 candle (6,9) sapphire ring
	defb 099h, scenery_candle | item_small_heart         ; r3 candle (9,9) small heart
	defb 09ch, scenery_candle | item_black_bible         ; r3 candle (12,9) black bible
	defb 05ch, scenery_floor | item_yellow_key         ; r3 floor (12,5) yellow key
	defb scenery_next_room              ; next room
	defb 053h, scenery_chest | item_white_cross         ; r4 chest (3,5) white cross
	defb 0b3h, scenery_chest | item_red_shield         ; r4 chest (3,11) red shield
	defb scenery_next_room              ; next room
	defb 087h, scenery_candle | item_large_heart         ; r5 candle (7,8) large heart
	defb 08ah, scenery_candle | item_small_heart         ; r5 candle (10,8) small heart
	defb scenery_end_hub              ; end

; hub 1 = stages 4-6 (0x80e7)
scenery_list_h1:
	; stage 4
	defb 098h, scenery_candle | item_small_heart         ; r0 candle (8,9) small heart
	defb 09eh, scenery_candle | item_blue_gem         ; r0 candle (14,9) blue gem
	defb 048h, scenery_candle | item_slime         ; r0 candle (8,4) slime (not a wall)
	defb 05dh, scenery_floor | item_yellow_key         ; r0 floor (13,5) yellow key
	defb 042h, scenery_block32 | item_white_key         ; r0 block (2,4) white key
	defb scenery_next_room              ; next room
	defb 034h, scenery_candle | item_rosary         ; r1 candle (4,3) rosary
	defb 084h, scenery_candle | item_sapphire_ring         ; r1 candle (4,8) sapphire ring
	defb 089h, scenery_candle | item_large_heart         ; r1 candle (9,8) large heart
	defb 07ch, scenery_floor | item_yellow_key         ; r1 floor (12,7) yellow key
	defb 03ch, scenery_candle | item_slime         ; r1 candle (12,3) slime
	defb 0b9h, scenery_chest | item_map         ; r1 chest (9,11) map
	defb 0ach, 0c4h         ; r1 vendor (12,10) lockpick slot0
	defb scenery_next_room              ; next room
	defb 035h, scenery_candle | item_slime         ; r2 candle (5,3) slime
	defb 083h, scenery_candle | item_small_heart         ; r2 candle (3,8) small heart
	defb 04ch, scenery_candle | item_small_orb         ; r2 candle (12,4) small orb
	defb 0adh, scenery_candle | item_blue_gem         ; r2 candle (13,10) blue gem
	defb 07dh, scenery_floor | item_yellow_key         ; r2 floor (13,7) yellow key
	defb 044h, 0d6h         ; r2 vendor (4,4) potion slot2
	defb scenery_next_room              ; next room
	defb 034h, scenery_candle | item_large_heart         ; r3 candle (4,3) large heart
	defb 03ah, scenery_candle | item_large_heart         ; r3 candle (10,3) large heart
	defb 0b1h, scenery_chest | item_white_bible         ; r3 chest (1,11) white bible
	defb 097h, scenery_floor | item_yellow_key         ; r3 floor (7,9) yellow key
	defb scenery_next_room              ; next room
	defb 031h, scenery_candle | item_slime         ; r4 candle (1,3) slime
	defb 037h, scenery_candle | item_small_orb         ; r4 candle (7,3) small orb
	defb 03bh, scenery_candle | item_small_heart         ; r4 candle (11,3) small heart
	defb 0bbh, scenery_floor | item_yellow_key         ; r4 floor (11,11) yellow key
	defb 072h, scenery_chest | item_hourglass         ; r4 chest (2,7) hourglass
	defb 07ah, scenery_chest | item_axe         ; r4 chest (10,7) axe
	defb scenery_next_room              ; next room
	defb 036h, scenery_candle | item_small_heart         ; r5 candle (6,3) small heart
	defb 07dh, scenery_candle | item_large_heart         ; r5 candle (13,7) large heart
	defb 091h, scenery_chest | item_red_shield         ; r5 chest (1,9) red shield
	defb scenery_next_stage              ; end stream
	; stage 5
	defb 024h, scenery_candle | item_slime         ; r0 candle (4,2) slime
	defb 028h, scenery_candle | item_small_heart         ; r0 candle (8,2) small heart
	defb 02ch, scenery_candle | item_small_heart         ; r0 candle (12,2) small heart
	defb scenery_next_room              ; next room
	defb 047h, scenery_candle | item_large_heart         ; r1 candle (7,4) large heart
	defb 04bh, scenery_candle | item_small_heart         ; r1 candle (11,4) small heart
	defb 076h, scenery_floor | item_yellow_key         ; r1 floor (6,7) yellow key
	defb 09ah, scenery_floor | item_yellow_key         ; r1 floor (10,9) yellow key
	defb scenery_next_room              ; next room
	defb 022h, scenery_candle | item_rosary         ; r2 candle (2,2) rosary
	defb 03bh, scenery_candle | item_large_heart         ; r2 candle (11,3) large heart
	defb 07ah, scenery_chest | item_sapphire_ring         ; r2 chest (10,7) sapphire ring
	defb scenery_next_room              ; next room
	defb 082h, scenery_candle | item_large_heart         ; r3 candle (2,8) large heart
	defb 04ch, scenery_block32 | item_white_key         ; r3 block (12,4) white key
	defb 08ch, scenery_cover, 0d3h    ; r3 reveal (12,8) vendor hourglass slot3
	defb 05bh, scenery_chest | item_white_bag         ; r3 chest (11,5) white bag
	defb 09bh, scenery_chest | item_holy_water         ; r3 chest (11,9) holy water
	defb scenery_next_room              ; next room
	defb 044h, scenery_candle | item_small_heart         ; r4 candle (4,4) small heart
	defb 04dh, scenery_candle | item_slime         ; r4 candle (13,4) slime
	defb 048h, scenery_candle | item_small_heart         ; r4 candle (8,4) small heart
	defb 083h, scenery_candle | item_small_heart         ; r4 candle (3,8) small heart
	defb 088h, scenery_candle | item_small_heart         ; r4 candle (8,8) small heart
	defb 095h, scenery_floor | item_yellow_key         ; r4 floor (5,9) yellow key
	defb 09ch, scenery_floor | item_yellow_key         ; r4 floor (12,9) yellow key
	defb scenery_next_room              ; next room
	defb 035h, scenery_candle | item_slime         ; r5 candle (5,3) slime
	defb 03dh, scenery_candle | item_slime         ; r5 candle (13,3) slime
	defb 094h, scenery_candle | item_small_heart         ; r5 candle (4,9) small heart
	defb 099h, scenery_candle | item_slime         ; r5 candle (9,9) slime
	defb 09ch, scenery_candle | item_small_heart         ; r5 candle (12,9) small heart
	defb scenery_next_stage              ; end stream
	; stage 6
	defb 067h, scenery_floor | item_yellow_key         ; r0 floor (7,6) yellow key
	defb 054h, scenery_candle | item_sapphire_ring         ; r0 candle (4,5) sapphire ring
	defb 02ch, scenery_cover, 0d5h    ; r0 reveal (12,2) vendor potion slot1
	; 32x32 wall row (Y=10): heart, three slimes, white key
	defb 0a4h, scenery_block32 | item_large_heart         ; r0 block (4,10) large heart
	defb 0a6h, scenery_block32 | item_slime         ; r0 block (6,10) slime
	defb 0a8h, scenery_block32 | item_slime         ; r0 block (8,10) slime
	defb 0aah, scenery_block32 | item_slime         ; r0 block (10,10) slime
	defb 0ach, scenery_block32 | item_white_key         ; r0 block (12,10) white key
	defb scenery_next_room              ; next room
	defb 022h, scenery_candle | item_chain_whip         ; r1 candle (2,2) chain whip
	defb 026h, scenery_candle | item_slime         ; r1 candle (6,2) slime
	defb 02ah, scenery_candle | item_small_heart         ; r1 candle (10,2) small heart
	defb 082h, scenery_candle | item_slime         ; r1 candle (2,8) slime
	defb 086h, scenery_candle | item_slime         ; r1 candle (6,8) slime
	defb 08ah, scenery_candle | item_large_heart         ; r1 candle (10,8) large heart
	defb 09ch, scenery_floor | item_yellow_key         ; r1 floor (12,9) yellow key
	defb scenery_next_room              ; next room
	defb 038h, scenery_candle | item_large_heart         ; r2 candle (8,3) large heart
	defb 073h, scenery_candle | item_small_heart         ; r2 candle (3,7) small heart
	defb 07bh, scenery_candle | item_small_heart         ; r2 candle (11,7) small heart
	defb 032h, scenery_cover, 0e3h    ; r2 reveal (2,3) vendor knife slot3
	defb 044h, scenery_floor | item_yellow_key         ; r2 floor (4,4) yellow key
	defb 088h, scenery_cover, scenery_chest | item_sapphire_ring    ; r2 reveal (8,8) chest sapphire ring
	defb 0a2h, scenery_chest | item_chain_whip         ; r2 chest (2,10) chain whip
	defb scenery_next_room              ; next room
	defb 062h, scenery_candle | item_rosary         ; r3 candle (2,6) rosary
	defb 066h, scenery_candle | item_chain_whip         ; r3 candle (6,6) chain whip
	defb 09dh, scenery_floor | item_yellow_key         ; r3 floor (13,9) yellow key
	defb scenery_next_room              ; next room
	defb 062h, scenery_candle | item_small_heart         ; r4 candle (2,6) small heart
	defb 066h, scenery_candle | item_slime         ; r4 candle (6,6) slime
	defb 06ah, scenery_candle | item_large_heart         ; r4 candle (10,6) large heart
	defb 06eh, scenery_candle | item_slime         ; r4 candle (14,6) slime
	defb scenery_next_room              ; next room
	defb 062h, scenery_candle | item_small_orb         ; r5 candle (2,6) small orb
	defb 06eh, scenery_candle | item_small_heart         ; r5 candle (14,6) small heart
	defb 076h, scenery_candle | item_small_heart         ; r5 candle (6,7) small heart
	defb 07ah, scenery_candle | item_small_heart         ; r5 candle (10,7) small heart
	defb scenery_end_hub              ; end

; hub 2 = stages 7-9 (0x81b3)
scenery_list_h2:
	; stage 7
	defb 09ah, scenery_candle | item_small_heart         ; r0 candle (10,9) small heart
	defb 032h, 0c0h         ; r0 vendor (2,3) candle slot0
	defb scenery_next_room              ; next room
	defb 033h, scenery_candle | item_small_heart         ; r1 candle (3,3) small heart
	defb 056h, scenery_candle | item_large_heart         ; r1 candle (6,5) large heart
	defb 05ah, scenery_candle | item_slime         ; r1 candle (10,5) slime
	defb 092h, scenery_candle | item_small_heart         ; r1 candle (2,9) small heart
	defb 09eh, scenery_candle | item_large_heart         ; r1 candle (14,9) large heart
	defb 084h, scenery_chest | item_black_bible         ; r1 chest (4,8) black bible
	defb 04eh, scenery_floor | item_yellow_key         ; r1 floor (14,4) yellow key
	defb scenery_next_room              ; next room
	defb 03eh, scenery_candle | item_large_heart         ; r2 candle (14,3) large heart
	defb 056h, scenery_candle | item_large_heart         ; r2 candle (6,5) large heart
	defb 064h, scenery_candle | item_large_heart         ; r2 candle (4,6) large heart
	defb 099h, scenery_candle | item_black_bible         ; r2 candle (9,9) black bible
	defb 0a2h, scenery_floor | item_yellow_key         ; r2 floor (2,10) yellow key
	defb scenery_next_room              ; next room
	defb 051h, scenery_candle | item_sapphire_ring         ; r3 candle (1,5) sapphire ring
	defb 04ch, scenery_candle | item_slime         ; r3 candle (12,4) slime
	defb 08ch, scenery_block32 | item_white_key         ; r3 block (12,8) white key
	defb 06dh, scenery_chest | item_red_shield         ; r3 chest (13,6) red shield
	defb scenery_next_room              ; next room
	defb 024h, scenery_candle | item_large_heart         ; r4 candle (4,2) large heart
	defb 02ch, scenery_candle | item_blue_bag         ; r4 candle (12,2) blue bag
	defb 081h, scenery_candle | item_small_heart         ; r4 candle (1,8) small heart
	defb 094h, scenery_candle | item_small_heart         ; r4 candle (4,9) small heart
	defb 044h, scenery_chest | item_yellow_shield         ; r4 chest (4,4) yellow shield
	defb 04ah, scenery_floor | item_yellow_key         ; r4 floor (10,4) yellow key
	defb 07ah, scenery_chest | item_axe         ; r4 chest (10,7) axe
	defb scenery_next_room              ; next room
	defb 039h, scenery_candle         ; r5 candle (9,3) none
	defb 055h, scenery_candle | item_large_heart         ; r5 candle (5,5) large heart
	defb 098h, scenery_candle         ; r5 candle (8,9) none
	defb 082h, scenery_chest | item_map         ; r5 chest (2,8) map
	defb 06bh, scenery_floor | item_yellow_key         ; r5 floor (11,6) yellow key
	defb scenery_next_room              ; next room
	defb 044h, scenery_candle | item_large_heart         ; r6 candle (4,4) large heart
	defb 094h, scenery_candle | item_slime         ; r6 candle (4,9) slime
	defb 098h, scenery_candle | item_large_heart         ; r6 candle (8,9) large heart
	defb 09bh, scenery_floor | item_yellow_key         ; r6 floor (11,9) yellow key
	defb scenery_next_room              ; next room
	defb 091h, scenery_candle | item_small_heart         ; r7 candle (1,9) small heart
	defb 094h, scenery_candle | item_large_heart         ; r7 candle (4,9) large heart
	defb 098h, scenery_candle | item_small_heart         ; r7 candle (8,9) small heart
	defb 07eh, scenery_floor | item_yellow_key         ; r7 floor (14,7) yellow key
	defb scenery_next_room              ; next room
	defb 059h, scenery_candle | item_small_heart         ; r8 candle (9,5) small heart
	defb 08ch, scenery_candle | item_large_heart         ; r8 candle (12,8) large heart
	defb 094h, scenery_candle         ; r8 candle (4,9) none
	defb 092h, 0c8h         ; r8 vendor (2,9) red shield slot0
	defb scenery_next_stage              ; end stream
	; stage 8
	defb 075h, scenery_candle | item_slime         ; r0 candle (5,7) slime
	defb 056h, scenery_block32 | item_slime         ; r0 block (6,5) slime
	defb 058h, scenery_block32 | item_slime         ; r0 block (8,5) slime
	defb 05ah, scenery_block32 | item_slime         ; r0 block (10,5) slime
	defb 076h, scenery_block32 | item_slime         ; r0 block (6,7) slime
	defb 078h, scenery_block32 | item_slime         ; r0 block (8,7) slime
	defb 07ah, scenery_cover, scenery_chest | item_sapphire_ring    ; r0 reveal (10,7) chest sapphire ring
	defb 07ch, scenery_block32 | item_yellow_key         ; r0 block (12,7) yellow key
	defb scenery_next_room              ; next room
	defb 065h, scenery_candle | item_boots         ; r1 candle (5,6) boots
	defb 06ah, scenery_candle | item_chain_whip         ; r1 candle (10,6) chain whip
	defb 06ch, scenery_candle | item_small_heart         ; r1 candle (12,6) small heart
	defb 074h, scenery_cover, scenery_chest | item_lockpick    ; r1 reveal (4,7) chest lockpick
	defb 076h, scenery_cover, scenery_chest | item_map    ; r1 reveal (6,7) chest map
	defb 078h, scenery_block32         ; r1 block (8,7) none
	defb 07ch, scenery_block32 | item_yellow_key         ; r1 block (12,7) yellow key
	defb scenery_next_room              ; next room
	defb 02bh, scenery_candle | item_small_heart         ; r2 candle (11,2) small heart
	defb 064h, scenery_candle | item_small_heart         ; r2 candle (4,6) small heart
	defb 068h, scenery_candle | item_black_bible         ; r2 candle (8,6) black bible
	defb 07ch, 0cfh         ; r2 vendor (12,7) yellow shield slot3
	defb scenery_next_room              ; next room
	defb 037h, scenery_candle | item_large_heart         ; r3 candle (7,3) large heart
	defb 077h, scenery_candle | item_slime         ; r3 candle (7,7) slime
	defb 07eh, scenery_candle         ; r3 candle (14,7) none
	defb 082h, scenery_chest | item_boots         ; r3 chest (2,8) boots
	defb 04ah, scenery_floor | item_yellow_key         ; r3 floor (10,4) yellow key
	defb 07ch, 0d3h         ; r3 vendor (12,7) hourglass slot3
	defb scenery_next_room              ; next room
	defb 026h, scenery_candle | item_small_heart         ; r4 candle (6,2) small heart
	defb 02ah, scenery_candle | item_small_heart         ; r4 candle (10,2) small heart
	defb 084h, scenery_candle | item_large_heart         ; r4 candle (4,8) large heart
	defb 0a1h, scenery_floor | item_yellow_key         ; r4 floor (1,10) yellow key
	defb scenery_next_room              ; next room
	defb 054h, scenery_candle | item_wings         ; r5 candle (4,5) wings
	defb 059h, scenery_candle | item_slime         ; r5 candle (9,5) slime
	defb 0bbh, scenery_candle | item_small_heart         ; r5 candle (11,11) small heart
	defb 05ah, scenery_cover, scenery_chest | item_large_heart    ; r5 reveal (10,5) chest large heart
	defb scenery_next_room              ; next room
	defb scenery_next_room              ; next room
	defb 072h, scenery_candle | item_slime         ; r7 candle (2,7) slime
	defb 075h, scenery_candle | item_slime         ; r7 candle (5,7) slime
	defb 042h, scenery_floor | item_white_key         ; r7 floor (2,4) white key
	defb 04ch, scenery_block32 | item_slime         ; r7 block (12,4) slime
	defb 08ch, scenery_cover, scenery_chest | item_knife    ; r7 reveal (12,8) chest knife
	defb 0ach, scenery_block32 | item_large_heart         ; r7 block (12,10) large heart
	defb scenery_next_stage              ; end stream
	; stage 9
	defb 068h, scenery_chest | item_sapphire_ring         ; r0 chest (8,6) sapphire ring
	defb scenery_next_room              ; next room
	defb 05eh, scenery_candle | item_small_heart         ; r1 candle (14,5) small heart
	defb scenery_next_room              ; next room
	defb 043h, scenery_candle | item_slime         ; r2 candle (3,4) slime
	defb 046h, scenery_candle | item_slime         ; r2 candle (6,4) slime
	defb 049h, scenery_candle | item_blue_gem         ; r2 candle (9,4) blue gem
	defb 04ch, scenery_candle | item_boots         ; r2 candle (12,4) boots
	defb scenery_next_room              ; next room
	defb scenery_next_room              ; next room
	defb 046h, scenery_candle | item_blue_gem         ; r4 candle (6,4) blue gem
	defb 049h, scenery_candle | item_large_heart         ; r4 candle (9,4) large heart
	defb 03ch, scenery_block32 | item_yellow_key         ; r4 block (12,3) yellow key
	defb 0aeh, scenery_chest | item_sapphire_ring         ; r4 chest (14,10) sapphire ring
	defb 06bh, scenery_floor | item_yellow_key         ; r4 floor (11,6) yellow key
	defb 06eh, scenery_floor | item_yellow_key         ; r4 floor (14,6) yellow key
	defb scenery_next_room              ; next room
	defb 091h, scenery_candle | item_white_cross         ; r5 candle (1,9) white cross
	defb 097h, scenery_candle | item_small_heart         ; r5 candle (7,9) small heart
	defb 06ah, scenery_floor | item_yellow_key         ; r5 floor (10,6) yellow key
	defb 0a9h, scenery_chest | item_large_heart         ; r5 chest (9,10) large heart
	defb scenery_next_room              ; next room
	defb 034h, scenery_candle | item_blue_gem         ; r6 candle (4,3) blue gem
	defb 03bh, scenery_candle | item_small_heart         ; r6 candle (11,3) small heart
	defb 0a4h, scenery_candle | item_small_heart         ; r6 candle (4,10) small heart
	defb 042h, scenery_chest | item_white_cross         ; r6 chest (2,4) white cross
	defb 089h, scenery_floor | item_yellow_key         ; r6 floor (9,8) yellow key
	defb scenery_next_room              ; next room
	defb 062h, scenery_candle | item_blue_bag         ; r7 candle (2,6) blue bag
	defb 096h, scenery_candle | item_small_heart         ; r7 candle (6,9) small heart
	defb 099h, scenery_candle | item_small_heart         ; r7 candle (9,9) small heart
	defb 09ch, scenery_candle | item_small_heart         ; r7 candle (12,9) small heart
	defb scenery_next_room              ; next room
	defb 039h, scenery_candle | item_large_heart         ; r8 candle (9,3) large heart
	defb 089h, scenery_candle | item_small_heart         ; r8 candle (9,8) small heart
	defb 06dh, scenery_floor | item_white_key         ; r8 floor (13,6) white key
	defb 09ch, scenery_cover, 0dch    ; r8 reveal (12,9) vendor cross slot0
	defb 047h, scenery_chest | item_holy_water         ; r8 chest (7,4) holy water
	defb scenery_end_hub              ; end

; hub 3 = stages 10-12 (0x82b1)
scenery_list_h3:
	; stage 10
	defb 065h, scenery_candle | item_sapphire_ring         ; r0 candle (5,6) sapphire ring
	defb 07ah, scenery_candle | item_rosary         ; r0 candle (10,7) rosary
	defb 033h, scenery_floor | item_white_key         ; r0 floor (3,3) white key
	defb 08eh, scenery_chest | item_chain_whip         ; r0 chest (14,8) chain whip
	defb scenery_next_room              ; next room
	defb 038h, scenery_candle | item_black_bible         ; r1 candle (8,3) black bible
	defb 03eh, scenery_candle | item_large_heart         ; r1 candle (14,3) large heart
	defb 065h, scenery_candle | item_small_heart         ; r1 candle (5,6) small heart
	defb 032h, 0c5h         ; r1 vendor (2,3) lockpick slot1
	defb 069h, scenery_floor | item_yellow_key         ; r1 floor (9,6) yellow key
	defb scenery_next_room              ; next room
	defb 062h, scenery_candle | item_white_cross         ; r2 candle (2,6) white cross
	defb 07dh, scenery_candle | item_sapphire_ring         ; r2 candle (13,7) sapphire ring
	defb scenery_next_room              ; next room
	defb 07ah, scenery_candle | item_blue_gem         ; r3 candle (10,7) blue gem
	defb 076h, scenery_block32 | item_yellow_key         ; r3 block (6,7) yellow key
	defb 07dh, scenery_candle | item_small_heart         ; r3 candle (13,7) small heart
	defb scenery_next_room              ; next room
	defb 077h, scenery_candle | item_blue_bag         ; r4 candle (7,7) blue bag
	defb 07dh, scenery_candle | item_small_heart         ; r4 candle (13,7) small heart
	defb 084h, scenery_chest | item_white_bible         ; r4 chest (4,8) white bible
	defb scenery_next_room              ; next room
	defb 035h, scenery_candle | item_small_heart         ; r5 candle (5,3) small heart
	defb 03dh, scenery_candle | item_wings         ; r5 candle (13,3) wings
	defb 07dh, scenery_candle | item_small_heart         ; r5 candle (13,7) small heart
	defb 08eh, scenery_floor | item_yellow_key         ; r5 floor (14,8) yellow key
	defb 046h, scenery_chest | item_axe         ; r5 chest (6,4) axe
	defb 087h, scenery_chest | item_white_bag         ; r5 chest (7,8) white bag
	defb scenery_next_room              ; next room
	defb 082h, scenery_candle | item_small_heart         ; r6 candle (2,8) small heart
	defb 086h, scenery_candle | item_large_heart         ; r6 candle (6,8) large heart
	defb 08ah, scenery_candle | item_small_heart         ; r6 candle (10,8) small heart
	defb 08ch, scenery_candle | item_large_heart         ; r6 candle (12,8) large heart
	defb scenery_next_room              ; next room
	defb 092h, scenery_candle | item_small_heart         ; r7 candle (2,9) small heart
	defb 084h, scenery_candle | item_large_heart         ; r7 candle (4,8) large heart
	defb 086h, scenery_candle | item_small_heart         ; r7 candle (6,8) small heart
	defb 089h, scenery_candle | item_small_heart         ; r7 candle (9,8) small heart
	defb 09bh, scenery_candle | item_small_heart         ; r7 candle (11,9) small heart
	defb 09eh, scenery_candle | item_large_heart         ; r7 candle (14,9) large heart
	defb scenery_next_room              ; next room
	defb 094h, scenery_candle | item_small_heart         ; r8 candle (4,9) small heart
	defb 092h, 0ceh         ; r8 vendor (2,9) yellow shield slot2
	defb scenery_next_stage              ; end stream
	; stage 11
	defb 097h, scenery_candle | item_large_heart         ; r0 candle (7,9) large heart
	defb 09ah, scenery_candle | item_slime         ; r0 candle (10,9) slime
	defb 09dh, scenery_candle | item_slime         ; r0 candle (13,9) slime
	defb scenery_next_room              ; next room
	defb 048h, scenery_floor | item_yellow_key         ; r1 floor (8,4) yellow key
	defb 056h, scenery_block32 | item_white_key         ; r1 block (6,5) white key
	defb 076h, scenery_cover, scenery_chest | item_holy_water    ; r1 reveal (6,7) chest holy water
	defb 078h, scenery_cover, scenery_chest | item_white_bible    ; r1 reveal (8,7) chest white bible
	defb 07ah, scenery_cover, scenery_chest | item_lockpick    ; r1 reveal (10,7) chest lockpick
	defb 07ch, scenery_block32 | item_large_heart         ; r1 block (12,7) large heart
	defb 094h, scenery_block32         ; r1 block (4,9) none
	defb 096h, scenery_cover, 0c1h    ; r1 reveal (6,9) vendor candle slot1
	defb scenery_next_room              ; next room
	defb 072h, scenery_candle | item_large_heart         ; r2 candle (2,7) large heart
	defb 075h, scenery_candle | item_small_heart         ; r2 candle (5,7) small heart
	defb 08dh, scenery_candle | item_large_heart         ; r2 candle (13,8) large heart
	defb scenery_next_room              ; next room
	defb 056h, scenery_cover, scenery_chest | item_lockpick    ; r3 reveal (6,5) chest lockpick
	defb 078h, scenery_block32 | item_large_heart         ; r3 block (8,7) large heart
	defb 07ch, scenery_cover, scenery_chest | item_red_shield    ; r3 reveal (12,7) chest red shield
	defb 094h, scenery_block32         ; r3 block (4,9) none
	defb 096h, scenery_cover, scenery_chest | item_axe    ; r3 reveal (6,9) chest axe
	defb 098h, scenery_block32         ; r3 block (8,9) none
	defb 09ah, scenery_cover, 0d7h    ; r3 reveal (10,9) vendor potion slot3
	defb scenery_next_room              ; next room
	defb 08bh, scenery_candle | item_small_heart         ; r4 candle (11,8) small heart
	defb 08eh, scenery_candle | item_chain_whip         ; r4 candle (14,8) chain whip
	defb 098h, scenery_cover, scenery_chest | item_white_cross    ; r4 reveal (8,9) chest white cross
	defb scenery_next_room              ; next room
	defb 094h, scenery_candle | item_slime         ; r5 candle (4,9) slime
	defb 097h, scenery_candle | item_slime         ; r5 candle (7,9) slime
	defb scenery_next_stage              ; end stream
	; stage 12
	defb 093h, scenery_candle | item_small_heart         ; r0 candle (3,9) small heart
	defb scenery_next_room              ; next room
	defb 089h, scenery_candle | item_small_heart         ; r1 candle (9,8) small heart
	defb 08eh, scenery_candle | item_small_heart         ; r1 candle (14,8) small heart
	defb 074h, scenery_block32 | item_yellow_key         ; r1 block (4,7) yellow key
	defb scenery_next_room              ; next room
	defb 082h, scenery_candle         ; r2 candle (2,8) none
	defb 097h, scenery_candle | item_large_heart         ; r2 candle (7,9) large heart
	defb 09ch, scenery_candle         ; r2 candle (12,9) none
	defb 0aeh, scenery_chest | item_lockpick         ; r2 chest (14,10) lockpick
	defb scenery_next_room              ; next room
	defb 093h, scenery_candle | item_small_heart         ; r3 candle (3,9) small heart
	defb 098h, scenery_candle | item_small_heart         ; r3 candle (8,9) small heart
	defb 09bh, scenery_candle         ; r3 candle (11,9) none
	defb 09eh, scenery_candle | item_large_heart         ; r3 candle (14,9) large heart
	defb scenery_next_room              ; next room
	defb 08eh, scenery_candle | item_small_heart         ; r4 candle (14,8) small heart
	defb 086h, scenery_chest | item_white_bible         ; r4 chest (6,8) white bible
	defb 078h, 0dfh         ; r4 vendor (8,7) cross slot3
	defb scenery_next_room              ; next room
	defb 098h, scenery_candle | item_large_heart         ; r5 candle (8,9) large heart
	defb 06ch, scenery_block32 | item_white_key         ; r5 block (12,6) white key
	defb 092h, scenery_cover, scenery_chest | item_blue_gem    ; r5 reveal (2,9) chest blue gem
	defb 09ah, scenery_block32         ; r5 block (10,9) none
	defb scenery_next_room              ; next room
	defb scenery_next_room              ; next room
	defb 091h, scenery_candle | item_boots         ; r7 candle (1,9) boots
	defb 07ah, scenery_candle | item_slime         ; r7 candle (10,7) slime
	defb 07eh, scenery_candle         ; r7 candle (14,7) none
	defb 08ch, scenery_chest | item_map         ; r7 chest (12,8) map
	defb scenery_next_room              ; next room
	defb 072h, scenery_candle | item_small_heart         ; r8 candle (2,7) small heart
	defb 079h, scenery_candle | item_slime         ; r8 candle (9,7) slime
	defb 09ch, scenery_candle | item_large_heart         ; r8 candle (12,9) large heart
	defb 0aeh, scenery_floor | item_yellow_key         ; r8 floor (14,10) yellow key
	defb scenery_next_room              ; next room
	defb 072h, scenery_candle | item_large_heart         ; r9 candle (2,7) large heart
	defb 077h, scenery_candle | item_small_heart         ; r9 candle (7,7) small heart
	defb 07ah, scenery_candle | item_slime         ; r9 candle (10,7) slime
	defb 074h, scenery_block32 | item_yellow_key         ; r9 block (4,7) yellow key
	defb scenery_next_room              ; next room
	defb 091h, scenery_candle | item_small_heart         ; r10 candle (1,9) small heart
	defb 096h, scenery_candle | item_blue_gem         ; r10 candle (6,9) blue gem
	defb 08ch, scenery_candle | item_large_heart         ; r10 candle (12,8) large heart
	defb scenery_next_room              ; next room
	defb 097h, scenery_candle         ; r11 candle (7,9) none
	defb 084h, scenery_chest | item_white_cross         ; r11 chest (4,8) white cross
	defb scenery_end_hub              ; end

; hub 4 = stages 13-15 (0x8398)
scenery_list_h4:
	; stage 13
	defb 093h, scenery_candle | item_large_heart         ; r0 candle (3,9) large heart
	defb 098h, scenery_candle | item_small_heart         ; r0 candle (8,9) small heart
	defb 09eh, scenery_candle | item_large_heart         ; r0 candle (14,9) large heart
	defb 032h, scenery_cover, 0e3h    ; r0 reveal (2,3) vendor knife slot3
	defb scenery_next_room              ; next room
	defb 094h, scenery_candle | item_small_heart         ; r1 candle (4,9) small heart
	defb 08ch, scenery_candle | item_small_heart         ; r1 candle (12,8) small heart
	defb 0aeh, scenery_floor | item_yellow_key         ; r1 floor (14,10) yellow key
	defb scenery_next_room              ; next room
	defb 087h, scenery_candle | item_large_heart         ; r2 candle (7,8) large heart
	defb 08ch, scenery_candle | item_small_heart         ; r2 candle (12,8) small heart
	defb 049h, scenery_floor | item_yellow_key         ; r2 floor (9,4) yellow key
	defb 0adh, scenery_floor | item_yellow_key         ; r2 floor (13,10) yellow key
	defb scenery_next_room              ; next room
	defb 031h, scenery_candle | item_small_heart         ; r3 candle (1,3) small heart
	defb 036h, scenery_candle | item_large_heart         ; r3 candle (6,3) large heart
	defb 03bh, scenery_candle | item_black_bible         ; r3 candle (11,3) black bible
	defb 049h, scenery_floor | item_yellow_key         ; r3 floor (9,4) yellow key
	defb scenery_next_room              ; next room
	defb 035h, scenery_candle | item_large_heart         ; r4 candle (5,3) large heart
	defb 03ah, scenery_candle | item_small_orb         ; r4 candle (10,3) small orb
	defb 098h, scenery_candle         ; r4 candle (8,9) none
	defb 094h, scenery_cover, scenery_chest | item_map    ; r4 reveal (4,9) chest map
	defb 092h, 0c6h         ; r4 vendor (2,9) lockpick slot2
	defb scenery_next_room              ; next room
	defb 034h, scenery_candle | item_sapphire_ring         ; r5 candle (4,3) sapphire ring
	defb 039h, scenery_candle | item_large_heart         ; r5 candle (9,3) large heart
	defb 03eh, scenery_candle | item_small_heart         ; r5 candle (14,3) small heart
	defb scenery_next_room              ; next room
	defb 049h, scenery_floor | item_yellow_key         ; r6 floor (9,4) yellow key
	defb 03ch, scenery_cover, 0d1h    ; r6 reveal (12,3) vendor hourglass slot1
	defb 07ah, scenery_block32 | item_white_key         ; r6 block (10,7) white key
	defb scenery_next_room              ; next room
	defb 083h, scenery_candle | item_small_heart         ; r7 candle (3,8) small heart
	defb 089h, scenery_candle | item_large_heart         ; r7 candle (9,8) large heart
	defb 08ch, scenery_candle | item_chain_whip         ; r7 candle (12,8) chain whip
	defb 04bh, scenery_floor | item_yellow_key         ; r7 floor (11,4) yellow key
	defb 0a2h, scenery_floor | item_yellow_key         ; r7 floor (2,10) yellow key
	defb scenery_next_room              ; next room
	defb 028h, scenery_candle | item_small_heart         ; r8 candle (8,2) small heart
	defb 02bh, scenery_candle | item_small_heart         ; r8 candle (11,2) small heart
	defb 02eh, scenery_candle         ; r8 candle (14,2) none
	defb 032h, scenery_cover, scenery_chest | item_white_bible    ; r8 reveal (2,3) chest white bible
	defb 052h, scenery_cover, scenery_chest | item_white_bag    ; r8 reveal (2,5) chest white bag
	defb scenery_next_room              ; next room
	defb 05bh, scenery_candle | item_large_heart         ; r9 candle (11,5) large heart
	defb 05eh, scenery_candle         ; r9 candle (14,5) none
	defb scenery_next_room              ; next room
	defb 059h, scenery_candle | item_small_heart         ; r10 candle (9,5) small heart
	defb 05ch, scenery_candle | item_small_heart         ; r10 candle (12,5) small heart
	defb 09ch, scenery_cover, 0d8h    ; r10 reveal (12,9) vendor holy water slot0
	defb scenery_next_room              ; next room
	defb 032h, scenery_cover, scenery_chest | item_axe    ; r11 reveal (2,3) chest axe
	defb scenery_next_stage              ; end stream
	; stage 14
	defb 023h, scenery_candle | item_large_heart         ; r0 candle (3,2) large heart
	defb 083h, scenery_candle | item_chain_whip         ; r0 candle (3,8) chain whip
	defb 06dh, scenery_floor | item_yellow_key         ; r0 floor (13,6) yellow key
	defb scenery_next_room              ; next room
	defb 094h, scenery_candle | item_boots         ; r1 candle (4,9) boots
	defb 098h, scenery_candle | item_large_heart         ; r1 candle (8,9) large heart
	defb 09ch, scenery_candle | item_slime         ; r1 candle (12,9) slime
	defb 06dh, scenery_chest | item_axe         ; r1 chest (13,6) axe
	defb 064h, scenery_floor | item_yellow_key         ; r1 floor (4,6) yellow key
	defb scenery_next_room              ; next room
	defb 064h, scenery_candle | item_small_orb         ; r2 candle (4,6) small orb
	defb 08ch, scenery_candle | item_small_heart         ; r2 candle (12,8) small heart
	defb 04bh, scenery_chest | item_sapphire_ring         ; r2 chest (11,4) sapphire ring
	defb 06eh, scenery_chest | item_red_shield         ; r2 chest (14,6) red shield
	defb 0a6h, scenery_floor | item_yellow_key         ; r2 floor (6,10) yellow key
	defb scenery_next_room              ; next room
	defb 024h, scenery_candle | item_white_cross         ; r3 candle (4,2) white cross
	defb 029h, scenery_candle         ; r3 candle (9,2) none
	defb scenery_next_room              ; next room
	defb 024h, scenery_candle | item_slime         ; r4 candle (4,2) slime
	defb 02dh, scenery_candle | item_small_heart         ; r4 candle (13,2) small heart
	defb 078h, scenery_candle | item_small_heart         ; r4 candle (8,7) small heart
	defb 0a5h, scenery_floor | item_yellow_key         ; r4 floor (5,10) yellow key
	defb 0ach, scenery_floor | item_yellow_key         ; r4 floor (12,10) yellow key
	defb scenery_next_room              ; next room
	defb 044h, scenery_block32         ; r5 block (4,4) none
	defb 064h, scenery_block32 | item_white_key         ; r5 block (4,6) white key
	defb 04bh, scenery_chest | item_map         ; r5 chest (11,4) map
	defb scenery_next_room              ; next room
	defb 043h, scenery_candle | item_small_heart         ; r6 candle (3,4) small heart
	defb 049h, scenery_candle | item_white_cross         ; r6 candle (9,4) white cross
	defb 04ch, scenery_candle | item_small_heart         ; r6 candle (12,4) small heart
	defb 0a3h, scenery_chest | item_small_orb         ; r6 chest (3,10) small orb
	defb 096h, 0c1h         ; r6 vendor (6,9) candle slot1
	defb scenery_next_room              ; next room
	defb 037h, scenery_candle         ; r7 candle (7,3) none
	defb 03ah, scenery_candle | item_small_heart         ; r7 candle (10,3) small heart
	defb 08ah, scenery_candle | item_blue_bag         ; r7 candle (10,8) blue bag
	defb 093h, scenery_candle | item_small_heart         ; r7 candle (3,9) small heart
	defb 095h, scenery_candle | item_small_heart         ; r7 candle (5,9) small heart
	defb scenery_next_stage              ; end stream
	; stage 15
	defb 035h, scenery_candle | item_small_heart         ; r0 candle (5,3) small heart
	defb 094h, scenery_candle | item_black_bible         ; r0 candle (4,9) black bible
	defb 04bh, scenery_chest | item_map         ; r0 chest (11,4) map
	defb 03ch, scenery_cover, 0d6h    ; r0 reveal (12,3) vendor potion slot2
	defb scenery_next_room              ; next room
	defb 096h, scenery_candle | item_large_heart         ; r1 candle (6,9) large heart
	defb 09ah, scenery_candle | item_black_bible         ; r1 candle (10,9) black bible
	defb 08dh, scenery_candle | item_large_heart         ; r1 candle (13,8) large heart
	defb 03bh, scenery_candle | item_large_heart         ; r1 candle (11,3) large heart
	defb 0a4h, scenery_floor | item_yellow_key         ; r1 floor (4,10) yellow key
	defb scenery_next_room              ; next room
	defb 081h, scenery_candle | item_black_bible         ; r2 candle (1,8) black bible
	defb 085h, scenery_candle | item_small_heart         ; r2 candle (5,8) small heart
	defb 089h, scenery_candle | item_small_heart         ; r2 candle (9,8) small heart
	defb 08dh, scenery_candle | item_sapphire_ring         ; r2 candle (13,8) sapphire ring
	defb 04bh, scenery_chest | item_white_bible         ; r2 chest (11,4) white bible
	defb 03ch, scenery_cover, 0dch    ; r2 reveal (12,3) vendor cross slot0
	defb scenery_next_room              ; next room
	defb 089h, scenery_candle | item_sapphire_ring         ; r3 candle (9,8) sapphire ring
	defb 08dh, scenery_candle | item_large_heart         ; r3 candle (13,8) large heart
	defb 042h, scenery_floor | item_white_key         ; r3 floor (2,4) white key
	defb scenery_next_room              ; next room
	defb 04bh, scenery_floor | item_yellow_key         ; r4 floor (11,4) yellow key
	defb scenery_next_room              ; next room
	defb 042h, scenery_candle | item_large_heart         ; r5 candle (2,4) large heart
	defb 04ah, scenery_candle | item_large_heart         ; r5 candle (10,4) large heart
	defb 062h, scenery_chest | item_hourglass         ; r5 chest (2,6) hourglass
	defb 06bh, scenery_chest | item_red_shield         ; r5 chest (11,6) red shield
	defb 0ach, scenery_chest | item_map         ; r5 chest (12,10) map
	defb scenery_next_room              ; next room
	defb 087h, scenery_candle | item_small_heart         ; r6 candle (7,8) small heart
	defb 08ch, scenery_candle | item_large_heart         ; r6 candle (12,8) large heart
	defb 0a9h, scenery_floor | item_yellow_key         ; r6 floor (9,10) yellow key
	defb 0adh, scenery_chest | item_lockpick         ; r6 chest (13,10) lockpick
	defb scenery_next_room              ; next room
	defb scenery_next_room              ; next room
	defb 0a4h, scenery_floor | item_yellow_key         ; r8 floor (4,10) yellow key
	defb scenery_next_room              ; next room
	defb 062h, scenery_candle | item_large_heart         ; r9 candle (2,6) large heart
	defb 076h, scenery_candle | item_small_orb         ; r9 candle (6,7) small orb
	defb 079h, scenery_candle | item_large_heart         ; r9 candle (9,7) large heart
	defb 06dh, scenery_candle | item_large_heart         ; r9 candle (13,6) large heart
	defb scenery_end_hub              ; end

; hub 5 = stages 16-18 (0x8497)
scenery_list_h5:
	; stage 16
	defb 068h, scenery_candle | item_slime         ; r0 candle (8,6) slime
	defb 096h, scenery_candle | item_small_heart         ; r0 candle (6,9) small heart
	defb 09bh, scenery_candle | item_slime         ; r0 candle (11,9) slime
	defb scenery_next_room              ; next room
	defb 06ch, scenery_floor | item_yellow_key         ; r1 floor (12,6) yellow key
	defb scenery_next_room              ; next room
	defb 062h, scenery_chest | item_sapphire_ring         ; r2 chest (2,6) sapphire ring
	defb scenery_next_room              ; next room
	defb scenery_next_room              ; next room
	defb scenery_next_room              ; next room
	defb 056h, scenery_candle | item_large_heart         ; r5 candle (6,5) large heart
	defb 069h, scenery_floor | item_white_key         ; r5 floor (9,6) white key
	defb scenery_next_room              ; next room
	defb 021h, scenery_candle | item_blue_gem         ; r6 candle (1,2) blue gem
	defb 036h, scenery_candle | item_large_heart         ; r6 candle (6,3) large heart
	defb 094h, scenery_candle | item_small_heart         ; r6 candle (4,9) small heart
	defb 098h, scenery_candle | item_large_heart         ; r6 candle (8,9) large heart
	defb 0a6h, scenery_chest | item_lockpick         ; r6 chest (6,10) lockpick
	defb scenery_next_room              ; next room
	defb scenery_next_room              ; next room
	defb 0ach, scenery_floor | item_white_key         ; r8 floor (12,10) white key
	defb scenery_next_room              ; next room
	defb 057h, scenery_candle | item_wings         ; r9 candle (7,5) wings
	defb 059h, scenery_candle | item_large_heart         ; r9 candle (9,5) large heart
	defb 066h, scenery_chest | item_small_orb         ; r9 chest (6,6) small orb
	defb 068h, scenery_chest | item_hourglass         ; r9 chest (8,6) hourglass
	defb 06dh, scenery_floor | item_white_key         ; r9 floor (13,6) white key
	defb scenery_next_stage              ; end stream
	; stage 17
	defb 025h, scenery_candle | item_white_bible         ; r0 candle (5,2) white bible
	defb 058h, scenery_candle | item_small_heart         ; r0 candle (8,5) small heart
	defb 091h, scenery_candle | item_large_heart         ; r0 candle (1,9) large heart
	defb 098h, scenery_block32 | item_white_key         ; r0 block (8,9) white key
	defb scenery_next_room              ; next room
	defb 032h, scenery_candle | item_small_heart         ; r1 candle (2,3) small heart
	defb 03dh, scenery_candle | item_small_heart         ; r1 candle (13,3) small heart
	defb 058h, scenery_block32         ; r1 block (8,5) none
	defb 078h, scenery_block32         ; r1 block (8,7) none
	defb 098h, scenery_cover, 0dbh    ; r1 reveal (8,9) vendor holy water slot3
	defb 0a7h, scenery_chest | item_red_shield         ; r1 chest (7,10) red shield
	defb 061h, scenery_floor | item_yellow_key         ; r1 floor (1,6) yellow key
	defb scenery_next_room              ; next room
	defb 04dh, scenery_candle | item_large_heart         ; r2 candle (13,4) large heart
	defb 09dh, scenery_candle | item_small_heart         ; r2 candle (13,9) small heart
	defb 052h, scenery_chest | item_cross         ; r2 chest (2,5) cross
	defb 094h, scenery_block32         ; r2 block (4,9) none
	defb 096h, scenery_cover, scenery_chest | item_white_bible    ; r2 reveal (6,9) chest white bible
	defb 0a8h, scenery_chest | item_map         ; r2 chest (8,10) map
	defb scenery_next_room              ; next room
	defb 047h, scenery_candle | item_black_bible         ; r3 candle (7,4) black bible
	defb 04ch, scenery_candle | item_large_heart         ; r3 candle (12,4) large heart
	defb 094h, scenery_candle | item_large_heart         ; r3 candle (4,9) large heart
	defb 09ch, scenery_candle | item_slime         ; r3 candle (12,9) slime
	defb 06dh, scenery_floor | item_yellow_key         ; r3 floor (13,6) yellow key
	defb scenery_next_room              ; next room
	defb 031h, scenery_candle | item_small_heart         ; r4 candle (1,3) small heart
	defb 035h, scenery_candle | item_rosary         ; r4 candle (5,3) rosary
	defb 03ch, scenery_candle | item_small_heart         ; r4 candle (12,3) small heart
	defb 084h, scenery_candle | item_large_heart         ; r4 candle (4,8) large heart
	defb 08ch, scenery_candle | item_large_heart         ; r4 candle (12,8) large heart
	defb 0aah, scenery_chest | item_hourglass         ; r4 chest (10,10) hourglass
	defb scenery_next_room              ; next room
	defb 038h, scenery_candle | item_slime         ; r5 candle (8,3) slime
	defb 03bh, scenery_candle | item_small_heart         ; r5 candle (11,3) small heart
	defb 03eh, scenery_candle | item_slime         ; r5 candle (14,3) slime
	defb 08eh, scenery_candle | item_large_heart         ; r5 candle (14,8) large heart
	defb 042h, scenery_chest | item_white_bag         ; r5 chest (2,4) white bag
	defb 0ach, scenery_floor | item_yellow_key         ; r5 floor (12,10) yellow key
	defb scenery_next_room              ; next room
	defb 03ah, scenery_candle | item_large_heart         ; r6 candle (10,3) large heart
	defb 084h, scenery_candle | item_small_heart         ; r6 candle (4,8) small heart
	defb 04dh, scenery_chest | item_boots         ; r6 chest (13,4) boots
	defb 068h, scenery_chest | item_sapphire_ring         ; r6 chest (8,6) sapphire ring
	defb 0abh, scenery_chest | item_yellow_shield         ; r6 chest (11,10) yellow shield
	defb 09ch, scenery_cover, 0e0h    ; r6 reveal (12,9) vendor knife slot0
	defb 090h, scenery_block32         ; r6 block (0,9) none
	defb scenery_next_room              ; next room
	defb 08dh, scenery_chest | item_cross         ; r7 chest (13,8) cross
	defb 0aeh, scenery_chest | item_large_heart         ; r7 chest (14,10) large heart
	defb 04eh, scenery_floor | item_yellow_key         ; r7 floor (14,4) yellow key
	defb scenery_next_room              ; next room
	defb 038h, scenery_candle         ; r8 candle (8,3) none
	defb 078h, scenery_candle         ; r8 candle (8,7) none
	defb 04eh, scenery_floor | item_yellow_key         ; r8 floor (14,4) yellow key
	defb 032h, 0cah         ; r8 vendor (2,3) red shield slot2
	defb scenery_next_room              ; next room
	defb 044h, scenery_floor | item_yellow_key         ; r9 floor (4,4) yellow key
	defb 032h, 0d4h         ; r9 vendor (2,3) potion slot0
	defb 058h, scenery_block32 | item_slime         ; r9 block (8,5) slime
	defb 05ah, scenery_cover, scenery_chest | item_white_cross    ; r9 reveal (10,5) chest white cross
	defb 076h, scenery_block32 | item_large_heart         ; r9 block (6,7) large heart
	defb 078h, scenery_block32 | item_large_heart         ; r9 block (8,7) large heart
	defb 0a9h, scenery_chest | item_lockpick         ; r9 chest (9,10) lockpick
	defb scenery_next_room              ; next room
	defb 04dh, scenery_floor | item_white_key         ; r10 floor (13,4) white key
	defb 0adh, scenery_floor | item_yellow_key         ; r10 floor (13,10) yellow key
	defb scenery_next_room              ; next room
	defb 043h, scenery_candle | item_blue_bag         ; r11 candle (3,4) blue bag
	defb scenery_next_stage              ; end stream
	; stage 18
	defb scenery_next_room              ; next room
	defb 036h, scenery_candle | item_large_heart         ; r1 candle (6,3) large heart
	defb 03eh, scenery_candle | item_large_heart         ; r1 candle (14,3) large heart
	defb 084h, scenery_floor | item_yellow_key         ; r1 floor (4,8) yellow key
	defb 09ch, 0e3h         ; r1 vendor (12,9) knife slot3
	defb scenery_next_room              ; next room
	defb 075h, scenery_candle | item_large_heart         ; r2 candle (5,7) large heart
	defb 07dh, scenery_candle | item_large_heart         ; r2 candle (13,7) large heart
	defb 081h, scenery_chest | item_lockpick         ; r2 chest (1,8) lockpick
	defb 044h, scenery_floor | item_yellow_key         ; r2 floor (4,4) yellow key
	defb scenery_next_room              ; next room
	defb 046h, scenery_candle | item_large_heart         ; r3 candle (6,4) large heart
	defb 04eh, scenery_candle | item_slime         ; r3 candle (14,4) slime
	defb 091h, scenery_candle         ; r3 candle (1,9) none
	defb 096h, scenery_candle | item_large_heart         ; r3 candle (6,9) large heart
	defb 09eh, scenery_candle | item_small_heart         ; r3 candle (14,9) small heart
	defb 061h, scenery_chest | item_blue_gem         ; r3 chest (1,6) blue gem
	defb scenery_next_room              ; next room
	defb 022h, scenery_candle | item_slime         ; r4 candle (2,2) slime
	defb 069h, scenery_candle | item_slime         ; r4 candle (9,6) slime
	defb 094h, scenery_candle | item_slime         ; r4 candle (4,9) slime
	defb 09dh, scenery_candle | item_small_heart         ; r4 candle (13,9) small heart
	defb 041h, scenery_chest | item_boots         ; r4 chest (1,4) boots
	defb 066h, scenery_floor | item_yellow_key         ; r4 floor (6,6) yellow key
	defb scenery_next_room              ; next room
	defb 03ch, scenery_candle | item_chain_whip         ; r5 candle (12,3) chain whip
	defb 048h, scenery_floor | item_yellow_key         ; r5 floor (8,4) yellow key
	defb 0b1h, scenery_floor | item_yellow_key         ; r5 floor (1,11) yellow key
	defb 042h, scenery_chest | item_small_orb         ; r5 chest (2,4) small orb
	defb 0a7h, scenery_chest | item_sapphire_ring         ; r5 chest (7,10) sapphire ring
	defb scenery_next_room              ; next room
	defb 03ah, scenery_candle         ; r6 candle (10,3) none
	defb 046h, scenery_candle | item_small_heart         ; r6 candle (6,4) small heart
	defb 0bbh, scenery_candle | item_small_heart         ; r6 candle (11,11) small heart
	defb 031h, scenery_floor | item_white_key         ; r6 floor (1,3) white key
	defb scenery_next_room              ; next room
	defb 034h, scenery_candle | item_small_heart         ; r7 candle (4,3) small heart
	defb 049h, scenery_candle | item_large_heart         ; r7 candle (9,4) large heart
	defb 07dh, scenery_candle | item_small_heart         ; r7 candle (13,7) small heart
	defb 091h, scenery_candle | item_large_heart         ; r7 candle (1,9) large heart
	defb 0a3h, scenery_chest | item_white_bag         ; r7 chest (3,10) white bag
	defb 066h, scenery_floor | item_yellow_key         ; r7 floor (6,6) yellow key
	defb scenery_next_room              ; next room
	defb 035h, scenery_candle         ; r8 candle (5,3) none
	defb 038h, scenery_candle | item_small_heart         ; r8 candle (8,3) small heart
	defb 03bh, scenery_candle | item_small_heart         ; r8 candle (11,3) small heart
	defb 094h, scenery_candle         ; r8 candle (4,9) none
	defb 098h, scenery_candle | item_large_heart         ; r8 candle (8,9) large heart
	defb 09ch, scenery_candle | item_small_heart         ; r8 candle (12,9) small heart
	defb 032h, 0d4h         ; r8 vendor (2,3) potion slot0
	defb scenery_end_hub              ; end


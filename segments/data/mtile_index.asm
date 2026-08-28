; Stage/room index for metatile streams (seg11 0x6000).
; mtile_defbase follows the packed streams at 0x7EBB (data/mtile_defbase.asm).

; mtile_rowbase (seg11 0x6000): byte[stage] = first room index for that stage.
; rooms-in-stage = rowbase[n+1]-rowbase[n] for stages 0..17.  Stage 18's next
; byte is the low byte of mtile_roomptr (delta -23); its count is 10 from
; minimap_room_count.  19 bytes covering stages 0..18.
mtile_rowbase:
	defb 000h,003h,00bh,011h,017h,01dh,023h,029h,032h,03ah,043h,04ch,052h,05eh,06ah,072h,07ch,086h,092h

; mtile_roomptr (seg11 0x6013): word[index] -> 48-byte metatile stream.
; 156 rooms (stages 0..17 = 146, stage 18 = 10), packed immediately after
; mtile_stream_intro.  room_map_build: index = rowbase[D000]+D001.
mtile_roomptr:
	defw 0617bh,061abh,061dbh,0620bh,0623bh,0626bh,0629bh,062cbh
	defw 062fbh,0632bh,0635bh,0638bh,063bbh,063ebh,0641bh,0644bh
	defw 0647bh,064abh,064dbh,0650bh,0653bh,0656bh,0659bh,065cbh
	defw 065fbh,0662bh,0665bh,0668bh,066bbh,066ebh,0671bh,0674bh
	defw 0677bh,067abh,067dbh,0680bh,0683bh,0686bh,0689bh,068cbh
	defw 068fbh,0692bh,0695bh,0698bh,069bbh,069ebh,06a1bh,06a4bh
	defw 06a7bh,06aabh,06adbh,06b0bh,06b3bh,06b6bh,06b9bh,06bcbh
	defw 06bfbh,06c2bh,06c5bh,06c8bh,06cbbh,06cebh,06d1bh,06d4bh
	defw 06d7bh,06dabh,06ddbh,06e0bh,06e3bh,06e6bh,06e9bh,06ecbh
	defw 06efbh,06f2bh,06f5bh,06f8bh,06fbbh,06febh,0701bh,0704bh
	defw 0707bh,070abh,070dbh,0710bh,0713bh,0716bh,0719bh,071cbh
	defw 071fbh,0722bh,0725bh,0728bh,072bbh,072ebh,0731bh,0734bh
	defw 0737bh,073abh,073dbh,0740bh,0743bh,0746bh,0749bh,074cbh
	defw 074fbh,0752bh,0755bh,0758bh,075bbh,075ebh,0761bh,0764bh
	defw 0767bh,076abh,076dbh,0770bh,0773bh,0776bh,0779bh,077cbh
	defw 077fbh,0782bh,0785bh,0788bh,078bbh,078ebh,0791bh,0794bh
	defw 0797bh,079abh,079dbh,07a0bh,07a3bh,07a6bh,07a9bh,07acbh
	defw 07afbh,07b2bh,07b5bh,07b8bh,07bbbh,07bebh,07c1bh,07c4bh
	defw 07c7bh,07cabh,07cdbh,07d0bh,07d3bh,07d6bh,07d9bh,07dcbh
	defw 07dfbh,07e2bh,07e5bh,07e8bh


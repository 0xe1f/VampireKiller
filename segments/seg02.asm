; ===========================================================================
;  SEGMENT 2 - banked code, paged at 0x8000-0x9FFF (page 2a).
;  Raw disassembly imported for annotation; reverse-engineering IN PROGRESS.
;  (Origin is set by PHASE 0x8000 in VampireKiller.asm; regenerate the raw
;   disassembly with  tools/regen-seg.sh 2 0x8000 .)
;
;  MSX/MSX2 BIOS entry-point names and shared seg0/seg1 routine labels are
;  defined elsewhere (bios.inc, seg00.asm, seg01.asm) and referenced here.
; ===========================================================================

	inc l
	inc l
	inc l
	inc (hl)
	xor a
	ld (0c433h),a
	inc l
	ld a,(hl)
	cp 01bh
l800ch:
	jr nz,l801ch
	ld a,0e0h
	ld (0d618h),a
	ld (0d61ch),a
	ld (0d620h),a
	ld (0d624h),a
l801ch:
	pop hl
	pop bc
	ld a,010h
	add a,l
	ld l,a
	djnz $-47
	ret
projectile_hit_actors:         ; (0x8025) C450/C460 vs C800 if +0E bit0
	ld a,(0c450h)
	ld b,a
	ld a,(0c460h)
	or b
	ret z
	ld ix,0c800h
	ld b,007h
l8034h:
	ld a,(ix+000h)
	and a
	jr z,l8047h
	ld a,(ix+00eh)
	rra
	jr nc,l8047h
	push bc
	call actor_vs_proj
	pop bc
	jr c,l8053h
l8047h:
	ld de,00080h
	add ix,de
	djnz l8034h
	ret
l804fh:
	defb 001h,004h,002h,002h  ; fodder dmg: knife/axe/cross/holy (iy+1)-2
l8053h:
	ld a,00ch
	call play_sound
	ld a,(ix+000h)
	sub 011h
	cp 007h
	jr c,l808fh
l8061h:
	ld a,(iy+001h)
	sub 002h
	ld hl,l804fh
	call ADD_HL_A
	ld b,(hl)
	ld a,(ix+00dh)
l8070h:
	sub b
	ld (ix+00dh),a
	jr z,l8079h
	jp p,l807fh
l8079h:
	call award_kill_score
	call sub_9a45h
l807fh:
	ld a,(iy+001h)
	cp 002h
	push iy
	pop hl
	jp z,projectile_clear_hl  ; knife (type 2): despawn on hit
	res 0,(ix+00eh)        ; axe/cross/holy: keep projectile, drop hittable
	ret
l808fh:
	ld a,(ix+000h)
	cp 012h
	jr nz,l809ch
	ld a,(0ce00h)
	and a
	jr z,l8061h
l809ch:
	call weapon_hit_damage
	ld a,(0c418h)
	and a
	jr z,l80a8h
	rla
	jr nc,l807fh
l80a8h:
	call 07e1eh
	jr l807fh
	ld ix,0c470h
	ld b,008h
l80b3h:
	ld a,(ix+000h)
	and a
	jr z,l80dbh
	push bc
	call sub_8467h
	pop bc
	jr nc,l80dbh
	inc (ix+003h)
	ld a,(ix+004h)
	ld (0c433h),a
	ld a,(iy+001h)
	dec a
	dec a
	jr nz,l80d6h
	push iy
	pop hl
	call z,projectile_clear_hl
l80d6h:
	ld a,00ch
	jp play_sound
l80dbh:
	ld de,CHRGTR
	add ix,de
	djnz l80b3h
	ret
	ld hl,0c5b5h
	call sub_80ech
	ld hl,0c5c5h
sub_80ech:
	ld a,(hl)
	rla
	ret nc
	ld a,(0c416h)
	cp 002h
	jr nc,l8104h
	ld a,(0c422h)
	cp 003h
	jr nz,l8104h
	push hl
	call obj_vs_whip_lo
	pop hl
	jr c,l8119h
l8104h:
	push hl
	call obj_vs_proj_lo
	pop hl
	ret nc
	ld a,(iy+001h)
	cp 002h
	jr nz,l8119h
	push hl
	push iy
	pop hl
	call projectile_clear_hl
	pop hl
l8119h:
	inc l
	inc l
	inc l
	inc (hl)
	ld a,00ch
	jp play_sound
	ld hl,0c500h
	ld b,008h
l8127h:
	push bc
	push hl
	ld a,(hl)
	rla
	jr nc,l816ah
	push hl
	ld a,004h
	add a,l
	ld l,a
	ld a,(hl)
	pop hl
	cp 00ah
	jr z,l813ch
	cp 00bh
	jr nz,l816ah
l813ch:
	ld a,(0c416h)
	cp 002h
	jr nc,l8151h
	ld a,(0c422h)
	cp 003h
	jr nz,l8151h
	push hl
	call obj_vs_whip_hi
	pop hl
	jr c,l8160h
l8151h:
	push hl
	call obj_vs_proj_hi
	pop hl
	jr nc,l816ah
	push hl
	push iy
	pop hl
	call projectile_clear_hl
	pop hl
l8160h:
	inc l
	inc l
	inc l
	ld (hl),002h
	ld a,00ch
	call play_sound
l816ah:
	pop hl
	pop bc
	ld a,010h
	add a,l
	ld l,a
	djnz l8127h
	ret
; --- hurt_simon_contact (seg2 0x8173) - Simon TAKES contact damage from actor IX -
; Base damage B = the ODD byte of this actor type's l81d5h entry (the even byte is
; the kill score - see l81d5h below).  Then:
;   * Red shield (0xC701 bit 4, bonus id 3): if Simon is facing the hit, take B
;     as-is (not doubled) and spend a charge (0xC441--; at 0, res bit4 +
;     hud_bonus_refresh drops the HUD).  A backstab still takes the doubled hit.
;   * Otherwise (no red shield / not facing): B is DOUBLED, so unshielded
;     contact = 2 * (l81d5h odd byte).  Runtime-confirmed: zombie(t01) odd 1 -> 2,
;     dog(t05) odd 3 -> 6 (0x1E->0x18).  Then jp damage_health (0xC415 -= B).
hurt_simon_contact:
	ld a,(ix+000h)
	dec a
	add a,a
	ld hl,l81d5h
	call ADD_HL_A
	inc hl                 ; -> odd byte = base contact damage for this type
	ld b,(hl)
	ld a,(0c701h)
	bit 4,a                ; red shield (id 3)?
	jr z,l819ah            ; no shield -> full (doubled) damage
	ld a,(0c427h)
	sub (ix+005h)
	ld a,(0c42ch)
	jr nc,l8197h
	and a
	jr z,l819fh
	jr l819ah
l8197h:
	and a
	jr nz,l819fh
l819ah:
	ld a,b                 ; unshielded: double the base damage
	add a,a
	ld b,a
	jr l81afh
l819fh:
	ld hl,0c441h           ; shielded hit: spend a shield charge
	dec (hl)
	jr nz,l81afh
	ld hl,0c701h
	res 4,(hl)             ; charges gone -> drop the red shield
	push bc
	call hud_bonus_refresh
	pop bc
l81afh:
	jp damage_health       ; 0xC415 -= B
; award_kill_score (seg2 0x81B2): give points for killing the actor in IX.
; Looks up the per-type hundreds value D from table l81d5h[(type-1)] (E=0 low pair),
; then picks the high pair C by type (0x11 -> 3, 0x17 -> 5, else 0) and calls
; add_score with C:D:E.
award_kill_score:
	ld a,(ix+000h)
	ld b,a
	dec a
	add a,a
	ld hl,l81d5h
	call ADD_HL_A
	ld e,000h
	ld d,(hl)               ; D = hundreds pair for this enemy type
	ld a,b
	cp 011h
	ld c,003h
	jp z,add_score
	ld c,005h
	cp 017h
	jp z,add_score
	ld c,000h
	jp add_score
; l81d5h - per-actor-type table, 2 bytes/entry, indexed by (type - 1):
;   even byte = kill SCORE / 100 in BCD (read by award_kill_score above)
;   odd  byte = base CONTACT damage to Simon (read by hurt_simon_contact; the
;               real damage is 2x this when unshielded)
;         type: 01   02   03   04   05   06   07   08   09   0a   0b   0c   0d
;   score/100 :  1    2    2    1    1    2    2    2    2    3    2    1    2
;   contact dmg:  x2 of odd byte -> zombie(t01)=2, dog(t05)=6 (confirmed in play)
;   high types 0x0e=1000pts, 0x11 +30000, 0x12-14 2000, 0x17 +50000 [bosses].
; Confirmed: t01 zombie 100/2; t02/t03 merman 200/4; t04 hanging bat 100/2;
; t05 dog 100/6; t07 flying skull 200/2; t08 ghost head 200/4; t0F roc 400/4.
; Hearts/keys are pickups (collect_bonus), not kills, so they award 0 here.
l81d5h:
	defb 001h,001h, 002h,002h, 002h,002h, 001h,001h  ; t01-04
	defb 001h,003h, 002h,002h, 002h,001h, 002h,002h  ; t05-08
	defb 002h,001h, 003h,001h, 002h,001h, 001h,001h  ; t09-0c
	defb 002h,001h, 010h,003h, 004h,002h, 003h,003h  ; t0d-10
	defb 000h,003h, 020h,002h, 020h,002h, 020h,002h  ; t11-14
	defb 030h,003h, 070h,003h, 000h,000h, 002h,001h  ; t15-18
	defb 001h,002h, 001h,002h, 001h,002h, 001h,002h  ; t19-1c blob
	defb 000h,000h, 000h,000h, 001h,001h, 000h,000h  ; t1d-20
	defb 002h,001h, 000h,000h, 002h,001h, 000h,000h  ; t21-24
	defb 000h,000h, 000h,000h, 000h,000h, 000h,000h
	defb 000h,000h, 000h,000h, 000h,000h, 001h,001h
	defb 000h,000h, 000h,000h
add_score_100:                 ; (0x8231) +100 for destroying a shot
	ld de,00100h
	jp add_score_c0
pickup_vs_simon:               ; (0x8237) C500 slot HL vs Simon (Y+10, X+8, 10x8)
	inc l
	ld a,(hl)
	add a,010h
	ld e,a
	inc l
	ld a,(hl)
	add a,008h
	ld d,a
	ld hl,01008h
	jp overlap_simon
proj_overlap_simon:            ; (0x8247) projectile DE vs Simon box (catch)
	ld d,(ix+005h)
	ld e,(ix+004h)
	ld hl,01008h
	jp overlap_simon
; Hit-class overlap: look up a box size by actor/shot type, then test vs
; Simon / whip / projectile / yellow shield.  Shots use 3 classes (0..2);
; C800 uses 7 (table 1..7, then dec a).  Carry = overlap.
shot_vs_simon:                 ; (0x8253) shot vs Simon (hurt)
	call hit_class_shot
	call DISPATCH_A
	defw shot_box_0_simon, shot_box_1_simon, shot_box_2_simon
shot_vs_proj:                  ; (0x825F) C450/C460 vs shot
	call hit_class_shot
	call DISPATCH_A
	defw shot_box_0_proj, shot_box_1_proj, shot_box_2_proj
shot_vs_shield:                ; (0x826B) yellow shield vs shot
	call hit_class_shot
	call DISPATCH_A
	defw shot_box_0_shield, shot_box_1_shield, shot_box_2_shield
shot_vs_whip:                  ; (0x8277) whip vs shot
	call hit_class_shot
	call DISPATCH_A
	defw shot_box_0_whip, shot_box_1_whip, shot_box_2_whip
actor_vs_whip:                 ; (0x8283) whip vs C800
	call hit_class_c800
	call DISPATCH_A
	defw box_1_whip, box_2_whip, box_3_whip, box_4_whip
	defw box_5_whip, box_6_whip, box_7_whip
actor_vs_simon:                ; (0x8297) C800 vs Simon (contact)
	call hit_class_c800
	call DISPATCH_A
	defw box_1_simon, box_2_simon, box_3_simon, box_4_simon
	defw box_5_simon, box_6_simon, box_7_simon
actor_vs_proj:                 ; (0x82AB) C450/C460 vs C800
	call hit_class_c800
	call DISPATCH_A
	defw box_1_proj, box_2_proj, box_3_proj, box_4_proj
	defw box_5_proj, box_6_proj, box_7_proj
hit_class_c800:                ; (0x82BF) A = class 0..6; B=X C=Y
	ld a,(ix+000h)
	dec a
	ld hl,hit_class_c800_tbl
	call ADD_HL_A
	ld a,(hl)
	dec a
	ld b,(ix+005h)
	ld c,(ix+003h)
	ret
hit_class_c800_tbl:            ; (0x82D2) type-1 -> class 1..7 (then dec a)
	defb 001h,001h,001h,002h,003h,001h,002h,002h  ; 1-8
	defb 001h,001h,001h,002h,002h,002h,004h,004h  ; 9-16
	defb 005h,004h,004h,006h,006h,007h,002h,002h  ; 17-24
	defb 002h,002h,002h,002h,001h,001h,002h,001h  ; 25-32
	defb 001h,002h,002h,002h,001h,002h,001h,001h  ; 33-40
	defb 001h,001h,001h,002h,001h,001h,001h,001h  ; 41-48
hit_class_shot:                ; (0x8302) A = class 0..2; B=X C=Y
	ld a,(ix+000h)
	dec a
	ld hl,hit_class_shot_tbl
	call ADD_HL_A
	ld a,(hl)
	ld b,(ix+005h)
	ld c,(ix+003h)
	ret
hit_class_shot_tbl:            ; (0x8314) shot type-1 -> class 0..2
	defb 000h,000h,000h,002h,000h,001h,001h,002h,002h,000h,002h
shot_box_0_simon:                  ; 0x831F  3x6 vs Simon
	ld hl,00603h
	ld d,b
	ld e,c
	jp overlap_simon
shot_box_0_whip:                   ; 0x8327
	ld hl,00603h
	ld d,b
	ld e,c
	jp overlap_whip
shot_box_0_proj:                   ; 0x832F
	ld hl,00603h
	ld d,b
	ld e,c
	jp overlap_projectile
shot_box_0_shield:                 ; 0x8337
	ld hl,00603h
	ld d,b
	ld e,c
	jp overlap_shield
shot_box_1_simon:                  ; 0x833F  6x6
	ld hl,00606h
	ld d,b
	ld e,c
	jp overlap_simon
shot_box_1_whip:
	ld hl,00606h
	ld d,b
	ld e,c
	jp overlap_whip
shot_box_1_proj:
	ld hl,00606h
	ld d,b
	ld e,c
	jp overlap_projectile
shot_box_1_shield:
	ld hl,00606h
	ld d,b
	ld e,c
	jp overlap_shield
shot_box_2_simon:                  ; 0x835F  6x12 (bone / axe / sickle)
	ld hl,00c06h
	ld d,b
	ld e,c
	jp overlap_simon
shot_box_2_whip:
	ld hl,00c06h
	ld d,b
	ld e,c
	jp overlap_whip
shot_box_2_proj:
	ld hl,00c06h
	ld d,b
	ld e,c
	jp overlap_projectile
shot_box_2_shield:
	ld hl,00c06h
	ld d,b
	ld e,c
	jp overlap_shield
; C800 class 1 fodder (zombie, merman, pikeman, skels, pile): 5x24
box_1_simon:                   ; 0x837F
	ld hl,01805h
	ld d,b
	ld e,c
	jp overlap_simon
box_1_whip:
	ld hl,01805h
	ld d,b
	ld e,c
	jp overlap_whip
box_1_proj:
	ld hl,01805h
	ld d,b
	ld e,c
	jp overlap_projectile
; class 2 flyers (bat, skull, ghost, raven, hunch, dragon, blob, igor): 8x16
box_2_simon:                   ; 0x8397
	ld hl,01008h
	ld d,b
	ld e,c
	jp overlap_simon
box_2_whip:                    ; 0x839F -> shared 10x8 whip tail
	ld d,b
	ld e,c
	jr box_10x08_whip
obj_vs_whip_hi:                ; (0x83A3) HL slot Y+10, X+8 vs whip
	call obj_xy_10_8
	jr box_10x08_whip
obj_vs_whip_lo:                ; (0x83A8) HL slot Y+20, X+10 vs whip
	call obj_xy_20_10
box_10x08_whip:                ; 0x83AB
	ld hl,01008h
	jp overlap_whip
box_2_proj:                    ; 0x83B1
	ld d,b
	ld e,c
	jr box_10x08_proj
obj_vs_proj_hi:                ; (0x83B5)
	call obj_xy_10_8
	jr box_10x08_proj
obj_vs_proj_lo:                ; (0x83BA)
	call obj_xy_20_10
box_10x08_proj:                ; 0x83BD
	ld hl,01008h
	jp overlap_projectile
obj_xy_20_10:                  ; (0x83C3) E=Y+0x20, D=X+0x10 from HL
	inc l
	ld a,(hl)
	add a,020h
	ld e,a
	inc l
	ld a,(hl)
	add a,010h
	ld d,a
	ret
obj_xy_10_8:                   ; (0x83CE) E=Y+0x10, D=X+0x08 from HL
	inc l
	ld a,(hl)
	add a,010h
	ld e,a
	inc l
	ld a,(hl)
	add a,008h
	ld d,a
	ret
; class 3 dog: 12x10
box_3_simon:                   ; 0x83D9
	ld hl,00a0ch
	ld d,b
	ld e,c
	jp overlap_simon
box_3_whip:
	ld hl,00a0ch
	ld d,b
	ld e,c
	jp overlap_whip
box_3_proj:
	ld hl,00a0ch
	ld d,b
	ld e,c
	jp overlap_projectile
; class 4 roc / axe / giant bat / medusa: 12x24
box_4_simon:                   ; 0x83F1
	ld hl,0180ch
	ld d,b
	ld e,c
	jp overlap_simon
box_4_whip:
	ld hl,0180ch
	ld d,b
	ld e,c
	jp overlap_whip
box_4_proj:
	ld hl,0180ch
	ld d,b
	ld e,c
	jp overlap_projectile
; class 5 Dracula: 16x48 vs Simon; whip/proj use 5x24 at Y-0x20 (head)
box_5_simon:                   ; 0x8409
	ld hl,03010h
	ld d,b
	ld e,c
	jp overlap_simon
box_5_whip:                    ; 0x8411
	ld hl,01805h
	ld d,b
	ld a,c
	sub 020h
	ld e,a
	jp overlap_whip
box_5_proj:                    ; 0x841C
	ld hl,01805h
	ld d,b
	ld a,c
	sub 020h
	ld e,a
	jp overlap_projectile
; class 6 mummy / Frankenstein: 5x40
box_6_simon:                   ; 0x8427
	ld hl,02805h
	ld d,b
	ld e,c
	jp overlap_simon
box_6_whip:
	ld hl,02805h
	ld d,b
	ld e,c
	jp overlap_whip
box_6_proj:
	ld hl,02805h
	ld d,b
	ld e,c
	jp overlap_projectile
; class 7 grim reaper: 8x48
box_7_simon:                   ; 0x843F
	ld hl,03008h
	ld d,b
	ld e,c
	jp overlap_simon
box_7_whip:
	ld hl,03008h
	ld d,b
	ld e,c
	jp overlap_whip
box_7_proj:
	ld hl,03008h
	ld d,b
	ld e,c
	jp overlap_projectile
candle_vs_whip:                ; (0x8457) C470 slot HL vs whip
	inc hl
	ld a,(hl)
	add a,010h
	ld e,a
	inc hl
	ld a,(hl)
	add a,008h
	ld d,a
	ld hl,01008h
	jp overlap_whip
sub_8467h:
	ld a,(ix+004h)
	cp 002h
	ld hl,01008h
	jr c,l8474h
	ld hl,02010h
l8474h:
	ld a,(ix+001h)
	add a,h
	ld e,a
	ld a,(ix+002h)
	add a,l
	ld d,a
	jp overlap_projectile
overlap_simon:                 ; (0x8481) DE=actor XY, HL=box; vs Simon C427/C425
	ld a,005h
	add a,l
	ld l,a
	ld a,(0c427h)
	sub d
	jr nc,l848dh
	neg
l848dh:
	cp l
	ret nc
	ld c,h
	ld a,(0c420h)
	ld b,a
	dec a
	cp 002h
	ld a,012h
	jr c,l849dh
	ld a,01ah
l849dh:
	add a,h
	ld h,a
	ld a,b
	dec a
	ld a,(0c425h)
	jr nz,l84a8h
	sub 008h
l84a8h:
	sub 002h
	sub e
	add a,c
	cp h
	ret
overlap_whip:                  ; (0x84AE) DE=actor XY, HL=box; vs whip (facing + C416)
	ld a,(0c416h)
	dec a
	ld a,00ch
	jr nz,l84b8h
	ld a,010h
l84b8h:
	add a,l
	ld l,a
	call sub_84e0h
	jr nc,l84c1h
	xor a
	ret
l84c1h:
	sub d
	jr nc,l84c6h
	neg
l84c6h:
	cp l
	ret nc
	ld a,(0c420h)
	cp 002h
	ld b,012h
	jr nz,l84d3h
	ld b,00ah
l84d3h:
	ld c,h
	ld a,004h
	add a,h
	ld h,a
	ld a,(0c425h)
	sub b
	sub e
	add a,c
	cp h
	ret
sub_84e0h:
	ld a,(0c416h)
	dec a
	ld b,014h
	jr nz,l84eah
	ld b,018h
l84eah:
	ld a,(0c42ch)
	and a
	ld a,(0c427h)
	jr z,l84f5h
	sub b
	ret
l84f5h:
	add a,b
	ret
overlap_projectile:            ; (0x84F7) DE=actor XY, HL=box; vs C450 then C460
	ld iy,0c450h
	call sub_8507h
	ret c
	ld iy,0c460h
	call sub_8507h
	ret
sub_8507h:
	ld a,006h
	add a,l
	ld l,a
	ld a,(iy+005h)
	sub d
	jr nc,l8513h
	neg
l8513h:
	cp l
	ret nc
	ld a,(iy+001h)
	cp 002h
	ld b,00ch
	jr nz,l8520h
	ld b,006h
l8520h:
	ld c,h
	ld a,b
	add a,h
	ld h,a
	ld a,(iy+004h)
	sub e
	add a,c
	cp h
	ret
	ld a,(0c420h)
	cp 004h
	jr nz,l8538h
	ld a,(0c428h)
	cp 003h
	ret c
l8538h:
	ld hl,0c598h
	ld de,CHKRAM
	ld b,002h
l8540h:
	ld a,(hl)
	and a
	push hl
	push bc
	call nz,sub_8556h
	pop bc
	pop hl
	ld a,007h
	call ADD_HL_A
	djnz l8540h
	ld a,d
	or e
	ld (0c439h),a
	ret
sub_8556h:
	ld c,(hl)
	inc hl
	ld a,(0c425h)
	sub (hl)
	cp 008h
	jr nc,l8575h
	ld b,007h
	inc hl
	ld a,(0c427h)
	sub b
	sub (hl)
	cp 020h
	jr c,l857fh
	ld a,(0c427h)
	add a,b
	sub (hl)
	cp 020h
	jr c,l857fh
l8575h:
	ld a,c
	rra
	jr c,l857ch
	ld d,000h
	ret
l857ch:
	ld e,000h
	ret
l857fh:
	ld a,c
	rra
	jr c,l8585h
	ld d,c
	ret
l8585h:
	ld e,c
	ret
; door_proximity (0x8587): carry set if Simon overlaps the white-key door.
; Entry: B = Simon Y (0xC425), C = Simon X (0xC427).  0xC5AD is door Y,
; 0xC5AE is door X (from door_tbl, NOT a 0x1F object).  Y window is 0x38
; after C5AD-8; X window is 8.  Facing (0xC42C) nudges C by +/-8 first.
door_proximity:
	ld a,(0c42ch)
	and a
	jr z,l8593h
	ld a,c
	sub 008h
	ld c,a
	jr l8597h
l8593h:
	ld a,c
	add a,008h
	ld c,a
l8597h:
	dec b
	dec b
	ld a,(0c5adh)          ; door Y
	sub 008h
	ld d,a
	ld a,b
	sub d
	cp 038h
	ret nc                 ; Y miss
	ld a,(0c5aeh)          ; door X
	ld d,a
	ld a,c
	sub d
	cp 008h
	ret                    ; carry = X overlap
; --- hurt_simon_projectile (seg2 0x85AD) - Simon TAKES damage from a hazard ------
; Scans the 3 hazard/projectile slots at 0xC580; if Simon overlaps one (sub_85e5h
; returns carry) it puts Simon into the hurt/knockback state (0xC420=5) and deals
; fixed damage: B = 8, or B = 16 when bit 0 of the slot byte is set (stronger
; hazard).  Skipped while Simon is already dying (0xC420==6) or during the 0xC42D /
; 0xC43A i-frame / freeze timers.
hurt_simon_projectile:
	ld a,(0c420h)
	cp 006h
	ret z                  ; already dying -> ignore
	ld a,(0c42dh)
	and a
	ret nz
	ld a,(0c43ah)
	and a
	ret nz
	ld hl,0c580h           ; 3 hazard/projectile slots
	ld b,003h
l85c2h:
	ld a,(hl)
	and a
	jr z,l85ddh
	push hl
	call sub_85e5h         ; overlap test vs Simon
	pop hl
	jr nc,l85ddh           ; no hit -> next slot
	ld a,005h
	ld (0c420h),a          ; hurt/knockback state
	ld a,(hl)
	rra
	ld b,008h              ; base hazard damage = 8
	jr nc,l85dah
	ld b,010h              ; flagged hazard = 16
l85dah:
	jp damage_health       ; 0xC415 -= B
l85ddh:
	ld a,008h
	call ADD_HL_A
	djnz l85c2h
	ret
sub_85e5h:
	inc hl
	ld a,(hl)
	ld d,a
	ld a,(0c425h)
	sub 01ch
	sub d
	cp 008h
	ret nc
	inc hl
	ld a,(hl)
	ld d,a
	ld a,(0c427h)
	sub d
	cp 020h
	ret
; spot_proximity (seg2 0x85FB): carry if Simon overlaps the armed spot
; (C5B1!=0, C5B2=Y, C5B3=X).  Box is 0x10 tall (vs Y-4) and 0x10 wide.
; simon_crouch: on-pad + UP -> portal wind-up (state 7).
spot_proximity:
	ld hl,0c5b1h
	ld a,(hl)              ; C5B1 armed?
	and a
	ret z                  ; NC: no pad in this room
	inc hl
	ld a,(hl)              ; C5B2 pad Y
	ld d,a
	ld a,(0c425h)          ; Simon Y
	sub 004h
	sub d
	cp 010h
	ret nc                 ; Y miss
	inc hl
	ld a,(hl)              ; C5B3 pad X
	ld d,a
	ld a,(0c427h)          ; Simon X
	sub d
	cp 010h
	ret                    ; CY if X in 0x10 box
; yellow_shield_tick (seg2 0x8617): if C701 bit5 (bonus id 4), overlap-test the
; shot slots and absorb hits: free the shot, spend a C441 charge,
; drop the yellow shield at 0.
yellow_shield_tick:
	ld a,(0c701h)
	and 020h               ; yellow shield (id 4)
	ret z
	ld ix,0d700h
	ld b,008h
l8623h:
	push bc
	ld a,(ix+000h)
	and a
	jr z,l8649h
	cp 00ch
	jr z,l8649h
	call shot_vs_shield
	jr nc,l8649h
	call sub_9a21h
	ld a,00bh
	call play_sound
	ld hl,0c441h
	dec (hl)
	jr nz,l8649h
	ld hl,0c701h
	res 5,(hl)             ; charges gone -> drop yellow shield
	call hud_bonus_refresh
l8649h:
	pop bc
	ld de,00080h
	add ix,de
	djnz l8623h
	ret
overlap_shield:                ; (0x8652) yellow shield: Simon X ±8 by facing
	ld a,004h
	add a,l
	ld l,a
	ld a,(0c42ch)
	and a
	ld a,008h
	jr z,l8660h
	neg
l8660h:
	ld b,a
	ld a,(0c427h)
	add a,b
	sub d
	jr nc,l866ah
	neg
l866ah:
	cp l
	ret nc
	ld c,h
	ld a,020h
	add a,h
	ld h,a
	ld a,(0c425h)
	sub e
	add a,c
	cp h
	ret
; ---------------------------------------------------------------------------
;  brazier_tick_all (seg2 0x8678) - per-frame update of the destructible light
;  scenery (braziers in the courtyard / candles in the castle).  Walks the 8
;  object slots at 0xC470 (stride 0x10) and ticks each active one.  Called each
;  frame from seg0 0x8656-area and seg1 0x628-area.
; ---------------------------------------------------------------------------
brazier_tick_all:
	ld bc,00800h            ; B = 8 slots, C = 0 (slot index)
	ld hl,0c470h            ; HL -> scenery object block
l867eh:
	push bc
	push hl
	push hl
	pop ix                  ; IX -> current object
	ld a,(hl)               ; A = +0x00 state
	ld b,a                  ; keep old state in B
	or a
	call nz,brazier_tick    ; tick it if active (state != 0)
	pop hl
	pop bc
	inc c                   ; next slot index
	ld a,l
	add a,010h              ; HL += 0x10 (next slot)
	ld l,a
	djnz l867eh
	ret

; ---------------------------------------------------------------------------
;  brazier_tick (seg2 0x8693) - update one C470 slot (candle or breakable
;  block).  First frame (old +00==1) saves the nametable under the object
;  (`block_save_under`) then either draws the flame or stamps 4x4 brick
;  tiles (`block_stamp`).  Hit (+0x03 != 0) -> brazier_destroyed.
; ---------------------------------------------------------------------------
brazier_tick:
	ld (hl),002h            ; +0x00 state = 2 (present/lit)
	inc l
	ld e,(hl)               ; E = +0x01  \ object word
	inc l
	ld d,(hl)               ; D = +0x02  / (screen pos)
	inc l
	ld a,(hl)               ; A = +0x03 hit flag
	or a
	jp nz,brazier_destroyed ; hit -> destroy + drop
	inc l
	ld a,(hl)               ; A = +0x04 kind
	ex af,af'
	inc l
	inc l
	inc (hl)                ; +0x06 anim
	ld a,b
	cp 001h
	jr nz,l86bah            ; already stamped
	ex af,af'
	push af
	push de
	call block_save_under  ; copy nametable under this slot to E480/E4A0
	pop de
	pop af
	cp 002h
	jp c,l86c2h             ; kind 0/1: candle flame
	jp block_stamp          ; kind 2/3: overlay brick tiles
l86bah:
	ld a,(hl)
	and 003h
	ret nz
	ex af,af'
	cp 002h
	ret nc                  ; blocks: stamp once
l86c2h:
	or a
	ld a,000h
	jr z,l86c9h
	ld a,002h
l86c9h:
	bit 3,(hl)
	jr z,l86ceh
	inc a
l86ceh:
	jp l8991h
; block_stamp (seg2 0x86D1) - blit brick tile ids to VRAM and into D100.
; kind 2 = 16x16 (2x2); kind 3 = 32x32 (4x4, skip the leading 2x2 bytes).
; Courtyard uses block_tiles_court; castle uses block_tiles_castle.
block_stamp:
	ld b,a
	ld a,(0d002h)
	or a
	ld hl,block_tiles_court
	jr z,l86deh
	ld hl,block_tiles_castle
l86deh:
	ld a,b
	ld bc,01002h
	cp 002h
	jr z,l86eeh
	ld bc,02004h
	ld a,004h
	call ADD_HL_A
l86eeh:
	push bc
	push de
	ld b,c
	push bc
	push hl
	push de
	call tiles_blit_vram
	pop de
	call 07d36h            ; map_cell_at
	pop de
	pop bc
	ex de,hl
	call tiles_to_map
	pop hl
	pop de
	ld e,d
	ld a,(0c702h)
	rra
	ret nc
sub_8709h:
	ld c,00eh              ; white (MSX colour 14) rectangle outline
	jp 048e3h
sub_870eh:
	ld a,(0c702h)
	rra
	ret nc
sub_8713h:
	ld bc,00800h
	ld hl,0c470h
l8719h:
	push bc
	push hl
	ld a,(hl)
	cp 002h
	jr nz,l8737h
	inc l
	ld e,(hl)
	inc l
	ld d,(hl)
	inc l
	inc l
	ld a,(hl)
	cp 002h
	jr c,l8737h
	ex de,hl
	ld de,01010h
	jr z,l8734h
	ld de,02020h
l8734h:
	call sub_8709h
l8737h:
	pop hl
	pop bc
	inc c
	ld a,l
	add a,010h
	ld l,a
	djnz l8719h
	ret
; block_save_under (seg2 0x8741) - copy the nametable under this C470 slot
; into E480 (2x2, kind!=3) or E4A0 (4x4, kind 3), indexed by slot C.
block_save_under:
	cp 003h
	ld hl,0e4a0h
	jr z,l875eh
	ld hl,0e480h
l874bh:
	push hl
	push bc
	call 07d36h
	pop bc
	pop de
	ld a,c
	add a,a
	add a,a
	call ADD_DE_A
	ld bc,00202h
	jp l8773h
l875eh:
	push hl
	push bc
	call 07d36h
	pop bc
	pop de
	ld a,c
	add a,a
	add a,a
	add a,a
	add a,a
	call ADD_DE_A
	ld bc,00404h
	jp l8773h
l8773h:
	push bc
	ld b,000h
	push hl
	ldir
	pop hl
	pop bc
	ld a,020h
	call ADD_HL_A
	djnz l8773h
	ret
; tiles_blit_vram (seg2 0x8783) - B rows x C tile-ids from (HL) at pixel DE.
tiles_blit_vram:
	push bc
	push de
	ld b,c
l8786h:
	ld a,(hl)
	inc hl
	call 04b12h
	call 04b56h
	djnz l8786h
	pop de
	ld a,e
	add a,008h
	ld e,a
	pop bc
	djnz tiles_blit_vram
	ret
; 2x2 then 4x4 8x8 tile ids stamped over a breakable block (courtyard / castle).
block_tiles_court:
	defb 001h,002h,009h,00bh
	defb 001h,002h,001h,002h
	defb 009h,00bh,00ah,009h
	defb 001h,002h,001h,002h
	defb 009h,00bh,00ah,009h
block_tiles_castle:
	defb 001h,002h,00ah,00bh
	defb 001h,002h,001h,002h
	defb 00ah,00bh,00ah,00bh
	defb 001h,002h,001h,002h
	defb 00ah,00bh,00ah,00bh
; ---------------------------------------------------------------------------
;  brazier_destroyed (seg2 0x87C1) - candle or block hit.  HL -> +0x03.
;  Kind < 2: candle. Kind >= 2: restore nametable/VRAM from E480/E4A0, play
;  SFX 0x0E.  +05 bonus 0x1F = reveal (vendor/chest from +09); 0x18 = white
;  key floor spawn; else scenery_clear_rec + drop_spawn (slime = 0x15).
; ---------------------------------------------------------------------------
brazier_destroyed:
	ld (hl),000h            ; +0x03 hit flag = 0
	inc l
	ld (ix+000h),000h       ; +0x00 state = 0 (object gone)
	ld a,(hl)               ; A = +0x04 kind
	inc l
	ld b,(hl)               ; B = +0x05 bonus id
	cp 002h
	jp nc,l87d9h
	call block_restore_vram_2x2
	call scenery_clear_rec
	jp scenery_drop
l87d9h:
	push bc
	push de
	push bc
	ld c,a
	ld a,00eh
	call play_sound
	ld a,c
	pop bc
	cp 002h
	jr z,l87f0h
	call block_restore_vram_4x4
	call block_restore_map_4x4
	jr l87f6h
l87f0h:
	call block_restore_vram_2x2
	call block_restore_map_2x2
l87f6h:
	ld a,(ix+005h)         ; bonus id
	cp 01fh
	jr z,l881bh            ; 0x1F = reveal (third scenery byte)
	cp 018h
	jr z,l8845h            ; 0x18 = white key
	call scenery_clear_rec
	pop de
	pop bc
	ld a,b
	or a
	jr z,l8818h
	ld a,(ix+004h)
	cp 003h
	jr nz,l8815h
	ld a,e
	add a,010h             ; 4x4 block: drop at Y+16
	ld e,a
l8815h:
	call drop_spawn
l8818h:
	jp l88ceh
; --- reveal (bonus 0x1F): +09 is the third scenery byte, +07/+08 -> E000 pos.
;  bits7-6 == 11 -> vendor (bits5-2 offer index, bits1-0 slot) via l9180h.
;  otherwise -> chest contents bits4-0 via l8a1ah.
l881bh:
	pop de
	pop bc
	ld a,(ix+009h)         ; reveal byte
	ld b,a
	ld h,(ix+007h)         ; HL -> E000 pos
	ld l,(ix+008h)
	and 0c0h
	cp 0c0h
	ld a,b
	jr z,l8838h
	and 01fh
	ld b,a
	ld a,e
	add a,010h
	ld e,a
	jp l8a1ah
l8838h:
	ld c,a
	and 03ch
	rrca
	rrca
	ld b,a
	ld a,c
	and 003h
	ld c,a
	jp l9180h
l8845h:
	ld b,a
	pop de
	pop bc
	ld h,(ix+007h)
	ld l,(ix+008h)
	jp l8a04h
block_restore_vram_2x2:
	ld hl,0e480h
sub_8854h:                     ; also: blit 2x2 from caller HL (door path)
	push bc
	push de
	ld a,c
	add a,a
	add a,a
	call ADD_HL_A
	ld bc,00202h
	call tiles_blit_vram
	pop de
	pop bc
	ret
block_restore_vram_4x4:
	ld hl,0e4a0h
l8868h:
	push bc
	push de
	ld a,c
	add a,a
	add a,a
	add a,a
	add a,a
	call ADD_HL_A
	ld bc,00404h
	call tiles_blit_vram
	pop de
	pop bc
	ret
scenery_clear_rec:
	ld h,(ix+007h)
	ld l,(ix+008h)
	ld (hl),000h           ; zero E000 pos (record gone)
	ret
block_restore_map_2x2:
	ld hl,0e480h
	push bc
	push de
	push hl
	push bc
	call 07d36h
	pop bc
	pop de
	ld a,c
	add a,a
	add a,a
	call ADD_DE_A
	ex de,hl
	ld bc,00202h
	call tiles_to_map
	pop de
	pop bc
	ret
block_restore_map_4x4:
	ld hl,0e4a0h
sub_88a3h:                     ; also: 4x4 map restore from caller HL (vendor 0xE580)
	push bc
	push de
	push hl
	push bc
	call 07d36h
	pop bc
	pop de
	ld a,c
	add a,a
	add a,a
	add a,a
	add a,a
	call ADD_DE_A
	ex de,hl
	ld bc,00404h
	call tiles_to_map
	pop de
	pop bc
	ret
tiles_to_map:
	push bc
	ld b,000h
	push de
	ldir
	pop de
	pop bc
	ld a,020h
	call ADD_DE_A
	djnz tiles_to_map
	ret
l88ceh:
	ld hl,0c5a6h
	ld bc,00201h
l88d4h:
	ld (hl),c
	inc l
	ld (hl),e
	inc l
	ld (hl),d
	inc l
	ld c,084h
	djnz l88d4h
	ret
break_spark_tick:                  ; (seg2 0x88DF) two C5A6 whip-break sparks
	ld b,002h
	ld hl,0c5a6h
l88e4h:
	push bc
	push hl
	ld a,(hl)
	ld b,a
	or a
	jr z,l88f1h
	call sub_88f9h
	call sub_8942h
l88f1h:
	pop hl
	inc l
	inc l
	inc l
	pop bc
	djnz l88e4h
	ret
sub_88f9h:
	and 07fh
	ld c,a
	inc l
	inc l
	ld a,(hl)
	bit 7,b
	jr nz,l890ah
	add a,002h
	jr c,l8929h
	ld (hl),a
	jr l890fh
l890ah:
	sub 002h
	jr c,l8929h
	ld (hl),a
l890fh:
	dec l
	dec l
	ld a,c
	inc a
	ld de,l892fh
	call ADD_DE_A
	ld a,(de)
	inc (hl)
	or a
	jr nz,l8921h
	dec (hl)
	ld a,00ah
l8921h:
	inc l
	add a,(hl)
	ld (hl),a
	cp 0d4h
	jr nc,l892ah
	ret
l8929h:
	dec l
l892ah:
	ld (hl),0e0h
	dec l
	ld (hl),000h
l892fh:
	inc l
	ret
	jp m,0fcfch
	call m,0fefeh
	rst 38h
	rst 38h
	ld bc,00201h
	ld (bc),a
	inc b
	inc b
	inc b
	ld b,000h
sub_8942h:
	ld hl,0c5a7h
	ld de,0d628h
	ld b,002h
l894ah:
	push bc
	push hl
	ld bc,002ffh
	ld a,0e0h
l8951h:
	push hl
	ldi
	ldi
	ld (de),a
	inc de
	inc de
	ld a,0e4h
	pop hl
	djnz l8951h
	pop hl
	inc hl
	inc hl
	inc hl
	pop bc
	djnz l894ah
	ld hl,0d4a0h
	ld a,002h
	call sub_8979h
	ld a,04ch
	call sub_8979h
	ld a,002h
	call sub_8979h
	ld a,04ch
sub_8979h:
	ld b,010h
l897bh:
	ld (hl),a
	inc hl
	djnz l897bh
	ret
l8980h:
	ld a,005h              ; leather whip: source X = 5*16
	ld l,070h              ; source Y = 0x70
l8984h:                        ; HMMM 16x16 from VRAM page 1 at (A*16, L)
	add a,a
	add a,a
	add a,a
	add a,a
	ld h,a
	ld bc,01010h
	ld a,001h
	jp vdp_hmmm
l8991h:
	ld l,070h
	jp l8cd2h
scenery_drop:
	call sub_8a30h
scenery_drop_slot:
	ld a,b
	or a
	jr z,l89a5h
	cp 015h                ; slime: no flame, C500 hatches actor_blob_*
	jr z,l89a5h
	call sub_89c6h
	ret z
l89a5h:
	call sub_8a3eh
	ret nz
	ld (hl),001h
	inc l
	ld (hl),e
	inc l
	ld (hl),d
	inc l
	ld (hl),000h
	inc l
	ld (hl),b
	inc l
	ld (hl),000h
	ld a,b
	cp 015h
	jr z,l89c2h
	cp 002h
	jr c,l89c2h
	ld (hl),002h
l89c2h:
	inc l
	ld (hl),000h
	ret
sub_89c6h:
	push bc
	push de
	push ix
	ld a,e
	add a,010h
	ld e,a
	ld a,d
	add a,008h
	ld d,a
	ld a,b
	cp 001h
	jr nz,l89dbh
	ld c,actor_flame
	jr l89ddh
l89dbh:
	ld c,026h
l89ddh:
	xor a
	call 05f26h
	ld a,(0cf31h)
	dec a
	pop ix
	pop de
	pop bc
	ret
drop_spawn:
	ld a,b
	cp 015h
	jp z,scenery_drop_slot
	call sub_8a30h
	call sub_8a3eh
	ret nz
sub_89f7h:
	ld (hl),083h
	inc l
	ld (hl),e
	inc l
	ld (hl),d
	inc l
	inc l
	ld (hl),b
	inc l
	ld (hl),0ffh
	ret
l8a04h:
	ld (0c70dh),hl
	call sub_8a3eh
	ret nz
	call sub_89f7h
	ld a,l
	add a,009h
	ld l,a
l8a12h:
	ld de,(0c70dh)
	ld (hl),d
	inc l
	ld (hl),e
	ret
l8a1ah:
	ld (0c70dh),hl
	call sub_8a3eh
	ret nz
	push bc
	ld b,019h              ; chest container (bonus id 25)
	call sub_89f7h
	pop bc
	ld a,l
	add a,008h
	ld l,a
	ld (hl),b              ; +0x0D = real contents id
	inc l
	jr l8a12h
sub_8a30h:
	ld a,b
	cp 01ah
	ret c
	ld a,(0c416h)
	add a,019h
	cp b
	ret nz
	ld b,001h
	ret
sub_8a3eh:
	push bc
	ld hl,0c500h
	ld b,008h
l8a44h:
	ld a,(hl)
	or a
	jr z,l8a4fh
	ld a,010h
	add a,l
	ld l,a
	djnz l8a44h
	or a
l8a4fh:
	pop bc
	ret
pickup_tick:                       ; (seg2 0x8A51) 8 x C500 floor items/chests
	call sub_8f5ch             ; pickup-popup timer
	ld bc,00800h
	ld hl,0c500h
l8a5ah:
	push hl
	pop ix
	push bc
	push hl
	ld a,(hl)
	ld b,a
	or a
	jr z,l8a6ah
	call sub_8a74h
	call sub_8c67h
l8a6ah:
	pop hl
	pop bc
	ld a,010h
	add a,l
	ld l,a
	inc c
	djnz l8a5ah
	ret
sub_8a74h:
	ld e,(ix+001h)
	ld d,(ix+002h)
	ex af,af'
	ld a,(ix+003h)
	dec a
	jp z,l8be6h
	ex af,af'
	dec a
	and 07fh
	exx
	ld hl,l8a94h
	add a,a
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)
	push de
	exx
	ret
l8a94h:
	and b
	adc a,d
	rst 38h
	adc a,d
	ld (hl),a
	adc a,e
	xor c
	adc a,e
	out (08bh),a
	and b
	adc a,d
	inc (ix+006h)
	ld a,(ix+006h)
	and 00fh
	ret nz
	inc (hl)
	ld a,(ix+004h)
	or a
	jp z,l8b22h
	cp 015h                ; slime fake-item: hatch instead of settling
	jr z,l8ad7h
	set 7,(hl)
	dec a
	ld a,001h
	jr z,l8abeh
	ld a,002h
l8abeh:
	ld (ix+005h),a
	ret nz
	ld (ix+006h),000h
	ld (ix+009h),002h
	ld (ix+00ah),000h
	ld (ix+00bh),000h
	ld (ix+00ch),020h
	ret
l8ad7h:
	ld a,(0d002h)          ; hub: 0 = courtyard (just despawn)
	or a
	ld b,a
	jr z,l8af4h
	ld a,b
	dec a
	and 007h
	ld hl,blob_hatch_type          ; hub-1 -> blue / white / red
	call ADD_HL_A
	ld c,(hl)
	push ix
	ld a,e
	add a,010h
	ld e,a
	call spawn_actor
	pop ix
l8af4h:
	jp l8b22h
blob_hatch_type:
	defb actor_blob_blue, actor_blob_white, actor_blob_red, actor_blob_red
	defb actor_blob_red, actor_blob_red, actor_blob_white, actor_blob_white
	ld hl,00810h
	add hl,de
	ld a,0dbh
	cp l
	jr c,l8b22h
	ex de,hl
	call 07d36h
	sub 001h
	cp 009h
	jr c,l8b6fh
	ld a,(ix+004h)
	dec a
	jp z,l8b29h
	ld a,(ix+001h)
	add a,008h
	ld (ix+001h),a
	ret
l8b22h:
	ld (ix+005h),0ffh
	jp l8bceh
l8b29h:
	push ix
	pop hl
	inc l
	inc (ix+006h)
	ld a,(0c003h)
	rra
	jr nc,l8b37h
	inc (hl)
l8b37h:
	inc l
	ld d,(hl)
	ld e,(ix+008h)
	ex de,hl
	ld b,(ix+009h)
	ld c,(ix+00ah)
	add hl,bc
	ex de,hl
	ld (ix+008h),e
	ld (hl),d
	ld h,b
	ld l,c
	ld b,(ix+00bh)
	ld c,(ix+00ch)
	and a
	sbc hl,bc
	ld (ix+009h),h
	ld (ix+00ah),l
	ld a,(ix+006h)
	sub 020h
	ret nz
	ld (ix+006h),a
	ld a,b
	cpl
	ld (ix+00bh),a
	ld a,c
	neg
	ld (ix+00ch),a
	ret
l8b6fh:
	ld (ix+005h),0ffh
	inc (ix+000h)
	ret
	ld a,e
	add a,004h
	and 0f8h
	ld e,a
	ld a,d
	add a,004h
	and 0f8h
	ld d,a
	ld (ix+001h),e
	ld (ix+002h),d
	push de
	call sub_8cdfh
	pop de
	ld a,(ix+004h)
	dec a
	call sub_8cc8h
	ld a,(ix+004h)
	sub 017h
	cp 003h
	ld a,008h
	jr nc,l8ba2h
	ld a,0ffh
l8ba2h:
	ld (ix+006h),a
	inc (ix+000h)
	ret
	set 7,(hl)
	ld a,(ix+003h)
	cp 002h
	jp z,l8c4bh
	push de
	ld a,(ix+004h)
	dec a
	call sub_8cc8h
	pop de
	ld a,(ix+006h)
	inc a
	ret z
	ld a,(0c003h)
	and 00fh
	ret nz
	dec (ix+006h)
	ret nz
	call sub_8cedh
l8bceh:
	ld (ix+000h),000h
	ret
	inc (ix+006h)
	ld a,(ix+006h)
	and 01fh
	ret nz
	ld (hl),002h
	ld a,(ix+004h)
	or a
	jp z,l8b22h
	ret
l8be6h:
	ld (ix+003h),000h
	call sub_8f6fh
	ret nz
	ld a,(hl)
	and 07fh
	ld (hl),000h
	cp 004h
	jr nz,l8bfah
	call sub_8cedh
l8bfah:
	ld a,(ix+004h)
	cp 019h                ; chest: don't collect_bonus(25); reveal contents
	jr z,l8c1bh
	ld (ix+005h),0ffh
	call sub_8d30h
	ld a,(ix+004h)
	cp 017h
	jr z,l8c12h
	cp 018h
	ret nz
l8c12h:
	ld h,(ix+00eh)
	ld l,(ix+00fh)
	ld (hl),000h
	ret
l8c1bh:
	ld a,(ix+00dh)         ; contents id stashed when the chest spawned
	ld (ix+004h),a
	call sub_8c36h         ; hop it as a normal pickup
	ld a,(0c700h)
	or a
	jr nz,l8c12h
	ld hl,0c701h
	ld a,(hl)
	and 0f9h
	ld (hl),a
	call sub_8ed0h
	jr l8c12h
sub_8c36h:
	ld a,(ix+001h)
	sub 008h
	ld (ix+001h),a
	ld (ix+000h),005h
	ld (ix+006h),000h
	ld (ix+005h),002h
	ret
; Whip-hit on a world pickup: hourglass (id 10) tips onto its side (id 11);
; a second hit on the tipped one starts its despawn timer (ix+6=1).
l8c4bh:
	ld (ix+003h),000h
	ld a,(ix+004h)
	cp 00ah                ; upright hourglass?
	jr nz,l8c5fh
	ld (ix+004h),00bh      ; -> tipped (bonus_tipped_hourglass)
	call sub_8cedh
	jr sub_8c36h
l8c5fh:
	cp 00bh                ; already tipped: another whip deletes it
	ret nz
	ld (ix+006h),001h
	ret
sub_8c67h:
	ld a,(ix+004h)
	cp 019h
	ret z
	ld a,(ix+000h)
	and 00fh
	cp 004h
	ret z
	ld a,(ix+005h)
	or a
	jr z,l8c85h
	dec a
	jr z,l8c98h
	dec a
	jr z,l8c9dh
	ld a,0e0h
	jr l8cafh
l8c85h:
	ld a,(0c003h)
	ld b,a
	and 001h
	ret nz
	bit 2,b
	ld b,0f4h
	jr nz,l8c94h
	ld b,0f8h
l8c94h:
	ld c,008h
	jr l8cach
l8c98h:
	ld bc,0e808h
	jr l8cach
l8c9dh:
	ld bc,0ec0eh
	ld a,(0c003h)
	and 003h
	ld hl,l8cc4h
	call ADD_HL_A
	ld c,(hl)
l8cach:
	ld a,(ix+001h)
l8cafh:
	ld hl,0d628h
	ld (hl),a
	inc hl
	ld a,(ix+002h)
	ld (hl),a
	inc hl
	ld (hl),b
	ld hl,0d4a0h
	ld b,010h
l8cbfh:
	ld (hl),c
	inc hl
	djnz l8cbfh
	ret
l8cc4h:
	ex af,af'
	ld bc,SCALXY
sub_8cc8h:
	ld l,050h
	cp 010h
	jr c,l8cd2h
	sub 010h
	ld l,060h
l8cd2h:
	add a,a
	add a,a
	add a,a
	add a,a
	ld h,a
	ld bc,01010h
	ld a,048h
	jp vdp_lmmm
sub_8cdfh:
	push bc
	call 07d36h
	pop bc
	ld (ix+007h),c
	ld hl,0e520h
	jp l874bh
sub_8cedh:
	push ix
	push de
	push de
	ld c,(ix+007h)
	ld hl,0e520h
	push bc
	push hl
	call 07d36h
	ld de,0e800h
	ld bc,00202h
	call l8773h
	pop hl
	pop bc
	push bc
	push hl
	ld a,c
	add a,a
	add a,a
	call ADD_HL_A
	ld b,004h
	ld de,0e800h
l8d14h:
	ld a,(de)
	cp (hl)
	jr z,l8d19h
	ld (hl),a
l8d19h:
	inc hl
	inc de
	djnz l8d14h
	pop hl
	pop bc
	pop de
	call sub_8854h
	call sub_9273h
	call door_begin_open
	call sub_870eh
	pop de
	pop ix
	ret
sub_8d30h:
	ld a,(ix+004h)
; ---------------------------------------------------------------------------
;  collect_bonus (seg2 0x8D33) - apply a picked-up bonus whose id is in A.
;  Entry collect_bonus pushes the common tail play_sound; collect_bonus_apply is the bare entry
;  (caller supplies its own continuation).  Latches the bonus id into 0xC419
;  (last-pickup latch, drives the pickup HUD/message) then dispatches through the
;  25-entry word table collect_bonus_tbl at 0x8D45 (index = A-1; A>=0x1A falls through to l8d77h):
;    1/2 hearts, 3/4 shields, 5 white cross, 6 rosary, 7 small orb, 8 blue gem,
;    9 sapphire ring, 10/11 hourglass (upright / tipped), 12/13 boots/wings,
;    14 candle, 15 map, 16/17 bibles, 18 staff, 19/20 money bags,
;    21 slime (fake pickup; collect is a no-effect stub), 22 potion, 23/24 keys,
;    25 chest (container; world collect never reaches this stub).
;  Reached from both pickup paths: the mid-air 0xC800 heart (type 0x24, via
;  sub_9a72h) and the settled 0xC500 pickup list.
; ---------------------------------------------------------------------------
collect_bonus:
	ld hl,play_sound
	push hl
collect_bonus_apply:
	ld (0c419h),a          ; latch last-collected bonus id
	call 08f2ah
	cp 01ah
	jr nc,l8d77h
	dec a
	call DISPATCH_A
collect_bonus_tbl:             ; (seg2 0x8D45) word[id-1]; id>=0x1A -> l8d77h
	defw bonus_small_heart
	defw bonus_large_heart
	defw bonus_red_shield
	defw bonus_yellow_shield
	defw bonus_white_cross
	defw bonus_rosary
	defw bonus_small_orb
	defw bonus_blue_gem
	defw bonus_sapphire_ring
	defw bonus_hourglass
	defw bonus_tipped_hourglass
	defw bonus_boots
	defw bonus_wings
	defw bonus_candle
	defw bonus_map
	defw bonus_black_bible
	defw bonus_white_bible
	defw bonus_staff
	defw bonus_white_bag
	defw bonus_blue_bag
	defw bonus_slime
	defw bonus_potion
	defw bonus_yellow_key
	defw bonus_white_key
	defw bonus_chest
; --- weapon pickup (bonus id >= 0x1A) ---------------------------------------
; index = id - 0x19 -> C416: 0x1A chain (1), 0x1B knife (2), 0x1C axe (3),
; 0x1D cross (4). Index 5 is holy water (bonus_holy_water / C701 bit3), not a
; C416 weapon. Otherwise store the new weapon id, run hud_weapon_icon (HUD), then
; FALL THROUGH into bonus_rosary (brief C440 no-spawn window).
l8d77h:
	sub 019h
	cp 005h
	jr z,bonus_holy_water
	ld (0c416h),a          ; set equipped weapon id
	call hud_weapon_icon
; --- bonus_rosary (id 6, 0x8D83) - temporary "no new enemies" power-up ------
; Arms the enemy-spawn suppression timer 0xC440: while nonzero, room_spawner
; (seg0 0x5EBF) bails every frame and no new enemies spawn. Duration depends on
; bonus id 11 (0xC431 bit 2): 0xF0 (240 frames ~4s) if set, else 0x96 (150
; frames ~2.5s).  Same bit also lengthens the blue gem, sapphire ring, and
; hourglass.  0xC440 counts down each frame in
; seg1 0x75C7. Effect is immediate/current-room; existing 0xC800 actors are kept.
; Weapon pickups fall through into this same code (brief no-spawn window).
bonus_rosary:
	ld a,(0c431h)          ; id 11 (C431 bit2) selects the duration
	and 004h
	ld a,0f0h              ; -> 240-frame timer
	jr nz,l8d8eh
	ld a,096h              ; -> 150-frame timer
l8d8eh:
	ld (0c440h),a          ; arm the no-spawn timer
l8d91h:
	ld a,012h
	ret
bonus_holy_water:              ; id 0x1E (0x8D94): C701 bit3; jump+LEFT/RIGHT, 5 hearts
	ld b,008h
l8d96h:
	call inv_or_c701
	jr l8d91h
bonus_hourglass:               ; id 10 (0x8D9B): C701 bit6
	ld b,040h
	jr l8d96h
bonus_red_shield:              ; id 3 (0x8D9F): C701 bit4, drop bit5, C441=16
	ld hl,0c701h
	res 5,(hl)             ; drop yellow (mutually exclusive)
	ld b,010h              ; bit4 = red shield (face-on contact dmg not 2x)
	jr l8dafh
bonus_yellow_shield:           ; id 4 (0x8DA8): C701 bit5, drop bit4, C441=16
	ld hl,0c701h
	res 4,(hl)             ; drop red
	ld b,020h              ; bit5 = yellow (absorb enemy shots)
l8dafh:
	ld a,010h
	ld (0c441h),a          ; 16 charges
	jr l8d96h
bonus_small_heart:             ; id 1 (0x8DB6): +1 heart currency
	ld b,001h
l8db8h:
	call add_hearts         ; B=1 small (+1); B=5 large (+5)
	ld a,00fh
	ret
bonus_large_heart:             ; id 2 (0x8DBE): +5 heart currency
	ld b,005h
	jr l8db8h
bonus_white_cross:             ; id 5 (0x8DC2): despawn on-screen actors
	push ix
	call 0780dh            ; kill C800 actors and shots
	pop ix
	call sub_9294h
	ld a,018h
	ld (0c43eh),a          ; backdrop flash
	ld a,01bh
	ret
bonus_blue_gem:                ; id 8 (0x8DD4): invis; sprite flash white
	ld a,(0c431h)          ; id 11 -> longer
	and 004h
	ld a,0f0h              ; 240 frames ~4s
	jr nz,l8ddfh
	ld a,096h              ; 150 frames ~2.5s
l8ddfh:
	ld (0c43ah),a          ; skip contact + projectile hits while nonzero
	ld a,016h
	ret
bonus_small_orb:               ; id 7 (0x8DE5): +8 HP (1/4 of 0x20 bar)
	ld b,008h
	call restore_health
	jr l8e11h
bonus_sapphire_ring:           ; id 9 (0x8DEC): sprite flash red; touch-kills
	ld a,(0c431h)          ; id 11 -> longer
	and 004h
	ld a,0f0h
	jr nz,l8df7h
	ld a,096h
l8df7h:
	ld (0c434h),a
	jr l8e11h
bonus_tipped_hourglass:        ; id 11 (0x8DFC): C431 bit2, 1.5x timed bonuses
	ld hl,0c431h           ; whip the hourglass pickup once to get this
	set 2,(hl)
	jr l8e11h
bonus_boots:                   ; id 12 (0x8E03): C431 bit3 faster walk
	ld hl,0c431h
	set 3,(hl)
	jr l8e11h
bonus_wings:                   ; id 13 (0x8E0A): C431 bit4 higher jump
	ld hl,0c431h
	set 4,(hl)
	jr l8e11h
l8e11h:
	jp l8d91h
bonus_potion:                  ; id 22 (0x8E14): bottle, +32 HP = full bar
	ld b,020h              ; vendor sells this (price tbl 0x16); HUD tile @ 0x9A00
	call restore_health
	jr l8e11h
; Shared stub for slime (id 21) and chest (id 25).  collect_bonus has already
; latched C419 and shown the popup; this pops the play_sound continuation and
; returns with no effect.  World chests never get here (l8c1bh opens them).
bonus_slime:                   ; id 21 (0x8E1B): fake candle drop; hatches if left
bonus_chest:                   ; id 25: treasure-chest container (see l8a1ah)
	pop hl
	ret
bonus_candle:                  ; id 14 (0x8E1D): C702 bit0, white C470 outlines
	call sub_8713h         ; draw 0x0E rectangles on breakable blocks
	ld b,001h
	jr l8e34h
bonus_black_bible:             ; id 16 (0x8E24): C702 bit6, vendor price doubled
	ld hl,0c702h
	res 7,(hl)             ; drop the white-bible bit (mutually exclusive)
	ld b,040h
	jr l8e34h
bonus_white_bible:             ; id 17 (0x8E2D): C702 bit7, vendor price halved
	ld hl,0c702h
	res 6,(hl)             ; drop the black-bible bit (mutually exclusive)
	ld b,080h
l8e34h:
	call inv_or_c702         ; 0xC702 |= B
	ld a,012h              ; pickup popup message id
	ret
bonus_map:                     ; id 15 (0x8E3A): C431 bit6, C701 bit7, C70F=3
	ld hl,0c431h
	set 6,(hl)
	ld a,003h
	ld (0c70fh),a          ; 3 map uses (F2)
	ld b,080h
	jp l8d96h
bonus_white_bag:               ; id 19 (0x8E49): +5000 score
	ld de,05000h
l8e4ch:
	call add_score_c0
	ld a,010h
	ret
bonus_blue_bag:                ; id 20 (0x8E52): +1000 score
	ld de,01000h
	jr l8e4ch
bonus_yellow_key:              ; id 23 (0x8E57): C701 bit1, C700=1 (chests)
	ld b,002h
	call inv_or_c701
	ld hl,0c700h
	ld (hl),001h
	call sub_8ed0h
	ld a,014h
	ret
bonus_white_key:               ; id 24 (0x8E67): C701 bit0 (stage-exit door)
	ld b,001h
	call inv_or_c701
	call sub_8ec1h
	ld a,014h
	ret
	pop hl
	ret
; OR bit-mask B into an inventory byte: inv_or_c701 -> 0xC701, inv_or_c702 -> 0xC702
inv_or_c701:
	ld hl,0c701h
	jr l8e7ch
inv_or_c702:
	ld hl,0c702h
l8e7ch:
	ld a,b
	or (hl)
	ld (hl),a
	ret
bonus_staff:                   ; id 18 (0x8E80): C700=3, C701 bit2; drops yellow key
	ld hl,0c431h
	set 1,(hl)
	ld hl,0c701h
	res 1,(hl)             ; can't hold yellow key with the staff
	ld b,004h
	call inv_or_c701
	ld a,003h
	ld (0c700h),a
	call sub_8ed0h
	ld a,00fh
	ret
lose_weapon:                   ; (0x8E9A) C416=0 leather; refresh HUD (missed catch)
	xor a
	ld (0c416h),a
	jp hud_weapon_icon
hud_weapon_icon:                     ; HUD equipped-weapon icon from C416
	ld a,(0c416h)
	ld de,l800ch
	or a
	jp z,l8980h            ; 0 = leather (not in the bonus sheet)
	add a,019h             ; C416 1..4 -> bonus ids 0x1A..0x1D
l8eadh:                        ; A = bonus id -> blit that HUD tile
	dec a                  ; 0-based index
	ld l,050h              ; ids 1-16 at Y=0x50
	cp 010h
	jr c,l8eb8h
	sub 010h
	ld l,060h              ; ids 17+ at Y=0x60
l8eb8h:
	jp l8984h
	call sub_8ed0h
	jp sub_8ec1h
sub_8ec1h:
	ld de,0a40ch
	ld a,(0c701h)
	and 001h
	jp z,l8980h
	ld a,018h
	jr l8eadh
sub_8ed0h:
	ld de,0940ch
	ld a,(0c701h)
	ld b,a
	and 006h
	jp z,l8980h
	ld a,(0c700h)
	or a
	jp z,l8980h
	bit 2,b
	ld a,012h
	jr nz,l8eebh
	ld a,017h
l8eebh:
	jr l8eadh
hud_bonus_refresh:
	call sub_8f51h
	ld a,(0c701h)
	ld c,a
	ld b,005h              ; bits 7..3: map, hourglass, Y shield, R shield, holy
	xor a
l8ef7h:
	rl c
	call c,sub_8f0ch
	inc a
	djnz l8ef7h
	ret
	ld c,b
	ld b,005h
	xor a
l8f04h:
	rl c
	jr c,sub_8f0ch
	inc a
	djnz l8f04h
	ret
sub_8f0ch:
	push af
	push bc
	ld hl,l8f20h
	add a,a
	call ADD_HL_A
	ld d,(hl)
	ld e,00ch
	inc hl
	ld a,(hl)
	call l8eadh
	pop bc
	pop af
	ret
l8f20h:
	ret pe
	rrca
	ret c
	ld a,(bc)
	ret z
	inc b
	ret z
	inc bc
	cp b
	ld e,0feh
	ld bc,0fec8h
	ld e,028h
	inc bc
	cp 017h
	ret nc
	push ix
	push af
; Show the on-screen pickup popup (the little item name/message). This runs for
; EVERY pickup (via 0x8F2A), so 0xC5E5/0xC5E6 are generic - NOT rosary-specific.
	ld a,0ffh
	ld (0c5e5h),a          ; 0xC5E5 = popup active (0xFF)
	ld a,020h
	ld (0c5e6h),a          ; 0xC5E6 = popup display timer (0x20 frames)
	call sub_8f51h
	ld de,0d00ch
	ld a,(0c419h)
	call l8eadh
	pop af
	pop ix
	ret
sub_8f51h:
	ld hl,0b80ch
	ld bc,04010h
	xor a
	ld d,a
	jp 04911h
; Pickup-popup tick: if 0xC5E5==0xFF (active), every 0x40 frames decrement the
; 0xC5E6 timer; when it hits 0, tear the popup down (hud_bonus_refresh).
sub_8f5ch:
	ld a,(0c5e5h)
	inc a
	ret nz                 ; not 0xFF -> no popup active
	ld a,(0c003h)
	and 03fh
	ret z
	ld hl,0c5e6h
	dec (hl)
	ret nz
	jp hud_bonus_refresh
sub_8f6fh:
	push hl
	ld a,(ix+004h)
	cp 019h                ; chest: need C700 (yellow key / staff charges)
	jr nz,l8f8ah
	ld hl,0c700h
	ld a,(hl)
	or a
	jr nz,l8f81h
	inc a
	pop hl
	ret
l8f81h:
	dec (hl)
	ld a,011h
	call play_sound
l8f87h:
	xor a
	pop hl
	ret
l8f8ah:
	cp 017h
	ld b,006h
	jr z,l8f96h
	cp 018h
	ld b,001h
	jr nz,l8f87h
l8f96h:
	call sub_8f9bh
	pop hl
	ret
sub_8f9bh:
	ld hl,0c701h
	ld a,(hl)
	and b
	ret
sub_8fa1h:
	ld a,(0c580h)
	or a
	ret nz
sub_8fa6h:
	ld hl,(0d000h)
	ld de,00106h
	rst 20h
	ret nz
	ld hl,l8fc4h
	ld de,0c580h
	ld b,003h
l8fb6h:
	push bc
	ld bc,00006h
	ldir
	xor a
	ld (de),a
	inc e
	inc e
	pop bc
	djnz l8fb6h
	ret
l8fc4h:                            ; 3 x 6-byte C580 seeds (stage 6 room 1)
	defb 001h,060h,03ch,000h,000h,00bh
	defb 001h,060h,07ch,000h,001h,00ah
	defb 001h,060h,0bch,001h,002h,00bh
hazard_tick:                       ; (seg2 0x8FD6) 3 x C580 hazard slots
	call sub_8fa1h
l8fd9h:
	ld hl,0c580h
	ld b,003h
l8fdeh:
	push hl
	pop ix
	push bc
	push hl
	ld a,(hl)
	or a
	call nz,sub_8ff1h
	pop hl
	pop bc
	ld a,008h
	add a,l
	ld l,a
	djnz l8fdeh
	ret
sub_8ff1h:
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)
	inc hl
	inc (hl)
	ld b,(hl)
	inc hl
	dec a
	jr nz,l9005h
	ld a,c
	and b
	ret nz
	ld a,004h
	jr l900bh
l9005h:
	ld a,003h
	and b
	ret nz
	ld a,0fch
l900bh:
	add a,e
	ld e,a
	ld a,(hl)
	inc hl
	inc (hl)
	sub (hl)
	jr nz,l901ch
	ld (hl),a
	ld a,(ix+000h)
	xor 003h
	ld (ix+000h),a
l901ch:
	ld (ix+001h),e
	ld a,e
	sub 004h
	ld e,a
	ld hl,l8070h
	ld bc,02010h
	ld a,001h
	jp vdp_hmmm
sub_902eh:
	call sub_8fa6h
	jp l8fd9h
platform_load:                     ; (seg2 0x9034) seed C598 from platform_tbl
	ld hl,0c598h
	ld a,(hl)
	or a
	ret nz
	ld hl,platform_tbl
l903dh:
	ld a,(hl)
	inc a
	ret z
	dec a
	push hl
	ld de,(0d000h)
	cp e
	jr nz,l9067h
	inc hl
	ld a,(hl)
	cp d
	jr nz,l9067h
	inc hl
	ld b,(hl)
	inc hl
	ld de,0c598h
	ld c,001h
l9056h:
	push bc
	ld a,c
	ld (de),a
	inc de
	ld bc,00004h
	ldir
	inc de
	inc de
	pop bc
	inc c
	djnz l9056h
	pop hl
	ret
l9067h:
	pop hl
	inc hl
	inc hl
	ld a,(hl)
	inc hl
	add a,a
	add a,a
	call ADD_HL_A
	jr l903dh
platform_tbl:                      ; (seg2 0x9073) {stage,room,n} + n×4 bytes; 0xFF end
	defb 005h,001h,001h        ; stage 5 room 1
	defb 05fh,060h,001h,040h
	defb 005h,004h,002h        ; stage 5 room 4
	defb 05fh,020h,001h,030h
	defb 05fh,0b8h,0ffh,038h
	defb 00ah,000h,001h        ; stage 10 rooms 0/2/3/4
	defb 08fh,060h,001h,060h
	defb 00ah,002h,001h
	defb 0a7h,040h,001h,080h
	defb 00ah,003h,001h
	defb 08fh,020h,001h,0a0h
	defb 00ah,004h,001h
	defb 0a7h,080h,001h,040h
	defb 0ffh
platform_tick:                     ; (seg2 0x90A2) 2 x C598 moving platforms
	ld hl,0c598h
	ld b,002h
l90a7h:
	push bc
	push hl
	ld a,(hl)
	or a
	jr z,l90b5h
	push hl
	call sub_90bfh
	pop hl
	call sub_90dfh
l90b5h:
	pop hl
	pop bc
	ld de,00007h
	add hl,de
	inc c
	djnz l90a7h
	ret
sub_90bfh:
	inc hl
	inc hl
	ld d,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld c,(hl)
	inc hl
	inc (hl)
	ld a,(hl)
	inc hl
	inc (hl)
	ld a,c
	sub (hl)
	jr nz,l90d0h
	ld (hl),a
l90d0h:
	dec hl
	dec hl
	dec hl
	jr nz,l90dah
	ld a,(hl)
	neg
	ld (hl),a
	ret
l90dah:
	dec hl
	ld a,d
	add a,e
	ld (hl),a
	ret
sub_90dfh:
	ld a,(hl)
	push af
l90e1h:
	inc hl
	ld de,0d638h
	dec a
	jr z,l90ebh
	ld de,0d648h
l90ebh:
	call sub_9119h
	pop af
	ld hl,0d4e0h
	dec a
	jr z,l90f8h
	ld hl,0d520h
l90f8h:
	ld de,00244h
	ld a,(0d000h)
	cp 005h
	jr z,l9105h
	ld de,0094ch
l9105h:
	ld a,d
	call sub_9112h
	ld a,e
	call sub_9112h
	ld a,d
	call sub_9112h
	ld a,e
sub_9112h:
	ld b,010h
l9114h:
	ld (hl),a
	inc hl
	djnz l9114h
	ret
sub_9119h:
	ld ix,l9146h
	ld b,004h
l911fh:
	push bc
	push hl
	ld a,(hl)
l9122h:
	dec a
	ld (de),a
	inc hl
	inc de
	ld a,(ix+000h)
	add a,(hl)
	ld (de),a
	inc hl
	inc de
	ld c,(ix+001h)
	ld a,(0d000h)
	cp 005h
	ld a,c
	jr z,l913ah
	add a,008h
l913ah:
	ld (de),a
	inc de
	inc de
	inc ix
	inc ix
	pop hl
	pop bc
	djnz l911fh
	ret
l9146h:
	nop
	ret nc
	nop
	call nc,0d010h
	djnz l9122h
; --- door_anim_tick (0x914E) - door-open animation driver (0xC5AC) ----------
;  0xC5AC is the door sub-state.  door_load_coords arms it to 0xFF (vertical
;  door: blit the closed graphic via door_blit_tiles) or 0x04 (courtyard).
;  door_begin_open sets 0xFF again to start the OPEN sequence.  Here:
;   0xC5AC == 0xFF -> jp door_blit_tiles (C5AC:=1, paint 6 tiles at Y,X)
;   0xC5AC   != 3  -> nothing to do yet
;  When == 3, 0xC5AD=Y / 0xC5AE=X give the door position; +3 is a frame
;  counter that advances each call, blitting opening frames via 0x494D
;  until it reaches 0x2C, then latches "open" (state stays 3 at l916fh).
door_anim_tick:
	ld hl,0c5ach
	ld a,(hl)
	inc a
	jp z,door_blit_tiles   ; 0xFF -> blit door graphic, C5AC:=1
	cp 003h
	ret nz                 ; only animate in the "open" state
	inc l
	ld e,(hl)              ; E = door Y (0xC5AD)
	inc l
	ld d,(hl)              ; D = door X (0xC5AE)
	inc l
	inc (hl)               ; advance the opening-frame counter (+3)
	ld a,(hl)
	cp 02ch
	jr nc,l916fh           ; done animating
	ld h,d
	ld l,e
	inc l
	ld bc,0082fh
	ld a,000h
	jp vdp_hmmm              ; blit the next open frame
l916fh:
	ld a,003h
	ld (0c5ach),a          ; hold "open" state
	ret
door_begin_open:
	ld hl,0c5ach
	ld a,(hl)
	dec a
	ret nz                 ; only when 0xC5AC == 1 (door armed)
	ld (hl),0ffh           ; -> 0xFF: begin opening
	jp door_anim_tick
; --- l9180h - spawn a special object (vendor) into a 0xC5B5/0xC5C5 slot -----
;  On entry HL = object map position, B = subtype, C = slot/variant.  sub_91a9h
;  classifies the subtype (via table 0x5B12) and returns the target slot in A
;  (1 -> 0xC5B5, else -> 0xC5C5), or NZ to reject.  The 16-byte struct is filled:
;    +0 = 1 (active)   +1/+2 = E,D (position)   +4 = B (subtype)   +5 = C (slot)
;    +7/+8 = 0xC70D (the position latched on entry).
;  This is NOT the white-key door; door coords live at 0xC5AD/0xC5AE from door_tbl.
l9180h:
	ld (0c70dh),hl
	call sub_91a9h
	ret nz
	ld hl,0c5b5h
	dec a
	jr nz,l9190h
	ld hl,0c5c5h
l9190h:
	ld (hl),001h           ; +0 = active
	inc l
	ld (hl),e              ; +1 = pos lo
	inc l
	ld (hl),d              ; +2 = pos hi
	inc l
	ld (hl),000h
	inc l
	ld (hl),b              ; +4 = subtype
	inc l
	ld (hl),c              ; +5 = slot/variant
	inc l
	ld (hl),000h
	inc l
	ld de,(0c70dh)
	ld (hl),d              ; +7 = latched pos hi
	inc l
	ld (hl),e              ; +8 = latched pos lo
	ret
sub_91a9h:
	ld a,b
	exx
	ld hl,05b12h
	call ADD_HL_A
	ld c,(hl)
	ld b,002h
l91b4h:
	push bc
	ld a,002h
	sub b
	call sub_9456h
	ld a,(hl)
	pop bc
	cp c
	jr z,l91c2h
	djnz l91b4h
l91c2h:
	ld a,b
	exx
	ret
vendor_tick:                       ; (seg2 0x91C5) 2 x C5B5/C5C5 vendor slots
	ld hl,0c5b5h
	ld bc,00200h
l91cbh:
	push bc
	push hl
	push hl
	pop ix
	ld a,(hl)
	or a
	call nz,sub_91dfh
	pop hl
	ld a,010h
	add a,l
	ld l,a
	pop bc
	inc c
	djnz l91cbh
	ret
sub_91dfh:
	inc l
	ld e,(hl)
	inc l
	ld d,(hl)
	dec l
	dec l
	and 00fh
	dec a
	jr z,l91f1h
	dec a
	jr z,l91f9h
	dec a
	jr z,l9230h
	ret
l91f1h:
	ld (ix+009h),c
	ld (hl),082h
	jp l9253h
l91f9h:
	inc l
	inc l
	inc l
	ld a,(hl)
	or a
	ret z
	ld (hl),000h
	inc l
	ld b,(hl)
	inc l
	ld c,(hl)
	inc l
	cp 0ffh
	jr z,l921ch
	call sub_9228h
	res 7,(hl)
	inc (hl)
	call vendor_pick_outcome
l9213h:
	ld (ix+00ah),020h
	ld (ix+000h),003h
	ret
l921ch:
	ld a,006h
	ld (0c70ch),a
	ld a,003h
	ld (0c70bh),a
	jr l9213h
sub_9228h:
	ld a,(ix+009h)
	call sub_9456h
	inc hl
	ret
l9230h:
	dec (ix+00ah)
	ld a,(ix+00ah)
	push af
	rra
	ld a,002h
	jr c,l923fh
	ld a,(0c70bh)
l923fh:
	push de
	call sub_9265h
	pop de
	pop af
	ret nz
	ld a,(0c70bh)
	call sub_9265h
	ld (ix+000h),082h
	jp vendor_outcome_dispatch
l9253h:
	push de
	ld hl,0e580h
	call l875eh
	pop de
	call sub_9228h
	bit 7,(hl)
	jr z,l9263h
	dec (hl)
l9263h:
	ld a,003h
sub_9265h:
	rrca
	rrca
	rrca
	ld h,a
	ld l,0a0h
	ld a,048h
	ld bc,02020h
	jp vdp_lmmm
sub_9273h:
	ld hl,0c5b5h
	ld bc,00200h
l9279h:
	push bc
	push hl
	push hl
	pop ix
	ld a,(hl)
	or a
	call nz,sub_928dh
	pop hl
	ld a,010h
	add a,l
	ld l,a
	pop bc
	inc c
	djnz l9279h
	ret
sub_928dh:
	inc l
	ld e,(hl)
	inc l
	ld d,(hl)
	jp l9263h
sub_9294h:
	ld hl,0c5b5h
	ld b,002h
l9299h:
	push hl
	ld a,(hl)
	or a
	jr z,l92a6h
	add a,a
	jr nc,l92a6h
	inc l
	inc l
	inc l
	ld (hl),0ffh
l92a6h:
	pop hl
	ld a,010h
	add a,l
	ld l,a
	djnz l9299h
	ret
; --- vendor_outcome_dispatch (0x92AE) -----------------------------------------
; Execute the vendor's reaction to a whip hit, selected by state byte 0xC70C.
; DISPATCH_A jumps through the inlined word table that follows, indexed by 0xC70C:
;   0 -> 0x932E  register the hit (0xC40C=0xFF, latch vendor id -> 0xC703)
;   1 -> 0x933A  bump vendor "mood" 0xD012 up   (cap 3)
;   2 -> 0x9343  bump vendor "mood" 0xD012 down (floor 0)
;   3 -> 0x934B  GIVE +5 hearts   (add_hearts, sfx 0x0F)
;   4 -> 0x9355  TAKE -5 hearts   (spend_hearts, sfx 0x1D)
;   5 -> 0x934A  do NOTHING       (points at a bare `ret`)
;   6 -> 0x935F  LEAVE / vanish   (sfx 0x10, then awards +5000 via jp add_score_c0)
; This is why whipping the vendor sometimes gives hearts, sometimes takes them,
; sometimes does nothing, and eventually makes him leave.
vendor_outcome_dispatch:
	ld a,(0c70ch)
	call DISPATCH_A
vendor_outcome_tbl:
	defw vendor_hit_latch    ; 0  C40C=FF, latch vendor id
	defw vendor_mood_up      ; 1  D012++ (cap 3)
	defw vendor_mood_down    ; 2  D012-- (floor 0)
	defw vendor_give_hearts  ; 3  +5 hearts
	defw vendor_take_hearts  ; 4  -5 hearts
	defw vendor_noop         ; 5  ret (mood_down's ret)
	defw vendor_leave        ; 6  vanish, +5000
; --- vendor_pick_outcome (0x92C2) ---------------------------------------------
; Advance the vendor state machine to the next outcome after a whip hit.
; vendor_transition_tbl is a table of 8-byte rows; the row is chosen by ix+005 (vendor variant/
; phase), then indexed by the previous action (clamped to 0..7) to read the next
; state -> 0xC70C.  For "random" states >= 7 the low nibble of the R (refresh)
; register is used as a coin-flip to pick between two candidate states, which is
; the source of the run-to-run variation the player observes.  Finally the state
; is mapped through vendor_state_action_tbl (0x9327) into the reaction id 0xC70B.
vendor_pick_outcome:
	ld de,vendor_transition_tbl            ; vendor_transition_tbl (8-byte rows per ix+5)
	ld a,(ix+005h)
	add a,a
	add a,a
	add a,a
	call ADD_DE_A
	ld a,(hl)
	dec a
	cp 008h
	jr c,l92d6h
	ld a,007h
l92d6h:
	call ADD_DE_A
	ld a,(de)
	ld (0c70ch),a
	sub 007h
	jr c,l92f9h            ; states 0..6: use directly
	; states 7/8/9: coin-flip between two candidates via R register (RNG)
	ld hl,00305h
	jr z,l92efh
	dec a
	ld hl,00405h
	jr z,l92efh
	ld hl,00304h
l92efh:
	ld a,r
	rra
	ld a,h
	jr c,l92f6h
	ld a,l
l92f6h:
	ld (0c70ch),a
l92f9h:
	ld a,(0c70ch)
	ld hl,vendor_state_action_tbl
	call ADD_HL_A
	ld a,(hl)
	ld (0c70bh),a
	ret
; vendor_transition_tbl: 4 x 8-byte rows, values 0..9 (>=7 are RNG coin-flips)
vendor_transition_tbl:
	defb 000h,007h,007h,007h,008h,008h,005h,006h
	defb 000h,003h,003h,001h,005h,005h,005h,006h
	defb 009h,009h,000h,005h,005h,005h,002h,006h
	defb 005h,005h,005h,005h,000h,003h,005h,006h
vendor_state_action_tbl:       ; (0x9327) state -> reaction id 0xC70B
	defb 001h,004h,004h,000h,000h,003h,003h
vendor_hit_latch:              ; (0x932E) register that the vendor was hit
	ld a,0ffh
	ld (0c40ch),a
	ld a,(ix+009h)
	ld (0c703h),a          ; latch vendor object id
	ret
vendor_mood_up:                ; (0x933A) raise D012 (cap 3)
	ld hl,0d012h
	ld a,(hl)
	cp 003h
	ret z
	inc (hl)
	ret
vendor_mood_down:              ; (0x9343) lower D012 (floor 0)
	ld hl,0d012h
	ld a,(hl)
	or a
	ret z
	dec (hl)
vendor_noop:                   ; (0x934A) outcome 5: do nothing
	ret
vendor_give_hearts:            ; (0x934B) +5 hearts (sfx 0x0F)
	ld a,00fh
	call play_sound
	ld b,005h
	jp add_hearts
vendor_take_hearts:            ; (0x9355) -5 hearts (sfx 0x1D)
	ld a,01dh
	call play_sound
	ld b,005h
	jp spend_hearts
; vendor_leave (0x935F): erase sprite, sfx 0x10, then +5000 (jp add_score_c0).
vendor_leave:
	ld (ix+000h),000h
	call sub_937fh
	ld hl,0e580h
	call sub_88a3h
	ld h,(ix+007h)
	ld l,(ix+008h)
	ld (hl),000h
	ld a,010h
	call play_sound
	ld de,05000h
	jp add_score_c0        ; add_score += 5000 (departure bonus)
sub_937fh:
	ld e,(ix+001h)
	ld d,(ix+002h)
	ld c,(ix+009h)
	ld hl,0e580h
	jp l8868h
; --- vendor_make_offer (0x938E) -----------------------------------------------
; Arm a sale: pick the item + price (vendor_set_offer_item -> 0xC708 item, 0xC707 price),
; start the 0xC706 offer countdown (0x14 = 20 ticks), play the "offer" jingle
; (sfx 0x19) and draw the price/item bubble (l939eh).  Called from the resident
; vendor state machine (seg0 l4411h) while seg2 is paged in.
vendor_make_offer:
	call vendor_set_offer_item
	ld a,014h
	ld (0c706h),a          ; offer timer = 0x14; decremented in vendor_purchase_tick
	ld a,019h
	call play_sound
	jp l939eh
l939eh:
	ld a,(0c703h)
	ld hl,0c5b5h
	add a,a
	add a,a
	add a,a
	add a,a
	call ADD_HL_A
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,d
	cp 080h
	jr nc,l93b8h
	sub 010h
	jr l93bah
l93b8h:
	sub 020h
l93bah:
	ld h,a
	ld a,e
	sub 018h
	ld l,a
	ld (0c704h),hl
	ld de,0b080h
	ld bc,05020h
	ld a,004h
	push hl
	push bc
	call vdp_hmmm
	pop bc
	pop hl
	call 05d15h
	ld bc,03806h
	call sub_94b6h
	ld hl,01314h
	ex de,hl
	ld c,00eh
	call 048e3h
l93e3h:
	ld bc,00804h
	ld hl,l948ch
	call sub_94a6h
	ld bc,00810h
	ld hl,l9491h
	call sub_94a6h
	call sub_9498h
	ld bc,03908h
	call sub_94b6h
	ld a,(0c708h)
	dec a
	call sub_8cc8h
	ret
; --- vendor_set_offer_item (0x9406) -------------------------------------------
; Choose the item to sell (-> 0xC708) then look up its price in the price table.
vendor_set_offer_item:
	call sub_9453h
	ld a,(hl)
	ld (0c708h),a          ; offered item = bonus id (e.g. 0x1B = knife)
	inc hl
	set 7,(hl)
	ld hl,vendor_price_tbl            ; vendor_price_tbl (9 rows of 4: id,normal,half,double)
	ld b,009h
l9415h:
	cp (hl)
	inc hl
	jr z,vendor_select_price
	inc hl
	inc hl
	inc hl
	djnz l9415h
	ret
; vendor_select_price: high bits of 0xC702 (bible flags) pick the price variant.
;   no bible  -> +1 normal price     (knife = 0x50 = 50 hearts, BCD)
;   bit7 set  -> +2 halved  (white bible)   (knife = 0x30 = 30)
;   bit6 set  -> +3 doubled (black bible)    (knife = 0x90 = 90)
vendor_select_price:
	ld a,(0c702h)          ; bible price-modifier flags
	add a,a
	jr c,l9429h
	add a,a
	jr nc,l942ah
	inc hl
l9429h:
	inc hl
l942ah:
	ld a,(hl)
	ld (0c707h),a          ; price in hearts (BCD)
	ret
; vendor_price_tbl: 9 x { item id, normal, halved(white bible), doubled(black bible) }
vendor_price_tbl:
	defb 00eh,020h,015h,060h  ; candle
	defb 012h,030h,020h,060h  ; staff
	defb 003h,020h,010h,060h  ; red shield
	defb 004h,020h,010h,080h  ; yellow shield
	defb 00ah,040h,020h,080h  ; hourglass
	defb 016h,040h,015h,080h  ; potion
	defb 01eh,030h,010h,050h  ; holy water
	defb 01dh,020h,010h,080h  ; cross
	defb 01bh,050h,030h,090h  ; knife
sub_9453h:
	ld a,(0c703h)
sub_9456h:
	push af
	ld bc,CHKRAM
	ld a,(0d000h)
	or a
l945eh:
	jr z,l9468h
	dec a
	ld hl,l947ah
	call ADD_HL_A
	ld c,(hl)
l9468h:
	ld hl,0de00h
	add hl,bc
	ld a,(0d001h)
	add a,a
	add a,a
	call ADD_HL_A
	pop af
	or a
	ret z
	inc hl
	inc hl
	ret
l947ah:
	nop
	ld b,b
	add a,b
	nop
	ld b,b
	add a,b
	nop
	ld b,b
	add a,b
	nop
	ld b,b
	add a,b
	nop
	ld b,b
	add a,b
	nop
	ld b,b
	add a,b
l948ch:
	ccf
	dec sp
	nop
	ld c,h
	rst 38h
l9491h:
	ld d,b
	ld c,l
	nop
	nop
	ld c,(hl)
	ld c,a
	rst 38h
sub_9498h:
	ld bc,01810h
l949bh:
	call sub_94b6h
	ld hl,0c707h
	ld b,001h
	jp 0457fh
sub_94a6h:
	call sub_94b6h
l94a9h:
	ld a,(hl)
	inc a
	ret z
	dec a
	call 04aeeh
	call 04b56h
	inc hl
	jr l94a9h
sub_94b6h:
	ld de,(0c704h)
	ld a,d
	add a,b
	ld d,a
	ld a,e
	add a,c
	ld e,a
	ret
; --- vendor_purchase_tick (0x94C1) --------------------------------------------
; Runs while an offer is on screen.  Every 0x20 frames tick down the 0xC706 offer
; timer; when it hits 0 the offer is withdrawn (vendor_offer_withdraw).  Otherwise poll the
; buy/refuse buttons: nothing pressed -> keep waiting (ret 0xFF, vendor_offer_pending); SHIFT/
; refuse -> withdraw (vendor_offer_withdraw, sfx 0x02); SPACE/confirm -> buy only if Simon has
; enough hearts (0xC417 >= price 0xC707): deduct price (spend_hearts) and grant
; the item (collect_bonus / collect_bonus_apply), sfx 0x12.
vendor_purchase_tick:
	ld a,(0c003h)
	and 01fh
	jr nz,l94ceh
	ld hl,0c706h           ; offer countdown
	dec (hl)
	jr z,vendor_offer_withdraw            ; expired -> withdraw offer
l94ceh:
	call vendor_read_buttons         ; read confirm/refuse buttons (edge-detected)
	jr z,vendor_offer_pending            ; nothing pressed -> keep offer open
	rra
	jr nc,vendor_offer_withdraw           ; refuse (SHIFT / no confirm bit) -> withdraw
	ld a,(0c707h)
	ld b,a
	ld a,(0c417h)          ; Simon's hearts
	cp b
	jr c,vendor_offer_withdraw            ; can't afford -> withdraw
	ld a,(0c704h)
	cp 020h
	push af
	call c,sub_9514h
	call spend_hearts      ; pay the price in hearts
	ld a,(0c708h)
	call collect_bonus_apply         ; collect_bonus(item) -> give the purchased item
	pop af
	call c,l939eh
	ld a,012h
	call play_sound            ; purchase-confirmed jingle
	call sub_9453h
	inc hl
	res 7,(hl)
	xor a
	ret
vendor_offer_withdraw:                        ; offer declined / expired / unaffordable
	ld a,002h
	call play_sound
	xor a
	ret
vendor_offer_pending:                        ; no button this frame -> leave offer pending
	ld a,0ffh
	or a
	ret
	call sub_9514h
	jp sub_870eh
sub_9514h:
	push bc
	ld hl,0b080h
	ld de,(0c704h)
	ld bc,05020h
	ld a,001h
	call vdp_hmmm
	pop bc
	ret
; --- vendor_read_buttons (0x9526) ---------------------------------------------
; Build a "newly pressed" bitmask of the confirm/refuse controls and return it.
; Reads the two joystick triggers (PSG reg 0x0E bits 0x30) plus keyboard SPACE
; (row 8) and SHIFT (row 6) via SNSMAT.  0xC709 holds last frame's state so the
; final `xor c / and (hl)` yields only the freshly-pressed edges.  In
; vendor_purchase_tick bit0 (SPACE/trigger) = confirm/buy, the others = refuse.
vendor_read_buttons:
	ld e,08fh
	ld a,00fh
	call WRTPSG
	ld a,00eh
	di
	call RDPSG              ; PSG port B = joystick
	ei
	cpl
	and 030h               ; two fire buttons
	rrca
	rrca
	rrca
	rrca
	ld d,a
	ld a,006h
	call read_kbd_matrix_bit          ; keyboard row 6 -> SHIFT (refuse)
	add a,a
	or d
	ld d,a
	ld a,008h
	call read_kbd_matrix_bit          ; keyboard row 8 -> SPACE (confirm)
	or d
	ld hl,0c709h            ; previous button state (for edge detection)
	ld c,(hl)
	ld (hl),a
	xor c
	and (hl)
	ret
read_kbd_matrix_bit:                     ; read one keyboard-matrix bit (row in A) -> 0/1
	call SNSMAT
	cpl
	and 001h
	ret
; --- minimap_driver (0x9559) - the F2 "world map" feature.  Called every frame;
;     0xCF38 is the map-screen state (0 = playing, 1 = build, 2 = displayed).
;     The map item (picked up in-stage) sets 0xC701 bit7 and 0xC70F = 3 uses;
;     each F2 press while displayed<->hidden consumes one use.  F-key edges come
;     from 0xC00B (bit1 = F2 just pressed; see seg0 read_fkeys 0x4BFB).
minimap_driver:
	ld a,(0c002h)          ; input-enable flags...
	and 040h               ; ...bit6 = input allowed?
	ret z
	ld a,(0ce00h)          ; suppress while a transition/cutscene is active
	and a
	ret nz
	ld a,(0cf38h)          ; map-screen state
	dec a
	jr z,l95afh            ; state 1 -> build the map (draw every room cell)
	dec a
	jr z,l95bah            ; state 2 -> displayed: wait for F2 to close it
	ld a,(0c00bh)          ; state 0 (playing): F-key edges
	bit 1,a                ; F2 just pressed?
	ret z
	ld a,(0c701h)          ; inventory flags...
	add a,a               ; ...bit7 -> carry = map item held?
	ret nc                 ; no map item -> ignore F2
	ld hl,0c70fh           ; remaining map uses (seeded to 3 on pickup)
	ld a,(hl)
	and a
	ret z                  ; none left -> ignore
	dec (hl)               ; spend one use
	jr nz,l9589h
	ld hl,0c701h           ; last use spent...
	res 7,(hl)             ; ...clear the map-held flag
	call hud_bonus_refresh
l9589h:
	call 04805h            ; switch to the map screen (VDP page/setup)
	ld hl,DCOMPR
	ld bc,QINLIN
	xor a
	ld d,000h
	call 04911h
	ld hl,01830h
	ld bc,0d07eh
	ld a,033h
	ld d,000h
	call 04911h
	ld a,019h
	call play_sound
l95aah:
	ld hl,0cf38h           ; advance map-screen state (0->1->2)
	inc (hl)
	ret
l95afh:                    ; state 1: build the map, then advance to "displayed"
	call minimap_build         ; draw every room's cell (loops over all rooms)
	call sub_981ch
	call sub_985ah
	jr l95aah
l95bah:                    ; state 2 (displayed): F2 again closes the map
	ld a,(0c00bh)
	bit 1,a                ; F2 pressed?
	ret z
	call 04f98h            ; restore the play screen and resume
	call sub_902eh
	call door_begin_open
	call sub_9273h
	call sub_870eh
	call 04810h
	xor a
	ld (0cf38h),a          ; back to state 0 (playing)
	ret
; --- minimap_build - build the whole minimap: loop room index 0xCFFD = 0..N-1,
;     drawing each room's cell.  minimap_room_pos places the cell; the loop ends when the
;     index reaches the per-stage room count in minimap_room_count (minimap_room_count[stage]).
minimap_build:
	xor a
	ld (0cffdh),a          ; room index = 0
l95dbh:
	call sub_9610h
	call minimap_room_pos         ; look up + set this room's minimap cell position
	call sub_979ah
	call sub_980eh
	ld a,(0cffdh)
	inc a
	ld (0cffdh),a          ; ++room index
	ld c,a
	ld a,(0d000h)          ; stage
	ld hl,minimap_room_count           ; minimap_room_count[stage]
	call ADD_HL_A
	ld a,c
	cp (hl)
	jr nz,l95dbh           ; loop until all rooms drawn
	ret
; minimap_room_count (seg2 0x95FD): rooms per stage 0..18.
minimap_room_count:
	defb 003h,008h,006h,006h,006h,006h,006h,009h,008h
	defb 009h,009h,006h,00ch,00ch,008h,00ah,00ah,00ch,00ah
sub_9610h:
	ld hl,0e800h
	ld a,(0d000h)
	ld b,a
	ld a,(0cffdh)
	ld c,a
	call 04fb6h
	ld a,(0cffdh)
	call 05bd9h
	ld de,0eb00h
	call 05b28h
	ld ix,0eb00h
	ld a,(0d001h)
	ld hl,0cffdh
	cp (hl)
	jr nz,l963bh
	ld ix,0c470h
l963bh:
	ld b,008h
l963dh:
	ld a,(ix+000h)
	and a
	jr z,l964bh
	ld a,(ix+004h)
	cp 003h
	call z,sub_9653h
l964bh:
	ld de,CHRGTR
	add ix,de
	djnz l963dh
	ret
sub_9653h:
	ld a,(ix+001h)
	sub 010h
	ld h,(ix+002h)
	rra
	rra
	rra
	rra
	rr h
	rra
	rr h
	rra
	rr h
	ld l,h
	and 003h
	add a,0e8h
	ld h,a
	ld c,004h
l966fh:
	ld a,001h
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	ld a,01dh
	call ADD_HL_A
	dec c
	jr nz,l966fh
	ret
; --- minimap_room_pos - MINIMAP ROOM POSITION LOOKUP.  This is the authoritative room
;     geography: rooms are placed on the F2 map at HAND-AUTHORED cells, not derived
;     from the room-connectivity graph (which is a navigation graph with wrap/portal
;     edges).  Per stage 0xD000, minimap_stage_ptr[stage] points to an array of one-byte POSITION
;     CODES (one per room 0xCFFD); minimap_coord_tbl (0x975E) maps a code to a packed
;     screen coord (high byte X = 0x20+0x20*col over 6 columns, low byte Y = 0x38+
;     0x15*row over 5 rows).  Result stored at 0xCFF2 = this room's draw position.
;     Decoded for all 19 stages by tools/roomperm.py (its layout() reads this table).
minimap_room_pos:
	ld a,(0d000h)          ; stage
	ld de,minimap_stage_ptr           ; minimap_stage_ptr[]
	call lookup_word_tbl   ; de = this stage's position-code array
	ld a,(0cffdh)          ; room index
	call ADD_DE_A
	ld a,(de)              ; a = room's position code
	ld de,0975eh           ; minimap_coord_tbl
	call lookup_word_tbl   ; de = packed (X,Y) screen coord for that code
	ld (0cff2h),de         ; store as this room's minimap draw position
	ret
; minimap_stage_ptr: word[stage] -> per-room position-code array (see minimap_room_pos).
; z80dasm shows the following as instructions; it is DATA and never executed.
minimap_stage_ptr:
	jp nz,0c596h
	sub (hl)
	call 0d396h
	sub (hl)
	exx
	sub (hl)
	rst 18h
	sub (hl)
	push hl
	sub (hl)
	ex de,hl
	sub (hl)
	call p,0fc96h
	sub (hl)
	dec b
	sub a
	ld c,097h
	inc d
	sub a
	jr nz,$-103
	inc l
	sub a
	inc (hl)
	sub a
	ld a,097h
	ld c,b
	sub a
	ld d,h
	sub a
	dec c
	ld c,00fh
	dec c
	ld c,00fh
	djnz l96d1h
	ex af,af'
	add hl,bc
	ld a,(bc)
	ld c,00fh
	ex af,af'
	add hl,bc
l96d1h:
	inc d
	dec d
	rlca
	ex af,af'
	add hl,bc
	ld a,(bc)
	dec c
	ld c,00dh
	ld c,00fh
	rlca
	ex af,af'
	add hl,bc
	rrca
	ld c,00dh
	add hl,bc
	ex af,af'
	rlca
	rrca
l96e6h:
	ld c,00dh
	add hl,bc
	ex af,af'
	rlca
	dec d
	inc d
	inc de
	rrca
	ld c,00dh
	add hl,bc
	ex af,af'
	rlca
	inc c
	dec c
	ld c,00fh
	djnz l9702h
	add hl,bc
	ld a,(bc)
	inc c
	dec c
	ld c,00fh
	djnz $+19
l9702h:
	dec bc
	ld d,017h
	inc c
	dec c
	ld c,00fh
	djnz l971ch
	rlca
	ex af,af'
	dec bc
	inc c
	dec c
	ld c,00fh
	djnz $+19
	rlca
	ex af,af'
	add hl,bc
	dec c
	ld c,00fh
	djnz l9730h
l971ch:
	dec d
l971dh:
	add hl,de
	ld a,(de)
	dec de
	rlca
	ex af,af'
	add hl,bc
	ld bc,00302h
	inc b
	rrca
	inc d
	dec d
l972ah:
	ld d,01ch
	djnz l973dh
	ld c,00ah
l9730h:
	add hl,bc
	ex af,af'
	rlca
	ld b,015h
	inc d
	rrca
	ld c,009h
	ex af,af'
	inc b
	inc bc
	ld (bc),a
l973dh:
	ld bc,00a0bh
	add hl,bc
	ex af,af'
	rlca
	ld b,011h
	djnz l9756h
	ld c,016h
	dec d
	inc d
	djnz l975ch
	ld c,008h
	rlca
	ld b,002h
	ld bc,01c00h
	dec de
l9756h:
	ld a,(de)
	inc d
	rrca
	ld c,009h
	inc bc
l975ch:
	ld (bc),a
	ld bc,02038h
	jr c,$+66
	jr c,l97c4h
	jr c,l96e6h
	jr c,$-94
	jr c,l972ah
	ld c,l
	jr nz,$+79
	ld b,b
	ld c,l
	ld h,b
	ld c,l
	add a,b
	ld c,l
	and b
	ld c,l
	ret nz
	ld h,d
	jr nz,$+100
	ld b,b
	ld h,d
	ld h,b
	ld h,d
	add a,b
	ld h,d
	and b
	ld h,d
	ret nz
	ld (hl),a
	jr nz,l97fch
	ld b,b
	ld (hl),a
	ld h,b
	ld (hl),a
	add a,b
	ld (hl),a
	and b
	ld (hl),a
	ret nz
	adc a,h
	jr nz,l971dh
	ld b,b
	adc a,h
	ld h,b
	adc a,h
	add a,b
	adc a,h
	and b
	adc a,h
	ret nz
sub_979ah:
	ld de,0e840h
	ld hl,0eb00h
	ld bc,002c0h
l97a3h:
	call sub_97b5h
	call sub_9801h
	bit 0,c
	jr z,l97aeh
	inc hl
l97aeh:
	inc de
	dec bc
	ld a,c
	or b
	jr nz,l97a3h
	ret
sub_97b5h:
	ld a,(de)
	exx
	cp 00eh
	jr nc,l97d7h
	ld hl,l97f3h
	ld e,a
	ld d,000h
	add hl,de
	ld a,(hl)
	ld c,a
l97c4h:
	dec a
	jp m,l97d7h
	jr z,l97dah
	dec a
	jr z,l97deh
	ld a,(0d002h)
	cp 005h
	jr z,l97e9h
	and a
	jr z,l97e2h
l97d7h:
	xor a
	exx
	ret
l97dah:
	ld a,00eh
	exx
	ret
l97deh:
	ld a,00eh
	exx
	ret
l97e2h:
	ld a,c
	cp 003h
	jr z,l97dah
	jr l97d7h
l97e9h:
	ld a,c
	sub 003h
	jr z,l97dah
	dec a
	jr z,l97dah
	jr l97d7h
l97f3h:
	nop
	ld bc,00201h
	ld (bc),a
	inc b
	inc b
	inc b
	inc b
l97fch:
	inc bc
	ld bc,00201h
	ld (bc),a
sub_9801h:
	bit 0,c
	jr z,l9808h
	or (hl)
	ld (hl),a
	ret
l9808h:
	add a,a
	add a,a
	add a,a
	add a,a
	ld (hl),a
	ret
sub_980eh:
	ld de,(0cff2h)
	ld hl,0eb00h
	ld bc,02016h
	xor a
	jp 04991h
sub_981ch:
	ld a,(0d001h)
	ld (0cffdh),a
	call minimap_room_pos
	ld hl,(0cff2h)
	ld a,(0c425h)
	sub 040h
	call c,sub_984bh
	rra
	rra
	rra
	and 01fh
	add a,l
	ld e,a
	ld a,(0c427h)
	rra
	rra
	rra
	and 01fh
	add a,h
	ld d,a
	ld bc,00404h
	ld hl,l9852h
	xor a
	jp 04991h
sub_984bh:
	ex af,af'
	ld a,l
	sub 020h
	ld l,a
	ex af,af'
	ret
l9852h:
	ex af,af'
	add a,b
	adc a,b
	adc a,b
	adc a,b
	adc a,b
	ex af,af'
	add a,b
sub_985ah:
	ld a,(0d000h)
	ld c,a
	add a,a
	add a,c
	ld hl,l98b3h
	call ADD_HL_A
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	bit 0,(hl)
	ld hl,l987bh
	jr z,l9874h
	ld hl,l9897h
l9874h:
	ld bc,00807h
	xor a
	jp 04991h
l987bh:
	nop
	ex af,af'
	nop
	nop
	nop
	ex af,af'
	add a,b
	nop
	adc a,b
	adc a,b
	adc a,b
	nop
	adc a,b
	adc a,b
	adc a,b
	add a,b
	adc a,b
	adc a,b
	adc a,b
	nop
	nop
	ex af,af'
	add a,b
	nop
	nop
	ex af,af'
	nop
	nop
l9897h:
	nop
	nop
	add a,b
	nop
	nop
	ex af,af'
	add a,b
	nop
	nop
	adc a,b
	adc a,b
	adc a,b
	ex af,af'
	adc a,b
	adc a,b
	adc a,b
	nop
	adc a,b
	adc a,b
	adc a,b
	nop
	ex af,af'
	add a,b
	nop
	nop
	nop
	add a,b
	nop
l98b3h:
	ld l,h
	sub d
	nop
	ld c,(hl)
	or h
	nop
	ld h,e
	sub h
	nop
	ld l,(hl)
	ld d,h
	nop
	ld c,(hl)
	ld b,l
	ld bc,04352h
	ld bc,06552h
	ld bc,sub_9453h+1
	nop
	ld d,b
	or h
	nop
	add a,d
	jp 05801h
	call nc,06d00h
	call nc,06d00h
	sub h
	nop
	add a,d
	ld h,e
	ld bc,02458h
	ld bc,06543h
	ld bc,02550h
	ld bc,0253ah
	ld bc,06543h
	defb 001h
actors_tick:                       ; (seg2 0x98EC) room_spawner + C800 if D010==0
	ld a,(0d010h)
	and a                  ; 0==normal play
	call z,room_spawner    ; per-frame enemy spawner (seg0 0x5EBF), skipped mid-transition
c800_tick:                         ; (seg2 0x98F3) tick all 7 C800 actor slots
	ld ix,0c800h
	ld b,007h
l98f9h:
	ld a,(ix+000h)
	and a
	jr z,l990fh
	push bc
	call sub_9936h
	jr c,l990bh
	call actor_type_tick
	call actor_integrate
l990bh:
	call actor_cull_offscreen
	pop bc
l990fh:
	ld de,00080h
	add ix,de
	djnz l98f9h
	ret
shot_sat_build:                    ; (seg2 0x9917) shot shape streams -> actor SAT
	ld ix,0d700h
	ld b,008h
	jr l9925h
c800_sat_build:                    ; (seg2 0x991F) C800 shape streams -> actor SAT
	ld ix,0c800h
	ld b,007h
l9925h:
	push bc
	ld a,(ix+000h)
	and a
	call nz,actor_sat_build
	ld de,00080h
	add ix,de
	pop bc
	djnz l9925h
	ret
sub_9936h:
	ld a,(0d010h)
	and a
	ret z
	ld a,(ix+07eh)
	and a
	ret z
	scf
	ret
; actor_type_tick (seg2 0x9942) - per-frame C800 tick. DISPATCH_A on type-1.
; Separate from spawn-time entity_tbl: most entries are a later instruction of
; the same enemy_*_tick (skip spawn pose / splash / fly-in). Types 0x17 and
; 0x1D are `ret` (no per-frame work). 0x1F shares type 4; 0x21 shares 2/3;
; 0x23 shares type 13 (hunchback).
actor_type_tick:
	ld a,(ix+000h)
	dec a
	call DISPATCH_A
actor_tick_tbl:
	defw enemy_zombie_go    ; 1
	defw merman_go          ; 2
	defw merman_go          ; 3  merman_red
	defw hanging_bat_go     ; 4  past fly-in
	defw enemy_dog_go       ; 5
	defw enemy_pikeman_go   ; 6
	defw enemy_flying_skull_go ; 7
	defw enemy_ghost_head_go ; 8
	defw enemy_red_skeleton_go ; 9
	defw enemy_skull_pile_go ; 10
	defw white_skel_go      ; 11
	defw enemy_raven_go     ; 12
	defw hunchback_go       ; 13
	defw enemy_bone_dragon_go ; 14
	defw enemy_roc_go       ; 15
	defw enemy_axe_knight_go ; 16
	defw enemy_dracula_go   ; 17
	defw enemy_giant_bat_go ; 18
	defw enemy_medusa_go    ; 19
	defw enemy_mummy_go     ; 20
	defw enemy_frankenstein_go ; 21
	defw enemy_grim_reaper_go ; 22
	defw tick_nop           ; 23 ret (no SAT; actor_sat_build skips 0x17)
	defw igor_go            ; 24
	defw enemy_blob_go      ; 25 type 0x19 (same tick; not in hatch table)
	defw enemy_blob_go      ; 26 actor_blob_blue
	defw enemy_blob_go      ; 27 actor_blob_red
	defw enemy_blob_go      ; 28 actor_blob_white
	defw tick_nop_seg2      ; 29 ret
	defw flame_tick         ; 30 actor_flame
	defw hanging_bat_go     ; 31 placed_bat
	defw merman_splash_go   ; 32
	defw merman_go          ; 33 placed_merman
	defw actor_orb_go       ; 34
	defw hunchback_go       ; 35 roc_drop
	defw actor_pickup_go    ; 36
	defb 0a5h,099h,025h,09ch,0bah,04eh,000h,04fh
	defb 000h,04fh,03ch,04fh,0a5h,099h,0a3h,06ah
	defb 019h,0adh,074h,068h
tick_nop_seg2:
	ret
actors_rearm_hittable:         ; (0x99A6) if actor +0E bit2, set bit0 (C800 then shots)
	ld de,00080h
	ld hl,0c80eh
	ld b,007h
	call sub_99b6h
	ld hl,0d70eh
	ld b,008h
sub_99b6h:
	bit 2,(hl)
	jr z,l99bch
	set 0,(hl)
l99bch:
	add hl,de
	djnz sub_99b6h
	ret
; ---------------------------------------------------------------------------
;  actor_integrate (seg2 0x99C0) - advance one actor by its velocity.  Skips
;  dead slots (+0x06 == 0).  Adds the 16-bit Y velocity (+0x07/+0x08) to the Y
;  position (+0x02/+0x03) and the X velocity (+0x09/+0x0A) to the X position
;  (+0x04/+0x05).  This is the physics step paired with the velocity helpers in
;  seg3 (actor_set_xvel / actor_set_yvel / actor_add_*).
; ---------------------------------------------------------------------------
actor_integrate:
	ld a,(ix+006h)
	and a
	ret z                   ; slot dead -> nothing to do
	ld e,(ix+007h)          ; DE = Y velocity
	ld d,(ix+008h)
	ld l,(ix+002h)          ; HL = Y position
	ld h,(ix+003h)
	add hl,de               ; Ypos += Yvel
	ld (ix+002h),l
	ld (ix+003h),h
	ld e,(ix+009h)          ; DE = X velocity
	ld d,(ix+00ah)
	ld l,(ix+004h)          ; HL = X position
	ld h,(ix+005h)
	add hl,de               ; Xpos += Xvel
	ld (ix+004h),l
	ld (ix+005h),h
	ret

; ---------------------------------------------------------------------------
;  actor_cull_offscreen (seg2 0x99EC) - free the actor if its pixel position has
;  left the play area: Y (+0x03) >= 0xE4, or X (+0x05) >= 0xF1 or < 0x07.
;  Falls through into actor_free.
; ---------------------------------------------------------------------------
actor_cull_offscreen:
	ld a,(ix+003h)
	cp 0e4h
	jr nc,actor_free        ; Y off the bottom
	ld a,(ix+005h)
	cp 0f1h
	jr nc,actor_free        ; X off the right
	cp 007h
	ret nc
; actor_free (seg2 0x99FD) - clear the actor slot (+0x00 type, +0x0E) and, if it
; owns a linked sub-slot (flagged at +0x25), release that too.
actor_free:
	xor a
	ld (ix+000h),a
	ld (ix+00eh),a
	push ix
	pop hl
	set 5,l
	ld c,(hl)
	ld a,c
	and a
	ret z
	inc l
l9a0eh:
	ld a,(hl)
	ld de,0d638h
	add a,a
	add a,a
	add a,e
	ld e,a
	ld a,0e0h
	ld (de),a
	ld a,l
	add a,005h
	ld l,a
	dec c
	jr nz,l9a0eh
	ret
sub_9a21h:
	call actor_free
	ld c,(ix+003h)
	ld b,(ix+005h)
	ld hl,CHKRAM
	ld e,l
	ld d,h
	ld a,0ffh
	push ix
	call shot_spawn
	ld (ix+01fh),000h
	ld (ix+07eh),000h
	pop ix
	ret
	ld a,001h
	jr l9a46h
sub_9a45h:
	xor a
l9a46h:
	ld (0cfffh),a
	push ix
	call sub_9a51h
	pop ix
	ret
sub_9a51h:
	call sub_9a72h
	ret c
	call actor_free
	call sub_9ac5h
	ret c
	call sub_9b29h
sub_9a5fh:
	ld c,actor_flame
	push ix
	push bc
	call spawn_actor
	pop bc
	ld (ix+01fh),b
	pop ix
	ld hl,0ce08h
	inc (hl)
	ret
sub_9a72h:
	ld a,(ix+000h)
	ld (0cff0h),a
	cp 022h
	jp z,l9a94h
	cp 024h
	jr z,l9a9eh
	cp 026h
	jr z,l9a99h
	cp 011h
	jp z,l9aaah
	cp 009h
	jr z,l9ab0h
	cp 018h
	jr z,l9abah
	xor a
	ret
l9a94h:
	call actor_free
	scf
	ret
l9a99h:
	ld a,(ix+01fh)
	jr l9aa0h
l9a9eh:
	ld a,001h
l9aa0h:
	push af
	call actor_free
	pop af
	call collect_bonus      ; type 0x24 heart touched in mid-air -> +1 heart
	scf
	ret
l9aaah:
	ld (ix+001h),008h
	scf
	ret
l9ab0h:
	ld a,(0cfffh)
	and a
	ret nz
	call 0b04fh
	scf
	ret
l9abah:
	ld a,(0ce0bh)
	and a
	ret nz
	ld (ix+010h),008h
	scf
	ret
sub_9ac5h:
	ld b,000h
	ld a,(0ce00h)
	and a
	ret nz
	ld a,(0cff0h)
	cp 00eh
	jr z,l9afah
	ld a,(0cfffh)
	and a
	ret nz
	ld a,(ix+01fh)
	ld c,a
	and a
	jp nz,l9b1ah
	ld hl,0cf40h
	inc (hl)
	ld a,(hl)
	and 01fh
	ld c,013h
	jp z,l9b1ah
	ld a,r
	and 03fh
	ld c,002h
	jr z,l9b1ah
	and 003h
	ret nz
	ld b,001h
	ret
l9afah:
	ld e,(ix+003h)
	ld d,(ix+005h)
	ld b,004h
l9b02h:
	push bc
	push de
	ld b,001h
	ld a,(0cfffh)
	and a
	jr z,l9b0dh
	dec b
l9b0dh:
	call sub_9a5fh
	pop de
	pop bc
	ld a,d
	add a,010h
	ld d,a
	djnz l9b02h
	scf
	ret
l9b1ah:
	push bc
	call sub_9b29h
	ld c,026h
	call spawn_actor
	pop bc
	ld (ix+01fh),c
	scf
	ret
sub_9b29h:
	ld a,(0cff0h)
	ld hl,l9b3ah
	call ADD_HL_A
	ld a,(ix+003h)
	sub (hl)
	ld e,a
	ld d,(ix+005h)
l9b3ah:
	ret
	djnz l9b4dh
	djnz l9b3fh
l9b3fh:
	nop
	djnz l9b42h
l9b42h:
	nop
	djnz l9b55h
	djnz l9b47h
l9b47h:
	nop
	nop
	jr l9b5bh
	jr nz,l9b65h
l9b4dh:
	jr flame_init
	jr $+26
	nop
	nop
	nop
	nop
l9b55h:
	nop
	nop
	nop
	nop
	nop
	nop
l9b5bh:
	djnz l9b5dh
l9b5dh:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
l9b65h:
	nop
	nop
; ---------------------------------------------------------------------------
;  flame_init (seg2 0x9B67) - initialise a "destruction flame" effect actor
;  (the flame that whipped objects/enemies turn into before vanishing).
;  Seeds the flame sprite frame and its lifetime countdown.
; ---------------------------------------------------------------------------
flame_init:
	ld (ix+00bh),085h       ; +0x0B anim frame = flame sprite 0x85
	ld (ix+00ch),010h       ; +0x0C lifetime timer = 0x10
	ld (ix+00eh),000h       ; +0x0E = 0
	ld (ix+07eh),000h       ; +0x7E = 0
	ret

; ---------------------------------------------------------------------------
;  flame_tick (seg2 0x9B78) - per-frame update of the destruction flame.  It
;  flickers the flame sprite (0x85 <-> 0x86 on bit 2 of the countdown) while the
;  lifetime timer (+0x0C) runs down.  When it expires, if the drop gate (+0x1F)
;  is set it spawns the settled pickup actor (type 0x24) at the flame's position
;  - runtime-confirmed as the candle -> flame -> small-heart(0x24) chain.
; ---------------------------------------------------------------------------
flame_tick:
	ld a,(ix+000h)
	ld (0cff0h),a           ; stash actor type in scratch 0xCFF0
	ld a,(ix+00ch)          ; A = lifetime timer
	and 004h                ; bit 2 -> flicker phase
	ld c,085h               ; flame frame 0x85
	jr z,l9b88h
	inc c                   ; ...or 0x86 (the flicker/undulation)
l9b88h:
	ld (ix+00bh),c          ; +0x0B anim frame = flame sprite
	dec (ix+00ch)           ; lifetime timer--
	ret nz                  ; keep burning until it hits 0
	call actor_free             ; flame expired: free/finalise the slot
	ld a,(ix+01fh)
	and a
	ret z                   ; +0x1F drop gate clear -> no pickup
	ld c,actor_pickup       ; drop = settled pickup at the flame spot
	ld e,(ix+003h)          ; DE = flame position (+0x03 / +0x05)
	ld d,(ix+005h)
	jp spawn_actor          ; spawn the settled pickup at that spot
	ld (ix+00eh),002h
	ld (ix+00ch),001h
	ld (ix+006h),001h
	ld de,00080h
	call actor_set_yvel
	ld de,00200h
	call actor_set_xvel
	ld (ix+011h),0ffh
	ld (ix+010h),0e0h
	ld (ix+00bh),000h
	ld (ix+07eh),000h
	ret
	ld (ix+00ch),014h
	ld (ix+006h),000h
	ld (ix+00eh),002h
	ld (ix+00bh),001h
	ld (ix+07eh),000h
	ret
actor_pickup_go:
	call sub_9c64h
	jr c,l9c0ah
	inc (ix+00ch)
	ld e,(ix+010h)
	ld d,(ix+011h)
	call actor_add_xvel
	ld a,(ix+00ch)
	sub 020h
	ret nz
	ld (ix+00ch),a
	ld e,(ix+010h)
	ld d,(ix+011h)
	call neg_de
	ld (ix+010h),e
	ld (ix+011h),d
	ret
l9c0ah:
	call actor_free
	ld b,001h
	ld hl,00410h
l9c12h:
	ld a,(ix+003h)
	sub l
	and 0f8h
	ld e,a
	ld a,(ix+005h)
	sub h
	add a,004h
	and 0f8h
	ld d,a
	jp drop_spawn
	ld hl,l9c60h
	ld a,(0c003h)
	and 003h
	call ADD_HL_A
	ld a,(hl)
	ld (ix+025h),a
	ld a,(ix+001h)
	and a
	jr nz,l9c4dh
	dec (ix+00ch)
	ret nz
	inc (ix+001h)
	ld de,CHKRAM
	call actor_set_xvel
	ld de,00800h
	jp actor_set_yvel
l9c4dh:
	ld (ix+006h),001h
	call sub_9c64h
	ret nc
	call actor_free
	ld b,(ix+01fh)
	ld hl,00810h
	jr l9c12h
l9c60h:
	ex af,af'
	ld bc,SCALXY
sub_9c64h:
	ld e,(ix+003h)
	ld d,(ix+005h)
	jp map_solid_pair
	ld (ix+00eh),000h
	ld c,00eh
	ld a,(0d000h)
	cp 00ah
	jr nz,l9c80h
	ld c,015h
	ld (ix+025h),00bh
l9c80h:
	ld (ix+00bh),c
	ld (ix+00ch),01eh
	ld (ix+006h),001h
	ld (ix+07eh),000h
	ld hl,0cf30h
	inc (hl)
	ld a,(hl)
	ld hl,0fb00h
	ld de,00100h
	rra
	jr c,l9ca3h
	ld de,0ff00h
	ld hl,0fa00h
l9ca3h:
	call actor_set_xvel
	ex de,hl
	jp actor_set_yvel
merman_splash_go:
	ld de,00080h
	jp actor_add_yvel
	ld hl,0cf00h
	ld de,l9cc2h
	ld b,007h
l9cb8h:
	ld a,(de)
	ld (hl),a
	inc de
	inc l
	ld (hl),000h
	inc l
	djnz l9cb8h
	ret
l9cc2h:
	inc b
	inc b
	inc b
	ex af,af'
	ex af,af'
	ex af,af'
	ex af,af'
	ex af,af'
spawn_rate_gate:
	exx
	ld hl,0cf10h
	dec (hl)
	ld a,(hl)
	exx
	and 003h
	ret nz
	dec (hl)
	ret nz
	inc l
	ld a,(hl)
	inc (hl)
	dec l
	and 007h
	call ADD_DE_A
	ld a,(0d012h)
	add a,a
	ld c,a
	ld a,(de)
	sub c
	jr nc,l9ce9h
	xor a
l9ce9h:
	inc a
	ld (hl),a
	xor a
	ret
; --- zombie_generator (0x9ced) - continuous zombie spawner (room_spawner bit0) -
;  Rate-gated by spawn_rate_gate (0xCF00 counter, threshold table l9d4ah scaled by the
;  0xD012 difficulty/mood).  When it fires, spawn_pick_pos picks the spawn position
;  (hardcoded per stage/room - NOT read from the tile map), then spawns
;  actor_zombie.  Typical: X = 0xF0 (right edge) or 0x10 (left), Y = 0xC0.
zombie_generator:
	ld hl,0cf00h
	ld de,l9d4ah
	call spawn_rate_gate         ; time to spawn?
	ret nz
	call spawn_pick_pos         ; DE = spawn position (D=X, E=Y)
	call sub_9e1dh
	ret c                  ; bail if the slot area / cap says no
	ld c,actor_zombie
	jp spawn_actor
; --- spawn_pick_pos - pick a ground-enemy spawn position by stage/room -------------
;  Out: D = X, E = Y.  D flips 0xF0 <-> 0x10 = right/left edge by a per-actor
;  flag.  Reads stage 0xD000 (L) and room 0xD001 (H).  Tile map is not consulted.
spawn_pick_pos:
	ld a,(0c425h)          ; Simon Y (used by some stage branches)
	ld c,a
	ld hl,(0d000h)         ; L = stage (0xD000), H = room (0xD001)
	ld a,l
	dec a
	jr z,l9d2fh            ; stage 1
	dec a
	jr z,l9d22h
	dec a
	jr z,l9d1eh
	cp 008h
	jr z,l9d1ah
	jr l9d33h
l9d1ah:
	ld e,0b0h
	jr l9d24h
l9d1eh:
	ld e,0c0h
	jr l9d24h
l9d22h:
	ld e,0a0h
l9d24h:
	ld d,0f0h
	ld a,(0cf01h)
	bit 1,a
	ret z
	ld d,010h
	ret
l9d2fh:
	ld a,h
	dec a
	jr z,l9d3fh
l9d33h:
	ld e,0c0h
l9d35h:
	ld d,0f0h
	ld a,(0c42ch)
	and a
	ret z
	ld d,010h
	ret
l9d3fh:
	ld e,0c0h
	ld a,c
	cp 088h
	jr nc,l9d35h
	ld de,0f060h
	ret
l9d4ah:                        ; zombie spawn-rate thresholds (8 bytes)
	defb 00ch,012h,00ch,00ch,00ch,012h,00ch,00ch
merman_generator:           ; (0x9D52) bit1, actor_merman_green (1 HP)
	ld hl,0cf02h
	ld c,actor_merman_green
	jr merman_spawn
merman_generator_3:         ; (0x9D59) bit2, actor_merman_red (spit, 2 HP)
	ld hl,0cf02h
	ld c,actor_merman_red
merman_spawn:
	ld de,l9d96h
	push bc
	call spawn_rate_gate
	pop bc
	ret nz
	ld e,0c8h              ; Y = 0xC8
	ld a,(0cf03h)
	and 007h
	ld hl,l9d8eh           ; X picks
	call ADD_HL_A
	ld d,(hl)
	ld a,(0c427h)          ; skip if Simon X is within 0x18 of spawn X
	sub d
	add a,018h
	cp 030h
	jp nc,spawn_actor
	ld a,d
	ld d,020h
	cp 080h
	jr c,l9d89h
	ld d,0e0h
l9d89h:
	add a,d
	ld d,a
	jp spawn_actor
l9d8eh:                        ; merman spawn X candidates
	defb 060h,0d0h,030h,090h,0a0h,040h,060h,0b0h
l9d96h:                        ; merman spawn-rate thresholds
	defb 001h,018h,018h,018h,018h,018h,018h,018h
hanging_bat_generator:         ; (0x9D9E) bit3, actor_hanging_bat
	ld hl,0cf06h
	ld de,l9dc2h
	ld c,actor_hanging_bat
flyer_spawn:                   ; bats / ghosts / medusa heads: edge X, Y=SimonY-8
	push bc
	call spawn_rate_gate
	pop bc
	ret nz
	inc hl
	ld a,(hl)
	rr a
	ld d,0f0h              ; X = right edge
	jr c,l9db6h
	ld d,010h              ; X = left edge
l9db6h:
	call sub_9e1dh
	ld a,(0c425h)
	sub 008h
	ld e,a                 ; Y = Simon Y - 8
	jp spawn_actor
l9dc2h:                        ; bat spawn-rate thresholds
	defb 014h,014h,014h,028h,014h,014h,014h,028h
flying_skull_generator:        ; (0x9DCA) bit4, actor_flying_skull
	ld hl,0cf08h
	ld de,l9dd4h
	ld c,actor_flying_skull
	jr flyer_spawn
l9dd4h:                        ; ghost spawn-rate thresholds
	defb 01ch,01ch,01ch,048h,01ch,01ch,01ch,048h
ghost_head_generator:          ; (0x9DDC) bit5, actor_ghost_head
	ld hl,0cf0ah
	ld de,l9de6h
	ld c,actor_ghost_head
	jr flyer_spawn
l9de6h:                        ; medusa-head spawn-rate thresholds
	defb 00ch,00ch,00ch,018h,00ch,00ch,00ch,018h
roc_generator:                 ; (0x9DEE) bit6, actor_roc
	ld hl,0cf0ch
	ld de,l9e15h
	call spawn_rate_gate
	ret nz
	ld a,(0c427h)
	cp 0c0h
	jr c,l9e05h
	ld a,001h
	ld (0cf0ch),a          ; Simon already on the right -> don't spawn
	ret
l9e05h:
	ld de,0e030h           ; X=0xE0 Y=0x30
	ld a,(0cf0dh)
	rra
	jr c,l9e10h
	ld e,040h              ; or Y=0x40
l9e10h:
	ld c,actor_roc
	jp spawn_actor
l9e15h:                        ; skull-cannon spawn-rate thresholds
	defb 018h,018h,018h,018h,018h,018h,018h,018h
sub_9e1dh:
	ld a,(0c427h)
	cp 0c0h
	jr nc,l9e30h
	cp 040h
	jr c,l9e29h
	ret
l9e29h:
	ld a,d
	cp 040h
	ret nc
	ld d,0f0h
l9e2fh:
	ret
l9e30h:
	ld a,d
l9e31h:
	cp 0c0h
l9e33h:
	ccf
	ret nc
l9e35h:
	ld d,010h
	ret
shot_tick:                         ; (seg2 0x9E38) 8 shot slots at 0xD700
	ld ix,0d700h
	ld b,008h
l9e3eh:
	ld a,(ix+000h)
	and a
	jr z,l9e57h
	push bc
	call sub_9936h
	jr c,l9e50h
	call shot_type_tick
	call actor_integrate
l9e50h:
	call actor_sat_build
	call actor_cull_offscreen
	pop bc
l9e57h:
	ld de,00080h
	add ix,de
	djnz l9e3eh
	ret
shot_type_tick:                ; (seg2 0x9E5F) shot per-type tick (type-1)
	ld a,(ix+000h)
	dec a
	call DISPATCH_A
	defw fireball          ; 1  merman, dragon, g-bat
	defw fireball          ; 2
	defw fireball          ; 3  skull-pile
	defw shot_bone    ; 4  white-skeleton bone (kind 11)
	defw fireball          ; 5  Dracula
	defw medusa_snake  ; 6  kind 0x13
	defw mummy_bandage   ; 7  kind 0x14
	defw shot_sickle       ; 8  grim sickle (kind 0x16)
	defw shot_axe          ; 9  axe knight (kind 16)
	defw fireball          ; 10 igor (kind 24)
	defw shot_nop          ; 11 unused
	defw flame_tick        ; 12 kind 0xFF (death flame from sub_9a21h)
; fireball (seg2 0x9E7E) - types 1-3, 5, 10. Shared sprite: pose 3, SAT
; pattern 0xF0 (shape 0xB5CF), colours 0/8 from shot_sat_ptr 0xA0EA.
; Pixels are gfx_rle_a185 at VRAM 0xFF80 (loaded with the HUD sprites).
; Tick is ret; actor_integrate coasts on spawn velocity.
fireball:
	ret
medusa_snake:             ; (0x9E7F) poses 0x27-0x2A, facing
	inc (ix+00ch)
	bit 1,(ix+00ch)
	ld a,027h
	jr z,l9e8bh
	inc a
l9e8bh:
	bit 7,(ix+00ah)
	jr nz,l9e93h
	add a,002h
l9e93h:
	ld (ix+00bh),a
	ret
mummy_bandage:            ; (0x9E97) seek stored Y (ix+10/11), poses 0x39/0x3A
	ld e,(ix+012h)
	ld d,(ix+013h)
	ld l,(ix+010h)
	ld h,(ix+011h)
	add hl,de
	ld (ix+010h),l
	ld (ix+011h),h
	ld a,(ix+00ch)
	inc (ix+00ch)
	and 004h
	ld c,039h
	jr z,l9eb7h
	inc c
l9eb7h:
	ld (ix+00bh),c
	ld de,CALLF
	ld a,(ix+003h)
	cp (ix+011h)
	jr c,l9ec8h
	ld de,0ffd0h
l9ec8h:
	jp actor_add_yvel
shot_nop:
	ret
shot_axe:                      ; (0x9ECC) poses 0x63-0x66; homing on thrower CFFC
	inc (ix+00ch)
	ld a,(ix+00ch)
	rra
	rra
	and 003h
	add a,063h
	ld (ix+00bh),a
	bit 7,(ix+010h)
	ld de,OUTDO
	jr nz,l9ee7h
	ld de,0ffe8h
l9ee7h:
	call actor_add_xvel
	ld a,(ix+013h)
	and a
	jr z,l9ef4h
	dec (ix+013h)
	ret
l9ef4h:
	ld l,(ix+011h)
	ld h,(ix+012h)
	ld a,(hl)
	cp 010h
	ret nz
	ld a,005h
	add a,l
	ld l,a
	ld a,(hl)
	sub (ix+005h)
	add a,010h
	cp 020h
	ret nc
	jp actor_free
; shot_bone (seg2 0x9F0E) - shot type 4, the white skeleton's bone.
; 4-frame spin (shapes 0x4B-0x4E, packed after the skeleton walk 0x47-0x4A)
; plus gravity 0x50/frame. Spawned by shot_throw with kind 11.
shot_bone:
	ld a,(ix+00ch)
	inc a
	cp 00ch                ; 12-step timer -> 4 poses x 3 frames
	jr c,l9f17h
	xor a
l9f17h:
	ld (ix+00ch),a
	rra
	rra
	and 003h
	add a,04bh             ; pose 0x4B / 4C / 4D / 4E
	ld (ix+00bh),a
	ld de,SETRD            ; +0x50/frame (SETRD equ 0x50, not the BIOS entry)
	jp actor_add_yvel
shot_sickle:                   ; (0x9F29) poses 0x7D-0x80; windup then fly 0x1E
	ld a,(ix+00ch)
	rra
	rra
	and 003h
	add a,07dh
	ld (ix+00bh),a
	ld a,(ix+001h)
	dec a
	jr z,l9f53h
	dec (ix+00ch)
	ret nz
	ld a,040h
	call 0a0eeh
	call actor_set_xvel
	ex de,hl
	call actor_set_yvel
	ld (ix+00ch),01eh
	inc (ix+001h)
	ret
l9f53h:
	dec (ix+00ch)
	ret nz
	ld de,CHKRAM
	call actor_set_xvel
	call actor_set_yvel
	ld (ix+00ch),03ch
	ld (ix+001h),e
	ret
; shot_throw (seg2 0x9F68) - spawn a shot from the current actor.
; Kind = ix+0 (via shot_kind_type -> shot type). Pos = (X, Y-16). Yvel HL, Xvel DE.
; White skeleton (type 11) -> shot type 4 (shot_bone). Axe (16) -> type 9.
shot_throw:
	ld a,(ix+003h)
	sub 010h               ; spawn 16 px above the actor
	ld c,a
	ld b,(ix+005h)         ; B = actor X
	ld a,(ix+000h)         ; A = actor type as kind
; shot_spawn (seg2 0x9F74) - A=kind, BC=pos, HL=yvel, DE=xvel. Allocates a
; shot slot. Kind 0xFF is type 12 (flame); else type = shot_kind_type[kind].
shot_spawn:
	ld (0cff9h),a          ; kind
	ld (0cff1h),bc         ; pixel pos
	ld (0cff5h),hl         ; Y velocity
	ld (0cff7h),de         ; X velocity
	push ix
	call shot_alloc
	pop ix
	ret
shot_alloc:                    ; (seg2 0x9F8A) find a free shot slot and arm it
	ld a,(0cff9h)
	cp 0ffh
	ld c,00ch              ; kind 0xFF -> shot type 12 (flame_tick)
	jr z,l9f9ah
	ld hl,shot_kind_type   ; kind -> shot type; [11]=4 bone, [16]=9 axe
	call ADD_HL_A
	ld c,(hl)
l9f9ah:
	ld a,c
	ld (0cff0h),a
	ld hl,0d700h
	ld b,008h
	xor a
	ld de,00080h
l9fa7h:
	cp (hl)
	jr z,l9faeh
	add hl,de
	djnz l9fa7h
	ret
l9faeh:
	push hl
	pop ix
	ld (0cff3h),hl
	ld c,002h
	ld (ix+020h),c
	ld (ix+07fh),001h
	ld (ix+07eh),001h
	ld de,01100h
	ld hl,0d67ch
	ld b,008h
	ld a,(0ce03h)
	and a
	jr z,l9fd1h
	ld b,002h
l9fd1h:
	ld a,(hl)
	cp 0e0h
	jr nz,l9fdfh
	ld (hl),0e1h
	call 0604fh
	inc e
	dec c
	jr z,l9fe7h
l9fdfh:
	dec d
	dec l
	dec l
	dec l
	dec l
	djnz l9fd1h
	ret
l9fe7h:
	ld hl,(0cff3h)
	ld a,(0cff0h)
	ld (hl),a
	inc l
	ld (hl),000h
	ld de,(0cff1h)
	inc l
	ld (hl),000h
	inc l
	ld (hl),e
	inc l
	ld (hl),000h
	inc l
	ld (hl),d
	inc l

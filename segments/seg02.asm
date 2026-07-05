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
	call sub_82abh
	pop bc
	jr c,l8053h
l8047h:
	ld de,00080h
	add ix,de
	djnz l8034h
	ret
l804fh:
	ld bc,00204h
	ld (bc),a
l8053h:
	ld a,00ch
	call 050a6h
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
	call sub_81b2h
	call sub_9a45h
l807fh:
	ld a,(iy+001h)
	cp 002h
	push iy
	pop hl
	jp z,074f3h
	res 0,(ix+00eh)
	ret
l808fh:
	ld a,(ix+000h)
	cp 012h
	jr nz,l809ch
	ld a,(0ce00h)
	and a
	jr z,l8061h
l809ch:
	call 07e33h
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
	call z,074f3h
l80d6h:
	ld a,00ch
	jp 050a6h
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
	call sub_83a8h
	pop hl
	jr c,l8119h
l8104h:
	push hl
	call sub_83bah
	pop hl
	ret nc
	ld a,(iy+001h)
	cp 002h
	jr nz,l8119h
	push hl
	push iy
	pop hl
	call 074f3h
	pop hl
l8119h:
	inc l
	inc l
	inc l
	inc (hl)
	ld a,00ch
	jp 050a6h
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
	call sub_83a3h
	pop hl
	jr c,l8160h
l8151h:
	push hl
	call sub_83b5h
	pop hl
	jr nc,l816ah
	push hl
	push iy
	pop hl
	call 074f3h
	pop hl
l8160h:
	inc l
	inc l
	inc l
	ld (hl),002h
	ld a,00ch
	call 050a6h
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
;   * If the shield is up (0xC701 bit 4): compare the hit direction (0xC427 Simon X
;     vs actor +0x05, and facing 0xC42C).  A blocked hit takes B as-is and spends a
;     shield charge (0xC441--; when it hits 0 the shield bit is cleared + sub_8eedh
;     removes its HUD).  An unblocked/backstab hit falls to the doubling path.
;   * Otherwise (no shield / not blocked): B is DOUBLED, so the real contact damage
;     = 2 * (l81d5h odd byte).  Runtime-confirmed: zombie(t01) odd 1 -> 2, dog(t05)
;     odd 3 -> 6 (0x1E->0x18).  Then jp damage_health (0xC415 -= B).
hurt_simon_contact:
	ld a,(ix+000h)
	dec a
	add a,a
	ld hl,l81d5h
	call ADD_HL_A
	inc hl                 ; -> odd byte = base contact damage for this type
	ld b,(hl)
	ld a,(0c701h)
	bit 4,a                ; shield active?
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
	res 4,(hl)             ; charges gone -> drop the shield
	push bc
	call sub_8eedh
	pop bc
l81afh:
	jp damage_health       ; 0xC415 -= B
; award_kill_score (seg2 0x81B2): give points for killing the actor in IX.
; Looks up the per-type hundreds value D from table l81d5h[(type-1)] (E=0 low pair),
; then picks the high pair C by type (0x11 -> 3, 0x17 -> 5, else 0) and calls
; add_score with C:D:E.
sub_81b2h:
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
; Confirmed in play: t01 zombie score 100 / dmg 2; t05 dog score 100 / dmg 6;
; t04 candle/destructible score 100 (matches the +100 candle whip).  Hearts/keys
; are pickups (collect_bonus), not kills, so they award 0 here.
l81d5h:
	ld bc,00201h
	ld (bc),a
	ld (bc),a
	ld (bc),a
	ld bc,00101h
	inc bc
	ld (bc),a
	ld (bc),a
	ld (bc),a
	ld bc,00202h
	ld (bc),a
	ld bc,00103h
	ld (bc),a
	ld bc,00101h
	ld (bc),a
	ld bc,00310h
	inc b
	ld (bc),a
	inc bc
	inc bc
	nop
	inc bc
	jr nz,l81fbh
	jr nz,l81fdh
l81fbh:
	jr nz,l81ffh
l81fdh:
	jr nc,l8202h
l81ffh:
	ld (hl),b
	inc bc
	nop
l8202h:
	nop
	ld (bc),a
	ld bc,00201h
	ld bc,UPC
	ld (bc),a
	ld bc,00002h
	nop
	nop
	nop
	ld bc,00001h
	nop
	ld (bc),a
	ld bc,CHKRAM
	ld (bc),a
	ld bc,CHKRAM
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	ld bc,00001h
	nop
	nop
	nop
	ld de,00100h
	jp 044f3h
	inc l
	ld a,(hl)
	add a,010h
	ld e,a
	inc l
	ld a,(hl)
	add a,008h
	ld d,a
	ld hl,01008h
	jp l8481h
	ld d,(ix+005h)
	ld e,(ix+004h)
	ld hl,01008h
	jp l8481h
	call sub_8302h
	call DISPATCH_A
	rra
	add a,e
	ccf
	add a,e
	ld e,a
	add a,e
	call sub_8302h
	call DISPATCH_A
	cpl
	add a,e
	ld c,a
	add a,e
	ld l,a
	add a,e
sub_826bh:
	call sub_8302h
	call DISPATCH_A
	scf
	add a,e
	ld d,a
	add a,e
	ld (hl),a
	add a,e
	call sub_8302h
	call DISPATCH_A
	daa
	add a,e
	ld b,a
	add a,e
	ld h,a
	add a,e
	call sub_82bfh
	call DISPATCH_A
	add a,a
	add a,e
	sbc a,a
	add a,e
	pop hl
	add a,e
	ld sp,hl
	add a,e
	ld de,02f84h
	add a,h
	ld b,a
	add a,h
	call sub_82bfh
	call DISPATCH_A
	ld a,a
	add a,e
	sub a
	add a,e
	exx
	add a,e
	pop af
	add a,e
	add hl,bc
	add a,h
	daa
	add a,h
	ccf
	add a,h
sub_82abh:
	call sub_82bfh
	call DISPATCH_A
	adc a,a
	add a,e
	or c
	add a,e
	jp (hl)
	add a,e
	ld bc,01c84h
	add a,h
	scf
	add a,h
	ld c,a
	add a,h
sub_82bfh:
	ld a,(ix+000h)
	dec a
	ld hl,l82d2h
	call ADD_HL_A
	ld a,(hl)
	dec a
	ld b,(ix+005h)
	ld c,(ix+003h)
	ret
l82d2h:
	ld bc,00101h
	ld (bc),a
	inc bc
	ld bc,00202h
	ld bc,00101h
	ld (bc),a
	ld (bc),a
	ld (bc),a
	inc b
	inc b
	dec b
	inc b
	inc b
	ld b,006h
	rlca
	ld (bc),a
	ld (bc),a
	ld (bc),a
	ld (bc),a
	ld (bc),a
	ld (bc),a
	ld bc,00201h
	ld bc,00201h
	ld (bc),a
	ld (bc),a
	ld bc,UPC
	ld bc,00101h
	ld bc,UPC
	ld bc,00101h
sub_8302h:
	ld a,(ix+000h)
	dec a
	ld hl,l8314h
	call ADD_HL_A
	ld a,(hl)
	ld b,(ix+005h)
	ld c,(ix+003h)
	ret
l8314h:
	nop
	nop
	nop
	ld (bc),a
	nop
	ld bc,00201h
	ld (bc),a
	nop
	ld (bc),a
	ld hl,00603h
	ld d,b
	ld e,c
	jp l8481h
	ld hl,00603h
	ld d,b
	ld e,c
	jp l84aeh
	ld hl,00603h
	ld d,b
	ld e,c
	jp l84f7h
	ld hl,00603h
	ld d,b
	ld e,c
	jp l8652h
	ld hl,00606h
	ld d,b
	ld e,c
	jp l8481h
	ld hl,00606h
	ld d,b
	ld e,c
	jp l84aeh
	ld hl,00606h
	ld d,b
	ld e,c
	jp l84f7h
	ld hl,00606h
	ld d,b
	ld e,c
	jp l8652h
	ld hl,00c06h
	ld d,b
	ld e,c
	jp l8481h
	ld hl,00c06h
	ld d,b
	ld e,c
	jp l84aeh
	ld hl,00c06h
	ld d,b
	ld e,c
	jp l84f7h
	ld hl,00c06h
	ld d,b
	ld e,c
	jp l8652h
	ld hl,01805h
	ld d,b
	ld e,c
	jp l8481h
	ld hl,01805h
	ld d,b
	ld e,c
	jp l84aeh
	ld hl,01805h
	ld d,b
	ld e,c
	jp l84f7h
	ld hl,01008h
	ld d,b
	ld e,c
	jp l8481h
	ld d,b
	ld e,c
	jr l83abh
sub_83a3h:
	call sub_83ceh
	jr l83abh
sub_83a8h:
	call sub_83c3h
l83abh:
	ld hl,01008h
	jp l84aeh
	ld d,b
	ld e,c
	jr l83bdh
sub_83b5h:
	call sub_83ceh
	jr l83bdh
sub_83bah:
	call sub_83c3h
l83bdh:
	ld hl,01008h
	jp l84f7h
sub_83c3h:
	inc l
	ld a,(hl)
	add a,020h
	ld e,a
	inc l
	ld a,(hl)
	add a,010h
	ld d,a
	ret
sub_83ceh:
	inc l
	ld a,(hl)
	add a,010h
	ld e,a
	inc l
	ld a,(hl)
	add a,008h
	ld d,a
	ret
	ld hl,00a0ch
	ld d,b
	ld e,c
	jp l8481h
	ld hl,00a0ch
	ld d,b
	ld e,c
	jp l84aeh
	ld hl,00a0ch
	ld d,b
	ld e,c
	jp l84f7h
	ld hl,0180ch
	ld d,b
	ld e,c
	jp l8481h
	ld hl,0180ch
	ld d,b
	ld e,c
	jp l84aeh
	ld hl,0180ch
	ld d,b
	ld e,c
	jp l84f7h
	ld hl,03010h
	ld d,b
	ld e,c
	jp l8481h
	ld hl,01805h
	ld d,b
	ld a,c
	sub 020h
	ld e,a
	jp l84aeh
	ld hl,01805h
	ld d,b
	ld a,c
	sub 020h
	ld e,a
	jp l84f7h
	ld hl,02805h
	ld d,b
	ld e,c
	jp l8481h
	ld hl,02805h
	ld d,b
	ld e,c
	jp l84aeh
	ld hl,02805h
	ld d,b
	ld e,c
	jp l84f7h
	ld hl,03008h
	ld d,b
	ld e,c
	jp l8481h
	ld hl,03008h
	ld d,b
	ld e,c
	jp l84aeh
	ld hl,03008h
	ld d,b
	ld e,c
	jp l84f7h
	inc hl
	ld a,(hl)
	add a,010h
	ld e,a
	inc hl
	ld a,(hl)
	add a,008h
	ld d,a
	ld hl,01008h
	jp l84aeh
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
	jp l84f7h
l8481h:
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
l84aeh:
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
l84f7h:
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
	ld a,(0c5adh)
	sub 008h
	ld d,a
	ld a,b
	sub d
	cp 038h
	ret nc
	ld a,(0c5aeh)
	ld d,a
	ld a,c
	sub d
	cp 008h
	ret
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
	ld hl,0c5b1h
	ld a,(hl)
	and a
	ret z
	inc hl
	ld a,(hl)
	ld d,a
	ld a,(0c425h)
	sub 004h
	sub d
	cp 010h
	ret nc
	inc hl
	ld a,(hl)
	ld d,a
	ld a,(0c427h)
	sub d
	cp 010h
	ret
	ld a,(0c701h)
	and 020h
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
	call sub_826bh
	jr nc,l8649h
	call sub_9a21h
	ld a,00bh
	call 050a6h
	ld hl,0c441h
	dec (hl)
	jr nz,l8649h
	ld hl,0c701h
	res 5,(hl)
	call sub_8eedh
l8649h:
	pop bc
	ld de,00080h
	add ix,de
	djnz l8623h
	ret
l8652h:
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
;  brazier_tick (seg2 0x8693) - update one brazier/candle.  IX/HL -> object.
;  Advances the flame animation (+0x06) and, when the object has been hit
;  (+0x03 != 0), branches to brazier_destroyed to clear it and drop its item.
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
	ld a,(hl)               ; A = +0x04
	ex af,af'
	inc l
	inc l
	inc (hl)                ; +0x06 flame animation phase++
	ld a,b
	cp 001h
	jr nz,l86bah
	ex af,af'
	push af
	push de
	call sub_8741h
	pop de
	pop af
	cp 002h
	jp c,l86c2h
	jp l86d1h
l86bah:
	ld a,(hl)
	and 003h
	ret nz
	ex af,af'
	cp 002h
	ret nc
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
l86d1h:
	ld b,a
	ld a,(0d002h)
	or a
	ld hl,l8799h
	jr z,l86deh
	ld hl,l87adh
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
	call sub_8783h
	pop de
	call 07d36h
	pop de
	pop bc
	ex de,hl
	call sub_88beh
	pop hl
	pop de
	ld e,d
	ld a,(0c702h)
	rra
	ret nc
sub_8709h:
	ld c,00eh
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
sub_8741h:
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
sub_8783h:
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
	djnz sub_8783h
	ret
l8799h:
	ld bc,00902h
	dec bc
	ld bc,UPC
	ld (bc),a
	add hl,bc
	dec bc
	ld a,(bc)
	add hl,bc
	ld bc,UPC
	ld (bc),a
	add hl,bc
	dec bc
	ld a,(bc)
	add hl,bc
l87adh:
	ld bc,00a02h
	dec bc
	ld bc,UPC
	ld (bc),a
	ld a,(bc)
	dec bc
	ld a,(bc)
	dec bc
	ld bc,UPC
	ld (bc),a
	ld a,(bc)
	dec bc
	ld a,(bc)
	dec bc
; ---------------------------------------------------------------------------
;  brazier_destroyed (seg2 0x87C1) - a brazier/candle has been hit.  HL -> +0x03.
;  Clears the object (+0x03 = 0, +0x00 state = 0) and runs the item-drop logic;
;  +0x04 (A) selects the drop and +0x05 (B) its parameter.  Objects with a drop
;  spawn a flame at their spot (see flame_tick) which then yields the pickup.
; ---------------------------------------------------------------------------
brazier_destroyed:
	ld (hl),000h            ; +0x03 hit flag = 0
	inc l
	ld (ix+000h),000h       ; +0x00 state = 0 (object gone)
	ld a,(hl)               ; A = +0x04 (drop selector)
	inc l
	ld b,(hl)               ; B = +0x05 (drop parameter)
	cp 002h
	jp nc,l87d9h
	call sub_8851h
	call sub_887bh
	jp l8996h
l87d9h:
	push bc
	push de
	push bc
	ld c,a
	ld a,00eh
	call 050a6h
	ld a,c
	pop bc
	cp 002h
	jr z,l87f0h
	call sub_8865h
	call sub_88a0h
	jr l87f6h
l87f0h:
	call sub_8851h
	call sub_8884h
l87f6h:
	ld a,(ix+005h)
	cp 01fh
	jr z,l881bh
	cp 018h
	jr z,l8845h
	call sub_887bh
	pop de
	pop bc
	ld a,b
	or a
	jr z,l8818h
	ld a,(ix+004h)
	cp 003h
	jr nz,l8815h
	ld a,e
	add a,010h
	ld e,a
l8815h:
	call sub_89eah
l8818h:
	jp l88ceh
l881bh:
	pop de
	pop bc
	ld a,(ix+009h)
	ld b,a
	ld h,(ix+007h)
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
sub_8851h:
	ld hl,0e480h
sub_8854h:
	push bc
	push de
	ld a,c
	add a,a
	add a,a
	call ADD_HL_A
	ld bc,00202h
	call sub_8783h
	pop de
	pop bc
	ret
sub_8865h:
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
	call sub_8783h
	pop de
	pop bc
	ret
sub_887bh:
	ld h,(ix+007h)
	ld l,(ix+008h)
	ld (hl),000h
	ret
sub_8884h:
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
	call sub_88beh
	pop de
	pop bc
	ret
sub_88a0h:
	ld hl,0e4a0h
sub_88a3h:
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
	call sub_88beh
	pop de
	pop bc
	ret
sub_88beh:
	push bc
	ld b,000h
	push de
	ldir
	pop de
	pop bc
	ld a,020h
	call ADD_DE_A
	djnz sub_88beh
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
	ld a,005h
	ld l,070h
l8984h:
	add a,a
	add a,a
	add a,a
	add a,a
	ld h,a
	ld bc,01010h
	ld a,001h
	jp 0494dh
l8991h:
	ld l,070h
	jp l8cd2h
l8996h:
	call sub_8a30h
l8999h:
	ld a,b
	or a
	jr z,l89a5h
	cp 015h
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
	ld c,01eh
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
sub_89eah:
	ld a,b
	cp 015h
	jp z,l8999h
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
	ld b,019h
	call sub_89f7h
	pop bc
	ld a,l
	add a,008h
	ld l,a
	ld (hl),b
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
	call sub_8f5ch
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
	cp 015h
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
	ld a,(0d002h)
	or a
	ld b,a
	jr z,l8af4h
	ld a,b
	dec a
	and 007h
	ld hl,l8af7h
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
l8af7h:
	ld a,(de)
	inc e
	dec de
	dec de
	dec de
	dec de
	inc e
	inc e
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
	cp 019h
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
	ld a,(ix+00dh)
	ld (ix+004h),a
	call sub_8c36h
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
l8c4bh:
	ld (ix+003h),000h
	ld a,(ix+004h)
	cp 00ah
	jr nz,l8c5fh
	ld (ix+004h),00bh
	call sub_8cedh
	jr sub_8c36h
l8c5fh:
	cp 00bh
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
	jp 049e2h
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
	call sub_9175h
	call sub_870eh
	pop de
	pop ix
	ret
sub_8d30h:
	ld a,(ix+004h)
; ---------------------------------------------------------------------------
;  collect_bonus (seg2 0x8D33) - apply a picked-up bonus whose id is in A.
;  Entry sub_8d33h pushes the common tail 0x50A6; sub_8d37h is the bare entry
;  (caller supplies its own continuation).  Latches the bonus id into 0xC419
;  (last-pickup latch, drives the pickup HUD/message) then dispatches through the
;  25-entry word table at 0x8D45 (index = A-1; A>=0x1A falls through to l8d77h):
;    1 = small heart (+1), 2 = large heart (+5), health refills via restore_health
;    (+8 / +32), keys + sub-weapons OR their bit into 0xC701/0xC702, etc.
;  Reached from both pickup paths: the mid-air 0xC800 heart (type 0x24, via
;  sub_9a72h) and the settled 0xC500 pickup list.
; ---------------------------------------------------------------------------
collect_bonus:
	ld hl,050a6h
	push hl
sub_8d37h:
	ld (0c419h),a          ; latch last-collected bonus id
	call 08f2ah
	cp 01ah
	jr nc,l8d77h
	dec a
	call DISPATCH_A
	or (hl)
	adc a,l
	cp (hl)
	adc a,l
	sbc a,a
	adc a,l
	xor b
	adc a,l
	jp nz,0838dh
	adc a,l
	push hl
	adc a,l
	call nc,0ec8dh
	adc a,l
	sbc a,e
	adc a,l
	call m,0038dh
	adc a,(hl)
	ld a,(bc)
	adc a,(hl)
	dec e
	adc a,(hl)
	ld a,(0248eh)
	adc a,(hl)
	dec l
	adc a,(hl)
	add a,b
	adc a,(hl)
	ld c,c
	adc a,(hl)
	ld d,d
	adc a,(hl)
	dec de
	adc a,(hl)
	inc d
	adc a,(hl)
	ld d,a
	adc a,(hl)
	ld h,a
	adc a,(hl)
	dec de
	adc a,(hl)
; --- weapon pickup (bonus id >= 0x1A) ---------------------------------------
; index = id - 0x19; index 5 is special (l8d94h). Otherwise store the new weapon
; id in 0xC416, run sub_8ea1h, then FALL THROUGH into the rosary code below - so a
; weapon pickup also arms the 0xC440 no-spawn timer (brief pickup grace window).
l8d77h:
	sub 019h
	cp 005h
	jr z,l8d94h
	ld (0c416h),a          ; set equipped weapon id
	call sub_8ea1h
; --- collect_bonus[6] = Rosary (temporary "no new enemies" power-up) ---------
; Arms the enemy-spawn suppression timer 0xC440: while nonzero, room_spawner
; (seg0 0x5EBF) bails every frame and no new enemies spawn. Duration depends on
; 0xC431 bit 2: 0xF0 (240 frames ~4s) if set, else 0x96 (150 frames ~2.5s) - the
; likely difference between the two rosary types. 0xC440 counts down each frame in
; seg1 0x75C7. Effect is immediate/current-room; existing 0xC800 actors are kept.
	ld a,(0c431h)          ; power-up flag bit 2 selects the duration
	and 004h
	ld a,0f0h              ; -> 240-frame timer
	jr nz,l8d8eh
	ld a,096h              ; -> 150-frame timer
l8d8eh:
	ld (0c440h),a          ; arm the no-spawn timer
l8d91h:
	ld a,012h
	ret
l8d94h:
	ld b,008h
l8d96h:
	call sub_8e74h
	jr l8d91h
	ld b,040h
	jr l8d96h
	ld hl,0c701h
	res 5,(hl)
	ld b,010h
	jr l8dafh
	ld hl,0c701h
	res 4,(hl)
	ld b,020h
l8dafh:
	ld a,010h
	ld (0c441h),a
	jr l8d96h
	ld b,001h
l8db8h:
	call add_hearts         ; value 1 = small heart (+1); value 2 = large heart (+5)
	ld a,00fh
	ret
	ld b,005h
	jr l8db8h
	push ix
	call 0780dh
	pop ix
	call sub_9294h
	ld a,018h
	ld (0c43eh),a
	ld a,01bh
	ret
	ld a,(0c431h)
	and 004h
	ld a,0f0h
	jr nz,l8ddfh
	ld a,096h
l8ddfh:
	ld (0c43ah),a
	ld a,016h
	ret
	ld b,008h
	call restore_health
	jr l8e11h
	ld a,(0c431h)
	and 004h
	ld a,0f0h
	jr nz,l8df7h
	ld a,096h
l8df7h:
	ld (0c434h),a
	jr l8e11h
	ld hl,0c431h
	set 2,(hl)
	jr l8e11h
	ld hl,0c431h
	set 3,(hl)
	jr l8e11h
	ld hl,0c431h
	set 4,(hl)
	jr l8e11h
l8e11h:
	jp l8d91h
	ld b,020h
	call restore_health
	jr l8e11h
	pop hl
	ret
	call sub_8713h
	ld b,001h
	jr l8e34h
; bonus id 0x10 = BLACK BIBLE: set 0xC702 bit6 -> vendor price doubled
	ld hl,0c702h
	res 7,(hl)             ; drop the white-bible bit (mutually exclusive)
	ld b,040h              ; bit6 = black bible (double price)
	jr l8e34h
; bonus id 0x11 = WHITE BIBLE: set 0xC702 bit7 -> vendor price halved
	ld hl,0c702h
	res 6,(hl)             ; drop the black-bible bit (mutually exclusive)
	ld b,080h              ; bit7 = white bible (half price)
l8e34h:
	call sub_8e79h         ; 0xC702 |= B
	ld a,012h              ; pickup popup message id
	ret
	ld hl,0c431h
	set 6,(hl)
	ld a,003h
	ld (0c70fh),a
	ld b,080h
	jp l8d96h
	ld de,05000h
l8e4ch:
	call 044f3h
	ld a,010h
	ret
	ld de,01000h
	jr l8e4ch
	ld b,002h
	call sub_8e74h
	ld hl,0c700h
	ld (hl),001h
	call sub_8ed0h
	ld a,014h
	ret
	ld b,001h
	call sub_8e74h
	call sub_8ec1h
	ld a,014h
	ret
	pop hl
	ret
; OR bit-mask B into an inventory byte: sub_8e74h -> 0xC701, sub_8e79h -> 0xC702
sub_8e74h:
	ld hl,0c701h
	jr l8e7ch
sub_8e79h:
	ld hl,0c702h
l8e7ch:
	ld a,b
	or (hl)
	ld (hl),a
	ret
	ld hl,0c431h
	set 1,(hl)
	ld hl,0c701h
	res 1,(hl)
	ld b,004h
	call sub_8e74h
	ld a,003h
	ld (0c700h),a
	call sub_8ed0h
	ld a,00fh
	ret
	xor a
	ld (0c416h),a
	jp sub_8ea1h
sub_8ea1h:
	ld a,(0c416h)
	ld de,l800ch
	or a
	jp z,l8980h
	add a,019h
l8eadh:
	dec a
	ld l,050h
	cp 010h
	jr c,l8eb8h
	sub 010h
	ld l,060h
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
sub_8eedh:
	call sub_8f51h
	ld a,(0c701h)
	ld c,a
	ld b,005h
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
; 0xC5E6 timer; when it hits 0, tear the popup down (sub_8eedh).
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
	jp sub_8eedh
sub_8f6fh:
	push hl
	ld a,(ix+004h)
	cp 019h
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
	call 050a6h
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
l8fc4h:
	ld bc,03c60h
	nop
	nop
	dec bc
	ld bc,07c60h
	nop
	ld bc,0010ah
	ld h,b
	cp h
	ld bc,00b02h
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
	jp 0494dh
sub_902eh:
	call sub_8fa6h
	jp l8fd9h
	ld hl,0c598h
	ld a,(hl)
	or a
	ret nz
	ld hl,l9073h
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
l9073h:
	dec b
	ld bc,05f01h
	ld h,b
	ld bc,00540h
	inc b
	ld (bc),a
	ld e,a
	jr nz,$+3
	jr nc,l90e1h
	cp b
	rst 38h
	jr c,$+12
	nop
	ld bc,0608fh
	ld bc,00a60h
	ld (bc),a
	ld bc,040a7h
	ld bc,00a80h
	inc bc
	ld bc,0208fh
	ld bc,00aa0h
	inc b
	ld bc,080a7h
	ld bc,0ff40h
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
l914eh:
	ld hl,0c5ach
	ld a,(hl)
	inc a
	jp z,05403h
	cp 003h
	ret nz
	inc l
	ld e,(hl)
	inc l
	ld d,(hl)
	inc l
	inc (hl)
	ld a,(hl)
	cp 02ch
	jr nc,l916fh
	ld h,d
	ld l,e
	inc l
	ld bc,0082fh
	ld a,000h
	jp 0494dh
l916fh:
	ld a,003h
	ld (0c5ach),a
	ret
sub_9175h:
	ld hl,0c5ach
	ld a,(hl)
	dec a
	ret nz
	ld (hl),0ffh
	jp l914eh
l9180h:
	ld (0c70dh),hl
	call sub_91a9h
	ret nz
	ld hl,0c5b5h
	dec a
	jr nz,l9190h
	ld hl,0c5c5h
l9190h:
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
	ld (hl),c
	inc l
	ld (hl),000h
	inc l
	ld de,(0c70dh)
	ld (hl),d
	inc l
	ld (hl),e
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
	jp 049e2h
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
;   6 -> 0x935F  LEAVE / vanish   (sfx 0x10, then awards +5000 via jp 044f3h)
; This is why whipping the vendor sometimes gives hearts, sometimes takes them,
; sometimes does nothing, and eventually makes him leave.
vendor_outcome_dispatch:
	ld a,(0c70ch)
	call DISPATCH_A
	ld l,093h
	ld a,(04393h)
	sub e
	ld c,e
	sub e
	ld d,l
	sub e
	ld c,d
	sub e
	ld e,a
	sub e
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
	ld hl,09327h           ; vendor_state_action_tbl[state] -> reaction id 0xC70B
	call ADD_HL_A
	ld a,(hl)
	ld (0c70bh),a
	ret
; vendor_transition_tbl: 8-byte rows, values 0..9 (>=7 are RNG coin-flips above)
vendor_transition_tbl:
	nop
	rlca
	rlca
	rlca
	ex af,af'
	ex af,af'
	dec b
	ld b,000h
	inc bc
	inc bc
	ld bc,00505h
	dec b
	ld b,009h
	add hl,bc
	nop
	dec b
	dec b
	dec b
	ld (bc),a
	ld b,005h
	dec b
	dec b
	dec b
	nop
	inc bc
	dec b
	ld b,001h
	inc b
	inc b
	nop
	nop
	inc bc
	inc bc
; vendor outcome 0 (0x932E): register that the vendor was hit this frame
	ld a,0ffh
	ld (0c40ch),a
	ld a,(ix+009h)
	ld (0c703h),a          ; latch vendor object id
	ret
; vendor outcome 1 (0x933A): raise vendor "mood" 0xD012 (cap 3)
	ld hl,0d012h
	ld a,(hl)
	cp 003h
	ret z
	inc (hl)
	ret
; vendor outcome 2 (0x9343): lower vendor "mood" 0xD012 (floor 0)
	ld hl,0d012h
	ld a,(hl)
	or a
	ret z
	dec (hl)
	ret
; vendor outcome 3 (0x934B): GIVE Simon +5 hearts (sfx 0x0F)
	ld a,00fh
	call 050a6h
	ld b,005h
	jp add_hearts
; vendor outcome 4 (0x9355): TAKE 5 hearts from Simon (sfx 0x1D)
	ld a,01dh
	call 050a6h
	ld b,005h
	jp spend_hearts
; (vendor outcome 5 = the bare `ret` two lines above = do nothing)
; vendor outcome 6 (0x935F): vendor LEAVES - erase sprite, sfx 0x10, then
; award +5000 points (DE=0x5000 -> add_score via 0x44F3).
	ld (ix+000h),000h
	call sub_937fh
	ld hl,0e580h
	call sub_88a3h
	ld h,(ix+007h)
	ld l,(ix+008h)
	ld (hl),000h
	ld a,010h
	call 050a6h
	ld de,05000h
	jp 044f3h              ; add_score += 5000 (departure bonus)
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
	call 050a6h
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
	call 0494dh
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
	ld c,020h
	dec d
	ld h,b
	ld (de),a
	jr nc,sub_9456h
	ld h,b
	inc bc
	jr nz,$+18
	ld h,b
	inc b
	jr nz,l944eh
	add a,b
	ld a,(bc)
	ld b,b
	jr nz,$-126
	ld d,040h
	dec d
	add a,b
	ld e,030h
	djnz l949bh
	dec e
	jr nz,l945eh
l944eh:
	add a,b
	dec de
	ld d,b
	jr nc,l93e3h
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
; --- vendor_purchase_tick (0x94BE) --------------------------------------------
; Runs while an offer is on screen.  Every 0x20 frames tick down the 0xC706 offer
; timer; when it hits 0 the offer is withdrawn (vendor_offer_withdraw).  Otherwise poll the
; buy/refuse buttons: nothing pressed -> keep waiting (ret 0xFF, vendor_offer_pending); SHIFT/
; refuse -> withdraw (vendor_offer_withdraw, sfx 0x02); SPACE/confirm -> buy only if Simon has
; enough hearts (0xC417 >= price 0xC707): deduct price (spend_hearts) and grant
; the item (collect_bonus / sub_8d37h), sfx 0x12.
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
	call sub_8d37h         ; collect_bonus(item) -> give the purchased item
	pop af
	call c,l939eh
	ld a,012h
	call 050a6h            ; purchase-confirmed jingle
	call sub_9453h
	inc hl
	res 7,(hl)
	xor a
	ret
vendor_offer_withdraw:                        ; offer declined / expired / unaffordable
	ld a,002h
	call 050a6h
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
	call 0494dh
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
	ld a,(0c002h)
	and 040h
	ret z
	ld a,(0ce00h)
	and a
	ret nz
	ld a,(0cf38h)
	dec a
	jr z,l95afh
	dec a
	jr z,l95bah
	ld a,(0c00bh)
	bit 1,a
	ret z
	ld a,(0c701h)
	add a,a
	ret nc
	ld hl,0c70fh
	ld a,(hl)
	and a
	ret z
	dec (hl)
	jr nz,l9589h
	ld hl,0c701h
	res 7,(hl)
	call sub_8eedh
l9589h:
	call 04805h
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
	call 050a6h
l95aah:
	ld hl,0cf38h
	inc (hl)
	ret
l95afh:
	call sub_95d7h
	call sub_981ch
	call sub_985ah
	jr l95aah
l95bah:
	ld a,(0c00bh)
	bit 1,a
	ret z
	call 04f98h
	call sub_902eh
	call sub_9175h
	call sub_9273h
	call sub_870eh
	call 04810h
	xor a
	ld (0cf38h),a
	ret
sub_95d7h:
	xor a
	ld (0cffdh),a
l95dbh:
	call sub_9610h
	call sub_9681h
	call sub_979ah
	call sub_980eh
	ld a,(0cffdh)
	inc a
	ld (0cffdh),a
	ld c,a
	ld a,(0d000h)
	ld hl,l95fdh
	call ADD_HL_A
	ld a,c
	cp (hl)
	jr nz,l95dbh
	ret
l95fdh:
	inc bc
	ex af,af'
	ld b,006h
	ld b,006h
	ld b,009h
	ex af,af'
	add hl,bc
	add hl,bc
	ld b,00ch
	inc c
	ex af,af'
	ld a,(bc)
	ld a,(bc)
	inc c
	ld a,(bc)
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
sub_9681h:
	ld a,(0d000h)
	ld de,l969ch
	call lookup_word_tbl
	ld a,(0cffdh)
	call ADD_DE_A
	ld a,(de)
	ld de,0975eh
	call lookup_word_tbl
	ld (0cff2h),de
	ret
l969ch:
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
	call sub_9681h
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
	ld bc,0103ah
	ret nc
	and a                  ; (real intent: ld a,(0d010h)/and a - 0==normal play)
	call z,room_spawner    ; per-frame enemy spawner (seg0 0x5EBF), skipped mid-transition
	ld ix,0c800h           ; then tick all 7 actor slots
	ld b,007h
l98f9h:
	ld a,(ix+000h)
	and a
	jr z,l990fh
	push bc
	call sub_9936h
	jr c,l990bh
	call sub_9942h
	call sub_99c0h
l990bh:
	call actor_cull_offscreen
	pop bc
l990fh:
	ld de,00080h
	add ix,de
	djnz l98f9h
	ret
	ld ix,0d700h
	ld b,008h
	jr l9925h
	ld ix,0c800h
	ld b,007h
l9925h:
	push bc
	ld a,(ix+000h)
	and a
	call nz,0644ch
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
sub_9942h:
	ld a,(ix+000h)
	dec a
	call DISPATCH_A
	ld l,e
	xor c
	rla
	and e
	rla
	and e
	rst 38h
	or b
	add a,h
	xor b
	sbc a,c
	and l
	add a,d
	or b
	ld (066a5h),hl
	xor a
	dec (hl)
	and d
	add a,l
	or e
	add a,h
	and (hl)
	ld c,a
	or d
	cp (hl)
	xor c
	jp z,0ffb1h
	xor l
	ld c,c
	xor e
	ld (hl),a
	cp (hl)
	jr nz,$-65
	sbc a,d
	cp b
	ld l,e
	cp d
	ld (hl),h
	cp h
	ld c,a
	ld l,d
	defb 0fdh,0bah,0f1h ;illegal sequence
	or h
	pop af
	or h
	pop af
	or h
	pop af
	or h
	and l
	sbc a,c
	ld a,b
	sbc a,e
	rst 38h
	or b
	xor d
	sbc a,h
	rla
	and e
	xor b
	or a
	ld c,a
	or d
	ret po
	sbc a,e
	and l
	sbc a,c
	dec h
	sbc a,h
	cp d
	ld c,(hl)
	nop
	ld c,a
	nop
	ld c,a
	inc a
	ld c,a
	and l
	sbc a,c
	and e
	ld l,d
	add hl,de
	xor l
	ld (hl),h
	ld l,b
	ret
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
sub_99c0h:
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
	call sub_9f74h
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
	ld c,01eh
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
	ld c,024h               ; drop = pickup item type 0x24
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
	call 0a183h
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
	jp sub_89eah
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
	jp 07b9fh
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
sub_9ccah:
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
	ld hl,0cf00h
	ld de,l9d4ah
	call sub_9ccah
	ret nz
	call sub_9d03h
	call sub_9e1dh
	ret c
	ld c,001h
	jp spawn_actor
sub_9d03h:
	ld a,(0c425h)
	ld c,a
	ld hl,(0d000h)
	ld a,l
	dec a
	jr z,l9d2fh
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
l9d4ah:
	inc c
	ld (de),a
	inc c
	inc c
	inc c
	ld (de),a
	inc c
	inc c
	ld hl,0cf02h
	ld c,002h
	jr l9d5eh
	ld hl,0cf02h
	ld c,003h
l9d5eh:
	ld de,l9d96h
	push bc
	call sub_9ccah
	pop bc
	ret nz
	ld e,0c8h
	ld a,(0cf03h)
	and 007h
	ld hl,l9d8eh
	call ADD_HL_A
	ld d,(hl)
	ld a,(0c427h)
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
l9d8eh:
	ld h,b
	ret nc
	jr nc,l9d22h
	and b
	ld b,b
	ld h,b
	or b
l9d96h:
	ld bc,01818h
	jr $+26
	jr $+26
	jr $+35
	ld b,0cfh
	ld de,l9dc2h
	ld c,004h
l9da6h:
	push bc
	call sub_9ccah
	pop bc
	ret nz
	inc hl
	ld a,(hl)
	rr a
	ld d,0f0h
	jr c,l9db6h
	ld d,010h
l9db6h:
	call sub_9e1dh
	ld a,(0c425h)
	sub 008h
	ld e,a
	jp spawn_actor
l9dc2h:
	inc d
	inc d
	inc d
	jr z,l9ddbh
	inc d
	inc d
	jr z,l9dech
	ex af,af'
	rst 8
	ld de,l9dd4h
	ld c,007h
	jr l9da6h
l9dd4h:
	inc e
	inc e
	inc e
	ld c,b
	inc e
	inc e
	inc e
l9ddbh:
	ld c,b
	ld hl,0cf0ah
	ld de,l9de6h
	ld c,008h
	jr l9da6h
l9de6h:
	inc c
	inc c
	inc c
	jr l9df7h
	inc c
l9dech:
	inc c
	jr l9e10h
	inc c
	rst 8
	ld de,l9e15h
	call sub_9ccah
l9df7h:
	ret nz
	ld a,(0c427h)
	cp 0c0h
	jr c,l9e05h
	ld a,001h
	ld (0cf0ch),a
	ret
l9e05h:
	ld de,0e030h
	ld a,(0cf0dh)
	rra
	jr c,l9e10h
	ld e,040h
l9e10h:
	ld c,00fh
	jp spawn_actor
l9e15h:
	jr l9e2fh
	jr l9e31h
	jr l9e33h
	jr l9e35h
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
	ld ix,0d700h
	ld b,008h
l9e3eh:
	ld a,(ix+000h)
	and a
	jr z,l9e57h
	push bc
	call sub_9936h
	jr c,l9e50h
	call sub_9e5fh
	call sub_99c0h
l9e50h:
	call 0644ch
	call actor_cull_offscreen
	pop bc
l9e57h:
	ld de,00080h
	add ix,de
	djnz l9e3eh
	ret
sub_9e5fh:
	ld a,(ix+000h)
	dec a
	call DISPATCH_A
	ld a,(hl)
	sbc a,(hl)
	ld a,(hl)
	sbc a,(hl)
	ld a,(hl)
	sbc a,(hl)
	ld c,09fh
	ld a,(hl)
	sbc a,(hl)
	ld a,a
	sbc a,(hl)
	sub a
	sbc a,(hl)
	add hl,hl
	sbc a,a
	call z,07e9eh
	sbc a,(hl)
	res 3,(hl)
	ld a,b
	sbc a,e
	ret
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
	ret
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
	ld a,(ix+00ch)
	inc a
	cp 00ch
	jr c,l9f17h
	xor a
l9f17h:
	ld (ix+00ch),a
	rra
	rra
	and 003h
	add a,04bh
	ld (ix+00bh),a
	ld de,SETRD
	jp actor_add_yvel
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
	ld a,(ix+003h)
	sub 010h
	ld c,a
	ld b,(ix+005h)
	ld a,(ix+000h)
sub_9f74h:
	ld (0cff9h),a
	ld (0cff1h),bc
	ld (0cff5h),hl
	ld (0cff7h),de
	push ix
	call sub_9f8ah
	pop ix
	ret
sub_9f8ah:
	ld a,(0cff9h)
	cp 0ffh
	ld c,00ch
	jr z,l9f9ah
	ld hl,0a095h
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

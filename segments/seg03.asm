; ===========================================================================
;  SEGMENT 3 - banked code, paged at 0xA000-0xBFFF (page 2b).
;  Raw disassembly imported for annotation; reverse-engineering IN PROGRESS.
;  (Origin is set by PHASE 0xA000 in VampireKiller.asm; regenerate the raw
;   disassembly with  tools/regen-seg.sh 3 0xA000 .)
;
;  MSX/MSX2 BIOS entry-point names and shared seg0/seg1 routine labels are
;  defined elsewhere (bios.inc, seg00.asm, seg01.asm) and referenced here.
; ===========================================================================

	ld (hl),001h
	inc l
	ld de,(0cff5h)
	ld (hl),e
	inc l
	ld (hl),d
	ld de,(0cff7h)
	inc l
	ld (hl),e
	inc l
	ld (hl),d
	inc l
	ld (hl),003h
	ld a,(ix+000h)
	ld de,0a0c4h
	call lookup_word_tbl
	ld hl,(0cff3h)
	set 5,l
	ld b,(hl)
	ld a,005h
	add a,l
	ld l,a
la028h:
	ld a,(de)
	ld (hl),a
	inc de
	ld a,l
	add a,005h
	ld l,a
	djnz la028h
	ld hl,(0cff3h)
	ld a,(ix+000h)
	dec a
	call DISPATCH_A
	ld d,e
	and b
	ld d,e
	and b
	ld d,e
	and b
	ld d,e
	and b
	ld d,e
	and b
	ld d,e
	and b
	ld d,h
	and b
	ld (hl),c
	and b
	add a,d
	and b
	ld d,e
	and b
	ld d,e
	and b
	ld h,a
	sbc a,e
	ret
	ld (ix+010h),000h
	ld a,(ix+003h)
	ld (ix+011h),a
	ld l,(ix+007h)
	ld h,(ix+008h)
	ld de,00100h
	and a
	sbc hl,de
	ld (ix+012h),l
	ld (ix+013h),h
	ret
	ld (ix+006h),001h
	ld (ix+00ch),03ch
	ld de,CHKRAM
	call actor_set_yvel
	jp actor_set_xvel
	ld a,(ix+00ah)
	ld (ix+010h),a
	ld (ix+013h),018h
	ld hl,(0cffch)
	ld (ix+011h),l
	ld (ix+012h),h
	ret
	ld bc,00201h
	ld bc,00101h
	ld bc,00101h
	inc bc
	inc b
	ld bc,00101h
	ld bc,00509h
	ld bc,00706h
	ld bc,00b08h
	ld a,(bc)
	ld bc,00101h
	ld bc,00101h
	ld bc,00101h
	ld bc,00101h
	ld bc,00101h
	ld bc,00101h
	ld bc,00101h
	ld bc,00101h
	jp pe,0eaa0h
	and b
	jp pe,0dea0h
	and b
	jp pe,0e0a0h
	and b
	jp po,0e2a0h
	and b
	call po,0eaa0h
	and b
	and 0a0h
	ret pe
	and b
	ld b,d
	inc c
	ld b,l
	ld (bc),a
	ld b,d
	dec b
	ld b,d
	dec b
	ld c,b
	dec b
	nop
	ex af,af'
	nop
	ex af,af'
sub_a0ech:
	ld a,080h
	ld e,(ix+003h)
	ld d,(ix+005h)
sub_a0f4h:
	ld c,a
	ld a,(0d012h)
	add a,a
	add a,a
	add a,a
	add a,c
	ld (0cff0h),a
	call sub_a13bh
	ld a,(0cff8h)
	ld e,a
	ld d,000h
	ld a,e
	sub 03fh
	neg
	ld hl,0a1e9h
	push hl
	add hl,de
	ld c,(hl)
	pop hl
	ld e,a
	add hl,de
	ld a,(hl)
	ld (0cff7h),a
	ld e,c
	call sub_a18bh
	ld a,(0cff1h)
	and a
	call nz,sub_a183h
	ld (0cff3h),de
	ld a,(0cff7h)
	ld e,a
	call sub_a18bh
	ld a,(0cff2h)
	and a
	call nz,sub_a183h
	ld hl,(0cff3h)
	ret
sub_a13bh:
	ld hl,0cff1h
	ld (hl),000h
	ld a,(0c425h)
	sub e
	jr nc,la149h
	neg
	inc (hl)
la149h:
	inc hl
	ld (hl),000h
	rra
	rra
	and 038h
	ld e,a
	ld a,(0c427h)
	sub d
	jr nc,la15ah
	neg
	inc (hl)
la15ah:
	rra
	rra
	rra
	rra
	rra
	and 007h
	add a,e
	ld hl,la1a9h
	call ADD_HL_A
	ld a,(hl)
	ld (0cff8h),a
	ld c,a
	ld hl,(0cff1h)
	ld a,h
	ld b,000h
	and a
	jr z,la178h
	ld b,080h
la178h:
	cp l
	ld a,c
	jr z,la17eh
	neg
la17eh:
	add a,b
	ld (0cff9h),a
	ret
sub_a183h:
	ld a,d
	cpl
	ld d,a
	ld a,e
	cpl
	ld e,a
	inc de
	ret
sub_a18bh:
	ld a,(0cff0h)
	ld h,a
	call sub_a19dh
	xor a
	add hl,hl
	adc a,a
	add hl,hl
	adc a,a
	add hl,hl
	adc a,a
	ld l,h
	ld h,a
	ex de,hl
	ret
sub_a19dh:
	ld b,008h
	ld l,000h
	ld d,l
la1a2h:
	add hl,hl
	jr nc,la1a6h
	add hl,de
la1a6h:
	djnz la1a2h
	ret
la1a9h:
	jr nz,$+10
	inc b
	inc bc
	ld (bc),a
	ld (bc),a
	ld bc,03801h
	jr nz,$+23
	rrca
	inc c
	add hl,bc
	ex af,af'
	rlca
	dec sp
	dec hl
	jr nz,la1d6h
	inc d
	djnz $+16
	inc c
	dec a
	ld sp,02027h
	ld a,(de)
	ld d,013h
	ld de,0343dh
	inc l
	dec h
	jr nz,$+30
	jr $+23
	ld a,036h
	cpl
	add hl,hl
	inc h
la1d6h:
	jr nz,la1f4h
	add hl,de
	ld a,038h
	ld (0282ch),a
	inc hl
	jr nz,la1feh
	ld a,039h
	inc (hl)
	cpl
	ld hl,(02326h)
	jr nz,la1eah
la1eah:
	ld b,00ch
	ld (de),a
	add hl,de
	rra
	ld h,02ch
	ld (03e38h),a
la1f4h:
	ld b,h
	ld c,d
	ld d,b
	ld d,(hl)
	ld e,h
	ld h,d
	ld l,b
	ld l,l
	ld (hl),e
	ld a,c
la1feh:
	ld a,(hl)
	add a,h
	adc a,c
	adc a,(hl)
	sub e
	sbc a,c
	sbc a,(hl)
	and d
	and a
	xor h
	or c
	or l
	cp c
	cp (hl)
	jp nz,0cac6h
	adc a,0d1h
	push de
	ret c
	call c,0e2dfh
	push hl
	rst 20h
	jp pe,0efedh
	pop af
	di
	push af
	rst 30h
	ret m
	jp m,0fcfbh
	defb 0fdh,0feh,0feh ;illegal sequence
	rst 38h
	rst 38h
	rst 38h
	call sub_a2afh
	ld (ix+010h),008h
	ld (ix+011h),020h
	ret
	call sub_a2afh
	ld a,(ix+001h)
	dec a
	jr z,la25ah
	dec a
	jr z,la2a0h
	dec (ix+010h)
	ret nz
	inc (ix+001h)
	ld (ix+011h),018h
	ld a,(0d012h)
	add a,a
	add a,a
	add a,a
	sub 028h
	neg
	ld (ix+010h),a
	ret
la25ah:
	ld a,04ch
	bit 0,(ix+011h)
	jr z,la264h
	ld a,048h
la264h:
	call sub_a291h
	dec (ix+011h)
	ret nz
	ld (ix+013h),012h
	inc (ix+001h)
la272h:
	ld hl,CHKRAM
	ld de,0fc00h
	bit 0,(ix+00bh)
	jr z,la281h
	ld de,00400h
la281h:
	ld a,(ix+003h)
	sub 014h
	ld c,a
	ld b,(ix+005h)
	ld a,00ah
	call 09f74h
	ld a,04ch
sub_a291h:
	ld (ix+025h),002h
	ld (ix+02ah),a
	ld (ix+02fh),002h
	ld (ix+034h),a
	ret
la2a0h:
	call sub_a2afh
	dec (ix+013h)
	ret nz
	ld (ix+001h),000h
	jr la272h
	ld a,04ch
sub_a2afh:
	ld b,005h
	ld a,(0d000h)
	cp 009h
	jr nz,la2c1h
	ld a,(0d001h)
	cp 004h
	jr nz,la2c1h
	ld b,007h
la2c1h:
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,la2cah
	dec b
la2cah:
	ld (ix+00bh),b
	ret
	ld (ix+01bh),001h
	xor a
	ld (ix+01ch),a
	ld (ix+012h),a
	ld (ix+010h),002h
	ld (ix+019h),a
	ld (ix+015h),001h
	jp la36dh
	call 0a4bah
	xor a
	ld (ix+018h),a
	ld (ix+01bh),a
	inc a
	ld (ix+006h),a
	ld (ix+019h),a
	ld (ix+008h),0f4h
	ld (ix+007h),080h
	ld a,008h
	call sub_a4efh
	ld e,(ix+003h)
	ld d,(ix+005h)
	ld c,020h
	push de
	call spawn_actor
	pop de
	ld c,020h
	jp spawn_actor
	inc (ix+01dh)
	ld a,(ix+001h)
	dec a
	jp z,la3a7h
	dec a
	jp z,la461h
	bit 0,(ix+018h)
	jr nz,la32eh
	call 0a4bah
la32eh:
	ld de,CHKRAM
	call actor_set_xvel
	ld de,00080h
	call actor_add_yvel
	bit 7,(ix+008h)
	ret nz
	ld d,(ix+005h)
	ld e,(ix+003h)
	bit 0,(ix+012h)
	jr z,la34fh
	ld a,d
	add a,008h
	ld d,a
la34fh:
	call 07b9fh
	jr nc,la387h
	ld a,007h
	call sub_a4efh
	ld a,(ix+003h)
	and 0f8h
	ld (ix+003h),a
	ld a,(0d012h)
	add a,a
	add a,a
	sub 030h
	neg
	ld (ix+010h),a
la36dh:
	ld (ix+011h),010h
	ld (ix+014h),000h
	ld (ix+015h),001h
	ld (ix+001h),001h
	ld (ix+013h),008h
	ld de,CHKRAM
	jp actor_set_yvel
la387h:
	ld a,(ix+003h)
	cp 0c0h
	ret c
	ld a,009h
	call sub_a4efh
	call 099fdh
	ld e,(ix+003h)
	ld d,(ix+005h)
	ld c,020h
	push de
	call spawn_actor
	pop de
	ld c,020h
	jp spawn_actor
la3a7h:
	bit 0,(ix+01bh)
	jr z,la3d2h
	bit 0,(ix+01ch)
	jr nz,la3d2h
	ld (ix+00bh),012h
	ld a,(0c425h)
	ld b,a
	ld (ix+000h),003h
	ld a,(ix+003h)
	sub 008h
	cp b
	ret nc
	add a,010h
	cp b
	ret c
	ld (ix+006h),001h
	ld (ix+01ch),001h
la3d2h:
	bit 0,(ix+000h)
	jr z,la3e5h
	dec (ix+010h)
	jr nz,la3e5h
	inc (ix+001h)
	ld (ix+011h),018h
	ret
la3e5h:
	dec (ix+015h)
	jr nz,la40ah
	call sub_a4d6h
	ld (ix+012h),000h
	ld de,0fe80h
	ld a,(0c427h)
	cp (ix+005h)
	jr c,la403h
	ld (ix+012h),001h
	ld de,00180h
la403h:
	call actor_set_xvel
	ld (ix+013h),001h
la40ah:
	ld hl,la459h
	bit 0,(ix+012h)
	jr z,la416h
	ld hl,0a45dh
la416h:
	dec (ix+013h)
	jr nz,la436h
	ld (ix+013h),008h
	inc (ix+014h)
	ld a,(ix+014h)
	and 001h
	bit 0,(ix+000h)
	jr z,la42fh
	add a,002h
la42fh:
	call ADD_HL_A
	ld a,(hl)
	ld (ix+00bh),a
la436h:
	ld a,(ix+005h)
	bit 7,(ix+00ah)
	jr nz,la441h
	add a,008h
la441h:
	ld d,a
	ld e,(ix+003h)
	call 07b9fh
	ret c
	ld (ix+008h),000h
	ld (ix+007h),000h
	dec (ix+001h)
	ld (ix+018h),001h
	ret
la459h:
	ex af,af'
	add hl,bc
	rrca
	djnz $+13
	inc c
	ld (de),a
	inc de
la461h:
	ld (ix+006h),000h
	dec (ix+011h)
	jr z,la48dh
	ld a,(ix+011h)
	cp 008h
	jr z,la499h
	ld hl,la4b6h
	cp 010h
	jr c,la489h
	ld c,000h
la47ah:
	bit 0,(ix+012h)
	jr z,la481h
	inc c
la481h:
	ld b,000h
	add hl,bc
	ld a,(hl)
	ld (ix+00bh),a
	ret
la489h:
	ld c,002h
	jr la47ah
la48dh:
	dec (ix+001h)
	ld (ix+010h),030h
	ld (ix+006h),001h
	ret
la499h:
	ld hl,CHKRAM
	ld de,00300h
	bit 7,(ix+00ah)
	jr z,la4a8h
	ld de,0fd00h
la4a8h:
	ld a,(ix+003h)
	sub 014h
	ld c,a
	ld b,(ix+005h)
	ld a,002h
	jp 09f74h
la4b6h:
	rrca
	ld (de),a
	ld de,00614h
	dec bc
	ld c,008h
	bit 0,(ix+000h)
	jr z,la4c8h
	ld b,012h
	ld c,00fh
la4c8h:
	ld (ix+00bh),b
	ld a,(0c427h)
	cp (ix+005h)
	ret nc
	ld (ix+00bh),c
	ret
sub_a4d6h:
	ld hl,la4fah
	bit 0,(ix+019h)
	jr nz,la4e2h
	ld hl,la4feh
la4e2h:
	ld a,(ix+01dh)
	and 003h
	call ADD_HL_A
	ld a,(hl)
	ld (ix+015h),a
	ret
sub_a4efh:
	ld c,a
	ld a,(0c420h)
	cp 006h
	ret z
	ld a,c
	jp 050a6h
la4fah:
	djnz la51ch
	jr $+50
la4feh:
	ex af,af'
	djnz la50ch
	ld b,0ddh
	ld (hl),006h
	ld bc,07eddh
	inc bc
	ld (ix+010h),a
la50ch:
	ld de,0fc80h
	call actor_set_yvel
	ld a,(ix+005h)
	cp 080h
	ld de,00280h
	jr c,la51fh
la51ch:
	ld de,0fd80h
la51fh:
	jp actor_set_xvel_scroll
	ld c,071h
	ld a,(0d000h)
	cp 015h
	jr nz,la52dh
	ld c,072h
la52dh:
	inc (ix+00ch)
	bit 2,(ix+00ch)
	jr z,la537h
	inc c
la537h:
	bit 7,(ix+00ah)
	jr nz,la53fh
	inc c
	inc c
la53fh:
	ld (ix+00bh),c
	ld de,00040h
	ld a,(ix+003h)
	cp (ix+010h)
	jr c,actor_add_yvel
	ld de,0ffc0h
; ---------------------------------------------------------------------------
;  Actor velocity helpers.  Actor slot layout (confirmed via the seg2 integrator
;  at 0x99C0 and the dog/zombie AI):
;     +0x02/+0x03  Y position (16-bit fixed: +0x02 frac, +0x03 pixel)
;     +0x04/+0x05  X position (16-bit fixed: +0x04 frac, +0x05 pixel)
;     +0x07/+0x08  Y velocity (16-bit signed)
;     +0x09/+0x0A  X velocity (16-bit signed)
;  actor_add_yvel (0xA550): Yvel += DE, but clamp to [0, 0x07FF] - i.e. downward
;  only with a terminal fall speed (gravity).  Falls through to actor_set_yvel.
; ---------------------------------------------------------------------------
actor_add_yvel:
	ld l,(ix+007h)
	ld h,(ix+008h)
	add hl,de               ; Yvel += DE
	ex de,hl
	ld a,d
	and a
	jp m,actor_set_yvel     ; negative -> store as-is
	cp 008h
	jr c,actor_set_yvel     ; < 0x0800 -> store
	ld de,007ffh            ; clamp to terminal fall speed
actor_set_yvel:
	ld (ix+007h),e          ; +0x07/+0x08 = Y velocity
	ld (ix+008h),d
	ret

; actor_add_xvel (0xA56B): Xvel += DE.  Falls through to actor_set_xvel.
actor_add_xvel:
	ld l,(ix+009h)
	ld h,(ix+00ah)
	add hl,de               ; Xvel += DE
	ex de,hl
actor_set_xvel:
	ld (ix+009h),e          ; +0x09/+0x0A = X velocity
	ld (ix+00ah),d
	ret
	ld (ix+006h),001h
	ld de,CHKRAM
	ld (ix+010h),e
	ld (ix+011h),e
	call actor_set_yvel
	ld de,00160h
	call actor_set_xvel
	ld (ix+00bh),050h
	ld (ix+00ch),060h
	ret
	dec (ix+00ch)
	ld a,014h
	bit 7,(ix+00ah)
	jr z,la5a6h
	ld a,0f8h
la5a6h:
	add a,(ix+005h)
	ld d,a
	ld e,(ix+003h)
	call 07b9fh
	jr nc,la613h
	ld d,(ix+005h)
	ld bc,00808h
	bit 7,(ix+00ah)
	jr nz,la5c3h
	call 07bc5h
	jr la5c6h
la5c3h:
	call 07c21h
la5c6h:
	jr c,la613h
	ld a,(ix+005h)
	cp 0f0h
	jr c,la5d7h
	bit 7,(ix+00ah)
	jr z,la613h
	jr la5e3h
la5d7h:
	cp 00fh
	jp nc,la5e3h
	bit 7,(ix+00ah)
	jp nz,la613h
la5e3h:
	call sub_a63eh
	jr nc,la605h
	bit 0,(ix+011h)
	jr nz,la609h
	ld de,00160h
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,la5fch
	ld de,0fea0h
la5fch:
	call actor_set_xvel_scroll
	ld (ix+011h),001h
	jr la616h
la605h:
	ld (ix+011h),000h
la609h:
	ld a,(ix+00ch)
	and a
	jr nz,la616h
	ld (ix+00ch),060h
la613h:
	call sub_a649h
la616h:
	inc (ix+010h)
	ld a,(ix+010h)
	rra
	rra
	and 003h
	ld hl,la62eh
	bit 7,(ix+00ah)
	jr nz,la62bh
	add a,004h
la62bh:
	ld c,a
	jr la636h
la62eh:
	ld d,b
	ld d,c
	ld d,d
	ld d,c
	ld d,e
	ld d,h
	ld d,l
	ld d,h
la636h:
	ld b,000h
	add hl,bc
	ld a,(hl)
	ld (ix+00bh),a
	ret
sub_a63eh:
	ld a,(0c425h)
	sub (ix+003h)
	add a,008h
	cp 010h
	ret
sub_a649h:
	push af
	push de
	ld e,(ix+009h)
	ld d,(ix+00ah)
	call sub_a183h
	call actor_set_xvel
	pop de
	pop af
	ret
; ---------------------------------------------------------------------------
;  actor_set_xvel_scroll (0xA65A) - set X velocity (DE) but fold in the room's
;  horizontal scroll speed (0xD012 * 32) so the actor tracks with the scrolling
;  background.  DE == 0 short-circuits to a plain store.  Ends by storing to
;  +0x09/+0x0A via actor_set_xvel.
; ---------------------------------------------------------------------------
actor_set_xvel_scroll:
	ld a,d
	or e
	jp z,actor_set_xvel     ; zero velocity: just store
	push hl
	ex de,hl                ; HL = requested X velocity
	ld a,(0d012h)           ; A = scroll speed
	add a,a
	add a,a
	add a,a
	add a,a
	add a,a                 ; A = scroll * 32
	ld d,000h
	ld e,a
	bit 7,h
	call nz,sub_a183h       ; sign-extend/adjust when velocity negative
	add hl,de               ; blend scroll into velocity
	ex de,hl
	pop hl
	jp actor_set_xvel
	ld (ix+010h),018h
	ld (ix+00bh),089h
	ld (ix+012h),000h
	ret
	inc (ix+018h)
	ld a,(ix+001h)
	call DISPATCH_A
	sbc a,l
	and (hl)
	xor h
	and (hl)
	sbc a,0a6h
	pop af
	and (hl)
	dec b
	and a
	cpl
	and a
	ld l,e
	and a
	sbc a,d
	and a
	dec (ix+010h)
	ret nz
	ld (ix+006h),001h
	inc (ix+001h)
	call sub_a7c4h
	ret
	call sub_a834h
	ret c
	call sub_a79eh
	ld a,0e0h
	bit 7,(ix+008h)
	jr z,la6bdh
	ld a,020h
la6bdh:
	ld h,(ix+008h)
	ld l,(ix+007h)
	call sub_a82ah
	ld (ix+008h),h
	ld (ix+007h),l
	ld a,(ix+008h)
	and a
	ret nz
	ld a,(ix+007h)
	and a
	ret nz
	ld (ix+01eh),018h
	inc (ix+001h)
	ret
	call sub_a79eh
	ld (ix+006h),000h
	dec (ix+01eh)
	ret nz
	ld (ix+006h),001h
	inc (ix+001h)
	ret
	ld (ix+001h),001h
	ld a,(0c425h)
	sub (ix+003h)
	cp 018h
	jp nc,sub_a7c4h
	ld (ix+001h),004h
	ret
	ld (ix+00ah),003h
	ld (ix+009h),000h
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,la71dh
	ld (ix+00ah),0fdh
	ld (ix+009h),000h
la71dh:
	ld (ix+008h),000h
	ld (ix+007h),000h
	inc (ix+001h)
	ld (ix+010h),030h
	jp sub_a79eh
	call sub_a834h
	ret c
	call sub_a79eh
	dec (ix+010h)
	jr z,la763h
	bit 7,(ix+00ah)
	jr z,la752h
	ld (ix+011h),000h
	ld a,(0c427h)
	sub 008h
	cp (ix+005h)
	ret c
	inc (ix+001h)
	ret
la752h:
	ld (ix+011h),001h
	ld a,(0c427h)
	add a,008h
	cp (ix+005h)
	ret nc
	inc (ix+001h)
	ret
la763h:
	call sub_a7c4h
	ld (ix+001h),001h
	ret
	call sub_a834h
	ret c
	call sub_a79eh
	ld a,0e0h
	ld e,0feh
	bit 0,(ix+011h)
	jr nz,la780h
	ld a,020h
	ld e,002h
la780h:
	ld h,(ix+00ah)
	ld l,(ix+009h)
	call sub_a82ah
	ld (ix+00ah),h
	ld (ix+009h),l
	ld a,h
	cp e
	ret nz
	inc (ix+001h)
	ld (ix+009h),000h
	ret
	call sub_a834h
	ret c
sub_a79eh:
	ld hl,la7c0h
	bit 7,(ix+00ah)
	jr z,la7aah
	ld hl,la7c2h
la7aah:
	inc (ix+012h)
	ld a,(ix+012h)
	and 008h
	sra a
	sra a
	sra a
	call ADD_HL_A
	ld a,(hl)
	ld (ix+00bh),a
	ret
la7c0h:
	adc a,d
	adc a,e
la7c2h:
	add a,a
	adc a,b
sub_a7c4h:
	ld de,0fe00h
	ld hl,00200h
	ld a,(0c427h)
	cp (ix+005h)
	jr c,la7d3h
	ex de,hl
la7d3h:
	ld a,(ix+005h)
	cp 0c0h
	jr nc,la7e3h
	cp 040h
	jr nc,la7e6h
	ld de,00200h
	jr la7e6h
la7e3h:
	ld de,0fe00h
la7e6h:
	call actor_set_xvel
	ld hl,la81ah
	ld a,(0c425h)
	cp (ix+003h)
	jr c,la7f7h
	ld hl,la822h
la7f7h:
	ld a,(ix+018h)
	and 003h
	add a,a
	call ADD_HL_A
	ld d,(hl)
	inc hl
	ld e,(hl)
	ld a,(ix+003h)
	bit 7,d
	jr z,la812h
	cp 040h
	call c,sub_a183h
	jp actor_set_yvel
la812h:
	cp 0c0h
	call nc,sub_a183h
	jp actor_set_yvel
la81ah:
	defb 0fdh,0e0h,0fdh ;illegal sequence
	add a,b
	defb 0fdh,000h,0fbh ;illegal sequence
	add a,b
la822h:
	ld (bc),a
	jr nz,la827h
	add a,b
	inc bc
la827h:
	nop
	inc bc
	add a,b
sub_a82ah:
	bit 7,a
	jp z,ADD_HL_A
	add a,l
	ld l,a
	ret c
	dec h
	ret
sub_a834h:
	ld a,(ix+003h)
	bit 7,(ix+008h)
	jr nz,la843h
	cp 0c0h
	jr nc,la859h
	jr la847h
la843h:
	cp 020h
	jr c,la859h
la847h:
	ld a,(ix+005h)
	bit 7,(ix+00ah)
	jr nz,la856h
	cp 0e8h
	jr nc,la859h
	xor a
	ret
la856h:
	cp 010h
	ret nc
la859h:
	ld (ix+01eh),018h
	ld (ix+001h),002h
	scf
	ret

; ---------------------------------------------------------------------------
;  enemy_dog_tick (seg3 0xA863) - behaviour handler for entity type 5, the
;  "sitting dog".  Reached via seg0 entity_tbl[type-1] dispatch.  Runtime-
;  confirmed: the dog idles in place until Simon closes in, then flees right
;  off-screen.  This path selects the idle animation frame from Simon's
;  proximity to the dog.
; ---------------------------------------------------------------------------
enemy_dog_tick:
	ld b,(ix+005h)          ; B = dog position byte (+0x05)
	ld a,(0c427h)           ; A = Simon X (screen)
	cp b                    ; Simon at/past the dog?
	ld a,043h               ; idle frame 0x43 (Simon still far)
	jr nc,la870h
	ld a,03fh               ; idle frame 0x3f (Simon near)
la870h:
	ld (ix+00bh),a          ; store animation frame (+0x0B)
	ld (ix+006h),001h       ; mark actor alive (+0x06 = 1)
	ld (ix+00ch),000h       ; clear anim/state timer (+0x0C)
	ld de,CHKRAM            ; DE = 0 (offset, not the BIOS entry)
	call actor_set_xvel
	jp actor_set_yvel            ; chain to shared actor tail
	ld a,(ix+005h)
	cp 018h
	jp c,099fdh
	ld a,(ix+001h)
	call DISPATCH_A
	sbc a,b
	xor b
	or e
	xor b
	exx
	xor b
	ld a,(0c427h)
	sub (ix+005h)
	ld de,00400h
	jr nc,la8a8h
	neg
	ld de,0fc00h
la8a8h:
	cp 040h
	ret nc
	call actor_set_xvel
	ld (ix+001h),001h
	ret
	call sub_a910h
	ld e,(ix+003h)
	ld d,(ix+005h)
	call 07b9fh
	ret c
	ld de,0fef8h
	call actor_set_yvel
	ld a,(ix+00ah)
	bit 7,a
	ld a,046h
	jr z,la8d1h
	ld a,042h
la8d1h:
	ld (ix+00bh),a
	ld (ix+001h),002h
	ret
	ld de,000a0h
	call actor_add_yvel
	ld e,(ix+003h)
	ld d,(ix+005h)
	call 07b9fh
	ret nc
	ld b,(ix+005h)
	ld a,(0c427h)
	cp b
	ld de,00400h
	jr nc,la8f8h
	ld de,0fc00h
la8f8h:
	call actor_set_xvel
	ld (ix+00ch),000h
	ld (ix+001h),001h
	ld (ix+002h),000h
	call sub_a9a9h
	ld de,CHKRAM
	jp actor_set_yvel
sub_a910h:
	ld a,(ix+00ch)
	inc a
	cp 00dh
	jr c,la91ah
	ld a,001h
la91ah:
	ld (ix+00ch),a
	bit 7,(ix+00ah)
	ld a,(ix+00ch)
	jr z,la92ah
	ld b,041h
	jr la92ch
la92ah:
	ld b,045h
la92ch:
	cp 004h
	jr c,la937h
	inc b
	cp 00ah
	jr c,la937h
	dec b
	dec b
la937h:
	ld (ix+00bh),b
	ret

; ---------------------------------------------------------------------------
;  enemy_zombie_tick (seg3 0xA93B) - behaviour handler for entity type 1, the
;  walking zombie.  Reached via seg0 entity_tbl[type-1] dispatch.  This entry
;  is the spawn/init path: it picks the walk direction from which side of the
;  screen the zombie is on, so it heads toward the centre/Simon.
; ---------------------------------------------------------------------------
enemy_zombie_tick:
	ld (ix+006h),001h       ; mark actor alive (+0x06 = 1)
	ld a,(ix+005h)          ; A = zombie X (+0x05)
	cp 080h                 ; left or right half of the screen?
	ld de,00220h            ; +X velocity (move right)  \ right half
	ld bc,03d00h            ; anim 0x3d, facing 0        /
	jr c,la952h
	ld de,0fde0h            ; -X velocity (move left)   \ left half
	ld bc,03b01h            ; anim 0x3b, facing 1        /
la952h:
	ld (ix+011h),e          ; store 16-bit X velocity (+0x11/+0x12)
	ld (ix+012h),d
	call actor_set_xvel_scroll
	ld (ix+00bh),b          ; walk anim frame (+0x0B = 0x3d / 0x3b)
	ld (ix+00ch),008h       ; anim timer (+0x0C = 8)
	ld (ix+010h),c          ; facing flag (+0x10 = 0 right / 1 left)
	ld de,CHKRAM            ; DE = 0 (offset, not the BIOS entry)
	jp actor_set_yvel            ; chain to shared actor tail
	dec (ix+00ch)
	jr nz,la98bh
	ld a,(ix+010h)
	or a
	ld bc,03d3eh
	jr z,la97ch
	ld bc,03b3ch
la97ch:
	ld a,(ix+00bh)
	cp b
	ld a,b
	jr nz,la984h
	ld a,c
la984h:
	ld (ix+00bh),a
	ld (ix+00ch),004h
la98bh:
	ld d,(ix+005h)
	ld e,(ix+003h)
	call 07b9fh
	jr nc,la9b2h
	ld de,CHKRAM
	call actor_set_yvel
	ld e,(ix+011h)
	ld d,(ix+012h)
	call actor_set_xvel_scroll
	ld (ix+006h),001h
sub_a9a9h:
	ld a,(ix+003h)
	and 0f8h
	ld (ix+003h),a
	ret
la9b2h:
	ld de,CHKRAM
	call actor_set_xvel
	ld de,00060h
	jp actor_add_yvel
	ld hl,la9ceh
	push hl
	ld a,(ix+001h)
	call DISPATCH_A
	rst 18h
	xor c
	ld (de),a
	xor d
	ld a,0aah
la9ceh:
	ld a,(ix+022h)
	add a,010h
	ld (ix+003h),a
	ld a,(ix+023h)
	add a,008h
	ld (ix+005h),a
	ret
	push ix
	pop hl
	ld a,l
	add a,023h
	ld l,a
	push ix
	pop hl
	ld e,l
	ld d,h
	set 4,e
	ld a,023h
	add a,l
	ld l,a
	push hl
	push de
	call sub_aa6eh
	pop de
	pop hl
	call sub_aa6eh
	dec (ix+00ch)
	ret nz
	call sub_aa91h
	inc (ix+001h)
	ld (ix+00ch),01eh
	ld (ix+018h),020h
	ld (ix+019h),000h
	ret
	ld (ix+024h),080h
	ld (ix+029h),084h
	call sub_aa84h
	push ix
	pop hl
	ld e,l
	set 4,e
	ld d,h
	ld a,022h
	add a,l
	ld l,a
	push hl
	push de
	call sub_aa6eh
	pop de
	pop hl
	call sub_aa6eh
	dec (ix+00ch)
	ret nz
	ld (ix+00ch),018h
	inc (ix+001h)
	ret
	ld (ix+024h),070h
	ld (ix+029h),074h
	dec (ix+00ch)
	jr z,laa65h
	ld a,(ix+00ch)
	cp 008h
	ret nz
	call sub_a0ech
	bit 7,d
	ret z
	ld a,(ix+022h)
	add a,00ch
	ld c,a
	ld b,(ix+023h)
	ld a,00eh
	jp 09f74h
laa65h:
	ld (ix+00ch),01eh
	ld (ix+001h),001h
	ret
sub_aa6eh:
	ld b,008h
laa70h:
	ld a,(de)
	inc de
	cp (hl)
	jr z,laa7dh
	ld a,001h
	jr nc,laa7bh
	ld a,0ffh
laa7bh:
	add a,(hl)
	ld (hl),a
laa7dh:
	ld a,005h
	add a,l
	ld l,a
	djnz laa70h
	ret
sub_aa84h:
	dec (ix+018h)
	ret nz
	ld a,r
	and 00fh
	add a,010h
	ld (ix+018h),a
sub_aa91h:
	ld a,(ix+019h)
	inc (ix+019h)
	and 007h
	add a,a
	add a,a
	ld hl,laab4h
	call ADD_HL_A
	push ix
	pop de
	set 4,e
	ld b,004h
laaa8h:
	ld a,(hl)
	add a,(ix+01ah)
	ld (de),a
	inc de
	ld (de),a
	inc de
	inc hl
	djnz laaa8h
	ret
laab4h:
	nop
	nop
	nop
	nop
	call pe,0f8f2h
	cp 020h
	jr $+18
	ld (bc),a
	djnz $+22
	inc c
	ld (bc),a
	call m,004fch
	cp 004h
	inc c
	nop
	ld (bc),a
	jr nz,laae6h
	djnz $+4
	nop
	call p,RIGHTC
	ld (ix+00ch),020h
	ld a,(ix+003h)
	ld (ix+01ah),a
	ld a,(ix+005h)
	ld (ix+01bh),a
	push ix
laae6h:
	pop de
	set 4,e
	ld hl,lab25h
	ld b,004h
laaeeh:
	ld a,(hl)
	add a,(ix+01bh)
	ld (de),a
	inc de
	ld (de),a
	inc de
	inc hl
	djnz laaeeh
	ld a,00ah
	add a,e
	ld e,a
	ld bc,008ffh
	ld hl,lab15h
lab03h:
	ld a,(ix+01ah)
	ld (de),a
	inc de
	ld a,(ix+01bh)
lab0bh:
	ld (de),a
	inc de
	ldi
	ldi
	inc e
	djnz lab03h
	ret
lab15h:
	add a,b
	ld (bc),a
	add a,h
	ld c,h
	ld a,b
	ld (bc),a
	ld a,h
	ld c,h
	ld a,b
	ld (bc),a
	ld a,h
	ld c,h
	ld a,b
	ld (bc),a
	ld a,h
	ld c,h
lab25h:
	ret nc
	ret po
	ret p
	nop
	ld (ix+006h),000h
	ld de,0fe00h
	call actor_set_yvel
	ld de,CHKRAM
	call actor_set_xvel
	ld (ix+00bh),056h
	ld (ix+00ch),01eh
	xor a
	ld (ix+010h),a
	ld (ix+00eh),a
	ret
	ld hl,lab67h
	push hl
	ld a,(ix+001h)
	call DISPATCH_A
	ld l,(hl)
	xor e
	adc a,l
	xor e
	or d
	xor e
	in a,(0abh)
	ret p
	xor e
	jr z,lab0bh
	ld b,a
	xor h
	add a,l
	xor h
	or l
	xor h
	ret po
	xor h
lab67h:
	ld a,(ix+005h)
	ld (0ce0fh),a
	ret
	ld a,(0c427h)
	sub (ix+005h)
	ld c,056h
	jr c,lab7ah
	inc c
	inc c
lab7ah:
	ld (ix+00bh),c
	dec (ix+00ch)
	ret nz
	ld (ix+006h),001h
	ld a,(ix+003h)
	ld (ix+011h),a
	jr labaeh
	ld a,(ix+011h)
	sub (ix+003h)
	cp 040h
	ret c
	ld a,(ix+003h)
	add a,030h
	ld (ix+003h),a
	ld (ix+006h),000h
	ld (ix+00bh),05bh
	ld a,01eh
	ld (ix+00ch),a
	call sub_ad87h
labaeh:
	inc (ix+001h)
	ret
	ld c,000h
	ld hl,lacb1h
	call sub_ad3eh
	call sub_ad4ch
	bit 0,(ix+00ch)
	call nz,sub_ad68h
	call sub_add3h
	dec (ix+00ch)
	ret nz
	call sub_ad4ch
	call sub_add9h
	ld (ix+00ch),004h
	ld (ix+00eh),007h
	jr labaeh
	dec (ix+00ch)
	ret nz
	ld c,001h
	ld hl,lacb1h
	call sub_ad3eh
	call sub_add9h
	ld (ix+00ch),004h
	jr labaeh
	dec (ix+00ch)
	ret nz
	ld hl,CHKRAM
	call sub_ac0ch
	ld hl,00180h
	call sub_ac0ch
	ld hl,0fe80h
	call sub_ac0ch
	ld (ix+00ch),01eh
	jr labaeh
sub_ac0ch:
	ld a,(0c427h)
	cp (ix+005h)
	ld de,00280h
	jr nc,lac1ah
	ld de,0fd80h
lac1ah:
	ld a,(ix+003h)
	sub 018h
	ld c,a
	ld b,(ix+005h)
	ld a,011h
	jp 09f74h
	dec (ix+00ch)
	ret nz
	call sub_ad62h
	ld a,005h
	ld (0ce0eh),a
	ld a,(ix+003h)
	sub 040h
	ld (ix+003h),a
	ld (ix+00ch),05ah
	ld (ix+00eh),000h
	jp labaeh
	dec (ix+00ch)
	ret nz
	ld a,(ix+003h)
	add a,040h
	ld (ix+003h),a
	ld c,000h
	ld hl,lacb1h
	call sub_ad3eh
	ld hl,lac7dh
	ld a,(ix+010h)
	cp 007h
	jr c,lac69h
	ld (ix+010h),0ffh
lac69h:
	call ADD_HL_A
	ld a,(hl)
	ld (ix+005h),a
	call sub_ad87h
	inc (ix+010h)
	ld (ix+00ch),01eh
	jp labaeh
lac7dh:
	jr nc,$-46
	ld d,b
	and b
	ld b,b
	ret nz
	add a,b
	or b
	ld c,000h
	ld hl,lacb1h
	call sub_ad3eh
	call sub_ad4ch
	bit 0,(ix+00ch)
	call nz,sub_ad62h
	call sub_add3h
	dec (ix+00ch)
	ret nz
	call sub_ad4ch
	call sub_add9h
	ld (ix+00ch),004h
	ld (ix+001h),003h
	ld (ix+00eh),007h
	ret
lacb1h:
	ld e,e
	ld e,h
	ld e,l
	ld e,(hl)
	call sub_add9h
	xor a
	ld (ix+025h),a
	ld (ix+02ah),a
	ld (ix+02fh),a
	ld (ix+034h),a
	ld (ix+00eh),a
	ld (ix+00ch),03ch
	inc (ix+001h)
	call sub_ad1fh
	ld a,(ix+003h)
	sub 02bh
	ld e,a
	ld d,(ix+005h)
	ld c,02dh
	jp spawn_actor
	dec (ix+00ch)
	ret nz
	ld a,001h
	ld (0ce16h),a
	call sub_adcdh
	jp 099fdh
	ld (ix+006h),001h
	ld (ix+00eh),000h
	ld (ix+07eh),000h
	ld a,(0c427h)
	cp (ix+005h)
	ld c,057h
	ld de,00300h
	jr c,lad0dh
	ld de,0fd00h
	ld c,059h
lad0dh:
	ld (ix+00bh),c
	call actor_set_xvel
	ld de,0fd00h
	jp actor_set_yvel
	ld de,SETRD
	jp actor_add_yvel
sub_ad1fh:
	push ix
	ld ix,0d700h
	jr lad2fh
	push ix
	ld ix,0c800h
	ld b,007h
lad2fh:
	push bc
	call 099fdh
	ld de,00080h
	add ix,de
	pop bc
	djnz lad2fh
	pop ix
	ret
sub_ad3eh:
	ld a,(0c427h)
	cp (ix+005h)
	jp c,la636h
	inc c
lad48h:
	inc c
	jp la636h
sub_ad4ch:
	ld b,008h
	ld de,00025h
lad51h:
	ld hl,lad5ah
	call sub_ad74h
	djnz lad51h
	ret
lad5ah:
	ld (bc),a
	ld c,b
	ld (bc),a
	ld c,b
	ld (bc),a
	ld c,b
	ld (bc),a
	ld c,b
sub_ad62h:
	ld b,008h
	ld e,025h
	jr lad6ch
sub_ad68h:
	ld b,004h
	ld e,039h
lad6ch:
	ld c,000h
lad6eh:
	call sub_ad79h
	djnz lad6eh
	ret
sub_ad74h:
	ld a,d
	call ADD_HL_A
	ld c,(hl)
sub_ad79h:
	push ix
	pop hl
	ld a,e
	call ADD_HL_A
	ld (hl),c
	inc d
	ld a,e
	add a,005h
	ld e,a
	ret
sub_ad87h:
	ld a,(ix+005h)
	sub 010h
	ld h,a
	ld l,091h
	ld de,08080h
	ld bc,02020h
	ld a,004h
	jp 0494dh
	ld hl,0ce0eh
	ld a,(hl)
	dec a
	ret m
	ld (hl),000h
	ld de,ladc3h
	call lookup_word_tbl
	ex de,hl
	ld a,(0ce0fh)
	sub 010h
	ld d,a
	ld e,091h
	ld bc,02020h
	ld a,h
	cp 080h
	jr z,ladbeh
	ld a,048h
	jp 049e2h
ladbeh:
	ld a,001h
	jp 0494dh
ladc3h:
	add a,b
	nop
	add a,b
	jr nz,lad48h
	ld b,b
	add a,b
	ld h,b
	add a,b
	add a,b
sub_adcdh:
	ld a,005h
	ld (0ce0eh),a
	ret
sub_add3h:
	bit 0,(ix+00ch)
	jr nz,sub_adcdh
sub_add9h:
	ld a,(ix+00bh)
	sub 05ah
	cp 005h
	ret nc
	ld (0ce0eh),a
	ret
	ld (ix+006h),001h
	ld de,CHKRAM
	call actor_set_yvel
	call actor_set_xvel_scroll
	ld (ix+00bh),05fh
	ld (ix+010h),000h
	ld (ix+011h),03ch
	ret
	bit 0,(ix+001h)
	jr nz,lae3dh
	ld d,(ix+005h)
	ld e,(ix+003h)
	call 07b9fh
	jr c,lae13h
	jp lb345h
lae13h:
	ld a,(ix+003h)
	and 0f0h
	ld (ix+003h),a
	inc (ix+001h)
	ld de,00140h
	ld (ix+00bh),061h
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,lae34h
	ld de,0fec0h
	ld (ix+00bh),05fh
lae34h:
	call actor_set_xvel_scroll
	ld de,CHKRAM
	jp actor_set_yvel
lae3dh:
	call sub_af1fh
	ld a,010h
	bit 7,(ix+00ah)
	jr z,lae4ah
	ld a,0f8h
lae4ah:
	add a,(ix+005h)
	ld d,a
	ld e,(ix+003h)
	call 07b9fh
	jp nc,laefdh
	ld d,(ix+005h)
	ld bc,00808h
	bit 7,(ix+00ah)
	jr nz,lae68h
	call 07bc5h
	jr lae6bh
lae68h:
	call 07c21h
lae6bh:
	jp c,laefdh
	ld (ix+006h),001h
	call sub_af47h
	cp 02eh
	jr nc,lae90h
	ld de,00140h
	ld a,(0c427h)
	cp (ix+005h)
	jr c,lae87h
	ld de,0fec0h
lae87h:
	call actor_set_xvel_scroll
	ld (ix+010h),001h
	jr laea9h
lae90h:
	cp 05ch
	jr c,laea9h
	ld de,00140h
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,laea2h
	ld de,0fec0h
laea2h:
	call actor_set_xvel_scroll
	ld (ix+010h),000h
laea9h:
	ld a,(ix+005h)
	cp 0f0h
	call nc,sub_af33h
	cp 00fh
	call c,sub_af3dh
laeb6h:
	bit 1,(ix+001h)
	jr nz,laef0h
	call sub_af47h
	cp 02ah
	jr nc,laee6h
	bit 0,(ix+010h)
	ret z
laec8h:
	set 1,(ix+001h)
	push ix
	pop hl
	ld (0cffch),hl
	ld hl,CHKRAM
	ld de,00400h
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,laee3h
	ld de,0fc00h
laee3h:
	jp 09f68h
laee6h:
	cp 060h
	ret c
	bit 0,(ix+010h)
	ret nz
	jr laec8h
laef0h:
	dec (ix+011h)
	ret nz
	ld (ix+011h),03ch
	res 1,(ix+001h)
	ret
laefdh:
	ld (ix+006h),000h
	call sub_af47h
	cp 03eh
	jr c,laf13h
	cp 04ch
	jr nc,laf19h
	ld (ix+006h),001h
	jp sub_a649h
laf13h:
	ld (ix+010h),001h
	jr laeb6h
laf19h:
	ld (ix+010h),000h
	jr laeb6h
sub_af1fh:
	ld c,000h
	ld a,(0c003h)
	and 008h
	jr z,laf29h
	inc c
laf29h:
	ld hl,laf2fh
	jp sub_ad3eh
laf2fh:
	ld e,a
	ld h,b
	ld h,c
	ld h,d
sub_af33h:
	bit 7,(ix+00ah)
	ret nz
	ld (ix+006h),000h
	ret
sub_af3dh:
	bit 7,(ix+00ah)
	ret z
	ld (ix+006h),000h
	ret
sub_af47h:
	ld a,(0c427h)
	sub (ix+005h)
	ret nc
	neg
	ret
	ld de,CHKRAM
	call actor_set_yvel
	ld (ix+011h),030h
	xor a
	ld (ix+02fh),a
	ld (ix+034h),a
	ld (ix+00eh),a
	ret
	ld a,(ix+001h)
	call DISPATCH_A
	ld (hl),d
	xor a
	push bc
	xor a
	inc a
	or b
	dec (ix+011h)
	jr z,laf85h
	ld c,026h
	ld a,(ix+011h)
	cp 00ch
	jr nc,laf81h
	dec c
laf81h:
	ld (ix+00bh),c
	ret
laf85h:
	ld (ix+00eh),007h
	ld a,(ix+025h)
	ld (ix+02fh),a
	ld (ix+034h),045h
	call sub_afa2h
	ld (ix+00ch),010h
	inc (ix+001h)
	ld (ix+006h),001h
	ret
sub_afa2h:
	ld a,(0c427h)
	sub (ix+005h)
	jr c,lafb7h
	ld (ix+012h),000h
	ld (ix+00bh),021h
	ld de,00220h
	jr lafc2h
lafb7h:
	ld (ix+012h),001h
	ld (ix+00bh),023h
	ld de,0fde0h
lafc2h:
	jp actor_set_xvel_scroll
	ld a,(ix+005h)
	bit 7,(ix+00ah)
	ld c,010h
	jr z,lafd2h
	ld c,0f0h
lafd2h:
	add a,c
	ld d,a
	ld e,(ix+003h)
	call 07b9fh
	jr nc,lb004h
	ld d,(ix+005h)
	ld e,(ix+003h)
	ld b,008h
	ld c,008h
	ld a,(ix+012h)
	and a
	jr nz,laff8h
	ld a,(ix+005h)
	cp 0f0h
	jr nc,lb004h
	call 07bc5h
	jr lb002h
laff8h:
	ld a,(ix+005h)
	cp 010h
	jr c,lb004h
	call 07c21h
lb002h:
	jr nc,lb018h
lb004h:
	ld a,(ix+012h)
	xor 001h
	ld (ix+012h),a
	ld e,(ix+009h)
	ld d,(ix+00ah)
	call sub_a183h
	call actor_set_xvel_scroll
lb018h:
	bit 2,(ix+00ch)
	ld c,021h
	jr z,lb021h
	inc c
lb021h:
	ld a,(ix+012h)
	and a
	jr nz,lb029h
	inc c
	inc c
lb029h:
	ld (ix+00bh),c
	dec (ix+00ch)
	ret nz
	ld (ix+006h),000h
	ld (ix+00ch),004h
	inc (ix+001h)
	ret
	dec (ix+00ch)
	ret nz
	call sub_afa2h
	ld (ix+00ch),030h
	ld (ix+006h),001h
	dec (ix+001h)
	ret
	ld (ix+011h),040h
	xor a
	ld (ix+006h),a
	ld (ix+00eh),a
	ld (ix+02fh),a
	ld (ix+034h),a
	ld (ix+00bh),026h
	ld (ix+001h),a
	ret
	ld (ix+006h),001h
	ld (ix+010h),000h
	ld (ix+00ch),001h
	bit 7,(ix+00ah)
	ld c,016h
	jr nz,lb07dh
	inc c
lb07dh:
	ld (ix+00bh),c
	jr lb08dh
	call sub_b0bch
	dec (ix+00ch)
	ret nz
	ld (ix+00ch),010h
lb08dh:
	ld a,(0c425h)
	ld de,0ff00h
	inc a
	cp (ix+003h)
	jr c,lb0a6h
	ld de,00100h
	sub 018h
	cp (ix+003h)
	jr nc,lb0a6h
	ld de,CHKRAM
lb0a6h:
	call actor_set_yvel
	ld de,0fee0h
	ld hl,0c427h
	ld a,(ix+005h)
	sub (hl)
	jr nc,lb0b8h
	ld de,SETC
lb0b8h:
	call actor_set_xvel
	ret
sub_b0bch:
	ld a,016h
	bit 2,(ix+00ch)
	jr z,lb0c5h
	inc a
lb0c5h:
	bit 7,(ix+00ah)
	jr nz,lb0cdh
	add a,002h
lb0cdh:
	ld (ix+00bh),a
	ret
	ld (ix+001h),002h
	ld de,00180h
	call actor_set_yvel
	ld de,00300h
	ld a,(0c427h)
	sub (ix+005h)
	call c,sub_a183h
	call actor_set_xvel_scroll
	ld (ix+006h),001h
	ld (ix+011h),000h
	ld a,(ix+002h)
	ld (ix+012h),a
	ld a,(ix+003h)
	ld (ix+013h),a
	ret
	ld a,(ix+001h)
	dec a
	jr z,lb145h
	dec a
	jp z,lb186h
	ld (ix+00bh),01ah
	ld (ix+006h),000h
	ld a,(0c425h)
	sub (ix+003h)
	cp 050h
	ret nc
	ld c,01bh
	ld a,(0c427h)
	sub (ix+005h)
	ld de,00180h
	jr nc,lb12eh
	ld de,0fe80h
	neg
	ld c,01eh
lb12eh:
	cp 040h
	ret nc
	ld (ix+00bh),c
	call actor_set_xvel
	ld (ix+006h),001h
	ld de,00180h
	call actor_set_yvel
	inc (ix+001h)
	ret
lb145h:
	ld a,(0c425h)
	sub (ix+005h)
	sub 004h
	cp 010h
	jr nc,lb15fh
	ld a,(ix+003h)
	ld (ix+013h),a
	ld (ix+015h),000h
	ld (ix+001h),002h
lb15fh:
	ld a,(ix+011h)
	rra
	rra
	rra
	inc (ix+011h)
	and 003h
	ld hl,lb17eh
	bit 7,(ix+00ah)
	jr z,lb176h
	ld hl,lb182h
lb176h:
	call ADD_HL_A
	ld a,(hl)
	ld (ix+00bh),a
	ret
lb17eh:
	ld e,01fh
	ld e,020h
lb182h:
	dec de
	inc e
	dec de
	dec e
lb186h:
	call lb15fh
	ld de,00019h
	ld a,(ix+003h)
	cp (ix+013h)
	jr c,lb197h
	ld de,0ffe7h
lb197h:
	jp actor_add_yvel
	call sub_b219h
	ld (ix+011h),000h
	ld c,023h
	ld a,(ix+003h)
	add a,00ch
	ld e,a
	ld a,(ix+005h)
	cp 080h
	ld b,0fdh
	jr c,lb1b4h
	ld b,004h
lb1b4h:
	add a,b
	ld d,a
	push ix
	call spawn_actor
	pop ix
	ld a,(0cf31h)
	and a
	ret nz
	ld a,001h
	ld (0cf0ch),a
	jp 099fdh
	call sub_b1eeh
	bit 0,(ix+001h)
	jr nz,lb1e5h
	call sub_af47h
	cp 038h
	ret nc
	ld (ix+00ch),008h
	ld (ix+006h),000h
	inc (ix+001h)
	ret
lb1e5h:
	dec (ix+00ch)
	ret nz
	ld (ix+006h),001h
	ret
sub_b1eeh:
	inc (ix+011h)
	ld c,000h
	ld a,(ix+011h)
	cp 007h
	jr c,lb210h
	ld c,001h
	cp 00dh
	jr c,lb210h
	ld c,002h
	cp 013h
	jr c,lb210h
	ld c,001h
	cp 018h
	jr c,lb210h
	ld (ix+011h),000h
lb210h:
	ld hl,lb216h
	jp la636h
lb216h:
	ld l,l
	ld l,(hl)
	adc a,l
sub_b219h:
	ld (ix+006h),001h
	ld a,r
	srl a
	srl a
	srl a
	ld b,a
	ld a,03ch
	sub b
	ld (ix+00ch),a
	ld a,(ix+000h)
	cp 00dh
	jr nz,lb23bh
	ld (ix+001h),004h
	ld (ix+006h),000h
lb23bh:
	ld de,0fd80h
	ld (ix+00bh),067h
	ld (ix+010h),001h
	call actor_set_xvel
	ld de,CHKRAM
	jp actor_set_yvel
	ld a,(ix+001h)
	call DISPATCH_A
	ld e,a
	or d
	ld l,a
	or d
	adc a,h
	or d
	adc a,0b2h
	ld hl,0cdb3h
	ld b,a
	xor a
	cp 03ch
	ret nc
	ld de,CHKRAM
	call actor_set_xvel
	inc (ix+001h)
	ret
	call lb345h
	ld d,(ix+005h)
	ld e,(ix+003h)
	call 07b9fh
	jr c,lb27dh
lb27dh:
	inc (ix+001h)
lb280h:
	call sub_a9a9h
	ld (ix+006h),000h
	ld (ix+00ch),002h
	ret
	ld c,000h
	ld hl,lb341h
	call sub_ad3eh
	dec (ix+00ch)
	ret nz
	inc (ix+001h)
	ld de,0fda0h
	ld a,(ix+003h)
	cp 050h
	jr c,lb2aeh
	ld a,r
	and 003h
	jr nz,lb2aeh
	ld de,0f8e0h
lb2aeh:
	call actor_set_yvel
lb2b1h:
	ld (ix+006h),001h
	ld de,00220h
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,lb2c3h
	ld de,0fde0h
lb2c3h:
	call actor_set_xvel
	ld c,001h
	ld hl,lb341h
	jp sub_ad3eh
	call lb345h
	call sub_b307h
	ld de,CHKRAM
	call c,sub_a649h
	ld d,(ix+005h)
	ld e,(ix+003h)
	bit 7,(ix+008h)
	jr z,lb2f4h
	ld a,e
	sub 010h
	ld e,a
	call 07b9fh
	ret nc
	ld de,CHKRAM
	jp actor_set_yvel
lb2f4h:
	call 07b9fh
	ret nc
	ld c,000h
	ld hl,lb341h
	call sub_ad3eh
	ld (ix+001h),002h
	jp lb280h
sub_b307h:
	ld d,(ix+005h)
	ld e,(ix+003h)
	ld bc,00808h
	ld a,(ix+00ah)
	or (ix+009h)
	ret z
	bit 7,(ix+00ah)
	jp nz,07c1ah
	jp 07bbeh
	ld c,000h
	ld hl,lb341h
	call sub_ad3eh
	call sub_af47h
	cp 03ch
	jr c,lb334h
	dec (ix+00ch)
	ret nz
lb334h:
	ld de,0ffffh
	call actor_set_yvel
	ld (ix+001h),003h
	jp lb2b1h
lb341h:
	ld h,a
	ld l,b
	ld l,d
	ld l,e
lb345h:
	ld de,000a0h
	jp actor_add_yvel
	ld a,(0c427h)
	ld b,(ix+005h)
	cp b
	ld de,00240h
	jr nc,lb35ah
	ld de,0fdc0h
lb35ah:
	call actor_set_xvel_scroll
	ld de,CHKRAM
	call actor_set_yvel
	ld (ix+006h),001h
	ld (ix+011h),000h
sub_b36bh:
	ld a,(0c427h)
	cp (ix+005h)
	ld c,047h
	jr c,lb377h
	ld c,049h
lb377h:
	inc (ix+012h)
	bit 3,(ix+012h)
	jr nz,lb381h
	inc c
lb381h:
	ld (ix+00bh),c
	ret
	call sub_b36bh
	ld a,(ix+001h)
	call DISPATCH_A
	sub h
	or e
	ld e,b
	or h
	or b
	or h
	ld a,(0c427h)
	ld b,a
	ld a,(ix+005h)
	add a,030h
	sub b
	cp 060h
	jr nc,lb3b0h
	ld a,(ix+005h)
	cp b
	ld de,0fdc0h
	jr c,lb3cah
	ld de,00240h
	jr lb3cah
lb3b0h:
	ld a,(0c427h)
	ld b,a
	ld a,(ix+005h)
	add a,050h
	sub b
	cp 0a0h
	jr c,lb3e2h
	ld a,(ix+005h)
	cp b
	ld de,00240h
	jr c,lb3cah
	ld de,0fdc0h
lb3cah:
	call actor_set_xvel_scroll
	ld a,(ix+012h)
	and 006h
	jr nz,lb3e2h
	ld (ix+010h),010h
	ld (ix+001h),002h
	ld (ix+006h),000h
	jr lb43eh
lb3e2h:
	ld e,(ix+003h)
	ld d,(ix+005h)
	ld bc,0080ch
	ld a,(ix+00ah)
	and 080h
	jr nz,lb3ffh
	call 07bc5h
	jr nc,lb40ah
	ld de,0fdc0h
	call actor_set_xvel_scroll
	jr lb40ah
lb3ffh:
	call 07c21h
	jr nc,lb40ah
	ld de,00240h
	call actor_set_xvel
lb40ah:
	ld e,(ix+003h)
	ld a,(ix+00ah)
	or a
	ld b,004h
	jr z,lb41ch
	ld b,009h
	jp p,lb41ch
	ld b,0fch
lb41ch:
	ld a,(ix+005h)
	add a,b
	ld d,a
	call 07b9fh
	jr c,lb43eh
	ld de,00240h
	bit 7,(ix+00ah)
	call nz,sub_a183h
	call actor_set_xvel
	ld de,0fb8fh
	call actor_set_yvel
	ld (ix+001h),001h
	ret
lb43eh:
	ld a,(ix+005h)
	cp 010h
	ld de,00240h
	jr c,lb455h
	cp 0eeh
	ld de,0fdc0h
	jr nc,lb455h
	ld e,(ix+009h)
	ld d,(ix+00ah)
lb455h:
	jp actor_set_xvel_scroll
	ld bc,0080ch
	ld e,(ix+003h)
	ld d,(ix+005h)
	bit 7,(ix+00ah)
	jr z,lb46eh
	call 07c21h
	jr nc,lb479h
	jr lb473h
lb46eh:
	call 07bc5h
	jr nc,lb479h
lb473h:
	ld de,CHKRAM
	call actor_set_xvel
lb479h:
	ld de,00068h
	call actor_add_yvel
	bit 7,(ix+008h)
	ret nz
	ld e,(ix+003h)
	ld a,(ix+00ah)
	bit 7,a
	ld b,008h
	jr nz,lb497h
	ld b,0fdh
	and a
	jr nz,lb497h
	ld b,005h
lb497h:
	ld a,(ix+005h)
	add a,b
	ld d,a
	call 07b9fh
	ret nc
	xor a
	ld (ix+001h),a
	ld (ix+002h),a
	call sub_a9a9h
	ld de,CHKRAM
	jp actor_set_yvel
	dec (ix+010h)
	ret nz
	ld a,r
	rra
	ld hl,0fb00h
	jr nc,lb4bfh
	ld hl,0f800h
lb4bfh:
	ld a,(0c427h)
	cp (ix+005h)
	ld de,00180h
	jr nc,lb4cdh
	ld de,0fe80h
lb4cdh:
	call 09f68h
	ld (ix+001h),000h
	ld (ix+006h),001h
	ret
	call sub_b618h
	ld (ix+006h),001h
	ld de,CHKRAM
	ld (ix+00eh),e
	call actor_set_xvel
	call actor_set_yvel
	ld (ix+010h),008h
	ret
	call sub_b618h
	ld a,(ix+001h)
	call DISPATCH_A
	ld (bc),a
	or l
	inc d
	or l
	ld a,(de)
	or l
	dec l
	or l
	call sub_b590h
	ret nz
	ld de,00200h
	call actor_set_yvel
	ld (ix+00eh),007h
	inc (ix+001h)
	ret
	call sub_b570h
	ret nc
	jr lb552h
	ld (ix+006h),000h
	dec (ix+010h)
	ret nz
	call sub_b607h
	ld (ix+010h),01eh
	inc (ix+001h)
	ret
	ld (ix+006h),001h
	call sub_b618h
	call sub_b5c8h
	jp nc,lb595h
	call sub_b5e7h
	jp nc,lb5f6h
	call sub_b5b5h
	ld de,CHKRAM
	call c,actor_set_xvel
	call sub_b5a5h
	jr c,lb552h
	dec (ix+010h)
	ret nz
lb552h:
	ld de,CHKRAM
	call actor_set_yvel
	call actor_set_xvel
	ld a,(ix+003h)
	and 0f8h
	ld (ix+003h),a
	ld (ix+006h),000h
	ld (ix+010h),01eh
	ld (ix+001h),002h
	ret
sub_b570h:
	call sub_b5b5h
	ld de,CHKRAM
	call c,actor_set_xvel
	call sub_b5e7h
	jr c,lb586h
	ld de,00040h
	call actor_add_yvel
	xor a
	ret
lb586h:
	ld a,(ix+003h)
	and 0f8h
	ld (ix+003h),a
	scf
	ret
sub_b590h:
	dec (ix+010h)
	ret nz
	ret
lb595h:
	ld (ix+001h),001h
	call sub_b607h
	ld de,00200h
	ld de,0fd00h
	jp actor_set_yvel
sub_b5a5h:
	ld a,(ix+005h)
	bit 7,(ix+00ah)
	jr z,lb5b1h
	cp 010h
	ret
lb5b1h:
	cp 0e8h
	ccf
	ret
sub_b5b5h:
	ld e,(ix+003h)
	ld d,(ix+005h)
	ld a,d
	or e
	ret z
	bit 7,(ix+00ah)
	jp z,07bbeh
	jp 07c1ah
sub_b5c8h:
	ld a,(0c425h)
	sub 010h
	cp (ix+003h)
	ccf
	ret c
	ld e,(ix+003h)
	ld d,(ix+005h)
	ld a,008h
	bit 7,(ix+00ah)
	jr z,lb5e2h
	ld a,0f8h
lb5e2h:
	add a,d
	ld d,a
	jp 07baah
sub_b5e7h:
	xor a
	bit 7,(ix+008h)
	ret nz
	ld e,(ix+003h)
	ld d,(ix+005h)
	jp 07baah
lb5f6h:
	ld de,CHKRAM
	call actor_set_xvel
	ld de,00200h
	call actor_set_yvel
	ld (ix+001h),001h
	ret
sub_b607h:
	ld a,(0c427h)
	cp (ix+005h)
	ld de,001c0h
	jr nc,lb615h
	ld de,0fe40h
lb615h:
	jp actor_set_xvel
sub_b618h:
	ld a,(0d000h)
	ld de,lb645h+1
	call lookup_word_tbl
	ld a,(0d001h)
	srl a
	push af
	call ADD_DE_A
	pop af
	ld a,(de)
	jr c,lb632h
	rra
	rra
	rra
	rra
lb632h:
	and 00fh
	ld hl,lb649h
	call ADD_HL_A
	ld a,(hl)
	inc (ix+00ch)
	bit 4,(ix+00ch)
	jr z,lb645h
	inc a
lb645h:
	ld (ix+00bh),a
	ret
lb649h:
	nop
	sbc a,e
	sbc a,l
	sbc a,a
	and c
	ld l,h
	or (hl)
	ld l,a
	or (hl)
	ld (hl),d
	or (hl)
	ld (hl),l
	or (hl)
	ld a,d
	or (hl)
	ld a,(hl)
	or (hl)
	add a,e
	or (hl)
	adc a,b
	or (hl)
	adc a,e
	or (hl)
	sub c
	or (hl)
	sub a
	or (hl)
	sbc a,e
	or (hl)
	and b
	or (hl)
	and (hl)
	or (hl)
	xor h
	or (hl)
	ld (03332h),a
	inc sp
	inc sp
	inc sp
	ld de,03113h
	ld b,h
	ld de,01301h
	jr nc,lb6aeh
	ld bc,03113h
	inc sp
	inc sp
	inc b
	ld de,02000h
	nop
	nop
	inc sp
	jr nc,lb69dh
	nop
	inc b
	ld b,h
	ld b,h
	ld b,h
	ld b,h
	ld b,h
	ld b,h
	djnz lb6d3h
	nop
	ld b,c
	ld de,04414h
	ld b,c
	ld b,h
	ld b,h
	ld b,h
	ld b,h
lb69dh:
	ld b,h
	ld b,h
	ld b,c
	ld de,01111h
	ld de,01111h
	ld de,04444h
	ld b,b
	ld b,h
	inc b
	ld b,h
	ld b,h
lb6aeh:
	ld b,h
	ld b,h
	ld b,h
	ld b,h
	ld a,(0ce0bh)
	or a
	jr nz,lb6cch
	ld a,(0ce00h)
	dec a
	ret m
	call DISPATCH_A
	ld (0e2beh),a
	cp h
	ld e,(hl)
	cp b
	dec l
	cp d
	jp m,lb7bbh
	ld h,l
lb6cch:
	ld a,(0ce10h)
	call DISPATCH_A
	ret po
lb6d3h:
	or (hl)
	jp pe,0f4b6h
	or (hl)
	dec c
	or a
	jp pe,03db6h
	or a
	ld e,b
	or a
	call 0780dh
	ld a,03ch
	ld (0ce02h),a
	jr lb6efh
	ld hl,0ce02h
	dec (hl)
	ret nz
lb6efh:
	ld hl,0ce10h
	inc (hl)
	ret
	call 057c7h
	xor a
	ld (0ce11h),a
	ld (0ce14h),a
	ld c,022h
	ld de,07840h
	call spawn_actor
	ld a,0b4h
	ld (0ce02h),a
	jr lb6efh
	ld a,(0ce11h)
	and a
	jr nz,lb72ch
	ld a,(0ce14h)
	and a
	ret z
	ld hl,0ce02h
	dec (hl)
	ret nz
	ld a,006h
	ld (0ce10h),a
	ld a,090h
	ld (0ce02h),a
	ld a,08ch
	jp 050a6h
lb72ch:
	ld a,000h
	call 050a6h
	ld a,08ch
	call 050a6h
	ld a,096h
	ld (0ce02h),a
	jr lb6efh
	ld a,(0c003h)
	rra
	ret c
	ld a,(0c415h)
	cp 020h
	jr nc,lb751h
	ld a,001h
	call 050a6h
	jp 04658h
lb751h:
	ld a,03ch
	ld (0ce02h),a
	jr lb6efh
	ld hl,0ce02h
	dec (hl)
	ret nz
	ld a,0e0h
	ld (0c425h),a
	ld hl,0d600h
	ld b,080h
lb767h:
	ld (hl),0e0h
	inc hl
	djnz lb767h
	xor a
	ld (0ce0bh),a
	ld (0ce00h),a
	ld (0ce0ch),a
	ld (0ce11h),a
	inc a
	ld (0c409h),a
	ret
	ld a,05ah
	ld (ix+010h),a
	ld a,001h
	ld (0ce0ch),a
	ld (ix+00bh),08fh
	ld (ix+006h),000h
	ld (ix+00eh),000h
	ld (ix+00ch),000h
	ld (ix+07eh),000h
	ld de,CHKRAM
	call actor_set_xvel
	ld de,00100h
	jp actor_set_yvel
	ld a,(ix+001h)
	call DISPATCH_A
	or h
	or a
	rra
	cp b
	ld b,(hl)
	cp b
	ld a,(0c003h)
	and 001h
	ld c,0ffh
lb7bbh:
	jr nz,lb7beh
	inc c
lb7beh:
	call sub_b7d2h
	dec (ix+010h)
	ret nz
	ld c,0ffh
	call sub_b7d2h
	ld (ix+006h),001h
	inc (ix+001h)
	ret
sub_b7d2h:
	ld a,(0d000h)
	ld de,lb801h
	sub 003h
	jr z,lb7dfh
	ld de,lb810h
lb7dfh:
	ld a,(ix+00bh)
	sub 08fh
	ld b,a
	add a,a
	add a,a
	add a,b
	call ADD_DE_A
	push ix
	pop hl
	ld a,025h
	add a,l
	ld l,a
	ld b,005h
lb7f4h:
	ld a,(de)
	inc de
	and c
	ld (hl),a
	ld a,005h
	add a,l
	ld l,a
	djnz lb7f4h
	ld (hl),000h
	ret
lb801h:
	ld c,008h
	ld b,002h
	nop
	ld c,008h
	ld b,004h
	ld (bc),a
	ex af,af'
	ld b,004h
	ld (bc),a
	nop
lb810h:
	ld c,008h
	rlca
	ld (bc),a
	nop
	ld c,008h
	rlca
	dec b
	ld (bc),a
	ex af,af'
	rlca
	dec b
	ld (bc),a
	nop
	call sub_b846h
	ld e,(ix+003h)
	ld d,(ix+005h)
	call 07b9fh
	ret nc
	ld (ix+006h),000h
	ld (ix+00bh),08fh
	ld c,0ffh
	call sub_b7d2h
	ld (ix+00eh),002h
	ld a,001h
	ld (0ce14h),a
	inc (ix+001h)
	ret
sub_b846h:
	ld a,(ix+00ch)
	inc (ix+00ch)
	rra
	and 003h
	ld hl,lb85ah
	call ADD_HL_A
	ld a,(hl)
	ld (ix+00bh),a
	ret
lb85ah:
	adc a,a
	sub b
	sub c
	sub b
	ld a,(0ce01h)
	call DISPATCH_A
	ld l,b
	cp b
	ld a,e
	cp b
	ld c,014h
	ld de,030c5h
	call spawn_actor
	ld c,014h
	ld de,0d0c5h
	call spawn_actor
	jp lbe44h
	ld a,(0ce15h)
	and a
	ret z
	jp lbe4eh
	ld (ix+00bh),036h
	ld (ix+010h),020h
	ld de,CHKRAM
	call actor_set_yvel
	ld (ix+014h),002h
	ld (ix+015h),001h
	ret
	ld a,(ix+001h)
	call DISPATCH_A
	xor b
	cp b
	or h
	cp b
	rst 10h
	cp b
	ld h,a
	cp c
	dec (ix+010h)
	ret nz
	inc (ix+001h)
	ld (ix+006h),001h
	ret
	ld de,0fdd0h
	ld (ix+012h),001h
	ld a,(0c427h)
	cp (ix+005h)
	jr c,lb8cah
	ld de,00230h
	ld (ix+012h),000h
lb8cah:
	call actor_set_xvel
	inc (ix+001h)
	ld (ix+013h),007h
	jp lb9bdh
	call sub_b9d6h
	dec (ix+010h)
	jr nz,lb937h
	call lb9bdh
	ld (ix+013h),007h
	inc (ix+017h)
	bit 0,(ix+017h)
	jr z,lb8f7h
	bit 7,(ix+00ah)
	jr nz,lb914h
	jr lb8ffh
lb8f7h:
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,lb914h
lb8ffh:
	ld de,0fdd0h
	call actor_set_xvel
	ld (ix+012h),001h
	ld a,(0c427h)
	cp (ix+005h)
	jr c,lb929h
	call sub_b9d6h
lb914h:
	ld de,00230h
	call actor_set_xvel
	ld (ix+012h),000h
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,lb929h
	jp sub_b9d6h
lb929h:
	inc (ix+001h)
	ld (ix+006h),000h
	ld (ix+011h),030h
	jp sub_b9d6h
lb937h:
	ld a,(ix+005h)
	cp 020h
	jr c,lb941h
	cp 0e1h
	ret c
lb941h:
	bit 7,(ix+00ah)
	ld de,00230h
	call actor_set_xvel
	ld (ix+012h),000h
	ld (ix+005h),020h
	jr nz,lb962h
	ld de,0fdd0h
	call actor_set_xvel
	ld (ix+005h),0e0h
	inc (ix+012h)
lb962h:
	call sub_b9d6h
	jr lb9bdh
	dec (ix+011h)
	jr z,lb98ch
	ld a,008h
	bit 0,(ix+011h)
	jr z,lb976h
	ld a,04ch
lb976h:
	ld (ix+025h),002h
	ld (ix+02ah),a
	ld (ix+02fh),002h
	ld (ix+034h),a
	ld (ix+039h),002h
	ld (ix+03eh),a
	ret
lb98ch:
	ld a,(ix+003h)
	sub 038h
	ld e,a
	ld d,(ix+005h)
	ld a,040h
	call sub_a0f4h
	ld a,(ix+012h)
	rrca
	xor d
	call m,sub_a183h
	ld a,(ix+003h)
	sub 018h
	ld c,a
	ld b,(ix+005h)
	ld a,014h
	call 09f74h
	ld a,00ah
	call sub_a4efh
	dec (ix+001h)
	ld (ix+006h),001h
	ret
lb9bdh:
	ld a,r
	or 080h
	ld hl,lb9ceh
	and 007h
	call ADD_HL_A
	ld a,(hl)
	ld (ix+010h),a
	ret
lb9ceh:
	ld b,b
	ex af,af'
	jr nc,lb9e2h
	jr nz,lb9ech
	jr c,lb9feh
sub_b9d6h:
	ld hl,lba2ah
	bit 0,(ix+012h)
	jr z,lb9e2h
	ld hl,lba27h
lb9e2h:
	inc (ix+013h)
	ld a,(ix+013h)
	cp 008h
	jr nz,lba1ch
lb9ech:
	ld (ix+013h),000h
	bit 0,(ix+015h)
	jr z,lba0ah
	inc (ix+014h)
	ld a,(ix+014h)
	cp 003h
lb9feh:
	jr nz,lba1ch
	ld (ix+014h),001h
	ld (ix+015h),000h
	jr lba1ch
lba0ah:
	dec (ix+014h)
	ld a,(ix+014h)
	cp 0ffh
	jr nz,lba1ch
	ld (ix+014h),001h
	ld (ix+015h),001h
lba1ch:
	ld a,(ix+014h)
	call ADD_HL_A
	ld a,(hl)
	ld (ix+00bh),a
	ret
lba27h:
	inc sp
	inc (hl)
	dec (hl)
lba2ah:
	ld (hl),037h
	jr c,lba68h
	ld bc,0cdceh
	ld l,e
	ld b,b
	scf
	cp d
	ld c,(hl)
	cp d
	xor a
	ld (0ce07h),a
	ld c,015h
	ld de,0d0c0h
	call spawn_actor
	ld c,018h
	ld de,0d0a0h
	call spawn_actor
	jp lbe44h
	ld a,(0ce15h)
	and a
	ret z
	jp lbe4eh
	ld (ix+011h),000h
	ld (ix+010h),030h
	ld (ix+006h),001h
	ld de,CHKRAM
	call actor_set_xvel
lba68h:
	jp actor_set_yvel
	ld a,(ix+010h)
	and a
	call nz,sub_badah
	call sub_bac0h
	ld a,(ix+001h)
	dec a
	jr z,lba9eh
	ld (ix+00ch),020h
	ld a,(0c427h)
	sub (ix+005h)
	jr nc,lba90h
	add a,040h
	jr c,lba90h
	ld de,0fde0h
	jr lba93h
lba90h:
	ld de,00220h
lba93h:
	ld (0ce09h),de
	call actor_set_xvel
	inc (ix+001h)
	ret
lba9eh:
	call sub_baaah
	dec (ix+00ch)
	ret nz
	ld (ix+001h),000h
	ret
sub_baaah:
	ld a,(ix+005h)
	cp 0e0h
	jr nc,lbabah
	cp 010h
	ret nc
	ld de,00220h
	jp actor_set_xvel
lbabah:
	ld de,0fde0h
	jp actor_set_xvel
sub_bac0h:
	ld hl,lbad6h
	inc (ix+011h)
	ld a,(ix+011h)
	rra
	rra
	rra
	and 003h
	call ADD_HL_A
	ld a,(hl)
	ld (ix+00bh),a
	ret
lbad6h:
	ld a,c
	ld a,d
	ld a,e
	ld a,d
sub_badah:
	dec (ix+010h)
	ret nz
	ld a,001h
	ld (0ce07h),a
	ret
	ld (ix+006h),001h
	ld (ix+010h),000h
	ld de,CHKRAM
	call actor_set_yvel
	call actor_set_xvel
	call sub_bbe8h
	xor a
	ld (ix+011h),a
	ret
	ld a,(ix+001h)
	dec a
	jr z,lbb2ah
	dec a
	jp z,lbb96h
	call sub_bbc7h
	ret c
	ld a,(0ce07h)
	and a
	jr z,lbb1fh
	ld (ix+011h),000h
	ld de,0fa00h
	call actor_set_yvel
	inc (ix+001h)
	ret
lbb1fh:
	ld (ix+00bh),067h
	ld de,(0ce09h)
	jp actor_set_xvel
lbb2ah:
	call sub_bbc7h
	ret c
	inc (ix+011h)
	ld a,(ix+011h)
	ld c,067h
	cp 004h
	jr c,lbb3bh
	inc c
lbb3bh:
	call sub_bbedh
	call sub_bbdbh
	ld de,00060h
	call actor_add_yvel
	ld a,(ix+005h)
	cp 0e8h
	ld e,(ix+009h)
	ld d,(ix+00ah)
	push af
	call nc,sub_bb84h
	pop af
	cp 014h
	call c,sub_bb8dh
	bit 7,(ix+008h)
	ret nz
	ld e,(ix+003h)
	ld d,(ix+005h)
	call 07b9fh
	ret nc
	ld c,069h
	call sub_bbedh
	ld (ix+006h),000h
	ld a,(ix+003h)
	and 0f8h
	ld (ix+003h),a
	ld (ix+00ch),010h
	inc (ix+001h)
	ret
sub_bb84h:
	bit 7,d
	ret nz
	call sub_a183h
	jp actor_set_xvel
sub_bb8dh:
	bit 7,d
	ret z
	call sub_a183h
	jp actor_set_xvel
lbb96h:
	call sub_bbc7h
	ld (ix+006h),000h
	ret c
	dec (ix+00ch)
	ret nz
	ld a,(ix+003h)
	ld de,0f880h
	cp 080h
	jr nc,lbbafh
	ld de,0fa80h
lbbafh:
	ld a,r
	or 080h
	ld l,a
	ld h,000h
	add hl,hl
	add hl,de
	call actor_set_yvel
	ld (ix+006h),001h
	xor a
	ld (ix+011h),a
	ld (ix+001h),a
	ret
sub_bbc7h:
	ld a,(ix+010h)
	and a
	jr z,lbbd6h
	dec (ix+010h)
	ld (ix+006h),000h
	scf
	ret
lbbd6h:
	ld (ix+006h),001h
	ret
sub_bbdbh:
	dec (ix+012h)
	ret nz
	call sub_bbe8h
	call sub_a0ech
	jp 09f68h
sub_bbe8h:
	ld (ix+012h),030h
	ret
sub_bbedh:
	bit 7,(ix+00ah)
	ld a,c
	jr nz,lbbf6h
	add a,003h
lbbf6h:
	ld (ix+00bh),a
	ret
	ld a,(0ce01h)
	call DISPATCH_A
	inc b
	cp h
	rra
	cp h
	ld de,0a090h
	ld c,016h
	call spawn_actor
	call sub_bc30h
	call sub_bc30h
	call sub_bc30h
	call sub_bc30h
	xor a
	ld (0ce02h),a
	jp lbe44h
	ld a,(0ce15h)
	and a
	jp nz,lbe4eh
	ld hl,0ce02h
	dec (hl)
	ret nz
	ld (hl),080h
	jp sub_bc30h
sub_bc30h:
	ld hl,0cf20h
	ld a,(hl)
	inc (hl)
	and 007h
	add a,a
	ld hl,lbc4bh
	call ADD_HL_A
	ld c,(hl)
	inc hl
	ld b,(hl)
	ld de,CHKRAM
	ld h,e
	ld l,e
	ld a,016h
	jp 09f74h
lbc4bh:
	jr nc,lbc7dh
	add a,b
	ret nz
	jr nc,$-62
	ret nz
	jr nc,$+74
	add a,b
	and b
	add a,b
	ld l,b
	jr nc,$+106
	ret nz
	ld de,0fd80h
	call actor_set_xvel
	ld de,0fe00h
	call actor_set_yvel
	ld (ix+006h),000h
	ld (ix+00ch),01eh
	ld (ix+00bh),07ch
	ret
	ld a,(ix+001h)
	dec a
	jr z,lbc86h
	dec (ix+00ch)
lbc7dh:
	ret nz
	inc (ix+001h)
	ld (ix+006h),001h
	ret
lbc86h:
	ld e,(ix+007h)
	ld d,(ix+008h)
	ld hl,SYNCHR
	add hl,de
	ex de,hl
	call actor_set_yvel
	ld e,(ix+009h)
	ld d,(ix+00ah)
	ld a,(ix+005h)
	cp 0e8h
	push af
	call nc,sub_bcd0h
	pop af
	cp 018h
	call c,sub_bcd9h
	ld a,(ix+003h)
	cp 040h
	jr nc,lbcc0h
	ld e,(ix+007h)
	ld d,(ix+008h)
	bit 7,d
	jr z,lbcc0h
	call sub_a183h
	call actor_set_yvel
lbcc0h:
	ld e,(ix+003h)
	ld d,(ix+005h)
	call 07b9fh
	ret nc
	ld de,0fd00h
	jp actor_set_yvel
sub_bcd0h:
	bit 7,d
	ret nz
	call sub_a183h
	jp actor_set_xvel
sub_bcd9h:
	bit 7,d
	ret z
	call sub_a183h
	jp actor_set_xvel
	ld a,(0ce01h)
	call DISPATCH_A
	ret p
	cp h
	ret m
	cp h
	nop
	cp l
	jr $-65
	ld a,078h
	ld (0ce02h),a
	jp lbe44h
	ld hl,0ce02h
	dec (hl)
	ret nz
	jp lbe44h
	ld de,09090h
	ld c,013h
	call spawn_actor
	ld hl,08070h
	ld bc,02020h
	ld a,000h
	ld d,000h
	call 04911h
	jp lbe44h
	ld a,(0ce15h)
	and a
	ret z
	jp lbe4eh
	call sub_be14h
	ld a,(ix+001h)
	call DISPATCH_A
	ld l,l
	cp l
	and b
	cp l
	xor a
	ld (ix+009h),0f8h
	ld (ix+00ah),a
	ld (ix+007h),010h
	ld (ix+008h),a
	ld (ix+00bh),02bh
	ld (ix+006h),001h
	ld (ix+015h),03ch
	ld (ix+014h),008h
	ret
sub_bd4dh:
	dec (ix+014h)
	ld c,02bh
	bit 3,(ix+014h)
	jr z,lbd59h
	inc c
lbd59h:
	ld (ix+00bh),c
	ld de,DCOMPR
	ld a,(ix+003h)
	cp 0a0h
	jr c,lbd69h
	ld de,0ffe0h
lbd69h:
	add hl,de
	jp actor_add_yvel
	call sub_bd4dh
	ld a,(ix+005h)
	sub 010h
	cp 0e0h
	jr nc,lbd86h
	ld a,(0c427h)
	sub (ix+005h)
	jr nc,lbd83h
	neg
lbd83h:
	cp 008h
	ret nc
lbd86h:
	ld a,(ix+009h)
	cpl
	ld e,a
	ld a,(ix+00ah)
	cpl
	ld d,a
	inc de
	call actor_set_xvel
	ld (ix+012h),03fh
	ld (ix+013h),060h
	inc (ix+001h)
	ret
	dec (ix+013h)
	ld a,(ix+013h)
	and a
	jr nz,lbde4h
	inc (ix+013h)
	ld (ix+006h),000h
	dec (ix+012h)
	jr nz,lbde3h
	xor a
	ld (ix+009h),0f8h
	ld (ix+00ah),a
	ld a,(0c427h)
	cp (ix+005h)
	jr nc,lbdd3h
	ld a,(ix+009h)
	cpl
	ld e,a
	ld a,(ix+00ah)
	cpl
	ld d,a
	inc de
	call actor_set_xvel
lbdd3h:
	ld (ix+006h),001h
	ld (ix+001h),000h
	ld (ix+012h),02fh
	ld (ix+013h),04fh
lbde3h:
	ret
lbde4h:
	call sub_bd4dh
	ld a,(ix+005h)
	sub 010h
	cp 0e0h
	jr nc,lbdfdh
	ld a,(0c427h)
	sub (ix+005h)
	jr nc,lbdfah
	neg
lbdfah:
	cp 008h
	ret nc
lbdfdh:
	ld a,(ix+009h)
	cpl
	ld e,a
	ld a,(ix+00ah)
	cpl
	ld d,a
	inc de
	call actor_set_xvel
	ld (ix+012h),03fh
	ld (ix+013h),010h
	ret
sub_be14h:
	dec (ix+015h)
	ret nz
	ld (ix+015h),03ch
	call sub_a0ech
	ld a,(ix+003h)
	sub 010h
	ld c,a
	ld b,(ix+005h)
	push ix
	ld a,013h
	call 09f74h
	pop ix
	ret
	ld a,(0ce01h)
	call DISPATCH_A
	inc a
	cp (hl)
	ld c,c
	cp (hl)
	ld c,012h
	ld de,07040h
	call spawn_actor
lbe44h:
	ld hl,0ce01h
	inc (hl)
	ret
	ld a,(0ce15h)
	and a
	ret z
lbe4eh:
	xor a
	ld (0ce10h),a
	inc a
	ld (0ce0bh),a
	ret
	ld (ix+00bh),04fh
	ld (ix+006h),000h
	ld a,(0d000h)
	cp 003h
	ld (ix+013h),03ch
	jr z,lbe6eh
	ld (ix+013h),001h
lbe6eh:
	ld de,CHKRAM
	call actor_set_xvel
	jp actor_set_yvel
	inc (ix+014h)
	inc (ix+00ch)
	ld a,(ix+00ch)
	and 008h
	ld a,04eh
	jr z,lbe87h
	inc a
lbe87h:
	ld (ix+00bh),a
	ld a,(ix+001h)
	call DISPATCH_A
	sbc a,h
	cp (hl)
	xor c
	cp (hl)
	xor l
	cp (hl)
	rst 30h
	cp (hl)
	ld d,c
	cp a
	sbc a,c
	cp a
	dec (ix+013h)
	ret nz
	ld (ix+006h),001h
	ld (ix+001h),001h
	ret
	ld (ix+001h),002h
lbeadh:
	ld a,(0c425h)
	sub 030h
	ld b,030h
	jr c,lbeb7h
	ld b,a
lbeb7h:
	ld (ix+011h),b
	ld a,(ix+014h)
	and 001h
	ld a,048h
	jr z,lbec5h
	neg
lbec5h:
	ld c,a
	ld a,(0c427h)
	add a,c
	ld c,a
	ld (ix+012h),c
	ld a,(0c427h)
	ld h,a
	ld a,(0c425h)
	ld l,a
	push hl
	ld a,c
	ld (0c427h),a
	ld a,b
	ld (0c425h),a
	call sub_a0ech
	call actor_set_xvel
	ex de,hl
	call actor_set_yvel
	pop hl
	ld a,l
	ld (0c425h),a
	ld a,h
	ld (0c427h),a
	ld (ix+001h),003h
	ret
	bit 7,(ix+008h)
	ld a,(ix+003h)
	jr z,lbf04h
	cp 030h
	jr c,lbf30h
lbf04h:
	cp 090h
	jr nc,lbf30h
	ld a,(ix+005h)
	sub 020h
	cp 0b0h
	jr nc,lbf30h
	ld a,(ix+003h)
	add a,008h
	sub (ix+011h)
	cp 010h
	ret nc
	ld a,(ix+005h)
	add a,008h
	sub (ix+012h)
	cp 010h
	jr c,lbf30h
	ld a,(ix+005h)
	sub 020h
	cp 0c0h
	ret c
lbf30h:
	ld de,CHKRAM
	call actor_set_xvel
	call actor_set_yvel
	ld a,r
	srl a
	srl a
	neg
	add a,040h
	ld (ix+010h),a
	ld (ix+001h),004h
	ret
sub_bf4bh:
	call sub_a0ech
	jp 09f68h
	ld a,(ix+010h)
	cp 018h
	call z,sub_bf4bh
	dec (ix+010h)
	ret nz
	ld de,00280h
	call actor_set_yvel
	ld a,(0c427h)
	ld b,(ix+005h)
	cp b
	jr nc,lbf6fh
	ld c,a
	ld a,b
	ld b,c
lbf6fh:
	sub b
	ld d,a
	ld e,000h
	srl d
	rr e
	srl d
	rr e
	srl d
	rr e
	srl d
	rr e
	srl d
	rr e
	ld a,(0c427h)
	ld b,(ix+005h)
	cp b
	call c,sub_a183h
	call actor_set_xvel
	ld (ix+001h),005h
	ret
	ld de,0fff0h
	call actor_add_yvel
	ld a,(ix+005h)
	cp 019h
	ld b,002h
	jr c,lbfaeh
	cp 0e7h
	ld b,0feh
	jr c,lbfb5h
lbfaeh:
	ld (ix+009h),000h
	ld (ix+00ah),b
lbfb5h:
	bit 7,(ix+008h)
	ret z
	ld a,(ix+003h)
	cp 041h
	ret nc
	ld (ix+001h),002h
	jp lbeadh
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h
	rst 38h

; ===========================================================================
;  SEGMENT 0 - resident bank.  Paged at 0x4000-0x5FFF for the whole game and
;  holds the boot/init code, the interrupt handler, the bank-switch helpers
;  and the top-level game state machine.
;  (Origin is set by PHASE 0x4000 in VampireKiller.asm; regenerate the raw
;   disassembly with  tools/regen-seg.sh 0 0x4000 tools/seg00.blocks .)
;
;  BIOS entry-point names below are for readability only - they resolve to the
;  fixed MSX main-ROM addresses and are not emitted into the ROM.
; ===========================================================================
; ---- MSX main-ROM BIOS jump table ----------------------------------------
CHKRAM:	equ 0x0000
SYNCHR:	equ 0x0008
RDSLT:	equ 0x000c
CHRGTR:	equ 0x0010
WRSLT:	equ 0x0014
DCOMPR:	equ 0x0020
ENASLT:	equ 0x0024
WRTVDP:	equ 0x0047
CHGMOD:	equ 0x005f
WRTPSG:	equ 0x0093
RDPSG:	equ 0x0096
RSLREG:	equ 0x0138
SNSMAT:	equ 0x0141


; --- 16-byte MSX cartridge header (ROM offset 0) ---------------------------
;   +0  "AB"      magic identifying an MSX ROM cartridge
;   +2  INIT      entry point called at boot           -> 0x4075
;   +4  STATEMENT expansion BASIC statement handler    -> none (0)
;   +6  DEVICE    expansion device handler             -> none (0)
;   +8  TEXT      BASIC program pointer                -> none (0)
;   +10 reserved (6 bytes, 0)
rom_header_start:
	defb 041h		;4000	41		; 'A'  cartridge magic
	defb 042h		;4001	42		; 'B'
	defb 075h		;4002	75		; INIT lo  \ entry = 0x4075
	defb 040h		;4003	40		; INIT hi  /
	defb 000h		;4004	00		.
	defb 000h		;4005	00		.
	defb 000h		;4006	00		.
	defb 000h		;4007	00		.
	defb 000h		;4008	00		.
	defb 000h		;4009	00		.
	defb 000h		;400a	00		.
	defb 000h		;400b	00		.
	defb 000h		;400c	00		.
	defb 000h		;400d	00		.
	defb 000h		;400e	00		.
	defb 000h		;400f	00		.
rom_header_end:

; BLOCK 'data_4010' (start 0x4010 end 0x4028)
data_4010_start:
	defb 043h		;4010	43		C
	defb 000h		;4011	00		.
	defb 044h		;4012	44		D
	defb 000h		;4013	00		.
	defb 007h		;4014	07		.
	defb 000h		;4015	00		.
	defb 044h		;4016	44		D
	defb 000h		;4017	00		.
	defb 0e8h		;4018	e8		.
	defb 000h		;4019	00		.
	defb 0c0h		;401a	c0		.
	defb 004h		;401b	04		.
	defb 000h		;401c	00		.
	defb 011h		;401d	11		.
	defb 0c4h		;401e	c4		.
	defb 000h		;401f	00		.
	defb 0d0h		;4020	d0		.
	defb 012h		;4021	12		.
	defb 010h		;4022	10		.
	defb 0c4h		;4023	c4		.
	defb 000h		;4024	00		.
	defb 000h		;4025	00		.
	defb 005h		;4026	05		.
	defb 0c4h		;4027	c4		.
data_4010_end:
; ===========================================================================
;  INT_HANDLER - timer interrupt (H.TIMI hook, installed by INIT at 0xFD9F).
;  Runs once per VDP frame: per-frame sound/VDP work out of segs 14/15, then
;  the game tick.  Two guards keep a slow tick from re-entering itself.
; ===========================================================================
INT_HANDLER:
	di			;4028	f3		.
	ld a,(0e600h)		;4029	3a 00 e6	; hard re-entrancy guard (outer)
	or a			;402c	b7		.
	jp nz,l40c5h		;402d	c2 c5 40	; already inside a tick -> just read keys
l4030h:
	di			;4030	f3		.
	ld a,00eh		;4031	3e 0e		; page segment 14...
	ld (08000h),a		;4033	32 00 80	; ...into 0x8000-0x9FFF
	ld a,00fh		;4036	3e 0f		; page segment 15...
	ld (0a000h),a		;4038	32 00 a0	; ...into 0xA000-0xBFFF
	call 08964h		;403b	cd 64 89	; per-frame work in seg 14/15 (sound/VDP)
	di			;403e	f3		.
	ld a,(0f0f2h)		;403f	3a f2 f0	; restore game's page-2 segment...
	ld (08000h),a		;4042	32 00 80	; ...(0f0f2 = current seg at 0x8000)
	ld a,(0f0f3h)		;4045	3a f3 f0	; restore game's page-3 segment...
	ld (0a000h),a		;4048	32 00 a0	; ...(0f0f3 = current seg at 0xA000)
	ld hl,0c005h		;404b	21 05 c0	; soft guard: game-tick-in-progress flag
	bit 0,(hl)		;404e	cb 46		.
	jp nz,l405fh		;4050	c2 5f 40	; tick still running -> skip this frame
	inc (hl)		;4053	34		; mark tick in progress
	ei			;4054	fb		.
	call 04ba4h		;4055	cd a4 4b	; input / timers update
	call sub_414dh		;4058	cd 4d 41	; MAIN TICK (top-level state machine)
	xor a			;405b	af		.
	ld (0c005h),a		;405c	32 05 c0	; clear tick-in-progress flag
l405fh:
	ei			;405f	fb		.
	ret			;4060	c9		.
; ADD_HL_A - HL += A (unsigned), carry into H.  Indexes byte tables.
ADD_HL_A:
	add a,l			;4061	85		.
	ld l,a			;4062	6f		.
	ret nc			;4063	d0		.
	inc h			;4064	24		.
	ret			;4065	c9		.
; ADD_DE_A - DE += A (unsigned), carry into D.
ADD_DE_A:
	add a,e			;4066	83		.
	ld e,a			;4067	5f		.
	ret nc			;4068	d0		.
	inc d			;4069	14		.
	ret			;406a	c9		.
; DISPATCH_A - jump-table dispatch on A.  The word table is inlined right
; after the `call`; jumps to table[A].
DISPATCH_A:
	pop hl			;406b	e1		; HL = address of inline word table
	add a,a			;406c	87		; A *= 2 (word index)
	call ADD_HL_A		;406d	cd 61 40	; HL += A -> &table[A]
	ld e,(hl)		;4070	5e		; DE = table[A]
	inc hl			;4071	23		.
	ld d,(hl)		;4072	56		.
	ex de,hl		;4073	eb		.
	jp (hl)			;4074	e9		; jump to selected handler
; ===========================================================================
;  INIT - cartridge entry point (from header +2).  Called by the BIOS at boot:
;  find this ROM's slot, page it into CPU page 2 (0x8000-0xBFFF), clear RAM,
;  init subsystems, install the interrupt hook, then idle - the game then runs
;  entirely from INT_HANDLER.
; ===========================================================================
INIT:
	di			;4075	f3		.
	ld sp,0f0f0h		;4076	31 f0 f0	; stack near top of RAM
	call RSLREG		;4079	cd 38 01	; A = primary slot select register
	rrca			;407c	0f		; rotate page-2 slot bits (6,7)...
	rrca			;407d	0f		; ...down to bits 0,1
	and 003h		;407e	e6 03		; C = this cartridge's primary slot #
	ld c,a			;4080	4f		.
	ld b,000h		;4081	06 00		.
	ld hl,0fcc1h		;4083	21 c1 fc	; EXPTBL: is that primary slot expanded?
	add hl,bc		;4086	09		.
	ld a,(hl)		;4087	7e		.
	and 080h		;4088	e6 80		; bit7 = slot is expanded
	or c			;408a	b1		.
	ld c,a			;408b	4f		; C = slot id (primary + expanded flag)
	inc hl			;408c	23		; advance EXPTBL(0xFCC1) -> SLTTBL(0xFCC5)
	inc hl			;408d	23		.
	inc hl			;408e	23		.
	inc hl			;408f	23		.
	ld a,(hl)		;4090	7e		; SLTTBL: last value written to slot reg
	and 00ch		;4091	e6 0c		; keep page-2 secondary-slot bits
	or c			;4093	b1		; full slot id for ENASLT
	ld h,080h		;4094	26 80		; H = 0x80 -> target CPU page 2 (0x8000)
	call ENASLT		;4096	cd 24 00	; page this ROM into 0x8000-0xBFFF
	ld hl,0c000h		;4099	21 00 c0	; clear work RAM 0xC000..0xF0EF:
	ld de,0c001h		;409c	11 01 c0	.
	ld bc,030efh		;409f	01 ef 30	; length 0x30EF
	ld (hl),000h		;40a2	36 00		.
	ldir			;40a4	ed b0		; (hl)=0 then propagate via LDIR
	call sub_533dh		;40a6	cd 3d 53	; init subsystem
	call sub_5c99h		;40a9	cd 99 5c	; init subsystem
	call sub_533dh		;40ac	cd 3d 53	.
	call sub_4b60h		;40af	cd 60 4b	; init subsystem
	di			;40b2	f3		.
	ld a,0c3h		;40b3	3e c3		; opcode for JP
	ld (0fd9fh),a		;40b5	32 9f fd	; install timer-interrupt hook (H.TIMI)...
	ld hl,data_4010_end	;40b8	21 28 40	; ...JP INT_HANDLER (=data_4010_end, 0x4028)
	ld (0fda0h),hl		;40bb	22 a0 fd	.
	xor a			;40be	af		.
	ld (0f3dbh),a		;40bf	32 db f3	.
	ei			;40c2	fb		; interrupts on: game now runs from the tick
l40c3h:
	jr l40c3h		;40c3	18 fe		; idle forever; work happens in INT_HANDLER
; l40c5h - light path when INT_HANDLER re-enters during a busy tick: just
; sample the SPACE key / joystick trigger so input isn't missed.
l40c5h:
	ld a,007h		;40c5	3e 07		; scan keyboard matrix row 7...
	call SNSMAT		;40c7	cd 41 01	.
	cpl			;40ca	2f		.
	and 010h		;40cb	e6 10		; ...bit 4 = SPACE
	ld b,a			;40cd	47		.
	ld a,001h		;40ce	3e 01		; scan row 1...
	call SNSMAT		;40d0	cd 41 01	.
	cpl			;40d3	2f		.
	and 080h		;40d4	e6 80		; ...bit 7
	or b			;40d6	b0		; merge the two key bits
	ld hl,0e610h		;40d7	21 10 e6	! . .
	ld c,(hl)		;40da	4e		N
	ld (hl),a		;40db	77		w
	xor c			;40dc	a9		.
	and (hl)		;40dd	a6		.
	ld c,a			;40de	4f		O
	ld hl,0e601h		;40df	21 01 e6	! . .
	ld a,(hl)		;40e2	7e		~
	or a			;40e3	b7		.
	jr nz,l40f1h		;40e4	20 0b		  .
	bit 4,c			;40e6	cb 61		. a
	jp z,l4030h		;40e8	ca 30 40	. 0 @
	ld (hl),c		;40eb	71		q
	call sub_4107h		;40ec	cd 07 41	. . A
	ei			;40ef	fb		.
	ret			;40f0	c9		.
l40f1h:
	bit 7,c			;40f1	cb 79		. y
	jp nz,l40fch		;40f3	c2 fc 40	. . @
	bit 4,c			;40f6	cb 61		. a
	jr z,l4102h		;40f8	28 08		( .
	xor a			;40fa	af		.
	ld (hl),a		;40fb	77		w
l40fch:
	call sub_4132h		;40fc	cd 32 41	. 2 A
	jp l4030h		;40ff	c3 30 40	. 0 @
l4102h:
	call sub_411fh		;4102	cd 1f 41	. . A
	ei			;4105	fb		.
	ret			;4106	c9		.
sub_4107h:
	ld a,008h		;4107	3e 08		> .
	call RDPSG		;4109	cd 96 00	. . .
	ld (0e611h),a		;410c	32 11 e6	2 . .
	ld a,009h		;410f	3e 09		> .
	call RDPSG		;4111	cd 96 00	. . .
	ld (0e612h),a		;4114	32 12 e6	2 . .
	ld a,00ah		;4117	3e 0a		> .
	call RDPSG		;4119	cd 96 00	. . .
	ld (0e613h),a		;411c	32 13 e6	2 . .
sub_411fh:
	ld e,000h		;411f	1e 00		. .
	ld a,008h		;4121	3e 08		> .
	call WRTPSG		;4123	cd 93 00	. . .
	ld e,000h		;4126	1e 00		. .
	inc a			;4128	3c		<
	call WRTPSG		;4129	cd 93 00	. . .
	ld e,000h		;412c	1e 00		. .
	inc a			;412e	3c		<
	jp WRTPSG		;412f	c3 93 00	. . .
sub_4132h:
	ld a,(0e611h)		;4132	3a 11 e6	: . .
	ld e,a			;4135	5f		_
	ld a,008h		;4136	3e 08		> .
	call WRTPSG		;4138	cd 93 00	. . .
	ld a,(0e612h)		;413b	3a 12 e6	: . .
	ld e,a			;413e	5f		_
	ld a,009h		;413f	3e 09		> .
	call WRTPSG		;4141	cd 93 00	. . .
	ld a,(0e613h)		;4144	3a 13 e6	: . .
	ld e,a			;4147	5f		_
	ld a,00ah		;4148	3e 0a		> .
	jp WRTPSG		;414a	c3 93 00	. . .
; ===========================================================================
;  sub_414dh - MAIN TICK / top-level game state machine.  Called once per
;  frame from INT_HANDLER.  Two-level state:
;     0xC000 = primary state  (C) -> selects a handler from main_state_tbl
;     0xC001 = secondary state (B) -> sub-phase, read by the `djnz` ladders
;              inside each handler (each `djnz` skips one sub-state).
;     0xC003 = free-running frame counter (bumped every tick).
;  For the three front-end states (0..2: logo / title / attract) the shared
;  post-handler l4398h is pushed as a return address so it runs after the
;  handler and drives the "press SPACE/trigger to start" transition.
; ===========================================================================
sub_414dh:
	ld hl,0c003h		;414d	21 03 c0	; frame counter...
	inc (hl)		;4150	34		; ...++
	ld bc,(0c000h)		;4151	ed 4b 00 c0	; C=primary state, B=secondary state
	ld a,c			;4155	79		.
	cp 003h			;4156	fe 03		; front-end states 0..2?
	jr nc,l415eh		;4158	30 04		; no -> in-game, skip post-handler
	ld hl,l4398h		;415a	21 98 43	; yes -> run front-end post-handler...
	push hl			;415d	e5		; ...after the state handler returns
l415eh:
	call DISPATCH_A		;415e	cd 6b 40	; jump to main_state_tbl[primary state]

; main_state_tbl - primary game-state handlers (indexed by 0xC000).
; Roles are inferred from the boot flow / behaviour (see docs/game-notes.md);
; the front-end trio matches logo -> title -> attract.
main_state_tbl:
	defw 0417dh		;4161	7d 41	; 0  front-end: Konami logo        (*)
	defw 041a0h		;4163	a0 41	; 1  front-end: title screen       (*)
	defw 041abh		;4165	ab 41	; 2  front-end: attract / demo     (*)
	defw 041d1h		;4167	d1 41	; 3  in-game phase
	defw 0422ch		;4169	2c 42	; 4  in-game phase
	defw 04257h		;416b	57 42	; 5  in-game phase
	defw 04294h		;416d	94 42	; 6  in-game phase
	defw 042b2h		;416f	b2 42	; 7  in-game phase
	defw 04324h		;4171	24 43	; 8  in-game phase
	defw 0437eh		;4173	7e 43	; 9  in-game phase
	defw 0438eh		;4175	8e 43	; 10 in-game phase
	defw 043e1h		;4177	e1 43	; 11 in-game phase
	defw 043f7h		;4179	f7 43	; 12 in-game phase
	defw 0441bh		;417b	1b 44	; 13 in-game phase
main_state_tbl_end:
	djnz l418ah		;417d	10 0b		. .
	call 06253h		;417f	cd 53 62	. S b
	ld a,(0c422h)		;4182	3a 22 c4	: " .
	or a			;4185	b7		.
	ret z			;4186	c8		.
	xor a			;4187	af		.
	jr l41c9h		;4188	18 3f		. ?
l418ah:
	djnz l4198h		;418a	10 0c		. .
	ld hl,0c004h		;418c	21 04 c0	! . .
	dec (hl)		;418f	35		5
	ret nz			;4190	c0		.
	call sub_4d4eh		;4191	cd 4e 4d	. N M
	xor a			;4194	af		.
	jp l424bh		;4195	c3 4b 42	. K B
l4198h:
	call sub_47c0h		;4198	cd c0 47	. . G
	call 06209h		;419b	cd 09 62	. . b
	jr l41cch		;419e	18 2c		. ,
	ld hl,0c004h		;41a0	21 04 c0	! . .
	dec (hl)		;41a3	35		5
	ret nz			;41a4	c0		.
	call 07aeeh		;41a5	cd ee 7a	. . z
	jp l4249h		;41a8	c3 49 42	. I B
	djnz l41c1h		;41ab	10 14		. .
	call sub_4e27h		;41ad	cd 27 4e	. ' N
	ld a,(0c413h)		;41b0	3a 13 c4	: . .
	or a			;41b3	b7		.
	ret nz			;41b4	c0		.
l41b5h:
	xor a			;41b5	af		.
l41b6h:
	ld (0c000h),a		;41b6	32 00 c0	2 . .
	ld a,020h		;41b9	3e 20		>  
	ld (0c004h),a		;41bb	32 04 c0	2 . .
	jp l4252h		;41be	c3 52 42	. R B
l41c1h:
	call sub_47c0h		;41c1	cd c0 47	. . G
	call sub_4deeh		;41c4	cd ee 4d	. . M
	ld a,020h		;41c7	3e 20		>  
l41c9h:
	ld (0c004h),a		;41c9	32 04 c0	2 . .
l41cch:
	ld hl,0c001h		;41cc	21 01 c0	! . .
	inc (hl)		;41cf	34		4
	ret			;41d0	c9		.
	djnz l41e4h		;41d1	10 11		. .
	ld hl,0c004h		;41d3	21 04 c0	! . .
	dec (hl)		;41d6	35		5
	jr z,l41cch		;41d7	28 f3		( .
	bit 2,(hl)		;41d9	cb 56		. V
	ld hl,l4d30h		;41db	21 30 4d	! 0 M
	jp z,l4ad2h		;41de	ca d2 4a	. . J
	jp l4ad6h		;41e1	c3 d6 4a	. . J
l41e4h:
	djnz l41ech		;41e4	10 06		. .
	call sub_44cdh		;41e6	cd cd 44	. . D
	jp l41cch		;41e9	c3 cc 41	. . A
l41ech:
	djnz l41fbh		;41ec	10 0d		. .
	ld a,001h		;41ee	3e 01		> .
	ld (0c41ah),a		;41f0	32 1a c4	2 . .
	call 063dah		;41f3	cd da 63	. . c
	ld a,0a0h		;41f6	3e a0		> .
	jp l41c9h		;41f8	c3 c9 41	. . A
l41fbh:
	djnz l4222h		;41fb	10 25		. %
	call sub_4e9ah		;41fd	cd 9a 4e	. . N
	ld hl,0c004h		;4200	21 04 c0	! . .
	ld a,(0c003h)		;4203	3a 03 c0	: . .
l4206h:
	rra			;4206	1f		.
	ret c			;4207	d8		.
	dec (hl)		;4208	35		5
	ret nz			;4209	c0		.
	call sub_47f7h		;420a	cd f7 47	. . G
	xor a			;420d	af		.
	ld (0c41ah),a		;420e	32 1a c4	2 . .
	call 062d7h		;4211	cd d7 62	. . b
	ld hl,0e604h		;4214	21 04 e6	! . .
	ld a,(hl)		;4217	7e		~
	or a			;4218	b7		.
	jr z,l4220h		;4219	28 05		( .
	ld (hl),000h		;421b	36 00		6 .
	call sub_5e38h		;421d	cd 38 5e	. 8 ^
l4220h:
	jr l4249h		;4220	18 27		. '
l4222h:
	ld a,08ah		;4222	3e 8a		> .
	call sub_50a6h		;4224	cd a6 50	. . P
	ld a,050h		;4227	3e 50		> P
	jp l41c9h		;4229	c3 c9 41	. . A
	ld hl,0c410h		;422c	21 10 c4	! . .
	ld a,(hl)		;422f	7e		~
	sub 001h		;4230	d6 01		. .
	daa			;4232	27		'
	ld (hl),a		;4233	77		w
	call sub_47dbh		;4234	cd db 47	. . G
	call sub_451ah		;4237	cd 1a 45	. . E
	call 062edh		;423a	cd ed 62	. . b
	ld hl,0c413h		;423d	21 13 c4	! . .
	ld (hl),001h		;4240	36 01		6 .
	call 07956h		;4242	cd 56 79	. V y
	xor a			;4245	af		.
	ld (0c40dh),a		;4246	32 0d c4	2 . .
l4249h:
	ld a,020h		;4249	3e 20		>  
l424bh:
	ld (0c004h),a		;424b	32 04 c0	2 . .
	ld hl,0c000h		;424e	21 00 c0	! . .
	inc (hl)		;4251	34		4
l4252h:
	xor a			;4252	af		.
	ld (0c001h),a		;4253	32 01 c0	2 . .
	ret			;4256	c9		.
	call sub_5c2ch		;4257	cd 2c 5c	. , \
	ld a,(0c40ch)		;425a	3a 0c c4	: . .
	or a			;425d	b7		.
	ld a,00ch		;425e	3e 0c		> .
	jp nz,l41b6h		;4260	c2 b6 41	. . A
	ld a,(0c40ah)		;4263	3a 0a c4	: . .
	and a			;4266	a7		.
	jp nz,l428ch		;4267	c2 8c 42	. . B
	ld a,(0c41bh)		;426a	3a 1b c4	: . .
	and a			;426d	a7		.
	ld a,009h		;426e	3e 09		> .
	jp nz,l41b6h		;4270	c2 b6 41	. . A
	ld a,(0c408h)		;4273	3a 08 c4	: . .
	or a			;4276	b7		.
	ld a,00ah		;4277	3e 0a		> .
	jp nz,l41b6h		;4279	c2 b6 41	. . A
	ld a,(0c409h)		;427c	3a 09 c4	: . .
	and a			;427f	a7		.
	ld a,008h		;4280	3e 08		> .
	jp nz,l41b6h		;4282	c2 b6 41	. . A
	ld a,(0c413h)		;4285	3a 13 c4	: . .
	or a			;4288	b7		.
	ret nz			;4289	c0		.
	jr l4249h		;428a	18 bd		. .
l428ch:
	call sub_449ch		;428c	cd 9c 44	. . D
	ld a,00bh		;428f	3e 0b		> .
	jp l41b6h		;4291	c3 b6 41	. . A
	ld hl,0c410h		;4294	21 10 c4	! . .
	ld a,(hl)		;4297	7e		~
	or a			;4298	b7		.
	jr z,l42abh		;4299	28 10		( .
l429bh:
	call 062d7h		;429b	cd d7 62	. . b
	xor a			;429e	af		.
	ld (0c420h),a		;429f	32 20 c4	2   .
	inc a			;42a2	3c		<
	ld (0c40dh),a		;42a3	32 0d c4	2 . .
	ld a,004h		;42a6	3e 04		> .
	jp l41b6h		;42a8	c3 b6 41	. . A
l42abh:
	ld a,08bh		;42ab	3e 8b		> .
	call sub_50a6h		;42ad	cd a6 50	. . P
	jr l4249h		;42b0	18 97		. .
	djnz l42e3h		;42b2	10 2f		. /
	ld a,(0e600h)		;42b4	3a 00 e6	: . .
	or a			;42b7	b7		.
	jr z,l42bfh		;42b8	28 05		( .
	call sub_4314h		;42ba	cd 14 43	. . C
	jr nz,l42d3h		;42bd	20 14		  .
l42bfh:
	ld a,(0c0a7h)		;42bf	3a a7 c0	: . .
	and a			;42c2	a7		.
	ret nz			;42c3	c0		.
	ld hl,0c004h		;42c4	21 04 c0	! . .
	dec (hl)		;42c7	35		5
	ret nz			;42c8	c0		.
	ld hl,0c002h		;42c9	21 02 c0	! . .
	ld a,(hl)		;42cc	7e		~
	and 0bfh		;42cd	e6 bf		. .
	ld (hl),a		;42cf	77		w
	jp l41b5h		;42d0	c3 b5 41	. . A
l42d3h:
	ld a,003h		;42d3	3e 03		> .
	ld (0c410h),a		;42d5	32 10 c4	2 . .
	xor a			;42d8	af		.
	ld h,a			;42d9	67		g
	ld l,a			;42da	6f		o
	ld (0c405h),hl		;42db	22 05 c4	" . .
	ld (0c407h),a		;42de	32 07 c4	2 . .
	jr l429bh		;42e1	18 b8		. .
l42e3h:
	call sub_47c0h		;42e3	cd c0 47	. . G
	ld hl,l4d41h		;42e6	21 41 4d	! A M
	call l4ad2h		;42e9	cd d2 4a	. . J
	ld a,(0e600h)		;42ec	3a 00 e6	: . .
	or a			;42ef	b7		.
	jr z,l42f8h		;42f0	28 06		( .
	ld hl,l4300h		;42f2	21 00 43	! . C
	call l4ad2h		;42f5	cd d2 4a	. . J
l42f8h:
	call sub_451ah		;42f8	cd 1a 45	. . E
	ld a,078h		;42fb	3e 78		> x
	jp l41c9h		;42fd	c3 c9 41	. . A
l4300h:
	ld d,b			;4300	50		P
	ld l,b			;4301	68		h
	ld (hl),025h		;4302	36 25		6 %
	cp 064h			;4304	fe 64		. d
	ld l,b			;4306	68		h
	ld c,a			;4307	4f		O
	cp 070h			;4308	fe 70		. p
	ld l,b			;430a	68		h
	inc sp			;430b	33		3
	ccf			;430c	3f		?
	ld a,044h		;430d	3e 44		> D
	add hl,sp		;430f	39		9
	ld a,045h		;4310	3e 45		> E
	dec (hl)		;4312	35		5
	rst 38h			;4313	ff		.
sub_4314h:
	ld a,007h		;4314	3e 07		> .
	call SNSMAT		;4316	cd 41 01	. A .
	cpl			;4319	2f		/
	and 002h		;431a	e6 02		. .
	ld hl,0e614h		;431c	21 14 e6	! . .
	ld c,(hl)		;431f	4e		N
	ld (hl),a		;4320	77		w
	xor c			;4321	a9		.
	and (hl)		;4322	a6		.
	ret			;4323	c9		.
	djnz l4377h		;4324	10 51		. Q
	ld hl,0d002h		;4326	21 02 d0	! . .
	inc (hl)		;4329	34		4
	ld a,006h		;432a	3e 06		> .
	sub (hl)		;432c	96		.
	jr nz,l434bh		;432d	20 1c		  .
	ld (hl),a		;432f	77		w
	ld a,0ffh		;4330	3e ff		> .
	ld (0d000h),a		;4332	32 00 d0	2 . .
	ld a,020h		;4335	3e 20		>  
	ld (0c415h),a		;4337	32 15 c4	2 . .
	ld hl,0cf34h		;433a	21 34 cf	! 4 .
	inc (hl)		;433d	34		4
	ld a,(hl)		;433e	7e		~
	cp 002h			;433f	fe 02		. .
	jr nz,l434bh		;4341	20 08		  .
	ld hl,0c002h		;4343	21 02 c0	! . .
	res 6,(hl)		;4346	cb b6		. .
	jp l41b5h		;4348	c3 b5 41	. . A
l434bh:
	call 062dch		;434b	cd dc 62	. . b
l434eh:
	ld hl,0c410h		;434e	21 10 c4	! . .
	ld a,(hl)		;4351	7e		~
	add a,001h		;4352	c6 01		. .
	daa			;4354	27		'
	ld (hl),a		;4355	77		w
	ld hl,0c411h		;4356	21 11 c4	! . .
	ld a,(hl)		;4359	7e		~
	add a,001h		;435a	c6 01		. .
	daa			;435c	27		'
	ld (hl),a		;435d	77		w
	ld hl,0d000h		;435e	21 00 d0	! . .
	inc (hl)		;4361	34		4
	inc hl			;4362	23		#
	xor a			;4363	af		.
	ld (hl),a		;4364	77		w
	ld (0c409h),a		;4365	32 09 c4	2 . .
	ld (0c408h),a		;4368	32 08 c4	2 . .
	ld a,004h		;436b	3e 04		> .
	jp l41b6h		;436d	c3 b6 41	. . A
	ld hl,CHKRAM		;4370	21 00 00	! . .
	ld (0c000h),hl		;4373	22 00 c0	" . .
	ret			;4376	c9		.
l4377h:
	call sub_47c0h		;4377	cd c0 47	. . G
	xor a			;437a	af		.
	jp l41c9h		;437b	c3 c9 41	. . A
	call sub_5a35h		;437e	cd 35 5a	. 5 Z
	ld a,006h		;4381	3e 06		> .
	jp nc,l41b6h		;4383	d2 b6 41	. . A
	call 062fch		;4386	cd fc 62	. . b
	ld a,005h		;4389	3e 05		> .
	jp l41b6h		;438b	c3 b6 41	. . A
	ld hl,0c701h		;438e	21 01 c7	! . .
	ld a,(hl)		;4391	7e		~
	and 0feh		;4392	e6 fe		. .
	ld (hl),a		;4394	77		w
	jp l434eh		;4395	c3 4e 43	. N C
; ===========================================================================
;  l4398h - front-end post-handler (runs after the logo/title/attract handler,
;  states 0..2).  Reads the start input; on press it moves logo/attract back to
;  the title, or (from the title) begins the game.
; ===========================================================================
l4398h:
	call sub_4bc2h		;4398	cd c2 4b	; front-end per-frame update (anim/timer)
	ld hl,0c401h		;439b	21 01 c4	; 0xC401 = start/trigger input state
	call sub_4bbbh		;439e	cd bb 4b	; A = newly-pressed buttons this frame
	or a			;43a1	b7		.
	ret z			;43a2	c8		; nothing pressed -> stay in this state
	ld hl,0c004h		;43a3	21 04 c0	; reset the sub-state timer...
	ld (hl),000h		;43a6	36 00		; ...(0xC004 = 0)
	ld hl,0c000h		;43a8	21 00 c0	; HL -> primary state (0xC000)
	ld b,(hl)		;43ab	46		; B = current state
	djnz l43c1h		;43ac	10 13		; state != 1 (logo/attract) -> back to title
	and 030h		;43ae	e6 30		; title: was it SPACE/trigger (bits 4,5)?
	ret z			;43b0	c8		; other key -> ignore
	ld a,040h		;43b1	3e 40		.
	ld (0c002h),a		;43b3	32 02 c0	; flag "start pressed"
	ld a,(0e600h)		;43b6	3a 00 e6	; in a tick already? (demo/attract guard)
	or a			;43b9	b7		.
	jr nz,l43cbh		;43ba	20 0f		; yes -> full game-start setup
	ld (hl),003h		;43bc	36 03		; else advance to state 3 (in-game)...
	inc hl			;43be	23		.
	ld (hl),b		;43bf	70		; ...0xC001 = old state as sub-state
	ret			;43c0	c9		.
; state 0 (logo) or 2 (attract) + any press -> return to the title screen.
l43c1h:
	ld (hl),001h		;43c1	36 01		; primary state = 1 (title)
	ld a,000h		;43c3	3e 00		.
	call sub_50a6h		;43c5	cd a6 50	; request sound/music change
	jp sub_4d4eh		;43c8	c3 4e 4d	; (re)build the title screen
; l43cbh - full game start: seed the run state then enter gameplay.
l43cbh:
	xor a			;43cb	af		.
	ld (0e604h),a		;43cc	32 04 e6	; clear a run flag
	ld a,001h		;43cf	3e 01		.
	ld (0e605h),a		;43d1	32 05 e6	; initial lives / level counters...
	ld (0e606h),a		;43d4	32 06 e6	.
	ld a,003h		;43d7	3e 03		.
	ld (0e607h),a		;43d9	32 07 e6	.
	ld a,00dh		;43dc	3e 0d		; A = 0x0D -> next-state selector
	jp l41b6h		;43de	c3 b6 41	; enter gameplay via the state setter
	ld a,(0c00bh)		;43e1	3a 0b c0	: . .
	rra			;43e4	1f		.
	ret nc			;43e5	d0		.
	xor a			;43e6	af		.
	ld (0c40ah),a		;43e7	32 0a c4	2 . .
	call sub_44bfh		;43ea	cd bf 44	. . D
	ld a,0feh		;43ed	3e fe		> .
	call sub_50a6h		;43ef	cd a6 50	. . P
	ld a,005h		;43f2	3e 05		> .
	jp l41b6h		;43f4	c3 b6 41	. . A
	djnz l4402h		;43f7	10 09		. .
	call 094c1h		;43f9	cd c1 94	. . .
	ret nz			;43fc	c0		.
	ld a,00fh		;43fd	3e 0f		> .
	jp l41c9h		;43ff	c3 c9 41	. . A
l4402h:
	djnz l4411h		;4402	10 0d		. .
	ld hl,0c004h		;4404	21 04 c0	! . .
	dec (hl)		;4407	35		5
	ret nz			;4408	c0		.
	call 0950eh		;4409	cd 0e 95	. . .
	ld a,005h		;440c	3e 05		> .
	jp l41b6h		;440e	c3 b6 41	. . A
l4411h:
	xor a			;4411	af		.
	ld (0c40ch),a		;4412	32 0c c4	2 . .
	call 0938eh		;4415	cd 8e 93	. . .
	jp l41cch		;4418	c3 cc 41	. . A
	djnz l4453h		;441b	10 36		. 6
	ld a,(0c006h)		;441d	3a 06 c0	: . .
	and 033h		;4420	e6 33		. 3
	ret z			;4422	c8		.
	and 003h		;4423	e6 03		. .
	jp nz,l5e84h		;4425	c2 84 5e	. . ^
	ld a,(0e60bh)		;4428	3a 0b e6	: . .
	or a			;442b	b7		.
	jp nz,l4439h		;442c	c2 39 44	. 9 D
	call sub_5d04h		;442f	cd 04 5d	. . ]
	ld hl,00003h		;4432	21 03 00	! . .
	ld (0c000h),hl		;4435	22 00 c0	" . .
	ret			;4438	c9		.
l4439h:
	dec a			;4439	3d		=
	jr z,l4447h		;443a	28 0b		( .
	ld hl,0b8b8h		;443c	21 b8 b8	! . .
	ld (0e602h),hl		;443f	22 02 e6	" . .
l4442h:
	call sub_5d89h		;4442	cd 89 5d	. . ]
	jr l4450h		;4445	18 09		. .
l4447h:
	ld hl,0b0b8h		;4447	21 b8 b0	! . .
	ld (0e602h),hl		;444a	22 02 e6	" . .
	call sub_5d68h		;444d	cd 68 5d	. h ]
l4450h:
	jp l41cch		;4450	c3 cc 41	. . A
l4453h:
	djnz l4488h		;4453	10 33		. 3
	call sub_5e28h		;4455	cd 28 5e	. ( ^
	jr nz,l445dh		;4458	20 03		  .
	jp l5db9h		;445a	c3 b9 5d	. . ]
l445dh:
	ld a,(0e60bh)		;445d	3a 0b e6	: . .
	ld b,a			;4460	47		G
	ld hl,0e604h		;4461	21 04 e6	! . .
	or (hl)			;4464	b6		.
	ld (hl),a		;4465	77		w
	ld a,(0e615h)		;4466	3a 15 e6	: . .
	or a			;4469	b7		.
	jr z,l447eh		;446a	28 12		( .
	ld a,(0e60eh)		;446c	3a 0e e6	: . .
	ld d,a			;446f	57		W
	ld a,(0e60fh)		;4470	3a 0f e6	: . .
	bit 0,b			;4473	cb 40		. @
	jr z,l4483h		;4475	28 0c		( .
	ld (0e605h),a		;4477	32 05 e6	2 . .
	ld a,d			;447a	7a		z
	ld (0e606h),a		;447b	32 06 e6	2 . .
l447eh:
	xor a			;447e	af		.
	ld (0c001h),a		;447f	32 01 c0	2 . .
	ret			;4482	c9		.
l4483h:
	ld (0e607h),a		;4483	32 07 e6	2 . .
	jr l447eh		;4486	18 f6		. .
l4488h:
	call sub_5cf6h		;4488	cd f6 5c	. . \
	xor a			;448b	af		.
	ld hl,0e608h		;448c	21 08 e6	! . .
	ld de,0e609h		;448f	11 09 e6	. . .
	ld bc,0000eh		;4492	01 0e 00	. . .
	ld (hl),000h		;4495	36 00		6 .
	ldir			;4497	ed b0		. .
	jp l41cch		;4499	c3 cc 41	. . A
sub_449ch:
	ld hl,06854h		;449c	21 54 68	! T h
	ld bc,03010h		;449f	01 10 30	. . 0
	ld de,0d070h		;44a2	11 70 d0	. p .
	ld a,004h		;44a5	3e 04		> .
	push hl			;44a7	e5		.
	push bc			;44a8	c5		.
	call sub_494dh		;44a9	cd 4d 49	. M I
	pop bc			;44ac	c1		.
	pop hl			;44ad	e1		.
	call sub_5d15h		;44ae	cd 15 5d	. . ]
	ld hl,l44b7h		;44b1	21 b7 44	! . D
	jp l4ad2h		;44b4	c3 d2 4a	. . J
l44b7h:
	ld l,h			;44b7	6c		l
	ld e,b			;44b8	58		X
	ld b,b			;44b9	40		@
	ld sp,04345h		;44ba	31 45 43	1 E C
	dec (hl)		;44bd	35		5
	rst 38h			;44be	ff		.
sub_44bfh:
	ld de,06854h		;44bf	11 54 68	. T h
	ld bc,03010h		;44c2	01 10 30	. . 0
	ld hl,0d070h		;44c5	21 70 d0	! p .
	ld a,001h		;44c8	3e 01		> .
	jp sub_494dh		;44ca	c3 4d 49	. M I
sub_44cdh:
	ld hl,0c405h		;44cd	21 05 c4	! . .
	ld bc,01bfbh		;44d0	01 fb 1b	. . .
	ld d,h			;44d3	54		T
	ld e,l			;44d4	5d		]
	inc e			;44d5	1c		.
	ld (hl),000h		;44d6	36 00		6 .
	ldir			;44d8	ed b0		. .
	ld hl,l44f0h		;44da	21 f0 44	! . D
	ld de,0c410h		;44dd	11 10 c4	. . .
	ld bc,00003h		;44e0	01 03 00	. . .
	ldir			;44e3	ed b0		. .
	ld a,020h		;44e5	3e 20		>  
	ld (0c415h),a		;44e7	32 15 c4	2 . .
	ld a,080h		;44ea	3e 80		> .
	ld (0c418h),a		;44ec	32 18 c4	2 . .
	ret			;44ef	c9		.
l44f0h:
	inc bc			;44f0	03		.
	nop			;44f1	00		.
	ld bc,0000eh		;44f2	01 0e 00	. . .
	ld a,(0c002h)		;44f5	3a 02 c0	: . .
	add a,a			;44f8	87		.
	ret p			;44f9	f0		.
	ld hl,0c405h		;44fa	21 05 c4	! . .
	ld a,(hl)		;44fd	7e		~
	add a,e			;44fe	83		.
	daa			;44ff	27		'
	ld (hl),a		;4500	77		w
	inc l			;4501	2c		,
	ld a,(hl)		;4502	7e		~
	adc a,d			;4503	8a		.
	daa			;4504	27		'
	ld (hl),a		;4505	77		w
	inc hl			;4506	23		#
	ld a,(hl)		;4507	7e		~
	adc a,c			;4508	89		.
	daa			;4509	27		'
	ld (hl),a		;450a	77		w
	jr nc,l4538h		;450b	30 2b		0 +
	ld bc,09999h		;450d	01 99 99	. . .
	ld (0c402h),bc		;4510	ed 43 02 c4	. C . .
	ld (0c403h),bc		;4514	ed 43 03 c4	. C . .
	jr l4538h		;4518	18 1e		. .
sub_451ah:
	ld hl,l4c07h		;451a	21 07 4c	! . L
	call l4ad2h		;451d	cd d2 4a	. . J
	call sub_4542h		;4520	cd 42 45	. B E
	call sub_456dh		;4523	cd 6d 45	. m E
	call sub_4575h		;4526	cd 75 45	. u E
	call sub_45b7h		;4529	cd b7 45	. . E
	call sub_454ch		;452c	cd 4c 45	. L E
	call 08ea1h		;452f	cd a1 8e	. . .
	call 08ebbh		;4532	cd bb 8e	. . .
	call 08eedh		;4535	cd ed 8e	. . .
l4538h:
	ld hl,0c407h		;4538	21 07 c4	! . .
	ld de,03800h		;453b	11 00 38	. . 8
	ld b,003h		;453e	06 03		. .
	jr l457fh		;4540	18 3d		. =
sub_4542h:
	ld de,09c00h		;4542	11 00 9c	. . .
	ld hl,0c411h		;4545	21 11 c4	! . .
	ld b,001h		;4548	06 01		. .
	jr l457fh		;454a	18 33		. 3
sub_454ch:
	ld hl,07f0bh		;454c	21 0b 7f	! . .
	ld de,01212h		;454f	11 12 12	. . .
	ld c,008h		;4552	0e 08		. .
	call sub_48e3h		;4554	cd e3 48	. . H
	ld hl,0930bh		;4557	21 0b 93	! . .
	ld de,02212h		;455a	11 12 22	. . "
	ld c,00eh		;455d	0e 0e		. .
	call sub_48e3h		;455f	cd e3 48	. . H
	ld hl,0b70bh		;4562	21 0b b7	! . .
	ld de,04212h		;4565	11 12 42	. . B
	ld c,00eh		;4568	0e 0e		. .
	jp sub_48e3h		;456a	c3 e3 48	. . H
sub_456dh:
	ld hl,0c417h		;456d	21 17 c4	! . .
	ld de,0c000h		;4570	11 00 c0	. . .
	jr l457bh		;4573	18 06		. .
sub_4575h:
	ld hl,0c410h		;4575	21 10 c4	! . .
	ld de,0e400h		;4578	11 00 e4	. . .
l457bh:
	ld b,001h		;457b	06 01		. .
	jr l457fh		;457d	18 00		. .
l457fh:
	ld a,(hl)		;457f	7e		~
	rra			;4580	1f		.
	rra			;4581	1f		.
	rra			;4582	1f		.
	rra			;4583	1f		.
	call sub_458fh		;4584	cd 8f 45	. . E
	ld a,(hl)		;4587	7e		~
	call sub_458fh		;4588	cd 8f 45	. . E
	dec hl			;458b	2b		+
	djnz l457fh		;458c	10 f1		. .
	ret			;458e	c9		.
sub_458fh:
	and 00fh		;458f	e6 0f		. .
	add a,020h		;4591	c6 20		.  
	call sub_4aeeh		;4593	cd ee 4a	. . J
	ld a,d			;4596	7a		z
	add a,008h		;4597	c6 08		. .
	ld d,a			;4599	57		W
	ret			;459a	c9		.
	ld hl,0c417h		;459b	21 17 c4	! . .
	ld a,(hl)		;459e	7e		~
	add a,b			;459f	80		.
	daa			;45a0	27		'
	jr nc,l45a5h		;45a1	30 02		0 .
	ld a,099h		;45a3	3e 99		> .
l45a5h:
	jr l45b0h		;45a5	18 09		. .
	ld hl,0c417h		;45a7	21 17 c4	! . .
	ld a,(hl)		;45aa	7e		~
	cp b			;45ab	b8		.
	jr c,l45b4h		;45ac	38 06		8 .
	sub b			;45ae	90		.
	daa			;45af	27		'
l45b0h:
	ld (hl),a		;45b0	77		w
	jp sub_456dh		;45b1	c3 6d 45	. m E
l45b4h:
	xor a			;45b4	af		.
	jr l45b0h		;45b5	18 f9		. .
sub_45b7h:
	call sub_45c0h		;45b7	cd c0 45	. . E
l45bah:
	call sub_45c6h		;45ba	cd c6 45	. . E
	jp l45ech		;45bd	c3 ec 45	. . E
sub_45c0h:
	call sub_45cfh		;45c0	cd cf 45	. . E
	jp l45d8h		;45c3	c3 d8 45	. . E
sub_45c6h:
	ld hl,03b16h		;45c6	21 16 3b	! . ;
	ld bc,l4206h		;45c9	01 06 42	. . B
l45cch:
	jp sub_5d15h		;45cc	c3 15 5d	. . ]
sub_45cfh:
	ld hl,03b0dh		;45cf	21 0d 3b	! . ;
	ld bc,l4206h		;45d2	01 06 42	. . B
	jp l45cch		;45d5	c3 cc 45	. . E
l45d8h:
	ld hl,0c415h		;45d8	21 15 c4	! . .
	ld a,(hl)		;45db	7e		~
	ld hl,03c0eh		;45dc	21 0e 3c	! . <
	add a,a			;45df	87		.
	or a			;45e0	b7		.
	ret z			;45e1	c8		.
	ld b,a			;45e2	47		G
	ld c,004h		;45e3	0e 04		. .
	ld d,000h		;45e5	16 00		. .
	ld a,011h		;45e7	3e 11		> .
	jp l4911h		;45e9	c3 11 49	. . I
l45ech:
	ld hl,0c418h		;45ec	21 18 c4	! . .
	ld a,(hl)		;45ef	7e		~
	ld hl,03c17h		;45f0	21 17 3c	! . <
	ld b,a			;45f3	47		G
	and 003h		;45f4	e6 03		. .
	ld c,a			;45f6	4f		O
	ld a,b			;45f7	78		x
	and 0fch		;45f8	e6 fc		. .
	rrca			;45fa	0f		.
	or a			;45fb	b7		.
	jr nz,l4602h		;45fc	20 04		  .
	or c			;45fe	b1		.
	ret z			;45ff	c8		.
	ld a,002h		;4600	3e 02		> .
l4602h:
	ld b,a			;4602	47		G
	ld c,004h		;4603	0e 04		. .
	ld d,000h		;4605	16 00		. .
	ld a,088h		;4607	3e 88		> .
	jp l4911h		;4609	c3 11 49	. . I
l460ch:
	ld hl,0c415h		;460c	21 15 c4	! . .
	ld a,(hl)		;460f	7e		~
	add a,b			;4610	80		.
	cp 021h			;4611	fe 21		. !
	jr c,l461bh		;4613	38 06		8 .
	ld a,020h		;4615	3e 20		>  
	sub (hl)		;4617	96		.
	ld b,a			;4618	47		G
	ld a,020h		;4619	3e 20		>  
l461bh:
	ld (hl),a		;461b	77		w
	jp sub_45c0h		;461c	c3 c0 45	. . E
	ld hl,0c418h		;461f	21 18 c4	! . .
	ld a,(hl)		;4622	7e		~
	add a,b			;4623	80		.
	cp 081h			;4624	fe 81		. .
	jr c,l462eh		;4626	38 06		8 .
	ld a,080h		;4628	3e 80		> .
	sub (hl)		;462a	96		.
	ld b,a			;462b	47		G
	ld a,080h		;462c	3e 80		> .
l462eh:
	ld (hl),a		;462e	77		w
	jp l45bah		;462f	c3 ba 45	. . E
l4632h:
	ld hl,0c415h		;4632	21 15 c4	! . .
	ld a,(hl)		;4635	7e		~
	cp b			;4636	b8		.
	jr nc,l463ah		;4637	30 01		0 .
	ld b,a			;4639	47		G
l463ah:
	ld a,b			;463a	78		x
	or a			;463b	b7		.
	ret z			;463c	c8		.
	ld a,(hl)		;463d	7e		~
	sub b			;463e	90		.
	ld (hl),a		;463f	77		w
	jp sub_45c0h		;4640	c3 c0 45	. . E
l4643h:
	ld hl,0c418h		;4643	21 18 c4	! . .
	ld a,(hl)		;4646	7e		~
	cp b			;4647	b8		.
	jr nc,l464bh		;4648	30 01		0 .
	ld b,a			;464a	47		G
l464bh:
	ld a,b			;464b	78		x
	or a			;464c	b7		.
	ret z			;464d	c8		.
	ld a,(hl)		;464e	7e		~
	sub b			;464f	90		.
	ld (hl),a		;4650	77		w
	jp l45bah		;4651	c3 ba 45	. . E
	ld b,001h		;4654	06 01		. .
	jr l4632h		;4656	18 da		. .
	ld b,001h		;4658	06 01		. .
	jp l460ch		;465a	c3 0c 46	. . F
	ld b,001h		;465d	06 01		. .
	jr l4643h		;465f	18 e2		. .
sub_4661h:
	call sub_46d5h		;4661	cd d5 46	. . F
	call sub_4674h		;4664	cd 74 46	. t F
	ex af,af'		;4667	08		.
	ld a,(00006h)		;4668	3a 06 00	: . .
	ld c,a			;466b	4f		O
	ex af,af'		;466c	08		.
l466dh:
	inir			;466d	ed b2		. .
	dec a			;466f	3d		=
	jr nz,l466dh		;4670	20 fb		  .
	ex de,hl		;4672	eb		.
	ret			;4673	c9		.
sub_4674h:
	ex de,hl		;4674	eb		.
	ld a,c			;4675	79		y
	or a			;4676	b7		.
	ld a,b			;4677	78		x
	ld b,c			;4678	41		A
	ret z			;4679	c8		.
	inc a			;467a	3c		<
	ret			;467b	c9		.
sub_467ch:
	ex de,hl		;467c	eb		.
	call sub_46b6h		;467d	cd b6 46	. . F
	call sub_4674h		;4680	cd 74 46	. t F
	ex af,af'		;4683	08		.
	ld a,(00007h)		;4684	3a 07 00	: . .
	ld c,a			;4687	4f		O
	ex af,af'		;4688	08		.
l4689h:
	otir			;4689	ed b3		. .
	dec a			;468b	3d		=
	jr nz,l4689h		;468c	20 fb		  .
	ret			;468e	c9		.
sub_468fh:
	push de			;468f	d5		.
	push af			;4690	f5		.
	call sub_46b6h		;4691	cd b6 46	. . F
	ld d,c			;4694	51		Q
	ld a,c			;4695	79		y
	or a			;4696	b7		.
	jr z,l469ah		;4697	28 01		( .
	inc b			;4699	04		.
l469ah:
	ld a,(00007h)		;469a	3a 07 00	: . .
	ld c,a			;469d	4f		O
	pop af			;469e	f1		.
l469fh:
	out (c),a		;469f	ed 79		. y
	dec d			;46a1	15		.
	jr nz,l469fh		;46a2	20 fb		  .
	djnz l469fh		;46a4	10 f9		. .
	pop de			;46a6	d1		.
	ret			;46a7	c9		.
	push bc			;46a8	c5		.
	push af			;46a9	f5		.
	call sub_46b6h		;46aa	cd b6 46	. . F
	ld a,(00007h)		;46ad	3a 07 00	: . .
	ld c,a			;46b0	4f		O
	pop af			;46b1	f1		.
	out (c),a		;46b2	ed 79		. y
	pop bc			;46b4	c1		.
	ret			;46b5	c9		.
sub_46b6h:
	push bc			;46b6	c5		.
	ld a,(00007h)		;46b7	3a 07 00	: . .
	inc a			;46ba	3c		<
	ld c,a			;46bb	4f		O
	ld a,h			;46bc	7c		|
	rlca			;46bd	07		.
	rlca			;46be	07		.
	and 003h		;46bf	e6 03		. .
	di			;46c1	f3		.
	out (c),a		;46c2	ed 79		. y
	ld a,08eh		;46c4	3e 8e		> .
	out (c),a		;46c6	ed 79		. y
	ld a,l			;46c8	7d		}
	out (c),a		;46c9	ed 79		. y
	ld a,h			;46cb	7c		|
	and 03fh		;46cc	e6 3f		. ?
	or 040h			;46ce	f6 40		. @
	out (c),a		;46d0	ed 79		. y
	pop bc			;46d2	c1		.
	ei			;46d3	fb		.
	ret			;46d4	c9		.
sub_46d5h:
	push bc			;46d5	c5		.
	ld a,(00007h)		;46d6	3a 07 00	: . .
	inc a			;46d9	3c		<
	ld c,a			;46da	4f		O
	ld a,h			;46db	7c		|
	rlca			;46dc	07		.
	rlca			;46dd	07		.
	and 003h		;46de	e6 03		. .
	di			;46e0	f3		.
	out (c),a		;46e1	ed 79		. y
	ld a,08eh		;46e3	3e 8e		> .
	out (c),a		;46e5	ed 79		. y
	ld a,l			;46e7	7d		}
	out (c),a		;46e8	ed 79		. y
	ld a,h			;46ea	7c		|
	and 03fh		;46eb	e6 3f		. ?
	out (c),a		;46ed	ed 79		. y
	pop bc			;46ef	c1		.
	ei			;46f0	fb		.
	ret			;46f1	c9		.
l46f2h:
	ex de,hl		;46f2	eb		.
	ld e,(hl)		;46f3	5e		^
	inc hl			;46f4	23		#
	ld d,(hl)		;46f5	56		V
	inc hl			;46f6	23		#
	ex de,hl		;46f7	eb		.
sub_46f8h:
	call sub_46b6h		;46f8	cd b6 46	. . F
	ld a,(00007h)		;46fb	3a 07 00	: . .
	ld c,a			;46fe	4f		O
l46ffh:
	ld a,(de)		;46ff	1a		.
	and a			;4700	a7		.
	ret z			;4701	c8		.
	inc de			;4702	13		.
	ld b,a			;4703	47		G
	and 07fh		;4704	e6 7f		. .
	cp b			;4706	b8		.
	jr z,l4713h		;4707	28 0a		( .
	and a			;4709	a7		.
	jr z,l46f2h		;470a	28 e6		( .
	ex de,hl		;470c	eb		.
	ld b,a			;470d	47		G
	otir			;470e	ed b3		. .
	ex de,hl		;4710	eb		.
	jr l46ffh		;4711	18 ec		. .
l4713h:
	ld a,(de)		;4713	1a		.
	inc de			;4714	13		.
l4715h:
	out (c),a		;4715	ed 79		. y
	djnz l4715h		;4717	10 fc		. .
	jr l46ffh		;4719	18 e4		. .
l471bh:
	ld a,(hl)		;471b	7e		~
	inc hl			;471c	23		#
	inc a			;471d	3c		<
	ret z			;471e	c8		.
	dec a			;471f	3d		=
	or a			;4720	b7		.
	jr z,l472bh		;4721	28 08		( .
	dec a			;4723	3d		=
	jr z,l4730h		;4724	28 0a		( .
	call sub_4772h		;4726	cd 72 47	. r G
	jr l471bh		;4729	18 f0		. .
l472bh:
	call sub_4735h		;472b	cd 35 47	. 5 G
	jr l471bh		;472e	18 eb		. .
l4730h:
	call sub_4745h		;4730	cd 45 47	. E G
	jr l471bh		;4733	18 e6		. .
sub_4735h:
	ld e,(hl)		;4735	5e		^
	inc hl			;4736	23		#
	ld d,(hl)		;4737	56		V
	inc hl			;4738	23		#
	ld a,(hl)		;4739	7e		~
	inc hl			;473a	23		#
	ld b,(hl)		;473b	46		F
	inc hl			;473c	23		#
	push hl			;473d	e5		.
	ld l,a			;473e	6f		o
	ld h,b			;473f	60		`
	call sub_46f8h		;4740	cd f8 46	. . F
	pop hl			;4743	e1		.
	ret			;4744	c9		.
sub_4745h:
	ld e,(hl)		;4745	5e		^
	inc hl			;4746	23		#
	ld d,(hl)		;4747	56		V
	inc hl			;4748	23		#
	ld a,(hl)		;4749	7e		~
	inc hl			;474a	23		#
	push hl			;474b	e5		.
	ld l,a			;474c	6f		o
	ld h,000h		;474d	26 00		& .
	add hl,hl		;474f	29		)
	add hl,hl		;4750	29		)
	add hl,hl		;4751	29		)
	add hl,hl		;4752	29		)
	add hl,hl		;4753	29		)
	ld c,l			;4754	4d		M
	ld b,h			;4755	44		D
	ex de,hl		;4756	eb		.
	push bc			;4757	c5		.
	push af			;4758	f5		.
	ld de,0e800h		;4759	11 00 e8	. . .
	call sub_4661h		;475c	cd 61 46	. a F
	pop af			;475f	f1		.
	call sub_4786h		;4760	cd 86 47	. . G
	pop bc			;4763	c1		.
	pop hl			;4764	e1		.
	ld e,(hl)		;4765	5e		^
	inc hl			;4766	23		#
	ld d,(hl)		;4767	56		V
	inc hl			;4768	23		#
	push hl			;4769	e5		.
	ld hl,0ec00h		;476a	21 00 ec	! . .
	call sub_467ch		;476d	cd 7c 46	. | F
	pop hl			;4770	e1		.
	ret			;4771	c9		.
sub_4772h:
	ld e,(hl)		;4772	5e		^
	inc hl			;4773	23		#
	ld d,(hl)		;4774	56		V
	inc hl			;4775	23		#
	ld c,(hl)		;4776	4e		N
	inc hl			;4777	23		#
	ld b,(hl)		;4778	46		F
	inc hl			;4779	23		#
	ld a,(hl)		;477a	7e		~
	inc hl			;477b	23		#
	push hl			;477c	e5		.
	ld h,(hl)		;477d	66		f
	ld l,a			;477e	6f		o
	ex de,hl		;477f	eb		.
	call sub_467ch		;4780	cd 7c 46	. | F
	pop hl			;4783	e1		.
	inc hl			;4784	23		#
	ret			;4785	c9		.
sub_4786h:
	ld hl,0e800h		;4786	21 00 e8	! . .
	ld de,0ec10h		;4789	11 10 ec	. . .
	ld c,a			;478c	4f		O
l478dh:
	call sub_47a4h		;478d	cd a4 47	. . G
	ld a,0e0h		;4790	3e e0		> .
	add a,e			;4792	83		.
	ld e,a			;4793	5f		_
	jr c,l4797h		;4794	38 01		8 .
	dec d			;4796	15		.
l4797h:
	call sub_47a4h		;4797	cd a4 47	. . G
	ld a,020h		;479a	3e 20		>  
	call ADD_DE_A		;479c	cd 66 40	. f @
	dec c			;479f	0d		.
	jp nz,l478dh		;47a0	c2 8d 47	. . G
	ret			;47a3	c9		.
sub_47a4h:
	ld b,010h		;47a4	06 10		. .
l47a6h:
	ld a,(hl)		;47a6	7e		~
	inc hl			;47a7	23		#
	exx			;47a8	d9		.
	ld c,a			;47a9	4f		O
	ld a,001h		;47aa	3e 01		> .
l47ach:
	rr c			;47ac	cb 19		. .
	rla			;47ae	17		.
	jp nc,l47ach		;47af	d2 ac 47	. . G
	exx			;47b2	d9		.
	ld (de),a		;47b3	12		.
	inc de			;47b4	13		.
	djnz l47a6h		;47b5	10 ef		. .
	ret			;47b7	c9		.
	call sub_47f7h		;47b8	cd f7 47	. . G
	ld bc,CHKRAM		;47bb	01 00 00	. . .
	jr l47c6h		;47be	18 06		. .
sub_47c0h:
	call sub_47f7h		;47c0	cd f7 47	. . G
	ld bc,000d4h		;47c3	01 d4 00	. . .
l47c6h:
	push bc			;47c6	c5		.
	call sub_47dbh		;47c7	cd db 47	. . G
	pop bc			;47ca	c1		.
	call sub_47e8h		;47cb	cd e8 47	. . G
l47ceh:
	ld a,(0f3e0h)		;47ce	3a e0 f3	: . .
	or 040h			;47d1	f6 40		. @
	ld b,a			;47d3	47		G
	ld c,001h		;47d4	0e 01		. .
	call WRTVDP		;47d6	cd 47 00	. G .
	jr l4810h		;47d9	18 35		. 5
sub_47dbh:
	ld a,(0f3e0h)		;47db	3a e0 f3	: . .
	and 0bfh		;47de	e6 bf		. .
	ld b,a			;47e0	47		G
	ld c,001h		;47e1	0e 01		. .
	call WRTVDP		;47e3	cd 47 00	. G .
	jr l4805h		;47e6	18 1d		. .
sub_47e8h:
	ld hl,CHKRAM		;47e8	21 00 00	! . .
	xor a			;47eb	af		.
	ld d,a			;47ec	57		W
	call l4911h		;47ed	cd 11 49	. . I
	ld b,000h		;47f0	06 00		. .
	ld c,017h		;47f2	0e 17		. .
	jp WRTVDP		;47f4	c3 47 00	. G .
sub_47f7h:
	ld hl,0f600h		;47f7	21 00 f6	! . .
	ld a,0e0h		;47fa	3e e0		> .
	ld bc,00080h		;47fc	01 80 00	. . .
	call sub_468fh		;47ff	cd 8f 46	. . F
	jp 063cch		;4802	c3 cc 63	. . c
l4805h:
	ld a,(0ffe7h)		;4805	3a e7 ff	: . .
	or 002h			;4808	f6 02		. .
	ld b,a			;480a	47		G
	ld c,008h		;480b	0e 08		. .
	jp WRTVDP		;480d	c3 47 00	. G .
l4810h:
	ld a,(0ffe7h)		;4810	3a e7 ff	: . .
	and 0fdh		;4813	e6 fd		. .
	ld b,a			;4815	47		G
	ld c,008h		;4816	0e 08		. .
	jp WRTVDP		;4818	c3 47 00	. G .
sub_481bh:
	push bc			;481b	c5		.
	push hl			;481c	e5		.
	ld b,a			;481d	47		G
	ld a,(00007h)		;481e	3a 07 00	: . .
	inc a			;4821	3c		<
	ld c,a			;4822	4f		O
	di			;4823	f3		.
	out (c),b		;4824	ed 41		. A
	ld a,090h		;4826	3e 90		> .
	out (c),a		;4828	ed 79		. y
	inc c			;482a	0c		.
	out (c),d		;482b	ed 51		. Q
	push af			;482d	f5		.
	pop af			;482e	f1		.
	out (c),e		;482f	ed 59		. Y
	dec c			;4831	0d		.
	ld hl,0f680h		;4832	21 80 f6	! . .
	ld a,b			;4835	78		x
	add a,a			;4836	87		.
	add a,l			;4837	85		.
	ld l,a			;4838	6f		o
	call sub_46b6h		;4839	cd b6 46	. . F
	dec c			;483c	0d		.
	out (c),d		;483d	ed 51		. Q
	out (c),e		;483f	ed 59		. Y
	pop hl			;4841	e1		.
	pop bc			;4842	c1		.
	ei			;4843	fb		.
	ret			;4844	c9		.
l4845h:
	ld a,(hl)		;4845	7e		~
	inc hl			;4846	23		#
	inc a			;4847	3c		<
	ret z			;4848	c8		.
	dec a			;4849	3d		=
	ld d,(hl)		;484a	56		V
	inc hl			;484b	23		#
	ld e,(hl)		;484c	5e		^
	inc hl			;484d	23		#
	call sub_481bh		;484e	cd 1b 48	. . H
	jr l4845h		;4851	18 f2		. .
l4853h:
	ld a,002h		;4853	3e 02		> .
	call sub_485ch		;4855	cd 5c 48	. \ H
	rra			;4858	1f		.
	jr c,l4853h		;4859	38 f8		8 .
	ret			;485b	c9		.
sub_485ch:
	push bc			;485c	c5		.
	push hl			;485d	e5		.
	ld hl,(00006h)		;485e	2a 06 00	* . .
	inc h			;4861	24		$
	inc l			;4862	2c		,
	ld c,h			;4863	4c		L
	di			;4864	f3		.
	out (c),a		;4865	ed 79		. y
	ld a,08fh		;4867	3e 8f		> .
	out (c),a		;4869	ed 79		. y
	ld c,l			;486b	4d		M
	in a,(c)		;486c	ed 78		. x
	push af			;486e	f5		.
	xor a			;486f	af		.
	ld c,h			;4870	4c		L
	out (c),a		;4871	ed 79		. y
	ld a,08fh		;4873	3e 8f		> .
	out (c),a		;4875	ed 79		. y
	pop af			;4877	f1		.
	pop hl			;4878	e1		.
	pop bc			;4879	c1		.
	ei			;487a	fb		.
	ret			;487b	c9		.
sub_487ch:
	call l4853h		;487c	cd 53 48	. S H
	push bc			;487f	c5		.
	ld a,(00007h)		;4880	3a 07 00	: . .
	inc a			;4883	3c		<
	ld c,a			;4884	4f		O
	ld a,024h		;4885	3e 24		> $
	di			;4887	f3		.
	out (c),a		;4888	ed 79		. y
	ld a,091h		;488a	3e 91		> .
	out (c),a		;488c	ed 79		. y
	inc c			;488e	0c		.
	inc c			;488f	0c		.
	out (c),h		;4890	ed 61		. a
	xor a			;4892	af		.
	out (c),a		;4893	ed 79		. y
	out (c),l		;4895	ed 69		. i
	out (c),a		;4897	ed 79		. y
	pop hl			;4899	e1		.
	dec h			;489a	25		%
	out (c),h		;489b	ed 61		. a
	xor a			;489d	af		.
	out (c),a		;489e	ed 79		. y
	xor a			;48a0	af		.
	out (c),a		;48a1	ed 79		. y
	out (c),a		;48a3	ed 79		. y
	out (c),l		;48a5	ed 69		. i
	out (c),a		;48a7	ed 79		. y
	ld a,070h		;48a9	3e 70		> p
	out (c),a		;48ab	ed 79		. y
	ei			;48ad	fb		.
	ret			;48ae	c9		.
sub_48afh:
	call l4853h		;48af	cd 53 48	. S H
	push bc			;48b2	c5		.
	ld a,(00007h)		;48b3	3a 07 00	: . .
	inc a			;48b6	3c		<
	ld c,a			;48b7	4f		O
	ld a,024h		;48b8	3e 24		> $
	di			;48ba	f3		.
	out (c),a		;48bb	ed 79		. y
	ld a,091h		;48bd	3e 91		> .
	out (c),a		;48bf	ed 79		. y
	inc c			;48c1	0c		.
	inc c			;48c2	0c		.
	out (c),h		;48c3	ed 61		. a
	xor a			;48c5	af		.
	out (c),a		;48c6	ed 79		. y
	out (c),l		;48c8	ed 69		. i
	out (c),a		;48ca	ed 79		. y
	pop hl			;48cc	e1		.
	dec h			;48cd	25		%
	out (c),h		;48ce	ed 61		. a
	xor a			;48d0	af		.
	out (c),a		;48d1	ed 79		. y
	xor a			;48d3	af		.
	out (c),a		;48d4	ed 79		. y
	out (c),a		;48d6	ed 79		. y
	out (c),l		;48d8	ed 69		. i
	inc a			;48da	3c		<
	out (c),a		;48db	ed 79		. y
	ld a,070h		;48dd	3e 70		> p
	out (c),a		;48df	ed 79		. y
	ei			;48e1	fb		.
	ret			;48e2	c9		.
sub_48e3h:
	ld b,e			;48e3	43		C
	call sub_48fdh		;48e4	cd fd 48	. . H
	ld b,d			;48e7	42		B
	call sub_4907h		;48e8	cd 07 49	. . I
	push hl			;48eb	e5		.
	ld a,l			;48ec	7d		}
	dec a			;48ed	3d		=
	add a,e			;48ee	83		.
	ld l,a			;48ef	6f		o
	ld b,d			;48f0	42		B
	call sub_4907h		;48f1	cd 07 49	. . I
	pop hl			;48f4	e1		.
	ld a,h			;48f5	7c		|
	dec a			;48f6	3d		=
	add a,d			;48f7	82		.
	ld h,a			;48f8	67		g
	ld b,e			;48f9	43		C
	jp sub_48fdh		;48fa	c3 fd 48	. . H
sub_48fdh:
	push hl			;48fd	e5		.
	push de			;48fe	d5		.
	push bc			;48ff	c5		.
	call sub_48afh		;4900	cd af 48	. . H
	pop bc			;4903	c1		.
	pop de			;4904	d1		.
	pop hl			;4905	e1		.
	ret			;4906	c9		.
sub_4907h:
	push hl			;4907	e5		.
	push de			;4908	d5		.
	push bc			;4909	c5		.
	call sub_487ch		;490a	cd 7c 48	. | H
	pop bc			;490d	c1		.
	pop de			;490e	d1		.
	pop hl			;490f	e1		.
	ret			;4910	c9		.
l4911h:
	ex af,af'		;4911	08		.
	call l4853h		;4912	cd 53 48	. S H
	push bc			;4915	c5		.
	ld a,(00007h)		;4916	3a 07 00	: . .
	inc a			;4919	3c		<
	ld c,a			;491a	4f		O
	ld a,024h		;491b	3e 24		> $
	di			;491d	f3		.
	out (c),a		;491e	ed 79		. y
	ld a,091h		;4920	3e 91		> .
	out (c),a		;4922	ed 79		. y
	inc c			;4924	0c		.
	inc c			;4925	0c		.
	out (c),h		;4926	ed 61		. a
	xor a			;4928	af		.
	out (c),a		;4929	ed 79		. y
	out (c),l		;492b	ed 69		. i
	out (c),d		;492d	ed 51		. Q
	pop hl			;492f	e1		.
	out (c),h		;4930	ed 61		. a
	cp h			;4932	bc		.
	jr nz,l4936h		;4933	20 01		  .
	inc a			;4935	3c		<
l4936h:
	out (c),a		;4936	ed 79		. y
	xor a			;4938	af		.
	out (c),l		;4939	ed 69		. i
	cp l			;493b	bd		.
	jr nz,l493fh		;493c	20 01		  .
	inc a			;493e	3c		<
l493fh:
	out (c),a		;493f	ed 79		. y
	ex af,af'		;4941	08		.
	out (c),a		;4942	ed 79		. y
	xor a			;4944	af		.
	out (c),a		;4945	ed 79		. y
	ld a,0c0h		;4947	3e c0		> .
	out (c),a		;4949	ed 79		. y
	ei			;494b	fb		.
	ret			;494c	c9		.
sub_494dh:
	ex af,af'		;494d	08		.
	call l4853h		;494e	cd 53 48	. S H
	push bc			;4951	c5		.
	ld a,(00007h)		;4952	3a 07 00	: . .
	inc a			;4955	3c		<
	ld c,a			;4956	4f		O
	ld a,020h		;4957	3e 20		>  
	di			;4959	f3		.
	out (c),a		;495a	ed 79		. y
	ld a,091h		;495c	3e 91		> .
	out (c),a		;495e	ed 79		. y
	inc c			;4960	0c		.
	inc c			;4961	0c		.
	out (c),h		;4962	ed 61		. a
	xor a			;4964	af		.
	out (c),a		;4965	ed 79		. y
	out (c),l		;4967	ed 69		. i
	ex af,af'		;4969	08		.
	ld l,a			;496a	6f		o
	and 003h		;496b	e6 03		. .
	out (c),a		;496d	ed 79		. y
	out (c),d		;496f	ed 51		. Q
	xor a			;4971	af		.
	out (c),a		;4972	ed 79		. y
	out (c),e		;4974	ed 59		. Y
	ld a,l			;4976	7d		}
	rra			;4977	1f		.
	rra			;4978	1f		.
	and 003h		;4979	e6 03		. .
	out (c),a		;497b	ed 79		. y
	pop hl			;497d	e1		.
	out (c),h		;497e	ed 61		. a
	xor a			;4980	af		.
	out (c),a		;4981	ed 79		. y
	out (c),l		;4983	ed 69		. i
	out (c),a		;4985	ed 79		. y
	out (c),a		;4987	ed 79		. y
	out (c),a		;4989	ed 79		. y
	ld a,0d0h		;498b	3e d0		> .
	out (c),a		;498d	ed 79		. y
	ei			;498f	fb		.
	ret			;4990	c9		.
sub_4991h:
	ex af,af'		;4991	08		.
	call l4853h		;4992	cd 53 48	. S H
	push bc			;4995	c5		.
	ld a,(00007h)		;4996	3a 07 00	: . .
	inc a			;4999	3c		<
	ld c,a			;499a	4f		O
	ld a,024h		;499b	3e 24		> $
	di			;499d	f3		.
	out (c),a		;499e	ed 79		. y
	ld a,091h		;49a0	3e 91		> .
	out (c),a		;49a2	ed 79		. y
	inc c			;49a4	0c		.
	inc c			;49a5	0c		.
	out (c),d		;49a6	ed 51		. Q
	xor a			;49a8	af		.
	out (c),a		;49a9	ed 79		. y
	out (c),e		;49ab	ed 59		. Y
	ex af,af'		;49ad	08		.
	out (c),a		;49ae	ed 79		. y
	pop de			;49b0	d1		.
	out (c),d		;49b1	ed 51		. Q
	xor a			;49b3	af		.
	out (c),a		;49b4	ed 79		. y
	out (c),e		;49b6	ed 59		. Y
	out (c),a		;49b8	ed 79		. y
	ld a,(hl)		;49ba	7e		~
	inc hl			;49bb	23		#
	out (c),a		;49bc	ed 79		. y
	xor a			;49be	af		.
	out (c),a		;49bf	ed 79		. y
	ld a,0f0h		;49c1	3e f0		> .
	out (c),a		;49c3	ed 79		. y
	dec c			;49c5	0d		.
	dec c			;49c6	0d		.
	ld a,0ach		;49c7	3e ac		> .
	out (c),a		;49c9	ed 79		. y
	ld a,091h		;49cb	3e 91		> .
	out (c),a		;49cd	ed 79		. y
	inc c			;49cf	0c		.
	inc c			;49d0	0c		.
l49d1h:
	ld a,002h		;49d1	3e 02		> .
	call sub_485ch		;49d3	cd 5c 48	. \ H
	rra			;49d6	1f		.
	ret nc			;49d7	d0		.
	add a,a			;49d8	87		.
	add a,a			;49d9	87		.
	jr nc,l49d1h		;49da	30 f5		0 .
	ld a,(hl)		;49dc	7e		~
	inc hl			;49dd	23		#
	out (c),a		;49de	ed 79		. y
	jr l49d1h		;49e0	18 ef		. .
sub_49e2h:
	ex af,af'		;49e2	08		.
	call l4853h		;49e3	cd 53 48	. S H
	push bc			;49e6	c5		.
	ld a,(00007h)		;49e7	3a 07 00	: . .
	inc a			;49ea	3c		<
	ld c,a			;49eb	4f		O
	ld a,020h		;49ec	3e 20		>  
	di			;49ee	f3		.
	out (c),a		;49ef	ed 79		. y
	ld a,091h		;49f1	3e 91		> .
	out (c),a		;49f3	ed 79		. y
	inc c			;49f5	0c		.
	inc c			;49f6	0c		.
	out (c),h		;49f7	ed 61		. a
	xor a			;49f9	af		.
	out (c),a		;49fa	ed 79		. y
	out (c),l		;49fc	ed 69		. i
	ex af,af'		;49fe	08		.
	rlca			;49ff	07		.
	rlca			;4a00	07		.
	ld l,a			;4a01	6f		o
	and 003h		;4a02	e6 03		. .
	out (c),a		;4a04	ed 79		. y
	out (c),d		;4a06	ed 51		. Q
	xor a			;4a08	af		.
	out (c),a		;4a09	ed 79		. y
	out (c),e		;4a0b	ed 59		. Y
	ld a,l			;4a0d	7d		}
	ld e,a			;4a0e	5f		_
	rlca			;4a0f	07		.
	rlca			;4a10	07		.
	and 003h		;4a11	e6 03		. .
	out (c),a		;4a13	ed 79		. y
	pop hl			;4a15	e1		.
	out (c),h		;4a16	ed 61		. a
	xor a			;4a18	af		.
	out (c),a		;4a19	ed 79		. y
	out (c),l		;4a1b	ed 69		. i
	out (c),a		;4a1d	ed 79		. y
	out (c),a		;4a1f	ed 79		. y
	out (c),a		;4a21	ed 79		. y
	ld a,e			;4a23	7b		{
	rra			;4a24	1f		.
	rra			;4a25	1f		.
	and 00fh		;4a26	e6 0f		. .
	or 090h			;4a28	f6 90		. .
	out (c),a		;4a2a	ed 79		. y
	ei			;4a2c	fb		.
	ret			;4a2d	c9		.
l4a2eh:
	call sub_4a37h		;4a2e	cd 37 4a	. 7 J
	call sub_4b56h		;4a31	cd 56 4b	. V K
	djnz l4a2eh		;4a34	10 f8		. .
	ret			;4a36	c9		.
sub_4a37h:
	push bc			;4a37	c5		.
	push de			;4a38	d5		.
	push hl			;4a39	e5		.
	push de			;4a3a	d5		.
	call sub_4aach		;4a3b	cd ac 4a	. . J
	pop de			;4a3e	d1		.
	ld b,d			;4a3f	42		B
	ld d,e			;4a40	53		S
	ld e,b			;4a41	58		X
	srl d			;4a42	cb 3a		. :
	rr e			;4a44	cb 1b		. .
	ld a,d			;4a46	7a		z
	add a,080h		;4a47	c6 80		. .
	ld d,a			;4a49	57		W
	ld hl,0c110h		;4a4a	21 10 c1	! . .
	call sub_4a58h		;4a4d	cd 58 4a	. X J
	pop hl			;4a50	e1		.
	ld bc,SYNCHR		;4a51	01 08 00	. . .
	add hl,bc		;4a54	09		.
	pop de			;4a55	d1		.
	pop bc			;4a56	c1		.
	ret			;4a57	c9		.
sub_4a58h:
	push de			;4a58	d5		.
	ld b,008h		;4a59	06 08		. .
l4a5bh:
	push bc			;4a5b	c5		.
	ld bc,00004h		;4a5c	01 04 00	. . .
	call sub_467ch		;4a5f	cd 7c 46	. | F
	ex de,hl		;4a62	eb		.
	ld bc,00080h		;4a63	01 80 00	. . .
	add hl,bc		;4a66	09		.
	ex de,hl		;4a67	eb		.
	pop bc			;4a68	c1		.
	djnz l4a5bh		;4a69	10 f0		. .
	pop de			;4a6b	d1		.
	ret			;4a6c	c9		.
l4a6dh:
	push bc			;4a6d	c5		.
	call sub_4a58h		;4a6e	cd 58 4a	. X J
	ld a,004h		;4a71	3e 04		> .
	add a,e			;4a73	83		.
	cp 080h			;4a74	fe 80		. .
	jr nz,l4a7dh		;4a76	20 05		  .
	ld a,004h		;4a78	3e 04		> .
	add a,d			;4a7a	82		.
	ld d,a			;4a7b	57		W
	xor a			;4a7c	af		.
l4a7dh:
	ld e,a			;4a7d	5f		_
	pop bc			;4a7e	c1		.
	djnz l4a6dh		;4a7f	10 ec		. .
	ret			;4a81	c9		.
sub_4a82h:
	push de			;4a82	d5		.
	ld b,010h		;4a83	06 10		. .
l4a85h:
	push bc			;4a85	c5		.
	ld bc,SYNCHR		;4a86	01 08 00	. . .
	call sub_467ch		;4a89	cd 7c 46	. | F
	ex de,hl		;4a8c	eb		.
	ld bc,00080h		;4a8d	01 80 00	. . .
	add hl,bc		;4a90	09		.
	ex de,hl		;4a91	eb		.
	pop bc			;4a92	c1		.
	djnz l4a85h		;4a93	10 f0		. .
	pop de			;4a95	d1		.
	ret			;4a96	c9		.
l4a97h:
	push bc			;4a97	c5		.
	call sub_4a82h		;4a98	cd 82 4a	. . J
	ld a,008h		;4a9b	3e 08		> .
	add a,e			;4a9d	83		.
	cp 080h			;4a9e	fe 80		. .
	jr nz,l4aa7h		;4aa0	20 05		  .
	ld a,008h		;4aa2	3e 08		> .
	add a,d			;4aa4	82		.
	ld d,a			;4aa5	57		W
	xor a			;4aa6	af		.
l4aa7h:
	ld e,a			;4aa7	5f		_
	pop bc			;4aa8	c1		.
	djnz l4a97h		;4aa9	10 ec		. .
	ret			;4aab	c9		.
sub_4aach:
	ld b,008h		;4aac	06 08		. .
	ld de,0c110h		;4aae	11 10 c1	. . .
l4ab1h:
	push bc			;4ab1	c5		.
	push hl			;4ab2	e5		.
	ex de,hl		;4ab3	eb		.
	ld a,(de)		;4ab4	1a		.
	ld d,a			;4ab5	57		W
	ld b,004h		;4ab6	06 04		. .
l4ab8h:
	ld a,c			;4ab8	79		y
	rl d			;4ab9	cb 12		. .
	jr c,l4abeh		;4abb	38 01		8 .
	xor a			;4abd	af		.
l4abeh:
	rld			;4abe	ed 6f		. o
	ld a,c			;4ac0	79		y
	rl d			;4ac1	cb 12		. .
	jr c,l4ac6h		;4ac3	38 01		8 .
	xor a			;4ac5	af		.
l4ac6h:
	rld			;4ac6	ed 6f		. o
	inc hl			;4ac8	23		#
	djnz l4ab8h		;4ac9	10 ed		. .
	ex de,hl		;4acb	eb		.
	pop hl			;4acc	e1		.
	inc hl			;4acd	23		#
	pop bc			;4ace	c1		.
	djnz l4ab1h		;4acf	10 e0		. .
	ret			;4ad1	c9		.
l4ad2h:
	ld c,0ffh		;4ad2	0e ff		. .
	jr l4ad8h		;4ad4	18 02		. .
l4ad6h:
	ld c,000h		;4ad6	0e 00		. .
l4ad8h:
	ld d,(hl)		;4ad8	56		V
	inc hl			;4ad9	23		#
	ld e,(hl)		;4ada	5e		^
	inc hl			;4adb	23		#
l4adch:
	ld a,(hl)		;4adc	7e		~
	inc hl			;4add	23		#
	ld b,a			;4ade	47		G
	inc b			;4adf	04		.
	ret z			;4ae0	c8		.
	inc b			;4ae1	04		.
	jr z,l4ad2h		;4ae2	28 ee		( .
	and c			;4ae4	a1		.
	call sub_4aeeh		;4ae5	cd ee 4a	. . J
	ld a,d			;4ae8	7a		z
	add a,008h		;4ae9	c6 08		. .
	ld d,a			;4aeb	57		W
	jr l4adch		;4aec	18 ee		. .
sub_4aeeh:
	push bc			;4aee	c5		.
	push hl			;4aef	e5		.
	push de			;4af0	d5		.
	or a			;4af1	b7		.
	ld h,a			;4af2	67		g
	jr z,l4afah		;4af3	28 05		( .
	call sub_4b48h		;4af5	cd 48 4b	. H K
	add a,038h		;4af8	c6 38		. 8
l4afah:
	ld l,a			;4afa	6f		o
	ld bc,00808h		;4afb	01 08 08	. . .
	ld a,001h		;4afe	3e 01		> .
	call sub_494dh		;4b00	cd 4d 49	. M I
	pop de			;4b03	d1		.
	pop hl			;4b04	e1		.
	pop bc			;4b05	c1		.
	ret			;4b06	c9		.
l4b07h:
	push af			;4b07	f5		.
	call sub_4aeeh		;4b08	cd ee 4a	. . J
	call sub_4b56h		;4b0b	cd 56 4b	. V K
	pop af			;4b0e	f1		.
	djnz l4b07h		;4b0f	10 f6		. .
	ret			;4b11	c9		.
sub_4b12h:
	push bc			;4b12	c5		.
	push hl			;4b13	e5		.
	push de			;4b14	d5		.
	call sub_4b48h		;4b15	cd 48 4b	. H K
	ld bc,00808h		;4b18	01 08 08	. . .
	ld a,001h		;4b1b	3e 01		> .
	call sub_494dh		;4b1d	cd 4d 49	. M I
	pop de			;4b20	d1		.
	pop hl			;4b21	e1		.
	pop bc			;4b22	c1		.
	ret			;4b23	c9		.
	push bc			;4b24	c5		.
	push hl			;4b25	e5		.
	push de			;4b26	d5		.
	call sub_4b48h		;4b27	cd 48 4b	. H K
	ld bc,00808h		;4b2a	01 08 08	. . .
	ld a,048h		;4b2d	3e 48		> H
	call sub_49e2h		;4b2f	cd e2 49	. . I
	pop de			;4b32	d1		.
	pop hl			;4b33	e1		.
	pop bc			;4b34	c1		.
	ret			;4b35	c9		.
	push bc			;4b36	c5		.
	push hl			;4b37	e5		.
	push de			;4b38	d5		.
	call sub_4b48h		;4b39	cd 48 4b	. H K
	ld bc,00808h		;4b3c	01 08 08	. . .
	ld a,005h		;4b3f	3e 05		> .
	call sub_494dh		;4b41	cd 4d 49	. M I
	pop de			;4b44	d1		.
	pop hl			;4b45	e1		.
	pop bc			;4b46	c1		.
	ret			;4b47	c9		.
sub_4b48h:
	ld b,a			;4b48	47		G
	and 01fh		;4b49	e6 1f		. .
	add a,a			;4b4b	87		.
	add a,a			;4b4c	87		.
	add a,a			;4b4d	87		.
	ld h,a			;4b4e	67		g
	ld a,b			;4b4f	78		x
	and 0e0h		;4b50	e6 e0		. .
	rrca			;4b52	0f		.
	rrca			;4b53	0f		.
	ld l,a			;4b54	6f		o
	ret			;4b55	c9		.
sub_4b56h:
	ld a,d			;4b56	7a		z
	add a,008h		;4b57	c6 08		. .
	ld d,a			;4b59	57		W
	ret nz			;4b5a	c0		.
	ld a,e			;4b5b	7b		{
	add a,008h		;4b5c	c6 08		. .
	ld e,a			;4b5e	5f		_
	ret			;4b5f	c9		.
sub_4b60h:
	call sub_507dh		;4b60	cd 7d 50	. } P
	call l4805h		;4b63	cd 05 48	. . H
	ld a,005h		;4b66	3e 05		> .
	call CHGMOD		;4b68	cd 5f 00	. _ .
	call sub_47dbh		;4b6b	cd db 47	. . G
	xor a			;4b6e	af		.
	ld h,a			;4b6f	67		g
	ld l,a			;4b70	6f		o
	ld b,a			;4b71	47		G
	ld c,a			;4b72	4f		O
	ld d,a			;4b73	57		W
	call l4911h		;4b74	cd 11 49	. . I
	xor a			;4b77	af		.
	ld h,a			;4b78	67		g
	ld l,a			;4b79	6f		o
	ld b,a			;4b7a	47		G
	ld c,a			;4b7b	4f		O
	ld d,001h		;4b7c	16 01		. .
	call l4911h		;4b7e	cd 11 49	. . I
	call l4853h		;4b81	cd 53 48	. S H
	ld b,004h		;4b84	06 04		. .
	ld hl,l4b9ch		;4b86	21 9c 4b	! . K
l4b89h:
	push bc			;4b89	c5		.
	ld c,(hl)		;4b8a	4e		N
	inc hl			;4b8b	23		#
	ld b,(hl)		;4b8c	46		F
	inc hl			;4b8d	23		#
	push hl			;4b8e	e5		.
	call WRTVDP		;4b8f	cd 47 00	. G .
	pop hl			;4b92	e1		.
	pop bc			;4b93	c1		.
	djnz l4b89h		;4b94	10 f3		. .
	call sub_47f7h		;4b96	cd f7 47	. . G
	jp l47ceh		;4b99	c3 ce 47	. . G
l4b9ch:
	ld bc,00562h		;4b9c	01 62 05	. b .
	rst 28h			;4b9f	ef		.
	ld b,01fh		;4ba0	06 1f		. .
	dec bc			;4ba2	0b		.
	ld bc,0023ah		;4ba3	01 3a 02	. : .
	ret nz			;4ba6	c0		.
	and 040h		;4ba7	e6 40		. @
	jp z,l4e35h		;4ba9	ca 35 4e	. 5 N
	call sub_4bfbh		;4bac	cd fb 4b	. . K
	ld hl,0c00ch		;4baf	21 0c c0	! . .
	call sub_4bbbh		;4bb2	cd bb 4b	. . K
	call sub_4bc2h		;4bb5	cd c2 4b	. . K
l4bb8h:
	ld hl,0c007h		;4bb8	21 07 c0	! . .
sub_4bbbh:
	ld c,(hl)		;4bbb	4e		N
	ld (hl),a		;4bbc	77		w
	xor c			;4bbd	a9		.
	and (hl)		;4bbe	a6		.
	dec hl			;4bbf	2b		+
	ld (hl),a		;4bc0	77		w
	ret			;4bc1	c9		.
sub_4bc2h:
	ld e,08fh		;4bc2	1e 8f		. .
	ld a,00fh		;4bc4	3e 0f		> .
	call WRTPSG		;4bc6	cd 93 00	. . .
	ld a,00eh		;4bc9	3e 0e		> .
	di			;4bcb	f3		.
	call RDPSG		;4bcc	cd 96 00	. . .
	ei			;4bcf	fb		.
	cpl			;4bd0	2f		/
	and 03fh		;4bd1	e6 3f		. ?
	push af			;4bd3	f5		.
	ld a,008h		;4bd4	3e 08		> .
	call SNSMAT		;4bd6	cd 41 01	. A .
	cpl			;4bd9	2f		/
	ld e,a			;4bda	5f		_
	and 020h		;4bdb	e6 20		.  
	ld e,a			;4bdd	5f		_
	ld a,008h		;4bde	3e 08		> .
	call SNSMAT		;4be0	cd 41 01	. A .
	cpl			;4be3	2f		/
	rrca			;4be4	0f		.
	rrca			;4be5	0f		.
	ld b,a			;4be6	47		G
	and 004h		;4be7	e6 04		. .
	or e			;4be9	b3		.
	ld c,a			;4bea	4f		O
	ld a,b			;4beb	78		x
	rrca			;4bec	0f		.
	rrca			;4bed	0f		.
	ld b,a			;4bee	47		G
	and 018h		;4bef	e6 18		. .
	or c			;4bf1	b1		.
	ld c,a			;4bf2	4f		O
	ld a,b			;4bf3	78		x
	rrca			;4bf4	0f		.
	and 003h		;4bf5	e6 03		. .
	or c			;4bf7	b1		.
	pop bc			;4bf8	c1		.
	or b			;4bf9	b0		.
	ret			;4bfa	c9		.
sub_4bfbh:
	ld a,006h		;4bfb	3e 06		> .
	call SNSMAT		;4bfd	cd 41 01	. A .
	cpl			;4c00	2f		/
	rlca			;4c01	07		.
	rlca			;4c02	07		.
	rlca			;4c03	07		.
	and 007h		;4c04	e6 07		. .
	ret			;4c06	c9		.
; --- HUD / status-bar text set (drawn via 0x451a).  Text is ASCII-0x10, spelled
;     out here with vk(); leading numbers are VDP name-table positions, 0xFE ends
;     a field and 0xFF ends the set.  Byte-for-byte identical to the original.
l4c07h:
	LUA ALLPASS
	  vk({0x08,0x00,"SCORE",0x30,0xfe})           -- "SCORE" + score-digit tile
	  vk({0x08,0x0c,"PLAYER",0xfe})               -- "PLAYER"
	  vk({0x08,0x14,"ENEMY",0xfe})                -- "ENEMY" (0x14 = HP-bar icon)
	  vk({0xb0,0x00,0x50,0x30,0xfe})              -- enemy HP-bar cell position
	  vk({0xd4,0x00,0x40,0x30,0xfe})              -- player HP-bar cell position
	  vk({0x6c,0x00,"STAGE",0x30,0xff})           -- "STAGE" + number tile
	  vk({0x60,0x38,"STAGE",0x00,0x00,0x00,0xff}) -- "STAGE" (alternate position)
	ENDLUA
; --- 0x4C3F-0x4D0E: VDP name-table / tile-layout data for the title & HUD
;     screens (referenced by sub_4d4eh via l4c3fh/l4c5ah/l4ca0h).  This is DATA;
;     the instructions z80dasm shows below are a misdisassembly of that data and
;     are never executed.  TODO: convert to `db` (byte-exact) in a later pass.
l4c3fh:
	ld (bc),a		;4c3f	02		.
	cp 0f8h			;4c40	fe f8		. .
	inc bc			;4c42	03		.
	inc b			;4c43	04		.
	cp 0f8h			;4c44	fe f8		. .
	dec b			;4c46	05		.
	ld b,007h		;4c47	06 07		. .
	ex af,af'		;4c49	08		.
	cp 000h			;4c4a	fe 00		. .
	add hl,bc		;4c4c	09		.
	ld a,(bc)		;4c4d	0a		.
	dec bc			;4c4e	0b		.
	inc c			;4c4f	0c		.
	dec c			;4c50	0d		.
	cp 0f8h			;4c51	fe f8		. .
	ld c,00fh		;4c53	0e 0f		. .
	ld bc,01001h		;4c55	01 01 10	. . .
	ld de,02fffh		;4c58	11 ff 2f	. . /
	cpl			;4c5b	2f		/
	cp 0b0h			;4c5c	fe b0		. .
	ld d,017h		;4c5e	16 17		. .
	jr $+23			;4c60	18 15		. .
	ld bc,00101h		;4c62	01 01 01	. . .
	ld bc,02f28h		;4c65	01 28 2f	. ( /
	cpl			;4c68	2f		/
	ld (de),a		;4c69	12		.
	inc de			;4c6a	13		.
	inc d			;4c6b	14		.
	dec d			;4c6c	15		.
	cp 000h			;4c6d	fe 00		. .
	ld h,023h		;4c6f	26 23		& #
	inc h			;4c71	24		$
	dec h			;4c72	25		%
	ld bc,00101h		;4c73	01 01 01	. . .
	ld bc,01a19h		;4c76	01 19 1a	. . .
	dec de			;4c79	1b		.
l4c7ah:
	ld (02423h),hl		;4c7a	22 23 24	" # $
	dec h			;4c7d	25		%
	cp 000h			;4c7e	fe 00		. .
	inc e			;4c80	1c		.
	dec e			;4c81	1d		.
	ld e,01fh		;4c82	1e 1f		. .
	ld bc,00101h		;4c84	01 01 01	. . .
	ld bc,02a29h		;4c87	01 29 2a	. ) *
	dec hl			;4c8a	2b		+
	inc e			;4c8b	1c		.
	dec e			;4c8c	1d		.
	ld e,01fh		;4c8d	1e 1f		. .
	cp 000h			;4c8f	fe 00		. .
	jr nz,$+35		;4c91	20 21		  !
	inc l			;4c93	2c		,
	ld bc,00101h		;4c94	01 01 01	. . .
	ld bc,02d01h		;4c97	01 01 2d	. . -
	ld l,027h		;4c9a	2e 27		. '
	jr nz,l4cbfh		;4c9c	20 21		  !
	inc l			;4c9e	2c		,
	rst 38h			;4c9f	ff		.
l4ca0h:
	ld h,a			;4ca0	67		g
	ld (de),a		;4ca1	12		.
	inc de			;4ca2	13		.
	inc d			;4ca3	14		.
	dec d			;4ca4	15		.
	ld d,017h		;4ca5	16 17		. .
	jr $+27			;4ca7	18 19		. .
	ld a,(de)		;4ca9	1a		.
	dec de			;4caa	1b		.
	inc e			;4cab	1c		.
	dec e			;4cac	1d		.
	ld e,01fh		;4cad	1e 1f		. .
	jr nz,$+35		;4caf	20 21		  !
	cp 008h			;4cb1	fe 08		. .
	ld (02423h),hl		;4cb3	22 23 24	" # $
	dec h			;4cb6	25		%
	ld h,027h		;4cb7	26 27		& '
	jr z,l4ce4h		;4cb9	28 29		( )
	ld hl,(02c2bh)		;4cbb	2a 2b 2c	* + ,
	dec l			;4cbe	2d		-
l4cbfh:
	ld l,02fh		;4cbf	2e 2f		. /
	jr nc,l4cf4h		;4cc1	30 31		0 1
	cp 000h			;4cc3	fe 00		. .
	ld (03433h),a		;4cc5	32 33 34	2 3 4
	dec (hl)		;4cc8	35		5
	ld (hl),037h		;4cc9	36 37		6 7
	jr c,l4d06h		;4ccb	38 39		8 9
	ld a,(03c3bh)		;4ccd	3a 3b 3c	: ; <
	dec a			;4cd0	3d		=
	ld a,03fh		;4cd1	3e 3f		> ?
	ld b,b			;4cd3	40		@
	ld b,c			;4cd4	41		A
	cp 000h			;4cd5	fe 00		. .
	cp 0f8h			;4cd7	fe f8		. .
	ld b,d			;4cd9	42		B
	ld b,e			;4cda	43		C
	ld b,h			;4cdb	44		D
	ld b,l			;4cdc	45		E
	ld b,(hl)		;4cdd	46		F
	ld b,a			;4cde	47		G
	ld c,b			;4cdf	48		H
	ld b,a			;4ce0	47		G
	ld c,c			;4ce1	49		I
	ld c,d			;4ce2	4a		J
	ld c,e			;4ce3	4b		K
l4ce4h:
	ld c,h			;4ce4	4c		L
	ld c,l			;4ce5	4d		M
	cp 000h			;4ce6	fe 00		. .
	ld d,d			;4ce8	52		R
	ld d,e			;4ce9	53		S
	ld d,h			;4cea	54		T
	ld d,l			;4ceb	55		U
	ld d,(hl)		;4cec	56		V
	ld d,a			;4ced	57		W
	ld h,b			;4cee	60		`
	ld d,a			;4cef	57		W
	ld h,b			;4cf0	60		`
	ld h,c			;4cf1	61		a
	ld e,e			;4cf2	5b		[
	ld e,h			;4cf3	5c		\
l4cf4h:
	ld e,l			;4cf4	5d		]
	nop			;4cf5	00		.
	nop			;4cf6	00		.
	ld h,l			;4cf7	65		e
	ld h,l			;4cf8	65		e
	cp 000h			;4cf9	fe 00		. .
	ld c,(hl)		;4cfb	4e		N
	ld c,a			;4cfc	4f		O
	ld d,b			;4cfd	50		P
	ld d,c			;4cfe	51		Q
	ld e,b			;4cff	58		X
	ld e,c			;4d00	59		Y
	ld e,d			;4d01	5a		Z
	ld e,c			;4d02	59		Y
	ld l,b			;4d03	68		h
	ld l,c			;4d04	69		i
	ld l,d			;4d05	6a		j
l4d06h:
	ld e,(hl)		;4d06	5e		^
	ld e,a			;4d07	5f		_
	ld h,d			;4d08	62		b
	ld h,e			;4d09	63		c
	ld h,h			;4d0a	64		d
	ld h,e			;4d0b	63		c
	ld h,h			;4d0c	64		d
	ld h,(hl)		;4d0d	66		f
	rst 38h			;4d0e	ff		.
; --- Title / front-end text (drawn by sub_4d4eh).  ASCII-0x10 via vk(); leading
;     numbers are VDP position/attribute prefixes, 0xFE/0xFF are separators.
l4d0fh:
	LUA ALLPASS
	  vk({0x48,0x88,0x2a,0x00,"KONAMI 1986",0xfe})  -- "KONAMI 1986"
	  vk({0x48,0xa0,"PUSH SPACE KEY",0xff})         -- "PUSH SPACE KEY"
	ENDLUA
l4d30h:
	LUA ALLPASS
	  vk({0x48,0xa0,0x00,0x00,"PLAY START",0x00,0x00,0xff})  -- "PLAY START"
	ENDLUA
l4d41h:
	LUA ALLPASS
	  vk({0x58,0x58,"GAME",0x00,0x00,"OVER",0xff})  -- "GAME OVER"
	ENDLUA
sub_4d4eh:
	call sub_47dbh		;4d4e	cd db 47	. . G
	call sub_4de2h		;4d51	cd e2 4d	. . M
	call l4853h		;4d54	cd 53 48	. S H
	call sub_572eh		;4d57	cd 2e 57	. . W
	ld b,003h		;4d5a	06 03		. .
	ld de,06606h		;4d5c	11 06 66	. . f
l4d5fh:
	ld a,00fh		;4d5f	3e 0f		> .
	call sub_481bh		;4d61	cd 1b 48	. . H
	dec e			;4d64	1d		.
	dec e			;4d65	1d		.
	ld a,d			;4d66	7a		z
	sub 022h		;4d67	d6 22		. "
	ld d,a			;4d69	57		W
	ld hl,00800h		;4d6a	21 00 08	! . .
l4d6dh:
	dec hl			;4d6d	2b		+
	ld a,h			;4d6e	7c		|
	or l			;4d6f	b5		.
	jr nz,l4d6dh		;4d70	20 fb		  .
	djnz l4d5fh		;4d72	10 eb		. .
	ld b,000h		;4d74	06 00		. .
	ld c,007h		;4d76	0e 07		. .
	call WRTVDP		;4d78	cd 47 00	. G .
	ld a,00fh		;4d7b	3e 0f		> .
	ld de,00700h		;4d7d	11 00 07	. . .
	call sub_481bh		;4d80	cd 1b 48	. . H
	call sub_47f7h		;4d83	cd f7 47	. . G
	call sub_53bdh		;4d86	cd bd 53	. . S
	call sub_5a02h		;4d89	cd 02 5a	. . Z
	ld hl,CHRGTR		;4d8c	21 10 00	! . .
	ld bc,00068h		;4d8f	01 68 00	. h .
	ld a,0ffh		;4d92	3e ff		> .
	ld d,000h		;4d94	16 00		. .
	call l4911h		;4d96	cd 11 49	. . I
	ld hl,00516h		;4d99	21 16 05	! . .
	call 07ad6h		;4d9c	cd d6 7a	. . z
	ld hl,00569h		;4d9f	21 69 05	! i .
	call 07ad6h		;4da2	cd d6 7a	. . z
	ld a,(0002bh)		;4da5	3a 2b 00	: + .
	and 00fh		;4da8	e6 0f		. .
	jr nz,l4dc3h		;4daa	20 17		  .
	ld de,0a818h		;4dac	11 18 a8	. . .
	ld hl,l4c3fh		;4daf	21 3f 4c	! ? L
	call 07b39h		;4db2	cd 39 7b	. 9 {
	ld de,0a038h		;4db5	11 38 a0	. 8 .
	ld hl,04c5ah		;4db8	21 5a 4c	! Z L
	call 07b39h		;4dbb	cd 39 7b	. 9 {
	call 07af6h		;4dbe	cd f6 7a	. . z
	jr l4dd5h		;4dc1	18 12		. .
l4dc3h:
	ld de,03828h		;4dc3	11 28 38	. ( 8
	ld hl,l4ca0h		;4dc6	21 a0 4c	! . L
	call 07b39h		;4dc9	cd 39 7b	. 9 {
	ld de,0b830h		;4dcc	11 30 b8	. 0 .
	ld hl,l4c3fh		;4dcf	21 3f 4c	! ? L
	call 07b39h		;4dd2	cd 39 7b	. 9 {
l4dd5h:
	ld hl,l4d0fh		;4dd5	21 0f 4d	! . M
	call l4ad2h		;4dd8	cd d2 4a	. . J
	jp l47ceh		;4ddb	c3 ce 47	. . G
	ld d,001h		;4dde	16 01		. .
	jr l4de4h		;4de0	18 02		. .
sub_4de2h:
	ld d,000h		;4de2	16 00		. .
l4de4h:
	ld hl,CHKRAM		;4de4	21 00 00	! . .
	ld bc,CHKRAM		;4de7	01 00 00	. . .
	xor a			;4dea	af		.
	jp l4911h		;4deb	c3 11 49	. . I
sub_4deeh:
	ld hl,0c420h		;4dee	21 20 c4	!   .
	ld de,0c421h		;4df1	11 21 c4	. ! .
	ld bc,01bdfh		;4df4	01 df 1b	. . .
	xor a			;4df7	af		.
	ld (hl),a		;4df8	77		w
	ldir			;4df9	ed b0		. .
	ld (0c007h),a		;4dfb	32 07 c0	2 . .
	ld (0cf3dh),a		;4dfe	32 3d cf	2 = .
	ld (0d001h),a		;4e01	32 01 d0	2 . .
	ld (0d002h),a		;4e04	32 02 d0	2 . .
	inc a			;4e07	3c		<
	ld (0c413h),a		;4e08	32 13 c4	2 . .
	ld (0c411h),a		;4e0b	32 11 c4	2 . .
	ld (0d000h),a		;4e0e	32 00 d0	2 . .
	ld (0cf3ah),a		;4e11	32 3a cf	2 : .
	ld a,020h		;4e14	3e 20		>  
	ld (0c415h),a		;4e16	32 15 c4	2 . .
	ld a,080h		;4e19	3e 80		> .
	ld (0c418h),a		;4e1b	32 18 c4	2 . .
	call 062d7h		;4e1e	cd d7 62	. . b
	call 062edh		;4e21	cd ed 62	. . b
	jp sub_451ah		;4e24	c3 1a 45	. . E
sub_4e27h:
	call sub_5c2ch		;4e27	cd 2c 5c	. , \
	ld a,(0c41bh)		;4e2a	3a 1b c4	: . .
	and a			;4e2d	a7		.
	ret z			;4e2e	c8		.
	call sub_5a35h		;4e2f	cd 35 5a	. 5 Z
	jp 062fch		;4e32	c3 fc 62	. . b
l4e35h:
	ld hl,0cf3ah		;4e35	21 3a cf	! : .
	dec (hl)		;4e38	35		5
	jr z,l4e4dh		;4e39	28 12		( .
l4e3bh:
	ld a,(0cf3bh)		;4e3b	3a 3b cf	: ; .
	cp 0ffh			;4e3e	fe ff		. .
	jr z,l4e48h		;4e40	28 06		( .
	ld hl,0c007h		;4e42	21 07 c0	! . .
	jp l4bb8h		;4e45	c3 b8 4b	. . K
l4e48h:
	xor a			;4e48	af		.
	ld (0c413h),a		;4e49	32 13 c4	2 . .
	ret			;4e4c	c9		.
l4e4dh:
	inc hl			;4e4d	23		#
	inc hl			;4e4e	23		#
	ld c,(hl)		;4e4f	4e		N
	inc (hl)		;4e50	34		4
	ld de,l4e64h		;4e51	11 64 4e	. d N
	ld l,c			;4e54	69		i
	ld h,000h		;4e55	26 00		& .
	add hl,hl		;4e57	29		)
	add hl,de		;4e58	19		.
	ld a,(hl)		;4e59	7e		~
	ld (0cf3ah),a		;4e5a	32 3a cf	2 : .
	inc hl			;4e5d	23		#
	ld a,(hl)		;4e5e	7e		~
	ld (0cf3bh),a		;4e5f	32 3b cf	2 ; .
	jr l4e3bh		;4e62	18 d7		. .
l4e64h:
	ld d,000h		;4e64	16 00		. .
	dec hl			;4e66	2b		+
	ex af,af'		;4e67	08		.
	rlca			;4e68	07		.
	jr l4e82h		;4e69	18 17		. .
	ex af,af'		;4e6b	08		.
	ex af,af'		;4e6c	08		.
	jr l4ec4h		;4e6d	18 55		. U
	ex af,af'		;4e6f	08		.
	inc b			;4e70	04		.
	nop			;4e71	00		.
	djnz $+6		;4e72	10 04		. .
	add hl,bc		;4e74	09		.
	nop			;4e75	00		.
	ld b,c			;4e76	41		A
	ld hl,02922h		;4e77	21 22 29	! " )
	rlca			;4e7a	07		.
	add hl,sp		;4e7b	39		9
	dec h			;4e7c	25		%
	add hl,hl		;4e7d	29		)
	ld hl,(00408h)		;4e7e	2a 08 04	* . .
	add hl,hl		;4e81	29		)
l4e82h:
	ld c,l			;4e82	4d		M
	ex af,af'		;4e83	08		.
	rrca			;4e84	0f		.
	nop			;4e85	00		.
	ld a,(de)		;4e86	1a		.
	inc b			;4e87	04		.
	add hl,bc		;4e88	09		.
	inc d			;4e89	14		.
	rrca			;4e8a	0f		.
	inc b			;4e8b	04		.
	rlca			;4e8c	07		.
	nop			;4e8d	00		.
	ld e,(hl)		;4e8e	5e		^
	ex af,af'		;4e8f	08		.
	ld c,000h		;4e90	0e 00		. .
	inc d			;4e92	14		.
	inc b			;4e93	04		.
	rrca			;4e94	0f		.
	nop			;4e95	00		.
	ld c,h			;4e96	4c		L
	ld hl,0ff01h		;4e97	21 01 ff	! . .
sub_4e9ah:
	call 098f3h		;4e9a	cd f3 98	. . .
	call 0991fh		;4e9d	cd 1f 99	. . .
	call 064f3h		;4ea0	cd f3 64	. . d
	jp 065abh		;4ea3	c3 ab 65	. . e
	ld c,027h		;4ea6	0e 27		. '
	ld de,0e048h		;4ea8	11 48 e0	. H .
	jp l5f24h		;4eab	c3 24 5f	. $ _
	ld (ix+006h),001h	;4eae	dd 36 06 01	. 6 . .
	ld (ix+00bh),094h	;4eb2	dd 36 0b 94	. 6 . .
	ld (ix+00eh),a		;4eb6	dd 77 0e	. w .
	ret			;4eb9	c9		.
	xor a			;4eba	af		.
	ld (ix+008h),a		;4ebb	dd 77 08	. w .
	ld (ix+007h),a		;4ebe	dd 77 07	. w .
	ld de,0ffe0h		;4ec1	11 e0 ff	. . .
l4ec4h:
	jp 0a573h		;4ec4	c3 73 a5	. s .
	ld c,028h		;4ec7	0e 28		. (
	ld de,09038h		;4ec9	11 38 90	. 8 .
	call l5f24h		;4ecc	cd 24 5f	. $ _
	ld c,029h		;4ecf	0e 29		. )
	ld de,03068h		;4ed1	11 68 30	. h 0
	jp l5f24h		;4ed4	c3 24 5f	. $ _
	ld hl,0ffe0h		;4ed7	21 e0 ff	! . .
	ld de,CHKRAM		;4eda	11 00 00	. . .
	bit 0,(ix+000h)		;4edd	dd cb 00 46	. . . F
	jr z,l4ee9h		;4ee1	28 06		( .
	ld hl,DCOMPR		;4ee3	21 20 00	!   .
	ld de,0fff0h		;4ee6	11 f0 ff	. . .
l4ee9h:
	call 0a564h		;4ee9	cd 64 a5	. d .
	ex de,hl		;4eec	eb		.
	call 0a573h		;4eed	cd 73 a5	. s .
	ld (ix+006h),001h	;4ef0	dd 36 06 01	. 6 . .
	ld (ix+00bh),092h	;4ef4	dd 36 0b 92	. 6 . .
	xor a			;4ef8	af		.
	ld (ix+010h),a		;4ef9	dd 77 10	. w .
	ld (ix+00eh),a		;4efc	dd 77 0e	. w .
	ret			;4eff	c9		.
	inc (ix+010h)		;4f00	dd 34 10	. 4 .
	ld a,(ix+010h)		;4f03	dd 7e 10	. ~ .
	cp 004h			;4f06	fe 04		. .
	ret nz			;4f08	c0		.
	ld (ix+010h),000h	;4f09	dd 36 10 00	. 6 . .
	inc (ix+011h)		;4f0d	dd 34 11	. 4 .
	ld (ix+00bh),092h	;4f10	dd 36 0b 92	. 6 . .
	bit 0,(ix+011h)		;4f14	dd cb 11 46	. . . F
	ret z			;4f18	c8		.
	ld (ix+00bh),093h	;4f19	dd 36 0b 93	. 6 . .
	ret			;4f1d	c9		.
	ld c,02ah		;4f1e	0e 2a		. *
	ld de,0f0c0h		;4f20	11 c0 f0	. . .
	jp l5f24h		;4f23	c3 24 5f	. $ _
	ld (ix+00bh),098h	;4f26	dd 36 0b 98	. 6 . .
	xor a			;4f2a	af		.
	ld (ix+001h),a		;4f2b	dd 77 01	. w .
	ld (ix+013h),a		;4f2e	dd 77 13	. w .
	ld (ix+014h),a		;4f31	dd 77 14	. w .
	ld (ix+00eh),a		;4f34	dd 77 0e	. w .
	ld (ix+006h),001h	;4f37	dd 36 06 01	. 6 . .
	ret			;4f3b	c9		.
	ld a,(ix+001h)		;4f3c	dd 7e 01	. ~ .
	dec a			;4f3f	3d		=
	jr z,l4f5eh		;4f40	28 1c		( .
	call sub_4f67h		;4f42	cd 67 4f	. g O
	xor a			;4f45	af		.
	ld (ix+00ah),0ffh	;4f46	dd 36 0a ff	. 6 . .
	ld (ix+009h),080h	;4f4a	dd 36 09 80	. 6 . .
	ld (ix+008h),a		;4f4e	dd 77 08	. w .
	ld (ix+007h),a		;4f51	dd 77 07	. w .
	ld a,(ix+005h)		;4f54	dd 7e 05	. ~ .
	cp 080h			;4f57	fe 80		. .
	ret nc			;4f59	d0		.
	inc (ix+001h)		;4f5a	dd 34 01	. 4 .
	ret			;4f5d	c9		.
l4f5eh:
	ld (ix+006h),000h	;4f5e	dd 36 06 00	. 6 . .
	ld (ix+00bh),097h	;4f62	dd 36 0b 97	. 6 . .
	ret			;4f66	c9		.
sub_4f67h:
	ld a,(ix+014h)		;4f67	dd 7e 14	. ~ .
	add a,090h		;4f6a	c6 90		. .
	ld (ix+014h),a		;4f6c	dd 77 14	. w .
	jr nc,l4f74h		;4f6f	30 03		0 .
	inc (ix+013h)		;4f71	dd 34 13	. 4 .
l4f74h:
	ld a,(ix+013h)		;4f74	dd 7e 13	. ~ .
	rra			;4f77	1f		.
	rra			;4f78	1f		.
	and 003h		;4f79	e6 03		. .
	ld hl,l4f86h		;4f7b	21 86 4f	! . O
	call ADD_HL_A		;4f7e	cd 61 40	. a @
	ld a,(hl)		;4f81	7e		~
	ld (ix+00bh),a		;4f82	dd 77 0b	. w .
	ret			;4f85	c9		.
l4f86h:
	sbc a,b			;4f86	98		.
	sbc a,c			;4f87	99		.
	sbc a,d			;4f88	9a		.
	sbc a,c			;4f89	99		.
	ld hl,0d100h		;4f8a	21 00 d1	! . .
	ld a,(0d000h)		;4f8d	3a 00 d0	: . .
	ld b,a			;4f90	47		G
	ld a,(0d001h)		;4f91	3a 01 d0	: . .
	ld c,a			;4f94	4f		O
	jp l4fb6h		;4f95	c3 b6 4f	. . O
	ld hl,0d140h		;4f98	21 40 d1	! @ .
	ld de,DCOMPR		;4f9b	11 20 00	.   .
	ld b,016h		;4f9e	06 16		. .
l4fa0h:
	push bc			;4fa0	c5		.
	ld b,020h		;4fa1	06 20		.  
l4fa3h:
	ld a,(hl)		;4fa3	7e		~
	call sub_4b12h		;4fa4	cd 12 4b	. . K
	inc hl			;4fa7	23		#
	ld a,d			;4fa8	7a		z
	add a,008h		;4fa9	c6 08		. .
	ld d,a			;4fab	57		W
	djnz l4fa3h		;4fac	10 f5		. .
	pop bc			;4fae	c1		.
	ld a,e			;4faf	7b		{
	add a,008h		;4fb0	c6 08		. .
	ld e,a			;4fb2	5f		_
	djnz l4fa0h		;4fb3	10 eb		. .
	ret			;4fb5	c9		.
l4fb6h:
	ld (0c5d5h),hl		;4fb6	22 d5 c5	" . .
	ld (0c5d7h),bc		;4fb9	ed 43 d7 c5	. C . .
	di			;4fbd	f3		.
	ld hl,0f0f1h		;4fbe	21 f1 f0	! . .
	ld a,00bh		;4fc1	3e 0b		> .
	ld (entity_tbl_end),a	;4fc3	32 00 60	2 . `
	ld (hl),a		;4fc6	77		w
	inc l			;4fc7	2c		,
	inc a			;4fc8	3c		<
	ld (08000h),a		;4fc9	32 00 80	2 . .
	ld (hl),a		;4fcc	77		w
	inc l			;4fcd	2c		,
	inc a			;4fce	3c		<
	ld (0a000h),a		;4fcf	32 00 a0	2 . .
	ld (hl),a		;4fd2	77		w
	ei			;4fd3	fb		.
	ld a,(0c41ah)		;4fd4	3a 1a c4	: . .
	ld hl,0614bh		;4fd7	21 4b 61	! K a
	and a			;4fda	a7		.
	jr nz,l4ff7h		;4fdb	20 1a		  .
	ld a,(0c5d8h)		;4fdd	3a d8 c5	: . .
	ld hl,entity_tbl_end	;4fe0	21 00 60	! . `
	call ADD_HL_A		;4fe3	cd 61 40	. a @
	ld l,(hl)		;4fe6	6e		n
	ld a,(0c5d7h)		;4fe7	3a d7 c5	: . .
	add a,l			;4fea	85		.
	ld h,000h		;4feb	26 00		& .
	ld l,a			;4fed	6f		o
	add hl,hl		;4fee	29		)
	ld de,06013h		;4fef	11 13 60	. . `
	add hl,de		;4ff2	19		.
	ld e,(hl)		;4ff3	5e		^
	inc hl			;4ff4	23		#
	ld d,(hl)		;4ff5	56		V
	ex de,hl		;4ff6	eb		.
l4ff7h:
	ld de,(0c5d5h)		;4ff7	ed 5b d5 c5	. [ . .
	ld a,006h		;4ffb	3e 06		> .
l4ffdh:
	ex af,af'		;4ffd	08		.
	ld b,008h		;4ffe	06 08		. .
l5000h:
	ld a,(hl)		;5000	7e		~
	push de			;5001	d5		.
	exx			;5002	d9		.
	push af			;5003	f5		.
	ld a,(0c41ah)		;5004	3a 1a c4	: . .
	and a			;5007	a7		.
	ld bc,0a041h		;5008	01 41 a0	. A .
	jr nz,l501ah		;500b	20 0d		  .
	ld a,(0c5d8h)		;500d	3a d8 c5	: . .
	add a,a			;5010	87		.
	ld hl,07ebbh		;5011	21 bb 7e	! . ~
	call ADD_HL_A		;5014	cd 61 40	. a @
	ld c,(hl)		;5017	4e		N
	inc hl			;5018	23		#
	ld b,(hl)		;5019	46		F
l501ah:
	pop af			;501a	f1		.
	ld h,000h		;501b	26 00		& .
	ld l,a			;501d	6f		o
	add hl,hl		;501e	29		)
	add hl,hl		;501f	29		)
	add hl,hl		;5020	29		)
	add hl,hl		;5021	29		)
	add hl,bc		;5022	09		.
	ld bc,01cffh		;5023	01 ff 1c	. . .
	pop de			;5026	d1		.
	ldi			;5027	ed a0		. .
	ldi			;5029	ed a0		. .
	ldi			;502b	ed a0		. .
	ldi			;502d	ed a0		. .
	ld a,b			;502f	78		x
	add a,e			;5030	83		.
	ld e,a			;5031	5f		_
	ldi			;5032	ed a0		. .
	ldi			;5034	ed a0		. .
	ldi			;5036	ed a0		. .
	ldi			;5038	ed a0		. .
	ld a,b			;503a	78		x
	add a,e			;503b	83		.
	ld e,a			;503c	5f		_
	ldi			;503d	ed a0		. .
	ldi			;503f	ed a0		. .
	ldi			;5041	ed a0		. .
	ldi			;5043	ed a0		. .
	ld a,b			;5045	78		x
	add a,e			;5046	83		.
	ld e,a			;5047	5f		_
	ldi			;5048	ed a0		. .
	ldi			;504a	ed a0		. .
	ldi			;504c	ed a0		. .
	ldi			;504e	ed a0		. .
	exx			;5050	d9		.
	inc hl			;5051	23		#
	inc e			;5052	1c		.
	inc e			;5053	1c		.
	inc e			;5054	1c		.
	inc de			;5055	13		.
	djnz l5000h		;5056	10 a8		. .
	ex de,hl		;5058	eb		.
	ld bc,00060h		;5059	01 60 00	. ` .
	add hl,bc		;505c	09		.
	ex de,hl		;505d	eb		.
	ex af,af'		;505e	08		.
	dec a			;505f	3d		=
	jp nz,l4ffdh		;5060	c2 fd 4f	. . O
	di			;5063	f3		.
	push hl			;5064	e5		.
	ld hl,0f0f1h		;5065	21 f1 f0	! . .
	ld a,001h		;5068	3e 01		> .
	ld (entity_tbl_end),a	;506a	32 00 60	2 . `
	ld (hl),a		;506d	77		w
	inc a			;506e	3c		<
	ld (08000h),a		;506f	32 00 80	2 . .
	inc hl			;5072	23		#
	ld (hl),a		;5073	77		w
	inc a			;5074	3c		<
	ld (0a000h),a		;5075	32 00 a0	2 . .
	inc hl			;5078	23		#
	ld (hl),a		;5079	77		w
	pop hl			;507a	e1		.
	ei			;507b	fb		.
	ret			;507c	c9		.
sub_507dh:
	ld a,0bch		;507d	3e bc		> .
	ld (0c097h),a		;507f	32 97 c0	2 . .
	xor a			;5082	af		.
	ld (0c0a5h),a		;5083	32 a5 c0	2 . .
	ld (0c0a6h),a		;5086	32 a6 c0	2 . .
	ld (0c0a7h),a		;5089	32 a7 c0	2 . .
sub_508ch:
	xor a			;508c	af		.
	ld (0c096h),a		;508d	32 96 c0	2 . .
	ld (0c098h),a		;5090	32 98 c0	2 . .
	ld (0c0a8h),a		;5093	32 a8 c0	2 . .
	ld hl,089ceh		;5096	21 ce 89	! . .
	ld (0c010h),hl		;5099	22 10 c0	" . .
	ld (0c012h),hl		;509c	22 12 c0	" . .
	ld (0c014h),hl		;509f	22 14 c0	" . .
	ld (0c016h),hl		;50a2	22 16 c0	" . .
l50a5h:
	ret			;50a5	c9		.
sub_50a6h:
	push hl			;50a6	e5		.
	push de			;50a7	d5		.
	push bc			;50a8	c5		.
	push af			;50a9	f5		.
	di			;50aa	f3		.
	ld a,00eh		;50ab	3e 0e		> .
	ld (08000h),a		;50ad	32 00 80	2 . .
	ld (0f0f2h),a		;50b0	32 f2 f0	2 . .
	ei			;50b3	fb		.
	di			;50b4	f3		.
	ld a,00fh		;50b5	3e 0f		> .
	ld (0a000h),a		;50b7	32 00 a0	2 . .
	ld (0f0f3h),a		;50ba	32 f3 f0	2 . .
	ei			;50bd	fb		.
	pop af			;50be	f1		.
	di			;50bf	f3		.
	or a			;50c0	b7		.
	jp z,l51abh		;50c1	ca ab 51	. . Q
	cp 0fbh			;50c4	fe fb		. .
	jp nc,l51b1h		;50c6	d2 b1 51	. . Q
	or a			;50c9	b7		.
	jp p,l5171h		;50ca	f2 71 51	. q Q
	ld de,0c01ch		;50cd	11 1c c0	. . .
	ld hl,l515dh		;50d0	21 5d 51	! ] Q
	ld bc,WRSLT		;50d3	01 14 00	. . .
	ldir			;50d6	ed b0		. .
	ld hl,l515dh		;50d8	21 5d 51	! ] Q
	ld bc,WRSLT		;50db	01 14 00	. . .
	ldir			;50de	ed b0		. .
	ld hl,l515dh		;50e0	21 5d 51	! ] Q
	ld bc,WRSLT		;50e3	01 14 00	. . .
	ldir			;50e6	ed b0		. .
	and 07fh		;50e8	e6 7f		. .
	rlca			;50ea	07		.
	ld e,a			;50eb	5f		_
	rlca			;50ec	07		.
	add a,e			;50ed	83		.
	ld hl,08dc9h		;50ee	21 c9 8d	! . .
	add a,l			;50f1	85		.
	ld l,a			;50f2	6f		o
	jr nc,l50f6h		;50f3	30 01		0 .
	inc h			;50f5	24		$
l50f6h:
	ld e,(hl)		;50f6	5e		^
	inc hl			;50f7	23		#
	ld d,(hl)		;50f8	56		V
	inc hl			;50f9	23		#
	ld (0c01ch),de		;50fa	ed 53 1c c0	. S . .
	ld e,(hl)		;50fe	5e		^
	inc hl			;50ff	23		#
	ld d,(hl)		;5100	56		V
	inc hl			;5101	23		#
	ld (0c030h),de		;5102	ed 53 30 c0	. S 0 .
	ld e,(hl)		;5106	5e		^
	inc hl			;5107	23		#
	ld d,(hl)		;5108	56		V
	ld (0c044h),de		;5109	ed 53 44 c0	. S D .
	ld hl,08a64h		;510d	21 64 8a	! d .
	ld (0c010h),hl		;5110	22 10 c0	" . .
	ld hl,08a6bh		;5113	21 6b 8a	! k .
	ld (0c012h),hl		;5116	22 12 c0	" . .
	ld hl,08a72h		;5119	21 72 8a	! r .
	ld (0c014h),hl		;511c	22 14 c0	" . .
	xor a			;511f	af		.
	ld (0c096h),a		;5120	32 96 c0	2 . .
	ld hl,l50a5h		;5123	21 a5 50	! . P
	ld (0c016h),hl		;5126	22 16 c0	" . .
	ld a,(0c098h)		;5129	3a 98 c0	: . .
	and 0fdh		;512c	e6 fd		. .
	ld (0c098h),a		;512e	32 98 c0	2 . .
l5131h:
	xor a			;5131	af		.
	ld (0c0a5h),a		;5132	32 a5 c0	2 . .
	ld (0c0a6h),a		;5135	32 a6 c0	2 . .
	ld (0c0a8h),a		;5138	32 a8 c0	2 . .
	ld a,007h		;513b	3e 07		> .
	ld (0c0a7h),a		;513d	32 a7 c0	2 . .
l5140h:
	di			;5140	f3		.
	push hl			;5141	e5		.
	ld hl,0f0f1h		;5142	21 f1 f0	! . .
	ld a,001h		;5145	3e 01		> .
	ld (entity_tbl_end),a	;5147	32 00 60	2 . `
	ld (hl),a		;514a	77		w
	inc a			;514b	3c		<
	ld (08000h),a		;514c	32 00 80	2 . .
	inc hl			;514f	23		#
	ld (hl),a		;5150	77		w
	inc a			;5151	3c		<
	ld (0a000h),a		;5152	32 00 a0	2 . .
	inc hl			;5155	23		#
	ld (hl),a		;5156	77		w
	pop hl			;5157	e1		.
	ei			;5158	fb		.
	pop bc			;5159	c1		.
	pop de			;515a	d1		.
	pop hl			;515b	e1		.
	ret			;515c	c9		.
l515dh:
	nop			;515d	00		.
	nop			;515e	00		.
	ld bc,CHKRAM		;515f	01 00 00	. . .
	nop			;5162	00		.
	nop			;5163	00		.
	nop			;5164	00		.
	nop			;5165	00		.
	ld bc,CHKRAM		;5166	01 00 00	. . .
	nop			;5169	00		.
	nop			;516a	00		.
	ld bc,00001h		;516b	01 01 00	. . .
	nop			;516e	00		.
	nop			;516f	00		.
	nop			;5170	00		.
l5171h:
	ld c,a			;5171	4f		O
	ld a,(0c0a8h)		;5172	3a a8 c0	: . .
	or a			;5175	b7		.
	jp nz,l5140h		;5176	c2 40 51	. @ Q
	ld a,(0c096h)		;5179	3a 96 c0	: . .
	cp c			;517c	b9		.
	jp z,l5183h		;517d	ca 83 51	. . Q
	jp nc,l5140h		;5180	d2 40 51	. @ Q
l5183h:
	ld a,c			;5183	79		y
	ld (0c096h),a		;5184	32 96 c0	2 . .
	ld de,0c058h		;5187	11 58 c0	. X .
	ld hl,l515dh		;518a	21 5d 51	! ] Q
	ld bc,WRSLT		;518d	01 14 00	. . .
	ldir			;5190	ed b0		. .
	rlca			;5192	07		.
	ld hl,08d8dh		;5193	21 8d 8d	! . .
	add a,l			;5196	85		.
	ld l,a			;5197	6f		o
	jr nc,l519bh		;5198	30 01		0 .
	inc h			;519a	24		$
l519bh:
	ld e,(hl)		;519b	5e		^
	inc hl			;519c	23		#
	ld d,(hl)		;519d	56		V
	ld (0c064h),de		;519e	ed 53 64 c0	. S d .
	ld hl,08c9ch		;51a2	21 9c 8c	! . .
	ld (0c016h),hl		;51a5	22 16 c0	" . .
	jp l5140h		;51a8	c3 40 51	. @ Q
l51abh:
	call sub_508ch		;51ab	cd 8c 50	. . P
	jp l5140h		;51ae	c3 40 51	. @ Q
l51b1h:
	jp z,l527dh		;51b1	ca 7d 52	. } R
	cp 0fch			;51b4	fe fc		. .
	jp z,l52d0h		;51b6	ca d0 52	. . R
	cp 0fdh			;51b9	fe fd		. .
	jp z,l51cbh		;51bb	ca cb 51	. . Q
	cp 0feh			;51be	fe fe		. .
	jp z,l5234h		;51c0	ca 34 52	. 4 R
	ld a,03ah		;51c3	3e 3a		> :
	ld (0c0a5h),a		;51c5	32 a5 c0	2 . .
	jp l5140h		;51c8	c3 40 51	. @ Q
l51cbh:
	ld a,(0c098h)		;51cb	3a 98 c0	: . .
	or 001h			;51ce	f6 01		. .
	ld (0c098h),a		;51d0	32 98 c0	2 . .
	ld a,(0c0a5h)		;51d3	3a a5 c0	: . .
	ld (0c099h),a		;51d6	32 99 c0	2 . .
	ld a,(0c0a6h)		;51d9	3a a6 c0	: . .
	ld (0c09ah),a		;51dc	32 9a c0	2 . .
	ld a,(0c097h)		;51df	3a 97 c0	: . .
	ld (0c09bh),a		;51e2	32 9b c0	2 . .
	ld a,0bfh		;51e5	3e bf		> .
	ld (0c097h),a		;51e7	32 97 c0	2 . .
	xor a			;51ea	af		.
	call RDPSG		;51eb	cd 96 00	. . .
	ld (0c09ch),a		;51ee	32 9c c0	2 . .
	ld a,001h		;51f1	3e 01		> .
	call RDPSG		;51f3	cd 96 00	. . .
	ld (0c09dh),a		;51f6	32 9d c0	2 . .
	ld a,008h		;51f9	3e 08		> .
	call RDPSG		;51fb	cd 96 00	. . .
	ld (0c09eh),a		;51fe	32 9e c0	2 . .
	ld a,009h		;5201	3e 09		> .
	call RDPSG		;5203	cd 96 00	. . .
	ld (0c09fh),a		;5206	32 9f c0	2 . .
	ld a,00ah		;5209	3e 0a		> .
	call RDPSG		;520b	cd 96 00	. . .
	ld (0c0a0h),a		;520e	32 a0 c0	2 . .
	xor a			;5211	af		.
	ld (0c094h),a		;5212	32 94 c0	2 . .
	ld a,005h		;5215	3e 05		> .
	ld (0c095h),a		;5217	32 95 c0	2 . .
	ld hl,08a5dh		;521a	21 5d 8a	! ] .
	ld (0c01ah),hl		;521d	22 1a c0	" . .
	ld de,0c080h		;5220	11 80 c0	. . .
	ld hl,l515dh		;5223	21 5d 51	! ] Q
	ld bc,WRSLT		;5226	01 14 00	. . .
	ldir			;5229	ed b0		. .
	ld hl,09463h		;522b	21 63 94	! c .
	ld (0c080h),hl		;522e	22 80 c0	" . .
	jp l5131h		;5231	c3 31 51	. 1 Q
l5234h:
	ld a,(0c098h)		;5234	3a 98 c0	: . .
	and 0feh		;5237	e6 fe		. .
	ld (0c098h),a		;5239	32 98 c0	2 . .
	ld a,(0c099h)		;523c	3a 99 c0	: . .
	ld (0c0a5h),a		;523f	32 a5 c0	2 . .
	ld a,(0c09ah)		;5242	3a 9a c0	: . .
	ld (0c0a6h),a		;5245	32 a6 c0	2 . .
	ld a,(0c09bh)		;5248	3a 9b c0	: . .
	ld (0c097h),a		;524b	32 97 c0	2 . .
	ld a,(0c09ch)		;524e	3a 9c c0	: . .
	ld e,a			;5251	5f		_
	xor a			;5252	af		.
	call WRTPSG		;5253	cd 93 00	. . .
	ld a,(0c09dh)		;5256	3a 9d c0	: . .
	ld e,a			;5259	5f		_
	ld a,001h		;525a	3e 01		> .
	call WRTPSG		;525c	cd 93 00	. . .
	ld a,(0c09eh)		;525f	3a 9e c0	: . .
	ld e,a			;5262	5f		_
	ld a,008h		;5263	3e 08		> .
	call WRTPSG		;5265	cd 93 00	. . .
	ld a,(0c09fh)		;5268	3a 9f c0	: . .
	ld e,a			;526b	5f		_
	ld a,009h		;526c	3e 09		> .
	call WRTPSG		;526e	cd 93 00	. . .
	ld a,(0c0a0h)		;5271	3a a0 c0	: . .
	ld e,a			;5274	5f		_
	ld a,00ah		;5275	3e 0a		> .
	call WRTPSG		;5277	cd 93 00	. . .
	jp l5140h		;527a	c3 40 51	. @ Q
l527dh:
	ld a,(0c098h)		;527d	3a 98 c0	: . .
	or 002h			;5280	f6 02		. .
	ld (0c098h),a		;5282	32 98 c0	2 . .
	ld a,(0c097h)		;5285	3a 97 c0	: . .
	ld (0c0a1h),a		;5288	32 a1 c0	2 . .
	ld a,(0c096h)		;528b	3a 96 c0	: . .
	or a			;528e	b7		.
	jp nz,l5297h		;528f	c2 97 52	. . R
	ld a,0bfh		;5292	3e bf		> .
	jp l529ch		;5294	c3 9c 52	. . R
l5297h:
	ld a,(0c097h)		;5297	3a 97 c0	: . .
	or 01bh			;529a	f6 1b		. .
l529ch:
	ld (0c097h),a		;529c	32 97 c0	2 . .
	xor a			;529f	af		.
	call RDPSG		;52a0	cd 96 00	. . .
	ld (0c0a2h),a		;52a3	32 a2 c0	2 . .
	ld a,001h		;52a6	3e 01		> .
	call RDPSG		;52a8	cd 96 00	. . .
	ld (0c0a3h),a		;52ab	32 a3 c0	2 . .
	ld a,008h		;52ae	3e 08		> .
	call RDPSG		;52b0	cd 96 00	. . .
	ld (0c0a4h),a		;52b3	32 a4 c0	2 . .
	ld hl,08c95h		;52b6	21 95 8c	! . .
	ld (0c018h),hl		;52b9	22 18 c0	" . .
	ld de,0c06ch		;52bc	11 6c c0	. l .
	ld hl,l515dh		;52bf	21 5d 51	! ] Q
	ld bc,WRSLT		;52c2	01 14 00	. . .
	ldir			;52c5	ed b0		. .
	ld hl,0948bh		;52c7	21 8b 94	! . .
	ld (0c078h),hl		;52ca	22 78 c0	" x .
	jp l5140h		;52cd	c3 40 51	. @ Q
l52d0h:
	ld a,(0c098h)		;52d0	3a 98 c0	: . .
	and 0fdh		;52d3	e6 fd		. .
	ld (0c098h),a		;52d5	32 98 c0	2 . .
	ld a,(0c096h)		;52d8	3a 96 c0	: . .
	or a			;52db	b7		.
	ld a,(0c0a1h)		;52dc	3a a1 c0	: . .
	jp z,l52f0h		;52df	ca f0 52	. . R
	ld b,a			;52e2	47		G
	ld a,(0c097h)		;52e3	3a 97 c0	: . .
	or 0dbh			;52e6	f6 db		. .
	and b			;52e8	a0		.
	ld b,a			;52e9	47		G
	ld a,(0c097h)		;52ea	3a 97 c0	: . .
	and 024h		;52ed	e6 24		. $
	or b			;52ef	b0		.
l52f0h:
	ld (0c097h),a		;52f0	32 97 c0	2 . .
	ld a,(0c0a2h)		;52f3	3a a2 c0	: . .
	ld e,a			;52f6	5f		_
	xor a			;52f7	af		.
	call WRTPSG		;52f8	cd 93 00	. . .
	ld a,(0c0a3h)		;52fb	3a a3 c0	: . .
	ld e,a			;52fe	5f		_
	ld a,001h		;52ff	3e 01		> .
	call WRTPSG		;5301	cd 93 00	. . .
	ld a,(0c0a4h)		;5304	3a a4 c0	: . .
	ld e,a			;5307	5f		_
	ld a,008h		;5308	3e 08		> .
	call WRTPSG		;530a	cd 93 00	. . .
	jp l5140h		;530d	c3 40 51	. @ Q
	ld a,(0c0a6h)		;5310	3a a6 c0	: . .
	cp 0f8h			;5313	fe f8		. .
	ret			;5315	c9		.
	call sub_5369h		;5316	cd 69 53	. i S
	ld hl,0be59h		;5319	21 59 be	! Y .
	ld de,00800h		;531c	11 00 08	. . .
	ld bc,00d01h		;531f	01 01 0d	. . .
	call l4a2eh		;5322	cd 2e 4a	. . J
	ld hl,0bec1h		;5325	21 c1 be	! . .
	ld de,07000h		;5328	11 00 70	. . p
	ld bc,00d02h		;532b	01 02 0d	. . .
	call l4a2eh		;532e	cd 2e 4a	. . J
	ld hl,0bf29h		;5331	21 29 bf	! ) .
	ld de,0d800h		;5334	11 00 d8	. . .
	ld bc,01a03h		;5337	01 03 1a	. . .
	call l4a2eh		;533a	cd 2e 4a	. . J
sub_533dh:
	di			;533d	f3		.
	push hl			;533e	e5		.
	ld hl,0f0f1h		;533f	21 f1 f0	! . .
	ld a,001h		;5342	3e 01		> .
	ld (entity_tbl_end),a	;5344	32 00 60	2 . `
	ld (hl),a		;5347	77		w
	inc a			;5348	3c		<
	ld (08000h),a		;5349	32 00 80	2 . .
	inc hl			;534c	23		#
	ld (hl),a		;534d	77		w
	inc a			;534e	3c		<
	ld (0a000h),a		;534f	32 00 a0	2 . .
	inc hl			;5352	23		#
	ld (hl),a		;5353	77		w
	pop hl			;5354	e1		.
	ei			;5355	fb		.
	ret			;5356	c9		.
sub_5357h:
	di			;5357	f3		.
	ld hl,0f0f2h		;5358	21 f2 f0	! . .
	ld a,00eh		;535b	3e 0e		> .
	ld (08000h),a		;535d	32 00 80	2 . .
	ld (hl),a		;5360	77		w
	inc l			;5361	2c		,
	inc a			;5362	3c		<
	ld (0a000h),a		;5363	32 00 a0	2 . .
	ld (hl),a		;5366	77		w
	ei			;5367	fb		.
	ret			;5368	c9		.
sub_5369h:
	di			;5369	f3		.
	ld hl,0f0f1h		;536a	21 f1 f0	! . .
	ld a,00bh		;536d	3e 0b		> .
	ld (entity_tbl_end),a	;536f	32 00 60	2 . `
	ld (hl),a		;5372	77		w
	inc l			;5373	2c		,
	inc a			;5374	3c		<
	ld (08000h),a		;5375	32 00 80	2 . .
	ld (hl),a		;5378	77		w
	inc l			;5379	2c		,
	inc a			;537a	3c		<
	ld (0a000h),a		;537b	32 00 a0	2 . .
	ld (hl),a		;537e	77		w
	ei			;537f	fb		.
	ret			;5380	c9		.
sub_5381h:
	di			;5381	f3		.
	ld hl,0f0f2h		;5382	21 f2 f0	! . .
	ld a,009h		;5385	3e 09		> .
	ld (08000h),a		;5387	32 00 80	2 . .
	ld (hl),a		;538a	77		w
	inc l			;538b	2c		,
	inc a			;538c	3c		<
	ld (0a000h),a		;538d	32 00 a0	2 . .
	ld (hl),a		;5390	77		w
	ei			;5391	fb		.
	ret			;5392	c9		.
sub_5393h:
	di			;5393	f3		.
	ld hl,0f0f2h		;5394	21 f2 f0	! . .
	ld a,007h		;5397	3e 07		> .
	ld (08000h),a		;5399	32 00 80	2 . .
	ld (hl),a		;539c	77		w
	inc l			;539d	2c		,
	inc a			;539e	3c		<
	ld (0a000h),a		;539f	32 00 a0	2 . .
	ld (hl),a		;53a2	77		w
	ei			;53a3	fb		.
	ret			;53a4	c9		.
sub_53a5h:
	di			;53a5	f3		.
	ld hl,0f0f1h		;53a6	21 f1 f0	! . .
	ld a,004h		;53a9	3e 04		> .
	ld (entity_tbl_end),a	;53ab	32 00 60	2 . `
	ld (hl),a		;53ae	77		w
	inc l			;53af	2c		,
	inc a			;53b0	3c		<
	ld (08000h),a		;53b1	32 00 80	2 . .
	ld (hl),a		;53b4	77		w
	inc l			;53b5	2c		,
	inc a			;53b6	3c		<
	ld (0a000h),a		;53b7	32 00 a0	2 . .
	ld (hl),a		;53ba	77		w
	ei			;53bb	fb		.
	ret			;53bc	c9		.
sub_53bdh:
	call sub_5393h		;53bd	cd 93 53	. . S
	ld de,CHKRAM		;53c0	11 00 00	. . .
	ld c,000h		;53c3	0e 00		. .
	ld hl,0bed8h		;53c5	21 d8 be	! . .
	call sub_4a37h		;53c8	cd 37 4a	. 7 J
	ld de,00040h		;53cb	11 40 00	. @ .
	ld hl,0bd80h		;53ce	21 80 bd	! . .
	ld bc,0300eh		;53d1	01 0e 30	. . 0
	call l4a2eh		;53d4	cd 2e 4a	. . J
	ld hl,0bf00h		;53d7	21 00 bf	! . .
	ld de,0a440h		;53da	11 40 a4	. @ .
	ld b,001h		;53dd	06 01		. .
	call l4a6dh		;53df	cd 6d 4a	. m J
	jp sub_533dh		;53e2	c3 3d 53	. = S
	call sub_5357h		;53e5	cd 57 53	. W S
	ld de,08040h		;53e8	11 40 80	. @ .
	ld hl,08824h		;53eb	21 24 88	! $ .
	ld bc,00e0eh		;53ee	01 0e 0e	. . .
	call l4a2eh		;53f1	cd 2e 4a	. . J
	ld de,00848h		;53f4	11 48 08	. H .
	ld hl,08894h		;53f7	21 94 88	! . .
	ld bc,01a0eh		;53fa	01 0e 1a	. . .
	call l4a2eh		;53fd	cd 2e 4a	. . J
	jp sub_533dh		;5400	c3 3d 53	. = S
	ld (hl),001h		;5403	36 01		6 .
	ld de,(0c5adh)		;5405	ed 5b ad c5	. [ . .
	ld hl,l5428h		;5409	21 28 54	! ( T
	ld b,006h		;540c	06 06		. .
l540eh:
	push bc			;540e	c5		.
	push de			;540f	d5		.
	push hl			;5410	e5		.
	ld a,(hl)		;5411	7e		~
	inc hl			;5412	23		#
	ld h,(hl)		;5413	66		f
	ld l,a			;5414	6f		o
	ld bc,00808h		;5415	01 08 08	. . .
	xor a			;5418	af		.
	call sub_4991h		;5419	cd 91 49	. . I
	pop hl			;541c	e1		.
	inc hl			;541d	23		#
	inc hl			;541e	23		#
	pop de			;541f	d1		.
	ld a,e			;5420	7b		{
	add a,008h		;5421	c6 08		. .
	ld e,a			;5423	5f		_
	pop bc			;5424	c1		.
	djnz l540eh		;5425	10 e7		. .
	ret			;5427	c9		.
l5428h:
	inc (hl)		;5428	34		4
	ld d,h			;5429	54		T
	ld d,h			;542a	54		T
	ld d,h			;542b	54		T
	inc (hl)		;542c	34		4
	ld d,h			;542d	54		T
	ld d,h			;542e	54		T
	ld d,h			;542f	54		T
	ld d,h			;5430	54		T
	ld d,h			;5431	54		T
	ld (hl),h		;5432	74		t
	ld d,h			;5433	54		T
	nop			;5434	00		.
	jp 0003ch		;5435	c3 3c 00	. < .
	nop			;5438	00		.
	jp 0003ch		;5439	c3 3c 00	. < .
	inc c			;543c	0c		.
	jp 0c03ch		;543d	c3 3c c0	. < .
	inc bc			;5440	03		.
	inc sp			;5441	33		3
	inc sp			;5442	33		3
	jr nc,$+5		;5443	30 03		0 .
	inc sp			;5445	33		3
	inc sp			;5446	33		3
	jr nc,$+5		;5447	30 03		0 .
	inc sp			;5449	33		3
	inc sp			;544a	33		3
	jr nc,l5450h		;544b	30 03		0 .
	inc bc			;544d	03		.
	jr nc,$+50		;544e	30 30		0 0
l5450h:
	nop			;5450	00		.
	jp 0003ch		;5451	c3 3c 00	. < .
	nop			;5454	00		.
	jp 0003ch		;5455	c3 3c 00	. < .
	nop			;5458	00		.
	jp 0003ch		;5459	c3 3c 00	. < .
	nop			;545c	00		.
	jp 0003ch		;545d	c3 3c 00	. < .
	nop			;5460	00		.
	jp 0003ch		;5461	c3 3c 00	. < .
	nop			;5464	00		.
	jp 0003ch		;5465	c3 3c 00	. < .
	nop			;5468	00		.
	jp 0003ch		;5469	c3 3c 00	. < .
	nop			;546c	00		.
	jp 0003ch		;546d	c3 3c 00	. < .
	nop			;5470	00		.
	jp 0003ch		;5471	c3 3c 00	. < .
	nop			;5474	00		.
	jp 0003ch		;5475	c3 3c 00	. < .
	inc c			;5478	0c		.
	jp 0c03ch		;5479	c3 3c c0	. < .
	inc bc			;547c	03		.
	inc sp			;547d	33		3
	inc sp			;547e	33		3
	jr nc,$+5		;547f	30 03		0 .
	inc sp			;5481	33		3
	inc sp			;5482	33		3
	jr nc,$+5		;5483	30 03		0 .
	inc sp			;5485	33		3
	inc sp			;5486	33		3
	jr nc,l548ch		;5487	30 03		0 .
	inc bc			;5489	03		.
	jr nc,$+50		;548a	30 30		0 0
l548ch:
	nop			;548c	00		.
	jp 0003ch		;548d	c3 3c 00	. < .
	nop			;5490	00		.
	nop			;5491	00		.
	nop			;5492	00		.
	nop			;5493	00		.
	call sub_5381h		;5494	cd 81 53	. . S
	ld hl,09000h		;5497	21 00 90	! . .
	ld de,0a800h		;549a	11 00 a8	. . .
	ld b,014h		;549d	06 14		. .
	call l4a97h		;549f	cd 97 4a	. . J
	ld hl,09a00h		;54a2	21 00 9a	! . .
	ld de,0b028h		;54a5	11 28 b0	. ( .
	ld b,001h		;54a8	06 01		. .
	call l4a97h		;54aa	cd 97 4a	. . J
	ld hl,09a80h		;54ad	21 80 9a	! . .
	ld de,08c70h		;54b0	11 70 8c	. p .
	ld bc,00804h		;54b3	01 04 08	. . .
	ld a,001h		;54b6	3e 01		> .
	call sub_4991h		;54b8	cd 91 49	. . I
	ld de,08074h		;54bb	11 74 80	. t .
	ld b,004h		;54be	06 04		. .
l54c0h:
	push bc			;54c0	c5		.
	push de			;54c1	d5		.
	ld hl,09a90h		;54c2	21 90 9a	! . .
	ld bc,00808h		;54c5	01 08 08	. . .
	ld a,001h		;54c8	3e 01		> .
	call sub_4991h		;54ca	cd 91 49	. . I
	pop de			;54cd	d1		.
	pop bc			;54ce	c1		.
	ld a,d			;54cf	7a		z
	add a,008h		;54d0	c6 08		. .
	ld d,a			;54d2	57		W
	djnz l54c0h		;54d3	10 eb		. .
	call sub_53a5h		;54d5	cd a5 53	. . S
	ld hl,0b9c8h		;54d8	21 c8 b9	! . .
	ld de,0b030h		;54db	11 30 b0	. 0 .
	ld b,008h		;54de	06 08		. .
	call l4a97h		;54e0	cd 97 4a	. . J
	ld hl,0bdc8h		;54e3	21 c8 bd	! . .
	ld de,0b800h		;54e6	11 00 b8	. . .
	ld b,005h		;54e9	06 05		. .
	call l4a97h		;54eb	cd 97 4a	. . J
	call sub_5381h		;54ee	cd 81 53	. . S
	call sub_54f7h		;54f1	cd f7 54	. . T
	jp sub_533dh		;54f4	c3 3d 53	. = S
sub_54f7h:
	ld ix,l5595h		;54f7	dd 21 95 55	. ! . U
	ld de,0d000h		;54fb	11 00 d0	. . .
	ld b,005h		;54fe	06 05		. .
l5500h:
	push bc			;5500	c5		.
	push de			;5501	d5		.
	call sub_5514h		;5502	cd 14 55	. . U
	call sub_554fh		;5505	cd 4f 55	. O U
	pop de			;5508	d1		.
	ld a,010h		;5509	3e 10		> .
	call ADD_DE_A		;550b	cd 66 40	. f @
	pop bc			;550e	c1		.
	inc ix			;550f	dd 23		. #
	djnz l5500h		;5511	10 ed		. .
	ret			;5513	c9		.
sub_5514h:
	exx			;5514	d9		.
	ld de,0e800h		;5515	11 00 e8	. . .
	ld hl,0bda7h		;5518	21 a7 bd	! . .
	ld b,000h		;551b	06 00		. .
l551dh:
	push bc			;551d	c5		.
	ld a,(hl)		;551e	7e		~
	inc hl			;551f	23		#
	ld b,a			;5520	47		G
	rrca			;5521	0f		.
	rrca			;5522	0f		.
	rrca			;5523	0f		.
	rrca			;5524	0f		.
	and 00fh		;5525	e6 0f		. .
	cp 00fh			;5527	fe 0f		. .
	jr nz,l552eh		;5529	20 03		  .
	and (ix+000h)		;552b	dd a6 00	. . .
l552eh:
	add a,a			;552e	87		.
	add a,a			;552f	87		.
	add a,a			;5530	87		.
	add a,a			;5531	87		.
	ld c,a			;5532	4f		O
	ld a,b			;5533	78		x
	and 00fh		;5534	e6 0f		. .
	cp 00fh			;5536	fe 0f		. .
	jr nz,l553dh		;5538	20 03		  .
	and (ix+000h)		;553a	dd a6 00	. . .
l553dh:
	or c			;553d	b1		.
	ld (de),a		;553e	12		.
	inc de			;553f	13		.
	pop bc			;5540	c1		.
	djnz l551dh		;5541	10 da		. .
	xor a			;5543	af		.
	ld (de),a		;5544	12		.
	ld h,d			;5545	62		b
	ld l,e			;5546	6b		k
	inc de			;5547	13		.
	ld bc,0001fh		;5548	01 1f 00	. . .
	ldir			;554b	ed b0		. .
	exx			;554d	d9		.
	ret			;554e	c9		.
sub_554fh:
	ld hl,l5575h		;554f	21 75 55	! u U
	ld b,004h		;5552	06 04		. .
l5554h:
	push bc			;5554	c5		.
	push de			;5555	d5		.
	ld b,004h		;5556	06 04		. .
l5558h:
	push bc			;5558	c5		.
	push hl			;5559	e5		.
	ld a,(hl)		;555a	7e		~
	inc hl			;555b	23		#
	ld h,(hl)		;555c	66		f
	ld l,a			;555d	6f		o
	call sub_4a58h		;555e	cd 58 4a	. X J
	ld a,004h		;5561	3e 04		> .
	call ADD_DE_A		;5563	cd 66 40	. f @
	pop hl			;5566	e1		.
	inc hl			;5567	23		#
	inc hl			;5568	23		#
	pop bc			;5569	c1		.
	djnz l5558h		;556a	10 ec		. .
	pop de			;556c	d1		.
	ld a,d			;556d	7a		z
	add a,004h		;556e	c6 04		. .
	ld d,a			;5570	57		W
	pop bc			;5571	c1		.
	djnz l5554h		;5572	10 e0		. .
	ret			;5574	c9		.
l5575h:
	nop			;5575	00		.
	jp (hl)			;5576	e9		.
	nop			;5577	00		.
	jp (hl)			;5578	e9		.
	nop			;5579	00		.
	jp (hl)			;557a	e9		.
	nop			;557b	00		.
	jp (hl)			;557c	e9		.
	nop			;557d	00		.
	jp (hl)			;557e	e9		.
	nop			;557f	00		.
	ret pe			;5580	e8		.
	jr nz,$-22		;5581	20 e8		  .
	ld b,b			;5583	40		@
	ret pe			;5584	e8		.
	nop			;5585	00		.
	jp (hl)			;5586	e9		.
	ld h,b			;5587	60		`
	ret pe			;5588	e8		.
	add a,b			;5589	80		.
	ret pe			;558a	e8		.
	nop			;558b	00		.
	jp (hl)			;558c	e9		.
	and b			;558d	a0		.
	ret pe			;558e	e8		.
	ret nz			;558f	c0		.
	ret pe			;5590	e8		.
	ret po			;5591	e0		.
	ret pe			;5592	e8		.
	nop			;5593	00		.
	jp (hl)			;5594	e9		.
l5595h:
	inc bc			;5595	03		.
	ex af,af'		;5596	08		.
	ld (bc),a		;5597	02		.
	ld c,00fh		;5598	0e 0f		. .
	call sub_5381h		;559a	cd 81 53	. . S
	ld a,(0c416h)		;559d	3a 16 c4	: . .
	cp 005h			;55a0	fe 05		. .
	jr z,l55dbh		;55a2	28 37		( 7
	dec a			;55a4	3d		=
	jr z,l55dbh		;55a5	28 34		( 4
	dec a			;55a7	3d		=
	add a,a			;55a8	87		.
	ld hl,l55deh		;55a9	21 de 55	! . U
	call ADD_HL_A		;55ac	cd 61 40	. a @
	ld e,(hl)		;55af	5e		^
	inc hl			;55b0	23		#
	ld d,(hl)		;55b1	56		V
	ld hl,0f8c0h		;55b2	21 c0 f8	! . .
	call sub_46f8h		;55b5	cd f8 46	. . F
	ld a,(0c416h)		;55b8	3a 16 c4	: . .
	cp 004h			;55bb	fe 04		. .
	jr z,l55cfh		;55bd	28 10		( .
	cp 003h			;55bf	fe 03		. .
	jr z,l55cfh		;55c1	28 0c		( .
	cp 002h			;55c3	fe 02		. .
	jr nz,l55dbh		;55c5	20 14		  .
	ld hl,l55eeh		;55c7	21 ee 55	! . U
	call sub_4745h		;55ca	cd 45 47	. E G
	jr l55dbh		;55cd	18 0c		. .
l55cfh:
	ld hl,l55e4h		;55cf	21 e4 55	! . U
	call sub_4745h		;55d2	cd 45 47	. E G
	ld hl,l55e9h		;55d5	21 e9 55	! . U
	call sub_4745h		;55d8	cd 45 47	. E G
l55dbh:
	jp sub_533dh		;55db	c3 3d 53	. = S
l55deh:
	ld c,(hl)		;55de	4e		N
	and d			;55df	a2		.
	ret			;55e0	c9		.
	and h			;55e1	a4		.
	ld (hl),d		;55e2	72		r
	and d			;55e3	a2		.
l55e4h:
	ret nz			;55e4	c0		.
	ret m			;55e5	f8		.
	ld (bc),a		;55e6	02		.
	add a,b			;55e7	80		.
	ld sp,hl		;55e8	f9		.
l55e9h:
	nop			;55e9	00		.
	ld sp,hl		;55ea	f9		.
	ld (bc),a		;55eb	02		.
	ld b,b			;55ec	40		@
	ld sp,hl		;55ed	f9		.
l55eeh:
	ret nz			;55ee	c0		.
	ret m			;55ef	f8		.
	ld (bc),a		;55f0	02		.
	nop			;55f1	00		.
	ld sp,hl		;55f2	f9		.
	call sub_5381h		;55f3	cd 81 53	. . S
	ld de,0a0eah		;55f6	11 ea a0	. . .
	ld hl,0f900h		;55f9	21 00 f9	! . .
	call sub_46f8h		;55fc	cd f8 46	. . F
	call sub_533dh		;55ff	cd 3d 53	. = S
	ld hl,0d600h		;5602	21 00 d6	! . .
	ld bc,00808h		;5605	01 08 08	. . .
l5608h:
	ld de,0c5adh		;5608	11 ad c5	. . .
	ld a,b			;560b	78		x
	cp 005h			;560c	fe 05		. .
	ld a,(de)		;560e	1a		.
	jr nc,l5613h		;560f	30 02		0 .
	add a,010h		;5611	c6 10		. .
l5613h:
	dec a			;5613	3d		=
	ld (hl),a		;5614	77		w
	inc hl			;5615	23		#
	inc de			;5616	13		.
	ld a,(de)		;5617	1a		.
	ld (hl),a		;5618	77		w
	inc hl			;5619	23		#
	ld a,c			;561a	79		y
	and 00bh		;561b	e6 0b		. .
	add a,a			;561d	87		.
	add a,a			;561e	87		.
	ld (hl),a		;561f	77		w
	inc c			;5620	0c		.
	inc hl			;5621	23		#
	inc hl			;5622	23		#
	djnz l5608h		;5623	10 e3		. .
	ld hl,0d400h		;5625	21 00 d4	! . .
	ld c,00ch		;5628	0e 0c		. .
	call sub_5642h		;562a	cd 42 56	. B V
	ld hl,0d410h		;562d	21 10 d4	! . .
	ld c,00dh		;5630	0e 0d		. .
	call sub_5642h		;5632	cd 42 56	. B V
	ld hl,0d420h		;5635	21 20 d4	!   .
	ld c,00eh		;5638	0e 0e		. .
	call sub_5642h		;563a	cd 42 56	. B V
	ld hl,0d430h		;563d	21 30 d4	! 0 .
	ld c,002h		;5640	0e 02		. .
sub_5642h:
	ld d,h			;5642	54		T
	ld e,l			;5643	5d		]
	ld a,040h		;5644	3e 40		> @
	call ADD_DE_A		;5646	cd 66 40	. f @
	ld b,010h		;5649	06 10		. .
l564bh:
	ld a,c			;564b	79		y
	ld (hl),a		;564c	77		w
	ld (de),a		;564d	12		.
	inc hl			;564e	23		#
	inc de			;564f	13		.
	djnz l564bh		;5650	10 f9		. .
	ret			;5652	c9		.
	call sub_53a5h		;5653	cd a5 53	. . S
	ld a,(0d000h)		;5656	3a 00 d0	: . .
	cp 00dh			;5659	fe 0d		. .
	call nc,sub_5393h	;565b	d4 93 53	. . S
	ld a,(0d000h)		;565e	3a 00 d0	: . .
	add a,a			;5661	87		.
	ld hl,l5749h		;5662	21 49 57	! I W
	call ADD_HL_A		;5665	cd 61 40	. a @
	ld e,(hl)		;5668	5e		^
	inc hl			;5669	23		#
	ld d,(hl)		;566a	56		V
	ex de,hl		;566b	eb		.
l566ch:
	ld de,08004h		;566c	11 04 80	. . .
	ld b,0bfh		;566f	06 bf		. .
	call l4a6dh		;5671	cd 6d 4a	. m J
	jp sub_533dh		;5674	c3 3d 53	. = S
	call sub_5381h		;5677	cd 81 53	. . S
	ld hl,08000h		;567a	21 00 80	! . .
	jr l566ch		;567d	18 ed		. .
	call sub_5369h		;567f	cd 69 53	. i S
	ld hl,0f800h		;5682	21 00 f8	! . .
	ld de,0a319h		;5685	11 19 a3	. . .
	call sub_46f8h		;5688	cd f8 46	. . F
	ld hl,0f840h		;568b	21 40 f8	! @ .
	ld de,0a351h		;568e	11 51 a3	. Q .
	call sub_46f8h		;5691	cd f8 46	. . F
	ld hl,0f880h		;5694	21 80 f8	! . .
	ld de,0a38ch		;5697	11 8c a3	. . .
	call sub_46f8h		;569a	cd f8 46	. . F
	ld hl,0f8c0h		;569d	21 c0 f8	! . .
	ld de,0a3cah		;56a0	11 ca a3	. . .
	call sub_46f8h		;56a3	cd f8 46	. . F
	ld hl,0f900h		;56a6	21 00 f9	! . .
	ld de,0a40bh		;56a9	11 0b a4	. . .
	call sub_46f8h		;56ac	cd f8 46	. . F
	ld hl,0f940h		;56af	21 40 f9	! @ .
	ld de,0a447h		;56b2	11 47 a4	. G .
	call sub_46f8h		;56b5	cd f8 46	. . F
	ld hl,0f980h		;56b8	21 80 f9	! . .
	ld de,0a480h		;56bb	11 80 a4	. . .
	call sub_46f8h		;56be	cd f8 46	. . F
	ld hl,0f9c0h		;56c1	21 c0 f9	! . .
	ld de,0a4bch		;56c4	11 bc a4	. . .
	call sub_46f8h		;56c7	cd f8 46	. . F
	ld de,0b895h		;56ca	11 95 b8	. . .
	ld hl,0fa00h		;56cd	21 00 fa	! . .
	call sub_46f8h		;56d0	cd f8 46	. . F
	jp sub_533dh		;56d3	c3 3d 53	. = S
	call sub_5369h		;56d6	cd 69 53	. i S
	ld de,0f880h		;56d9	11 80 f8	. . .
	ld hl,0ac93h		;56dc	21 93 ac	! . .
	ld bc,00180h		;56df	01 80 01	. . .
	call sub_467ch		;56e2	cd 7c 46	. | F
	jp sub_533dh		;56e5	c3 3d 53	. = S
sub_56e8h:
	call sub_5369h		;56e8	cd 69 53	. i S
	ld a,(0c42eh)		;56eb	3a 2e c4	: . .
	add a,a			;56ee	87		.
	ld hl,0a281h		;56ef	21 81 a2	! . .
	call ADD_HL_A		;56f2	cd 61 40	. a @
	ld e,(hl)		;56f5	5e		^
	inc hl			;56f6	23		#
	ld d,(hl)		;56f7	56		V
	ld hl,0f800h		;56f8	21 00 f8	! . .
	call sub_46f8h		;56fb	cd f8 46	. . F
	ld a,(0c42fh)		;56fe	3a 2f c4	: / .
	add a,a			;5701	87		.
	ld hl,0a2d1h		;5702	21 d1 a2	! . .
	call ADD_HL_A		;5705	cd 61 40	. a @
	ld e,(hl)		;5708	5e		^
	inc hl			;5709	23		#
	ld d,(hl)		;570a	56		V
	ld hl,0f840h		;570b	21 40 f8	! @ .
	call sub_46f8h		;570e	cd f8 46	. . F
	jp sub_533dh		;5711	c3 3d 53	. = S
	call sub_572eh		;5714	cd 2e 57	. . W
	call sub_5381h		;5717	cd 81 53	. . S
	ld hl,0bea7h		;571a	21 a7 be	! . .
	ld a,(0d000h)		;571d	3a 00 d0	: . .
	add a,a			;5720	87		.
	call ADD_HL_A		;5721	cd 61 40	. a @
	ld e,(hl)		;5724	5e		^
	inc hl			;5725	23		#
	ld d,(hl)		;5726	56		V
	ex de,hl		;5727	eb		.
	call l4845h		;5728	cd 45 48	. E H
	jp sub_533dh		;572b	c3 3d 53	. = S
sub_572eh:
	call sub_5381h		;572e	cd 81 53	. . S
	ld hl,0bf88h		;5731	21 88 bf	! . .
	call l4845h		;5734	cd 45 48	. E H
	jp sub_533dh		;5737	c3 3d 53	. = S
	call sub_572eh		;573a	cd 2e 57	. . W
	call sub_5381h		;573d	cd 81 53	. . S
	ld hl,0bfa1h		;5740	21 a1 bf	! . .
	call l4845h		;5743	cd 45 48	. E H
	jp sub_533dh		;5746	c3 3d 53	. = S
l5749h:
	nop			;5749	00		.
	ld h,b			;574a	60		`
	jr nz,$+116		;574b	20 72		  r
	jr nz,l57c1h		;574d	20 72		  r
	jr nz,$+116		;574f	20 72		  r
	or e			;5751	b3		.
	sub l			;5752	95		.
	or e			;5753	b3		.
	sub l			;5754	95		.
	or e			;5755	b3		.
	sub l			;5756	95		.
	sub e			;5757	93		.
	add a,h			;5758	84		.
	sub e			;5759	93		.
	add a,h			;575a	84		.
	sub e			;575b	93		.
	add a,h			;575c	84		.
	ld (hl),e		;575d	73		s
	sbc a,(hl)		;575e	9e		.
	ld (hl),e		;575f	73		s
	sbc a,(hl)		;5760	9e		.
	ld (hl),e		;5761	73		s
	sbc a,(hl)		;5762	9e		.
	nop			;5763	00		.
	add a,b			;5764	80		.
	nop			;5765	00		.
	add a,b			;5766	80		.
	nop			;5767	00		.
	add a,b			;5768	80		.
	ld b,b			;5769	40		@
	sub (hl)		;576a	96		.
	ld b,b			;576b	40		@
	sub (hl)		;576c	96		.
	ret nz			;576d	c0		.
	and h			;576e	a4		.
	call sub_5381h		;576f	cd 81 53	. . S
	ld hl,0ff00h		;5772	21 00 ff	! . .
	ld de,0a185h		;5775	11 85 a1	. . .
	call sub_46f8h		;5778	cd f8 46	. . F
	ld de,0a147h		;577b	11 47 a1	. G .
	ld hl,0f9c0h		;577e	21 c0 f9	! . .
	call sub_46f8h		;5781	cd f8 46	. . F
	jp sub_533dh		;5784	c3 3d 53	. = S
	call l4805h		;5787	cd 05 48	. . H
	call sub_5381h		;578a	cd 81 53	. . S
	ld hl,09ab0h		;578d	21 b0 9a	! . .
	ld a,(0d000h)		;5790	3a 00 d0	: . .
	or a			;5793	b7		.
	jr z,l57b8h		;5794	28 22		( "
	dec a			;5796	3d		=
	add a,a			;5797	87		.
	call ADD_HL_A		;5798	cd 61 40	. a @
	ld e,(hl)		;579b	5e		^
	inc hl			;579c	23		#
	ld d,(hl)		;579d	56		V
	ld a,(0d001h)		;579e	3a 01 d0	: . .
	add a,a			;57a1	87		.
	add a,a			;57a2	87		.
	call ADD_DE_A		;57a3	cd 66 40	. f @
	ex de,hl		;57a6	eb		.
	ld a,(hl)		;57a7	7e		~
	inc hl			;57a8	23		#
	push hl			;57a9	e5		.
	ld h,(hl)		;57aa	66		f
	ld l,a			;57ab	6f		o
	call l471bh		;57ac	cd 1b 47	. . G
	pop hl			;57af	e1		.
	inc hl			;57b0	23		#
	ld a,(hl)		;57b1	7e		~
	inc hl			;57b2	23		#
	ld h,(hl)		;57b3	66		f
	ld l,a			;57b4	6f		o
	call l4845h		;57b5	cd 45 48	. E H
l57b8h:
	jp sub_533dh		;57b8	c3 3d 53	. = S
	call sub_5381h		;57bb	cd 81 53	. . S
	ld hl,09fedh		;57be	21 ed 9f	! . .
l57c1h:
	call l471bh		;57c1	cd 1b 47	. . G
	jp sub_533dh		;57c4	c3 3d 53	. = S
	call sub_5381h		;57c7	cd 81 53	. . S
	ld hl,0fa00h		;57ca	21 00 fa	! . .
	ld de,0b0aah		;57cd	11 aa b0	. . .
	call sub_46f8h		;57d0	cd f8 46	. . F
	ld a,(0d000h)		;57d3	3a 00 d0	: . .
	sub 003h		;57d6	d6 03		. .
	ld hl,0a01ah		;57d8	21 1a a0	! . .
	jr z,l57e0h		;57db	28 03		( .
	ld hl,0a021h		;57dd	21 21 a0	! ! .
l57e0h:
	call l4845h		;57e0	cd 45 48	. E H
	jp sub_533dh		;57e3	c3 3d 53	. = S
	call sub_5369h		;57e6	cd 69 53	. i S
	ld hl,0b5a1h		;57e9	21 a1 b5	! . .
	call sub_5834h		;57ec	cd 34 58	. 4 X
	ld de,0c000h		;57ef	11 00 c0	. . .
	call sub_5816h		;57f2	cd 16 58	. . X
	call sub_5858h		;57f5	cd 58 58	. X X
	ld de,0c020h		;57f8	11 20 c0	.   .
	call sub_5816h		;57fb	cd 16 58	. . X
	ld hl,0b719h		;57fe	21 19 b7	! . .
	call sub_5834h		;5801	cd 34 58	. 4 X
	ld de,0c010h		;5804	11 10 c0	. . .
	call sub_5816h		;5807	cd 16 58	. . X
	call sub_5858h		;580a	cd 58 58	. X X
	ld de,0c030h		;580d	11 30 c0	. 0 .
	call sub_5816h		;5810	cd 16 58	. . X
	jp sub_533dh		;5813	c3 3d 53	. = S
sub_5816h:
	ld b,020h		;5816	06 20		.  
	ld hl,0e800h		;5818	21 00 e8	! . .
l581bh:
	push bc			;581b	c5		.
	push de			;581c	d5		.
	push hl			;581d	e5		.
	ld bc,CHRGTR		;581e	01 10 00	. . .
	call sub_467ch		;5821	cd 7c 46	. | F
	pop hl			;5824	e1		.
	pop de			;5825	d1		.
	pop bc			;5826	c1		.
	ld a,010h		;5827	3e 10		> .
	call ADD_HL_A		;5829	cd 61 40	. a @
	ld a,080h		;582c	3e 80		> .
	call ADD_DE_A		;582e	cd 66 40	. f @
	djnz l581bh		;5831	10 e8		. .
	ret			;5833	c9		.
sub_5834h:
	ld b,020h		;5834	06 20		.  
	ld de,0e800h		;5836	11 00 e8	. . .
l5839h:
	push bc			;5839	c5		.
	ld a,(hl)		;583a	7e		~
	and a			;583b	a7		.
	jr z,l5844h		;583c	28 06		( .
	ld b,a			;583e	47		G
	xor a			;583f	af		.
l5840h:
	ld (de),a		;5840	12		.
	inc de			;5841	13		.
	djnz l5840h		;5842	10 fc		. .
l5844h:
	ld a,00ch		;5844	3e 0c		> .
	sub (hl)		;5846	96		.
	inc hl			;5847	23		#
	ld c,a			;5848	4f		O
	ld b,000h		;5849	06 00		. .
	ldir			;584b	ed b0		. .
	xor a			;584d	af		.
	ld b,004h		;584e	06 04		. .
l5850h:
	ld (de),a		;5850	12		.
	inc de			;5851	13		.
	djnz l5850h		;5852	10 fc		. .
	pop bc			;5854	c1		.
	djnz l5839h		;5855	10 e2		. .
	ret			;5857	c9		.
sub_5858h:
	ld hl,0e800h		;5858	21 00 e8	! . .
	ld de,0e80fh		;585b	11 0f e8	. . .
	ld c,020h		;585e	0e 20		.  
l5860h:
	ld b,008h		;5860	06 08		. .
	call sub_5873h		;5862	cd 73 58	. s X
	ld a,008h		;5865	3e 08		> .
	call ADD_HL_A		;5867	cd 61 40	. a @
	ld a,018h		;586a	3e 18		> .
	call ADD_DE_A		;586c	cd 66 40	. f @
	dec c			;586f	0d		.
	jr nz,l5860h		;5870	20 ee		  .
	ret			;5872	c9		.
sub_5873h:
	ex af,af'		;5873	08		.
	ld a,(hl)		;5874	7e		~
	ex af,af'		;5875	08		.
	ld a,(de)		;5876	1a		.
	rrca			;5877	0f		.
	rrca			;5878	0f		.
	rrca			;5879	0f		.
	rrca			;587a	0f		.
	ld (hl),a		;587b	77		w
	ex af,af'		;587c	08		.
	rrca			;587d	0f		.
	rrca			;587e	0f		.
	rrca			;587f	0f		.
	rrca			;5880	0f		.
	ld (de),a		;5881	12		.
	inc hl			;5882	23		#
	dec de			;5883	1b		.
	djnz sub_5873h		;5884	10 ed		. .
	ret			;5886	c9		.
	call sub_5357h		;5887	cd 57 53	. W S
	call sub_589ch		;588a	cd 9c 58	. . X
	call sub_58d3h		;588d	cd d3 58	. . X
	call sub_5931h		;5890	cd 31 59	. 1 Y
	call sub_5992h		;5893	cd 92 59	. . Y
	call sub_599dh		;5896	cd 9d 59	. . Y
	jp sub_533dh		;5899	c3 3d 53	. = S
sub_589ch:
	ld hl,0abf8h		;589c	21 f8 ab	! . .
	ld b,008h		;589f	06 08		. .
	ld de,08018h		;58a1	11 18 80	. . .
	call l4a6dh		;58a4	cd 6d 4a	. m J
	ld hl,0acf8h		;58a7	21 f8 ac	! . .
	ld b,002h		;58aa	06 02		. .
	ld de,08040h		;58ac	11 40 80	. @ .
	call l4a6dh		;58af	cd 6d 4a	. m J
	ld hl,0ad38h		;58b2	21 38 ad	! 8 .
	ld b,002h		;58b5	06 02		. .
	ld de,08060h		;58b7	11 60 80	. ` .
	call l4a6dh		;58ba	cd 6d 4a	. m J
	ld hl,0ad78h		;58bd	21 78 ad	! x .
	ld b,001h		;58c0	06 01		. .
	ld de,08070h		;58c2	11 70 80	. p .
	call l4a6dh		;58c5	cd 6d 4a	. m J
	ld hl,0ad98h		;58c8	21 98 ad	! . .
	ld b,06ch		;58cb	06 6c		. l
	ld de,08078h		;58cd	11 78 80	. x .
	jp l4a6dh		;58d0	c3 6d 4a	. m J
sub_58d3h:
	ld hl,0ad78h		;58d3	21 78 ad	! x .
	ld b,001h		;58d6	06 01		. .
	ld de,08074h		;58d8	11 74 80	. t .
	call sub_58f1h		;58db	cd f1 58	. . X
	ld hl,0ad98h		;58de	21 98 ad	! . .
	ld b,06ch		;58e1	06 6c		. l
	ld de,09028h		;58e3	11 28 90	. ( .
	call sub_58f1h		;58e6	cd f1 58	. . X
	ld hl,0acf8h		;58e9	21 f8 ac	! . .
	ld b,002h		;58ec	06 02		. .
	ld de,08048h		;58ee	11 48 80	. H .
sub_58f1h:
	push bc			;58f1	c5		.
	push de			;58f2	d5		.
	push hl			;58f3	e5		.
	call sub_5904h		;58f4	cd 04 59	. . Y
	pop hl			;58f7	e1		.
	ld de,DCOMPR		;58f8	11 20 00	.   .
	add hl,de		;58fb	19		.
	pop de			;58fc	d1		.
	call sub_5962h		;58fd	cd 62 59	. b Y
	pop bc			;5900	c1		.
	djnz sub_58f1h		;5901	10 ee		. .
	ret			;5903	c9		.
sub_5904h:
	push de			;5904	d5		.
	ld de,0e800h		;5905	11 00 e8	. . .
	ld bc,DCOMPR		;5908	01 20 00	.   .
	ldir			;590b	ed b0		. .
	call sub_5919h		;590d	cd 19 59	. . Y
	pop de			;5910	d1		.
	ld hl,0e800h		;5911	21 00 e8	! . .
	ld b,001h		;5914	06 01		. .
	jp l4a6dh		;5916	c3 6d 4a	. m J
sub_5919h:
	ld hl,0e800h		;5919	21 00 e8	! . .
	ld de,0e803h		;591c	11 03 e8	. . .
	ld c,008h		;591f	0e 08		. .
l5921h:
	ld b,002h		;5921	06 02		. .
	call sub_5873h		;5923	cd 73 58	. s X
	inc hl			;5926	23		#
	inc hl			;5927	23		#
	ld a,006h		;5928	3e 06		> .
	call ADD_DE_A		;592a	cd 66 40	. f @
	dec c			;592d	0d		.
	jr nz,l5921h		;592e	20 f1		  .
	ret			;5930	c9		.
sub_5931h:
	ld hl,08048h		;5931	21 48 80	! H .
	ld b,002h		;5934	06 02		. .
	ld de,08058h		;5936	11 58 80	. X .
	call sub_594fh		;5939	cd 4f 59	. O Y
	ld hl,08040h		;593c	21 40 80	! @ .
	ld b,002h		;593f	06 02		. .
	ld de,08050h		;5941	11 50 80	. P .
	call sub_594fh		;5944	cd 4f 59	. O Y
	ld hl,08060h		;5947	21 60 80	! ` .
	ld b,002h		;594a	06 02		. .
	ld de,08068h		;594c	11 68 80	. h .
sub_594fh:
	push bc			;594f	c5		.
	push de			;5950	d5		.
	push hl			;5951	e5		.
	call sub_5970h		;5952	cd 70 59	. p Y
	pop de			;5955	d1		.
	call sub_5962h		;5956	cd 62 59	. b Y
	ex de,hl		;5959	eb		.
	pop de			;595a	d1		.
	call sub_5962h		;595b	cd 62 59	. b Y
	pop bc			;595e	c1		.
	djnz sub_594fh		;595f	10 ee		. .
	ret			;5961	c9		.
sub_5962h:
	ld a,e			;5962	7b		{
	add a,004h		;5963	c6 04		. .
	and 07fh		;5965	e6 7f		. .
	ld e,a			;5967	5f		_
	ret nz			;5968	c0		.
	ld a,d			;5969	7a		z
	add a,004h		;596a	c6 04		. .
	and 0fch		;596c	e6 fc		. .
	ld d,a			;596e	57		W
	ret			;596f	c9		.
sub_5970h:
	push de			;5970	d5		.
	ld de,0e818h		;5971	11 18 e8	. . .
	ld b,008h		;5974	06 08		. .
l5976h:
	push bc			;5976	c5		.
	ld bc,00004h		;5977	01 04 00	. . .
	call sub_4661h		;597a	cd 61 46	. a F
	ld a,e			;597d	7b		{
	sub 008h		;597e	d6 08		. .
	ld e,a			;5980	5f		_
	ld a,080h		;5981	3e 80		> .
	call ADD_HL_A		;5983	cd 61 40	. a @
	pop bc			;5986	c1		.
	djnz l5976h		;5987	10 ed		. .
	pop de			;5989	d1		.
	ld hl,0e800h		;598a	21 00 e8	! . .
	ld b,001h		;598d	06 01		. .
	jp l4a6dh		;598f	c3 6d 4a	. m J
sub_5992h:
	ld hl,0bbd8h		;5992	21 d8 bb	! . .
	ld de,0d000h		;5995	11 00 d0	. . .
	ld b,008h		;5998	06 08		. .
	jp l4a97h		;599a	c3 97 4a	. . J
sub_599dh:
	ld b,004h		;599d	06 04		. .
	ld hl,0bdd8h		;599f	21 d8 bd	! . .
	ld de,0d040h		;59a2	11 40 d0	. @ .
l59a5h:
	push bc			;59a5	c5		.
	push de			;59a6	d5		.
	push hl			;59a7	e5		.
	call sub_59c3h		;59a8	cd c3 59	. . Y
	pop hl			;59ab	e1		.
	ld de,00080h		;59ac	11 80 00	. . .
	add hl,de		;59af	19		.
	pop de			;59b0	d1		.
	ld a,e			;59b1	7b		{
	add a,008h		;59b2	c6 08		. .
	and 07fh		;59b4	e6 7f		. .
	ld e,a			;59b6	5f		_
	jr nz,l59bfh		;59b7	20 06		  .
	ld a,d			;59b9	7a		z
	add a,008h		;59ba	c6 08		. .
	and 0f8h		;59bc	e6 f8		. .
	ld d,a			;59be	57		W
l59bfh:
	pop bc			;59bf	c1		.
	djnz l59a5h		;59c0	10 e3		. .
	ret			;59c2	c9		.
sub_59c3h:
	push de			;59c3	d5		.
	ld de,0e800h		;59c4	11 00 e8	. . .
	ld bc,00080h		;59c7	01 80 00	. . .
	ldir			;59ca	ed b0		. .
	call sub_59d8h		;59cc	cd d8 59	. . Y
	pop de			;59cf	d1		.
	ld hl,0e800h		;59d0	21 00 e8	! . .
	ld b,001h		;59d3	06 01		. .
	jp l4a97h		;59d5	c3 97 4a	. . J
sub_59d8h:
	ld hl,0e800h		;59d8	21 00 e8	! . .
	ld de,0e807h		;59db	11 07 e8	. . .
	ld c,010h		;59de	0e 10		. .
l59e0h:
	ld b,004h		;59e0	06 04		. .
	call sub_5873h		;59e2	cd 73 58	. s X
	ld a,004h		;59e5	3e 04		> .
	call ADD_HL_A		;59e7	cd 61 40	. a @
	ld a,00ch		;59ea	3e 0c		> .
	call ADD_DE_A		;59ec	cd 66 40	. f @
	dec c			;59ef	0d		.
	jr nz,l59e0h		;59f0	20 ee		  .
	ret			;59f2	c9		.
	call sub_572eh		;59f3	cd 2e 57	. . W
	call sub_5381h		;59f6	cd 81 53	. . S
	ld hl,0bf6fh		;59f9	21 6f bf	! o .
	call l4845h		;59fc	cd 45 48	. E H
	jp sub_533dh		;59ff	c3 3d 53	. = S
sub_5a02h:
	call sub_5393h		;5a02	cd 93 53	. . S
	ld hl,0ac80h		;5a05	21 80 ac	! . .
	ld de,08004h		;5a08	11 04 80	. . .
	ld b,011h		;5a0b	06 11		. .
	call l4a6dh		;5a0d	cd 6d 4a	. m J
	ld a,(0002bh)		;5a10	3a 2b 00	: + .
	and 00fh		;5a13	e6 0f		. .
	jr nz,l5a2ah		;5a15	20 13		  .
	ld hl,0aea0h		;5a17	21 a0 ae	! . .
	ld b,01eh		;5a1a	06 1e		. .
	call l4a6dh		;5a1c	cd 6d 4a	. m J
	call sub_5369h		;5a1f	cd 69 53	. i S
	ld de,0bbf6h		;5a22	11 f6 bb	. . .
	call l46f2h		;5a25	cd f2 46	. . F
	jr l5a32h		;5a28	18 08		. .
l5a2ah:
	ld hl,0b260h		;5a2a	21 60 b2	! ` .
	ld b,059h		;5a2d	06 59		. Y
	call l4a6dh		;5a2f	cd 6d 4a	. m J
l5a32h:
	jp sub_533dh		;5a32	c3 3d 53	. = S
sub_5a35h:
	call sub_5369h		;5a35	cd 69 53	. i S
	call 0b963h		;5a38	cd 63 b9	. c .
	jp sub_533dh		;5a3b	c3 3d 53	. = S
	call sub_5369h		;5a3e	cd 69 53	. i S
	call 0b99ah		;5a41	cd 9a b9	. . .
	jp sub_533dh		;5a44	c3 3d 53	. = S
	call sub_5369h		;5a47	cd 69 53	. i S
	call 0bb31h		;5a4a	cd 31 bb	. 1 .
	jp sub_533dh		;5a4d	c3 3d 53	. = S
	ld hl,0e000h		;5a50	21 00 e0	! . .
	ld de,0e001h		;5a53	11 01 e0	. . .
	ld (hl),000h		;5a56	36 00		6 .
	ld bc,0047fh		;5a58	01 7f 04	. . .
	ldir			;5a5b	ed b0		. .
	call sub_5a63h		;5a5d	cd 63 5a	. c Z
	jp l5ab6h		;5a60	c3 b6 5a	. . Z
sub_5a63h:
	call sub_5357h		;5a63	cd 57 53	. W S
	call sub_5a9fh		;5a66	cd 9f 5a	. . Z
	ld de,0e000h		;5a69	11 00 e0	. . .
l5a6ch:
	push de			;5a6c	d5		.
l5a6dh:
	push de			;5a6d	d5		.
l5a6eh:
	ld a,(hl)		;5a6e	7e		~
	or a			;5a6f	b7		.
	jr z,l5a9ah		;5a70	28 28		( (
	inc a			;5a72	3c		<
	jr z,l5a8eh		;5a73	28 19		( .
	inc a			;5a75	3c		<
	jr z,l5a85h		;5a76	28 0d		( .
	ldi			;5a78	ed a0		. .
	ld a,(hl)		;5a7a	7e		~
	ldi			;5a7b	ed a0		. .
	cp 07fh			;5a7d	fe 7f		. .
	jr nz,l5a83h		;5a7f	20 02		  .
	ldi			;5a81	ed a0		. .
l5a83h:
	jr l5a6eh		;5a83	18 e9		. .
l5a85h:
	pop de			;5a85	d1		.
	ld a,018h		;5a86	3e 18		> .
	call ADD_DE_A		;5a88	cd 66 40	. f @
	inc hl			;5a8b	23		#
	jr l5a6dh		;5a8c	18 df		. .
l5a8eh:
	pop de			;5a8e	d1		.
	pop de			;5a8f	d1		.
	push hl			;5a90	e5		.
	ld hl,00180h		;5a91	21 80 01	! . .
	add hl,de		;5a94	19		.
	ex de,hl		;5a95	eb		.
	pop hl			;5a96	e1		.
	inc hl			;5a97	23		#
	jr l5a6ch		;5a98	18 d2		. .
l5a9ah:
	pop de			;5a9a	d1		.
	pop de			;5a9b	d1		.
	jp sub_533dh		;5a9c	c3 3d 53	. = S
sub_5a9fh:
	ld a,(0d000h)		;5a9f	3a 00 d0	: . .
	or a			;5aa2	b7		.
	ld hl,0800ch		;5aa3	21 0c 80	! . .
	ret z			;5aa6	c8		.
	ld a,(0d002h)		;5aa7	3a 02 d0	: . .
	ld hl,08000h		;5aaa	21 00 80	! . .
	add a,a			;5aad	87		.
	call ADD_HL_A		;5aae	cd 61 40	. a @
	ld e,(hl)		;5ab1	5e		^
	inc hl			;5ab2	23		#
	ld d,(hl)		;5ab3	56		V
	ex de,hl		;5ab4	eb		.
	ret			;5ab5	c9		.
l5ab6h:
	ld hl,0de00h		;5ab6	21 00 de	! . .
	ld de,0de01h		;5ab9	11 01 de	. . .
	ld (hl),000h		;5abc	36 00		6 .
	ld bc,000bfh		;5abe	01 bf 00	. . .
	push hl			;5ac1	e5		.
	ldir			;5ac2	ed b0		. .
	pop de			;5ac4	d1		.
	ld hl,0e000h		;5ac5	21 00 e0	! . .
	ld b,030h		;5ac8	06 30		. 0
l5acah:
	push bc			;5aca	c5		.
	push hl			;5acb	e5		.
	push de			;5acc	d5		.
	call sub_5adeh		;5acd	cd de 5a	. . Z
	pop hl			;5ad0	e1		.
	ld bc,00004h		;5ad1	01 04 00	. . .
	add hl,bc		;5ad4	09		.
	ex de,hl		;5ad5	eb		.
	pop hl			;5ad6	e1		.
	ld c,018h		;5ad7	0e 18		. .
	add hl,bc		;5ad9	09		.
	pop bc			;5ada	c1		.
	djnz l5acah		;5adb	10 ed		. .
	ret			;5add	c9		.
sub_5adeh:
	ld bc,00802h		;5ade	01 02 08	. . .
l5ae1h:
	inc hl			;5ae1	23		#
	ld a,(hl)		;5ae2	7e		~
	and 0e0h		;5ae3	e6 e0		. .
	cp 060h			;5ae5	fe 60		. `
	jr z,l5b07h		;5ae7	28 1e		( .
l5ae9h:
	and 0c0h		;5ae9	e6 c0		. .
	cp 0c0h			;5aeb	fe c0		. .
	jr nz,l5b03h		;5aed	20 14		  .
	ld a,(hl)		;5aef	7e		~
	push bc			;5af0	c5		.
	push hl			;5af1	e5		.
	ld hl,l5b12h		;5af2	21 12 5b	! . [
	and 03ch		;5af5	e6 3c		. <
	rrca			;5af7	0f		.
	rrca			;5af8	0f		.
	call ADD_HL_A		;5af9	cd 61 40	. a @
	ldi			;5afc	ed a0		. .
	inc de			;5afe	13		.
	pop hl			;5aff	e1		.
	pop bc			;5b00	c1		.
	dec c			;5b01	0d		.
	ret z			;5b02	c8		.
l5b03h:
	inc hl			;5b03	23		#
	djnz l5ae1h		;5b04	10 db		. .
	ret			;5b06	c9		.
l5b07h:
	ld a,(hl)		;5b07	7e		~
	and 01fh		;5b08	e6 1f		. .
	cp 01fh			;5b0a	fe 1f		. .
	jr nz,l5b03h		;5b0c	20 f5		  .
	inc hl			;5b0e	23		#
	ld a,(hl)		;5b0f	7e		~
	jr l5ae9h		;5b10	18 d7		. .
l5b12h:
	ld c,012h		;5b12	0e 12		. .
	inc bc			;5b14	03		.
	inc b			;5b15	04		.
	ld a,(bc)		;5b16	0a		.
	ld d,01eh		;5b17	16 1e		. .
	dec e			;5b19	1d		.
	dec de			;5b1a	1b		.
	nop			;5b1b	00		.
	nop			;5b1c	00		.
	nop			;5b1d	00		.
	nop			;5b1e	00		.
	nop			;5b1f	00		.
	nop			;5b20	00		.
	nop			;5b21	00		.
	call sub_5bd6h		;5b22	cd d6 5b	. . [
	ld de,0c470h		;5b25	11 70 c4	. p .
	ld b,008h		;5b28	06 08		. .
l5b2ah:
	ld a,(hl)		;5b2a	7e		~
	inc hl			;5b2b	23		#
	or a			;5b2c	b7		.
	jr z,l5b83h		;5b2d	28 54		( T
	push bc			;5b2f	c5		.
	push hl			;5b30	e5		.
	push de			;5b31	d5		.
	ld a,(hl)		;5b32	7e		~
	and 0e0h		;5b33	e6 e0		. .
	jr z,l5b8fh		;5b35	28 58		( X
	bit 7,(hl)		;5b37	cb 7e		. ~
	jr nz,l5bach		;5b39	20 71		  q
	dec hl			;5b3b	2b		+
	ld a,001h		;5b3c	3e 01		> .
	ld (de),a		;5b3e	12		.
	inc de			;5b3f	13		.
	push hl			;5b40	e5		.
	push bc			;5b41	c5		.
	call sub_5c1dh		;5b42	cd 1d 5c	. . \
	ld a,c			;5b45	79		y
	ld (de),a		;5b46	12		.
	inc de			;5b47	13		.
	ld a,b			;5b48	78		x
	ld (de),a		;5b49	12		.
	inc de			;5b4a	13		.
	pop bc			;5b4b	c1		.
	xor a			;5b4c	af		.
	ld (de),a		;5b4d	12		.
	inc de			;5b4e	13		.
	ld a,(hl)		;5b4f	7e		~
	ld b,a			;5b50	47		G
	rlca			;5b51	07		.
	rlca			;5b52	07		.
	rlca			;5b53	07		.
	and 007h		;5b54	e6 07		. .
	dec a			;5b56	3d		=
	jr nz,l5b61h		;5b57	20 08		  .
	ld a,(0d000h)		;5b59	3a 00 d0	: . .
	or a			;5b5c	b7		.
	jr z,l5b61h		;5b5d	28 02		( .
	ld a,0ffh		;5b5f	3e ff		> .
l5b61h:
	inc a			;5b61	3c		<
	ld (de),a		;5b62	12		.
	inc e			;5b63	1c		.
	ld a,b			;5b64	78		x
	and 01fh		;5b65	e6 1f		. .
	ld (de),a		;5b67	12		.
	inc e			;5b68	1c		.
	ex af,af'		;5b69	08		.
	ld a,l			;5b6a	7d		}
	ld (de),a		;5b6b	12		.
	inc e			;5b6c	1c		.
	pop bc			;5b6d	c1		.
	ld a,b			;5b6e	78		x
	ld (de),a		;5b6f	12		.
	inc e			;5b70	1c		.
	ld a,c			;5b71	79		y
	ld (de),a		;5b72	12		.
	inc e			;5b73	1c		.
	ex af,af'		;5b74	08		.
	cp 01fh			;5b75	fe 1f		. .
	jr nz,l5b7ch		;5b77	20 03		  .
	inc hl			;5b79	23		#
	ldi			;5b7a	ed a0		. .
l5b7ch:
	pop de			;5b7c	d1		.
	ld a,e			;5b7d	7b		{
	add a,010h		;5b7e	c6 10		. .
	ld e,a			;5b80	5f		_
	pop hl			;5b81	e1		.
	pop bc			;5b82	c1		.
l5b83h:
	ld a,(hl)		;5b83	7e		~
	inc hl			;5b84	23		#
	and 01fh		;5b85	e6 1f		. .
	cp 01fh			;5b87	fe 1f		. .
	jr nz,l5b8ch		;5b89	20 01		  .
	inc hl			;5b8b	23		#
l5b8ch:
	djnz l5b2ah		;5b8c	10 9c		. .
	ret			;5b8e	c9		.
l5b8fh:
	ld a,(0cf38h)		;5b8f	3a 38 cf	: 8 .
	and a			;5b92	a7		.
	jr nz,l5b7ch		;5b93	20 e7		  .
	call sub_5b9dh		;5b95	cd 9d 5b	. . [
	call 08a04h		;5b98	cd 04 8a	. . .
	jr l5b7ch		;5b9b	18 df		. .
sub_5b9dh:
	dec l			;5b9d	2d		-
	push hl			;5b9e	e5		.
	push bc			;5b9f	c5		.
	call sub_5c1dh		;5ba0	cd 1d 5c	. . \
	ld d,b			;5ba3	50		P
	ld e,c			;5ba4	59		Y
	pop bc			;5ba5	c1		.
	ld a,(hl)		;5ba6	7e		~
	and 01fh		;5ba7	e6 1f		. .
	ld b,a			;5ba9	47		G
	pop hl			;5baa	e1		.
	ret			;5bab	c9		.
l5bach:
	ld a,(0cf38h)		;5bac	3a 38 cf	: 8 .
	and a			;5baf	a7		.
	jr nz,l5b7ch		;5bb0	20 ca		  .
	bit 6,(hl)		;5bb2	cb 76		. v
	jr nz,l5bbeh		;5bb4	20 08		  .
	call sub_5b9dh		;5bb6	cd 9d 5b	. . [
	call 08a1ah		;5bb9	cd 1a 8a	. . .
	jr l5b7ch		;5bbc	18 be		. .
l5bbeh:
	push hl			;5bbe	e5		.
	pop ix			;5bbf	dd e1		. .
	call sub_5b9dh		;5bc1	cd 9d 5b	. . [
	ld a,(ix+000h)		;5bc4	dd 7e 00	. ~ .
	ld c,a			;5bc7	4f		O
	and 03ch		;5bc8	e6 3c		. <
	rrca			;5bca	0f		.
	rrca			;5bcb	0f		.
	ld b,a			;5bcc	47		G
	ld a,c			;5bcd	79		y
	and 003h		;5bce	e6 03		. .
	ld c,a			;5bd0	4f		O
	call 09180h		;5bd1	cd 80 91	. . .
	jr l5b7ch		;5bd4	18 a6		. .
sub_5bd6h:
	ld a,(0d001h)		;5bd6	3a 01 d0	: . .
	ld (0cffeh),a		;5bd9	32 fe cf	2 . .
	push bc			;5bdc	c5		.
	push de			;5bdd	d5		.
	ld de,CHKRAM		;5bde	11 00 00	. . .
	ld a,(0d000h)		;5be1	3a 00 d0	: . .
	or a			;5be4	b7		.
	jr z,l5bf5h		;5be5	28 0e		( .
	dec a			;5be7	3d		=
	ld hl,l5c0bh		;5be8	21 0b 5c	! . \
	call ADD_HL_A		;5beb	cd 61 40	. a @
	ld l,(hl)		;5bee	6e		n
	ld h,d			;5bef	62		b
	add hl,hl		;5bf0	29		)
	add hl,hl		;5bf1	29		)
	add hl,hl		;5bf2	29		)
	add hl,hl		;5bf3	29		)
	ex de,hl		;5bf4	eb		.
l5bf5h:
	ld hl,0e000h		;5bf5	21 00 e0	! . .
	add hl,de		;5bf8	19		.
	ex de,hl		;5bf9	eb		.
	ld a,(0cffeh)		;5bfa	3a fe cf	: . .
	ld l,a			;5bfd	6f		o
	ld h,000h		;5bfe	26 00		& .
	add hl,hl		;5c00	29		)
	add hl,hl		;5c01	29		)
	add hl,hl		;5c02	29		)
	ld b,h			;5c03	44		D
	ld c,l			;5c04	4d		M
	add hl,hl		;5c05	29		)
	add hl,bc		;5c06	09		.
	add hl,de		;5c07	19		.
	pop de			;5c08	d1		.
	pop bc			;5c09	c1		.
	ret			;5c0a	c9		.
l5c0bh:
	nop			;5c0b	00		.
	jr $+50			;5c0c	18 30		. 0
	nop			;5c0e	00		.
	jr l5c41h		;5c0f	18 30		. 0
	nop			;5c11	00		.
	jr l5c44h		;5c12	18 30		. 0
	nop			;5c14	00		.
	jr $+50			;5c15	18 30		. 0
	nop			;5c17	00		.
	jr $+50			;5c18	18 30		. 0
	nop			;5c1a	00		.
	jr $+50			;5c1b	18 30		. 0
sub_5c1dh:
	ld a,(hl)		;5c1d	7e		~
	ld b,a			;5c1e	47		G
	and 0f0h		;5c1f	e6 f0		. .
	ld c,a			;5c21	4f		O
	ld a,b			;5c22	78		x
	and 00fh		;5c23	e6 0f		. .
	add a,a			;5c25	87		.
	add a,a			;5c26	87		.
	add a,a			;5c27	87		.
	add a,a			;5c28	87		.
	ld b,a			;5c29	47		G
	inc hl			;5c2a	23		#
	ret			;5c2b	c9		.
sub_5c2ch:
	call 06848h		;5c2c	cd 48 68	. H h
	call 06552h		;5c2f	cd 52 65	. R e
	ld a,(0ce40h)		;5c32	3a 40 ce	: @ .
	and a			;5c35	a7		.
	jp nz,066c1h		;5c36	c2 c1 66	. . f
	call 09559h		;5c39	cd 59 95	. Y .
	ld a,(0cf38h)		;5c3c	3a 38 cf	: 8 .
	and a			;5c3f	a7		.
	ret nz			;5c40	c0		.
l5c41h:
	ld a,(0c002h)		;5c41	3a 02 c0	: . .
l5c44h:
	and 040h		;5c44	e6 40		. @
	jr z,l5c63h		;5c46	28 1b		( .
	ld a,(0c00bh)		;5c48	3a 0b c0	: . .
	rra			;5c4b	1f		.
	jr nc,l5c63h		;5c4c	30 15		0 .
	ld a,(0ce00h)		;5c4e	3a 00 ce	: . .
	cp 006h			;5c51	fe 06		. .
	call z,0ad9ah		;5c53	cc 9a ad	. . .
	ld a,001h		;5c56	3e 01		> .
	ld (0c40ah),a		;5c58	32 0a c4	2 . .
	call sub_56e8h		;5c5b	cd e8 56	. . V
	ld a,0fdh		;5c5e	3e fd		> .
	jp sub_50a6h		;5c60	c3 a6 50	. . P
l5c63h:
	call sub_56e8h		;5c63	cd e8 56	. . V
	call 06b06h		;5c66	cd 06 6b	. . k
	call 0783eh		;5c69	cd 3e 78	. > x
	call 0b6b2h		;5c6c	cd b2 b6	. . .
	call 098ech		;5c6f	cd ec 98	. . .
	call 09e38h		;5c72	cd 38 9e	. 8 .
	call 07d6fh		;5c75	cd 6f 7d	. o }
	call 08678h		;5c78	cd 78 86	. x .
	call 091c5h		;5c7b	cd c5 91	. . .
	call 08a51h		;5c7e	cd 51 8a	. Q .
	call 088dfh		;5c81	cd df 88	. . .
	call 08fd6h		;5c84	cd d6 8f	. . .
	call 090a2h		;5c87	cd a2 90	. . .
	call 0914eh		;5c8a	cd 4e 91	. N .
	call 0991fh		;5c8d	cd 1f 99	. . .
	call 09917h		;5c90	cd 17 99	. . .
	call 064f3h		;5c93	cd f3 64	. . d
	jp 064ech		;5c96	c3 ec 64	. . d
sub_5c99h:
	ld bc,00400h		;5c99	01 00 04	. . .
	ld hl,0fcc1h		;5c9c	21 c1 fc	! . .
l5c9fh:
	push bc			;5c9f	c5		.
	push hl			;5ca0	e5		.
	ld a,(hl)		;5ca1	7e		~
	bit 7,a			;5ca2	cb 7f		. .
	jr nz,l5cbah		;5ca4	20 14		  .
	call sub_5cd3h		;5ca6	cd d3 5c	. . \
l5ca9h:
	pop hl			;5ca9	e1		.
	pop bc			;5caa	c1		.
	jr c,l5cb4h		;5cab	38 07		8 .
	inc hl			;5cad	23		#
	inc c			;5cae	0c		.
	djnz l5c9fh		;5caf	10 ee		. .
	xor a			;5cb1	af		.
	jr l5cb6h		;5cb2	18 02		. .
l5cb4h:
	ld a,0ffh		;5cb4	3e ff		> .
l5cb6h:
	ld (0e600h),a		;5cb6	32 00 e6	2 . .
	ret			;5cb9	c9		.
l5cbah:
	call sub_5cbfh		;5cba	cd bf 5c	. . \
	jr l5ca9h		;5cbd	18 ea		. .
sub_5cbfh:
	and 080h		;5cbf	e6 80		. .
	or c			;5cc1	b1		.
	ld c,a			;5cc2	4f		O
	ld b,004h		;5cc3	06 04		. .
l5cc5h:
	push bc			;5cc5	c5		.
	call sub_5cd3h		;5cc6	cd d3 5c	. . \
	pop bc			;5cc9	c1		.
	ret c			;5cca	d8		.
	ld a,c			;5ccb	79		y
	add a,004h		;5ccc	c6 04		. .
	ld c,a			;5cce	4f		O
	djnz l5cc5h		;5ccf	10 f4		. .
	and a			;5cd1	a7		.
	ret			;5cd2	c9		.
sub_5cd3h:
	ld de,l5cf0h		;5cd3	11 f0 5c	. . \
	ld hl,07ffah		;5cd6	21 fa 7f	! . .
	ld b,006h		;5cd9	06 06		. .
l5cdbh:
	push bc			;5cdb	c5		.
l5cdch:
	push de			;5cdc	d5		.
	ld a,c			;5cdd	79		y
	call RDSLT		;5cde	cd 0c 00	. . .
	pop de			;5ce1	d1		.
	pop bc			;5ce2	c1		.
	ex de,hl		;5ce3	eb		.
	cp (hl)			;5ce4	be		.
	ex de,hl		;5ce5	eb		.
	jr nz,l5ceeh		;5ce6	20 06		  .
	inc hl			;5ce8	23		#
	inc de			;5ce9	13		.
	djnz l5cdbh		;5cea	10 ef		. .
	scf			;5cec	37		7
	ret			;5ced	c9		.
l5ceeh:
	and a			;5cee	a7		.
	ret			;5cef	c9		.
l5cf0h:
	nop			;5cf0	00		.
	jr nc,l5d24h		;5cf1	30 31		0 1
	inc de			;5cf3	13		.
	dec (hl)		;5cf4	35		5
	xor d			;5cf5	aa		.
sub_5cf6h:
	call sub_5d04h		;5cf6	cd 04 5d	. . ]
	ld c,00eh		;5cf9	0e 0e		. .
	call sub_48e3h		;5cfb	cd e3 48	. . H
	ld hl,l5d1dh		;5cfe	21 1d 5d	! . ]
	jp l4ad2h		;5d01	c3 d2 4a	. . J
sub_5d04h:
	ld hl,02098h		;5d04	21 98 20	! .  
	ld bc,0c038h		;5d07	01 38 c0	. 8 .
sub_5d0ah:
	xor a			;5d0a	af		.
	ld d,000h		;5d0b	16 00		. .
	push bc			;5d0d	c5		.
	push hl			;5d0e	e5		.
	call l4911h		;5d0f	cd 11 49	. . I
	pop hl			;5d12	e1		.
	pop de			;5d13	d1		.
	ret			;5d14	c9		.
sub_5d15h:
	call sub_5d0ah		;5d15	cd 0a 5d	. . ]
	ld c,00eh		;5d18	0e 0e		. .
	jp sub_48e3h		;5d1a	c3 e3 48	. . H
l5d1dh:
	ld e,b			;5d1d	58		X
	and b			;5d1e	a0		.
	jr nc,$+50		;5d1f	30 30		0 0
	jr nc,l5d60h		;5d21	30 3d		0 =
	dec (hl)		;5d23	35		5
l5d24h:
	ld a,045h		;5d24	3e 45		> E
	jr nc,$+50		;5d26	30 30		0 0
l5d28h:
	jr nc,l5d28h		;5d28	30 fe		0 .
	jr z,l5cdch		;5d2a	28 b0		( .
	ld c,a			;5d2c	4f		O
	cp 030h			;5d2d	fe 30		. 0
	or b			;5d2f	b0		.
	ld b,e			;5d30	43		C
	ld b,h			;5d31	44		D
	ld sp,l4442h		;5d32	31 42 44	1 B D
	nop			;5d35	00		.
	scf			;5d36	37		7
	ld sp,0353dh		;5d37	31 3d 35	1 = 5
	cp 030h			;5d3a	fe 30		. 0
	cp b			;5d3c	b8		.
	dec a			;5d3d	3d		=
	ccf			;5d3e	3f		?
	inc (hl)		;5d3f	34		4
	add hl,sp		;5d40	39		9
	ld (hl),049h		;5d41	36 49		6 I
	nop			;5d43	00		.
	ld b,e			;5d44	43		C
	ld b,h			;5d45	44		D
	ld sp,03537h		;5d46	31 37 35	1 7 5
	nop			;5d49	00		.
	ld a,045h		;5d4a	3e 45		> E
	dec a			;5d4c	3d		=
	ld (04235h),a		;5d4d	32 35 42	2 5 B
	cp 030h			;5d50	fe 30		. 0
	ret nz			;5d52	c0		.
	dec a			;5d53	3d		=
	ccf			;5d54	3f		?
	inc (hl)		;5d55	34		4
	add hl,sp		;5d56	39		9
	ld (hl),049h		;5d57	36 49		6 I
	nop			;5d59	00		.
	ld b,b			;5d5a	40		@
	inc a			;5d5b	3c		<
	ld sp,03549h		;5d5c	31 49 35	1 I 5
	ld b,d			;5d5f	42		B
l5d60h:
	nop			;5d60	00		.
	ld a,045h		;5d61	3e 45		> E
	dec a			;5d63	3d		=
	ld (04235h),a		;5d64	32 35 42	2 5 B
	rst 38h			;5d67	ff		.
sub_5d68h:
	ld hl,l5d79h		;5d68	21 79 5d	! y ]
	call sub_5d97h		;5d6b	cd 97 5d	. . ]
	ld hl,0e605h		;5d6e	21 05 e6	! . .
	ld de,0b0b8h		;5d71	11 b8 b0	. . .
l5d74h:
	ld b,001h		;5d74	06 01		. .
	jp l457fh		;5d76	c3 7f 45	. . E
l5d79h:
	ld c,b			;5d79	48		H
	cp b			;5d7a	b8		.
	ld b,e			;5d7b	43		C
	ld b,h			;5d7c	44		D
	ld sp,03537h		;5d7d	31 37 35	1 7 5
	nop			;5d80	00		.
	ld a,045h		;5d81	3e 45		> E
	dec a			;5d83	3d		=
	ld (04235h),a		;5d84	32 35 42	2 5 B
	cpl			;5d87	2f		/
	rst 38h			;5d88	ff		.
sub_5d89h:
	ld hl,l5d9fh		;5d89	21 9f 5d	! . ]
	call sub_5d97h		;5d8c	cd 97 5d	. . ]
	ld hl,0e607h		;5d8f	21 07 e6	! . .
	ld de,0b8b8h		;5d92	11 b8 b8	. . .
	jr l5d74h		;5d95	18 dd		. .
sub_5d97h:
	push hl			;5d97	e5		.
	call sub_5db0h		;5d98	cd b0 5d	. . ]
	pop hl			;5d9b	e1		.
	jp l4ad2h		;5d9c	c3 d2 4a	. . J
l5d9fh:
	ld c,b			;5d9f	48		H
	cp b			;5da0	b8		.
	ld b,b			;5da1	40		@
	inc a			;5da2	3c		<
	ld sp,03549h		;5da3	31 49 35	1 I 5
	ld b,d			;5da6	42		B
	nop			;5da7	00		.
	ld a,045h		;5da8	3e 45		> E
	dec a			;5daa	3d		=
	ld (04235h),a		;5dab	32 35 42	2 5 B
	cpl			;5dae	2f		/
	rst 38h			;5daf	ff		.
sub_5db0h:
	ld hl,024b0h		;5db0	21 b0 24	! . $
	ld bc,0b818h		;5db3	01 18 b8	. . .
	jp sub_5d0ah		;5db6	c3 0a 5d	. . ]
l5db9h:
	call sub_5deeh		;5db9	cd ee 5d	. . ]
	ret z			;5dbc	c8		.
	ld hl,(0e608h)		;5dbd	2a 08 e6	* . .
	ld d,000h		;5dc0	16 00		. .
	ld b,008h		;5dc2	06 08		. .
	ld a,l			;5dc4	7d		}
	call sub_5de8h		;5dc5	cd e8 5d	. . ]
	jr c,l5dd1h		;5dc8	38 07		8 .
	ld a,h			;5dca	7c		|
	ld b,002h		;5dcb	06 02		. .
	call sub_5de8h		;5dcd	cd e8 5d	. . ]
	ret nc			;5dd0	d0		.
l5dd1h:
	ld hl,0e615h		;5dd1	21 15 e6	! . .
	ld (hl),0ffh		;5dd4	36 ff		6 .
	ld hl,0e60fh		;5dd6	21 0f e6	! . .
	ld a,d			;5dd9	7a		z
	rld			;5dda	ed 6f		. o
	ld de,(0e602h)		;5ddc	ed 5b 02 e6	. [ . .
	ld b,001h		;5de0	06 01		. .
	call l457fh		;5de2	cd 7f 45	. . E
	jp l5e0fh		;5de5	c3 0f 5e	. . ^
sub_5de8h:
	rra			;5de8	1f		.
	ret c			;5de9	d8		.
	inc d			;5dea	14		.
	djnz sub_5de8h		;5deb	10 fb		. .
	ret			;5ded	c9		.
sub_5deeh:
	xor a			;5dee	af		.
	call SNSMAT		;5def	cd 41 01	. A .
	cpl			;5df2	2f		/
	ld d,a			;5df3	57		W
	ld a,001h		;5df4	3e 01		> .
	call SNSMAT		;5df6	cd 41 01	. A .
	cpl			;5df9	2f		/
	and 003h		;5dfa	e6 03		. .
	ld e,a			;5dfc	5f		_
	ld a,d			;5dfd	7a		z
	ld hl,0e608h		;5dfe	21 08 e6	! . .
	ld c,(hl)		;5e01	4e		N
	ld (hl),a		;5e02	77		w
	xor c			;5e03	a9		.
	and (hl)		;5e04	a6		.
	ld d,a			;5e05	57		W
	ld a,e			;5e06	7b		{
	inc hl			;5e07	23		#
	ld c,(hl)		;5e08	4e		N
	ld (hl),a		;5e09	77		w
	xor c			;5e0a	a9		.
	and (hl)		;5e0b	a6		.
	ld e,a			;5e0c	5f		_
	or d			;5e0d	b2		.
	ret			;5e0e	c9		.
l5e0fh:
	ld hl,0e60fh		;5e0f	21 0f e6	! . .
	ld a,(hl)		;5e12	7e		~
	ld c,a			;5e13	4f		O
	rrca			;5e14	0f		.
	rrca			;5e15	0f		.
	rrca			;5e16	0f		.
	rrca			;5e17	0f		.
	and 00fh		;5e18	e6 0f		. .
	add a,a			;5e1a	87		.
	ld b,a			;5e1b	47		G
	add a,a			;5e1c	87		.
	add a,a			;5e1d	87		.
	add a,b			;5e1e	80		.
	ld b,a			;5e1f	47		G
	ld a,c			;5e20	79		y
	and 00fh		;5e21	e6 0f		. .
	add a,b			;5e23	80		.
	ld (0e60eh),a		;5e24	32 0e e6	2 . .
	ret			;5e27	c9		.
sub_5e28h:
	ld a,007h		;5e28	3e 07		> .
	call SNSMAT		;5e2a	cd 41 01	. A .
	cpl			;5e2d	2f		/
	and 080h		;5e2e	e6 80		. .
	ld hl,0e60ah		;5e30	21 0a e6	! . .
	ld c,(hl)		;5e33	4e		N
	ld (hl),a		;5e34	77		w
	xor c			;5e35	a9		.
	and (hl)		;5e36	a6		.
	ret			;5e37	c9		.
sub_5e38h:
	rra			;5e38	1f		.
	push af			;5e39	f5		.
	jr nc,l5e67h		;5e3a	30 2b		0 +
	ld a,(0e606h)		;5e3c	3a 06 e6	: . .
	cp 013h			;5e3f	fe 13		. .
	jr c,l5e44h		;5e41	38 01		8 .
	xor a			;5e43	af		.
l5e44h:
	ld (0d000h),a		;5e44	32 00 d0	2 . .
	ld a,(0e605h)		;5e47	3a 05 e6	: . .
	cp 019h			;5e4a	fe 19		. .
	jr c,l5e4fh		;5e4c	38 01		8 .
	xor a			;5e4e	af		.
l5e4fh:
	ld (0c411h),a		;5e4f	32 11 c4	2 . .
	ld hl,l5e71h		;5e52	21 71 5e	! q ^
	ld a,(0d000h)		;5e55	3a 00 d0	: . .
	call ADD_HL_A		;5e58	cd 61 40	. a @
	ld a,(hl)		;5e5b	7e		~
	ld (0d002h),a		;5e5c	32 02 d0	2 . .
	xor a			;5e5f	af		.
	ld (0d001h),a		;5e60	32 01 d0	2 . .
	inc a			;5e63	3c		<
	ld (0c40dh),a		;5e64	32 0d c4	2 . .
l5e67h:
	pop af			;5e67	f1		.
	rra			;5e68	1f		.
	ret nc			;5e69	d0		.
	ld a,(0e607h)		;5e6a	3a 07 e6	: . .
	ld (0c410h),a		;5e6d	32 10 c4	2 . .
	ret			;5e70	c9		.
l5e71h:
	nop			;5e71	00		.
	nop			;5e72	00		.
	nop			;5e73	00		.
	nop			;5e74	00		.
	ld bc,00101h		;5e75	01 01 01	. . .
	ld (bc),a		;5e78	02		.
	ld (bc),a		;5e79	02		.
	ld (bc),a		;5e7a	02		.
	inc bc			;5e7b	03		.
	inc bc			;5e7c	03		.
	inc bc			;5e7d	03		.
	inc b			;5e7e	04		.
	inc b			;5e7f	04		.
	inc b			;5e80	04		.
	dec b			;5e81	05		.
	dec b			;5e82	05		.
	dec b			;5e83	05		.
l5e84h:
	rra			;5e84	1f		.
	ld a,001h		;5e85	3e 01		> .
	jr nc,l5e8bh		;5e87	30 02		0 .
	ld a,0ffh		;5e89	3e ff		> .
l5e8bh:
	ld b,a			;5e8b	47		G
	ld hl,0e60bh		;5e8c	21 0b e6	! . .
	add a,(hl)		;5e8f	86		.
	and 003h		;5e90	e6 03		. .
	cp 003h			;5e92	fe 03		. .
	jr nz,l5e9dh		;5e94	20 07		  .
	ld a,b			;5e96	78		x
	add a,a			;5e97	87		.
	ld a,002h		;5e98	3e 02		> .
	jr c,l5e9dh		;5e9a	38 01		8 .
	xor a			;5e9c	af		.
l5e9dh:
	push af			;5e9d	f5		.
	push hl			;5e9e	e5		.
	ld a,(hl)		;5e9f	7e		~
	call sub_5ea9h		;5ea0	cd a9 5e	. . ^
	pop hl			;5ea3	e1		.
	pop af			;5ea4	f1		.
	ld (hl),a		;5ea5	77		w
	jp l5eadh		;5ea6	c3 ad 5e	. . ^
sub_5ea9h:
	ld b,000h		;5ea9	06 00		. .
	jr l5eafh		;5eab	18 02		. .
l5eadh:
	ld b,04fh		;5ead	06 4f		. O
l5eafh:
	ld hl,l5ebch		;5eaf	21 bc 5e	! . ^
	call ADD_HL_A		;5eb2	cd 61 40	. a @
	ld e,(hl)		;5eb5	5e		^
	ld d,028h		;5eb6	16 28		. (
	ld a,b			;5eb8	78		x
	jp sub_4aeeh		;5eb9	c3 ee 4a	. . J
l5ebch:
	or b			;5ebc	b0		.
	cp b			;5ebd	b8		.
	ret nz			;5ebe	c0		.
	ld a,(0c440h)		;5ebf	3a 40 c4	: @ .
	and a			;5ec2	a7		.
	ret nz			;5ec3	c0		.
	ld a,(0c420h)		;5ec4	3a 20 c4	:   .
	cp 006h			;5ec7	fe 06		. .
	ret z			;5ec9	c8		.
	ld a,(0c5ach)		;5eca	3a ac c5	: . .
	sub 002h		;5ecd	d6 02		. .
	ret z			;5ecf	c8		.
	dec a			;5ed0	3d		=
	ret z			;5ed1	c8		.
	cp 002h			;5ed2	fe 02		. .
	ret z			;5ed4	c8		.
	di			;5ed5	f3		.
	ld a,00eh		;5ed6	3e 0e		> .
	ld (08000h),a		;5ed8	32 00 80	2 . .
	ld (0f0f2h),a		;5edb	32 f2 f0	2 . .
	ei			;5ede	fb		.
	ld a,(0d000h)		;5edf	3a 00 d0	: . .
	ld de,085a6h		;5ee2	11 a6 85	. . .
	call 06549h		;5ee5	cd 49 65	. I e
	ld a,(0d001h)		;5ee8	3a 01 d0	: . .
	call ADD_DE_A		;5eeb	cd 66 40	. f @
	ld a,(de)		;5eee	1a		.
	push af			;5eef	f5		.
	di			;5ef0	f3		.
	ld a,002h		;5ef1	3e 02		> .
	ld (08000h),a		;5ef3	32 00 80	2 . .
	ld (0f0f2h),a		;5ef6	32 f2 f0	2 . .
	ei			;5ef9	fb		.
	pop af			;5efa	f1		.
	rra			;5efb	1f		.
	push af			;5efc	f5		.
	call c,09cedh		;5efd	dc ed 9c	. . .
	pop af			;5f00	f1		.
	rra			;5f01	1f		.
	push af			;5f02	f5		.
	call c,09d52h		;5f03	dc 52 9d	. R .
	pop af			;5f06	f1		.
	rra			;5f07	1f		.
	push af			;5f08	f5		.
	call c,09d59h		;5f09	dc 59 9d	. Y .
	pop af			;5f0c	f1		.
	rra			;5f0d	1f		.
	push af			;5f0e	f5		.
	call c,09d9eh		;5f0f	dc 9e 9d	. . .
	pop af			;5f12	f1		.
	rra			;5f13	1f		.
	push af			;5f14	f5		.
	call c,09dcah		;5f15	dc ca 9d	. . .
	pop af			;5f18	f1		.
	rra			;5f19	1f		.
	push af			;5f1a	f5		.
	call c,09ddch		;5f1b	dc dc 9d	. . .
	pop af			;5f1e	f1		.
	rra			;5f1f	1f		.
	jp c,09deeh		;5f20	da ee 9d	. . .
	ret			;5f23	c9		.
l5f24h:
	xor a			;5f24	af		.
	ld b,a			;5f25	47		G
	ld (0cffah),a		;5f26	32 fa cf	2 . .
	ld a,b			;5f29	78		x
	ld (0cffbh),a		;5f2a	32 fb cf	2 . .
	xor a			;5f2d	af		.
	ld (0cf31h),a		;5f2e	32 31 cf	2 1 .
	ld a,c			;5f31	79		y
	ld (0cff0h),a		;5f32	32 f0 cf	2 . .
	ld (0cff1h),de		;5f35	ed 53 f1 cf	. S . .
	ld hl,0c800h		;5f39	21 00 c8	! . .
	ld b,007h		;5f3c	06 07		. .
	xor a			;5f3e	af		.
	ld de,00080h		;5f3f	11 80 00	. . .
l5f42h:
	cp (hl)			;5f42	be		.
	jr z,l5f49h		;5f43	28 04		( .
	add hl,de		;5f45	19		.
	djnz l5f42h		;5f46	10 fa		. .
	ret			;5f48	c9		.
l5f49h:
	push hl			;5f49	e5		.
	pop ix			;5f4a	dd e1		. .
	ld (0cff3h),hl		;5f4c	22 f3 cf	" . .
	ld a,(0cff0h)		;5f4f	3a f0 cf	: . .
	ld hl,0605eh		;5f52	21 5e 60	! ^ `
	call ADD_HL_A		;5f55	cd 61 40	. a @
	ld a,(hl)		;5f58	7e		~
	ld (ix+020h),a		;5f59	dd 77 20	. w  
	ld c,a			;5f5c	4f		O
	and a			;5f5d	a7		.
	jr z,l5f7eh		;5f5e	28 1e		( .
	ld de,CHKRAM		;5f60	11 00 00	. . .
	ld hl,0d638h		;5f63	21 38 d6	! 8 .
	ld b,00eh		;5f66	06 0e		. .
l5f68h:
	ld a,(hl)		;5f68	7e		~
	cp 0e0h			;5f69	fe e0		. .
	jr nz,l5f76h		;5f6b	20 09		  .
	ld (hl),0e1h		;5f6d	36 e1		6 .
	call 0604fh		;5f6f	cd 4f 60	. O `
	inc e			;5f72	1c		.
	dec c			;5f73	0d		.
	jr z,l5f7eh		;5f74	28 08		( .
l5f76h:
	inc d			;5f76	14		.
	inc l			;5f77	2c		,
	inc l			;5f78	2c		,
	inc l			;5f79	2c		,
	inc l			;5f7a	2c		,
	djnz l5f68h		;5f7b	10 eb		. .
	ret			;5f7d	c9		.
l5f7eh:
	ld a,001h		;5f7e	3e 01		> .
	ld (0cf31h),a		;5f80	32 31 cf	2 1 .
	ld hl,(0cff3h)		;5f83	2a f3 cf	* . .
	ld a,(0cff0h)		;5f86	3a f0 cf	: . .
	ld (hl),a		;5f89	77		w
	inc l			;5f8a	2c		,
	ld (hl),000h		;5f8b	36 00		6 .
	ld de,(0cff1h)		;5f8d	ed 5b f1 cf	. [ . .
	inc l			;5f91	2c		,
	ld (hl),000h		;5f92	36 00		6 .
	inc l			;5f94	2c		,
	ld (hl),e		;5f95	73		s
	inc l			;5f96	2c		,
	ld (hl),000h		;5f97	36 00		6 .
	inc l			;5f99	2c		,
	ld (hl),d		;5f9a	72		r
	inc l			;5f9b	2c		,
	ld (hl),000h		;5f9c	36 00		6 .
	ld a,(0cffah)		;5f9e	3a fa cf	: . .
	ld (ix+00fh),a		;5fa1	dd 77 0f	. w .
	ld a,(0cffbh)		;5fa4	3a fb cf	: . .
	ld (ix+01fh),a		;5fa7	dd 77 1f	. w .
	ld (ix+07eh),001h	;5faa	dd 36 7e 01	. 6 ~ .
	ld (ix+07fh),001h	;5fae	dd 36 7f 01	. 6 . .
	ld (ix+00eh),007h	;5fb2	dd 36 0e 07	. 6 . .
	ld de,0608bh		;5fb6	11 8b 60	. . `
	call 06030h		;5fb9	cd 30 60	. 0 `
	ld a,(0cff0h)		;5fbc	3a f0 cf	: . .
	ld de,060e8h		;5fbf	11 e8 60	. . `
	call ADD_DE_A		;5fc2	cd 66 40	. f @
	ld a,(de)		;5fc5	1a		.
	ld (ix+00dh),a		;5fc6	dd 77 0d	. w .
	ld hl,(0cff3h)		;5fc9	2a f3 cf	* . .
	ld a,(ix+000h)		;5fcc	dd 7e 00	; A = entity type (ix+0)...
	dec a			;5fcf	3d		; ...-1 -> 0-based index
	call DISPATCH_A		;5fd0	cd 6b 40	; jump to entity_tbl[type-1]

; entity_tbl - per-object behaviour handlers, indexed by entity type-1.
; Targets are all in 0xA000-0xBFFF, i.e. code in whichever segment is currently
; paged into page 2b - so these are addresses in banked ROM, not local labels.
; (22 entries; the trailing 0x5FFF byte is padding to the segment boundary.)
entity_tbl:
	defw 0a93bh		;5fd3	3b a9		; entity type 1
	defw 0a2e7h		;5fd5	e7 a2		. .
	defw 0a2e7h		;5fd7	e7 a2		. .
	defw 0b0d1h		;5fd9	d1 b0		. .
	defw 0a863h		;5fdb	63 a8		c .
	defw 0a57ah		;5fdd	7a a5		z .
	defw 0b068h		;5fdf	68 b0		h .
	defw 0a502h		;5fe1	02 a5		. .
	defw 0af51h		;5fe3	51 af		Q .
	defw 0a229h		;5fe5	29 a2		) .
	defw 0b34bh		;5fe7	4b b3		K .
	defw 0a677h		;5fe9	77 a6		w .
	defw 0b219h		;5feb	19 b2		. .
	defw 0aad4h		;5fed	d4 aa		. .
	defw 0b19ah		;5fef	9a b1		. .
	defw 0ade5h		;5ff1	e5 ad		. .
	defw 0ab29h		;5ff3	29 ab		) .
	defw 0be57h		;5ff5	57 be		W .
	defw 0bd2dh		;5ff7	2d bd		- .
	defw 0b883h		;5ff9	83 b8		. .
	defw 0ba56h		;5ffb	56 ba		V .
	defw 0bc5bh		;5ffd	5b bc		[ .
	defb 047h		;5fff	47		G
entity_tbl_end:

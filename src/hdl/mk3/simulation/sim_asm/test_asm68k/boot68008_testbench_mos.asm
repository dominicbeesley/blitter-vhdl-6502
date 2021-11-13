STACK		:=	$1000
screen_ptr	:=	$1000

		;section "code"
		org $8D0000


runfrom_sys:	nop
		nop
		nop
		nop
		nop
		rts
runfrom_sys_end:

handle_res:	
		; copy vectors to low page

		trap	#0

		move.l	#$5A6996A5, D0
		move.l	#$A496695A, D1

		; quick load store test to chipram
		lea.l	$2000, A0
		move.l	D0,(A0)
		move.l  (A0),D2


		; quick byte store test
		move.b	D0, 0
		move.b	D1, 1
		move.b	0, D1
		move.b	1, D0

		moveq 	#(v_end-v_start)/4, D1
		lea.l	0, A0
		lea.l	v_start(PC),A1
.lp0:		move.l	(A1)+,(A0)+
		dbf	D1,.lp0	

		; reset boot
		move.b	#$D1,$FFFFFCFF

		trap	#0

		; test 1m cycles
;		move.b	#1,D0
;		move.b	D0,$FFE00
;		move.b	D0,$FFE00
;		move.b	D0,$FFE00
;		move.b	D0,$FFE00
;
;		; test 2m cycles
;		add.b	#1,$FF2000
;		add.b	#1,$FF2000
;		add.b	#1,$FF2000
;		add.b	#1,$FF2000
;		add.b	#1,$FF2000
;		add.b	#1,$FF2000
;
;		moveq	#runfrom_sys_end-runfrom_sys-1,D1
;		lea.l	$FFFF2000,A0
;		lea.l	runfrom_sys(PC),A1
;.;lp		move.b	(A1)+,(A0)+
;		dbf	D1,.lp
;
;		jsr	$FFFF2000

		jsr	cls
		lea.l	(test_d,PC),A0
		jsr	PrString
here:		jmp	here(PC)


cls:		movea.l	(screen_start),A0
		move.l A0,(screen_ptr)
		move.w	(screen_len),D0
;;		clr.b	D1
		move.b	#$A5, D1
.lp:		move.b	D1,(A0)+
		dbf	D0,.lp
		rts

PrString:	move.b	(A0)+,D0
		beq	.ex
		jsr	OSWRCH
		bra	PrString
.ex:		rts

OSWRCH:		movem.l	D1/A0-A1,-(A7)
		clr.w	D1
		move.b	D0,D1
		sub.b	#32,D1
		bcs	.ex
		rol.w	#3,D1
		movea.l	(screen_ptr),A1
		lea	font(PC),A0
		lea.l	0(A0,D1.W),A0
		move.l	(A0)+,D1
		move.l	D1,(A1)+
		move.l	(A0)+,D1
		move.l	D1,(A1)+
		move.l	A1,(screen_ptr)
.ex:		movem.l	(A7)+,D1/A0-A1
		rts



screen_start:	dc.l	$FFFF5800			; assume mode 4
screen_len:	dc.w	$2800				; mode 4 screen size
screen_ptr_org:	dc.l	$FFFF5800+8*320			; somewhere in mode 4

message:	

test_d:		dc.b	"Blitter Board 68008", 0

handle_trap0:	rte


font:		incbin	font.bin


;		section "romvectors"
		org	$8D3F00
v_start:
v_stack:	dc.l	STACK
v_reset:	dc.l	handle_res

		org	$8D3F80
v_trap0:	dc.l	handle_trap0
v_end:

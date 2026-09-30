
		.setcpu "6502X"

		.include "p20k.inc"

		.ZEROPAGE
zp_CTR:		.RES 1
		
		.CODE

test_str:	.byte	$10, $20, $30, $40, $AA, $FF, 0

test_prog:	ldx	#1
@lp:		txa
		eor 	#$AA
		sta	$1000,X
		inx
		cpx	#10
		bne	@lp
		rts
test_prog_len = * - test_prog

mos_handle_res:

	sei
	cld
	ldx	#$FF	
	txs
	
	inx
	stx	zp_CTR

	lda	#0
	sta 	$FE36
	sta	$FE37

	lda	#$D1
	sta	$FCFF
	lda	#$60
	sta	$FCFD
	sta	$FCFE

	jsr	memtest

	lda	#$10
	sta	$FCFD
	sta	$FCFE

	jsr	memtest

	lda	#$D1
	sta	$FCFF
	lda	#$60
	sta	$FCFD
	sta	$FCFE

	jsr	runtest

	lda	#$10
	sta	$FCFD
	sta	$FCFE

	jsr	runtest


	; turn on / off throttle
@lp:	ldx	zp_CTR
	txa
	ror	A
	ror	A
	and	#$80
	sta	$FE36

	txa
	ror	A
	and	#$01
	sta	$FE37


	inc	$10
	dec	$10

	txa
	sta	sheila_SYSVIA_orb
	lsr
	ora	#7
	sta	sheila_SYSVIA_orb

	lda	#$64
	sta	$FE10

	lda	#3
	sta	$FE08

	lda	$FE40	; wait

	lda	#$E5
	sta	$FE08

	lda	$FE40	; wait

	lda	#'A'
	sta	$FE09	

	ldx	zp_CTR
	inx
	stx	zp_CTR
	jmp 	@lp

memtest:
	ldx	#0
@lp1:	lda	test_str, X
	beq	@sk1
	sta	JIM, X
	inx
	jmp	@lp1
@sk1:	ldx	#0
@lp2:	lda	test_str, X
	beq	@sk2
	eor	JIM, X
	inx
	jmp	@lp2
@sk2:	rts


runtest:	ldx	#test_prog_len
@lp:	lda	test_prog-1,X
	sta	JIM-1,X
	dex
	bne	@lp

	jsr	JIM
	rts


mos_handle_nmi:
	rti

mos_handle_irq:
	rti


		.SEGMENT "VECTORS"
hanmi:  .addr   mos_handle_nmi                  
hares:  .addr   mos_handle_res                  
hairq:  .addr   mos_handle_irq                  

		.END

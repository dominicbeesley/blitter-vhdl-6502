; (c) Dossytronics 2023
; test harness ROM for VHDL testbench for efinix-test on xyloni board

		.setcpu "6502X"

		.include "p20k.inc"

		.ZEROPAGE
ZP_PTR:		.RES 2
CTR:		.RES 4
		.CODE

start:


	; TODO - init BSS

@lp:	inc	CTR
	bne	@s1
	inc	CTR+1
	bne	@s1
	inc	CTR+2
	bne	@s1
	inc	CTR+3
	
@s1:	lda	CTR+3
	jsr	PrintHexA
	lda	CTR+2
	jsr	PrintHexA
	lda	CTR+1
	jsr	PrintHexA
	lda	CTR+0
	jsr	PrintHexA

	lda	#<str_msg
	sta	ZP_PTR
	lda	#>str_msg
	sta	ZP_PTR+1
	ldy	#0
@lp2:	lda	(ZP_PTR),Y
	beq	@sk1
	jsr	uart_tx
	iny
	bne	@lp2
@sk1:


	ldx	#0
	ldy	#0
@lp3:	jsr	wait
	dex
	bne	@lp3
	dey
	bne	@lp3
	beq	@lp

wait:	jsr	wait2
wait2:	
	bit	UART_STAT
	bmi	shch
	rts

shch:	pha
	lda	UART_DAT
	jsr	PrintHexA
	pla
	rts

uart_tx:	bit	UART_STAT
	bvs	uart_tx
	sta	UART_DAT
	rts


PrintHexA:	pha
		lsr	a
		lsr	a
		lsr	a
		lsr	a
		jsr	PrintHexNybA
		pla
		pha
		jsr	PrintHexNybA
		pla
		rts
PrintHexNybA:	and	#$0F
		cmp	#10
		bcc	@1
		adc	#'A'-'9'-2
@1:		adc	#'0'
		jsr	uart_tx
		rts


		.rodata

str_msg:	.byte "Hello Ishbel", 13, 10, 0

		.END

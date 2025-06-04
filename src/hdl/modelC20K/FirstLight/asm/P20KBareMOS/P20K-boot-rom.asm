; (c) Dossytronics 2023
; test harness ROM for VHDL testbench for efinix-test on xyloni board

		.setcpu "6502X"

		.include "p20k.inc"

                .import noice_init
                .import noice_nmi
                .import noice_brk
                .import noice_enter


		.ZEROPAGE
ZP_PTR:		.RES 2
CTR:		.RES 4
		.CODE

mos_handle_res:

	sei
	cld
	ldx	#$FF	
	txs


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

	; TODO - init BSS

	jsr	noice_init

	jsr	noice_enter

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


mos_handle_nmi:
		jmp	noice_nmi

mos_handle_irq:
		; check for BRK
		pha
		txa
		pha

		; stack
		;	+5	caller PCH
		;	+4	caller PCL
		;	+3	caller P
		;	+2	caller A
		;	+1	caller X

		tsx	
		lda	$103,X
		and	#$10
		bne	mos_handle_brk

		
		;;;;; interrupt handler, can use A,X

		pla
		tax
		pla
		rti

mos_handle_brk:	pla
		tax
		pla
		jmp	noice_brk





str_msg:	.byte "Hello Ishbel", 13, 10, 0

		.SEGMENT "VECTORS"
hanmi:  .addr   mos_handle_nmi                  ; FFFA 00 0D                    ..
hares:  .addr   mos_handle_res                  ; FFFC CD D9                    ..
hairq:  .addr   mos_handle_irq                  ; FFFE 1C DC                    ..

		.END

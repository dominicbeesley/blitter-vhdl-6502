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

	jmp	noice_enter


uart_tx:	
	bit	UART_STAT
	bvs	uart_tx
	sta	UART_DAT
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





str_msg:	.byte "NoIce Monitor MOS", 13, 10, 0

		.SEGMENT "VECTORS"
hanmi:  .addr   mos_handle_nmi                  
hares:  .addr   mos_handle_res                  
hairq:  .addr   mos_handle_irq                  

		.END

; (c) Dossytronics 2023
; test harness ROM for VHDL testbench for efinix-test on xyloni board

		.setcpu "6502X"


UART_BASE = $FE00
UART_STAT = UART_BASE + 0
UART_DAT  = UART_BASE + 1

UART_STAT_RXF = $80
UART_STAT_TXF = $40


		.ZEROPAGE
ZP_PTR:		.RES 2

		.CODE

mos_handle_res:

	sei
	cld
	ldx	#$FA			; start stack just below vectors
	txs

@lp:
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
@sk1:	ldx	#0
	ldy	#0
@lp3:	dex
	bne	@lp3
	dey
	bne	@lp3
	beq	@lp


uart_tx:	bit	UART_STAT
	bvs	uart_tx
	sta	UART_DAT
	rts




mos_handle_nmi:
mos_handle_irq:
		rti

str_msg:	.byte "Hello Ishbel", 0

		.SEGMENT "VECTORS"
hanmi:  .addr   mos_handle_nmi                  ; FFFA 00 0D                    ..
hares:  .addr   mos_handle_res                  ; FFFC CD D9                    ..
hairq:  .addr   mos_handle_irq                  ; FFFE 1C DC                    ..

		.END

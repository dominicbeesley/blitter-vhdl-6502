; (c) Dossytronics 2025

		.setcpu "6502X"

		.include "p20k.inc"

; scan keyboard and output pressed keys to uart - no interrupts codes >= $10

T1_TICKS := (1000000 / 100) - 2

		.macro WAIT
		lda	$FE00
		.endmacro

		.ZEROPAGE

		.DATA
zp_ctr:		.res	1

		.CODE
start:		
		lda	#$7F
		sta	sheila_SYSVIA_ddra	; all out except PA7
		WAIT

		lda	#$0F
		sta	sheila_SYSVIA_ddrb	; slow latch is out
		WAIT

		lda	#$03
		sta	sheila_SYSVIA_orb
		WAIT

		cli

loop:		ldx	#$10
@l2:		stx	sheila_SYSVIA_ora_nh
		WAIT
		lda	sheila_SYSVIA_ora_nh
		bpl	@sk
		jsr	PrintHex
		lda	#' '
		jsr	uart_tx
@sk:		inx
		bpl	@l2
		
		lda	#'.'
		jsr	uart_tx
		lda	#13
		jsr	uart_tx
		lda	#10
		jsr	uart_tx

		lda	#10
		sta	zp_ctr	
		ldx	#0
		ldy	#0
@wl:		dey
		bne	@wl
		dex
		bne	@wl
		dec	zp_ctr
		bne	@wl

		jmp	loop

PrintHex:
		pha                        
		lsr 	A
		lsr	A
		lsr 	A
		lsr	A
		jsr 	PrIntHexNyb
		pla
		and 	#$0F
PrIntHexNyb:
		sed
		clc
		adc	#$90
		adc	#$40
		cld
uart_tx:	bit	UART_STAT
		bvs	uart_tx
		sta	UART_DAT
		rts




		.END

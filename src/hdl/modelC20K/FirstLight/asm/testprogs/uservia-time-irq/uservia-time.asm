; (c) Dossytronics 2023
; test harness ROM for VHDL testbench for efinix-test on xyloni board

		.setcpu "6502X"

		.include "p20k.inc"

; set user via to run at 100 ticks per second and poll interrupt flag

T1_TICKS := (1000000 / 100) - 2

		.ZEROPAGE
zp_ctr100:	.res	1
zp_seconds:	.res	4

		.DATA
old_IRQV:	.res	2

		.CODE
start:		
		lda	#0
		sta	zp_seconds
		sta	zp_seconds + 1
		sta	zp_seconds + 2
		sta	zp_seconds + 3

		; intercept interrupts
		lda	IRQV
		sta	old_IRQV
		lda	IRQV + 1
		sta	old_IRQV + 1

		lda	#<handle_irq
		sta	IRQV
		lda	#>handle_irq
		sta	IRQV+1
		

		; clear interrupt enables and flags
		lda	#$7F
		sta	sheila_USRVIA_ier
		sta	sheila_USRVIA_ifr


		lda	#VIA_ACR_T1_CONT
		sta	sheila_USRVIA_acr		

		lda	#<T1_TICKS
		sta	sheila_USRVIA_t1ll
		lda	#>T1_TICKS
		sta	sheila_USRVIA_t1lh
		sta	sheila_USRVIA_t1ch


		; enable T1 interrupt
		lda	#VIA_IFR_BIT_ANY|VIA_IFR_BIT_T1
		sta	sheila_USRVIA_ier
		
		lda	#100
		sta	zp_ctr100

		cli

loop:		
		

		lda	zp_seconds+3
		jsr	PrintHex
		lda	zp_seconds+2
		jsr	PrintHex
		lda	zp_seconds+1
		jsr	PrintHex
		lda	zp_seconds+0
		jsr	PrintHex

		lda	#13
		jsr	uart_tx
		lda	#10
		jsr	uart_tx

		jmp	loop

		
handle_irq:
		lda	sheila_USRVIA_ifr
		bpl	@notirq
		and	#VIA_IFR_BIT_T1
		beq	@notirq
		sta	sheila_USRVIA_ifr	; clear flag

		dec	zp_ctr100
		bne	@sk1

		lda	#100
		sta	zp_ctr100
		inc	zp_seconds+0
		bne	@sk1
		inc	zp_seconds+1
		bne	@sk1
		inc	zp_seconds+2
		bne	@sk1
		inc	zp_seconds+3
@sk1:
@notirq:	rts

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

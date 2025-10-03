
		.include "c20k816.inc"
		.include "deice.inc"

                .import deice_init
                .import deice_enter_emu
                .import deice_enter_nat

		.export deice_GETCHAR
		.export deice_PUTCHAR
		.export deice_nat2emu_rti


		.ZEROPAGE
ZP_PTR:		.RES 2
CTR:		.RES 4
		
		.CODE

mos_handle_res_emu:
		.a8
		.i8 

		; enter here in emulation mode but

		sep	#$30		;; unnecessary but safe?
		sei			;; unnecessary but safe?
		cld			;; unnecessary but safe?
		ldx	#$FF		;; 8 bit stack a $1FF
		txs

		; setup default vectors
		ldx	#end_default_vectors - default_vectors - 1
@vl:		lda	default_vectors,X
		sta	USERV,X
		dex
		bpl	@vl


		lda	#<str_msg
		sta	ZP_PTR
		lda	#>str_msg
		sta	ZP_PTR+1
		ldy	#0
@lp2:		lda	(ZP_PTR),Y
		beq	@sk1
		jsr	uart_tx
		iny
		bne	@lp2
@sk1:

		; TODO - init BSS

		jsr	deice_init

deice_restart:
		pea	deice_restart
		php
		pha	
		lda	#DEICE_STATE_RESET
		; enter native mode!
		clc
		xce
		; enter monitor
		jmp	deice_enter_emu

		;; this must remain in bank 0
deice_nat2emu_rti:
		sec
		xce
		rti



uart_tx:	
		php
		rep	#$10		; big X
		sep	#$20		; small x
		pha
		.i16
		.a8	
@lp:		lda	f:UART_STAT
		and	#$40
		bne	@lp
		pla
		sta	f:UART_DAT
		plp
		rts

deice_PUTCHAR := uart_tx


;
;===========================================================================
; Get a character to A
;
; Return A=char, CY=0 if data received
;        CY=1 if timeout (0.5 seconds)
;
; Uses 5 bytes of stack including return address
;
deice_GETCHAR:	php
		rep	#$10		; big X
		sep	#$20		; small A
		.i16
		.a8
		phx
		ldx	#0		
@l1:		lda	f:UART_STAT
		bpl	@sk1
		beq	@sk1
		lda	f:UART_DAT
		plx
		plp
		clc
		rts
@sk1:		dex
		bne	@l1
		plx
		plp
		sec
		rts

mos_handle_cop_nat:
		jmp	mos_handle_cop_nat
mos_handle_brk_nat:
		jmp	mos_handle_brk_nat
mos_handle_abt_nat:
		.a16
		.i16
		rep	#$30
		pha
		lda	#DEICE_STATE_ABORT
		jml	deice_enter_nat
		.a8
		.i8
mos_handle_irq_nat:
		jmp	mos_handle_irq_nat
mos_handle_nmi_nat:
		jmp	mos_handle_nmi_nat



mos_handle_cop_emu:
		jmp	mos_handle_cop_emu
mos_handle_abt_emu:
		pha
		lda	#DEICE_STATE_ABORT
		clc
		xce				; switch to native mode
		jml	deice_enter_emu

mos_handle_nmi_emu:
		jmp	mos_handle_nmi_emu

mos_handle_irq_emu:
		.a8
		.i8
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
		jsr	call_irqv

		pla
		tax
		pla
		rti

call_irqv:	jmp	(IRQV)

default_irqv:	jmp	default_irqv
default_brkv:	jmp	default_brkv

mos_handle_brk:	pla
		tax
		pla
		jmp	(BRKV)

		.RODATA
default_vectors:
		.addr	default_irqv
		.addr	default_brkv
		.addr	default_irqv
		.addr	default_brkv
end_default_vectors:

str_msg:	.byte "DeIce Monitor MOS for C20K / 65816 with mini-mos", 13, 10, 0

		.SEGMENT "VECTORS"
		; natural mode vectors
		.res	2		
		.res	2
		.addr	mos_handle_cop_nat
		.addr	mos_handle_brk_nat
		.addr	mos_handle_abt_nat
		.addr	mos_handle_nmi_nat
		.res	2
		.addr	mos_handle_irq_nat

		.res	2		
		.res	2
		.addr	mos_handle_cop_emu
		.res	2
		.addr	mos_handle_abt_emu
	  	.addr   mos_handle_nmi_emu                  
	  	.addr   mos_handle_res_emu                  
	  	.addr   mos_handle_irq_emu                  

		.END

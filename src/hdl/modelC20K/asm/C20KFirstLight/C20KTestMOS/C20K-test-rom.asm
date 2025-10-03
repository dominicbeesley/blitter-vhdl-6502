; (c) Dossytronics 2023
; test harness ROM for VHDL testbench for efinix-test on xyloni board

		.setcpu "6502X"

		.include "p20k.inc"

		.ZEROPAGE
ZP_PTR:		.RES 2
CTR:		.RES 4
		
		.CODE

mos_handle_res:

	sei
	cld
	ldx	#$FF	
	txs

	lda	#DEVNO_C20K
	sta	fred_JIM_DEVNO
	lda	#$12
	sta	fred_JIM_PAGE_HI
	lda	#$34
	sta	fred_JIM_PAGE_LO

again:
	stx	JIM
	lda	JIM
	inx
	jmp	again

mos_handle_nmi:
		rti

mos_handle_irq:
		rti

		.SEGMENT "VECTORS"
hanmi:  .addr   mos_handle_nmi                  
hares:  .addr   mos_handle_res                  
hairq:  .addr   mos_handle_irq                  

		.END

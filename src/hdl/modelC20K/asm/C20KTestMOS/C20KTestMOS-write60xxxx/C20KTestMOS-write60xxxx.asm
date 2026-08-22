
		.setcpu "6502X"

		.include "p20k.inc"

		.ZEROPAGE
zp_CTR:		.RES 1
		
		.CODE

mos_handle_res:

	sei
	cld
	ldx	#$FF	
	txs
	
	inx
	stx	zp_CTR


	lda	#$D1
	sta	fred_JIM_DEVNO
	lda	#$FC
	sta	fred_JIM_PAGE_HI
	lda	#$40
	sta	fred_JIM_PAGE_LO
	sta	JIM+$10

	lda	#$55
	pha
	lda	#$AA
	pla
	pha
	pla
	jsr	t1


	


here:	jmp	here

t1:	pla
	pha
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

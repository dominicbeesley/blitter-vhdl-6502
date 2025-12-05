
		.setcpu "65816"

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


	lda	#DEVNO_C20K
	sta	fred_JIM_DEVNO
	lda	#$60
	sta	fred_JIM_PAGE_HI
	lda	#$55
	sta	JIM

	ldx	#20
@lp:	txa
	sta	$2000,X
	dex
	bne	@lp


	lda	#$0
	sta	f:A16_CS_DMA_SEL

	lda	#$FF
	sta	f:A16_CS_DMA_SRC_ADDR + 2
	lda	#$20
	sta	f:A16_CS_DMA_SRC_ADDR + 1
	lda	#$00
	sta	f:A16_CS_DMA_SRC_ADDR + 0

	lda	#$02
	sta	f:A16_CS_DMA_DEST_ADDR + 2
	lda	#$02
	sta	f:A16_CS_DMA_DEST_ADDR + 1
	lda	#$03
	sta	f:A16_CS_DMA_DEST_ADDR + 0

	lda	#$00
	sta	f:A16_CS_DMA_COUNT + 1
	lda	#$11
	sta	f:A16_CS_DMA_COUNT + 0

	lda	#DMACTL_ACT|DMACTL_HALT|DMACTL_STEP_DEST_UP|DMACTL_STEP_SRC_UP
	sta	f:A16_CS_DMA_CTL

	ldx	#10
	inx
	inx
	inx
	inx
	inx
	inx
	inx
	inx
	inx
	inx
	inx
	inx
	inx
	inx
	stx	$0000




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

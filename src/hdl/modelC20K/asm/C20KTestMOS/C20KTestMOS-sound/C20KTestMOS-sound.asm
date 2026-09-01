
		.setcpu "65816"

		.include "p20k.inc"

		.ZEROPAGE
zp_CTR:		.RES 1
		

SOUND_BUF_ADDR:=	$050000

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
	lda	#^SOUND_BUF_ADDR
	sta	fred_JIM_PAGE_HI
	lda	#>SOUND_BUF_ADDR
	sta	fred_JIM_PAGE_LO

	ldx	#20
@lp:	txa
	sta	JIM,X
	dex
	bne	@lp


	lda	#$0
	sta	f:A16_CS_SND_SEL

	lda	#^SOUND_BUF_ADDR
	sta	f:A16_CS_SND_ADDR + 2
	lda	#>SOUND_BUF_ADDR
	sta	f:A16_CS_SND_ADDR + 1
	lda	#$0
	sta	f:A16_CS_SND_ADDR + 0

	lda	#$0
	sta	f:A16_CS_SND_LEN + 1
	lda	#$20
	sta	f:A16_CS_SND_LEN + 0

	lda	#$0
	sta	f:A16_CS_SND_REPOFF + 1
	lda	#$0
	sta	f:A16_CS_SND_REPOFF + 0

	lda	#$0
	sta	f:A16_CS_SND_PERIOD + 1
	lda	#$10
	sta	f:A16_CS_SND_PERIOD + 0

	lda	#$81
	sta	f:A16_CS_SND_STATUS

there:	ldx	#10
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

	jmp	there

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

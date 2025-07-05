
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

	; turn on / off throttle
@lp:	ldx	zp_CTR
	txa
	ror	A
	ror	A
	and	#$80
	sta	$FE36

	txa
	sta	sheila_SYSVIA_orb
	lsr
	ora	#7
	sta	sheila_SYSVIA_orb

	ldx	zp_CTR
	inx
	stx	zp_CTR
@wl:	dex
	bne	@wl

	jmp	@lp



mos_handle_nmi:
	rti

mos_handle_irq:
	rti


		.SEGMENT "VECTORS"
hanmi:  .addr   mos_handle_nmi                  
hares:  .addr   mos_handle_res                  
hairq:  .addr   mos_handle_irq                  

		.END

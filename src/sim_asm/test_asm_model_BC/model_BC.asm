; (c) Dossytronics 2023
; test bench ROM for MODEL_BC hybrid BBC_B/Blitter with HDMI output

		.setcpu "6502X"

		.include	"common.inc"
		.include	"hw.inc"

vec_nmi		:=	$D00

		.ZEROPAGE
ZP_PTR:		.RES 2

		.CODE
mostbl_chardefs:
	.byte	$00,$00,$00,$00,$00,$00,$00,$00
	.byte	$18,$18,$18,$18,$18,$00,$18,$00
	.byte	$6C,$6C,$6C,$00,$00,$00,$00,$00
	.byte	$36,$36,$7F,$36,$7F,$36,$36,$00
	.byte	$0C,$3F,$68,$3E,$0B,$7E,$18,$00
	.byte	$60,$66,$0C,$18,$30,$66,$06,$00
	.byte	$38,$6C,$6C,$38,$6D,$66,$3B,$00
	.byte	$0C,$18,$30,$00,$00,$00,$00,$00
	.byte	$0C,$18,$30,$30,$30,$18,$0C,$00
	.byte	$30,$18,$0C,$0C,$0C,$18,$30,$00
	.byte	$00,$18,$7E,$3C,$7E,$18,$00,$00
	.byte	$00,$18,$18,$7E,$18,$18,$00,$00
	.byte	$00,$00,$00,$00,$00,$18,$18,$30
	.byte	$00,$00,$00,$7E,$00,$00,$00,$00
	.byte	$00,$00,$00,$00,$00,$18,$18,$00
	.byte	$00,$06,$0C,$18,$30,$60,$00,$00
	.byte	$3C,$66,$6E,$7E,$76,$66,$3C,$00
	.byte	$18,$38,$18,$18,$18,$18,$7E,$00
	.byte	$3C,$66,$06,$0C,$18,$30,$7E,$00
	.byte	$3C,$66,$06,$1C,$06,$66,$3C,$00
	.byte	$0C,$1C,$3C,$6C,$7E,$0C,$0C,$00
	.byte	$7E,$60,$7C,$06,$06,$66,$3C,$00
	.byte	$1C,$30,$60,$7C,$66,$66,$3C,$00
	.byte	$7E,$06,$0C,$18,$30,$30,$30,$00
	.byte	$3C,$66,$66,$3C,$66,$66,$3C,$00
	.byte	$3C,$66,$66,$3E,$06,$0C,$38,$00
	.byte	$00,$00,$18,$18,$00,$18,$18,$00
	.byte	$00,$00,$18,$18,$00,$18,$18,$30
	.byte	$0C,$18,$30,$60,$30,$18,$0C,$00
	.byte	$00,$00,$7E,$00,$7E,$00,$00,$00
	.byte	$30,$18,$0C,$06,$0C,$18,$30,$00
	.byte	$3C,$66,$0C,$18,$18,$00,$18,$00
	.byte	$3C,$66,$6E,$6A,$6E,$60,$3C,$00
	.byte	$3C,$66,$66,$7E,$66,$66,$66,$00
	.byte	$7C,$66,$66,$7C,$66,$66,$7C,$00
	.byte	$3C,$66,$60,$60,$60,$66,$3C,$00
	.byte	$78,$6C,$66,$66,$66,$6C,$78,$00
	.byte	$7E,$60,$60,$7C,$60,$60,$7E,$00
	.byte	$7E,$60,$60,$7C,$60,$60,$60,$00
	.byte	$3C,$66,$60,$6E,$66,$66,$3C,$00
	.byte	$66,$66,$66,$7E,$66,$66,$66,$00
	.byte	$7E,$18,$18,$18,$18,$18,$7E,$00
	.byte	$3E,$0C,$0C,$0C,$0C,$6C,$38,$00
	.byte	$66,$6C,$78,$70,$78,$6C,$66,$00
	.byte	$60,$60,$60,$60,$60,$60,$7E,$00
	.byte	$63,$77,$7F,$6B,$6B,$63,$63,$00
	.byte	$66,$66,$76,$7E,$6E,$66,$66,$00
	.byte	$3C,$66,$66,$66,$66,$66,$3C,$00
	.byte	$7C,$66,$66,$7C,$60,$60,$60,$00
	.byte	$3C,$66,$66,$66,$6A,$6C,$36,$00
	.byte	$7C,$66,$66,$7C,$6C,$66,$66,$00
	.byte	$3C,$66,$60,$3C,$06,$66,$3C,$00
	.byte	$7E,$18,$18,$18,$18,$18,$18,$00
	.byte	$66,$66,$66,$66,$66,$66,$3C,$00
	.byte	$66,$66,$66,$66,$66,$3C,$18,$00
	.byte	$63,$63,$6B,$6B,$7F,$77,$63,$00
	.byte	$66,$66,$3C,$18,$3C,$66,$66,$00
	.byte	$66,$66,$66,$3C,$18,$18,$18,$00
	.byte	$7E,$06,$0C,$18,$30,$60,$7E,$00
	.byte	$7C,$60,$60,$60,$60,$60,$7C,$00
	.byte	$00,$60,$30,$18,$0C,$06,$00,$00
	.byte	$3E,$06,$06,$06,$06,$06,$3E,$00
	.byte	$18,$3C,$66,$42,$00,$00,$00,$00
	.byte	$00,$00,$00,$00,$00,$00,$00,$FF
	.byte	$1C,$36,$30,$7C,$30,$30,$7E,$00
	.byte	$00,$00,$3C,$06,$3E,$66,$3E,$00
	.byte	$60,$60,$7C,$66,$66,$66,$7C,$00
	.byte	$00,$00,$3C,$66,$60,$66,$3C,$00
	.byte	$06,$06,$3E,$66,$66,$66,$3E,$00
	.byte	$00,$00,$3C,$66,$7E,$60,$3C,$00
	.byte	$1C,$30,$30,$7C,$30,$30,$30,$00
	.byte	$00,$00,$3E,$66,$66,$3E,$06,$3C
	.byte	$60,$60,$7C,$66,$66,$66,$66,$00
	.byte	$18,$00,$38,$18,$18,$18,$3C,$00
	.byte	$18,$00,$38,$18,$18,$18,$18,$70
	.byte	$60,$60,$66,$6C,$78,$6C,$66,$00
	.byte	$38,$18,$18,$18,$18,$18,$3C,$00
	.byte	$00,$00,$36,$7F,$6B,$6B,$63,$00
	.byte	$00,$00,$7C,$66,$66,$66,$66,$00
	.byte	$00,$00,$3C,$66,$66,$66,$3C,$00
	.byte	$00,$00,$7C,$66,$66,$7C,$60,$60
	.byte	$00,$00,$3E,$66,$66,$3E,$06,$07
	.byte	$00,$00,$6C,$76,$60,$60,$60,$00
	.byte	$00,$00,$3E,$60,$3C,$06,$7C,$00
	.byte	$30,$30,$7C,$30,$30,$30,$1C,$00
	.byte	$00,$00,$66,$66,$66,$66,$3E,$00
	.byte	$00,$00,$66,$66,$66,$3C,$18,$00
	.byte	$00,$00,$63,$6B,$6B,$7F,$36,$00
	.byte	$00,$00,$66,$3C,$18,$3C,$66,$00
	.byte	$00,$00,$66,$66,$66,$3E,$06,$3C
	.byte	$00,$00,$7E,$0C,$18,$30,$7E,$00
	.byte	$0C,$18,$18,$70,$18,$18,$0C,$00
	.byte	$18,$18,$18,$00,$18,$18,$18,$00
	.byte	$30,$18,$18,$0E,$18,$18,$30,$00
	.byte	$31,$6B,$46,$00,$00,$00,$00,$00
	.byte	$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

_ULA_SETTINGS:		.byte	$9c				; 10011100
			.byte	$d8				; 11011000
			.byte	$f4				; 11110100
			.byte	$9c				; 10011100
			.byte	$88				; 10001000
			.byte	$c4				; 11000100
			.byte	$88				; 10001000
			.byte	$4b				; 01001011

;************* 6845 REGISTERS 0-11 FOR SCREEN TYPE 0 - MODES 0-2 *********

_CRTC_REG_TAB:		.byte	$7f				; 0 Horizontal Total	 =128
			.byte	$50				; 1 Horizontal Displayed =80
			.byte	$62				; 2 Horizontal Sync	 =&62
			.byte	$28				; 3 HSync Width+VSync	 =&28  VSync=2, HSync Width=8
			.byte	$26				; 4 Vertical Total	 =38
			.byte	$00				; 5 Vertial Adjust	 =0
			.byte	$20				; 6 Vertical Displayed	 =32
			.byte	$22				; 7 VSync Position	 =&22
			.byte	$01				; 8 Interlace+Cursor	 =&01  Cursor=0, Display=0, Interlace=Sync
			.byte	$07				; 9 Scan Lines/Character =8
			.byte	$67				; 10 Cursor Start Line	  =&67	Blink=On, Speed=1/32, Line=7
			.byte	$08				; 11 Cursor End Line	  =8


;************* 6845 REGISTERS 0-11 FOR SCREEN TYPE 1 - MODE 3 ************

			.byte	$7f				; 0 Horizontal Total	 =128
			.byte	$50				; 1 Horizontal Displayed =80
			.byte	$62				; 2 Horizontal Sync	 =&62
			.byte	$28				; 3 HSync Width+VSync	 =&28  VSync=2, HSync=8
			.byte	$1e				; 4 Vertical Total	 =30
			.byte	$02				; 5 Vertical Adjust	 =2
			.byte	$19				; 6 Vertical Displayed	 =25
			.byte	$1b				; 7 VSync Position	 =&1B
			.byte	$01				; 8 Interlace+Cursor	 =&01  Cursor=0, Display=0, Interlace=Sync
			.byte	$09				; 9 Scan Lines/Character =10
			.byte	$67				; 10 Cursor Start Line	  =&67	Blink=On, Speed=1/32, Line=7
			.byte	$09				; 11 Cursor End Line	  =9


;************ 6845 REGISTERS 0-11 FOR SCREEN TYPE 2 - MODES 4-5 **********

			.byte	$3f				; 0 Horizontal Total	 =64
			.byte	$28				; 1 Horizontal Displayed =40
			.byte	$31				; 2 Horizontal Sync	 =&31
			.byte	$24				; 3 HSync Width+VSync	 =&24  VSync=2, HSync=4
			.byte	$26				; 4 Vertical Total	 =38
			.byte	$00				; 5 Vertical Adjust	 =0
			.byte	$20				; 6 Vertical Displayed	 =32
			.byte	$22				; 7 VSync Position	 =&22
			.byte	$01				; 8 Interlace+Cursor	 =&01  Cursor=0, Display=0, Interlace=Sync
			.byte	$07				; 9 Scan Lines/Character =8
			.byte	$67				; 10 Cursor Start Line	  =&67	Blink=On, Speed=1/32, Line=7
			.byte	$08				; 11 Cursor End Line	  =8


;********** 6845 REGISTERS 0-11 FOR SCREEN TYPE 3 - MODE 6 ***************

			.byte	$3f				; 0 Horizontal Total	 =64
			.byte	$28				; 1 Horizontal Displayed =40
			.byte	$31				; 2 Horizontal Sync	 =&31
			.byte	$24				; 3 HSync Width+VSync	 =&24  VSync=2, HSync=4
			.byte	$1e				; 4 Vertical Total	 =30
			.byte	$02				; 5 Vertical Adjust	 =0
			.byte	$19				; 6 Vertical Displayed	 =25
			.byte	$1b				; 7 VSync Position	 =&1B
			.byte	$01				; 8 Interlace+Cursor	 =&01  Cursor=0, Display=0, Interlace=Sync
			.byte	$09				; 9 Scan Lines/Character =10
			.byte	$67				; 10 Cursor Start Line	  =&67	Blink=On, Speed=1/32, Line=7
			.byte	$09				; 11 Cursor End Line	  =9


;********* 6845 REGISTERS 0-11 FOR SCREEN TYPE 4 - MODE 7 ****************

			.byte	$3f				; 0 Horizontal Total	 =64
			.byte	$28				; 1 Horizontal Displayed =40
			.byte	$33				; 2 Horizontal Sync	 =&33  Note: &31 is a better value
			.byte	$24				; 3 HSync Width+VSync	 =&24  VSync=2, HSync=4
			.byte	$1e				; 4 Vertical Total	 =30
			.byte	$02				; 5 Vertical Adjust	 =2
			.byte	$19				; 6 Vertical Displayed	 =25
			.byte	$1b				; 7 VSync Position	 =&1B
			.byte	$93				; 8 Interlace+Cursor	 =&93  Cursor=2, Display=1, Interlace=Sync+Video
			.byte	$12				; 9 Scan Lines/Character =19
			.byte	$72				; 10 Cursor Start Line	  =&72	Blink=On, Speed=1/32, Line=18
			.byte	$13				; 11 Cursor End Line	  =19

mos_handle_res:
	sei
	cld

	lda	#$40
	sta	vec_nmi

	; set up sys via
	
	ldx	#$0F
	stx	sheila_SYSVIA_ddrb	; set low nibble as latch control, high as printer/joystick inputs

	inx
	; reset all latches
@lat_res:
	dex
	stx	sheila_SYSVIA_orb
	cpx	#9
	bcs	@lat_res

	
	; TODO: scan keyboard links ?
	ldx	#0
	stx	sheila_SYSVIA_ddra	; slow bus/keyboard all inputs

	; TEST #0
	ldx	sheila_SYSVIA_ddra
	txa
	eor	#$FF
	sta	sheila_SYSVIA_ddra
	lda	sheila_SYSVIA_ddra
	stx	sheila_SYSVIA_ddra

	; TEST #1 
	; For the Model B/C the vhdl needs to intercept the IER 
	; CA1 interrupt disabled on motherboard and enabled
	; on "shadow" sysvia

	; clear IER
	ldx	#$7F
	stx	sheila_SYSVIA_ier

	; enable interrupts for T1, T2, CB1 (EOC), CA1 (Vysnc)
	ldx	#$F2
	stx	sheila_SYSVIA_ier

	; END TEST #1

	; TEST #2 PCR - not sure what should happen here
	ldx	#$04			; CB2=in neg edge, CB1=neg edge, CA2=in pos edge, CA1=neg edge
	stx	sheila_SYSVIA_pcr

	; END TEST #2

	; TEST #3 ACR - not sure what should happen here

	ldx	#$60			; T1 cont, T2 countdown, pulses PB
	stx	sheila_SYSVIA_acr

	; END TEST #3

	; TEST #4 T1 - should only set this up on motherboard
	ldx	#$0E
	stx	sheila_SYSVIA_t1ll
	ldx	#$27
	stx	sheila_SYSVIA_t1lh
	stx	sheila_SYSVIA_t1ch

	; END TEST #4

	; TEST #5 setup latches for mode 2
	; should set latch on at least shadow, probably on both?
	ldx	#$D
	stx	sheila_SYSVIA_orb
	ldx	#$4
	stx	sheila_SYSVIA_orb
	
	; END TEST 5

	; TEST #6 set up ULA / CRTC
	; should set up on both ?
	; set up HDMI for mode 2
	lda	_ULA_SETTINGS+2
	sta	sheila_ULA_ctl

	ldy	#$0b				; Y=11
	ldx	#$0b
_BCBB0:	lda	_CRTC_REG_TAB,X			; get end of 6845 registers 0-11 table
	sty	sheila_CRTC_ix
	sta	sheila_CRTC_dat
	dex					; reduce pointers
	dey					; 
	bpl	_BCBB0				; and if still >0 do it again


	; palette
	lda	#$00
	ldx	#15
	clc
pplp:	sta	sheila_ULA_pal
	adc	#$11
	dex
	bne	pplp

HERE:	lda	#$FF
	sta	$FEFF
	jmp	HERE



mos_handle_irq:
		rti

		.SEGMENT "VECTORS"
hanmi:  .addr   vec_nmi                         ; FFFA 00 0D                    ..
hares:  .addr   mos_handle_res                  ; FFFC CD D9                    ..
hairq:  .addr   mos_handle_irq                  ; FFFE 1C DC                    ..

		.END

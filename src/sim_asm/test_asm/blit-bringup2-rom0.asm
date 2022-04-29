; (c) Dossytronics 2017
; test harness ROM for VHDL testbench for MEMC mk2
; makes a 4k ROM

		.setcpu "6502X"

		.include	"common.inc"
		.include	"hw.inc"
		.include 	"aeris.inc"

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


sprite:
		.INCBIN "SPRIT2"



aeris_test2:
		AE_BRA		aeris_test2
aeris_test2_end:


aeris_test:	
		AE_MOVEC	0, 3
ae_lp:		

		AE_MOVECC	1, 0

ae_lp2:
		AE_BRA		*+3
		AE_BRA		*+3
		AE_BRA		*+3
		AE_BRA		*+3
		AE_BRA		*+3
		AE_DSZ		1
		AE_BRA		ae_lp2

		AE_SYNC
		AE_MOVE16	$2, $20, $ABCD
		AE_UNSYNC

		AE_DSZ		0
		AE_BRA		ae_lp


		AE_BRA		aeris_test

		AE_SYNC
		AE_MOVE16	$2, $40, $BEEF
		AE_UNSYNC

		AE_SYNC
		AE_MOVE16	$2, $40, $DEAD
		AE_UNSYNC

		AE_SYNC
		AE_MOVE16	$2, $40, $1234
		AE_UNSYNC

		AE_SYNC
		AE_WAITH
		AE_MOVE16	$2, $40, $FEDC
		AE_MOVE16	$2, $40, $BA98
		AE_MOVE16	$2, $40, $7654
		AE_MOVE16	$2, $40, $3210
		AE_UNSYNC

		AE_BRA		aeris_test


;		AE_MOVEC	0, 10
;		AE_MOVEP	0, aeris_rainbow
;
;		;;AE_WAIT		$1FF, $00, 30, 0
;
;aeris_lp1:	AE_MOVECC	1, 0
;		AE_MOVEPP	1, 0
;
;		AE_MOVEC	2, 9
;
;aeris_lp2:	AE_PLAY16	1, 1
;
;aeris_lp3:	AE_WAITH
;		AE_DSZ		0
;		AE_BRA		aeris_lp3
;
;		AE_DSZ		2
;		AE_BRA		aeris_lp2
;
;		AE_SKIP		$1FF, $00, 200, 0
;		AE_BRA		aeris_lp1
;
;		AE_WAIT		$1FF, $00, $1FF, 0

		

aeris_rainbow:			
		AE_MOVE16	$2, $23, $0000		; black
		AE_MOVE16	$2, $23, $0F00		; red
		AE_MOVE16	$2, $23, $0F80		; orange
		AE_MOVE16	$2, $23, $0FF0		; yellow
		AE_MOVE16	$2, $23, $0FF0		; green
		AE_MOVE16	$2, $23, $000F		; blue
		AE_MOVE16	$2, $23, $0408		; indigo
		AE_MOVE16	$2, $23, $0F8F		; violet
		AE_MOVE16	$2, $23, $0000		; black


;;		AE_MOVEC	3, 4
;;aeris_lp:	AE_DSZ		3
;;		AE_BRA		aeris_lp
;;		AE_WAITH
;;
;;		AE_WAIT		$1FF, $FF, 0, 5
;;		AE_BRAL		7, aeris_sub
;;		AE_SKIP		$1FF, 0, 1, 0
;;		AE_BRA		aeris_test
;;		AE_MOVE		$2, $21, $04
;;		AE_MOVE		$2, $21, $14
;;		AE_MOVE		$2, $21, $44
;;		AE_MOVE		$2, $21, $54
;;		AE_MOVEP	5, aeris_data
;;		AE_PLAY		5, 2
;;		AE_PLAY16	5, 2
		AE_WAIT		$1FF, $FF, $1FF, $FF		;; wait forever
;;
;;aeris_sub:	AE_MOVE		$2, $23, $10
;;		AE_MOVE16	$2, $00, $1234
;;		AE_MOVE16I 	$2, $02, $5678
;;		AE_RET		7
;;
;;aeris_data:	AE_MOVE 	$2, $21, $00
;;		AE_MOVE 	$2, $21, $02
;;aeris_data16:		
;;		AE_MOVE16 	$2, $23, $ABCD
;;		AE_MOVE16 	$2, $23, $DCBA

aeris_test_end:


sprite_blit_addr_mask := $050000
sprite_blit_addr_sprit := $050000 + $40
sprite2_size := 320


sample_test1:
		.INCBIN "A.SAMP"
sample_len	:= *-sample_test1

test_data:
	.byte	1,2,3,4,5,6,7,8,9

sprite2blit_ctl:
	.word	sprite
	.byte	$FF
	.word	sprite_blit_addr_mask & $FFFF
	.byte	sprite_blit_addr_mask >> 16
	.word	sprite2_size


sample_to_blit:
	.byte	$8A		; act, lin, mo.0, execD, execB	0 BLTCON
	.byte	$CC		; copy B to D, ignore A, C	0 FUNCGEN
	WORDBE	(32-1)		; 				0 WIDTH
	.byte	0		;				0 HEIGHT
	.byte	0		;				0 SHIFT
	.byte	0		;				0 MASK_FIRST
	.byte	0		;				0 MASK_LAST
	.byte	$AA		;				0 DATA_A
	.byte	0		;				0 ADDR_A_BANK
	WORDBE	0		;				0 ADDR_A
	.byte	$55		;				0 DATA_B
	.byte	$FF		;				0 ADDR_B_BANK
	WORDBE	sample_test1	;				0 ADDR_B
	.byte	$5A		;				0 DATA_C
	.byte	0		;				0 ADDR_C_BANK
	WORDBE	0		;				0 ADDR_C
	.byte	0		;				0 INTCON
	.byte	$08		;				0 ADDR_D_BANK
	WORDBE	$0000		;				0 ADDR_D
	WORDBE	256		;				0 STRIDE_A
	WORDBE	256		;				0 STRIDE_B
	WORDBE	256		;				0 STRIDE_C
	WORDBE	256		;				0 STRIDE_D



dollar_copy_to_SRAM_settings:
	.byte	BLITCON_EXEC_B + BLITCON_EXEC_D					;0
	.byte	$CC		; copy B to D, ignore A, C	FUNCGEN		;1
	.byte	0		; 				WIDTH		;2
	.byte	255		;				HEIGHT		;3
	.byte	0		;				SHIFT		;4
	.byte	0		;				MASK_FIRST	;5
	.byte	0		;				MASK_LAST	;6
	.byte	$AA		;				DATA_A		;7
	.byte	0		;				ADDR_A_BANK	;8
	WORDBE	0		;				ADDR_A		;9
	.byte	$55		;				DATA_B		;B
	.byte	$FF		;				ADDR_B_BANK	;C
	WORDBE	(mostbl_chardefs+8*('$'-' '));			ADDR_B		;D
	.byte	0		;				ADDR_C_BANK	;F
	WORDBE	0		;				ADDR_C		;10
	.byte	$00		;				ADDR_D_BANK	;12
	WORDBE	$0		;				ADDR_D		;13
	.byte	$00		;				ADDR_E_BANK	;15
	WORDBE	$0		;				ADDR_E		;16
	WORDBE	1		;				STRIDE_A	;18
	WORDBE	1		;				STRIDE_B	;1A
	WORDBE	1		;				STRIDE_C	;1C
	WORDBE	1		;				STRIDE_D	;1E
	.byte	BLITCON_ACT_ACT + BLITCON_ACT_MODE_1BBP		;BLTCON ACT	;0

dollar_copy_from_SRAM_settings:
	.byte	BLITCON_EXEC_B + BLITCON_EXEC_D
	.byte	$CC		; copy B to D, ignore A, C	FUNCGEN
	.byte	0		; 				WIDTH
	.byte	7		;				HEIGHT
	.byte	0		;				SHIFT
	.byte	0		;				MASK_FIRST
	.byte	0		;				MASK_LAST
	.byte	$AA		;				DATA_A
	.byte	0		;				ADDR_A_BANK
	WORDBE	0		;				ADDR_A
	.byte	$55		;				DATA_B
	.byte	$00		;				ADDR_B_BANK
	WORDBE	$0000		;				ADDR_B
	.byte	0		;				ADDR_C_BANK
	WORDBE	0		;				ADDR_C
	.byte	$FF		;				ADDR_D_BANK
	WORDBE	$4000		;				ADDR_D
	.byte	$FF		;				ADDR_E_BANK
	WORDBE	$4000		;				ADDR_E
	WORDBE	1		;				STRIDE_A
	WORDBE	1		;				STRIDE_B
	WORDBE	1		;				STRIDE_C
	WORDBE	1		;				STRIDE_D
dollar_copy_from_SRAM_settings_ACT := BLITCON_ACT_ACT + BLITCON_ACT_MODE_1BBP
	.byte	dollar_copy_from_SRAM_settings_ACT


sprite_test_settings:
	.byte	$EF		; act, cell, 4bpp, execD,C,B,A	BLTCON
	.byte	$CA		; copy B to D, mask A, C	FUNCGEN
	WORDBE	(8 - 1)		; 				WIDTH
	.byte	32-1		;				HEIGHT
	.byte	0		;				SHIFT
	.byte	0		;				MASK_FIRST
	.byte	0		;				MASK_LAST
	.byte	$AA		;				DATA_A
	.byte	sprite_blit_addr_mask >> 16		;				ADDR_A_BANK
	WORDBE	sprite_blit_addr_mask & $FFFF		;				ADDR_A
	.byte	$55		;				DATA_B
	.byte	sprite_blit_addr_sprit >> 16		;				ADDR_B_BANK
	WORDBE	sprite_blit_addr_sprit & $FFFF	;				ADDR_B
	.byte	$5A		;				DATA_C
	.byte	$FF		;				ADDR_C_BANK
	WORDBE	$300C		;				ADDR_C
	.byte	0		;				INTCON
	.byte	$FF		;				ADDR_D_BANK
	WORDBE	$300C		;				ADDR_D
	WORDBE	2		;				STRIDE_A
	WORDBE	8		;				STRIDE_B
	WORDBE	640		;				STRIDE_C
	WORDBE	640		;				STRIDE_D


blitcol_test_data:
	.byte	$03, $80


testrts:
	stx	$4000
	inx
	stx	$4001
	ldx	$4000
	ldx	$4001
	rts
testrtsend:

zp_shift 	:= $80
zp_maskf	:= $81
blitcolres	:= $100



I2C_TEST_ADDR	:= $A2


i2cwait:
	bit	jim_I2C_STAT
	bmi	i2cwait
	rts

mos_handle_res:

	; tricky test rom prolg
	sei
	cld

	ldx	#$FF
	txs

	; quick memory read/write test
	lda	#100
	sta	$200
	inc	$200

	; test SW RAM r/w
	lda	#14
	sta	$FE30
	lda	#17
	sta	$8000
	lda	$8000

	; test throttle

	lda	#$80
	sta	$FE36
	lda	#$D1
	sta	fred_JIM_DEVNO
	nop
	nop
	lda	fred_JIM_DEVNO
	lda	#0
	sta	fred_JIM_DEVNO


	lda	#$D1
	sta	fred_JIM_DEVNO
	; test RAM0 access
	lda	#$01
	sta	fred_JIM_PAGE_HI
	sta	fred_JIM_PAGE_LO
	sta	JIM
	lda	JIM

	lda	#0
	sta	$FE36			; throttle back off before test ChipRAM Write/Readback


	ldx	#3
@lp0:	txa
	sta	JIM,X
	dex
	bne	@lp0
	ldx	#3
@lp00:	lda	JIM,X
	dex
	bne	@lp00



	; test BBC slow bus bodge
	sta	sheila_SYSVIA_orb
	lda	sheila_SYSVIA_ora
	sta	sheila_SYSVIA_orb
	sta	sheila_SYSVIA_orb

	; turn off throttle
	lda	#0
	sta	$FE36

	; test VPA/VDA/cycles on 816
	php
	plp

	; quick ROM E test
	lda	#$E
	sta	$FE30
	lda	$8000


	lda	#$D1
	sta	fred_JIM_DEVNO
	; test HDMI RAM access
	lda	#$FA
	sta	fred_JIM_PAGE_HI
	lda	#0
	sta	fred_JIM_PAGE_LO
	lda	#$AA
	sta	JIM
	lda	JIM
	lda	#$55
	sta	JIM+1
	lda	JIM+1
	lda	JIM

HDMI_PAGE_REGS		:=	$FBFE
HDMI_ADDR_VIDPROC_CTL	:=	$FD20
HDMI_ADDR_VIDPROC_PAL	:=	$FD21
HDMI_ADDR_CRTC_IX	:=	$FD00
HDMI_ADDR_CRTC_DAT	:=	$FD01

	; set up HDMI for mode 2

	lda	#>HDMI_PAGE_REGS
	sta	fred_JIM_PAGE_HI
	lda	#<HDMI_PAGE_REGS
	sta	fred_JIM_PAGE_LO

	lda	_ULA_SETTINGS+2
	sta	HDMI_ADDR_VIDPROC_CTL

	ldy	#$0b				; Y=11
	ldx	#$0b
_BCBB0:	lda	_CRTC_REG_TAB,X			; get end of 6845 registers 0-11 table
	sty	HDMI_ADDR_CRTC_IX
	sta	HDMI_ADDR_CRTC_DAT
	dex					; reduce pointers
	dey					; 
	bpl	_BCBB0				; and if still >0 do it again


	; palette
	lda	#$00
	ldx	#15
	clc
pplp:	sta	HDMI_ADDR_VIDPROC_PAL
	adc	#$11
	dex
	bne	pplp



	; test i2c interface 
	lda	#$D1
	sta	fred_JIM_DEVNO
	jsr	jimDMACPAGE


	; send address with RnW=0
	lda	#I2C_TEST_ADDR
	sta	jim_I2C_DATA
	lda	#I2C_BUSY|I2C_START
	sta	jim_I2C_STAT

	jsr	i2cwait

	lda	#1
	sta	jim_I2C_DATA
	lda	#I2C_BUSY
	sta	jim_I2C_STAT

	jsr	i2cwait

	lda	#2
	sta	jim_I2C_DATA
	lda	#I2C_BUSY
	sta	jim_I2C_STAT

	jsr	i2cwait

	lda	#3
	sta	jim_I2C_DATA
	lda	#I2C_BUSY|I2C_STOP
	sta	jim_I2C_STAT


	; send address with RnW=1
	lda	#I2C_TEST_ADDR|I2C_RNW
	sta	jim_I2C_DATA
	lda	#I2C_BUSY|I2C_START
	sta	jim_I2C_STAT

	jsr	i2cwait

	lda	#I2C_BUSY|I2C_RNW
	sta	jim_I2C_STAT

	jsr	i2cwait
	lda	jim_I2C_DATA

	lda	#I2C_BUSY|I2C_RNW|I2C_NACK|I2C_STOP
	sta	jim_I2C_STAT

	jsr	i2cwait
	lda	jim_I2C_DATA


	; test BB RAM (if enabled)
	lda	#$D1
	sta	fred_JIM_DEVNO
	lda	#$70
	sta	fred_JIM_PAGE_HI
	sta	fred_JIM_PAGE_LO

	lda	#$AA
	sta	$FD00
	lda	$FD00

	; test Chipram
	lda	#$00
	sta	fred_JIM_PAGE_HI
	sta	fred_JIM_PAGE_LO

	lda	#$AA
	sta	$FD00
	lda	$FD00

	; test Flash
	lda	#$90
	sta	fred_JIM_PAGE_HI
	sta	fred_JIM_PAGE_LO

	lda	$FD00
	lda	$FD00
	lda	$FD00

	

	; enable jim
	lda	#JIM_DEVNO_BLITTER
	sta	fred_JIM_DEVNO
	lda	fred_JIM_DEVNO	


	; quick BLTURBO test
	lda	#$80
	sta	$FE37
	ldx	#23
	stx	$7F0F
	ldx	$7F0F


	; quick version test
	lda	#$FC
	sta	$FCFD
	lda	$FD00
	lda	$FD00


	; test contention of resources - set off a dma transfer
	; from ChipRAM to SYS run program from memory at same
	; time copying to/from SYS

	; initialise DMAC channel 0

	jsr	jimDMACPAGE
	ldx	#0
	stx	jim_DMAC_DMA_SEL
	; source is Base of MOS in ChipRAM (80 0000)
	ldx	#$80
	stx	jim_DMAC_DMA_SRC_ADDR
	ldx	#0
	stx	jim_DMAC_DMA_SRC_ADDR+1
	stx	jim_DMAC_DMA_SRC_ADDR+2

	; dest is Screen RAM at FF 7000
	ldx	#$FF
	stx	jim_DMAC_DMA_DEST_ADDR
	ldx	#$70
	stx	jim_DMAC_DMA_DEST_ADDR+1
	ldx	#0
	stx	jim_DMAC_DMA_DEST_ADDR+2

	ldx	#$00
	stx	jim_DMAC_DMA_COUNT
	ldx	#$40
	stx	jim_DMAC_DMA_COUNT+1

	ldx	#DMACTL_ACT | DMACTL_STEP_DEST_UP | DMACTL_STEP_SRC_UP
	stx	jim_DMAC_DMA_CTL

	; loop copying from SYS RAM at FF 1000 to Chip RAM at 00 01000
@lpDMA:	jsr	jimChipRAMPAGE
	lda	$1000,X
	sta	JIM,X
	inx
	jsr	jimDMACPAGE
	lda	jim_DMAC_DMA_CTL
	bmi	@lpDMA



	lda	#20
	sta	0
@lp0:	dec	0
	bne	@lp0



	lda	$FC00
	lda	$FC00
	jmp	@sksk
@sksk:	lda	$FC00
	lda	$FC00

	lda	#$A5
	eor	$FC00



	; sound select test
	jsr	jimDMACPAGE
	ldx	#3
@l1_1:	stx	jim_DMAC_SND_SEL
	txa
	asl	A
	asl	A
	asl	A
	asl	A
	sta	jim_DMAC_SND_ADDR+1
	dex
	bpl	@l1_1

	ldx	#3
@l1_2:	stx	jim_DMAC_SND_SEL
	lda	jim_DMAC_SND_ADDR+1
	dex
	bpl	@l1_2



	lda	#0
	sta	fred_JIM_PAGE_HI
	sta	fred_JIM_PAGE_LO

	; test run from RAM
	ldx	#testrtsend-testrts
@lprts:	lda	testrts,X
	sta	$FD00,X
	dex
	bpl	@lprts
	jsr	$FD00

	jsr testDMAC_simple



;;	jsr	illegalops

	jsr	AERTEST

	ldx	#0
@lp:	stx	$FE40
	stx	$FE40
	stx	$FE40
	stx	$FE40
	stx	$FE40
	stx	$FE40
	stx	$FE40
	inx
	jmp	@lp


	; blturbo on page 0, 1
	lda	#$03
	sta	sheila_MEM_LOMEMTURBO

	jsr	testrts

	; check clock lock
	lda	$FC00
	lda	$FC00
	lda	$FC00
	lda	$FC00
	bne	@s1
@s1:	lda	$FC00
	lda	$FC00
	lda	$FC00
	lda	$FC00




	jsr	SOUNDTEST

	jsr	AERTEST



HERE:	jmp	HERE



	; test blitter collision detection
	lda	#0
	sta	zp_shift
	lda	#$FF
	sta	zp_maskf

	ldx	#$FF
	stx	jim_DMAC_ADDR_A
	stx	jim_DMAC_ADDR_B
	stx	jim_DMAC_MASK_LAST
	ldx	#0
	stx	jim_DMAC_HEIGHT
	inx
	stx	jim_DMAC_WIDTH
	ldx	#$C0
	stx	jim_DMAC_FUNCGEN
	ldx	#BLITCON_EXEC_A+BLITCON_EXEC_B
	stx	jim_DMAC_BLITCON
	

@loop:	ldx	#>blitcol_test_data
	stx	jim_DMAC_ADDR_A+1
	stx	jim_DMAC_ADDR_B+1
	ldx	#<blitcol_test_data
	stx	jim_DMAC_ADDR_A+2
	stx	jim_DMAC_ADDR_B+2
	ldx	zp_shift
	stx	jim_DMAC_SHIFT
	ldx	zp_maskf
	stx	jim_DMAC_MASK_FIRST
	ldx	#BLITCON_ACT_MODE_1BBP+BLITCON_ACT_ACT+BLITCON_ACT_COLLISION
	stx	jim_DMAC_BLITCON
	
	ldx	zp_shift
	lda	jim_DMAC_BLITCON
	sta	blitcolres, X


	; next
	inc	zp_shift
	lsr	zp_maskf
	bne	@loop


	ldx	#0
@loop2:	lda	blitcolres, X
	inx
	cpx	#8
	bne	@loop2


	; test lo memory blturbo
	lda	#0
	sta	fred_JIM_PAGE_HI
	lda	#02
	sta	fred_JIM_PAGE_LO


	ldx	#testrtsend-testrts-1
@lp:	lda	testrts,X
	sta	$FD00,X
	dex
	bpl	@lp

	lda	#01
	sta	sheila_MEM_LOMEMTURBO

	jsr	$200








	lda	#$03
	sta	$FE37					; make pages 00-2F shadow

	sta	$4000
	sta	$4001

	lda	#$10
	sta	fred_JIM_PAGE_HI
	sta	fred_JIM_PAGE_LO

	ldx	#testrtsend-testrts
@l1:	lda	testrts,X
	sta	jim_base,X
	dex
	bpl	@l1

	jsr	jim_base

	lda	#0
	sta	$FE37

	jsr	jim_base

	jsr	SOUNDTEST


	ldx	#0
@l2:	stx	$FE30
	lda	$8000
	inx
	cpx	#10
	bne	@l2



	; test DMAC pause

	LDA	#$FF
	STA	jim_DMAC_DMA_SRC_ADDR
	STA	jim_DMAC_DMA_DEST_ADDR
	LDA	#>(sample_to_blit + 31)
	STA	jim_DMAC_DMA_SRC_ADDR + 1
	LDA	#<(sample_to_blit + 31)
	STA	jim_DMAC_DMA_SRC_ADDR + 2
	LDA	#>$FC5C
	STA	jim_DMAC_DMA_DEST_ADDR + 1
	LDA	#<$FC5C
	STA	jim_DMAC_DMA_DEST_ADDR + 2
	LDA	#0
	STA	jim_DMAC_DMA_COUNT
	LDA	#$5
	STA	jim_DMAC_DMA_COUNT+1
	LDA	#$01
	STA	jim_DMAC_DMA_CTL2		; pause!
	LDA	#5
	STA	jim_DMAC_DMA_PAUSE_VAL
	LDA	#$BA				; act, dest, src down, halt, extend
	STA	jim_DMAC_DMA_CTL


	; test sound register writes / reads
	lda	#0
	sta jim_DMAC_SND_SEL
	lda #0
	sta jim_DMAC_SND_DATA
	lda #255
	sta jim_DMAC_SND_DATA

	lda	#3
	sta jim_DMAC_SND_SEL
	lda #0
	sta jim_DMAC_SND_DATA
	lda #128
	sta jim_DMAC_SND_DATA

	lda	#0
	sta jim_DMAC_SND_SEL
	lda jim_DMAC_SND_DATA


	; test DMAC

	LDA	#$FF
	STA	jim_DMAC_DMA_SRC_ADDR
	STA	jim_DMAC_DMA_DEST_ADDR
	LDA	#>(sample_to_blit + 31)
	STA	jim_DMAC_DMA_SRC_ADDR + 1
	LDA	#<(sample_to_blit + 31)
	STA	jim_DMAC_DMA_SRC_ADDR + 2
	LDA	#>(jim_DMAC + 31)
	STA	jim_DMAC_DMA_DEST_ADDR + 1
	LDA	#<(jim_DMAC + 31)
	STA	jim_DMAC_DMA_DEST_ADDR + 2
	LDA	#0
	STA	jim_DMAC_DMA_COUNT
	LDA	#$1F
	STA	jim_DMAC_DMA_COUNT+1
	LDA	#$01
	STA	jim_DMAC_DMA_CTL2		; pause!
	LDA	#3
	STA	jim_DMAC_DMA_PAUSE_VAL
	LDA	#$BA				; act, dest, src down, halt, extend
	STA	jim_DMAC_DMA_CTL

skipahead:


testDMAC_simple:
	; test DMAC simple 16 bits
	jsr	jimDMACPAGE
	LDA	#$FF
	STA	jim_DMAC_DMA_SEL
	STA	jim_DMAC_DMA_SRC_ADDR
	STA	jim_DMAC_DMA_DEST_ADDR
	LDA	#>test_data
	STA	jim_DMAC_DMA_SRC_ADDR + 1
	LDA	#<test_data
	STA	jim_DMAC_DMA_SRC_ADDR + 2
	LDA	#>$4000
	STA	jim_DMAC_DMA_DEST_ADDR + 1
	LDA	#<$4000
	STA	jim_DMAC_DMA_DEST_ADDR + 2
	LDA	#>$10
	STA	jim_DMAC_DMA_COUNT
	LDA	#<$10
	STA	jim_DMAC_DMA_COUNT+1
	LDA	#$04				; word, no swap
	STA	jim_DMAC_DMA_CTL2		; no pause!
	LDA	#0
	STA	jim_DMAC_DMA_PAUSE_VAL
	LDA	#$A5				; act, dest, src up, NOT halt, extend
	STA	jim_DMAC_DMA_CTL

	LDA	$FE60
	STX	$FE60
	INX
	JMP	@jj
@jj:	LDA	$FE60
	STX	$FE60
	INX


@w:	BIT	jim_DMAC_DMA_CTL
	BMI	@w


	; test count =0 restart - should do a single iteration back to 4000
	LDA	#0
	STA	jim_DMAC_DMA_DEST_ADDR+2
	LDA	#$A5				; act, dest, src up, NOT halt, extend
	STA	jim_DMAC_DMA_CTL

@w2:	BIT	jim_DMAC_DMA_CTL
	BMI	@w2


	rts


jimDMACPAGE:
	pha
	lda	#<jim_page_DMAC
	sta	fred_JIM_PAGE_LO
	lda	#>jim_page_DMAC
	sta	fred_JIM_PAGE_HI
	pla
	rts
jimChipRAMPAGE:
	pha
	lda	#0
	sta	fred_JIM_PAGE_LO
	sta	fred_JIM_PAGE_HI
	pla
	rts


SOUNDTEST:
	jsr	jimDMACPAGE
	; sound read test
	lda	#3
	sta	jim_DMAC_SND_SEL
	lda	#$ff
	sta	jim_DMAC_SND_SEL
	lda	jim_DMAC_SND_SEL



	; set up sound sample
	lda	#1
	sta	fred_JIM_PAGE_HI
	sta	fred_JIM_PAGE_LO
	ldx	#31
@lll1:	txa
	sta	$FD00,X
	dex
	bpl	@lll1

	jsr	jimDMACPAGE

	ldy	#0
sl:	sty	jim_DMAC_SND_SEL
	; play samples

	ldx	#1
	stx	jim_DMAC_SND_ADDR
	ldx	#1
	stx	jim_DMAC_SND_ADDR + 1
	ldx	#0
	stx	jim_DMAC_SND_ADDR + 2
	ldx	#0
	stx	jim_DMAC_SND_PERIOD
	stx	jim_DMAC_SND_LEN
	tya
	asl	a
	asl	a
	adc	#20
	sta	jim_DMAC_SND_PERIOD + 1
	ldx	#31
	stx	jim_DMAC_SND_LEN + 1
	ldx	#$81
	stx	jim_DMAC_SND_STATUS

	iny
	cpy	#4
	bne	sl
	rts

AERTEST:
	jsr	jimDMACPAGE
	; test dma
	lda	#0
	sta	jim_DMAC_DMA_SEL	
	; source address from ROM at FFCxxx
	lda	#$FF
	sta	jim_DMAC_DMA_SRC_ADDR
	lda	#>aeris_test
	sta	jim_DMAC_DMA_SRC_ADDR+1
	lda	#<aeris_test
	sta	jim_DMAC_DMA_SRC_ADDR+2
	lda	#$00
	sta	jim_DMAC_DMA_DEST_ADDR
	lda	#$10
	sta	jim_DMAC_DMA_DEST_ADDR+1
	lda	#$00
	sta	jim_DMAC_DMA_DEST_ADDR+2
	lda	#>(aeris_test_end-aeris_test-1)
	sta	jim_DMAC_DMA_COUNT
	lda	#<(aeris_test_end-aeris_test-1)
	sta	jim_DMAC_DMA_COUNT+1
	lda	#DMACTL_ACT+DMACTL_HALT+DMACTL_STEP_SRC_UP+DMACTL_STEP_DEST_UP
	sta	jim_DMAC_DMA_CTL


	;aeris setup at $00 1000

;	lda	#0
;	sta	fred_JIM_PAGE_HI
;	lda	#$10
;	sta	fred_JIM_PAGE_LO
;
;	; copy data to chip ram
;	ldx	#aeris_test_end-aeris_test-1
;aecpylp:lda	aeris_test,X
;	sta	JIM,X
;	dex
;	bpl	aecpylp
;
;	jsr	jimDMACPAGE

	lda	#$00
	sta	jim_DMAC_AERIS_PROGBASE
	lda	#$10
	sta	jim_DMAC_AERIS_PROGBASE+1
	lda	#$00
	sta	jim_DMAC_AERIS_PROGBASE+2

	lda	#$80
	sta	jim_DMAC_AERIS_CTL
	rts

AERTEST2:
	jsr	jimDMACPAGE
	; test dma
	lda	#0
	sta	jim_DMAC_DMA_SEL	
	; source address from ROM at FFCxxx
	lda	#$FF
	sta	jim_DMAC_DMA_SRC_ADDR
	lda	#>aeris_test2
	sta	jim_DMAC_DMA_SRC_ADDR+1
	lda	#<aeris_test2
	sta	jim_DMAC_DMA_SRC_ADDR+2
	lda	#$00
	sta	jim_DMAC_DMA_DEST_ADDR
	lda	#$10
	sta	jim_DMAC_DMA_DEST_ADDR+1
	lda	#$00
	sta	jim_DMAC_DMA_DEST_ADDR+2
	lda	#>(aeris_test2_end-aeris_test2-1)
	sta	jim_DMAC_DMA_COUNT
	lda	#<(aeris_test2_end-aeris_test2-1)
	sta	jim_DMAC_DMA_COUNT+1
	lda	#DMACTL_ACT+DMACTL_HALT+DMACTL_STEP_SRC_UP+DMACTL_STEP_DEST_UP
	sta	jim_DMAC_DMA_CTL

	lda	#$00
	sta	jim_DMAC_AERIS_PROGBASE
	lda	#$10
	sta	jim_DMAC_AERIS_PROGBASE+1
	lda	#$00
	sta	jim_DMAC_AERIS_PROGBASE+2

	lda	#$80
	sta	jim_DMAC_AERIS_CTL
	rts


;		; wait until blit done
;1		LDA	jim_DMAC_BLITCON
;		BMI	1B
		RTS


	; test some illegal operations
illegalops:
		ldx	#$55			; mask
		lda	#%10011100		; data
		sax	0			; should store   00010100 to 0
		alr	#$AA			; A should be    01000100
		slo	0			; 0 should go to 00101000 and A to 01101100
		sta	0
		rts

mos_handle_irq:
		rti

		.SEGMENT "VECTORS"
hanmi:  .addr   vec_nmi                         ; FFFA 00 0D                    ..
hares:  .addr   mos_handle_res                  ; FFFC CD D9                    ..
hairq:  .addr   mos_handle_irq                  ; FFFE 1C DC                    ..

		.END

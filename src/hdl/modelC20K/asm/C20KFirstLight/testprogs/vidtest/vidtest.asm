; MIT License
; 
; Copyright (c) 2025 Dossytronics
; https://github.com/dominicbeesley/blitter-65xx-code
; 
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
; 
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.


; (c) Dossytronics 2017, 2025
;
; Demonstrates hdmi and video access - for analogue video the correct firmware
; should be programmed and IC's U28, U19 must be fitted

		.include	"p20k.inc"

		.ZEROPAGE

ptr1:		.res	2


		.CODE
		
		; quick test program - change HDMI to mode 2, non-interlaced and copy current screen contents to base
		; of hdmi memory

VIDPROC_CTL	:=	$FE20
VIDPROC_PAL	:=	$FE21
CRTC_IX		:=	$FE00
CRTC_DAT	:=	$FE01


zp_ptr			:=	$70


		.CODE

START:

	; set up HDMI for mode 2

		lda	_ULA_SETTINGS+7
		sta	VIDPROC_CTL

		ldy	#$0b				; Y=11
		ldx	#$0b
_BCBB0:		lda	_CRTC_REG_TAB7,X		; get end of 6845 registers 0-11 table
		sty	CRTC_IX
		sta	CRTC_DAT
		dex					; reduce pointers
		dey					; 
		bpl	_BCBB0				; and if still >0 do it again

		; palette
		lda	#$0F
		ldx	#15
		clc
pplp:		sta	VIDPROC_PAL
		adc	#$0F
		dex
		bne	pplp


		lda	#$30
		sta	zp_ptr + 1
		lda	#$00
		sta	zp_ptr
		ldy	#0
@flp:		tya
		sta	(zp_ptr),Y
		iny
		bne	@flp
		inc	zp_ptr + 1
		bpl	@flp


		brk
		brk


		rts


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
			.byte	$01				; 8 Interlace+Cursor	 =&01  Cursor=0, Display=0, Interlace=On
			.byte	$07				; 9 Scan Lines/Character =8
			.byte	$67				; 10 Cursor Start Line	  =&67	Blink=On, Speed=1/32, Line=7
			.byte	$08				; 11 Cursor End Line	  =8




;********* 6845 REGISTERS 0-11 FOR SCREEN TYPE 4 - MODE 7 ****************

_CRTC_REG_TAB7:		.byte	$3f				; 0 Horizontal Total	 =64
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

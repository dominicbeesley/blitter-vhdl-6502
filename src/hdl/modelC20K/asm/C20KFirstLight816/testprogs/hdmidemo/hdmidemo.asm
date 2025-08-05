; MIT License
; 
; Copyright (c) 2025 Dossytronics
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
; Demonstrates reading the manufacturer codes of the Flash EEPROM of
; the c20k board via 65816 methods. address of Flash EEPROM is 80 0000 

		.include	"c20k816.inc"


.macro          M_PRINT addr
		.a8
		.i16
		ldy	#.loword(addr)
		jsr	PrintY
.endmacro

.macro		M_ADDR addr
		.a8
		.i16
		pha
		phx
		lda	#.bankbyte(addr)
		sta	z:<(zp_addr+2)
		ldx	#.loword(addr)
		stx	z:<(zp_addr+0)
		plx
		pla
.endmacro

.macro 		M_ADDR_5555
		M_ADDR $805555
.endmacro

.macro 		M_ADDR_2AAA
		M_ADDR $802AAA
.endmacro


		.ZEROPAGE
zp_addr:	.res	3

		.BSS
manu_id:	.res 	1
dev_id:		.res	1
		.CODE
		
;==============================================================================
; M A I N
;==============================================================================

main:
		; entry is from DeIce monitor and we won't be returning
		clc
		xce		; ensure native mode
		rep	#$30
		.i16
		.a16

		lda	#.loword(__ZP_START__)
		tcd
		ldx	#.loword(__STACK_START__ + __STACK_SIZE__ - 1)
		txs

		phk
		plb	; data bank is program bank


		; enter mode 7
		ldy	#.loword(crtc_mode7)
		jsl	mode_crtc

		lda	#$4b
		jsl	poke_ula

		ldx	#.loword(testcard_mo7)
		ldy	#$7C00
		lda	#25*40
		;;mvn	.bankbyte(main), .bankbyte(HDMI_SCREEN_BASE)
		;;mvn	$10, $FA
		.byte $54, .bankbyte(HDMI_SCREEN_BASE),.bankbyte(main)


		wdm	0


	; mode agnostic, value in lower half of C
poke_ula:	pha
		php
		sep	#$20
		.a8
		sta	f:HDMI_ULA_ctl
		plp
		pla
		rtl

	; mode agnostic, value in lower half of C
poke_crtc:	pha	
		phx
		phy	
		php
		sep	#$30
		.a8
		.i8
		pha
		txa
		sta	f:HDMI_CRTC_ix
		pla
		sta	f:HDMI_CRTC_dat
		plp
		ply
		plx
		pla
		rtl
		
mode_crtc:	pha
		phx
		phy
		php
		rep	#$10
		sep	#$20
		.i16
		.a8
		ldx	#11
@lp:		lda	11,Y
		dey
		jsl	poke_crtc
		dex
		bpl	@lp
		plp
		ply
		plx
		pla
		rtl





uart_tx:	php
		.a8
		.i8
		sep	#$20
		pha
@lp:		lda	f:UART_STAT
		and	#$40
		bne	@lp
		pla
		sta	f:UART_DAT
		plp
		rts


uart_rx:	php
		.a8
		.i8
		sep	#$20
@lp:		lda	f:UART_STAT
		bpl	@lp
		lda	f:UART_DAT
		plp
		rts

		.rodata

;********* 6845 REGISTERS 0-11 FOR SCREEN TYPE 4 - MODE 7 ****************

crtc_mode7:
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

testcard_mo7:		.incbin "testcard.mo7"

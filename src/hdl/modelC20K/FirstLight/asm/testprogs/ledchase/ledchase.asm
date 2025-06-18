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


		.include "p20k.inc"


		.ZEROPAGE
zp_ctr:		.res	4


zp_wait_ctr:	.res	2

zp_tmp:		.res	4

		.BSS

		.CODE
		
;==============================================================================
; M A I N
;==============================================================================

		lda	#DEVNO_C20K
		sta	fred_JIM_DEVNO

		lda	#>PAGE_LEDS
		sta	fred_JIM_PAGE_HI
		lda	#<PAGE_LEDS
		sta	fred_JIM_PAGE_LO


lmain:
		jsr	leds_blank

		jsr	wait
		jsr	wait
		jsr	wait


		lda	#3
		sta	zp_ctr+1
@l3:
		; colours down
		ldy	#11*3
@l2:
		lda	spec_cols,Y
		sta	JIM+0
		lda	spec_cols+1,Y
		sta	JIM+1
		lda	spec_cols+2,Y
		sta	JIM+2

		lda	#8
		sta	zp_ctr
@l1:		jsr	wait
		jsr	leds_rotate_down
		dec	zp_ctr
		bne	@l1

		dey
		dey
		dey
		bpl	@l2
		dec	zp_ctr+1
		bne	@l3

		
		ldy	#11*3
@l4:		lda	spec_cols,Y
		sta	JIM+0
		lda	spec_cols+1,Y
		sta	JIM+1
		lda	spec_cols+2,Y
		sta	JIM+2
		jsr	wait
		jsr	wait
		jsr	leds_rotate_down
		dey
		dey
		dey
		bpl	@l4

here:		jmp	here


		jmp	lmain


wait0:		rts

wait:		lda	#0
		sta	zp_wait_ctr
		sta	zp_wait_ctr+1
@lp:		jsr	wait0
		dec	zp_wait_ctr
		bne	@lp
		dec	zp_wait_ctr+1
		bne	@lp
		rts

leds_rotate_down:
		pha
		txa
		pha
		lda	JIM+30
		sta	zp_tmp+3
		lda	JIM+29
		sta	zp_tmp+2
		lda	JIM+28
		sta	zp_tmp+1

		ldx	#4*7-1
@l1:		lda	JIM,X
		sta	JIM+4,X
		dex
		bpl	@l1

		lda	zp_tmp+3
		sta	JIM+2
		lda	zp_tmp+2
		sta	JIM+1
		lda	zp_tmp+1
		sta	JIM+0

		pla
		tax
		pla
		rts





leds_blank:	lda	#0
		ldy	#8*4
@lp:		dey
		dey
		sta	JIM,Y
		dey
		sta	JIM,Y
		dey
		sta	JIM,Y
		bne	@lp
		rts

		.data

		.macro	COLOUR r, g, b
		.byte r,g,b
		.endmacro

spec_cols:	COLOUR $F, $0, $0
		COLOUR $C, $3, $0
		COLOUR $7, $7, $0
		COLOUR $3, $C, $0
		COLOUR $0, $F, $0
		COLOUR $0, $C, $3
		COLOUR $0, $7, $7
		COLOUR $0, $3, $C
		COLOUR $0, $0, $F
		COLOUR $3, $0, $C		
		COLOUR $7, $0, $7
		COLOUR $C, $0, $3		
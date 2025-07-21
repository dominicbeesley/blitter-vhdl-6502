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


		sep	#$20
		.a8

		; enter software ID mode
		M_ADDR_5555
		lda	#$AA
		sta	[zp_addr]
		M_ADDR_2AAA
		lda	#$55
		sta	[zp_addr]
		M_ADDR_5555
		lda	#$90
		sta	[zp_addr]



		M_ADDR 	$800000	
		lda	[zp_addr]
		sta	manu_id

		M_ADDR 	$800001
		lda	[zp_addr]
		sta	dev_id


		lda	#$F0
		sta	[zp_addr]

		M_PRINT str_man

		lda	manu_id
		cmp	#$BF
		bne	@s1
		M_PRINT str_sst
		beq	@s2
@s1:		jsr	uk
@s2:

dev:
		M_PRINT str_dev

		lda	dev_id
		cmp	#$D5
		beq	@s010
		cmp	#$D6
		beq	@s020
		cmp	#$D7
		beq	@s040
@s1:		jsr	uk
		jmp	@s2
@s010:		M_PRINT str_dev_010
		jmp	@s2
@s020:		M_PRINT str_dev_020
		jmp	@s2
@s040:		M_PRINT str_dev_040
		jmp	@s2
@s2:

		wdm	0
here:		jmp	here


uk:		pha			
		M_PRINT str_uk
		pla
		jsr	PrintHex
		lda	#')'
		jsr	OSWRCH
		jmp	OSNEWL




; see http://www.obelisk.me.uk/6502/algorithms.html
PrintHex:
		pha                        
		lsr 	A
		lsr	A
		lsr 	A
		lsr	A
		jsr 	PrIntHexNyb
		pla
		and 	#$0F
PrIntHexNyb:
		sed
		clc
		adc	#$90
		adc	#$40
		cld
		jmp	OSWRCH

PrintAddr:	lda	zp_addr+2
		jsr	PrintHex
		lda	zp_addr+1
		jsr	PrintHex
		lda	zp_addr+0
		jmp	PrintHex

PrintY:		
@lp:		lda	a:0,Y
		beq	@out
		jsr	OSASCI
		iny
		bne	@lp
@out:		rts



Print13:	lda	#13
		jmp	OSWRCH

PrintSpc:	lda	#' '
		jmp	OSWRCH


OSASCI:		cmp	#$0d		; OSASCI output a byte to VDU stream expanding
		bne	OSWRCH		; carriage returns (&0D) to LF/CR (&0A,&0D)
OSNEWL:		lda	#$0a		; OSNEWL output a CR/LF to VDU stream
		jsr	OSWRCH		; Outputs A followed by CR to VDU stream
		lda	#$0d
OSWRCH:
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

str_man:	.byte	"Manufacturer :", 0
str_dev:	.byte	"Device       :", 0
str_uk:		.byte	"Unknown (&", 0
str_sst:	.byte	"SST/Microchip", $D, 0
str_dev_010:	.byte	"SST39*F010", $D, 0
str_dev_020:	.byte	"SST39*F020", $D, 0
str_dev_040:	.byte	"SST39*F040", $D, 0


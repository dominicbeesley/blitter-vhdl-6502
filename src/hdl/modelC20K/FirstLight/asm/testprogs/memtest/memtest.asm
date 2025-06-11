; MIT License
; 
; Copyright (c) 2023 Dossytronics
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


; (c) Dossytronics 2017
; test a memory mapped JIM memory

; (c) Dossytronics 2025 - adapted from version
; in blitter tools65 project

		.include 	"p20k.inc"



.macro 		M_BRK
		brk
.endmacro

.macro          M_PRINT addr
		ldx	#<addr
		ldy	#>addr
		jsr	PrintXY
.endmacro

		.ZEROPAGE
zp_tmpptr:	.res	2
zp_trans_acc:	
zp_addr:	.res	3
zp_data:	.res	1
zp_fail:	.res	1

zp_mos_txtptr:	.res	2

		.BSS
addr_max:	.res	3
flag_soak:	.res	1
flag_soak_ctr:	.res	4
		.CODE
		
;==============================================================================
; M A I N
;==============================================================================


		lda	#$1F
		sta	addr_max+2
		ldx	#$FF
		stx	addr_max+1
		stx	addr_max+0

		stx	flag_soak
		inx
		stx	flag_soak_ctr
		stx	flag_soak_ctr + 1
		stx	flag_soak_ctr + 2
		stx	flag_soak_ctr + 3

go:

		; check device present
;		lda	dev_no
;		sta	zp_mos_jimdevsave
;		sta	fred_JIM_DEVNO
;		lda	fred_JIM_DEVNO		
;		eor	dev_no
;		tax
;		inx
;		beq	@devok
;
;		M_PRINT str_warning_dev
;		lda	dev_no
;		jsr	PrintHex
;		jsr	OSNEWL
;		
;		jsr	contyn
;
;		M_PRINT str_panic
;		jsr	contyn
;
@devok:
		M_PRINT str_Init


again:
		M_PRINT str_TestDataLine

data_W1:
		M_PRINT str_TestW1

		jsr	addr0
		sta	zp_fail

		lda	#1
		sta	zp_data
@l:		jsr	jimwrite
		clc
		rol	zp_data
		bcc	@l

		jsr	passfail

data_W0:
		M_PRINT str_TestW0

		jsr	addr0
		sta	zp_fail

		lda	#$FE
		sta	zp_data
@l:		jsr	jimwrite
		jsr	jimcheck
		sec
		rol	zp_data
		bcs	@l

		jsr	passfail

		M_PRINT str_TestAddrLine

addr_W1:
		M_PRINT str_TestW1

		jsr	addr0
		sec	
		jsr	roladdr
		sta	zp_fail

		lda	#1
		sta	zp_data
@l:		jsr	jimwrite
		clc
		jsr	roladdr
		inc	zp_data
		jsr	cmpaddrmax
		bcc	@l
		
		jsr	addr0
		sec	
		jsr	roladdr

		lda	#1
		sta	zp_data
@l2:		jsr	jimcheck
		clc
		jsr	roladdr
		inc	zp_data
		jsr	cmpaddrmax
		bcc	@l2

		jsr	passfail

addr_W0:
		M_PRINT str_TestW0

		jsr	addrmax
		clc
		jsr	roladdr
		jsr	addrandmax
		lda	#0
		sta	zp_fail

		lda	#$FF
		sta	zp_data
@l:		jsr	addrandmax
		jsr	jimwrite
		dec	zp_data
		sec
		jsr	roladdr
		jsr	addrandmax
		jsr	cmpaddrmax
		bcc	@l

		jsr	addrmax
		clc
		jsr	roladdr
		jsr	addrandmax
		
		lda	#$FF
		sta	zp_data
@l2:		jsr	jimcheck
		sec
		jsr	roladdr
		dec	zp_data
		jsr	addrandmax
		jsr	cmpaddrmax
		bcc	@l2

		jsr	passfail

addr_S1:
		M_PRINT str_TestS1

		jsr	addr0
		sta	zp_fail

		lda	#1
		sta	zp_data
@l:		jsr	jimwrite
		sec
		jsr	roladdr
		inc	zp_data
		jsr	cmpaddrmax
		bcc	@l
		
		jsr	addr0

		lda	#1
		sta	zp_data
@l2:		jsr	jimcheck
		sec
		jsr	roladdr
		inc	zp_data
		jsr	cmpaddrmax
		bcc	@l2

		jsr	passfail



		bit	flag_soak
		bpl	@out

		M_PRINT	str_SoakPass

		ldx	#3

@l3:		lda	flag_soak_ctr,X
		jsr	PrintHex
		dex
		bpl	@l3

		inc	flag_soak_ctr
		bne	@sc1
		inc	flag_soak_ctr+1
		bne	@sc1
		inc	flag_soak_ctr+2
		bne	@sc1
		inc	flag_soak_ctr+3


@sc1:		jsr	OSNEWL
		jmp	again


@out:		rts

cmpaddrmax:	sec
		lda	zp_addr
		sbc	addr_max
		lda	zp_addr+1
		sbc	addr_max+1
		lda	zp_addr+2
		sbc	addr_max+2
		rts

roladdr:
		rol	zp_addr
		rol	zp_addr+1
		rol	zp_addr+2
		rts

roraddr:
		ror	zp_addr
		ror	zp_addr+1
		ror	zp_addr+2
		rts


addr0:	
		lda	#0
		sta	zp_addr
		sta	zp_addr+1
		sta	zp_addr+2
		rts

addrmax:	
		lda	addr_max
		sta	zp_addr
		lda	addr_max+1
		sta	zp_addr+1
		lda	addr_max+2
		sta	zp_addr+2
		rts

addrandmax:	
		lda	addr_max
		and	zp_addr
		sta	zp_addr
		lda	addr_max+1
		and	zp_addr+1
		sta	zp_addr+1
		lda	addr_max+2
		and	zp_addr+2
		sta	zp_addr+2
		rts



jimwrite:
		jsr	jimaddr
		lda	zp_data
		ldx	zp_addr+0
		sta	JIM,X
		rts

jimreadA:
		jsr	jimaddr
		ldx	zp_addr+0
		lda	JIM,X
		rts

jimcheck:
		jsr	jimaddr
		ldx	zp_addr+0
		lda	JIM,X
		cmp	zp_data
		bne	@s1
		rts
@s1:		inc	zp_fail
		pha

		jsr	OSNEWL
		jsr	PrintAddr
		jsr	PrintSpc
		jsr	PrintData

		M_PRINT str_read
		pla
		jmp	PrintHex



passfail:	lda	zp_fail
		beq	pass
		M_PRINT str_fail

contyn:	
		ldx	#<str_continue
		ldy	#>str_continue
		jsr	PromptYN
		bne	exit
		rts

pass:		M_PRINT str_pass
		rts


exit:		M_PRINT str_exit
		brk


jimaddr:
;;		lda	dev_no
;;		sta	zp_mos_jimdevsave
;;		sta	fred_JIM_DEVNO
		lda	zp_addr+2
		sta	fred_JIM_PAGE_HI
		lda	zp_addr+1
		sta	fred_JIM_PAGE_LO
		rts

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
PrintData:	lda	zp_data
		jmp	PrintHex

PrintXY:	stx	zp_tmpptr
		sty	zp_tmpptr + 1
		ldy	#0
@lp:		lda	(zp_tmpptr),Y
		beq	@out
		jsr	OSASCI
		iny
		bne	@lp
@out:		rts


PromptYN:	jsr	PrintXY
		ldx	#<str_YN
		ldy	#>str_YN
		jsr	PrintXY
@1:		jsr	WaitKey
		bcs	PromptRTS
		and	#$DF
		cmp	#'Y'
		beq	PromptYes
		cmp	#'N'
		bne	@1
PromptNo:	ldx	#<strNo
		ldy	#>strNo
		jsr	PrintXY
		lda	#$FF
		clc
		rts
PromptYes:	ldx	#<strYes
		ldy	#>strYes
		jsr	PrintXY
		lda	#0
		clc
PromptRTS:	rts

Print13:	lda	#13
		jmp	OSWRCH

PrintSpc:	lda	#' '
		jmp	OSWRCH



WaitKey:	jsr	uart_rx
		cmp	#27
		beq	@esc
		clc
		rts
@esc:		M_PRINT str_Escape
		sec
		rts

;------------------------------------------------------------------------------
; Parsing
;------------------------------------------------------------------------------
SkipSpacesPTR:	lda	(zp_mos_txtptr),Y
		iny
		beq	@s
		cmp	#' '
		beq	SkipSpacesPTR
@s:		dey
		rts

ToUpper:	cmp	#'a'
		bcc	@1
		cmp	#'z'+1
		bcs	@1
		and	#$DF
@1:		rts

parseONOFF:	jsr	SkipSpacesPTR
		lda	(zp_mos_txtptr),Y
		jsr	ToUpper
		cmp	#'O'
		bne	ParseHexErr
		iny
		lda	(zp_mos_txtptr),Y
		jsr	ToUpper
		cmp	#'N'
		beq	parseONOFF_ON
		cmp	#'F'
		bne	ParseHexErr
		iny
		lda	(zp_mos_txtptr),Y
		jsr	ToUpper
		cmp	#'F'
		bne	ParseHexErr
		lda	#0
parseONOFF_ck:						; check for space or &D
		pha
		iny
		lda	(zp_mos_txtptr),Y
		cmp	#' '+1
		bcs	ParseHexErr		
		clc
		pla
		rts
parseONOFF_ON:	lda	#$FF
		bne	parseONOFF_ck


ParseHex:
		ldx	#$FF				; indicates first char
		jsr	zeroAcc
		jsr	SkipSpacesPTR
		cmp	#$D
		beq	ParseHexErr
ParseHexLp:	lda	(zp_mos_txtptr),Y
		iny
		jsr	ToUpper
		inx	
		beq	@1
		cmp	#'+'
		beq	ParseHexDone	
@1:		cmp	#' '+1
		bcc	ParseHexDone
		cmp	#'0'
		bcc	ParseHexErr
		cmp	#'9'+1
		bcs	ParseHexAlpha
		sec
		sbc	#'0'
ParseHexShAd:	jsr	asl4Acc				; multiply existing number by 16
		jsr	addAAcc				; add current digit
		jmp	ParseHexLp
ParseHexAlpha:	cmp	#'A'
		bcc	ParseHexErr
		cmp	#'F'+1
		bcs	ParseHexErr
		sbc	#'A'-11				; note carry clear 'A'-'F' => 10-15
		jmp	ParseHexShAd
ParseHexErr:	sec
		rts
ParseHexDone:	dey
		clc
		rts

;------------------------------------------------------------------------------
; Arith
;------------------------------------------------------------------------------
zeroAcc:	pha
		lda	#0
		sta	zp_trans_acc
		sta	zp_trans_acc + 1
		sta	zp_trans_acc + 2
		sta	zp_trans_acc + 3
		pla
		rts

asl4Acc:
		pha
		txa
		pha
		ldx	#4
@1:		asl	zp_trans_acc + 0
		rol	zp_trans_acc + 1
		rol	zp_trans_acc + 2
		rol	zp_trans_acc + 3
		dex
		bne	@1
		pla
		tax
		pla
		rts

addAAcc:
		pha
		clc
		adc	zp_trans_acc + 0
		sta	zp_trans_acc + 0
		bcc	@1
		inc	zp_trans_acc + 1
		bne	@1
		inc	zp_trans_acc + 2
		bne	@1
		inc	zp_trans_acc + 3
@1:		pla
		rts


OSASCI:		cmp	#$0d		; OSASCI output a byte to VDU stream expanding
		bne	OSWRCH		; carriage returns (&0D) to LF/CR (&0A,&0D)
OSNEWL:		lda	#$0a		; OSNEWL output a CR/LF to VDU stream
		jsr	OSWRCH		; Outputs A followed by CR to VDU stream
		lda	#$0d
OSWRCH:
uart_tx:	bit	UART_STAT
		bvs	uart_tx
		sta	UART_DAT
		rts


uart_rx:	bit	UART_STAT
		bpl	uart_rx
		lda	UART_DAT
		rts



str_TestDataLine:	.byte	"Testing data lines", $D, 0
str_TestW1:		.byte	"Walking 1's", 0
str_TestW0:		.byte	"Walking 0's", 0
str_TestS1:		.byte	"Shifting 1's", 0
str_TestS0:		.byte	"Shifting 0's", 0
str_TestAddrLine:	.byte	"Testing address lines", $D, 0
str_Writing:		.byte	"Writing ", 0
str_At:			.byte	" at ", 0
str_Init:		.byte	"JIM page-wide memory test", $D, 0
str_OK:			.byte	$D, "OK.", $D, 0
str_YN:			.byte	" (Y/N)?",0
strErrsDet:		.byte	" errors detected", 0
strNo:			.byte	"No", $D, 0
strYes:			.byte	"Yes", $D, 0
str_notequal:		.byte	"<>",0
str_pass:		.byte	" - PASS", 13, 0
str_fail:		.byte	13, "FAIL!", 13, 0
str_continue:		.byte	"Continue?", 0
str_read:		.byte	" failed, read ", 0 
str_warning_dev:	.byte	"Warning: device not found ", 0
str_panic:		.byte	"WARNING: This will corrupt all memory in the specified range", 13, 0
str_SoakPass:		.byte	"Pass, soak test #",0
str_Escape:		.byte   "Escape", 0
str_exit:		.byte   "Exit", 0

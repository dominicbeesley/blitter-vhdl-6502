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

		.include 	"p20k.inc"

.macro          M_PRINT addr
		ldx	#<addr
		ldy	#>addr
		jsr	PrintXY
.endmacro

.macro		M_ADDR 	addr
		lda	#.bankbyte(addr)
		sta	zp_addr+2
		lda	#.hibyte(addr)
		sta	zp_addr+1
		lda	#.lobyte(addr)
		sta	zp_addr+0
.endmacro

FLASHBASE =	$800000

		.ZEROPAGE
zp_tmpptr:	.res	2
zp_addr:	.res	3
zp_data:	.res	1
zp_fail:	.res	1
zp_len:		.res	3
zp_curlen:	.res	1
zp_cksum:	.res	1
zp_src_ptr:	.res	2

zp_trans_acc:	.res	4



zp_mos_txtptr:	.res	2

		.BSS
addr_max:	.res	3
flag_soak:	.res	1
flag_soak_ctr:	.res	4
		

		.CODE
;==============================================================================
; M A I N
;==============================================================================

		lda	#DEVNO_C20K
		sta	fred_JIM_DEVNO

main_menu:	M_PRINT	str_menu

		jsr	ReadLine
		bcs	main_menu

		lda	textbuf
		and	#$DF
		cmp	#'R'
		bne	@sk_mR
		jmp	doREAD
@sk_mR:		cmp	#'P'
		bne	@sk_mP
		jmp	doPROG
@sk_mP:
		; drop through unrecognized
		jmp	 main_menu



ErrBadHex:	M_PRINT str_BadHex
		jmp	 main_menu

;==============================================================================
; T E S T
;==============================================================================

doPROG:		M_PRINT	str_Prog
		
		ldx	#<textbuf
		stx	zp_mos_txtptr
		ldy	#>textbuf
		sty	zp_mos_txtptr+1
		ldy	#1
		jsr	ParseHex
		bcc	@ok_start
		jmp	ErrBadHex
@ok_start:	jsr	acc2Addr
		jsr	ParseHex
		bcc	@ok_len
		jmp	ErrBadHex
@ok_len:	jsr	acc2Len
		lda	#$00			; point at buffer starting at local 0x1000
		sta	zp_src_ptr
		lda	#$10
		sta	zp_src_ptr+1
@prog_loop:	jsr	PrintAddr
		jsr	OSNEWL
		; length to program in X 
		ldx	#$80
		lda	zp_len+1
		ora	zp_len+2
		bne	@lensk3
		lda	zp_len
		bne	@lensk1
		jmp	main_menu
@lensk1:	bmi	@lensk3
		tax
@lensk3:	; check for page alignment
		clc
		txa
		adc	zp_addr
		bcc	@lensk2
		lda	zp_addr
		eor	#$FF
		tax
		inx
@lensk2:	stx	zp_curlen
		stx	zp_cksum		; save length for later add
		ldy	#0
		ldx	zp_addr
		lda	zp_addr+2
		bmi	@prog_flash
		; RAM program
		jsr	jimaddr
@rplp:		lda	(zp_src_ptr),Y
		sta	JIM,X
		iny
		inx
		dec	zp_curlen
		bne	@rplp

@uppaddr:	lda	zp_cksum
		jsr	addAAddr
		clc
		lda	zp_cksum
		adc	zp_src_ptr
		sta	zp_src_ptr
		lda	#0
		adc	zp_src_ptr+1
		sta	zp_src_ptr+1

		sec
		lda	zp_len
		sbc	zp_cksum
		sta	zp_len
		lda	zp_len+1
		sbc	#0
		sta	zp_len+1
		lda	zp_len+2
		sbc	#0
		sta	zp_len+2

		jmp	@prog_loop


@prog_flash:	lda	#$A0			; write byte command
		jsr	flash_cmd
		jsr	jimaddr
		lda	(zp_src_ptr),Y
		sta	JIM,X
@wlp:		lda	JIM,X
		eor	JIM,X
		bne	@wlp

		lda	(zp_src_ptr),Y
		eor	JIM,X
		beq	@okv
		jsr	pushAddr
		stx	zp_addr
		jsr	PrintAddr
		lda	#'!'
		jsr	uart_tx
		lda	JIM,X
		jsr	PrintHex
		lda	#'!'
		jsr	uart_tx
		lda	(zp_src_ptr),Y
		jsr	PrintHex
		jsr	OSNEWL
		jmp	main_menu

@okv:		iny
		inx
		dec	zp_curlen
		bne	@prog_flash
		jmp	@uppaddr


flash_prog_byte:pha
		lda	#$A0
		jsr	flash_cmd
		pla
		jsr	jimwriteA
		; todo: check toggle bit?
		jmp	main_menu


;==============================================================================
; R E A D   M E M O R Y
;==============================================================================
doREAD:		ldx	#<textbuf
		stx	zp_mos_txtptr
		ldy	#>textbuf
		sty	zp_mos_txtptr+1
		ldy	#1
		jsr	ParseHex
		bcc	@ok_start
		jmp	ErrBadHex
@ok_start:	jsr	acc2Addr
		jsr	ParseHex
		bcc	@ok_len
		jmp	ErrBadHex
@ok_len:	jsr	acc2Len
@rd_lp:		ldx	#$20
		lda	zp_len+1
		ora	zp_len+2
		bne	@go20		; if >= $100 start
		lda	zp_len+0
		beq	@end
		cmp	#$20
		bcs	@go20		; if >= 40 start
		tax
@go20:		; now check to see if this will cross a page boundary
		clc
		txa
		adc	zp_addr
		bcc	@go
		; it does so set length to remainder
		lda	zp_addr
		eor	#$FF
		tax
		inx
@go:		stx	zp_curlen
		ldy	#0
		sty	zp_cksum
		lda	#'S'
		jsr	OSWRCH
		lda	#'2'
		jsr	OSWRCH
		lda	zp_curlen
		clc
		adc	#4			; add 4 for addr, checksum
		jsr	PrintHex
		jsr	PrintAddr
		jsr	jimaddr
		ldy	zp_addr+0
@rd_lp2:	lda	JIM,Y
		iny
		jsr	PrintHex
		dex
		bne	@rd_lp2
		lda	zp_cksum
		eor	#$FF
		jsr	PrintHex
		jsr	OSNEWL
		lda	zp_curlen
		jsr	subALen
		lda	zp_curlen
		jsr	addAAddr
		jmp	@rd_lp

@end:		jsr	OSNEWL
		jmp	main_menu



ReadLine:	ldx	#0		
		stx	textptr
@rllp:		
		jsr	uart_rx
		cmp	#27
		beq	@esc
		ldx	textptr
		bne	@nospck
		cmp	#32
		beq	@rllp
@nospck:	cmp	#13
		beq	@cr
		cmp	#32
		bcc	@rllp
@cr:		jsr	uart_tx
		ldx	textptr
		sta	textbuf,X
		inx	
		bne	@skdec
		dex
@skdec:		stx	textptr
		cmp	#13
		bne	@rllp
		jsr	OSNEWL
		clc
		rts

@esc:		M_PRINT str_Escape
		sec
		rts

;----------------------------------------------------------------------

flash_cmd:	jsr	pushAddr
		pha
		jsr	jimwrite5522
		M_ADDR	FLASHBASE + $5555
		pla
		jsr	jimwriteA
		jsr	popAddr
		rts
		


jimwrite5555_AA:M_ADDR	FLASHBASE + $5555
		lda	#$AA
		bne	jimwriteA

jimwrite5522:	jsr	jimwrite5555_AA
		; fall through
jimwrite2AAA_55:M_ADDR	FLASHBASE + $2AAA
		lda	#$55
		bne	jimwriteA
jimwrite:
		lda	zp_data
jimwriteA:	pha
		txa
		pha
		jsr	jimaddr
		tsx
		lda	$102,X
		ldx	zp_addr+0
		sta	JIM,X
		pla
		tax
		pla
		rts

jimreadA:
		jsr	jimaddr
		ldx	zp_addr+0
		lda	JIM,X
		rts



jimaddr:
;;		lda	dev_no
;;		sta	zp_mos_jimdevsave
;;		sta	fred_JIM_DEVNO
		pha
		lda	zp_addr+2
		sta	fred_JIM_PAGE_HI
		lda	zp_addr+1
		sta	fred_JIM_PAGE_LO
		pla
		rts

; see http://www.obelisk.me.uk/6502/algorithms.html
PrintHex:
		pha                        
		clc
		adc	zp_cksum
		sta	zp_cksum		; update checksum
		pla
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
; Address
;------------------------------------------------------------------------------
acc2Addr:	lda	zp_trans_acc
		sta	zp_addr
		lda	zp_trans_acc + 1
		sta	zp_addr + 1
		lda	zp_trans_acc + 2
		sta	zp_addr + 2
		rts

acc2Len:	lda	zp_trans_acc
		sta	zp_len
		lda	zp_trans_acc + 1
		sta	zp_len + 1
		lda	zp_trans_acc + 2
		sta	zp_len + 2
		rts
subALen:	eor	#$FF
		sec
		adc	zp_len
		sta	zp_len
		lda	zp_len+1
		sbc	#0
		sta	zp_len+1
		lda	zp_len+2
		sbc	#0
		sta	zp_len+2
		rts
addAAddr:	clc
		adc	zp_addr
		sta	zp_addr
		lda	zp_addr+1
		adc	#0
		sta	zp_addr+1
		lda	zp_addr+2
		adc	#0
		sta	zp_addr+2
		rts

pushAddr:	pha
		pha
		pha		; reserve space

		pha
		txa
		pha
		
		; stack
		; + 6..7	rts
		; + 3..5	space
		; + 2		caller A
		; + 1		caller X

		tsx
		lda	$106,X
		sta	$103,X
		lda	$107,X
		sta	$104,X

		; stack
		; + 5..7	spare
		; + 3..4	rts
		; + 2		caller A
		; + 1		caller X

		lda	zp_addr
		sta	$105,X
		lda	zp_addr+1
		sta	$106,X
		lda	zp_addr+2
		sta	$107,X
		pla
		tax
		pla
		rts


		; stack on entry to popAddr
		; + 3..5	pushed addr
		; + 1..2	rts
popAddr:	pha
		txa
		pha

		; + 5..7	pushed addr
		; + 3..4	rts
		; + 2		A
		; + 1		X

		tsx
		lda	$105,X
		sta	zp_addr
		lda	$106,X
		sta	zp_addr+1
		lda	$107,X
		sta	zp_addr+2

		lda	$104,X
		sta	$107,X
		lda	$103,X
		sta	$106,X
		lda	$102,X
		sta	$105,X

		; + 6..7	rts
		; + 5		A
		; + 3..4	-
		; + 2		A
		; + 1		X

		pla
		tax
		pla
		pla
		pla
		pla
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

		.rodata
str_menu:	.byte	"FlashProg",13,10
		.byte	"---------",13,10
		.byte	"Menu:",13,10
		.byte   " (R)EAD <addr> <len>", 13,10
		.byte   " (P)ROG <addr> <len>", 13, 10
		.byte 	0

str_Prog:	.byte	"Send SRECS...",13,10,13,10,0

str_Escape:	.byte   "Escape", 0
str_YN:		.byte	" (Y/N)?",0
strNo:		.byte	"No", $D, 0
strYes:		.byte	"Yes", $D, 0

str_BadHex:	.byte	"Bad Hex", 13, 10, 0
		.data
textbuf:	.res	256
textptr:	.res	1

		.end

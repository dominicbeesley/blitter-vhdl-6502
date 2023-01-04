MACH_BEEB	EQU 1
CPU_6809	EQU 1

		include "includes/hardware.inc"
		include "includes/common.inc"
		include "includes/mosrom.inc"

		CODE
		setdp	$0


;---------------------------------------------------------------------------------------------------
; MOS ROM
;---------------------------------------------------------------------------------------------------
		ORG	$C000


		; this is the swmos test code it is copied to the swmos area and exec'd
swmos_test	lda	#1
		sta	$FE08
		lda	#2
		sta	$FE08
		lda	#$22
		sta	$FE21
		nop
		nop
		rts
swmos_test_end

		; this is copied to bottom of stack before exec, as when we trigger
		; the switch this rom will be paged out!
swmos_test_call lda	#1
		sta	$FE31
		jsr	swmos_test			; this should be running in SWMOS ram!
		lda	#0
		sta	$FE31				; back to normal and jim off!
		rts
swmos_test_call_end

test_blit_data
		fcb	%01111011
		fcb	0,23,45,67,89,123,33,255
test_blit_data_end

blit_regs
		fcb	$1F				; BLTCON0 - execA,B,C,D,E
		fcb	$CA				; A&B | /A&C
		fcb	7				; WIDTH
		fcb	0				; HEIGHT
		fcb	$0				; SHIFT
		fcb	$FF				; mask first
		fcb	$FF				; mask last
		fcb	$00				; data A
		fcb	$00
		fdb	$0000				; addr A
		fcb	$00				; data B
		fcb	$00
		fdb	$0001				; addr B
		fcb	$FF
		fdb	$3000				; addr C
		fcb	$FF
		fdb	$3000				; addr D
		fcb	$01
		fdb	$0000				; addr E
		fdb	$0001				; stride A
		fdb	$0008				; stride B
		fdb	640				; stride C
		fdb	640				; stride D


mos_handle_res
		lds	#STACKTOP

		lda	#$0C
		sta	$FE31

		ldx	#$1000
		ldb	#4
		lda	#0
1		sta	,X+
		inca
		decb
		bpl	1B


		ldx	#$1000
		ldb	#4
1		lda	,X+
		decb
		bpl	1B


		; quick 1MHz tests

		sta	$FC00
		sta	$FC01
		sta	$FC02
		sta	$FC03
		sta	$FC04
		sta	$FC05


		lda	#JIM_DEVNO_BLITTER
		sta	fred_JIM_DEVNO

		lda	#JIM_DEVNO_BLITTER
		sta	fred_JIM_DEVNO
		ldx	#jim_page_DMAC
		stx	fred_JIM_PAGE_HI

		; test BBC slow bus bodge
		sta	sheila_SYSVIA_orb
		lda	sheila_SYSVIA_ora
		sta	sheila_SYSVIA_orb
		sta	sheila_SYSVIA_orb




		; DMAC step normal test
		clr	jim_DMAC_DMA_SEL
		lda	#$FF
		sta	jim_DMAC_DMA_SRC_ADDR
		sta	jim_DMAC_DMA_DEST_ADDR
		ldx	#$3000
		stx	jim_DMAC_DMA_SRC_ADDR+1
		ldx	#$4000
		stx	jim_DMAC_DMA_DEST_ADDR+1
		ldx	#10
		stx	jim_DMAC_DMA_COUNT
		lda	#DMACTL2_SZ_WORD
		sta	jim_DMAC_DMA_CTL2
		lda	#DMACTL_ACT+DMACTL_HALT+DMACTL_STEP_DEST_UP+DMACTL_STEP_SRC_NONE+DMACTL_EXTEND
		sta	jim_DMAC_DMA_CTL



		; line drawing test
		;============================
		; set start point address
		lda	#$FF
		sta	jim_DMAC_ADDR_C
		sta	jim_DMAC_ADDR_D
		ldx	#$3200
		stx	jim_DMAC_ADDR_C+1
		stx	jim_DMAC_ADDR_D+1
		; set start point pixel mask and colour
		sta	jim_DMAC_DATA_B			; colour 1bpp white
		lda	#$10				; 8bpp left middle pixel
		sta	jim_DMAC_DATA_A
		; set major length
		ldx	#3
		stx	jim_DMAC_WIDTH			; 16 bits!
		; set slope
		ldd	#30				; major length
		std	jim_DMAC_ADDR_B+1
		lsra
		rorb
		std	jim_DMAC_ADDR_A+1		; initial error accumulator value
		ldd	#10
		std	jim_DMAC_STRIDE_A

		;set func gen to be plot B masked by A
		lda	#$CA				; B masked by A
		sta	jim_DMAC_FUNCGEN

		; set bltcon 0
		lda	#BLITCON_EXEC_C + BLITCON_EXEC_D
		sta	jim_DMAC_BLITCON
		; set bltcon 1 - right/down
		lda	#BLITCON_ACT_ACT + BLITCON_ACT_CELL + BLITCON_ACT_LINE
		sta	jim_DMAC_BLITCON

		; quick DMAC test SYS to CHIP
		clr	jim_DMAC_DMA_SEL

		clr	jim_DMAC_DMA_DEST_ADDR
		lda	#$FF
		sta	jim_DMAC_DMA_SRC_ADDR
		ldx	#test_blit_data
		stx	jim_DMAC_DMA_SRC_ADDR + 1
		ldy	#0
		sty	jim_DMAC_DMA_DEST_ADDR + 1

		ldx	#test_blit_data_end-test_blit_data-1
		stx	jim_DMAC_DMA_COUNT
		lda	#$95
		sta	jim_DMAC_DMA_CTL


		; test running mos from SWMOS ram area
		; copy some code to swmos via JIM - must be at start of ROM and be < 256 bytes
		ldd	#$7F00				; swmostest is at slot #8 i.e. $02 0000
		std	fred_JIM_PAGE_HI
		ldx	#swmos_test
		ldy	#$FD00
		ldb	#swmos_test_end-swmos_test
1		lda	,X+
		sta	,Y+
		decb
		bpl	1B

		ldx	#swmos_test_call
		ldy	#$100
		ldb	#swmos_test_call_end-swmos_test_call
1		lda	,X+
		sta	,Y+
		decb
		bpl	1B

		jsr	$100


		ldd	#$5AA5
		std	$FE00
		std	$FE00
		std	$FE00

		lda	$FC00
		lda	$FC00
		lda	$FC00
		lda	$FC00
		lda	$FC00

		lda	#0
		ldx	#$3000
1		sta	,x+
		inca
		cmpa	#11
		bne	1B



		; quick BLIT test A/B from $00 0000
		; D/C to / from $FF 3000
		; E to $01 0000


		ldx	#blit_regs
		ldy	#jim_DMAC_BLITCON
		ldb	#32
1		lda	,X+
		sta	,Y+
		decb
		bne	1B
		lda	#$E0
		sta	jim_DMAC_BLITCON		; exec, cell, 4bpp




		lda	#$FF
		sta	$FEFE
1		jmp	1B






		ORG	REMAPPED_HW_VECTORS
XRESV		FDB	mos_handle_div0	; $FFF0   ; Hardware vectors, paged in to $F7Fx from $FFFx
XSWI3V		FDB	mos_handle_swi3	; $FFF2		; on 6809 we use this instead of 6502 BRK
XSWI2V		FDB	mos_handle_irq	; $FFF4
XFIRQV		FDB	mos_handle_irq	; $FFF6
XIRQV		FDB	mos_handle_irq	; $FFF8
XSWIV		FDB	mos_handle_swi	; $FFFA
XNMIV		FDB	mos_handle_nmi	; $FFFC
XRESETV		FDB	mos_handle_res	; $FFFE

mos_handle_div0
		jmp	mos_handle_div0
mos_handle_swi3
		rti
mos_handle_swi
		rti
mos_handle_irq
		rti
mos_handle_nmi
		rti

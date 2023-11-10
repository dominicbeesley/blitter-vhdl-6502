; (c) Dossytronics 2017
; test harness ROM for VHDL testbench for MEMC mk2
; makes a 4k ROM

		.setcpu "6502X"

		.include	"common.inc"
		.include	"hw.inc"

vec_nmi		:=	$D00

		.ZEROPAGE
ZP_PTR:		.RES 2

		.CODE

mos_handle_res:
		cld
		sei
		ldx	#$FF
		txs

		; copy fast prog to RAM
		ldx	#test_fast_prg_len-1
@l1:		lda	test_fast_prg, X
		sta	$400,X
		dex
		bpl	@l1

		jsr	$400

HERE:		jmp	HERE


test_fast_prg:	ldx	#5
@lp:		txa
		sta	$100,X
		dex
		bne	@lp
		rts
test_fast_prg_len := *-test_fast_prg

mos_handle_irq:
		rti

		.SEGMENT "VECTORS"
hanmi:  .addr   vec_nmi                         ; FFFA 00 0D                    ..
hares:  .addr   mos_handle_res                  ; FFFC CD D9                    ..
hairq:  .addr   mos_handle_irq                  ; FFFE 1C DC                    ..

		.END

		.area	CODE (CON, ABS)

		.globl	font_data

handle_res:	di
		ld	sp, 0x3000


		; enable local jim

		ld	a,#0xD1
		ld	(0xFCFF),a
		ld	a,#0xFC
		ld	(0xFCFE),a
		ld	a,#0xFE
		ld	(0xFCFD),a

		ld	a,(0xFCFF)
		out	(0x8F), a
		in	a, (0x8F)

		; cls
		ld	hl, 0xB000
		ld	de, 0xB001
		ld	a, 0
		ld	(hl),a
		ld	bc, 0x4000-1
		ldir

		ld	hl, 0xC000
		ld	(scr_ptr), hl
		ld	hl, message

str_loop:	ld	a, (hl)
		or	a
		jr	Z, str_done
		call	scr_char
		inc	hl
		jr	str_loop
str_done:	jr	str_done

scr_char:	push	af
		push	bc
		push	hl
		push	de

		and	#127
		sub	#32

		ld	h,0
		ld	l,a
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	de,#font_data
		add	hl,de
		ld	de,(scr_ptr)
		ld	bc,#8
		ldir
		ld	(scr_ptr),de
		pop	de
		pop	hl
		pop	bc
		pop	af
		ret


message:	.asciz	"Hello Stardot Z80!"
scr_ptr:	.rmb 2

		.area   CODE (CON, ABS)

		.globl	font_data

SCREEN_BASE	= 0xA000
SCREEN_LEN	= 0x4000

handle_res3:	di
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
		ld	hl, SCREEN_BASE
		ld	de, SCREEN_BASE+1
		ld	a, 0
		ld	(hl),a
		ld	bc, SCREEN_LEN-1
		ldir

		ld	hl, SCREEN_BASE + 640 * 5
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


		.area   CODE_VEC (CON, ABS)
handle_res:

		; this area contains boot code and is mapped read-only to address 00xx in the CPU during boot
		; until the blitter FCFF address is written with $D1, writes still write memory at 00 0000
		; normally one would set up the low memory with interrupt vectors etc before switching modes

		jp	handle_res2

handle_res2:	; we are now running in ROM and can disable the boot mapping by writing to FCFF

		ld	a,#0xD1
		ld	(0xFCFF),a

		jp	handle_res3



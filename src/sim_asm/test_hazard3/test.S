

TEST_PROG = 0x10000



start:

		addi 	sp,zero,0x200		// setup a MOSsy stack

		li		a0, 0xdeadbeef
		li		a1, 0x1234

		sw		a0, 8(a1)			// write deadbeef => 123C 
		sh		a0, 2(a1)			// write beef     => 1236
		sh		a0, 2(a1)			// write beef     => 1236
		sb		a0, 5(a1)			// write ef       => 1239
		
		lb		a0, 8(a1)			// read  ef		  => 123C
		sb		a0, 0(a1)			// write ef		  => 1234
		lb		a0, 9(a1)			// 
		sb		a0, 1(a1)			//
		lb		a0, 10(a1)			//
		sb		a0, 2(a1)			//
		lb		a0, 11(a1)			//
		sb		a0, 3(a1)			//

		lw		a0, 0(a1)
		sw		a0, 12(a1)

		
		la		a0, TEST_PROG
		la		a1, test_progr
		la		a3, test_progr_end
lp:		lh		a2, 0(a1)
		sh		a2, 0(a0)
		addi	a1,a1,2
		addi	a0,a0,2
		blt		a1,a3,lp

		la		a0, TEST_PROG
		la		ra, c
		jr		a0
c:
		c.nop
		ecall

here:	j here

		.align(4)
handleirq:

there:

		sw	a0,12(sp)
		sw	a1,4(sp)

		lw  a2, 12(sp)
		lw  a3, 4(sp)


		j	there

test_progr:
		c.nop
		c.nop
		li	a0, 12
		li  a1, 13
		la	a2, there

		ret
test_progr_end:

		.section reset, "x", @progbits
reset_hw:
j		start
		.section irq, "x", @progbits
irq_hw:
j		handleirq



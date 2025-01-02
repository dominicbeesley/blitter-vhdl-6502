

TEST_PROG = 0x10000


#include "custom_ops.S"

start:
//		picorv32_waitirq_insn(zero)
		picorv32_maskirq_insn(zero, zero)

		addi 	sp,zero,0x200		// setup a MOSsy stack
		
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
		picorv32_getq_insn(t0, q1);
		andi t0,t0,~2
		picorv32_setq_insn(q1, t0);
		la	t0, there		
		picorv32_setq_insn(q0, t0);
		c.nop
		picorv32_retirq_insn();
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



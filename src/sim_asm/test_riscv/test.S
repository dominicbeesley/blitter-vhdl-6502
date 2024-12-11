



#include "custom_ops.S"

start:
//		picorv32_waitirq_insn(zero)
		picorv32_maskirq_insn(zero, zero)

		addi 	sp,zero,0x200		// setup a MOSsy stack
		
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


		j	there

		.section .data
splash:
		.incbin "splash.mo7"

		.section reset, "x", @progbits
reset_hw:
j		start
		.section irq, "x", @progbits
irq_hw:
j		handleirq



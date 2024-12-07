



#include "custom_ops.S"

start:
//		picorv32_waitirq_insn(zero)
		picorv32_maskirq_insn(zero, zero)

		addi 	sp,zero,0x200		// setup a MOSsy stack
		
		ecall

here:	j here


handleirq:
		jmp	handleirq

		.section .data
splash:
		.incbin "splash.mo7"

		.section reset, "x", @progbits
reset_hw:
j		start
		.section irq, "x", @progbits
irq_hw:
j		handleirq



		
		

		.org 0xC000



handle_res:	
		lds	#0x100

		ldx	#10
llopa:		dex
		bne	llopa

loop:
		inca
		staa	0
		ldab	0
		swi
		bra	loop


handle_swi:	ldx	2
		inx
		stx	2
		rti


		.org 0x3FF8
hw_irq:		.word	handle_res
hw_swi:		.word	handle_swi
hw_nmi:		.word	handle_res
hw_res:		.word	handle_res
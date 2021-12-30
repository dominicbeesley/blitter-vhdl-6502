		
		

		.org 0xC000



handle_res:	
		inca
		staa	0
		ldab	0
		jmp	handle_res



		.org 0x3FF8
hw_irq:		.word	handle_res
hw_swi:		.word	handle_res
hw_nmi:		.word	handle_res
hw_res:		.word	handle_res
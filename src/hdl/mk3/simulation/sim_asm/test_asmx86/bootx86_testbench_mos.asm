		
		cpu 186

		
		org 0xC000


		section TEXT

handle_res:	
	

handle_res_lcl:
		jmp	handle_res_lcl
		jmp	handle_res_lcl
		jmp	handle_res_lcl
		jmp	handle_res_lcl
		jmp	handle_res_lcl
		jmp	handle_res_lcl
		jmp	handle_res_lcl
		jmp	handle_res_lcl
		jmp	handle_res_lcl
		jmp	handle_res_lcl
		jmp	handle_res_lcl


x:
		TIMES 0x3FF0-($-$$) db 0

		jmp 	0FC00h:0000h

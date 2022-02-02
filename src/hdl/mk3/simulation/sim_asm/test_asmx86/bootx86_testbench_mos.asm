		
		cpu 186

		

		org 0C000h

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

		jmp 	handle_res

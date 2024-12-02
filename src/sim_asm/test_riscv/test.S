
		.section .data
splash:
		.incbin "splash.mo7"


start:

		addi 	sp,zero,0x200		// setup a MOSsy stack
		
		la	t0, splash		// source
		la	t1, 0xFFFF7C00		// dest
		li	t2, 0xFFFF8000		// dest end

		//copy loop
lp:
		lb	t3,0(t0)
		sb	t3,0(t1)
		addi	t0,t0,1
		addi	t1,t1,1
		bne	t1,t2,lp




		.section reset, "x", @progbits
reset_hw:
j		start
		.section irq, "x", @progbits
irq_hw:
beq		x0,x0,irq_hw



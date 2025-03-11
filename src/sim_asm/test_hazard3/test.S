
#define hazard3_csr_meiea      0xbe0 // External interrupt pending array
#define hazard3_csr_meipa      0xbe1 // External interrupt enable array
#define hazard3_csr_meifa      0xbe2 // External interrupt force array
#define hazard3_csr_meipra     0xbe3 // External interrupt priority array
#define hazard3_csr_meinext    0xbe4 // Next external interrupt
#define hazard3_csr_meicontext 0xbe5 // External interrupt context register


TEST_PROG = 0x10000


start:

		addi 	sp,zero,0x200		// setup a MOSsy stack

		li		a0, 0x5A
		li		a1, 0xFFFF0000

		sb		a0,0(a1)


		// test some 1MHz access stuff

		li		a0, 0xA5
		sb		a0, 0xFFFFFCF0(zero)
		lb		a0, 0xFFFFFCF3(zero)
		lb		a2, 0(a1)
		sb		a0, 0xFFFFFCF0(zero)
		lb		a0, 0xFFFFFCF3(zero)

		
		// test interruptor

		li		a0, 0x10
		sb		a0, 0xFFFFFC40(zero)
		li		a0, 0x11
		sb		a0, 0xFFFFFC41(zero)


		// set up irq vectors stuff

		csrrs	a0, misa, x0
		sw		a0, 0(sp)

		la		a0, irqvecs + 1
		//la		a0, handle_trap			//NOT VECTORED!
		csrrw	x0, mtvec, a0

		// set up the H3 custom irq controller

		li	t0, (0xFF0<<16)|(0)
		csrrw	x0, hazard3_csr_meipra, t0

		li	t0, (7<<16)|(0)
		csrrs	x0, hazard3_csr_meiea, t0	// enable all external interrupts (debug, nmi, irq)


		li	t0, 1<<11
		csrrs	x0, mie, t0			// enable external interrupts
		csrrsi	x0, mstatus, 1<<3		// enable global interrupts



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
isr_external_irq:
  		// Set bit 1 when reading to clear+save mie.mtie and mie.msie
  		csrrsi 	a0, hazard3_csr_meicontext, 0x2
  		sw 		a0, 16(sp)
  		csrr 	a0, mstatus
  		sw 		a0, 20(sp)
  		j 		get_next_irq
dispatch_irq:
  		// Preemption priority was configured by meinext update, so enable preemption:
  		csrsi 	mstatus, 0x8
  		// meinext is pre-shifted by 2, so only an add is required to index table
  		la 		a1, _external_irq_table
  		add 	a1, a1, a0
  		jalr 	ra, a1
  		// Disable IRQs on returning so we can sample the next IRQ
  		csrci 	mstatus, 0x8
get_next_irq:
  		// Sample the current highest-priority active IRQ (left-shifted by 2) from
  		// meinext, and write 1 to the LSB to tell hardware to tell hw to update
  		// meicontext with the preemption priority (and IRQ number) of this IRQ
  		csrrsi 	a0, hazard3_csr_meinext, 0x1
  		// MSB will be set if there is no active IRQ at the current priority level
  		bgez 	a0, dispatch_irq
no_more_irqs:
  		// Restore saved context and return from handler
  		lw 		a0, 12(sp)
  		csrw 	mepc, a0
  		lw 		a0, 16(sp)
  		csrw 	hazard3_csr_meicontext, a0
  		lw 		a0, 20(sp)
  		csrw 	mstatus, a0
  		lw		ra, 0(sp)
  		lw 		a0, 4(sp)
  		lw 		a1, 8(sp)
  		addi	sp, sp, 24
  		mret

		.align(4)
_external_irq_table:
		j		service_irq
		.align(2)
		j		service_nmi
		.align(2)
service_nmi:
		sb		x0, 0xFFFFFC41(zero)
		ret

service_bad:
		j		service_bad

service_irq:

		//some artificial delay to bump into with nmi
		li		a0, 50
si_l:	addi	a0, a0, -1
		bnez	a0, si_l

		sb		x0, 0xFFFFFC40(zero)
		ret
service_debug:
		j		service_debug

		.align(6)
handle_trap:
  		// Save caller saves and exception return state whilst IRQs are disabled.
  		// We can't be pre-empted during this time, but if a higher-priority IRQ
  		// arrives ("late arrival"), that will be the one displayed in meinext.
  		addi 	sp, sp, -24
  		sw		ra, 0(sp)
  		sw		a0, 4(sp)
  		sw		a1, 8(sp)
  		csrr 	a0, mepc
  		sw 		a0, 12(sp)
		csrr	a0, mcause
		bgez	a0, handle_soft_trap
		li		a1, 0x80000000
		xor		a0, a0, a1
		li		a1, 11
		beq		a0, a1, isr_external_irq

		// unexpected interrupt (timer or software)
unexint:
		j		unexint

		.align(2)
handle_soft_trap:

		j		handle_soft_trap

test_progr:
		c.nop
		c.nop
		li	a0, 12
		li  a1, 13

		ret
test_progr_end:

		.align(8)
irqvecs:
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)
		j	handle_trap
		.align(2)


		.section reset, "x", @progbits
reset_hw:
		j		start
		.section irq, "x", @progbits
irq_hw:
		j		handle_trap



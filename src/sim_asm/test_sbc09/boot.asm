MACH_BEEB	EQU 1
CPU_6809	EQU 1

		include "includes/hardware.inc"
		include "includes/mmu.inc"

		CODE
		setdp	$0

; "Supervisor DP"

		ORG	0
DP_SAVE_SYS_STACK		RMB	2
DP_SAVE_USER_STACK	RMB	2
DP_TEST_SVC_CTR		RMB 	1

; "User DP"

		ORG	0
DP_USER_TEST_CTR		RMB	1



;---------------------------------------------------------------------------------------------------
; MOS ROM
;---------------------------------------------------------------------------------------------------
		ORG	$C000

handle_res	clra
		tfr	a,dp
		lds	#$8000

		clr	$0000
		clr	$1000
		clr	$B000

		inc	$0000
		inc	$1000
		inc	$B000

		; set up task 0 to have SYS at top (this code), ram 0-BFFF

		lda 	#0
		sta	MMU_ACC_KEY
		lda	#$80
		sta	MMU_MAP+MMU_16_0
		lda	#$82
		sta	MMU_MAP+MMU_16_4
		lda	#$84
		sta	MMU_MAP+MMU_16_8
		lda	#$C6
		sta	MMU_MAP+MMU_16_C

		lda 	#MMU_CTL_ENMMU|MMU_CTL_PROT
		sta	MMU_CTL

		; we should now be in map 0 with mmu enabled

		; Test mmu readback

		lda	MMU_CTL
		lda	MMU_ACC_KEY
		lda	MMU_TASK_KEY
		lda	MMU_MAP+MMU_16_0
		lda	MMU_MAP+MMU_16_4
		lda	MMU_MAP+MMU_16_8
		lda	MMU_MAP+MMU_16_C


		; set up task 2 to contain a user task which is all RAM 

		lda 	#2
		sta	MMU_ACC_KEY
		lda	#$86
		sta	MMU_MAP+MMU_16_0
		lda	#$88
		sta	MMU_MAP+MMU_16_4
		lda	#$8A
		sta	MMU_MAP+MMU_16_8
		lda	#$8C
		sta	MMU_MAP+MMU_16_C

		; page in task 2's buttom page at 4000-7FFF
		lda 	#0
		sta	MMU_ACC_KEY
		lda	#$86
		sta	MMU_MAP+MMU_16_4

		; copy user task to 1000 (5000)
		ldu 	#ut0_r
		ldy	#$5000
		ldx 	#ut0_end-ut0+1
1		lda 	,u+
		sta	,y+
		leax	-1,x
		bne 	1B

		; setup a phoney user stack
		lda	#0		; phoney CCR
		sta	$7ffd
		ldd 	#$1000
		std	$7ffe

		lda	#2
		sta	MMU_TASK_KEY	; set task 2 as task to swap to

		; poke at hardware location
		sta	$FE60


		orcc 	#$50		; disable interrupts as we will mess with stack		
		sts	DP_SAVE_SYS_STACK
		lds 	#$3ffd		; User stack!
		jmp	MMU_RTI


here		inc 	$0
		inc	$3FFF
		inc	$4000
		inc	$8000

		jmp	here



; user task 0
ut0_r
		ORG	$1000
		PUT	ut0_r
ut0
		ldx 	#3
1		inc 	DP_USER_TEST_CTR
		leax 	-1,X
		bne	1B
		swi3

		; poke at random hardware location to test hardware protection
		sta	$FE60

		jmp 	ut0

ut0_end

		ORG	ut0_r + ut0_end - ut0
		PUT	ut0_r + ut0_end - ut0





		ORG	REMAPPED_HW_VECTORS
XRESV		FDB	handle_div0	; $FFF0   ; Hardware vectors, paged in to $F7Fx from $FFFx
XSWI3V		FDB	handle_swi3	; $FFF2		; on 6809 we use this instead of 6502 BRK
XSWI2V		FDB	handle_irq	; $FFF4
XFIRQV		FDB	handle_irq	; $FFF6
XIRQV		FDB	handle_irq	; $FFF8
XSWIV		FDB	handle_swi	; $FFFA
XNMIV		FDB	handle_nmi	; $FFFC
XRESETV		FDB	handle_res	; $FFFE

handle_div0
		jmp	handle_div0
handle_swi3
		orcc	#$50			; disable interrupt while we adjust the 
						; stack - really we need a hardware solution
						; to this!

		clra
		tfr	a,dp

		sts	<DP_SAVE_USER_STACK
		lds	<DP_SAVE_SYS_STACK

		andcc 	#$AF			; interrupts back on

		inc 	<DP_TEST_SVC_CTR

		orcc	#$50			; disable interrupts while we put back user stack
		sts	<DP_SAVE_SYS_STACK
		lds	<DP_SAVE_USER_STACK	; put back user stack
		jmp 	MMU_RTI
handle_swi
		rti
handle_irq
		rti
handle_nmi
		rti



	.text

c_VIA:	.ualong	0xFFFFFE40
c_SYSMEM:.ualong  0xFFFF0000

reset:
	mov	r12,#0
	ldr	r0,[r12]


	ldr	r12,c_VIA
	strb	r0,[r12]
	ldrb	r0,[r12,#1]

	ldr	r12,c_SYSMEM
	mov	r0,#0xAA
	strb	r0,[r12]
	ldrb	r0,[r12,#1]

	mov	r0,#23
	mov	r2,#0x1000
lp2:	add	r2,r2,#4
	mov	r1,#3
lp:	add	r0,r0,r1
	strb	r0,[r2,r1]
	subs	r1,r1,#1
	bpl	lp
	ldr	r5,[r2]
	b	lp2


	.section "romvectors", "acrx"

	B	reset1			; reset
	subs	pc,lr,#4			; undefined
	subs	pc,lr,#4			; swi
	subs	pc,lr,#4			; prefetch abort
	subs	pc,lr,#4			; data abort
	subs	pc,lr,#4			; uk
	subs	pc,lr,#4			; irq
	subs	pc,lr,#4			; firq


reset1:	mov	r0,#2
	mov	r1,#0
rlp:	ldmia	r1,{r2,r3,r4,r5}
	stmia	r1!,{r2,r3,r4,r5}
	subs	r0,r0,#1
	bne	rlp

	mov	r12,#0xFFFFFCFF
	mov	r0,#0xD1
	strb	r0,[r12]
	b	reset



	.text

reset:
	mov	r0,#23
	mov	r2,#0x1000
lp2:	mov	r1,#3
lp:	add	r0,r0,r1
	subs	r1,r1,#1
	strb	r0,[r2,r1,lsl#3]
	bne	lp
	b	lp2


	.section "romvectors", "acrx"

	B	reset


		.macro	AE_WAIT	VM, HM, V, H
		.byte	$00 | ((VM & $1E0) >> 5) 
		.byte	((VM & $01F) << 3) | ((HM & $1C) >> 2)
		.byte	((HM & 3) << 6) | ((V & $1F8) >> 3)
		.byte	((V & $07) << 5) | ((H & $1F))
		.endmacro

		.macro	AE_SKIP	VM, HM, V, H
		.byte	$10 | ((VM & $1E0) >> 5) 
		.byte	((VM & $01F) << 3) | ((HM & $1C) >> 2)
		.byte	((HM & 3) << 6) | ((V & $1F8) >> 3)
		.byte	((V & $07) << 5) | ((H & $1F))
		.endmacro

		.macro	AE_MOVE16I b, h, D16
		.byte	$20 | (b & $0F)
		.byte	h
		.byte	>D16
		.byte	<D16
		.endmacro

		.macro	AE_MOVE16 b, h, D16
		.byte	$30 | (b & $0F)
		.byte	h
		.byte	>D16
		.byte	<D16
		.endmacro

		.macro	AE_MOVE	b, h, d
		.byte	$40 | (b & $0F)
		.byte	(h & $FF)
		.byte	(d & $FF)
		.endmacro

		.macro	AE_BRA	sym
		.local r
r	:=	sym - (*+3)
		.byte	$50 
		.byte	(r & $FF00) >> 8
		.byte	(r & $FF)
		.endmacro

		.macro	AE_BRAL p, sym
		.local r
r	:=	sym - (*+3)
		.byte	$58 | (p & $07)
		.byte	(r & $FF00) >> 8
		.byte	(r & $FF)
		.endmacro

		.macro	AE_MOVEP p, sym
		.local r
r	:=	sym - (*+3)
		.byte	$70 | (p & $07)
		.byte	(r & $FF00) >> 8
		.byte	(r & $FF)
		.endmacro

		.macro	AE_MOVEC c, imm
		.byte	$80 | (c & $07)
		.byte	imm
		.endmacro

		.macro	AE_PLAY	p, n
		.byte	$90 | (p & $07)
		.byte	n
		.endmacro

		.macro	AE_PLAY16 p, n
		.byte	$98 | (p & $07)
		.byte	n
		.endmacro

		.macro	AE_ADDC c, imm
		.byte	$A0 | (c & $7)
		.byte 	imm & $FF
		.endmacro

		.macro	AE_ADDP c, imm
		.byte	$A8 | (c & $7)
		.byte 	imm & $FF
		.endmacro

		.macro 	AE_MOVECC c1, c2
		.byte	$B0
		.byte	((c1 & $7) << 4) | (c2 & $7)
		.endmacro

		.macro 	AE_MOVEPP p1, p2
		.byte	$B1
		.byte	((p1 & $7) << 4) | (p2 & $7)
		.endmacro

		.macro	AE_SYNC
		.byte	$C1
		.endmacro

		.macro	AE_UNSYNC
		.byte	$C0
		.endmacro

		.macro	AE_RET	p
		.byte	$D8 | (p & $07)
		.endmacro

		.macro	AE_DSZ	c
		.byte	$E0 | (c & $07)
		.endmacro

		.macro 	AE_WAITH
		.byte	$F0
		.endmacro
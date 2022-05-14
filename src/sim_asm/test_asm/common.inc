
	.IFNDEF INC_COMMON

INC_COMMON	:=	1
		.MACRO	WORDBE	arg
		.byte	>(arg&$FFFF)
		.byte	<(arg&$FFFF)
		.ENDMACRO

		.MACRO	BANK	arg
		.byte	((arg >> 16)&$FF)
		.ENDMACRO

		.MACRO  BLADDR	arg
		BANK	arg
		WORDBE	arg
		.ENDMACRO
	.ENDIF



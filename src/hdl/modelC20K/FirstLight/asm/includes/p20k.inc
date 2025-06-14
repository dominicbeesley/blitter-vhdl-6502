

UART_BASE = $FE00
UART_STAT = UART_BASE + 0
UART_DAT  = UART_BASE + 1

UART_STAT_RXF = $80
UART_STAT_TXF = $40


JIM		:= $FD00

fred_JIM_PAGE_HI2		:=	$FCFC		; note ignored Blitter/Paula
fred_JIM_PAGE_HI		:=	$FCFD
fred_JIM_PAGE_LO		:=	$FCFE
fred_JIM_DEVNO			:=	$FCFF

PAGE_LEDS	:= $F000

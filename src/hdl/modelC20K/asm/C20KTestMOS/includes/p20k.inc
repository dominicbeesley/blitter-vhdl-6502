;***********************************************************************
;* SOFTWARE                                                            *
;***********************************************************************
; BLTCON is written in two passes with top bit clear i.e. not BLTCON_ACT_ACT
; the exec flags are first set
; then with top bit set the active flag, bit mode and cell flags are set
; BLTCON/ACT byte flags

BLITCON_ACT_ACT			:=	$80		; always set when setting act constants/execing  
BLITCON_ACT_CELL		:=	$40		; cell addressing used i.e. move one byte left adds 8 to address
							; moving one line down either adds 1 byte or STRIDE depending on whether 
							; line crosses an 8 line boundary
BLITCON_ACT_MODE_1BBP		:=	$00		; 1 bit per pixel mapping 2 colours
BLITCON_ACT_MODE_2BBP		:=	$10		; 2 bit per pixel mapping 4 colours
BLITCON_ACT_MODE_4BBP		:=	$20		; 4 bit per pixel mapping 16 colours
BLITCON_ACT_MODE_8BBP		:=	$30		; 8 bit per pixel mapping 256 colours
BLITCON_ACT_LINE		:=	$08		; draw a line
BLITCON_ACT_COLLISION		:=	$04		; gets reset for any non-zero D data (even in EXEC_D is clear)
BLITCON_ACT_WRAP		:=	$02		; wrap C/D addresses to fit between min/max

BLITCON_LINE_MAJOR_UPnRIGHT	:=	$10		; line draw major axis is up
BLITCON_LINE_MINOR_CCW		:=	$20		; minor axis is CCW to MAJOR i.e.:
							;  - left when maj up, up when maj right
							;  - otherwise, right when maj up, down when maj right

BLITCON_EXEC_A			:=	$01
BLITCON_EXEC_B			:=	$02
BLITCON_EXEC_C			:=	$04
BLITCON_EXEC_D			:=	$08
BLITCON_EXEC_E			:=	$10
BLITCON_CELL_B			:=	$20		; NEW

AERIS_CTL_ACT			:=	$80

; DMA controller control flags
DMACTL_ACT			:=	$80		; always set to initiate a transfer

DMACTL_EXTEND			:=	$20		; use extended functions from control2
DMACTL_HALT			:=	$10		; halt cpu during transfer
DMACTL_STEP_DEST_NONE		:=	$00		; do not step destination address
DMACTL_STEP_DEST_UP		:=	$04		; step destination up after transfer
DMACTL_STEP_DEST_DOWN		:=	$08		; step destination down after transfer
DMACTL_STEP_DEST_NOP		:=	$0C		; skip writes, do not increment address
DMACTL_STEP_SRC_NONE		:=	$00		; do not step destination address
DMACTL_STEP_SRC_UP		:=	$01		; step destination up after transfer
DMACTL_STEP_SRC_DOWN		:=	$02		; step destination down after transfer
DMACTL_STEP_SRC_NOP		:=	$03		; skip reads, do not incrememnt address

DMACTL2_IF			:=	$80		; interrupt occurred
DMACTL2_IE			:=	$02		; interrupt enable, interrupt after transfer
DMACTL2_SZ_BYTE			:=	$00
DMACTL2_SZ_WORD			:=	$04
DMACTL2_SZ_WORDSWAPDEST		:=	$08
DMACTL2_SZ_WORDSWAPSRC		:=	$0C
DMACTL2_PAUSE			:=	$01

; Sound Status / control bits
SND_CTL_ACT			:=	$80
SND_CTL_REPEAT			:=	$01


;;; NEW little-endian Word aligned API

CS_BLIT_base			:=	0	; base JIM offset
CS_BLIT_BLITCON_offs		:=	0
CS_BLIT_FUNCGEN_offs		:=	$1
CS_BLIT_MASK_FIRST_offs		:=	$2	; 
CS_BLIT_MASK_LAST_offs		:=	$3
CS_BLIT_WIDTH_offs		:=	$4	; 8 bit
CS_BLIT_HEIGHT_offs		:=	$5	; 8 bit 
CS_BLIT_SHIFT_A_offs		:=	$6	; shift for A data poking this will poke SHIFT_B
						; spare
CS_BLIT_STRIDE_A_offs		:=	$8	; 16 bit little endian
CS_BLIT_STRIDE_B_offs		:=	$A	; 16 bit little endian
CS_BLIT_STRIDE_C_offs		:=	$C	; 16 bit little endian - writing this also writes STRIDE_D for convenience
						; 16 spare
CS_BLIT_ADDR_A_offs		:=	$10	; 24 bit
CS_BLIT_DATA_A_offs		:=	$13
CS_BLIT_ADDR_B_offs		:=	$14	; 24 bit
CS_BLIT_DATA_B_offs		:=	$17
CS_BLIT_ADDR_C_offs		:=	$18	; 24 bit writing this also writes ADDR_D for convenience
CS_BLIT_DATA_C_offs		:=	$1B
CS_BLIT_ADDR_E_offs		:=	$1C
						; spare
CS_BLIT_ADDR_D_MIN_offs		:=	$20	; 24 bit
						; spare
CS_BLIT_ADDR_D_MAX_offs		:=	$24	; 24 bit
						; spare
CS_BLIT_STRIDE_D_offs		:=	$28	; 16 bit little endian
CS_BLIT_SHIFT_B_offs		:=	$2A	
						; spare
CS_BLIT_ADDR_D_offs		:=	$2C	; 24 bit


;;; NEW little-endian Word aligned API

CS_SND_base			:=      $80
CS_SND_SEL_offs			:=	$80
CS_SND_MA_VOL_offs		:=	$81
CS_SND_DATA_offs		:=	$82
CS_SND_PEAK_offs		:=	$83
CS_SND_REPOFF_offs		:=	$84
CS_SND_VOL_offs			:=	$86
CS_SND_STATUS_offs		:=	$87
CS_SND_LEN_offs			:=	$88
CS_SND_PERIOD_offs		:=	$8A
CS_SND_ADDR_offs		:=	$8C

;;; NEW little-endian Word aligned API

CS_DMA_base			:=      $90
CS_DMA_SRC_ADDR_offs		:=	$90
CS_DMA_DEST_ADDR_offs		:=	$94
CS_DMA_COUNT_offs		:=	$98
CS_DMA_DATA_offs		:=	$9A
CS_DMA_CTL_offs			:=	$9C
CS_DMA_CTL2_offs		:=	$9D
CS_DMA_PAUSE_VAL_offs		:=	$9E
CS_DMA_SEL_offs			:=	$9F



CS_AERIS_base			:=      $B0
CS_AERIS_CTL_offs		:=	$B0
CS_AERIS_PROGBASE_offs		:=	$B4
CS_AERIS_PC_offs		:=	$B8


CS_I2C_offs			:=	$D0

jim_page_CHIPSET		:=	$FEFE

jim_page_VERSION		:=	$FC00

jim_offs_VERSION_API_level	:=	$80
jim_offs_VERSION_Board_level	:=	$81
jim_offs_VERSION_API_sublevel	:=	$82
jim_offs_VERSION_cfg_bits	:=	$84
jim_offs_VERSION_cap_bits	:=	$88

jim_CS_BLIT_BLITCON		:= 	$FD00 + CS_BLIT_BLITCON_offs
jim_CS_BLIT_FUNCGEN		:= 	$FD00 + CS_BLIT_FUNCGEN_offs
jim_CS_BLIT_MASK_FIRST		:= 	$FD00 + CS_BLIT_MASK_FIRST_offs
jim_CS_BLIT_MASK_LAST		:= 	$FD00 + CS_BLIT_MASK_LAST_offs
jim_CS_BLIT_WIDTH		:= 	$FD00 + CS_BLIT_WIDTH_offs
jim_CS_BLIT_HEIGHT		:= 	$FD00 + CS_BLIT_HEIGHT_offs
jim_CS_BLIT_SHIFT_A		:= 	$FD00 + CS_BLIT_SHIFT_A_offs
jim_CS_BLIT_STRIDE_A		:= 	$FD00 + CS_BLIT_STRIDE_A_offs
jim_CS_BLIT_STRIDE_B		:= 	$FD00 + CS_BLIT_STRIDE_B_offs
jim_CS_BLIT_STRIDE_C		:= 	$FD00 + CS_BLIT_STRIDE_C_offs
jim_CS_BLIT_ADDR_A		:= 	$FD00 + CS_BLIT_ADDR_A_offs
jim_CS_BLIT_DATA_A		:= 	$FD00 + CS_BLIT_DATA_A_offs
jim_CS_BLIT_ADDR_B		:= 	$FD00 + CS_BLIT_ADDR_B_offs
jim_CS_BLIT_DATA_B		:= 	$FD00 + CS_BLIT_DATA_B_offs
jim_CS_BLIT_ADDR_C		:= 	$FD00 + CS_BLIT_ADDR_C_offs
jim_CS_BLIT_DATA_C		:= 	$FD00 + CS_BLIT_DATA_C_offs
jim_CS_BLIT_ADDR_E		:= 	$FD00 + CS_BLIT_ADDR_E_offs
jim_CS_BLIT_ADDR_D_MIN		:= 	$FD00 + CS_BLIT_ADDR_D_MIN_offs
jim_CS_BLIT_ADDR_D_MAX		:= 	$FD00 + CS_BLIT_ADDR_D_MAX_offs
jim_CS_BLIT_STRIDE_D		:= 	$FD00 + CS_BLIT_STRIDE_D_offs
jim_CS_BLIT_SHIFT_B		:= 	$FD00 + CS_BLIT_SHIFT_B_offs
jim_CS_BLIT_ADDR_D		:= 	$FD00 + CS_BLIT_ADDR_D_offs


jim_CS_SND_SEL			:= 	$FD00 + CS_SND_SEL_offs
jim_CS_SND_MA_VOL		:= 	$FD00 + CS_SND_MA_VOL_offs
jim_CS_SND_DATA			:= 	$FD00 + CS_SND_DATA_offs
jim_CS_SND_PEAK			:= 	$FD00 + CS_SND_PEAK_offs
jim_CS_SND_REPOFF		:= 	$FD00 + CS_SND_REPOFF_offs
jim_CS_SND_VOL			:= 	$FD00 + CS_SND_VOL_offs
jim_CS_SND_STATUS		:= 	$FD00 + CS_SND_STATUS_offs
jim_CS_SND_LEN			:= 	$FD00 + CS_SND_LEN_offs
jim_CS_SND_PERIOD		:= 	$FD00 + CS_SND_PERIOD_offs
jim_CS_SND_ADDR			:= 	$FD00 + CS_SND_ADDR_offs

jim_CS_DMA_SRC_ADDR		:=	$FD00 + CS_DMA_SRC_ADDR_offs
jim_CS_DMA_DEST_ADDR		:=	$FD00 + CS_DMA_DEST_ADDR_offs
jim_CS_DMA_COUNT		:=	$FD00 + CS_DMA_COUNT_offs
jim_CS_DMA_DATA			:=	$FD00 + CS_DMA_DATA_offs
jim_CS_DMA_CTL			:=	$FD00 + CS_DMA_CTL_offs
jim_CS_DMA_CTL2			:=	$FD00 + CS_DMA_CTL2_offs
jim_CS_DMA_PAUSE_VAL		:=	$FD00 + CS_DMA_PAUSE_VAL_offs
jim_CS_DMA_SEL			:=	$FD00 + CS_DMA_SEL_offs

jim_CS_AERIS_CTL		:=	$FD00 + CS_AERIS_CTL_offs
jim_CS_AERIS_PROGBASE		:=	$FD00 + CS_AERIS_PROGBASE_offs
jim_CS_AERIS_PPC		:=	$FD00 + CS_AERIS_PC_offs


jim_I2C_BASE			:= 	$FD00 + CS_I2C_offs
jim_I2C_STAT			:= 	jim_I2C_BASE
jim_I2C_DATA			:= 	jim_I2C_BASE + 1


;*************** 65816 24 bit addresses

A16_CS	:= jim_page_CHIPSET << 8

A16_CS_BLIT_FUNCGEN		:= 	A16_CS + CS_BLIT_FUNCGEN_offs
A16_CS_BLIT_MASK_FIRST		:= 	A16_CS + CS_BLIT_MASK_FIRST_offs
A16_CS_BLIT_MASK_LAST		:= 	A16_CS + CS_BLIT_MASK_LAST_offs
A16_CS_BLIT_WIDTH		:= 	A16_CS + CS_BLIT_WIDTH_offs
A16_CS_BLIT_HEIGHT		:= 	A16_CS + CS_BLIT_HEIGHT_offs
A16_CS_BLIT_SHIFT_A		:= 	A16_CS + CS_BLIT_SHIFT_A_offs
A16_CS_BLIT_STRIDE_A		:= 	A16_CS + CS_BLIT_STRIDE_A_offs
A16_CS_BLIT_STRIDE_B		:= 	A16_CS + CS_BLIT_STRIDE_B_offs
A16_CS_BLIT_STRIDE_C		:= 	A16_CS + CS_BLIT_STRIDE_C_offs
A16_CS_BLIT_ADDR_A		:= 	A16_CS + CS_BLIT_ADDR_A_offs
A16_CS_BLIT_DATA_A		:= 	A16_CS + CS_BLIT_DATA_A_offs
A16_CS_BLIT_ADDR_B		:= 	A16_CS + CS_BLIT_ADDR_B_offs
A16_CS_BLIT_DATA_B		:= 	A16_CS + CS_BLIT_DATA_B_offs
A16_CS_BLIT_ADDR_C		:= 	A16_CS + CS_BLIT_ADDR_C_offs
A16_CS_BLIT_DATA_C		:= 	A16_CS + CS_BLIT_DATA_C_offs
A16_CS_BLIT_ADDR_E		:= 	A16_CS + CS_BLIT_ADDR_E_offs
A16_CS_BLIT_ADDR_D_MIN		:= 	A16_CS + CS_BLIT_ADDR_D_MIN_offs
A16_CS_BLIT_ADDR_D_MAX		:= 	A16_CS + CS_BLIT_ADDR_D_MAX_offs
A16_CS_BLIT_STRIDE_D		:= 	A16_CS + CS_BLIT_STRIDE_D_offs
A16_CS_BLIT_SHIFT_B		:= 	A16_CS + CS_BLIT_SHIFT_B_offs
A16_CS_BLIT_ADDR_D		:= 	A16_CS + CS_BLIT_ADDR_D_offs


A16_CS_SND_SEL			:= 	A16_CS + CS_SND_SEL_offs
A16_CS_SND_MA_VOL		:= 	A16_CS + CS_SND_MA_VOL_offs
A16_CS_SND_DATA			:= 	A16_CS + CS_SND_DATA_offs
A16_CS_SND_PEAK			:= 	A16_CS + CS_SND_PEAK_offs
A16_CS_SND_REPOFF		:= 	A16_CS + CS_SND_REPOFF_offs
A16_CS_SND_VOL			:= 	A16_CS + CS_SND_VOL_offs
A16_CS_SND_STATUS		:= 	A16_CS + CS_SND_STATUS_offs
A16_CS_SND_LEN			:= 	A16_CS + CS_SND_LEN_offs
A16_CS_SND_PERIOD		:= 	A16_CS + CS_SND_PERIOD_offs
A16_CS_SND_ADDR			:= 	A16_CS + CS_SND_ADDR_offs

A16_CS_DMA_SRC_ADDR		:=	A16_CS + CS_DMA_SRC_ADDR_offs
A16_CS_DMA_DEST_ADDR		:=	A16_CS + CS_DMA_DEST_ADDR_offs
A16_CS_DMA_COUNT		:=	A16_CS + CS_DMA_COUNT_offs
A16_CS_DMA_DATA			:=	A16_CS + CS_DMA_DATA_offs
A16_CS_DMA_CTL			:=	A16_CS + CS_DMA_CTL_offs
A16_CS_DMA_CTL2			:=	A16_CS + CS_DMA_CTL2_offs
A16_CS_DMA_PAUSE_VAL		:=	A16_CS + CS_DMA_PAUSE_VAL_offs
A16_CS_DMA_SEL			:=	A16_CS + CS_DMA_SEL_offs

A16_CS_AERIS_CTL		:=	A16_CS + CS_AERIS_CTL_offs
A16_CS_AERIS_PROGBASE		:=	A16_CS + CS_AERIS_PROGBASE_offs
A16_CS_AERIS_PPC		:=	A16_CS + CS_AERIS_PC_offs


A16_I2C_BASE			:= 	A16_CS + CS_I2C_offs
A16_I2C_STAT			:= 	jim_I2C_BASE
A16_I2C_DATA			:= 	jim_I2C_BASE + 1



I2C_BUSY	:= $80
I2C_NACK	:= $40
I2C_STOP	:= $04
I2C_START	:= $02
I2C_RNW		:= $01
USERV	:= $0200
BRKV	:= $0202
IRQV	:= $0204


;***********************************************************************
;* HARDWARE                                                            *
;***********************************************************************


UART_BASE = $FC10
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

DEVNO_C20K				:=  $D1


;***********************************************************************
;* System VIA                                                          *
;***********************************************************************
sheila_SYSVIA_orb			:= $FE40
sheila_SYSVIA_ora			:= $FE41
sheila_SYSVIA_ddrb			:= $FE42
sheila_SYSVIA_ddra			:= $FE43
sheila_SYSVIA_t1cl			:= $FE44
sheila_SYSVIA_t1ch			:= $FE45
sheila_SYSVIA_t1ll			:= $FE46
sheila_SYSVIA_t1lh			:= $FE47
sheila_SYSVIA_t2cl			:= $FE48
sheila_SYSVIA_t2ch			:= $FE49
sheila_SYSVIA_sr			:= $FE4A
sheila_SYSVIA_acr			:= $FE4B
sheila_SYSVIA_pcr			:= $FE4C
sheila_SYSVIA_ifr			:= $FE4D
sheila_SYSVIA_ier			:= $FE4E
sheila_SYSVIA_ora_nh		:= $FE4F

;***********************************************************************
;* User VIA                                                            *
;***********************************************************************
sheila_USRVIA_orb			:= $FE60
sheila_USRVIA_ora			:= $FE61
sheila_USRVIA_ddrb			:= $FE62
sheila_USRVIA_ddra			:= $FE63
sheila_USRVIA_t1cl			:= $FE64
sheila_USRVIA_t1ch			:= $FE65
sheila_USRVIA_t1ll			:= $FE66
sheila_USRVIA_t1lh			:= $FE67
sheila_USRVIA_t2cl			:= $FE68
sheila_USRVIA_t2ch			:= $FE69
sheila_USRVIA_sr			:= $FE6A
sheila_USRVIA_acr			:= $FE6B
sheila_USRVIA_pcr			:= $FE6C
sheila_USRVIA_ifr			:= $FE6D
sheila_USRVIA_ier			:= $FE6E
sheila_USRVIA_ora_nh			:= $FE6F

;***********************************************************************
;*  VIA constants                                                      *
;***********************************************************************

VIA_IFR_BIT_ANY				:= $80
VIA_IFR_BIT_T1				:= $40
VIA_IFR_BIT_T2				:= $20
VIA_IFR_BIT_CB1				:= $10
VIA_IFR_BIT_CB2				:= $08
VIA_IFR_BIT_SR				:= $04
VIA_IFR_BIT_CA1				:= $02
VIA_IFR_BIT_CA2				:= $01

VIA_ACR_SHIFTMODE_0			:= $00
VIA_ACR_SHIFTMODE_1			:= $04
VIA_ACR_SHIFTMODE_2			:= $08
VIA_ACR_SHIFTMODE_3			:= $0C
VIA_ACR_SHIFTMODE_4			:= $10
VIA_ACR_SHIFTMODE_5			:= $14
VIA_ACR_SHIFTMODE_6			:= $18
VIA_ACR_SHIFTMODE_7			:= $1C

VIA_ACR_T2_COUNT_PB6		:= $20

VIA_ACR_T1_MASK				:= $C0
VIA_ACR_T1_CONT				:= $40
VIA_ACR_T1_SSHOT			:= $80
VIA_ACR_T1_SQUARE			:= $C0



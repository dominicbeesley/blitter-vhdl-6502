; MIT License
; 
; Copyright (c) 2025 Dossytronics
; https://github.com/dominicbeesley/blitter-vhdl-6502
; 
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
; 
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

                .include "p20k.inc"

                .export noice_init
                .export noice_nmi
                .export noice_brk
                .export noice_enter

                .CODE

noice_init:
				rts
noice_enter:
				sei
				cld
				lda		#>noice_enter
				pha
				lda		#<noice_enter
				pha
				php

				lda		#'A'
				jsr	PUTCHAR
				lda		#'B'
				jsr	PUTCHAR
				lda		#'C'
				jsr	PUTCHAR

				lda		#0
				jmp		INT_ENTRY

noice_brk:		sta		REG_A
				lda		#1					; breakpoint
				jmp		INT_ENTRY

noice_nmi:		sta		REG_A
				lda		#2					; NMI
				jmp		INT_ENTRY

; 6502 family Debug monitor for use with NOICE02
;
; This monitor uses only the basic 6502 instructions.
; No 65C02 extended instructions are used
;
; Copyright (c) 2011 by John Hartman
;
; Modification History:
;   6-Feb-94 JLH ported from Mitsubishi 740 version
;  12-Feb-97 JLH wrong target type!  Change from 1 to 7 for 65(C)02
;  21-Jul-00 JLH change FN_MIN from F7 to F0
;  22-Sep-00 JLH add CALL address to TSTG
;  12-Mar-01 JLH V3.0: improve text about paging, formerly called "mapping"
;  27-Aug-11 JLH ported to Alfred Arnold assembler
;  06-Sep-18 DB Ported to Dossy blitter board for 65(c)02
;
;============================================================================
;============================================================================

		.BSS
; Target registers: order must match that used by NoICE on the PC
TASK_REGS:
REG_STATE:       .RES	1
REG_PAGE:        .RES	1
REG_SP:          .RES	2
REG_Y:           .RES	1
REG_X:           .RES	1
REG_A:           .RES	1
REG_CC:          .RES	1
REG_PC:          .RES	2
TASK_REG_END:
TASK_REGS_SIZE  :=	TASK_REG_END-TASK_REGS
;
; In order that we need no page zero RAM, do memory access via an
; instruction built into RAM.  Build instruction and RTS here
CODEBUF:	.RES    4       ;ROOM FOR "LDA xxxx, RTS"
;
; Store a counter for input timeout
RXTIMER:       	.RES    2
;
; Communications buffer
; (Must be at least as long as TASK_REG_SZ.  At least 19 bytes recommended.
; Larger values may improve speed of NoICE memory move commands.)
COMBUF_SIZE	:=	128             ;DATA SIZE FOR COMM BUFFER
COMBUF:         .RES	2+COMBUF_SIZE+1 ;BUFFER ALSO HAS FN, LEN, AND CHECK
;
CODE_SAVE_SIZE 	:=	$10
CODE_SAVE_AREA:	.RES	CODE_SAVE_SIZE

RAM_END:                	        ;ADDRESS OF TOP+1 OF RAM


		.code




;
;===========================================================================
; Get a character to A
;
; Return A=char, CY=0 if data received
;        CY=1 if timeout (0.5 seconds)
;
; Uses 4 bytes of stack including return address
;
GETCHAR:
        	LDA     #0              		;LONG TIMEOUT
        	STA     RXTIMER
        	STA     RXTIMER+1
GC10:   	DEC     RXTIMER
        	BNE     GC20            		;BR IF NOT TIMEOUT
        	DEC     RXTIMER+1       		;ELSE DEC HIGH HALF
        	BEQ     GC90            		;EXIT IF TIMEOUT
GC20:   	BIT     UART_STAT   			;READ DEVICE STATUS
        	BPL     GC10            		;NOT READY YET.
;
; Data received:  return CY=0. data in A
        	CLC                     		;CY=0
        	LDA     UART_DAT		   		;READ DATA
        	RTS
;
; Timeout:  return CY=1
GC90:   	SEC                    			;CY=1
        	RTS

;
;===========================================================================
; Output character in A
;
; Uses 5 bytes of stack including return address
;
PUTCHAR:
PC10:   	BIT     UART_STAT		   		;CHECK TX STATUS
        	BVS     PC10	
        	STA     UART_DAT		  		;TRANSMIT CHAR.
        	RTS

;
;======================================================================
; Response string for GET TARGET STATUS request
; Reply describes target:
TSTG:   	.byte	7				;2: PROCESSOR TYPE = 65(C)02
        	.byte	COMBUF_SIZE			;3: SIZE OF COMMUNICATIONS BUFFER
        	.byte	$80				;4: has CALL
        	.word	$8000,$BFFF			;5-8: LOW AND HIGH LIMIT OF MAPPED MEM (NONE)
        	.byte	B1-B0				;9 BREAKPOINT INSTR LENGTH
;
; Define either the BRK or JSR BRKE instruction for use as breakpoint
; Arnold assembles BRK as two bytes: 00 EA.  We want a ONE byte breakpoint
; so we do it by hand.
B0:     	.byte	0					;10+ BREKAPOINT INSTRUCTION
B1:     	.byte	"6502 monitor V0.1 P20K BARE",0    ;DESCRIPTION, ZERO
        	.byte   0                       	;page of CALL breakpoint
        	.word   B0                      	;address of CALL breakpoint in native order
B2:
TSTG_SIZE	:=	B2-TSTG				;SIZE OF STRING
;
;======================================================================
; HARDWARE PLATFORM INDEPENDENT EQUATES AND CODE
;
; Communications function codes.
FN_GET_STATUS   :=     $FF     				;reply with device info
FN_READ_MEM     :=     $FE     				;reply with data
FN_WRITE_MEM    :=     $FD     				;reply with status (+/-)
FN_READ_REGS    :=     $FC     				;reply with registers
FN_WRITE_REGS   :=     $FB     				;reply with status
FN_RUN_TARGET   :=     $FA     				;reply (delayed) with registers
FN_SET_BYTES    :=     $F9     				;reply with data (truncate if error)
FN_IN           :=     $F8     				;input from port
FN_OUT          :=     $F7     				;output to port
;
FN_MIN          :=     $F0				;MINIMUM RECOGNIZED FUNCTION CODE
FN_ERROR        :=     $F0				;error reply to unknown op-code
;
; 6502 OP-CODE EQUATES
B               :=     $10				;BREAK BIT IN CONDITION CODES
LDA_OP          :=     $AD				;LDA AAA
STA_OP          :=     $8D				;STA AAA
CMP_OP          :=     $CD				;CMP AAA
LDAY_OP         :=     $B9				;LDA AAA,Y
STAY_OP         :=     $99				;STA AAA,Y
CMPY_OP         :=     $D9				;CMP AAA,Y
RTS_OP          :=     $60				;RTS



;===========================================================================
; Enter here via JSR for breakpoint:  PC is stacked.
; Stacked PC points at JSR+1
;;BRKE: STA     REG_A           ;SAVE ACCUM FROM DIRECT ENTRY
;;      PHP                     ;SAVE CC'S AS IF AFTER A BRK INSTRUCTION
;;      SEC
;
; Common handler for default interrupt handlers
; Enter with A=interrupt code = processor state
; PC and CC are stacked.
; REG_A has pre-interrupt accmulator
; Stacked PC points at BRK+2 if BRK, else at PC if entry from interrupt
; A  has state
INT_ENTRY:
;
; Set CPU mode to safe state
		NOP					;DATA BOOK SHOWS THIS - DON'T KNOW WHY
		SEI					;INTERRUPTS OFF
		CLD					;USE BINARY MODE


;
; Save registers in reg block for return to master
		STA     REG_STATE       		;SAVE MACHINE STATE
		PLA                     		;GET CONDITION CODES
		STA     REG_CC
		PLA                     		;GET LSB OF PC OF BREAKPOINT
		STA     REG_PC
		PLA                     		;GET MSB OF PC OF BREAKPOINT
		STA     REG_PC+1

;; If this is a breakpoint (state = 1), then back up PC to point at BRK
        LDA     REG_STATE       ;SAVED STATUS FOR TESTING
        CMP     #1
        BNE     B99             ;BR IF NOT BREAKPOINT: PC IS OK

       	SEC
       	LDA     REG_PC          		;BACK UP PC TO POINT AT BREAKPOINT
       	SBC     #2
       	STA     REG_PC
       	LDA     REG_PC+1
       	SBC     #0
       	STA     REG_PC+1
B99:    JMP     ENTER_MON       		;REG_PC POINTS AT BREAKPOINT OPCODE


;
;===========================================================================
;
; Main loop:  wait for command frame from master
;
; Uses 4 bytes of stack before jump to functions
;
MAIN:
;
; Since we have only part of a page for stack, we run on the target's
; stack.  Thus, reset to target SP, rather than our own.
MAI10:		LDX     REG_SP
		TXS
		LDX     #0		                ;INIT INPUT BYTE COUNT
;
; First byte is a function code
        	JSR     GETCHAR                 	;GET A FUNCTION
        	BCS     MAI10                   	;JIF TIMEOUT: RESYNC
        	CMP     #FN_MIN
        	BCC     MAI10                   	;JIF BELOW MIN: ILLEGAL FUNCTION
        	STA     COMBUF,X                	;SAVE FUNCTION CODE
        	INX
;
; Second byte is data byte count (may be zero)
       		JSR     GETCHAR                 	;GET A LENGTH BYTE
       		BCS     MAI10                   	;JIF TIMEOUT: RESYNC
       		CMP     #COMBUF_SIZE+1	
       		BCS     MAI10                   	;JIF TOO LONG: ILLEGAL LENGTH
       		STA     COMBUF,X                	;SAVE LENGTH
       		INX
       		CMP     #0
       		BEQ     MAI80                   	;SKIP DATA LOOP IF LENGTH = 0
;
; Loop for data
        	TAY                             	;SAVE LENGTH FOR LOOP
MAI20:  	JSR     GETCHAR                 	;GET A DATA BYTE
        	BCS     MAI10                   	;JIF TIMEOUT: RESYNC
        	STA     COMBUF,X                	;SAVE DATA BYTE
        	INX
        	DEY
        	BNE     MAI20
;
; Get the checksum
MAI80:  	JSR     GETCHAR                 	;GET THE CHECKSUM
        	BCS     MAI10                   	;JIF TIMEOUT: RESYNC
        	STA     CODEBUF                 	;SAVE CHECKSUM
;
; Compare received checksum to that calculated on received buffer
; (Sum should be 0)
        	JSR     CHECKSUM
        	CLC
        	ADC     CODEBUF
        	BNE     MAI10                   	;JIF BAD CHECKSUM
;
; Process the message.
		LDA     COMBUF+0                	;GET THE FUNCTION CODE
		CMP     #FN_GET_STATUS
		BEQ     TARGET_STATUS
		CMP     #FN_READ_MEM
		BEQ     JREAD_MEM
		CMP     #FN_WRITE_MEM
		BEQ     JWRITE_MEM
		CMP     #FN_READ_REGS
		BEQ     JREAD_REGS
		CMP     #FN_WRITE_REGS
		BEQ     JWRITE_REGS
		CMP     #FN_RUN_TARGET
		BEQ     JRUN_TARGET
		CMP     #FN_SET_BYTES
		BEQ     JSET_BYTES
		CMP     #FN_IN
		BEQ     JIN_PORT
		CMP     #FN_OUT
		BEQ     JOUT_PORT
;
; Error: unknown function.  Complain
        	LDA     #FN_ERROR
        	STA     COMBUF          		;SET FUNCTION AS "ERROR"
        	LDA     #1
        	JMP     SEND_STATUS     		;VALUE IS "ERROR"
;
; long jumps to handlers
JREAD_MEM:      JMP     READ_MEM
JWRITE_MEM:     JMP     WRITE_MEM
JREAD_REGS:     JMP     READ_REGS
JWRITE_REGS:    JMP     WRITE_REGS
JRUN_TARGET:    JMP     RUN_TARGET
JSET_BYTES:     JMP     SET_BYTES
JIN_PORT:       JMP     IN_PORT
JOUT_PORT:      JMP     OUT_PORT

;===========================================================================
;
; Target Status:  FN, len
TARGET_STATUS:
        	LDX     #0                      	;DATA FOR REPLY
        	LDY     #TSTG_SIZE              	;LENGTH OF REPLY
        	STY     COMBUF+1                	;SET SIZE IN REPLY BUFFER
TS10:   	LDA     TSTG,X                  	;MOVE REPLY DATA TO BUFFER
        	STA     COMBUF+2,X
        	INX
        	DEY
        	BNE     TS10
;
; Compute checksum on buffer, and send to master, then return
        	JMP     SEND



SELPAGE:
		; nothing for
        RTS


;===========================================================================
;
; Read Memory:  FN, len, page, Alo, Ahi, Nbytes
;
READ_MEM:
;
; Set page
		LDA	COMBUF+2
        JSR SELPAGE
;
; Build "LDA  AAAA,Y" in RAM
        	LDA     #LDAY_OP
        	STA     CODEBUF+0

;
; Set address of instruction in RAM
        	LDA     COMBUF+3
        	STA     CODEBUF+1
        	LDA     COMBUF+4
        	STA     CODEBUF+2
;
; Set return after LDA
        	LDA     #RTS_OP
        	STA     CODEBUF+3
;
; Prepare return buffer: FN (unchanged), LEN, DATA
        	LDX     COMBUF+5                	;NUMBER OF BYTES TO GET
        	STX     COMBUF+1                	;RETURN LENGTH = REQUESTED DATA
        	BEQ     GLP90                   	;JIF NO BYTES TO GET
;
; Read the requested bytes from local memory
        	LDY     #0                      	;INITIAL OFFSET
GLP:    	JSR     CODEBUF                 	;GET BYTE AAAA,Y TO A
        	STA     COMBUF+2,Y              	;STORE TO RETURN BUFFER
        	INY
        	DEX
        	BNE     GLP
;
; Compute checksum on buffer, and send to master, then return
GLP90:  	JMP     SEND


;===========================================================================
;
; Write Memory:  FN, len, page, Alo, Ahi, (len-3 bytes of Data)
;
; Uses 2 bytes of stack
;
WRITE_MEM:
;
; Set page
		LDA	COMBUF+2
		JSR SELPAGE
;
; Build "STA  AAAA,Y" in RAM
        	LDA     #STAY_OP
        	STA     CODEBUF+0

;
; Set address into RAM
        	LDA     COMBUF+3
        	STA     CODEBUF+1
        	LDA     COMBUF+4
        	STA     CODEBUF+2
;
; Set return after STA
        	LDA     #RTS_OP
        	STA     CODEBUF+3
;
; Prepare return buffer: FN (unchanged), LEN, DATA
        	LDX     COMBUF+1                	;NUMBER OF BYTES TO PUT
        	DEX                             	;LESS PAGE, ADDRLO, ADDRHI
        	DEX
        	DEX
        	BEQ     WLP50                   	;JIF NO BYTES TO PUT
;
; Write the specified bytes to local memory
        	LDY     #0                      	;INITIAL OFFSET
WLP:    	LDA     COMBUF+5,Y              	;GET BYTE TO WRITE
        	JSR     CODEBUF                 	;STORE THE BYTE AT AAAA,Y
        	INY
        	DEX
        	BNE     WLP
;
; Build "CMP  AAAA,Y" in RAM
		LDA     #CMPY_OP
		STA     CODEBUF+0
;
; Compare to see if the write worked
        	LDX     COMBUF+1                	;NUMBER OF BYTES TO PUT
        	DEX                             	;LESS PAGE, ADDRLO, ADDRHI
        	DEX
        	DEX
        	LDY     #0                      	;INITIAL OFFSET
WLP20:  	LDA     COMBUF+5,Y              	;GET BYTE JUST WRITTEN
        	JSR     CODEBUF                 	;COMPARE THE BYTE AT AAAA,Y
        	BNE     WLP80                   	;BR IF WRITE FAILED
        	INY
        	DEX
        	BNE     WLP20
;
; Write succeeded:  return status = 0
WLP50:  	LDA     #0                      	;RETURN STATUS = 0
        	JMP     WLP90
;
; Write failed:  return status = 1
WLP80:  	LDA     #1
;
; Return OK status
WLP90:  	JMP     SEND_STATUS


;===========================================================================
;
; Read registers:  FN, len=0
;
READ_REGS:
;
; Enter here from "RUN" and "STEP" to return task registers
RETURN_REGS:
        	LDX     #0                      	;REGISTER LIVE HERE
        	LDY     #TASK_REGS_SIZE         	;NUMBER OF BYTES
        	STY     COMBUF+1                	;SAVE RETURN DATA LENGTH
;
; Copy the registers
GRLP:   	LDA     TASK_REGS,X             ;GET BYTE TO A
        	STA     COMBUF+2,X              ;STORE TO RETURN BUFFER
        	INX
        	DEY
        	BNE     GRLP
;
; Compute checksum on buffer, and send to master, then return
        	JMP     SEND


;===========================================================================
;
; Write registers:  FN, len, (register image)
;
WRITE_REGS:
;
        	LDX     #0                      	;POINTER TO DATA
        	LDY     COMBUF+1                	;NUMBER OF BYTES
        	BEQ     WRR80                   	;JIF NO REGISTERS
;
; Copy the registers
WRRLP:  	LDA     COMBUF+2,X              	;GET BYTE TO A
        	STA     TASK_REGS,X             	;STORE TO REGISTER RAM
        	INX
        	DEY
        	BNE     WRRLP
;
; Reload SP, in case it has changed
        	LDX     REG_SP
        	TXS
;
; Return OK status
WRR80:  	LDA     #0
        	JMP     SEND_STATUS

;===========================================================================
;
; Run Target:  FN, len
;
; Uses 3 bytes of stack for user PC and CC before RTI
;
RUN_TARGET:
;
; Restore user's page
		LDA     REG_PAGE	                ;USER'S PAGE
		JSR SELPAGE               	;set hardware page
;
; Switch to user stack, if not already running on it
        	LDX     REG_SP                  ;BACK TO USER STACK
        	TXS
        	LDA     REG_PC+1                ;SAVE MS USER PC FOR RTI
        	PHA
        	LDA     REG_PC                  ;SAVE LS USER PC FOR RTI
        	PHA
        	LDA     REG_CC                  ;SAVE USER CONDITION CODES FOR RTI
        	PHA

;
; Restore registers
	        LDX     REG_X
	        LDY     REG_Y
	        LDA     REG_A


	        ; DB: special blitter return to page out our code
		sta	$FE32				; go back to old rom layout
;
; Return to user
	        RTI

;
;===========================================================================
;
; Common continue point for all monitor entrances
; REG_STATE, REG_A, REG_CC, REG_PC set; X, Y intact; SP = user stack
ENTER_MON:
        	STX     REG_X
        	STY     REG_Y
        	TSX
        	STX     REG_SP          		;SAVE USER'S STACK POINTER (LSB)
        	LDA     #1              		;STACK PAGE ALWAYS 1
EM10:   	STA     REG_SP+1        		;(ASSUME PAGE 1 STACK)
;
; With only a partial page for the stack, don't switch
;;;        LDX  #MONSTACK       ;AND USE OURS INSTEAD
;;;        TXS
;
;;		LDA     PAGEIMAGE       		;GET CURRENT USER PAGE
;;        	LDA     #0              		;... OR ZERO IF UNPAGED TARGET
        	STA     REG_PAGE        		;SAVE USER'S PAGE

;
; Return registers to master
		JMP     RETURN_REGS


;===========================================================================
;
; Set target byte(s):  FN, len { (page, alow, ahigh, data), (...)... }
;
; Return has FN, len, (data from memory locations)
;
; If error in insert (memory not writable), abort to return short data
;
; This function is used primarily to set and clear breakpoints
;
; Uses 2 bytes of stack
;
SET_BYTES:
        	LDY     COMBUF+1               		;LENGTH = 4*NBYTES
       		BEQ     SB90                    	;JIF NO BYTES
;
; Loop on inserting bytes
        	LDX     #0                      	;INDEX INTO INPUT BUFFER
        	LDY     #0                      	;INDEX INTO OUTPUT BUFFER
SB10:
;
; Set page
      		LDA     COMBUF+2,X
            JSR SELPAGE
;
; Build "LDA  AAAA" in RAM
        	LDA     #LDA_OP
        	STA     CODEBUF+0
;
; Set address
        	LDA     COMBUF+3,X
        	STA     CODEBUF+1
        	LDA     COMBUF+4,X
        	STA     CODEBUF+2
;
; Set return after LDA
        	LDA     #RTS_OP
        	STA     CODEBUF+3
;
; Read current data at byte location
        	JSR     CODEBUF                 	;GET BYTE AT AAAA
        	STA     COMBUF+2,Y              	;SAVE IN RETURN BUFFER
;
; Insert new data at byte location
;
; Build "STA  AAAA" in RAM
        	LDA     #STA_OP
        	STA     CODEBUF+0
        	LDA     COMBUF+5,X              	;BYTE TO WRITE
        	JSR     CODEBUF
;
; Verify write
        	LDA     #CMP_OP
        	STA     CODEBUF+0
        	LDA     COMBUF+5,X
        	JSR     CODEBUF
        	BNE     SB90				;BR IF INSERT FAILED: ABORT AT Y BYTES
;
; Loop for next byte
        	INY	        	                ;COUNT ONE INSERTED BYTE
        	INX		        		;STEP TO NEXT BYTE SPECIFIER
        	INX
        	INX
        	INX
        	CPX     COMBUF+1
        	BNE     SB10                    	;LOOP FOR ALL BYTES
;
; Return buffer with data from byte locations
SB90:   	STY     COMBUF+1                	;SET COUNT OF RETURN BYTES
;
; Compute checksum on buffer, and send to master, then return
        	JMP     SEND

;===========================================================================
;
; Input from port:  FN, len, PortAddressLo, PAhi (=0)
;
; While the M740 has no input or output instructions, we retain these
; to allow write-without-verify
;
IN_PORT:
;
; Build "LDA  AAAA" in RAM
        LDA     #LDA_OP
        STA     CODEBUF+0
;
; Set port address
        LDA     COMBUF+2
        STA     CODEBUF+1
        LDA     COMBUF+3
        STA     CODEBUF+2
;
; Set return after LDA
        LDA     #RTS_OP
        STA     CODEBUF+3
;
; Read the requested byte from local memory
        JSR     CODEBUF                 ;GET BYTE TO A
;
; Return byte read as "status"
        JMP     SEND_STATUS

;===========================================================================
;
; Output to port:  FN, len, PortAddressLo, PAhi (=0), data
;
OUT_PORT:
;
; Build "STA  AAAA" in RAM
        LDA     #STA_OP
        STA     CODEBUF+0
;
; Set port address
        LDA     COMBUF+2
        STA     CODEBUF+1
        LDA     COMBUF+3
        STA     CODEBUF+2
;
; Set return after STA
        LDA     #RTS_OP
        STA     CODEBUF+3
;
; Get data
        LDA     COMBUF+4
;
; Write value to port
        JSR     CODEBUF         ;PUT BYTE FROM A
;
; Do not read port to verify (some I/O devices don't like it)
;
; Return status of OK
        LDA     #0
        JMP     SEND_STATUS

;===========================================================================
; Build status return with value from "A"
;
SEND_STATUS:
        STA     COMBUF+2                ;SET STATUS
        LDA     #1
        STA     COMBUF+1                ;SET LENGTH
        JMP     SEND

;===========================================================================
; Append checksum to COMBUF and send to master
;
SEND:   JSR     CHECKSUM                ;GET A=CHECKSUM, X->checksum location
        EOR     #$FF
        CLC
        ADC     #1
        STA     COMBUF,X                ;STORE NEGATIVE OF CHECKSUM
;
; Send buffer to master
        LDX     #0                      ;POINTER TO DATA
        LDY     COMBUF+1                ;LENGTH OF DATA
        INY                             ;PLUS FUNCTION, LENGTH, CHECKSUM
        INY
        INY
SND10:  LDA     COMBUF,X
        JSR     PUTCHAR                 ;SEND A BYTE
        INX
        DEY
        BNE     SND10
        JMP     MAIN                    ;BACK TO MAIN LOOP

;===========================================================================
; Compute checksum on COMBUF.  COMBUF+1 has length of data,
; Also include function byte and length byte
;
; Returns:
;      A = checksum
;      X = pointer to next byte in buffer (checksum location)
;      Y is scratched
;
CHECKSUM:
        LDX     #0                      ;pointer to buffer
        LDY     COMBUF+1                ;length of message
        INY                             ;plus function, length
        INY
        LDA     #0                      ;init checksum to 0
CHK10:  CLC
        ADC     COMBUF,X
        INX
        DEY
        BNE     CHK10                   ;loop for all
        RTS                             ;return with checksum in A



        .IFNDEF __DEICE__INC__
__DEICE__INC__:


;
;======================================================================
;  HARDWARE PLATFORM INDEPENDENT EQUATES AND CODE
;
;  Communications function codes.
FN_GET_STAT             :=  $FF    ; reply with device info
FN_READ_MEM             :=  $FE    ; reply with data
FN_WRITE_M              :=  $FD    ; reply with status (+/-)
FN_READ_RG              :=  $FC    ; reply with registers
FN_WRITE_RG             :=  $FB    ; reply with status
FN_RUN_TARG             :=  $FA    ; reply (delayed) with registers
FN_SET_BYTES            :=  $F9    ; reply with data (truncate if error)
FN_IN                   :=  $F8    ; input from port
FN_OUT                  :=  $F7    ; output to port
;
FN_MIN                  :=  $F7    ; MINIMUM RECOGNIZED FUNCTION CODE
FN_ERROR                :=  $F0    ; error reply to unknown op-code

DEICE_STATE_BP          :=  1           ; breakpoint
DEICE_STATE_TRACE       :=  2           ; trace
DEICE_STATE_ILLEGAL     :=  3
DEICE_STATE_ABORT       :=  4
DEICE_STATE_RESET       :=  5
DEICE_STATE_IRQ         :=  $10         ; add the irq number to this
DEICE_STATE_NMI         :=  $10         ; add the irq number to this


        .ENDIF
-- DB: 2023 - this versions has been heavily modified from the original found at:
-- - https://tams.informatik.uni-hamburg.de/vhdl/models/i80386/i80386.vhd
-- - http://www.pldworld.com/_hdl/1/index.html
-- This version modified to use IEEE libraries, std_logic*types and more modern constructs
-- Tested with ModelSim on the https://github.com/dominicbeesley/blitter-vhdl-6502 project
-- If you are the author of the original work please contact me via GitHub


------------------------------------------------------------------------------
--                                                                          --
-- Intel 80386 VHDL model                                                   --
-- Copyright (C) Convergent, Inc. 1988                                      --
--                                                                          --
--               File: i80386.vhd                                           --
--           Revision: E0.1                                                 --
--       Date Created: 6-12-1988                                            --
--             Author: Mark Dakur                                           --
--           Function: This VHDL model emulates the Intel 80386 32-bit CPU  --
--                     to the instruction and bus timing level.             --
--           Generics: Debug 1=Enable Reporting of Model Status.            --
--                           0=None (Default)                               --
--                     Inst                                                 --
--                     Performance                                          --
--                     Speed                                                --
--   Target Simulator: ViewSim                                              --
--                                                                          --
-- Reference Material: Intel Data Book, 80386-20, Oct., 1987                --
--                     Intel 80386 Programmers Reference, 1986              --
--                     80386 Technical Reference, Edmund Strauss, 1987      --
--                                                                          --
--       Verification: No                                                   --
--         Validation: No                                                   --
--      Certification: No                                                   --
--                                                                          --
-- Behavioral models have two main parts:  a package declaration and its    --
-- corresponding package body, and an entity declaration and its            --
-- corresponding architecture body.  The package declaration and            --
-- package body define subprograms used by the behavioral model;            --
-- the entity declaration and architecture body define the behavior         --
-- of the model.                                                            --
-- This file contains the entity declaration and architecture.              --
------------------------------------------------------------------------------
------------------------------------------------------------------------------
--                              Specification                               --
--                                                                          --
-- 1.0 Introduction                                                         --
-- 2.0 Description                                                          --
--                                                                          --
-- The i80386 consists of 6 functional units defined as follows:            --
--                                                                          --
-- 1) Bus Interface Unit {BIunit}                                           --
--    Accepts internal requests for code fetches from the CPunit and        --   
--    data transfers from the Eunit and prioritizes the requests.           --
--    It is the interface to the external pins (ports) of the package.      --
--                                                                          --
-- 2) Code Prefetch Unit {CPunit}                                           --
--    Performs the program look ahead function.  When the BIunit is not     --
--    performing bus cycles to execute an instruction, it uses the BIunit   --
--    to to fetch sequentially along the instruction byte stream.  These    --
--    prefetched instructions are stored in the 16-byte Code Queue to       --
--    await processing by the IDunit.                                       --
--                                                                          --
-- 3) Instruction Decode Unit {IDunit}                                      --
--    a) Instructions Supported:                                            --
--      1)  nop                                                             --
--      2)  mov eax,"immediate 32 bit data"                                 --
--      3)  mov ebx,"immediate 32 bit data"                                 --
--      4)  mov eax,[ebx]                                                   --
--      5)  mov [ebx],eax                                                   --
--      6)  in al,"byte address"                                            --
--      7)  out "byte address",al                                           --
--      8)  inc eax                                                         --
--      9)  inc ebx                                                         --
--      10) jmp "label" (relative nears and shorts)                         --
--                                                                          --
-- 4) Execution Unit {Eunit}                                                --
--    a) Control Unit {Cunit}                                               --
--    b) Data Unit {Dunit}                                                  --
--    c) Protection Test Unit {PTunit}                                      --
--                                                                          --
-- 5) Segmentation Unit {Sunit}                                             --
--                                                                          --
-- 6) Paging Unit {Punit}                                                   --
--    a) Page Translator Unit {PTunit}                                      --
--       i) Translation Lookaside Buffer {TLB}                              --
--          a) Page Directory                                               --
--          b) Page Table                                                   --
------------------------------------------------------------------------------
------------------------------------------------------------------------------
--                         Revision History                                 --
--                                                                          --
-- Revision                                                                 --
-- Level    Date    Engineer        Description                             --
-- -------- ------- --------------- --------------------------------------- --
-- E0.1     6-12-88 Dakur       First Release                               --
------------------------------------------------------------------------------
------------------------------------------------------------------------------
--
-- Entity declaration for i80386:
--
-- The following entity declaration begins the definition of the
-- behavioral model of the i80386.  It declares the model's name
-- and its IO signals, or ports.  This declaration defines the
-- model's interface with enclosing designs; it defines the part
-- of the model that is externally visible.  Following this
-- entity declaration is its corresponding architecture body;
-- the architecture body defines the behavior of the model.
--
-----------------------------------------------------------------------
--DB remove --PACKAGE i80386 is
--DB remove --FUNCTION tohex (CONSTANT value, Bytes: IN INTEGER) RETURN integer;
--DB remove --
--DB remove --END i80386;
--DB remove --
--DB remove --PACKAGE BODY i80386 is
--DB remove --FUNCTION tohex (CONSTANT value, Bytes: IN INTEGER) RETURN integer IS
--DB remove --    VARIABLE dWord: std_logic_vector(31 downto 0);
--DB remove --    VARIABLE Byte:  std_logic_vector(31 downto 0);
--DB remove --    VARIABLE Count: INTEGER;
--DB remove --BEGIN                   
--DB remove --    Count := 1;
--DB remove --    dWord := std_logic_vector(value);
--DB remove --    Convert: WHILE Count <= Bytes LOOP
--DB remove --        CASE integer(Bytes) is
--DB remove --            WHEN 4 =>
--DB remove --                CASE Count is
--DB remove --                    WHEN 1 =>
--DB remove --                        Byte := X"000000" & dWord(31 downto 24);
--DB remove --                    WHEN 2 =>
--DB remove --                        Byte := X"000000" & dWord(23 downto 16);
--DB remove --                    WHEN 3 =>
--DB remove --                        Byte := X"000000" & dWord(15 downto 8);
--DB remove --                    WHEN 4 =>
--DB remove --                        Byte := X"000000" & dWord(7 downto 0);
--DB remove --                    WHEN OTHERS => NULL;
--DB remove --                END CASE;
--DB remove --            WHEN 2 =>
--DB remove --                CASE Count is
--DB remove --                    WHEN 1 =>
--DB remove --                        Byte := X"000000" & dWord(15 downto 8);
--DB remove --                    WHEN 2 =>
--DB remove --                        Byte := X"000000" & dWord(7 downto 0);
--DB remove --                    WHEN OTHERS => NULL;
--DB remove --                END CASE;
--DB remove --            WHEN 1 =>
--DB remove --                Byte := X"000000" & dWord(7 downto 0);
--DB remove --            WHEN OTHERS => NULL;
--DB remove --        END CASE;
--DB remove --        Count := Count + 1;
--DB remove --        CASE integer(Byte(7 downto 4)) is
--DB remove --            WHEN 15 =>
--DB remove --                put("F");
--DB remove --            WHEN 14 =>
--DB remove --                put("E");
--DB remove --            WHEN 13 =>
--DB remove --                put("D");
--DB remove --            WHEN 12 =>
--DB remove --                put("C");
--DB remove --            WHEN 11 =>
--DB remove --                put("B");
--DB remove --            WHEN 10 =>
--DB remove --                put("A");
--DB remove --            WHEN 9 =>
--DB remove --                put("9");
--DB remove --            WHEN 8 =>
--DB remove --                put("8");
--DB remove --            WHEN 7 =>
--DB remove --                put("7");
--DB remove --            WHEN 6 =>
--DB remove --                put("6");
--DB remove --            WHEN 5 =>
--DB remove --                put("5");
--DB remove --            WHEN 4 =>
--DB remove --                put("4");
--DB remove --            WHEN 3 =>
--DB remove --                put("3");
--DB remove --            WHEN 2 =>
--DB remove --                put("2");
--DB remove --            WHEN 1 =>
--DB remove --                put("1");
--DB remove --            WHEN 0 =>
--DB remove --                put("0");
--DB remove --            WHEN OTHERS => put("X");
--DB remove --        END CASE;
--DB remove --        CASE integer(Byte(3 downto 0)) is
--DB remove --            WHEN 15 =>
--DB remove --                put("F");
--DB remove --            WHEN 14 =>
--DB remove --                put("E");
--DB remove --            WHEN 13 =>
--DB remove --                put("D");
--DB remove --            WHEN 12 =>
--DB remove --                put("C");
--DB remove --            WHEN 11 =>
--DB remove --                put("B");
--DB remove --            WHEN 10 =>
--DB remove --                put("A");
--DB remove --            WHEN 9 =>
--DB remove --                put("9");
--DB remove --            WHEN 8 =>
--DB remove --                put("8");
--DB remove --            WHEN 7 =>
--DB remove --                put("7");
--DB remove --            WHEN 6 =>
--DB remove --                put("6");
--DB remove --            WHEN 5 =>
--DB remove --                put("5");
--DB remove --            WHEN 4 =>
--DB remove --                put("4");
--DB remove --            WHEN 3 =>
--DB remove --                put("3");
--DB remove --            WHEN 2 =>
--DB remove --                put("2");
--DB remove --            WHEN 1 =>
--DB remove --                put("1");
--DB remove --            WHEN 0 =>
--DB remove --                put("0");
--DB remove --            WHEN OTHERS => put("X");
--DB remove --        END CASE;
--DB remove --    END LOOP Convert;
--DB remove --    put("h");
--DB remove --    RETURN 1;
--DB remove --END tohex;
--DB remove --END i80386;
--DB remove --USE work.i80386.tohex;


-- DB: add IEEE libs
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use std.textio.all;

library work;

entity i80386 is

    GENERIC (CONSTANT Debug:        BOOLEAN := FALSE;
             CONSTANT Inst:         BOOLEAN := FALSE;
             CONSTANT Performance:  INTEGER := 1;
             CONSTANT Speed:        INTEGER := 32);

-- USE: Pass a value to the above generics from attributes attached to the 80386 symbol
--      on the schematic.

-- Description: Debug; A value of integer 1 (one) means that the model will output
--              status information as simulation progresses.  The default if no attribute exists is
--              FALSE, or no status reported.

--				Inst; A value of interger 1 (one) means that the model will output
--				instructions.  The Debug generic overides this one.

--              Performance; 0=min, 1=typ, 2=max

--              Speed; Processor speed choices, values are: 0=16MHz, 1=20MHz, 2=25MHZ, 3=30MHz

    port    (BE_n:                  out std_logic_vector(3 downto 0) := B"0000";
            Address:                out std_logic_vector(31 downto 2) := B"111111111111111111111111111111";
            W_R_n:                  out std_logic := '0';
            D_C_n:                  out std_logic := '1';
            M_IO_n:                 out std_logic := '0';
            LOCK_n, ADS_n:          out std_logic := '1';
            HLDA:                   out std_logic := '0';
            Data:                   inout std_logic_vector(31 downto 0) := X"ZZZZZZZZ";
            CLK2:                   in std_logic := '0';
            NA_n, BS16_n:           in std_logic := '1';
            READY_n, HOLD, PERQ:    in std_logic := '0';
            BUSY_n, ERROR_n:        in std_logic := '1';
            INTR:                   in std_logic := '0';
            NMI, RESET:             in std_logic := '0');

-- THE ORDER OF THE PORTS IS IMPORTANT FOR COMPATIBILITY WITH THE "PINORDER"
-- ATTRIBUTE ON THE SYMBOL FOR THIS MODEL.

end i80386;

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--
-- Architecture Body of i80386:
--
-- The following architecture body defines the behavior of the i80386
-- model.  It consists of a set of process statements and other
-- concurrent statements.  These statements are all invoked when
-- simulation begins, and continue to execute concurrently throughout
-- simulation.  The statements communicate via the internal signals
-- declared at the top of the architecture body. Each statement either
-- checks the validity of input signals, or modifies the values of
-- output signals or internal signals in response to changes on input
-- signals or internal signals.
--
-----------------------------------------------------------------------

architecture behavior of i80386 is

-- Internal Signals
-- These information paths allow for communication between Concurent
-- Process Blocks within the model.  All signals that are defined here have
-- global visibility.  Signals, variables and constants defined within process
-- blocks have local visibility within that process ONLY.

    SIGNAL CLK:             std_logic                   := '1'; -- 80386 internal clock=CLK2 / 2

    SIGNAL StateNA:         std_logic                   := '1';
    SIGNAL StateBS16:       std_logic                   := '1';
    SIGNAL RequestPending:  std_logic                   := '1';
    CONSTANT Pending:       std_logic                   := '1';
    CONSTANT NotPending:    std_logic                   := '0';
    SIGNAL NonAligned:      std_logic                   := '0';
    SIGNAL ReadRequest:     std_logic                   := '1';
    SIGNAL MemoryFetch:     std_logic                   := '1';
    SIGNAL CodeFetch:       std_logic                   := '1';
    SIGNAL ByteEnable:      std_logic_vector(3 downto 0)    := X"0";
    SIGNAL DataWidth:       std_logic_vector(31 downto 0)   := X"00000002";
    CONSTANT WidthByte:     INTEGER                 := 0; -- Byte
    CONSTANT WidthWord:     INTEGER                 := 1; -- Word  (2 bytes)
    CONSTANT WidthDword:    INTEGER                 := 2; -- Dword (4 bytes)
    SIGNAL dWord:           std_logic_vector(31 downto 0)   := X"00000000";

    -- DB: make state enumerated
    type t_state is (StateTi, StateT1, StateT2, StateT1P, StateTh, StateT2P, StateT2I, DBRESET);
    signal State : t_state := StateTi;

-- DB REMOVE -- CONSTANT StateTi:       INTEGER := 0;   -- Reset State
-- DB REMOVE -- CONSTANT StateT1:       INTEGER := 1;   -- First state of a non-pipelined bus cycle
-- DB REMOVE -- CONSTANT StateT2:       INTEGER := 2;   -- State where NA_n is false (non-pipelined)
-- DB REMOVE -- CONSTANT StateT1P:      INTEGER := 3;   -- First state of a pipelined bus cycle
-- DB REMOVE -- CONSTANT StateTh:       INTEGER := 4;   -- Hold acknowledge state
-- DB REMOVE -- CONSTANT StateT2P:      INTEGER := 5;   -- Subsequent state of a pipelined bus cycle
-- DB REMOVE -- CONSTANT StateT2I:      INTEGER := 6;   -- Subsequent state of a potential pipelined
                                            -- bus cycle.
    --DB: the following statement appears to be untrue!
    -- The constants are indexes into the vector State where each constant represents 1 bit of the vector.


-- Internal User Registers
--- General Purpose Data and Address
    SIGNAL EAX: std_logic_vector(31 DOWNTO 0);
    SIGNAL EDX: std_logic_vector(31 DOWNTO 0);
    SIGNAL ECX: std_logic_vector(31 DOWNTO 0);
    SIGNAL EBX: std_logic_vector(31 DOWNTO 0);
    SIGNAL EBP: std_logic_vector(31 DOWNTO 0);
    SIGNAL ESI: std_logic_vector(31 DOWNTO 0);
    SIGNAL EDI: std_logic_vector(31 DOWNTO 0);
    SIGNAL ESP: std_logic_vector(31 DOWNTO 0);
-- NOTE: Create a proceedure that can be called with the appropriate mnemonic
-- to access the appropriate register.  Futher work must be done to implement
-- the 16-bit and 8-bit versions of these registers.

--- Segment Selectors
    SIGNAL CS:  std_logic_vector(15 DOWNTO 0);  -- Code Segment
    SIGNAL SS:  std_logic_vector(15 DOWNTO 0);  -- Stack Segment
    SIGNAL DS:  std_logic_vector(15 DOWNTO 0);  -- Data Segment Module A
    SIGNAL ES:  std_logic_vector(15 DOWNTO 0);  -- Data Segment Structure 1
    SIGNAL FSS: std_logic_vector(15 DOWNTO 0);  -- Data Segment Structure 2
    SIGNAL GS:  std_logic_vector(15 DOWNTO 0);  -- Data Segment Structure 3

--- Segment Descripters
--- These register are associated with each Segment Selector Register and are
--- not visible to the programmer.
--- Instruction Pointer and Flags
    SIGNAL rEIP:        std_logic_vector(31 downto 0) := X"FFFFFFF0";
-- Must create a proceedure to access by mnemonic the IP within the EIP register.
    SIGNAL rEFLAGS:     std_logic_vector(31 downto 0) := B"XXXXXXXXXXXXXXXX0XXXXXXXXX0X0X1X";
    CONSTANT VM:        INTEGER := 0;
    CONSTANT RF:        INTEGER := 0;
    CONSTANT NT:        INTEGER := 0;
    CONSTANT IOPL:      INTEGER := 0;
    CONSTANT xOF:       INTEGER := 0;
    CONSTANT DF:        INTEGER := 0;
    CONSTANT xIF:       INTEGER := 0;
    CONSTANT TF:        INTEGER := 0;
    CONSTANT SF:        INTEGER := 0;
    CONSTANT ZF:        INTEGER := 0;
    CONSTANT AF:        INTEGER := 4;
    CONSTANT PF:        INTEGER := 2;
    CONSTANT CF:        INTEGER := 0;

--- Machine Control
    SIGNAL rCR0:        std_logic_vector(31 downto 0) := X"00000000";
    SIGNAL rCR1:        std_logic_vector(31 downto 0) := X"00000000";
    SIGNAL rCR2:        std_logic_vector(31 downto 0) := X"00000000";
    -- Page Directory Base Register
    SIGNAL rCR3:        std_logic_vector(31 downto 0) := X"00000000";

--- System Address (Memory Mapping Management)
    -- Global Descripter Table Pointer
    SIGNAL rGDTbase:        std_logic_vector(31 downto 0) := X"00000000";
    SIGNAL rGDTlimit:       std_logic_vector(15 downto 0) := X"0000";
    SIGNAL rGDTselector:    std_logic_vector(15 downto 0) := X"0000";
    -- Local Descripter Table Pointer
    SIGNAL rLDTbase:        std_logic_vector(31 downto 0) := X"00000000";
    SIGNAL rLDTlimit:       std_logic_vector(15 downto 0) := X"0000";
    SIGNAL rLDTselector:    std_logic_vector(15 downto 0) := X"0000";
    -- Interrupt Descripter Table Pointer
    SIGNAL rIDTbase:        std_logic_vector(31 downto 0) := X"00000000";
    SIGNAL rIDTlimit:       std_logic_vector(15 downto 0) := X"0000";
    SIGNAL rIDTselector:    std_logic_vector(15 downto 0) := X"0000";
    -- Task State Segment Descripter Table Pointer
    SIGNAL rTSSbase:        std_logic_vector(31 downto 0) := X"00000000";
    SIGNAL rTSSlimit:       std_logic_vector(15 downto 0) := X"0000";
    SIGNAL rTSSselector:    std_logic_vector(15 downto 0) := X"0000";
    -- Page Table Register Files
--  SIGNAL rfPageDir:       std_logic_2d(0 to 1024,31 downto 0);
--  SIGNAL rfPageTable:     std_logic_2d(0 to 1024,31 downto 0);
--- Debug
--- Test

-- 80386 Instruction Set (Supported by this model)

--- Instruction Prefixes
        CONSTANT REP:               INTEGER := 16#F3#;
        CONSTANT REPNE:             INTEGER := 16#F2#;
        CONSTANT LOCK:              INTEGER := 16#F0#;

--- Segment Override Prefixes
        CONSTANT CSsop:             INTEGER := 16#2E#;
        CONSTANT SSsop:             INTEGER := 16#36#;
        CONSTANT DSsop:             INTEGER := 16#3E#;
        CONSTANT ESsop:             INTEGER := 16#26#;
        CONSTANT FSsop:             INTEGER := 16#64#;
        CONSTANT GSsop:             INTEGER := 16#65#;
        CONSTANT OPsop:             INTEGER := 16#66#;
        CONSTANT ADsop:             INTEGER := 16#67#;

--- Data Transfer
        CONSTANT MOV_al_b:          INTEGER := 16#B0#;
        CONSTANT MOV_eax_dw:        INTEGER := 16#B8#; -- mov eax,0000A5A5h
        CONSTANT MOV_ebx_dw:        INTEGER := 16#BB#; -- mov ebx,0FFFFFFF0h
        CONSTANT MOV_ebx_eax:       INTEGER := 16#89#; -- mov [ebx],eax {89,03}
        CONSTANT MOV_eax_ebx:       INTEGER := 16#8B#; -- mov eax,[ebx] {8B,03}
        CONSTANT IN_al:             INTEGER := 16#E4#;
        CONSTANT OUT_al:            INTEGER := 16#E6#;
--- Arithmetic
        CONSTANT ADD_al_b:          INTEGER := 16#04#;
        CONSTANT ADD_ax_w:          INTEGER := 16#05#;
--- Shift/Rotate
        CONSTANT ROL_eax_b:         INTEGER := 16#D1#; -- rol eax,1 {D1,C0}
        CONSTANT ROL_al_1:          INTEGER := 16#D0#;
        CONSTANT ROL_al_n:          INTEGER := 16#C0#;
--- String Manipulation
        CONSTANT INC_eax:           INTEGER := 16#40#;
        CONSTANT INC_ebx:           INTEGER := 16#43#;
--- Bit Manipulation
--- Control Transfer
        CONSTANT JMP_rel_short:     INTEGER := 16#EB#;
        CONSTANT JMP_rel_near:      INTEGER := 16#E9#;
        CONSTANT JMP_intseg_immed:  INTEGER := 16#EA#;
--- High Level Language Support
--- Operating System Support
--- Processor Control
        CONSTANT HLT:               INTEGER := 16#F4#;
        CONSTANT WAITx:             INTEGER := 16#9B#;
        CONSTANT NOP:               INTEGER := 16#90#;

    BEGIN

-- Begin Fault Detection Section
    Faults: PROCESS
    BEGIN
        WAIT UNTIL now > 1 ps;
        assert not is_X(CLK2)
            report "Clock {i}: CLK2 (pin F12) is undefined"
            severity FAILURE;
        assert not is_X(READY_n)
            report "Control {i}: READY (pin G13) is undefined"
            severity FAILURE;
    END PROCESS Faults;
-- End Fault Detection Section

-- Begin Behavioral Blocks
    -- Port Signals Status Reports Begin
    CLK2status: PROCESS     -- Function:    The first time (after the loading the network)
                            --              the simulation is run, this process will report
                            --              status of the 80386's CLK2 input from the network.

        VARIABLE StartTime:     time;
        VARIABLE Pwidth:        time;
        VARIABLE freq:          INTEGER;
    BEGIN
        WAIT UNTIL rising_edge(CLK2);
        StartTime := now;
        WAIT UNTIL rising_edge(CLK2);
        Pwidth := (now - StartTime);
        freq := 1000000 us / Pwidth;

        report  "CLK2 Pulse Width is=" & time'image(Pwidth);
        report  "CLK2 Frequency is=" & integer'image(freq) & "kHZ";
        WAIT;
    end PROCESS CLK2status;
    -- Port Signals Status Reports End

    -- Internal Control Logic Processes Begin
    GenCLK: PROCESS
    begin
        -- CLK is the 80386's internal clock an is 1/2 of CLK2
        wait until rising_edge(CLK2);
        CLK <= not CLK;
    end PROCESS GenCLK;

    Initialize: PROCESS
    BEGIN
        EAX <= X"00000000";
        rEFLAGS <= X"00000002";
        rEIP <= X"FFFFFFF0";
        rIDTbase <= X"00000000";
        rIDTlimit <= X"03FF";
        IF Debug THEN
            report "DEBUG: State=RESET";
        END IF;
        WAIT UNTIL falling_edge(RESET); -- De-assert the drivers
        IF Debug THEN
            report "DEBUG: 80386 was successfully Reset.";
        END IF;
        EAX <= X"ZZZZZZZZ";
        rEFLAGS <= X"ZZZZZZZZ";
        rEIP <= X"ZZZZZZZZ";
        rIDTbase <= X"ZZZZZZZZ";
        rIDTlimit <= X"ZZZZ";
        RequestPending <= 'Z';
        WAIT UNTIL rising_edge(RESET);
    end PROCESS Initialize;

    TstateMachine: PROCESS(RESET,CLK)
    VARIABLE nState: t_state := StateTi;
    BEGIN

        if RESET = '1' then
            State <= DBRESET;
        elsif falling_edge(CLK) then
            CASE State is
                WHEN StateTi =>
                    IF RESET = '0' and RequestPending = Pending THEN
                        nState := StateT1;
                        IF Debug THEN
                            report "DEBUG: 80386 is in State Ti, Moving to StateT1";
                        END IF;
                    ELSIF RESET = '0' and HOLD = '1' THEN
                        nState := StateTh;
                        IF Debug THEN
                            report "DEBUG: 80386 is in State Ti, Moving to StateTh";
                        END IF;
                    ELSE
                        nState := StateTi;
                        IF Debug THEN
                            IF RESET = '1' THEN
                                report "DEBUG: 80386 is in State Ti, Due to RESET = Asserted";
                            ELSE
                                report "DEBUG: 80386 is in State Ti, Due to NO Requests Pending";
                            END IF;
                        END IF;
                    END IF;

                WHEN StateT1 =>
                    IF Debug THEN
                        report "DEBUG: 80386 is in State T1, Moving to StateT2";
                    END IF;
                    nState := StateT2;

                WHEN StateT2 =>
                    IF Debug THEN
                        report "DEBUG: 80386 is in State T2";
                    END IF;
                    IF READY_n = '0' and HOLD ='0' and RequestPending = Pending THEN
                        nState := StateT1;
                    ELSIF READY_N = '1' and NA_n = '1' THEN
                        NULL;
                    ELSIF (RequestPending = Pending or HOLD = '1') and (READY_N = '1' and NA_n = '0') THEN
                        nState := StateT2I;
                    ELSIF RequestPending = Pending and HOLD = '0' and READY_N = '1' and NA_n = '0' THEN
                        nState := StateT2P;
                    ELSIF RequestPending = NotPending and HOLD = '0' and READY_N = '0' THEN
                        nState := StateTi;
                    ELSIF HOLD = '1' and READY_N = '1' THEN
                        nState := StateTh;
                    END IF;

                WHEN StateT1P =>
                    IF Debug THEN
                        report "DEBUG: 80386 is in State T1P";
                    END IF;
                    IF NA_n = '0' and HOLD = '0' and RequestPending = Pending THEN
                        nState := StateT2P;
                    ELSIF NA_n = '0' and (HOLD = '1' or RequestPending = NotPending) THEN
                        nState := StateT2I;
                    ELSIF NA_n = '1' THEN
                        nState := StateT2;
                    END IF;

                WHEN StateTh =>
                    IF Debug THEN
                        report "DEBUG: 80386 is in State Th";
                    END IF;
                    IF HOLD = '1' THEN
                        NULL;
                    ELSIF HOLD = '0' and RequestPending = Pending THEN
                        nState := StateT1;
                    ELSIF HOLD = '0' and RequestPending = NotPending THEN
                        nState := StateTi;
                    END IF;

                WHEN StateT2P =>
                    IF Debug THEN
                        report "DEBUG: 80386 is in State T2P";
                    END IF;
                    IF READY_n = '0' THEN
                        nState := StateT1P;
                    END IF;

                WHEN StateT2I =>
                    IF Debug THEN
                        report "DEBUG: 80386 is in State T2I";
                    END IF;
                    IF READY_n = '1' and (RequestPending = NotPending or HOLD = '1') THEN
                        NULL;
                    ELSIF READY_n = '1' and RequestPending = Pending and HOLD = '0' THEN
                        nState := StateT2P;
                    ELSIF READY_n = '0' and HOLD = '1' THEN
                        nState := StateTh;
                    ELSIF READY_n = '0' and HOLD = '0' and RequestPending = Pending THEN
                        nState := StateT1;
                    ELSIF READY_n = '0' and HOLD = '0' and RequestPending = NotPending THEN
                        nState := StateTi;
                    END IF;

                WHEN OTHERS => report "MODEL ERROR: Invalid State=" & t_state'image(State);
            END CASE;
            State <= nState;    -- This is where the next State is actually assigned.
        end if;
    end PROCESS TstateMachine;
    -- Internal Control Logic Processes End

    -- Instruction Pre-Fetch, Decode and Execution Unit Begin
    InstDecode: PROCESS
    
    type inst_q_type is array(1 to 16) of std_logic_vector(7 downto 0);

    VARIABLE InstQueue:         inst_q_type;
    VARIABLE InstQueueRd_Addr:  INTEGER := 1;       -- Address used by the decode unit to read the queue.
    VARIABLE InstQueueWr_Addr:  INTEGER := 1;       -- Address used by the Pre-fetch unit to fill the queue.
    VARIABLE InstQueueLimit:    INTEGER := 16;      -- Maximum length of the Queue.
    VARIABLE InstAddrPointer:   INTEGER := 0;       -- Allways points to the current instruction's Address.
    VARIABLE PhyAddrPointer:    INTEGER := 0;       -- Allways points to the Systems Physical Address.
    VARIABLE Extended:          BOOLEAN := FALSE;   -- True if an extended op-code prefix was detected.
    VARIABLE More:              BOOLEAN := FALSE;   -- True if instruction was decoded correctly and
                                                    -- another read is needed for data.
    VARIABLE Flush:             BOOLEAN := FALSE;   -- True if JMP was executed, flush the Queue.
    VARIABLE First:             BOOLEAN := TRUE;    -- First time thru.
    VARIABLE Byte:              std_logic_vector(7 downto 0);
    VARIABLE lWord:             std_logic_vector(15 downto 0);
    VARIABLE uWord:             std_logic_vector(15 downto 0);
    VARIABLE fWord:             std_logic_vector(31 downto 0);
    VARIABLE Dummy:             INTEGER;

    BEGIN
        IF First THEN
            PhyAddrPointer := to_integer(unsigned(rEIP));
            InstAddrPointer := PhyAddrPointer;
            First := FALSE;
        END IF;
        RequestPending <= Pending;
        ReadRequest <= Pending;
        MemoryFetch <= Pending;
        CodeFetch <= Pending;
        IF Debug THEN
            report "DEBUG: Fetching 1st Word @ Addr=" & to_hstring(to_signed(PhyAddrPointer,32));
        END IF;
        WAIT UNTIL falling_edge(READY_n);
        RequestPending <= NotPending;
        WAIT UNTIL falling_edge(CLK);
        InstQueue(InstQueueWr_Addr) := Data(7 downto 0);
        InstQueueWr_Addr := InstQueueWr_Addr + 1;
        InstQueue(InstQueueWr_Addr) := Data(15 downto 8);
        InstQueueWr_Addr := InstQueueWr_Addr + 1;
        IF StateBS16 = '1' THEN  -- A dWord code fetch
            InstQueue(InstQueueWr_Addr) := Data(23 downto 16);
            InstQueueWr_Addr := InstQueueWr_Addr + 1;
            InstQueue(InstQueueWr_Addr) := Data(31 downto 24);
            InstQueueWr_Addr := InstQueueWr_Addr + 1;
            PhyAddrPointer := PhyAddrPointer + 4; -- Point to next dWord since BS16- = 1
        ELSE
            PhyAddrPointer := PhyAddrPointer + 2; -- Point to next word since BS16- = 0
            IF Debug THEN
                report "DEBUG: Fetching 2nd Word @ Addr=" & to_hstring(to_signed(PhyAddrPointer,32));
            END IF;
            rEIP <= std_logic_vector(to_signed(PhyAddrPointer, rEIP'length));
            WAIT UNTIL rising_edge(CLK);
            RequestPending <= Pending;
            WAIT UNTIL falling_edge(READY_n);
            RequestPending <= NotPending;
            WAIT UNTIL falling_edge(CLK);
            InstQueue(InstQueueWr_Addr) := Data(7 downto 0);
            InstQueueWr_Addr := InstQueueWr_Addr + 1;
            InstQueue(InstQueueWr_Addr) := Data(15 downto 8);
            InstQueueWr_Addr := InstQueueWr_Addr + 1;
            PhyAddrPointer := PhyAddrPointer + 2; -- Point to next word since BS16- = 0
        END IF;
        Decode: WHILE InstQueueRd_Addr < InstQueueWr_Addr LOOP
            IF DEBUG THEN
                report "DEBUG: InstQueueRd_Addr=" & integer'image(InstQueueRd_Addr);
                report "DEBUG: InstQueueWr_Addr=" & integer'image(InstQueueWr_Addr);
                report "DEBUG: InstQueueLimit=" & integer'image(InstQueueLimit);
                report "DEBUG: InstAddrPointer=" & to_hstring(to_signed(InstAddrPointer,32));
                report "DEBUG: PhyAddrPointer=" & to_hstring(to_signed(PhyAddrPointer,32));
                report "DEBUG: Extended=" & boolean'image(Extended);
                report "DEBUG: Flush=" & boolean'image(Flush);
                report "DEBUG: More=" & boolean'image(More);
                report "DEBUG: InstQueue( 1)=" & to_hstring(InstQueue(1));
                report "DEBUG: InstQueue( 2)=" & to_hstring(InstQueue(2));
                report "DEBUG: InstQueue( 3)=" & to_hstring(InstQueue(3));
                report "DEBUG: InstQueue( 4)=" & to_hstring(InstQueue(4));
                report "DEBUG: InstQueue( 5)=" & to_hstring(InstQueue(5));
                report "DEBUG: InstQueue( 6)=" & to_hstring(InstQueue(6));
                report "DEBUG: InstQueue( 7)=" & to_hstring(InstQueue(7));
                report "DEBUG: InstQueue( 8)=" & to_hstring(InstQueue(8));
                report "DEBUG: InstQueue( 9)=" & to_hstring(InstQueue(9));
                report "DEBUG: InstQueue(10)=" & to_hstring(InstQueue(10));
                report "DEBUG: InstQueue(11)=" & to_hstring(InstQueue(11));
                report "DEBUG: InstQueue(12)=" & to_hstring(InstQueue(12));
                report "DEBUG: InstQueue(13)=" & to_hstring(InstQueue(13));
                report "DEBUG: InstQueue(14)=" & to_hstring(InstQueue(14));
                report "DEBUG: InstQueue(15)=" & to_hstring(InstQueue(15));
                report "DEBUG: InstQueue(16)=" & to_hstring(InstQueue(16));
            END IF;
            CASE to_integer(unsigned(InstQueue(InstQueueRd_Addr))) is
                WHEN NOP =>
                    InstAddrPointer := InstAddrPointer + 1;
                    InstQueueRd_Addr := InstQueueRd_Addr + 1;
                    Flush := FALSE;
                    More := FALSE;
                    IF Debug OR Inst THEN
                        report "DEBUG: Executing NOP";
                    END IF;
                WHEN OPsop =>
                    InstAddrPointer := InstAddrPointer + 1;
                    InstQueueRd_Addr := InstQueueRd_Addr + 1;
                    Extended := TRUE;
                    Flush := FALSE;
                    More := FALSE;
                    IF Debug OR Inst THEN
                        report "DEBUG: Extended Op-Code Read:" & to_hstring(to_unsigned(OPsop,32));
                    END IF;
                WHEN JMP_rel_short =>
                    IF (InstQueueWr_Addr - InstQueueRd_Addr) >= 3 THEN
                            
                        IF InstQueue(InstQueueRd_Addr+1)(7) = '1' THEN -- Negative Offset
                            PhyAddrPointer := InstAddrPointer + 1 - (16#FF# - to_integer(unsigned(InstQueue(InstQueueRd_Addr+1))));
                            InstAddrPointer := PhyAddrPointer;
                            IF Debug OR Inst THEN
                                report "DEBUG: Executing JMP-Rel-Short from:" & to_hstring(to_signed(InstAddrPointer,32)) & " (-)To:" & to_hstring(to_signed(PhyAddrPointer,32));
                            END IF;
                        ELSE -- Positive Offset
                            PhyAddrPointer := InstAddrPointer + 2 + to_integer(unsigned(InstQueue(InstQueueRd_Addr+1)));
                            InstAddrPointer := PhyAddrPointer;
                            IF Debug OR Inst THEN
                                report "DEBUG: Executing JMP-Rel-Short from:" & to_hstring(to_signed(InstAddrPointer,32)) & " (+)To:" & to_hstring(to_signed(PhyAddrPointer,32));
                            END IF;
                        END IF;
                        Flush := TRUE;
                        More := FALSE;
                    ELSE
                        Flush := FALSE;
                        More := TRUE;
                    END IF;
                WHEN JMP_rel_near =>
                    IF (InstQueueWr_Addr - InstQueueRd_Addr) >= 5 THEN
                            
                        PhyAddrPointer := InstAddrPointer + 5 + to_integer(unsigned(InstQueue(InstQueueRd_Addr+1)));
                        InstAddrPointer := PhyAddrPointer;
                        IF Debug OR Inst THEN
                            report "DEBUG: Executing JMP-Rel-Near from:" & to_hstring(to_signed(InstAddrPointer,32)) & " To:" & to_hstring(to_signed(PhyAddrPointer,32));
                        END IF;
                        Flush := TRUE;
                        More := FALSE;
                    ELSE
                        Flush := FALSE;
                        More := TRUE;
                    END IF;
                WHEN JMP_intseg_immed =>
-- To be Implemented (mad/8-23-1988)
                    IF Debug OR Inst THEN
                        report "DEBUG: {TBD} Executing JMP-IntSeg-Immed from:" & integer'image(InstAddrPointer);
                    END IF;
                    InstAddrPointer := InstAddrPointer + 1;
                    InstQueueRd_Addr := InstQueueRd_Addr + 1;
                    Flush := FALSE;
                    More := FALSE;
                WHEN MOV_al_b =>
-- To be Implemented (mad/8-23-1988)
                    IF Debug OR Inst THEN
                        report "DEBUG: {TBD} Executing MOV-al<-byte";
                    END IF;
                    InstAddrPointer := InstAddrPointer + 1;
                    InstQueueRd_Addr := InstQueueRd_Addr + 1;
                    Flush := FALSE;
                    More := FALSE;
                WHEN MOV_eax_dw =>
                    IF (InstQueueWr_Addr - InstQueueRd_Addr) >= 5 THEN
                        -- Note Word position is swaped
                        EAX <= InstQueue(InstQueueRd_Addr+4) & InstQueue(InstQueueRd_Addr+3)
                                     & InstQueue(InstQueueRd_Addr+2) & InstQueue(InstQueueRd_Addr+1);
                        WAIT FOR 0 us;
                        IF Debug OR Inst THEN
                            report "DEBUG: Executing MOV-eax<-dw of:" & to_hstring(EAX);
                        END IF;
                        More := FALSE;
                        Flush := FALSE;
                        InstAddrPointer := InstAddrPointer + 5;
                        InstQueueRd_Addr := InstQueueRd_Addr + 5;
                    ELSE
                        Flush := FALSE;
                        More := TRUE;
                        IF Debug THEN
                            report "DEBUG: Executing MOV-eax<-dw but ...";
                            report "DEBUG: all of the immediate data is not in queue.";
                        END IF;
                    END IF;
                WHEN MOV_ebx_dw =>
                    IF (InstQueueWr_Addr - InstQueueRd_Addr) >= 5 THEN
                            
                        -- Note Word position is swaped
                        EBX <= InstQueue(InstQueueRd_Addr+4) & InstQueue(InstQueueRd_Addr+3)
                                     & InstQueue(InstQueueRd_Addr+2) & InstQueue(InstQueueRd_Addr+1);
                        WAIT FOR 0 us;
                        IF Debug OR Inst THEN
                            report "DEBUG: Executing MOV-ebx<-dw of:" & to_hstring(EBX);
                        END IF;
                        More := FALSE;
                        Flush := FALSE;
                        InstAddrPointer := InstAddrPointer + 5;
                        InstQueueRd_Addr := InstQueueRd_Addr + 5;
                    ELSE
                        Flush := FALSE;
                        More := TRUE;
                        IF Debug THEN
                            report "DEBUG: Executing MOV-ebx<-dw but ...";
                            report "DEBUG: all of the immediate data is not in queue.";
                        END IF;
                    END IF;
                WHEN MOV_eax_ebx =>  -- Read at [ebx] to eax register
                    IF (InstQueueWr_Addr - InstQueueRd_Addr) >= 2 THEN                            
                        IF Debug OR Inst THEN
                            report "DEBUG: Executing MOV-eax,[ebx] at address:" & to_hstring(EBX);
                        END IF;
                        rEIP <= EBX;
                        RequestPending <= Pending;
                        ReadRequest <= Pending;
                        MemoryFetch <= Pending;
                        CodeFetch <= NotPending;
                        WAIT UNTIL falling_edge(READY_n);
                        RequestPending <= NotPending;
                        WAIT UNTIL falling_edge(CLK);
                        uWord := Data(15 downto 0);
                        IF StateBS16 = '1' THEN
                            lWord := Data(31 downto 16);
                        ELSE
                            rEIP <= std_logic_vector(unsigned(rEIP) + 2);
                            WAIT FOR 0 us;
                            IF Debug THEN
                                report "DEBUG: Reading Second Word at Addr=" & to_hstring(rEIP);
                            END IF;
                            WAIT UNTIL rising_edge(CLK);
                            RequestPending <= Pending;
                            WAIT UNTIL falling_edge(READY_n);
                            RequestPending <= NotPending;
                            WAIT UNTIL falling_edge(CLK);
                            lWord := Data(15 downto 0);
                        END IF;
                        EAX <= uWord & lWord;
                        WAIT FOR 0 us;
                        IF Debug OR Inst THEN
                            report "DEBUG: Data=" & to_hstring(EAX);
                        END IF;
                        More := FALSE;
                        Flush := FALSE;
                        InstAddrPointer := InstAddrPointer + 2;
                        InstQueueRd_Addr := InstQueueRd_Addr + 2;
                    ELSE
                        Flush := FALSE;
                        More := TRUE;
                    END IF;
                WHEN MOV_ebx_eax =>  -- Write at [ebx] from eax register
                    IF (InstQueueWr_Addr - InstQueueRd_Addr) >= 2 THEN                            
                        IF Debug OR Inst THEN
                            report " DEBUG: Executing MOV-[ebx],eax at address:" & to_hstring(EBX);
                        END IF;
                        rEIP <= EBX;
                        lWord := EAX(15 downto 0);
                        uWord := EAX(31 downto 16);
                        IF Debug OR Inst THEN
                            report "DEBUG: Data=" & to_hstring(EAX);
                        END IF;
                        RequestPending <= Pending;
                        ReadRequest <= NotPending;
                        MemoryFetch <= Pending;
                        CodeFetch <= NotPending;
                        IF Debug THEN
                            report "DEBUG: Writing First Word at Addr=" & to_hstring(EBX);
                        END IF;
                        WAIT UNTIL (State = StateT1 OR State = StateT1P);
                        WAIT UNTIL rising_edge(CLK);
                        Data <= (uWord & lWord) after 48 ns;
                        WAIT UNTIL falling_edge(READY_n);
                        RequestPending <= NotPending;
                        WAIT UNTIL rising_edge(CLK);
                        Data <= X"ZZZZZZZZ" after 48 ns;
                        wait for 0 us;
                        IF StateBS16 = '0' THEN
                            IF Debug THEN
                                report "DEBUG: Writing Second Word at Addr=" & to_hstring(EBX);
                            END IF;
                            rEIP <= std_logic_vector(unsigned(rEIP) + 2);
                            RequestPending <= Pending;
                            ReadRequest <= NotPending;
                            MemoryFetch <= Pending;
                            CodeFetch <= NotPending;
                            WAIT UNTIL (State = StateT1 OR State = StateT1P);
                            WAIT UNTIL rising_edge(CLK);
                            Data <= (uWord & lWord) after 48 ns;
                            WAIT UNTIL falling_edge(READY_n);
                            RequestPending <= NotPending;
                            WAIT UNTIL rising_edge(CLK);
                            Data <= X"ZZZZZZZZ" after 48 ns;
                            wait for 0 us;
                        END IF;
                        More := FALSE;
                        Flush := FALSE;
                        InstAddrPointer := InstAddrPointer + 2;
                        InstQueueRd_Addr := InstQueueRd_Addr + 2;
                    ELSE
                        Flush := FALSE;
                        More := TRUE;
                    END IF;
                WHEN IN_al =>
                    IF (InstQueueWr_Addr - InstQueueRd_Addr) >= 2 THEN
                        rEIP <= (7 downto 0 => InstQueue(InstQueueRd_Addr+1), others => '0');
                        WAIT FOR 0 us;
                            
                        RequestPending <= Pending;
                        ReadRequest <= Pending;
                        MemoryFetch <= NotPending;
                        CodeFetch <= NotPending;
                        WAIT UNTIL falling_edge(READY_n);
                        RequestPending <= NotPending;
                        WAIT UNTIL falling_edge(CLK);
                        EAX(7 downto 0) <= Data(7 downto 0);
                        WAIT FOR 0 us;
                        IF Debug OR Inst THEN
                            report "DEBUG: Executing IN-al from:" & to_hstring(rEIP) & " Data=" & to_hstring(EAX(7 downto 0));
                        END IF;
                        InstAddrPointer := InstAddrPointer + 2;
                        InstQueueRd_Addr := InstQueueRd_Addr + 2;
                        Flush := FALSE;
                        More := FALSE;
                    ELSE
                        Flush := FALSE;
                        More := TRUE;
                        IF Debug THEN
                            report "DEBUG: Executing IN-al but ...";
                            report "DEBUG: the immediate Address is not in queue.";
                        END IF;
                    END IF;
                WHEN OUT_al =>
                    IF (InstQueueWr_Addr - InstQueueRd_Addr) >= 2 THEN
                            
                        rEIP <= (7 downto 0 => InstQueue(InstQueueRd_Addr+1), others => '0');
                        wait for 0 us;
                            
                        RequestPending <= Pending;
                        ReadRequest <= NotPending;
                        MemoryFetch <= NotPending;
                        CodeFetch <= NotPending;
                        IF Debug OR Inst THEN
                            report "DEBUG: Executing OUT-al to:" & to_hstring(rEIP) & " Data=" & to_hstring(EAX(7 downto 0));
                        END IF;
                        WAIT UNTIL (State = StateT1 OR State = StateT1P);
                        WAIT UNTIL rising_edge(CLK);
                        fWord := X"ZZZZZZ" & EAX(7 downto 0);
                        Data <= fWord after 48 ns;
                        WAIT UNTIL falling_edge(READY_n);
                        RequestPending <= NotPending;
                        WAIT UNTIL rising_edge(CLK);
                        Data <= X"ZZZZZZZZ" after 48 ns;
                        wait for 0 us;
                        InstAddrPointer := InstAddrPointer + 2;
                        InstQueueRd_Addr := InstQueueRd_Addr + 2;
                        Flush := FALSE;
                        More := FALSE;
                    ELSE
                        Flush := FALSE;
                        More := TRUE;
                        IF Debug THEN
                            report "DEBUG: Executing OUT-al but ...";
                            report "DEBUG: the immediate Address is not in queue.";
                        END IF;
                    END IF;
                WHEN ADD_al_b =>
-- To be Implemented (mad/8-23-1988)
                    IF Debug OR Inst THEN
                        report "DEBUG: {TBD} Executing ADD-al to byte:";
                    END IF;
                    InstAddrPointer := InstAddrPointer + 1;
                    InstQueueRd_Addr := InstQueueRd_Addr + 1;
                    Flush := FALSE;
                    More := FALSE;
                WHEN ADD_ax_w =>
-- To be Implemented (mad/8-23-1988)
                    IF Debug OR Inst THEN
                        report "DEBUG: {TBD} Executing ADD-ax to word:";
                    END IF;
                    InstAddrPointer := InstAddrPointer + 1;
                    InstQueueRd_Addr := InstQueueRd_Addr + 1;
                    Flush := FALSE;
                    More := FALSE;
                WHEN ROL_al_1 =>
-- To be Implemented (mad/8-23-1988)
                    IF Debug OR Inst THEN
                        report "DEBUG: {TBD} Executing ROL-al left one bit";
                    END IF;
                    InstAddrPointer := InstAddrPointer + 2;
                    InstQueueRd_Addr := InstQueueRd_Addr + 2;
                    Flush := FALSE;
                    More := FALSE;
                WHEN ROL_al_n =>
-- To be Implemented (mad/8-23-1988)
                    IF Debug OR Inst THEN
                        report "DEBUG: {TBD} Executing ROL-al by:";
                    END IF;
                    InstAddrPointer := InstAddrPointer + 2;
                    InstQueueRd_Addr := InstQueueRd_Addr + 2;
                    Flush := FALSE;
                    More := FALSE;
                WHEN INC_eax =>
                    EAX <= std_logic_vector(unsigned(EAX) + 1);
                    wait for 0 us;
                    IF Debug OR Inst THEN
                        report "DEBUG: Executing INC-eax by 1 to:" & to_hstring(EAX);
                    END IF;
                    InstAddrPointer := InstAddrPointer + 1;
                    InstQueueRd_Addr := InstQueueRd_Addr + 1;
                    Flush := FALSE;
                    More := FALSE;
                WHEN INC_ebx =>
                    EBX <= std_logic_vector(unsigned(EBX) + 1);
                    wait for 0 us;
                    IF Debug OR Inst THEN
                        report "DEBUG: Executing INC-ebx by 1 to:" & to_hstring(EBX);
                    END IF;
                    InstAddrPointer := InstAddrPointer + 1;
                    InstQueueRd_Addr := InstQueueRd_Addr + 1;
                    Flush := FALSE;
                    More := FALSE;
                WHEN OTHERS  =>
                    report "ERROR: Invalid Instruction=" & to_hstring(InstQueue(InstQueueRd_Addr));
                    InstAddrPointer := InstAddrPointer + 1;
                    InstQueueRd_Addr := InstQueueRd_Addr + 1;
                    Flush := FALSE;
                    More := FALSE;
            END CASE;
            EXIT WHEN ((InstQueueLimit - InstQueueRd_Addr) < 4) OR Flush OR More;
        END LOOP Decode;
        IF Flush THEN
            InstQueueRd_Addr := 1;
            InstQueueWr_Addr := 1;
            fWord := std_logic_vector(to_signed(InstAddrPointer, fWord'length));
            IF fWord(0) = '1' THEN
                InstQueueRd_Addr := InstQueueRd_Addr + to_integer(unsigned(fWord(1 downto 0)));
            END IF;
            IF Debug THEN
                report "DEBUG: Flushing Instruction Queue";
            END IF;
        END IF;
        IF (InstQueueLimit - InstQueueRd_Addr) < 3 THEN -- The queue is about to be bounded.
            -- This section implements the circular queue.
            IF Debug THEN
                report "DEBUG: Instruction Queue Length Execeeded";
                report "DEBUG: Implementing Circular Queue";
            END IF;
            InstQueueWr_Addr := 1;
            Circular: WHILE InstQueueRd_Addr <= InstQueueLimit LOOP
                InstQueue(InstQueueWr_Addr) := InstQueue(InstQueueRd_Addr);
                InstQueueRd_Addr := InstQueueRd_Addr + 1;
                InstQueueWr_Addr := InstQueueWr_Addr + 1;
            END LOOP Circular;
            InstQueueRd_Addr := 1;
        END IF;
        IF Debug THEN
            report "DEBUG: Request Pending, filling Queue at:" & integer'image(InstQueueWr_Addr);
        END IF;
        rEIP <= std_logic_vector(to_signed(PhyAddrPointer,rEIP'length));
        WAIT UNTIL rising_edge(CLK);
    end PROCESS InstDecode;
    -- Instruction Pre-Fetch, Decode and Execution Unit Begin
       
    -- ByteEnables Begin
    GenByteEnables: PROCESS (rEIP)
    BEGIN
        CASE to_integer(unsigned(DataWidth)) is
            WHEN WidthByte =>
                CASE to_integer(unsigned(rEIP(1 downto 0))) is -- A[1:0]
                    WHEN 0 =>
                        ByteEnable <= B"1110";
                    WHEN 1 =>
                        ByteEnable <= B"1101";
                    WHEN 2 =>
                        ByteEnable <= B"1011";
                    WHEN 3 =>
                        ByteEnable <= B"0111";
                    WHEN OTHERS  => NULL;
                END CASE;
            WHEN WidthWord =>
                CASE to_integer(unsigned(rEIP(1 downto 0))) is -- A[1:0]
                    WHEN 0 =>
                        ByteEnable <= B"1100";
                        NonAligned <= NotPending;
                    WHEN 1 =>
                        ByteEnable <= B"1001";
                        NonAligned <= NotPending;
                    WHEN 2 =>
                        ByteEnable <= B"0011";
                        NonAligned <= NotPending;
                    WHEN 3 =>
                        IF Debug THEN
                            report "DEBUG: Non-Aligned Word";
                        END IF;
                        ByteEnable <= B"0111";
                        NonAligned <= Pending;
                    WHEN OTHERS  => NULL;
                END CASE;
            WHEN WidthDword =>
                CASE to_integer(unsigned(rEIP(1 downto 0))) is -- A[1:0]
                    WHEN 0 =>
                        ByteEnable <= B"0000";
                        NonAligned <= NotPending;
                    WHEN 1 =>
                        IF Debug THEN
                            report "DEBUG: Non-Aligned Dword";
                        END IF;
                        ByteEnable <= B"0001";
                        NonAligned <= Pending;
                    WHEN 2 =>
                        IF Debug THEN
                            report "DEBUG: Non-Aligned Dword";
                        END IF;
                        NonAligned <= Pending;
                        ByteEnable <= B"0011";
                    WHEN 3 =>
                        IF Debug THEN
                            report "DEBUG: Non-Aligned Dword";
                        END IF;
                        NonAligned <= Pending;
                        ByteEnable <= B"0111";
                    WHEN OTHERS  => NULL;
                END CASE;
            WHEN OTHERS  =>
                report "MODEL ERROR: Data Path Width Fault: DataWidth";
                report "MODEL ERROR: Width Selected was:" & integer'image(to_integer(unsigned(DataWidth)));
        END CASE;
    end PROCESS GenByteEnables;
    -- ByteEnables End

    -- Bus Interface Unit Begin
    GenBusIntf: PROCESS (State)
    BEGIN
        CASE State is
            WHEN StateT1 | StateT2P =>
                Address <= rEIP(31 downto 2) after 40 ns;
                IF Debug THEN
--                  putline("DEBUG: Next Address=",rEIP);
                END IF;
                BE_n <= ByteEnable after 30 ns;
                M_IO_n <= MemoryFetch;
                IF ReadRequest = Pending THEN
                    W_R_n <= '0' after 30 ns;
                ELSE
                    W_R_n <= '1' after 30 ns;
                END IF;
                IF CodeFetch = Pending THEN
                    D_C_n <= '0' after 30 ns;
                ELSE
                    D_C_n <= '1' after 30 ns;
                END IF;
            WHEN OTHERS  => NULL;
        END CASE;
        CASE State is
            WHEN StateT1  => ADS_n <= '0' after 25 ns;
            WHEN StateT2  => ADS_n <= '1' after 25 ns;
            WHEN StateT1P => ADS_n <= '1' after 25 ns;
            WHEN StateT2P => ADS_n <= '0' after 25 ns;
            WHEN OTHERS  => NULL;
        END CASE;
    end PROCESS GenBusIntf;

    BS16: PROCESS
    BEGIN
        WAIT UNTIL State = StateT2 OR State = StateT1P;
        WHILE State = StateT2 OR State = StateT1P LOOP
            WAIT UNTIL rising_edge(CLK);
            StateBS16 <= BS16_n;
            IF BS16_n = '0' THEN
                DataWidth <= std_logic_vector(to_unsigned(Widthword, DataWidth'length)); -- WidthByte, WidthWord, WidthDword
            ELSE
                DataWidth <= std_logic_vector(to_unsigned(WidthDword, DataWidth'length));
            END IF;
        END LOOP;
    end PROCESS BS16;

    NA: PROCESS
    BEGIN
        WAIT UNTIL State = StateT2 OR State = StateT1P;
        WAIT UNTIL rising_edge(CLK);
        StateNA <= NA_n;
    end PROCESS NA;

    -- Bus Interface Unit End
-- End Behavioral Blocks

end behavior;

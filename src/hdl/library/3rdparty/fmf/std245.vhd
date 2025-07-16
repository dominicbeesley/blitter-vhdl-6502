--------------------------------------------------------------------------------
--   File Name : std245.vhd
--------------------------------------------------------------------------------
--  Copyright (C) 1995-2007 Free Model Foundry; http://www.FreeModelFoundry.com
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License version 2 as
--  published by the Free Software Foundation.
--
--  MODIFICATION HISTORY :
--
--  version: |    author: |   mod. date: |    changes made:
--    V1.0         rev3       95 DEC 08   Initial release
--    V1.1      R. Munden     97 MAY 25   Conformed to style guide
--    V1.2     D.Vukicevic    05 JUL 07   Style guide: replaced tabs with spaces
--    V2.0      R. Munden     07 JUN 12   Replaced VITAL primitives with 
--                                        VitalTruthTable
--------------------------------------------------------------------------------
--  PART DESCRIPTION:
--
--  Library:     STD
--  Technology:  54/74XXXX
--  Part:        STD245
--
--  Desciption:  8-bit TTL Transceiver
--------------------------------------------------------------------------------

LIBRARY IEEE;    USE IEEE.std_logic_1164.ALL;
                 USE IEEE.VITAL_primitives.all;
                 USE IEEE.VITAL_timing.all;
LIBRARY FMF;     USE FMF.gen_utils.ALL;

--------------------------------------------------------------------------------
-- ENTITY DECLARATION
--------------------------------------------------------------------------------
ENTITY std245 IS
    GENERIC (
        -- tipd delays: interconnect path delays
        tipd_A          : VitalDelayType01 := VitalZeroDelay01;
        tipd_B          : VitalDelayType01 := VitalZeroDelay01;
        tipd_DIR        : VitalDelayType01 := VitalZeroDelay01;
        tipd_ENeg       : VitalDelayType01 := VitalZeroDelay01;
        -- tpd delays:
        tpd_A_B         : VitalDelayType01 := UnitDelay01;
        tpd_B_A         : VitalDelayType01 := UnitDelay01;
        tpd_DIR_A       : VitalDelayType01Z := UnitDelay01Z;
        tpd_DIR_B       : VitalDelayType01Z := UnitDelay01Z;
        tpd_ENeg_A      : VitalDelayType01Z := UnitDelay01Z;
        tpd_ENeg_B      : VitalDelayType01Z := UnitDelay01Z;
        -- generic control parameters
        TimingChecksOn  : BOOLEAN   := DefaultTimingChecks;
        MsgOn               : BOOLEAN := DefaultMsgOn;
        XOn                 : Boolean  := DefaultXOn;
        InstancePath    : STRING    := DefaultInstancePath;
        -- For FMF SDF techonology file usage
        TimingModel         : STRING   := DefaultTimingModel
        );
    PORT (
        A               : INOUT std_ulogic := 'U';
        B               : INOUT std_ulogic := 'U';
        ENeg            : IN    std_ulogic := 'U';
        DIR             : IN    std_ulogic := 'U'
    );

    ATTRIBUTE VITAL_LEVEL0 of std245 : ENTITY IS TRUE;
END std245;

--------------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION
--------------------------------------------------------------------------------
ARCHITECTURE vhdl_behavioral of std245 IS
    ATTRIBUTE VITAL_LEVEL1 of vhdl_behavioral : ARCHITECTURE IS TRUE;

    SIGNAL A_ipd            : std_ulogic := 'X';
    SIGNAL B_ipd            : std_ulogic := 'X';
    SIGNAL DIR_ipd          : std_ulogic := 'X';
    SIGNAL ENeg_ipd         : std_ulogic := 'X';

BEGIN

    ----------------------------------------------------------------------------
    -- Wire Delays
    ----------------------------------------------------------------------------
    WireDelay : BLOCK
    BEGIN

        w1: VitalWireDelay (A_ipd, A, tipd_A);
        w2: VitalWireDelay (B_ipd, B, tipd_B);
        w3: VitalWireDelay (DIR_ipd, DIR, tipd_DIR);
        w4: VitalWireDelay (ENeg_ipd, ENeg, tipd_ENeg);

    END BLOCK;

    ----------------------------------------------------------------------------
    -- VITALBehavior Process
    ----------------------------------------------------------------------------
    VITALBehavior1 : PROCESS(A_ipd, B_ipd, DIR_ipd, ENeg_ipd)

        CONSTANT std245_tab : VitalTruthTableType := (
        ----------------------------------------------
        ---INPUTS---|---OUTPUTS---
        --E    D    A    B  |  A    B
        ----------------------------------------------
        ('1', '-', '-', '-', 'Z', 'Z'),
        ('X', '-', '-', '-', 'X', 'X'),
        ('-', 'X', '-', '-', 'X', 'X'),
        ('0', '0', '-', '0', '0', 'Z'),
        ('0', '0', '-', '1', '1', 'Z'),
        ('0', '0', '-', 'X', 'X', 'Z'),
        ('0', '1', '0', '-', 'Z', '0'),
        ('0', '1', '1', '-', 'Z', '1'),
        ('0', '1', 'X', '-', 'Z', 'X')
        );

        -- Functionality Results Variables
        VARIABLE OData : std_logic_vector(0 to 1);
        ALIAS A_zd     : std_ulogic IS OData(0);
        ALIAS B_zd     : std_ulogic IS OData(1);

        -- Output Glitch Detection Variables
        VARIABLE A_GlitchData : VitalGlitchDataType;
        VARIABLE B_GlitchData : VitalGlitchDataType;

    BEGIN

        ------------------------------------------------------------------------
        -- Functionality Section
        ------------------------------------------------------------------------
        OData := VitalTruthTable (
                    TruthTable => std245_tab,
                    DataIn     => (ENeg_ipd, DIR_ipd, A_ipd, B_ipd)
                 );

        ------------------------------------------------------------------------
        -- Path Delay Section
        ------------------------------------------------------------------------
        VitalPathDelay01Z (
            OutSignal       =>  A,
            OutSignalName   =>  "A",
            OutTemp         =>  A_zd,
            Paths           => (
                0 => (InputChangeTime   => B_ipd'LAST_EVENT,
                      PathDelay         => VitalExtendToFillDelay(tpd_B_A),
                      PathCondition     => TRUE ),
                1 => (InputChangeTime   => DIR_ipd'LAST_EVENT,
                      PathDelay         => tpd_DIR_A,
                      PathCondition     => TRUE ),
                2 => (InputChangeTime   => ENeg_ipd'LAST_EVENT,
                      PathDelay         => tpd_ENeg_A,
                      PathCondition     => TRUE ) ),
            GlitchData      => A_GlitchData );

        VitalPathDelay01Z (
            OutSignal       =>  B,
            OutSignalName   =>  "B",
            OutTemp         =>  B_zd,
            Paths           => (
                0 => (InputChangeTime   => A_ipd'LAST_EVENT,
                      PathDelay         => VitalExtendToFillDelay(tpd_A_B),
                      PathCondition     => TRUE ),
                1 => (InputChangeTime   => DIR_ipd'LAST_EVENT,
                      PathDelay         => tpd_DIR_B,
                      PathCondition     => TRUE ),
                2 => (InputChangeTime   => ENeg_ipd'LAST_EVENT,
                      PathDelay         => tpd_ENeg_B,
                      PathCondition     => TRUE ) ),
            GlitchData      => B_GlitchData );

    END PROCESS;

END vhdl_behavioral;

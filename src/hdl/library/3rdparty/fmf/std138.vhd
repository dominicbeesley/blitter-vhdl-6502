--------------------------------------------------------------------------------
--  File Name: std138.vhd
--------------------------------------------------------------------------------
--  Copyright (C) 1997 Free Model Foundry; http://www.FreeModelFoundry.com
-- 
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License version 2 as
--  published by the Free Software Foundation.
-- 
--  MODIFICATION HISTORY:
-- 
--  version: |  author:  | mod date: | changes made
--    V1.0     R. Munden   97 SEP 11   Conformed to style guide
--------------------------------------------------------------------------------
--  PART DESCRIPTION:
-- 
--  Library:     STD
--  Technology:  54/74XXXX
--  Part:        STD138
-- 
--  Desciption:  3 to 8 decoder
--------------------------------------------------------------------------------

LIBRARY IEEE;    USE IEEE.std_logic_1164.ALL;
                 USE IEEE.VITAL_timing.ALL;
                 USE IEEE.VITAL_primitives.ALL;
LIBRARY FMF;     USE FMF.gen_utils.ALL;

--------------------------------------------------------------------------------
-- ENTITY DECLARATION
--------------------------------------------------------------------------------
ENTITY std138 IS
    GENERIC (
        -- tipd delays: interconnect path delays
        tipd_A              : VitalDelayType01 := VitalZeroDelay01;
        tipd_B              : VitalDelayType01 := VitalZeroDelay01;
        tipd_C              : VitalDelayType01 := VitalZeroDelay01;
        tipd_G1             : VitalDelayType01 := VitalZeroDelay01;
        tipd_G2ANeg         : VitalDelayType01 := VitalZeroDelay01;
        tipd_G2BNeg         : VitalDelayType01 := VitalZeroDelay01;
        -- tpd delays
        tpd_A_Y0Neg         : VitalDelayType01 := UnitDelay01;
        tpd_G1_Y0Neg        : VitalDelayType01 := UnitDelay01;
        tpd_G2ANeg_Y0Neg    : VitalDelayType01 := UnitDelay01;
        -- generic control parameters
        InstancePath        : STRING   := DefaultInstancePath;
        MsgOn               : BOOLEAN  := DefaultMsgOn;
        XOn                 : BOOLEAN  := DefaultXOn;
        -- For FMF SDF techonology file usage
        TimingModel         : STRING   := DefaultTimingModel
    );
    PORT (
        A           : IN    std_logic := 'X';
        B           : IN    std_logic := 'X';
        C           : IN    std_logic := 'X';
        G1          : IN    std_logic := 'X';
        G2ANeg      : IN    std_logic := 'X';
        G2BNeg      : IN    std_logic := 'X';
        Y0Neg       : OUT   std_logic := 'U';
        Y1Neg       : OUT   std_logic := 'U';
        Y2Neg       : OUT   std_logic := 'U';
        Y3Neg       : OUT   std_logic := 'U';
        Y4Neg       : OUT   std_logic := 'U';
        Y5Neg       : OUT   std_logic := 'U';
        Y6Neg       : OUT   std_logic := 'U';
        Y7Neg       : OUT   std_logic := 'U'
    );
    ATTRIBUTE VITAL_LEVEL0 of std138 : ENTITY IS TRUE;
END std138;

--------------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION
--------------------------------------------------------------------------------
ARCHITECTURE vhdl_behavioral of std138 IS
    ATTRIBUTE VITAL_LEVEL1 of vhdl_behavioral : ARCHITECTURE IS TRUE;

    SIGNAL A_ipd        : std_ulogic := 'X';
    SIGNAL B_ipd        : std_ulogic := 'X';
    SIGNAL C_ipd        : std_ulogic := 'X';
    SIGNAL G1_ipd       : std_ulogic := 'X';
    SIGNAL G2ANeg_ipd   : std_ulogic := 'X';
    SIGNAL G2BNeg_ipd   : std_ulogic := 'X';
    SIGNAL G2int        : std_ulogic := 'X';

BEGIN
    ----------------------------------------------------------------------------
    -- Wire Delays
    ----------------------------------------------------------------------------
    WireDelay : BLOCK
    BEGIN

        w_1: VitalWireDelay (A_ipd, A, tipd_A);
        w_2: VitalWireDelay (B_ipd, B, tipd_B);
        w_3: VitalWireDelay (C_ipd, C, tipd_C);
        w_4: VitalWireDelay (G1_ipd, G1, tipd_G1);
        w_5: VitalWireDelay (G2ANeg_ipd, G2ANeg, tipd_G2ANeg);
        w_6: VitalWireDelay (G2BNeg_ipd, G2BNeg, tipd_G2BNeg);

    END BLOCK;

    ----------------------------------------------------------------------------
    -- Concurrent procedure calls
    ----------------------------------------------------------------------------
    a_1: VitalOR2 (
            q         => G2int,
            a         => G2ANeg_ipd,
            b         => G2BNeg_ipd
         );

    ----------------------------------------------------------------------------
    -- Decode Process
    ----------------------------------------------------------------------------
    Decode : PROCESS (G1_ipd, G2int, C_ipd, B_ipd, A_ipd)

        CONSTANT std138_tab : VitalTruthTableType := (
            ----------------------------------------------------------------
            ---------INPUTS---------|---------------OUTPUTS-----------------
            --G1  G2    C    B    A | Y0   Y1   Y2   Y3   Y4   Y5   Y6   Y7
            -----------------------------------------------------------------
            ('-', '1', '-', '-', '-', '1', '1', '1', '1', '1', '1', '1', '1'), 
            ('0', '-', '-', '-', '-', '1', '1', '1', '1', '1', '1', '1', '1'), 
            ('1', '0', '0', '0', '0', '0', '1', '1', '1', '1', '1', '1', '1'), 
            ('1', '0', '0', '0', '1', '1', '0', '1', '1', '1', '1', '1', '1'), 
            ('1', '0', '0', '1', '0', '1', '1', '0', '1', '1', '1', '1', '1'), 
            ('1', '0', '0', '1', '1', '1', '1', '1', '0', '1', '1', '1', '1'), 
            ('1', '0', '1', '0', '0', '1', '1', '1', '1', '0', '1', '1', '1'), 
            ('1', '0', '1', '0', '1', '1', '1', '1', '1', '1', '0', '1', '1'), 
            ('1', '0', '1', '1', '0', '1', '1', '1', '1', '1', '1', '0', '1'), 
            ('1', '0', '1', '1', '1', '1', '1', '1', '1', '1', '1', '1', '0')
        );

        -- Functionality Results Variables
        VARIABLE YData          : std_logic_vector(0 to 7);
        ALIAS Y0_zd             : std_ulogic IS YData(0);
        ALIAS Y1_zd             : std_ulogic IS YData(1);
        ALIAS Y2_zd             : std_ulogic IS YData(2);
        ALIAS Y3_zd             : std_ulogic IS YData(3);
        ALIAS Y4_zd             : std_ulogic IS YData(4);
        ALIAS Y5_zd             : std_ulogic IS YData(5);
        ALIAS Y6_zd             : std_ulogic IS YData(6);
        ALIAS Y7_zd             : std_ulogic IS YData(7);


        -- Output Glitch Detection Variables
        VARIABLE Y0_GlitchData  : VitalGlitchDataType;
        VARIABLE Y1_GlitchData  : VitalGlitchDataType;
        VARIABLE Y2_GlitchData  : VitalGlitchDataType;
        VARIABLE Y3_GlitchData  : VitalGlitchDataType;
        VARIABLE Y4_GlitchData  : VitalGlitchDataType;
        VARIABLE Y5_GlitchData  : VitalGlitchDataType;
        VARIABLE Y6_GlitchData  : VitalGlitchDataType;
        VARIABLE Y7_GlitchData  : VitalGlitchDataType;

    BEGIN
        ------------------------------------------------------------------------
        -- Functionality Section
        ------------------------------------------------------------------------
        YData := VitalTruthTable (
                    TruthTable  => std138_tab,
                    DataIn      => (G1_ipd, G2int, C_ipd, B_ipd, A_ipd)
                 );

        ------------------------------------------------------------------------
        -- Path Delay Section
        ------------------------------------------------------------------------
        VitalPathDelay01 (
            OutSignal       => Y0Neg,
            OutSignalName   => "Y0Neg",
            OutTemp         => Y0_zd,
            GlitchData      => Y0_GlitchData,
            XOn             => XOn,
            MsgOn           => MsgOn,
            Paths           => (
                0 => (
                    InputChangeTime => G1_ipd'LAST_EVENT,
                    PathDelay       => tpd_G1_Y0Neg,
                    PathCondition   => TRUE),
                1 => (
                    InputChangeTime => G2int'LAST_EVENT,
                    PathDelay       => tpd_G2ANeg_Y0Neg,
                    PathCondition   => TRUE),
                2 => (
                    InputChangeTime => A_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')),
                3 => (
                    InputChangeTime => B_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')),
                4 => (
                    InputChangeTime => C_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')))
            );

        VitalPathDelay01 (
            OutSignal       => Y1Neg,
            OutSignalName   => "Y1Neg",
            OutTemp         => Y1_zd,
            GlitchData      => Y1_GlitchData,
            XOn             => XOn,
            MsgOn           => MsgOn,
            Paths           => (
                0 => (
                    InputChangeTime => G1_ipd'LAST_EVENT,
                    PathDelay       => tpd_G1_Y0Neg,
                    PathCondition   => TRUE),
                1 => (
                    InputChangeTime => G2int'LAST_EVENT,
                    PathDelay       => tpd_G2ANeg_Y0Neg,
                    PathCondition   => TRUE),
                2 => (
                    InputChangeTime => A_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')),
                3 => (
                    InputChangeTime => B_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')),
                4 => (
                    InputChangeTime => C_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')))
            );

        VitalPathDelay01 (
            OutSignal       => Y2Neg,
            OutSignalName   => "Y2Neg",
            OutTemp         => Y2_zd,
            GlitchData      => Y2_GlitchData,
            XOn             => XOn,
            MsgOn           => MsgOn,
            Paths           => (
                0 => (
                    InputChangeTime => G1_ipd'LAST_EVENT,
                    PathDelay       => tpd_G1_Y0Neg,
                    PathCondition   => TRUE),
                1 => (
                    InputChangeTime => G2int'LAST_EVENT,
                    PathDelay       => tpd_G2ANeg_Y0Neg,
                    PathCondition   => TRUE),
                2 => (
                    InputChangeTime => A_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')),
                3 => (
                    InputChangeTime => B_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')),
                4 => (
                    InputChangeTime => C_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')))
            );

        VitalPathDelay01 (
            OutSignal       => Y3Neg,
            OutSignalName   => "Y3Neg",
            OutTemp         => Y3_zd,
            GlitchData      => Y3_GlitchData,
            XOn             => XOn,
            MsgOn           => MsgOn,
            Paths           => (
                0 => (
                    InputChangeTime => G1_ipd'LAST_EVENT,
                    PathDelay       => tpd_G1_Y0Neg,
                    PathCondition   => TRUE),
                1 => (
                    InputChangeTime => G2int'LAST_EVENT,
                    PathDelay       => tpd_G2ANeg_Y0Neg,
                    PathCondition   => TRUE),
                2 => (
                    InputChangeTime => A_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')),
                3 => (
                    InputChangeTime => B_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')),
                4 => (
                    InputChangeTime => C_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')))
            );

        VitalPathDelay01 (
            OutSignal       => Y4Neg,
            OutSignalName   => "Y4Neg",
            OutTemp         => Y4_zd,
            GlitchData      => Y4_GlitchData,
            XOn             => XOn,
            MsgOn           => MsgOn,
            Paths           => (
                0 => (
                    InputChangeTime => G1_ipd'LAST_EVENT,
                    PathDelay       => tpd_G1_Y0Neg,
                    PathCondition   => TRUE),
                1 => (
                    InputChangeTime => G2int'LAST_EVENT,
                    PathDelay       => tpd_G2ANeg_Y0Neg,
                    PathCondition   => TRUE),
                2 => (
                    InputChangeTime => A_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')),
                3 => (
                    InputChangeTime => B_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')),
                4 => (
                    InputChangeTime => C_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')))
            );

        VitalPathDelay01 (
            OutSignal       => Y5Neg,
            OutSignalName   => "Y5Neg",
            OutTemp         => Y5_zd,
            GlitchData      => Y5_GlitchData,
            XOn             => XOn,
            MsgOn           => MsgOn,
            Paths           => (
                0 => (
                    InputChangeTime => G1_ipd'LAST_EVENT,
                    PathDelay       => tpd_G1_Y0Neg,
                    PathCondition   => TRUE),
                1 => (
                    InputChangeTime => G2int'LAST_EVENT,
                    PathDelay       => tpd_G2ANeg_Y0Neg,
                    PathCondition   => TRUE),
                2 => (
                    InputChangeTime => A_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')),
                3 => (
                    InputChangeTime => B_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')),
                4 => (
                    InputChangeTime => C_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')))
            );

        VitalPathDelay01 (
            OutSignal       => Y6Neg,
            OutSignalName   => "Y6Neg",
            OutTemp         => Y6_zd,
            GlitchData      => Y6_GlitchData,
            XOn             => XOn,
            MsgOn           => MsgOn,
            Paths           => (
                0 => (
                    InputChangeTime => G1_ipd'LAST_EVENT,
                    PathDelay       => tpd_G1_Y0Neg,
                    PathCondition   => TRUE),
                1 => (
                    InputChangeTime => G2int'LAST_EVENT,
                    PathDelay       => tpd_G2ANeg_Y0Neg,
                    PathCondition   => TRUE),
                2 => (
                    InputChangeTime => A_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')),
                3 => (
                    InputChangeTime => B_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')),
                4 => (
                    InputChangeTime => C_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')))
            );

        VitalPathDelay01 (
            OutSignal       => Y7Neg,
            OutSignalName   => "Y7Neg",
            OutTemp         => Y7_zd,
            GlitchData      => Y7_GlitchData,
            XOn             => XOn,
            MsgOn           => MsgOn,
            Paths           => (
                0 => (
                    InputChangeTime => G1_ipd'LAST_EVENT,
                    PathDelay       => tpd_G1_Y0Neg,
                    PathCondition   => TRUE),
                1 => (
                    InputChangeTime => G2int'LAST_EVENT,
                    PathDelay       => tpd_G2ANeg_Y0Neg,
                    PathCondition   => TRUE),
                2 => (
                    InputChangeTime => A_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')),
                3 => (
                    InputChangeTime => B_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')),
                4 => (
                    InputChangeTime => C_ipd'LAST_EVENT,
                    PathDelay       => tpd_A_Y0Neg,
                    PathCondition   => ((G1_ipd = '1') AND G2int = '1')))
            );

    END PROCESS;

END vhdl_behavioral;

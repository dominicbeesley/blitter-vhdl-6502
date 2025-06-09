-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2025 Dominic Beesley https://github.com/dominicbeesley
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
-- ----------------------------------------------------------------------

-- Company:          Dossytronics
-- Engineer:         Dominic Beesley
-- 
-- Create Date:      9/6/2025
-- Design Name: 
-- Module Name:      sim_peripherals_csel
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      c20k peripherals chip select board sim 
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--                   Does basic delays and timings for the chip select in the mux
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library fmf;

entity sim_peripherals_csel is
   port(
      clk_2MHzE_i    :  in std_logic;
      nCS_i          :  in std_logic_vector(3 downto 0);

      nADLC_o        : out std_logic;
      nKBPAWR_o      : out std_logic;
      nIC32WR_o      : out std_logic;
      nPGFC_o        : out std_logic;
      nPGFD_o        : out std_logic;
      nTUBE_o        : out std_logic;
      nFDC_o         : out std_logic;
      nFDCONWR_o     : out std_logic;
      nVIAB_o        : out std_logic
   );
end sim_peripherals_csel;

architecture rtl of sim_peripherals_csel is


begin


e_138_a:entity fmf.std138
--    GENERIC MAP(
--        -- tipd delays: interconnect path delays
--        tipd_A              : VitalDelayType01 := VitalZeroDelay01;
--        tipd_B              : VitalDelayType01 := VitalZeroDelay01;
--        tipd_C              : VitalDelayType01 := VitalZeroDelay01;
--        tipd_G1             : VitalDelayType01 := VitalZeroDelay01;
--        tipd_G2ANeg         : VitalDelayType01 := VitalZeroDelay01;
--        tipd_G2BNeg         : VitalDelayType01 := VitalZeroDelay01;
--        -- tpd delays
--        tpd_A_Y0Neg         : VitalDelayType01 := UnitDelay01;
--        tpd_G1_Y0Neg        : VitalDelayType01 := UnitDelay01;
--        tpd_G2ANeg_Y0Neg    : VitalDelayType01 := UnitDelay01;
--        -- generic control parameters
--        InstancePath        : STRING   := DefaultInstancePath;
--        MsgOn               : BOOLEAN  := DefaultMsgOn;
--        XOn                 : BOOLEAN  := DefaultXOn;
--        -- For FMF SDF techonology file usage
--        TimingModel         : STRING   := DefaultTimingModel
--    );
    PORT MAP(
        A           => nCS_i(0),
        B           => nCS_i(1),
        C           => nCS_i(2),
        G1          => clk_2MHzE_i,
        G2ANeg      => nCS_i(3),
        G2BNeg      => nCS_i(3),
        Y0Neg       => open,
        Y1Neg       => open,
        Y2Neg       => open,
        Y3Neg       => open,
        Y4Neg       => nKBPAWR_o,
        Y5Neg       => nIC32WR_o,
        Y6Neg       => nFDC_o,
        Y7Neg       => nFDCONWR_o
    );



e_138_b:entity fmf.std138
--    GENERIC MAP(
--        -- tipd delays: interconnect path delays
--        tipd_A              : VitalDelayType01 := VitalZeroDelay01;
--        tipd_B              : VitalDelayType01 := VitalZeroDelay01;
--        tipd_C              : VitalDelayType01 := VitalZeroDelay01;
--        tipd_G1             : VitalDelayType01 := VitalZeroDelay01;
--        tipd_G2ANeg         : VitalDelayType01 := VitalZeroDelay01;
--        tipd_G2BNeg         : VitalDelayType01 := VitalZeroDelay01;
--        -- tpd delays
--        tpd_A_Y0Neg         : VitalDelayType01 := UnitDelay01;
--        tpd_G1_Y0Neg        : VitalDelayType01 := UnitDelay01;
--        tpd_G2ANeg_Y0Neg    : VitalDelayType01 := UnitDelay01;
--        -- generic control parameters
--        InstancePath        : STRING   := DefaultInstancePath;
--        MsgOn               : BOOLEAN  := DefaultMsgOn;
--        XOn                 : BOOLEAN  := DefaultXOn;
--        -- For FMF SDF techonology file usage
--        TimingModel         : STRING   := DefaultTimingModel
--    );
    PORT MAP(
        A           => nCS_i(0),
        B           => nCS_i(1),
        C           => nCS_i(2),
        G1          => nCS_i(3),
        G2ANeg      => '0',
        G2BNeg      => '0',
        Y0Neg       => open,
        Y1Neg       => nVIAB_o,
        Y2Neg       => nPGFC_o,
        Y3Neg       => nPGFD_o,
        Y4Neg       => nTUBE_o,
        Y5Neg       => nADLC_o,
        Y6Neg       => open,
        Y7Neg       => open
    );


end rtl;


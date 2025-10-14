-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2021 Dominic Beesley https://github.com/dominicbeesley
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


-- Company:             Dossytronics
-- Engineer:            Dominic Beesley
-- 
-- Create Date:         1/8/2022
-- Design Name: 
-- Module Name:         cy74FCT2543
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:         A simple simulation model for a TX/RX latching transceiver
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
USE IEEE.VITAL_timing.ALL;
USE IEEE.VITAL_primitives.ALL;

library fmf;

entity cy74FCT2543 is
    port(
        A : inout std_logic_vector(7 downto 0);
        B : inout std_logic_vector(7 downto 0);

        nOEAB : in std_logic;
        nLEAB : in std_logic;
        nCEAB : in std_logic;

        nOEBA : in std_logic;
        nLEBA : in std_logic;
        nCEBA : in std_logic

    );
end cy74FCT2543;

architecture behav of cy74FCT2543 is
	signal i_BA_Q : std_logic_vector(7 downto 0);
	signal i_AB_Q : std_logic_vector(7 downto 0);
begin

	G_L:FOR I in 7 downto 0 GENERATE

		e_fmf_543:entity fmf.std543
		GENERIC MAP (
        -- tipd delays: interconnect path delays
--        tipd_A                   : VitalDelayType01 := VitalZeroDelay01;
--        tipd_B                   : VitalDelayType01 := VitalZeroDelay01;
--        tipd_OEBANeg             : VitalDelayType01 := VitalZeroDelay01;
--        tipd_CEBANeg             : VitalDelayType01 := VitalZeroDelay01;
--        tipd_LEBANeg             : VitalDelayType01 := VitalZeroDelay01;
--        tipd_OEABNeg             : VitalDelayType01 := VitalZeroDelay01;
--        tipd_CEABNeg             : VitalDelayType01 := VitalZeroDelay01;
--        tipd_LEABNeg             : VitalDelayType01 := VitalZeroDelay01;
        -- tpd delays
        tpd_A_B                  => (8 ns, 8 ns),
        tpd_B_A                  => (8 ns, 8 ns),
        tpd_OEBANeg_A            => (12 ns, 12 ns, 12 ns, 12 ns, 12 ns, 12 ns),
        tpd_LEBANeg_A            => (12 ns, 12 ns),
        tpd_OEABNeg_B            => (12 ns, 12 ns, 12 ns, 12 ns, 12 ns, 12 ns),
        tpd_LEABNeg_B            => (12 ns, 12 ns),
        tpd_CEABNeg_B            => (12 ns, 12 ns, 12 ns, 12 ns, 12 ns, 12 ns),
        tpd_CEBANeg_A            => (12 ns, 12 ns, 12 ns, 12 ns, 12 ns, 12 ns),
        -- tsetup values: setup times
        tsetup_A_LEABNeg         => 2 ns,
        tsetup_B_LEBANeg         => 2 ns,
        -- thold values: hold times
        thold_A_LEABNeg          => 2 ns,
        thold_B_LEBANeg          => 2 ns,
        -- tpw values: pulse widths
        tpw_LEBANeg_negedge      => 5 ns,
        tpw_LEABNeg_negedge      => 5 ns
       	)
		port map (
	        A                => A(I),
    	    B                => B(I),
        	OEBANeg          => nOEBA,
        	CEBANeg          => nCEBA,
        	LEBANeg          => nLEBA,
        	OEABNeg          => nOEAB,
        	CEABNeg          => nCEAB,
        	LEABNeg          => nLEAB
			);
	END GENERATE;
	

end behav;
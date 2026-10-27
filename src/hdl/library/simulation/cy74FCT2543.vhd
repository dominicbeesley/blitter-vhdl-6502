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
   generic (
      G_GRADE : string := "T"   -- speed grade: "T", "AT" or "CT" (max delays)
   );
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

   -- Datasheet switching characteristics, max column of each grade
   type t_timing is record
      t_pd  : time;     -- A or B to B or A
      t_le  : time;     -- nLE to output
      t_en  : time;     -- tPZH/tPZL, nOE or nCE to output
      t_dis : time;     -- tPHZ/tPLZ, nOE or nCE to output
   end record;

   function timing(grade : string) return t_timing is
   begin
      if grade = "CT" then
         return (t_pd => 5.5 ns, t_le => 7.0 ns,  t_en => 8.0 ns,  t_dis => 6.5 ns);
      elsif grade = "AT" then
         return (t_pd => 6.5 ns, t_le => 8.0 ns,  t_en => 9.0 ns,  t_dis => 7.5 ns);
      else
         return (t_pd => 8.5 ns, t_le => 12.5 ns, t_en => 12.0 ns, t_dis => 9.0 ns);
      end if;
   end function;

   constant C_T : t_timing := timing(G_GRADE);

   -- VitalDelayType01Z order: (01, 10, 0Z, Z1, 1Z, Z0)
   constant C_TPD_EN : VitalDelayType01Z := (C_T.t_en, C_T.t_en, C_T.t_dis, C_T.t_en, C_T.t_dis, C_T.t_en);

begin

   assert G_GRADE = "T" or G_GRADE = "AT" or G_GRADE = "CT"
      report "cy74FCT2543: unknown G_GRADE " & G_GRADE severity failure;

	G_L:FOR I in 7 downto 0 GENERATE

		e_fmf_543:entity fmf.std543
		GENERIC MAP (
        -- tpd delays
         tpd_A_B                  => (C_T.t_pd, C_T.t_pd),
         tpd_B_A                  => (C_T.t_pd, C_T.t_pd),
         tpd_OEBANeg_A            => C_TPD_EN,
         tpd_LEBANeg_A            => (C_T.t_le, C_T.t_le),
         tpd_OEABNeg_B            => C_TPD_EN,
         tpd_LEABNeg_B            => (C_T.t_le, C_T.t_le),
         tpd_CEABNeg_B            => C_TPD_EN,
         tpd_CEBANeg_A            => C_TPD_EN,
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

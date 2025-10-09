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


----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	16/6/2025
-- Design Name: 
-- Module Name:    	74HCT574
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 		fmf libraries
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library fmf;

entity HCT574 is
	Port (
		D				: in		STD_LOGIC_VECTOR(7 downto 0);
		Q				: out		STD_LOGIC_VECTOR(7 downto 0);
		CLK			: in		STD_LOGIC;
		nOE			: in		STD_LOGIC
	);
end HCT574;

architecture Behavioral of HCT574 is
begin


G_CHAN:FOR i in 0 to 7 generate
	e_gate:entity fmf.std574
   GENERIC MAP (
      -- tpd delays
      tpd_CLK_Q           => (18 ns, 18 ns),
      tpd_OENeg_Q         => (0 ns , 0 ns, 15 ns, 22 ns, 15 ns, 22 ns),
      -- tsetup values: setup times
      tsetup_D_CLK        => 10 ns,
      -- thold values: hold times
      thold_D_CLK         => 5 ns,
      -- tpw values: pulse widths
      tpw_CLK_posedge     => 15 ns,
      tpw_CLK_negedge     => 15 ns,
      -- tperiod_min: minimum clock period = 1/max freq
      tperiod_CLK_posedge => 34 ns,
      -- generic control parameters
      TimingChecksOn      => true,
      MsgOn               => true,
      XOn                 => true
   )
   PORT MAP (
      Q       => Q(I),
      D       => D(I),
      CLK     => CLK,
      OENeg   => nOE
   );
end generate;

	
	
end Behavioral;


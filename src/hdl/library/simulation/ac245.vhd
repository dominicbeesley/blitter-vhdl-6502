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


----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	15/7/2025
-- Design Name: 
-- Module Name:    	74AC574
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 		fmf libraries
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: @ 3.3V - not checked against datasheet
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library fmf;

entity AC245 is
	Port (
		A				: inout	STD_LOGIC_VECTOR(7 downto 0);
		B				: inout	STD_LOGIC_VECTOR(7 downto 0);
		DIR_AnB		: in		STD_LOGIC;
		nOE			: in		STD_LOGIC
	);
end AC245;

architecture Behavioral of AC245 is
begin


G_CHAN:FOR i in 0 to 7 generate
	e_gate:entity fmf.std245
   GENERIC MAP (
      -- tpd delays
      tpd_A_B           => (5 ns, 5 ns),
      tpd_B_A           => (5 ns, 5 ns),
      tpd_DIR_A         => (0 ns, 0 ns, 7 ns, 7 ns, 6.5 ns, 7 ns),
      tpd_DIR_B         => (0 ns, 0 ns, 7 ns, 7 ns, 6.5 ns, 7 ns),
      tpd_ENeg_A        => (0 ns, 0 ns, 7 ns, 7 ns, 6.5 ns, 7 ns),
      tpd_ENeg_B        => (0 ns, 0 ns, 7 ns, 7 ns, 6.5 ns, 7 ns),
      -- generic control parameters
      TimingChecksOn    => true,
      MsgOn             => true,
      XOn               => true
   )
   PORT MAP (
      A                 => A(I),
      B                 => B(I),
      ENeg              => nOE,
      DIR               => DIR_AnB
   );
end generate;

	
	
end Behavioral;


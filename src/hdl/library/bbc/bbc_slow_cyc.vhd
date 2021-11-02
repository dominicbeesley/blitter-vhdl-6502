-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2020 Dominic Beesley https://github.com/dominicbeesley
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
-- -----------------------------------------------------------------------------


-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	2/5/2019
-- Design Name: 
-- Module Name:    	detect a bbc slow cycle
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Combinatorial check for slow addresses
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------



library IEEE;
use IEEE.std_logic_1164.all;

entity bbc_slow_cyc is
port (
		sys_A_i 				: in	std_logic_vector(15 downto 0);
		slow_o 				: out	std_logic
);
end bbc_slow_cyc;

architecture rtl of bbc_slow_cyc is

begin

	slow_o <= '1' when (
		sys_A_i(15 downto 8) = x"FC" or
		sys_A_i(15 downto 8) = x"FD" or
		(	sys_A_i(15 downto 8) = x"FE" and (
				sys_A_i(7 downto 4) = x"0" or -- CRTC/ACIA
				sys_A_i(7 downto 4) = x"1" or -- SERPROC/STATID -- TODO:CHECK
				sys_A_i(7 downto 4) = x"4" or -- SYS VIA
				sys_A_i(7 downto 4) = x"5" or -- SYS VIA
				sys_A_i(7 downto 4) = x"6" or -- USR VIA
				sys_A_i(7 downto 4) = x"7" or -- USR VIA
				sys_A_i(7 downto 4) = x"C" or -- ADC
				sys_A_i(7 downto 4) = x"D"	   -- ADC
			)
		)) else 
	'0';

end rtl;
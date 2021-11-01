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
-- Create Date:    	17/7/2021
-- Design Name: 
-- Module Name:    	serialout.vhd
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A simple parallel to serial which repeats a 4 byte message
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: Used for ERC testing boards
--
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity serialout is
generic (
	message : string(1 to 4)
	);
port (
	bit_clk : in std_logic;

	so : out std_logic
);
end serialout;

architecture rtl of serialout is

signal ix : integer range 0 to 4;
signal curch : std_logic_vector(9 downto 0); 
signal bitix : integer range 0 to 9;
begin

	p:process(bit_clk)
	begin
		if rising_edge(bit_clk) then
			if bitix = 9 then
	
	
				if ix = 4 then
					ix <= 0;
					curch <= (others => '1');
				else
					ix <= ix + 1;
					curch <= '1' & std_logic_vector(to_unsigned(character'pos(message(ix+1)),8)) & '0';
				end if;

				bitix <= 0;
			else
	
				bitix <= bitix + 1;
				curch <= "1" & curch(9 downto 1);
			end if;
		end if;

	end process;
	
	so <= curch(0);

end rtl;

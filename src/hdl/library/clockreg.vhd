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
-- ----------------------------------------------------------------------

-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	2/5/2019
-- Design Name: 
-- Module Name:    	register signals into a new clock domain
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		simple register based meta stability fixer
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------


LIBRARY ieee;

USE ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

LIBRARY work;

-- (c) Dominic Beesley 2019

entity clockreg is
	generic (
		G_DEPTH : positive := 1;
		G_WIDTH : positive := 1
	);
	port (
		clk_i	: in	std_logic;
		d_i	: in	std_logic_vector(G_WIDTH-1 downto 0);
		q_o	: out	std_logic_vector(G_WIDTH-1 downto 0)
	);
end;

architecture arch of clockreg is
type reg_arr is array(G_DEPTH-1 downto 0) of std_logic_vector(G_WIDTH-1 downto 0);
signal r : reg_arr;
begin
	
	q_o <= r(0);

	p:procesS(clk_i)
	begin
		if rising_edge(clk_i) then
			r(G_DEPTH-1) <= d_i;
			if G_DEPTH > 1 then
				for I in G_DEPTH-1 downto 1 loop
					r(I - 1) <= r(I);				
				end loop;
			end if;
		end if;
	end process;

end;
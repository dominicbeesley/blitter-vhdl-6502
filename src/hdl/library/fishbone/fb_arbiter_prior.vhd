-- MIT License
-- 
-- Copyright (c) 2021 dominicbeesley
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
-- 

-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	30/6/2019
-- Design Name: 
-- Module Name:    	priority arbiter
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A simple priority arbiter where lsb in req gets priority
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: For an exmplanation see https://www.krll.de/portfolio/vhdl-round-robin-arbiter/
--
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use work.common.all;


entity fb_arbiter_prior is
generic (
	CNT : natural
	);
port (
	clk_i 			: in    std_logic;
	rst_i				: in    std_logic;

	req_i   			: in    std_logic_vector(CNT-1 downto 0);		-- this doesn't get registered
	ack_i				: in 	  std_logic; -- should fire for one cycle to indicate previous grant had been 
												 -- serviced
	grant_ix_o 		: out   unsigned(numbits(CNT)-1 downto 0)		-- this doesn't get registered
	);
end fb_arbiter_prior;

architecture rtl of fb_arbiter_prior is
begin

	process(req_i)
	begin
		grant_ix_o <= (others => '-');
		for I in CNT-1 downto 0 loop
			if req_i(I) = '1' then
				grant_ix_o <= to_unsigned(I, grant_ix_o'length);
			end if;
		end loop;
	end process;

end rtl;
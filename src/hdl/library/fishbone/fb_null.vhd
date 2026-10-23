-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2022 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:    	16/10/2022
-- Design Name: 
-- Module Name:    	fishbone bus - null peripheral
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone peripheral that always reads the same value
--							and silently absorbs writes
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;

entity fb_null is
	generic (
		G_READ_VAL				: std_logic_vector(7 downto 0) := x"FF"	-- default value to read back	
	);
	port(

		fb_syscon_i				: in	fb_syscon_t;

		-- peripheral port connecter1 to controllers
		fb_c2p_i					: in	fb_con_o_per_i_t;
		fb_p2c_o					: out	fb_con_i_per_o_t
	);
end fb_null;

architecture rtl of fb_null is
signal r_wait_we : std_logic;
signal r_A_ack : std_logic;
signal r_D_ack : std_logic;
begin
	
	p_state:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_wait_we <= '0';
			r_A_ack <= '0';
			r_D_ack <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			r_A_ack <= '0';
			r_D_ack <= '0';

			if r_wait_we = '1' then
				if fb_c2p_i.d_wr_stb = '1' then
					r_D_ack <= '1';
					r_wait_we <= '0';
				end if;
			elsif fb_c2p_i.cyc = '1' and fb_c2p_i.a_stb = '1' and r_A_ack = '0' then
				r_A_ack <= '1';
				if fb_c2p_i.we = '1' and (fb_c2p_i.d_wr_stb = '0' or r_D_ack = '1') then
					r_wait_we <= '1';
				else
					r_D_ack <= '1';
				end if;
			end if;

			if fb_c2p_i.cyc = '0' then
				r_wait_we <= '0';
			end if;
		end if;
	end process;

	fb_p2c_o.A_ack <= r_A_ack;
	fb_p2c_o.D_rd <= G_READ_VAL;
	fb_p2c_o.D_ack <= r_D_ack;
	fb_p2c_o.rdy <= r_D_ack;

end rtl;

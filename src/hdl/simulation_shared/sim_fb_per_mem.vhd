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


-- Company: 				Dossytronics
-- Engineer: 				Dominic Beesley
-- 
-- Create Date:    		25/10/2022
-- Design Name: 
-- Module Name:    		work.sim_fb_per_mem
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 			A simple memory peripheral
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

entity sim_fb_per_mem is
generic (
		G_SIZE : natural := 8
	);
port (

		fb_syscon_i								: in	fb_syscon_t;

		fb_c2p_i									: in fb_con_o_per_i_t;
		fb_p2c_o									: out	fb_con_i_per_o_t;

		stall_i									: in std_logic
	);

end sim_fb_per_mem;

architecture rtl of sim_fb_per_mem is
	
	type t_mem is array (0 to G_SIZE-1) of std_logic_vector(7 downto 0);

	signal r_mem : t_mem;

	signal r_stall   	: std_logic;
	signal r_ack	 	: std_logic;
	signal r_d_rd		: std_logic_vector(7 downto 0);

begin

			fb_p2c_o <= (
					stall => stall_i or r_stall,
					ack => r_ack,
					rdy => r_ack,
					D_rd => r_d_rd
				);
	


	p_per:process
	variable init:boolean := true;
	variable v_a: std_logic_vector(23 downto 0);
	variable v_d: std_logic_vector(7 downto 0);
	begin

		if (init) then
			init := false;
			for i in 0 to G_SIZE-1 loop
				r_mem(i) <= std_logic_vector(to_unsigned(i mod 255 ,8)) xor x"FF";
			end loop;
		else

			r_ack <= '0';
			r_stall <= '0';
			r_d_rd <= (others => '-');

			wait until fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' and rising_edge(fb_syscon_i.clk) and stall_i = '0';

			v_a := fb_c2p_i.A;

			r_stall <= '1';

			if fb_c2p_i.we = '1' then
				while fb_c2p_i.D_wr_stb /= '1' loop
					report "wait wr stb" severity note;
					wait until rising_edge(fb_syscon_i.clk);
				end loop;			
				r_mem(to_integer(unsigned(v_a)) mod G_SIZE) <= fb_c2p_i.D_wr;
				report "Written " & to_hex_string(fb_c2p_i.D_wr) & " to " & to_hex_string(v_a) severity note;

				wait until rising_edge(fb_syscon_i.clk);
			else
				wait until rising_edge(fb_syscon_i.clk);
				wait until rising_edge(fb_syscon_i.clk);
				wait until rising_edge(fb_syscon_i.clk);
				v_d := r_mem(to_integer(unsigned(v_a)) mod G_SIZE);
				r_D_Rd <= v_d;
				report "read " & to_hex_string(v_d) & " from " & to_hex_string(v_a) severity note;
			end if;

			r_ack <= '1';
			wait until rising_edge(fb_syscon_i.clk);

		end if;

	end process;




end rtl;
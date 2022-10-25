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
use work.fb_CPU_exp_pack.all;

entity sim_fb_per_mem is
generic (
		G_SIZE : natural := 8
	);
port (

		fb_syscon_i								: in	fb_syscon_t;

		fb_con_c2p_i							: in fb_con_o_per_i_t;
		fb_con_p2c_o							: out	fb_con_i_per_o_t
	);

end sim_fb_per_mem;

architecture rtl of sim_fb_per_mem is
	
	type t_mem is array (0 to G_SIZE-1) of std_logic_vector(7 downto 0);

	r_mem : t_mem;

begin

	p_init:process
	variable i:natural;
	begin
		for i in 0 to G_SIZE-1 loop
			r_mem(i) <= std_logic_vector(to_unsigned(i mod 255 ,8)) xor x"FF";
		end loop;
		wait;
	end process;


end rtl;
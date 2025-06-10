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
-- Create Date:    	24/10/2022
-- Design Name: 
-- Module Name:    	fishbone bus - CPU address translation and wait
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A pass-through fishbone component that translates logical to 
--							physical addresses - this one does nothing!
-- Dependencies: 
--
-- Revision: 
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.fishbone.all;
use work.common.all;

entity fb_cpu_log2phys_simple16 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;										-- fast clock speed in mhz						
		G_MK3									: boolean := false		
	);
	port(

		fb_syscon_i								: in	fb_syscon_t;

		-- controller interface from the cpu
		fb_con_c2p_i							: in fb_con_o_per_i_t;
		fb_con_p2c_o							: out	fb_con_i_per_o_t;

		fb_per_c2p_o							: out fb_con_o_per_i_t;
		fb_per_p2c_i							: in	fb_con_i_per_o_t

	);
end fb_cpu_log2phys_simple16;


architecture rtl of fb_cpu_log2phys_simple16 is 

begin

	fb_con_p2c_o <= fb_per_p2c_i;

	p_l2p:process(all)
	begin
		
		fb_per_c2p_o <= fb_con_c2p_i;

		if fb_con_c2p_i.A(23 downto 16) = x"FF" then
			if fb_con_c2p_i.A(15 downto 8) = x"FD" then
				fb_per_c2p_o.A <= x"1F10" & fb_con_c2p_i.A(7 downto 0);
			end if;
		end if;

	end process;


end rtl;
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
use ieee.std_logic_misc.all;

library work;
use work.fishbone.all;
use work.common.all;

entity fb_null is
	generic (
		SIM						: boolean := false;								-- skip some stuff, i.e. slow sdram start up
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
signal i_ack		:std_logic;
begin
	
	i_ack <= fb_c2p_i.cyc and fb_c2p_i.a_stb;

	fb_p2c_o.stall <= '0';
	fb_p2c_o.D_rd <= G_READ_VAL;
	fb_p2c_o.ack <= i_ack;
	fb_p2c_o.rdy <= i_ack;

end rtl;

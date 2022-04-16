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
-- Create Date:    		30/3/2022
-- Design Name: 
-- Module Name:    		work.fb_CPU_exp_pack
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 			type definitions for wrapping CPU expansion socket pins Mk.3
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
use work.fb_CPU_pack.all;


package fb_CPU_exp_pack is

	constant	C_CPU_BYTELANES	: positive := 2;									-- number of data byte lanes


	type t_cpu_wrap_exp_o is record
		exp_PORTB					: std_logic_vector(7 downto 0);
		exp_PORTD					: std_logic_vector(11 downto 0);
		exp_PORTD_o_en				: std_logic_vector(11 downto 0);
		exp_PORTE_nOE				: std_logic;	
		exp_PORTF_nOE				: std_logic;	

		CPU_D_RnW					: std_logic;
	end record;

	type t_cpu_wrap_exp_o_arr is array(natural range<>) of t_cpu_wrap_exp_o;

	type t_cpu_wrap_exp_i is record

		-- cpu socket signals
		CPUSKT_D						: std_logic_vector(15 downto 0);
		CPUSKT_A						: std_logic_vector(23 downto 0);

		exp_PORTD					: std_logic_vector(11 downto 0);

	end record;

end fb_CPU_exp_pack;
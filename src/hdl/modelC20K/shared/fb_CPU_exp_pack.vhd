-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2026 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:    		21/10/2026
-- Design Name: 
-- Module Name:    		work.fb_CPU_exp_pack
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 			type definitions for wrapping CPU expansion socket pins C20K
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: No external ports come out of here on C20K
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;

package fb_CPU_exp_pack is

	type t_cpu_wrap_exp_o is record
		nowt : std_logic;
	end record;

	constant C_EXP_O_DUMMY : t_cpu_wrap_exp_o := (
		nowt => '0'
	);

	type t_cpu_wrap_exp_o_arr is array(natural range<>) of t_cpu_wrap_exp_o;

	type t_cpu_wrap_exp_i is record
		nowt : std_logic;
	end record;

	constant C_EXP_I_DUMMY : t_cpu_wrap_exp_i := (
		nowt => '0'
	);

end fb_CPU_exp_pack;
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

package fb_CPU_exp_pack is

	constant	C_CPU_BYTELANES	: positive := 4;									-- number of data byte lanes


	type t_cpu_wrap_exp_o is record
		PORTA_nOE			: std_logic;
		PORTA_DIR			: std_logic;										-- DIR is '1' for CPU to Blitter, '0' for Blitter to CPU
		PORTA					: std_logic_vector(7 downto 0);
		PORTB					: std_logic_vector(7 downto 0);
		PORTD					: std_logic_vector(11 downto 0);
		PORTD_o_en			: std_logic_vector(11 downto 0);
		PORTE_i_nOE			: std_logic;	
		PORTF_i_nOE			: std_logic;	
		PORTF_o_nOE			: std_logic;	
		PORTF					: std_logic_vector(11 downto 4);
	end record;

	type t_cpu_wrap_exp_o_arr is array(natural range<>) of t_cpu_wrap_exp_o;

	type t_cpu_wrap_exp_i is record

		PORTA					: std_logic_vector(7 downto 0);
		PORTC					: std_logic_vector(11 downto 0);
		PORTD					: std_logic_vector(11 downto 0);
		PORTEFG				: std_logic_vector(11 downto 0);

	end record;

end fb_CPU_exp_pack;
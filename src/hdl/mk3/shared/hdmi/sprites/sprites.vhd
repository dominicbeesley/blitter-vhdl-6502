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
-- -----------------------------------------------------------------------------

-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	1/10/2023
-- Design Name: 
-- Module Name:    	sprites.vhd
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Model C sprite: main sprite outer wrapper
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
-- 	Inspired by Amiga sprites but tweaked to work in an 8-bit world
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.sprites_pack.all;
use work.common.all;

entity sprites is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		G_N_SPRITES							: natural := 8									-- maximum number of sprites
	);
	port(

		rst_i									: in	std_logic;							

		clk_i									: in	std_logic;
		clken_i								: in	std_logic;							-- this qualifies all clocks

		pixel_clken_i						: in	std_logic;							-- move to next pixel must coincide with clken_i
		horz_ctr_i							: in	unsigned(8 downto 0); 			-- counts mode 4 pixels since horz-sync

		-- data interface, from sequencer
		SEQ_D_i								: in	std_logic_vector(7 downto 0);
		SEQ_wren_i							: in	std_logic;
		SEQ_A_i								: in	unsigned(numbits(G_N_SPRITES) + 3 downto 0);			
																								-- sprite data A..D, pos/ctl, ptr, lst (see below in p_regs)
		SEQ_DATAPTR_inc_i					: in	std_logic_vector(numbits(G_N_SPRITES)-1 downto 0);
																								-- increment pointer this clock

		-- addresses out to sequencer
		SEQ_DATAPTR_A_o					: out t_spr_addr_array(G_N_SPRITES-1 downto 0);

		-- data interface, from CPU
		CPU_D_i								: in	std_logic_vector(7 downto 0);
		CPU_wren_i							: in	std_logic;
		CPU_A_i								: in	unsigned(3 downto 0);			-- sprite data A..D, pos/ctl, ptr, lst (see below in p_regs)

		-- pixel data out
		px_D_o								: out	std_logic_vector(1 downto 0)


	

	);
end sprites;

architecture rtl of sprites is


begin


end rtl;
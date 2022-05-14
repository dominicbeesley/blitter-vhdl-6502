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
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	fishbone bus - Blitter/Paula chipset wrapper
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for all the chipset components
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

package fb_chipset_pack is

component fb_chipset
	generic (
		SIM						: boolean := false;							-- skip some stuff, i.e. slow sdram start up
 		CLOCKSPEED				: natural										-- fast clock speed in mhz						
	);
	port(

		fb_syscon_i				: in	fb_syscon_t;

		-- peripheral port connecter1 to controllers
		fb_per_c2p_i			: in	fb_con_o_per_i_t;
		fb_per_p2c_o			: out	fb_con_i_per_o_t;

		-- controller port connector to peripherals
		fb_con_c2p_o			: out fb_con_o_per_i_t;
		fb_con_p2c_i			: in 	fb_con_i_per_o_t;

		-- request CPU halt
		cpu_halt_o				: out std_logic;
		cpu_int_o				: out std_logic;

		-- sound clock
		clk_snd_i				: in std_logic;

		-- sound output - do D->A business at top level as 1MPaula and Blitter use different DACs
		snd_dat_o							: out		signed(9 downto 0);
		snd_dat_change_clken_o			: out		std_logic;


		-- 6845 signals to Aeris
		vsync_i					: in std_logic;
		hsync_i					: in std_logic;

		-- top level ports -- TODO: should EEPROM really be part of chipset? - probably due to where it sits in address map
		I2C_SCL_io				: inout std_logic;
		I2C_SDA_io				: inout std_logic

	);
	end component;

end fb_chipset_pack;
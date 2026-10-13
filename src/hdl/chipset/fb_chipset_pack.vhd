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

library work;
use work.common.all;
use work.board_config_pack.all;
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
		snd_dat_o							: out		signed(15 downto 0);
		snd_dat_l_o							: out		signed(15 downto 0);
		snd_dat_r_o							: out		signed(15 downto 0);


		-- 6845 signals to Aeris
		vsync_i					: in std_logic;
		hsync_i					: in std_logic;

		-- top level ports 
		-- TODO: should EEPROM/SDCARD  really be part of chipset? - probably due to where it sits in address map

		-- i2c eeprom / rtc etc
		I2C_SCL_io				: inout std_logic;
		I2C_SDA_io				: inout std_logic;

		-- SDCARD spi
		SD_CS_o					: out		std_logic;
		SD_CLK_o					: out		std_logic;
		SD_MOSI_o				: out		std_logic;
		SD_MISO_i				: in		std_logic;
		SD_DET_i					: in		std_logic

	);
	end component;

	-----------------------------------------------------------------------------
	-- work out number / order of controllers 
	-----------------------------------------------------------------------------

	constant MAS_NO_CHIPSET_AERIS			: natural := 0;
	constant MAS_NO_CHIPSET_SND			: natural := MAS_NO_CHIPSET_AERIS + b2n(G_INCL_CS_AERIS);
	constant MAS_NO_CHIPSET_DMA_0			: natural := MAS_NO_CHIPSET_SND + b2n(G_INCL_CS_SND);
	constant MAS_NO_CHIPSET_DMA_1			: natural := MAS_NO_CHIPSET_DMA_0 + b2n(G_INCL_CS_DMA AND G_DMA_CHANNELS >= 1);
	constant MAS_NO_CHIPSET_BLIT 			: natural := MAS_NO_CHIPSET_DMA_1 + b2n(G_INCL_CS_DMA AND G_DMA_CHANNELS >= 2);
	constant CONTROLLER_COUNT_CHIPSET	: natural := MAS_NO_CHIPSET_BLIT + b2n(G_INCL_CS_BLIT);

	-----------------------------------------------------------------------------
	-- work out number / order of peripherals 
	-----------------------------------------------------------------------------


	constant PERIPHERAL_NO_CHIPSET_DMA		: natural := 0;
	constant PERIPHERAL_NO_CHIPSET_SOUND	: natural := PERIPHERAL_NO_CHIPSET_DMA + b2n(G_INCL_CS_DMA);
	constant PERIPHERAL_NO_CHIPSET_BLIT		: natural := PERIPHERAL_NO_CHIPSET_SOUND + b2n(G_INCL_CS_SND);
	constant PERIPHERAL_NO_CHIPSET_AERIS	: natural := PERIPHERAL_NO_CHIPSET_BLIT + b2n(G_INCL_CS_BLIT);
	constant PERIPHERAL_NO_CHIPSET_EEPROM	: natural := PERIPHERAL_NO_CHIPSET_AERIS + b2n(G_INCL_CS_AERIS);
	constant PERIPHERAL_NO_CHIPSET_SDCARD	: natural := PERIPHERAL_NO_CHIPSET_EEPROM + b2n(G_INCL_CS_EEPROM);
	constant PERIPHERAL_COUNT_CHIPSET		: natural := PERIPHERAL_NO_CHIPSET_SDCARD + b2n(G_INCL_CS_SDCARD);


end fb_chipset_pack;
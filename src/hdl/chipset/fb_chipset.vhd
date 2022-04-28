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
use work.common.all;
use work.board_config_pack.all;

entity fb_chipset is
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

		-- 6845 signals to Aeris
		vsync_i					: in std_logic;
		hsync_i					: in std_logic;

		-- top level ports -- TODO: should EEPROM really be part of chipset? - probably due to where it sits in address map
		I2C_SCL_io				: inout std_logic;
		I2C_SDA_io				: inout std_logic;

		SND_L_o					: out std_logic;
		SND_R_o					: out std_logic

	);
end fb_chipset;

architecture rtl of fb_chipset is


	-----------------------------------------------------------------------------
	-- fishbone signals
	-----------------------------------------------------------------------------

	-- blit controller
	signal i_c2p_blit_con		: fb_con_o_per_i_t;
	signal i_p2c_blit_con		: fb_con_i_per_o_t;
	-- blit peripheral interface control registers
	signal i_c2p_blit_per		: fb_con_o_per_i_t;
	signal i_p2c_blit_per		: fb_con_i_per_o_t;

	-- aeris controller
	signal i_c2p_aeris_con		: fb_con_o_per_i_t;
	signal i_p2c_aeris_con		: fb_con_i_per_o_t;
	-- aeris peripheral interface control registers
	signal i_c2p_aeris_per		: fb_con_o_per_i_t;
	signal i_p2c_aeris_per		: fb_con_i_per_o_t;

	-- dma controller
	signal i_c2p_dma_con			: fb_con_o_per_i_arr(G_DMA_CHANNELS-1 downto 0);
	signal i_p2c_dma_con			: fb_con_i_per_o_arr(G_DMA_CHANNELS-1 downto 0);
	-- dma peripheral interface control registers
	signal i_c2p_dma_per			: fb_con_o_per_i_t;
	signal i_p2c_dma_per			: fb_con_i_per_o_t;

	-- sound controller
	signal i_c2p_snd_con			: fb_con_o_per_i_t;
	signal i_p2c_snd_con			: fb_con_i_per_o_t;
	-- sound peripheral interface control registers
	signal i_c2p_snd_per			: fb_con_o_per_i_t;
	signal i_p2c_snd_per			: fb_con_i_per_o_t;

	-- i2c eeprom control registers wrapper
	signal i_c2p_eeprom_per		: fb_con_o_per_i_t;
	signal i_p2c_eeprom_per		: fb_con_i_per_o_t;

	-- chipset controller->peripheral
	signal i_con_c2p_chipset	: fb_con_o_per_i_arr(CONTROLLER_COUNT_CHIPSET-1 downto 0);
	signal i_con_p2c_chipset	: fb_con_i_per_o_arr(CONTROLLER_COUNT_CHIPSET-1 downto 0);
	-- chipset peripheral->controller
	signal i_per_c2p_chipset	: fb_con_o_per_i_arr(PERIPHERAL_COUNT_CHIPSET-1 downto 0);
	signal i_per_p2c_chipset	: fb_con_i_per_o_arr(PERIPHERAL_COUNT_CHIPSET-1 downto 0);


	-----------------------------------------------------------------------------
	-- inter component (non-fishbone) signals
	-----------------------------------------------------------------------------

	-- chipset c2p intcon to peripheral sel
	signal i_chipset_intcon_peripheral_sel_addr		: std_logic_vector(7 downto 0);
	signal i_chipset_intcon_peripheral_sel			: unsigned(numbits(PERIPHERAL_COUNT_CHIPSET)-1 downto 0);  -- address decoded selected peripheral
	signal i_chipset_intcon_peripheral_sel_oh		: std_logic_vector(PERIPHERAL_COUNT_CHIPSET-1 downto 0);	-- address decoded selected peripherals as one-hot		


	signal i_dma_cpu_int					: std_logic;							-- interrupt out from dma
	signal i_dma_cpu_halt				: std_logic;							-- cpu halt request out from dma
	signal i_blit_cpu_halt				: std_logic;							-- cpu halt request out from blit
	signal i_aeris_cpu_halt				: std_logic;							-- cpu halt request out from aeris
	signal i_snd_cpu_halt				: std_logic;							-- cpu halt request out from snd

	signal i_dac_snd_pwm					: std_logic;							-- pwm signal for sound channels
	signal i_dac_sample					: signed(9 downto 0);				-- sample playing
	signal i_snd_dat_o					: signed(9 downto 0);   			-- sound data out



begin

-- TODO: intercept case where a chipset controller connects direct to a chipset peripheral 
-- and handle as a loop back - maybe more effort than it's worth?
-- TODO: make DMA multiplex its own masters internally?

-- logical map
--                     +----------------+ 
--                     | addr2s chipset |
--                     +----------------+
--                           |                       +----------+                   _______
--                         _______                   |          |<-i_*_dma_con[0]->|       \
--                        /       |<-i_*_dma_per---->| DMA      |<-i_*_dma_con[1]->|        \
--                       /        |                  +----------+                  |         |
--                      |         |<-i_*_snd_per---->| SOUND    |<-i_*_snd_con---->| chipset | <->controller port
--                      |  intcon |                  +----------+                  | con     |    [fb_con_*]
--  peripheral port <-> |  chipset|<-i_*_blit_per--->| BLIT     |<-i_*_blit_con--->|         |
--	    [fb_per_*]       |         |                  +----------+                  |        /
--                       \        |<-i_*_aeris_per-->| AERIS    |<-i_*_aeris_con-->|       /
--                        \       |                  +----------+                   -------
--                         ------- <-i_*_eeprom_per->| EEPROM   |
--                                                   +----------+
--                                 
--                                 


	-- multiplex all the chipset controller ports down to a single 
	-- controller out to the top level resources
	e_chipset_con:entity work.fb_intcon_many_to_one
	generic map (
		SIM => SIM,
		G_CONTROLLER_COUNT	=> CONTROLLER_COUNT_CHIPSET
	)
	port map (

		fb_syscon_i						=> fb_syscon_i,

		-- peripheral port connect to controllers
		fb_con_c2p_i => i_con_c2p_chipset,
		fb_con_p2c_o => i_con_p2c_chipset,

		-- controller port connect to peripherals
		fb_per_c2p_o					=> fb_con_c2p_o,
		fb_per_p2c_i					=> fb_con_p2c_i

	);

	-- address decode to select peripheral
	e_addr2s_chipset:entity work.address_decode_chipset
	generic map (
		SIM							=> SIM
	)
	port map (
		addr_i						=> i_chipset_intcon_peripheral_sel_addr,
		peripheral_sel_o			=> i_chipset_intcon_peripheral_sel,
		peripheral_sel_oh_o		=> i_chipset_intcon_peripheral_sel_oh
	);

	e_fb_intcon_chipset:entity work.fb_intcon_one_to_many
	generic map (
		SIM => SIM,
		G_PERIPHERAL_COUNT => PERIPHERAL_COUNT_CHIPSET,
		G_ADDRESS_WIDTH => 8
	)
	port map (
		fb_syscon_i 		=> fb_syscon_i,

		fb_con_c2p_i		=>	fb_per_c2p_i,
		fb_con_p2c_o		=> fb_per_p2c_o,

		fb_per_c2p_o => i_per_c2p_chipset,
		fb_per_p2c_i => i_per_p2c_chipset,		

		peripheral_sel_addr_o					=> i_chipset_intcon_peripheral_sel_addr,
		peripheral_sel_i							=> i_chipset_intcon_peripheral_sel,
		peripheral_sel_oh_i						=> i_chipset_intcon_peripheral_sel_oh

	);

GDMA:IF G_INCL_CS_DMA GENERATE

	G_DMA_C:FOR I in 0 TO G_DMA_CHANNELS-1 GENERATE
		
		i_con_c2p_chipset(MAS_NO_CHIPSET_DMA_0 + I)	<= i_c2p_dma_con(I);
		i_p2c_dma_con(i) 	<= i_con_p2c_chipset(MAS_NO_CHIPSET_DMA_0 + I);
	END GENERATE;
	
	i_per_p2c_chipset(PERIPHERAL_NO_CHIPSET_DMA)	<=	i_p2c_dma_per;
	i_c2p_dma_per 		<= i_per_c2p_chipset(PERIPHERAL_NO_CHIPSET_DMA);

	e_fb_dma:entity work.fb_DMAC_int_dma
	 generic map (
		SIM									=> SIM,
		G_CHANNELS							=> G_DMA_CHANNELS,
		CLOCKSPEED							=> CLOCKSPEED
	 )
    Port map (

		-- fishbone signals		
		fb_syscon_i							=> fb_syscon_i,

		-- peripheral interface (control registers)
		fb_per_c2p_i						=> i_c2p_dma_per,
		fb_per_p2c_o						=> i_p2c_dma_per,

		-- controller interface (dma)
		fb_con_c2p_o						=> i_c2p_dma_con,
		fb_con_p2c_i						=> i_p2c_dma_con,

		int_o									=> i_dma_cpu_int,
		cpu_halt_o							=> i_dma_cpu_halt,
		dma_halt_i							=> i_aeris_cpu_halt
	 );
END GENERATE;
GNODMA:IF NOT G_INCL_CS_DMA GENERATE
	i_dma_cpu_halt <= i_aeris_cpu_halt;
	i_dma_cpu_int <= '0';
END GENERATE;

GBLIT:IF G_INCL_CS_BLIT GENERATE

	i_con_c2p_chipset(MAS_NO_CHIPSET_BLIT)		<= i_c2p_blit_con;
	i_p2c_blit_con 	<= i_con_p2c_chipset(MAS_NO_CHIPSET_BLIT);
	i_c2p_blit_per    <= i_per_c2p_chipset(PERIPHERAL_NO_CHIPSET_BLIT);
	i_per_p2c_chipset(PERIPHERAL_NO_CHIPSET_BLIT)  <= i_p2c_blit_per;

	e_fb_blit:entity work.fb_dmac_blit
	 generic map (
		SIM									=> SIM
	 )
    Port map (

		-- fishbone signals		
		fb_syscon_i							=> fb_syscon_i,

		-- peripheral interface (control registers)
		fb_per_c2p_i						=> i_c2p_blit_per,
		fb_per_p2c_o						=> i_p2c_blit_per,

		-- controller interface (dma)
		fb_con_c2p_o						=> i_c2p_blit_con,
		fb_con_p2c_i						=> i_p2c_blit_con,

		cpu_halt_o							=> i_blit_cpu_halt,
		blit_halt_i							=> i_aeris_cpu_halt

	 );
END GENERATE;
GNOTBLIT:IF NOT G_INCL_CS_BLIT GENERATE
	i_blit_cpu_halt <= i_aeris_cpu_halt;
END GENERATE;

GAERIS: IF G_INCL_CS_AERIS GENERATE

	i_con_c2p_chipset(MAS_NO_CHIPSET_AERIS)	<= i_c2p_aeris_con;
	i_p2c_aeris_con <= i_con_p2c_chipset(MAS_NO_CHIPSET_AERIS);
	
	i_c2p_aeris_per <= i_per_c2p_chipset(PERIPHERAL_NO_CHIPSET_AERIS);
	i_per_p2c_chipset(PERIPHERAL_NO_CHIPSET_AERIS) <= i_p2c_aeris_per;

	e_fb_aeris:entity work.fb_dmac_aeris
	 generic map (
		SIM									=> SIM,
		CLOCKSPEED							=> CLOCKSPEED
	 )
    Port map (

		-- fishbone signals		
		fb_syscon_i							=> fb_syscon_i,

		-- peripheral interface (control registers)
		fb_per_c2p_i						=> i_c2p_aeris_per,
		fb_per_p2c_o						=> i_p2c_aeris_per,

		-- controller interface (dma)
		fb_con_c2p_o						=> i_c2p_aeris_con,
		fb_con_p2c_i						=> i_p2c_aeris_con,

		cpu_halt_o							=> i_aeris_cpu_halt,

		vsync_i								=> vsync_i,
		hsync_i								=> hsync_i,

		dbg_state_o							=> open

	 );
END GENERATE;
GNOTAERIS: IF NOT G_INCL_CS_AERIS GENERATE
	i_aeris_cpu_halt <= '0';
END GENERATE;


GSND:IF G_INCL_CS_SND GENERATE
	i_con_c2p_chipset(MAS_NO_CHIPSET_SND)			<= i_c2p_snd_con;
	i_p2c_snd_con <= i_con_p2c_chipset(MAS_NO_CHIPSET_SND);
	
	i_c2p_snd_per <= i_per_c2p_chipset(PERIPHERAL_NO_CHIPSET_SOUND);
	i_per_p2c_chipset(PERIPHERAL_NO_CHIPSET_SOUND)	<= i_p2c_snd_per;

	e_fb_snd:entity work.fb_DMAC_int_sound
	 generic map (
		SIM									=> SIM,
		G_CHANNELS							=> G_SND_CHANNELS
	 )
    Port map (

		-- fishbone signals		
		fb_syscon_i							=> fb_syscon_i,

		-- peripheral interface (control registers)
		fb_per_c2p_i						=> i_c2p_snd_per,
		fb_per_p2c_o						=> i_p2c_snd_per,

		-- controller interface (dma)
		fb_con_c2p_o						=> i_c2p_snd_con,
		fb_con_p2c_i						=> i_p2c_snd_con,

		snd_clk_i							=> clk_snd_i,
		snd_dat_o							=> i_snd_dat_o,

		cpu_halt_o							=> i_snd_cpu_halt

	 );

	i_dac_sample <= i_snd_dat_o;

	SND_R_o <= i_dac_snd_pwm;
	SND_L_o <= i_dac_snd_pwm;

	e_dac_snd: entity work.dac_1bit 
	generic map (
		G_SAMPLE_SIZE		=> 10,
		G_SYNC_DEPTH		=> 0
	)
   port map (
		rst_i					=> fb_syscon_i.rst,
		clk_dac				=> fb_syscon_i.clk,

		sample				=> i_dac_sample,
		
		bitstream			=> i_dac_snd_pwm
	);
END GENERATE;
GNOTSND:IF NOT G_INCL_CS_SND GENERATE
	i_snd_cpu_halt <= '0';

END GENERATE;


GEEPROM: IF G_INCL_CS_EEPROM GENERATE
	i_c2p_eeprom_per <= i_per_c2p_chipset(PERIPHERAL_NO_CHIPSET_EEPROM);
	i_per_p2c_chipset(PERIPHERAL_NO_CHIPSET_EEPROM)	<=	i_p2c_eeprom_per;

	e_fb_eeprom:entity work.fb_i2c
	generic map (
		SIM									=> SIM,
		CLOCKSPEED							=> CLOCKSPEED
	)
	port map (

		-- eeprom signals
		I2C_SCL_io							=> I2C_SCL_io,
		I2C_SDA_io							=> I2C_SDA_io,

		-- fishbone signals

		fb_syscon_i							=> fb_syscon_i,
		fb_c2p_i								=> i_c2p_eeprom_per,
		fb_p2c_o								=> i_p2c_eeprom_per
	);

END GENERATE;
GNOEEPROM: IF NOT G_INCL_CS_EEPROM GENERATE
	I2C_SDA_io <= 'Z';
	I2C_SCL_io <= 'Z';
END GENERATE;



	cpu_halt_o <= i_dma_cpu_halt or i_blit_cpu_halt or i_aeris_cpu_halt;-- or i_snd_cpu_halt;
	cpu_int_o <= i_dma_cpu_int;

end rtl;

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
use work.fb_intcon_pack.all;
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
end fb_chipset;

architecture rtl of fb_chipset is

	function B2OZ(b:boolean) return natural is 
	begin
		if b then
			return 1;
		else
			return 0;
		end if;
	end function;

	-----------------------------------------------------------------------------
	-- work out number / order of controllers 
	-----------------------------------------------------------------------------

	constant MAS_NO_CHIPSET_AERIS			: natural := 0;
	constant MAS_NO_CHIPSET_SND			: natural := MAS_NO_CHIPSET_AERIS + B2OZ(G_INCL_CS_AERIS);
	constant MAS_NO_CHIPSET_DMA_0			: natural := MAS_NO_CHIPSET_SND + B2OZ(G_INCL_CS_SND);
	constant MAS_NO_CHIPSET_DMA_1			: natural := MAS_NO_CHIPSET_DMA_0 + B2OZ(G_INCL_CS_DMA AND G_DMA_CHANNELS >= 1);
	constant MAS_NO_CHIPSET_BLIT 			: natural := MAS_NO_CHIPSET_DMA_1 + B2OZ(G_INCL_CS_DMA AND G_DMA_CHANNELS >= 2);
	constant CONTROLLER_COUNT_CHIPSET	: natural := MAS_NO_CHIPSET_BLIT + B2OZ(G_INCL_CS_BLIT);

	-----------------------------------------------------------------------------
	-- work out number / order of peripherals 
	-----------------------------------------------------------------------------


	constant PERIPHERAL_NO_CHIPSET_DMA		: natural := 0;
	constant PERIPHERAL_NO_CHIPSET_SOUND	: natural := PERIPHERAL_NO_CHIPSET_DMA + B2OZ(G_INCL_CS_DMA);
	constant PERIPHERAL_NO_CHIPSET_BLIT		: natural := PERIPHERAL_NO_CHIPSET_SOUND + B2OZ(G_INCL_CS_SND);
	constant PERIPHERAL_NO_CHIPSET_AERIS	: natural := PERIPHERAL_NO_CHIPSET_BLIT + B2OZ(G_INCL_CS_BLIT);
	constant PERIPHERAL_NO_CHIPSET_EEPROM	: natural := PERIPHERAL_NO_CHIPSET_AERIS + B2OZ(G_INCL_CS_AERIS);
	constant PERIPHERAL_COUNT_CHIPSET		: natural := PERIPHERAL_NO_CHIPSET_EEPROM + B2OZ(G_INCL_CS_EEPROM);


	-----------------------------------------------------------------------------
	-- component definitions for optional components
	-----------------------------------------------------------------------------

	component fb_dmac_aeris is
		generic (
			SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up	
			CLOCKSPEED							: natural
		);
	   Port (
			-- fishbone signals		
			fb_syscon_i							: in		fb_syscon_t;

			-- peripheral interface (control registers)
			fb_per_c2p_i						: in		fb_con_o_per_i_t;
			fb_per_p2c_o						: out		fb_con_i_per_o_t;

			-- controller interface (dma)
			fb_con_c2p_o						: out		fb_con_o_per_i_t;
			fb_con_p2c_i						: in		fb_con_i_per_o_t;

			cpu_halt_o							: out		std_logic;

			hsync_i								: in		std_logic;
			vsync_i								: in		std_logic;

			dbg_state_o							: out		std_logic_vector(3 downto 0)

		);
	end component;

	component fb_dmac_blit is
		generic (
			SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up	
			G_STRIDE_HIGH						: integer := 11
		);
	   Port (
			-- fishbone signals		
			fb_syscon_i							: in		fb_syscon_t;

			-- peripheral interface (control registers)
			fb_per_c2p_i						: in		fb_con_o_per_i_t;
			fb_per_p2c_o						: out		fb_con_i_per_o_t;

			-- controller interface (dma)
			fb_con_c2p_o						: out		fb_con_o_per_i_t;
			fb_con_p2c_i						: in		fb_con_i_per_o_t;

			cpu_halt_o							: out		std_logic;
			blit_halt_i							: in		std_logic
		);
	end component;

	component fb_DMAC_int_dma is
		 generic (
			SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up	
			G_CHANNELS							: natural := 2;
			CLOCKSPEED							: natural
		 );
	    Port (

			-- fishbone signals		
			fb_syscon_i							: in		fb_syscon_t;

			-- peripheral interface (control registers)
			fb_per_c2p_i						: in		fb_con_o_per_i_t;
			fb_per_p2c_o						: out		fb_con_i_per_o_t;

			-- controller interface (dma)
			fb_con_c2p_o						: out		fb_con_o_per_i_arr(G_CHANNELS-1 downto 0);
			fb_con_p2c_i						: in		fb_con_i_per_o_arr(G_CHANNELS-1 downto 0);

			int_o									: out		STD_LOGIC;		-- interrupt active hi
			cpu_halt_o							: out		STD_LOGIC;
			dma_halt_i							: in		STD_LOGIC
		 );
	end component;


	component fb_DMAC_int_sound is
		generic (
			SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up	
			G_CHANNELS							: natural := 4
		);
		Port (

			-- fishbone signals		
			fb_syscon_i							: in		fb_syscon_t;

			-- peripheral interface (control registers)
			fb_per_c2p_i						: in		fb_con_o_per_i_t;
			fb_per_p2c_o						: out		fb_con_i_per_o_t;

			-- controller interface (dma)
			fb_con_c2p_o						: out		fb_con_o_per_i_t;
			fb_con_p2c_i						: in		fb_con_i_per_o_t;

			-- sound specific
			snd_clk_i							: in		std_logic;
			snd_dat_o							: out		signed(9 downto 0);
			snd_dat_change_clken_o			: out		std_logic
		);
	end component;

	component fb_i2c is
		generic (
			SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
			CLOCKSPEED							: natural := 128;								-- fast clock speed in mhz				
			BUS_SPEED							: natural := 400000							-- i2c bus speed in Hz
		);
		port(

			-- eeprom signals
			I2C_SCL_io							: inout	std_logic;
			I2C_SDA_io							: inout	std_logic;

			-- fishbone signals

			fb_syscon_i							: in		fb_syscon_t;
			fb_c2p_i								: in		fb_con_o_per_i_t;
			fb_p2c_o								: out		fb_con_i_per_o_t

		);
	end component;

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

	-- null peripheral for out-of range addresses
	signal i_c2p_null_per		: fb_con_o_per_i_t;
	signal i_p2c_null_per		: fb_con_i_per_o_t;

	-- chipset controller->peripheral
	signal i_con_c2p_chipset	: fb_con_o_per_i_arr(CONTROLLER_COUNT_CHIPSET-1 downto 0);
	signal i_con_p2c_chipset	: fb_con_i_per_o_arr(CONTROLLER_COUNT_CHIPSET-1 downto 0);
	-- chipset peripheral->controller - note+1 for unsel
	signal i_per_c2p_chipset	: fb_con_o_per_i_arr(PERIPHERAL_COUNT_CHIPSET downto 0);
	signal i_per_p2c_chipset	: fb_con_i_per_o_arr(PERIPHERAL_COUNT_CHIPSET downto 0);


	-----------------------------------------------------------------------------
	-- inter component (non-fishbone) signals
	-----------------------------------------------------------------------------

	-- chipset c2p intcon to peripheral sel
	signal i_chipset_intcon_peripheral_sel_addr		: std_logic_vector(9 downto 0);
		-- NOTE: plus 1 for dummy channel for "no peripheral"
	signal i_chipset_intcon_peripheral_sel			: unsigned(numbits(PERIPHERAL_COUNT_CHIPSET+1)-1 downto 0);  -- address decoded selected peripheral
	signal i_chipset_intcon_peripheral_sel_oh		: std_logic_vector(PERIPHERAL_COUNT_CHIPSET downto 0);	-- address decoded selected peripherals as one-hot		


	signal i_dma_cpu_int					: std_logic;							-- interrupt out from dma
	signal i_dma_cpu_halt				: std_logic;							-- cpu halt request out from dma
	signal i_blit_cpu_halt				: std_logic;							-- cpu halt request out from blit
	signal i_aeris_cpu_halt				: std_logic;							-- cpu halt request out from aeris


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


	G_NO_CONTROLLERS:IF CONTROLLER_COUNT_CHIPSET = 0 GENERATE
		fb_con_c2p_o <= fb_c2p_unsel;
	END GENERATE;
	G_ONE_CONTROLLER:IF CONTROLLER_COUNT_CHIPSET = 1 GENERATE
		fb_con_c2p_o <= i_con_c2p_chipset(0);
		i_con_p2c_chipset(0) <= fb_con_p2c_i;
	END GENERATE;
	G_MANY_CONTROLLER:IF CONTROLLER_COUNT_CHIPSET >1 GENERATE

		-- multiplex all the chipset controller ports down to a single 
		-- controller out to the top level resources
		e_chipset_con:fb_intcon_many_to_one
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
	END GENERATE;

	--TODO: have a default chipset peripheral that returns FF?

	-- address decode to select peripheral
	e_addr2s_chipset:entity work.address_decode_chipset
	generic map (
		SIM							=> SIM,
		G_PERIPHERAL_NO_CHIPSET_DMA		=> PERIPHERAL_NO_CHIPSET_DMA,
		G_PERIPHERAL_NO_CHIPSET_SOUND		=> PERIPHERAL_NO_CHIPSET_SOUND,
		G_PERIPHERAL_NO_CHIPSET_BLIT		=> PERIPHERAL_NO_CHIPSET_BLIT,
		G_PERIPHERAL_NO_CHIPSET_AERIS		=> PERIPHERAL_NO_CHIPSET_AERIS,
		G_PERIPHERAL_NO_CHIPSET_EEPROM 	=> PERIPHERAL_NO_CHIPSET_EEPROM,
		G_PERIPHERAL_COUNT_CHIPSET 		=> PERIPHERAL_COUNT_CHIPSET
	)
	port map (
		addr_i						=> i_chipset_intcon_peripheral_sel_addr,
		peripheral_sel_o			=> i_chipset_intcon_peripheral_sel,
		peripheral_sel_oh_o		=> i_chipset_intcon_peripheral_sel_oh
	);

	e_fb_intcon_chipset:entity work.fb_intcon_one_to_many
	generic map (
		SIM => SIM,
		G_PERIPHERAL_COUNT => PERIPHERAL_COUNT_CHIPSET+1, -- NOTE: +1 for unsel
		G_ADDRESS_WIDTH => 10,
		G_REGISTER_CON_READS => true
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


	e_fb_null:entity work.fb_null
	 generic map (
		SIM									=> SIM,
		G_READ_VAL							=> x"FF"
	 )
    Port map (

		-- fishbone signals		
		fb_syscon_i							=> fb_syscon_i,

		-- peripheral interface (control registers)
		fb_c2p_i								=> i_c2p_null_per,
		fb_p2c_o								=> i_p2c_null_per
	);

	i_per_p2c_chipset(PERIPHERAL_COUNT_CHIPSET)	<=	i_p2c_null_per;
	i_c2p_null_per 		<= i_per_c2p_chipset(PERIPHERAL_COUNT_CHIPSET);


GDMA:IF G_INCL_CS_DMA GENERATE

	G_DMA_C:FOR I in 0 TO G_DMA_CHANNELS-1 GENERATE
		
		i_con_c2p_chipset(MAS_NO_CHIPSET_DMA_0 + I)	<= i_c2p_dma_con(I);
		i_p2c_dma_con(i) 	<= i_con_p2c_chipset(MAS_NO_CHIPSET_DMA_0 + I);
	END GENERATE;
	
	i_per_p2c_chipset(PERIPHERAL_NO_CHIPSET_DMA)	<=	i_p2c_dma_per;
	i_c2p_dma_per 		<= i_per_c2p_chipset(PERIPHERAL_NO_CHIPSET_DMA);

	e_fb_dma:fb_DMAC_int_dma
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

	e_fb_blit:fb_dmac_blit
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

	e_fb_aeris:fb_dmac_aeris
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

	e_fb_snd:fb_DMAC_int_sound
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
		snd_dat_o							=> snd_dat_o,
		snd_dat_change_clken_o			=> snd_dat_change_clken_o
	 );

END GENERATE;


GEEPROM: IF G_INCL_CS_EEPROM GENERATE
	i_c2p_eeprom_per <= i_per_c2p_chipset(PERIPHERAL_NO_CHIPSET_EEPROM);
	i_per_p2c_chipset(PERIPHERAL_NO_CHIPSET_EEPROM)	<=	i_p2c_eeprom_per;

	e_fb_eeprom:fb_i2c
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



	cpu_halt_o <= i_dma_cpu_halt or i_blit_cpu_halt or i_aeris_cpu_halt;
	cpu_int_o <= i_dma_cpu_int;

end rtl;

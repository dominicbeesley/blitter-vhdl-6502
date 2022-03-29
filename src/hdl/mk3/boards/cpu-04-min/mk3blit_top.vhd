-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	4/4/2019
-- Design Name: 
-- Module Name:    	dip 40 blitter - mk2 product board
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		PoC blitter and 6502/6809/Z80/68008 cpu board with 2M RAM, 256k ROM
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--use work.mk1board_types.all;

library work;
use work.common.all;
use work.fishbone.all;
use work.board_config_pack.all;

entity mk3blit_top is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up
	);
	port(
		-- crystal osc 48Mhz - on WS board
		CLK_48M_i							: in		std_logic;

		-- 2M RAM/256K ROM bus (45)
		MEM_A_o								: out		std_logic_vector(20 downto 0);
		MEM_D_io								: inout	std_logic_vector(7 downto 0);	-- 17 bit RAMs used but D[7..0] is multiplexed with D[15..8]
		MEM_nOE_o							: out		std_logic;
		MEM_nWE_o							: out		std_logic;							-- add external pull-up

		MEM_FL_nCE_o						: out		std_logic;				
		MEM_RAM_nCE_o						: out		std_logic_vector(3 downto 0);
		
		-- 1 bit DAC sound out stereo, aux connectors mirror main (2)
		SND_L_o								: out		std_logic;
		SND_R_o								: out		std_logic;

		-- hdmi (11)

		HDMI_SCL_io							: inout		std_logic;
		HDMI_SDA_io							: inout	std_logic;
		HDMI_HPD_i							: in		std_logic;
		HDMI_CK_o							: out		std_logic;
		HDMI_D0_o							: out		std_logic;
		HDMI_D1_o							: out		std_logic;
		HDMI_D2_o							: out		std_logic;
		
		-- sdcard (5)
		SD_CS_o								: out		std_logic;
		SD_CLK_o								: out		std_logic;
		SD_MOSI_o							: out		std_logic;
		SD_MISO_i							: in		std_logic;
		SD_DET_i								: in		std_logic;

		-- SYS bus connects to SYStem CPU socket (38)

		SUP_nRESET_i						: in		std_logic;								-- SYStem reset after supervisor

		SYS_A_o								: out		std_logic_vector(15 downto 0);
		SYS_D_io								: inout	std_logic_vector(7 downto 0);
		SYS_BUF_D_DIR_o					: out		std_logic;
		SYS_BUF_D_nOE_o					: out		std_logic;
		
		SYS_SYNC_o							: out		std_logic;
		SYS_PHI1_o							: out		std_logic;
		SYS_PHI2_o							: out		std_logic;
		SYS_RnW_o							: out		std_logic;


		-- test these as outputs!!!
		SYS_RDY_i							: in 		std_logic; -- BBC Master only?
		SYS_nNMI_i							: in 		std_logic;
		SYS_nIRQ_i							: in 		std_logic;
		SYS_PHI0_i							: in 		std_logic;
		SYS_nDBE_i							: in 		std_logic;


		-- SYS configuration and auxiliary (18)
		SYS_AUX_io							: inout	std_logic_vector(6 downto 0);
		SYS_AUX_o							: out		std_logic_vector(3 downto 0);

		-- rpi interface (26)
		--rpi_gpio								: inout	std_logic_vector(27 downto 2);


		-- i2c EEPROM (2)
		I2C_SCL_io							: inout		std_logic;
		I2C_SDA_io							: inout	std_logic;


		-- cpu / expansion sockets (56)

		exp_PORTA_io						: inout	std_logic_vector(7 downto 0);
		exp_PORTA_nOE_o					: out		std_logic;
		exp_PORTA_DIR_o					: out		std_logic;

		exp_PORTB_o							: out		std_logic_vector(7 downto 0);

		exp_PORTC_io						: inout 	std_logic_vector(11 downto 0);
		exp_PORTD_io						: inout	std_logic_vector(11 downto 0);

		exp_PORTEFG_io						: inout	std_logic_vector(11 downto 0);
		exp_PORTE_nOE						: out		std_logic;
		exp_PORTF_nOE						: out		std_logic;
		exp_PORTG_nOE						: out		std_logic;


		-- LEDs 
		LED_o									: out		std_logic_vector(3 downto 0);

		BTNUSER_i							: in		std_logic_vector(1 downto 0)

	);
end mk3blit_top;

architecture rtl of mk3blit_top is

begin

e_top:entity work.mk3blit 
	generic map (
		SIM									=> SIM,
		CLOCKSPEED							=> 128,
		
		G_INCL_CHIPSET						=> true,
		G_INCL_CS_DMA						=> true,
		G_DMA_CHANNELS						=> 1,
		G_INCL_CS_BLIT						=> false,
		G_INCL_CS_SND						=> true,
		G_INCL_CS_AERIS					=> false,
		
		G_INCL_CPU_T65						=> true,
		G_INCL_CPU_65C02					=> false,
		G_INCL_CPU_6800					=> true,
		G_INCL_CPU_80188					=> true,		
		G_INCL_CPU_65816					=> true,
		G_INCL_CPU_6x09					=> true,
		G_INCL_CPU_Z80						=> false,
		G_INCL_CPU_68k						=> true,

		G_MEM_SWRAM_SLOT					=> 1,
		G_MEM_FAST_IS_10					=> true,
		G_MEM_SLOW_IS_45					=> true

	)
	port map (
		CLK_48M_i 							=> CLK_48M_i,
		MEM_A_o 								=> MEM_A_o,
		MEM_D_io 							=> MEM_D_io,
		MEM_nOE_o 							=> MEM_nOE_o,
		MEM_nWE_o 							=> MEM_nWE_o,
		MEM_FL_nCE_o 						=> MEM_FL_nCE_o,
		MEM_RAM_nCE_o 						=> MEM_RAM_nCE_o,
		SND_L_o 								=> SND_L_o,
		SND_R_o 								=> SND_R_o,
		HDMI_SCL_io 							=> HDMI_SCL_io,
		HDMI_SDA_io 						=> HDMI_SDA_io,
		HDMI_HPD_i 							=> HDMI_HPD_i,
		HDMI_CK_o 							=> HDMI_CK_o,
		HDMI_D0_o 							=> HDMI_D0_o,
		HDMI_D1_o 							=> HDMI_D1_o,
		HDMI_D2_o 							=> HDMI_D2_o,
		SD_CS_o 								=> SD_CS_o,
		SD_CLK_o 							=> SD_CLK_o,
		SD_MOSI_o 							=> SD_MOSI_o,
		SD_MISO_i 							=> SD_MISO_i,
		SD_DET_i 							=> SD_DET_i,
		SUP_nRESET_i 						=> SUP_nRESET_i,
		SYS_A_o 								=> SYS_A_o,
		SYS_D_io 							=> SYS_D_io,
		SYS_BUF_D_DIR_o 					=> SYS_BUF_D_DIR_o,
		SYS_BUF_D_nOE_o 					=> SYS_BUF_D_nOE_o,
		SYS_SYNC_o 							=> SYS_SYNC_o,
		SYS_PHI1_o 							=> SYS_PHI1_o,
		SYS_PHI2_o 							=> SYS_PHI2_o,
		SYS_RnW_o 							=> SYS_RnW_o,
		SYS_RDY_i 							=> SYS_RDY_i,
		SYS_nNMI_i 							=> SYS_nNMI_i,
		SYS_nIRQ_i 							=> SYS_nIRQ_i,
		SYS_PHI0_i 							=> SYS_PHI0_i,
		SYS_nDBE_i 							=> SYS_nDBE_i,
		SYS_AUX_io 							=> SYS_AUX_io,
		SYS_AUX_o 							=> SYS_AUX_o,
		I2C_SCL_io 							=> I2C_SCL_io,
		I2C_SDA_io 							=> I2C_SDA_io,
		exp_PORTA_io 						=> exp_PORTA_io,
		exp_PORTA_nOE_o 					=> exp_PORTA_nOE_o,
		exp_PORTA_DIR_o 					=> exp_PORTA_DIR_o,
		exp_PORTB_o 						=> exp_PORTB_o,
		exp_PORTC_io 						=> exp_PORTC_io,
		exp_PORTD_io 						=> exp_PORTD_io,
		exp_PORTEFG_io 					=> exp_PORTEFG_io,
		exp_PORTE_nOE 						=> exp_PORTE_nOE,
		exp_PORTF_nOE 						=> exp_PORTF_nOE,
		exp_PORTG_nOE 						=> exp_PORTG_nOE,
		LED_o		 							=> LED_o,
		BTNUSER_i 							=> BTNUSER_i
	);

end rtl;

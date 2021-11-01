-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2009 Benjamin Krill <benjamin@krll.de>
-- Copyright (c) 2020 Dominic Beesley <dominic@dossytronics.net>
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
-- Create Date:    	15/7/2021
-- Design Name: 
-- Module Name:    	mk.3 board first light test and ERC
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		flash some and output RS323 strings on various pins for board testing
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

entity mk3_board_erc is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural := 128;								-- fast clock speed in mhz				
		G_DMA_CHANNELS						: natural := 2;
		G_SND_CHANNELS						: natural := 4;
		G_MASTER_COUNT						: natural := 9;
		G_SLAVE_COUNT						: natural := 10;
		G_JIM_DEVNO							: std_logic_vector(7 downto 0) := x"D1"
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

		HDMI_SCL_o							: out		std_logic;
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
		SYS_RDY_i							: out 		std_logic; -- Master only?-- WARNING
		SYS_nNMI_i							: out 		std_logic;-- WARNING
		SYS_nIRQ_i							: out 		std_logic;-- WARNING
		SYS_PHI0_i							: out 		std_logic;-- WARNING
		SYS_nDBE_i							: out 		std_logic;-- WARNING


		-- SYS configuration and auxiliary (18)
		SYS_AUX_io							: inout	std_logic_vector(6 downto 0);
		SYS_AUX_o							: out		std_logic_vector(3 downto 0);

		-- rpi interface (26)
		--rpi_gpio								: inout	std_logic_vector(27 downto 2);


		-- i2c EEPROM (2)
		I2C_SCL_o							: out		std_logic;
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
end mk3_board_erc;

architecture rtl of mk3_firstlight is

signal ctr		: unsigned(28 downto 0);

signal bauddiv : integer range 0 to 4999;
signal bit_clk : std_logic;

begin

	p:process(CLK_48M_i)
	begin
		if rising_edge(CLK_48M_i) then
			ctr <= ctr + 1;
		end if;

	end process;

	p_bit_clk:process(CLK_48M_i)
	begin
		if rising_edge(CLK_48M_i) then
			bit_clk <= '0';
			if bauddiv >= 4999 then
				bauddiv <= 0;
				bit_clk <= '1';
			else
				bauddiv <= bauddiv + 1;	
			end if;
		end if;

	end process;

	MEM_nOE_o <= '1';

	e_MEM_A_o0:entity work.serialout generic map (message => "MA0 ") port map (bit_clk => bit_clk, so => MEM_A_o(0));
	e_MEM_A_o1:entity work.serialout generic map (message => "MA1 ") port map (bit_clk => bit_clk, so => MEM_A_o(1));
	e_MEM_A_o2:entity work.serialout generic map (message => "MA2 ") port map (bit_clk => bit_clk, so => MEM_A_o(2));
	e_MEM_A_o3:entity work.serialout generic map (message => "MA3 ") port map (bit_clk => bit_clk, so => MEM_A_o(3));
	e_MEM_A_o4:entity work.serialout generic map (message => "MA4 ") port map (bit_clk => bit_clk, so => MEM_A_o(4));
	e_MEM_A_o5:entity work.serialout generic map (message => "MA5 ") port map (bit_clk => bit_clk, so => MEM_A_o(5));
	e_MEM_A_o6:entity work.serialout generic map (message => "MA6 ") port map (bit_clk => bit_clk, so => MEM_A_o(6));
	e_MEM_A_o7:entity work.serialout generic map (message => "MA7 ") port map (bit_clk => bit_clk, so => MEM_A_o(7));
	e_MEM_A_o8:entity work.serialout generic map (message => "MA8 ") port map (bit_clk => bit_clk, so => MEM_A_o(8));
	e_MEM_A_o9:entity work.serialout generic map (message => "MA9 ") port map (bit_clk => bit_clk, so => MEM_A_o(9));
	e_MEM_A_o10:entity work.serialout generic map (message => "MA10") port map (bit_clk => bit_clk, so => MEM_A_o(10));
	e_MEM_A_o11:entity work.serialout generic map (message => "MA11") port map (bit_clk => bit_clk, so => MEM_A_o(11));
	e_MEM_A_o12:entity work.serialout generic map (message => "MA12") port map (bit_clk => bit_clk, so => MEM_A_o(12));
	e_MEM_A_o13:entity work.serialout generic map (message => "MA13") port map (bit_clk => bit_clk, so => MEM_A_o(13));
	e_MEM_A_o14:entity work.serialout generic map (message => "MA14") port map (bit_clk => bit_clk, so => MEM_A_o(14));
	e_MEM_A_o15:entity work.serialout generic map (message => "MA15") port map (bit_clk => bit_clk, so => MEM_A_o(15));
	e_MEM_A_o16:entity work.serialout generic map (message => "MA16") port map (bit_clk => bit_clk, so => MEM_A_o(16));
	e_MEM_A_o17:entity work.serialout generic map (message => "MA17") port map (bit_clk => bit_clk, so => MEM_A_o(17));
	e_MEM_A_o18:entity work.serialout generic map (message => "MA18") port map (bit_clk => bit_clk, so => MEM_A_o(18));
	e_MEM_A_o19:entity work.serialout generic map (message => "MA19") port map (bit_clk => bit_clk, so => MEM_A_o(19));
	e_MEM_A_o20:entity work.serialout generic map (message => "MA20") port map (bit_clk => bit_clk, so => MEM_A_o(20));

	e_MEM_D_io0:entity work.serialout generic map (message => "MD0 ") port map (bit_clk => bit_clk, so => MEM_D_io(0));
	e_MEM_D_io1:entity work.serialout generic map (message => "MD1 ") port map (bit_clk => bit_clk, so => MEM_D_io(1));
	e_MEM_D_io2:entity work.serialout generic map (message => "MD2 ") port map (bit_clk => bit_clk, so => MEM_D_io(2));
	e_MEM_D_io3:entity work.serialout generic map (message => "MD3 ") port map (bit_clk => bit_clk, so => MEM_D_io(3));
	e_MEM_D_io4:entity work.serialout generic map (message => "MD4 ") port map (bit_clk => bit_clk, so => MEM_D_io(4));
	e_MEM_D_io5:entity work.serialout generic map (message => "MD5 ") port map (bit_clk => bit_clk, so => MEM_D_io(5));
	e_MEM_D_io6:entity work.serialout generic map (message => "MD6 ") port map (bit_clk => bit_clk, so => MEM_D_io(6));
	e_MEM_D_io7:entity work.serialout generic map (message => "MD7 ") port map (bit_clk => bit_clk, so => MEM_D_io(7));


	e_MEM_nWE_o:entity work.serialout generic map (message => "MnWE") port map (bit_clk => bit_clk, so => MEM_nWE_o);
	e_MEM_FL_nCE_o:entity work.serialout generic map (message => "FnCE") port map (bit_clk => bit_clk, so => MEM_FL_nCE_o);
	e_MEM_RAM_nCE_o0:entity work.serialout generic map (message => "MRC0") port map (bit_clk => bit_clk, so => MEM_RAM_nCE_o(0));
	e_MEM_RAM_nCE_o1:entity work.serialout generic map (message => "MRC1") port map (bit_clk => bit_clk, so => MEM_RAM_nCE_o(1));
	e_MEM_RAM_nCE_o2:entity work.serialout generic map (message => "MRC2") port map (bit_clk => bit_clk, so => MEM_RAM_nCE_o(2));
	e_MEM_RAM_nCE_o3:entity work.serialout generic map (message => "MRC3") port map (bit_clk => bit_clk, so => MEM_RAM_nCE_o(3));


	LED_o <= std_logic_vector(ctr(ctr'HIGH downto ctr'HIGH-3));

	e_SYS_SYNC_o:entity work.serialout generic map (message => "SYNC") port map (bit_clk => bit_clk, so => SYS_SYNC_o);
	e_SYS_PHI1_o:entity work.serialout generic map (message => "PHI1") port map (bit_clk => bit_clk, so => SYS_PHI1_o);
	e_SYS_PHI2_o:entity work.serialout generic map (message => "PHI2") port map (bit_clk => bit_clk, so => SYS_PHI2_o);
	e_SYS_RnW_o:entity work.serialout generic map (message => "RnW ") port map (bit_clk => bit_clk, so => SYS_RnW_o);

	e_SYS_RDY_i_oo:entity work.serialout generic map (message => "RDY ") port map (bit_clk => bit_clk, so => SYS_RDY_i);
	e_SYS_nNMI_i_oo:entity work.serialout generic map (message => "nNMI") port map (bit_clk => bit_clk, so => SYS_nNMI_i);
	e_SYS_nIRQ_i_oo:entity work.serialout generic map (message => "nIRQ") port map (bit_clk => bit_clk, so => SYS_nIRQ_i);
	e_SYS_PHI0_i_oo:entity work.serialout generic map (message => "PHI0") port map (bit_clk => bit_clk, so => SYS_PHI0_i);
	e_SYS_nDBE_i_oo:entity work.serialout generic map (message => "nDBE") port map (bit_clk => bit_clk, so => SYS_nDBE_i);


	e_SAO0:entity work.serialout generic map (message => "SAO0") port map (bit_clk => bit_clk, so => SYS_AUX_o(0));
	e_SAO1:entity work.serialout generic map (message => "SAO1") port map (bit_clk => bit_clk, so => SYS_AUX_o(1));
	e_SAO2:entity work.serialout generic map (message => "SAO2") port map (bit_clk => bit_clk, so => SYS_AUX_o(2));
	e_SAO3:entity work.serialout generic map (message => "SAO3") port map (bit_clk => bit_clk, so => SYS_AUX_o(3));


	e_SA0:entity work.serialout generic map (message => "SA0 ") port map (bit_clk => bit_clk, so => SYS_AUX_io(0));
	e_SA1:entity work.serialout generic map (message => "SA1 ") port map (bit_clk => bit_clk, so => SYS_AUX_io(1));
	e_SA2:entity work.serialout generic map (message => "SA2 ") port map (bit_clk => bit_clk, so => SYS_AUX_io(2));
	e_SA3:entity work.serialout generic map (message => "SA3 ") port map (bit_clk => bit_clk, so => SYS_AUX_io(3));
	e_SA4:entity work.serialout generic map (message => "SA4 ") port map (bit_clk => bit_clk, so => SYS_AUX_io(4));
	e_SA5:entity work.serialout generic map (message => "SA5 ") port map (bit_clk => bit_clk, so => SYS_AUX_io(5));
	e_SA6:entity work.serialout generic map (message => "SA6 ") port map (bit_clk => bit_clk, so => SYS_AUX_io(6));

	SYS_BUF_D_DIR_o <= '0';
	SYS_BUF_D_nOE_o <= '0';

	e_SYSD0:entity work.serialout generic map (message => "SYD0") port map (bit_clk => bit_clk, so => SYS_D_io(0));
	e_SYSD1:entity work.serialout generic map (message => "SYD1") port map (bit_clk => bit_clk, so => SYS_D_io(1));
	e_SYSD2:entity work.serialout generic map (message => "SYD2") port map (bit_clk => bit_clk, so => SYS_D_io(2));
	e_SYSD3:entity work.serialout generic map (message => "SYD3") port map (bit_clk => bit_clk, so => SYS_D_io(3));
	e_SYSD4:entity work.serialout generic map (message => "SYD4") port map (bit_clk => bit_clk, so => SYS_D_io(4));
	e_SYSD5:entity work.serialout generic map (message => "SYD5") port map (bit_clk => bit_clk, so => SYS_D_io(5));
	e_SYSD6:entity work.serialout generic map (message => "SYD6") port map (bit_clk => bit_clk, so => SYS_D_io(6));
	e_SYSD7:entity work.serialout generic map (message => "SYD7") port map (bit_clk => bit_clk, so => SYS_D_io(7));

	e_SYSA0:entity work.serialout generic map (message => "SA0 ") port map (bit_clk => bit_clk, so => SYS_A_o(0));
	e_SYSA1:entity work.serialout generic map (message => "SA1 ") port map (bit_clk => bit_clk, so => SYS_A_o(1));
	e_SYSA2:entity work.serialout generic map (message => "SA2 ") port map (bit_clk => bit_clk, so => SYS_A_o(2));
	e_SYSA3:entity work.serialout generic map (message => "SA3 ") port map (bit_clk => bit_clk, so => SYS_A_o(3));
	e_SYSA4:entity work.serialout generic map (message => "SA4 ") port map (bit_clk => bit_clk, so => SYS_A_o(4));
	e_SYSA5:entity work.serialout generic map (message => "SA5 ") port map (bit_clk => bit_clk, so => SYS_A_o(5));
	e_SYSA6:entity work.serialout generic map (message => "SA6 ") port map (bit_clk => bit_clk, so => SYS_A_o(6));
	e_SYSA7:entity work.serialout generic map (message => "SA7 ") port map (bit_clk => bit_clk, so => SYS_A_o(7));
	e_SYSA8:entity work.serialout generic map (message => "SA8 ") port map (bit_clk => bit_clk, so => SYS_A_o(8));
	e_SYSA9:entity work.serialout generic map (message => "SA9 ") port map (bit_clk => bit_clk, so => SYS_A_o(9));
	e_SYSA10:entity work.serialout generic map (message => "SA10") port map (bit_clk => bit_clk, so => SYS_A_o(10));
	e_SYSA11:entity work.serialout generic map (message => "SA11") port map (bit_clk => bit_clk, so => SYS_A_o(11));
	e_SYSA12:entity work.serialout generic map (message => "SA12") port map (bit_clk => bit_clk, so => SYS_A_o(12));
	e_SYSA13:entity work.serialout generic map (message => "SA13") port map (bit_clk => bit_clk, so => SYS_A_o(13));
	e_SYSA14:entity work.serialout generic map (message => "SA14") port map (bit_clk => bit_clk, so => SYS_A_o(14));
	e_SYSA15:entity work.serialout generic map (message => "SA15") port map (bit_clk => bit_clk, so => SYS_A_o(15));



	e_A0:entity work.serialout generic map (message => "PA0 ") port map (bit_clk => bit_clk, so => exp_PORTA_io(0));
	e_A1:entity work.serialout generic map (message => "PA1 ") port map (bit_clk => bit_clk, so => exp_PORTA_io(1));
	e_A2:entity work.serialout generic map (message => "PA2 ") port map (bit_clk => bit_clk, so => exp_PORTA_io(2));
	e_A3:entity work.serialout generic map (message => "PA3 ") port map (bit_clk => bit_clk, so => exp_PORTA_io(3));
	e_A4:entity work.serialout generic map (message => "PA4 ") port map (bit_clk => bit_clk, so => exp_PORTA_io(4));
	e_A5:entity work.serialout generic map (message => "PA5 ") port map (bit_clk => bit_clk, so => exp_PORTA_io(5));
	e_A6:entity work.serialout generic map (message => "PA6 ") port map (bit_clk => bit_clk, so => exp_PORTA_io(6));
	e_A7:entity work.serialout generic map (message => "PA7 ") port map (bit_clk => bit_clk, so => exp_PORTA_io(7));

	e_B0:entity work.serialout generic map (message => "PB0 ") port map (bit_clk => bit_clk, so => exp_PORTB_o(0));
	e_B1:entity work.serialout generic map (message => "PB1 ") port map (bit_clk => bit_clk, so => exp_PORTB_o(1));
	e_B2:entity work.serialout generic map (message => "PB2 ") port map (bit_clk => bit_clk, so => exp_PORTB_o(2));
	e_B3:entity work.serialout generic map (message => "PB3 ") port map (bit_clk => bit_clk, so => exp_PORTB_o(3));
	e_B4:entity work.serialout generic map (message => "PB4 ") port map (bit_clk => bit_clk, so => exp_PORTB_o(4));
	e_B5:entity work.serialout generic map (message => "PB5 ") port map (bit_clk => bit_clk, so => exp_PORTB_o(5));
	e_B6:entity work.serialout generic map (message => "PB6 ") port map (bit_clk => bit_clk, so => exp_PORTB_o(6));
	e_B7:entity work.serialout generic map (message => "PB7 ") port map (bit_clk => bit_clk, so => exp_PORTB_o(7));


	exp_PORTA_DIR_o <= '0';
	exp_PORTA_nOE_o <= '0';

	e_C0:entity work.serialout generic map (message => "PC0 ") port map (bit_clk => bit_clk, so => exp_PORTC_io(0));
	e_C1:entity work.serialout generic map (message => "PC1 ") port map (bit_clk => bit_clk, so => exp_PORTC_io(1));
	e_C2:entity work.serialout generic map (message => "PC2 ") port map (bit_clk => bit_clk, so => exp_PORTC_io(2));
	e_C3:entity work.serialout generic map (message => "PC3 ") port map (bit_clk => bit_clk, so => exp_PORTC_io(3));
	e_C4:entity work.serialout generic map (message => "PC4 ") port map (bit_clk => bit_clk, so => exp_PORTC_io(4));
	e_C5:entity work.serialout generic map (message => "PC5 ") port map (bit_clk => bit_clk, so => exp_PORTC_io(5));
	e_C6:entity work.serialout generic map (message => "PC6 ") port map (bit_clk => bit_clk, so => exp_PORTC_io(6));
	e_C7:entity work.serialout generic map (message => "PC7 ") port map (bit_clk => bit_clk, so => exp_PORTC_io(7));
	e_C8:entity work.serialout generic map (message => "PC8 ") port map (bit_clk => bit_clk, so => exp_PORTC_io(8));
	e_C9:entity work.serialout generic map (message => "PC9 ") port map (bit_clk => bit_clk, so => exp_PORTC_io(9));
	e_C10:entity work.serialout generic map (message => "PC10") port map (bit_clk => bit_clk, so => exp_PORTC_io(10));
	e_C11:entity work.serialout generic map (message => "PC11") port map (bit_clk => bit_clk, so => exp_PORTC_io(11));

	e_D0:entity work.serialout generic map (message => "PD0 ") port map (bit_clk => bit_clk, so => exp_PORTD_io(0));
	e_D1:entity work.serialout generic map (message => "PD1 ") port map (bit_clk => bit_clk, so => exp_PORTD_io(1));
	e_D2:entity work.serialout generic map (message => "PD2 ") port map (bit_clk => bit_clk, so => exp_PORTD_io(2));
	e_D3:entity work.serialout generic map (message => "PD3 ") port map (bit_clk => bit_clk, so => exp_PORTD_io(3));
	e_D4:entity work.serialout generic map (message => "PD4 ") port map (bit_clk => bit_clk, so => exp_PORTD_io(4));
	e_D5:entity work.serialout generic map (message => "PD5 ") port map (bit_clk => bit_clk, so => exp_PORTD_io(5));
	e_D6:entity work.serialout generic map (message => "PD6 ") port map (bit_clk => bit_clk, so => exp_PORTD_io(6));
	e_D7:entity work.serialout generic map (message => "PD7 ") port map (bit_clk => bit_clk, so => exp_PORTD_io(7));
	e_D8:entity work.serialout generic map (message => "PD8 ") port map (bit_clk => bit_clk, so => exp_PORTD_io(8));
	e_D9:entity work.serialout generic map (message => "PD9 ") port map (bit_clk => bit_clk, so => exp_PORTD_io(9));
	e_D10:entity work.serialout generic map (message => "PD10") port map (bit_clk => bit_clk, so => exp_PORTD_io(10));
	e_D11:entity work.serialout generic map (message => "PD11") port map (bit_clk => bit_clk, so => exp_PORTD_io(11));

	e_EFG0:entity work.serialout generic map (message => "EF0 ") port map (bit_clk => bit_clk, so => exp_PORTEFG_io(0));
	e_EFG1:entity work.serialout generic map (message => "EF1 ") port map (bit_clk => bit_clk, so => exp_PORTEFG_io(1));
	e_EFG2:entity work.serialout generic map (message => "EF2 ") port map (bit_clk => bit_clk, so => exp_PORTEFG_io(2));
	e_EFG3:entity work.serialout generic map (message => "EF3 ") port map (bit_clk => bit_clk, so => exp_PORTEFG_io(3));
	e_EFG4:entity work.serialout generic map (message => "EF4 ") port map (bit_clk => bit_clk, so => exp_PORTEFG_io(4));
	e_EFG5:entity work.serialout generic map (message => "EF5 ") port map (bit_clk => bit_clk, so => exp_PORTEFG_io(5));
	e_EFG6:entity work.serialout generic map (message => "EF6 ") port map (bit_clk => bit_clk, so => exp_PORTEFG_io(6));
	e_EFG7:entity work.serialout generic map (message => "EF7 ") port map (bit_clk => bit_clk, so => exp_PORTEFG_io(7));
	e_EFG8:entity work.serialout generic map (message => "EF8 ") port map (bit_clk => bit_clk, so => exp_PORTEFG_io(8));
	e_EFG9:entity work.serialout generic map (message => "EF9 ") port map (bit_clk => bit_clk, so => exp_PORTEFG_io(9));
	e_EFG10:entity work.serialout generic map (message => "EF10") port map (bit_clk => bit_clk, so => exp_PORTEFG_io(10));
	e_EFG11:entity work.serialout generic map (message => "EF11") port map (bit_clk => bit_clk, so => exp_PORTEFG_io(11));

	exp_PORTE_nOE <= '0';
	exp_PORTF_nOE <= '0';
	exp_PORTG_nOE <= '0';

end rtl;

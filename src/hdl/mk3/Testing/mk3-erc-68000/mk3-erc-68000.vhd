-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2020 Dominic Beesley https://github.com/dominicbeesley
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
-- Module Name:    	mk.3 board first light test, 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Exercise the pins on a 68000 expansion board
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: The CPU shouldn't be in its socket and the board must be out of the motherboard or damage may occur
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity mk3_erc_68000 is
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


		
		SYS_RDY_i							: in		std_logic; -- BBC Master only?
		SYS_nNMI_i							: in		std_logic;
		SYS_nIRQ_i							: in		std_logic;
		SYS_PHI0_i							: in		std_logic;
		SYS_nDBE_i							: in		std_logic;


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
end mk3_erc_68000;

architecture rtl of mk3_erc_68000 is

signal ctr		: unsigned(28 downto 0);

signal bauddiv : integer range 0 to 4999;
signal bit_clk : std_logic;

signal	i_exp_PORTE : std_logic_vector(11 downto 0);
signal   i_exp_PORTF : std_logic_vector(11 downto 4);

begin


	exp_PORTEFG_io <= i_exp_PORTE when ctr(ctr'HIGH) = '1' else
							i_exp_PORTF & "ZZZZ";

	exp_PORTG_nOE <= '1';
	exp_PORTE_nOE <= not ctr(ctr'HIGH);
	exp_PORTF_nOE <= ctr(ctr'HIGH);


	LED_o <= std_logic_vector(ctr(ctr'HIGH downto ctr'HIGH-3));

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
	MEM_A_o <= (others => '1');
	MEM_D_io <= (others => '1');

	MEM_nWE_o <= '1';
	MEM_FL_nCE_o <= '1';
	MEM_RAM_nCE_o <= (others => '1');
	


	SYS_SYNC_o <= '1';
	SYS_PHI1_o <= not SYS_PHI0_i;
	SYS_PHI2_o <= SYS_PHI0_i;
	SYS_RnW_o <= '1';



	SYS_AUX_o <= std_logic_vector(ctr(ctr'high downto ctr'high-3));
	SYS_AUX_io <= std_logic_vector(ctr(ctr'high downto ctr'high-6));

	SYS_BUF_D_DIR_o <= '1';
	SYS_BUF_D_nOE_o <= '1';

	SYS_D_io <= (others => 'Z');
	SYS_A_o <= (others => '1');

	exp_PORTA_DIR_o <= '0';
	exp_PORTA_nOE_o <= '0';

	e_A0:entity work.serialout generic map (message => "D0  ") port map (bit_clk => bit_clk, so => exp_PORTA_io(0));
	e_A1:entity work.serialout generic map (message => "D1  ") port map (bit_clk => bit_clk, so => exp_PORTA_io(1));
	e_A2:entity work.serialout generic map (message => "D2  ") port map (bit_clk => bit_clk, so => exp_PORTA_io(2));
	e_A3:entity work.serialout generic map (message => "D3  ") port map (bit_clk => bit_clk, so => exp_PORTA_io(3));
	e_A4:entity work.serialout generic map (message => "D4  ") port map (bit_clk => bit_clk, so => exp_PORTA_io(4));
	e_A5:entity work.serialout generic map (message => "D5  ") port map (bit_clk => bit_clk, so => exp_PORTA_io(5));
	e_A6:entity work.serialout generic map (message => "D6  ") port map (bit_clk => bit_clk, so => exp_PORTA_io(6));
	e_A7:entity work.serialout generic map (message => "D7  ") port map (bit_clk => bit_clk, so => exp_PORTA_io(7));

	e_B0:entity work.serialout generic map (message => "VPA ") port map (bit_clk => bit_clk, so => exp_PORTB_o(0));
	e_B1:entity work.serialout generic map (message => "BERR") port map (bit_clk => bit_clk, so => exp_PORTB_o(1));
	e_B2:entity work.serialout generic map (message => "CLK ") port map (bit_clk => bit_clk, so => exp_PORTB_o(2));
	e_B3:entity work.serialout generic map (message => "BGAK") port map (bit_clk => bit_clk, so => exp_PORTB_o(3));
	e_B4:entity work.serialout generic map (message => "IPL1") port map (bit_clk => bit_clk, so => exp_PORTB_o(4));
	e_B5:entity work.serialout generic map (message => "IPL0") port map (bit_clk => bit_clk, so => exp_PORTB_o(5));
	e_B6:entity work.serialout generic map (message => "IPL2") port map (bit_clk => bit_clk, so => exp_PORTB_o(6));
	e_B7:entity work.serialout generic map (message => "DTAK") port map (bit_clk => bit_clk, so => exp_PORTB_o(7));

	e_C0:entity work.serialout generic map (message => "A0  ") port map (bit_clk => bit_clk, so => exp_PORTC_io(0));
	e_C1:entity work.serialout generic map (message => "A1  ") port map (bit_clk => bit_clk, so => exp_PORTC_io(1));
	e_C2:entity work.serialout generic map (message => "A2  ") port map (bit_clk => bit_clk, so => exp_PORTC_io(2));
	e_C3:entity work.serialout generic map (message => "A3  ") port map (bit_clk => bit_clk, so => exp_PORTC_io(3));
	e_C4:entity work.serialout generic map (message => "A4  ") port map (bit_clk => bit_clk, so => exp_PORTC_io(4));
	e_C5:entity work.serialout generic map (message => "A5  ") port map (bit_clk => bit_clk, so => exp_PORTC_io(5));
	e_C6:entity work.serialout generic map (message => "A6  ") port map (bit_clk => bit_clk, so => exp_PORTC_io(6));
	e_C7:entity work.serialout generic map (message => "A7  ") port map (bit_clk => bit_clk, so => exp_PORTC_io(7));
	e_C8:entity work.serialout generic map (message => "A16 ") port map (bit_clk => bit_clk, so => exp_PORTC_io(8));
	e_C9:entity work.serialout generic map (message => "A17 ") port map (bit_clk => bit_clk, so => exp_PORTC_io(9));
	e_C10:entity work.serialout generic map (message => "A18 ") port map (bit_clk => bit_clk, so => exp_PORTC_io(10));
	e_C11:entity work.serialout generic map (message => "A19 ") port map (bit_clk => bit_clk, so => exp_PORTC_io(11));

	e_D0:entity work.serialout generic map (message =>  "E   ") port map (bit_clk => bit_clk, so => exp_PORTD_io(0));
	e_D1:entity work.serialout generic map (message =>  "RnW ") port map (bit_clk => bit_clk, so => exp_PORTD_io(1));
	e_D2:entity work.serialout generic map (message =>  "UDS ") port map (bit_clk => bit_clk, so => exp_PORTD_io(2));
	e_D3:entity work.serialout generic map (message =>  "FC0 ") port map (bit_clk => bit_clk, so => exp_PORTD_io(3));
	e_D4:entity work.serialout generic map (message =>  "FC2 ") port map (bit_clk => bit_clk, so => exp_PORTD_io(4));
	e_D5:entity work.serialout generic map (message =>  "AS  ") port map (bit_clk => bit_clk, so => exp_PORTD_io(5));
	e_D6:entity work.serialout generic map (message =>  "FC1 ") port map (bit_clk => bit_clk, so => exp_PORTD_io(6));
	e_D7:entity work.serialout generic map (message =>  "BG  ") port map (bit_clk => bit_clk, so => exp_PORTD_io(7));
	e_D8:entity work.serialout generic map (message =>  "BR  ") port map (bit_clk => bit_clk, so => exp_PORTD_io(8));
	e_D9:entity work.serialout generic map (message =>  "RES ") port map (bit_clk => bit_clk, so => exp_PORTD_io(9));
	e_D10:entity work.serialout generic map (message => "HALT") port map (bit_clk => bit_clk, so => exp_PORTD_io(10));
	e_D11:entity work.serialout generic map (message => "VMA ") port map (bit_clk => bit_clk, so => exp_PORTD_io(11));

	e_EG0:entity work.serialout generic map  (message => "A8  ") port map (bit_clk => bit_clk, so => i_exp_PORTE(0));
	e_EG1:entity work.serialout generic map  (message => "A9  ") port map (bit_clk => bit_clk, so => i_exp_PORTE(1));
	e_EG2:entity work.serialout generic map  (message => "A10 ") port map (bit_clk => bit_clk, so => i_exp_PORTE(2));
	e_EG3:entity work.serialout generic map  (message => "A11 ") port map (bit_clk => bit_clk, so => i_exp_PORTE(3));
	e_EG4:entity work.serialout generic map  (message => "A12 ") port map (bit_clk => bit_clk, so => i_exp_PORTE(4));
	e_EG5:entity work.serialout generic map  (message => "A13 ") port map (bit_clk => bit_clk, so => i_exp_PORTE(5));
	e_EG6:entity work.serialout generic map  (message => "A14 ") port map (bit_clk => bit_clk, so => i_exp_PORTE(6));
	e_EG7:entity work.serialout generic map  (message => "A15 ") port map (bit_clk => bit_clk, so => i_exp_PORTE(7));
	e_EG8:entity work.serialout generic map  (message => "A20 ") port map (bit_clk => bit_clk, so => i_exp_PORTE(8));
	e_EG9:entity work.serialout generic map  (message => "A21 ") port map (bit_clk => bit_clk, so => i_exp_PORTE(9));
	e_EG10:entity work.serialout generic map (message => "A22 ") port map (bit_clk => bit_clk, so => i_exp_PORTE(10));
	e_EG11:entity work.serialout generic map (message => "A23 ") port map (bit_clk => bit_clk, so => i_exp_PORTE(11));

	e_FG4:entity work.serialout generic map  (message => "D8  ") port map (bit_clk => bit_clk, so => i_exp_PORTF(4));
	e_FG5:entity work.serialout generic map  (message => "D9  ") port map (bit_clk => bit_clk, so => i_exp_PORTF(5));
	e_FG6:entity work.serialout generic map  (message => "D10 ") port map (bit_clk => bit_clk, so => i_exp_PORTF(6));
	e_FG7:entity work.serialout generic map  (message => "D11 ") port map (bit_clk => bit_clk, so => i_exp_PORTF(7));
	e_FG8:entity work.serialout generic map  (message => "D12 ") port map (bit_clk => bit_clk, so => i_exp_PORTF(8));
	e_FG9:entity work.serialout generic map  (message => "D13 ") port map (bit_clk => bit_clk, so => i_exp_PORTF(9));
	e_FG10:entity work.serialout generic map (message => "D14 ") port map (bit_clk => bit_clk, so => i_exp_PORTF(10));
	e_FG11:entity work.serialout generic map (message => "D15 ") port map (bit_clk => bit_clk, so => i_exp_PORTF(11));


end rtl;

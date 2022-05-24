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

entity mk2_erc is
	port(

		-- crystal osc 48MHz - not fitted on blit board
		CLK_48M_i							: in		std_logic;	

		-- crystal osc 50Mhz - on WS board
		CLK_50M_i							: in		std_logic;
	
		-- 2M RAM/256K ROM bus
		MEM_A_o								: out		std_logic_vector(20 downto 0);
		MEM_D_io								: out		std_logic_vector(7 downto 0);
		MEM_nOE_o							: out		std_logic;
		MEM_ROM_nWE_o						: out		std_logic;
		MEM_RAM_nWE_o						: out		std_logic;
		MEM_ROM_nCE_o						: out		std_logic;
		MEM_RAM0_nCE_o						: out		std_logic;
		
		-- 1 bit DAC sound out stereo, aux connectors mirror main
		SND_BITS_L_o						: out		std_logic;
		SND_BITS_L_AUX_o					: out		std_logic;
		SND_BITS_R_o						: out		std_logic;
		SND_BITS_R_AUX_o					: out		std_logic;
		
		-- 	SYS bus connects to SYStem CPU socket


		SUP_nRESET_i						: in		std_logic;								-- SYStem reset after supervisor
		EXT_nRESET_i						: in		std_logic;								-- WS button

		SYS_A_o								: out		std_logic_vector(15 downto 0);
		SYS_D_io								: out	std_logic_vector(7 downto 0);
		
		-- SYS signals are connected direct to the BBC cpu socket
		SYS_RDY_i							: out		std_logic; -- Master only?
		SYS_nNMI_i							: out		std_logic;
		SYS_nIRQ_i							: out		std_logic;
		SYS_SYNC_o							: out		std_logic;
		SYS_PHI0_i							: out		std_logic;
		SYS_PHI1_o							: out		std_logic;
		SYS_PHI2_o							: out		std_logic;
		SYS_RnW_o							: out		std_logic;


		-- CPU sockets, shared lines for 6502/65102/65816/6809,Z80,68008
		-- shared names are of the form CPUSKT_aaa[C[bbb][6ccc][9ddd][Keee][Zfff]
		-- aaa = NMOS 6502 and other 6502 derivatives (65c02, 65816) unless overridden
		-- bbb = CMOS 65C102-(if directly followed by 6ccc use that interpretation)
		-- ccc = WDC 65816	
		-- ddd = 6309/6809
		-- eee = Z80
		-- fff = MC68008

		-- NC indicates Not Connected in a mode

		CPUSKT_A_i									: out		std_logic_vector(19 downto 0);
		CPUSKT_D_io									: out  std_logic_vector(7 downto 0);

		CPUSKT_6EKEZnRD_i							: out		std_logic;		
		CPUSKT_C6nML9BUSYKnBGZnBUSACK_i		: out		std_logic;
		CPUSKT_RnWZnWR_i							: out		std_logic;
		CPUSKT_PHI16ABRT9BSKnDS_i				: out		std_logic;		-- 6ABRT is actually an output but pulled up on the board
		CPUSKT_PHI26VDAKFC0ZnMREQ_i			: out		std_logic;
		CPUSKT_SYNC6VPA9LICKFC2ZnM1_i			: out		std_logic;
		CPUSKT_VSS6VPB9BAKnAS_i					: out		std_logic;
		CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i		: out		std_logic;		-- nSO is actually an output but pulled up on the board


		CPUSKT_6BE9TSCKnVPA_o					: out		std_logic;
		CPUSKT_9Q_o									: out		std_logic;
		CPUSKT_KnBRZnBUSREQ_o					: out		std_logic;
		CPUSKT_PHI09EKZCLK_o						: out		std_logic;
		CPUSKT_RDY9KnHALTZnWAIT_o				: out		std_logic;
		CPUSKT_nIRQKnIPL1_o						: out		std_logic;
		CPUSKT_nNMIKnIPL02_o						: out		std_logic;
		CPUSKT_nRES_o								: out		std_logic;
		CPUSKT_9nFIRQLnDTACK_o					: out		std_logic;

		-- LEDs 
		LED_o										: out		std_logic_vector(3 downto 0);

		-- CONFIG / TEST connector

		CFG_io									: out	std_logic_vector(15 downto 0);

		-- i2c EEPROM
		I2C_SCL_io								: out		std_logic;
		I2C_SDA_io							: out	std_logic

	);
end mk2_erc;

architecture rtl of mk2_erc is

signal ctr		: unsigned(28 downto 0);

signal bauddiv : integer range 0 to 5207;
signal bit_clk : std_logic;

begin

	p:process(CLK_50M_i)
	begin
		if rising_edge(CLK_50M_i) then
			ctr <= ctr + 1;
		end if;

	end process;

	p_bit_clk:process(CLK_50M_i)
	begin
		if rising_edge(CLK_50M_i) then
			bit_clk <= '0';
			if bauddiv = 5207 then
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


	e_MEM_ROM_nWE_o:entity work.serialout generic map (message => "ROWE") port map (bit_clk => bit_clk, so => MEM_ROM_nWE_o);
	e_MEM_RAM_nWE_o:entity work.serialout generic map (message => "RAWE") port map (bit_clk => bit_clk, so => MEM_RAM_nWE_o);
	e_MEM_ROM_nCE_o:entity work.serialout generic map (message => "FnCE") port map (bit_clk => bit_clk, so => MEM_ROM_nCE_o);
	e_MEM_RAM0_nCE_o0:entity work.serialout generic map (message => "MRC0") port map (bit_clk => bit_clk, so => MEM_RAM0_nCE_o);

	e_LED_o0:entity work.serialout generic map (message => "LED0") port map (bit_clk => bit_clk, so => LED_o(0));
	e_LED_o1:entity work.serialout generic map (message => "LED1") port map (bit_clk => bit_clk, so => LED_o(1));
	e_LED_o2:entity work.serialout generic map (message => "LED2") port map (bit_clk => bit_clk, so => LED_o(2));
	e_LED_o3:entity work.serialout generic map (message => "LED3") port map (bit_clk => bit_clk, so => LED_o(3));


	e_SYS_SYNC_o:entity work.serialout generic map (message => "SYNC") port map (bit_clk => bit_clk, so => SYS_SYNC_o);
	e_SYS_PHI1_o:entity work.serialout generic map (message => "PHI1") port map (bit_clk => bit_clk, so => SYS_PHI1_o);
	e_SYS_PHI2_o:entity work.serialout generic map (message => "PHI2") port map (bit_clk => bit_clk, so => SYS_PHI2_o);
	e_SYS_RnW_o:entity work.serialout generic map (message => "RnW ") port map (bit_clk => bit_clk, so => SYS_RnW_o);

	e_SYS_RDY_i_oo:entity work.serialout generic map (message => "RDY ") port map (bit_clk => bit_clk, so => SYS_RDY_i);
	e_SYS_nNMI_i_oo:entity work.serialout generic map (message => "nNMI") port map (bit_clk => bit_clk, so => SYS_nNMI_i);
	e_SYS_nIRQ_i_oo:entity work.serialout generic map (message => "nIRQ") port map (bit_clk => bit_clk, so => SYS_nIRQ_i);
	e_SYS_PHI0_i_oo:entity work.serialout generic map (message => "PHI0") port map (bit_clk => bit_clk, so => SYS_PHI0_i);
	

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

e_SND_BITS_L_o:		entity work.serialout generic map (message => "SNDL") port map (bit_clk => bit_clk, so => SND_BITS_L_o);
e_SND_BITS_L_AUX_o:	entity work.serialout generic map (message => "SNAL") port map (bit_clk => bit_clk, so => SND_BITS_L_AUX_o);
e_SND_BITS_R_o:		entity work.serialout generic map (message => "SNDR") port map (bit_clk => bit_clk, so => SND_BITS_R_o);
e_SND_BITS_R_AUX_o:	entity work.serialout generic map (message => "SNAR") port map (bit_clk => bit_clk, so => SND_BITS_R_AUX_o);

e_CPUSKT_A_i0:		entity work.serialout generic map (message => "CA00") port map (bit_clk => bit_clk, so => CPUSKT_A_i(0));
e_CPUSKT_A_i1:		entity work.serialout generic map (message => "CA01") port map (bit_clk => bit_clk, so => CPUSKT_A_i(1));
e_CPUSKT_A_i2:		entity work.serialout generic map (message => "CA02") port map (bit_clk => bit_clk, so => CPUSKT_A_i(2));
e_CPUSKT_A_i3:		entity work.serialout generic map (message => "CA03") port map (bit_clk => bit_clk, so => CPUSKT_A_i(3));
e_CPUSKT_A_i4:		entity work.serialout generic map (message => "CA04") port map (bit_clk => bit_clk, so => CPUSKT_A_i(4));
e_CPUSKT_A_i5:		entity work.serialout generic map (message => "CA05") port map (bit_clk => bit_clk, so => CPUSKT_A_i(5));
e_CPUSKT_A_i6:		entity work.serialout generic map (message => "CA06") port map (bit_clk => bit_clk, so => CPUSKT_A_i(6));
e_CPUSKT_A_i7:		entity work.serialout generic map (message => "CA07") port map (bit_clk => bit_clk, so => CPUSKT_A_i(7));
e_CPUSKT_A_i8:		entity work.serialout generic map (message => "CA08") port map (bit_clk => bit_clk, so => CPUSKT_A_i(8));
e_CPUSKT_A_i9:		entity work.serialout generic map (message => "CA09") port map (bit_clk => bit_clk, so => CPUSKT_A_i(9));
e_CPUSKT_A_i10:	entity work.serialout generic map (message => "CA10") port map (bit_clk => bit_clk, so => CPUSKT_A_i(10));
e_CPUSKT_A_i11:	entity work.serialout generic map (message => "CA11") port map (bit_clk => bit_clk, so => CPUSKT_A_i(11));
e_CPUSKT_A_i12:	entity work.serialout generic map (message => "CA12") port map (bit_clk => bit_clk, so => CPUSKT_A_i(12));
e_CPUSKT_A_i13:	entity work.serialout generic map (message => "CA13") port map (bit_clk => bit_clk, so => CPUSKT_A_i(13));
e_CPUSKT_A_i14:	entity work.serialout generic map (message => "CA14") port map (bit_clk => bit_clk, so => CPUSKT_A_i(14));
e_CPUSKT_A_i15:	entity work.serialout generic map (message => "CA15") port map (bit_clk => bit_clk, so => CPUSKT_A_i(15));
e_CPUSKT_A_i16:	entity work.serialout generic map (message => "CA16") port map (bit_clk => bit_clk, so => CPUSKT_A_i(16));
e_CPUSKT_A_i17:	entity work.serialout generic map (message => "CA17") port map (bit_clk => bit_clk, so => CPUSKT_A_i(17));
e_CPUSKT_A_i18:	entity work.serialout generic map (message => "CA18") port map (bit_clk => bit_clk, so => CPUSKT_A_i(18));
e_CPUSKT_A_i19:	entity work.serialout generic map (message => "CA19") port map (bit_clk => bit_clk, so => CPUSKT_A_i(19));

e_CPUSKT_D_io0:	entity work.serialout generic map (message => "CD00") port map (bit_clk => bit_clk, so => CPUSKT_D_io(0));
e_CPUSKT_D_io1:	entity work.serialout generic map (message => "CD01") port map (bit_clk => bit_clk, so => CPUSKT_D_io(1));
e_CPUSKT_D_io2:	entity work.serialout generic map (message => "CD02") port map (bit_clk => bit_clk, so => CPUSKT_D_io(2));
e_CPUSKT_D_io3:	entity work.serialout generic map (message => "CD03") port map (bit_clk => bit_clk, so => CPUSKT_D_io(3));
e_CPUSKT_D_io4:	entity work.serialout generic map (message => "CD04") port map (bit_clk => bit_clk, so => CPUSKT_D_io(4));
e_CPUSKT_D_io5:	entity work.serialout generic map (message => "CD05") port map (bit_clk => bit_clk, so => CPUSKT_D_io(5));
e_CPUSKT_D_io6:	entity work.serialout generic map (message => "CD06") port map (bit_clk => bit_clk, so => CPUSKT_D_io(6));
e_CPUSKT_D_io7:	entity work.serialout generic map (message => "CD07") port map (bit_clk => bit_clk, so => CPUSKT_D_io(7));

e_CPUSKT_6EKEZnRD_i:						entity work.serialout generic map (message => "C6EK") port map (bit_clk => bit_clk, so => CPUSKT_6EKEZnRD_i);
e_CPUSKT_C6nML9BUSYKnBGZnBUSACK_i:	entity work.serialout generic map (message => "C6nM") port map (bit_clk => bit_clk, so => CPUSKT_C6nML9BUSYKnBGZnBUSACK_i);
e_CPUSKT_RnWZnWR_i:						entity work.serialout generic map (message => "RnWZ") port map (bit_clk => bit_clk, so => CPUSKT_RnWZnWR_i);
e_CPUSKT_PHI16ABRT9BSKnDS_i:			entity work.serialout generic map (message => "PHI1") port map (bit_clk => bit_clk, so => CPUSKT_PHI16ABRT9BSKnDS_i);
e_CPUSKT_PHI26VDAKFC0ZnMREQ_i:		entity work.serialout generic map (message => "PHI2") port map (bit_clk => bit_clk, so => CPUSKT_PHI26VDAKFC0ZnMREQ_i);
e_CPUSKT_SYNC6VPA9LICKFC2ZnM1_i:		entity work.serialout generic map (message => "SYNC") port map (bit_clk => bit_clk, so => CPUSKT_SYNC6VPA9LICKFC2ZnM1_i);
e_CPUSKT_VSS6VPB9BAKnAS_i:				entity work.serialout generic map (message => "VSS6") port map (bit_clk => bit_clk, so => CPUSKT_VSS6VPB9BAKnAS_i);
e_CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i:	entity work.serialout generic map (message => "nSO6") port map (bit_clk => bit_clk, so => CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i);
e_CPUSKT_6BE9TSCKnVPA_o:				entity work.serialout generic map (message => "6BE9") port map (bit_clk => bit_clk, so => CPUSKT_6BE9TSCKnVPA_o);
e_CPUSKT_9Q_o:								entity work.serialout generic map (message => "9Q_o") port map (bit_clk => bit_clk, so => CPUSKT_9Q_o);
e_CPUSKT_KnBRZnBUSREQ_o:				entity work.serialout generic map (message => "KnBR") port map (bit_clk => bit_clk, so => CPUSKT_KnBRZnBUSREQ_o);
e_CPUSKT_PHI09EKZCLK_o:					entity work.serialout generic map (message => "PHI0") port map (bit_clk => bit_clk, so => CPUSKT_PHI09EKZCLK_o);
e_CPUSKT_RDY9KnHALTZnWAIT_o:			entity work.serialout generic map (message => "RDY9") port map (bit_clk => bit_clk, so => CPUSKT_RDY9KnHALTZnWAIT_o);
e_CPUSKT_nIRQKnIPL1_o:					entity work.serialout generic map (message => "nIRQ") port map (bit_clk => bit_clk, so => CPUSKT_nIRQKnIPL1_o);
e_CPUSKT_nNMIKnIPL02_o:					entity work.serialout generic map (message => "nNMI") port map (bit_clk => bit_clk, so => CPUSKT_nNMIKnIPL02_o);
e_CPUSKT_nRES_o:							entity work.serialout generic map (message => "nRES") port map (bit_clk => bit_clk, so => CPUSKT_nRES_o);
e_CPUSKT_9nFIRQLnDTACK_o:				entity work.serialout generic map (message => "9nFI") port map (bit_clk => bit_clk, so => CPUSKT_9nFIRQLnDTACK_o);

e_CFG_io00:		entity work.serialout generic map (message => "CF00") port map (bit_clk => bit_clk, so => CFG_io(0));
e_CFG_io01:		entity work.serialout generic map (message => "CF01") port map (bit_clk => bit_clk, so => CFG_io(1));
e_CFG_io02:		entity work.serialout generic map (message => "CF02") port map (bit_clk => bit_clk, so => CFG_io(2));
e_CFG_io03:		entity work.serialout generic map (message => "CF03") port map (bit_clk => bit_clk, so => CFG_io(3));
e_CFG_io04:		entity work.serialout generic map (message => "CF04") port map (bit_clk => bit_clk, so => CFG_io(4));
e_CFG_io05:		entity work.serialout generic map (message => "CF05") port map (bit_clk => bit_clk, so => CFG_io(5));
e_CFG_io06:		entity work.serialout generic map (message => "CF06") port map (bit_clk => bit_clk, so => CFG_io(6));
e_CFG_io07:		entity work.serialout generic map (message => "CF07") port map (bit_clk => bit_clk, so => CFG_io(7));
e_CFG_io08:		entity work.serialout generic map (message => "CF08") port map (bit_clk => bit_clk, so => CFG_io(8));
e_CFG_io09:		entity work.serialout generic map (message => "CF09") port map (bit_clk => bit_clk, so => CFG_io(9));
e_CFG_io10:		entity work.serialout generic map (message => "CF10") port map (bit_clk => bit_clk, so => CFG_io(10));
e_CFG_io11:		entity work.serialout generic map (message => "CF11") port map (bit_clk => bit_clk, so => CFG_io(11));
e_CFG_io12:		entity work.serialout generic map (message => "CF12") port map (bit_clk => bit_clk, so => CFG_io(12));
e_CFG_io13:		entity work.serialout generic map (message => "CF13") port map (bit_clk => bit_clk, so => CFG_io(13));
e_CFG_io14:		entity work.serialout generic map (message => "CF14") port map (bit_clk => bit_clk, so => CFG_io(14));
e_CFG_io15:		entity work.serialout generic map (message => "CF15") port map (bit_clk => bit_clk, so => CFG_io(15));

e_I2C_SCL_io:	entity work.serialout generic map (message => "2SCL") port map (bit_clk => bit_clk, so => I2C_SCL_io);
e_I2C_SDA_io:	entity work.serialout generic map (message => "2SDA") port map (bit_clk => bit_clk, so => I2C_SDA_io);

end rtl;

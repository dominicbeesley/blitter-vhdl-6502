
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

----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	23/3/2018
-- Design Name: 
-- Module Name:    	simulation file for the bus behaviour of a "realish" 65816
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		uses P65C816 core
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
-- This is a very rough approximation to allow setting up of address/bank timings etc
-- default timings are for chip running at 3.3V (8MHz)
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY real_65816_tb IS
	GENERIC (
			dly_bank	 : time := 40 ns;	
			hld_bank  : time := 10 ns;		
			dly_addr  : time := 40 ns;
			dly_dwrite: time := 30 ns;	-- dwrite must be > dhold
			dly_dhold : time := 10 ns;
			dly_dsetup: time := 10 ns;
			dly_be	 : time := 20 ns;
			hld_EMX	 : time := 5 ns;
			dly_EMX	 : time := 45 ns
		);
	PORT (
		A					: OUT 	STD_LOGIC_VECTOR(15 downto 0);
		D					: INOUT 	STD_LOGIC_VECTOR(7 downto 0);
		nRESET			: IN		STD_LOGIC;
		RDY				: INOUT	STD_LOGIC;
		nIRQ				: IN		STD_LOGIC;
		nNMI				: IN		STD_LOGIC;
		BE					: IN		STD_LOGIC;	-- NOTE: this is not implemented!
		RnW				: OUT		STD_LOGIC;
		VPA				: OUT		STD_LOGIC;
		VPB				: OUT		STD_LOGIC;
		VDA				: OUT		STD_LOGIC;
		MX					: OUT		STD_LOGIC;	-- unlikely to work t65 incomplete
		E					: OUT		STD_LOGIC;	-- unlikely to work t65 incomplete
		MLB				: OUT		STD_LOGIC; 

		PHI2				: IN		STD_LOGIC
		);
END real_65816_tb;

ARCHITECTURE Behavioral OF real_65816_tb IS
	SIGNAL	i_phi2_D_dly	: STD_LOGIC;
	SIGNAL	i_phi2_D_hold	: STD_LOGIC;
	SIGNAL 	i_bankact		: STD_LOGIC;
	SIGNAL	i_E_act			: STD_LOGIC;
	SIGNAL	i_M_act			: STD_LOGIC;
	SIGNAL	i_X_act			: STD_LOGIC;
	SIGNAL	i_EF				: STD_LOGIC;
	SIGNAL	i_MF				: STD_LOGIC;
	SIGNAL	i_XF				: STD_LOGIC;
	SIGNAL	i_EF_dly			: STD_LOGIC;
	SIGNAL	i_MF_dly			: STD_LOGIC;
	SIGNAL	i_XF_dly			: STD_LOGIC;

	SIGNAL	i_MLB				: STD_LOGIC;
	SIGNAL	i_VPA				: STD_LOGIC;
	SIGNAL	i_VDA				: STD_LOGIC;
	SIGNAL	i_VPB				: STD_LOGIC;

	SIGNAL	i_cpu_clk		: STD_LOGIC;

	SIGNAL  	i_RnW				: STD_LOGIC;
	SIGNAL	i_cpu_A			: STD_LOGIC_VECTOR(23 downto 0);
	SIGNAL	i_cpu_A_dly		: STD_LOGIC_VECTOR(23 downto 0);

	SIGNAL	i_cpu_D_out		: STD_LOGIC_VECTOR(7 downto 0);
	SIGNAL	i_cpu_D_out_dly_hold : STD_LOGIC_VECTOR(7 downto 0);
	SIGNAL	i_cpu_D_in		: STD_LOGIC_VECTOR(7 downto 0);
	SIGNAL	i_RnW_hold		: STD_LOGIC;

	SIGNAL	i_PHI2_dly_EMX	: STD_LOGIC;
	SIGNAL	i_PHI2_hld_EMX	: STD_LOGIC;

	SIGNAL	i_PHI2_dly_bank: STD_LOGIC;
	SIGNAL	i_PHI2_hld_bank: STD_LOGIC;

	SIGNAL   i_RDY_o			: STD_LOGIC;

	SIGNAL	i_BE_dly			: STD_LOGIC;

	SIGNAL 	i_wract			: STD_LOGIC;

BEGIN

	i_cpu_clk <= not(PHI2);

	i_RnW_hold <= i_RnW AFTER dly_addr;
	RnW <= 	i_RnW_hold when i_BE_dly = '1' else
				'Z';
	i_cpu_A_dly <= transport i_cpu_A(23 downto 0) AFTER dly_addr;
	i_BE_dly <= transport BE after dly_be;
	A <= 
			(others => 'Z') when i_BE_dly = '0' else
			i_cpu_A_dly(15 downto 0);
	
	MLB <= i_MLB AFTER dly_addr;
	VPA <= i_VPA AFTER dly_addr;
	VDA <= i_VDA AFTER dly_addr;
	VPB <= i_VPB AFTER dly_addr;

	p_bank:process
	begin
		wait until falling_edge(PHI2) and RDY = '1';
		wait for dly_bank;
		i_bankact <= '1';
		wait until rising_edge(PHI2);
		wait for hld_bank;
		i_bankact <= '0';
	end process;

	p_wract:process
	begin
		wait until rising_edge(PHI2);
		wait for dly_dwrite;
		i_wract <= '1';
		wait until falling_edge(PHI2) and RDY = '1';
		wait for dly_dhold;
		i_wract <= '0';
	end process;


	i_cpu_D_out_dly_hold <= i_cpu_D_out AFTER dly_dhold;

	D <= 	(others => 'Z') when i_BE_dly = '0' else
			i_cpu_A(23 downto 16) when i_bankact = '1' else
			i_cpu_D_out_dly_hold when i_wract = '1' and i_RnW_hold = '0' else
		 	(others => 'Z');

	i_cpu_D_in <= D after dly_dsetup;

	i_phi2_D_dly <= PHI2 after dly_dwrite;
	i_phi2_D_hold <= PHI2 after dly_dhold; 

	i_PHI2_hld_EMX <= PHI2 after hld_EMX;
	i_PHI2_dly_EMX <= PHI2 after dly_EMX;

	i_E_act <= 	'1' when i_PHI2_dly_EMX = '1' or PHI2 = '0' or i_PHI2_hld_EMX = '0' else
					'0';
	i_M_act <=  '1' when i_PHI2_dly_EMX = '1' and i_PHI2_hld_EMX = '1' else 
					'0';
	i_X_act <=  '1' when i_PHI2_dly_EMX = '0' and i_PHI2_hld_EMX = '0' else 
					'0';

	i_EF_dly <= i_EF AFTER hld_EMX;
	i_MF_dly <= i_MF AFTER hld_EMX;
	i_XF_dly <= i_XF AFTER hld_EMX;

	E 	<= i_EF_dly when i_E_act = '1' else 
			'X';
	MX <= i_MF_dly when i_M_act = '1' else
			i_XF_dly when i_X_act = '1' else 
			'X';



	--TODO E/M/X flags
	e_t65816cput: entity work.P65C816
   port map ( 
      CLK		=> i_cpu_clk,
		RST_N		=> nRESET,
		CE			=> '1',
		  
		RDY_IN	=> RDY,
      NMI_N		=> nNMI,
		IRQ_N		=> nIRQ,
		ABORT_N	=> '1',
      D_IN		=> i_cpu_D_in,
      D_OUT    => i_cpu_D_out,
      A_OUT    => i_cpu_A,
      WE  		=> i_RnW,
		RDY_OUT 	=> i_RDY_o,
		VPA 		=> i_VPA,
		VDA 		=> i_VDA,
		MLB 		=> i_MLB,
		VPB 		=> i_VPB,

		EF_o		=> i_EF,
		MF_o		=> i_MF,
		XF_o		=> i_XF
    );

	RDY <= 	'0' when i_RDY_o = '0' else 
				'H';


END Behavioral;

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
-- Module Name:    	simulation file for the bus behaviour of a "real" 6809
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		
--
-- Dependencies: 	Uses the John Kent 6809 core
--
-- Revision: 
-- Revision 0.01 - File Created
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY real_6809_tb IS
	GENERIC (
			dly_addr  : time := 70 ns; -- faster than spec!
			dly_dout  : time := 70 ns; -- data delay from Q rise
			dly_dhold : time := 20 ns
		);
	PORT (
		A					: OUT 		STD_LOGIC_VECTOR(15 downto 0);
		D					: INOUT 	STD_LOGIC_VECTOR(7 downto 0);
		nRESET				: IN		STD_LOGIC;
		TSC					: IN		STD_LOGIC;
		nHALT				: IN		STD_LOGIC;
		nIRQ				: IN		STD_LOGIC;
		nNMI				: IN		STD_LOGIC;
		nFIRQ				: IN		STD_LOGIC;
		AVMA				: OUT		STD_LOGIC;
		RnW					: OUT		STD_LOGIC;
		LIC					: OUT		STD_LOGIC;

		CLK_E				: IN		STD_LOGIC;
		CLK_Q				: IN		STD_LOGIC;
		BA					: OUT		STD_LOGIC;
		BS					: OUT		STD_LOGIC;
		BUSY				: OUT		STD_LOGIC
		);
END real_6809_tb;

ARCHITECTURE Behavioral OF real_6809_tb IS

	SIGNAL	i_cpu_clk		: STD_LOGIC;

	SIGNAL  i_RnW			: STD_LOGIC;
	SIGNAL	i_cpu_A			: STD_LOGIC_VECTOR(15 downto 0);
	SIGNAL  i_LIC			: STD_LOGIC;
	SIGNAL	i_BA			: STD_LOGIC;
	SIGNAL	i_BS			: STD_LOGIC;

	SIGNAL	i_cpu_D_out		: STD_LOGIC_VECTOR(7 downto 0);
	SIGNAL	i_cpu_D_in		: STD_LOGIC_VECTOR(7 downto 0);
	SIGNAL	i_RnW_hold		: STD_LOGIC;

	SIGNAL	i_irq			: STD_LOGIC;
	SIGNAL	i_firq			: STD_LOGIC;
	SIGNAL	i_nmi			: STD_LOGIC;
	SIGNAL	i_vma			: STD_LOGIC;
	SIGNAL	i_halt			: STD_LOGIC;

	SIGNAL  i_data_write	: STD_LOGIC;
	SIGNAL	i_RESET			: STD_LOGIC;
BEGIN

	p_data_Write:process
	BEGIN
		wait until CLK_Q = '1';
		i_data_write <= '1';
		wait until CLK_E = '0';
		wait for dly_dhold;
		i_data_write <= '0';

	END PROCESS;

	i_irq <= not(nIRQ);
	i_firq <= not(nFIRQ);
	i_nmi <= not(nNMI);
	i_halt <= not(nHALT);
	i_reset <= not(nRESET);

	i_cpu_clk <= not(CLK_E);

	i_RnW_hold <= i_RnW AFTER dly_addr;
	RnW <= i_RnW_hold;
	A <= i_cpu_A AFTER dly_addr;
	LIC <= i_LIC AFTER dly_addr;
	BA <= i_BA AFTER dly_addr;
	BS <= i_BS AFTER dly_addr;

	AVMA <= i_VMA;
	BUSY <= 'X';	-- dunno what to do with this so make it X for now?

	D <= i_cpu_D_out AFTER dly_dhold when i_data_write = '1' and i_RnW_hold = '0' else
		 (others => 'Z');

	i_cpu_D_in <= D;

	e_cpu: entity work.cpu09 port map (
		clk			=> i_cpu_clk,
		rst			=> i_RESET,
		vma			=> i_vma,
		lic_out		=> i_lic,
		ifetch		=> open,
		opfetch		=> open,
		ba			=> i_ba,
		bs			=> i_bs,
		addr		=> i_cpu_A,
		rw			=> i_RnW,
		data_out	=> i_cpu_D_out,
		data_in		=> i_cpu_D_in,
		irq			=> i_irq,
		firq		=> i_firq,
		nmi			=> i_nmi,
		halt		=> i_halt,
		hold		=> '0'
	);

END Behavioral;

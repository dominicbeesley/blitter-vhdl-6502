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
-- Create Date:    	28/12/2018
-- Design Name: 
-- Module Name:    	simulation file for the bus behaviour of a "real" 6800
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		
--
-- Dependencies: 	Uses the John Kent 6800 core
--
-- Revision: 
-- Revision 0.01 - File Created
----------------------------------------------------------------------------------


-- CAVEATS:
-- TSC ignored!
-- HALT not tested 


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY real_6800_tb IS
	GENERIC (
			dly_addr  : time := 130 ns; -- faster than spec!
			dly_dout  : time := 70 ns; -- data delay from Q rise
			dly_dhold : time := 25 ns;
			dly_tddw  : time := 160 ns
		);
	PORT (
		PHI1				: IN		STD_LOGIC;
		PHI2				: IN		STD_LOGIC;
		A					: OUT 		STD_LOGIC_VECTOR(15 downto 0);
		D					: INOUT 	STD_LOGIC_VECTOR(7 downto 0);
		nRESET			: IN		STD_LOGIC;
		TSC				: IN		STD_LOGIC;
		DBE				: IN		STD_LOGIC;
		nHALT				: IN		STD_LOGIC;
		nIRQ				: IN		STD_LOGIC;
		nNMI				: IN		STD_LOGIC;

		VMA				: OUT		STD_LOGIC;
		RnW				: OUT		STD_LOGIC;
		BA					: OUT		STD_LOGIC

		);
END real_6800_tb;

ARCHITECTURE Behavioral OF real_6800_tb IS

	SIGNAL	i_cpu_clk		: STD_LOGIC;

	SIGNAL  	i_RnW				: STD_LOGIC;
	SIGNAL	i_cpu_A			: STD_LOGIC_VECTOR(15 downto 0);

	SIGNAL	i_cpu_D_out		: STD_LOGIC_VECTOR(7 downto 0);
	SIGNAL	i_cpu_D_in		: STD_LOGIC_VECTOR(7 downto 0);
	SIGNAL	i_RnW_hold		: STD_LOGIC;

	SIGNAL	i_irq				: STD_LOGIC;
	SIGNAL	i_nmi				: STD_LOGIC;
	SIGNAL	i_vma				: STD_LOGIC;
	SIGNAL	i_halt			: STD_LOGIC;

	SIGNAL  	i_data_write	: STD_LOGIC;
	SIGNAL	i_RESET			: STD_LOGIC;	

BEGIN

	i_data_write <= (DBE and not i_RnW_hold) after dly_tddw-dly_dhold;


	i_irq <= not(nIRQ);

	i_nmi <= not(nNMI);
	i_halt <= not(nHALT);

	i_reset <= not(nRESET);

	i_cpu_clk <= PHI2;							-- NOTE: cpu68 is falling edge clock

	i_RnW_hold <= i_RnW AFTER dly_addr;
	RnW <= i_RnW_hold;
	A <= i_cpu_A AFTER dly_addr;

	BA <= '0';									-- TODO!

	VMA <= i_VMA;

	D <= i_cpu_D_out AFTER dly_dhold when i_data_write = '1' and i_RnW_hold = '0' else
		 (others => 'Z');

	i_cpu_D_in <= D;

	e_cpu: entity work.cpu68 port map (
		clk			=> i_cpu_clk,
		rst			=> i_RESET,
		rw				=> i_RnW,
		vma			=> i_vma,
		address		=> i_cpu_A,
		data_out		=> i_cpu_D_out,
		data_in		=> i_cpu_D_in,
		hold			=> '0',

		halt			=> i_halt,
		irq			=> i_irq,
		nmi			=> i_nmi
	);

END Behavioral;

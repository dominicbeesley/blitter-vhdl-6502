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
-- Module Name:    	simulation file for the bus behaviour of a "real" 6502
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		uses T65 core
--
-- Dependencies: 	T65 core
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
-- simulate phi0, phi1, phi2 timings and 6502A pinout at 2MHz
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY real_6502_tb IS
	GENERIC (
			dly_phi0a : time := 20 ns;
			dly_phi0b : time := 20 ns;
			dly_phi0c : time := 20 ns;
			dly_phi0d : time := 20 ns;
			dly_addr  : time := 70 ns; -- faster than spec!
			dly_dwrite: time := 100 ns;	-- dwrite must be > dhold
			dly_dhold : time := 30 ns
		);
	PORT (
		A					: OUT 		STD_LOGIC_VECTOR(15 downto 0);
		D					: INOUT 	STD_LOGIC_VECTOR(7 downto 0);
		nRESET			: IN		STD_LOGIC;
		RDY				: IN		STD_LOGIC;
		nIRQ				: IN		STD_LOGIC;
		nNMI				: IN		STD_LOGIC;
		nSO				: IN		STD_LOGIC;
		RnW				: OUT		STD_LOGIC;
		SYNC				: OUT		STD_LOGIC;

		PHI0				: IN		STD_LOGIC;
		PHI1				: OUT		STD_LOGIC;
		PHI2				: OUT		STD_LOGIC
		);
END real_6502_tb;

ARCHITECTURE Behavioral OF real_6502_tb IS
	SIGNAL	i_gen_phi0_a	: STD_LOGIC;
	SIGNAL	i_gen_phi0_b	: STD_LOGIC;
	SIGNAL	i_gen_phi0_c	: STD_LOGIC;
	SIGNAL	i_gen_phi0_d	: STD_LOGIC;

	SIGNAL	i_gen_phi1		: STD_LOGIC;
	SIGNAL  	i_gen_phi2		: STD_LOGIC;

	SIGNAL	i_phi2_D_dly	: STD_LOGIC;
	SIGNAL	i_phi2_D_hold	: STD_LOGIC;

	SIGNAL	i_cpu_clk		: STD_LOGIC;

	SIGNAL  	i_RnW			: STD_LOGIC;
	SIGNAL	i_cpu_A			: STD_LOGIC_VECTOR(23 downto 0);
	SIGNAL  	i_SYNC			: STD_LOGIC;

	SIGNAL	i_cpu_D_out		: STD_LOGIC_VECTOR(7 downto 0);
	SIGNAL	i_cpu_D_in		: STD_LOGIC_VECTOR(7 downto 0);
	SIGNAL	i_RnW_hold		: STD_LOGIC;
BEGIN

	i_gen_phi0_a <= PHI0 AFTER dly_phi0a;
	i_gen_phi0_b <= i_gen_phi0_a AFTER dly_phi0b;
	i_gen_phi0_c <= i_gen_phi0_b AFTER dly_phi0c;
	i_gen_phi0_d <= i_gen_phi0_c AFTER dly_phi0d;

	i_gen_phi1 		<= not (i_gen_phi0_b or i_gen_phi0_d);
	i_gen_phi2		<= i_gen_phi0_b and i_gen_phi0_d;

	PHI1 <= i_gen_phi1;
	PHI2 <= i_gen_phi2;

	i_cpu_clk <= not(i_gen_phi2);

	i_RnW_hold <= i_RnW AFTER dly_addr;
	RnW <= i_RnW_hold;
	A <= i_cpu_A(15 downto 0) AFTER dly_addr;
	SYNC <= i_SYNC AFTER dly_addr;

	D <= i_cpu_D_out AFTER dly_dhold when (i_phi2_D_hold = '1' or i_phi2_D_dly = '1') and i_RnW_hold = '0' else
		 (others => 'Z');

	i_cpu_D_in <= D;

	i_phi2_D_dly <= i_gen_phi2 after dly_dwrite;
	i_phi2_D_hold <= i_gen_phi2 after dly_dhold; 

	e_t65cput: ENTITY work.T65 PORT MAP (
	    Mode    => "00",								--6502
	    Res_n   => nRESET,
	    Enable  => '1',
	    Clk     => i_cpu_clk,
	    Rdy     => RDY,
	    Abort_n => '1',
	    IRQ_n   => nIRQ,
	    NMI_n   => nNMI,
	    SO_n    => nSO,
	    R_W_n   => i_RnW,
	    Sync    => i_SYNC,
	    EF      => open,
	    MF      => open,
	    XF      => open,
	    ML_n    => open,
	    VP_n    => open,
	    VDA     => open,
	    VPA     => open,
	    A       => i_cpu_A,
	    DI      => i_cpu_D_in,
	    DO      => i_cpu_D_out
	  );

END Behavioral;

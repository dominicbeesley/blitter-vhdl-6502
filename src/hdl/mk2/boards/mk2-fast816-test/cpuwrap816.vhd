-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2023 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:    	7/11/2023
-- Design Name: 
-- Module Name:    	dip 40 blitter - mk2 product board
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		PoC blitter and 6502/6809/Z80/68008 cpu board with 2M RAM, 256k ROM - fast 65816 only implementation
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
use work.common.all;

entity cpuwrap816 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural := 128;								-- fast clock speed in mhz				

		-- defaults for 8MHz conservative
		N_CPU_PHI1							: positive := 8;
		N_CPU_PHI2							: positive := 8;

		P_CPU_PHI1_ADDR					: integer  := 5;			-- cycle during phi1 to sample BANK/ADDR/RnW
		-- these count back from end of phi2 0 will be last cycle of phi2
		P_CPU_PHI2_STRETCH				: integer  := -3			-- cycle during phi2 when data must be ready

	);
	port(
		clk_i										: in		std_logic;				-- fast clock
		rst_i										: in		std_logic;

		CPUSKT_A_i								: in		std_logic_vector(19 downto 0);
		CPUSKT_D_io								: inout  std_logic_vector(7 downto 0);

		CPUSKT_E_i								: in		std_logic;		
		CPUSKT_nML_i							: in		std_logic;
		CPUSKT_RnW_i							: in		std_logic;
		CPUSKT_nABRT_i							: in		std_logic;		-- 6ABRT is actually an output but pulled up on the board TODO: make I/O ?
		CPUSKT_VDA_i							: in		std_logic;
		CPUSKT_VPA_i							: in		std_logic;
		CPUSKT_nVP_i							: in		std_logic;
		CPUSKT_MX_i								: in		std_logic;		-- nSO is actually an output but pulled up on the board


		CPUSKT_BE_o								: out		std_logic;
		CPUSKT_PHI2_o							: out		std_logic;
		CPUSKT_RDY_o							: out		std_logic;
		CPUSKT_nIRQ_o							: out		std_logic;
		CPUSKT_nNMI_o							: out		std_logic;
		CPUSKT_nRES_o							: out		std_logic;

		-- SYS signals in

		SYS_nIRQ_i								: in		std_logic;
		SYS_nNMI_i								: in		std_logic;

		-- data access signals

		W_D_i					   				: in		std_logic_vector(7 downto 0);
		W_D_o					   				: in		std_logic_vector(7 downto 0);
		W_A_o	   								: out		std_logic_vector(23 downto 0);
		W_RnW_o			   					: out		std_logic;

		W_req_o			   					: out		std_logic;
		W_ack_i									: in		std_logic
	);
end cpuwrap816;

architecture rtl of cpuwrap816 is

	signal r_cpu_phi_ring	: std_logic_vector(N_CPU_PHI1+N_CPU_PHI2-1 downto 0) := (0=> '1', others => '0');

	signal r_CPU_PHI2			: std_logic := '0';

	signal r_bank				: std_logic_vector(7 downto 0);

begin

	p_phi_ring:process(rst_i, clk_i)
	begin
		if rising_edge(clk_i) then
			r_cpu_phi_ring <= r_cpu_phi_ring(r_cpu_phi_ring'high-1 downto 0) & r_cpu_phi_ring(r_cpu_phi_ring'high);
		end if;
	end process;

	p_phi2:process(clk_i)
	begin
		if rising_edge(clk_i) then
			if r_cpu_phi_ring(N_CPU_PHI1-1) = '1' then
				r_CPU_PHI2 <= '1';
				r_bank <= CPUSKT_D_io;
			elsif r_cpu_phi_ring(N_CPU_PHI1+N_CPU_PHI2-1) = '1' then
				r_CPU_PHI2 <= '0';
			end if;
		end if;
	end process;

	
	CPUSKT_PHI2_o  <= r_CPU_PHI2;
	CPUSKT_nRES_o 	<= not rst_i;
	CPUSKT_BE_o 	<= '1';
	CPUSKT_RDY_o   <= '1';
	CPUSKT_nIRQ_o  <= SYS_nIRQ_i;
	CPUSKT_nNMI_o  <= SYS_nNMI_i;

	CPUSKT_D_io <= (others => 'Z');

end rtl;

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

---- 8MHz
--		-- faster A setup
--		N_CPU_PHI1							: positive := 8;
--		N_CPU_PHI2							: positive := 8;
--
--		P_CPU_PHI1_ADDR					: integer  := 5;			-- cycle during phi1 to sample BANK/ADDR/RnW
--		-- these count back from end of phi2 0 will be last cycle of phi2
--		P_CPU_PHI2_STRETCH				: integer  := -2;			-- cycle during phi2 when data must be ready
--		P_CPU_PHI2_DATA_WR				: integer  := 4;
--		P_CPU_PHI1_DATA_RD_HLD			: integer  := 0;
--		P_CPU_PHI2_DATA_RD_SETUP		: integer  := -3

---- 8MHz
--		-- defaults for 8MHz conservative
--		N_CPU_PHI1							: positive := 8;
--		N_CPU_PHI2							: positive := 8;
--
--		P_CPU_PHI1_ADDR					: integer  := 5;			-- cycle during phi1 to sample BANK/ADDR/RnW
--		-- these count back from end of phi2 0 will be last cycle of phi2
--		P_CPU_PHI2_STRETCH				: integer  := -2;			-- cycle during phi2 when data must be ready
--		P_CPU_PHI2_DATA_WR				: integer  := 4;
--		P_CPU_PHI1_DATA_RD_HLD			: integer  := 0;
--		P_CPU_PHI2_DATA_RD_SETUP		: integer  := -3
--
-- 16MHz
		-- defaults for 8MHz conservative
		N_CPU_PHI1							: positive := 4;
		N_CPU_PHI2							: positive := 4;

		P_CPU_PHI1_ADDR					: integer  := 3;			-- cycle during phi1 to sample BANK/ADDR/RnW
		-- these count back from end of phi2 0 will be last cycle of phi2
		P_CPU_PHI2_STRETCH				: integer  := -2;			-- cycle during phi2 when data must be ready
		P_CPU_PHI2_DATA_WR				: integer  := 2;
		P_CPU_PHI1_DATA_RD_HLD			: integer  := 0;
		P_CPU_PHI2_DATA_RD_SETUP		: integer  := -2

	);
	port(
		clk_i										: in		std_logic;				-- fast clock
		rst_i										: in		std_logic;

		CPUSKT_A_i								: in		std_logic_vector(15 downto 0);
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
		W_D_o					   				: out		std_logic_vector(7 downto 0);
		W_A_o	   								: out		std_logic_vector(23 downto 0);
		W_RnW_o			   					: out		std_logic;

		W_req_o			   					: out		std_logic;
		W_D_wr_stb_o							: out		std_logic;
		W_ack_i									: in		std_logic
	);
end cpuwrap816;

architecture rtl of cpuwrap816 is

	signal r_cpu_phi_ring	: std_logic_vector(N_CPU_PHI1+N_CPU_PHI2-1 downto 0) := (0=> '1', others => '0');

	signal r_CPU_PHI2			: std_logic := '0';

	signal r_bank				: std_logic_vector(7 downto 0);
	signal r_addr				: std_logic_vector(15 downto 0);
	signal r_rnw				: std_logic;
	signal r_req				: std_logic;
	signal r_d_wr_stb			: std_logic;
	signal r_d_rd_en			: std_logic;

	signal i_cken_PHI2_start: std_logic;
	signal i_cken_PHI2_end  : std_logic;
	signal i_cken_ADDR_read : std_logic;
	signal i_cken_STRETCH   : std_logic;
	signal i_cken_DATA_WR	: std_logic;
	signal i_cken_DATA_RD_s	: std_logic;
	signal i_cken_DATA_RD_e	: std_logic;

	function CKPx(offset:integer; max:natural) return natural is
	begin
		if offset >= 0 then
			if (offset >= max) then
				return max-1;
			else
				return offset;
			end if;
		else 
			if max+offset < 0 then
				return 0;
			else
				return max+offset;
			end if;
		end if;
	end function;

	function CKP1(offset:integer) return natural is
	begin
		return CKPx(offset, N_CPU_PHI1);
	end function;

	function CKP2(offset:integer) return natural is
	begin
		return N_CPU_PHI1 + CKPx(offset, N_CPU_PHI2);
	end function;

begin

	i_cken_PHI2_start		<= r_cpu_phi_ring(CKP1(-1));
	i_cken_PHI2_end		<= r_cpu_phi_ring(CKP2(-1));
	i_cken_ADDR_read		<= r_cpu_phi_ring(CKP1(P_CPU_PHI1_ADDR));
	i_cken_STRETCH			<= r_cpu_phi_ring(CKP2(P_CPU_PHI2_STRETCH));
	i_cken_DATA_WR			<= r_cpu_phi_ring(CKP2(P_CPU_PHI2_DATA_WR));
	i_cken_DATA_RD_s		<= r_cpu_phi_ring(CKP2(P_CPU_PHI2_DATA_RD_SETUP));
	i_cken_DATA_RD_e		<= i_cken_PHI2_end;

	p_phi2:process(clk_i)
	begin
		if rising_edge(clk_i) then
			if i_cken_PHI2_start = '1' then
				r_CPU_PHI2 <= '1';
			elsif i_cken_PHI2_end = '1' then
				r_CPU_PHI2 <= '0';
			end if;
		end if;
	end process;

	p_cyc_state:process(rst_i, clk_i)
	variable v_stretch:boolean;
	begin

		if rst_i = '1' then
			r_bank		<= (others => '0');
			r_addr		<= (others => '0');
			r_rnw			<= '1';
			r_req			<= '0';
			r_d_wr_stb	<= '0';
		elsif rising_edge(clk_i) then

			v_stretch := false;
			if r_req = '1' and  i_cken_STRETCH = '1' then
				-- cycle stretch gets stuck on this cycle
				if W_ack_i /= '1' then
					v_stretch := true;
				else
					r_req <= '0';
				end if;
			end if;

			if not v_stretch then
				r_cpu_phi_ring <= r_cpu_phi_ring(r_cpu_phi_ring'high-1 downto 0) & r_cpu_phi_ring(r_cpu_phi_ring'high);
			end if;


			if i_cken_ADDR_read = '1' then
				-- here we start a new cycle, if required
				r_bank 		<= CPUSKT_D_io;
				r_addr 		<= CPUSKT_A_i;
				r_rnw  		<= CPUSKT_RnW_i;
				r_req  		<= CPUSKT_VPA_i or CPUSKT_VDA_i;
				r_d_wr_stb 	<= '0';
			end if;

			if i_cken_DATA_WR = '1' then
				r_d_wr_stb 	<= '1';
			end if;
		end if;

	end process;

	p_rd_en:process(rst_i, clk_i)
	begin
		if rst_i = '1' then
			r_d_rd_en <= '0';
		elsif rising_edge(clk_i) then
			if i_cken_DATA_RD_s = '1' then
				r_d_rd_en <= r_rnw;
			end if;

			if i_cken_DATA_RD_e = '1' then
				r_d_rd_en <= '0';
			end if;
		end if;
	end process;

	W_A_o 			<= r_bank & r_addr;
	W_D_o 			<= CPUSKT_D_io;
	W_req_o 			<= r_req;
	W_RnW_o  		<= r_rnw;
	W_D_wr_stb_o 	<= r_d_wr_stb;


	CPUSKT_PHI2_o  <= r_CPU_PHI2;
	CPUSKT_nRES_o 	<= not rst_i;
	CPUSKT_BE_o 	<= '1';
	CPUSKT_RDY_o   <= '1';
	CPUSKT_nIRQ_o  <= SYS_nIRQ_i;
	CPUSKT_nNMI_o  <= SYS_nNMI_i;

	CPUSKT_D_io 	<= W_D_i when r_d_rd_en = '1' else
							(others => 'Z');

end rtl;

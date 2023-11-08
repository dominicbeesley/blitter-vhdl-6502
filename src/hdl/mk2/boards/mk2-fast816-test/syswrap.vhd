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
-- Module Name:    	syswap
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		BBC motherboard wrapper
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

entity syswrap is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural := 128;								-- fast clock speed in mhz				

		N_PHI_DLY							: natural := 2;								-- delay between phi2 and phi0 in CLOCKSPEED clocks
		N_PHI1_START						: natural := 10								-- number of cycles into phi1 that a cycle will be requested i.e. A/RnW change here during phi1

	);
	port(
		clk_i										: in		std_logic;				-- fast clock
		rst_i										: in		std_logic;

		-- motherboard signals

		SYS_A_o								: out		std_logic_vector(15 downto 0);
		SYS_D_io								: inout	std_logic_vector(7 downto 0);
		SYS_RDY_i							: in		std_logic; -- Master only?
		SYS_SYNC_o							: out		std_logic;
		SYS_PHI0_i							: in		std_logic;
		SYS_PHI1_o							: out		std_logic;
		SYS_PHI2_o							: out		std_logic;
		SYS_RnW_o							: out		std_logic;

		-- data access signals

		W_D_i					   			: in		std_logic_vector(7 downto 0);
		W_D_o					   			: in		std_logic_vector(7 downto 0);
		W_A_i	   							: in		std_logic_vector(15 downto 0);
		W_RnW_i			   				: out		std_logic;

		W_req_i			   				: in		std_logic;
		W_ack_o								: out		std_logic
	);
end syswrap;

architecture rtl of syswrap is

	constant phi0_ring_len : natural := (N_PHI_DLY + N_PHI1_START);

	signal r_phi0_dly : std_logic_vector(phi0_ring_len-1 downto 0) := (others => '0');

	signal i_cken_start 	: std_logic;
	signal i_cken_phi2	: std_logic;

begin

	p_phi0_dly:process(clk_i)
	begin
		if rising_edge(clk_i) then
			r_phi0_dly <= r_phi0_dly(r_phi0_dly'high-1 downto 0) & SYS_PHI0_i;
		end if;
	end process;
	
	SYS_PHI1_o <= not r_phi0_dly(N_PHI_DLY) and not SYS_PHI0_i;
	SYS_PHI2_o <= r_phi0_dly(N_PHI_DLY) and SYS_PHI0_i;

	i_cken_start <= r_phi0_dly(N_PHI_DLY+N_PHI1_START-1) and not r_phi0_dly(N_PHI_DLY+N_PHI1_START-2);
	i_cken_phi2 <= r_phi0_dly(N_PHI_DLY-1) and not r_phi0_dly(N_PHI_DLY-2);

	

end rtl;

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
-- Create Date:    	9/11/2023
-- Design Name: 
-- Module Name:    	memwrap 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A wrapper for the blitter/cpu board's SRAM
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

entity memwrap is
	generic (
		SIM									: boolean := false;		-- skip some stuff, i.e. slow sdram start up
		G_FLASH_IS_45						: boolean := false;		-- 45ns Flash chip fitted (else 55ns)
		G_SLOW_IS_45						: boolean := false		-- 45ns BB Ram chip fitted (else 55ns)
	);
	port(
		clk_i										: in		std_logic;				-- fast clock
		rst_i										: in		std_logic;

		-- 2M RAM/256K ROM bus
		MEM_A_o								: out		std_logic_vector(20 downto 0);
		MEM_D_io								: inout	std_logic_vector(7 downto 0);
		MEM_nOE_o							: out		std_logic;
		MEM_ROM_nWE_o						: out		std_logic;
		MEM_RAM_nWE_o						: out		std_logic;
		MEM_ROM_nCE_o						: out		std_logic;
		MEM_RAM0_nCE_o						: out		std_logic;

		-- bus signals

		W_D_i					   			: in		std_logic_vector(7 downto 0);
		W_D_o					   			: out		std_logic_vector(7 downto 0);
		W_A_i	   							: in		std_logic_vector(23 downto 0);
		W_RnW_i			   				: in		std_logic;

		W_req_i			   				: in		std_logic;
		W_CPU_D_wr_stb_i					: in		std_logic;
		W_ack_o								: out		std_logic

	);
end memwrap;

architecture rtl of memwrap is

	type 	 	state_mem_t is (idle, wait_wr_stb, wait_rd, wait_wr, act, wait_cyc);

	signal	state			: state_mem_t;

	signal	r_ack			:  std_logic;
	signal   r_D			:  std_logic_vector(7 downto 0);
	signal	r_cyc			:  std_logic; 							-- current cycle is still active on master

begin



	W_D_o 				<= r_D;
	W_ack_o		 		<= r_ack;

	p_state:process(rst_i, clk_i)
	variable v_rdy_ctdn : unsigned(2 downto 0);
	variable v_goidle	  : boolean;
	begin

		if rst_i = '1' then
			state <= idle;
			MEM_A_o <= (others => '0');
			MEM_D_io <= (others => 'Z');
			MEM_nOE_o <= '1';
			MEM_RAM0_nCE_o <= '1';
			MEM_ROM_nCE_o <= '1';
			MEM_RAM_nWE_o <= '1';
			MEM_ROM_nWE_o <= '1';
			r_ack <= '0';
			r_d <= (others => '0');
			r_cyc <= '0';
		else
			if rising_edge(clk_i) then
				v_goidle := false;
				case state is
					when idle =>
						MEM_A_o <= (others => '0');
						MEM_D_io <= (others => 'Z');
						MEM_nOE_o <= '1';
						MEM_RAM_nWE_o <= '1';
						MEM_ROM_nWE_o <= '1';
						MEM_RAM0_nCE_o <= '1';
						MEM_ROM_nCE_o <= '1';

						if W_req_i = '1' then
							r_cyc <= '1';
							MEM_RAM_nWE_o <= W_RnW_i;
							MEM_ROM_nWE_o <= W_RnW_i;
							MEM_nOE_o <= not W_RnW_i;							
							MEM_A_o <= W_A_i(20 downto 0);

							-- work out which memory chip and what speed
							if W_A_i(23) = '1' then
								MEM_ROM_nCE_o <= '0';
								IF G_FLASH_IS_45 then
									v_rdy_ctdn := to_unsigned(5, v_rdy_ctdn'length);
								else
									v_rdy_ctdn := to_unsigned(7, v_rdy_ctdn'length);
								end if;
							else -- BBRAM
								MEM_RAM0_nCE_o <= '0';
								if G_SLOW_IS_45 then
									v_rdy_ctdn := to_unsigned(5, v_rdy_ctdn'length);
								else
									v_rdy_ctdn := to_unsigned(7, v_rdy_ctdn'length);
								end if;
							end if;

							if W_RnW_i = '1' then							
								state <= wait_rd;
							else
						 		if W_CPU_D_wr_stb_i = '1' then
						 			r_D <= W_D_i;
						 			state <= wait_wr;
						 			r_ack <= r_cyc;
						 		else
									state <= wait_wr_stb;
								end if;
							end if;		
						end if;
					when wait_wr_stb =>
						if W_CPU_D_wr_stb_i = '1' then
				 			r_ack <= r_cyc;
				 			MEM_D_io <= W_D_i;
							state <= wait_wr;
						end if;
					when wait_rd =>
						if v_rdy_ctdn = 0 then
							v_goidle := true;
							r_D	<= MEM_D_io;
							r_ack <= r_cyc;
						else
							v_rdy_ctdn := v_rdy_ctdn - 1;
						end if;
					when wait_wr =>
						if v_rdy_ctdn = 0 then
							v_goidle := true;
							MEM_RAM_nWE_o <= '1';
							MEM_ROM_nWE_o <= '1';
						else
							v_rdy_ctdn := v_rdy_ctdn - 1;
						end if;
					when wait_cyc =>
						if r_cyc = '0' then
							state <= idle;
						end if;
					when others =>
						r_ack <= '1';
						state <= idle;
						r_cyc <= '0';
				end case;

				if v_goidle then
					if r_cyc = '0' then
						state <= idle;
					else
						state <= wait_cyc;
					end if;
				end if;

				if W_req_i = '0' then
					r_cyc <= '0';
					r_ack <= '0';
				end if;

			end if;
		end if;

	end process;


end rtl;
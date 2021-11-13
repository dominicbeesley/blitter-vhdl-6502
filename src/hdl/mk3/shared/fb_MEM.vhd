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
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	fishbone bus - MEM - memory wrapper
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the blitter/cpu board's SRAM
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

--TODO: lose latched D - not really much point?


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;

entity fb_mem is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		G_SWRAM_SLOT						: natural := 1;								-- when set address range $60 0000 - $7F 0000 goes to this MEM_nCE
																									--  defaults to 1 for min_04 on rev.2
		G_FAST_IS_10						: boolean := false;							-- when true run RAM(1..3) at 10ns
		G_SLOW_IS_45						: boolean := false;							-- when true run BB RAM at 45ns else 55ns		
		G_FLASH_IS_45						: boolean := false							-- when true run Flash at 45ns else 55ns
	);
	port(


		-- 2M RAM/256K ROM bus
		MEM_A_o								: out		std_logic_vector(20 downto 0);
		MEM_D_io								: inout	std_logic_vector(7 downto 0);
		MEM_nOE_o							: out		std_logic;
		MEM_nWE_o							: out		std_logic;
		MEM_ROM_nCE_o						: out		std_logic;
		MEM_RAM_nCE_o						: out		std_logic_vector(3 downto 0);

		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;

		debug_mem_a_stb_o					: out		std_logic

	);
end fb_mem;

architecture rtl of fb_mem is

	type 	 	state_mem_t is (idle, wait1, wait2, wait3, wait4, wait5, wait6, wait7, wait8, act);

	signal	state			: state_mem_t;

	signal	i_con_ack	:	std_logic;

begin

	debug_mem_a_stb_o <= fb_c2p_i.a_stb;

--	p_latch_d:process(fb_syscon_i, state, MEM_D_io)
--	begin
--		if fb_syscon_i.rst = '1' then
--			fb_p2c_o.D_rd <= (others => '0');
--		elsif state /= idle and state /= act then
--			fb_p2c_o.D_rd <= MEM_D_io;
--		end if;
--	end process;

	p_state:process(fb_syscon_i)
	variable v_st_first : state_mem_t;
	variable v_rdy_first: natural;
	begin

		if fb_syscon_i.rst = '1' then
			state <= idle;
			MEM_A_o <= (others => '0');
			MEM_D_io <= (others => 'Z');
			MEM_nOE_o <= '1';
			MEM_nWE_o <= '1';
			MEM_RAM_nCE_o <= (others => '1');
			MEM_ROM_nCE_o <= '1';
			fb_p2c_o.rdy_ctdn <= RDY_CTDN_MAX;
			fb_p2c_o.ack <= '0';
			fb_p2c_o.nul <= '0';
		else
			if rising_edge(fb_syscon_i.clk) then
				case state is
					when idle =>
						MEM_A_o <= (others => '0');
						MEM_D_io <= (others => 'Z');
						MEM_nOE_o <= '1';
						MEM_nWE_o <= '1';
						MEM_RAM_nCE_o <= (others => '1');
						MEM_ROM_nCE_o <= '1';
						fb_p2c_o.rdy_ctdn <= RDY_CTDN_MAX;
						fb_p2c_o.ack <= '0';
						fb_p2c_o.nul <= '0';
						if fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' then

							if fb_c2p_i.we = '0' or fb_c2p_i.D_wr_stb = '1' then							
								MEM_nWE_o <= not fb_c2p_i.we;
								MEM_nOE_o <= fb_c2p_i.we;
								MEM_A_o <= fb_c2p_i.A(20 downto 0);
								if fb_c2p_i.we = '1' then
									MEM_D_io <= fb_c2p_i.D_wr;
								end if;

								-- work out which memory chip and what speed
								if fb_c2p_i.A(23) = '1' then
									MEM_ROM_nCE_o <= '0';
									IF G_FLASH_IS_45 then
										v_st_first := wait3;
									else
										v_st_first := wait1;
									end if;
									v_rdy_first := 7;
								elsif fb_c2p_i.A(22 downto 21) = "11" then -- BBRAM
									MEM_RAM_nCE_o(G_SWRAM_SLOT) <= '0';
									if G_SWRAM_SLOT = 0 then
										-- slow BB RAM...how slow?
										if G_SLOW_IS_45 then
											v_st_first := wait3;
											v_rdy_first := 6;
										else
											v_st_first := wait1;
											v_rdy_first := 7;
										end if;
									elsif G_FAST_IS_10 then
										v_st_first := wait7;
										v_rdy_first := 2;
									else
										v_st_first := wait6;
										v_rdy_first := 3;
									end if;
								else
									-- ram at 0..$5F FFFF maps
									MEM_RAM_nCE_o(to_integer(unsigned(fb_c2p_i.A(22 downto 21)))+1) <= '0';
									if G_FAST_IS_10 then
										v_st_first := wait7;
										v_rdy_first := 2;
									else
										v_st_first := wait6;
										v_rdy_first := 3;
									end if;

								end if;


								fb_p2c_o.rdy_ctdn <= to_unsigned(v_rdy_first, RDY_CTDN_LEN);			
								state <= v_st_first;

							end if;
						end if;
					when wait1 =>
						state <= wait2;
						fb_p2c_o.rdy_ctdn <= to_unsigned(7, RDY_CTDN_LEN);
					when wait2 =>
						state <= wait3;
						fb_p2c_o.rdy_ctdn <= to_unsigned(6, RDY_CTDN_LEN);
					when wait3 =>
						state <= wait4;
						fb_p2c_o.rdy_ctdn <= to_unsigned(5, RDY_CTDN_LEN);
					when wait4 =>
						state <= wait5;
						fb_p2c_o.rdy_ctdn <= to_unsigned(4, RDY_CTDN_LEN);
					when wait5 =>
						state <= wait6;
						fb_p2c_o.rdy_ctdn <= to_unsigned(3, RDY_CTDN_LEN);
					when wait6 =>
						state <= wait7;
						fb_p2c_o.rdy_ctdn <= to_unsigned(2, RDY_CTDN_LEN);
					when wait7 =>
						state <= wait8;
						fb_p2c_o.rdy_ctdn <= to_unsigned(1, RDY_CTDN_LEN);
					when wait8 =>
						state <= act;
						fb_p2c_o.rdy_ctdn <= to_unsigned(0, RDY_CTDN_LEN);
						fb_p2c_o.ack <= '1';
						fb_p2c_o.D_rd <= MEM_D_io;
					when act =>
						fb_p2c_o.rdy_ctdn <= to_unsigned(0, RDY_CTDN_LEN);
						MEM_nOE_o <= '1';
						MEM_nWE_o <= '1';
						MEM_RAM_nCE_o <= (others => '1');
						MEM_ROM_nCE_o <= '1';
						fb_p2c_o.ack <= '0';
					when others =>
						fb_p2c_o.nul <= '1';
						fb_p2c_o.ack <= '1';
						state <= idle;
				end case;
				if fb_c2p_i.cyc = '0' or fb_c2p_i.a_stb = '0' then
					state <= idle;
					fb_p2c_o.rdy_ctdn <= RDY_CTDN_MAX;
					fb_p2c_o.ack <= '0';
					fb_p2c_o.nul <= '0';
				end if;
			end if;
		end if;

	end process;


end rtl;
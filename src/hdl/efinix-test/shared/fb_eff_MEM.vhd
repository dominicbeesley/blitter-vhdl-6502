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
-- Module Name:    	fb_eff_mem
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for efinix block RAM
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
use work.fishbone.all;

entity fb_eff_mem is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		G_ADDR_W								: positive	-- number of address lines in memory
			
	);
	port(


		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t

	);
end fb_eff_mem;

architecture rtl of fb_eff_mem is

	type 	 	state_mem_t is (idle, wait_wr_stb);

	type		arr_mem_t is array(2**G_ADDR_W-1 downto 0) of std_logic_vector(7 downto 0) := (others => (others => '0'));

	signal	state			: state_mem_t;

	signal	r_addr		:  std_logic_vector(G_ADDR_W-1 downto 0); 
	signal	i_ack			:  std_logic; -- fast ack for writes on same cycle to make 8MHz on 65816


	signal	r_mem			: arr_mem_t(2**G_ADDR_W-1 to 0);
	signal	i_mem_rd_d	: std_logic_vector(7 downto 0);
	signal	r_had_wr_stb:

	signal	r_we			: std_logic;
	signal	r_d_wr		: std_logic_vector(7 downto 0);

begin

	i_mem_rd_d <= r_mem(to_integer(unsigned(r_addr)));

	p_wr:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i) then
			if r_we = '1' then
				r_mem(r_addr) <= r_d_wr;
			end if;
		end if;

	end process;


	fb_p2c_o.D_rd <= i_mem_rd_d;
	fb_p2c_o.rdy <= r_rdy or i_wr_ack;
	fb_p2c_o.ack <= r_ack or i_wr_ack;
	fb_p2c_o.stall <= '0' when state = idle else '1';

	i_ack 	<= '1' when state = idle and fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' and fb_c2p_i.D_wr_stb = '1' and fb_c2p_i.we = '1' else
					'1' when state = wait_wr_stb and fb_c2p_i.D_wr_stb = '1' else
					'0';

	p_state:process(fb_syscon_i)
	variable v_rdy_ctdn: t_rdy_ctdn;
	begin

		if fb_syscon_i.rst = '1' then
			state <= idle;
			r_ack <= '0';
			r_rdy <= '0';
			r_we <= '0';
			r_d_wr <= (others => '0');
			r_addr <= (others => '0');
		else
			if rising_edge(fb_syscon_i.clk) then

				r_ack <= '0';

				case state is
					when idle =>
						r_we <= '0';						
						r_rdy <= '0';
						v_rdy_ctdn := RDY_CTDN_MAX;	

						if fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' then

							r_rdy_ctdn <= fb_c2p_i.rdy_ctdn;

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
									v_rdy_ctdn := to_unsigned(5, RDY_CTDN_LEN);
								else
									v_rdy_ctdn := to_unsigned(7, RDY_CTDN_LEN);
								end if;
							elsif fb_c2p_i.A(22 downto 21) = "11" then -- BBRAM
								MEM_RAM_nCE_o(G_SWRAM_SLOT) <= '0';
								if G_SWRAM_SLOT = 0 then
									-- slow BB RAM...how slow?
									if G_SLOW_IS_45 then
										v_rdy_ctdn := to_unsigned(5, RDY_CTDN_LEN);
									else
										v_rdy_ctdn := to_unsigned(7, RDY_CTDN_LEN);
									end if;
								elsif G_FAST_IS_10 then
									v_rdy_ctdn := to_unsigned(1, RDY_CTDN_LEN);
								else
									v_rdy_ctdn := to_unsigned(2, RDY_CTDN_LEN);
								end if;
							else
								-- ram at 0..$5F FFFF maps
								MEM_RAM_nCE_o(to_integer(unsigned(fb_c2p_i.A(22 downto 21)))+1) <= '0';
								if G_FAST_IS_10 then
									v_rdy_ctdn := to_unsigned(1, RDY_CTDN_LEN);
								else
									v_rdy_ctdn := to_unsigned(2, RDY_CTDN_LEN);
								end if;

							end if;

							if fb_c2p_i.we = '0' then							
								state <= wait_rd;
							else
							 	if fb_c2p_i.D_wr_stb = '1' then
							 		state <= wait_wr;
							 	else
									state <= wait_wr_stb;
								end if;
							end if;							
						end if;
					when wait_wr_stb =>
						if fb_c2p_i.D_wr_stb = '1' then
							MEM_D_io <= fb_c2p_i.D_wr;
							state <= wait_wr;
						end if;
					when wait_rd =>
						if v_rdy_ctdn <= r_rdy_ctdn then
							r_rdy <= '1';
						else
							r_rdy <= '0';
						end if;

						if v_rdy_ctdn = 0 then
							state <= idle;
							r_ack <= '1';
						else
							v_rdy_ctdn := v_rdy_ctdn - 1;
						end if;
					when wait_wr =>
						r_rdy <= '0';
						if v_rdy_ctdn = 0 then
							state <= idle;
							MEM_nWE_o <= '1';
						else
							v_rdy_ctdn := v_rdy_ctdn - 1;
						end if;
					when others =>
						r_ack <= '1';
						r_rdy <= '1';
						r_rdy_ctdn <= RDY_CTDN_MIN;
						state <= idle;
				end case;

			end if;
		end if;
	end process;


end rtl;
-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2022 Dominic Beesley https://github.com/dominicbeesley
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

-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	24/10/2022
-- Design Name: 
-- Module Name:    	fishbone bus - CPU address translation and wait
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A pass-through fishbone component that translates logical to 
--							physical addresses - this one does nothing!
-- Dependencies: 
--
-- Revision: 
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;

entity fb_cpu_log2phys_simple16 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;										-- fast clock speed in mhz						
		G_MK3									: boolean := false		
	);
	port(

		fb_syscon_i								: in	fb_syscon_t;

		-- controller interface from the cpu
		fb_con_c2p_i							: in fb_con_o_per_i_t;
		fb_con_p2c_o							: out	fb_con_i_per_o_t;

		fb_per_c2p_o							: out fb_con_o_per_i_t;
		fb_per_p2c_i							: in	fb_con_i_per_o_t;

		-- memory control and paging
		JIM_page_i							: in  std_logic_vector(15 downto 0);
		JIM_en_i								: in  std_logic

	);
end fb_cpu_log2phys_simple16;


architecture rtl of fb_cpu_log2phys_simple16 is 

	type state_t is (idle, waitstall, wait_d_stb);

	signal r_state 		: state_t;

	signal r_cyc						: std_logic;
	signal r_A_stb						: std_logic;							-- output address strobe
	signal i_A_stb						: std_logic;							-- input qualified address strobe
	signal i_phys_A					: std_logic_vector(23 downto 0);
	signal r_phys_A					: std_logic_vector(23 downto 0);
	signal r_we							: std_logic;
	signal r_D_wr_stb					: std_logic;
	signal r_D_wr						: std_logic_vector(7 downto 0);
	signal r_rdy_ctdn					: t_rdy_ctdn;

	signal r_done_r_d_wr_stb		: std_logic;


begin

	fb_con_p2c_o.stall <= '0' when r_state = idle else '1';
	fb_con_p2c_o.ack <= fb_per_p2c_i.ack;
	fb_con_p2c_o.rdy <= fb_per_p2c_i.rdy;
	fb_con_p2c_o.D_rd <= fb_per_p2c_i.D_rd;

	fb_per_c2p_o.cyc			<=	r_cyc;
	fb_per_c2p_o.we			<=	r_we;
	fb_per_c2p_o.A				<=	r_phys_A;
	fb_per_c2p_o.A_stb		<= r_A_stb;
	fb_per_c2p_o.D_wr			<= r_D_wr;
	fb_per_c2p_o.D_wr_stb	<= r_D_wr_stb;
	fb_per_c2p_o.rdy_ctdn	<= r_rdy_ctdn;

	-- ================================================================================================ --
	-- State Machine 
	-- ================================================================================================ --

	i_A_stb 	<= '1' when fb_con_c2p_i.cyc = '1' and fb_con_c2p_i.a_stb = '1' and r_state = idle else
					'0';


	p_state:process(fb_syscon_i)
	variable v_accept_wr_stb:boolean;
	begin
		if fb_syscon_i.rst = '1' then
			r_state <= idle;
			r_phys_A <= (others => '0');
			r_cyc <= '0';
			r_we <= '0';
			r_D_wr_stb <= '0';
			r_D_wr <= (others => '0');
			r_rdy_ctdn <= RDY_CTDN_MAX;
			r_a_stb <= '0';
			r_done_r_d_wr_stb <= '0';
		elsif rising_edge(fb_syscon_i.clk) then

			r_a_stb <= '0';

			v_accept_wr_stb := false;

			case r_state is
				when idle =>
					r_done_r_d_wr_stb <= '0';
					r_D_wr_stb <= '0';
					if i_A_stb then
						v_accept_wr_stb := true;
						r_phys_A <= i_phys_A;
						r_we <= fb_con_c2p_i.we;
						r_rdy_ctdn <= fb_con_c2p_i.rdy_ctdn;
						r_cyc <= '1';
						r_state <= waitstall;
						r_a_stb <= '1';
					end if;
				when waitstall =>
					v_accept_wr_stb := true;
					if fb_per_p2c_i.stall = '1' then
						r_a_stb <= '1';
						r_State <= waitstall;
					else
						if fb_con_c2p_i.D_wr_stb = '1' or r_we = '0' or r_done_r_d_wr_stb = '1' then
							r_state <= idle;
							r_done_r_d_wr_stb <= '0';
							r_D_wr_stb <= '0';
						else
							r_state <= wait_d_stb;
						end if;
						r_D_wr_stb <= '0';
					end if;
				when wait_d_stb =>
					v_accept_wr_stb := true;
					r_D_wr_stb <= '0';
					-- this gets cancelled in if below
					if fb_con_c2p_i.D_wr_stb = '1' or r_we = '0' or r_done_r_d_wr_stb = '1' then
						r_state <= idle;
						r_done_r_d_wr_stb <= '0';
						r_D_wr_stb <= '0';
					end if;
				when others =>
					r_state <= idle;
			end case;

			if v_accept_wr_stb then
				if r_done_r_d_wr_stb = '0' or r_state = idle then
					if (r_D_wr_stb = '0' or r_state = idle) and fb_con_c2p_i.D_wr_stb = '1' then
						r_D_wr_stb <= '1';
						r_D_wr <= fb_con_c2p_i.D_WR;
						r_done_r_d_wr_stb <= '1';
					end if;
				end if;
			end if;

			if fb_con_c2p_i.cyc = '0' then
				r_A_stb <= '0';
				r_cyc <= '0';
				r_state <= idle;
				r_D_wr_stb <= '0';
				r_done_r_d_wr_stb <= '0';
			end if;

		end if;
	end process;



	p_l2p:process(all)
	begin
		
		i_phys_A <= fb_con_c2p_i.A;

		if fb_con_c2p_i.A(23 downto 16) = x"FF" then
			if fb_con_c2p_i.A(15 downto 12) >= x"8" and fb_con_c2p_i.A(15 downto 12) < x"F" then
				i_phys_A <= x"00" & '0' & fb_con_c2p_i.A(14 downto 0);
			elsif fb_con_c2p_i.A(15 downto 8) = x"FD" and JIM_en_i = '1' then
				i_phys_A <= JIM_page_i & fb_con_c2p_i.A(7 downto 0);
			end if;
		end if;

	end process;


end rtl;
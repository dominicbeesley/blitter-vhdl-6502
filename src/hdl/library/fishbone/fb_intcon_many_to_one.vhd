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
-- Create Date:    	18/5/2019
-- Design Name: 
-- Module Name:    	one to many Fishbone inter-connect
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		interconnect using configurable priority/round-robin arbitration
-- Dependencies: 
--
-- Revision: --
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.fishbone.all;
use work.common.all;

entity fb_intcon_many_to_one is
	generic (
		SIM					: boolean := false;
		G_CONTROLLER_COUNT		: POSITIVE;
		G_ARB_ROUND_ROBIN : boolean := false
	);
	port (

		fb_syscon_i				: in	fb_syscon_t;

		-- peripheral port connect to controllers
		fb_con_c2p_i			: in	fb_con_o_per_i_arr(G_CONTROLLER_COUNT-1 downto 0);
		fb_con_p2c_o			: out	fb_con_i_per_o_arr(G_CONTROLLER_COUNT-1 downto 0);

		-- controller port connecto to peripherals
		fb_per_c2p_o			: out fb_con_o_per_i_t;
		fb_per_p2c_i			: in 	fb_con_i_per_o_t

	);
end fb_intcon_many_to_one;


architecture rtl of fb_intcon_many_to_one is
	signal	i_cyc_a_stb			: std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);	-- cyc requests in from controllers grouped
	signal	i_cyc					: std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);	-- cyc requests in from controllers grouped
	signal	i_cyc_grant_ix		: unsigned(numbits(G_CONTROLLER_COUNT)-1 downto 0);
	signal	r_cyc_grant_ix		: unsigned(numbits(G_CONTROLLER_COUNT)-1 downto 0);
	signal	r_cyc_act_oh		: unsigned(G_CONTROLLER_COUNT-1 downto 0);				-- controller is active 
	signal	i_a_stb_any			: std_logic;												-- common cyc sent to all peripherals
	signal	r_cyc_ack			: std_logic;												-- signal that cycle is being serviced

	-- register the muxed signals for timing
	signal	r_c2p_A			: std_logic_vector(23 downto 0);						-- registered address of selected controller
	signal	r_c2p_we			: std_logic;												-- registered we 
	signal	r_rdy_ctdn		: t_rdy_ctdn;
	signal	r_D_wr			: std_logic_vector(7 downto 0);
	signal	r_D_wr_stb		: std_logic;

	signal	r_cyc_per		: std_logic;												-- registered cyc for peripheral
	signal	r_a_stb_per		: std_logic;												-- registered a_stb for peripheral

	signal   ir_p2c_stall	: std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);

	--r_state machine
	type		state_t	is	(idle, waitstall, act);
	signal	r_state				: state_t;

begin


g_cyc:for I in G_CONTROLLER_COUNT-1 downto 0 generate
	i_cyc_a_stb(I) <= fb_con_c2p_i(i).cyc and fb_con_c2p_i(i).a_stb;
	i_cyc(I) <= fb_con_c2p_i(i).cyc;
end generate;

	g_arb:if G_ARB_ROUND_ROBIN generate
		-- arbitrate between incoming controllers
		e_arb_rr:entity work.fb_arbiter_roundrobin
		generic map (
			CNT => G_CONTROLLER_COUNT
			)
		port map (
			clk_i 		=> fb_syscon_i.clk,
			rst_i 		=> fb_syscon_i.rst,
			req_i 		=> i_cyc,
			ack_i			=> r_cyc_ack,
			grant_ix_o	=> i_cyc_grant_ix
			);
	else generate
		-- arbitrate between incoming controllers
		e_arb_pri:entity work.fb_arbiter_prior
		generic map (
			CNT => G_CONTROLLER_COUNT
			)
		port map (
			clk_i 		=> fb_syscon_i.clk,
			rst_i 		=> fb_syscon_i.rst,
			req_i 		=> i_cyc,
			ack_i			=> r_cyc_ack,
			grant_ix_o	=> i_cyc_grant_ix
			);		
	end generate;

	i_a_stb_any <= or_reduce(i_cyc_a_stb);

	fb_per_c2p_o.cyc 			<= r_cyc_per;
	fb_per_c2p_o.we 			<= r_c2p_we;
	fb_per_c2p_o.A				<= r_c2p_A;
	fb_per_c2p_o.A_stb		<= r_a_stb_per;
	fb_per_c2p_o.D_wr			<= r_D_wr;
	fb_per_c2p_o.D_wr_stb	<= r_D_wr_stb;
	fb_per_c2p_o.rdy_ctdn   <= r_rdy_ctdn;

	p_stall:process(i_cyc, i_cyc_grant_ix, r_state)
	variable I:natural;
	begin
		ir_p2c_stall <= (others => '1');
		for I in G_CONTROLLER_COUNT-1 downto 0 loop
			if or_reduce(i_cyc) = '1' then
				if r_state = idle and i_cyc_grant_ix = I then
					ir_p2c_stall(I) <= '0';
				end if;
			end if;
		end loop;
	end process;

	g_p2c_shared_bus:for I in G_CONTROLLER_COUNT-1 downto 0 generate
		-- TODO: check if moving data to own shared register saves space
		fb_con_p2c_o(I).D_rd 		<= fb_per_p2c_i.D_rd;
		fb_con_p2c_o(I).rdy 			<= fb_per_p2c_i.rdy and r_cyc_act_oh(I);
		fb_con_p2c_o(I).ack 			<= fb_per_p2c_i.ack and r_cyc_act_oh(I);	
		fb_con_p2c_o(I).stall		<= ir_p2c_stall(I);			
	end generate;

	p_state:process(fb_syscon_i, r_state)
	begin
		if fb_syscon_i.rst = '1' then
			r_state <= idle;
			r_cyc_per <= '0';
			r_a_stb_per <= '0';
			r_c2p_A <= (others => '0');
			r_c2p_we <= '0';
			r_cyc_grant_ix <= (others => '0');
			r_cyc_act_oh <= (others => '0');
			r_D_wr <= (others => '0');
			r_D_wr_stb <= '0';
			r_rdy_ctdn <= RDY_CTDN_MIN;
		elsif rising_edge(fb_syscon_i.clk) then
			r_state <= r_state;
			r_cyc_ack <= '0';

			case r_state is
				when idle =>
					if i_a_stb_any = '1' then
						r_state <= act;
						r_cyc_grant_ix <= i_cyc_grant_ix;
						r_cyc_ack <= '1';
						r_cyc_per <= '1';
						r_a_stb_per <= '1';
						r_c2p_A <= fb_con_c2p_i(to_integer(i_cyc_grant_ix)).A;					
						r_c2p_we <= fb_con_c2p_i(to_integer(i_cyc_grant_ix)).we;
						r_rdy_ctdn <= fb_con_c2p_i(to_integer(i_cyc_grant_ix)).rdy_ctdn;
						r_cyc_act_oh(to_integer(i_cyc_grant_ix)) <= '1';
						r_D_wr_stb <= fb_con_c2p_i(to_integer(i_cyc_grant_ix)).D_wr_stb;
						r_D_wr <= fb_con_c2p_i(to_integer(i_cyc_grant_ix)).D_wr;
						r_state <= waitstall;
					end if;
				when waitstall =>
					-- while stalled latch 
					if fb_per_p2c_i.stall = '1' then
						if fb_con_c2p_i(to_integer(r_cyc_grant_ix)).D_wr_stb = '1' then
							r_d_wr_stb <= '1';
							r_d_wr <= fb_con_c2p_i(to_integer(r_cyc_grant_ix)).D_wr;
						end if;
					else
						r_d_wr_stb <= fb_con_c2p_i(to_integer(r_cyc_grant_ix)).D_wr_stb;
						r_d_wr <= fb_con_c2p_i(to_integer(r_cyc_grant_ix)).D_wr;
					end if;

					if fb_per_p2c_i.stall = '0' then
						r_state <= act;
						r_a_stb_per <= '0';
					end if;
				when act => 
						r_d_wr_stb <= fb_con_c2p_i(to_integer(r_cyc_grant_ix)).D_wr_stb;
						r_d_wr <= fb_con_c2p_i(to_integer(r_cyc_grant_ix)).D_wr;
				when others =>  
					r_state <= r_state; -- do nowt
			end case;

			-- catch all for ended cycle
			if r_state /= idle and i_cyc(to_integer(r_cyc_grant_ix)) = '0' then
				r_state <= idle;
				r_cyc_per <= '0';
				r_cyc_grant_ix <= (others => '0');
				r_cyc_act_oh <= (others => '0');
				r_D_wr <= (others => '0');
				r_D_wr_stb <= '0';
			end if;
		end if;
	end process;


end rtl;
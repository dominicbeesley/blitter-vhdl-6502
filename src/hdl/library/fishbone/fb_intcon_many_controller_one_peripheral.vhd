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
		G_MASTER_COUNT		: POSITIVE;
		G_ARB_ROUND_ROBIN : boolean := false
	);
	port (

		fb_syscon_i				: in	fb_syscon_t;

		-- slave port connect to masters
		fb_mas_m2s_i			: in	fb_mas_o_sla_i_arr(G_MASTER_COUNT-1 downto 0);
		fb_mas_s2m_o			: out	fb_mas_i_sla_o_arr(G_MASTER_COUNT-1 downto 0);

		-- master port connecto to slaves
		fb_sla_m2s_o			: out fb_mas_o_sla_i_t;
		fb_sla_s2m_i			: in 	fb_mas_i_sla_o_t

	);
end fb_intcon_many_to_one;


architecture rtl of fb_intcon_many_to_one is
	signal	i_cyc_req			: std_logic_vector(G_MASTER_COUNT-1 downto 0);	-- cyc requests in from masters grouped
	signal	i_cyc_grant_ix		: unsigned(numbits(G_MASTER_COUNT)-1 downto 0);
	signal	r_cyc_grant_ix		: unsigned(numbits(G_MASTER_COUNT)-1 downto 0);
	signal	r_cyc_act_oh		: unsigned(G_MASTER_COUNT-1 downto 0);				-- master is active 
	signal	i_comcyc				: std_logic;												-- common cyc sent to all slaves
	signal	r_cyc_ack			: std_logic;												-- signal that cycle is being serviced

	signal	i_m2s				: fb_mas_o_sla_i_t := fb_m2s_unsel;					-- the i_m2s that has been granted muxed

	-- register the muxed signals for timing
	signal	r_m2s_A			: std_logic_vector(23 downto 0);						-- registered address of selected master
	signal	r_m2s_we			: std_logic;												-- registered we 
	signal	r_D_wr			: std_logic_vector(7 downto 0);
	signal	r_D_wr_stb		: std_logic;

	signal	r_cyc_sla		: std_logic;												-- registered cyc for slave

	signal	i_s2m				: fb_mas_i_sla_o_t;										-- data returned from selected slave

	--r_state machine
	type		state_t	is	(idle, act);
	signal	r_state				: state_t;

begin


g_cyc:for I in G_MASTER_COUNT-1 downto 0 generate
	i_cyc_req(I) <= fb_mas_m2s_i(i).cyc and fb_mas_m2s_i(i).a_stb;
end generate;

	g_arb:if G_ARB_ROUND_ROBIN generate
		-- arbitrate between incoming masters
		e_arb_rr:entity work.fb_arbiter_roundrobin
		generic map (
			CNT => G_MASTER_COUNT
			)
		port map (
			clk_i 		=> fb_syscon_i.clk,
			rst_i 		=> fb_syscon_i.rst,
			req_i 		=> i_cyc_req,
			ack_i			=> r_cyc_ack,
			grant_ix_o	=> i_cyc_grant_ix
			);
	else generate
		-- arbitrate between incoming masters
		e_arb_pri:entity work.fb_arbiter_prior
		generic map (
			CNT => G_MASTER_COUNT
			)
		port map (
			clk_i 		=> fb_syscon_i.clk,
			rst_i 		=> fb_syscon_i.rst,
			req_i 		=> i_cyc_req,
			ack_i			=> r_cyc_ack,
			grant_ix_o	=> i_cyc_grant_ix
			);		
	end generate;

	i_comcyc <= or_reduce(i_cyc_req);

	fb_sla_m2s_o.cyc 			<= r_cyc_sla;
	fb_sla_m2s_o.we 			<= r_m2s_we;
	fb_sla_m2s_o.A				<= r_m2s_A;
	fb_sla_m2s_o.A_stb		<= r_cyc_sla;
	fb_sla_m2s_o.D_wr			<= r_D_wr;
	fb_sla_m2s_o.D_wr_stb	<= r_D_wr_stb;


	g_s2m_shared_bus:for I in G_MASTER_COUNT-1 downto 0 generate
		-- TODO: check if moving data to own shared register saves space
		fb_mas_s2m_o(I).D_rd 		<= fb_sla_s2m_i.D_rd;
		fb_mas_s2m_o(I).rdy_ctdn 	<= fb_sla_s2m_i.rdy_ctdn when r_cyc_act_oh(I) = '1' else
												 	RDY_CTDN_MAX;
		fb_mas_s2m_o(I).ack 			<= fb_sla_s2m_i.ack and r_cyc_act_oh(I);				
		fb_mas_s2m_o(I).nul 			<= fb_sla_s2m_i.nul and r_cyc_act_oh(I);
	end generate;

	p_state:process(fb_syscon_i, r_state)
	begin
		if fb_syscon_i.rst = '1' then
			r_state <= idle;
			r_cyc_sla <= '0';
			r_m2s_A <= (others => '0');
			r_m2s_we <= '0';
			r_cyc_grant_ix <= (others => '0');
			r_cyc_act_oh <= (others => '0');
			r_D_wr <= (others => '0');
			r_D_wr_stb <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			r_state <= r_state;
			r_cyc_ack <= '0';

			case r_state is
				when idle =>
					if i_comcyc = '1' then
						r_state <= act;
						r_cyc_grant_ix <= i_cyc_grant_ix;
						r_cyc_ack <= '1';
						r_cyc_sla <= '1';
						r_m2s_A <= fb_mas_m2s_i(to_integer(i_cyc_grant_ix)).A;					
						r_m2s_we <= fb_mas_m2s_i(to_integer(i_cyc_grant_ix)).we;
						r_cyc_act_oh(to_integer(i_cyc_grant_ix)) <= '1';
						r_state <= act;
						r_D_wr_stb <= fb_mas_m2s_i(to_integer(i_cyc_grant_ix)).D_wr_stb;
						r_D_wr <= fb_mas_m2s_i(to_integer(i_cyc_grant_ix)).D_wr;
					end if;
				when act =>
					r_D_wr_stb <= fb_mas_m2s_i(to_integer(r_cyc_grant_ix)).D_wr_stb;
					r_D_wr <= fb_mas_m2s_i(to_integer(r_cyc_grant_ix)).D_wr;
				when others =>  
					r_state <= idle;
					r_cyc_sla <= '0';
					r_cyc_grant_ix <= (others => '0');
					r_cyc_act_oh <= (others => '0');
					r_D_wr <= (others => '0');
					r_D_wr_stb <= '0';
					r_state <= idle; -- do nowt
			end case;

			-- catch all for ended cycle
			if r_state /= idle and i_cyc_req(to_integer(r_cyc_grant_ix)) = '0' then
				r_state <= idle;
				r_cyc_sla <= '0';
				r_cyc_grant_ix <= (others => '0');
				r_cyc_act_oh <= (others => '0');
				r_D_wr <= (others => '0');
				r_D_wr_stb <= '0';
			end if;
		end if;
	end process;


end rtl;
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
-- Module Name:    	many to many Fishbone inter-connect
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

entity fb_intcon_shared is
	generic (
		SIM					: boolean := false;
		G_MASTER_COUNT		: POSITIVE;
		G_SLAVE_COUNT		: POSITIVE;
		G_ARB_ROUND_ROBIN : boolean := false;
		G_REGISTER_MAS_S2M: boolean := false
	);
	port (

		fb_syscon_i				: in	fb_syscon_t;

		-- slave port connect to masters
		fb_mas_m2s_i			: in	fb_mas_o_sla_i_arr(G_MASTER_COUNT-1 downto 0);
		fb_mas_s2m_o			: out	fb_mas_i_sla_o_arr(G_MASTER_COUNT-1 downto 0);

		-- master port connecto to slaves
		fb_sla_m2s_o			: out fb_mas_o_sla_i_arr(G_SLAVE_COUNT-1 downto 0);
		fb_sla_s2m_i			: in 	fb_mas_i_sla_o_arr(G_SLAVE_COUNT-1 downto 0);

		-- slave select interface -- note, testing shows that having both one hot and index is faster _and_ uses fewer resources
		slave_sel_addr_o		: out	std_logic_vector(23 downto 0);
		slave_sel_i				: in unsigned(numbits(G_SLAVE_COUNT)-1 downto 0);  -- address decoded selected slave
		slave_sel_oh_i			: in std_logic_vector(G_SLAVE_COUNT-1 downto 0)		-- address decoded selected slaves as one-hot

	);
end fb_intcon_shared;


architecture rtl of fb_intcon_shared is
	signal	i_cyc_req			: std_logic_vector(G_MASTER_COUNT-1 downto 0);	-- cyc requests in from masters grouped
	signal	i_cyc_grant_ix		: unsigned(numbits(G_MASTER_COUNT)-1 downto 0); -- grant signal from arbitrator
	signal	r_cyc_grant_ix		: unsigned(numbits(G_MASTER_COUNT)-1 downto 0); -- indexed which master is active
	signal	r_cyc_act_oh		: unsigned(G_MASTER_COUNT-1 downto 0);				-- one hot for which master is active 
	signal	i_comcyc				: std_logic;												-- '1' when any master is active
	signal	r_cyc_ack			: std_logic;												-- signal that cycle is being serviced

	signal	i_m2s				: fb_mas_o_sla_i_t := fb_m2s_unsel;					-- the i_m2s that has been granted muxed

	-- register the muxed signals for timing
	signal	r_m2s_A			: std_logic_vector(23 downto 0);						-- registered address of selected master
	signal	r_m2s_we			: std_logic;												-- registered we 
	
	signal	r_slave_sel		: unsigned(numbits(G_SLAVE_COUNT)-1 downto 0);  -- registered address decoded selected slave
	signal	r_cyc_sla		: std_logic_vector(G_SLAVE_COUNT-1 downto 0);	-- registered cyc for slaves - one hot

	signal	i_s2m				: fb_mas_i_sla_o_t;										-- data returned from selected slave

	--r_state machine
	type		state_t	is	(idle, sel_slave, act);
	signal	r_state				: state_t;

begin

	slave_sel_addr_o <= i_m2s.A;

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

	-- multiplex i_m2s inputs
	p_mux_m2s:process(r_cyc_grant_ix, fb_mas_m2s_i, i_comcyc)
	begin
		i_m2s <= fb_m2s_unsel;
		if i_comcyc = '1' then
			i_m2s <= fb_mas_m2s_i(to_integer(r_cyc_grant_ix));
		end if;
	end process;

	g_m2s_shared:for I in G_SLAVE_COUNT-1 downto 0 generate
		fb_sla_m2s_o(I).cyc 			<= r_cyc_sla(i);
		fb_sla_m2s_o(I).we 			<= r_m2s_we;
		fb_sla_m2s_o(I).A				<= r_m2s_A;
		fb_sla_m2s_o(I).A_stb		<= r_cyc_sla(I);
		fb_sla_m2s_o(I).D_wr			<= i_m2s.D_wr;
		fb_sla_m2s_o(I).D_wr_stb	<= i_m2s.D_wr_stb;
	end generate;

	-- signals back from selected slave to masters
	p_s2m_shared:process(r_slave_sel, fb_sla_s2m_i, r_state)
	begin
		if r_state = act then
			i_s2m <= fb_sla_s2m_i(to_integer(r_slave_sel));
		else
			i_s2m <= fb_s2m_unsel;
		end if;
	end process;

	G_REGISTER_MAS_S2M_ON:IF G_REGISTER_MAS_S2M GENERATE
		p_reg_mas_s2m:process(fb_syscon_i.clk)
		begin
			if rising_edge(fb_syscon_i.clk) then
				for I in G_MASTER_COUNT-1 downto 0 loop
					-- TODO: check if moving data to own shared register saves space
					fb_mas_s2m_o(I).D_rd 		<= i_s2m.D_rd;
					if r_cyc_act_oh(I) = '1' then
						fb_mas_s2m_o(I).rdy_ctdn 	<= i_s2m.rdy_ctdn;
					else
						fb_mas_s2m_o(I).rdy_ctdn 	<= RDY_CTDN_MAX;
					end if;
					fb_mas_s2m_o(I).ack 			<= i_s2m.ack and r_cyc_act_oh(I);				
					fb_mas_s2m_o(I).nul 			<= i_s2m.nul and r_cyc_act_oh(I);
				end loop;
			end if;
		end process;
	END GENERATE;


	G_REGISTER_MAS_S2M_OFF:IF NOT G_REGISTER_MAS_S2M GENERATE
		g_s2m_shared_bus:for I in G_MASTER_COUNT-1 downto 0 generate
					-- TODO: check if moving data to own shared register saves space
					fb_mas_s2m_o(I).D_rd 		<= i_s2m.D_rd;
					fb_mas_s2m_o(I).rdy_ctdn 	<= i_s2m.rdy_ctdn when r_cyc_act_oh(I) = '1' else
														 	RDY_CTDN_MAX;
					fb_mas_s2m_o(I).ack 			<= i_s2m.ack and r_cyc_act_oh(I);				
					fb_mas_s2m_o(I).nul 			<= i_s2m.nul and r_cyc_act_oh(I);
		end generate;
	END GENERATE;

	p_state:process(fb_syscon_i, r_state)
	begin
		if fb_syscon_i.rst = '1' then
			r_state <= idle;
			r_slave_sel <= (others => '0');
			r_cyc_sla <= (G_SLAVE_COUNT-1 downto 0 => '0');
			r_m2s_A <= (others => '0');
			r_m2s_we <= '0';
			r_cyc_grant_ix <= (others => '0');
			r_cyc_act_oh <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
			r_state <= r_state;
			r_cyc_ack <= '0';

			case r_state is
				when idle =>
					if i_comcyc = '1' then
						r_state <= sel_slave;
						r_cyc_grant_ix <= i_cyc_grant_ix;
						r_cyc_ack <= '1';
					end if;
				when sel_slave =>
					r_cyc_sla <= slave_sel_oh_i;
					r_slave_sel <= slave_sel_i;
					--register these as they shouldn't change during a cycle
					r_m2s_A <= i_m2s.A;					
					r_m2s_we <= i_m2s.we;
					r_cyc_act_oh(to_integer(r_cyc_grant_ix)) <= '1';
					r_state <= act;
				when others =>  
					r_state <= r_state; -- do nowt
			end case;

			-- catch all for ended cycle
			if r_state /= idle and i_cyc_req(to_integer(r_cyc_grant_ix)) = '0' then
				r_state <= idle;
				r_slave_sel <= (others => '0');
				r_cyc_sla <= (G_SLAVE_COUNT-1 downto 0 => '0');
				r_cyc_grant_ix <= (others => '0');
				r_cyc_act_oh <= (others => '0');
			end if;
		end if;
	end process;


end rtl;
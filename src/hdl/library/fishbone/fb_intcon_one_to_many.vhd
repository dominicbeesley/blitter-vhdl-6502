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
-- Module Name:    	many to one Fishbone interconnect
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

entity fb_intcon_one_to_many is
	generic (
		SIM					: boolean := false;
		G_SLAVE_COUNT		: POSITIVE;
		G_ARB_ROUND_ROBIN : boolean := false;
		G_ADDRESS_WIDTH	: POSITIVE 						-- width of the address that we care about
	);
	port (

		fb_syscon_i				: in	fb_syscon_t;

		-- slave port connect to masters
		fb_mas_m2s_i			: in	fb_mas_o_sla_i_t;
		fb_mas_s2m_o			: out	fb_mas_i_sla_o_t;

		-- master port connecto to slaves
		fb_sla_m2s_o			: out fb_mas_o_sla_i_arr(G_SLAVE_COUNT-1 downto 0);
		fb_sla_s2m_i			: in 	fb_mas_i_sla_o_arr(G_SLAVE_COUNT-1 downto 0);

		-- slave select interface -- note, testing shows that having both one hot and index is faster _and_ uses fewer resources
		slave_sel_addr_o		: out	std_logic_vector(G_ADDRESS_WIDTH-1 downto 0);
		slave_sel_i				: in unsigned(numbits(G_SLAVE_COUNT)-1 downto 0);  -- address decoded selected slave
		slave_sel_oh_i			: in std_logic_vector(G_SLAVE_COUNT-1 downto 0)		-- address decoded selected slaves as one-hot

	);
end fb_intcon_one_to_many;


architecture rtl of fb_intcon_one_to_many is
	
	signal	r_slave_sel_ix	: unsigned(numbits(G_SLAVE_COUNT)-1 downto 0);  -- registered address decoded selected slave index
	signal	r_cyc_sla_oh	: std_logic_vector(G_SLAVE_COUNT-1 downto 0);	-- registered cyc for slaves - one hot
	

	signal	i_s2m				: fb_mas_i_sla_o_t;										-- data returned from selected slave

	--r_state machine
	type		state_t	is	(idle, act);
	signal	r_state				: state_t;

	signal	r_mas_we			: std_logic;
	signal	r_mas_D_wr		: std_logic_vector(7 downto 0);
	signal	r_mas_D_wr_stb	: std_logic;
	signal	r_mas_A			: std_logic_vector(G_ADDRESS_WIDTH-1 downto 0);
	signal 	i_mas_A			: std_logic_vector(23 downto 0);

begin

	slave_sel_addr_o <= fb_mas_m2s_i.A(G_ADDRESS_WIDTH-1 downto 0);

	p_frig:process(r_mas_A)
	begin
		i_mas_A <= (others => '-');
		i_mas_A(G_ADDRESS_WIDTH-1 downto 0) <= r_mas_A;
	end process;

	g_m2s_shared:for I in G_SLAVE_COUNT-1 downto 0 generate
		fb_sla_m2s_o(I).cyc 			<= r_cyc_sla_oh(I);
		fb_sla_m2s_o(I).A_stb		<= r_cyc_sla_oh(I);
		fb_sla_m2s_o(I).we 			<= r_mas_we;
		fb_sla_m2s_o(I).A				<= i_mas_A;
		fb_sla_m2s_o(I).D_wr			<= r_mas_D_wr;
		fb_sla_m2s_o(I).D_wr_stb	<= r_mas_D_wr_stb;
	end generate;

	-- signals back from selected slave to masters
	p_s2m_shared:process(r_slave_sel_ix, fb_sla_s2m_i, r_state)
	begin
		if r_state = act then
			i_s2m <= fb_sla_s2m_i(to_integer(r_slave_sel_ix));
		else
			i_s2m <= fb_s2m_unsel;
		end if;
	end process;

	fb_mas_s2m_o.D_rd 		<= i_s2m.D_rd;
	fb_mas_s2m_o.rdy_ctdn 	<= i_s2m.rdy_ctdn;
	fb_mas_s2m_o.ack 			<= i_s2m.ack;				
	fb_mas_s2m_o.nul 			<= i_s2m.nul;

	p_state:process(fb_syscon_i, r_state)
	begin
		if fb_syscon_i.rst = '1' then
			r_state <= idle;
			r_slave_sel_ix <= (others => '0');
			r_cyc_sla_oh <= (G_SLAVE_COUNT-1 downto 0 => '0');
			r_mas_A <= (others => '0');
			r_mas_D_wr <= (others => '0');
			r_mas_D_wr_stb <= '0';
			r_mas_we <= '0';
		elsif rising_edge(fb_syscon_i.clk) then

			r_state <= r_state;

			case r_state is
				when idle =>
					if fb_mas_m2s_i.cyc = '1' and fb_mas_m2s_i.A_stb = '1' then
						r_state <= act;
						r_cyc_sla_oh <= slave_sel_oh_i;
						r_slave_sel_ix <= slave_sel_i;
						r_mas_A <= fb_mas_m2s_i.A(G_ADDRESS_WIDTH-1 downto 0);
						r_mas_we <= fb_mas_m2s_i.we;
					end if;
				when act =>
					r_mas_D_wr <= fb_mas_m2s_i.D_wr;
					r_mas_D_wr_stb <= fb_mas_m2s_i.D_wr_stb;
					r_state <= r_state; -- do nowt
				when others =>  
					r_slave_sel_ix <= (others => '0');
					r_cyc_sla_oh <= (others => '0');
					r_mas_D_wr <= (others => '0');
					r_mas_D_wr_stb <= '0';
					r_state <= idle; -- do nowt
			end case;

			-- catch all for ended cycle
			if fb_mas_m2s_i.A_stb = '0' or fb_mas_m2s_i.cyc = '0' then
				r_state <= idle;
				r_slave_sel_ix <= (others => '0');
				r_cyc_sla_oh <= (others => '0');
			end if;
		end if;
	end process;


end rtl;
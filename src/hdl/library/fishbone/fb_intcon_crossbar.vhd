-- MIT License
-- 
-- Copyright (c) 2019 dominicbeesley
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
-- 

-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	18/5/2019
-- Design Name: 
-- Module Name:    	Crossbar Fishbone inter-connect
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Crossbar switch using priority arbitration
-- Dependencies: 
--
-- Revision: --
----------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fishbone.all;
use work.common.all;

entity fb_intcon_crossbar is
	generic (
		G_MASTER_COUNT		: POSITIVE;
		G_SLAVE_COUNT		: POSITIVE
	);
	port (

		fb_syscon_i				: in	fb_syscon_t;

		-- slave port connect to masters
		fb_mas_m2s_i			: in	fb_mas_o_sla_i_arr(G_MASTER_COUNT-1 downto 0);
		fb_mas_s2m_o			: out	fb_mas_i_sla_o_arr(G_MASTER_COUNT-1 downto 0);

		-- master port connecto to slaves
		fb_sla_m2s_o			: out fb_mas_o_sla_i_arr(G_SLAVE_COUNT-1 downto 0);
		fb_sla_s2m_i			: in 	fb_mas_i_sla_o_arr(G_SLAVE_COUNT-1 downto 0);


		-- the addresses to be mapped
		map_addr_to_map_o		: out	fb_std_logic_2d(G_MASTER_COUNT-1 downto 0, 23 downto 0);	
		-- possibly translated address
		map_addr_mapped_i		: in	fb_std_logic_2d(G_MASTER_COUNT-1 downto 0, 23 downto 0);					
		-- a set of unsigned values indicating which slave (if any) is selected
		map_slave_sel_i		: in	fb_std_logic_2d(G_MASTER_COUNT-1 downto 0, numbits(G_SLAVE_COUNT)-1 downto 0);
		-- set if a slave should be selected
		map_addr_matched_i   : in  std_logic_vector(G_MASTER_COUNT-1 downto 0)


	);
end fb_intcon_crossbar;


architecture rtl of fb_intcon_crossbar is

	type		state_t is (idle, sel, act);

	type		state_arr is array(G_MASTER_COUNT-1 downto 0) of state_t;

	type		master_arr_of_slave_oh is array (G_MASTER_COUNT-1 downto 0) of std_logic_vector(G_SLAVE_COUNT-1 downto 0);
	type		slave_arr_of_master_oh is array (G_SLAVE_COUNT-1 downto 0) of std_logic_vector(G_MASTER_COUNT-1 downto 0);
	type		master_arr_of_slave_unsigned is array (G_MASTER_COUNT-1 downto 0) of unsigned(numbits(G_SLAVE_COUNT)-1 downto 0);
	type		slave_arr_of_master_unsigned is array (G_SLAVE_COUNT-1 downto 0) of unsigned(numbits(G_MASTER_COUNT)-1 downto 0);
		

	-- note for the signals marked one-hot they may all be 0 hot i.e. either one bit in the bitmask
	-- will be selected or none

	signal	r_state						: state_arr;												-- state machine state for each master
	signal	r_slave_busy				: std_logic_vector(G_SLAVE_COUNT-1 downto 0);	-- slave is marked busy until cyc released
	signal	r_master_nul				: std_logic_vector(G_MASTER_COUNT-1 downto 0);	-- error return null to master

	signal   r_fb_mas_s2m				: fb_mas_i_sla_o_arr(G_MASTER_COUNT-1 downto 0);-- slave signals back to each master

	signal 	i_map_addr_to_map			: fb_std_logic_2d(G_MASTER_COUNT-1 downto 0, 23 downto 0);		

	signal	r_arr_slave_req_oh		: slave_arr_of_master_oh;
	signal	i_arr_slave_gnt_oh		: slave_arr_of_master_oh;
	signal	i_arr_slave_sel			: master_arr_of_slave_unsigned;

	signal	r_arr_slave2master_act  : slave_arr_of_master_unsigned;
	signal	r_arr_master2slave_act  : master_arr_of_slave_unsigned;

	signal clk : std_logic;
	signal rst : std_logic;

begin

	-- this may seem unnecessary but ISIM mucks up the state machines
	-- if the clock signal comes from a record.
	clk <= fb_syscon_i.clk;
	rst <= fb_syscon_i.rst;

	map_addr_to_map_o <= i_map_addr_to_map;

	p_addrmap:process(fb_mas_m2s_i)
	begin
		for M in G_MASTER_COUNT-1 downto 0 loop
			for B in 23 downto 0 loop
				i_map_addr_to_map(M, B) <= fb_mas_m2s_i(M).A(B);
			end loop;
		end loop;
	end process;

	-- rearrange 2d signals as arrays for convenience...hopefully this should optimise away!
	p_mas_map:process(map_slave_sel_i)
	begin	
		for M in G_MASTER_COUNT-1 downto 0 loop
			for B in numbits(G_SLAVE_COUNT)-1 downto 0 loop
				i_arr_slave_sel(M)(B) <= map_slave_sel_i(M, B);
			end loop;
		end loop;
	end process;

	p_mas2req:process(rst, clk)
	begin
		if rst = '1' then
			for M in G_MASTER_COUNT-1 downto 0 loop
				for S in G_SLAVE_COUNT-1 downto 0 loop
					r_arr_slave_req_oh(S)(M) <= '0';
				end loop;
			end loop;
		elsif rising_edge(clk) then
			for S in G_SLAVE_COUNT-1 downto 0 loop
				r_arr_slave_req_oh(S) <= (others => '0');
			end loop;
			for M in G_MASTER_COUNT-1 downto 0 loop
				if fb_mas_m2s_i(M).cyc = '1' and fb_mas_m2s_i(M).A_stb = '1' then
					r_arr_slave_req_oh(to_integer(i_arr_slave_sel(M)))(M) <= '1';
				end if;
			end loop;
		end if;
	end process;

	g_arb:for S in G_SLAVE_COUNT-1 downto 0 generate
		e:entity work.fb_arbiter_prior_lsb
		generic map (
			WIDTH => G_MASTER_COUNT
		)
		port map (
			req_i => r_arr_slave_req_oh(S),
			gnt_o => i_arr_slave_gnt_oh(S)
		);
	end generate;


	-- per master state machine
	p_sel: process(rst, clk)
	variable v_tmp : boolean;
	variable v_tmp2 : boolean;
	begin

		if rst = '1' then
			for M in G_MASTER_COUNT-1 downto 0 loop
				-- for each master run this process
				r_state(M) <= idle;
				r_slave_busy <= (others => '0');
				r_master_nul(M) <= '0';
				r_arr_master2slave_act(M) <= (others => '-');
			end loop;
			for S in G_SLAVE_COUNT-1 downto 0 loop
				r_arr_slave2master_act(S) <= (others => '-');
			end loop;
		else
			if rising_edge(clk) then

				for M in G_MASTER_COUNT-1 downto 0 loop
					-- for each master run this process
					case r_state(M) is
						when idle =>
							-- wait for master to request something
							if fb_mas_m2s_i(M).cyc = '1' and fb_mas_m2s_i(M).A_stb = '1' then
								r_state(M) <= sel;
							end if;
						when sel =>
							v_tmp := true;
							v_tmp2 := false;
							if map_addr_matched_i(M) = '1' then
								v_tmp := false;
								for S in G_SLAVE_COUNT-1 downto 0 loop
									if i_arr_slave_gnt_oh(S)(M) = '1' and r_slave_busy(S) = '0' then
										v_tmp2 := true;
										r_slave_busy(S) <= '1';
										r_arr_master2slave_act(M) <= to_unsigned(S, numbits(G_SLAVE_COUNT));
										r_arr_slave2master_act(S) <= to_unsigned(M, numbits(G_MASTER_COUNT));
									end if;
								end loop;
							end if;
							if v_tmp then
								-- no slave matched do a dummy cyle!
								r_state(M) <= act;
								r_master_nul(M) <= '1';
							elsif v_tmp2 then
								r_state(M) <= act;
								r_master_nul(M) <= '0';
							end if;
						when act =>
							if fb_mas_m2s_i(M).cyc = '0' then
								r_state(M) <= idle;
								r_master_nul(M) <= '0';
								r_slave_busy(to_integer(r_arr_master2slave_act(M))) <= '0';
							end if;
						when others =>
							r_state(M) <= idle;
							r_master_nul(M) <= '0';
					end case;
				end loop;
			end if;
		end if;
	end process;

	p_mas2slv_crossbar:process(clk)
	begin
		if rising_edge(clk) then
			g_addr: for I in G_SLAVE_COUNT-1 downto 0 loop
				if r_slave_busy(I) = '0' then
					fb_sla_m2s_o(I) <= fb_m2s_unsel;
				else
					fb_sla_m2s_o(I) <= fb_mas_m2s_i(to_integer(r_arr_slave2master_act(I)));
				end if;
			end loop;
		end if;
	end process;

	fb_mas_s2m_o <= r_fb_mas_s2m;

	p_s2m:process(rst, clk)
	begin

		if rst = '1' then
			g_addr_m_rst: for M in G_MASTER_COUNT-1 downto 0 loop
				r_fb_mas_s2m(M) <= fb_s2m_unsel;
			end loop;
		elsif rising_edge(clk) then
			g_addr_m: for M in G_MASTER_COUNT-1 downto 0 loop
				-- default / unmatched states
				if (r_state(M) = act) then
					if r_master_nul(M) = '1' then
						r_fb_mas_s2m(M) <=
						(
							D_rd => (others => '1'),
							rdy => RDY_CTDN_MIN,
							nul => '1',
							ack => fb_syscon_i.cpu_clks(FB_CPUCLKINDEX(fb_mas_m2s_i(M).cyc_speed)).cpu_clken
						);
					else
						r_fb_mas_s2m(M) <= fb_sla_s2m_i(to_integer(r_arr_master2slave_act(M)));
					end if;
				else
					r_fb_mas_s2m(M) <= fb_s2m_unsel;
				end if;
			end loop;
		end if;
	end process;

end rtl;
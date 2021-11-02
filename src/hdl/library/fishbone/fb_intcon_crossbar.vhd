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
		G_CONTROLLER_COUNT		: POSITIVE;
		G_PERIPHERAL_COUNT		: POSITIVE
	);
	port (

		fb_syscon_i				: in	fb_syscon_t;

		-- peripheral port connect to controllers
		fb_con_c2p_i			: in	fb_con_o_per_i_arr(G_CONTROLLER_COUNT-1 downto 0);
		fb_con_p2c_o			: out	fb_con_i_per_o_arr(G_CONTROLLER_COUNT-1 downto 0);

		-- controller port connecto to peripherals
		fb_per_c2p_o			: out fb_con_o_per_i_arr(G_PERIPHERAL_COUNT-1 downto 0);
		fb_per_p2c_i			: in 	fb_con_i_per_o_arr(G_PERIPHERAL_COUNT-1 downto 0);


		-- the addresses to be mapped
		map_addr_to_map_o		: out	fb_std_logic_2d(G_CONTROLLER_COUNT-1 downto 0, 23 downto 0);	
		-- possibly translated address
		map_addr_mapped_i		: in	fb_std_logic_2d(G_CONTROLLER_COUNT-1 downto 0, 23 downto 0);					
		-- a set of unsigned values indicating which peripheral (if any) is selected
		map_peripheral_sel_i		: in	fb_std_logic_2d(G_CONTROLLER_COUNT-1 downto 0, numbits(G_PERIPHERAL_COUNT)-1 downto 0);
		-- set if a peripheral should be selected
		map_addr_matched_i   : in  std_logic_vector(G_CONTROLLER_COUNT-1 downto 0)


	);
end fb_intcon_crossbar;


architecture rtl of fb_intcon_crossbar is

	type		state_t is (idle, sel, act);

	type		state_arr is array(G_CONTROLLER_COUNT-1 downto 0) of state_t;

	type		controller_arr_of_peripheral_oh is array (G_CONTROLLER_COUNT-1 downto 0) of std_logic_vector(G_PERIPHERAL_COUNT-1 downto 0);
	type		peripheral_arr_of_controller_oh is array (G_PERIPHERAL_COUNT-1 downto 0) of std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);
	type		controller_arr_of_peripheral_unsigned is array (G_CONTROLLER_COUNT-1 downto 0) of unsigned(numbits(G_PERIPHERAL_COUNT)-1 downto 0);
	type		peripheral_arr_of_controller_unsigned is array (G_PERIPHERAL_COUNT-1 downto 0) of unsigned(numbits(G_CONTROLLER_COUNT)-1 downto 0);
		

	-- note for the signals marked one-hot they may all be 0 hot i.e. either one bit in the bitmask
	-- will be selected or none

	signal	r_state						: state_arr;												-- state machine state for each controller
	signal	r_peripheral_busy				: std_logic_vector(G_PERIPHERAL_COUNT-1 downto 0);	-- peripheral is marked busy until cyc released
	signal	r_controller_nul				: std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);	-- error return null to controller

	signal   r_fb_con_s2m				: fb_con_i_per_o_arr(G_CONTROLLER_COUNT-1 downto 0);-- peripheral signals back to each controller

	signal 	i_map_addr_to_map			: fb_std_logic_2d(G_CONTROLLER_COUNT-1 downto 0, 23 downto 0);		

	signal	r_arr_peripheral_req_oh		: peripheral_arr_of_controller_oh;
	signal	i_arr_peripheral_gnt_oh		: peripheral_arr_of_controller_oh;
	signal	i_arr_peripheral_sel			: controller_arr_of_peripheral_unsigned;

	signal	r_arr_p2c_act  : peripheral_arr_of_controller_unsigned;
	signal	r_arr_c2p_act  : controller_arr_of_peripheral_unsigned;

	signal clk : std_logic;
	signal rst : std_logic;

begin

	-- this may seem unnecessary but ISIM mucks up the state machines
	-- if the clock signal comes from a record.
	clk <= fb_syscon_i.clk;
	rst <= fb_syscon_i.rst;

	map_addr_to_map_o <= i_map_addr_to_map;

	p_addrmap:process(fb_con_c2p_i)
	begin
		for M in G_CONTROLLER_COUNT-1 downto 0 loop
			for B in 23 downto 0 loop
				i_map_addr_to_map(M, B) <= fb_con_c2p_i(M).A(B);
			end loop;
		end loop;
	end process;

	-- rearrange 2d signals as arrays for convenience...hopefully this should optimise away!
	p_con_map:process(map_peripheral_sel_i)
	begin	
		for M in G_CONTROLLER_COUNT-1 downto 0 loop
			for B in numbits(G_PERIPHERAL_COUNT)-1 downto 0 loop
				i_arr_peripheral_sel(M)(B) <= map_peripheral_sel_i(M, B);
			end loop;
		end loop;
	end process;

	p_con2req:process(rst, clk)
	begin
		if rst = '1' then
			for M in G_CONTROLLER_COUNT-1 downto 0 loop
				for S in G_PERIPHERAL_COUNT-1 downto 0 loop
					r_arr_peripheral_req_oh(S)(M) <= '0';
				end loop;
			end loop;
		elsif rising_edge(clk) then
			for S in G_PERIPHERAL_COUNT-1 downto 0 loop
				r_arr_peripheral_req_oh(S) <= (others => '0');
			end loop;
			for M in G_CONTROLLER_COUNT-1 downto 0 loop
				if fb_con_c2p_i(M).cyc = '1' and fb_con_c2p_i(M).A_stb = '1' then
					r_arr_peripheral_req_oh(to_integer(i_arr_peripheral_sel(M)))(M) <= '1';
				end if;
			end loop;
		end if;
	end process;

	g_arb:for S in G_PERIPHERAL_COUNT-1 downto 0 generate
		e:entity work.fb_arbiter_prior_lsb
		generic map (
			WIDTH => G_CONTROLLER_COUNT
		)
		port map (
			req_i => r_arr_peripheral_req_oh(S),
			gnt_o => i_arr_peripheral_gnt_oh(S)
		);
	end generate;


	-- per controller state machine
	p_sel: process(rst, clk)
	variable v_tmp : boolean;
	variable v_tmp2 : boolean;
	begin

		if rst = '1' then
			for M in G_CONTROLLER_COUNT-1 downto 0 loop
				-- for each controller run this process
				r_state(M) <= idle;
				r_peripheral_busy <= (others => '0');
				r_controller_nul(M) <= '0';
				r_arr_c2p_act(M) <= (others => '-');
			end loop;
			for S in G_PERIPHERAL_COUNT-1 downto 0 loop
				r_arr_p2c_act(S) <= (others => '-');
			end loop;
		else
			if rising_edge(clk) then

				for M in G_CONTROLLER_COUNT-1 downto 0 loop
					-- for each controller run this process
					case r_state(M) is
						when idle =>
							-- wait for controller to request something
							if fb_con_c2p_i(M).cyc = '1' and fb_con_c2p_i(M).A_stb = '1' then
								r_state(M) <= sel;
							end if;
						when sel =>
							v_tmp := true;
							v_tmp2 := false;
							if map_addr_matched_i(M) = '1' then
								v_tmp := false;
								for S in G_PERIPHERAL_COUNT-1 downto 0 loop
									if i_arr_peripheral_gnt_oh(S)(M) = '1' and r_peripheral_busy(S) = '0' then
										v_tmp2 := true;
										r_peripheral_busy(S) <= '1';
										r_arr_c2p_act(M) <= to_unsigned(S, numbits(G_PERIPHERAL_COUNT));
										r_arr_p2c_act(S) <= to_unsigned(M, numbits(G_CONTROLLER_COUNT));
									end if;
								end loop;
							end if;
							if v_tmp then
								-- no peripheral matched do a dummy cyle!
								r_state(M) <= act;
								r_controller_nul(M) <= '1';
							elsif v_tmp2 then
								r_state(M) <= act;
								r_controller_nul(M) <= '0';
							end if;
						when act =>
							if fb_con_c2p_i(M).cyc = '0' then
								r_state(M) <= idle;
								r_controller_nul(M) <= '0';
								r_peripheral_busy(to_integer(r_arr_c2p_act(M))) <= '0';
							end if;
						when others =>
							r_state(M) <= idle;
							r_controller_nul(M) <= '0';
					end case;
				end loop;
			end if;
		end if;
	end process;

	p_c2p_crossbar:process(clk)
	begin
		if rising_edge(clk) then
			g_addr: for I in G_PERIPHERAL_COUNT-1 downto 0 loop
				if r_peripheral_busy(I) = '0' then
					fb_per_c2p_o(I) <= fb_c2p_unsel;
				else
					fb_per_c2p_o(I) <= fb_con_c2p_i(to_integer(r_arr_p2c_act(I)));
				end if;
			end loop;
		end if;
	end process;

	fb_con_p2c_o <= r_fb_con_s2m;

	p_s2m:process(rst, clk)
	begin

		if rst = '1' then
			g_addr_m_rst: for M in G_CONTROLLER_COUNT-1 downto 0 loop
				r_fb_con_s2m(M) <= fb_p2c_unsel;
			end loop;
		elsif rising_edge(clk) then
			g_addr_m: for M in G_CONTROLLER_COUNT-1 downto 0 loop
				-- default / unmatched states
				if (r_state(M) = act) then
					if r_controller_nul(M) = '1' then
						r_fb_con_s2m(M) <=
						(
							D_rd => (others => '1'),
							rdy => RDY_CTDN_MIN,
							nul => '1',
							ack => fb_syscon_i.cpu_clks(FB_CPUCLKINDEX(fb_con_c2p_i(M).cyc_speed)).cpu_clken
						);
					else
						r_fb_con_s2m(M) <= fb_per_p2c_i(to_integer(r_arr_c2p_act(M)));
					end if;
				else
					r_fb_con_s2m(M) <= fb_p2c_unsel;
				end if;
			end loop;
		end if;
	end process;

end rtl;
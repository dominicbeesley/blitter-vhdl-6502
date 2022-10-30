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
-- Create Date:    	28/10/2022
-- Design Name: 
-- Module Name:    	fishbone bus - CPU burst transfers for multiple bytes
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Dependencies: 
--
-- Revision: 
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.fb_sys_pack.all;


entity fb_cpu_con_burst is
generic (
	SIM : boolean := false;
	G_BYTELANES : positive := 1
	);
port (

	-- config

	BE_i					: in std_logic; -- 1 for big endian

	-- from cpu wrappers

	cyc_i					: in std_logic; 
	A_i					: in std_logic_vector(23 downto 0);
	we_i					: in std_logic;
	lane_req_i			: in std_logic_vector(G_BYTELANES-1 downto 0);			-- this is a mask of byte lanes to be read/written and must all be set when cyc goes active
	D_wr_i				: in std_logic_vector((8 * G_BYTELANES)-1 downto 0);
	D_wr_stb_i			: in std_logic_vector(G_BYTELANES-1 downto 0);
	rdy_ctdn_i			: in t_rdy_ctdn;

	-- return to wrappers

	rdy_o					: out std_logic;												-- unlike fishbone D_rd, rdy, ack_lane and ack will latch until end of cycle
	act_lane_o			: out std_logic_vector(G_BYTELANES-1 downto 0);
	ack_lane_o			: out std_logic_vector(G_BYTELANES-1 downto 0);
	ack_o					: out std_logic;
	D_rd_o				: out std_logic_vector((8 * G_BYTELANES)-1 downto 0);

	-- fishbone byte wide controller interface

	fb_syscon_i			: in fb_syscon_t;

	fb_con_c2p_o		: out fb_con_o_per_i_t;
	fb_con_p2c_i		: in	fb_con_i_per_o_t

);
end fb_cpu_con_burst;


architecture rtl of fb_cpu_con_burst is

	signal r_cyc			: std_logic;

	signal r_tx_mas		: std_logic_vector(G_BYTELANES-1 downto 0);
	signal r_rx_mas		: std_logic_vector(G_BYTELANES-1 downto 0);

	signal i_tx_cur		: std_logic_vector(G_BYTELANES-1 downto 0);
	signal i_rx_cur		: std_logic_vector(G_BYTELANES-1 downto 0);

	signal r_A				: std_logic_vector(23 downto 0);
	signal r_D_rd			: std_logic_vector((8 * G_BYTELANES)-1 downto 0);
	signal r_rdy			: std_logic;
	signal r_ack			: std_logic;
	signal r_ack_lane		: std_logic_vector(G_BYTELANES-1 downto 0);
	signal r_wait_d_stb	: std_logic;

	function priority_endian(
		BE		: std_logic;
		req	: std_logic_vector(G_BYTELANES-1 downto 0)		
		) return std_logic_vector is
	variable i:natural;
	variable b:boolean;
	variable ret:std_logic_vector(G_BYTELANES-1 downto 0);
	begin

		b := false;
		ret := (others => '0');
		if BE = '1' then
			for i in G_BYTELANES-1 downto 0 loop
				if not b and req(i) = '1' then
				   ret(i) := '1';
					b:=true;
				end if;
			end loop;
		else
			for i in 0 to G_BYTELANES-1 loop
				if not b and req(i) = '1' then
				   ret(i) := '1';
					b:=true;
				end if;
			end loop;
		end if;
		return ret;
	end function;



begin

	i_tx_cur <= priority_endian(BE_i, lane_req_i and r_tx_mas);
	i_rx_cur <= priority_endian(BE_i, lane_req_i and r_rx_mas);

	p_con_state:process(fb_syscon_i)
	begin

		if fb_syscon_i.rst = '1' then
			r_cyc <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if r_cyc then
				if cyc_i = '0' then
					r_cyc <= '0';
				end if;
			else
				if cyc_i = '1' then
					r_cyc <= '1';
				end if;
			end if;
		end if;

	end process;

	p_tx:process(fb_syscon_i) 
	begin
		if fb_syscon_i.rst = '1' then
			r_tx_mas <= (others => '1');
			r_A <= (others => '0');	
			r_wait_d_stb <= '0';
		elsif rising_edge(fb_syscon_i.clk) then

			if r_cyc = '0' and cyc_i = '1' then
				r_tx_mas <= (others => '1');
				r_A <= A_i;
				r_wait_d_stb <= '0';
			elsif r_cyc = '1' then
				if (fb_con_p2c_i.stall = '0' and or_reduce(i_tx_cur) = '1') or r_wait_d_stb = '1' then
					if we_i = '0' or or_reduce(i_tx_cur and D_wr_stb_i) = '1' then
						r_tx_mas <= r_tx_mas and not i_tx_cur;
						r_A <= std_logic_vector(unsigned(r_A) + 1);
						r_wait_d_stb <= '0';
					else
						r_wait_d_stb <= '1';
					end if;
				end if;
			else
				r_tx_mas <= (others => '0');
				r_wait_d_stb <= '0';
			end if;
		end if;
	end process;

	p_rx:process(fb_syscon_i)
	variable i:natural;
	begin
		if fb_syscon_i.rst = '1' then
			r_rx_mas <= (others => '1');
			r_D_rd <= (others => '1');
			r_rdy <= '0';
			r_ack <= '0';
			r_ack_lane <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
			if r_cyc = '0' and cyc_i = '1' then
				r_rx_mas <= (others => '1');
				r_rdy <= '0';
				r_ack <= '0';
				r_ack_lane <= (others => '0');
			elsif r_cyc = '1' and cyc_i = '1' then
				if fb_con_p2c_i.ack then
					for i in 0 to G_BYTELANES-1 loop
						if i_rx_cur(i) = '1' then
							r_d_Rd(((i+1)*8)-1 downto (i*8)) <= fb_con_p2c_i.D_rd;
						end if;
					end loop;
					r_rx_mas <= r_rx_mas and not i_rx_cur;
					r_ack_lane <= r_ack_lane or i_rx_cur;
					if or_reduce(lane_req_i and r_rx_mas and not i_rx_cur) = '0' then
						r_ack <= '1';
					end if;
				end if;

				if fb_con_p2c_i.rdy = '1' and or_reduce(lane_req_i and r_rx_mas and not i_rx_cur) = '0' and r_cyc = '1' then
					r_rdy <= '1';
				end if;
			else
				r_rx_mas <= (others => '0');
				r_rdy <= '0';
				r_ack <= '0';
				r_ack_lane <= (others => '0');
			end if;
		end if;
	end process;

	fb_con_c2p_o.cyc <= r_cyc;
	fb_con_c2p_o.A_stb <= or_reduce(i_tx_cur);
	fb_con_c2p_o.A <= r_A;
	fb_con_c2p_o.we <= we_i;
	fb_con_c2p_o.rdy_ctdn <= rdy_ctdn_i;
	fb_con_c2p_o.D_wr_stb <= or_reduce(i_tx_cur and D_wr_stb_i);

	p_d_wr_mux:process(D_wr_i, i_tx_cur)
	variable i:natural;
	begin
		fb_con_c2p_o.D_Wr <= (others => '-');
		for i in 0 to G_BYTELANES -1 loop
			if i_tx_cur(i) = '1' then
				fb_con_c2p_o.D_Wr <= D_wr_i((8*(i+1))-1 downto 8*i);
			end if;
		end loop;
	end process;

	rdy_o			<= r_rdy;
	ack_lane_o	<= r_ack_lane;
	ack_o			<= r_ack;
	D_rd_o		<= r_d_Rd;

	act_lane_o  <= i_tx_cur;

end rtl;

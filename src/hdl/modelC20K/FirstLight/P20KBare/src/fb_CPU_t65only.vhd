-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2023 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:    	25/04/2023
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component, cut down
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for just the T65 core
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--		This component provides a fishbone master wrapper around the T65 core. 
--
----------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.fb_CPU_pack.all;
use work.board_config_pack.all;

entity fb_cpu_t65only is
	generic (
		G_NMI_META_LEVELS					: natural := 5;
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural
	);
	port(

		-- configuration

		-- direct CPU control signals from system
		nmi_n_i									: in	std_logic;
		irq_n_i									: in	std_logic;

		-- fishbone signals
		fb_syscon_i								: in	fb_syscon_t;
		fb_c2p_o									: out fb_con_o_per_i_t;
		fb_p2c_i									: in	fb_con_i_per_o_t;

		-- chipset control signals
		cpu_halt_i								: in  std_logic
	);
end fb_cpu_t65only;

architecture rtl of fb_cpu_t65only is


	component fb_cpu_t65 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;										-- fast clock speed in mhz						
		CLKEN_DLY_MAX						: natural 	:= 2								-- used to time latching of address etc signals			
	);
	port(
		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		fb_syscon_i								: in	fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i

	);
	end component;

	signal i_wrap_D_rd				: std_logic_vector(8*C_CPU_BYTELANES-1 downto 0);

	signal r_nmi				: std_logic;

	signal r_nmi_meta			: std_logic_vector(G_NMI_META_LEVELS-1 downto 0);

	signal i_wrap_o_cur_act			: t_cpu_wrap_o;											-- selected wrap_o signal hard OR soft
	signal i_wrap_i					: t_cpu_wrap_i;

	signal i_fb_c2p_log			: fb_con_o_per_i_t;
	signal i_fb_p2c_log			: fb_con_i_per_o_t;

	signal i_fb_c2p_extra_instr_fetch : std_logic;

begin


	-- ================================================================================================ --
	-- NMI registration 
	-- ================================================================================================ --

	-- nmi was unreliable when testing DFS/ADFS, try de-gltiching
	p_nmi_meta:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_nmi_meta <= (others => '1');
			r_nmi <= '1';
		elsif rising_edge(fb_syscon_i.clk) then
			r_nmi_meta <= nmi_n_i & r_nmi_meta(G_NMI_META_LEVELS-1 downto 1);
			if or_reduce(r_nmi_meta) = '0' then
				r_nmi <= '0';
			elsif and_reduce(r_nmi_meta) = '1' then
				r_nmi <= '1';
			end if;
		end if;
	end process;


	-- ================================================================================================ --
	-- Multibyte burst controller
	-- ================================================================================================ --


	e_burst:entity work.fb_cpu_con_burst
	generic map (
		SIM 				=> SIM,
		G_BYTELANES 	=> C_CPU_BYTELANES
		)
	port map (
		
		BE_i					=> i_wrap_o_cur_act.BE,
		cyc_i					=> i_wrap_o_cur_act.cyc,
		A_i					=> i_wrap_o_cur_act.A,
		we_i					=> i_wrap_o_cur_act.we,
		lane_req_i			=> i_wrap_o_cur_act.lane_req,
		D_wr_i				=> i_wrap_o_cur_act.D_wr,
		D_wr_stb_i			=> i_wrap_o_cur_act.D_wr_stb,
		rdy_ctdn_i			=> i_wrap_o_cur_act.rdy_ctdn,
		instr_fetch_i		=> i_wrap_o_cur_act.instr_fetch,
	
		-- return to wrappers
	
		rdy_o					=> i_wrap_i.rdy,
		act_lane_o			=> i_wrap_i.act_lane,
		ack_lane_o			=> i_wrap_i.ack_lane,
		ack_o					=> i_wrap_i.ack,
		D_rd_o				=> i_wrap_i.D_rd,
	
		-- fishbone byte wide controller interface
	
		fb_syscon_i			=> fb_syscon_i,
	
		fb_con_c2p_o		=> i_fb_c2p_log,
		fb_con_p2c_i		=> i_fb_p2c_log,

		fb_con_c2pinstr_fetch_o		=> i_fb_c2p_extra_instr_fetch

	
	);
	

	-- ================================================================================================ --
	-- log2phys and VIA throttle stage
	-- ================================================================================================ --

	e_log:entity work.fb_cpu_log2phys_simple16
	generic map (
		SIM			=> SIM,
		CLOCKSPEED	=> CLOCKSPEED
	)
	port map(

		fb_syscon_i								=> fb_syscon_i,

		-- controller interface from the cpu
		fb_con_c2p_i							=> i_fb_c2p_log,
		fb_con_p2c_o							=> i_fb_p2c_log,

		fb_per_c2p_o							=> fb_c2p_o,
		fb_per_p2c_i							=> fb_p2c_i

	);

	


	-- ================================================================================================ --
	-- Instantiate CPU wrappers 
	-- ================================================================================================ --


	e_t65:fb_cpu_t65
	generic map (
		SIM									=> SIM,
		CLOCKSPEED							=> CLOCKSPEED
	)
	port map (

		-- configuration
		cpu_en_i									=> '1',
		fb_syscon_i								=> fb_syscon_i,

		wrap_o									=> i_wrap_o_cur_act,
		wrap_i									=> i_wrap_i

	);


	-- ================================================================================================ --
	-- extra Wrapper to/from CPU handlers
	-- ================================================================================================ --

	i_wrap_i.cpu_halt 					<= cpu_halt_i;

	i_wrap_i.noice_debug_nmi_n 		<= '1';
	i_wrap_i.noice_debug_shadow 		<= '0';
	i_wrap_i.noice_debug_inhibit_cpu <= '0';
	i_wrap_i.throttle_cpu_2MHz 		<= '0';
	i_wrap_i.cpu_2MHz_phi2_clken 		<= '1';		-- required to force throttle off in process p_throttle
	i_wrap_i.nmi_n 						<= r_nmi;
	i_wrap_i.irq_n 						<= irq_n_i;


end rtl;

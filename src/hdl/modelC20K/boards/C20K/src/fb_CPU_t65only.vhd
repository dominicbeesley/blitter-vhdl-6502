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

library work;
use work.fishbone.all;
use work.common.all;
use work.fb_CPU_pack.all;
use work.board_config_pack.all;
use work.fb_sys_pack.all;

entity fb_cpu_t65only is
	generic (
		G_NMI_META_LEVELS					: natural := 5;
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural
	);
	port(

		-- configuration

		cfg_sys_type_i							: in sys_type;
		cfg_swram_enable_i					: in std_logic;
		cfg_mosram_i							: in std_logic;
		cfg_swromx_i							: in std_logic;

		-- cpu throttle
		throttle_cpu_2MHz_i					: in std_logic;
		cpu_2MHz_phi2_clken_i				: in std_logic;
		rom_throttle_map_i					: in std_logic_vector(15 downto 0);
		rom_autohazel_map_i					: in std_logic_vector(15 downto 0);	

		-- extra memory map control signals
		sys_ROMPG_i								: in		std_logic_vector(7 downto 0);
		JIM_page_i								: in  	std_logic_vector(15 downto 0);
		JIM_en_i									: in		std_logic;		-- jim enable, this is handled here 

		-- memctl signals
		swmos_shadow_i							: in	std_logic;		-- shadow mos from SWRAM slot #8
		turbo_lo_mask_i						: in 	std_logic_vector(7 downto 0);

		-- noice debugger signals to cpu
		noice_debug_nmi_n_i					: in	std_logic;		-- debugger is forcing a cpu NMI
		noice_debug_shadow_i					: in	std_logic;		-- debugger memory MOS map is active (overrides shadow_mos)
		noice_debug_inhibit_cpu_i			: in	std_logic;		-- during a 5C op code, inhibit address / data to avoid
																				-- spurious memory accesses
		-- noice debugger signals from cpu
		noice_debug_5c_o						: out	std_logic;		-- A 5C instruction is being fetched (qualify with clken below)
		noice_debug_cpu_clken_o				: out	std_logic;		-- clken and cpu rdy
		noice_debug_A0_tgl_o					: out	std_logic;		-- 1 when current A0 is different to previous fetched
		noice_debug_opfetch_o				: out	std_logic;		-- this cycle is an opcode fetch

		-- direct CPU control signals from system
		nmi_n_i									: in	std_logic;
		irq_n_i									: in	std_logic;

		-- fishbone signals
		fb_syscon_i								: in	fb_syscon_t;
		fb_c2p_o									: out fb_con_o_per_i_t;
		fb_p2c_i									: in	fb_con_i_per_o_t;

		-- chipset control signals
		cpu_halt_i								: in  std_logic;

		-- debug
		debug_cpu_instr_A						: out std_logic_vector(23 downto 0)

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
	signal i_throttle_act		: std_logic;

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
			if my_or_reduce(r_nmi_meta) = '0' then
				r_nmi <= '0';
			elsif my_and_reduce(r_nmi_meta) = '1' then
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
	
	p_debug_instr_a:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			if i_fb_c2p_extra_instr_fetch = '1' and i_fb_c2p_log.A_stb = '1' and i_fb_c2p_log.cyc = '1' then
				debug_cpu_instr_A <= i_fb_c2p_log.A; 
			end if;
		end if;
	end process;

	-- ================================================================================================ --
	-- log2phys and VIA throttle stage
	-- ================================================================================================ --

	e_log:entity work.fb_cpu_log2phys
	generic map (
		SIM			=> SIM,
		CLOCKSPEED	=> CLOCKSPEED,
		G_MK3			=> false,
		G_C20K		=> true, 
		G_IORB_BLOCK=> G_IORB_BLOCK
	)
	port map(

		fb_syscon_i								=> fb_syscon_i,

		-- controller interface from the cpu
		fb_con_c2p_i							=> i_fb_c2p_log,
		fb_con_p2c_o							=> i_fb_p2c_log,
		fb_con_extra_instr_fetch_i			=> i_fb_c2p_extra_instr_fetch,

		fb_per_c2p_o							=> fb_c2p_o,
		fb_per_p2c_i							=> fb_p2c_i,

		-- per cpu config
		cfg_sys_via_block_i					=> '1',					-- TODO: RiscV etc
		cfg_t65_i								=> '1',					-- TODO: RiscV etc

		-- system type
		cfg_sys_type_i							=> cfg_sys_type_i,
		cfg_swram_enable_i					=> cfg_swram_enable_i,
		cfg_mosram_i							=> cfg_mosram_i,
		cfg_swromx_i							=> cfg_swromx_i,

		-- extra memory map control signals
		sys_ROMPG_i								=> sys_ROMPG_i,
		JIM_page_i								=> JIM_page_i,
		jim_en_i									=> jim_en_i,

		-- SYS VIA slowdown enable
		sys_via_blocker_en_i					=> '0',					-- TODO: Other CPUs

		-- memctl signals
		swmos_shadow_i							=> swmos_shadow_i,		-- TODO: get from memctl in some way
		turbo_lo_mask_i						=> turbo_lo_mask_i,
		rom_autohazel_map_i					=> rom_autohazel_map_i,

		mos_throttle_i							=> not swmos_shadow_i,
		throttle_all_i							=> throttle_cpu_2MHz_i,
		rom_throttle_map_i					=> rom_throttle_map_i,
		throttle_act_o							=> i_throttle_act,

		-- noice signals
		noice_debug_shadow_i					=> noice_debug_shadow_i,


		-- debug signals
		debug_SYS_VIA_block_o				=> open,




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

	i_wrap_i.noice_debug_nmi_n 		<= noice_debug_nmi_n_i;
	i_wrap_i.noice_debug_shadow 		<= noice_debug_shadow_i;
	i_wrap_i.noice_debug_inhibit_cpu <= noice_debug_inhibit_cpu_i;
	i_wrap_i.throttle_cpu_2MHz 		<= throttle_cpu_2MHz_i or i_throttle_act;
	i_wrap_i.cpu_2MHz_phi2_clken 		<= cpu_2MHz_phi2_clken_i;
	i_wrap_i.nmi_n 						<= r_nmi;
	i_wrap_i.irq_n 						<= irq_n_i;

	-- noice signals from current CPU

	noice_debug_5c_o						<= i_wrap_o_cur_act.noice_debug_5c;
	noice_debug_cpu_clken_o				<= i_wrap_o_cur_act.noice_debug_cpu_clken;
	noice_debug_A0_tgl_o					<= i_wrap_o_cur_act.noice_debug_A0_tgl;
	noice_debug_opfetch_o				<= i_wrap_o_cur_act.noice_debug_opfetch;


end rtl;

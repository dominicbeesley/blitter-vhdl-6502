-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2025 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:    	25/04/2025
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component, cut down
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for just the T65 core (and RISC-V)
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--		This component provides a fishbone master wrapper around the T65, RISC-V cores. 
--
----------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.board_config_pack.all;
use work.fb_CPU_pack.all;
use work.fb_SYS_pack.all;

entity fb_cpu_t65only is
	generic (
		G_NMI_META_LEVELS					: natural := 5;
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;
		G_INCL_CPU_T65						: boolean := false;
		G_INCL_CPU_PICORV32				: boolean := false;
		G_INCL_CPU_HAZARD3				: boolean := false
	);
	port(

		-- configuration

		cfg_cpu_use_t65_i						: in std_logic;
		cfg_cpu_use_riscv_i					: in std_logic;
		cfg_sys_type_i							: in sys_type;
		cfg_swram_enable_i					: in std_logic;
		cfg_mosram_i							: in std_logic;
		cfg_swromx_i							: in std_logic;

		-- cpu throttle
		throttle_cpu_2MHz_i					: in std_logic;
		cpu_2MHz_phi2_clken_i				: in std_logic;
		rom_throttle_map_i					: in std_logic_vector(15 downto 0);
		rom_autohazel_map_i					: in std_logic_vector(15 downto 0);	
		throttle_act_o							: out std_logic;

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

		-- optional clocks for riscv / hazard3
		clk_32m_i								: in std_logic;	

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

	component fb_cpu_picorv32 is
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
		wrap_i									: in t_cpu_wrap_i;

		-- cpu clock

		clk_32M_i								: in std_logic

	);
	end component;

	component fb_cpu_hazard3 is
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
		wrap_i									: in t_cpu_wrap_i;

		-- cpu clock

		clk_32m_i								: in std_logic

	);
	end component;

function B2OZ(b:boolean) return natural is 
	begin
		if b then
			return 1;
		else
			return 0;
		end if;
	end function;

	constant C_IX_CPU_T65						: natural := 0;
	constant C_IX_CPU_RISCV						: natural := C_IX_CPU_T65 + B2OZ(G_INCL_CPU_T65);
	constant C_IX_CPU_COUNT						: natural := C_IX_CPU_RISCV + 1; -- always add 1 at end though it might not be actually used! -- B2OZ(G_INCL_CPU_PICORV32 OR G_INCL_CPU_HAZARD3)
	signal i_wrap_o_all 				: t_cpu_wrap_o_arr(0 to C_IX_CPU_COUNT-1);		-- all wrap_o signals
	signal i_wrap_o_cur_act			: t_cpu_wrap_o;											-- selected wrap_o signal hard OR soft
	signal i_wrap_i					: t_cpu_wrap_i;
	-----------------------------------------------------------------------------
	-- configuration registers setup at boot time
	-----------------------------------------------------------------------------
	
	signal r_cpu_run_ix_act		: natural range 0 to C_IX_CPU_COUNT-1;				-- index of currently selected hard OR soft cpu


	-----------------------------------------------------------------------------
	-- fishbone before log2phys wrapper
	-----------------------------------------------------------------------------
	signal i_fb_c2p_log			: fb_con_o_per_i_t;
	signal i_fb_p2c_log			: fb_con_i_per_o_t;
	signal i_fb_c2p_extra_instr_fetch : std_logic;		-- extra signal to qualify a cycle as an instruction fetch

	-----------------------------------------------------------------------------
	-- cpu mapping signals
	-----------------------------------------------------------------------------

	-- wrapper enable signals

	signal r_cpu_en_t65 : std_logic;
	signal r_cpu_en_riscv : std_logic;
	signal i_wrap_D_rd				: std_logic_vector(8*C_CPU_BYTELANES-1 downto 0);

	signal r_nmi				: std_logic;

	signal r_nmi_meta			: std_logic_vector(G_NMI_META_LEVELS-1 downto 0);


	signal i_throttle_act		: std_logic;

	signal r_do_sys_via_block		: std_logic;		-- per cpu enable
begin
	-- ================================================================================================ --
	-- BOOT TIME CONFIGURATION
	-- ================================================================================================ --

	-- PORTEFG nOE's selected in top level p_EFG_en process
	p_config:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then

			if fb_syscon_i.prerun(2) = '1' then


				r_cpu_en_t65 <= '0';
				r_cpu_en_riscv <= '0';
				r_do_sys_via_block <= '0';	

				r_cpu_run_ix_act <= C_IX_CPU_T65;

				-- multiplex/enable active cpu wrapper
				if cfg_cpu_use_t65_i = '1' then
					r_do_sys_via_block <= '1';	
					r_cpu_en_t65 <= '1';
				elsif cfg_cpu_use_riscv_i = '1' and (G_INCL_CPU_PICORV32 or G_INCL_CPU_HAZARD3) then
					r_do_sys_via_block <= '0';	
					r_cpu_en_riscv <= '1';				
					r_cpu_run_ix_act <= C_IX_CPU_RISCV;
				end if;
		  	end if;
		end if;
	end process;


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
		G_C20K		=> true
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
		cfg_t65_i								=> r_cpu_en_t65,
		cfg_sys_via_block_i					=> r_do_sys_via_block,

		-- system type
		cfg_sys_type_i							=> cfg_sys_type_i,
		cfg_swram_enable_i					=> cfg_swram_enable_i,
		cfg_mosram_i							=> cfg_mosram_i,
		cfg_swromx_i							=> cfg_swromx_i,

		-- extra memory map control signals
		sys_ROMPG_i								=> sys_ROMPG_i,
		JIM_page_i								=> JIM_page_i,
		jim_en_i									=> jim_en_i,

		-- memctl signals
		swmos_shadow_i							=> swmos_shadow_i,		-- TODO: get from memctl in some way
		turbo_lo_mask_i						=> turbo_lo_mask_i,
		rom_autohazel_map_i					=> rom_autohazel_map_i,

		mos_throttle_i							=> not swmos_shadow_i,
		throttle_all_i							=> throttle_cpu_2MHz_i,
		rom_throttle_map_i					=> rom_throttle_map_i,
		throttle_act_o							=> i_throttle_act,

		-- noice signals
		noice_debug_shadow_i					=> noice_debug_shadow_i
	);

	


	-- ================================================================================================ --
	-- Instantiate CPU wrappers 
	-- ================================================================================================ --


gt65: IF G_INCL_CPU_T65 GENERATE
	e_t65:fb_cpu_t65
	generic map (
		SIM									=> SIM,
		CLOCKSPEED							=> CLOCKSPEED
	)
	port map (

		-- configuration
		cpu_en_i									=> r_cpu_en_t65,
		fb_syscon_i								=> fb_syscon_i,

		wrap_o									=> i_wrap_o_all(C_IX_CPU_T65),
		wrap_i									=> i_wrap_i

	);

END GENERATE;

assert G_INCL_CPU_PICORV32 = false or G_INCL_CPU_HAZARD3 = false report "Can only include one of PICORV32 or HAZARD3" severity error;

gpicorv32: IF G_INCL_CPU_PICORV32 GENERATE
	e_picorv32:fb_cpu_picorv32
	generic map (
		SIM									=> SIM,
		CLOCKSPEED							=> CLOCKSPEED
	)
	port map (

		-- configuration
		cpu_en_i									=> r_cpu_en_riscv,
		fb_syscon_i								=> fb_syscon_i,

		wrap_o									=> i_wrap_o_all(C_IX_CPU_RISCV),
		wrap_i									=> i_wrap_i,

		clk_32m_i								=> clk_32m_i

	);

END GENERATE;

ghazard3: IF G_INCL_CPU_HAZARD3 GENERATE
	e_hazard3:fb_cpu_hazard3
	generic map (
		SIM									=> SIM,
		CLOCKSPEED							=> CLOCKSPEED
	)
	port map (

		-- configuration
		cpu_en_i									=> r_cpu_en_riscv,
		fb_syscon_i								=> fb_syscon_i,

		wrap_o									=> i_wrap_o_all(C_IX_CPU_RISCV),
		wrap_i									=> i_wrap_i,

		clk_32m_i								=> clk_32m_i

	);

END GENERATE;

	-- ================================================================================================ --
	-- multiplex wrapper signals
	-- ================================================================================================ --

	i_wrap_o_cur_act			<= i_wrap_o_all(r_cpu_run_ix_act);	


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

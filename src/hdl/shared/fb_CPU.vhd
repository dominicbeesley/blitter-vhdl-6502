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
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the CPU sockets on the blitter board
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--		This component provides a fishbone master wrapper around the CPU socket _and_ the T65
--	core. The actual device in use is selected by the cfg_t65_i and cfg_hard_cpu_type_i input signals.
--		Each type of processor is split out into its own wrapper named fb_CPU_<cpu name>  - these are not
-- fishbone wrappers per-se but instead provide a simplified set of signals to enable the state machine
-- to direct the fishbone master interface. This was done to simplify development and may well need to 
-- be rationalised to better utilize resources.
--
----------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.board_config_pack.all;
use work.fb_CPU_pack.all;
use work.fb_CPU_exp_pack.all;
use work.fb_SYS_pack.all;

entity fb_cpu is
	generic (
		G_NMI_META_LEVELS					: natural := 5;
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;										-- fast clock speed in mhz						
		G_INCL_CPU_T65						: boolean := false;
		G_INCL_CPU_65C02					: boolean := false;
		G_INCL_CPU_6800					: boolean := false;
		G_INCL_CPU_80188					: boolean := false;
		G_INCL_CPU_65816					: boolean := false;
		G_INCL_CPU_6x09					: boolean := false;
		G_INCL_CPU_Z80						: boolean := false;
		G_INCL_CPU_680x0					: boolean := false;
		G_INCL_CPU_68008					: boolean := false;
		G_INCL_CPU_ARM2					: boolean := false;
		G_MK3									: boolean := false
	);
	port(

		-- configuration

		cfg_cpu_type_i							: in cpu_type;
		cfg_cpu_use_t65_i						: in std_logic;
		cfg_cpu_speed_opt_i					: in cpu_speed_opt;
		cfg_sys_type_i							: in sys_type;
		cfg_swram_enable_i					: in std_logic;
		cfg_mosram_i							: in std_logic;
		cfg_swromx_i							: in std_logic;


		-- cpu throttle
		throttle_cpu_2MHz_i					: in std_logic;
		cpu_2MHz_phi2_clken_i				: in std_logic;


		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in  t_cpu_wrap_exp_i;

		hard_cpu_en_o							: out std_logic;

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

		-- cpu specific signals

		boot_65816_i							: in 	std_logic;

		-- temporary debug signals
		debug_wrap_cyc_o						: out std_logic;

		debug_65816_vma_o						: out std_logic;

		debug_SYS_VIA_block_o				: out std_logic;

		debug_80188_state_o					: out std_logic_vector(2 downto 0);
		debug_80188_ale_o						: out std_logic;

		debug_65816_addr_meta_o				: out std_logic

	);
end fb_cpu;

architecture rtl of fb_cpu is


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

	component fb_cpu_6x09 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		cpu_speed_opt_i						: in cpu_speed_opt;

		fb_syscon_i								: in	fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

		-- CPU expansion signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i


	);
	end component;

	component fb_cpu_sbc09 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		cpu_speed_opt_i						: in cpu_speed_opt;

		fb_syscon_i								: in	fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

		-- CPU expansion signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i


	);
	end component;

	component fb_cpu_z80 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		fb_syscon_i								: in	fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

		-- CPU expansion signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i;

		-- special m68k signals
		JIM_en_i									: in		std_logic

	);
	end component;

	component fb_cpu_68008 is
	generic (
		CLOCKSPEED							: positive := 128;
		SIM									: boolean := false
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		fb_syscon_i								: in	fb_syscon_t;
		cfg_mosram_i							: in std_logic;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

		-- CPU expansion signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i;

		-- special m68k signals

		JIM_en_i									: in		std_logic

	);
	end component;


	component fb_cpu_680x0 is
	generic (
		CLOCKSPEED							: positive := 128;
		SIM									: boolean := false
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		fb_syscon_i								: in	fb_syscon_t;
		cfg_mosram_i							: in std_logic;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

		-- CPU expansion signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i;

		-- special m68k signals

		JIM_en_i									: in		std_logic

	);
	end component;

	component fb_cpu_65816 is
		generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: positive
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		fb_syscon_i								: in	fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

		-- CPU expansion signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i;

		-- 65816 specific signals

		boot_65816_i							: in		std_logic;

		debug_vma_o								: out		std_logic;

		debug_addr_meta_o						: out		std_logic

	);
	end component;

	component fb_cpu_65c02 is
		generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		cfg_cpu_speed_i						: in cpu_speed_opt;			
		fb_syscon_i								: in fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

		-- CPU expansion signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i

	);		
	end component;

	component fb_cpu_6800 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;
		G_BYTELANES							: positive	:= 1
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;							-- 1 when this cpu is the current one

		fb_syscon_i								: in	fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

		-- CPU expansion signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i

	);
	end component;

	component fb_cpu_80188 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;
		G_BYTELANES							: positive	:= 1
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;							-- 1 when this cpu is the current one

		fb_syscon_i								: in	fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

		-- CPU expansion signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i;

		-- debug signals

		debug_80188_state_o					: out std_logic_vector(2 downto 0);
		debug_80188_ale_o						: out std_logic

	);
	end component;

	component fb_cpu_arm2 is
	generic (
		CLOCKSPEED							: positive := 128;
		SIM									: boolean := false
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		fb_syscon_i								: in	fb_syscon_t;
		cfg_mosram_i							: in std_logic;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

		-- CPU expansion signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i;

		-- special m68k signals

		JIM_en_i									: in		std_logic

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
	constant C_IX_CPU_65C02						: natural := C_IX_CPU_T65 + B2OZ(G_INCL_CPU_T65);
	constant C_IX_CPU_6800						: natural := C_IX_CPU_65C02 + B2OZ(G_INCL_CPU_65C02);
	constant C_IX_CPU_80188						: natural := C_IX_CPU_6800 + B2OZ(G_INCL_CPU_6800);
	constant C_IX_CPU_65816						: natural := C_IX_CPU_80188 + B2OZ(G_INCL_CPU_80188);
	constant C_IX_CPU_6x09						: natural := C_IX_CPU_65816 + B2OZ(G_INCL_CPU_65816);
	constant C_IX_CPU_Z80						: natural := C_IX_CPU_6x09 + B2OZ(G_INCL_CPU_6x09);
	constant C_IX_CPU_680X0						: natural := C_IX_CPU_Z80 + B2OZ(G_INCL_CPU_Z80);
	constant C_IX_CPU_68008						: natural := C_IX_CPU_680X0 + B2OZ(G_INCL_CPU_680X0);
	constant C_IX_CPU_ARM2						: natural := C_IX_CPU_68008 + B2OZ(G_INCL_CPU_68008);
	constant C_IX_CPU_SBC09						: natural := C_IX_CPU_ARM2 + B2OZ(G_INCL_CPU_ARM2);
	constant C_IX_CPU_COUNT						: natural := C_IX_CPU_SBC09 + 1; -- always add 1 at end though it might not be actually used!

	-- NOTE: when we multiplex signals out to the expansion headers even when t65 is active
	-- we should route in/out any hard cpu signals to allow the wrappers to set sensible
	-- signal directions and levels to hold the hard cpu in low-power or reset state

	signal i_wrap_o_all 				: t_cpu_wrap_o_arr(0 to C_IX_CPU_COUNT-1);		-- all wrap_o signals
	signal i_wrap_exp_o_all 		: t_cpu_wrap_exp_o_arr(0 to C_IX_CPU_COUNT-1);	-- all wrap_exp_o signals
	signal i_wrap_o_cur_act			: t_cpu_wrap_o;											-- selected wrap_o signal hard OR soft
	signal i_wrap_exp_o_cur_hard	: t_cpu_wrap_exp_o;										-- selected wrap_exp_o signal hard only
	signal i_wrap_i					: t_cpu_wrap_i;
	signal i_wrap_exp_i				: t_cpu_wrap_exp_i;

	-----------------------------------------------------------------------------
	-- configuration registers setup at boot time
	-----------------------------------------------------------------------------
	
	signal r_cpu_run_ix_hard	: natural range 0 to C_IX_CPU_COUNT-1;				-- index of currently selected hard cpu
	signal r_cpu_run_ix_act		: natural range 0 to C_IX_CPU_COUNT-1;				-- index of currently selected hard OR soft cpu


	signal i_fb_c2p_log			: fb_con_o_per_i_t;
	signal i_fb_p2c_log			: fb_con_i_per_o_t;

	-----------------------------------------------------------------------------
	-- cpu mapping signals
	-----------------------------------------------------------------------------

	-- wrapper enable signals

	signal r_cpu_en_t65 : std_logic;
	signal r_cpu_en_6x09 : std_logic;
	signal r_cpu_en_sbc09 : std_logic;
	signal r_cpu_en_z80 : std_logic;
	signal r_cpu_en_680x0 : std_logic;
	signal r_cpu_en_68008 : std_logic;
	signal r_cpu_en_65c02 : std_logic;
	signal r_cpu_en_6800 : std_logic;
	signal r_cpu_en_80188 : std_logic;
	signal r_cpu_en_65816 : std_logic;
	signal r_cpu_en_arm2 : std_logic;


	signal i_wrap_D_rd				: std_logic_vector(8*C_CPU_BYTELANES-1 downto 0);

	signal r_hard_cpu_en				: 	std_logic;


	signal r_nmi				: std_logic;

	signal r_nmi_meta			: std_logic_vector(G_NMI_META_LEVELS-1 downto 0);

	signal r_do_sys_via_block		: std_logic;
begin

	-- ================================================================================================ --
	-- BOOT TIME CONFIGURATION
	-- ================================================================================================ --

	hard_cpu_en_o <= r_hard_cpu_en;

	-- PORTEFG nOE's selected in top level p_EFG_en process
	p_config:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then

			if fb_syscon_i.prerun(2) = '1' then

				r_hard_cpu_en <= '0';

				r_cpu_en_t65 <= '0';
				r_cpu_en_6x09 <= '0';
				r_cpu_en_sbc09 <= '0';
				r_cpu_en_z80 <= '0';
				r_cpu_en_680x0 <= '0';
				r_cpu_en_68008 <= '0';
				r_cpu_en_65c02 <= '0';
				r_cpu_en_6800 <= '0';
				r_cpu_en_80188 <= '0';
				r_cpu_en_65816 <= '0';
				r_cpu_en_arm2 <= '0';

				r_do_sys_via_block <= '0';	

				r_cpu_run_ix_act <= C_IX_CPU_T65;
				r_cpu_run_ix_hard <= C_IX_CPU_T65; -- dummy value

				-- multiplex/enable active cpu wrapper
				if cfg_cpu_use_t65_i = '1' then
					r_do_sys_via_block <= '1';	
					r_cpu_en_t65 <= '1';
				else
					if cfg_cpu_type_i = CPU_65816 and G_INCL_CPU_65816 then
						r_cpu_run_ix_act <= C_IX_CPU_65816;
						r_do_sys_via_block <= '1';	
						r_cpu_en_65816 <= '1';
					elsif cfg_cpu_type_i = CPU_680x0 and G_INCL_CPU_680x0 then
						r_cpu_run_ix_act <= C_IX_CPU_680x0;
						r_cpu_en_680x0 <= '1';
					elsif cfg_cpu_type_i = CPU_68008 and G_INCL_CPU_68008 then
						r_cpu_run_ix_act <= C_IX_CPU_68008;
						r_cpu_en_68008 <= '1';
					elsif cfg_cpu_type_i = CPU_6800 and G_INCL_CPU_6800 then
						r_cpu_run_ix_act <= C_IX_CPU_6800;
						r_cpu_en_6800 <= '1';
					elsif cfg_cpu_type_i = CPU_6x09 and G_INCL_CPU_6x09 then
						r_cpu_run_ix_act <= C_IX_CPU_6x09;
						if cfg_cpu_speed_opt_i = CPUSPEED_6309_3_5 then
							r_do_sys_via_block <= '1';	
						end if;
						r_cpu_en_6x09 <= '1';
					elsif cfg_cpu_type_i = CPU_SBC09 and G_INCL_CPU_SBC09 then
						r_cpu_run_ix_act <= C_IX_CPU_SBC09;
						if cfg_cpu_speed_opt_i = CPUSPEED_6309_3_5 then
							r_do_sys_via_block <= '1';	
						end if;
						r_cpu_en_sbc09 <= '1';
					elsif cfg_cpu_type_i = CPU_65C02 and G_INCL_CPU_65C02 then
						r_cpu_run_ix_act <= C_IX_CPU_65C02;
						r_do_sys_via_block <= '1';	
						r_cpu_en_65c02 <= '1';
					elsif cfg_cpu_type_i = CPU_80188 and G_INCL_CPU_80188 then
						r_cpu_run_ix_act <= C_IX_CPU_80188;
						r_cpu_en_80188 <= '1';
					elsif cfg_cpu_type_i = CPU_Z80 and G_INCL_CPU_Z80 then
						r_cpu_run_ix_act <= C_IX_CPU_Z80;
						r_cpu_en_z80 <= '1';						
					elsif cfg_cpu_type_i = CPU_ARM2 and G_INCL_CPU_ARM2 then
						r_cpu_run_ix_act <= C_IX_CPU_ARM2;
						r_cpu_en_arm2 <= '1';						
					end if;
				end if;

				-- multiplex/enable current hard cpu expansion out
				if cfg_cpu_type_i = CPU_65816 and G_INCL_CPU_65816 then
					r_cpu_run_ix_hard <= C_IX_CPU_65816;
					r_hard_cpu_en <= '1';
				elsif cfg_cpu_type_i = CPU_680x0 and G_INCL_CPU_680x0 then
					r_cpu_run_ix_hard <= C_IX_CPU_680x0;
					r_hard_cpu_en <= '1';
				elsif cfg_cpu_type_i = CPU_68008 and G_INCL_CPU_68008 then
					r_cpu_run_ix_hard <= C_IX_CPU_68008;
					r_hard_cpu_en <= '1';
				elsif cfg_cpu_type_i = CPU_6800 and G_INCL_CPU_6800 then
					r_cpu_run_ix_hard <= C_IX_CPU_6800;
					r_hard_cpu_en <= '1';
				elsif cfg_cpu_type_i = CPU_6x09 and G_INCL_CPU_6x09 then
					r_cpu_run_ix_hard <= C_IX_CPU_6x09;
					r_hard_cpu_en <= '1';
				elsif cfg_cpu_type_i = CPU_SBC09 and G_INCL_CPU_SBC09 then
					r_cpu_run_ix_hard <= C_IX_CPU_SBC09;
					r_hard_cpu_en <= '1';
				elsif cfg_cpu_type_i = CPU_65C02 and G_INCL_CPU_65C02 then
					r_cpu_run_ix_hard <= C_IX_CPU_65C02;
					r_hard_cpu_en <= '1';
				elsif cfg_cpu_type_i = CPU_80188 and G_INCL_CPU_80188 then
					r_cpu_run_ix_hard <= C_IX_CPU_80188;
					r_hard_cpu_en <= '1';
				elsif cfg_cpu_type_i = CPU_Z80 and G_INCL_CPU_Z80 then
					r_cpu_run_ix_hard <= C_IX_CPU_Z80;
					r_hard_cpu_en <= '1';
				elsif cfg_cpu_type_i = CPU_ARM2 and G_INCL_CPU_ARM2 then
					r_cpu_run_ix_hard <= C_IX_CPU_ARM2;
					r_hard_cpu_en <= '1';
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
			if or_reduce(r_nmi_meta) = '0' then
				r_nmi <= '0';
			elsif and_reduce(r_nmi_meta) = '1' then
				r_nmi <= '1';
			end if;
		end if;
	end process;



	debug_wrap_cyc_o <= i_wrap_o_cur_act.cyc;
	
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
	
		-- return to wrappers
	
		rdy_o					=> i_wrap_i.rdy,
		act_lane_o			=> i_wrap_i.act_lane,
		ack_lane_o			=> i_wrap_i.ack_lane,
		ack_o					=> i_wrap_i.ack,
		D_rd_o				=> i_wrap_i.D_rd,
	
		-- fishbone byte wide controller interface
	
		fb_syscon_i			=> fb_syscon_i,
	
		fb_con_c2p_o		=> i_fb_c2p_log,
		fb_con_p2c_i		=> i_fb_p2c_log
	
	);
	

	-- ================================================================================================ --
	-- log2phys and VIA throttle stage
	-- ================================================================================================ --

	e_log:entity work.fb_cpu_log2phys
	generic map (
		SIM			=> SIM,
		CLOCKSPEED	=> CLOCKSPEED,
		G_MK3			=> G_MK3
	)
	port map(

		fb_syscon_i								=> fb_syscon_i,

		-- controller interface from the cpu
		fb_con_c2p_i							=> i_fb_c2p_log,
		fb_con_p2c_o							=> i_fb_p2c_log,

		fb_per_c2p_o							=> fb_c2p_o,
		fb_per_p2c_i							=> fb_p2c_i,

		-- per cpu config
		cfg_sys_via_block_i					=> r_do_sys_via_block,
		cfg_t65_i								=> r_cpu_en_t65,

		-- system type
		cfg_sys_type_i							=> cfg_sys_type_i,
		cfg_swram_enable_i					=> cfg_swram_enable_i,
		cfg_mosram_i							=> cfg_mosram_i,
		cfg_swromx_i							=> cfg_swromx_i,

		-- extra memory map control signals
		sys_ROMPG_i								=> sys_ROMPG_i,
		JIM_page_i								=> JIM_page_i,
		JIM_en_i									=> JIM_en_i,

		-- memctl signals
		swmos_shadow_i							=> swmos_shadow_i,
		turbo_lo_mask_i						=> turbo_lo_mask_i,

		-- noice signals
		noice_debug_shadow_i					=> noice_debug_shadow_i,

		-- debug
		debug_SYS_VIA_block_o				=> debug_SYS_VIA_block_o 				

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

g6x09:IF G_INCL_CPU_6x09 GENERATE
	e_wrap_6x09:fb_cpu_6x09
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_6x09,
		cpu_speed_opt_i						=> cfg_cpu_speed_opt_i,
		fb_syscon_i								=> fb_syscon_i,

		wrap_o									=> i_wrap_o_all(C_IX_CPU_6x09),
		wrap_i									=> i_wrap_i,

		wrap_exp_o								=> i_wrap_exp_o_all(C_IX_CPU_6x09),
		wrap_exp_i								=> i_wrap_exp_i
	);
END GENERATE;

gSBC09:IF G_INCL_CPU_SBC09 GENERATE
	e_wrap_SBC09:fb_cpu_SBC09
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_sbc09,
		cpu_speed_opt_i						=> cfg_cpu_speed_opt_i,
		fb_syscon_i								=> fb_syscon_i,

		wrap_o									=> i_wrap_o_all(C_IX_CPU_SBC09),
		wrap_i									=> i_wrap_i,

		wrap_exp_o								=> i_wrap_exp_o_all(C_IX_CPU_SBC09),
		wrap_exp_i								=> i_wrap_exp_i
	);
END GENERATE;

gz80: IF G_INCL_CPU_Z80 GENERATE
	e_wrap_z80:fb_cpu_z80
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_z80,
		fb_syscon_i								=> fb_syscon_i,

		wrap_o									=> i_wrap_o_all(C_IX_CPU_Z80),
		wrap_i									=> i_wrap_i,

		wrap_exp_o								=> i_wrap_exp_o_all(C_IX_CPU_Z80),
		wrap_exp_i								=> i_wrap_exp_i,

 		JIM_en_i									=> JIM_en_i

	);
END GENERATE;


g680x0:IF G_INCL_CPU_680x0 GENERATE
	e_wrap_680x0:fb_cpu_680x0
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_680x0,
		fb_syscon_i								=> fb_syscon_i,
		cfg_mosram_i							=> cfg_mosram_i,

		wrap_o									=> i_wrap_o_all(C_IX_CPU_680x0),
		wrap_i									=> i_wrap_i,

		wrap_exp_o								=> i_wrap_exp_o_all(C_IX_CPU_680x0),
		wrap_exp_i								=> i_wrap_exp_i,

 		JIM_en_i									=> JIM_en_i

	);
END GENERATE;

gARM2:IF G_INCL_CPU_ARM2 GENERATE
	e_wrap_arm2:fb_cpu_arm2
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_arm2,
		fb_syscon_i								=> fb_syscon_i,
		cfg_mosram_i							=> cfg_mosram_i,

		wrap_o									=> i_wrap_o_all(C_IX_CPU_ARM2),
		wrap_i									=> i_wrap_i,

		wrap_exp_o								=> i_wrap_exp_o_all(C_IX_CPU_ARM2),
		wrap_exp_i								=> i_wrap_exp_i,

 		JIM_en_i									=> JIM_en_i

	);
END GENERATE;


g68008:IF G_INCL_CPU_68008 GENERATE
	e_wrap_68008:fb_cpu_68008
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_68008,
		fb_syscon_i								=> fb_syscon_i,
		cfg_mosram_i							=> cfg_mosram_i,

		wrap_o									=> i_wrap_o_all(C_IX_CPU_68008),
		wrap_i									=> i_wrap_i,

		wrap_exp_o								=> i_wrap_exp_o_all(C_IX_CPU_68008),
		wrap_exp_i								=> i_wrap_exp_i,

 		JIM_en_i									=> JIM_en_i

	);
END GENERATE;

g65c02:IF G_INCL_CPU_65C02 GENERATE
	e_wrap_65c02:fb_cpu_65c02
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_65c02,
		cfg_cpu_speed_i						=> cfg_cpu_speed_opt_i,	
		fb_syscon_i								=> fb_syscon_i,

		wrap_o									=> i_wrap_o_all(C_IX_CPU_65C02),
		wrap_i									=> i_wrap_i,

		wrap_exp_o								=> i_wrap_exp_o_all(C_IX_CPU_65C02),
		wrap_exp_i								=> i_wrap_exp_i

	);
END GENERATE;

g6800:IF G_INCL_CPU_6800 GENERATE
	e_wrap_6800:fb_cpu_6800
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_6800,
		fb_syscon_i								=> fb_syscon_i,

		wrap_o									=> i_wrap_o_all(C_IX_CPU_6800),
		wrap_i									=> i_wrap_i,

		wrap_exp_o								=> i_wrap_exp_o_all(C_IX_CPU_6800),
		wrap_exp_i								=> i_wrap_exp_i

	);
END GENERATE;

g80188:IF G_INCL_CPU_80188 GENERATE
	e_wrap_80188:fb_cpu_80188
	generic map (
		SIM									=> SIM,
		CLOCKSPEED							=> CLOCKSPEED,
		G_BYTELANES							=> C_CPU_BYTELANES
	)
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_80188,
		fb_syscon_i								=> fb_syscon_i,

		wrap_o									=> i_wrap_o_all(C_IX_CPU_80188),
		wrap_i									=> i_wrap_i,

		wrap_exp_o								=> i_wrap_exp_o_all(C_IX_CPU_80188),
		wrap_exp_i								=> i_wrap_exp_i,

		-- debug signals

		debug_80188_state_o					=> debug_80188_state_o,
		debug_80188_ale_o						=> debug_80188_ale_o

	);
END GENERATE;



g65816:IF G_INCL_CPU_65816 GENERATE
	e_wrap_65816:fb_cpu_65816
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_65816,
		fb_syscon_i								=> fb_syscon_i,

		wrap_o									=> i_wrap_o_all(C_IX_CPU_65816),
		wrap_i									=> i_wrap_i,

		wrap_exp_o								=> i_wrap_exp_o_all(C_IX_CPU_65816),
		wrap_exp_i								=> i_wrap_exp_i,


		boot_65816_i							=> boot_65816_i,

		debug_vma_o								=> debug_65816_vma_o,
		debug_addr_meta_o						=> debug_65816_addr_meta_o
	);
END GENERATE;


	-- ================================================================================================ --
	-- Dummy exp out for when no external CPU is selected
	-- ================================================================================================ --

	G_DEF_EXP:IF G_INCL_CPU_T65 GENERATE
		i_wrap_exp_o_all(C_IX_CPU_T65) <= C_EXP_O_DUMMY;
	END GENERATE;

	-- ================================================================================================ --
	-- multiplex wrapper signals
	-- ================================================================================================ --

	i_wrap_o_cur_act			<= i_wrap_o_all(r_cpu_run_ix_act);	
	i_wrap_exp_o_cur_hard	<= i_wrap_exp_o_all(r_cpu_run_ix_hard);	


	-- ================================================================================================ --
	-- extra Wrapper to/from CPU handlers
	-- ================================================================================================ --

	i_wrap_i.cpu_halt 					<= cpu_halt_i;

	i_wrap_i.noice_debug_nmi_n 		<= noice_debug_nmi_n_i;
	i_wrap_i.noice_debug_shadow 		<= noice_debug_shadow_i;
	i_wrap_i.noice_debug_inhibit_cpu <= noice_debug_inhibit_cpu_i;
	i_wrap_i.throttle_cpu_2MHz 		<= throttle_cpu_2MHz_i;
	i_wrap_i.cpu_2MHz_phi2_clken 		<= cpu_2MHz_phi2_clken_i;
	i_wrap_i.nmi_n 						<= r_nmi;
	i_wrap_i.irq_n 						<= irq_n_i;


	-- ================================================================================================ --
	-- expansion header signals to/from current CPU
	-- ================================================================================================ --
	wrap_exp_o					<= i_wrap_exp_o_cur_hard;
	i_wrap_exp_i				<= wrap_exp_i;


	-- noice signals from current CPU

	noice_debug_5c_o			<= i_wrap_o_cur_act.noice_debug_5c;
	noice_debug_cpu_clken_o	<= i_wrap_o_cur_act.noice_debug_cpu_clken;
	noice_debug_A0_tgl_o		<= i_wrap_o_cur_act.noice_debug_A0_tgl;
	noice_debug_opfetch_o	<= i_wrap_o_cur_act.noice_debug_opfetch;


end rtl;

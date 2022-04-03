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
		G_INCL_CPU_68k						: boolean := false

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

		CPUSKT_D_io									: inout	std_logic_vector(7 downto 0);
		CPUSKT_A_i									: in		std_logic_vector(19 downto 0);

		CPUSKT_6EKEZnRD_i							: in		std_logic;		
		CPUSKT_C6nML9BUSYKnBGZnBUSACK_i		: in		std_logic;
		CPUSKT_RnWZnWR_i							: in		std_logic;
		CPUSKT_PHI16ABRT9BSKnDS_i				: in		std_logic;		-- 6ABRT is actually an output but pulled up on the board
		CPUSKT_PHI26VDAKFC0ZnMREQ_i			: in		std_logic;
		CPUSKT_SYNC6VPA9LICKFC2ZnM1_i			: in		std_logic;
		CPUSKT_VSS6VPA9BAKnAS_i					: in		std_logic;
		CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i		: in		std_logic;		-- nSO is actually an output but pulled up on the board
		CPUSKT_6BE9TSCKnVPA_o					: out		std_logic;
		CPUSKT_9Q_o									: out		std_logic;
		CPUSKT_KnBRZnBUSREQ_o					: out		std_logic;
		CPUSKT_PHI09EKZCLK_o						: out		std_logic;
		CPUSKT_RDY9KnHALTZnWAIT_o				: out		std_logic;
		CPUSKT_nIRQKnIPL1_o						: out		std_logic;
		CPUSKT_nNMIKnIPL02_o						: out		std_logic;
		CPUSKT_nRES_o								: out		std_logic;
		CPUSKT_9nFIRQLnDTACK_o					: out		std_logic;

		-- extra memory map control signals
		sys_ROMPG_i								: in		std_logic_vector(7 downto 0);
		JIM_page_i								: in  	std_logic_vector(15 downto 0);
		jim_en_i									: in		std_logic;		-- jim enable, this is handled here 

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
		debug_80188_ale_o						: out std_logic

	);
end fb_cpu;

architecture rtl of fb_cpu is

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
	constant C_IX_CPU_68k						: natural := C_IX_CPU_Z80 + B2OZ(G_INCL_CPU_Z80);
	constant C_IX_CPU_COUNT						: natural := C_IX_CPU_68k + B2OZ(G_INCL_CPU_68k);

	-- NOTE: when we multiplex signals out to the expansion headers even when t65 is active
	-- we should route in/out any hard cpu signals to allow the wrappers to set sensible
	-- signal directions and levels to hold the hard cpu in low-power or reset state

	signal i_wrap_o_all 			: t_cpu_wrap_o_arr(0 to C_IX_CPU_COUNT-1);		-- all wrap_o signals
	signal i_wrap_o_cur_act		: t_cpu_wrap_o;											-- selected wrap_o signal hard OR soft
	signal i_wrap_o_cur_hard	: t_cpu_wrap_o;											-- selected wrap_o signal hard only
	signal i_wrap_i				: t_cpu_wrap_i;

	-----------------------------------------------------------------------------
	-- configuration registers setup at boot time
	-----------------------------------------------------------------------------
	
	signal r_cpu_run_ix_hard	: natural range 0 to C_IX_CPU_COUNT-1;				-- index of currently selected hard cpu
	signal r_cpu_run_ix_act		: natural range 0 to C_IX_CPU_COUNT-1;				-- index of currently selected hard OR soft cpu


	-----------------------------------------------------------------------------
	-- cpu mapping signals
	-----------------------------------------------------------------------------



	-- wrapper enable signals

	signal r_cpu_en_t65 : std_logic;
	signal r_cpu_en_6x09 : std_logic;
	signal r_cpu_en_z80 : std_logic;
	signal r_cpu_en_68k : std_logic;
--	signal r_cpu_en_6502 : std_logic;
	signal r_cpu_en_65c02 : std_logic;
	signal r_cpu_en_6800 : std_logic;
	signal r_cpu_en_80188 : std_logic;
	signal r_cpu_en_65816 : std_logic;

	type state_t is (
		s_idle							-- waiting for address ready signal from cpu wrapper
		, s_block						-- SYS via was accessed recently and we're trying to access it again
		, s_waitack						
		);

	signal r_state				: state_t;

	signal r_D_rd				: std_logic_vector((C_CPU_BYTELANES*8)-1 downto 0);
	signal r_acked 			: std_logic_vector(C_CPU_BYTELANES-1 downto 0);

	signal r_wrap_cyc					: std_logic;
	signal i_wrap_phys_A				: std_logic_vector(23 downto 0);
	signal r_wrap_phys_A				: std_logic_vector(23 downto 0);
	signal r_wrap_we					: std_logic;
	signal r_wrap_D_WR_stb			: std_logic;
	signal r_wrap_D_WR				: std_logic_vector(7 downto 0);

	signal i_wrap_D_rd				: std_logic_vector(8*C_CPU_BYTELANES-1 downto 0);

	signal r_hard_cpu_en				: 	std_logic;


	signal r_nmi				: std_logic;

	signal r_nmi_meta			: std_logic_vector(G_NMI_META_LEVELS-1 downto 0);

	signal r_do_sys_via_block		: std_logic;
	signal i_SYS_VIA_block			: std_logic;
	signal r_sys_via_block_clken 	: std_logic;
begin

	-- ================================================================================================ --
	-- BOOT TIME CONFIGURATION
	-- ================================================================================================ --


	-- PORTEFG nOE's selected in top level p_EFG_en process
	p_config:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then

			if fb_syscon_i.prerun(2) = '1' then

				r_hard_cpu_en <= '0';

				r_cpu_en_t65 <= '0';
				r_cpu_en_6x09 <= '0';
				r_cpu_en_z80 <= '0';
				r_cpu_en_68k <= '0';
--				r_cpu_en_6502 <= '0';
				r_cpu_en_65c02 <= '0';
				r_cpu_en_6800 <= '0';
				r_cpu_en_80188 <= '0';
				r_cpu_en_65816 <= '0';

				r_do_sys_via_block <= '0';	

				r_cpu_run_ix_act <= C_IX_CPU_T65;
				r_cpu_run_ix_hard <= C_IX_CPU_T65; -- dummy value

				-- multiplex/enable active cpu wrapper
				if cfg_cpu_use_t65_i = '1' then
					r_do_sys_via_block <= '1';	
					r_cpu_en_t65 <= '1';
				else
					case cfg_cpu_type_i is
						when CPU_65816 =>
							r_cpu_run_ix_act <= C_IX_CPU_65816;
							r_do_sys_via_block <= '1';	
							r_cpu_en_65816 <= '1';
						when CPU_68K =>
							r_cpu_run_ix_act <= C_IX_CPU_68k;
							r_cpu_en_68k <= '1';
						when CPU_6800 =>
							r_cpu_run_ix_act <= C_IX_CPU_6800;
							r_cpu_en_6800 <= '1';
						when CPU_6x09 =>
							r_cpu_run_ix_act <= C_IX_CPU_6x09;
							r_cpu_en_6x09 <= '1';
						when CPU_80188 =>
							r_cpu_run_ix_act <= C_IX_CPU_80188;
							r_cpu_en_80188 <= '1';
						when others => 
							null;
					end case;
				end if;

				-- multiplex/enable current hard cpu expansion out
				case cfg_cpu_type_i is
					when CPU_65816 =>
						r_cpu_run_ix_hard <= C_IX_CPU_65816;
					r_hard_cpu_en <= '1';
					when CPU_68K =>
						r_cpu_run_ix_hard <= C_IX_CPU_68k;
						r_hard_cpu_en <= '1';
					when CPU_6800 =>
						r_cpu_run_ix_hard <= C_IX_CPU_6800;
						r_hard_cpu_en <= '1';
					when CPU_6x09 =>
						r_cpu_run_ix_hard <= C_IX_CPU_6x09;
						r_hard_cpu_en <= '1';
					when CPU_80188 =>
						r_cpu_run_ix_hard <= C_IX_CPU_80188;
						r_hard_cpu_en <= '1';
					when others => 
						null;
				end case;



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



	debug_wrap_cyc_o <= r_wrap_cyc;

	-- ================================================================================================ --
	-- BYTE lanes 
	-- ================================================================================================ --


	G_BL_RD:FOR I in C_CPU_BYTELANES-1 downto 0 GENERATE
		i_wrap_D_rd(7+I*8 downto I*8) <= fb_p2c_i.D_rd when r_acked(I) = '0' else 
															r_D_rd(7+I*8 downto I*8);
	END GENERATE;
	
	-- CAVEATS:
	--   the process below has been trimmed with the following expectations:
	--		1 when i_wrap cyc goes active it is a register in the wrapper
	--	   2 the logical address passed in i_wrap_o_cur.A_log is also registered in the wrapper
	--			the above two allow for the log->phys mapping in a single cycle

	-- ================================================================================================ --
	-- State Machine 
	-- ================================================================================================ --


	p_wrap_state:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_state <= s_idle;
			r_wrap_phys_A <= (others => '0');
			r_wrap_cyc <= '0';
			r_wrap_we <= '0';
			r_wrap_D_WR_stb <= '0';
			r_wrap_D_WR <= (others => '0');


			r_acked <= (others => '0');

			r_D_rd <= (others => '0');

		elsif rising_edge(fb_syscon_i.clk) then
			r_state <= r_state;
			r_sys_via_block_clken <= '0';

			if (or_reduce(i_wrap_o_cur_act.cyc) = '1' or r_wrap_cyc = '1') and i_wrap_o_cur_act.D_WR_stb = '1' then
				r_wrap_D_WR_stb <= '1';
				r_wrap_D_WR <= i_wrap_o_cur_act.D_WR;
			end if;

			case r_state is
				when s_idle =>
					if or_reduce(i_wrap_o_cur_act.cyc) = '1' then
						r_wrap_phys_A <= i_wrap_phys_A;
						r_wrap_we <= i_wrap_o_cur_act.we;

						if r_do_sys_via_block = '1' and i_SYS_VIA_block = '1' then
							r_state <= s_block;
						else
							r_state <= s_waitack;
							r_wrap_cyc <= '1';
						end if;
					end if;
				   r_acked <= not(i_wrap_o_cur_act.cyc);
				when s_block =>
					if i_SYS_VIA_block = '0' then
						r_state <= s_waitack;
						r_wrap_cyc <= '1';
					end if;
				when s_waitack =>
					if i_wrap_o_cur_act.ack = '1' then
						r_sys_via_block_clken <= '1';
						r_state <= s_idle;
						r_wrap_cyc <= '0';
						r_wrap_D_WR_stb <= '0';
						for I in C_CPU_BYTELANES-1 downto 0 loop
							if r_acked(I) = '0' then
								r_D_rd(7+I*8 downto I*8) <= fb_p2c_i.D_rd;
								r_acked(I) <= '1';
						end if;
						end loop;
					end if;
				when others =>
					r_state <= s_idle;
			end case;


		end if;
	end process;

	-- ================================================================================================ --
	-- Logical to physical address mapping 
	-- ================================================================================================ --


	e_log2phys: entity work.log2phys
	generic map (
		SIM									=> SIM
	)
	port map (
		fb_syscon_i 						=> fb_syscon_i,	
		-- CPU address control signals from other components
		JIM_page_i							=> JIM_page_i,
		sys_ROMPG_i							=> sys_ROMPG_i,
		cfg_swram_enable_i				=> cfg_swram_enable_i,
		cfg_swromx_i						=> cfg_swromx_i,
		cfg_mosram_i						=> cfg_mosram_i,
		cfg_t65_i							=> r_cpu_en_t65,
      cfg_sys_type_i                => cfg_sys_type_i,

		jim_en_i								=> jim_en_i,
		swmos_shadow_i						=> swmos_shadow_i,
		turbo_lo_mask_i					=> turbo_lo_mask_i,
		noice_debug_shadow_i				=> noice_debug_shadow_i,

		A_i									=> i_wrap_o_cur_act.A_log,
		A_o									=> i_wrap_phys_A
	);

	-- ================================================================================================ --
	-- Instantiate CPU wrappers 
	-- ================================================================================================ --


gt65: IF G_INCL_CPU_T65 GENERATE
	e_t65:entity work.fb_cpu_t65
	generic map (
		SIM									=> SIM,
		CLOCKSPEED							=> CLOCKSPEED
	)
	port map (

		-- configuration
		cpu_en_i									=> r_cpu_en_t65,
		fb_syscon_i								=> fb_syscon_i,

		wrap_o									=> i_wrap_o_all(C_IX_CPU_T65),
		wrap_i									=> i_wrap_i,

		D_rd_i									=> i_wrap_D_rd(7 downto 0)


	);

END GENERATE;

g6x09:IF G_INCL_CPU_6x09 GENERATE
	e_wrap_6x09:entity work.fb_cpu_6x09
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
		wrap_i									=> i_wrap_i
	);
END GENERATE;

gz80: IF G_INCL_CPU_Z80 GENERATE
	e_wrap_z80:entity work.fb_cpu_z80
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_z80,
		fb_syscon_i								=> fb_syscon_i,

		wrap_o									=> i_wrap_o_all(C_IX_CPU_Z80),
		wrap_i									=> i_wrap_i

	);
END GENERATE;


g68k:IF G_INCL_CPU_68k GENERATE
	e_wrap_68k:entity work.fb_cpu_68k
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_68k,
		cfg_mosram_i							=> cfg_mosram_i,
		cfg_cpu_speed_i						=> cfg_cpu_speed_opt_i,		
		fb_syscon_i								=> fb_syscon_i,

		wrap_o									=> i_wrap_o_all(C_IX_CPU_68k),
		wrap_i									=> i_wrap_i,

		jim_en_i									=> jim_en_i

	);
END GENERATE;


--g6502:IF G_OPT_INCLUDE_6502 GENERATE
--
--	e_wrap_6502:entity work.fb_cpu_6502
--	generic map (
--		SIM										=> SIM,
--		CLOCKSPEED								=> CLOCKSPEED,
--		G_JIM_DEVNO								=> G_JIM_DEVNO
--	) 
--	port map(
--
--		-- configuration
--		cpu_en_i									=> r_cpu_en_6502,
--		fb_syscon_i								=> fb_syscon_i,
--
--		wrap_o									=> i_wrap_o_all(C_IX_CPU_6502),
--		wrap_i									=> i_wrap_i
--
--	);
--END GENERATE;

g65c02:IF G_INCL_CPU_65C02 GENERATE
	e_wrap_65c02:entity work.fb_cpu_65c02
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
		wrap_i									=> i_wrap_i

	);
END GENERATE;


g65816:IF G_INCL_CPU_65816 GENERATE
	e_wrap_65816:entity work.fb_cpu_65816
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

		boot_65816_i							=> boot_65816_i,

		debug_vma_o								=> debug_65816_vma_o
	);
END GENERATE;

	-- ================================================================================================ --
	-- SYS VIA blocker
	-- ================================================================================================ --

	e_sys_via_block:entity work.fb_sys_via_blocker
	generic map (
		SIM => SIM,
		CLOCKSPEED => CLOCKSPEED		
		)
	port map (
		fb_syscon_i => fb_syscon_i,
		cfg_sys_type_i => cfg_sys_type_i,
		clken => r_sys_via_block_clken,
		A_i => i_wrap_o_cur_act.A_log,
		RnW_i => not i_wrap_o_cur_act.we,
		SYS_VIA_block_o => i_SYS_VIA_block
		);

	debug_SYS_VIA_block_o <= i_SYS_VIA_block;

	-- ================================================================================================ --
	-- multiplex wrapper signals
	-- ================================================================================================ --

	i_wrap_o_cur_act	<= i_wrap_o_all(r_cpu_run_ix_act);	
	i_wrap_o_cur_hard	<= i_wrap_o_all(r_cpu_run_ix_hard);	


	-- ================================================================================================ --
	-- Wrapper to/from CPU handlers
	-- ================================================================================================ --

  	fb_c2p_o.cyc <= r_wrap_cyc;
  	fb_c2p_o.we <= r_wrap_we;
  	fb_c2p_o.A <= r_wrap_phys_A;
  	fb_c2p_o.A_stb <= r_wrap_cyc;
  	fb_c2p_o.D_wr <=  r_wrap_D_wr;
  	fb_c2p_o.D_wr_stb <= r_wrap_D_wr_stb;



	i_wrap_i.rdy_ctdn						<= fb_p2c_i.rdy_ctdn;
	i_wrap_i.cyc 							<= r_wrap_cyc;

	i_wrap_i.cpu_halt 					<= cpu_halt_i;
	i_wrap_i.CPUSKT_D 					<= CPUSKT_D_io;
	i_wrap_i.CPUSKT_A 					<= CPUSKT_A_i;

	i_wrap_i.CPUSKT_6EKEZnRD					<= CPUSKT_6EKEZnRD_i;
	i_wrap_i.CPUSKT_C6nML9BUSYKnBGZnBUSACK	<= CPUSKT_C6nML9BUSYKnBGZnBUSACK_i;
	i_wrap_i.CPUSKT_RnWZnWR						<= CPUSKT_RnWZnWR_i;
	i_wrap_i.CPUSKT_PHI16ABRT9BSKnDS			<= CPUSKT_PHI16ABRT9BSKnDS_i;
	i_wrap_i.CPUSKT_PHI26VDAKFC0ZnMREQ		<= CPUSKT_PHI26VDAKFC0ZnMREQ_i;
	i_wrap_i.CPUSKT_SYNC6VPA9LICKFC2ZnM1	<= CPUSKT_SYNC6VPA9LICKFC2ZnM1_i;
	i_wrap_i.CPUSKT_VSS6VPA9BAKnAS			<= CPUSKT_VSS6VPA9BAKnAS_i;
	i_wrap_i.CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ	<= CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i;

	i_wrap_i.noice_debug_nmi_n 		<= noice_debug_nmi_n_i;
	i_wrap_i.noice_debug_shadow 		<= noice_debug_shadow_i;
	i_wrap_i.noice_debug_inhibit_cpu <= noice_debug_inhibit_cpu_i;
	i_wrap_i.throttle_cpu_2MHz 		<= throttle_cpu_2MHz_i;
	i_wrap_i.cpu_2MHz_phi2_clken 		<= cpu_2MHz_phi2_clken_i;
	i_wrap_i.nmi_n 						<= r_nmi;
	i_wrap_i.irq_n 						<= irq_n_i;


	-- ================================================================================================ --
	-- expansion header signals from current CPU
	-- ================================================================================================ --

	CPUSKT_6BE9TSCKnVPA_o		<= i_wrap_o_cur_hard.CPUSKT_6BE9TSCKnVPA;
	CPUSKT_9Q_o						<= i_wrap_o_cur_hard.CPUSKT_9Q;
	CPUSKT_KnBRZnBUSREQ_o		<= i_wrap_o_cur_hard.CPUSKT_KnBRZnBUSREQ;
	CPUSKT_PHI09EKZCLK_o			<= i_wrap_o_cur_hard.CPUSKT_PHI09EKZCLK;
	CPUSKT_RDY9KnHALTZnWAIT_o	<= i_wrap_o_cur_hard.CPUSKT_RDY9KnHALTZnWAIT;
	CPUSKT_nIRQKnIPL1_o			<= i_wrap_o_cur_hard.CPUSKT_nIRQKnIPL1;
	CPUSKT_nNMIKnIPL02_o			<= i_wrap_o_cur_hard.CPUSKT_nNMIKnIPL02;
	CPUSKT_nRES_o					<= i_wrap_o_cur_hard.CPUSKT_nRES;
	CPUSKT_9nFIRQLnDTACK_o		<= i_wrap_o_cur_hard.CPUSKT_9nFIRQLnDTACK;


	CPUSKT_D_io	 		<= (others => 'Z') when i_wrap_o_cur_hard.CPU_D_RnW = '0' else
									i_wrap_D_rd(7 downto 0);

	-- noice signals from current CPU

	noice_debug_5c_o			<= i_wrap_o_cur_act.noice_debug_5c;
	noice_debug_cpu_clken_o	<= i_wrap_o_cur_act.noice_debug_cpu_clken;
	noice_debug_A0_tgl_o		<= i_wrap_o_cur_act.noice_debug_A0_tgl;
	noice_debug_opfetch_o	<= i_wrap_o_cur_act.noice_debug_opfetch;


end rtl;

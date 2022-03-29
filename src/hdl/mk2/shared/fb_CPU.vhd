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

entity fb_cpu is
	generic (
		G_NMI_META_LEVELS					: natural := 5;
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural										-- fast clock speed in mhz						
	);
	port(

		-- configuration

		cfg_hard_cpu_type_i					: in cpu_type;
		cfg_hard_cpu_speed_i					: in std_logic;
		cfg_swram_enable_i					: in std_logic;
		cfg_mosram_i							: in std_logic;
		cfg_t65_i								: in std_logic;				-- when 0 enable t65 core
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
		fb_m2s_o									: out fb_mas_o_sla_i_t;
		fb_s2m_i									: in	fb_mas_i_sla_o_t;

		-- chipset control signals
		cpu_halt_i								: in  std_logic;

		-- cpu specific signals

		boot_65816_i							: in 	std_logic;

		-- temporary debug signals
		debug_wrap_cyc_o						: out std_logic;

		debug_65816_vma_o						: out std_logic

	);
end fb_cpu;

architecture rtl of fb_cpu is

-- number of 128MHz cycles until we will allow between two accesses to SYS VIA IORB
	constant C_IORB_BODGE_MAX : natural := CLOCKSPEED * 10;

	signal r_iorb_block 			: std_logic;
	signal r_iorb_block_ctdn 	: unsigned(NUMBITS(C_IORB_BODGE_MAX) downto 0);
	signal i_iorb_cs				: std_logic;
	signal r_iorb_cs				: std_logic;

	-- wrapper enable signals
	signal i_cpu_en_t65 : std_logic;
	signal i_cpu_en_6x09 : std_logic;
	signal i_cpu_en_z80 : std_logic;
	signal i_cpu_en_68k : std_logic;
--	signal i_cpu_en_6502 : std_logic;
	signal i_cpu_en_65c02 : std_logic;
	signal i_cpu_en_65816 : std_logic;

	type state_t is (
		s_idle							-- waiting for address ready signal from cpu wrapper
		, s_waitack						-- wait for ack from cpu
		, iorb_blocked					-- pause on iorb
		);

	signal r_state				: state_t;

	signal r_D_rd				: std_logic_vector(7 downto 0);
	signal r_acked 			: std_logic;

	-- per-wrapper control signals

	signal i_t65_wrap_cyc			: std_logic;
	signal i_t65_wrap_A_log			: std_logic_vector(23 downto 0);
	signal i_t65_wrap_we				: std_logic;
	signal i_t65_wrap_D_WR_stb		: std_logic;
	signal i_t65_wrap_D_WR			: std_logic_vector(7 downto 0);
	signal i_t65_wrap_ack			: std_logic;

--	signal i_6502_wrap_cyc			: std_logic;
--	signal i_6502_wrap_A_log		: std_logic_vector(23 downto 0);
--	signal i_6502_wrap_we			: std_logic;
--	signal i_6502_wrap_D_WR_stb	: std_logic;
--	signal i_6502_wrap_D_WR			: std_logic_vector(7 downto 0);
--	signal i_6502_wrap_ack			: std_logic;
--
	signal i_65c02_wrap_cyc			: std_logic;
	signal i_65c02_wrap_A_log		: std_logic_vector(23 downto 0);
	signal i_65c02_wrap_we			: std_logic;
	signal i_65c02_wrap_D_WR_stb	: std_logic;
	signal i_65c02_wrap_D_WR		: std_logic_vector(7 downto 0);
	signal i_65c02_wrap_ack			: std_logic;

	signal i_65816_wrap_cyc			: std_logic;
	signal i_65816_wrap_A_log		: std_logic_vector(23 downto 0);
	signal i_65816_wrap_we			: std_logic;
	signal i_65816_wrap_D_WR_stb	: std_logic;
	signal i_65816_wrap_D_WR		: std_logic_vector(7 downto 0);
	signal i_65816_wrap_ack			: std_logic;

	signal i_6x09_wrap_cyc			: std_logic;
	signal i_6x09_wrap_A_log		: std_logic_vector(23 downto 0);
	signal i_6x09_wrap_we			: std_logic;
	signal i_6x09_wrap_D_WR_stb	: std_logic;
	signal i_6x09_wrap_D_WR			: std_logic_vector(7 downto 0);
	signal i_6x09_wrap_ack			: std_logic;

	signal i_z80_wrap_cyc			: std_logic;
	signal i_z80_wrap_A_log			: std_logic_vector(23 downto 0);
	signal i_z80_wrap_we				: std_logic;
	signal i_z80_wrap_D_WR_stb		: std_logic;
	signal i_z80_wrap_D_WR			: std_logic_vector(7 downto 0);
	signal i_z80_wrap_ack			: std_logic;

	signal i_68k_wrap_cyc			: std_logic;
	signal i_68k_wrap_A_log			: std_logic_vector(23 downto 0);
	signal i_68k_wrap_we				: std_logic;
	signal i_68k_wrap_D_WR_stb		: std_logic;
	signal i_68k_wrap_D_WR			: std_logic_vector(7 downto 0);
	signal i_68k_wrap_ack			: std_logic;


	-- multiplexed control signals
	signal i_wrap_cyc					: std_logic;
	signal i_wrap_A_log				: std_logic_vector(23 downto 0);
	signal i_wrap_we					: std_logic;
	signal i_wrap_D_WR_stb			: std_logic;
	signal i_wrap_D_WR				: std_logic_vector(7 downto 0);
	signal i_wrap_ack					: std_logic;

	signal r_wrap_cyc					: std_logic;
	signal i_wrap_phys_A				: std_logic_vector(23 downto 0);
	signal r_wrap_phys_A				: std_logic_vector(23 downto 0);
	signal r_wrap_we					: std_logic;
	signal r_wrap_D_WR_stb			: std_logic;
	signal r_wrap_D_WR				: std_logic_vector(7 downto 0);

	signal i_wrap_D_rd				: std_logic_vector(7 downto 0);

	-- cpu socket outputs multiplex

	signal i_6x09_CPUSKT_6BE9TSCKnVPA		: std_logic;
	signal i_6x09_CPUSKT_9Q						: std_logic;
	signal i_6x09_CPUSKT_KnBRZnBUSREQ		: std_logic;
	signal i_6x09_CPUSKT_PHI09EKZCLK			: std_logic;
	signal i_6x09_CPUSKT_RDY9KnHALTZnWAIT	: std_logic;
	signal i_6x09_CPUSKT_nIRQKnIPL1			: std_logic;
	signal i_6x09_CPUSKT_nNMIKnIPL02			: std_logic;
	signal i_6x09_CPUSKT_nRES					: std_logic;
	signal i_6x09_CPUSKT_9nFIRQLnDTACK		: std_logic;

	signal i_z80_CPUSKT_6BE9TSCKnVPA			: std_logic;
	signal i_z80_CPUSKT_9Q						: std_logic;
	signal i_z80_CPUSKT_KnBRZnBUSREQ			: std_logic;
	signal i_z80_CPUSKT_PHI09EKZCLK			: std_logic;
	signal i_z80_CPUSKT_RDY9KnHALTZnWAIT	: std_logic;
	signal i_z80_CPUSKT_nIRQKnIPL1			: std_logic;
	signal i_z80_CPUSKT_nNMIKnIPL02			: std_logic;
	signal i_z80_CPUSKT_nRES					: std_logic;
	signal i_z80_CPUSKT_9nFIRQLnDTACK		: std_logic;

	signal i_68k_CPUSKT_6BE9TSCKnVPA			: std_logic;
	signal i_68k_CPUSKT_9Q						: std_logic;
	signal i_68k_CPUSKT_KnBRZnBUSREQ			: std_logic;
	signal i_68k_CPUSKT_PHI09EKZCLK			: std_logic;
	signal i_68k_CPUSKT_RDY9KnHALTZnWAIT	: std_logic;
	signal i_68k_CPUSKT_nIRQKnIPL1			: std_logic;
	signal i_68k_CPUSKT_nNMIKnIPL02			: std_logic;
	signal i_68k_CPUSKT_nRES					: std_logic;
	signal i_68k_CPUSKT_9nFIRQLnDTACK		: std_logic;

--	signal i_6502_CPUSKT_6BE9TSCKnVPA		: std_logic;
--	signal i_6502_CPUSKT_9Q						: std_logic;
--	signal i_6502_CPUSKT_KnBRZnBUSREQ		: std_logic;
--	signal i_6502_CPUSKT_PHI09EKZCLK			: std_logic;
--	signal i_6502_CPUSKT_RDY9KnHALTZnWAIT	: std_logic;
--	signal i_6502_CPUSKT_nIRQKnIPL1			: std_logic;
--	signal i_6502_CPUSKT_nNMIKnIPL02			: std_logic;
--	signal i_6502_CPUSKT_nRES					: std_logic;
--	signal i_6502_CPUSKT_9nFIRQLnDTACK		: std_logic;
--
	signal i_65c02_CPUSKT_6BE9TSCKnVPA		: std_logic;
	signal i_65c02_CPUSKT_9Q					: std_logic;
	signal i_65c02_CPUSKT_KnBRZnBUSREQ		: std_logic;
	signal i_65c02_CPUSKT_PHI09EKZCLK		: std_logic;
	signal i_65c02_CPUSKT_RDY9KnHALTZnWAIT	: std_logic;
	signal i_65c02_CPUSKT_nIRQKnIPL1			: std_logic;
	signal i_65c02_CPUSKT_nNMIKnIPL02		: std_logic;
	signal i_65c02_CPUSKT_nRES					: std_logic;
	signal i_65c02_CPUSKT_9nFIRQLnDTACK		: std_logic;

	signal i_65816_CPUSKT_6BE9TSCKnVPA		: std_logic;
	signal i_65816_CPUSKT_9Q					: std_logic;
	signal i_65816_CPUSKT_KnBRZnBUSREQ		: std_logic;
	signal i_65816_CPUSKT_PHI09EKZCLK		: std_logic;
	signal i_65816_CPUSKT_RDY9KnHALTZnWAIT	: std_logic;
	signal i_65816_CPUSKT_nIRQKnIPL1			: std_logic;
	signal i_65816_CPUSKT_nNMIKnIPL02		: std_logic;
	signal i_65816_CPUSKT_nRES					: std_logic;
	signal i_65816_CPUSKT_9nFIRQLnDTACK		: std_logic;


	-- buffer direction multiples
	-- buffer direction for CPU_D_io '1' for read into cpu
	signal i_t65_CPU_D_RnW						: std_logic;		
--	signal i_6502_CPU_D_RnW						: std_logic;		
	signal i_65c02_CPU_D_RnW					: std_logic;			
	signal i_65816_CPU_D_RnW					: std_logic;	
	signal i_6x09_CPU_D_RnW						: std_logic;
	signal i_z80_CPU_D_RnW						: std_logic;
	signal i_68k_CPU_D_RnW						: std_logic;
	signal i_CPU_D_RnW							: std_logic;

	signal i_t65_noice_debug_5c				:	std_logic;
	signal i_t65_noice_debug_cpu_clken		:	std_logic;
	signal i_t65_noice_debug_A0_tgl			:	std_logic;
	signal i_t65_noice_debug_opfetch			:	std_logic;

--	signal i_6502_noice_debug_5c				:	std_logic;
--	signal i_6502_noice_debug_cpu_clken		:	std_logic;
--	signal i_6502_noice_debug_A0_tgl			:	std_logic;
--	signal i_6502_noice_debug_opfetch		:	std_logic;
--
	signal i_65c02_noice_debug_5c				:	std_logic;
	signal i_65c02_noice_debug_cpu_clken	:	std_logic;
	signal i_65c02_noice_debug_A0_tgl		:	std_logic;
	signal i_65c02_noice_debug_opfetch		:	std_logic;

	signal i_65816_noice_debug_5c				:	std_logic;
	signal i_65816_noice_debug_cpu_clken	:	std_logic;
	signal i_65816_noice_debug_A0_tgl		:	std_logic;
	signal i_65816_noice_debug_opfetch		:	std_logic;

	signal i_6x09_noice_debug_5c				:	std_logic;
	signal i_6x09_noice_debug_cpu_clken		:	std_logic;
	signal i_6x09_noice_debug_A0_tgl			:	std_logic;
	signal i_6x09_noice_debug_opfetch		:	std_logic;

	signal i_z80_noice_debug_5c				:	std_logic;
	signal i_z80_noice_debug_cpu_clken		:	std_logic;
	signal i_z80_noice_debug_A0_tgl			:	std_logic;
	signal i_z80_noice_debug_opfetch			:	std_logic;

	signal i_68k_noice_debug_5c				:	std_logic;
	signal i_68k_noice_debug_cpu_clken		:	std_logic;
	signal i_68k_noice_debug_A0_tgl			:	std_logic;
	signal i_68k_noice_debug_opfetch			:	std_logic;


	signal r_nmi				: std_logic;

	signal r_nmi_meta			: std_logic_vector(G_NMI_META_LEVELS-1 downto 0);

begin

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



	debug_wrap_cyc_o <= i_wrap_cyc;

	--NOTE: this can't be moved to SYS otherwise it hogs the intercon and blocks aeris, best left here
	i_iorb_cs <= '1' when i_wrap_phys_A(23 downto 4) = x"FFFE4" else 
					 '0';

	CPUSKT_D_io	 	<= (others => 'Z') when i_CPU_D_RnW = '0' else
						i_wrap_D_rd;

	i_wrap_D_rd <= 		r_D_rd when r_acked = '1' else
						fb_s2m_i.D_rd;
	
	-- CAVEATS:
	--   the process below has been trimmed with the following expectations:
	--		1 when i_wrap cyc goes active it is a register in the wrapper
	--	   2 the logical address passed in i_wrap_A_log is also registered in the wrapper
	--			the above two allow for the log->phys mapping in a single cycle


	p_wrap_state:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_state <= s_idle;
			r_wrap_phys_A <= (others => '0');
			r_wrap_cyc <= '0';
			r_wrap_we <= '0';
			r_wrap_D_WR_stb <= '0';
			r_wrap_D_WR <= (others => '0');

			r_iorb_block <= '0';
			r_iorb_block_ctdn <= (others => '0');
			r_iorb_cs <= '0';

			r_acked <= '0';

		elsif rising_edge(fb_syscon_i.clk) then
			r_state <= r_state;


			if (i_wrap_cyc = '1' or r_wrap_cyc = '1' or r_state = iorb_blocked) and i_wrap_D_WR_stb = '1' then
				r_wrap_D_WR_stb <= '1';
				r_wrap_D_WR <= i_wrap_D_WR;
			end if;

			case r_state is
				when s_idle =>
					if i_wrap_cyc = '1' then
						if i_iorb_cs = '1' and r_iorb_block = '1' then
							r_state <= iorb_blocked;
						else
							r_state <= s_waitack;
							r_wrap_phys_A <= i_wrap_phys_A;
							r_wrap_we <= i_wrap_we;
							r_wrap_cyc <= '1';
							r_iorb_cs <= i_iorb_cs;
						end if;
					end if;
				when iorb_blocked =>
					if r_iorb_block = '0' then
						r_state <= s_waitack;
						r_wrap_phys_A <= i_wrap_phys_A;
						r_wrap_we <= i_wrap_we;
						r_wrap_cyc <= '1';
						r_iorb_cs <= '1';
					end if;
				when s_waitack =>
				   r_acked <= '0';
					if i_wrap_ack = '1' then
						r_state <= s_idle;
						r_wrap_cyc <= '0';
						r_wrap_D_WR_stb <= '0';
						r_acked <= '1';
						r_D_rd <= fb_s2m_i.D_rd;

						if r_iorb_cs = '1' then
							r_iorb_block_ctdn <= to_unsigned(C_IORB_BODGE_MAX, r_iorb_block_ctdn'length);
							r_iorb_block <= '1';
						end if;
					end if;
				when others =>
					r_state <= s_idle;
			end case;

			if r_iorb_block = '1' then
				if r_iorb_block_ctdn(r_iorb_block_ctdn'high) = '1' then -- counter wrapped
					r_iorb_block <= '0';
				else
					r_iorb_block_ctdn <= r_iorb_block_ctdn - 1;
				end if;
			end if;

		end if;
	end process;

	e_log2phys: entity work.log2phys
	generic map (
		SIM									=> SIM
	)
	port map (
		-- CPU address control signals from other components
		JIM_page_i							=> JIM_page_i,
		sys_ROMPG_i							=> sys_ROMPG_i,
		cfg_swram_enable_i				=> cfg_swram_enable_i,
		cfg_swromx_i						=> cfg_swromx_i,
		cfg_mosram_i						=> cfg_mosram_i,
		cfg_t65_i							=> cfg_t65_i,

		jim_en_i								=> jim_en_i,
		swmos_shadow_i						=> swmos_shadow_i,
		turbo_lo_mask_i					=> turbo_lo_mask_i,
		noice_debug_shadow_i				=> noice_debug_shadow_i,

		A_i									=> i_wrap_A_log,
		A_o									=> i_wrap_phys_A
	);


  	fb_m2s_o.cyc <= r_wrap_cyc;
  	fb_m2s_o.we <= r_wrap_we;
  	fb_m2s_o.A <= r_wrap_phys_A;
  	fb_m2s_o.A_stb <= r_wrap_cyc;
  	fb_m2s_o.D_wr <=  r_wrap_D_wr;
  	fb_m2s_o.D_wr_stb <= r_wrap_D_wr_stb;



  	i_cpu_en_t65 	<= '1' when cfg_t65_i = '1' else '0';
  	i_cpu_en_6x09 	<= '1' when cfg_t65_i = '0' and cfg_hard_cpu_type_i = cpu_6x09 else '0';
  	i_cpu_en_z80 	<= '1' when cfg_t65_i = '0' and cfg_hard_cpu_type_i = cpu_z80 else '0';
  	i_cpu_en_68k 	<= '1' when cfg_t65_i = '0' and cfg_hard_cpu_type_i = cpu_68008 else '0';
--  	i_cpu_en_6502 	<= '1' when cfg_t65_i = '0' and cfg_hard_cpu_type_i = cpu_6502 else '0';
  	i_cpu_en_65c02	<= '1' when cfg_t65_i = '0' and cfg_hard_cpu_type_i = cpu_65c02 else '0';
  	i_cpu_en_65816	<= '1' when cfg_t65_i = '0' and cfg_hard_cpu_type_i = cpu_65816 else '0';


	e_t65:entity work.fb_cpu_t65
	generic map (
		SIM									=> SIM,
		CLOCKSPEED							=> CLOCKSPEED
	)
	port map (

		-- configuration
		cpu_en_i									=> i_cpu_en_t65,
		fb_syscon_i								=> fb_syscon_i,

		-- noice debugger signals to cpu
		noice_debug_nmi_n_i					=> noice_debug_nmi_n_i,
		noice_debug_shadow_i					=> noice_debug_shadow_i,
		noice_debug_inhibit_cpu_i			=> noice_debug_inhibit_cpu_i,
																				-- spurious memory accesses
		-- noice debugger signals from cpu
		noice_debug_5c_o						=> i_t65_noice_debug_5c,
		noice_debug_cpu_clken_o				=> i_t65_noice_debug_cpu_clken,
		noice_debug_A0_tgl_o					=> i_t65_noice_debug_A0_tgl,
		noice_debug_opfetch_o				=> i_t65_noice_debug_opfetch,

		-- cpu throttle
		throttle_cpu_2MHz_i 					=> throttle_cpu_2MHz_i,
		cpu_2MHz_phi2_clken_i				=> cpu_2MHz_phi2_clken_i,

		-- direct CPU control signals from system
		nmi_n_i									=> r_nmi,
		irq_n_i									=> irq_n_i,

		-- state machine signals
		wrap_cyc_o								=> i_t65_wrap_cyc,
		wrap_A_log_o							=> i_t65_wrap_A_log,
		wrap_A_we_o								=> i_t65_wrap_we,
		wrap_D_WR_stb_o						=> i_t65_wrap_D_WR_stb,
		wrap_D_WR_o								=> i_t65_wrap_D_WR,
		wrap_ack_o								=> i_t65_wrap_ack,

		wrap_rdy_ctdn_i						=> fb_s2m_i.rdy_ctdn,
		wrap_cyc_i								=> r_wrap_cyc,
		wrap_D_rd_i								=> i_wrap_D_rd,

		-- chipset control signals
		cpu_halt_i								=> cpu_halt_i

	);

	e_wrap_6x09:entity work.fb_cpu_6x09
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED
	) 
	port map(

		-- configuration
		cpu_en_i									=> i_cpu_en_6x09,
		cpu_speed_i								=> cfg_hard_cpu_speed_i,
		fb_syscon_i								=> fb_syscon_i,

		-- noice debugger signals to cpu
		noice_debug_nmi_n_i					=> noice_debug_nmi_n_i,
		noice_debug_shadow_i					=> noice_debug_shadow_i,
		noice_debug_inhibit_cpu_i			=> noice_debug_inhibit_cpu_i,
																				-- spurious memory accesses
		-- noice debugger signals from cpu
		noice_debug_5c_o						=> i_6x09_noice_debug_5c,
		noice_debug_cpu_clken_o				=> i_6x09_noice_debug_cpu_clken,
		noice_debug_A0_tgl_o					=> i_6x09_noice_debug_A0_tgl,
		noice_debug_opfetch_o				=> i_6x09_noice_debug_opfetch,

		-- direct CPU control signals from system
		nmi_n_i									=> r_nmi,
		irq_n_i									=> irq_n_i,

		-- state machine signals
		wrap_cyc_o								=> i_6x09_wrap_cyc,
		wrap_A_log_o							=> i_6x09_wrap_A_log,
		wrap_A_we_o								=> i_6x09_wrap_we,
		wrap_D_WR_stb_o						=> i_6x09_wrap_D_WR_stb,
		wrap_D_WR_o								=> i_6x09_wrap_D_WR,
		wrap_ack_o								=> i_6x09_wrap_ack,

		wrap_rdy_ctdn_i						=> fb_s2m_i.rdy_ctdn,
		wrap_cyc_i								=> r_wrap_cyc,

		-- chipset control signals
		cpu_halt_i								=> cpu_halt_i,

		CPU_D_RnW_o								=> i_6x09_CPU_D_RnW,

		-- cpu socket signals
		CPUSKT_D_i								=> CPUSKT_D_io,

		CPUSKT_A_i								=> CPUSKT_A_i,
		CPUSKT_6EKEZnRD_i						=> CPUSKT_6EKEZnRD_i,
		CPUSKT_C6nML9BUSYKnBGZnBUSACK_i	=> CPUSKT_C6nML9BUSYKnBGZnBUSACK_i,
		CPUSKT_RnWZnWR_i						=> CPUSKT_RnWZnWR_i,
		CPUSKT_PHI16ABRT9BSKnDS_i			=> CPUSKT_PHI16ABRT9BSKnDS_i,
		CPUSKT_PHI26VDAKFC0ZnMREQ_i		=> CPUSKT_PHI26VDAKFC0ZnMREQ_i,
		CPUSKT_SYNC6VPA9LICKFC2ZnM1_i		=> CPUSKT_SYNC6VPA9LICKFC2ZnM1_i,
		CPUSKT_VSS6VPA9BAKnAS_i				=> CPUSKT_VSS6VPA9BAKnAS_i,
		CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i	=> CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i,
		CPUSKT_6BE9TSCKnVPA_o				=> i_6x09_CPUSKT_6BE9TSCKnVPA,
		CPUSKT_9Q_o								=> i_6x09_CPUSKT_9Q,
		CPUSKT_KnBRZnBUSREQ_o				=> i_6x09_CPUSKT_KnBRZnBUSREQ,
		CPUSKT_PHI09EKZCLK_o					=> i_6x09_CPUSKT_PHI09EKZCLK,
		CPUSKT_RDY9KnHALTZnWAIT_o			=> i_6x09_CPUSKT_RDY9KnHALTZnWAIT,
		CPUSKT_nIRQKnIPL1_o					=> i_6x09_CPUSKT_nIRQKnIPL1,
		CPUSKT_nNMIKnIPL02_o					=> i_6x09_CPUSKT_nNMIKnIPL02,
		CPUSKT_nRES_o							=> i_6x09_CPUSKT_nRES,
		CPUSKT_9nFIRQLnDTACK_o				=> i_6x09_CPUSKT_9nFIRQLnDTACK
	);

	e_wrap_z80:entity work.fb_cpu_z80
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED
	) 
	port map(

		-- configuration
		cpu_en_i									=> i_cpu_en_z80,
		fb_syscon_i								=> fb_syscon_i,

		-- noice debugger signals to cpu
		noice_debug_nmi_n_i					=> noice_debug_nmi_n_i,
		noice_debug_shadow_i					=> noice_debug_shadow_i,
		noice_debug_inhibit_cpu_i			=> noice_debug_inhibit_cpu_i,
																				-- spurious memory accesses
		-- noice debugger signals from cpu
		noice_debug_5c_o						=> i_z80_noice_debug_5c,
		noice_debug_cpu_clken_o				=> i_z80_noice_debug_cpu_clken,
		noice_debug_A0_tgl_o					=> i_z80_noice_debug_A0_tgl,
		noice_debug_opfetch_o				=> i_z80_noice_debug_opfetch,

		-- direct CPU control signals from system
		nmi_n_i									=> r_nmi,
		irq_n_i									=> irq_n_i,

		-- state machine signals
		wrap_cyc_o								=> i_z80_wrap_cyc,
		wrap_A_log_o							=> i_z80_wrap_A_log,
		wrap_A_we_o								=> i_z80_wrap_we,
		wrap_D_WR_stb_o						=> i_z80_wrap_D_WR_stb,
		wrap_D_WR_o								=> i_z80_wrap_D_WR,
		wrap_ack_o								=> i_z80_wrap_ack,

		wrap_rdy_ctdn_i						=> fb_s2m_i.rdy_ctdn,
		wrap_cyc_i								=> r_wrap_cyc,

		-- chipset control signals
		cpu_halt_i								=> cpu_halt_i,

		CPU_D_RnW_o								=> i_z80_CPU_D_RnW,

		-- cpu socket signals
		CPUSKT_D_i								=> CPUSKT_D_io,

		CPUSKT_A_i								=> CPUSKT_A_i,
		CPUSKT_6EKEZnRD_i						=> CPUSKT_6EKEZnRD_i,
		CPUSKT_C6nML9BUSYKnBGZnBUSACK_i	=> CPUSKT_C6nML9BUSYKnBGZnBUSACK_i,
		CPUSKT_RnWZnWR_i						=> CPUSKT_RnWZnWR_i,
		CPUSKT_PHI16ABRT9BSKnDS_i			=> CPUSKT_PHI16ABRT9BSKnDS_i,
		CPUSKT_PHI26VDAKFC0ZnMREQ_i		=> CPUSKT_PHI26VDAKFC0ZnMREQ_i,
		CPUSKT_SYNC6VPA9LICKFC2ZnM1_i		=> CPUSKT_SYNC6VPA9LICKFC2ZnM1_i,
		CPUSKT_VSS6VPA9BAKnAS_i				=> CPUSKT_VSS6VPA9BAKnAS_i,
		CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i	=> CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i,
		CPUSKT_6BE9TSCKnVPA_o				=> i_z80_CPUSKT_6BE9TSCKnVPA,
		CPUSKT_9Q_o								=> i_z80_CPUSKT_9Q,
		CPUSKT_KnBRZnBUSREQ_o				=> i_z80_CPUSKT_KnBRZnBUSREQ,
		CPUSKT_PHI09EKZCLK_o					=> i_z80_CPUSKT_PHI09EKZCLK,
		CPUSKT_RDY9KnHALTZnWAIT_o			=> i_z80_CPUSKT_RDY9KnHALTZnWAIT,
		CPUSKT_nIRQKnIPL1_o					=> i_z80_CPUSKT_nIRQKnIPL1,
		CPUSKT_nNMIKnIPL02_o					=> i_z80_CPUSKT_nNMIKnIPL02,
		CPUSKT_nRES_o							=> i_z80_CPUSKT_nRES,
		CPUSKT_9nFIRQLnDTACK_o				=> i_z80_CPUSKT_9nFIRQLnDTACK
	);



	e_wrap_68k:entity work.fb_cpu_68k
	generic map (
		SIM										=> SIM
	) 
	port map(

		-- configuration
		cpu_en_i									=> i_cpu_en_68k,
		cfg_mosram_i							=> cfg_mosram_i,
		fb_syscon_i								=> fb_syscon_i,

		-- noice debugger signals to cpu
		noice_debug_nmi_n_i					=> noice_debug_nmi_n_i,
		noice_debug_shadow_i					=> noice_debug_shadow_i,
		noice_debug_inhibit_cpu_i			=> noice_debug_inhibit_cpu_i,
																				-- spurious memory accesses
		-- noice debugger signals from cpu
		noice_debug_5c_o						=> i_68k_noice_debug_5c,
		noice_debug_cpu_clken_o				=> i_68k_noice_debug_cpu_clken,
		noice_debug_A0_tgl_o					=> i_68k_noice_debug_A0_tgl,
		noice_debug_opfetch_o				=> i_68k_noice_debug_opfetch,

		-- direct CPU control signals from system
		nmi_n_i									=> r_nmi,
		irq_n_i									=> irq_n_i,

		-- state machine signals
		wrap_cyc_o								=> i_68k_wrap_cyc,
		wrap_A_log_o							=> i_68k_wrap_A_log,
		wrap_A_we_o								=> i_68k_wrap_we,
		wrap_D_WR_stb_o						=> i_68k_wrap_D_WR_stb,
		wrap_D_WR_o								=> i_68k_wrap_D_WR,
		wrap_ack_o								=> i_68k_wrap_ack,

		wrap_rdy_ctdn_i						=> fb_s2m_i.rdy_ctdn,
		wrap_cyc_i								=> r_wrap_cyc,

		-- chipset control signals
		cpu_halt_i								=> cpu_halt_i,

		CPU_D_RnW_o								=> i_68k_CPU_D_RnW,

		-- cpu socket signals
		CPUSKT_D_i								=> CPUSKT_D_io,

		CPUSKT_A_i								=> CPUSKT_A_i,
		CPUSKT_6EKEZnRD_i						=> CPUSKT_6EKEZnRD_i,
		CPUSKT_C6nML9BUSYKnBGZnBUSACK_i	=> CPUSKT_C6nML9BUSYKnBGZnBUSACK_i,
		CPUSKT_RnWZnWR_i						=> CPUSKT_RnWZnWR_i,
		CPUSKT_PHI16ABRT9BSKnDS_i			=> CPUSKT_PHI16ABRT9BSKnDS_i,
		CPUSKT_PHI26VDAKFC0ZnMREQ_i		=> CPUSKT_PHI26VDAKFC0ZnMREQ_i,
		CPUSKT_SYNC6VPA9LICKFC2ZnM1_i		=> CPUSKT_SYNC6VPA9LICKFC2ZnM1_i,
		CPUSKT_VSS6VPA9BAKnAS_i				=> CPUSKT_VSS6VPA9BAKnAS_i,
		CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i	=> CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i,
		CPUSKT_6BE9TSCKnVPA_o				=> i_68k_CPUSKT_6BE9TSCKnVPA,
		CPUSKT_9Q_o								=> i_68k_CPUSKT_9Q,
		CPUSKT_KnBRZnBUSREQ_o				=> i_68k_CPUSKT_KnBRZnBUSREQ,
		CPUSKT_PHI09EKZCLK_o					=> i_68k_CPUSKT_PHI09EKZCLK,
		CPUSKT_RDY9KnHALTZnWAIT_o			=> i_68k_CPUSKT_RDY9KnHALTZnWAIT,
		CPUSKT_nIRQKnIPL1_o					=> i_68k_CPUSKT_nIRQKnIPL1,
		CPUSKT_nNMIKnIPL02_o					=> i_68k_CPUSKT_nNMIKnIPL02,
		CPUSKT_nRES_o							=> i_68k_CPUSKT_nRES,
		CPUSKT_9nFIRQLnDTACK_o				=> i_68k_CPUSKT_9nFIRQLnDTACK,

		jim_en_i									=> jim_en_i
	);




--
--	e_wrap_6502:entity work.fb_cpu_6502
--	generic map (
--		SIM										=> SIM,
--		G_JIM_DEVNO								=> G_JIM_DEVNO
--	) 
--	port map(
--
--		-- configuration
--		cpu_en_i									=> i_cpu_en_6502,
--		fb_syscon_i								=> fb_syscon_i,
--
--		-- noice debugger signals to cpu
--		noice_debug_nmi_n_i					=> noice_debug_nmi_n_i,
--		noice_debug_shadow_i					=> noice_debug_shadow_i,
--		noice_debug_inhibit_cpu_i			=> noice_debug_inhibit_cpu_i,
--																				-- spurious memory accesses
--		-- noice debugger signals from cpu
--		noice_debug_5c_o						=> i_6502_noice_debug_5c,
--		noice_debug_cpu_clken_o				=> i_6502_noice_debug_cpu_clken,
--		noice_debug_A0_tgl_o					=> i_6502_noice_debug_A0_tgl,
--		noice_debug_opfetch_o				=> i_6502_noice_debug_opfetch,
--
--		-- direct CPU control signals from system
--		nmi_n_i									=> nmi_n_i,
--		irq_n_i									=> irq_n_i,
--
--		-- state machine signals
--		wrap_cyc_o								=> i_6502_wrap_cyc,
--		wrap_A_log_o							=> i_6502_wrap_A_log,
--		wrap_A_we_o								=> i_6502_wrap_we,
--		wrap_D_WR_stb_o						=> i_6502_wrap_D_WR_stb,
--		wrap_D_WR_o								=> i_6502_wrap_D_WR,
--		wrap_ack_o								=> i_6502_wrap_ack,
--
--		wrap_dtack_i							=> fb_s2m_i.dtack,
--		wrap_rdy_ctdn_i						=> fb_s2m_i.rdy_ctdn,
--		wrap_cyc_i								=> r_wrap_cyc,
--
--		-- chipset control signals
--		cpu_halt_i								=> cpu_halt_i,
--
--		CPU_D_RnW_o								=> i_6502_CPU_D_RnW,
--
--		-- cpu socket signals
--		CPUSKT_D_i								=> CPUSKT_D_io,
--
--		CPUSKT_A_i								=> CPUSKT_A_i,
--		CPUSKT_6EKEZnRD_i						=> CPUSKT_6EKEZnRD_i,
--		CPUSKT_C6nML9BUSYKnBGZnBUSACK_i	=> CPUSKT_C6nML9BUSYKnBGZnBUSACK_i,
--		CPUSKT_RnWZnWR_i						=> CPUSKT_RnWZnWR_i,
--		CPUSKT_PHI16ABRT9BSKnDS_i			=> CPUSKT_PHI16ABRT9BSKnDS_i,
--		CPUSKT_PHI26VDAKFC0ZnMREQ_i		=> CPUSKT_PHI26VDAKFC0ZnMREQ_i,
--		CPUSKT_SYNC6VPA9LICKFC2ZnM1_i		=> CPUSKT_SYNC6VPA9LICKFC2ZnM1_i,
--		CPUSKT_VSS6VPA9BAKnAS_i				=> CPUSKT_VSS6VPA9BAKnAS_i,
--		CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i	=> CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i,
--		CPUSKT_6BE9TSCKnVPA_o				=> i_6502_CPUSKT_6BE9TSCKnVPA,
--		CPUSKT_9Q_o								=> i_6502_CPUSKT_9Q,
--		CPUSKT_KnBRZnBUSREQ_o				=> i_6502_CPUSKT_KnBRZnBUSREQ,
--		CPUSKT_PHI09EKZCLK_o					=> i_6502_CPUSKT_PHI09EKZCLK,
--		CPUSKT_RDY9KnHALTZnWAIT_o			=> i_6502_CPUSKT_RDY9KnHALTZnWAIT,
--		CPUSKT_nIRQKnIPL1_o					=> i_6502_CPUSKT_nIRQKnIPL1,
--		CPUSKT_nNMIKnIPL02_o					=> i_6502_CPUSKT_nNMIKnIPL02,
--		CPUSKT_nRES_o							=> i_6502_CPUSKT_nRES,
--		CPUSKT_9nFIRQLnDTACK_o				=> i_6502_CPUSKT_9nFIRQLnDTACK,
--
--		jim_en_i									=> r_JIM_en
--	);
--
	e_wrap_65c02:entity work.fb_cpu_65c02
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED
	) 
	port map(

		-- configuration
		cpu_en_i									=> i_cpu_en_65c02,
		cpu_speed_i								=> cfg_hard_cpu_speed_i,	
		fb_syscon_i								=> fb_syscon_i,

		-- noice debugger signals to cpu
		noice_debug_nmi_n_i					=> noice_debug_nmi_n_i,
		noice_debug_shadow_i					=> noice_debug_shadow_i,
		noice_debug_inhibit_cpu_i			=> noice_debug_inhibit_cpu_i,
																				-- spurious memory accesses
		-- noice debugger signals from cpu
		noice_debug_5c_o						=> i_65c02_noice_debug_5c,
		noice_debug_cpu_clken_o				=> i_65c02_noice_debug_cpu_clken,
		noice_debug_A0_tgl_o					=> i_65c02_noice_debug_A0_tgl,
		noice_debug_opfetch_o				=> i_65c02_noice_debug_opfetch,

		-- cpu throttle
		throttle_cpu_2MHz_i 					=> throttle_cpu_2MHz_i,
		cpu_2MHz_phi2_clken_i				=> cpu_2MHz_phi2_clken_i,

		-- direct CPU control signals from system
		nmi_n_i									=> r_nmi,
		irq_n_i									=> irq_n_i,

		-- state machine signals
		wrap_cyc_o								=> i_65c02_wrap_cyc,
		wrap_A_log_o							=> i_65c02_wrap_A_log,
		wrap_A_we_o								=> i_65c02_wrap_we,
		wrap_D_WR_stb_o						=> i_65c02_wrap_D_WR_stb,
		wrap_D_WR_o								=> i_65c02_wrap_D_WR,
		wrap_ack_o								=> i_65c02_wrap_ack,

		wrap_rdy_ctdn_i						=> fb_s2m_i.rdy_ctdn,
		wrap_cyc_i								=> r_wrap_cyc,

		-- chipset control signals
		cpu_halt_i								=> cpu_halt_i,

		CPU_D_RnW_o								=> i_65c02_CPU_D_RnW,

		-- cpu socket signals
		CPUSKT_D_i								=> CPUSKT_D_io,

		CPUSKT_A_i								=> CPUSKT_A_i,
		CPUSKT_6EKEZnRD_i						=> CPUSKT_6EKEZnRD_i,
		CPUSKT_C6nML9BUSYKnBGZnBUSACK_i	=> CPUSKT_C6nML9BUSYKnBGZnBUSACK_i,
		CPUSKT_RnWZnWR_i						=> CPUSKT_RnWZnWR_i,
		CPUSKT_PHI16ABRT9BSKnDS_i			=> CPUSKT_PHI16ABRT9BSKnDS_i,
		CPUSKT_PHI26VDAKFC0ZnMREQ_i		=> CPUSKT_PHI26VDAKFC0ZnMREQ_i,
		CPUSKT_SYNC6VPA9LICKFC2ZnM1_i		=> CPUSKT_SYNC6VPA9LICKFC2ZnM1_i,
		CPUSKT_VSS6VPA9BAKnAS_i				=> CPUSKT_VSS6VPA9BAKnAS_i,
		CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i	=> CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i,
		CPUSKT_6BE9TSCKnVPA_o				=> i_65c02_CPUSKT_6BE9TSCKnVPA,
		CPUSKT_9Q_o								=> i_65c02_CPUSKT_9Q,
		CPUSKT_KnBRZnBUSREQ_o				=> i_65c02_CPUSKT_KnBRZnBUSREQ,
		CPUSKT_PHI09EKZCLK_o					=> i_65c02_CPUSKT_PHI09EKZCLK,
		CPUSKT_RDY9KnHALTZnWAIT_o			=> i_65c02_CPUSKT_RDY9KnHALTZnWAIT,
		CPUSKT_nIRQKnIPL1_o					=> i_65c02_CPUSKT_nIRQKnIPL1,
		CPUSKT_nNMIKnIPL02_o					=> i_65c02_CPUSKT_nNMIKnIPL02,
		CPUSKT_nRES_o							=> i_65c02_CPUSKT_nRES,
		CPUSKT_9nFIRQLnDTACK_o				=> i_65c02_CPUSKT_9nFIRQLnDTACK
	);

	e_wrap_65816:entity work.fb_cpu_65816
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED
	) 
	port map(

		-- configuration
		cpu_en_i									=> i_cpu_en_65816,
		fb_syscon_i								=> fb_syscon_i,

		-- noice debugger signals to cpu
		noice_debug_nmi_n_i					=> noice_debug_nmi_n_i,
		noice_debug_shadow_i					=> noice_debug_shadow_i,
		noice_debug_inhibit_cpu_i			=> noice_debug_inhibit_cpu_i,
																				-- spurious memory accesses
		-- noice debugger signals from cpu
		noice_debug_5c_o						=> i_65816_noice_debug_5c,
		noice_debug_cpu_clken_o				=> i_65816_noice_debug_cpu_clken,
		noice_debug_A0_tgl_o					=> i_65816_noice_debug_A0_tgl,
		noice_debug_opfetch_o				=> i_65816_noice_debug_opfetch,

		-- direct CPU control signals from system
		nmi_n_i									=> r_nmi,
		irq_n_i									=> irq_n_i,

		-- state machine signals
		wrap_cyc_o								=> i_65816_wrap_cyc,
		wrap_A_log_o							=> i_65816_wrap_A_log,
		wrap_A_we_o								=> i_65816_wrap_we,
		wrap_D_WR_stb_o						=> i_65816_wrap_D_WR_stb,
		wrap_D_WR_o								=> i_65816_wrap_D_WR,
		wrap_ack_o								=> i_65816_wrap_ack,

		wrap_rdy_ctdn_i						=> fb_s2m_i.rdy_ctdn,
		wrap_cyc_i								=> r_wrap_cyc,

		-- chipset control signals
		cpu_halt_i								=> cpu_halt_i,

		CPU_D_RnW_o								=> i_65816_CPU_D_RnW,

		-- cpu socket signals
		CPUSKT_D_i								=> CPUSKT_D_io,

		CPUSKT_A_i								=> CPUSKT_A_i,
		CPUSKT_6EKEZnRD_i						=> CPUSKT_6EKEZnRD_i,
		CPUSKT_C6nML9BUSYKnBGZnBUSACK_i	=> CPUSKT_C6nML9BUSYKnBGZnBUSACK_i,
		CPUSKT_RnWZnWR_i						=> CPUSKT_RnWZnWR_i,
		CPUSKT_PHI16ABRT9BSKnDS_i			=> CPUSKT_PHI16ABRT9BSKnDS_i,
		CPUSKT_PHI26VDAKFC0ZnMREQ_i		=> CPUSKT_PHI26VDAKFC0ZnMREQ_i,
		CPUSKT_SYNC6VPA9LICKFC2ZnM1_i		=> CPUSKT_SYNC6VPA9LICKFC2ZnM1_i,
		CPUSKT_VSS6VPA9BAKnAS_i				=> CPUSKT_VSS6VPA9BAKnAS_i,
		CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i	=> CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i,
		CPUSKT_6BE9TSCKnVPA_o				=> i_65816_CPUSKT_6BE9TSCKnVPA,
		CPUSKT_9Q_o								=> i_65816_CPUSKT_9Q,
		CPUSKT_KnBRZnBUSREQ_o				=> i_65816_CPUSKT_KnBRZnBUSREQ,
		CPUSKT_PHI09EKZCLK_o					=> i_65816_CPUSKT_PHI09EKZCLK,
		CPUSKT_RDY9KnHALTZnWAIT_o			=> i_65816_CPUSKT_RDY9KnHALTZnWAIT,
		CPUSKT_nIRQKnIPL1_o					=> i_65816_CPUSKT_nIRQKnIPL1,
		CPUSKT_nNMIKnIPL02_o					=> i_65816_CPUSKT_nNMIKnIPL02,
		CPUSKT_nRES_o							=> i_65816_CPUSKT_nRES,
		CPUSKT_9nFIRQLnDTACK_o				=> i_65816_CPUSKT_9nFIRQLnDTACK,

		boot_65816_i							=> boot_65816_i,

		debug_vma_o								=> debug_65816_vma_o
	);

	-- multiplex control signals

	i_wrap_cyc				<= i_t65_wrap_cyc				when cfg_t65_i = '1' else
									i_6x09_wrap_cyc			when cfg_hard_cpu_type_i = cpu_6x09 else
									i_z80_wrap_cyc				when cfg_hard_cpu_type_i = cpu_z80 else
									i_68k_wrap_cyc				when cfg_hard_cpu_type_i = cpu_68008 else
--									i_6502_wrap_cyc			when cfg_hard_cpu_type_i = cpu_6502 else
									i_65c02_wrap_cyc			when cfg_hard_cpu_type_i = cpu_65c02 else
									i_65816_wrap_cyc			when cfg_hard_cpu_type_i = cpu_65816 else
									'0';	

	i_wrap_A_log			<= i_t65_wrap_A_log			when cfg_t65_i = '1' else
									i_6x09_wrap_A_log			when cfg_hard_cpu_type_i = cpu_6x09 else
									i_z80_wrap_A_log			when cfg_hard_cpu_type_i = cpu_z80 else
									i_68k_wrap_A_log			when cfg_hard_cpu_type_i = CPU_68008 else
--									i_6502_wrap_A_log			when cfg_hard_cpu_type_i = CPU_6502 else
									i_65c02_wrap_A_log		when cfg_hard_cpu_type_i = CPU_65c02 else
									i_65816_wrap_A_log		when cfg_hard_cpu_type_i = CPU_65816 else
									(others => '0');
	i_wrap_we				<= i_t65_wrap_we				when cfg_t65_i = '1' else
									i_6x09_wrap_we				when cfg_hard_cpu_type_i = cpu_6x09 else
									i_z80_wrap_we				when cfg_hard_cpu_type_i = cpu_z80 else
									i_68k_wrap_we				when cfg_hard_cpu_type_i = cpu_68008 else
--									i_6502_wrap_we				when cfg_hard_cpu_type_i = cpu_6502 else
									i_65c02_wrap_we			when cfg_hard_cpu_type_i = cpu_65c02 else
									i_65816_wrap_we			when cfg_hard_cpu_type_i = cpu_65816 else
									'0';			
	i_wrap_D_WR_stb		<= i_t65_wrap_D_WR_stb		when cfg_t65_i = '1' else
									i_6x09_wrap_D_WR_stb		when cfg_hard_cpu_type_i = cpu_6x09 else
									i_z80_wrap_D_WR_stb		when cfg_hard_cpu_type_i = cpu_z80 else
									i_68k_wrap_D_WR_stb		when cfg_hard_cpu_type_i = cpu_68008 else
--									i_6502_wrap_D_WR_stb		when cfg_hard_cpu_type_i = cpu_6502 else
									i_65c02_wrap_D_WR_stb	when cfg_hard_cpu_type_i = cpu_65c02 else
									i_65816_wrap_D_WR_stb	when cfg_hard_cpu_type_i = cpu_65816 else
									'0';
	i_wrap_D_WR				<= i_t65_wrap_D_WR			when cfg_t65_i = '1' else
									i_6x09_wrap_D_WR			when cfg_hard_cpu_type_i = cpu_6x09 else
									i_z80_wrap_D_WR			when cfg_hard_cpu_type_i = cpu_z80 else
									i_68k_wrap_D_WR			when cfg_hard_cpu_type_i = cpu_68008 else
--									i_6502_wrap_D_WR			when cfg_hard_cpu_type_i = cpu_6502 else
									i_65c02_wrap_D_WR			when cfg_hard_cpu_type_i = cpu_65c02 else
									i_65816_wrap_D_WR			when cfg_hard_cpu_type_i = cpu_65816 else
									(others => '0');			
	i_wrap_ack				<= i_t65_wrap_ack				when cfg_t65_i = '1' else
									i_6x09_wrap_ack			when cfg_hard_cpu_type_i = cpu_6x09 else
									i_z80_wrap_ack				when cfg_hard_cpu_type_i = cpu_z80 else
									i_68k_wrap_ack				when cfg_hard_cpu_type_i = cpu_68008 else
--									i_6502_wrap_ack			when cfg_hard_cpu_type_i = cpu_6502 else
									i_65c02_wrap_ack			when cfg_hard_cpu_type_i = cpu_65c02 else
									i_65816_wrap_ack			when cfg_hard_cpu_type_i = cpu_65816 else
									'0';			

	-- multiplex CPUSKT output signals

	CPUSKT_6BE9TSCKnVPA_o 		<= i_6x09_CPUSKT_6BE9TSCKnVPA			when cfg_hard_cpu_type_i = cpu_6x09 else
											i_z80_CPUSKT_6BE9TSCKnVPA			when cfg_hard_cpu_type_i = cpu_z80 else
											i_68k_CPUSKT_6BE9TSCKnVPA			when cfg_hard_cpu_type_i = cpu_68008 else
											--i_6502_CPUSKT_6BE9TSCKnVPA			when cfg_hard_cpu_type_i = cpu_6502 else
											i_65c02_CPUSKT_6BE9TSCKnVPA		when cfg_hard_cpu_type_i = cpu_65c02 else
											i_65816_CPUSKT_6BE9TSCKnVPA		when cfg_hard_cpu_type_i = cpu_65816 else
											'0';
	CPUSKT_9Q_o 					<= i_6x09_CPUSKT_9Q						when cfg_hard_cpu_type_i = cpu_6x09 else
											i_z80_CPUSKT_9Q						when cfg_hard_cpu_type_i = cpu_z80 else
											i_68k_CPUSKT_9Q						when cfg_hard_cpu_type_i = cpu_68008 else
											--i_6502_CPUSKT_9Q						when cfg_hard_cpu_type_i = cpu_6502 else
											i_65c02_CPUSKT_9Q						when cfg_hard_cpu_type_i = cpu_65c02 else
											i_65816_CPUSKT_9Q						when cfg_hard_cpu_type_i = cpu_65816 else
											'1';
	CPUSKT_KnBRZnBUSREQ_o 		<= i_6x09_CPUSKT_KnBRZnBUSREQ			when cfg_hard_cpu_type_i = cpu_6x09 else
											i_z80_CPUSKT_KnBRZnBUSREQ			when cfg_hard_cpu_type_i = cpu_z80 else
											i_68k_CPUSKT_KnBRZnBUSREQ			when cfg_hard_cpu_type_i = cpu_68008 else
											--i_6502_CPUSKT_KnBRZnBUSREQ			when cfg_hard_cpu_type_i = cpu_6502 else
											i_65c02_CPUSKT_KnBRZnBUSREQ		when cfg_hard_cpu_type_i = cpu_65c02 else
											i_65816_CPUSKT_KnBRZnBUSREQ		when cfg_hard_cpu_type_i = cpu_65816 else
											'1';
	CPUSKT_PHI09EKZCLK_o 		<= i_6x09_CPUSKT_PHI09EKZCLK			when cfg_hard_cpu_type_i = cpu_6x09 else
											i_z80_CPUSKT_PHI09EKZCLK			when cfg_hard_cpu_type_i = cpu_z80 else
											i_68k_CPUSKT_PHI09EKZCLK			when cfg_hard_cpu_type_i = cpu_68008 else
											--i_6502_CPUSKT_PHI09EKZCLK			when cfg_hard_cpu_type_i = cpu_6502 else
											i_65c02_CPUSKT_PHI09EKZCLK			when cfg_hard_cpu_type_i = cpu_65c02 else
											i_65816_CPUSKT_PHI09EKZCLK			when cfg_hard_cpu_type_i = cpu_65816 else
											'1';
	CPUSKT_RDY9KnHALTZnWAIT_o 	<= i_6x09_CPUSKT_RDY9KnHALTZnWAIT	when cfg_hard_cpu_type_i = cpu_6x09 else
											i_z80_CPUSKT_RDY9KnHALTZnWAIT		when cfg_hard_cpu_type_i = cpu_z80 else
											i_68k_CPUSKT_RDY9KnHALTZnWAIT		when cfg_hard_cpu_type_i = cpu_68008 else
											--i_6502_CPUSKT_RDY9KnHALTZnWAIT	when cfg_hard_cpu_type_i = cpu_6502 else
											i_65c02_CPUSKT_RDY9KnHALTZnWAIT	when cfg_hard_cpu_type_i = cpu_65c02 else
											i_65816_CPUSKT_RDY9KnHALTZnWAIT	when cfg_hard_cpu_type_i = cpu_65816 else
											'1';
	CPUSKT_nIRQKnIPL1_o 			<= i_6x09_CPUSKT_nIRQKnIPL1			when cfg_hard_cpu_type_i = cpu_6x09 else
											i_z80_CPUSKT_nIRQKnIPL1				when cfg_hard_cpu_type_i = cpu_z80 else
											i_68k_CPUSKT_nIRQKnIPL1				when cfg_hard_cpu_type_i = cpu_68008 else
											--i_6502_CPUSKT_nIRQKnIPL1			when cfg_hard_cpu_type_i = cpu_6502 else
											i_65c02_CPUSKT_nIRQKnIPL1			when cfg_hard_cpu_type_i = cpu_65c02 else
											i_65816_CPUSKT_nIRQKnIPL1			when cfg_hard_cpu_type_i = cpu_65816 else
											'1';
	CPUSKT_nNMIKnIPL02_o 		<= i_6x09_CPUSKT_nNMIKnIPL02			when cfg_hard_cpu_type_i = cpu_6x09 else
											i_z80_CPUSKT_nNMIKnIPL02			when cfg_hard_cpu_type_i = cpu_z80 else
											i_68k_CPUSKT_nNMIKnIPL02			when cfg_hard_cpu_type_i = cpu_68008 else
											--i_6502_CPUSKT_nNMIKnIPL02			when cfg_hard_cpu_type_i = cpu_6502 else
											i_65c02_CPUSKT_nNMIKnIPL02			when cfg_hard_cpu_type_i = cpu_65c02 else
											i_65816_CPUSKT_nNMIKnIPL02			when cfg_hard_cpu_type_i = cpu_65816 else
											'1';
	CPUSKT_nRES_o 					<= i_6x09_CPUSKT_nRES					when cfg_hard_cpu_type_i = cpu_6x09 else
											i_z80_CPUSKT_nRES						when cfg_hard_cpu_type_i = cpu_z80 else
											i_68k_CPUSKT_nRES						when cfg_hard_cpu_type_i = cpu_68008 else
											--i_6502_CPUSKT_nRES					when cfg_hard_cpu_type_i = cpu_6502 else
											i_65c02_CPUSKT_nRES					when cfg_hard_cpu_type_i = cpu_65c02 else
											i_65816_CPUSKT_nRES					when cfg_hard_cpu_type_i = cpu_65816 else
											'0';
	CPUSKT_9nFIRQLnDTACK_o 		<= i_6x09_CPUSKT_9nFIRQLnDTACK		when cfg_hard_cpu_type_i = cpu_6x09 else
											i_z80_CPUSKT_9nFIRQLnDTACK			when cfg_hard_cpu_type_i = cpu_z80 else
											i_68k_CPUSKT_9nFIRQLnDTACK			when cfg_hard_cpu_type_i = cpu_68008 else
											--i_6502_CPUSKT_9nFIRQLnDTACK		when cfg_hard_cpu_type_i = cpu_6502 else
											i_65c02_CPUSKT_9nFIRQLnDTACK		when cfg_hard_cpu_type_i = cpu_65c02 else
											i_65816_CPUSKT_9nFIRQLnDTACK		when cfg_hard_cpu_type_i = cpu_65816 else
											'1';


	i_CPU_D_RnW <= '0' 						when cfg_t65_i = '1' else
						i_6x09_CPU_D_RnW 		when cfg_hard_cpu_type_i = cpu_6x09 else
						i_z80_CPU_D_RnW		when cfg_hard_cpu_type_i = cpu_z80 else
						i_68k_CPU_D_RnW		when cfg_hard_cpu_type_i = cpu_68008 else
--						i_6502_CPU_D_RnW		when cfg_hard_cpu_type_i = cpu_6502 else
						i_65c02_CPU_D_RnW		when cfg_hard_cpu_type_i = cpu_65c02 else
						i_65816_CPU_D_RnW		when cfg_hard_cpu_type_i = cpu_65816 else
						'0';


	-- multiplex noice signals

	noice_debug_5c_o				<= i_t65_noice_debug_5c 			when cfg_t65_i = '1' else
											i_6x09_noice_debug_5c			when cfg_hard_cpu_type_i = cpu_6x09 else
											i_z80_noice_debug_5c				when cfg_hard_cpu_type_i = cpu_z80 else
											i_68k_noice_debug_5c				when cfg_hard_cpu_type_i = cpu_68008 else
--											i_6502_noice_debug_5c			when cfg_hard_cpu_type_i = cpu_6502 else
											i_65c02_noice_debug_5c			when cfg_hard_cpu_type_i = cpu_65c02 else
											i_65816_noice_debug_5c			when cfg_hard_cpu_type_i = cpu_65816 else
											'0';
	noice_debug_cpu_clken_o		<= i_t65_noice_debug_cpu_clken 	when cfg_t65_i = '1' else
											i_6x09_noice_debug_cpu_clken	when cfg_hard_cpu_type_i = cpu_6x09 else
											i_z80_noice_debug_cpu_clken	when cfg_hard_cpu_type_i = cpu_z80 else
											i_68k_noice_debug_cpu_clken	when cfg_hard_cpu_type_i = cpu_68008 else
--											i_6502_noice_debug_cpu_clken	when cfg_hard_cpu_type_i = cpu_6502 else
											i_65c02_noice_debug_cpu_clken	when cfg_hard_cpu_type_i = cpu_65c02 else
											i_65816_noice_debug_cpu_clken	when cfg_hard_cpu_type_i = cpu_65816 else
											'0';
	noice_debug_A0_tgl_o			<= i_t65_noice_debug_A0_tgl 		when cfg_t65_i = '1' else
											i_6x09_noice_debug_A0_tgl		when cfg_hard_cpu_type_i = cpu_6x09 else
											i_z80_noice_debug_A0_tgl		when cfg_hard_cpu_type_i = cpu_z80 else
											i_68k_noice_debug_A0_tgl		when cfg_hard_cpu_type_i = cpu_68008 else
--											i_6502_noice_debug_A0_tgl		when cfg_hard_cpu_type_i = cpu_6502 else
											i_65c02_noice_debug_A0_tgl		when cfg_hard_cpu_type_i = cpu_65c02 else
											i_65816_noice_debug_A0_tgl		when cfg_hard_cpu_type_i = cpu_65816 else
											'0';
	noice_debug_opfetch_o		<= i_t65_noice_debug_opfetch 		when cfg_t65_i = '1' else
											i_6x09_noice_debug_opfetch		when cfg_hard_cpu_type_i = cpu_6x09 else
											i_z80_noice_debug_opfetch		when cfg_hard_cpu_type_i = cpu_z80 else
											i_68k_noice_debug_opfetch		when cfg_hard_cpu_type_i = cpu_68008 else
--											i_6502_noice_debug_opfetch		when cfg_hard_cpu_type_i = cpu_6502 else
											i_65c02_noice_debug_opfetch	when cfg_hard_cpu_type_i = cpu_65c02 else
											i_65816_noice_debug_opfetch	when cfg_hard_cpu_type_i = cpu_65816 else
											'0';

end rtl;

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
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the CPU sockets on the mk.3 blitter board
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--		This component provides a fishbone controller wrapper around the CPU socket _and_ the T65
--	core. The actual device in use is selected by the configuration on ports F/G.
--		Each type of processor is split out into its own wrapper named fb_CPU_<cpu name>  - these are not
-- fishbone wrappers per-se but instead provide a simplified set of signals to enable the state machine
-- to direct the fishbone controller interface. This was done to simplify development and may well need to 
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
use work.mk3blit_pack.all;

entity fb_cpu is
	generic (
		G_NMI_META_LEVELS					: natural := 5;
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;										-- fast clock speed in mhz						
		G_INCL_CPU_T65						: boolean := false;
		G_INCL_CPU_65C02					: boolean := false;
		G_INCL_CPU_6800					: boolean := false;
		G_INCL_CPU_65816					: boolean := false;
		G_INCL_CPU_6x09					: boolean := false;
		G_INCL_CPU_Z80						: boolean := false;
		G_INCL_CPU_68k						: boolean := false;

		G_BYTELANES							: positive := 2									-- number of data byte lanes
	);
	port(

		-- configuration

		cfg_do6502_debug_o					: out std_logic;
		cfg_mk2_cpubits_o						: out std_logic_vector(2 downto 0);		-- mk.2 compatible cpu type TODO: get rid?
		cfg_softt65_o							: out std_logic;

		cfg_sys_type_i							: in sys_type;
		cfg_swram_enable_i					: in std_logic;
		cfg_mosram_i							: in std_logic;
		cfg_swromx_i							: in std_logic;


		-- cpu throttle
		throttle_cpu_2MHz_i					: in std_logic;
		cpu_2MHz_phi2_clken_i				: in std_logic;

		-- cpu / expansion sockets (56)

		exp_PORTA_io							: inout	std_logic_vector(7 downto 0);
		exp_PORTA_nOE_o						: out		std_logic;
		exp_PORTA_DIR_o						: out		std_logic;

		exp_PORTB_o								: out		std_logic_vector(7 downto 0);

		exp_PORTC_io							: inout 	std_logic_vector(11 downto 0);
		exp_PORTD_io							: inout	std_logic_vector(11 downto 0);

		exp_PORTEFG_io							: inout	std_logic_vector(11 downto 0);
		exp_PORTE_nOE_o						: out		std_logic;
		exp_PORTF_nOE_o						: out		std_logic;
		exp_PORTG_nOE_o						: out		std_logic;

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

		debug_iorb_block_o					: out std_logic

	);
end fb_cpu;

architecture rtl of fb_cpu is

	-----------------------------------------------------------------------------
	-- configuration registers read at boot time
	-----------------------------------------------------------------------------
	

	signal r_cfg_hard_cpu_type	: cpu_type;
	signal r_cfg_cpubits			: std_logic_vector(2 downto 0); 
	signal r_cfg_do6502_debug_o: std_logic;

	signal r_cfg_pins_cpu_speed: std_logic_vector(2 downto 0);
	signal r_cfg_pins_cpu_type	: std_logic_vector(3 downto 0);



	-----------------------------------------------------------------------------
	-- cpu mapping signals
	-----------------------------------------------------------------------------


	signal	i_CPUSKT_A_i								:std_logic_vector(23 downto 0);

	signal	i_exp_PORTB_o								:std_logic_vector(7 downto 0);
	signal	i_exp_PORTD_o								:std_logic_vector(11 downto 0);
	signal	i_exp_PORTD_o_en							:std_logic_vector(11 downto 0);
	signal	i_exp_PORTE_nOE							: std_logic;	-- enable that multiplexed buffer chip
	signal	i_exp_PORTF_nOE							: std_logic;	-- enable that multiplexed buffer chip - 16 bit cpu high data byte


-- number of 128MHz cycles until we will allow between two accesses to SYS VIA IORB
	constant C_IORB_BODGE_MAX : natural := CLOCKSPEED * 10;

	signal r_iorb_block 			: std_logic;
	signal r_iorb_block_ctdn 	: unsigned(NUMBITS(C_IORB_BODGE_MAX) downto 0);
	signal i_iorb_cs				: std_logic;
	signal r_iorb_cs				: std_logic;
	signal r_iorb_resetctr		: std_logic;

	-- wrapper enable signals
	signal r_cpu_en_t65 : std_logic;
	signal r_cpu_en_6x09 : std_logic;
	signal r_cpu_en_z80 : std_logic;
	signal r_cpu_en_68k : std_logic;
--	signal r_cpu_en_6502 : std_logic;
	signal r_cpu_en_65c02 : std_logic;
	signal r_cpu_en_6800 : std_logic;
	signal r_cpu_en_65816 : std_logic;

	type state_t is (
		s_idle							-- waiting for address ready signal from cpu wrapper
		, s_waitack						-- wait for ack from cpu
		, iorb_blocked					-- pause on iorb
		);

	signal r_state				: state_t;

	signal r_D_rd				: std_logic_vector((G_BYTELANES*8)-1 downto 0);
	signal r_acked 			: std_logic_vector(G_BYTELANES-1 downto 0);

	-- per-wrapper control signals

	signal i_t65_wrap_cyc			: std_logic_vector(G_BYTELANES-1 downto 0);
	signal i_t65_wrap_A_log			: std_logic_vector(23 downto 0);
	signal i_t65_wrap_we				: std_logic;
	signal i_t65_wrap_D_WR_stb		: std_logic;
	signal i_t65_wrap_D_WR			: std_logic_vector(7 downto 0);
	signal i_t65_wrap_ack			: std_logic;

--	signal i_6502_wrap_cyc			: std_logic_vector(G_BYTELANES-1 downto 0);
--	signal i_6502_wrap_A_log		: std_logic_vector(23 downto 0);
--	signal i_6502_wrap_we			: std_logic;
--	signal i_6502_wrap_D_WR_stb	: std_logic;
--	signal i_6502_wrap_D_WR			: std_logic_vector(7 downto 0);
--	signal i_6502_wrap_ack_l		: std_logic;
--	signal i_6502_wrap_ack_h		: std_logic;
--
	signal i_65c02_wrap_cyc			: std_logic_vector(G_BYTELANES-1 downto 0);
	signal i_65c02_wrap_A_log		: std_logic_vector(23 downto 0);
	signal i_65c02_wrap_we			: std_logic;
	signal i_65c02_wrap_D_WR_stb	: std_logic;
	signal i_65c02_wrap_D_WR		: std_logic_vector(7 downto 0);
	signal i_65c02_wrap_ack			: std_logic;

	signal i_6800_wrap_cyc			: std_logic_vector(G_BYTELANES-1 downto 0);
	signal i_6800_wrap_A_log		: std_logic_vector(23 downto 0);
	signal i_6800_wrap_we			: std_logic;
	signal i_6800_wrap_D_WR_stb	: std_logic;
	signal i_6800_wrap_D_WR			: std_logic_vector(7 downto 0);
	signal i_6800_wrap_ack			: std_logic;


	signal i_65816_wrap_cyc			: std_logic_vector(G_BYTELANES-1 downto 0);
	signal i_65816_wrap_A_log		: std_logic_vector(23 downto 0);
	signal i_65816_wrap_we			: std_logic;
	signal i_65816_wrap_D_WR_stb	: std_logic;
	signal i_65816_wrap_D_WR		: std_logic_vector(7 downto 0);
	signal i_65816_wrap_ack			: std_logic;

	signal i_6x09_wrap_cyc			: std_logic_vector(G_BYTELANES-1 downto 0);
	signal i_6x09_wrap_A_log		: std_logic_vector(23 downto 0);
	signal i_6x09_wrap_we			: std_logic;
	signal i_6x09_wrap_D_WR_stb	: std_logic;
	signal i_6x09_wrap_D_WR			: std_logic_vector(7 downto 0);
	signal i_6x09_wrap_ack			: std_logic;

	signal i_z80_wrap_cyc			: std_logic_vector(G_BYTELANES-1 downto 0);
	signal i_z80_wrap_A_log			: std_logic_vector(23 downto 0);
	signal i_z80_wrap_we				: std_logic;
	signal i_z80_wrap_D_WR_stb		: std_logic;
	signal i_z80_wrap_D_WR			: std_logic_vector(7 downto 0);
	signal i_z80_wrap_ack			: std_logic;

	signal i_68k_wrap_cyc			: std_logic_vector(G_BYTELANES-1 downto 0);
	signal i_68k_wrap_A_log			: std_logic_vector(23 downto 0);
	signal i_68k_wrap_we				: std_logic;
	signal i_68k_wrap_D_WR_stb		: std_logic;
	signal i_68k_wrap_D_WR			: std_logic_vector(7 downto 0);
	signal i_68k_wrap_ack			: std_logic;


	-- multiplexed control signals
	signal i_wrap_cyc					: std_logic_vector(G_BYTELANES-1 downto 0);		-- each bit here indicates a byte lane high to low being read/written
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

	signal i_wrap_D_rd				: std_logic_vector(15 downto 0);

	-- cpu socket outputs multiplex

	signal i_6x09_exp_PORTB_o					: std_logic_vector(7 downto 0);
	signal i_6x09_exp_PORTD_o					: std_logic_vector(11 downto 0);
	signal i_6x09_exp_PORTD_o_en				: std_logic_vector(11 downto 0);
	signal i_6x09_exp_PORTE_nOE				: std_logic;	
	signal i_6x09_exp_PORTF_nOE				: std_logic;	


	signal i_z80_exp_PORTB_o					: std_logic_vector(7 downto 0);
	signal i_z80_exp_PORTD_o					: std_logic_vector(11 downto 0);
	signal i_z80_exp_PORTD_o_en				: std_logic_vector(11 downto 0);
	signal i_z80_exp_PORTE_nOE					: std_logic;	
	signal i_z80_exp_PORTF_nOE					: std_logic;	

	signal i_68k_exp_PORTB_o					: std_logic_vector(7 downto 0);
	signal i_68k_exp_PORTD_o					: std_logic_vector(11 downto 0);
	signal i_68k_exp_PORTD_o_en				: std_logic_vector(11 downto 0);
	signal i_68k_exp_PORTE_nOE					: std_logic;	
	signal i_68k_exp_PORTF_nOE					: std_logic;	


--	signal i_6502_exp_PORTB_o					: std_logic_vector(7 downto 0);
--	signal i_6502_exp_PORTD_o					:std_logic_vector(11 downto 0);
--	signal i_6502_exp_PORTD_o_en				:std_logic_vector(11 downto 0);
--	signal i_6502_exp_PORTE_nOE				: std_logic;	
--	signal i_6502_exp_PORTF_nOE				: std_logic;	
--	signal i_6502_exp_PORTF_DIR				: std_logic_vector(11 downto 0);	
--	signal i_6502_exp_PORTF_o					: std_logic_vector(11 downto 0);

--
	signal i_65c02_exp_PORTB_o					: std_logic_vector(7 downto 0);
	signal i_65c02_exp_PORTD_o					: std_logic_vector(11 downto 0);
	signal i_65c02_exp_PORTD_o_en				: std_logic_vector(11 downto 0);
	signal i_65c02_exp_PORTE_nOE				: std_logic;	
	signal i_65c02_exp_PORTF_nOE				: std_logic;	

	signal i_6800_exp_PORTB_o					: std_logic_vector(7 downto 0);
	signal i_6800_exp_PORTD_o					: std_logic_vector(11 downto 0);
	signal i_6800_exp_PORTD_o_en				: std_logic_vector(11 downto 0);
	signal i_6800_exp_PORTE_nOE				: std_logic;	
	signal i_6800_exp_PORTF_nOE				: std_logic;	

	signal i_65816_exp_PORTB_o					: std_logic_vector(7 downto 0);
	signal i_65816_exp_PORTD_o					: std_logic_vector(11 downto 0);
	signal i_65816_exp_PORTD_o_en				: std_logic_vector(11 downto 0);
	signal i_65816_exp_PORTE_nOE				: std_logic;	
	signal i_65816_exp_PORTF_nOE				: std_logic;	


	-- buffer direction multiples
	-- buffer direction for CPU_D_io '1' for read into cpu
	signal i_t65_CPU_D_RnW						: std_logic;		
--	signal i_6502_CPU_D_RnW						: std_logic;		
	signal i_65c02_CPU_D_RnW					: std_logic;			
	signal i_6800_CPU_D_RnW						: std_logic;			
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

	signal i_6800_noice_debug_5c				:	std_logic;
	signal i_6800_noice_debug_cpu_clken		:	std_logic;
	signal i_6800_noice_debug_A0_tgl			:	std_logic;
	signal i_6800_noice_debug_opfetch		:	std_logic;

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

	signal r_hard_cpu_en							: 	std_logic;


	signal r_nmi				: std_logic;

	signal r_nmi_meta			: std_logic_vector(G_NMI_META_LEVELS-1 downto 0);

begin

	-- ================================================================================================ --
	-- BOOT TIME CONFIGURATION
	-- ================================================================================================ --
	
	cfg_mk2_cpubits_o <= r_cfg_cpubits;
	cfg_softt65_o <= r_cpu_en_t65;
	cfg_do6502_debug_o <= r_cfg_do6502_debug_o;

	-- PORTEFG nOE's selected in top level p_EFG_en process
	p_config:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then

			if fb_syscon_i.prerun(0) = '1' then
				r_cfg_pins_cpu_type <= exp_PORTEFG_io(3 downto 0);

			end if;
			if fb_syscon_i.prerun(1) = '1' then
				-- read port G at boot time
				r_cpu_en_t65 <= not exp_PORTEFG_io(3);
				--TODO: this should be all three bits
				r_cfg_pins_cpu_speed <= exp_PORTEFG_io(11 downto 9);
			end if;
			if fb_syscon_i.prerun(2) = '1' then

				r_cpu_en_6x09 <= '0';
				r_cpu_en_z80 <= '0';
				r_cpu_en_68k <= '0';
--				r_cpu_en_6502 <= '0';
				r_cpu_en_65c02 <= '0';
				r_cpu_en_6800 <= '0';
				r_cpu_en_65816 <= '0';


				if r_cpu_en_t65 = '1' 
					or r_cfg_hard_cpu_type = CPU_6502  
					or r_cfg_hard_cpu_type = CPU_65c02 
					then
					r_cfg_do6502_debug_o <= '1';
				else
					r_cfg_do6502_debug_o <= '0';
				end if;

			-- unbodge all this and work out a compatible (with mk.2) way
			-- of encoding all this, or alter BLUTILS ROM

				if r_cfg_pins_cpu_type = "1100" then
					r_cfg_hard_cpu_type <= CPU_65816;
					r_cfg_cpubits <= "001";
					r_cpu_en_65816 <= not(r_cpu_en_t65);
				elsif r_cfg_pins_cpu_type = "0011" then
					r_cfg_hard_cpu_type <= CPU_68008;
					r_cfg_cpubits <= "000";
					r_cpu_en_68k <= not(r_cpu_en_t65);
				elsif r_cfg_pins_cpu_type = "0111" then
					if r_cfg_pins_cpu_speed = "000" then
						r_cfg_hard_cpu_type <= CPU_6800;
						r_cfg_cpubits <= "110";			
						r_cpu_en_6800 <= not(r_cpu_en_t65);
					else
						r_cfg_hard_cpu_type <= CPU_6x09;
						r_cfg_cpubits <= "110";			
						r_cpu_en_6x09 <= not(r_cpu_en_t65);
					end if;
				else
					r_cfg_hard_cpu_type <= CPU_65816;
					r_cfg_cpubits <= "001";
				end if;

	--			if exp_PORTEFG_io(7 downto 4) = "1110" then
	--				r_cfg_hard_cpu_type <= CPU_65C02;
	--				r_cfg_cpubits <= "011";
	--			elsif exp_PORTEFG_io(7 downto 4) = "1100" then
	--				r_cfg_hard_cpu_type <= CPU_65816;
	--				r_cfg_cpubits <= "001";
	--			elsif exp_PORTEFG_io(7 downto 4) = "0111" then
	--				r_cfg_hard_cpu_type <= CPU_6x09;
	--				r_cfg_cpubits <= "110";
	--			elsif exp_PORTEFG_io(7 downto 4) = "0101" then
	--				r_cfg_hard_cpu_type <= CPU_Z80;
	--				r_cfg_cpubits <= "100";
	--			elsif exp_PORTEFG_io(7 downto 4) = "0011" then
	--				r_cfg_hard_cpu_type <= CPU_68008;
	--				r_cfg_cpubits <= "000";
	--			else
	--				r_cfg_hard_cpu_type <= CPU_6502;
	--				r_cfg_cpubits <= "111";
	--			end if;


				if	(r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09) or
					(r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80) or
					(r_cfg_hard_cpu_type = cpu_68008 and G_INCL_CPU_68k) or
					--(r_cfg_hard_cpu_type = cpu_6502 and G_OPT_INCLUDE_6502) or
					(r_cfg_hard_cpu_type = cpu_65c02 and G_INCL_CPU_65C02) or
					(r_cfg_hard_cpu_type = cpu_6800 and G_INCL_CPU_6800) or
					(r_cfg_hard_cpu_type = cpu_65816 and G_INCL_CPU_65816) then
					r_hard_cpu_en <= '1';
				else
					r_hard_cpu_en <= '0';
				end if;


		  	end if;


		end if;
	end process;

	-- ================================================================================================ --
	-- BUFFERS and MULTIPLEXERS
	-- ================================================================================================ --

	-- PORTA is a 74lvc4245 need to control direction and enable
	exp_PORTA_nOE_o <= not r_hard_cpu_en or fb_syscon_i.rst;
	exp_PORTA_DIR_o <= not i_CPU_D_RnW;
	exp_PORTA_io	 		<= (others => 'Z') when i_CPU_D_RnW = '0' else
									i_wrap_D_rd(7 downto 0);

	-- PORTB is hardwired output 74lvc4245

	exp_PORTB_o <= i_exp_PORTB_o;

	-- PORTC is always input only CB3T buffer, can be output but not used

	i_CPUSKT_A_i(7 downto 0) <= exp_PORTC_io(7 downto 0);
	i_CPUSKT_A_i(19 downto 16) <= exp_PORTC_io(11 downto 8);
	exp_PORTC_io <= (others => 'Z');


	-- PORTD - individual cpu wrappers control direction and direction 

	g_portd_o:for I in 11 downto 0 generate
		exp_PORTD_io(I) <= i_exp_PORTD_o(I) when i_exp_PORTD_o_en(I) = '1' else
							 'Z';
	end generate;

	-- PORTE,F,G are multiplexed CB3T's with PORTEFG_io connected to all three on one side
	-- broken out to separate pins on expansion headers on other sides
	-- to use as inputs relevant nOE needs to be asserted and data read (after a delay!)
	-- only port F is used as inputs and needs the DIR signal asserted to output data

	-- PORTE always inputs at present
	exp_PORTE_nOE_o <= i_exp_PORTE_nOE; 
	-- NOTE: address 23 downto 20, 15 downto 8 only valid when portE is enabled
	i_CPUSKT_A_i(15 downto 8) <= exp_PORTEFG_io(7 downto 0);
	i_CPUSKT_A_i(23 downto 20) <= exp_PORTEFG_io(11 downto 8);

	exp_PORTF_nOE_o <= i_exp_PORTF_nOE;

	-- PORTF data output on lines 11..4 on 16 bit cpus, 3..0 always inputs for config
	g_portefg_o:for I in 7 downto 0 generate
		exp_PORTEFG_io(I + 4) <= i_wrap_D_rd(8 + I) when i_CPU_D_RnW = '1' and i_exp_PORTF_nOE = '0' else
							 'Z';
	end generate;

	exp_PORTEFG_io(3 downto 0) <= (others => 'Z');
	
	-- PORTG only used at reset, read in top level
	exp_PORTG_nOE_o <= '1';



	debug_iorb_block_o <= '1' when r_state = iorb_blocked else '0'; 

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


	G_BL_RD:FOR I in G_BYTELANES-1 downto 0 GENERATE
		i_wrap_D_rd(7+I*8 downto I*8) <= fb_p2c_i.D_rd when r_acked(I) = '0' else 
															r_D_rd(7+I*8 downto I*8);
	END GENERATE;
	
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
			r_iorb_cs <= '0';

			r_acked <= (others => '0');
			r_iorb_resetctr <= '1';

			r_D_rd <= (others => '0');

		elsif rising_edge(fb_syscon_i.clk) then
			r_state <= r_state;

			r_iorb_resetctr <= '0';

			if (or_reduce(i_wrap_cyc) = '1' or r_wrap_cyc = '1' or r_state = iorb_blocked) and i_wrap_D_WR_stb = '1' then
				r_wrap_D_WR_stb <= '1';
				r_wrap_D_WR <= i_wrap_D_WR;
			end if;

			case r_state is
				when s_idle =>
					if or_reduce(i_wrap_cyc) = '1' then
						r_wrap_phys_A <= i_wrap_phys_A;
						if i_iorb_cs = '1' and r_iorb_block = '1' then
							r_state <= iorb_blocked;
						else
							r_state <= s_waitack;
							r_wrap_we <= i_wrap_we;
							r_wrap_cyc <= '1';
							r_iorb_cs <= i_iorb_cs;
						end if;
					end if;
				   r_acked <= not(i_wrap_cyc);
				when iorb_blocked =>
					if r_iorb_block = '0' then
						r_state <= s_waitack;
						r_wrap_we <= i_wrap_we;
						r_wrap_cyc <= '1';
						r_iorb_cs <= '1';
					end if;
				when s_waitack =>
					if i_wrap_ack = '1' then
						r_state <= s_idle;
						r_wrap_cyc <= '0';
						r_wrap_D_WR_stb <= '0';
						for I in G_BYTELANES-1 downto 0 loop
							if r_acked(I) = '0' then
								r_D_rd(7+I*8 downto I*8) <= fb_p2c_i.D_rd;
								r_acked(I) <= '1';
							end if;
						end loop;
						if r_iorb_cs = '1' then
							r_iorb_block <= '1';
							r_iorb_resetctr <= '1';
						end if;
					end if;
				when others =>
					r_state <= s_idle;
			end case;

			if r_iorb_block = '1' and
				r_iorb_block_ctdn(r_iorb_block_ctdn'high) = '1' and 
				r_iorb_resetctr = '0' then -- counter wrapped
					r_iorb_block <= '0';
			end if;

		end if;
	end process;

	piorbctdn:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			if r_iorb_resetctr = '1' then
				r_iorb_block_ctdn <= to_unsigned(C_IORB_BODGE_MAX, r_iorb_block_ctdn'length);
			elsif r_iorb_block = '1' then
				r_iorb_block_ctdn <= r_iorb_block_ctdn - 1;
			end if;
		end if;

	end process;

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

		A_i									=> i_wrap_A_log,
		A_o									=> i_wrap_phys_A,

		IORB_CS_o							=> i_iorb_cs
	);


  	fb_c2p_o.cyc <= r_wrap_cyc;
  	fb_c2p_o.we <= r_wrap_we;
  	fb_c2p_o.A <= r_wrap_phys_A;
  	fb_c2p_o.A_stb <= r_wrap_cyc;
  	fb_c2p_o.D_wr <=  r_wrap_D_wr;
  	fb_c2p_o.D_wr_stb <= r_wrap_D_wr_stb;


gt65: IF G_INCL_CPU_T65 GENERATE
	e_t65:entity work.fb_cpu_t65
	generic map (
		SIM									=> SIM,
		CLOCKSPEED							=> CLOCKSPEED,
		G_BYTELANES							=> G_BYTELANES
	)
	port map (

		-- configuration
		cpu_en_i									=> r_cpu_en_t65,
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

		wrap_rdy_ctdn_i						=> fb_p2c_i.rdy_ctdn,
		wrap_cyc_i								=> r_wrap_cyc,
		wrap_D_rd_i								=> i_wrap_D_rd(7 downto 0),

		-- chipset control signals
		cpu_halt_i								=> cpu_halt_i

	);
END GENERATE;


g6x09:IF G_INCL_CPU_6x09 GENERATE
	e_wrap_6x09:entity work.fb_cpu_6x09
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED,
		G_BYTELANES								=> G_BYTELANES
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_6x09,
		cpu_speed_i								=> r_cfg_pins_cpu_speed,
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

		wrap_rdy_ctdn_i						=> fb_p2c_i.rdy_ctdn,
		wrap_cyc_i								=> r_wrap_cyc,

		-- chipset control signals
		cpu_halt_i								=> cpu_halt_i,

		CPU_D_RnW_o								=> i_6x09_CPU_D_RnW,

		-- cpu socket signals
		CPUSKT_D_i								=> exp_PORTEFG_io(11 downto 4) & exp_PORTA_io,

		CPUSKT_A_i								=> i_CPUSKT_A_i,

		exp_PORTB_o								=> i_6x09_exp_PORTB_o,
		exp_PORTD_i								=> exp_PORTD_io,
		exp_PORTD_o								=> i_6x09_exp_PORTD_o,
		exp_PORTD_o_en							=> i_6x09_exp_PORTD_o_en,
		exp_PORTE_nOE							=> i_6x09_exp_PORTE_nOE,
		exp_PORTF_nOE							=> i_6x09_exp_PORTF_nOE
	);
END GENERATE;

g6800:IF G_INCL_CPU_6800 GENERATE
	e_wrap_6800:entity work.fb_cpu_6800
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED,
		G_BYTELANES								=> G_BYTELANES
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_6800,
		cpu_speed_i								=> r_cfg_pins_cpu_speed,
		fb_syscon_i								=> fb_syscon_i,

		-- noice debugger signals to cpu
		noice_debug_nmi_n_i					=> noice_debug_nmi_n_i,
		noice_debug_shadow_i					=> noice_debug_shadow_i,
		noice_debug_inhibit_cpu_i			=> noice_debug_inhibit_cpu_i,
																				-- spurious memory accesses
		-- noice debugger signals from cpu
		noice_debug_5c_o						=> i_6800_noice_debug_5c,
		noice_debug_cpu_clken_o				=> i_6800_noice_debug_cpu_clken,
		noice_debug_A0_tgl_o					=> i_6800_noice_debug_A0_tgl,
		noice_debug_opfetch_o				=> i_6800_noice_debug_opfetch,

		-- direct CPU control signals from system
		nmi_n_i									=> r_nmi,
		irq_n_i									=> irq_n_i,

		-- state machine signals
		wrap_cyc_o								=> i_6800_wrap_cyc,
		wrap_A_log_o							=> i_6800_wrap_A_log,
		wrap_A_we_o								=> i_6800_wrap_we,
		wrap_D_WR_stb_o						=> i_6800_wrap_D_WR_stb,
		wrap_D_WR_o								=> i_6800_wrap_D_WR,
		wrap_ack_o								=> i_6800_wrap_ack,

		wrap_rdy_ctdn_i						=> fb_p2c_i.rdy_ctdn,
		wrap_cyc_i								=> r_wrap_cyc,

		-- chipset control signals
		cpu_halt_i								=> cpu_halt_i,

		CPU_D_RnW_o								=> i_6800_CPU_D_RnW,

		-- cpu socket signals
		CPUSKT_D_i								=> exp_PORTEFG_io(11 downto 4) & exp_PORTA_io,

		CPUSKT_A_i								=> i_CPUSKT_A_i,

		exp_PORTB_o								=> i_6800_exp_PORTB_o,
		exp_PORTD_i								=> exp_PORTD_io,
		exp_PORTD_o								=> i_6800_exp_PORTD_o,
		exp_PORTD_o_en							=> i_6800_exp_PORTD_o_en,
		exp_PORTE_nOE							=> i_6800_exp_PORTE_nOE,
		exp_PORTF_nOE							=> i_6800_exp_PORTF_nOE
	);
END GENERATE;


gz80: IF G_INCL_CPU_Z80 GENERATE
	e_wrap_z80:entity work.fb_cpu_z80
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED,
		G_BYTELANES								=> G_BYTELANES
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_z80,
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

		wrap_rdy_ctdn_i						=> fb_p2c_i.rdy_ctdn,
		wrap_cyc_i								=> r_wrap_cyc,

		-- chipset control signals
		cpu_halt_i								=> cpu_halt_i,

		CPU_D_RnW_o								=> i_z80_CPU_D_RnW,

		-- cpu socket signals
		CPUSKT_D_i								=> exp_PORTEFG_io(11 downto 4) & exp_PORTA_io,

		CPUSKT_A_i								=> i_CPUSKT_A_i,

		exp_PORTB_o								=> i_z80_exp_PORTB_o,

		exp_PORTD_i								=> exp_PORTD_io,
		exp_PORTD_o								=> i_z80_exp_PORTD_o,
		exp_PORTD_o_en							=> i_z80_exp_PORTD_o_en,
		exp_PORTE_nOE							=> i_z80_exp_PORTE_nOE,
		exp_PORTF_nOE							=> i_z80_exp_PORTF_nOE

	);
END GENERATE;


g68k:IF G_INCL_CPU_68k GENERATE
	e_wrap_68k:entity work.fb_cpu_68k
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED,		
		G_BYTELANES								=> G_BYTELANES
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_68k,
		cfg_mosram_i							=> cfg_mosram_i,
		cfg_cpu_speed_i						=> r_cfg_pins_cpu_speed,		
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

		wrap_rdy_ctdn_i						=> fb_p2c_i.rdy_ctdn,
		wrap_cyc_i								=> r_wrap_cyc,

		-- chipset control signals
		cpu_halt_i								=> cpu_halt_i,

		CPU_D_RnW_o								=> i_68k_CPU_D_RnW,

		-- cpu socket signals
		CPUSKT_D_i								=> exp_PORTEFG_io(11 downto 4) & exp_PORTA_io,

		CPUSKT_A_i								=> i_CPUSKT_A_i,

		exp_PORTB_o								=> i_68k_exp_PORTB_o,

		exp_PORTD_i								=> exp_PORTD_io,
		exp_PORTD_o								=> i_68k_exp_PORTD_o,
		exp_PORTD_o_en							=> i_68k_exp_PORTD_o_en,
		exp_PORTE_nOE							=> i_68k_exp_PORTE_nOE,
		exp_PORTF_nOE							=> i_68k_exp_PORTF_nOE,

		jim_en_i									=> jim_en_i

	);
END GENERATE;


--g6502:IF G_OPT_INCLUDE_6502 GENERATE
--
--	e_wrap_6502:entity work.fb_cpu_6502
--	generic map (
--		SIM										=> SIM,
--		CLOCKSPEED								=> CLOCKSPEED,
--		G_JIM_DEVNO								=> G_JIM_DEVNO,
--		G_BYTELANES								=> G_BYTELANES
--	) 
--	port map(
--
--		-- configuration
--		cpu_en_i									=> r_cpu_en_6502,
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
--		wrap_dtack_i							=> fb_p2c_i.dtack,
--		wrap_rdy_ctdn_i						=> fb_p2c_i.rdy_ctdn,
--		wrap_cyc_i								=> r_wrap_cyc,
--
--		-- chipset control signals
--		cpu_halt_i								=> cpu_halt_i,
--
--		CPU_D_RnW_o								=> i_6502_CPU_D_RnW,
--
--		-- cpu socket signals
--		CPUSKT_D_i								=> exp_PORTEFG_io(11 downto 4) & exp_PORTA_io,
--
--		CPUSKT_A_i								=> CPUSKT_A_i,
--
--		exp_PORTB_o								=> i_6502_exp_PORTB_o,
--
--		exp_PORTD_i								=> exp_PORTD_io,
--		exp_PORTD_o								=> i_6502_exp_PORTD_o,
--		exp_PORTD_o_en							=> i_6502_exp_PORTD_o_en,
--		exp_PORTE_nOE							=> i_6502_exp_PORTE_nOE,
--		exp_PORTF_nOE							=> i_6502_exp_PORTF_nOE

--
--	);
--END GENERATE;

g65c02:IF G_INCL_CPU_65C02 GENERATE
	e_wrap_65c02:entity work.fb_cpu_65c02
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED,
		G_BYTELANES								=> G_BYTELANES
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_65c02,
		cpu_speed_i								=> r_cfg_pins_cpu_speed,	
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

		wrap_rdy_ctdn_i						=> fb_p2c_i.rdy_ctdn,
		wrap_cyc_i								=> r_wrap_cyc,

		-- chipset control signals
		cpu_halt_i								=> cpu_halt_i,

		CPU_D_RnW_o								=> i_65c02_CPU_D_RnW,

		-- cpu socket signals
		CPUSKT_D_i								=> exp_PORTEFG_io(11 downto 4) & exp_PORTA_io,

		CPUSKT_A_i								=> i_CPUSKT_A_i,

		exp_PORTB_o								=> i_65c02_exp_PORTB_o,

		exp_PORTD_i								=> exp_PORTD_io,
		exp_PORTD_o								=> i_65c02_exp_PORTD_o,
		exp_PORTD_o_en							=> i_65c02_exp_PORTD_o_en,
		exp_PORTE_nOE							=> i_65c02_exp_PORTE_nOE,
		exp_PORTF_nOE							=> i_65c02_exp_PORTF_nOE

	);
END GENERATE;


g65816:IF G_INCL_CPU_65816 GENERATE
	e_wrap_65816:entity work.fb_cpu_65816
	generic map (
		SIM										=> SIM,
		CLOCKSPEED								=> CLOCKSPEED,
		G_BYTELANES								=> G_BYTELANES
	) 
	port map(

		-- configuration
		cpu_en_i									=> r_cpu_en_65816,
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

		wrap_rdy_ctdn_i						=> fb_p2c_i.rdy_ctdn,
		wrap_cyc_i								=> r_wrap_cyc,

		-- chipset control signals
		cpu_halt_i								=> cpu_halt_i,

		CPU_D_RnW_o								=> i_65816_CPU_D_RnW,

		-- cpu socket signals
		CPUSKT_D_i								=> exp_PORTEFG_io(11 downto 4) & exp_PORTA_io,

		CPUSKT_A_i								=> i_CPUSKT_A_i,

		exp_PORTB_o								=> i_65816_exp_PORTB_o,

		exp_PORTD_i								=> exp_PORTD_io,
		exp_PORTD_o								=> i_65816_exp_PORTD_o,
		exp_PORTD_o_en							=> i_65816_exp_PORTD_o_en,
		exp_PORTE_nOE							=> i_65816_exp_PORTE_nOE,
		exp_PORTF_nOE							=> i_65816_exp_PORTF_nOE,

		boot_65816_i							=> boot_65816_i,

		debug_vma_o								=> debug_65816_vma_o
	);
END GENERATE;

	-- multiplex control signals

	i_wrap_cyc				<= i_t65_wrap_cyc				when r_cpu_en_t65 = '1' and G_INCL_CPU_T65 else
									i_6x09_wrap_cyc			when r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09 else
									i_z80_wrap_cyc				when r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80 else
									i_68k_wrap_cyc				when r_cfg_hard_cpu_type = cpu_68008 and G_INCL_CPU_68k else
--									i_6502_wrap_cyc			when r_cfg_hard_cpu_type = cpu_6502 and G_OPT_INCLUDE_6502 else
									i_65c02_wrap_cyc			when r_cfg_hard_cpu_type = cpu_65c02 and G_INCL_CPU_65C02 else
									i_6800_wrap_cyc			when r_cfg_hard_cpu_type = cpu_6800 and G_INCL_CPU_6800 else
									i_65816_wrap_cyc			when r_cfg_hard_cpu_type = cpu_65816 and G_INCL_CPU_65816 else
									(others => '0');	

	i_wrap_A_log			<= i_t65_wrap_A_log			when r_cpu_en_t65 = '1' and G_INCL_CPU_T65 else
									i_6x09_wrap_A_log			when r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09 else
									i_z80_wrap_A_log			when r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80 else
									i_68k_wrap_A_log			when r_cfg_hard_cpu_type = CPU_68008 and G_INCL_CPU_68k else
--									i_6502_wrap_A_log			when r_cfg_hard_cpu_type = CPU_6502 and G_OPT_INCLUDE_6502 else
									i_65c02_wrap_A_log		when r_cfg_hard_cpu_type = CPU_65c02 and G_INCL_CPU_65C02 else
									i_6800_wrap_A_log			when r_cfg_hard_cpu_type = CPU_6800 and G_INCL_CPU_6800 else
									i_65816_wrap_A_log		when r_cfg_hard_cpu_type = CPU_65816 and G_INCL_CPU_65816 else
									(others => '0');
	i_wrap_we				<= i_t65_wrap_we				when r_cpu_en_t65 = '1' and G_INCL_CPU_T65 else
									i_6x09_wrap_we				when r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09 else
									i_z80_wrap_we				when r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80 else
									i_68k_wrap_we				when r_cfg_hard_cpu_type = cpu_68008 and G_INCL_CPU_68k else
--									i_6502_wrap_we				when r_cfg_hard_cpu_type = cpu_6502 and G_OPT_INCLUDE_6502 else
									i_65c02_wrap_we			when r_cfg_hard_cpu_type = cpu_65c02 and G_INCL_CPU_65C02 else
									i_6800_wrap_we				when r_cfg_hard_cpu_type = cpu_6800 and G_INCL_CPU_6800 else
									i_65816_wrap_we			when r_cfg_hard_cpu_type = cpu_65816 and G_INCL_CPU_65816 else
									'0';			
	i_wrap_D_WR_stb		<= i_t65_wrap_D_WR_stb		when r_cpu_en_t65 = '1' and G_INCL_CPU_T65 else
									i_6x09_wrap_D_WR_stb		when r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09 else
									i_z80_wrap_D_WR_stb		when r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80 else
									i_68k_wrap_D_WR_stb		when r_cfg_hard_cpu_type = cpu_68008 and G_INCL_CPU_68k else
--									i_6502_wrap_D_WR_stb		when r_cfg_hard_cpu_type = cpu_6502 and G_OPT_INCLUDE_6502 else
									i_6800_wrap_D_WR_stb		when r_cfg_hard_cpu_type = cpu_6800 and G_INCL_CPU_6800 else
									i_65816_wrap_D_WR_stb	when r_cfg_hard_cpu_type = cpu_65816 and G_INCL_CPU_65816 else
									'0';
	i_wrap_D_WR				<= i_t65_wrap_D_WR			when r_cpu_en_t65 = '1' and G_INCL_CPU_T65 else
									i_6x09_wrap_D_WR			when r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09 else
									i_z80_wrap_D_WR			when r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80 else
									i_68k_wrap_D_WR			when r_cfg_hard_cpu_type = cpu_68008 and G_INCL_CPU_68k else
--									i_6502_wrap_D_WR			when r_cfg_hard_cpu_type = cpu_6502 and G_OPT_INCLUDE_6502 else
									i_65c02_wrap_D_WR			when r_cfg_hard_cpu_type = cpu_65c02 and G_INCL_CPU_65C02 else
									i_6800_wrap_D_WR			when r_cfg_hard_cpu_type = cpu_6800 and G_INCL_CPU_6800 else
									i_65816_wrap_D_WR			when r_cfg_hard_cpu_type = cpu_65816 and G_INCL_CPU_65816 else
									(others => '0');		

	i_wrap_ack				<= i_t65_wrap_ack				when r_cpu_en_t65 = '1' and G_INCL_CPU_T65 else
									i_6x09_wrap_ack			when r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09 else
									i_z80_wrap_ack				when r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80 else
									i_68k_wrap_ack				when r_cfg_hard_cpu_type = cpu_68008 and G_INCL_CPU_68k else
--									i_6502_wrap_ack			when r_cfg_hard_cpu_type = cpu_6502 and G_OPT_INCLUDE_6502 else
									i_65c02_wrap_ack			when r_cfg_hard_cpu_type = cpu_65c02 and G_INCL_CPU_65C02 else
									i_6800_wrap_ack			when r_cfg_hard_cpu_type = cpu_6800 and G_INCL_CPU_6800 else
									i_65816_wrap_ack			when r_cfg_hard_cpu_type = cpu_65816 and G_INCL_CPU_65816 else
									'0';			



	-- multiplex CPUSKT output signalsG_INCL_CPU_T65 

	i_exp_PORTB_o 					<= i_6x09_exp_PORTB_o		when r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09 else
											i_z80_exp_PORTB_o			when r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80 else
											i_68k_exp_PORTB_o			when r_cfg_hard_cpu_type = cpu_68008 and G_INCL_CPU_68k else
											--i_6502_exp_PORTB_o			when r_cfg_hard_cpu_type = cpu_6502 and G_OPT_INCLUDE_6502 else
											i_65c02_exp_PORTB_o		when r_cfg_hard_cpu_type = cpu_65c02 and G_INCL_CPU_65C02 else
											i_6800_exp_PORTB_o		when r_cfg_hard_cpu_type = cpu_6800 and G_INCL_CPU_6800 else
											i_65816_exp_PORTB_o		when r_cfg_hard_cpu_type = cpu_65816 and G_INCL_CPU_65816 else
											( others => '1');

	i_exp_PORTD_o 					<= i_6x09_exp_PORTD_o		when r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09 else
											i_z80_exp_PORTD_o			when r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80 else
											i_68k_exp_PORTD_o			when r_cfg_hard_cpu_type = cpu_68008 and G_INCL_CPU_68k else
											--i_6502_exp_PORTD_o			when r_cfg_hard_cpu_type = cpu_6502 and G_OPT_INCLUDE_6502 else
											i_65c02_exp_PORTD_o		when r_cfg_hard_cpu_type = cpu_65c02 and G_INCL_CPU_65C02 else
											i_6800_exp_PORTD_o		when r_cfg_hard_cpu_type = cpu_6800 and G_INCL_CPU_6800 else
											i_65816_exp_PORTD_o		when r_cfg_hard_cpu_type = cpu_65816 and G_INCL_CPU_65816 else
											( others => '1');

	i_exp_PORTD_o_en				<= i_6x09_exp_PORTD_o_en	when r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09 else
											i_z80_exp_PORTD_o_en		when r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80 else
											i_68k_exp_PORTD_o_en		when r_cfg_hard_cpu_type = cpu_68008 and G_INCL_CPU_68k else
											--i_6502_exp_PORTD_o_en	when r_cfg_hard_cpu_type = cpu_6502 and G_OPT_INCLUDE_6502 else
											i_65c02_exp_PORTD_o_en	when r_cfg_hard_cpu_type = cpu_65c02 and G_INCL_CPU_65C02 else
											i_6800_exp_PORTD_o_en	when r_cfg_hard_cpu_type = cpu_6800 and G_INCL_CPU_6800 else
											i_65816_exp_PORTD_o_en	when r_cfg_hard_cpu_type = cpu_65816 and G_INCL_CPU_65816 else
											( others => '0');

	i_exp_PORTE_nOE				<= i_6x09_exp_PORTE_nOE		when r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09 else
											i_z80_exp_PORTE_nOE		when r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80 else
											i_68k_exp_PORTE_nOE		when r_cfg_hard_cpu_type = cpu_68008 and G_INCL_CPU_68k else
											--i_6502_exp_PORTE_nOE	when r_cfg_hard_cpu_type = cpu_6502 and G_OPT_INCLUDE_6502 else
											i_65c02_exp_PORTE_nOE	when r_cfg_hard_cpu_type = cpu_65c02 and G_INCL_CPU_65C02 else
											i_6800_exp_PORTE_nOE		when r_cfg_hard_cpu_type = cpu_6800 and G_INCL_CPU_6800 else
											i_65816_exp_PORTE_nOE	when r_cfg_hard_cpu_type = cpu_65816 and G_INCL_CPU_65816 else
											'1';

	i_exp_PORTF_nOE				<= i_6x09_exp_PORTF_nOE		when r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09 else
											i_z80_exp_PORTF_nOE		when r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80 else
											i_68k_exp_PORTF_nOE		when r_cfg_hard_cpu_type = cpu_68008 and G_INCL_CPU_68k else
											--i_6502_exp_PORTF_nOE	when r_cfg_hard_cpu_type = cpu_6502 and G_OPT_INCLUDE_6502 else
											i_65c02_exp_PORTF_nOE	when r_cfg_hard_cpu_type = cpu_65c02 and G_INCL_CPU_65C02 else
											i_6800_exp_PORTF_nOE		when r_cfg_hard_cpu_type = cpu_6800 and G_INCL_CPU_6800 else
											i_65816_exp_PORTF_nOE	when r_cfg_hard_cpu_type = cpu_65816 and G_INCL_CPU_65816 else
											'1';





	i_CPU_D_RnW <= '0' 						when r_cpu_en_t65 = '1' and G_INCL_CPU_T65 else
						i_6x09_CPU_D_RnW 		when r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09 else
						i_z80_CPU_D_RnW		when r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80 else
						i_68k_CPU_D_RnW		when r_cfg_hard_cpu_type = cpu_68008 and G_INCL_CPU_68k else
--						i_6502_CPU_D_RnW		when r_cfg_hard_cpu_type = cpu_6502 and G_OPT_INCLUDE_6502 else
						i_65c02_CPU_D_RnW		when r_cfg_hard_cpu_type = cpu_65c02 and G_INCL_CPU_65C02 else
						i_6800_CPU_D_RnW		when r_cfg_hard_cpu_type = cpu_6800 and G_INCL_CPU_6800 else
						i_65816_CPU_D_RnW		when r_cfg_hard_cpu_type = cpu_65816 and G_INCL_CPU_65816 else
						'0';


	-- multiplex noice signals

	noice_debug_5c_o				<= i_t65_noice_debug_5c 			when r_cpu_en_t65 = '1' and G_INCL_CPU_T65 else
											i_6x09_noice_debug_5c			when r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09 else
											i_z80_noice_debug_5c				when r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80 else
											i_68k_noice_debug_5c				when r_cfg_hard_cpu_type = cpu_68008 and G_INCL_CPU_68k else
--											i_6502_noice_debug_5c			when r_cfg_hard_cpu_type = cpu_6502 and G_OPT_INCLUDE_6502 else
											i_65c02_noice_debug_5c			when r_cfg_hard_cpu_type = cpu_65c02 and G_INCL_CPU_65C02 else
											i_6800_noice_debug_5c			when r_cfg_hard_cpu_type = cpu_6800 and G_INCL_CPU_6800 else
											i_65816_noice_debug_5c			when r_cfg_hard_cpu_type = cpu_65816 and G_INCL_CPU_65816 else
											'0';
	noice_debug_cpu_clken_o		<= i_t65_noice_debug_cpu_clken 	when r_cpu_en_t65 = '1' and G_INCL_CPU_T65 else
											i_6x09_noice_debug_cpu_clken	when r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09 else
											i_z80_noice_debug_cpu_clken	when r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80 else
											i_68k_noice_debug_cpu_clken	when r_cfg_hard_cpu_type = cpu_68008 and G_INCL_CPU_68k else
--											i_6502_noice_debug_cpu_clken	when r_cfg_hard_cpu_type = cpu_6502 and G_OPT_INCLUDE_6502 else
											i_65c02_noice_debug_cpu_clken	when r_cfg_hard_cpu_type = cpu_65c02 and G_INCL_CPU_65C02 else
											i_6800_noice_debug_cpu_clken	when r_cfg_hard_cpu_type = cpu_6800 and G_INCL_CPU_6800 else
											i_65816_noice_debug_cpu_clken	when r_cfg_hard_cpu_type = cpu_65816 and G_INCL_CPU_65816 else
											'0';
	noice_debug_A0_tgl_o			<= i_t65_noice_debug_A0_tgl 		when r_cpu_en_t65 = '1' and G_INCL_CPU_T65 else
											i_6x09_noice_debug_A0_tgl		when r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09 else
											i_z80_noice_debug_A0_tgl		when r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80 else
											i_68k_noice_debug_A0_tgl		when r_cfg_hard_cpu_type = cpu_68008 and G_INCL_CPU_68k else
--											i_6502_noice_debug_A0_tgl		when r_cfg_hard_cpu_type = cpu_6502 and G_OPT_INCLUDE_6502 else
											i_65c02_noice_debug_A0_tgl		when r_cfg_hard_cpu_type = cpu_65c02 and G_INCL_CPU_65C02 else
											i_6800_noice_debug_A0_tgl		when r_cfg_hard_cpu_type = cpu_6800 and G_INCL_CPU_6800 else
											i_65816_noice_debug_A0_tgl		when r_cfg_hard_cpu_type = cpu_65816 and G_INCL_CPU_65816 else
											'0';
	noice_debug_opfetch_o		<= i_t65_noice_debug_opfetch 		when r_cpu_en_t65 = '1' and G_INCL_CPU_T65 else
											i_6x09_noice_debug_opfetch		when r_cfg_hard_cpu_type = cpu_6x09 and G_INCL_CPU_6x09 else
											i_z80_noice_debug_opfetch		when r_cfg_hard_cpu_type = cpu_z80 and G_INCL_CPU_Z80 else
											i_68k_noice_debug_opfetch		when r_cfg_hard_cpu_type = cpu_68008 and G_INCL_CPU_68k else
--											i_6502_noice_debug_opfetch		when r_cfg_hard_cpu_type = cpu_6502 and G_OPT_INCLUDE_6502 else
											i_65c02_noice_debug_opfetch	when r_cfg_hard_cpu_type = cpu_65c02 and G_INCL_CPU_65C02 else
											i_6800_noice_debug_opfetch		when r_cfg_hard_cpu_type = cpu_6800 and G_INCL_CPU_6800 else
											i_65816_noice_debug_opfetch	when r_cfg_hard_cpu_type = cpu_65816 and G_INCL_CPU_65816 else
											'0';

end rtl;

-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	9/8/2020
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - t65 soft core
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the t65 core
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: NOTE: abandoned 18/8/2020, 6502A is just too slow to set up address to be usable
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.board_config_pack.all;


entity fb_cpu_6502 is
		generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		G_JIM_DEVNO							: std_logic_vector(7 downto 0);
		CLKEN_DLY_MAX						: natural := 20								-- used to time latching of address etc signals
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		fb_syscon_i								: in	fb_syscon_t;

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

		-- state machine signals
		wrap_cyc_o							: out std_logic;
		wrap_A_log_o							: out std_logic_vector(23 downto 0);	-- this will be passed on to fishbone after to log2phys mapping
		wrap_A_we_o								: out std_logic;								-- we signal for this cycle
		wrap_D_WR_stb_o						: out std_logic;								-- for write cycles indicates write data is ready
		wrap_D_WR_o								: out std_logic_vector(7 downto 0);		-- write data
		wrap_cyc_cpu_speed_o					: out fb_cyc_speed_t;						-- cycle speed for fishbone
		wrap_ack_o								: out std_logic;

		wrap_rdy_i								: in std_logic;
		wrap_dtack_i							: in std_logic;
		wrap_cyc_i								: in std_logic;

		-- chipset control signals
		cpu_halt_i								: in  std_logic;

		CPU_D_RnW_o								: out		std_logic;								-- '1' cpu is reading, else writing

		-- cpu socket signals
		CPUSKT_D_i								: in		std_logic_vector(7 downto 0);

		CPUSKT_A_i								: in		std_logic_vector(19 downto 0);

		CPUSKT_6EKEZnRD_i						: in		std_logic;		
		CPUSKT_C6nML9BUSYKnBGZnBUSACK_i	: in		std_logic;
		CPUSKT_RnWZnWR_i						: in		std_logic;
		CPUSKT_PHI16ABRT9BSKnDS_i			: in		std_logic;		-- 6ABRT is actually an output but pulled up on the board
		CPUSKT_PHI26VDAKFC0ZnMREQ_i		: in		std_logic;
		CPUSKT_SYNC6VPA9LICKFC2ZnM1_i		: in		std_logic;
		CPUSKT_VSS6VPA9BAKnAS_i				: in		std_logic;
		CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i	: in		std_logic;		-- nSO is actually an output but pulled up on the board
		CPUSKT_6BE9TSCKnVPA_o				: out		std_logic;
		CPUSKT_9Q_o								: out		std_logic;
		CPUSKT_KnBRZnBUSREQ_o				: out		std_logic;
		CPUSKT_PHI09EKZCLK_o					: out		std_logic;
		CPUSKT_RDY9KnHALTZnWAIT_o			: out		std_logic;
		CPUSKT_nIRQKnIPL1_o					: out		std_logic;
		CPUSKT_nNMIKnIPL02_o					: out		std_logic;
		CPUSKT_nRES_o							: out		std_logic;
		CPUSKT_9nFIRQLnDTACK_o				: out		std_logic;


		-- special m68k signals
		jim_en_i									: in		std_logic

);
end fb_cpu_6502;

architecture rtl of fb_cpu_6502 is
	signal r_prev_A0			: std_logic;

	signal i_cpu_clk			: fb_cpu_clks_t;

	signal r_clken_dly		: std_logic_vector(CLKEN_DLY_MAX downto 0) := (others => '0');
	signal r_clken_phi0_dly	: std_logic_vector(CLKEN_DLY_MAX downto 0) := (others => '0');
	signal r_cpu_stretch		: std_logic;

	signal i_cpu_clken		: std_logic;	-- end of phi0 and cycle stretch finished

begin

	CPU_D_RnW_o <= 	'1' 	when CPUSKT_RnWZnWR_i = '1' and CPUSKT_PHI26VDAKFC0ZnMREQ_i = '1' else
							'0';


	wrap_cyc_cpu_speed_o <= MHZ_2;
	wrap_A_log_o 			<= x"FF" & CPUSKT_A_i(15 downto 0);
	wrap_cyc_o 			<= '1' when r_clken_dly(18) = '1' else '0';
	wrap_A_we_o  			<= not(CPUSKT_RnWZnWR_i);
	wrap_D_wr_o				<=	CPUSKT_D_i;	
	wrap_D_wr_stb_o		<= r_clken_phi0_dly(8);
	wrap_ack_o				<= wrap_rdy_i and i_cpu_clk.cpu_clken and not r_cpu_stretch;


	CPUSKT_6BE9TSCKnVPA_o <= not cpu_en_i;
	
	CPUSKT_KnBRZnBUSREQ_o <= '1';
	
	CPUSKT_PHI09EKZCLK_o <= i_cpu_clk.cpu_clk_E or r_cpu_stretch;
	
	CPUSKT_9Q_o <= '1';
	
	CPUSKT_nRES_o <= (not fb_syscon_i.rst) when cpu_en_i = '1' else '0';
	
	CPUSKT_nNMIKnIPL02_o <= noice_debug_nmi_n_i and nmi_n_i;
	
	CPUSKT_nIRQKnIPL1_o <=  irq_n_i;
  	
  	CPUSKT_9nFIRQLnDTACK_o <=  '1';

  	CPUSKT_RDY9KnHALTZnWAIT_o <= 	'1' when fb_syscon_i.rst = '1' else
  											'1' when noice_debug_inhibit_cpu_i = '1' else
  											'0' when cpu_halt_i = '1' else
  											'1';						

	i_cpu_clk <= 	fb_syscon_i.cpu_clks(FB_CPUCLKINDEX(MHZ_2));


	i_cpu_clken <= i_cpu_clk.cpu_clken and not r_cpu_stretch;

  	p_cpu_6x09_stretch:process(fb_syscon_i)
  	begin
  		if fb_syscon_i.rst = '1' then
  			r_cpu_stretch <= '0';
  		elsif rising_edge(fb_syscon_i.clk) then
  			if i_cpu_clk.cpu_Q_clken = '1' then
				if wrap_rdy_i = '0' then
  					r_cpu_stretch <= '1';
  				else
  					r_cpu_stretch <= '0';
  				end if;
  			end if;
  		end if;
  	end process;


	p_clken_dly:process(fb_syscon_i)
	variable v_cur_phi0 : std_logic := '0';
	variable	v_pre_phi0 : std_logic := '0';
	begin
		if rising_edge(fb_syscon_i.clk) then
			v_cur_phi0 := (i_cpu_clk.cpu_clk_E or r_cpu_stretch);
			r_clken_dly <= r_clken_dly(r_clken_dly'high-1 downto 0) & i_cpu_clk.cpu_clken;
			r_clken_phi0_dly <= r_clken_phi0_dly(r_clken_phi0_dly'high-1 downto 0) & (v_cur_phi0 and (v_cur_phi0 xor v_pre_phi0));
			v_pre_phi0 := v_cur_phi0;
		end if;
	end process;



   p_prev_a0:process(fb_syscon_i) 
  	begin
  		if fb_syscon_i.rst = '1' then
  			r_prev_A0 <= '0';
  		elsif rising_edge(fb_syscon_i.clk) then
  			if i_cpu_clken = '1' then
  				r_prev_A0 <= CPUSKT_A_i(0);
  			end if;
  		end if;
  	end process;


	noice_debug_A0_tgl_o <= r_prev_A0 xor CPUSKT_A_i(0);

  	noice_debug_cpu_clken_o <= i_cpu_clken;
  	
  	noice_debug_5c_o	 <= '0';
--  								'1' when 
--  										CPUSKT_SYNC6VPA9LICKFC2ZnM1_i = '1' 
--  										and CPUSKT_D_i = x"5C" else
--  								'0';
--
  	noice_debug_opfetch_o <= CPUSKT_SYNC6VPA9LICKFC2ZnM1_i;



end rtl;
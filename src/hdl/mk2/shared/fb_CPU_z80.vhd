-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	9/8/2020
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - z80
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the z80 processor slot
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

-- NOTE: this requires a board mod on the mk.2 board - the z80's RFSH pin needs to 
-- be connected to CPUSKT_VSS6VPA9BAKnAS_i


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.board_config_pack.all;


entity fb_cpu_z80 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural
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
		wrap_cyc_o								: out std_logic;
		wrap_A_log_o							: out std_logic_vector(23 downto 0);	-- this will be passed on to fishbone after to log2phys mapping
		wrap_A_we_o								: out std_logic;								-- we signal for this cycle
		wrap_D_WR_stb_o						: out std_logic;								-- for write cycles indicates write data is ready
		wrap_D_WR_o								: out std_logic_vector(7 downto 0);		-- write data
		wrap_ack_o								: out std_logic;

		wrap_rdy_ctdn_i						: in unsigned(RDY_CTDN_LEN-1 downto 0);
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
		CPUSKT_9nFIRQLnDTACK_o				: out		std_logic


	);
end fb_cpu_z80;

architecture rtl of fb_cpu_z80 is


--TODO: other speed grades
--Current speed grade 8 MHz
--Assume 128MHz fast clock

-- timings below in number of fast clocks
	constant T_cpu_clk_half	: natural 		:= 8;		-- clock half period - 8MHZ


	signal r_clkctdn			: unsigned(NUMBITS(T_cpu_clk_half)-1 downto 0) := to_unsigned(T_cpu_clk_half-1, NUMBITS(T_cpu_clk_half));

	signal r_cpu_clk			: std_logic;
	signal r_cpu_clk_ne		: std_logic;
	signal r_cpu_clk_pe		: std_logic;


	signal r_act				: std_logic;

	signal i_rdy				: std_logic;

	signal r_A_log				: std_logic_vector(23 downto 0);
	signal i_A_log				: std_logic_vector(23 downto 0);
	signal r_WE					: std_logic;
	signal r_WR_stb			: std_logic;

begin

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity error;

	CPU_D_RnW_o <= '0' when CPUSKT_6EKEZnRD_i = '1' else
					 	'1';

	--TODO: mark rdy earlier!
	--TODO: register this signal (metastable vs z80?)
	i_rdy <= '1' when wrap_rdy_ctdn_i = RDY_CTDN_MIN else 
				'0';


	wrap_cyc_o 				<= r_act;
	wrap_A_we_o  			<= r_WE;
	wrap_D_wr_o				<=	CPUSKT_D_i;	
	wrap_D_wr_stb_o		<= r_WR_stb;
	wrap_ack_o				<= not r_act;
	wrap_A_log_o			<= r_A_log;
  		

  	i_A_log <=						x"FFFD" & CPUSKT_A_i(7 downto 0) when CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i = '0' else 
  										x"FF" & CPUSKT_A_i(15 downto 0) when (CPUSKT_A_i(15 downto 8) = x"FC" or CPUSKT_A_i(15 downto 8) = x"FD" or CPUSKT_A_i(15 downto 8) = x"FE") else
										x"FF" & '0' & CPUSKT_A_i(14 downto 0) when CPUSKT_A_i(15) = '1' else 	-- 8000-FFFF from SYS 0-7FFF (for screen)
  										x"00" & CPUSKT_A_i(15 downto 0); 	-- low memory from chip ram

	p_cpu_clk:process(fb_syscon_i)
	begin

		if rising_edge(fb_syscon_i.clk) then

			r_cpu_clk_pe <= '0';
			r_cpu_clk_ne <= '0';

			if r_clkctdn = 0 then
				if r_cpu_clk = '1' then
					r_cpu_clk_ne <= '1';
					r_cpu_clk <= '0';
				else
					r_cpu_clk_pe <= '1';
					r_cpu_clk <= '1';					
				end if;
				r_clkctdn <= to_unsigned(T_cpu_clk_half-1, r_clkctdn'length);
			else
				r_clkctdn <= r_clkctdn - 1;
			end if;

		end if;

	end process;



	p_act:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_act <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if r_cpu_clk_pe = '1' then

				r_WR_stb <= not(CPUSKT_RnWZnWR_i);

				if r_act = '0' and (CPUSKT_PHI26VDAKFC0ZnMREQ_i = '0' or CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i = '0')
												and CPUSKT_VSS6VPA9BAKnAS_i = '1' then
					r_act <= '1';

					r_A_log <=	i_A_log;

					r_WE <= CPUSKT_6EKEZnRD_i;
				elsif CPUSKT_PHI26VDAKFC0ZnMREQ_i = '1' and CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i = '1' then
					r_act <= '0';
				end if;
			end if;
		end if;
	end process;

	CPUSKT_6BE9TSCKnVPA_o <= '1';

	CPUSKT_KnBRZnBUSREQ_o <= cpu_en_i;

	CPUSKT_PHI09EKZCLK_o <= r_cpu_clk;

	CPUSKT_9Q_o <= '1';

	CPUSKT_nRES_o <= (not fb_syscon_i.rst) when cpu_en_i = '1' else '0';


	CPUSKT_nNMIKnIPL02_o <= nmi_n_i and noice_debug_nmi_n_i;

	CPUSKT_nIRQKnIPL1_o <=  irq_n_i;

  	CPUSKT_9nFIRQLnDTACK_o <=  '1';

  	CPUSKT_RDY9KnHALTZnWAIT_o <= 	'1' 			when fb_syscon_i.rst = '1' else
  											'1' 			when noice_debug_inhibit_cpu_i = '1' else
  											i_rdy		 	when wrap_cyc_i = '1' else
  											'1';						


  	--TODO: this doesn't look right
  	noice_debug_cpu_clken_o <= '1' when r_cpu_clk_pe = '1' and wrap_cyc_i = '1' and i_rdy = '1' else
  										'0';
  	
  	noice_debug_5c_o	 	 	<=	'0';

  	noice_debug_opfetch_o 	<= '1' when CPUSKT_SYNC6VPA9LICKFC2ZnM1_i = '0' and CPUSKT_PHI26VDAKFC0ZnMREQ_i = '0' else
  										'0';

	noice_debug_A0_tgl_o  	<= '0'; -- TODO: check if needed



end rtl;



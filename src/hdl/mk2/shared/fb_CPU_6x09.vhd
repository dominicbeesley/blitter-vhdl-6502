-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	9/8/2020
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - 6x09
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the 6x09 processor slot
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.board_config_pack.all;


entity fb_cpu_6x09 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		cpu_speed_i								: in std_logic;				-- 1 for 3.5MHz, 0 for 2 Mhz

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
end fb_cpu_6x09;

architecture rtl of fb_cpu_6x09 is
	function MAX(LEFT, RIGHT: INTEGER) return INTEGER is
	begin
  		if LEFT > RIGHT then return LEFT;
  		else return RIGHT;
    	end if;
  	end;

	
-- there are 4 phases for the 6x09 cpu we will label them A,B,C,D:
--
-- Phase | Q | E | Notes
-- ------+---+---+-----------------------------------------------------------
--   A   | 0 | 0 | Start of cycle, Addr, BA, BS, RnW, timed from start
--       |   |   | of this phase but may occur in next phase
-- ------+---+---+-----------------------------------------------------------
--   B   | 1 | 0 | Busy, LIC, AVMA and write data timed from the start of 
--       |   |   | this phase
-- ------+---+---+-----------------------------------------------------------
--   C   | 1 | 1 | 
-- ------+---+---+-----------------------------------------------------------
--   D   | 0 | 1 | End of processor cycle at end of this phase, read data
--       |   |   | must meet timings for end of this phase
--       |   |   | NOTE: this phase will be stretched whilst awaiting data


-- timings
-- =======
-- Timings below for 2 MHz (68B09) and [3+ MHz HD63C09] modes
--
-- Name     | Time ns         | Notes
-- ---------+-----------------+----------------------------------------------
-- Min phase| 100 [65]        | minimum time for a single phase
-- A+B      | 210 [140]       |
-- A+B      | 220 [140]       |
-- B+C      | 220 [140]       |
-- A -> tAD | 110 [110]			| Address, RnW, BA, BS delay
-- B -> tCD | 200 [130]			| Busy, Lic, AVMA delay
-- B -> tDD | 119 [ 70]			| Write data delay
-- tDS-> D  | 40  [ 20]       | Read data setup (to end of cycle)
-- A -> tDH | 20  [ 20]			| Read data hold (from end of cycle)

-- The actual timings below are in 128MHz cycles from start of cycle 0-indexed i.e.
-- 0 =~ 7ns 11 =~ 84 ns

--! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
--TODO: Make the timings below meet specs! Currently bodged

-- Timings in fast clock cycles - 1
-- 2MHz timings
   constant T_phA_2 : natural := 12;
   constant T_phB_2 : natural := 12;
   constant T_phC_2 : natural := 12;
   constant T_phD_2 : natural := 12;
   constant T_tAD_2 : natural := 11;		-- really should be 13
   constant T_tDD_2 : natural := 15;
   constant T_tDS_2 : natural := 2;
   constant T_tDH_2 : natural := 2;

-- 2MHz timings
   constant T_phA_3 : natural := 8;
   constant T_phB_3 : natural := 8;
   constant T_phC_3 : natural := 8;
   constant T_phD_3 : natural := 8;			-- 4*9/128 =~ 3.55MHz!
   constant T_tAD_3 : natural := 11;		-- really should be 13
   constant T_tDD_3 : natural := 8;
   constant T_tDS_3 : natural := 0;
   constant T_tDH_3 : natural := 2;
--! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !


   constant T_MAX_Ph: natural := MAX(T_phA_2, MAX(T_phB_2, MAX(T_phC_2, MAX(T_phD_2, MAX(T_phA_3, MAX(T_phB_3, MAX(T_phC_3, T_phD_3)))))));
   constant T_MAX_AD: natural := MAX(T_tAD_2, T_tAD_3);
   constant T_MAX_DD: natural := MAX(T_tDD_2, T_tDD_3);
   constant T_MAX_DS: natural := MAX(T_tDS_2, T_tDS_3);
   constant T_MAX_DH: natural := MAX(T_tDH_2, T_tDH_3);



   type t_state is (phA, phB, phC, phD);

   signal r_state 			: t_state;

   signal r_ph_ring			: std_logic_vector(T_MAX_Ph downto 0);
   signal r_AD_ring			: std_logic_vector(T_MAX_AD downto 0);
   signal r_DD_ring			: std_logic_vector(T_MAX_DD downto 0);
   signal r_DS_ring			: std_logic_vector(T_MAX_DS downto 0);
   signal r_DH_ring			: std_logic_vector(T_MAX_DH downto 0);

	signal r_cpu_6x09_FIC 	: std_logic;
	signal r_cpu_6x09_VMA	: std_logic;

	signal i_rdy				: std_logic;

	signal r_log_A				: std_logic_vector(23 downto 0);
	signal r_a_stb				: std_logic;
	signal i_D_wr_stb			: std_logic;
	signal r_cpu_E				: std_logic;
	signal r_cpu_Q				: std_logic;
	signal r_cpu_res			: std_logic;
	signal r_wrap_ack			: std_logic;

begin

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity error;


	CPU_D_RnW_o <= 	'0'	when CPUSKT_VSS6VPA9BAKnAS_i = '1' else
							'1' 	when CPUSKT_RnWZnWR_i = '1' and r_DH_ring(T_MAX_DH) = '1' else
							'0';

	wrap_A_log_o 			<= r_log_A;
																		
	-- note: don't start CYC until AS is settled
	wrap_cyc_o 				<= r_a_stb;
	wrap_A_we_o  			<= not(CPUSKT_RnWZnWR_i);
	wrap_D_wr_o				<=	CPUSKT_D_i;	
	wrap_D_wr_stb_o		<= i_D_wr_stb;
	wrap_ack_o				<= r_wrap_ack;

	i_D_wr_stb <= 	r_DD_ring(T_tDD_3) when cpu_speed_i = '1' else
						r_DD_ring(T_tDD_2);


	p_address_latch:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			r_a_stb <= '0';
			if r_cpu_res = '0' and 
				r_cpu_6x09_VMA = '1' and (
				(cpu_speed_i = '1' and r_AD_ring(T_tAD_3) = '1') or (r_AD_ring(T_tAD_2) = '1') 
				) then

				if noice_debug_inhibit_cpu_i = '1' then
					r_a_stb <= '0';
				else
					r_a_stb <= '1';
					if CPUSKT_PHI16ABRT9BSKnDS_i = '1' and CPUSKT_VSS6VPA9BAKnAS_i = '0' then
						-- toggle A(11) on vector pull to avoid MOS jump table
						r_log_A <= x"FF" & CPUSKT_A_i(15 downto 12) & not(CPUSKT_A_i(11)) & CPUSKT_A_i(10 downto 0) ;
					else 
						r_log_A <= x"FF" & CPUSKT_A_i(15 downto 0);
					end if;

				end if;

			end if;
		end if;
	end process;


	p_state:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then

			if fb_syscon_i.rst = '1' then
				r_cpu_res <= '1';
			end if;

			r_PH_ring <= r_PH_ring(r_PH_ring'high-1 downto 0) & "1";
			r_AD_ring <= r_AD_ring(r_AD_ring'high-1 downto 0) & "0";
			r_DD_ring <= r_DD_ring(r_DD_ring'high-1 downto 0) & "0";

			if wrap_rdy_ctdn_i = RDY_CTDN_MIN then
				r_DS_ring <= r_DS_ring(r_DS_ring'high-1 downto 0) & "1";
			else
				r_DS_ring <= (others => '0');
			end if;

			if r_state = phD then
				r_DH_ring <= (others => '1');
			else
				r_DH_ring <= r_DH_ring(r_DH_ring'high-1 downto 0) & "0";
			end if;

			r_wrap_ack <= '0';

			case r_state is
				when phA => 
					if (cpu_speed_i = '1' and r_PH_ring(T_phA_3) = '1') or r_PH_ring(T_phA_2) = '1' then
						r_state <= phB;
						r_DD_ring <= (0 => '1', others => '0');
						r_cpu_Q <= '1';
						r_ph_ring <= (others => '0');
					end if;
				when phB =>
					if (cpu_speed_i = '1' and r_PH_ring(T_phB_3) = '1') or r_PH_ring(T_phB_2) = '1' then
						r_state <= phC;
						r_cpu_E <= '1';
						r_ph_ring <= (others => '0');
					end if;
				when phC =>
					if (cpu_speed_i = '1' and r_PH_ring(T_phC_3) = '1') or r_PH_ring(T_phC_2) = '1' then
						r_state <= phD;
						r_cpu_Q <= '0';
						r_ph_ring <= (others => '0');
					end if;
				when phD =>
					if (cpu_speed_i = '1' and r_PH_ring(T_phD_3) = '1') or r_PH_ring(T_phD_2) = '1' then
						if 
							r_cpu_res = '1' 
							or r_cpu_6x09_VMA = '0' 
							or (cpu_speed_i = '1' and r_DS_ring(T_tDS_3) = '1')
							or noice_debug_inhibit_cpu_i = '1'
							or r_DS_ring(T_tDS_2) = '1' then
							r_state <= phA;
							r_cpu_6x09_FIC <= CPUSKT_SYNC6VPA9LICKFC2ZnM1_i;
							if SIM then
								-- horrible bodge - our cpu model doesn't do AVMA correctly!
								r_cpu_6x09_VMA <= '1';
							else
								r_cpu_6x09_VMA <= CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i;
							end if;
							r_AD_ring <= (0 => '1', others => '0');
							r_wrap_ack <= '1';
							r_cpu_E <= '0';
							r_ph_ring <= (others => '0');
							if fb_syscon_i.rst = '0' then
								r_cpu_res <= '0';
							end if;
						end if;
					end if;
				when others =>
					r_state <= phA;
					r_cpu_6x09_FIC <= CPUSKT_SYNC6VPA9LICKFC2ZnM1_i;
					if SIM then
						-- horrible bodge - our cpu model doesn't do AVMA correctly!
						r_cpu_6x09_VMA <= '1';
					else
						r_cpu_6x09_VMA <= CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i;
					end if;
					r_AD_ring <= (0 => '1', others => '0');
					r_wrap_ack <= '1';
					r_cpu_Q <= '0';
					r_cpu_E <= '0';
					r_ph_ring <= (others => '0');
					if fb_syscon_i.rst = '0' then
						r_cpu_res <= '0';
					end if;
				end case;
		end if;
	end process;



	CPUSKT_6BE9TSCKnVPA_o <= not cpu_en_i;
	
	CPUSKT_KnBRZnBUSREQ_o <= '1';
	
	CPUSKT_PHI09EKZCLK_o <= r_cpu_E;
	
	CPUSKT_9Q_o <= r_cpu_Q;
	
	CPUSKT_nRES_o <= (not r_cpu_res) when cpu_en_i = '1' else '0';
	
	CPUSKT_nNMIKnIPL02_o <= noice_debug_nmi_n_i;
	
	CPUSKT_nIRQKnIPL1_o <=  irq_n_i;
  	
  	CPUSKT_9nFIRQLnDTACK_o <=  nmi_n_i;

  	-- NOTE: for 6x09 we don't need to register RDY, instead allow the CPU to latch it and use the AS/BS signals
  	-- to direct cyc etc

  	CPUSKT_RDY9KnHALTZnWAIT_o <= 	i_rdy;

  	i_rdy <=								'1' when fb_syscon_i.rst = '1' else
  											'1' when noice_debug_inhibit_cpu_i = '1' else
  											'0' when cpu_halt_i = '1' else
  											'1';						


  	noice_debug_cpu_clken_o <= r_wrap_ack;
  	
  	noice_debug_5c_o	 	 	<=	'0';

  	noice_debug_opfetch_o 	<= r_cpu_6x09_FIC;

	noice_debug_A0_tgl_o  	<= '0'; -- TODO: check if needed


end rtl;

-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	9/8/2020
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - 65c02, w65c02s, 65c102 etc
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

--TODO: no effort is made here to register the 2MHz part to the system clock
-- due to the jitter on some SYS clock cycles which are not exactly 2MHz the 
-- CPU may miss some cycles!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.board_config_pack.all;


entity fb_cpu_65c02 is
		generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		cpu_speed_i								: in std_logic;				-- 1 for 8MHz else 2MHz
		fb_syscon_i								: in fb_syscon_t;

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

		-- cpu throttle
		throttle_cpu_2MHz_i					: in std_logic;
		cpu_2MHz_phi2_clken_i				: in std_logic;

		-- direct CPU control signals from system
		nmi_n_i									: in	std_logic;
		irq_n_i									: in	std_logic;

		-- state machine signals
		wrap_cyc_o								: out std_logic;								-- signal to state machine that we want access at some point soon
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
end fb_cpu_65c02;

architecture rtl of fb_cpu_65c02 is
	signal r_prev_A0			: std_logic;

	signal r_PHI0				: std_logic;
	signal r_PHI0_dly			: std_logic_vector(3 downto 0);

	type t_state is (
		phi1,
		phi2
		);

	signal r_state				: t_state;

	subtype t_substate is unsigned(4 downto 0); -- divide down by a max of 64/2

	signal r_substate			: t_substate := (others => '1');	
	signal r_rdy_ctup			: t_substate := (others => '1'); -- this counts up since data was ready


	--TODO: sort this all out to be more intuitive 

	constant SUBSTATEMAX_2	: t_substate := to_unsigned(31, t_substate'length);
	constant SUBSTATEMAX_8	: t_substate := to_unsigned(7, t_substate'length);

	-- address latch state:
	constant SUBSTATE_A_2	: t_substate := SUBSTATEMAX_2 - to_unsigned(6, t_substate'length);		-- TODO: this is too fast for a 2MHz part!
	constant SUBSTATE_A_8	: t_substate := SUBSTATEMAX_8 - to_unsigned(6, t_substate'length);

	constant SUBSTATE_D_2	: t_substate := to_unsigned(2, t_substate'length);		-- TODO: this is too fast for a 2MHz part!
	constant SUBSTATE_D_8	: t_substate := to_unsigned(1, t_substate'length);

	constant SUBSTATE_D_WR_2: t_substate := SUBSTATEMAX_2 - to_unsigned(7, t_substate'length);		-- TODO: this is too fast for a 2MHz part!
	constant SUBSTATE_D_WR_8: t_substate := SUBSTATEMAX_8 - to_unsigned(6, t_substate'length);


	signal r_cpu_hlt			: std_logic;	-- need to register this at the start of the cycle following
														-- halt being asserted to stop that cycle from starting
	signal r_cpu_res			: std_logic;

	signal r_boot_65816_dly	: std_logic_vector(2 downto 0) := (others => '1');
	signal r_a_stb				: std_logic;		-- '1' for 1 cycle at start of a master cycle
	signal r_D_WR_stb			: std_logic;
	signal r_inihib			: std_logic;		-- '1' throughout an inhibited cycle

	signal r_log_A				: std_logic_vector(23 downto 0);

	signal i_ack				: std_logic;

	signal r_fbreset_prev	: std_logic := '0';

	signal r_throttle_cpu_2MHz : std_logic;

begin


	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity error;


	CPU_D_RnW_o <= 	'1' 	when CPUSKT_RnWZnWR_i = '1' 					
										and (r_PHI0_dly(r_PHI0_dly'high) = '1' 	
										or r_PHI0_dly(0) = '1')
										else												
							'0';


	wrap_A_log_o 			<= r_log_A;
	wrap_cyc_o	 			<= r_a_stb;
	wrap_A_we_o  			<= not(CPUSKT_RnWZnWR_i);
	wrap_D_wr_o				<=	CPUSKT_D_i;	
	wrap_D_wr_stb_o		<= r_D_WR_stb;
	wrap_ack_o				<= i_ack;


	p_phi0_dly:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_PHI0_dly <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
			r_PHI0_dly <= r_PHI0_dly(r_PHI0_dly'high-1 downto 0) & r_PHI0;
		end if;
	end process;

	p_state:process(fb_syscon_i)
	variable v_ctupnext : t_substate;	
	begin
		if rising_edge(fb_syscon_i.clk) then

			r_a_stb <= '0';
			r_D_WR_stb <= '0';

			if wrap_rdy_ctdn_i = RDY_CTDN_MIN then
				v_ctupnext := r_rdy_ctup + 1;
				if v_ctupnext /= 0 then
					r_rdy_ctup <= v_ctupnext;
				end if;
			end if;

			case r_state is
				when phi1 =>
					if (r_substate = SUBSTATE_A_2 and cpu_speed_i = '0') or
						(r_substate = SUBSTATE_A_8 and cpu_speed_i = '1') then
	
						if r_cpu_hlt = '0' then
							-- not boot mode map direct
							r_log_A <= x"FF" & CPUSKT_A_i(15 downto 0);
						end if;


						if  noice_debug_inhibit_cpu_i = '0' and
							 fb_syscon_i.rst = '0' and
							 cpu_halt_i = '0' then
							r_a_stb <= '1';
							r_D_WR_stb <= '0';
							r_rdy_ctup <= (others => '0');
							r_inihib <= '0';
						else
							r_inihib <= '1';
						end if;

						if fb_syscon_i.rst = '1' or cpu_en_i = '0' then
							r_cpu_hlt <= '0';
							r_cpu_res <= '1';
						else
							r_cpu_hlt <= cpu_halt_i;
							r_cpu_res <= '0';												
						end if;
					end if;

					if r_substate = 0 then

						r_state <= phi2;
						r_PHI0 <= '1';
						if cpu_speed_i = '0' then
							r_substate <= SUBSTATEMAX_2;
						else
							r_substate <= SUBSTATEMAX_8;
						end if;
					else
						r_substate <= r_substate - 1;
					end if;

				when phi2 =>

					if (r_substate = SUBSTATE_D_WR_2 and cpu_speed_i = '0') or
						(r_substate = SUBSTATE_D_WR_8 and cpu_speed_i = '1') then
						r_D_WR_stb <= '1';
					end if;

					if r_substate = 0 then

						if i_ack then
							r_state <= phi1;
							r_PHI0 <= '0';
							r_throttle_cpu_2MHz <= throttle_cpu_2MHz_i;
							if cpu_speed_i = '0' then
								r_substate <= SUBSTATEMAX_2;
							else
								r_substate <= SUBSTATEMAX_8;
							end if;
						end if;
					else
						r_substate <= r_substate - 1;
					end if;

				when others =>
					r_state <= phi1;
					r_substate <= SUBSTATEMAX_2;
					r_PHI0 <= '0';
			end case;


			-- bodge for reset - need to better work out the state machine!
			if r_fbreset_prev = '0' and fb_syscon_i.rst = '1' then
				r_state <= phi1;
				r_substate <= SUBSTATEMAX_2;
				r_PHI0 <= '0';				
				r_throttle_cpu_2MHz <= throttle_cpu_2MHz_i;
			end if;
			r_fbreset_prev <= fb_syscon_i.rst;


		end if;
	end process;

	i_ack <= '1' when
		r_state = phi2 and
		r_substate = 0 and
		(
			r_inihib = '1' or
			r_cpu_res = '1' or
			(r_rdy_ctup >= SUBSTATE_D_2 and cpu_speed_i = '0') or
			(r_rdy_ctup >= SUBSTATE_D_8 and cpu_speed_i = '1') 
		) and
		(r_throttle_cpu_2MHz = '0' or cpu_2MHz_phi2_clken_i = '1')

			else
				'0';



	CPUSKT_6BE9TSCKnVPA_o <= cpu_en_i;
	
	CPUSKT_KnBRZnBUSREQ_o <= '1';	
	
	CPUSKT_PHI09EKZCLK_o <= r_PHI0;
	
	CPUSKT_9Q_o <= '1';
	
	CPUSKT_nRES_o <= not r_cpu_res;
	
	CPUSKT_nNMIKnIPL02_o <= noice_debug_nmi_n_i and nmi_n_i;
	
	CPUSKT_nIRQKnIPL1_o <=  irq_n_i;
  	
  	CPUSKT_9nFIRQLnDTACK_o <=  '1';

  	CPUSKT_RDY9KnHALTZnWAIT_o <= 	'0' when r_cpu_hlt = '1' else
  											'1';						

--=======================================================================================
-- NoIce stuff
--=======================================================================================

   p_prev_a0:process(fb_syscon_i) 
  	begin
  		if fb_syscon_i.rst = '1' then
  			r_prev_A0 <= '0';
  		elsif rising_edge(fb_syscon_i.clk) then
  			if r_state = phi2 and r_substate = 0 then
  				r_prev_A0 <= CPUSKT_A_i(0);
  			end if;
  		end if;
  	end process;


	noice_debug_A0_tgl_o <= r_prev_A0 xor CPUSKT_A_i(0);

  	noice_debug_cpu_clken_o <= '1' when r_state = phi2 and r_substate = 0 else '0';

  	noice_debug_5c_o	 <= '1' when 
  										CPUSKT_SYNC6VPA9LICKFC2ZnM1_i = '1' 
  										and CPUSKT_D_i = x"5C" else
  								'0';

  	noice_debug_opfetch_o <= CPUSKT_SYNC6VPA9LICKFC2ZnM1_i and not r_cpu_hlt;



end rtl;
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
-- Create Date:    	9/8/2020
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - 68008
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the 68008 processor slot
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
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


entity fb_cpu_68k is
	generic (
		CLOCKSPEED							: positive := 128;
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		G_BYTELANES							: positive := 2
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		cfg_mosram_i							: in std_logic;				-- 1 means map boot rom at 7D xxxx else 8D xxxx
		cfg_cpu_speed_i						: in std_logic;
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
		wrap_cyc_o								: out std_logic_vector(G_BYTELANES-1 downto 0);
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
		CPUSKT_D_i								: in		std_logic_vector((G_BYTELANES*8)-1 downto 0);

		CPUSKT_A_i								: in		std_logic_vector(23 downto 0);
		
		exp_PORTB_o								: out		std_logic_vector(7 downto 0);

		exp_PORTD_i								: in		std_logic_vector(11 downto 0);
		exp_PORTD_o								: out		std_logic_vector(11 downto 0);
		exp_PORTD_o_en							: out		std_logic_vector(11 downto 0);

		exp_PORTE_nOE							: out		std_logic;	-- enable that multiplexed buffer chip
		exp_PORTF_nOE							: out		std_logic;	-- enable that multiplexed buffer chip


		-- special m68k signals

		jim_en_i									: in		std_logic

	);
end fb_cpu_68k;

architecture rtl of fb_cpu_68k is

--TODO: only uses address lines 19 downto 0!

-- timings below in number of fast clocks
	constant C_CLKD2_10		: natural 		:= 6;		-- clock half period - 10.666MHZ
	constant C_CLKD2_20		: natural 		:= 3;		-- clock half period - 10.666MHZ


	signal r_clkctdn			: unsigned(NUMBITS(C_CLKD2_10)-1 downto 0) := to_unsigned(C_CLKD2_10-1, NUMBITS(C_CLKD2_10));

	signal r_cpu_clk			: std_logic;

	signal r_m68k_boot		: std_logic;

	signal r_cyc_o				: std_logic_vector(G_BYTELANES-1 downto 0);

	signal i_rdy				: std_logic;

	signal r_A_log				: std_logic_vector(23 downto 0);
	signal i_A_log				: std_logic_vector(23 downto 0);
	signal r_WE					: std_logic;
	signal r_WR_stb			: std_logic;

	-- signal to cpu that cycle is about to finish
	signal r_ndtack			: std_logic;
	signal r_ndtack2			: std_logic;

	-- enable dtack to be signalled in this byte lane's cycle
	signal r_lastcyc			: std_logic;

	signal r_noice_clken		: std_logic;

	-- port B
	signal i_CPUSKT_VPA_o	: std_logic;
	signal i_CPUSKT_CLK_o	: std_logic;
	signal i_CPUSKT_nIPL2_o	: std_logic;
	signal i_CPUSKT_nIPL0_o	: std_logic;
	signal i_CPUSKT_nIPL1_o	: std_logic;

	-- port D in
	signal i_CPUSKT_nBG_i	: std_logic;
	signal i_CPUSKT_RnW_i	: std_logic;
	signal i_CPUSKT_nUDS_i	: std_logic;
	signal i_CPUSKT_FC0_i	: std_logic;
	signal i_CPUSKT_FC2_i	: std_logic;
	signal i_CPUSKT_nAS_i	: std_logic;
	signal i_CPUSKT_FC1_i	: std_logic;

	-- port D out
	signal i_CPUSKT_nRES_o	: std_logic;
	signal i_CPUSKT_nHALT_o	: std_logic;


	signal i_nDS_either		: std_logic; -- either of the LDS/UDS is low or 8 bit DS is low
	signal r_cpuskt_A_vector: std_logic; -- the registered cpu address was at 00 00xx
	-- delayed/stabilised async signals
	signal i_nAS_m				: std_logic;
	signal i_nDS_either_m	: std_logic;
	signal i_RnW_m				: std_logic;
	signal r_cpuskt_A_m		: std_logic_vector(23 downto 0);

	type	t_state is (
		idle 			-- waiting for a cpu cycle to start
	,	idle_wr_ds	-- waiting for U/LDS to be ready on a 16 bit write cycle
	,	wr_l			-- write cycle 16 bit low
	,	wr_u			-- write cycle 16 bit upper
	,	rd_l			-- read cycle 8 bit/16 bit low
	,	rd_u			-- read cycle 16 bit upper
	,	wait_as_de	-- cycle done, wait for AS to go high
	,  reset0		-- reset buffers and wait
	,  reset1		-- reset buffers and wait
		);

	signal r_state				: t_state;
	signal r_PORTE_nOE		: std_logic;
	signal r_PORTF_nOE		: std_logic;

	signal i_cyc_ack_i		: std_logic;
	signal r_wrap_cyc_dly	: std_logic;

begin

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity failure;
	assert G_BYTELANES >= 2 report "G_BYTELANES must be 2 or greater" severity failure;

	exp_PORTB_o(0) <= i_CPUSKT_VPA_o;
	exp_PORTB_o(1) <= '1';
	exp_PORTB_o(2) <= i_CPUSKT_CLK_o;
	exp_PORTB_o(3) <= '1';
	exp_PORTB_o(4) <= i_CPUSKT_nIPL1_o;
	exp_PORTB_o(5) <= i_CPUSKT_nIPL0_o;
	exp_PORTB_o(6) <= i_CPUSKT_nIPL2_o;
	exp_PORTB_o(7) <= r_ndtack2;


	i_CPUSKT_RnW_i		<= exp_PORTD_i(1);
	i_CPUSKT_nUDS_i	<= exp_PORTD_i(2);
	i_CPUSKT_FC0_i		<= exp_PORTD_i(3);
	i_CPUSKT_FC2_i		<= exp_PORTD_i(4);
	i_CPUSKT_nAS_i		<= exp_PORTD_i(5);
	i_CPUSKT_FC1_i		<= exp_PORTD_i(6);
	i_CPUSKT_nBG_i		<= exp_PORTD_i(7);

	exp_PORTD_o <= (
		8 => '1',										-- nBR
		9 => i_CPUSKT_nRES_o,
		10 => i_CPUSKT_nHALT_o,					-- 68K halt
		others => '1'

		);

	exp_PORTD_o_en <= (
		8 => '1',
		9 => '1',
		10 => '1',
		others => '0'
		);

	exp_PORTE_nOE <= r_PORTE_nOE;
	exp_PORTF_nOE <= r_PORTF_nOE;

	-- TODO: make this a register in state machine and delay?
	CPU_D_RnW_o <= 	'0' when i_CPUSKT_RnW_i = '0' else
							'1';


	wrap_A_log_o 			<= r_A_log;
	wrap_cyc_o 				<= r_cyc_o;
	wrap_A_we_o  			<= r_WE;
	wrap_D_wr_o				<=	CPUSKT_D_i(15 downto 8) when r_state = wr_u else
									CPUSKT_D_i(7 downto 0);	
	wrap_D_wr_stb_o		<= r_WR_stb;
	wrap_ack_o				<= i_cyc_ack_i;


	i_cyc_ack_i 			<= '1' when wrap_rdy_ctdn_i = RDY_CTDN_MIN and r_wrap_cyc_dly = '1' 
									else '0';

	-- either DS is low or 8 bit
	i_nDS_either <= i_CPUSKT_nUDS_i when cfg_cpu_speed_i = '1' else -- 68008
						i_CPUSKT_nUDS_i and CPUSKT_A_i(0); -- 68000

	-- register async signals for meta stability and to delay relative to each other
	e_m_DS_e:entity work.metadelay 
		generic map ( N => 2 ) 
		port map (clk => fb_syscon_i.clk, i => i_nDS_either, o => i_nDS_either_m);

	e_m_AS_e:entity work.metadelay 
		generic map ( N => 3 ) 
		port map (clk => fb_syscon_i.clk, i => i_CPUSKT_nAS_i, o => i_nAS_m);

	e_m_RnW_e:entity work.metadelay 
		generic map ( N => 1 ) 
		port map (clk => fb_syscon_i.clk, i => i_CPUSKT_RnW_i, o => i_RnW_m);

	e_cyc_dly_e:entity work.metadelay 
		generic map ( N => 1 ) 
		port map (clk => fb_syscon_i.clk, i => wrap_cyc_i, o => r_wrap_cyc_dly);

	-- register and fiddle cpu socket address, bodge for upper/lower byte
	p_reg_cpu_A:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_cpuskt_A_m <= (others => '0');
			r_cpuskt_A_vector <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if r_state = idle or r_state = reset1 then
				r_cpuskt_A_vector <= '0';
				r_cpuskt_A_m(23 downto 1) <= CPUSKT_A_i(23 downto 1);
				if CPUSKT_A_i(19 downto 8) = x"000" and (cfg_cpu_speed_i = '1' or CPUSKT_A_i(23 downto 20) = x"0") then
					r_cpuskt_A_vector <= '1';
				end if;

				if cfg_cpu_speed_i = '1' then
					r_cpuskt_A_m(0) <= CPUSKT_A_i(0);
				else
					r_cpuskt_A_m(0) <= '0';
				end if;	
			end if;
		end if;
	end process;

	i_A_log 	<= 
					x"7D3F" & r_cpuskt_A_m(7 downto 0) 	-- boot from SWRAM at 7D xxxx
							when r_cpuskt_A_vector = '1' and r_m68k_boot = '1' and i_RnW_m = '1' and cfg_mosram_i = '1' else
					x"8D3F" & r_cpuskt_A_m(7 downto 0) 	-- boot from Flash at 8D xxxx
							when r_cpuskt_A_vector = '1' and r_m68k_boot = '1' and i_RnW_m = '1' else
					r_cpuskt_A_m 
							when cfg_cpu_speed_i = '0' else
					x"F" & r_cpuskt_A_m(19 downto 0) 
							when r_cpuskt_A_m(19 downto 16) = x"F" 
								or r_cpuskt_A_m(19 downto 16) = x"E"	else -- sys or chipset
			      x"7" & r_cpuskt_A_m(19 downto 0) 
			      		when r_cpuskt_A_m(19 downto 16) = x"D" and cfg_mosram_i = '1' else -- Flash ROM
			      x"8" & r_cpuskt_A_m(19 downto 0) 
			      		when r_cpuskt_A_m(19 downto 16) = x"D" else -- Flash ROM
			      x"0" & r_cpuskt_A_m(19 downto 0); -- RAM

   

	p_cpu_clk:process(fb_syscon_i)
	begin

		if rising_edge(fb_syscon_i.clk) then
			if r_clkctdn = 0 then
				if r_cpu_clk = '1' then
					r_cpu_clk <= '0';
				else
					r_cpu_clk <= '1';					
				end if;
				if cfg_cpu_speed_i = '1' then
					r_clkctdn <= to_unsigned(C_CLKD2_10-1, r_clkctdn'length);
				else
					r_clkctdn <= to_unsigned(C_CLKD2_20-1, r_clkctdn'length);					
				end if;
			else
				r_clkctdn <= r_clkctdn - 1;
			end if;

		end if;

	end process;


	p_act:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_cyc_o <= (others => '0');
			r_noice_clken <= '0';
			r_WR_stb <= '0';
			r_WE <= '0';
			r_A_log <= (others => '0');
			r_noice_clken <= '0';
			r_state <= reset0;
			r_A_log <= (others => '0');			
			r_PORTE_nOE <= '0';
			r_PORTF_nOE <= '1';
			r_lastcyc <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			r_noice_clken <= '0';
			r_WR_stb <= '0';
			r_cyc_o <= (others => '0');

			case r_state is 
				when idle =>
					if i_nAS_m = '0' then
						-- start of cycle
						if i_RnW_m = '1' then
							if cfg_cpu_speed_i = '1' then
								-- don't need to wait to deduce byte lane
								r_state <= rd_l;
								r_cyc_o(0) <= '1';
								r_WE <= '0';
								r_lastcyc <= '1';
								r_A_log <= i_A_log;
							else							
								if i_CPUSKT_nUDS_i = '0' then
									-- upper first
									r_state <= rd_u;
									r_cyc_o(1) <= '1';
									r_WE <= '0';
									r_A_log <= i_A_log;
									-- only allow dtack if the lower isn't needed
									r_lastcyc <= CPUSKT_A_i(0);
								else
									r_state <= rd_l;
									r_cyc_o(0) <= '1';
									r_WE <= '0';
									r_A_log <= i_A_log(23 downto 1) & '1';
									r_lastcyc <= '1';
								end if;
							end if;
						else
							if cfg_cpu_speed_i = '1' then
								r_state <= wr_l;
								r_cyc_o(0) <= '1';
								r_WE <= '1';
								r_lastcyc <= '1';
							else
								r_state <= idle_wr_ds;
							end if;
						end if;
						--TODO: - should this be staggered to avoid two drivers?
						r_PORTF_nOE <= '0';
						r_PORTE_nOE <= '1';
					end if;
				when idle_wr_ds =>
					if i_nDS_either_m = '0' then
						if i_CPUSKT_nUDS_i = '0' then
							r_state <= wr_u;
							r_cyc_o(1) <= '1';
							r_WE <= '1';
							r_lastcyc <= CPUSKT_A_i(0);
							r_A_log <= i_A_log;
							r_WR_stb <= '1';
						else
							r_state <= wr_l;
							r_cyc_o(0) <= '1';
							r_WE <= '1';
							r_lastcyc <= '1';
							r_A_log <= i_A_log(23 downto 1) & '1';
							r_WR_stb <= '1';
						end if;
					end if;
				when rd_u =>
					if i_cyc_ack_i = '1' then
						if cfg_cpu_speed_i = '1' or CPUSKT_A_i(0) = '1' then
							r_state <= wait_as_de;
						else
							r_A_log(0) <= '1';
							r_cyc_o(0) <= '1';
							r_state <= rd_l;
							r_lastcyc <= '1';
						end if;
					end if;
				when rd_l =>
					if i_cyc_ack_i = '1' then
						r_state <= wait_as_de;
					end if;
				when wr_u =>
					if cfg_cpu_speed_i = '1' and i_CPUSKT_nUDS_i = '0' then
						r_WR_stb <= '1';
					end if;
					if i_cyc_ack_i = '1' then
						if cfg_cpu_speed_i = '1' or CPUSKT_A_i(0) = '1' then
							r_state <= wait_as_de;
						else
							r_A_log(0) <= '1';
							r_cyc_o(0) <= '1';
							r_state <= wr_l;							
							r_lastcyc <= '1';
							r_WR_stb <= '1';
						end if;
					end if;
				when wr_l =>
					if i_cyc_ack_i = '1' then
						r_state <= wait_as_de;
					end if;
				when wait_as_de =>
					if i_nAS_m = '1' then
						r_state <= reset0;						
					end if;
				when reset1 => 
					r_state <= idle;
				when others => 			-- or reset0
					r_state <= reset1;
					r_PORTE_nOE <= '0';
					r_PORTF_nOE <= '1';
					r_lastcyc <= '0';

			end case;

		end if;
	end process;

	p_dtack:process(fb_syscon_i)
	begin

		if fb_syscon_i.rst = '1' then
			r_ndtack <= '1';
		elsif rising_edge(fb_syscon_i.clk) then
			if r_state = idle then
				r_ndtack <= '1';
			elsif r_wrap_cyc_dly = '1' and wrap_cyc_i = '1' and r_lastcyc = '1' then
				if (cfg_cpu_speed_i = '1' and wrap_rdy_ctdn_i <= C_CLKD2_10 * 2) or
					(cfg_cpu_speed_i = '0' and wrap_rdy_ctdn_i <= C_CLKD2_20 * 2) then 
					r_ndtack <= '0';
				end if;
			end if;
		end if;

	end process;

	p_dtack2:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_ndtack2 <= '1';
		elsif rising_edge(fb_syscon_i.clk) then
			if r_cpu_clk = '0' then
				r_ndtack2 <= r_ndtack;
			end if;
		end if;
	end process;


	-- assert vpa during interrupt for autovectoring
	i_CPUSKT_VPA_o					<= '0' when  i_CPUSKT_FC0_i = '1' 
													and i_CPUSKT_FC1_i = '1' 
													and i_CPUSKT_FC2_i = '1' else
								 			'1';

	i_CPUSKT_CLK_o 				<= r_cpu_clk;



	i_CPUSKT_nIPL2_o 				<= nmi_n_i and noice_debug_nmi_n_i;
	i_CPUSKT_nIPL0_o	 			<= nmi_n_i and noice_debug_nmi_n_i;
	i_CPUSKT_nIPL1_o 				<= irq_n_i and noice_debug_nmi_n_i;

	i_CPUSKT_nRES_o				<= not fb_syscon_i.rst;

  	i_CPUSKT_nHALT_o				<= '0' when fb_syscon_i.rst = '1' else
  											'1' when noice_debug_inhibit_cpu_i = '1' else
  											not cpu_halt_i;


	p_m68k_boot:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_m68k_boot <= '1';
		elsif rising_edge(fb_syscon_i.clk) then
			if JIM_en_i = '1' then
				r_m68k_boot <= '0';
			end if;
		end if;
	end process;


  	noice_debug_cpu_clken_o <= r_noice_clken;
  	
  	noice_debug_5c_o	 	 	<=	'0';

  	noice_debug_opfetch_o 	<= '1' when i_CPUSKT_FC1_i = '1' and i_CPUSKT_FC0_i = '0' else
  										'0';

	noice_debug_A0_tgl_o  	<= '0';



end rtl;

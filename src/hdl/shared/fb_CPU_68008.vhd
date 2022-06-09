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
-- Description: 		A fishbone wrapper for the 68k processor slot
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
use work.board_config_pack.all;
use work.fb_cpu_pack.all;
use work.fb_cpu_exp_pack.all;

entity fb_cpu_68008 is
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

		jim_en_i									: in		std_logic

	);
end fb_cpu_68008;

architecture rtl of fb_cpu_68008 is

--TODO: only uses address lines 19 downto 0!

-- timings below in number of fast clocks
	constant C_CLKD2_10		: natural 		:= 6;		-- clock half period - 10.666MHZ
	constant C_CLKD2_20		: natural 		:= 3;		-- clock half period - 21.333MHZ


	signal r_clkctdn			: unsigned(NUMBITS(C_CLKD2_10)-1 downto 0) := to_unsigned(C_CLKD2_10-1, NUMBITS(C_CLKD2_10));

	signal r_cpu_clk			: std_logic;

	signal r_m68k_boot		: std_logic;

	signal r_cyc_o				: std_logic;

	signal i_rdy				: std_logic;

	signal r_A_log				: std_logic_vector(23 downto 0);
	signal i_A_log				: std_logic_vector(23 downto 0);
	signal r_WE					: std_logic;
	signal r_WR_stb			: std_logic;

	-- signal to cpu that cycle is about to finish
	signal r_ndtack			: std_logic;
	signal r_ndtack2			: std_logic;

	signal r_noice_clken		: std_logic;

	signal i_CPUSKT_VPA_o	: std_logic;
	signal i_CPUSKT_CLK_o	: std_logic;
	signal i_CPUSKT_nIPL02_o: std_logic;
	signal i_CPUSKT_nIPL1_o	: std_logic;
	signal i_CPUSKT_nDTACK_o: std_logic;
	signal i_CPUSKT_nRES_o	: std_logic;
	signal i_CPUSKT_nHALT_o	: std_logic;

	signal i_CPU_D_RnW_o		: std_logic;

	signal i_CPUSKT_nBG_i	: std_logic;
	signal i_CPUSKT_RnW_i	: std_logic;
	signal i_CPUSKT_nDS_i	: std_logic;
	signal i_CPUSKT_FC0_i	: std_logic;
	signal i_CPUSKT_FC2_i	: std_logic;
	signal i_CPUSKT_nAS_i	: std_logic;
	signal i_CPUSKT_FC1_i	: std_logic;
	signal i_CPUSKT_E_i		: std_logic;

	signal i_CPUSKT_D_i		: std_logic_vector(7 downto 0);
	signal i_CPUSKT_A_i		: std_logic_vector(19 downto 0);

	signal i_nDS_either		: std_logic; -- either of the LDS/UDS is low or 8 bit DS is low
	signal r_cpuskt_A_vector: std_logic; -- the registered cpu address was at 00 00xx
	-- delayed/stabilised async signals
	signal i_nAS_m				: std_logic;
	signal i_nDS_either_m	: std_logic;
	signal i_RnW_m				: std_logic;
	signal r_cpuskt_A_m		: std_logic_vector(19 downto 0);

	type	t_state is (
		idle 			-- waiting for a cpu cycle to start
	,	idle_wr_ds	-- waiting for U/LDS to be ready on a 16 bit write cycle
	,	wr				-- write cycle
	,	rd				-- read cycle 
	,	wait_as_de	-- cycle done, wait for AS to go high
	,  reset0		-- reset buffers and wait
	,  reset1		-- reset buffers and wait
		);

	signal r_state				: t_state;

	signal i_cyc_ack_i		: std_logic;
	signal r_wrap_cyc_dly	: std_logic;

begin

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity failure;

	e_pinmap:entity work.fb_cpu_68008_exp_pins
	port map(

		-- cpu wrapper signals
		wrap_exp_o => wrap_exp_o,
		wrap_exp_i => wrap_exp_i,

		-- local 6x09 wrapper signals to/from CPU expansion port 

		CPUSKT_VPA_i		=> i_CPUSKT_VPA_o,
		CPUSKT_CLK_i		=> i_CPUSKT_CLK_o,
		CPUSKT_nHALT_i		=> i_CPUSKT_nHALT_o,
		CPUSKT_nIPL1_i		=> i_CPUSKT_nIPL1_o,
		CPUSKT_nIPL02_i	=> i_CPUSKT_nIPL02_o,
		CPUSKT_nRES_i		=> i_CPUSKT_nRES_o,
		CPUSKT_nDTACK_i	=> i_CPUSKT_nDTACK_o,

		CPUSKT_E_o			=> i_CPUSKT_E_i,
		CPUSKT_nBG_o		=> i_CPUSKT_nBG_i,
		CPUSKT_RnW_o		=> i_CPUSKT_RnW_i,
		CPUSKT_nDS_o		=> i_CPUSKT_nDS_i,
		CPUSKT_FC0_o		=> i_CPUSKT_FC0_i,
		CPUSKT_FC2_o		=> i_CPUSKT_FC2_i,
		CPUSKT_nAS_o		=> i_CPUSKT_nAS_i,
		CPUSKT_FC1_o		=> i_CPUSKT_FC1_i,

		-- shared per CPU signals
		CPU_D_RnW_i			=> i_CPU_D_RnW_o,

		CPUSKT_A_o			=> i_CPUSKT_A_i,
		CPUSKT_D_o			=> i_CPUSKT_D_i

	);



	-- TODO: make this a register in state machine and delay?
	i_CPU_D_RnW_o <= 	'0' when i_CPUSKT_RnW_i = '0' else
							'1';


	wrap_o.A_log 			<= r_A_log;
	wrap_o.cyc(0)			<= r_cyc_o;
	wrap_o.we	  			<= r_WE;
	wrap_o.D_wr				<=	i_CPUSKT_D_i;	
	wrap_o.D_wr_stb		<= r_WR_stb;
	wrap_o.ack				<= i_cyc_ack_i;

	i_cyc_ack_i 			<= '1' when wrap_i.rdy_ctdn = RDY_CTDN_MIN and r_wrap_cyc_dly = '1' 
									else '0';

	-- either DS is low or 8 bit
	i_nDS_either <= i_CPUSKT_nDS_i;

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
		port map (clk => fb_syscon_i.clk, i => wrap_i.cyc, o => r_wrap_cyc_dly);

	-- register and fiddle cpu socket address, bodge for upper/lower byte
	p_reg_cpu_A:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_cpuskt_A_m <= (others => '0');
			r_cpuskt_A_vector <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if r_state = idle or r_state = reset1 then
				r_cpuskt_A_vector <= '0';
				r_cpuskt_A_m <= i_CPUSKT_A_i;
				if i_CPUSKT_A_i(19 downto 8) = x"000" then
					r_cpuskt_A_vector <= '1';
				end if;
			end if;
		end if;
	end process;

	i_A_log 	<= 
					-- TODO: simplify these down to FFFF to boot from MOS rom in SYS map?
					x"7D3F" & r_cpuskt_A_m(7 downto 0) 	-- boot from SWRAM at 7D xxxx
							when r_cpuskt_A_vector = '1' and r_m68k_boot = '1' and i_RnW_m = '1' and cfg_mosram_i = '1' else
					x"8D3F" & r_cpuskt_A_m(7 downto 0) 	-- boot from Flash at 8D xxxx
							when r_cpuskt_A_vector = '1' and r_m68k_boot = '1' and i_RnW_m = '1' else
					x"F" & r_cpuskt_A_m 
							when r_cpuskt_A_m(19 downto 16) = x"F" 
								or r_cpuskt_A_m(19 downto 16) = x"E"	else -- sys or chipset
			      x"7" & r_cpuskt_A_m
			      		when r_cpuskt_A_m(19 downto 16) = x"D" and cfg_mosram_i = '1' else -- BB/Chip RAM MOS ROM
			      x"8" & r_cpuskt_A_m
			      		when r_cpuskt_A_m(19 downto 16) = x"D" else -- Flash MOS ROM
			      x"0" & r_cpuskt_A_m; -- RAM

	p_cpu_clk:process(fb_syscon_i)
	begin

		if rising_edge(fb_syscon_i.clk) then
			if r_clkctdn = 0 then
				if r_cpu_clk = '1' then
					r_cpu_clk <= '0';
				else
					r_cpu_clk <= '1';					
				end if;
				r_clkctdn <= to_unsigned(C_CLKD2_10-1, r_clkctdn'length);
			else
				r_clkctdn <= r_clkctdn - 1;
			end if;

		end if;

	end process;


	p_act:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_cyc_o <= '0';
			r_noice_clken <= '0';
			r_WR_stb <= '0';
			r_WE <= '0';
			r_A_log <= (others => '0');
			r_noice_clken <= '0';
			r_state <= reset0;
			r_A_log <= (others => '0');			
		elsif rising_edge(fb_syscon_i.clk) then
			r_noice_clken <= '0';
			r_WR_stb <= '0';
			r_cyc_o <= '0';
			
			case r_state is 
				when idle =>
					if i_nAS_m = '0' then
						-- start of cycle
						if i_RnW_m = '1' then
							r_state <= rd;
							r_cyc_o <= '1';
							r_WE <= '0';
							r_A_log <=	i_A_log;
						else
							r_state <= idle_wr_ds;
						end if;
					end if;
				when idle_wr_ds =>
					if i_nDS_either_m = '0' then
						r_state <= wr;
						r_cyc_o <= '1';
						r_WE <= '1';
						r_A_log <= i_A_log;
						r_WR_stb <= '1';
					end if;
				when rd =>
					if i_cyc_ack_i = '1' then
						r_state <= wait_as_de;
					end if;
				when wr =>
					r_WR_stb <= '1';
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
			elsif r_wrap_cyc_dly = '1' and wrap_i.cyc = '1' then
				if (wrap_i.rdy_ctdn <= C_CLKD2_10 * 2) then 
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
	i_CPUSKT_nDTACK_o				<= r_ndtack2;


	i_CPUSKT_nIPL02_o	 			<= wrap_i.nmi_n and wrap_i.noice_debug_nmi_n;
	i_CPUSKT_nIPL1_o 				<= wrap_i.irq_n and wrap_i.noice_debug_nmi_n;

	i_CPUSKT_nRES_o				<= not fb_syscon_i.rst;

  	i_CPUSKT_nHALT_o				<= '0' when fb_syscon_i.rst = '1' else
  											'1' when wrap_i.noice_debug_inhibit_cpu = '1' else
  											not wrap_i.cpu_halt;


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


  	wrap_o.noice_debug_cpu_clken <= r_noice_clken;
  	
  	wrap_o.noice_debug_5c	 	 	<=	'0';

  	wrap_o.noice_debug_opfetch 	<= '1' when i_CPUSKT_FC1_i = '1' and i_CPUSKT_FC0_i = '0' else
  										'0';

	wrap_o.noice_debug_A0_tgl  	<= '0';



end rtl;

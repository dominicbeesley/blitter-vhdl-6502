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
-- Module Name:    	fishbone bus - CPU wrapper component - 680x0
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the 680x0 processor slot
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

entity fb_cpu_680x0 is
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
end fb_cpu_680x0;

architecture rtl of fb_cpu_680x0 is

--TODO: only uses address lines 19 downto 0!

-- timings below in number of fast clocks
	constant C_CLKD2_10		: natural 		:= 6;		-- clock half period - 10.666MHZ
	constant C_CLKD2_20		: natural 		:= 3;		-- clock half period - 21.333MHZ


	signal r_clkctdn			: unsigned(NUMBITS(C_CLKD2_10)-1 downto 0) := to_unsigned(C_CLKD2_10-1, NUMBITS(C_CLKD2_10));

	signal r_cpu_clk			: std_logic;

	signal r_m68k_boot		: std_logic;

	signal r_cyc				: std_logic;
	signal r_lane_req_o		: std_logic_vector(1 downto 0);
	signal i_rdy				: std_logic;
	signal r_A_log				: std_logic_vector(23 downto 0);
	signal i_A_log				: std_logic_vector(23 downto 0);
	signal r_WE					: std_logic;
	signal r_WR_stb			: std_logic;
	signal i_cyc_ack_i		: std_logic;

	-- signal to cpu that cycle is about to finish
	signal r_ndtack			: std_logic;

	signal r_noice_clken		: std_logic;

	-- port B
	signal i_CPUSKT_VPA_b2c	: std_logic;
	signal i_CPUSKT_CLK_b2c	: std_logic;
	signal i_CPUSKT_nIPL2_b2c	: std_logic;
	signal i_CPUSKT_nIPL0_b2c	: std_logic;
	signal i_CPUSKT_nIPL1_b2c	: std_logic;
	signal i_CPUSKT_nDTACK_b2c: std_logic;
	signal i_CPUSKT_nRES_b2c	: std_logic;
	signal i_CPUSKT_nHALT_b2c	: std_logic;

	signal i_BUF_D_RnW_b2c		: std_logic;

	signal i_CPUSKT_nBG_c2b	: std_logic;
	signal i_CPUSKT_RnW_c2b	: std_logic;
	signal i_CPUSKT_nUDS_c2b	: std_logic;
	signal i_CPUSKT_nLDS_c2b	: std_logic;
	signal i_CPUSKT_FC0_c2b	: std_logic;
	signal i_CPUSKT_FC2_c2b	: std_logic;
	signal i_CPUSKT_nAS_c2b	: std_logic;
	signal i_CPUSKT_FC1_c2b	: std_logic;
	signal i_CPUSKT_E_c2b		: std_logic;

	signal i_CPUSKT_D_c2b		: std_logic_vector(15 downto 0);
	signal i_CPUSKT_A_c2b		: std_logic_vector(23 downto 1);

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
	,	wr				-- write
	,	rd				-- read
	,	wait_as_de	-- cycle done, wait for AS to go high
	,  reset0		-- reset buffers and wait
	,  reset1		-- reset buffers and wait
		);

	type t_mux_state is (
		port_e,
		port_f_next,
		port_f,
		port_e_next
		);

	signal r_state_mux		: t_mux_state;
	signal i_PORTE_nOE		: std_logic;
	signal i_PORTF_nOE		: std_logic;
	signal r_state				: t_state;


begin


	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity failure;
	
	e_pinmap:entity work.fb_cpu_680x0_exp_pins
	port map(

		-- cpu wrapper signals
		wrap_exp_o => wrap_exp_o,
		wrap_exp_i => wrap_exp_i,

		-- local 6x09 wrapper signals to/from CPU expansion port 

		CPUSKT_VPA_b2c		=> i_CPUSKT_VPA_b2c,
		CPUSKT_CLK_b2c		=> i_CPUSKT_CLK_b2c,
		CPUSKT_nHALT_b2c	=> i_CPUSKT_nHALT_b2c,
		CPUSKT_nIPL0_b2c	=> i_CPUSKT_nIPL0_b2c,
		CPUSKT_nIPL1_b2c	=> i_CPUSKT_nIPL1_b2c,
		CPUSKT_nIPL2_b2c	=> i_CPUSKT_nIPL2_b2c,
		CPUSKT_nRES_b2c	=> i_CPUSKT_nRES_b2c,
		CPUSKT_nDTACK_b2c	=> i_CPUSKT_nDTACK_b2c,
		CPUSKT_D_b2c		=> wrap_i.D_rd(15 downto 0),

		BUF_D_RnW_b2c		=> i_BUF_D_RnW_b2c,

		CPUSKT_E_c2b		=> i_CPUSKT_E_c2b,
		CPUSKT_nBG_c2b		=> i_CPUSKT_nBG_c2b,
		CPUSKT_RnW_c2b		=> i_CPUSKT_RnW_c2b,
		CPUSKT_nUDS_c2b		=> i_CPUSKT_nUDS_c2b,
		CPUSKT_nLDS_c2b		=> i_CPUSKT_nLDS_c2b,
		CPUSKT_FC0_c2b		=> i_CPUSKT_FC0_c2b,
		CPUSKT_FC2_c2b		=> i_CPUSKT_FC2_c2b,
		CPUSKT_nAS_c2b		=> i_CPUSKT_nAS_c2b,
		CPUSKT_FC1_c2b		=> i_CPUSKT_FC1_c2b,

		-- shared per CPU signals

		CPUSKT_A_c2b			=> i_CPUSKT_A_c2b,
		CPUSKT_D_c2b			=> i_CPUSKT_D_c2b,

		-- socket muxing for extra 16 bit plug
		MUX_PORTE_nOE_i		=> i_PORTE_nOE,
		MUX_PORTF_nOE_i		=> i_PORTF_nOE

	);


	-- TODO: make this a register in state machine and delay?
	i_BUF_D_RnW_b2c <= 	'0' when i_CPUSKT_RnW_c2b = '0' else
							'1';


	wrap_o.be				<= '1';
	wrap_o.cyc				<= r_cyc;
	wrap_o.A		 			<= r_A_log;	
	wrap_o.lane_req		<= (
			0 => r_lane_req_o(0),
			1 => r_lane_req_o(1),
			others => '0');
	wrap_o.we	  			<= r_WE;
	wrap_o.D_wr(15 downto 0)
								<=	i_CPUSKT_D_c2b(15 downto 0);	
	G_D_WR_EXT:if C_CPU_BYTELANES > 2 GENERATE
		wrap_o.D_WR((8*C_CPU_BYTELANES)-1 downto 16) <= (others => '-');
	END GENERATE;
	wrap_o.D_wr_stb		<= (others => r_WR_stb);
--	wrap_o.rdy_ctdn		<= to_unsigned((C_CLKD2_20 * 2) + 3, t_rdy_ctdn'length);
	wrap_o.rdy_ctdn		<= to_unsigned((C_CLKD2_20 * 2), t_rdy_ctdn'length);

	i_cyc_ack_i 			<= wrap_i.ack;
	i_PORTE_nOE <= '0' when r_state_mux = port_e else '1';
	i_PORTF_nOE <= '0' when r_state_mux = port_f else '1';

	-- either DS is low or 8 bit
	i_nDS_either <= i_CPUSKT_nUDS_c2b and i_CPUSKT_nLDS_c2b;

	-- register async signals for meta stability and to delay relative to each other
--	e_m_DS_e:entity work.metadelay 
--		generic map ( N => 1 ) 
--		port map (clk => fb_syscon_i.clk, i => i_nDS_either, o => i_nDS_either_m);
i_nDS_either_m <= i_nDS_either;

	e_m_AS_e:entity work.metadelay 
		generic map ( N => 1 ) 
		port map (clk => fb_syscon_i.clk, i => i_CPUSKT_nAS_c2b, o => i_nAS_m);

--	e_m_RnW_e:entity work.metadelay 
--		generic map ( N => 0 ) 
--		port map (clk => fb_syscon_i.clk, i => i_CPUSKT_RnW_c2b, o => i_RnW_m);
i_RnW_m <= i_CPUSKT_RnW_c2b;

	-- register and fiddle cpu socket address, bodge for upper/lower byte
	p_reg_cpu_A:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_cpuskt_A_m <= (others => '0');
			r_cpuskt_A_vector <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if r_state = idle or r_state = reset1 then
				r_cpuskt_A_vector <= '0';
				r_cpuskt_A_m(23 downto 1) <= i_CPUSKT_A_c2b(23 downto 1);
				if i_CPUSKT_A_c2b(23 downto 8) = x"0000" then
					r_cpuskt_A_vector <= '1';
				end if;

				r_cpuskt_A_m(0) <= '0';
			end if;
		end if;
	end process;

	i_A_log 	<= 
					-- TODO: simplify these down to FFFF to boot from MOS rom in SYS map?
					x"7D3F" & r_cpuskt_A_m(7 downto 0) 	-- boot from SWRAM at 7D xxxx
							when r_cpuskt_A_vector = '1' and r_m68k_boot = '1' and i_RnW_m = '1' and cfg_mosram_i = '1' else
					x"8D3F" & r_cpuskt_A_m(7 downto 0) 	-- boot from Flash at 8D xxxx
							when r_cpuskt_A_vector = '1' and r_m68k_boot = '1' and i_RnW_m = '1' else
					r_cpuskt_A_m; -- RAM

   

	p_cpu_clk:process(fb_syscon_i)
	begin

		if rising_edge(fb_syscon_i.clk) then
			if r_clkctdn = 0 then
				if r_cpu_clk = '1' then
					r_cpu_clk <= '0';
				else
					r_cpu_clk <= '1';					
				end if;
					r_clkctdn <= to_unsigned(C_CLKD2_20-1, r_clkctdn'length);					
			else
				r_clkctdn <= r_clkctdn - 1;
			end if;

		end if;

	end process;




	p_act:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_lane_req_o <= (others => '0');
			r_noice_clken <= '0';
			r_WR_stb <= '0';
			r_WE <= '0';
			r_A_log <= (others => '0');
			r_noice_clken <= '0';
			r_state <= reset0;
			r_A_log <= (others => '0');			
			r_state_mux <= port_e;
			r_cyc <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			r_noice_clken <= '0';

			if r_state_mux = port_e_next then
				r_state_mux <= port_e;
			elsif r_state_mux = port_f_next then
				r_state_mux <= port_f;
			end if;

			case r_state is 
				when idle =>
					if i_nAS_m = '0' then
						-- start of cycle
						if i_RnW_m = '1' then
							r_cyc <= '1';
							r_state <= rd;
							r_lane_req_o <= not(i_CPUSKT_nUDS_c2b & i_CPUSKT_nLDS_c2b);
							r_we <= '0';
							r_A_log <= i_A_log(23 downto 1) & i_CPUSKT_nUDS_c2b;
						else
							r_state <= idle_wr_ds;
						end if;
						r_state_mux <= port_f_next;
					end if;
				when idle_wr_ds =>
					if i_nDS_either_m = '0' then
							r_cyc <= '1';
							r_state <= wr;
							r_lane_req_o <= not(i_CPUSKT_nUDS_c2b & i_CPUSKT_nLDS_c2b);
							r_we <= '1';
							r_A_log <= i_A_log(23 downto 1) & i_CPUSKT_nUDS_c2b;
							r_WR_stb <= '1';
					end if;
				when rd =>
					if i_cyc_ack_i = '1' then
						r_state <= wait_as_de;
						r_cyc <= '0';
					end if;
				when wr =>
					if i_cyc_ack_i = '1' then
						r_state <= wait_as_de;
						r_cyc <= '0';
					end if;
				when wait_as_de =>
					if i_nAS_m = '1' then
						r_state <= reset0;						
					end if;
				when reset1 => 
					r_state <= idle;
				when others => 			-- or reset0
					r_state <= reset1;
					r_state_mux <= port_e_next;
					r_cyc <= '0';
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
			elsif r_cyc = '1' then
				if wrap_i.rdy = '1' then 
					r_ndtack <= '0';
				end if;
			end if;
		end if;

	end process;

	-- assert vpa during interrupt for autovectoring
	i_CPUSKT_VPA_b2c					<= '0' when  i_CPUSKT_FC0_c2b = '1' 
													and i_CPUSKT_FC1_c2b = '1' 
													and i_CPUSKT_FC2_c2b = '1' else
								 			'1';

	i_CPUSKT_CLK_b2c 				<= r_cpu_clk;
	i_CPUSKT_nDTACK_b2c				<= r_ndtack;



	i_CPUSKT_nIPL2_b2c 				<= wrap_i.nmi_n and wrap_i.noice_debug_nmi_n;
	i_CPUSKT_nIPL0_b2c	 			<= wrap_i.nmi_n and wrap_i.noice_debug_nmi_n;
	i_CPUSKT_nIPL1_b2c 				<= wrap_i.irq_n and wrap_i.noice_debug_nmi_n;

	i_CPUSKT_nRES_b2c					<= not fb_syscon_i.rst when cpu_en_i = '1' else '0';

  	i_CPUSKT_nHALT_b2c				<= '0' when fb_syscon_i.rst = '1' else
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

  	wrap_o.noice_debug_opfetch 	<= '1' when i_CPUSKT_FC1_c2b = '1' and i_CPUSKT_FC0_c2b = '0' else
  										'0';

	wrap_o.noice_debug_A0_tgl  	<= '0';



end rtl;

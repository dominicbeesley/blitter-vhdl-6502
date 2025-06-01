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
-- Create Date:    	19/7/2022
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - arm2
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the arm2 processor slot
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

entity fb_cpu_arm2 is
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

		-- special arm2 signals

		jim_en_i									: in		std_logic

	);
end fb_cpu_arm2;

architecture rtl of fb_cpu_arm2 is

-- timings below in number of fast clocks
	constant C_CLKD2_8		: natural 		:= 8;		-- clock half period - 8MHz

	signal r_clkctdn			: unsigned(NUMBITS(C_CLKD2_8)-1 downto 0) := to_unsigned(C_CLKD2_8-1, NUMBITS(C_CLKD2_8));

	signal r_cpu_phi1			: std_logic;
	signal r_cpu_phi2			: std_logic;

	signal r_cyc_o				: std_logic;
	signal i_cyc_ack_i		: std_logic;
	signal r_D_wr_stb			: std_logic;

	signal r_arm_boot			: std_logic;							-- place ROM at 0-100 from 8D3Fxx at boot

	signal i_rdy				: std_logic;

	signal r_a_cpu				: std_logic_vector(23 downto 0);
	signal r_A_log				: unsigned(1 downto 0);
	signal r_WE					: std_logic;
	signal r_nMREQ				: std_logic;
	signal r_nOPC				: std_logic;
	signal r_nBW				: std_logic;
	signal r_nRW				: std_logic;
	signal r_instr_fetch		: std_logic;

	-- port B

	signal i_CPUSKT_ABRT_b2c	: std_logic;
	signal i_CPUSKT_phi1_b2c	: std_logic;
	signal i_CPUSKT_phi2_b2c	: std_logic;
	signal i_CPUSKT_nIRQ_b2c	: std_logic;
	signal i_CPUSKT_nFIRQ_b2c	: std_logic;
	signal i_CPUSKT_RES_b2c		: std_logic;

	signal i_CPUBRD_nBL_b2c		: std_logic_vector(3 downto 0);

	signal i_BUF_D_RnW_b2c		: std_logic;

	signal i_CPUSKT_nM_c2b		: std_logic_vector(1 downto 0);
	signal i_CPUSKT_nRW_c2b		: std_logic;
	signal i_CPUSKT_nBW_c2b		: std_logic;
	signal i_CPUSKT_nOPC_c2b	: std_logic;
	signal i_CPUSKT_nMREQ_c2b	: std_logic;
	signal i_CPUSKT_nTRAN_c2b	: std_logic;
	signal i_CPUSKT_SEQ_c2b		: std_logic;


	signal i_CPUSKT_D_mux_c2b	: std_logic_vector(7 downto 0);
	signal i_CPUSKT_D_mux_b2c	: std_logic_vector(7 downto 0);
	signal i_CPUSKT_A_c2b		: std_logic_vector(25 downto 0);

	signal i_readed_lane			: std_logic_vector(3 downto 0);
	signal r_readed_lane_prev	: std_logic_vector(3 downto 0);
	signal r_readed_lane_prev2	: std_logic_vector(3 downto 0);

	signal i_write_lane			: std_logic_vector(3 downto 0);
	signal r_writed_lane_prev	: std_logic_vector(3 downto 0);
	signal r_writed_lane_prev2	: std_logic_vector(3 downto 0);
	signal r_writed_lane_prev3	: std_logic_vector(3 downto 0);

	type t_clk_state is (
		phi1,
		phi2
		);

	signal r_clk_state		: t_clk_state;

	type t_mem_acc_state is (
		idle,
		rd,
		wr,
		done
		);

	signal r_mem_acc_state  : t_mem_acc_state;
	signal r_mem_acc_reset  : std_logic;	
	signal r_lane_req		: std_logic_vector(3 downto 0);

begin

	p_prio_readed:process(wrap_i.ack_lane)
	begin
		if wrap_i.ack_lane(3) = '1' then
			i_readed_lane <= "1000";
		elsif wrap_i.ack_lane(2) = '1' then
			i_readed_lane <= "0100";
		elsif wrap_i.ack_lane(1) = '1' then
			i_readed_lane <= "0010";
		elsif wrap_i.ack_lane(0) = '1' then
			i_readed_lane <= "0001";
		else
			i_readed_lane <= "0000";
		end if;	
	end process;


	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity failure;
	
	e_pinmap:entity work.fb_cpu_arm2_exp_pins
	port map(

		-- cpu wrapper signals
		wrap_exp_o => wrap_exp_o,
		wrap_exp_i => wrap_exp_i,

		-- local 6x09 wrapper signals to/from CPU expansion port 

		CPUSKT_ABRT_b2c		=> i_CPUSKT_ABRT_b2c,
		CPUSKT_phi1_b2c		=> i_CPUSKT_phi1_b2c,
		CPUSKT_phi2_b2c		=> i_CPUSKT_phi2_b2c,
		CPUSKT_nIRQ_b2c		=> i_CPUSKT_nIRQ_b2c,
		CPUSKT_nFIRQ_b2c		=> i_CPUSKT_nFIRQ_b2c,
		CPUSKT_RES_b2c			=> i_CPUSKT_RES_b2c,

		-- multiplexed 8 to 32 databus
		CPUSKT_D_mux_b2c		=> i_CPUSKT_D_mux_b2c,
		CPUBRD_nBL_b2c			=> i_CPUBRD_nBL_b2c,
		BUF_D_RnW_b2c			=> i_BUF_D_RnW_b2c,

		CPUSKT_nM_c2b			=> i_CPUSKT_nM_c2b,
		CPUSKT_nRW_c2b			=> i_CPUSKT_nRW_c2b,
		CPUSKT_nBW_c2b			=> i_CPUSKT_nBW_c2b,
		CPUSKT_nOPC_c2b		=> i_CPUSKT_nOPC_c2b,
		CPUSKT_nMREQ_c2b		=> i_CPUSKT_nMREQ_c2b,
		CPUSKT_nTRAN_c2b		=> i_CPUSKT_nTRAN_c2b,
		CPUSKT_SEQ_c2b			=> i_CPUSKT_SEQ_c2b,

		CPUSKT_D_mux_c2b		=> i_CPUSKT_D_mux_c2b,
		CPUSKT_A_c2b			=> i_CPUSKT_A_c2b

	);


	i_BUF_D_RnW_b2c <= 	not r_nRW;

	i_CPUSKT_ABRT_b2c 	<= '0';
	i_CPUSKT_phi1_b2c 	<= r_cpu_phi1;
	i_CPUSKT_phi2_b2c 	<= r_cpu_phi2;
	i_CPUSKT_RES_b2c		<= fb_syscon_i.rst when cpu_en_i = '1' else '1';		-- TODO:does this need synchronising?
	i_CPUSKT_nFIRQ_b2c	<= wrap_i.nmi_n;
	i_CPUSKT_nIRQ_b2c 	<= wrap_i.irq_n;
	i_CPUBRD_nBL_b2c 		<= not i_readed_lane or r_readed_lane_prev2 when r_WE = '0' else
									not i_write_lane;
	i_CPUSKT_D_mux_b2c <= 	wrap_i.D_rd(7 downto 0)   when i_readed_lane(0) = '1' else
									wrap_i.D_rd(15 downto 8)  when i_readed_lane(1) = '1' else
									wrap_i.D_rd(23 downto 16) when i_readed_lane(2) = '1' else
									wrap_i.D_rd(31 downto 24);


	wrap_o.BE 				<= '0';
	wrap_o.A	 				<= r_A_cpu(23 downto 2) & std_logic_vector(r_A_log);
	wrap_o.lane_req		<= r_lane_req;
	wrap_o.cyc 				<= r_cyc_o;
	wrap_o.we	  			<= r_WE;
	wrap_o.D_wr				<=	i_CPUSKT_D_mux_c2b & i_CPUSKT_D_mux_c2b & i_CPUSKT_D_mux_c2b & i_CPUSKT_D_mux_c2b;	
	G_B:FOR I in 0 to 3 GENERATE
	wrap_o.D_wr_stb(I)	<= r_writed_lane_prev3(I) and r_D_wr_stb;
	END GENERATE;
	wrap_o.rdy_ctdn		<= RDY_CTDN_MIN;
	wrap_o.instr_fetch 	<= r_instr_fetch;

	i_cyc_ack_i 			<= wrap_i.ack;


	p_reg_writed:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			r_writed_lane_prev <= wrap_i.act_lane;
			r_writed_lane_prev2 <= r_writed_lane_prev;
			r_writed_lane_prev3 <= r_writed_lane_prev2;
		end if;
	end process;

	i_write_lane <= wrap_i.act_lane;

	p_reg_readed:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			r_readed_lane_prev <= i_readed_lane;
			r_readed_lane_prev2 <= r_readed_lane_prev;
		end if;
	end process;

	p_mem_acc_state:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst ='1' then
			r_cyc_o <= '0';
			r_lane_req <= (others => '1');
			r_mem_acc_state <= done;
			r_D_wr_stb <= '0';
			r_WE <= '0';
			r_A_log <= (others => '0');		
		elsif rising_edge(fb_syscon_i.clk) then
			case r_mem_acc_state is 
				when idle =>
					r_cyc_o <= '0';
					r_D_wr_stb <= '0';
					if r_cpu_phi1 = '1' and r_nMREQ = '0' then
						if r_nBW = '1' then
							r_lane_req <= "1111";
							r_A_log <= "00";
						else
							r_lane_req <= (others => '0');
							r_lane_req(to_integer(unsigned(r_a_cpu(1 downto 0)))) <= '1';
							r_A_log <= unsigned(r_a_cpu(1 downto 0));
						end if;
						if r_nRW = '0' then
							r_mem_acc_state <= rd;
							r_WE <= '0';
						else
							r_mem_acc_state <= wr;
							r_WE <= '1';
						end if;
						r_cyc_o <= '1';
					end if;
				when wr =>
					if r_cpu_phi2 = '1' then
						r_D_wr_stb <= '1';
					end if;
					if i_cyc_ack_i then
						r_D_wr_stb <= '0';
						r_mem_acc_state <= done;
					end if;
				when rd =>
					if i_cyc_ack_i then
						r_mem_acc_state <= done;
					end if;				
				when done =>
					if r_mem_acc_reset = '1' then
						r_mem_acc_state <= idle;
						r_cyc_o <= '0';
					end if;
				when others =>
					r_cyc_o <= '0';
					r_D_wr_stb <= '0';
					r_mem_acc_state <= idle;
			end case;
		end if;
	end process;

	p_clk_state:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then

			r_mem_acc_reset <= '0';

			if r_clkctdn /= 0 then
				r_clkctdn <= r_clkctdn - 1;
			end if;

			case r_clk_state is
				when phi1 =>
					if r_clkctdn = 0 then
						r_cpu_phi1 <= '0';
						r_clkctdn <= to_unsigned(C_CLKD2_8-1, r_clkctdn'length);
						r_clk_state <= phi2;
					else
						r_cpu_phi1 <= '1';

						r_instr_fetch <= not r_nOPC;
						if r_arm_boot = '1' and r_nRW = '0' then
							if cfg_mosram_i = '1' then
								r_a_cpu <= x"7D3F" & i_CPUSKT_A_c2b(7 downto 0); 	-- boot from SWRAM at 7D xxxx
							else
								r_a_cpu <= x"8D3F" & i_CPUSKT_A_c2b(7 downto 0); 	-- boot from Flash at 8D xxxx
							end if;
						else
							r_a_cpu <= i_CPUSKT_A_c2b(23 downto 0);
						end if;
					end if;

				when phi2 =>
					if r_clkctdn = 0 and (r_mem_acc_state = done or r_nMREQ /= '0') then
						r_cpu_phi2 <= '0';
						r_clkctdn <= to_unsigned(C_CLKD2_8-1, r_clkctdn'length);
						r_clk_state <= phi1;
						r_mem_acc_reset <= '1';
						r_nMREQ <= i_CPUSKT_nMREQ_c2b or fb_syscon_i.rst;
						r_nOPC <= i_CPUSKT_nOPC_c2b;
						r_nBW <= i_CPUSKT_nBW_c2b;
						r_nRW <= i_CPUSKT_nRW_c2b;
					else
						r_cpu_phi2 <= '1';
					end if;
				when others =>
					r_clk_state <= phi1;
			end case;
		end if;

	end process;

	p_arm_boot:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_arm_boot <= '1';
		elsif rising_edge(fb_syscon_i.clk) then
			if JIM_en_i = '1' then
				r_arm_boot <= '0';
			end if;
		end if;
	end process;

  	wrap_o.noice_debug_cpu_clken 	<= '0';
  	wrap_o.noice_debug_5c	 	 	<=	'0';
  	wrap_o.noice_debug_opfetch 	<= '0';
	wrap_o.noice_debug_A0_tgl  	<= '0';



end rtl;

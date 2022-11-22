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

--TODO: uses ack, could maybe use rdy_ctdb?


----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	25/8/2019 
-- Design Name: 
-- Module Name:    	aeris - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		copper like co pro chip 
--
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
-- 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_MISC.ALL;

library work;
use work.fishbone.ALL;
use work.blit_types.ALL;
use work.common.ALL;

entity fb_dmac_aeris is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up	
		CLOCKSPEED							: natural
	);
   Port (
		-- fishbone signals		
		fb_syscon_i							: in		fb_syscon_t;

		-- peripheral interface (control registers)
		fb_per_c2p_i						: in		fb_con_o_per_i_t;
		fb_per_p2c_o						: out		fb_con_i_per_o_t;

		-- controller interface (dma)
		fb_con_c2p_o						: out		fb_con_o_per_i_t;
		fb_con_p2c_i						: in		fb_con_i_per_o_t;

		cpu_halt_o							: out		std_logic;

		hsync_i								: in		std_logic;
		vsync_i								: in		std_logic;

		dbg_state_o							: out		std_logic_vector(3 downto 0)

	);
	constant A_CONTROL			: integer := 0;
	constant	A_PROGSTART 		: integer := 1;
	constant	A_PC			 		: integer := 4;
end fb_dmac_aeris;

architecture Behavioral of fb_dmac_aeris is

	-- peripheral interface sigs
	type		per_strate_t		is (idle, wait_d_stb, rd);

	signal	r_per_state				: per_strate_t;
	signal	r_per_addr				: std_logic_vector(2 downto 0);
	signal 	i_per_D_rd				: std_logic_vector(7 downto 0);
	signal 	r_per_ack				: std_logic;
	signal 	r_per_D_wr				: std_logic_vector(7 downto 0);
	signal	r_per_D_wr_stb			: std_logic;

	-- controller cycle sigs
	type		con_state_type is (idle, waitack);
	signal	r_con_state				: con_state_type;


	TYPE 		state_type 			IS (
		idle,				-- either an illegal op was executed or at reset
		op_fetch,		-- fetching op code
		decode,			-- decode step - TODO: get rid?
		arg_0_fetch,	-- fetch arg 0
		arg_1_fetch,	-- fetch arg 1
		arg_2_fetch,	-- fetch arg 2
		exec,				-- exec for "easy instructions"
		exec_move,		-- exec for move
		exec_move16_0,		-- exec for move
		exec_move16_1,		-- exec for move
		play_op_fetch,		-- play op code fetch
		play_next			-- play check counter and advance
	);

	type t_ctr_arr is array (0 to 7) of std_logic_vector(7 downto 0);
	type t_ptr_arr is array (0 to 7) of std_logic_vector(15 downto 0);

	signal	r_counters		: t_ctr_arr;
	signal	r_pointers		: t_ptr_arr;

	signal	r_ctl_wait_cyc		: std_logic;		-- when '1' start program on next VS
	signal	r_ctl_feedback	: std_logic_vector(3 downto 0);
	signal	r_prog_base		: std_logic_vector(23 downto 0);
	signal 	r_cpu_halt		: std_logic;

	signal	r_play_ptrreg	: std_logic_vector(2 downto 0);
	signal	r_play_ctr		: std_logic_vector(7 downto 0);
	signal	r_play_started	: std_logic;
	signal	r_play_16		: std_logic;

	signal	r_state			: state_type;

	signal	r_op				: std_logic_vector(7 downto 0);
	signal	r_arg_0			: std_logic_vector(7 downto 0);
	signal	r_arg_1			: std_logic_vector(7 downto 0);
	signal	r_arg_2			: std_logic_vector(7 downto 0);
	signal	r_op_skip		: std_logic;								-- set by SKIP instruction if next op to be skipped

	signal	r_pc				: std_logic_vector(15 downto 0);

	signal	r_raster_ctr	: unsigned(8 downto 0); -- lines since VS
	signal	r_line_ctr		: unsigned(8 downto 0); -- 8MHz cycles along line

	signal	r_vs_meta		: std_logic_vector(10 downto 0);
	signal	r_hs_meta		: std_logic_vector(2 downto 0);

	signal	tgl_vs_edge		: bit := '0';
	signal	tgl_hs_edge		: bit := '0';
	signal	ack_vs_edge		: bit := '0';
	signal	ack_hs_edge		: bit := '0';
	signal	tgl_vs_edge_pgm: bit := '0';
	signal	ack_vs_edge_pgm: bit := '0';
	signal	r_ack_hs_waith	: bit := '0';

	signal	r_con_cyc_ack	: std_logic;

	signal	i_ctr_match		: std_logic;		-- '1' when ctrs are >= wait/skip spec

	signal	i_raster_ctr_masked 	: unsigned(8 downto 0);
	signal	i_raster_ctr_cmp 		: unsigned(8 downto 0);
	signal	i_line_ctr_masked 	: unsigned(4 downto 0);
	signal	i_line_ctr_cmp 		: unsigned(4 downto 0);

	signal	i_move_A					: std_logic_vector(23 downto 0);
	signal	i_move_D					: std_logic_vector(7 downto 0);
	signal	i_move_A_l				: std_logic_vector(7 downto 0);

	signal	r_8M_ctdn				: unsigned(numbits(CLOCKSPEED/8)-1 downto 0);
	signal	r_8M_clken				: std_logic;

begin

	cpu_halt_o <= r_cpu_halt;


--==============================================================================
-- S C R E E N   P O S I T I O N   C O U N T E R S
--==============================================================================


	p_meta:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			r_vs_meta <= r_vs_meta(r_vs_meta'high-1 downto 0) & vsync_i;
			r_hs_meta <= r_hs_meta(r_hs_meta'high-1 downto 0) & hsync_i;

			if r_vs_meta(r_vs_meta'high) = '0' and 
				r_vs_meta(r_vs_meta'high-1) = '0' and 
				r_vs_meta(r_vs_meta'high-2) = '1' and
				r_vs_meta(r_vs_meta'high-3) = '1' then
				tgl_vs_edge <= not tgl_vs_edge;
			end if;

			if r_hs_meta(r_hs_meta'high) = '0' and r_hs_meta(r_hs_meta'high-1) = '1' then
				tgl_hs_edge <= not tgl_hs_edge;
			end if;

		end if;
	end process;

	p_8M_clock:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_8M_ctdn <= to_unsigned((CLOCKSPEED/8)-1, r_8M_ctdn'length);
			r_8M_clken <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			r_8M_clken <= '0';
			if r_8M_ctdn = to_unsigned(0, r_8M_ctdn'length) then
				r_8M_clken <= '1';
				r_8M_ctdn <= to_unsigned((CLOCKSPEED/8)-1, r_8M_ctdn'length);
			else
				r_8M_ctdn <= r_8M_ctdn - 1;
			end if;
		end if;
	end process;
	
	p_screen_counters:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_raster_ctr <= (others => '0');
			r_line_ctr <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then 
			if r_8M_clken = '1' then
				if tgl_hs_edge /= ack_hs_edge then
					-- we've got a line
					if tgl_vs_edge /= ack_vs_edge then
						r_raster_ctr <= (others => '0');
						ack_vs_edge <= tgl_vs_edge;
						tgl_vs_edge_pgm <= not tgl_vs_edge_pgm;
					else
						r_raster_ctr <= r_raster_ctr + 1;
					end if;
					r_line_ctr <= (others => '0');
					ack_hs_edge <= tgl_hs_edge;
				else
					r_line_ctr <= r_line_ctr + 1;
				end if;
			end if;
		end if;
	end process;

	i_raster_ctr_masked <= (r_raster_ctr and unsigned(std_logic_vector'(r_op(3 downto 0) & r_arg_0(7 downto 3))));
	i_raster_ctr_cmp <= unsigned(std_logic_vector'(r_arg_1(5 downto 0) & r_arg_2(7 downto 5)));
	i_line_ctr_masked <= r_line_ctr(8 downto 4) and unsigned(std_logic_vector'(r_arg_0(2 downto 0) & r_arg_1(7 downto 6)));
	i_line_ctr_cmp <= unsigned(std_logic_vector'(r_arg_2(4 downto 0)));

	i_ctr_match <= '1' when (i_raster_ctr_masked >= i_raster_ctr_cmp) and (i_line_ctr_masked >= i_line_ctr_cmp) else
						'0';


--==============================================================================
-- C O P R O   S T A T E   M A C H I N E
--==============================================================================

	p_cop_mach_next:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_pc <= (others => '0');
			r_op <= (others => '0');
			r_arg_0 <= (others => '0');
			r_arg_1 <= (others => '0');
			r_arg_2 <= (others => '0');
			r_op_skip <= '0';
			r_pointers <= (others => (others => '0'));
			r_counters <= (others => (others => '0'));
			r_play_ctr <= (others => '0');
			r_play_ptrreg <= (others => '0');
			r_play_started <= '0';
			r_play_16 <= '0';
			r_state <= idle;		
			r_cpu_halt<= '0';	
		elsif rising_edge(fb_syscon_i.clk) then 
			r_con_cyc_ack <= '0';

			if r_ctl_wait_cyc = '0' then
				r_pc <= (others => '0');
				ack_vs_edge_pgm <= tgl_vs_edge_pgm;
				r_state <= idle;
				r_op_skip <= '0';
				r_play_started <= '0';
				r_cpu_halt<= '0';	
			elsif 
					(	r_state = idle 
						or (r_state = op_fetch and fb_con_p2c_i.ack = '1') 
						or (r_state = exec and r_op(7 downto 4) = x"0") -- wait
						or (r_state = exec and r_op(7 downto 4) = x"F") -- waith
					)
					and r_ctl_wait_cyc = '1' and tgl_vs_edge_pgm /= ack_vs_edge_pgm then
				ack_vs_edge_pgm <= tgl_vs_edge_pgm;
				r_pc <= r_prog_base(15 downto 0);
				r_state <= op_fetch;
				r_op_skip <= '0';
				r_play_started <= '0';
				r_cpu_halt<= '0';	
				r_con_cyc_ack <= '1'; -- force a finish of any controller cycle
			else
				case r_state is
					when idle =>
						r_cpu_halt<= '0';	
						r_state <= idle;
					when op_fetch | play_op_fetch =>
						-- wait for opcode fetch to complete then go to decode
						if fb_con_p2c_i.ack = '1' then
							if r_state = play_op_fetch then
								if r_play_16 = '1' then
									r_state <= arg_0_fetch; -- always a move16!
								else
									r_state <= arg_1_fetch; -- always a move!
								end if;
								r_op(3 downto 0) <= fb_con_p2c_i.D_rd(3 downto 0);
							else
								r_state <= decode;
								r_op <= fb_con_p2c_i.D_rd;
							end if;
							r_pc <= std_logic_vector(unsigned(r_pc) + 1);
							r_con_cyc_ack <= '1';
							r_ack_hs_waith <= tgl_hs_edge;
						end if;
					when decode => 
						r_play_started <= '0';
						if r_op(7 downto 6) = "00" then
							-- WAIT, SKIP, MOVE16, get all args
							r_state <= arg_0_fetch;
						elsif r_op(7 downto 6) = "01" then
							-- MOVE, BRANCH, DBNZ, MOVEP
							r_state <= arg_1_fetch;
						elsif r_op(7 downto 6) = "10" then
							-- MOVEC, PLAY, ADDx MOVErr
							r_state <= arg_2_fetch;
						else
							-- SYNC, UNSYNC, RET
							r_state <= exec;
						end if;
					when arg_0_fetch =>
						if fb_con_p2c_i.ack = '1' then
							r_arg_0 <= fb_con_p2c_i.D_rd;
							r_state <= arg_1_fetch;
							r_pc <= std_logic_vector(unsigned(r_pc) + 1);
							r_con_cyc_ack <= '1';
						end if;
					when arg_1_fetch =>
						if fb_con_p2c_i.ack = '1' then
							r_arg_1 <= fb_con_p2c_i.D_rd;
							r_state <= arg_2_fetch;
							r_pc <= std_logic_vector(unsigned(r_pc) + 1);
							r_con_cyc_ack <= '1';
						end if;
					when arg_2_fetch =>
						if fb_con_p2c_i.ack = '1' then
							r_arg_2 <= fb_con_p2c_i.D_rd;
							r_state <= exec;
							r_pc <= std_logic_vector(unsigned(r_pc) + 1);
							r_con_cyc_ack <= '1';
						end if;
					when exec =>
						if r_op_skip = '1' then
							r_state <= op_fetch;
							r_op_skip <= '0';
						elsif r_op(7 downto 4) = x"0" then
							-- WAIT
							if i_ctr_match = '1' then
								r_state <= op_fetch;
							end if;
						elsif r_op(7 downto 4) = x"1" then
							-- SKIP
							if i_ctr_match = '1' then
								r_state <= op_fetch;
								r_op_skip <= '1';
							else
								r_state <= op_fetch;
							end if;
						elsif r_op(7 downto 4) = x"2" or r_op(7 downto 4) = x"3" then
							r_state <= exec_move16_0;
						elsif r_op(7 downto 4) = x"4" then
							r_state <= exec_move;
						elsif r_op(7 downto 4) = x"5" then
							-- BRA
							r_state <= op_fetch;
							r_pc <= std_logic_vector(
											unsigned(r_pc) 
											+ unsigned(std_logic_vector'(r_arg_1 & r_arg_2))
										);
							if (r_op(3) = '1') then --link
								r_pointers(to_integer(unsigned(r_op(2 downto 0)))) <= r_pc;
							end if;
						elsif r_op(7 downto 4) = x"7" then
							-- MOVEP
							r_state <= op_fetch;
							r_pointers(to_integer(unsigned(r_op(2 downto 0)))) 
								<= std_logic_vector(
										unsigned(r_pc) 
										+ unsigned(std_logic_vector'(r_arg_1 & r_arg_2))
									);
						elsif r_op(7 downto 4) = x"8" then
							-- MOVEC
							r_state <= op_fetch;
							r_counters(to_integer(unsigned(r_op(2 downto 0)))) <= r_arg_2;
						elsif r_op(7 downto 4) = x"9" then
							-- PLAY
							if r_play_started = '0' then
								r_play_ctr <= r_arg_2;
								r_play_ptrreg <= r_op(2 downto 0);
								r_play_started <= '1';
								r_play_16 <= r_op(3);
								r_state <= play_op_fetch;		
								--swap PC and pointer for duration of the play
								r_pointers(to_integer(unsigned(r_op(2 downto 0))))	<= r_pc;
								r_pc <= r_pointers(to_integer(unsigned(r_op(2 downto 0))));
							else
								if r_play_16 = '1' then
									r_state <= exec_move16_0;
								else
									r_state <= exec_move;
								end if;
							end if;
						elsif r_op(7 downto 4) = x"A" then -- ADDx
							if r_op(3) = '0' then
								r_counters(to_integer(unsigned(r_op(2 downto 0)))) 
									<= std_logic_vector(
											unsigned(r_counters(to_integer(unsigned(r_op(2 downto 0))))) 
											+ unsigned(r_arg_2)
										);
							else
								r_pointers(to_integer(unsigned(r_op(2 downto 0)))) 
									<= std_logic_vector(
											unsigned(r_pointers(to_integer(unsigned(r_op(2 downto 0))))) 
											+ unsigned(resize(signed(r_arg_2),16))
										);
							end if;
							r_state <= op_fetch;
						elsif r_op(7 downto 3) = "10110" then -- MOVECC/MOVEPP
							if r_op(0) = '0' then
								r_counters(to_integer(unsigned(r_arg_2(6 downto 4)))) 
									<= r_counters(to_integer(unsigned(r_arg_2(2 downto 0))));
							else
								r_pointers(to_integer(unsigned(r_arg_2(6 downto 4)))) 
									<= r_pointers(to_integer(unsigned(r_arg_2(2 downto 0))));
							end if;
							r_state <= op_fetch;
						elsif r_op(7 downto 3) = "11000" then -- SYNC/UNSYNC
							r_cpu_halt <= r_op(0);
							r_state <= op_fetch;
						elsif r_op(7 downto 4) = x"D" then -- RET
							r_pc <= r_pointers(to_integer(unsigned(r_op(2 downto 0))));
							r_state <= op_fetch;
						elsif r_op(7 downto 4) = x"E" then -- DSZ
							if unsigned(r_counters(to_integer(unsigned(r_op(2 downto 0))))) = 1 then
								r_op_skip <= '1';
							end if;
							r_counters(to_integer(unsigned(r_op(2 downto 0)))) 
								<= std_logic_vector(
										unsigned(r_counters(to_integer(unsigned(r_op(2 downto 0))))) 
										- 1
									);
							r_state <= op_fetch;
						elsif r_op(7 downto 0) = x"F0" then -- WAITH
							if r_ack_hs_waith /= tgl_hs_edge then
								r_state <= op_fetch;
							end if;
 						else
							-- unknown instruction trap
							r_state <= idle;
						end if;
					when exec_move =>
						-- MOVE
						if fb_con_p2c_i.ack = '1' then
							if r_play_started = '1' then
								r_state <= play_next;
							else
								r_state <= op_fetch;
							end if;
							r_con_cyc_ack <= '1';
						end if;
					when exec_move16_0 =>
						-- MOVE16
						if fb_con_p2c_i.ack = '1' then
							r_state <= exec_move16_1;
							r_con_cyc_ack <= '1';
							if r_op(4) = '0' then
								r_arg_1 <= std_logic_vector(unsigned(r_arg_1) + 1);
							end if;
						end if;
					when exec_move16_1 =>
						-- MOVE
						if fb_con_p2c_i.ack = '1' then
							if r_play_started = '1' then
								r_state <= play_next;
							else
								r_state <= op_fetch;
							end if;
							r_con_cyc_ack <= '1';
						end if;
					when play_next =>
						r_play_ctr <= std_logic_vector(unsigned(r_play_ctr) - 1);
						if unsigned(r_play_ctr) = 1 or tgl_vs_edge_pgm /= ack_vs_edge_pgm then
							--swap back pointers
							r_pointers(to_integer(unsigned(r_play_ptrreg)))	<= r_pc;
							r_pc <= r_pointers(to_integer(unsigned(r_play_ptrreg)));
							r_state <= op_fetch;
						else
							r_state <= play_op_fetch;
						end if;
					when others =>
						r_state <= idle;
				end case;
			end if;
		end if;		
	end process;

	i_move_A_l <= 	r_arg_0 when r_state = exec_move16_0 or r_state = exec_move16_1 else
						r_arg_1;

	i_move_A <= x"FFFC" & i_move_A_l when r_op(3 downto 0) = x"0" else
					x"FFFD" & i_move_A_l when r_op(3 downto 0) = x"1" else
					x"FFFE" & i_move_A_l when r_op(3 downto 0) = x"2" else
					x"FEF" & r_op(3 downto 0) & i_move_A_l;


	i_move_D <= r_arg_1 when r_state = exec_move16_0 else
					r_arg_2;

	p_con_state:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_con_state <= idle;
			fb_con_c2p_o <= (
				cyc => '0',
				we => '0',
				A => (others => '-'),
				A_stb => '0',
				D_wr => (others => '-'),
				D_wr_stb => '0',
				rdy_ctdn => RDY_CTDN_MIN
				);
		else
			if rising_edge(fb_syscon_i.clk) then
				case r_con_state is 
					when idle => 
						case r_state is 
							when op_fetch | play_op_fetch | arg_0_fetch | arg_1_fetch | arg_2_fetch =>
								fb_con_c2p_o <= (
									cyc => '1',
									we => '0',
									A => r_prog_base(23 downto 16) & r_pc,
									A_stb => '1',
									D_wr => (others => '-'),
									D_wr_stb => '0',
									rdy_ctdn => RDY_CTDN_MIN
									);
							when exec_move | exec_move16_0 | exec_move16_1 =>
								fb_con_c2p_o <= (
									cyc => '1',
									we => '1',
									A => i_move_A,
									A_stb => '1',
									D_wr => i_move_D,
									D_wr_stb => '1',
									rdy_ctdn => RDY_CTDN_MIN
									);				
							when others =>
								fb_con_c2p_o <= (
									cyc => '0',
									we => '-',
									A => (others => '-'),
									A_stb => '0',
									D_wr => (others => '-'),
									D_wr_stb => '0',
									rdy_ctdn => RDY_CTDN_MIN
									);
						end case;	
					when waitack =>
						if fb_con_p2c_i.stall = '0' then
							fb_con_c2p_o.a_stb <= '0';
							fb_con_c2p_o.d_wr_stb <= '0';
						end if;
					when others => 
						r_con_state <= idle;
						fb_con_c2p_o <= (
							cyc => '0',
							we => '0',
							A => (others => '-'),
							A_stb => '0',
							D_wr => (others => '-'),
							D_wr_stb => '0',
							rdy_ctdn => RDY_CTDN_MIN
							);
				end case;

				if r_con_cyc_ack = '1' then
					r_con_state <= idle;
					fb_con_c2p_o.cyc <= '0';
				end if;

			end if;
		end if;
	end process;


--==============================================================================
-- S L A V E 
--==============================================================================

	p_regs_wr:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_ctl_wait_cyc <= '0';
			r_prog_base <= (others => '0');
			r_ctl_feedback <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
			if r_per_D_wr_stb = '1' then 
				case to_integer(unsigned(r_per_addr)) is
					when A_CONTROL =>
						r_ctl_wait_cyc <= fb_per_c2p_i.D_wr(7);
						r_ctl_feedback <= fb_per_c2p_i.D_wr(3 downto 0);
					when A_PROGSTART =>
						r_prog_base(23 downto 16) <= fb_per_c2p_i.D_wr;
					when A_PROGSTART + 1 =>
						r_prog_base(15 downto 8) <= fb_per_c2p_i.D_wr;
					when A_PROGSTART + 2 =>
						r_prog_base(7 downto 0) <= fb_per_c2p_i.D_wr;
					when others =>
						null;
				end case;
			end if;
		end if;

	end process;

	p_regs_rd:process(r_per_addr, r_prog_base, r_pc, r_ctl_wait_cyc, r_ctl_feedback)	
	begin
		case to_integer(unsigned(r_per_addr)) is
			when A_CONTROL =>
				i_per_D_rd <= r_ctl_wait_cyc & "000" & r_ctl_feedback;
			when A_PROGSTART =>
				i_per_D_rd <= r_prog_base(23 downto 16);
			when A_PROGSTART + 1 =>
				i_per_D_rd <= r_prog_base(15 downto 8);
			when A_PROGSTART + 2 =>
				i_per_D_rd <= r_prog_base(7 downto 0);
			when A_PC =>
				i_per_D_rd <= r_prog_base(23 downto 16);
			when A_PC + 1 =>
				i_per_D_rd <= r_pc(15 downto 8);
			when A_PC + 2 =>
				i_per_D_rd <= r_pc(7 downto 0);
			when others =>
				i_per_D_rd <= (others => '-');
		end case;
	end process;

	p_per_state:process(fb_syscon_i, fb_per_c2p_i)
	variable v_write:boolean;
	begin
		if fb_syscon_i.rst = '1' then
			r_per_state <= idle;
			r_per_ack <= '0';
			r_per_addr <= (others => '0');
			r_per_D_wr <= (others => '0');
			r_per_D_wr_stb <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			r_per_ack <= '0';
			r_per_D_wr_stb <= '0';
			v_write := false;
			case r_per_state is
				when idle =>
					if fb_per_c2p_i.cyc = '1' and fb_per_c2p_i.a_stb = '1' then
						r_per_addr <= fb_per_c2p_i.A(2 downto 0);
						if fb_per_c2p_i.we = '0' then
							r_per_state <= rd;
						else
							v_write := true;
						end if;
					end if;
				when wait_d_stb =>
					v_write := true;
				when rd =>
					fb_per_p2c_o.D_rd <= i_per_D_rd;
					if fb_per_c2p_i.we = '0' or fb_per_c2p_i.D_wr_stb = '1' then
						r_per_state <= idle;
						r_per_ack <= '1';
					end if;
				when others => null;
			end case;

			if v_write then
				if fb_per_c2p_i.D_wr_stb = '1' then
					r_per_D_wr <= fb_per_c2p_i.D_wr;
					r_per_D_wr_stb <= '1';
					r_per_state <= idle;
					r_per_ack <= '1';
				else
					r_per_state <= wait_d_stb;
				end if;
			end if;

			if fb_per_c2p_i.cyc = '0' then
				r_per_state <= idle;
			end if;

		end if;
	end process;

	fb_per_p2c_o.rdy <= r_per_ack;
	fb_per_p2c_o.ack <= r_per_ack;
	fb_per_p2c_o.stall <= '0' when r_per_state = idle else '1';

	dbg_state_o <= "0000" when r_state = idle else
		"0001" when r_state = op_fetch else
		"0010" when r_state = decode else
		"0011" when r_state = arg_0_fetch else
		"0100" when r_state = arg_1_fetch else
		"0101" when r_state = arg_2_fetch else
		"0110" when r_state = exec else
		"0111" when r_state = exec_move else
		"1000" when r_state = exec_move16_0 else
		"1001" when r_state = exec_move16_1 else
		"1010" when r_state = play_op_fetch else
		"1011" when r_state = play_next else
		"1111";

end Behavioral;



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
-- Module Name:    	fishbone bus - SYS wrapper component
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the BBC micro mainboard
--							NOTE: THIS IS A SPECIAL VERSION FOR MODEL_B/C that diverts signals to/from motherboard
--							to "shadow" on board components (HDMI, etc)
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
use work.common.all;
use work.board_config_pack.all;
use work.fb_SYS_pack.all;

entity fb_sys is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;
		CYCLES_SETUP						: natural := 0;-- number of cycles we expect data to be ready before
																	-- phi2, note this is pretty tight on a Model B so 0 might
																	-- prove to be safest, 1 seems to work ok on test
		G_JIM_DEVNO							: std_logic_vector(7 downto 0);
		-- TODO: horrendous bodge - need to prep the databus with the high byte of address for "nul" reads of hw addresses where no hardware is present
		DEFAULT_SYS_ADDR					: std_logic_vector(15 downto 0) := x"FFEA" -- this reads as x"EE" which should satisfy the TUBE detect code in the MOS and DFS/ADFS startup code

	);
	port(

      cfg_sys_type_i                : in     sys_type;

		-- SYS main board signals from CPU riser socket

		SYS_A_o								: out		std_logic_vector(15 downto 0);
		SYS_D_io								: inout	std_logic_vector(7 downto 0);
		
		-- SYS signals are connected direct to the BBC cpu socket
		SYS_RDY_i							: in		std_logic; -- BBC Master only?
		SYS_SYNC_o							: out		std_logic;
		SYS_PHI0_i							: in		std_logic;
		SYS_PHI1_o							: out		std_logic;
		SYS_PHI2_o							: out		std_logic;
		SYS_RnW_o							: out		std_logic;

		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;

		sys_ROMPG_o							: out		std_logic_vector(7 downto 0);		-- a shadow copy of the mainboard rom
																										-- paging register, used to select
																										-- on board paged roms from flash/sram

		sys_dll_lock_o							: out		std_logic;

		debug_sys_rd_ack_o				: out		std_logic;

		dbg_lock_o								: out		std_logic;
		dbg_fast_o								: out		std_logic;
		dbg_slow_o								: out		std_logic;
		dbg_cycle_o								: out		std_logic;

		jim_en_o									: out		std_logic;
		jim_page_o								: out		std_logic_vector(15 downto 0);

		cpu_2MHz_phi2_clken_o				: out		std_logic;

		debug_write_cycle_repeat_o			: out		std_logic;

		debug_wrap_sys_cyc_o					: out		std_logic;
		debug_wrap_sys_st_o					: out		std_logic;

		debug_sys_D_dir						: out		std_logic;

		---- MODEL B/C EXTRAS ----

		mb_vsync_i								: in		std_logic;

		mb_irq_o									: out		std_logic

	);
end fb_sys;

architecture rtl of fb_sys is

	type 	 	state_sys_t is (
		-- waiting for a request
		idle, 
		-- read address latched, wait for data to be ready
		addrlatched_rd, 
		-- write address latched
		addrlatched_wr, 
		-- we have latched the data wait for the end of sys cycle, or 
		-- possibly repeat the cycle if the data arrive too late (check r_wr_setup_ctr)
		wait_sys_end_wr, 
		-- we need to repeat the write cycle, all the signals are already setup on the bus
		-- just wait for start of next cycle and redo wait_sys_end_wr
		wait_sys_repeat_wr,
		-- controller has dropped cycle wait for end of sys cycle
		wait_sys_end, 
		--jim_dev_wr, -- this needs to be in parallel with a normal write to pass thru to SYS
		jim_dev_rd,
		jim_page_lo_wr,
		jim_page_hi_wr,
		jim_page_lo_rd,
		jim_page_hi_rd
	);

	signal 	i_gen_phi1 			: std_logic;
	signal 	i_gen_phi2 			: std_logic;

	signal 	r_sys_A				: std_logic_vector(15 downto 0);

	signal	state					: state_sys_t;

	signal   r_ack					: std_logic;							-- goes to 1 for single cycle when read data ready or for writes when data strobed
	signal   r_rdy					: std_logic;							-- goes to 1 when r_ack will occur in < r_con_rdy_ctdn cycles

	-- local copy of ROMPG
	signal	r_sys_ROMPG			: std_logic_vector(7 downto 0);	

	signal	i_sys_slow_cyc		: std_logic;

	signal	i_SYScyc_end_clken: std_logic;							-- goes to 1 for single cycle when sys cycle ended
	signal	i_SYScyc_st_clken	: std_logic;							-- goes to 1 for single cycle near start of sys cycle, in time for the motherboard cycle stretch logic

	signal	r_con_cyc			: std_logic; 							-- goes to zero if cyc/a_stb dropped
	signal   r_con_rdy_ctdn		: t_rdy_ctdn;

	signal	r_sys_d				: std_logic_vector(7 downto 0);
	signal	r_sys_RnW			: std_logic;

	signal	i_sys_rdy_ctdn_rd	: unsigned(RDY_CTDN_LEN-1 downto 0); -- number of cycles until data ready

	--latch for D_Rd
	signal	r_D_rd				: std_logic_vector(7 downto 0);
	signal	i_D_rd				: std_logic_vector(7 downto 0);

	--jim registers
	signal	r_JIM_en				: std_logic;
	signal	r_JIM_page			: std_logic_vector(15 downto 0);

	
	--write setup checks
	constant C_WRITE_SETUP		: natural := 13;	 -- approx 100ns! If this is not enforced then mode 2
																 -- has corrupt writes, none of the other modes seem 
																 -- to be affected. I'm not sure if this is a NULA thing
																 -- or a general beeb thing. It was shown up on the 6800
																 -- cpu which has relatively slow writes before DBE was
																 -- shortened
	signal	r_wr_setup_ctr		: unsigned(NUMBITS(C_WRITE_SETUP)-1 downto 0);

	signal	r_had_d_stb			: std_logic;
	signal	r_d_wr				: std_logic_vector(7 downto 0);


	--- model B/C Vsync irq stuff ---

	signal	r_mb_ca1_clr_req  : std_logic;		-- signal from cpu to clear interrupt (either read port A or IFR set)
	signal   r_mb_ca1_clr_ack	: std_logic;		-- ack signal for above

	signal	r_ier_ca1			: std_logic;		-- interrupt enable for CA1
	signal   r_ifr_ca1			: std_logic;		-- interrupt status for CA1

	signal 	r_prev_ca1			: std_logic;


begin

	--TODOPIPE: separate peripheral and motherboard cycle state machines
	--TODOPIPE: don't wait for cycle release
	--TODOPIPE: repeat missed write - configure with generic?


	debug_write_cycle_repeat_o <= '1' when state = wait_sys_repeat_wr else '0';
	debug_wrap_sys_cyc_o 		<= fb_c2p_i.a_stb and fb_c2p_i.cyc;
	debug_wrap_sys_st_o 			<= i_SYScyc_st_clken;
	debug_sys_D_dir				<= '1' when r_sys_RnW = '0' and (i_gen_phi2 = '1' or SYS_PHI0_i = '1') else '0';

	-- used to synchronise throttled cpu
	cpu_2MHz_phi2_clken_o <= i_SYScyc_end_clken;

	jim_en_o <= r_JIM_en;
	jim_page_o <= r_JIM_page;

	SYS_D_io <= r_sys_d when r_sys_RnW = '0' and (i_gen_phi2 = '1' or SYS_PHI0_i = '1') else
					(others => 'Z');
	SYS_RnW_o <= r_sys_RnW;

	sys_ROMPG_o <= r_sys_ROMPG;

	SYS_phi1_o <= i_gen_phi1;
	SYS_PHI2_o <= i_gen_phi2;
	SYS_A_o <= r_sys_A;

	-- new: 21/7/21 - always read rom paging register from SYS (which will read as nothing!)
	i_D_rd <= SYS_D_io;

	fb_p2c_o.D_rd <= r_D_rd; -- this used to be a latch but got rid for timing simplification
	fb_p2c_o.stall <= '0' when state = idle and i_SYScyc_st_clken = '1' else '1'; --TODO_PIPE: check this is best way?
	fb_p2c_o.rdy <= r_rdy and fb_c2p_i.cyc;
	fb_p2c_o.ack <= r_ack and fb_c2p_i.cyc;

	p_state:process(fb_syscon_i)
	begin

		if fb_syscon_i.rst = '1' then
			state <= idle;

			r_con_cyc <= '0';
			r_ack <= '0';
			r_con_rdy_ctdn <= RDY_CTDN_MAX;
			r_rdy <= '0';

			r_sys_A <= DEFAULT_SYS_ADDR;
			r_sys_RnW <= '1';
			r_sys_d <= (others => '0');

			r_sys_ROMPG <= (others => '0');


			r_JIM_en <= '0';
			r_JIM_page <= (others => '0');

			r_had_d_stb <= '0';
			r_d_wr <= (others => '0');

			r_mb_ca1_clr_req <= '0';
			r_ier_ca1 <= '0';

		else
			if rising_edge(fb_syscon_i.clk) then

				r_ack <= '0';

				case state is
					when idle =>

						r_con_cyc <= '0';
						r_rdy <= '0';

						r_had_d_stb <= '0';

						if i_SYScyc_st_clken = '1' then
							-- default idle cycle, drop busses
							r_sys_A <= DEFAULT_SYS_ADDR;
							r_sys_RnW <= '1';



							if fb_c2p_i.cyc = '1' and fb_c2p_i.a_stb = '1' then

								r_sys_A <= fb_c2p_i.A(15 downto 0);
								r_con_cyc <= '1';
								r_con_rdy_ctdn <= fb_c2p_i.rdy_ctdn; 


								if fb_c2p_i.A(15 downto 0) = x"FCFF" and fb_c2p_i.we = '0' and r_JIM_en = '1' then
									state <= jim_dev_rd;
								elsif fb_c2p_i.A(15 downto 0) = x"FCFE" and fb_c2p_i.we = '1' and r_JIM_en = '1' then
									if fb_c2p_i.D_wr_stb = '1' then
										r_JIM_page(7 downto 0) <= fb_c2p_i.D_wr;
										r_ack <= '1';
										r_rdy <= '1';
										state <= idle;
									else
										state <= jim_page_lo_wr;
									end if;
								elsif fb_c2p_i.A(15 downto 0) = x"FCFD" and fb_c2p_i.we = '1' and r_JIM_en = '1' then
									if fb_c2p_i.D_wr_stb = '1' then
										r_JIM_page(15 downto 8) <= fb_c2p_i.D_wr;
										r_ack <= '1';
										r_rdy <= '1';
										state <= idle;
									else
										state <= jim_page_hi_wr;
									end if;
								elsif fb_c2p_i.A(15 downto 0) = x"FCFE" and fb_c2p_i.we = '0' and r_JIM_en = '1' then
									state <= jim_page_lo_rd;
								elsif fb_c2p_i.A(15 downto 0) = x"FCFD" and fb_c2p_i.we = '0' and r_JIM_en = '1' then
									state <= jim_page_hi_rd;
								else

									if fb_c2p_i.we = '1' then
										r_had_d_stb <= fb_c2p_i.D_wr_stb;
										r_d_wr <= fb_c2p_i.d_wr;
										r_sys_RnW <= '0';							
										state <= addrlatched_wr;
										r_wr_setup_ctr <= (others => '0');
									else
										r_sys_RnW <= '1';
										state <= addrlatched_rd;
									end if;
								end if;

							end if;
						end if;

					when addrlatched_rd =>

						if fb_c2p_i.cyc = '0' or r_con_cyc = '0' then
							if i_SYScyc_end_clken = '1' then
								state <= idle;
							else
								state <= wait_sys_end;
							end if;
						else

							if i_sys_rdy_ctdn_rd <= r_con_rdy_ctdn then
								r_rdy <= '1';
							end if;
							if i_sys_rdy_ctdn_rd = RDY_CTDN_MIN then
								state <= idle;		
								r_ack <= '1';	
								-- MODEL B/C intercept IER/IFR
								if r_sys_A(15 downto 0) = x"FE4D" then
									-- IFR
									r_D_rd(7) <= i_D_rd(7) or (r_ier_ca1 and r_ifr_ca1);
									r_D_rd(6 downto 2) <= i_D_rd(6 downto 2);
									r_D_rd(1) <= r_ier_ca1 and r_ifr_ca1;
									r_D_rd(0) <= i_D_rd(0);
								elsif r_sys_A(15 downto 0) = x"FE4E" then
									-- IER
									r_D_rd(7) <= i_D_rd(7);
									r_D_rd(6 downto 2) <= i_D_rd(6 downto 2);
									r_D_rd(1) <= r_ier_ca1;
									r_D_rd(0) <= i_D_rd(0);
								else
									if r_sys_A(15 downto 0) = x"FE40" then
										-- reads of PORTA clear CA1 interrupt
										r_mb_ca1_clr_req <= not r_mb_ca1_clr_ack;
									end if;
									r_D_rd <= i_D_rd;				
								end if;
							end if;
						end if;
					when addrlatched_wr =>
						-- TODO: This assumes that the data will be ready in this cycle							
						-- put something in to retry if not, probably will mess up
						-- anyway if writing to a hardware reg?

						if fb_c2p_i.cyc = '0' or r_con_cyc = '0' then
							if i_SYScyc_end_clken = '1' then
								state <= idle;
							else
								state <= wait_sys_end;
							end if;
						else
							if fb_c2p_i.D_wr_stb = '1' and r_had_d_stb = '0' then
								r_had_d_stb <= '1';
								r_d_wr <= fb_c2p_i.d_wr;
							end if;
							if r_had_d_stb = '1' then
	                     if r_sys_A(15 downto 0) = x"FE05" and cfg_sys_type_i = SYS_ELK then
	                        -- TODO: fix this properly, for now just munge the number to match
	                        -- the mappings from the BBC, this will not allow any external ROMs!
	                        r_sys_ROMPG <= r_D_wr xor "00001100";       -- write to both shadow register and SYS
								elsif r_sys_A(15 downto 0) = x"FE30" and cfg_sys_type_i /= SYS_ELK then
									r_sys_ROMPG <= r_D_wr;			-- write to both shadow register and SYS
								end if;
								if r_sys_A(15 downto 0) = x"FCFF" then
									if r_D_wr = G_JIM_DEVNO then
										r_JIM_en <= '1';
									else
										r_JIM_en <= '0';
									end if;
								end if;

								-- MODEL B/C - intercept IER
								if r_sys_A(15 downto 0) = x"FE4E" then
									if r_D_wr(7) = '1' then
										r_sys_D <= r_D_wr and "11111101"; 	-- mask out CA1
									else
										r_sys_D <= r_D_wr or "00000010"; 	-- force clear CA1
									end if;

									if r_D_wr(1) = '1' then
										r_ier_ca1 <= r_D_wr(7);
									end if;
								else
									-- MODEL B/C - intercept IFR reset
									if r_sys_A(15 downto 0) = x"FE4D" then
										if r_D_wr(1) = '1' then
											r_mb_ca1_clr_req <= not r_mb_ca1_clr_ack;
										end if;
									end if;
									r_sys_D <= r_D_wr;
								end if;
								r_ack <= '1';
								r_rdy <= '1';
								state <= wait_sys_end_wr;
							end if;
						end if;

					when wait_sys_end_wr =>
						if i_SYScyc_end_clken = '1' then
							if r_wr_setup_ctr < C_WRITE_SETUP then
								state <= wait_sys_repeat_wr;
							else
								state <= idle;
							end if;
						else
							if r_wr_setup_ctr < C_WRITE_SETUP then
								r_wr_setup_ctr <= r_wr_setup_ctr + 1;
							end if;
						end if;

					when wait_sys_repeat_wr => 
						if i_SYScyc_st_clken = '1' then
							state <= wait_sys_end_wr;
							r_wr_setup_ctr <= (others => '0');
						end if;

					when wait_sys_end =>
						-- controller has released wait for end of this cycle
						if i_SYScyc_end_clken = '1' then
							state <= idle;
						end if;

					when jim_dev_rd =>
						r_rdy <= '1';
						state <= idle;		
						r_ack <= '1';		
						r_D_rd <= G_JIM_DEVNO xor x"FF";				
					when jim_page_lo_rd =>
						r_rdy <= '1';
						state <= idle;		
						r_ack <= '1';		
						r_D_rd <= r_JIM_page(7 downto 0);				
					when jim_page_hi_rd =>
						r_rdy <= '1';
						state <= idle;		
						r_ack <= '1';		
						r_D_rd <= r_JIM_page(15 downto 8);				

					when jim_page_lo_wr =>
						if fb_c2p_i.cyc = '0' or r_con_cyc = '0' then
							if i_SYScyc_end_clken = '1' then
								state <= idle;
							else
								state <= wait_sys_end;
							end if;
						elsif fb_c2p_i.D_wr_stb = '1' then
							r_JIM_page(7 downto 0) <= fb_c2p_i.D_wr;
							r_ack <= '1';
							r_rdy <= '1';
							state <= idle;
						end if;
					when jim_page_hi_wr =>
						if fb_c2p_i.cyc = '0' or r_con_cyc = '0' then
							if i_SYScyc_end_clken = '1' then
								state <= idle;
							else
								state <= wait_sys_end;
							end if;
						elsif fb_c2p_i.D_wr_stb = '1' then
							r_JIM_page(15 downto 8) <= fb_c2p_i.D_wr;
							r_ack <= '1';
							r_rdy <= '1';
							state <= idle;
						end if;
					when others =>
						-- catch all
						state <= idle;
						
						r_sys_RnW <= '1';
						r_rdy <= '0';
						r_con_cyc <= '0';

				end case;

--				if cfg_sys_type_i = SYS_BBC and r_con_cyc = '1' and i_SYScyc_st_clken = '1' then
--					-- a cycle has overrun, release the bus
--					r_sys_RnW <= '1';
--					fb_p2c_o.rdy_ctdn <= RDY_CTDN_MIN;
--					r_ack <= '1';
--					state <= idle;
--					r_sys_A <= DEFAULT_SYS_ADDR;
--					r_sys_RnW <= '1';
--				end if;

				if fb_c2p_i.cyc = '0' then
					-- controller has dropped the cycle
					r_con_cyc <= '0';
					r_rdy <= '0';
					r_ack <= '0';

				end if;

			end if;
		end if;

	end process;

   --TODO: see if the dll can be made to run reliably from phi0
   --and shift as appropriate
   --TODO: split dll from ctdn etc generation

	e_dll:entity work.fb_SYS_clock_dll
	generic map (
		SIM => SIM,
		CLOCKSPEED => CLOCKSPEED,
		CYCLES_SETUP => CYCLES_SETUP
	)
	port map (
      cfg_sys_type_i          => cfg_sys_type_i,
		fb_syscon_i 				=> fb_syscon_i,
		sys_dll_lock_o				=> sys_dll_lock_o,
		sys_phi2_i					=> i_gen_phi2,
		sys_slow_cyc_i				=> i_sys_slow_cyc,
		sys_rdyctdn_o				=> open,
		sys_rdyctdn_rd_o			=> i_sys_rdy_ctdn_rd,
		sys_cyc_start_clken_o	=> i_SYScyc_st_clken,
		sys_cyc_end_clken_o		=> i_SYScyc_end_clken,

		dbg_lock_o 					=> dbg_lock_o,
		dbg_fast_o 					=> dbg_fast_o,
		dbg_slow_o 					=> dbg_slow_o,
		dbg_cycle_o 				=> dbg_cycle_o
	);

	e_phigen:entity work.fb_SYS_phigen
	generic map (
		SIM => SIM,
		CLOCKSPEED => CLOCKSPEED
	)
	port map (
		fb_syscon_i => fb_syscon_i,
		phi0_i => SYS_PHI0_i,
		phi1_o => i_gen_phi1,
		phi2_o => i_gen_phi2
	);

	e_slow_cyc_dec:entity work.bbc_slow_cyc
	port map (
		SYS_A_i => r_sys_A,
		SLOW_o => i_sys_slow_cyc
		);


	SYS_SYNC_o <= '1';

	debug_sys_rd_ack_o <= r_ack;

	--- Model B/C Vsync stuff ---

	p_ca1:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_prev_ca1 <= mb_vsync_i;
			r_mb_ca1_clr_ack <= '0';
			r_ifr_ca1 <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			
			--detect falling edge
			if mb_vsync_i = '0' and r_prev_ca1 = '1' then
				if r_ier_ca1 = '1' then
					r_ifr_ca1 <= '1';
				end if;
			end if;
			r_prev_ca1 <= mb_vsync_i;

			--detect cpu ca1 interrupt clear
			if r_mb_ca1_clr_ack /= r_mb_ca1_clr_req then
				r_mb_ca1_clr_ack <= r_mb_ca1_clr_req;
				r_ifr_ca1 <= '0';
			end if;

		end if;
	end process;

	mb_irq_o <= '0' when r_ifr_ca1 = '1' and r_ier_ca1 = '1' else
					'1';

end rtl;
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
use work.mk3blit_pack.all;

entity fb_sys is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;
		CYCLES_SETUP						: natural := 1;-- number of cycles we expect data to be ready before
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

		debug_jim_hi_wr_o						: out		std_logic;
		debug_write_cycle_repeat_o			: out		std_logic;

		debug_wrap_sys_cyc_o					: out		std_logic;
		debug_wrap_sys_st_o					: out		std_logic

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
		-- sys cycle ended wait for controller to drop
		wait_con_rel_rd,
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

	-- local copy of ROMPG
	signal	r_sys_ROMPG			: std_logic_vector(7 downto 0);	

	signal	i_sys_slow_cyc		: std_logic;

	signal	i_SYScyc_end_clken: std_logic;							-- goes to 1 for single cycle when sys cycle ended
	signal	i_SYScyc_st_clken	: std_logic;							-- goes to 1 for single cycle near start of sys cycle, in time for the motherboard cycle stretch logic

	signal	i_con_cyc			: std_logic;							-- cyc and a_stb = '1'
	signal	r_con_cyc			: std_logic; 							-- goes to zero if cyc/a_stb dropped

	signal	r_sys_d				: std_logic_vector(7 downto 0);
	signal	r_sys_RnW			: std_logic;

	signal	i_sys_rdy_ctdn		: unsigned(RDY_CTDN_LEN-1 downto 0); -- number of cycles until phi0
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

begin
	debug_write_cycle_repeat_o <= '1' when state = wait_sys_repeat_wr else '0';
	debug_wrap_sys_cyc_o <= fb_c2p_i.cyc;
	debug_wrap_sys_st_o <= i_SYScyc_st_clken;

	-- used to synchronise throttled cpu
	cpu_2MHz_phi2_clken_o <= i_SYScyc_end_clken;

	jim_en_o <= r_JIM_en;
	jim_page_o <= r_JIM_page;

	SYS_D_io <= r_sys_d when r_sys_RnW = '0' and (i_gen_phi2 = '1' or SYS_PHI0_i = '1') else
					(others => 'Z');
	SYS_RnW_o <= r_sys_RnW;

	i_con_cyc <= fb_c2p_i.cyc and fb_c2p_i.a_stb;

	sys_ROMPG_o <= r_sys_ROMPG;

	SYS_phi1_o <= i_gen_phi1;
	SYS_PHI2_o <= i_gen_phi2;
	SYS_A_o <= r_sys_A;

--	-- latch to try and squeeze a bit of time at end of sys cycle - RAM reads are tight
--	i_D_rd <= r_sys_ROMPG when r_sys_A(15 downto 0) = x"FE30" else
--				 SYS_D_io;
	-- new: 21/7/21 - always read rom paging register from SYS (which will read as nothing!)
	i_D_rd <= SYS_D_io;

	fb_p2c_o.D_rd <= i_D_rd when state = addrlatched_rd else
						  r_D_rd;

	p_state:process(fb_syscon_i)
	begin

		if fb_syscon_i.rst = '1' then
			state <= idle;

			r_con_cyc <= '0';
			r_ack <= '0';

			r_sys_A <= DEFAULT_SYS_ADDR;
			r_sys_RnW <= '1';
			r_sys_d <= (others => '0');

			r_sys_ROMPG <= (others => '0');

			fb_p2c_o.rdy_ctdn <= RDY_CTDN_MAX;

			r_JIM_en <= '0';
			r_JIM_page <= (others => '0');

			debug_jim_hi_wr_o <= '0';

		else
			if rising_edge(fb_syscon_i.clk) then

				r_ack <= '0';

				case state is
					when idle =>

						debug_jim_hi_wr_o <= '0';

						r_con_cyc <= '0';
						fb_p2c_o.rdy_ctdn <= RDY_CTDN_MAX;

						if i_SYScyc_st_clken = '1' then
							-- default idle cycle, drop busses
							r_sys_A <= DEFAULT_SYS_ADDR;
							r_sys_RnW <= '1';



							if i_con_cyc = '1' then

								r_sys_A <= fb_c2p_i.A(15 downto 0);
								r_con_cyc <= '1';


								if fb_c2p_i.A(15 downto 0) = x"FCFF" and fb_c2p_i.we = '0' and r_JIM_en = '1' then
									state <= jim_dev_rd;
								elsif fb_c2p_i.A(15 downto 0) = x"FCFE" and fb_c2p_i.we = '1' and r_JIM_en = '1' then
									state <= jim_page_lo_wr;
								elsif fb_c2p_i.A(15 downto 0) = x"FCFD" and fb_c2p_i.we = '1' and r_JIM_en = '1' then
									state <= jim_page_hi_wr;
									debug_jim_hi_wr_o <= '1';
								elsif fb_c2p_i.A(15 downto 0) = x"FCFE" and fb_c2p_i.we = '0' and r_JIM_en = '1' then
									state <= jim_page_lo_rd;
								elsif fb_c2p_i.A(15 downto 0) = x"FCFD" and fb_c2p_i.we = '0' and r_JIM_en = '1' then
									state <= jim_page_hi_rd;
									debug_jim_hi_wr_o <= '1';
								else

									if fb_c2p_i.we = '1' then
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

						if i_con_cyc = '0' or r_con_cyc = '0' then
							if i_SYScyc_end_clken = '1' then
								state <= idle;
							else
								state <= wait_sys_end;
							end if;
						else

							fb_p2c_o.rdy_ctdn <= i_sys_rdy_ctdn_rd;
							if i_sys_rdy_ctdn_rd = RDY_CTDN_MIN then
								state <= wait_con_rel_rd;		
								r_ack <= '1';		
								r_D_rd <= i_D_rd;				
							end if;
						end if;
					when wait_con_rel_rd =>
						-- read cycle was finished, return to idle

						if i_con_cyc = '0' or r_con_cyc = '0' then
							state <= idle;
						end if;					

					when addrlatched_wr =>
						-- TODO: This assumes that the data will be ready in this cycle							
						-- put something in to retry if not, probably will mess up
						-- anyway if writing to a hardware reg?

						if i_con_cyc = '0' or r_con_cyc = '0' then
							if i_SYScyc_end_clken = '1' then
								state <= idle;
							else
								state <= wait_sys_end;
							end if;
						elsif fb_c2p_i.D_wr_stb = '1' then
                     if r_sys_A(15 downto 0) = x"FE05" and cfg_sys_type_i = SYS_ELK then
                        -- TODO: fix this properly, for now just munge the number to match
                        -- the mappings from the BBC, this will not allow any external ROMs!
                        r_sys_ROMPG <= fb_c2p_i.D_wr xor "00001100";       -- write to both shadow register and SYS
							elsif r_sys_A(15 downto 0) = x"FE30" and cfg_sys_type_i /= SYS_ELK then
								r_sys_ROMPG <= fb_c2p_i.D_wr;			-- write to both shadow register and SYS
							end if;
							if r_sys_A(15 downto 0) = x"FCFF" then
								if fb_c2p_i.D_wr = G_JIM_DEVNO then
									r_JIM_en <= '1';
								else
									r_JIM_en <= '0';
								end if;
							end if;
							r_sys_D <= fb_c2p_i.D_wr;
							r_ack <= '1';
							fb_p2c_o.rdy_ctdn <= RDY_CTDN_MIN;
							state <= wait_sys_end_wr;
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
						fb_p2c_o.rdy_ctdn <= RDY_CTDN_MIN;
						state <= wait_con_rel_rd;		
						r_ack <= '1';		
						r_D_rd <= G_JIM_DEVNO xor x"FF";				
					when jim_page_lo_rd =>
						fb_p2c_o.rdy_ctdn <= RDY_CTDN_MIN;
						state <= wait_con_rel_rd;		
						r_ack <= '1';		
						r_D_rd <= r_JIM_page(7 downto 0);				
					when jim_page_hi_rd =>
						fb_p2c_o.rdy_ctdn <= RDY_CTDN_MIN;
						state <= wait_con_rel_rd;		
						r_ack <= '1';		
						r_D_rd <= r_JIM_page(15 downto 8);				

					when jim_page_lo_wr =>
						if i_con_cyc = '0' or r_con_cyc = '0' then
							if i_SYScyc_end_clken = '1' then
								state <= idle;
							else
								state <= wait_sys_end;
							end if;
						elsif fb_c2p_i.D_wr_stb = '1' then
							r_JIM_page(7 downto 0) <= fb_c2p_i.D_wr;
							r_ack <= '1';
							fb_p2c_o.rdy_ctdn <= RDY_CTDN_MIN;
							state <= wait_con_rel_rd;
						end if;
					when jim_page_hi_wr =>
						if i_con_cyc = '0' or r_con_cyc = '0' then
							if i_SYScyc_end_clken = '1' then
								state <= idle;
							else
								state <= wait_sys_end;
							end if;
						elsif fb_c2p_i.D_wr_stb = '1' then
							r_JIM_page(15 downto 8) <= fb_c2p_i.D_wr;
							r_ack <= '1';
							fb_p2c_o.rdy_ctdn <= RDY_CTDN_MIN;
							state <= wait_con_rel_rd;
						end if;
					when others =>
						-- catch all
						state <= idle;
						
						r_sys_RnW <= '1';
						fb_p2c_o.rdy_ctdn <= RDY_CTDN_MAX;
						r_con_cyc <= '0';

				end case;

				if cfg_sys_type_i = SYS_BBC and r_con_cyc = '1' and i_SYScyc_st_clken = '1' then
					-- a cycle has overrun, release the bus
					r_sys_RnW <= '1';
					fb_p2c_o.rdy_ctdn <= RDY_CTDN_MIN;
					r_ack <= '1';
					state <= idle;
					r_sys_A <= DEFAULT_SYS_ADDR;
					r_sys_RnW <= '1';
				end if;

				if i_con_cyc = '0' then
					-- controller has dropped the cycle
					r_con_cyc <= '0';
					fb_p2c_o.rdy_ctdn <= RDY_CTDN_MAX;
					r_ack <= '0';

				end if;

			end if;
		end if;

	end process;


	fb_p2c_o.ack <= r_ack;
	fb_p2c_o.nul <= '0';


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
		sys_rdyctdn_o				=> i_sys_rdy_ctdn,
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


end rtl;
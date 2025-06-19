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
-- Create Date:    	16/06/2025
-- Design Name: 
-- Module Name:    	fishbone bus - SYS wrapper component
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the C20k main board _and_ on board
--							peripherals in the FF FC00 - FF FEFF address region
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------
-- TODO: Master/Elk
--



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;

entity fb_SYS_c20k is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;
		G_JIM_DEVNO							: std_logic_vector(7 downto 0);
		-- TODO: horrendous bodge - need to prep the databus with the high byte of address for "nul" reads of hw addresses where no hardware is present
		DEFAULT_SYS_ADDR					: std_logic_vector(15 downto 0) := x"FFEF"   -- this reads as x"EE" which should satisfy the TUBE detect code in the MOS and DFS/ADFS startup code

	);
	port(

		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;

	   -- mux clock outputs
	   mux_mhz1E_clk_o         : out    std_logic;                        -- 1MHzE clock for main board
	   mux_mhz2E_clk_o         : out    std_logic;                        -- 2MHzE clock for main board - cycle stretched

	   -- mux control outputs
	   mux_nALE_o              : out    std_logic;
	   mux_D_nOE_o             : out    std_logic;
	   mux_I0_nOE_o            : out    std_logic;
	   mux_I1_nOE_o            : out    std_logic;
	   mux_O0_nOE_o            : out    std_logic;
	   mux_O1_nOE_o            : out    std_logic;

	   -- mux multiplexed signals bus
	   mux_bus_io              : inout  std_logic_vector(7 downto 0);


		-- memory registers managed in here
		sys_ROMPG_o							: out		std_logic_vector(7 downto 0);		-- a shadow copy of the mainboard rom
																										-- paging register, used to select
 																										-- on board paged roms from flash/sram

		jim_en_o									: out		std_logic;
		jim_page_o								: out		std_logic_vector(15 downto 0);

		-- cpu sync 
		cpu_2MHz_phi2_clken_o				: out		std_logic

	);
end fb_SYS_c20k;

architecture rtl of fb_SYS_c20k is

	type 	 	state_sys_t is (
		-- waiting for a request
		idle, 
		-- read address latched, wait for data to be ready
		addrlatched_rd, 
		-- write address latched
		addrlatched_wr, 
		-- we have latched the data wait for the end of sys cycle, or 
		-- possibly repeat the cycle if the data arrive too late 
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

	signal	r_state				: state_sys_t;
	signal   r_ack					: std_logic;							-- goes to 1 for single cycle when read data ready or for writes when data strobed
	signal   r_rdy					: std_logic;							-- goes to 1 when r_ack will occur in < r_con_rdy_ctdn cycles

	-- regs for D_Rd
	signal	r_D_rd				: std_logic_vector(7 downto 0);
	signal	i_D_rd				: std_logic_vector(7 downto 0);

	-- regs for D_wr
	signal	r_had_d_stb			: std_logic;
	signal	r_d_wr				: std_logic_vector(7 downto 0);

	-- sys local signals
	signal 	r_sys_A				: std_logic_vector(15 downto 0);
	signal	r_sys_d_wr			: std_logic_vector(7 downto 0);
	signal	r_sys_RnW			: std_logic;
	signal	i_sys_rdy_ctdn_rd	: unsigned(RDY_CTDN_LEN-1 downto 0); -- number of cycles until data ready

	-- local copy of ROMPG
	signal	r_sys_ROMPG			: std_logic_vector(7 downto 0);	

	signal	r_con_cyc			: std_logic; 							-- goes to zero if cyc/a_stb dropped
	signal   r_con_rdy_ctdn		: t_rdy_ctdn;


	--jim registers
	signal	r_JIM_en				: std_logic;
	signal	r_JIM_page			: std_logic_vector(15 downto 0);

	-- timing back from MUX/board
	signal   i_SYScyc_st_clken : std_logic;
	signal	i_SYScyc_end_clken: std_logic;

	
-- TODO: write setup checks in mux and pass back to here...
	--write setup checks
	constant C_WRITE_SETUP		: natural := 13;	 -- approx 100ns! If this is not enforced then mode 2
																 -- has corrupt writes, none of the other modes seem 
																 -- to be affected. I'm not sure if this is a NULA thing
																 -- or a general beeb thing. It was shown up on the 6800
																 -- cpu which has relatively slow writes before DBE was
																 -- shortened
	signal	r_wr_setup_ctr		: unsigned(NUMBITS(C_WRITE_SETUP)-1 downto 0);

begin

	--TODO: get 2mhzE clken
	-- used to synchronise throttled cpu
	cpu_2MHz_phi2_clken_o <= i_SYScyc_end_clken;

	jim_en_o <= r_JIM_en;
	jim_page_o <= r_JIM_page;

	fb_p2c_o.D_rd <= r_D_rd; -- this used to be a latch but got rid for timing simplification
	fb_p2c_o.stall <= '0' when r_state = idle and i_SYScyc_st_clken = '1' else '1'; --TODO_PIPE: check this is best way?
	fb_p2c_o.rdy <= r_rdy and fb_c2p_i.cyc;
	fb_p2c_o.ack <= r_ack and fb_c2p_i.cyc;

	p_state:process(fb_syscon_i)
	begin

		if fb_syscon_i.rst = '1' then
			r_state <= idle;

			r_con_cyc <= '0';
			r_ack <= '0';
			r_con_rdy_ctdn <= RDY_CTDN_MAX;
			r_rdy <= '0';

			r_sys_A <= DEFAULT_SYS_ADDR;
			r_sys_RnW <= '1';
			r_sys_d_wr <= (others => '0');

			r_sys_ROMPG <= (others => '0');


			r_JIM_en <= '0';
			r_JIM_page <= (others => '0');

			r_had_d_stb <= '0';
			r_d_wr <= (others => '0');

		else
			if rising_edge(fb_syscon_i.clk) then

				r_ack <= '0';

				case r_state is
					when idle =>

						r_con_cyc <= '0';
						r_rdy <= '0';

						r_had_d_stb <= '0';

						if i_SYScyc_st_clken = '1' then
							-- default idle cycle, drop buses
							r_sys_A <= DEFAULT_SYS_ADDR;
							r_sys_RnW <= '1';



							if fb_c2p_i.cyc = '1' and fb_c2p_i.a_stb = '1' then

								r_sys_A <= fb_c2p_i.A(15 downto 0);
								r_con_cyc <= '1';
								r_con_rdy_ctdn <= fb_c2p_i.rdy_ctdn; 


								if fb_c2p_i.A(15 downto 0) = x"FCFF" and fb_c2p_i.we = '0' and r_JIM_en = '1' then
									r_state <= jim_dev_rd;
								elsif fb_c2p_i.A(15 downto 0) = x"FCFE" and fb_c2p_i.we = '1' and r_JIM_en = '1' then
									if fb_c2p_i.D_wr_stb = '1' then
										r_JIM_page(7 downto 0) <= fb_c2p_i.D_wr;
										r_ack <= '1';
										r_rdy <= '1';
										r_state <= idle;
									else
										r_state <= jim_page_lo_wr;
									end if;
								elsif fb_c2p_i.A(15 downto 0) = x"FCFD" and fb_c2p_i.we = '1' and r_JIM_en = '1' then
									if fb_c2p_i.D_wr_stb = '1' then
										r_JIM_page(15 downto 8) <= fb_c2p_i.D_wr;
										r_ack <= '1';
										r_rdy <= '1';
										r_state <= idle;
									else
										r_state <= jim_page_hi_wr;
									end if;
								elsif fb_c2p_i.A(15 downto 0) = x"FCFE" and fb_c2p_i.we = '0' and r_JIM_en = '1' then
									r_state <= jim_page_lo_rd;
								elsif fb_c2p_i.A(15 downto 0) = x"FCFD" and fb_c2p_i.we = '0' and r_JIM_en = '1' then
									r_state <= jim_page_hi_rd;
								else

									if fb_c2p_i.we = '1' then
										r_had_d_stb <= fb_c2p_i.D_wr_stb;
										r_d_wr <= fb_c2p_i.d_wr;
										r_sys_RnW <= '0';							
										r_state <= addrlatched_wr;
										r_wr_setup_ctr <= (others => '0');
									else
										r_sys_RnW <= '1';
										r_state <= addrlatched_rd;
									end if;
								end if;

							end if;
						end if;

					when addrlatched_rd =>

						if fb_c2p_i.cyc = '0' or r_con_cyc = '0' then
							if i_SYScyc_end_clken = '1' then
								r_state <= idle;
							else
								r_state <= wait_sys_end;
							end if;
						else

							if i_sys_rdy_ctdn_rd <= r_con_rdy_ctdn then
								r_rdy <= '1';
							end if;
							if i_sys_rdy_ctdn_rd = RDY_CTDN_MIN then
								r_state <= idle;		
								r_ack <= '1';		
								r_D_rd <= i_D_rd;				
							end if;
						end if;
					when addrlatched_wr =>
						-- TODO: This assumes that the data will be ready in this cycle							
						-- put something in to retry if not, probably will mess up
						-- anyway if writing to a hardware reg?

						if fb_c2p_i.cyc = '0' or r_con_cyc = '0' then
							if i_SYScyc_end_clken = '1' then
								r_state <= idle;
							else
								r_state <= wait_sys_end;
							end if;
						else
							if fb_c2p_i.D_wr_stb = '1' and r_had_d_stb = '0' then
								r_had_d_stb <= '1';
								r_d_wr <= fb_c2p_i.d_wr;
							end if;
							if r_had_d_stb = '1' then
								if r_sys_A(15 downto 0) = x"FE30" then
									r_sys_ROMPG <= r_D_wr;			-- write to both shadow register and MUX for now TODO: maybe not for c20k?
								end if;
								if r_sys_A(15 downto 0) = x"FCFF" then
									if r_D_wr = G_JIM_DEVNO then
										r_JIM_en <= '1';
									else
										r_JIM_en <= '0';
									end if;
								end if;
								r_sys_D_wr <= r_D_wr;
								r_ack <= '1';
								r_rdy <= '1';
								r_state <= wait_sys_end_wr;
							end if;
						end if;

					when wait_sys_end_wr =>
						if i_SYScyc_end_clken = '1' then
							if r_wr_setup_ctr < C_WRITE_SETUP then
								r_state <= wait_sys_repeat_wr;
							else
								r_state <= idle;
							end if;
						else
							if r_wr_setup_ctr < C_WRITE_SETUP then
								r_wr_setup_ctr <= r_wr_setup_ctr + 1;
							end if;
						end if;

					when wait_sys_repeat_wr => 
						if i_SYScyc_st_clken = '1' then
							r_state <= wait_sys_end_wr;
							r_wr_setup_ctr <= (others => '0');
						end if;

					when wait_sys_end =>
						-- controller has released wait for end of this cycle
						if i_SYScyc_end_clken = '1' then
							r_state <= idle;
						end if;

					when jim_dev_rd =>
						r_rdy <= '1';
						r_state <= idle;		
						r_ack <= '1';		
						r_D_rd <= G_JIM_DEVNO xor x"FF";				
					when jim_page_lo_rd =>
						r_rdy <= '1';
						r_state <= idle;		
						r_ack <= '1';		
						r_D_rd <= r_JIM_page(7 downto 0);				
					when jim_page_hi_rd =>
						r_rdy <= '1';
						r_state <= idle;		
						r_ack <= '1';		
						r_D_rd <= r_JIM_page(15 downto 8);				

					when jim_page_lo_wr =>
						if fb_c2p_i.cyc = '0' or r_con_cyc = '0' then
							if i_SYScyc_end_clken = '1' then
								r_state <= idle;
							else
								r_state <= wait_sys_end;
							end if;
						elsif fb_c2p_i.D_wr_stb = '1' then
							r_JIM_page(7 downto 0) <= fb_c2p_i.D_wr;
							r_ack <= '1';
							r_rdy <= '1';
							r_state <= idle;
						end if;
					when jim_page_hi_wr =>
						if fb_c2p_i.cyc = '0' or r_con_cyc = '0' then
							if i_SYScyc_end_clken = '1' then
								r_state <= idle;
							else
								r_state <= wait_sys_end;
							end if;
						elsif fb_c2p_i.D_wr_stb = '1' then
							r_JIM_page(15 downto 8) <= fb_c2p_i.D_wr;
							r_ack <= '1';
							r_rdy <= '1';
							r_state <= idle;
						end if;
					when others =>
						-- catch all
						r_state <= idle;
						
						r_sys_RnW <= '1';
						r_rdy <= '0';
						r_con_cyc <= '0';

				end case;

--				if cfg_sys_type_i = SYS_BBC and r_con_cyc = '1' and i_SYScyc_st_clken = '1' then
--					-- a cycle has overrun, release the bus
--					r_sys_RnW <= '1';
--					fb_p2c_o.rdy_ctdn <= RDY_CTDN_MIN;
--					r_ack <= '1';
--					r_state <= idle;
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


	e_MUX:entity work.c20k_peripherals_mux_ctl
   generic map (
      G_FAST_CLOCKSPEED    => CLOCKSPEED * 1000000,
      G_BEEBFPGA           => false,
      DEFAULT_SYS_ADDR     => DEFAULT_SYS_ADDR
   )
   port map (

      -- clocks in   
      clk_fast_i              => fb_syscon_i.clk,

      -- clock ens out in fast clock domain
      mhz1E_clken_o           => open,
      mhz2E_clken_o           => open,

      -- state control in
      reset_i                 => fb_syscon_i.rst,

      -- address and cycle selection from core, registered 1 cycle after i_SYScyc_st_clken
      sys_cyc_en_i            => r_con_cyc,
      sys_A_i                 => r_sys_A,
      sys_RnW_i               => r_sys_RnW,
      sys_nRST_i              => not fb_syscon_i.rst,

      -- address and cycle selection back to core
      addr_ack_clken_o        => i_SYScyc_st_clken,

      sys_D_wr_i              => r_d_wr,

      -- data and inputs back from bus at end of cycle
      sys_D_rd_o              => i_D_rd,
      sys_D_rd_clken_o        => i_SYScyc_end_clken,

   	-- how many cycles until a read will be ready
	   rd_ready_ctdn_o         => i_sys_rdy_ctdn_rd,

      -- mux clock outputs
      mux_mhz1E_clk_o         => mux_mhz1E_clk_o,
      mux_mhz2E_clk_o         => mux_mhz2E_clk_o,

      -- mux control outputs
      mux_nALE_o              => mux_nALE_o,
      mux_D_nOE_o             => mux_D_nOE_o,
      mux_I0_nOE_o            => mux_I0_nOE_o,
      mux_I1_nOE_o            => mux_I1_nOE_o,
      mux_O0_nOE_o            => mux_O0_nOE_o,
      mux_O1_nOE_o            => mux_O1_nOE_o,

      -- mux multiplexed signals bus   
      mux_bus_io              => mux_bus_io,

      -- random other multiplexed pins out to FPGA (I0 phase)
      p_ser_cts_o             => open,
      p_ser_rx_o              => open,
      p_d_cas_o               => open,
      p_kb_nRST_o             => open,
      p_kb_CA2_o              => open,
      p_netint_o              => open,
      p_irq_o                 => open,
      p_nmi_o                 => open,

      -- random other multiplexed pins out to FPGA (I1 phase)
      p_j_i0_o                => open,
      p_j_i1_o                => open,
      p_j_spi_miso_o          => open,
      p_btn0_o                => open,
      p_btn1_o                => open,
      p_btn2_o                => open,
      p_btn3_o                => open,
      p_kb_pa7_o              => open,

      -- random other multiplexed pins in from FPGA (O0 phase)
      p_SER_TX_i              => '1',
      p_SER_RTS_i             => '1',

      -- random other multiplexed pins in from FPGA (O1 phase)
      p_j_ds_nCS2_i           => '1',
      p_j_ds_nCS1_i           => '1',
      p_j_spi_clk_i           => '1',
      p_VID_HS_i              => '1',
      p_VID_VS_i              => '1',
      p_VID_CS_i              => '1',
      p_j_spi_mosi_i          => '1',
      p_j_adc_nCS_i           => '1'


   );

end rtl;
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

-- Company:          Dossytronics
-- Engineer:         Dominic Beesley
-- 
-- Create Date:      16/06/2025
-- Design Name: 
-- Module Name:      fishbone bus - SYS wrapper component
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      A fishbone wrapper for the C20k main board _and_ on board
--                   peripherals in the FF FC00 - FF FEFF address region
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
use work.board_config_pack.all;
use work.fb_SYS_pack.all;

entity fb_SYS_c20k is
   generic (
      SIM                           : boolean := false;                    -- skip some stuff, i.e. slow sdram start up
      CLOCKSPEED                    : natural;
      G_JIM_DEVNO                   : std_logic_vector(7 downto 0);
      -- TODO: horrendous bodge - need to prep the databus with the high byte of address for "nul" reads of hw addresses where no hardware is present
      DEFAULT_SYS_ADDR              : std_logic_vector(15 downto 0) := x"FFEF"   -- this reads as x"EE" which should satisfy the TUBE detect code in the MOS and DFS/ADFS startup code

   );
   port(

      cfg_sys_type_i                : in     sys_type;
      -- fishbone signals

      fb_syscon_i                   : in     fb_syscon_t;
      fb_c2p_i                      : in     fb_con_o_per_i_t;
      fb_p2c_o                      : out    fb_con_i_per_o_t;

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
      sys_ROMPG_o                   : out    std_logic_vector(7 downto 0);    -- a shadow copy of the mainboard rom
                                                                              -- paging register, used to select
                                                                              -- on board paged roms from flash/sram

      jim_en_o                         : out    std_logic;
      jim_page_o                       : out    std_logic_vector(15 downto 0);

      -- cpu sync 
      cpu_2MHz_phi2_clken_o            : out    std_logic;

      -- combined signals
      sys_nIRQ_o                       : out    std_logic;
      sys_nNMI_o                       : out    std_logic;

      -- random other multiplexed pins out to FPGA (I0 phase)
      p_ser_cts_o                      : out    std_logic;
      p_ser_rx_o                       : out    std_logic;
      p_d_cas_o                        : out    std_logic;
      p_kb_nRST_o                      : out    std_logic;

      -- random other multiplexed pins out to FPGA (I1 phase)
      p_j_i0_o                         : out    std_logic;
      p_j_i1_o                         : out    std_logic;
      p_j_spi_miso_o                   : out    std_logic;
      p_btn0_o                         : out    std_logic;
      p_btn1_o                         : out    std_logic;
      p_btn2_o                         : out    std_logic;
      p_btn3_o                         : out    std_logic;

      -- random other multiplexed pins in from FPGA (O0 phase)
      p_SER_TX_i                       : in     std_logic;
      p_SER_RTS_i                      : in     std_logic;

      -- random other multiplexed pins in from FPGA (O1 phase)
      p_j_ds_nCS2_i                    : in     std_logic;
      p_j_ds_nCS1_i                    : in     std_logic;
      p_j_spi_clk_i                    : in     std_logic;
      p_VID_HS_i                       : in     std_logic;
      p_VID_VS_i                       : in     std_logic;
      p_j_spi_mosi_i                   : in     std_logic;
      p_j_adc_nCS_i                    : in     std_logic;

      -- other inputs to FPGA
      lpstb_i                          : in     std_logic;

      -- emulated / synthesized beeb signals
      beeb_ic32_o                      : out    std_logic_vector(7 downto 0);
      c20k_latch_o                     : out    std_logic_vector(7 downto 0) 

   );
end fb_SYS_c20k;

architecture rtl of fb_SYS_c20k is

   type     state_sys_t is (
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
      jim_page_hi_rd,
      sys_via_rd,
      sys_via_wr
   );

   signal   r_state           : state_sys_t;
   signal   r_ack             : std_logic;                     -- goes to 1 for single cycle when read data ready or for writes when data strobed
   signal   r_rdy             : std_logic;                     -- goes to 1 when r_ack will occur in < r_con_rdy_ctdn cycles

   -- regs for D_Rd
   signal   r_D_rd            : std_logic_vector(7 downto 0);
   signal   i_D_rd            : std_logic_vector(7 downto 0);

   -- regs for D_wr
   signal   r_had_d_stb       : std_logic;
   signal   r_d_wr            : std_logic_vector(7 downto 0);

   -- sys local signals
   signal   r_sys_A           : std_logic_vector(15 downto 0);
   signal   r_sys_d_wr        : std_logic_vector(7 downto 0);
   signal   r_sys_RnW         : std_logic;
   signal   i_sys_rdy_ctdn_rd : unsigned(RDY_CTDN_LEN-1 downto 0); -- number of cycles until data ready

   -- local copy of ROMPG
   signal   r_sys_ROMPG       : std_logic_vector(7 downto 0);  

   signal   r_con_cyc         : std_logic;                     -- goes to zero if cyc/a_stb dropped
   signal   r_con_rdy_ctdn    : t_rdy_ctdn;


   --jim registers
   signal   r_JIM_en          : std_logic;
   signal   r_JIM_page        : std_logic_vector(15 downto 0);

   -- timing back from MUX/board
   signal   i_SYScyc_st_clken : std_logic;
   signal   i_SYScyc_end_clken: std_logic;

   
-- TODO: write setup checks in mux and pass back to here...
   --write setup checks
   constant C_WRITE_SETUP     : natural := 13;   -- approx 100ns! If this is not enforced then mode 2
                                                 -- has corrupt writes, none of the other modes seem 
                                                 -- to be affected. I'm not sure if this is a NULA thing
                                                 -- or a general beeb thing. It was shown up on the 6800
                                                 -- cpu which has relatively slow writes before DBE was
                                                 -- shortened
   signal   r_wr_setup_ctr    : unsigned(NUMBITS(C_WRITE_SETUP)-1 downto 0);

   -- control
   signal   i_reset_full      : std_logic;      -- reset mux state machine before clocking out full reset
   signal   i_reset_hard      : std_logic;      -- "power up" reset for sys via --TODO: distinguish between reset button and break key?
   signal   r_reset_bus       : std_logic := '0';      -- single cycle reset
   signal   r_reset_bus_pre   : std_logic := '0';      -- single cycle reset baulk

   -- peripheral local signals

   signal   i_p_netint        : std_logic;
   signal   i_p_irq           : std_logic;
   signal   i_p_nmi           : std_logic;
   signal   i_p_kb_pa7        : std_logic;
   signal   i_beeb_ic32       : std_logic_vector(7 downto 0);

   -- emulated peripherals signals
   signal   i_MHz1E_clken     : std_logic;
   signal   i_MHz2E_clken     : std_logic;
   signal   i_MHz4_clken      : std_logic;

   signal   i_sysvia_d_o      : std_logic_vector(7 downto 0);
   signal   r_sysvia_d_o      : std_logic_vector(7 downto 0);
   signal   r_sysvia_nCS2     : std_logic;
   signal   i_sysvia_nIRQ     : std_logic;
   signal   i_sysvia_ca2      : std_logic;
   signal   i_sysvia_PA_i     : std_logic_vector(7 downto 0);
   signal   i_sysvia_PA_o     : std_logic_vector(7 downto 0);
   signal   i_sysvia_PA_nOE   : std_logic_vector(7 downto 0);
   signal   i_sysvia_CB1_i    : std_logic;
   signal   i_sysvia_PB_i     : std_logic_vector(7 downto 0);

   signal   ip_VID_CS         : std_logic;



begin

   ip_VID_CS <= not (p_VID_HS_i xor p_VID_VS_i);

   sys_nIRQ_o <= i_p_irq and i_sysvia_nIRQ;
   sys_nNMI_o <= i_p_nmi;

   --TODO: get 2mhzE clken
   -- used to synchronise throttled cpu
   cpu_2MHz_phi2_clken_o <= i_MHz2E_clken;

   jim_en_o <= r_JIM_en;
   jim_page_o <= r_JIM_page;

   fb_p2c_o.D_rd <=  r_sysvia_d_o when r_sysvia_nCS2 = '0' else
                     r_D_rd; -- this used to be a latch but got rid for timing simplification
   fb_p2c_o.stall <= '0' when r_state = idle and i_SYScyc_st_clken = '1' else '1'; --TODO_PIPE: check this is best way?
	sys_ROMPG_o <= r_sys_ROMPG;
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
                  r_sysvia_nCS2 <= '1';

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

                           if fb_c2p_i.A(15 downto 4) = x"FE4" then
                              r_sysvia_nCS2 <= '0';
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
                     if i_SYScyc_end_clken = '1' then
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

--          if cfg_sys_type_i = SYS_BBC and r_con_cyc = '1' and i_SYScyc_st_clken = '1' then
--             -- a cycle has overrun, release the bus
--             r_sys_RnW <= '1';
--             fb_p2c_o.rdy_ctdn <= RDY_CTDN_MIN;
--             r_ack <= '1';
--             r_state <= idle;
--             r_sys_A <= DEFAULT_SYS_ADDR;
--             r_sys_RnW <= '1';
--          end if;

            if fb_c2p_i.cyc = '0' then
               -- controller has dropped the cycle
               r_con_cyc <= '0';
               r_rdy <= '0';
               r_ack <= '0';

            end if;

         end if;
      end if;

   end process;


   i_reset_full <= '1' when fb_syscon_i.rst = '1' and (fb_syscon_i.rst_state = resetfull or fb_syscon_i.rst_state = powerup) else
                   '0';
   i_reset_hard <= '1' when fb_syscon_i.rst = '1' and fb_syscon_i.rst_state = powerup else
                   '0';


   p_reset_bus:process(fb_syscon_i)
   begin
      if rising_edge(fb_syscon_i.clk) then
         r_reset_bus <= '0';         
         if i_reset_full = '1' and r_reset_bus_pre = '0' then
            r_reset_bus <= '1';
         end if;
         r_reset_bus_pre <= i_reset_full;
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
      mhz1E_clken_o           => i_MHz1E_clken,
      mhz2E_clken_o           => i_MHz2E_clken,
      mhz4_clken_o            => i_MHz4_clken,

      -- state control in
      reset_i                 => r_reset_bus,

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
      p_ser_cts_o             => p_ser_cts_o,
      p_ser_rx_o              => p_ser_rx_o,
      p_d_cas_o               => p_d_cas_o,
      p_kb_nRST_o             => p_kb_nRST_o,
      p_kb_CA2_o              => i_sysvia_ca2,
      p_netint_o              => i_p_netint,
      p_irq_o                 => i_p_irq,
      p_nmi_o                 => i_p_nmi,

      -- random other multiplexed pins out to FPGA (I1 phase)
      p_j_i0_o                => p_j_i0_o,
      p_j_i1_o                => p_j_i1_o,
      p_j_spi_miso_o          => p_j_spi_miso_o,
      p_btn0_o                => p_btn0_o,
      p_btn1_o                => p_btn1_o,
      p_btn2_o                => p_btn2_o,
      p_btn3_o                => p_btn3_o,
      p_kb_pa7_o              => i_p_kb_pa7,

      -- random other multiplexed pins in from FPGA (O0 phase)
      p_SER_TX_i              => p_SER_TX_i,
      p_SER_RTS_i             => p_SER_RTS_i,

      -- random other multiplexed pins in from FPGA (O1 phase)
      p_j_ds_nCS2_i           => p_j_ds_nCS2_i,
      p_j_ds_nCS1_i           => p_j_ds_nCS1_i,
      p_j_spi_clk_i           => p_j_spi_clk_i,
      p_VID_HS_i              => p_VID_HS_i,
      p_VID_VS_i              => p_VID_VS_i,
      p_VID_CS_i              => ip_VID_CS,
      p_j_spi_mosi_i          => p_j_spi_mosi_i,
      p_j_adc_nCS_i           => p_j_adc_nCS_i,

      -- emulated / synthesized back to core
      beeb_ic32_o             => i_beeb_ic32,
      c20k_latch_o            => c20k_latch_o

   );

   --==========================================================
   -- Emulated motherboard chips   
   --==========================================================

   -- slow latch
   beeb_ic32_o <= i_beeb_ic32;

   -- SYS VIA

   -- TODO: speech
   g_pa_back:for i in 0 to 6 generate
      i_sysvia_PA_i(i) <=  i_sysvia_PA_o(i) when i_sysvia_PA_nOE(i) = '0' else
                           '1';
   end generate;
   i_sysvia_PA_i(7) <= i_p_kb_pa7 when i_beeb_ic32(3) = '0' else
                       '1';

   i_sysvia_PB_i <= (others => '1');
   


   e_sys_via:entity work.M6522
   port map (
      I_RS                  => r_sys_A(3 downto 0),
      I_DATA                => r_d_wr,
      O_DATA                => i_sysvia_d_o,
      O_DATA_OE_L           => open,

      I_RW_L                => r_sys_RnW,
      I_CS1                 => mux_mhz2E_clk_o,
      I_CS2_L               => r_sysvia_nCS2,

      O_IRQ_L               => i_sysvia_nIRQ,

      -- port a
      I_CA1                 => p_VID_VS_i,
      I_CA2                 => i_sysvia_ca2,
      O_CA2                 => open,
      O_CA2_OE_L            => open,

      I_PA                  => i_sysvia_PA_i,
      O_PA                  => i_sysvia_PA_o,
      O_PA_OE_L             => i_sysvia_PA_nOE,

      -- port b
      I_CB1                 => i_sysvia_CB1_i,
      O_CB1                 => open,
      O_CB1_OE_L            => open,

      I_CB2                 => lpstb_i,
      O_CB2                 => open,
      O_CB2_OE_L            => open,

      I_PB                  => i_sysvia_PB_i,
      O_PB                  => open,
      O_PB_OE_L             => open,

      I_P2_H                => mux_mhz1E_clk_o,
      RESET_L               => not i_reset_hard,
      ENA_4                 => i_MHz4_clken,
      CLK                   => fb_syscon_i.clk
   );

   p_reg_sysvia_do:process(fb_syscon_i)
   begin 
      if rising_edge(fb_syscon_i.clk) then
         if r_sys_RnW = '1' and r_sysvia_nCS2 = '0' and mux_mhz1E_clk_o = '1' and i_MHz4_clken = '1' then
            r_sysvia_d_o <= i_sysvia_d_o;
         end if;
      end if;
   end process;

end rtl;
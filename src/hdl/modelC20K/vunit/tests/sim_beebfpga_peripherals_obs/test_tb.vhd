library vunit_lib;
context vunit_lib.vunit_context;



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use std.textio.all;

library fmf;

library work;

entity test_tb is
   generic (
      runner_cfg : string
      );
end test_tb;

architecture rtl of test_tb is

   signal i_clk_48         : std_logic;
   signal i_reset          : std_logic;

   signal ic_mhz1E_clken   : std_logic;
   signal ic_mhz2E_clken   : std_logic;

   signal i_SYS_RnW        : std_logic;
   signal i_SYS_A          : std_logic_vector(15 downto 0);
   signal i_sys_D_wr       : std_logic_vector(7 downto 0);

   signal ic_addr_ack_clken: std_logic;

   signal i_sys_D_rd       : std_logic_vector(7 downto 0);
   signal i_sys_D_rd_clken : std_logic;

   signal im_mux_mhz1E_clk : std_logic;
   signal im_mux_mhz2E_clk : std_logic;

   signal im_mux_nALE_o    : std_logic;
   signal im_mux_D_nOE_o   : std_logic;
   signal im_mux_I0_nOE_o  : std_logic;
   signal im_mux_I1_nOE_o  : std_logic;
   signal im_mux_O0_nOE_o  : std_logic;
   signal im_mux_O1_nOE_o  : std_logic;

   signal im_mux_bus_io    : std_logic_vector(7 downto 0);

begin

   p_clk_48:process
   begin
      i_clk_48 <= '0';
      wait for 0.5 us / 48;
      i_clk_48 <= '1';
      wait for 0.5 us / 48;
   end process;


   p_main:process
      variable I:natural;

      procedure CYC_R(
         A : in  std_logic_vector(15 downto 0)     
         ) is
      begin
         i_SYS_A <= A;
         i_SYS_RnW <= '1';
         wait until ic_addr_ack_clken = '1' and rising_edge(i_clk_48);

         wait until ic_mhz2E_clken = '1' and rising_edge(i_clk_48);
      end procedure;

      procedure CYC_W(
         A : in  std_logic_vector(15 downto 0);         
         D : in  std_logic_vector(7 downto 0)
         ) is
      begin
         i_SYS_A <= A;
         i_SYS_RnW <= '0';
         i_SYS_D_wr <= D;
         wait until ic_addr_ack_clken = '1' and rising_edge(i_clk_48);
         wait until ic_mhz2E_clken = '1' and rising_edge(i_clk_48);
      end procedure;

   begin

      test_runner_setup(runner, runner_cfg);


      while test_suite loop

         if run("test") then

            i_SYS_A <= (others => '0');

            i_reset <= '1';
            wait for 1 us;
            wait until rising_edge(i_clk_48);
            i_reset <= '0';

            wait until ic_mhz2E_clken = '1' and rising_edge(i_clk_48);
            wait until ic_mhz2E_clken = '1' and rising_edge(i_clk_48);
            wait until ic_mhz2E_clken = '1' and rising_edge(i_clk_48);
            wait until ic_mhz2E_clken = '1' and rising_edge(i_clk_48);
            
            CYC_R(x"FFEA");
            CYC_R(x"FFEA");
            CYC_W(x"FD23", x"5A");
            CYC_R(x"FFEA");
            CYC_R(x"FFEA");
            CYC_R(x"FFEA");
            CYC_R(x"FE41");             -- keyboard port A - should ignore
            CYC_W(x"FE41", x"A5");      -- keyboard port A
            CYC_R(x"FFEA");
            CYC_R(x"FFEA");
            CYC_W(x"FE80", x"A5");      -- FDCON
            CYC_W(x"FE80", x"5A");
            CYC_W(x"FE84", x"A5");      -- FDC
            CYC_W(x"FE84", x"5A");

            CYC_R(x"FFEA");

            wait for 10 us;

         end if;

      end loop;

      wait for 3 us;

      test_runner_cleanup(runner); -- Simulation ends here
   end process;



   e_dut:entity work.c20k_peripherals_mux_ctl
   generic map (
      G_FAST_CLOCKSPEED    => 96000000,
      G_BEEBFPGA           => true
   )
   port map (

      -- clocks in   
      clk_fast_i              => i_clk_48,

      -- clock ens out in fast clock domain
      mhz1E_clken_o           => ic_mhz1E_clken,
      mhz2E_clken_o           => ic_mhz2E_clken,

      -- state control in
      reset_i                 => i_reset,

      -- address and cycle selection from core
      sys_A_en                => '1',
      sys_A_i                 => i_SYS_A,
      sys_RnW_i               => i_SYS_RnW,

      -- address and cycle selection back to core
      addr_ack_clken_o        => ic_addr_ack_clken,

      -- data and inputs back from bus at end of cycle
      sys_D_rd                => i_sys_D_rd,
      sys_D_rd_clken          => i_sys_D_rd_clken,

      -- mux clock outputs
      mux_mhz1E_clk            => im_mux_mhz1E_clk,
      mux_mhz2E_clk            => im_mux_mhz2E_clk,

      -- mux control outputs
      mux_nALE_o              => im_mux_nALE_o,
      mux_D_nOE_o             => im_mux_D_nOE_o,
      mux_I0_nOE_o            => im_mux_I0_nOE_o,
      mux_I1_nOE_o            => im_mux_I1_nOE_o,
      mux_O0_nOE_o            => im_mux_O0_nOE_o,
      mux_O1_nOE_o            => im_mux_O1_nOE_o,

      -- mux multiplexed signals bus   
      mux_bus_io              => im_mux_bus_io
   );



--   e_brd_per:entity work.sim_peripherals_mux
--   port map (
--
--      clk_2MHz_E_i   => i_clk_2MHzE,
--      clk_1MHz_E_i   => i_clk_1MHzE,
--      
--      MIO_io         => i_MIO,
--      MIO_nALE_i     => i_MIO_nALE,
--      MIO_D_nOE_i    => i_MIO_D_nOE,
--      MIO_I0_nOE_i   => i_MIO_I0_nOE,
--      MIO_I1_nOE_i   => i_MIO_I1_nOE,
--      MIO_O0_nOE_i   => i_MIO_O0_nOE,
--      MIO_O1_nOE_i   => i_MIO_O1_nOE,
--
--      P_RnW_o        => im_P_RnW,
--      P_nRST_o       => im_P_nRST,
--      P_SER_TX_o     => im_P_SER_TX,
--      P_SER_RTS_o    => im_P_SER_RTS,
--
--      nADLC_o        => im_nADLC,
--      nKBPAWR_o      => im_nKBPAWR,
--      nIC32WR_o      => im_nIC32WR,
--      nPGFC_o        => im_nPGFC,
--      nPGFD_o        => im_nPGFD,
--      nFDC_o         => im_nFDC,
--      nTUBE_o        => im_nTUBE,
--      nFDCONWR_o     => im_nFDCONWR,
--      nVIAB_o        => im_nVIAB,
--
--      -- MIO_I0 phase
--
--      ser_cts_i      => imi_ser_cts,
--      ser_rx_i       => imi_ser_rx,
--      d_cas_i        => imi_d_cas,
--      kb_nRST_i      => imi_kb_nRST,
--      kb_CA2_i       => imi_kb_CA2,
--      netint_i       => imi_netint,
--      irq_i          => imi_irq,
--      nmi_i          => imi_nmi,
--
--      -- MIO_O1 phase
--      j_ds_nCS2_o    => im_j_ds_nCS2,
--      j_ds_nCS1_o    => im_j_ds_nCS1,
--      j_spi_clk_o    => im_j_spi_clk,
--      VID_HS_o       => im_VID_HS,
--      VID_VS_o       => im_VID_VS,
--      VID_CS_o       => im_VID_CS,
--      j_spi_mosi_o   => im_j_spi_mosi,
--      j_adc_nCS_o    => im_j_adc_nCS,
--
--      -- MIO_I1 phase
--      j_i0_i         => imi_j_i0_i,
--      j_i1_i         => imi_j_i1_i,
--      j_spi_miso_i   => imi_j_spi_miso_i,
--      btn0_i         => imi_btn0_i,
--      btn1_i         => imi_btn1_i,
--      btn2_i         => imi_btn2_i,
--      btn3_i         => imi_btn3_i,
--      kb_pa7_i       => imi_kb_pa7_i,
--
--      -- data phase
--      P_D_io         => im_P_D,
--
--      -- address phase
--      P_A_o          => im_P_A
--
--
--   );
--
--   -- mock devices
--
--   e_floppy:entity work.floppy
--   port map (
--      A_i         => im_P_A(1 downto 0),
--      D_io        => im_P_D,
--      RnW_i       => im_P_RnW,
--      nRST_i      => im_P_nRST,
--      nFDC_i      => im_nFDC,
--      nFDCON_i    => im_nFDCONWR,
--      NMI_o       => open,       -- UNTESTED
--      CLK8_i      => '1'         -- UNTESTED
--   );
--
--   e_slow_cyc:entity work.bbc_slow_cyc
--   port map (
--      sys_A_i        => i_SYS_A,
--      slow_o         => i_bbc_slow_cyc
--   );

end rtl;

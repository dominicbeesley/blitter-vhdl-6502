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
   signal i_sys_nRST       : std_logic;

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

   -- peripheral signals to / from FPGA to controller
   signal ipi_ser_cts      : std_logic;
   signal ipi_ser_rx       : std_logic;
   signal ipi_d_cas        : std_logic;
   signal ipi_kb_nRST      : std_logic;
   signal ipi_kb_CA2       : std_logic;
   signal ipi_netint       : std_logic;
   signal ipi_irq          : std_logic;
   signal ipi_nmi          : std_logic;
   signal ipi_j_i0         : std_logic;
   signal ipi_j_i1         : std_logic;
   signal ipi_j_spi_miso   : std_logic;
   signal ipi_btn0         : std_logic;
   signal ipi_btn1         : std_logic;
   signal ipi_btn2         : std_logic;
   signal ipi_btn3         : std_logic;
   signal ipi_kb_pa7       : std_logic;

   signal ipo_SER_TX       : std_logic;
   signal ipo_SER_RTS      : std_logic;
   signal ipo_j_ds_nCS2    : std_logic;
   signal ipo_j_ds_nCS1    : std_logic;
   signal ipo_j_spi_clk    : std_logic;
   signal ipo_VID_HS       : std_logic;
   signal ipo_VID_VS       : std_logic;
   signal ipo_VID_CS       : std_logic;
   signal ipo_j_spi_mosi   : std_logic;
   signal ipo_j_adc_nCS    : std_logic;

   -- peripheral signals on the simulated motherboard in/out of the multiplexer
   signal ibpo_RnW         : std_logic;
   signal ibpo_nRST        : std_logic;
   signal ibpo_SER_TX      : std_logic;
   signal ibpo_SER_RTS     : std_logic;
   signal ibpo_nADLC       : std_logic;
   signal ibpo_nKBPAWR     : std_logic;
   signal ibpo_nIC32WR     : std_logic;
   signal ibpo_nPGFC       : std_logic;
   signal ibpo_nPGFD       : std_logic;
   signal ibpo_nFDC        : std_logic;
   signal ibpo_nTUBE       : std_logic;
   signal ibpo_nFDCONWR    : std_logic;
   signal ibpo_nVIAB       : std_logic;
   signal ibpi_ser_cts     : std_logic;
   signal ibpi_ser_rx      : std_logic;
   signal ibpi_d_cas       : std_logic;
   signal ibpi_kb_nRST     : std_logic;
   signal ibpi_kb_CA2      : std_logic;
   signal ibpi_netint      : std_logic;
   signal ibpi_irq         : std_logic;
   signal ibpi_nmi         : std_logic;
   signal ibpo_j_ds_nCS2   : std_logic;
   signal ibpo_j_ds_nCS1   : std_logic;
   signal ibpo_j_spi_clk   : std_logic;
   signal ibpo_VID_HS      : std_logic;
   signal ibpo_VID_VS      : std_logic;
   signal ibpo_VID_CS      : std_logic;
   signal ibpo_j_spi_mosi  : std_logic;
   signal ibpo_j_adc_nCS   : std_logic;
   signal ibpi_j_i0        : std_logic;
   signal ibpi_j_i1        : std_logic;
   signal ibpi_j_spi_miso  : std_logic;
   signal ibpi_btn0        : std_logic;
   signal ibpi_btn1        : std_logic;
   signal ibpi_btn2        : std_logic;
   signal ibpi_btn3        : std_logic;
   signal ibpi_kb_pa7      : std_logic;
   signal ibpio_P_D        : std_logic_vector(7 downto 0);
   signal ibpo_A           : std_logic_vector(7 downto 0);

   signal i_u11_Q          : std_logic_vector(7 downto 0);

begin


   p_clk_48:process
   begin
      i_clk_48 <= '0';
      wait for 0.5 us / 96;
      i_clk_48 <= '1';
      wait for 0.5 us / 96;
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

            -- reset inputs to mux
            ibpi_ser_cts <= '0';
            ibpi_ser_rx <= '0';
            ibpi_d_cas <= '0';
            ibpi_kb_nRST <= '0';
            ibpi_kb_CA2 <= '0';
            ibpi_netint <= '0';
            ibpi_irq <= '0';
            ibpi_nmi <= '0';
            ibpi_j_i0 <= '0';
            ibpi_j_i1 <= '0';
            ibpi_j_spi_miso <= '0';
            ibpi_btn0 <= '0';
            ibpi_btn1 <= '0';
            ibpi_btn2 <= '0';
            ibpi_btn3 <= '0';
            ibpi_kb_pa7 <= '0';

            -- reset outputs from fpga
            ipo_SER_TX <= '0';
            ipo_SER_RTS <= '0';
            ipo_j_ds_nCS2 <= '0';
            ipo_j_ds_nCS1 <= '0';
            ipo_j_spi_clk <= '0';
            ipo_VID_HS <= '0';
            ipo_VID_VS <= '0';
            ipo_VID_CS <= '0';
            ipo_j_spi_mosi <= '0';
            ipo_j_adc_nCS <= '0';

            i_SYS_A <= (others => '0');
            i_SYS_RnW <= '1';
            i_SYS_D_wr <= (others => '0');
            
            i_sys_nRST <= '0';
            i_reset <= '1';
            wait for 1 us;
            wait until rising_edge(i_clk_48);
            i_reset <= '0';
            i_sys_nRST <= '1';

            wait until ic_mhz2E_clken = '1' and rising_edge(i_clk_48);
            wait until ic_mhz2E_clken = '1' and rising_edge(i_clk_48);
            wait until ic_mhz2E_clken = '1' and rising_edge(i_clk_48);
            wait until ic_mhz2E_clken = '1' and rising_edge(i_clk_48);
            
            CYC_R(x"FFEA");
            CYC_W(x"FE40", x"A5");
            CYC_W(x"FE40", x"5A");
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
            ibpi_btn0 <= '1';
            ibpi_btn2 <= '1';
            CYC_W(x"FE80", x"5A");
            ibpi_btn0 <= '0';
            ibpi_btn2 <= '0';
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
      sys_cyc_en_i            => '1',
      sys_A_i                 => i_SYS_A,
      sys_RnW_i               => i_SYS_RnW,
      sys_nRST_i              => i_sys_nRST,

      -- address and cycle selection back to core
      addr_ack_clken_o        => ic_addr_ack_clken,

      sys_D_wr_i              => i_sys_D_wr,

      -- data and inputs back from bus at end of cycle
      sys_D_rd_o              => i_sys_D_rd,
      sys_D_rd_clken_o        => i_sys_D_rd_clken,

      -- mux clock outputs
      mux_mhz1E_clk_o         => im_mux_mhz1E_clk,
      mux_mhz2E_clk_o         => im_mux_mhz2E_clk,

      -- mux control outputs
      mux_nALE_o              => im_mux_nALE_o,
      mux_D_nOE_o             => im_mux_D_nOE_o,
      mux_I0_nOE_o            => im_mux_I0_nOE_o,
      mux_I1_nOE_o            => im_mux_I1_nOE_o,
      mux_O0_nOE_o            => im_mux_O0_nOE_o,
      mux_O1_nOE_o            => im_mux_O1_nOE_o,

      -- mux multiplexed signals bus   
      mux_bus_io              => im_mux_bus_io,

      -- random other multiplexed pins out to FPGA (I0 phase)
      p_ser_cts_o             => ipi_ser_cts,
      p_ser_rx_o              => ipi_ser_rx,
      p_d_cas_o               => ipi_d_cas,
      p_kb_nRST_o             => ipi_kb_nRST,
      p_kb_CA2_o              => ipi_kb_CA2,
      p_netint_o              => ipi_netint,
      p_irq_o                 => ipi_irq,
      p_nmi_o                 => ipi_nmi,

      -- random other multiplexed pins out to FPGA (I1 phase)
      p_j_i0_o                => ipi_j_i0,
      p_j_i1_o                => ipi_j_i1,
      p_j_spi_miso_o          => ipi_j_spi_miso,
      p_btn0_o                => ipi_btn0,
      p_btn1_o                => ipi_btn1,
      p_btn2_o                => ipi_btn2,
      p_btn3_o                => ipi_btn3,
      p_kb_pa7_o              => ipi_kb_pa7,

      -- random other multiplexed pins in from FPGA (O0 phase)
      p_SER_TX_i              => ipo_SER_TX,
      p_SER_RTS_i             => ipo_SER_RTS,

      -- random other multiplexed pins in from FPGA (O1 phase)
      p_j_ds_nCS2_i           => ipo_j_ds_nCS2,
      p_j_ds_nCS1_i           => ipo_j_ds_nCS1,
      p_j_spi_clk_i           => ipo_j_spi_clk,
      p_VID_HS_i              => ipo_VID_HS,
      p_VID_VS_i              => ipo_VID_VS,
      p_VID_CS_i              => ipo_VID_CS,
      p_j_spi_mosi_i          => ipo_j_spi_mosi,
      p_j_adc_nCS_i           => ipo_j_adc_nCS


   );


--===========================================================
-- board sim
--===========================================================


   e_brd_per:entity work.sim_peripherals_mux
   port map (

      clk_2MHz_E_i   => im_mux_mhz1E_clk,
      clk_1MHz_E_i   => im_mux_mhz2E_clk,
      
      MIO_io         => im_mux_bus_io,
      MIO_nALE_i     => im_mux_nALE_o,
      MIO_D_nOE_i    => im_mux_D_nOE_o,
      MIO_I0_nOE_i   => im_mux_I0_nOE_o,
      MIO_I1_nOE_i   => im_mux_I1_nOE_o,
      MIO_O0_nOE_i   => im_mux_O0_nOE_o,
      MIO_O1_nOE_i   => im_mux_O1_nOE_o,

      P_RnW_o        => ibpo_RnW,
      P_nRST_o       => ibpo_nRST,
      P_SER_TX_o     => ibpo_SER_TX,
      P_SER_RTS_o    => ibpo_SER_RTS,

      nADLC_o        => ibpo_nADLC,
      nKBPAWR_o      => ibpo_nKBPAWR,
      nIC32WR_o      => ibpo_nIC32WR,
      nPGFC_o        => ibpo_nPGFC,
      nPGFD_o        => ibpo_nPGFD,
      nFDC_o         => ibpo_nFDC,
      nTUBE_o        => ibpo_nTUBE,
      nFDCONWR_o     => ibpo_nFDCONWR,
      nVIAB_o        => ibpo_nVIAB,

      -- MIO_I0 phase

      ser_cts_i      => ibpi_ser_cts,
      ser_rx_i       => ibpi_ser_rx,
      d_cas_i        => ibpi_d_cas,
      kb_nRST_i      => ibpi_kb_nRST,
      kb_CA2_i       => ibpi_kb_CA2,
      netint_i       => ibpi_netint,
      irq_i          => ibpi_irq,
      nmi_i          => ibpi_nmi,

      -- MIO_O1 phase
      j_ds_nCS2_o    => ibpo_j_ds_nCS2,
      j_ds_nCS1_o    => ibpo_j_ds_nCS1,
      j_spi_clk_o    => ibpo_j_spi_clk,
      VID_HS_o       => ibpo_VID_HS,
      VID_VS_o       => ibpo_VID_VS,
      VID_CS_o       => ibpo_VID_CS,
      j_spi_mosi_o   => ibpo_j_spi_mosi,
      j_adc_nCS_o    => ibpo_j_adc_nCS,

      -- MIO_I1 phase
      j_i0_i         => ibpi_j_i0,
      j_i1_i         => ibpi_j_i1,
      j_spi_miso_i   => ibpi_j_spi_miso,
      btn0_i         => ibpi_btn0,
      btn1_i         => ibpi_btn1,
      btn2_i         => ibpi_btn2,
      btn3_i         => ibpi_btn3,
      kb_pa7_i       => ibpi_kb_pa7,

      -- data phase
      P_D_io         => ibpio_P_D,

      -- address phase
      P_A_o          => ibpo_A


   );


   -- slow latch the data lines are munged in or before the controller
   -- to mimic a LS259 8 bit addressable latch
   e_U9:entity work.hct574
    PORT MAP (
        Q       => i_u11_Q,
        D       => ibpio_P_D,
        CLK     => ibpo_nIC32WR,
        nOE     => '0'
    );


end rtl;

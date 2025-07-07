library vunit_lib;
context vunit_lib.vunit_context;



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use std.textio.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.fb_tester_pack.all;

library fmf;

library work;

entity test_tb is
   generic (
      runner_cfg : string
      );
end test_tb;

architecture rtl of test_tb is

   --constant G_MOSROMFILE : string := "C:/Users/Dominic/Documents/Programming/HostFS/roms65/MOS120.M";
   constant G_MOSROMFILE : string := "../../../../../asm/C20KTestMOS/build/C20KTestMOS-ThrottleOff.rom";

   constant BOARD_CLOCKSPEED : natural := 27;

   constant BOARD_CLOCK_PER : time := (1000000/BOARD_CLOCKSPEED) * 1 ps;

   type t_byte_array is array(natural range <>) of std_logic_vector(7 downto 0);

   signal r_brd_clk        : std_logic;
   signal r_sup_nRST       : std_logic;

   -- signals to/from mux controller and mux/board simulation
   signal im_mux_mhz1E_clk : std_logic;
   signal im_mux_mhz2E_clk : std_logic;

   signal im_mux_nALE_o    : std_logic;
   signal im_mux_D_nOE_o   : std_logic;
   signal im_mux_I0_nOE_o  : std_logic;
   signal im_mux_I1_nOE_o  : std_logic;
   signal im_mux_O0_nOE_o  : std_logic;
   signal im_mux_O1_nOE_o  : std_logic;

   signal im_mux_bus_io    : std_logic_vector(7 downto 0);

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
   signal ibpi_ser_cts     : std_logic := '1';
   signal ibpi_ser_rx      : std_logic := '1';
   signal ibpi_d_cas       : std_logic := '1';
   signal ibpi_kb_nRST     : std_logic := '1';
   signal ibpi_kb_CA2      : std_logic := '1';
   signal ibpi_netint      : std_logic := '1';
   signal ibpi_irq         : std_logic := '1';
   signal ibpi_nmi         : std_logic := '1';
   signal ibpo_j_ds_nCS2   : std_logic;
   signal ibpo_j_ds_nCS1   : std_logic;
   signal ibpo_j_spi_clk   : std_logic;
   signal ibpo_VID_HS      : std_logic;
   signal ibpo_VID_VS      : std_logic;
   signal ibpo_VID_CS      : std_logic;
   signal ibpo_j_spi_mosi  : std_logic;
   signal ibpo_j_adc_nCS   : std_logic;
   signal ibpi_j_i0        : std_logic := '1';
   signal ibpi_j_i1        : std_logic := '1';
   signal ibpi_j_spi_miso  : std_logic := '1';
   signal ibpi_btn0        : std_logic := '1';
   signal ibpi_btn1        : std_logic := '1';
   signal ibpi_btn2        : std_logic := '1';
   signal ibpi_btn3        : std_logic := '1';
   signal ibpi_kb_pa7      : std_logic := '1';
   signal ibpio_P_D        : std_logic_vector(7 downto 0);
   signal ibpo_A           : std_logic_vector(7 downto 0);

   -- memory on motherboard

   signal i_mem_A          : std_logic_vector(20 downto 0);
   signal i_mem_D          : std_logic_vector(7 downto 0);
   signal i_mem_RAM_nCE    : std_logic_vector(3 downto 0);
   signal i_mem_ROM_nCE    : std_logic;
   signal i_mem_nOE        : std_logic;
   signal i_mem_nWE        : std_logic;

begin
   p_brd_clk:process
   begin
      r_brd_clk <= '1';
      wait for BOARD_CLOCK_PER / 2;
      r_brd_clk <= '0';
      wait for BOARD_CLOCK_PER / 2;
   end process;

   p_brd_rst:process
   begin
      wait for 100 ns;
      r_sup_nRST <= '0';
      wait for 10 us;
      r_sup_nRST <= '1';
      wait;
   end process;



   p_main:process
   begin

      test_runner_setup(runner, runner_cfg);

      while test_suite loop

         if run("look") then

            wait for 1200 us;

         end if;

      end loop;

      wait for 3 us;

      test_runner_cleanup(runner); -- Simulation ends here
   end process;

   e_dut:entity work.C20K
   generic map (
      SIM                           => true,
      CLOCKSPEED                    => 128
   )
   port map (

      brd_clk_27M_i        => r_brd_clk,
      sup_nRST_i           => r_sup_nRST,

      clk_ext_pal_i        => '1',


      --ddr_addr_o           => open,
      ddr_bank_o           => open,
      ddr_cas_o            => open,
      ddr_ck_o             => open,
      ddr_cke_o            => open,
      ddr_cs_o             => open,
      ddr_dm_io            => open,
      ddr_dq_io            => open,
      ddr_dqs_io           => open,
      ddr_odt_o            => open,
      ddr_ras_o            => open,
      ddr_reset_n_o        => open,
      ddr_we_o             => open,

      mem_A_io             => i_mem_A,
      mem_D_io             => i_mem_D,
      mem_RAM_nCE_o        => i_mem_RAM_nCE,
      mem_ROM_nCE_o        => i_mem_ROM_nCE,
      mem_nOE_o            => i_mem_nOE,
      mem_nWE_o            => i_mem_nWE,

      cpu_A_nOE_o          => open,
      cpu_BE_o             => open,
      cpu_E_i              => '1',
      cpu_MX_i             => '1',
      cpu_PHI2_o           => open,
      cpu_RDY_o            => open,
      cpu_nABORT_io        => '1',
      cpu_nIRQ_o           => open,
      cpu_nNMI_o           => open,
      cpu_nRES_o           => open,


      aud_i2s_bck_pwm_L_o  => open,
      aud_i2s_dat_o        => open,
      aud_i2s_ws_pwm_R_o   => open,


      flash_ck_o           => open,
      flash_cs_o           => open,
      flash_miso_i         => '1',
      flash_mosi_o         => open,

      tmds_clk_o_p         => open,
      tmds_d_o_p           => open,
      edid_scl_io          => open,
      edid_sda_io          => open,
      hdmi_cec_io          => open,
      hdmi_hpd_io          => open,

      vid_b_o              => open,
      vid_chroma_o         => open,
      vid_g_o              => open,
      vid_r_o              => open,

      i2c_scl_io           => open,
      i2c_sda_io           => open,

      mux_D_nOE_o          => im_mux_D_nOE_o, 
      mux_i0_nOE_o         => im_mux_I0_nOE_o, 
      mux_i1_nOE_o         => im_mux_I1_nOE_o, 
      mux_io               => im_mux_bus_io, 
      mux_nALE_o           => im_mux_nALE_o, 
      mux_o0_nOE_o         => im_mux_O0_nOE_o, 
      mux_o1_nOE_o         => im_mux_O1_nOE_o, 

      p_1MHZ_E_o           => im_mux_mhz1E_clk,
      p_2MHZ_E_o           => im_mux_mhz2E_clk,
      p_8MHZ_FDC_o         => open,
      pj_LPSTB_i           => '1',
      cassette_o           => open,

      sd0_cs_o             => open,
      sd0_miso_i           => '1',
      sd0_mosi_o           => open,
      sd0_sclk_o           => open,
      
      sd1_cs_o             => open,
      sd1_miso_i           => '1',
      sd1_mosi_o           => open,
      sd1_sclk_o           => open,
      
      spare_T3             => '1',
      spare_T4             => '1',
      spare_rst_n_t10_i    => '1',

      ui_leds_o            => open,
      
      uart2_dtr_i          => '1',
      uart2_rts_o          => open,
      uart2_rx_i           => '1',
      uart2_tx_o           => open

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



   --actually just the same ROM repeated!
   e_blit_rom_512: entity work.ram_tb 
   generic map (
      size        => 16*1024,
      dump_filename => "",
      romfile => G_MOSROMFILE,
      tco => 55 ns,
      taa => 55 ns
   )
   port map (
      A           => i_MEM_A(13 downto 0),
      D           => i_MEM_D,
      nCS         => i_mem_ROM_nCE,
      nOE         => i_MEM_nOE,
      nWE         => '1',
      
      tst_dump    => '0'

   );

   -- single non BB ram
   --TODO the timings are wrong!
   e_blit_ram_2048: entity work.ram_tb 
   generic map (
      size        => 2*1024*1024,
      dump_filename => "c:/temp/ram_dump_blit_dip40_poc-blitram.bin",
      tco => 10 ns,
      taa => 10 ns,
      toh => 2 ns,      
      tohz => 3 ns,  
      thz => 3 ns,
      tolz => 3 ns,
      tlz => 3 ns,
      toe => 4.5 ns,
      twed => 6.5 ns
   )
   port map (
      A           => i_MEM_A(20 downto 0),
      D           => i_MEM_D,
      nCS         => i_MEM_RAM_nCE(1),
      nOE         => i_MEM_nOE,
      nWE         => i_MEM_nWE,
      
      tst_dump    => '0'

   );

end rtl;

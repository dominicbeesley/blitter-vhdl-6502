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

   constant CLOCKSPEED : natural := 128;

   constant CLOCK_PER : time := (1000000/CLOCKSPEED) * 1 ps;

   type t_byte_array is array(natural range <>) of std_logic_vector(7 downto 0);

   signal i_fb_syscon : fb_syscon_t;
   signal i_fb_con_c2p : fb_con_o_per_i_t;
   signal i_fb_con_p2c : fb_con_i_per_o_t;

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

   -- back out to core signals
   signal i_sys_ROMPG         : std_logic_vector(7 downto 0);
   signal i_jim_en            : std_logic;
   signal i_jim_page          : std_logic_vector(15 downto 0);
   signal cpu_2MHz_phi2_clken : std_logic;

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

   signal i_u11_Q          : std_logic_vector(7 downto 0);

   procedure multi_read(
         A        : in  std_logic_vector(23 downto 0);
         N        : positive;
      signal c2p  : out fb_con_o_per_i_t;
         D        : out t_byte_array;

         A_stb_dl : natural := 0       -- no of cycles to delay a_stb after cyc and between cycles
      ) is
   variable v_tx : natural; -- number of a_stb's sent
   variable v_rx : natural; -- number of acks sent
   variable v_wt : natural;
   variable v_tot: natural;
   variable v_wt_stall:boolean;
   begin

      c2p <= fb_c2p_unsel;

      wait until rising_edge(i_fb_syscon.clk);

      c2p.cyc <= '1';
      c2p.rdy_ctdn <= RDY_CTDN_MIN;
      c2p.we <= '0';

      v_tot := 0;
      v_wt := A_stb_dl;
      v_wt_stall := false;
      while v_rx < N loop

         v_tot := v_tot + 1;
         assert v_tot < N * 2000 report "multi read " & to_hex_string(A) & "[" & natural'image(N) & "] took too many cyles" severity error;

         if v_tx < N and v_wt = 0 and not v_wt_stall then
            c2p.A <= std_logic_vector(unsigned(A) + v_tx);
            c2p.A_stb <= '1';
            v_tx := v_tx + 1;
            v_wt_stall := true;
         end if;

         wait until rising_edge(i_fb_syscon.clk);

         if v_wt_stall and i_fb_con_p2c.stall = '0' then
            v_wt_stall := false;
            c2p.A_stb <= '0';
            v_wt := A_stb_dl;
         end if;

         if i_fb_con_p2c.ack = '1' then
            D(v_rx) := i_fb_con_p2c.D_rd;
            v_rx := v_rx + 1;
         end if;

      end loop;

      c2p <= fb_c2p_unsel;


   end multi_read;


   


   procedure test_multi_mem_read(
      A           : in std_logic_vector(23 downto 0);
      N           : positive; -- number of reads in burst
      signal c2p  : out fb_con_o_per_i_t;
      A_stb_dl    : in natural := 0    -- number of cycles to delay A_stb for reads    
   )  is
   variable v_read: t_byte_array(0 to N-1);
   variable v_exp : t_byte_array(0 to N-1);
   variable i     : natural;
   begin

      multi_read(A, N, c2p, v_read, 0);

      for i in 0 to N-1 loop
         v_exp(I) := std_logic_vector((unsigned(A(7 downto 0)) + i) xor x"FF");

         assert v_read(I) = v_exp(I) report "returned " & to_hex_string(A) & "[" & natural'image(i) & "] " & to_hex_string(v_read(I)) & " expecting " & to_hex_string(v_exp(I)) severity error;
      end loop;

   end test_multi_mem_read;


   procedure test_simple_mem_read(
      A           : in std_logic_vector(23 downto 0);
      signal c2p  : out fb_con_o_per_i_t;
      A_stb_dl    : in natural := 0    -- number of cycles to delay A_stb for reads    
   )  is
   variable v_read: std_logic_vector(7 downto 0);
   variable v_exp : std_logic_vector(7 downto 0);
   begin

      fbtest_single_read(
         syscon_i => i_fb_syscon,
         p2c_i => i_fb_con_p2c,
         c2p_o => c2p,
         A_i => A, 
         D_o => v_read
         );

      v_exp := A(7 downto 0) xor x"FF";

      assert v_read = v_exp report "returned " & to_hex_string(v_read) & " expecting " & to_hex_string(v_exp) severity error;

   end test_simple_mem_read;


   procedure test_simple_mem_write_then_read(
      A           : in std_logic_vector(23 downto 0);
      D           : in std_logic_vector(7 downto 0);
      signal c2p  : out fb_con_o_per_i_t;
      A_stb_dl    : in natural := 0;      -- number of cycles to delay A_stb for reads/writes
      D_stb_dl    : in natural := 0
   )  is
   variable v_read: std_logic_vector(7 downto 0);
   begin

      fbtest_single_write(
         syscon_i => i_fb_syscon,
         p2c_i => i_fb_con_p2c,
         c2p_o => c2p,

         A_i => A,
         D_i => D, 
         A_stb_dl_i => A_stb_dl, 
         D_stb_dl_i => D_stb_dl
         );

      -- do a dummy read to clear any registered addresses!
      fbtest_single_read(
         syscon_i => i_fb_syscon,
         p2c_i => i_fb_con_p2c,
         c2p_o => c2p,
         A_i =>x"000000", 
         D_o => v_read,
         A_stb_dl_i => A_stb_dl
         );

      -- do actual read
      fbtest_single_read(
         syscon_i => i_fb_syscon,
         p2c_i => i_fb_con_p2c,
         c2p_o => c2p,
         A_i => A, 
         D_o => v_read,
         A_stb_dl_i => A_stb_dl
         );

      assert v_read = D report "returned " & to_hex_string(v_read) & " expecting " & to_hex_string(D) severity error;

   end test_simple_mem_write_then_read;

   procedure simple_write(
      A           : in std_logic_vector(23 downto 0);
      D           : in std_logic_vector(7 downto 0);
      signal c2p  : out fb_con_o_per_i_t;
      A_stb_dl    : in natural := 0;      -- number of cycles to delay A_stb for reads/writes
      D_stb_dl    : in natural := 0
   )  is
   begin

      fbtest_single_write(
         syscon_i => i_fb_syscon,
         p2c_i => i_fb_con_p2c,
         c2p_o => c2p,
         A_i => A,
         D_i => D, 
         A_stb_dl_i => A_stb_dl, 
         D_stb_dl_i => D_stb_dl
         );

   end simple_write;

begin
   p_syscon_clk:process
   begin
      i_fb_syscon.clk <= '1';
      wait for CLOCK_PER / 2;
      i_fb_syscon.clk <= '0';
      wait for CLOCK_PER / 2;
   end process;

   p_syscon_rst:process
   begin
      wait for 100 ns;
      i_fb_syscon.rst <= '1';
      -- simplify reset sequence
      i_fb_syscon.rst_state <= powerup;
      wait for 1 us;
      i_fb_syscon.rst <= '0';
      -- simplify reset sequence
      i_fb_syscon.rst_state <= run;
      wait;
   end process;


   p_main:process
   variable v_time:time;

   begin

      test_runner_setup(runner, runner_cfg);

      while test_suite loop

         if run("write latch and test") then

            -- simple single read, with no a_stb delay

            fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

            wait for 10 us;

            simple_write(x"FFFE40", x"08", i_fb_con_c2p);
            simple_write(x"FFFE40", x"00", i_fb_con_c2p);

         

         end if;

      end loop;

      wait for 3 us;

      test_runner_cleanup(runner); -- Simulation ends here
   end process;

   e_dut:entity work.fb_sys_c20k
   generic map (
      SIM                           => true,
      CLOCKSPEED                    => CLOCKSPEED,
      G_JIM_DEVNO                   => x"D2"
   )
   port map (

      -- fishbone signals

      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_i                      => i_fb_con_c2p,
      fb_p2c_o                      => i_fb_con_p2c,

      -- mux clock outputs
      mux_mhz1E_clk_o               => im_mux_mhz1E_clk,
      mux_mhz2E_clk_o               => im_mux_mhz2E_clk,

      -- mux control outputs
      mux_nALE_o                    => im_mux_nALE_o,
      mux_D_nOE_o                   => im_mux_D_nOE_o,
      mux_I0_nOE_o                  => im_mux_I0_nOE_o,
      mux_I1_nOE_o                  => im_mux_I1_nOE_o,
      mux_O0_nOE_o                  => im_mux_O0_nOE_o,
      mux_O1_nOE_o                  => im_mux_O1_nOE_o,

      -- mux multiplexed signals bus
      mux_bus_io                    => im_mux_bus_io,


      -- memory registers managed in here
      sys_ROMPG_o                   => i_sys_ROMPG,
      jim_en_o                      => i_jim_en,
      jim_page_o                    => i_jim_page,

      -- cpu sync 
      cpu_2MHz_phi2_clken_o         => cpu_2MHz_phi2_clken

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

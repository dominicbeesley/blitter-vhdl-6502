-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2025 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:      2/6/2025
-- Design Name: 
-- Module Name:      P20KBare
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      Top level module for C20K/Primer 20K test system
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.common.all;
use work.fishbone.all;
use work.fb_CPU_pack.all;
use work.fb_intcon_pack.all;
use work.board_config_pack.all;
use work.ws2812_pack.all;

entity P20KBare is
   generic (
      SIM                           : boolean := false;                    -- skip some stuff, i.e. slow sdram start up
      CLOCKSPEED                    : natural := 128;                      -- fast clock speed in mhz          
      BAUD                          : natural := 19200;
      PROJECT_ROOT_PATH             : string  := "../../../../.."
   );
   port (

      brd_clk_27M_i        : in            std_logic;

      sup_nRST_i           : in            std_logic;

      clk_ext_pal_i        : in            std_logic;


      ddr_addr_o           : out           std_logic_vector(13 downto 0);
      ddr_bank_o           : out           std_logic_vector(2 downto 0);
      ddr_cas_o            : out           std_logic;
      ddr_ck_o             : out           std_logic;
      ddr_cke_o            : out           std_logic;
      ddr_cs_o             : out           std_logic;
      ddr_dm_io            : in            std_logic_vector(1 downto 0);
      ddr_dq_io            : in            std_logic_vector(15 downto 0);
      ddr_dqs_io           : in            std_logic_vector(1 downto 0);
      ddr_odt_o            : out           std_logic;
      ddr_ras_o            : out           std_logic;
      ddr_reset_n_o        : out           std_logic;
      ddr_we_o             : out           std_logic;

      mem_A_io             : inout         std_logic_vector(20 downto 0); -- note: inout as can be to RAM or from CPU
      mem_D_io             : inout         std_logic_vector(7 downto 0);
      mem_nCE_o            : out           std_logic_vector(3 downto 1);
      mem_nCE_BB_o         : out           std_logic;
      mem_nCE_FL_o         : out           std_logic;
      mem_nOE_o            : out           std_logic;
      mem_nWE_o            : out           std_logic;

      cpu_A_nOE_o          : out           std_logic;
      cpu_BE_o             : out           std_logic;
      cpu_E_i              : in            std_logic;
      cpu_MX_i             : in            std_logic;
      cpu_PHI2_o           : out           std_logic;
      cpu_RDY_o            : out           std_logic;
      cpu_nABORT_io        : in            std_logic;
      cpu_nIRQ_o           : out           std_logic;
      cpu_nNMI_o           : out           std_logic;
      cpu_nRES_o           : out           std_logic;


      aud_i2s_bck_pwm_L_o  : out           std_logic;
      aud_i2s_dat_o        : out           std_logic;
      aud_i2s_ws_pwm_R_o   : out           std_logic;


      flash_ck_o           : out           std_logic;
      flash_cs_o           : out           std_logic;
      flash_miso_i         : in            std_logic;
      flash_mosi_o         : out           std_logic;

      tmds_clk_o_p         : out           std_logic;
      tmds_d_o_p           : out           std_logic_vector(2 downto 0);
      edid_scl_o           : out           std_logic;
      edid_sda_io          : inout         std_logic;
      hdmi_cec_io          : inout         std_logic;
      hdmi_hpd_io          : inout         std_logic;

      vid_b_o              : out           std_logic;
      vid_chroma_o         : out           std_logic;
      vid_g_o              : out           std_logic;
      vid_r_o              : out           std_logic;

      i2c_scl_o            : out           std_logic;
      i2c_sda_io           : inout         std_logic;

      mux_D_nOE_o          : out           std_logic;
      mux_i0_nOE_o         : out           std_logic;
      mux_i1_nOE_o         : out           std_logic;
      mux_io               : out           std_logic_vector(7 downto 0);
      mux_nALE_o           : out           std_logic;
      mux_o0_nOE_o         : out           std_logic;
      mux_o1_nOE_o         : out           std_logic;

      p_1MHZ_E_o           : out           std_logic;
      p_2MHZ_E_o           : out           std_logic;
      p_8MHZ_FDC_o         : out           std_logic;
      pj_LPSTB_i           : in            std_logic;
      cassette_o           : out           std_logic;

      sd0_cs_o             : out           std_logic;
      sd0_miso_i           : in            std_logic;
      sd0_mosi_o           : out           std_logic;
      sd0_sclk_o           : out           std_logic;
      
      sd1_cs_o             : out           std_logic;
      sd1_miso_i           : in            std_logic;
      sd1_mosi_o           : out           std_logic;
      sd1_sclk_o           : out           std_logic;
      
      spare_T3             : in            std_logic;
      spare_T4             : in            std_logic;
      spare_rst_n_t10_i    : in            std_logic;

      ui_leds_o            : out           std_logic;
      
      uart2_dtr_i          : in            std_logic;
      uart2_rts_o          : out           std_logic;
      uart2_rx_i           : in            std_logic;
      uart2_tx_o           : out           std_logic

);
end entity;

architecture rtl of P20KBare is

   signal   i_JIM_page     : std_logic_vector(15 downto 0);


   -----------------------------------------------------------------------------
   -- fishbone signals
   -----------------------------------------------------------------------------

   signal i_fb_syscon         : fb_syscon_t;                   -- shared bus signals

   -- cpu wrapper
   signal i_c2p_cpu           : fb_con_o_per_i_t;
   signal i_p2c_cpu           : fb_con_i_per_o_t;

   -- block ROM wrapper
   signal i_c2p_mem_rom           : fb_con_o_per_i_t;
   signal i_p2c_mem_rom           : fb_con_i_per_o_t;

   -- block RAM wrapper
   signal i_c2p_mem_ram           : fb_con_o_per_i_t;
   signal i_p2c_mem_ram           : fb_con_i_per_o_t;

   -- SRAM wrapper
   signal i_c2p_mem_ram_brd       : fb_con_o_per_i_t;
   signal i_p2c_mem_ram_brd       : fb_con_i_per_o_t;

   -- uart wrapper
   signal i_c2p_uart          : fb_con_o_per_i_t;
   signal i_p2c_uart          : fb_con_i_per_o_t;

   -- 1mhz bus wrapper
   signal i_c2p_1mhz_bus          : fb_con_o_per_i_t;
   signal i_p2c_1mhz_bus          : fb_con_i_per_o_t;

   -- LED array wrapper
   signal i_c2p_led_arr          : fb_con_o_per_i_t;
   signal i_p2c_led_arr          : fb_con_i_per_o_t;

   -- intcon controller->peripheral
   signal i_con_c2p_intcon    : fb_con_o_per_i_arr(CONTROLLER_COUNT-1 downto 0);
   signal i_con_p2c_intcon    : fb_con_i_per_o_arr(CONTROLLER_COUNT-1 downto 0);
   -- intcon peripheral->controller
   signal i_per_c2p_intcon    : fb_con_o_per_i_arr(PERIPHERAL_COUNT-1 downto 0);
   signal i_per_p2c_intcon    : fb_con_i_per_o_arr(PERIPHERAL_COUNT-1 downto 0);

   -----------------------------------------------------------------------------
   -- intcon to peripheral sel
   -----------------------------------------------------------------------------
   signal i_intcon_peripheral_sel_addr    : fb_arr_std_logic_vector(CONTROLLER_COUNT-1 downto 0)(23 downto 0);
   signal i_intcon_peripheral_sel         : fb_arr_unsigned(CONTROLLER_COUNT-1 downto 0)(numbits(PERIPHERAL_COUNT)-1 downto 0);  -- address decoded selected peripheral
   signal i_intcon_peripheral_sel_oh      : fb_arr_std_logic_vector(CONTROLLER_COUNT-1 downto 0)(PERIPHERAL_COUNT-1 downto 0);   -- address decoded selected peripherals as one-hot    

   -----------------------------------------------------------------------------
   -- peripherals
   -----------------------------------------------------------------------------
   
   constant C_BAUD_CKK16_DIV : positive := (CLOCKSPEED*1000000)/(16*BAUD);

   signal r_clken_baud16  : std_logic;
   signal r_clk_baud_div: unsigned(numbits(C_BAUD_CKK16_DIV-1) downto 0); -- note 1 bigger to catch carry out

   signal i_ser_tx      : std_logic;

   signal i_clk_pll_48M: std_logic;
   signal i_clk_pll_128M: std_logic;

begin

   e_pll_27_48: entity work.pll_27_48
   port map (
      clkout => i_clk_pll_48M,
      clkin => brd_clk_27M_i
   );

   e_pll_48_128: entity work.pll_48_128
   port map (
      clkout => i_clk_pll_128M,
      clkin => i_clk_pll_48M
   );

   e_fb_syscon: entity work.fb_syscon
   generic map (
      SIM => SIM,
      CLOCKSPEED => CLOCKSPEED
   )
   port map (
      fb_syscon_o                   => i_fb_syscon,

      EXT_nRESET_i                  => sup_nRST_i,

      clk_fish_i                    => i_clk_pll_128M,
      clk_lock_i                    => '1',
      sys_dll_lock_i                => '1'

   ); 

   -- address decode to select peripheral
   e_addr2s:entity work.address_decode_P20K
   generic map (
      SIM                     => SIM,
      G_PERIPHERAL_COUNT      => PERIPHERAL_COUNT
   )
   port map (
      addr_i                  => i_intcon_peripheral_sel_addr(0),
      peripheral_sel_o        => i_intcon_peripheral_sel(0),
      peripheral_sel_oh_o     => i_intcon_peripheral_sel_oh(0)
   );

   e_fb_intcon: fb_intcon_one_to_many
   generic map (
      SIM                           => SIM,
      G_PERIPHERAL_COUNT                  => PERIPHERAL_COUNT,
      G_ADDRESS_WIDTH               => 24
      )
   port map (
      fb_syscon_i                   => i_fb_syscon,

      -- peripheral ports connect to controllers
      fb_con_c2p_i                  => i_con_c2p_intcon(0),
      fb_con_p2c_o                  => i_con_p2c_intcon(0),

      -- controller ports connect to peripherals
      fb_per_c2p_o                  => i_per_c2p_intcon,
      fb_per_p2c_i                  => i_per_p2c_intcon,

      peripheral_sel_addr_o         => i_intcon_peripheral_sel_addr(0),
      peripheral_sel_i              => i_intcon_peripheral_sel(0),
      peripheral_sel_oh_i           => i_intcon_peripheral_sel_oh(0)
   );

   i_con_c2p_intcon(MAS_NO_CPU)           <= i_c2p_cpu;
   i_per_p2c_intcon(PERIPHERAL_NO_MEM_RAM)<= i_p2c_mem_ram;
   i_per_p2c_intcon(PERIPHERAL_NO_MEM_ROM)<= i_p2c_mem_rom;
   i_per_p2c_intcon(PERIPHERAL_NO_MEM_BRD)<= i_p2c_mem_ram_brd;
   i_per_p2c_intcon(PERIPHERAL_NO_1MHZ_BUS)<= i_p2c_1mhz_bus;
   i_per_p2c_intcon(PERIPHERAL_NO_LED_ARR)<= i_p2c_led_arr;
   i_per_p2c_intcon(PERIPHERAL_NO_UART)   <= i_p2c_uart;

   i_p2c_cpu            <= i_con_p2c_intcon(MAS_NO_CPU);
   i_c2p_mem_ram        <= i_per_c2p_intcon(PERIPHERAL_NO_MEM_RAM);
   i_c2p_mem_rom        <= i_per_c2p_intcon(PERIPHERAL_NO_MEM_ROM);
   i_c2p_mem_ram_brd    <= i_per_c2p_intcon(PERIPHERAL_NO_MEM_BRD);
   i_c2p_1mhz_bus       <= i_per_c2p_intcon(PERIPHERAL_NO_1MHZ_BUS);
   i_c2p_led_arr        <= i_per_c2p_intcon(PERIPHERAL_NO_LED_ARR);
   i_c2p_uart           <= i_per_c2p_intcon(PERIPHERAL_NO_UART);

   e_fb_mem_rom: entity work.fb_P20K_mem
   generic map (
      G_ADDR_W => 12,   -- 4K
      G_READONLY => true,
      INIT_FILE => PROJECT_ROOT_PATH & "/src/hdl/modelC20K/FirstLight/asm/P20KBareMOS/build/P20K-boot-rom.vec"
      )
   port map (
      -- fishbone signals

      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_i                      => i_c2p_mem_rom,
      fb_p2c_o                      => i_p2c_mem_rom

   );

   e_fb_mem_ram: entity work.fb_P20K_mem
   generic map (
      G_ADDR_W => 12 -- 4K      
      )
   port map (
      -- fishbone signals

      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_i                      => i_c2p_mem_ram,
      fb_p2c_o                      => i_p2c_mem_ram

   );

   e_fb_mem_sdram:entity work.fb_C20K_mem_sram
   port map (

      -- fishbone signals

      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_i                      => i_c2p_mem_ram_brd,
      fb_p2c_o                      => i_p2c_mem_ram_brd,

      mem_A_o                       => mem_A_io,
      mem_D_io                      => mem_D_io,
      mem_nCE_o                     => mem_nCE_o,
      mem_nCE_BB_o                  => mem_nCE_BB_o,
      mem_nCE_FL_o                  => mem_nCE_FL_o,
      mem_nOE_o                     => mem_nOE_o,
      mem_nWE_o                     => mem_nWE_o


   );

   e_fb_1mhzBus:entity work.fb_c20k_1MHZ_bus
   port map (

      -- fishbone signals

      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_i                      => i_c2p_1mhz_bus,
      fb_p2c_o                      => i_p2c_1mhz_bus,

      JIM_page_o                    => i_JIM_page
   );

   p_uart_clk:process(i_fb_syscon)
   begin
      if rising_edge(i_fb_syscon.clk) then
         r_clken_baud16 <= '0';
         if i_fb_syscon.rst = '1' then
            r_clk_baud_div <= to_unsigned(C_BAUD_CKK16_DIV-1, r_clk_baud_div'length);
         elsif r_clk_baud_div(r_clk_baud_div'high) = '1' then
            r_clk_baud_div <= to_unsigned(C_BAUD_CKK16_DIV-1, r_clk_baud_div'length);
            r_clken_baud16 <= '1';
         else
            r_clk_baud_div <= r_clk_baud_div - 1;
         end if;
      end if;
   end process;

   e_fb_uart: entity work.fb_uart
   port map (
      baud16_clken_i => r_clken_baud16,
      ser_rx_i       => uart2_rx_i,
      ser_tx_o       => uart2_tx_o,

      -- fishbone signals

      fb_syscon_i    => i_fb_syscon,
      fb_c2p_i    => i_c2p_uart,
      fb_p2c_o    => i_p2c_uart

   );


   e_fb_cpu_t65only: entity work.fb_cpu_t65only
   generic map (
      SIM => SIM,
      CLOCKSPEED => CLOCKSPEED
   )
   port map (

      -- direct CPU control signals from system
      nmi_n_i                       => '1',
      irq_n_i                       => '1',
      cpu_halt_i                    => '0',

      -- fishbone signals
      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_o                      => i_c2p_cpu,
      fb_p2c_i                      => i_p2c_cpu,

      -- logical mappings
      JIM_page_i                    => i_JIM_page

   );

--   led(0) <= i_ser_tx;
--   led(1) <= '1';
--   led(2) <= not i_ser_tx;
--   led(3) <= '0';

   e_fb_led_arr:entity work.fb_ws2812
   generic map (
      G_CLOCKSPEED => CLOCKSPEED * 1000000,
      G_N_CHAIN => 8
      )
   port map (

      -- fishbone signals

      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_i                      => i_c2p_led_arr,
      fb_p2c_o                      => i_p2c_led_arr,

      led_serial_o                  => ui_leds_o
   );


      ddr_addr_o           <= (others => '0');
      ddr_bank_o           <= (others => '0');
      ddr_cas_o            <= '0';
      ddr_ck_o             <= '0';
      ddr_cke_o            <= '0';
      ddr_cs_o             <= '0';
      ddr_odt_o            <= '0';
      ddr_ras_o            <= '0';
      ddr_reset_n_o        <= '0';
      ddr_we_o             <= '0';


      cpu_A_nOE_o          <= '1';
      cpu_BE_o             <= '0';
      cpu_PHI2_o           <= '1';
      cpu_RDY_o            <= '1';
      cpu_nIRQ_o           <= '1';
      cpu_nNMI_o           <= '1';
      cpu_nRES_o           <= '1';

      aud_i2s_bck_pwm_L_o  <= '1';
      aud_i2s_dat_o        <= '1';
      aud_i2s_ws_pwm_R_o   <= '1';

      flash_ck_o           <= '1';
      flash_cs_o           <= '1';
      flash_mosi_o         <= '1';

      tmds_clk_o_p         <= '1';
      tmds_d_o_p           <= (others => '1');
      edid_scl_o           <= '1';
      edid_sda_io          <= 'Z';
      hdmi_cec_io          <= 'Z';
      hdmi_hpd_io          <= 'Z';

      vid_b_o              <= '0';
      vid_chroma_o         <= '0';
      vid_g_o              <= '0';
      vid_r_o              <= '0';

      i2c_scl_o            <= '1';
      i2c_sda_io           <= 'Z';

      mux_D_nOE_o          <= '1';
      mux_i0_nOE_o         <= '1';
      mux_i1_nOE_o         <= '1';
      mux_io               <= (others => 'Z');
      mux_nALE_o           <= '1';
      mux_o0_nOE_o         <= '1';
      mux_o1_nOE_o         <= '1';

      p_1MHZ_E_o           <= '0';
      p_2MHZ_E_o           <= '0';
      p_8MHZ_FDC_o         <= '0';

      cassette_o           <= '0';

      sd0_cs_o             <= '0';
      sd0_mosi_o           <= '0';
      sd0_sclk_o           <= '0';
      
      sd1_cs_o             <= '0';
      sd1_mosi_o           <= '0';
      sd1_sclk_o           <= '0';
                     
      





end architecture rtl;
      
      

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
-- Module Name:      C20KFirstLight
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
use work.board_config_pack.all;
use work.HDMI_pack.all;
use work.fb_CPU_pack.all;
use work.fb_intcon_pack.all;

entity C60KFirstLight is
   generic (
      SIM                           : boolean := false;                    -- skip some stuff, i.e. slow sdram start up
      CLOCKSPEED                    : natural := 128;                      -- fast clock speed in mhz          
      BAUD                          : natural := 19200;
      PROJECT_ROOT_PATH             : string  := "../../../../..";
      SDRAM_DATA_WIDTH              : natural := 16;     -- 2 bytes per word
      SDRAM_ROW_WIDTH               : natural := 13;     -- 8K rows
      SDRAM_COL_WIDTH               : natural := 9;      -- 512 cols
      SDRAM_BANK_WIDTH              : natural := 2       -- 4 banks
   );
   port (

      sys_clk_50_i        : in            std_logic;

      sup_nRST_i           : in            std_logic;

      clk_ext_pal_i        : in            std_logic;

      sdram_clk_o          : out           std_logic;
      sdram_cke_o          : out           std_logic;
      sdram_cs_n_o         : out           std_logic;
      sdram_cas_n_o        : out           std_logic;
      sdram_ras_n_o        : out           std_logic;
      sdram_wen_n_o        : out           std_logic;
      sdram_dq_io          : inout         std_logic_vector(SDRAM_DATA_WIDTH-1 downto 0);
      sdram_addr_o         : out           std_logic_vector(SDRAM_ROW_WIDTH-1 downto 0);
      sdram_ba_o           : out           std_logic_vector(SDRAM_BANK_WIDTH-1 downto 0);
      sdram_dqm_o          : out           std_logic_vector(SDRAM_DATA_WIDTH / 8 - 1 downto 0);

      aud_i2s_bck_pwm_L_o  : out           std_logic;
      aud_i2s_dat_o        : out           std_logic;
      aud_i2s_ws_pwm_R_o   : out           std_logic;

      led_o                : out           std_logic_vector(7 downto 0);

      ds_clk_o             : out           std_logic;
      ds_miso_i            : in            std_logic;
      ds_mosi_o            : out           std_logic;
      ds_cs_o              : out           std_logic;
      ds_clk2_o            : out           std_logic;
      ds_miso2_i           : in            std_logic;
      ds_mosi2_o           : out           std_logic;
      ds_cs2_o             : out           std_logic;

      usb1_dp_io           : inout         std_logic;
      usb1_dn_io           : inout         std_logic;
      usb2_dp_io           : inout         std_logic;
      usb2_dn_io           : inout         std_logic;


      flash_ck_o           : out           std_logic;
      flash_cs_o           : out           std_logic;
      flash_miso_i         : in            std_logic;
      flash_mosi_o         : out           std_logic;

      tmds_clk_o_p         : out           std_logic;
      tmds_d_o_p           : out           std_logic_vector(2 downto 0);
      edid_scl_io          : inout         std_logic;
      edid_sda_io          : inout         std_logic;
      hdmi_cec_io          : inout         std_logic;
      hdmi_hpd_io          : inout         std_logic;

      i2c_scl_io           : inout         std_logic;
      i2c_sda_io           : inout         std_logic;

      sd0_cs_o             : out           std_logic;
      sd0_miso_i           : in            std_logic;
      sd0_mosi_o           : out           std_logic;
      sd0_sclk_o           : out           std_logic;
      
      uart2_rx_i           : in            std_logic;
      uart2_tx_o           : out           std_logic

);
end entity;

architecture rtl of C60KFirstLight is

   attribute syn_keep : integer;

   -----------------------------------------------------------------------------
   -- component declarations
   -----------------------------------------------------------------------------
   component CLKDIV
   generic (
      DIV_MODE : string := "2";
      GSREN: in string := "false"
   );
   port (
      CLKOUT: out std_logic;
      HCLKIN: in std_logic;
      RESETN: in std_logic;
      CALIB: in std_logic
   );
   end component;

   COMPONENT OBUF
   PORT (
      O:OUT std_logic;
      I:IN std_logic
   );
   END COMPONENT;

   signal   i_JIM_page     : std_logic_vector(15 downto 0);
   signal   i_JIM_en       : std_logic;

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

   -- uart wrapper
   signal i_c2p_uart          : fb_con_o_per_i_t;
   signal i_p2c_uart          : fb_con_i_per_o_t;

   -- FPGA config flash
   signal i_c2p_xflash          : fb_con_o_per_i_t;
   signal i_p2c_xflash          : fb_con_i_per_o_t;

   -- null devices
   signal i_c2p_null          : fb_con_o_per_i_t;
   signal i_p2c_null          : fb_con_i_per_o_t;

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
	-- sound signals
	-----------------------------------------------------------------------------

	signal i_clk_snd						: std_logic := '0';					-- ~3.5MHz PAULA samplerate clock
	signal i_dac_snd_pwm					: std_logic;							-- pwm signal for sound channels
	-----------------------------------------------------------------------------
	-- HDMI stuff
	-----------------------------------------------------------------------------

	-- hdmi peripheral interface control registers
	signal i_c2p_hdmi_per				: fb_con_o_per_i_t;
	signal i_p2c_hdmi_per				: fb_con_i_per_o_t;

	signal i_vid_48_r                : std_logic_vector(3 downto 0);
	signal i_vid_48_g                : std_logic_vector(3 downto 0);
	signal i_vid_48_b                : std_logic_vector(3 downto 0);
	signal i_vid_48_hs               : std_logic;
	signal i_vid_48_vs               : std_logic;
	signal i_vid_48_blank			   : std_logic;
   signal r_vid_128_hs              : std_logic;
   signal r_vid_128_vs              : std_logic;

	signal i_mb_scroll_latch_c			: std_logic_vector(1 downto 0); -- scroll offset registers from port B latch

   -----------------------------------------------------------------------------
   -- peripherals
   -----------------------------------------------------------------------------
   
   constant C_BAUD_CKK16_DIV : positive := (CLOCKSPEED*1000000)/(16*BAUD);

   signal r_clken_baud16  : std_logic;
   signal r_clk_baud_div: unsigned(numbits(C_BAUD_CKK16_DIV-1) downto 0); -- note 1 bigger to catch carry out

   signal i_clk_pll_48M: std_logic;          -- used for HDMI / VIDEO pixels (12/24/16 MHz pixel clocks)
   attribute syn_keep of i_clk_pll_48M : signal is 1; -- keep for SDC
   signal i_clk_pll_128M: std_logic;         -- used for main logic/fishbone bus
   attribute syn_keep of i_clk_pll_128M : signal is 1; -- keep for SDC

   signal i_clk_pll_360M: std_logic;         -- used for video DACs
   attribute syn_keep of i_clk_pll_360M : signal is 1; -- keep for SDC
   signal i_clk_div_72M:  std_logic;         -- used for video DAC samples 
   attribute syn_keep of i_clk_div_72M : signal is 1; -- keep for SDC

   signal r_dac_sample     : signed(10 downto 0);
   signal i_paula_sample   : signed(9 downto 0) := (others => '0');

   -----------------------------------------------------------------------------
   -- 1 bit video clocks and chroma
   -----------------------------------------------------------------------------
   signal i_clk_chroma_x4_jitter : std_logic; -- Base PALx4 clock
   attribute syn_keep of i_clk_chroma_x4_jitter : signal is 1; -- keep for SDC
   signal i_chroma_s             : signed(4 downto 0);
   signal r2_vid_chroma          : unsigned(4 downto 0);

   signal i_vid_r_0  : std_logic;
   signal i_vid_g_0  : std_logic;
   signal i_vid_b_0  : std_logic;
   signal i_vid_chroma_0  : std_logic;

begin

   e_pll_50_48: entity work.pll_50_48
   port map (
      clkout0 => i_clk_pll_48M,
      clkin => sys_clk_50_i
   );

   e_pll_48_128: entity work.pll_48_128
   port map (
      clkout0 => i_clk_pll_128M,
      clkin => i_clk_pll_48M
   );

   e_fb_syscon: entity work.fb_syscon
   generic map (
      SIM => SIM,
      CLOCKSPEED => CLOCKSPEED
   )
   port map (
      fb_syscon_o                   => i_fb_syscon,

      EXT_nRESET_i                  => '1',                 -- disable keyboard reset, in case not built
      EXT_nRESET_power_i            => sup_nRST_i,

      clk_fish_i                    => i_clk_pll_128M,
      clk_lock_i                    => '1',
      sys_dll_lock_i                => '1'

   ); 

   -- address decode to select peripheral
   e_addr2s:entity work.address_decode_P20K
   generic map (
      SIM                     => SIM
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
   i_per_p2c_intcon(PERIPHERAL_NO_MEM_ROM)<= i_p2c_mem_rom;
   i_per_p2c_intcon(PERIPHERAL_NO_UART)   <= i_p2c_uart;
   i_per_p2c_intcon(PERIPHERAL_NO_XFLASH) <= i_p2c_xflash;
   i_per_p2c_intcon(PERIPHERAL_NO_NULL) <= i_p2c_null;

   i_p2c_cpu            <= i_con_p2c_intcon(MAS_NO_CPU);
   i_c2p_mem_rom        <= i_per_c2p_intcon(PERIPHERAL_NO_MEM_ROM);
   i_c2p_uart           <= i_per_c2p_intcon(PERIPHERAL_NO_UART);
   i_c2p_xflash         <= i_per_c2p_intcon(PERIPHERAL_NO_XFLASH);
   i_c2p_null           <= i_per_c2p_intcon(PERIPHERAL_NO_NULL);

   e_fb_mem_rom: entity work.fb_P20K_mem
   generic map (
      G_ADDR_W => 12,   -- 4K
      G_READONLY => true,
      INIT_FILE => PROJECT_ROOT_PATH & G_OSROM
      )
   port map (
      -- fishbone signals

      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_i                      => i_c2p_mem_rom,
      fb_p2c_o                      => i_p2c_mem_rom

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
      JIM_page_i                    => i_JIM_page,
      JIM_en_i                      => i_JIM_en      

   );


   -------------------------------------
   -- FPGA CONFIG FLASH
   -------------------------------------


   e_fb_xflash:entity work.fb_spi
   generic map (
      SIM                           => SIM,
      CLOCKSPEED                    => CLOCKSPEED,
      PRESCALE                      => 1
   )
   port map (

      -- eeprom signals
      SPI_CS_o(0)                   => flash_cs_o,
      SPI_CLK_o                     => flash_ck_o,
      SPI_MOSI_o                    => flash_mosi_o,
      SPI_MISO_i                    => flash_miso_i,
      SPI_DET_i                     => '1',

      -- fishbone signals

      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_i                      => i_c2p_xflash,
      fb_p2c_o                      => i_p2c_xflash
   );


p_reg_128:process(i_fb_syscon)
begin
   if rising_edge(i_fb_syscon.clk) then
      r_vid_128_hs <= i_vid_48_hs;
      r_vid_128_vs <= i_vid_48_vs;
   end if;
end process;

--====================================================
-- N U L L   D E V I C E
--====================================================

   e_fb_null:entity work.fb_null
   port map (
      -- fishbone signals

      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_i                      => i_c2p_null,
      fb_p2c_o                      => i_p2c_null
   );



--====================================================
-- H D M I
--====================================================

G_HDMI:IF G_INCL_HDMI GENERATE
	i_per_p2c_intcon(PERIPHERAL_NO_HDMI)		<= i_p2c_hdmi_per;
	i_c2p_hdmi_per			<= i_per_c2p_intcon(PERIPHERAL_NO_HDMI);

--   i_mb_scroll_latch_c <= i_beeb_ic32(5 downto 4);

   i_mb_scroll_latch_c <= "11";

	e_fb_HDMI:fb_HDMI
	generic map (
		SIM => SIM,
		CLOCKSPEED => CLOCKSPEED
	)
	port map (
		CLK_48M_i			=> i_clk_pll_48M,

		fb_syscon_i			=> i_fb_syscon,
		fb_c2p_i				=> i_c2p_hdmi_per,
		fb_p2c_o				=> i_p2c_hdmi_per,

		HDMI_SCL_io			=> edid_scl_io,
		HDMI_SDA_io			=> edid_sda_io,
		HDMI_HPD_i			=> HDMI_HPD_io,
		HDMI_CK_o			=> tmds_clk_o_p,
		HDMI_B_o				=> tmds_d_o_p(0),
		HDMI_G_o				=> tmds_d_o_p(1),
		HDMI_R_o				=> tmds_d_o_p(2),

		-- analogue video	straight from CRTC/ULA

		VGA_R_o				=> i_vid_48_r,
		VGA_G_o				=> i_vid_48_g,
		VGA_B_o				=> i_vid_48_b,
		VGA_HS_o				=> i_vid_48_hs,
		VGA_VS_o				=> i_vid_48_vs,
		VGA_BLANK_o			=> i_vid_48_blank,

		-- analogue video	retimed to 27 MHz DVI clock

		VGA27_R_o				=> open,
		VGA27_G_o				=> open,
		VGA27_B_o				=> open,
		VGA27_HS_o				=> open,
		VGA27_VS_o				=> open,
		VGA27_BLANK_o			=> open,

		scroll_latch_c_i		=> i_mb_scroll_latch_c,

		PCM_L_i				=> r_dac_sample & "00000",
      PCM_R_i           => r_dac_sample & "00000"
	);
END GENERATE;


      i2c_scl_io           <= '1';
      i2c_sda_io           <= 'Z';

      sd0_cs_o             <= '0';
      sd0_mosi_o           <= '0';
      sd0_sclk_o           <= '0';
                           
end architecture rtl;
      
      

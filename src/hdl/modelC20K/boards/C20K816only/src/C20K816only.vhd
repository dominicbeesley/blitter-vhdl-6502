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
-- Module Name:      C20K816only
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      Top level module for C20K test system using 65816 as main CPU
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
use work.fb_SYS_pack.all;
use work.fb_CPU_pack.all;
use work.fb_chipset_pack.all;
use work.fb_intcon_pack.all;
use work.ws2812_pack.all;

entity C20K816only is
   generic (
      SIM                           : boolean := false;                    -- skip some stuff, i.e. slow sdram start up
      CLOCKSPEED                    : natural := 128;                      -- fast clock speed in mhz          
      BAUD                          : natural := 19200
   );
   port (

      brd_clk_27M_i        : in            std_logic;

      sup_nRST_i           : in            std_logic;

      clk_ext_pal_i        : in            std_logic;


--TODO: clash with OSER10's on video
--      ddr_addr_o           : out           std_logic_vector(13 downto 0);
      ddr_bank_o           : out           std_logic_vector(2 downto 0);
      ddr_cas_o            : out           std_logic;
      ddr_ck_o             : out           std_logic;
      ddr_cke_o            : out           std_logic;
      ddr_cs_o             : out           std_logic;
      ddr_dm_io            : inout         std_logic_vector(1 downto 0);
      ddr_dq_io            : inout         std_logic_vector(15 downto 0);
      ddr_dqs_io           : inout         std_logic_vector(1 downto 0);
      ddr_odt_o            : out           std_logic;
      ddr_ras_o            : out           std_logic;
      ddr_reset_n_o        : out           std_logic;
      ddr_we_o             : out           std_logic;

      mem_A_io             : inout         std_logic_vector(20 downto 0); -- note: inout as can be to RAM or from CPU
      mem_D_io             : inout         std_logic_vector(7 downto 0);
      mem_RAM_nCE_o        : out           std_logic_vector(3 downto 0);
      mem_ROM_nCE_o        : out           std_logic;
      mem_nOE_o            : out           std_logic;
      mem_nWE_o            : out           std_logic;

      cpu_A_nOE_o          : out           std_logic;
      cpu_BE_o             : out           std_logic;
      cpu_E_i              : in            std_logic;
      cpu_MX_i             : in            std_logic;
      cpu_PHI2_o           : out           std_logic;
      cpu_RDY_io           : out           std_logic;
      cpu_nABORT_o         : out           std_logic;
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
      edid_scl_io          : inout         std_logic;
      edid_sda_io          : inout         std_logic;
      hdmi_cec_io          : inout         std_logic;
      hdmi_hpd_io          : inout         std_logic;

      vid_b_o              : out           std_logic;
      vid_chroma_o         : out           std_logic;
      vid_g_o              : out           std_logic;
      vid_r_o              : out           std_logic;

      i2c_scl_io           : inout         std_logic;
      i2c_sda_io           : inout         std_logic;

      mux_D_nOE_o          : out           std_logic;
      mux_i0_nOE_o         : out           std_logic;
      mux_i1_nOE_o         : out           std_logic;
      mux_io               : inout         std_logic_vector(7 downto 0);
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

architecture rtl of C20K816only is

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

   -----------------------------------------------------------------------------
	-- config signals
	-----------------------------------------------------------------------------

	signal r_cfg_swram_enable	: std_logic;
   signal r_cfg_sys_type      : sys_type;
	signal r_cfg_swromx			: std_logic;
	signal r_cfg_mosram			: std_logic;

	signal r_cfg_do6502_debug	: std_logic;							-- enable 6502 extensions for NoIce debugger
	signal r_cfg_mk2_cpubits	: std_logic_vector(2 downto 0);	-- config bits as presented in memctl register to utils rom TODO: change this!
	signal r_cfg_cpu_type		: cpu_type;								-- hard cpu type
	signal r_cfg_cpu_use_t65	: std_logic;							-- if '1' boot to T65
	signal r_cfg_cpu_speed_opt : cpu_speed_opt;						-- hard cpu dependent speed/option

	-- the following registers contain the boot configuration fed to FC 0104..FC 0108
	signal r_cfg_ver_boot		: std_logic_vector(31 downto 0);

   -----------------------------------------------------------------------------
   -- fishbone signals
   -----------------------------------------------------------------------------

   signal i_fb_syscon         : fb_syscon_t;                   -- shared bus signals

   -- cpu wrapper
   signal i_c2p_cpu           : fb_con_o_per_i_t;
   signal i_p2c_cpu           : fb_con_i_per_o_t;

	-- cpu beeb motherboard wrapper
   signal i_c2p_sys               : fb_con_o_per_i_t;
   signal i_p2c_sys               : fb_con_i_per_o_t;

	-- blitter board RAM/ROM memory wrapper
	signal i_c2p_mem				: fb_con_o_per_i_t;
	signal i_p2c_mem				: fb_con_i_per_o_t;

	-- memory control registers wrapper
	signal i_c2p_memctl			: fb_con_o_per_i_t;
	signal i_p2c_memctl			: fb_con_i_per_o_t;

	-- version info wrapper
	signal i_c2p_version			: fb_con_o_per_i_t;
	signal i_p2c_version			: fb_con_i_per_o_t;

	--chipset peripheral
	signal i_c2p_chipset_per	: fb_con_o_per_i_t;
	signal i_p2c_chipset_per	: fb_con_i_per_o_t;

	-- chipset controller
	signal i_c2p_chipset_con	: fb_con_o_per_i_t;
	signal i_p2c_chipset_con	: fb_con_i_per_o_t;

   -- intcon controller->peripheral
   signal i_con_c2p_intcon    : fb_con_o_per_i_arr(CONTROLLER_COUNT-1 downto 0);
   signal i_con_p2c_intcon    : fb_con_i_per_o_arr(CONTROLLER_COUNT-1 downto 0);
   -- intcon peripheral->controller
   signal i_per_c2p_intcon    : fb_con_o_per_i_arr(PERIPHERAL_COUNT-1 downto 0);
   signal i_per_p2c_intcon    : fb_con_i_per_o_arr(PERIPHERAL_COUNT-1 downto 0);

	-----------------------------------------------------------------------------
	-- inter component (non-fishbone) signals
	-----------------------------------------------------------------------------

	signal i_JIM_en						: std_logic;							-- local jim device enable
	signal i_JIM_page						: std_logic_vector(15 downto 0);	-- the actual mapping is done in the cpu component address
																							-- translator (and is not available to the rest of the 
																							-- chipset)

	signal i_sys_ROMPG					: std_logic_vector(7 downto 0);	-- a shadow copy of the mainboard rom
																							-- paging register, used to select
																							-- on board paged roms from flash/sram

	signal i_turbo_lo_mask				: std_logic_vector(7 downto 0);	-- which blocks of 16 pages to run at full speed

	signal i_swmos_shadow				: std_logic;							-- shadow mos from SWRAM slot #8	

	signal i_flasher						: std_logic_vector(3 downto 0);	-- a simple set of slow clocks for generating flashing 
																							-- LED sfishals
	signal i_clk_fish_128M				: std_logic;							-- the main system clock from the pll - don't use this
																							-- use fb_syscon.clk
	signal i_clk_lock						: std_logic;							-- indicates whether the main pll is locked
	signal i_sys_dll_lock				: std_logic;							-- indicates whether the system dll is locked

	signal i_memctl_configbits			: std_logic_vector(15 downto 0);

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
	-- cpu control signals
	-----------------------------------------------------------------------------
	signal i_chipset_cpu_halt			: std_logic; -- TODO: ignored
	signal i_chipset_cpu_int			: std_logic; -- TODO: ignored

	signal i_boot_65816					: std_logic_vector(1 downto 0);
   signal i_window_65816            : std_logic_vector(12 downto 0);
   signal i_window_65816_wr_en      : std_logic;

	signal i_throttle_cpu_2MHz			: std_logic;

	signal i_cpu_2MHz_phi2_clken		: std_logic;

	signal i_rom_throttle_map			: std_logic_vector(15 downto 0);
	signal i_rom_autohazel_map			: std_logic_vector(15 downto 0);
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


   -- multiplex in to core, out from peripheral (I0 phase)   
   signal icipo_kb_nRST    : std_logic;
   signal i_sys_nIRQ        : std_logic;
   signal i_sys_nNMI        : std_logic;

   -- multiplex in to core, out from peripheral (I1 phase)   
   signal icipo_j_i0       : std_logic;
   signal icipo_j_i1       : std_logic;
   signal icipo_j_spi_miso : std_logic;
   signal icipo_btn0       : std_logic;
   signal icipo_btn1       : std_logic;
   signal icipo_btn2       : std_logic;
   signal icipo_btn3       : std_logic;


   -- multiplex out from core, in to peripheral (O0 phase)   
   signal icopi_j_ds_nCS2  : std_logic;
   signal icopi_j_ds_nCS1  : std_logic;
   signal icopi_j_spi_clk  : std_logic;
   signal icopi_j_spi_mosi : std_logic;
   signal icopi_j_adc_nCS  : std_logic;

   -- emulated / synthesized beeb signals
   signal i_beeb_ic32      : std_logic_vector(7 downto 0);
   signal i_c20k_latch     : std_logic_vector(7 downto 0);
   signal i_psg_audio      : signed(13 downto 0);
   signal r_dac_sample     : signed(10 downto 0);
   signal i_paula_sample   : signed(9 downto 0);

   -- debug
   signal i_debug_leds     : ws2812_colour_arr_t(0 to 7);
   signal i_debug_cpu_instr_a : std_logic_vector(23 downto 0);

   -----------------------------------------------------------------------------
   -- 1 bit video clocks and chroma
   -----------------------------------------------------------------------------
   signal i_clk_chroma_x4_jitter : std_logic; -- Base PALx4 clock
--   signal i_clk_chroma_x4        : std_logic;
--   signal i_clk_chroma_x60_dac   : std_logic;
--   signal i_clk_chroma_x12_px    : std_logic;
--   signal i_clk_chroma_x20_dac   : std_logic;
   signal i_chroma_s             : signed(4 downto 0);
   signal r2_vid_chroma          : unsigned(4 downto 0);

   signal i_vid_r_0  : std_logic;
   signal i_vid_g_0  : std_logic;
   signal i_vid_b_0  : std_logic;
   signal i_vid_chroma_0  : std_logic;

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

      EXT_nRESET_i                  => icipo_kb_nRST,
      EXT_nRESET_power_i            => sup_nRST_i,

      clk_fish_i                    => i_clk_pll_128M,
      clk_lock_i                    => '1',
      sys_dll_lock_i                => '1'

   ); 

g_addr_decode:for I in CONTROLLER_COUNT-1 downto 0 generate
   -- address decode to select peripheral
   e_addr2s:entity work.address_decode
   generic map (
      SIM                     => SIM,
      G_PERIPHERAL_COUNT      => PERIPHERAL_COUNT,
      G_INCL_CHIPSET		      => G_INCL_CHIPSET,
		G_INCL_HDMI					=> G_INCL_HDMI,
		G_HDMI_SHADOW_SYS			=> G_HDMI_SHADOW_SYS,
      G_C20K                  => true
	)
	port map (
		addr_i						=> i_intcon_peripheral_sel_addr(I),
		peripheral_sel_o			=> i_intcon_peripheral_sel(I),
		peripheral_sel_oh_o		=> i_intcon_peripheral_sel_oh(I)
	);
end generate;

g_intcon_shared:IF CONTROLLER_COUNT > 1 GENERATE
	e_fb_intcon: fb_intcon_shared
	generic map (
		SIM => SIM,
		G_CONTROLLER_COUNT => CONTROLLER_COUNT,
		G_PERIPHERAL_COUNT => PERIPHERAL_COUNT,
		G_REGISTER_CONTROLLER_P2C => true,
      G_REGISTER_PERIPHERAL_C2P => false
		)
   port map (
		fb_syscon_i 		=> i_fb_syscon,

		-- peripheral ports connect to controllers
		fb_con_c2p_i						=> i_con_c2p_intcon,
		fb_con_p2c_o						=> i_con_p2c_intcon,

		-- controller ports connect to peripherals
		fb_per_c2p_o						=> i_per_c2p_intcon,
		fb_per_p2c_i						=> i_per_p2c_intcon,

		peripheral_sel_addr_o					=> i_intcon_peripheral_sel_addr,
		peripheral_sel_i							=> i_intcon_peripheral_sel,
		peripheral_sel_oh_i						=> i_intcon_peripheral_sel_oh
   );


END GENERATE;
g_intcon_o2m:IF CONTROLLER_COUNT = 1 GENERATE
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


END GENERATE;   

	i_con_c2p_intcon(MAS_NO_CPU)           <= i_c2p_cpu;
	i_per_p2c_intcon(PERIPHERAL_NO_MEMCTL)	<=	i_p2c_memctl;
	i_per_p2c_intcon(PERIPHERAL_NO_CHIPRAM)	<=	i_p2c_mem;
   i_per_p2c_intcon(PERIPHERAL_NO_SYS)    <= i_p2c_sys;
	i_per_p2c_intcon(PERIPHERAL_NO_VERSION)	<= i_p2c_version;

   i_p2c_cpu            <= i_con_p2c_intcon(MAS_NO_CPU);
	i_c2p_memctl			<= i_per_c2p_intcon(PERIPHERAL_NO_MEMCTL);
	i_c2p_mem				<= i_per_c2p_intcon(PERIPHERAL_NO_CHIPRAM);
   i_c2p_sys            <= i_per_c2p_intcon(PERIPHERAL_NO_SYS);
	i_c2p_version			<= i_per_c2p_intcon(PERIPHERAL_NO_VERSION);




GCHIPSET: IF G_INCL_CHIPSET GENERATE
--TODO:NO MASTERS	i_con_c2p_intcon(MAS_NO_CHIPSET)				<= i_c2p_chipset_con;
--TODO:NO MASTERS   i_p2c_chipset_con    <= i_con_p2c_intcon(MAS_NO_CHIPSET);


	i_per_p2c_intcon(PERIPHERAL_NO_CHIPSET)	<= i_p2c_chipset_per;
	i_c2p_chipset_per		<= i_per_c2p_intcon(PERIPHERAL_NO_CHIPSET);

	e_chipset:fb_chipset
	generic map (
		SIM => SIM,
		CLOCKSPEED => CLOCKSPEED
	)
	port map (
		fb_syscon_i		=> i_fb_syscon,

		-- peripheral port connect to controllers
		fb_per_c2p_i 	=> i_c2p_chipset_per,
		fb_per_p2c_o 	=> i_p2c_chipset_per,

		-- controller port connecto to peripherals
		fb_con_c2p_o	=> i_c2p_chipset_con,
		fb_con_p2c_i	=> i_p2c_chipset_con,

		clk_snd_i		=> i_clk_snd,

		cpu_halt_o		=> i_chipset_cpu_halt,
		cpu_int_o		=> i_chipset_cpu_int,

		vsync_i			=> not i_vid_48_vs,
		hsync_i			=> not i_vid_48_hs,

		I2C_SDA_io		=> I2C_SDA_io,
		I2C_SCL_io		=> I2C_SCL_io,

		snd_dat_o		=> i_paula_sample,
		snd_dat_change_clken_o => open,

      SD_CS_o              => sd0_cs_o,
      SD_CLK_o             => sd0_sclk_o,
      SD_MOSI_o            => sd0_mosi_o,
      SD_MISO_i            => sd0_miso_i,
      SD_DET_i             => '1'

	);


END GENERATE;
GNOTCHIPSET:IF NOT G_INCL_CHIPSET GENERATE
	i_chipset_cpu_halt <= '0';
	i_chipset_cpu_int <= '0';
	i_paula_sample <= (others => '0');
	I2C_SDA_io <= 'Z';
	I2C_SCL_io <= 'Z';
END GENERATE;


   G_SND_1BIT:if not G_C20K_I2S generate
      --NOTE: we do DAC stuff at top level as blitter/1MPaula do this differently
      
   p_reg_snd:process(i_fb_syscon)
   begin 
      if rising_edge(i_fb_syscon.clk) then
         r_dac_sample <= resize(i_paula_sample, 11) + resize(i_psg_audio(i_psg_audio'high downto i_psg_audio'high-9), 11);
      end if;
   end process;


   --NOTE: we do DAC stuff at top level as blitter/1MPaula do this differently

  e_dac_snd: entity work.dac_1bit 
  generic map (
     G_SAMPLE_SIZE     => 11,
     G_SYNC_DEPTH      => 0
  )
  port map (
     rst_i             => i_fb_syscon.rst,
     clk_dac           => i_fb_syscon.clk,

     sample            => r_dac_sample,
  
     bitstream         => i_dac_snd_pwm
  );


	aud_i2s_ws_pwm_R_o <= i_dac_snd_pwm;
	aud_i2s_bck_pwm_L_o <= i_dac_snd_pwm;
      aud_i2s_dat_o        <= '1';

   end generate;

   G_SND_i2s:if G_C20K_I2S generate
      p_reg_snd:process(i_clk_snd)
      begin 
         if rising_edge(i_clk_snd) then
            r_dac_sample <= resize(i_paula_sample, 11) + resize(i_psg_audio(i_psg_audio'high downto i_psg_audio'high-9), 11);
         end if;
      end process;

      e_i2s:entity work.i2s
      port map (
         
         clk_i => i_clk_snd,
         rst_i => i_fb_syscon.rst,
         pwm_l_i => r_dac_sample & "00000",
         pwm_r_i => r_dac_sample & "00000",

         bck_o => aud_i2s_bck_pwm_L_o,
         ws_o  => aud_i2s_ws_pwm_R_o,
         dat_o => aud_i2s_dat_o

      );

   end generate;



	e_fb_version:entity work.fb_version
	port map (
		-- fishbone signals

		fb_syscon_i							=> i_fb_syscon,
		fb_c2p_i								=> i_c2p_version,
		fb_p2c_o								=> i_p2c_version,

		cfg_bits_i							=> r_cfg_ver_boot

	);


	e_memctl:entity work.fb_memctl 
	generic map (
		SIM									=> SIM
	)
	port map (

		-- configuration
		do6502_debug_i						=> r_cfg_do6502_debug,
		turbo_lo_mask_o					=> i_turbo_lo_mask,
		swmos_shadow_o						=> i_swmos_shadow,
		cfgbits_i							=> i_memctl_configbits,

		-- noice debugger signals to cpu
		noice_debug_nmi_n_o				=> open,
		noice_debug_shadow_o				=> open,
		noice_debug_inhibit_cpu_o		=> open,
		-- noice debugger signals from cpu
		noice_debug_5c_i					=> '0',
		noice_debug_cpu_clken_i			=> '0',
		noice_debug_A0_tgl_i				=> '0',
		noice_debug_opfetch_i			=> '0',

		-- noice debugger button		
		noice_debug_button_i				=> '0',

		-- cpu throttle

		throttle_cpu_2MHz_o 				=> i_throttle_cpu_2MHz,

		-- fishbone signals

		fb_syscon_i							=> i_fb_syscon,
		fb_c2p_i								=> i_c2p_memctl,
		fb_p2c_o								=> i_p2c_memctl,

		-- cpu specific

		boot_65816_o						=> i_boot_65816,
      window_65816_o                => i_window_65816,
      window_65816_wr_en_o          => i_window_65816_wr_en,

		rom_throttle_map_o				=> i_rom_throttle_map,
		rom_autohazel_map_o				=> i_rom_autohazel_map
	);


--	e_fb_mem: entity work.fb_mem
--	generic map (
--		G_SWRAM_SLOT						=> G_MEM_SWRAM_SLOT,
--		G_FAST_IS_10						=> G_MEM_FAST_IS_10,
--		G_SLOW_IS_45						=> G_MEM_SLOW_IS_45
--	)
--	port map (
--			-- 2M RAM/256K ROM bus
--		MEM_A_o								=> mem_A_io,
--		MEM_D_io								=> MEM_D_io,
--		MEM_nOE_o							=> MEM_nOE_o,
--		MEM_nWE_o							=> MEM_nWE_o,
--		MEM_ROM_nCE_o						=> MEM_ROM_nCE_o,
--		MEM_RAM_nCE_o						=> MEM_RAM_nCE_o,
--
--		-- fishbone signals
--
--		fb_syscon_i							=> i_fb_syscon,
--		fb_c2p_i								=> i_c2p_mem,
--		fb_p2c_o								=> i_p2c_mem,
--
--		debug_mem_a_stb_o					=> open
--	);

   e_fb_sys:entity work.fb_SYS_c20k
   generic map (
      SIM                           => SIM,
      CLOCKSPEED                    => CLOCKSPEED,
      G_JIM_DEVNO                   => G_JIM_DEVNO
   )
   port map (
      cfg_sys_type_i                => r_cfg_sys_type,

      -- fishbone signals

      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_i                      => i_c2p_sys,
      fb_p2c_o                      => i_p2c_sys,

      -- mux clock outputs
      mux_mhz1E_clk_o               => p_1MHZ_E_o,
      mux_mhz2E_clk_o               => p_2MHZ_E_o,

      mhz8_fdc_clk_o                => p_8MHZ_FDC_o,


      -- mux control outputs
      mux_nALE_o                    => mux_nALE_o,
      mux_D_nOE_o                   => mux_D_nOE_o,
      mux_I0_nOE_o                  => mux_I0_nOE_o,
      mux_I1_nOE_o                  => mux_I1_nOE_o,
      mux_O0_nOE_o                  => mux_O0_nOE_o,
      mux_O1_nOE_o                  => mux_O1_nOE_o,

      -- mux multiplexed signals bus
      mux_bus_io                    => mux_io,


      -- memory registers managed in here
      jim_en_o                      => i_JIM_en,
      jim_page_o                    => i_JIM_page,
		sys_ROMPG_o							=> i_sys_ROMPG,

      -- cpu sync 
      cpu_2MHz_phi2_clken_o         => i_cpu_2MHz_phi2_clken,

      -- combined signals
      sys_nIRQ_o                    => i_sys_nIRQ,
      sys_nNMI_o                    => i_sys_nNMI,

      -- random other multiplexed pins out to FPGA (I0 phase)
      p_kb_nRST_o                   => icipo_kb_nRST,

      -- random other multiplexed pins out to FPGA (I1 phase)
      p_j_i0_o                      => icipo_j_i0,
      p_j_i1_o                      => icipo_j_i1,
      p_j_spi_miso_o                => icipo_j_spi_miso,
      p_btn0_o                      => icipo_btn0,
      p_btn1_o                      => icipo_btn1,
      p_btn2_o                      => icipo_btn2,
      p_btn3_o                      => icipo_btn3,


      -- random other multiplexed pins in from FPGA (O1 phase)
      p_j_ds_nCS2_i                 => icopi_j_ds_nCS2,
      p_j_ds_nCS1_i                 => icopi_j_ds_nCS1,
      p_j_spi_clk_i                 => icopi_j_spi_clk,
      p_VID_HS_i                    => r_vid_128_hs,
      p_VID_VS_i                    => r_vid_128_vs,
      p_j_spi_mosi_i                => icopi_j_spi_mosi,
      p_j_adc_nCS_i                 => icopi_j_adc_nCS,

      -- other inputs to FPGA
      lpstb_i                       => pj_LPSTB_i,

      -- emulated / synthesized beeb signals
      beeb_ic32_o                   => i_beeb_ic32,
      c20k_latch_o                  => i_c20k_latch,
      psg_audio_o                   => i_psg_audio,

      p_d_cas_o                     => cassette_o
   );
   

p_reg_128:process(i_fb_syscon)
begin
   if rising_edge(i_fb_syscon.clk) then
      r_vid_128_hs <= i_vid_48_hs;
      r_vid_128_vs <= i_vid_48_vs;
   end if;
end process;


   e_mem_cpu_65816: entity work.fb_C20K_mem_cpu_65816
   generic map (
      SIM => SIM,
      CLOCKSPEED => CLOCKSPEED * 1000000,
      CPU_SPEED => 8000000
   )
   port map (

		-- configuration

--		cfg_cpu_type_i						=> r_cfg_cpu_type,
--		cfg_cpu_use_t65_i					=> r_cfg_cpu_use_t65,
--		cfg_cpu_speed_opt_i				=> r_cfg_cpu_speed_opt,
     	cfg_sys_type_i                => r_cfg_sys_type,      
		cfg_swram_enable_i				=> r_cfg_swram_enable,
		cfg_swromx_i						=> r_cfg_swromx,
		cfg_mosram_i						=> r_cfg_mosram,

		-- cpu throttle

		throttle_cpu_2MHz_i 				=> i_throttle_cpu_2MHz,
		cpu_2MHz_phi2_clken_i			=> i_cpu_2MHz_phi2_clken,
		rom_throttle_map_i				=> i_rom_throttle_map,
		rom_autohazel_map_i				=> i_rom_autohazel_map,

      -- memctl signals
      swmos_shadow_i                => i_swmos_shadow,

      -- logical mappings
		sys_ROMPG_i 						=> i_sys_ROMPG,	
		turbo_lo_mask_i					=> i_turbo_lo_mask,
      JIM_en_i                      => i_JIM_en,      
      JIM_page_i                    => i_JIM_page,

      -- direct CPU control signals from system
      nmi_n_i                       => i_sys_nNMI,
      irq_n_i                       => i_sys_nIRQ,
      debug_btn_n_i                 => icipo_btn1,
      cpu_halt_i                    => '0',

      noice_debug_shadow_i          => '0',     --TODO: reinstate?

      boot_65816_i                  => i_boot_65816,
      window_65816_i                => i_window_65816,
      window_65816_wr_en_i          => i_window_65816_wr_en,

      -- fishbone signals
      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_o                      => i_c2p_cpu,
      fb_p2c_i                      => i_p2c_cpu,

      -- debug
      debug_cpu_instr_A             => i_debug_cpu_instr_a,

      -- memory motherboard signals
      MEM_A_io                      => MEM_A_io,
      MEM_D_io                      => MEM_D_io,
      MEM_RAM_nCE_o                 => MEM_RAM_nCE_o,
      MEM_ROM_nCE_o                 => MEM_ROM_nCE_o,
      MEM_nOE_o                     => MEM_nOE_o,
      MEM_nWE_o                     => MEM_nWE_o,

      -- cpu motherboard signals
      CPU_A_nOE_o                   => CPU_A_nOE_o,
      CPU_PHI2_o                    => CPU_PHI2_o,
      CPU_BE_o                      => CPU_BE_o,
      CPU_RDY_io                    => CPU_RDY_io,
      CPU_nRES_o                    => CPU_nRES_o,
      CPU_nIRQ_o                    => CPU_nIRQ_o,
      CPU_nNMI_o                    => CPU_nNMI_o,
      CPU_nABORT_o                  => CPU_nABORT_o,
      CPU_MX_i                      => CPU_MX_i,
      CPU_E_i                       => CPU_E_i



   );



   -------------------------------------
   -- DEBUG LEDS
   -------------------------------------
   --G_DBG_LED_I:FOR I in 0 to 7 generate
   --
   --   i_debug_leds(I).red <= (0 => i_c20k_latch(I), others => '0');
   --   i_debug_leds(I).blue <= (0 => '1', others => '0');
   --   i_debug_leds(I).green <= (0 => i_beeb_ic32(I), others => '0');
   --END GENERATE;

   p_leds:process(i_fb_syscon)
   variable i : integer;
   variable vr_btn : unsigned(7 downto 0);
   begin
      if rising_edge(i_fb_syscon.clk) then
         if i_fb_syscon.rst = '1' then
            for i in 0 to 7 loop
               if i < 4 then
                  i_debug_leds(I).red <= (0 =>  i_fb_syscon.prerun(i), others => '0');
               else
                  i_debug_leds(I).red <= (others => '0');
               end if;
               if i = fb_rst_state_t'pos(i_fb_syscon.rst_state) then
                  i_debug_leds(I).green <= (0 => '1', others => '0');
               else
                  i_debug_leds(I).green <= (0 => '0', others => '0');
               end if;
               i_debug_leds(I).blue <= (others => '0');         
            end loop;
            vr_btn := (others => '0');
         elsif i_c2p_cpu.A_stb = '1' and i_c2p_cpu.cyc = '1' and vr_btn(vr_btn'high) = '1' then
            for i in 0 to 7 loop
               i_debug_leds(I).red <= (0 => i_debug_cpu_instr_a(I), others => '0');
               i_debug_leds(I).green <= (0 => i_debug_cpu_instr_a(I + 8), others => '0');
               i_debug_leds(I).blue <= (0 => i_debug_cpu_instr_a(I + 16), others => '0');
            end loop;
         end if;

         if icipo_btn2 = '0' then
            vr_btn := (others => '0');
         elsif vr_btn(vr_btn'high) = '0' then
            vr_btn := vr_btn + 1;
         end if;
      end if;

   end process;

   e_dbg_led:entity work.ws2812
   generic map (
      G_CLOCKSPEED                    => CLOCKSPEED * 1000000,
      G_N_CHAIN                       => 8
   )
   port map (
      rst_i                   => '0',
      clk_i                   => i_fb_syscon.clk,
      rgb_arr_i               => i_debug_leds,
      led_serial_o            => ui_leds_o

   );


p_boot_mosram:process(i_fb_syscon)
begin
   if rising_edge(i_fb_syscon.clk) then
      if i_fb_syscon.rst = '1' then
         r_cfg_mosram <= not icipo_btn0;
      end if;
   end if;
end process;

                     
r_cfg_cpu_use_t65 <= '0';
r_cfg_swromx <= '0';
r_cfg_swram_enable <= '1';
r_cfg_sys_type <= SYS_BBC;
r_cfg_do6502_debug <= '1'; 
r_cfg_cpu_type <= CPU_65816;
r_cfg_cpu_speed_opt <= NONE;
r_cfg_mk2_cpubits <= "001";   --TODO: check!

-- synthesize from above
p_cfgboot:process(i_fb_syscon)
begin
   if rising_edge(i_fb_syscon.clk) then
      if i_fb_syscon.rst = '1' then
         r_cfg_ver_boot <= (others => '1');
         r_cfg_ver_boot(15 downto 9) <= "1100101"; -- CPU=65816
         r_cfg_ver_boot(3) <= not r_cfg_cpu_use_t65;
         r_cfg_ver_boot(4) <= not r_cfg_swromx;
         r_cfg_ver_boot(5) <= not r_cfg_mosram;
         r_cfg_ver_boot(6) <= r_cfg_swram_enable;
      end if;
   end if;
end process;



--TODO: MK2/MK3 harmonize
i_memctl_configbits <= 
	"1111111" &
	r_cfg_swram_enable &
	"111" &
	r_cfg_swromx &
	r_cfg_mk2_cpubits &
	not r_cfg_cpu_use_t65;

--====================================================
-- H D M I
--====================================================

G_HDMI:IF G_INCL_HDMI GENERATE
	i_per_p2c_intcon(PERIPHERAL_NO_HDMI)		<= i_p2c_hdmi_per;
	i_c2p_hdmi_per			<= i_per_c2p_intcon(PERIPHERAL_NO_HDMI);

   i_mb_scroll_latch_c <= i_beeb_ic32(5 downto 4);

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
		VGA27_HS_o				=> sd1_cs_o,
		VGA27_VS_o				=> sd1_sclk_o,
		VGA27_BLANK_o			=> sd1_mosi_o,

		scroll_latch_c_i		=> i_mb_scroll_latch_c,

		PCM_L_i				=> r_dac_sample & "00000",
      PCM_R_i           => r_dac_sample & "00000"
	);
END GENERATE;

--TODO: clash with OSER10's on video
--      ddr_addr_o           <= (others => '1');
      ddr_bank_o           <= (others => '1');
      ddr_cas_o            <= '1';
      ddr_ck_o             <= '1';
      ddr_cke_o            <= '0';
      ddr_cs_o             <= '1';
      ddr_odt_o            <= '1';
      ddr_ras_o            <= '1';
      ddr_reset_n_o        <= '0';
      ddr_we_o             <= '0';
      ddr_dq_io            <= (others => 'Z');
      ddr_dqs_io           <= (others => 'Z');
      ddr_dm_io            <= (others => 'Z');


      flash_ck_o           <= '1';
      flash_cs_o           <= '1';
      flash_mosi_o         <= '1';


      
-- hdmi debug --      sd1_cs_o             <= '0';
-- hdmi debug --      sd1_mosi_o           <= '0';
-- hdmi debug --      sd1_sclk_o           <= '0';




e_null_brd_mem:entity work.fb_null
   port map (

      fb_syscon_i          => i_fb_syscon,

      fb_c2p_i             => i_c2p_mem,
      fb_p2c_o             => i_p2c_mem
   );


G_DO1BIT_DAC_VIDEO:if G_1BIT_DAC_VIDEO generate
   --------------------------------------------------------
   -- 1 bit video
   --------------------------------------------------------
    
   -- the 1 bit DACs run at 360MHz pwm, there are three sub-pixels for each 72MHz sample

   -- TODO: this is frigged together - we need another pll to (re)generate chroma clocks

   e_pll2: entity work.pll_rgb_dac
   port map (
      clkout      => i_clk_pll_360M,
      clkin       => i_clk_pll_48M
   );

   clkdiv5 : CLKDIV
   generic map (
      DIV_MODE => "5",            -- Divide by 5
      GSREN => "false"
   )
   port map (
      RESETN => '1',
      HCLKIN => i_clk_pll_360M,
      CLKOUT => i_clk_div_72M,
      CALIB  => '1'
   );

   
---   -- generate a slightly jittery 17.7MHz sub-carrier, we'll pass this through a PLL to smooth it out a bit
---   p_car_gen:process(i_clk_pll_48M)
---      constant div : natural := 709379;
---      constant num : natural := 1920000;    -- PAL * 4 with 25Hz offset (17.734475)
---      variable r_acc : unsigned(numbits(num) downto 0) := (others => '0');
---   begin
---      if rising_edge(i_clk_pll_48M) then
---         r_acc := r_acc + div;
---         if r_acc >= num then
---            r_acc := r_acc - num;
---            i_clk_chroma_x4_jitter <= '1';
---         else
---            i_clk_chroma_x4_jitter <= '0';
---         end if;
---      end if;
---   end process;

--- TODO: not enough plls to allow this, maybe change main clock to 96MHz?
---   e_pal_pll: entity work.pll_pal_sc
---   port map (
---      clkout => i_clk_chroma_x60_dac,        -- ~266.0MHz  - DAC frequency
---      clkoutd3 => i_clk_chroma_x20_dac,      -- ~88.7MHz
---      clkin  => i_clk_chroma_x4_jitter
---   );
---
---   -- divide above by 5
---   e_clkdiv_cdac_5 : CLKDIV
---   generic map (
---      DIV_MODE => "5",
---      GSREN => "false"
---   )
---   port map (
---      RESETN => '1',
---      HCLKIN => i_clk_chroma_x60_dac,
---      CLKOUT => i_clk_chroma_x12_px,          -- ~53.2MHz colour pixel clock clock
---      CALIB  => '1'
---   );
---   
---   e_clkdiv_cdac_3 : CLKDIV
---   generic map (
---      DIV_MODE => "5",
---      GSREN => "false"
---   )
---   port map (
---      RESETN => '1',
---      HCLKIN => i_clk_chroma_x20_dac,
---      CLKOUT => i_clk_chroma_x4,             -- ~17.5MHz x4 cleaner clock
---      CALIB  => '1'
---   );

   e_chroma_gen:entity work.dossy_chroma
   generic map (
---      G_USE_EXT_x4_CLK  => true,
      G_GAIN => 1.0
   )
   port map (
      clk_i             => i_clk_pll_48M,
---      clk_chroma_x4_i   => i_clk_chroma_x4,
      r_i               => unsigned(i_Vid_48_r),
      g_i               => unsigned(i_Vid_48_g),
      b_i               => unsigned(i_Vid_48_b),
      hs_i              => i_vid_48_hs,
      vs_i              => i_Vid_48_vs,
      chroma_o          => i_chroma_s,
      clk_chroma_x4_o   => i_clk_chroma_x4_jitter,
      car_ry_o          => open,
      pal_sw_o          => open,
      base_ry_o         => open
   );


   p_chrom_s2u:process(i_clk_pll_48M)
   begin
      if rising_edge(i_clk_pll_48M) then
         r2_vid_chroma <= to_unsigned(16+to_integer(i_chroma_s), 5);
      end if;
   end process;

---   -- regular 30 bits per sample 
---   e_chroma_dac:entity work.dac1_oser
---   port map (
---      rst_i             => i_fb_syscon.rst,
---      clk_sample_i      => i_clk_chroma_x4,
---      clk_dac_px_i      => i_clk_chroma_x12_px,
---      clk_dac_i         => i_clk_chroma_x60_dac,
---      sample_i          => r2_vid_chroma(4 downto 1),
---      bitstream_o       => vid_chroma_o
---   );

   e_mono_dac_chr:entity work.dac1_oserx2
   port map (
      rst_i             => i_fb_syscon.rst,
      clk_sample_i      => i_clk_pll_48M,
      clk_dac_px_i      => i_clk_div_72M,
      clk_dac_i         => i_clk_pll_360M,
      sample_i          => r2_vid_chroma(4 downto 1),
      bitstream_o       => i_vid_chroma_0
   );

    
   -- split x2 15 bits per sample
   e_mono_dac_r:entity work.dac1_oserx2
   port map (
      rst_i             => i_fb_syscon.rst,
      clk_sample_i      => i_clk_pll_48M,
      clk_dac_px_i      => i_clk_div_72M,
      clk_dac_i         => i_clk_pll_360M,
      sample_i          => unsigned(not(i_Vid_48_r)),
      bitstream_o       => i_vid_r_0
   );

   e_mono_dac_g:entity work.dac1_oserx2
   port map (
      rst_i             => i_fb_syscon.rst,
      clk_sample_i      => i_clk_pll_48M,
      clk_dac_px_i      => i_clk_div_72M,
      clk_dac_i         => i_clk_pll_360M,
      sample_i          => unsigned(not(i_Vid_48_g)),
      bitstream_o       => i_vid_g_0
   );

   e_mono_dac_b:entity work.dac1_oserx2
   port map (
      rst_i             => i_fb_syscon.rst,
      clk_sample_i      => i_clk_pll_48M,
      clk_dac_px_i      => i_clk_div_72M,
      clk_dac_i         => i_clk_pll_360M,
      sample_i          => unsigned(not(i_Vid_48_b)),
      bitstream_o       => i_vid_b_0
   );

     
      clkdiv5_snd : CLKDIV
      generic map (
         DIV_MODE => "5",            -- Divide by 5
         GSREN => "false"
      )
      port map (
         RESETN => '1',
         HCLKIN => i_clk_chroma_x4_jitter,
         CLKOUT => i_clk_snd,
         CALIB  => '1'
      );

   e_obuf_vid_chroma:obuf
   port map (
      I => i_vid_chroma_0,
      O => vid_chroma_o
      );

   e_obuf_vid_r:obuf
   port map (
      I => i_vid_r_0,
      O => vid_r_o
      );

   e_obuf_vid_g:obuf
   port map (
      I => i_vid_g_0,
      O => vid_g_o
      );

   e_obuf_vid_b:obuf
   port map (
      I => i_vid_b_0,
      O => vid_b_o
      );

end generate;
G_DONT_1BIT_DAC_VIDEO:if not G_1BIT_DAC_VIDEO generate
   vid_r_o <= not i_Vid_48_r(i_Vid_48_r'high);
   vid_g_o <= not i_Vid_48_g(i_Vid_48_g'high);
   vid_b_o <= not i_Vid_48_b(i_Vid_48_b'high);
   vid_chroma_o <= '0';

   -- TODO: this is quite rough and ready, check frequency and improve once reliable
   p_clk_snd_gen:process(i_fb_syscon.clk)
      constant div : natural := 3547;
      constant num : natural := 64000;    -- roughly PAL * 4/5
      variable r_acc : unsigned(numbits(num) downto 0) := (others => '0');
   begin
      if rising_edge(i_fb_syscon.clk) then
         r_acc := r_acc + div;
         if r_acc >= num then
            r_acc := r_acc - num;
            i_clk_snd <= not i_clk_snd;
         end if;
      end if;
   end process;

end generate;

end architecture rtl;
      

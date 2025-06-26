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
-- Module Name:      C20K
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
use work.fb_SYS_pack.all;
use work.fb_CPU_pack.all;
use work.fb_chipset_pack.all;
use work.fb_intcon_pack.all;
use work.ws2812_pack.all;

entity C20K is
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
      mem_RAM_nCE_o        : out           std_logic_vector(3 downto 0);
      mem_ROM_nCE_o        : out           std_logic;
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

architecture rtl of C20K is
-----------------------------------------------------------------------------
	-- config signals
	-----------------------------------------------------------------------------

	signal i_cfg_debug_button  : std_logic;

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

   -- led array wrapper
   signal i_c2p_led_arr       : fb_con_o_per_i_t;
   signal i_p2c_led_arr       : fb_con_i_per_o_t;

   -- debug uart wrapper
   signal i_c2p_uart       : fb_con_o_per_i_t;
   signal i_p2c_uart       : fb_con_i_per_o_t;

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

	signal i_noice_debug_nmi_n			: std_logic;							-- debugger is forcing a cpu NMI
	signal i_noice_debug_shadow		: std_logic;							-- debugger memory MOS map is active (overrides shadow_mos)
	signal i_noice_debug_inhibit_cpu	: std_logic;							-- during a 5C op code, inhibit address / data to avoid
																							-- spurious memory accesses
	signal i_noice_debug_5c				: std_logic;							-- A 5C instruction is being fetched (qualify with clken below)
	signal i_noice_debug_cpu_clken	: std_logic;							-- clken and cpu rdy
	signal i_noice_debug_A0_tgl		: std_logic;							-- 1 when current A0 is different to previous fetched
	signal i_noice_debug_opfetch		: std_logic;							-- this cycle is an opcode fetch
	signal r_noice_debug_btn			: std_logic;

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

	signal i_clk_snd						: std_logic;							-- ~3.5MHz PAULA samplerate clock
	signal i_dac_snd_pwm					: std_logic;							-- pwm signal for sound channels
	signal i_dac_sample					: signed(9 downto 0);				-- sample playing

	-----------------------------------------------------------------------------
	-- cpu control signals
	-----------------------------------------------------------------------------
	signal i_cpu_IRQ_n					: std_logic;
	signal i_chipset_cpu_halt			: std_logic;
	signal i_chipset_cpu_int			: std_logic;

	signal i_boot_65816					: std_logic_vector(1 downto 0);
	signal i_65816_bool_act				: std_logic;

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

	signal i_vga_debug_r					: std_logic_vector(3 downto 0);
	signal i_vga_debug_g					: std_logic_vector(3 downto 0);
	signal i_vga_debug_b					: std_logic_vector(3 downto 0);
	signal i_vga_debug_hs				: std_logic;
	signal i_vga_debug_vs				: std_logic;
	signal i_vga_debug_blank			: std_logic;

	signal i_vga27_debug_r				: std_logic_vector(3 downto 0);
	signal i_vga27_debug_g				: std_logic_vector(3 downto 0);
	signal i_vga27_debug_b				: std_logic_vector(3 downto 0);
	signal i_vga27_debug_hs				: std_logic;
	signal i_vga27_debug_vs				: std_logic;
	signal i_vga27_debug_blank			: std_logic;

	signal i_debug_hsync_det			: std_logic;
	signal i_debug_vsync_det			: std_logic;
	signal i_debug_hsync_crtc			: std_logic;
	signal i_debug_odd					: std_logic;
	signal i_debug_spr_mem_clken		: std_logic;

	signal i_mb_scroll_latch_c			: std_logic_vector(1 downto 0); -- scroll offset registers from port B latch

   -----------------------------------------------------------------------------
   -- peripherals
   -----------------------------------------------------------------------------
   
   constant C_BAUD_CKK16_DIV : positive := (CLOCKSPEED*1000000)/(16*BAUD);

   signal r_clken_baud16  : std_logic;
   signal r_clk_baud_div: unsigned(numbits(C_BAUD_CKK16_DIV-1) downto 0); -- note 1 bigger to catch carry out

   signal i_ser_tx      : std_logic;

   signal i_clk_pll_48M: std_logic;
   signal i_clk_pll_128M: std_logic;

   -- multiplex in to core, out from peripheral (I0 phase)   
   signal icipo_ser_cts    : std_logic;
   signal icipo_ser_rx     : std_logic;
   signal icipo_d_cas      : std_logic;
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
   signal icopi_SER_TX     : std_logic;
   signal icopi_SER_RTS    : std_logic;

   -- multiplex out from core, in to peripheral (O0 phase)   
   signal icopi_j_ds_nCS2  : std_logic;
   signal icopi_j_ds_nCS1  : std_logic;
   signal icopi_j_spi_clk  : std_logic;
   signal icopi_j_spi_mosi : std_logic;
   signal icopi_j_adc_nCS  : std_logic;

   -- emulated / synthesized beeb signals
   signal i_beeb_ic32      : std_logic_vector(7 downto 0);
   signal i_c20k_latch     : std_logic_vector(7 downto 0);


   -- debug
   signal i_debug_leds     : ws2812_colour_arr_t(0 to 7);

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

      EXT_nRESET_i                  => sup_nRST_i and icipo_kb_nRST,    -- TODO: make supervisor/reset button do power-up reset

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
      G_INCL_CHIPSET		  => G_INCL_CHIPSET,
		G_INCL_HDMI					=> G_INCL_HDMI,
		G_HDMI_SHADOW_SYS			=> G_HDMI_SHADOW_SYS
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
		G_REGISTER_CONTROLLER_P2C => true
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
   i_per_p2c_intcon(PERIPHERAL_NO_LED_ARR)<= i_p2c_led_arr;
   i_per_p2c_intcon(PERIPHERAL_NO_UART)   <= i_p2c_uart;

   i_p2c_cpu            <= i_con_p2c_intcon(MAS_NO_CPU);
	i_c2p_memctl			<= i_per_c2p_intcon(PERIPHERAL_NO_MEMCTL);
	i_c2p_mem				<= i_per_c2p_intcon(PERIPHERAL_NO_CHIPRAM);
   i_c2p_sys            <= i_per_c2p_intcon(PERIPHERAL_NO_SYS);
	i_c2p_version			<= i_per_c2p_intcon(PERIPHERAL_NO_VERSION);
   i_c2p_led_arr        <= i_per_c2p_intcon(PERIPHERAL_NO_LED_ARR);
   i_c2p_uart           <= i_per_c2p_intcon(PERIPHERAL_NO_UART);



--TODO: CHIPSET
--TODO: sn74689 sound
GCHIPSET: IF G_INCL_CHIPSET GENERATE
	i_con_c2p_intcon(MAS_NO_CHIPSET)				<= i_c2p_chipset_con;
	i_per_p2c_intcon(PERIPHERAL_NO_CHIPSET)	<= i_p2c_chipset_per;

	i_p2c_chipset_con 	<= i_con_p2c_intcon(MAS_NO_CHIPSET);
	i_c2p_chipset_per		<= i_per_c2p_intcon(PERIPHERAL_NO_CHIPSET);

	e_chipset:fb_chipset
	generic map (
		SIM => SIM,
		CLOCKSPEED => CLOCKSPEED
	)
	port map (
		fb_syscon_i						=> i_fb_syscon,

		-- peripheral port connect to controllers
		fb_per_c2p_i 	=> i_c2p_chipset_per,
		fb_per_p2c_o 	=> i_p2c_chipset_per,

		-- controller port connecto to peripherals
		fb_con_c2p_o	=> i_c2p_chipset_con,
		fb_con_p2c_i	=> i_p2c_chipset_con,

		clk_snd_i		=> i_clk_snd,

		cpu_halt_o		=> i_chipset_cpu_halt,
		cpu_int_o		=> i_chipset_cpu_int,

		vsync_i			=> i_vga_debug_vs,
		hsync_i			=> i_vga_debug_hs,

		I2C_SDA_io		=> I2C_SDA_io,
		I2C_SCL_io		=> I2C_SCL_io,

		snd_dat_o		=> i_dac_sample,
		snd_dat_change_clken_o => open

	);

	--NOTE: we do DAC stuff at top level as blitter/1MPaula do this differently
	G_SND_DAC:IF G_INCL_CS_SND GENERATE

		e_dac_snd: entity work.dac_1bit 
		generic map (
			G_SAMPLE_SIZE		=> 10,
			G_SYNC_DEPTH		=> 0
		)
   	port map (
			rst_i					=> i_fb_syscon.rst,
			clk_dac				=> i_fb_syscon.clk,

			sample				=> i_dac_sample,
		
			bitstream			=> i_dac_snd_pwm
		);
	END GENERATE;
	G_NO_SND_DAC:IF not G_INCL_CS_SND GENERATE
		i_dac_snd_pwm <= '0';
	END GENERATE;

END GENERATE;
GNOTCHIPSET:IF NOT G_INCL_CHIPSET GENERATE
	i_chipset_cpu_halt <= '0';
	i_chipset_cpu_int <= '0';
	i_dac_snd_pwm <= '0';
	I2C_SDA_io <= 'Z';
	I2C_SCL_io <= 'Z';
END GENERATE;

	aud_i2s_ws_pwm_R_o <= i_dac_snd_pwm;
	aud_i2s_bck_pwm_L_o <= i_dac_snd_pwm;

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
		noice_debug_nmi_n_o				=> i_noice_debug_nmi_n,
		noice_debug_shadow_o				=> i_noice_debug_shadow,
		noice_debug_inhibit_cpu_o		=> i_noice_debug_inhibit_cpu,
		-- noice debugger signals from cpu
		noice_debug_5c_i					=> i_noice_debug_5c,
		noice_debug_cpu_clken_i			=> i_noice_debug_cpu_clken,
		noice_debug_A0_tgl_i				=> i_noice_debug_A0_tgl,
		noice_debug_opfetch_i			=> i_noice_debug_opfetch,

		-- noice debugger button		
		noice_debug_button_i				=> r_noice_debug_btn,

		-- cpu throttle

		throttle_cpu_2MHz_o 				=> i_throttle_cpu_2MHz,

		-- fishbone signals

		fb_syscon_i							=> i_fb_syscon,
		fb_c2p_i								=> i_c2p_memctl,
		fb_p2c_o								=> i_p2c_memctl,

		-- cpu specific

		boot_65816_o						=> i_boot_65816,

		rom_throttle_map_o				=> i_rom_throttle_map,
		rom_autohazel_map_o				=> i_rom_autohazel_map
	);


	e_fb_mem: entity work.fb_mem
	generic map (
		G_SWRAM_SLOT						=> G_MEM_SWRAM_SLOT,
		G_FAST_IS_10						=> G_MEM_FAST_IS_10,
		G_SLOW_IS_45						=> G_MEM_SLOW_IS_45
	)
	port map (
			-- 2M RAM/256K ROM bus
		MEM_A_o								=> mem_A_io,
		MEM_D_io								=> MEM_D_io,
		MEM_nOE_o							=> MEM_nOE_o,
		MEM_nWE_o							=> MEM_nWE_o,
		MEM_ROM_nCE_o						=> MEM_ROM_nCE_o,
		MEM_RAM_nCE_o						=> MEM_RAM_nCE_o,

		-- fishbone signals

		fb_syscon_i							=> i_fb_syscon,
		fb_c2p_i								=> i_c2p_mem,
		fb_p2c_o								=> i_p2c_mem,

		debug_mem_a_stb_o					=> open
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

   e_fb_sys:entity work.fb_SYS_c20k
   generic map (
      SIM                           => SIM,
      CLOCKSPEED                    => CLOCKSPEED,
      G_JIM_DEVNO                   => x"D2"
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
      p_ser_cts_o                   => icipo_ser_cts,
      p_ser_rx_o                    => icipo_ser_rx,
      p_d_cas_o                     => icipo_d_cas,
      p_kb_nRST_o                   => icipo_kb_nRST,

      -- random other multiplexed pins out to FPGA (I1 phase)
      p_j_i0_o                      => icipo_j_i0,
      p_j_i1_o                      => icipo_j_i1,
      p_j_spi_miso_o                => icipo_j_spi_miso,
      p_btn0_o                      => icipo_btn0,
      p_btn1_o                      => icipo_btn1,
      p_btn2_o                      => icipo_btn2,
      p_btn3_o                      => icipo_btn3,

      -- random other multiplexed pins in from FPGA (O0 phase)
      p_SER_TX_i                    => icopi_SER_TX,
      p_SER_RTS_i                   => icopi_SER_RTS,

      -- random other multiplexed pins in from FPGA (O1 phase)
      p_j_ds_nCS2_i                 => icopi_j_ds_nCS2,
      p_j_ds_nCS1_i                 => icopi_j_ds_nCS1,
      p_j_spi_clk_i                 => icopi_j_spi_clk,
      p_VID_HS_i                    => i_vga_debug_hs,
      p_VID_VS_i                    => i_vga_debug_vs,
      p_VID_CS_i                    => not (i_vga_debug_hs xor i_vga_debug_vs),
      p_j_spi_mosi_i                => icopi_j_spi_mosi,
      p_j_adc_nCS_i                 => icopi_j_adc_nCS,

      -- other inputs to FPGA
      lpstb_i                       => pj_LPSTB_i,

      -- emulated / synthesized beeb signals
      beeb_ic32_o                   => i_beeb_ic32,
      c20k_latch_o                  => i_c20k_latch		
   );
   
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

      -- noice debugger signals to cpu
      noice_debug_nmi_n_i           => i_noice_debug_nmi_n,
      noice_debug_shadow_i          => i_noice_debug_shadow,
      noice_debug_inhibit_cpu_i     => i_noice_debug_inhibit_cpu,
      -- noice debugger signals from cpu
      noice_debug_5c_o              => i_noice_debug_5c,
      noice_debug_cpu_clken_o       => i_noice_debug_cpu_clken,
      noice_debug_A0_tgl_o          => i_noice_debug_A0_tgl,
      noice_debug_opfetch_o         => i_noice_debug_opfetch,


      -- logical mappings
		sys_ROMPG_i 						=> i_sys_ROMPG,	
		turbo_lo_mask_i					=> i_turbo_lo_mask,
      JIM_en_i                      => i_JIM_en,      
      JIM_page_i                    => i_JIM_page,

      -- direct CPU control signals from system
      nmi_n_i                       => icipo_btn1, -- TODO: NMI
      irq_n_i                       => i_sys_nIRQ,
      cpu_halt_i                    => i_chipset_cpu_halt,

      -- fishbone signals
      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_o                      => i_c2p_cpu,
      fb_p2c_i                      => i_p2c_cpu




   );

	i_cpu_IRQ_n <= not i_chipset_cpu_int and i_sys_nIRQ;


--   led(0) <= i_ser_tx;
--   led(1) <= '1';
--   led(2) <= not i_ser_tx;
--   led(3) <= '0';

--TODO: move to chipset?
--   e_fb_led_arr:entity work.fb_ws2812
--   generic map (
--      G_CLOCKSPEED => CLOCKSPEED * 1000000,
--      G_N_CHAIN => 8
--      )
--   port map (

--      -- fishbone signals

--      fb_syscon_i                   => i_fb_syscon,
--      fb_c2p_i                      => i_c2p_led_arr,
--      fb_p2c_o                      => i_p2c_led_arr,

--      led_serial_o                  => open --ui_leds_o
--   );




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
   begin
      if rising_edge(i_fb_syscon.clk) then
         if i_c2p_cpu.A_stb = '1' and i_c2p_cpu.cyc = '1' then
            for i in 0 to 7 loop
               i_debug_leds(I).red <= (0 => i_c2p_cpu.A(I), others => '0');
               i_debug_leds(I).green <= (0 => i_c2p_cpu.A(I + 8), others => '0');
               i_debug_leds(I).blue <= (0 => i_c2p_cpu.A(I + 16), others => '0');
            end loop;
         end if;
      end if;

   end process;

   e_dbg_led:entity work.ws2812
   generic map (
      G_CLOCKSPEED                    => CLOCKSPEED * 1000000,
      G_N_CHAIN                       => 8
   )
   port map (
      rst_i                   => i_fb_syscon.rst,
      clk_i                   => i_fb_syscon.clk,
      rgb_arr_i               => i_debug_leds,
      led_serial_o            => ui_leds_o

   );


                     
r_cfg_ver_boot <= (others => '1');
r_cfg_cpu_use_t65 <= '1';
r_cfg_swromx <= '0';
r_cfg_mosram <= '0';
r_cfg_swram_enable <= '1';
r_cfg_sys_type <= SYS_BBC;
r_cfg_do6502_debug <= '1'; 
r_cfg_cpu_type <= NONE;
r_cfg_cpu_speed_opt <= NONE;
r_cfg_mk2_cpubits <= "000";   --TODO: check!


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

		VGA_R_o				=> i_vga_debug_r,
		VGA_G_o				=> i_vga_debug_g,
		VGA_B_o				=> i_vga_debug_b,
		VGA_HS_o				=> i_vga_debug_hs,
		VGA_VS_o				=> i_vga_debug_vs,
		VGA_BLANK_o			=> i_vga_debug_blank,

		-- analogue video	retimed to 27 MHz DVI clock

		VGA27_R_o				=> i_vga27_debug_r,
		VGA27_G_o				=> i_vga27_debug_g,
		VGA27_B_o				=> i_vga27_debug_b,
		VGA27_HS_o				=> i_vga27_debug_hs,
		VGA27_VS_o				=> i_vga27_debug_vs,
		VGA27_BLANK_o			=> i_vga27_debug_blank,

		scroll_latch_c_i		=> i_mb_scroll_latch_c,

		PCM_L_i				=> i_dac_sample,

		debug_hsync_det_o => i_debug_hsync_det,
		debug_vsync_det_o => i_debug_vsync_det,
		debug_hsync_crtc_o => i_debug_hsync_crtc,
		debug_odd_o => i_debug_odd,
		debug_spr_mem_clken_o => i_debug_spr_mem_clken

	);
END GENERATE;

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

      aud_i2s_dat_o        <= '1';

      flash_ck_o           <= '1';
      flash_cs_o           <= '1';
      flash_mosi_o         <= '1';


      vid_b_o              <= not i_vga_debug_b(3);
      vid_chroma_o         <= '0';
      vid_g_o              <= not i_vga_debug_g(3);
      vid_r_o              <= not i_vga_debug_r(3);


      p_8MHZ_FDC_o         <= '0';

      cassette_o           <= '0';

      sd0_cs_o             <= '0';
      sd0_mosi_o           <= '0';
      sd0_sclk_o           <= '0';
      
      sd1_cs_o             <= '0';
      sd1_mosi_o           <= '0';
      sd1_sclk_o           <= '0';


end architecture rtl;
      
      

-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2022 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:    	1/7/2021
-- Design Name: 
-- Module Name:    	Mk.3 Blitter top-level design
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--use work.mk1board_types.all;

library work;
use work.common.all;
use work.fishbone.all;
use work.board_config_pack.all;
use work.HDMI_pack.all;
use work.fb_SYS_pack.all;
use work.fb_CPU_pack.all;
use work.fb_CPU_exp_pack.all;
use work.fb_chipset_pack.all;
use work.fb_intcon_pack.all;

entity mk3blit is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural := 128;								-- fast clock speed in mhz				
		G_JIM_DEVNO							: std_logic_vector(7 downto 0) := x"D1";
		G_DWRITE_HOLD						: natural := 6									-- hold write data on system bus for this many cycles
	);
	port(
		-- crystal osc 48Mhz - on WS board
		CLK_48M_i							: in		std_logic;

		-- 2M RAM/256K ROM bus (45)
		MEM_A_o								: out		std_logic_vector(20 downto 0);
		MEM_D_io								: inout	std_logic_vector(7 downto 0);	-- 17 bit RAMs used but D[7..0] is multiplexed with D[15..8]
		MEM_nOE_o							: out		std_logic;
		MEM_nWE_o							: out		std_logic;							-- add external pull-up

		MEM_FL_nCE_o						: out		std_logic;				
		MEM_RAM_nCE_o						: out		std_logic_vector(3 downto 0);
		
		-- 1 bit DAC sound out stereo, aux connectors mirror main (2)
		SND_L_o								: out		std_logic;
		SND_R_o								: out		std_logic;

		-- hdmi (11)

		HDMI_SCL_io							: inout	std_logic;
		HDMI_SDA_io							: inout	std_logic;
		HDMI_HPD_i							: in		std_logic;
		HDMI_CK_o							: out		std_logic;
		HDMI_D0_o							: out		std_logic;
		HDMI_D1_o							: out		std_logic;
		HDMI_D2_o							: out		std_logic;
		
		-- sdcard (5)
		SD_CS_o								: out		std_logic;
		SD_CLK_o								: out		std_logic;
		SD_MOSI_o							: out		std_logic;
		SD_MISO_i							: in		std_logic;
		SD_DET_i								: in		std_logic;

		-- SYS bus connects to SYStem CPU socket (38)

		SUP_nRESET_i						: in		std_logic;								-- SYStem reset after supervisor

		SYS_A_o								: out		std_logic_vector(15 downto 0);
		SYS_D_io								: inout	std_logic_vector(7 downto 0);
		SYS_BUF_D_DIR_o					: out		std_logic;
		SYS_BUF_D_nOE_o					: out		std_logic;
		
		SYS_SYNC_o							: out		std_logic;
		SYS_PHI1_o							: out		std_logic;
		SYS_PHI2_o							: out		std_logic;
		SYS_RnW_o							: out		std_logic;


		-- test these as outputs!!!
		SYS_RDY_i							: in 		std_logic; -- Master only?
		SYS_nNMI_i							: in 		std_logic;
		SYS_nIRQ_i							: in 		std_logic;
		SYS_PHI0_i							: in 		std_logic;
		SYS_nDBE_i							: in 		std_logic;


		-- SYS configuration and auxiliary (18)
		SYS_AUX_io							: inout	std_logic_vector(6 downto 0);
		SYS_AUX_o							: out		std_logic_vector(3 downto 0);

		-- rpi interface (26)
		--rpi_gpio								: inout	std_logic_vector(27 downto 2);


		-- i2c EEPROM (2)
		I2C_SCL_io							: inout	std_logic;
		I2C_SDA_io							: inout	std_logic;


		-- cpu / expansion sockets (56)

		exp_PORTA_io						: inout	std_logic_vector(7 downto 0);
		exp_PORTA_nOE_o					: out		std_logic;
		exp_PORTA_DIR_o					: out		std_logic;

		exp_PORTB_o							: out		std_logic_vector(7 downto 0);

		exp_PORTC_io						: inout 	std_logic_vector(11 downto 0);
		exp_PORTD_io						: inout	std_logic_vector(11 downto 0);

		exp_PORTEFG_io						: inout	std_logic_vector(11 downto 0);
		exp_PORTE_nOE						: out		std_logic;
		exp_PORTF_nOE						: out		std_logic;
		exp_PORTG_nOE						: out		std_logic;


		-- LEDs 
		LED_o									: out		std_logic_vector(3 downto 0);

		BTNUSER_i							: in		std_logic_vector(1 downto 0)

	);
end mk3blit;

architecture rtl of mk3blit is

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


	signal i_hsync					: std_logic;
	signal i_vsync					: std_logic;

	-----------------------------------------------------------------------------
	-- fishbone signals
	-----------------------------------------------------------------------------

	signal i_fb_syscon			: fb_syscon_t;							-- shared bus signals

	-- cpu wrapper
	signal i_c2p_cpu				: fb_con_o_per_i_t;
	signal i_p2c_cpu				: fb_con_i_per_o_t;

	-- cpu beeb motherboard wrapper
	signal i_c2p_sys				: fb_con_o_per_i_t;
	signal i_p2c_sys				: fb_con_i_per_o_t;

	-- blitter board RAM/ROM memory wrapper
	signal i_c2p_mem				: fb_con_o_per_i_t;
	signal i_p2c_mem				: fb_con_i_per_o_t;

	-- memory control registers wrapper
	signal i_c2p_memctl			: fb_con_o_per_i_t;
	signal i_p2c_memctl			: fb_con_i_per_o_t;

	-- memory control registers wrapper
	signal i_c2p_version			: fb_con_o_per_i_t;
	signal i_p2c_version			: fb_con_i_per_o_t;

	--chipset peripheral
	signal i_c2p_chipset_per	: fb_con_o_per_i_t;
	signal i_p2c_chipset_per	: fb_con_i_per_o_t;

	-- chipset controller
	signal i_c2p_chipset_con	: fb_con_o_per_i_t;
	signal i_p2c_chipset_con	: fb_con_i_per_o_t;

	-- intcon controller->peripheral
	signal i_con_c2p_intcon		: fb_con_o_per_i_arr(CONTROLLER_COUNT-1 downto 0);
	signal i_con_p2c_intcon		: fb_con_i_per_o_arr(CONTROLLER_COUNT-1 downto 0);
	-- intcon peripheral->controller
	signal i_per_c2p_intcon		: fb_con_o_per_i_arr(PERIPHERAL_COUNT-1 downto 0);
	signal i_per_p2c_intcon		: fb_con_i_per_o_arr(PERIPHERAL_COUNT-1 downto 0);

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

	-- intcon to peripheral sel
	signal i_intcon_peripheral_sel_addr		: fb_arr_std_logic_vector(CONTROLLER_COUNT-1 downto 0)(23 downto 0);
	signal i_intcon_peripheral_sel			: fb_arr_unsigned(CONTROLLER_COUNT-1 downto 0)(numbits(PERIPHERAL_COUNT)-1 downto 0);  -- address decoded selected peripheral
	signal i_intcon_peripheral_sel_oh		: fb_arr_std_logic_vector(CONTROLLER_COUNT-1 downto 0)(PERIPHERAL_COUNT-1 downto 0);	-- address decoded selected peripherals as one-hot		

	-----------------------------------------------------------------------------
	-- sound signals
	-----------------------------------------------------------------------------

	signal i_clk_snd						: std_logic;							-- ~3.5MHz PAULA samplerate clock
	signal i_dac_snd_pwm					: std_logic;							-- pwm signal for sound channels
	signal i_dac_sample					: signed(9 downto 0);				-- sample playing

	-----------------------------------------------------------------------------
	-- sys signals
	-----------------------------------------------------------------------------

	signal i_SYS_RnW						: std_logic;
	signal i_SYS_A							: std_logic_vector(15 downto 0);
	signal i_SYS_PHI2						: std_logic;
	signal i_SYS_PHI2_dly_nOE			: std_logic;							-- used to extend the gating of the data bus

	signal i_BUF_D_nOE					: std_logic;

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

	-- port direction/control signals
	signal i_cpu_exp_PORTE_nOE			: std_logic;
	signal i_cpu_exp_PORTF_nOE			: std_logic;
	signal i_cpu_exp_PORTG_nOE			: std_logic;

	signal i_rom_throttle_map			: std_logic_vector(15 downto 0);
	signal i_rom_autohazel_map			: std_logic_vector(15 downto 0);

	-----------------------------------------------------------------------------
	-- cpu expansion header wrapper signals
	-----------------------------------------------------------------------------
	signal i_wrap_exp_o					: t_cpu_wrap_exp_o;
	signal i_wrap_exp_i					: t_cpu_wrap_exp_i;
	signal i_hard_cpu_en					: std_logic;

	-----------------------------------------------------------------------------
	-- HDMI stuff
	-----------------------------------------------------------------------------

	-- hdmi peripheral interface control registers
	signal i_c2p_hdmi_per				: fb_con_o_per_i_t;
	signal i_p2c_hdmi_per				: fb_con_i_per_o_t;

	signal i_vga_debug_r					: std_logic;
	signal i_vga_debug_g					: std_logic;
	signal i_vga_debug_b					: std_logic;
	signal i_vga_debug_hs				: std_logic;
	signal i_vga_debug_vs				: std_logic;
	signal i_vga_debug_blank			: std_logic;

	signal i_debug_hsync_det			: std_logic;
	signal i_debug_vsync_det			: std_logic;
	signal i_debug_hsync_crtc			: std_logic;


	-----------------------------------------------------------------------------
	-- temporary debugging signals
	-----------------------------------------------------------------------------

	signal	i_debug_lock				: std_logic;
	signal	i_debug_fast				: std_logic;
	signal	i_debug_slow				: std_logic;
	signal	i_debug_cycle				: std_logic;

	signal	i_debug_sys_rd_ack		: std_logic;

	signal	i_debug_mem_a_stb			: std_logic;

	signal	i_debug_wrap_cpu_cyc		: std_logic;
	signal	i_debug_wrap_sys_cyc		: std_logic;
	signal	i_debug_wrap_sys_st		: std_logic;

	signal	i_debug_65816_vma			: std_logic;
	signal	i_debug_65816_addr_meta : std_logic;

	signal	i_debug_SYS_VIA_block		: std_logic;

	signal	i_debug_write_cycle_repeat : std_logic;

	signal   i_debug_z180_m1			: std_logic;

	signal  i_debug_80188_state			: std_logic_vector(2 downto 0);

begin

	e_fb_clocks: entity work.clocks_pll
	generic map (
		SIM => 	SIM,
		CLOCKSPEED => CLOCKSPEED
	)
	port map (
		EXT_nRESET_i						=> SUP_nRESET_i,
		EXT_CLK_48M_i						=> CLK_48M_i,

		clk_fish_o							=> i_clk_fish_128M,
		clk_snd_o							=> i_clk_snd,

		clk_lock_o							=> i_clk_lock,

		flasher_o							=> i_flasher

	);	


	e_fb_syscon: entity work.fb_syscon
	generic map (
		SIM => SIM,
		CLOCKSPEED => CLOCKSPEED
	)
	port map (
		fb_syscon_o							=> i_fb_syscon,

		EXT_nRESET_i						=> SUP_nRESET_i,

		clk_fish_i							=> i_clk_fish_128M,
		clk_lock_i							=> i_clk_lock,
		sys_dll_lock_i						=> i_sys_dll_lock

	);	

g_addr_decode:for I in CONTROLLER_COUNT-1 downto 0 generate
	-- address decode to select peripheral
	e_addr2s:entity work.address_decode
	generic map (
		SIM							=> SIM,
		G_PERIPHERAL_COUNT		=> PERIPHERAL_COUNT,
		G_INCL_CHIPSET				=> G_INCL_CHIPSET,
		G_INCL_HDMI					=> G_INCL_HDMI
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
		SIM 									=> SIM,
		G_PERIPHERAL_COUNT 						=> PERIPHERAL_COUNT,
		G_ADDRESS_WIDTH 					=> 24
		)
	port map (
		fb_syscon_i 						=> i_fb_syscon,

		-- peripheral ports connect to controllers
		fb_con_c2p_i						=> i_con_c2p_intcon(0),
		fb_con_p2c_o						=> i_con_p2c_intcon(0),

		-- controller ports connect to peripherals
		fb_per_c2p_o						=> i_per_c2p_intcon,
		fb_per_p2c_i						=> i_per_p2c_intcon,

		peripheral_sel_addr_o			=> i_intcon_peripheral_sel_addr(0),
		peripheral_sel_i					=> i_intcon_peripheral_sel(0),
		peripheral_sel_oh_i				=> i_intcon_peripheral_sel_oh(0)
	);


END GENERATE;

	i_con_c2p_intcon(MAS_NO_CPU)			<= i_c2p_cpu;
	i_per_p2c_intcon(PERIPHERAL_NO_MEMCTL)	<=	i_p2c_memctl;
	i_per_p2c_intcon(PERIPHERAL_NO_CHIPRAM)	<=	i_p2c_mem;
	i_per_p2c_intcon(PERIPHERAL_NO_SYS)		<=	i_p2c_sys;
	i_per_p2c_intcon(PERIPHERAL_NO_VERSION)	<= i_p2c_version;

	i_p2c_cpu				<= i_con_p2c_intcon(MAS_NO_CPU);
	i_c2p_memctl			<= i_per_c2p_intcon(PERIPHERAL_NO_MEMCTL);
	i_c2p_mem				<= i_per_c2p_intcon(PERIPHERAL_NO_CHIPRAM);
	i_c2p_sys				<= i_per_c2p_intcon(PERIPHERAL_NO_SYS);
	i_c2p_version			<= i_per_c2p_intcon(PERIPHERAL_NO_VERSION);



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

		vsync_i			=> i_vsync,
		hsync_i			=> i_hsync,

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

	SND_R_o <= i_dac_snd_pwm;
	SND_L_o <= i_dac_snd_pwm;



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
		MEM_A_o								=> MEM_A_o,
		MEM_D_io								=> MEM_D_io,
		MEM_nOE_o							=> MEM_nOE_o,
		MEM_nWE_o							=> MEM_nWE_o,
		MEM_ROM_nCE_o						=> MEM_FL_nCE_o,
		MEM_RAM_nCE_o						=> MEM_RAM_nCE_o,

		-- fishbone signals

		fb_syscon_i							=> i_fb_syscon,
		fb_c2p_i								=> i_c2p_mem,
		fb_p2c_o								=> i_p2c_mem,

		debug_mem_a_stb_o					=> i_debug_mem_a_stb
	);

	e_bus_oe_dly:entity work.metadelay
	generic map (
		N => MAX(0,G_DWRITE_HOLD-3)		-- need here to make sure we hold data in fb_SYS for at least as long as nOE delay
		)
	port map (
		clk => i_fb_syscon.clk,
		i => i_SYS_PHI2,
		o => i_SYS_PHI2_dly_nOE
		);


	i_BUF_D_nOE <= not i_SYS_PHI2 and not i_SYS_PHI2_dly_nOE;

	SYS_RnW_o <= i_SYS_RnW;
	SYS_A_o <= i_SYS_A;
	SYS_PHI2_o <= i_SYS_PHI2;
	SYS_BUF_D_nOE_o <= i_BUF_D_nOE;
	SYS_BUF_D_DIR_o <= i_SYS_RnW;

	e_fb_sys: entity work.fb_sys
	generic map (
		SIM => SIM,
		CLOCKSPEED => CLOCKSPEED,
		G_JIM_DEVNO => G_JIM_DEVNO,
		G_DWRITE_HOLD => G_DWRITE_HOLD
	)
	port map (
      cfg_sys_type_i                => r_cfg_sys_type,

		SYS_A_o								=> i_SYS_A,
		SYS_D_io								=> SYS_D_io,
		SYS_RDY_i							=> SYS_RDY_i,
		SYS_SYNC_o							=> SYS_SYNC_o,
		SYS_PHI0_i							=> SYS_PHI0_i,
		SYS_PHI1_o							=> SYS_PHI1_o,
		SYS_PHI2_o							=> i_SYS_PHI2,
		SYS_RnW_o							=> i_SYS_RnW,

		-- fishbone signals
		fb_syscon_i							=> i_fb_syscon,
		fb_c2p_i								=> i_c2p_sys,
		fb_p2c_o								=> i_p2c_sys,

		-- generated extra signals

		sys_ROMPG_o							=> i_sys_ROMPG,

		sys_dll_lock_o						=> i_sys_dll_lock,

		debug_sys_rd_ack_o				=> i_debug_sys_rd_ack,

		dbg_lock_o							=> i_debug_lock,
		dbg_fast_o							=> i_debug_fast,
		dbg_slow_o							=> i_debug_slow,
		dbg_cycle_o							=> i_debug_cycle,

		JIM_page_o							=> i_JIM_page,
		JIM_en_o								=> i_JIM_en,

		cpu_2MHz_phi2_clken_o			=> i_cpu_2MHz_phi2_clken,

		debug_write_cycle_repeat_o		=> i_debug_write_cycle_repeat,

		debug_wrap_sys_cyc_o				=> i_debug_wrap_sys_cyc,
		debug_wrap_sys_st_o				=> i_debug_wrap_sys_st
	);


	e_fb_cpu: entity work.fb_cpu
	generic map (
		SIM => SIM,
		CLOCKSPEED => CLOCKSPEED,
		G_MK3 => true,

		G_INCL_CPU_T65						=> G_INCL_CPU_T65,
		G_INCL_CPU_65C02					=> G_INCL_CPU_65C02,
		G_INCL_CPU_6800					=> G_INCL_CPU_6800,
		G_INCL_CPU_80188					=> G_INCL_CPU_80188,
		G_INCL_CPU_65816					=> G_INCL_CPU_65816,
		G_INCL_CPU_6x09					=> G_INCL_CPU_6x09,
		G_INCL_CPU_Z80						=> G_INCL_CPU_Z80,
		G_INCL_CPU_Z180						=> G_INCL_CPU_Z180,
		G_INCL_CPU_680x0					=> G_INCL_CPU_680x0,
		G_INCL_CPU_68008					=> G_INCL_CPU_68008,
		G_INCL_CPU_ARM2					=> G_INCL_CPU_ARM2
	)
	port map (

		-- configuration

		cfg_cpu_type_i						=> r_cfg_cpu_type,
		cfg_cpu_use_t65_i					=> r_cfg_cpu_use_t65,
		cfg_cpu_speed_opt_i				=> r_cfg_cpu_speed_opt,
     	cfg_sys_type_i                => r_cfg_sys_type,      
		cfg_swram_enable_i				=> r_cfg_swram_enable,
		cfg_swromx_i						=> r_cfg_swromx,
		cfg_mosram_i						=> r_cfg_mosram,

		-- cpu throttle

		throttle_cpu_2MHz_i 				=> i_throttle_cpu_2MHz,
		cpu_2MHz_phi2_clken_i			=> i_cpu_2MHz_phi2_clken,
		rom_throttle_map_i				=> i_rom_throttle_map,
		rom_autohazel_map_i				=> i_rom_autohazel_map,

		-- wrapper expansion header/socket pins
		wrap_exp_i							=> i_wrap_exp_i,
		wrap_exp_o							=> i_wrap_exp_o,

		hard_cpu_en_o						=> i_hard_cpu_en,

		-- memctl signals
		swmos_shadow_i						=> i_swmos_shadow,

		-- noice debugger signals to cpu
		noice_debug_nmi_n_i				=> i_noice_debug_nmi_n,
		noice_debug_shadow_i				=> i_noice_debug_shadow,
		noice_debug_inhibit_cpu_i		=> i_noice_debug_inhibit_cpu,
		-- noice debugger signals from cpu
		noice_debug_5c_o					=> i_noice_debug_5c,
		noice_debug_cpu_clken_o			=> i_noice_debug_cpu_clken,
		noice_debug_A0_tgl_o				=> i_noice_debug_A0_tgl,
		noice_debug_opfetch_o			=> i_noice_debug_opfetch,


		-- extra memory map control signals
		sys_ROMPG_i 						=> i_sys_ROMPG,	
		turbo_lo_mask_i					=> i_turbo_lo_mask,


		-- direct CPU control signals from system
		nmi_n_i								=> SYS_nNMI_i,
		irq_n_i								=> i_cpu_IRQ_n,

		-- fishbone signals
		fb_syscon_i							=> i_fb_syscon,
		fb_c2p_o								=> i_c2p_cpu,
		fb_p2c_i								=> i_p2c_cpu,

		-- chipset control signals
		cpu_halt_i							=> i_chipset_cpu_halt,

		boot_65816_i						=> i_boot_65816,

		debug_wrap_cyc_o					=> i_debug_wrap_cpu_cyc,

		debug_65816_vma_o					=> i_debug_65816_vma,

		JIM_en_i								=> i_JIM_en,
		JIM_page_i							=> i_JIM_page,

		debug_SYS_VIA_block_o			=> i_debug_SYS_VIA_block,
		debug_z180_m1_o					=> i_debug_z180_m1,
		debug_65816_addr_meta_o			=> i_debug_65816_addr_meta,
		debug_80188_state_o				=> i_debug_80188_state,
		debug_65816_boot_act_o			=> i_65816_bool_act
	);

	i_cpu_IRQ_n <= SYS_nIRQ_i and not i_chipset_cpu_int;

	--===========================================================
	-- CPU wrap external pins to/from typed objects to allow same
	-- fb_CPU to be used for mk2/3 boards -- signals will be 
	-- unpacked in lower level wrappers by fb_CPU_xxx_exp_pins 
	-- components
	--===========================================================

	-- PORTA is a 74lvc4245 need to control direction and enable
	exp_PORTA_nOE_o <= i_wrap_exp_o.PORTA_nOE;
	exp_PORTA_DIR_o <= i_wrap_exp_o.PORTA_DIR;
	exp_PORTA_io	 <= (others => 'Z') when i_wrap_exp_o.PORTA_DIR = '1' or i_wrap_exp_o.PORTA_nOE = '1' else
						 	 i_wrap_exp_o.PORTA;

	i_wrap_exp_i.PORTA <= exp_PORTA_io;

	-- PORTB is hardwired output 74lvc4245

	exp_PORTB_o <= i_wrap_exp_o.PORTB;

	-- PORTC is always input only CB3T buffer, can be output but not used

	i_wrap_exp_i.PORTC <= exp_PORTC_io;
	exp_PORTC_io <= (others => 'Z');

	-- PORTD - individual cpu wrappers control direction and direction 

	g_portd_o:for I in 11 downto 0 generate
		exp_PORTD_io(I) <= i_wrap_exp_o.PORTD(I) when i_wrap_exp_o.PORTD_o_en(I) = '1' else
							 'Z';
	end generate;

	i_wrap_exp_i.PORTD <= exp_PORTD_io;

	-- PORTE,F,G are multiplexed CB3T's with PORTEFG_io connected to all three on one side
	-- broken out to separate pins on expansion headers on other sides
	-- to use as inputs relevant nOE needs to be asserted and data read (after a delay!)
	-- only port F is used as inputs and needs the DIR signal asserted to output data

	-- PORTE always inputs at present
	i_cpu_exp_PORTE_nOE <= i_wrap_exp_o.PORTE_i_nOE and i_wrap_exp_o.PORTE_o_nOE;

	-- NOTE: address 23 downto 20, 15 downto 8 only valid when portE is enabled
	i_wrap_exp_i.PORTEFG <= exp_PORTEFG_io;

	i_cpu_exp_PORTF_nOE <= i_wrap_exp_o.PORTF_i_nOE and i_wrap_exp_o.PORTF_o_nOE;

	-- PORTF data output on lines 11..4 on 16 bit cpus, 3..0 always inputs for config
	exp_PORTEFG_io(11 downto 0) 
		<= 	i_wrap_exp_o.PORTF & "ZZZZ" when i_wrap_exp_o.PORTF_o_nOE = '0' else
		    "ZZZZ" & i_wrap_exp_o.PORTE when i_wrap_exp_o.PORTE_o_nOE = '0' else
			(others => 'Z');
	
	-- PORTG only used at reset, read in top level
	i_cpu_exp_PORTG_nOE <= '1';




	p_debug_btn:process(i_fb_syscon)
	variable vcnt:unsigned(7 downto 0);
	begin
		if i_fb_syscon.rst = '1' then
			vcnt := (others => '1');
			r_noice_debug_btn <= '0';			
		else
			if rising_edge(i_fb_syscon.clk) then
				if i_cfg_debug_button = '0' then
					if vcnt = 0 then
						r_noice_debug_btn <= '1';
					else
						vcnt := vcnt - 1;
					end if;
				else
					vcnt := (others => '1');
					r_noice_debug_btn <= '0';
				end if;
			end if;
		end if;
	end process;


-- ================================================================================================ --
-- BOOT TIME CONFIGURATION
-- ================================================================================================ --


-- enable port F/G for reading configuration
p_EFG_en:process(i_fb_syscon, i_cpu_exp_PORTE_nOE, i_cpu_exp_PORTF_nOE, i_cpu_exp_PORTG_nOE)
begin
	if i_fb_syscon.rst = '1' then
		exp_PORTE_nOE <= '1';
		exp_PORTF_nOE <= '1';
		exp_PORTG_nOE <= '1';
		if i_fb_syscon.prerun(0) = '1' then
			exp_PORTF_nOE <= '0';
		end if;
		if i_fb_syscon.prerun(1) = '1' then
			exp_PORTG_nOE <= '0';
		end if;
	else
		exp_PORTE_nOE <= i_cpu_exp_PORTE_nOE;
		exp_PORTF_nOE <= i_cpu_exp_PORTF_nOE;
		exp_PORTG_nOE <= i_cpu_exp_PORTG_nOE;
	end if;		

end process;

-- configure hard/soft cpu
p_config:process(i_fb_syscon)
variable v_cfg_pins_cpu_type_and_speed : std_logic_vector(6 downto 0);
begin
	if rising_edge(i_fb_syscon.clk) then

		if i_fb_syscon.prerun(0) = '1' then
			r_cfg_ver_boot 	<= (others => '0');	-- clear rest
			r_cfg_ver_boot(15 downto 12) <= exp_PORTEFG_io(3 downto 0);	-- portF[3..0] pins

			v_cfg_pins_cpu_type_and_speed(6 downto 3) := exp_PORTEFG_io(3 downto 0);
		elsif i_fb_syscon.prerun(1) = '1' then
			r_cfg_ver_boot(11 downto 0) <= exp_PORTEFG_io;
			-- read port G at boot time
			r_cfg_cpu_use_t65 <= not exp_PORTEFG_io(3);
			v_cfg_pins_cpu_type_and_speed(2 downto 0) := exp_PORTEFG_io(11 downto 9);
			r_cfg_swromx <= not exp_PORTEFG_io(4);
			r_cfg_mosram <= not exp_PORTEFG_io(5);
			r_cfg_swram_enable <= exp_PORTEFG_io(6);
         case exp_PORTEFG_io(2 downto 0) is
            when "110" => 
               r_cfg_sys_type <= SYS_ELK;
            when others =>
               r_cfg_sys_type <= SYS_BBC;
         end case;
		elsif i_fb_syscon.prerun(2) = '1' then

			r_cfg_do6502_debug <= '0';

			if r_cfg_cpu_use_t65 = '1' then
				r_cfg_do6502_debug <= '1';
			end if;

			r_cfg_cpu_type <= NONE;
			r_cfg_cpu_speed_opt <= NONE;
			r_cfg_mk2_cpubits <= "111";

			-- select cpu configuration	
			case v_cfg_pins_cpu_type_and_speed is
				when "1100101" =>
					r_cfg_cpu_type <= CPU_65816;
					r_cfg_mk2_cpubits <= "001";
					-- r_cfg_do6502_debug <= '1'; -- doesn't work for 65816 yet
				when "0111111" =>
					r_cfg_cpu_type <= CPU_6x09;
					r_cfg_mk2_cpubits <= "110";
				when "0111010" =>
					r_cfg_cpu_type <= CPU_6x09;
					r_cfg_cpu_speed_opt <= CPUSPEED_6309_3_5;
					r_cfg_mk2_cpubits <= "010";
				when "0111000" =>
					r_cfg_cpu_type <= CPU_6800;
				when "0011000" =>
					r_cfg_cpu_type <= CPU_680X0;
					r_cfg_mk2_cpubits <= "000";
				when "0100000" =>
					r_cfg_cpu_type <= CPU_80188;
				when "0100100" =>
					r_cfg_cpu_type <= CPU_80186;
				when "1101110" =>
					r_cfg_cpu_type <= CPU_65c02;
					r_cfg_mk2_cpubits <= "011";
					r_cfg_do6502_debug <= '1';
				when "1110101" =>
					r_cfg_cpu_type <= CPU_65c02;
					r_cfg_cpu_speed_opt <= CPUSPEED_65C02_8;
					r_cfg_mk2_cpubits <= "101";
					r_cfg_do6502_debug <= '1';
				when "0110111" =>
					r_cfg_cpu_type <= CPU_ARM2;
					r_cfg_mk2_cpubits <= "000";
				when "0101001" =>
					r_cfg_cpu_type <= CPU_Z180;
					r_cfg_mk2_cpubits <= "100";
				when others =>
					null;
			end case;
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

i_cfg_debug_button <= SYS_AUX_io(6);

i_hsync <= SYS_AUX_io(5);
i_vsync <= SYS_AUX_io(4);


LED_o(0) <= '0' 			 when i_fb_syscon.rst_state = reset else
				i_flasher(3) when i_fb_syscon.rst_state = powerup else
				i_flasher(2) when i_fb_syscon.rst_state = resetfull else
				i_flasher(0) when i_fb_syscon.rst_state = lockloss else
				'1'			 when i_fb_syscon.rst_state = run else
				i_flasher(1);
LED_o(1) <= not i_debug_SYS_VIA_block;
LED_o(2) <= not i_JIM_en;
LED_o(3) <= '0' when r_cfg_cpu_type = CPU_Z180 else '1';

SYS_AUX_o			<= "0" & i_debug_80188_state;
SYS_AUX_io(0) <= i_vga_debug_hs;
SYS_AUX_io(1) <= i_vga_debug_vs;
SYS_AUX_io(2) <= i_noice_debug_opfetch;
SYS_AUX_io(3) <= i_65816_bool_act;

SYS_AUX_io <= (others => 'Z');


SD_CS_o <= '1';
SD_CLK_o <= '1';
SD_MOSI_o <= '1';




--====================================================
-- H D M I
--====================================================

G_HDMI:IF G_INCL_HDMI GENERATE
	i_per_p2c_intcon(PERIPHERAL_NO_HDMI)		<= i_p2c_hdmi_per;
	i_c2p_hdmi_per			<= i_per_c2p_intcon(PERIPHERAL_NO_HDMI);


	e_fb_HDMI:fb_HDMI
	generic map (
		SIM => SIM,
		CLOCKSPEED => CLOCKSPEED
	)
	port map (
		CLK_48M_i			=> CLK_48M_i,

		fb_syscon_i			=> i_fb_syscon,
		fb_c2p_i				=> i_c2p_hdmi_per,
		fb_p2c_o				=> i_p2c_hdmi_per,

		HDMI_SCL_io			=> HDMI_SCL_io,
		HDMI_SDA_io			=> HDMI_SDA_io,
		HDMI_HPD_i			=> HDMI_HPD_i,
		HDMI_CK_o			=> HDMI_CK_o,
		HDMI_B_o				=> HDMI_D0_o,
		HDMI_G_o				=> HDMI_D1_o,
		HDMI_R_o				=> HDMI_D2_o,

		-- debug video	

		VGA_R_o				=> i_vga_debug_r,
		VGA_G_o				=> i_vga_debug_g,
		VGA_B_o				=> i_vga_debug_b,
		VGA_HS_o				=> i_vga_debug_hs,
		VGA_VS_o				=> i_vga_debug_vs,
		VGA_BLANK_o			=> i_vga_debug_blank,

		PCM_L_i				=> i_dac_sample,

		debug_hsync_det_o => i_debug_hsync_det,
		debug_vsync_det_o => i_debug_vsync_det,
		debug_hsync_crtc_o => i_debug_hsync_crtc

	);
END GENERATE;


end rtl;

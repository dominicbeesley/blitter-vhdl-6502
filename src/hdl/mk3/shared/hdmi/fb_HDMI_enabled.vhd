-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	21/9/2021
-- Design Name: 
-- Module Name:    	fishbone bus - HDMI dual head wrapper
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the blitter/cpu board's secondary screen
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.common.all;
use work.fishbone.all;

entity fb_HDMI is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		SIM_NODVI							: boolean := false;
		CLOCKSPEED							: natural
	);
	port(

		CLK_48M_i							: in		std_logic;

		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;

		HDMI_SCL_io							: inout	std_logic;
		HDMI_SDA_io							: inout	std_logic;
		HDMI_HPD_i							: in		std_logic;
		HDMI_CK_o							: out		std_logic;
		HDMI_R_o								: out		std_logic;
		HDMI_G_o								: out		std_logic;
		HDMI_B_o								: out		std_logic;

		-- analogue video	

		VGA_R_o								: out		std_logic_vector(3 downto 0);
		VGA_G_o								: out		std_logic_vector(3 downto 0);
		VGA_B_o								: out		std_logic_vector(3 downto 0);
		VGA_HS_o								: out		std_logic;
		VGA_VS_o								: out		std_logic;
		VGA_BLANK_o							: out		std_logic;

		-- retimed analogue video
		VGA27_R_o							: out		std_logic_vector(3 downto 0);
		VGA27_G_o							: out		std_logic_vector(3 downto 0);
		VGA27_B_o							: out		std_logic_vector(3 downto 0);
		VGA27_HS_o							: out		std_logic;
		VGA27_VS_o							: out		std_logic;
		VGA27_BLANK_o						: out		std_logic;

		-- sysvia scroll registers
		scroll_latch_c_i					: in		std_logic_vector(1 downto 0);


		PCM_L_i								: in		signed(9 downto 0);

		debug_vsync_det_o			: out std_logic;
		debug_hsync_det_o			: out std_logic;
		debug_hsync_crtc_o			: out std_logic;
		debug_odd_o					: out std_logic


	);
end fb_HDMI;



architecture rtl of fb_hdmi is

	--=========== FISHBONE ============--

	constant PERIPHERAL_COUNT 				: positive := 7;
	constant PERIPHERAL_N_MEM 				: natural := 0;
	constant PERIPHERAL_N_VIDPROC 		: natural := 1;
	constant PERIPHERAL_N_CRTC 			: natural := 2;
	constant PERIPHERAL_N_I2C				: natural := 3;
	constant PERIPHERAL_N_HDMI_CTL		: natural := 4;
	constant PERIPHERAL_N_SEQ_CTL			: natural := 5;
	constant PERIPHERAL_N_SPRITES			: natural := 6;
	
	-- intcon peripheral->controller
	signal i_per_c2p_intcon				: fb_con_o_per_i_arr(PERIPHERAL_COUNT-1 downto 0);
	signal i_per_p2c_intcon				: fb_con_i_per_o_arr(PERIPHERAL_COUNT-1 downto 0);
		-- intcon to peripheral sel
	signal i_intcon_peripheral_sel_addr	: std_logic_vector(23 downto 0);	
	signal i_intcon_peripheral_sel			: unsigned(numbits(PERIPHERAL_COUNT)-1 downto 0);  -- address decoded selected peripheral
	signal i_intcon_peripheral_sel_oh		: std_logic_vector(PERIPHERAL_COUNT-1 downto 0);	-- address decoded selected peripherals as one-hot		

	signal i_ram_fb_m2s					: fb_con_o_per_i_t;
	signal i_ram_fb_s2m					: fb_con_i_per_o_t;
	signal i_crtc_fb_m2s					: fb_con_o_per_i_t;
	signal i_crtc_fb_s2m					: fb_con_i_per_o_t;
	signal i_vidproc_fb_m2s				: fb_con_o_per_i_t;
	signal i_vidproc_fb_s2m				: fb_con_i_per_o_t;
	signal i_i2c_fb_m2s					: fb_con_o_per_i_t;
	signal i_i2c_fb_s2m					: fb_con_i_per_o_t;
	signal i_hdmictl_fb_m2s				: fb_con_o_per_i_t;
	signal i_hdmictl_fb_s2m				: fb_con_i_per_o_t;
	signal i_seqctl_fb_c2p				: fb_con_o_per_i_t;
	signal i_seqctl_fb_p2c				: fb_con_i_per_o_t;
	signal i_sprites_fb_c2p				: fb_con_o_per_i_t;
	signal i_sprites_fb_p2c				: fb_con_i_per_o_t;


	-- DVI PLL
	signal i_clk_hdmi_pixel				: std_logic;
	signal i_clk_hdmi_tmds				: std_logic;

	--========== LOCAL VIDEO =========--
	signal i_D_pxbyte 					: std_logic_vector(7 downto 0);

	signal i_RAM_A							: std_logic_vector(16 downto 0);
	signal i_RAM_Q							: std_logic_vector(7 downto 0);

	signal i_RAMA_PLANE0					: std_logic_vector(16 downto 0);
	signal r_RAMD_PLANE0					: std_logic_vector(7 downto 0);
	signal i_RAMA_PLANE1					: std_logic_vector(16 downto 0);
	signal r_RAMD_PLANE1					: std_logic_vector(7 downto 0);
	signal i_RAMA_FONT					: std_logic_vector(16 downto 0);
	signal r_RAMD_FONT					: std_logic_vector(7 downto 0);

	signal i_clken_crtc					: std_logic;

	-- RGB signals out of ULA
	signal i_ULA_R							: std_logic_vector(3 downto 0);
	signal i_ULA_G							: std_logic_vector(3 downto 0);
	signal i_ULA_B							: std_logic_vector(3 downto 0);

	-- SYNC signals out of CRTC
	signal i_vsync_CRTC					: std_logic;
	signal i_hsync_CRTC					: std_logic;
	signal i_disen_CRTC					: std_logic;
	signal i_cursor_CRTC					: std_logic;

	signal i_crtc_MA						: std_logic_vector(13 downto 0);
	signal i_crtc_RA						: std_logic_vector(4 downto 0);

	signal i_vsync_DVI					: std_logic;
	signal i_hsync_DVI					: std_logic;
	signal i_blank_DVI					: std_logic;


	signal i_R_DVI							: std_logic_vector(7 downto 0);
	signal i_G_DVI							: std_logic_vector(7 downto 0);
	signal i_B_DVI							: std_logic_vector(7 downto 0);

	signal i_R_encoded					: std_logic_vector(9 downto 0);
	signal i_G_encoded					: std_logic_vector(9 downto 0);
	signal i_B_encoded					: std_logic_vector(9 downto 0);


	signal i_audio							: std_logic_vector(15 downto 0);

	signal i_avi							: std_logic_vector(111 downto 0);

	signal i_R_TTX							: std_logic;
	signal i_G_TTX							: std_logic;
	signal i_B_TTX							: std_logic;
	signal i_TTX							: std_logic;

	signal r_ttx_pixel_clken			: std_logic_vector(3 downto 0) := "1000";

	signal i_pixel_double				: std_logic;
	signal i_audio_enable				: std_logic;
	signal r_pix_audio_enable			: std_logic;

	signal i_ttxt_di_clken				: std_logic;

	-- extras for ANSI mode

	signal i_seq_alphamode				: std_logic;
	signal i_seq_alphaaddrfontA		: std_logic_vector(7 downto 0);

	signal i_aa								: unsigned(3 downto 0);

	-- sprites

	signal i_sprite_pixel_cken			: std_logic;		-- this in vidproc (48MHZ domain)

	component hdmi_out_altera_max10 is
	   port (
      clock_pixel_i     : in std_logic;   -- x1
      clock_tdms_i      : in std_logic;   -- x5
      red_i             : in  std_logic_vector(9 downto 0);
      green_i           : in  std_logic_vector(9 downto 0);
      blue_i            : in  std_logic_vector(9 downto 0);      
      red_s             : out std_logic;
      green_s           : out std_logic;
      blue_s            : out std_logic;
      clock_s           : out std_logic
   );
	end component;

	component hdmi is 
	   generic (
      FREQ: integer := 27000000;              -- pixel clock frequency
      FS: integer := 48000;                   -- audio sample rate - should be 32000, 44100 or 48000
      CTS: integer := 27000;                  -- CTS = Freq(pixclk) * N / (128 * Fs)
      N: integer := 6144                      -- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300
                          -- Check HDMI spec 7.2 for details
   );
   port (
      -- clocks
      I_CLK_PIXEL    : in std_logic;
      -- components
      I_R            : in std_logic_vector(7 downto 0);
      I_G            : in std_logic_vector(7 downto 0);
      I_B            : in std_logic_vector(7 downto 0);
      I_BLANK        : in std_logic;
      I_HSYNC        : in std_logic;
      I_VSYNC        : in std_logic;
--      I_ASPECT_169   : in std_logic;
      I_AVI_DATA     : in std_logic_vector(111 downto 0);
      -- PCM audio
      I_AUDIO_ENABLE : in std_logic;
      I_AUDIO_PCM_L  : in std_logic_vector(15 downto 0);
      I_AUDIO_PCM_R  : in std_logic_vector(15 downto 0);
      -- TMDS parallel pixel synchronous outputs (serialize LSB first)
      O_RED       : out std_logic_vector(9 downto 0); -- Red
      O_GREEN        : out std_logic_vector(9 downto 0); -- Green
      O_BLUE         : out std_logic_vector(9 downto 0)  -- Blue
	);
	end component;

begin

	VGA27_R_o 		<= i_R_DVI(7 downto 4);
	VGA27_G_o 		<= i_G_DVI(7 downto 4);
	VGA27_B_o 		<= i_B_DVI(7 downto 4);
	VGA27_VS_o 		<= i_vsync_DVI;
	VGA27_HS_o 		<= i_hsync_DVI;
	VGA27_BLANK_o 	<= i_blank_DVI;

	VGA_R_o 			<= i_ULA_R;
	VGA_G_o 			<= i_ULA_G;
	VGA_B_o 			<= i_ULA_B;
	VGA_VS_o 		<= i_vsync_CRTC;
	VGA_HS_o 		<= i_hsync_CRTC;
	VGA_BLANK_o 	<= not i_disen_CRTC;

	g_sim_pll:if SIM generate

		g_hdmi_pixel:if not SIM_NODVI generate
			p_pll_hdmi_pixel: process
			begin
				i_clk_hdmi_pixel <= '1';
				wait for 18.5 ns;
				i_clk_hdmi_pixel <= '0';
				wait for 18.5 ns;
			end process;
		end generate;

		p_pll_hdmi_tmds: process
		begin
			i_clk_hdmi_tmds <= '1';
			wait for 3.7 ns;
			i_clk_hdmi_tmds <= '0';
			wait for 3.7 ns;
		end process;

	end generate;

	g_not_sim_pll:if not SIM generate

		e_pll_hdmi: entity work.pll_hdmi
		port map(
			inclk0 => CLK_48M_i,
			c1 => i_clk_hdmi_pixel,
			c0 => i_clk_hdmi_tmds
		);
	end generate;


	e_vidproc:entity work.fb_HDMI_vidproc
	generic map (
		SIM => SIM
	)
	port map(
		fb_syscon_i			=> fb_syscon_i,
		fb_c2p_i				=> i_vidproc_fb_m2s,
		fb_p2c_o				=> i_vidproc_fb_s2m,

		CLK_48M_i			=> CLK_48M_i,

		CLKEN_CRTC_o		=> i_clken_crtc,
		RAM_D0_i				=> i_D_pxbyte,
		nINVERT_i			=> '1',
		DISEN_i				=> i_disen_CRTC,
		CURSOR_i				=> i_cursor_CRTC,
		R_TTX_i				=> i_R_TTX,
		G_TTX_i				=> i_G_TTX,
		B_TTX_i				=> i_B_TTX,
		R_o					=> i_ULA_R,
		G_o					=> i_ULA_G,
		B_o					=> i_ULA_B,

		TTX_o					=> i_TTX,

		-- model B/C extras
	   MODE_ATTR_i 		=> i_seq_alphamode,
		RAM_D1_i				=> r_RAMD_PLANE1,
		
		SPR_PX_CLKEN		=> i_sprite_pixel_cken

	);



	e_crtc:entity work.fb_HDMI_crtc
	generic map (
		SIM				=> SIM
	)
	port map (

		fb_syscon_i			=> fb_syscon_i,
		fb_c2p_i				=> i_crtc_fb_m2s,
		fb_p2c_o				=> i_crtc_fb_s2m,
		CLKEN_CRTC_i		=> i_clken_crtc,
		
		-- Display interface
		VSYNC_o				=> i_vsync_CRTC,
		HSYNC_o				=> i_hsync_CRTC,
		DE_o					=> i_disen_CRTC,
		CURSOR_o				=> i_cursor_CRTC,
		LPSTB_i				=> '0',
		
		-- Memory interface
		MA_o					=> i_crtc_MA,
		RA_o					=> i_crtc_RA

	);

	p_ttx_px_clk:process(CLK_48M_i)
	begin
		if rising_edge(CLK_48M_i) then
			r_ttx_pixel_clken <= r_ttx_pixel_clken(0) & r_ttx_pixel_clken(r_ttx_pixel_clken'high downto 1);
		end if;
	end process;

	e_ttx:entity work.saa5050
	port map (
    CLOCK       => CLK_48M_i,
    -- 6 MHz dot clock enable
    CLKEN       => r_ttx_pixel_clken(0),
    -- Async reset
    nRESET      => not fb_syscon_i.rst,

    -- Indicates special VGA Mode 7 (720x576p)
    VGA         => '0',

    -- Character data input (in the bus clock domain)
    DI_CLOCK    => fb_syscon_i.clk,
    DI_CLKEN    => i_ttxt_di_clken,
    DI          => i_D_pxbyte(6 downto 0),

    -- Timing inputs
    -- General line reset (not used)
    GLR         => not i_hsync_CRTC,
    -- Data entry window - high during VSYNC.
    -- Resets ROM row counter and drives 'flash' signal
    DEW         => i_vsync_CRTC,
    -- Character rounding select - high during even field
    CRS         => not i_crtc_RA(0),
    -- Load output shift register enable - high during active video
    LOSE        => i_disen_CRTC,

    -- Video out
    R           => i_R_TTX,
    G           => i_G_TTX,
    B           => i_B_TTX,
    Y           => open

    );


	p_ttx_di:process(fb_syscon_i)
	variable vr_delay : std_logic_vector(30 downto 0);
	begin
		if fb_syscon_i.rst = '1' then
			vr_delay := (others => '0');
			i_ttxt_di_clken <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			i_ttxt_di_clken <= vr_delay(vr_delay'high);
			vr_delay(vr_delay'high downto 1) := vr_delay(vr_delay'high-1 downto 0);
			vr_delay(0) := i_clken_crtc;
		end if;
	end process;


	e_hdmi_ram:entity work.fb_HDMI_ram
	generic map (
		SIM => SIM
	)
	port map(

		fb_syscon_i		=> fb_syscon_i,
		fb_c2p_i			=> i_ram_fb_m2s,
		fb_p2c_o			=> i_ram_fb_s2m,
	
		-- vga signals
	
		hdmi_ram_clk_i		=> fb_syscon_i.clk,
		hdmi_ram_addr_i	=> i_RAM_A,
		hdmi_ram_Q_o		=> i_RAM_Q
	
	);

	e_hdmi_ctl:entity work.fb_hdmi_ctl
	generic map (
		SIM => SIM
	)
	port map(

		fb_syscon_i		=> fb_syscon_i,
		fb_c2p_i			=> i_hdmictl_fb_m2s,
		fb_p2c_o			=> i_hdmictl_fb_s2m,
	
		avi_o				=> i_avi,
		audio_enable_o => i_audio_enable,
		pixel_double_o	=> i_pixel_double
	
	);

	e_hdmi_seq_ctrl:entity work.fb_HDMI_seq_ctl
	generic map (
		SIM					=> SIM
	)
	port map (
		fb_syscon_i			=> fb_syscon_i,
		fb_c2p_i				=> i_seqctl_fb_c2p,
		fb_p2c_o				=> i_seqctl_fb_p2c,
	
		mode_alpha_o		=> i_seq_alphamode,
		addr_alpha_fontA	=> i_seq_alphaaddrfontA
	);



	e_fb_i2c:entity work.fb_i2c
	generic map (
		SIM									=> SIM,
		CLOCKSPEED							=> CLOCKSPEED
	)
	port map (

		-- eeprom signals
		I2C_SCL_io							=> HDMI_SCL_io,
		I2C_SDA_io							=> HDMI_SDA_io,

		-- fishbone signals

		fb_syscon_i							=> fb_syscon_i,
		fb_c2p_i								=> i_i2c_fb_m2s,
		fb_p2c_o								=> i_i2c_fb_s2m
	);




	
--====================================================================
-- DVI 
--====================================================================

	G_DVI:IF NOT SIM_NODVI generate
		e_synch:entity work.dvi_synchro
		port map (

			fb_syscon_i		=> fb_syscon_i,
			CLK_48M_i		=> CLK_48M_i,
			pixel_double_i => i_pixel_double,

			-- input signals in the local clock domain
			VSYNC_CRTC_i	=> i_vsync_CRTC,
			HSYNC_CRTC_i	=> i_hsync_CRTC,
			DISEN_CRTC_i	=> i_disen_CRTC,

			R_ULA_i			=> i_ULA_R,
			G_ULA_i			=> i_ULA_G,
			B_ULA_i			=> i_ULA_B,

			TTX_i				=> i_TTX,

			-- synchronised / generated / conditioned signals in DVI pixel clock domain

			clk_pixel_dvi => i_clk_hdmi_pixel,

			VSYNC_DVI_o		=> i_vsync_dvi,
			HSYNC_DVI_o		=> i_hsync_dvi,
			BLANK_DVI_o		=> i_blank_dvi,

			R_DVI_o			=> i_R_DVI,
			G_DVI_o			=> i_G_DVI,
			B_DVI_o			=> i_B_DVI,

			debug_hsync_det_o 	=> debug_hsync_det_o,
			debug_vsync_det_o 	=> debug_vsync_det_o,
			debug_hsync_crtc_o	=> debug_hsync_crtc_o,
			debug_odd_o 		=> debug_odd_o

		);
	end generate;

G_NOTSIM_SERIAL:IF NOT SIM GENERATE

	-- re-register in other clock domain - TODO: remove?
	p_r:process(i_clk_hdmi_pixel)
	begin
		if rising_edge(i_clk_hdmi_pixel) then
			r_pix_audio_enable <= i_audio_enable;
		end if;

	end process;

	e_spirkov:hdmi
	port map (
		I_CLK_PIXEL => i_clk_hdmi_pixel,
		I_R => i_R_DVI,
		I_G => i_G_DVI,
		I_B => i_B_DVI,
		I_BLANK => i_blank_DVI,
		I_HSYNC => i_hsync_DVI,
		I_VSYNC => i_vsync_DVI,
--		I_ASPECT_169 => r_fbhdmi_169,
		I_AVI_DATA => i_avi,

		I_AUDIO_ENABLE => r_pix_audio_enable,
		I_AUDIO_PCM_L => i_audio,
		I_AUDIO_PCM_R => i_audio,

		O_RED => i_R_encoded,
		O_GREEN => i_G_encoded,
		O_BLUE => i_B_encoded
	);



	e_hdmi_serial:hdmi_out_altera_max10
	port map (
		clock_pixel_i => i_clk_hdmi_pixel,
		clock_tdms_i => i_clk_hdmi_tmds,
		red_i => i_R_encoded,
		green_i => i_G_encoded,
		blue_i => i_B_encoded,
		red_s => HDMI_R_o,
		green_s => HDMI_G_o,
		blue_s => HDMI_B_o,
		clock_s => HDMI_CK_o
	);

	p_snd:process(i_clk_hdmi_pixel)
	begin
		if rising_edge(i_clk_hdmi_pixel) then
			i_audio <= std_logic_vector(PCM_L_i) & "000000";
		end if;
	end process;


END GENERATE;

--====================================================================
-- Screen address calculations and other "sequencer stuff" - TODO: move to separate module?
--====================================================================

-- TODO: improve teletext detect (out from vidproc or keep MA13?)
-- TODO: mode 15/80 cols teletext


	-- Address translation logic for calculation of display address
	i_aa <= unsigned(i_crtc_ma(11 downto 8)) when i_crtc_ma(12) = '0' else
			  unsigned(i_crtc_ma(11 downto 8)) + 8 when scroll_latch_c_i = "00" else
			  unsigned(i_crtc_ma(11 downto 8)) + 12 when scroll_latch_c_i = "01" else
			  unsigned(i_crtc_ma(11 downto 8)) + 6 when scroll_latch_c_i = "10" else
			  unsigned(i_crtc_ma(11 downto 8)) + 11;

	i_RAMA_PLANE0 <= 	"0011111" & i_crtc_ma(9 downto 0) when i_TTX = '1' else
							"00111" & i_crtc_ma(10 downto 0) & '0' when i_seq_alphamode = '1' else
							"00" & std_logic_vector(i_aa(3 downto 0)) & i_crtc_ma(7 downto 0) & i_crtc_ra(2 downto 0);			

	i_RAMA_PLANE1 <= 	(others => '1') when i_TTX = '1' else
							"00111" & i_crtc_ma(10 downto 0) & '1' when i_seq_alphamode = '1' else
							(others => '1');


	-- in alpha mode the address of the next set of pixels looked up from font loaded at 3000
	i_RAMA_FONT <= i_seq_alphaaddrfontA(4 downto 0) & r_RAMD_PLANE0 & i_crtc_ra(3 downto 0);


	p_seq:process(fb_syscon_i)
	variable v_seq:unsigned(3 downto 0);
	begin
		if rising_edge(fb_syscon_i.clk) then
			if i_clken_crtc = '1' then
				v_seq := (others => '0');
			elsif v_seq /= "1111" then
				v_seq := v_seq + 1;
			end if;

			case to_integer(v_seq) is
				when 2 =>
					i_RAM_A <= i_RAMA_PLANE0;
				when 4 =>
					r_RAMD_PLANE0 <= i_RAM_Q;
					i_RAM_A <= i_RAMA_PLANE1;
				when 6 =>
					i_RAM_A <= i_RAMA_FONT;
					r_RAMD_PLANE1 <= i_RAM_Q;
				when 8 =>
					r_RAMD_FONT <= i_RAM_Q;
				when others =>
					null;
			end case;
		end if;					
	end process;

	i_D_pxbyte <= 	r_RAMD_FONT when i_seq_alphamode = '1' else
						r_RAMD_PLANE0;
--====================================================================
-- Sprites
--====================================================================

	e_sprites:entity work.fb_sprites
	generic map (
		SIM									=> SIM,
		G_N_SPRITES							=> 8
	)
	port map (

		-- fishbone signals for cpu/dma port

		fb_syscon_i							=> fb_syscon_i,
		fb_c2p_i								=> i_sprites_fb_c2p,
		fb_p2c_o								=> i_sprites_fb_p2c,

		-- data interface, from sequencer
		SEQ_D_i								=> (others => '-'),
		SEQ_wren_i							=> '0',
		SEQ_A_i								=> (others => '0'),
																								-- sprite data A..D, pos/ctl, ptr, lst (see below in p_regs)
		SEQ_DATAPTR_inc_i					=> (others => '0'),
																								-- increment pointer this clock
		-- addresses out to sequencer
		SEQ_DATAPTR_A_o					=> open,


		-- vidproc / crtc signals in

		pixel_clk_i							=> CLK_48M_i,
		vsync_i								=> i_vsync_CRTC,
		hsync_i								=> i_hsync_CRTC,
		disen_i								=> i_disen_CRTC,
		pixel_clken_i						=> i_sprite_pixel_cken,
		
		-- pixels out
		pixel_act_o							=> open,
		pixel_o								=> open
	

	);


--====================================================================
-- FISHBONE interconnection
--====================================================================

	i_ram_fb_m2s <= i_per_c2p_intcon(PERIPHERAL_N_MEM);
	i_vidproc_fb_m2s <= i_per_c2p_intcon(PERIPHERAL_N_VIDPROC);
	i_crtc_fb_m2s <= i_per_c2p_intcon(PERIPHERAL_N_CRTC);
	i_i2c_fb_m2s <= i_per_c2p_intcon(PERIPHERAL_N_I2C);
	i_hdmictl_fb_m2s <= i_per_c2p_intcon(PERIPHERAL_N_HDMI_CTL);
	i_seqctl_fb_c2p <= i_per_c2p_intcon(PERIPHERAL_N_SEQ_CTL);
	i_sprites_fb_c2p <= i_per_c2p_intcon(PERIPHERAL_N_SPRITES);

	i_per_p2c_intcon(PERIPHERAL_N_MEM) <= i_ram_fb_s2m;
	i_per_p2c_intcon(PERIPHERAL_N_VIDPROC) <= i_vidproc_fb_s2m;
	i_per_p2c_intcon(PERIPHERAL_N_CRTC) <= i_crtc_fb_s2m;
	i_per_p2c_intcon(PERIPHERAL_N_I2C) <= i_i2c_fb_s2m;
	i_per_p2c_intcon(PERIPHERAL_N_HDMI_CTL) <= i_hdmictl_fb_s2m;
	i_per_p2c_intcon(PERIPHERAL_N_SEQ_CTL) <= i_seqctl_fb_p2c;
	i_per_p2c_intcon(PERIPHERAL_N_SPRITES) <= i_sprites_fb_p2c;



	e_fb_intcon: entity work.fb_intcon_one_to_many
	generic map (
		SIM 									=> SIM,
		G_PERIPHERAL_COUNT 						=> PERIPHERAL_COUNT,
		G_ADDRESS_WIDTH 					=> 24
		)
	port map (
		fb_syscon_i 						=> fb_syscon_i,

		-- peripheral ports connect to controllers
		fb_con_c2p_i						=> fb_c2p_i,
		fb_con_p2c_o						=> fb_p2c_o,

		-- controller ports connect to peripherals
		fb_per_c2p_o						=> i_per_c2p_intcon,
		fb_per_p2c_i						=> i_per_p2c_intcon,

		peripheral_sel_addr_o			=> i_intcon_peripheral_sel_addr,
		peripheral_sel_i					=> i_intcon_peripheral_sel,
		peripheral_sel_oh_i				=> i_intcon_peripheral_sel_oh
	);

	p_sel:process(i_intcon_peripheral_sel_addr)
	begin
		i_intcon_peripheral_sel_oh <= (others => '0');


		-- official addresses:
		-- FB FFxx - Sprites
		-- FB FE00, FE01 - CRTC		(IX, DAT)
		-- FB FE02, FE03 - SEQ CTL	(IX, DAT)
		-- FB FE2x - VIDPROC
		-- FB FEDx - i2c
		-- FB FEEx - HDMI control
		if i_intcon_peripheral_sel_addr(16 downto 8) = "1" & x"FF" then
			-- sprites
			i_intcon_peripheral_sel <= to_unsigned(PERIPHERAL_N_SPRITES, numbits(PERIPHERAL_COUNT));
			i_intcon_peripheral_sel_oh(PERIPHERAL_N_SPRITES) <= '1';		
		elsif i_intcon_peripheral_sel_addr(16 downto 8) = "1" & x"FE" then
			if i_intcon_peripheral_sel_addr(7 downto 4) = x"E" then
				i_intcon_peripheral_sel <= to_unsigned(PERIPHERAL_N_HDMI_CTL, numbits(PERIPHERAL_COUNT));
				i_intcon_peripheral_sel_oh(PERIPHERAL_N_HDMI_CTL) <= '1';		
			elsif i_intcon_peripheral_sel_addr(7 downto 4) = x"D" then
				i_intcon_peripheral_sel <= to_unsigned(PERIPHERAL_N_I2C, numbits(PERIPHERAL_COUNT));
				i_intcon_peripheral_sel_oh(PERIPHERAL_N_I2C) <= '1';		
			elsif i_intcon_peripheral_sel_addr(7 downto 4) = x"2" then
				i_intcon_peripheral_sel <= to_unsigned(PERIPHERAL_N_VIDPROC, numbits(PERIPHERAL_COUNT));
				i_intcon_peripheral_sel_oh(PERIPHERAL_N_VIDPROC) <= '1';
			elsif i_intcon_peripheral_sel_addr(7 downto 1) = x"0" & "000" then
				i_intcon_peripheral_sel <= to_unsigned(PERIPHERAL_N_CRTC, numbits(PERIPHERAL_COUNT));
				i_intcon_peripheral_sel_oh(PERIPHERAL_N_CRTC) <= '1';				
			else
				i_intcon_peripheral_sel <= to_unsigned(PERIPHERAL_N_SEQ_CTL, numbits(PERIPHERAL_COUNT));
				i_intcon_peripheral_sel_oh(PERIPHERAL_N_SEQ_CTL) <= '1';				
			end if;
		else
			i_intcon_peripheral_sel <= to_unsigned(PERIPHERAL_N_MEM, numbits(PERIPHERAL_COUNT));
			i_intcon_peripheral_sel_oh(PERIPHERAL_N_MEM) <= '1';
		end if;
	end process;

end rtl;


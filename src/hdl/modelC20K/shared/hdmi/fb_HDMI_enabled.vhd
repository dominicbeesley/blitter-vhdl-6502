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
use work.sprites_pack.all;

entity fb_HDMI is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		SIM_NODVI							: boolean := false;
		CLOCKSPEED							: natural;
		G_N_SPRITES							: natural := 4;
		G_EXT_TMDS_CLOCKS					: boolean := false
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


		-- sound in 
		PCM_L_i								: in		signed(15 downto 0);
		PCM_R_i								: in		signed(15 downto 0);

		-- debug
		debug_vsync_det_o					: out std_logic;
		debug_hsync_det_o					: out std_logic;
		debug_hsync_crtc_o				: out std_logic;
		debug_odd_o							: out std_logic;
		debug_spr_mem_clken_o			: out std_logic;

		-- external clocks (optional)
		clk_ext_hdmi_pixel_i				: in std_logic := '1';
		clk_ext_hdmi_tmds_i				: in std_logic := '1'


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



	--========== LOCAL VIDEO =========--
	signal i_VIDRAM_A						: std_logic_vector(16 downto 0);
	signal i_VIDRAM_Q						: std_logic_vector(7 downto 0);

	signal i_RAMD_PLANE0					: std_logic_vector(7 downto 0);
	signal i_RAMD_PLANE1					: std_logic_vector(7 downto 0);

	signal i_clken48_crtc				: std_logic;
	signal i_clken48_spr					: std_logic;
	signal i_reset48						: std_logic;

	-- RGB signals out of ULA
	signal i_ULA_R							: std_logic_vector(3 downto 0);
	signal i_ULA_G							: std_logic_vector(3 downto 0);
	signal i_ULA_B							: std_logic_vector(3 downto 0);

	-- SYNC signals out of CRTC
	signal i_vsync_CRTC					: std_logic;
	signal i_hsync_CRTC					: std_logic;
	signal i_disen_CRTC					: std_logic;			-- disen is  gated by RA (mode 3/6)
	signal i_disen_CRTC_U				: std_logic;			-- disen not gated by RA (mode 3/6)
	signal i_disen_VIDPROC				: std_logic;			-- disen not gated by RA (mode 3/6), with vidproc delay
	signal i_cursor_CRTC					: std_logic;

	signal i_crtc_MA						: std_logic_vector(13 downto 0);
	signal i_crtc_RA						: std_logic_vector(4 downto 0);


	signal i_avi							: std_logic_vector(111 downto 0);
	signal i_ILACE							: std_logic;

	signal i_R_TTX							: std_logic;
	signal i_G_TTX							: std_logic;
	signal i_B_TTX							: std_logic;
	signal i_TTX							: std_logic;
	signal i_TTX80							: std_logic;		-- 80 column teletext

	signal r_ttx_pixel_clken			: std_logic_vector(3 downto 0) := "1000";
	signal i_ttx_pixel_clken			: std_logic;
	signal i_ttx_pixde					: std_logic;	-- display enable after pass through saa5050

	signal i_pixel_double				: std_logic;
	signal r_pixel_double_48			: std_logic;	-- reclock in 48M clock
	signal i_audio_enable				: std_logic;

	signal i_txt_data						: std_logic_vector(6 downto 0);
	signal i_txt_lose						: std_logic;
	signal i_ttxt_di_clken				: std_logic;

	-- extras for ANSI mode

	signal i_seq_alphamode				: std_logic;
	signal i_seq_alphaaddrfontA		: std_logic_vector(7 downto 0);
	signal r_seq_alphamode48			: std_logic;
	signal r_seq_alphaaddrfontA48		: std_logic_vector(7 downto 0);

	signal r_scroll_latch_c_48			: std_logic_vector(1 downto 0);


	-- sprites

	signal i_sprite_pixel_cken			: std_logic;		-- this in vidproc (48MHZ domain)
	signal i_sprite_pixel_act			: std_logic;
	signal i_sprite_pixel_dat			: std_logic_vector(3 downto 0);

	signal i_SEQ_SPR_wren				: std_logic;
	signal i_SEQ_SPR_DATA_req			: std_logic;
	signal i_SEQ_SPR_DATAPTR_A			: t_spr_addr_array(G_N_SPRITES-1 downto 0);
	signal i_SEQ_SPR_DATAPTR_act		: std_logic_vector(G_N_SPRITES-1 downto 0);
	signal i_SEQ_SPR_A					: unsigned(numbits(G_N_SPRITES) + 3 downto 0);
	signal i_SEQ_SPR_D					: std_logic_vector(7 downto 0);
	signal i_SEQ_SPR_A_pre				: t_spr_pre_array(G_N_SPRITES-1 downto 0);


begin


	VGA_R_o 			<= i_ULA_R;
	VGA_G_o 			<= i_ULA_G;
	VGA_B_o 			<= i_ULA_B;
	VGA_VS_o 		<= i_vsync_CRTC;
	VGA_HS_o 		<= i_hsync_CRTC;
	VGA_BLANK_o 	<= not i_disen_VIDPROC;

   debug_spr_mem_clken_o <= i_clken48_spr;


	e_vidproc:entity work.fb_HDMI_vidproc
	generic map (
		SIM => SIM
	)
	port map(
		fb_syscon_i			=> fb_syscon_i,
		fb_c2p_i				=> i_vidproc_fb_m2s,
		fb_p2c_o				=> i_vidproc_fb_s2m,

		-- fishbone to 48m timing signals
		reset48_o			=> i_reset48,

		CLK_48M_i			=> CLK_48M_i,

		CLKEN_CRTC_o		=> i_clken48_crtc,
		CLKEN_SPR_o			=> i_clken48_spr,
		nINVERT_i			=> '1',
		DISEN_i				=> i_disen_CRTC,
		DISEN_U_i			=> i_disen_CRTC_U,
		CURSOR_i				=> i_cursor_CRTC,
		R_TTX_i				=> i_R_TTX,
		G_TTX_i				=> i_G_TTX,
		B_TTX_i				=> i_B_TTX,
		PIXDE_TTX_i			=> i_ttx_pixde,
		PIXCLKEN_TTX_i		=> i_ttx_pixel_clken,
		R_o					=> i_ULA_R,
		G_o					=> i_ULA_G,
		B_o					=> i_ULA_B,
		PIXCLKEN_o			=> open, -- TODO: pass on?
		PIXDE_o				=> i_disen_VIDPROC,

		TTX_o					=> i_TTX,
		TTX80_i				=> i_TTX80,

		-- model B/C extras
	   MODE_ATTR_i 		=> r_seq_alphamode48,
		RAM_D0_i				=> i_RAMD_PLANE0,
		RAM_D1_i				=> i_RAMD_PLANE1,
		
		SPR_PX_CLKEN		=> i_sprite_pixel_cken,
		SPR_PX_ACT			=> i_sprite_pixel_act,
		SPR_PX_DAT			=> i_sprite_pixel_dat

	);



	e_crtc:entity work.fb_HDMI_crtc
	generic map (
		SIM				=> SIM
	)
	port map (

		fb_syscon_i			=> fb_syscon_i,
		fb_c2p_i				=> i_crtc_fb_m2s,
		fb_p2c_o				=> i_crtc_fb_s2m,

		clock_48_i			=> CLK_48M_i,
		
		-- fishbone to 48m timing signals
		reset48_i			=> i_reset48,

		-- Display interface
		CLKEN_CRTC_i		=> i_clken48_crtc,
		VSYNC_o				=> i_vsync_CRTC,
		HSYNC_o				=> i_hsync_CRTC,
		DE_o					=> i_disen_CRTC_U,
		CURSOR_o				=> i_cursor_CRTC,
		LPSTB_i				=> '0',
		
		-- Memory interface
		MA_o					=> i_crtc_MA,
		RA_o					=> i_crtc_RA,

		ILACE_O				=> i_ILACE

	);

	i_disen_CRTC <= i_disen_CRTC_U and (not i_crtc_RA(3) or r_seq_alphamode48);

	p_ttx_px_clk:process(CLK_48M_i)
	begin
		if rising_edge(CLK_48M_i) then
			r_ttx_pixel_clken <= r_ttx_pixel_clken(0) & r_ttx_pixel_clken(r_ttx_pixel_clken'high downto 1);
		end if;
	end process;

	p_ttx80:process(CLK_48M_i)
	begin
		if rising_edge(CLK_48M_i) then
			if i_crtc_MA(12) = '1' and scroll_latch_c_i(0) = '0' then
				i_ttx80 <= '1';
			else
				i_ttx80 <= '0';
			end if;
		end if;
	end process;

	i_ttx_pixel_clken <= r_ttx_pixel_clken(0) or (r_ttx_pixel_clken(2) and i_ttx80);

	e_ttx:entity work.saa5050
	port map (
   	CLOCK       => CLK_48M_i,
   	-- 6 MHz dot clock enable
   	CLKEN       => i_ttx_pixel_clken,
   	-- Async reset
   	nRESET      => not fb_syscon_i.rst,

   	-- Indicates special VGA Mode 7 (720x576p)
   	VGA         => '0',

   	-- Character data input (in the bus clock domain)
   	DI_CLOCK    => CLK_48M_i,
   	DI_CLKEN    => i_ttxt_di_clken,
   	DI          => i_txt_data,

   	-- Timing inputs
   	-- General line reset (not used)
   	GLR         => not i_hsync_CRTC,
   	-- Data entry window - high during VSYNC.
   	-- Resets ROM row counter and drives 'flash' signal
   	DEW         => i_vsync_CRTC,
   	-- Character rounding select - high during even field
   	CRS         => not i_crtc_RA(0),
   	-- Load output shift register enable - high during active video
   	LOSE        => i_txt_lose,

   	-- Video out
   	R           => i_R_TTX,
   	G           => i_G_TTX,
   	B           => i_B_TTX,
   	Y           => open,
   	PIXDE			=> i_ttx_pixde

    );

	 -- IC15 (LS273 latch in front of SAA5050)
    process(CLK_48M_i)
    begin
        if rising_edge(CLK_48M_i) then

            i_ttxt_di_clken <= '0';
           	if i_clken48_crtc = '1' then
                i_txt_data <= i_RAMD_PLANE0(6 downto 0);
                i_txt_lose <= i_disen_CRTC_U;
                i_ttxt_di_clken <= '1';
            end if;
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
	
		hdmi_ram_clk_i		=> CLK_48M_i,
		hdmi_ram_addr_i	=> i_VIDRAM_A,
		hdmi_ram_Q_o		=> i_VIDRAM_Q
	
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
		pixel_double_o	=> i_pixel_double,

		ilace_i			=> i_ILACE
	
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

	p_seq_ctl_48:process(clk_48M_i)
	begin
		if rising_edge(CLK_48M_i) then		

			r_seq_alphamode48 <= i_seq_alphamode;
			r_seq_alphaaddrfontA48 <= i_seq_alphaaddrfontA;
		
		end if;
	end process;


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




	

	e_vidmem_seq:entity work.vidmem_sequencer
	generic map (
		SIM => SIM,
		G_N_SPRITES => G_N_SPRITES
		)
	port map (
		rst_i						=> i_reset48,
		clk_i						=> CLK_48M_i,

		scroll_latch_c_i		=> r_scroll_latch_c_48,
		ttxmode_i				=> i_TTX,
		ttx80mode_i				=> i_TTX80,

		crtc_mem_clken_i		=> i_clken48_spr,
		crtc_MA_i				=> i_crtc_MA,
		crtc_RA_i				=> i_crtc_RA,

		SEQ_alphamode_i		=> r_seq_alphamode48,
		SEQ_font_addr_A   	=> r_seq_alphaaddrfontA48,

		SEQ_SPR_DATA_req_i	=> i_SEQ_SPR_DATA_req,
		SEQ_SPR_DATAPTR_A_i	=> i_SEQ_SPR_DATAPTR_A,
		SEQ_SPR_DATAPTR_act_i=> i_SEQ_SPR_DATAPTR_act,
		SEQ_SPR_A_pre_i		=> i_SEQ_SPR_A_pre,

		SEQ_SPR_wren_o			=> i_SEQ_SPR_wren,
		SEQ_SPR_A_o				=> i_SEQ_SPR_A,
		SEQ_SPR_D_o				=> i_SEQ_SPR_D,

		RAM_D_i					=> i_VIDRAM_Q,
		RAM_A_o					=> i_VIDRAM_A,

		RAMD_PLANE0_o			=> i_RAMD_PLANE0,
		RAMD_PLANE1_o			=> i_RAMD_PLANE1

	);

p_reg_48:process(clk_48M_i)
begin
	if rising_edge(CLK_48M_i) then
		r_scroll_latch_c_48 <= scroll_latch_c_i;
	end if;
end process;


--====================================================================
-- Sprites
--====================================================================

	e_sprites:entity work.fb_sprites
	generic map (
		SIM									=> SIM,
		G_N_SPRITES							=> G_N_SPRITES
	)
	port map (

		-- fishbone signals for cpu/dma port

		fb_syscon_i							=> fb_syscon_i,
		fb_c2p_i								=> i_sprites_fb_c2p,
		fb_p2c_o								=> i_sprites_fb_p2c,

		-- clock in for all non regs, should be a multiple of pixel rate and < 2*fb clock (i.e. 48 vs 128 is enough)
		clk_48M_i							=> CLK_48M_i,
		reset48_i							=> i_reset48,

		-- data interface, from sequencer
		SEQ_D_i								=> i_SEQ_SPR_D,
		SEQ_wren_i							=> i_SEQ_SPR_wren,
		SEQ_A_i								=> i_SEQ_SPR_A,
																								-- sprite data A..D, pos/ctl, ptr, lst (see below in p_regs)
		-- addresses out to sequencer
		SEQ_DATAPTR_A_o					=> i_SEQ_SPR_DATAPTR_A,
		SEQ_DATAPTR_act_o					=> i_SEQ_SPR_DATAPTR_act,
		SEQ_DATA_req_o						=> i_SEQ_SPR_DATA_req,
		SEQ_A_pre_o							=> i_SEQ_SPR_A_pre,


		-- vidproc / crtc signals in

		vsync_i								=> i_vsync_CRTC,
		hsync_i								=> i_hsync_CRTC,
		disen_i								=> i_disen_CRTC_U,
		pixel_clken_i						=> i_sprite_pixel_cken,
		
		-- pixels out
		pixel_act_o							=> i_sprite_pixel_act,
		pixel_o								=> i_sprite_pixel_dat
	

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


--====================================================================
-- HDMI/DVI output
--====================================================================

	r_pd:process(CLK_48M_i)
	begin
		if rising_edge(CLK_48M_i) then 
			r_pixel_double_48 <= i_pixel_double;
		end if;
	end process;

	e_vid15tohdmi:entity work.vid15tohdmi
   generic map (
      SIM                           => SIM,
      SIM_NODVI                     => SIM_NODVI,
      G_EXT_TMDS_CLOCKS             => G_EXT_TMDS_CLOCKS
   )
	port map (

      HDMI_CK_o                     => HDMI_CK_o,
      HDMI_R_o                      => HDMI_R_o,
      HDMI_G_o                      => HDMI_G_o,
      HDMI_B_o                      => HDMI_B_o,

      -- video domain clock (pixels are a division of this)
      CLK_48M_i                     => CLK_48M_i,
      RESET_i                       => i_reset48,

      -- video in 15KHz line rate on 48MHz clock
      VID_R_i                       => i_ULA_R,
      VID_G_i                       => i_ULA_G,
      VID_B_i                       => i_ULA_B,
      VID_HS_i                      => i_hsync_CRTC,
      VID_VS_i                      => i_vsync_CRTC,
      VID_DISEN_i                   => i_disen_VIDPROC,
      TTX_i                         => i_TTX,
      TTX80_i								=> i_TTX80,
   
      -- sound data in (48KHz)
      PCM_L_i                       => PCM_L_i,
      PCM_R_i                       => PCM_R_i,

      -- hdmi extras in
      AVI_i                         => i_avi,
      AUDIO_EN_i                    => i_audio_enable,

      -- dvi retimer extras in
      PIXEL_DOUBLE_i                => r_pixel_double_48,

      -- retimed analogue video
      VGA27_R_o                     => VGA27_R_o,
      VGA27_G_o                     => VGA27_G_o,
      VGA27_B_o                     => VGA27_B_o,
      VGA27_HS_o                    => VGA27_HS_o,
      VGA27_VS_o                    => VGA27_VS_o,
      VGA27_BLANK_o                 => VGA27_BLANK_o,

      -- external clocks (optional)
      clk_ext_hdmi_pixel_i          => clk_ext_hdmi_pixel_i,
      clk_ext_hdmi_tmds_i           => clk_ext_hdmi_tmds_i

);

end rtl;


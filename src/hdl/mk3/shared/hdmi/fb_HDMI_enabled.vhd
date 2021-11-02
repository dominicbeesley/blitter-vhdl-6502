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
use ieee.numeric_std.all;

library work;
use work.common.all;
use work.fishbone.all;


architecture rtl of fb_hdmi is

	--=========== FISHBONE ============--

	constant PERIPHERAL_COUNT 				: positive := 4;
	constant PERIPHERAL_N_MEM 				: natural := 0;
	constant PERIPHERAL_N_VIDPROC 			: natural := 1;
	constant PERIPHERAL_N_CRTC 				: natural := 2;
	constant PERIPHERAL_N_I2C					: natural := 3;
	
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


	-- DVI PLL
	signal i_clk_hdmi_pixel				: std_logic;
	signal i_clk_hdmi_tmds				: std_logic;

	--========== LOCAL VIDEO =========--
	signal i_D_pxbyte 					: std_logic_vector(7 downto 0);
	signal i_A_pxbyte						: std_logic_vector(16 downto 0);

	signal i_clken_crtc					: std_logic;

	-- RGB signals out of ULA
	signal i_ULA_R							: std_logic_vector(7 downto 0);
	signal i_ULA_G							: std_logic_vector(7 downto 0);
	signal i_ULA_B							: std_logic_vector(7 downto 0);

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

begin

	VGA_R_o <= i_R_DVI(7);
	VGA_G_o <= i_G_DVI(7);
	VGA_B_o <= i_B_DVI(7);
	VGA_VS_o <= i_vsync_DVI;
	VGA_HS_o <= i_hsync_DVI;
	VGA_BLANK_o <= i_blank_DVI;

	e_vidproc:entity work.fb_HDMI_vidproc
	generic map (
		SIM => SIM
	)
	port map(
		fb_syscon_i		=> fb_syscon_i,
		fb_c2p_i			=> i_vidproc_fb_m2s,
		fb_p2c_o			=> i_vidproc_fb_s2m,
		CLKEN_CRTC_o	=> i_clken_crtc,
		RAM_D_i			=> i_D_pxbyte,
		nINVERT_i		=> '1',
		DISEN_i			=> i_disen_CRTC,
		CURSOR_i			=> i_cursor_CRTC,
		R_TTX_i			=> '0',
		G_TTX_i			=> '0',
		B_TTX_i			=> '0',
		R_o				=> i_ULA_R,
		G_o				=> i_ULA_G,
		B_o				=> i_ULA_B

	);

	e_crtc:entity work.fb_HDMI_crtc
	generic map (
		SIM				=> SIM
	)
	port map (

		fb_syscon_i		=> fb_syscon_i,
		fb_c2p_i			=> i_crtc_fb_m2s,
		fb_p2c_o			=> i_crtc_fb_s2m,
		CLKEN_CRTC_i	=> i_clken_crtc,
		
		-- Display interface
		VSYNC_o			=> i_vsync_CRTC,
		HSYNC_o			=> i_hsync_CRTC,
		DE_o				=> i_disen_CRTC,
		CURSOR_o			=> i_cursor_CRTC,
		LPSTB_i			=> '0',
		
		-- Memory interface
		MA_o				=> i_crtc_MA,
		RA_o				=> i_crtc_RA

	);



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
		hdmi_ram_addr_i	=> i_A_pxbyte,
		hdmi_ram_Q_o		=> i_D_pxbyte
	
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

	e_synch:entity work.dvi_synchro
	port map (
		clk_pixel_dvi => i_clk_hdmi_pixel,


		-- input signals in the local clock domain
		VSYNC_CRTC_i	=> i_vsync_CRTC,
		HSYNC_CRTC_i	=> i_hsync_CRTC,
		DISEN_CRTC_i	=> i_disen_CRTC,

		R_ULA_i			=> i_ULA_R,
		G_ULA_i			=> i_ULA_G,
		B_ULA_i			=> i_ULA_B,

		-- synchronised / generated / conditioned signals in DVI pixel clock domain

		VSYNC_DVI_o		=> i_vsync_dvi,
		HSYNC_DVI_o		=> i_hsync_dvi,
		BLANK_DVI_o		=> i_blank_dvi,

		R_DVI_o			=> i_R_DVI,
		G_DVI_o			=> i_G_DVI,
		B_DVI_o			=> i_B_DVI

	);


	e_dvid:entity work.dvid
   port map ( 
   	clk       => i_clk_hdmi_tmds,
      clk_pixel => i_clk_hdmi_pixel,
      red_p     => i_R_dvi,
      green_p   => i_G_dvi,
      blue_p    => i_B_dvi,
      blank     => i_blank_dvi,
      hsync     => i_hsync_dvi,
      vsync     => i_vsync_dvi,
      red_s     => HDMI_R_o,
      green_s   => HDMI_G_o,
      blue_s    => HDMI_B_o,
      clock_s   => HDMI_CK_o
   );


--====================================================================
-- Screen address calculations 
--====================================================================

-- TODO: improve wrapping (stuck in mode 0..2)
-- TODO: improve teletext detect (out from vidproc?)


	-- Address translation logic for calculation of display address
	process(i_crtc_ma,i_crtc_ra)
	variable aa : unsigned(3 downto 0);
	begin
		if i_crtc_ma(12) = '0' then
			-- No adjustment
			aa := unsigned(i_crtc_ma(11 downto 8));
		else
				aa := unsigned(i_crtc_ma(11 downto 8)) + 6;
		end if;
		
		if i_crtc_ma(13) = '0' then
			-- HI RES
			i_A_pxbyte <= "00" & std_logic_vector(aa(3 downto 0)) & i_crtc_ma(7 downto 0) & i_crtc_ra(2 downto 0);
		else
			-- TTX VDU
			i_A_pxbyte <= "00" & std_logic(aa(3)) & "1111" & i_crtc_ma(9 downto 0);
		end if;
	end process;



--====================================================================
-- FISHBONE interconnection
--====================================================================

	i_ram_fb_m2s <= i_per_c2p_intcon(PERIPHERAL_N_MEM);
	i_vidproc_fb_m2s <= i_per_c2p_intcon(PERIPHERAL_N_VIDPROC);
	i_crtc_fb_m2s <= i_per_c2p_intcon(PERIPHERAL_N_CRTC);
	i_i2c_fb_m2s <= i_per_c2p_intcon(PERIPHERAL_N_I2C);

	i_per_p2c_intcon(PERIPHERAL_N_MEM) <= i_ram_fb_s2m;
	i_per_p2c_intcon(PERIPHERAL_N_VIDPROC) <= i_vidproc_fb_s2m;
	i_per_p2c_intcon(PERIPHERAL_N_CRTC) <= i_crtc_fb_s2m;
	i_per_p2c_intcon(PERIPHERAL_N_I2C) <= i_i2c_fb_s2m;


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

		peripheral_sel_addr_o					=> i_intcon_peripheral_sel_addr,
		peripheral_sel_i							=> i_intcon_peripheral_sel,
		peripheral_sel_oh_i						=> i_intcon_peripheral_sel_oh
	);

	p_sel:process(i_intcon_peripheral_sel_addr)
	begin
		i_intcon_peripheral_sel_oh <= (others => '0');


		-- official addresses:
		-- FB FE00, FE01 - CRTC
		-- FB FE2x - VIDPROC
		-- FB FEDx - i2c
		if i_intcon_peripheral_sel_addr(16 downto 8) = "1" & x"FE" then
			if i_intcon_peripheral_sel_addr(7) = '1' then
				i_intcon_peripheral_sel <= to_unsigned(PERIPHERAL_N_I2C, numbits(PERIPHERAL_COUNT));
				i_intcon_peripheral_sel_oh(PERIPHERAL_N_I2C) <= '1';		
			elsif i_intcon_peripheral_sel_addr(5) = '1' then
				i_intcon_peripheral_sel <= to_unsigned(PERIPHERAL_N_VIDPROC, numbits(PERIPHERAL_COUNT));
				i_intcon_peripheral_sel_oh(PERIPHERAL_N_VIDPROC) <= '1';
			else
				i_intcon_peripheral_sel <= to_unsigned(PERIPHERAL_N_CRTC, numbits(PERIPHERAL_COUNT));
				i_intcon_peripheral_sel_oh(PERIPHERAL_N_CRTC) <= '1';				
			end if;
		else
			i_intcon_peripheral_sel <= to_unsigned(PERIPHERAL_N_MEM, numbits(PERIPHERAL_COUNT));
			i_intcon_peripheral_sel_oh(PERIPHERAL_N_MEM) <= '1';
		end if;
	end process;


	g_sim_pll:if SIM generate

		p_pll_hdmi_pixel: process
		begin
			i_clk_hdmi_pixel <= '1';
			wait for 18.5 ns;
			i_clk_hdmi_pixel <= '0';
			wait for 18.5 ns;
		end process;

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





end rtl;


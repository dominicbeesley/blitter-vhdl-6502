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

entity fb_HDMI is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
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

		-- debug video	

		VGA_R_o								: out		std_logic;
		VGA_G_o								: out		std_logic;
		VGA_B_o								: out		std_logic;
		VGA_HS_o								: out		std_logic;
		VGA_VS_o								: out		std_logic;
		VGA_BLANK_o							: out		std_logic;

		PCM_L_i								: in		signed(9 downto 0)

	);
end fb_HDMI;



architecture rtl of fb_hdmi is

	-- noddy test card gen
	
	signal r_ctr_x							: unsigned(10 downto 0) := (others => '0');
	signal r_ctr_y							: unsigned(9 downto 0) := (others => '0');
	signal r_ctr_y_log					: unsigned(9 downto 0) := (others => '0');


	-- DVI PLL
	signal i_clk_hdmi_pixel				: std_logic;
	signal i_clk_hdmi_tmds				: std_logic;

	signal i_vsync_DVI					: std_logic;
	signal i_hsync_DVI					: std_logic;
	signal i_blank_DVI					: std_logic;

	signal r_vsync_DVI					: std_logic;
	signal r_hsync_DVI					: std_logic;
	signal r_blank_DVI					: std_logic;


	signal i_R_DVI							: std_logic_vector(7 downto 0);
	signal i_G_DVI							: std_logic_vector(7 downto 0);
	signal i_B_DVI							: std_logic_vector(7 downto 0);

	signal r_R_DVI							: std_logic_vector(7 downto 0);
	signal r_G_DVI							: std_logic_vector(7 downto 0);
	signal r_B_DVI							: std_logic_vector(7 downto 0);

	signal i_R_encoded					: std_logic_vector(9 downto 0);
	signal i_G_encoded					: std_logic_vector(9 downto 0);
	signal i_B_encoded					: std_logic_vector(9 downto 0);


	signal i_audio							: std_logic_vector(15 downto 0);

begin

	VGA_R_o <= r_R_DVI(7);
	VGA_G_o <= r_G_DVI(7);
	VGA_B_o <= r_B_DVI(7);
	VGA_VS_o <= r_vsync_DVI;
	VGA_HS_o <= r_hsync_DVI;
	VGA_BLANK_o <= r_blank_DVI;



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


	-- CEA-861-D 1440x576i/50 @27M (21)
	-- measured from start of HS by line, lines in r_ctr_y are numbered as in CEA-861-D minus 1 i.e. 0 to 624 (instead of 1 to 625)

	p_screengen:process(i_clk_hdmi_pixel)
	begin
		if rising_edge(i_clk_hdmi_pixel) then
			if r_ctr_x = 1727 then
				r_ctr_x <= (others => '0');
				if r_ctr_y = 624 then
					r_ctr_y <= (others => '0');
				else
					r_ctr_y <= r_ctr_y + 1;
				end if;
			else
				r_ctr_x <= r_ctr_x + 1;
			end if;
		end if;
	end process;


	i_hsync_DVI <= '0' when r_ctr_x < 126 else
						'1';



	i_vsync_DVI <= '0' when r_ctr_y < 3 or
								(r_ctr_y = 312 and r_ctr_x >= 864) or
								r_ctr_y = 313 or
								r_ctr_y = 314 or
								(r_ctr_y = 315 and r_ctr_x < 864)
						else
						'1';

	i_blank_DVI <= '1' when r_ctr_x < 264 or r_ctr_x >= (1728-24) or
									r_ctr_y >= 623 or 
									r_ctr_y < 22 or
									(r_ctr_y >= 310 and r_ctr_y < 335) else
						'0';

--	i_R_DVI <= (std_logic_vector(r_ctr_x(5 downto 0)) & "00") when r_ctr_x(4 downto 3) = not r_ctr_y_log(4 downto 3) else
--					(others => '0');
--	i_G_DVI <= std_logic_vector(r_ctr_x(7 downto 1)) & "0" when r_ctr_x(6) = '1' else 
--				  	(others => '0');
--	i_B_DVI <= std_logic_vector(r_ctr_y_log(7 downto 0));

	i_R_DVI <= "11000000" when r_ctr_y_log(4) = '1' and r_ctr_x(5) = r_ctr_y_log(4) else "00011111";
	i_G_DVI <= "11000000" when r_ctr_y_log(5) = '1' and r_ctr_x(5) = r_ctr_y_log(4) else "00011111";
	i_B_DVI <= "11000000" when r_ctr_y_log(6) = '1' and r_ctr_x(5) = r_ctr_y_log(4) else "00011111";


--	i_R_DVI <= (std_logic_vector(r_ctr_x(5 downto 0)) & "00") when r_ctr_x(4 downto 3) = not r_ctr_y_log(4 downto 3) else
--					(others => '0');
--	i_G_DVI <= std_logic_vector(r_ctr_x(7 downto 1)) & "0" when r_ctr_x(6) = '1' else 
--				  	(others => '0');
--	i_B_DVI <= std_logic_vector(r_ctr_y_log(7 downto 0));


	p_reg:process(i_clk_hdmi_pixel)
	begin
		if rising_edge(i_clk_hdmi_pixel) then
			r_hsync_DVI <= i_hsync_DVI;
			r_vsync_DVI <= i_vsync_DVI;
			r_blank_DVI <= i_blank_DVI;

			if (i_blank_DVI = '1') then
				r_R_DVI <= (others => '0');
				r_G_DVI <= (others => '0');
				r_B_DVI <= (others => '0');
			else
				r_R_DVI <= i_R_DVI;
				r_G_DVI <= i_G_DVI;
				r_B_DVI <= i_B_DVI;
			end if;


		end if;
	end process;


	p_ctr_y_log:process(i_clk_hdmi_pixel)
	begin
		if rising_edge(i_clk_hdmi_pixel) then
			if r_ctr_x = 0 then
				if r_ctr_y = 22 then
					r_ctr_y_log <= to_unsigned(0, r_ctr_y_log'length);
				elsif r_ctr_y = 335 then
					r_ctr_y_log <= to_unsigned(1, r_ctr_y_log'length);
				else
					r_ctr_y_log <= r_ctr_y_log + 2;
				end if;
			end if;
		end if;
	end process;


--	e_dvid:entity work.dvid
--   port map ( 
--   	clk       => i_clk_hdmi_tmds,
--      clk_pixel => i_clk_hdmi_pixel,
--      red_p     => r_R_dvi,
--      green_p   => r_G_dvi,
--      blue_p    => r_B_dvi,
--      blank     => r_blank_dvi,
--      hsync     => r_hsync_dvi,
--      vsync     => r_vsync_dvi,
--      red_s     => HDMI_R_o,
--      green_s   => HDMI_G_o,
--      blue_s    => HDMI_B_o,
--      clock_s   => HDMI_CK_o
--   );

	e_spirkov:entity work.hdmi
	port map (
		I_CLK_PIXEL => i_clk_hdmi_pixel,
		I_R => i_R_DVI,
		I_G => i_G_DVI,
		I_B => i_B_DVI,
		I_BLANK => i_blank_DVI,
		I_HSYNC => i_hsync_DVI,
		I_VSYNC => i_vsync_DVI,
		I_ASPECT_169 => '1',

		I_AUDIO_ENABLE => '1',
		I_AUDIO_PCM_L => i_audio,
		I_AUDIO_PCM_R => i_audio,

		O_RED => i_R_encoded,
		O_GREEN => i_G_encoded,
		O_BLUE => i_B_encoded
	);


	e_hdmi_serial:entity work.hdmi_out_altera_max10
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

--====================================================================
-- FISHBONE frig
--====================================================================

	fb_p2c_o.ack <= '1';
	fb_p2c_o.rdy_ctdn <= RDY_CTDN_MIN;



end rtl;


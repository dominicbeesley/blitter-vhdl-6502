-- Company:          Dossytronics
-- Engineer:         Dominic Beesley
-- 
-- Create Date:      12/7/2025
-- Design Name: 
-- Module Name:      vid15tohdmi
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      Takes in 15kHz line-rate video and outputs a DVI/HDMI signal
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


entity vid15tohdmi is
   generic (
      SIM                           : boolean := false;                    -- skip some stuff, i.e. slow sdram start up
      SIM_NODVI                     : boolean := false;
      G_EXT_TMDS_CLOCKS             : boolean := false
   );
port (

      HDMI_CK_o                     : out    std_logic;
      HDMI_R_o                      : out    std_logic;
      HDMI_G_o                      : out    std_logic;
      HDMI_B_o                      : out    std_logic;

      -- video domain clock (pixels are a division of this)
      CLK_48M_i                     : in     std_logic;
      RESET_i                       : in     std_logic;

      -- video in 15KHz line rate on 48MHz clock
      VID_R_i                       : in     std_logic_vector(3 downto 0);
      VID_G_i                       : in     std_logic_vector(3 downto 0);
      VID_B_i                       : in     std_logic_vector(3 downto 0);
      VID_HS_i                      : in     std_logic;
      VID_VS_i                      : in     std_logic;
      VID_DISEN_i                   : in     std_logic;
      TTX_i                         : in     std_logic;
   
      -- sound data in (48KHz)
      PCM_L_i                       : in     signed(15 downto 0);
      PCM_R_i                       : in     signed(15 downto 0);

      -- debug
      debug_vsync_det_o             : out std_logic;
      debug_hsync_det_o             : out std_logic;
      debug_hsync_crtc_o            : out std_logic;
      debug_odd_o                   : out std_logic;
      debug_spr_mem_clken_o         : out std_logic;


      -- hdmi extras in
      AVI_i                         : in     std_logic_vector(111 downto 0);
      AUDIO_EN_i                    : in     std_logic;

      -- dvi retimer extras in
      PIXEL_DOUBLE_i                : in     std_logic;

      -- retimed analogue video
      VGA27_R_o                     : out    std_logic_vector(3 downto 0);
      VGA27_G_o                     : out    std_logic_vector(3 downto 0);
      VGA27_B_o                     : out    std_logic_vector(3 downto 0);
      VGA27_HS_o                    : out    std_logic;
      VGA27_VS_o                    : out    std_logic;
      VGA27_BLANK_o                 : out    std_logic;

      -- external clocks (optional)
      clk_ext_hdmi_pixel_i          : in std_logic := '1';
      clk_ext_hdmi_tmds_i           : in std_logic := '1'

);
end vid15tohdmi;

architecture rtl of vid15tohdmi is

   component hdmi_out_gowin_2a is
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


   -- DVI PLL
   signal i_clk_hdmi_pixel          : std_logic;
   signal i_clk_hdmi_tmds           : std_logic;

   --============================================================
   -- Re-timed video signals to hdmi pixel clock (27MHz)
   --============================================================
   
   signal i_vsync_DVI               : std_logic;
   signal i_hsync_DVI               : std_logic;
   signal i_blank_DVI               : std_logic;
   signal i_R_DVI                   : std_logic_vector(7 downto 0);
   signal i_G_DVI                   : std_logic_vector(7 downto 0);
   signal i_B_DVI                   : std_logic_vector(7 downto 0);

   signal i_R_encoded               : std_logic_vector(9 downto 0);
   signal i_G_encoded               : std_logic_vector(9 downto 0);
   signal i_B_encoded               : std_logic_vector(9 downto 0);

   -- control signals registered to hdmi pixel clock
   signal r_pix_audio_enable        : std_logic;

   signal r_PCM_L_pix               : signed(15 downto 0);
   signal r_PCM_R_pix               : signed(15 downto 0);


begin

   VGA27_R_o      <= i_R_DVI(7 downto 4);
   VGA27_G_o      <= i_G_DVI(7 downto 4);
   VGA27_B_o      <= i_B_DVI(7 downto 4);
   VGA27_VS_o     <= i_vsync_DVI;
   VGA27_HS_o     <= i_hsync_DVI;
   VGA27_BLANK_o  <= i_blank_DVI;

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

   g_not_sim_pll:if not SIM and not G_EXT_TMDS_CLOCKS generate

      e_pll_hdmi: entity work.pll_hdmi
      port map(
         clkin => CLK_48M_i,
         clkout => i_clk_hdmi_tmds
      );

    clkdiv5 : CLKDIV
        generic map (
            DIV_MODE => "5",            -- Divide by 5
            GSREN => "false"
        )
        port map (
            RESETN => '1',
            HCLKIN => i_clk_hdmi_tmds,
            CLKOUT => i_clk_hdmi_pixel,         -- 27MHz HDMI Pixel Clock
            CALIB  => '1'
        );
   end generate;

   g_ext_pll:if G_EXT_TMDS_CLOCKS generate

   i_clk_hdmi_pixel <= clk_ext_hdmi_pixel_i;
   i_clk_hdmi_tmds <= clk_ext_hdmi_tmds_i;

   end generate;

--====================================================================
-- DVI 
--====================================================================

   G_DVI:IF NOT SIM_NODVI generate
      e_synch:entity work.dvi_synchro
      port map (

         RESET_48M_i    => RESET_i,
         CLK_48M_i      => CLK_48M_i,
         pixel_double_i => pixel_double_i,

         -- input signals in the local clock domain
         VSYNC_CRTC_i   => VID_VS_i,
         HSYNC_CRTC_i   => VID_HS_i,
         DISEN_CRTC_i   => VID_DISEN_i,

         R_ULA_i        => VID_R_i,
         G_ULA_i        => VID_G_i,
         B_ULA_i        => VID_B_i,

         TTX_i          => TTX_i,

         -- synchronised / generated / conditioned signals in DVI pixel clock domain

         clk_pixel_dvi => i_clk_hdmi_pixel,

         VSYNC_DVI_o    => i_vsync_dvi,
         HSYNC_DVI_o    => i_hsync_dvi,
         BLANK_DVI_o    => i_blank_dvi,

         R_DVI_o        => i_R_DVI,
         G_DVI_o        => i_G_DVI,
         B_DVI_o        => i_B_DVI,

         debug_hsync_det_o    => debug_hsync_det_o,
         debug_vsync_det_o    => debug_vsync_det_o,
         debug_hsync_crtc_o   => debug_hsync_crtc_o,
         debug_odd_o          => debug_odd_o

      );
   end generate;


G_NOTSIM_SERIAL:IF NOT SIM GENERATE


   p_r:process(i_clk_hdmi_pixel)
   begin
      if rising_edge(i_clk_hdmi_pixel) then
         r_pix_audio_enable <= AUDIO_EN_i;
      end if;
   end process;

   p_snd:process(i_clk_hdmi_pixel)
   begin
      if rising_edge(i_clk_hdmi_pixel) then
         r_PCM_L_pix <= PCM_L_i;
         r_PCM_R_pix <= PCM_R_i;
      end if;
   end process;


   e_spirkov:hdmi
   generic map (
      FREQ  => 54000000,              -- pixel clock frequency
      FS    => 48000,                   -- audio sample rate - should be 32000, 44100 or 48000
      CTS   => 54000,                  -- CTS = Freq(pixclk) * N / (128 * Fs)
      N     => 6144                      -- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300
                          -- Check HDMI spec 7.2 for details
   )
   port map (
      I_CLK_PIXEL => i_clk_hdmi_pixel,
      I_R => i_R_DVI,
      I_G => i_G_DVI,
      I_B => i_B_DVI,
      I_BLANK => i_blank_DVI,
      I_HSYNC => i_hsync_DVI,
      I_VSYNC => i_vsync_DVI,
--    I_ASPECT_169 => r_fbhdmi_169,
      I_AVI_DATA => AVI_i,

      I_AUDIO_ENABLE => r_pix_audio_enable,
      I_AUDIO_PCM_L => std_logic_vector(PCM_L_i),
      I_AUDIO_PCM_R => std_logic_vector(PCM_R_i),

      O_RED => i_R_encoded,
      O_GREEN => i_G_encoded,
      O_BLUE => i_B_encoded
   );



   e_hdmi_serial:hdmi_out_gowin_2a
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


END GENERATE;

end architecture rtl;
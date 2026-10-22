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
use ieee.numeric_std.all;

use work.hdmi_int_pack.all;

entity vid15tohdmi is
   generic (
      SIM                           : boolean := false;                    -- skip some stuff, i.e. slow sdram start up
      SIM_NO_DVI                    : boolean := false
   );
port (

      clk_tmds_pixel_i              : in     std_logic;
      tmds_R_o                      : out    std_logic_vector(9 downto 0);
      tmds_G_o                      : out    std_logic_vector(9 downto 0);
      tmds_B_o                      : out    std_logic_vector(9 downto 0);

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
      TTX80_i                       : in     std_logic;
   
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
      VGA27_BLANK_o                 : out    std_logic


);
end vid15tohdmi;

architecture rtl of vid15tohdmi is

   --============================================================
   -- Re-timed video signals to hdmi pixel clock (27MHz)
   --============================================================
   
   signal i_vsync_DVI               : std_logic;
   signal i_hsync_DVI               : std_logic;
   signal i_blank_DVI               : std_logic;
   signal i_R_DVI                   : std_logic_vector(7 downto 0);
   signal i_G_DVI                   : std_logic_vector(7 downto 0);
   signal i_B_DVI                   : std_logic_vector(7 downto 0);

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

--====================================================================
-- DVI 
--====================================================================

   G_DVI:IF NOT SIM_NO_DVI generate
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
         TTX80_i        => TTX80_i,

         -- synchronised / generated / conditioned signals in DVI pixel clock domain

         clk_pixel_dvi => clk_tmds_pixel_i,

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


      p_r:process(clk_tmds_pixel_i)
   begin
         if rising_edge(clk_tmds_pixel_i) then
         r_pix_audio_enable <= AUDIO_EN_i;
      end if;
   end process;

      p_snd:process(clk_tmds_pixel_i)
   begin
         if rising_edge(clk_tmds_pixel_i) then
         r_PCM_L_pix <= PCM_L_i;
         r_PCM_R_pix <= PCM_R_i;
      end if;
   end process;


   e_spirkov:hdmi
   generic map (
      FREQ  => 27000000,              -- pixel clock frequency
      FS    => 48000,                   -- audio sample rate - should be 32000, 44100 or 48000
      CTS   => 27000,                  -- CTS = Freq(pixclk) * N / (128 * Fs)
      N     => 6144                      -- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300
                          -- Check HDMI spec 7.2 for details
   )
   port map (
         I_CLK_PIXEL => clk_tmds_pixel_i,
      I_R => i_R_DVI,
      I_G => i_G_DVI,
      I_B => i_B_DVI,
      I_BLANK => i_blank_DVI,
      I_HSYNC => i_hsync_DVI,
      I_VSYNC => i_vsync_DVI,
--    I_ASPECT_169 => r_fbhdmi_169,
      I_AVI_DATA => AVI_i,

      I_AUDIO_ENABLE => r_pix_audio_enable,
         I_AUDIO_PCM_L => std_logic_vector(r_PCM_L_pix),
         I_AUDIO_PCM_R => std_logic_vector(r_PCM_R_pix),

         O_RED => TMDS_R_o,
         O_GREEN => TMDS_G_o,
         O_BLUE => TMDS_B_o
   );

END GENERATE;

end architecture rtl;
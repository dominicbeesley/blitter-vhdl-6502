-- Company:          Dossytronics
-- Engineer:         Dominic Beesley
-- 
-- Create Date:      22/9/2021
-- Design Name: 
-- Module Name:      fb_HDMI_ctl
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      fishbone bus - HDMI control AVI bytes
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
use work.fishbone.all;

entity fb_HDMI_ctl is
   generic (
      SIM                           : boolean := false                     -- skip some stuff, i.e. slow sdram start up
   );
   port(

      -- fishbone signals for cpu/dma port

      fb_syscon_i                   : in     fb_syscon_t;
      fb_c2p_i                      : in     fb_con_o_per_i_t;
      fb_p2c_o                      : out    fb_con_i_per_o_t;

      avi_o                         : out    std_logic_vector(111 downto 0);

      pixel_double_o                : out    std_logic;
      audio_enable_o                : out    std_logic;

      ilace_i                       : in     std_logic

   );
end fb_HDMI_ctl;

architecture rtl of fb_HDMI_ctl is

   --constant  C_DEFAULT_AVI              : std_logic_vector(111 downto 0) := x"0000000000000000011500191030";
   constant C_DEFAULT_AVI           : std_logic_vector(111 downto 0) := x"0000000000000000031A880812B0";

   signal r_avi                     : std_logic_vector(111 downto 0);
   signal r_avi_lat                 : std_logic_vector(111 downto 0);
   signal r_avi_default             : std_logic;

   signal r_pixel_double            : std_logic;
   signal r_audio_enable            : std_logic;

   -- FISHBONE wrapper signals
   type     state_per_t is (idle, act_rd, act_wr);

   signal   r_state     : state_per_t;

   signal   r_D_ack     : std_logic;
   signal   r_A         : std_logic_vector(3 downto 0);
   signal   r_A_ack     : std_logic;
   signal   r_D_rd      : std_logic_vector(7 downto 0);
   signal   i_D_rd      : std_logic_vector(7 downto 0);

   signal   r_D_wr      : std_logic_vector(7 downto 0);
   signal   r_d_wr_stb  : std_logic;

begin

   fb_p2c_o.A_ack    <= r_A_ack;
   fb_p2c_o.D_rd     <= r_D_rd;
   fb_p2c_o.rdy      <= r_D_ack;
   fb_p2c_o.D_ack    <= r_D_ack;


   p_avi_override:process(fb_syscon_i)
   begin
      if rising_edge(fb_syscon_i.clk) then
         avi_o <= r_avi_lat;
         if r_avi_default = '1' then
            avi_o(33) <= not ilace_i;
         end if;
      end if;
   end process;

   pixel_double_o <= r_pixel_double;
   audio_enable_o <= r_audio_enable;

   p_d_wr:process(fb_syscon_i)
   begin
      if fb_syscon_i.rst = '1' then
         r_pixel_double <= '1';
         r_audio_enable <= '1';
         r_avi <= C_DEFAULT_AVI;
         r_avi_lat <= C_DEFAULT_AVI;
         r_avi_default <= '1';
      elsif rising_edge(fb_syscon_i.clk) then
         if r_d_wr_stb = '1' then
            case to_integer(unsigned(r_A)) is
               when 0 =>
                  r_avi(7 downto 0) <= r_d_wr;
               when 1 =>
                  r_avi(15 downto 8) <= r_d_wr;
               when 2 =>
                  r_avi(23 downto 16) <= r_d_wr;
               when 3 =>
                  r_avi(31 downto 24) <= r_d_wr;
               when 4 =>
                  r_avi(39 downto 32) <= r_d_wr;
               when 5 =>
                  r_avi(47 downto 40) <= r_d_wr;
               when 6 =>
                  r_avi(55 downto 48) <= r_d_wr;
               when 7 =>
                  r_avi(63 downto 56) <= r_d_wr;
               when 8 =>
                  r_avi(71 downto 64) <= r_d_wr;
               when 9 =>
                  r_avi(79 downto 72) <= r_d_wr;
               when 10 =>
                  r_avi(87 downto 80) <= r_d_wr;
               when 11 =>
                  r_avi(95 downto 88) <= r_d_wr;
               when 12 =>
                  r_avi(103 downto 96) <= r_d_wr;
               when 13 =>
                  r_avi(111 downto 104) <= r_d_wr;
               when 14 =>
                  r_pixel_double <= r_d_wr(0);
                  r_audio_enable <= r_d_wr(1);
               when 15 =>
                  r_avi_lat <= r_avi;
                  r_avi_default <= '0';
               when others => null;
            end case;
         end if;
      end if;
   end process;

   i_D_rd <=
      r_avi(7 downto 0) when r_A = x"0" else
      r_avi(15 downto 8) when r_A = x"1" else
      r_avi(23 downto 16) when r_A = x"2" else
      r_avi(31 downto 24) when r_A = x"3" else
      r_avi(39 downto 32) when r_A = x"4" else
      r_avi(47 downto 40) when r_A = x"5" else
      r_avi(55 downto 48) when r_A = x"6" else
      r_avi(63 downto 56) when r_A = x"7" else
      r_avi(71 downto 64) when r_A = x"8" else
      r_avi(79 downto 72) when r_A = x"9" else
      r_avi(87 downto 80) when r_A = x"A" else
      r_avi(95 downto 88) when r_A = x"B" else
      r_avi(103 downto 96) when r_A = x"C" else
      r_avi(111 downto 104) when r_A = x"D" else
      "000000" & r_audio_enable & r_pixel_double;


   p_per_state:process(fb_syscon_i)
   begin
      if fb_syscon_i.rst = '1' then
         r_state <= idle;
         r_D_ack <= '0';
         r_A_ack <= '0';
         r_D_rd <= (others => '0');
         r_A <= (others => '0');
         r_d_wr <= (others => '0');
         r_d_wr_stb <= '0';
      elsif rising_edge(fb_syscon_i.clk) then
         r_D_ack <= '0';
         r_A_ack <= '0';
         -- defer write one cycle to ease routing
         r_d_wr_stb <= '0';
         -- capture early - only needs to remain for one cycle but followed by a big mux so register to split timing
         r_d_wr <= fb_c2p_i.D_wr;
         case r_state is
            when idle =>
               -- capture early for less muxing
               r_A <= fb_c2p_i.A(3 downto 0);
               -- no need to check for previous r_A_ack cycle here as we can only go to act_wr, act_rd so no double ack
               if fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' then
                  if fb_c2p_i.we = '1' then
                     r_state <= act_wr;
                  else
                     r_state <= act_rd;
                  end if;
                  r_A_ack <= '1';
               end if;
            when act_wr =>
               if fb_c2p_i.cyc = '1' and fb_c2p_i.D_wr_stb = '1' and r_D_ack = '0' then
                  r_D_ack <= '1';
                  r_state <= idle;
                  r_d_wr_stb <= '1';
               end if;
            when act_rd =>
               if fb_c2p_i.cyc = '1' then
                  r_D_rd <= i_D_rd;
                  r_D_ack <= '1';
               end if;
               r_state <= idle;              
            when others =>
               -- not sure if we should blindly ack here
               r_state <= idle;
         end case;

         if fb_c2p_i.cyc = '0' then
            r_state <= idle;
         end if;
      end if;
   end process;



end rtl;
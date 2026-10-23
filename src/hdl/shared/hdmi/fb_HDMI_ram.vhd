-- Company:          Dossytronics
-- Engineer:         Dominic Beesley
-- 
-- Create Date:      22/9/2021
-- Design Name: 
-- Module Name:      fb_HDMI_ram
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      A fishbone wrapper for the blitter/cpu board's secondary screen memory
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

entity fb_HDMI_ram is
   generic (
      SIM                           : boolean := false                    -- skip some stuff, i.e. slow sdram start up
   );
   port(

      -- fishbone signals for cpu/dma port

      fb_syscon_i                   : in     fb_syscon_t;
      fb_c2p_i                      : in     fb_con_o_per_i_t;
      fb_p2c_o                      : out    fb_con_i_per_o_t;

      -- vga signals

      hdmi_ram_clk_i                : in     std_logic;
      hdmi_ram_addr_i               : in     std_logic_vector(16 downto 0);
      hdmi_ram_Q_o                  : out    std_logic_vector(7 downto 0)

   );
end fb_HDMI_ram;

architecture rtl of fb_HDMI_ram is

   -- FISHBONE wrapper signals
   type     state_per_t is (idle, act_rd, act_rd2, act_wr);

   signal   r_state     : state_per_t;

   signal   r_D_ack     : std_logic;
   signal   r_A         : std_logic_vector(14 downto 0);
   signal   r_A_ack     : std_logic;
   signal   r_D_rd      : std_logic_vector(7 downto 0);
   signal   i_D_rd      : std_logic_vector(7 downto 0);

   signal   r_D_wr      : std_logic_vector(7 downto 0);
   signal   r_D_wr_stb  : std_logic;

begin

   fb_p2c_o.A_ack    <= r_A_ack;
   fb_p2c_o.rdy      <= r_D_ack;
   fb_p2c_o.D_ack    <= r_D_ack;
   fb_p2c_o.D_rd     <= r_D_rd;



   p_per_state:process(fb_syscon_i)
   begin
      if fb_syscon_i.rst = '1' then
         r_state <= idle;
         r_D_ack <= '0';
         r_A_ack <= '0';
         r_A <= (others => '0');
         r_D_wr <= (others => '0');
         r_D_wr_stb <= '0';
         r_D_rd <= (others => '0');
      elsif rising_edge(fb_syscon_i.clk) then
         r_D_ack <= '0';
         r_A_ack <= '0';
         -- we don't really need to defer, kept for consistency
         r_D_wr_stb <= '0';
         -- capture early - only needs to remain for one cycle 
         r_D_wr <= fb_c2p_i.D_wr;
         case r_state is
            when idle =>
               -- capture early for less muxing
                  r_A <= fb_c2p_i.A(14 downto 0);
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
                  r_D_wr_stb <= '1';
               end if;
            when act_rd =>
               r_state <= act_rd2;
            when act_rd2 =>
               if fb_c2p_i.cyc = '1' then
                  r_D_ack <= '1';
                  r_D_rd <= i_D_rd;
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

   e_hdmi_ram:entity work.ram_tdp_2clk
   generic map (
      G_ADDRESS_SIZE    => 32 * 1024,
      G_DATA_WIDTH      => 8
   )
   port map (
      -- port A
      a_clk_i           => fb_syscon_i.clk,
      a_wr_en_i         => r_D_wr_stb,
      a_addr_i          => r_A,
      a_D_i             => r_D_Wr,
      a_D_o             => i_D_rd,

      -- port B
      b_clk_i           => hdmi_ram_clk_i,
      b_wr_en_i         => '0',
      b_addr_i          => hdmi_ram_addr_i(14 downto 0),
      b_D_i             => (others => '0'),
      b_D_o             => hdmi_ram_Q_o
   );


end rtl;
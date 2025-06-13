-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2023 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:      13/6/2023
-- Design Name: 
-- Module Name:      fb_ws2812
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      fishbone controller for ws2812 LED array
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
use work.ws2812_pack.all;

entity fb_ws2812 is
   generic (
      G_CLOCKSPEED                  : natural;                       -- fast clock speed in mhz          
      G_N_CHAIN                     : natural
   );
   port(
      
      -- fishbone signals

      fb_syscon_i                   : in     fb_syscon_t;
      fb_c2p_i                      : in     fb_con_o_per_i_t;
      fb_p2c_o                      : out    fb_con_i_per_o_t;

      -- led chain out
      led_serial_o                    : out    std_logic

   );
end fb_ws2812;

architecture rtl of fb_ws2812 is

   signal r_fb_ack   : std_logic;
   type state_t is (idle, wait_wr_stb);
   signal r_state    : state_t;
   signal r_wr_addr  : std_logic_vector(numbits(G_N_CHAIN) + 1 downto 0);
   signal i_wr_addr  : std_logic_vector(numbits(G_N_CHAIN) + 1 downto 0);

   signal r_colours  : ws2812_colour_arr_t(0 to G_N_CHAIN-1);

begin

   read:process(all)
   variable v_index : integer := to_integer(unsigned(fb_c2p_i.A(numbits(G_N_CHAIN) + 1 downto 2)));
   begin
      if fb_c2p_i.A(1 downto 0) = "00" then
         fb_p2c_o.D_rd <= "0000" & std_logic_vector(r_colours(v_index).red);
      elsif fb_c2p_i.A(1 downto 0) = "01" then
         fb_p2c_o.D_rd <= "0000" & std_logic_vector(r_colours(v_index).green);
      elsif fb_c2p_i.A(1 downto 0) = "10" then
         fb_p2c_o.D_rd <= "0000" & std_logic_vector(r_colours(v_index).blue);
      else
         fb_p2c_o.D_rd <= x"FF";
      end if;      

   end process;

   fb_p2c_o.ack <= r_fb_ack;
   fb_p2c_o.rdy <= r_fb_ack;
   fb_p2c_o.stall <= '0' when r_state = idle else '1';

   i_wr_addr <=   fb_c2p_i.A(numbits(G_N_CHAIN) + 1 downto 0) when r_state = idle else
                  r_wr_addr;

   p_state:process(fb_syscon_i)
   variable v_dowrite: boolean;
   variable v_wr_index : integer; 
   begin
      
      if fb_syscon_i.rst = '1' then
         r_fb_ack <= '0';
         r_colours <= (others => ( x"0", x"0", x"0"));
      elsif rising_edge(fb_syscon_i.clk) then
         
         v_dowrite := false;

         r_fb_ack <= '0';

         case r_state is
            when idle =>
               if fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' then
                  r_wr_addr <= fb_c2p_i.A(numbits(G_N_CHAIN) + 1 downto 0);
                  if fb_c2p_i.we = '1' then
                     if fb_c2p_i.D_wr_stb = '1' then
                        v_dowrite := true;
                     else
                        r_state <= wait_wr_stb;
                     end if;
                  else
                     r_fb_ack <= '1';                 
                  end if;
               end if;
            when wait_wr_stb =>
               if fb_c2p_i.D_wr_stb = '1' then
                  v_dowrite := true;
                  r_state <= idle;
               end if;
            when others =>
               r_state <= idle;

         end case;


         if v_dowrite then
            v_wr_index := to_integer(unsigned(i_wr_addr(numbits(G_N_CHAIN) + 1 downto 2)));
            if i_wr_addr(1 downto 0) = "00" then
               r_colours(v_wr_index).red <= unsigned(fb_c2p_i.D_wr(3 downto 0));
            elsif i_wr_addr(1 downto 0) = "01" then
               r_colours(v_wr_index).green <= unsigned(fb_c2p_i.D_wr(3 downto 0));
            elsif i_wr_addr(1 downto 0) = "10" then
               r_colours(v_wr_index).blue <= unsigned(fb_c2p_i.D_wr(3 downto 0));
            end if;
            r_fb_ack <= '1';
         end if;

      end if;
   end process;


   e_led_arr:entity work.ws2812
   generic map (
      G_CLOCKSPEED     => G_CLOCKSPEED,
      G_N_CHAIN        => G_N_CHAIN
   )
   port map (
      
      rst_i          => fb_syscon_i.rst,
      clk_i          => fb_syscon_i.clk,
      rgb_arr_i      => r_colours,

      led_serial_o   => led_serial_o

   );


end rtl;
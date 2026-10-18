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
   -- fishbone peripheral handler
   type     state_mem_t is (idle, act_rd, act_wr);

   signal   r_state     : state_mem_t;

   signal   r_D_ack     : std_logic;
   signal   r_A         : std_logic_vector(numbits(G_N_CHAIN) + 1 downto 0);
   signal   r_A_ack     : std_logic;
   signal   r_D_rd      : std_logic_vector(7 downto 0);
   signal   i_D_rd      : std_logic_vector(7 downto 0);

   signal   r_D_wr      : std_logic_vector(7 downto 0);
   signal   r_D_wr_stb  : std_logic;

   signal r_colours     : ws2812_colour_arr_t(0 to G_N_CHAIN-1);

begin

   read:process(all)
   variable v_index : integer;
   variable v_A : std_logic_vector(1 downto 0);
   begin
      v_index := to_integer(unsigned(r_A(numbits(G_N_CHAIN) + 1 downto 2)));
      v_A := r_A(1 downto 0);
      if v_A = "00" then
         i_D_rd <= "0000" & std_logic_vector(r_colours(v_index).red);
      elsif v_A = "01" then
         i_D_rd <= "0000" & std_logic_vector(r_colours(v_index).green);
      elsif v_A = "10" then
         i_D_rd <= "0000" & std_logic_vector(r_colours(v_index).blue);
      else
         i_D_rd <= x"FF";
      end if;      

   end process;

   p_wr:process(fb_syscon_i)
   variable v_index : integer; 
   variable v_A : std_logic_vector(1 downto 0);
   variable v_D : unsigned(3 downto 0);
   begin
      if fb_syscon_i.rst = '1' then
         r_colours <= (others => (others => (others => '0')));
      elsif rising_edge(fb_syscon_i.clk) then
         if r_D_wr_stb = '1' then
            v_index := to_integer(unsigned(r_A(numbits(G_N_CHAIN) + 1 downto 2)));
            v_A := r_A(1 downto 0);
            v_D := unsigned(r_D_wr(3 downto 0));
            if v_A = "00" then
               r_colours(v_index).red <= v_D;
            elsif v_A = "01" then
               r_colours(v_index).green <= v_D;
            elsif v_A = "10" then
               r_colours(v_index).blue <= v_D;
            end if;
         end if;
      end if;

   end process;

   fb_p2c_o.A_ack    <= r_A_ack;
   fb_p2c_o.D_rd     <= r_D_rd;
   fb_p2c_o.rdy      <= r_D_ack;
   fb_p2c_o.D_ack    <= r_D_ack;

   -- fishbone register access
   p_state_cyc:process(fb_syscon_i)
   variable v_dowrite : boolean;
   begin

      if fb_syscon_i.rst = '1' then

         r_state <= idle;
         r_D_ack <= '0';
         r_A_ack <= '0';
         r_D_rd <= (others => '0');
         r_A <= (others => '0');
         r_D_wr_stb <= '0';
         r_D_wr <= (others => '0');

      elsif rising_edge(fb_syscon_i.clk) then
         v_dowrite := false;
         r_D_ack <= '0';
         r_A_ack <= '0';
         r_D_wr_stb <= '0';

         case r_state is
            when idle =>
               -- capture early for less muxing
               r_A <= fb_c2p_i.A(numbits(G_N_CHAIN) + 1 downto 0);
               -- no need to check for previous r_A_ack cycle here as we can only go to act_wr, act_rd so no double ack
               if (fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1') then
                  r_A_ack <= '1';
                  if fb_c2p_i.we = '1' then
                     r_state <= act_wr;
                  else
                     r_state <= act_rd;                     
                  end if;
               end if;              
            when act_wr =>
               if fb_c2p_i.D_wr_stb = '1' and r_D_ack = '0' then
                  v_dowrite := true;
               end if;
            when act_rd => 
               if fb_c2p_i.cyc = '1' then
                  r_D_ack <= '1';   
                  r_D_rd <= i_D_rd;             
               end if;
               r_state <= idle;
            when others =>
               r_state <= idle;
         end case;

         if fb_c2p_i.cyc = '0' then
            r_state <= idle;
            r_A_ack <= '0';
            r_D_ack <= '0';
         elsif v_dowrite then
            r_state <= idle;
            r_D_ack <= '1';
            r_D_wr_stb <= '1';
            r_D_wr <= fb_c2p_i.D_wr;
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
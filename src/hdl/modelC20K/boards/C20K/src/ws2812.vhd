-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2025 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:      13/6/2025
-- Design Name: 
-- Module Name:      ws2812
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      Controller for a string of WS2812B LEDs with gamma correction
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
use work.ws2812_pack.all;

entity ws2812 is
   generic (
      G_CLOCKSPEED                    : natural := 48000000;                 -- fast clock speed in Hz >> 4MHz or a multiple of 4MHz
      
      G_N_CHAIN                       : natural
   );
   port(
      rst_i                   : in     std_logic;

      clk_i                   : in     std_logic;

      rgb_arr_i               : in     ws2812_colour_arr_t(0 to G_N_CHAIN-1);

      led_serial_o            : out    std_logic

   );
end ws2812;

architecture rtl of ws2812 is

   constant C_CLK_PER         : time    := 1000000 us / G_CLOCKSPEED;

   constant C_CLKS_BIT        : natural := 1.25 us / C_CLK_PER;
   constant C_CLKS_T0H        : natural := 0.4  us / C_CLK_PER;
   constant C_CLKS_T1H        : natural := 0.8  us / C_CLK_PER;

   constant C_BYTES_RESET     : natural := 100 us / (C_CLK_PER * C_CLKS_BIT * 8);

   type     state_t is (reset, run);
   signal   r_state           : state_t := reset;

   signal   r_intra_bit_ctr   : unsigned(numbits( C_CLKS_BIT - 1) downto 0) := (others => '0');
   signal   i_last_intra_bit  : std_logic;
   signal   i_low_intra_bit_0 : std_logic;
   signal   i_low_intra_bit_1 : std_logic;
   signal   r_bit_ctr         : unsigned(numbits(23) downto 0) := (others => '0');
   signal   i_last_bit        : std_logic;
   signal   r_reset_ctr       : unsigned(numbits(C_BYTES_RESET - 1) downto 0) := (others => '0');
   signal   r_index           : unsigned(numbits(G_N_CHAIN - 1) downto 0) := (others => '0');

   signal   r_next_grb        : unsigned(23 downto 0) := x"123412";

   signal   r_cur_grb         : unsigned(23 downto 0) := (others => '0');
   signal   r_cur_mask        : unsigned(23 downto 0) := (others => '0');

   signal   r_bit             : std_logic;

begin

   led_serial_o <= r_bit;

   i_last_intra_bit <=  '1' when to_integer(r_intra_bit_ctr) >= C_CLKS_BIT - 1 else 
                        '0';
   p_intra_bit_ctr:process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i = '1' then
            r_intra_bit_ctr <= (others => '0');
         else
            if i_last_intra_bit = '1' then
               r_intra_bit_ctr <= (others => '0');
            else
               r_intra_bit_ctr <= r_intra_bit_ctr + 1;
            end if;
         end if;
      end if;
   end process;

   i_last_bit <=  '1' when to_integer(r_bit_ctr) = 23 else
                  '0';
   p_bit_ctr:process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i = '1' then
            r_bit_ctr <= (others => '0');
         else
            if i_last_intra_bit = '1' then
               if i_last_bit = '1' then
                  r_bit_ctr <= (others => '0');
               else
                  r_bit_ctr <= r_bit_ctr + 1;
               end if;
            end if;
         end if;
      end if;
   end process;

   p_state:process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i = '1' then
            r_state <= reset;
            r_index <= (others => '0');
            r_reset_ctr <= (others => '0');
         else
            case r_state is
               when reset =>
                  if i_last_bit = '1' and i_last_intra_bit = '1' then
                     if r_reset_ctr >= C_BYTES_RESET-1 then
                        r_state <= run;
                        r_index <= (others => '0');
                     else
                        r_reset_ctr <= r_reset_ctr + 1;
                     end if;
                  end if;
               when run =>
                  if i_last_bit = '1' and i_last_intra_bit = '1' then

                     if r_index >= G_N_CHAIN - 1 then
                        r_state <= reset;
                        r_index <= (others => '0');
                        r_reset_ctr <= (others => '0');
                     else
                        r_index <= r_index + 1;
                     end if;
                  else
                     r_next_grb <= 
                        (
                           ws2812_gamma(rgb_arr_i(to_integer(r_index)).green),
                           ws2812_gamma(rgb_arr_i(to_integer(r_index)).red),
                           ws2812_gamma(rgb_arr_i(to_integer(r_index)).blue)
                        );                     
                  end if;
               when others => 
                  r_index <= (others => '0');
                  r_state <= reset;
                  r_reset_ctr <= (others => '0');
            end case;
         end if;
      end if;

   end process;


   p_bits_shift:process(clk_i)
   begin
      if rising_edge(clk_i) then
         if i_last_intra_bit = '1' then
            if i_last_bit = '1' then
               r_cur_grb <= r_next_grb;
               if r_state = run then
                  r_cur_mask <= (others => '1');
               end if;
            else
               r_cur_grb <= r_cur_grb(r_cur_grb'high-1 downto 0) & '0';
               r_cur_mask <= r_cur_mask(r_cur_mask'high-1 downto 0) & '0';
            end if;
         end if;
      end if;
   end process;

   i_low_intra_bit_0 <= '1' when to_integer(r_intra_bit_ctr) >= C_CLKS_T0H - 1 else 
                        '0';
   i_low_intra_bit_1 <= '1' when to_integer(r_intra_bit_ctr) >= C_CLKS_T1H - 1 else 
                        '0';
   p_bit_gen:process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i = '1' then
            r_bit <= '0';
         else
            if r_cur_mask(23) = '0' then
               r_bit <= '0';
            elsif i_last_intra_bit = '1' then
               r_bit <= '1';
            elsif r_cur_grb(23) = '1' and i_low_intra_bit_1 = '1' then
               r_bit <= '0';
            elsif r_cur_grb(23) = '0' and i_low_intra_bit_0 = '1' then
               r_bit <= '0';
            end if;
         end if;
      end if;
   end process;

end rtl;
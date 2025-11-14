
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
-- Create Date:      13/11/2025
-- Design Name: 
-- Module Name:      i2s
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      i2s driver for the PT8211S J-format i2s
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: The clk is inverted and drives B_CLK direct, suitable for
-- 							driving direct from clk_snd at ~3.5MHz or 17.7MHz PALx4
--
----------------------------------------------------------------------------------




library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity i2s is
port (
   rst_i 		: in	std_logic;
   clk_i 		: in	std_logic;
   pwm_l_i		: in	signed(15 downto 0);
   pwm_r_i		: in	signed(15 downto 0);

   bck_o 		: out	std_logic;
   ws_o  		: out	std_logic;
   dat_o 		: out	std_logic

);
end entity;

architecture  rtl of i2s is
	signal   r_i2s_ws    : std_logic_vector(31 downto 0) := "11111111111111110000000000000000";
   signal   r_bits      : std_logic_vector(31 downto 0);
begin

   bck_o <= not clk_i;
   ws_o <= r_i2s_ws(r_i2s_ws'high);
   dat_o <= r_bits(r_bits'high);

   p_i2s_tx:process(clk_i, rst_i)
   begin
      if rst_i = '1' then
         r_i2s_ws <= "11111111111111110000000000000000";
         r_bits <= (others => '0');
      elsif rising_edge(clk_i) then            
         if r_i2s_ws(r_i2s_ws'high) = '1' and r_i2s_ws(r_i2s_ws'high - 1) = '0' then
            r_bits <= std_logic_vector(pwm_l_i) & std_logic_vector(pwm_r_i);
         else
            r_bits <= r_bits(r_bits'high - 1 downto 0) & r_bits(r_bits'high);
         end if;
         r_i2s_ws <= r_i2s_ws(r_i2s_ws'high -1 downto 0) & r_i2s_ws(r_i2s_ws'high);
      end if;
   end process;

end architecture  rtl;

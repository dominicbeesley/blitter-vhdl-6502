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
-- ----------------------------------------------------------------------


-- Company:             Dossytronics
-- Engineer:            Dominic Beesley
-- 
-- Create Date:         13/6/2025
-- Design Name: 
-- Module Name:         ws2182_pack
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:         types and constants for ws2812 array controller
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ws2812_pack is

   constant C_WS2182_COLOUR_BITS : natural := 4;

   subtype ws2812_channel_t is unsigned(C_WS2182_COLOUR_BITS-1 downto 0);

   type ws2812_colour_t is record 
      red   : ws2812_channel_t;
      green : ws2812_channel_t;
      blue  : ws2812_channel_t;
   end record;

   type ws2812_colour_arr_t is array(integer range <>) of ws2812_colour_t;

   function ws2812_gamma(cha : ws2812_channel_t) return unsigned;

end package;

package body ws2812_pack is


-- Gamma table python script 
--N=16
--
--MAX=63
--DEAD=1
--GAMMA=2
--
--NN=pow(N-1, GAMMA)
--
--for i in range(0, N):
--    v=int((DEAD if i>0 else 0)+(MAX-DEAD)*pow(i,GAMMA)/NN)
--    print(f"when {i} => val := {v};")
   
   function ws2812_gamma(cha:ws2812_channel_t) return unsigned is
   variable val : integer;
   begin
      case to_integer(cha) is
         when 1 => val := 1;
         when 2 => val := 2;
         when 3 => val := 3;
         when 4 => val := 5;
         when 5 => val := 7;
         when 6 => val := 10;
         when 7 => val := 14;
         when 8 => val := 18;
         when 9 => val := 23;
         when 10 => val := 28;
         when 11 => val := 34;
         when 12 => val := 40;
         when 13 => val := 47;
         when 14 => val := 55;
         when 15 => val := 63;
         when others => val := 0;
      end case;
      return to_unsigned(val, 8);
   end function;


end ws2812_pack;
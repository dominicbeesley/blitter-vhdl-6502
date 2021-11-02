-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2020 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:      6/8/2021
-- Design Name: 
-- Module Name:      detect Electron RAM/HW slow cycles
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      Combinatorial check for slow addresses
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------



library IEEE;
use IEEE.std_logic_1164.all;

entity elk_slow_cyc is
port (
      sys_A_i           : in  std_logic_vector(15 downto 0);
      slow_o            : out std_logic;
      slow_ram_o        : out std_logic      
);
end elk_slow_cyc;

architecture rtl of elk_slow_cyc is

begin

   slow_ram_o <=  '1' when sys_A_i(15) = '0' else 
                  '0';

   slow_o <= '1' when (
      sys_A_i(15 downto 8) = x"FC" or
      sys_A_i(15 downto 8) = x"FD" or
      sys_A_i(15 downto 8) = x"FE" 
      ) else 
   '0';

end rtl;
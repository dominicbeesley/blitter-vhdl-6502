-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2021 Dominic Beesley https://github.com/dominicbeesley
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



----------------------------------------------------------------------------------
-- Company:          Dossytronics
-- Engineer:         Dominic Beesley
-- 
-- Create Date:      5/1/2025
-- Design Name: 
-- Module Name:      sim_bbc_interruptor
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      sim only generate interrupts from code after specifed no 
--                   of microseconds by writing a value, write a zero to clear
--                   interrupt
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.common.all;

entity sim_bbc_interruptor is
   Generic (
      ADDR : std_logic_vector(7 downto 0)
   );
   port (
      E        : in     std_logic;
      RnW      : in     std_logic;
      nCS      : in     std_logic;
      nRST     : in     std_logic;
      A        : in     std_logic_vector(7 downto 0);
      D        : in     std_logic_vector(7 downto 0);
      nINT     : inout  std_logic
   );
      
end sim_bbc_interruptor;

architecture Behavioral of sim_bbc_interruptor is
   signal r_countdown   : std_logic_vector(7 downto 0) := (others => '0');
   signal r_int         : std_logic := '0';
begin

   p_write:process(E, nRST)
   begin
      if nRST = '0' then
         r_int <= '0';
         r_countdown <= (others => '0');
      elsif falling_edge(E) then
         
         if RnW = '0' and nCS = '0' and A = ADDR then
            r_int <= '0';
            r_countdown <= D;
         elsif r_countdown /= x"00" then
            if r_countdown = x"01" then
               r_int <= '1';
            end if;
            r_countdown <= std_logic_vector(unsigned(r_countdown) - 1);
         end if;
      end if;

   end process;

   nINT <= '0' when r_int else 'Z';

end Behavioral;


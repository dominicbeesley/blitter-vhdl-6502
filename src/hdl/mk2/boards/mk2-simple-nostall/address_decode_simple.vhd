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
-- Create Date:      28/7/2020
-- Design Name: 
-- Module Name:      address_decode
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      Blitter board mk.3 address decoder
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--use work.mk1board_types.all;

library work;
use work.common.all;
use work.fishbone.all;
use work.board_config_pack.all;

entity address_decode_simple is
   port(
      addr_i                  : in     std_logic_vector(23 downto 0);
      we_i                    : in     std_logic;
      peripheral_sel_o        : out    unsigned(numbits(PERIPHERAL_COUNT)-1 downto 0);
      peripheral_sel_oh_o     : out    std_logic_vector(PERIPHERAL_COUNT-1 downto 0)      
   );
end address_decode_simple;

architecture rtl of address_decode_simple is
begin



   p_map:process(all)
   begin
      peripheral_sel_oh_o <= (others => '0');
      if (addr_i(23 downto 22) = "11") then                       -- "11xx xxxx"
         -- peripherals/sys
         if (addr_i(16) = '1') then                                              -- "11xx xxx1"    FF
				if addr_i(15 downto 4) = x"FE3" and addr_i(3 downto 0) /= x"0" and addr_i(3 downto 0) /= x"4" then
					-- memctl
					peripheral_sel_o <= to_unsigned(PERIPHERAL_NO_MEMCTL, numbits(PERIPHERAL_COUNT));
					peripheral_sel_oh_o(PERIPHERAL_NO_MEMCTL) <= '1';
				else
               -- SYS
               peripheral_sel_o <= to_unsigned(PERIPHERAL_NO_SYS, numbits(PERIPHERAL_COUNT));
               peripheral_sel_oh_o(PERIPHERAL_NO_SYS) <= '1';
            end if;
         else
            if addr_i(14) = '1' then
               peripheral_sel_o <= to_unsigned(PERIPHERAL_NO_CONFIG, numbits(PERIPHERAL_COUNT));
               peripheral_sel_oh_o(PERIPHERAL_NO_CONFIG) <= '1';
            else
               -- version
               peripheral_sel_o <= to_unsigned(PERIPHERAL_NO_VERSION, numbits(PERIPHERAL_COUNT));
               peripheral_sel_oh_o(PERIPHERAL_NO_VERSION) <= '1';
            end if;
         end if;
      else
         -- memory
         peripheral_sel_o <= to_unsigned(PERIPHERAL_NO_CHIPRAM, numbits(PERIPHERAL_COUNT));
         peripheral_sel_oh_o(PERIPHERAL_NO_CHIPRAM) <= '1';
      end if;
   end process;

end rtl;

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


-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	28/7/2020
-- Design Name: 
-- Module Name:    	add2slave
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Blitter board mk.3 address decoder
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
use work.mk3blit_pack.all;

entity address_decode is
	generic (
		SIM							: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		G_SLAVE_COUNT				: natural;
		G_INCL_CHIPSET				: boolean;
		G_INCL_HDMI					: boolean
	);
	port(
		addr_i						: in		std_logic_vector(23 downto 0);
		slave_sel_o					: out		unsigned(numbits(G_SLAVE_COUNT)-1 downto 0);
		slave_sel_oh_o				: out		std_logic_vector(G_SLAVE_COUNT-1 downto 0)
	);
end address_decode;

architecture rtl of address_decode is
begin


	p_map:process(addr_i)
	begin
		slave_sel_oh_o <= (others => '0');
		if (addr_i(23 downto 22) = "11") then														-- "11xx xxxx"
			-- peripherals/sys
			if (addr_i(19 downto 17) = "101" and G_INCL_HDMI) then							-- "11xx 101x"		FA-FB
					-- hdmi
					slave_sel_o <= to_unsigned(SLAVE_NO_HDMI, numbits(G_SLAVE_COUNT));
					slave_sel_oh_o(SLAVE_NO_HDMI) <= '1';				
			elsif (addr_i(16) = '1') then																-- "11xx xxx1"		FF
				if addr_i(15 downto 4) = x"FE3" and addr_i(3 downto 0) /= x"0" and addr_i(3 downto 0) /= x"4" then
					-- memctl
					slave_sel_o <= to_unsigned(SLAVE_NO_MEMCTL, numbits(G_SLAVE_COUNT));
					slave_sel_oh_o(SLAVE_NO_MEMCTL) <= '1';
				else
					-- SYS
					slave_sel_o <= to_unsigned(SLAVE_NO_SYS, numbits(G_SLAVE_COUNT));
					slave_sel_oh_o(SLAVE_NO_SYS) <= '1';
				end if;
			elsif addr_i(17) = '1' and G_INCL_CHIPSET then										-- "11xx xx1x"		FE
				slave_sel_o <= to_unsigned(SLAVE_NO_CHIPSET, numbits(G_SLAVE_COUNT));
				slave_sel_oh_o(SLAVE_NO_CHIPSET) <= '1';
			else
				-- version
				slave_sel_o <= to_unsigned(SLAVE_NO_VERSION, numbits(G_SLAVE_COUNT));
				slave_sel_oh_o(SLAVE_NO_VERSION) <= '1';
			end if;
		else
			-- memory
			slave_sel_o <= to_unsigned(SLAVE_NO_CHIPRAM, numbits(G_SLAVE_COUNT));
			slave_sel_oh_o(SLAVE_NO_CHIPRAM) <= '1';
		end if;
	end process;

end rtl;

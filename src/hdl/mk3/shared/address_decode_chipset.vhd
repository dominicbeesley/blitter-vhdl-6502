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
-- Description: 		Blitter board mk.3 address decoder intra-chipset
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

entity address_decode_chipset is
	generic (
		SIM							: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		G_SLAVE_COUNT				: natural := 9;
		G_INCL_CS_DMA				: boolean := false;
		G_DMA_CHANNELS				: natural := 2;
		G_INCL_CS_BLIT				: boolean := false;
		G_INCL_CS_SND				: boolean := false;
		G_SND_CHANNELS				: natural := 4;
		G_INCL_CS_AERIS			: boolean := false;
		G_INCL_CS_EEPROM			: boolean := false

	);
	port(
		addr_i						: in		std_logic_vector(7 downto 0);
		slave_sel_o					: out		unsigned(numbits(G_SLAVE_COUNT)-1 downto 0);
		slave_sel_oh_o				: out		std_logic_vector(G_SLAVE_COUNT-1 downto 0)
	);
end address_decode_chipset;

architecture rtl of address_decode_chipset is
begin


		p_map:process(addr_i)
		variable a : std_logic_vector(3 downto 0);
		begin

			a := addr_i(7 downto 4);

			slave_sel_oh_o <= (others => '0');
			if a = x"8" and G_INCL_CS_SND then
				slave_sel_o <= to_unsigned(SLAVE_NO_CHIPSET_SOUND, numbits(G_SLAVE_COUNT));
				slave_sel_oh_o(SLAVE_NO_CHIPSET_SOUND) <= '1';
			elsif a = x"9" and G_INCL_CS_DMA then
				slave_sel_o <= to_unsigned(SLAVE_NO_CHIPSET_DMA, numbits(G_SLAVE_COUNT));
				slave_sel_oh_o(SLAVE_NO_CHIPSET_DMA) <= '1';
			elsif a = x"B" and G_INCL_CS_AERIS then
				slave_sel_o <= to_unsigned(SLAVE_NO_CHIPSET_AERIS, numbits(G_SLAVE_COUNT));
				slave_sel_oh_o(SLAVE_NO_CHIPSET_AERIS) <= '1';
			elsif a = x"D" and G_INCL_CS_EEPROM then
				slave_sel_o <= to_unsigned(SLAVE_NO_CHIPSET_EEPROM, numbits(G_SLAVE_COUNT));
				slave_sel_oh_o(SLAVE_NO_CHIPSET_EEPROM) <= '1';
			elsif (a = x"6" or a = x"7" or a = x"A") and G_INCL_CS_BLIT then -- official address 6,7,A
				slave_sel_o <= to_unsigned(SLAVE_NO_CHIPSET_BLIT, numbits(G_SLAVE_COUNT));
				slave_sel_oh_o(SLAVE_NO_CHIPSET_BLIT) <= '1';
			else
			--TODO: investigate - making BLITTER default here causes sparkles in DEMO65 and 
			--crashes and random wrong tiles in ADVENT65
			--seemingly no ill effects to Paula though which is strange
				slave_sel_o <= to_unsigned(0, numbits(G_SLAVE_COUNT));
				slave_sel_oh_o(0) <= '1';
			end if;
		end process;

end rtl;

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


-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	25/4/2023
-- Design Name: 
-- Module Name:    	address_decode_p20k
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Simple decoder for P20K/C20K test
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

entity address_decode_p20k is
	generic (
		SIM							: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		G_PERIPHERAL_COUNT		: natural
	);
	port(
		addr_i						: in		std_logic_vector(23 downto 0);
		peripheral_sel_o			: out		unsigned(numbits(G_PERIPHERAL_COUNT)-1 downto 0);
		peripheral_sel_oh_o		: out		std_logic_vector(G_PERIPHERAL_COUNT-1 downto 0)
	);
end address_decode_p20k;

architecture rtl of address_decode_p20k is
begin


	p_map:process(addr_i)
	begin
		peripheral_sel_oh_o <= (others => '0');

		if addr_i(23 downto 16) = x"FF" then
			if addr_i(15 downto 4) = x"FE0" then
				peripheral_sel_o <= to_unsigned(PERIPHERAL_NO_UART, peripheral_sel_o'length);
				peripheral_sel_oh_o(PERIPHERAL_NO_UART) <= '1';
			elsif addr_i(15 downto 8) = x"FC" or addr_i(15 downto 8) = x"FD" then
				peripheral_sel_o <= to_unsigned(PERIPHERAL_NO_1MHZ_BUS, peripheral_sel_o'length);
				peripheral_sel_oh_o(PERIPHERAL_NO_1MHZ_BUS) <= '1';
			elsif addr_i(15) = '1' then

				peripheral_sel_o <= to_unsigned(PERIPHERAL_NO_MEM_ROM, peripheral_sel_o'length);
				peripheral_sel_oh_o(PERIPHERAL_NO_MEM_ROM) <= '1';
			elsif addr_i(15 downto 12) = x"0" then
				peripheral_sel_o <= to_unsigned(PERIPHERAL_NO_MEM_RAM, peripheral_sel_o'length);
				peripheral_sel_oh_o(PERIPHERAL_NO_MEM_RAM) <= '1';
			else
				peripheral_sel_o <= to_unsigned(PERIPHERAL_NO_MEM_BRD, peripheral_sel_o'length);
				peripheral_sel_oh_o(PERIPHERAL_NO_MEM_BRD) <= '1';
			end if;
		elsif addr_i(23 downto 16) = x"F0" then
			peripheral_sel_o <= to_unsigned(PERIPHERAL_NO_LED_ARR, peripheral_sel_o'length);
			peripheral_sel_oh_o(PERIPHERAL_NO_LED_ARR) <= '1';		
		else
			peripheral_sel_o <= to_unsigned(PERIPHERAL_NO_MEM_BRD, peripheral_sel_o'length);
			peripheral_sel_oh_o(PERIPHERAL_NO_MEM_BRD) <= '1';			
		end if;
	end process;

end rtl;

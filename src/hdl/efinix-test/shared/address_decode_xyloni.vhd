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
-- Module Name:    	address_decode_xyloni
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Simple decoder for xyloni test
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

entity address_decode_xyloni is
	generic (
		SIM							: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		G_PERIPHERAL_COUNT		: natural
	);
	port(
		addr_i						: in		std_logic_vector(23 downto 0);
		peripheral_sel_o			: out		unsigned(numbits(G_PERIPHERAL_COUNT)-1 downto 0);
		peripheral_sel_oh_o		: out		std_logic_vector(G_PERIPHERAL_COUNT-1 downto 0)
	);
end address_decode_xyloni;

architecture rtl of address_decode_xyloni is
begin


	p_map:process(addr_i)
	begin
		peripheral_sel_oh_o <= (others => '0');

		if addr_i(15 downto 4) = x"FE0" then
			peripheral_sel_o <= to_unsigned(PERIPHERAL_NO_UART, peripheral_sel_o'length);
			peripheral_sel_oh_o(PERIPHERAL_NO_UART) <= '1';
		else
			peripheral_sel_o <= to_unsigned(PERIPHERAL_NO_MEM, peripheral_sel_o'length);
			peripheral_sel_oh_o(PERIPHERAL_NO_MEM) <= '1';
		end if;
	end process;

end rtl;

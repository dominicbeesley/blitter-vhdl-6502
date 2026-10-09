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
-- Module Name:    	address_decode
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
use work.board_config_pack.all;

entity address_decode_simple is
	port(
		addr_i						: in		std_logic_vector(23 downto 0);
		we_i							: in     std_logic;
		peripheral_sel_o			: out		unsigned(0 downto 0);
		peripheral_sel_oh_o		: out		std_logic_vector(1 downto 0)		
	);
end address_decode_simple;

architecture rtl of address_decode_simple is
begin

	--	Match			Spec		Device
	--	11xx xxxx
	-- 11xx 101x	FA-FB		HDMI
	--	11xx xxx1	FF			SYS and other emulated devices (TODO: move memctl to SYS?)
	

	p_map:process(all)
	begin
		peripheral_sel_oh_o <= (others => '0');
		peripheral_sel_o <= "0";

		if addr_i(23 downto 16) = x"FF" then
			peripheral_sel_oh_o <= "01";
			peripheral_sel_o <= "0";
		else
			peripheral_sel_oh_o <= "10";
			peripheral_sel_o <= "1";
		end if;
	end process;

end rtl;

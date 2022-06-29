-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2022 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:    	14/1/2019
-- Design Name: 
-- Module Name:    	fishbone bus - SYS wrapper component SYS VIA blocker
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Block access to the SYS via where a writes/reads of port B
--							occur too close together (i.e. where MOS is running from FAST ram)
--							causes keyboard/sound glitches
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.fb_SYS_pack.all;

entity fb_sys_via_blocker is
	generic (
		SIM									: boolean := false;									-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural

	);
	port(

		fb_syscon_i							: in		fb_syscon_t;
		
      cfg_sys_type_i                : in     sys_type;

      clken									: in		std_logic;
		A_i									: in		std_logic_vector(23 downto 0);
		RnW_i									: in		std_logic;

		SYS_VIA_block_o					: out		std_logic

	);
end fb_sys_via_blocker;

architecture rtl of fb_sys_via_blocker is

	constant C_IORB_BODGE_MAX 	: natural := CLOCKSPEED * 10;						-- number of 128MHz cycles until we will allow between two accesses to SYS VIA IORB

	signal r_iorb_block 			: std_logic;
	signal r_iorb_block_ctdn 	: unsigned(NUMBITS(C_IORB_BODGE_MAX) downto 0);
	signal i_iorb_cs				: std_logic;

begin

	i_iorb_cs <= '1' when (
		A_i(23 downto 4) = x"FFFE4" or 
		A_i(23 downto 4) = x"FFFE6"
		) and cfg_sys_type_i /= SYS_ELK else
			'0';

	SYS_VIA_block_o <= r_iorb_block and i_iorb_cs;

	piorbctdn:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_iorb_block <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if i_iorb_cs = '1' and clken = '1' and RnW_i = '0' then
				r_iorb_block_ctdn <= to_unsigned(C_IORB_BODGE_MAX, r_iorb_block_ctdn'length);
				r_iorb_block <= '1';
			elsif r_iorb_block = '1' then
				r_iorb_block_ctdn <= r_iorb_block_ctdn - 1;
				if r_iorb_block_ctdn = to_unsigned(1, r_iorb_block_ctdn'length) then
					r_iorb_block <= '0';
				end if;
			end if;
		end if;
	end process;

end rtl;

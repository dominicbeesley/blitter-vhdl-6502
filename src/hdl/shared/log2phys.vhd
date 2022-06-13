
-- ###  #  ##   #          ###  #   ## ###      ## # # ##   #  # #          #       #  ##      ### ### ### ###
--  #  # # # # # #  #      #   # # #    #      #   # # # # # # ###      ## ###     ##  # #     # # # # # # # #
--  #  # # # # # #         ##  ###  #   #       #  ### ##  ### ###     # #  #       #  # #     # # # # # # # #
--  #  # # # # # #  #      #   # #   #  #        # ### # # # # # #     ###  ##      #  # #     # # # # # # # #
--  #   #  ##   #          #   # # ##   #      ##  # # # # # # # #                 ### ##      ### ### ### ###



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
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	map "logical" CPU addresses to physical addresses
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		
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
use work.fb_sys_pack.all;

entity log2phys is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up
	);
	port(

		-- fishbone signals
		fb_syscon_i							: in	fb_syscon_t;

		-- config signals
		cfg_swram_enable_i				: in std_logic;
		cfg_swromx_i						: in std_logic;
		cfg_mosram_i						: in std_logic;
		cfg_t65_i							: in std_logic;
		cfg_sys_type_i						: in sys_type;

		-- CPU address control signals from other components
		sys_ROMPG_i							: in	std_logic_vector(7 downto 0);
		JIM_page_i							: in  std_logic_vector(15 downto 0);
		turbo_lo_mask_i					: in	std_logic_vector(7 downto 0);

		-- memctl signals in
		jim_en_i								: in  std_logic;		-- local jim override
		swmos_shadow_i						: in	std_logic;		-- shadow mos from SWRAM slot #8

		-- noice debugger signals to cpu
		noice_debug_shadow_i				: in std_logic;		-- debugger memory MOS map is active (overrides shadow_mos)

		-- addresses to map
		A_i									: in	std_logic_vector(23 downto 0);
		-- mapped address
		A_o									: out std_logic_vector(23 downto 0)

	);
end log2phys;

architecture rtl of log2phys is
	signal map0n1 : boolean;
	signal r_pagrom_A 	: std_logic_vector(9 downto 0);
	signal r_mosrom_A		: std_logic_vector(9 downto 0);
begin

	map0n1 <= cfg_t65_i = '1' xor cfg_swromx_i = '1';

	p_romadd:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			r_pagrom_A <= x"FF" & "10";
			if cfg_swram_enable_i = '1' then
				if map0n1 then
					if (sys_ROMPG_i(2) = '0' or sys_ROMPG_i(3) = '1') then
						if sys_ROMPG_i(0) = '0' then
							r_pagrom_A <= x"7" & "111" & sys_ROMPG_i(3 downto 1);
						else
							r_pagrom_A <= x"9" & "111" & sys_ROMPG_i(3 downto 1);
						end if;
					end if;
				else
					if (sys_ROMPG_i(2) = '0' or sys_ROMPG_i(3) = '1' or cfg_sys_type_i /= SYS_ELK) then
						if sys_ROMPG_i(0) = '0' then
							r_pagrom_A <= x"7" & "110" & sys_ROMPG_i(3 downto 1);
						else
							r_pagrom_A <= x"9" & "110" & sys_ROMPG_i(3 downto 1);
						end if;						
					end if;
				end if;				
			end if;
		end if;
	end process;

	p_mosadd:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			r_mosrom_A <= x"FF" & "11";								-- SYS																FF C000 - FF FFFF
			if cfg_swram_enable_i = '1' then
				if noice_debug_shadow_i = '1' then
					if map0n1 then		
						r_mosrom_A <= x"9F" & "11";							-- NOICE shadow MOS from slot #F map 0 					9F C000 - 9F FFFF
					else
						r_mosrom_A <= x"9D" & "11";							-- in map 1 NOICE shadow 1 MOS is taken from				9D C000 - 9D FFFF
					end if;			
				elsif swmos_shadow_i = '1' or cfg_mosram_i = '1' then
					if map0n1 then
						r_mosrom_A <= x"7F" & "00";							-- SWMOS from slot #8 map 0 RAM at							7F 0000 - 7F 3FFF
					else
						r_mosrom_A <= x"7D" & "00";							-- SWMOS from slot #8 map 1 RAM at							7D 0000 - 7D 3FFF
					end if;
				elsif not map0n1 then
					r_mosrom_A <= x"9D" & "00";								-- SWMOS from slot #9 map 1									9D 0000 - 9D 3FFF
				end if;
			end if;
		end if;
	end process;


	p_A0:process(A_i, noice_debug_shadow_i, jim_en_i, JIM_page_i, r_mosrom_A, r_pagrom_A, turbo_lo_mask_i, cfg_sys_type_i)
	begin
		A_o <= A_i;
		if A_i(23 downto 16) = x"FF" then -- system access
			if A_i(15 downto 14) = "10" then -- paged rom access
				A_o <= r_pagrom_A & A_i(13 downto 0);
			elsif A_i(15 downto 8) = x"FD" then
				if jim_en_i = '1' then
					A_o <= JIM_page_i & A_i(7 downto 0);
				end if;
			elsif A_i(15 downto 14) = "11" 
					and A_i(15 downto 8) /= x"FC"
					and A_i(15 downto 8) /= x"FD"
					and A_i(15 downto 8) /= x"FE" then -- MOS access
				if noice_debug_shadow_i = '1' and A_i(13 downto 12) = "00" then
						A_o <= x"7E8" & A_i(11 downto 0);				-- NOICE shadow ram from hidden slot #4 of map 0		7E 8000 - 7E 8FFF
					else
						A_o <= r_mosrom_A & A_i(13 downto 0);			-- SWMOS from slot #9 map 1									9D 0000 - 9D 3FFF
				end if;
			elsif A_i(15) = '0' and turbo_lo_mask_i(to_integer(unsigned(A_i(14 downto 12)))) = '1' then
				A_o <= x"00" & A_i(15 downto 0);							-- turbo RAM														00 0000 - 00 7FFF
			end if;

		end if;
	end process p_A0;

end rtl;

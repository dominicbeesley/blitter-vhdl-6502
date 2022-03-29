-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	map "logical" cpu addresses to physical addresses
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

entity log2phys is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up
	);
	port(
		-- config signals
		cfg_swram_enable_i				: in std_logic;
		cfg_swromx_i						: in std_logic;
		cfg_mosram_i						: in std_logic;
		cfg_t65_i							: in std_logic;

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
begin

	map0n1 <= cfg_t65_i = '1' xor cfg_swromx_i = '1';

	A_o <= 	
				A_i 		
   						when A_i(23 downto 16) /= x"FF"										-- memory 
				-- MAP 0
	else		x"7" & "111" & sys_ROMPG_i(3 downto 1) & A_i(13 downto 0)
							when (sys_ROMPG_i(2) = '0' or sys_ROMPG_i(3) = '1')
							and sys_ROMPG_i(0) = '0'
							and A_i(15 downto 14) = "10"											-- SWRAM from chipram 7E 0000 - 7F FFFF
							and cfg_swram_enable_i = '1'
							and map0n1
	else		x"9" & "111" & sys_ROMPG_i(3 downto 1) & A_i(13 downto 0)
							when (sys_ROMPG_i(2) = '0' or sys_ROMPG_i(3) = '1') 
							and sys_ROMPG_i(0) = '1'
							and A_i(15 downto 14) = "10"											-- SWROM from eerpom 8E 0000 - 8F FFFF
							and cfg_swram_enable_i = '1'
							and map0n1
				-- MAP 1
	else		x"7" & "110" & sys_ROMPG_i(3 downto 1) & A_i(13 downto 0)
							when sys_ROMPG_i(0) = '0'
							and A_i(15 downto 14) = "10"											-- SWRAM from chipram 7E 0000 - 7F FFFF
							and cfg_swram_enable_i = '1'
							and not map0n1
	else		x"9" & "110" & sys_ROMPG_i(3 downto 1) & A_i(13 downto 0)
							when sys_ROMPG_i(0) = '1'
							and A_i(15 downto 14) = "10"											-- SWROM from eerpom 8E 0000 - 8F FFFF
							and cfg_swram_enable_i = '1'
							and not map0n1
				-- noice debug shadow
	else		x"7E8" & A_i(11 downto 0)															-- NOICE shadow ram from hidden slot #4 of map 0
							when A_i(15 downto 12) = x"C"											-- physical 7E 8000 - 7E 8FFF
							and noice_debug_shadow_i = '1'
	else		x"9F" & "11" & A_i(13 downto 0)													-- NOICE shadow MOS from slot #F map 0
							when A_i(15 downto 14) = "11"											-- SWMOS from ram 8F C000 - 8F FFFFF
							and A_i(15 downto 8) /= x"FC"
							and A_i(15 downto 8) /= x"FD"
							and A_i(15 downto 8) /= x"FE"
							and noice_debug_shadow_i = '1'
							and map0n1
	else		x"9D" & "11" & A_i(13 downto 0)													-- in map 1 MOS is taken from
							when A_i(15 downto 14) = "11"											-- SWMOS from ram 8F C000 - 8F FFFFF
							and A_i(15 downto 8) /= x"FC"
							and A_i(15 downto 8) /= x"FD"
							and A_i(15 downto 8) /= x"FE"
							and noice_debug_shadow_i = '1'
							and not map0n1
				-- flex shadow bank in map 0
	else		x"7F" & "00" & A_i(13 downto 0)													-- SWMOS from slot #8 map 0
							when A_i(15 downto 14) = "11"											-- SWMOS from ram 7F 0000 - 7F 3FFFF
							and A_i(15 downto 8) /= x"FC"
							and A_i(15 downto 8) /= x"FD"
							and A_i(15 downto 8) /= x"FE"
							and swmos_shadow_i = '1'
							and map0n1
				-- flex shadow bank in map 1
	else		x"7D" & "00" & A_i(13 downto 0)													-- SWMOS from slot #8 map 1
							when A_i(15 downto 14) = "11"											-- SWMOS from ram 7F 0000 - 7F 3FFFF
							and A_i(15 downto 8) /= x"FC"
							and A_i(15 downto 8) /= x"FD"
							and A_i(15 downto 8) /= x"FE"
							and swmos_shadow_i = '1'
							and not map0n1
				-- normal mos map 1 from slot 9
	else		x"9D" & "00" & A_i(13 downto 0)													-- SWMOS from slot #9 map 1
							when A_i(15 downto 14) = "11"											-- SWMOS from ram 7F 0000 - 7F 3FFFF
							and A_i(15 downto 8) /= x"FC"
							and A_i(15 downto 8) /= x"FD"
							and A_i(15 downto 8) /= x"FE"
							and not map0n1
							and cfg_mosram_i = '0'
				-- normal mos map 1 from slot 7 (mosram enabled)
	else		x"7D" & "00" & A_i(13 downto 0)													-- SWMOS from slot #9 map 1
							when A_i(15 downto 14) = "11"											-- SWMOS from ram 7F 0000 - 7F 3FFFF
							and A_i(15 downto 8) /= x"FC"
							and A_i(15 downto 8) /= x"FD"
							and A_i(15 downto 8) /= x"FE"
							and not map0n1


	else		JIM_page_i & A_i(7 downto 0)
							when A_i(15 downto 8) = x"FD"
							and jim_en_i = '1'
	else		x"00" & A_i(15 downto 0)
							when 
								(A_i(15 downto 12) = x"0" and turbo_lo_mask_i(0) = '1')
							or (A_i(15 downto 12) = x"1" and turbo_lo_mask_i(1) = '1')
							or (A_i(15 downto 12) = x"2" and turbo_lo_mask_i(2) = '1')
							or (A_i(15 downto 12) = x"3" and turbo_lo_mask_i(3) = '1')
							or (A_i(15 downto 12) = x"4" and turbo_lo_mask_i(4) = '1')
							or (A_i(15 downto 12) = x"5" and turbo_lo_mask_i(5) = '1')
							or (A_i(15 downto 12) = x"6" and turbo_lo_mask_i(6) = '1')
							or (A_i(15 downto 12) = x"7" and turbo_lo_mask_i(7) = '1')							
	else		A_i;
end rtl;

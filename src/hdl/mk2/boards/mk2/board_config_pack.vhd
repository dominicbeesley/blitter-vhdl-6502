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
-- ----------------------------------------------------------------------


-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    		9/3/2018
-- Design Name: 
-- Module Name:    		work.board_config_pack
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		board build configuration 
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use IEEE.math_real.all;

library work;
use work.firmware_info_pack.all;

package board_config_pack is

	constant FW_BOARD_LEVEL				: firmware_board_level := MK2;

	constant G_IORB_BLOCK		: boolean := true;

	constant G_INCL_HDMI					: boolean := false;
	constant G_INCL_CHIPSET				: boolean := true;
	constant G_INCL_CS_DMA				: boolean := true;
	constant G_DMA_CHANNELS				: natural := 2;
	constant G_INCL_CS_BLIT				: boolean := true;
	constant G_INCL_CS_SND				: boolean := true;
	constant G_SND_CHANNELS				: natural := 4;
	constant G_INCL_CS_AERIS			: boolean := true;
	constant G_INCL_CS_EEPROM			: boolean := true;
	constant G_INCL_CS_SDCARD			: boolean := false;		-- TODO: figure out if there are pins available?
		
	constant C_CPU_BYTELANES			: positive := 1;		
	constant G_INCL_CPU_T65				: boolean := true;
	constant G_INCL_CPU_65C02			: boolean := true;
	constant G_INCL_CPU_6800			: boolean := false;
	constant G_INCL_CPU_80188			: boolean := false;
	constant G_INCL_CPU_65816			: boolean := true;
	constant G_INCL_CPU_6x09			: boolean := true;
	constant G_INCL_CPU_Z80				: boolean := true;
	constant G_INCL_CPU_68008			: boolean := true;
	constant G_INCL_CPU_680x0			: boolean := false;
	constant G_INCL_CPU_ARM2			: boolean := false;
	constant G_INCL_CPU_Z180			: boolean := false;

	constant G_MEM_FAST_IS_10			: boolean := true;
	constant G_MEM_SLOW_IS_45			: boolean := true;
	constant G_MEM_FLASH_IS_45			: boolean := false;

	constant PERIPHERAL_COUNT			: natural := 5;
	constant PERIPHERAL_NO_VERSION	: natural := 0;
	constant PERIPHERAL_NO_SYS	 		: natural := 1;
	constant PERIPHERAL_NO_CHIPRAM	: natural := 2;
	constant PERIPHERAL_NO_MEMCTL		: natural := 3;
	constant PERIPHERAL_NO_CHIPSET	: natural := 4;
	constant PERIPHERAL_NO_HDMI		: natural := 0;		-- not on mk2 board!

	constant CONTROLLER_COUNT			: natural := 2;
	-- note 0 is highest priority!
	constant MAS_NO_CPU					: natural := 1;
	constant MAS_NO_CHIPSET				: natural := 0;

end board_config_pack;


package body board_config_pack is

end board_config_pack;

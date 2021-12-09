-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2021 Dominic Beesley https://github.com/dominicbeesley
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
-- Module Name:    		work.mk3blit_pack
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		board configuration file
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use IEEE.math_real.all;

package mk3blit_pack is
	type cpu_type is (CPU_6x09, CPU_6502, CPU_65C02, CPU_65816, CPU_Z80, CPU_68008);
	type sys_type is (SYS_BBC, SYS_ELK);

	constant GBUILD_INCL_HDMI	: boolean := false;



	constant PERIPHERAL_COUNT	: natural := 6;
	constant PERIPHERAL_NO_VERSION	: natural := 0;
	constant PERIPHERAL_NO_SYS	: natural := 1;
	constant PERIPHERAL_NO_CHIPRAM	: natural := 2;
	constant PERIPHERAL_NO_MEMCTL	: natural := 3;
	constant PERIPHERAL_NO_CHIPSET	: natural := 4;
	constant PERIPHERAL_NO_HDMI	: natural := 5;--unused
	

	constant CONTROLLER_COUNT	: natural := 2;
	-- not 0 is highest priority!
	constant MAS_NO_CPU		: natural := 1;
	constant MAS_NO_CHIPSET		: natural := 0;


	constant PERIPHERAL_COUNT_CHIPSET	: natural := 2;
	constant PERIPHERAL_NO_CHIPSET_DMA	: natural := 0;
	constant PERIPHERAL_NO_CHIPSET_SOUND	: natural := 1;
	constant PERIPHERAL_NO_CHIPSET_BLIT	: natural := 1;--unused
	constant PERIPHERAL_NO_CHIPSET_AERIS	: natural := 1;--unused
	constant PERIPHERAL_NO_CHIPSET_EEPROM	: natural := 1;--unused


	constant CONTROLLER_COUNT_CHIPSET	: natural := 2;
	constant MAS_NO_CHIPSET_BLIT		: natural := 2; -- unused 4;
	constant MAS_NO_CHIPSET_DMA_1		: natural := 2; -- unused;
	constant MAS_NO_CHIPSET_DMA_0		: natural := 1;
	constant MAS_NO_CHIPSET_SND		: natural := 0; -- when used 1;
	constant MAS_NO_CHIPSET_AERIS		: natural := 0; -- unused


end mk3blit_pack;


package body mk3blit_pack is

end mk3blit_pack;

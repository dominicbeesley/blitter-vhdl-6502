
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    		9/3/2018
-- Design Name: 
-- Module Name:    		work.mk3blit_pack
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		shared types
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



	constant PERIPHERAL_COUNT		: natural := 6;
	constant PERIPHERAL_NO_VERSION	: natural := 0;
	constant PERIPHERAL_NO_SYS	 	: natural := 1;
	constant PERIPHERAL_NO_CHIPRAM	: natural := 2;
	constant PERIPHERAL_NO_MEMCTL	: natural := 3;
	constant PERIPHERAL_NO_CHIPSET	: natural := 4;
	constant PERIPHERAL_NO_HDMI		: natural := 5;
	

	constant CONTROLLER_COUNT		: natural := 2;
	-- not 0 is highest priority!
	constant MAS_NO_CPU		: natural := 1;
	constant MAS_NO_CHIPSET		: natural := 0;


	constant PERIPHERAL_COUNT_CHIPSET	: natural := 5;
	constant PERIPHERAL_NO_CHIPSET_DMA	: natural := 0;
	constant PERIPHERAL_NO_CHIPSET_SOUND	: natural := 1;
	constant PERIPHERAL_NO_CHIPSET_BLIT	: natural := 2;
	constant PERIPHERAL_NO_CHIPSET_AERIS	: natural := 3;
	constant PERIPHERAL_NO_CHIPSET_EEPROM: natural := 4;


	constant CONTROLLER_COUNT_CHIPSET	: natural := 5;
	constant MAS_NO_CHIPSET_BLIT	: natural := 4;
	constant MAS_NO_CHIPSET_DMA_1	: natural := 3; 
	constant MAS_NO_CHIPSET_DMA_0	: natural := 2;
	constant MAS_NO_CHIPSET_SND	: natural := 1; 
	constant MAS_NO_CHIPSET_AERIS	: natural := 0; 




end mk3blit_pack;


package body mk3blit_pack is

end mk3blit_pack;

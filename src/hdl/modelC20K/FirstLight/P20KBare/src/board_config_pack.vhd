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
-- ----------------------------------------------------------------------


-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    		25/4/2023
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

package board_config_pack is
		
	constant C_CPU_BYTELANES	: positive := 1;		

	constant CONTROLLER_COUNT 			: natural 		:= 1;
	constant MAS_NO_CPU					: natural		:= 0;
	constant PERIPHERAL_COUNT 			: natural 		:= 5;
	constant PERIPHERAL_NO_MEM_RAM 	: natural		:= 0;
	constant PERIPHERAL_NO_MEM_ROM 	: natural		:= 1;
	constant PERIPHERAL_NO_MEM_BRD 	: natural		:= 2;
	constant PERIPHERAL_NO_1MHZ_BUS	: natural      := 3;
	constant PERIPHERAL_NO_UART 		: natural		:= 4;

end board_config_pack;


package body board_config_pack is

end board_config_pack;

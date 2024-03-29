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
-- Module Name:    		work.firmware_info_pack
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		firmware version / level information
-- Dependencies: 
--
-- Revision: 
--	0101	- Added ARM2, Z180 and configuration bits for mem speed, supershadow
--  0102	- Added per-ROM throttle flags in FE33/5
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------


-- This table should be updated when new features are introduced and the corresponding
-- information in API.md updated
--
-- | API | Sub | Description                                            |
-- |-----|-----|--------------------------------------------------------|
-- |  1  |  0  | API level/sublevel registers introduced                |
-- |  1  |  1  | Added new CPU types                                    |
-- |  1  |  2  | per-ROM throttle registers                             |
-- |  1  |  3  | Auto-hazel for Model B / Elk                           |


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package firmware_info_pack is
	
	type firmware_board_level is (PAULA, MK1, MK2, MK3);

	constant FW_API_level : std_logic_vector(7 downto 0) := x"01";
	constant FW_API_sublevel : std_logic_vector(7 downto 0) := x"03";

end firmware_info_pack;


package body firmware_info_pack is

end firmware_info_pack;


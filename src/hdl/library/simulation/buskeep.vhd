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



----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	5/1/2025
-- Design Name: 
-- Module Name:    	buskeep
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		sim only bus keeper, holds bus L or H depending on last forced value (indefinitely)
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.common.all;

entity buskeep is
	Generic (
		WIDTH : natural;
		DELAY : time := 10 ns
	);
	port (
		D_io : inout 	std_logic_vector(WIDTH-1 downto 0)
		
	);
		
end buskeep;

architecture Behavioral of buskeep is
	TYPE keeptable_t IS ARRAY (std_logic'LOW TO std_logic'HIGH) OF std_logic;

	CONSTANT keeptable : keeptable_t := (
                         'Z',  -- 'U'
                         'Z',  -- 'X'
                         'L',  -- '0'
                         'H',  -- '1'
                         'Z',  -- 'Z'
                         'Z',  -- 'W'
                         'L',  -- 'L'
                         'H',  -- 'H'
                         'Z'   -- '-'
                        );

	function keep(v : in std_logic) return std_logic is
	begin
  		return keeptable(v);
	end;
begin

	KA:for i in WIDTH-1 downto 0 
	generate
		D_io(I) <= keep(D_io(I)) after DELAY;
	end generate KA;

end Behavioral;


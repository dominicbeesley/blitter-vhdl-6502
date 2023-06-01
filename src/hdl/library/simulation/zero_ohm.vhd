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
-- Create Date:    	1/6/2023
-- Design Name: 
-- Module Name:    	zero_ohm.vhd
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A zero-ohm link between two inout signals
--                   http://computer-programming-forum.com/42-vhdl/e21a4ee687301ae8.htm
-- Dependencies: 
--
-- Revision: 
--
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity zero_ohm is
port (
	A  :  inout   std_logic := 'Z';
   B  :  inout   std_logic := 'Z'
   );
end zero_ohm;


architecture rtl of zero_ohm is
begin  
  p:process
  begin  --  process Resistor_Lbl
    wait on A, B;
    -- Cause a 'break'
    A <= 'Z';
    B <= 'Z';
    wait for 0 ns;
    -- Cause a 'make'
    A <= B;
    B <= A;
    -- Force a wait to prevent assignment to re-awake the process
    wait for 0 ns;
  end process;
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity zero_ohm_bus is
generic (
	WIDTH	: positive
	);
port (
	A  :  inout   std_logic_vector(WIDTH-1 downto 0) := (others => 'Z');
   B  :  inout   std_logic_vector(WIDTH-1 downto 0) := (others => 'Z')
	);
end zero_ohm_bus;

architecture rtl of zero_ohm_bus is
begin

	g:for I in WIDTH-1 downto 0 generate
		z:entity work.zero_ohm
      port map (
			A => A(I),
			B => B(I)
			);
	end generate;

end rtl;
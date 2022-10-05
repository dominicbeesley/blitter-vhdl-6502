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


-- Company:             Dossytronics
-- Engineer:            Dominic Beesley
-- 
-- Create Date:         1/8/2022
-- Design Name: 
-- Module Name:         cy74FCT2543
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:         A simple simulation model for a TX/RX latching transceiver
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

entity cy74FCT2543 is
    port(
        A : inout std_logic_vector(7 downto 0);
        B : inout std_logic_vector(7 downto 0);

        nOEAB : in std_logic;
        nLEAB : in std_logic;
        nCEAB : in std_logic;

        nOEBA : in std_logic;
        nLEBA : in std_logic;
        nCEBA : in std_logic

    );
end cy74FCT2543;

architecture behav of cy74FCT2543 is
	signal i_BA_Q : std_logic_vector(7 downto 0);
	signal i_AB_Q : std_logic_vector(7 downto 0);
begin

	G_L:FOR I in 7 downto 0 GENERATE

		A(I) <= i_BA_Q(I) when nOEBA = '0' and nCEBA = '0' else 'Z';
		B(I) <= i_AB_Q(I) when nOEAB = '0' and nCEAB = '0' else 'Z';

		p_lat_BA:process(nCEBA, nLEBA, B)
		begin
			if nCEBA = '0' and nLEBA = '0' then
				i_BA_Q(I) <= B(I);
			end if;
		end process;

		p_lat_AB:process(nCEAB, nLEAB, A)
		begin
			if nCEAB = '0' and nLEAB = '0' then
				i_AB_Q(I) <= A(I);
			end if;
		end process;


	END GENERATE;
	

end behav;
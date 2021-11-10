
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
-- Create Date:         10/11/2021
-- Design Name: 
-- Module Name:         work.ls02
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:         A simple simulation model for a 74LS51 gate
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY ls51 IS
    GENERIC (
        t_rise : TIME := 12 ns;
        t_fall : TIME := 12 ns
    );
    PORT(
        dA, dB, dC : IN std_logic := '1';
        dD, dE, dF : IN std_logic := '1';
        q : OUT std_logic
    );
END ls51;

ARCHITECTURE behav OF ls51 IS
BEGIN
    PROCESS(dA, dB, dC)
    BEGIN
        IF (dA = '1' and dB = '1' and dC = '1') or (dD = '1' and dE = '1' and dF = '1') THEN
            q <= '0' AFTER t_fall;
        ELSE
            q <= '1' AFTER t_rise;
        END IF;
    END PROCESS;
END behav;
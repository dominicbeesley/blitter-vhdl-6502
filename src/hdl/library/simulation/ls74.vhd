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
-- Description:         A simple simulation model for a 74LS74 gate
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------


LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY ls74 IS
    GENERIC (
        t_rise : TIME := 13 ns;
        t_fall : TIME := 25 ns;
        t_setup : TIME := 20 ns;
        t_width : TIME := 25 ns
    );
    PORT(
        d, clr, pre, clk : IN std_logic;
        q : OUT std_logic;
        nq: OUT std_logic
    );
END ls74;

ARCHITECTURE behav OF ls74 IS
BEGIN
    PROCESS(clk, clr, pre)
    BEGIN
        IF clr = '0' THEN
            q <= '0' AFTER t_fall;
            nQ <= '1' AFTER t_rise;
        ELSIF pre = '0' THEN
            q <= '1' AFTER t_rise;
            nQ <= '0' AFTER t_fall;
        ELSIF clk'EVENT AND clk = '1' THEN
            IF d = '1' THEN
                q <= '1' AFTER t_rise;
                nQ <= '0' AFTER t_fall;
            ELSE
                q <= '0' AFTER t_fall;
                nQ <= '1' AFTER t_rise;
            END IF;
        END IF;
    END PROCESS;

    -- process to check data setup time
    PROCESS(clk)
    BEGIN
        IF clk'EVENT AND clk = '1' THEN
            ASSERT d'LAST_EVENT > t_setup
            REPORT "D changed within setup time"
            SEVERITY ERROR;
        END IF;
    END PROCESS;
    
    -- process to check clock high pulse width
    PROCESS(clk)
    VARIABLE last_clk : TIME := 0 ns;
    BEGIN
        IF clk'EVENT AND clk = '0' THEN
            ASSERT NOW - last_clk > t_width
            REPORT "Clock pulse width too short"
            SEVERITY ERROR;
        ELSE
            last_clk := NOW;
        END IF;
    END PROCESS;
END behav;
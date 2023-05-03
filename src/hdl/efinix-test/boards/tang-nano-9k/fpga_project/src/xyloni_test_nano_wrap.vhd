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
-- -----------------------------------------------------------------------------


-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	25/4/2023
-- Design Name: 
-- Module Name:    	xyloni_test_nano_wrap
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Test build of a minimal T65 computer on a Tang Nano 9K
--							this wraps the Efinix Xyloni project and provides the
--							pll which is done on the Efinix with the interface designer
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity xyloni_test_nano_wrap is
	port(
		-- crystal osc 48Mhz - on WS board
		clk_27_i								: in		std_logic;

		ser_tx_o								: out		std_logic;
		ser_rx_i								: in		std_logic;

		led									: out		std_logic_vector(5 downto 0);

		debug_ser_tx_o						: out		std_logic

	);
end xyloni_test_nano_wrap;

architecture rtl of xyloni_test_nano_wrap is

signal i_clk_pll128 : std_logic;

begin

e_xylon:entity work.xyloni_test
	generic map(
		PROJECT_ROOT_PATH => "./../../../../../"
	)
	port map(
		-- crystal osc 48Mhz - on WS board
		clk_128_pll_i		=> i_clk_pll128,

		ser_tx_o				=> ser_tx_o,
		ser_rx_i				=> ser_rx_i,

		led					=> led(3 downto 0),

		debug_ser_tx_o		=> debug_ser_tx_o

	);

e_pll:entity work.main_pll
    port map (
        clkout => i_clk_pll128,
        clkin => clk_27_i
    );

end rtl;
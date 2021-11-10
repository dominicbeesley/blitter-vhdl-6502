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
-- Create Date:    	13/7/2017 
-- Design Name: 
-- Module Name:    	74xx245 behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
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

entity LS74245 is
	Generic (
		tprop			: time	:= 12 ns;	-- 7 ns for F
		toe			: time	:= 40 ns;	-- 8 ns for F
		ttr			: time	:= 12 ns	-- 7 ns for F -- this is a guess, no info on datasheet
	);
	Port (
		A				: inout	STD_LOGIC_VECTOR(7 downto 0);
		B				: inout	STD_LOGIC_VECTOR(7 downto 0);
		dirA2BnB2A	: in		STD_LOGIC;
		nOE			: in		STD_LOGIC
	);
end LS74245;

architecture Behavioral of LS74245 is
	signal	dirA2BnB2A_dly		: std_logic;
	signal	nOE_dly				: std_logic;
		
begin

	dirA2BnB2A_dly <= dirA2BnB2A after ttr;
	nOE_dly <= nOE after toe;

	B <= to_stdlogicvector(to_bitvector(A)) after tprop when dirA2BnB2A_dly = '1' and nOE_dly = '0' else (others => 'Z') after tprop;
	A <= to_stdlogicvector(to_bitvector(B)) after tprop when dirA2BnB2A_dly = '0' and nOE_dly = '0' else (others => 'Z') after tprop;
	
	
end Behavioral;


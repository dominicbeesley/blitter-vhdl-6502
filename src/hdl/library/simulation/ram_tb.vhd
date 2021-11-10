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
-- Create Date:    	12/7/2017 
-- Design Name: 
-- Module Name:    	ROM_TB 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Behavioral only model of an SRAM (modelled loosely on the KM684000BLP-7L datasheet)
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

entity RAM_tb is
	Generic (
		toh		: time := 10 ns;
		tohz		: time := 25 ns;
		thz		: time := 25 ns;
		tolz		: time := 5  ns;
		tlz		: time := 10 ns;
		toe		: time := 35 ns;
		tco		: time := 70 ns;
		taa		: time := 70 ns;
		
		twed		: time := 40 ns;	-- this is bogus!
		
		size		: integer := 1024;
		
		dump_filename : string := "d:\temp\ram";
		
		romfile	: string := ""
	);
	port (
		A				: in		std_logic_vector(numbits(size)-1 downto 0);
		D				: inout	std_logic_vector(7 downto 0);
		nCS			: in		std_logic;
		nOE			: in		std_logic;
		nWE			: in		std_logic;
		
		tst_dump		: in		std_logic
		
	);
		
end RAM_tb;

architecture Behavioral of RAM_tb is

	type		ram_type			is array (0 to size - 1) of std_logic_vector(7 downto 0);

	signal	i_A_DLY			: std_logic_vector(A'range);
	signal	i_A_nCS_DLY		: std_logic;
	signal	i_nCS_OE_dly	: std_logic;
	signal	i_nOE_dly		: std_logic;
	signal	i_nWE_dly		: std_logic;
	signal	i_D				: std_logic_vector(7 downto 0);	
	signal	i_D_in_dly		: std_logic_vector(7 downto 0);
	signal	i_data			: ram_type := (others => (others => '0'));
	
	function has_meta(X:std_logic_vector) return boolean is
	begin
		for I in X'low to X'high loop
			if X(I) /= '1' and X(I) /= '0' then
				return true;
			end if;
		end loop;
		return false;
	end;
	
begin


	i_A_nCS_DLY <= nCS after tco;
	i_A_DLY <= A after taa;
	i_D_in_dly <= D after tco;			-- huge bodge!

	p_add2d: process(i_A_DLY, i_A_nCS_DLY)
	begin
		if (i_A_DLY'event or i_A_nCS_DLY'event) and i_A_nCS_DLY = '0' then
			if has_meta(i_A_DLY) then
				i_D <= (others => 'Z');
			elsif to_integer(unsigned(i_A_DLY)) < size then
				i_D <= i_data(to_integer(unsigned(i_A_DLY)));
			end if;
		else
			i_D <= (others => 'Z') after toh;
		end if;
	end process;
	
	D <= (others => 'Z') when i_nCS_OE_dly = '1' or i_nOE_dly = '1' or i_nWE_dly = '0' else
			i_D;
	
	i_nWE_dly <= nWE after twed;
	--todo: modelling of write delays
	
	p_write: process(A, nWE, nCS, i_A_DLY, i_D_in_dly, i_nCS_OE_dly, i_nWE_dly)
		type char_file_t is file of character;
		file char_file : char_file_t;
		variable char_v : character;
		subtype byte_t is natural range 0 to 255;
		variable byte_v : byte_t;
		variable i : integer;
		variable init : boolean := true;
	begin
		if (init) then
			if (romfile /= "") then
				report "FILE:" & romfile severity note;
				i := 0;
				file_open(char_file, romfile );
				while not endfile(char_file) and i < size loop
					read(char_file, char_v);
					byte_v := character'pos(char_v);
					i_data(i) <= std_logic_vector(to_unsigned(byte_v, 8));
					i := i + 1;
					--report "Char: " & " #" & integer'image(byte_v);
				end loop;
				file_close(char_file);
			end if;
			init := false;
		elsif (rising_edge(nWE) and i_nCS_OE_dly = '0') or (rising_edge(nCS) and i_nWE_dly = '0') then
--			report "WRITE :" & integer'image(to_integer(unsigned(i_A_DLY))) & ":" & integer'image(to_integer(unsigned(i_D_in_dly)));
			i_data(to_integer(unsigned(i_A_DLY)) mod size) <= i_D_in_dly;		-- TODO: using delayed address here not sure this is right check with datasheet!
		end if;
	end process;
	
	p_nCS_OE_dly: process
	begin
		if nCS = '1' then 
			wait for tlz;
		else
			wait for thz;		-- this is what data sheet implies but I'm not sure it's right, check with hardware?
		end if;
		i_nCS_OE_dly <= nCS;
		wait until nCS'event;
	end process;
		
	p_nOE_dly: process
	begin
		if nOE = '1' then
			wait for tolz;
		else
			wait for tohz;
		end if;
		i_nOE_dly <= nOE;
		wait until nOE'event;
	end process;
		
	p_dump: process
	type char_file_t is file of character;
	file char_file : char_file_t;
	variable char_v : character;
	variable ctr : integer := 0;
	variable i : integer;
	variable full_filename : string(1 to 256);
	begin
		--full_filename := dump_filename & INTEGER'IMAGE(ctr) & ".bin";
		wait until rising_edge(tst_dump);
		
		i := 0;
		file_open(char_file, dump_filename, write_mode );
		while  i < size loop
			char_v := CHARACTER'VAL(to_integer(unsigned(i_data(i))));
			write(char_file, char_v);
			i := i + 1;
		end loop;
		file_close(char_file);

		ctr := ctr + 1;
	end process;
		
end Behavioral;


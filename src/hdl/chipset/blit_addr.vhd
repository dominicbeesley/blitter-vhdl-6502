-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2009 Benjamin Krill <benjamin@krll.de>
-- Copyright (c) 2020 Dominic Beesley <dominic@dossytronics.net>
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

----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	10/11/2018
-- Design Name: 
-- Module Name:    	blit_addr - DMA blit address generator 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Calculate next dma address. 
--							
--
-- Dependencies: 
--	
-- Revision: 
-- Revision 0.01 - File Created
-- Revision 0.02 - use a direction indicator in preparation for line drawing mode
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.blit_types.ALL;

entity blit_addr is
	 generic (
		ram_A_hi 	: integer := 15;
		width_hi		: integer := 9;
		stride_hi	: integer := 9
	 );
    Port (
    	rst					: in		std_logic;
    	clk					: in		std_logic;
    	clk_en_start		: in		std_logic;

    	direction			: in		blit_addr_direction;

		mode_cell			: in		BOOLEAN; -- '1' - indicated CELL mode 
				
		bytes_stride		: in		SIGNED(stride_hi downto 0);	-- stride in addition to bytes_wide in cell mode this should be screen width minus 8
		width					: in		UNSIGNED(width_hi downto 0);	-- actually width in bytes - 1 for linear, in cell mode bytes = (width+1)*8 i.e. w = char cells - 1
						
		addr_in				: in		STD_LOGIC_VECTOR(ram_A_hi downto 0);
		addr_out				: out		STD_LOGIC_VECTOR(ram_A_hi downto 0);
		addr_ready			: out		STD_LOGIC;

		wrap					: in		STD_LOGIC;
		addr_min				: in		STD_LOGIC_VECTOR(ram_A_hi downto 0);
		addr_max				: in		STD_LOGIC_VECTOR(ram_A_hi downto 0)

	 );
end blit_addr;

architecture Behavioral of blit_addr is
	
	type t_state is (idle, calc, cklim, over, under);
	signal	r_state		: t_state;

	signal	i_addr_next : STD_LOGIC_VECTOR(ram_A_hi downto 0);
	signal	r_addr_out	: STD_LOGIC_VECTOR(ram_A_hi downto 0);

begin

	addr_out <= r_addr_out;
	addr_ready <= '1' when r_state = idle and clk_en_start = '0' else
					  '0';

	p_state:process(rst, clk)
	begin
		if rst = '1' then
			r_state <= idle;
			r_addr_out <= (others => '0');
		elsif rising_edge(clk) then
			if clk_en_start = '1' then
				r_state <= calc;
			else
				case r_state is 
					when calc =>
						r_addr_out <= i_addr_next;
						if wrap = '1' then
							r_state <= cklim;
						else
							r_state <= idle;
						end if;
					when cklim =>
						if r_addr_out >= addr_max then
							r_state <= over;
						elsif r_addr_out < addr_min then
							r_state <= under;
						end if;
					when over =>
						r_addr_out <= std_logic_vector(unsigned(r_addr_out) - unsigned(addr_max) + unsigned(addr_min));
						r_state <= idle;
					when under =>
						r_addr_out <= std_logic_vector(unsigned(addr_max) + unsigned(r_addr_out) - unsigned(addr_min));
						r_state <= idle;
					when others => null;
				end case;
			end if;
		end if;
	end process;


	
	p_next_addr: process(addr_in, mode_cell, bytes_stride, width, direction)
	begin

		if (mode_cell) then
			case direction is
				when CHA_E => 
					i_addr_next <= std_logic_vector(unsigned(addr_in) + 1);
				when SPR_WRAP =>
					if addr_in(2 downto 0) = "111" then
						i_addr_next <= std_logic_vector(unsigned(addr_in) + unsigned(resize(bytes_stride, ram_A_hi+1)) - (width & "000") - 7);
					else
						i_addr_next <= std_logic_vector(unsigned(addr_in) - (width & "000") + 1);
					end if;
				when PLOT_UP =>
					if addr_in(2 downto 0) = "000" then
						i_addr_next <=	std_logic_vector(unsigned(addr_in) - unsigned(resize(bytes_stride, ram_A_hi+1)) + 7);
					else
						i_addr_next <=	std_logic_vector(unsigned(addr_in) - 1);
					end if;
				when PLOT_DOWN =>
					if addr_in(2 downto 0) = "111" then
						i_addr_next <=	std_logic_vector(unsigned(addr_in) + unsigned(resize(bytes_stride, ram_A_hi+1)) - 7);
					else
						i_addr_next <=	std_logic_vector(unsigned(addr_in) + 1);
					end if;
				when PLOT_LEFT =>
					i_addr_next <= std_logic_vector(unsigned(addr_in) - 8);
				when PLOT_RIGHT =>
					i_addr_next <= std_logic_vector(unsigned(addr_in) + 8);
				when others =>
					i_addr_next <= addr_in;
			end case;
		else
			case direction is
				when CHA_E => 
					i_addr_next <= std_logic_vector(unsigned(addr_in) + 1);
				when SPR_WRAP =>
					i_addr_next <= std_logic_vector(unsigned(addr_in) + unsigned(resize(bytes_stride, ram_A_hi+1)) - width);
				when PLOT_UP =>
					i_addr_next <= std_logic_vector(unsigned(addr_in) - unsigned(resize(bytes_stride, ram_A_hi+1)));
				when PLOT_DOWN =>
					i_addr_next <= std_logic_vector(unsigned(addr_in) + unsigned(resize(bytes_stride, ram_A_hi+1)));
				when PLOT_LEFT =>
					i_addr_next <= std_logic_vector(unsigned(addr_in) - 1);
				when PLOT_RIGHT =>
					i_addr_next <= std_logic_vector(unsigned(addr_in) + 1);
				when others =>
					i_addr_next <= addr_in;
			end case;
		end if;
	end process;
end Behavioral;


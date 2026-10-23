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
-- Revision 0.03 - Oct 2026: the width/stride terms are precomputed in registers
--                  by the caller (delta_wrap, delta_wrap_mid, stride_m7), so the
--                  next address is one add/subtract of a selected operand
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
		stride_hi	: integer := 9
	 );
    Port (
    	rst					: in		std_logic;
    	clk					: in		std_logic;
    	clk_en_start		: in		std_logic;

    	direction			: in		blit_addr_direction;

		mode_cell			: in		BOOLEAN; -- '1' - indicated CELL mode 
				
		bytes_stride		: in		SIGNED(stride_hi downto 0);	-- stride in addition to bytes_wide in cell mode this should be screen width minus 8

		-- precomputed by the caller from the channel's stride and width, which
		-- are constant during a blit (width w is bytes - 1 for linear, char
		-- cells - 1 in cell mode); all modulo 2**(ram_A_hi+1)
		delta_wrap			: in		STD_LOGIC_VECTOR(ram_A_hi downto 0);	-- SPR_WRAP: cell: stride - w*8 - 7 (end of cell), linear: stride - w
		delta_wrap_mid		: in		STD_LOGIC_VECTOR(ram_A_hi downto 0);	-- SPR_WRAP, cell, not end of cell: 1 - w*8
		stride_m7			: in		STD_LOGIC_VECTOR(ram_A_hi downto 0);	-- cell PLOT_UP/PLOT_DOWN crossing a cell: stride - 7
						
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


	
	-- next address: addr_in plus or minus one selected operand, so a single
	-- carry chain (the subtract is done as add of the inverse plus carry in)
	p_next_addr: process(all)
	variable v_stride : unsigned(ram_A_hi downto 0);
	variable v_op     : unsigned(ram_A_hi downto 0);
	variable v_sub    : std_logic;
	begin
		v_stride := unsigned(resize(bytes_stride, ram_A_hi+1));
		v_sub := '0';

		if (mode_cell) then
			case direction is
				when CHA_E => 
					v_op := to_unsigned(1, v_op'length);
				when SPR_WRAP =>
					if addr_in(2 downto 0) = "111" then
						v_op := unsigned(delta_wrap);
					else
						v_op := unsigned(delta_wrap_mid);
					end if;
				when PLOT_UP =>
					if addr_in(2 downto 0) = "000" then
						v_op := unsigned(stride_m7);
						v_sub := '1';
					else
						v_op := to_unsigned(1, v_op'length);
						v_sub := '1';
					end if;
				when PLOT_DOWN =>
					if addr_in(2 downto 0) = "111" then
						v_op := unsigned(stride_m7);
					else
						v_op := to_unsigned(1, v_op'length);
					end if;
				when PLOT_LEFT =>
					v_op := to_unsigned(8, v_op'length);
					v_sub := '1';
				when PLOT_RIGHT =>
					v_op := to_unsigned(8, v_op'length);
				when others =>
					v_op := (others => '0');
			end case;
		else
			case direction is
				when CHA_E => 
					v_op := to_unsigned(1, v_op'length);
				when SPR_WRAP =>
					v_op := unsigned(delta_wrap);
				when PLOT_UP =>
					v_op := v_stride;
					v_sub := '1';
				when PLOT_DOWN =>
					v_op := v_stride;
				when PLOT_LEFT =>
					v_op := to_unsigned(1, v_op'length);
					v_sub := '1';
				when PLOT_RIGHT =>
					v_op := to_unsigned(1, v_op'length);
				when others =>
					v_op := (others => '0');
			end case;
		end if;

		i_addr_next <= std_logic_vector(
							unsigned(addr_in)
							+ (v_op xor (v_op'range => v_sub))
							+ unsigned'(0 => v_sub)
							);
	end process;
end Behavioral;


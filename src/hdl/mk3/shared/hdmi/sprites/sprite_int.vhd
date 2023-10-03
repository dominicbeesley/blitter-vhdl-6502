-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2022 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:    	30/9/2023
-- Design Name: 
-- Module Name:    	sprite_int.vhd
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Model C sprite: line comparator and serialiser
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--		See http://amigadev.elowar.com/read/ADCD_2.1/Hardware_Manual_guide/node02D6.html
-- 	Inspired by Amiga sprites but tweaked to work in an 8-bit world
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;

entity sprite_int is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up
	);
	port(

		rst_i									: in	std_logic;							

		clk_i									: in	std_logic;							-- cpu/sequencer clock
		clken_i								: in	std_logic;							-- this qualifies all clocks for seq/cpu

		-- data interface, from sequencer
		SEQ_D_i								: in	std_logic_vector(7 downto 0);
		SEQ_wren_i							: in	std_logic;
		SEQ_A_i								: in	unsigned(3 downto 0);			-- sprite data A..D, pos/ctl, ptr, lst (see below in p_regs)
		SEQ_DATAPTR_inc_i					: in	std_logic;							-- increment pointer this clock

		-- sequencer interface out
		SEQ_DATAPTR_A_o					: out	std_logic_vector(23 downto 0);-- sprite data pointer out 

		-- data interface, from CPU
		CPU_D_i								: in	std_logic_vector(7 downto 0);
		CPU_wren_i							: in	std_logic;
		CPU_A_i								: in	unsigned(3 downto 0);			-- sprite data A..D, pos/ctl, ptr, lst (see below in p_regs)

		pixel_clk_i							: in  std_logic;							-- pixel clock (not necessarily same domain as cpu/sequencer)
		pixel_clken_i						: in	std_logic;							-- move to next pixel must coincide with clken_i
		horz_ctr_i							: in	unsigned(8 downto 0); 			-- counts mode 4 pixels since horz-sync
		vert_ctr_i							: in	std_logic;

		-- pixel data out
		px_D_o								: out	std_logic_vector(1 downto 0);

		-- registers out

		horz_start_o						: out	unsigned(8 downto 0);
		vert_start_o						: out	unsigned(8 downto 0);
		vert_stop_o							: out	unsigned(8 downto 0);
		attach_o								: out	std_logic

	);
end sprite_int;

architecture rtl of sprite_int is

	-- registers
	signal r_armed					:	std_logic;									-- indicates that the sprite is armed (either by a direct cpu load or DMA)
	signal r_spr_data				:	std_logic_vector(31 downto 0);		-- this sprite line's bit map ready for transfer to serializer
	signal r_spr_serial			:	std_logic_vector(31 downto 0);
	signal r_horz_start			:	unsigned(8 downto 0);
	signal r_vert_start			:	unsigned(8 downto 0);
	signal r_vert_stop			:	unsigned(8 downto 0);
	signal r_attach				:	std_logic;
	signal r_lat_data_ptr		: 	std_logic_vector(15 downto 0);		-- latched data pointer (copied to r_data_ptr when high byte written)
	signal r_data_ptr				:	std_logic_vector(23 downto 0);		-- pointer to sprite pixel data


	-- combinatorials
	signal i_horz_eq				:  std_logic;									-- '1' when horz_ctr == r_horz_start
	signal i_serial_load			:	std_logic;									-- load the serializer at this pixel clock

begin

	horz_start_o <= r_horz_start;
	vert_start_o <= r_vert_start;
	vert_stop_o  <= r_vert_stop;
	attach_o 	 <= r_attach;

	px_D_o		 <= r_spr_serial(r_spr_serial'high downto r_spr_serial'high-1);


	-- horz comparator
	i_horz_eq <= '1' when r_horz_start = horz_ctr_i else '0';

	-- (re)arm the sprite for this line ready for comparator
	p_arm:process(clk_i, rst_i, clken_i)
	begin
		if rst_i = '1' then
			r_armed <= '0';
		elsif rising_edge(clk_i) and clken_i = '1' then
			-- arm on data write to last data byte
			-- clear on any ctl/pos change
			if SEQ_A_i(2) = '1' and SEQ_wren_i = '1' then
				r_armed <= '0';
			elsif SEQ_A_i = "011" then
				r_armed <= '1';
			end if;
		end if;
	end process;

	p_regs:process(clk_i, rst_i, clken_i)
	variable v_cur_wren 	: boolean;
	variable v_cur_A	  	: unsigned(SEQ_A_i'high downto SEQ_A_i'low);
	variable v_cur_D	  	: std_logic_vector(7 downto 0);
	variable v_wr_dptr 	: boolean;
	begin
		if rst_i = '1' then
			r_horz_start <= (others => '0');
			r_vert_start <= (others => '0');
			r_vert_stop  <= (others => '0');
			r_attach <= '0';
			r_spr_data <= (others => '0');
			r_lat_data_ptr <= (others => '0');
			r_data_ptr <= (others => '0');
		elsif rising_edge(clk_i) and clken_i = '1' then
			
			v_cur_wren := false;
			if SEQ_wren_i = '1' then
				v_cur_wren := true;
				v_cur_A := SEQ_A_i;
				v_cur_D := SEQ_D_i;
			elsif CPU_wren_i = '1' then
				v_cur_wren := true;
				v_cur_A := CPU_A_i;
				v_cur_D := CPU_D_i;
			end if;

			v_wr_dptr := false;
			if v_cur_wren then
				case to_integer(v_cur_A) is
					-- data - note pixel data is left aligned, low byte first, planar (not like Amiga?)
					when 0	=> r_spr_data(31 downto 24) <= v_cur_D;
					when 1	=> r_spr_data(23 downto 16) <= v_cur_D;
					when 2	=> r_spr_data(15 downto 8)  <= v_cur_D;
					when 3	=> r_spr_data( 7 downto 0)  <= v_cur_D;
					-- control / pos different to Amiga!
					when 4	=> r_horz_start(7 downto 0) <= unsigned(v_cur_D);
					when 5	=> r_vert_start(7 downto 0) <= unsigned(v_cur_D);
					when 6	=> r_vert_stop(7 downto 0)  <= unsigned(v_cur_D);
					when 7   =>
						-- TODO: latch h/v/etc starts until this written?!?
						r_horz_start(8) <= v_cur_D(0);
						r_vert_start(8) <= v_cur_D(1);
						r_vert_stop(8)  <= v_cur_D(2);
						r_attach			 <= v_cur_D(7);
					-- little endian data pointer (todo - CPU access in Big Endian as well?)
					when 8	=> 
						r_lat_data_ptr(7 downto 0) 			<= v_cur_D;
					when 9	=> 
						r_lat_data_ptr(7 downto 0) 			<= v_cur_D;
					when 10	=> 
						v_wr_dptr := true;					
					when others => 
						null;
				end case;
			end if;

			if v_wr_dptr then
				r_data_ptr <= v_cur_D & r_lat_data_ptr;
			elsif SEQ_DATAPTR_inc_i = '1' then
				r_data_ptr <= r_data_ptr(23 downto 16) & std_logic_vector(unsigned(r_lat_data_ptr(15 downto 0)) + 1);
			end if;


		end if;
	end process;

	p_shr:process(pixel_clk_i, rst_i, pixel_clken_i)
	begin
		if rst_i = '1' then
			r_spr_serial <= (others => '0');
		elsif rising_edge(pixel_clk_i) and pixel_clken_i = '1' then
			
			if r_armed = '1' and i_horz_eq = '1' then
				-- hit horizontal pos and we're armed
				r_spr_serial <= r_spr_data;
			else
				r_spr_serial <= r_spr_serial(r_spr_serial'high-2 downto 0) & "00";
			end if;
		end if;
	end process;
end rtl;
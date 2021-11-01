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

-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	10/11/2018
-- Design Name: 
-- Module Name:    	blit_types.vhd
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		shared types for blitter
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------

PACKAGE blit_types IS
	TYPE blit_addr_direction IS (
		CHA_E			-- just increment address always
	,  PLOT_UP		-- cell: 		subtract 1 or bytes_stride and set lower 3 bits if crossing a cell boundary
						-- notcell:		subtract bytes_stride 
	,  PLOT_DOWN	-- cell:			add 1 or bytes_stride and reset lower 3 bits if crossing a cell boundary
						-- notcell:		add bytes stride 
	,	PLOT_RIGHT	-- cell:			add 8
						-- notcell:		add 1
	,	PLOT_LEFT	-- cell:			sub 8
						-- notcell:		sub 8
	,	SPR_WRAP		-- cell:			add bytes_stride - width*8 - 7 when at end of cell (i.e. lower 3 bits set) else
						-- 				add 1 - width * 8
						-- notcell:		add bytes_stride - width
	,  NONE			-- do nothing
	);
END blit_types;
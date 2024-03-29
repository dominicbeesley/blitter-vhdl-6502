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


-- Company: 				Dossytronics
-- Engineer: 				Dominic Beesley
-- 
-- Create Date:    		30/3/2022
-- Design Name: 
-- Module Name:    		work.fb_CPU_exp_pack
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 			type definitions for wrapping CPU expansion socket pins Mk.2
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
use work.fishbone.all;

package fb_CPU_exp_pack is


	type t_cpu_wrap_exp_o is record
		CPUSKT_6BE9TSCKnVPA					:		std_logic;
		CPUSKT_9Q								:		std_logic;
		CPUSKT_KnBRZnBUSREQ					:		std_logic;
		CPUSKT_PHI09EKZCLK					:		std_logic;
		CPUSKT_RDY9KnHALTZnWAIT				:		std_logic;
		CPUSKT_nIRQKnIPL1						:		std_logic;
		CPUSKT_nNMIKnIPL02					:		std_logic;
		CPUSKT_nRES								:		std_logic;
		CPUSKT_9nFIRQLnDTACK					:		std_logic;
		CPUSKT_D									:		std_logic_vector(7 downto 0);
		CPUSKT_PHI16ABRT9BSKnDS				:     std_logic;
		CPUSKT_PHI16ABRT9BSKnDS_nOE		:		std_logic;

		-- control signals for cpu core on a per wrapper basis
		CPU_D_RnW								:		std_logic;


	end record;

	constant C_EXP_O_DUMMY : t_cpu_wrap_exp_o := (
		CPUSKT_6BE9TSCKnVPA					=> 'Z',
		CPUSKT_9Q								=> 'Z',
		CPUSKT_KnBRZnBUSREQ					=> 'Z',
		CPUSKT_PHI09EKZCLK					=> 'Z',
		CPUSKT_RDY9KnHALTZnWAIT				=> 'Z',
		CPUSKT_nIRQKnIPL1						=> 'Z',
		CPUSKT_nNMIKnIPL02					=> 'Z',
		CPUSKT_nRES								=> '0',
		CPUSKT_9nFIRQLnDTACK					=> 'Z',
		CPUSKT_D									=> (others => '-'),
		CPU_D_RnW								=> '1',
		CPUSKT_PHI16ABRT9BSKnDS				=> '1',
		CPUSKT_PHI16ABRT9BSKnDS_nOE		=> '1'
	);


	type t_cpu_wrap_exp_o_arr is array(natural range<>) of t_cpu_wrap_exp_o;

	type t_cpu_wrap_exp_i is record

		CPUSKT_6EKEZnRD						:		std_logic;		
		CPUSKT_C6nML9BUSYKnBGZnBUSACK		:		std_logic;
		CPUSKT_RnWZnWR							:		std_logic;
		CPUSKT_PHI16ABRT9BSKnDS				:		std_logic;		-- 6ABRT is actually an output but pulled up on the board
		CPUSKT_PHI26VDAKFC0ZnMREQ			:		std_logic;
		CPUSKT_SYNC6VPA9LICKFC2ZnM1		:		std_logic;
		CPUSKT_VSS6VPB9BAKnAS				:		std_logic;
		CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ		:		std_logic;		-- nSO is actually an output but pulled up on the board

		-- control signals for cpu core on a per wrapper basis
		CPUSKT_D									:		std_logic_vector(7 downto 0);
		CPUSKT_A									:		std_logic_vector(19 downto 0);

	end record;

end fb_CPU_exp_pack;
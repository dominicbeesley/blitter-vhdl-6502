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
-- Module Name:    		work.fb_CPU_pack
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 			fb_CPU type defs for mk2 board
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


package fb_CPU_pack is

	type cpu_type is (NONE, CPU_6x09, CPU_6502, CPU_65C02, CPU_65816, CPU_Z80, CPU_68K, CPU_6800, CPU_80188);
	type cpu_speed_opt is 
	(
		NONE,
		CPUSPEED_6309_3_5,
		CPUSPEED_68008_10,
		CPUSPEED_65C02_8
	);

	constant	C_CPU_BYTELANES	: positive := 1;									-- number of data byte lanes

	type t_cpu_wrap_o is record
		cyc							: std_logic_vector(C_CPU_BYTELANES-1 downto 0);
		A_log							: std_logic_vector(23 downto 0);
		we								: std_logic;
		D_WR_stb						: std_logic;
		D_WR							: std_logic_vector(7 downto 0);
		ack							: std_logic;

		CPUSKT_6BE9TSCKnVPA					:		std_logic;
		CPUSKT_9Q									:		std_logic;
		CPUSKT_KnBRZnBUSREQ					:		std_logic;
		CPUSKT_PHI09EKZCLK						:		std_logic;
		CPUSKT_RDY9KnHALTZnWAIT				:		std_logic;
		CPUSKT_nIRQKnIPL1						:		std_logic;
		CPUSKT_nNMIKnIPL02						:		std_logic;
		CPUSKT_nRES								:		std_logic;
		CPUSKT_9nFIRQLnDTACK					:		std_logic;

		CPU_D_RnW					: std_logic;

		noice_debug_5c				: std_logic;						-- A 5C instruction is being fetched (qualify with clken below)
		noice_debug_cpu_clken	: std_logic;						-- clken and cpu rdy
		noice_debug_A0_tgl		: std_logic;						-- 1 when current A0 is different to previous fetched
		noice_debug_opfetch		: std_logic;						-- this cycle is an opcode fetch

	end record;

	type t_cpu_wrap_o_arr is array(natural range<>) of t_cpu_wrap_o;

	type t_cpu_wrap_i is record

		-- direct CPU control signals from system
		nmi_n							: std_logic;
		irq_n							: std_logic;

		-- chipset control signals
		cpu_halt						: std_logic;

		-- wrapper stuff
		rdy_ctdn						: unsigned(RDY_CTDN_LEN-1 downto 0);
		cyc							: std_logic;


		noice_debug_nmi_n			: std_logic;		-- debugger is forcing a cpu NMI
		noice_debug_shadow		: std_logic;		-- debugger memory MOS map is active (overrides shadow_mos)
		noice_debug_inhibit_cpu	: std_logic;		-- during a 5C op code, inhibit address / data to avoid
																				-- spurious memory accesses
		-- optional tuning signals

		throttle_cpu_2MHz			: std_logic;		-- cpu throttle
		cpu_2MHz_phi2_clken		: std_logic;		-- sys phi2 signal for throttle

		-- cpu socket signals
		CPUSKT_D						: std_logic_vector((C_CPU_BYTELANES*8)-1 downto 0);
		CPUSKT_A						: std_logic_vector(23 downto 0);

		CPUSKT_6EKEZnRD							:	std_logic;		
		CPUSKT_C6nML9BUSYKnBGZnBUSACK		:	std_logic;
		CPUSKT_RnWZnWR							:	std_logic;
		CPUSKT_PHI16ABRT9BSKnDS				:	std_logic;		-- 6ABRT is actually an output but pulled up on the board
		CPUSKT_PHI26VDAKFC0ZnMREQ			:	std_logic;
		CPUSKT_SYNC6VPA9LICKFC2ZnM1			:	std_logic;
		CPUSKT_VSS6VPA9BAKnAS					:	std_logic;
		CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ		:	std_logic;		-- nSO is actually an output but pulled up on the board


	end record;

end fb_CPU_pack;
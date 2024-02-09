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
use work.board_config_pack.all;
use work.fb_CPU_exp_pack.all;

package fb_CPU_pack is

	type cpu_type is (NONE, CPU_6x09, CPU_6502, CPU_65C02, CPU_65816, CPU_Z80, CPU_Z180, CPU_68008, CPU_680x0, CPU_6800, CPU_80188, CPU_80186, CPU_ARM2);
	type cpu_speed_opt is 
	(
		NONE,
		CPUSPEED_6309_3_5,
		CPUSPEED_65C02_8
	);

	type t_cpu_wrap_o is record

		-- signals passed to fb_CPU_con_burst
		be								: std_logic;
		cyc							: std_logic; 
		A								: std_logic_vector(23 downto 0);
		we								: std_logic;
		lane_req						: std_logic_vector(C_CPU_BYTELANES-1 downto 0);
		D_wr							: std_logic_vector((8 * C_CPU_BYTELANES)-1 downto 0);
		D_wr_stb						: std_logic_vector(C_CPU_BYTELANES-1 downto 0);
		rdy_ctdn						: t_rdy_ctdn;
		instr_fetch					: std_logic;

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

		-- signals passed back from fb_CPU_con_burst
		rdy							: std_logic;
		act_lane						: std_logic_vector(C_CPU_BYTELANES-1 downto 0);
		ack_lane						: std_logic_vector(C_CPU_BYTELANES-1 downto 0);
		ack							: std_logic;
		D_rd							: std_logic_vector((8 * C_CPU_BYTELANES)-1 downto 0);

		noice_debug_nmi_n			: std_logic;		-- debugger is forcing a cpu NMI
		noice_debug_shadow		: std_logic;		-- debugger memory MOS map is active (overrides shadow_mos)
		noice_debug_inhibit_cpu	: std_logic;		-- during a 5C op code, inhibit address / data to avoid
																				-- spurious memory accesses
		-- optional tuning signals

		throttle_cpu_2MHz			: std_logic;		-- cpu throttle
		cpu_2MHz_phi2_clken		: std_logic;		-- sys phi2 signal for throttle


	end record;

end fb_CPU_pack;
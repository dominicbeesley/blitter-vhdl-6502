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
-- Create Date:    	9/8/2020
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - z80 pin mappings
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Map pins for z80 expansion header in t_cpu_wrap_x types to 
--							local pin signals for Mk.2 board
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

-- NOTE: this requires a board mod on the mk.2 board - the z80's RFSH pin needs to 
-- be connected to CPUSKT_VSS6VPA9BAKnAS_b2c


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.board_config_pack.all;
use work.fb_cpu_pack.all;
use work.fb_cpu_exp_pack.all;

entity fb_cpu_z80_exp_pins is
	port(

		-- cpu wrapper signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i;	

		-- local z80 wrapper signals to/from CPU expansion port 

		CPUSKT_nBUSREQ_b2c					: in std_logic;
		CPUSKT_CLK_b2c							: in std_logic;
		CPUSKT_nWAIT_b2c						: in std_logic;
		CPUSKT_nIRQ_b2c						: in std_logic;
		CPUSKT_nNMI_b2c						: in std_logic;
		CPUSKT_nRES_b2c						: in std_logic;
		CPUSKT_D_b2c							: in std_logic_vector(7 downto 0);
		BUF_D_RnW_b2c							: in std_logic;


		CPUSKT_nRD_c2b							: out std_logic;
		CPUSKT_nWR_c2b							: out std_logic;
		CPUSKT_nMREQ_c2b						: out std_logic;
		CPUSKT_nM1_c2b							: out std_logic;
		CPUSKT_nRFSH_c2b						: out std_logic;
		CPUSKT_nIOREQ_c2b						: out std_logic;
		CPUSKT_nBUSACK_c2b					: out std_logic;

		CPUSKT_D_c2b							: out std_logic_vector(7 downto 0);
		CPUSKT_A_c2b							: out std_logic_vector(15 downto 0)

	);
end fb_cpu_z80_exp_pins;

architecture rtl of fb_cpu_z80_exp_pins is
begin

	wrap_exp_o.CPUSKT_6BE9TSCKnVPA 			<= '1';
	wrap_exp_o.CPUSKT_9Q 						<= '1';
	wrap_exp_o.CPUSKT_KnBRZnBUSREQ 			<= CPUSKT_nBUSREQ_b2c;
	wrap_exp_o.CPUSKT_PHI09EKZCLK 			<= CPUSKT_CLK_b2c;
	wrap_exp_o.CPUSKT_RDY9KnHALTZnWAIT		<= CPUSKT_nWAIT_b2c;
	wrap_exp_o.CPUSKT_nIRQKnIPL1				<= CPUSKT_nIRQ_b2c;
	wrap_exp_o.CPUSKT_nNMIKnIPL02				<= CPUSKT_nNMI_b2c;
	wrap_exp_o.CPUSKT_nRES						<= CPUSKT_nRES_b2c;
	wrap_exp_o.CPUSKT_9nFIRQLnDTACK			<= '1';
	wrap_exp_o.CPUSKT_D							<=	CPUSKT_D_b2c;
	wrap_exp_o.CPU_D_RnW 						<= BUF_D_RnW_b2c;
	wrap_exp_o.CPUSKT_PHI16ABRT9BSKnDS		<= '1';
	wrap_exp_o.CPUSKT_PHI16ABRT9BSKnDS_nOE	<= '1';



	CPUSKT_nRD_c2b			<= wrap_exp_i.CPUSKT_6EKEZnRD;
	CPUSKT_nWR_c2b			<= wrap_exp_i.CPUSKT_RnWZnWR;
	CPUSKT_nMREQ_c2b		<= wrap_exp_i.CPUSKT_PHI26VDAKFC0ZnMREQ;
	CPUSKT_nM1_c2b			<= wrap_exp_i.CPUSKT_SYNC6VPA9LICKFC2ZnM1;
	CPUSKT_nRFSH_c2b		<= wrap_exp_i.CPUSKT_VSS6VPB9BAKnAS;
	CPUSKT_nIOREQ_c2b		<= wrap_exp_i.CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ;
	CPUSKT_nBUSACK_c2b	<= wrap_exp_i.CPUSKT_C6nML9BUSYKnBGZnBUSACK;

	CPUSKT_A_c2b 		<= wrap_exp_i.CPUSKT_A(15 downto 0);
	CPUSKT_D_c2b 		<= wrap_exp_i.CPUSKT_D;

end rtl;



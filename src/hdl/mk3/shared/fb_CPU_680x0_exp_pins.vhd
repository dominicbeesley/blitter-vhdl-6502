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
-- Create Date:    	15/4/2022
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - 680x0 pin mappings
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Map pins for 680x0 expansion header in t_cpu_wrap_x types to 
--							local pin signals for MK3 board
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
use work.common.all;
use work.board_config_pack.all;
use work.fb_cpu_pack.all;
use work.fb_cpu_exp_pack.all;

entity fb_cpu_680x0_exp_pins is
	port(

		-- cpu wrapper signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i;	

		-- local 68k wrapper signals to/from CPU expansion port 

		CPUSKT_VPA_i							: in std_logic;
		CPUSKT_CLK_i							: in std_logic;
		CPUSKT_nHALT_i							: in std_logic;
		CPUSKT_nIPL0_i							: in std_logic;
		CPUSKT_nIPL1_i							: in std_logic;
		CPUSKT_nIPL2_i							: in std_logic;
		CPUSKT_nRES_i							: in std_logic;
		CPUSKT_nDTACK_i						: in std_logic;

		CPU_D_RnW_i								: in std_logic;

		MUX_PORTE_nOE_i						: in std_logic;
		MUX_PORTF_nOE_i						: in std_logic;


		CPUSKT_E_o								: out std_logic;
		CPUSKT_nBG_o							: out std_logic;
		CPUSKT_RnW_o							: out std_logic;
		CPUSKT_nUDS_o							: out std_logic;
		CPUSKT_nLDS_o							: out std_logic;
		CPUSKT_FC0_o							: out std_logic;
		CPUSKT_FC2_o							: out std_logic;
		CPUSKT_nAS_o							: out std_logic;
		CPUSKT_FC1_o							: out std_logic;

		CPUSKT_D_o							: out std_logic_vector(15 downto 0);
		CPUSKT_A_o							: out std_logic_vector(23 downto 1)


	);
end fb_cpu_680x0_exp_pins;

architecture rtl of fb_cpu_680x0_exp_pins is
begin

	wrap_exp_o.exp_PORTB(0) <= CPUSKT_VPA_i;
	wrap_exp_o.exp_PORTB(1) <= '1';
	wrap_exp_o.exp_PORTB(2) <= CPUSKT_CLK_i;
	wrap_exp_o.exp_PORTB(3) <= '1';
	wrap_exp_o.exp_PORTB(4) <= CPUSKT_nIPL1_i;
	wrap_exp_o.exp_PORTB(5) <= CPUSKT_nIPL0_i;
	wrap_exp_o.exp_PORTB(6) <= CPUSKT_nIPL2_i;
	wrap_exp_o.exp_PORTB(7) <= CPUSKT_nDTACK_i;


	CPUSKT_E_o		<= wrap_exp_i.exp_PORTD(0);	
	CPUSKT_RnW_o		<= wrap_exp_i.exp_PORTD(1);
	CPUSKT_nUDS_o		<= wrap_exp_i.exp_PORTD(2);
	CPUSKT_FC0_o		<= wrap_exp_i.exp_PORTD(3);
	CPUSKT_FC2_o		<= wrap_exp_i.exp_PORTD(4);
	CPUSKT_nAS_o		<= wrap_exp_i.exp_PORTD(5);
	CPUSKT_FC1_o		<= wrap_exp_i.exp_PORTD(6);
	CPUSKT_nBG_o		<= wrap_exp_i.exp_PORTD(7);

	CPUSKT_nLDS_o		<= wrap_exp_i.CPUSKT_A(0);


	wrap_exp_o.exp_PORTD <= (
		8 => '1',										-- nBR
		9 => CPUSKT_nRES_i,
		10 => CPUSKT_nHALT_i,					-- 68K halt
		others => '1'
		);

	wrap_exp_o.exp_PORTD_o_en <= (
		8 => '1',
		9 => '1',
		10 => '1',
		others => '0'
		);

	wrap_exp_o.exp_PORTE_nOE <= MUX_PORTE_nOE_i;
	wrap_exp_o.exp_PORTF_nOE <= MUX_PORTF_nOE_i;

	wrap_exp_o.CPU_D_RnW 	<= CPU_D_RnW_i;
	CPUSKT_A_o 		<= wrap_exp_i.CPUSKT_A(23 downto 1);
	CPUSKT_D_o 		<= wrap_exp_i.CPUSKT_D;

end rtl;



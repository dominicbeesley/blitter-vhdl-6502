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
-- Module Name:    	fishbone bus - CPU wrapper component - 80188 pin mappings
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Map pins for 80188 expansion header in t_cpu_wrap_x types to 
--							local pin signals for MK2 board
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

entity fb_cpu_80188_exp_pins is
	port(

		-- cpu wrapper signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i;	

		-- local 80188 wrapper signals to/from CPU expansion port 

		CPUSKT_nTEST_i		: in  std_logic;
		CPUSKT_X1_i			: in  std_logic;
		CPUSKT_SRDY_i		: in  std_logic;
		CPUSKT_ARDY_i		: in  std_logic;
		CPUSKT_INT0_i		: in  std_logic;
		CPUSKT_nNMI_i		: in  std_logic;
		CPUSKT_nRES_i		: in  std_logic;
		CPUSKT_INT1_i		: in  std_logic;
		CPUSKT_DRQ0_i		: in  std_logic;
		CPUSKT_INT2_i		: in  std_logic;
		CPUSKT_HOLD_i		: in  std_logic;
		CPUSKT_INT3_i		: in  std_logic;

		CPU_D_RnW_i			: in std_logic;

		CPUSKT_nS_o			: out std_logic_vector(2 downto 0);
		CPUSKT_nUCS_o		: out std_logic;
		CPUSKT_nLCS_o		: out std_logic;
		CPUSKT_RESET_o		: out std_logic;
		CPUSKT_CLKOUT_o	: out std_logic;
		CPUSKT_nRD_o		: out std_logic;
		CPUSKT_nWR_o		: out std_logic;
		CPUSKT_nDEN_o		: out std_logic;
		CPUSKT_DTnR_o		: out std_logic;
		CPUSKT_ALE_o		: out std_logic;
		CPUSKT_HLDA_o		: out std_logic;
		CPUSKT_nLOCK_o		: out std_logic;

		CPUSKT_D_o			: out std_logic_vector(7 downto 0);
		CPUSKT_A_o			: out std_logic_vector(19 downto 8)


	);
end fb_cpu_80188_exp_pins;

architecture rtl of fb_cpu_80188_exp_pins is
begin

	wrap_exp_o.exp_PORTB(0)	<= CPUSKT_nTEST_i;
	wrap_exp_o.exp_PORTB(1)	<= CPUSKT_ARDY_i;
	wrap_exp_o.exp_PORTB(2)	<= CPUSKT_X1_i;
	wrap_exp_o.exp_PORTB(3)	<= CPUSKT_SRDY_i;
	wrap_exp_o.exp_PORTB(4)	<= CPUSKT_INT0_i;
	wrap_exp_o.exp_PORTB(5)	<= CPUSKT_nNMI_i;
	wrap_exp_o.exp_PORTB(6)	<= CPUSKT_nRES_i;
	wrap_exp_o.exp_PORTB(7)	<= CPUSKT_INT1_i;

	CPUSKT_nS_o(0)		<= wrap_exp_i.CPUSKT_A(0);
	CPUSKT_nS_o(1)		<= wrap_exp_i.CPUSKT_A(1);
	CPUSKT_nS_o(2)		<= wrap_exp_i.CPUSKT_A(2);
	CPUSKT_nUCS_o		<= wrap_exp_i.CPUSKT_A(3);
	CPUSKT_nLCS_o		<= wrap_exp_i.CPUSKT_A(4);
	CPUSKT_RESET_o		<= wrap_exp_i.CPUSKT_A(5);
	CPUSKT_CLKOUT_o	<= wrap_exp_i.CPUSKT_A(6);


	CPUSKT_nRD_o		<= wrap_exp_i.exp_PORTD(0);
	CPUSKT_nWR_o		<= wrap_exp_i.exp_PORTD(1);
	CPUSKT_nDEN_o		<= wrap_exp_i.exp_PORTD(2);
	CPUSKT_DTnR_o		<= wrap_exp_i.exp_PORTD(4);
	CPUSKT_ALE_o		<= wrap_exp_i.exp_PORTD(5);
	CPUSKT_HLDA_o		<= wrap_exp_i.exp_PORTD(7);
	CPUSKT_nLOCK_o		<= wrap_exp_i.exp_PORTD(11);

	wrap_exp_o.exp_PORTD <= (
		3						=> CPUSKT_INT2_i,
		6						=> CPUSKT_DRQ0_i,
		8						=> CPUSKT_HOLD_i,
		10						=> CPUSKT_INT3_i,
		others				=> '1'
		);

	wrap_exp_o.exp_PORTD_o_en <= (
		3 => '1',
		6 => '1',
		8 => '1',
		10 => '1',	
		others => '0'
		);

	wrap_exp_o.exp_PORTE_nOE <= '0';
	wrap_exp_o.exp_PORTF_nOE <= '1';

	wrap_exp_o.CPU_D_RnW 	<= CPU_D_RnW_i;
	CPUSKT_A_o 		<= wrap_exp_i.CPUSKT_A(19 downto 8);
	CPUSKT_D_o 		<= wrap_exp_i.CPUSKT_D(7 downto 0);

end rtl;



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
-- Create Date:    	30/5/2023
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - 386ex pin mappings
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Map pins for 386ex expansion header in t_cpu_wrap_x types to 
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

entity fb_cpu_386ex_exp_pins is
	port(

		-- cpu wrapper signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i;	

		-- local 386ex wrapper signals to/from CPU expansion port 

		CPUSKT_nSMI_b2c		: in  std_logic;
		CPUSKT_DRQ_b2c			: in  std_logic;
		CPUSKT_CLK2_b2c		: in  std_logic;
		CPUSKT_nREADY_b2c		: in  std_logic;
		CPUSKT_nINT0_b2c		: in  std_logic;
		CPUSKT_nNMI_b2c		: in  std_logic;
		CPUSKT_RESET_b2c		: in  std_logic;
		CPUSKT_D_b2c			: in  std_logic_vector(15 downto 0);

		CPUSKT_nNA_b2c			: in  std_logic;

		BUF_D_RnW_b2c			: in  std_logic;	

		MUX_PORTE_nOE_i		: in  std_logic;
		MUX_PORTF_nOE_i		: in  std_logic;

		CPUSKT_WnR_c2b			: out std_logic;
		CPUSKT_nBHE_c2b		: out std_logic;
		CPUSKT_MnIO_c2b		: out std_logic;
		CPUSKT_DnC_c2b			: out std_logic;
		CPUSKT_nADS_c2b		: out std_logic;
		CPUSKT_nLBA_c2b		: out std_logic;
		CPUSKT_nREFRESH_c2b	: out std_logic;
		CPUSKT_CLKOUT_c2b		: out std_logic;
		CPUSKT_nSMIACT_c2b	: out std_logic;
		CPUSKT_nUCS_c2b		: out std_logic;
		CPUSKT_nREADY_c2b		: out std_logic;

		CPUSKT_D_c2b			: out std_logic_vector(15 downto 0);
		CPUSKT_A_c2b			: out std_logic_vector(23 downto 0)


	);
end fb_cpu_386ex_exp_pins;

architecture rtl of fb_cpu_386ex_exp_pins is
begin

	CPUSKT_D_c2b(7 downto 0)
	 							<= wrap_exp_i.PORTA;

	wrap_exp_o.PORTA		<= CPUSKT_D_b2c(7 downto 0);
	wrap_exp_o.PORTA_nOE <= '0';
	wrap_exp_o.PORTA_DIR <= not BUF_D_RnW_b2c;

	wrap_exp_o.PORTB(0)	<= CPUSKT_nSMI_b2c;
	wrap_exp_o.PORTB(1)	<= CPUSKT_DRQ_b2c;
	wrap_exp_o.PORTB(2)	<= CPUSKT_CLK2_b2c;
--	wrap_exp_o.PORTB(3)	<= CPUSKT_nREADY_b2c;	-- original board mistake!
	wrap_exp_o.PORTB(4)	<= CPUSKT_nINT0_b2c;
	wrap_exp_o.PORTB(5)	<= CPUSKT_nNMI_b2c;
	wrap_exp_o.PORTB(6)	<= CPUSKT_RESET_b2c;
	wrap_exp_o.PORTB(7)	<= '0';						-- reserved

	CPUSKT_A_c2b(7 downto 0)
	 							<= wrap_exp_i.PORTC(7 downto 0);
	CPUSKT_A_c2b(19 downto 16)	
								<= wrap_exp_i.PORTC(11 downto 8);

	CPUSKT_WnR_c2b			<= wrap_exp_i.PORTD(0);
	CPUSKT_nBHE_c2b		<= wrap_exp_i.PORTD(2);
	CPUSKT_MnIO_c2b		<= wrap_exp_i.PORTD(3);
	CPUSKT_DnC_c2b			<= wrap_exp_i.PORTD(4);
	CPUSKT_nADS_c2b		<= wrap_exp_i.PORTD(5);
	CPUSKT_nLBA_c2b		<= wrap_exp_i.PORTD(6);
	CPUSKT_nREFRESH_c2b	<= wrap_exp_i.PORTD(8);
	CPUSKT_CLKOUT_c2b		<= wrap_exp_i.PORTD(9);
	CPUSKT_nSMIACT_c2b	<= wrap_exp_i.PORTD(10);
	CPUSKT_nUCS_c2b		<= wrap_exp_i.PORTD(11);

	wrap_exp_o.PORTD <= (
		1						=> CPUSKT_nREADY_b2c,
		7						=> CPUSKT_nNA_b2c,
		others				=> '1'
		);

	wrap_exp_o.PORTD_o_en <= (
		1 => wrap_exp_i.PORTD(6), -- nLBA signal in
		7 => '1',	
		others => '0'
		);

	wrap_exp_o.PORTE_i_nOE <= MUX_PORTE_nOE_i;
	wrap_exp_o.PORTE_o_nOE 	<= '1';
	wrap_exp_o.PORTF_i_nOE <= MUX_PORTF_nOE_i or BUF_D_RnW_b2c;
	wrap_exp_o.PORTF_o_nOE <= MUX_PORTF_nOE_i or not BUF_D_RnW_b2c;

	wrap_exp_o.PORTF(11 downto 4) <= CPUSKT_D_b2c(15 downto 8);
	CPUSKT_D_c2b(15 downto 8) <= wrap_exp_i.PORTEFG(11 downto 4);

	CPUSKT_A_c2b(15 downto 8) <= wrap_exp_i.PORTEFG(7 downto 0);
	CPUSKT_A_c2b(23 downto 20) <= wrap_exp_i.PORTEFG(11 downto 8);

end rtl;



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
-- Create Date:    	7/4/2022
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - 65c02 pin mappings
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Map pins for 65c02 expansion header in t_cpu_wrap_x types to 
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

entity fb_cpu_65C02_exp_pins is
	port(

		-- cpu wrapper signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i;	

		-- local 65c02 wrapper signals to/from CPU expansion port 

		CPUSKT_BE_b2c							: in std_logic;
		CPUSKT_PHI0_b2c						: in std_logic;
		CPUSKT_RDY_b2c							: in std_logic;
		CPUSKT_nIRQ_b2c						: in std_logic;
		CPUSKT_nNMI_b2c						: in std_logic;
		CPUSKT_nRES_b2c						: in std_logic;
		CPUSKT_D_b2c							: in std_logic_vector(7 downto 0);

		BUF_D_RnW_b2c							: in std_logic;

		CPUSKT_RnW_c2b							: out std_logic;
		CPUSKT_SYNC_c2b						: out std_logic;
		CPUSKT_VPB_c2b							: out std_logic;
		CPUSKT_D_c2b							: out std_logic_vector(7 downto 0);
		CPUSKT_A_c2b							: out std_logic_vector(15 downto 0)

	);
end fb_cpu_65C02_exp_pins;

architecture rtl of fb_cpu_65C02_exp_pins is
begin

	CPUSKT_D_c2b <= wrap_exp_i.PORTA;
	wrap_exp_o.PORTA <= CPUSKT_D_b2c;
	wrap_exp_o.PORTA_nOE <= '0';
	wrap_exp_o.PORTA_DIR <= not BUF_D_RnW_b2c;

	wrap_exp_o.PORTB(0) <= CPUSKT_BE_b2c;
	wrap_exp_o.PORTB(1) <= '1';
	wrap_exp_o.PORTB(2) <= CPUSKT_PHI0_b2c;
	wrap_exp_o.PORTB(3) <= CPUSKT_RDY_b2c;
	wrap_exp_o.PORTB(4) <= CPUSKT_nIRQ_b2c;
	wrap_exp_o.PORTB(5) <= CPUSKT_nNMI_b2c;
	wrap_exp_o.PORTB(6) <= CPUSKT_nRES_b2c;
	wrap_exp_o.PORTB(7) <= '1';

	CPUSKT_A_c2b(7 downto 0) <= wrap_exp_i.PORTC(7 downto 0);

	CPUSKT_RnW_c2b		<= wrap_exp_i.PORTD(1);
	CPUSKT_SYNC_c2b		<= wrap_exp_i.PORTD(4);
	CPUSKT_VPB_c2b		<= wrap_exp_i.PORTD(5);


	wrap_exp_o.PORTD <= (
		others => '1'
		);

	wrap_exp_o.PORTD_o_en <= (
		others => '0'
		);

	wrap_exp_o.PORTE_i_nOE <= '0';
	wrap_exp_o.PORTE_o_nOE <= '1';	
	wrap_exp_o.PORTF_i_nOE <= '1';
	wrap_exp_o.PORTF_o_nOE <= '1';

	wrap_exp_o.PORTF <= (others => '-');

	CPUSKT_A_c2b(15 downto 8) <= wrap_exp_i.PORTEFG(7 downto 0);


end rtl;



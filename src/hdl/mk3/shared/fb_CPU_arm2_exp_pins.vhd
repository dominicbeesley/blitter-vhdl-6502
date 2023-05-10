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
-- Create Date:    	19/7/2022
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - 680x0 pin mappings
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Map pins for arm2 expansion header in t_cpu_wrap_x types to 
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

entity fb_cpu_arm2_exp_pins is
	port(

		-- cpu wrapper signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i;	

		-- local arm2 wrapper signals to/from CPU expansion port 

		CPUSKT_ABRT_b2c							: in std_logic;
		CPUSKT_phi1_b2c							: in std_logic;
		CPUSKT_phi2_b2c							: in std_logic;
		CPUSKT_nIRQ_b2c							: in std_logic;
		CPUSKT_nFIRQ_b2c							: in std_logic;
		CPUSKT_RES_b2c								: in std_logic;
		
		CPUSKT_D_mux_b2c							: in std_logic_vector(7 downto 0);
		CPUBRD_nBL_b2c								: in std_logic_vector(3 downto 0);
		BUF_D_RnW_b2c								: in std_logic;

		CPUSKT_nM_c2b								: out std_logic_vector(1 downto 0);
		CPUSKT_nRW_c2b								: out std_logic;
		CPUSKT_nBW_c2b								: out std_logic;
		CPUSKT_nOPC_c2b							: out std_logic;
		CPUSKT_nMREQ_c2b							: out std_logic;
		CPUSKT_nTRAN_c2b							: out std_logic;
		CPUSKT_SEQ_c2b								: out std_logic;
		CPUSKT_A_c2b								: out std_logic_vector(25 downto 0);

		CPUSKT_D_mux_c2b							: out std_logic_vector(7 downto 0)


	);
end fb_cpu_arm2_exp_pins;

architecture rtl of fb_cpu_arm2_exp_pins is
begin

	CPUSKT_D_mux_c2b(7 downto 0) 	<= wrap_exp_i.PORTA;
	wrap_exp_o.PORTA 					<= CPUSKT_D_mux_b2c(7 downto 0);
	wrap_exp_o.PORTA_nOE 			<= '0';
	wrap_exp_o.PORTA_DIR 			<= not BUF_D_RnW_b2c;

	wrap_exp_o.PORTB(0) <= CPUSKT_ABRT_b2c;
	wrap_exp_o.PORTB(1) <= CPUSKT_phi1_b2c;
	wrap_exp_o.PORTB(2) <= CPUSKT_phi2_b2c;
	wrap_exp_o.PORTB(3) <= CPUBRD_nBL_b2c(3);
	wrap_exp_o.PORTB(4) <= CPUBRD_nBL_b2c(2);
	wrap_exp_o.PORTB(5) <= CPUBRD_nBL_b2c(1);
	wrap_exp_o.PORTB(6) <= CPUSKT_RES_b2c;
	wrap_exp_o.PORTB(7) <= CPUBRD_nBL_b2c(0);

	CPUSKT_A_c2b(7 downto 0) 	<= wrap_exp_i.PORTC(7 downto 0);
	CPUSKT_A_c2b(19 downto 16) <= wrap_exp_i.PORTC(11 downto 8);

	CPUSKT_nM_c2b(0)		<= wrap_exp_i.PORTD(0);
	CPUSKT_nRW_c2b			<= wrap_exp_i.PORTD(1);
	CPUSKT_nBW_c2b			<= wrap_exp_i.PORTD(2);
	CPUSKT_nM_c2b(1)		<= wrap_exp_i.PORTD(3);
	CPUSKT_nOPC_c2b		<= wrap_exp_i.PORTD(4);
	CPUSKT_nMREQ_c2b		<= wrap_exp_i.PORTD(5);
	CPUSKT_nTRAN_c2b		<= wrap_exp_i.PORTD(6);
	CPUSKT_A_c2b(24)		<= wrap_exp_i.PORTD(7);
	CPUSKT_A_c2b(25)		<= wrap_exp_i.PORTD(8);
	CPUSKT_SEQ_c2b			<= wrap_exp_i.PORTD(11);





	wrap_exp_o.PORTD <= (
		9	=>  CPUSKT_nIRQ_b2c,
		10 =>  CPUSKT_nFIRQ_b2c,
		others => '1'
		);

	wrap_exp_o.PORTD_o_en <= (
		9	=> '1',
		10	=> '1',
		others => '0'
		);

	wrap_exp_o.PORTE_i_nOE <= '0';
	wrap_exp_o.PORTE_o_nOE <= '1';	
	wrap_exp_o.PORTF_i_nOE <= '1';
	wrap_exp_o.PORTF_o_nOE <= '1';
	wrap_exp_o.PORTF <= (others => '-');

	CPUSKT_A_c2b(15 downto 8) <= wrap_exp_i.PORTEFG(7 downto 0);
	CPUSKT_A_c2b(23 downto 20) <= wrap_exp_i.PORTEFG(11 downto 8);

end rtl;



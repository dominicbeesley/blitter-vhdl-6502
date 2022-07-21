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

		CPUSKT_ABRT_i							: in std_logic;
		CPUSKT_phi1_i							: in std_logic;
		CPUSKT_phi2_i							: in std_logic;
		CPUSKT_nIRQ_i							: in std_logic;
		CPUSKT_nFIRQ_i							: in std_logic;
		CPUSKT_nRES_i							: in std_logic;

		CPUBRD_nBL_i							: in std_logic_vector(3 downto 0);
		CPUSKT_CPB_i							: in std_logic;
		CPUSKT_CPA_i							: in std_logic;


		CPU_D_RnW_i								: in std_logic;

		CPUSKT_nM_o								: out std_logic_vector(1 downto 0);
		CPUSKT_nRW_o							: out std_logic;
		CPUSKT_nBW_o							: out std_logic;
		CPUSKT_nOPC_o							: out std_logic;
		CPUSKT_nMREQ_o							: out std_logic;
		CPUSKT_nTRAN_o							: out std_logic;
		CPUSKT_nCPI_o							: out std_logic;

		CPUSKT_D_o								: out std_logic_vector(7 downto 0);
		CPUSKT_A_o								: out std_logic_vector(23 downto 0)


	);
end fb_cpu_arm2_exp_pins;

architecture rtl of fb_cpu_arm2_exp_pins is
begin

	wrap_exp_o.exp_PORTB(0) <= CPUSKT_ABRT_i;
	wrap_exp_o.exp_PORTB(1) <= CPUSKT_phi1_i;
	wrap_exp_o.exp_PORTB(2) <= CPUSKT_phi2_i;
	wrap_exp_o.exp_PORTB(3) <= CPUBRD_nBL_i(0);
	wrap_exp_o.exp_PORTB(4) <= CPUSKT_nIRQ_i;
	wrap_exp_o.exp_PORTB(5) <= CPUSKT_nFIRQ_i;
	wrap_exp_o.exp_PORTB(6) <= CPUSKT_nRES_i;
	wrap_exp_o.exp_PORTB(7) <= CPUBRD_nBL_i(1);



	CPUSKT_nM_o(0)		<= wrap_exp_i.exp_PORTD(0);
	CPUSKT_nRW_o		<= wrap_exp_i.exp_PORTD(1);
	CPUSKT_nBW_o		<= wrap_exp_i.exp_PORTD(2);
	CPUSKT_nM_o(1)		<= wrap_exp_i.exp_PORTD(3);
	CPUSKT_nOPC_o		<= wrap_exp_i.exp_PORTD(4);
	CPUSKT_nMREQ_o		<= wrap_exp_i.exp_PORTD(5);
	CPUSKT_nTRAN_o		<= wrap_exp_i.exp_PORTD(6);
	CPUSKT_nCPI_o		<= wrap_exp_i.exp_PORTD(9);




	wrap_exp_o.exp_PORTD <= (
		7 =>  CPUBRD_nBL_i(2),
		8 => CPUBRD_nBL_i(3),
		10 => CPUSKT_CPB_i,
		11 => CPUSKT_CPA_i,
		others => '1'
		);

	wrap_exp_o.exp_PORTD_o_en <= (
		7 => '1',
		8 => '1',
		10 => '1',
		11 => '1',
		others => '0'
		);

	wrap_exp_o.exp_PORTE_nOE <= '0';
	wrap_exp_o.exp_PORTF_nOE <= '1';

	wrap_exp_o.CPU_D_RnW 	<= CPU_D_RnW_i;
	CPUSKT_A_o 		<= wrap_exp_i.CPUSKT_A;
	CPUSKT_D_o 		<= wrap_exp_i.CPUSKT_D(7 downto 0);

end rtl;



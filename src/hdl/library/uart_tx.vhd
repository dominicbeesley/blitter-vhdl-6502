-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2023 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:    	25/4/2023
-- Design Name: 
-- Module Name:    	uart_tx
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Simple uart for debugging purposes. baud_clk_i should be
--						at the baud rate. No handshaking, format = 8n1
--						client CPU should set tx_data_i and set tx_req_i <= not tx_ack_o
--						the tx_ack_o signal will flip once the character has been
--						transmitted. tx_data_i should remain stable after tx_req_i
--						has been set.
--						The data and req signals are registered in the clock domain
--						set a false path from the CPU clock domain, assumes that
--						baud clock rate is << cpu clock
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
use work.common.all;
use work.fishbone.all;
use work.fb_CPU_pack.all;
use work.fb_intcon_pack.all;
use work.board_config_pack.all;

entity uart_tx is
	port(
		-- serial signals

		baud_clk_i						: in		std_logic;
		ser_tx_o							: out		std_logic;

		-- cpu signals

		rst_i								: in std_logic;
		tx_data_i						: in std_logic_vector(7 downto 0);
		tx_req_i							: in std_logic;
		tx_ack_o							: out std_logic

	);
end uart_tx;

architecture rtl of uart_tx is

	signal	r_tx_char			: std_logic_vector(7 downto 0);
	signal	r_tx_req				: std_logic;
	signal	r_tx_ack				: std_logic;
	signal   r_ser_tx				: std_logic;
	signal	r_shift				: std_logic_vector(8 downto 0);

	type tx_state is (idle, shift);
	
	signal	r_state : tx_state;

begin

	ser_tx_o <= r_ser_tx;
	tx_ack_o <= r_tx_ack;

	p_meta:process(baud_clk_i, rst_i)
	begin
		if rst_i = '1' then
			r_tx_req <= '0';
		elsif rising_edge(baud_clk_i) then
			r_tx_req <= tx_req_i;
		end if;
	end process;

	p_state:process(baud_clk_i, rst_i)
	begin
		if rst_i = '1' then
			r_tx_ack <= '0';
			r_state <= idle;
			r_ser_tx <= '1';
			r_shift <= (r_shift'high => '1', others => '0');
		elsif rising_edge(baud_clk_i) then
			
			r_shift <= '0' & r_shift(r_shift'high downto 1);

			case r_state is
				when idle =>

					if r_tx_req /= r_tx_ack then
						r_tx_char <= tx_data_i;
						r_ser_tx <= '0';		-- start bit for one clock
						r_shift <= (r_shift'high => '1', others => '0');
						r_state <= shift;
						r_tx_ack <= r_tx_req; -- we've got the char in the shift register, can accept another...later
					end if;
				when shift =>
					if r_shift(0) = '1' then
						r_state <= idle;
						r_ser_tx <= '1';
					else
						r_ser_tx <= r_tx_char(0);
						r_tx_char <= '0' & r_tx_char(r_tx_char'high downto 1);
					end if;				
				when others =>
					r_state <= idle;
					r_ser_tx <= '1';
					r_tx_ack <= r_tx_req;
			end case;
			
		end if;
	end process;

end rtl;
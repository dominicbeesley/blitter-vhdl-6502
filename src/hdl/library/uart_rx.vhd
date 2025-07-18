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
-- Module Name:    	uart_rx
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Simple uart for debugging purposes. baud_clken_i should be
--						at 16 times the baud rate. No handshaking, format = 8n1
--						client CPU should set tx_data_i and set tx_req_i <= not tx_ack_o
--						the tx_ack_o signal will flip once the character has been
--						transmitted. tx_data_i should remain stable after tx_req_i
--						has been set.
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

entity uart_rx is
	port(
		-- serial signals

		clk_i								: in     std_logic;
		baud16_clken_i					: in		std_logic;
		ser_rx_i							: in		std_logic;

		-- cpu signals

		rst_i								: in std_logic;

		rx_dat_o							: out std_logic_vector(7 downto 0);
		rx_ferr_o						: out std_logic;
		rx_req_o							: out std_logic								-- flips when character received

	);
end uart_rx;

architecture rtl of uart_rx is

	type rx_state is (idle, start_bit, shift, stop_bit);
	
	signal	r_state : rx_state;

	signal	r_dat		: std_logic_vector(7 downto 0) 
												:= (others => '0');
	signal	r_shift	: std_logic_vector(7 downto 0) 
												:= (others => '0');
	signal   r_ix		: unsigned(2 downto 0)	
												:= (others => '0');	-- bit number - we read 8 plus start and stop
	signal   r_subctr : unsigned(3 downto 0)	
												:= (others => '0');	-- intra bit counter (16 for 1 bit, 8 for half)

	signal   r_ser_rx : std_logic_vector(3 downto 0) := 
												(others => '0');		-- meta stability and change detection

	signal   r_req    : std_logic		:= '0';
	signal   r_ferr   : std_logic		:= '0';

begin

	rx_req_o <= r_req;
	rx_dat_o <= r_dat;
	rx_ferr_o <= r_ferr;

	p_meta:process(clk_i)
	begin
		if rising_edge(clk_i) then
		   if baud16_clken_i = '1' then
				r_ser_rx <= r_ser_rx(r_ser_rx'high-1 downto 0) & ser_rx_i ;
			end if;
		end if;
	end process;

	p_state:process(clk_i)
	begin
		if rising_edge(clk_i) then
			if rst_i = '1' then
				r_req <= '0';
				r_state <= idle;
				r_ix <= (others => '0');
				r_subctr <= (others => '0');
				r_dat <= (others => '0');				
				r_shift <= (others => '0');				
				r_ferr <= '0';
			elsif baud16_clken_i = '1' then
				r_subctr <= r_subctr + 1;
				case r_state is
					when idle =>
						if r_ser_rx(0) = '0' and r_ser_rx(1) = '1' then
							r_subctr <= to_unsigned(8, r_subctr'length);
							r_state <= start_bit;
						end if;
					when start_bit =>
						if r_subctr = 0 then
							r_ix <= (others => '0');
							r_state <= shift;
						end if;
					when shift =>
						if r_subctr = 0 then
							r_ix <= r_ix + 1;
							r_shift <= r_ser_rx(0) & r_shift(7 downto 1);
							if to_integer(r_ix) = 7 then							
								r_state <= stop_bit;
							end if;
						end if;
					when stop_bit =>
						if r_subctr = 0 then
							if r_ser_rx(0) = '1' then
								r_dat <= r_shift;
							else
								r_ferr <= '1';
							end if;
							r_req <= not r_req;
							r_state <= idle;
						end if;							
					when others =>
						r_state <= idle;
						r_ferr <= '1';
						r_req <= '1';
				end case;
				
			end if;
		end if;
	end process;

end rtl;
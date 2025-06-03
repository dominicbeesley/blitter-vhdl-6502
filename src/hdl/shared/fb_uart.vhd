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
-- Module Name:    	fb_uart
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Simple uart for debugging purposes. BAUD_CLK_16 should be
--							16x the baud rate. No handshaking, format = 8n1
--							Even addresses read status:
--								(7) - rx data full i.e. data available, read data to clear
--								(6) - tx data full i.e. you should wait to write data data, a char is being xmitted
--								(0) - framing error
--							Odd addresses read/write data from/to rx/tx
--							There is no overrun detection
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

entity fb_uart is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural := 128								-- fast clock speed in mhz				
	);
	port(
		-- serial signals

		baud16_clken_i						: in		std_logic;							-- clocked in fishbone domain 16x baud rate
		ser_rx_i								: in		std_logic;
		ser_tx_o								: out		std_logic;

		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t

	);
end fb_uart;

architecture rtl of fb_uart is

	signal i_tx_ack	: std_logic;
	signal r_tx_req	: std_logic;

	signal r_fb_ack	: std_logic;
	type state_t is (idle, wait_wr_stb);
	signal r_state    : state_t;
	signal r_wr_addr	: std_logic;
	signal i_wr_addr	: std_logic;
	signal r_tx_char	: std_logic_vector(7 downto 0);

	signal r_clk_div	: unsigned(3 downto 0); -- divide the 16x clock down for TX
	signal r_clken_baud	: std_logic;

	signal i_rx_req	: std_logic;
	signal r_rx_ack	: std_logic;

	signal i_rx_ferr  : std_logic;

	signal i_rx_dat   : std_logic_vector(7 downto 0);
begin

	fb_p2c_o.D_rd <= 	(7 => i_rx_req xor r_rx_ack, 6 => i_tx_ack xor r_tx_req, 0 => i_rx_ferr, others => '0') when fb_c2p_i.A(0) = '0' else
							i_rx_dat;
	fb_p2c_o.ack <= r_fb_ack;
	fb_p2c_o.rdy <= r_fb_ack;
	fb_p2c_o.stall <= '0' when r_state = idle else '1';

	i_wr_addr <= 	fb_c2p_i.A(0) when r_state = idle else
						r_wr_addr;

	p_state:process(fb_syscon_i)
	variable v_dowrite: boolean;
	begin
		
		if fb_syscon_i.rst = '1' then
			r_fb_ack <= '0';
			r_tx_req <= '0';
			r_rx_ack <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			
			v_dowrite := false;

			r_fb_ack <= '0';

			case r_state is
				when idle =>
					if fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' then
						r_wr_addr <= fb_c2p_i.A(0);
						if fb_c2p_i.we = '1' then
							if fb_c2p_i.D_wr_stb = '1' then
								v_dowrite := true;
							else
								r_state <= wait_wr_stb;
							end if;
						else
							r_fb_ack <= '1';						
							if fb_c2p_i.A(0) = '1' then
								-- ack read of data
								r_rx_ack <= i_rx_req;
							end if;

						end if;
					end if;
				when wait_wr_stb =>
					if fb_c2p_i.D_wr_stb = '1' then
						v_dowrite := true;
						r_state <= idle;
					end if;
				when others =>
					r_state <= idle;

			end case;


			if v_dowrite then
				if i_wr_addr = '1' then
					-- write to TX
					r_tx_req <= not i_tx_ack;
					r_tx_char <= fb_c2p_i.D_wr;
				end if;
				r_fb_ack <= '1';
			end if;

		end if;
	end process;

	e_tx:entity work.uart_tx
	port map (
		clk_i	=> fb_syscon_i.clk,
		baud_clken_i => r_clken_baud,
		ser_tx_o => ser_tx_o,
		rst_i => fb_syscon_i.rst,
		tx_data_i => r_tx_char,
		tx_req_i => r_tx_req,
		tx_ack_o => i_tx_ack
		);

	e_rx:entity work.uart_rx
	port map (
		clk_i				=> fb_syscon_i.clk,
		baud16_clken_i => baud16_clken_i,
		ser_rx_i 		=> ser_rx_i,
		rst_i 			=> fb_syscon_i.rst,
		rx_dat_o			=> i_rx_dat,
		rx_ferr_o		=> i_rx_ferr,
		rx_req_o			=> i_rx_req
		);

	p_clk_div:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			r_clken_baud <= '0';
			if fb_syscon_i.rst = '1' then
				r_clk_div <= (others => '0');
			elsif baud16_clken_i = '1' then
				r_clk_div <= r_clk_div - 1;
				if r_clk_div = 0 then
					r_clken_baud <= '1';
				end if;
			end if;
		end if;
	end process;

end rtl;
-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2020 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:    	14/02/2024
-- Design Name: 
-- Module Name:    	fishbone bus - spi
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for spi bus
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------


--
-- The spi component has the following registers

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.fishbone.all;
use work.common.all;


entity fb_spi is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural := 128;								-- fast clock speed in mhz				
		DEFAULT_SPEED						: natural := 400000							-- default SPI bus speed in Hz
	);
	port(

		-- SPI signals

		SPI_CS_o								: out		std_logic_vector(7 downto 0);
		SPI_CLK_o							: out		std_logic;
		SPI_MOSI_o							: out		std_logic;
		SPI_MISO_i							: in		std_logic;
		SPI_DET_i							: in		std_logic;


		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t

	);
end fb_spi;

architecture rtl of fb_spi is

	constant C_FAST_CLKDIV4		: natural := natural(ceil(real(CLOCKSPEED*1000000)/real(DEFAULT_SPEED*4))); -- divider for 4 phase clock
	signal	r_4ph_ctr			: unsigned(numbits(C_FAST_CLKDIV4)-1 downto 0) := (others => '0');
	signal	r_4ph_clken			: std_logic;
	signal	r_4ph_phase			: std_logic_vector(3 downto 0) := "0100";

	type 	 	state_cyc_t 		is (idle, wait_wr);

	type 		state_i2c_t 		is (idle, shift);

	signal	r_state_cyc			: state_cyc_t;	
	signal	r_con_ack			:	std_logic;

	signal	r_dat_wr				: 	std_logic_vector(7 downto 0);		-- write data latch
	signal	r_shift				:	std_logic_vector(7 downto 0);		
	signal	r_shift_occup		:	std_logic_vector(6 downto 0);		

	signal	r_ctl_busy			:	std_logic;								-- busy written to status register

	signal	r_state_spi			:  state_i2c_t;
	signal	r_spi_mosi			: 	std_logic;

	-- signals from fishbone to shift process
	signal   r_start_req			:  std_logic;								-- slip state to start
	signal   r_start_ack			:  std_logic;								-- acknowledge req started

begin


	fb_p2c_o.rdy <= r_con_ack and fb_c2p_i.cyc;
	fb_p2c_o.ack <= r_con_ack and fb_c2p_i.cyc;
	fb_p2c_o.stall <= '0' when r_state_cyc = idle else '1';

	SPI_MOSI_o <= r_spi_mosi;

	SPI_CLK_o  <= not(r_4ph_phase(3) or r_4ph_phase(2));
						

	-- make a 4 phase clock at 4 * the spi bus speed
	p_stat_clock_div:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_4ph_ctr <= (others => '0');
			r_4ph_clken <= '0';
			r_4ph_phase <= "0001";
		elsif rising_edge(fb_syscon_i.clk) then
			r_4ph_clken <= '0';
			if r_4ph_ctr = C_FAST_CLKDIV4 - 1 then			
				r_4ph_clken <= '1';
				r_4ph_ctr <= (others => '0');
				if r_state_spi = idle then
					r_4ph_phase <= "0001";
				else
					r_4ph_phase <= r_4ph_phase(2 downto 0) & r_4ph_phase(3);
				end if;
			else
				r_4ph_ctr <= r_4ph_ctr + 1;
			end if;
		end if;
	end process;

	-- spi state machine
	p_state_spi:process(fb_syscon_i, r_4ph_clken)
	begin
		if fb_syscon_i.rst = '1' then
			r_state_spi <= idle;
			r_start_ack <= '0';
			r_spi_mosi <= '1';			
		elsif rising_edge(fb_syscon_i.clk) and r_4ph_clken = '1' then
	
			case r_state_spi is 
				when idle => 
					if r_start_req /= r_start_ack then
						r_state_spi <= shift;
						r_shift_occup <= (others => '1');
						r_start_ack <= r_start_req;
						r_shift <= r_dat_wr;
					end if;
				when shift =>
					if r_4ph_phase(0) = '1' then
						r_spi_mosi <= r_shift(r_shift'high);
						r_shift_occup <= r_shift_occup(r_shift_occup'high-1 downto 0) & "0";
					elsif r_4ph_phase(3) = '1' then
						r_shift <= r_shift(r_shift'high-1 downto 0) & SPI_MISO_i; 
						if r_shift_occup(r_shift_occup'high) = '0' then
							r_state_spi <= idle;
						end if;
					end if;
				when others =>
					r_state_spi <= idle;
			end case;
		end if;
	end process;


	-- fishbone register access
	p_state_cyc:process(fb_syscon_i)
	variable v_dowrite: boolean;
	begin

		if fb_syscon_i.rst = '1' then
			r_state_cyc <= idle;
			r_con_ack <= '0';
			r_dat_wr <= (others => '0');
			r_start_req <= '0';
		else
			if rising_edge(fb_syscon_i.clk) then
				v_dowrite := false;

				r_con_ack <= '0';

				case r_state_cyc is
					when idle =>
						if (fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1') then
							if fb_c2p_i.we = '1' then
								if fb_c2p_i.D_wr_stb = '1' then
									v_dowrite := true;
								else
									r_state_cyc <= wait_wr;
								end if;
							else
								fb_p2c_o.D_rd <= r_shift;
								r_state_cyc <= idle;
								r_con_ack <= '1';
							end if;
						end if;
					when wait_wr =>
						if fb_c2p_i.D_wr_stb = '1' then
							v_dowrite := true;
						end if;
					when others =>
						r_state_cyc <= idle;
				end case;

				if fb_c2p_i.cyc = '0' then
					r_con_ack <= '0';
					r_state_cyc <= idle;
				elsif v_dowrite then
					if (fb_c2p_i.A(0) = '0') then
						r_dat_wr <= fb_c2p_i.D_wr;
						r_start_req <= not(r_start_ack);
					end if;
					r_state_cyc <= idle;
					r_con_ack <= '1';
				end if;
			end if;
		end if;

	end process;



end rtl;
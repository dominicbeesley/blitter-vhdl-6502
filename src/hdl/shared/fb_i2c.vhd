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
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	fishbone bus - i2c 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for i2c bus
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------


--
-- The i2c component has the following registers
--	
--	Address	|	Direction	|	Description
-- ---------+--------------+-------------------------------------------------------------------------
--	STAT=0	|	Read			|	Status register:
--				|					|	Bit 7 : BUSY 	flag, when set a shift is in operation
--				|					|	Bit 6 : ACK  	0 if previous operation was ack'd either by controller or peripheral
--				|					|	
--	CTL=0		|  Write			|	Bit 7 : BUSY 	1 start a new operation when the current one completes
--				|					|						if 0 cancel a stop condition
--				|					|						will be generated as soon as the clock is released by 
--				|					|						the peripheral, any pending operation will be terminated
--				|					|	Bit 6 : ACK  	if 0 and operation is a read acknowledge it afterwards
--				|					|	Bit 2	: STOP	send a stop condition after this operation
--				|					|	Bit 1	: START	send a start condition before this operation
--				|					|	Bit 0 : RnW		if 1 read a byte, if 0 write
-- ---------+--------------+-------------------------------------------------------------------------
--	DAT=1		|	Read			|	Read received data
--				|	Write			|	Write data latch 

-- probe address exists:
--	DAT = <addr><<1 & "1"
-- STAT = "10000110"				; BUSY+START+STOP+WRITE
-- WHILE STAT(BUSY) = "0":WEND
-- RETURN (STAT(ACK) = "0")
--
-- write 1,2,3 to addres 0x23
--	DAT = x"46"
-- CTL = "10000010"
-- WHILE STAT(BUSY) = "0":WEND
-- IF STAT(ACK) = "1" RETURN
--	DAT = x"01"
-- STAT = "10000000"
-- WHILE STAT(BUSY) = "0":WEND
-- IF STAT(ACK) = "1" RETURN
--	DAT = x"01"
-- STAT = "10000000"
-- WHILE STAT(BUSY) = "0":WEND
-- IF STAT(ACK) = "1" RETURN
--	DAT = x"03"
-- STAT = "10000100"
-- WHILE STAT(BUSY) = "0":WEND




library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.fishbone.all;
use work.common.all;


entity fb_i2c is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural := 128;								-- fast clock speed in mhz				
		BUS_SPEED							: natural := 400000							-- i2c bus speed in Hz
	);
	port(

		-- eeprom signals
		I2C_SCL_io							: inout	std_logic;
		I2C_SDA_io							: inout	std_logic;

		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t

	);
end fb_i2c;

architecture rtl of fb_i2c is

	constant C_FAST_CLKDIV4		: natural := natural(ceil(real(CLOCKSPEED*1000000)/real(BUS_SPEED*4))); -- divider for 4 phase clock
	signal	r_4ph_ctr			: unsigned(numbits(C_FAST_CLKDIV4)-1 downto 0) := (others => '0');
	signal	r_4ph_clken			: std_logic;
	signal	r_4ph_phase			: std_logic_vector(3 downto 0) := "0100";
	signal	r_4ph_run			: std_logic;

	type 	 	state_cyc_t 		is (idle, wait_cyc);

	type 		state_i2c_t 		is (idle, start, shift, reg, stop);

	signal	r_state_cyc			: state_cyc_t;	

	signal	r_con_ack			:	std_logic;
	signal	r_con_rdy			:	std_logic;

	signal	r_dat_wr				: 	std_logic_vector(7 downto 0);		-- write data latch
	signal	r_ctl_busy			:	std_logic;								-- busy written to status register
	signal	r_ctl_ack			:	std_logic;								-- ack flag written to status register	sent after reads
	signal	r_ctl_stop			:  std_logic;
	signal	r_ctl_start			:  std_logic;
	signal	r_ctl_rnw			:  std_logic;
	signal	r_ctl_written		: 	std_logic;

	signal	r_state_i2c			:  state_i2c_t;

	signal	r_shift				:	std_logic_vector(8 downto 0);		-- (0) is ack
	signal	r_shift_occup		:	std_logic_vector(8 downto 0);		

	signal	r_ctl_written_ack	:  std_logic;
	signal	r_dat_rd				: 	std_logic_vector(7 downto 0);		-- write data latch
	signal	r_stat_ack			:  std_logic;								-- ack flag from last operation used for writes

	signal	r_i2c_sda			: 	std_logic;

begin


	fb_p2c_o.rdy_ctdn <= 
		RDY_CTDN_MIN when r_con_rdy = '1' else
		RDY_CTDN_MAX;
	fb_p2c_o.ack <= r_con_ack;
	fb_p2c_o.nul <= '0';

	I2C_SDA_io <= 	'0' when r_i2c_sda = '0' else
						'Z';
	I2C_SCL_io <= 	'0' when r_4ph_phase(1 downto 0) = "00" else
						'Z';

	-- make a 4 phase clock at 4 * the i2c bus speed
	p_stat_clock_div:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_4ph_ctr <= (others => '0');
			r_4ph_clken <= '0';
			r_4ph_phase <= "0100";
		elsif rising_edge(fb_syscon_i.clk) then
			r_4ph_clken <= '0';
			if r_4ph_ctr = C_FAST_CLKDIV4 - 1 then
				r_4ph_clken <= '1';
				r_4ph_ctr <= (others => '0');
				if not (r_4ph_phase(0) = '1' and to_bit(I2C_SCL_io) /= '1') -- clock stretch
					and r_4ph_run = '1'
						then 
					r_4ph_phase <= r_4ph_phase(2 downto 0) & r_4ph_phase(3);
				end if;
			else
				r_4ph_ctr <= r_4ph_ctr + 1;
			end if;
		end if;
	end process;

	-- i2c state machine
	p_state_i2c:process(fb_syscon_i)
	begin

		if fb_syscon_i.rst = '1' then
			r_state_i2c <= idle;
			r_ctl_written_ack <= '0';
			r_dat_rd <= (others => '0');
			r_stat_ack <= '0';
			r_shift <= (others => '0');
			r_shift_occup <= (others => '0');
			r_i2c_sda <= '1';
			r_4ph_run <= '0';
		elsif rising_edge(fb_syscon_i.clk) and r_4ph_clken = '1' then

			-- check for register write (and synchronise)
			if r_ctl_written /= r_ctl_written_ack then
				-- register was written set state machine start
				-- always set shift register (even if not used)
				r_shift_occup <= (others => '1');
				if r_ctl_rnw = '1' then
					r_shift(8 downto 1) <= (others => '1');
				else
					r_shift(8 downto 1) <= r_dat_wr;
				end if;
				r_shift(0) <= r_ctl_ack or not r_ctl_rnw;		-- set ack in shift register to 1 for writes (to read ack from peripheral)
				r_4ph_run <= '1';
				if r_ctl_busy = '0' then
					-- go straight to do a stop bit
					r_i2c_sda <= '0';
					r_state_i2c <= stop;
				else
					if r_ctl_start then
						r_state_i2c <= start;
						r_i2c_sda <= '1';
					else
						r_state_i2c <= shift;
					end if;
				end if;
				r_ctl_written_ack <= r_ctl_written;
			else
				
				case r_state_i2c is 
					when idle => 
						r_state_i2c <= idle;
					when start =>
						if r_4ph_phase(1) = '1' and to_bit(I2C_SDA_io) = '1' then
							r_i2c_sda <= '0';
							r_state_i2c <= shift;
						end if;
					when shift =>
						if r_4ph_phase(3) = '1' then
							r_i2c_sda <= r_shift(r_shift'high);
							r_shift_occup <= r_shift_occup(r_shift_occup'high-1 downto 0) & "0";
						elsif r_4ph_phase(1) = '1' then
								r_shift <= r_shift(r_shift'high-1 downto 0) & I2C_SDA_io; 
							if r_shift_occup(r_shift_occup'high) = '0' then
								r_state_i2c <= reg;
							end if;
						end if;
					when reg =>
						r_dat_rd <= r_shift(8 downto 1);
						r_stat_ack <= r_shift(0);

						if r_ctl_stop = '1' then
							r_i2c_sda <= '0';
							r_state_i2c <= stop;
						else
							r_4ph_run <= '0';
							r_state_i2c <= idle;
						end if;

					when stop =>
						if r_4ph_phase(1) = '1' and to_bit(I2C_SDA_io) = '0' then
							r_i2c_sda <= '1';
							r_state_i2c <= idle;
							r_4ph_run <= '0';
						end if;

					when others =>
						r_state_i2c <= idle;
				end case;



			end if;
		end if;
	end process;


	-- fishbone register access
	p_state_cyc:process(fb_syscon_i)
	begin

		if fb_syscon_i.rst = '1' then
			r_state_cyc <= idle;
			r_con_ack <= '0';
			r_con_rdy <= '0';
			r_ctl_written <= '0';
			r_dat_wr <= (others => '0');
			r_ctl_busy <= '0';
			r_ctl_ack <= '0';
			r_ctl_stop <= '0';
			r_ctl_start <= '0';
			r_ctl_rnw <= '0';
			r_ctl_written <= '0';
		else
			if rising_edge(fb_syscon_i.clk) then
				r_con_ack <= '0';

				case r_state_cyc is
					when idle =>
						r_con_rdy <= '0';
						if (fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1') then
							if fb_c2p_i.we = '1' and fb_c2p_i.D_wr_stb = '1' then
								if (fb_c2p_i.A(0) = '0') then
									r_ctl_busy <= fb_c2p_i.D_wr(7);
									r_ctl_ack <= fb_c2p_i.D_wr(6);
									r_ctl_stop <= fb_c2p_i.D_wr(2);
									r_ctl_start <= fb_c2p_i.D_wr(1);
									r_ctl_rnw <= fb_c2p_i.D_wr(0);

									r_ctl_written <= not r_ctl_written_ack;
								else
									r_dat_wr <= fb_c2p_i.D_wr;
								end if;
								r_state_cyc <= wait_cyc;
								r_con_rdy <= '1';
								r_con_ack <= '1';
							elsif fb_c2p_i.we = '0' then
								if (fb_c2p_i.A(0) = '0') then
									if r_state_i2c = idle and r_ctl_written = r_ctl_written_ack then
										fb_p2c_o.D_rd(7) <= '0';
									else
										fb_p2c_o.D_rd(7) <= '1';
									end if;
									fb_p2c_o.D_rd(6) <= r_stat_ack;
									fb_p2c_o.D_rd(5 downto 0) <= (others => '0');
								else
									fb_p2c_o.D_rd <= r_dat_rd;
								end if;
								r_state_cyc <= wait_cyc;
								r_con_rdy <= '1';
								r_con_ack <= '1';
							end if;
						end if;
					when wait_cyc =>
						if fb_c2p_i.cyc = '0' or fb_c2p_i.a_stb = '0' then
							r_state_cyc <= idle;
						end if;
					when others =>
						r_state_cyc <= idle;
				end case;
			end if;
		end if;

	end process;


end rtl;
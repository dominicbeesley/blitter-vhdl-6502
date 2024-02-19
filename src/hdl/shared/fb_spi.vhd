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

--	
--	Address	|	Direction	|	Description
-- ---------+--------------+-------------------------------------------------------------------------
--	STAT=0	|	Read			|	Status register:
--				|					|	Bit 7 : BUSY 	flag, when set a shift is in operation the shift register
--				|					|	               contents should not be read whilst this flag is set but
--          |              |                 you may start one more write operation which will be 
--          |              |                 latched and carried out after the current one.
--	CTL=0		|  Write			|	 5..7 : 			reserved write as 0's
--				|					|	 2..4 : CS     The chip select index (this chip select will be activated)
--				|					|	    1 : CPOL   The SPI clock polarity
--				|					|	    0 : CPHA   The SPI clock / data phase
-- ---------+--------------+-------------------------------------------------------------------------
-- DIV=1    |  Write       |  Clock divider - 1 default = 0 i.e. 256
-- ---------+--------------+-------------------------------------------------------------------------
--	SHIFT=2 	|	Read			|	Read current shift register value, do not start another shift
--	WRITE=2	|	Write			|	Write data latch, start a shift and reset CS after the shift 
--	READ_O=3 |	Read			|	Read current shift register value, and shift out data in data latch, 
--          |              |  leave CS active after the shift is completed
--	WRITEO=3	|	Write			|	Write data latch, start a shift, leave CS active after the shift is 
--          |              |  complete


-- The CTL register is set to 0 at reset
-- All writes to CTL will abandon any active shift and reset all CS registers

-- Clock Dividers
-- The main system clock is pre-scaled by the pre-scaler set in the generic parameter then the clock is divided by


-- final freq = CLOCK / (2 * PS * DIV)

-- with PS = 4
--      DIV = 256 (default) = 62.5kHz
--            40            = 400 kHz
--             2            = 8   MHz
--             1            = 16  MHz


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
		PRESCALE								: positive := 4								-- prescaler to apply before clock divider
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

	type 	 	state_cyc_t 		is (idle, wait_wr);
	type 		state_spi_t 		is (idle, shift, latch, fin);

	-- clock generation
	signal	r_2ph_ctr			: unsigned(7 downto 0) := (others => '0');
	signal	r_2ph_clken			: std_logic;
	signal	r_PS_clken			: std_logic;

	-- shift register state machine
	signal	r_state_spi			:  state_spi_t;
	signal	r_spi_mosi			: 	std_logic;
	signal	r_spi_cs				: 	std_logic_vector(7 downto 0);
	signal   r_spi_clk			:  std_logic;
	signal   r_act_cshold		:  std_logic;
	signal	r_shift_occup		:	std_logic_vector(14 downto 0);		


	-- data
	signal	r_dat_wr				: 	std_logic_vector(7 downto 0);		-- write data latch
	signal	r_shift				:	std_logic_vector(7 downto 0);		

	-- control

	signal	r_ctl_cpol			: std_logic;				-- spi clock polarity
	signal	r_ctl_cpha			: std_logic;				-- spi phase
	signal   r_ctl_csix			: unsigned(2 downto 0);	-- current CS index	

	signal   r_ctl_div			: std_logic_vector(7 downto 0) := (others => '0');


	-- status

	signal 	i_stat_busy 		: std_logic;

	-- fishbone state machine
	signal	r_state_cyc			: state_cyc_t;	
	signal	r_con_ack			:	std_logic;


	-- signals from fishbone to shift process
	signal   r_req_req			: std_logic;								-- slip state to start
	signal   r_req_ack			: std_logic;								-- acknowledge req started
	signal   r_req_cshold		: std_logic;
	signal   r_req_reset			: std_logic;								-- reset state machine immediately


begin

	i_stat_busy <= '1' when r_state_spi /= idle or r_req_req /= r_req_ack else '0';


	fb_p2c_o.rdy <= r_con_ack and fb_c2p_i.cyc;
	fb_p2c_o.ack <= r_con_ack and fb_c2p_i.cyc;
	fb_p2c_o.stall <= '0' when r_state_cyc = idle else '1';

	SPI_MOSI_o	<= r_spi_mosi;
	SPI_CLK_o  	<= r_spi_clk xor r_ctl_cpol;
	SPI_CS_o		<= r_spi_CS;					

	G_NOPS:IF PRESCALE = 1 GENERATE
		r_PS_clken <= '1';
	END GENERATE;

	G_PS:IF PRESCALE > 1 GENERATE
		p_PS:process(fb_syscon_i)
		variable v_ps:unsigned(numbits(PRESCALE-1)-1 downto 0) := to_unsigned(PRESCALE-1, numbits(PRESCALE)); 
		begin
			if rising_edge(fb_syscon_i.clk) then
				if v_ps = 0 then
					v_ps := to_unsigned(PRESCALE-1, v_ps'length);
					r_PS_clken <= '1';
				else
					v_ps := v_ps - 1;
					r_PS_clken <= '0';
				end if;
			end if;

		end process;
	END GENERATE;

	-- make a 4 phase clock at 4 * the spi bus speed
	p_stat_clock_div:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_2ph_ctr <= (others => '0');
			r_2ph_clken <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			r_2ph_clken <= '0';
			if r_PS_clken = '1' then
				if r_2ph_ctr = 0 then			
					r_2ph_clken <= '1';
					r_2ph_ctr <= unsigned(r_ctl_div) - 1;
				else
					r_2ph_ctr <= r_2ph_ctr - 1;
				end if;
			end if;
		end if;
	end process;

	-- spi state machine
	p_state_spi:process(fb_syscon_i, r_2ph_clken)
	begin
		if fb_syscon_i.rst = '1' then
			r_state_spi <= idle;
			r_req_ack <= '0';
			r_spi_mosi <= '1';			
			r_spi_CS <= (others => '1');
			r_spi_clk <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if r_2ph_clken = '1' then

				r_shift_occup <= '0' & r_shift_occup(r_shift_occup'high downto 1);
		
				case r_state_spi is 
					when idle => 
						r_spi_clk <= '0';
						if r_req_req /= r_req_ack then
							r_state_spi <= shift;
							r_shift_occup <= (others => '1');
							r_req_ack <= r_req_req;
							r_shift <= r_dat_wr;
							r_spi_CS(to_integer(r_ctl_csix)) <= '0';
							r_act_cshold <= r_req_cshold;
							if r_ctl_cpha = '1' then
								r_state_spi <= shift;
							else
								r_spi_mosi <= r_dat_wr(r_dat_wr'high);
								r_state_spi <= latch;
							end if;
						end if;
					when shift =>
						r_state_spi <= latch;
						if r_shift_occup(0) = '0' then
							r_state_spi <= fin;
						else
							r_spi_mosi <= r_shift(r_shift'high);						
						end if;
						r_spi_clk <= not r_spi_clk;
					when latch =>
						r_shift <= r_shift(6 downto 0) & SPI_MISO_i;
						r_state_spi <= shift;
						if r_shift_occup(0) = '0' then
							r_state_spi <= fin;
						end if;
						r_spi_clk <= not r_spi_clk;
					when fin =>
						r_state_spi <= idle;
						if r_act_cshold = '0' then
							r_spi_CS <= (others => '1');
						end if;
					when others =>
						r_spi_CS <= (others => '1');
						r_state_spi <= idle;
						r_spi_clk <= '0';
				end case;
			end if;

			if r_req_reset = '1' then				
				r_spi_CS <= (others => '1');
				r_state_spi <= idle;
				r_spi_clk <= '0';
			end if;
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
			r_req_req <= '0';
			r_ctl_cpol <= '0';
			r_ctl_cpha <= '0';
			r_ctl_div <= (others => '0');
		else
			if rising_edge(fb_syscon_i.clk) then
				v_dowrite := false;

				r_con_ack <= '0';
				r_req_reset <= '0';

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
								if fb_c2p_i.A(1 downto 0) = "00" then
									fb_p2c_o.D_rd <= (7 => i_stat_busy, 1 => r_ctl_cpol, 0 => r_ctl_cpha, others => '0');
								elsif fb_c2p_i.A(1 downto 0) = "01" then
									fb_p2c_o.D_rd <= r_ctl_div;
								else
									fb_p2c_o.D_rd <= r_shift;
									if fb_c2p_i.A(0) = '1' then
										r_req_req <= not(r_req_ack);
										r_req_cshold <= '1';
									end if;
								end if;
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
					if fb_c2p_i.A(1 downto 0) = "00" then
						-- control register write
						r_req_reset <= '1';				-- reset spi state machine and nCS
						r_ctl_csix <= unsigned(fb_c2p_i.D_wr(4 downto 2));
						r_ctl_cpol <= fb_c2p_i.D_wr(1);
						r_ctl_cpha <= fb_c2p_i.D_wr(0);
					elsif fb_c2p_i.A(1 downto 0) = "01" then
						-- clock divider register write
						r_req_reset <= '1';				-- reset spi state machine and nCS
						r_ctl_div <= fb_c2p_i.D_wr;
					else
						r_dat_wr <= fb_c2p_i.D_wr;
						r_req_req <= not(r_req_ack);
						r_req_cshold <= fb_c2p_i.A(0);
					end if;
					r_state_cyc <= idle;
					r_con_ack <= '1';
				end if;
			end if;
		end if;

	end process;



end rtl;
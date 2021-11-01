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
----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	29/4/2019
-- Design Name: 
-- Module Name:    	sound channel
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Fishbone version of the sound channel, this new version
--							does all work in the main fishbone clock domain which
--							should be faster than the sound sample clock domain which
--							is fed to this domain via a flancter
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.02 - Add peak 
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.fishbone.all;

entity fb_DMAC_int_sound_cha is
	 generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up	
	 );
    Port (

		-- fishbone signals		
		fb_syscon_i							: in		fb_syscon_t;

		-- slave interface (control registers)
		fb_sla_m2s_i						: in		fb_mas_o_sla_i_t;
		fb_sla_s2m_o						: out		fb_mas_i_sla_o_t;

		-- master interface (dma)
		data_req_o							: out		std_logic;
		data_ack_i							: in		std_logic;
		data_addr_o							: out		unsigned(23 downto 0);
		data_addr_offs_o					: out		unsigned(15 downto 0);
		data_data_i							: in		signed(7 downto 0);

		-- sound specific
		snd_dat_o							: out		signed(7 downto 0);
		snd_dat_change_clken				: out		std_logic;
		snd_clken_sndclk_i				: in 		std_logic					-- clken in fishbone clock domain for sound clock 3.5ish MHz

	 );

	 -- sound
	 constant	A_DATA			: integer := 0;
	 constant	A_ADDR			: integer := 1;
	 constant	A_PERIOD			: integer := 4;
	 constant	A_LEN				: integer := 6;
	 constant	A_STATUS			: integer := 8;
	 constant	A_VOL				: integer := 9;
	 constant	A_REPOFF			: integer := 10;
	 constant	A_PEAK			: integer := 12;
end fb_DMAC_int_sound_cha;

architecture Behavioral of fb_DMAC_int_sound_cha is

	signal r_data						: signed(7 downto 0);								-- sample playing
	signal r_data_next				: signed(7 downto 0);								-- sample retrieved by dma
	signal r_addr						: unsigned(23 downto 0);
	signal r_period_h_latch			: std_logic_vector(7 downto 0);					-- latched high period, not written until low byte
	signal r_period					: unsigned(15 downto 0);							-- this is the amiga sample period
	signal r_len						: unsigned(15 downto 0);							-- sample length - 1
	signal r_act_prev_sndclk		: std_logic;											-- flag to see if act has changed since last snd clock
	signal r_act						: std_logic;
	signal r_repeat					: std_logic;
	signal r_vol						: unsigned(5 downto 0);								-- volume for this channel
	signal r_repoff					: unsigned(15 downto 0);
	signal r_peak						: unsigned(6 downto 0);
	signal r_snd_dat_change_clken	: std_logic;											-- signals change in sound data

	signal r_samper_ctr				: unsigned(15 downto 0);							-- counts down to next sample from period
	signal i_samper_ctr_next		: unsigned(16 downto 0);							-- 1 less than current r_samper_ctr plus 1bit for carry in msb
	signal r_sam_ctr					: unsigned(15 downto 0);							-- counts up to length of samples
	signal i_next_sam_ctr			: unsigned(15 downto 0);							-- next value for sample counter
	signal i_next_act					: std_logic;											-- next value for enable, set to 0 when sample finished

	-- slave state machine
	type		sla_state_t		is (idle, data, wait_cyc);
	signal	r_sla_state				: sla_state_t;
	signal	r_sla_addr				: std_logic_vector(3 downto 0);
	signal 	i_sla_D_rd				: std_logic_vector(7 downto 0);
	signal	r_sla_rdy				: std_logic;
	signal	r_sla_ack				: std_logic;

	signal	r_snd_dat				: signed(7 downto 0);
	signal   r_snd_dat_mag			: unsigned(6 downto 0);
	signal	r_snd_peak_clken		: std_logic;

	signal	r_mas_data_req			: std_logic;

	begin

	data_req_o <= r_mas_data_req;
	data_addr_o <= r_addr;
	data_addr_offs_o <= r_sam_ctr;
							
	p_sam_ctr_next: process(r_sam_ctr, r_repeat, r_len, r_repoff)
	begin
		i_next_act <= '1';
		if (r_sam_ctr = r_len) then
			if (r_repeat = '1') then
				i_next_sam_ctr <= r_repoff;
			else
				i_next_act <= '0';
				i_next_sam_ctr <= (others => '0');
			end if;
		else
			i_next_sam_ctr <= r_sam_ctr + 1;
		end if;
	end process;

	p_sla_state:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_sla_state <= idle;
			r_sla_rdy <= '0';
			r_sla_ack <= '0';
			r_sla_addr <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
			r_sla_ack <= '0';

			case r_sla_state is
				when idle =>
					if fb_sla_m2s_i.cyc = '1' and fb_sla_m2s_i.a_stb = '1' then
						r_sla_addr <= fb_sla_m2s_i.A(3 downto 0);
						r_sla_state <= data;
					end if;
				when data =>
					fb_sla_s2m_o.D_rd <= i_sla_D_rd;
					if fb_sla_m2s_i.we = '0' or fb_sla_m2s_i.D_wr_stb = '1' then
						r_sla_state <= wait_cyc;
						r_sla_rdy <= '1';
						r_sla_ack <= '1';
					end if;
				when wait_cyc =>
					if fb_sla_m2s_i.cyc = '0' or fb_sla_m2s_i.a_stb = '0' then
						r_sla_state <= idle;
						r_sla_rdy <= '0';
					end if;
				when others => null;
			end case;
		end if;
	end process;

	fb_sla_s2m_o.rdy_ctdn <= RDY_CTDN_MIN when r_sla_rdy = '1' else
									 RDY_CTDN_MAX;
	fb_sla_s2m_o.ack <= r_sla_ack;
	fb_sla_s2m_o.nul <= '0';

	i_samper_ctr_next <= ("0" & r_samper_ctr) - 1;

	p_regs_wr : process(fb_syscon_i)
	variable v_sam_next:boolean;
	begin

		if fb_syscon_i.rst = '1' then
			r_data <= (others => '0');
			r_addr <= (others => '0');
			r_act <= '0';
			r_act_prev_sndclk <= '0';
			r_repeat <= '0';
			r_repoff <= (others => '0');
			r_len <= (others => '0');
			r_period <= (others => '0');
			r_sam_ctr <= (others => '0');	
			r_vol <= (others => '1');			-- default full vol	 
			r_peak <= (others => '0');
			r_snd_dat_change_clken <= '1';
			r_samper_ctr <= (others => '0');
			r_mas_data_req <= '0';
		elsif rising_edge(fb_syscon_i.clk) then

			r_snd_dat_change_clken <= '0';

			v_sam_next := false;

			if snd_clken_sndclk_i = '1' then												-- for each sound clock edge
				if r_act = '0' then															-- act = 0 don't do anything
					r_samper_ctr <= (others => '0');
					r_mas_data_req <= '0';
				else
					if r_act_prev_sndclk = '0' then										-- just gone active, trigger read but
						r_mas_data_req <= '1';												-- no sample ready yet

						r_samper_ctr <= r_period;
					elsif i_samper_ctr_next(i_samper_ctr_next'high) = '1' then	-- if counter going to roll over or act just gone active
						r_mas_data_req <= '1';												-- flag a sample transition to other processes
						r_samper_ctr <= r_period;											-- reset period counter
				r_data <= r_data_next;
				r_snd_dat_change_clken <= '1';
					else
						r_samper_ctr <= i_samper_ctr_next(15 downto 0);				-- decrement period counter
					end if;
				end if;
				r_act_prev_sndclk <= r_act;
			end if;


			-- update data when read from master interface
			if data_ack_i = '1' then
				r_data_next <= signed(data_data_i);
				r_mas_data_req <= '0';
				r_act <= i_next_act;
				r_sam_ctr <= i_next_sam_ctr;
			end if;

			if r_snd_peak_clken = '1' then
				r_peak <= r_snd_dat_mag;
			end if;


			if fb_sla_m2s_i.cyc = '1' 
				and fb_sla_m2s_i.A_stb = '1' 
				and fb_sla_m2s_i.D_wr_stb = '1' 
				and fb_sla_m2s_i.we = '1' 
				and r_sla_ack = '1' 
				then

				case to_integer(unsigned(r_sla_addr)) is
					when A_DATA =>
						r_data <= SIGNED(fb_sla_m2s_i.D_wr);
						r_snd_dat_change_clken <= '1';
					when A_ADDR =>
						r_addr(23 downto 16) <= unsigned(fb_sla_m2s_i.D_wr);
					when A_ADDR + 1 =>
						r_addr(15 downto 8) <= unsigned(fb_sla_m2s_i.D_wr);
					when A_ADDR + 2 =>
						r_addr(7 downto 0) <= unsigned(fb_sla_m2s_i.D_wr);
					when A_PERIOD =>
						r_period_h_latch <= fb_sla_m2s_i.D_wr;
					when A_PERIOD + 1 =>
						r_period <= UNSIGNED(r_period_h_latch & fb_sla_m2s_i.D_wr);
					when A_LEN =>
						r_len(15 downto 8) <= UNSIGNED(fb_sla_m2s_i.D_wr);
					when A_LEN + 1 =>
						r_len(7 downto 0) <= UNSIGNED(fb_sla_m2s_i.D_wr);
					when A_REPOFF =>
						r_repoff(15 downto 8) <= UNSIGNED(fb_sla_m2s_i.D_wr);
					when A_REPOFF + 1 =>
						r_repoff(7 downto 0) <= UNSIGNED(fb_sla_m2s_i.D_wr);
					when A_STATUS =>
						r_repeat <= fb_sla_m2s_i.D_wr(0);
						r_act <= fb_sla_m2s_i.D_wr(7);
						r_sam_ctr <= (others => '0');
					when A_VOL =>
						r_vol <= UNSIGNED(fb_sla_m2s_i.D_wr(7 downto 2));
					when A_PEAK =>
						r_peak <= (others => '0');
					when others => null;
				end case;
			end if;
		end if;
	end process;

	p_regs_rd: process(r_sla_addr, 
		r_data,
		r_addr,
		r_len,
		r_period,
		r_act,
		r_repeat,
		r_repoff,
		r_peak,
		r_vol		
		)
	begin
		case to_integer(unsigned(r_sla_addr)) is
			when A_DATA =>
				i_sla_D_rd <= std_logic_vector(r_data);
			when A_ADDR =>
				i_sla_D_rd <= std_logic_vector(r_addr(23 downto 16));
			when A_ADDR + 1 =>
				i_sla_D_rd <= std_logic_vector(r_addr(15 downto 8));
			when A_ADDR + 2 =>
				i_sla_D_rd <= std_logic_vector(r_addr(7 downto 0));
			when A_PERIOD => 
				i_sla_D_rd <= std_logic_vector(r_period(15 downto 8));
			when A_PERIOD + 1=> 
				i_sla_D_rd <= std_logic_vector(r_period(7 downto 0));
			when A_LEN => 
				i_sla_D_rd <= std_logic_vector(r_len(15 downto 8));
			when A_LEN + 1=> 
				i_sla_D_rd <= std_logic_vector(r_len(7 downto 0));
			when A_REPOFF => 
				i_sla_D_rd <= std_logic_vector(r_repoff(15 downto 8));
			when A_REPOFF + 1=> 
				i_sla_D_rd <= std_logic_vector(r_repoff(7 downto 0));
			when A_STATUS => 
				i_sla_D_rd <= r_act & "000000" & r_repeat;
			when A_VOL => 
				i_sla_D_rd <= std_logic_vector(r_vol) & "00";
			when A_PEAK =>
				i_sla_D_rd <= "0" & std_logic_vector(r_peak);
			when others =>
				i_sla_D_rd <= (others => '1');
		end case;
	end process;
	
	p_vol:process(fb_syscon_i)
	variable v_res:signed(r_data'length+r_vol'length downto 0);
	begin
		if rising_edge(fb_syscon_i.clk) then
			v_res := (r_data * signed("0" & r_vol));
			r_snd_dat <= v_res(v_res'high) & v_res(v_res'high-2 downto v_res'high-8);
			snd_dat_change_clken <= r_snd_dat_change_clken;
		end if;
	end process;

	snd_dat_o <= r_snd_dat;

	p_peak:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_snd_dat_mag <= (others => '0');
			r_snd_peak_clken <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if r_snd_dat_mag > r_peak then
				r_snd_peak_clken <= '1';
			else
				r_snd_peak_clken <= '0';			
			end if;

			if r_snd_dat(r_snd_dat'high) = '1' then
				r_snd_dat_mag <= unsigned(not(r_snd_dat(6 downto 0)));
			else
				r_snd_dat_mag <= unsigned(r_snd_dat(6 downto 0));
			end if;			
		end if;
	end process;

end Behavioral;

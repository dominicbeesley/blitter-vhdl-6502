-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2009 Benjamin Krill <benjamin@krll.de>
-- Copyright (c) 2020 Dominic Beesley <dominic@dossytronics.net>
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
-- Create Date:    	3/7/2019 
-- Design Name: 
-- Module Name:    	dmac - sound channel selector and wrapper
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.02 - sound mixer fed back to channel for peak detector
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_MISC.ALL;


library work;
use work.fishbone.all;
use work.common.all;


entity fb_DMAC_int_sound is
	 generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up	
		G_CHANNELS							: natural := 4
	 );
    Port (

		-- fishbone signals		
		fb_syscon_i							: in		fb_syscon_t;

		-- slave interface (control registers)
		fb_sla_m2s_i						: in		fb_mas_o_sla_i_t;
		fb_sla_s2m_o						: out		fb_mas_i_sla_o_t;

		-- master interface (dma)
		fb_mas_m2s_o						: out		fb_mas_o_sla_i_t;
		fb_mas_s2m_i						: in		fb_mas_i_sla_o_t;

		cpu_halt_o							: out		STD_LOGIC;

		-- sound specific
		snd_clk_i							: in		std_logic;
		snd_dat_o							: out		signed(9 downto 0);
		snd_dat_change_clken_o			: out		std_logic
	 );

	 -- sound
	 constant	A_CHA_SEL		: integer := 15;
	 constant	A_OVR_VOL		: integer := 14;
end fb_DMAC_int_sound;

architecture Behavioral of fb_DMAC_int_sound is

	constant PADBITS						: std_logic_vector(8-CEIL_LOG2(G_CHANNELS-1)-1 downto 0) := (others => '0');

	type		sla_state_t	is (idle, child_act, sel_act, wait_cyc);

	type		snd_dat_arr is array(natural range <>) of signed(7 downto 0);

	type		cha_addr_arr is array(natural range <>) of unsigned(23 downto 0);
	type		cha_addr_offs_arr is array(natural range <>) of unsigned(15 downto 0);

	signal	r_sla_state 				: sla_state_t;
	signal   r_sla_sel_rdy				: std_logic;
	signal   r_sla_sel_ack				: std_logic;

	signal	i_cha_fb_sla_m2s			: fb_mas_o_sla_i_arr(G_CHANNELS-1 downto 0);
	signal	i_cha_fb_sla_s2m			: fb_mas_i_sla_o_arr(G_CHANNELS-1 downto 0);

	signal	r_cha_sel					: unsigned(CEIL_LOG2(G_CHANNELS-1)-1 downto 0);
	signal	r_ovr_vol					: unsigned(5 downto 0);

	signal	i_child_snd_dat			: snd_dat_arr(G_CHANNELS-1 downto 0);
	signal	i_child_snd_dat_clken	: std_logic_vector(G_CHANNELS-1 downto 0);
	signal	r_tot_snd_dat				: signed(9 downto 0);

	signal 	i_snd_clken_sndclk		: std_logic;											-- gets set to 1 on each positive edge of the
																											-- sound clock for one fishbone cycle

	signal	i_snd_clk_tgl				: std_logic;

	signal	r_reg_snd_clk				: std_logic_vector(5 downto 0);

	type		mas_state_t	is (idle, start, startcy, start2, act);
	-- master interface signals from channels
	signal	r_mas_state					: mas_state_t;

	signal	r_mas_addrplusoffs		: unsigned(23 downto 0);
	signal	r_mas_cyc					: std_logic;
	
	signal	i_cha_data_req				: std_logic_vector(G_CHANNELS-1 downto 0);
	signal	i_cha_data_ack 			: std_logic_vector(G_CHANNELS-1 downto 0);
	signal	i_cha_data_addr			: cha_addr_arr(G_CHANNELS-1 downto 0);
	signal	i_cha_data_addr_offs		: cha_addr_offs_arr(G_CHANNELS-1 downto 0);
	signal	i_cha_data_data 			: signed(7 downto 0);
	signal	r_cha_data_cur_ix			: unsigned(numbits(G_CHANNELS)-1 downto 0);
	signal	r_cha_data_cur_oh			: std_logic_vector(G_CHANNELS-1 downto 0);


	signal	i_cur_cha_addr				: unsigned(23 downto 0);
	signal	i_cur_cha_addr_offs		: unsigned(15 downto 0);
begin

	p_snd_tgl:process(snd_clk_i)
	begin

		if rising_edge(snd_clk_i) then
			if i_snd_clk_tgl = '0' then
				i_snd_clk_tgl <= '1';
			else
				i_snd_clk_tgl <= '0';
			end if;
		end if;
	end process;

	p_snd_clk_xdomain:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			r_reg_snd_clk <= r_reg_snd_clk(r_reg_snd_clk'high-1 downto 0) & i_snd_clk_tgl;

			if r_reg_snd_clk(r_reg_snd_clk'high) /= r_reg_snd_clk(r_reg_snd_clk'high-1) then
				i_snd_clken_sndclk <= '1';
			else
				i_snd_clken_sndclk <= '0';
			end if;
		end if;
	end process;

--	snd_clken_sndclk_o <= i_snd_clken_sndclk;
---- generate a 3.5ish Mhz clock en from sound clock in 
--	-- the fbsyscon clock domain
--	e_flanc_snd2fb : entity work.flancter
--	generic map (
--		REGISTER_OUT => TRUE
--	)
--	port map (
--		rst_i_async	=> fb_syscon_i.rst,
--		
--		set_i_ck		=> snd_clk_i,
--		set_i			=> '1',
--		
--		rst_i_ck		=> fb_syscon_i.clk,
--		rst_i			=> '1',
--		
--		flag_out		=> i_snd_clken_sndclk
--	);

	p_snd_add:process(fb_syscon_i)
	variable v_snd_tot : signed(CEIL_LOG2(G_CHANNELS-1)+7 downto 0);
	begin
		if rising_edge(fb_syscon_i.clk) then
			v_snd_tot := (others => '0');
			for I in G_CHANNELS-1 downto 0 loop
				v_snd_tot := v_snd_tot + i_child_snd_dat(I);
			end loop;
			r_tot_snd_dat <= resize(v_snd_tot, 10);

			snd_dat_change_clken_o <= '0';
			for C in G_CHANNELS-1 downto 0 loop
				if i_child_snd_dat_clken(C) = '1' then
					snd_dat_change_clken_o <= '1';
				end if;
			end loop;
		end if;
	end process;

	snd_dat_o <= r_tot_snd_dat;

	p_sla_state:process(fb_syscon_i, fb_sla_m2s_i)
	variable v_rs:natural range 0 to 15;
	begin
		v_rs := to_integer(unsigned(fb_sla_m2s_i.A(3 downto 0)));
		if fb_syscon_i.rst = '1' then
			r_sla_state <= idle;
			r_cha_sel <= (others => '0');
			r_ovr_vol <= (others => '1');
			r_sla_sel_rdy <= '0';
			r_sla_sel_ack <= '0';
		elsif rising_edge(fb_syscon_i.clk) then

			r_sla_sel_ack <= '0';

			case r_sla_state is
				when idle =>
					if fb_sla_m2s_i.cyc = '1' and fb_sla_m2s_i.A_stb = '1' then
						if v_rs = A_CHA_SEL or v_rs = A_OVR_VOL then
							r_sla_state <= sel_act;
							if fb_sla_m2s_i.we = '0' then
								r_sla_sel_rdy <= '1';
								r_sla_sel_ack <= '1';
							end if;
						else
							r_sla_state <= child_act;
						end if;
					end if;
				when sel_act =>
					if fb_sla_m2s_i.we = '1' and fb_sla_m2s_i.D_wr_stb = '1' then
						if v_rs = A_CHA_SEL then
							r_cha_sel <= unsigned(fb_sla_m2s_i.D_wr(CEIL_LOG2(G_CHANNELS-1)-1 downto 0));
						elsif v_rs = A_OVR_VOL then
							r_ovr_vol <= unsigned(fb_sla_m2s_i.D_wr(7 downto 2));
						end if;
						r_sla_sel_rdy <= '1';
						r_sla_sel_ack <= '1';
						r_sla_state <= wait_cyc;
					end if;
				when wait_cyc =>
					-- do nothing just wait for cyc/a_stb to go low
				when others => null;
			end case;

			if fb_sla_m2s_i.cyc = '0' or fb_sla_m2s_i.a_stb = '0' then
				r_sla_state <= idle;
				r_sla_sel_rdy <= '0';
			end if;
		end if;
	end process;

	g_cha: for I in 0 to G_CHANNELS-1 generate

		e_cha_1: entity work.fb_DMAC_int_sound_cha
		generic map (
		SIM									=> SIM
		)
		port map (

		-- fishbone signals		
		fb_syscon_i							=> fb_syscon_i,

		-- slave interface (control registers)
		fb_sla_m2s_i						=> i_cha_fb_sla_m2s(I),
		fb_sla_s2m_o						=> i_cha_fb_sla_s2m(I),

		-- master interface (dma)
		data_req_o							=> i_cha_data_req(I),
		data_ack_i							=> i_cha_data_ack(I),
		data_addr_o							=> i_cha_data_addr(I),
		data_addr_offs_o					=> i_cha_data_addr_offs(I),
		data_data_i							=> i_cha_data_data,

		snd_clken_sndclk_i				=> i_snd_clken_sndclk,
		snd_dat_o							=> i_child_snd_dat(I),
		snd_dat_change_clken				=> i_child_snd_dat_clken(I)

		);

	end generate;

		
	p_sla_cha_sel_o:process(fb_syscon_i, r_sla_sel_ack, r_sla_state, r_ovr_vol, r_cha_sel, i_cha_fb_sla_s2m, 
													fb_sla_m2s_i, r_sla_sel_rdy)	
	variable v_rs:natural range 0 to 15;
	variable v_rdy_ctdn:unsigned(RDY_CTDN_LEN-1 downto 0);
	begin
		v_rs := to_integer(unsigned(fb_sla_m2s_i.A(3 downto 0)));
		if r_sla_sel_rdy = '1' then
			v_rdy_ctdn := RDY_CTDN_MIN;
		else 
			v_rdy_ctdn := RDY_CTDN_MAX;
		end if;
		fb_sla_s2m_o <= fb_s2m_unsel;
		if r_sla_state = child_act then
			for I in 0 to G_CHANNELS-1 loop
				if r_cha_sel = I then
					fb_sla_s2m_o <= i_cha_fb_sla_s2m(I);
				end if;
			end loop;
		elsif r_sla_state = sel_act or r_sla_state = wait_cyc then
			if v_rs = A_OVR_VOL then
				fb_sla_s2m_o <= (
					D_rd => std_logic_vector(r_ovr_vol) & "00",
					rdy_ctdn => v_rdy_ctdn,
					ack => r_sla_sel_ack,
					nul => '0'
					);				
			else
				fb_sla_s2m_o <= (
					D_rd => PADBITS & std_logic_vector(r_cha_sel),
					rdy_ctdn => v_rdy_ctdn,
					ack => r_sla_sel_ack,
					nul => '0'
					);
			end if;
		end if;
	end process;
					
	p_sla_cha_sel_i:process(r_cha_sel, fb_sla_m2s_i)
	begin
		for I in 0 to G_CHANNELS-1 loop
			if r_cha_sel = I then
				-- this assumes that the child channels will
				-- ignore selects to register F!
				i_cha_fb_sla_m2s(I) <= fb_sla_m2s_i;
			else
				i_cha_fb_sla_m2s(I) <= (
						cyc => '0',
						we => '0',
						A => (others => '1'),
						A_stb => '0',
						D_wr => (others => '-'),
						D_wr_stb => '0'
					);
			end if;
		end loop;		
	end process;

					

	i_cha_data_ack <= r_cha_data_cur_oh when r_mas_state = act and fb_mas_s2m_i.ack = '1' else
							(others => '0');

	i_cha_data_data <= signed(fb_mas_s2m_i.D_rd);

	i_cur_cha_addr <= i_cha_data_addr(to_integer(r_cha_data_cur_ix));
	i_cur_cha_addr_offs <= i_cha_data_addr_offs(to_integer(r_cha_data_cur_ix));
	
	fb_mas_m2s_o.cyc <= r_mas_cyc;
	fb_mas_m2s_o.a_stb <= r_mas_cyc;
	fb_mas_m2s_o.A <= std_logic_vector(r_mas_addrplusoffs);
	fb_mas_m2s_o.we <= '0';
	fb_mas_m2s_o.D_wr <= (others => '0');
	fb_mas_m2s_o.D_wr_stb <= '0';

	p_mas_state: process(fb_syscon_i)
	variable v_ix: unsigned(numbits(G_CHANNELS)-1 downto 0);
	variable v_add16 : unsigned(16 downto 0);
	begin
		if fb_syscon_i.rst = '1' then

			r_mas_state <= idle;
			r_mas_cyc <= '0';
			r_mas_addrplusoffs <= (others => '0');
			cpu_halt_o <= '0';
			r_cha_data_cur_ix <= (others => '0');
			r_cha_data_cur_oh <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then

			v_add16 := 
					("0" & i_cur_cha_addr(15 downto 0))
				+ 	("0" & i_cur_cha_addr_offs)
				;

			case r_mas_state is
				when idle => 
					--arbitrate, simple priority
					if or_reduce(i_cha_data_req) = '1' then
						for I in G_CHANNELS-1 downto 0 loop
							if i_cha_data_req(I) = '1' then
								r_cha_data_cur_ix <= to_unsigned(I, r_cha_data_cur_ix'length);
								r_cha_data_cur_oh <= std_logic_vector(to_unsigned(2**I, r_cha_data_cur_oh'length));
							end if;
						end loop;
						r_mas_state <= start;
					end if;
				when start =>
					r_mas_addrplusoffs(15 downto 0) <= v_add16(15 downto 0);
					r_mas_addrplusoffs(23 downto 16) <= i_cur_cha_addr(23 downto 16);
					if v_add16(16) = '1' then
						r_mas_state <= startcy;
					else
						r_mas_cyc <= '1';
						cpu_halt_o <= '1';
					r_mas_state <= act;
					end if;
				when startcy =>
					r_mas_addrplusoffs(23 downto 16) <= r_mas_addrplusoffs(23 downto 16) + 1;
					r_mas_cyc <= '1';
					cpu_halt_o <= '1';
					r_mas_state <= act;						
				when act =>
					if or_reduce(i_cha_data_req and r_cha_data_cur_oh) /= '1' then
						r_mas_state <= idle;
						r_mas_cyc <= '0';
						cpu_halt_o <= '0';
						r_cha_data_cur_oh <= (others => '0');
					end if;
				when others =>
					r_mas_cyc <= '0';
					r_mas_state <= idle;					
			end case;
		end if;
	end process;



end Behavioral;

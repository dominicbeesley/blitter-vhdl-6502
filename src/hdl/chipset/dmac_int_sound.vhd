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


library work;
use work.fishbone.all;
use work.common.all;
use work.fb_intcon_pack.all;

entity fb_DMAC_int_sound is
	 generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up	
		G_CHANNELS							: natural := 4
	 );
    Port (

		-- fishbone signals		
		fb_syscon_i							: in		fb_syscon_t;

		-- peripheral interface (control registers)
		fb_per_c2p_i						: in		fb_con_o_per_i_t;
		fb_per_p2c_o						: out		fb_con_i_per_o_t;

		-- controller interface (dma)
		fb_con_c2p_o						: out		fb_con_o_per_i_t;
		fb_con_p2c_i						: in		fb_con_i_per_o_t;

		-- sound specific
		snd_clk_i							: in		std_logic;
		snd_dat_o							: out		signed(15 downto 0);
		snd_dat_l_o							: out		signed(15 downto 0);
		snd_dat_r_o							: out		signed(15 downto 0)
	 );

	 -- sound
	 constant	A_CHA_SEL		: std_logic_vector(3 downto 0) := x"F";
	 constant	A_OVR_VOL		: std_logic_vector(3 downto 0) := x"E";
end fb_DMAC_int_sound;

architecture Behavioral of fb_DMAC_int_sound is

	-- buffer peripheral port
	signal	i_per_buf_c2p		: fb_con_o_per_i_t;
	signal	i_per_buf_p2c		: fb_con_i_per_o_t;


	type		snd_dat_arr is array(natural range <>) of signed(7 downto 0);

	type		cha_addr_arr is array(natural range <>) of unsigned(23 downto 0);
	type		cha_addr_offs_arr is array(natural range <>) of unsigned(15 downto 0);

	-- local registers state machine
	type		per_state_t	is (idle, act_rd, act_wr);
	signal	r_per_state 				: per_state_t;
   signal   r_D_ack  : std_logic;
   signal   r_A      : std_logic_vector(3 downto 0);
   signal   r_A_ack  : std_logic;
   signal   r_D_rd   : std_logic_vector(7 downto 0);

	-- note one more item in each of these array than channels for the local vol/sel regs
	signal	i_o2m_fb_per_c2p			: fb_con_o_per_i_arr(G_CHANNELS downto 0);
	signal	i_o2m_fb_per_p2c			: fb_con_i_per_o_arr(G_CHANNELS downto 0);

	signal	i_local_c2p					: fb_con_o_per_i_t;
	signal	i_local_p2c					: fb_con_i_per_o_t;

	-- local registers
	signal	r_cha_sel					: unsigned(numbits(G_CHANNELS)-1 downto 0);
	signal   r_cha_sel_oh				: std_logic_vector(G_CHANNELS-1 downto 0);
	signal	r_ovr_vol					: unsigned(5 downto 0);

	-- munged addresses
	signal 	i_per_c2p_bele				: fb_con_o_per_i_t; -- adddresses adjusted for little/big-endian maps

	-- select between channels/local registers
	signal   i_addr_addr					: std_logic_vector(23 downto 0);
	signal   i_addr_dec_ix				: unsigned(numbits(G_CHANNELS+1)-1 downto 0);
	signal   i_addr_dec_oh				: std_logic_vector(G_CHANNELS downto 0);
	constant C_LOCAL_OH : std_logic_vector(G_CHANNELS downto 0) := (G_CHANNELS => '1', others => '0');

	signal	i_child_snd_dat			: snd_dat_arr(G_CHANNELS-1 downto 0);
	signal	i_child_snd_dat_clken	: std_logic_vector(G_CHANNELS-1 downto 0);
	signal	r_tot_snd_dat				: signed(15 downto 0);
	signal	r_tot_snd_dat_l			: signed(15 downto 0);
	signal	r_tot_snd_dat_r			: signed(15 downto 0);

	signal 	i_snd_clken_sndclk		: std_logic;											-- gets set to 1 on each positive edge of the
																											-- sound clock for one fishbone cycle

	signal	i_snd_clk_tgl				: std_logic;

	signal	r_reg_snd_clk				: std_logic_vector(5 downto 0);

	type		con_state_t	is (idle, start, startcy, act);
	-- controller interface signals from channels
	signal	r_con_state					: con_state_t;

	signal	r_con_addrplusoffs		: unsigned(23 downto 0);
	signal	r_con_cyc					: std_logic;
	signal   r_con_a_stb					: std_logic;
	
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

	snd_dat_o <= r_tot_snd_dat;
	snd_dat_l_o <= r_tot_snd_dat_l;
	snd_dat_r_o <= r_tot_snd_dat_r;

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

	p_snd_add:process(fb_syscon_i)
	variable v_snd_tot : signed(CEIL_LOG2(G_CHANNELS-1)+7 downto 0);
	variable v_snd_tot_l : signed(CEIL_LOG2(G_CHANNELS-1)+7 downto 0);
	variable v_snd_tot_r : signed(CEIL_LOG2(G_CHANNELS-1)+7 downto 0);
	begin
		if rising_edge(fb_syscon_i.clk) then
			v_snd_tot := (others => '0');
			v_snd_tot_l := (others => '0');
			v_snd_tot_r := (others => '0');
			for I in G_CHANNELS-1 downto 0 loop
				v_snd_tot := v_snd_tot + i_child_snd_dat(I);
				if (I mod 4 = 0) or (I mod 4 = 3) then
					v_snd_tot_l := v_snd_tot_l + i_child_snd_dat(I);
					v_snd_tot_r := v_snd_tot_r + shift_right(i_child_snd_dat(I), 2);
				else
					v_snd_tot_l := v_snd_tot_l + shift_right(i_child_snd_dat(I), 2);
					v_snd_tot_r := v_snd_tot_r + i_child_snd_dat(I);
					end if;
			end loop;
			r_tot_snd_dat <= resize2(v_snd_tot, 16);
			r_tot_snd_dat_l <= resize2(v_snd_tot_l, 16);
			r_tot_snd_dat_r <= resize2(v_snd_tot_r, 16);
		end if;
	end process;

	e_buf_per:fb_intcon_buffer
   generic map (
      G_REG_C2P            => true,
      G_REG_P2C            => true
   ) 
   port map (

      fb_syscon_i          => fb_syscon_i,

      -- upstream peripheral port connect to controller
      fb_up_c2p_i          => fb_per_c2p_i,
      fb_up_p2c_o          => fb_per_p2c_o,

      -- downstream controller port connect to peripheral
      fb_dn_c2p_o          => i_per_buf_c2p,
      fb_dn_p2c_i          => i_per_buf_p2c

   );

	p_be_le:process(all)
	begin
		i_per_c2p_bele <= i_per_buf_c2p;
		if i_per_buf_c2p.A(9) = '1' then
			i_per_c2p_bele.A(3 downto 0) <= not i_per_buf_c2p.A(3 downto 0);
		end if;
	end process;


	e_per_mux:entity work.fb_intcon_one_to_many
	generic map (
      G_PERIPHERAL_COUNT   => G_CHANNELS + 1,
      G_MAXOUT             => 1     -- no pipelining here
   )
   port map (

      fb_syscon_i          => fb_syscon_i,

      -- peripheral port connect to controller
      fb_up_c2p_i          => i_per_c2p_bele,
      fb_up_p2c_o          => i_per_buf_p2c,

      -- controller port connect to peripherals
      fb_dn_c2p_o          => i_o2m_fb_per_c2p,
      fb_dn_p2c_i          => i_o2m_fb_per_p2c,

      -- peripheral select interface (see above)
      peripheral_sel_addr_o   => i_addr_addr,
      peripheral_sel_we_o     => open,
      peripheral_sel_i        => i_addr_dec_ix,
      peripheral_sel_oh_i     => i_addr_dec_oh
   );

	i_addr_dec_ix <= 	to_unsigned(G_CHANNELS, i_addr_dec_ix'length) 
									when i_addr_addr(3 downto 0) = A_CHA_SEL or i_addr_addr(3 downto 0) = A_OVR_VOL else
							resize(r_cha_sel, i_addr_dec_ix'length);
	i_addr_dec_oh <=  C_LOCAL_OH when i_addr_addr(3 downto 0) = A_CHA_SEL or i_addr_addr(3 downto 0) = A_OVR_VOL else
							"0" & r_cha_sel_oh;


	i_o2m_fb_per_p2c(G_CHANNELS) <= i_local_p2c;
	i_local_c2p <= i_o2m_fb_per_c2p(G_CHANNELS);

   i_local_p2c.A_ack    <= r_A_ack;
   i_local_p2c.D_rd     <= r_D_rd;
   i_local_p2c.rdy      <= r_D_ack;
   i_local_p2c.D_ack    <= r_D_ack;


	p_per_state:process(fb_syscon_i)
   variable v_dowrite: boolean;
	begin
		if fb_syscon_i.rst = '1' then
			r_per_state <= idle;
         r_D_ack <= '0';
         r_A_ack <= '0';
         r_D_rd <= (others => '0');
         r_A <= (others => '0');

			r_cha_sel <= (others => '0');
			r_cha_sel_oh <= (0 => '1', others => '0');
			r_ovr_vol <= (others => '1');
		elsif rising_edge(fb_syscon_i.clk) then
         v_dowrite := false;
         r_D_ack <= '0';
         r_A_ack <= '0';

			case r_per_state is
            when idle =>
               -- no need to check for previous r_A_ack cycle here as we can only go to act_wr, act_rd so no double ack
               if (i_local_c2p.cyc = '1' and i_local_c2p.A_stb = '1') then
                  r_A <= i_local_c2p.A(3 downto 0);
                  r_A_ack <= '1';
                  if i_local_c2p.we = '1' then
                     r_per_state <= act_wr;
                  else
                     r_per_state <= act_rd;                     
                  end if;
               end if;              
            when act_wr =>
               if i_local_c2p.D_wr_stb = '1' and r_D_ack = '0' then
                  v_dowrite := true;
               end if;
            when act_rd => 
               if i_local_c2p.cyc = '1' then
                  r_D_ack <= '1';                
                  if r_A = A_CHA_SEL then
                     r_D_rd <= std_logic_vector(resize(r_cha_sel, 8));
                  else
                     r_D_rd <= std_logic_vector(r_ovr_vol) & "00";
                  end if;
               end if;
               r_per_state <= idle;
            when others =>
               r_per_state <= idle;
			end case;

			if i_local_c2p.cyc = '0' then
            r_per_state <= idle;
            r_A_ack <= '0';
            r_D_ack <= '0';
         elsif v_dowrite then
            r_per_state <= idle;
            r_D_ack <= '1';
            if r_A = A_CHA_SEL then
					if G_CHANNELS > 1 then
						r_cha_sel <= unsigned(i_local_c2p.D_wr(numbits(G_CHANNELS)-1 downto 0));
						r_cha_sel_oh <= (others => '0');
						r_cha_sel_oh(to_integer(unsigned(i_local_c2p.D_wr(numbits(G_CHANNELS)-1 downto 0)))) <= '1';
					else
						r_cha_sel_oh <= "1";
					end if;
				elsif r_A = A_OVR_VOL then
					r_ovr_vol <= unsigned(i_local_c2p.D_wr(7 downto 2));
            end if;
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

		-- peripheral interface (control registers)
		fb_per_c2p_i						=> i_o2m_fb_per_c2p(I),
		fb_per_p2c_o						=> i_o2m_fb_per_p2c(I),

		-- controller interface (dma)
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




					

	i_cha_data_ack <= r_cha_data_cur_oh when r_con_state = act and fb_con_p2c_i.D_ack = '1' else
							(others => '0');

	i_cha_data_data <= signed(fb_con_p2c_i.D_rd);

	i_cur_cha_addr <= i_cha_data_addr(to_integer(r_cha_data_cur_ix));
	i_cur_cha_addr_offs <= i_cha_data_addr_offs(to_integer(r_cha_data_cur_ix));
	
	fb_con_c2p_o.cyc <= r_con_cyc;
	fb_con_c2p_o.a_stb <= r_con_a_stb;
	fb_con_c2p_o.A <= std_logic_vector(r_con_addrplusoffs);
	fb_con_c2p_o.we <= '0';
	fb_con_c2p_o.D_wr <= (others => '0');
	fb_con_c2p_o.D_wr_stb <= '0';
	fb_con_c2p_o.rdy_ctdn <= RDY_CTDN_MIN;

	p_con_state: process(fb_syscon_i)
	variable v_add16 : unsigned(16 downto 0);
	begin
		if fb_syscon_i.rst = '1' then

			r_con_state <= idle;
			r_con_cyc <= '0';
			r_con_a_stb <= '0';
			r_con_addrplusoffs <= (others => '0');
			r_cha_data_cur_ix <= (others => '0');
			r_cha_data_cur_oh <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then

			v_add16 := 
					("0" & i_cur_cha_addr(15 downto 0))
				+ 	("0" & i_cur_cha_addr_offs)
				;

			case r_con_state is
				when idle => 
					--arbitrate, simple priority
					if my_or_reduce(i_cha_data_req) = '1' then
						for I in G_CHANNELS-1 downto 0 loop
							if i_cha_data_req(I) = '1' then
								r_cha_data_cur_ix <= to_unsigned(I, r_cha_data_cur_ix'length);
								r_cha_data_cur_oh <= std_logic_vector(to_unsigned(2**I, r_cha_data_cur_oh'length));
							end if;
						end loop;
						r_con_state <= start;
					end if;
				when start =>
					r_con_addrplusoffs(15 downto 0) <= v_add16(15 downto 0);
					r_con_addrplusoffs(23 downto 16) <= i_cur_cha_addr(23 downto 16);
					if v_add16(16) = '1' then
						r_con_state <= startcy;
					else
						r_con_cyc <= '1';
						r_con_a_stb <= '1';
						r_con_state <= act;
					end if;
				when startcy =>
					r_con_addrplusoffs(23 downto 16) <= r_con_addrplusoffs(23 downto 16) + 1;
					r_con_cyc <= '1';
					r_con_a_stb <= '1';
					r_con_state <= act;						
				when act =>

					if fb_con_p2c_i.A_ack = '1' then
						r_con_a_stb <= '0';
					end if;

					if my_or_reduce(i_cha_data_req and r_cha_data_cur_oh) /= '1' then
						r_con_state <= idle;
						r_con_cyc <= '0';
						r_con_a_stb <= '0';
						r_cha_data_cur_oh <= (others => '0');
					end if;
				when others =>
					r_con_cyc <= '0';
					r_con_state <= idle;					
			end case;
		end if;
	end process;



end Behavioral;

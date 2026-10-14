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
-- Module Name:    	dmac - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
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

entity fb_DMAC_int_dma is
	 generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up	
		G_CHANNELS							: natural := 2;
		CLOCKSPEED							: natural
	 );
    Port (

		-- fishbone signals		
		fb_syscon_i							: in		fb_syscon_t;

		-- peripheral interface (control registers)
		fb_per_c2p_i						: in		fb_con_o_per_i_t;
		fb_per_p2c_o						: out		fb_con_i_per_o_t;

		-- controller interface (dma)
		fb_con_c2p_o						: out		fb_con_o_per_i_arr(G_CHANNELS-1 downto 0);
		fb_con_p2c_i						: in		fb_con_i_per_o_arr(G_CHANNELS-1 downto 0);

		int_o									: out		STD_LOGIC;		-- interrupt active hi
		cpu_halt_o							: out		STD_LOGIC;
		dma_halt_i							: in		STD_LOGIC
	 );

end fb_DMAC_int_dma;


architecture Behavioral of fb_DMAC_int_dma is

	constant	A_CHA_SEL		: std_logic_vector(3 downto 0) := x"F";

	-- buffer peripheral port
	signal	i_per_buf_c2p		: fb_con_o_per_i_t;
	signal	i_per_buf_p2c		: fb_con_i_per_o_t;

	-- local register (channel select) state machine
	type		per_state_t	is (idle, act_rd, act_wr);
	signal	r_per_state 		: per_state_t;
	signal	r_A_ack				: std_logic;
	signal	r_D_ack				: std_logic;
	signal	r_D_rd				: std_logic_vector(7 downto 0);
	signal	r_is_sel_reg		: std_logic;				-- current local access is to register F

	-- one more port than channels: the last one is the local channel select register
	signal	i_o2m_fb_per_c2p	: fb_con_o_per_i_arr(G_CHANNELS downto 0);
	signal	i_o2m_fb_per_p2c	: fb_con_i_per_o_arr(G_CHANNELS downto 0);
	signal	i_local_c2p			: fb_con_o_per_i_t;
	signal	i_local_p2c			: fb_con_i_per_o_t;

	signal	r_cha_sel			: unsigned(numbits(G_CHANNELS)-1 downto 0);
	signal	r_cha_sel_oh		: std_logic_vector(G_CHANNELS-1 downto 0);	-- all 0 when r_cha_sel is not a channel
	signal	i_cha_sel_none		: std_logic;

	-- select between channels/local register
	signal	i_addr_addr			: std_logic_vector(23 downto 0);
	signal	i_addr_dec_ix		: unsigned(numbits(G_CHANNELS+1)-1 downto 0);
	signal	i_addr_dec_oh		: std_logic_vector(G_CHANNELS downto 0);
	constant	C_LOCAL_OH			: std_logic_vector(G_CHANNELS downto 0) := (G_CHANNELS => '1', others => '0');

	signal	i_child_int			: std_logic_vector(G_CHANNELS-1 downto 0);
	signal	i_child_cpu_halt	: std_logic_vector(G_CHANNELS-1 downto 0);


begin


	int_o <= my_or_reduce(i_child_int);
	cpu_halt_o <= my_or_reduce(i_child_cpu_halt);

 	e_buf_per:fb_intcon_buffer
   generic map (
      G_REG_C2P            => true,
      G_REG_P2C            => false
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


	e_per_mux:entity work.fb_intcon_one_to_many
	generic map (
		G_PERIPHERAL_COUNT	=> G_CHANNELS + 1,
		G_MAXOUT					=> 1		-- no pipelining here
	)
	port map (

		fb_syscon_i				=> fb_syscon_i,

		-- peripheral port connect to controller
		fb_up_c2p_i				=> i_per_buf_c2p,
		fb_up_p2c_o				=> i_per_buf_p2c,

		-- controller port connect to peripherals
		fb_dn_c2p_o				=> i_o2m_fb_per_c2p,
		fb_dn_p2c_i				=> i_o2m_fb_per_p2c,

		-- peripheral select interface
		peripheral_sel_addr_o	=> i_addr_addr,
		peripheral_sel_we_o		=> open,
		peripheral_sel_i			=> i_addr_dec_ix,
		peripheral_sel_oh_i		=> i_addr_dec_oh
	);



	-- register F (in both the big- and little-endian maps) is the local channel
	-- select register, everything else goes to the selected channel. If the
	-- selected channel doesn't exist everything goes to the local registers,
	-- where reads other than F return FF and writes other than F are ignored.
	-- Software uses this to probe how many channels there are.
	-- TODO: document the probe behaviour (and that with a power of 2 channels the
	-- written value wraps, so no channel number is invalid)
	i_cha_sel_none <= not my_or_reduce(r_cha_sel_oh);

	i_addr_dec_ix <= 	to_unsigned(G_CHANNELS, i_addr_dec_ix'length) 
									when i_addr_addr(3 downto 0) = A_CHA_SEL or i_cha_sel_none = '1' else
							resize(r_cha_sel, i_addr_dec_ix'length);
	i_addr_dec_oh <=	C_LOCAL_OH when i_addr_addr(3 downto 0) = A_CHA_SEL or i_cha_sel_none = '1' else
							'0' & r_cha_sel_oh;

	i_local_c2p <= i_o2m_fb_per_c2p(G_CHANNELS);
	i_o2m_fb_per_p2c(G_CHANNELS) <= i_local_p2c;

	i_local_p2c.A_ack		<= r_A_ack;
	i_local_p2c.D_rd		<= r_D_rd;
	i_local_p2c.rdy		<= r_D_ack;
	i_local_p2c.D_ack		<= r_D_ack;

	-- local channel select register, the only register at this level (see above
	-- for other addresses when no valid channel is selected)
	-- r_cha_sel and r_cha_sel_oh are updated in the same clock as the D_ack so
	-- that the next access (held by e_per_mux until then) goes to the new channel
	p_per_state:process(fb_syscon_i)
	variable v_dowrite : boolean;
	begin
		if fb_syscon_i.rst = '1' then
			r_per_state <= idle;
			r_A_ack <= '0';
			r_D_ack <= '0';
			r_D_rd <= (others => '0');
			r_is_sel_reg <= '0';
			r_cha_sel <= (others => '0');
			r_cha_sel_oh <= (0 => '1', others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
			v_dowrite := false;
			r_A_ack <= '0';
			r_D_ack <= '0';

			case r_per_state is
				when idle =>
					-- no need to check for previous r_A_ack cycle here as we can only go to act_wr, act_rd so no double ack
					if i_local_c2p.cyc = '1' and i_local_c2p.A_stb = '1' then
						r_A_ack <= '1';
						if i_local_c2p.A(3 downto 0) = A_CHA_SEL then
							r_is_sel_reg <= '1';
								else
							r_is_sel_reg <= '0';
							end if;
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
						if r_is_sel_reg = '1' then
							r_D_rd <= std_logic_vector(resize(r_cha_sel, 8));
						else
							r_D_rd <= (others => '1');
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
				if r_is_sel_reg = '1' then
					-- any value is stored, as before; the one-hot is all 0 if it
					-- isn't a channel
				if G_CHANNELS > 1 then
						r_cha_sel <= unsigned(i_local_c2p.D_wr(numbits(G_CHANNELS)-1 downto 0));
				else
					r_cha_sel <= (others => '0');
				end if;
					r_cha_sel_oh <= (others => '0');
					for I in 0 to G_CHANNELS-1 loop
						if G_CHANNELS = 1 or unsigned(i_local_c2p.D_wr(numbits(G_CHANNELS)-1 downto 0)) = I then
							r_cha_sel_oh(I) <= '1';
						end if;
					end loop;
			end if;
			end if;
		end if;
	end process;
	
	--TODO: to save resources move register decoding and fishbone stuff to this level
	-- as only one selected
	g_cha: for I in 0 to G_CHANNELS-1 generate

		e_cha_1: entity work.fb_DMAC_int_dma_cha
		generic map (
		SIM									=> SIM,
		CLOCKSPEED							=> CLOCKSPEED
		)
		port map (

		-- fishbone signals		
		fb_syscon_i							=> fb_syscon_i,

		-- peripheral interface (control registers)
		fb_per_c2p_i						=> i_o2m_fb_per_c2p(I),
		fb_per_p2c_o						=> i_o2m_fb_per_p2c(I),

		-- controller interface (dma)
		fb_con_c2p_o						=> fb_con_c2p_o(I),
		fb_con_p2c_i						=> fb_con_p2c_i(I),

		int_o									=> i_child_int(I),
		cpu_halt_o							=> i_child_cpu_halt(I),
		dma_halt_i							=> dma_halt_i

		);

	end generate;

end Behavioral;

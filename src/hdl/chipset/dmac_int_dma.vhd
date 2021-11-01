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
use IEEE.STD_LOGIC_MISC.ALL;

library work;
use work.fishbone.all;
use work.common.all;

entity fb_DMAC_int_dma is
	 generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up	
		G_CHANNELS							: natural := 2;
		CLOCKSPEED							: natural
	 );
    Port (

		-- fishbone signals		
		fb_syscon_i							: in		fb_syscon_t;

		-- slave interface (control registers)
		fb_sla_m2s_i						: in		fb_mas_o_sla_i_t;
		fb_sla_s2m_o						: out		fb_mas_i_sla_o_t;

		-- master interface (dma)
		fb_mas_m2s_o						: out		fb_mas_o_sla_i_arr(G_CHANNELS-1 downto 0);
		fb_mas_s2m_i						: in		fb_mas_i_sla_o_arr(G_CHANNELS-1 downto 0);

		int_o									: out		STD_LOGIC;		-- interrupt active hi
		cpu_halt_o							: out		STD_LOGIC;
		dma_halt_i							: in		STD_LOGIC
	 );

	 -- sound
	 constant	A_CHA_SEL		: integer := 15;
end fb_DMAC_int_dma;

architecture Behavioral of fb_DMAC_int_dma is

	constant PADBITS				: std_logic_vector(7-NUMBITS(G_CHANNELS) downto 0) := (others => '0');

	type		sla_state_t	is (idle, child_act, sel_act, wait_cyc);

	signal	r_sla_state 		: sla_state_t;

	signal	i_cha_fb_sla_m2s	: fb_mas_o_sla_i_arr(G_CHANNELS-1 downto 0);
	signal	i_cha_fb_sla_s2m	: fb_mas_i_sla_o_arr(G_CHANNELS-1 downto 0);

	signal	r_cha_sel			: unsigned(numbits(G_CHANNELS)-1 downto 0);

	signal	i_child_int			: std_logic_vector(G_CHANNELS-1 downto 0);
	signal	i_child_cpu_halt	: std_logic_vector(G_CHANNELS-1 downto 0);

	signal	r_sel_sla_rdy		: std_logic;
	signal	r_sel_sla_ack		: std_logic;

begin

	int_o <= or_reduce(i_child_int);
	cpu_halt_o <= or_reduce(i_child_cpu_halt);

	p_sla_state:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_sla_state <= idle;
			r_cha_sel <= (others => '0');
			r_sel_sla_rdy <= '0';
			r_sel_sla_ack <= '0';
		elsif rising_edge(fb_syscon_i.clk) then

			r_sel_sla_ack <= '0';
			case r_sla_state is
				when idle =>
					if fb_sla_m2s_i.cyc = '1' and fb_sla_m2s_i.A_stb = '1' then
						if unsigned(fb_sla_m2s_i.A(3 downto 0)) = x"F" then
							r_sla_state <= sel_act;
							if fb_sla_m2s_i.we = '0' then
								r_sel_sla_ack <= '1';
								r_sel_sla_rdy <= '1';
							end if;
						else
							r_sla_state <= child_act;
						end if;
					end if;
				when sel_act =>
					if fb_sla_m2s_i.we = '1' and fb_sla_m2s_i.D_wr_stb = '1' then
						r_cha_sel <= unsigned(fb_sla_m2s_i.D_wr(numbits(G_CHANNELS)-1 downto 0));
						r_sel_sla_ack <= '1';
						r_sel_sla_rdy <= '1';
						r_sla_state <= wait_cyc;
					end if;
				when wait_cyc =>
				   -- already ack'd wait for cyc/a_stb to go low
				when others => null;
			end case;
			if fb_sla_m2s_i.cyc = '0' or fb_sla_m2s_i.A_stb = '0' then
				r_sla_state <= idle;
				r_sel_sla_rdy <= '0';
			end if;

		end if;
	end process;
	
	g_cha: for I in 0 to G_CHANNELS-1 generate

		e_cha_1: entity work.fb_DMAC_int_dma_cha
		generic map (
		SIM									=> SIM,
		CLOCKSPEED							=> CLOCKSPEED
		)
		port map (

		-- fishbone signals		
		fb_syscon_i							=> fb_syscon_i,

		-- slave interface (control registers)
		fb_sla_m2s_i						=> i_cha_fb_sla_m2s(I),
		fb_sla_s2m_o						=> i_cha_fb_sla_s2m(I),

		-- master interface (dma)
		fb_mas_m2s_o						=> fb_mas_m2s_o(I),
		fb_mas_s2m_i						=> fb_mas_s2m_i(I),

		int_o									=> i_child_int(I),
		cpu_halt_o							=> i_child_cpu_halt(I),
		dma_halt_i							=> dma_halt_i

		);

	end generate;

	p_sla_cha_sel_o:process(fb_syscon_i, r_sla_state, r_cha_sel, i_cha_fb_sla_s2m, fb_sla_m2s_i, r_sel_sla_rdy, r_sel_sla_ack)	
	variable v_sla_rdy_ctdn:unsigned(RDY_CTDN_LEN-1 downto 0);
	begin		
		if r_sel_sla_rdy = '1' then
			v_sla_rdy_ctdn := RDY_CTDN_MIN;
		else 
			v_sla_rdy_ctdn := RDY_CTDN_MAX;
		end if;


		fb_sla_s2m_o <= (
			D_rd => (others => '-'),
			rdy_ctdn => RDY_CTDN_MAX,
			ack => '0',
			nul => '0'
			);
		if r_sla_state = child_act then
			for I in 0 to G_CHANNELS-1 loop
				if r_cha_sel = I then
					fb_sla_s2m_o <= i_cha_fb_sla_s2m(I);
				end if;
			end loop;
		elsif r_sla_state = sel_act or r_sla_state = wait_cyc then
			fb_sla_s2m_o <= (
				D_rd => PADBITS & std_logic_vector(r_cha_sel),
				rdy_ctdn => v_sla_rdy_ctdn,
				ack => r_sel_sla_ack,
				nul => '0'
				);
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
						A => (others => '-'),
						A_stb => '0',
						D_wr => (others => '-'),
						D_wr_stb => '0'
					);
			end if;
		end loop;		
	end process;
end Behavioral;

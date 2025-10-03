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

	constant PADBITS				: std_logic_vector(7-NUMBITS(G_CHANNELS) downto 0) := (others => '0');

	type		sla_state_t	is (idle, child_act, sel_wr_wait);

	signal	r_per_state 		: sla_state_t;

	signal	i_cha_fb_per_c2p	: fb_con_o_per_i_arr(G_CHANNELS-1 downto 0);
	signal	i_cha_fb_per_p2c	: fb_con_i_per_o_arr(G_CHANNELS-1 downto 0);

	signal	r_cha_sel			: unsigned(numbits(G_CHANNELS)-1 downto 0);
	signal	i_reg_sel_sel		: std_logic;											-- 1 when current register access is for "F"
	signal   i_reg_ack			: std_logic; -- 1 when cha_sel is being ack'd
	signal   i_cyc_start			: std_logic;
	signal   i_sel_per_p2c		: fb_con_i_per_o_t;
	signal	i_reg_rd				: std_logic_vector(7 downto 0);

	signal	i_child_int			: std_logic_vector(G_CHANNELS-1 downto 0);
	signal	i_child_cpu_halt	: std_logic_vector(G_CHANNELS-1 downto 0);


begin


	int_o <= my_or_reduce(i_child_int);
	cpu_halt_o <= my_or_reduce(i_child_cpu_halt);

	i_cyc_start <= '1' when fb_per_c2p_i.cyc = '1' and fb_per_c2p_i.A_stb = '1' else '0';
	i_reg_sel_sel <= '1' when fb_per_c2p_i.A(3 downto 0) = A_CHA_SEL 
					else '0';
	i_reg_ack <= '1' when (r_per_state = idle and i_cyc_start = '1' and i_reg_sel_sel = '1' and (fb_per_c2p_i.we = '0' or fb_per_c2p_i.D_wr_stb = '1')) -- can ack on idle
								  or (r_per_state = sel_wr_wait and fb_per_c2p_i.D_wr_stb = '1') 
					else '0';

	p_per_state:process(fb_syscon_i)
	variable v_do_write_sel_reg:boolean;
	begin
		if fb_syscon_i.rst = '1' then
			r_per_state <= idle;
			r_cha_sel <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then

			v_do_write_sel_reg := false;

			case r_per_state is
				when idle =>
					if i_cyc_start = '1' then
						if i_reg_sel_sel = '1' then
							if fb_per_c2p_i.we = '1' then
								if fb_per_c2p_i.D_wr_stb = '1' then
									v_do_write_sel_reg := true;
								else
									r_per_state <= sel_wr_wait;
								end if;
							end if;
						else
							r_per_state <= child_act;
						end if;					
					end if;
				when sel_wr_wait => 
					if fb_per_c2p_i.D_wr_stb = '1' then
						v_do_write_sel_reg := true;
					end if;
				when child_act =>
					if i_sel_per_p2c.ack = '1' then
						r_per_state <= idle;
					end if;
				when others =>
					r_per_state <= idle;
			end case;


			if v_do_write_sel_reg then
				if G_CHANNELS > 1 then
					r_cha_sel <= unsigned(fb_per_c2p_i.D_wr(numbits(G_CHANNELS)-1 downto 0));
				else
					r_cha_sel <= (others => '0');
				end if;
				r_per_state <= idle;				
			end if;

			if fb_per_c2p_i.cyc = '0' then
				r_per_state <= idle;
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
		fb_per_c2p_i						=> i_cha_fb_per_c2p(I),
		fb_per_p2c_o						=> i_cha_fb_per_p2c(I),

		-- controller interface (dma)
		fb_con_c2p_o						=> fb_con_c2p_o(I),
		fb_con_p2c_i						=> fb_con_p2c_i(I),

		int_o									=> i_child_int(I),
		cpu_halt_o							=> i_child_cpu_halt(I),
		dma_halt_i							=> dma_halt_i

		);

	end generate;


	p_child_p2c:process(i_cha_fb_per_p2c, r_cha_sel)
	begin
			if G_CHANNELS = 1 then
				i_sel_per_p2c <= i_cha_fb_per_p2c(0);
			else
				i_sel_per_p2c <= (
					D_rd => (others => '1'),
					ack => '1',
					rdy => '1',
					stall => '0'
					);
				for I in 0 to G_CHANNELS-1 loop
					if r_cha_sel = I then
						i_sel_per_p2c <= i_cha_fb_per_p2c(I);
					end if;
				end loop;
			end if;
	end process;

	i_reg_rd <= PADBITS & std_logic_vector(r_cha_sel) when G_CHANNELS > 1 else (others => '0');

	fb_per_p2c_o.D_rd <= i_reg_rd when r_per_state = idle else i_sel_per_p2c.D_rd;
	fb_per_p2c_o.rdy <= i_reg_ack when r_per_state = idle or r_per_state = sel_wr_wait else i_sel_per_p2c.rdy;
	fb_per_p2c_o.ack <= i_reg_ack when r_per_state = idle or r_per_state = sel_wr_wait else i_sel_per_p2c.ack;
	fb_per_p2c_o.stall <= '0' when r_per_state = idle else '1';
					
	p_per_cha_sel_i:process(r_cha_sel, fb_per_c2p_i)
	begin
		if G_CHANNELS = 1 then
			i_cha_fb_per_c2p(0) <= fb_per_c2p_i;
		else
			for I in 0 to G_CHANNELS-1 loop
				i_cha_fb_per_c2p(I) <= (
					cyc => 		fb_per_c2p_i.cyc and b2s(I = r_cha_sel),
					we => 		fb_per_c2p_i.we,
					A => 			fb_per_c2p_i.A,
					A_stb => 	fb_per_c2p_i.A_stb,
					D_wr => 		fb_per_c2p_i.D_wr,
					D_wr_stb => fb_per_c2p_i.D_wr_stb,
					rdy_ctdn => fb_per_c2p_i.rdy_ctdn
				);
			end loop;		
		end if;
	end process;
end Behavioral;

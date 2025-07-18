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
-- Create Date:    	18/5/2019
-- Design Name: 
-- Module Name:    	many to one Fishbone interconnect
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		interconnect using configurable priority/round-robin arbitration
-- Dependencies: 
--
-- Revision: --
----------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.fishbone.all;
use work.common.all;

entity fb_intcon_one_to_many is
	generic (
		SIM					: boolean := false;
		G_PERIPHERAL_COUNT		: POSITIVE;
		G_ARB_ROUND_ROBIN : boolean := false;
		G_ADDRESS_WIDTH	: POSITIVE; 						-- width of the address that we care about
		G_REGISTER_CON_READS  : boolean := false	-- add registers on reads port of controller
	);
	port (

		fb_syscon_i				: in	fb_syscon_t;

		-- peripheral port connect to controllers
		fb_con_c2p_i			: in	fb_con_o_per_i_t;
		fb_con_p2c_o			: out	fb_con_i_per_o_t;

		-- controller port connecto to peripherals
		fb_per_c2p_o			: out fb_con_o_per_i_arr(G_PERIPHERAL_COUNT-1 downto 0);
		fb_per_p2c_i			: in 	fb_con_i_per_o_arr(G_PERIPHERAL_COUNT-1 downto 0);

		-- peripheral select interface -- note, testing shows that having both one hot and index is faster _and_ uses fewer resources
		peripheral_sel_addr_o		: out	std_logic_vector(G_ADDRESS_WIDTH-1 downto 0);
		peripheral_sel_i				: in unsigned(numbits(G_PERIPHERAL_COUNT)-1 downto 0);  -- address decoded selected peripheral
		peripheral_sel_oh_i			: in std_logic_vector(G_PERIPHERAL_COUNT-1 downto 0)		-- address decoded selected peripherals as one-hot

	);
end fb_intcon_one_to_many;


architecture rtl of fb_intcon_one_to_many is
	
	signal	r_peripheral_sel_ix	: unsigned(numbits(G_PERIPHERAL_COUNT)-1 downto 0);  -- registered address decoded selected peripheral index
	signal	r_cyc_per_oh	: std_logic_vector(G_PERIPHERAL_COUNT-1 downto 0);	-- registered cyc for peripherals - one hot
	signal	r_a_stb			: std_logic;

	signal	i_s2m				: fb_con_i_per_o_t;										-- data returned from selected peripheral

	--r_state machine
	type		state_t	is	(idle, wait_per_stall, act);
	signal	r_state				: state_t;

	signal	r_con_we			: std_logic;
	signal	r_con_D_wr		: std_logic_vector(7 downto 0);
	signal	r_con_D_wr_stb	: std_logic;
	signal	r_con_A			: std_logic_vector(G_ADDRESS_WIDTH-1 downto 0);
	signal	r_rdy_ctdn		: t_rdy_ctdn;
	signal 	i_con_A			: std_logic_vector(23 downto 0);
begin

	peripheral_sel_addr_o <= fb_con_c2p_i.A(G_ADDRESS_WIDTH-1 downto 0);

	p_frig:process(r_con_A)
	begin
		i_con_A <= (others => '-');
		i_con_A(G_ADDRESS_WIDTH-1 downto 0) <= r_con_A;
	end process;


	g_c2p_shared:for I in G_PERIPHERAL_COUNT-1 downto 0 generate
		fb_per_c2p_o(I).cyc 			<= r_cyc_per_oh(I);
		fb_per_c2p_o(I).A_stb		<= r_cyc_per_oh(I) and r_a_stb;
		fb_per_c2p_o(I).we 			<= r_con_we;
		fb_per_c2p_o(I).A				<= i_con_A;
		fb_per_c2p_o(I).D_wr			<= r_con_D_wr;
		fb_per_c2p_o(I).D_wr_stb	<= r_con_D_wr_stb;
		fb_per_c2p_o(I).rdy_ctdn	<= r_rdy_ctdn;
	end generate;

	-- signals back from selected peripheral to controllers
	p_p2c_shared:process(r_peripheral_sel_ix, fb_per_p2c_i, r_state)
	begin
		if r_state /= idle then
			i_s2m <= fb_per_p2c_i(to_integer(r_peripheral_sel_ix));
		else
			i_s2m <= fb_p2c_unsel;
		end if;
	end process;

	g_do_reg_reads:if G_REGISTER_CON_READS generate
		p_reg_rd:process(fb_syscon_i)
		begin
			if fb_syscon_i.rst = '1' then
				fb_con_p2c_o.D_rd 		<= (others => '0');
				fb_con_p2c_o.rdy		 	<= '0';
				fb_con_p2c_o.ack 			<= '0';	
			elsif rising_edge(fb_syscon_i.clk) then
				fb_con_p2c_o.D_rd 		<= i_s2m.D_rd;
				fb_con_p2c_o.rdy		 	<= i_s2m.rdy;
				fb_con_p2c_o.ack 			<= i_s2m.ack;	
			end if;
		end process;
	end generate;

	g_dont_reg_reads:if not G_REGISTER_CON_READS generate
	fb_con_p2c_o.D_rd 		<= i_s2m.D_rd;
	fb_con_p2c_o.rdy		 	<= i_s2m.rdy;
	fb_con_p2c_o.ack 			<= i_s2m.ack;	
	end generate;

	fb_con_p2c_o.stall		<= '0' when r_state = idle else '1';		

	p_state:process(fb_syscon_i, r_state)
	begin
		if fb_syscon_i.rst = '1' then
			r_state <= idle;
			r_peripheral_sel_ix <= (others => '0');
			r_cyc_per_oh <= (G_PERIPHERAL_COUNT-1 downto 0 => '0');
			r_a_stb <= '1';
			r_con_A <= (others => '0');
			r_con_D_wr <= (others => '0');
			r_con_D_wr_stb <= '0';
			r_con_we <= '0';
			r_rdy_ctdn <= RDY_CTDN_MIN;
		elsif rising_edge(fb_syscon_i.clk) then

			case r_state is
				when idle =>
					r_con_D_wr_stb <= '0';
					if fb_con_c2p_i.cyc = '1' and fb_con_c2p_i.A_stb = '1' then
						r_a_stb <= '1';
						r_cyc_per_oh <= peripheral_sel_oh_i;
						r_peripheral_sel_ix <= peripheral_sel_i;
						r_con_A <= fb_con_c2p_i.A(G_ADDRESS_WIDTH-1 downto 0);
						r_con_we <= fb_con_c2p_i.we;
						r_rdy_ctdn <= fb_con_c2p_i.rdy_ctdn;

						if fb_con_c2p_i.D_wr_stb = '1' then
							r_con_D_wr <= fb_con_c2p_i.D_wr;
							r_con_D_wr_stb <= fb_con_c2p_i.D_wr_stb;
						end if;

						r_state <= wait_per_stall;
					end if;
				when wait_per_stall =>

					if fb_con_c2p_i.D_wr_stb = '1' then
						r_con_D_wr <= fb_con_c2p_i.D_wr;
						r_con_D_wr_stb <= fb_con_c2p_i.D_wr_stb;
					end if;

					if fb_per_p2c_i(to_integer(r_peripheral_sel_ix)).stall /= '0' then
						r_state <= wait_per_stall;
					else
						r_state <= act;
						r_a_stb <= '0';
					end if;

				when act =>

					if fb_con_c2p_i.D_wr_stb = '1' then
						r_con_D_wr <= fb_con_c2p_i.D_wr;
						r_con_D_wr_stb <= fb_con_c2p_i.D_wr_stb;
					end if;

					if i_s2m.ack = '1' then
						r_state <= idle; -- do nowt
					end if;
				when others =>  
					r_peripheral_sel_ix <= (others => '0');
					r_cyc_per_oh <= (others => '0');
					r_con_D_wr <= (others => '0');
					r_con_D_wr_stb <= '0';
					r_state <= idle; -- do nowt
			end case;

			-- catch all for ended cycle
			if fb_con_c2p_i.cyc = '0' then
				r_state <= idle;
				r_peripheral_sel_ix <= (others => '0');
				r_cyc_per_oh <= (others => '0');
				r_a_stb <= '0';
			end if;



		end if;
	end process;


end rtl;
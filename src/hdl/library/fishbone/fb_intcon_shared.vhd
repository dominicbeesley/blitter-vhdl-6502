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
-- Module Name:    	many to many Fishbone inter-connect
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

entity fb_intcon_shared is
	generic (
		SIM					: boolean := false;
		G_CONTROLLER_COUNT		: POSITIVE;
		G_PERIPHERAL_COUNT		: POSITIVE;
		G_ARB_ROUND_ROBIN : boolean := false;
		G_REGISTER_CONTROLLER_P2C: boolean := false
	);
	port (

		fb_syscon_i				: in	fb_syscon_t;

		-- peripheral port connect to controllers
		fb_con_c2p_i			: in	fb_con_o_per_i_arr(G_CONTROLLER_COUNT-1 downto 0);
		fb_con_p2c_o			: out	fb_con_i_per_o_arr(G_CONTROLLER_COUNT-1 downto 0);

		-- controller port connecto to peripherals
		fb_per_c2p_o			: out fb_con_o_per_i_arr(G_PERIPHERAL_COUNT-1 downto 0);
		fb_per_p2c_i			: in 	fb_con_i_per_o_arr(G_PERIPHERAL_COUNT-1 downto 0);

		-- peripheral select interface -- note, testing shows that having both one hot and index is faster _and_ uses fewer resources
		peripheral_sel_addr_o		: out	fb_arr_std_logic_vector(G_CONTROLLER_COUNT-1 downto 0)(23 downto 0);
		peripheral_sel_i				: in fb_arr_unsigned(G_CONTROLLER_COUNT-1 downto 0)(numbits(G_PERIPHERAL_COUNT)-1 downto 0);  -- address decoded selected peripheral
		peripheral_sel_oh_i			: in fb_arr_std_logic_vector(G_CONTROLLER_COUNT-1 downto 0)(G_PERIPHERAL_COUNT-1 downto 0)		-- address decoded selected peripherals as one-hot

	);
end fb_intcon_shared;


architecture rtl of fb_intcon_shared is

	function b2s(i:boolean) return std_logic is
	begin
		if i = true then
			return '1';
		else
			return '0';
		end if;
	end function;


	signal	i_cyc_a_stb			: std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);	-- a_stb (qualified) requests in from controllers grouped
	signal	i_cyc					: std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);	-- cyc requests in from controllers grouped
	signal	i_cyc_grant_ix		: unsigned(numbits(G_CONTROLLER_COUNT)-1 downto 0); -- grant signal from arbitrator
	signal	r_cyc_grant_ix		: unsigned(numbits(G_CONTROLLER_COUNT)-1 downto 0); -- indexed which controller is active
	signal	r_cyc_act_oh		: unsigned(G_CONTROLLER_COUNT-1 downto 0);				-- one hot for which controller is active 
	signal	i_a_stb_any			: std_logic;												-- '1' when any controller is active
	signal	r_cyc_ack			: std_logic;												-- signal that cycle is being serviced

	signal	i_c2px				: fb_con_o_per_i_t := fb_c2p_unsel;					-- the i_c2px that has been granted muxed

	-- register the muxed signals for timing
	signal	r_c2p_A			: std_logic_vector(23 downto 0);						-- registered address of selected controller
	signal	r_c2p_we			: std_logic;												-- registered we 
	signal	r_rdy_ctdn		: t_rdy_ctdn;
	signal   r_a_stb			: std_logic;
	signal	r_d_wr			: std_logic_vector(7 downto 0);
	signal	r_d_wr_stb		: std_logic;
	
	signal	r_peripheral_sel		: unsigned(numbits(G_PERIPHERAL_COUNT)-1 downto 0);  -- registered address decoded selected peripheral
	signal	r_cyc_per		: std_logic_vector(G_PERIPHERAL_COUNT-1 downto 0);	-- registered cyc for peripherals - one hot

	signal	i_p2c				: fb_con_i_per_o_t;										-- data returned from selected peripheral

	-- these signals might or might not be registered when fed back from peripheral 
	-- dependant upon G_REGISTER_CONTROLLER_P2C
	
	signal   ir_p2c_D_rd		: std_logic_vector(7 downto 0);
	signal   ir_p2c_rdy		: std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);
	signal   ir_p2c_ack		: std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);
	signal   ir_p2c_stall	: std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);

	--r_state machine
	type		state_t	is	(idle, waitstall, act);
	signal	r_state				: state_t;

begin

g_addr_decode:for I in G_CONTROLLER_COUNT-1 downto 0 generate
	peripheral_sel_addr_o(I) <= fb_con_c2p_i(I).A;

end generate;


g_cyc:for I in G_CONTROLLER_COUNT-1 downto 0 generate
	i_cyc_a_stb(I) <= fb_con_c2p_i(i).cyc and fb_con_c2p_i(i).a_stb;
	i_cyc(I) <= fb_con_c2p_i(i).cyc;
end generate;



	g_arb:if G_ARB_ROUND_ROBIN generate
		-- arbitrate between incoming controllers
		e_arb_rr:entity work.fb_arbiter_roundrobin
		generic map (
			CNT => G_CONTROLLER_COUNT
			)
		port map (
			clk_i 		=> fb_syscon_i.clk,
			rst_i 		=> fb_syscon_i.rst,
			req_i 		=> i_cyc,
			ack_i			=> r_cyc_ack,
			grant_ix_o	=> i_cyc_grant_ix
			);
	else generate
		-- arbitrate between incoming controllers
		e_arb_pri:entity work.fb_arbiter_prior
		generic map (
			CNT => G_CONTROLLER_COUNT
			)
		port map (
			clk_i 		=> fb_syscon_i.clk,
			rst_i 		=> fb_syscon_i.rst,
			req_i 		=> i_cyc,
			ack_i			=> r_cyc_ack,
			grant_ix_o	=> i_cyc_grant_ix
			);		
	end generate;

	i_a_stb_any <= or_reduce(i_cyc_a_stb);

	-- multiplex i_c2px inputs
	p_mux_m2s:process(r_state, r_cyc_grant_ix, fb_con_c2p_i)
	begin
		i_c2px <= fb_c2p_unsel;
		if r_state /= idle then
			i_c2px <= fb_con_c2p_i(to_integer(r_cyc_grant_ix));
		end if;
	end process;

	g_c2p_shared:for I in G_PERIPHERAL_COUNT-1 downto 0 generate
		fb_per_c2p_o(I).cyc 			<= r_cyc_per(i);
		fb_per_c2p_o(I).we 			<= r_c2p_we;
		fb_per_c2p_o(I).A				<= r_c2p_A;
		fb_per_c2p_o(I).rdy_ctdn	<= r_rdy_ctdn;
		fb_per_c2p_o(I).A_stb		<= r_A_stb;
		fb_per_c2p_o(I).D_wr			<= r_D_wr;
		fb_per_c2p_o(I).D_wr_stb	<= r_D_wr_stb;
	end generate;

	-- signals back from selected peripheral to controllers
	i_p2c <= fb_per_p2c_i(to_integer(r_peripheral_sel));

	G_REGISTER_CONTROLLER_P2C_ON:IF G_REGISTER_CONTROLLER_P2C GENERATE
		p_reg_con_s2m:process(fb_syscon_i.clk)
		begin
			if rising_edge(fb_syscon_i.clk) then
				ir_p2c_D_rd	<= i_p2c.D_rd;

				for I in G_CONTROLLER_COUNT-1 downto 0 loop
					ir_p2c_rdy(I)	<= i_p2c.rdy and r_cyc_act_oh(I);
					ir_p2c_ack(I)	<= i_p2c.ack and r_cyc_act_oh(I);				
				end loop;
			end if;
		end process;
	END GENERATE;


	G_REGISTER_CONTROLLER_P2C_OFF:IF NOT G_REGISTER_CONTROLLER_P2C GENERATE
		g_p2c_shared_bus:for I in G_CONTROLLER_COUNT-1 downto 0 generate
					-- TODO: check if moving data to own shared register saves space
				ir_p2c_D_rd	<= i_p2c.D_rd;
				gra:for I in G_CONTROLLER_COUNT-1 downto 0 generate
					ir_p2c_rdy(I)	<= i_p2c.rdy and r_cyc_act_oh(I);
					ir_p2c_ack(I)	<= i_p2c.ack and r_cyc_act_oh(I);				
				end generate;
		end generate;
	END GENERATE;

	-- stall is always async
	g_stall:for I in G_CONTROLLER_COUNT-1 downto 0 generate
		ir_p2c_stall(I) <= '0' when r_state = idle and i_cyc_grant_ix = I else '1';
	end generate;

	-- had to separate this out into separate step as modelsim goes daft if different parts of
	-- a record are assigned in different processes or part in process part as continuous
	g_p2c:for I in G_CONTROLLER_COUNT-1 downto 0 generate
		fb_con_p2c_o(I).D_rd <= ir_p2c_D_rd;
		fb_con_p2c_o(I).rdy <= ir_p2c_rdy(I);
		fb_con_p2c_o(I).ack <= ir_p2c_ack(I);
		fb_con_p2c_o(I).stall <= ir_p2c_stall(I);
	end generate;




	p_state:process(fb_syscon_i, r_state)
	begin
		if fb_syscon_i.rst = '1' then
			r_state <= idle;
			r_peripheral_sel <= (others => '0');
			r_cyc_per <= (G_PERIPHERAL_COUNT-1 downto 0 => '0');
			r_c2p_A <= (others => '0');
			r_c2p_we <= '0';
			r_cyc_grant_ix <= (others => '0');
			r_cyc_act_oh <= (others => '0');
			r_rdy_ctdn <= RDY_CTDN_MIN;
			r_a_stb <= '0';
			r_d_wr_stb <= '0';
			r_d_wr <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
			r_state <= r_state;
			r_cyc_ack <= '0';

			case r_state is
				when idle =>
					if i_a_stb_any = '1' then
						r_cyc_grant_ix <= i_cyc_grant_ix;
						r_cyc_ack <= '1';
						r_cyc_per <= peripheral_sel_oh_i(to_integer(i_cyc_grant_ix));
						r_peripheral_sel <= peripheral_sel_i(to_integer(i_cyc_grant_ix));
						--register these as they shouldn't change during a cycle
						r_c2p_A <= fb_con_c2p_i(to_integer(i_cyc_grant_ix)).A;					
						r_c2p_we <= fb_con_c2p_i(to_integer(i_cyc_grant_ix)).we;
						r_rdy_ctdn <= fb_con_c2p_i(to_integer(i_cyc_grant_ix)).rdy_ctdn;
						r_cyc_act_oh(to_integer(i_cyc_grant_ix)) <= '1';
						r_d_wr_stb <= fb_con_c2p_i(to_integer(i_cyc_grant_ix)).D_wr_stb;
						r_d_wr <= fb_con_c2p_i(to_integer(i_cyc_grant_ix)).D_wr;
						r_state <= waitstall;
						r_a_stb <= '1';
					end if;
				when waitstall =>

					-- while stalled latch 
					if i_p2c.stall = '1' then
						if fb_con_c2p_i(to_integer(r_cyc_grant_ix)).D_wr_stb = '1' then
							r_d_wr_stb <= '1';
							r_d_wr <= fb_con_c2p_i(to_integer(r_cyc_grant_ix)).D_wr;
						end if;
					else
						r_d_wr_stb <= fb_con_c2p_i(to_integer(r_cyc_grant_ix)).D_wr_stb;
						r_d_wr <= fb_con_c2p_i(to_integer(r_cyc_grant_ix)).D_wr;
					end if;

					if i_p2c.stall = '0' then
						r_state <= act;
						r_a_stb <= '0';
					end if;
				when act => 
						r_d_wr_stb <= fb_con_c2p_i(to_integer(r_cyc_grant_ix)).D_wr_stb;
						r_d_wr <= fb_con_c2p_i(to_integer(r_cyc_grant_ix)).D_wr;
				when others =>  
					r_state <= r_state; -- do nowt
			end case;


			-- catch all for ended cycle
			if r_state /= idle and i_cyc(to_integer(r_cyc_grant_ix)) = '0' then
				r_state <= idle;
				r_peripheral_sel <= (others => '0');
				r_cyc_per <= (G_PERIPHERAL_COUNT-1 downto 0 => '0');
				r_cyc_grant_ix <= (others => '0');
				r_cyc_act_oh <= (others => '0');
			end if;
		end if;
	end process;


end rtl;
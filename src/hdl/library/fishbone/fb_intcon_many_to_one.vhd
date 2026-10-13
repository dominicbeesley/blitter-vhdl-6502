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

-- Company:          Dossytronics
-- Engineer:         Dominic Beesley
-- 
-- Create Date:      18/5/2019
-- Design Name: 
-- Module Name:      many to one Fishbone inter-connect
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      interconnect using configurable priority/round-robin arbitration
-- Dependencies: 
--
-- Revision:
--                   Oct 2026 Fishbone: stall replaced by A_ack, ack by D_ack.
--                   Minimum change: the forward (c2p) path is still registered,
--                   now as a one-entry address slot like fb_intcon_buffer's c2p
--                   stage, so A_ack to the controller is generated here. The
--                   grant is held until the granted controller drops cyc.
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fishbone.all;
use work.common.all;

entity fb_intcon_many_to_one is
	generic (
		G_CONTROLLER_COUNT      : POSITIVE;
		G_ARB_ROUND_ROBIN : boolean := false
	);
	port (

		fb_syscon_i          : in  fb_syscon_t;

		-- peripheral port connect to controllers
		fb_up_c2p_i          : in  fb_con_o_per_i_arr(G_CONTROLLER_COUNT-1 downto 0);
		fb_up_p2c_o          : out fb_con_i_per_o_arr(G_CONTROLLER_COUNT-1 downto 0);

		-- controller port connect to peripherals
		fb_dn_c2p_o          : out fb_con_o_per_i_t;
		fb_dn_p2c_i          : in  fb_con_i_per_o_t

	);
end fb_intcon_many_to_one;


architecture rtl of fb_intcon_many_to_one is
	signal   i_cyc_a_stb       : std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);  -- cyc and A_stb from each controller
	signal   i_cyc             : std_logic_vector(G_CONTROLLER_COUNT-1 downto 0); -- cyc requests in from controllers grouped
	signal   i_cyc_grant_ix    : unsigned(numbits(G_CONTROLLER_COUNT)-1 downto 0);
	signal   r_cyc_grant_ix    : unsigned(numbits(G_CONTROLLER_COUNT)-1 downto 0);
	signal   r_cyc_act_oh      : unsigned(G_CONTROLLER_COUNT-1 downto 0);            -- controller is active 
	signal   i_a_stb_any       : std_logic;                                        -- any controller has an A_stb
	signal   r_cyc_ack         : std_logic;                                    -- signal that cycle is being serviced

	-- register the muxed signals for timing
	signal   r_c2p_A        : std_logic_vector(23 downto 0);                -- registered address of selected controller
	signal   r_c2p_we       : std_logic;                                    -- registered we 
	signal   r_rdy_ctdn     : t_rdy_ctdn;
	signal   r_D_wr         : std_logic_vector(7 downto 0);
	signal   r_D_wr_stb     : std_logic;

	signal   r_cyc_per      : std_logic;                                    -- registered cyc for peripheral
	signal   r_a_stb_per       : std_logic;                                        -- registered a_stb for peripheral (address slot full)
	signal   r_A_ack           : std_logic;                                        -- A_ack to the granted controller

	--r_state machine
	type     state_t  is (idle, act);
	signal   r_state           : state_t;

begin


g_cyc:for I in G_CONTROLLER_COUNT-1 downto 0 generate
	i_cyc_a_stb(I) <= fb_up_c2p_i(i).cyc and fb_up_c2p_i(i).a_stb;
	i_cyc(I) <= fb_up_c2p_i(i).cyc;
end generate;

	g_arb:if G_ARB_ROUND_ROBIN generate
		-- arbitrate between incoming controllers
		e_arb_rr:entity work.fb_arbiter_roundrobin
		generic map (
			CNT => G_CONTROLLER_COUNT
			)
		port map (
			clk_i       => fb_syscon_i.clk,
			rst_i       => fb_syscon_i.rst,
			req_i       => i_cyc,
			ack_i       => r_cyc_ack,
			grant_ix_o  => i_cyc_grant_ix
			);
	else generate
		-- arbitrate between incoming controllers
		e_arb_pri:entity work.fb_arbiter_prior
		generic map (
			CNT => G_CONTROLLER_COUNT
			)
		port map (
			clk_i       => fb_syscon_i.clk,
			rst_i       => fb_syscon_i.rst,
			req_i       => i_cyc,
			ack_i       => r_cyc_ack,
			grant_ix_o  => i_cyc_grant_ix
			);    
	end generate;

	i_a_stb_any <= my_or_reduce(i_cyc_a_stb);

	fb_dn_c2p_o.cyc         <= r_cyc_per;
	fb_dn_c2p_o.we          <= r_c2p_we;
	fb_dn_c2p_o.A           <= r_c2p_A;
	fb_dn_c2p_o.A_stb       <= r_a_stb_per;
	fb_dn_c2p_o.D_wr        <= r_D_wr;
	fb_dn_c2p_o.D_wr_stb    <= r_D_wr_stb;
	fb_dn_c2p_o.rdy_ctdn    <= r_rdy_ctdn;

	g_p2c_shared_bus:for I in G_CONTROLLER_COUNT-1 downto 0 generate
		-- TODO: check if moving data to own shared register saves space
		fb_up_p2c_o(I).D_rd  <= fb_dn_p2c_i.D_rd;
		fb_up_p2c_o(I).rdy   <= fb_dn_p2c_i.rdy and r_cyc_act_oh(I);
		fb_up_p2c_o(I).D_ack <= fb_dn_p2c_i.D_ack and r_cyc_act_oh(I);
		fb_up_p2c_o(I).A_ack <= r_A_ack and r_cyc_act_oh(I);
	end generate;

	p_state:process(fb_syscon_i)
	variable v_free : boolean;
	begin
		if fb_syscon_i.rst = '1' then
			r_state <= idle;
			r_cyc_ack <= '0';
			r_cyc_per <= '0';
			r_a_stb_per <= '0';
			r_A_ack <= '0';
			r_c2p_A <= (others => '0');
			r_c2p_we <= '0';
			r_cyc_grant_ix <= (others => '0');
			r_cyc_act_oh <= (others => '0');
			r_D_wr <= (others => '0');
			r_D_wr_stb <= '0';
			r_rdy_ctdn <= RDY_CTDN_MIN;
		elsif rising_edge(fb_syscon_i.clk) then
			r_cyc_ack <= '0';
			r_A_ack <= '0';

			case r_state is
				when idle =>
					-- grant; the controller's A_stb is taken in act, a clock later
					if i_a_stb_any = '1' then
						r_state <= act;
						r_cyc_grant_ix <= i_cyc_grant_ix;
						r_cyc_ack <= '1';
						r_cyc_per <= '1';
						r_rdy_ctdn <= fb_up_c2p_i(to_integer(i_cyc_grant_ix)).rdy_ctdn;
						r_cyc_act_oh(to_integer(i_cyc_grant_ix)) <= '1';
						end if;
				when act =>
					-- address side: depth-1 slot, reloadable in the clock it empties
					-- (as fb_intcon_buffer c2p stage)
					v_free := r_a_stb_per = '0' or fb_dn_p2c_i.A_ack = '1';
					if fb_dn_p2c_i.A_ack = '1' then
						r_a_stb_per <= '0';
					end if;
					if v_free and fb_up_c2p_i(to_integer(r_cyc_grant_ix)).A_stb = '1' and r_A_ack = '0' then
						r_a_stb_per <= '1';
						r_c2p_A <= fb_up_c2p_i(to_integer(r_cyc_grant_ix)).A;
						r_c2p_we <= fb_up_c2p_i(to_integer(r_cyc_grant_ix)).we;
						r_A_ack <= '1';
					end if;
					-- write data: registered copy, mask the strobe in the clock after
					-- the peripheral's D_ack (the peripheral's guard covers the other)
					r_D_wr_stb <= fb_up_c2p_i(to_integer(r_cyc_grant_ix)).D_wr_stb and not fb_dn_p2c_i.D_ack;
					r_D_wr <= fb_up_c2p_i(to_integer(r_cyc_grant_ix)).D_wr;
				when others =>  
					r_state <= idle;
			end case;

			-- catch all for ended cycle
			if r_state /= idle and i_cyc(to_integer(r_cyc_grant_ix)) = '0' then
				r_state <= idle;
				r_cyc_per <= '0';
				r_a_stb_per <= '0';
				r_A_ack <= '0';
				r_cyc_grant_ix <= (others => '0');
				r_cyc_act_oh <= (others => '0');
				r_D_wr <= (others => '0');
				r_D_wr_stb <= '0';
			end if;
		end if;
	end process;


end rtl;

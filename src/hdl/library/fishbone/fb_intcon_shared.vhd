-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2026 Dominic Beesley https://github.com/dominicbeesley
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
-- Module Name:      fb_intcon_shared
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      arbitrates between controllers and steers each transaction
--                   to one of many peripherals, Oct 2026 Fishbone (A_ack/D_ack)
-- Dependencies:     fishbone, common, fb_arbiter_prior/_roundrobin, one external
--                   address decoder per controller (see fb_intcon_pack for the
--                   peripheral_sel_* interface)
--
-- Revision:
--                   Oct 2026 Fishbone: rewritten. Does the job of
--                   fb_intcon_many_to_one followed by fb_intcon_one_to_many,
--                   but decodes each controller's address *before* the
--                   registered slot, so no decoder is on the forward path
-- Additional Comments:
--
--   Arbitration (as fb_intcon_many_to_one)
--   * The arbiter picks between controllers at the start of cyc up.
--     a grant is taken when any controller has cyc and A_stb up and held 
--     until the granted controller drops cyc
--   * The grant is taken and the first transaction captured in the same
--     edge (no extra clock at the start of a cycle).
--
--   Pipelining: G_PIPELINE_DEPTH is the most transactions that may be
--   outstanding at the peripherals (A_ack'd, not yet D_ack'd). 1 turns
--   pipelining off and uses a simpler slot (below) with shorter paths from
--   the peripherals' A_ack and D_ack. Use 1 unless a controller on this
--   interconnect issues its next A_stb before the previous D_ack.
--
--   Forward path: one registered slot
--   * The slot holds A, we, and the peripheral select (index and one-hot)
--     loaded whenever the slot is free. The slot is marked full,
--     and A_ack given to the controller, only for an A_stb.
--   * cyc, A, we, D_wr, D_wr_stb and rdy_ctdn are broadcast to every
--     peripheral; only A_stb is steered. 
--   * The address decoders sit between the controllers and the slot
--     register, not on the path to the peripherals: each A_stb is one small
--     LUT of registers.
--
--   Not pipelined (G_PIPELINE_DEPTH = 1)
--   * The slot holds its transaction until the peripheral's D_ack.
--     A_stb to peripheral k is r_full and r_sel_oh(k) until the
--     peripheral's A_ack (r_dn_A_acked); D_ack empties the slot.
--   * Returns are steered by r_sel_oh and gated with r_full.
--   * The peripheral's A_ack and D_ack each feed one LUT (r_dn_A_acked,
--     r_full) and the controller's returns; nothing in the slot's load or
--     capture depends on them. A controller that waits for D_ack before its
--     next A_stb sees no extra latency: the slot is free on the edge where
--     it sees the D_ack.
--
--   Pipelined (G_PIPELINE_DEPTH > 1)
--   * A_stb to peripheral k is r_full and r_sel_oh(k), unless something is
--     owed (r_cnt_nz) and k isn't the peripheral owed it (r_own_oh(k)) or the
--     count is at G_PIPELINE_DEPTH (r_cnt_max). Using the one-hots (index
--     and one-hot always agree) needs no index compare.
--   * The slot empties on the peripheral's A_ack and can reload in the same
--     clock, so a controller can still issue one transaction per 2 clocks.
--
--   Peripheral switching and returns when pipelined (as fb_intcon_one_to_many)
--   * r_cnt counts transactions A_ack'd by a peripheral but not yet D_ack'd,
--     and r_own_oh records which peripheral owes them. While
--     r_cnt /= 0 the slot's A_stb is only forwarded to the same peripheral,
--     and only while r_cnt < G_PIPELINE_DEPTH. So D_acks come back in order, from
--     one peripheral at a time, and one cycle may span several peripherals.
--   * Returns are steered by registers only: A_ack by r_sel_oh (the slot
--     holds its select until A_ack), D_ack/D_rd/rdy by r_own_oh. r_own_oh
--     follows the slot while r_cnt = 0 and holds while anything is owed.
--     Acks are registered at the peripherals, so none can answer before the
--     clock after it first sees A_stb, by which time r_own_oh holds it.
--   * Only the one-hot select is used; the decoders' index (peripheral_sel_i)
--     is not needed here and is left unconnected inside.
--   * D_ack and rdy to the controller are gated with downstream cyc and the
--     granted controller's one-hot, so nothing from an aborted cycle reaches
--     the next controller.
--
-- Assumptions (as fb_intcon_one_to_many, see fb_intcon_pack): every decoder
-- maps every address to a valid peripheral with index and one-hot agreeing;
-- a peripheral gives one A_ack per A_stb it was sent in this cyc and one
-- D_ack per A_ack'd transaction; it takes D_wr_stb only for an accepted write
-- still waiting for data.
--
-- Latency: one registered hop per transaction (the slot); returns are
-- combinational through register-steered muxes.
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;

entity fb_intcon_shared is
	generic (
      G_CONTROLLER_COUNT : positive;
      G_PERIPHERAL_COUNT : positive;
		G_ARB_ROUND_ROBIN : boolean := false;
      G_PIPELINE_DEPTH   : positive := 15     -- max transactions outstanding at the peripherals, 1 = not pipelined
	);
	port (
		fb_syscon_i				: in	fb_syscon_t;

      -- peripheral ports connect to controllers
      fb_up_c2p_i           : in  fb_con_o_per_i_arr(G_CONTROLLER_COUNT-1 downto 0);
      fb_up_p2c_o           : out fb_con_i_per_o_arr(G_CONTROLLER_COUNT-1 downto 0);

      -- controller ports connect to peripherals
      fb_dn_c2p_o           : out fb_con_o_per_i_arr(G_PERIPHERAL_COUNT-1 downto 0);
      fb_dn_p2c_i           : in  fb_con_i_per_o_arr(G_PERIPHERAL_COUNT-1 downto 0);

      -- peripheral select interface, one decoder per controller (see fb_intcon_pack)
		peripheral_sel_addr_o		: out	fb_arr_std_logic_vector(G_CONTROLLER_COUNT-1 downto 0)(23 downto 0);
		peripheral_sel_we_o			: out	std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);
      peripheral_sel_i      : in  fb_arr_unsigned(G_CONTROLLER_COUNT-1 downto 0)(numbits(G_PERIPHERAL_COUNT)-1 downto 0);
      peripheral_sel_oh_i   : in  fb_arr_std_logic_vector(G_CONTROLLER_COUNT-1 downto 0)(G_PERIPHERAL_COUNT-1 downto 0)
	);
end entity fb_intcon_shared;

architecture rtl of fb_intcon_shared is

   type state_t is (idle, act);

   -- arbitration
   signal r_state        : state_t;
   signal i_cyc          : std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);   -- cyc from each controller
   signal i_cyc_a_stb    : std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);   -- cyc and A_stb from each controller
   signal i_a_stb_any    : std_logic;                                         -- any controller has cyc and A_stb
   signal i_arb_grant_ix : unsigned(numbits(G_CONTROLLER_COUNT)-1 downto 0);  -- arbiter's choice (combinatorial)
   signal r_grant_ix     : unsigned(numbits(G_CONTROLLER_COUNT)-1 downto 0);  -- granted controller
   signal r_grant_oh     : std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);   -- granted controller one-hot, all 0 in idle
   signal r_arb_ack      : std_logic;                                         -- grant taken (to arbiter)

   -- the granted controller: arbiter's choice in idle, held grant in act
   signal i_grant_ix     : unsigned(numbits(G_CONTROLLER_COUNT)-1 downto 0);
   signal i_gnt_c2p      : fb_con_o_per_i_t;
   signal i_gnt_sel_oh   : std_logic_vector(G_PERIPHERAL_COUNT-1 downto 0);

   -- forward slot and downstream registers
   signal r_dn_cyc       : std_logic;
   signal r_full         : std_logic;                                         -- slot holds an A_stb
   signal r_up_A_ack     : std_logic;                                         -- A_ack to the granted controller
   signal r_A            : std_logic_vector(23 downto 0);
   signal r_we           : std_logic;
   signal r_sel_oh       : std_logic_vector(G_PERIPHERAL_COUNT-1 downto 0);
	signal	r_rdy_ctdn		: t_rdy_ctdn;
   signal r_D_wr         : std_logic_vector(7 downto 0);
   signal r_D_wr_stb     : std_logic;

   -- peripheral bookkeeping (as fb_intcon_one_to_many)
   constant C_PIPELINED  : boolean := G_PIPELINE_DEPTH > 1;

   -- not pipelined only
   signal r_dn_A_acked   : std_logic;                                         -- the peripheral has A_ack'd the slot's transaction

   -- pipelined only
   signal r_cnt          : integer range 0 to G_PIPELINE_DEPTH;               -- A_ack'd, not D_ack'd
   signal r_cnt_nz       : std_logic;                                         -- r_cnt /= 0, registered with r_cnt
   signal r_cnt_max      : std_logic;                                         -- r_cnt = G_PIPELINE_DEPTH, registered with r_cnt
   signal r_own_oh       : std_logic_vector(G_PERIPHERAL_COUNT-1 downto 0);

   -- returns from the peripherals, steered by registers
   signal i_dn_A_ack     : std_logic;
   signal i_dn_D_ack     : std_logic;
   signal i_dn_rdy       : std_logic;
   signal i_dn_D_rd      : std_logic_vector(7 downto 0);

begin

   -- --------------------------------------------------------------------------
   -- Decoder interface: one decoder per controller, on its live address
   -- --------------------------------------------------------------------------
   g_dec : for c in G_CONTROLLER_COUNT-1 downto 0 generate
      peripheral_sel_addr_o(c) <= fb_up_c2p_i(c).A;
      peripheral_sel_we_o(c)   <= fb_up_c2p_i(c).we;
      i_cyc(c)                 <= fb_up_c2p_i(c).cyc;
      i_cyc_a_stb(c)           <= fb_up_c2p_i(c).cyc and fb_up_c2p_i(c).A_stb;
end generate;

   i_a_stb_any <= my_or_reduce(i_cyc_a_stb);

   -- --------------------------------------------------------------------------
   -- Arbitration
   -- --------------------------------------------------------------------------
	g_arb:if G_ARB_ROUND_ROBIN generate
		e_arb_rr:entity work.fb_arbiter_roundrobin
		generic map (
			CNT => G_CONTROLLER_COUNT
			)
		port map (
			clk_i 		=> fb_syscon_i.clk,
			rst_i 		=> fb_syscon_i.rst,
			req_i 		=> i_cyc,
         ack_i      => r_arb_ack,
         grant_ix_o => i_arb_grant_ix
			);
	else generate
		e_arb_pri:entity work.fb_arbiter_prior
		generic map (
			CNT => G_CONTROLLER_COUNT
			)
		port map (
			clk_i 		=> fb_syscon_i.clk,
			rst_i 		=> fb_syscon_i.rst,
			req_i 		=> i_cyc,
         ack_i      => r_arb_ack,
         grant_ix_o => i_arb_grant_ix
			);		
	end generate;

   -- the arbiter's choice is only valid while some controller is asking
   i_grant_ix   <= i_arb_grant_ix when r_state = idle and i_a_stb_any = '1' else
                   r_grant_ix;
   i_gnt_c2p    <= fb_up_c2p_i(to_integer(i_grant_ix));
   i_gnt_sel_oh <= peripheral_sel_oh_i(to_integer(i_grant_ix));

   -- --------------------------------------------------------------------------
   -- Downstream: only A_stb is steered, and only from registers
   -- --------------------------------------------------------------------------
   -- Not pipelined: the slot's A_stb goes to the peripheral it is addressed
   -- to (r_sel_oh(k)) until that peripheral A_acks it.
   -- Pipelined: it is forwarded to peripheral k when it is addressed to k
   -- and either nothing is owed, or k is the peripheral owed (r_own_oh(k))
   -- and the count isn't at G_PIPELINE_DEPTH. "Addressed to a peripheral
   -- other than the one owed" is just r_own_oh(k) = '0' when r_sel_oh(k) =
   -- '1': no index compare, and A_stb(k) depends on five registers only.

   g_dn : for k in G_PERIPHERAL_COUNT-1 downto 0 generate
      g_nopipe : if not C_PIPELINED generate
         fb_dn_c2p_o(k).A_stb <= r_full and r_sel_oh(k) and not r_dn_A_acked;
      end generate;
      g_pipe : if C_PIPELINED generate
         fb_dn_c2p_o(k).A_stb <= r_full and r_sel_oh(k) and
                                 (not r_cnt_nz or (r_own_oh(k) and not r_cnt_max));
      end generate;
      fb_dn_c2p_o(k).cyc      <= r_dn_cyc;
      fb_dn_c2p_o(k).A        <= r_A;
      fb_dn_c2p_o(k).we       <= r_we;
      fb_dn_c2p_o(k).D_wr     <= r_D_wr;
      fb_dn_c2p_o(k).D_wr_stb <= r_D_wr_stb;
      fb_dn_c2p_o(k).rdy_ctdn <= r_rdy_ctdn;
	end generate;

   -- --------------------------------------------------------------------------
   -- Returns from the peripherals, AND-OR muxed by registered one-hots
   -- --------------------------------------------------------------------------
   -- Not pipelined: D_ack, rdy and D_rd come from the slot's peripheral
   -- (r_sel_oh, held until D_ack) and only while the slot is full.
   -- Pipelined: from the peripheral owed (r_own_oh).
   p_p2c_mux : process (all)
      variable v_A_ack  : std_logic;
      variable v_D_ack  : std_logic;
      variable v_rdy    : std_logic;
      variable v_D_rd   : std_logic_vector(7 downto 0);
      variable v_ret_oh : std_logic_vector(G_PERIPHERAL_COUNT-1 downto 0);
      variable v_D_en   : std_logic;
	begin
      if C_PIPELINED then
         v_ret_oh := r_own_oh;
         v_D_en   := r_dn_cyc;
      else
         v_ret_oh := r_sel_oh;
         v_D_en   := r_dn_cyc and r_full;
      end if;
      v_A_ack := '0';
      v_D_ack := '0';
      v_rdy   := '0';
      v_D_rd  := (others => '0');
      for k in 0 to G_PERIPHERAL_COUNT-1 loop
         v_A_ack := v_A_ack or (r_sel_oh(k) and fb_dn_p2c_i(k).A_ack);
         v_D_ack := v_D_ack or (v_ret_oh(k) and fb_dn_p2c_i(k).D_ack);
         v_rdy   := v_rdy   or (v_ret_oh(k) and fb_dn_p2c_i(k).rdy);
         v_D_rd  := v_D_rd  or (fb_dn_p2c_i(k).D_rd and (v_D_rd'range => v_ret_oh(k)));
		end loop;
      i_dn_A_ack <= r_dn_cyc and v_A_ack;
      i_dn_D_ack <= v_D_en and v_D_ack;
      i_dn_rdy   <= v_D_en and v_rdy;
      i_dn_D_rd  <= v_D_rd;
	end process;

   g_up : for c in G_CONTROLLER_COUNT-1 downto 0 generate
      fb_up_p2c_o(c).A_ack <= r_up_A_ack and r_grant_oh(c);
      fb_up_p2c_o(c).D_ack <= i_dn_D_ack and r_grant_oh(c);
      fb_up_p2c_o(c).rdy   <= i_dn_rdy   and r_grant_oh(c);
      fb_up_p2c_o(c).D_rd  <= i_dn_D_rd;
	end generate;

   -- --------------------------------------------------------------------------
   -- Grant, slot and bookkeeping
   -- --------------------------------------------------------------------------
   p_state : process (fb_syscon_i)
      variable v_act  : boolean;   -- a grant is held, or taken at this edge
      variable v_free : boolean;   -- the slot can take a new transaction
	begin
		if fb_syscon_i.rst = '1' then
			r_state <= idle;
         r_grant_ix <= (others => '0');
         r_grant_oh <= (others => '0');
         r_arb_ack  <= '0';
         r_dn_cyc   <= '0';
         r_full     <= '0';
         r_up_A_ack <= '0';
         r_A        <= (others => '0');
         r_we       <= '0';
         r_sel_oh   <= (others => '0');
			r_rdy_ctdn <= RDY_CTDN_MIN;
         r_D_wr     <= (others => '0');
         r_D_wr_stb <= '0';
         r_dn_A_acked <= '0';
         r_cnt      <= 0;
         r_cnt_nz   <= '0';
         r_cnt_max  <= '0';
         r_own_oh   <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
         r_arb_ack  <= '0';
         r_up_A_ack <= '0';

         -- take a grant
         v_act := r_state = act;
         if r_state = idle and i_a_stb_any = '1' then
            v_act := true;
            r_state    <= act;
            r_grant_ix <= i_arb_grant_ix;
            r_grant_oh <= (others => '0');
            r_grant_oh(to_integer(i_arb_grant_ix)) <= '1';
            r_arb_ack  <= '1';
            r_dn_cyc   <= '1';
         end if;

         -- slot: A, we and select follow the granted controller whenever the
         -- slot is free (their enable doesn't depend on A_stb); it is marked
         -- full only for an A_stb, which isn't the one just A_ack'd
         if C_PIPELINED then
            -- free on the peripheral's A_ack, and can reload in that clock
            v_free := r_full = '0' or i_dn_A_ack = '1';
            if i_dn_A_ack = '1' then
               r_full <= '0';
            end if;
         else
            -- held until the peripheral's D_ack; its A_ack only drops A_stb
            v_free := r_full = '0';
            if i_dn_A_ack = '1' then
               r_dn_A_acked <= '1';
            end if;
            if i_dn_D_ack = '1' then
               r_full <= '0';
            end if;
         end if;
         if v_free then
            r_A      <= i_gnt_c2p.A;
            r_we     <= i_gnt_c2p.we;
            r_sel_oh <= i_gnt_sel_oh;
         end if;
         if v_act and v_free and i_gnt_c2p.cyc = '1' and i_gnt_c2p.A_stb = '1'
               and r_up_A_ack = '0' then
            r_full       <= '1';
            r_up_A_ack   <= '1';
            r_dn_A_acked <= '0';
         end if;

         -- rdy_ctdn is constant for the granted controller's cyc, and the
         -- grant only changes while downstream cyc is low
         r_rdy_ctdn <= i_gnt_c2p.rdy_ctdn;

         -- write data: registered copy, strobe masked in the clock of the
         -- peripheral's D_ack
         r_D_wr <= i_gnt_c2p.D_wr;
         if v_act then
            r_D_wr_stb <= i_gnt_c2p.cyc and i_gnt_c2p.D_wr_stb and not i_dn_D_ack;
						else
            r_D_wr_stb <= '0';
					end if;

         -- pipelined only: owner and outstanding count. Not pipelined, r_own_oh
         -- is unused; it is still assigned here so it isn't only set by the
         -- asynchronous reset (which synthesis makes into a latch)
         if not C_PIPELINED then
            r_own_oh <= (others => '0');
         end if;
         if C_PIPELINED then
            -- owner follows the slot while nothing is owed
            if r_cnt = 0 then
               r_own_oh <= r_sel_oh;
            end if;

            -- outstanding count: +1 on the peripheral's A_ack, -1 on its D_ack.
            -- r_cnt_nz / r_cnt_max are worked out from the current r_cnt (compares
            -- on registers, in parallel with the A_ack/D_ack muxes), not from the
            -- incremented value, so only the up/down/hold choice follows the muxes.
            if i_dn_A_ack = '1' and i_dn_D_ack = '0' then
               r_cnt    <= r_cnt + 1;
               r_cnt_nz <= '1';
               if r_cnt = G_PIPELINE_DEPTH - 1 then
                  r_cnt_max <= '1';
               else
                  r_cnt_max <= '0';
               end if;
            elsif i_dn_A_ack = '0' and i_dn_D_ack = '1' and r_cnt_nz = '1' then
               r_cnt <= r_cnt - 1;
               if r_cnt >= 2 then
                  r_cnt_nz <= '1';
               else
                  r_cnt_nz <= '0';
               end if;
               r_cnt_max <= '0';
            end if;
         end if;

         -- the granted controller has dropped cyc: end (or abort) the cycle
         if r_state = act and i_cyc(to_integer(r_grant_ix)) = '0' then
				r_state <= idle;
            r_grant_oh <= (others => '0');
            r_dn_cyc   <= '0';
            r_full     <= '0';
            r_up_A_ack <= '0';
            r_D_wr_stb <= '0';
            r_dn_A_acked <= '0';
            r_cnt      <= 0;
            r_cnt_nz   <= '0';
            r_cnt_max  <= '0';
			end if;
		end if;
	end process;

end architecture rtl;

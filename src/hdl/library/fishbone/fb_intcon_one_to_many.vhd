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
-- Create Date:    	06/10/2026
-- Design Name:
-- Module Name:    	one to many Fishbone interconnect
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description: 		pipelined interconnect from a single controller to many
--							peripherals, Oct 2026 Fishbone (A_ack / D_ack)
-- Dependencies: 		fishbone, common, external address decoder (see
--							fb_intcon_pack for the peripheral_sel_* interface)
--
-- Revision:
-- Additional Comments:
--
--   * A_stb is forwarded only to the addressed peripheral, and that
--     peripheral's A_ack is passed back. There is no stall: holding off
--     A_stb (and therefore A_ack) is the back-pressure.
--   * r_cnt counts transactions that have been A_ack'd but not yet D_ack'd,
--     and r_peripheral_sel_ix / r_peripheral_sel_oh record which peripheral
--     owes those D_acks.
--   * An A_stb for a different peripheral is not forwarded until r_cnt
--     reaches zero, so D_acks always return in order, from one peripheral at
--     a time. At most G_MAXOUT transactions may be outstanding.
--   * D_ack, D_rd and rdy come from, and D_wr_stb goes to, the owning
--     peripheral (r_peripheral_sel_oh). With nothing outstanding they use the
--     peripheral currently being strobed, which covers D_ack coincident with
--     A_ack and D_wr_stb coincident with A_stb.
--   * The one-hot select steers the strobes and muxes the returned signals;
--     the index is only used for the "different peripheral" compare.
--   * A, we, D_wr and rdy_ctdn are broadcast to every peripheral.
--   * Dropping cyc aborts the cycle and clears r_cnt.
--
-- A_ack and D_ack stay registered at the peripheral; this block only muxes
-- them, so it adds no latency but does add decode/mux delay to those paths.
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;

entity fb_intcon_one_to_many is
  generic (
    G_PERIPHERAL_COUNT : positive := 4;   -- number of peripherals
    G_MAXOUT           : positive := 15   -- max outstanding transactions
  );
  port (
    fb_syscon_i           : in  fb_syscon_t;

    -- peripheral port connect to controller
    fb_up_c2p_i           : in  fb_con_o_per_i_t;
    fb_up_p2c_o           : out fb_con_i_per_o_t;

    -- controller port connect to peripherals
    fb_dn_c2p_o           : out fb_con_o_per_i_arr(G_PERIPHERAL_COUNT-1 downto 0);
    fb_dn_p2c_i           : in  fb_con_i_per_o_arr(G_PERIPHERAL_COUNT-1 downto 0);

    -- peripheral select interface (see fb_intcon_pack)
    peripheral_sel_addr_o : out std_logic_vector(23 downto 0);
    peripheral_sel_we_o   : out std_logic;
    peripheral_sel_i      : in  unsigned(numbits(G_PERIPHERAL_COUNT)-1 downto 0);  -- selected peripheral index
    peripheral_sel_oh_i   : in  std_logic_vector(G_PERIPHERAL_COUNT-1 downto 0)    -- selected peripheral one-hot
  );
end entity fb_intcon_one_to_many;

architecture rtl of fb_intcon_one_to_many is

  -- registers
  signal r_cnt               : integer range 0 to G_MAXOUT := 0;  -- A_ack'd, not D_ack'd
  signal r_peripheral_sel_ix : unsigned(numbits(G_PERIPHERAL_COUNT)-1 downto 0)
                               := (others => '0');               -- peripheral owing them
  signal r_peripheral_sel_oh : std_logic_vector(G_PERIPHERAL_COUNT-1 downto 0)
                               := (others => '0');               -- same, one-hot

  -- combinatorial
  signal i_hold     : std_logic;    -- don't forward A_stb yet
  signal i_fwd      : std_logic;    -- A_stb forwarded to the selected peripheral
  signal i_src_oh   : std_logic_vector(G_PERIPHERAL_COUNT-1 downto 0);  -- data phase peripheral
  signal i_dvld     : std_logic;    -- i_src_oh may respond
  signal i_sel_a_ack: std_logic;    -- A_ack from the selected peripheral
  signal i_src_d_ack: std_logic;    -- D_ack from the data phase peripheral
  signal i_src_rdy  : std_logic;    -- rdy from the data phase peripheral
  signal i_src_d_rd : std_logic_vector(7 downto 0);  -- D_rd from the data phase peripheral
  signal i_aack     : std_logic;    -- A_ack passed up this clock
  signal i_dack     : std_logic;    -- D_ack passed up this clock

begin

  -- --------------------------------------------------------------------------
  -- Address and write enable out to the external decoder
  -- --------------------------------------------------------------------------
  peripheral_sel_addr_o <= fb_up_c2p_i.A;
  peripheral_sel_we_o   <= fb_up_c2p_i.we;

  -- --------------------------------------------------------------------------
  -- Address phase: forward A_stb unless another peripheral still owes D_acks
  -- or the outstanding limit has been reached
  -- --------------------------------------------------------------------------
  i_hold <= '1' when r_cnt /= 0 and
                     (peripheral_sel_i /= r_peripheral_sel_ix or r_cnt = G_MAXOUT)
            else '0';

  i_fwd  <= fb_up_c2p_i.cyc and fb_up_c2p_i.A_stb and not i_hold;
  i_aack <= i_fwd and i_sel_a_ack;

  fb_up_p2c_o.A_ack <= i_aack;

  -- --------------------------------------------------------------------------
  -- Data phase source: the owner if anything is outstanding, otherwise the
  -- peripheral currently being strobed
  -- --------------------------------------------------------------------------
  i_src_oh <= r_peripheral_sel_oh when r_cnt /= 0 else peripheral_sel_oh_i;
  i_dvld   <= '1' when fb_up_c2p_i.cyc = '1' and (r_cnt /= 0 or i_fwd = '1')
              else '0';

  i_dack <= i_dvld and i_src_d_ack;

  fb_up_p2c_o.D_ack <= i_dack;
  fb_up_p2c_o.rdy   <= i_dvld and i_src_rdy;
  fb_up_p2c_o.D_rd  <= i_src_d_rd;

  -- --------------------------------------------------------------------------
  -- Peripheral to controller muxes, AND-OR from the one-hot selects
  -- --------------------------------------------------------------------------
  p_p2c_mux : process (all)
    variable v_a_ack : std_logic;
    variable v_d_ack : std_logic;
    variable v_rdy   : std_logic;
    variable v_d_rd  : std_logic_vector(7 downto 0);
  begin
    v_a_ack := '0';
    v_d_ack := '0';
    v_rdy   := '0';
    v_d_rd  := (others => '0');
    for k in 0 to G_PERIPHERAL_COUNT-1 loop
      v_a_ack := v_a_ack or (peripheral_sel_oh_i(k) and fb_dn_p2c_i(k).A_ack);
      v_d_ack := v_d_ack or (i_src_oh(k) and fb_dn_p2c_i(k).D_ack);
      v_rdy   := v_rdy   or (i_src_oh(k) and fb_dn_p2c_i(k).rdy);
      v_d_rd  := v_d_rd  or (fb_dn_p2c_i(k).D_rd and (v_d_rd'range => i_src_oh(k)));
    end loop;
    i_sel_a_ack <= v_a_ack;
    i_src_d_ack <= v_d_ack;
    i_src_rdy   <= v_rdy;
    i_src_d_rd  <= v_d_rd;
  end process;

  -- --------------------------------------------------------------------------
  -- Per-peripheral signals. cyc goes to the peripheral being strobed and to
  -- the owner of outstanding transactions; A, we, D_wr and rdy_ctdn are
  -- broadcast.
  -- --------------------------------------------------------------------------
  g_c2p : for k in G_PERIPHERAL_COUNT-1 downto 0 generate
    fb_dn_c2p_o(k).cyc      <= (i_fwd and peripheral_sel_oh_i(k)) or
                               (i_dvld and i_src_oh(k));
    fb_dn_c2p_o(k).A_stb    <= i_fwd and peripheral_sel_oh_i(k);
    fb_dn_c2p_o(k).D_wr_stb <= i_dvld and i_src_oh(k) and fb_up_c2p_i.D_wr_stb;
    fb_dn_c2p_o(k).A        <= fb_up_c2p_i.A;
    fb_dn_c2p_o(k).we       <= fb_up_c2p_i.we;
    fb_dn_c2p_o(k).D_wr     <= fb_up_c2p_i.D_wr;
    fb_dn_c2p_o(k).rdy_ctdn <= fb_up_c2p_i.rdy_ctdn;
  end generate;

  -- --------------------------------------------------------------------------
  -- Outstanding-transaction tracking: +1 on A_ack, -1 on D_ack
  -- --------------------------------------------------------------------------
  process (fb_syscon_i)
  begin
    if rising_edge(fb_syscon_i.clk) then
      if fb_syscon_i.rst = '1' or fb_up_c2p_i.cyc = '0' then
        r_cnt <= 0;
      else
        if i_aack = '1' and i_dack = '0' then
          r_cnt <= r_cnt + 1;
        elsif i_aack = '0' and i_dack = '1' and r_cnt /= 0 then
          r_cnt <= r_cnt - 1;
        end if;

        if i_aack = '1' then
          r_peripheral_sel_ix <= peripheral_sel_i;
          r_peripheral_sel_oh <= peripheral_sel_oh_i;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;

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
-- ----------------------------------------------------------------------


-- Company:             Dossytronics
-- Engineer:            Dominic Beesley
--
-- Create Date:         06/10/2026
-- Design Name:
-- Module Name:         work.sim_fb_per_mem_pipe
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:         A pipelined memory peripheral
-- Dependencies:
--
-- Revision:
-- Additional Comments:
--    Accepted transactions are queued (up to G_DEPTH) and serviced one at a
--    time, in order, from the head of the queue. A_ack is given when a
--    transaction is pushed and is withheld while the queue is full.
--    D_wr_stb is only looked at when the head of the queue is a write.
--
--    The service delay starts when a transaction reaches the head of the
--    queue and depends on whether it is in the same page (top bits above
--    G_PAGE_BITS) as the previous transaction serviced:
--
--    sim_A_ack_hold_i     hold off A_ack while '1'
--    sim_A_ack_dly_i      clocks to delay A_ack after A_stb is seen
--    sim_D_miss_dly_i     clocks to service a transaction in a new page
--    sim_D_hit_dly_i      clocks to service a transaction in the same page
--
--    For writes the service delay runs before D_wr_stb is looked at, so it
--    overlaps any wait for the data.
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;

entity sim_fb_per_mem_pipe is
generic (
      G_SIZE : natural := 8;
      G_VALUE_XOR : std_logic_vector(7 downto 0) := x"00";
      G_DEPTH : positive := 4;
      G_PAGE_BITS : natural := 8
   );
port (

      fb_syscon_i                      : in  fb_syscon_t;

      fb_c2p_i                         : in  fb_con_o_per_i_t;
      fb_p2c_o                         : out fb_con_i_per_o_t;

      sim_A_ack_hold_i                 : in  std_logic := '0';
      sim_A_ack_dly_i                  : in  natural := 0;
      sim_D_miss_dly_i                 : in  natural := 0;
      sim_D_hit_dly_i                  : in  natural := 0

   );

end sim_fb_per_mem_pipe;

architecture rtl of sim_fb_per_mem_pipe is

   type t_mem is array (0 to G_SIZE-1) of std_logic_vector(7 downto 0);

   type t_q_ent is record
      we    : std_logic;
      A     : std_logic_vector(23 downto 0);
   end record;

   type t_q is array (0 to G_DEPTH-1) of t_q_ent;

   function f_mem_init return t_mem is
   variable v_ret : t_mem;
   begin
      for i in 0 to G_SIZE-1 loop
         v_ret(i) := std_logic_vector(to_unsigned(i mod 256, 8)) xor x"FF" xor G_VALUE_XOR;
      end loop;
      return v_ret;
   end function;

   signal r_A_ack    : std_logic := '0';
   signal r_D_ack    : std_logic := '0';
   signal r_D_rd     : std_logic_vector(7 downto 0) := (others => '-');

begin

   fb_p2c_o <= (
         A_ack => r_A_ack,
         rdy => r_D_ack,
         D_ack => r_D_ack,
         D_rd => r_D_rd
      );

   p_per:process(fb_syscon_i)
   variable vr_mem      : t_mem := f_mem_init;
   variable vr_q        : t_q;
   variable vr_head     : natural range 0 to G_DEPTH-1 := 0;
   variable vr_count    : natural range 0 to G_DEPTH := 0;
   variable vr_A_wait   : boolean := false;     -- an A_stb is waiting for its A_ack
   variable vr_A_dly    : natural := 0;         -- clocks left before A_ack
   variable vr_D_busy   : boolean := false;     -- the head is being serviced
   variable vr_D_dly    : natural := 0;         -- clocks left before the head completes
   variable vr_page     : std_logic_vector(23 downto G_PAGE_BITS);
   variable vr_page_vld : boolean := false;
   variable v_ix        : natural;
   begin
      if fb_syscon_i.rst = '1' then

         r_A_ack <= '0';
         r_D_ack <= '0';
         r_D_rd  <= (others => '-');
         vr_count := 0;
         vr_A_wait := false;
         vr_D_busy := false;
         vr_page_vld := false;

      elsif rising_edge(fb_syscon_i.clk) then

         -- acks are single clock pulses
         r_A_ack <= '0';
         r_D_ack <= '0';
         r_D_rd  <= (others => '-');

         if fb_c2p_i.cyc = '0' then

            if vr_count /= 0 then
               report "cyc dropped with " & natural'image(vr_count) & " transactions queued" severity note;
            end if;
            vr_count := 0;
            vr_A_wait := false;
            vr_D_busy := false;
            vr_page_vld := false;

         else

            -- A side: push. r_A_ack is the value from the previous clock,
            -- i.e. '1' when this A_stb is the one being acknowledged now.
            if fb_c2p_i.A_stb = '1' and r_A_ack = '0' then
               if not vr_A_wait then
                  vr_A_wait := true;
                  vr_A_dly := sim_A_ack_dly_i;
               end if;
               if vr_A_dly > 0 then
                  vr_A_dly := vr_A_dly - 1;
               elsif sim_A_ack_hold_i = '0' and vr_count < G_DEPTH then
                  vr_q((vr_head + vr_count) mod G_DEPTH) := (we => fb_c2p_i.we, A => fb_c2p_i.A);
                  vr_count := vr_count + 1;
                  vr_A_wait := false;
                  r_A_ack <= '1';
               end if;
            end if;

            -- D side: service the head
            if vr_count /= 0 then

               if not vr_D_busy then
                  vr_D_busy := true;
                  if vr_page_vld and vr_q(vr_head).A(23 downto G_PAGE_BITS) = vr_page then
                     vr_D_dly := sim_D_hit_dly_i;
                  else
                     vr_D_dly := sim_D_miss_dly_i;
                  end if;
                  vr_page := vr_q(vr_head).A(23 downto G_PAGE_BITS);
                  vr_page_vld := true;
               end if;

               if vr_D_dly > 0 then
                  vr_D_dly := vr_D_dly - 1;
               else
                  v_ix := to_integer(unsigned(vr_q(vr_head).A)) mod G_SIZE;
                  if vr_q(vr_head).we = '0' then
                     r_D_rd <= vr_mem(v_ix);
                     r_D_ack <= '1';
                     vr_D_busy := false;
                     report "read " & to_hex_string(vr_mem(v_ix)) & " from " & to_hex_string(vr_q(vr_head).A) severity note;
                  elsif fb_c2p_i.D_wr_stb = '1' and r_D_ack = '0' then
                     -- r_D_ack = '1' means the D_wr_stb is the one being
                     -- acknowledged now
                     vr_mem(v_ix) := fb_c2p_i.D_wr;
                     r_D_ack <= '1';
                     vr_D_busy := false;
                     report "Written " & to_hex_string(fb_c2p_i.D_wr) & " to " & to_hex_string(vr_q(vr_head).A) severity note;
                  end if;

                  if not vr_D_busy then
                     vr_head := (vr_head + 1) mod G_DEPTH;
                     vr_count := vr_count - 1;
                  end if;
               end if;

            end if;

         end if;
      end if;
   end process;

end rtl;

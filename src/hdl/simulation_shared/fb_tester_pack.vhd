-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2025 Dominic Beesley https://github.com/dominicbeesley
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

-- Company:          Dossytronics
-- Engineer:         Dominic Beesley
-- 
-- Create Date:      4/6/2025
-- Design Name: 
-- Module Name:      fb_tester_pack
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      Fishbone bus component testers
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--                   Procedures for stimulating fishbone components
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;

package fb_tester_pack is

   type t_fbtest_byte_array is array(natural range <>) of std_logic_vector(7 downto 0);

   constant RDY_CTDN_TEST : unsigned(RDY_CTDN_LEN-1 downto 0) := RDY_CTDN_MIN;

   procedure fbtest_wait_reset
   (
      signal syscon_i   : in  fb_syscon_t;
      signal c2p_o      : out fb_con_o_per_i_t
   ); 

    procedure fbtest_single_read(
      signal syscon_i   : in  fb_syscon_t;
      signal p2c_i      : in  fb_con_i_per_o_t;
      signal c2p_o      : out fb_con_o_per_i_t;

      A_i               : in  std_logic_vector(23 downto 0);
      D_o               : out std_logic_vector(7 downto 0);

      A_stb_dl_i        : in  natural := 0 -- no of cycles to delay a_stb after cyc
   );

   procedure fbtest_single_write(
      signal syscon_i   : in  fb_syscon_t;
      signal p2c_i      : in  fb_con_i_per_o_t;
      signal c2p_o      : out fb_con_o_per_i_t;

      A_i                  : in  std_logic_vector(23 downto 0);
      D_i                  : in  std_logic_vector(7 downto 0);

      A_stb_dl_i           : natural := 0;   -- no of cycles to delay a_stb after cyc
      D_stb_dl_i           : natural := 0   -- no of cycles to delay d_stb after a_stb
   );

   procedure fbtest_multi_read(
      signal syscon_i   : in  fb_syscon_t;
      signal p2c_i      : in  fb_con_i_per_o_t;
      signal c2p_o      : out fb_con_o_per_i_t;

         A        : in  std_logic_vector(23 downto 0);
         N        : positive;
         D        : out t_fbtest_byte_array;

         A_stb_dl : natural := 0;       -- no of cycles to delay a_stb after cyc and between cycles

         A_INC    : natural := 1
      );

   procedure fbtest_multi_write(
      signal syscon_i   : in  fb_syscon_t;
      signal p2c_i      : in  fb_con_i_per_o_t;
      signal c2p_o      : out fb_con_o_per_i_t;

         A        : in  std_logic_vector(23 downto 0);
         N        : positive;
         D        : in t_fbtest_byte_array;

         A_stb_dl : natural := 0;       -- no of cycles to delay a_stb after cyc and between cycles
         D_stb_dl : natural := 0;
         A_INC    : natural := 1
      );
end package;

package body fb_tester_pack is


   -- wait for the syscon to come out of reset and set c2p_o to unsel
   procedure fbtest_wait_reset
   (
      signal syscon_i   : in  fb_syscon_t;
      signal c2p_o      : out fb_con_o_per_i_t
   ) is
   variable i:natural;
   begin

      c2p_o <= fb_c2p_unsel;

      if syscon_i.rst /= '1' then
         wait until syscon_i.rst = '1';
      end if;

      wait until syscon_i.rst = '0';

      for i in 0 to 3 loop
         wait until rising_edge(syscon_i.clk);
      end loop;

   end fbtest_wait_reset;

   -- perform a single read of the fishbone bus, return read D
   procedure fbtest_single_read(
      signal syscon_i   : in  fb_syscon_t;
      signal p2c_i      : in  fb_con_i_per_o_t;
      signal c2p_o      : out fb_con_o_per_i_t;

      A_i               : in  std_logic_vector(23 downto 0);
      D_o               : out std_logic_vector(7 downto 0);

      A_stb_dl_i        : in  natural := 0 -- no of cycles to delay a_stb after cyc
   ) is
   variable v_iter: natural;
   variable v_read_done : boolean;
   begin
      
      v_read_done := false;

      wait until rising_edge(syscon_i.clk);

      if (A_stb_dl_i = 0) then
         c2p_o <= (
            cyc         => '1',
            we          => '0',
            A           => A_i,
            A_stb       => '1',
            D_wr        => x"00",
            D_wr_stb    => '0',
            rdy_ctdn    => RDY_CTDN_TEST
         );
      else
         c2p_o <= (
            cyc         => '1',
            we          => '0',
            A           => (others => '-'),
            A_stb       => '0',
            D_wr        => x"00",
            D_wr_stb    => '0',
            rdy_ctdn    => RDY_CTDN_TEST
         );
         for i in 1 to A_stb_dl_i loop
            wait until rising_edge(syscon_i.clk);
         end loop;

         c2p_o.A_stb <= '1';
         c2p_o.A <= A_i;
      end if;

      wait until rising_edge(syscon_i.clk);

      -- wait for A_ack

      v_iter := 0;
      while p2c_i.A_ack /= '1' loop
         wait until rising_edge(syscon_i.clk);
         v_iter := v_iter + 1;
         if v_iter > 100000 then
            report "Failed waiting for A_ack" severity error;
         end if;
      end loop;

      c2p_o.a_stb <= '0';
      c2p_o.a <= (others => '-');

      -- wait for done - may be coincident with A_ack
      v_iter := 0;
      loop
         if p2c_i.d_ack = '1' then
            D_o := p2c_i.D_rd;
            v_read_done := true;
         end if;
         if p2c_i.done = '1' then
            exit;
         end if;
         wait until rising_edge(syscon_i.clk);
         v_iter := v_iter + 1;
         if v_iter > 100000 then
            report "Failed waiting for done/d_ack" severity error;
         end if;
      end loop;

      c2p_o <= fb_c2p_unsel;

      wait until rising_edge(syscon_i.clk);

      if not v_read_done then
         report "Data not read" severity error;
      end if;
   

   end fbtest_single_read;


   procedure fbtest_single_write(
      signal syscon_i   : in  fb_syscon_t;
      signal p2c_i      : in  fb_con_i_per_o_t;
      signal c2p_o      : out fb_con_o_per_i_t;

      A_i                  : in  std_logic_vector(23 downto 0);
      D_i                  : in  std_logic_vector(7 downto 0);

      A_stb_dl_i           : natural := 0;   -- no of cycles to delay a_stb after cyc
      D_stb_dl_i           : natural := 0   -- no of cycles to delay d_stb after a_stb
   ) is
   variable v_iter: natural;
   variable v_had_d_ack : boolean;
   begin

      c2p_o <= fb_c2p_unsel;
      v_had_d_ack := false;

      wait until rising_edge(syscon_i.clk);

      c2p_o.cyc <= '1';
      c2p_o.rdy_ctdn <= RDY_CTDN_TEST;

      v_iter := 0;
      while v_iter < A_stb_dl_i loop
         wait until rising_edge(syscon_i.clk);
         v_iter := v_iter + 1;
      end loop;

      c2p_o.we <= '1';
      c2p_o.A <= A_i;
      c2p_o.A_stb <= '1';

      if D_stb_dl_i = 0 then
         c2p_o.D_wr <= D_i;
         c2p_o.D_wr_stb <= '1';
      else
         c2p_o.D_wr <= (others => '-');
         c2p_o.D_wr_stb <= '0';      
      end if;

      v_iter := 0;
      loop
         wait until rising_edge(syscon_i.clk);
         if p2c_i.A_ack = '1' then
            exit;
         end if;
         v_iter := v_iter + 1;
         if v_iter > 100000 then
            report "Failed waiting for A_ack" severity error;
         end if;
      end loop;

      v_had_d_ack := (c2p_o.D_wr_stb and p2c_i.d_ack) = '1';

      c2p_o.we <= '0';
      c2p_o.A <= (others => '-');
      c2p_o.A_stb <= '0';

      if D_stb_dl_i /= 0 then
         v_iter := 1;
         while v_iter < D_stb_dl_i loop
            wait until rising_edge(syscon_i.clk);
            v_iter := v_iter + 1;
         end loop;
         c2p_o.D_wr <= D_i;
         c2p_o.D_wr_stb <= '1';    
      end if;

      while not v_had_d_ack loop
         wait until rising_edge(syscon_i.clk);
         v_had_d_ack := v_had_d_ack or ((c2p_o.D_wr_stb and p2c_i.d_ack) = '1');
      end loop;

      c2p_o.D_wr <= (others => '-');
      c2p_o.D_wr_stb <= '0';

      -- wait for ack

      v_iter := 0;
      while p2c_i.done /= '1' loop
         wait until rising_edge(syscon_i.clk);
         v_iter := v_iter + 1;
         if v_iter > 100000 then
            report "Failed waiting for ack" severity error;
         end if;
      end loop;

      c2p_o <= fb_c2p_unsel;

      wait until rising_edge(syscon_i.clk);
      
   end fbtest_single_write;

   procedure fbtest_multi_read(
      signal syscon_i   : in  fb_syscon_t;
      signal p2c_i      : in  fb_con_i_per_o_t;
      signal c2p_o      : out fb_con_o_per_i_t;

         A        : in  std_logic_vector(23 downto 0);
         N        : in  positive;
         D        : out t_fbtest_byte_array;

         A_stb_dl : in  natural := 0;       -- no of cycles to delay a_stb after cyc and between cycles

         A_INC    : in  natural := 1
      ) is
   variable v_tx : natural; -- number of a_stb's sent
   variable v_rx : natural; -- number of acks sent
   variable v_wt : natural;
   variable v_tot: natural;
   variable v_wt_A_ack:boolean;
   begin

      c2p_o <= fb_c2p_unsel;

      wait until rising_edge(syscon_i.clk);

      c2p_o.cyc <= '1';
      c2p_o.rdy_ctdn <= RDY_CTDN_MIN;
      c2p_o.we <= '0';

      v_tot := 0;
      v_wt := A_stb_dl;
      v_wt_A_ack := false;
      while v_rx < N loop

         v_tot := v_tot + 1;
         assert v_tot < N * 2000 report "multi read " & to_hex_string(A) & "[" & natural'image(N) & "] took too many cyles" severity error;

         if v_tx < N and v_wt = 0 and not v_wt_A_ack then
            c2p_o.A <= std_logic_vector(unsigned(A) + v_tx);
            c2p_o.A_stb <= '1';
            v_wt_A_ack := true;
            report "THERE" severity note;
         elsif v_wt > 0 then
            v_wt := v_wt -1;
         end if;

         wait until rising_edge(syscon_i.clk);

         if v_wt_A_ack and p2c_i.A_ack = '1' then
            v_wt_A_ack := false;
            c2p_o.A_stb <= '0';
            c2p_o.A <= (others => '-');
            v_wt := A_stb_dl;
            v_tx := v_tx + A_INC;
            report "HERE" severity note;
         end if;


         if p2c_i.D_ack = '1' then
            D(v_rx) := p2c_i.D_rd;
            v_rx := v_rx + 1;
         end if;

      end loop;

      c2p_o <= fb_c2p_unsel;


   end fbtest_multi_read;

   procedure fbtest_multi_write(
      signal syscon_i   : in  fb_syscon_t;
      signal p2c_i      : in  fb_con_i_per_o_t;
      signal c2p_o      : out fb_con_o_per_i_t;

         A        : in  std_logic_vector(23 downto 0);
         N        : positive;
         D        : in t_fbtest_byte_array;

         A_stb_dl : natural := 0;       -- no of cycles to delay a_stb after cyc and between cycles
         D_stb_dl : natural := 0;
         A_INC    : natural := 1
      ) is
   variable v_tx : natural; -- number of a_stb's sent
   variable v_dx : natural; -- number of d_acks recvd
   variable v_wt : natural;
   variable v_wtd: natural;
   variable v_tot: natural;
   variable v_wt_A_ack:boolean;
   variable v_wt_d_ack:boolean;
   begin

      c2p_o <= fb_c2p_unsel;

      wait until rising_edge(syscon_i.clk);

      c2p_o.cyc <= '1';
      c2p_o.rdy_ctdn <= RDY_CTDN_MIN;
      c2p_o.we <= '1';

      v_tot := 0;
      v_wt := A_stb_dl;
      v_wtd:= D_stb_dl + A_stb_dl;
      v_wt_A_ack := false;
      v_wt_d_ack := false;
      while v_dx < N or v_tx < N loop

         v_tot := v_tot + 1;
         assert v_tot < N * 2000 report "multi write " & to_hex_string(A) & "[" & natural'image(N) & "] took too many cyles" severity error;

         if v_tx < N and v_wt = 0 and not v_wt_A_ack then
            c2p_o.A <= std_logic_vector(unsigned(A) + v_tx);
            c2p_o.A_stb <= '1';
            v_wt_A_ack := true;
         elsif v_wt > 0 then
            v_wt := v_wt -1;
         end if;

         if v_dx < N and v_wtd = 0 and not v_wt_d_ack then
            c2p_o.D_wr <= D(v_dx);
            c2p_o.D_wr_stb <= '1';
            v_wt_d_ack := true;
         end if;


         wait until rising_edge(syscon_i.clk);

         if v_wt_A_ack and p2c_i.A_ack = '1' then
            v_wt_A_ack := false;
            c2p_o.A_stb <= '0';
            c2p_o.A <= (others => '-');
            v_wt := A_stb_dl;
            v_tx := v_tx + A_INC;
         end if;

         if v_wt_d_ack and p2c_i.D_ack = '1' then
            v_wt_d_ack := false;
            c2p_o.D_wr_stb <= '0';
            c2p_o.D_wr <= (others => '-');         
            v_wtd:= D_stb_dl;
            v_dx := v_dx + A_INC;
         end if;

      end loop;

      c2p_o <= fb_c2p_unsel;


   end fbtest_multi_write;


end fb_tester_pack;
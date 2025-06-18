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
use ieee.std_logic_misc.all;

library work;
use work.fishbone.all;
use work.common.all;

package fb_tester_pack is

   constant RDY_CTDN_TEST : unsigned(RDY_CTDN_LEN-1 downto 0) := to_unsigned(5, RDY_CTDN_LEN);

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
   variable v_ret : std_logic_vector(7 downto 0);
   begin

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

      -- wait for stall

      v_iter := 0;
      while p2c_i.stall /= '0' loop
         wait until rising_edge(syscon_i.clk);
         v_iter := v_iter + 1;
         if v_iter > 100000 then
            report "Failed waiting for stall" severity error;
         end if;
      end loop;

      c2p_o.a_stb <= '0';
      c2p_o.a <= (others => '-');

      wait until rising_edge(syscon_i.clk);
      -- wait for ack

      v_iter := 0;
      while p2c_i.ack /= '1' loop
         wait until rising_edge(syscon_i.clk);
         v_iter := v_iter + 1;
         if v_iter > 100000 then
            report "Failed waiting for ack" severity error;
         end if;
      end loop;

      D_o := p2c_i.D_rd;

      wait until rising_edge(syscon_i.clk);

      c2p_o <= fb_c2p_unsel;

      wait until rising_edge(syscon_i.clk);
      

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
   begin

      c2p_o <= fb_c2p_unsel;

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
      end if;

      v_iter := 0;
      loop
         wait until rising_edge(syscon_i.clk);
         if p2c_i.stall = '0' then
            exit;
         end if;
         v_iter := v_iter + 1;
         if v_iter > 100000 then
            report "Failed waiting for stall" severity error;
         end if;
      end loop;


      c2p_o.we <= '0';
      c2p_o.A <= (others => '-');
      c2p_o.A_stb <= '0';
      c2p_o.D_wr <= (others => '-');
      c2p_o.D_wr_stb <= '0';

      if D_stb_dl_i /= 0 then
         v_iter := 1;
         while v_iter < D_stb_dl_i loop
            wait until rising_edge(syscon_i.clk);
            v_iter := v_iter + 1;
         end loop;
         c2p_o.D_wr <= D_i;
         c2p_o.D_wr_stb <= '1';    
         wait until rising_edge(syscon_i.clk);
      end if;

      c2p_o.D_wr <= (others => '-');
      c2p_o.D_wr_stb <= '0';

      -- wait for ack

      v_iter := 0;
      while p2c_i.ack /= '1' loop
         wait until rising_edge(syscon_i.clk);
         v_iter := v_iter + 1;
         if v_iter > 100000 then
            report "Failed waiting for ack" severity error;
         end if;
      end loop;

      c2p_o <= fb_c2p_unsel;

      wait until rising_edge(syscon_i.clk);
      
   end fbtest_single_write;


end fb_tester_pack;
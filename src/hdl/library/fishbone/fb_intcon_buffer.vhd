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

-- Company:          Dossytronics
-- Engineer:         Dominic Beesley
-- 
-- Create Date:      07/10/2026
-- Design Name: 
-- Module Name:      fishbone bus - inter-stage buffer
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      A fishbone interconnect that sits between a controller
--                   and a peripheral and registers signals to assist in timing
--                   closure where there are problems with long paths.
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--                   The buffer will add at 0, 1 or 2 clock cycles of 
--                   latency depending on the G_REG_C2P and G_REG_P2C settings.
--                   * When G_REG_C2P is true the cyc, A/stb, we, D_wr and 
--                     D_wr_stb are registered
--                   * When G_REG_P2C is true the D_rd, D_ack and rdy signals 
--                     are registered
--                   * when G_REG_C2P is true the return A_ack signal is 
--                     synthesized locally
--                   * if neither are true the buffer just passes through with
--                     no registers or delays
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;

entity fb_intcon_buffer is
   generic (
      G_REG_C2P            : boolean; -- insert a set of registers to the c2p signals
      G_REG_P2C            : boolean  -- insert a set of registers in the p2c signals
   );
   port(

      fb_syscon_i          : in  fb_syscon_t;

      -- upstream peripheral port connect to controller
      fb_up_c2p_i          : in  fb_con_o_per_i_t;
      fb_up_p2c_o          : out fb_con_i_per_o_t;

      -- downstream controller port connect to peripheral
      fb_dn_c2p_o          : out fb_con_o_per_i_t;
      fb_dn_p2c_i          : in  fb_con_i_per_o_t

   );
end fb_intcon_buffer;

architecture rtl of fb_intcon_buffer is

   signal   r_full         : std_logic;

   signal   r_up_A_ack     : std_logic;
   signal   r_up_D_ack     : std_logic;
   signal   r_up_rdy       : std_logic;
   signal   r_up_D_rd      : std_logic_vector(7 downto 0);

   signal   r_dn_cyc       : std_logic;
   signal   r_dn_A         : std_logic_vector(23 downto 0);
   signal   r_dn_we        : std_logic;
   signal   r_dn_D_wr      : std_logic_vector(7 downto 0);
   signal   r_dn_D_wr_stb  : std_logic;
   signal   r_dn_rdy_ctdn  :  t_rdy_ctdn;

   signal   i_d_wr_stb_mask: std_logic;

begin
   
   -- mask the d_wr_stb that is passed on depending on which stages are buffered
   i_d_wr_stb_mask <=   ((not fb_dn_p2c_i.D_ack) or not b2s(G_REG_C2P))
                        and 
                        ((not r_up_D_ack) or not b2s(G_REG_P2C));


   p_stage : process(fb_syscon_i)
   variable v_free : boolean;
   begin
      if fb_syscon_i.rst = '1' then
         r_full <= '0'; 
         r_up_A_ack <= '0'; 
         r_dn_cyc <= '0';
         r_dn_D_wr_stb <= '0'; 
         r_up_D_ack <= '0'; 
         r_up_rdy <= '0';
      elsif rising_edge(fb_syscon_i.clk) then
         r_up_A_ack <= '0';
         r_dn_rdy_ctdn <= fb_up_c2p_i.rdy_ctdn;
         if fb_up_c2p_i.cyc = '0' then
            r_full <= '0'; 
            r_dn_cyc <= '0'; 
            r_dn_D_wr_stb <= '0';
            r_up_D_ack <= '0'; 
            r_up_rdy <= '0';
         else
            r_dn_cyc <= '1';
            -- address side: depth-1 slot, reloadable in the clock it empties
            v_free := r_full = '0' or fb_dn_p2c_i.A_ack = '1';
            if fb_dn_p2c_i.A_ack = '1' then
               r_full <= '0';
            end if;
            if v_free and fb_up_c2p_i.A_stb = '1' and r_up_A_ack = '0' then
               r_full <= '1'; 
               r_dn_A <= fb_up_c2p_i.A; 
               r_dn_we <= fb_up_c2p_i.we;
               r_up_A_ack <= '1';
            end if;
            -- write data: registered copy, both stale clocks masked
            r_dn_D_wr_stb  <= fb_up_c2p_i.D_wr_stb and i_d_wr_stb_mask;
            r_dn_D_wr      <= fb_up_c2p_i.D_wr;
            -- return path: D_ack, rdy and D_rd registered together
            r_up_D_ack     <= fb_dn_p2c_i.D_ack and r_dn_cyc;
            r_up_rdy       <= fb_dn_p2c_i.rdy   and r_dn_cyc;
            r_up_D_rd      <= fb_dn_p2c_i.D_rd;
         end if;
      end if;
   end process;

   p_c2p:process(all)
   begin
      if G_REG_C2P then
         fb_dn_c2p_o <= (
            cyc            => r_dn_cyc,
            we             => r_dn_we,
            A              => r_dn_A,
            A_stb          => r_full,
            D_wr           => r_dn_D_wr,
            D_wr_stb       => r_dn_D_wr_stb,
            rdy_ctdn       => r_dn_rdy_ctdn
         );
      else
         fb_dn_c2p_o <= fb_up_c2p_i;
         fb_dn_c2p_o.D_wr_stb <= fb_up_c2p_i.D_wr_stb and i_d_wr_stb_mask;
      end if;
   end process;

   p_p2c:process(all)
   begin
      if G_REG_P2C then
         if G_REG_C2P then
            fb_up_p2c_o <= (
               A_ack          => r_up_A_ack,
               D_rd           => r_up_D_rd,
               D_ack          => r_up_D_ack,
               rdy            => r_up_rdy
            );
         else
            fb_up_p2c_o <= (
               A_ack          => fb_dn_p2c_i.A_ack,
               D_rd           => r_up_D_rd,
               D_ack          => r_up_D_ack,
               rdy            => r_up_rdy
            );
         end if;
      elsif G_REG_C2P then
         fb_up_p2c_o <= (
            A_ack          => r_up_A_ack,
            D_rd           => fb_dn_p2c_i.D_rd,
            D_ack          => fb_dn_p2c_i.D_ack and r_dn_cyc,
            rdy            => fb_dn_p2c_i.rdy and r_dn_cyc
         );
      else
         fb_up_p2c_o <= fb_dn_p2c_i;
      end if;

   end process;

   

end rtl;

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
-- Create Date:      16/04/2019
-- Design Name: 
-- Module Name:      fb_mem
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      A fishbone wrapper for the blitter/cpu board's SRAM / EEPROM
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;

entity fb_mem is
   generic (
      SIM                           : boolean := false;                    -- skip some stuff, i.e. slow sdram start up
      G_SWRAM_SLOT                  : natural := 1;                        -- when set address range $60 0000 - $7F 0000 goes to this MEM_nCE
                                                                           --  defaults to 1 for min_04 on rev.2
      G_FAST_IS_10                  : boolean := false;                    -- when true run RAM(1..3) at 10ns
      G_SLOW_IS_45                  : boolean := false;                    -- when true run BB RAM at 45ns else 55ns    
      G_FLASH_IS_45                 : boolean := false                     -- when true run Flash at 45ns else 55ns
   );
   port(


      -- 2M RAM/256K ROM bus
      MEM_A_o                       : out    std_logic_vector(20 downto 0);
      MEM_D_io                      : inout  std_logic_vector(7 downto 0);
      MEM_nOE_o                     : out    std_logic;
      MEM_nWE_o                     : out    std_logic;
      MEM_ROM_nCE_o                 : out    std_logic;
      MEM_RAM_nCE_o                 : out    std_logic_vector(3 downto 0);

      -- fishbone signals

      fb_syscon_i                   : in     fb_syscon_t;
      fb_c2p_i                      : in     fb_con_o_per_i_t;
      fb_p2c_o                      : out    fb_con_i_per_o_t;

      debug_mem_a_stb_o             : out    std_logic

   );
end fb_mem;

architecture rtl of fb_mem is

   type     state_mem_t is (idle, wait_wr_stb, wait_rd, wait_wr);

   signal   state       : state_mem_t;

   signal   r_rdy_ctdn  :  t_rdy_ctdn;
   signal   r_rdy       :  std_logic;
   signal   r_D_rd      :  std_logic_vector(7 downto 0);
   signal   r_A_ack     :  std_logic;
   signal   r_D_ack     :  std_logic;

   signal   r_cur_A     :  std_logic_vector(23 downto 21);
   signal   r_cur_we    :  std_logic;


   signal   r_D_wr      :  std_logic_vector(7 downto 0);
   signal   r_D_wr_nOE  :  std_logic;

begin

   debug_mem_a_stb_o <= fb_c2p_i.a_stb;

   fb_p2c_o.A_ack    <= r_A_ack;
   fb_p2c_o.D_rd     <= r_D_rd;
   fb_p2c_o.rdy      <= r_rdy;
   fb_p2c_o.D_ack    <= r_D_ack;

   MEM_D_io <= r_D_wr when r_D_wr_nOE = '0' else (others => 'Z');

   p_state:process(fb_syscon_i)
   variable vr_rdy_ctdn : t_rdy_ctdn;
   variable v_allow_next : boolean;
   begin

      if fb_syscon_i.rst = '1' then
         state <= idle;
         MEM_A_o <= (others => '0');
         r_D_wr <= (others => '0');
         r_D_wr_nOE <= '1';
         MEM_nOE_o <= '1';
         MEM_nWE_o <= '1';
         MEM_RAM_nCE_o <= (others => '1');
         MEM_ROM_nCE_o <= '1';
         vr_rdy_ctdn := RDY_CTDN_MAX;
         r_rdy_ctdn <= RDY_CTDN_MIN;
         r_D_ack <= '0';
         r_A_ack <= '0';
         r_rdy <= '0';
         r_cur_A <= (others => '0');
         r_cur_we <= '0';
      elsif rising_edge(fb_syscon_i.clk) then

         v_allow_next := false;
         r_A_ack <= '0';
         r_D_ack <= '0';

         case state is
            when idle =>
               MEM_A_o <= (others => '0');
               r_D_wr_nOE <= '1';
               MEM_nOE_o <= '1';
               MEM_nWE_o <= '1';
               MEM_RAM_nCE_o <= (others => '1');
               MEM_ROM_nCE_o <= '1';               
               r_rdy <= '0';
               vr_rdy_ctdn := RDY_CTDN_MAX;

               v_allow_next := true;

            when wait_wr_stb =>
               if fb_c2p_i.D_wr_stb = '1' and r_D_ack = '0' then
                  r_D_wr_nOE <= '0';
                  r_D_wr <= fb_c2p_i.D_wr;
                  r_D_ack <= '1';
                  r_rdy <= '1';
                  state <= wait_wr;
               end if;
            when wait_rd =>
               if vr_rdy_ctdn <= r_rdy_ctdn then
                  r_rdy <= '1';
               end if;

               if vr_rdy_ctdn = 0 then
                  state <= idle;
                  r_D_ack <= '1';
                  r_D_rd <= MEM_D_io;
                  v_allow_next := true;
               else
                  vr_rdy_ctdn := vr_rdy_ctdn - 1;
               end if;
            when wait_wr =>
               if vr_rdy_ctdn = 0 then
                  state <= idle;
                  MEM_nWE_o <= '1';
               else
                  vr_rdy_ctdn := vr_rdy_ctdn - 1;
               end if;
            when others =>
               state <= idle;
         end case;

         if v_allow_next then
            if fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' and r_A_ack = '0' 
               and (
                  (fb_c2p_i.A(23 downto 21) = r_cur_A and fb_c2p_i.we = r_cur_we)
                  or state = idle) then
               r_A_ack <= '1';
               r_rdy_ctdn <= fb_c2p_i.rdy_ctdn;

               r_cur_A <= fb_c2p_i.A(23 downto 21);
               r_cur_we <= fb_c2p_i.we;
               MEM_nWE_o <= not fb_c2p_i.we;
               MEM_nOE_o <= fb_c2p_i.we;
               MEM_A_o <= fb_c2p_i.A(20 downto 0);
               if fb_c2p_i.we = '1' then
                  r_D_wr_nOE <= '0';
                  r_D_wr <= fb_c2p_i.D_wr;
               end if;

               -- work out which memory chip and what speed
               if fb_c2p_i.A(23) = '1' then
                  MEM_ROM_nCE_o <= '0';
                  IF G_FLASH_IS_45 then
                     vr_rdy_ctdn := to_unsigned(5, RDY_CTDN_LEN);
                  else
                     vr_rdy_ctdn := to_unsigned(7, RDY_CTDN_LEN);
                  end if;
               elsif fb_c2p_i.A(22 downto 21) = "11" then -- BBRAM
                  MEM_RAM_nCE_o(G_SWRAM_SLOT) <= '0';
                  if G_SWRAM_SLOT = 0 then
                     -- slow BB RAM...how slow?
                     if G_SLOW_IS_45 then
                        vr_rdy_ctdn := to_unsigned(5, RDY_CTDN_LEN);
                     else
                        vr_rdy_ctdn := to_unsigned(7, RDY_CTDN_LEN);
                     end if;
                  elsif G_FAST_IS_10 then
                     vr_rdy_ctdn := to_unsigned(1, RDY_CTDN_LEN);
                  else
                     vr_rdy_ctdn := to_unsigned(2, RDY_CTDN_LEN);
                  end if;
               else
                  -- ram at 0..$5F FFFF maps
                  MEM_RAM_nCE_o(to_integer(unsigned(fb_c2p_i.A(22 downto 21)))+1) <= '0';
                  if G_FAST_IS_10 then
                     vr_rdy_ctdn := to_unsigned(1, RDY_CTDN_LEN);
                  else
                     vr_rdy_ctdn := to_unsigned(2, RDY_CTDN_LEN);
                  end if;

               end if;

               if fb_c2p_i.we = '0' then                    
                  state <= wait_rd;
               else
               if fb_c2p_i.D_wr_stb = '1' and r_D_ack = '0' then
                  r_D_wr_nOE <= '0';
                  r_D_wr <= fb_c2p_i.D_wr;
                  r_D_ack <= '1';
                  r_rdy <= '1';
                     state <= wait_wr;
                  else
                     state <= wait_wr_stb;
                  end if;
               end if;                    
            end if;

         end if;

         if r_D_ack = '1' then
            r_rdy <= '0';
         end if;

         if fb_c2p_i.cyc = '0' then
            r_D_ack <= '0';
            r_rdy   <= '0';
            if state /= wait_wr then   -- a D_ack'd write must complete its nWE pulse
               state <= idle;
            end if;
         end if;
      end if;
   end process;


end rtl;
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
-- Module Name:      A clock DLL for synchronising with the 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      A digital PLL to synchronise a 2MHz/1MHz clock with a 
--                   BBC/ELK/Master motherboard (blitter) or 1MHz bus (Hoglet)
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
use work.mk3blit_pack.all;

entity fb_sys_clock_dll is
   generic (
      SIM                              : boolean := false;                    -- skip some stuff, i.e. slow sdram start up
      CLOCKSPEED                       : natural;

      NEW_EDGE_META                    : natural := 2;
      NEW_EDGE_LENDIV2                 : natural := 2;
      NEW_EDGE_EXTRA                   : natural := 2;
      NEW_LOCK_RANGE                   : natural := 2;

      G_2M_DATA_SETUP                  : natural := 2 --1 + 50*128/1000 
                                       -- however we need to subtract cycles for phi0-phi2 and a bit for jitter
                                       -- 3 seems to work, 2 is safe!
                                       -- according to spec there should be at least 50ns (or 70?) before phi2!

   );
   port(

      cfg_sys_type_i                   : in     sys_type;

      fb_syscon_i                      : in     fb_syscon_t;

      sys_phi2_i                       : in     std_logic;                    -- SYS_CLK_E, phi0 from motherboard used for timing generation or 1MHzE for 1M bus devices
      
      sys_slow_cyc_i                   : in     std_logic;                    -- indicates a slow cycle generated from the SYS address

      dbg_lock_o                       : out    std_logic;
      dbg_fast_o                       : out    std_logic;
      dbg_slow_o                       : out    std_logic;
      dbg_cycle_o                      : out    std_logic;

      sys_dll_lock_o                   : out    std_logic;

      sys_rdyctdn_o                    : out    unsigned(RDY_CTDN_LEN-1 downto 0);

      sys_cyc_start_clken_o            : out    std_logic;                    -- fires towards the start of the cycle 
                                                                              -- - in time to register an address on 
                                                                              -- the SYS bus that allows the motherboard 
                                                                              -- clock stretching logic to propagate
      sys_cyc_end_clken_o              : out    std_logic                     -- fires at the end of a cycle aligned with the
                                                                              -- end of phi0/2

   );
end fb_sys_clock_dll;

architecture rtl of fb_sys_clock_dll is

   -- phi2 dll and sub-clock gen

   signal   r_new_oh_ring_clock : std_logic_vector(CLOCKSPEED/2 downto 0) := (0 => '1', others => '0')
                                                                        ;  -- note this is one longer than needed for 
                                                                           -- an extra position when stretching
   signal   r_ctdn : unsigned(RDY_CTDN_LEN-1 downto 0);

   signal   r_new_dll_lock    : std_logic;
   signal   r_new_dll_fast    : std_logic;
   signal   r_new_dll_slow    : std_logic;

   signal   r_new_edge_dly    : std_logic_vector((NEW_EDGE_META + NEW_EDGE_LENDIV2*2)-1 downto 0);
   signal   i_new_edge_clken  : std_logic;
   signal   r_new_cycle_dly   : std_logic_vector((NEW_EDGE_META + NEW_EDGE_LENDIV2+NEW_LOCK_RANGE+1) downto 0);
   signal   r_new_cycle_clken : std_logic;

   signal   r_CLK_E_toggle             : std_logic := '0'; -- toggles on clk E fall in (after META delay)
   signal   i_v_n2mcycles_stretch      : unsigned(1 downto 0);

   signal   i_start_clken_nostretch    : std_logic;
   signal   i_2M_clken                 : std_logic;   -- 2MHz clocken as phi0 goes low
   signal   i_notslo                   : std_logic;

   -- used in stretched sys cycles to count number of 2M cycles elapsed since start of this stretched cycle
   signal   r_long_1M_cyc              : std_logic := '0';                    -- for SYS devices only
   signal   r_2Mcycle                  : unsigned(1 downto 0)  := (others => '0');
                                                                              -- counts number of 2m cycles since last 
                                                                              -- fast cycles per 1m cycle
begin

   -- clock sizing assertions
   -- must give enough even resolution for a 16 MHz clock i.e. be divisible by 32
   assert CLOCKSPEED mod 32 = 0 report "main fishbone clock must be a multiple of 32 MHz" severity error;

   i_start_clken_nostretch    <= r_new_oh_ring_clock(4 + ((CLOCKSPEED * 140) / 1000)) when cfg_sys_type_i = SYS_ELK else
                                 r_new_oh_ring_clock(((CLOCKSPEED * 140) / 1000));

   dbg_slow_o <= r_new_dll_slow;
   dbg_fast_o <= r_new_dll_fast;
   dbg_lock_o <= r_new_dll_lock;
   dbg_cycle_o <= r_new_cycle_clken;

   sys_cyc_end_clken_o    <=  i_new_edge_clken when cfg_sys_type_i = SYS_ELK else
                              i_2M_clken and i_notslo;
   sys_cyc_start_clken_o  <= i_start_clken_nostretch and not sys_phi2_i when cfg_sys_type_i = SYS_ELK else
                             i_start_clken_nostretch and i_notslo;

   sys_dll_lock_o <= '1' when cfg_sys_type_i = SYS_ELK else
                      r_new_dll_lock;


   p_2M_clken:process(r_new_oh_ring_clock)
   variable J:integer;
   variable x:std_logic;
   begin
      J := (CLOCKSPEED/2)-1;
      x := '0';
      while J < r_new_oh_ring_clock'high loop
         x := x or r_new_oh_ring_clock(J);
         J := J + CLOCKSPEED/2;
      end loop;
      i_2M_clken <= x;
   end process;


-----------------------------------------------------------------
-- NEW clock / dll
-----------------------------------------------------------------

   p_new_oh_clock_cycle:process(fb_syscon_i.clk)
   begin
      if rising_edge(fb_syscon_i.clk) then
         if r_new_dll_lock = '0' and i_new_edge_clken = '1' then
            r_new_oh_ring_clock <= ((NEW_EDGE_META + NEW_EDGE_LENDIV2+2) => '1', others => '0');            
         else
            r_new_oh_ring_clock(r_new_oh_ring_clock'high downto 2) <= r_new_oh_ring_clock(r_new_oh_ring_clock'high-1 downto 1);           
            if r_new_dll_slow = '1' then 
               if r_new_oh_ring_clock(0) = '0' then -- skip first position unless it is current
                  r_new_oh_ring_clock(0) <= '0';
                  r_new_cycle_clken <= 
                     (r_new_oh_ring_clock(r_new_oh_ring_clock'high) and not r_new_oh_ring_clock(1))
                     or r_new_oh_ring_clock(r_new_oh_ring_clock'high-1);
                  r_new_oh_ring_clock(1) <= 
                     (r_new_oh_ring_clock(r_new_oh_ring_clock'high) and not r_new_oh_ring_clock(1))
                     or r_new_oh_ring_clock(r_new_oh_ring_clock'high-1);
               end if;
            elsif r_new_dll_fast = '1' then
               r_new_oh_ring_clock(0) <= r_new_oh_ring_clock(r_new_oh_ring_clock'high);
               r_new_cycle_clken <= r_new_oh_ring_clock(r_new_oh_ring_clock'high);
               r_new_oh_ring_clock(1) <= r_new_oh_ring_clock(0);
            else
               r_new_oh_ring_clock(0) <= 
                  (r_new_oh_ring_clock(r_new_oh_ring_clock'high) and not r_new_oh_ring_clock(0))
                  or r_new_oh_ring_clock(r_new_oh_ring_clock'high-1);
               r_new_cycle_clken <= 
                  (r_new_oh_ring_clock(r_new_oh_ring_clock'high) and not r_new_oh_ring_clock(0))
                  or r_new_oh_ring_clock(r_new_oh_ring_clock'high-1);            
               r_new_oh_ring_clock(1) <= r_new_oh_ring_clock(0);              
            end if;
         end if;

         r_new_cycle_dly <= r_new_cycle_dly(r_new_cycle_dly'high-1 downto 0) & r_new_cycle_clken;
      end if;
   end process;

   p_new_edge:process(fb_syscon_i.clk)
   begin
      if rising_edge(fb_syscon_i.clk) then
         r_new_edge_dly(r_new_edge_dly'high downto 1) <= r_new_edge_dly(r_new_edge_dly'high-1 downto 0);
         r_new_edge_dly(0) <= sys_phi2_i;
      end if;
   end process;

   p_new_edge_detect:process(r_new_edge_dly)
   variable v_edge:std_logic;
   begin
      v_edge := '1';
      for I in r_new_edge_dly'high downto r_new_edge_dly'high-NEW_EDGE_LENDIV2+1 loop
         if r_new_edge_dly(I) /= '1' then
            v_edge := '0';
         end if;
      end loop;
      for I in r_new_edge_dly'high-NEW_EDGE_LENDIV2 downto r_new_edge_dly'high-(NEW_EDGE_LENDIV2*2)+1 loop
         if r_new_edge_dly(I) /= '0' then
            v_edge := '0';
         end if;
      end loop;
      i_new_edge_clken <= v_edge;
   end process;

   p_clk_e_tgl:process(fb_syscon_i.clk)
   begin
      if rising_edge(fb_syscon_i.clk) then
         if i_new_edge_clken = '1' then
            r_CLK_E_toggle <= not r_CLK_E_toggle;
         end if;
      end if;
   end process;

   p_new_dll:process(fb_syscon_i.clk)
   variable v_lock : std_logic := '0';
   variable v_slow : std_logic := '0';
   variable v_fast : std_logic := '0';
   begin

      if rising_edge(fb_syscon_i.clk) then
         
         if i_new_edge_clken = '1' then
            v_lock := '0';
            -- a SYS_E negative edge happened NEW_EDGE_META + NEW_EDGE_LENDIV2 cycles ago
            -- check against the delayed lock clock cycle to see if the cycle is in range
            -- and / or slow/fast
            for I in -NEW_LOCK_RANGE to NEW_LOCK_RANGE loop
               if r_new_cycle_dly(NEW_EDGE_META + NEW_EDGE_LENDIV2 + I) = '1' then
                  v_lock := '1';
                  if I < 0 then
                     v_fast := '0';
                     v_slow := '1';
                  elsif I = 0 then
                     v_fast := '0';
                     v_slow := '0';
                  else
                     v_fast := '1';
                     v_slow := '0';
                  end if;
               end if;
            end loop;

            r_new_dll_lock <= v_lock;
            r_new_dll_fast <= v_fast;
            r_new_dll_slow <= v_slow;
         elsif r_new_oh_ring_clock(2) = '1' then -- reset fast slow near start of cycle
            r_new_dll_fast <= '0';
            r_new_dll_slow <= '0';
         end if;
      end if;

   end process;


   p_detect_long_1Mcyc:process(fb_syscon_i)
   begin
      if rising_edge(fb_syscon_i.clk) then
         if r_new_oh_ring_clock(3 * CLOCKSPEED / 8) = '1' and unsigned(r_2Mcycle) = 0 then -- middle of where phi2 would be unless stretched cycle
            if sys_phi2_i = '1' then
               r_long_1M_cyc <= '0'; 
            else
               r_long_1M_cyc <= '1'; 
            end if;
         end if;
      end if;
   end process;


   i_v_n2mcycles_stretch 
      <= to_unsigned(0, i_v_n2mcycles_stretch'length) when sys_slow_cyc_i = '0' else
         to_unsigned(2, i_v_n2mcycles_stretch'length) when r_long_1M_cyc = '1' else
         to_unsigned(1, i_v_n2mcycles_stretch'length);

   p_fin:process(fb_syscon_i.clk)
   variable v_prev_phi0_toggle   : std_logic := '0';
   begin
      if rising_edge(fb_syscon_i.clk) then
         if r_new_oh_ring_clock((CLOCKSPEED/4)-2) = '1' then -- middle of 2m cycle, increment counter or reset
            if v_prev_phi0_toggle /= r_CLK_E_toggle then
               v_prev_phi0_toggle := not v_prev_phi0_toggle;
               r_2Mcycle <= (others => '0');
            else
               r_2Mcycle <= r_2Mcycle + 1;
            end if;
         end if;
      end if;
   end process;

   p_ctdn:process(fb_syscon_i)
   begin
      if fb_syscon_i.rst = '1' then
         r_ctdn <= (others => '1');
      elsif rising_edge(fb_syscon_i.clk) then
         if cfg_sys_type_i = SYS_ELK then
            if i_start_clken_nostretch then
               r_ctdn <= RDY_CTDN_MAX;
            elsif i_new_edge_clken = '1' then
               r_ctdn <= RDY_CTDN_MIN;
            end if;
         else
            if i_2M_clken = '1' then
               r_ctdn <= to_unsigned((CLOCKSPEED / 2) - G_2M_DATA_SETUP, r_ctdn'length);
            elsif r_ctdn > 0 then
               r_ctdn <= r_ctdn - 1;
            end if;           
         end if;
      end if;

   end process;


   sys_rdyctdn_o <=
         r_ctdn when cfg_sys_type_i = SYS_ELK else
         RDY_CTDN_MAX when unsigned(r_2Mcycle) /= i_v_n2mcycles_stretch else
         r_ctdn when r_ctdn <= RDY_CTDN_MAX else
         RDY_CTDN_MAX;           

   i_notslo <=
         '0' when unsigned(r_2Mcycle) /= i_v_n2mcycles_stretch else
         '1';



end rtl;
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
-- Create Date:      9/6/2025
-- Design Name: 
-- Module Name:      fb_tester_pack
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      Control module for the peripherals mux on the c20k
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--                   This is intended to work in the Blitter and BeebFPGA projects
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.common.all;

entity c20k_peripherals_mux_ctl is
generic (
      G_FAST_CLOCKSPEED    : natural := 128000000;
      G_BEEBFPGA           : boolean := false
   );
port (

   -- clocks in   
   clk_fast_i              : in     std_logic;

   -- clock ens out in fast clock domain
   mhz1E_clken_o           : out    std_logic;                       -- last fast cycle of 1MHz enable
   mhz2E_clken_o           : out    std_logic;                       -- last cycle of cycle stretched 2MHzE
                                                                     -- coincident with clken_mhz1E_clken_i

   -- state control in
   reset_i                 : in     std_logic;                       -- reset signal
                                                                     -- this can be a single fast clock long and 
                                                                     -- will start a new bus cycle on the next fast
                                                                     -- clock

   -- address and cycle selection from core
   -- this needs to be ready before the ALE phase
   sys_A_en                : in     std_logic;                       -- ignore cycle when '0'
   sys_A_i                 : in     std_logic_vector(15 downto 0);   -- this will be decoded to a peripheral
   sys_RnW_i               : in     std_logic;

   -- address and cycle selection back to core
   addr_ack_clken_o        : out    std_logic;                       -- clken for an address being accepted 
                                                                     -- from the core into this module

   -- data and inputs back from bus at end of cycle
   sys_D_rd                : out    std_logic_vector(7 downto 0);    -- data back from peripherals
   sys_D_rd_clken          : out    std_logic;                       -- read data valid

   

   -- mux clock outputs
   mux_mhz1E_clk           : out    std_logic;                        -- 1MHzE clock for main board
   mux_mhz2E_clk           : out    std_logic;                        -- 2MHzE clock for main board - cycle stretched

   -- mux control outputs


   mux_nALE_o              : out    std_logic;
   mux_D_nOE_o             : out    std_logic;
   mux_I0_nOE_o            : out    std_logic;
   mux_I1_nOE_o            : out    std_logic;
   mux_O0_nOE_o            : out    std_logic;
   mux_O1_nOE_o            : out    std_logic;

   -- mux multiplexed signals bus
   
   mux_bus_io              : inout  std_logic_vector(7 downto 0)


);
end c20k_peripherals_mux_ctl;

architecture rtl of c20k_peripherals_mux_ctl is
   
   constant C_CLKS_MHZ2          : natural := G_FAST_CLOCKSPEED / 4000000;
   constant C_CLKS_MHZ2_HALF     : natural := C_CLKS_MHZ2 / 2;

   constant C_CTR2_LENGTH        : natural := numbits(C_CLKS_MHZ2 - 1);

   --imaginary 32MHz slices within a 2MHz cycle
   constant C_32_D_hold          : natural := 1;
   constant C_32_ALE             : natural := 2;
   constant C_32_O0              : natural := 3;
   constant C_32_I0              : natural := 4;
   constant C_32_O1              : natural := 5;
   constant C_32_I1              : natural := 6;
   constant C_32_D_write         : natural := 10;
   constant C_32_D_read          : natural := 14;

   function C_F_MUL return natural is
   begin
      if G_BEEBFPGA then
         return 3;
      else
         return 4;
      end if;
   end function;

   -- above 32 slices translated to fast clock 
   constant C_F_D_hold           : natural := C_F_MUL * C_32_D_hold;
   constant C_F_ALE              : natural := C_F_MUL * C_32_ALE;
   constant C_F_O0               : natural := C_F_MUL * C_32_O0;
   constant C_F_I0               : natural := C_F_MUL * C_32_I0;
   constant C_F_O1               : natural := C_F_MUL * C_32_O1;
   constant C_F_I1               : natural := C_F_MUL * C_32_I1;
   constant C_F_D_write          : natural := C_F_MUL * C_32_D_write;
   constant C_F_D_read           : natural := C_F_MUL * C_32_D_read;

   signal r_mhz2_ctdn            : unsigned(C_CTR2_LENGTH-1 downto 0) := to_unsigned(0, C_CTR2_LENGTH);
 
   signal r_mhz1E_clken          : std_logic := '0';
   signal r_mhz2int_clken        : std_logic := '0';        -- not cycle stretched
   signal r_mhz2int_rise_clken   : std_logic := '0';        -- not cycle stretched

   signal r_mhz1E_clk            : std_logic := '0';
   signal r_mhz2E_clk            : std_logic := '0';

   signal i_bbc_slow_cyc         : std_logic;

   type slow_cyc_t is (fast, slow_short, slow_short_2, slow_long);
   signal r_slow                 : slow_cyc_t   := fast;



begin

   assert G_BEEBFPGA = false or G_FAST_CLOCKSPEED = 96000000 report "CLOCKSPEED must be 96M for BEEBFPGA" severity error;
   assert G_BEEBFPGA = true  or G_FAST_CLOCKSPEED = 128000000 report "CLOCKSPEED must be 128M for C20K" severity error;

   p_clk_2i:process(clk_fast_i)
   begin
      if rising_edge(clk_fast_i) then
         r_mhz2int_rise_clken <= '0';
         r_mhz2int_clken <= '0'; 
         r_mhz1E_clken <= '0';
         if reset_i = '1' then
            r_mhz2_ctdn <= to_unsigned(0, C_CTR2_LENGTH);
         else
            if to_integer(r_mhz2_ctdn) >= C_CLKS_MHZ2 - 1  then
               r_mhz2int_clken <= '1';               
               if r_mhz1E_clk = '1' then
                  r_mhz1E_clken <= '1';
               end if;
               r_mhz2_ctdn <= to_unsigned(0, C_CTR2_LENGTH);
            else
               r_mhz2_ctdn <= r_mhz2_ctdn + 1;
            end if;

            if to_integer(r_mhz2_ctdn) = C_CLKS_MHZ2_HALF - 1 then
               r_mhz2int_rise_clken <= '1';
            end if;
         end if;
      end if;
   end process;


   p_clk_1e:process(clk_fast_i)
   begin
      if rising_edge(clk_fast_i) then
         if reset_i = '1' then
            r_mhz1E_clk <= '0';            
         else
            if r_mhz2int_clken = '1' then
               r_mhz1E_clk <= not r_mhz1E_clk;
            end if;
         end if;
      end if;
   end process;

   p_clk_2e:process(clk_fast_i)
   begin
      if rising_edge(clk_fast_i) then
         if reset_i = '1' then
            r_mhz2E_clk <= '0';     
            r_slow <= fast;       
         else
            if to_integer(r_mhz2_ctdn) = C_F_ALE and r_slow = fast then
               -- register whether a slow or fast cycle and the type
               if i_bbc_slow_cyc then
                  if r_mhz1E_clk = '1' then
                     r_slow <= slow_long;
                  else
                     r_slow <= slow_short;
                  end if;
               else
                  r_slow <= fast;
               end if;
            else
               if r_mhz2int_clken = '1' then
                  if r_slow = fast then
                     r_mhz2E_clk <= '0';
                  end if;

               elsif r_mhz2int_rise_clken = '1' then
                  if r_slow = fast or r_slow = slow_short then
                     r_mhz2E_clk <= '1';
                  end if;

                  if r_slow = slow_long then
                     r_slow <= slow_short;
                  elsif r_slow = slow_short then
                     r_slow <= slow_short_2;
                  elsif r_slow = slow_short_2 then
                     r_slow <= fast;
                  end if;


               end if;
            end if;
         end if;
      end if;
   end process;

   p_cyc:process(clk_fast_i)
   begin
      if rising_edge(clk_fast_i) then
         addr_ack_clken_o <= '0';
         if to_integer(r_mhz2_ctdn) = C_F_ALE and r_slow = fast then
            addr_ack_clken_o <= '1';
         end if;
      end if;
   end process;

   mhz1E_clken_o <= r_mhz1E_clken;
   mhz2E_clken_o <=  r_mhz2int_clken when r_slow = fast else 
                     '0';
   mux_mhz1E_clk <= r_mhz1E_clk;
   mux_mhz2E_clk <= r_mhz2E_clk;


   e_slow_cyc:entity work.bbc_slow_cyc
   port map (
      sys_A_i        => sys_A_i,
      slow_o         => i_bbc_slow_cyc
   );



   mux_bus_io <= (others => 'Z');

end rtl;
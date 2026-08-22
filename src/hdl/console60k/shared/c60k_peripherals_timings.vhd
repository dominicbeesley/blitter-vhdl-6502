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
-- TODO: try reducing number of SYS_A lines and check resource usage / timing improvement

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;

entity c60k_peripherals_timings is
generic (
      G_FAST_CLOCKSPEED    : natural := 128000000;
      G_BEEBFPGA           : boolean := false;
      G_RD_CTDN_BITS       : natural := 7;
      DEFAULT_SYS_ADDR     : std_logic_vector(15 downto 0) := x"FFEA";
      DEFAULT_SYS_DATA     : std_logic_vector(7 downto 0) := x"FE";
--      DEFAULT_SYS_RnW      : std_logic := '0';        -- bodge FE onto bus for Tube detect, only works if MOS runs at 2MHz!
      DEFAULT_SYS_RnW      : std_logic := '1';
      C20K_LATCH_ADDR      : std_logic_vector(15 downto 0) := x"FC20";  -- TODO: better address
      C20K_LATCH_DEFAULT   : std_logic_vector(7 downto 0)  := "00100001"
   );
port (

   -- clocks in   
   clk_fast_i              : in     std_logic;

   -- clock ens out in fast clock domain
   mhz1E_clken_o           : out    std_logic;                       -- last fast cycle of 1MHz enable
   mhz2E_clken_o           : out    std_logic;                       -- last cycle of cycle stretched 2MHzE
                                                                     -- coincident with clken_mhz1E_clken_i
   mhz4_clken_o            : out    std_logic;                       -- 4x 1MHzE_clken - used by m6522

   -- state control in
   reset_i                 : in     std_logic;                       -- reset signal
                                                                     -- this can be a single fast clock long and 
                                                                     -- will start a new bus cycle on the next fast
                                                                     -- clock

   -- address and cycle selection from core
   -- this needs to be ready before the ALE phase
   -- A, RnW are registered _1 cycle AFTER_ addr_ack_clken_o 
   sys_cyc_en_i            : in     std_logic;                       -- ignore SYS bus cycle when '0'
   sys_A_i                 : in     std_logic_vector(15 downto 0);   -- this will be decoded to a peripheral
   sys_RnW_i               : in     std_logic;                       -- bus/peripherals RnW
   sys_nRST_i              : in     std_logic;                       -- bus/peripherals reset

   -- address and cycle selection back to core
   addr_ack_clken_o        : out    std_logic;                       -- clken for an address being accepted 
                                                                     -- from the core into this module
   -- sys write 
   sys_D_wr_i              : in     std_logic_vector(7 downto 0);    -- needs to be ready before write part of cycle

   -- data and inputs back from bus at end of cycle
   sys_D_rd_o              : out    std_logic_vector(7 downto 0);    -- data back from peripherals
   sys_D_rd_clken_o        : out    std_logic;                       -- read data valid

   -- how many cycles until a read will be ready
   rd_ready_ctdn_o         : out    unsigned(G_RD_CTDN_BITS-1 downto 0);

   -- mux clock outputs
   mux_mhz1E_clk_o         : out    std_logic;                        -- 1MHzE clock for main board
   mux_mhz2E_clk_o         : out    std_logic;                        -- 2MHzE clock for main board - cycle stretched
   -- slow latch curren values
   beeb_ic32_o             : out    std_logic_vector(7 downto 0)     -- the emulated beeb ic32 outputs

);
end c60k_peripherals_timings;

architecture rtl of c60k_peripherals_timings is
   
   constant C_CLKS_MHZ2          : natural := G_FAST_CLOCKSPEED / 2000000;
   constant C_CLKS_MHZ2_HALF     : natural := C_CLKS_MHZ2 / 2;

   constant C_MHZ2_CTR_LEN       : natural := numbits(C_CLKS_MHZ2-1);
   constant C_BIG_CTR_LEN        : natural := numbits(C_CLKS_MHZ2 * 3 - 1);       -- needs to fit at least 3 2MHz cycles for long clock stetch

   constant C_CLKS_MHZ8          : natural := G_FAST_CLOCKSPEED / 8000000;
   constant C_CLKS_MHZ8_HALF     : natural := C_CLKS_MHZ8 / 2;

   --imaginary 32MHz slices within a 2MHz cycle
   constant C_32_D_hold          : natural := 0;
   constant C_32_I0              : natural := 2;
   constant C_32_O1              : natural := 3;
   constant C_32_I1              : natural := 4;
   constant C_32_ALE             : natural := 5;      -- address setup to phi2
   constant C_32_O0              : natural := 6;      -- address setup to phi2
   constant C_32_D_write         : natural := 10;
   constant C_32_D_read          : natural := 10;

   function C_F_MUL return natural is
   begin
      if G_BEEBFPGA then
         return 3;
      else
         return 4;
      end if;
   end function;

   function C_F_SOFF return natural is
   begin
      if G_BEEBFPGA then
         return 1;
      else
         return 2;
      end if;
   end function;

   -- above 32 slices translated to fast clock 
   constant C_F_D_hold           : natural := C_CLKS_MHZ2 - 1 - C_F_MUL * C_32_D_hold;
   constant C_F_ALE              : natural := C_CLKS_MHZ2 - 1 - C_F_MUL * C_32_ALE;
   constant C_F_O0               : natural := C_CLKS_MHZ2 - 1 - C_F_MUL * C_32_O0;
   constant C_F_I0               : natural := C_CLKS_MHZ2 - 1 - C_F_MUL * C_32_I0;
   constant C_F_O1               : natural := C_CLKS_MHZ2 - 1 - C_F_MUL * C_32_O1;
   constant C_F_I1               : natural := C_CLKS_MHZ2 - 1 - C_F_MUL * C_32_I1;
   constant C_F_D_write          : natural := C_CLKS_MHZ2 - 1 - C_F_MUL * C_32_D_write;
   constant C_F_D_read           : natural := C_CLKS_MHZ2 - 1 - C_F_MUL * C_32_D_read;

   -- note for stretched cycles 2mhzE must rise _before_ 1MHzE for the USER VIA
   -- TODO: check if this is acceptable for Master
   constant C_2MHZE_LONG_UP      : natural := C_CLKS_MHZ2_HALF * 4 + 1;
   constant C_2MHZE_MED_UP       : natural := C_CLKS_MHZ2_HALF * 3 + 1;
   constant C_2MHZE_SHORT_UP     : natural := C_CLKS_MHZ2_HALF * 1 + 1;
   constant C_2MHZE_DOWN         : natural := 1;
   constant C_2MHZI_UP           : natural := C_CLKS_MHZ2_HALF + 1;
   constant C_2MHZI_DOWN         : natural := 1;


   signal r_big_ctdn             : unsigned(C_BIG_CTR_LEN - 1 downto 0) := (others => '1');
   signal r_mhz2_ctdn            : unsigned(C_MHZ2_CTR_LEN-1 downto 0);
 
   signal r_mhz1E_clken          : std_logic := '0';
   signal r_mhz2int_clken        : std_logic := '0';        -- not cycle stretched at end of phi2
   signal r_mhz2int_rise_clken   : std_logic := '0';        -- not cycle stretched at end of phi1
   signal r_mhz2E_clken          : std_logic := '0';        -- cycle stretched at end of phi2
   signal r_mhz2E_up_clken       : std_logic := '0';
   signal r_mhz1E_clk            : std_logic := '0';
   signal r_mhz2E_clk            : std_logic := '0';

   signal i_bbc_slow_cyc         : std_logic;

   type stretch_cyc_t is (short, medium, long);
   signal r_stretch              : stretch_cyc_t   := short;
   signal r_cyc_start            : std_logic;               -- on next cycle after address registered
   signal r_cyc                  : std_logic;               -- cycle is live

   -- bus req/ack signals
   signal r_addr_ack_clken       : std_logic;      -- signal to controller to prepare addresses
   signal r_addr_ack_clken2      : std_logic;      -- signal to internal process to latch addresses
   -- bus registered signals
   signal r_SYS_A                : std_logic_vector(15 downto 0)  := (others => '0');
   signal r_SYS_RnW              : std_logic                      := '1';
   signal r_SYS_D_wr             : std_logic_vector(7 downto 0)   := (others => '0');

   signal r_beeb_ic32            : std_logic_vector(7 downto 0)   := (others =>'0'); -- emulated BEEB IC32
   signal i_new_ic32             : std_logic_vector(7 downto 0);

   function RDYCTDN(i : integer) return unsigned is
   begin

      if i < 2**G_RD_CTDN_BITS then
         return to_unsigned(i, G_RD_CTDN_BITS);
      else
         return to_unsigned(2**G_RD_CTDN_BITS, G_RD_CTDN_BITS) - 1;
      end if;
   end function;

begin

   p_rdyctdn:process(clk_fast_i)
   begin
      if rising_edge(clk_fast_i) then
         rd_ready_ctdn_o <= RDYCTDN(to_integer(r_big_ctdn));
      end if;
   end process;

   addr_ack_clken_o <= r_addr_ack_clken;
   

   assert G_BEEBFPGA = false or G_FAST_CLOCKSPEED = 96000000 report "CLOCKSPEED must be 96M for BEEBFPGA" severity error;
   assert G_BEEBFPGA = true  or G_FAST_CLOCKSPEED = 128000000 report "CLOCKSPEED must be 128M for C20K" severity error;

   p_big_clk:process(clk_fast_i)
   begin
      if rising_edge(clk_fast_i) then
         if reset_i = '1' then
            r_big_ctdn <= to_unsigned(C_CLKS_MHZ2 - 1, C_BIG_CTR_LEN);      -- needs to fit at least 3 2MHz cycles for long clock stetch
            r_mhz2_ctdn <= to_unsigned(C_CLKS_MHZ2 - 1, C_MHZ2_CTR_LEN);
         else
            if r_big_ctdn = 0 then
               r_big_ctdn <= to_unsigned(C_CLKS_MHZ2 - 1, C_BIG_CTR_LEN);       -- needs to fit at least 3 2MHz cycles for long clock stetch
               r_stretch <= short;
            else
               r_big_ctdn <= r_big_ctdn - 1;
            end if;

            if r_mhz2_ctdn = 0 then
               r_mhz2_ctdn <= to_unsigned(C_CLKS_MHZ2 - 1, C_MHZ2_CTR_LEN);       -- needs to fit at least 3 2MHz cycles for long clock stetch
            else
               r_mhz2_ctdn <= r_mhz2_ctdn - 1;
            end if;

            if r_cyc_start = '1' then
               -- register whether a slow or fast cycle and the type
               if i_bbc_slow_cyc = '1' and r_cyc = '1' then
                  if r_mhz1E_clk = '1' then
                     r_stretch <= long;
                     r_big_ctdn <= to_unsigned(C_F_ALE + C_F_MUL + 2 * C_CLKS_MHZ2 - 2, C_BIG_CTR_LEN);
                  else
                     r_stretch <= medium;
                     r_big_ctdn <= to_unsigned(C_F_ALE + C_F_MUL + 1 * C_CLKS_MHZ2 - 2, C_BIG_CTR_LEN);
                  end if;
               else
                  r_big_ctdn <= to_unsigned(to_integer(r_mhz2_ctdn) - 1, C_BIG_CTR_LEN);
                  r_stretch <= short;
               end if;
            end if;

         end if;
      end if;
   end process;

   p_clk_2i:process(clk_fast_i)
   begin
      if rising_edge(clk_fast_i) then
         r_mhz2int_rise_clken <= '0';
         r_mhz2int_clken <= '0'; 
         r_mhz1E_clken <= '0';

         if r_mhz2_ctdn = C_2MHZI_DOWN then
            r_mhz2int_clken <= '1';               
            if r_mhz1E_clk = '1' then
               r_mhz1E_clken <= '1';
            end if;
         elsif to_integer(r_mhz2_ctdn) = C_2MHZI_UP then
            r_mhz2int_rise_clken <= '1';
         end if;

      end if;
   end process;

   mhz4_clken_o <= r_mhz2int_clken or r_mhz2int_rise_clken;


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
         r_mhz2E_clken <= '0';
         r_mhz2E_up_clken <= '0';
         if reset_i = '1' then
            r_mhz2E_clk <= '0';     
         else
            
            if r_mhz2E_up_clken = '1' then
               r_mhz2E_clk <= '1';
            elsif r_mhz2E_clken = '1' then
               r_mhz2E_clk <= '0';
            end if;


            if r_stretch = long then
               if to_integer(r_big_ctdn) = C_2MHZE_LONG_UP then
                  r_mhz2E_up_clken <= '1';
               elsif to_integer(r_big_ctdn) = C_2MHZE_DOWN then
                  r_mhz2E_clken <= '1';
               end if;
            elsif r_stretch = medium then
               if to_integer(r_big_ctdn) = C_2MHZE_MED_UP then
                  r_mhz2E_up_clken <= '1';
               elsif to_integer(r_big_ctdn) = C_2MHZE_DOWN then
                  r_mhz2E_clken <= '1';
               end if;
            else
               if to_integer(r_mhz2_ctdn) = C_2MHZE_SHORT_UP then
                  r_mhz2E_up_clken <= '1';
               elsif to_integer(r_big_ctdn) = C_2MHZE_DOWN then
                  r_mhz2E_clken <= '1';
               end if;
            end if;
         end if;
      end if;
   end process;

   mhz1E_clken_o <= r_mhz1E_clken;
   mhz2E_clken_o <= r_mhz2E_clken;
   mux_mhz1E_clk_o <= r_mhz1E_clk;
   mux_mhz2E_clk_o <= r_mhz2E_clk;


   p_cyc:process(clk_fast_i)
   begin
      if rising_edge(clk_fast_i) then
         r_addr_ack_clken <= '0';
         r_addr_ack_clken2 <= '0';
         r_cyc_start <= '0';
         if reset_i = '1' then
            r_SYS_A <= (others => '0');
            r_SYS_RnW <= '0';
         else
            if to_integer(r_big_ctdn) = C_F_ALE + C_F_MUL + 2 and r_stretch = short then
               r_addr_ack_clken <= '1';
            elsif r_addr_ack_clken = '1' then
               r_addr_ack_clken2 <= '1';
            elsif r_addr_ack_clken2 = '1' then
               r_cyc_start <= '1';
               if sys_cyc_en_i = '1' then
                  r_SYS_A <= sys_A_i;
                  r_SYS_RnW <= sys_RnW_i;
                  r_cyc <= '1';
               else
                  r_SYS_A <= DEFAULT_SYS_ADDR;
                  r_SYS_RnW <= DEFAULT_SYS_RnW;                  
                  r_cyc <= '0';
               end if;
            end if;
         end if;
      end if;
   end process;

   --TODO: define exact cycle (before/after phi2) for read
   p_rd:process(clk_fast_i)
   begin

      if rising_edge(clk_fast_i) then
         sys_D_rd_clken_o <= '0';

         if r_big_ctdn < 16 then
            sys_D_rd_o <= r_SYS_A(15 downto 8); -- TODO: check this but it should work for TUBE / 8271 detect
         end if;

         if r_mhz2E_clken = '1' then
            sys_D_rd_clken_o <= '1';
         end if;
      end if;
   end process;

   p_wr:process(clk_fast_i)
   begin
      if rising_edge(clk_fast_i) then
         if reset_i = '1' then
            r_SYS_D_wr <= (others => '0');
         else
            if to_integer(r_mhz2_ctdn) = C_F_D_write - 1 then
               if r_cyc = '1' then
                  r_SYS_D_wr <= sys_D_wr_i;
               else
                  r_SYS_D_wr <= DEFAULT_SYS_DATA;
               end if;
            end if;
         end if;
      end if;      
   end process;

   p_slow_latch_mux:process(all)
   variable v_m : std_logic_vector(7 downto 0);
   begin
      v_m := "00000001" sll to_integer(unsigned(r_SYS_D_wr(2 downto 0)));
      i_new_ic32 <= r_beeb_ic32;
      if r_SYS_D_wr(3) = '1' then
         i_new_ic32 <= r_beeb_ic32 or v_m;
      else
         i_new_ic32 <= r_beeb_ic32 and not v_m;
      end if;
   end process;
         
   p_slow_latch:process(clk_fast_i)
   begin
      if rising_edge(clk_fast_i) then
         if SYS_nRST_i = '0' then
            --TODO: mask out new indices
            r_beeb_ic32 <= (others => '0');
         else
            if r_mhz1E_clken = '1' and r_SYS_RnW = '0' and r_SYS_A = x"FE40" then
               r_beeb_ic32 <= i_new_ic32;
            end if;
         end if;
      end if;
   end process;

   beeb_ic32_o <= r_beeb_ic32;

   e_slow_cyc:entity work.bbc_slow_cyc
   port map (
      sys_A_i        => r_SYS_A,
      slow_o         => i_bbc_slow_cyc
   );

end rtl;
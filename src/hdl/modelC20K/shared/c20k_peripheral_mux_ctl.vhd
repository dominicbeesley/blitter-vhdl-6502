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
use ieee.std_logic_misc.all;

library work;
use work.common.all;

entity c20k_peripherals_mux_ctl is
generic (
      G_FAST_CLOCKSPEED    : natural := 128000000;
      G_BEEBFPGA           : boolean := false;
      G_RD_CTDN_BITS       : natural := 7;
      DEFAULT_SYS_ADDR     : std_logic_vector(15 downto 0) := x"FFEA";
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

   -- mux control outputs
   mux_nALE_o              : out    std_logic;
   mux_D_nOE_o             : out    std_logic;
   mux_I0_nOE_o            : out    std_logic;
   mux_I1_nOE_o            : out    std_logic;
   mux_O0_nOE_o            : out    std_logic;
   mux_O1_nOE_o            : out    std_logic;

   -- mux multiplexed signals bus
   mux_bus_io              : inout  std_logic_vector(7 downto 0);

   -- random other multiplexed pins out to FPGA (I0 phase)
   p_ser_cts_o             : out    std_logic;
   p_ser_rx_o              : out    std_logic;
   p_d_cas_o               : out    std_logic;
   p_kb_nRST_o             : out    std_logic;
   p_kb_CA2_o              : out    std_logic;
   p_netint_o              : out    std_logic;
   p_irq_o                 : out    std_logic;
   p_nmi_o                 : out    std_logic;

   -- random other multiplexed pins out to FPGA (I1 phase)
   p_j_i0_o                : out    std_logic;
   p_j_i1_o                : out    std_logic;
   p_j_spi_miso_o          : out    std_logic;
   p_btn0_o                : out    std_logic;
   p_btn1_o                : out    std_logic;
   p_btn2_o                : out    std_logic;
   p_btn3_o                : out    std_logic;
   p_kb_pa7_o              : out    std_logic;

   -- random other multiplexed pins in from FPGA (O0 phase)
   p_SER_TX_i              : in     std_logic;
   p_SER_RTS_i             : in     std_logic;

   -- random other multiplexed pins in from FPGA (O1 phase)
   p_j_ds_nCS2_i           : in     std_logic;
   p_j_ds_nCS1_i           : in     std_logic;
   p_j_spi_clk_i           : in     std_logic;
   p_VID_HS_i              : in     std_logic;
   p_VID_VS_i              : in     std_logic;
   p_VID_CS_i              : in     std_logic;
   p_j_spi_mosi_i          : in     std_logic;
   p_j_adc_nCS_i           : in     std_logic;

   -- slow latch curren values
   beeb_ic32_o             : out    std_logic_vector(7 downto 0); -- the emulated beeb ic32 outputs
   c20k_latch_o            : out    std_logic_vector(7 downto 0)  -- c20k slow latch


);
end c20k_peripherals_mux_ctl;

architecture rtl of c20k_peripherals_mux_ctl is
   
   constant C_CLKS_MHZ2          : natural := G_FAST_CLOCKSPEED / 2000000;
   constant C_CLKS_MHZ2_HALF     : natural := C_CLKS_MHZ2 / 2;

   constant C_MHZ2_CTR_LEN       : natural := numbits(C_CLKS_MHZ2-1);
   constant C_BIG_CTR_LEN        : natural := numbits(C_CLKS_MHZ2 * 3 - 1);       -- needs to fit at least 3 2MHz cycles for long clock stetch

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

   -- convenience and grouping of mux bus signals
   signal i_MIO_O0               : std_logic_vector(7 downto 0);
   signal i_MIO_O1               : std_logic_vector(7 downto 0);
   signal i_MIO_nCS              : std_logic_vector(3 downto 0);

   -- registered signals in from multiplexed input phases
   signal r_p_ser_cts            : std_logic;
   signal r_p_ser_rx             : std_logic;
   signal r_p_d_cas              : std_logic;
   signal r_p_kb_nRST            : std_logic;
   signal r_p_kb_CA2             : std_logic;
   signal r_p_netint             : std_logic;
   signal r_p_irq                : std_logic;
   signal r_p_nmi                : std_logic;
   signal r_p_j_i0               : std_logic;
   signal r_p_j_i1               : std_logic;
   signal r_p_j_spi_miso         : std_logic;
   signal r_p_btn0               : std_logic;
   signal r_p_btn1               : std_logic;
   signal r_p_btn2               : std_logic;
   signal r_p_btn3               : std_logic;
   signal r_p_kb_pa7             : std_logic;


   -- bus req/ack signals
   signal r_addr_ack_clken       : std_logic;      -- signal to controller to prepare addresses
   signal r_addr_ack_clken2      : std_logic;      -- signal to internal process to latch addresses
   -- bus registered signals
   signal r_SYS_A                : std_logic_vector(15 downto 0)  := (others => '0');
   signal r_SYS_RnW              : std_logic                      := '1';
   signal r_SYS_D_wr             : std_logic_vector(7 downto 0)   := (others => '0');

   signal r_beeb_ic32            : std_logic_vector(7 downto 0)   := (others =>'0'); -- emulated BEEB IC32
   signal r_c20k_latch           : std_logic_vector(7 downto 0)   := C20K_LATCH_DEFAULT; -- c02k internal latch
   signal i_C20K_U9_o            : std_logic_vector(7 downto 0);
   signal i_new_ic32             : std_logic_vector(7 downto 0);
   signal i_new_c20k_latch       : std_logic_vector(7 downto 0);

   -- slow latch reset
   signal i_data_o               : std_logic_vector(7 downto 0);

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
                  r_SYS_RnW <= '1';
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
            sys_D_rd_o <= mux_bus_io;
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
               r_SYS_D_wr <= sys_D_wr_i;
            end if;
         end if;
      end if;      
   end process;

   p_slow_latch_mux:process
   variable v_m : std_logic_vector(7 downto 0);
   begin
      v_m := "00000001" sll to_integer(unsigned(r_SYS_D_wr(2 downto 0)));
      i_new_c20k_latch <= r_c20k_latch;
      i_new_ic32 <= r_beeb_ic32;
      if SYS_nRST_i = '1' then
         if r_SYS_A = C20K_LATCH_ADDR then
            if r_SYS_D_wr(3) = '1' then
               i_new_c20k_latch <= r_c20k_latch or v_m;
            else
               i_new_c20k_latch <= r_c20k_latch and not v_m;
            end if;
         else
            if r_SYS_D_wr(3) = '1' then
               i_new_ic32 <= r_beeb_ic32 or v_m;
            else
               i_new_ic32 <= r_beeb_ic32 and not v_m;
            end if;
         end if;
      end if;
   end process;
         
--      i_C20K_U9_o <= i_new_ic32(7 downto 6) & 
--                     i_new_c20k_latch(5 downto 4) &
--                     i_new_ic32(3) & 
--                     i_new_c20k_latch(2 downto 0);
   i_C20K_U9_o <= i_new_ic32(7 downto 6) & 
                  i_new_c20k_latch(5) &
                  "0" &
                  i_new_ic32(3) & 
                  "00" &
                  i_new_c20k_latch(0);

   p_slow_latch:process(clk_fast_i)
   begin
      if rising_edge(clk_fast_i) then
         if SYS_nRST_i = '0' then
            --TODO: mask out new indices
            r_beeb_ic32 <= (others => '0');
            r_c20k_latch <= C20K_LATCH_DEFAULT;
         else
            if r_mhz1E_clken = '1' and r_SYS_RnW = '0' and r_SYS_A = x"FE40" then
               r_beeb_ic32 <= i_new_ic32;
            elsif r_mhz1E_clken = '1' and r_SYS_RnW = '0' and r_SYS_A = C20K_LATCH_ADDR then
               r_c20k_latch <= i_new_c20k_latch;
            end if;
         end if;
      end if;
   end process;


   beeb_ic32_o <= r_beeb_ic32;
   c20k_latch_o <= r_c20k_latch;

   p_reg_i0:process(clk_fast_i)
   begin
      if rising_edge(clk_fast_i) then
         if to_integer(r_mhz2_ctdn) = C_F_I0 - 1 then
            r_p_ser_cts <= mux_bus_io(0);
            r_p_ser_rx <= mux_bus_io(1);
            r_p_d_cas <= mux_bus_io(2);
            r_p_kb_nRST <= mux_bus_io(3);
            r_p_kb_CA2 <= mux_bus_io(4);
            r_p_netint <= mux_bus_io(5);
            r_p_irq <= mux_bus_io(6);
            r_p_nmi <= mux_bus_io(7);
         end if;
      end if;
   end process;

   p_reg_i1:process(clk_fast_i)
   begin
      if rising_edge(clk_fast_i) then
         if to_integer(r_mhz2_ctdn) = C_F_I1 - 1 then
            r_p_j_i0 <= mux_bus_io(0);
            r_p_j_i1 <= mux_bus_io(1);
            r_p_j_spi_miso <= mux_bus_io(2);
            r_p_btn0 <= mux_bus_io(3);
            r_p_btn1 <= mux_bus_io(4);
            r_p_btn2 <= mux_bus_io(5);
            r_p_btn3 <= mux_bus_io(6);
            r_p_kb_pa7  <= mux_bus_io(7);
         end if;
      end if;
   end process;

   p_ser_cts_o <= r_p_ser_cts;
   p_ser_rx_o <= r_p_ser_rx;
   p_d_cas_o <= r_p_d_cas;
   p_kb_nRST_o <= r_p_kb_nRST;
   p_kb_CA2_o <= r_p_kb_CA2;
   p_netint_o <= r_p_netint;
   p_irq_o <= r_p_irq;
   p_nmi_o <= r_p_nmi;
   p_j_i0_o <= r_p_j_i0;
   p_j_i1_o <= r_p_j_i1;
   p_j_spi_miso_o <= r_p_j_spi_miso;
   p_btn0_o <= r_p_btn0;
   p_btn1_o <= r_p_btn1;
   p_btn2_o <= r_p_btn2;
   p_btn3_o <= r_p_btn3;
   p_kb_pa7_o <= r_p_kb_pa7;


   mux_nALE_o  <=    '0'   when to_integer(r_mhz2_ctdn) = C_F_ALE else
                     '1';
   mux_O0_nOE_o <=   '0'   when to_integer(r_mhz2_ctdn) = C_F_O0 else
                     '1';
   mux_O1_nOE_o <=   '0'   when to_integer(r_mhz2_ctdn) = C_F_O1 else
                     '1';

   mux_I0_nOE_o <=   '0'   when to_integer(r_mhz2_ctdn) <= C_F_I0 + 1 and to_integer(r_mhz2_ctdn) > C_F_I0 - 1 else
                     '1';
   mux_I1_nOE_o <=   '0'   when to_integer(r_mhz2_ctdn) <= C_F_I1 + 1 and to_integer(r_mhz2_ctdn) > C_F_I1 - 1 else
                     '1';

   i_MIO_nCS <= "0101"  when SYS_nRST_i = '0' else -- reset slow latch
                "0101"  when r_SYS_A(15 downto 0)       = x"FE40" and r_SYS_RnW = '0' else -- BEEB IC32 WRITE
                "0101"  when r_SYS_A(15 downto 0)       = C20K_LATCH_ADDR and r_SYS_RnW = '0' else -- C20K latch
                "1010"  when r_SYS_A(15 downto 8) = x"FC" else        -- PGFC -- TODO: local holes
                "1011"  when r_SYS_A(15 downto 8) = x"FD" else        -- PGFD -- TODO: local holes/jim paging reg
                "1100"  when r_SYS_A(15 downto 5) & "0" = x"FEE" else -- TUBE
                "1101"  when r_SYS_A(15 downto 5) & "0" = x"FEA" else -- ADLC
                "0110"  when r_SYS_A(15 downto 5) & "0" = x"FE8" and r_SYS_A(2) = '1' else -- FDC
                "0111"  when r_SYS_A(15 downto 5) & "0" = x"FE8" and r_SYS_A(2) = '0' and r_SYS_RnW = '0' else -- FDCON
                "1001"  when r_SYS_A(15 downto 5) & "0" = x"FE6" else -- VIAB
                "0100"  when r_SYS_A(15 downto 0)       = x"FE41" and r_SYS_RnW = '0' else -- KBPAWR
                "0100"  when r_SYS_A(15 downto 0)       = x"FE4F" and r_SYS_RnW = '0' else -- KBPAWR
                "0000";

   i_MIO_O0 <= (
         3 downto 0 => i_MIO_nCS,
         4 => r_SYS_RnW,
         5 => SYS_nRST_i,
         6 => p_SER_TX_i,
         7 => p_SER_RTS_i
      );

   i_MIO_O1 <= (
      0 => p_J_DS_nCS2_i,
      1 => p_J_DS_nCS1_i,
      2 => p_J_SPI_CLK_i,
      3 => p_VID_VS_i,
      4 => p_VID_HS_i,
      5 => p_VID_CS_i,
      6 => p_J_SPI_MOSI_i,
      7 => p_J_ADC_nCS_i
      );


   -- subvert data bus during reset to initialize c20k slow latch
   i_data_o       <= i_C20K_U9_o when i_MIO_nCS = "0101" else
                     r_SYS_D_wr;

   mux_bus_io <=  i_data_o  when to_integer(r_mhz2_ctdn) > C_F_D_hold - C_F_MUL + 1 and r_SYS_RnW = '0' else
                  r_SYS_A(7 downto 0)     
                            when to_integer(r_mhz2_ctdn) <= C_F_ALE + 1    and to_integer(r_mhz2_ctdn) > C_F_ALE - C_F_MUL + 1 else
                  i_MIO_O0  when to_integer(r_mhz2_ctdn) <= C_F_O0 + 1     and to_integer(r_mhz2_ctdn)  > C_F_O0  - C_F_MUL + 1 else
                  i_MIO_O1  when to_integer(r_mhz2_ctdn) <= C_F_O1 + 1     and to_integer(r_mhz2_ctdn)  > C_F_O1  - C_F_MUL + 1 else
                  i_data_o  when to_integer(r_mhz2_ctdn) <= C_F_D_write and r_SYS_RnW = '0' else
                  (others => 'Z');

   mux_D_nOE_o  <= '0'  when to_integer(r_mhz2_ctdn) > C_F_D_hold - C_F_MUL + 1 else
                   '0'  when to_integer(r_mhz2_ctdn) < C_F_D_write and r_SYS_RnW = '0' else
                   '0'  when to_integer(r_mhz2_ctdn) < C_F_D_read  and r_SYS_RnW = '1' else
                   '1';



   e_slow_cyc:entity work.bbc_slow_cyc
   port map (
      sys_A_i        => r_SYS_A,
      slow_o         => i_bbc_slow_cyc
   );

end rtl;
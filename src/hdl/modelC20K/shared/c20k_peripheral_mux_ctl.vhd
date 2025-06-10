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
   p_j_adc_nCS_i           : in     std_logic


);
end c20k_peripherals_mux_ctl;

architecture rtl of c20k_peripherals_mux_ctl is
   
   constant C_CLKS_MHZ2          : natural := G_FAST_CLOCKSPEED / 2000000;
   constant C_CLKS_MHZ2_HALF     : natural := C_CLKS_MHZ2 / 2;

   constant C_CTR2_LENGTH        : natural := numbits(C_CLKS_MHZ2 - 1);

   --imaginary 32MHz slices within a 2MHz cycle
   constant C_32_D_hold          : natural := 0;
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

   function C_F_SOFF return natural is
   begin
      if G_BEEBFPGA then
         return 1;
      else
         return 2;
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


   -- bus registered signals
   signal r_SYS_A                : std_logic_vector(15 downto 0)  := (others => '0');
   signal r_SYS_RnW              : std_logic                      := '1';
   signal r_SYS_D_wr             : std_logic_vector(7 downto 0)   := (others => '0');


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
               if i_bbc_slow_cyc = '1' and sys_cyc_en_i = '1' then
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

   mhz1E_clken_o <= r_mhz1E_clken;
   mhz2E_clken_o <=  r_mhz2int_clken when r_slow = fast else 
                     '0';
   mux_mhz1E_clk_o <= r_mhz1E_clk;
   mux_mhz2E_clk_o <= r_mhz2E_clk;


   p_cyc:process(clk_fast_i)
   begin
      if rising_edge(clk_fast_i) then
         addr_ack_clken_o <= '0';
         if reset_i = '1' then
            r_SYS_A <= (others => '0');
            r_SYS_RnW <= '1';
         else
            if to_integer(r_mhz2_ctdn) = C_F_ALE-1 and r_slow = fast then
               if sys_cyc_en_i = '1' then
                  addr_ack_clken_o <= '1';
                  r_SYS_A <= sys_A_i;
                  r_SYS_RnW <= sys_RnW_i;
               else
                  r_SYS_A <= x"FFEA";
                  r_SYS_RnW <= '1';
               end if;
            end if;
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

   p_reg_i0:process(clk_fast_i)
   begin
      if rising_edge(clk_fast_i) then
         if to_integer(r_mhz2_ctdn) = C_F_I0 + 2 then
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
         if to_integer(r_mhz2_ctdn) = C_F_I1 + 2 then
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

   mux_I0_nOE_o <=   '0'   when to_integer(r_mhz2_ctdn) >= C_F_I0 and to_integer(r_mhz2_ctdn) < C_F_I0 + C_F_MUL-1 else
                     '1';
   mux_I1_nOE_o <=   '0'   when to_integer(r_mhz2_ctdn) >= C_F_I1 and to_integer(r_mhz2_ctdn) < C_F_I1 + C_F_MUL-1 else
                     '1';

   i_MIO_nCS <= "1010"  when r_SYS_A(15 downto 8) = x"FC" else        -- PGFC -- TODO: local holes
                "1011"  when r_SYS_A(15 downto 8) = x"FD" else        -- PGFD -- TODO: local holes/jim paging reg
                "1100"  when r_SYS_A(15 downto 5) & "0" = x"FEE" else -- TUBE
                "1101"  when r_SYS_A(15 downto 5) & "0" = x"FEA" else -- ADLC
                "0110"  when r_SYS_A(15 downto 5) & "0" = x"FE8" and r_SYS_A(2) = '1' else -- FDC
                "0111"  when r_SYS_A(15 downto 5) & "0" = x"FE8" and r_SYS_A(2) = '0' and r_SYS_RnW = '0' else -- FDCON
                "1001"  when r_SYS_A(15 downto 5) & "0" = x"FE6" else -- VIAB
                "0100"  when r_SYS_A(15 downto 0)       = x"FE41" and r_SYS_RnW = '0' else -- KBPAWR
                "0100"  when r_SYS_A(15 downto 0)       = x"FE4F" and r_SYS_RnW = '0' else -- KBPAWR
                "0101"  when r_SYS_A(15 downto 0)       = x"FE40" and r_SYS_RnW = '0' else -- IC32WR
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


   mux_bus_io <=  r_SYS_D_wr  when to_integer(r_mhz2_ctdn) <= C_F_D_hold + C_F_MUL - 1 and r_SYS_RnW = '0' else
                  r_SYS_A(7 downto 0)     
                              when to_integer(r_mhz2_ctdn) >= C_F_ALE and to_integer(r_mhz2_ctdn) < C_F_ALE + C_F_MUL-1 else
                  i_MIO_O0    when to_integer(r_mhz2_ctdn) >= C_F_O0 and to_integer(r_mhz2_ctdn) < C_F_O0 + C_F_MUL-1 else
                  i_MIO_O1    when to_integer(r_mhz2_ctdn) >= C_F_O1 and to_integer(r_mhz2_ctdn) < C_F_O1 + C_F_MUL-1 else
                  r_SYS_D_wr  when to_integer(r_mhz2_ctdn) >= C_F_D_write and r_SYS_RnW = '0' else
                  (others => 'Z');

   mux_D_nOE_o  <= '0'  when to_integer(r_mhz2_ctdn) <= C_F_D_hold + C_F_MUL - 1 else
                   '0'  when to_integer(r_mhz2_ctdn) >= C_F_D_write and r_SYS_RnW = '0' else
                   '0'  when to_integer(r_mhz2_ctdn) >= C_F_D_read  and r_SYS_RnW = '1' else
                   '1';



   e_slow_cyc:entity work.bbc_slow_cyc
   port map (
      sys_A_i        => sys_A_i,
      slow_o         => i_bbc_slow_cyc
   );

end rtl;
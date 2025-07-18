-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2023 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:      25/04/2023
-- Design Name: 
-- Module Name:      fishbone bus - CPU wrapper component, cut down
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      A fishbone wrapper for just the T65 core
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--    This component provides a fishbone master wrapper around the T65 core. 
--
----------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.math_real.all;

library work;
use work.fishbone.all;
use work.common.all;

entity fb_C20K_mem_cpu_65816 is
   generic (
      G_NMI_META_LEVELS             : natural := 5;
      SIM                           : boolean := false;                    -- skip some stuff, i.e. slow sdram start up
      CLOCKSPEED                    : natural;                             -- fast clock speed in Hz
      CPU_SPEED                     : natural                              -- cpu speed in Hz must divide into CLOCKSPEED by an exact integer                
   );
   port(

      -- configuration

      -- direct CPU control signals from system
      nmi_n_i                          : in  std_logic;
      irq_n_i                          : in  std_logic;

      -- fishbone signals
      fb_syscon_i                      : in  fb_syscon_t;
      fb_c2p_o                         : out fb_con_o_per_i_t;
      fb_p2c_i                         : in  fb_con_i_per_o_t;

      -- chipset control signals
      cpu_halt_i                       : in  std_logic;

      -- logical mappings
      JIM_page_i                       : in  std_logic_vector(15 downto 0);
      JIM_en_i                         : in  std_logic;

      -- memory motherboard signals

      MEM_A_io                         : inout  std_logic_vector(20 downto 0);
      MEM_D_io                         : inout  std_logic_vector(7 downto 0);

      MEM_RAM_nCE_o                    : out    std_logic_vector(3 downto 0); -- 0 is BB RAM
      MEM_ROM_nCE_o                    : out    std_logic;                    -- Flash EEPROM select
      MEM_nOE_o                        : out    std_logic;
      MEM_nWE_o                        : out    std_logic;

      -- cpu motherboard signals
      CPU_A_nOE_o                      : out    std_logic;

      CPU_PHI2_o                       : out    std_logic;
      CPU_BE_o                         : out    std_logic;
      CPU_RDY_io                       : inout  std_logic;

      CPU_nRES_o                       : out    std_logic;
      CPU_nIRQ_o                       : out    std_logic;
      CPU_nNMI_o                       : out    std_logic;
      CPU_nABORT_o                     : out    std_logic;

      CPU_MX_i                         : in     std_logic;
      CPU_E_i                          : in     std_logic

   );
end fb_C20K_mem_cpu_65816;

architecture rtl of fb_C20K_mem_cpu_65816 is

   function cdiv(dividend:time; divisor:time) return integer is
   begin
      return integer(ceil(real(1000 * dividend / divisor) / 1000.0));

   end cdiv;

   constant C_CLOCK_PER    : time      := 1000000 us / CLOCKSPEED;

   constant T_ADS          : time      := 40000 ps;
   constant T_DHR          : time      := 10000 ps;
   constant T_DSR          : time      := 10000 ps;
   constant T_PCS          : time      := 15000 ps;
   constant T_MDS          : time      := 30000 ps;

   -- constants for cpu clock division events
   constant C_DIV_TOTAL          : integer   := CLOCKSPEED / CPU_SPEED;
   constant C_CPU_DIV_PHI1       : integer   := 0;
   constant C_CPU_DIV_PHI2       : integer   := C_DIV_TOTAL / 2;
   constant C_CPU_DIV_ADS        : integer   := cdiv(T_ADS , C_CLOCK_PER);
   constant C_CPU_DIV_PHI1_DHR   : integer   := cdiv(T_DHR , C_CLOCK_PER);
   constant C_CPU_DIV_PHI2_DHR   : integer   := C_CPU_DIV_PHI2 + cdiv(T_DHR , C_CLOCK_PER);
   constant C_CPU_DIV_MDS        : integer   := C_CPU_DIV_PHI2 + cdiv(T_MDS, C_CLOCK_PER);

   constant C_CPU_DIV_PHI2_DSR   : integer   := C_DIV_TOTAL - maximum(cdiv(T_DSR, C_CLOCK_PER), cdiv(T_PCS , C_CLOCK_PER));

   signal r_nmi            : std_logic;
   signal r_nmi_meta       : std_logic_vector(G_NMI_META_LEVELS-1 downto 0);

   signal r_cpu_div_ring   : std_logic_vector(C_DIV_TOTAL - 1 downto 0) := (0 => '1', others => '0');
   signal r_cpu_phi        : std_logic := '0';
   signal r_cpu_phi_DHR    : std_logic := '1';

   signal i_ring_next      : std_logic_vector(C_DIV_TOTAL-1 downto 0);
   signal r_cpu_n_reset    : std_logic_vector(3 downto 0) := (others => '0');

   type t_state is (
      reset,         -- coming out of reset
      wait_asetup,   -- wait for previous cycle to release and address / bank to be ready
      read_fb,       -- a fishbone read cycle is in progress, wait for fb ack
      write_fb       -- a fishbone write cycle is in progress, wait for fb ack
      );

   signal r_state          : t_state := reset;
   signal r_A              : std_logic_vector(23 downto 0);

   signal r_VPA            : std_logic;
   signal r_VDA            : std_logic;
   signal r_MLB            : std_logic;
   signal r_RnW            : std_logic;
   signal r_VPB            : std_logic;

   signal r_had_fb_ack     : std_logic;
   signal r_fb_D_rd        : std_logic_vector(7 downto 0);
   signal r_was_ready      : std_logic;

begin

   assert CLOCKSPEED > CPU_SPEED report "CLOCKSPEED must be greater than CPU_SPEED" severity error;
   assert CLOCKSPEED mod CPU_SPEED = 0 report "CLOCKSPEED must be an integer multiple of CPU_SPEED" severity error;

   -- ================================================================================================ --
   -- NMI registration - kept from Blitter, might be unnecessary
   -- ================================================================================================ --

   -- nmi was unreliable when testing DFS/ADFS, try de-gltiching
   p_nmi_meta:process(fb_syscon_i)
   begin
      if fb_syscon_i.rst = '1' then
         r_nmi_meta <= (others => '1');
         r_nmi <= '1';
      elsif rising_edge(fb_syscon_i.clk) then
         r_nmi_meta <= nmi_n_i & r_nmi_meta(G_NMI_META_LEVELS-1 downto 1);
         if or_reduce(r_nmi_meta) = '0' then
            r_nmi <= '0';
         elsif and_reduce(r_nmi_meta) = '1' then
            r_nmi <= '1';
         end if;
      end if;
   end process;

   -- ================================================================================================ --
   -- CPU phi clock generation
   -- ================================================================================================ --
   
   p_cpu_phi:process(fb_syscon_i)
   begin
--      if fb_syscon_i.rst = '1' then
--         r_cpu_div_ring <= (0 => '1', others => '0');
--         r_cpu_phi <= '0';
--         r_cpu_phi_DHR <= '1';
--      els
      if rising_edge(fb_syscon_i.clk) then
         if i_ring_next(C_CPU_DIV_PHI1) = '1' then
            r_cpu_phi <= '0';
         end if;

         if i_ring_next(C_CPU_DIV_PHI2) = '1' then
            r_cpu_phi <= '1';
         end if;

         if i_ring_next(C_CPU_DIV_PHI1_DHR) = '1' then
            r_cpu_phi_DHR <= '0';
         end if;

         if i_ring_next(C_CPU_DIV_PHI2_DHR) = '1' then
            r_cpu_phi_DHR <= '1';
         end if;

         r_cpu_div_ring <= i_ring_next;
      end if;
   end process;

   i_ring_next <= r_cpu_div_ring(r_cpu_div_ring'high - 1 downto 0) & r_cpu_div_ring(r_cpu_div_ring'high);

   -- ================================================================================================ --
   -- CPU reset
   -- ================================================================================================ --

   p_cpu_reset:process(fb_syscon_i)
   begin
      if fb_syscon_i.rst = '1' then
         r_cpu_n_reset <= (others => '0');         
      else
         if rising_edge(fb_syscon_i.clk) then
            if i_ring_next(C_CPU_DIV_PHI2) = '1' then
               r_cpu_n_reset <= "1" & r_cpu_n_reset(r_cpu_n_reset'high downto 1);
            end if;
         end if;
      end if;

   end process;

   -- ================================================================================================ --
   -- CPU cycle state machine
   -- ================================================================================================ --

   p_state:process(fb_syscon_i)
   begin
      if fb_syscon_i.rst = '1' then
         r_state      <= reset;
         r_had_fb_ack <= '0';
         r_was_ready  <= '0';
         r_fb_D_rd       <= (others => '0');

         fb_c2p_o <= fb_c2p_unsel;
         
      else
         if rising_edge(fb_syscon_i.clk) then
            case r_state is
               when reset =>
                  fb_c2p_o <= fb_c2p_unsel;
                  if i_ring_next(C_CPU_DIV_PHI2) = '1' then
                     r_state <= wait_asetup;
                  end if;
               when wait_asetup =>
                  fb_c2p_o <= fb_c2p_unsel;
                  if i_ring_next(C_CPU_DIV_ADS + 1) = '1' then

                     CPU_RDY_io <= '0';
                     r_was_ready <= '0';

                     fb_c2p_o.cyc <= '1';
                     fb_c2p_o.A <= r_A;
                     fb_c2p_o.A_stb <= '1';                     

                     r_had_fb_ack <= '0';
                     if r_RnW = '1' then
                        r_state <= read_fb;
                     else
                        fb_c2p_o.we <= '1';
                        r_state <= write_fb;
                     end if;
                  else
                     --TODO: log2 phys
                     r_A <= x"FF" & MEM_A_io(15 downto 0);
                     r_VPA <= MEM_A_io(16);
                     r_VDA <= MEM_A_io(17);
                     r_MLB <= MEM_A_io(18);
                     r_RnW <= MEM_A_io(19);
                     r_VPB <= MEM_A_io(20);
                  end if;
               when read_fb =>
                  if fb_c2p_o.A_stb = '1' and fb_p2c_i.stall = '0' then
                     fb_c2p_o.A_stb <= '0';
                  else
                     if fb_p2c_i.ack = '1' then
                        r_fb_D_rd <= fb_p2c_i.D_rd;
                        r_had_fb_ack <= '1';
                        CPU_RDY_io <= '1';
                        fb_c2p_o.cyc <= '0';
                     end if;

                     if i_ring_next(C_CPU_DIV_PHI2_DSR) = '1' and r_had_fb_ack = '1' then
                        r_was_ready <= '1';
                     end if;

                     if r_was_ready = '1' and i_ring_next(C_CPU_DIV_PHI1_DHR) = '1' then
                        r_state <= wait_asetup;
                     end if;

                  end if;
               when write_fb =>
                  if fb_c2p_o.A_stb = '1' and fb_p2c_i.stall = '0' then
                     fb_c2p_o.A_stb <= '0';
                  else
                     if fb_p2c_i.ack = '1' then
                        r_had_fb_ack <= '1';
                        fb_c2p_o.cyc <= '0';
                     end if;

                     if i_ring_next(C_CPU_DIV_MDS) = '1' then
                        fb_c2p_o.D_wr <= MEM_D_io;
                        fb_c2p_o.D_wr_stb <= '1';
                     end if;

                     if i_ring_next(C_CPU_DIV_PHI2_DSR) = '1' and r_had_fb_ack = '1' then
                        r_was_ready <= '1';
                        CPU_RDY_io <= '1';
                     end if;

                     if r_was_ready = '1' and i_ring_next(C_CPU_DIV_PHI1_DHR) = '1' then
                        r_state <= wait_asetup;
                     end if;


                  end if;

            end case;
         end if;
      end if;
      
   end process;

   -- ================================================================================================ --
   -- associate generated
   -- ================================================================================================ --

   CPU_nRES_o <= r_cpu_n_reset(0);
   CPU_nIRQ_o <= irq_n_i;
   CPU_PHI2_o <= r_cpu_phi;
   CPU_nNMI_o <= r_nmi;

   p_mem_D:process(fb_syscon_i.clk)
   begin
      if fb_syscon_i.rst = '1' then
         MEM_D_io <= (others => '1');
      else
         if rising_edge(fb_syscon_i.clk) then
            if r_cpu_n_reset(0) = '0' then
               MEM_D_io <= (others => '1');
            elsif r_state = read_fb and r_cpu_phi_DHR = '1' then
               MEM_D_io <= r_fb_D_rd;
            else
               MEM_D_io <= (others => 'Z');
            end if;
         end if;
      end if;
   end process;

   -- ================================================================================================ --
   -- Unused / static 
   -- ================================================================================================ --

   CPU_nABORT_o <= '1';
   CPU_BE_o <= '1';

   CPU_A_nOE_o <= '0';

   MEM_A_io <= (others => 'Z');
   MEM_RAM_nCE_o <= (others => '1');
   MEM_ROM_nCE_o <= '1';
   MEM_nOE_o <= '1';
   MEM_nWE_o <= '1';


end rtl;

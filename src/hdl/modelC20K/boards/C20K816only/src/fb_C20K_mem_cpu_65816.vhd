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
-- Create Date:      8/8/2025
-- Design Name: 
-- Module Name:      fb_C20K_mem_cpu_65816
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      A fishbone wrapper for just the on-board 65816 shared with memory bus
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--    
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
use work.board_config_pack.all;
use work.fb_sys_pack.all;

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

      -- debug button (NoIce / DeIce)
      debug_btn_n_i                    : in  std_logic;

      -- fishbone signals
      fb_syscon_i                      : in  fb_syscon_t;
      fb_c2p_o                         : out fb_con_o_per_i_t;
      fb_p2c_i                         : in  fb_con_i_per_o_t;

      -- chipset control signals
      cpu_halt_i                       : in  std_logic;

      -- config signals
      cfg_swram_enable_i            : in std_logic;
      cfg_swromx_i                  : in std_logic;
      cfg_mosram_i                  : in std_logic;
      cfg_sys_type_i                : in sys_type;

      -- CPU address control signals from other components
      sys_ROMPG_i                   : in  std_logic_vector(7 downto 0);
      JIM_page_i                    : in  std_logic_vector(15 downto 0);
      turbo_lo_mask_i               : in  std_logic_vector(7 downto 0);

      rom_throttle_map_i            : in  std_logic_vector(15 downto 0);

      rom_autohazel_map_i           : in  std_logic_vector(15 downto 0);
      throttle_cpu_2MHz_i           : in  std_logic;
      cpu_2MHz_phi2_clken_i         : in  std_logic;

      boot_65816_i                  : in  std_logic_vector(1 downto 0);
      -- boot settings:
      -- 10    logical page FF maps to logical page 00, any change takes 2 instructions to complete to allow jump
      -- 00    pages map direct, any change takes 2 instructions to complete to allow jump
      -- 01    logical page FF maps to 00 in Emu mode, direct map otherwise, immediate change on emu switch
      -- 11    logical page FF maps to 00 in Emu mode, direct map otherwise, immediate change on emu switch ignore Throttle in native mode

      -- when active set a "window" from logical address space 00/FF E000-F000
      -- resets to point at MOS rom at boot time
      window_65816_i                : in  std_logic_vector(12 downto 0);
      window_65816_wr_en_i          : in  std_logic;

      -- memctl signals in
      jim_en_i                      : in  std_logic;     -- local jim override
      swmos_shadow_i                : in  std_logic;     -- shadow mos from SWRAM slot #8

      -- noice debugger signals to cpu
      noice_debug_shadow_i          : in std_logic;      -- debugger memory MOS map is active (overrides shadow_mos)

      -- debug 
      debug_cpu_instr_a             : out std_logic_vector(23 downto 0);

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
      CPU_E_i                          : in     std_logic;

      debug_cpu_state_o                : out    std_logic_vector(2 downto 0)

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
      phys_a,        -- act on phys a from log2phys
      read_fb,       -- a fishbone read cycle is in progress, wait for fb ack
      write_fb,      -- a fishbone write cycle is in progress, wait for fb ack,
      read_local,    -- a local memory access, A(20..8) modified to phys A
      write_local,   -- a local write access, A(20..8) modified to phys A
      dead ,         -- VPA and VDA both null, assert ready and wait for another cycle
      cpu_skip       -- cpu is being throttled, suppress phi2
      );

   signal r_state          : t_state := reset;
   signal r_A              : std_logic_vector(23 downto 0);
   signal i_phys_A         : std_logic_vector(23 downto 0);
   signal r_phys_A         : std_logic_vector(23 downto 0);

   signal r_VPA            : std_logic;
   signal r_VDA            : std_logic;
   signal r_MLB            : std_logic;
   signal r_RnW            : std_logic;
   signal r_VPB            : std_logic;

   signal r_had_fb_ack     : std_logic;
   signal r_fb_D_rd        : std_logic_vector(7 downto 0);
   signal r_D_wr_local     : std_logic_vector(7 downto 0);
   signal r_was_ready      : std_logic;

   signal i_peripheral_sel_oh : std_logic_vector(PERIPHERAL_COUNT-1 downto 0);
   signal r_peripheral_sel_oh : std_logic_vector(PERIPHERAL_COUNT-1 downto 0);


   signal r_debug_abort_n_ack    : std_logic;
   signal r_WDM                  : std_logic;

   signal r_boot_65816_dly : std_logic_vector(2 downto 0) := (others => '1');
   signal i_boot           : std_logic;

   signal r_cyc_2M_before  : std_logic;         -- a phi2 was detected this cycle, next will be valid for throttled cycles
   signal r_cyc_2M         : std_logic;         -- qualifies a cpu cycle as being the first after phi2 ended

   signal i_throttle_act  : std_logic;   

begin

   assert CLOCKSPEED > CPU_SPEED report "CLOCKSPEED must be greater than CPU_SPEED" severity error;
   assert CLOCKSPEED mod CPU_SPEED = 0 report "CLOCKSPEED must be an integer multiple of CPU_SPEED" severity error;


   p_det_2m:process(fb_syscon_i)
   begin
      if fb_syscon_i.rst = '1' then
         r_cyc_2M <= '0';
         r_cyc_2M_before <= '0';
      elsif rising_edge(fb_syscon_i.clk) then
         if i_ring_next(0) = '1' then
            r_cyc_2M <= r_cyc_2M_before;
            r_cyc_2M_before <= cpu_2MHz_phi2_clken_i;
         else
            r_cyc_2M_before <= r_cyc_2M_before or cpu_2MHz_phi2_clken_i;
         end if;
      end if;
   end process;

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
   variable v_p_rst : std_logic;
   begin
--      if fb_syscon_i.rst = '1' then
--         r_cpu_div_ring <= (0 => '1', others => '0');
--         r_cpu_phi <= '0';
--         r_cpu_phi_DHR <= '1';
--      els
      if rising_edge(fb_syscon_i.clk) then

         if fb_syscon_i.rst = '1' and v_p_rst = '0' then
            r_cpu_div_ring   <= (0 => '1', others => '0');
         else
            if i_ring_next(C_CPU_DIV_PHI1) = '1' then
               r_cpu_phi <= '0';
            end if;

            if i_ring_next(C_CPU_DIV_PHI2) = '1' and r_state /= cpu_skip then
               r_cpu_phi <= '1';
            end if;

            if i_ring_next(C_CPU_DIV_PHI1_DHR) = '1' then
               r_cpu_phi_DHR <= '0';
            end if;

            if i_ring_next(C_CPU_DIV_PHI2_DHR) = '1' and r_state /= cpu_skip then
               r_cpu_phi_DHR <= '1';
            end if;

            r_cpu_div_ring <= i_ring_next;         
         end if;

         v_p_rst := fb_syscon_i.rst;
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
   -- Local log2phys
   -- ================================================================================================ --

   e_log2phys:entity work.log2phys
   generic map (
      SIM                           => SIM,
      G_MK3                         => false,
      G_C20K                        => true
   )
   port map (
      fb_syscon_i                   => fb_syscon_i,
      cfg_swram_enable_i            => cfg_swram_enable_i,
      cfg_swromx_i                  => cfg_swromx_i,
      cfg_mosram_i                  => cfg_mosram_i,
      cfg_t65_i                     => '0',
      cfg_sys_type_i                => cfg_sys_type_i,
      sys_ROMPG_i                   => sys_ROMPG_i,
      JIM_page_i                    => JIM_page_i,
      turbo_lo_mask_i               => turbo_lo_mask_i,
      mos_throttle_i                => not swmos_shadow_i,           --TODO: configure somewhere in memctl
      throttle_all_i                => throttle_cpu_2MHz_i,
      rom_throttle_map_i            => rom_throttle_map_i,
      throttle_act_o                => i_throttle_act,
      rom_autohazel_map_i           => rom_autohazel_map_i,
      window_65816_i                => window_65816_i,
      window_65816_wr_en_i          => window_65816_wr_en_i,
      jim_en_i                      => jim_en_i,
      swmos_shadow_i                => swmos_shadow_i,
      noice_debug_shadow_i          => noice_debug_shadow_i,
      A_i                           => r_A,
      instruction_fetch_i           => r_VPA and r_VDA,
      A_o                           => i_phys_A

   );

   e_ad_local:entity work.address_decode
   generic map (
      SIM                     => SIM,
      G_PERIPHERAL_COUNT      => PERIPHERAL_COUNT,
      G_INCL_CHIPSET          => G_INCL_CHIPSET,
      G_INCL_HDMI             => G_INCL_HDMI,
      G_C20K                  => true,
      G_HDMI_SHADOW_SYS       => G_HDMI_SHADOW_SYS
   )
   port map (
      addr_i                  => i_phys_A,
      peripheral_sel_o        => open,
      peripheral_sel_oh_o     => i_peripheral_sel_oh
   );

   -- ================================================================================================ --
   -- CPU cycle state machine
   -- ================================================================================================ --

   p_state:process(fb_syscon_i)

      procedure mem_unsel is
      begin
         MEM_A_io <= (others => 'Z');
         MEM_RAM_nCE_o <= (others => '1');
         MEM_ROM_nCE_o <= '1';
         MEM_nOE_o <= '1';
         MEM_nWE_o <= '1';
      end mem_unsel;


      procedure mem_sel is
      begin
         mem_unsel;
         MEM_A_io(20 downto 8) <= r_phys_A(20 downto 8);

         if i_phys_A(23) = '1' then
            MEM_ROM_nCE_o <= '0';
            CPU_RDY_io <= '0'; -- slow for 55ns rom
         elsif i_phys_A(22 downto 21) = "11" then
            MEM_RAM_nCE_o(0) <= '0';
            CPU_RDY_io <= '1';
         else
            MEM_RAM_nCE_o(to_integer(unsigned(r_phys_A(22 downto 21)))+1) <= '0';
            CPU_RDY_io <= '1';
         end if;

-- DELAY by 1 cycle         MEM_nWE_o <= r_RnW;
      end mem_sel;

   begin
      if fb_syscon_i.rst = '1' then
         r_state      <= reset;
         r_had_fb_ack <= '0';
         r_was_ready  <= '0';
         r_fb_D_rd       <= (others => '0');

         fb_c2p_o <= fb_c2p_unsel;

         CPU_A_nOE_o <= '0';
         CPU_RDY_io <= '1';
         mem_unsel;
         MEM_D_io <= (others => '1');        -- pull D(5) high at reset (reconfig_n)
         r_A <= (others => '0');
      else
         if rising_edge(fb_syscon_i.clk) then
            case r_state is
               when reset =>
                  fb_c2p_o <= fb_c2p_unsel;
                  if i_ring_next(C_CPU_DIV_PHI2) = '1' then
                     r_state <= wait_asetup;
                     MEM_D_io <= (others => 'Z');
                  end if;
               when wait_asetup =>
                  fb_c2p_o <= fb_c2p_unsel;
                  if i_ring_next(C_CPU_DIV_ADS) = '0' and i_ring_next(C_CPU_DIV_ADS + 1) = '0' then
                     CPU_A_nOE_o <= '0';
                  else
                     CPU_A_nOE_o <= '1';
                  end if;
                  mem_unsel;
                  MEM_D_io <= (others => 'Z');

                  if i_ring_next(C_CPU_DIV_ADS + 1) = '1' then

                     if r_cyc_2M = '0' and i_throttle_act = '1' then
                        r_state <= cpu_skip;
                     elsif r_VPA = '0' and r_VDA = '0' then
                        CPU_RDY_io <= '1';
                        r_state <= dead;
                     else
                        if r_VPA = '1' and r_VDA = '1' then
                           debug_cpu_instr_a <= r_A;
                        end if;
                        
                        CPU_RDY_io <= '0';
                        r_was_ready <= '0';

                        r_phys_A <= i_phys_A;
                        r_peripheral_sel_oh <= i_peripheral_sel_oh;
                        r_state <= phys_a;

                     end if;
                  else
                     if i_boot = '1' then
                        if MEM_D_io = x"00" then
                           if MEM_A_io(20) = '0' and unsigned(MEM_A_io(4 downto 0)) <= 16#19# then
                              -- vector pull in Native mode or "new" ABORT/COP
                              -- get from 008Fxx
                              r_A <= x"008F" & MEM_A_io(7 downto 0);
                           else
                              -- bank 0 maps to FF in boot mode
                              r_A <= x"FF" & MEM_A_io(15 downto 0);
                           end if;
                        else
                           -- not bank 0 map direct
                           r_A <= MEM_D_io & MEM_A_io(15 downto 0);
                        end if;
                     else
                        -- not boot mode map direct
                        r_A <= MEM_D_io & MEM_A_io(15 downto 0);
                     end if;

                     r_VPA <= MEM_A_io(16);
                     r_VDA <= MEM_A_io(17);
                     r_MLB <= MEM_A_io(18);
                     r_RnW <= MEM_A_io(19);
                     r_VPB <= MEM_A_io(20);

                  end if;
               when phys_a =>
                  if i_peripheral_sel_oh(PERIPHERAL_NO_CHIPRAM) = '1' then
                     mem_sel;
                     -- local memory cycle
                     if r_RnW = '1' then
                        r_state <= read_local;
                     else
                        r_state <= write_local;
                     end if;
                  else
                     -- not local memory start a fishbone cycle
                     fb_c2p_o.cyc <= '1';
                     fb_c2p_o.A <= r_phys_A;
                     fb_c2p_o.A_stb <= '1';                     
                     r_had_fb_ack <= '0';
                     if r_RnW = '1' then
                        r_state <= read_fb;
                     else
                        fb_c2p_o.we <= '1';
                        r_state <= write_fb;
                     end if;
                  end if;

               when read_fb =>
                  if fb_c2p_o.A_stb = '1' and fb_p2c_i.stall = '0' then
                     fb_c2p_o.A_stb <= '0';
                  else
                     if fb_p2c_i.ack = '1' then
                        r_fb_D_rd <= fb_p2c_i.D_rd;
                        r_had_fb_ack <= '1';
                        fb_c2p_o.cyc <= '0';
                     end if;

                     if i_ring_next(C_CPU_DIV_PHI2_DSR) = '1' and r_had_fb_ack = '1' then
                        CPU_RDY_io <= '1';
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

                     if i_ring_next(C_CPU_DIV_PHI2_DSR) = '1' and (r_had_fb_ack = '1' or fb_p2c_i.ack = '1') then
                        r_was_ready <= '1';
                        CPU_RDY_io <= '1';
                     end if;

                     if r_was_ready = '1' and i_ring_next(C_CPU_DIV_PHI1_DHR) = '1' then
                        r_state <= wait_asetup;
                     end if;
                  end if;
               when read_local|write_local =>
                  MEM_nWE_o <= r_RnW;
                  -- assumes all reads complete in time - check
                  if CPU_RDY_io = '1' then
                     if i_ring_next(C_CPU_DIV_PHI2_DHR) = '1' then
                        MEM_nOE_o <= not r_RnW;
                     end if;
                     
                     if i_ring_next(C_CPU_DIV_PHI1_DHR) = '1' then
                        r_state <= wait_asetup;
                        CPU_A_nOE_o <= '0';
                        mem_unsel;
                     end if;
                  else
                     if i_ring_next(C_CPU_DIV_PHI1_DHR) = '1' then
                        CPU_RDY_io <= '1';
                     end if;
                  end if;
               when dead =>
                  if i_ring_next(0) = '1' then
                     r_state <= wait_asetup;
                  end if;
               when cpu_skip =>
                  if i_ring_next(0) = '1' then
                     r_state <= wait_asetup;
                  end if;

            end case;
         end if;
      end if;
      
   end process;

   -- ================================================================================================ --
   -- WDM detect
   -- ================================================================================================ --

   p_wdm:process(fb_syscon_i)
   begin
      if fb_syscon_i.rst = '1' then
         r_WDM <= '0';
      elsif rising_edge(fb_syscon_i.clk) then
         if i_ring_next(0) = '1' then
            if MEM_D_io = x"42" and r_VDA = '1' and r_VPA = '1' and CPU_RDY_io = '1' then
               r_WDM <= '1';
            else
               r_WDM <= '0';
            end if;
         end if;
      end if;
   end process;

   -- ================================================================================================ --
   -- ABORT generation
   -- ================================================================================================ --

   p_abort:process(fb_syscon_i)
   begin
      if fb_syscon_i.rst = '1' then
         CPU_nABORT_o <= '1';
         r_debug_abort_n_ack <= '1';
      elsif rising_edge(fb_syscon_i.clk) then
         if i_ring_next(C_CPU_DIV_PHI2-2) = '1' then                    
            if debug_btn_n_i = '1' then
               r_debug_abort_n_ack <= '1';
            end if;

            if (debug_btn_n_i = '0' and r_debug_abort_n_ack = '1') or r_WDM = '1' then
               r_debug_abort_n_ack <= '0';
               CPU_nABORT_o <= '0';
            else
               CPU_nABORT_o <= '1';
            end if;

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



--=======================================================================================
-- 65816 "boot" mode, in boot mode all accesses are to bank FF
--=======================================================================================

   -- the boot signal is delayed such that it doesn't take effect until the next instruction
   -- fetch after the subsequent instruction to allow a long jump from the boot bank after
   -- the boot flag is removed

   p_boot_65816_dly:process(fb_syscon_i)
   begin
      if fb_syscon_i.rst = '1' then
         r_boot_65816_dly <= (others => '1');
      elsif rising_edge(fb_syscon_i.clk) then
         if i_ring_next(0) = '1' and r_VPA = '1' and r_VDA = '1' and CPU_RDY_io = '1' then
            r_boot_65816_dly <= r_boot_65816_dly(r_boot_65816_dly'high-1 downto 0) & boot_65816_i(1);
         end if;
      end if;

   end process;

   -- boot (or not boot) is taken one cpu cycle early when instruction fetch
   -- NOTE: This allows two instruction in the previous mode before switching - not one!
   i_boot <=   CPU_E_i when boot_65816_i(0) = '1' else
               r_boot_65816_dly(1) when r_VPA = '1' and r_VDA = '1' else
               r_boot_65816_dly(2);



   CPU_BE_o <= '1';

   debug_cpu_state_o <= std_logic_vector(to_unsigned(t_state'pos(r_state), 3));
end rtl;

-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2022 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:      8/10/2026
-- Design Name: 
-- Module Name:      mk2blit
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      Simple cut down mk.2 Blitter to bring up new fishbone stuff
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--use work.mk1board_types.all;

library work;
use work.common.all;
use work.fishbone.all;
use work.board_config_pack.all;
use work.fb_SYS_pack.all;
use work.fb_CPU_pack.all;
use work.fb_CPU_exp_pack.all;
use work.fb_intcon_pack.all;

entity mk2blit is
   generic (
      SIM                           : boolean := false;                    -- skip some stuff, i.e. slow sdram start up
      CLOCKSPEED                    : natural := 128;                      -- fast clock speed in mhz          
      G_DWRITE_HOLD                 : natural := 6;                        -- hold write data on system bus for this many cycles
      PROJECT_ROOT                  : string  := "../"                     -- path to root of project (to find relative files, override in simulations)
   );
   port(
      -- crystal osc 48MHz - not fitted on blit board
      CLK_48M_i                     : in     std_logic;  

      -- crystal osc 50Mhz - on WS board
      CLK_50M_i                     : in     std_logic;
   
      -- 2M RAM/256K ROM bus
      MEM_A_o                       : out    std_logic_vector(20 downto 0);
      MEM_D_io                      : inout  std_logic_vector(7 downto 0);
      MEM_nOE_o                     : out    std_logic;
      MEM_ROM_nWE_o                 : out    std_logic;
      MEM_RAM_nWE_o                 : out    std_logic;
      MEM_ROM_nCE_o                 : out    std_logic;
      MEM_RAM0_nCE_o                : out    std_logic;
      
      -- 1 bit DAC sound out stereo, aux connectors mirror main
      SND_BITS_L_o                  : out    std_logic;
      SND_BITS_L_AUX_o              : out    std_logic;
      SND_BITS_R_o                  : out    std_logic;
      SND_BITS_R_AUX_o              : out    std_logic;
      
      --    SYS bus connects to SYStem CPU socket


      SUP_nRESET_i                  : in     std_logic;                       -- SYStem reset after supervisor
      EXT_nRESET_i                  : in     std_logic;                       -- WS button

      SYS_A_o                       : out    std_logic_vector(15 downto 0);
      SYS_D_io                      : inout  std_logic_vector(7 downto 0);
      
      -- SYS signals are connected direct to the BBC cpu socket
      SYS_RDY_i                     : in     std_logic; -- Master only?
      SYS_nNMI_i                    : in     std_logic;
      SYS_nIRQ_i                    : in     std_logic;
      SYS_SYNC_o                    : out    std_logic;
      SYS_PHI0_i                    : in     std_logic;
      SYS_PHI1_o                    : out    std_logic;
      SYS_PHI2_o                    : out    std_logic;
      SYS_RnW_o                     : out    std_logic;


      -- CPU sockets, shared lines for 6502/65102/65816/6809,Z80,68008
      -- shared names are of the form CPUSKT_aaa[C[bbb][6ccc][9ddd][Keee][Zfff]
      -- aaa = NMOS 6502 and other 6502 derivatives (65c02, 65816) unless overridden
      -- bbb = CMOS 65C102-(if directly followed by 6ccc use that interpretation)
      -- ccc = WDC 65816   
      -- ddd = 6309/6809
      -- eee = Z80
      -- fff = MC68008

      -- NC indicates Not Connected in a mode

      CPUSKT_A_i                          : in     std_logic_vector(19 downto 0);
      CPUSKT_D_io                         : inout  std_logic_vector(7 downto 0);

      CPUSKT_6EKEZnRD_i                   : in     std_logic;     
      CPUSKT_C6nML9BUSYKnBGZnBUSACK_i     : in     std_logic;
      CPUSKT_RnWZnWR_i                    : in     std_logic;
      CPUSKT_PHI16ABRT9BSKnDS_io          : inout  std_logic;     -- 6ABRT is actually an output but pulled up on the board
      CPUSKT_PHI26VDAKFC0ZnMREQ_i         : in     std_logic;
      CPUSKT_SYNC6VPA9LICKFC2ZnM1_i       : in     std_logic;
      CPUSKT_VSS6VPB9BAKnAS_i             : in     std_logic;
      CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i     : in     std_logic;     -- nSO is actually an output but pulled up on the board


      CPUSKT_6BE9TSCKnVPA_o               : out    std_logic;
      CPUSKT_9Q_o                         : out    std_logic;
      CPUSKT_KnBRZnBUSREQ_o               : out    std_logic;
      CPUSKT_PHI09EKZCLK_o                : out    std_logic;
      CPUSKT_RDY9KnHALTZnWAIT_o           : out    std_logic;
      CPUSKT_nIRQKnIPL1_o                 : out    std_logic;
      CPUSKT_nNMIKnIPL02_o                : out    std_logic;
      CPUSKT_nRES_o                       : out    std_logic;
      CPUSKT_9nFIRQLnDTACK_o              : out    std_logic;

      -- LEDs 
      LED_o                               : out    std_logic_vector(3 downto 0);

      -- CONFIG / TEST connector

      CFG_io                              : inout  std_logic_vector(15 downto 0);

      -- configuration memory SPI/Flash
      flash_ck_o                          : out    std_logic;
      flash_cs_o                          : out    std_logic;
      flash_miso_i                        : in     std_logic;
      flash_mosi_o                        : out    std_logic;

      -- i2c EEPROM
      I2C_SCL_io                          : inout  std_logic;
      I2C_SDA_io                          : inout  std_logic

   );
end mk2blit;

architecture rtl of mk2blit is
   

   -----------------------------------------------------------------------------
   -- fishbone signals
   -----------------------------------------------------------------------------

   signal i_fb_syscon         : fb_syscon_t;                   -- shared bus signals

   -- cpu wrapper
   signal i_c2p_cpu           : fb_con_o_per_i_t;
   signal i_p2c_cpu           : fb_con_i_per_o_t;

   -- cpu beeb motherboard wrapper
   signal i_c2p_sys           : fb_con_o_per_i_t;
   signal i_p2c_sys           : fb_con_i_per_o_t;

   -- inferred memory wrapper
   signal i_c2p_mem           : fb_con_o_per_i_t;
   signal i_p2c_mem           : fb_con_i_per_o_t;

   -- intcon controller->peripheral
   signal i_con_c2p_intcon    : fb_con_o_per_i_arr(CONTROLLER_COUNT-1 downto 0);
   signal i_con_p2c_intcon    : fb_con_i_per_o_arr(CONTROLLER_COUNT-1 downto 0);
   -- intcon peripheral->controller
   signal i_per_c2p_intcon    : fb_con_o_per_i_arr(PERIPHERAL_COUNT-1 downto 0);
   signal i_per_p2c_intcon    : fb_con_i_per_o_arr(PERIPHERAL_COUNT-1 downto 0);

   -----------------------------------------------------------------------------
   -- inter component (non-fishbone) signals
   -----------------------------------------------------------------------------

   signal i_JIM_en                  : std_logic;                     -- local jim device enable
   signal i_JIM_page                : std_logic_vector(15 downto 0); -- the actual mapping is done in the cpu component address
                                                                     -- translator (and is not available to the rest of the 
                                                                     -- chipset)

   signal i_sys_ROMPG               : std_logic_vector(7 downto 0);  -- a shadow copy of the mainboard rom
                                                                     -- paging register, used to select
                                                                     -- on board paged roms from flash/sram

   signal i_flasher                 : std_logic_vector(3 downto 0);  -- a simple set of slow clocks for generating flashing 
                                                                     -- LED sfishals
   signal i_clk_fish_128M           : std_logic;                     -- the main system clock from the pll - don't use this
                                                                     -- use fb_syscon.clk
   signal i_clk_lock                : std_logic;                     -- indicates whether the main pll is locked
   signal i_sys_dll_lock            : std_logic;                     -- indicates whether the system dll is locked

   -- intcon to peripheral sel
   signal i_intcon_peripheral_sel_addr    : fb_arr_std_logic_vector(CONTROLLER_COUNT-1 downto 0)(23 downto 0);
   signal i_intcon_peripheral_sel_we      : std_logic_vector(CONTROLLER_COUNT-1 downto 0);
   signal i_intcon_peripheral_sel         : fb_arr_unsigned(CONTROLLER_COUNT-1 downto 0)(numbits(PERIPHERAL_COUNT)-1 downto 0);  -- address decoded selected peripheral
   signal i_intcon_peripheral_sel_oh      : fb_arr_std_logic_vector(CONTROLLER_COUNT-1 downto 0)(PERIPHERAL_COUNT-1 downto 0);   -- address decoded selected peripherals as one-hot    

   -----------------------------------------------------------------------------
   -- cpu control signals
   -----------------------------------------------------------------------------
   signal i_cpu_IRQ_n               : std_logic;

   signal i_cpu_2MHz_phi2_clken     : std_logic;

   -----------------------------------------------------------------------------
   -- cpu expansion header wrapper signals
   -----------------------------------------------------------------------------
   signal i_wrap_exp_o              : t_cpu_wrap_exp_o;
   signal i_wrap_exp_i              : t_cpu_wrap_exp_i;


begin

   e_fb_clocks: entity work.clocks_pll
   generic map (
      SIM =>   SIM,
      CLOCKSPEED => CLOCKSPEED
   )
   port map (
      EXT_nRESET_i                  => SUP_nRESET_i,
      EXT_CLK_50M_i                 => CLK_50M_i,

      clk_fish_o                    => i_clk_fish_128M,
      clk_snd_o                     => open,

      clk_lock_o                    => i_clk_lock,

      flasher_o                     => i_flasher

   ); 


   e_fb_syscon: entity work.fb_syscon
   generic map (
      SIM => SIM,
      CLOCKSPEED => CLOCKSPEED
   )
   port map (
      fb_syscon_o                   => i_fb_syscon,

      EXT_nRESET_i                  => SUP_nRESET_i,
      EXT_nRESET_power_i               => '1',

      clk_fish_i                    => i_clk_fish_128M,
      clk_lock_i                    => i_clk_lock,
      sys_dll_lock_i                => i_sys_dll_lock

   ); 

g_addr_decode:for I in CONTROLLER_COUNT-1 downto 0 generate
   -- address decode to select peripheral
   e_addr2s:entity work.address_decode_simple
   port map (
      addr_i                  => i_intcon_peripheral_sel_addr(I),
      we_i                    => i_intcon_peripheral_sel_we(I),
      peripheral_sel_o        => i_intcon_peripheral_sel(I),
      peripheral_sel_oh_o     => i_intcon_peripheral_sel_oh(I)
   );
end generate;

g_intcon_o2m:IF CONTROLLER_COUNT = 1 GENERATE
   e_fb_intcon: fb_intcon_one_to_many
   generic map (
      G_PERIPHERAL_COUNT            => PERIPHERAL_COUNT
      )
   port map (
      fb_syscon_i                   => i_fb_syscon,

      -- upstream ports connect to controllers
      fb_up_c2p_i                   => i_con_c2p_intcon(0),
      fb_up_p2c_o                   => i_con_p2c_intcon(0),

      -- downstream ports connect to peripherals
      fb_dn_c2p_o                   => i_per_c2p_intcon,
      fb_dn_p2c_i                   => i_per_p2c_intcon,

      peripheral_sel_addr_o         => i_intcon_peripheral_sel_addr(0),
      peripheral_sel_we_o           => i_intcon_peripheral_sel_we(0),
      peripheral_sel_i              => i_intcon_peripheral_sel(0),
      peripheral_sel_oh_i           => i_intcon_peripheral_sel_oh(0)
   );


END GENERATE;

   i_con_c2p_intcon(MAS_NO_CPU)        <= i_c2p_cpu;
   i_per_p2c_intcon(PERIPHERAL_NO_CHIPRAM)   <= i_p2c_mem;
   i_per_p2c_intcon(PERIPHERAL_NO_SYS)    <= i_p2c_sys;

   i_p2c_cpu            <= i_con_p2c_intcon(MAS_NO_CPU);
   i_c2p_mem            <= i_per_c2p_intcon(PERIPHERAL_NO_CHIPRAM);
   i_c2p_sys            <= i_per_c2p_intcon(PERIPHERAL_NO_SYS);


   e_fb_mem: entity work.fb_inferred_mem_altera
   generic map (
      G_ADDR_W => 10,   -- 1024
      G_READONLY => false
      )
   port map (

      -- fishbone signals

      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_i                      => i_c2p_mem,
      fb_p2c_o                      => i_p2c_mem

   );

   e_fb_sys: entity work.fb_sys
   generic map (
      SIM => SIM,
      CLOCKSPEED => CLOCKSPEED,
      G_JIM_DEVNO => G_JIM_DEVNO,
      G_DWRITE_HOLD => G_DWRITE_HOLD
   )
   port map (
      cfg_sys_type_i                => SYS_BBC,

      SYS_A_o                       => SYS_A_o,
      SYS_D_io                      => SYS_D_io,
      SYS_RDY_i                     => SYS_RDY_i,
      SYS_SYNC_o                    => SYS_SYNC_o,
      SYS_PHI0_i                    => SYS_PHI0_i,
      SYS_PHI1_o                    => SYS_PHI1_o,
      SYS_PHI2_o                    => SYS_PHI2_o,
      SYS_RnW_o                     => SYS_RnW_o,

      -- fishbone signals
      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_i                      => i_c2p_sys,
      fb_p2c_o                      => i_p2c_sys,

      -- generated extra signals

      sys_ROMPG_o                   => i_sys_ROMPG,

      sys_dll_lock_o                => i_sys_dll_lock,

      debug_sys_rd_ack_o            => open,

      dbg_lock_o                    => open,
      dbg_fast_o                    => open,
      dbg_slow_o                    => open,
      dbg_cycle_o                   => open,

      JIM_page_o                    => i_JIM_page,
      JIM_en_o                      => i_JIM_en,

      cpu_2MHz_phi2_clken_o         => i_cpu_2MHz_phi2_clken,

      debug_sys_D_dir               => open


   );


   e_fb_cpu: entity work.fb_cpu
   generic map (
      SIM => SIM,
      CLOCKSPEED => CLOCKSPEED
   )
   port map (

      -- configuration

      cfg_cpu_type_i                => NONE,
      cfg_cpu_use_t65_i             => '1',
      cfg_cpu_speed_opt_i           => NONE,
      cfg_sys_type_i                => SYS_BBC,
      cfg_swram_enable_i            => '0',
      cfg_mosram_i                  => '0',
      cfg_map0n1_i                  => '1',

      -- cpu throttle

      throttle_all_i                => '0',
      throttle_mos_i                => '0',
      cpu_2MHz_phi2_clken_i         => i_cpu_2MHz_phi2_clken,
      rom_throttle_map_i            => (others => '1'),
      rom_autohazel_map_i           => (others => '0'),

      -- wrapper expansion header/socket pins
      wrap_exp_i                    => i_wrap_exp_i,
      wrap_exp_o                    => i_wrap_exp_o,

      hard_cpu_en_o                 => open,

      -- memctl signals
      swmos_shadow_i                => '0',

      -- noice debugger signals to cpu
      noice_debug_nmi_n_i           => '1',
      noice_debug_shadow_i          => '0',
      noice_debug_inhibit_cpu_i     => '0',
      -- noice debugger signals from cpu
      noice_debug_5c_o              => open,
      noice_debug_cpu_clken_o       => open,
      noice_debug_A0_tgl_o          => open,
      noice_debug_opfetch_o         => open,


      -- logical mappings
      sys_ROMPG_i                   => i_sys_ROMPG,   
      turbo_lo_mask_i               => (others => '0'),
      JIM_en_i                      => i_JIM_en,      
      JIM_page_i                    => i_JIM_page,

      -- direct CPU control signals from system
      nmi_n_i                       => SYS_nNMI_i,
      irq_n_i                       => i_cpu_IRQ_n,

      -- fishbone signals
      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_o                      => i_c2p_cpu,
      fb_p2c_i                      => i_p2c_cpu,

      -- chipset control signals
      cpu_halt_i                    => '0',

      boot_65816_i                  => (others => '0'),
      window_65816_i                => (others => '0'),
      window_65816_wr_en_i          => '0',

      -- preboot
      preboot_i                     => '0',

      debug_wrap_cyc_o              => open,

      debug_65816_vma_o             => open

   );

   i_cpu_IRQ_n <= SYS_nIRQ_i; 

   --===========================================================
   -- CPU wrap external pins to/from typed objects to allow same
   -- fb_CPU to be used for mk2/3 boards -- signals will be 
   -- unpacked in lower level wrappers by fb_CPU_xxx_exp_pins 
   -- components
   --===========================================================

   i_wrap_exp_i.CPUSKT_6EKEZnRD                 <= CPUSKT_6EKEZnRD_i;
   i_wrap_exp_i.CPUSKT_C6nML9BUSYKnBGZnBUSACK   <= CPUSKT_C6nML9BUSYKnBGZnBUSACK_i;
   i_wrap_exp_i.CPUSKT_RnWZnWR                  <= CPUSKT_RnWZnWR_i;
   i_wrap_exp_i.CPUSKT_PHI16ABRT9BSKnDS         <= CPUSKT_PHI16ABRT9BSKnDS_io;
   i_wrap_exp_i.CPUSKT_PHI26VDAKFC0ZnMREQ       <= CPUSKT_PHI26VDAKFC0ZnMREQ_i;
   i_wrap_exp_i.CPUSKT_SYNC6VPA9LICKFC2ZnM1     <= CPUSKT_SYNC6VPA9LICKFC2ZnM1_i;
   i_wrap_exp_i.CPUSKT_VSS6VPB9BAKnAS           <= CPUSKT_VSS6VPB9BAKnAS_i;
   i_wrap_exp_i.CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ   <= CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i;
   i_wrap_exp_i.CPUSKT_D                        <= CPUSKT_D_io;
   i_wrap_exp_i.CPUSKT_A                        <= CPUSKT_A_i;

   CPUSKT_PHI16ABRT9BSKnDS_io <= i_wrap_exp_o.CPUSKT_PHI16ABRT9BSKnDS when i_wrap_exp_o.CPUSKT_PHI16ABRT9BSKnDS_nOE = '0' else
                                 'Z';

   CPUSKT_6BE9TSCKnVPA_o      <= i_wrap_exp_o.CPUSKT_6BE9TSCKnVPA;
   CPUSKT_9Q_o                <= i_wrap_exp_o.CPUSKT_9Q;
   CPUSKT_KnBRZnBUSREQ_o      <= i_wrap_exp_o.CPUSKT_KnBRZnBUSREQ;
   CPUSKT_PHI09EKZCLK_o       <= i_wrap_exp_o.CPUSKT_PHI09EKZCLK;
   CPUSKT_RDY9KnHALTZnWAIT_o  <= i_wrap_exp_o.CPUSKT_RDY9KnHALTZnWAIT;
   CPUSKT_nIRQKnIPL1_o        <= i_wrap_exp_o.CPUSKT_nIRQKnIPL1;
   CPUSKT_nNMIKnIPL02_o       <= i_wrap_exp_o.CPUSKT_nNMIKnIPL02;
   CPUSKT_nRES_o              <= i_wrap_exp_o.CPUSKT_nRES;
   CPUSKT_9nFIRQLnDTACK_o     <= i_wrap_exp_o.CPUSKT_9nFIRQLnDTACK;


   CPUSKT_D_io       <= (others => 'Z') when i_wrap_exp_o.CPU_D_RnW = '0' else
                        i_wrap_exp_o.CPUSKT_D;



--------------------------------------------------------------------------------
-- Default signals
--------------------------------------------------------------------------------

   MEM_A_o        <= (others => '0');
   MEM_D_io       <= (others => 'Z');
   MEM_nOE_o      <= '1';
   MEM_ROM_nWE_o  <= '1';
   MEM_RAM_nWE_o  <= '1';
   MEM_ROM_nCE_o  <= '1';
   MEM_RAM0_nCE_o <= '1';

   SND_BITS_L_o <= '0';
   SND_BITS_R_o <= '0';
   SND_BITS_L_aux_o <= '0';
   SND_BITS_R_aux_o <= '0';

   flash_ck_o <= '0';
   flash_cs_o <= '1';
   flash_mosi_o <= '0';

   I2C_SCL_io <= 'Z';
   I2C_SDA_io <= 'Z';


CFG_io <= (others => 'Z');


LED_o(0) <= '0'          when i_fb_syscon.rst_state = reset else
            i_flasher(3) when i_fb_syscon.rst_state = powerup else
            i_flasher(2) when i_fb_syscon.rst_state = resetfull else
            i_flasher(0) when i_fb_syscon.rst_state = lockloss else
            '1'          when i_fb_syscon.rst_state = run else
            i_flasher(1);
LED_o(1) <= '1';
LED_o(2) <= not i_JIM_en;
LED_o(3) <= '1';


end rtl;

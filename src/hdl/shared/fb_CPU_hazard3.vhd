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

-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	30/11/2024
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - picorv32 soft core
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the picorv32 core
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.fishbone.all;
use work.board_config_pack.all;
use work.fb_cpu_pack.all;
use work.fb_cpu_exp_pack.all;


entity fb_cpu_hazard3 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;										-- fast clock speed in mhz						
		CLKEN_DLY_MAX						: natural 	:= 2;								-- used to time latching of address etc signals			
		MAXSPEED								: natural := 32
	);
	port(
		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		fb_syscon_i								: in	fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i

	);
end fb_cpu_hazard3;

architecture rtl of fb_cpu_hazard3 is


	


	signal i_rv_addr 			: std_logic_vector(31 downto 0);
	signal i_rv_htrans		: std_logic_vector(1 downto 0);
	signal i_rv_hsize			: std_logic_vector(2 downto 0);
	signal i_rv_hprot			: std_logic_vector(3 downto 0);
	signal i_rv_write			: std_logic;

	signal r_rv_rdata			: std_logic_vector(31 downto 0);
	signal i_rv_wdata			: std_logic_vector(31 downto 0);
	signal i_rv_irq			: std_logic_vector(2 downto 0);
	signal i_rv_hready		: std_logic;

	signal i_rv_res_n			: std_logic;

	signal i_pwrup_req_tieback : std_logic;


	signal r_wrap_cyc					: std_logic;
	signal r_lane_req					: std_logic_vector(3 downto 0);
	signal r_lane_wrstb				: std_logic_vector(3 downto 0);
	signal r_we							: std_logic;
	signal r_instr						: std_logic;
	signal r_addr						: std_logic_vector(23 downto 0);
	signal r_rv_mem_ready			: std_logic;
	signal r_wrap_wdata				: std_logic_vector(31 downto 0);

	-- from addr phase to controller
	signal r_next_wrap_cyc			: std_logic;
	signal r_next_lane_req			: std_logic_vector(3 downto 0);
	signal r_next_we					: std_logic;
	signal r_next_instr				: std_logic;
	signal r_next_addr				: std_logic_vector(23 downto 0);
	signal r_rv_addr_ready			: std_logic;


	type state_t is (idle, rd, wr, goidle);

	signal r_state				: state_t;


component hazard3_cpu_1port is
   generic (
-- Hazard3 CPU configuration parameters

-- To configure Hazard3 you can either edit this file, or set parameters on
-- your top-level instantiation, it's up to you. These parameters are all
-- plumbed through Hazard3's internal hierarchy to the appropriate places.

-- If you add a parameter here, you should add a matching line to
-- hazard3_config_inst.vh to propagate the parameter through module
-- instantiations.

-- ----------------------------------------------------------------------------
-- Reset state configuration

-- RESET_VECTOR: Address of first instruction executed.
      RESET_VECTOR        : std_logic_vector(31 downto 0) := x"00000000";

-- MTVEC_INIT: Initial value of trap vector base. Bits clear in MTVEC_WMASK
-- will never change from this initial value. Bits set in MTVEC_WMASK can be
-- written/set/cleared as normal.
--
-- Note that mtvec bits 1:0 do not affect the trap base (as per RISC-V spec).
-- Bit 1 is don't care, bit 0 selects the vectoring mode: unvectored if == 0
-- (all traps go to mtvec), vectored if == 1 (exceptions go to mtvec, IRQs to
-- mtvec + mcause * 4). This means MTVEC_INIT also sets the initial vectoring
-- mode.
      MTVEC_INIT          : std_logic_vector(31 downto 0) := x"00000000";

-- ----------------------------------------------------------------------------
-- Standard RISC-V ISA support

-- EXTENSION_A: Support for atomic read/modify/write instructions
      EXTENSION_A : boolean := true;

-- EXTENSION_C: Support for compressed (variable-width) instructions
      EXTENSION_C : boolean := true;

-- EXTENSION_M: Support for hardware multiply/divide/modulo instructions
      EXTENSION_M : boolean := true;

-- EXTENSION_ZBA: Support for Zba address generation instructions
      EXTENSION_ZBA : boolean := false;

-- EXTENSION_ZBB: Support for Zbb basic bit manipulation instructions
      EXTENSION_ZBB : boolean := false;

-- EXTENSION_ZBC: Support for Zbc carry-less multiplication instructions
      EXTENSION_ZBC : boolean := false;

-- EXTENSION_ZBS: Support for Zbs single-bit manipulation instructions
      EXTENSION_ZBS : boolean := false;

-- EXTENSION_ZBKB: Support for Zbkb basic bit manipulation for cryptography
-- Requires: Zbb. (This flag enables instructions in Zbkb which aren't in Zbb.)
      EXTENSION_ZBKB : boolean := false;

-- EXTENSION_ZCB: Support for Zcb basic additional compressed instructions
-- Requires: EXTENSION_C. (Some Zcb instructions also require Zbb or M.)
-- Note Zca is equivalent to C, as we do not support the F extension.
      EXTENSION_ZCB : boolean := false;

-- EXTENSION_ZCMP: Support for Zcmp push/pop instructions.
-- Requires: EXTENSION_C.
      EXTENSION_ZCMP : boolean := false;

-- EXTENSION_ZIFENCEI: Support for the fence.i instruction
-- Optional, since a plain branch/jump will also flush the prefetch queue.
      EXTENSION_ZIFENCEI : boolean := false;

-- ----------------------------------------------------------------------------
-- Custom RISC-V extensions

-- EXTENSION_XH3B: Custom bit-extract-multiple instructions for Hazard3
      EXTENSION_XH3BEXTM : boolean := false;

-- EXTENSION_XH3IRQ: Custom preemptive, prioritised interrupt support. Can be
-- disabled if an external interrupt controller (e.g. PLIC) is used. If
-- disabled, and NUM_IRQS > 1, the external interrupts are simply OR'd into
-- mip.meip.
      EXTENSION_XH3IRQ : boolean := false;

-- EXTENSION_XH3PMPM: PMPCFGMx CSRs to enforce PMP regions in M-mode without
-- locking. Unlike ePMP mseccfg.rlb, locked and unlocked regions can coexist
      EXTENSION_XH3PMPM : boolean := false;

-- EXTENSION_XH3POWER: Custom power management controls for Hazard3
      EXTENSION_XH3POWER : boolean := false;

-- ----------------------------------------------------------------------------
-- Standard CSR support

-- Note the Zicsr extension is implied by any of CSR_M_MANDATORY, CSR_M_TRAP,
-- CSR_COUNTER.

-- CSR_M_MANDATORY: Bare minimum CSR support e.g. misa. Spec says must = 1 if
-- CSRs are present, but I won't tell anyone.
      CSR_M_MANDATORY : boolean := true;

-- CSR_M_TRAP: Include M-mode trap-handling CSRs, and enable trap support.
      CSR_M_TRAP : boolean := true;

-- CSR_COUNTER: Include performance counters and Zicntr CSRs
      CSR_COUNTER : boolean := false;

-- U_MODE: Support the U (user) execution mode. In U mode, the core performs
-- unprivileged bus accesses, and software's access to CSRs is restricted.
-- Additionally, if the PMP is included, the core may restrict U-mode
-- software's access to memory.
-- Requires: CSR_M_TRAP.
      U_MODE : boolean := false;


-- DEBUG_SUPPORT: Support for run/halt and instruction injection from an
-- external Debug Module, support for Debug Mode, and Debug Mode CSRs.
-- Requires: CSR_M_MANDATORY, CSR_M_TRAP.
      DEBUG_SUPPORT : boolean := false;

-- BREAKPOINT_TRIGGERS: Number of triggers which support type=2 execute=1
-- (but not store/load=1, i.e. not a watchpoint). Requires: DEBUG_SUPPORT
      BREAKPOINT_TRIGGERS : natural := 0;

-- ----------------------------------------------------------------------------
-- External interrupt support

-- NUM_IRQS: Number of external IRQs. Minimum 1, maximum 512. Note that if
-- EXTENSION_XH3IRQ (Hazard3 interrupt controller) is disabled then multiple
-- external interrupts are simply OR'd into mip.meip.
      NUM_IRQS : natural := 0;

-- IRQ_PRIORITY_BITS: Number of priority bits implemented for each interrupt
-- in meipra, if EXTENSION_XH3IRQ is enabled. The number of distinct levels
-- is (1 << IRQ_PRIORITY_BITS). Minimum 0, max 4. Note that multiple priority
-- levels with a large number of IRQs will have a severe effect on timing.
      IRQ_PRIORITY_BITS : natural := 0;


-- ----------------------------------------------------------------------------
-- Performance/size options

-- REDUCED_BYPASS: Remove all forwarding paths except X->X (so back-to-back
-- ALU ops can still run at 1 CPI), to save area.
      REDUCED_BYPASS : boolean := false;

-- MULDIV_UNROLL: Bits per clock for multiply/divide circuit, if present. Must
-- be a power of 2.
      MULDIV_UNROLL : natural := 1;

-- MUL_FAST: Use single-cycle multiply circuit for MUL instructions, retiring
-- to stage 3. The sequential multiply/divide circuit is still used for MULH*
      MUL_FAST : boolean := false;

-- MUL_FASTER: Retire fast multiply results to stage 2 instead of stage 3.
-- Throughput is the same, but latency is reduced from 2 cycles to 1 cycle.
-- Requires: MUL_FAST.
      MUL_FASTER : boolean := false;

-- MULH_FAST: extend the fast multiply circuit to also cover MULH*, and remove
-- the multiply functionality from the sequential multiply/divide circuit.
-- Requires: MUL_FAST
      MULH_FAST : boolean := false;

-- FAST_BRANCHCMP: Instantiate a separate comparator (eq/lt/ltu) for branch
-- comparisons, rather than using the ALU. Improves fetch address delay,
-- especially if Zba extension is enabled. Disabling may save area.
      FAST_BRANCHCMP : boolean := true;

-- RESET_REGFILE: whether to support reset of the general purpose registers.
-- There are around 1k bits in the register file, so the reset can be
-- disabled e.g. to permit block-RAM inference on FPGA.
      RESET_REGFILE : boolean := false;

-- BRANCH_PREDICTOR: enable branch prediction. The branch predictor consists
-- of a single BTB entry which is allocated on a taken backward branch, and
-- cleared on a mispredicted nontaken branch, a fence.i or a trap. Successful
-- prediction eliminates the 1-cyle fetch bubble on a taken branch, usually
-- making tight loops faster.
      BRANCH_PREDICTOR : boolean := false;

-- MTVEC_WMASK: Mask of which bits in mtvec are writable. Full writability is
-- recommended, because a common idiom in setup code is to set mtvec just
-- past code that may trap, as a hardware "try {...} catch" block.
--
-- - The vectoring mode can be made fixed by clearing the LSB of MTVEC_WMASK
--
-- - In vectored mode, the vector table must be aligned to its size, rounded
--   up to a power of two.
      MTVEC_WMASK         : std_logic_vector(31 downto 0) := x"fffffffd";

		W_ADDR              : natural := 32;   -- Do not modify
		W_DATA              : natural := 32    -- Do not modify



   );
   port (
   -- Global signals
         clk                        :  in    std_logic;
         clk_always_on              :  in    std_logic;
         rst_n                      :  in    std_logic;


   -- Power control signals
         pwrup_req                  :  out      std_logic;
         pwrup_ack                  :  in       std_logic;
         clk_en                     :  out      std_logic;
         unblock_out                :  out      std_logic;
         unblock_in                 :  in       std_logic;

   -- AHB5 Master port
         haddr                      :  out      std_logic_vector(W_ADDR-1 downto 0);
         hwrite                     :  out      std_logic;
         htrans                     :  out      std_logic_vector(1 downto 0);
         hsize                      :  out      std_logic_vector(2 downto 0);
         hburst                     :  out      std_logic_vector(2 downto 0);
         hprot                      :  out      std_logic_vector(3 downto 0);
         hmastlock                  :  out      std_logic;
         hmaster                    :  out      std_logic_vector(7 downto 0);
         hexcl                      :  out      std_logic;
         hready                     :  in       std_logic;
         hresp                      :  in       std_logic;
         hexokay                    :  in       std_logic;
         hwdata                     :  out      std_logic_vector(W_DATA-1 downto 0);
         hrdata                     :  in       std_logic_vector(W_DATA-1 downto 0);

   -- Debugger run/halt control
         dbg_req_halt               :  in       std_logic;
         dbg_req_halt_on_reset      :  in       std_logic;
         dbg_req_resume             :  in       std_logic;
         dbg_halted                 :  out      std_logic;
         dbg_running                :  out      std_logic;
   -- Debugger access to data0 CSR
         dbg_data0_rdata            :  in       std_logic_vector(W_DATA-1 downto 0);
         dbg_data0_wdata            :  out      std_logic_vector(W_DATA-1 downto 0);
         dbg_data0_wen              :  out      std_logic;
   -- Debugger instruction injection
         dbg_instr_data             :  in       std_logic_vector(W_DATA-1 downto 0);
         dbg_instr_data_vld         :  in       std_logic;
         dbg_instr_data_rdy         :  out      std_logic;
         dbg_instr_caught_exception :  out      std_logic;
         dbg_instr_caught_ebreak    :  out      std_logic;

   -- Optional debug system bus access patch-through
         dbg_sbus_addr              :  in       std_logic_vector(W_ADDR-1 downto 0);
         dbg_sbus_write             :  in       std_logic;
         dbg_sbus_size              :  in       std_logic_vector(1 downto 0);
         dbg_sbus_vld               :  in       std_logic;
         dbg_sbus_rdy               :  out      std_logic;
         dbg_sbus_err               :  out      std_logic;
         dbg_sbus_wdata             :  in       std_logic_vector(W_DATA-1 downto 0);
         dbg_sbus_rdata             :  out      std_logic_vector(W_DATA-1 downto 0);

   -- Level-sensitive interrupt sources
         irq                        :  in       std_logic_vector(2 downto 0);       -- -> mip.meip
         soft_irq                   :  in       std_logic;  -- -> mip.msip
         timer_irq                  :  in       std_logic   -- -> mip.mtip

   );
end component;


begin

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity error;

	-- NOTE: need to latch address on dly(1) not dly(0) as it was unreliable

	wrap_o.BE				<= '0';
	wrap_o.A 				<= r_addr;
	wrap_o.cyc				<= r_wrap_cyc;
	wrap_o.lane_req   	<= r_lane_req;
	wrap_o.rdy_ctdn   	<= RDY_CTDN_MIN;
	wrap_o.we	 			<= r_we;
	wrap_o.D_WR				<= r_wrap_wdata;
	wrap_o.D_WR_stb 		<= r_lane_wrstb;
	wrap_o.instr_fetch  	<= r_instr;

	i_rv_res_n <= not fb_syscon_i.rst when cpu_en_i = '1' else
						'0';

	-- handle address phase of AHB5 bus
	p_addr:process(fb_syscon_i)
	variable v_add2  : std_logic_vector(1 downto 0);
	begin

		if fb_syscon_i.rst = '1' then
			r_next_wrap_cyc <= '0';
			r_next_lane_req <= (others => '0');
			r_next_we <= '0';
			r_next_instr <= '0';
			r_next_addr <= (others => '0');
			r_rv_addr_ready <= '1';
		elsif rising_edge(fb_syscon_i.clk) then

			if i_rv_hready = '1' then
				if i_rv_htrans(1) = '1' then
					r_next_wrap_cyc <= '1';
					if i_rv_write = '0' then
						-- read cycle
						r_next_instr <= not i_rv_hprot(0);
						r_next_we <= '0';
					else
						-- write cycle
						r_next_instr <= '0';
						r_next_we <= '1';
					end if;

					case i_rv_hsize is
						when "000" =>
							v_add2 := i_rv_addr(1 downto 0);
							case i_rv_addr(1 downto 0) is
								when "00" => r_next_lane_req <= "0001";
								when "01" => r_next_lane_req <= "0010";
								when "10" => r_next_lane_req <= "0100";
								when others => r_next_lane_req <= "1000";
							end case;
						when "001" =>
							v_add2 := i_rv_addr(1) & '0';
							if i_rv_addr(1) = '1' then
								r_next_lane_req <= "1100";
							else
								r_next_lane_req <= "0011";
							end if;
						when others => 
							v_add2 := "00";
							r_next_lane_req <= "1111";
					end case;						

					r_next_addr <= i_rv_addr(23 downto 2) & v_add2;
					r_rv_addr_ready <= '0';
				else
					r_next_wrap_cyc <= '0';
					r_rv_addr_ready <= '1';
				end if;
			end if;
		end if;

	end process;

	-- handle controller state
	p_state:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_state <= idle;
			r_instr <= '0';
			r_wrap_cyc <= '0';
			r_we <= '0';
			r_addr <= (others => '0');
			r_rv_mem_ready <= '0';
			r_lane_req <= (others => '0');
			r_lane_wrstb <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
			
			r_rv_mem_ready <= '0';
			case r_state is
				when idle =>
					if r_next_wrap_cyc = '1' then
						r_wrap_cyc <= '1';
						r_addr <= r_next_addr;
						r_we <= r_next_we;
						r_instr <= r_next_instr;
						r_lane_req <= r_next_lane_req;
						if r_next_we = '0' then
							r_state <= rd;
						else
							r_state <= wr;
							r_rv_mem_ready <= '1';
						end if;
					end if;
				when rd =>
					if wrap_i.ack = '1' then
						r_state <= goidle;
						r_rv_mem_ready <= '1';
						r_rv_rdata <= wrap_i.D_rd;
						r_wrap_cyc <= '0';
					end if;
				when wr =>
					r_lane_wrstb <= r_lane_req;
					if r_rv_mem_ready = '1' then
						r_wrap_wdata <= i_rv_wdata;
					end if;
					if wrap_i.ack = '1' then
						r_state <= goidle;
						r_wrap_cyc <= '0';
					end if;
				when others => 
					r_state <= idle;
					r_wrap_cyc <= '0';
			end case;

		end if;
	end process;

	i_rv_irq <= (
		2 => not wrap_i.nmi_n,
		1 => not wrap_i.irq_n,
		0 => not wrap_i.noice_debug_nmi_n,
		others => '0'
		);

	i_rv_hready <= r_rv_mem_ready or r_rv_addr_ready;

	e_cpu:hazard3_cpu_1port
	generic map (
      RESET_VECTOR        	=> x"fffffff8",
      MTVEC_INIT          	=> x"fffffffc",

      EXTENSION_A				=> false,
      EXTENSION_C				=> true,
      EXTENSION_M				=> true,
      EXTENSION_ZBA			=> false,
      EXTENSION_ZBB			=> false,
      EXTENSION_ZBC			=> false,
      EXTENSION_ZBS			=> false,
      EXTENSION_ZBKB			=> false,
      EXTENSION_ZCB			=> false,
      EXTENSION_ZCMP			=> false,
      EXTENSION_ZIFENCEI	=> false,

      EXTENSION_XH3BEXTM 	=> false,
      EXTENSION_XH3IRQ 		=> false,
      EXTENSION_XH3PMPM 	=> false,
      EXTENSION_XH3POWER 	=> false,

      CSR_M_MANDATORY		=> true,
      CSR_M_TRAP				=> true,
      CSR_COUNTER				=> false,

      U_MODE 					=> false,

      NUM_IRQS 				=> 3,

      IRQ_PRIORITY_BITS 	=> 1
	)
	port map (
		-- Global signals
         clk                        => fb_syscon_i.clk,
         clk_always_on              => fb_syscon_i.clk,
         rst_n                      => i_rv_res_n,


   -- Power control signals
         pwrup_req                  => i_pwrup_req_tieback,
         pwrup_ack                  => i_pwrup_req_tieback,
         clk_en                     => open,
         unblock_out                => open,
         unblock_in                 => '0',

   -- AHB5 Master port
         haddr                      => i_rv_addr,
         hwrite                     => i_rv_write,
         htrans                     => i_rv_htrans,
         hsize                      => i_rv_hsize,
         hburst                     => open,
         hprot                      => i_rv_hprot,
         hmastlock                  => open,
         hmaster                    => open,
         hexcl                      => open,
         hready                     => i_rv_hready,
         hresp                      => '0',
         hexokay                    => '1',
         hwdata                     => i_rv_wdata,
         hrdata                     => r_rv_rdata,

   -- Debugger run/halt control
         dbg_req_halt               => '0',
         dbg_req_halt_on_reset      => '0',
         dbg_req_resume             => '0',
         dbg_halted                 => open,
         dbg_running                => open,
   -- Debugger access to data0 CSR
         dbg_data0_rdata            => (others => '0'),
         dbg_data0_wdata            => open,
         dbg_data0_wen              => open,
   -- Debugger instruction injection
         dbg_instr_data             => (others => '0'),
         dbg_instr_data_vld         => '0',
         dbg_instr_data_rdy         => open,
         dbg_instr_caught_exception => open,
         dbg_instr_caught_ebreak    => open,

   -- Optional debug system bus access patch-through
         dbg_sbus_addr             	=> (others => '0'),
         dbg_sbus_write             => '0',
         dbg_sbus_size              => (others => '0'),
         dbg_sbus_vld               => '0',
         dbg_sbus_rdy               => open,
         dbg_sbus_err               => open,
         dbg_sbus_wdata             => (others => '0'),
         dbg_sbus_rdata             => open,

   -- Level-sensitive interrupt sources
         irq                        => i_rv_irq,
         soft_irq                   => '0',
         timer_irq                  => '0'
	);

	wrap_o.noice_debug_A0_tgl 		<= '0';

  	wrap_o.noice_debug_cpu_clken 	<= '0';
  	
  	wrap_o.noice_debug_5c	 		<=	'0';

  	wrap_o.noice_debug_opfetch 	<= r_instr;



end rtl;
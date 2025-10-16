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

entity fb_cpu_picorv32 is
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
end fb_cpu_picorv32;

architecture rtl of fb_cpu_picorv32 is


	component picorv32 is generic (
		ENABLE_COUNTERS			: boolean := true;
		ENABLE_COUNTERS64			: boolean := true;
		ENABLE_REGS_16_31			: boolean := true;
		ENABLE_REGS_DUALPORT		: boolean := true;
		LATCHED_MEM_RDATA			: boolean := false;
		TWO_STAGE_SHIFT			: boolean := true;
		BARREL_SHIFTER				: boolean := false;
		TWO_CYCLE_COMPARE			: boolean := false;
		TWO_CYCLE_ALU				: boolean := false;
		COMPRESSED_ISA				: boolean := false;
		CATCH_MISALIGN				: boolean := true;
		CATCH_ILLINSN				: boolean := true;
		ENABLE_PCPI					: boolean := false;
		ENABLE_MUL					: boolean := false;
		ENABLE_FAST_MUL			: boolean := false;
		ENABLE_DIV					: boolean := false;
		ENABLE_IRQ					: boolean := false;
		ENABLE_IRQ_QREGS			: boolean := true;
		ENABLE_IRQ_TIMER			: boolean := true;
		ENABLE_TRACE				: boolean := false;
		REGS_INIT_ZERO				: boolean := false;
		MASKED_IRQ					: std_logic_vector(31 downto 0) := x"00000000";
		LATCHED_IRQ					: std_logic_vector(31 downto 0) := x"ffffffff";
		PROGADDR_RESET				: std_logic_vector(31 downto 0) := x"00000000";
		PROGADDR_IRQ				: std_logic_vector(31 downto 0) := x"00000010";
		STACKADDR					: std_logic_vector(31 downto 0) := x"ffffffff"
	);
	port (
		clk							: in	std_logic;
		resetn						: in	std_logic;
		trap							: out std_logic;

		mem_valid					: out std_logic;
		mem_instr					: out std_logic;
		mem_ready					: in  std_logic;

		mem_addr						: out std_logic_vector(31 downto 0);
		mem_wdata					: out std_logic_vector(31 downto 0);
		mem_wstrb					: out std_logic_vector(3 downto 0);
		mem_rdata					: in  std_logic_vector(31 downto 0);

		-- Look-Ahead Interface
		mem_la_read					: out std_logic;
		mem_la_write				: out std_logic;
		mem_la_addr					: out std_logic_vector(31 downto 0);
		mem_la_wdata 				: out std_logic_vector(31 downto 0);
		mem_la_wstrb 				: out std_logic_vector(3 downto 0);

		-- Pico Co-Processor Interface (PCPI)
		pcpi_valid					: out std_logic;
		pcpi_insn					: out std_logic_vector(31 downto 0);
		pcpi_rs1						: out std_logic_vector(31 downto 0);
		pcpi_rs2						: out std_logic_vector(31 downto 0);
		pcpi_wr						: in  std_logic;
		pcpi_rd						: in  std_logic_vector(31 downto 0);	
		pcpi_wait					: in	std_logic;
		pcpi_ready					: in	std_logic;

		-- IRQ Interface
		irq							: in	std_logic_vector(31 downto 0);
		eoi 							: out	std_logic_vector(31 downto 0);


		-- Trace Interface
		trace_valid					: out std_logic;
		trace_data					: out std_logic_vector(35 downto 0) 
	);
	end component;


	signal i_rv_mem_instr	: std_logic;
	signal i_rv_mem_valid	: std_logic;
	signal r_rv_mem_ready	: std_logic;
	signal i_rv_addr 			: std_logic_vector(31 downto 0);
	signal r_rv_rdata			: std_logic_vector(31 downto 0);
	signal i_rv_wdata			: std_logic_vector(31 downto 0);
	signal i_rv_wstrb			: std_logic_vector(3 downto 0);
	signal i_rv_irq			: std_logic_vector(31 downto 0);

	signal i_rv_mem_la_wrstb: std_logic_vector(3 downto 0);   -- need to look ahead to get byte lanes

	signal i_rv_res_n			: std_logic;
	signal i_rv_nmi_n			: std_logic;

	signal r_wrap_cyc			: std_logic;
	signal r_lane_req			: std_logic_vector(3 downto 0);
	signal r_we					: std_logic;
	signal r_instr				: std_logic;
	signal r_latch_rstrb		: std_logic_vector(3 downto 0);
	signal r_addr				: std_logic_vector(23 downto 0);

	type state_t is (idle, rd, wr, goidle);

	signal r_state				: state_t;

begin

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity error;

	-- NOTE: need to latch address on dly(1) not dly(0) as it was unreliable

	wrap_o.BE				<= '0';
	wrap_o.A 				<= r_addr;
	wrap_o.cyc				<= r_wrap_cyc;
	wrap_o.lane_req   	<= r_lane_req;
	wrap_o.rdy_ctdn   	<= RDY_CTDN_MIN;
	wrap_o.we	 			<= r_we;
	wrap_o.D_WR				<= i_rv_wdata;
	wrap_o.D_WR_stb 		<= r_lane_req;
	wrap_o.instr_fetch  	<= r_instr;

	i_rv_nmi_n 	<= wrap_i.nmi_n and wrap_i.noice_debug_nmi_n;

	i_rv_res_n <= not fb_syscon_i.rst when cpu_en_i = '1' else
						'0';

	p_rstrb:process(fb_syscon_i)
	begin
		-- here we synthesize a byte lane mask for reads
		-- as mem_la_wrstb always has correct bits sets 
		-- (for both reads and writes)
		if fb_syscon_i.rst = '1' then
			r_latch_rstrb <= "0000";
		elsif rising_edge(fb_syscon_i.clk) then
			if i_rv_mem_valid = '0' then
				r_latch_rstrb <= i_rv_mem_la_wrstb;
			end if;
		end if;
	end process;

	p_state:process(fb_syscon_i)
	variable v_lanes : std_logic_vector(3 downto 0);
	variable v_add2  : std_logic_vector(1 downto 0);
	begin
		if fb_syscon_i.rst = '1' then
			r_state <= idle;
			r_instr <= '0';
			r_wrap_cyc <= '0';
			r_we <= '0';
			r_addr <= (others => '0');
			r_rv_mem_ready <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			
			r_rv_mem_ready <= '0';

			case r_state is 
				when idle => 
					if i_rv_mem_valid = '1' then
						r_instr <= '0';
						r_wrap_cyc <= '1';
						if i_rv_wstrb = "0000" then
							-- read cycle
							r_instr <= i_rv_mem_instr;
							r_we <= '0';
							v_lanes :=  r_latch_rstrb;
							r_state <= rd;
						else
							-- write cycle
							r_we <= '1';
							v_lanes := i_rv_wstrb;
							r_state <= wr;
						end if;

						r_lane_req <= v_lanes;
						--TODO: check what actually happens on misaligned transfers and possibly allow?
						if v_lanes(0) = '1' then
							-- either full word or 1st byte
							v_add2 := "00";
						elsif v_lanes(1) = '1' then
						   -- must be 2nd byte
							v_add2 := "01";
						elsif v_lanes(2) = '1' then
						   -- must be 3rd byte or top halfword
							v_add2 := "10";
						elsif v_lanes(3) = '1' then
						   -- must be 4th byte
							v_add2 := "11";
						else
							-- this shouldn't happen!
							v_add2 := "00";	
						end if;
						r_addr <= i_rv_addr(23 downto 2) & v_add2;
							

					end if;
				when rd =>
					if wrap_i.ack = '1' then
						r_rv_mem_ready <= '1';
						r_rv_rdata <= wrap_i.D_rd;
						r_state <= goidle;
						r_wrap_cyc <= '0';						
					end if;
				when wr =>
					if wrap_i.ack = '1' then
						r_rv_mem_ready <= '1';
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
		3 => not wrap_i.nmi_n,
		4 => not wrap_i.irq_n,
		5 => not wrap_i.noice_debug_nmi_n,
		others => '0'
		);


	e_cpu:picorv32 generic map (
		ENABLE_COUNTERS			=> true,
		ENABLE_COUNTERS64			=> true,
		ENABLE_REGS_16_31			=> true,
		ENABLE_REGS_DUALPORT		=> true,
		LATCHED_MEM_RDATA			=> false,
		TWO_STAGE_SHIFT			=> true,
		BARREL_SHIFTER				=> false,
		TWO_CYCLE_COMPARE			=> true,
		TWO_CYCLE_ALU				=> true,
		COMPRESSED_ISA				=> true,
		CATCH_MISALIGN				=> true,
		CATCH_ILLINSN				=> true,
		ENABLE_PCPI					=> false,
		ENABLE_MUL					=> true,
		ENABLE_FAST_MUL			=> false,
		ENABLE_DIV					=> true,
		ENABLE_IRQ					=> true,
		ENABLE_IRQ_QREGS			=> true,
		ENABLE_IRQ_TIMER			=> true,
		ENABLE_TRACE				=> false,
		REGS_INIT_ZERO				=> false,
		MASKED_IRQ					=> x"ffffffc0",
		LATCHED_IRQ					=> x"ffffffcf",	-- don't latch IRQ or debug!
		PROGADDR_RESET				=> x"fffffff8",
		PROGADDR_IRQ				=> x"fffffffc",
		STACKADDR					=> x"00010000"
	)
	port map (
		clk							=> fb_syscon_i.clk,
		resetn						=> i_rv_res_n,
		trap							=> open,

		mem_valid					=> i_rv_mem_valid,
		mem_instr					=> i_rv_mem_instr,
		mem_ready					=> r_rv_mem_ready,

		mem_addr						=> i_rv_addr,
		mem_wdata					=> i_rv_wdata,
		mem_wstrb					=> i_rv_wstrb,
		mem_rdata					=> r_rv_rdata,

		-- Look-Ahead Interface
		mem_la_read					=> open,
		mem_la_write				=> open,
		mem_la_addr					=> open,
		mem_la_wdata 				=> open,
		mem_la_wstrb 				=> i_rv_mem_la_wrstb,	-- TODO: contact author of picorv32 about making a mem_la_rstrb from this or changing to byte selects and we

		-- Pico Co-Processor Interface (PCPI)
		pcpi_valid					=> open,
		pcpi_insn					=> open,
		pcpi_rs1						=> open,
		pcpi_rs2						=> open,
		pcpi_wr						=> '-',
		pcpi_rd						=> (others =>'-'),
		pcpi_wait					=> '-',
		pcpi_ready					=> '-',

		-- IRQ Interface
		irq							=> i_rv_irq,
		eoi 							=> open,


		-- Trace Interface
		trace_valid					=> open,
		trace_data					=> open
	);

	wrap_o.noice_debug_A0_tgl 		<= '0';

  	wrap_o.noice_debug_cpu_clken 	<= '0';
  	
  	wrap_o.noice_debug_5c	 		<=	'0';

  	wrap_o.noice_debug_opfetch 	<= i_rv_mem_instr;



end rtl;
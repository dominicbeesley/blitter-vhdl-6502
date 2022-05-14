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

-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	9/8/2020
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - z80
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the z80 processor slot
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

-- NOTE: this requires a board mod on the mk.2 board - the z80's RFSH pin needs to 
-- be connected to CPUSKT_VSS6VPA9BAKnAS_i


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.board_config_pack.all;
use work.fb_cpu_pack.all;
use work.fb_cpu_exp_pack.all;

entity fb_cpu_z80 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural
	);
	port(

		-- configuration
		cpu_en_i								: in std_logic;				-- 1 when this cpu is the current one
		fb_syscon_i								: in fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

		-- CPU expansion signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i;

		-- special m68k signals
		jim_en_i								: in std_logic

	);
end fb_cpu_z80;

architecture rtl of fb_cpu_z80 is


--TODO: other speed grades
--Current speed grade 8 MHz
--Assume 128MHz fast clock

-- timings below in number of fast clocks
	constant T_cpu_clk_half	: natural 		:= 8;		-- clock half period - 8MHZ


	signal r_clkctdn			: unsigned(NUMBITS(T_cpu_clk_half)-1 downto 0) := to_unsigned(T_cpu_clk_half-1, NUMBITS(T_cpu_clk_half));

	signal r_cpu_clk			: std_logic;
	signal r_cpu_clk_pe		: std_logic;

	signal r_z80_boot			: std_logic;								-- map MOS ROM FFFF00 at CPU addr 0000-00FF during boot

	signal r_act				: std_logic;

	signal i_rdy				: std_logic;

	signal r_A_log				: std_logic_vector(23 downto 0);
	signal i_A_log				: std_logic_vector(23 downto 0);
	signal r_WE					: std_logic;
	signal r_WR_stb			: std_logic;


	signal i_CPUSKT_CLK_o		: std_logic;
	signal i_CPUSKT_nWAIT_o		: std_logic;
	signal i_CPUSKT_nIRQ_o		: std_logic;
	signal i_CPUSKT_nNMI_o		: std_logic;
	signal i_CPUSKT_nRES_o		: std_logic;
	signal i_CPUSKT_nBUSREQ_o 	: std_logic;
	signal i_CPU_D_RnW_o		: std_logic;

	signal i_CPUSKT_nRD_i		: std_logic;
	signal i_CPUSKT_nWR_i		: std_logic;
	signal i_CPUSKT_nMREQ_i		: std_logic;
	signal i_CPUSKT_nM1_i		: std_logic;
	signal i_CPUSKT_nRFSH_i		: std_logic;
	signal i_CPUSKT_nIOREQ_i	: std_logic;
	signal i_CPUSKT_nBUSACK_i	: std_logic;

	signal i_CPUSKT_D_i		: std_logic_vector(7 downto 0);
	signal i_CPUSKT_A_i		: std_logic_vector(15 downto 0);

begin

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity error;

	e_pinmap:entity work.fb_cpu_z80_exp_pins
	port map(

		-- cpu wrapper signals
		wrap_exp_o => wrap_exp_o,
		wrap_exp_i => wrap_exp_i,

		-- local z80 wrapper signals

		CPUSKT_nBUSREQ_i						=> i_CPUSKT_nBUSREQ_o,
		CPUSKT_CLK_i							=> i_CPUSKT_CLK_o,
		CPUSKT_nWAIT_i							=> i_CPUSKT_nWAIT_o,
		CPUSKT_nIRQ_i							=> i_CPUSKT_nIRQ_o,
		CPUSKT_nNMI_i							=> i_CPUSKT_nNMI_o,
		CPUSKT_nRES_i							=> i_CPUSKT_nRES_o,

		CPUSKT_nRD_o							=> i_CPUSKT_nRD_i,
		CPUSKT_nWR_o							=> i_CPUSKT_nWR_i,
		CPUSKT_nMREQ_o							=> i_CPUSKT_nMREQ_i,
		CPUSKT_nM1_o							=> i_CPUSKT_nM1_i,
		CPUSKT_nRFSH_o							=> i_CPUSKT_nRFSH_i,
		CPUSKT_nIOREQ_o						=> i_CPUSKT_nIOREQ_i,
		CPUSKT_nBUSACK_o						=> i_CPUSKT_nBUSACK_i,

		-- shared per CPU signals
		CPU_D_RnW_i			=> i_CPU_D_RnW_o,

		CPUSKT_A_o			=> i_CPUSKT_A_i,
		CPUSKT_D_o			=> i_CPUSKT_D_i


	);

	i_CPU_D_RnW_o <= '0' when i_CPUSKT_nRD_i = '1' else
					 	'1';

	--TODO: mark rdy earlier!
	--TODO: register this signal (metastable vs z80?)
	i_rdy <= '1' when wrap_i.rdy_ctdn = RDY_CTDN_MIN else 
				'0';


	wrap_o.cyc 				<= ( 0 => r_act, others => '0');
	wrap_o.we  				<= r_WE;
	wrap_o.D_wr				<=	i_CPUSKT_D_i;	
	wrap_o.D_wr_stb			<= r_WR_stb;
	wrap_o.ack				<= not r_act;
	wrap_o.A_log			<= r_A_log;
  		

	-- Z80 memory map notes: TODO: move this to wiki/doc folder
	--
	-- BOOT TIME
	-- =========
	-- After reset a boot flag causes all reads to be made from the boot sector of the MOS rom at FF FFXX
	-- the Z80 starts executing at 0000 which would normally be mapped to 00 0000 which is ChipRAM. At boot
	-- time the MOS/MONITOR should set up the zero page (writes are still mapped as normal) and jump to an
	-- entry point in the MOS boot ears FF FFxx (boot mapping is still in force) then
	-- write the JIM_ENABLE value to the DEVICE_SELECT register i.e. ($FCFF)=$D1 all before enabling any
	-- interrupts.
	-- TODO: what happens if there is an NMI at boot time?! Need a handler at FF FF33?
	--
	-- NORMAL MEMORY MAP
	-- =================
	-- 
	-- CPU					Logical				Physical
	-- +------------+
	-- | 0000..9FFF |		00 0000..00 9FFF 	00 0000..00 9FFF - RAM at full speed 10ns/55ns
	-- | user mem   |
	-- | 40K			 |
	-- +------------+
	-- | A000..EFFF |		FF 3000..FF 7FFF	FF 3000..FF 7FFF - SYS/screen can be used as RAM but will run at 2MHz
	-- | screen mem |
	-- | 20K        |
	-- +------------+
	-- | F000..FBFF |		FF F000..FF FBFF  FF F000..FF FBFF - if running with ROM set 0
	-- | monitor rom|								7D 3000..7D 3BFF - if running in rom bank 1 with mosram
	-- | 3K         |    						9D 3000..9D 3BFF - if running in rom bank 1 normally
	-- +------------+
	-- | FC00..FEFF |		FF FC00..FF FEFF 	FF FC00..FF FEFF - hardware registers
	-- | hardware   |
	-- | 0.75K      |
	-- +------------+
	-- | FF00..FFFF |		FF FF00..FF FFFF	FF FF00..FF FFFF - if running in rom bank 0
	-- | boot rom   |								7D 3F00..7D 3FFF - if running in rom bank 1 with mosram
	-- | 0.25K      |    						9D 3F00..9D 3FFF - if running in rom bank 1 normally
	-- +------------+
	--
	-- IO Mapping
	-- ==========
	-- IO ports always access lofical and physical FF FDxx


	p_logadd:process(wrap_i, r_z80_boot, i_CPUSKT_nRD_i, i_CPUSKT_nIOREQ_i, i_CPUSKT_A_i)
	variable v_A_top : unsigned(3 downto 0);
	begin
		v_A_top := unsigned(i_CPUSKT_A_i(15 downto 12));
		if i_CPUSKT_nIOREQ_i = '0' then
			-- IO ports all map to JIM page
			i_A_log <= x"FFFD" & i_CPUSKT_A_i(7 downto 0);
		elsif i_CPUSKT_nRD_i = '0' and r_z80_boot = '1' then
			-- boot rom reads
			i_A_log <= x"FFFF" & i_CPUSKT_A_i(7 downto 0);
		elsif v_A_top >= x"A" and v_A_top <= x"E" then
			-- screen memory
			i_A_log <= x"FF" & std_logic_vector(v_A_top - 7) & i_CPUSKT_A_i(11 downto 0);
		elsif v_A_top = x"F" then
			-- mos rom / boot rom / hardware regs
			i_A_log <= x"FFF" & i_CPUSKT_A_i(11 downto 0);
		else
			-- chip ram low memory
			i_A_log <= x"00" & i_CPUSKT_A_i; 	-- low memory from chip ram
		end if;
	end process;


	p_cpu_clk:process(fb_syscon_i)
	begin

		if rising_edge(fb_syscon_i.clk) then

			r_cpu_clk_pe <= '0';

			if r_clkctdn = 0 then
				if r_cpu_clk = '1' then
					r_cpu_clk <= '0';
				else
					r_cpu_clk_pe <= '1';
					r_cpu_clk <= '1';					
				end if;
				r_clkctdn <= to_unsigned(T_cpu_clk_half-1, r_clkctdn'length);
			else
				r_clkctdn <= r_clkctdn - 1;
			end if;

		end if;

	end process;



	p_act:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_act <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if r_cpu_clk_pe = '1' then

				r_WR_stb <= not(i_CPUSKT_nWR_i);

				if r_act = '0' and 
					(
						(i_CPUSKT_nMREQ_i = '0' and i_CPUSKT_nRFSH_i = '1' ) or
						(i_CPUSKT_nIOREQ_i = '0' and (i_CPUSKT_nRD_i = '0' or i_CPUSKT_nWR_i = '0')) 
					) then
					r_act <= '1';

					r_A_log <=	i_A_log;

					r_WE <= i_CPUSKT_nRD_i;
				elsif i_CPUSKT_nMREQ_i = '1' and i_CPUSKT_nIOREQ_i = '1' then
					r_act <= '0';
				end if;
			end if;
		end if;
	end process;


	i_CPUSKT_nBUSREQ_o <= cpu_en_i;

	i_CPUSKT_CLK_o <= r_cpu_clk;

	i_CPUSKT_nRES_o <= (not fb_syscon_i.rst) when cpu_en_i = '1' else '0';

	i_CPUSKT_nNMI_o <= wrap_i.nmi_n and wrap_i.noice_debug_nmi_n;

	i_CPUSKT_nIRQ_o <=  wrap_i.irq_n;

  	i_CPUSKT_nWAIT_o <= 	'1' 			when fb_syscon_i.rst = '1' else
  												'1' 			when wrap_i.noice_debug_inhibit_cpu = '1' else
  												i_rdy		 	when wrap_i.cyc = '1' else
  												'0';						

	p_z80_boot:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_z80_boot <= '1';
		elsif rising_edge(fb_syscon_i.clk) then
			if JIM_en_i = '1' then
				r_z80_boot <= '0';
			end if;
		end if;
	end process;



  	--TODO: this doesn't look right
  	wrap_o.noice_debug_cpu_clken <= '1' when r_cpu_clk_pe = '1' and wrap_i.cyc = '1' and i_rdy = '1' else
  										'0';
  	
  	wrap_o.noice_debug_5c	 	 	<=	'0';

  	wrap_o.noice_debug_opfetch 	<= '1' when i_CPUSKT_nM1_i = '0' and i_CPUSKT_nMREQ_i = '0' else
  										'0';

	wrap_o.noice_debug_A0_tgl  	<= '0'; -- TODO: check if needed



end rtl;



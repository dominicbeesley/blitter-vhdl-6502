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
-- Create Date:    	28/1/2023
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - z180
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the z180 processor plug in
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

-- NOTE: this requires a board mod on the mk.2 board - the z80's RFSH pin needs to 
-- be connected to CPUSKT_VSS6VPA9BAKnAS_b2c


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.board_config_pack.all;
use work.fb_cpu_pack.all;
use work.fb_cpu_exp_pack.all;

entity fb_cpu_z180 is
	generic (
		SIM									: boolean := false;								-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;
		INT0_IM2_VEC							: std_logic_vector(7 downto 0) := x"3E"	-- int mode 2 interrupt ack value
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
		jim_en_i								: in std_logic;

		-- debug
		DBG_M1_o									: out std_logic

	);
end fb_cpu_z180;

architecture rtl of fb_cpu_z180 is


--TODO: other speed grades
--Current speed grade 8 MHz
--Assume 128MHz fast clock

-- timings below in number of fast clocks
	constant T_cpu_clk_half	: natural 		:= 4;		-- clock half period - 18.28MHZ - one half is 1 cycle smaller!


	signal r_clkctdn			: unsigned(NUMBITS(T_cpu_clk_half)-1 downto 0) := to_unsigned(T_cpu_clk_half-1, NUMBITS(T_cpu_clk_half));

	signal r_cpu_clk			: std_logic;
	signal r_cpu_clk_pe		: std_logic;

	signal r_z80_boot			: std_logic;								-- map MOS ROM FFFF00 at CPU addr 0000-00FF during boot

	signal r_cyc				: std_logic;
	signal r_D_WR_stb			: std_logic;

	signal i_rdy				: std_logic;

	signal r_A_log				: std_logic_vector(23 downto 0);
	signal i_A_log				: std_logic_vector(23 downto 0);
	signal r_WE					: std_logic;
	signal r_instr_fetch		: std_logic;


	signal i_CPUSKT_EXTAL_b2c		: std_logic;
	signal i_CPUSKT_nWAIT_b2c		: std_logic;
	signal i_CPUSKT_nINT0_b2c		: std_logic;
	signal i_CPUSKT_nINT1_b2c		: std_logic;
	signal i_CPUSKT_nINT2_b2c		: std_logic;
	signal i_CPUSKT_nNMI_b2c		: std_logic;
	signal i_CPUSKT_nRES_b2c		: std_logic;
	signal i_CPUSKT_nDREQ0_b2c		: std_logic;
	signal i_CPUSKT_nBUSREQ_b2c	: std_logic;
	signal i_CPUSKT_D_b2c			: std_logic_vector(7 downto 0);

	signal i_BUF_D_RnW_b2c			: std_logic;

	signal i_CPUSKT_nRD_c2b			: std_logic;
	signal i_CPUSKT_nWR_c2b			: std_logic;
	signal i_CPUSKT_nHALT_c2b		: std_logic;
	signal i_CPUSKT_nMREQ_c2b		: std_logic;
	signal i_CPUSKT_nM1_c2b			: std_logic;
	signal i_CPUSKT_nRFSH_c2b		: std_logic;
	signal i_CPUSKT_nIOREQ_c2b		: std_logic;
	signal i_CPUSKT_nBUSACK_c2b	: std_logic;
	signal i_CPUSKT_nTEND0_c2b		: std_logic;
	signal i_CPUSKT_ST_c2b			: std_logic;
	signal i_CPUSKT_PHI_c2b			: std_logic;

	signal i_CPUSKT_D_c2b			: std_logic_vector(7 downto 0);
	signal i_CPUSKT_A_c2b			: std_logic_vector(19 downto 0);

	signal i_nMREQ_dly				: std_logic;
	signal i_nIOREQ_dly				: std_logic;
	signal i_nRD_dly					: std_logic;
	signal i_nWR_dly					: std_logic;

	signal r_int0ack						: std_logic;

begin

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity error;

	e_pinmap:entity work.fb_cpu_z180_exp_pins
	port map(

		-- cpu wrapper signals
		wrap_exp_o => wrap_exp_o,
		wrap_exp_i => wrap_exp_i,

		-- local z80 wrapper signals

		CPUSKT_nBUSREQ_b2c					=> i_CPUSKT_nBUSREQ_b2c,
		CPUSKT_EXTAL_b2c						=> i_CPUSKT_EXTAL_b2c,
		CPUSKT_nWAIT_b2c						=> i_CPUSKT_nWAIT_b2c,
		CPUSKT_nINT0_b2c						=> i_CPUSKT_nINT0_b2c,
		CPUSKT_nINT1_b2c						=> i_CPUSKT_nINT1_b2c,
		CPUSKT_nINT2_b2c						=> i_CPUSKT_nINT2_b2c,
		CPUSKT_nNMI_b2c						=> i_CPUSKT_nNMI_b2c,
		CPUSKT_nDREQ0_b2c						=> i_CPUSKT_nDREQ0_b2c,
		CPUSKT_nRES_b2c						=> i_CPUSKT_nRES_b2c,
		CPUSKT_D_b2c							=> i_CPUSKT_D_b2c,

		BUF_D_RnW_b2c							=> i_BUF_D_RnW_b2c,

		CPUSKT_nRD_c2b							=> i_CPUSKT_nRD_c2b,
		CPUSKT_nWR_c2b							=> i_CPUSKT_nWR_c2b,
		CPUSKT_nHALT_c2b						=> i_CPUSKT_nHALT_c2b,
		CPUSKT_nMREQ_c2b						=> i_CPUSKT_nMREQ_c2b,
		CPUSKT_nM1_c2b							=> i_CPUSKT_nM1_c2b,
		CPUSKT_nRFSH_c2b						=> i_CPUSKT_nRFSH_c2b,
		CPUSKT_nIOREQ_c2b						=> i_CPUSKT_nIOREQ_c2b,
		CPUSKT_nBUSACK_c2b					=> i_CPUSKT_nBUSACK_c2b,


		CPUSKT_A_c2b							=> i_CPUSKT_A_c2b,
		CPUSKT_D_c2b							=> i_CPUSKT_D_c2b

	);

	i_CPUSKT_D_b2c <= INT0_IM2_VEC when r_int0ack = '1' else -- im2 interrupt ack
							wrap_i.D_rd(7 downto 0);

	i_BUF_D_RnW_b2c <= 	'1' when r_int0ack = '1' else -- im2 interrupt ack
								'0' when i_CPUSKT_nRD_c2b = '1' else
					 			'1';

	--TODO: mark rdy earlier!
	--TODO: register this signal (metastable vs z80?)
	i_rdy <= wrap_i.rdy;


	wrap_o.BE				<= '0';
	wrap_o.A					<= r_A_log;
	wrap_o.cyc 				<= r_cyc;
	wrap_o.lane_req		<= (0 => '1', others => '0');
	wrap_o.we  				<= r_WE;
	wrap_o.D_wr(7 downto 0)	<=	i_CPUSKT_D_c2b;	
	G_D_WR_EXT:if C_CPU_BYTELANES > 1 GENERATE
		wrap_o.D_WR((8*C_CPU_BYTELANES)-1 downto 8) <= (others => '-');
	END GENERATE;
	wrap_o.D_wr_stb		<= (0 => r_D_WR_stb, others => '0');
	--wrap_o.rdy_ctdn		<= RDY_CTDN_MIN;		-- TODO: this could go much earlier!?
  	wrap_o.rdy_ctdn		<= to_unsigned(5, RDY_CTDN_LEN);
  	wrap_o.instr_fetch 	<= r_instr_fetch;

	-- Z180 memory map notes: TODO: move this to wiki/doc folder
	--
	-- BOOT TIME
	-- =========
	-- After reset a boot flag causes all reads to be made from the boot sector of the MOS rom at FF FFXX
	-- the Z180 starts executing at 0 0000 which would normally be mapped to 00 0000 which is System RAM. 
	-- At boot time the MOS/MONITOR should set up the zero page (writes are still mapped as normal) and 
	-- jump to an entry point in the MOS boot in FF FFxx (boot mapping is still in force) then
	-- write the JIM_ENABLE value to the DEVICE_SELECT register i.e. (F FCFF)=$D1 all before enabling any
	-- interrupts.
	-- TODO: what happens if there is an NMI at boot time?! Need a handler at FF FF33?
	--
	-- IO Mapping
	-- ==========
	-- IO ports are 64k and always access logical and physical FF xxxx


	p_logadd:process(wrap_i, r_z80_boot, i_CPUSKT_nRD_c2b, i_CPUSKT_nIOREQ_c2b, i_CPUSKT_A_c2b)
	begin
		if i_CPUSKT_nIOREQ_c2b = '0' then
			-- IO ports all map to SYS i.e. 64k IO mapping?
			i_A_log <= x"FF" & i_CPUSKT_A_c2b(15 downto 0);
		elsif i_CPUSKT_nRD_c2b = '0' and r_z80_boot = '1' then
			-- boot rom reads
			i_A_log <= x"FFFF" & i_CPUSKT_A_c2b(7 downto 0);
			--TODO: this looks wrong check in z80 too
		--else
			--i_A_log <= x"FF" & i_CPUSKT_A_c2b; 	-- low memory from chip ram
		elsif i_CPUSKT_A_c2b(19) = '1' then
			i_A_log <= x"F" & i_CPUSKT_A_c2b; 	-- chipset / SYS
		else
			i_A_log <= x"0" & i_CPUSKT_A_c2b; 	-- low memory from chip ram
		end if;
	end process;


	p_cpu_clk:process(fb_syscon_i)
	begin

		if rising_edge(fb_syscon_i.clk) then

			if r_clkctdn = 0 then
				if r_cpu_clk = '1' then
					r_cpu_clk <= '0';
					r_clkctdn <= to_unsigned(T_cpu_clk_half-1, r_clkctdn'length);
				else
					r_cpu_clk <= '1';					
					r_clkctdn <= to_unsigned(T_cpu_clk_half-2, r_clkctdn'length);
			end if;
			else
				r_clkctdn <= r_clkctdn - 1;
			end if;

		end if;

	end process;

	-- register IOREQ/MREQ signals
	e_m_MREQ_e:entity work.metadelay 
		generic map ( N => 3 ) 
		port map (clk => fb_syscon_i.clk, i => i_CPUSKT_nMREQ_c2b, o => i_nMREQ_dly);

	e_m_IOREQ_e:entity work.metadelay 
		generic map ( N => 3 ) 
		port map (clk => fb_syscon_i.clk, i => i_CPUSKT_nIOREQ_c2b, o => i_nIOREQ_dly);

	e_m_RD_e:entity work.metadelay 
		generic map ( N => 1 ) 
		port map (clk => fb_syscon_i.clk, i => i_CPUSKT_nRD_c2b, o => i_nRD_dly);

	e_m_WR_e:entity work.metadelay 
		generic map ( N => 1 ) 
		port map (clk => fb_syscon_i.clk, i => i_CPUSKT_nWR_c2b, o => i_nWR_dly);


	p_act:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_cyc <= '0';
			r_int0ack <= '0';
		elsif rising_edge(fb_syscon_i.clk) then

			r_D_WR_stb <= not(i_CPUSKT_nWR_c2b);

			if r_cyc = '0' and 
				(
					(i_nMREQ_dly = '0' and i_CPUSKT_nRFSH_c2b = '1' ) or
					(i_nIOREQ_dly = '0' and (i_nRD_dly = '0' or i_nWR_dly = '0')) 
				) then
				r_cyc <= '1';
				r_int0ack <= '0';

				r_A_log <=	i_A_log;
				r_instr_fetch <= not(i_CPUSKT_nM1_c2b) and not(i_CPUSKT_nMREQ_c2b);

				r_WE <= i_nRD_dly;
			elsif i_nMREQ_dly = '1' and i_nIOREQ_dly = '1' then
				r_cyc <= '0';
				r_int0ack <= '0';
			end if;

			if r_int0ack = '0' and i_nIOREQ_dly = '0' and i_CPUSKT_nM1_c2b = '0' then
				r_int0ack <= '1';
			elsif r_int0ack = '1' and i_nIOREQ_dly = '1' then
				r_int0ack <= '0';
			end if;

		end if;
	end process;


	i_CPUSKT_nBUSREQ_b2c <= cpu_en_i;

	i_CPUSKT_EXTAL_b2c <= r_cpu_clk;

	i_CPUSKT_nRES_b2c <= (not fb_syscon_i.rst) when cpu_en_i = '1' else '0';

	i_CPUSKT_nNMI_b2c <= wrap_i.nmi_n and wrap_i.noice_debug_nmi_n;

	i_CPUSKT_nINT0_b2c <=  wrap_i.irq_n;

	i_CPUSKT_nINT1_b2c <=  '1';
	i_CPUSKT_nINT2_b2c <=  '1';
	i_CPUSKT_nDREQ0_b2c <= '1';


  	i_CPUSKT_nWAIT_b2c <= 	'1' 			when fb_syscon_i.rst = '1' else
  									'1' 			when wrap_i.noice_debug_inhibit_cpu = '1' else
  									i_rdy		 	when r_cyc ='1' else
  									'1';						

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
  	wrap_o.noice_debug_cpu_clken <= 	'1' when i_nMREQ_dly = '1' and i_nIOREQ_dly = '1' and r_cyc = '1' and i_rdy = '1' else
  												'0';
  	
  	wrap_o.noice_debug_5c	 	 	<=	'0';

  	wrap_o.noice_debug_opfetch 	<= '1' when i_CPUSKT_nM1_c2b = '0' and i_CPUSKT_nMREQ_c2b = '0' else
  										'0';

	wrap_o.noice_debug_A0_tgl  	<= '0'; -- TODO: check if needed



end rtl;



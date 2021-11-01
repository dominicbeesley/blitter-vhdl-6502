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
-- Create Date:    	9/8/2020
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - t65 soft core
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the t65 core
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
use work.mk3blit_pack.all;


entity fb_cpu_t65 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;										-- fast clock speed in mhz						
		CLKEN_DLY_MAX						: natural 	:= 2;								-- used to time latching of address etc signals			
		G_BYTELANES							: positive	:= 1
	);
	port(
		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		fb_syscon_i								: in	fb_syscon_t;

		-- noice debugger signals to cpu
		noice_debug_nmi_n_i					: in	std_logic;		-- debugger is forcing a cpu NMI
		noice_debug_shadow_i					: in	std_logic;		-- debugger memory MOS map is active (overrides shadow_mos)
		noice_debug_inhibit_cpu_i			: in	std_logic;		-- during a 5C op code, inhibit address / data to avoid
																				-- spurious memory accesses
		-- noice debugger signals from cpu
		noice_debug_5c_o						: out	std_logic;		-- A 5C instruction is being fetched (qualify with clken below)
		noice_debug_cpu_clken_o				: out	std_logic;		-- clken and cpu rdy
		noice_debug_A0_tgl_o					: out	std_logic;		-- 1 when current A0 is different to previous fetched
		noice_debug_opfetch_o				: out	std_logic;		-- this cycle is an opcode fetch

		-- cpu throttle
		throttle_cpu_2MHz_i					: in std_logic;
		cpu_2MHz_phi2_clken_i				: in std_logic;


		-- direct CPU control signals from system
		nmi_n_i									: in	std_logic;
		irq_n_i									: in	std_logic;

		-- state machine signals
		wrap_cyc_o								: out std_logic_vector(G_BYTELANES-1 downto 0);
		wrap_A_log_o							: out std_logic_vector(23 downto 0);	-- this will be passed on to fishbone after to log2phys mapping
		wrap_A_we_o								: out std_logic;								-- we signal for this cycle
		wrap_D_WR_stb_o						: out std_logic;								-- for write cycles indicates write data is ready
		wrap_D_WR_o								: out std_logic_vector(7 downto 0);		-- write data
		wrap_ack_o								: out std_logic;

		wrap_rdy_ctdn_i						: in unsigned(RDY_CTDN_LEN-1 downto 0);
		wrap_cyc_i								: in std_logic;
		wrap_D_rd_i								: in std_logic_vector(7 downto 0);
	
		-- chipset control signals
		cpu_halt_i								: in  std_logic

	);
end fb_cpu_t65;

architecture rtl of fb_cpu_t65 is

	signal i_t65_RnW			: std_logic;
	signal i_t65_SYNC			: std_logic;
	signal i_t65_A	 			: std_logic_vector(23 downto 0);
	signal i_t65_D_in			: std_logic_vector(7 downto 0);
	signal i_t65_D_out		: std_logic_vector(7 downto 0);
	signal i_t65_res_n		: std_logic;


	signal r_t65_RnW			: std_logic;
	signal r_t65_SYNC			: std_logic;
	signal r_t65_A	 			: std_logic_vector(23 downto 0);
	signal r_t65_D_out		: std_logic_vector(7 downto 0);


	signal i_cpu65_nmi_n		: std_logic;

	signal r_prev_A0			: std_logic;

	-- count down to next cycle - when all 1's can proceed
	signal r_cpu_clk			: std_logic_vector(CLKEN_DLY_MAX downto 0);

	-- i_t65_clken '1' for one cycle to complete a cycle/start another
	signal i_t65_clken		: std_logic;
	signal i_t65_clken_h		: std_logic; -- clocken masked by halt
	-- the above signal delayed
	signal r_clken_dly		: std_logic_vector(CLKEN_DLY_MAX downto 0) := (others => '0');

	signal r_cpu_halt			: std_logic;

	signal r_throttle_cpu_2MHz : std_logic;

	signal i_wrap_cyc 		: std_logic;

	--TODO: throttle only works on SYS_BBC, on Elk it repeats cycles!

begin

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity error;


	p_reg_A:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			if r_clken_dly(0) = '1' then
				r_t65_SYNC <= i_t65_SYNC;
				r_t65_A <= i_t65_A;
				r_t65_RnW <= i_t65_RnW;
				r_t65_D_out <= i_t65_D_out;
			end if;
		end if;

	end process;

	-- NOTE: need to latch address on dly(1) not dly(0) as it was unreliable

	i_wrap_cyc			<= '1' when noice_debug_inhibit_cpu_i = '0' and r_cpu_halt = '0' and r_clken_dly(1) = '1' else
								'0';

	wrap_A_log_o 		<= x"FF" & r_t65_A(15 downto 0);
	wrap_cyc_o			<= ( 0 => i_wrap_cyc, others => '0');
	wrap_A_we_o 		<= not r_t65_RnW;
	wrap_D_WR_o 		<= r_t65_D_out;
	wrap_D_WR_stb_o 	<= r_clken_dly(1);
	wrap_ack_o	 		<= i_t65_clken;

	i_cpu65_nmi_n <= nmi_n_i and noice_debug_nmi_n_i;


	i_t65_clken <= '1' when r_cpu_clk(0) = '1' and (
									(wrap_rdy_ctdn_i = RDY_CTDN_MIN) or 
									noice_debug_inhibit_cpu_i = '1' or
									r_cpu_halt = '1'
									) and (r_throttle_cpu_2MHz = '0' or cpu_2MHz_phi2_clken_i = '1')
									else
						'0';
	i_t65_clken_h <= 	'0' when r_cpu_halt = '1' else
							i_t65_clken;

	i_t65_res_n <= not fb_syscon_i.rst when cpu_en_i = '1' else
						'0';

	i_t65_D_in <= wrap_D_rd_i when i_t65_RnW = '1' else
					  i_t65_D_out;
	
	p_rdy:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_cpu_halt <= '0';
			r_throttle_cpu_2MHz <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if i_t65_clken = '1' then
				r_cpu_halt <= cpu_halt_i;
				r_throttle_cpu_2MHz <= throttle_cpu_2MHz_i;
			end if;
		end if;			
	end process;

	e_cpu: entity work.T65 
  	port map (
   	Mode    => "00", 		-- 6502A
   	Res_n   => i_t65_res_n,
   	Enable  => i_t65_clken_h,
   	Clk     => fb_syscon_i.clk,
   	Rdy     => '1',
   	Abort_n => '1',
   	IRQ_n   => irq_n_i,
   	NMI_n   => i_cpu65_nmi_n,
   	SO_n    => '1',
   	R_W_n   => i_t65_RnW,
   	Sync    => i_t65_SYNC,
   	EF      => open,
   	MF      => open,
   	XF      => open,
   	ML_n    => open,
   	VP_n    => open,
   	VDA     => open,
   	VPA     => open,
   	A       => i_t65_A,
   	DI      => i_t65_D_in,
   	DO      => i_t65_D_out
	);

	p_cpu_clk:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_cpu_clk <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
			if i_t65_clken = '1' then
				r_cpu_clk <= (others => '0');
			else
				r_cpu_clk(r_cpu_clk'high) <= '1';
				r_cpu_clk(r_cpu_clk'high - 1 downto 0) <= r_cpu_clk(r_cpu_clk'high downto 1);
			end if;
		end if;
	end process;

	p_clken_dly:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_clken_dly <= (0 => '1', others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
			if r_cpu_halt = '0' then		
				r_clken_dly <= r_clken_dly(r_clken_dly'high-1 downto 0) & i_t65_clken;
			end if;
		end if;
	end process;


  	p_prev_a0:process(fb_syscon_i) 
  	begin
  		if fb_syscon_i.rst = '1' then
  			r_prev_A0 <= '0';
  		elsif rising_edge(fb_syscon_i.clk) then
  			if i_t65_clken = '1' then
  				r_prev_A0 <= r_t65_A(0);
  			end if;
  		end if;
  	end process;


	noice_debug_A0_tgl_o <= r_prev_A0 xor r_t65_A(0);

  	noice_debug_cpu_clken_o <= i_t65_clken_h;
  	
  	noice_debug_5c_o	 <=
  								'1' when 
  										r_t65_SYNC = '1' 
  										and i_t65_D_in = x"5C" else
  								'0';

  	noice_debug_opfetch_o <= r_t65_SYNC;



end rtl;
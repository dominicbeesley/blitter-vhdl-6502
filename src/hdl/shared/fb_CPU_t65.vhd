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
use work.board_config_pack.all;
use work.fb_cpu_pack.all;

entity fb_cpu_t65 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;										-- fast clock speed in mhz						
		CLKEN_DLY_MAX						: natural 	:= 2								-- used to time latching of address etc signals			
	);
	port(
		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		fb_syscon_i								: in	fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

		-- special 
		D_Rd_i						: in std_logic_vector(7 downto 0)
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
	signal r_throttle_wait  : std_logic;
	signal i_throttle_wait  : std_logic;

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

	p_throttle:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			if i_wrap_cyc = '1' then
				r_throttle_wait <= r_throttle_cpu_2MHz;
			end if;

			if wrap_i.cpu_2MHz_phi2_clken = '1' then
				r_throttle_wait <= '0';
			end if;

			r_throttle_cpu_2MHz <= wrap_i.throttle_cpu_2MHz;
		end if;

	end process;

	i_throttle_wait <= r_throttle_wait and not wrap_i.cpu_2MHz_phi2_clken;

	-- NOTE: need to latch address on dly(1) not dly(0) as it was unreliable

	i_wrap_cyc			<= '1' when wrap_i.noice_debug_inhibit_cpu = '0' and r_cpu_halt = '0' and r_clken_dly(1) = '1' else
								'0';

	wrap_o.A_log 		<= x"FF" & r_t65_A(15 downto 0);
	wrap_o.cyc			<= ( 0 => i_wrap_cyc, others => '0');
	wrap_o.we	 		<= not r_t65_RnW;
	wrap_o.D_WR 		<= r_t65_D_out;
	wrap_o.D_WR_stb 	<= r_clken_dly(1);
	wrap_o.ack	 		<= i_t65_clken;

	i_cpu65_nmi_n <= wrap_i.nmi_n and wrap_i.noice_debug_nmi_n;


	i_t65_clken <= '1' when r_cpu_clk(0) = '1' and (
									(wrap_i.rdy_ctdn = RDY_CTDN_MIN) or 
									wrap_i.noice_debug_inhibit_cpu = '1' or
									r_cpu_halt = '1'
									) and i_throttle_wait = '0'
									else
						'0';
	i_t65_clken_h <= 	'0' when r_cpu_halt = '1' else
							i_t65_clken;

	i_t65_res_n <= not fb_syscon_i.rst when cpu_en_i = '1' else
						'0';

	i_t65_D_in <= D_rd_i when i_t65_RnW = '1' else
					  i_t65_D_out;
	
	p_rdy:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_cpu_halt <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if i_t65_clken = '1' then
				r_cpu_halt <= wrap_i.cpu_halt;
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
   	IRQ_n   => wrap_i.irq_n,
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


	wrap_o.noice_debug_A0_tgl <= r_prev_A0 xor r_t65_A(0);

  	wrap_o.noice_debug_cpu_clken <= i_t65_clken_h;
  	
  	wrap_o.noice_debug_5c	 <=
  								'1' when 
  										r_t65_SYNC = '1' 
  										and i_t65_D_in = x"5C" else
  								'0';

  	wrap_o.noice_debug_opfetch <= r_t65_SYNC;



end rtl;
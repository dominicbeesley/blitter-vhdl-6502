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

library work;
use work.fishbone.all;
use work.board_config_pack.all;
use work.fb_cpu_pack.all;

entity fb_cpu_t65 is
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
end fb_cpu_t65;

architecture rtl of fb_cpu_t65 is

	signal i_t65_RnW			: std_logic;
	signal i_t65_SYNC			: std_logic;
	signal i_t65_A	 			: std_logic_vector(23 downto 0);
	signal i_t65_D_in			: std_logic_vector(7 downto 0);
	signal i_t65_D_out		: std_logic_vector(7 downto 0);
	signal r_t65_res_n		: std_logic;


	signal i_cpu65_nmi_n		: std_logic;

	signal r_prev_A0			: std_logic;

	-- count down to next cycle - when all 1's can proceed
	constant CLK_BITS : natural := (CLOCKSPEED/MAXSPEED) - 1;
	signal r_cpu_clk			: std_logic_vector(CLK_BITS - 1 downto 0) := (others => '0');

	-- r_t65_clken '1' for one cycle to complete a cycle/start another
	signal r_t65_clken		: std_logic := '0';
	signal r_t65_clken_h		: std_logic := '0'; -- clocken masked by halt
	-- the above signal delayed
	signal r_clken_dly		: std_logic_vector(CLKEN_DLY_MAX downto 0) := (0 => '1', others => '0');

	signal r_cpu_halt			: std_logic;

	signal r_throttle_sync  : std_logic;		-- hold throttle for the rest of the instruction
	signal i_throttle			: std_logic;		-- '1' if current throttle or sync throttle
	signal r_had_phi2			: std_logic;		-- a phi2 occurred already while we were waiting for ack

	signal i_wrap_cyc 		: std_logic;

	signal i_wrap_ack 		: std_logic;
	signal r_wrap_acked		: std_logic;

	signal r_irq_n				: std_logic;

	--TODO: throttle only works on SYS_BBC, on Elk it repeats cycles!

begin

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity error;

	-- this will go active either for ever if BLTURBO T or at some point during
	-- the current cycle if BLTURBO R and may stay active to next SYNC
	i_throttle <= r_throttle_sync or wrap_i.throttle_cpu_2MHz;

	-- NOTE: need to latch address on dly(1) not dly(0) as it was unreliable

	i_wrap_cyc			<= '1' when wrap_i.noice_debug_inhibit_cpu = '0' and r_cpu_halt = '0' and r_t65_clken /= '1' else
								'0';

	wrap_o.BE				<= '0';
	wrap_o.A 				<= x"FF" & i_t65_A(15 downto 0);
	wrap_o.cyc				<= i_wrap_cyc;
	wrap_o.lane_req   	<= (0 => '1', others => '0');
	wrap_o.rdy_ctdn   	<= RDY_CTDN_MIN;
	wrap_o.we	 			<= not i_t65_RnW;
	wrap_o.D_WR(7 downto 0) <= i_t65_D_out;
	G_D_WR_EXT:if C_CPU_BYTELANES > 1 GENERATE
		wrap_o.D_WR((8*C_CPU_BYTELANES)-1 downto 8) <= (others => '-');
	END GENERATE;
	wrap_o.D_WR_stb 		<= (0 => r_clken_dly(2), others => '0');								-- TEST late Data strobe TODOPIPE: put this back to (0)
	wrap_o.instr_fetch  	<= i_t65_SYNC;

	i_cpu65_nmi_n <= wrap_i.nmi_n and wrap_i.noice_debug_nmi_n;

	p_reg_cken:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_throttle_sync <= '0';
			r_had_phi2 <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if r_t65_clken = '1' then
				r_had_phi2 <= '0';
				if i_t65_SYNC = '1' then
					r_throttle_sync <= wrap_i.throttle_cpu_2MHz;
				end if;
			elsif r_cpu_clk(0) = '1' and wrap_i.cpu_2MHz_phi2_clken = '1' then
				-- we were waiting for an ack when a phi2 happened
				r_had_phi2 <= '1';
			end if;
		end if;
	end process;

	p_clken:process(all)
	variable v_t65_clken : std_logic;
	begin
		if fb_syscon_i.rst = '1' then
			r_t65_clken <= '0';
			r_t65_clken_h <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if r_t65_clken = '0'
							and r_cpu_clk(0) = '1' 
							and (i_throttle = '0' or wrap_i.cpu_2MHz_phi2_clken = '1' or r_had_phi2 = '1') 
							and (		
									i_wrap_ack = '1' or 
									wrap_i.noice_debug_inhibit_cpu = '1' or
									r_cpu_halt = '1'
									) then
				v_t65_clken := '1';
			else
				v_t65_clken := '0';
			end if;

			r_t65_clken <= v_t65_clken;
			r_t65_clken_h <= v_t65_clken and not r_cpu_halt;

		end if;
	end process;

	p_reset:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_t65_res_n <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			r_t65_res_n <= cpu_en_i;
		end if;
	end process;


	i_t65_D_in <= wrap_i.D_rd(7 downto 0) when i_t65_RnW = '1' else
					  i_t65_D_out;
	
	p_rdy:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_cpu_halt <= '0';
			r_wrap_acked <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if r_t65_clken = '1' then
				r_cpu_halt <= wrap_i.cpu_halt;
				r_wrap_acked <= '0';
			else
				if wrap_i.ack = '1' then
					r_wrap_acked <= '1';
				end if;
			end if;
		end if;			
	end process;

	i_wrap_ack <= r_wrap_acked or wrap_i.ack;

	p_irq:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			r_irq_n <= wrap_i.irq_n;
		end if;
	end process;

	e_cpu: entity work.T65 
  	port map (
   	Mode    => "00", 		-- 6502A
   	Res_n   => r_t65_res_n,
   	Enable  => r_t65_clken_h,
   	Clk     => fb_syscon_i.clk,
   	Rdy     => '1',
   	Abort_n => '1',
   	IRQ_n   => r_irq_n,
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
			if r_t65_clken = '1' then
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
				r_clken_dly <= r_clken_dly(r_clken_dly'high-1 downto 0) & r_t65_clken;
			end if;
		end if;
	end process;


  	p_prev_a0:process(fb_syscon_i) 
  	begin
  		if fb_syscon_i.rst = '1' then
  			r_prev_A0 <= '0';
  		elsif rising_edge(fb_syscon_i.clk) then
  			if r_t65_clken = '1' then
  				r_prev_A0 <= i_t65_A(0);
  			end if;
  		end if;
  	end process;


--TODO: reinstate?
--	wrap_o.noice_debug_A0_tgl <= r_prev_A0 xor i_t65_A(0);
--
--  	wrap_o.noice_debug_cpu_clken <= r_t65_clken_h;
--  	
--  	wrap_o.noice_debug_5c	 <=
--  								'1' when 
--  										i_t65_SYNC = '1' 
--  										and i_t65_D_in = x"5C" else
--  								'0';
--
--  	wrap_o.noice_debug_opfetch <= i_t65_SYNC;

wrap_o.noice_debug_A0_tgl <= '0';
wrap_o.noice_debug_cpu_clken <= '0';
wrap_o.noice_debug_5c <= '0';
wrap_o.noice_debug_opfetch <= '0';


end rtl;
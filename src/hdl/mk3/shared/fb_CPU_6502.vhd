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
-- Additional Comments: NOTE: abandoned 18/8/2020, 6502A is just too slow to set up address to be usable
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.board_config_pack.all;
use work.fb_cpu_pack.all;

entity fb_cpu_6502 is
		generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		G_JIM_DEVNO							: std_logic_vector(7 downto 0);
		CLKEN_DLY_MAX						: natural := 20;								-- used to time latching of address etc signals
		G_BYTELANES							: positive	:= 1		
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		fb_syscon_i								: in	fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i
);
end fb_cpu_6502;

architecture rtl of fb_cpu_6502 is
	signal r_prev_A0			: std_logic;

	signal i_cpu_clk			: fb_cpu_clks_t;

	signal r_clken_dly		: std_logic_vector(CLKEN_DLY_MAX downto 0) := (others => '0');
	signal r_clken_phi0_dly	: std_logic_vector(CLKEN_DLY_MAX downto 0) := (others => '0');
	signal r_cpu_stretch		: std_logic;

	signal i_cpu_clken		: std_logic;	-- end of phi0 and cycle stretch finished

	signal i_CPUSKT_PHI0_o	: std_logic;
	signal i_CPUSKT_RDY_o	: std_logic;
	signal i_CPUSKT_nIRQ_o	: std_logic;
	signal i_CPUSKT_nNMI_o	: std_logic;
	signal i_CPUSKT_nRES_o	: std_logic;

	signal i_CPUSKT_RnW_i	: std_logic;
	signal i_CPUSKT_PHI2_i	: std_logic;
	signal i_CPUSKT_SYNC_i	: std_logic;

	signal i_wrap_cyc 		: std_logic;
begin

	wrap_o.exp_PORTB(0) <= '0';
	wrap_o.exp_PORTB(1) <= '1';
	wrap_o.exp_PORTB(2) <= i_CPUSKT_PHI0_o;
	wrap_o.exp_PORTB(3) <= i_CPUSKT_RDY_o;
	wrap_o.exp_PORTB(4) <= i_CPUSKT_nIRQ_o;
	wrap_o.exp_PORTB(5) <= i_CPUSKT_nNMI_o;
	wrap_o.exp_PORTB(6) <= i_CPUSKT_nRES_o;
	wrap_o.exp_PORTB(7) <= '1';

	i_CPUSKT_RnW_i			<= wrap_i.exp_PORTD(1);
	i_CPUSKT_PHI2_i		<= wrap_i.exp_PORTD(3);
	i_CPUSKT_SYNC_i		<= wrap_i.exp_PORTD(4);

	wrap_o.exp_PORTD <= (
		others => '1'
		);

	wrap_o.exp_PORTD_o_en <= (
		others => '0'
		);

	wrap_o.exp_PORTE_nOE <= '0';
	wrap_o.exp_PORTF_nOE <= '1';

	wrap_o.CPU_D_RnW <= 	'1' 	when i_CPUSKT_RnW_i = '1' and i_CPUSKT_PHI26VDAKFC0ZnMREQ_i = '1' else
							'0';

	i_wrap_cyc <= '1' when r_clken_dly(18) = '1' else '0';

	wrap_o.cyc_cpu_speed <= MHZ_2;
	wrap_o.A_log 			<= x"FF" & wrap_i.CPUSKT_A(15 downto 0);
	wrap_o.cyc 				<= (0 => i_wrap_cyc_o, others => '0');
	wrap_o.we  			<= not(i_CPUSKT_RnW_i);
	wrap_o.D_wr				<=	wrap_i.CPUSKT_D(7 downto 0);	
	wrap_o.D_wr_stb		<= r_clken_phi0_dly(8);
	wrap_o.ack				<= wrap_i.rdy and i_cpu_clk.cpu_clken and not r_cpu_stretch;
		
	i_CPUSKT_PHI0_o <= i_cpu_clk.cpu_clk_E or r_cpu_stretch;
		
	i_CPUSKT_nRES_o <= (not fb_syscon_i.rst) when cpu_en_i = '1' else '0';
	
	i_CPUSKT_nNMI_o <= wrap_i.noice_debug_nmi_n and wrap_i.nmi_n;
	
	i_CPUSKT_nIRQ_o <=  wrap_i.irq_n;
  	
  	i_CPUSKT_RDY_o <=	'1' when fb_syscon_i.rst = '1' else
  							'1' when wrap_i.noice_debug_inhibit_cpu = '1' else
  							'0' when wrap_i.cpu_halt = '1' else
  							'1';						

	i_cpu_clk <= 	fb_syscon_i.cpu_clks(FB_CPUCLKINDEX(MHZ_2));


	i_cpu_clken <= i_cpu_clk.cpu_clken and not r_cpu_stretch;

  	p_cpu_6x09_stretch:process(fb_syscon_i)
  	begin
  		if fb_syscon_i.rst = '1' then
  			r_cpu_stretch <= '0';
  		elsif rising_edge(fb_syscon_i.clk) then
  			if i_cpu_clk.cpu_Q_clken = '1' then
				if wrap_i.rdy = '0' then
  					r_cpu_stretch <= '1';
  				else
  					r_cpu_stretch <= '0';
  				end if;
  			end if;
  		end if;
  	end process;


	p_clken_dly:process(fb_syscon_i)
	variable v_cur_phi0 : std_logic := '0';
	variable	v_pre_phi0 : std_logic := '0';
	begin
		if rising_edge(fb_syscon_i.clk) then
			v_cur_phi0 := (i_cpu_clk.cpu_clk_E or r_cpu_stretch);
			r_clken_dly <= r_clken_dly(r_clken_dly'high-1 downto 0) & i_cpu_clk.cpu_clken;
			r_clken_phi0_dly <= r_clken_phi0_dly(r_clken_phi0_dly'high-1 downto 0) & (v_cur_phi0 and (v_cur_phi0 xor v_pre_phi0));
			v_pre_phi0 := v_cur_phi0;
		end if;
	end process;



   p_prev_a0:process(fb_syscon_i) 
  	begin
  		if fb_syscon_i.rst = '1' then
  			r_prev_A0 <= '0';
  		elsif rising_edge(fb_syscon_i.clk) then
  			if i_cpu_clken = '1' then
  				r_prev_A0 <= wrap_i.CPUSKT_A(0);
  			end if;
  		end if;
  	end process;


	wrap_o.noice_debug_A0_tgl <= r_prev_A0 xor wrap_i.CPUSKT_A(0);

  	wrap_o.noice_debug_cpu_clken <= i_cpu_clken;
  	
  	wrap_o.noice_debug_5c	 <= '0';
--  								'1' when 
--  										i_CPUSKT_SYNC_i = '1' 
--  										and wrap_i.CPUSKT_D(7 downto 0) = x"5C" else
--  								'0';
--
  	wrap_o.noice_debug_opfetch <= i_CPUSKT_SYNC_i;



end rtl;
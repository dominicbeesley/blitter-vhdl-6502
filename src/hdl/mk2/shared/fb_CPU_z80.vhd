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

entity fb_cpu_z80 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		fb_syscon_i								: in	fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i

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
	signal r_cpu_clk_ne		: std_logic;
	signal r_cpu_clk_pe		: std_logic;


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

	signal i_CPUSKT_nRD_i		: std_logic;
	signal i_CPUSKT_nWR_i		: std_logic;
	signal i_CPUSKT_nMREQ_i		: std_logic;
	signal i_CPUSKT_nM1_i		: std_logic;
	signal i_CPUSKT_nRFSH_i		: std_logic;
	signal i_CPUSKT_nIOREQ_i	: std_logic;
	signal i_CPUSKT_nBUSACK_i	: std_logic;

begin

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity error;

	wrap_o.CPUSKT_6BE9TSCKnVPA 		<= '1';
	wrap_o.CPUSKT_9Q 						<= '1';
	wrap_o.CPUSKT_KnBRZnBUSREQ 		<= i_CPUSKT_nBUSREQ_o;
	wrap_o.CPUSKT_PHI09EKZCLK 			<= i_CPUSKT_CLK_o;
	wrap_o.CPUSKT_RDY9KnHALTZnWAIT	<= i_CPUSKT_nWAIT_o;
	wrap_o.CPUSKT_nIRQKnIPL1			<= i_CPUSKT_nIRQ_o;
	wrap_o.CPUSKT_nNMIKnIPL02			<= i_CPUSKT_nNMI_o;
	wrap_o.CPUSKT_nRES					<= i_CPUSKT_nRES_o;
	wrap_o.CPUSKT_9nFIRQLnDTACK		<= '1';

	i_CPUSKT_nRD_i		<= wrap_i.CPUSKT_6EKEZnRD;
	i_CPUSKT_nWR_i		<= wrap_i.CPUSKT_RnWZnWR;
	i_CPUSKT_nMREQ_i	<= wrap_i.CPUSKT_PHI26VDAKFC0ZnMREQ;
	i_CPUSKT_nM1_i		<= wrap_i.CPUSKT_SYNC6VPA9LICKFC2ZnM1;
	i_CPUSKT_nRFSH_i	<= wrap_i.CPUSKT_VSS6VPA9BAKnAS;
	i_CPUSKT_nIOREQ_i	<= wrap_i.CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ;
	i_CPUSKT_nBUSACK_i<= wrap_i.CPUSKT_C6nML9BUSYKnBGZnBUSACK;


	wrap_o.CPU_D_RnW <= '0' when i_CPUSKT_nRD_i = '1' else
					 	'1';

	--TODO: mark rdy earlier!
	--TODO: register this signal (metastable vs z80?)
	i_rdy <= '1' when wrap_i.rdy_ctdn = RDY_CTDN_MIN else 
				'0';


	wrap_o.cyc 				<= ( 0 => r_act, others => '0');
	wrap_o.we  				<= r_WE;
	wrap_o.D_wr				<=	wrap_i.CPUSKT_D(7 downto 0);	
	wrap_o.D_wr_stb		<= r_WR_stb;
	wrap_o.ack				<= not r_act;
	wrap_o.A_log			<= r_A_log;
  		

  	i_A_log <=						x"FFFD" & wrap_i.CPUSKT_A(7 downto 0) when i_CPUSKT_nIOREQ_i = '0' else 
  										x"FF" & wrap_i.CPUSKT_A(15 downto 0) when (wrap_i.CPUSKT_A(15 downto 8) = x"FC" or wrap_i.CPUSKT_A(15 downto 8) = x"FD" or wrap_i.CPUSKT_A(15 downto 8) = x"FE") else
										x"FF" & '0' & wrap_i.CPUSKT_A(14 downto 0) when wrap_i.CPUSKT_A(15) = '1' else 	-- 8000-FFFF from SYS 0-7FFF (for screen)
  										x"00" & wrap_i.CPUSKT_A(15 downto 0); 	-- low memory from chip ram

	p_cpu_clk:process(fb_syscon_i)
	begin

		if rising_edge(fb_syscon_i.clk) then

			r_cpu_clk_pe <= '0';
			r_cpu_clk_ne <= '0';

			if r_clkctdn = 0 then
				if r_cpu_clk = '1' then
					r_cpu_clk_ne <= '1';
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

				if r_act = '0' and (i_CPUSKT_nMREQ_i = '0' or i_CPUSKT_nIOREQ_i = '0')
									and (i_CPUSKT_nRD_i = '0' or i_CPUSKT_nWR_i = '0')			-- had to add this as belt and braces
												and i_CPUSKT_nRFSH_i = '1' then						-- not sure we need this now? Might do for speed or might only need to qualify RD/WR on IORQ?
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
  												'1';						


  	--TODO: this doesn't look right
  	wrap_o.noice_debug_cpu_clken <= '1' when r_cpu_clk_pe = '1' and wrap_i.cyc = '1' and i_rdy = '1' else
  										'0';
  	
  	wrap_o.noice_debug_5c	 	 	<=	'0';

  	wrap_o.noice_debug_opfetch 	<= '1' when i_CPUSKT_nM1_i = '0' and i_CPUSKT_nMREQ_i = '0' else
  										'0';

	wrap_o.noice_debug_A0_tgl  	<= '0'; -- TODO: check if needed



end rtl;



-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2021 Dominic Beesley https://github.com/dominicbeesley
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
-- ----------------------------------------------------------------------


-- Company: 				Dossytronics
-- Engineer: 				Dominic Beesley
-- 
-- Create Date:    		29/1/2022
-- Design Name: 
-- Module Name:    		work.real80188
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 			mimic the external behaviour of a 80188 CPU
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: CAUTION: this is very much a work in progress and
--								only mimics the most basic parts of an 80188
--								
--
----------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity real80188_tb is
	generic (
		Tcico		:	time := 17 ns; -- X1 to clockout skew
		Tchsv		:	time := 25 ns; -- T4 Ck rise to valid status
		Tclav		:  time := 27 ns; -- address valid
		Tclax		:	time := 3 ns; --TODO: this should really be 0 and a data setup time added
		Tchlh		:  time := 20 ns -- ALE delay
	);
	port(

		X1_i		: in 		std_logic;
		SRDY_i	: in		std_logic;
		nRES_i	: in 		std_logic;		

		AD_io		: inout	std_logic_vector(7 downto 0);
		CLKOUT_o	: out 	std_logic;
		A_o		: out 	std_logic_vector(19 downto 8);
		ALE_o		: out		std_logic;
		nS_o		: out 	std_logic_vector(2 downto 0)

	);
end real80188_tb;

architecture behavioral of real80188_tb is

	type		cycle_t	is (
		IntAck,
		IO_R,
		IO_W,
		Halt,					-- TODO: work out how to divine this
		Instr_Fetch,		-- TODO: work out how to divine this
		Mem_Read,
		Mem_Write,
		Passive
		);

	type 		state_t	is (
		T1,T2,T3,T4
		);

	signal	r_cycle			: cycle_t;
	signal	r_state			: state_t;

	signal	r_CLK_int		: std_logic;
	signal	i_CLKOUT			: std_logic;

	signal	i_rtl_clk		: std_logic;
	signal	i_rtl_dbus_in	: std_logic_vector(7 downto 0);
	signal	i_rtl_intr		: std_logic;
	signal	i_rtl_nmi		: std_logic;
	signal	i_rtl_por		: std_logic;

	signal	i_rtl_abus		: std_logic_vector(19 downto 0);
	signal	i_rtl_dbus_out	: std_logic_vector(7 downto 0);
	signal	i_rtl_cpuerror	: std_logic;
	signal	i_rtl_inta		: std_logic;
	signal	i_rtl_iom		: std_logic;
	signal	i_rtl_rdn		: std_logic;
	signal	i_rtl_resoutn	: std_logic;
	signal	i_rtl_wran		: std_logic;
	signal	i_rtl_wrn		: std_logic;

	signal	i_nS				: std_logic_vector(2 downto 0);

	signal	r_S_act			: std_logic;
	signal	r_AD_act			: std_logic;

begin

	i_rtl_intr <= '0';
	i_rtl_nmi <= '0';
	i_rtl_por <= not nRES_i;

	p_ad_del:process
	begin
		wait until falling_edge(i_CLKOUT) and r_state = T4;
		wait for Tclav;
		AD_io <= i_rtl_abus(7 downto 0);
		A_o(19 downto 8) <= i_rtl_abus(19 downto 8);
		wait until falling_edge(i_CLKOUT);
		wait for Tclax;
		A_o(19 downto 16) <= (others => '0');
		if i_rtl_wrn = '0' then		-- TODO: should be a 3ns gap here
			AD_io <= i_rtl_dbus_out;
		else
			AD_io <= (others => 'Z');
		end if;
	end process;

	p_ale:process
	begin
		ALE_o <= '0';
		wait until rising_edge(i_CLKOUT) and r_state = T4;
		wait for Tchlh;
		ALE_o <= '1';
		wait until rising_edge(i_CLKOUT);
		wait for Tchlh;
	end process;




	p_state:process(i_CLKOUT)
	begin

		if falling_edge(i_CLKOUT) then
			case r_state is
				when T1 =>
					r_state <= T2;
				when T2 =>
					r_state <= T3;
					i_rtl_clk <= '0';
				when T3 =>
					if SRDY_i = '1' or nRES_i = '0' or r_cycle = passive then
						r_state <= T4;
						i_rtl_clk <= '1';				
					end if;
				when T4 =>
					r_state <= T1;
				when others =>
					r_state <= T1;
			end case;

		end if;

	end process;

	i_nS <= 	"000" when r_cycle = IntAck else
				"001"	when r_cycle = IO_R else
				"010"	when r_cycle = IO_W else
				"011"	when r_cycle = Halt else
				"100"	when r_cycle = Instr_Fetch else
				"101"	when r_cycle = Mem_Read else
				"110"	when r_cycle = Mem_Write else
				"111";

	nS_o <= 	i_nS after Tchsv when r_s_act = '1' else
				(others => '1');

	p_reg_nS:process(i_CLKOUT)
	begin
		if rising_edge(i_CLKOUT) and r_state = T4 then
			r_s_act <= '1';
			if nRES_i = '0' then
				r_cycle <= passive;
			elsif i_rtl_inta = '0' then
				r_cycle <= IntAck;
			elsif i_rtl_iom = '1' and i_rtl_rdn = '0' then
				r_cycle <= IO_R;
			elsif i_rtl_iom = '1' and i_rtl_wrn = '0' then
				r_cycle <= IO_W;
			elsif i_rtl_iom = '0' and i_rtl_rdn = '0' then
				r_cycle <= Mem_Read;
			elsif i_rtl_iom = '0' and i_rtl_wrn = '0' then
				r_cycle <= Mem_Write;
			else
				r_cycle <= passive;
			end if;
		end if;

		if falling_edge(i_CLKOUT) and r_state = T2 then
			r_s_act <= '0';
		end if;
	end process;


	p_X1:process(X1_i)
	begin
		if falling_edge(X1_i) then
			if r_CLK_int = '0' then
				r_CLK_int <= '1';
			else
				r_CLK_int <= '0';
			end if;
		end if;
	end process;

	i_CLKOUT <= r_CLK_int after Tcico;
	CLKOUT_o <= i_CLKOUT;

	e_cpu86:entity work.cpu86
   port map( 
      clk      => i_rtl_clk,
      dbus_in  => i_rtl_dbus_in,
      intr     => i_rtl_intr,
      nmi      => i_rtl_nmi,
      por      => i_rtl_por,

      abus     => i_rtl_abus,
      dbus_out => i_rtl_dbus_out,
      cpuerror => i_rtl_cpuerror,
      inta     => i_rtl_inta,
      iom      => i_rtl_iom,
      rdn      => i_rtl_rdn,
      resoutn  => i_rtl_resoutn,
      wran     => i_rtl_wran,
      wrn      => i_rtl_wrn
   );




end behavioral;
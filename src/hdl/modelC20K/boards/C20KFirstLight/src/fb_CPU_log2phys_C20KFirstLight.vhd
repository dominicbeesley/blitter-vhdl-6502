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
-- ----------------------------------------------------------------------

-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	24/10/2022
-- Design Name: 
-- Module Name:    	fishbone bus - CPU address translation and wait
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A pass-through fishbone component that translates logical to 
--							physical addresses - this one does nothing!
-- Dependencies: 
--
-- Revision: 
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;

entity fb_cpu_log2phys_simple16 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;										-- fast clock speed in mhz						
		G_MK3									: boolean := false		
	);
	port(

		fb_syscon_i								: in	fb_syscon_t;

		-- controller interface from the cpu
		fb_con_c2p_i							: in fb_con_o_per_i_t;
		fb_con_p2c_o							: out	fb_con_i_per_o_t;

		fb_per_c2p_o							: out fb_con_o_per_i_t;
		fb_per_p2c_i							: in	fb_con_i_per_o_t;

		-- memory control and paging
		JIM_page_i							: in  std_logic_vector(15 downto 0);
		JIM_en_i								: in  std_logic

	);
end fb_cpu_log2phys_simple16;


architecture rtl of fb_cpu_log2phys_simple16 is 

	type state_t is (idle, wait_a_ack);

	signal r_state 		: state_t;

	signal r_A_ack_host				: std_logic;
	signal r_cyc						: std_logic;
	signal r_A_stb_client			: std_logic;							-- output address strobe
	signal i_A_stb_host				: std_logic;							-- input qualified address strobe
	signal i_phys_A					: std_logic_vector(23 downto 0);
	signal r_phys_A					: std_logic_vector(23 downto 0);
	signal r_we							: std_logic;
	signal r_D_wr_stb					: std_logic;
	signal r_D_wr						: std_logic_vector(7 downto 0);
	signal r_rdy_ctdn					: t_rdy_ctdn;


begin


	fb_con_p2c_o.A_ack <= r_A_ack_host;
	fb_con_p2c_o.D_rd <= fb_per_p2c_i.D_rd;
 	-- gate with r_cyc: our cyc to the peripheral drops a clock after the host's,
   -- so a D_ack from the aborted cycle could otherwise reach the host
   fb_con_p2c_o.D_ack <= fb_per_p2c_i.D_ack and r_cyc;
   fb_con_p2c_o.rdy   <= fb_per_p2c_i.rdy and r_cyc;

	fb_per_c2p_o.cyc			<=	r_cyc;
	fb_per_c2p_o.we			<=	r_we;
	fb_per_c2p_o.A				<=	r_phys_A;
	fb_per_c2p_o.A_stb		<= r_A_stb_client;
	fb_per_c2p_o.D_wr			<= r_D_wr;
	fb_per_c2p_o.D_wr_stb	<= r_D_wr_stb;
	fb_per_c2p_o.rdy_ctdn	<= r_rdy_ctdn;

	-- ================================================================================================ --
	-- State Machine 
	-- ================================================================================================ --

	i_A_stb_host 	<= '1' when fb_con_c2p_i.cyc = '1' and fb_con_c2p_i.a_stb = '1' and r_state = idle else
					'0';


	p_state:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_state <= idle;
			r_phys_A <= (others => '0');
			r_cyc <= '0';
			r_we <= '0';
			r_D_wr_stb <= '0';
			r_D_wr <= (others => '0');
			r_rdy_ctdn <= RDY_CTDN_MAX;
			r_a_stb_client <= '0';
			r_A_ack_host <= '0';
		elsif rising_edge(fb_syscon_i.clk) then

			r_a_stb_client <= '0';
			r_A_ack_host <= '0';

			-- write data: registered copy of the host's, which it holds until
         -- D_ack. Masked in the clock after the peripheral's D_ack (the host
         -- hasn't seen it yet); the peripheral's guard covers the clock after.
         r_D_wr_stb <= fb_con_c2p_i.D_wr_stb and not fb_per_p2c_i.D_ack;
         r_D_wr     <= fb_con_c2p_i.D_wr;
         -- rdy_ctdn is constant for the host's whole cyc, and r_cyc drops at
         -- the same edge the host's cyc is first seen low, so copying it every
         -- clock keeps it constant for our cyc too, with no enable needed
         -- (as fb_intcon_buffer)
         r_rdy_ctdn <= fb_con_c2p_i.rdy_ctdn;

			case r_state is
				when idle =>
					-- address and we follow the host every idle clock, so the host
					-- A_stb doesn't drive their enable; only the value at the
					-- accepting edge is used, and A_stb to the peripheral is low here.
					-- r_throttle_act stays on the strobe: throttle_act_o is used by
					-- the CPU wrapper after this transaction is accepted.
						r_phys_A <= i_phys_A;
						r_we <= fb_con_c2p_i.we;
					if i_A_stb_host then
						r_cyc <= '1';
						r_state <= wait_a_ack;
						r_a_stb_client <= '1';
						r_a_ack_host <= '1';
					end if;
				when wait_a_ack =>
					if fb_per_p2c_i.A_ack = '0' then
						r_a_stb_client <= '1';
						r_State <= wait_a_ack;
					else
							r_state <= idle;
					end if;
				when others =>
					r_state <= idle;
			end case;

			if fb_con_c2p_i.cyc = '0' then
				r_A_stb_client <= '0';
				r_cyc <= '0';
				r_state <= idle;
				r_D_wr_stb <= '0';
			end if;

		end if;
	end process;


	-- ================================================================================================ --
	-- Logical to physical address mapping 
	-- ================================================================================================ --



	p_l2p:process(all)
	begin
		
		i_phys_A <= fb_con_c2p_i.A;

		if fb_con_c2p_i.A(23 downto 16) = x"FF" then
			if fb_con_c2p_i.A(15 downto 12) >= x"8" and fb_con_c2p_i.A(15 downto 12) < x"F" then
				i_phys_A <= x"00" & '0' & fb_con_c2p_i.A(14 downto 0);
			elsif fb_con_c2p_i.A(15 downto 8) = x"FD" and JIM_en_i = '1' then
				i_phys_A <= JIM_page_i & fb_con_c2p_i.A(7 downto 0);
			end if;
		end if;

	end process;


end rtl;
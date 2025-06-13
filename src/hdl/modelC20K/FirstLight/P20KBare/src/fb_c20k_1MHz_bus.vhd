-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2023 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:    	25/4/2023
-- Design Name: 
-- Module Name:    	fb_c20k_1mhz_bus
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Simple 1MHz bus (FRED, JIM)
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
use work.common.all;
use work.fishbone.all;

entity fb_c20k_1mhz_bus is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural := 128								-- fast clock speed in mhz				
	);
	port(
		
		JIM_page_o							: out		std_logic_vector(15 downto 0);

		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t

	);
end fb_c20k_1mhz_bus;

architecture rtl of fb_c20k_1mhz_bus is

	signal r_JIM_page			: std_logic_vector(15 downto 0);

	signal r_fb_ack	: std_logic;
	type state_t is (idle, wait_wr_stb);
	signal r_state    : state_t;
	signal r_wr_addr	: std_logic_vector(3 downto 0);
	signal i_wr_addr	: std_logic_vector(3 downto 0);

begin

	JIM_page_o <= r_JIM_page;

	fb_p2c_o.D_rd <= 	r_JIM_page(15 downto 8) when fb_c2p_i.A(3 downto 0) = x"D" else
							r_JIM_page(7 downto 0)  when fb_c2p_i.A(3 downto 0) = x"E" else
							x"FF";

	fb_p2c_o.ack <= r_fb_ack;
	fb_p2c_o.rdy <= r_fb_ack;
	fb_p2c_o.stall <= '0' when r_state = idle else '1';

	i_wr_addr <= 	fb_c2p_i.A(3 downto 0) when r_state = idle else
						r_wr_addr;

	p_state:process(fb_syscon_i)
	variable v_dowrite: boolean;
	begin
		
		if fb_syscon_i.rst = '1' then
			r_fb_ack <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			
			v_dowrite := false;

			r_fb_ack <= '0';

			case r_state is
				when idle =>
					if fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' then
						r_wr_addr <= fb_c2p_i.A(3 downto 0);
						if fb_c2p_i.we = '1' then
							if fb_c2p_i.D_wr_stb = '1' then
								v_dowrite := true;
							else
								r_state <= wait_wr_stb;
							end if;
						else
							r_fb_ack <= '1';						
						end if;
					end if;
				when wait_wr_stb =>
					if fb_c2p_i.D_wr_stb = '1' then
						v_dowrite := true;
						r_state <= idle;
					end if;
				when others =>
					r_state <= idle;

			end case;


			if v_dowrite then
				if i_wr_addr(3 downto 0) = x"D" then
					r_JIM_page(15 downto 8) <= fb_c2p_i.D_wr;
				elsif i_wr_addr(3 downto 0) = x"E" then
					r_JIM_page(7 downto 0) <= fb_c2p_i.D_wr;
				end if;
				r_fb_ack <= '1';
			end if;

		end if;
	end process;


end rtl;
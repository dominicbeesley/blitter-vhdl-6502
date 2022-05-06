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
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	fishbone bus - Version string wrapper
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the blitter/cpu board's Version data
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
use work.firmware_info_pack.all;
use work.board_config_pack.all;

entity fb_version is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up
	);
	port(

		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;

		cfg_bits_i							: in		std_logic_vector(31 downto 0)
	);
end fb_version;

architecture rtl of fb_version is

	type 	 	state_mem_t is (idle, act, wrel);

	signal	state			: state_mem_t;

	signal 	r_ack 	: std_logic;
	signal	i_Q		: std_logic_vector(7 downto 0);
	signal	r_A		: std_logic_vector(7 downto 0);
	signal	r_Q		: std_logic_vector(7 downto 0);

begin


	fb_p2c_o.rdy_ctdn <= (others => '0') when state = wrel else to_unsigned(1, RDY_CTDN_LEN);
	fb_p2c_o.ack <= r_ack;
	fb_p2c_o.nul <= '0';
	fb_p2c_o.D_rd <= r_Q;

	e_version:entity work.version_rom port map (
		A => r_A(6 downto 0),
		Q => i_Q
	);

	p_state:process(fb_syscon_i)
	begin

		if fb_syscon_i.rst = '1' then
			state <= idle;
			r_ack <= '0';
			r_Q <= (others => '0');
			r_A <= (others => '0');
		else
			if rising_edge(fb_syscon_i.clk) then
				r_ack <= '0';
				case state is
					when idle =>
						if fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' then
							state <= act;
							r_A <= fb_c2p_i.A(7 downto 0);
						end if;
					when act =>
						if r_A(7) = '1' then
							case to_integer(unsigned('0' & r_A(2 downto 0))) is
								when 0 =>
									r_Q <= FW_API_level;
								when 1 =>
									r_Q <= std_logic_vector(to_unsigned(firmware_board_level'POS(FW_board_level), 8));
								when 2 => 
									r_Q <= FW_API_sublevel;
								when 4 =>
									r_Q <= cfg_bits_i(7 downto 0);
								when 5 =>
									r_Q <= cfg_bits_i(15 downto 8);
								when 6 =>
									r_Q <= cfg_bits_i(23 downto 16);
								when 7 =>
									r_Q <= cfg_bits_i(31 downto 24);
								when others =>
									r_Q <= x"00";
							end case;
						else
							r_Q <= i_Q;
						end if;
						r_ack <= '1';
						state <= wrel;
					when wrel => 
						state <= wrel;
					when others =>
						state <= idle;
				end case;

				if fb_c2p_i.cyc = '0' or fb_c2p_i.A_stb = '0' then
					state <= idle;
				end if;

			end if;
		end if;

	end process;


end rtl;
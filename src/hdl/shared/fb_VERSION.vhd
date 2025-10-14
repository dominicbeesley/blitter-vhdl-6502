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

	signal	i_cap_bits : std_logic_vector(23 downto 0);

	function to_std(b: boolean) return std_ulogic is
	begin
		if b then
			return '1';
		else
			return '0';
		end if;
	end function to_std;

begin

	i_cap_bits(0) 				<= to_std(G_INCL_CHIPSET);
	i_cap_bits(1) 				<= to_std(G_INCL_CS_DMA and G_INCL_CHIPSET);
	i_cap_bits(2) 				<= to_std(G_INCL_CS_BLIT and G_INCL_CHIPSET);
	i_cap_bits(3) 				<= to_std(G_INCL_CS_AERIS and G_INCL_CHIPSET);
	i_cap_bits(4) 				<= to_std(G_INCL_CS_EEPROM and G_INCL_CHIPSET);
	i_cap_bits(5) 				<= to_std(G_INCL_CS_SND and G_INCL_CHIPSET);
	i_cap_bits(6) 				<= to_std(G_INCL_HDMI);
	i_cap_bits(7) 				<= to_std(G_INCL_CPU_T65);
	i_cap_bits(8) 				<= to_std(G_INCL_CPU_65C02);
	i_cap_bits(9) 				<= to_std(G_INCL_CPU_6800);
	i_cap_bits(10)				<= to_std(G_INCL_CPU_80188);
	i_cap_bits(11)				<= to_std(G_INCL_CPU_65816);
	i_cap_bits(12)				<= to_std(G_INCL_CPU_6x09);
	i_cap_bits(13)				<= to_std(G_INCL_CPU_Z80);
	i_cap_bits(14)				<= to_std(G_INCL_CPU_68008);
	i_cap_bits(15)				<= to_std(G_INCL_CPU_680x0);
	i_cap_bits(16)				<= to_std(G_INCL_CPU_ARM2);
	i_cap_bits(17)				<= to_std(G_INCL_CPU_Z180);
	i_cap_bits(18)				<= '0';							-- reserved for GFoot supershadow
	i_cap_bits(19)				<= to_std(G_MEM_FAST_IS_10);
	i_cap_bits(20)				<= to_std(G_MEM_SLOW_IS_45);
	i_cap_bits(21)				<= to_std(G_INCL_CPU_PICORV32);
	i_cap_bits(22)				<= to_std(G_INCL_CPU_HAZARD3);
	i_cap_bits(23) 				<= to_std(G_INCL_CS_SDCARD and G_INCL_CHIPSET);

	fb_p2c_o.rdy <= r_ack;
	fb_p2c_o.ack <= r_ack;
	fb_p2c_o.stall <= '0' when state = idle else '0';
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
							case to_integer(unsigned(r_A(3 downto 0))) is
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
								when 8 =>
									r_Q <= i_cap_bits(7 downto 0);
								when 9 =>
									r_Q <= i_cap_bits(15 downto 8);
								when 10 =>
									r_Q <= i_cap_bits(23 downto 16);
								when others =>
									r_Q <= x"00";
							end case;
						else
							r_Q <= i_Q;
						end if;
						r_ack <= '1';
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
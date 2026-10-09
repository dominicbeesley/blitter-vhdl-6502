-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2026 Dominic Beesley https://github.com/dominicbeesley
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

-- Company:          Dossytronics
-- Engineer:         Dominic Beesley
-- 
-- Create Date:      30/1/2026
-- Design Name: 
-- Module Name:      fb_config
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      A set of registers to configure the board
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

entity fb_config is
	generic (
		SIM                           : boolean := false                     -- skip some stuff, i.e. slow sdram start up
	);
	port(

		-- fishbone signals

		fb_syscon_i                   : in     fb_syscon_t;
		fb_c2p_i                      : in     fb_con_o_per_i_t;
		fb_p2c_o                      : out    fb_con_i_per_o_t;

		cfg_eco_station_id_o          : out    std_logic_vector(7 downto 0)
	);
end fb_config;


architecture rtl of fb_config is

	type     state_mem_t is (idle, act_rd, act_wr);

	signal   state       : state_mem_t;

	signal   r_D_ack  : std_logic;
	signal   r_A      : std_logic_vector(7 downto 0);
	signal   r_A_ack  : std_logic;
	signal   r_D_rd   : std_logic_vector(7 downto 0);
	
	signal   r_eco_station_id : std_logic_vector(7 downto 0);


	constant IX_STAT_ID  : natural := 16#10#;

begin

	cfg_eco_station_id_o <= r_eco_station_id;

	fb_p2c_o.A_ack    <= r_A_ack;
	fb_p2c_o.D_rd     <= r_D_rd;
	fb_p2c_o.rdy      <= r_D_ack;
	fb_p2c_o.D_ack    <= r_D_ack;


	p_state:process(fb_syscon_i)
	begin

		if fb_syscon_i.rst = '1' then
			state <= idle;
			r_D_ack <= '0';
			r_A_ack <= '0';
			r_D_rd <= (others => '0');
			r_A <= (others => '0');

			if fb_syscon_i.rst_state = resetfull or fb_syscon_i.rst_state = powerup then
				r_eco_station_id <= x"24";
			end if;
		elsif rising_edge(fb_syscon_i.clk) then

         r_D_ack <= '0';
         r_A_ack <= '0';
			case state is
				when idle =>
					if fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' then
                     if fb_c2p_i.we = '1' then
                        state <= act_wr;
							else
                        state <= act_rd;
							end if;
                     r_A <= fb_c2p_i.A(7 downto 0);
                     r_A_ack <= '1';
						end if;
               when act_wr =>
                  if fb_c2p_i.cyc = '1' and fb_c2p_i.D_wr_stb = '1' and r_D_ack = '0' then
							case to_integer(unsigned(r_A(7 downto 0))) is
								when IX_STAT_ID =>
                           r_eco_station_id <= fb_c2p_i.D_wr;
								when others => null;
                     end case;                  
                     r_D_ack <= '1';
                     state <= idle;
					end if;
               when act_rd =>
                  if fb_c2p_i.cyc = '1' then
                  	r_D_rd <= x"FF";
                     case to_integer(unsigned(r_A(7 downto 0))) is
								when IX_STAT_ID =>
									r_D_rd <= r_eco_station_id;
					    		when others => null;
					 		end case;
                     r_D_ack <= '1';
                  end if;
                  state <= idle;					
               when others =>
                  -- not sure if we should blindly ack here
                  state <= idle;
				end case;

			if fb_c2p_i.cyc = '0' then
				state <= idle;
			end if;
		end if;

	end process;


end rtl;
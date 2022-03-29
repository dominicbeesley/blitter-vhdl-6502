-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	fishbone bus - i2 exposed as an 8 bit r/w register
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for i2c eeprom
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

entity fb_i2c is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up
	);
	port(

		-- eeprom signals
		I2C_SCL_o							: out		std_logic;
		I2C_SDA_io							: inout	std_logic;

		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_m2s_i								: in		fb_mas_o_sla_i_t;
		fb_s2m_o								: out		fb_mas_i_sla_o_t

	);
end fb_i2c;

architecture rtl of fb_i2c is

	type 	 	state_mem_t is (idle, wait_cyc);

	signal	state			: state_mem_t;

	signal	r_mas_ack	:	std_logic;
	signal	r_mas_rdy	:	std_logic;

	signal	r_i2c_scl	: 	std_logic;
	signal	r_i2c_sda	: 	std_logic;

begin


	fb_s2m_o.rdy_ctdn <= 
		RDY_CTDN_MIN when r_mas_rdy = '1' else
		RDY_CTDN_MAX;
	fb_s2m_o.ack <= r_mas_ack;
	fb_s2m_o.nul <= '0';

	I2C_SDA_io <= 	'0' when r_i2c_sda = '0' else
						'Z';
	I2C_SCL_o <= 	r_i2c_scl;

	p_state:process(fb_syscon_i)
	begin

		if fb_syscon_i.rst = '1' then
			state <= idle;
			r_i2c_sda <= '1';
			r_i2c_scl <= '1';
			r_mas_ack <= '0';
		else
			if rising_edge(fb_syscon_i.clk) then
				r_mas_ack <= '0';

				case state is
					when idle =>
						r_mas_rdy <= '0';
						if (fb_m2s_i.cyc = '1' and fb_m2s_i.A_stb = '1') then
							if fb_m2s_i.we = '1' and fb_m2s_i.D_wr_stb = '1' then
								r_i2c_scl <= fb_m2s_i.D_wr(6);
								r_i2c_sda <= fb_m2s_i.D_wr(5);
								state <= wait_cyc;
								r_mas_rdy <= '1';
								r_mas_ack <= '1';
							elsif fb_m2s_i.we = '0' then
								fb_s2m_o.D_rd <= ( 7 => I2C_SDA_io, 6 => r_i2c_scl, 5 => r_i2c_sda, others => '1');
								state <= wait_cyc;
								r_mas_rdy <= '1';
								r_mas_ack <= '1';
							end if;
						end if;
					when wait_cyc =>
						if fb_m2s_i.cyc = '0' or fb_m2s_i.a_stb = '0' then
							state <= idle;
						end if;
					when others =>
						state <= idle;
				end case;
			end if;
		end if;

	end process;


end rtl;
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
-- Create Date:    	7/11/2020
-- Design Name: 
-- Module Name:    	Generate phi1/2 signals from a phi0
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		
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

entity fb_sys_phigen is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural
	);
	port(

		fb_syscon_i							: in		fb_syscon_t;


		phi0_i								: in	std_logic;
		phi1_o								: out	std_logic;
		phi2_o								: out	std_logic


	);
end fb_sys_phigen;

architecture rtl of fb_sys_phigen is

	signal 	r_sys_phi0_dly 	: std_logic_vector(2 downto 0) := (others => '0');
	signal 	i_gen_phi1 			: std_logic;
	signal 	i_gen_phi2 			: std_logic;


begin

	phi2_o <= i_gen_phi2;
	phi1_o <= i_gen_phi1;

	i_gen_phi1 <= not r_sys_phi0_dly(2);
	i_gen_phi2 <= r_sys_phi0_dly(1) and r_sys_phi0_dly(2);


	p_dly_phi0:process(fb_syscon_i.clk, phi0_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			r_sys_phi0_dly <= r_sys_phi0_dly(r_sys_phi0_dly'high-1 downto 0) & phi0_i;
		end if;
	end process;	

end rtl;
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	21/9/2021
-- Design Name: 
-- Module Name:    	fishbone bus - HDMI dual head wrapper
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the blitter/cpu board's secondary screen
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



architecture rtl_disabled of fb_hdmi is
begin
	-- this is included if HDMI is not configured at top leve

	HDMI_SCL_io		<= 'Z';
	HDMI_SDA_io		<= 'Z';

	HDMI_CK_o		<= '1';
	HDMI_R_o			<= '1';
	HDMI_G_o			<= '1';
	HDMI_B_o			<= '1';

	VGA_R_o			<= '1';
	VGA_G_o			<= '1';
	VGA_B_o			<= '1';
	VGA_HS_o			<= '1';
	VGA_VS_o			<= '1';
	VGA_BLANK_o		<= '1';

	fb_p2c_o.rdy_ctdn <= RDY_CTDN_MIN;
	fb_p2c_o.nul <= '1';
	fb_p2c_o.ack <= '1';
	fb_p2c_o.D_Rd <= (others => '0');

end rtl_disabled;

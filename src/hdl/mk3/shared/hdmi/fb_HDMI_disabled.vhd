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
-- Additional Comments: This is a "disabled" version 
--
----------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;
use work.fishbone.all;

entity fb_HDMI is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural
	);
	port(

		CLK_48M_i							: in		std_logic;

		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;

		HDMI_SCL_io							: inout	std_logic;
		HDMI_SDA_io							: inout	std_logic;
		HDMI_HPD_i							: in		std_logic;
		HDMI_CK_o							: out		std_logic;
		HDMI_R_o								: out		std_logic;
		HDMI_G_o								: out		std_logic;
		HDMI_B_o								: out		std_logic;

		-- debug video	

		VGA_R_o								: out		std_logic;
		VGA_G_o								: out		std_logic;
		VGA_B_o								: out		std_logic;
		VGA_HS_o								: out		std_logic;
		VGA_VS_o								: out		std_logic;
		VGA_BLANK_o							: out		std_logic

	);
end fb_HDMI;


architecture rtl of fb_hdmi is
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

end rtl;

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

entity fb_HDMI is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural
	);
	port(

		CLK_48M_i							: in		std_logic;

		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_m2s_i								: in		fb_mas_o_sla_i_t;
		fb_s2m_o								: out		fb_mas_i_sla_o_t;

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


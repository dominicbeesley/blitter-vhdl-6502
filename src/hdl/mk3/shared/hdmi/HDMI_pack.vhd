-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2021 Dominic Beesley https://github.com/dominicbeesley
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


-- Company: 				Dossytronics
-- Engineer: 				Dominic Beesley
-- 
-- Create Date:    		9/11/2021
-- Design Name: 
-- Module Name:    		work.hdmi_pack
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 			HDMI shared definitions
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;
use work.fishbone.all;

package HDMI_pack is


	component fb_HDMI is
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

		-- analogue video	

		VGA_R_o								: out		std_logic_vector(3 downto 0);
		VGA_G_o								: out		std_logic_vector(3 downto 0);
		VGA_B_o								: out		std_logic_vector(3 downto 0);
		VGA_HS_o								: out		std_logic;
		VGA_VS_o								: out		std_logic;
		VGA_BLANK_o							: out		std_logic;

		-- retimed analogue video
		VGA27_R_o							: out		std_logic_vector(3 downto 0);
		VGA27_G_o							: out		std_logic_vector(3 downto 0);
		VGA27_B_o							: out		std_logic_vector(3 downto 0);
		VGA27_HS_o							: out		std_logic;
		VGA27_VS_o							: out		std_logic;
		VGA27_BLANK_o						: out		std_logic;

		-- sysvia latch scroll registers

		scroll_latch_c_i					: in		std_logic_vector(1 downto 0);

		PCM_L_i								: in		signed(9 downto 0);

		debug_vsync_det_o			: out std_logic;
		debug_hsync_det_o			: out std_logic;
		debug_hsync_crtc_o			: out std_logic;
		debug_odd_o					: out std_logic


	);
	end component;
end package HDMI_pack;


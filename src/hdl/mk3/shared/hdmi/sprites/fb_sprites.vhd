-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	22/9/2021
-- Design Name: 
-- Module Name:    	fishbone bus - sprites control wrapper
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the model b/c sprites
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
use work.sprites_pack.all;
use work.fishbone.all;

entity fb_sprites is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		G_N_SPRITES							: positive := 8
	);
	port(

		-- fishbone signals for cpu/dma port

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;

		-- data interface, from sequencer
		SEQ_D_i								: in	std_logic_vector(7 downto 0);
		SEQ_wren_i							: in	std_logic;
		SEQ_A_i								: in	unsigned(numbits(G_N_SPRITES) + 3 downto 0);			
																								-- sprite data A..D, pos/ctl, ptr, lst (see below in p_regs)
		SEQ_DATAPTR_inc_i					: in	std_logic_vector(G_N_SPRITES-1 downto 0);
																								-- increment pointer this clock
		-- addresses out to sequencer
		SEQ_DATAPTR_A_o					: out t_spr_addr_array(G_N_SPRITES-1 downto 0);


		-- vidproc / crtc signals in

		pixel_clk_i							: in		std_logic;							-- clock in video domain (48MHz)
		pixel_cken_i						: in		std_logic;							-- 8MHz@64uS line (512 per line) pixel clock should be aligned with fb clock
		vsync_i								: in		std_logic;
		hsync_i								: in		std_logic;
		disen_i								: in		std_logic;
		
		-- pixels out
		pixel_act_o							: out		std_logic;
		pixel_o								: out		std_logic_vector(3 downto 0)
	

	);
end fb_sprites;

architecture rtl of fb_sprites is
	

begin


end rtl;
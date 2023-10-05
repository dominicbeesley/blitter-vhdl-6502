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
		-- addresses out to sequencer
		SEQ_DATAPTR_A_o					: out t_spr_addr_array(G_N_SPRITES-1 downto 0);
		SEQ_DATAPTR_act_o					: out std_logic_vector(G_N_SPRITES-1 downto 0);		-- indicates a request for this address
		SEQ_DATA_REQ_o						: out std_logic;							-- toggles once per line to inform sequencer to redo data

		-- vidproc / crtc signals in

		pixel_clk_i							: in		std_logic;							-- clock in video domain (48MHz)
		pixel_clken_i						: in		std_logic;							-- 8MHz@64uS line (512 per line) pixel clock should be aligned with fb clock
		vsync_i								: in		std_logic;
		hsync_i								: in		std_logic;
		disen_i								: in		std_logic;
		
		-- pixels out
		pixel_act_o							: out		std_logic;
		pixel_o								: out		std_logic_vector(3 downto 0)
	

	);
end fb_sprites;

architecture rtl of fb_sprites is
	
	-- FISHBONE wrapper signals
	type	 per_state_t is (idle, rd, wait_d_stb);
	signal r_per_state 					: per_state_t;

	constant C_A_SIZE						: natural := numbits(G_N_SPRITES) + 4;

	signal r_A								: std_logic_vector(C_A_SIZE-1 downto 0);
	signal r_d_wr							: std_logic_vector(7 downto 0);
	signal r_d_wr_stb						: std_logic;
	signal r_ack							: std_logic;

begin

		-- FISHBONE wrapper for CPU/DMA access
	fb_p2c_o.ack <= r_ack;
	fb_p2c_o.rdy <= r_ack;
	fb_p2c_o.stall <= '0' when r_per_state = idle else '1';

	p_per_state:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_per_state <= idle;
			r_ack <= '0';
			r_d_wr_stb <= '0';
			r_d_wr <= (others => '0');
			r_A <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
			r_ack <= '0';
			r_d_wr_stb <= '0';
			case r_per_state is
				when idle =>
					if fb_c2p_i.cyc = '1' and fb_c2p_i.a_stb = '1' then
						r_A <= fb_c2p_i.A(C_A_SIZE-1 downto 0);
						if fb_c2p_i.we = '1' then
							if fb_c2p_i.D_wr_stb = '1' then
								r_d_wr_stb <= '1';
								r_d_wr <= fb_c2p_i.d_wr;
								r_ack <= '1';
								r_per_state <= idle;
							else
								r_per_state <= wait_d_stb;
							end if;
						else
							r_per_state <= rd;
						end if;
					end if;
				when wait_d_stb =>
					if fb_c2p_i.D_wr_stb = '1' then
						r_d_wr_stb <= '1';
						r_d_wr <= fb_c2p_i.d_wr;
						r_ack <= '1';
						r_per_state <= idle;
					else
						r_per_state <= wait_d_stb;
					end if;
				when rd =>
					r_ack <= '1';
					r_per_state <= idle;	
				when others =>
					r_per_state <= idle;
					r_ack <= '1';
			end case;
		end if;
	end process;


e_sprites:entity work.sprites
	generic map (
		SIM							=> SIM,
		G_N_SPRITES					=> G_N_SPRITES
	)
	port map(

		rst_i							=> fb_syscon_i.rst,

		clk_i							=> fb_syscon_i.clk,
		clken_i						=> '1',

		-- data interface, from sequencer
		SEQ_D_i						=> SEQ_D_i,
		SEQ_wren_i					=> SEQ_wren_i,
		SEQ_A_i						=> SEQ_A_i,
																								-- sprite data A..D, pos/ctl, ptr, lst (see below in p_regs)
		-- addresses out to sequencer
		SEQ_DATAPTR_A_o			=> SEQ_DATAPTR_A_o,
		SEQ_DATAPTR_act_o			=> SEQ_DATAPTR_act_o,
		SEQ_DATA_req_o				=> SEQ_DATA_req_o,

		-- data interface, from CPU
		CPU_D_i						=> r_d_wr,
		CPU_wren_i					=> r_d_wr_stb,
		CPU_A_i						=> unsigned(r_A),

		-- vidproc / crtc signals in
		pixel_clk_i							=> pixel_clk_i,
		pixel_clken_i						=> pixel_clken_i,
		vsync_i								=> vsync_i,
		hsync_i								=> hsync_i,
		disen_i								=> disen_i,


		-- pixels out
		pixel_act_o					=> pixel_act_o,
		pixel_o						=> pixel_o

	);



end rtl;
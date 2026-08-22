-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2022 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:    	1/10/2023
-- Design Name: 
-- Module Name:    	sprites.vhd
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Model C sprite: main sprite outer wrapper
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
-- 	Inspired by Amiga sprites but tweaked to work in an 8-bit world
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.sprites_pack.all;
use work.common.all;

entity sprites is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		G_N_SPRITES							: natural := 4									-- maximum number of sprites
	);
	port(

		clk_48M_i							: in	std_logic;
		rst_i									: in	std_logic;							

		-- data interface, from sequencer
		SEQ_D_i								: in	std_logic_vector(7 downto 0);
		SEQ_wren_i							: in	std_logic;
		SEQ_A_i								: in	unsigned(numbits(G_N_SPRITES) + 3 downto 0);			
																								-- sprite data A..D, pos/ctl, ptr, lst (see below in p_regs)
		-- addresses out to sequencer
		SEQ_DATAPTR_A_o					: out t_spr_addr_array(G_N_SPRITES-1 downto 0);
		SEQ_DATAPTR_act_o					: out std_logic_vector(G_N_SPRITES-1 downto 0);		-- indicates a request for this address
		SEQ_DATA_REQ_o						: out std_logic;							-- toggles once per line to inform sequencer to redo data
		SEQ_A_pre_o							: out t_spr_pre_array(G_N_SPRITES-1 downto 0);

		-- data interface, from CPU
		CPU_D_i								: in	std_logic_vector(7 downto 0);
		CPU_A_i								: in	unsigned(numbits(G_N_SPRITES) + 3 downto 0);			-- sprite data A..D, pos/ctl, ptr, lst (see below in p_regs)
		CPU_wren_i							: in	std_logic;
		CPU_rden_i							: in  std_logic;
		CPU_D_o								: out   std_logic_vector(7 downto 0);--TODO: this for debugging only?
		CPU_wr_ack_o						: out   std_logic;
		CPU_rd_ack_o						: out   std_logic;

		-- vidproc / crtc signals in

		pixel_clken_i						: in		std_logic;							-- 8MHz@64uS line (512 per line) pixel clock should be aligned with fb clock
		vsync_i								: in		std_logic;
		hsync_i								: in		std_logic;
		disen_i								: in		std_logic;

		-- pixels out
		pixel_act_o							: out		std_logic;
		pixel_o								: out		std_logic_vector(3 downto 0);

		--debug out
		vert_ctr_o							: out		unsigned(8 downto 0);
		horz_ctr_o							: out		unsigned(8 downto 0)

	);
end sprites;

architecture rtl of sprites is

	constant C_A_SIZE						: natural := numbits(G_N_SPRITES) + 4;

	-- one hot from the SEQ_A_i/CPU_A_i to index each sprite
	signal i_SEQ_wren_oh		: std_logic_vector(G_N_SPRITES-1 downto 0);
	signal i_CPU_wren_oh		: std_logic_vector(G_N_SPRITES-1 downto 0);

	type t_arr_px is array (natural range <>) of std_logic_vector(1 downto 0);

	signal i_px_D				: t_arr_px(0 to G_N_SPRITES-1);

	type t_arr_pos is array (natural range <>) of unsigned(8 downto 0);

	signal i_horz_start 		: t_arr_pos(0 to G_N_SPRITES-1);
	signal i_vert_start 		: t_arr_pos(0 to G_N_SPRITES-1);
	signal i_vert_stop 		: t_arr_pos(0 to G_N_SPRITES-1);
	signal i_attach			: std_logic_vector(G_N_SPRITES-1 downto 0);

	
	-- local counter generation

	signal r_prev_hsync				: std_logic;
	signal r_prev_vsync				: std_logic;
	signal r_horz_ctr					: unsigned(8 downto 0);
	signal r_vert_ctr					: unsigned(8 downto 0);
	signal r_horz_disarm_clken		: std_logic;				-- disarm all sprites at "end" of line, needs to be before sequencer loads, think about moving elsewhere (sequencer?)
	signal r_vert_reload_clken		: std_logic;				-- pixel at which we reload sprite data pointers
	-- sequencer 
	signal r_data_req					: std_logic;

	type t_arr_d is array (natural range <>) of std_logic_vector(7 downto 0);

	signal i_CPU_D_o : t_arr_d(0 to G_N_SPRITES-1);
	signal i_CPU_wr_ack : std_logic_vector(G_N_SPRITES-1 downto 0);
	signal i_CPU_rd_ack : std_logic_vector(G_N_SPRITES-1 downto 0);


begin

assert G_N_SPRITES mod 2 = 0 report "There must be an even number of sprites" severity error;

	p_reg:process(rst_i, clk_48M_i)
	begin
		if rst_i then
			CPU_D_o <= (others => '0');
			CPU_wr_ack_o <= '0';
			CPU_rd_ack_o <= '0';
		elsif rising_edge(clk_48M_i) then
			CPU_D_o <= i_CPU_D_o(to_integer(unsigned(CPU_A_i(C_A_SIZE-1 downto 4))));
			CPU_wr_ack_o <= i_CPU_wr_ack(to_integer(unsigned(CPU_A_i(C_A_SIZE-1 downto 4))));
			CPU_rd_ack_o <= i_CPU_rd_ack(to_integer(unsigned(CPU_A_i(C_A_SIZE-1 downto 4))));
		end if;
	end process;

G_SPR:FOR I IN 0 TO G_N_SPRITES-1 GENERATE
	i_SEQ_wren_oh(I) <= '1' when SEQ_wren_i = '1' and SEQ_A_i(C_A_SIZE-1 downto 4) = I else '0';
	i_CPU_wren_oh(I) <= '1' when CPU_wren_i = '1' and CPU_A_i(C_A_SIZE-1 downto 4) = I else '0';
	
	horz_ctr_o <= r_horz_ctr;
	vert_ctr_o <= r_vert_ctr;


	e_spr:entity work.sprite_int
	generic map (
		SIM									=> SIM
	)
	port map(

		rst_i									=> rst_i,

		clk_48M_i							=> clk_48M_i,

		-- data interface, from sequencer
		SEQ_D_i								=> SEQ_D_i,
		SEQ_wren_i							=> i_SEQ_wren_oh(I),
		SEQ_A_i								=> SEQ_A_i(3 downto 0),

		-- sequencer interface out
		SEQ_DATAPTR_A_o					=> SEQ_DATAPTR_A_o(I),
		SEQ_DATAPTR_act_o					=> SEQ_DATAPTR_act_o(I),
		SEQ_A_pre_o							=> SEQ_A_pre_o(I),

		-- data interface, from CPU
		CPU_D_i								=> CPU_D_i,
		CPU_A_i								=> CPU_A_i(3 downto 0),
		CPU_rden_i							=> CPU_rden_i,
		CPU_wren_i							=> i_CPU_wren_oh(I),
		CPU_D_o								=> i_CPU_D_o(I),
		CPU_wr_ack_o						=> i_CPU_wr_ack(I),
		CPU_rd_ack_o						=> i_CPU_rd_ack(I),

		pixel_clken_i						=> pixel_clken_i,

		-- locally generated pixel/line counters
		horz_ctr_i							=> r_horz_ctr,
		vert_ctr_i							=> r_vert_ctr,

		-- pixel data out
		px_D_o								=> i_px_D(I),

		-- registers out

		horz_start_o						=> i_horz_start(I),
		vert_start_o						=> i_vert_start(I),
		vert_stop_o							=> i_vert_stop(I),
		attach_o								=> i_attach(I),

		-- arm/disarm in 
		horz_disarm_clken_i				=> r_horz_disarm_clken,
		vert_reload_clken_i				=> r_vert_reload_clken


	);
END GENERATE;

	p_pix_sel_tmp:process(clk_48M_i, rst_i)
	begin
		if rst_i = '1' then
			pixel_o <= (others => '0');
			pixel_act_o <= '0';
		elsif rising_edge(clk_48M_i) then
			if pixel_clken_i = '1' then
				pixel_act_o <= '0';
				pixel_o <= (others => '0');
				for I in 0 to G_N_SPRITES-1 loop
					if I mod 2 = 0 and i_attach(I) = '1' 
							and (i_px_D(I+1) /= "00" or i_px_D(I) /= "00") then
						pixel_o(3 downto 2) <= i_px_D(I+1);
						pixel_o(1 downto 0) <= i_px_D(I);
						pixel_act_o <= '1';
						exit;
					elsif i_px_D(I) /= "00" then
						pixel_o(1 downto 0) <= i_px_D(I);
						pixel_act_o <= '1';
						exit;
					end if;
				end loop;
			end if;
		end if;
	end process;

	SEQ_DATA_REQ_o <= r_data_req;

	process(rst_i, clk_48M_i, pixel_clken_i)
	begin

		if rst_i = '1' then
			r_horz_ctr <= (others => '0');
			r_vert_ctr <= (others => '0');
			r_prev_hsync <= '0';
			r_prev_vsync <= '0';
			r_horz_disarm_clken <= '0';
			r_vert_reload_clken <= '0';
			r_data_req <= '0';
		elsif rising_edge(clk_48M_i) and pixel_clken_i = '1' then			
			r_horz_disarm_clken <= '0';
			r_vert_reload_clken <= '0';
			if (hsync_i = '1' and r_prev_hsync = '0') then
				r_horz_disarm_clken <= '1';
				r_data_req <= not r_data_req;
				if vsync_i = '1' and r_prev_vsync = '0' then
					r_vert_ctr <= (others => '0');
					r_vert_reload_clken <= '1';
				else
					r_vert_ctr <= r_vert_ctr + 1;
				end if;
				r_prev_vsync <= vsync_i;
				r_horz_ctr <= (others => '0');
			else
				r_horz_ctr <= r_horz_ctr + 1;
			end if;

			r_prev_hsync <= hsync_i;
		end if;

	end process;



end rtl;
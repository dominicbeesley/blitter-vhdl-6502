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
		G_N_SPRITES							: natural := 8									-- maximum number of sprites
	);
	port(

		rst_i									: in	std_logic;							

		clk_i									: in	std_logic;
		clken_i								: in	std_logic;							-- this qualifies all clocks

		-- data interface, from sequencer
		SEQ_D_i								: in	std_logic_vector(7 downto 0);
		SEQ_wren_i							: in	std_logic;
		SEQ_A_i								: in	unsigned(numbits(G_N_SPRITES) + 3 downto 0);			
																								-- sprite data A..D, pos/ctl, ptr, lst (see below in p_regs)
		-- addresses out to sequencer
		SEQ_DATAPTR_A_o					: out t_spr_addr_array(G_N_SPRITES-1 downto 0);
		SEQ_DATAPTR_act_o					: out std_logic_vector(G_N_SPRITES-1 downto 0);		-- indicates a request for this address
		SEQ_DATA_REQ_o						: out std_logic;							-- toggles once per line to inform sequencer to redo data

		-- data interface, from CPU
		CPU_D_i								: in	std_logic_vector(7 downto 0);
		CPU_wren_i							: in	std_logic;
		CPU_A_i								: in	unsigned(numbits(G_N_SPRITES) + 3 downto 0);			-- sprite data A..D, pos/ctl, ptr, lst (see below in p_regs)

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
	signal r_horz_ctr					: unsigned(8 downto 0);
	signal r_vert_ctr					: unsigned(8 downto 0);
	signal r_horz_disarm_clken		: std_logic;				-- disarm all sprites at "end" of line, needs to be before sequencer loads, think about moving elsewhere (sequencer?)
	signal r_vert_reload_clken		: std_logic;				-- pixel at which we reload sprite data pointers
	-- sequencer 
	signal r_data_req					: std_logic;

begin

G_SPR:FOR I IN 0 TO G_N_SPRITES-1 GENERATE
	i_SEQ_wren_oh(I) <= '1' when SEQ_wren_i = '1' and SEQ_A_i(C_A_SIZE-1 downto 4) = I else '0';
	i_CPU_wren_oh(I) <= '1' when CPU_wren_i = '1' and CPU_A_i(C_A_SIZE-1 downto 4) = I else '0';

	e_spr:entity work.sprite_int
	generic map (
		SIM									=> SIM
	)
	port map(

		rst_i									=> rst_i,

		clk_i									=> clk_i,
		clken_i								=> clken_i,

		-- data interface, from sequencer
		SEQ_D_i								=> SEQ_D_i,
		SEQ_wren_i							=> i_SEQ_wren_oh(I),
		SEQ_A_i								=> SEQ_A_i(3 downto 0),

		-- sequencer interface out
		SEQ_DATAPTR_A_o					=> SEQ_DATAPTR_A_o(I),
		SEQ_DATAPTR_act_o					=> SEQ_DATAPTR_act_o(I),

		-- data interface, from CPU
		CPU_D_i								=> CPU_D_i,
		CPU_wren_i							=> i_CPU_wren_oh(I),
		CPU_A_i								=> CPU_A_i(3 downto 0),

		pixel_clk_i							=> pixel_clk_i,
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

--priority encoder and "attacher" for pixels
p_pix_sel:process(pixel_clk_i, rst_i)
variable I:natural;
variable v_act:boolean;
begin
	if rst_i = '1' then
		pixel_o <= (others => '0');
		pixel_act_o <= '0';
	elsif rising_edge(pixel_clk_i) then
		if pixel_clken_i = '1' then
			pixel_o <= (others => '0');
			pixel_act_o <= '0';
			I := 0;
			v_act := false;
			FOR I in 0 TO G_N_SPRITES-1 loop
				if not v_act then
					if i_px_D(I) /= "00" and (I mod 2 = 0 or i_attach(I-1) = '0') then
						pixel_o(1 downto 0) <= i_px_D(I);
						v_act := true;
					end if;
					if I mod 2 = 0 and i_attach(I) = '1' and I < G_N_SPRITES - 1 then
						if i_px_D(I+1) /= "00" then
							pixel_o(3 downto 2) <= i_px_D(I);
							v_act := true;
						end if;
					end if;
				end if;
			end loop;

			if v_act then
				pixel_act_o <= '1';
			end if;
		end if;
	end if;
end process;

	SEQ_DATA_REQ_o <= r_data_req;

	process(rst_i, pixel_clk_i, pixel_clken_i)
	begin

		if rst_i = '1' then
			r_horz_ctr <= (others => '0');
			r_vert_ctr <= (others => '0');
			r_prev_hsync <= '0';
			r_horz_disarm_clken <= '0';
			r_vert_reload_clken <= '0';
			r_data_req <= '0';
		elsif rising_edge(pixel_clk_i) and pixel_clken_i = '1' then			
			r_horz_disarm_clken <= '0';
			r_vert_reload_clken <= '0';
			if (hsync_i = '1' and r_prev_hsync = '0') then
				r_horz_disarm_clken <= '1';
				r_data_req <= not r_data_req;
				if vsync_i = '1' then
					r_vert_ctr <= (others => '0');
					r_vert_reload_clken <= '1';
				else
					r_vert_ctr <= r_vert_ctr + 1;
				end if;
				r_horz_ctr <= (others => '0');
			else
				r_horz_ctr <= r_horz_ctr + 1;
			end if;

			r_prev_hsync <= hsync_i;
		end if;

	end process;



end rtl;
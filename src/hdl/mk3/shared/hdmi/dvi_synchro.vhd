-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	26/10/2021
-- Design Name: 
-- Module Name:    	DVI_SYNCHRO
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Synchronise pixels to DVI clock domain and generate a blanking signal
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.fishbone.all;



entity dvi_synchro is
	port (
		clk_pixel_dvi 				: in	std_logic;


		-- input signals in the local clock domain
		VSYNC_CRTC_i				: in	std_logic;
		HSYNC_CRTC_i				: in	std_logic;
		DISEN_CRTC_i				: in	std_logic;

		R_ULA_i						: in	std_logic_vector(7 downto 0);
		G_ULA_i						: in	std_logic_vector(7 downto 0);
		B_ULA_i						: in	std_logic_vector(7 downto 0);

		-- synchronised / generated / conditioned signals in DVI pixel clock domain

		VSYNC_DVI_o					: out	std_logic;
		HSYNC_DVI_o					: out	std_logic;
		BLANK_DVI_o					: out	std_logic;

		R_DVI_o						: out std_logic_vector(7 downto 0);
		G_DVI_o						: out std_logic_vector(7 downto 0);
		B_DVI_o						: out std_logic_vector(7 downto 0)

	);
end dvi_synchro;


architecture rtl of dvi_synchro is
	

	constant C_LINES_PER_FIELD  	: natural := 312;		-- +1 for odd frames
	constant C_FIELD_BLANK_FRONT	: natural := 2; 		-- +0.5 for "even" frames i.e. before odd!
	constant C_FIELD_BLANK_BACK 	: natural := 22;		-- +0.5 for "odd" frames, include hsync!
	constant	C_VSYNC_LINES		 	: natural := 3;

	constant C_PIXELS_PER_LINE  	: natural := 1728; -- 64us * 27
	constant C_LINE_BLANK_FRONT 	: natural := 24;	
	constant C_LINE_BLANK_BACK  	: natural := 264; 	-- +1 for "odd" frames, includes hsync
	constant C_HSYNC_PIXELS			: natural := 126;

	signal 	r_field_counter		: unsigned(9 downto 0);	
	signal   r_line_counter			: unsigned(11 downto 0);

	signal 	r_vsync_meta			: std_logic_vector(3 downto 0);	-- in from 6845
	signal 	r_hsync_meta			: std_logic_vector(3 downto 0);	-- in from 6845

	signal	r_blank_line			: std_logic;
	signal	r_blank_field			: std_logic;
	signal	r_vsync					: std_logic;
	signal	r_hsync					: std_logic;

	signal	r_odd						: std_logic;
	signal	r_odd_next				: std_logic;
	signal	r_field_next			: std_logic;

begin


	BLANK_DVI_o <= r_blank_field or r_blank_line;
	--BLANK_DVI_o <= not DISEN_CRTC_i;

	VSYNC_DVI_o <= r_vsync;
	HSYNC_DVI_o <= r_hsync;

	p_synchro:process(clk_pixel_dvi)
	begin

		if rising_edge(clk_pixel_dvi) then

			r_vsync_meta <= r_vsync_meta(r_vsync_meta'high-1 downto 0) & VSYNC_CRTC_i;
			r_hsync_meta <= r_hsync_meta(r_hsync_meta'high-1 downto 0) & HSYNC_CRTC_i;

			R_DVI_o <= R_ULA_i;
			G_DVI_o <= G_ULA_i;
			B_DVI_o <= B_ULA_i;

		end if;

	end process;


	p_genblank:process(clk_pixel_dvi)
	begin
		if rising_edge(clk_pixel_dvi) then


			if r_vsync_meta(r_vsync_meta'high) = '0' and r_vsync_meta(r_vsync_meta'high-1) = '1' then
				if r_line_counter >= C_PIXELS_PER_LINE / 4 and r_line_counter < C_PIXELS_PER_LINE * 3 / 4 then
					r_odd_next <= '1';
					r_field_next <= '1';
				else
					r_odd_next <= '0';
					r_field_next <= '1';
				end if;
			end if;




			if r_hsync_meta(r_hsync_meta'high) = '0' and r_hsync_meta(r_hsync_meta'high-1) = '1' then
				-- leading edge of sync, reset counter
				r_line_counter <= (others => '0');
				if r_field_next = '1' then
					r_odd <= r_odd_next;
					r_field_counter <= to_unsigned(0, r_field_counter'length);
				else
					r_field_counter <= r_field_counter + 1;
				end if;
			else

				r_line_counter <= r_line_counter + 1;
			end if;

			if r_field_counter < C_FIELD_BLANK_BACK 
				or (r_odd = '1' and r_field_counter = C_FIELD_BLANK_BACK)
				or r_field_counter >= C_LINES_PER_FIELD - C_FIELD_BLANK_FRONT then
				r_blank_field <= '1';
			else
				r_blank_field <= '0';
			end if;

			if r_line_counter < C_LINE_BLANK_BACK
				or (r_odd = '1' and r_line_counter = C_LINE_BLANK_BACK)
				or r_line_counter >= C_PIXELS_PER_LINE - C_LINE_BLANK_FRONT then
				r_blank_line <= '1';
			else
				r_blank_line <= '0';
			end if;

			if r_line_counter < C_HSYNC_PIXELS then
				r_hsync <= '0';
			else
				r_hsync <= '1';
			end if;

			r_vsync <= '1';
			if r_field_counter = 0 then
				if r_odd = '1' then
					if r_line_counter >= C_PIXELS_PER_LINE / 2 then
						r_vsync <= '0';						
					end if;
				else
					r_vsync <= '0';
				end if;
			elsif r_field_counter < C_VSYNC_LINES then
				r_vsync <= '0';
			elsif r_field_counter = C_VSYNC_LINES then
				if r_odd = '1' and r_line_counter < C_HSYNC_PIXELS / 2 then
					r_vsync <= '0';
				end if;
			end if;



		end if;

	end process;

end rtl;

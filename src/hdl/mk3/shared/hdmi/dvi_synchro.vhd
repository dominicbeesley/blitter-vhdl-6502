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

		fb_syscon_i					: in		fb_syscon_t;

		-- input signals in the local clock domain
		clken_crtc_i				: in  std_logic;
		VSYNC_CRTC_i				: in	std_logic;
		HSYNC_CRTC_i				: in	std_logic;
		DISEN_CRTC_i				: in	std_logic;

		R_ULA_i						: in	std_logic_vector(7 downto 0);
		G_ULA_i						: in	std_logic_vector(7 downto 0);
		B_ULA_i						: in	std_logic_vector(7 downto 0);

		-- synchronised / generated / conditioned signals in DVI pixel clock domain

		clk_pixel_dvi 				: in	std_logic;
		VSYNC_DVI_o					: out	std_logic;
		HSYNC_DVI_o					: out	std_logic;
		BLANK_DVI_o					: out	std_logic;

		R_DVI_o						: out std_logic_vector(7 downto 0);
		G_DVI_o						: out std_logic_vector(7 downto 0);
		B_DVI_o						: out std_logic_vector(7 downto 0);


		debug_vsync_det_o			: out std_logic;
		debug_hsync_det_o			: out std_logic

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
	constant C_SYNC_LINE_LIMIT		: natural := 10;

	signal 	r_field_counter		: unsigned(9 downto 0) := (others => '0');	
	signal   r_line_counter			: unsigned(11 downto 0) := (others => '0');

	signal   r_hsync_prev_crtc		: std_logic;
	signal	r_hsync_lead_crtc		: std_logic;			-- flips on leading edge of hs from crtc
	signal	r_hsync_lead_ack		: std_logic;			-- acknowledge of crt hs edge in dvi pixel clock domain
	signal	r_hsync_lead_pulse	: std_logic;			-- single pixel clock pulse of hs leading edge in dvi clock domain

	signal	r_vsync_prev_crtc		: std_logic;
	signal	r_vsync_lead_crtc		: std_logic;			-- flips on leading edge of hs from crtc
	signal	r_vsync_lead_ack		: std_logic;			-- acknowledge of crt hs edge in dvi pixel clock domain
	signal	r_vsync_lead_pulse	: std_logic;			-- single pixel clock pulse of hs leading edge in dvi clock domain

	signal	r_blank_line			: std_logic := '0';
	signal	r_blank_field			: std_logic := '0';
	signal	r_vsync					: std_logic := '0';
	signal	r_hsync					: std_logic := '0';

	signal	r_odd						: std_logic := '0';
	signal	r_odd_next				: std_logic := '0';
	signal	r_field_next			: std_logic := '0';

begin

	debug_vsync_det_o <= r_vsync_lead_ack;
	debug_hsync_det_o <= r_hsync_lead_ack;


	BLANK_DVI_o <= r_blank_field or r_blank_line;
	--BLANK_DVI_o <= not DISEN_CRTC_i;

	VSYNC_DVI_o <= r_vsync;
	HSYNC_DVI_o <= r_hsync;


	p_reg_syncs_crtc:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_hsync_prev_crtc <= '0';
			r_hsync_lead_crtc <= '0';
			r_vsync_prev_crtc <= '0';
			r_vsync_lead_crtc <= '0';
		elsif rising_edge(fb_syscon_i.clk) and clken_crtc_i = '1' then

			if HSYNC_CRTC_i = '1' and r_hsync_prev_crtc = '0' then
				r_hsync_lead_crtc <= not r_hsync_lead_crtc;
			end if;

			if VSYNC_CRTC_i = '1' and r_vsync_prev_crtc = '0' then
				r_vsync_lead_crtc <= not r_vsync_lead_crtc;
			end if;

			r_hsync_prev_crtc <= HSYNC_CRTC_i;
			r_vsync_prev_crtc <= VSYNC_CRTC_i;

		end if;

	end process;


	p_reg_syncs_dvi:process(clk_pixel_dvi)
	begin

		if fb_syscon_i.rst = '1' then
			r_hsync_lead_ack <= '0';
			r_hsync_lead_pulse <= '0';
			r_vsync_lead_ack <= '0';
			r_vsync_lead_pulse <= '0';
		elsif rising_edge(clk_pixel_dvi) then

			r_hsync_lead_pulse <= '0';
			if r_hsync_lead_crtc /= r_hsync_lead_ack then
				r_hsync_lead_ack <= r_hsync_lead_crtc;
				r_hsync_lead_pulse <= '1';
			end if;

			r_vsync_lead_pulse <= '0';
			if r_vsync_lead_crtc /= r_vsync_lead_ack then
				r_vsync_lead_ack <= r_vsync_lead_crtc;
				r_vsync_lead_pulse <= '1';
			end if;

			if r_line_counter(0) = '1' then
				R_DVI_o <= R_ULA_i;
				G_DVI_o <= G_ULA_i;
				B_DVI_o <= B_ULA_i;
			end if;

		end if;

	end process;


	p_genblank:process(clk_pixel_dvi)
	begin
		if rising_edge(clk_pixel_dvi) then

			if r_vsync_lead_pulse = '1' then
				r_field_next <= '1';
				if r_line_counter >= C_PIXELS_PER_LINE / 4 and r_line_counter < C_PIXELS_PER_LINE * 3 / 4 then
					r_odd_next <= '1';
				else
					r_odd_next <= '0';
				end if;
			end if;

			if r_hsync_lead_pulse = '1' then

				-- leading edge of sync, reset counter
				r_line_counter <= (others => '0');
				if r_field_next = '1' then
					r_odd <= r_odd_next;
					r_field_counter <= to_unsigned(0, r_field_counter'length);
					r_field_next <= '0';
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
				if r_odd = '1' and r_line_counter < C_PIXELS_PER_LINE / 2 then
					r_vsync <= '0';
				end if;
			end if;



		end if;

	end process;

end rtl;

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

library work;
use work.fishbone.all;
use work.common.all;



entity dvi_synchro is
	generic (
		G_SHOWMARGIN : boolean := false
		);
	port (


		pixel_double_i				: in 	std_logic;

		-- input signals in the local clock domain
		CLK_48M_i					: in 	std_logic;
		RESET_48M_i					: in  std_logic;
		VSYNC_CRTC_i				: in	std_logic;
		HSYNC_CRTC_i				: in	std_logic;
		DISEN_CRTC_i				: in	std_logic;

		R_ULA_i						: in	std_logic_vector(3 downto 0);
		G_ULA_i						: in	std_logic_vector(3 downto 0);
		B_ULA_i						: in	std_logic_vector(3 downto 0);

		TTX_i							: in  std_logic;
		TTX80_i						: in  std_logic;

		-- synchronised / generated / conditioned signals in DVI pixel clock domain

		clk_pixel_dvi 				: in	std_logic;
		VSYNC_DVI_o					: out	std_logic;
		HSYNC_DVI_o					: out	std_logic;
		BLANK_DVI_o					: out	std_logic;

		R_DVI_o						: out std_logic_vector(7 downto 0);
		G_DVI_o						: out std_logic_vector(7 downto 0);
		B_DVI_o						: out std_logic_vector(7 downto 0);


		debug_vsync_det_o			: out std_logic;
		debug_hsync_det_o			: out std_logic;
		debug_hsync_crtc_o			: out std_logic;

		debug_odd_o					: out std_logic

	);
end dvi_synchro;


architecture rtl of dvi_synchro is

	function RGBNULA_TO_DVI(i:natural) return natural is
	begin
		if i = 0 then
			return 16;
		elsif i = 1 then
			return 30;
		elsif i = 2 then
			return 43;
		elsif i = 3 then
			return 57;
		elsif i = 4 then
			return 70;
		elsif i = 5 then
			return 84;
		elsif i = 6 then
			return 98;
		elsif i = 7 then
			return 111;
		elsif i = 8 then
			return 125;
		elsif i = 9 then
			return 138;
		elsif i = 10 then
			return 152;
		elsif i = 11 then
			return 166;
		elsif i = 12 then
			return 180;
		elsif i = 13 then
			return 193;
		elsif i = 14 then
			return 206;
		else 
			return 219;
		end if;
	end;

	

	constant C_LINES_PER_FIELD  	: natural := 312;		-- +1 for odd frames
	constant C_FIELD_BLANK_FRONT	: natural := 2; 		-- +0.5 for "even" frames i.e. before odd!
	constant C_FIELD_BLANK_BACK 	: natural := 22;		-- +0.5 for "odd" frames, include hsync!
	constant	C_VSYNC_LINES		 	: natural := 3;

-- 27MHz 1440x576 values
	constant C_PIXELS_PER_LINE  	: natural := 1728; -- 64us * 27
		-- numbers in () are fiddle factors to make correct relationships when monitoring on TVP401
	constant C_LINE_BLANK_FRONT 	: natural := 24;		
	constant C_HSYNC_PIXELS			: natural := 126 - (4);
	constant C_LINE_BLANK_BACK  	: natural := 138 + C_HSYNC_PIXELS + (4); 	

-- 54MHz 2880x576 values
--	constant C_PIXELS_PER_LINE  	: natural := 3456; -- 64us * 54
--		-- numbers in () are fiddle factors to make correct relationships when monitoring on TVP401
--	constant C_LINE_BLANK_FRONT 	: natural := 48;	
--	constant C_HSYNC_PIXELS			: natural := 252;
--	constant C_LINE_BLANK_BACK  	: natural := 276 + C_HSYNC_PIXELS; 	
	constant C_SYNC_LINE_LIMIT		: natural := 10;
	constant C_LINE_MARGIN			: natural := C_LINE_BLANK_BACK + 0;		-- margin from start of line to start ouputting pixels

	-- PIXELS in the 48MHz domain, where to start saving pixels
	constant C_PXSTART48				: natural := 11 * 48;
	constant C_PXLINE48				: natural := 64 * 48;

	constant C_META					: natural := 3;		-- meta stability between 48 and 27 MHz clock domains

	signal   r_hsync_prev_crtc		: std_logic;
	signal	r_hsync_lead_crtc		: std_logic;			-- flips on leading edge of hs from crtc
	signal	i_hsync_lead_dvi		: std_logic;			-- flips on leading edge of hs from crtc
	signal	r_hsync_lead_ack_dvi	: std_logic;			-- acknowledge of crt hs edge in dvi pixel clock domain
	signal	r_hsync_lead_cken_dvi: std_logic;			-- single pixel clock pulse of hs leading edge in dvi clock domain

	signal	r_vsync_prev_crtc		: std_logic;
	signal	r_vsync_lead_crtc		: std_logic;			-- flips on leading edge of hs from crtc
	signal	i_vsync_lead_dvi		: std_logic;			-- flips on leading edge of hs from crtc
	signal	r_vsync_lead_ack_dvi	: std_logic;			-- acknowledge of crt hs edge in dvi pixel clock domain
	signal	r_vsync_lead_cken_dvi: std_logic;			-- single pixel clock pulse of hs leading edge in dvi clock domain

	constant C_BUFMAX : natural := 720;

	signal 	r_field_counter		: unsigned(9 downto 0) := (others => '0');	
	signal   r_line_counter			: unsigned(NUMBITS((C_PIXELS_PER_LINE)-1)-1 downto 0) := (others => '0');

	signal	r_blank_line			: std_logic := '0';
	signal	r_blank_field			: std_logic := '0';
	signal	r_vsync					: std_logic := '0';
	signal	r_hsync					: std_logic := '0';

	signal	r_odd						: std_logic := '0';
	signal	r_odd_next				: std_logic := '0';
	signal	r_field_next			: std_logic := '0';
	signal	r_field_next_but_one	: std_logic := '0';

	signal	r_ula_read_wait					: std_logic;
	signal	r_ula_pixel_ring					: std_logic_vector(3 downto 0);
	signal	r_linebuf_ctr_ula					:unsigned(NUMBITS((2*C_BUFMAX)-1)-1 downto 0);
	signal	r_linebuf_ctr_dvi					:unsigned(NUMBITS((2*C_BUFMAX)-1)-1 downto 0);
	signal	r_linebuf_ctr_ula_max			:unsigned(NUMBITS((2*C_BUFMAX)-1)-1 downto 0);
	signal	r_linebuf_ctr_ula_prev_max		:unsigned(NUMBITS((2*C_BUFMAX)-1)-1 downto 0); -- last pixel captured on previous line
	signal	r_linebuf_ctr_dvi_max			:unsigned(NUMBITS((2*C_BUFMAX)-1)-1 downto 0);
	signal	i_line_buffer_wren				: std_logic;
	signal	i_line_buffer_Q					: std_logic_vector(11 downto 0);
	signal   r_line_px_in_ctr48				:unsigned(NUMBITS(2*C_PXLINE48)-1 downto 0);

begin

	debug_vsync_det_o <= r_vsync_lead_ack_dvi;
	debug_hsync_det_o <= r_hsync_lead_ack_dvi;
	debug_hsync_crtc_o <= HSYNC_CRTC_i;
	debug_odd_o <= r_odd;


	BLANK_DVI_o <= r_blank_field or r_blank_line;
	--BLANK_DVI_o <= not DISEN_CRTC_i;

	VSYNC_DVI_o <= r_vsync;
	HSYNC_DVI_o <= r_hsync;

	e_line_buff:entity work.linebuffer
	port map (
		reseta => '0',
		resetb => '0',

		clkb	=> clk_pixel_dvi, 
		adb   => std_logic_vector(r_linebuf_ctr_dvi),
		dout	=> i_line_buffer_Q,
		ceb   => '1',
		oce   => '1',

		clka	=> CLK_48M_i,
		ada   => std_logic_vector(r_linebuf_ctr_ula),
		din	=> R_ULA_i & G_ULA_i & B_ULA_i,
		cea	=> i_line_buffer_wren
	);


	i_line_buffer_wren <= '1' when r_linebuf_ctr_ula < r_linebuf_ctr_ula_max 
												and r_ula_pixel_ring(0) = '1' 
												and r_ula_read_wait = '0'
												else

								 '0';
			

	p_reg_pix_ula:process(CLK_48M_i, RESET_48M_i)
	begin
		if RESET_48M_i = '1' then
			r_line_px_in_ctr48 <= (others => '0');
			r_linebuf_ctr_ula <= (others => '0');
			r_linebuf_ctr_ula_max <= (others => '0');
		elsif rising_edge(CLK_48M_i) then

			if HSYNC_CRTC_i = '1' and r_hsync_prev_crtc = '0' then
				r_ula_read_wait <= '1';
				if r_hsync_lead_crtc = '0' then
					r_linebuf_ctr_ula <= to_unsigned(0, r_linebuf_ctr_ula'LENGTH);
					r_linebuf_ctr_ula_max <= to_unsigned(C_BUFMAX, r_linebuf_ctr_ula'LENGTH);
				else					
					r_linebuf_ctr_ula <= to_unsigned(C_BUFMAX, r_linebuf_ctr_ula'LENGTH);
					r_linebuf_ctr_ula_max <= to_unsigned(2*C_BUFMAX, r_linebuf_ctr_ula'LENGTH);
				end if;
				r_linebuf_ctr_ula_prev_max	<= r_linebuf_ctr_ula;
				r_line_px_in_ctr48 <= (others => '0');

			else 
				if r_line_px_in_ctr48 = C_PXSTART48 and r_ula_read_wait = '1' then
					r_ula_read_wait <= '0';
					r_ula_pixel_ring <= (others => '1');
				elsif i_line_buffer_wren = '1' then
					--if TTX_i = '1' and TTX80_i = '1' then
					--	r_ula_pixel_ring <= "0010";
					--els
					if TTX_i = '1' then
						r_ula_pixel_ring <= "1000";
					else
						r_ula_pixel_ring <= "0100";
					end if;

					r_linebuf_ctr_ula <= r_linebuf_ctr_ula + 1;
				else
					r_ula_pixel_ring <= "0" & r_ula_pixel_ring(3 downto 1);
				end if;
				r_line_px_in_ctr48 <= r_line_px_in_ctr48 + 1;
			end if;
		end if;

	end process;

	p_reg_syncs_crtc:process(RESET_48M_i, CLK_48M_i)
	begin
		if RESET_48M_i = '1' then
			r_hsync_prev_crtc <= '0';
			r_hsync_lead_crtc <= '0';
			r_vsync_prev_crtc <= '0';
			r_vsync_lead_crtc <= '0';
		elsif rising_edge(CLK_48M_i) then

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


	--================================= CRTC clock domain to DVI clock domain ========

	e_rm_hs:entity work.metadelay
	generic map (
		N		=> C_META
	)
	port map(
		clk	=> clk_pixel_dvi,
		i		=> r_hsync_lead_crtc,
		o  	=> i_hsync_lead_dvi
	);

	e_rm_vs:entity work.metadelay
	generic map (
		N		=> C_META
	)
	port map(
		clk	=> clk_pixel_dvi,
		i		=> r_vsync_lead_crtc,
		o  	=> i_vsync_lead_dvi
	);

	p_reg_syncs_dvi:process(RESET_48M_i, clk_pixel_dvi)
	begin

		if RESET_48M_i = '1' then
			r_hsync_lead_ack_dvi <= '0';
			r_hsync_lead_cken_dvi <= '0';
			r_vsync_lead_ack_dvi <= '0';
			r_vsync_lead_cken_dvi <= '0';
			r_linebuf_ctr_dvi <= (others => '0');
		elsif rising_edge(clk_pixel_dvi) then

			r_hsync_lead_cken_dvi <= '0';
			if i_hsync_lead_dvi /= r_hsync_lead_ack_dvi then
				r_hsync_lead_ack_dvi <= i_hsync_lead_dvi;
				r_hsync_lead_cken_dvi <= '1';
			end if;

			r_vsync_lead_cken_dvi <= '0';
			if i_vsync_lead_dvi /= r_vsync_lead_ack_dvi then
				r_vsync_lead_ack_dvi <= i_vsync_lead_dvi;
				r_vsync_lead_cken_dvi <= '1';
			end if;

			if r_line_counter(0 downto 0) = "0" or pixel_double_i = '0' then
				if r_line_counter < C_LINE_MARGIN then
					r_linebuf_ctr_dvi_max <= r_linebuf_ctr_ula_prev_max;
					if r_hsync_lead_ack_dvi = '0' then
						r_linebuf_ctr_dvi <= to_unsigned(0, r_linebuf_ctr_dvi'LENGTH);
					else					
						r_linebuf_ctr_dvi <= to_unsigned(C_BUFMAX, r_linebuf_ctr_dvi'LENGTH);
					end if;
					
					if G_SHOWMARGIN then
						R_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(5),8));
						G_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(5),8));
						B_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(5),8));
					else
						R_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(0),8));
						G_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(0),8));
						B_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(0),8));
					end if;
				else
					if r_linebuf_ctr_dvi < r_linebuf_ctr_dvi_max then
						R_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(TO_INTEGER(UNSIGNED(i_line_buffer_Q(11 downto 8)))),8));						
						G_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(TO_INTEGER(UNSIGNED(i_line_buffer_Q(7 downto 4)))),8));
						B_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(TO_INTEGER(UNSIGNED(i_line_buffer_Q(3 downto 0)))),8));

						r_linebuf_ctr_dvi <= r_linebuf_ctr_dvi + 1;
					else
						if G_SHOWMARGIN then
							R_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(10),8));
							G_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(5),8));
							B_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(7),8));				
						else
							R_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(0),8));
							G_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(0),8));
							B_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(0),8));
						end if;
					end if;
				end if;
			end if;

		end if;

	end process;


	p_genblank:process(clk_pixel_dvi)
	begin
		if rising_edge(clk_pixel_dvi) then

			if r_vsync_lead_cken_dvi = '1' then
				r_field_next_but_one <= '1';
				if r_line_counter >= C_PIXELS_PER_LINE / 4 and r_line_counter < C_PIXELS_PER_LINE * 3 / 4 then
					r_odd_next <= '1';
				else
					r_odd_next <= '0';
				end if;
			end if;

			if r_hsync_lead_cken_dvi = '1' then

				-- delay vsync detect by another line
				if r_field_next_but_one = '1' then
					r_field_next <= '1';
					r_field_next_but_one <= '0';
				else
					r_field_next <= '0';
				end if;

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

			if 	(r_field_counter < C_FIELD_BLANK_BACK)
				or (r_odd = '1' and r_field_counter = C_FIELD_BLANK_BACK)
				or (r_odd = '0' and r_field_counter >= C_LINES_PER_FIELD - C_FIELD_BLANK_FRONT)
				or (r_odd = '1' and r_field_counter > C_LINES_PER_FIELD - C_FIELD_BLANK_FRONT)
				then
				r_blank_field <= '1';
			else
				r_blank_field <= '0';
			end if;

			if r_line_counter < C_LINE_BLANK_BACK
				--or (r_odd = '1' and r_line_counter = C_LINE_BLANK_BACK)
				or r_line_counter >= C_PIXELS_PER_LINE - C_LINE_BLANK_FRONT
				then
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

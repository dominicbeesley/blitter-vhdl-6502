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
use work.common.all;



entity dvi_synchro is
	port (

		fb_syscon_i					: in	fb_syscon_t;

		pixel_double_i				: in 	std_logic;

		-- input signals in the local clock domain
		CLK_48M_i					: in 	std_logic;
		VSYNC_CRTC_i				: in	std_logic;
		HSYNC_CRTC_i				: in	std_logic;
		DISEN_CRTC_i				: in	std_logic;

		R_ULA_i						: in	std_logic_vector(3 downto 0);
		G_ULA_i						: in	std_logic_vector(3 downto 0);
		B_ULA_i						: in	std_logic_vector(3 downto 0);

		TTX_i							: in  std_logic;

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


	constant C_PIXELS_PER_LINE  	: natural := 1728; -- 64us * 27
	constant C_LINE_BLANK_FRONT 	: natural := 24;	
	constant C_LINE_BLANK_BACK  	: natural := 264; 	-- +1 for "odd" frames, includes hsync
	constant C_HSYNC_PIXELS			: natural := 126;
	constant C_SYNC_LINE_LIMIT		: natural := 10;
	constant C_LINE_MARGIN			: natural := 300;		-- margin from start of line to start ouputting pixels

	constant C_META					: natural := 3;		-- meta stability between 48 and 27 MHz clock domains

	signal   r_hsync_prev_crtc		: std_logic;
	signal	r_hsync_lead_crtc		: std_logic_vector(C_META-1 downto 0);			-- flips on leading edge of hs from crtc
	signal	r_hsync_lead_ack		: std_logic;			-- acknowledge of crt hs edge in dvi pixel clock domain
	signal	r_hsync_lead_pulse	: std_logic;			-- single pixel clock pulse of hs leading edge in dvi clock domain

	signal	r_vsync_prev_crtc		: std_logic;
	signal	r_vsync_lead_crtc		: std_logic_vector(C_META-1 downto 0);			-- flips on leading edge of hs from crtc
	signal	r_vsync_lead_ack		: std_logic;			-- acknowledge of crt hs edge in dvi pixel clock domain
	signal	r_vsync_lead_pulse	: std_logic;			-- single pixel clock pulse of hs leading edge in dvi clock domain

	constant C_BUFMAX : natural := 720;

	type		linebuffer_t is array (0 to C_BUFMAX*2) of std_logic_vector(11 downto 0);

	signal	linebuffer: linebuffer_t;

	signal 	r_field_counter		: unsigned(9 downto 0) := (others => '0');	
	signal   r_line_counter			: unsigned(11 downto 0) := (others => '0');

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

begin

	debug_vsync_det_o <= r_vsync_lead_ack;
	debug_hsync_det_o <= r_hsync_lead_ack;
	debug_hsync_crtc_o <= HSYNC_CRTC_i;
	debug_odd_o <= r_odd;


	BLANK_DVI_o <= r_blank_field or r_blank_line;
	--BLANK_DVI_o <= not DISEN_CRTC_i;

	VSYNC_DVI_o <= r_vsync;
	HSYNC_DVI_o <= r_hsync;

	e_line_buff:entity work.linebuffer
	port map (
		rdclock	=> clk_pixel_dvi, 
		rdaddress=> std_logic_vector(r_linebuf_ctr_dvi),
		q			=> i_line_buffer_Q,

		wrclock	=> CLK_48M_i,
		wraddress=> std_logic_vector(r_linebuf_ctr_ula),
		data		=> R_ULA_i & G_ULA_i & B_ULA_i,
		wren		=> i_line_buffer_wren
	);


	i_line_buffer_wren <= '1' when r_linebuf_ctr_ula < r_linebuf_ctr_ula_max 
												and r_ula_pixel_ring(0) = '1' 
												and r_ula_read_wait = '0'
												else

								 '0';
			

	p_reg_pix_ula:process(CLK_48M_i, fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_linebuf_ctr_ula <= (others => '0');
			r_linebuf_ctr_ula_max <= (others => '0');
		elsif rising_edge(CLK_48M_i) then

			if HSYNC_CRTC_i = '1' and r_hsync_prev_crtc = '0' then
				r_ula_read_wait <= '1';
				if r_hsync_lead_crtc(r_hsync_lead_crtc'HIGH) = '0' then
					r_linebuf_ctr_ula <= to_unsigned(0, r_linebuf_ctr_ula'LENGTH);
					r_linebuf_ctr_ula_max <= to_unsigned(C_BUFMAX, r_linebuf_ctr_ula'LENGTH);
				else					
					r_linebuf_ctr_ula <= to_unsigned(C_BUFMAX, r_linebuf_ctr_ula'LENGTH);
					r_linebuf_ctr_ula_max <= to_unsigned(2*C_BUFMAX, r_linebuf_ctr_ula'LENGTH);
				end if;
				r_linebuf_ctr_ula_prev_max	<= r_linebuf_ctr_ula + 1;

			elsif DISEN_CRTC_i = '1' and r_ula_read_wait = '1' then
				r_ula_read_wait <= '0';
				r_ula_pixel_ring <= (others => '1');
			elsif i_line_buffer_wren = '1' then
				if TTX_i = '1' then
					r_ula_pixel_ring <= "1000";
				else
					r_ula_pixel_ring <= "0100";
				end if;

				r_linebuf_ctr_ula <= r_linebuf_ctr_ula + 1;
			else
				r_ula_pixel_ring <= "0" & r_ula_pixel_ring(3 downto 1);
			end if;
		end if;

	end process;

	p_reg_syncs_crtc:process(fb_syscon_i, CLK_48M_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_hsync_prev_crtc <= '0';
			r_hsync_lead_crtc <= (others => '0');
			r_vsync_prev_crtc <= '0';
			r_vsync_lead_crtc <= (others => '0');
		elsif rising_edge(CLK_48M_i) then

			r_hsync_lead_crtc <= r_hsync_lead_crtc(r_hsync_lead_crtc'HIGH) & r_hsync_lead_crtc(r_hsync_lead_crtc'HIGH downto 1);
			r_vsync_lead_crtc <= r_vsync_lead_crtc(r_vsync_lead_crtc'HIGH) & r_vsync_lead_crtc(r_vsync_lead_crtc'HIGH downto 1);

			if HSYNC_CRTC_i = '1' and r_hsync_prev_crtc = '0' then
				r_hsync_lead_crtc(r_hsync_lead_crtc'HIGH) <= not r_hsync_lead_crtc(r_hsync_lead_crtc'HIGH);
			end if;

			if VSYNC_CRTC_i = '1' and r_vsync_prev_crtc = '0' then
				r_vsync_lead_crtc(r_vsync_lead_crtc'HIGH) <= not r_vsync_lead_crtc(r_vsync_lead_crtc'HIGH);
			end if;

			r_hsync_prev_crtc <= HSYNC_CRTC_i;
			r_vsync_prev_crtc <= VSYNC_CRTC_i;


		end if;

	end process;


	p_reg_syncs_dvi:process(fb_syscon_i, clk_pixel_dvi)
	begin

		if fb_syscon_i.rst = '1' then
			r_hsync_lead_ack <= '0';
			r_hsync_lead_pulse <= '0';
			r_vsync_lead_ack <= '0';
			r_vsync_lead_pulse <= '0';
			r_linebuf_ctr_dvi <= (others => '0');
		elsif rising_edge(clk_pixel_dvi) then

			r_hsync_lead_pulse <= '0';
			if r_hsync_lead_crtc(0) /= r_hsync_lead_ack then
				r_hsync_lead_ack <= r_hsync_lead_crtc(0);
				r_hsync_lead_pulse <= '1';
			end if;

			r_vsync_lead_pulse <= '0';
			if r_vsync_lead_crtc(0) /= r_vsync_lead_ack then
				r_vsync_lead_ack <= r_vsync_lead_crtc(0);
				r_vsync_lead_pulse <= '1';
			end if;

			if r_line_counter(0) = '0' or pixel_double_i = '0' then
				if r_line_counter < C_LINE_MARGIN then
					r_linebuf_ctr_dvi_max <= r_linebuf_ctr_ula_prev_max;
					if r_hsync_lead_ack = '0' then
						r_linebuf_ctr_dvi <= to_unsigned(0, r_linebuf_ctr_dvi'LENGTH);
					else					
						r_linebuf_ctr_dvi <= to_unsigned(C_BUFMAX, r_linebuf_ctr_dvi'LENGTH);
					end if;

					R_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(5),8));
					G_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(5),8));
					B_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(5),8));
				else
					if r_linebuf_ctr_dvi < r_linebuf_ctr_dvi_max then
						R_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(TO_INTEGER(UNSIGNED(i_line_buffer_Q(11 downto 8)))),8));						
						G_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(TO_INTEGER(UNSIGNED(i_line_buffer_Q(7 downto 4)))),8));
						B_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(TO_INTEGER(UNSIGNED(i_line_buffer_Q(3 downto 0)))),8));

						r_linebuf_ctr_dvi <= r_linebuf_ctr_dvi + 1;
					else
						R_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(0),8));
						G_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(0),8));
						B_DVI_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(0),8));				
					end if;
				end if;
			end if;

		end if;

	end process;


	p_genblank:process(clk_pixel_dvi)
	begin
		if rising_edge(clk_pixel_dvi) then

			if r_vsync_lead_pulse = '1' then
				r_field_next_but_one <= '1';
				if r_line_counter >= C_PIXELS_PER_LINE / 4 and r_line_counter < C_PIXELS_PER_LINE * 3 / 4 then
					r_odd_next <= '1';
				else
					r_odd_next <= '0';
				end if;
			end if;

			if r_hsync_lead_pulse = '1' then

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
				or r_line_counter > C_PIXELS_PER_LINE - C_LINE_BLANK_FRONT
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

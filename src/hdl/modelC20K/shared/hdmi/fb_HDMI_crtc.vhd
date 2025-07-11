-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	22/9/2021
-- Design Name: 
-- Module Name:    	fishbone bus - HDMI dual head CRTC wrapper
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the blitter/cpu board's secondary screen CRTC
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

--TODO: lose latched D - not really much point?


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;

entity fb_HDMI_crtc is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up
	);
	port(

		-- fishbone signals for cpu/dma port

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;

		-- fishbone to 48m timing signals
		reset48_i							: in     std_logic;
	
		-- Clock enable output to CRTC
		CLOCK_48_i							:  in    std_logic;
		CLKEN_CRTC_i						:	in		std_logic;
		
		-- Display interface
		VSYNC_o								:	out	std_logic;
		HSYNC_o								:	out	std_logic;
		DE_o									:	out	std_logic;
		CURSOR_o								:	out	std_logic;
		LPSTB_i								:	in		std_logic;
		
		-- Memory interface
		MA_o									:	out	std_logic_vector(13 downto 0);
		RA_o									:	out	std_logic_vector(4 downto 0);

		ILACE_o								:  out	std_logic

	);
end fb_HDMI_crtc;

architecture rtl of fb_HDMI_crtc is

	type		t_per_state	is (idle, rd, wait_d_stb);
	signal	r_per_state : t_per_state;

	-- FISHBONE wrapper signals
	signal	r_mc6845_rnw	: std_logic;
	signal	r_ack				: std_logic;
	signal	r_A				: std_logic;
	signal	r_D_wr			: std_logic_vector(7 downto 0);

	signal	r_vid_fb_req		: std_logic;
	signal   r_vid_48_ack   	: std_logic;
	signal   r_vid_48_clken		: std_logic;
	signal   r_vid_rd48_clken	: std_logic;
	signal	r_A_48				: std_logic;
	signal	r_D_wr_48			: std_logic_vector(7 downto 0);
	signal   i_d_rd_48			: std_logic_vector(7 downto 0);
	signal	r_mc6845_rnw_48	: std_logic;

begin

	e_crtc:entity work.mc6845
	port map (
		CLOCK			=> CLOCK_48_i,
		CLKEN			=> CLKEN_CRTC_i,
		CLKEN_CPU	=> '1',
		nRESET		=> not reset48_i,

		-- Bus interface
		ENABLE	=> r_vid_48_clken,
		R_nW		=> r_mc6845_rnw_48,
		RS			=> r_A_48,
		DI			=> r_d_wr_48,
		DO			=> i_d_rd_48,

		-- Display interface
		VSYNC		=> VSYNC_o,
		HSYNC		=> HSYNC_o,
		DE			=> DE_o,
		CURSOR	=> CURSOR_o,
		LPSTB		=> LPSTB_i,
		
		-- Memory interface
		MA			=> MA_o,
		RA			=> RA_o,

		VGA		=> '0',

		ILACE		=> ILACE_o
	);



	-- FISHBONE wrapper for CPU/DMA access
	fb_p2c_o.ack <= r_ack;
	fb_p2c_o.rdy <= r_ack;
	fb_p2c_o.stall <= '0' when r_per_state = idle else '1';

	p_req_ack:process(reset48_i, CLOCK_48_i)
	begin
		if reset48_i = '1' then
			r_vid_48_ack <= '0';
			r_vid_48_clken <= '0';
			r_vid_rd48_clken <= '0';
			r_mc6845_rnw_48 <= '1';
		elsif rising_edge(CLOCK_48_i) then
			r_vid_48_clken <= '0';
			r_vid_rd48_clken <= r_vid_48_clken;
			if r_vid_fb_req /= r_vid_48_ack then
				r_vid_48_clken <= '1';
				r_vid_48_ack <= r_vid_fb_req;
				r_A_48 <= r_A;
				r_D_wr_48 <= r_D_wr;
				r_mc6845_rnw_48 <= r_mc6845_rnw;
			end if;
		end if;
	end process;


	p_per_state:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_per_state <= idle;
			r_ack <= '0';
			r_mc6845_rnw <= '1';
			r_A <= '0';
			r_d_wr <= (others => '0');
			r_vid_fb_req <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			r_ack <= '0';
			case r_per_state is
				when idle =>
					if fb_c2p_i.cyc = '1' and fb_c2p_i.a_stb = '1' then
						r_mc6845_rnw <= not fb_c2p_i.we;
						r_A <= fb_c2p_i.A(0);
						if fb_c2p_i.we = '1' then
							if fb_c2p_i.D_wr_stb = '1' then
								r_d_wr <= fb_c2p_i.D_Wr;
								r_per_state <= idle;
								r_vid_fb_req <= not r_vid_48_ack;
								r_ack <= '1';
							else
								r_per_state <= wait_d_stb;
							end if;
						else
							r_per_state <= rd;
							r_vid_fb_req <= not r_vid_48_ack;
						end if;
					end if;
				when wait_d_stb =>
					if fb_c2p_i.D_wr_stb = '1' then
						r_d_wr <= fb_c2p_i.D_Wr;
						r_per_state <= idle;
						r_vid_fb_req <= not r_vid_48_ack;
						r_ack <= '1';
					else
						r_per_state <= wait_d_stb;
					end if;
				when rd =>
					if r_vid_rd48_clken = '1' then
						fb_p2c_o.D_rd <= i_d_rd_48;
						r_ack <= '1';
						r_per_state <= idle;
					end if;
				when others =>
					r_per_state <= idle;
					r_ack <= '1';
					r_mc6845_rnw <= '1';
			end case;
		end if;
	end process;




end rtl;
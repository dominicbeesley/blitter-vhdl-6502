-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	22/9/2021
-- Design Name: 
-- Module Name:    	fishbone bus - HDMI dual head VIDPROC wrapper
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the blitter/cpu board's secondary screen VIDPROC
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
use ieee.std_logic_misc.all;

library work;
use work.fishbone.all;

entity fb_HDMI_vidproc is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up

	);
	port(

		-- fishbone signals for cpu/dma port

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;

		
		CLK_48M_i							: in 		std_logic;

		-- Clock enable output to CRTC
		CLKEN_CRTC_o						:	out	std_logic;
		
		-- Clock enable output for sprite data fetches (always at 2MHz)
		CLKEN_SPR_o						:	out	std_logic;

		-- Display RAM data bus (for display data fetch)
		RAM_D0_i								:	in	std_logic_vector(7 downto 0);
		RAM_D1_i								:	in	std_logic_vector(7 downto 0);
		
		-- Control interface
		nINVERT_i							:	in	std_logic;
		DISEN_i								:	in	std_logic;
		CURSOR_i								:	in	std_logic;
		
		-- Teletext enabled
		TTX_o									:  out std_logic;

		-- Model B/C attribute in
		MODE_ATTR_i							:  in  std_logic;

		-- Model B/C sprites out
		SPR_PX_CLKEN						: out  std_logic;

		-- Model B/C sprites in 
		SPR_PX_ACT							: in   std_logic;
		SPR_PX_DAT  						: in   std_logic_vector(3 downto 0);

		-- Video in (teletext mode)
		R_TTX_i								:	in	std_logic;
		G_TTX_i								:	in	std_logic;
		B_TTX_i								:	in	std_logic;
		
		-- Video out
		R_o									:	out	std_logic_vector(3 downto 0);
		G_o									:	out	std_logic_vector(3 downto 0);
		B_o									:	out	std_logic_vector(3 downto 0)

	);
end fb_HDMI_vidproc;

architecture rtl of fb_HDMI_vidproc is

	-- FISHBONE wrapper signals
	type	 per_state_t is (idle, rd, wait_d_stb);
	signal r_per_state 					: per_state_t;

	signal r_A								: std_logic_vector(1 downto 0);
	signal r_d_wr							: std_logic_vector(7 downto 0);
	signal r_d_wr_stb						: std_logic;
	signal r_ack							: std_logic;

	-- VIDPROC generated signals
	signal	r_CLKEN16_DIV	: std_logic_vector(2 downto 0);
	signal	r_CLKEN16		: std_logic;

	signal 	i_R				: std_logic_vector(3 downto 0);
	signal 	i_G				: std_logic_vector(3 downto 0);
	signal 	i_B				: std_logic_vector(3 downto 0);

begin
	
	R_o <= i_R;
	G_o <= i_G;
	B_o <= i_B;


	e_vidproc:entity work.vidproc
	port map(
		PIXCLK			=> CLK_48M_i,


		CLOCK				=> fb_syscon_i.clk,
		CLKEN				=> r_CLKEN16,				-- TODO? 2MHz?

		nRESET			=> not fb_syscon_i.rst,
		
		CLKEN_CRTC		=> CLKEN_CRTC_o,
		CLKEN_SPR		=> CLKEN_SPR_o,
		
		CPUCLKEN			=> '1',
		ENABLE			=> r_d_wr_stb,
		A					=> r_A,
		DI_CPU			=> r_d_wr,
		DI_RAM_0			=> RAM_D0_i,
		DI_RAM_1			=> RAM_D1_i,
		nINVERT			=> nINVERT_i,
		DISEN				=> DISEN_i,
		CURSOR			=> CURSOR_i,
		R_IN				=> R_TTX_i,
		G_IN				=> G_TTX_i,
		B_IN				=> B_TTX_i,
		R					=> i_R,
		G					=> i_G,
		B					=> i_B,

		VGA				=> '0',

		TTXT				=> TTX_o,

		MODE_ATTR		=> MODE_ATTR_i,
		SPR_PX_CLKEN	=> SPR_PX_CLKEN,
		SPR_PX_ACT		=> SPR_PX_ACT,
		SPR_PX_DAT		=> SPR_PX_DAT
	);


	--register reset
	--divide down by 2 clock32 for clken
	p_reg32:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_CLKEN16_DIV <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
			r_CLKEN16_DIV <= std_logic_vector(unsigned(r_CLKEN16_DIV) + 1);
			if or_reduce(r_CLKEN16_DIV) = '0' then
				r_CLKEN16 <= '1';
			else
				r_CLKEN16 <= '0';
			end if;
		end if;
	end process;


		-- FISHBONE wrapper for CPU/DMA access
	fb_p2c_o.ack <= r_ack;
	fb_p2c_o.rdy <= r_ack;
	fb_p2c_o.stall <= '0' when r_per_state = idle else '1';

	fb_p2c_o.D_rd <= x"FF"; -- no readback


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
						r_A <= fb_c2p_i.A(1 downto 0);
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





end rtl;
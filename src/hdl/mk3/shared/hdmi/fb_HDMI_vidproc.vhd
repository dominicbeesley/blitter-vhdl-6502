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
		fb_m2s_i								: in		fb_mas_o_sla_i_t;
		fb_s2m_o								: out		fb_mas_i_sla_o_t;

		
		-- Clock enable output to CRTC
		CLKEN_CRTC_o						:	out	std_logic;
		
		-- Display RAM data bus (for display data fetch)
		RAM_D_i								:	in	std_logic_vector(7 downto 0);
		
		-- Control interface
		nINVERT_i							:	in	std_logic;
		DISEN_i								:	in	std_logic;
		CURSOR_i								:	in	std_logic;
		
		-- Video in (teletext mode)
		R_TTX_i								:	in	std_logic;
		G_TTX_i								:	in	std_logic;
		B_TTX_i								:	in	std_logic;
		
		-- Video out
		R_o									:	out	std_logic_vector(7 downto 0);
		G_o									:	out	std_logic_vector(7 downto 0);
		B_o									:	out	std_logic_vector(7 downto 0)

	);
end fb_HDMI_vidproc;

architecture rtl of fb_HDMI_vidproc is

	-- FISHBONE wrapper signals
	signal	i_fb_wrcyc_stb : std_logic;
	signal	i_fb_rdcyc		: std_logic;
	signal	r_ack				: std_logic;

	-- VIDPROC generated signals
	signal	r_CLKEN16_DIV	: std_logic_vector(2 downto 0);
	signal	r_CLKEN16		: std_logic;

	signal 	i_R_TTL			: std_logic;
	signal 	i_G_TTL			: std_logic;
	signal 	i_B_TTL			: std_logic;

begin
	
	R_o <= (others => i_R_TTL);
	G_o <= (others => i_G_TTL);
	B_o <= (others => i_B_TTL);


	e_vidproc:entity work.vidproc
	port map(
		CLOCK			=> fb_syscon_i.clk,
		CLKEN			=> r_CLKEN16,
		nRESET		=> not fb_syscon_i.rst,
		CLKEN_CRTC	=> CLKEN_CRTC_o,
		ENABLE		=> i_fb_wrcyc_stb,
		A0				=> fb_m2s_i.A(0),
		DI_CPU		=> fb_m2s_i.D_wr,
		DI_RAM		=> RAM_D_i,
		nINVERT		=> nINVERT_i,
		DISEN			=> DISEN_i,
		CURSOR		=> CURSOR_i,
		R_IN			=> R_TTX_i,
		G_IN			=> G_TTX_i,
		B_IN			=> B_TTX_i,
		R				=> i_R_TTL,
		G				=> i_G_TTL,
		B				=> i_B_TTL
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

	i_fb_wrcyc_stb <= fb_m2s_i.cyc and fb_m2s_i.A_stb and fb_m2s_i.we and fb_m2s_i.D_wr_stb;
	i_fb_rdcyc		<=  fb_m2s_i.cyc and fb_m2s_i.A_stb and not fb_m2s_i.we;

	fb_s2m_o.nul <= '0';
	fb_s2m_o.ack <= r_ack;

	-- TODO: This could give a better countdown but can't be bothered and it's unlikely
	-- to cause performance issues except for busy palette writes - might deliberately 
	-- delay this even more to a character cycle and count down to that?
	fb_s2m_o.rdy_ctdn <= to_unsigned(0, RDY_CTDN_LEN) when r_ack = '1' else
								RDY_CTDN_MAX;
	fb_s2m_o.D_rd <= (others => '1');

	p_ack:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_ack <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if i_fb_wrcyc_stb = '1' or i_fb_rdcyc = '1' then
				r_ack <= '1';
			else
				r_ack <= '0';
			end if;
		end if;
	end process;




end rtl;
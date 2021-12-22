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
	
		-- Clock enable output to CRTC
		CLKEN_CRTC_i						:	in		std_logic;
		CLKEN_CRTC_ADR_i					:	in		std_logic;
		
		-- Display interface
		VSYNC_o								:	out	std_logic;
		HSYNC_o								:	out	std_logic;
		DE_o									:	out	std_logic;
		CURSOR_o								:	out	std_logic;
		LPSTB_i								:	in		std_logic;
		
		-- Memory interface
		MA_o									:	out	std_logic_vector(13 downto 0);
		RA_o									:	out	std_logic_vector(4 downto 0)

	);
end fb_HDMI_crtc;

architecture rtl of fb_HDMI_crtc is

	-- FISHBONE wrapper signals
	signal	i_fb_wrcyc_stb : std_logic;
	signal	i_fb_rdcyc		: std_logic;
	signal	r_ack				: std_logic;
	signal 	i_rnw				: std_logic;



begin

	e_crtc:entity work.mc6845
	port map (
		CLOCK		=> fb_syscon_i.clk,
		CLKEN		=> CLKEN_CRTC_i,
		CLKEN_ADR=> CLKEN_CRTC_ADR_i,
		nRESET	=> not fb_syscon_i.rst,

		-- Bus interface
		ENABLE	=> i_fb_wrcyc_stb,
		R_nW		=> i_rnw,
		RS			=> fb_c2p_i.A(0),
		DI			=> fb_c2p_i.D_wr,
		DO			=> fb_p2c_o.D_rd,

		-- Display interface
		VSYNC		=> VSYNC_o,
		HSYNC		=> HSYNC_o,
		DE			=> DE_o,
		CURSOR	=> CURSOR_o,
		LPSTB		=> LPSTB_i,
		
		-- Memory interface
		MA			=> MA_o,
		RA			=> RA_o,

		VGA		=> '0'
	);



	-- FISHBONE wrapper for CPU/DMA access

	i_fb_wrcyc_stb <= fb_c2p_i.cyc and fb_c2p_i.A_stb and fb_c2p_i.we and fb_c2p_i.D_wr_stb;
	i_fb_rdcyc		<=  fb_c2p_i.cyc and fb_c2p_i.A_stb and not fb_c2p_i.we;

	fb_p2c_o.nul <= '0';
	fb_p2c_o.ack <= r_ack;
	i_rnw <= not fb_c2p_i.we;

	-- TODO: This could give a better countdown but can't be bothered and it's unlikely
	-- to cause performance issues except for busy palette writes - might deliberately 
	-- delay this even more to a character cycle and count down to that?
	fb_p2c_o.rdy_ctdn <= to_unsigned(0, RDY_CTDN_LEN) when r_ack = '1' else
								RDY_CTDN_MAX;

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
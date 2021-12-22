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
		CLKEN_CRTC_ADR_o					:	out	std_logic;
		
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

	signal 	i_R				: std_logic_vector(3 downto 0);
	signal 	i_G				: std_logic_vector(3 downto 0);
	signal 	i_B				: std_logic_vector(3 downto 0);

	signal	i_CPU_WR_EN		: std_logic;

	function RGBNULA_TO_DVI(i:unsigned) return natural is
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

begin
	
	R_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(unsigned(i_R)),8));
	G_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(unsigned(i_G)),8));
	B_o <= std_logic_vector(to_unsigned(RGBNULA_TO_DVI(unsigned(i_B)),8));


	e_vidproc:entity work.vidproc
	port map(
		PIXCLK			=> CLK_48M_i,


		CLOCK				=> fb_syscon_i.clk,
		CLKEN				=> r_CLKEN16,				-- TODO? 2MHz?

		nRESET			=> not fb_syscon_i.rst,
		
		CLKEN_CRTC		=> CLKEN_CRTC_o,
		CLKEN_CRTC_ADR	=> CLKEN_CRTC_ADR_o,
		
		CPUCLKEN			=> '1',
		ENABLE			=> i_CPU_WR_EN,
		A					=> fb_c2p_i.A(1 downto 0),
		DI_CPU			=> fb_c2p_i.D_wr,
		DI_RAM			=> RAM_D_i,
		nINVERT			=> nINVERT_i,
		DISEN				=> DISEN_i,
		CURSOR			=> CURSOR_i,
		R_IN				=> R_TTX_i,
		G_IN				=> G_TTX_i,
		B_IN				=> B_TTX_i,
		R					=> i_R,
		G					=> i_G,
		B					=> i_B,

		VGA				=> '0'
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

	i_fb_wrcyc_stb <= fb_c2p_i.cyc and fb_c2p_i.A_stb and fb_c2p_i.we and fb_c2p_i.D_wr_stb;
	i_fb_rdcyc		<=  fb_c2p_i.cyc and fb_c2p_i.A_stb and not fb_c2p_i.we;

	p_CPU_WR_EN:process(fb_syscon_i)
	variable v_prev_wrcyc: std_logic;
	begin
		if rising_edge(fb_syscon_i.clk) then
			i_CPU_WR_EN <= '0';
			if v_prev_wrcyc = '0' and i_fb_wrcyc_stb = '1' then
				i_CPU_WR_EN <= '1';
			end if;
			v_prev_wrcyc := i_fb_wrcyc_stb;
		end if;

	end process;

	fb_p2c_o.nul <= '0';
	fb_p2c_o.ack <= r_ack;

	-- TODO: This could give a better countdown but can't be bothered and it's unlikely
	-- to cause performance issues except for busy palette writes - might deliberately 
	-- delay this even more to a character cycle and count down to that?
	fb_p2c_o.rdy_ctdn <= to_unsigned(0, RDY_CTDN_LEN) when r_ack = '1' else
								RDY_CTDN_MAX;
	fb_p2c_o.D_rd <= (others => '1');

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
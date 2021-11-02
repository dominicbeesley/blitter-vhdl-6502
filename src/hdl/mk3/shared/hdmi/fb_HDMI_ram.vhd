-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	22/9/2021
-- Design Name: 
-- Module Name:    	fishbone bus - HDMI dual head RAM wrapper
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the blitter/cpu board's secondary screen memory
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

entity fb_HDMI_ram is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		G_MEM_ADDR_WIDTH					: positive := 15

	);
	port(

		-- fishbone signals for cpu/dma port

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;

		-- vga signals

		hdmi_ram_clk_i						: in		std_logic;
		hdmi_ram_addr_i					: in		std_logic_vector(16 downto 0);
		hdmi_ram_Q_o						: out		std_logic_vector(7 downto 0)

	);
end fb_HDMI_ram;

architecture rtl of fb_HDMI_ram is

	signal	i_fb_wrcyc_stb : std_logic;
	signal	i_fb_rdcyc		: std_logic;
	signal	r_ack				: std_logic;

begin

	i_fb_wrcyc_stb <= fb_c2p_i.cyc and fb_c2p_i.A_stb and fb_c2p_i.we and fb_c2p_i.D_wr_stb;
	i_fb_rdcyc		<=  fb_c2p_i.cyc and fb_c2p_i.A_stb and not fb_c2p_i.we;

	fb_p2c_o.nul <= '0';
	fb_p2c_o.ack <= r_ack;
	fb_p2c_o.rdy_ctdn <= to_unsigned(0, RDY_CTDN_LEN) when r_ack = '1' else
								to_unsigned(1, RDY_CTDN_LEN) when i_fb_wrcyc_stb = '1' else
								to_unsigned(1, RDY_CTDN_LEN) when i_fb_rdcyc = '1' else
								RDY_CTDN_MAX;

	p_ack:process(fb_syscon_i.clk, fb_syscon_i.rst)
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

	e_ram: entity work.hdmi_blockram
	port map
	(
		address_a => 	fb_c2p_i.A(G_MEM_ADDR_WIDTH-1 downto 0),
		clock_a => 		fb_syscon_i.clk,
		data_a => 		fb_c2p_i.D_wr,
		wren_a => 		i_fb_wrcyc_stb,
		q_a => 			fb_p2c_o.D_rd,

		address_b => 	hdmi_ram_addr_i(G_MEM_ADDR_WIDTH-1 downto 0),
		clock_b => 		hdmi_ram_clk_i,
		data_b => 		(others => '0'),
		wren_b => 		'0',
		q_b => 			hdmi_ram_Q_o		
	);



end rtl;
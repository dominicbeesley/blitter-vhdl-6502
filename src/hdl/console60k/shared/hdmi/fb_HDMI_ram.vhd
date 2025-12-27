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

	type	 per_state_t is (idle, rd0, rd, wait_d_stb);
	signal r_per_state 					: per_state_t;

	signal r_A								: std_logic_vector(G_MEM_ADDR_WIDTH-1 downto 0);
	signal r_d_wr							: std_logic_vector(7 downto 0);
	signal r_d_wr_stb						: std_logic;
	signal r_ack							: std_logic;

	signal i_douta							: std_logic_vector(7 downto 0);

begin

	-- FISHBONE wrapper for CPU/DMA access
	fb_p2c_o.ack <= r_ack;
	fb_p2c_o.rdy <= r_ack;
	fb_p2c_o.stall <= '0' when r_per_state = idle else '1';


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
						r_A <= fb_c2p_i.A(G_MEM_ADDR_WIDTH-1 downto 0);
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
							r_per_state <= rd0;
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
				when rd0 =>
					r_per_state <= rd;
				when rd =>
					fb_p2c_o.D_rd <= i_douta;
					r_ack <= '1';
					r_per_state <= idle;	
				when others =>
					r_per_state <= idle;
					r_ack <= '1';
			end case;
		end if;
	end process;


	e_ram: entity work.hdmi_blockram
	port map
	(
		reseta => '0',
		ada => 	r_A,
		clka => 		fb_syscon_i.clk,
		cea => '1',
		dina => 		r_d_wr,
		wrea => 		r_d_wr_stb,
		ocea => '1',
		douta =>   i_douta,

		resetb => '0',
		adb => 	hdmi_ram_addr_i(G_MEM_ADDR_WIDTH-1 downto 0),
		clkb => 		hdmi_ram_clk_i,
		ceb => '1',
		dinb => 		(others => '0'),
		wreb => 		'0',
		oceb => '1',
		doutb => 			hdmi_ram_Q_o		
	);



end rtl;
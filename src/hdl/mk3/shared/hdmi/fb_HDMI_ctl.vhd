-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	22/9/2021
-- Design Name: 
-- Module Name:    	fishbone bus - HDMI control AVI bytes
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

entity fb_HDMI_ctl is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up
	);
	port(

		-- fishbone signals for cpu/dma port

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;

		avi_o									: out		std_logic_vector(111 downto 0)

	);
end fb_HDMI_ctl;

architecture rtl of fb_HDMI_ctl is


	signal r_avi							: std_logic_vector(111 downto 0) := x"0000000000000000011500191030";

	signal r_avi_lat						: std_logic_vector(111 downto 0) := x"0000000000000000011500191030";


begin

	avi_o <= r_avi_lat;

	p_hdmi_regs:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then

		else
			if rising_edge(fb_syscon_i.clk) then

				if fb_c2p_i.cyc = '1' and fb_c2p_i.a_stb = '1' then
					if fb_c2p_i.we = '1' and fb_c2p_i.D_wr_stb = '1' then
						case to_integer(unsigned(fb_c2p_i.A(3 downto 0))) is
							when 0 =>
								r_avi(7 downto 0) <= fb_c2p_i.D_wr;
							when 1 =>
								r_avi(15 downto 8) <= fb_c2p_i.D_wr;
							when 2 =>
								r_avi(23 downto 16) <= fb_c2p_i.D_wr;
							when 3 =>
								r_avi(31 downto 24) <= fb_c2p_i.D_wr;
							when 4 =>
								r_avi(39 downto 32) <= fb_c2p_i.D_wr;
							when 5 =>
								r_avi(47 downto 40) <= fb_c2p_i.D_wr;
							when 6 =>
								r_avi(55 downto 48) <= fb_c2p_i.D_wr;
							when 7 =>
								r_avi(63 downto 56) <= fb_c2p_i.D_wr;
							when 8 =>
								r_avi(71 downto 64) <= fb_c2p_i.D_wr;
							when 9 =>
								r_avi(79 downto 72) <= fb_c2p_i.D_wr;
							when 10 =>
								r_avi(87 downto 80) <= fb_c2p_i.D_wr;
							when 11 =>
								r_avi(95 downto 88) <= fb_c2p_i.D_wr;
							when 12 =>
								r_avi(103 downto 96) <= fb_c2p_i.D_wr;
							when 13 =>
								r_avi(111 downto 104) <= fb_c2p_i.D_wr;
							when 15 =>
								r_avi_lat <= r_avi;
							when others => null;

						end case;
					end if;
				end if;	
			end if;
		end if;
	end process;

end rtl;
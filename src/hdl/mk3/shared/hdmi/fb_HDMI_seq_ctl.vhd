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

entity fb_HDMI_seq_ctl is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up
	);
	port(

		-- fishbone signals for cpu/dma port

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;
	
		ALPHA_MODE_o						: out		std_logic							-- when 1 alpha (ansi text) mode i.e. char in plane 0, attrs in plane 1


	);
end fb_HDMI_seq_ctl;

architecture rtl of fb_HDMI_seq_ctl is

	type		t_per_state	is (idle, rd, wait_d_stb);
	signal	r_per_state : t_per_state;

	-- FISHBONE wrapper signals
	signal	r_seq_en			: std_logic;
	signal	r_seq_rnw		: std_logic;
	signal	r_ack				: std_logic;
	signal	r_A				: std_logic;
	signal	r_D_wr			: std_logic_vector(7 downto 0);

	-- local signals

	signal 	r_IX				: unsigned(2 downto 0);
	signal	r_ALPHA			: std_logic;


begin

	ALPHA_MODE_o <= r_ALPHA;


	-- FISHBONE wrapper for CPU/DMA access
	fb_p2c_o.ack <= r_ack;
	fb_p2c_o.rdy <= r_ack;
	fb_p2c_o.stall <= '0' when r_per_state = idle else '1';

	p_per_state:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_per_state <= idle;
			r_ack <= '0';
			r_seq_en <= '0';
			r_seq_rnw <= '1';
			r_A <= '0';
			r_d_wr <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
			r_ack <= '0';
			r_seq_en <= '0';
			case r_per_state is
				when idle =>
					if fb_c2p_i.cyc = '1' and fb_c2p_i.a_stb = '1' then
						r_seq_rnw <= not fb_c2p_i.we;
						r_A <= fb_c2p_i.A(0);
						if fb_c2p_i.we = '1' then
							if fb_c2p_i.D_wr_stb = '1' then
								r_d_wr <= fb_c2p_i.D_Wr;
								r_seq_en <= '1';
								r_ack <= '1';
								r_per_state <= idle;
							else
								r_per_state <= wait_d_stb;
							end if;
						else
							r_seq_en <= '1';
							r_per_state <= rd;
						end if;
					end if;
				when wait_d_stb =>
					if fb_c2p_i.D_wr_stb = '1' then
						r_d_wr <= fb_c2p_i.D_Wr;
						r_seq_en <= '1';
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
					r_seq_en <= '0';
					r_seq_rnw <= '1';
			end case;
		end if;
	end process;


	p_wr:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_ALPHA <= '0';
			r_IX <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) and r_seq_en = '1' and r_seq_rnw = '0' then
			if r_A = '1' then
				-- data write
				case to_integer(r_IX) is
					when 0 =>
						r_ALPHA <= r_D_wr(0);
					when others =>
						null;
				end case;
			else
				r_IX <= unsigned(r_D_wr(r_IX'high downto 0));
			end if;
		end if;
	end process;

	fb_p2c_o.D_rd <= 	(0 => r_ALPHA, others => '0') when r_IX  = 0 else
							(others => '0');

end rtl;
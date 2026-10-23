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
	
		mode_alpha_o						: out		std_logic;							-- when 1 alpha (ansi text) mode i.e. char in plane 0, attrs in plane 1
		addr_alpha_fontA					: out		std_logic_vector(7 downto 0)

	);
end fb_HDMI_seq_ctl;

architecture rtl of fb_HDMI_seq_ctl is

	-- FISHBONE wrapper signals
   type     state_per_t is (idle, act_rd, act_wr);

   signal   r_state     : state_per_t;

   signal   r_D_ack     : std_logic;
   signal   r_A         : std_logic_vector(0 downto 0);
   signal   r_A_ack     : std_logic;
   signal   r_D_rd      : std_logic_vector(7 downto 0);
   signal   i_D_rd      : std_logic_vector(7 downto 0);

	signal	r_D_wr				: std_logic_vector(7 downto 0);
   signal   r_d_wr_stb  : std_logic;

	-- local signals

	signal 	r_IX					: unsigned(2 downto 0);
	signal	r_mode_alpha		: std_logic;
	signal   r_addr_alpha_fontA: std_logic_vector(7 downto 0);		-- font base address this will be multiplied by x"1000"

begin

   fb_p2c_o.A_ack    <= r_A_ack;
   fb_p2c_o.D_rd     <= r_D_rd;
   fb_p2c_o.rdy      <= r_D_ack;
   fb_p2c_o.D_ack    <= r_D_ack;


	mode_alpha_o <= r_mode_alpha;
	addr_alpha_fontA <= r_addr_alpha_fontA;


	p_per_state:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
         r_state <= idle;
         r_D_ack <= '0';
         r_A_ack <= '0';
         r_D_rd <= (others => '0');
         r_A <= (others => '0');
			r_d_wr <= (others => '0');
         r_d_wr_stb <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
         r_D_ack <= '0';
         r_A_ack <= '0';
         -- defer write one cycle to ease routing
         r_d_wr_stb <= '0';
         -- capture early - only needs to remain for one cycle but followed by a big mux so register to split timing
         r_d_wr <= fb_c2p_i.D_wr;
         case r_state is
				when idle =>
               -- capture early for less muxing
               r_A <= fb_c2p_i.A(0 downto 0);
               -- no need to check for previous r_A_ack cycle here as we can only go to act_wr, act_rd so no double ack
               if fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' then
						if fb_c2p_i.we = '1' then
                     r_state <= act_wr;
						else
                     r_state <= act_rd;
						end if;
                  r_A_ack <= '1';
					end if;
            when act_wr =>
               if fb_c2p_i.cyc = '1' and fb_c2p_i.D_wr_stb = '1' and r_D_ack = '0' then
                  r_D_ack <= '1';
                  r_state <= idle;
                  r_d_wr_stb <= '1';
               end if;
            when act_rd =>
               if fb_c2p_i.cyc = '1' then
                  r_D_rd <= i_D_rd;
                  r_D_ack <= '1';
					end if;
               r_state <= idle;              
				when others =>
               -- not sure if we should blindly ack here
               r_state <= idle;
			end case;

         if fb_c2p_i.cyc = '0' then
            r_state <= idle;
         end if;
		end if;
	end process;


	p_wr:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_mode_alpha <= '0';
			r_addr_alpha_fontA <= (others => '0');
			r_IX <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
			if r_d_wr_stb = '1' then
				if r_A = "1" then
					-- data write
					case to_integer(r_IX) is
						when 0 =>
							r_mode_alpha <= r_D_wr(0);
						when 1 => 
							r_addr_alpha_fontA <= r_D_wr;
						when others =>
							null;
					end case;
				else
					r_IX <= unsigned(r_D_wr(r_IX'high downto 0));
				end if;
			end if;
		end if;
	end process;

	-- Note: reads back always read back the value not the index - TODO: change this?
	i_D_rd <= 	(0 => r_mode_alpha, others => '0') when r_IX  = 0 else
							r_addr_alpha_fontA when r_IX  = 1 else
							(others => '0');

end rtl;
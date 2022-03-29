-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	fishbone bus - MEM - memory wrapper
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the blitter/cpu board's SRAM
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

entity fb_mem is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up
	);
	port(


		-- 2M RAM/256K ROM bus
		MEM_A_o								: out		std_logic_vector(20 downto 0);
		MEM_D_io								: inout	std_logic_vector(7 downto 0);
		MEM_nOE_o							: out		std_logic;
		MEM_ROM_nWE_o						: out		std_logic;
		MEM_RAM_nWE_o						: out		std_logic;
		MEM_ROM_nCE_o						: out		std_logic;
		MEM_RAM0_nCE_o						: out		std_logic;

		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_m2s_i								: in		fb_mas_o_sla_i_t;
		fb_s2m_o								: out		fb_mas_i_sla_o_t;

		debug_mem_a_stb_o					: out		std_logic

	);
end fb_mem;

architecture rtl of fb_mem is

	type 	 	state_mem_t is (idle, wait1, wait2, wait3, wait4, wait5, wait6, wait7, wait8, act);

	signal	state			: state_mem_t;

	signal	i_mas_ack	:	std_logic;

begin

	debug_mem_a_stb_o <= fb_m2s_i.a_stb;

	p_latch_d:process(fb_syscon_i, state, MEM_D_io)
	begin
		if fb_syscon_i.rst = '1' then
			fb_s2m_o.D_rd <= (others => '0');
		elsif state /= idle and state /= act then
			fb_s2m_o.D_rd <= MEM_D_io;
		end if;
	end process;

	p_state:process(fb_syscon_i)
	begin

		if fb_syscon_i.rst = '1' then
			state <= idle;
			MEM_A_o <= (others => '0');
			MEM_D_io <= (others => 'Z');
			MEM_nOE_o <= '1';
			MEM_RAM0_nCE_o <= '1';
			MEM_ROM_nCE_o <= '1';
			MEM_RAM_nWE_o <= '1';
			MEM_ROM_nWE_o <= '1';
			fb_s2m_o.rdy_ctdn <= RDY_CTDN_MAX;
			fb_s2m_o.ack <= '0';
			fb_s2m_o.nul <= '0';
		else
			if rising_edge(fb_syscon_i.clk) then
				case state is
					when idle =>
						MEM_A_o <= (others => '0');
						MEM_D_io <= (others => 'Z');
						MEM_nOE_o <= '1';
						MEM_RAM0_nCE_o <= '1';
						MEM_ROM_nCE_o <= '1';
						MEM_RAM_nWE_o <= '1';
						MEM_ROM_nWE_o <= '1';
						fb_s2m_o.rdy_ctdn <= RDY_CTDN_MAX;
						fb_s2m_o.ack <= '0';
						fb_s2m_o.nul <= '0';
						if fb_m2s_i.cyc = '1' and fb_m2s_i.A_stb = '1' then

							if fb_m2s_i.we = '1' and fb_m2s_i.D_wr_stb = '1' then
								MEM_A_o <= fb_m2s_i.A(20 downto 0);
								if fb_m2s_i.A(23) = '1' then
									MEM_ROM_nCE_o <= '0';
									MEM_ROM_nWE_o <= '0';																
									state <= wait2;
								else
									MEM_RAM0_nCE_o <= '0';
									MEM_RAM_nWE_o <= '0';							
									state <= wait3;
								end if;
								MEM_D_io <= fb_m2s_i.D_wr;								
							elsif fb_m2s_i.we = '0' then
								MEM_A_o <= fb_m2s_i.A(20 downto 0);
								if fb_m2s_i.A(23) = '1' then
									MEM_ROM_nCE_o <= '0';
									state <= wait2;
								else
									MEM_RAM0_nCE_o <= '0';
									state <= wait3;
								end if;
								MEM_nOE_o <= '0';															
							end if;
						end if;
					when wait1 =>
						state <= wait2;
						fb_s2m_o.rdy_ctdn <= to_unsigned(7, RDY_CTDN_LEN);
					when wait2 =>
						state <= wait3;
						fb_s2m_o.rdy_ctdn <= to_unsigned(6, RDY_CTDN_LEN);
					when wait3 =>
						state <= wait4;
						fb_s2m_o.rdy_ctdn <= to_unsigned(5, RDY_CTDN_LEN);
					when wait4 =>
						state <= wait5;
						fb_s2m_o.rdy_ctdn <= to_unsigned(4, RDY_CTDN_LEN);
					when wait5 =>
						state <= wait6;
						fb_s2m_o.rdy_ctdn <= to_unsigned(3, RDY_CTDN_LEN);
					when wait6 =>
							state <= wait7;
						fb_s2m_o.rdy_ctdn <= to_unsigned(2, RDY_CTDN_LEN);
					when wait7 =>
						state <= wait8;
						fb_s2m_o.rdy_ctdn <= to_unsigned(1, RDY_CTDN_LEN);
					when wait8 =>
						state <= act;
						fb_s2m_o.rdy_ctdn <= to_unsigned(0, RDY_CTDN_LEN);
						fb_s2m_o.ack <= '1';
					when act =>
						fb_s2m_o.rdy_ctdn <= to_unsigned(0, RDY_CTDN_LEN);
						MEM_nOE_o <= '1';
						MEM_RAM0_nCE_o <= '1';
						MEM_ROM_nCE_o <= '1';
						MEM_RAM_nWE_o <= '1';
						MEM_ROM_nWE_o <= '1';
						fb_s2m_o.ack <= '0';
					when others =>
						fb_s2m_o.nul <= '1';
						fb_s2m_o.ack <= '1';
						state <= idle;
				end case;
				if fb_m2s_i.cyc = '0' or fb_m2s_i.a_stb = '0' then
					state <= idle;
					fb_s2m_o.rdy_ctdn <= RDY_CTDN_MAX;
					fb_s2m_o.ack <= '0';
					fb_s2m_o.nul <= '0';
				end if;
			end if;
		end if;

	end process;


end rtl;
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	8/4/2019
-- Design Name: 
-- Module Name:    	clock generation, generate clocks in sync with SYStem phi2 clocks
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		PoC blitter and 6502/6809/Z80/68008 cpu board with 2M RAM, 256k ROM
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--USE WORK.mk1board_types.ALL;

entity clockgen is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow SDRAM start up
	);
	port(
		clk_128m_i							: in		std_logic;

		sys_phi2_in							: in		std_logic;

		mem_cyc_in							: in		std_logic;
		sys_slow_cyc_in					: in		std_logic;

		pll_clk_128m_out					: out		std_logic;							-- pll generated 128m clock from on-board 50m clock

		sys_clk_16m_out					: out		std_logic;
		sys_clk_8m_out						: out		std_logic;
		sys_clk_4m_out						: out		std_logic;
		sys_clk_2m_out						: out		std_logic;

		phi2_dll_lock						: out		std_logic;

		sys_phi2_fin_out					: out		std_logic;
		sys_long_1m_out					: out		std_logic;

		blip									: out		std_logic
	);
end clockgen;

architecture behavioral of clockgen is


	signal 	r_clock_ctr			: std_logic_vector(7 downto 0) := (others => '0');

	signal	i_long_1M_cyc		: std_logic;

	signal	r_sys_phi2			: std_logic_vector(2 downto 0);

	signal	r_sys_lockout		: std_logic; -- when '1' a non-system cycle has happened during this phi2 cycle, lockout phi2 acks

	signal	r_phi2phase_lock	: std_logic;

begin

	pll_clk_128m_out <= clk_128m_i;

	sys_clk_16m_out <= r_clock_ctr(2);
	sys_clk_8m_out <= r_clock_ctr(3);
	sys_clk_4m_out <= r_clock_ctr(4);
	sys_clk_2m_out <= r_clock_ctr(5);

	

	p_lockloss:process(i_pll_reset_n, r_phi2phase_lock, clk_128m_i)
	variable v_lock_ctr : unsigned(8 downto 0) := (others => '0');
	begin
		if rising_edge(clk_128m_i) then
			if i_pll_reset_n = '0' or r_phi2phase_lock = '0' then
				v_lock_ctr := (others => '1');
			elsif v_lock_ctr /= 0 then
				v_lock_ctr := v_lock_ctr - 1;
				sys_pll_reset_n_out <= '0';
			else
				sys_pll_reset_n_out <= '1';
			end if;
		end if;
	end process;

	blip <= r_sys_lockout;

	p_clock: process(clk_128m_i)
	variable v_new_clock:std_logic_vector(3 downto 0);
	begin
		if rising_edge(clk_128m_i) then

			if r_sys_phi2(1) = '0' and r_sys_phi2(2) = '1' then			
				if (signed(r_clock_ctr(3 downto 0)) < 3) then
					v_new_clock := std_logic_vector(signed(r_clock_ctr(3 downto 0)) + 2);
				elsif (signed(r_clock_ctr(3 downto 0)) = 3) then
					v_new_clock := "0100";
				else 
					v_new_clock := r_clock_ctr(3 downto 0);
				end if;
				r_clock_ctr(3 downto 0) <= v_new_clock;
				r_clock_ctr(r_clock_ctr'high downto 4) <= (others => v_new_clock(3));
				if (signed(r_clock_ctr(3 downto 0)) <= -2 or signed(r_clock_ctr(3 downto 0)) >= 6) then
					r_phi2phase_lock <= '0';
				else
					r_phi2phase_lock <= '1';
				end if;
			else
				r_clock_ctr <= std_logic_vector(unsigned(r_clock_ctr) + 1);
			end if;

			if unsigned(r_clock_ctr) = 4 then
				r_sys_lockout <= '0';
			elsif mem_cyc_in = '1' then
				r_sys_lockout <= '1';
			end if;

			r_sys_phi2 <= r_sys_phi2(r_sys_phi2'high - 1 downto 0) & sys_phi2_in;
		end if;
	end process;

	p_detect_long_1Mcyc:process(clk_128m_i, r_sys_phi2(1), r_clock_ctr)
	begin
		if rising_edge(clk_128m_i) then
			if r_clock_ctr = x"30" then
				if r_sys_phi2(1) = '1' then
					i_long_1M_cyc <= '0'; 
				else
					i_long_1M_cyc <= '1'; 
				end if;
			end if;
		end if;
	end process;


-- try rdy 2,4,8,16 signals instead
	p_fin:process(clk_128m_i, mem_cyc_in, r_clock_ctr, r_sys_lockout, sys_slow_cyc_in, i_long_1M_cyc)
	begin
		if rising_edge(clk_128m_i) then
			sys_phi2_fin_out <= '0';									-- reset on cpu clock
			if (mem_cyc_in = '1') then
				if r_clock_ctr(2 downto 0) = "111" then
					sys_phi2_fin_out <= '1';								-- fast memory/reg cycle
				end if;
			elsif r_sys_lockout = '0' then
				if sys_slow_cyc_in = '0' then								
					if r_clock_ctr(5 downto 0) = "111111" then
						sys_phi2_fin_out <= '1';								-- 2M sys cycle
					end if;
				else
					if i_long_1M_cyc = '1' then
						if r_clock_ctr(7 downto 0) = "10111111" then
							sys_phi2_fin_out <= '1';								-- long 1M sys cycle
						end if;
					else
						if r_clock_ctr(6 downto 0) = "1111111" then
							sys_phi2_fin_out <= '1';								-- short 1M sys cycle
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;

	sys_long_1m_out <= i_long_1M_cyc;

end behavioral;
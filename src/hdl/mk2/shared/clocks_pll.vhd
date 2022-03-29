-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	4/4/2019
-- Design Name: 
-- Module Name:    	dip 40 blitter - mk2 product board
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;

entity clocks_pll is
	generic (
		SIM										: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED								: natural := 128								-- fast clock speed in mhz				
	);
	port(

		EXT_nRESET_i							: in		std_logic;							-- external reset line																								
		EXT_CLK_50M_i							: in		std_logic;							-- board clock 50M

		clk_fish_o								: out 	std_logic;							-- main fast fishbone clock in 
		clk_lock_o								: out		std_logic;							-- pll lock indication
		clk_snd_o								: out		std_logic;							-- 3.5ish MHz clock for sound
		flasher_o								: out		std_logic_vector(3 downto 0)	-- flashes at approx 3=>0.5Hz, 1=2Hz, 1=2Hz, 0=4Hz


	);
end clocks_pll;


architecture rtl of clocks_pll is

	signal	r_flash_counter				: unsigned(CEIL_LOG2((2*CLOCKSPEED*1000000)-1)-1 downto 0) := (others => '0');

	signal	i_clk_fish						: std_logic;

	signal	i_clk_lock_128					: std_logic;
	signal	i_clk_lock_snd					: std_logic;

	-- shift register for reset pulse to PLL/DCM, shifted by clk in, to all 1's by start of reset
	signal	r_rst_pll						: std_logic_vector(10 downto 0) := (others => '1');	
	-- meta stability of EXT reset
	signal	r_ext_rst_meta					: std_logic_vector(2 downto 0) := (others => '0');

begin

	p_rst_shift:process(EXT_CLK_50M_i)
	variable v_rst_edge : boolean;
	begin

		if rising_edge(EXT_CLK_50M_i) then

			r_ext_rst_meta <= EXT_nRESET_i & r_ext_rst_meta(r_ext_rst_meta'high downto 1) ;

			if r_ext_rst_meta(1) = '0' and r_ext_rst_meta(0) = '1' then
				r_rst_pll <= (others => '1');
			else
				r_rst_pll <= '0' & r_rst_pll(r_rst_pll'high downto 1);
			end if;
		end if;

	end process;

	flasher_o <= std_logic_vector(r_flash_counter(r_flash_counter'high downto r_flash_counter'high-3));
	clk_fish_o <= i_clk_fish;

	p_flasher:process(i_clk_fish)
	begin
		if rising_edge(i_clk_fish) then
			r_flash_counter <= r_flash_counter + 1;
		end if;
	end process;

	g_sim_pll:if SIM generate
		p_pll_lock:process
		begin
			clk_lock_o <= '0';
			wait for 3.056 us;
			clk_lock_o <= '1';
			wait;
		end process;

		p_pll: process
		begin
			i_clk_fish <= '1';
			wait for 3.90625 ns;
			i_clk_fish <= '0';
			wait for 3.90625 ns;
		end process;

		p_pll_snd: process
		begin
			clk_snd_o <= '1';
			wait for 141 ns;
			clk_snd_o <= '0';
			wait for 141 ns;
		end process;
	end generate;

	g_not_sim_pll:if not SIM generate
		e_pll: entity work.pllmain
		port map(
			inclk0 => EXT_CLK_50M_i,
			c0 => i_clk_fish,
			c1 => clk_snd_o,
			locked => clk_lock_o
		);
	end generate;


end rtl;
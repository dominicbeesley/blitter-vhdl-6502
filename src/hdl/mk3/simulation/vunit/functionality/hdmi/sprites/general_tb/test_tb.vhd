library vunit_lib;
context vunit_lib.vunit_context;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.fishbone.all;

entity test_tb is
	generic (runner_cfg : string);
end test_tb;

architecture rtl of test_tb is

	constant FB_CLOCKSPEED : natural := 128;

	constant FB_CLOCK_PER : time := (1000000/FB_CLOCKSPEED) * 1 ps;

	signal i_fb_clk		: std_logic;
	signal i_SUP_RESn	: std_logic;

	signal i_fb_syscon			: fb_syscon_t;							-- shared bus signals


begin
	p_syscon_clk:process
	begin
		i_fb_clk <= '1';
		wait for FB_CLOCK_PER / 2;
		i_fb_clk <= '0';
		wait for FB_CLOCK_PER / 2;
	end process;


	p_main:process
	variable v_time:time;
	begin

		test_runner_setup(runner, runner_cfg);


		while test_suite loop

			if run("boop") then

				i_SUP_RESn <= '0';
				wait for 69 us; -- must be > pll lock time
				i_SUP_RESn <= '1';

				wait for 500 us;

			end if;


		end loop;

		wait for 3 us;

		test_runner_cleanup(runner); -- Simulation ends here
	end process;


	e_fb_syscon: entity work.fb_syscon
	generic map (
		SIM => true,
		CLOCKSPEED => FB_CLOCKSPEED
	)
	port map (
		fb_syscon_o							=> i_fb_syscon,

		EXT_nRESET_i						=> i_SUP_RESn,

		clk_fish_i							=> i_fb_clk,
		clk_lock_i							=> '1',
		sys_dll_lock_i						=> '1'

	);	


end rtl;
library vunit_lib;
context vunit_lib.vunit_context;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;

entity test_tb is
	generic (runner_cfg : string);
end test_tb;

architecture rtl of test_tb is

	constant CLOCKSPEED : natural := 128;

	constant CLOCK_PER : time := (1000000/CLOCKSPEED) * 1 ps;

	signal i_SER_RX 	: std_logic;
	signal i_SER_TX 	: std_logic;
	signal i_PLL_CLK	: std_logic;




begin
	p_syscon_clk:process
	begin
		i_PLL_CLK <= '1';
		wait for CLOCK_PER / 2;
		i_PLL_CLK <= '0';
		wait for CLOCK_PER / 2;
	end process;


	p_main:process
	variable v_time:time;
	begin

		test_runner_setup(runner, runner_cfg);


		i_SER_RX <= '0';


		while test_suite loop

			if run("boop") then


				wait for 500 us;

			end if;


		end loop;

		wait for 3 us;

		test_runner_cleanup(runner); -- Simulation ends here
	end process;

	e_dut:entity work.xyloni_test
	generic map (
		SIM			=> true,
		CLOCKSPEED	=> 128
	)
	port map (

		CLK_128_pll_i => i_PLL_CLK,
		SER_TX_o => i_SER_TX,
		SER_RX_i => i_SER_RX
	);

end rtl;

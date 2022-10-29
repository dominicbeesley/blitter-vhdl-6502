library vunit_lib;
context vunit_lib.vunit_context;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.fb_sys_pack.all;

entity test_tb is
	generic (runner_cfg : string);
end test_tb;

architecture rtl of test_tb is

	constant CLOCKSPEED : natural := 128;

	constant CLOCK_PER : time := (1000000/CLOCKSPEED) * 1 ps;

	type t_byte_array is array(natural range <>) of std_logic_vector(7 downto 0);

	signal i_fb_syscon : fb_syscon_t;
	signal i_fb_con_c2p : fb_con_o_per_i_t;
	signal i_fb_con_p2c : fb_con_i_per_o_t;


	constant G_BYTELANES : natural := 4;

	signal 	ib_BE						: std_logic;
	signal 	ib_cyc					: std_logic; 
	signal 	ib_A						: std_logic_vector(23 downto 0);
	signal 	ib_we						: std_logic;
	signal 	ib_lane_req				: std_logic_vector(G_BYTELANES-1 downto 0);
	signal 	ib_D_wr					: std_logic_vector((8 * G_BYTELANES)-1 downto 0);
	signal 	ib_D_wr_stb				: std_logic_vector(G_BYTELANES-1 downto 0);
	signal 	ib_rdy					: std_logic;
	signal 	ib_ack_lane				: std_logic_vector(G_BYTELANES-1 downto 0);
	signal 	ib_ack					: std_logic;
	signal 	ib_D_rd					: std_logic_vector((8 * G_BYTELANES)-1 downto 0);



	procedure sim_wait_reset 
	is
	variable i:natural;
	begin

			if i_fb_syscon.rst /= '1' then
			wait until i_fb_syscon.rst = '1';
		end if;

		wait until i_fb_syscon.rst = '0';

		for i in 0 to 3 loop
			wait until rising_edge(i_fb_syscon.clk);
		end loop;

	end sim_wait_reset;


begin
	p_syscon_clk:process
	begin
		i_fb_syscon.clk <= '1';
		wait for CLOCK_PER / 2;
		i_fb_syscon.clk <= '0';
		wait for CLOCK_PER / 2;
	end process;

	p_syscon_rst:process
	begin
		wait for 100 ns;
		i_fb_syscon.rst <= '1';
		-- simplify reset sequence
		i_fb_syscon.rst_state <= powerup;
		wait for 1 us;
		i_fb_syscon.rst <= '0';
		-- simplify reset sequence
		i_fb_syscon.rst_state <= run;
		wait;
	end process;


	p_main:process
	variable v_time:time;
	begin

		test_runner_setup(runner, runner_cfg);


		ib_BE <= '0';
		ib_A <= x"000000";
		ib_we <= '0';
		ib_lane_req <= "0000";
		ib_cyc <= '0';
		ib_D_wr <= (others => '0');
		ib_D_wr_stb <= (others => '0');


		while test_suite loop

			if run("little endian simple") then

				-- simple single read, with no a_stb delay

				sim_wait_reset;

				ib_BE <= '0';
				ib_A <= x"001200";
				ib_we <= '0';
				ib_lane_req <= "1111";
				ib_cyc <= '1';

				loop
					wait until rising_edge(i_fb_syscon.clk);
					if ib_ack = '1' then
						exit;
					end if;
				end loop;

				ib_cyc <= '0';

				assert ib_D_rd = x"FCFDFEFF" report "Expected FCFDFEFF got " & to_hex_string(ib_D_rd);

			elsif run("big endian simple") then

				-- simple single read, with no a_stb delay

				sim_wait_reset;

				ib_BE <= '1';
				ib_A <= x"001200";
				ib_we <= '0';
				ib_lane_req <= "1111";
				ib_cyc <= '1';

				loop
					wait until rising_edge(i_fb_syscon.clk);
					if ib_ack = '1' then
						exit;
					end if;
				end loop;

				ib_cyc <= '0';

				assert ib_D_rd = x"FFFEFDFC" report "Expected FFFEFDFC got " & to_hex_string(ib_D_rd);

			elsif run("8 bit simple") then

				-- simple single read, with no a_stb delay

				sim_wait_reset;

				ib_BE <= '0';
				ib_A <= x"001208";
				ib_we <= '0';
				ib_lane_req <= "0001";
				ib_cyc <= '1';

				loop
					wait until rising_edge(i_fb_syscon.clk);
					if ib_ack = '1' then
						exit;
					end if;
				end loop;

				ib_cyc <= '0';

				assert ib_D_rd(7 downto 0) = x"F7" report "Expected F7 got " & to_hex_string(ib_D_rd(7 downto 0));


			end if;

		end loop;

		wait for 3 us;

		test_runner_cleanup(runner); -- Simulation ends here
	end process;


	e_sim_per:entity work.sim_fb_per_mem
	generic map (
		G_SIZE => 256
		)
	port map (
		fb_syscon_i => i_fb_syscon,
		fb_c2p_i => i_fb_con_c2p,
		fb_p2c_o => i_fb_con_p2c
	);


	e_dut:entity work.fb_cpu_con_burst
	generic map (
		SIM			=> true,
		G_BYTELANES => G_BYTELANES
	)
	port map (

		fb_syscon_i							=> i_fb_syscon,

		BE_i									=> ib_BE,

		cyc_i									=> ib_cyc,
		A_i									=> ib_A,
		we_i									=> ib_we,
		lane_req_i							=> ib_lane_req,
		D_wr_i								=> ib_D_wr,
		D_wr_stb_i							=> ib_D_wr_stb,
		rdy_ctdn_i							=> RDY_CTDN_MIN,

		rdy_o									=> ib_rdy,
		ack_lane_o							=> ib_ack_lane,
		ack_o									=> ib_ack,
		D_rd_o								=> ib_D_rd,

		fb_con_c2p_o						=> i_fb_con_c2p,
		fb_con_p2c_i						=> i_fb_con_p2c

	);

end rtl;

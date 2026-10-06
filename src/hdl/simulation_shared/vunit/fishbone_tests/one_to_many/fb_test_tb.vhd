library vunit_lib;
context vunit_lib.vunit_context;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.fb_tester_pack.all;

entity test_tb is
	generic (runner_cfg : string);
end test_tb;

architecture rtl of test_tb is

	constant CLOCKSPEED 		: natural := 128;

	constant CLOCK_PER 		: time := (1000000/CLOCKSPEED) * 1 ps;

	signal i_fb_syscon 		: fb_syscon_t;
	
	signal i_fb_con_c2p		: fb_con_o_per_i_t;
	signal i_fb_con_p2c		: fb_con_i_per_o_t;

	signal i_fb_per_c2p 		: fb_con_o_per_i_arr(2 downto 0);
	signal i_fb_per_p2c 		: fb_con_i_per_o_arr(2 downto 0);

	signal is_A_ACK_DLY		: natural := 0;
	signal is_D_WR_ACK_DLY	: natural := 0;
	signal is_D_RD_ACK_DLY	: natural := 0;

	signal i_peripheral_sel_addr_o	: std_logic_vector(23 downto 0);
	signal i_peripheral_sel_we_o		: std_logic;
	signal i_peripheral_sel_i			: unsigned(1 downto 0);
	signal i_peripheral_sel_oh_i		: std_logic_vector(2 downto 0);

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
	variable v_time : time;
	variable v_D_test : std_logic_vector(7 downto 0);
	variable v_D_arrtest : t_fbtest_byte_array(0 to 100);

	procedure UNEXD(D : in std_logic_vector; D_expect : in std_logic_vector) is
	begin	
		if D /= D_expect then
			report "Unexpected data, got " & to_hstring(D) & ", expected " & to_hstring(D_expect) severity error;
		end if;
	end procedure UNEXD;

	begin

		is_A_ACK_DLY 	 <= 0;
		is_D_WR_ACK_DLY <= 0;
		is_D_RD_ACK_DLY <= 0;

		test_runner_setup(runner, runner_cfg);

		while test_suite loop

			if run("simple_mem_read") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				fbtest_single_read(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"000000",
					v_D_test,
					0
				);
				if v_D_test /= x"FF" then
					UNEXD(v_D_test, x"FF");
				end if;


				fbtest_single_read(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"100000",
					v_D_test,
					0
				);
				if v_D_test /= x"5A" then
					UNEXD(v_D_test, x"5A");
				end if;

				fbtest_single_read(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"200000",
					v_D_test,
					0
				);

				if v_D_test /= x"A5" then
					UNEXD(v_D_test, x"A5");
				end if;


			elsif run("simple_mem_write") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);
				fbtest_single_write(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"100012",
					x"A5",
					0,
					0
				);

				fbtest_single_read(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"100012",
					v_D_test,
					0
				);

				UNEXD(v_D_test, x"A5");
			elsif run("simple_mem_write_A_stb_dly") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				fbtest_single_write(
					i_fb_syscon,z
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"200012",
					x"A5",
					5,
					0
				);

				fbtest_single_read(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"200012",
					v_D_test,
					5
				);

				UNEXD(v_D_test, x"A5");
			elsif run("simple_mem_write_D_wr_stb_dly") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				fbtest_single_write(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"000012",
					x"A5",
					0,
					8
				);

				fbtest_single_read(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"000012",
					v_D_test,
					0
				);

				UNEXD(v_D_test, x"A5");
			elsif run("multi_mem_read") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				fbtest_multi_read(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"000012",
					5,
					v_D_arrtest,
					0,
					1
				);

				UNEXD(v_D_arrtest(0), x"ED");
				UNEXD(v_D_arrtest(1), x"EC");
				UNEXD(v_D_arrtest(2), x"EB");
				UNEXD(v_D_arrtest(3), x"EA");
				UNEXD(v_D_arrtest(4), x"E9");
			elsif run("multi_mem_write") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				v_D_arrtest(0) := x"12";
				v_D_arrtest(1) := x"DE";
				v_D_arrtest(2) := x"AD";
				v_D_arrtest(3) := x"BE";
				v_D_arrtest(4) := x"EF";

				fbtest_multi_write(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"000012",
					5,
					v_D_arrtest,
					0,
					0,
					1
				);

				v_D_arrtest := (others => (others => 'U'));

				fbtest_multi_read(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"000012",
					5,
					v_D_arrtest,
					0,
					1
				);

				UNEXD(v_D_arrtest(0), x"12");
				UNEXD(v_D_arrtest(1), x"DE");
				UNEXD(v_D_arrtest(2), x"AD");
				UNEXD(v_D_arrtest(3), x"BE");
				UNEXD(v_D_arrtest(4), x"EF");

			elsif run("multi_mem_write_slowA") then

				is_A_ACK_DLY <= 5;

				-- simple single read, with 5 clock a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				v_D_arrtest(0) := x"12";
				v_D_arrtest(1) := x"DE";
				v_D_arrtest(2) := x"AD";
				v_D_arrtest(3) := x"BE";
				v_D_arrtest(4) := x"EF";

				fbtest_multi_write(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"000012",
					5,
					v_D_arrtest,
					0,
					0,
					1
				);

				v_D_arrtest := (others => (others => 'U'));

				fbtest_multi_read(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"000012",
					5,
					v_D_arrtest,
					0,
					1
				);

				UNEXD(v_D_arrtest(0), x"12");
				UNEXD(v_D_arrtest(1), x"DE");
				UNEXD(v_D_arrtest(2), x"AD");
				UNEXD(v_D_arrtest(3), x"BE");
				UNEXD(v_D_arrtest(4), x"EF");

			elsif run("multi_mem_write_slowD") then

				is_A_ACK_DLY <= 0;
				is_D_RD_ACK_DLY <= 10;
				is_D_WR_ACK_DLY <= 8;

				-- simple single read, with 5 clock a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				v_D_arrtest(0) := x"12";
				v_D_arrtest(1) := x"DE";
				v_D_arrtest(2) := x"AD";
				v_D_arrtest(3) := x"BE";
				v_D_arrtest(4) := x"EF";

				fbtest_multi_write(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"000012",
					5,
					v_D_arrtest,
					0,
					0,
					1
				);

				v_D_arrtest := (others => (others => 'U'));

				fbtest_multi_read(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"000012",
					5,
					v_D_arrtest,
					0,
					1
				);

				UNEXD(v_D_arrtest(0), x"12");
				UNEXD(v_D_arrtest(1), x"DE");
				UNEXD(v_D_arrtest(2), x"AD");
				UNEXD(v_D_arrtest(3), x"BE");
				UNEXD(v_D_arrtest(4), x"EF");

			end if;


		end loop;

		wait for 3 us;

		test_runner_cleanup(runner); -- Simulation ends here
	end process;

	e_dut:entity work.fb_intcon_one_to_many
	generic map (
		G_PERIPHERAL_COUNT		=> 3
	)
	port map (

		fb_syscon_i						=> i_fb_syscon,

		-- peripheral port connect to controllers
		fb_con_c2p_i					=> i_fb_con_c2p,
		fb_con_p2c_o					=> i_fb_con_p2c,

		-- controller port connecto to peripherals
		fb_per_c2p_o					=> i_fb_per_c2p,
		fb_per_p2c_i					=> i_fb_per_p2c,

		-- peripheral select interface -- note, testing shows that having both one hot and index is faster _and_ uses fewer resources
		peripheral_sel_addr_o		=> i_peripheral_sel_addr_o,
		peripheral_sel_we_o		   => i_peripheral_sel_we_o,
		peripheral_sel_i				=> i_peripheral_sel_i,
		peripheral_sel_oh_i			=> i_peripheral_sel_oh_i

	);

	i_peripheral_sel_i <= 	"00" when i_peripheral_sel_addr_o(23 downto 20) = x"0" else
									"01" when i_peripheral_sel_addr_o(23 downto 20) = x"1" else
									"10";

	i_peripheral_sel_oh_i <= 	"001" when i_peripheral_sel_addr_o(23 downto 20) = x"0" else
										"010" when i_peripheral_sel_addr_o(23 downto 20) = x"1" else
										"100";

	e_sim_mem1:entity work.sim_fb_per_mem
	generic map (
		G_SIZE => 256,
		G_VALUE_XOR => x"00"
		)
	port map (
		fb_syscon_i => i_fb_syscon,
		fb_c2p_i 	=> i_fb_per_c2p(0),
		fb_p2c_o 	=> i_fb_per_p2c(0),

		sim_A_ACK_DLY 		=> is_A_ACK_DLY,
		sim_D_WR_ACK_DLY 	=> is_D_WR_ACK_DLY,
		sim_D_RD_ACK_DLY 	=> is_D_RD_ACK_DLY

	);

	e_sim_mem2:entity work.sim_fb_per_mem
	generic map (
		G_SIZE => 256,
		G_VALUE_XOR => x"A5"
		)
	port map (
		fb_syscon_i => i_fb_syscon,
		fb_c2p_i 	=> i_fb_per_c2p(1),
		fb_p2c_o 	=> i_fb_per_p2c(1),

		sim_A_ACK_DLY 		=> is_A_ACK_DLY,
		sim_D_WR_ACK_DLY 	=> is_D_WR_ACK_DLY,
		sim_D_RD_ACK_DLY 	=> is_D_RD_ACK_DLY

	);


	e_sim_mem3:entity work.sim_fb_per_mem
	generic map (
		G_SIZE => 256,
		G_VALUE_XOR => x"5A"
		)
	port map (
		fb_syscon_i => i_fb_syscon,
		fb_c2p_i 	=> i_fb_per_c2p(2),
		fb_p2c_o 	=> i_fb_per_p2c(2),

		sim_A_ACK_DLY 		=> is_A_ACK_DLY,
		sim_D_WR_ACK_DLY 	=> is_D_WR_ACK_DLY,
		sim_D_RD_ACK_DLY 	=> is_D_RD_ACK_DLY

	);


end rtl;

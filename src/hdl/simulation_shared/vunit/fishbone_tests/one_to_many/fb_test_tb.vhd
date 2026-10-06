library vunit_lib;
context vunit_lib.vunit_context;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.fb_tester_pack.all;

-- Tests for fb_intcon_one_to_many with three blocking sim_fb_per_mem
-- peripherals:
--
--   0x0x_xxxx -> peripheral 0, initial contents (A mod 256) xor FF
--   0x1x_xxxx -> peripheral 1, initial contents (A mod 256) xor FF xor A5
--   otherwise -> peripheral 2, initial contents (A mod 256) xor FF xor 5A
--
-- Bursts starting at 0x0FFFFE cross from peripheral 0 to peripheral 1 part
-- way through, which exercises holding off A_stb for a different peripheral
-- until the current one has returned all its D_acks.
--
-- As the peripherals are blocking (A_ack not given until the previous
-- transaction is D_ack'd) at most one transaction is ever outstanding, so
-- G_MAXOUT is not exercised here.

entity test_tb is
	generic (runner_cfg : string);
end test_tb;

architecture rtl of test_tb is

	constant CLOCKSPEED 		: natural := 128;

	constant CLOCK_PER 		: time := (1000000/CLOCKSPEED) * 1 ps;

	constant PERIPHERAL_COUNT : natural := 3;

	signal i_fb_syscon 		: fb_syscon_t;

	signal i_fb_con_c2p		: fb_con_o_per_i_t;
	signal i_fb_con_p2c		: fb_con_i_per_o_t;

	signal i_fb_per_c2p 		: fb_con_o_per_i_arr(PERIPHERAL_COUNT-1 downto 0);
	signal i_fb_per_p2c 		: fb_con_i_per_o_arr(PERIPHERAL_COUNT-1 downto 0);

	signal is_A_ACK_DLY		: natural := 0;
	signal is_D_WR_ACK_DLY	: natural := 0;
	signal is_D_RD_ACK_DLY	: natural := 0;

	signal i_peripheral_sel_addr_o	: std_logic_vector(23 downto 0);
	signal i_peripheral_sel_we_o		: std_logic;
	signal i_peripheral_sel_i			: unsigned(numbits(PERIPHERAL_COUNT)-1 downto 0);
	signal i_peripheral_sel_oh_i		: std_logic_vector(PERIPHERAL_COUNT-1 downto 0);

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
	variable v_completed : boolean;

	procedure UNEXD(D : in std_logic_vector; D_expect : in std_logic_vector) is
	begin
		if D /= D_expect then
			report "Unexpected data, got " & to_hstring(D) & ", expected " & to_hstring(D_expect) severity error;
		end if;
	end procedure UNEXD;

	-- the four bytes written by the cross peripheral write tests
	procedure SET_CROSS_DATA is
	begin
		v_D_arrtest := (others => (others => 'U'));
		v_D_arrtest(0) := x"12";
		v_D_arrtest(1) := x"DE";
		v_D_arrtest(2) := x"AD";
		v_D_arrtest(3) := x"BE";
	end procedure SET_CROSS_DATA;

	-- read back 4 bytes from 0x0FFFFE and check they are the cross data
	procedure CHECK_CROSS_DATA is
	begin
		v_D_arrtest := (others => (others => 'U'));
		fbtest_multi_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"0FFFFE", 4, v_D_arrtest, 0, 1);
		UNEXD(v_D_arrtest(0), x"12");
		UNEXD(v_D_arrtest(1), x"DE");
		UNEXD(v_D_arrtest(2), x"AD");
		UNEXD(v_D_arrtest(3), x"BE");
	end procedure CHECK_CROSS_DATA;

	-- read 4 bytes from 0x0FFFFE and check they are the initial contents
	procedure CHECK_CROSS_INIT(A_stb_dl : natural := 0) is
	begin
		v_D_arrtest := (others => (others => 'U'));
		fbtest_multi_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"0FFFFE", 4, v_D_arrtest, A_stb_dl, 1);
		UNEXD(v_D_arrtest(0), x"01");		-- peripheral 0, FE xor FF
		UNEXD(v_D_arrtest(1), x"00");		-- peripheral 0, FF xor FF
		UNEXD(v_D_arrtest(2), x"5A");		-- peripheral 1, 00 xor FF xor A5
		UNEXD(v_D_arrtest(3), x"5B");		-- peripheral 1, 01 xor FF xor A5
	end procedure CHECK_CROSS_INIT;

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
				UNEXD(v_D_test, x"FF");

				fbtest_single_read(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"100000",
					v_D_test,
					0
				);
				UNEXD(v_D_test, x"5A");

				fbtest_single_read(
					i_fb_syscon,
					i_fb_con_p2c,
					i_fb_con_c2p,
					x"200000",
					v_D_test,
					0
				);
				UNEXD(v_D_test, x"A5");

			elsif run("simple_mem_read_slowA") then

				-- single reads of each peripheral with a delayed A_ack

				is_A_ACK_DLY <= 5;

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				fbtest_single_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000000", v_D_test, 0);
				UNEXD(v_D_test, x"FF");
				fbtest_single_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"100000", v_D_test, 0);
				UNEXD(v_D_test, x"5A");
				fbtest_single_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"200000", v_D_test, 0);
				UNEXD(v_D_test, x"A5");

			elsif run("simple_mem_write") then

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

				-- single write and read with a 5 clock a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				fbtest_single_write(
					i_fb_syscon,
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

				-- single write with an 8 clock d_wr_stb delay

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

				-- burst write and read back with a 5 clock A_ack delay

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

				-- burst write and read back with slow D_acks

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

			elsif run("multi_mem_write_D_wr_stb_dly") then

				-- burst write with each d_wr_stb 3 clocks after its a_stb

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				SET_CROSS_DATA;
				fbtest_multi_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000040", 4, v_D_arrtest, 0, 3, 1);

				v_D_arrtest := (others => (others => 'U'));
				fbtest_multi_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000040", 4, v_D_arrtest, 0, 1);
				UNEXD(v_D_arrtest(0), x"12");
				UNEXD(v_D_arrtest(1), x"DE");
				UNEXD(v_D_arrtest(2), x"AD");
				UNEXD(v_D_arrtest(3), x"BE");

			elsif run("multi_read_cross_periph") then

				-- burst read crossing from peripheral 0 to 1

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);
				CHECK_CROSS_INIT;

			elsif run("multi_read_cross_periph_A_stb_dly") then

				-- as above with gaps between the a_stbs

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);
				CHECK_CROSS_INIT(3);

			elsif run("multi_read_cross_periph_slowA") then

				is_A_ACK_DLY <= 4;

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);
				CHECK_CROSS_INIT;

			elsif run("multi_read_cross_periph_slowD") then

				-- D_ack well after A_ack: the A_stb for peripheral 1 must be
				-- held until peripheral 0 has returned its D_ack

				is_D_RD_ACK_DLY <= 6;

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);
				CHECK_CROSS_INIT;

			elsif run("multi_write_cross_periph") then

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				SET_CROSS_DATA;
				fbtest_multi_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"0FFFFE", 4, v_D_arrtest, 0, 0, 1);
				CHECK_CROSS_DATA;

			elsif run("multi_write_cross_periph_late_D") then

				-- each d_wr_stb 3 clocks after its a_stb: the a_stb for
				-- peripheral 1 is held while peripheral 0 still waits for
				-- its data, and the d_wr_stb must reach peripheral 0

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				SET_CROSS_DATA;
				fbtest_multi_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"0FFFFE", 4, v_D_arrtest, 0, 3, 1);
				CHECK_CROSS_DATA;

			elsif run("multi_write_cross_periph_slowD") then

				is_D_WR_ACK_DLY <= 5;

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				SET_CROSS_DATA;
				fbtest_multi_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"0FFFFE", 4, v_D_arrtest, 0, 0, 1);
				CHECK_CROSS_DATA;

			elsif run("abort_read_wait_A_ack") then

				-- drop cyc while peripheral 1 is delaying A_ack, then check
				-- the interconnect has recovered by reading each peripheral

				is_A_ACK_DLY <= 10;

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				fbtest_abort(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"100010", '0', x"00", 3, v_completed);
				assert not v_completed report "aborted read completed" severity error;

				is_A_ACK_DLY <= 0;

				fbtest_single_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000010", v_D_test, 0);
				UNEXD(v_D_test, x"EF");
				fbtest_single_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"100010", v_D_test, 0);
				UNEXD(v_D_test, x"4A");

			elsif run("abort_read_wait_D_ack") then

				-- drop cyc after A_ack while peripheral 0 is delaying D_ack

				is_D_RD_ACK_DLY <= 10;

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				fbtest_abort(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000010", '0', x"00", 5, v_completed);
				assert not v_completed report "aborted read completed" severity error;

				is_D_RD_ACK_DLY <= 0;

				fbtest_single_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"100010", v_D_test, 0);
				UNEXD(v_D_test, x"4A");
				fbtest_single_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000010", v_D_test, 0);
				UNEXD(v_D_test, x"EF");

			elsif run("abort_write_wait_D_ack") then

				-- drop cyc while peripheral 0 is delaying the write D_ack;
				-- the write must not happen

				is_D_WR_ACK_DLY <= 10;

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				fbtest_abort(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000020", '1', x"77", 5, v_completed);
				assert not v_completed report "aborted write completed" severity error;

				fbtest_single_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000020", v_D_test, 0);
				UNEXD(v_D_test, x"DF");
				fbtest_single_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"100020", v_D_test, 0);
				UNEXD(v_D_test, x"7A");

			end if;


		end loop;

		wait for 3 us;

		test_runner_cleanup(runner); -- Simulation ends here
	end process;

	-- --------------------------------------------------------------------------
	-- Passive protocol checks on both sides of the interconnect
	-- --------------------------------------------------------------------------
	p_check:process(i_fb_syscon)
	variable v_n_a_stb   : natural;
	variable v_n_d_wr_stb: natural;
	variable vr_a_acks   : natural := 0;	-- A_acks passed up this cycle
	variable vr_d_acks   : natural := 0;	-- D_acks passed up this cycle
	begin
		if rising_edge(i_fb_syscon.clk) and i_fb_syscon.rst = '0' then

			-- peripheral side
			v_n_a_stb := 0;
			v_n_d_wr_stb := 0;
			for k in 0 to PERIPHERAL_COUNT-1 loop
				if i_fb_per_c2p(k).A_stb = '1' then
					v_n_a_stb := v_n_a_stb + 1;
					assert i_fb_per_c2p(k).cyc = '1' report "A_stb without cyc to peripheral " & integer'image(k) severity error;
				end if;
				if i_fb_per_c2p(k).D_wr_stb = '1' then
					v_n_d_wr_stb := v_n_d_wr_stb + 1;
					assert i_fb_per_c2p(k).cyc = '1' report "D_wr_stb without cyc to peripheral " & integer'image(k) severity error;
				end if;
			end loop;
			assert v_n_a_stb <= 1 report "A_stb to more than one peripheral" severity error;
			assert v_n_d_wr_stb <= 1 report "D_wr_stb to more than one peripheral" severity error;

			-- controller side
			if i_fb_con_c2p.cyc = '1' then
				assert i_fb_con_p2c.A_ack = '0' or i_fb_con_c2p.A_stb = '1' report "A_ack without A_stb" severity error;
				assert i_fb_con_p2c.D_ack = '0' or i_fb_con_p2c.rdy = '1' report "D_ack without rdy" severity error;
				if i_fb_con_p2c.A_ack = '1' then
					vr_a_acks := vr_a_acks + 1;
				end if;
				if i_fb_con_p2c.D_ack = '1' then
					vr_d_acks := vr_d_acks + 1;
				end if;
				assert vr_d_acks <= vr_a_acks report "more D_acks than A_acks" severity error;
			else
				assert i_fb_con_p2c.A_ack = '0' report "A_ack without cyc" severity error;
				assert i_fb_con_p2c.D_ack = '0' report "D_ack without cyc" severity error;
				vr_a_acks := 0;
				vr_d_acks := 0;
			end if;

		end if;
	end process;

	e_dut:entity work.fb_intcon_one_to_many
	generic map (
		G_PERIPHERAL_COUNT		=> PERIPHERAL_COUNT
	)
	port map (

		fb_syscon_i						=> i_fb_syscon,

		fb_up_c2p_i						=> i_fb_con_c2p,
		fb_up_p2c_o						=> i_fb_con_p2c,

		fb_dn_c2p_o						=> i_fb_per_c2p,
		fb_dn_p2c_i						=> i_fb_per_p2c,

		peripheral_sel_addr_o		=> i_peripheral_sel_addr_o,
		peripheral_sel_we_o		   => i_peripheral_sel_we_o,
		peripheral_sel_i				=> i_peripheral_sel_i,
		peripheral_sel_oh_i			=> i_peripheral_sel_oh_i

	);

	-- address decoder: index and one-hot each written out directly
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

		sim_A_ack_dly_i 		=> is_A_ACK_DLY,
		sim_D_wr_ack_dly_i 	=> is_D_WR_ACK_DLY,
		sim_D_rd_ack_dly_i 	=> is_D_RD_ACK_DLY

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

		sim_A_ack_dly_i 		=> is_A_ACK_DLY,
		sim_D_wr_ack_dly_i 	=> is_D_WR_ACK_DLY,
		sim_D_rd_ack_dly_i 	=> is_D_RD_ACK_DLY

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

		sim_A_ack_dly_i 		=> is_A_ACK_DLY,
		sim_D_wr_ack_dly_i 	=> is_D_WR_ACK_DLY,
		sim_D_rd_ack_dly_i 	=> is_D_RD_ACK_DLY

	);


end rtl;

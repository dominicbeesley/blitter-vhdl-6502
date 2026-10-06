library vunit_lib;
context vunit_lib.vunit_context;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.fb_tester_pack.all;

-- Tests for fb_intcon_one_to_many with three sim memory peripherals:
--
--   0x0x_xxxx -> peripheral 0, blocking sim_fb_per_mem,
--                initial contents (A mod 256) xor FF
--   0x1x_xxxx -> peripheral 1, pipelined sim_fb_per_mem_pipe,
--                initial contents (A mod 256) xor FF xor A5
--   otherwise -> peripheral 2, blocking sim_fb_per_mem,
--                initial contents (A mod 256) xor FF xor 5A
--
-- The delays of peripherals 0 and 2 are set per test (is_*). Peripheral 1
-- has fixed delays (A_ack 1, miss 16, hit 0): each visit starts with a miss,
-- so the next A_stb is A_ack'd and queued while the first is still being
-- serviced, and the queued hits return D_acks on consecutive clocks.
--
-- Bursts of C_BURST_LEN (8) start at:
--   C_A_CROSS_01 (0x0FFFFC) crosses from peripheral 0 to peripheral 1
--   C_A_CROSS_12 (0x1FFFFC) crosses from peripheral 1 to peripheral 2
--   C_A_PAGE_1   (0x1000FC) crosses a page boundary inside peripheral 1
-- At each peripheral crossing the interconnect must hold off the A_stb for
-- the new peripheral until the current one has returned all its D_acks.
-- Crossing out of peripheral 1 does this with several transactions
-- outstanding.
--
-- With back to back A_stbs peripheral 1 accepts a transaction every 3
-- clocks, so during the first 16 clock miss its queue (G_DEPTH 4) fills.
-- In the C_A_PAGE_1 burst (all 8 in peripheral 1) the 5th A_ack is then
-- withheld by the peripheral itself, rather than by the interconnect, and
-- the page crossing gives a second miss part way through the burst with
-- transactions queued behind it.
--
-- Memory is G_SIZE 256 (A mod 256), so C_A_PAGE_1 uses the same locations
-- in peripheral 1 as the two crossing bursts; each write burst uses its own
-- data so that the read back can only match the latest write.
--
-- Most tests check several conditions in turn; the notes on each say which.
--
-- Not yet exercised: G_MAXOUT, as the default (15) is more than peripheral
-- 1's G_DEPTH.

entity test_tb is
	generic (runner_cfg : string);
end test_tb;

architecture rtl of test_tb is

	constant CLOCKSPEED 		: natural := 128;

	constant CLOCK_PER 		: time := (1000000/CLOCKSPEED) * 1 ps;

	constant PERIPHERAL_COUNT : natural := 3;

	constant C_BURST_LEN		: natural := 8;

	constant C_A_CROSS_01	: std_logic_vector(23 downto 0) := x"0FFFFC";
	constant C_A_CROSS_12	: std_logic_vector(23 downto 0) := x"1FFFFC";
	constant C_A_PAGE_1		: std_logic_vector(23 downto 0) := x"1000FC";

	-- data written by the burst write tests
	constant C_BURST_DATA	: t_fbtest_byte_array(0 to C_BURST_LEN-1) :=
		(x"12", x"DE", x"AD", x"BE", x"EF", x"A5", x"B0", x"0B");

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

	-- initial memory contents at A, following the address map above
	function f_init(A : std_logic_vector(23 downto 0)) return std_logic_vector is
	variable v_xor : std_logic_vector(7 downto 0);
	begin
		case A(23 downto 20) is
			when x"0"	=> v_xor := x"00";
			when x"1"	=> v_xor := x"A5";
			when others	=> v_xor := x"5A";
		end case;
		return A(7 downto 0) xor x"FF" xor v_xor;
	end function;

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
	variable v_D_test : std_logic_vector(7 downto 0);
	variable v_D_arrtest : t_fbtest_byte_array(0 to 100);
	variable v_completed : boolean;

	procedure UNEXD(A : in std_logic_vector; D : in std_logic_vector; D_expect : in std_logic_vector) is
	begin
		if D /= D_expect then
			report "Unexpected data at " & to_hstring(A) & ", got " & to_hstring(D) & ", expected " & to_hstring(D_expect) severity error;
		end if;
	end procedure UNEXD;

	procedure SINGLE_READ(A : in std_logic_vector(23 downto 0); D_expect : in std_logic_vector; A_stb_dl : natural := 0) is
	begin
		fbtest_single_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, A, v_D_test, A_stb_dl);
		UNEXD(A, v_D_test, D_expect);
	end procedure SINGLE_READ;

	-- burst read C_BURST_LEN bytes from A and check they are the initial
	-- contents
	procedure BURST_READ(A : in std_logic_vector(23 downto 0); A_stb_dl : natural := 0) is
	variable v_A : std_logic_vector(23 downto 0);
	begin
		v_D_arrtest := (others => (others => 'U'));
		fbtest_multi_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, A, C_BURST_LEN, v_D_arrtest, A_stb_dl, 1);
		for i in 0 to C_BURST_LEN-1 loop
			v_A := std_logic_vector(unsigned(A) + i);
			UNEXD(v_A, v_D_arrtest(i), f_init(v_A));
		end loop;
	end procedure BURST_READ;

	-- burst write C_BURST_LEN bytes (C_BURST_DATA xor D_xor) to A, then burst
	-- read them back (itself a crossing read) and check them. Use a
	-- different D_xor when a burst writes locations already written in the
	-- test so that a lost write is seen.
	procedure BURST_WRITE(A : in std_logic_vector(23 downto 0); D_xor : in std_logic_vector(7 downto 0); D_stb_dl : natural := 0) is
	variable v_A : std_logic_vector(23 downto 0);
	begin
		v_D_arrtest := (others => (others => 'U'));
		for i in 0 to C_BURST_LEN-1 loop
			v_D_arrtest(i) := C_BURST_DATA(i) xor D_xor;
		end loop;
		fbtest_multi_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, A, C_BURST_LEN, v_D_arrtest, 0, D_stb_dl, 1);

		v_D_arrtest := (others => (others => 'U'));
		fbtest_multi_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, A, C_BURST_LEN, v_D_arrtest, 0, 1);
		for i in 0 to C_BURST_LEN-1 loop
			v_A := std_logic_vector(unsigned(A) + i);
			UNEXD(v_A, v_D_arrtest(i), C_BURST_DATA(i) xor D_xor);
		end loop;
	end procedure BURST_WRITE;

	begin

		is_A_ACK_DLY 	 <= 0;
		is_D_WR_ACK_DLY <= 0;
		is_D_RD_ACK_DLY <= 0;

		test_runner_setup(runner, runner_cfg);

		while test_suite loop

			if run("single_rw") then

				-- single transactions to each peripheral: reads of the
				-- initial contents check the decoder routing, then a write
				-- and read back to each with a different strobe timing

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				SINGLE_READ(x"000000", f_init(x"000000"));
				SINGLE_READ(x"100000", f_init(x"100000"));
				SINGLE_READ(x"200000", f_init(x"200000"));

				-- peripheral 0: D_wr_stb 8 clocks after A_stb
				fbtest_single_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000012", x"11", 0, 8);
				SINGLE_READ(x"000012", x"11");

				-- peripheral 1: no strobe delays
				fbtest_single_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"100012", x"22", 0, 0);
				SINGLE_READ(x"100012", x"22");

				-- peripheral 2: A_stb 5 clocks after cyc, for the write and the read
				fbtest_single_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"200012", x"33", 5, 0);
				SINGLE_READ(x"200012", x"33", 5);

			elsif run("cross_read") then

				-- burst reads crossing into and out of the pipelined
				-- peripheral and across a page inside it, first back to back
				-- then with 3 clock gaps between the A_stbs. Back to back,
				-- the page burst fills peripheral 1's queue (see header).

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				BURST_READ(C_A_CROSS_01);
				BURST_READ(C_A_CROSS_12);
				BURST_READ(C_A_PAGE_1);
				BURST_READ(C_A_CROSS_01, 3);
				BURST_READ(C_A_CROSS_12, 3);
				BURST_READ(C_A_PAGE_1, 3);

			elsif run("cross_read_slow") then

				-- as cross_read with slow A_ack and slow D_ack together on
				-- the blocking peripherals: the A_stb for the next
				-- peripheral must be held until the slow D_ack. No page
				-- burst, as peripheral 1's delays are fixed.

				is_A_ACK_DLY <= 4;
				is_D_RD_ACK_DLY <= 6;

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				BURST_READ(C_A_CROSS_01);
				BURST_READ(C_A_CROSS_12);

			elsif run("cross_write") then

				-- burst writes crossing into and out of the pipelined
				-- peripheral and across a page inside it, first with
				-- D_wr_stb with A_stb, then with each D_wr_stb 3 clocks late
				-- (each burst with its own data, see header). With late data
				-- the A_stb for the next peripheral is held while the
				-- current one still waits for its data, and the D_wr_stb must
				-- reach the current peripheral. In peripheral 1 the late data
				-- overlaps its miss delays.

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				BURST_WRITE(C_A_CROSS_01, x"00");
				BURST_WRITE(C_A_CROSS_12, x"00");
				BURST_WRITE(C_A_PAGE_1, x"55");
				BURST_WRITE(C_A_CROSS_01, x"FF", 3);
				BURST_WRITE(C_A_CROSS_12, x"FF", 3);
				BURST_WRITE(C_A_PAGE_1, x"AA", 3);

			elsif run("cross_write_slow") then

				-- as cross_write with slow A_ack and slow D_ack together on
				-- the blocking peripherals. No page burst, as above.

				is_A_ACK_DLY <= 4;
				is_D_WR_ACK_DLY <= 5;

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				BURST_WRITE(C_A_CROSS_01, x"00");
				BURST_WRITE(C_A_CROSS_12, x"00");

			elsif run("abort") then

				-- drop cyc part way through a transaction in three
				-- different states; after each check the interconnect has
				-- recovered by reading from two peripherals

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				-- 1. read: peripheral 0 is delaying A_ack
				is_A_ACK_DLY <= 10;
				fbtest_abort(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000010", '0', x"00", 3, v_completed);
				assert not v_completed report "abort 1: aborted read completed" severity error;
				is_A_ACK_DLY <= 0;

				SINGLE_READ(x"000010", f_init(x"000010"));
				SINGLE_READ(x"100010", f_init(x"100010"));

				-- 2. read: peripheral 1 has A_ack'd and is in its miss delay
				fbtest_abort(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"100010", '0', x"00", 5, v_completed);
				assert not v_completed report "abort 2: aborted read completed" severity error;

				SINGLE_READ(x"100010", f_init(x"100010"));
				SINGLE_READ(x"200010", f_init(x"200010"));

				-- 3. write: peripheral 1 has A_ack'd and queued the write and
				-- is in its miss delay; the write must not happen
				fbtest_abort(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"100020", '1', x"77", 5, v_completed);
				assert not v_completed report "abort 3: aborted write completed" severity error;

				SINGLE_READ(x"100020", f_init(x"100020"));
				SINGLE_READ(x"000020", f_init(x"000020"));

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
		G_PERIPHERAL_COUNT		=> PERIPHERAL_COUNT,
		G_MAXOUT						=> 2
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

	e_sim_mem2:entity work.sim_fb_per_mem_pipe
	generic map (
		G_SIZE => 256,
		G_VALUE_XOR => x"A5"
		)
	port map (
		fb_syscon_i => i_fb_syscon,
		fb_c2p_i 	=> i_fb_per_c2p(1),
		fb_p2c_o 	=> i_fb_per_p2c(1),

		sim_A_ack_dly_i 		=> 1,
		sim_D_miss_dly_i		=> 16,
		sim_D_hit_dly_i		=> 0
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

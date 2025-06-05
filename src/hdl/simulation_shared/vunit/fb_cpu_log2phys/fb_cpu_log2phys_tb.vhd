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
use work.fb_tester_pack.all;

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
	signal i_fb_con_extra_instr_fetch : std_logic;

	signal i_fb_per_c2p : fb_con_o_per_i_t;
	signal i_fb_per_p2c : fb_con_i_per_o_t;

	signal i_per_stall : std_logic := '0';
	signal i_ctr_per_stall : integer := 0;
	signal i_new_ctr_per_stall : integer := 0;


	procedure multi_read(
			A			: in 	std_logic_vector(23 downto 0);
			N			: positive;
		signal c2p	: out	fb_con_o_per_i_t;
			D    		: out t_byte_array;

			A_stb_dl : natural := 0			-- no of cycles to delay a_stb after cyc and between cycles
		) is
	variable v_tx : natural; -- number of a_stb's sent
	variable v_rx : natural; -- number of acks sent
	variable v_wt : natural;
	variable v_tot: natural;
	variable v_wt_stall:boolean;
	begin

		c2p <= fb_c2p_unsel;

		wait until rising_edge(i_fb_syscon.clk);

		c2p.cyc <= '1';
		c2p.rdy_ctdn <= RDY_CTDN_MIN;
		c2p.we <= '0';

		v_tot := 0;
		v_wt := A_stb_dl;
		v_wt_stall := false;
		while v_rx < N loop

			v_tot := v_tot + 1;
			assert v_tot < N * 2000 report "multi read " & to_hex_string(A) & "[" & natural'image(N) & "] took too many cyles" severity error;

			if v_tx < N and v_wt = 0 and not v_wt_stall then
				c2p.A <= std_logic_vector(unsigned(A) + v_tx);
				c2p.A_stb <= '1';
				v_tx := v_tx + 1;
				v_wt_stall := true;
			end if;

			wait until rising_edge(i_fb_syscon.clk);

			if v_wt_stall and i_fb_con_p2c.stall = '0' then
				v_wt_stall := false;
				c2p.A_stb <= '0';
				v_wt := A_stb_dl;
			end if;

			if i_fb_con_p2c.ack = '1' then
				D(v_rx) := i_fb_con_p2c.D_rd;
				v_rx := v_rx + 1;
			end if;

		end loop;

		c2p <= fb_c2p_unsel;


	end multi_read;


	


	procedure test_multi_mem_read(
		A				: in std_logic_vector(23 downto 0);
		N				: positive; -- number of reads in burst
		signal c2p 	: out	fb_con_o_per_i_t;
		A_stb_dl		: in natural := 0		-- number of cycles to delay A_stb for reads		
	)  is
	variable v_read: t_byte_array(0 to N-1);
	variable v_exp : t_byte_array(0 to N-1);
	variable i     : natural;
	begin

		multi_read(A, N, c2p, v_read, 0);

		for i in 0 to N-1 loop
			v_exp(I) := std_logic_vector((unsigned(A(7 downto 0)) + i) xor x"FF");

			assert v_read(I) = v_exp(I) report "returned " & to_hex_string(A) & "[" & natural'image(i) & "] " & to_hex_string(v_read(I)) & " expecting " & to_hex_string(v_exp(I)) severity error;
		end loop;

	end test_multi_mem_read;


	procedure test_simple_mem_read(
		A				: in std_logic_vector(23 downto 0);
		signal c2p 	: out	fb_con_o_per_i_t;
		A_stb_dl		: in natural := 0		-- number of cycles to delay A_stb for reads		
	)  is
	variable v_read: std_logic_vector(7 downto 0);
	variable v_exp : std_logic_vector(7 downto 0);
	begin

		fbtest_single_read(
			syscon_i => i_fb_syscon,
			p2c_i => i_fb_con_p2c,
			c2p_o => c2p,
			A_i => A, 
			D_o => v_read
			);

		v_exp := A(7 downto 0) xor x"FF";

		assert v_read = v_exp report "returned " & to_hex_string(v_read) & " expecting " & to_hex_string(v_exp) severity error;

	end test_simple_mem_read;


	procedure test_simple_mem_write_then_read(
		A				: in std_logic_vector(23 downto 0);
		D				: in std_logic_vector(7 downto 0);
		signal c2p 	: out	fb_con_o_per_i_t;
		A_stb_dl		: in natural := 0;		-- number of cycles to delay A_stb for reads/writes
		D_stb_dl		: in natural := 0
	)  is
	variable v_read: std_logic_vector(7 downto 0);
	begin

		fbtest_single_write(
			syscon_i => i_fb_syscon,
			p2c_i => i_fb_con_p2c,
			c2p_o => c2p,

			A_i => A,
			D_i => D, 
			A_stb_dl_i => A_stb_dl, 
			D_stb_dl_i => D_stb_dl
			);

		-- do a dummy read to clear any registered addresses!
		fbtest_single_read(
			syscon_i => i_fb_syscon,
			p2c_i => i_fb_con_p2c,
			c2p_o => c2p,
			A_i =>x"000000", 
			D_o => v_read,
			A_stb_dl_i => A_stb_dl
			);

		-- do actual read
		fbtest_single_read(
			syscon_i => i_fb_syscon,
			p2c_i => i_fb_con_p2c,
			c2p_o => c2p,
			A_i => A, 
			D_o => v_read,
			A_stb_dl_i => A_stb_dl
			);

		assert v_read = D report "returned " & to_hex_string(v_read) & " expecting " & to_hex_string(D) severity error;

	end test_simple_mem_write_then_read;


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

	procedure set_stall(
		stall_ctr_i : integer
		) is
	begin
		i_new_ctr_per_stall <= stall_ctr_i;
		wait until rising_edge(i_fb_syscon.clk);
		i_new_ctr_per_stall <= 0;
	end set_stall;


	begin

		test_runner_setup(runner, runner_cfg);

		while test_suite loop

			if run("simple_mem_read") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);
				test_simple_mem_read(x"000000", i_fb_con_c2p, 0);

			elsif run("simple_mem_read2") then

				-- simple single read, with 2 cycle a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);
				test_simple_mem_read(x"0001A5", i_fb_con_c2p, 2);

			elsif run("simple_mem_write_then_read") then

				-- simple single write followed by read, with no a_stb/d_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);
				test_simple_mem_write_then_read(x"000000", x"12", i_fb_con_c2p);

			elsif run("simple_mem_write_then_read2") then

				-- simple single write followed by read, with no a_stb = 2, d_stb = 3 delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);
				test_simple_mem_write_then_read(x"0001A5", x"BE", i_fb_con_c2p, 2, 3);

			elsif run("simple_mem_write_then_read3") then

				-- simple single write followed by read, with no a_stb = 2, d_stb = 3 delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);
				set_stall(5);
				test_simple_mem_write_then_read(x"0001A5", x"BE", i_fb_con_c2p, 0, 1);

			elsif run("ORB") then

				-- check that the VIA delay is working

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				v_time := now;

				test_simple_mem_write_then_read(x"FFFE40", x"BE", i_fb_con_c2p);
				test_simple_mem_write_then_read(x"FFFE40", x"DD", i_fb_con_c2p);

				v_time := now - v_time;

				report "orb took " & time'image(v_time) severity note;

				assert v_time > 20 us report "ORB too fast" severity error;
				assert v_time < 25 us report "ORB too slow" severity error;

			elsif run("multi_mem_read") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);
				test_multi_mem_read(x"000000", 4, i_fb_con_c2p, 0);

			end if;

		end loop;

		wait for 3 us;

		test_runner_cleanup(runner); -- Simulation ends here
	end process;

	p_stall:process
	begin
		wait until rising_edge(i_fb_syscon.clk);
		if i_new_ctr_per_stall > 0 then
			i_per_stall <= '1';
			i_ctr_per_stall <= i_new_ctr_per_stall;
		elsif i_ctr_per_stall > 0 then
			i_per_stall <= '1';
			i_ctr_per_stall <= i_ctr_per_stall - 1;
		else
			i_per_stall <= '0';
		end if;
	end process;

	e_sim_per:entity work.sim_fb_per_mem
	generic map (
		G_SIZE => 256
		)
	port map (
		fb_syscon_i => i_fb_syscon,
		fb_c2p_i => i_fb_per_c2p,
		fb_p2c_o => i_fb_per_p2c,

		stall_i  => i_per_stall
	);


	e_dut:entity work.fb_cpu_log2phys
	generic map (
		SIM									=> true,
		CLOCKSPEED							=> CLOCKSPEED,
		G_MK3									=> true
	)
	port map (

		fb_syscon_i							=> i_fb_syscon,
		fb_con_c2p_i						=> i_fb_con_c2p,
		fb_con_p2c_o						=> i_fb_con_p2c,
		fb_con_extra_instr_fetch_i		=> '0',

		fb_per_c2p_o						=> i_fb_per_c2p,
		fb_per_p2c_i						=> i_fb_per_p2c,

		-- per cpu config
		cfg_sys_via_block_i				=> '1',
		cfg_t65_i							=> '1',

		-- system type
		cfg_sys_type_i						=> SYS_BBC,
		cfg_swram_enable_i				=> '1',
		cfg_mosram_i						=> '0',
		cfg_swromx_i						=> '0',

		-- extra memory map control signals
		sys_ROMPG_i							=> x"0F",
		JIM_page_i							=> x"1234",
		jim_en_i								=> '1',

		-- SYS VIA slowdown enable
		sys_via_blocker_en_i				=> '1',

		-- memctl signals
		swmos_shadow_i						=> '1',
		turbo_lo_mask_i					=> x"00",
		rom_throttle_map_i				=> (others => '0'),
		rom_autohazel_map_i				=> (others => '0'),

		-- noice signals
		noice_debug_shadow_i				=> '0'

	);


end rtl;

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

	signal i_fb_syscon : fb_syscon_t;
	signal i_fb_con_c2p : fb_con_o_per_i_t;
	signal i_fb_con_p2c : fb_con_i_per_o_t;

	signal i_fb_per_c2p : fb_con_o_per_i_t;
	signal i_fb_per_p2c : fb_con_i_per_o_t;

	procedure sim_wait_reset 
	(
		signal c2p 	: out	fb_con_o_per_i_t
	) is
	variable i:natural;
	begin

		c2p <= fb_c2p_unsel;

		if i_fb_syscon.rst /= '1' then
			wait until i_fb_syscon.rst = '1';
		end if;

		wait until i_fb_syscon.rst = '0';

		for i in 0 to 3 loop
			wait until rising_edge(i_fb_syscon.clk);
		end loop;

	end sim_wait_reset;

	procedure single_read(
			A			: in 	std_logic_vector(23 downto 0);
		signal c2p	: out	fb_con_o_per_i_t;
			D    		: out std_logic_vector(7 downto 0)
	) is
	variable v_iter: natural;
	variable v_ret : std_logic_vector(7 downto 0);
	begin

		wait until rising_edge(i_fb_syscon.clk);

		c2p <= (
			cyc			=> '1',
			we				=> '0',
			A				=> A,
			A_stb			=> '1',
			D_wr			=> x"00",
			D_wr_stb		=> '0',
			rdy_ctdn		=> RDY_CTDN_MIN
		);

		wait until rising_edge(i_fb_syscon.clk);

		-- wait for stall

		v_iter := 0;
		while i_fb_con_p2c.stall /= '0' loop
			wait until rising_edge(i_fb_syscon.clk);
			v_iter := v_iter + 1;
			if v_iter > 1000 then
				report "Failed waiting for stall" severity error;
			end if;
		end loop;

		c2p.a_stb <= '0';

		wait until rising_edge(i_fb_syscon.clk);
		-- wait for ack

		v_iter := 0;
		while i_fb_con_p2c.ack /= '1' loop
			wait until rising_edge(i_fb_syscon.clk);
			v_iter := v_iter + 1;
			if v_iter > 1000 then
				report "Failed waiting for ack" severity error;
			end if;
		end loop;

		D := i_fb_con_p2c.D_rd;

		wait until rising_edge(i_fb_syscon.clk);

		c2p <= fb_c2p_unsel;

		wait until rising_edge(i_fb_syscon.clk);
		

	end single_read;

	procedure single_write(
			A			: in 	std_logic_vector(23 downto 0);
		signal c2p	: out	fb_con_o_per_i_t;
			D    		: in  std_logic_vector(7 downto 0)
	) is
	variable v_iter: natural;
	begin

		wait until rising_edge(i_fb_syscon.clk);

		c2p <= (
			cyc			=> '1',
			we				=> '1',
			A				=> A,
			A_stb			=> '1',
			D_wr			=> D,
			D_wr_stb		=> '1',
			rdy_ctdn		=> RDY_CTDN_MIN
		);

		wait until rising_edge(i_fb_syscon.clk);

		-- wait for stall

		v_iter := 0;
		while i_fb_con_p2c.stall /= '0' loop
			wait until rising_edge(i_fb_syscon.clk);
			v_iter := v_iter + 1;
			if v_iter > 1000 then
				report "Failed waiting for stall" severity error;
			end if;
		end loop;

		c2p.A_stb <= '0';
		c2p.D_wr_stb <= '0';
		c2p.we <= '0';

		wait until rising_edge(i_fb_syscon.clk);
		-- wait for ack

		v_iter := 0;
		while i_fb_con_p2c.ack /= '1' loop
			wait until rising_edge(i_fb_syscon.clk);
			v_iter := v_iter + 1;
			if v_iter > 1000 then
				report "Failed waiting for ack" severity error;
			end if;
		end loop;

		c2p <= fb_c2p_unsel;

		wait until rising_edge(i_fb_syscon.clk);
		

	end single_write;


	procedure test_simple_mem_read(
		signal c2p 	: out	fb_con_o_per_i_t
	)  is
	variable v_read: std_logic_vector(7 downto 0);
	begin

		sim_wait_reset(c2p);

		single_read(x"FF8023", c2p, v_read);

		assert v_read = x"DC" report "returned " & to_hex_string(v_read) & " expecting DC" severity error;

	end test_simple_mem_read;

	procedure test_simple_mem_write_then_read(
		signal c2p 	: out	fb_con_o_per_i_t
	)  is
	variable v_read: std_logic_vector(7 downto 0);
	begin

		sim_wait_reset(c2p);

		single_write(x"000000", c2p, x"12");

		single_read(x"000000", c2p, v_read);

		assert v_read = x"12" report "returned " & to_hex_string(v_read) & " expecting 12" severity error;

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
	begin

		test_runner_setup(runner, runner_cfg);

		while test_suite loop

			if run("simple_mem_read") then

				test_simple_mem_read(i_fb_con_c2p);

			elsif run("simple_mem_write_then_read") then

				test_simple_mem_write_then_read(i_fb_con_c2p);

			end if;

		end loop;

		test_runner_cleanup(runner); -- Simulation ends here
	end process;


	e_sim_per:entity work.sim_fb_per_mem
	generic map (
		G_SIZE => 256
		)
	port map (
		fb_syscon_i => i_fb_syscon,
		fb_c2p_i => i_fb_per_c2p,
		fb_p2c_o => i_fb_per_p2c
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

		-- memctl signals
		swmos_shadow_i						=> '1',
		turbo_lo_mask_i					=> x"00",

		-- noice signals
		noice_debug_shadow_i				=> '0'

	);

end rtl;

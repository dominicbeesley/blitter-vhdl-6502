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

	procedure sim_wait_reset is
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
	variable v_iter:natural;
	begin

		test_runner_setup(runner, runner_cfg);

		while test_suite loop

			if run("simple mem read") then

				i_fb_con_c2p <= fb_c2p_unsel;

				sim_wait_reset;

				i_fb_con_c2p <= (
					cyc			=> '1',
					we				=> '0',
					A				=> x"FF8023",
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

				i_fb_con_c2p.a_stb <= '0';

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

				report to_hex_string(i_fb_con_p2c.D_rd) severity note;


			end if;

		end loop;

		test_runner_cleanup(runner); -- Simulation ends here
	end process;

	p_per:process
	variable v_a: std_logic_vector(23 downto 0);
	begin

		i_fb_per_p2c <= (
				stall => '0',
				ack => '0',
				rdy => '0',
				D_rd => (others => '-')
			);

		wait until i_fb_per_c2p.cyc = '1' and i_fb_per_c2p.A_stb = '1' and rising_edge(i_fb_syscon.clk);

		v_a := i_fb_per_c2p.A;

		i_fb_per_p2c.stall <= '1';
		wait until rising_edge(i_fb_syscon.clk);
		wait until rising_edge(i_fb_syscon.clk);
		wait until rising_edge(i_fb_syscon.clk);
		i_fb_per_p2c.D_Rd <= v_a(7 downto 0) xor x"FF";
		i_fb_per_p2c.rdy <= '1';
		i_fb_per_p2c.ack <= '1';
		wait until rising_edge(i_fb_syscon.clk);

	end process;


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

library vunit_lib;
context vunit_lib.vunit_context;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.fishbone.all;
use work.common.all;

entity test_tb is
	generic (runner_cfg : string);
end test_tb;

architecture rtl of test_tb is

	constant CLOCKSPEED : natural := 128;
	constant CLOCK_PER : time := (1000000/CLOCKSPEED) * 1 ps;

	signal i_fb_syscon : fb_syscon_t;
	signal i_fb_con_c2p : fb_con_o_per_i_t;
	signal i_fb_con_p2c : fb_con_i_per_o_t;

	signal i_SPI_CS	: std_logic_vector(7 downto 0);
	signal i_SPI_CLK	: std_logic;
	signal i_SPI_MOSI	: std_logic;
	signal i_SPI_MISO	: std_logic;
	signal i_SPI_DET	: std_logic;

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
			D    		: out std_logic_vector(7 downto 0);

			A_stb_dl : natural := 0	-- no of cycles to delay a_stb after cyc
	) is
	variable v_iter: natural;
	variable v_ret : std_logic_vector(7 downto 0);
	begin

		wait until rising_edge(i_fb_syscon.clk);

		if (A_stb_dl = 0) then
			c2p <= (
				cyc			=> '1',
				we				=> '0',
				A				=> A,
				A_stb			=> '1',
				D_wr			=> x"00",
				D_wr_stb		=> '0',
				rdy_ctdn		=> RDY_CTDN_MIN
			);
		else
			c2p <= (
				cyc			=> '1',
				we				=> '0',
				A				=> (others => '-'),
				A_stb			=> '0',
				D_wr			=> x"00",
				D_wr_stb		=> '0',
				rdy_ctdn		=> RDY_CTDN_MIN
			);
			for i in 1 to A_stb_dl loop
				wait until rising_edge(i_fb_syscon.clk);
			end loop;

			c2p.A_stb <= '1';
			c2p.A <= A;
		end if;

		wait until rising_edge(i_fb_syscon.clk);

		-- wait for stall

		v_iter := 0;
		while i_fb_con_p2c.stall /= '0' loop
			wait until rising_edge(i_fb_syscon.clk);
			v_iter := v_iter + 1;
			if v_iter > 100000 then
				report "Failed waiting for stall" severity error;
			end if;
		end loop;

		c2p.a_stb <= '0';
		c2p.a <= (others => '-');

		wait until rising_edge(i_fb_syscon.clk);
		-- wait for ack

		v_iter := 0;
		while i_fb_con_p2c.ack /= '1' loop
			wait until rising_edge(i_fb_syscon.clk);
			v_iter := v_iter + 1;
			if v_iter > 100000 then
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
			D    		: in  std_logic_vector(7 downto 0);

			A_stb_dl : natural := 0;	-- no of cycles to delay a_stb after cyc
			D_stb_dl : natural := 0	-- no of cycles to delay d_stb after a_stb
	) is
	variable v_iter: natural;
	begin

		c2p <= fb_c2p_unsel;

		wait until rising_edge(i_fb_syscon.clk);

		c2p.cyc <= '1';
		c2p.rdy_ctdn <= RDY_CTDN_MIN;

		v_iter := 0;
		while v_iter < A_stb_dl loop
			wait until rising_edge(i_fb_syscon.clk);
			v_iter := v_iter + 1;
		end loop;

		c2p.we <= '1';
		c2p.A <= A;
		c2p.A_stb <= '1';

		if D_stb_dl = 0 then
			c2p.D_wr <= D;
			c2p.D_wr_stb <= '1';
		end if;

		v_iter := 0;
		loop
			wait until rising_edge(i_fb_syscon.clk);
			if i_fb_con_p2c.stall = '0' then
				exit;
			end if;
			v_iter := v_iter + 1;
			if v_iter > 100000 then
				report "Failed waiting for stall" severity error;
			end if;

		end loop;


		c2p.we <= '0';
		c2p.A <= (others => '-');
		c2p.A_stb <= '0';
		c2p.D_wr <= (others => '-');
		c2p.D_wr_stb <= '0';

		if D_stb_dl /= 0 then
			v_iter := 1;
			while v_iter < D_stb_dl loop
				wait until rising_edge(i_fb_syscon.clk);
				v_iter := v_iter + 1;

			end loop;
			c2p.D_wr <= D;
			c2p.D_wr_stb <= '1';		
			wait until rising_edge(i_fb_syscon.clk);

		end if;

		c2p.D_wr <= (others => '-');
		c2p.D_wr_stb <= '0';

		-- wait for ack

		v_iter := 0;
		while i_fb_con_p2c.ack /= '1' loop
			wait until rising_edge(i_fb_syscon.clk);
			v_iter := v_iter + 1;
			if v_iter > 100000 then
				report "Failed waiting for ack" severity error;
			end if;

		end loop;

		c2p <= fb_c2p_unsel;

		wait until rising_edge(i_fb_syscon.clk);
		
	end single_write;


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

		while test_suite loop

			if run("simple_write") then

				-- simple single read, with no a_stb delay
				sim_wait_reset(i_fb_con_c2p);
				single_write(x"000000", i_fb_con_c2p, x"A5");

				wait for 100 us;


			end if;

		end loop;

		wait for 3 us;

		test_runner_cleanup(runner); -- Simulation ends here
	end process;

	e_dut:entity work.fb_spi
	generic map (
		SIM									=> true,
		CLOCKSPEED							=> CLOCKSPEED
	)
	port map (

		fb_syscon_i							=> i_fb_syscon,
		fb_c2p_i								=> i_fb_con_c2p,
		fb_p2c_o								=> i_fb_con_p2c,

		SPI_CS_o								=> i_SPI_CS,
		SPI_CLK_o							=> i_SPI_CLK,
		SPI_MOSI_o							=> i_SPI_MOSI,
		SPI_MISO_i							=> i_SPI_MISO,
		SPI_DET_i							=> i_SPI_DET

	);


end rtl;

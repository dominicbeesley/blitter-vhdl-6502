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

   constant C_BURST_LEN    : natural := 8;

	signal i_fb_syscon 		: fb_syscon_t;
	signal i_fb_con_c2p 		: fb_con_o_per_i_t;
	signal i_fb_con_p2c 		: fb_con_i_per_o_t;

	signal is_A_ACK_DLY		: natural := 0;
	signal is_D_hit_ACK_DLY	: natural := 0;
	signal is_D_miss_ACK_DLY: natural := 0;

   signal   i_MEM_A              :  std_logic_vector(20 downto 0);
   signal   i_MEM_D              :  std_logic_vector(7 downto 0);
   signal   i_MEM_nOE            :  std_logic;
   signal   i_MEM_ROM_nWE        :  std_logic;
   signal   i_MEM_RAM_nWE        :  std_logic;
   signal   i_MEM_ROM_nCE        :  std_logic;
   signal   i_MEM_RAM0_nCE    	:  std_logic;

   constant C_BURST_DATA   : t_fbtest_byte_array(0 to C_BURST_LEN-1) :=
      (x"12", x"DE", x"AD", x"BE", x"EF", x"A5", x"B0", x"0B");

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

	procedure SINGLE_WRITE(A : in std_logic_vector(23 downto 0); D : in std_logic_vector; A_stb_dl : natural := 0; D_stb_dl : natural := 0) is
	begin
		fbtest_single_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, A, D, A_stb_dl, D_stb_dl);

		SINGLE_READ(A, D, A_stb_dl);
	end procedure;

   -- burst read C_BURST_LEN bytes from A and check they are the initial
   -- contents
   procedure BURST_READ(A : in std_logic_vector(23 downto 0); D_exp : t_fbtest_byte_array; A_stb_dl : natural := 0) is
   variable v_A : std_logic_vector(23 downto 0);
   begin
      v_D_arrtest := (others => (others => 'U'));
      fbtest_multi_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, A, C_BURST_LEN, v_D_arrtest, A_stb_dl, 1);
      for i in 0 to C_BURST_LEN-1 loop
         v_A := std_logic_vector(unsigned(A) + i);
         UNEXD(v_A, v_D_arrtest(i), D_exp(i));
      end loop;
   end procedure BURST_READ;

   -- burst write C_BURST_LEN bytes (C_BURST_DATA xor D_xor) to A, then burst
   -- read them back (itself a crossing read) and check them. Use a
   -- different D_xor when a burst writes locations already written in the
   -- test so that a lost write is seen.
   procedure BURST_WRITE(A : in std_logic_vector(23 downto 0); D : t_fbtest_byte_array; A_stb_dl : natural := 0; D_stb_dl : natural := 0) is
   variable v_A : std_logic_vector(23 downto 0);
   begin
      fbtest_multi_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, A, C_BURST_LEN, D, A_stb_dl, D_stb_dl, 1);

      v_D_arrtest := (others => (others => 'U'));
      fbtest_multi_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, A, C_BURST_LEN, v_D_arrtest, A_stb_dl, 1);
      for i in 0 to C_BURST_LEN-1 loop
         v_A := std_logic_vector(unsigned(A) + i);
         UNEXD(v_A, v_D_arrtest(i), D(i));
      end loop;
   end procedure BURST_WRITE;

	begin

		is_A_ACK_DLY 	 <= 0;
		is_D_hit_ACK_DLY <= 0;
		is_D_miss_ACK_DLY <= 0;

		test_runner_setup(runner, runner_cfg);

		while test_suite loop

			if run("simple_mem_write_chipram") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				SINGLE_WRITE(x"000012", x"A5", 0, 0);

			elsif run("simple_mem_write_flash") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				SINGLE_WRITE(x"900012", x"A5", 0, 0);
			elsif run("simple_mem_write_chipram_Adl5") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				SINGLE_WRITE(x"000012", x"A5", 5, 0);

			elsif run("simple_mem_write_flash_Adl5") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				SINGLE_WRITE(x"900012", x"A5", 5, 0);
			elsif run("simple_mem_write_chipram_Adl5Ddl8") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				SINGLE_WRITE(x"000012", x"A5", 5, 8);

			elsif run("simple_mem_write_flash_Adl5Ddl8") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				SINGLE_WRITE(x"900012", x"A5", 5, 8);
			elsif run("burst_mem_write_chipram") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				BURST_WRITE(x"000012", C_BURST_DATA, 0, 0);

			elsif run("burst_mem_write_flash") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				BURST_WRITE(x"900012", C_BURST_DATA, 0, 0);
			elsif run("burst_mem_write_chipram_Adl5") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				BURST_WRITE(x"000012", C_BURST_DATA, 5, 0);

			elsif run("burst_mem_write_flash_Adl5") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				BURST_WRITE(x"900012", C_BURST_DATA, 5, 0);
			elsif run("burst_mem_write_chipram_Adl5Ddl8") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				BURST_WRITE(x"000012", C_BURST_DATA, 5, 8);

			elsif run("burst_mem_write_flash_Adl5Ddl8") then

				-- simple single read, with no a_stb delay

				fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

				BURST_WRITE(x"900012", C_BURST_DATA, 5, 8);
			end if;


		end loop;

		wait for 3 us;

		test_runner_cleanup(runner); -- Simulation ends here
	end process;

	e_dut:entity work.fb_mem
	generic map (
		G_FLASH_IS_45	=> false,
		G_SLOW_IS_45	=> true
		)
	port map (
		fb_syscon_i => i_fb_syscon,
		fb_c2p_i => i_fb_con_c2p,
		fb_p2c_o => i_fb_con_p2c,

		MEM_A_o			=> i_MEM_A,
		MEM_D_io			=> i_MEM_D,
		MEM_nOE_o		=> i_MEM_nOE,
		MEM_ROM_nWE_o	=> i_MEM_ROM_nWE,
		MEM_RAM_nWE_o  => i_MEM_RAM_nWE,
		MEM_ROM_nCE_o  => i_MEM_ROM_nCE,
		MEM_RAM0_nCE_o => i_MEM_RAM0_nCE

	);

	-- chipram
	e_blit_ram_2048_0: entity work.ram_tb 
   generic map (
      size        => 2048*1024,
      tco => 45 ns,
      taa => 45 ns
   )
   port map (
      A           => i_MEM_A(20 downto 0),
      D           => i_MEM_D,
      nCS         => i_MEM_RAM0_nCE,
      nOE         => i_MEM_nOE,
      nWE         => i_MEM_RAM_nWE,
      
      tst_dump    => '0'

   );

   --actually a RAM so we can test phoney writes
   e_blit_rom_512: entity work.ram_tb 
   generic map (
      size        => 16*1024,
      dump_filename => "",
      tco => 55 ns,
      taa => 55 ns
   )
   port map (
		A           => i_MEM_A(13 downto 0),
      D           => i_MEM_D,
      nCS         => i_MEM_ROM_nCE,
      nOE         => i_MEM_nOE,
      nWE         => i_MEM_ROM_nWE,    
      tst_dump    => '0'

   );


   -- --------------------------------------------------------------------------
   -- Passive protocol checks 
   -- --------------------------------------------------------------------------
   p_check:process(i_fb_syscon)
   variable vr_a_acks   : natural := 0;   -- A_acks passed up this cycle
   variable vr_d_acks   : natural := 0;   -- D_acks passed up this cycle
   begin
      if rising_edge(i_fb_syscon.clk) and i_fb_syscon.rst = '0' then

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
            assert i_fb_con_c2p.D_wr_stb = '0' report "D_wr_stb without cyc " severity error;
            assert i_fb_con_c2p.A_stb = '0' report "A_stb without cyc " severity error;
            assert i_fb_con_p2c.A_ack = '0' report "A_ack without cyc" severity error;
            assert i_fb_con_p2c.D_ack = '0' report "D_ack without cyc" severity error;
            vr_a_acks := 0;
            vr_d_acks := 0;
         end if;

      end if;
   end process;

end rtl;

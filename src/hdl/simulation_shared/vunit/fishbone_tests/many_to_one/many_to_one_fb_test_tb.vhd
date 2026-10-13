library vunit_lib;
context vunit_lib.vunit_context;

-- many_to_one_fb_test_tb
--
-- Tests fb_intcon_many_to_one with three controllers (A, B, C, each through
-- an fb_intcon_buffer) sharing one pipelined sim memory (sim_fb_per_mem_pipe,
-- also behind a buffer: A_ack delay 1, miss 16, hit 0).
--
-- test_order: after reset all three controllers write 3 bytes each to
-- overlapping addresses (A 0x10-0x12, B 0x11-0x13, C 0x12-0x14), either as
-- one burst per controller (G_BURST) or as single-byte cycles. Controller A
-- then reads back 0x10-0x14. Because the ranges overlap, the read-back data
-- shows the order in which the writes were granted:
--   burst:  whole bursts in the order A, B, C, i.e. no switching mid-cyc.
--           Priority and round-robin give the same order here.
--   single: the per-byte cycles interleave between the controllers, in an
--           order that differs between priority and round-robin.
-- p_check checks both sides passively: no strobes to the peripheral without
-- cyc, no A_ack/D_ack to a controller without cyc, A_ack only with A_stb,
-- rdy with every D_ack, and never more D_acks than A_acks in a cycle.
--
-- run.py runs every combination of arbiter (priority/round-robin),
-- burst/single, and buffer setting (none/c2p/p2c/both, applied to all the
-- buffers).
--
-- Not covered yet: dropping cyc mid-burst, and reads by one controller 
-- interleaved with writes by another.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.fb_tester_pack.all;


entity test_tb is
   generic (
      runner_cfg  : string;
      G_ARB_ROUND_ROBIN    : boolean := false;
      G_BURST : boolean := false;

      G_CON_REG_P2C  : boolean := true;
      G_CON_REG_C2P  : boolean := true;

      G_PER_REG_P2C  : boolean := true;
      G_PER_REG_C2P  : boolean := true
   );
end test_tb;

architecture rtl of test_tb is

   constant CLOCKSPEED        : natural := 128;

   constant CLOCK_PER         : time := (1000000/CLOCKSPEED) * 1 ps;

   constant CONTROLLER_COUNT  : natural := 3;


   -- data written by the burst write tests
   constant C_BURST_LEN    : natural := 3;
   constant C_BURST_DATA_A : t_fbtest_byte_array(0 to C_BURST_LEN-1) :=
      (x"01", x"02", x"03");
   constant C_BURST_DATA_B : t_fbtest_byte_array(0 to C_BURST_LEN-1) :=
      (x"99", x"AA", x"BB");
   constant C_BURST_DATA_C : t_fbtest_byte_array(0 to C_BURST_LEN-1) :=
      (x"FF", x"FE", x"FD");

   constant C_BURST_ADDR_A : std_logic_vector(23 downto 0) := x"000010";
   constant C_BURST_ADDR_B : std_logic_vector(23 downto 0) := x"000011";
   constant C_BURST_ADDR_C : std_logic_vector(23 downto 0) := x"000012";

   constant C_READ_ADDR    : std_logic_vector(23 downto 0) := x"000010";
   constant C_READ_LEN     : natural := 5;

   signal   sim_rdback     : t_fbtest_byte_array(0 to C_READ_LEN-1);

   signal i_fb_syscon      : fb_syscon_t;

   signal i_fb_con_c2p     : fb_con_o_per_i_arr(CONTROLLER_COUNT-1 downto 0);
   signal i_fb_con_p2c     : fb_con_i_per_o_arr(CONTROLLER_COUNT-1 downto 0);

   signal i_fb_con_c2p_buf : fb_con_o_per_i_arr(CONTROLLER_COUNT-1 downto 0);
   signal i_fb_con_p2c_buf : fb_con_i_per_o_arr(CONTROLLER_COUNT-1 downto 0);

   signal i_fb_per_c2p     : fb_con_o_per_i_t;
   signal i_fb_per_p2c     : fb_con_i_per_o_t;

   signal i_fb_per_c2p1_buf: fb_con_o_per_i_t;
   signal i_fb_per_p2c1_buf: fb_con_i_per_o_t;

   signal is_A_STB_DLY     : natural := 0;

   signal r_PA_done        : boolean := false;
   signal r_PB_done        : boolean := false;
   signal r_PC_done        : boolean := false;
   signal r_READ_done      : boolean := false;


   procedure UNEXD(A : in std_logic_vector; D : in std_logic_vector; D_expect : in std_logic_vector) is
   begin
      if D /= D_expect then
         report "Unexpected data at " & to_hstring(A) & ", got " & to_hstring(D) & ", expected " & to_hstring(D_expect) severity error;
      end if;
   end procedure UNEXD;

   function ADDA(A : in std_logic_vector; I : natural) return std_logic_vector is
   begin
      return
         std_logic_vector(
            to_unsigned(
               to_integer(
                  unsigned(A)) + I, A'length));
   end function ADDA;

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
   variable v_check_data : t_fbtest_byte_array(0 to C_READ_LEN-1);
   variable I : natural;
   begin

      is_A_STB_DLY    <= 0;

      test_runner_setup(runner, runner_cfg);      

      while test_suite loop

         if run("test_order") then

            
            wait until r_READ_done;

            -- note: the priority scheme gives the same result as rr as there's a missed cyc, how to better test?
            if G_ARB_ROUND_ROBIN and not G_BURST then
               v_check_data := (x"01", x"02", x"03", x"BB", x"FD");
            elsif not G_BURST then
               v_check_data := (x"01", x"02", x"FF", x"FE", x"FD");
            else
               v_check_data := (x"01", x"99", x"FF", x"FE", x"FD");
            end if;

            for I in 0 to C_READ_LEN-1  loop
               UNEXD(
                  ADDA(C_READ_ADDR, I),
                  sim_rdback(I),
                  v_check_data(I)

                  );
            end loop;

         end if;

      end loop;

      wait for 3 us;

      test_runner_cleanup(runner); -- Simulation ends here
   end process;


   -- --------------------------------------------------------------------------
   -- Passive protocol checks on both sides of the interconnect
   -- --------------------------------------------------------------------------
   p_check:process(i_fb_syscon)
   type t_nat_arr is array (natural range <>) of natural;
   variable vr_a_acks   : t_nat_arr(0 to CONTROLLER_COUNT-1) := (others => 0);   -- A_acks passed up this cycle
   variable vr_d_acks   : t_nat_arr(0 to CONTROLLER_COUNT-1) := (others => 0);   -- D_acks passed up this cycle
   begin
      if rising_edge(i_fb_syscon.clk) and i_fb_syscon.rst = '0' then

         -- peripheral side
         if i_fb_per_c2p.A_stb = '1' then
            assert i_fb_per_c2p.cyc = '1' report "A_stb without cyc to peripheral "  severity error;
         end if;
         if i_fb_per_c2p.D_wr_stb = '1' then
            assert i_fb_per_c2p.cyc = '1' report "D_wr_stb without cyc to peripheral " severity error;
         end if;

         for k in 0 to CONTROLLER_COUNT-1 loop
            -- controller side
            if i_fb_con_c2p(k).cyc = '1' then
               assert i_fb_con_p2c(k).A_ack = '0' or i_fb_con_c2p(k).A_stb = '1' report "A_ack without A_stb controller " & integer'image(k) severity error;
               assert i_fb_con_p2c(k).D_ack = '0' or i_fb_con_p2c(k).rdy = '1' report "D_ack without rdy controller " & integer'image(k) severity error;
               if i_fb_con_p2c(k).A_ack = '1' then
                  vr_a_acks(k) := vr_a_acks(k) + 1;
               end if;
               if i_fb_con_p2c(k).D_ack = '1' then
                  vr_d_acks(k) := vr_d_acks(k) + 1;
               end if;
               assert vr_d_acks(k) <= vr_a_acks(k) report "more D_acks than A_acks controller " & integer'image(k) severity error;
            else
               assert i_fb_con_p2c(k).A_ack = '0' report "A_ack without cyc controller " & integer'image(k) severity error;
               assert i_fb_con_p2c(k).D_ack = '0' report "D_ack without cyc controller " & integer'image(k) severity error;
               vr_a_acks(k) := 0;
               vr_d_acks(k) := 0;
            end if;
         end loop;

      end if;
   end process;


   -- --------------------------------------------------------------------------
   -- Three controllers fighting for the bus, then one reads back all the data
   -- --------------------------------------------------------------------------

   
   p_A:process
   variable I:natural;
   variable v_rdback : t_fbtest_byte_array(0 to C_READ_LEN-1);
   begin
      fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p(0));
      if G_BURST then
         fbtest_multi_write(i_fb_syscon, i_fb_con_p2c(0), i_fb_con_c2p(0), C_BURST_ADDR_A, C_BURST_LEN, C_BURST_DATA_A, is_A_STB_DLY, 0, 1);
      else
         for I in 0 to C_BURST_LEN-1 loop
            fbtest_single_write(i_fb_syscon, i_fb_con_p2c(0), i_fb_con_c2p(0), ADDA(C_BURST_ADDR_A,I), C_BURST_DATA_A(I), is_A_STB_DLY, 0);
         end loop;
      end if;
         
      r_PA_done <= true;

      wait until r_PA_done and r_PB_done and r_PC_done;

      wait until rising_edge(i_fb_syscon.clk);

      fbtest_multi_read(i_fb_syscon, i_fb_con_p2c(0), i_fb_con_c2p(0), C_READ_ADDR, C_READ_LEN, v_rdback, is_A_STB_DLY, 1);
      
      sim_rdback <= v_rdback;
      r_READ_done <= true;

      wait;
   end process;

   p_B:process
   begin
      fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p(1));
      if G_BURST then
         fbtest_multi_write(i_fb_syscon, i_fb_con_p2c(1), i_fb_con_c2p(1), C_BURST_ADDR_B, C_BURST_LEN, C_BURST_DATA_B, is_A_STB_DLY, 0, 1);
      else
         for I in 0 to C_BURST_LEN-1 loop
            fbtest_single_write(i_fb_syscon, i_fb_con_p2c(1), i_fb_con_c2p(1), ADDA(C_BURST_ADDR_B,I), C_BURST_DATA_B(I), is_A_STB_DLY, 0);
         end loop;
      end if;
      
      r_PB_done <= true;

      wait;
   end process;

   p_C:process
   -- note: slow d_stb in this process
   begin
      fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p(2));
      if G_BURST then
         fbtest_multi_write(i_fb_syscon, i_fb_con_p2c(2), i_fb_con_c2p(2), C_BURST_ADDR_C, C_BURST_LEN, C_BURST_DATA_C, is_A_STB_DLY, 5, 1);
      else
         for I in 0 to C_BURST_LEN-1 loop
            fbtest_single_write(i_fb_syscon, i_fb_con_p2c(2), i_fb_con_c2p(2), ADDA(C_BURST_ADDR_C,I), C_BURST_DATA_C(I), is_A_STB_DLY, 5);
         end loop;
      end if;
      
      r_PC_done <= true;

      wait;
   end process;


   g_BUF:FOR I in 0 TO CONTROLLER_COUNT-1 GENERATE
      e_buf_con:entity work.fb_intcon_buffer
      generic map (
         G_REG_C2P   => G_CON_REG_C2P,
         G_REG_P2C   => G_CON_REG_P2C
      )
      port map (

         fb_syscon_i                => i_fb_syscon,

         fb_up_c2p_i                => i_fb_con_c2p(I),
         fb_up_p2c_o                => i_fb_con_p2c(I),

         fb_dn_c2p_o                => i_fb_con_c2p_buf(I),
         fb_dn_p2c_i                => i_fb_con_p2c_buf(I)

      );
   END GENERATE;

   e_dut:entity work.fb_intcon_many_to_one
   generic map (
      G_CONTROLLER_COUNT      => CONTROLLER_COUNT,
      G_ARB_ROUND_ROBIN       => G_ARB_ROUND_ROBIN
   )
   port map (

      fb_syscon_i                => i_fb_syscon,

      fb_up_c2p_i                => i_fb_con_c2p_buf,
      fb_up_p2c_o                => i_fb_con_p2c_buf,

      fb_dn_c2p_o                => i_fb_per_c2p,
      fb_dn_p2c_i                => i_fb_per_p2c

   );

   -- add a buffer for peripheral 1
   e_buf_per:entity work.fb_intcon_buffer
   generic map (
      G_REG_C2P   => G_PER_REG_C2P,
      G_REG_P2C   => G_PER_REG_P2C
   )
   port map (

      fb_syscon_i                => i_fb_syscon,

      fb_up_c2p_i                => i_fb_per_c2p,
      fb_up_p2c_o                => i_fb_per_p2c,

      fb_dn_c2p_o                => i_fb_per_c2p1_buf,
      fb_dn_p2c_i                => i_fb_per_p2c1_buf

   );

   e_sim_mem1:entity work.sim_fb_per_mem_pipe
   generic map (
      G_SIZE => 256,
      G_VALUE_XOR => x"A5"
      )
   port map (
      fb_syscon_i => i_fb_syscon,
      fb_c2p_i    => i_fb_per_c2p1_buf,
      fb_p2c_o    => i_fb_per_p2c1_buf,

      sim_A_ack_dly_i      => 1,
      sim_D_miss_dly_i     => 16,
      sim_D_hit_dly_i      => 0
   );


end rtl;

library vunit_lib;
context vunit_lib.vunit_context;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.fb_tester_pack.all;

-- Tests for fb_intcon_shared with two controllers and three sim memory
-- peripherals, and an fb_intcon_buffer on each controller and in front of
-- peripheral 1:
--
--   controller A -> e_buf_conA -+-> e_dut -+-> peripheral 0
--   controller B -> e_buf_conB -+          +-> e_buf_per -> peripheral 1
--                                          +-> peripheral 2
--
-- The address map, peripherals and bursts are the same as the one_to_many
-- bench:
--   0x0x_xxxx -> peripheral 0, blocking sim_fb_per_mem,
--                initial contents (A mod 256) xor FF
--   0x1x_xxxx -> peripheral 1, pipelined sim_fb_per_mem_pipe (A_ack 1,
--                miss 16, hit 0), initial contents (A mod 256) xor FF xor A5
--   otherwise -> peripheral 2, blocking sim_fb_per_mem,
--                initial contents (A mod 256) xor FF xor 5A
--
--   C_A_CROSS_01 (0x0FFFFC) 8-byte burst from peripheral 0 into 1
--   C_A_CROSS_12 (0x1FFFFC) 8-byte burst from peripheral 1 into 2
--   C_A_PAGE_1   (0x1000FC) 8-byte burst across a page inside peripheral 1
--
-- Each burst is one cyc that crosses peripherals, so it checks that the
-- interconnect re-steers within a cyc (the old fb_intcon_shared sent every
-- transaction in a cyc to the first one's peripheral) and holds the A_stb for
-- a new peripheral until the current one has returned all its D_acks.
--
-- Each controller has its own address decoder (f_dec_*), as the
-- interconnect decodes before arbitrating.
--
-- Tests:
--   single_rw, cross_read, cross_read_slow, cross_write, cross_write_slow,
--   abort: as in the one_to_many bench, run by controller A with B idle, so
--   the shared interconnect is checked as a drop-in for the one_to_many.
--   contend: A and B run crossing burst writes and read backs at the same
--   time, to disjoint locations, with and without late write data. Each
--   checks its own data, so a transaction steered to the wrong controller or
--   peripheral, or lost across a grant change, shows as a data error or a
--   hang.
--
-- run.py runs every test in each buffer setting (applied to all three
-- buffers) with G_PIPELINE_DEPTH 15 (pipelined) and 1 (not pipelined),
-- contend with both arbiters, and cross_read/cross_write also with
-- G_PIPELINE_DEPTH 2 (as G_MAXOUT 2 in the one_to_many bench).
--
-- p_check watches the controller side of each controller's buffer and the
-- peripheral side of the interconnect.

entity test_tb is
   generic (
      runner_cfg        : string;
      G_PIPELINE_DEPTH  : positive := 15;
      G_ARB_ROUND_ROBIN : boolean  := false;

      G_CON_REG_P2C     : boolean := true;
      G_CON_REG_C2P     : boolean := true;

      G_PER_REG_P2C     : boolean := true;
      G_PER_REG_C2P     : boolean := true
   );
end test_tb;

architecture rtl of test_tb is

   constant CLOCKSPEED       : natural := 128;
   constant CLOCK_PER        : time := (1000000/CLOCKSPEED) * 1 ps;

   constant CONTROLLER_COUNT : natural := 2;
   constant PERIPHERAL_COUNT : natural := 3;

   constant C_BURST_LEN      : natural := 8;

   constant C_A_CROSS_01     : std_logic_vector(23 downto 0) := x"0FFFFC";
   constant C_A_CROSS_12     : std_logic_vector(23 downto 0) := x"1FFFFC";
   constant C_A_PAGE_1       : std_logic_vector(23 downto 0) := x"1000FC";

   -- data written by the burst write tests
   constant C_BURST_DATA     : t_fbtest_byte_array(0 to C_BURST_LEN-1) :=
      (x"12", x"DE", x"AD", x"BE", x"EF", x"A5", x"B0", x"0B");

   signal i_fb_syscon        : fb_syscon_t;

   -- controllers (driven by fb_tester_pack procedures, one signal each)
   signal i_fb_conA_c2p      : fb_con_o_per_i_t;
   signal i_fb_conA_p2c      : fb_con_i_per_o_t;
   signal i_fb_conB_c2p      : fb_con_o_per_i_t;
   signal i_fb_conB_p2c      : fb_con_i_per_o_t;

   signal i_fb_con_c2p       : fb_con_o_per_i_arr(CONTROLLER_COUNT-1 downto 0);
   signal i_fb_con_p2c       : fb_con_i_per_o_arr(CONTROLLER_COUNT-1 downto 0);

   signal i_fb_con_c2p_buf   : fb_con_o_per_i_arr(CONTROLLER_COUNT-1 downto 0);
   signal i_fb_con_p2c_buf   : fb_con_i_per_o_arr(CONTROLLER_COUNT-1 downto 0);

   signal i_fb_per_c2p       : fb_con_o_per_i_arr(PERIPHERAL_COUNT-1 downto 0);
   signal i_fb_per_p2c       : fb_con_i_per_o_arr(PERIPHERAL_COUNT-1 downto 0);

   signal i_fb_per_c2p1_buf  : fb_con_o_per_i_t;
   signal i_fb_per_p2c1_buf  : fb_con_i_per_o_t;

   signal is_A_ACK_DLY       : natural := 0;
   signal is_D_WR_ACK_DLY    : natural := 0;
   signal is_D_RD_ACK_DLY    : natural := 0;

   -- controller B's run, started and finished by p_main
   signal is_b_go            : boolean := false;
   signal is_b_done          : boolean := false;

   signal i_peripheral_sel_addr_o : fb_arr_std_logic_vector(CONTROLLER_COUNT-1 downto 0)(23 downto 0);
   signal i_peripheral_sel_we_o   : std_logic_vector(CONTROLLER_COUNT-1 downto 0);
   signal i_peripheral_sel_i      : fb_arr_unsigned(CONTROLLER_COUNT-1 downto 0)(numbits(PERIPHERAL_COUNT)-1 downto 0);
   signal i_peripheral_sel_oh_i   : fb_arr_std_logic_vector(CONTROLLER_COUNT-1 downto 0)(PERIPHERAL_COUNT-1 downto 0);

   -- initial memory contents at A, following the address map above
   function f_init(A : std_logic_vector(23 downto 0)) return std_logic_vector is
   variable v_xor : std_logic_vector(7 downto 0);
   begin
      case A(23 downto 20) is
         when x"0"   => v_xor := x"00";
         when x"1"   => v_xor := x"A5";
         when others => v_xor := x"5A";
      end case;
      return A(7 downto 0) xor x"FF" xor v_xor;
   end function;

   -- address decoder, index and one-hot each written out directly
   function f_dec_ix(A : std_logic_vector(23 downto 0)) return unsigned is
   begin
      case A(23 downto 20) is
         when x"0"   => return "00";
         when x"1"   => return "01";
         when others => return "10";
      end case;
   end function;

   function f_dec_oh(A : std_logic_vector(23 downto 0)) return std_logic_vector is
   begin
      case A(23 downto 20) is
         when x"0"   => return "001";
         when x"1"   => return "010";
         when others => return "100";
      end case;
   end function;

   procedure UNEXD(A : in std_logic_vector; D : in std_logic_vector; D_expect : in std_logic_vector) is
   begin
      if D /= D_expect then
         report "Unexpected data at " & to_hstring(A) & ", got " & to_hstring(D) & ", expected " & to_hstring(D_expect) severity error;
      end if;
   end procedure UNEXD;

   procedure SINGLE_READ(
      signal syscon_i : in  fb_syscon_t;
      signal p2c_i    : in  fb_con_i_per_o_t;
      signal c2p_o    : out fb_con_o_per_i_t;
      A               : in  std_logic_vector(23 downto 0);
      D_expect        : in  std_logic_vector;
      A_stb_dl        : in  natural := 0
   ) is
   variable v_D : std_logic_vector(7 downto 0);
   begin
      fbtest_single_read(syscon_i, p2c_i, c2p_o, A, v_D, A_stb_dl);
      UNEXD(A, v_D, D_expect);
   end procedure SINGLE_READ;

   -- burst read C_BURST_LEN bytes from A and check they are the initial
   -- contents
   procedure BURST_READ(
      signal syscon_i : in  fb_syscon_t;
      signal p2c_i    : in  fb_con_i_per_o_t;
      signal c2p_o    : out fb_con_o_per_i_t;
      A               : in  std_logic_vector(23 downto 0);
      A_stb_dl        : in  natural := 0
   ) is
   variable v_A   : std_logic_vector(23 downto 0);
   variable v_arr : t_fbtest_byte_array(0 to 100);
   begin
      v_arr := (others => (others => 'U'));
      fbtest_multi_read(syscon_i, p2c_i, c2p_o, A, C_BURST_LEN, v_arr, A_stb_dl, 1);
      for i in 0 to C_BURST_LEN-1 loop
         v_A := std_logic_vector(unsigned(A) + i);
         UNEXD(v_A, v_arr(i), f_init(v_A));
      end loop;
   end procedure BURST_READ;

   -- burst write C_BURST_LEN bytes (C_BURST_DATA xor D_xor) to A, then burst
   -- read them back and check them. Use a different D_xor when a burst
   -- writes locations already written in the test, so a lost write is seen.
   procedure BURST_WRITE(
      signal syscon_i : in  fb_syscon_t;
      signal p2c_i    : in  fb_con_i_per_o_t;
      signal c2p_o    : out fb_con_o_per_i_t;
      A               : in  std_logic_vector(23 downto 0);
      D_xor           : in  std_logic_vector(7 downto 0);
      D_stb_dl        : in  natural := 0
   ) is
   variable v_A   : std_logic_vector(23 downto 0);
   variable v_arr : t_fbtest_byte_array(0 to 100);
   begin
      v_arr := (others => (others => 'U'));
      for i in 0 to C_BURST_LEN-1 loop
         v_arr(i) := C_BURST_DATA(i) xor D_xor;
      end loop;
      fbtest_multi_write(syscon_i, p2c_i, c2p_o, A, C_BURST_LEN, v_arr, 0, D_stb_dl, 1);

      v_arr := (others => (others => 'U'));
      fbtest_multi_read(syscon_i, p2c_i, c2p_o, A, C_BURST_LEN, v_arr, 0, 1);
      for i in 0 to C_BURST_LEN-1 loop
         v_A := std_logic_vector(unsigned(A) + i);
         UNEXD(v_A, v_arr(i), C_BURST_DATA(i) xor D_xor);
      end loop;
   end procedure BURST_WRITE;

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


   -- controller A, and the test sequence
   p_main:process
   variable v_completed : boolean;
   begin

      is_A_ACK_DLY    <= 0;
      is_D_WR_ACK_DLY <= 0;
      is_D_RD_ACK_DLY <= 0;

      test_runner_setup(runner, runner_cfg);

      while test_suite loop

         if run("single_rw") then

            -- single transactions to each peripheral: reads of the
            -- initial contents check the decoder routing, then a write
            -- and read back to each with a different strobe timing

            fbtest_wait_reset(i_fb_syscon, i_fb_conA_c2p);

            SINGLE_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"000000", f_init(x"000000"));
            SINGLE_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"100000", f_init(x"100000"));
            SINGLE_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"200000", f_init(x"200000"));

            -- peripheral 0: D_wr_stb 8 clocks after A_stb
            fbtest_single_write(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"000012", x"11", 0, 8);
            SINGLE_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"000012", x"11");

            -- peripheral 1: no strobe delays
            fbtest_single_write(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"100012", x"22", 0, 0);
            SINGLE_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"100012", x"22");

            -- peripheral 2: A_stb 5 clocks after cyc, for the write and the read
            fbtest_single_write(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"200012", x"33", 5, 0);
            SINGLE_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"200012", x"33", 5);

         elsif run("cross_read") then

            -- burst reads crossing into and out of the pipelined
            -- peripheral and across a page inside it, first back to back
            -- then with 3 clock gaps between the A_stbs

            fbtest_wait_reset(i_fb_syscon, i_fb_conA_c2p);

            BURST_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_CROSS_01);
            BURST_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_CROSS_12);
            BURST_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_PAGE_1);
            BURST_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_CROSS_01, 3);
            BURST_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_CROSS_12, 3);
            BURST_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_PAGE_1, 3);

         elsif run("cross_read_slow") then

            -- as cross_read with slow A_ack and slow D_ack together on
            -- the blocking peripherals

            is_A_ACK_DLY <= 4;
            is_D_RD_ACK_DLY <= 6;

            fbtest_wait_reset(i_fb_syscon, i_fb_conA_c2p);

            BURST_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_CROSS_01);
            BURST_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_CROSS_12);

         elsif run("cross_write") then

            -- burst writes crossing into and out of the pipelined
            -- peripheral and across a page inside it, first with
            -- D_wr_stb with A_stb, then with each D_wr_stb 3 clocks late

            fbtest_wait_reset(i_fb_syscon, i_fb_conA_c2p);

            BURST_WRITE(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_CROSS_01, x"00");
            BURST_WRITE(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_CROSS_12, x"00");
            BURST_WRITE(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_PAGE_1, x"55");
            BURST_WRITE(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_CROSS_01, x"FF", 3);
            BURST_WRITE(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_CROSS_12, x"FF", 3);
            BURST_WRITE(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_PAGE_1, x"AA", 3);

         elsif run("cross_write_slow") then

            -- as cross_write with slow A_ack and slow D_ack together on
            -- the blocking peripherals

            is_A_ACK_DLY <= 4;
            is_D_WR_ACK_DLY <= 5;

            fbtest_wait_reset(i_fb_syscon, i_fb_conA_c2p);

            BURST_WRITE(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_CROSS_01, x"00");
            BURST_WRITE(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_CROSS_12, x"00");

         elsif run("abort") then

            -- drop cyc part way through a transaction in three
            -- different states; after each check the interconnect has
            -- recovered by reading from two peripherals

            fbtest_wait_reset(i_fb_syscon, i_fb_conA_c2p);

            -- 1. read: peripheral 0 is delaying A_ack
            is_A_ACK_DLY <= 10;
            fbtest_abort(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"000010", '0', x"00", 3, v_completed);
            assert not v_completed report "abort 1: aborted read completed" severity error;
            is_A_ACK_DLY <= 0;

            SINGLE_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"000010", f_init(x"000010"));
            SINGLE_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"100010", f_init(x"100010"));

            -- 2. read: peripheral 1 has A_ack'd and is in its miss delay
            fbtest_abort(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"100010", '0', x"00", 5, v_completed);
            assert not v_completed report "abort 2: aborted read completed" severity error;

            SINGLE_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"100010", f_init(x"100010"));
            SINGLE_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"200010", f_init(x"200010"));

            -- 3. write: peripheral 1 has A_ack'd and queued the write and
            -- is in its miss delay; the write must not happen
            fbtest_abort(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"100020", '1', x"77", 5, v_completed);
            assert not v_completed report "abort 3: aborted write completed" severity error;

            SINGLE_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"100020", f_init(x"100020"));
            SINGLE_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"000020", f_init(x"000020"));

         elsif run("contend") then

            -- A and B at the same time (B's part is in p_conB). A writes
            -- C_A_CROSS_01 (peripheral 0 FC-FF, peripheral 1 00-03) and B
            -- writes C_A_CROSS_12 (peripheral 1 FC-FF, peripheral 2 00-03),
            -- so the locations are disjoint. Each also reads an unwritten
            -- location in a peripheral the other is writing to.

            fbtest_wait_reset(i_fb_syscon, i_fb_conA_c2p);

            is_b_go <= true;

            BURST_WRITE(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_CROSS_01, x"C3");
            BURST_WRITE(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_CROSS_01, x"69", 3);
            SINGLE_READ(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, x"200040", f_init(x"200040"));
            BURST_WRITE(i_fb_syscon, i_fb_conA_p2c, i_fb_conA_c2p, C_A_CROSS_01, x"0F");

            if not is_b_done then
               wait until is_b_done for 100 us;
            end if;
            assert is_b_done report "contend: controller B did not finish" severity error;
            is_b_go <= false;

         end if;


      end loop;

      wait for 3 us;

      test_runner_cleanup(runner); -- Simulation ends here
   end process;


   -- controller B: idle except in the contend test
   p_conB:process
   begin
      fbtest_wait_reset(i_fb_syscon, i_fb_conB_c2p);
      loop
         wait until is_b_go;

         BURST_WRITE(i_fb_syscon, i_fb_conB_p2c, i_fb_conB_c2p, C_A_CROSS_12, x"3C", 3);
         BURST_WRITE(i_fb_syscon, i_fb_conB_p2c, i_fb_conB_c2p, C_A_CROSS_12, x"96");
         SINGLE_READ(i_fb_syscon, i_fb_conB_p2c, i_fb_conB_c2p, x"000040", f_init(x"000040"));
         BURST_WRITE(i_fb_syscon, i_fb_conB_p2c, i_fb_conB_c2p, C_A_CROSS_12, x"F0", 3);

         is_b_done <= true;
         wait until not is_b_go;
         is_b_done <= false;
      end loop;
   end process;


   i_fb_con_c2p(0) <= i_fb_conA_c2p;
   i_fb_con_c2p(1) <= i_fb_conB_c2p;
   i_fb_conA_p2c   <= i_fb_con_p2c(0);
   i_fb_conB_p2c   <= i_fb_con_p2c(1);


   -- --------------------------------------------------------------------------
   -- Passive protocol checks on both sides of the interconnect
   -- --------------------------------------------------------------------------
   p_check:process(i_fb_syscon)
   type t_nat_arr is array (natural range <>) of natural;

   variable v_n_a_stb     : natural;
   variable v_n_up_ack    : natural;
   variable vr_a_acks     : t_nat_arr(0 to CONTROLLER_COUNT-1) := (others => 0);   -- A_acks to each controller this cycle
   variable vr_d_acks     : t_nat_arr(0 to CONTROLLER_COUNT-1) := (others => 0);   -- D_acks to each controller this cycle

   -- per-peripheral: D_acks never exceed A_acks in a cycle, and at most one
   -- peripheral D_acks in any clock
   variable vr_per_a_acks : t_nat_arr(0 to PERIPHERAL_COUNT-1) := (others => 0);
   variable vr_per_d_acks : t_nat_arr(0 to PERIPHERAL_COUNT-1) := (others => 0);
   variable v_n_d_ack     : natural;
   begin
      if rising_edge(i_fb_syscon.clk) and i_fb_syscon.rst = '0' then

         -- peripheral side
         v_n_a_stb := 0;
         for k in 0 to PERIPHERAL_COUNT-1 loop
            if i_fb_per_c2p(k).A_stb = '1' then
               v_n_a_stb := v_n_a_stb + 1;
               assert i_fb_per_c2p(k).cyc = '1' report "A_stb without cyc to peripheral " & integer'image(k) severity error;
            end if;
            if i_fb_per_c2p(k).D_wr_stb = '1' then
               assert i_fb_per_c2p(k).cyc = '1' report "D_wr_stb without cyc to peripheral " & integer'image(k) severity error;
            end if;
         end loop;
         assert v_n_a_stb <= 1 report "A_stb to more than one peripheral" severity error;

         v_n_d_ack := 0;
         for k in 0 to PERIPHERAL_COUNT-1 loop
            if i_fb_per_c2p(k).cyc = '1' then
               if i_fb_per_p2c(k).A_ack = '1' then
                  vr_per_a_acks(k) := vr_per_a_acks(k) + 1;
               end if;
               if i_fb_per_p2c(k).D_ack = '1' then
                  vr_per_d_acks(k) := vr_per_d_acks(k) + 1;
                  v_n_d_ack := v_n_d_ack + 1;
               end if;
               assert vr_per_d_acks(k) <= vr_per_a_acks(k)
                  report "peripheral " & integer'image(k) & " D_ack without a matching A_ack" severity error;
            else
               vr_per_a_acks(k) := 0;
               vr_per_d_acks(k) := 0;
            end if;
         end loop;
         assert v_n_d_ack <= 1 report "D_ack from more than one peripheral" severity error;

         -- interconnect's controller ports: acks only ever to one controller
         -- in a clock
         v_n_up_ack := 0;
         for c in 0 to CONTROLLER_COUNT-1 loop
            if i_fb_con_p2c_buf(c).A_ack = '1' or i_fb_con_p2c_buf(c).D_ack = '1' then
               v_n_up_ack := v_n_up_ack + 1;
            end if;
         end loop;
         assert v_n_up_ack <= 1 report "acks to more than one controller in a clock" severity error;

         -- controller side, each controller
         for c in 0 to CONTROLLER_COUNT-1 loop
            if i_fb_con_c2p(c).cyc = '1' then
               assert i_fb_con_p2c(c).A_ack = '0' or i_fb_con_c2p(c).A_stb = '1'
                  report "A_ack without A_stb, controller " & integer'image(c) severity error;
               assert i_fb_con_p2c(c).D_ack = '0' or i_fb_con_p2c(c).rdy = '1'
                  report "D_ack without rdy, controller " & integer'image(c) severity error;
               if i_fb_con_p2c(c).A_ack = '1' then
                  vr_a_acks(c) := vr_a_acks(c) + 1;
               end if;
               if i_fb_con_p2c(c).D_ack = '1' then
                  vr_d_acks(c) := vr_d_acks(c) + 1;
               end if;
               assert vr_d_acks(c) <= vr_a_acks(c)
                  report "more D_acks than A_acks, controller " & integer'image(c) severity error;
            else
               assert i_fb_con_p2c(c).A_ack = '0'
                  report "A_ack without cyc, controller " & integer'image(c) severity error;
               assert i_fb_con_p2c(c).D_ack = '0'
                  report "D_ack without cyc, controller " & integer'image(c) severity error;
               vr_a_acks(c) := 0;
               vr_d_acks(c) := 0;
            end if;
         end loop;

      end if;
   end process;

   g_buf_con:for c in 0 to CONTROLLER_COUNT-1 generate
      e_buf_con:entity work.fb_intcon_buffer
      generic map (
         G_REG_C2P   => G_CON_REG_C2P,
         G_REG_P2C   => G_CON_REG_P2C
      )
      port map (
         fb_syscon_i                => i_fb_syscon,

         fb_up_c2p_i                => i_fb_con_c2p(c),
         fb_up_p2c_o                => i_fb_con_p2c(c),

         fb_dn_c2p_o                => i_fb_con_c2p_buf(c),
         fb_dn_p2c_i                => i_fb_con_p2c_buf(c)
      );
   end generate;

   e_dut:entity work.fb_intcon_shared
   generic map (
      G_CONTROLLER_COUNT      => CONTROLLER_COUNT,
      G_PERIPHERAL_COUNT      => PERIPHERAL_COUNT,
      G_ARB_ROUND_ROBIN       => G_ARB_ROUND_ROBIN,
      G_PIPELINE_DEPTH        => G_PIPELINE_DEPTH
   )
   port map (
      fb_syscon_i                => i_fb_syscon,

      fb_up_c2p_i                => i_fb_con_c2p_buf,
      fb_up_p2c_o                => i_fb_con_p2c_buf,

      fb_dn_c2p_o                => i_fb_per_c2p,
      fb_dn_p2c_i                => i_fb_per_p2c,

      peripheral_sel_addr_o      => i_peripheral_sel_addr_o,
      peripheral_sel_we_o        => i_peripheral_sel_we_o,
      peripheral_sel_i           => i_peripheral_sel_i,
      peripheral_sel_oh_i        => i_peripheral_sel_oh_i
   );

   -- one address decoder per controller
   g_dec:for c in 0 to CONTROLLER_COUNT-1 generate
      i_peripheral_sel_i(c)    <= f_dec_ix(i_peripheral_sel_addr_o(c));
      i_peripheral_sel_oh_i(c) <= f_dec_oh(i_peripheral_sel_addr_o(c));
   end generate;

   e_sim_mem0:entity work.sim_fb_per_mem
   generic map (
      G_SIZE => 256,
      G_VALUE_XOR => x"00"
      )
   port map (
      fb_syscon_i => i_fb_syscon,
      fb_c2p_i    => i_fb_per_c2p(0),
      fb_p2c_o    => i_fb_per_p2c(0),

      sim_A_ack_dly_i      => is_A_ACK_DLY,
      sim_D_wr_ack_dly_i   => is_D_WR_ACK_DLY,
      sim_D_rd_ack_dly_i   => is_D_RD_ACK_DLY
   );

   -- buffer in front of peripheral 1
   e_buf_per:entity work.fb_intcon_buffer
   generic map (
      G_REG_C2P   => G_PER_REG_C2P,
      G_REG_P2C   => G_PER_REG_P2C
   )
   port map (
      fb_syscon_i                => i_fb_syscon,

      fb_up_c2p_i                => i_fb_per_c2p(1),
      fb_up_p2c_o                => i_fb_per_p2c(1),

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

   e_sim_mem2:entity work.sim_fb_per_mem
   generic map (
      G_SIZE => 256,
      G_VALUE_XOR => x"5A"
      )
   port map (
      fb_syscon_i => i_fb_syscon,
      fb_c2p_i    => i_fb_per_c2p(2),
      fb_p2c_o    => i_fb_per_p2c(2),

      sim_A_ack_dly_i      => is_A_ACK_DLY,
      sim_D_wr_ack_dly_i   => is_D_WR_ACK_DLY,
      sim_D_rd_ack_dly_i   => is_D_RD_ACK_DLY
   );

end rtl;

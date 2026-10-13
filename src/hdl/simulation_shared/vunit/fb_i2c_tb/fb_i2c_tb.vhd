-- fb_i2c test bench
--
-- A go/no-go check of fb_i2c through its Fishbone registers. Two I2C
-- transactions, as a driver would do them:
--   write: START, address+W, C_WR_DATA (each byte ACK'd by the model), STOP
--   read:  START, address+R, C_RD_DATA read back (ACK'd by fb_i2c except the
--          last, which is NACK'd), STOP
--
-- The software side polls STAT.BUSY like a real driver. p_model is a minimal
-- I2C peripheral at address C_ADDR: it checks the address and the written
-- bytes, sends C_RD_DATA for a read, and counts STOPs.
--
-- Not covered (later): clock stretching, repeated START, a NACK'd write or
-- wrong address, CTL BUSY=0 (stop/cancel), dropping cyc.

library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.fb_tester_pack.all;

entity fb_i2c_tb is
   generic (runner_cfg : string);
end fb_i2c_tb;

architecture rtl of fb_i2c_tb is

   constant CLOCKSPEED : natural := 128;
   constant CLOCK_PER  : time := (1000000/CLOCKSPEED) * 1 ps;

   constant A_STAT     : std_logic_vector(23 downto 0) := x"000000";   -- read STAT / write CTL
   constant A_DAT      : std_logic_vector(23 downto 0) := x"000001";

   -- CTL values
   constant C_CTL_WR_START    : std_logic_vector(7 downto 0) := x"82";  -- BUSY, START, write
   constant C_CTL_WR          : std_logic_vector(7 downto 0) := x"80";  -- BUSY, write
   constant C_CTL_WR_STOP     : std_logic_vector(7 downto 0) := x"84";  -- BUSY, write, STOP
   constant C_CTL_RD_ACK      : std_logic_vector(7 downto 0) := x"81";  -- BUSY, read, ACK it
   constant C_CTL_RD_NAK_STOP : std_logic_vector(7 downto 0) := x"C5";  -- BUSY, read, NACK it, STOP

   constant C_ADDR     : std_logic_vector(6 downto 0) := "1010000";      -- 0x50, e.g. an EEPROM
   constant C_WR_DATA  : t_fbtest_byte_array(0 to 1) := (x"12", x"34");
   constant C_RD_DATA  : t_fbtest_byte_array(0 to 2) := (x"48", x"49", x"21");   -- "HI!"

   signal i_fb_syscon  : fb_syscon_t;
   signal i_fb_con_c2p : fb_con_o_per_i_t;
   signal i_fb_con_p2c : fb_con_i_per_o_t;

   signal i_I2C_SCL    : std_logic;
   signal i_I2C_SDA    : std_logic;

   signal i_stop_count : natural := 0;

   -- SDA/SCL can read as 'H' (pull-up), so compare as X01
   procedure CHECKD(D : in std_logic_vector; D_expect : in std_logic_vector; what : in string) is
   begin
      if to_X01(D) /= D_expect then
         report what & ": got " & to_hstring(to_X01(D)) & ", expected " & to_hstring(D_expect) severity error;
      end if;
   end procedure CHECKD;

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

   test_runner_watchdog(runner, 5 ms);

   p_main:process
   variable v_d    : std_logic_vector(7 downto 0);
   variable v_stat : std_logic_vector(7 downto 0);

   -- poll STAT until BUSY is clear, return STAT
   procedure wait_not_busy(variable stat : out std_logic_vector(7 downto 0)) is
   variable v_s : std_logic_vector(7 downto 0);
   begin
      for i in 1 to 100000 loop
         fbtest_single_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, A_STAT, v_s);
         v_s := to_X01(v_s);
         if v_s(7) = '0' then
            stat := v_s;
            return;
         end if;
      end loop;
      report "Timed out waiting for BUSY to clear" severity failure;
   end procedure;

   -- write a byte to the bus with the given CTL, check it was ACK'd
   procedure write_byte(D : in std_logic_vector(7 downto 0); ctl : in std_logic_vector(7 downto 0); what : in string) is
   variable v_s : std_logic_vector(7 downto 0);
   begin
      fbtest_single_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, A_DAT, D);
      fbtest_single_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, A_STAT, ctl);
      wait_not_busy(v_s);
      assert v_s(6) = '0' report what & " not ACK'd" severity error;
      wait for 5 us;
   end procedure;

   begin

      test_runner_setup(runner, runner_cfg);

      while test_suite loop

         if run("write_read") then

            fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

            -- write transaction
            write_byte(C_ADDR & '0', C_CTL_WR_START, "Write address");
            for i in C_WR_DATA'range loop
               if i = C_WR_DATA'high then
                  write_byte(C_WR_DATA(i), C_CTL_WR_STOP, "Write byte " & integer'image(i));
               else
                  write_byte(C_WR_DATA(i), C_CTL_WR, "Write byte " & integer'image(i));
               end if;
            end loop;

            wait for 10 us;
            assert i_stop_count = 1 report "No STOP after the write" severity error;

            -- read transaction
            write_byte(C_ADDR & '1', C_CTL_WR_START, "Read address");
            for i in C_RD_DATA'range loop
               if i = C_RD_DATA'high then
                  fbtest_single_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, A_STAT, C_CTL_RD_NAK_STOP);
               else
                  fbtest_single_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, A_STAT, C_CTL_RD_ACK);
               end if;
               wait_not_busy(v_stat);
               fbtest_single_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, A_DAT, v_d);
               CHECKD(v_d, C_RD_DATA(i), "Read byte " & integer'image(i));
               wait for 5 us;
            end loop;

            wait for 10 us;
            assert i_stop_count = 2 report "No STOP after the read" severity error;
            assert to_X01(i_I2C_SCL) = '1' and to_X01(i_I2C_SDA) = '1'
               report "Bus not released after STOP" severity error;

         end if;

      end loop;

      wait for 3 us;

      test_runner_cleanup(runner); -- Simulation ends here
   end process;

   e_dut:entity work.fb_i2c
   generic map (
      SIM                           => true,
      CLOCKSPEED                    => CLOCKSPEED
   )
   port map (
      I2C_SCL_io                    => i_I2C_SCL,
      I2C_SDA_io                    => i_I2C_SDA,

      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_i                      => i_fb_con_c2p,
      fb_p2c_o                      => i_fb_con_p2c
   );

   -- pull-ups
   i_I2C_SCL <= 'H';
   i_I2C_SDA <= 'H';

   -- minimal I2C peripheral, see header
   p_model:process
   variable v_d  : std_logic_vector(7 downto 0);
   variable v_ack: std_logic;
   variable v_n  : natural;

   -- receive a byte (called after START or the previous byte's 9th clock)
   -- then ACK it
   procedure rx_byte_ack(variable d : out std_logic_vector(7 downto 0)) is
   begin
      for i in 7 downto 0 loop
         wait until rising_edge(i_I2C_SCL);
         d(i) := to_X01(i_I2C_SDA);
      end loop;
      wait until falling_edge(i_I2C_SCL);
      i_I2C_SDA <= '0';                   -- ACK
      wait until falling_edge(i_I2C_SCL);
      i_I2C_SDA <= 'Z';
   end procedure;

   begin
      i_I2C_SDA <= 'Z';

      loop
         -- START: SDA falls while SCL is high
         wait until falling_edge(i_I2C_SDA) and to_X01(i_I2C_SCL) = '1';
         report "model: START";

         rx_byte_ack(v_d);
         report "model: address byte 0x" & to_hstring(v_d);
         CHECKD(v_d(7 downto 1), C_ADDR, "Model address");

         if v_d(0) = '0' then
            -- write: receive and check the data bytes
            for b in C_WR_DATA'range loop
               rx_byte_ack(v_d);
               report "model: got 0x" & to_hstring(v_d);
               CHECKD(v_d, C_WR_DATA(b), "Model received byte " & integer'image(b));
            end loop;
         else
            -- read: send bytes until the controller NACKs
            v_n := 0;
            for b in C_RD_DATA'range loop
               for i in 7 downto 0 loop
                  if C_RD_DATA(b)(i) = '0' then
                     i_I2C_SDA <= '0';
                  else
                     i_I2C_SDA <= 'Z';
                  end if;
                  wait until falling_edge(i_I2C_SCL);
               end loop;
               i_I2C_SDA <= 'Z';
               wait until rising_edge(i_I2C_SCL);
               v_ack := to_X01(i_I2C_SDA);
               wait until falling_edge(i_I2C_SCL);
               v_n := v_n + 1;
               exit when v_ack = '1';
            end loop;
            assert v_n = C_RD_DATA'length and v_ack = '1'
               report "model: expected NACK on the last read byte only, NACK'd byte " & integer'image(v_n) severity error;
         end if;

         -- STOP: SDA rises while SCL is high
         wait until rising_edge(i_I2C_SDA) and to_X01(i_I2C_SCL) = '1';
         report "model: STOP";
         i_stop_count <= i_stop_count + 1;
      end loop;
   end process;

end rtl;

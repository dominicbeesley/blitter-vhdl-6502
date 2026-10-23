library vunit_lib;
context vunit_lib.vunit_context;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.fb_tester_pack.all;

entity test_tb is
   generic (runner_cfg : string);
end test_tb;

architecture rtl of test_tb is

   constant CLOCKSPEED : natural := 128;
   constant CLOCK_PER : time := (1000000/CLOCKSPEED) * 1 ps;

   signal i_CPHA : std_logic;
   signal i_CPOL : std_logic;

   signal i_fb_syscon : fb_syscon_t;
   signal i_fb_con_c2p : fb_con_o_per_i_t;
   signal i_fb_con_p2c : fb_con_i_per_o_t;

   signal i_SPI_CS   : std_logic_vector(7 downto 0);
   signal i_SPI_CLK  : std_logic;
   signal i_SPI_MOSI : std_logic;
   signal i_SPI_MISO : std_logic;
   signal i_SPI_DET  : std_logic;

   constant MAX_STR_LEN : positive := 16;
   signal   test_string_ix : positive := 1;
   signal   test_string_rd : string(1 to MAX_STR_LEN);

   procedure assign_string(signal sret: out string; s:string) is
   variable l : integer := s'length;
   begin
      sret <= (1 to MAX_STR_LEN => character'val(16#FF#));
      if l > 0 then
         if l > MAX_STR_LEN then
            l := MAX_STR_LEN;
         end if;
         sret(1 to l) <= s;
      end if;
   end procedure;

   procedure monitor(
      lbl :string;
      signal cs: in std_logic;
      signal clk: in std_logic;
      signal data : in std_logic
      ) is
   variable i : integer;
   variable d : std_logic_vector(7 downto 0);
   begin
      
      l_outer: loop
         if cs /= '0' then
            wait until cs = '0';
         end if;

         for i in 1 to 8 loop
            if (i_CPOL xor i_CPHA) = '0' then
               wait until rising_edge(clk) or cs = '1';
            else
               wait until falling_edge(clk) or cs = '1';
            end if;

            if cs = '1' then
               if i > 1 then
                  report lbl & " finished early";
               end if;
               next l_outer;
            end if;

            d := d(6 downto 0) & data;
         end loop;

         report lbl & " got 0x" & to_hstring(unsigned(d));

      end loop;   

   end procedure;


   procedure CHECKD(D : in std_logic_vector; D_expect : in std_logic_vector) is
   begin
      if D /= D_expect then
         report "Unexpected data got " & to_hstring(D) & ", expected " & to_hstring(D_expect) severity error;
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


   p_main:process
   variable v_time:time;
   variable D : std_logic_vector(7 downto 0);

   procedure WAITB is
   variable I : integer;
   begin
      i := 0;
      while true loop
         fbtest_single_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000000", D);
         assert i < 10000 report "Timed out waiting for busy" severity error;
         if D(7) = '0' then 
            exit;
         end if;
         i := i + 1;
      end loop;
   end procedure;

   begin

      test_runner_setup(runner, runner_cfg);

      while test_suite loop

         if run("general") then

            i_CPOL <= '0';
            i_CPHA <= '0';
            assign_string(test_string_rd, "HELLO THERE");

            fbtest_wait_reset(i_fb_syscon, i_fb_con_c2p);

            -- control            
            fbtest_single_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000000", x"00");
            -- divisor
            fbtest_single_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000001", x"28");

            fbtest_single_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000003", x"A5");
            wait for 20 us;
            -- late D_wr_stb: checks act_wr waits for data
            fbtest_single_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000002", x"5A", D_stb_dl_i => 3);
            wait for 20 us;
            fbtest_single_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000003", x"FF");
            wait for 20 us;

            WAITB;
            fbtest_single_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000003", D);
            CHECKD(D, x"4C");

            wait for 20 us;

            WAITB;
            fbtest_single_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000003", D);
            CHECKD(D, x"4C");

            wait for 20 us;

            WAITB;
            -- note read from reg 2 - don't start another transfer
            fbtest_single_read(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000002", D);
            CHECKD(D, x"4F");
            wait for 10 us;
            
            -- control, rewrite to clear nCS
            fbtest_single_write(i_fb_syscon, i_fb_con_p2c, i_fb_con_c2p, x"000000", x"00");

            wait for 10 us;

            assert i_SPI_CS = "11111111" report "CS not dropped" severity error;
         
         end if;

      end loop;

      wait for 3 us;

      test_runner_cleanup(runner); -- Simulation ends here
   end process;

   e_dut:entity work.fb_spi
   generic map (
      SIM                           => true,
      CLOCKSPEED                    => CLOCKSPEED
   )
   port map (

      fb_syscon_i                   => i_fb_syscon,
      fb_c2p_i                      => i_fb_con_c2p,
      fb_p2c_o                      => i_fb_con_p2c,

      SPI_CS_o                      => i_SPI_CS,
      SPI_CLK_o                     => i_SPI_CLK,
      SPI_MOSI_o                    => i_SPI_MOSI,
      SPI_MISO_i                    => i_SPI_MISO,
      SPI_DET_i                     => i_SPI_DET

   );


   p_test_string_rd:process
   variable i : integer;
   variable d : std_logic_vector(7 downto 0);
   begin

      if i_SPI_CS(0) /= '0' then
         wait until i_SPI_CS(0) = '0';
      end if;

      if test_string_ix > MAX_STR_LEN then
         d := x"FF";
      else
         d := std_logic_vector(to_unsigned(character'pos(test_string_rd(test_string_ix)), 8));
      end if;

      for i in 0 to 7 loop

         wait for 4 ns;

         i_SPI_MISO <= d(7);
         d := d(6 downto 0) & '1';

         wait until i_SPI_CLK = '1' or i_SPI_CS(0) = '1';
         if i_SPI_CS(0) = '1' then 
            exit;
         end if;

         if i = 0 then
            test_string_ix <= test_string_ix + 1;
         end if;

         wait until i_SPI_CLK = '0' or i_SPI_CS(0) = '1';
         if i_SPI_CS(0) = '1' then 
            exit;
         end if;

      end loop;

   end process;

   p_mon_mosi:process
   begin
      monitor("MOSI", i_SPI_CS(0), i_SPI_CLK, i_SPI_MOSI);
   end process;

   p_mon_miso:process
   begin
      monitor("MISO", i_SPI_CS(0), i_SPI_CLK, i_SPI_MISO);
   end process;


end rtl;

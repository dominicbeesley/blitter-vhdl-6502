library vunit_lib;
context vunit_lib.vunit_context;

-- test periphs_csel 


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use std.textio.all;

library fmf;

library work;

entity test_tb is
   generic (
      runner_cfg : string
      );
end test_tb;

architecture rtl of test_tb is

   signal i_clk_128     : std_logic;
   signal i_clk_2_int   : std_logic;

   signal i_SYS_A       : std_logic_vector(15 downto 0);
   signal i_SYS_D_rd    : std_logic_vector(7 downto 0);
   signal i_SYS_D_wr    : std_logic_vector(7 downto 0);
   signal i_SYS_RnW     : std_logic;

   signal i_bbc_slow_cyc: std_logic;


   signal i_clk_2MHzE   : std_logic;
   signal i_clk_1MHzE   : std_logic;
   signal i_MIO         : std_logic_vector(7 downto 0);

   signal i_MIO_nALE    : std_logic;
   signal i_MIO_D_nOE   : std_logic;
   signal i_MIO_I0_nOE  : std_logic;
   signal i_MIO_I1_nOE  : std_logic;
   signal i_MIO_O0_nOE  : std_logic;
   signal i_MIO_O1_nOE  : std_logic;

   signal i_MIO_nALE2   : std_logic;
   signal i_MIO_D_nOE2  : std_logic;
   signal i_MIO_O0_nOE2 : std_logic;
   signal i_MIO_O1_nOE2 : std_logic;

   signal i_MIO_O0      : std_logic_vector(7 downto 0);
   signal i_MIO_O1      : std_logic_vector(7 downto 0);

   -- O0 signals
   signal i_MIO_nCS     : std_logic_vector(3 downto 0);
   signal i_SYS_nRST    : std_logic := '1';
   signal i_SER_TX      : std_logic := '0';
   signal i_SER_RTS     : std_logic := '0';

   -- O1 signals
   signal i_J_SPI_CLK   : std_logic := '1';
   signal i_J_SPI_MOSI  : std_logic := '1';
   signal i_J_ADC_CS    : std_logic := '1';
   signal i_VID_HS      : std_logic := '1';
   signal i_VID_VS      : std_logic := '1';
   signal i_VID_CS      : std_logic := '1';
   signal i_J_DS1_CS    : std_logic := '1';
   signal i_J_DS2_CS    : std_logic := '1';

   signal i_sync_cyc    : std_logic;
   signal i_sync_cyc_A  : std_logic;


   -- test signals back out of peripherals

   signal i_test_VID_CS : std_logic;
   signal i_test_VID_HS : std_logic;
   signal i_test_VID_VS : std_logic;

begin

   p_clk_128:process
   begin
      i_clk_128 <= '0';
      wait for 0.5 us / 128;
      i_clk_128 <= '1';
      wait for 0.5 us / 128;
   end process;


   p_clk_2_int:process
   variable I : natural;
   begin
      i_clk_2_int <= '0';
      i_sync_cyc  <= '1';
      wait until rising_edge(i_clk_128);
      i_sync_cyc  <= '0';
      for I in 0 to 30 loop
         wait until rising_edge(i_clk_128);
      end loop;
      i_clk_2_int <= '1';
      for I in 0 to 31 loop
         wait until rising_edge(i_clk_128);
      end loop;
   end process;

   -- TODO: this doesn't test clock stretching
   p_clk_2e:process
   begin
      i_clk_2MHzE <= '0';
      wait for 80 ns;        
      if i_bbc_slow_cyc = '1' then
         if i_clk_1MHzE = '1' then
            wait until rising_edge(i_clk_2_int);
            wait until falling_edge(i_clk_2_int);
            wait until rising_edge(i_clk_2_int);
            i_clk_2MHzE <= '1';
            wait until falling_edge(i_clk_2_int);
            wait until rising_edge(i_clk_2_int);
            wait until falling_edge(i_clk_2_int);
         else
            wait until rising_edge(i_clk_2_int);
            i_clk_2MHzE <= '1';
            wait until falling_edge(i_clk_2_int);
            wait until rising_edge(i_clk_2_int);
            wait until falling_edge(i_clk_2_int);
         end if;
      else
         wait until rising_edge(i_clk_2_int);
         i_clk_2MHzE <= '1';
         wait until falling_edge(i_clk_2_int);
      end if;
   end process;

   p_clk_1e:process
   begin
      i_clk_1MHzE <= '0';
      wait until falling_edge(i_clk_2_int);
      i_clk_1MHzE <= '1';
      wait until falling_edge(i_clk_2_int);
   end process;

   p_timeslice:process(i_clk_128)
   variable i_ctr: unsigned(7 downto 0);
   begin
      if rising_edge(i_clk_128) then
         if i_sync_cyc = '1' then
            i_ctr := (others => '0');
         else

            -- latch/multiplex enables to peripherals module
            i_MIO_nALE     <= '1';
            i_MIO_D_nOE    <= '1';
            i_MIO_I0_nOE   <= '1';
            i_MIO_I1_nOE   <= '1';
            i_MIO_O0_nOE   <= '1';
            i_MIO_O1_nOE   <= '1';

            case to_integer(i_ctr) is
               when 0 to 1 =>       i_MIO_D_nOE  <= '0';      -- data hold from previous
               when 9 =>            i_MIO_nALE   <= '0';      -- address latch
               when 13 =>           i_MIO_O0_nOE <= '0';      -- chipsel / early out
               when 16|17|18 =>     i_MIO_I0_nOE <= '0';      -- early inputs
               when 21 =>           i_MIO_O1_nOE <= '0';      -- vid syncs / late out
               when 24|25|26 =>     i_MIO_I1_nOE <= '0';      -- late inputs
               
               when 45 to (2**i_ctr'high) -1  => 
                                    i_MIO_D_nOE  <= '0';      -- data setup

               when others => null;
            end case;

            -- local data multiplex 
            i_MIO_nALE2    <= '1';
            i_MIO_D_nOE2   <= '1';
            i_MIO_O0_nOE2  <= '1';
            i_MIO_O1_nOE2  <= '1';

            case to_integer(i_ctr) is
               when 0 to 1 =>       i_MIO_D_nOE2 <= '0';      -- data hold from previous
               when 8 to 10 =>      i_MIO_nALE2  <= '0';      -- address latch
               when 12 to 14 =>     i_MIO_O0_nOE2<= '0';      -- chipsel / early out
               when 20 to 22 =>     i_MIO_O1_nOE2<= '0';      -- vid syncs / late out
               
               when 45 to (2**i_ctr'high) -1  => 
                                    i_MIO_D_nOE2 <= '0';      -- data setup

               when others => null;
            end case;

            if i_ctr = 7 then 
               i_sync_cyc_A <= '1';
            else 
               i_sync_cyc_A <= '0';
            end if;

            i_ctr := i_ctr + 1;

         end if;

      end if;

   end process;

   i_MIO_nCS <= "1010"  when i_SYS_A(15 downto 8) = x"FC" else        -- PGFC -- TODO: local holes
                "1011"  when i_SYS_A(15 downto 8) = x"FD" else        -- PGFD -- TODO: local holes/jim paging reg
                "1100"  when i_SYS_A(15 downto 5) & "0" = x"FEE" else -- TUBE
                "1101"  when i_SYS_A(15 downto 5) & "0" = x"FEA" else -- ADLC
                "0110"  when i_SYS_A(15 downto 5) & "0" = x"FE8" and i_SYS_A(2) = '1' else -- FDC
                "0111"  when i_SYS_A(15 downto 5) & "0" = x"FE8" and i_SYS_A(2) = '0' and i_SYS_RnW = '0' else -- FDCON
                "1001"  when i_SYS_A(15 downto 5) & "0" = x"FE6" else -- VIAB
                "0100"  when i_SYS_A(15 downto 0)       = x"FE41" and i_SYS_RnW = '0' else -- KBPAWR
                "0100"  when i_SYS_A(15 downto 0)       = x"FE4F" and i_SYS_RnW = '0' else -- KBPAWR
                "0101"  when i_SYS_A(15 downto 0)       = x"FE40" and i_SYS_RnW = '0' else -- IC32WR
                "0000";

   i_MIO_O0 <= (
         3 downto 0 => i_MIO_nCS,
         4 => i_SYS_RnW,
         5 => i_SYS_nRST,
         6 => i_SER_TX,
         7 => i_SER_RTS
      );

   i_MIO_O1 <= i_J_SPI_CLK & i_J_SPI_MOSI & i_J_ADC_CS & i_VID_HS & i_VID_VS & i_VID_CS & i_J_DS1_CS & i_J_DS2_CS;

   i_MIO <= i_SYS_A(7 downto 0) when i_MIO_nALE2 = '0' else
            i_MIO_O0 when i_MIO_O0_nOE2 = '0' else
            i_MIO_O1 when i_MIO_O1_nOE2 = '0' else
            i_SYS_D_wr when i_MIO_D_nOE2 = '0' and i_SYS_RnW = '0' else
            (others => 'Z');


   p_main:process
      variable I:natural;

      procedure CYC_R(
         A : in  std_logic_vector(15 downto 0)     
         ) is
      begin
         wait until i_sync_cyc_A = '1';
         i_SYS_A <= A;
         i_SYS_RnW <= '1';
         wait until falling_edge(i_clk_2MHzE);
      end procedure;

      procedure CYC_W(
         A : in  std_logic_vector(15 downto 0);         
         D : in  std_logic_vector(7 downto 0)
         ) is
      begin
         wait until i_sync_cyc_A = '1';
         i_SYS_A <= A;
         i_SYS_RnW <= '0';
         i_SYS_D_wr <= D;
         wait until falling_edge(i_clk_2MHzE);
      end procedure;

   begin

      test_runner_setup(runner, runner_cfg);


      while test_suite loop

         if run("test") then

            wait until falling_edge(i_clk_2MHzE);
            wait until falling_edge(i_clk_2MHzE);
            wait until falling_edge(i_clk_2MHzE);

            CYC_R(x"FFEA");
            CYC_R(x"FFEA");
            CYC_W(x"FD23", x"5A");
            CYC_R(x"FFEA");
            CYC_R(x"FFEA");
            CYC_R(x"FFEA");
            CYC_R(x"FE41");             -- keyboard port A - should ignore
            CYC_W(x"FE41", x"A5");      -- keyboard port A
            CYC_R(x"FFEA");
            CYC_R(x"FFEA");
            CYC_W(x"FE80", x"A5");      -- FDCON
            CYC_W(x"FE80", x"5A");
            CYC_W(x"FE84", x"A5");      -- FDC
            CYC_W(x"FE84", x"5A");

            CYC_R(x"FFEA");

            wait for 10 us;

         end if;

      end loop;

      wait for 3 us;

      test_runner_cleanup(runner); -- Simulation ends here
   end process;

   e_dut:entity work.peripherals
   port map (

      clk_2MHz_E_i   => i_clk_2MHzE,
      clk_1MHz_E_i   => i_clk_1MHzE,
      
      MIO_io         => i_MIO,
      MIO_nALE_i     => i_MIO_nALE,
      MIO_D_nOE_i    => i_MIO_D_nOE,
      MIO_I0_nOE_i   => i_MIO_I0_nOE,
      MIO_I1_nOE_i   => i_MIO_I1_nOE,
      MIO_O0_nOE_i   => i_MIO_O0_nOE,
      MIO_O1_nOE_i   => i_MIO_O1_nOE,

      VID_HS_o       => i_test_VID_HS,
      VID_VS_o       => i_test_VID_VS,
      VID_CS_o       => i_test_VID_CS

   );

   e_slow_cyc:entity work.bbc_slow_cyc
   port map (
      sys_A_i        => i_SYS_A,
      slow_o         => i_bbc_slow_cyc
   );

end rtl;

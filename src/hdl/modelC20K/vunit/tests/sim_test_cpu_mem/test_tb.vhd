library vunit_lib;
context vunit_lib.vunit_context;



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use std.textio.all;

library work;
use work.common.all;

library fmf;

library work;

entity test_tb is
   generic (
      runner_cfg : string
      );
end test_tb;

architecture rtl of test_tb is

   --constant G_MOSROMFILE : string := "C:/Users/Dominic/Documents/Programming/HostFS/roms65/MOS120.M";
   constant G_MOSROMFILE : string := "../../../../../asm/C20KTestMOS/build/C20KTestMOS-ThrottleOff.rom";

   constant CLOCKSPEED : natural := 2000000;

   constant CLOCK_PER : time := (1000000 us / CLOCKSPEED);


   signal r_clk : std_logic;
   signal r_n_res : std_logic;

   signal i_MEM_A_io       : std_logic_vector(20 downto 0);
   signal i_MEM_D_io       : std_logic_vector(7 downto 0);
   signal i_MEM_nCE_i      : std_logic_vector(3 downto 0);
   signal i_MEM_FL_nCE_i   : std_logic;
   signal i_MEM_nOE_i      : std_logic;
   signal i_MEM_nWE_i      : std_logic;
   signal i_CPU_A_nOE_i    : std_logic;
   signal i_CPU_PHI2_i     : std_logic;
   signal i_CPU_BE_i       : std_logic;
   signal i_CPU_RDY_i      : std_logic;
   signal i_CPU_nRES_i     : std_logic;
   signal i_CPU_nIRQ_i     : std_logic;
   signal i_CPU_nNMI_i     : std_logic;
   signal i_CPU_nABORT_i   : std_logic;
   signal i_CPU_MX_o       : std_logic;
   signal i_CPU_E_o        : std_logic;


begin
   p_clk:process
   begin
      r_clk <= '1';
      wait for CLOCK_PER / 2;
      r_clk <= '0';
      wait for CLOCK_PER / 2;
   end process;

   p_brd_rst:process
   begin
      wait for 100 ns;
      r_n_res <= '0';
      wait for 10 us;
      r_n_res <= '1';
      wait;
   end process;



   p_main:process
   begin

      test_runner_setup(runner, runner_cfg);

      while test_suite loop

         if run("look") then

            wait for 50 us;

         end if;

      end loop;

      wait for 3 us;

      test_runner_cleanup(runner); -- Simulation ends here
   end process;

   e_dut: entity work.sim_cpu_mem
   generic map (
       G_MOSROMFILE  => G_MOSROMFILE
   )
   port map (

      MEM_A_io       => i_MEM_A_io,
      MEM_D_io       => i_MEM_D_io,
      MEM_nCE_i      => i_MEM_nCE_i,
      MEM_FL_nCE_i   => i_MEM_FL_nCE_i,
      MEM_nOE_i      => i_MEM_nOE_i,
      MEM_nWE_i      => i_MEM_nWE_i,
      CPU_A_nOE_i    => i_CPU_A_nOE_i,
      CPU_PHI2_i     => i_CPU_PHI2_i,
      CPU_BE_i       => i_CPU_BE_i,
      CPU_RDY_i      => i_CPU_RDY_i,
      CPU_nRES_i     => i_CPU_nRES_i,
      CPU_nIRQ_i     => i_CPU_nIRQ_i,
      CPU_nNMI_i     => i_CPU_nNMI_i,
      CPU_nABORT_i   => i_CPU_nABORT_i,
      CPU_MX_o       => i_CPU_MX_o,
      CPU_E_o        => i_CPU_E_o

   );

   i_CPU_PHI2_i <= r_clk;
   i_CPU_BE_i <= '1';
   i_CPU_nRES_i <= r_n_res;

   p_beh_meh:process
   variable v_A: std_logic_vector(15 downto 0);
   begin
      wait until falling_edge(r_clk);
      wait for 40 ns;      
      i_MEM_A_io <= (others => 'Z');
      i_CPU_A_nOE_i <= '0';
      wait for 20 ns;
      v_A := i_MEM_A_io(15 downto 0);
      i_CPU_A_nOE_i <= '1';
      wait for 20 ns;
      i_MEM_A_io <= "11111" & v_A(15 downto 8) & "ZZZZZZZZ";
   end process;


   i_CPU_RDY_i <= '1';
   i_CPU_nNMI_i <= '1';
   i_CPU_nIRQ_i <= '1';
   i_CPU_nABORT_i <= '1';

   i_MEM_FL_nCE_i <= not r_clk;
   i_MEM_nOE_i <= not r_clk;
   i_MEM_nWE_i <= '1';
   i_MEM_nCE_i <= (others => '1');


end rtl;

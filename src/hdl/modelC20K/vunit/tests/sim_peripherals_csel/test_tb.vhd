library vunit_lib;
context vunit_lib.vunit_context;

-- test periphs_csel 


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library fmf;

library work;

entity test_tb is
   generic (
      runner_cfg : string
      );
end test_tb;

architecture rtl of test_tb is

   signal   i_clk_2MHzE    : std_logic;
   signal   i_nCS          : std_logic_vector(3 downto 0);
   signal   i_nADLC        : std_logic;
   signal   i_nKBPAWR      : std_logic;
   signal   i_nIC32WR      : std_logic;
   signal   i_nPGFC        : std_logic;
   signal   i_nPGFD        : std_logic;
   signal   i_nTUBE        : std_logic;
   signal   i_nFDC         : std_logic;
   signal   i_nFDCONWR     : std_logic;
   signal   i_nVIAB        : std_logic;

begin

   -- TODO: this doesn't test clock stretching
   p_clk_2e:process
   begin
      i_clk_2MHzE <= '0';
      wait for 250 ns;
      i_clk_2MHzE <= '1';
      wait for 250 ns;
   end process;

   p_main:process
      variable I:natural;
   begin

      test_runner_setup(runner, runner_cfg);


      while test_suite loop

         if run("test") then
            for I in 0 to 15 loop
               wait until falling_edge(i_clk_2MHzE);
               i_nCS <= std_logic_vector(to_unsigned(I, 4));

               wait until falling_edge(i_clk_2MHzE);
               i_nCS <= (others => '0');

            end loop;


            wait for 10 us;

         end if;

      end loop;

      wait for 3 us;

      test_runner_cleanup(runner); -- Simulation ends here
   end process;

   e_dut:entity work.sim_peripherals_csel
   port map (
      clk_2MHzE_i    => i_clk_2MHzE,
      nCS_i          => i_nCS,
      nADLC_o        => i_nADLC,
      nKBPAWR_o      => i_nKBPAWR,
      nIC32WR_o      => i_nIC32WR,
      nPGFC_o        => i_nPGFC,
      nPGFD_o        => i_nPGFD,
      nTUBE_o        => i_nTUBE,
      nFDC_o         => i_nFDC,
      nFDCONWR_o     => i_nFDCONWR,
      nVIAB_o        => i_nVIAB

   );

end rtl;

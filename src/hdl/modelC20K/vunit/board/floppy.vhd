library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;

entity floppy is
port (
   A_i         :    in std_logic_vector(1 downto 0);
   D_io        : inout std_logic_vector(7 downto 0);
   RnW_i       :    in std_logic;
   nRST_i      :    in std_logic;
   nFDC_i      :    in std_logic;
   nFDCON_i    :    in std_logic;
   NMI_o       :   out std_logic;
   CLK8_i      :    in std_logic
);
end entity floppy;

architecture behav of floppy is

begin

   D_io <= (others => 'Z');

   p_FDCON:process
   begin
      
      wait until rising_edge(nFDCON_i);
      report "FDCON : WR : " & to_hstring(unsigned(D_io)) & LF severity note;

   end process;

end architecture behav;

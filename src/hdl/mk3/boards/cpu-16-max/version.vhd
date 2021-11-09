-- Automatically generated file (get-version.tcl) DO NOT EDIT!
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
entity version_rom is port (
 A : in std_logic_vector(7 downto 0);
 Q : out std_logic_vector(7 downto 0)
);
end version_rom;
-- 35c62a5M 2021-11-09:22:09:08
-- main:github.com/dominicbeesley/blitter-vhdl-6502.git
architecture rtl of version_rom is
begin
Q <=
   x"33" when unsigned(A) = 0 else 
   x"35" when unsigned(A) = 1 else 
   x"63" when unsigned(A) = 2 else 
   x"36" when unsigned(A) = 3 else 
   x"32" when unsigned(A) = 4 else 
   x"61" when unsigned(A) = 5 else 
   x"35" when unsigned(A) = 6 else 
   x"4D" when unsigned(A) = 7 else 
   x"20" when unsigned(A) = 8 else 
   x"32" when unsigned(A) = 9 else 
   x"30" when unsigned(A) = 10 else 
   x"32" when unsigned(A) = 11 else 
   x"31" when unsigned(A) = 12 else 
   x"2D" when unsigned(A) = 13 else 
   x"31" when unsigned(A) = 14 else 
   x"31" when unsigned(A) = 15 else 
   x"2D" when unsigned(A) = 16 else 
   x"30" when unsigned(A) = 17 else 
   x"39" when unsigned(A) = 18 else 
   x"3A" when unsigned(A) = 19 else 
   x"32" when unsigned(A) = 20 else 
   x"32" when unsigned(A) = 21 else 
   x"3A" when unsigned(A) = 22 else 
   x"30" when unsigned(A) = 23 else 
   x"39" when unsigned(A) = 24 else 
   x"3A" when unsigned(A) = 25 else 
   x"30" when unsigned(A) = 26 else 
   x"38" when unsigned(A) = 27 else 
   x"0D" when unsigned(A) = 28 else 
   x"6D" when unsigned(A) = 29 else 
   x"61" when unsigned(A) = 30 else 
   x"69" when unsigned(A) = 31 else 
   x"6E" when unsigned(A) = 32 else 
   x"3A" when unsigned(A) = 33 else 
   x"67" when unsigned(A) = 34 else 
   x"69" when unsigned(A) = 35 else 
   x"74" when unsigned(A) = 36 else 
   x"68" when unsigned(A) = 37 else 
   x"75" when unsigned(A) = 38 else 
   x"62" when unsigned(A) = 39 else 
   x"2E" when unsigned(A) = 40 else 
   x"63" when unsigned(A) = 41 else 
   x"6F" when unsigned(A) = 42 else 
   x"6D" when unsigned(A) = 43 else 
   x"2F" when unsigned(A) = 44 else 
   x"64" when unsigned(A) = 45 else 
   x"6F" when unsigned(A) = 46 else 
   x"6D" when unsigned(A) = 47 else 
   x"69" when unsigned(A) = 48 else 
   x"6E" when unsigned(A) = 49 else 
   x"69" when unsigned(A) = 50 else 
   x"63" when unsigned(A) = 51 else 
   x"62" when unsigned(A) = 52 else 
   x"65" when unsigned(A) = 53 else 
   x"65" when unsigned(A) = 54 else 
   x"73" when unsigned(A) = 55 else 
   x"6C" when unsigned(A) = 56 else 
   x"65" when unsigned(A) = 57 else 
   x"79" when unsigned(A) = 58 else 
   x"2F" when unsigned(A) = 59 else 
   x"62" when unsigned(A) = 60 else 
   x"6C" when unsigned(A) = 61 else 
   x"69" when unsigned(A) = 62 else 
   x"74" when unsigned(A) = 63 else 
   x"74" when unsigned(A) = 64 else 
   x"65" when unsigned(A) = 65 else 
   x"72" when unsigned(A) = 66 else 
   x"2D" when unsigned(A) = 67 else 
   x"76" when unsigned(A) = 68 else 
   x"68" when unsigned(A) = 69 else 
   x"64" when unsigned(A) = 70 else 
   x"6C" when unsigned(A) = 71 else 
   x"2D" when unsigned(A) = 72 else 
   x"36" when unsigned(A) = 73 else 
   x"35" when unsigned(A) = 74 else 
   x"30" when unsigned(A) = 75 else 
   x"32" when unsigned(A) = 76 else 
   x"2E" when unsigned(A) = 77 else 
   x"67" when unsigned(A) = 78 else 
   x"69" when unsigned(A) = 79 else 
   x"74" when unsigned(A) = 80 else 
   x"00";
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity version_rom is port (
 A : in std_logic_vector(6 downto 0);
 Q : out std_logic_vector(7 downto 0)
);
end version_rom;
-- G:cc9cc6bM|2025-07-02:13:16:23|C20K|dev-c20k-firstlight:dominicbeesley/blitter-vhdl-6502
architecture rtl of version_rom is

   constant G_SIZE_MAX : natural := 128;
   constant G_FILENAME : string := "version_strings.vec";
   
   type     rom_type       is array (0 to G_SIZE_MAX) of std_logic_vector(7 downto 0);

   impure function INITROM(file_name:STRING) return rom_type is
      file infile : text is in file_name;
      variable i : integer;
      variable inl : line;
      variable ret : rom_type := (others => x"00");
   begin

      i := 0;
      while not endfile(infile) and i < G_SIZE_MAX loop
         readline(infile, inl);
         read(inl, ret(i));
         i := i + 1;
      end loop;

      return ret;
   end function;

   signal   rom : rom_type := INITROM(G_FILENAME);

begin
   Q <= rom(to_integer(unsigned(A)));
end rtl;

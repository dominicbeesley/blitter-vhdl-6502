-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2009 Benjamin Krill <benjamin@krll.de>
-- Copyright (c) 2020 Dominic Beesley https://github.com/dominicbeesley
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
-- -----------------------------------------------------------------------------
-- 
-- See also https://git.krll.de/public/snippets/src/branch/master/vhdl/rrarbiter.vhd
-- This version has been modified from the Krill version with the following 
-- changes:
--    - ack is removed, instead req being de-asserted on the currently granted 
--      item causes a rerun
--    - registered masks etc used to improve timing closure
--    - functions used to make masks instead of (slower) arithmetic
--    - comments and renaming of signals and ports
--    - my_or_reduce used instead of compare to 0 - fewer resources, faster timing

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity fb_arbiter_roundrobin is
   generic ( CNT : integer := 7 );
   port (
      clk_i          : in    std_logic;
      rst_i          : in    std_logic;

      req_i          : in    std_logic_vector(CNT-1 downto 0);
      ack_i          : in    std_logic; -- should fire for one cycle to indicate previous grant had been 
                                        -- serviced
      --none of these are registered!
      grant_ix_o     : out   unsigned(numbits(CNT)-1 downto 0)
   );
end;

architecture rtl of fb_arbiter_roundrobin is
   signal r_grant_ix_prev     : unsigned(grant_ix_o'range);

   signal i_grant_ix_higher   : unsigned(grant_ix_o'range);
   signal i_grant_ix_le       : unsigned(grant_ix_o'range);
   signal i_grant_ix          : unsigned(grant_ix_o'range);
   signal i_grant_any_higher  : boolean;
   signal i_grant_any_le      : boolean;

begin

   grant_ix_o <= i_grant_ix;

   p:process(req_i, r_grant_ix_prev)
   variable v_grant_any_le : boolean;
   variable v_grant_any_higher : boolean;
   begin
      i_grant_ix_higher <= (others => '-');
      i_grant_ix_le <= (others => '-');
      v_grant_any_le := false;
      v_grant_any_higher := false;

      for I in 0 to req_i'length-1 loop
         if I <= to_integer(r_grant_ix_prev) then
            if req_i(I) = '1' and not v_grant_any_le then
               v_grant_any_le := true;
               i_grant_ix_le <= to_unsigned(I, grant_ix_o'length);
            end if;
         else
            if req_i(I) = '1' and not v_grant_any_higher then
               v_grant_any_higher := true;
               i_grant_ix_higher <= to_unsigned(I, grant_ix_o'length);
            end if;           
         end if;
      end loop;

      i_grant_any_higher <= v_grant_any_higher;
      i_grant_any_le <= v_grant_any_le;
   end process;

   i_grant_ix <=  i_grant_ix_higher when i_grant_any_higher else
                  i_grant_ix_le;

   process (clk_i, rst_i)
   begin
   if rst_i = '1' then
      r_grant_ix_prev <= (others => '1');
   elsif rising_edge(clk_i) then
      if ack_i = '1' then
         r_grant_ix_prev <= i_grant_ix;
      end if;
   end if;
   end process;

end rtl;
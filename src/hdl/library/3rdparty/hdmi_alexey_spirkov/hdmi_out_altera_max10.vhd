--
-- Copyright (c) 2015 Davor Jadrijevic
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
--


-- DB: MAX10 version, don't instantiate a obufds and use a dd_out component

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity hdmi_out_altera_max10 is
   port (
      clock_pixel_i     : in std_logic;   -- x1
      clock_tdms_i      : in std_logic;   -- x5
      red_i             : in  std_logic_vector(9 downto 0);
      green_i           : in  std_logic_vector(9 downto 0);
      blue_i            : in  std_logic_vector(9 downto 0);      
      red_s             : out std_logic;
      green_s           : out std_logic;
      blue_s            : out std_logic;
      clock_s           : out std_logic
   );
end entity;

architecture Behavioral of hdmi_out_altera_max10 is

   component dd_out
   PORT
   (
      datain_h    : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
      datain_l    : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
      outclock    : IN STD_LOGIC ;
      dataout     : OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
   );
   END component;


   signal mod5          : std_logic_vector(2 downto 0) := (others => '0'); -- DB: added initial value for modelsim
   signal shift_r,
         shift_g,
         shift_b,
         shift_clk      : std_logic_vector(9 downto 0);

   signal tmds          : std_logic_vector(3 downto 0);
   signal x             : std_logic_vector(3 downto 0);
   signal y           : std_logic_vector(3 downto 0);


begin

   process (clock_tdms_i)
   begin
      if rising_edge(clock_tdms_i) then
         if mod5(2) = '1' then
            mod5 <= "000";
            shift_r <= red_i;
            shift_g <= green_i;
            shift_b <= blue_i;
            shift_clk <= "0000011111";    -- the clock channel symbol is static
         else
            mod5 <= mod5 + "001";
            shift_r     <= "00" & shift_r(9 downto 2);
            shift_g     <= "00" & shift_g(9 downto 2);
            shift_b     <= "00" & shift_b(9 downto 2);
            shift_clk   <= "00" & shift_clk(9 downto 2);
         end if;
      end if;
   end process;


   y <= shift_b(1) & shift_g(1) & shift_r(1) & shift_clk (1);
   x <= shift_b(0) & shift_g(0) & shift_r(0) & shift_clk (0);
   ddr : dd_out port map (
       datain_h => x
    ,  datain_l => y
    ,  outclock => clock_tdms_i
    ,  dataout => tmds
    );

   --note maybe reverse of how they are in top-level?
   blue_s <= tmds(3);
   green_s <= tmds(2);
   red_s <= tmds(1);
   clock_s <= tmds(0);


end Behavioral;

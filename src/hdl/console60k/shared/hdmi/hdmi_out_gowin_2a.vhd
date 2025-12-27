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

-- vendor-independent module for simulating differential HDMI output
-- this module tested on scarab and it works :)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity hdmi_out_gowin_2a is
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

architecture Behavioral of hdmi_out_gowin_2a is

    component OSER10
        generic (
            GSREN : string := "false";
            LSREN : string := "true"
        );
        port (
            Q : out std_logic;
            D0 : in std_logic;
            D1 : in std_logic;
            D2 : in std_logic;
            D3 : in std_logic;
            D4 : in std_logic;
            D5 : in std_logic;
            D6 : in std_logic;
            D7 : in std_logic;
            D8 : in std_logic;
            D9 : in std_logic;
            FCLK : in std_logic;
            PCLK : in std_logic;
            RESET : in std_logic
        );
    end component;

    component ELVDS_OBUF
        port (
            I : in std_logic;
            O : out std_logic;
            OB : out std_logic
        );
    end component;

    signal serial_outputs : std_logic_vector(3 downto 0);

begin

        ser_b : OSER10
            generic map (
                GSREN => "false",
                LSREN => "true"
            )
            port map(
                PCLK  => clock_pixel_i,
                FCLK  => clock_tdms_i,
                RESET => '0',
                Q     => serial_outputs(0),
                D0    => blue_i(0),
                D1    => blue_i(1),
                D2    => blue_i(2),
                D3    => blue_i(3),
                D4    => blue_i(4),
                D5    => blue_i(5),
                D6    => blue_i(6),
                D7    => blue_i(7),
                D8    => blue_i(8),
                D9    => blue_i(9)
            );

        ser_g : OSER10
            generic map (
                GSREN => "false",
                LSREN => "true"
            )
            port map (
                PCLK  => clock_pixel_i,
                FCLK  => clock_tdms_i,
                RESET => '0',
                Q     => serial_outputs(1),
                D0    => green_i(0),
                D1    => green_i(1),
                D2    => green_i(2),
                D3    => green_i(3),
                D4    => green_i(4),
                D5    => green_i(5),
                D6    => green_i(6),
                D7    => green_i(7),
                D8    => green_i(8),
                D9    => green_i(9)
            );

        ser_r : OSER10
            generic map (
                GSREN => "false",
                LSREN => "true"
            )
            port map (
                PCLK  => clock_pixel_i,
                FCLK  => clock_tdms_i,
                RESET => '0',
                Q     => serial_outputs(2),
                D0    => red_i(0),
                D1    => red_i(1),
                D2    => red_i(2),
                D3    => red_i(3),
                D4    => red_i(4),
                D5    => red_i(5),
                D6    => red_i(6),
                D7    => red_i(7),
                D8    => red_i(8),
                D9    => red_i(9)
                );

        ser_c : OSER10
            generic map (
                GSREN => "false",
                LSREN => "true"
            )
            port map (
                PCLK  => clock_pixel_i,
                FCLK  => clock_tdms_i,
                RESET => '0',
                Q     => serial_outputs(3),
                D0    => '1',
                D1    => '1',
                D2    => '1',
                D3    => '1',
                D4    => '1',
                D5    => '0',
                D6    => '0',
                D7    => '0',
                D8    => '0',
                D9    => '0'
            );


   clock_s <= serial_outputs(3);
   red_s <= serial_outputs(2);
   green_s <= serial_outputs(1);
   blue_s <= serial_outputs(0);


end Behavioral;

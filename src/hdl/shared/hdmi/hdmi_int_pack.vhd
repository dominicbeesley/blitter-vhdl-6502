-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2021 Dominic Beesley https://github.com/dominicbeesley
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
-- ----------------------------------------------------------------------


-- Company:                         Dossytronics
-- Engineer:                        Dominic Beesley
-- 
-- Create Date:               9/11/2021
-- Design Name: 
-- Module Name:               work.hdmi_pack
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:               HDMI shared definitions
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

package hdmi_int_pack is


   component hdmi is 
      generic (
      FREQ: integer := 27000000;              -- pixel clock frequency
      FS: integer := 48000;                   -- audio sample rate - should be 32000, 44100 or 48000
      CTS: integer := 27000;                  -- CTS = Freq(pixclk) * N / (128 * Fs)
      N: integer := 6144                      -- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300
                          -- Check HDMI spec 7.2 for details
   );
   port (
      -- clocks
      I_CLK_PIXEL    : in std_logic;
      -- components
      I_R            : in std_logic_vector(7 downto 0);
      I_G            : in std_logic_vector(7 downto 0);
      I_B            : in std_logic_vector(7 downto 0);
      I_BLANK        : in std_logic;
      I_HSYNC        : in std_logic;
      I_VSYNC        : in std_logic;
--      I_ASPECT_169   : in std_logic;
      I_AVI_DATA     : in std_logic_vector(111 downto 0);
      -- PCM audio
      I_AUDIO_ENABLE : in std_logic;
      I_AUDIO_PCM_L  : in std_logic_vector(15 downto 0);
      I_AUDIO_PCM_R  : in std_logic_vector(15 downto 0);
      -- TMDS parallel pixel synchronous outputs (serialize LSB first)
      O_RED       : out std_logic_vector(9 downto 0); -- Red
      O_GREEN        : out std_logic_vector(9 downto 0); -- Green
      O_BLUE         : out std_logic_vector(9 downto 0)  -- Blue
   );
   end component;

end package hdmi_int_pack;

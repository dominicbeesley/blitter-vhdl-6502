-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2026 Dominic Beesley https://github.com/dominicbeesley
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

-- Company:          Dossytronics
-- Engineer:         Dominic Beesley
--
-- Create Date:      22/10/2026
-- Design Name:
-- Module Name:      ram_sdp_2clk
-- Project Name:
-- Target Devices:   Intel/Altera via Quartus (Cyclone IV, MAX10: M9K) and
--                   GoWin (GW2A: BSRAM), inferred block RAM
-- Tool versions:
-- Description:      Simple dual-port RAM (one write-only port, one read-only
--                   port) with a separate clock for each port
-- Dependencies:     work.common (numbits)
--
-- Revision:
-- Additional Comments:
--   Written to the inference templates of both tools: one write process, one
--   read process, no reset and no initial value on the array or the read
--   data. Check the build reports on each tool for an inferred block RAM
--   (Quartus: "Inferred RAM" in the analysis & synthesis report; GoWin: SDPB
--   in the resource report).
--
--   Read latency is one read clock: rd_D_o is registered from the address
--   presented at the previous rd_clk_i edge (the same as the Quartus
--   altsyncram with a registered read address and an unregistered output,
--   or a GoWin SDPB with READ_MODE '0').
--
--   A read and a write of the same address at the same time give undefined
--   read data (the clocks are unrelated).
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;

entity ram_sdp_2clk is
   generic (
      G_ADDRESS_SIZE    : positive;    -- number of words (needn't be a power of 2)
      G_DATA_WIDTH      : positive     -- bits per word
   );
   port (
      -- write port
      wr_clk_i          : in  std_logic;
      wr_en_i           : in  std_logic;
      wr_addr_i         : in  std_logic_vector(numbits(G_ADDRESS_SIZE)-1 downto 0);
      wr_D_i            : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);

      -- read port
      rd_clk_i          : in  std_logic;
      rd_addr_i         : in  std_logic_vector(numbits(G_ADDRESS_SIZE)-1 downto 0);
      rd_D_o            : out std_logic_vector(G_DATA_WIDTH-1 downto 0)
   );
end ram_sdp_2clk;

architecture rtl of ram_sdp_2clk is

   type     t_ram is array (0 to G_ADDRESS_SIZE-1) of std_logic_vector(G_DATA_WIDTH-1 downto 0);
   signal   r_ram             : t_ram;

   -- each tool ignores the other's attribute
   attribute ramstyle         : string;   -- Quartus
   attribute syn_ramstyle     : string;   -- GoWin
   attribute ramstyle     of r_ram : signal is "no_rw_check";
   attribute syn_ramstyle of r_ram : signal is "block_ram";

begin

   p_wr : process(wr_clk_i)
   begin
      if rising_edge(wr_clk_i) then
         if wr_en_i = '1' then
            r_ram(to_integer(unsigned(wr_addr_i))) <= wr_D_i;
         end if;
      end if;
   end process;

   p_rd : process(rd_clk_i)
   begin
      if rising_edge(rd_clk_i) then
         rd_D_o <= r_ram(to_integer(unsigned(rd_addr_i)));
      end if;
   end process;

end rtl;

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
-- Module Name:      ram_tdp_2clk
-- Project Name:
-- Target Devices:   Intel/Altera via Quartus (Cyclone IV, MAX10: M9K) and
--                   GoWin (GW2A: BSRAM), inferred block RAM
-- Tool versions:
-- Description:      True dual-port RAM: two ports, each can read and write,
--                   each with its own clock
-- Dependencies:     work.common (numbits)
--
-- Revision:
-- Additional Comments:
--   Written to the true dual-port, dual-clock inference template of both
--   tools: the array is a shared variable written from two processes, one
--   per port; no reset and no initial value on the array or read data.
--   Check the build reports on each tool for an inferred block RAM
--   (Quartus: "Inferred RAM" / BIDIR_DUAL_PORT in the analysis & synthesis
--   report; GoWin: DPB in the resource report). If a tool won't infer it,
--   fall back to a vendor IP architecture behind this same entity.
--
--   The shared variable isn't a protected type: allowed in VHDL-93 and what
--   both synthesis templates use; ModelSim warns about it in VHDL-2002/2008
--   mode, which can be ignored here.
--
--   Read latency is one clock on each port: x_D_o is registered from the
--   address presented at the previous edge (as the hdmi_blockram IP:
--   registered address, unregistered output).
--
--   A write on a port also updates that port's read data on the same edge
--   (write-through / new data, as the IP: altsyncram NEW_DATA, GoWin
--   WRITE_MODE "01"). A read on one port of an address being written by the
--   other port at the same time gives undefined data (unrelated clocks);
--   two writes to the same address at once leave it undefined.
--
--   For a read-only port tie its x_wr_en_i to '0' and x_D_i to anything.
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;

entity ram_tdp_2clk is
   generic (
      G_ADDRESS_SIZE    : positive;    -- number of words (needn't be a power of 2)
      G_DATA_WIDTH      : positive     -- bits per word
   );
   port (
      -- port A
      a_clk_i           : in  std_logic;
      a_wr_en_i         : in  std_logic;
      a_addr_i          : in  std_logic_vector(numbits(G_ADDRESS_SIZE)-1 downto 0);
      a_D_i             : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
      a_D_o             : out std_logic_vector(G_DATA_WIDTH-1 downto 0);

      -- port B
      b_clk_i           : in  std_logic;
      b_wr_en_i         : in  std_logic;
      b_addr_i          : in  std_logic_vector(numbits(G_ADDRESS_SIZE)-1 downto 0);
      b_D_i             : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
      b_D_o             : out std_logic_vector(G_DATA_WIDTH-1 downto 0)
   );
end ram_tdp_2clk;

architecture rtl of ram_tdp_2clk is

   type     t_ram is array (0 to G_ADDRESS_SIZE-1) of std_logic_vector(G_DATA_WIDTH-1 downto 0);
   shared variable sv_ram : t_ram;

   -- GoWin: block RAM, not distributed. (No Quartus "no_rw_check" here,
   -- unlike ram_sdp_2clk: it would let Quartus drop the same-port
   -- write-through behaviour described above.)
   attribute syn_ramstyle     : string;
   attribute syn_ramstyle of sv_ram : variable is "block_ram";

begin

   p_a : process(a_clk_i)
   begin
      if rising_edge(a_clk_i) then
         if a_wr_en_i = '1' then
            sv_ram(to_integer(unsigned(a_addr_i))) := a_D_i;
         end if;
         a_D_o <= sv_ram(to_integer(unsigned(a_addr_i)));
      end if;
   end process;

   p_b : process(b_clk_i)
   begin
      if rising_edge(b_clk_i) then
         if b_wr_en_i = '1' then
            sv_ram(to_integer(unsigned(b_addr_i))) := b_D_i;
         end if;
         b_D_o <= sv_ram(to_integer(unsigned(b_addr_i)));
      end if;
   end process;

end rtl;

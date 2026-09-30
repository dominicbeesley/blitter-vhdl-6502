-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	25/9/2026
-- Design Name: 
-- Module Name:    	sync_sync
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A sync synchroniser, for passing HS/VS from local 16/48 clock
--							to a 27/54MHz domain
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--       We need to synchronise the hsync / vsync signals from the 48 to 27/54 MHz pixel
--       domain. 
--       To do this we detect the change in the 27MHz domain and then resample a couple of
--       clocks later
--       There's hysteresis set to avoid hunting and we must set a period for the sample
--       position.
--       This is borrowed from BeebFPGA's scan doubler 
--       see https://github.com/hoglet67/BeebFpga/blob/dev/src/common/scandoubler/rgb2vga_scandoubler.vhd#L212
--    This is slightly different to the BeebFPGA version in that it is just used to 
--      detect the leading edge of syncs that are passed in as a flip in the input
----------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common.all;

library work;

entity sync_sync is
   generic (
      G_PERIOD : natural      := 9;   --PERIOD is the number cycles of dest clock to sample, 
                                 --there must be a whole number of these cycles between
                                 --HS's and must be >= HYSTERESIS*2 + (TRAIL - META)
      G_HYSTERESIS : natural     := 2;    --syncs will be samples this number of dest_clk cycles
                                 --after a sync is detected
      G_TRAIL : natural       := 4; --number of cycles after a detected edge to sample
      G_META : natural        := 2  --the incoming HS is passed through this number of flip
                                 --flops to remove metastability
   );
   port(
      HSYNC_SRC_e_i     : in  std_logic;
      VSYNC_SRC_e_i     : in  std_logic;

      CLK_DEST_i        : in  std_logic;
      
      HSYNC_DST_e_o     : out std_logic;
      VSYNC_DST_e_o     : out std_logic

   );
end sync_sync;



architecture rtl of sync_sync is
   
   signal   i_hsync_meta   : std_logic;

   signal   r_hsync_prev   : std_logic;

   signal   r_ctr       : unsigned(NUMBITS(G_PERIOD)-1 downto 0);

begin

   e_rm_hs:entity work.metadelay
   generic map (
      N     => G_META
   )
   port map(
      clk   => CLK_DEST_i,
      i     => HSYNC_SRC_e_i,
      o     => i_hsync_meta
   );

   p:process(CLK_DEST_i)
   begin
		if rising_edge(CLK_DEST_i) then
	      if (r_ctr = G_PERIOD -1) then
	         r_ctr <= to_unsigned(0, r_ctr'length);
	      else
	         r_ctr <= r_ctr + 1;
	      end if;

	      if r_hsync_prev /= i_hsync_meta then
	         if r_ctr >= G_HYSTERESIS and r_ctr < G_PERIOD - G_HYSTERESIS then
	            r_ctr <= to_unsigned(0, r_ctr'length);
	         end if;
	         r_hsync_prev <= i_hsync_meta;
	      end if;

	      if r_ctr = (G_TRAIL - G_META - 1) mod G_PERIOD then
	         HSYNC_DST_e_o <= HSYNC_SRC_e_i;
	         VSYNC_DST_e_o <= VSYNC_SRC_e_i;
	      end if;
	   end if;
   end process;

end rtl;


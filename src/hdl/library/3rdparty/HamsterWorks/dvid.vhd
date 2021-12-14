--------------------------------------------------------------------------------
-- Engineer:      Mike Field <hamster@snap.net.nz>
-- Description:   Converts VGA signals into DVID bitstreams.
--
--                'clk' should be 5x clk_pixel.
--
--                'blank' should be asserted during the non-display 
--                portions of the frame
--
-- This file hacked D.Beesley Dec 2021 for MAX 10 SERDES
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity dvid is
    Port ( clk       : in  STD_LOGIC;
           clk_pixel : in  STD_LOGIC;
           red_p     : in  STD_LOGIC_VECTOR (7 downto 0);
           green_p   : in  STD_LOGIC_VECTOR (7 downto 0);
           blue_p    : in  STD_LOGIC_VECTOR (7 downto 0);
           blank     : in  STD_LOGIC;
           hsync     : in  STD_LOGIC;
           vsync     : in  STD_LOGIC;
           red_s     : out STD_LOGIC;
           green_s   : out STD_LOGIC;
           blue_s    : out STD_LOGIC;
           clock_s   : out STD_LOGIC);
end dvid;

architecture Behavioral of dvid is
   COMPONENT TDMS_encoder
   PORT(
      clk     : IN  std_logic;
      data    : IN  std_logic_vector(7 downto 0);
      c       : IN  std_logic_vector(1 downto 0);
      blank   : IN  std_logic;          
      encoded : OUT std_logic_vector(9 downto 0)
      );
   END COMPONENT;
	
--	component dd_out
--	PORT
--	(
--		datain_h		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
--		datain_l		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
--		outclock		: IN STD_LOGIC ;
--		dataout		: OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
--	);
--	END component;

   signal encoded_red, encoded_green, encoded_blue : std_logic_vector(9 downto 0);
   signal latched_red, latched_green, latched_blue : std_logic_vector(9 downto 0) := (others => '0');
   
--   signal shift_red,   shift_green,   shift_blue   : std_logic_vector(9 downto 0) := (others => '0');   
--   signal shift_clock   : std_logic_vector(9 downto 0) := "1110000011";

   
   constant c_red       : std_logic_vector(1 downto 0) := (others => '0');
   constant c_green     : std_logic_vector(1 downto 0) := (others => '0');
   signal   c_blue      : std_logic_vector(1 downto 0);

--	signal tmds				: std_logic_vector(3 downto 0);
--	signal x				   : std_logic_vector(3 downto 0);
--	signal y			    : std_logic_vector(3 downto 0);
	
begin   
   c_blue <= vsync & hsync;
   
   TDMS_encoder_red:   TDMS_encoder PORT MAP(clk => clk_pixel, data => red_p,   c => c_red,   blank => blank, encoded => encoded_red);
   TDMS_encoder_green: TDMS_encoder PORT MAP(clk => clk_pixel, data => green_p, c => c_green, blank => blank, encoded => encoded_green);
   TDMS_encoder_blue:  TDMS_encoder PORT MAP(clk => clk_pixel, data => blue_p,  c => c_blue,  blank => blank, encoded => encoded_blue);

--   ODDR2_red   : ODDR2 generic map( DDR_ALIGNMENT => "C0", INIT => '0', SRTYPE => "ASYNC") 
--      port map (Q => red_s,   D0 => shift_red(0),   D1 => shift_red(1),   C0 => clk, C1 => clk_n, CE => '1', R => '0', S => '0');
   
--   ODDR2_green : ODDR2 generic map( DDR_ALIGNMENT => "C0", INIT => '0', SRTYPE => "ASYNC") 
--      port map (Q => green_s, D0 => shift_green(0), D1 => shift_green(1), C0 => clk, C1 => clk_n, CE => '1', R => '0', S => '0');

--   ODDR2_blue  : ODDR2 generic map( DDR_ALIGNMENT => "C0", INIT => '0', SRTYPE => "ASYNC") 
--      port map (Q => blue_s,  D0 => shift_blue(0),  D1 => shift_blue(1),  C0 => clk, C1 => clk_n, CE => '1', R => '0', S => '0');

--   ODDR2_clock : ODDR2 generic map( DDR_ALIGNMENT => "C0", INIT => '0', SRTYPE => "ASYNC") 
--      port map (Q => clock_s, D0 => shift_clock(0), D1 => shift_clock(1), C0 => clk, C1 => clk_n, CE => '1', R => '0', S => '0');

--	od_red : domDDR2 port map (q => red_s, d0 => shift_red(0), d1 => shift_red(1), ck0 => clk, ck1 => clk_n);
--	od_green : domDDR2 port map (q => green_s, d0 => shift_green(0), d1 => shift_green(1), ck0 => clk, ck1 => clk_n);
--	od_blue : domDDR2 port map (q => blue_s, d0 => shift_blue(0), d1 => shift_blue(1), ck0 => clk, ck1 => clk_n);
--	od_clock : domDDR2 port map (q => clock_s, d0 => shift_clock(0), d1 => shift_clock(1), ck0 => clk, ck1 => clk_n);

--  y <= shift_blue(1) & shift_green(1) & shift_red(1) & shift_clock (1);
--  x <= shift_blue(0) & shift_green(0) & shift_red(0) & shift_clock (0);
--	ddr : dd_out port map (
--			datain_h => x
--		,	datain_l => y
--		,  outclock => clk
--		,  dataout => tmds
--		);
		
--	--note reverse of how they are in top-level
--	blue_s <= tmds(3);
--	green_s <= tmds(2);
--	red_s <= tmds(1);
--	clock_s <= tmds(0);

   process(clk_pixel)
   begin
      if rising_edge(clk_pixel) then 
            latched_red   <= encoded_red;
            latched_green <= encoded_green;
            latched_blue  <= encoded_blue;
      end if;
   end process;

--   process(clk)
--   begin
--      if rising_edge(clk) then 
--         if shift_clock = "1110000011" then
--            shift_red   <= latched_red;
--            shift_green <= latched_green;
--            shift_blue  <= latched_blue;
--         else
--            shift_red   <= "00" & shift_red  (9 downto 2);
--            shift_green <= "00" & shift_green(9 downto 2);
--            shift_blue  <= "00" & shift_blue (9 downto 2);
--         end if;
--         shift_clock <= shift_clock(1 downto 0) & shift_clock(9 downto 2);
--      end if;
--   end process;
  
   e_hdmi_ser:entity work.hdmi_serial
   port map (
      tx_inclock => clk_pixel,
      tx_syncclock => clk,
      tx_in => "1110000011" & "0101010101" & "1100110011" & "1110001110",
      tx_out(0) => clock_s,
      tx_out(1) => red_s,
      tx_out(2) => green_s,
      tx_out(3) => blue_s
   );

end Behavioral;


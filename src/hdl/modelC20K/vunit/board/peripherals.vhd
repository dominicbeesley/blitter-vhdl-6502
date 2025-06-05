library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library fmf;

entity peripherals is
   port(

      clk_2MHz_E_i   :  in    std_logic;
      clk_1MHz_E_i   :  in    std_logic;
      
      MIO_io         :  inout std_logic_vector(7 downto 0);
      MIO_nALE_i     :  in    std_logic;
      MIO_D_nOE_i    :  in    std_logic;
      MIO_I0_nOE_i   :  in    std_logic;
      MIO_I1_nOE_i   :  in    std_logic;
      MIO_O0_nOE_i   :  in    std_logic;
      MIO_O1_nOE_i   :  in    std_logic;

      VID_HS_o       :  out   std_logic;
      VID_VS_o       :  out   std_logic;
      VID_CS_o       :  out   std_logic

      -- untested...
      -- KB_nRST_5
      -- clk_8MHzE
      -- j_lpstb
      -- ui_leds


   );
end peripherals;

architecture rtl of peripherals is
   
   signal i_P_D      : std_logic_vector(7 downto 0);
   signal i_P_A      : std_logic_vector(7 downto 0);

   signal i_U8_B     : std_logic_vector(7 downto 0);
   signal i_P_nCS    : std_logic_vector(3 downto 0);
   signal i_P_RnW    : std_logic;
   signal i_P_nRST   : std_logic;
   signal i_P_SER_TX : std_logic;
   signal i_P_SER_RTS: std_logic;

   signal i_nADLC    : std_logic;
   signal i_nKBPAWR  : std_logic;
   signal i_nIC32WR  : std_logic;
   signal i_nPGFC    : std_logic;
   signal i_nPGFD    : std_logic;
   signal i_nFDC     : std_logic;
   signal i_nTUBE    : std_logic;
   signal i_nFDCONWR : std_logic;
   signal i_nVIAB    : std_logic;
begin

   e_U6:entity work.LS74245
   generic map (
      -- rough ACT numbers
      tprop       => 6 ns, 
      toe         => 9 ns,
      ttr         => 12 ns -- 7 ns for F -- this is a guess, no info on datasheet
   )
   port map (
      A           => i_P_D,
      B           => MIO_io,
      dirA2BnB2A  => i_P_RnW,
      nOE         => MIO_D_nOE_i
   );

   e_U7:entity work.cy74FCT2543
   port map(
      A         => MIO_io,
      B         => i_P_A,

      nOEAB     => '0',
      nLEAB     => MIO_nALE_i,
      nCEAB     => '0',

      nOEBA     => '1',
      nLEBA     => '1',
      nCEBA     => '1'

    );

   e_U8:entity work.cy74FCT2543
   port map(
      A         => MIO_io,
      B         => i_U8_B,
      nOEAB     => '0',
      nLEAB     => MIO_O0_nOE_i,
      nCEAB     => '0',

      nOEBA     => '1',
      nLEBA     => '1',
      nCEBA     => '1'

    );

   (  3 downto 0 => i_P_nCS,
      4 => i_P_RnW,
      5 => i_P_nRST,
      6 => i_P_SER_TX,
      7 => i_P_SER_RTS
   ) <= i_U8_B;



   e_csel:entity work.periphs_csel
   port map (
      clk_2MHzE_i    => clk_2MHz_E_i,
      nCS_i          => i_P_nCS,

      nADLC_o        => i_nADLC,
      nKBPAWR_o      => i_nKBPAWR,
      nIC32WR_o      => i_nIC32WR,
      nPGFC_o        => i_nPGFC,
      nPGFD_o        => i_nPGFD,
      nFDC_o         => i_nFDC,
      nTUBE_o        => i_nTUBE,
      nFDCONWR_o     => i_nFDCONWR,
      nVIAB_o        => i_nVIAB
   );



   -- mock devices

   e_floppy:entity work.floppy
   port map (
      A_i         => i_P_A(1 downto 0),
      D_io        => i_P_D,
      RnW_i       => i_P_RnW,
      nRST_i      => i_P_nRST,
      nFDC_i      => i_nFDC,
      nFDCON_i    => i_nFDCONWR,
      NMI_o       => open,       -- UNTESTED
      CLK8_i      => '1'         -- UNTESTED
   );


end rtl;
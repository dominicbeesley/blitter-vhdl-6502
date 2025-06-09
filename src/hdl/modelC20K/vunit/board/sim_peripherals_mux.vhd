library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library fmf;

entity sim_peripherals_mux is
   port(

      -- signals to/from FPGA

      clk_2MHz_E_i   :  in    std_logic;
      clk_1MHz_E_i   :  in    std_logic;
      
      MIO_io         :  inout std_logic_vector(7 downto 0);
      MIO_nALE_i     :  in    std_logic;
      MIO_D_nOE_i    :  in    std_logic;
      MIO_I0_nOE_i   :  in    std_logic;
      MIO_I1_nOE_i   :  in    std_logic;
      MIO_O0_nOE_i   :  in    std_logic;
      MIO_O1_nOE_i   :  in    std_logic;


      -- signals to/from multiplex

      P_D_io         : inout  std_logic_vector(7 downto 0);
      P_A_o          : out    std_logic_vector(7 downto 0);
      

      -- MIO_O0 phase
      P_RnW_o        : out std_logic;
      P_nRST_o       : out std_logic;
      P_SER_TX_o     : out std_logic;
      P_SER_RTS_o    : out std_logic;

      nADLC_o        : out std_logic;
      nKBPAWR_o      : out std_logic;
      nIC32WR_o      : out std_logic;
      nPGFC_o        : out std_logic;
      nPGFD_o        : out std_logic;
      nFDC_o         : out std_logic;
      nTUBE_o        : out std_logic;
      nFDCONWR_o     : out std_logic;
      nVIAB_o        : out std_logic;

      -- MIO_I0 phase

      ser_cts_i      : in std_logic;
      ser_rx_i       : in std_logic;
      d_cas_i        : in std_logic;
      kb_nRST_i      : in std_logic;
      kb_CA2_i       : in std_logic;
      netint_i       : in std_logic;
      irq_i          : in std_logic;
      nmi_i          : in std_logic;      

      -- MIO_O1 phase
      j_ds_nCS2_o    : out std_logic;
      j_ds_nCS1_o    : out std_logic;
      j_spi_clk_o    : out std_logic;
      VID_VS_o       : out std_logic;
      VID_HS_o       : out std_logic;
      VID_CS_o       : out std_logic;
      j_spi_mosi_o   : out std_logic;
      j_adc_nCS_o    : out std_logic;

      -- MIO_I0 phase
      j_i0_i         : in std_logic;
      j_i1_i         : in std_logic;
      j_spi_miso_i   : in std_logic;
      btn0_i         : in std_logic;
      btn1_i         : in std_logic;
      btn2_i         : in std_logic;
      btn3_i         : in std_logic;
      kb_pa7_i       : in std_logic
      
   );
end sim_peripherals_mux;

architecture rtl of sim_peripherals_mux is
   

   signal i_U8_B     : std_logic_vector(7 downto 0);
   signal i_U4_B     : std_logic_vector(7 downto 0);
   signal i_U19_B     : std_logic_vector(7 downto 0);
   signal i_U20_B     : std_logic_vector(7 downto 0);
   signal i_P_nCS    : std_logic_vector(3 downto 0);
   signal i_P_RnW    : std_logic;

begin

   e_U6:entity work.LS74245
   generic map (
      -- rough ACT numbers
      tprop       => 6 ns, 
      toe         => 9 ns,
      ttr         => 12 ns -- 7 ns for F -- this is a guess, no info on datasheet
   )
   port map (
      A           => P_D_io,
      B           => MIO_io,
      dirA2BnB2A  => i_P_RnW,
      nOE         => MIO_D_nOE_i
   );

   e_U7:entity work.cy74FCT2543
   port map(
      A         => MIO_io,
      B         => P_A_o,

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
      5 => P_nRST_o,
      6 => P_SER_TX_o,
      7 => P_SER_RTS_o
   ) <= i_U8_B;

   e_U4:entity work.cy74FCT2543
   port map(
      A         => MIO_io,
      B         => i_U4_B,
      nOEAB     => '1',
      nLEAB     => '1',
      nCEAB     => '1',

      nOEBA     => MIO_I0_nOE_i,
      nLEBA     => '0',
      nCEBA     => '0'

    );

   P_RnW_o <= i_P_RnW;


   i_U4_B <=
   (  0 => ser_cts_i,
      1 => ser_rx_i,
      2 => d_cas_i,
      3 => kb_nRST_i,
      4 => kb_CA2_i,
      5 => netint_i,
      6 => irq_i,
      7 => nmi_i
   );


   e_U19:entity work.cy74FCT2543
   port map(
      A         => MIO_io,
      B         => i_U19_B,
      nOEAB     => '0',
      nLEAB     => MIO_O1_nOE_i,
      nCEAB     => '0',

      nOEBA     => '1',
      nLEBA     => '1',
      nCEBA     => '1'

    );

   
   j_adc_nCS_o <= i_U19_B(7);
   j_spi_mosi_o <= i_U19_B(6);
   VID_CS_o <= i_U19_B(5);
   VID_HS_o <= i_U19_B(4);
   VID_VS_o <= i_U19_B(3);
   j_spi_clk_o <= i_U19_B(2);
   j_ds_nCS1_o <= i_U19_B(1);
   j_ds_nCS2_o <= i_U19_B(0);


   e_U20:entity work.cy74FCT2543
   port map(
      A         => MIO_io,
      B         => i_U20_B,
      nOEAB     => '1',
      nLEAB     => '1',
      nCEAB     => '1',

      nOEBA     => MIO_I1_nOE_i,
      nLEBA     => '0',
      nCEBA     => '0'

    );

   i_U20_B <=
   (  0 => j_i0_i,
      1 => j_i1_i,
      2 => j_spi_miso_i,
      3 => btn0_i,
      4 => btn1_i,
      5 => btn2_i,
      6 => btn3_i,
      7 => kb_pa7_i
   );



   e_csel:entity work.sim_peripherals_csel
   port map (
      clk_2MHzE_i    => clk_2MHz_E_i,
      nCS_i          => i_P_nCS,

      nADLC_o        => nADLC_o,
      nKBPAWR_o      => nKBPAWR_o,
      nIC32WR_o      => nIC32WR_o,
      nPGFC_o        => nPGFC_o,
      nPGFD_o        => nPGFD_o,
      nFDC_o         => nFDC_o,
      nTUBE_o        => nTUBE_o,
      nFDCONWR_o     => nFDCONWR_o,
      nVIAB_o        => nVIAB_o
   );


end rtl;
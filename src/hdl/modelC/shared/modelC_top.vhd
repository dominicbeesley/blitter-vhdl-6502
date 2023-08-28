-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2023 Dominic Beesley https://github.com/dominicbeesley
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


-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	17/8/2023
-- Design Name: 
-- Module Name:    	Model C top level design
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--use work.mk1board_types.all;

library work;

entity modelC is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural := 128;								-- fast clock speed in mhz				
		G_JIM_DEVNO							: std_logic_vector(7 downto 0) := x"D1"
	);
	port(
		-- crystal osc 27Mhz - on WS board
		CLK_27M_i							: in		std_logic;
		-- crystal osc 48MHz - on Motherboard
		CLK_48M_i							: in		std_logic;

		-- 2M RAM/256K ROM bus (45)
		MEM_A_o								: out		std_logic_vector(20 downto 8);
		MEM_AD_io							: inout	std_logic_vector(7 downto 0);	-- 17 bit RAMs used but D[7..0] is multiplexed with D[15..8]
		MEM_nOE_o							: out		std_logic;
		MEM_nWE_o							: out		std_logic;							-- add external pull-up
		MEM_ALE_o							: out		std_logic;							-- add external pull-up

		MEM_FL_nCE_o						: out		std_logic;				
		MEM_RAM_nCE_o						: out		std_logic_vector(1 downto 0);
		
		-- 1 bit DAC sound out stereo, aux connectors mirror main (2)
		SND_L_o								: out		std_logic;
		SND_R_o								: out		std_logic;

		-- hdmi (11)

		HDMI_SCL_io							: inout	std_logic;
		HDMI_SDA_io							: inout	std_logic;
		HDMI_HPD_i							: in		std_logic;
		HDMI_CEC_io							: inout	std_logic;
		HDMI_CK_p_o							: out		std_logic;
		HDMI_CK_n_o							: out		std_logic;
		HDMI_D0_p_o							: out		std_logic;
		HDMI_D0_n_o							: out		std_logic;
		HDMI_D1_p_o							: out		std_logic;
		HDMI_D1_n_o							: out		std_logic;
		HDMI_D2_p_o							: out		std_logic;
		HDMI_D2_n_o							: out		std_logic;
		
		-- sdcard (5)
		SD_CS_o								: out		std_logic;
		SD_CLK_o								: out		std_logic;
		SD_MOSI_o							: out		std_logic;
		SD_MISO_i							: in		std_logic;
		SD_DET_i								: in		std_logic;

		-- SYS bus connects to SYStem CPU socket (38)

		SUP_nRESET_i						: in		std_logic;								-- SYStem reset after supervisor

		SYS_RnW_io							: inout	std_logic;
		SYS_A_o								: out		std_logic_vector(15 downto 0);
		SYS_D_io								: inout	std_logic_vector(7 downto 0);
		--SYS_BUF_D_DIR_o					: out		std_logic; -- use SYS_RnW?!?
		SYS_BUF_D_nOE_o					: out		std_logic;
		
		SYS_2MHzE_o							: out		std_logic;
		SYS_1MHzE_o							: out		std_logic;
		SYS_nPGFC_o							: out		std_logic;
		SYS_nPGFD_o							: out		std_logic;
		SYS_nPGFE_o							: out		std_logic;

		-- test these as outputs!!!
		SYS_nNMI_i							: inout	std_logic;		-- open drain
		SYS_nIRQ_i							: inout	std_logic;		-- open drain
		SYS_nRES_o							: out		std_logic;		-- open drain?

		-- CPU signals to/from 65816 that aren't shared with SYS bus
		--CPU_nML_i							: in		std_logic; -- only use if a pin is spare!
		CPU_nVP_i							: in		std_logic;
		CPU_E_i								: in		std_logic;
		CPU_VPA_i							: in		std_logic;
		CPU_VDA_i							: in		std_logic;
		--CPU_MX_i								: in		std_logic; 	-- only used for debugging

		CPU_BE_o								: out		std_logic;
		CPU_nABORT_o						: out		std_logic;
		CPU_PHI2_o							: out		std_logic;
		CPU_RDY_o							: out		std_logic;		-- keep but can drop in favour of clock stretch
		
		-- i2c EEPROM (2)
		I2C_SCL_io							: inout	std_logic;
		I2C_SDA_io							: inout	std_logic;


		-- cpu / expansion sockets (56)


		-- ddr 
		ddr_addr								: out		std_logic_vector (13 downto 0)        ;       -- ROW_WIDTH=14
		ddr_bank								: out		std_logic_vector (2 downto 0)         ;       -- BANK_WIDTH=3
		ddr_cs								: out		std_logic;
		ddr_ras								: out		std_logic;
		ddr_cas								: out		std_logic;
		ddr_we								: out		std_logic;
		ddr_ck								: out		std_logic;
		--ddr_ck_n								: out		std_logic;
		ddr_cke								: out		std_logic;
		ddr_odt								: out		std_logic;
		ddr_reset_n							: out		std_logic;
		ddr_dm								: out		std_logic_vector (1 downto 0)         ;      -- DM_WIDTH=2
		ddr_dq								: inout	std_logic_vector (15 downto 0)        ;      -- DQ_WIDTH=16
		ddr_dqs								: inout	std_logic_vector (1 downto 0)               -- DQS_WIDTH=2
		--ddr_dqs_n							: inout	std_logic_vector (1 downto 0)               -- DQS_WIDTH=2

	);
end modelC;

architecture rtl of modelC is

	component ELVDS_OBUF
	port (
		I : in std_logic;
		O : out std_logic;
		OB : out std_logic
	);
	end component;

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


	signal serialized_c	:	std_logic;
	signal serialized_r	:	std_logic;
	signal serialized_g	:	std_logic;
	signal serialized_b	:	std_logic;
	
	signal i_clk_135		: 	std_logic;

begin

	e_pll27:entity work.pll27
	port map (
        clkin => CLK_27M_i,
        clkout => i_clk_135
   );


        ser_b : OSER10
            generic map (
                GSREN => "false",
                LSREN => "true"
            )
            port map(
                PCLK  => CLK_27M_i,
                FCLK  => i_clk_135,
                RESET => '0',
                Q     => serialized_b,
                D0    => '1',
                D1    => '0',
                D2    => '1',
                D3    => '0',
                D4    => '1',
                D5    => '1',
                D6    => '0',
                D7    => '0',
                D8    => '1',
                D9    => '1'
            );


        -- Encode the 1-bit serialized TMDS streams to Low-voltage differential signaling (LVDS) HDMI output pins

        OBUFDS_c : ELVDS_OBUF
            port map (
                I  => serialized_c,
                O  => HDMI_CK_p_o,
                OB => HDMI_CK_n_o
             );

        OBUFDS_b : ELVDS_OBUF
            port map (
                I  => serialized_b,
                O  => HDMI_D0_p_o,
                OB => HDMI_D0_n_o
            );

        OBUFDS_g : ELVDS_OBUF
            port map (
                I  => serialized_g,
                O  => HDMI_D1_p_o,
                OB => HDMI_D1_n_o
            );

        OBUFDS_r : ELVDS_OBUF
            port map (
                I  => serialized_r,
                O  => HDMI_D2_p_o,
                OB => HDMI_D2_n_o
            );

			-- DDR


end rtl;

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


-- Company: 				Dossytronics
-- Engineer: 				Dominic Beesley
-- 
-- Create Date:    		31/5/2023
-- Design Name: 
-- Module Name:    		work.real386ex_tb
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 			mimic the external behaviour of a 386ex CPU
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: CAUTION: this is very much a work in progress and
--								only mimics the most basic parts of a 386ex
--								
--
----------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity real386ex_tb is
	port(

		CPUSKT_nSMI_i			: in  	std_logic;
		CPUSKT_DRQ_i			: in  	std_logic;
		CPUSKT_CLK2_i			: in  	std_logic;
		CPUSKT_nINT0_i			: in  	std_logic;
		CPUSKT_nNMI_i			: in  	std_logic;
		CPUSKT_RESET_i			: in  	std_logic;
		CPUSKT_nNA_i			: in  	std_logic;

		CPUSKT_D_io				: inout	std_logic_vector(15 downto 0);
		CPUSKT_nREADY_io		: inout	std_logic;

		CPUSKT_WnR_o			: out		std_logic;
		CPUSKT_nBHE_o			: out		std_logic;
		CPUSKT_MnIO_o			: out		std_logic;
		CPUSKT_DnC_o			: out		std_logic;
		CPUSKT_nADS_o			: out		std_logic;
		CPUSKT_nLBA_o			: out		std_logic;
		CPUSKT_nREFRESH_o		: out		std_logic;
		CPUSKT_CLKOUT_o		: out		std_logic;
		CPUSKT_nSMIACT_o		: out		std_logic;
		CPUSKT_nUCS_o			: out		std_logic;

		CPUSKT_A_o				: out 	std_logic_vector(23 downto 0)


	);
end real386ex_tb;

architecture behavioral of real386ex_tb is

	signal i_core_o_BE_n		: std_logic_vector(3 downto 0);
	signal i_core_o_Address	: std_logic_vector(31 downto 2);
	signal i_core_o_W_R_n	: std_logic;
	signal i_core_o_D_C_n	: std_logic;
	signal i_core_o_M_IO_n	: std_logic;
	signal i_core_o_LOCK_n	: std_logic;
	signal i_core_o_ADS_n	: std_logic;
	signal i_core_o_HLDA		: std_logic;

	signal i_core_data_x		: std_logic_vector(31 downto 16);

	signal i_core_i_CLK2		: std_logic;
	signal i_core_i_NA_n		: std_logic;
	signal i_core_i_BS16_n	: std_logic;
	signal i_core_i_READY_n	: std_logic;
	signal i_core_i_HOLD		: std_logic;
	signal i_core_i_PERQ		: std_logic;
	signal i_core_i_BUSY_n	: std_logic;
	signal i_core_i_ERROR_n	: std_logic;
	signal i_core_i_INTR		: std_logic;
	signal i_core_i_NMI		: std_logic;
	signal i_core_i_RESET	: std_logic;

	signal i_hi_bus			: std_logic;
	signal i_lo_bus			: std_logic;
	
	signal i_BLE				: std_logic;
	signal i_BHE				: std_logic;

begin

	i_hi_bus <= '1' when i_core_o_BE_n(3) = '0' or i_core_o_BE_n(2) = '0' else
					'0';
	i_lo_bus <= '1' when i_core_o_BE_n(1) = '0' or i_core_o_BE_n(0) = '0' else
					'0';

	i_core_i_BS16_n <= 	'0' when i_hi_bus = '1' else
								'1';

	i_BLE <= i_core_o_BE_n(0) when i_lo_bus = '1' else
				i_core_o_BE_n(2);

	i_BHE <= i_core_o_BE_n(1) when i_lo_bus = '1' else
				i_core_o_BE_n(3);

	CPUSKT_A_o 			<= i_core_o_Address(23 downto 2) & not(i_lo_bus) & i_BLE;
	CPUSKT_nBHE_o		<= i_BHE;

	p_clkout:process
	begin
		wait until rising_edge(CPUSKT_CLK2_i);
		CPUSKT_CLKOUT_o <= '0';
		wait until rising_edge(CPUSKT_CLK2_i);
		CPUSKT_CLKOUT_o <= '1';

	end process;

	i_core_i_RESET <= CPUSKT_RESET_i;
	i_core_i_INTR <= not CPUSKT_nINT0_i;
	i_core_i_NMI <= not CPUSKT_nNMI_i;
	i_core_i_CLK2 <= CPUSKT_CLK2_i;
	i_core_i_NA_n <= CPUSKT_nNA_i;
	i_core_i_READY_n <= CPUSKT_nREADY_io;
	i_core_i_HOLD <= '0';
	i_core_i_PERQ <= '0';
	i_core_i_BUSY_n <= '1';
	i_core_i_ERROR_n <= '1';

	CPUSKT_WnR_o		<= i_core_o_W_R_n;
	CPUSKT_MnIO_o		<= i_core_o_M_IO_n;
	CPUSKT_DnC_o		<= i_core_o_D_C_n;
	CPUSKT_nADS_o		<= i_core_o_ADS_n;
	CPUSKT_nLBA_o		<= '1';
	CPUSKT_nREFRESH_o	<= '1';
	CPUSKT_nSMIACT_o	<= '1';
	CPUSKT_nUCS_o		<= '1';

	CPUSKT_nREADY_io  <= 'Z';

	e_i386_core:entity work.i80386
   generic map (
   	Debug => false,
		Inst => true,
      Performance => 1,
		Speed => 32)

	port map (
    	BE_n			=> i_core_o_BE_n,
		Address		=> i_core_o_Address,
		W_R_n			=> i_core_o_W_R_n,
		D_C_n			=> i_core_o_D_C_n,
		M_IO_n		=> i_core_o_M_IO_n,
		LOCK_n		=> i_core_o_LOCK_n,
		ADS_n			=> i_core_o_ADS_n,
		HLDA			=> i_core_o_HLDA,

		Data(15 downto 0)
						=> CPUSKT_D_io,
		Data(31 downto 16)
						=> i_core_data_x,
		
		CLK2			=> i_core_i_CLK2,
		NA_n			=> i_core_i_NA_n,
		BS16_n		=> i_core_i_BS16_n,
		READY_n		=> i_core_i_READY_n,
		HOLD			=> i_core_i_HOLD,
		PERQ			=> i_core_i_PERQ,
		BUSY_n		=> i_core_i_BUSY_n,
		ERROR_n		=> i_core_i_ERROR_n,
		INTR			=> i_core_i_INTR,
		NMI			=> i_core_i_NMI,
		RESET			=> i_core_i_RESET

		);

	i_core_data_x <= (others => 'H');

end behavioral;
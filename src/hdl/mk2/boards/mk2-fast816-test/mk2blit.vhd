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
-- Create Date:    	7/11/2023
-- Design Name: 
-- Module Name:    	dip 40 blitter - mk2 product board
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		PoC blitter and 6502/6809/Z80/68008 cpu board with 2M RAM, 256k ROM - fast 65816 only implementation
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


library work;
use work.common.all;

entity mk2blit is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural := 128;								-- fast clock speed in mhz				
		G_JIM_DEVNO							: std_logic_vector(7 downto 0) := x"D1"
	);
	port(
		-- crystal osc 48MHz - not fitted on blit board
		CLK_48M_i							: in		std_logic;	

		-- crystal osc 50Mhz - on WS board
		CLK_50M_i							: in		std_logic;
	
		-- 2M RAM/256K ROM bus
		MEM_A_o								: out		std_logic_vector(20 downto 0);
		MEM_D_io								: inout	std_logic_vector(7 downto 0);
		MEM_nOE_o							: out		std_logic;
		MEM_ROM_nWE_o						: out		std_logic;
		MEM_RAM_nWE_o						: out		std_logic;
		MEM_ROM_nCE_o						: out		std_logic;
		MEM_RAM0_nCE_o						: out		std_logic;
		
		-- 1 bit DAC sound out stereo, aux connectors mirror main
		SND_BITS_L_o						: out		std_logic;
		SND_BITS_L_AUX_o					: out		std_logic;
		SND_BITS_R_o						: out		std_logic;
		SND_BITS_R_AUX_o					: out		std_logic;
		
		-- 	SYS bus connects to SYStem CPU socket


		SUP_nRESET_i						: in		std_logic;								-- SYStem reset after supervisor
		EXT_nRESET_i						: in		std_logic;								-- WS button

		SYS_A_o								: out		std_logic_vector(15 downto 0);
		SYS_D_io								: inout	std_logic_vector(7 downto 0);
		
		-- SYS signals are connected direct to the BBC cpu socket
		SYS_RDY_i							: in		std_logic; -- Master only?
		SYS_nNMI_i							: in		std_logic;
		SYS_nIRQ_i							: in		std_logic;
		SYS_SYNC_o							: out		std_logic;
		SYS_PHI0_i							: in		std_logic;
		SYS_PHI1_o							: out		std_logic;
		SYS_PHI2_o							: out		std_logic;
		SYS_RnW_o							: out		std_logic;


		-- CPU sockets, shared lines for 6502/65102/65816/6809,Z80,68008
		-- shared names are of the form CPUSKT_aaa[C[bbb][6ccc][9ddd][Keee][Zfff]
		-- aaa = NMOS 6502 and other 6502 derivatives (65c02, 65816) unless overridden
		-- bbb = CMOS 65C102-(if directly followed by 6ccc use that interpretation)
		-- ccc = WDC 65816	
		-- ddd = 6309/6809
		-- eee = Z80
		-- fff = MC68008

		-- NC indicates Not Connected in a mode

		CPUSKT_A_i									: in		std_logic_vector(19 downto 0);
		CPUSKT_D_io									: inout  std_logic_vector(7 downto 0);

		CPUSKT_6EKEZnRD_i							: in		std_logic;		
		CPUSKT_C6nML9BUSYKnBGZnBUSACK_i		: in		std_logic;
		CPUSKT_RnWZnWR_i							: in		std_logic;
		CPUSKT_PHI16ABRT9BSKnDS_i				: in		std_logic;		-- 6ABRT is actually an output but pulled up on the board
		CPUSKT_PHI26VDAKFC0ZnMREQ_i			: in		std_logic;
		CPUSKT_SYNC6VPA9LICKFC2ZnM1_i			: in		std_logic;
		CPUSKT_VSS6VPB9BAKnAS_i					: in		std_logic;
		CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i		: in		std_logic;		-- nSO is actually an output but pulled up on the board


		CPUSKT_6BE9TSCKnVPA_o					: out		std_logic;
		CPUSKT_9Q_o									: out		std_logic;
		CPUSKT_KnBRZnBUSREQ_o					: out		std_logic;
		CPUSKT_PHI09EKZCLK_o						: out		std_logic;
		CPUSKT_RDY9KnHALTZnWAIT_o				: out		std_logic;
		CPUSKT_nIRQKnIPL1_o						: out		std_logic;
		CPUSKT_nNMIKnIPL02_o						: out		std_logic;
		CPUSKT_nRES_o								: out		std_logic;
		CPUSKT_9nFIRQLnDTACK_o					: out		std_logic;

		-- LEDs 
		LED_o										: out		std_logic_vector(3 downto 0);

		-- CONFIG / TEST connector

		CFG_io									: inout	std_logic_vector(15 downto 0);

		-- i2c EEPROM
		I2C_SCL_io								: inout		std_logic;
		I2C_SDA_io							: inout	std_logic

	);
end mk2blit;

architecture rtl of mk2blit is


component pllmain
   PORT
   (
      areset      : IN STD_LOGIC  := '0';
      inclk0      : IN STD_LOGIC  := '0';
      c0    : OUT STD_LOGIC ;
      locked      : OUT STD_LOGIC 
   );
end component;

   signal i_fast_clk           : std_logic;
   signal i_pll_locked        : std_logic;

	signal r_rst					: std_logic;

	signal i_W_CPU_D_i			: std_logic_vector(7 downto 0);
	signal i_W_CPU_D_o			: std_logic_vector(7 downto 0);
	signal i_W_CPU_A				: std_logic_vector(23 downto 0);
	signal i_W_CPU_RnW			: std_logic;

	signal i_W_CPU_req			: std_logic;
	signal i_W_CPU_ack			: std_logic;

begin

pll:pllmain 
port map (
   areset => not SUP_nRESET_i,
   inclk0 => CLK_50M_i,
   c0     => i_fast_clk,
   locked => i_pll_locked
);

p_reset:process(i_pll_locked, SUP_nRESET_i, i_fast_clk)
variable v_ctdn: unsigned(7 downto 0);
begin
	if i_pll_locked = '0' or SUP_nRESET_i = '0' then
		r_rst <= '1';
		v_ctdn := (others => '0');
	elsif rising_edge(i_fast_clk) then
		if r_rst = '1' then
			if v_ctdn(v_ctdn'high) = '1' then
				r_rst <= '0';
			else
				v_ctdn := v_ctdn + 1;
			end if;
		end if;
	end if;
end process;

--===================================== SYS ==============================================

e_syswrap:entity work.syswrap
generic map (
		SIM									=> SIM,
		CLOCKSPEED							=> CLOCKSPEED
	)
port map (
		clk_i									=> i_fast_clk,
		rst_i									=> r_rst,

		-- motherboard signals

		SYS_A_o								=> SYS_A_o,
		SYS_D_io								=> SYS_D_io,
		SYS_RDY_i							=> SYS_RDY_i,
		SYS_SYNC_o							=> SYS_SYNC_o,
		SYS_PHI0_i							=> SYS_PHI0_i,
		SYS_PHI1_o							=> SYS_PHI1_o,
		SYS_PHI2_o							=> SYS_PHI2_o,
		SYS_RnW_o							=> SYS_RnW_o,

		-- data access signals

		W_D_i					   			=> i_W_CPU_D_o,
		W_D_o					   			=> i_W_CPU_D_i,
		W_A_i	   							=> i_W_CPU_A(15 downto 0),
		W_RnW_i			   				=> i_W_CPU_RnW,

		W_req_i			   				=> i_W_CPU_req,
		W_ack_o								=> i_W_CPU_ack
	);

--===================================== CPU ==============================================

	cpuwrap:entity work.cpuwrap816
	generic map (
		SIM									=> SIM,
		CLOCKSPEED							=> CLOCKSPEED
	)
	port map (
		clk_i										=> i_fast_clk,
		rst_i										=> r_rst,

		CPUSKT_A_i								=> CPUSKT_A_i,
		CPUSKT_D_io								=> CPUSKT_D_io,

		CPUSKT_E_i								=> CPUSKT_6EKEZnRD_i,
		CPUSKT_nML_i							=> CPUSKT_C6nML9BUSYKnBGZnBUSACK_i,
		CPUSKT_RnW_i							=> CPUSKT_RnWZnWR_i,
		CPUSKT_nABRT_i							=> CPUSKT_PHI16ABRT9BSKnDS_i,
		CPUSKT_VDA_i							=> CPUSKT_PHI26VDAKFC0ZnMREQ_i,
		CPUSKT_VPA_i							=> CPUSKT_SYNC6VPA9LICKFC2ZnM1_i,
		CPUSKT_nVP_i							=> CPUSKT_VSS6VPB9BAKnAS_i,
		CPUSKT_MX_i								=> CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i,


		CPUSKT_BE_o								=> CPUSKT_6BE9TSCKnVPA_o,
		CPUSKT_PHI2_o							=> CPUSKT_PHI09EKZCLK_o,
		CPUSKT_RDY_o							=> CPUSKT_RDY9KnHALTZnWAIT_o,
		CPUSKT_nIRQ_o							=> CPUSKT_nIRQKnIPL1_o,
		CPUSKT_nNMI_o							=> CPUSKT_nNMIKnIPL02_o,
		CPUSKT_nRES_o							=> CPUSKT_nRES_o,

		SYS_nIRQ_i								=> SYS_nIRQ_i,
		SYS_nNMI_i								=> SYS_nNMI_i,

		W_D_i					   				=> i_W_CPU_D_i,
		W_D_o					   				=> i_W_CPU_D_o,
		W_A_o	   								=> i_W_CPU_A,
		W_RnW_o			   					=> i_W_CPU_RnW,

		W_req_o			   					=> i_W_CPU_req,
		W_ack_i									=> i_W_CPU_ack

	);

	CPUSKT_9Q_o							<= '1';
	CPUSKT_KnBRZnBUSREQ_o			<= '1';
	CPUSKT_9nFIRQLnDTACK_o			<= '1';



-- unused stuff

      -- 2M RAM/256K ROM bus (45)
      MEM_A_o                       <= (others => '0');
      MEM_D_io                      <= (others => 'Z');
      MEM_nOE_o                     <= '1';
      MEM_ROM_nWE_o                 <= '1';
      MEM_RAM_nWE_o                 <= '1';
      MEM_ROM_nCE_o                 <= '1';
      MEM_RAM0_nCE_o                <= '1';
      
      -- 1 bit DAC sound out stereo, aux connectors mirror main (2)
      SND_BITS_L_o                  <= '1';
      SND_BITS_R_o                  <= '1';
      SND_BITS_L_AUX_o              <= '1';
      SND_BITS_R_AUX_o              <= '1';


      -- i2c EEPROM (2)
      I2C_SCL_io                    <= '1';
      I2C_SDA_io                    <= '1';

	  	
		CFG_io								<= (others => 'Z');

      -- LEDs 
      LED_o                         <= (others => '1');

end rtl;

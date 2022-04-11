----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	23/3/2018
-- Design Name: 
-- Module Name:    	test bench for dmac blitter on mk2 board a "real" 65816
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		For mk1 board simulation
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--  This test bench emulates a cut-down BBC micro with a single 16k MOS ROM
--  and 32k RAM, hardware at FC00-FEFF does nothing special other than return 
--  'X', one special register at FEFF is used to terminate the simulation
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sim_65816_tb is
generic (
	G_MOSROMFILE : string := "../../../../simulation/sim_asm/test_asm/build/blit-bringup2-rom0.rom"
	);
end sim_65816_tb;

architecture Behavioral of sim_65816_tb is

	signal	sim_ENDSIM			: 	std_logic 		:= '0';
	
	signal	i_EXT_CLK_48M		: 	std_logic;
	signal	i_EXT_CLK_50M		: 	std_logic;

	signal	sim_dump_ram		:	std_logic;
	signal	sim_reg_halt 		:  std_logic;
	
	signal	i_SUP_nRESET		:	std_logic;
	signal	i_EXT_nRESET		:	std_logic;

	signal	i_SYS_phi0			:  std_logic;
	signal	i_SYS_phi1			:  std_logic;
	signal	i_SYS_phi2			:  std_logic;
	signal	i_SYS_A				:	std_logic_vector(15 downto 0);
	signal	i_SYS_D				:	std_logic_vector(7 downto 0);
	signal	i_SYS_RnW			: std_logic;
	signal	i_SYS_nNMI			: std_logic;
	signal	i_SYS_nIRQ			: std_logic;
	signal	i_SYS_SYNC			: std_logic;


	signal	i_MEM_A					:	std_logic_vector(20 downto 0);
	signal	i_MEM_D					:	std_logic_vector(7 downto 0);
	signal	i_MEM_nOE				:	std_logic;
	signal	i_MEM_ROM_nWE			:	std_logic;
	signal	i_MEM_RAM_nWE			:	std_logic;
	signal	i_MEM_ROM_nCE			:	std_logic;
	signal	i_MEM_RAM0_nCE		:	std_logic;



	signal	i_CFG					: std_logic_vector(15 downto 0);
	signal	i_hsync									:  std_logic;
	signal	i_vsync									:  std_logic;


	signal	i_CPU_A									:	std_logic_vector(19 downto 0);
	signal	i_CPU_D									:  std_logic_vector(7 downto 0);
	signal	i_CPU_6EKEZnRD							:	std_logic;		
	signal	i_CPU_C6nML9BUSYKnBGZnBUSACK		:	std_logic;
	signal	i_CPU_RnWZnWR							:	std_logic;
	signal	i_CPU_PHI16ABRT9BSKnDS				:	std_logic;		-- 6ABRT is actually an output but pulled up on the board
	signal	i_CPU_PHI26VDAKFC0ZnMREQ			:	std_logic;
	signal	i_CPU_SYNC6VPA9LICKFC2ZnM1			:	std_logic;
	signal	i_CPU_VSS6VPA9BAKnAS					:	std_logic;
	signal	i_CPU_nSO6MX9AVMAKFC1ZnIOREQ		:	std_logic;		-- nSO is actually an output but pulled up on the board
	signal	i_CPU_6BE9TSCKnVPA					:	std_logic;
	signal	i_CPU_9Q									:	std_logic;
	signal	i_CPU_KnBRZnBUSREQ					:	std_logic;
	signal	i_CPU_PHI09EKZCLK						:	std_logic;
	signal	i_CPU_RDY9KnHALTZnWAIT				:	std_logic;
	signal	i_CPU_nIRQKnIPL1						:	std_logic;
	signal	i_CPU_nNMIKnIPL02						:	std_logic;
	signal	i_CPU_nRES								:	std_logic;
	signal	i_CPU_9nFIRQLnDTACK					:	std_logic;

begin
	

	i_CFG <= (
	0				=>	'1',	-- don't use t65 core
	3 downto 1 	=> "001", -- 65816 @ 8MHz
	4 				=> '1', -- swromx off
	7				=> '1', -- debug button
	8				=> '1', -- onboard swrom/ram enable
	14				=> i_vsync,
	15				=> i_hsync,
	others		=> 'H');

	i_CPU_nSO6MX9AVMAKFC1ZnIOREQ <= 'H';

	e_daughter: entity work.mk2blit
	generic map (
		SIM => true
	)
	port map (
		CLK_48M_i							=> i_EXT_CLK_48M,
		CLK_50M_i							=> i_EXT_CLK_50M,

				-- 1M RAM/512K ROM bus
		MEM_A_o								=> i_MEM_A,
		MEM_D_io								=> i_MEM_D,
		MEM_nOE_o							=> i_MEM_nOE,
		MEM_ROM_nWE_o						=> i_MEM_ROM_nWE,
		MEM_RAM_nWE_o						=> i_MEM_RAM_nWE,
		MEM_ROM_nCE_o						=> i_MEM_ROM_nCE,
		MEM_RAM0_nCE_o						=> i_MEM_RAM0_nCE,
		
		-- 1 bit DAC sound out
		SND_BITS_L_o						=> open,
		SND_BITS_R_o						=> open,
		SND_BITS_L_AUX_o					=> open,
		SND_BITS_R_AUX_o					=> open,

		SUP_nRESET_i						=> i_SUP_nRESET,
		EXT_nRESET_i						=> i_EXT_nRESET,
		
		SYS_A_o								=> i_SYS_A,
		SYS_D_io								=> i_SYS_D,
		
		SYS_SYNC_o 							=> i_SYS_SYNC,
		SYS_PHI1_o 							=> i_SYS_PHI1,
		SYS_PHI2_o 							=> i_SYS_PHI2,

		SYS_RnW_o 							=> i_SYS_RnW,
		SYS_RDY_i							=> '1',
		SYS_nNMI_i 							=> i_SYS_nNMI,
		SYS_nIRQ_i 							=> i_SYS_nIRQ,
		SYS_PHI0_i 							=> i_SYS_PHI0,
		I2C_SCL_io 							=> open,
		I2C_SDA_io 							=> open,

		-- CPU sockets, shared lines for 6502/65102/65816/6809,Z80,68008
		-- shared names are of the form CPUSKT_aaa[C[bbb][6ccc][9ddd][Keee][Zfff]
		-- aaa = NMOS 6502 and other 6502 derivatives (65c02, 65816) unless overridden
		-- bbb = CMOS 65C102-(if directly followed by 6ccc use that interpretation)
		-- ccc = WDC 65816	
		-- ddd = 6309/6809
		-- eee = Z80
		-- fff = MC68008

		-- NC indicates Not Connected in a mode

		CPUSKT_A_i								=> i_CPU_A,
		CPUSKT_D_io								=> i_CPU_D,
		CPUSKT_6EKEZnRD_i						=> i_CPU_6EKEZnRD, 
		CPUSKT_C6nML9BUSYKnBGZnBUSACK_i	=> i_CPU_C6nML9BUSYKnBGZnBUSACK, 
		CPUSKT_RnWZnWR_i						=> i_CPU_RnWZnWR,
		CPUSKT_PHI16ABRT9BSKnDS_i			=> i_CPU_PHI16ABRT9BSKnDS,
		CPUSKT_PHI26VDAKFC0ZnMREQ_i		=> i_CPU_PHI26VDAKFC0ZnMREQ,
		CPUSKT_SYNC6VPA9LICKFC2ZnM1_i		=> i_CPU_SYNC6VPA9LICKFC2ZnM1,
		CPUSKT_VSS6VPA9BAKnAS_i				=> i_CPU_VSS6VPA9BAKnAS, 
		CPUSKT_nSO6MX9AVMAKFC1ZnIOREQ_i	=> i_CPU_nSO6MX9AVMAKFC1ZnIOREQ, 
		CPUSKT_6BE9TSCKnVPA_o				=> i_CPU_6BE9TSCKnVPA,
		CPUSKT_9Q_o								=> i_CPU_9Q,
		CPUSKT_KnBRZnBUSREQ_o				=> i_CPU_KnBRZnBUSREQ,
		CPUSKT_PHI09EKZCLK_o					=> i_CPU_PHI09EKZCLK,
		CPUSKT_RDY9KnHALTZnWAIT_o			=> i_CPU_RDY9KnHALTZnWAIT,
		CPUSKT_nIRQKnIPL1_o					=> i_CPU_nIRQKnIPL1,
		CPUSKT_nNMIKnIPL02_o					=> i_CPU_nNMIKnIPL02,
		CPUSKT_nRES_o							=> i_CPU_nRES,
		CPUSKT_9nFIRQLnDTACK_o				=> i_CPU_9nFIRQLnDTACK,

		-- LEDs 
		LED_o									=> open,
		-- CONFIG / TEST connector
		CFG_io								=> i_CFG
		
	);



	e_cpu: entity work.real_65816_tb 
	--NMOS
	--CMOS - not really, just a bit quicker...
	--GENERIC MAP (
	--	dly_phi0a => 1 ns,
	--	dly_phi0b => 1 ns,
	--	dly_phi0c => 1 ns,
	--	dly_phi0d => 1 ns,
	--	dly_addr  => 10 ns, -- faster than spec!
	--	dly_dwrite=> 40 ns,	-- dwrite must be > dhold
	--	dly_dhold => 30 ns
	--)
	PORT MAP (
		A 			=> i_CPU_A(15 downto 0),
		D 			=> i_CPU_D,
		nRESET 	=> i_CPU_nRES,
		RDY 		=> i_CPU_RDY9KnHALTZnWAIT,
		nIRQ 		=> i_CPU_nIRQKnIPL1,
		nNMI 		=> i_CPU_nNMIKnIPL02,
		RnW 		=> i_CPU_RnWZnWR,
		BE			=> i_CPU_6BE9TSCKnVPA,
		VPA		=> i_CPU_SYNC6VPA9LICKFC2ZnM1,
		VPB		=> i_CPU_VSS6VPA9BAKnAS,
		VDA		=> i_CPU_PHI26VDAKFC0ZnMREQ,
		MX			=> i_CPU_nSO6MX9AVMAKFC1ZnIOREQ,
		E			=> i_CPU_6EKEZnRD,
		MLB		=> i_CPU_C6nML9BUSYKnBGZnBUSACK,
		PHI2 		=> i_CPU_PHI09EKZCLK
		);

	i_CPU_A(19 downto 16) <= (others => 'H');


	e_blit_ram_2048_0: entity work.ram_tb 
	generic map (
		size 			=> 2048*1024,
		dump_filename => "d:\\temp\\ram_dump_blit_dip40_poc-blitram.bin",
		tco => 55 ns,
		taa => 55 ns
	)
	port map (
		A				=> i_MEM_A(20 downto 0),
		D				=> i_MEM_D,
		nCS			=> i_MEM_RAM0_nCE,
		nOE			=> i_MEM_nOE,
		nWE			=> i_MEM_RAM_nWE,
		
		tst_dump		=> sim_dump_ram

	);

	--actually just the same ROM repeated!
	e_blit_rom_512: entity work.ram_tb 
	generic map (
		size 			=> 16*1024,
		dump_filename => "",
		romfile => G_MOSROMFILE,
		tco => 55 ns,
		taa => 55 ns
	)
	port map (
A				=> i_MEM_A(13 downto 0),
		D				=> i_MEM_D,
		nCS			=> i_MEM_ROM_nCE,
		nOE			=> i_MEM_nOE,
		nWE			=> i_MEM_ROM_nWE,		
		tst_dump		=> sim_dump_ram

	);



	i_EXT_CLK_48M <= 'H';
	i_EXT_nRESET <= 'H';

	main_clkc50: process
	begin
		if sim_ENDSIM='0' then
			i_EXT_CLK_50M <= '0';
			wait for 10 ns;
			i_EXT_CLK_50M <= '1';
			wait for 10 ns;
		else
			wait;
		end if;
	end process;

	
	stim: process
	variable usct : integer := 0;
	
	begin
			
			sim_dump_ram <= '0';
			i_SUP_nRESET <= '1';
			
			wait for 1034 ns;

			i_SUP_nRESET <= '0';
			
			wait for 1 ns;						
			wait for 20 us;
			i_SUP_nRESET <= '1';

			while usct < 200000 and sim_reg_halt /= '1' loop
				wait for 10 us;
				usct := usct + 1;
			end loop;
			
			
			sim_dump_ram <= '1';
			sim_ENDSIM <= '1';

			wait for 10 us;

			wait;
	end process;


end;
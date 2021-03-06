----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	23/3/2018
-- Design Name: 
-- Module Name:    	test bench for dmac blitter on mk2 board uising t65 core
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

entity sim_6502_tb is
generic (
	G_MOSROMFILE : string := "../../../../../../sim_asm/test_asm/build/blit-bringup2-rom0.rom"
	);
end sim_6502_tb;

architecture Behavioral of sim_6502_tb is

	signal	sim_ENDSIM			: 	std_logic 		:= '0';
	
	signal	EXT_CLK_48M			: 	std_logic;
	signal	EXT_CLK_50M			: 	std_logic;

	signal	sim_dump_ram		:	std_logic;
	signal	sim_reg_halt 		:  std_logic;
	
	signal	SYS_phi0				:  std_logic;
	signal	SYS_phi1				:  std_logic;
	signal	SYS_phi2				:  std_logic;
	signal	SUP_nRESET			:	std_logic;
	signal	EXT_nRESET			:	std_logic;

	signal	SYS_A					:	std_logic_vector(15 downto 0);
	signal	SYS_D					:	std_logic_vector(7 downto 0);

	signal	SYS_D_bushold		:	std_logic_vector(7 downto 0) := (others => 'W');

	signal	MEM_A					:	std_logic_vector(20 downto 0);
	signal	MEM_D					:	std_logic_vector(7 downto 0);
	signal	MEM_nOE				:	std_logic;
	signal	MEM_ROM_nWE			:	std_logic;
	signal	MEM_RAM_nWE			:	std_logic;
	signal	MEM_ROM_nCE			:	std_logic;
	signal	MEM_RAM0_nCE		:	std_logic;

	signal	i_SYS_TB_nPGFC		: std_logic;
	signal	i_SYS_TB_nPGFD		: std_logic;
	signal	i_SYS_TB_nPGFE		: std_logic;
	signal	i_SYS_TB_RAM_nCS	: std_logic;
	signal	i_SYS_TB_RAM_RnW	: std_logic;
	signal	i_SYS_TB_MOSROM_nCS	: std_logic;

	signal	SYS_RnW				: std_logic;


	signal	SYS_nNMI				: std_logic;
	signal	SYS_nIRQ				: std_logic;

	signal	CFG					: std_logic_vector(15 downto 0);

	signal	CLK_16				: std_logic;

	signal	bbc_1MHzE			: std_logic;
	signal	bbc_slow				: std_logic;

	signal	bbc_slow_dl			: std_logic;

	signal	i_CPU_A									:	std_logic_vector(19 downto 0);
	signal	i_CPU_D									:  std_logic_vector(7 downto 0);
	signal	i_CPU_6EKEZnRD							:	std_logic;		
	signal	i_CPU_C6nML9BUSYKnBGZnBUSACK		:	std_logic;
	signal	i_CPU_RnWZnWR							:	std_logic;
	signal	i_CPU_PHI16ABRT9BSKnDS				:	std_logic;		-- 6ABRT is actually an output but pulled up on the board
	signal	i_CPU_PHI26VDAKFC0ZnMREQ			:	std_logic;
	signal	i_CPU_SYNC6VPA9LICKFC2ZnM1			:	std_logic;
	signal	i_CPU_VSS6VPB9BAKnAS					:	std_logic;
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

	signal	i_hsync									:  std_logic;
	signal	i_vsync									:  std_logic;


begin
	
	i_SYS_TB_nPGFE <= 	'0' when SYS_A(15 downto 8) = x"FE" else
								'1';

	i_SYS_TB_nPGFD <= 	'0' when SYS_A(15 downto 8) = x"FD" else
								'1';

	i_SYS_TB_nPGFC <= 	'0' when SYS_A(15 downto 8) = x"FC" else
								'1';

	i_SYS_TB_RAM_nCS <= 	'0' when SYS_A(15) = '0' and SYS_phi2 = '1' else
								'1' after 30 ns;
								
	i_SYS_TB_RAM_RnW <= 	'0' when SYS_RnW = '0' and SYS_phi2 = '1' else
								'1';

	i_SYS_TB_MOSROM_nCS <= 	'0' when SYS_A(15 downto 14) = "11" and i_SYS_TB_nPGFE = '1' and i_SYS_TB_nPGFD = '1' and i_SYS_TB_nPGFC = '1' else
								'1' after 30 ns;


	e_slow_cyc_dec:entity work.bbc_slow_cyc
	port map (
		SYS_A_i => SYS_A,
		SLOW_o => bbc_slow
		);
	
	bbc_slow_dl <= bbc_slow after 40 ns;

	CFG(0) <= '1';	-- t65 cpu
	CFG(1) <= '1';
	CFG(2) <= '1';
	CFG(3) <= '1'; -- hard == 6502A
	CFG(4) <= '0'; -- swromx
	CFG(7) <= '1'; -- debug button
	CFG(8) <= '1'; -- onboard swrom/ram enable

	CFG(14) <= i_vsync;
	CFG(15) <= i_hsync;

	CFG <= (others => 'H');

	i_CPU_nSO6MX9AVMAKFC1ZnIOREQ <= 'H';

	e_daughter: entity work.mk2blit
	generic map (
		SIM => true
	)
	port map (
		CLK_48M_i							=> EXT_CLK_48M,
		CLK_50M_i							=> EXT_CLK_50M,

				-- 1M RAM/512K ROM bus
		MEM_A_o								=> MEM_A,
		MEM_D_io								=> MEM_D,
		MEM_nOE_o							=> MEM_nOE,
		MEM_ROM_nWE_o						=> MEM_ROM_nWE,
		MEM_RAM_nWE_o						=> MEM_RAM_nWE,
		MEM_ROM_nCE_o						=> MEM_ROM_nCE,
		MEM_RAM0_nCE_o						=> MEM_RAM0_nCE,
		
		-- 1 bit DAC sound out
		SND_BITS_L_o						=> open,
		SND_BITS_R_o						=> open,
		SND_BITS_L_AUX_o					=> open,
		SND_BITS_R_AUX_o					=> open,

		SUP_nRESET_i						=> SUP_nRESET,
		EXT_nRESET_i						=> EXT_nRESET,
		
		-- CPU/SYS bus connects to CPU sockets, SYStem CPU socket, normally the A lines are 
		-- 	read, however during DMA we may disconnect CPU address, data etc lines from 
		--		SYS and take over
		SYS_A_o								=> SYS_A,
		SYS_D_io								=> SYS_D,

		-- SYS signals are connected direct to the BBC cpu socket
		SYS_RDY_i							=> '1',
		SYS_nNMI_i							=> SYS_nNMI,
		SYS_nIRQ_i							=> SYS_nIRQ,
		SYS_SYNC_o							=> open,
		SYS_PHI0_i							=> SYS_PHI0,
		SYS_PHI1_o							=> SYS_PHI1,
		SYS_PHI2_o							=> SYS_PHI2,
		SYS_RnW_o							=> SYS_RnW,

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
		CPUSKT_VSS6VPB9BAKnAS_i				=> i_CPU_VSS6VPB9BAKnAS, 
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
		--CFG									: INOUT	STD_LOGIC_VECTOR(10 DOWNTO 0)
		CFG_io								=> CFG,

		EEPROM_SCL_o						=> open,
		EEPROM_SDA_io						=> open
		
	);

	i_CPU_A <= (others => 'H');
	i_CPU_D <= (others => 'H');

	p_hold:process(SYS_D(0))
	variable prev: std_logic_vector(7 downto 0) := (others => 'U');
	begin
		if SYS_D'event then
			FOR I in 0 to 7 LOOP
				if prev(I) = '0' then
					if SYS_D(I) = 'Z' or SYS_D(I) = 'W' or SYS_D(I) = 'H' then
						SYS_D_bushold(I) <= 'L';
					end if;
				elsif prev(I) = '1' then
					if SYS_D(I) = 'Z' or SYS_D(I) = 'W' or SYS_D(I) = 'L' then
						SYS_D_bushold(I) <= 'H';
					end if;
				else
					SYS_D_bushold(I) <= 'H';
				end if;
			END LOOP;
			prev := SYS_D;
		end if;
	end process;

	SYS_D <= SYS_D_bushold;

	e_cpu: entity work.real_6502_tb 
	--NMOS
	GENERIC MAP (
			dly_phi0a => 5 ns,
			dly_phi0b => 5 ns,
			dly_phi0c => 5 ns,
			dly_phi0d => 5 ns,
			dly_addr  => 110 ns, 
			dly_dwrite=> 100 ns,	-- dwrite must be > dhold
			dly_dhold => 30 ns
		)
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
		A => i_CPU_A(15 downto 0),
		D => i_CPU_D,
		nRESET => i_CPU_nRES,
		RDY => i_CPU_RDY9KnHALTZnWAIT,
		nIRQ => i_CPU_nIRQKnIPL1,
		nNMI => i_CPU_nNMIKnIPL02,
		nSO => i_CPU_nSO6MX9AVMAKFC1ZnIOREQ,
		RnW => i_CPU_RnWZnWR,
		SYNC => i_CPU_SYNC6VPA9LICKFC2ZnM1,
		PHI0 => i_CPU_PHI09EKZCLK,
		PHI1 => i_CPU_PHI16ABRT9BSKnDS,
		PHI2 => i_CPU_PHI26VDAKFC0ZnMREQ
		);


	e_blit_ram_2048: entity work.ram_tb 
	generic map (
		size 			=> 2048*1024,
		dump_filename => "d:\\temp\\ram_dump_blit_dip40_poc-blitram.bin",
		tco => 55 ns,
		taa => 55 ns
	)
	port map (
		A				=> MEM_A(20 downto 0),
		D				=> MEM_D,
		nCS			=> MEM_RAM0_nCE,
		nOE			=> MEM_nOE,
		nWE			=> MEM_RAM_nWE,
		
		tst_dump		=> sim_dump_ram

	);

	--actually just the same ROM repeated!
	e_blit_rom_512: entity work.ram_tb 
	generic map (
		size 			=> 16*1024,
		dump_filename => "",
		romfile => "E:/Users/dominic/programming/6502/6502-general/Blitter/roms/bltutil/bltutil.rom",
		tco => 55 ns,
		taa => 55 ns
	)
	port map (
		A				=> MEM_A(13 downto 0),
		D				=> MEM_D,
		nCS			=> MEM_ROM_nCE,
		nOE			=> MEM_nOE,
		nWE			=> MEM_RAM_nWE,
		
		tst_dump		=> sim_dump_ram

	);



	e_sys_ram_32: entity work.ram_tb 
	generic map (
		size 			=> 32*1024,
		dump_filename => "d:\\temp\\ram_dump_blit_dip40_poc-sysram.bin",
		tco => 150 ns,
		taa => 150 ns
	)
	port map (
		A				=> SYS_A(14 downto 0),
		D				=> SYS_D,
		nCS			=> i_SYS_TB_RAM_nCS,
		nOE			=> '0',
		nWE			=> i_SYS_TB_RAM_RnW,
		
		tst_dump		=> sim_dump_ram

	);

	
	w_sys_rom_16: entity work.rom_tb
	generic map (
		romfile 		=> "../../test_asm/blit-bringup2-rom0.rom",
		size 			=> 16*1024
	)
	port map (
		A 				=> SYS_A(13 downto 0),
		D 				=> SYS_D,
		nCS 			=> i_SYS_TB_MOSROM_nCS,
		nOE 			=> '0'
	);

	p_reg_halt: process(SUP_nRESET, i_SYS_TB_nPGFE, SYS_A, SYS_D, SYS_phi2)
	begin
		if (SUP_nRESET = '0') then
			sim_reg_halt <= '0';
		elsif falling_edge(SYS_phi2) and SYS_RnW = '0' and i_SYS_TB_nPGFE = '0' and unsigned(SYS_A(7 downto 0)) = 16#FF# then
			sim_reg_halt <= SYS_D(7);
		end if;
	end process;
	
	p_clk_16:process -- deliberately 1/4 ns fast!
	begin
		CLK_16 <= '1';
		wait for 31.2 ns;
		CLK_16 <= '0';
		wait for 31.25 ns;
	end process;


	e_bbc_clk_gen:entity work.bbc_clk_gen 
	port map (
		clk_16_i        => CLK_16,
		clk_8_o         => open,
		clk_4_o         => open,
		clk_2_o         => open,
		clk_1_o         => open,
		
		bbc_SLOW_i      => bbc_slow_dl,
		bbc_phi1_i      => SYS_phi1,
		bbc_1MHzE_o     => bbc_1MHzE,
		bbc_ROMSEL_clk_o=> open,
		bbc_phi0_o      => SYS_PHI0
	);

--	main_clkc: process
--	begin
--		if sim_ENDSIM='0' then
--			SYS_phi0 <= '0';
--			wait for 254 ns;
--			SYS_phi0 <= '1';
--			wait for 247 ns;
--		else
--			wait;
--		end if;
--	end process;


	EXT_CLK_48M <= 'H';

	main_clkc50: process
	begin
		if sim_ENDSIM='0' then
			EXT_CLK_50M <= '0';
			wait for 10 ns;
			EXT_CLK_50M <= '1';
			wait for 10 ns;
		else
			wait;
		end if;
	end process;

	
	p6845_h: process
	begin
		if sim_ENDSIM = '0' then
			i_hsync <= '1';
			wait for 4 us;
			i_hsync <= '0';
			wait for 60 us;
		else
			wait;
		end if;
	end process;		

	p6845_v: process
	begin
		if sim_ENDSIM = '0' then
			i_vsync <= '0';
			wait for 15 us;
			i_vsync <= '1';
			wait for 128 us;
			i_vsync <= '0';
			wait for 753 us;
		else
			wait;
		end if;
	end process;

	stim: process
	variable usct : integer := 0;
	
	begin
			
			sim_dump_ram <= '0';
			SUP_nRESET <= '1';
			
			wait for 1034 ns;

			SUP_nRESET <= '0';


			SYS_nIRQ <= '1';
			SYS_nNMI <= '1';
			
			wait for 1 ns;						
			wait for 20 us;
			SUP_nRESET <= '1';

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
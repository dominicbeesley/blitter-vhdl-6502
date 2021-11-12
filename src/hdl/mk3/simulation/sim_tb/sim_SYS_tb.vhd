----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	24/7/2021
-- Design Name: 
-- Module Name:    	shared model of BBC Model B motherboard
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		For mk3 board simulation
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.sim_SYS_pack.all;

entity sim_SYS_tb is
generic (
	G_MOSROMFILE 		: string := "";
	G_RAMDUMPFILE		: string := "";
	G_SIM_SYS_TYPE		: SIM_SYS_TYPE := SIM_SYS_BBC
	);
port (
	SYS_phi0_o		: out 	std_logic;
	SYS_phi1_i		: in  	std_logic;
	SYS_phi2_i		: in  	std_logic;
	SYS_A_i			: in		std_logic_vector(15 downto 0);
	SYS_D_io			: inout	std_logic_vector(7 downto 0);
	SYS_RnW_i		: in		std_logic;
	SYS_SYNC_i		: in		std_logic;
	SYS_nNMI_o		: out		std_logic;
	SYS_nIRQ_o		: out		std_logic;
	SYS_nRESET_i	: in		std_logic;

	SYS_BUF_D_nOE_i: in		std_logic;
	SYS_BUF_D_DIR_i: in		std_logic;


	hsync_o			: out		std_logic;
	vsync_o			: out		std_logic;

	sim_ENDSIM		: in		std_logic;
	sim_dump_ram	: in		std_logic;
	sim_reg_halt_o : out		std_logic
);
end sim_SYS_tb;

architecture Behavioral of sim_SYS_tb is

	signal	i_SYS_TB_nPGFC			: std_logic;
	signal	i_SYS_TB_nPGFD			: std_logic;
	signal	i_SYS_TB_nPGFE			: std_logic;
	signal	i_SYS_TB_RAM_nCS		: std_logic;
	signal	i_SYS_TB_RAM_RnW		: std_logic;
	signal	i_SYS_TB_MOSROM_nCS	: std_logic;

	signal	sys_slow_hw				: std_logic;
	signal	sys_slow_hw_dl			: std_logic;
	signal	sys_slow_ram			: std_logic;
	signal	sys_slow_ram_dl		: std_logic;
	signal	sys_ram_en				: std_logic;

	signal	r_hsync					: std_logic;
	signal	r_vsync					: std_logic;

	-- these are all before/after delays from buffers
	signal	i_SYS_phi0				: std_logic;
	signal	i_SYS_phi1				: std_logic;
	signal	i_SYS_phi2				: std_logic;
	signal	i_SYS_A					: std_logic_vector(15 downto 0);
	signal	i_SYS_D					: std_logic_vector(7 downto 0);
	signal	i_SYS_RnW				: std_logic;
	signal	i_SYS_SYNC				: std_logic;

	signal	i_SYS_BUF_D_nOE_dly	: std_logic;
	signal	i_SYS_BUF_D_DIR_dly	: std_logic;

	signal	r_CLK_16					: std_logic;



begin

	SYS_nIRQ_o <= '1';
	SYS_nNMI_o <= '1';
	hsync_o <= r_hsync;
	vsync_o <= r_vsync;

	-- model the 74LVC4245 on the data lines
	i_SYS_BUF_D_nOE_dly <= SYS_BUF_D_nOE_i after 8 ns;
	i_SYS_BUF_D_DIR_dly <= SYS_BUF_D_DIR_i after 8 ns;

	SYS_D_io 	<= 	(others => 'Z') when i_SYS_BUF_D_DIR_dly = '0' or i_SYS_BUF_D_nOE_dly = '1' else
						   i_SYS_D after 6 ns;
	i_SYS_D 		<= 	(others => 'Z') when i_SYS_BUF_D_DIR_dly = '1' or i_SYS_BUF_D_nOE_dly = '1' else
					      SYS_D_io after 6 ns;
	-- model the 74LVC4245 on the address lines
	i_SYS_A <= SYS_A_i after 8 ns;

	-- model the control signals mb->blitter through 74LVC4245
	SYS_phi0_o <= i_SYS_PHI0 after 8 ns;
	-- model the control signals blitter->mb through 74LVC4245
	i_SYS_phi2 <= SYS_phi2_i after 8 ns;
	i_SYS_phi1 <= SYS_phi1_i after 8 ns;
	i_SYS_SYNC <= SYS_SYNC_i after 8 ns;
	i_SYS_RnW <= SYS_Rnw_i after 8 ns;



	i_SYS_TB_nPGFE <= 	'0' when i_SYS_A(15 downto 8) = x"FE" else
								'1';

	i_SYS_TB_nPGFD <= 	'0' when i_SYS_A(15 downto 8) = x"FD" else
								'1';

	i_SYS_TB_nPGFC <= 	'0' when i_SYS_A(15 downto 8) = x"FC" else
								'1';

	i_SYS_TB_RAM_nCS <= 	'0' when i_SYS_A(15) = '0' and i_SYS_phi2 = '1' and sys_ram_en = '1' else
								'1' after 30 ns;
								
	i_SYS_TB_RAM_RnW <= 	'0' when i_SYS_RnW = '0' and i_SYS_phi2 = '1' else
								'1';

	i_SYS_TB_MOSROM_nCS <= 	'0' when i_SYS_A(15 downto 14) = "11" and i_SYS_TB_nPGFE = '1' and i_SYS_TB_nPGFD = '1' and i_SYS_TB_nPGFC = '1' else
								'1' after 30 ns;

	e_sys_ram_32: entity work.ram_tb 
	generic map (
		size 			=> 32*1024,
		dump_filename => G_RAMDUMPFILE,
		tco => 150 ns,
		taa => 150 ns
	)
	port map (
		A				=> i_SYS_A(14 downto 0),
		D				=> i_SYS_D,
		nCS			=> i_SYS_TB_RAM_nCS,
		nOE			=> '0',
		nWE			=> i_SYS_TB_RAM_RnW,
		
		tst_dump		=> sim_dump_ram

	);

	
	w_sys_rom_16: entity work.rom_tb
	generic map (
		romfile 		=> G_MOSROMFILE,
		size 			=> 16*1024
	)
	port map (
		A 				=> i_SYS_A(13 downto 0),
		D 				=> i_SYS_D,
		nCS 			=> i_SYS_TB_MOSROM_nCS,
		nOE 			=> '0'
	);

	p_clk_16:process -- deliberately a touch fast to test dll
	begin
		r_CLK_16 <= '1';
		wait for 31.2 ns;
		r_CLK_16 <= '0';
		wait for 31.25 ns;
	end process;



	G_BBC_CK:IF G_SIM_SYS_TYPE = SIM_SYS_BBC GENERATE
	e_bbc_clk_gen:entity work.bbc_clk_gen 
	port map (
		clk_16_i        => r_CLK_16,
		clk_8_o         => open,
		clk_4_o         => open,
		clk_2_o         => open,
		clk_1_o         => open,
		
		bbc_slow_i  	 => sys_slow_hw_dl,
		bbc_phi1_i      => i_SYS_phi1,

		bbc_phi0_o      => i_SYS_PHI0
	);

	e_slow_cyc_dec:entity work.bbc_slow_cyc
	port map (
		SYS_A_i => i_SYS_A,
		SLOW_o => sys_slow_hw
		);
	
	sys_slow_ram <= '0';
	sys_slow_hw_dl <= sys_slow_hw after 30 ns;
	sys_slow_ram_dl <= sys_slow_ram after 30 ns;
	sys_ram_en <= '1';

	END GENERATE;

	G_ELK_CK:IF G_SIM_SYS_TYPE = SIM_SYS_ELK GENERATE
	e_elk_clk_gen:entity work.elk_clk_gen 
	port map (
		clk_16_i        => r_CLK_16,
		clk_8_o         => open,
		clk_4_o         => open,
		clk_2_o         => open,
		clk_1_o         => open,
		
		elk_slow_hw_i  => sys_slow_hw_dl,
		elk_slow_RAM_i => sys_slow_ram_dl,
		elk_ram_en_o   => sys_ram_en,

		elk_phi0_o      => i_SYS_PHI0
	);

	e_slow_cyc_dec:entity work.elk_slow_cyc
	port map (
		SYS_A_i => i_SYS_A,
		SLOW_o => sys_slow_hw,
		SLOW_RAM_o => sys_slow_ram
		);
	
	sys_slow_hw_dl <= sys_slow_hw after 40 ns;
	sys_slow_ram_dl <= sys_slow_ram after 40 ns;

	END GENERATE;


	p6845_h: process
	begin
		if sim_ENDSIM = '0' then
			r_hsync <= '1';
			wait for 4 us;
			r_hsync <= '0';
			wait for 60 us;
		else
			wait;
		end if;
	end process;		

	p6845_v: process
	begin
		if sim_ENDSIM = '0' then
			r_vsync <= '0';
			wait for 15 us;
			r_vsync <= '1';
			wait for 128 us;
			r_vsync <= '0';
			wait for 753 us;
		else
			wait;
		end if;
	end process;

	-- a phony hardware register to halt the sim
	p_reg_halt: process(SYS_nRESET_i, i_SYS_TB_nPGFE, i_SYS_A, i_SYS_D, i_SYS_phi2)
	begin
		if (SYS_nRESET_i = '0') then
			sim_reg_halt_o <= '0';
		elsif falling_edge(i_SYS_phi2) and i_SYS_RnW = '0' and i_SYS_TB_nPGFE = '0' and unsigned(i_SYS_A(7 downto 0)) = 16#FF# then
			sim_reg_halt_o <= i_SYS_D(7);
		end if;
	end process;


end;
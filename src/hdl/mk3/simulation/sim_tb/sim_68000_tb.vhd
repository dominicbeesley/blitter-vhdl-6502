----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:     18/8/2021
-- Design Name: 
-- Module Name:    	test bench for dmac blitter on mk3 board using 68008 cpu
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		For mk3 board simulation
--
-- Dependencies: 
--
-- Revision: 
----------------------------------------------------------------------------------

--TODO: 18/4/2022 - use newer core for this sim? FCx, VMA, E not correctly emulated

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sim_68000_tb is
generic (
	G_MOSROMFILE : string := "../../../../../../sim_asm/test_asm68k/build/boot68008_testbench_mos.bin"
	);
end sim_68000_tb;

architecture Behavioral of sim_68000_tb is

	signal	sim_ENDSIM			: 	std_logic 		:= '0';
	
	signal	i_EXT_CLK_48M		: 	std_logic;

	signal	sim_dump_ram		:	std_logic;
	signal	sim_reg_halt 		:  std_logic;
	
	signal	i_SUP_nRESET		:	std_logic;

	signal	i_SYS_phi0			:  std_logic;
	signal	i_SYS_phi1			:  std_logic;
	signal	i_SYS_phi2			:  std_logic;
	signal	i_SYS_A				:	std_logic_vector(15 downto 0);
	signal	i_SYS_D				:	std_logic_vector(7 downto 0);
	signal	i_SYS_RnW			: std_logic;
	signal	i_SYS_nNMI			: std_logic;
	signal	i_SYS_nIRQ			: std_logic;
	signal	i_SYS_SYNC			: std_logic;

	signal	i_SYS_BUF_D_nOE	: std_logic;
	signal	i_SYS_BUF_D_DIR	: std_logic;
	signal	i_SYS_AUX_io		: std_logic_vector(6 downto 0);


	signal	i_MEM_A				:	std_logic_vector(20 downto 0);
	signal	i_MEM_D				:	std_logic_vector(7 downto 0);
	signal	i_MEM_nOE			:	std_logic;
	signal	i_MEM_nWE			:	std_logic;
	signal	i_MEM_RAM_nCE		:	std_logic_vector(3 downto 0);
	signal	i_MEM_FL_nCE		:	std_logic;

	signal	i_exp_PORTA_io_blit	: std_logic_vector(7 downto 0);
	signal	i_exp_PORTA_nOE_blit	: std_logic;
	signal	i_exp_PORTA_DIR_blit	: std_logic;
	signal	i_exp_PORTB_o_blit	: std_logic_vector(7 downto 0);
	signal	i_exp_PORTC_io			: std_logic_vector(11 downto 0);
	signal	i_exp_PORTD_io			: std_logic_vector(11 downto 0);

	signal	i_exp_PORTA_io_cpu	: std_logic_vector(7 downto 0);
	signal	i_exp_PORTA_nOE_dly	: std_logic;
	signal	i_exp_PORTA_DIR_dly	: std_logic;
	signal	i_exp_PORTB_o_cpu		: std_logic_vector(7 downto 0);



	signal	i_exp_PORTG			: std_logic_vector(11 downto 0);
	signal	i_exp_PORTF			: std_logic_vector(11 downto 0);
	signal	i_exp_PORTE			: std_logic_vector(11 downto 0);

	signal	i_exp_PORTEFG_io	: std_logic_vector(11 downto 0);
	signal	i_exp_PORTE_nOE	: std_logic;
	signal	i_exp_PORTF_nOE	: std_logic;
	signal	i_exp_PORTG_nOE	: std_logic;
	signal	i_exp_PORTE_nOE_dly	: std_logic;
	signal	i_exp_PORTF_nOE_dly	: std_logic;
	signal	i_exp_PORTG_nOE_dly	: std_logic;

	signal	i_hsync									:  std_logic;
	signal	i_vsync									:  std_logic;


	signal	i_cpu_CLK							: std_logic;
	signal	i_cpu_IPL							: std_logic_vector(2 downto 0);
	signal	i_cpu_nDTACK						: std_logic;
	signal	i_cpu_A								: std_logic_vector(31 downto 0);
	signal	i_cpu_AS								: std_logic;
	signal	i_cpu_LDS							: std_logic;
	signal	i_cpu_UDS							: std_logic;
	signal	i_cpu_RnW							: std_logic;
	signal	i_CPU_FC								: std_logic_vector(2 downto 0);
	signal	i_cpu_BERR							: std_logic;
	signal	i_cpu_nVPA							: std_logic;
	signal	i_cpu_nVMA							: std_logic;
	signal	i_cpu_E								: std_logic;

	signal	i_CPU_D_out							: std_logic_vector(15 downto 0);
	signal	i_CPU_D_in							: std_logic_vector(15 downto 0);
	signal	i_CPU_drive_data					: std_logic;

begin
	
	e_SYS:entity work.sim_SYS_tb
	generic map (
		G_MOSROMFILE => G_MOSROMFILE,
		G_RAMDUMPFILE => "d:\\temp\\ram_dump_blit_dip40_poc-sysram.bin",
		G_MK3 => true
	)
	port map (
		SYS_phi0_o				=> i_SYS_phi0,
		SYS_phi1_i				=> i_SYS_phi1,
		SYS_phi2_i				=> i_SYS_phi2,
		SYS_A_i					=> i_SYS_A,
		SYS_D_io					=> i_SYS_D,
		SYS_RnW_i				=> i_SYS_RnW,
		SYS_SYNC_i				=> i_SYS_SYNC,
		SYS_nNMI_o				=> i_SYS_nNMI,
		SYS_nIRQ_o				=> i_SYS_nIRQ,
		SYS_nRESET_i			=> i_SUP_nRESET,

		SYS_BUF_D_nOE_i		=> i_SYS_BUF_D_nOE,
		SYS_BUF_D_DIR_i		=> i_SYS_BUF_D_DIR,

		hsync_o					=> i_hsync,
		vsync_o					=> i_vsync,

		sim_ENDSIM				=> sim_ENDSIM,
		sim_dump_ram			=> sim_dump_ram,
		sim_reg_halt_o			=> sim_reg_halt
	);

	-- config pins
	i_exp_PORTG <= (
		2 downto 0 => "111" -- Model B
	,	3 => '1' -- not t65
	,	4 => '1' -- swromx off
	,	5 => '1' -- mosram off
	,  6 => '1' -- memi off (enable mem)
	,	8 downto 7 => "11" -- spare
	, 11 downto 9 => "000" -- hard cpu speed 68000/20
		);

	i_exp_PORTF <= (
		3 downto 0 => "0011" -- 68008,
	,	others => 'H'
		);

	i_exp_PORTE <= (
		others => 'H'
		);

	i_exp_PORTE_nOE_dly <= i_exp_PORTE_nOE after 10 ns;
	i_exp_PORTF_nOE_dly <= i_exp_PORTF_nOE after 10 ns;
	i_exp_PORTG_nOE_dly <= i_exp_PORTG_nOE after 10 ns;

	--i_exp_PORTE <= i_exp_PORTEFG_io when (i_exp_PORTE_nOE_dly) = '0' else
	--					(others => 'Z');
	--i_exp_PORTF <= i_exp_PORTEFG_io when (i_exp_PORTF_nOE_dly) = '0' else
	--					(others => 'Z');
	--i_exp_PORTG <= i_exp_PORTEFG_io when (i_exp_PORTG_nOE_dly) = '0' else
	--					(others => 'Z');


	i_exp_PORTEFG_io 	<= i_exp_PORTE when (i_exp_PORTE_nOE_dly) = '0' else
							(others => 'Z');
	i_exp_PORTEFG_io 	<= i_exp_PORTF when (i_exp_PORTF_nOE_dly) = '0' else
							(others => 'Z');
	i_exp_PORTEFG_io  <= i_exp_PORTG when (i_exp_PORTG_nOE_dly) = '0' else
							(others => 'Z');


	-- model the 74LVC4245 on PORTA
	i_exp_PORTA_nOE_dly <= i_exp_PORTA_nOE_blit after 8 ns;
	i_exp_PORTA_DIR_dly <= i_exp_PORTA_DIR_blit after 8 ns;

	i_exp_PORTA_io_cpu	<= 	(others => 'Z') when i_exp_PORTA_DIR_dly = '1' or i_exp_PORTA_nOE_dly = '1' else
						   			i_exp_PORTA_io_blit after 6 ns;
	i_exp_PORTA_io_blit	<= 	(others => 'Z') when i_exp_PORTA_DIR_dly = '0' or i_exp_PORTA_nOE_dly = '1' else
					      			i_exp_PORTA_io_cpu after 6 ns;

	-- model the 74LVC4245 on PORTB
	i_exp_PORTB_o_cpu <= i_exp_PORTB_o_blit after 6 ns;


	-- TODO: work out how to map the bidirectional 74cb3t's for PORTC/D

	i_SYS_AUX_io <= (
		5 => i_hsync,
		4 => i_vsync,
		others => 'H'
	);



	e_daughter: entity work.mk3blit
	generic map (
		SIM => true
	)
	port map (
		CLK_48M_i 							=> i_EXT_CLK_48M,
		
		MEM_A_o 								=> i_MEM_A,
		MEM_D_io 							=> i_MEM_D,
		MEM_nOE_o 							=> i_MEM_nOE,
		MEM_nWE_o 							=> i_MEM_nWE,
		MEM_FL_nCE_o 						=> i_MEM_FL_nCE,
		MEM_RAM_nCE_o 						=> i_MEM_RAM_nCE,

		SND_L_o 								=> open,
		SND_R_o 								=> open,
		
		HDMI_SCL_io 							=> open,
		HDMI_SDA_io 						=> open,
		HDMI_HPD_i 							=> '1',
		HDMI_CK_o 							=> open,
		HDMI_D0_o 							=> open,
		HDMI_D1_o 							=> open,
		HDMI_D2_o 							=> open,

		SD_CS_o 								=> open,
		SD_CLK_o 							=> open,
		SD_MOSI_o 							=> open,
		SD_MISO_i 							=> '1',
		SD_DET_i 							=> '1',
		
		SUP_nRESET_i 						=> i_SUP_nRESET,

		SYS_A_o 								=> i_SYS_A,
		SYS_D_io 							=> i_SYS_D,
		SYS_BUF_D_DIR_o 					=> i_SYS_BUF_D_DIR,
		SYS_BUF_D_nOE_o 					=> i_SYS_BUF_D_nOE,

		SYS_SYNC_o 							=> i_SYS_SYNC,
		SYS_PHI1_o 							=> i_SYS_PHI1,
		SYS_PHI2_o 							=> i_SYS_PHI2,
		
		SYS_RnW_o 							=> i_SYS_RnW,
		SYS_RDY_i 							=> '1',
		SYS_nNMI_i 							=> i_SYS_nNMI,
		SYS_nIRQ_i 							=> i_SYS_nIRQ,
		SYS_PHI0_i 							=> i_SYS_PHI0,
		SYS_nDBE_i 							=> 'H',
		
		SYS_AUX_io 							=> i_SYS_AUX_io,
		SYS_AUX_o 							=> open,

		I2C_SCL_io 							=> open,
		I2C_SDA_io 							=> open,

		exp_PORTA_io 						=> i_exp_PORTA_io_blit,
		exp_PORTA_nOE_o 					=> i_exp_PORTA_nOE_blit,
		exp_PORTA_DIR_o 					=> i_exp_PORTA_DIR_blit,

		exp_PORTB_o 						=> i_exp_PORTB_o_blit,
		exp_PORTC_io 						=> i_exp_PORTC_io,
		exp_PORTD_io 						=> i_exp_PORTD_io,
		
		exp_PORTEFG_io 					=> i_exp_PORTEFG_io,
		exp_PORTE_nOE 						=> i_exp_PORTE_nOE,
		exp_PORTF_nOE 						=> i_exp_PORTF_nOE,
		exp_PORTG_nOE 						=> i_exp_PORTG_nOE,

		LED_o		 							=> open,
		BTNUSER_i 							=> (others => '1')

		
	);



	e_cpu:entity work.TG68
	port map (
		clk          		=> i_cpu_CLK,
		reset        		=> i_exp_PORTD_io(9),
		clkena_in			=> '1',
--		halt					=> i_exp_PORTD_io(10),
--      berr					=> i_CPU_BERR,
      ipl           		=> i_cpu_IPL,
      addr          		=> i_cpu_A,
--      fc						=> i_cpu_FC,
      data_in	=> i_CPU_D_in,
      data_out				=> i_CPU_D_out,
      drive_data			=> i_CPU_drive_data,
      as            		=> i_cpu_AS,
      uds            	=> i_CPU_UDS,
      lds            	=> i_cpu_LDS,
      rw            		=> i_cpu_RnW,
      dtack         		=> i_cpu_nDTACK
--      e						=> i_cpu_E,
--      VPA					=> i_cpu_nVPA,
--      VMA					=> i_cpu_nVMA
   );

	i_CPU_D_in <= i_exp_PORTEFG_io(11 downto 4) & i_exp_PORTA_io_cpu;     

   i_exp_PORTF(11 downto 4) <= i_CPU_D_out(15 downto 8) when i_CPU_drive_data = '1' else (others => 'Z');
   i_exp_PORTA_io_cpu <= i_CPU_D_out(7 downto 0) when i_CPU_drive_data = '1' else (others => 'Z');


	--TODO: WARNING: berr, ignored
	i_cpu_nVPA <= i_exp_PORTB_o_cpu(0);
	i_cpu_BERR <= not i_exp_PORTB_o_cpu(1); 
	i_cpu_CLK <= i_exp_PORTB_o_cpu(2);
	i_cpu_IPL <= i_exp_PORTB_o_cpu(6) & i_exp_PORTB_o_cpu(4) & i_exp_PORTB_o_cpu(5);
	i_cpu_nDTACK <= i_exp_PORTB_o_cpu(7);

	i_exp_PORTC_io <= 	
		(	
			0 => i_cpu_LDS,
			7 downto 1 => i_cpu_A(7 downto 1),
			11 downto 8 => i_cpu_A(19 downto 16)
		);
	--TODO: WARNING: this is incomplete as tg68 doesn't do BG, BREQ signals 
	i_exp_PORTD_io <= (
		0 => i_CPU_E -- E
	,	1 => i_CPU_RnW
	,  2 => i_CPU_UDS
	,  3 => i_CPU_FC(0)
	,	4 => i_CPU_FC(2)
	,	5 => i_cpu_AS
	,  6 => i_CPU_FC(1)
	,  7 => '0' -- BG
	,  8 => 'Z' -- BR
	, 11 => i_CPU_nVMA
	, others => 'Z'
		);


	i_exp_PORTE <= (
		7 downto 0 => i_cpu_A(15 downto 8),
		11 downto 8 => i_cpu_A(23 downto 20),
		others => 'H'
	);


		-- single non BB ram
	--TODO the timings are wrong!
	e_blit_ram_2048: entity work.ram_tb 
	generic map (
		size 			=> 1024*1024,
		dump_filename => "d:\\temp\\ram_dump_blit_dip40_poc-blitram.bin",
		tco => 10 ns,
		taa => 10 ns,
		toh => 2 ns,		
		tohz => 3 ns,  
		thz => 3 ns,
		tolz => 3 ns,
		tlz => 3 ns,
		toe => 4.5 ns,
		twed => 6.5 ns
	)
	port map (
		A				=> i_MEM_A(19 downto 0),
		D				=> i_MEM_D,
		nCS			=> i_MEM_RAM_nCE(1),
		nOE			=> i_MEM_nOE,
		nWE			=> i_MEM_nWE,
		
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
		nCS			=> i_MEM_FL_nCE,
		nOE			=> i_MEM_nOE,
		nWE			=> i_MEM_nWE,
		
		tst_dump		=> sim_dump_ram

	);

	main_clkc48: process
	begin
		if sim_ENDSIM='0' then
			i_EXT_CLK_48M <= '0';
			wait for 10.416666 ns;
			i_EXT_CLK_48M <= '1';
			wait for 10.416666 ns;
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
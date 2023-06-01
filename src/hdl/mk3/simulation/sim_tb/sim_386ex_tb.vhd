----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	31/5/2023
-- Design Name: 
-- Module Name:    	test bench for dmac blitter on mk3 board using 386ex cpu
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		
--
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
----------------------------------------------------------------------------------

library vunit_lib;
context vunit_lib.vunit_context;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sim_386ex_tb is
generic (
	runner_cfg : string := "#";
	G_MOSROMFILE : string := "../../../../../../sim_asm/test_asmx86/build/bootx86_testbench_mos.rom"
	);
end sim_386ex_tb;

architecture Behavioral of sim_386ex_tb is

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

	signal	i_CPU_nSMI				: std_logic;
	signal	i_CPU_DRQ				: std_logic;
	signal	i_CPU_CLK2				: std_logic;
	signal	i_CPU_nINT0				: std_logic;
	signal	i_CPU_nNMI				: std_logic;
	signal	i_CPU_RESET				: std_logic;
	signal	i_CPU_nNA				: std_logic;

	signal   i_CPU_D					: std_logic_vector(15 downto 0);
	signal	i_CPU_nREADY			: std_logic;

	signal	i_CPU_WnR				: std_logic;
	signal	i_CPU_nBHE				: std_logic;
	signal	i_CPU_MnIO				: std_logic;
	signal	i_CPU_DnC				: std_logic;
	signal	i_CPU_nADS				: std_logic;
	signal	i_CPU_nLBA				: std_logic;
	signal	i_CPU_nREFRESH			: std_logic;
	signal	i_CPU_CLKOUT			: std_logic;
	signal	i_CPU_nSMIACT			: std_logic;
	signal	i_CPU_nUCS				: std_logic;


	signal	i_CPU_A					: std_logic_vector(23 downto 0);

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
	, 11 downto 9 => "111" -- hard cpu speed 386ex
		);

	i_exp_PORTF <= (
		3 downto 0 => "0100" -- x86,
	,	others => 'H'
		);

	i_exp_PORTE <= (
		others => 'H'
		);

	i_exp_PORTE_nOE_dly <= i_exp_PORTE_nOE after 10 ns;
	i_exp_PORTF_nOE_dly <= i_exp_PORTF_nOE after 10 ns;
	i_exp_PORTG_nOE_dly <= i_exp_PORTG_nOE after 10 ns;

	-- inspired by http://computer-programming-forum.com/42-vhdl/e21a4ee687301ae8.htm zero ohm resistor example
	p_exp_PORTEFG_bidi:process
	begin
		wait on i_exp_PORTE, i_exp_PORTF, i_exp_PORTG, i_exp_PORTEFG_io, i_exp_PORTE_nOE_dly, i_exp_PORTF_nOE_dly, i_exp_PORTG_nOE_dly;
		-- cause breaks
		i_exp_PORTEFG_io <= (others => 'Z');
		i_exp_PORTE <= (others => 'Z');
		i_exp_PORTF <= (others => 'Z');
		i_exp_PORTG <= (others => 'Z');
		wait for 0 ns;
		-- remake
		if i_exp_PORTE_nOE_dly = '0' then
			i_exp_PORTEFG_io <= i_exp_PORTE;
			i_exp_PORTE <= i_exp_PORTEFG_io;
		end if;
		if i_exp_PORTF_nOE_dly = '0' then
			i_exp_PORTEFG_io <= i_exp_PORTF;
			i_exp_PORTF <= i_exp_PORTEFG_io;
		end if;
		if i_exp_PORTG_nOE_dly = '0' then
			i_exp_PORTEFG_io <= i_exp_PORTG;
			i_exp_PORTG <= i_exp_PORTEFG_io;
		end if;
		-- Force a wait to prevent assignment to re-awake the process
    	wait for 0 ns;

	end process;



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
		
		HDMI_SCL_io 						=> open,
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

	i_CPU_nSMI 		<= i_exp_PORTB_o_cpu(0);
	i_CPU_DRQ 		<= i_exp_PORTB_o_cpu(1);
	i_CPU_CLK2 		<= i_exp_PORTB_o_cpu(2);
	i_CPU_nINT0		<= i_exp_PORTB_o_cpu(4);
	i_CPU_nNMI 		<= i_exp_PORTB_o_cpu(5);
	i_CPU_RESET		<= i_exp_PORTB_o_cpu(6);

	--TODO: delays?
	i_exp_PORTC_io <= (
		7 downto 0 => i_CPU_A(7 downto 0),
		11 downto 8 => i_CPU_A(19 downto 16)
	);

	i_exp_PORTD_io <= (
		0 => i_CPU_WnR,
		2 => i_CPU_nBHE,
		3 => i_CPU_MnIO,
		4 => i_CPU_DnC,
		5 => i_CPU_nADS,
		6 => i_CPU_nLBA,
		8 => i_CPU_nREFRESH,
		9 => i_CPU_CLKOUT,
		10 => i_CPU_nSMIACT,
		11 => i_CPU_nUCS,
		others => 'H'
		);

	i_CPU_nREADY <= i_exp_PORTD_io(1); -- TODO: really a bidir on 386ex
	i_CPU_nNA <= i_exp_PORTD_io(7);

	i_exp_PORTE(7 downto 0) <= i_CPU_A(15 downto 8);		
	i_exp_PORTE(11 downto 8) <= i_CPU_A(23 downto 20);		



	e_cpu:entity work.real386ex_tb
	port map (
		CPUSKT_nSMI_i			=> i_CPU_nSMI,
		CPUSKT_DRQ_i			=> i_CPU_DRQ,
		CPUSKT_CLK2_i			=> i_CPU_CLK2,
		CPUSKT_nINT0_i			=> i_CPU_nINT0,
		CPUSKT_nNMI_i			=> i_CPU_nNMI,
		CPUSKT_RESET_i			=> i_CPU_RESET,
		CPUSKT_nNA_i			=> i_CPU_nNA,

		CPUSKT_D_io(7 downto 0)
									=> i_exp_PORTA_io_cpu,
		CPUSKT_D_io(15 downto 8)
									=> i_exp_PORTF(11 downto 4),

		CPUSKT_nREADY_io		=> i_CPU_nREADY,


		CPUSKT_WnR_o			=> i_CPU_WnR,
		CPUSKT_nBHE_o			=> i_CPU_nBHE,
		CPUSKT_MnIO_o			=> i_CPU_MnIO,
		CPUSKT_DnC_o			=> i_CPU_DnC,
		CPUSKT_nADS_o			=> i_CPU_nADS,
		CPUSKT_nLBA_o			=> i_CPU_nLBA,
		CPUSKT_nREFRESH_o		=> i_CPU_nREFRESH,
		CPUSKT_CLKOUT_o		=> i_CPU_CLKOUT,
		CPUSKT_nSMIACT_o		=> i_CPU_nSMIACT,
		CPUSKT_nUCS_o			=> i_CPU_nUCS,
		CPUSKT_A_o				=> i_CPU_A

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


-- VUNIT --

	p_main:process
	variable v_time:time;
	begin
		test_runner_setup(runner, runner_cfg);


		while test_suite loop

			if run("run all") then
	
				wait for 1000 us;

			end if;

		end loop;

		wait for 3 us;

		test_runner_cleanup(runner); -- Simulation ends here
	end process;


end;
-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2022 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:    	29/1/2023
-- Design Name: 
-- Module Name:    	test bench for dmac blitter on mk3 board using z180 cpu
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

entity sim_z180_tb is
generic (
	G_MOSROMFILE : string := "../../../../../../sim_asm/test_asmz180/build/z180_rom.bin"
	);
end sim_z180_tb;

architecture Behavioral of sim_z180_tb is

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

	signal 	i_CPUSKT_nBUSREQ		: std_logic;
	signal 	i_CPUSKT_EXTAL			: std_logic;
	signal 	i_CPUSKT_nWAIT			: std_logic;
	signal 	i_CPUSKT_nINT0			: std_logic;
	signal 	i_CPUSKT_nINT1			: std_logic;
	signal 	i_CPUSKT_nINT2			: std_logic;
	signal 	i_CPUSKT_nNMI			: std_logic;
	signal 	i_CPUSKT_nDREQ0		: std_logic;
	signal 	i_CPUSKT_nRES			: std_logic;

	signal	i_CPUSKT_nRD			: std_logic;
	signal	i_CPUSKT_nWR			: std_logic;
	signal	i_CPUSKT_nHALT			: std_logic;
	signal	i_CPUSKT_nMREQ			: std_logic;
	signal	i_CPUSKT_nM1			: std_logic;
	signal	i_CPUSKT_nRFSH			: std_logic;
	signal	i_CPUSKT_nIOREQ		: std_logic;
	signal	i_CPUSKT_nBUSACK		: std_logic;
	signal	i_CPUSKT_nTEND0		: std_logic;
	signal	i_CPUSKT_ST				: std_logic;
	signal	i_CPUSKT_PHI			: std_logic;

	signal 	i_CPUSKT_D				: std_logic_vector(7 downto 0);
	signal 	i_CPUSKT_A				: std_logic_vector(19 downto 0);

	signal	i_CPU_Din				: std_logic_vector(7 downto 0);
	signal	i_CPU_Dout				: std_logic_vector(7 downto 0);
	signal	i_CPU_Den				: std_logic;


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
	, 11 downto 9 => "001" -- hard cpu speed z180
		);

	i_exp_PORTF <= (
		3 downto 0 => "0101" -- z180,
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



	e_cpu: entity work.T80a
	generic map (
			mode => 0
	)
	port map (
		  RESET_n     => i_CPUSKT_nRES,
        CLK_n       => i_CPUSKT_PHI,
        WAIT_n      => i_CPUSKT_nWAIT,
        INT_n       => i_CPUSKT_nINT0,
        NMI_n       => i_CPUSKT_nNMI,
        BUSRQ_n     => i_CPUSKT_nBUSREQ,
        M1_n        => i_CPUSKT_nM1,
        MREQ_n      => i_CPUSKT_nMREQ, 
        IORQ_n      => i_CPUSKT_nIOREQ,
        RD_n        => i_CPUSKT_nRD,
        WR_n        => i_CPUSKT_nWR,
        RFSH_n      => i_CPUSKT_nRFSH,
        HALT_n      => i_CPUSKT_nHALT,
        BUSAK_n     => i_CPUSKT_nBUSACK,
        A           => i_CPUSKT_A(15 downto 0),
        Din         => i_CPU_Din,
        Dout        => i_CPU_Dout,
        Den         => i_CPU_Den


	);

	i_CPUSKT_D <= i_exp_PORTA_io_cpu;
	i_CPUSKT_D <= i_CPU_Dout when i_cpu_den = '1' else (others => 'Z');
	i_CPU_Din <= i_CPUSKT_D;

	--TODO: z180
	i_CPUSKT_A(19 downto 16) <= (others => '0');

--	p_phi:process
--	begin

		--TODO: z180

--		wait until rising_edge(i_CPUSKT_EXTAL);
--		wait for 30 ns;
--		if i_CPUSKT_PHI = '0' then
--			i_CPUSKT_PHI <= '1';
--		else
--			i_CPUSKT_PHI <= '0';
--		end if;

--	end process;

	i_CPUSKT_PHI <= i_CPUSKT_EXTAL after 25 ns;


	i_CPUSKT_nINT1 	<= i_exp_PORTB_o_cpu(0);
	i_CPUSKT_nINT2	 	<= i_exp_PORTB_o_cpu(1);
	i_CPUSKT_EXTAL	 	<= i_exp_PORTB_o_cpu(2);
	i_CPUSKT_nWAIT		<= i_exp_PORTB_o_cpu(3);
	i_CPUSKT_nINT0  	<= i_exp_PORTB_o_cpu(4);
	i_CPUSKT_nNMI  	<= i_exp_PORTB_o_cpu(5);
	i_CPUSKT_nRES		<= i_exp_PORTB_o_cpu(6);
	i_CPUSKT_nDREQ0	<= i_exp_PORTB_o_cpu(7);

	i_exp_PORTC_io(7 downto 0) <= i_CPUSKT_A(7 downto 0);
	i_exp_PORTC_io(11 downto 8) <= i_CPUSKT_A(19 downto 16);

	i_exp_PORTD_io(0) <= i_CPUSKT_nRD;
	i_exp_PORTD_io(1) <= i_CPUSKT_nWR;
	i_exp_PORTD_io(2) <=	i_CPUSKT_nHALT;
	i_exp_PORTD_io(3) <= i_CPUSKT_nMREQ;
	i_exp_PORTD_io(4) <= i_CPUSKT_nM1;
	i_exp_PORTD_io(5) <= i_CPUSKT_nRFSH;
	i_exp_PORTD_io(6) <= i_CPUSKT_nIOREQ;
	i_exp_PORTD_io(7) <= i_CPUSKT_nBUSACK;
	i_CPUSKT_nBUSREQ <= i_exp_PORTD_io(8);
	i_exp_PORTD_io(8) <= i_CPUSKT_nTEND0;
	i_exp_PORTD_io(9) <= i_CPUSKT_ST;
	i_exp_PORTD_io(10) <= i_CPUSKT_PHI;
	

	i_exp_PORTE(7 downto 0) <= i_CPUSKT_A(15 downto 8);		

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
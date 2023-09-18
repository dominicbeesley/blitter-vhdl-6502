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
	G_SIM_SYS_TYPE		: SIM_SYS_TYPE := SIM_SYS_BBC;
	G_INCLUDE_SYSVIA	: boolean := false;
	G_MK3			: boolean				-- enable SYS buffer delay
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

	SYS_1MHzE_o		: out		std_logic;
	SYS_2MHzE_o		: out		std_logic;

	hsync_o			: out		std_logic;
	vsync_o			: out		std_logic;

	sim_ENDSIM		: in		std_logic;
	sim_dump_ram	: in		std_logic;
	sim_reg_halt_o : out		std_logic
);
end sim_SYS_tb;

architecture Behavioral of sim_SYS_tb is

	component M6522 is
   port (
      I_RS                  : in    std_logic_vector(3 downto 0);
      I_DATA                : in    std_logic_vector(7 downto 0);
      O_DATA                : out   std_logic_vector(7 downto 0);
      O_DATA_OE_L           : out   std_logic;

      I_RW_L                : in    std_logic;
      I_CS1                 : in    std_logic;
      I_CS2_L               : in    std_logic;

      O_IRQ_L               : out   std_logic; -- note, not open drain

      -- port a
      I_CA1                 : in    std_logic;
      I_CA2                 : in    std_logic;
      O_CA2                 : out   std_logic;
      O_CA2_OE_L            : out   std_logic;

      I_PA                  : in    std_logic_vector(7 downto 0);
      O_PA                  : out   std_logic_vector(7 downto 0);
      O_PA_OE_L             : out   std_logic_vector(7 downto 0);

      -- port b
      I_CB1                 : in    std_logic;
      O_CB1                 : out   std_logic;
      O_CB1_OE_L            : out   std_logic;

      I_CB2                 : in    std_logic;
      O_CB2                 : out   std_logic;
      O_CB2_OE_L            : out   std_logic;

      I_PB                  : in    std_logic_vector(7 downto 0);
      O_PB                  : out   std_logic_vector(7 downto 0);
      O_PB_OE_L             : out   std_logic_vector(7 downto 0);

      I_P2_H                : in    std_logic; -- high for phase 2 clock  ____----__
      RESET_L               : in    std_logic;
      ENA_4                 : in    std_logic; -- clk enable
      CLK                   : in    std_logic
   );
	end component;


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
	signal	i_SYS_1MHzE				: std_logic;
	signal	i_SYS_2MHzE				: std_logic;
	signal	i_SYS_A					: std_logic_vector(15 downto 0);
	signal	i_SYS_D					: std_logic_vector(7 downto 0);
	signal	i_SYS_RnW				: std_logic;
	signal	i_SYS_SYNC				: std_logic;

	signal	i_SYS_BUF_D_nOE_dly	: std_logic;
	signal	i_SYS_BUF_D_DIR_dly	: std_logic;

	signal	r_CLK_16					: std_logic;

	signal	i_clken4					: std_logic;	 -- Hoglet 6522 clocken

	-- sysvia

	signal	i_sysvia_cs2			: std_logic;
	signal   i_sysvia_D_out			: std_logic_vector(7 downto 0);
	signal   i_sysvia_D_oe			: std_logic;
	signal   i_sysvia_nIRQ			: std_logic;

begin

	SYS_1MHzE_o	<= i_SYS_1MHzE;
	SYS_2MHzE_o	<= i_SYS_2MHzE;

	SYS_nIRQ_o <= i_sysvia_nIRQ;
	SYS_nNMI_o <= '1';
	hsync_o <= r_hsync;
	vsync_o <= r_vsync;

	g_sys_buf:IF G_MK3 GENERATE
		-- model the 74LVC4245 on the data lines
		i_SYS_BUF_D_nOE_dly <= SYS_BUF_D_nOE_i after 8 ns;
		i_SYS_BUF_D_DIR_dly <= SYS_BUF_D_DIR_i after 8 ns;

		SYS_D_io 	<= 	(others => 'Z') when i_SYS_BUF_D_DIR_dly = '0' or i_SYS_BUF_D_nOE_dly = '1' else
						   i_SYS_D after 6 ns;
		i_SYS_D 		<= 	(others => 'Z') when i_SYS_BUF_D_DIR_dly = '1' or i_SYS_BUF_D_nOE_dly = '1' else
					      SYS_D_io after 6 ns;
	END GENERATE;


	g_sys_nobuf:IF NOT G_MK3 GENERATE

		--SYS_D_io 	<= 	i_SYS_D;
		--i_SYS_D 		<= 	SYS_D_io;

		-- try and do a bidirectional assign
		GA:FOR I IN 7 downto 0 GENERATE

			p:process
			variable v_t:time;
			variable presv:boolean;
			begin
				wait on i_SYS_D(I)'transaction, SYS_D_io(I)'transaction until v_t /= now;

				v_t := now;


				SYS_D_io(I) <= 'Z';
				i_SYS_D(I)  <= 'Z';
				wait for 0 ns;

				SYS_D_io(I) <= i_SYS_D(I);
				i_SYS_D(I)  <= SYS_D_io(I);
				wait for 0 ns;
			end process;
		END GENERATE GA;
	END GENERATE;


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
			
			bbc_slow_i  	=> sys_slow_hw_dl,
			bbc_phi1_i      => i_SYS_phi1,

			bbc_phi0_o      => i_SYS_PHI0,
			bbc_2MHzE_o     => i_SYS_2MHzE,
			bbc_1MHzE_o     => i_SYS_1MHzE,

			clken4_o			 => i_clken4
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

		-- sys via
		G_SYSVIA:IF G_INCLUDE_SYSVIA GENERATE
			e_sys_via:m6522
			port map (
				-- clocking stuff
		      I_P2_H                => i_SYS_1MHzE,
	   	   RESET_L               => SYS_nRESET_i,	-- NOTE: this should be only reset on power up but all resets are hard in sim
	      	ENA_4                 => i_clken4, -- generated clken Hoglet specific 6522 implementation
	      	CLK                   => not r_CLK_16,


		      I_RW_L					 => SYS_Rnw_i,
		      I_CS1						 => i_SYS_1MHzE,
		      I_CS2_L					 => i_sysvia_cs2,
		
		      O_IRQ_L               => i_sysvia_nIRQ,

	         I_RS                  => i_SYS_A(3 downto 0),
	      	I_DATA                => SYS_D_io,
	      	O_DATA                => i_sysvia_D_out,
	      	O_DATA_OE_L           => i_sysvia_D_oe,

		      -- port a
		      I_CA1                 => '1',
		      I_CA2                 => '1',
		      O_CA2                 => open,
		      O_CA2_OE_L            => open,

		      I_PA                  => (others => '1'),
		      O_PA                  => open,
		      O_PA_OE_L             => open,

		      -- port b
		      I_CB1                 => '1',
		      O_CB1                 => open,
		      O_CB1_OE_L            => open,

		      I_CB2                 => '1',
		      O_CB2                 => open,
		      O_CB2_OE_L            => open,

		      I_PB                  => (others => '1'),
		      O_PB                  => open,
		      O_PB_OE_L             => open
			);

			SYS_D_io <= i_sysvia_D_out when i_sysvia_D_oe = '0' else (others => 'Z');
		END GENERATE;
		G_NO_SYSVIA:IF NOT G_INCLUDE_SYSVIA GENERATE
			i_sysvia_nIRQ <= '1';
		END GENERATE;

	END GENERATE;

	G_ELK_CK:IF G_SIM_SYS_TYPE = SIM_SYS_ELK GENERATE
		e_elk_clk_gen:entity work.elk_clk_gen 
		port map (
			clk_16_i        => r_CLK_16,
			
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

		i_sysvia_nIRQ <= '1';

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
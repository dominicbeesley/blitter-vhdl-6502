
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
-- Create Date:    	9/8/2020
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - 6x09
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the 6x09 processor slot
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
use work.fishbone.all;
use work.board_config_pack.all;
use work.fb_cpu_pack.all;
use work.fb_cpu_exp_pack.all;

entity fb_cpu_6x09 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		cpu_speed_opt_i						: in cpu_speed_opt;

		fb_syscon_i								: in	fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

		-- CPU expansion signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i


	);
end fb_cpu_6x09;

architecture rtl of fb_cpu_6x09 is
	function MAX(LEFT, RIGHT: INTEGER) return INTEGER is
	begin
  		if LEFT > RIGHT then return LEFT;
  		else return RIGHT;
    	end if;
  	end;

	
-- there are 4 phases for the 6x09 cpu we will label them A,B,C,D:
--
-- Phase | Q | E | Notes
-- ------+---+---+-----------------------------------------------------------
--   A   | 0 | 0 | Start of cycle, Addr, BA, BS, RnW, timed from start
--       |   |   | of this phase but may occur in next phase
-- ------+---+---+-----------------------------------------------------------
--   B   | 1 | 0 | Busy, LIC, AVMA and write data timed from the start of 
--       |   |   | this phase
-- ------+---+---+-----------------------------------------------------------
--   C   | 1 | 1 | 
-- ------+---+---+-----------------------------------------------------------
--   D   | 0 | 1 | End of processor cycle at end of this phase, read data
--       |   |   | must meet timings for end of this phase
--       |   |   | NOTE: this phase will be stretched whilst awaiting data


-- timings
-- =======
-- Timings below for 2 MHz (68B09) and [3+ MHz HD63C09] modes
--
-- Name     | Time ns         | Notes
-- ---------+-----------------+----------------------------------------------
-- Min phase| 100 [65]        | minimum time for a single phase
-- A+B      | 210 [140]       |
-- A+B      | 220 [140]       |
-- B+C      | 220 [140]       |
-- A -> tAD | 110 [110]			| Address, RnW, BA, BS delay
-- B -> tCD | 200 [130]			| Busy, Lic, AVMA delay
-- B -> tDD | 119 [ 70]			| Write data delay
-- tDS-> D  | 40  [ 20]       | Read data setup (to end of cycle)
-- A -> tDH | 20  [ 20]			| Read data hold (from end of cycle)

-- The actual timings below are in 128MHz cycles from start of cycle 0-indexed i.e.
-- 0 =~ 7ns 11 =~ 84 ns

--! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
--TODO: Make the timings below meet specs! Currently bodged

-- Timings in fast clock cycles - 2!
-- 2MHz timings
   constant T_phA_2 : natural := 12;
   constant T_phB_2 : natural := 12;
   constant T_phC_2 : natural := 12;
   constant T_phD_2 : natural := 12;
   constant T_tAD_2 : natural := 10;		-- really should be 13
   constant T_tDD_2 : natural := 15;
   constant T_tDS_2 : natural := 2;
   constant T_tDH_2 : natural := 2;

-- 3MHz timings
   constant T_phA_3 : natural := 7;
   constant T_phB_3 : natural := 7;
   constant T_phC_3 : natural := 7;
   constant T_phD_3 : natural := 7;			-- 4*9/128 =~ 3.55MHz!
   constant T_tAD_3 : natural := 10;		-- really should be 13
   constant T_tDD_3 : natural := 8;
   constant T_tDS_3 : natural := 0;
   constant T_tDH_3 : natural := 2;
--! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !


   constant T_MAX_Ph: natural := MAX(T_phA_2, MAX(T_phB_2, MAX(T_phC_2, MAX(T_phD_2, MAX(T_phA_3, MAX(T_phB_3, MAX(T_phC_3, T_phD_3)))))));
   constant T_MAX_AD: natural := MAX(T_tAD_2, T_tAD_3);
   constant T_MAX_DD: natural := MAX(T_tDD_2, T_tDD_3);
   constant T_MAX_DS: natural := MAX(T_tDS_2, T_tDS_3);
   constant T_MAX_DH: natural := MAX(T_tDH_2, T_tDH_3);



   type t_state is (phA, phB, phC, phD);

   signal r_state 			: t_state;

   signal r_ph_ring			: std_logic_vector(T_MAX_Ph downto 0);
   signal r_AD_ring			: std_logic_vector(T_MAX_AD downto 0);
   signal r_DD_ring			: std_logic_vector(T_MAX_DD downto 0);
   signal r_DS_ring			: std_logic_vector(T_MAX_DS downto 0);
   signal r_DH_ring			: std_logic_vector(T_MAX_DH downto 0);

	signal r_cpu_6x09_FIC 	: std_logic;
	signal r_cpu_6x09_VMA	: std_logic;

	signal i_rdy				: std_logic;

	signal r_log_A				: std_logic_vector(23 downto 0);
	signal r_we					: std_logic;
	signal r_a_stb				: std_logic;
	signal i_D_wr_stb			: std_logic;
	signal r_cpu_E				: std_logic;
	signal r_cpu_Q				: std_logic;
	signal r_cpu_res			: std_logic;
	signal r_wrap_ack			: std_logic;

	signal i_CPUSKT_TSC_o	: std_logic;
	signal i_CPUSKT_CLK_Q_o	: std_logic;
	signal i_CPUSKT_CLK_E_o	: std_logic;
	signal i_CPUSKT_nHALT_o	: std_logic;
	signal i_CPUSKT_nIRQ_o	: std_logic;
	signal i_CPUSKT_nNMI_o	: std_logic;
	signal i_CPUSKT_nRES_o	: std_logic;
	signal i_CPUSKT_nFIRQ_o	: std_logic;
	
	signal i_CPU_D_RnW_o		: std_logic;

	signal i_CPUSKT_RnW_i	: std_logic;
	signal i_CPUSKT_BS_i		: std_logic;
	signal i_CPUSKT_LIC_i	: std_logic;
	signal i_CPUSKT_BA_i		: std_logic;
	signal i_CPUSKT_AVMA_i	: std_logic;

	signal i_CPUSKT_D_i		: std_logic_vector(7 downto 0);
	signal i_CPUSKT_A_i		: std_logic_vector(15 downto 0);

	signal r_cfg_not6309			: std_logic;

begin

	p_cfg:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			if fb_syscon_i.rst = '1' then
				if cpu_speed_opt_i = CPUSPEED_6309_3_5 then
					r_cfg_not6309 <= '1';
				else
					r_cfg_not6309 <= '0';
				end if;
			end if;
		end if;

	end process;


	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity error;

	e_pinmap:entity work.fb_cpu_6x09_exp_pins
	port map(

		-- cpu wrapper signals
		wrap_exp_o => wrap_exp_o,
		wrap_exp_i => wrap_exp_i,

		-- local 6x09 wrapper signals to/from CPU expansion port 

		CPUSKT_TSC_i		=> i_CPUSKT_TSC_o,
		CPUSKT_CLK_Q_i		=> i_CPUSKT_CLK_Q_o,
		CPUSKT_CLK_E_i		=> i_CPUSKT_CLK_E_o,
		CPUSKT_nHALT_i		=> i_CPUSKT_nHALT_o,
		CPUSKT_nIRQ_i		=> i_CPUSKT_nIRQ_o,
		CPUSKT_nNMI_i		=> i_CPUSKT_nNMI_o,
		CPUSKT_nRES_i		=> i_CPUSKT_nRES_o,
		CPUSKT_nFIRQ_i		=> i_CPUSKT_nFIRQ_o,

		CPUSKT_RnW_o		=> i_CPUSKT_RnW_i,
		CPUSKT_BS_o			=> i_CPUSKT_BS_i,
		CPUSKT_LIC_o		=> i_CPUSKT_LIC_i,
		CPUSKT_BA_o			=> i_CPUSKT_BA_i,
		CPUSKT_AVMA_o		=> i_CPUSKT_AVMA_i,

		-- shared per CPU signals
		CPU_D_RnW_i			=> i_CPU_D_RnW_o,

		CPUSKT_A_o			=> i_CPUSKT_A_i,
		CPUSKT_D_o			=> i_CPUSKT_D_i

	);


	i_CPU_D_RnW_o <= 	'0'	when i_CPUSKT_BA_i = '1' else
							'1' 	when i_CPUSKT_RnW_i = '1' and r_DH_ring(T_MAX_DH) = '1' else
							'0';

	wrap_o.A_log 			<= r_log_A;
																		
	-- note: don't start CYC until AS is settled
	wrap_o.cyc 				<= (0 => r_a_stb, others => '0');
	wrap_o.we	  			<= r_we;
	wrap_o.D_wr				<=	i_CPUSKT_D_i;	
	wrap_o.D_wr_stb		<= i_D_wr_stb;
	wrap_o.ack				<= r_wrap_ack;

	i_D_wr_stb <= 	r_DD_ring(T_tDD_3) when r_cfg_not6309 = '1' else
						r_DD_ring(T_tDD_2);


	p_address_latch:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			r_a_stb <= '0';
			if r_cpu_res = '0' and 
				r_cpu_6x09_VMA = '1' and (
				(r_cfg_not6309 = '1' and r_AD_ring(T_tAD_3) = '1') or (r_AD_ring(T_tAD_2) = '1') 
				) then

				if wrap_i.noice_debug_inhibit_cpu = '1' then
					r_a_stb <= '0';
				else
					r_a_stb <= '1';
					if i_CPUSKT_BS_i = '1' and i_CPUSKT_BA_i = '0' then
						-- toggle A(11) on vector pull to avoid MOS jump table
						r_log_A <= x"FF" & i_CPUSKT_A_i(15 downto 12) & not(i_CPUSKT_A_i(11)) & i_CPUSKT_A_i(10 downto 0) ;
					else 
						r_log_A <= x"FF" & i_CPUSKT_A_i;
					end if;
					r_we <= not(i_CPUSKT_RnW_i);
				end if;

			end if;
		end if;
	end process;


	p_state:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then

			if fb_syscon_i.rst = '1' then
				r_cpu_res <= '1';
			end if;

			r_PH_ring <= r_PH_ring(r_PH_ring'high-1 downto 0) & "1";
			r_AD_ring <= r_AD_ring(r_AD_ring'high-1 downto 0) & "0";
			r_DD_ring <= r_DD_ring(r_DD_ring'high-1 downto 0) & "0";

			if wrap_i.rdy_ctdn = RDY_CTDN_MIN then
				r_DS_ring <= r_DS_ring(r_DS_ring'high-1 downto 0) & "1";
			else
				r_DS_ring <= (others => '0');
			end if;

			if r_state = phD then
				r_DH_ring <= (others => '1');
			else
				r_DH_ring <= r_DH_ring(r_DH_ring'high-1 downto 0) & "0";
			end if;

			r_wrap_ack <= '0';

			case r_state is
				when phA => 
					if (r_cfg_not6309 = '1' and r_PH_ring(T_phA_3) = '1') or r_PH_ring(T_phA_2) = '1' then
						r_state <= phB;
						r_DD_ring <= (0 => '1', others => '0');
						r_cpu_Q <= '1';
						r_ph_ring <= (others => '0');
					end if;
				when phB =>
					if (r_cfg_not6309 = '1' and r_PH_ring(T_phB_3) = '1') or r_PH_ring(T_phB_2) = '1' then
						r_state <= phC;
						r_cpu_E <= '1';
						r_ph_ring <= (others => '0');
					end if;
				when phC =>
					if (r_cfg_not6309 = '1' and r_PH_ring(T_phC_3) = '1') or r_PH_ring(T_phC_2) = '1' then
						r_state <= phD;
						r_cpu_Q <= '0';
						r_ph_ring <= (others => '0');
					end if;
				when phD =>
					if (r_cfg_not6309 = '1' and r_PH_ring(T_phD_3) = '1') or r_PH_ring(T_phD_2) = '1' then
						if 
							r_cpu_res = '1' 
							or r_cpu_6x09_VMA = '0' 
							or (r_cfg_not6309 = '1' and r_DS_ring(T_tDS_3) = '1')
							or wrap_i.noice_debug_inhibit_cpu = '1'
							or r_DS_ring(T_tDS_2) = '1' then
							r_state <= phA;
							r_cpu_6x09_FIC <= i_CPUSKT_LIC_i;
							if SIM then
								-- horrible bodge - our cpu model doesn't do AVMA correctly!
								r_cpu_6x09_VMA <= '1';
							else
								r_cpu_6x09_VMA <= i_CPUSKT_AVMA_i;
							end if;
							r_AD_ring <= (0 => '1', others => '0');
							r_wrap_ack <= '1';
							r_cpu_E <= '0';
							r_ph_ring <= (others => '0');
							if fb_syscon_i.rst = '0' then
								r_cpu_res <= '0';
							end if;
						end if;
					end if;
				when others =>
					r_state <= phA;
					r_cpu_6x09_FIC <= i_CPUSKT_LIC_i;
					if SIM then
						-- horrible bodge - our cpu model doesn't do AVMA correctly!
						r_cpu_6x09_VMA <= '1';
					else
						r_cpu_6x09_VMA <= i_CPUSKT_AVMA_i;
					end if;
					r_AD_ring <= (0 => '1', others => '0');
					r_wrap_ack <= '1';
					r_cpu_Q <= '0';
					r_cpu_E <= '0';
					r_ph_ring <= (others => '0');
					if fb_syscon_i.rst = '0' then
						r_cpu_res <= '0';
					end if;
				end case;
		end if;
	end process;

	i_CPUSKT_TSC_o <= not cpu_en_i;

	i_CPUSKT_CLK_E_o <= r_cpu_E;
	
	i_CPUSKT_CLK_Q_o <= r_cpu_Q;

	i_CPUSKT_nRES_o <= (not r_cpu_res) when cpu_en_i = '1' else '0';
	
	i_CPUSKT_nNMI_o <= wrap_i.noice_debug_nmi_n;
	
	i_CPUSKT_nIRQ_o <=  wrap_i.irq_n;
  	
  	i_CPUSKT_nFIRQ_o <=  wrap_i.nmi_n;

  	-- NOTE: for 6x09 we don't need to register RDY, instead allow the CPU to latch it and use the AS/BS signals
  	-- to direct cyc etc

  	i_CPUSKT_nHALT_o <= 	i_rdy;

  	i_rdy <=								'1' when fb_syscon_i.rst = '1' else
  											'1' when wrap_i.noice_debug_inhibit_cpu = '1' else
  											'0' when wrap_i.cpu_halt = '1' else
  											'1';						


  	wrap_o.noice_debug_cpu_clken <= r_wrap_ack;
  	
  	wrap_o.noice_debug_5c	 	 	<=	'0';

  	wrap_o.noice_debug_opfetch 	<= r_cpu_6x09_FIC;

	wrap_o.noice_debug_A0_tgl  	<= '0'; -- TODO: check if needed


end rtl;


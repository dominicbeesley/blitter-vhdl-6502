
-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2020 Dominic Beesley https://github.com/dominicbeesley
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
-- Module Name:    	fishbone bus - CPU wrapper component - 6800
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the 6800 processor slot
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
use work.mk3blit_pack.all;


entity fb_cpu_6800 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;
		G_BYTELANES							: positive	:= 1
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;							-- 1 when this cpu is the current one
		cpu_speed_i								: in std_logic_vector(2 downto 0);

		fb_syscon_i								: in	fb_syscon_t;

		-- noice debugger signals to cpu
		noice_debug_nmi_n_i					: in	std_logic;		-- debugger is forcing a cpu NMI
		noice_debug_shadow_i					: in	std_logic;		-- debugger memory MOS map is active (overrides shadow_mos)
		noice_debug_inhibit_cpu_i			: in	std_logic;		-- during a 5C op code, inhibit address / data to avoid
																				-- spurious memory accesses
		-- noice debugger signals from cpu
		noice_debug_5c_o						: out	std_logic;		-- A 5C instruction is being fetched (qualify with clken below)
		noice_debug_cpu_clken_o				: out	std_logic;		-- clken and cpu rdy
		noice_debug_A0_tgl_o					: out	std_logic;		-- 1 when current A0 is different to previous fetched
		noice_debug_opfetch_o				: out	std_logic;		-- this cycle is an opcode fetch

		-- direct CPU control signals from system
		nmi_n_i									: in	std_logic;
		irq_n_i									: in	std_logic;

		-- state machine signals
		wrap_cyc_o								: out std_logic_vector(G_BYTELANES-1 downto 0);
		wrap_A_log_o							: out std_logic_vector(23 downto 0);	-- this will be passed on to fishbone after to log2phys mapping
		wrap_A_we_o								: out std_logic;								-- we signal for this cycle
		wrap_D_WR_stb_o						: out std_logic;								-- for write cycles indicates write data is ready
		wrap_D_WR_o								: out std_logic_vector(7 downto 0);		-- write data
		wrap_ack_o								: out std_logic;

		wrap_rdy_ctdn_i						: in unsigned(RDY_CTDN_LEN-1 downto 0);
		wrap_cyc_i								: in std_logic;

		-- chipset control signals
		cpu_halt_i								: in  std_logic;

		CPU_D_RnW_o								: out		std_logic;								-- '1' cpu is reading, else writing

		-- cpu socket signals
		CPUSKT_D_i								: in		std_logic_vector((G_BYTELANES*8)-1 downto 0);

		CPUSKT_A_i								: in		std_logic_vector(23 downto 0);

		exp_PORTB_o								: out		std_logic_vector(7 downto 0);

		exp_PORTD_i								: in		std_logic_vector(11 downto 0);
		exp_PORTD_o								: out		std_logic_vector(11 downto 0);
		exp_PORTD_o_en							: out		std_logic_vector(11 downto 0);
		exp_PORTE_nOE							: out		std_logic;	-- enable that multiplexed buffer chip
		exp_PORTF_nOE							: out		std_logic	-- enable that multiplexed buffer chip

	);
end fb_cpu_6800;

architecture rtl of fb_cpu_6800 is
	function MAX(LEFT, RIGHT: INTEGER) return INTEGER is
	begin
  		if LEFT > RIGHT then return LEFT;
  		else return RIGHT;
    	end if;
  	end;
	
   type t_state is (phi1, phi2);

   signal r_state 			: t_state;

   constant T_MAX_Ph			: natural := (128/4)-2;	-- 2Mhz
   constant T_MAX_DBE		: natural := 10;			-- >75ns
   constant T_MAX_DH			: natural := 2;			-- >10 ns
   --constant T_MAX_DS			: natural := 6;			-- >40 ns
--   constant T_MAX_DS			: natural := 6;				-- ~46 ns
   constant T_MAX_DS			: natural := 4;				-- ~32 ns
   constant T_MAX_DD			: natural := T_MAX_DBE+11;	-- ~160 ns after DBE
-- constant T_MAX_AD			: natural := 17;			-- >135 ns
   constant T_MAX_AD			: natural := 12;			-- >

   signal r_ph_ring			: std_logic_vector(T_MAX_Ph downto 0); -- max ring counter size for each phase
   signal r_AD_ring			: std_logic_vector(T_MAX_AD downto 0);	-- Address ready
   signal r_DD_ring			: std_logic_vector(T_MAX_DD downto 0); -- write data ready from DBE asserted
   signal r_DS_ring			: std_logic_vector(T_MAX_DS downto 0); -- data setup for reads
   signal r_DH_ring			: std_logic_vector(T_MAX_DH downto 0);	-- data hold for reads
   signal r_DBE_ring			: std_logic_vector(T_MAX_DBE downto 0);

	signal i_rdy				: std_logic;

	signal r_log_A				: std_logic_vector(23 downto 0);
	signal r_we					: std_logic;
	signal r_a_stb				: std_logic;
	signal r_cpu_phi1			: std_logic;
	signal r_cpu_phi2			: std_logic;
	signal r_cpu_res			: std_logic;
	signal r_wrap_ack			: std_logic;

	signal i_CPUSKT_TSC_o	: std_logic;
	signal i_CPUSKT_Phi1_o	: std_logic;
	signal i_CPUSKT_Phi2_o	: std_logic;
	signal i_CPUSKT_nHALT_o	: std_logic;
	signal i_CPUSKT_nIRQ_o	: std_logic;
	signal i_CPUSKT_nNMI_o	: std_logic;
	signal i_CPUSKT_nRES_o	: std_logic;
	signal i_CPUSKT_DBE_o	: std_logic;

	signal i_CPUSKT_RnW_i	: std_logic;
	signal i_CPUSKT_BA_i		: std_logic;
	signal i_CPUSKT_VMA_i	: std_logic;

begin

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity error;


	exp_PORTB_o(0) <= i_CPUSKT_TSC_o;
	exp_PORTB_o(1) <= i_CPUSKT_Phi1_o;
	exp_PORTB_o(2) <= i_CPUSKT_Phi2_o;
	exp_PORTB_o(3) <= i_CPUSKT_nHALT_o;
	exp_PORTB_o(4) <= i_CPUSKT_nIRQ_o;
	exp_PORTB_o(5) <= i_CPUSKT_nNMI_o;
	exp_PORTB_o(6) <= i_CPUSKT_nRES_o;
	exp_PORTB_o(7) <= i_CPUSKT_DBE_o;


	i_CPUSKT_RnW_i		<= exp_PORTD_i(1);
	i_CPUSKT_BA_i		<= exp_PORTD_i(5);
	i_CPUSKT_VMA_i		<= exp_PORTD_i(6);

	exp_PORTD_o <= (
		others => '1'
		);

	exp_PORTD_o_en <= (
		others => '0'
		);

	exp_PORTE_nOE <= '0';
	exp_PORTF_nOE <= '1';

	CPU_D_RnW_o <= 	'1' 	when i_CPUSKT_RnW_i = '1' and r_DH_ring(T_MAX_DH) = '1' else
							'0';

	wrap_A_log_o 			<= r_log_A;
																		
	-- note: don't start CYC until AS is settled
	wrap_cyc_o 				<= (0 => r_a_stb, others => '0');
	wrap_A_we_o  			<= r_we;
	wrap_D_wr_o				<=	CPUSKT_D_i(7 downto 0);	
	wrap_D_wr_stb_o		<= r_DD_ring(T_MAX_DD);
	wrap_ack_o				<= r_wrap_ack;



	p_address_latch:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			r_a_stb <= '0';
			if r_cpu_res = '0' and i_CPUSKT_VMA_i = '1' and r_AD_ring(T_MAX_AD) = '1'  then
				--TODO: noice inhibit?
				r_a_stb <= '1';
				r_log_A <= x"FF" & CPUSKT_A_i(15 downto 0);
				r_we <= not(i_CPUSKT_RnW_i);
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
			r_DBE_ring <= r_DBE_ring(r_DBE_ring'high-1 downto 0) & "1";

			if wrap_rdy_ctdn_i = RDY_CTDN_MIN then
				r_DS_ring <= r_DS_ring(r_DS_ring'high-1 downto 0) & "1";
			else
				r_DS_ring <= (others => '0');
			end if;

			if r_state = Phi2 then
				r_DH_ring <= (others => '1');
			else
				r_DH_ring <= r_DH_ring(r_DH_ring'high-1 downto 0) & "0";
			end if;

			r_wrap_ack <= '0';

			case r_state is
				when Phi1 => 
					if r_PH_ring(T_MAX_Ph) then
						r_state <= Phi2;
						r_DD_ring <= (0 => '1', others => '0');
						r_cpu_phi2 <= '1';
						r_cpu_phi1 <= '0';
						r_ph_ring <= (others => '0');
					end if;
				when Phi2 =>
					if r_PH_ring(T_MAX_Ph) = '1' then
						if r_cpu_res = '1' or i_CPUSKT_VMA_i = '0' or r_DS_ring(T_MAX_DS) = '1' then
							r_state <= Phi1;
							r_AD_ring <= (0 => '1', others => '0');
							r_wrap_ack <= '1';
							r_cpu_phi1 <= '1';
							r_DBE_ring <= (others => '0');
							r_cpu_phi2 <= '0';
							r_ph_ring <= (others => '0');
							if fb_syscon_i.rst = '0' then
								r_cpu_res <= '0';
							end if;
						else
							r_PH_ring <= r_PH_ring; -- keep the phase where it is
						end if;
					end if;
				when others =>
					r_state <= phi1;
					r_AD_ring <= (0 => '1', others => '0');
					r_wrap_ack <= '1';
					r_cpu_phi1 <= '1';
					r_cpu_phi2 <= '0';
					r_DBE_ring <= (others => '0');
					r_ph_ring <= (others => '0');
					if fb_syscon_i.rst = '0' then
						r_cpu_res <= '0';
					end if;
				end case;
		end if;
	end process;

	i_CPUSKT_TSC_o <= not cpu_en_i;
		
	i_CPUSKT_Phi1_o <= r_cpu_Phi1;
	
	i_CPUSKT_Phi2_o <= r_cpu_Phi2;
	
	i_CPUSKT_nRES_o <= (not r_cpu_res) when cpu_en_i = '1' else '0';
	
	i_CPUSKT_nNMI_o <= noice_debug_nmi_n_i and nmi_n_i;
	
	i_CPUSKT_nIRQ_o <=  irq_n_i;
  	
  	i_CPUSKT_DBE_o <= r_DBE_ring(T_MAX_DBE);

  	-- NOTE: for 6x09 we don't need to register RDY, instead allow the CPU to latch it and use the AS/BS signals
  	-- to direct cyc etc

  	i_CPUSKT_nHALT_o <= 	i_rdy;

  	i_rdy <=								'0' when cpu_halt_i = '1' else
  											'1';						


  	noice_debug_cpu_clken_o <= r_wrap_ack;
  	
  	noice_debug_5c_o	 	 	<=	'0';

  	noice_debug_opfetch_o 	<= '0';

	noice_debug_A0_tgl_o  	<= '0'; -- TODO: check if needed


end rtl;



--           .---.
--          /. ./|                                  ,--,
--      .--'.  ' ;             __  ,-.      ,---, ,--.'|         ,---,
--     /__./ \ : |           ,' ,'/ /|  ,-+-. /  ||  |,      ,-+-. /  |  ,----._,.
-- .--'.  '   \' .  ,--.--.  '  | |' | ,--.'|'   |`--'_     ,--.'|'   | /   /  ' /
--/___/ \ |    ' ' /       \ |  |   ,'|   |  ,"' |,' ,'|   |   |  ,"' ||   :     |
--;   \  \;      :.--.  .-. |'  :  /  |   | /  | |'  | |   |   | /  | ||   | .\  .
-- \   ;  `      | \__\/: . .|  | '   |   | |  | ||  | :   |   | |  | |.   ; ';  |
--  .   \    .\  ; ," .--.; |;  : |   |   | |  |/ '  : |__ |   | |  |/ '   .   . |
--   \   \   ' \ |/  /  ,.  ||  , ;   |   | |--'  |  | '.'||   | |--'   `---`-'| |
--    :   '  |--";  :   .'   \---'    |   |/      ;  :    ;|   |/       .'__/\_: |
--     \   \ ;   |  ,     .-./        '---'       |  ,   / '---'        |   :    :
--      '---"     `--`---'                         ---`-'                \   \  /
--                                                                        `--`-'

-- A bit flaky on test, occasionally crashes on test-1.ihx in mode 0. Not sure if
-- data setup or address setup is too tight

-- TODO: sys accesses are at 1MHz!

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
use work.board_config_pack.all;
use work.fb_cpu_pack.all;
use work.fb_cpu_exp_pack.all;

entity fb_cpu_6800 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;
		G_BYTELANES							: positive	:= 1
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;							-- 1 when this cpu is the current one

		fb_syscon_i								: in	fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

		-- CPU expansion signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i

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
   constant T_MAX_DS			: natural := 2;				-- ~32 ns
   constant T_MAX_DD			: natural := T_MAX_DBE+11;	-- ~160 ns after DBE
-- constant T_MAX_AD			: natural := 17;			-- >135 ns
   constant T_MAX_AD			: natural := 11;			-- >

   signal r_ph_ring			: std_logic_vector(T_MAX_Ph downto 0); -- max ring counter size for each phase
   signal r_AD_ring			: std_logic_vector(T_MAX_AD downto 0);	-- Address ready
   signal r_DD_ring			: std_logic_vector(T_MAX_DD downto 0); -- write data ready from DBE asserted
   signal r_DS_ring			: std_logic_vector(T_MAX_DS downto 0); -- data setup for reads
   signal r_DH_ring			: std_logic_vector(T_MAX_DH downto 0);	-- data hold for reads
   signal r_DBE_ring			: std_logic_vector(T_MAX_DBE downto 0);

	signal i_rdy				: std_logic;

	signal r_log_A				: std_logic_vector(23 downto 0);
	signal r_we					: std_logic;
	signal r_cyc				: std_logic;
	signal r_cpu_phi1			: std_logic;
	signal r_cpu_phi2			: std_logic;
	signal r_cpu_res			: std_logic;
	signal r_wrap_ack			: std_logic;

	signal i_CPUSKT_TSC_b2c	: std_logic;
	signal i_CPUSKT_Phi1_b2c	: std_logic;
	signal i_CPUSKT_Phi2_b2c	: std_logic;
	signal i_CPUSKT_nHALT_b2c	: std_logic;
	signal i_CPUSKT_nIRQ_b2c	: std_logic;
	signal i_CPUSKT_nNMI_b2c	: std_logic;
	signal i_CPUSKT_nRES_b2c	: std_logic;
	signal i_CPUSKT_DBE_b2c	: std_logic;

	signal i_BUF_D_RnW_b2c		: std_logic;

	signal i_CPUSKT_RnW_c2b	: std_logic;
	signal i_CPUSKT_BA_c2b		: std_logic;
	signal i_CPUSKT_VMA_c2b	: std_logic;

	signal i_CPUSKT_D_c2b		: std_logic_vector(7 downto 0);
	signal i_CPUSKT_A_c2b		: std_logic_vector(15 downto 0);

begin

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity error;

	e_pinmap:entity work.fb_cpu_6800_exp_pins
	port map(

		-- cpu wrapper signals
		wrap_exp_o => wrap_exp_o,
		wrap_exp_i => wrap_exp_i,

		-- local 6800 wrapper signals to/from CPU expansion port 
		CPUSKT_TSC_b2c		=> i_CPUSKT_TSC_b2c,
		CPUSKT_Phi1_b2c	=> i_CPUSKT_Phi1_b2c,
		CPUSKT_Phi2_b2c	=> i_CPUSKT_Phi2_b2c,
		CPUSKT_nHALT_b2c	=> i_CPUSKT_nHALT_b2c,
		CPUSKT_nIRQ_b2c	=> i_CPUSKT_nIRQ_b2c,
		CPUSKT_nNMI_b2c	=> i_CPUSKT_nNMI_b2c,
		CPUSKT_nRES_b2c	=> i_CPUSKT_nRES_b2c,
		CPUSKT_DBE_b2c		=> i_CPUSKT_DBE_b2c,
		CPUSKT_D_b2c		=> wrap_i.D_rd(7 downto 0),

		CPUSKT_RnW_c2b		=> i_CPUSKT_RnW_c2b,
		CPUSKT_BA_c2b		=> i_CPUSKT_BA_c2b,
		CPUSKT_VMA_c2b		=> i_CPUSKT_VMA_c2b,

		-- shared per CPU signals
		BUF_D_RnW_b2c		=> i_BUF_D_RnW_b2c,

		CPUSKT_A_c2b		=> i_CPUSKT_A_c2b,
		CPUSKT_D_c2b		=> i_CPUSKT_D_c2b

	);


	

	i_BUF_D_RnW_b2c <= 	i_CPUSKT_RnW_c2b;

	wrap_o.BE				<= '0';
	wrap_o.A 				<= r_log_A;
																		
	-- note: don't start CYC until AS is settled
	wrap_o.cyc				<= r_cyc;
	wrap_o.lane_req		<= (0 => '1', others => '0');
	wrap_o.we	  			<= r_we;
	wrap_o.D_wr(7 downto 0)	<=	i_CPUSKT_D_c2b;	
	G_D_WR_EXT:if C_CPU_BYTELANES > 1 GENERATE
		wrap_o.D_WR((8*C_CPU_BYTELANES)-1 downto 8) <= (others => '-');
	END GENERATE;	
	wrap_o.D_wr_stb		<= (0 => r_DD_ring(T_MAX_DD), others => '0');
	wrap_o.rdy_ctdn		<= RDY_CTDN_MIN;



	p_address_latch:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_cyc <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if r_cpu_res = '0' and i_CPUSKT_VMA_c2b = '1' and r_AD_ring(T_MAX_AD) = '1'  then
				--TODO: noice inhibit?
				r_cyc <= '1';
				r_log_A <= x"FF" & i_CPUSKT_A_c2b(15 downto 0);
				r_we <= not(i_CPUSKT_RnW_c2b);
			elsif r_cyc = '1' and r_wrap_ack = '1' then
				r_cyc <= '0';
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
			r_DD_ring <= r_DD_ring(r_DD_ring'high-1 downto 0) & "1";
			r_DBE_ring <= r_DBE_ring(r_DBE_ring'high-1 downto 0) & "1";

			if wrap_i.ack = '1' then
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
					r_DD_ring <= (0 => '1', others => '0');
					if r_PH_ring(T_MAX_Ph) then
						r_state <= Phi2;
						r_cpu_phi2 <= '1';
						r_cpu_phi1 <= '0';
						r_ph_ring <= (others => '0');
					end if;
				when Phi2 =>
					if r_PH_ring(T_MAX_Ph) = '1' then
						if r_cpu_res = '1' or i_CPUSKT_VMA_c2b = '0' or r_DS_ring(T_MAX_DS) = '1' then
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

	i_CPUSKT_TSC_b2c <= not cpu_en_i;
		
	i_CPUSKT_Phi1_b2c <= r_cpu_Phi1;
	
	i_CPUSKT_Phi2_b2c <= r_cpu_Phi2;
	
	i_CPUSKT_nRES_b2c <= (not r_cpu_res) when cpu_en_i = '1' else '0';
	
	i_CPUSKT_nNMI_b2c <= wrap_i.noice_debug_nmi_n and wrap_i.nmi_n;
	
	i_CPUSKT_nIRQ_b2c <=  wrap_i.irq_n;
  	
  	i_CPUSKT_DBE_b2c <= r_DBE_ring(T_MAX_DBE);

  	-- NOTE: for 6x09 we don't need to register RDY, instead allow the CPU to latch it and use the AS/BS signals
  	-- to direct cyc etc

  	i_CPUSKT_nHALT_b2c <= 	i_rdy;

  	i_rdy <=								'0' when wrap_i.cpu_halt = '1' else
  											'1';						


  	wrap_o.noice_debug_cpu_clken <= r_wrap_ack;
  	
  	wrap_o.noice_debug_5c	 	 	<=	'0';

  	wrap_o.noice_debug_opfetch 	<= '0';

	wrap_o.noice_debug_A0_tgl  	<= '0'; -- TODO: check if needed


end rtl;


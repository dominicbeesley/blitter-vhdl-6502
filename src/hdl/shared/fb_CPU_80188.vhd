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
-- Create Date:    	29/1/2022
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - 80C188XL
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the 80188 processor board
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

entity fb_cpu_80188 is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;
		G_BYTELANES							: positive	:= 1
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;							-- 1 when this cpu is the current one

		cpu_16bit_i								: in std_logic;							-- 1 when this is actually a 80C186

		fb_syscon_i								: in	fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

		-- CPU expansion signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i;

		-- debug signals

		debug_80188_state_o					: out std_logic_vector(2 downto 0);
		debug_80188_ale_o						: out std_logic

	);
end fb_cpu_80188;

architecture rtl of fb_cpu_80188 is
	function MAX(LEFT, RIGHT: INTEGER) return INTEGER is
	begin
  		if LEFT > RIGHT then return LEFT;
  		else return RIGHT;
    	end if;
  	end;
	
   type t_state is (idle, IntAck, ActRead, ActWrite, ActWrite2, ActHalt, ActRel);

   signal r_state 			: t_state;

   constant T_MAX_X1			: natural := (128/64);	-- 32Mhz X1

   signal r_X1_ring			: std_logic_vector(T_MAX_X1-1 downto 0) := (0 => '1', others => '0'); -- max ring counter size for each phase
   signal r_X1					: std_logic;

	signal r_log_A				: std_logic_vector(23 downto 0);
	signal r_lanes				: std_logic_vector(1 downto 0);
	signal r_we					: std_logic;
	signal r_cyc				: std_logic;
	signal r_wrap_ack			: std_logic;
	signal r_d_wr_stb			: std_logic;

	signal i_CPUSKT_nTEST_b2c	: std_logic;
	signal i_CPUSKT_X1_b2c		: std_logic;
	signal i_CPUSKT_SRDY_b2c	: std_logic;
	signal i_CPUSKT_ARDY_b2c	: std_logic;
	signal i_CPUSKT_INT0_b2c	: std_logic;
	signal i_CPUSKT_nNMI_b2c	: std_logic;
	signal i_CPUSKT_nRES_b2c	: std_logic;
	signal i_CPUSKT_INT1_b2c	: std_logic;
	signal i_CPUSKT_DRQ0_b2c	: std_logic;

	signal i_CPUSKT_INT2_b2c	: std_logic;
	signal i_CPUSKT_HOLD_b2c	: std_logic;
	signal i_CPUSKT_INT3_b2c	: std_logic;

	signal i_CPUSKT_nS_c2b		: std_logic_vector(2 downto 0);
	signal i_CPUSKT_nUCS_c2b	: std_logic;
	signal i_CPUSKT_nLCS_c2b	: std_logic;
	signal i_CPUSKT_RESET_c2b	: std_logic;
	signal i_CPUSKT_CLKOUT_c2b	: std_logic;

	signal i_CPUSKT_nRD_c2b		: std_logic;
	signal i_CPUSKT_nWR_c2b		: std_logic;
	signal i_CPUSKT_nDEN_c2b	: std_logic;
	signal i_CPUSKT_DTnR_c2b	: std_logic;
	signal i_CPUSKT_ALE_c2b		: std_logic;
	signal i_CPUSKT_HLDA_c2b	: std_logic;
	signal i_CPUSKT_nLOCK_c2b	: std_logic;
	signal i_CPUSKT_BHE_c2b		: std_logic;

	signal i_BUF_D_RnW_L_b2c	: std_logic;
	signal i_BUF_D_RnW_H_b2c	: std_logic;

	signal i_CPUSKT_A_c2b		: std_logic_vector(19 downto 0);
	signal i_CPUSKT_D_c2b		: std_logic_vector(15 downto 0);

	signal r_CLK_meta				: std_logic_vector((T_MAX_X1 * 4 - 2) downto 0);
	signal i_CPU_CLK_posedge	: std_logic;
	signal i_CPU_CLK_negedge	: std_logic;

	signal r_SRDY					: std_logic;

	signal i_mem_addr				: std_logic_vector(23 downto 0);
	signal i_io_addr				: std_logic_vector(23 downto 0);

begin

	

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity failure;
	assert C_CPU_BYTELANES >= 2 report "Requires 2 or more byte lanes" severity failure;

	e_pinmap:entity work.fb_cpu_80188_exp_pins
	port map (

		-- cpu wrapper signals
	wrap_exp_o => wrap_exp_o,
		wrap_exp_i => wrap_exp_i,

		-- local 80188 wrapper signals to/from CPU expansion port 

		CPUSKT_nTEST_b2c		=> i_CPUSKT_nTEST_b2c,
		CPUSKT_X1_b2c			=> i_CPUSKT_X1_b2c,
		CPUSKT_SRDY_b2c		=> i_CPUSKT_SRDY_b2c,
		CPUSKT_ARDY_b2c		=> i_CPUSKT_ARDY_b2c,
		CPUSKT_INT0_b2c		=> i_CPUSKT_INT0_b2c,
		CPUSKT_nNMI_b2c		=> i_CPUSKT_nNMI_b2c,
		CPUSKT_nRES_b2c		=> i_CPUSKT_nRES_b2c,
		CPUSKT_INT1_b2c		=> i_CPUSKT_INT1_b2c,
		CPUSKT_DRQ0_b2c		=> i_CPUSKT_DRQ0_b2c,
		CPUSKT_INT2_b2c		=> i_CPUSKT_INT2_b2c,
		CPUSKT_HOLD_b2c		=> i_CPUSKT_HOLD_b2c,
		CPUSKT_INT3_b2c		=> i_CPUSKT_INT3_b2c,
		CPUSKT_D_b2c			=> wrap_i.D_rd(15 downto 0),

		BUF_D_RnW_L_b2c		=> i_BUF_D_RnW_L_b2c,
		BUF_D_RnW_H_b2c		=> i_BUF_D_RnW_H_b2c,

		CPUSKT_nS_c2b			=> i_CPUSKT_nS_c2b,
		CPUSKT_nUCS_c2b		=> i_CPUSKT_nUCS_c2b,
		CPUSKT_nLCS_c2b		=> i_CPUSKT_nLCS_c2b,
		CPUSKT_RESET_c2b		=> i_CPUSKT_RESET_c2b,
		CPUSKT_CLKOUT_c2b		=> i_CPUSKT_CLKOUT_c2b,
		CPUSKT_nRD_c2b			=> i_CPUSKT_nRD_c2b,
		CPUSKT_nWR_c2b			=> i_CPUSKT_nWR_c2b,
		CPUSKT_nDEN_c2b		=> i_CPUSKT_nDEN_c2b,
		CPUSKT_DTnR_c2b		=> i_CPUSKT_DTnR_c2b,
		CPUSKT_ALE_c2b			=> i_CPUSKT_ALE_c2b,
		CPUSKT_HLDA_c2b		=> i_CPUSKT_HLDA_c2b,
		CPUSKT_nLOCK_c2b		=> i_CPUSKT_nLOCK_c2b,
		CPUSKT_BHE_c2b			=> i_CPUSKT_BHE_c2b,

		CPUSKT_D_c2b			=> i_CPUSKT_D_c2b,
		CPUSKT_A_c2b			=> i_CPUSKT_A_c2b


	);



	p_X1:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			r_X1_ring <= r_X1_ring(r_X1_ring'high - 1 downto 0) & r_X1_ring(r_X1_ring'high);

			if r_X1_ring(0) = '1' then
				if r_X1 = '0' then
					r_X1 <= '1';
				else
					r_X1 <= '0';
				end if;
			end if;

			r_CLK_meta <= r_CLK_meta(r_CLK_meta'high-1 downto 0) & i_CPUSKT_CLKOUT_c2b;
		end if;
	end process;


	i_CPUSKT_nTEST_b2c	<= i_CPUSKT_RESET_c2b;
	i_CPUSKT_X1_b2c		<= r_X1;

	i_CPUSKT_ARDY_b2c	<= '0';
	i_CPUSKT_SRDY_b2c	<= r_SRDY;
	i_CPUSKT_INT0_b2c	<= not wrap_i.irq_n;
	i_CPUSKT_nNMI_b2c	<= wrap_i.noice_debug_nmi_n;
	i_CPUSKT_nRES_b2c	<= (not fb_syscon_i.rst) when cpu_en_i = '1' else '0';		-- TODO:does this need synchronising?
	i_CPUSKT_INT1_b2c	<= '0';
	i_CPUSKT_INT2_b2c	<= '0';
	i_CPUSKT_HOLD_b2c	<= '0';
	i_CPUSKT_INT3_b2c	<= '0';
	i_CPUSKT_DRQ0_b2c <= not wrap_i.nmi_n;


	i_BUF_D_RnW_L_b2c	<= 	'1' 	when i_CPUSKT_DTnR_c2b = '0' and i_CPUSKT_nDEN_c2b = '0' else
									'0';
	i_BUF_D_RnW_H_b2c	<= 	'1' 	when i_CPUSKT_DTnR_c2b = '0' and i_CPUSKT_nDEN_c2b = '0' and cpu_16bit_i = '1' else
									'0';

	wrap_o.BE					<= '0';
	wrap_o.cyc					<= r_cyc;
	wrap_o.A		 				<= r_log_A;
	wrap_o.lane_req(1 downto 0) <= r_lanes;
	wrap_o.we	  				<= r_we;
	wrap_o.D_wr(15 downto 0)<=	i_CPUSKT_D_c2b;	
	G_D_WR_EXT:if C_CPU_BYTELANES > 2 GENERATE
		wrap_o.D_WR((8*C_CPU_BYTELANES)-1 downto 16) <= (others => '-');
		wrap_o.lane_req(C_CPU_BYTELANES-1 downto 2) <= (others => '0');
	END GENERATE;		
	wrap_o.D_wr_stb			<= (others => r_d_wr_stb);
	wrap_o.rdy_ctdn			<= RDY_CTDN_MIN;


	i_CPU_CLK_posedge <= '1' when r_CLK_meta(r_CLK_meta'high) = '0' and r_CLK_meta(r_CLK_meta'high - 1) = '1' else
								'0';

	i_CPU_CLK_negedge <= '1' when r_CLK_meta(r_CLK_meta'high) = '1' and r_CLK_meta(r_CLK_meta'high - 1) = '0' else
								'0';



	i_io_addr <= x"FF" & i_CPUSKT_A_c2b(15 downto 0);
	i_mem_addr <= 	(i_CPUSKT_A_c2b(19) and i_CPUSKT_A_c2b(18)) & 
						(i_CPUSKT_A_c2b(19) and i_CPUSKT_A_c2b(18)) & 
						(i_CPUSKT_A_c2b(19) and i_CPUSKT_A_c2b(18)) & 
						(i_CPUSKT_A_c2b(19) and i_CPUSKT_A_c2b(18)) & 
						i_CPUSKT_A_c2b(19 downto 0);

	p_state:process(fb_syscon_i)
	variable v_start_mem_cycle:boolean;
	begin
		if fb_syscon_i.rst = '1' then
			r_log_A <= (others => '0');
			r_lanes <= (others => '0');
			r_cyc <= '0';
			r_d_wr_stb <= '0';
			r_we <= '0';
			r_wrap_ack <= '0';
			r_state <= idle;
			r_SRDY <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			r_wrap_ack <= '0';
			case r_state is
				when idle =>
					if i_CPU_CLK_posedge = '1' and i_CPUSKT_ALE_c2b = '1' then
						-- check cycle type
						v_start_mem_cycle := false;
						case i_CPUSKT_nS_c2b is
							when "000" => 
								r_state <= IntAck;	
							when "001" =>
								r_state <= ActRead;
								r_we <= '0';
								r_log_A <= i_io_addr;
								v_start_mem_cycle := true;
							when "010" =>
								r_state <= ActWrite;
								r_we <= '1';
								r_log_A <= i_io_addr;
								v_start_mem_cycle := true;
							when "011" =>
								r_state <= ActHalt;
								r_we <= '1';
							when "100"|"101" =>
								r_state <= ActRead;
								r_we <= '0';
								r_log_A <= i_mem_addr;
								v_start_mem_cycle := true;
							when "110" =>
								r_state <= ActWrite;
								r_we <= '1';
								r_log_A <= i_mem_addr;
								v_start_mem_cycle := true;
							when others =>
								r_state <= Idle; -- passive?
						end case;

						if v_start_mem_cycle then
							r_cyc <= '1';
							r_SRDY <= '0';
							if cpu_16bit_i = '0' then
								-- 8 bit just bottom lane
								r_lanes <= "01";
							else
								-- do byte lanes stuff
								r_lanes(0) <= not i_CPUSKT_A_c2b(0);
								r_lanes(1) <= not i_CPUSKT_BHE_c2b;
							end if;
						end if;
					end if;
				when ActRead =>
					-- wait for data, place on bus then wait for data and then ack
					--TODO: maybe make this two steps - wait for ack then wait for clock edge?
					if wrap_i.rdy = '1' and i_CPU_CLK_posedge = '1' then
						r_SRDY <= '1';
						r_state <= ActRel;
					end if;

				when ActWrite => 
					-- wait for data from the cpu and feed on to the wrap
					if i_CPU_CLK_posedge = '1' and i_CPUSKT_nWR_c2b = '0' then
						r_d_wr_stb <= '1';
						r_state <= ActWrite2;
					end if;

				when ActWrite2 =>
					-- wait for data, place on bus then wait for data and then ack
					--TODO: maybe make this two steps - wait for ack then wait for clock edge?
					if wrap_i.rdy = '1' and i_CPU_CLK_posedge = '1' then
						r_state <= ActRel;
						r_SRDY <= '1';
					end if;

				when ActRel =>
					-- wait for clock to go low after setting SRDY
					if i_CPUSKT_nDEN_c2b = '1' and i_CPU_CLK_negedge = '1' then
						r_wrap_ack <= '1';
						r_state <= idle;
						r_SRDY <= '0';
						r_cyc <= '0';
						r_d_wr_stb <= '0';
					end if;
				when others =>
					r_log_A <= (others => '0');
					r_cyc <= '0';
					r_we <= '0';
					r_wrap_ack <= '0';
					r_state <= idle;
			end case;

		end if;

	end process;



  	wrap_o.noice_debug_cpu_clken <= r_wrap_ack;
  	
  	wrap_o.noice_debug_5c	 	 	<=	'0';

  	wrap_o.noice_debug_opfetch 	<= '0';

	wrap_o.noice_debug_A0_tgl  	<= '0'; -- TODO: check if needed


	debug_80188_state_o <= 	"000" when r_state = idle else
							   	"001" when r_state = IntAck else
			 						"010" when r_state = ActRead else
			 						"011" when r_state = ActWrite else
			 						"100" when r_state = ActWrite2 else
			 						"101" when r_state = ActHalt else
			 						"110" when r_state = ActRel else
			 						"111";
	debug_80188_ale_o <= i_CPU_CLK_posedge;

end rtl;


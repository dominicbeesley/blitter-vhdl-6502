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
-- Create Date:    	30/5/2023
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - 386ex
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the 386ex processor board
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

entity fb_cpu_386ex is
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
		wrap_exp_i								: in t_cpu_wrap_exp_i;

		debug_ready								: out std_logic
	);
end fb_cpu_386ex;

architecture rtl of fb_cpu_386ex is
	function MAX(LEFT, RIGHT: INTEGER) return INTEGER is
	begin
  		if LEFT > RIGHT then return LEFT;
  		else return RIGHT;
    	end if;
  	end;
	
   type t_state is (idle, Refresh, IntAck, ActRead, ActWrite, ActWrite2, ActHalt, ActRel);

   signal r_state 					: t_state;

   constant T_MAX_X1					: natural := (128/128);	-- 64Mhz CLK2
	signal r_CLK_meta					: std_logic_vector(((T_MAX_X1+1) * 2) - 1 downto 0); 
--   constant T_MAX_X1					: natural := 2;
--   signal r_CLK_meta					: std_logic_vector(6 downto 0); 

   signal r_CLK2_ring				: std_logic_vector(T_MAX_X1-1 downto 0) := (0 => '1', others => '0'); -- max ring counter size for each phase
   signal r_CLK2						: std_logic;

	signal r_log_A						: std_logic_vector(23 downto 0);
	signal r_lanes						: std_logic_vector(1 downto 0);
	signal r_we							: std_logic;
	signal r_cyc						: std_logic;
	signal r_wrap_ack					: std_logic;
	signal r_d_wr_stb					: std_logic;

	signal i_CPUSKT_nSMI_b2c		: std_logic;
	signal i_CPUSKT_DRQ_b2c			: std_logic;
	signal i_CPUSKT_CLK2_b2c		: std_logic;
	signal i_CPUSKT_nREADY_b2c		: std_logic;	-- out from here for non "LBA#" cycles
	signal i_CPUSKT_nINT0_b2c		: std_logic;
	signal i_CPUSKT_nNMI_b2c		: std_logic;
	signal i_CPUSKT_RESET_b2c		: std_logic;
	signal i_CPUSKT_nNA_b2c			: std_logic;

	signal i_CPUSKT_WnR_c2b			: std_logic;
	signal i_CPUSKT_nBHE_c2b		: std_logic;
	signal i_CPUSKT_MnIO_c2b		: std_logic;
	signal i_CPUSKT_DnC_c2b			: std_logic;
	signal i_CPUSKT_nADS_c2b		: std_logic;
	signal i_CPUSKT_nLBA_c2b		: std_logic;
	signal i_CPUSKT_nREFRESH_c2b	: std_logic;
	signal i_CPUSKT_CLKOUT_c2b		: std_logic;
	signal i_CPUSKT_nSMIACT_c2b	: std_logic;
	signal i_CPUSKT_nUCS_c2b		: std_logic;
	signal i_CPUSKT_nREADY_c2b		: std_logic;	-- back in from CPU for "LBA#" cycles

	signal i_BUF_D_RnW_b2c			: std_logic;

	signal i_CPUSKT_A_c2b			: std_logic_vector(23 downto 0);
	signal i_CPUSKT_D_c2b			: std_logic_vector(15 downto 0);

	signal i_PORTE_nOE				: std_logic;
	signal i_PORTF_nOE				: std_logic;

	signal i_CPU_CLK_posedge		: std_logic;
	signal i_CPU_CLK_negedge		: std_logic;

	signal i_mem_addr					: std_logic_vector(23 downto 0);
	signal i_io_addr					: std_logic_vector(23 downto 0);
	signal i_io_blit					: std_logic;

	signal r_SRDY						: std_logic;

begin

	

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity failure;
	assert C_CPU_BYTELANES >= 2 report "Requires 2 or more byte lanes" severity failure;

	e_pinmap:entity work.fb_cpu_386ex_exp_pins
	port map (

		-- cpu wrapper signals
		wrap_exp_o => wrap_exp_o,
		wrap_exp_i => wrap_exp_i,

		-- local 80188 wrapper signals to/from CPU expansion port 

		CPUSKT_nSMI_b2c		=>	i_CPUSKT_nSMI_b2c,
		CPUSKT_DRQ_b2c			=>	i_CPUSKT_DRQ_b2c,
		CPUSKT_CLK2_b2c		=>	i_CPUSKT_CLK2_b2c,
		CPUSKT_nREADY_b2c		=>	i_CPUSKT_nREADY_b2c,
		CPUSKT_nINT0_b2c		=>	i_CPUSKT_nINT0_b2c,
		CPUSKT_nNMI_b2c		=>	i_CPUSKT_nNMI_b2c,
		CPUSKT_RESET_b2c		=>	i_CPUSKT_RESET_b2c,
		CPUSKT_nNA_b2c			=> i_CPUSKT_nNA_b2c,

		CPUSKT_D_b2c			=>	wrap_i.D_rd(15 downto 0),

		BUF_D_RnW_b2c			=> i_BUF_D_RnW_b2c,

		MUX_PORTE_nOE_i		=> i_PORTE_nOE,
		MUX_PORTF_nOE_i		=> i_PORTF_nOE,

		CPUSKT_WnR_c2b			=> i_CPUSKT_WnR_c2b,
		CPUSKT_nBHE_c2b		=> i_CPUSKT_nBHE_c2b,
		CPUSKT_MnIO_c2b		=> i_CPUSKT_MnIO_c2b,
		CPUSKT_DnC_c2b			=> i_CPUSKT_DnC_c2b,
		CPUSKT_nADS_c2b		=> i_CPUSKT_nADS_c2b,
		CPUSKT_nLBA_c2b		=> i_CPUSKT_nLBA_c2b,
		CPUSKT_nREFRESH_c2b	=> i_CPUSKT_nREFRESH_c2b,
		CPUSKT_CLKOUT_c2b		=> i_CPUSKT_CLKOUT_c2b,
		CPUSKT_nSMIACT_c2b	=> i_CPUSKT_nSMIACT_c2b,
		CPUSKT_nUCS_c2b		=> i_CPUSKT_nUCS_c2b,
		CPUSKT_nREADY_c2b		=> i_CPUSKT_nREADY_c2b,

		CPUSKT_D_c2b			=> i_CPUSKT_D_c2b,
		CPUSKT_A_c2b			=> i_CPUSKT_A_c2b
	);



	p_X1:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			r_CLK2_ring <= r_CLK2_ring(r_CLK2_ring'high - 1 downto 0) & r_CLK2_ring(r_CLK2_ring'high);

			if r_CLK2_ring(0) = '1' then
				if r_CLK2 = '0' then
					r_CLK2 <= '1';
				else
					r_CLK2 <= '0';
				end if;
			end if;

			r_CLK_meta <= r_CLK_meta(r_CLK_meta'high-1 downto 0) & i_CPUSKT_CLKOUT_c2b;
		end if;
	end process;


	i_CPUSKT_CLK2_b2c		<= r_CLK2;

	i_CPUSKT_nNA_b2c		<= '1';
	i_CPUSKT_nREADY_b2c	<= not r_SRDY;		-- note the direction of this is set in exp_pins
	i_CPUSKT_nINT0_b2c	<= wrap_i.irq_n;
	i_CPUSKT_nNMI_b2c		<= wrap_i.noice_debug_nmi_n;
	i_CPUSKT_RESET_b2c	<= fb_syscon_i.rst when cpu_en_i = '1' else '1';		-- TODO:does this need synchronising?

	i_CPUSKT_nSMI_b2c		<= '1'; --TODO: hook up as noice debug instead of nmi
	i_CPUSKT_DRQ_b2c		<= not wrap_i.nmi_n;



	i_BUF_D_RnW_b2c		<=	'1' 	when i_CPUSKT_WnR_c2b = '0' else
									'0';

	wrap_o.BE							<= '0';
	wrap_o.cyc							<= r_cyc;
	wrap_o.A		 						<= r_log_A;
	wrap_o.lane_req(1 downto 0) 	<= r_lanes;
	wrap_o.we	  						<= r_we;
	wrap_o.D_wr(15 downto 0)		<=	i_CPUSKT_D_c2b;	
	G_D_WR_EXT:if C_CPU_BYTELANES > 2 GENERATE
		wrap_o.D_WR((8*C_CPU_BYTELANES)-1 downto 16) <= (others => '-');
		wrap_o.lane_req(C_CPU_BYTELANES-1 downto 2) <= (others => '0');
	END GENERATE;		
	wrap_o.D_wr_stb					<= (others => r_d_wr_stb);
	wrap_o.rdy_ctdn					<= RDY_CTDN_MIN;


	i_CPU_CLK_posedge <= '1' when r_CLK_meta(r_CLK_meta'high) = '0' and r_CLK_meta(r_CLK_meta'high - 1) = '1' else
								'0';

	i_CPU_CLK_negedge <= '1' when r_CLK_meta(r_CLK_meta'high) = '1' and r_CLK_meta(r_CLK_meta'high - 1) = '0' else
								'0';


	i_io_blit   <= '1' when 		i_CPUSKT_A_c2b(15 downto 8) /= x"F0" 
									and   i_CPUSKT_A_c2b(15 downto 8) /= x"F4" 
									and   i_CPUSKT_A_c2b(15 downto 8) /= x"F8" 
									and  	i_CPUSKT_A_c2b(15 downto 12) /= x"0" else
						'0';

--	i_io_blit   <= '1' when i_CPUSKT_A_c2b(15 downto 12) /= x"0" else
--						'0';

	i_io_addr 	<= x"FF" & i_CPUSKT_A_c2b(15 downto 0);
	i_mem_addr 	<=	x"FF" & i_CPUSKT_A_c2b(15 downto 0) when i_CPUSKT_A_c2b(23 downto 16) = x"0F" else
						-- read version when 0Axxxx
						x"FC" & i_CPUSKT_A_c2b(15 downto 0) when i_CPUSKT_A_c2b(23 downto 16) = x"0B" else
						i_CPUSKT_A_c2b(23 downto 0);

	p_state:process(fb_syscon_i)
	variable v_start_mem_cycle:boolean;
	variable v_cycle_type:std_logic_vector(3 downto 0);
	begin
		if fb_syscon_i.rst = '1' then
			r_log_A <= (others => '0');
			r_lanes <= (others => '0');
			r_cyc <= '0';
			r_d_wr_stb <= '0';
			r_we <= '0';
			r_wrap_ack <= '0';
			r_state <= idle;
			r_SRDY <= '1';
			i_PORTE_nOE <= '0';
			i_PORTF_nOE <= '1';
		elsif rising_edge(fb_syscon_i.clk) then
			r_wrap_ack <= '0';

			case r_state is
				when idle =>
					i_PORTE_nOE <= '0';
					i_PORTF_nOE <= '1';
					if i_CPU_CLK_negedge = '1' and i_CPUSKT_nADS_c2b = '0' then
						-- check cycle type
						v_start_mem_cycle := false;
						v_cycle_type := i_CPUSKT_MnIO_c2b & i_CPUSKT_DnC_c2b & i_CPUSKT_WnR_c2b & i_CPUSKT_nREFRESH_c2b;
						case v_cycle_type is
							when "0000" | "0001" => 
								r_state <= IntAck;	
							when "0100" | "0101" =>
								-- I/O read
								if i_io_blit = '1' then
									r_state <= ActRead;
									r_we <= '0';
									r_log_A <= i_io_addr;
									v_start_mem_cycle := true;
								end if;
							when "0110" | "0111" =>
								-- I/O write
								if i_io_blit = '1' then
									r_state <= ActWrite;
									r_we <= '1';
									r_log_A <= i_io_addr;
									v_start_mem_cycle := true;
								end if;
							when "1010" | "1011" =>
								r_state <= ActHalt;
								r_we <= '0';
							when "1000" | "1001" | "1101" =>
								-- Code or Data read
								r_state <= ActRead;
								r_we <= '0';
								r_log_A <= i_mem_addr;
								v_start_mem_cycle := true;
							when "1110" | "1111" =>
								-- Data write
								r_state <= ActWrite;
								r_we <= '1';
								r_log_A <= i_mem_addr;
								v_start_mem_cycle := true;
							when "1100" =>
								r_state <= Refresh;
								r_we <= '0';								
							when others =>
								r_state <= Idle; -- passive?
						end case;

						if v_start_mem_cycle then
							r_cyc <= '1';
							-- do byte lanes stuff
							r_lanes(0) <= not i_CPUSKT_A_c2b(0);
							r_lanes(1) <= not i_CPUSKT_nBHE_c2b;
							i_PORTE_nOE <= '1';
							r_SRDY <= '0';
						end if;
					end if;
				when ActRead =>
					-- wait for data, place on bus then wait for data and then ack
					--TODO: maybe make this two steps - wait for ack then wait for clock edge?
					i_PORTF_nOE <= '0';
					if wrap_i.rdy = '1' and i_CPU_CLK_negedge = '1' then
						r_SRDY <= '1';
						r_state <= Idle;
						r_wrap_ack <= '1';
						r_state <= idle;
						r_cyc <= '0';
						r_d_wr_stb <= '0';
						i_PORTE_nOE <= '0';
						i_PORTF_nOE <= '1';
					end if;

				when ActWrite => 
					-- wait for data from the cpu and feed on to the wrap
					i_PORTF_nOE <= '0';
					if i_CPU_CLK_posedge = '1' then
						r_d_wr_stb <= '1';
						r_state <= ActWrite2;
					end if;

				when ActWrite2 =>
					if wrap_i.ack = '1' and i_CPU_CLK_negedge = '1' then
						r_SRDY <= '1';
						r_state <= Idle;
						r_wrap_ack <= '1';
						r_state <= idle;
						r_cyc <= '0';
						r_d_wr_stb <= '0';
						i_PORTE_nOE <= '0';
						i_PORTF_nOE <= '1';
					end if;
				when others =>
					r_log_A <= (others => '0');
					r_cyc <= '0';
					r_we <= '0';
					r_wrap_ack <= '0';
					r_state <= idle;
					i_PORTE_nOE <= '0';
					i_PORTF_nOE <= '1';
			end case;

		end if;

	end process;

	debug_ready <= i_CPUSKT_nREADY_c2b;

  	wrap_o.noice_debug_cpu_clken <= r_wrap_ack;
  	
  	wrap_o.noice_debug_5c	 	 	<=	'0';

  	wrap_o.noice_debug_opfetch 	<= '0';

	wrap_o.noice_debug_A0_tgl  	<= '0'; -- TODO: check if needed


end rtl;


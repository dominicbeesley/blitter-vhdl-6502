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

entity fb_cpu_80188 is
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

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

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
	signal r_we					: std_logic;
	signal r_a_stb				: std_logic;
	signal r_wrap_ack			: std_logic;
	signal r_d_wr_stb			: std_logic;

	signal i_CPUSKT_nTEST_o	: std_logic;
	signal i_CPUSKT_X1_o		: std_logic;
	signal i_CPUSKT_SRDY_o	: std_logic;
	signal i_CPUSKT_ARDY_o	: std_logic;
	signal i_CPUSKT_INT0_o	: std_logic;
	signal i_CPUSKT_nNMI_o	: std_logic;
	signal i_CPUSKT_nRES_o	: std_logic;
	signal i_CPUSKT_INT1_o	: std_logic;
	signal i_CPUSKT_DRQ0_o	: std_logic;

	signal i_CPUSKT_INT2_o	: std_logic;
	signal i_CPUSKT_HOLD_o	: std_logic;
	signal i_CPUSKT_INT3_o	: std_logic;

	signal i_CPUSKT_nS_i		: std_logic_vector(2 downto 0);
	signal i_CPUSKT_nUCS_i	: std_logic;
	signal i_CPUSKT_nLCS_i	: std_logic;
	signal i_CPUSKT_RESET_i	: std_logic;
	signal i_CPUSKT_CLKOUT_i: std_logic;

	signal i_CPUSKT_nRD_i	: std_logic;
	signal i_CPUSKT_nWR_i	: std_logic;
	signal i_CPUSKT_nDEN_i	: std_logic;
	signal i_CPUSKT_DTnR_i	: std_logic;
	signal i_CPUSKT_ALE_i	: std_logic;
	signal i_CPUSKT_HLDA_i	: std_logic;
	signal i_CPUSKT_nLOCK_i	: std_logic;

	signal r_CLK_meta			: std_logic_vector((T_MAX_X1 * 4 - 2) downto 0);
	signal i_CPU_CLK_posedge: std_logic;
	signal i_CPU_CLK_negedge: std_logic;

	signal r_SRDY				: std_logic;

	signal i_mem_addr			: std_logic_vector(23 downto 0);
	signal i_io_addr			: std_logic_vector(23 downto 0);

begin

	

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity error;


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

			r_CLK_meta <= r_CLK_meta(r_CLK_meta'high-1 downto 0) & i_CPUSKT_CLKOUT_i;
		end if;
	end process;


	i_CPUSKT_nTEST_o	<= i_CPUSKT_RESET_i;
	i_CPUSKT_X1_o		<= r_X1;

	i_CPUSKT_ARDY_o	<= '0';
	i_CPUSKT_SRDY_o	<= r_SRDY;
	i_CPUSKT_INT0_o	<= not wrap_i.irq_n;
	i_CPUSKT_nNMI_o	<= '0';
	i_CPUSKT_nRES_o	<= (not fb_syscon_i.rst) when cpu_en_i = '1' else '0';		-- TODO:does this need synchronising?
	i_CPUSKT_INT1_o	<= '0';
	i_CPUSKT_INT2_o	<= '0';
	i_CPUSKT_HOLD_o	<= '0';
	i_CPUSKT_INT3_o	<= '0';
	i_CPUSKT_DRQ0_o   <= not wrap_i.nmi_n;

	wrap_o.exp_PORTB(0)	<= i_CPUSKT_nTEST_o;
	wrap_o.exp_PORTB(1)	<= i_CPUSKT_ARDY_o;
	wrap_o.exp_PORTB(2)	<= i_CPUSKT_X1_o;
	wrap_o.exp_PORTB(3)	<= i_CPUSKT_SRDY_o;
	wrap_o.exp_PORTB(4)	<= i_CPUSKT_INT0_o;
	wrap_o.exp_PORTB(5)	<= i_CPUSKT_nNMI_o;
	wrap_o.exp_PORTB(6)	<= i_CPUSKT_nRES_o;
	wrap_o.exp_PORTB(7)	<= i_CPUSKT_INT1_o;

	--TODO: sort out CPUSKT_A
	i_CPUSKT_nS_i(0)		<= wrap_i.CPUSKT_A(0);
	i_CPUSKT_nS_i(1)		<= wrap_i.CPUSKT_A(1);
	i_CPUSKT_nS_i(2)		<= wrap_i.CPUSKT_A(2);
	i_CPUSKT_nUCS_i		<= wrap_i.CPUSKT_A(3);
	i_CPUSKT_nLCS_i		<= wrap_i.CPUSKT_A(4);
	i_CPUSKT_RESET_i		<= wrap_i.CPUSKT_A(5);
	i_CPUSKT_CLKOUT_i		<= wrap_i.CPUSKT_A(6);


	i_CPUSKT_nRD_i			<= wrap_i.exp_PORTD(0);
	i_CPUSKT_nWR_i			<= wrap_i.exp_PORTD(1);
	i_CPUSKT_nDEN_i		<= wrap_i.exp_PORTD(2);
	i_CPUSKT_DTnR_i		<= wrap_i.exp_PORTD(4);
	i_CPUSKT_ALE_i			<= wrap_i.exp_PORTD(5);
	i_CPUSKT_HLDA_i		<= wrap_i.exp_PORTD(7);
	i_CPUSKT_nLOCK_i		<= wrap_i.exp_PORTD(11);

	wrap_o.exp_PORTD <= (
		3						=> i_CPUSKT_INT2_o,
		6						=> i_CPUSKT_DRQ0_o,
		8						=> i_CPUSKT_HOLD_o,
		10						=> i_CPUSKT_INT3_o,
		others				=> '1'
		);

	wrap_o.exp_PORTD_o_en <= (
		3 => '1',
		6 => '1',
		8 => '1',
		10 => '1',	
		others => '0'
		);

	wrap_o.exp_PORTE_nOE <= '0';
	wrap_o.exp_PORTF_nOE <= '1';

	wrap_o.CPU_D_RnW <= 	'1' 	when i_CPUSKT_DTnR_i = '0' and i_CPUSKT_nDEN_i = '0' else
								'0';

	wrap_o.A_log 			<= r_log_A;
	wrap_o.cyc 				<= (0 => r_a_stb, others => '0');
	wrap_o.we	  			<= r_we;
	wrap_o.D_wr				<=	wrap_i.CPUSKT_D(7 downto 0);	
	wrap_o.D_wr_stb		<= r_d_wr_stb;
	wrap_o.ack				<= r_wrap_ack;


	i_CPU_CLK_posedge <= '1' when r_CLK_meta(r_CLK_meta'high) = '0' and r_CLK_meta(r_CLK_meta'high - 1) = '1' else
								'0';

	i_CPU_CLK_negedge <= '1' when r_CLK_meta(r_CLK_meta'high) = '1' and r_CLK_meta(r_CLK_meta'high - 1) = '0' else
								'0';



	i_io_addr <= x"FF" & wrap_i.CPUSKT_A(15 downto 8) & wrap_i.CPUSKT_D(7 downto 0);
	i_mem_addr <= 	(wrap_i.CPUSKT_A(19) and wrap_i.CPUSKT_A(18)) & 
						(wrap_i.CPUSKT_A(19) and wrap_i.CPUSKT_A(18)) & 
						(wrap_i.CPUSKT_A(19) and wrap_i.CPUSKT_A(18)) & 
						(wrap_i.CPUSKT_A(19) and wrap_i.CPUSKT_A(18)) & 
						wrap_i.CPUSKT_A(19 downto 8) & 
						wrap_i.CPUSKT_D(7 downto 0);

	p_state:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_log_A <= (others => '0');
			r_a_stb <= '0';
			r_d_wr_stb <= '0';
			r_we <= '0';
			r_wrap_ack <= '0';
			r_state <= idle;
			r_SRDY <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			r_a_stb <= '0';
			r_d_wr_stb <= '0';
			r_wrap_ack <= '0';
			case r_state is
				when idle =>
					if i_CPU_CLK_posedge = '1' and i_CPUSKT_ALE_i = '1' then
						-- check cycle type
						case i_CPUSKT_nS_i is
							when "000" => 
								r_state <= IntAck;	
							when "001" =>
								r_state <= ActRead;
								r_we <= '0';
								r_log_A <= i_io_addr;
								r_a_stb <= '1';
								r_SRDY <= '0';
							when "010" =>
								r_state <= ActWrite;
								r_we <= '1';
								r_log_A <= i_io_addr;
								r_a_stb <= '1';
								r_SRDY <= '0';
							when "011" =>
								r_state <= ActHalt;
								r_we <= '1';
							when "100"|"101" =>
								r_state <= ActRead;
								r_we <= '0';
								r_log_A <=  i_mem_addr;
								r_a_stb <= '1';
								r_SRDY <= '0';
							when "110" =>
								r_state <= ActWrite;
								r_we <= '1';
								r_log_A <= i_mem_addr;
								r_a_stb <= '1';
								r_SRDY <= '0';
							when others =>
								r_state <= Idle; -- passive?
						end case;

					end if;
				when ActRead =>
					-- wait for data, place on bus then wait for data and then ack
					if wrap_i.rdy_ctdn = RDY_CTDN_MIN and i_CPU_CLK_posedge = '1' then
						r_SRDY <= '1';
						r_state <= ActRel;
					end if;

				when ActWrite => 
					-- wait for data from the cpu and feed on to the wrap
					if i_CPU_CLK_posedge = '1' and i_CPUSKT_nWR_i = '0' then
						r_d_wr_stb <= '1';
						r_state <= ActWrite2;
					end if;

				when ActWrite2 =>
					-- wait for data, place on bus then wait for data and then ack
					if wrap_i.rdy_ctdn = RDY_CTDN_MIN and i_CPU_CLK_posedge = '1' then
						r_state <= ActRel;
						r_SRDY <= '1';
					end if;

				when ActRel =>
					-- wait for clock to go low after setting SRDY
					if i_CPUSKT_nDEN_i = '1' and i_CPU_CLK_negedge = '1' then
						r_wrap_ack <= '1';
						r_state <= idle;
						r_SRDY <= '0';
					end if;
				when others =>
					r_log_A <= (others => '0');
					r_a_stb <= '0';
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


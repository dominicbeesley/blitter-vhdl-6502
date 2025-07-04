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
-- Create Date:    	3/7/2017 
-- Design Name: 
-- Module Name:    	dmac - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		
--
--
-- Revision: 
-- Revision 0.01 - File Created
-- 			0.02 - changed control register bits around, added pause/extend, fix IE/IF behaviour
-- Additional Comments:  
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.fishbone.all;


entity fb_DMAC_int_dma_cha is
	 generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up	
		CLOCKSPEED							: natural
	 );
    Port (

		-- fishbone signals		
		fb_syscon_i							: in		fb_syscon_t;

		-- peripheral interface (control registers)
		fb_per_c2p_i						: in		fb_con_o_per_i_t;
		fb_per_p2c_o						: out		fb_con_i_per_o_t;

		-- controller interface (dma)
		fb_con_c2p_o						: out		fb_con_o_per_i_t;
		fb_con_p2c_i						: in		fb_con_i_per_o_t;

		int_o									: out		STD_LOGIC;		-- interrupt active hi
		cpu_halt_o							: out		STD_LOGIC;
		dma_halt_i							: in		STD_LOGIC

	 );

	-- original big-endian 
	 constant   A_CTL					: integer := 16#00#;
	 constant	A_SRC_ADDR_BANK	: integer := 16#01#;	 
	 constant   A_SRC_ADDR			: integer := 16#02#; 
	 constant   A_DEST_ADDR_BANK	: integer := 16#04#; 
	 constant   A_DEST_ADDR			: integer := 16#05#; 
	 constant   A_COUNT				: integer := 16#07#;
	 constant 	A_DATA				: integer := 16#09#;
	 constant 	A_CTL2				: integer := 16#0A#;
	 constant 	A_PAUSE_VAL			: integer := 16#0B#;

	-- NEW ABI: cater for little-endian pokes and 4 byte aligned access for ARM
	 constant   A_N_SRC_ADDR		: integer := 16#10#; 
	 constant	A_N_SRC_ADDR_BANK	: integer := 16#12#;	 
	 constant   A_N_DEST_ADDR		: integer := 16#14#; 
	 constant   A_N_DEST_ADDR_BANK: integer := 16#16#; 
	 constant   A_N_COUNT			: integer := 16#18#;	-- poking count 32 bit will poke data but doesn't matter
	 constant 	A_N_DATA				: integer := 16#1A#;
	 constant 	A_N_CTL				: integer := 16#1C#;
	 constant 	A_N_CTL2				: integer := 16#1D#;
	 constant 	A_N_PAUSE_VAL		: integer := 16#1E#;


end fb_DMAC_int_dma_cha;

architecture Behavioral of fb_DMAC_int_dma_cha is

	type		mas_state_type is (idle, waitack);
	type 		dma_state_type	is (sIdle, sStart, sMemAccSRC, sMemAccSRC2, sMemAccPAUSE, sMemAccDEST, sMemAccDEST2, sFinish);
	type		step_type		is (none, up, down, nop);
	type		stepsize_type	is (byte, word, wordswapdest, wordswapsrc);
	type		per_State_t		is (idle, wr, rd);

	function bits2stepsize(bits : STD_LOGIC_VECTOR(1 downto 0)) return stepsize_type is
	variable v_ret : stepsize_type;
	begin
		case bits is
			when "01" =>
				v_ret := word;
			when "10" =>
				v_ret := wordswapdest;
			when "11" =>
				v_ret := wordswapsrc;
			when others =>
				v_ret := byte;
		end case;
		return v_ret;
	end bits2stepsize;

	function stepsize2bits(ss : stepsize_type) return STD_LOGIC_VECTOR is
	variable v_ret : STD_LOGIC_VECTOR(1 downto 0);
	begin
		case ss is
			when word => 
				v_ret := "01";
			when wordswapdest => 
				v_ret := "10";
			when wordswapsrc => 
				v_ret := "11";
			when others => 
				v_ret := "00";
		end case;
		return v_ret;
	end stepsize2bits;

	function to_step(x:std_logic_vector(1 downto 0))
	return step_type is
		variable ret:step_type;
	begin
		if x = "00" then
			ret := none;
		elsif x = "01" then
			ret := up;
		elsif x = "10" then
			ret := down;
		else
			ret := nop;
		end if;
		return ret;
	end;

	function to_std_logic_vector(x:step_type)
	return std_logic_vector is
		variable ret:std_logic_vector(1 downto 0);
	begin
		if x = none then
			ret := "00";
		elsif x = up then
			ret := "01";
		elsif x = down then
			ret := "10";
		else
			ret := "11";
		end if;
		return ret;
	end;

	signal	r_per_state				: per_State_t;
	signal	r_per_addr				: std_logic_vector(4 downto 0);		-- mangled address to cater for LE/BE (LE if bit 4 set)
	signal 	i_per_D_rd				: std_logic_vector(7 downto 0);
	signal	r_per_D_rd				: std_logic_vector(7 downto 0);
	signal 	r_per_ack				: std_logic;
	signal	r_per_had_d_wr_stb	: std_logic;

	signal	r_dma_state				: dma_state_type;
	signal	i_dma_state_next		: dma_state_type;

	signal	i_next_src_addr		: std_logic_vector(15 downto 0);
	signal	i_next_dest_addr		: std_logic_vector(15 downto 0);
	signal	i_next_con_addr		: std_logic_vector(23 downto 0);					-- the address for the next controller cycle
	signal	r_con_addr				: std_logic_vector(23 downto 0);					-- the address for the current controller cycle

	signal	r_ctl_act				: std_logic;
	signal	r_ctl_step_src			: step_type;
	signal	r_ctl_step_dest		: step_type;

	signal	r_src_addr_bank		: std_logic_vector(7 downto 0);
	signal	r_src_addr				: std_logic_vector(15 downto 0);

	signal	r_dest_addr_bank		: std_logic_vector(7 downto 0);
	signal	r_dest_addr				: std_logic_vector(15 downto 0);

	signal	r_data					: std_logic_vector(15 downto 0);
	signal	r_count					: unsigned(15 downto 0);
	signal	r_count_finish			: std_logic;											-- set when count exhausted
	signal	r_count_clken 			: std_logic;

	signal	r_ctl_halt				: std_logic;	-- halt cpu
	signal	r_ctl_extend			: std_logic;

	signal	r_ctl2_pause			: std_logic;
	signal	r_ctl2_if				: std_logic;	-- interrupt flag
	signal	r_ctl2_ie				: std_logic;	-- interrupt enable
	signal	r_ctl2_stepsize		: stepsize_type;

	signal	r_pause_val				: std_logic_vector(7 downto 0);

	signal 	r_pause_ct_dn			: unsigned(11 downto 0);
	signal	r_pause_ct_dn_finished:std_logic;

	signal	r_con_state				: mas_state_type;
	signal	r_con_cyc				: std_logic;
	signal	r_con_stb				: std_logic;


	signal	i_state_change_clken	: std_logic;
begin

	-- check CLOCKSPEED is 128, assumed by pause_ct_dn

	p_addr_next_src_addr: process(i_dma_state_next, r_src_addr, r_ctl_step_src, r_ctl2_stepsize, r_ctl_extend)
	begin

		i_next_src_addr <= r_src_addr;
		case i_dma_state_next is
			when sMemAccSRC =>
				if r_ctl_extend = '0' or r_ctl2_stepsize = byte then
					if r_ctl_step_src = up then
						i_next_src_addr <= std_logic_vector(unsigned(r_src_addr) + 1);
					elsif r_ctl_step_src = down then
						i_next_src_addr <= std_logic_vector(unsigned(r_src_addr) - 1);
					end if;
				end if;
			when sMemAccSRC2 =>
				if r_ctl_step_src = up then
					i_next_src_addr <= std_logic_vector(unsigned(r_src_addr) + 2);
				elsif r_ctl_step_src = down then
					i_next_src_addr <= std_logic_vector(unsigned(r_src_addr) - 2);
				end if;
		end case;
	end process;

	p_addr_next_dest_addr: process(i_dma_state_next, r_dest_addr, r_ctl_step_dest, r_ctl2_stepsize, r_ctl_extend)
	begin
		i_next_dest_addr <= r_dest_addr;
		case i_dma_state_next is
			when sMemAccDEST  =>
				if r_ctl_extend = '0' or r_ctl2_stepsize = byte then
					if r_ctl_step_dest = up then
						i_next_dest_addr <= std_logic_vector(unsigned(r_dest_addr) + 1);
					elsif r_ctl_step_dest = down then
						i_next_dest_addr <= std_logic_vector(unsigned(r_dest_addr) - 1);
					end if;
				end if;
			when sMemAccDEST2 =>
				if r_ctl_step_dest = up then
					i_next_dest_addr <= std_logic_vector(unsigned(r_dest_addr) + 2);
				elsif r_ctl_step_dest = down then
					i_next_dest_addr <= std_logic_vector(unsigned( r_dest_addr) - 2);
				end if;
		end case;
	end process;

	p_controller_cycle_state:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_con_state <= idle;
			r_con_cyc <= '0';
			r_con_stb <= '0';
		else
			if rising_edge(fb_syscon_i.clk) then
				case r_con_state is
					when idle =>
						if dma_halt_i = '0' then
							case r_dma_state is
								when sMemAccSRC|sMemAccSRC2 =>
									if r_ctl_step_src /= nop then
										r_con_cyc <= '1';
										r_con_stb <= '1';
										r_con_state <= waitack;
									end if;
								when sMemAccDEST|sMemAccDEST2 =>
									if r_ctl_step_dest /= nop then
										r_con_cyc <= '1';
										r_con_stb <= '1';
										r_con_state <= waitack;
									end if;
								when others => null;						
							end case;
						end if;
					when waitack =>
						if fb_con_p2c_i.stall = '0' then
							r_con_stb <= '0';
						end if;
						if fb_con_p2c_i.ack = '1' then
							r_con_cyc <= '0';
							r_con_state <= idle;
						end if;
					when others => null;
				end case;
			end if;
		end if;
	end process;

	i_state_change_clken <= 
		fb_con_p2c_i.ack when r_con_cyc = '1' else
		'1' when
				r_dma_state = sIdle 
			or r_dma_state = sFinish 
			or r_dma_state = sMemAccPAUSE 
			or r_dma_state = sStart 
			or (r_dma_state = sMemAccDEST and r_ctl_step_dest = nop)
			or (r_dma_state = sMemAccDEST2 and r_ctl_step_dest = nop)
			or (r_dma_state = sMemAccSRC and r_ctl_step_src = nop)
			or (r_dma_state = sMemAccSRC2 and r_ctl_step_src = nop)
			else
		'0';

	p_stat: process(fb_syscon_i, fb_con_p2c_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_dma_state <= sIdle;
		elsif rising_edge(fb_syscon_i.clk) then
			if i_state_change_clken = '1' then --  move to next state process!
				r_dma_state <= i_dma_state_next;
			end if;
		end if;
	end process;

	p_reg_pause_ctdn:process(fb_syscon_i)	
	begin
		if fb_syscon_i.rst = '1' then
			r_pause_ct_dn <= (others => '0');
			r_pause_ct_dn_finished <= '0';
		elsif rising_edge(fb_syscon_i.clk) then 

			if r_dma_state = sMemAccPAUSE then
				if r_pause_ct_dn = 1 then
					r_pause_ct_dn_finished <= '1';
				end if;
				r_pause_ct_dn <= r_pause_ct_dn - 1;
			elsif i_dma_state_next = sMemAccPAUSE then
				if unsigned(r_pause_val) = 0 then
					r_pause_ct_dn_finished <= '1';
				end if;
				r_pause_ct_dn <= unsigned(std_logic_vector'(r_pause_val & "0000"));
			end if;
		end if;

	end process;

	-- note the order of cycles is now A,C,B,D to better interleave cycles to system ram on BBC micro
	p_next_state: process (
		r_count, r_dma_state, 
		r_ctl_act,
		r_pause_ct_dn_finished,
		r_ctl2_pause,
		r_ctl_extend,
		r_ctl2_stepsize,
		r_count_finish
		)
	begin
		case r_dma_state is
			when sStart =>
				i_dma_state_next <= sMemAccSRC;
			when sMemAccDEST =>
				if r_ctl_extend = '1' and r_ctl2_stepsize /= byte then
					i_dma_state_next <= sMemAccDEST2;
				else
					if r_count_finish = '1' then
						i_dma_state_next <= sFinish;
					else
						i_dma_state_next <= sMemAccSRC;
					end if;
				end if;
			when sMemAccDEST2 =>
				if r_count_finish = '1' then
					i_dma_state_next <= sFinish;
				else
					i_dma_state_next <= sMemAccSRC;
				end if;			
			when sFinish =>
				i_dma_state_next <= sIdle;
			when sIdle =>
				if r_ctl_act = '1' then
					i_dma_state_next <= sStart;
				else
					i_dma_state_next <= sIdle;
				end if;
			when sMemAccSRC =>
				if r_ctl_extend = '1' and r_ctl2_stepsize /= byte then
					i_dma_state_next <= sMemAccSRC2;
				else
					if r_ctl_extend = '1' and r_ctl2_pause = '1' then
						i_dma_state_next <= sMemAccPAUSE;
					else
						i_dma_state_next <= sMemAccDEST;
					end if;
				end if;
			when sMemAccSRC2 =>
				if r_ctl_extend = '1' and r_ctl2_pause = '1' then
					i_dma_state_next <= sMemAccPAUSE;
				else
					i_dma_state_next <= sMemAccDEST;
				end if;
			when sMemAccPAUSE =>
				if r_pause_ct_dn_finished = '1' then
					i_dma_state_next <= sMemAccDEST;
				else
					i_dma_state_next <= sMemAccPAUSE;
				end if;
			when others =>
				i_dma_state_next <= sFinish;		-- finish catch all
		end case;		
	end process;

	p_per_state:process(fb_syscon_i)
	variable v_do_Write:boolean;
	begin
		if fb_syscon_i.rst = '1' then
			r_per_state <= idle;
			r_per_ack <= '0';
			r_per_addr <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
			r_per_ack <= '0';

			case r_per_state is
				when idle =>
					r_per_had_d_wr_stb <= '0';
					if fb_per_c2p_i.cyc = '1' and fb_per_c2p_i.a_stb = '1' then
						r_per_addr <= fb_per_c2p_i.A(9) & fb_per_c2p_i.A(3 downto 0);
						if fb_per_c2p_i.we = '1' then
							r_per_state <= wr;
							if fb_per_c2p_i.D_wr_stb = '1' then
								r_per_had_d_wr_stb <= '1';
							end if;
						else
							r_per_state <= rd;
						end if;
					end if;
				when rd =>
					r_per_D_rd <= i_per_D_rd;
					r_per_ack <= '1';
					r_per_state <= idle;
				when wr =>
					if fb_per_c2p_i.D_wr_stb = '1' then
						r_per_had_d_wr_stb <= '1';
					end if;
					if r_per_had_d_wr_stb = '1' then
						r_per_ack <= '1';
						r_per_state <= idle;
					end if;
				when others =>
					r_per_state <= idle;

			end case;
		end if;
	end process;


	fb_per_p2c_o.D_rd <= r_per_D_rd;
	fb_per_p2c_o.rdy <= r_per_ack;
	fb_per_p2c_o.ack <= r_per_ack;
	fb_per_p2c_o.stall <= '0' when r_per_state = idle else '0';


	p_regs_wr : process(fb_syscon_i, fb_per_c2p_i)
	begin


		if fb_syscon_i.rst = '1' then
			r_ctl_act <= '0';
			r_ctl_extend <= '0';
			r_ctl_halt <= '0';
			r_ctl_step_src <= none;
			r_ctl_step_dest <= none;

			r_src_addr_bank <= (others => '0');
			r_src_addr <= (others => '0');

			r_dest_addr_bank <= (others => '0');
			r_dest_addr <= (others => '0');

			r_data <= (others => '0');
			r_count <= (others => '0');
			r_count_finish <= '0';
			r_pause_val <= (others => '0');
			r_ctl2_pause <= '0';
			r_ctl2_if <= '0';
			r_ctl2_ie <= '0';
			r_ctl2_stepsize <= byte;
			r_count_clken <= '0';
		elsif rising_edge(fb_syscon_i.clk) then

			if (r_dma_state = sFinish) then
				r_ctl_act <= '0';
				r_ctl2_if <= '1';
			end if;
				
			r_count_clken <= '0';

			if i_state_change_clken = '1' then

				-- data updates when act
				case r_dma_state is
					when sMemAccSRC =>
						if r_ctl_step_src /= nop then
							if r_ctl_extend = '1' and r_ctl2_stepsize = wordswapsrc then
								r_data(7 downto 0) <= fb_con_p2c_i.D_rd;
							else
								r_data(15 downto 8) <= fb_con_p2c_i.D_rd;
							end if;
						end if;
					when sMemAccSRC2 =>
						if r_ctl_step_src /= nop then						
							if r_ctl_extend = '1' and r_ctl2_stepsize = wordswapsrc then
								r_data(15 downto 8) <= fb_con_p2c_i.D_rd;
							else
								r_data(7 downto 0) <= fb_con_p2c_i.D_rd;
							end if;
						end if;
					when others => null;
				end case;
				-- address update when act
				case i_dma_state_next is
					when sMemAccSRC|sMemAccSRC2 =>
						r_src_addr <= i_next_src_addr;
					when sMemAccDEST|sMemAccDEST2 =>
						r_dest_addr <= i_next_dest_addr;
					when others => null;
				end case;

				r_con_addr <= i_next_con_addr;

				if (r_dma_state = sMemAccDEST and (r_ctl_extend = '0' or r_ctl2_stepsize = byte))
				or (r_dma_state = sMemAccDEST2) then
					r_count_clken <= '1';
				end if;
			end if;

			if r_count_clken = '1' then
				--TODO: this could be more efficient but needs to leave count=0 at end and do a single cycle when called with count = 0
				if r_count /= 0 then
					if r_count = 1 then
						r_count_finish <= '1';
					end if;
					r_count <= r_count - 1;
				else
					r_count_finish <= '1';
				end if;
			end if;

			if r_per_state = wr and r_per_had_d_wr_stb = '1' then

				case to_integer(unsigned(r_per_addr)) is
					when A_CTL | A_N_CTL=>
						r_ctl_act <= fb_per_c2p_i.D_wr(7);
						r_ctl_extend <= fb_per_c2p_i.D_wr(5);
						r_ctl_halt <= fb_per_c2p_i.D_wr(4);
						r_ctl_step_src <= to_step(fb_per_c2p_i.D_wr(1 downto 0));
						r_ctl_step_dest <= to_step(fb_per_c2p_i.D_wr(3 downto 2));
						r_ctl2_if <= '0';
					when A_SRC_ADDR_BANK | A_N_SRC_ADDR_BANK =>
						r_src_addr_bank <= fb_per_c2p_i.D_wr(7 downto 0);
					when A_SRC_ADDR + 0 | A_N_SRC_ADDR + 1=>
						r_src_addr(15 downto 8) <= fb_per_c2p_i.D_wr;
					when A_SRC_ADDR + 1 | A_N_SRC_ADDR + 0=>
						r_src_addr(7 downto 0) <= fb_per_c2p_i.D_wr;
					when A_DEST_ADDR_BANK | A_N_DEST_ADDR_BANK =>
						r_dest_addr_bank <= fb_per_c2p_i.D_wr(7 downto 0);
					when A_DEST_ADDR + 0 | A_N_DEST_ADDR + 1 =>
						r_dest_addr(15 downto 8) <= fb_per_c2p_i.D_wr;
					when A_DEST_ADDR + 1 | A_N_DEST_ADDR + 0 =>
						r_dest_addr(7 downto 0) <= fb_per_c2p_i.D_wr;
					when A_COUNT + 0 | A_N_COUNT + 1 =>
						r_count(15 downto 8) <= UNSIGNED(fb_per_c2p_i.D_wr);
						r_count_finish <= '0';
					when A_COUNT + 1 | A_N_COUNT + 0 =>
						r_count(7 downto 0) <= UNSIGNED(fb_per_c2p_i.D_wr);
						r_count_finish <= '0';
					when A_DATA | A_N_DATA =>
						r_data(15 downto 8) <= fb_per_c2p_i.D_wr;
						r_data(7 downto 0) <= fb_per_c2p_i.D_wr;
					when A_CTL2 | A_N_CTL2 =>
						r_ctl2_if <= '0';												-- TODO : move to a read reg?
						r_ctl2_ie <= fb_per_c2p_i.D_wr(1);
						r_ctl2_pause <= fb_per_c2p_i.D_wr(0);
						r_ctl2_stepsize <= bits2stepsize(fb_per_c2p_i.D_wr(3 downto 2));
					when A_PAUSE_VAL | A_N_PAUSE_VAL =>
						r_pause_val <= fb_per_c2p_i.D_wr;
					when others => null;
				end case;
			end if;
		end if;
	end process;

	p_regs_rd: process(r_per_addr, 	
		r_ctl_act,
		r_src_addr_bank,
		r_src_addr,
		r_ctl_step_src,
		r_dest_addr_bank,
		r_dest_addr,
		r_ctl_step_dest,
		r_data,
		r_count,
		r_ctl2_if,
		r_ctl2_ie,
		r_ctl_halt,
		r_pause_val,
		r_ctl2_pause,
		r_ctl_extend,
		r_ctl2_stepsize
		)
	begin
		case to_integer(unsigned(r_per_addr)) is
			when A_CTL =>
				i_per_D_rd <= 	r_ctl_act 
									& '0'
									& r_ctl_extend
									& r_ctl_halt
									& to_std_logic_vector(r_ctl_step_dest) 
									& to_std_logic_vector(r_ctl_step_src);
			when A_SRC_ADDR_BANK | A_N_SRC_ADDR_BANK =>
				i_per_D_rd <= r_src_addr_bank;
			when A_SRC_ADDR + 0 | A_N_SRC_ADDR + 1 =>
				i_per_D_rd <= r_src_addr(15 downto 8);
			when A_SRC_ADDR + 1 | A_N_SRC_ADDR + 0 =>
				i_per_D_rd <= r_src_addr(7 downto 0);
			when A_DEST_ADDR_BANK | A_N_DEST_ADDR_BANK =>
				i_per_D_rd <= r_dest_addr_bank;
			when A_DEST_ADDR + 0 | A_N_DEST_ADDR + 1 =>
				i_per_D_rd <= r_dest_addr(15 downto 8);
			when A_DEST_ADDR + 1 | A_N_DEST_ADDR + 0 =>
				i_per_D_rd <= r_dest_addr(7 downto 0);
			when A_COUNT + 0 | A_N_COUNT + 1 =>
				i_per_D_rd <= std_logic_vector(r_count(15 downto 8));
			when A_COUNT + 1 | A_N_COUNT + 0 =>
				i_per_D_rd <= std_logic_vector(r_count(7 downto 0));
			when A_DATA | A_N_DATA =>
				i_per_D_rd <= r_data(15 downto 8);
			when A_CTL2 | A_N_CTL2 =>
				i_per_D_rd <= r_ctl2_if
								 & "000"
								 & stepsize2bits(r_ctl2_stepsize)
								 & r_ctl2_ie
								 & r_ctl2_pause;
			when A_PAUSE_VAL | A_N_PAUSE_VAL=>
				i_per_D_rd <= r_pause_val;
			when others => 
				i_per_D_rd <= (others => '-');
		end case;
	end process;

	
	cpu_halt_o <= 	'1' when r_ctl_act = '1' and r_ctl_halt = '1' else
						'0';	

	int_o <=			r_ctl2_if when r_ctl2_ie = '1' else
						'0';


	i_next_con_addr <=
				 		r_src_addr_bank & std_logic_vector(unsigned(r_src_addr) + 1) 
								when i_dma_state_next = sMemAccSRC and r_ctl_extend = '1' and r_ctl2_stepsize = wordswapsrc else 
						r_src_addr_bank & r_src_addr
								when i_dma_state_next = sMemAccSRC else 
						r_src_addr_bank & r_src_addr 
								when i_dma_state_next = sMemAccSRC2 and r_ctl_extend = '1' and r_ctl2_stepsize = wordswapsrc else 
						r_src_addr_bank & std_logic_vector(unsigned(r_src_addr) + 1)
								when i_dma_state_next = sMemAccSRC2 else 
						r_dest_addr_bank & std_logic_vector(unsigned(r_dest_addr) + 1)
								when i_dma_state_next = sMemAccDEST and r_ctl_extend = '1' and r_ctl2_stepsize = wordswapdest else 
						r_dest_addr_bank & r_dest_addr
								when i_dma_state_next = sMemAccDEST else 
						r_dest_addr_bank & r_dest_addr
								when i_dma_state_next = sMemAccDEST2 and r_ctl_extend = '1' and r_ctl2_stepsize = wordswapdest else 
						r_dest_addr_bank & std_logic_vector(unsigned(r_dest_addr) + 1)
								when i_dma_state_next = sMemAccDEST2 else 
						(others => '1');


	fb_con_c2p_o.cyc <= r_con_cyc;
  	fb_con_c2p_o.we <= '1' when r_dma_state = sMemAccDEST or r_dma_state = sMemAccDEST2 else
  							 '0';
  	fb_con_c2p_o.A <= r_con_addr;
  	fb_con_c2p_o.A_stb <= r_con_stb;
	fb_con_c2p_o.D_wr	 <=	r_data(7 downto 0) when r_dma_state = sMemAccDEST and (r_ctl_extend = '1' and r_ctl2_stepsize = wordswapdest) else
									r_data(7 downto 0) when r_dma_state = sMemAccDEST2 and (r_ctl_extend = '0' or r_ctl2_stepsize /= wordswapdest) else
									r_data(15 downto 8);
  	fb_con_c2p_o.D_wr_stb <= r_con_stb;
  	fb_con_c2p_o.rdy_ctdn <= RDY_CTDN_MIN;
	
end Behavioral;
-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2025 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:    	28/12/2025
-- Design Name: 
-- Module Name:    	fb_SDRAM
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for generic SDRAM using the Dossytronics
--							SDRAM controller
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

entity fb_SDRAM is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up

		CLOCKSPEED 	: natural;
		T_CAS_EXTRA : natural 	:= 0;	-- this needs to be 1 for > ~90 MHz

		
		-- SDRAM geometry
		LANEBITS		: natural 	:= 1;	-- number of byte lanes bits, if 0 don't connect sdram_DQM_o
		BANKBITS    : natural 	:= 2;	-- number of bits, if none set to 0 and don't connect sdram_BS_o
		ROWBITS     : positive 	:= 13;
		COLBITS		: positive 	:= 9;

		-- SDRAM speed 
		trp 			: time := 15 ns;  -- precharge
		trcd 			: time := 15 ns;	-- active to read/write
		trc 			: time := 60 ns;	-- active to active time
		trfsh			: time := 1.8 us;	-- the refresh control signal will be blocked if it occurs more frequently than this
		trfc  		: time := 63 ns 	-- refresh cycle time

	);
	port(

		-- sdram interface
		sdram_DQ_io			:	inout std_logic_vector((2**LANEBITS)*8-1 downto 0);
		sdram_A_o			:	out	std_logic_vector(maximum(COLBITS, ROWBITS)-1 downto 0); 
		sdram_BS_o			:  out 	std_logic_vector(maximum(BANKBITS-1, 0) downto 0); 
		sdram_CKE_o			:	out	std_logic;
		sdram_nCS_o			:	out	std_logic;
		sdram_nRAS_o		:	out	std_logic;
		sdram_nCAS_o		:	out	std_logic;
		sdram_nWE_o			:	out	std_logic;
		sdram_DQM_o			:	out	std_logic_vector(2 ** LANEBITS - 1 downto 0);

		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;

		debug_mem_a_stb_o					: out		std_logic

	);
end fb_SDRAM;

architecture rtl of fb_SDRAM is

	type 	 	state_mem_t is (idle, wait_wr_stb, wait_rd, wait_wr, act);

	signal	r_state	   : state_mem_t;

	signal	r_ack			:  std_logic;
	signal	i_wr_ack		:  std_logic; -- fast ack for writes on same cycle to make 8MHz on 65816

	signal   i_ctl_stall	: std_logic;
	signal   i_ctl_cyc	: std_logic;
	signal   i_ctl_we	   : std_logic;
	signal   i_ctl_A	   : std_logic_vector(LANEBITS+BANKBITS+ROWBITS+COLBITS-1 downto 0);
	signal   i_ctl_D_wr	: std_logic_vector(7 downto 0);
	signal   i_ctl_D_rd	: std_logic_vector(7 downto 0);
	signal   i_ctl_ack	: std_logic;

	function MIN(a: natural; b:natural) return natural is
	begin
		if a > b then
			return b;
		else
			return a;
		end if;
	end function;

begin

	debug_mem_a_stb_o <= fb_c2p_i.a_stb;


	fb_p2c_o.rdy <= r_ack;
	fb_p2c_o.ack <= r_ack;
	fb_p2c_o.stall <= '0' when r_state = idle else '1';

	p_state:process(fb_syscon_i)
	variable v_rdy_ctdn: t_rdy_ctdn;
	begin

		if fb_syscon_i.rst = '1' then
			r_state <= idle;
			r_ack <= '0';
		else
			if rising_edge(fb_syscon_i.clk) then

				r_ack <= '0';

				if i_ctl_stall = '0' then
					i_ctl_cyc <= '0';
				end if;

				case r_state is
					when idle =>
						if fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' then

							i_ctl_we <= fb_c2p_i.we;
							i_ctl_A <= (others => '0');
							i_ctl_A(MIN(24, LANEBITS+BANKBITS+ROWBITS+COLBITS) - 1 downto 0) 
								<= fb_c2p_i.A(MIN(24, LANEBITS+BANKBITS+ROWBITS+COLBITS) - 1 downto 0);

							if fb_c2p_i.we = '0' then
								i_ctl_cyc <= '1';
								r_state <= wait_rd;
							elsif fb_c2p_i.d_wr_stb = '1' then
								i_ctl_D_wr <= fb_c2p_i.D_wr;
								i_ctl_cyc <= '1';
								r_state <= wait_wr;
							else
								r_state <= wait_wr_stb;
							end if;
						end if;
					when wait_wr_stb =>
						if fb_c2p_i.d_wr_stb = '1' then
							i_ctl_D_wr <= fb_c2p_i.D_wr;
							i_ctl_cyc <= '1';
							r_state <= wait_wr;
						end if;
					when wait_wr =>
						if i_ctl_ack = '1' then
							r_ack <= '1';
							r_state <= idle;
						end if;
					when wait_rd =>
						if i_ctl_ack = '1' then
							fb_p2c_o.D_rd <= i_ctl_D_rd;
							r_ack <= '1';
							r_state <= idle;
						end if;
					when others =>
						r_ack <= '1';
						r_state <= idle;
				end case;

			end if;
		end if;
	end process;


	e_ctl:entity work.sdramctl
	generic map (
		CLOCKSPEED 	=> CLOCKSPEED * 1000000,
		T_CAS_EXTRA => 1,

		
		-- SDRAM geometry
		LANEBITS		=> LANEBITS,
		BANKBITS    => BANKBITS,
		ROWBITS     => ROWBITS,
		COLBITS		=> COLBITS,

		-- SDRAM speed 
		trp 			=> trp,
		trcd 			=> trcd,
		trc 			=> trc,
		trfsh			=> trfsh,
		trfc  		=> trfc		
		)
	port map (
		clk					=> fb_syscon_i.clk,

		-- sdram interface
		sdram_DQ_io			=> sdram_DQ_io,
		sdram_A_o			=> sdram_A_o,
		sdram_BS_o			=> sdram_BS_o,
		sdram_CKE_o			=> sdram_CKE_o,
		sdram_nCS_o			=> sdram_nCS_o,
		sdram_nRAS_o		=> sdram_nRAS_o,
		sdram_nCAS_o		=> sdram_nCAS_o,
		sdram_nWE_o			=> sdram_nWE_o,
		sdram_DQM_o			=> sdram_DQM_o,

		-- cpu interface

		-- Address laid out as bank, row, column, byte lanes from high to low

		ctl_rfsh_i			=> '1', -- TODO: this will fire between cycles "randomly" work out how to fit in (more?) nicely
		ctl_manrfsh_i		=> '0',
		ctl_reset_i			=> fb_syscon_i.rst, -- TODO: make this power on only?

		ctl_stall_o			=> i_ctl_stall,
		ctl_cyc_i			=> i_ctl_cyc,
		ctl_we_i				=> i_ctl_we,
		ctl_A_i				=> i_ctl_A,
		ctl_D_wr_i			=> i_ctl_D_wr,
		ctl_D_rd_o			=> i_ctl_D_rd,
		ctl_ack_o			=> i_ctl_ack
	);


end rtl;
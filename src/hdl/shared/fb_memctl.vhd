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
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	fishbone bus - Memory access and mapping control
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the memory control registers (except 
--							the ROM paging register which is handles in fb_SYS)
--							Also includes the state machine for sepcialised 6502/65816
--							debugging using a shadow ROM and shadow RAM exclusive to
--							debugger, for use with the NoICE / BLTUTILS roms
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

entity fb_memctl is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up
	);
	port(

		-- configuration signals
		do6502_debug_i						: in  std_logic;
		cfgbits_i							: in  std_logic_vector(15 downto 0);

		-- memory control signals

		turbo_lo_mask_o					: out	std_logic_vector(7 downto 0);

		swmos_shadow_o						: out	std_logic;		-- shadow mos from SWRAM slot #8

		boot_65816_o						: out std_logic;

		-- noice debugger signals to cpu
		noice_debug_nmi_n_o				: out	std_logic;		-- debugger is forcing a cpu NMI
		noice_debug_shadow_o				: out std_logic;		-- debugger memory MOS map is active (overrides shadow_mos)
		noice_debug_inhibit_cpu_o		: out	std_logic;		-- during a 5C op code, inhibit address / data to avoid
																			-- spurious memory accesses
		-- noice debugger signals from cpu
		noice_debug_5c_i					: in	std_logic;		-- A 5C instruction is being fetched (qualify with clken below)
		noice_debug_cpu_clken_i			: in	std_logic;		-- clken and cpu rdy
		noice_debug_A0_tgl_i				: in	std_logic;		-- 1 when current A0 is different to previous fetched
		noice_debug_opfetch_i			: in	std_logic;		-- this cycle is an opcode fetch

		-- noice debugger button		

		noice_debug_button_i				: in	std_logic;

		-- cput throttle
		throttle_cpu_2MHz_o				: out std_logic;

		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;

		-- debug

		DEBUG_REG_o							: out		std_logic_vector(7 downto 0)

	);
end fb_memctl;

architecture rtl of fb_memctl is

	type 	 	fb_state_mem_t is (idle, wait_write);
	signal	fb_state								: fb_state_mem_t;

	type		noice_state_t is (
			idle 				-- nothing happening
			, startBTN		-- button press detected and nmi asserted, wait for sync followed by same address
			, start5C		-- 5C instruction encountered, check that an IRQ is not being serviced then enter debug
			, startREGwr	-- a 1 bit was written to SWMOS_DEBUG - switch to DEBUG map after next instruction
			, wait65int 	-- sync just happened wait for next cycle and A0 is same for 6502 interrupt signature
			, restore		-- a store was made to FE32 put everything back		
		);

	signal	r_con_ack						:	std_logic;

	signal	r_turbo_lo						:	std_logic_vector(7 downto 0);

	signal	r_swmos_shadow					:	std_logic := '0';
	signal	r_noice_debug_shadow			:	std_logic;
	signal	r_noice_debug_shadow_saved	:	std_logic;
	signal	r_noice_debug_en				:	std_logic := '0';

	signal	r_noice_debug_act				: 	std_logic;
	signal	r_noice_debug_5C				:  std_logic;
	signal	r_noice_debug_nmi_n			:	std_logic;
	signal	r_noice_debug_inhibit_cpu	:  std_logic;

	signal	r_noice_state					:	noice_state_t;

	signal	r_noice_debug_written_val	: 	std_logic;
	signal	r_swmos_debug_written_en		: 	std_logic;
	signal	r_swmos_debug_written_ack		: 	std_logic;


	signal	r_swmos_save_written_en		: 	std_logic;
	signal	r_swmos_save_written_ack	: 	std_logic;

	signal   r_65816_boot					: 	std_logic;

	signal	r_throttle_cpu_2MHz				: 	std_logic;

begin

	throttle_cpu_2MHz_o <= r_throttle_cpu_2MHz;

	boot_65816_o <= r_65816_boot;

	turbo_lo_mask_o <= r_turbo_lo;

	swmos_shadow_o <= r_swmos_shadow;

	noice_debug_nmi_n_o <= 
		r_noice_debug_nmi_n when do6502_debug_i = '1' else
		'0' when noice_debug_button_i = '1' else
		'1';
	noice_debug_shadow_o <= r_noice_debug_shadow;
	noice_debug_inhibit_cpu_o <= r_noice_debug_inhibit_cpu;

	fb_p2c_o.rdy <= r_con_ack and fb_c2p_i.cyc;
	fb_p2c_o.ack <= r_con_ack and fb_c2p_i.cyc;
	fb_p2c_o.stall <= '0' when fb_state = idle else '1';

	fb_p2c_o.D_rd <= 		-- FE37 - lomem turbo map
								r_turbo_lo 
								when unsigned(fb_c2p_i.A(3 downto 0)) = 7 else
								-- FE36 - 2Mhz throttle
								r_throttle_cpu_2MHz & "0000000" 
								when unsigned(fb_c2p_i.A(3 downto 0)) = 6 else
								-- FE31 / swmos register
								r_noice_debug_act
							& 	r_noice_debug_5C
							& 	r_65816_boot
							&	'0'
							&  r_noice_debug_en
							&	r_noice_debug_shadow
							&	'0'
							&	r_swmos_shadow 
								when unsigned(fb_c2p_i.A(3 downto 0)) = 1 else		
								-- FE32 / swmos "save" register
								"000"													-- return to non-debug
							&	'0'
							&  r_noice_debug_en
							&	r_noice_debug_shadow_saved
							&	'0'
							&	r_swmos_shadow
								when unsigned(fb_c2p_i.A(3 downto 0)) = 2 else	
							not(cfgbits_i(7 downto 0))
								when unsigned(fb_c2p_i.A(3 downto 0)) = 14 else
							not(cfgbits_i(15 downto 8))
								when unsigned(fb_c2p_i.A(3 downto 0)) = 15 else
							x"A5";

	p_fb_state:process(fb_syscon_i)
	variable v_dowrite : boolean;
	begin

		if rising_edge(fb_syscon_i.clk) then
			r_con_ack <= '0';
			if fb_syscon_i.rst = '1' then
				fb_state <= idle;
				r_turbo_lo <= (others => '0');
				r_swmos_save_written_en <= '0';
				r_swmos_debug_written_en <= '0';
				r_65816_boot <= '1';	
				DEBUG_REG_o <= (others => '0');
				if fb_syscon_i.rst_state = resetfull or fb_syscon_i.rst_state = powerup then
					r_throttle_cpu_2MHz <= '0';
					r_noice_debug_en <= '0';
					r_swmos_shadow <= '0';
				end if;		
			else
					v_dowrite := false;

					r_con_ack <= '0';

					case fb_state is
					when idle =>
						if (fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1') then
							if fb_c2p_i.we = '1' then
								if fb_c2p_i.D_wr_stb = '1' then
									v_dowrite := true;
								else
									fb_state <= wait_write;
								end if;
							else
								fb_state <= idle;
								r_con_ack <= '1';
							end if;
						end if;
					when wait_write =>
						if fb_c2p_i.D_wr_stb = '1' then
							v_dowrite := true;
						end if;
					when others =>
						fb_state <= idle;
				end case;

				if fb_c2p_i.cyc = '0' then
					fb_state <= idle;
				elsif v_dowrite then
					fb_state <= idle;
					r_con_ack <= '1';
					case to_integer(unsigned(fb_c2p_i.A(2 downto 0))) is
						when 7 =>
							r_turbo_lo <= fb_c2p_i.D_wr;
						when 6 =>
							r_throttle_cpu_2MHz <= fb_c2p_i.D_wr(7);
						when 5 => 
							DEBUG_REG_o <= fb_c2p_i.D_wr;
						when 1 =>
							r_swmos_shadow <= fb_c2p_i.D_wr(0);
							r_noice_debug_en <= fb_c2p_i.D_wr(3);
							r_65816_boot <= fb_c2p_i.D_wr(5);
							r_noice_debug_written_val <= fb_c2p_i.D_wr(2);
							r_swmos_debug_written_en <= not r_swmos_debug_written_ack;
						when 2 => 
							r_swmos_save_written_en <= not r_swmos_save_written_ack;
						when others =>
					end case;
				end if;



			end if;
		end if;

	end process;


	p_noice_reg: process(fb_syscon_i, noice_debug_cpu_clken_i)
	variable v_noice_debug_button_prev : STD_LOGIC;
	begin
			
		if fb_syscon_i.rst = '1' then
			r_noice_debug_act <= '0';
			r_noice_debug_nmi_n <= '1';
			v_noice_debug_button_prev := '0';
			r_noice_debug_inhibit_cpu <= '0';
			r_noice_state <= idle;
			r_noice_debug_inhibit_cpu <= '0';
			r_noice_debug_shadow <= '0';	
			r_noice_debug_5C <= '0';	
			r_swmos_save_written_ack <= '0';
			r_swmos_debug_written_ack <= '0';
		elsif rising_edge(fb_syscon_i.clk) and noice_debug_cpu_clken_i = '1' then

			case r_noice_state is
				when idle => 
					if v_noice_debug_button_prev = '0' 
							and noice_debug_button_i = '1' 
							and r_noice_debug_act = '0' 
							and r_noice_debug_en = '1' 
							and do6502_debug_i = '1'
							then																		-- debug button pressed, startBTN debug nmi (65)
						r_noice_state <= startBTN;
					elsif  noice_debug_5c_i = '1'
							and noice_debug_opfetch_i = '1' 
							and r_noice_debug_act = '0' 
							and r_noice_debug_en = '1' 
							and do6502_debug_i = '1'
							then																		-- 5C instruction (65)
						r_noice_state <= start5C;
						r_noice_debug_inhibit_cpu <= '1';
					elsif r_swmos_save_written_en /= r_swmos_save_written_ack then
						if r_noice_debug_en = '1' then								-- restore state
							r_noice_state <= restore;
						end if;
						r_swmos_save_written_ack <= r_swmos_save_written_en;
					elsif  r_swmos_debug_written_en /= r_swmos_debug_written_ack then
						if r_noice_debug_en = '1'  then											-- write to SWMOS_DEBUG _after_ next instruction
							r_noice_state <= startREGwr;
						end if;
						r_swmos_debug_written_ack <= r_swmos_debug_written_en;
					end if;
				when start5C =>
			   		if noice_debug_A0_tgl_i = '1' then -- check for 5C but A0 didn't toggle, abandon irq being serviced
		   				r_noice_debug_nmi_n <= '0';
						r_noice_debug_act <= '1';
						r_noice_debug_5C <= '1';
						r_noice_debug_shadow_saved <= r_noice_debug_shadow;
						r_noice_debug_shadow <= '1';
					end if;
					r_noice_debug_inhibit_cpu <= '0';
		   			r_noice_state <= idle;
				when startBTN =>
					if noice_debug_opfetch_i = '1' then						
		   				r_noice_debug_nmi_n <= '0';
						r_noice_state <= wait65int;
					end if;
				when startREGwr =>
					if noice_debug_opfetch_i = '1' then
						r_noice_debug_act <= r_noice_debug_written_val;
						r_noice_debug_5C <= '0';
						r_noice_debug_shadow_saved <= r_noice_debug_shadow;
						r_noice_debug_shadow <= r_noice_debug_written_val;

						r_noice_debug_inhibit_cpu <= '0';
						r_noice_state <= idle;
					end if;
				when wait65int =>																-- wait for a 6502 interrupt signature 
																									-- which is a SYNC followed by a fetch
					if noice_debug_A0_tgl_i = '0' then									-- from the same address
																									-- (or more cheaply here, not A0 toggle)
						r_noice_debug_act <= '1';
						r_noice_debug_5C <= '0';
						r_noice_debug_shadow_saved <= r_noice_debug_shadow;
						r_noice_debug_shadow <= '1';
						r_noice_state <= idle;
					else
						-- not an interrupt fetch wait for a sync again
						r_noice_state <= startBTN;
					end if;

				when restore=>
					r_noice_debug_inhibit_cpu <= '0';
					r_noice_debug_nmi_n <= '1';
					r_noice_debug_act <= '0';
					r_noice_debug_5C <= '0';
					r_noice_debug_shadow <= r_noice_debug_shadow_saved;

					r_noice_state <= idle;
				when others =>
					-- this shouldn't happen!
					r_noice_debug_inhibit_cpu <= '0';
					r_noice_debug_nmi_n <= '1';
					r_noice_debug_act <= '0';
					r_noice_debug_5C <= '0';

					r_noice_state <= idle;
			end case;			

			v_noice_debug_button_prev := noice_debug_button_i;

		end if;
	end process;



end rtl;
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
-- ----------------------------------------------------------------------

-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	24/10/2022
-- Design Name: 
-- Module Name:    	fishbone bus - CPU address translation and wait
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A pass-through fishbone component that translates logical to 
--							physical addresses and additionally throttles consecutive 
--							accesses to the system VIA
-- Dependencies: 
--
-- Revision: 
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.fishbone.all;
use work.common.all;
use work.fb_sys_pack.all;

entity fb_cpu_log2phys is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;										-- fast clock speed in mhz						
		G_MK3									: boolean := false;							-- TODO: get from board_config?
		G_C20K								: boolean := false;
		G_IORB_BLOCK						: boolean := true
	);
	port(

		fb_syscon_i								: in	fb_syscon_t;

		-- controller interface from the cpu
		fb_con_c2p_i							: in fb_con_o_per_i_t;
		fb_con_p2c_o							: out	fb_con_i_per_o_t;
		fb_con_extra_instr_fetch_i				: in std_logic;

		fb_per_c2p_o							: out fb_con_o_per_i_t;
		fb_per_p2c_i							: in	fb_con_i_per_o_t;

		-- per cpu config
		cfg_sys_via_block_i					: in std_logic;
		cfg_t65_i								: in std_logic;

		-- system type
		cfg_sys_type_i							: in sys_type;
		cfg_swram_enable_i					: in std_logic;
		cfg_mosram_i							: in std_logic;
		cfg_swromx_i							: in std_logic;

		-- extra memory map control signals
		sys_ROMPG_i								: in std_logic_vector(7 downto 0);
		JIM_page_i								: in std_logic_vector(15 downto 0);
		jim_en_i									: in std_logic;		-- jim enable, this is handled here 

		-- SYS VIA slowdown enable
		sys_via_blocker_en_i					: in std_logic;

		-- memctl signals
		swmos_shadow_i							: in std_logic;		-- shadow mos from SWRAM slot #8
		turbo_lo_mask_i						: in std_logic_vector(7 downto 0);
		rom_throttle_map_i					: in std_logic_vector(15 downto 0);
		rom_autohazel_map_i					: in std_logic_vector(15 downto 0);
		rom_throttle_act_o					: out std_logic;

		-- noice signals
		noice_debug_shadow_i					: in std_logic;


		-- debug signals
		debug_SYS_VIA_block_o				: out std_logic

	);
end fb_cpu_log2phys;


architecture rtl of fb_cpu_log2phys is 

	type state_t is (idle, waitstall, viablock, wait_d_stb);

	signal r_state 		: state_t;

	signal r_cyc						: std_logic;
	signal r_A_stb						: std_logic;
	signal i_phys_A					: std_logic_vector(23 downto 0);
	signal r_phys_A					: std_logic_vector(23 downto 0);
	signal r_we							: std_logic;
	signal r_D_wr_stb					: std_logic;
	signal r_D_wr						: std_logic_vector(7 downto 0);
	signal r_rdy_ctdn					: t_rdy_ctdn;

	signal i_SYS_VIA_block			: std_logic;
	signal r_done_r_d_wr_stb		: std_logic;

	signal i_sysvia_clken			: std_logic;

	signal i_rom_throttle_act		: std_logic; -- set to '1' when current cycle should be throttled
	signal r_rom_throttle_act		: std_logic; -- set to '1' when current cycle should be throttled

begin


	fb_con_p2c_o.stall <= '0' when r_state = idle else '1';
	fb_con_p2c_o.ack <= fb_per_p2c_i.ack;
	fb_con_p2c_o.rdy <= fb_per_p2c_i.rdy;
	fb_con_p2c_o.D_rd <= fb_per_p2c_i.D_rd;

	fb_per_c2p_o.cyc			<=	r_cyc;
	fb_per_c2p_o.we			<=	r_we;
	fb_per_c2p_o.A				<=	r_phys_A;
	fb_per_c2p_o.A_stb		<= r_A_stb;
	fb_per_c2p_o.D_wr			<= r_D_wr;
	fb_per_c2p_o.D_wr_stb	<= r_D_wr_stb;
	fb_per_c2p_o.rdy_ctdn	<= r_rdy_ctdn;

	rom_throttle_act_o <= r_rom_throttle_act;

	-- ================================================================================================ --
	-- State Machine 
	-- ================================================================================================ --


	p_state:process(fb_syscon_i)
	variable v_accept_wr_stb:boolean;
	begin
		if fb_syscon_i.rst = '1' then
			r_state <= idle;
			r_phys_A <= (others => '0');
			r_cyc <= '0';
			r_we <= '0';
			r_D_wr_stb <= '0';
			r_D_wr <= (others => '0');
			r_rdy_ctdn <= RDY_CTDN_MAX;
			r_a_stb <= '0';
			r_done_r_d_wr_stb <= '0';
		elsif rising_edge(fb_syscon_i.clk) then

			r_a_stb <= '0';

			v_accept_wr_stb := false;

			case r_state is
				when idle =>
					r_done_r_d_wr_stb <= '0';
					r_D_wr_stb <= '0';
					if fb_con_c2p_i.cyc = '1' and fb_con_c2p_i.a_stb = '1' then
						v_accept_wr_stb := true;
						r_phys_A <= i_phys_A;
						r_rom_throttle_act <= i_rom_throttle_act;
						r_we <= fb_con_c2p_i.we;
						r_rdy_ctdn <= fb_con_c2p_i.rdy_ctdn;

						if cfg_sys_via_block_i = '1' and i_SYS_VIA_block = '1' then
							r_state <= viablock;
						else
							r_state <= waitstall;
							r_a_stb <= '1';
						end if;

						r_cyc <= '1';
					end if;
				when viablock =>
					v_accept_wr_stb := true;
					if i_SYS_VIA_block = '0' then
						r_state <= waitstall;
						r_a_stb <= '1';
						r_cyc <= '1';
					end if;
				when waitstall =>
					v_accept_wr_stb := true;
					if fb_per_p2c_i.stall = '1' then
						r_a_stb <= '1';
						r_State <= waitstall;
					else
						if fb_con_c2p_i.D_wr_stb = '1' or r_we = '0' or r_done_r_d_wr_stb = '1' then
							r_state <= idle;
							r_done_r_d_wr_stb <= '0';
							r_D_wr_stb <= '0';
						else
							r_state <= wait_d_stb;
						end if;
						r_D_wr_stb <= '0';
					end if;
				when wait_d_stb =>
					v_accept_wr_stb := true;
					r_D_wr_stb <= '0';
					-- this gets cancelled in if below
					if fb_con_c2p_i.D_wr_stb = '1' or r_we = '0' or r_done_r_d_wr_stb = '1' then
						r_state <= idle;
						r_done_r_d_wr_stb <= '0';
						r_D_wr_stb <= '0';
					end if;
				when others =>
					r_state <= idle;
			end case;

			if v_accept_wr_stb then
				if r_done_r_d_wr_stb = '0' or r_state = idle then
					if (r_D_wr_stb = '0' or r_state = idle) and fb_con_c2p_i.D_wr_stb = '1' then
						r_D_wr_stb <= '1';
						r_D_wr <= fb_con_c2p_i.D_WR;
						r_done_r_d_wr_stb <= '1';
					end if;
				end if;
			end if;

			if fb_con_c2p_i.cyc = '0' then
				r_A_stb <= '0';
				r_cyc <= '0';
				r_state <= idle;
				r_D_wr_stb <= '0';
				r_done_r_d_wr_stb <= '0';
			end if;

		end if;
	end process;




	-- ================================================================================================ --
	-- SYS VIA blocker
	-- ================================================================================================ --
	g_do_IORB_BLOCK:if G_IORB_BLOCK generate
		e_sys_via_block:entity work.fb_sys_via_blocker
		generic map (
			SIM => SIM,
			CLOCKSPEED => CLOCKSPEED		
			)
		port map (
			fb_syscon_i => fb_syscon_i,
			cfg_sys_type_i => cfg_sys_type_i,
			clken => i_sysvia_clken,
			enable_i => sys_via_blocker_en_i,
			A_i => i_phys_A,
			RnW_i => not fb_con_c2p_i.we,
			SYS_VIA_block_o => i_SYS_VIA_block
			);
	end generate;

	g_dont_IORB_BLOCK:if not G_IORB_BLOCK generate
		i_SYS_VIA_block <= '0';
	end generate;

	i_sysvia_clken <= '1' when r_state = idle and fb_con_c2p_i.a_stb = '1' else
							'0';


	-- ================================================================================================ --
	-- Logical to physical address mapping 
	-- ================================================================================================ --


	e_log2phys: entity work.log2phys
	generic map (
		SIM									=> SIM,
		G_MK3									=> G_MK3,
		G_C20K								=> G_C20K
	)
	port map (
		fb_syscon_i 						=> fb_syscon_i,	
		-- CPU address control signals from other components
		JIM_page_i							=> JIM_page_i,
		sys_ROMPG_i							=> sys_ROMPG_i,
		cfg_swram_enable_i				=> cfg_swram_enable_i,
		cfg_swromx_i						=> cfg_swromx_i,
		cfg_mosram_i						=> cfg_mosram_i,
		cfg_t65_i							=> cfg_t65_i,
      cfg_sys_type_i                => cfg_sys_type_i,

		jim_en_i								=> jim_en_i,
		swmos_shadow_i						=> swmos_shadow_i,
		turbo_lo_mask_i					=> turbo_lo_mask_i,
		noice_debug_shadow_i				=> noice_debug_shadow_i,

		rom_throttle_map_i				=> rom_throttle_map_i,
		rom_autohazel_map_i				=> rom_autohazel_map_i,
		rom_throttle_act_o				=> i_rom_throttle_act,

		A_i									=> fb_con_c2p_i.A,
		instruction_fetch_i				=> fb_con_extra_instr_fetch_i,

		A_o									=> i_phys_A
	);

	debug_SYS_VIA_block_o <= i_SYS_VIA_block;

end rtl;
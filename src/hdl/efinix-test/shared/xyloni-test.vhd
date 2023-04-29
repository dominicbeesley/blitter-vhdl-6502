-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2023 Dominic Beesley https://github.com/dominicbeesley
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
-- Create Date:    	25/4/2023
-- Design Name: 
-- Module Name:    	xyloni_test
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Test build of a minimal T65 computer on an Efinix Xyloni
--							Dev board to explore number of LE's used and timing.
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
use work.common.all;
use work.fishbone.all;
use work.fb_CPU_pack.all;
use work.fb_intcon_pack.all;
use work.board_config_pack.all;

entity xyloni_test is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural := 128;								-- fast clock speed in mhz				
		BAUD									: natural := 9600
	);
	port(
		-- crystal osc 48Mhz - on WS board
		clk_128_pll_i						: in		std_logic;

		ser_tx_o								: out		std_logic;
		ser_rx_i								: in		std_logic;

		led									: out		std_logic_vector(3 downto 0);

		debug_ser_tx_o						: out		std_logic

	);
end xyloni_test;

architecture rtl of xyloni_test is




	-----------------------------------------------------------------------------
	-- fishbone signals
	-----------------------------------------------------------------------------

	signal i_fb_syscon			: fb_syscon_t;							-- shared bus signals

	-- cpu wrapper
	signal i_c2p_cpu				: fb_con_o_per_i_t;
	signal i_p2c_cpu				: fb_con_i_per_o_t;

	-- block RAM/ROM wrapper
	signal i_c2p_mem				: fb_con_o_per_i_t;
	signal i_p2c_mem				: fb_con_i_per_o_t;

	-- uart wrapper
	signal i_c2p_uart				: fb_con_o_per_i_t;
	signal i_p2c_uart				: fb_con_i_per_o_t;

	-- intcon controller->peripheral
	signal i_con_c2p_intcon		: fb_con_o_per_i_arr(CONTROLLER_COUNT-1 downto 0);
	signal i_con_p2c_intcon		: fb_con_i_per_o_arr(CONTROLLER_COUNT-1 downto 0);
	-- intcon peripheral->controller
	signal i_per_c2p_intcon		: fb_con_o_per_i_arr(PERIPHERAL_COUNT-1 downto 0);
	signal i_per_p2c_intcon		: fb_con_i_per_o_arr(PERIPHERAL_COUNT-1 downto 0);

	-----------------------------------------------------------------------------
	-- intcon to peripheral sel
	-----------------------------------------------------------------------------
	signal i_intcon_peripheral_sel_addr		: fb_arr_std_logic_vector(CONTROLLER_COUNT-1 downto 0)(23 downto 0);
	signal i_intcon_peripheral_sel			: fb_arr_unsigned(CONTROLLER_COUNT-1 downto 0)(numbits(PERIPHERAL_COUNT)-1 downto 0);  -- address decoded selected peripheral
	signal i_intcon_peripheral_sel_oh		: fb_arr_std_logic_vector(CONTROLLER_COUNT-1 downto 0)(PERIPHERAL_COUNT-1 downto 0);	-- address decoded selected peripherals as one-hot		

	-----------------------------------------------------------------------------
	-- peripherals
	-----------------------------------------------------------------------------
	
	constant C_BAUD_CKK16_DIV2 : positive := (CLOCKSPEED*1000000)/(32*BAUD);

	signal r_clk_baud16	: std_logic;
	signal r_clk_baud_div: unsigned(numbits(C_BAUD_CKK16_DIV2-1) downto 0); -- note 1 bigger to catch carry out

	signal i_ser_tx		: std_logic;

begin


	e_fb_syscon: entity work.fb_syscon
	generic map (
		SIM => SIM,
		CLOCKSPEED => CLOCKSPEED
	)
	port map (
		fb_syscon_o							=> i_fb_syscon,

		EXT_nRESET_i						=> '1',

		clk_fish_i							=> CLK_128_pll_i,
		clk_lock_i							=> '1',
		sys_dll_lock_i						=> '1'

	);	

	-- address decode to select peripheral
	e_addr2s:entity work.address_decode_xyloni
	generic map (
		SIM							=> SIM,
		G_PERIPHERAL_COUNT		=> PERIPHERAL_COUNT
	)
	port map (
		addr_i						=> i_intcon_peripheral_sel_addr(0),
		peripheral_sel_o			=> i_intcon_peripheral_sel(0),
		peripheral_sel_oh_o		=> i_intcon_peripheral_sel_oh(0)
	);

	e_fb_intcon: fb_intcon_one_to_many
	generic map (
		SIM 									=> SIM,
		G_PERIPHERAL_COUNT 						=> PERIPHERAL_COUNT,
		G_ADDRESS_WIDTH 					=> 24
		)
	port map (
		fb_syscon_i 						=> i_fb_syscon,

		-- peripheral ports connect to controllers
		fb_con_c2p_i						=> i_con_c2p_intcon(0),
		fb_con_p2c_o						=> i_con_p2c_intcon(0),

		-- controller ports connect to peripherals
		fb_per_c2p_o						=> i_per_c2p_intcon,
		fb_per_p2c_i						=> i_per_p2c_intcon,

		peripheral_sel_addr_o			=> i_intcon_peripheral_sel_addr(0),
		peripheral_sel_i					=> i_intcon_peripheral_sel(0),
		peripheral_sel_oh_i				=> i_intcon_peripheral_sel_oh(0)
	);

	i_con_c2p_intcon(MAS_NO_CPU)			<= i_c2p_cpu;
	i_per_p2c_intcon(PERIPHERAL_NO_MEM)	<=	i_p2c_mem;
	i_per_p2c_intcon(PERIPHERAL_NO_UART)	<=	i_p2c_uart;

	i_p2c_cpu				<= i_con_p2c_intcon(MAS_NO_CPU);
	i_c2p_mem				<= i_per_c2p_intcon(PERIPHERAL_NO_MEM);
	i_c2p_uart				<= i_per_c2p_intcon(PERIPHERAL_NO_UART);

	e_fb_mem: entity work.fb_eff_mem
	generic map (
		G_ADDR_W => 12,
--		INIT_FILE => "./../../../../../../../sim_asm/efinix-test/build/efinix-boot-rom.vec"
		INIT_FILE => "./../../../../sim_asm/efinix-test/build/efinix-boot-rom.vec"
		)
	port map (
		-- fishbone signals

		fb_syscon_i							=> i_fb_syscon,
		fb_c2p_i								=> i_c2p_mem,
		fb_p2c_o								=> i_p2c_mem

	);

	p_uart_clk:process(i_fb_syscon)
	begin
		if i_fb_syscon.rst = '1' then
			r_clk_baud_div <= to_unsigned(C_BAUD_CKK16_DIV2-1, r_clk_baud_div'length);
			r_clk_baud16 <= '1';
		elsif rising_edge(i_fb_syscon.clk) then
			if r_clk_baud_div(r_clk_baud_div'high) = '1' then
				r_clk_baud_div <= to_unsigned(C_BAUD_CKK16_DIV2-1, r_clk_baud_div'length);
				r_clk_baud16 <= not(r_clk_baud16);
			else
				r_clk_baud_div <= r_clk_baud_div - 1;
			end if;
		end if;
	end process;

	e_fb_uart: entity work.fb_uart
	port map (
		clk_baud16_i	=>	r_clk_baud16,
		ser_rx_i			=> ser_rx_i,
		ser_tx_o			=> i_ser_tx,

		-- fishbone signals

		fb_syscon_i		=> i_fb_syscon,
		fb_c2p_i		=> i_c2p_uart,
		fb_p2c_o		=> i_p2c_uart

	);

	ser_tx_o <= i_ser_tx;
	debug_ser_tx_o <= i_ser_tx;

	e_fb_cpu_t65only: entity work.fb_cpu_t65only
	generic map (
		SIM => SIM,
		CLOCKSPEED => CLOCKSPEED
	)
	port map (

		-- direct CPU control signals from system
		nmi_n_i								=> '1',
		irq_n_i								=> '1',
		cpu_halt_i							=> '0',

		-- fishbone signals
		fb_syscon_i							=> i_fb_syscon,
		fb_c2p_o								=> i_c2p_cpu,
		fb_p2c_i								=> i_p2c_cpu

	);

	led(0) <= i_ser_tx;
	led(1) <= '1';
	led(2) <= not i_ser_tx;
	led(3) <= '0';

end rtl;

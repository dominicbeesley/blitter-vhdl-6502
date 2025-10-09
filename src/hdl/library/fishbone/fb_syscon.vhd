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
-- Module Name:    	fishbone bus - syscon 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone syscon provider
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

library work;
use work.common.all;

entity fb_syscon is
	generic (
		SIM										: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED								: natural := 128								-- fast clock speed in mhz		
	);
	port(


		EXT_nRESET_i							: in		std_logic;					-- break key
		EXT_nRESET_power_i						: in		std_logic := '1';			-- power reset key

		clk_fish_i								: in 		std_logic;					-- main fast fishbone clock in 
		clk_lock_i								: in 		std_logic;					-- pll lock indication
		sys_dll_lock_i							: in		std_logic;

		fb_syscon_o								: out 	fb_syscon_t						-- fishbone syscon record


	);
end fb_syscon;


architecture rtl of fb_syscon is

	function SKIP_RESET(VAL:natural; QUICKVAL:natural) return natural is
	begin
		if SIM then
			return QUICKVAL;
		else
			return VAL;
		end if;
	end SKIP_RESET;


	signal	i_fb_syscon						: fb_syscon_t;

	signal	r_rst_state						: fb_rst_state_t := powerup;

	constant RST_COUNT_FULL					: natural := 2**(ceil_log2(CLOCKSPEED * 3 * 1000000)-1)-1; -- full reset 3 seconds (ish)
	constant RST_PUP_MAX						: natural := SKIP_RESET(CLOCKSPEED * 10, CLOCKSPEED);				-- quickly force a full  reset at powerup
	constant RST_RUN							: natural := SKIP_RESET(CLOCKSPEED * 50, CLOCKSPEED);				-- for reset noise/debounce 50 us
	constant RST_CTR_LEN						: natural := ceil_log2(RST_COUNT_FULL);


	signal	r_rst_counter					: unsigned(RST_CTR_LEN-1 downto 0) := (others => '0');


	signal	i_r_in							: std_logic_vector(1 downto 0);
	signal	i_r_out							: std_logic_vector(1 downto 0);

	signal	rr_EXT_nRESET					: std_logic; -- metastabilised
	signal	rr_EXT_nRESET_power				: std_logic; -- metastabilised

	signal  i_any_reset_n					: std_logic;

	signal	r_prerun_shift					: std_logic_vector(3 downto 0);
	signal  r_need_full						: std_logic;

begin

	fb_syscon_o <= i_fb_syscon;

	i_fb_syscon.clk <= clk_fish_i;
	i_fb_syscon.rst_state <= r_rst_state;
	i_fb_syscon.prerun <= r_prerun_shift;


	e_regsigs:entity work.clockreg
	generic map (
		G_DEPTH => 2,
		G_WIDTH => 2
	)
	port map (
		clk_i	=> i_fb_syscon.clk,
		d_i	=> i_r_in,
		q_o	=> i_r_out
	);

	i_r_in(0) <= EXT_nRESET_i;
	i_r_in(1) <= EXT_nRESET_power_i;
	rr_EXT_nRESET <= i_r_out(0);
	rr_EXT_nRESET_power <= i_r_out(1);

	i_any_reset_n <= rr_EXT_nRESET and rr_EXT_nRESET_power;


	p_reset_state:process(i_fb_syscon.clk)
	begin
		if rising_edge(i_fb_syscon.clk) then

			case r_rst_state is
				when powerup =>
					if r_rst_counter = RST_PUP_MAX then
						r_rst_state <= reset;
						r_rst_counter <= (others => '0');
					else
						r_rst_counter <= r_rst_counter + 1;
					end if;
					r_prerun_shift <= ( others => '0');
					i_fb_syscon.rst <= '1';
					r_need_full <= '1';
				when reset =>
					if i_any_reset_n = '0' then
						-- detect reset button held down and start a "full" reset
						r_rst_counter <= r_rst_counter + 1;
						if r_rst_counter = to_unsigned(RST_COUNT_FULL, RST_CTR_LEN) then
							r_rst_state <= resetfull;
							r_rst_counter <= (others => '0');
						end if;
					else
						r_rst_counter <= (others => '0');
						if r_need_full = '1' then
							r_rst_state <= resetfull;
						else
							r_rst_state <= prerun;
						end if;
						r_prerun_shift <= ( 0 => '1', others => '0');
					end if;
					i_fb_syscon.rst <= '1';
					r_need_full <= r_need_full or not rr_EXT_nRESET_power;
				when resetfull =>
					if i_any_reset_n = '1' then
						r_rst_counter <= (others => '0');
						r_rst_state <= prerun;
						r_prerun_shift <= ( 0 => '1', others => '0');
					end if;
					i_fb_syscon.rst <= '1';
				when prerun =>
					r_rst_counter <= r_rst_counter + 1;
					r_need_full <= '0';
					if i_any_reset_n = '0' then
						r_rst_counter <= (others => '0');
						r_rst_state <= reset;
					elsif r_rst_counter = to_unsigned(RST_RUN, RST_CTR_LEN) then
						r_rst_counter <= (others => '0');
						if r_prerun_shift(r_prerun_shift'HIGH) = '1' then							
							r_rst_state <= run;
							r_prerun_shift <= (others => '0');
						else
							r_prerun_shift <= r_prerun_shift(r_prerun_shift'HIGH-1 downto 0) & '0';
						end if;
					end if;
					i_fb_syscon.rst <= '1';
				when run =>
					if clk_lock_i = '0' or sys_dll_lock_i = '0' then
						r_rst_state <= lockloss;
					elsif i_any_reset_n = '0' then
						r_rst_counter <= (others => '0');
						r_rst_state <= reset;
					end if;
					i_fb_syscon.rst <= '0';
				when lockloss =>
					if i_any_reset_n = '0' then
						r_rst_counter <= (others => '0');
						r_rst_state <= reset;
					end if;
					i_fb_syscon.rst <= '1';					
				when others => 
					r_rst_state <= lockloss;
					i_fb_syscon.rst <= '1';					
			end case;
		end if;
	end process;

end rtl;





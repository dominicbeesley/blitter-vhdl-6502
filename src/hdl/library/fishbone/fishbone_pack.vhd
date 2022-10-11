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
-- Module Name:    	fishbone bus
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A bus (loosely based on Wishbone) to allow communication 
--							between various devices of differing speeds
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package fishbone is

	-- RDY_CTDN
	-- --------

	-- As of Oct 2022 the semantics of rdy_ctdn has changed, rather than the peripheral providing a count
	-- down it returns a single rdy signal. The controller specifies (at the start of each cycle) the
	-- number of cycles _before_ ack that rdy should go high.
	-- 
	-- It is up to the peripheral to return rdy. It MUST at least:
	--  * set rdy no later than ack
	--  * set rdy no earlier than rdy_ctdn cycles before ack

	constant RDY_CTDN_LEN 	:	natural		:= 7;
	subtype t_rdy_ctdn is unsigned(RDY_CTDN_LEN-1 downto 0);
	constant RDY_CTDN_MAX	:	t_rdy_ctdn 	:= to_unsigned(127, RDY_CTDN_LEN);		-- allow up to 127 wait states for 1MHz cycles
	constant RDY_CTDN_MIN	:  t_rdy_ctdn 	:= to_unsigned(0, RDY_CTDN_LEN);

	type fb_std_logic_2d is array(natural range <>, natural range <>) of std_logic;

	function fb_2d_get_slice(
		x : fb_std_logic_2d;
		i : natural
	) return std_logic_vector;

	procedure fb_2d_set_slice(
		signal x: inout fb_std_logic_2d; 
		constant i: in natural;
		signal v: in std_logic_vector
	);

	procedure fb_2d_copy_slice(
		signal dest: inout fb_std_logic_2d;
		constant destslice: in natural;
		signal src: in fb_std_logic_2d;
		constant srcslice: in natural
	);

	type fb_rst_state_t is (
		-- the board is being powered up
		powerup, 
		-- a normal break/reset
		reset, 
		-- the user has held the reset in for 3s
		resetfull, 
		-- deadzone before starting processors on blitter board to avoid glitchy/bouncy resets to aid debuggin
		-- not used on all devices
		prerun, 
		-- normal - no reset in progress
		run, 
		-- the clock generators / plls lost lock 
		lockloss
		);


	type fb_syscon_t is record
		clk					: std_logic;							-- "fast" clock
		rst					: std_logic;							-- bus reset
		rst_state			: fb_rst_state_t;						-- power up etc
		prerun				: std_logic_vector(3 downto 0);	-- one hot that goes from 0001 to 1000 during the prerun state
	end record fb_syscon_t;


	-- signals from controllers to peripherals
	type fb_con_o_per_i_t is record				
		cyc					:  std_logic;							-- stays active throughout cycle
		we						: 	std_logic;							-- write =1, read = 0, qualified by A_stb
		A						: 	std_logic_vector(23 downto 0);-- physical address
		A_stb					: 	std_logic;							-- address out strobe, qualifies A
		D_wr					: 	std_logic_vector(7 downto 0);	-- data out from controller to peripheral
		D_wr_stb				:	std_logic;							-- data out strobe, qualifies D_wr, can ack writes as soon
																			-- as this is ready or wait until end of cycle
		rdy_ctdn				:	t_rdy_ctdn;							-- see above
	end record fb_con_o_per_i_t;

	--signals from peripherals to controllers
	type fb_con_i_per_o_t is record

		D_rd					: 	std_logic_vector(7 downto 0);	-- data in during a read
		stall					:  std_logic;							-- when asserted re-try a_stb
		ack					:	std_logic;							-- cycle complete, controller can/should terminate cycle now, data was supplied or latched
		rdy					:  std_logic;							-- cycle will be complete in (at most) rdy_ctdn (input) bus cycles

	end record fb_con_i_per_o_t;

	type fb_con_o_per_i_arr is array(natural range <>) of fb_con_o_per_i_t;
	type fb_con_i_per_o_arr is array(natural range <>) of fb_con_i_per_o_t;

	-- this constant contains the nul controller to peripheral signal
	constant fb_c2p_unsel : fb_con_o_per_i_t := (
		cyc => '0',
		we => '0',
		A => (others => '1'),
		A_stb => '0',
		D_wr => (others => '1'),
		D_wr_stb => '0',
		rdy_ctdn => RDY_CTDN_MIN
		);

	-- this constant contains the nul peripheral to controller signal
	constant fb_p2c_unsel : fb_con_i_per_o_t := (
		D_rd => (others => '1'),
		ack => '0',
		rdy => '0',
		stall => '1'
		);


	type fb_arr_std_logic_vector is array (integer range <>) of std_logic_vector;
	type fb_arr_unsigned is array (integer range <>) of unsigned;

end package;

package body fishbone is


	function fb_2d_get_slice(x:fb_std_logic_2d; i:natural) return std_logic_vector is
	variable ret:std_logic_vector(x'range(2));
	begin
		for j in x'range(2) loop
			ret(j) := x(i,j);
		end loop;
		return ret;
	end fb_2d_get_slice;

	procedure fb_2d_set_slice(
		signal x : inout fb_std_logic_2d; 
		constant i : in natural;
		signal v : in std_logic_vector
		) is
	begin
		for j in v'range loop
			x(i,j) <= v(j);
		end loop;
	end fb_2d_set_slice;

	procedure fb_2d_copy_slice(
		signal dest: inout fb_std_logic_2d;
		constant destslice: in natural;
		signal src: in fb_std_logic_2d;
		constant srcslice: in natural
	) is
	begin
		for j in dest'range(2) loop
			dest(destslice,j) <= src(srcslice,j);
		end loop;
	end fb_2d_copy_slice;

end fishbone;
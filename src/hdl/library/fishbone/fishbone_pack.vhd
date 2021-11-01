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
	-- the RDY countdown allows a slave to indicate how long it will be until data will be ready 
	-- this should count down to 0 and go to 0 once D_rd is valid for reads or 0 once a write is 
	-- under way
	-- when the number of cycles is not known then the rdy_ctdn should be set to RDY_CTDN_MAX
	-- it is allowable to jump suddenly downwards _but not upwards_
	-- care should be taken when propagating D_rd and rdy_ctdn through any interconnects that 
	-- they are subject to similar delays (where they are registered)

	constant RDY_CTDN_LEN 	:	natural		:= 7;
	constant RDY_CTDN_MAX	:	unsigned 	:= to_unsigned(127, RDY_CTDN_LEN);		-- allow up to 127 wait states for 1MHz cycles
	constant RDY_CTDN_MIN	:  unsigned 	:= to_unsigned(0, RDY_CTDN_LEN);

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

	end record fb_syscon_t;


	-- signals from masters to slaves
	type fb_mas_o_sla_i_t is record				
		cyc					:  std_logic;							-- stays active throughout cycle
		we						: 	std_logic;							-- write =1, read = 0, qualified by A_o_stb_o
		A						: 	std_logic_vector(23 downto 0);-- physical address
		A_stb					: 	std_logic;							-- address out strobe, qualifies A_o, hold until end of cyc_o
		D_wr					: 	std_logic_vector(7 downto 0);	-- data out from master to slave
		D_wr_stb				:	std_logic;							-- data out strobe, qualifies D_o, can ack writes as soon
																			-- as this is ready or wait until end of cycle
	end record fb_mas_o_sla_i_t;

	--signals from slaves to masters
	type fb_mas_i_sla_o_t is record

		D_rd					: 	std_logic_vector(7 downto 0);	-- data in during a read
		rdy_ctdn				:	unsigned(RDY_CTDN_LEN-1 downto 0);							-- see above
		ack					:	std_logic;							-- cycle complete, master must terminate cycle now, data was supplied or latched
		nul					:	std_logic;							-- when set there is no respone i.e. either there is an error or no address matches
																			-- the cycle should be abored immediately (ack will also be set)

	end record fb_mas_i_sla_o_t;

	type fb_mas_o_sla_i_arr is array(natural range <>) of fb_mas_o_sla_i_t;
	type fb_mas_i_sla_o_arr is array(natural range <>) of fb_mas_i_sla_o_t;

	-- this constant contains the nul master to slave signal
	constant fb_m2s_unsel : fb_mas_o_sla_i_t := (
		cyc => '0',
		we => '0',
		A => (others => '1'),
		A_stb => '0',
		D_wr => (others => '1'),
		D_wr_stb => '0'
		);

	-- this constant contains the nul slave to master signal
	constant fb_s2m_unsel : fb_mas_i_sla_o_t := (
		D_rd => (others => '1'),
		rdy_ctdn => RDY_CTDN_MAX,
		ack => '0',
		nul => '0'
		);


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
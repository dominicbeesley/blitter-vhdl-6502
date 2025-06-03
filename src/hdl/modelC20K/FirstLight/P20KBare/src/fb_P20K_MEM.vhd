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
-- Module Name:    	fb_eff_mem
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for P20K block RAM
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;


library work;
use work.fishbone.all;

entity fb_eff_mem is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		G_ADDR_W								: positive;	-- number of address lines in memory
		INIT_FILE							: string := ""
	);
	port(


		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t

	);
end fb_eff_mem;

architecture rtl of fb_eff_mem is

	type		arr_mem_t is array(2**G_ADDR_W-1 downto 0) of std_logic_vector(7 downto 0);

	impure function MEM_INIT_FILE(file_name:STRING) return arr_mem_t is
	FILE infile : text is in file_name;
	variable arr : arr_mem_t := (others => (others => '0'));
	variable inl : line;
	variable count : integer;
	begin
		count := 0;
		while not(endfile(infile)) and count < 2**G_ADDR_W loop
			readline(infile, inl);
			read(inl, arr(count));
			count := count + 1;
		end loop;

		return arr;
	end function;

	impure function MEM_INIT(file_name:STRING) return arr_mem_t is
	begin
		if file_name = "" then
			return (others => (others => '0'));
		else
			return MEM_INIT_FILE(file_name);
		end if;
	end function;



	type 	 	state_mem_t is (idle, wait_wr_stb, wr, rd);


	signal	state			: state_mem_t;

	signal   i_addr		: std_logic_vector(G_ADDR_W-1 downto 0); 
	signal	r_addr		: std_logic_vector(G_ADDR_W-1 downto 0); 

	signal	r_mem			: arr_mem_t := MEM_INIT(INIT_FILE) ;

	signal	i_wr_en		: std_logic;

	signal	r_rd_ack			: std_logic;
	signal	i_wr_ack			: std_logic;

begin

--	i_mem_rd_d <= r_mem(to_integer(unsigned(r_addr)));

	p_ram_rd:process(fb_syscon_i.clk)
	begin
		if rising_edge(fb_syscon_i.clk) then
			fb_p2c_o.D_Rd <= r_mem(to_integer(unsigned(i_addr)));
		end if;
	end process;
	
	i_addr <= fb_c2p_i.A(G_ADDR_W-1 downto 0) when state = idle else
				 r_addr;

	p_wr:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			if i_wr_ack = '1' then
				r_mem(to_integer(unsigned(i_addr))) <= fb_c2p_i.D_wr;
			end if;
		end if;

	end process;


	fb_p2c_o.rdy <= i_wr_ack or r_rd_ack;
	fb_p2c_o.ack <= i_wr_ack or r_rd_ack;
	fb_p2c_o.stall <= '0' when state = idle else '1';

	i_wr_ack 	<= '1' when state = idle and fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' and fb_c2p_i.D_wr_stb = '1' and fb_c2p_i.we = '1' else
						'1' when state = wait_wr_stb and fb_c2p_i.D_wr_stb = '1' else
						'0';

	p_state:process(fb_syscon_i)
	begin

		if fb_syscon_i.rst = '1' then
			state <= idle;
			r_rd_ack <= '0';
			r_addr <= (others => '0');
		else
			if rising_edge(fb_syscon_i.clk) then

				r_rd_ack <= '0';

				case state is
					when idle =>
						if fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' then
							r_addr <= fb_c2p_i.A(G_ADDR_W-1 downto 0);
							if fb_c2p_i.we = '0' then
								r_rd_ack <= '1';
							else
								if fb_c2p_i.D_wr_stb = '0' then
									state <= wait_wr_stb;
								end if;
							end if;
						end if;
					when wait_wr_stb =>
						if fb_c2p_i.D_wr_stb = '1' then
							state <= idle;
						end if;
					when others =>
						state <= idle;
				end case;

			end if;
		end if;
	end process;


end rtl;
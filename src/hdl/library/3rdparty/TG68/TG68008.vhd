------------------------------------------------------------------------------
------------------------------------------------------------------------------
--                                                                          --
-- This is the TOP-Level for TG68_fast to generate 68008 Bus signals        --
--                                                                          --
-- Copyright (c) 2019      Dominic Beesley								          -- 
--                                                                          --
-- This source file is free software: you can redistribute it and/or modify --
-- it under the terms of the GNU Lesser General Public License as published --
-- by the Free Software Foundation, either version 3 of the License, or     --
-- (at your option) any later version.                                      --
--                                                                          --
-- This source file is distributed in the hope that it will be useful,      --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of           --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            --
-- GNU General Public License for more details.                             --
--                                                                          --
-- You should have received a copy of the GNU General Public License        --
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.    --
--                                                                          --
------------------------------------------------------------------------------
------------------------------------------------------------------------------
--



library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity TG68008 is
   port(        
		clk           : in std_logic;
		reset         : in std_logic;
        clkena_in     : in std_logic:='1';
        data_in       : in std_logic_vector(7 downto 0);
        IPL           : in std_logic_vector(2 downto 0):="111";
        dtack         : in std_logic;
        addr          : out std_logic_vector(31 downto 0);
        data_out      : out std_logic_vector(7 downto 0);
        as            : out std_logic;
        ds            : out std_logic;
        lds           : out std_logic;
        rw            : out std_logic;
        drive_data    : out std_logic				--enable for data_out driver
        );
end TG68008;

ARCHITECTURE logic OF TG68008 IS

	COMPONENT TG68_fast
    PORT (
        clk           : in std_logic;
        reset         : in std_logic;
        clkena_in     : in std_logic;
        data_in       : in std_logic_vector(15 downto 0);
		IPL			  : in std_logic_vector(2 downto 0);
        test_IPL      : in std_logic;
        address       : out std_logic_vector(31 downto 0);
        data_write    : out std_logic_vector(15 downto 0);
        state_out     : out std_logic_vector(1 downto 0);
        decodeOPC     : buffer std_logic;
		wr			  : out std_logic;
		UDS, LDS	  : out std_logic
        );
	END COMPONENT;


   SIGNAL as_s        : std_logic;
   SIGNAL as_e        : std_logic;
   SIGNAL ds_s        : std_logic;
   SIGNAL ds_e        : std_logic;
   SIGNAL rw_s        : std_logic;
   SIGNAL rw_e        : std_logic;
   SIGNAL waitm       : std_logic;
   SIGNAL clkena_e    : std_logic;
   SIGNAL S_state     : std_logic_vector(2 downto 0);
   SIGNAL decode	  : std_logic;
   SIGNAL wr	      : std_logic;
   SIGNAL uds_in	  : std_logic;
   SIGNAL lds_in	  : std_logic;
   SIGNAL cpu_state   : std_logic_vector(1 downto 0);
   SIGNAL clkena	  : std_logic;
   SIGNAL n_clk		  : std_logic;
   SIGNAL cpuIPL      : std_logic_vector(2 downto 0);


   constant s_cpu_opcode	: std_logic_vector(1 downto 0) := "00";
   constant s_cpu_idle		: std_logic_vector(1 downto 0) := "01";
   constant s_cpu_memrd		: std_logic_vector(1 downto 0) := "10";
   constant s_cpu_memwr		: std_logic_vector(1 downto 0) := "11";

   signal	r_data_in		: std_logic_vector(15 downto 0);
   signal	i_data_out		: std_logic_vector(15 downto 0);

   signal	r_addr			: std_logic_vector(31 downto 0);
   signal	i_addr			: std_logic_vector(31 downto 0);

   signal	r_uds			: std_logic;
   signal	r_lds			: std_logic;

BEGIN  

	n_clk <= NOT clk;

TG68_fast_inst: TG68_fast
	PORT MAP (
		clk => n_clk, 				-- : in std_logic;
        reset => reset, 			-- : in std_logic;
        clkena_in => clkena, 		-- : in std_logic;
        data_in => r_data_in, 		-- : in std_logic_vector(15 downto 0);
		IPL => cpuIPL, 				-- : in std_logic_vector(2 downto 0);
        test_IPL => '0', 			-- : in std_logic;
        address => i_addr, 			-- : out std_logic_vector(31 downto 0);
        data_write => i_data_out, 	-- : out std_logic_vector(15 downto 0);
        state_out => cpu_state,		-- : out std_logic_vector(1 downto 0);
        decodeOPC => decode, 		-- : buffer std_logic;
		wr => wr, 					-- : out std_logic;
		UDS => uds_in, 				-- : out std_logic;
		LDS => lds_in 				-- : out std_logic;
        );
	

	clkena <= 	'1' when clkena_in = '1' and (clkena_e='1' OR cpu_state="01") else
				'0';

-- latch!
process(clk,reset,ds_e, ds_s, S_state)
BEGIN
	if reset = '0' then
		r_data_in <= (others => '1');
	elsif rising_edge(clk) then
		if ds_e = '0' or ds_s = '0' then
			if S_state(2) = '1' then
				r_data_in(7 downto 0) <= data_in;
			else
				r_data_in(15 downto 8) <= data_in;
			end if;
		end if;
	end if;
END PROCESS;

data_out <= i_data_out(7 downto 0) when S_state(2) = '1' else
			i_data_out(15 downto 8);
addr <= r_addr;
				
PROCESS (clk, reset, cpu_state, as_s, as_e, rw_s, rw_e, ds_s, ds_e)
	BEGIN
		IF cpu_state="01" THEN 
			as <= '1';
			rw <= '1';
			ds <= '1';
		ELSE
			as <= as_s AND as_e;
			rw <= rw_s AND rw_e;
			ds <= ds_s AND ds_e;
		END IF;
		IF reset='0' THEN
			S_state <= "111";
			as_s <= '1';
			rw_s <= '1';
			ds_s <= '1';
			r_addr <= (others => '1');
			r_uds <= '1';
			r_lds <= '1';
			waitm <= '1';
		ELSIF rising_edge(clk) THEN
        	IF clkena_in='1' THEN
				as_s <= '1';
				rw_s <= '1';
				ds_s <= '1';
				IF cpu_state/=s_cpu_idle OR decode='1' THEN
					CASE S_state IS
						WHEN "000" => as_s <= '0';			-- s2
									 r_addr <= i_addr;
									 r_uds <= uds_in;
									 r_lds <= lds_in;
									 rw_s <= wr;
									 IF wr='1' THEN
									 	ds_s <= '0';
									 END IF;
									 IF uds_in = '0' then
									 	S_state <= "001";
									 ELSE
									 	S_state <= "101";
									 END IF;
						WHEN "001" => as_s <= '0';			-- s4
									 rw_s <= wr;
									 ds_s <= '0';
									 S_state <= "010";
						WHEN "010" =>						-- s6
									 rw_s <= wr;
									 IF waitm='0' THEN
										S_state <= "011";
									 END IF;
						WHEN "011" =>						-- s0
									IF r_lds = '1' then
										S_state <= "000";
									ELSE
										S_state <= "100";
									END IF;
						WHEN "100" => as_s <= '0';			-- s2
									r_addr <= r_addr + 1;
									rw_s <= wr;
									IF wr='1' THEN
										ds_s <= '0';
									END IF;
 								 	S_state <= "101";									
						WHEN "101" => as_s <= '0';			-- s4
									 rw_s <= wr;
									 ds_s <= '0';
									 S_state <= "110";
						WHEN "110" =>						-- s6
									 rw_s <= wr;
									 IF waitm='0' THEN
										S_state <= "111";
									 END IF;
						WHEN "111" =>						-- s0
									S_state <= "000";
						WHEN OTHERS => null;			
					END CASE;
				END IF;
			END IF;
		END IF;	
		IF reset='0' THEN
			as_e <= '1';
			rw_e <= '1';
			ds_e <= '1';
			clkena_e <= '0';
			cpuIPL <= "111";
			drive_data <= '0';
		ELSIF falling_edge(clk) THEN
        	IF clkena_in='1' THEN
				as_e <= '1';
				rw_e <= '1';
				ds_e <= '1';
				clkena_e <= '0';
				drive_data <= '0';
				CASE S_state IS
					WHEN "000"|"100" => null;						-- s1
					WHEN "001"|"101" => drive_data <= NOT wr;		-- s3
					WHEN "010"|"110" => as_e <= '0';				-- s5
								 		ds_e <= '0';
								 		cpuIPL <= IPL;
								 		drive_data <= NOT wr;
								 		IF cpu_state=s_cpu_idle THEN
									 		clkena_e <= '1';
									 		waitm <= '0';
								 		ELSE
								 			IF S_state(2) = '1' or r_lds = '1' then
									 			clkena_e <= NOT dtack;
									 		END IF;
									 		waitm <= dtack;
								 		END IF;
					WHEN OTHERS => null;			
				END CASE;
			END IF;
		END IF;	
	END PROCESS;
END;	
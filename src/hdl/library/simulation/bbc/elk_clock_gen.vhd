-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2021 Dominic Beesley https://github.com/dominicbeesley
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

-- Company:             Dossytronics
-- Engineer:            Dominic Beesley
-- 
-- Create Date:         10/11/2021
-- Design Name: 
-- Module Name:         elk_clk_gen
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:         A simulation model for the Electron's clock generation 
--                      and stretching circuitry
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------




library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;


entity elk_clk_gen is
generic (
    MODE_2MHZ       : boolean := true                   -- when true have 38/64us as ram wait
);
port (
    clk_16_i        : in    std_logic;
    clk_8_o         : out   std_logic;
    clk_4_o         : out   std_logic;
    clk_2_o         : out   std_logic;
    clk_1_o         : out   std_logic;
    
    elk_SLOW_hw_i   : in    std_logic;      -- slow address 1MHz detected
    elk_SLOW_RAM_i  : in    std_logic;      -- slow ram addresses either 1000 or 1500 ns or 38us for MODE_2MHz

    elk_phi0_o      : out   std_logic;
    elk_ram_en_o    : out   std_logic       -- enable motherboard ram 
);
end elk_clk_gen;

architecture rtl of elk_clk_gen is
    signal r_clk_8      : std_logic := '0';
    signal r_clk_4      : std_logic := '0';
    signal r_clk_2      : std_logic := '0';
    signal r_clk_1      : std_logic := '0';

    signal r_scan_ctr   : unsigned(5 downto 0) := (others => '0');

    signal r_scan_act   : std_logic;
    signal i_mem_bsy    : std_logic;

    type t_state is (idle, hw0, hw1, ram);

    signal r_state      : t_state := idle;

begin

    clk_8_o <= r_clk_8;
    clk_4_o <= r_clk_4;
    clk_2_o <= r_clk_2;
    clk_1_o <= r_clk_1;

    p_clk_8:process(clk_16_i)
    begin
        if falling_edge(clk_16_i) then
            r_clk_8 <= not r_clk_8;
        end if;
    end process;

    p_clk_4:process(r_clk_8)
    begin
        if falling_edge(r_clk_8) then
            r_clk_4 <= not r_clk_4;
        end if;
    end process;

    p_clk_2:process(r_clk_4, i_mem_bsy)
    begin
        if falling_edge(r_clk_4) then
            r_clk_2 <= not r_clk_2;
            if (r_clk_2 = '0') then -- was about to rise - possibly block next fall...

                case r_state is
                    when idle =>
                        -- check the type of memory access
                        if elk_SLOW_hw_i = '1' then
                            -- hardware access - check the 1MHz cycle state and delay
                            -- either to make a 1000 ns or 1500 ns depending on the
                            -- phase of 1MHz
                            if r_clk_1 = '1' then
                                r_state <= hw0;
                            else
                                r_state <= hw1;
                            end if;
                        elsif elk_SLOW_RAM_i = '1' then
                            if i_mem_bsy = '1' or r_clk_1 = '0' then
                                r_state <= ram;
                            end if;
                        end if;
                    when ram =>
                        if i_mem_bsy = '0' and r_clk_1 = '1' then
                            r_state <= idle;
                        end if;
                    when hw0 =>
                        if r_clk_1 = '0' then
                            r_state <= hw1;
                        end if;
                    when hw1 =>
                        if r_clk_1 = '1' then
                            r_state <= idle;                            
                        end if;
                    when others =>
                        r_state <= idle;
                end case;
            end if;
        end if;
    end process;

    p_clk_1:process(r_clk_2)
    begin
        if falling_edge(r_clk_2) then
            r_clk_1 <= not r_clk_1;
            r_scan_ctr <= r_scan_ctr + 1;
            if to_integer(r_scan_ctr) < 40 then
                r_scan_act <= '1';
            else
                r_scan_act <= '0';
            end if;
        end if;
    end process;

    i_mem_bsy <=    '1' when MODE_2MHz and r_scan_act = '1' else
                    '1' when r_scan_act = '1' and r_clk_1 = '1' else
                    '0';

    elk_phi0_o <=   '1' when r_state /= idle else
                    r_clk_2;

    elk_ram_en_o <= '1' when r_clk_1 = '0' and r_state = idle else
                    '0';    


end rtl;


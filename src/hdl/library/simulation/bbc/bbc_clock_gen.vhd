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
-- Module Name:         bbc_clk_gen
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:         A simulation model for the Model B's clock generation 
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

entity bbc_clk_gen is
port (
    clk_16_i        : in    std_logic;
    
    bbc_SLOW_i      : in    std_logic;      -- slow address detected i.e. pin 8 of IC23
    bbc_phi1_i      : in    std_logic;    

    bbc_1MHzE_o     : out   std_logic;
    bbc_ROMSEL_clk_o: out   std_logic;
    bbc_phi0_o      : out   std_logic;

    bbc_2MHzE_o     : out   std_logic;

    clken4_o        : out   std_logic       -- needed for Hoglet's 6522 implementation
);
end bbc_clk_gen;

architecture rtl of bbc_clk_gen is
    signal r_clk_8      : std_logic := '0';
    signal r_clk_4      : std_logic := '0';
    signal r_clk_2      : std_logic := '0';
    signal i_bbc_1MHzE  : std_logic := '0';
    signal i_bbc_n1MHzE : std_logic := '0';
    signal i_IC30B_Q	: std_logic := '0';
    signal i_nSLOW      : std_logic := '0';
    signal i_IC31B_nQ   : std_logic := '0';
    signal i_IC34A_nQ   : std_logic := '0';
    signal i_IC29C_Q    : std_logic := '0';
    signal i_IC30A_Q    : std_logic := '0';
    signal i_phi0       : std_logic := '0';
    signal i_IC28A_Q      : std_logic;
begin

    clken4_o <= r_clk_8 and r_clk_4;

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

    p_clk_2:process(r_clk_4)
    begin
        if falling_edge(r_clk_4) then
            r_clk_2 <= not r_clk_2;
        end if;
    end process;
        
    e_IC34B:entity work.ls74
    port map (
        d => i_bbc_n1MHzE,
        pre => '1',
        clr => '1',
        clk => r_clk_2,
        q => i_bbc_1MHzE,
        nq=> i_bbc_n1MHzE
    );
    
    bbc_1MHzE_o <= i_bbc_1MHzE;

    e_IC37E:entity work.ls04
    port map (
        d => bbc_phi1_i,
        q => bbc_2MHzE_o
        );

    e_IC30B:entity work.ls74
    port map (
        d => r_clk_2,
        pre => '1',
        clr => '1',
        clk => r_clk_8,
        q => i_IC30B_Q
    );

    e_IC33A:entity work.ls04
    port map (
        d => bbc_SLOW_i,
        q => i_nSLOW
        );

    e_IC31B:entity work.ls74
    port map (
        d => i_nSLOW,
        pre => i_IC34A_nQ,
        clr => '1',
        clk => i_bbc_1MHzE,
        nq => i_IC31B_nQ        
        );

    e_IC29C:entity work.ls32
    port map (
        dA => i_nSLOW,
        dB => i_IC31B_nQ,
        q => i_IC29C_Q
        );

    e_IC34A:entity work.ls74
    port map (
        d => i_IC29C_Q,
        pre => '1',
        clr => '1',
        clk => i_IC30A_Q,
        nq => i_IC34A_nQ                
        );

    e_IC30A:entity work.ls74
    port map (
        d => i_IC30B_Q,
        pre => '1',
        clr => i_IC28A_Q,
        clk => r_clk_8,
        q => i_IC30A_Q,
        nq => bbc_ROMSEL_clk_o               
        );

    e_IC29D:entity work.ls32
    port map (
        dA => i_IC34A_nQ,
        dB => i_IC30A_Q,
        q => i_phi0
        );

    bbc_phi0_o <= i_phi0;

    e_IC28:entity work.ls51
    port map (
        dA => i_bbc_1MHzE,
        dB => bbc_SLOW_i,
        dC => bbc_phi1_i,
        dD => '0',
        dE => '0',
        dF => '0',
        Q => i_IC28A_Q
        );

    
end rtl;


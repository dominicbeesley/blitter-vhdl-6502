-- MIT License
-- -----------------------------------------------------------------------------
-- Copyright (c) 2025 Dominic Beesley https://github.com/dominicbeesley
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

-- Company:          Dossytronics
-- Engineer:         Dominic Beesley
-- 
-- Create Date:      15/7/2025
-- Design Name: 
-- Module Name:      sim_cpu_mem
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      c20k combined memory chips, 65816 and multiplex chips
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--                   Does basic delays and timings for the CPU, memory and mux
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library fmf;

entity sim_cpu_mem is
   generic (
       G_MOSROMFILE : string 
   );
   port(

      MEM_A_io       : inout  std_logic_vector(20 downto 0);
      MEM_D_io       : inout  std_logic_vector(7 downto 0);

      MEM_nCE_i      : in     std_logic_vector(3 downto 0); -- 0 is BB RAM
      MEM_FL_nCE_i   : in     std_logic;                    -- Flash EEPROM select
      MEM_nOE_i      : in     std_logic;
      MEM_nWE_i      : in     std_logic;

      CPU_A_nOE_i    : in     std_logic;

      CPU_PHI2_i     : in     std_logic;
      CPU_BE_i       : in     std_logic;
      CPU_RDY_i      : in     std_logic;

      CPU_nRES_i     : in     std_logic;
      CPU_nIRQ_i     : in     std_logic;
      CPU_nNMI_i     : in     std_logic;
      CPU_nABORT_i   : in     std_logic;

      CPU_MX_o       : out    std_logic;
      CPU_E_o        : out    std_logic

   );
end sim_cpu_mem;

architecture rtl of sim_cpu_mem is

   signal i_CPU_A    : std_logic_vector(15 downto 8);
   signal i_CPU_VDA  : std_logic;
   signal i_CPU_VPA  : std_logic;
   signal i_CPU_nVPB : std_logic;
   signal i_CPU_nMLB : std_logic;
   signal i_CPU_Rnw  : std_logic;

   signal i_U40_A    : std_logic_vector(7 downto 0);
   signal i_U40_B    : std_logic_vector(7 downto 0);

begin 


   e_U39:entity work.AC245
   Port map (
      A           => MEM_A_io(15 downto 8),
      B           => i_CPU_A(15 downto 8),
      DIR_AnB     => '0',
      nOE         => CPU_A_nOE_i
   );

   e_U40:entity work.AC245
   Port map (
      A           => i_U40_A,
      B           => i_U40_B,
      DIR_AnB     => '0',
      nOE         => CPU_A_nOE_i
   );

   i_U40_A <= (others => 'Z');

   --MEM_A_io(17) <= i_U40_A(4);
   --MEM_A_io(20) <= i_U40_A(3);
   --MEM_A_io(18) <= i_U40_A(2);
   --MEM_A_io(16) <= i_U40_A(1);
   --MEM_A_io(19) <= i_U40_A(0);


   i_U40_B <= (
      4      => i_CPU_VDA,
      3      => i_CPU_nVPB,
      2      => i_CPU_nMLB,
      1      => i_CPU_VPA,
      0      => i_CPU_RnW,
      others => '0'
      );



   e_U38:entity work.real_65816_tb
   port map (
      A(7 downto 0)  => MEM_A_io(7 downto 0),
      A(15 downto 8) => i_CPU_A,
      D              => MEM_D_io,
      nRESET         => CPU_nRES_i,
      RDY            => CPU_RDY_i,
      nIRQ           => CPU_nIRQ_i,
      nNMI           => CPU_nNMI_i,
      BE             => CPU_BE_i,
      RnW            => i_CPU_RnW,
      VPA            => i_CPU_VPA,
      VPB            => i_CPU_nVPB,
      VDA            => i_CPU_VDA,
      MX             => CPU_MX_o,
      E              => CPU_E_o,
      MLB            => i_CPU_nMLB,

      PHI2           => CPU_PHI2_i
      );

   --actually just the same ROM repeated!
   e_U25: entity work.ram_tb 
   generic map (
      size        => 16*1024,
      dump_filename => "",
      romfile => G_MOSROMFILE,
      tco => 55 ns,
      taa => 55 ns
   )
   port map (
      A           => MEM_A_io(13 downto 0),
      D           => MEM_D_io,
      nCS         => MEM_FL_nCE_i,
      nOE         => MEM_nOE_i,
      nWE         => '1',
      
      tst_dump    => '0'

   );

   -- single non BB ram
   --TODO the timings are wrong!
   e_U22: entity work.ram_tb 
   generic map (
      size        => 2*1024*1024,
      dump_filename => "",
      tco => 10 ns,
      taa => 10 ns,
      toh => 2 ns,      
      tohz => 3 ns,  
      thz => 3 ns,
      tolz => 3 ns,
      tlz => 3 ns,
      toe => 4.5 ns,
      twed => 6.5 ns
   )
   port map (
      A           => MEM_A_io(20 downto 0),
      D           => MEM_D_io,
      nCS         => MEM_nCE_i(1),
      nOE         => MEM_nOE_i,
      nWE         => MEM_nWE_i,
      
      tst_dump    => '0'

   );



end architecture rtl;

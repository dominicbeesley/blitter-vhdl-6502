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
-- -----------------------------------------------------------------------------

-- Company:          Dossytronics
-- Engineer:         Dominic Beesley
-- 
-- Create Date:      30/9/2023
-- Design Name: 
-- Module Name:      sprite_int.vhd
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:      Model C sprite: line comparator and serialiser
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--    See http://amigadev.elowar.com/read/ADCD_2.1/Hardware_Manual_guide/node02D6.html
--    Inspired by Amiga sprites but tweaked to work in an 8-bit world
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.fishbone.all;

entity sprite_int is
   generic (
      SIM                           : boolean := false                     -- skip some stuff, i.e. slow sdram start up
   );
   port(

      rst_i                         : in  std_logic;                    

      clk_i                         : in  std_logic;                    -- cpu/sequencer clock
      clken_i                       : in  std_logic;                    -- this qualifies all clocks for seq/cpu

      -- data interface, from sequencer
      SEQ_D_i                       : in  std_logic_vector(7 downto 0);
      SEQ_wren_i                    : in  std_logic;
      SEQ_A_i                       : in  unsigned(3 downto 0);         -- sprite data A..D, pos/ctl, ptr, lst (see below in p_regs)

      -- sequencer interface out
      SEQ_DATAPTR_A_o               : out std_logic_vector(23 downto 0);-- sprite data pointer out 
      SEQ_DATAPTR_act_o             : out std_logic;
      SEQ_A_pre_o                   : out std_logic_vector(1 downto 0); -- 00 = data, 01 = ctl, 10 = ptr, 11 = lst(unused)

      -- data interface, from CPU
      CPU_D_i                       : in  std_logic_vector(7 downto 0);
      CPU_A_i                       : in  unsigned(3 downto 0);         -- sprite data A..D, pos/ctl, ptr, lst (see below in p_regs)
      CPU_wren_i                    : in  std_logic;
      CPU_rden_i                    : in  std_logic;

      CPU_D_o                       : out   std_logic_vector(7 downto 0); --TODO: debug sprite read interface, remove?
      CPU_wr_ack_o                  : out std_logic;                    -- when writing stall until this is '1'
      CPU_rd_ack_o                  : out std_logic;                    -- when writing stall until this is '1'

      -- vidproc / crtc signals in
      pixel_clk_i                   : in  std_logic;                    -- pixel clock (not necessarily same domain as cpu/sequencer)
      pixel_clken_i                 : in  std_logic;                    -- move to next pixel must coincide with clken_i
      horz_ctr_i                    : in  unsigned(8 downto 0);         -- counts mode 4 pixels since horz-sync
      vert_ctr_i                    : in  unsigned(8 downto 0);

      -- pixel data out
      px_D_o                        : out std_logic_vector(1 downto 0);

      -- registers out

      horz_start_o                  : out unsigned(8 downto 0);
      vert_start_o                  : out unsigned(8 downto 0);
      vert_stop_o                   : out unsigned(8 downto 0);
      attach_o                      : out std_logic;

      -- arm/disarm in 
      horz_disarm_clken_i              : in  std_logic;              -- fires once per line when all sprites should restart prior to sequencer loading new data
      vert_reload_clken_i              : in  std_logic               -- fires once per frame when pointers should be reset

   );
end sprite_int;

architecture rtl of sprite_int is

   -- registers
   signal r_line_armed        :  std_logic;                          -- indicates that the sprite is armed (either by a direct cpu load or DMA)
   signal r_spr_data          :  std_logic_vector(31 downto 0);      -- this sprite line's bit map ready for transfer to serializer
   signal r_spr_serial        :  std_logic_vector(31 downto 0);
   signal r_horz_start        :  unsigned(8 downto 0);
   signal r_vert_start        :  unsigned(8 downto 0);
   signal r_vert_stop         :  unsigned(8 downto 0);
   signal r_attach            :  std_logic;
   signal r_lat_data_ptr      :  std_logic_vector(15 downto 0);      -- latched data pointer (copied to r_data_ptr when high byte written)
   signal r_lat_list_ptr      :  std_logic_vector(15 downto 0);      -- latched data pointer2 (copied to r_listinit_ptrwhen high byte written)
   signal r_data_ptr          :  std_logic_vector(23 downto 0);      -- pointer to sprite pixel data as it is read
   signal r_list_ptr          :  std_logic_vector(23 downto 0);      -- pointer to current list item (reloaded from r_listinit_ptr at start of field)
   signal r_listinit_ptr      :  std_logic_vector(23 downto 0);      -- pointer to head of this sprite's list
   signal r_list_en           :  std_logic;                          -- '1' when any bit set in r_listinit_ptr

   -- combinatorials
   signal i_horz_eq           :  std_logic;                          -- '1' when horz_ctr == r_horz_start

   -- vertical activation 
   signal r_vert_armed        :  std_logic;                 -- control register has been written this frame
   signal r_vert_act          :  std_logic;                 -- between v start/end and armed

   -- signal vertical restart from pixel to data clock
   signal r_vert_req          :  std_logic;
   signal r_vert_req2          :  std_logic;
   signal r_vert_ack          :  std_logic;

   signal r_horz_req          :  std_logic;
   signal r_horz_req2          :  std_logic;
   signal r_horz_ack          :  std_logic;

   type t_list_state is (idle, start, ctl, dataptr, data);
   signal r_list_state        :  t_list_state;
   signal r_list_cont         :  std_logic;
   signal r_load_data_ptr     :  std_logic;

   signal r_debug_syncmismatch:  std_logic;
   signal r_debug_ctr         :  unsigned(7 downto 0);
   signal r_debug_ctr2        :  unsigned(7 downto 0);

   signal r_debug_states      :  std_logic_vector(7 downto 0);
   signal r_debug_states_prev :  std_logic_vector(7 downto 0);
   

begin

   horz_start_o <= r_horz_start;
   vert_start_o <= r_vert_start;
   vert_stop_o  <= r_vert_stop;
   attach_o     <= r_attach;

   px_D_o       <= r_spr_serial(r_spr_serial'high downto r_spr_serial'high-1);


   -- process to get horizontal restart from pixel clock into clk_i domain
   p_sync_cd:process(pixel_clk_i, pixel_clken_i, rst_i)
   begin

      if rst_i = '1' then
         r_horz_req <= '0';
         r_vert_req <= '0';
      elsif rising_edge(pixel_clk_i) and pixel_clken_i = '1' then
         if horz_disarm_clken_i = '1' then
            r_horz_req <= not r_horz_req;
         end if;
         if vert_reload_clken_i = '1' then
            r_vert_req <= not r_vert_req;
         end if;
      end if;
   end process;

   -- horz comparator
   i_horz_eq <= '1' when r_horz_start = horz_ctr_i else '0';

   -- (re)arm the sprite for this line ready for comparator
   p_arm:process(clk_i, rst_i, clken_i)
   begin
      if rst_i = '1' then
         r_vert_act <= '0';
         r_line_armed <= '0';
         r_horz_ack <= '0';
         r_list_state <= idle;      
         r_vert_ack <= '0';
         r_list_ptr <= (others => '0');
         r_load_data_ptr <= '0';    
         r_vert_armed <= '0';    
         r_debug_ctr <= (others =>'0');
         r_debug_states_prev <= (others => '0');
         r_debug_states <= (others => '0');
      elsif rising_edge(clk_i) and clken_i = '1' then
         -- arm on data write to last data byte
         -- clear on any ctl/pos change

         r_horz_req2 <= r_horz_req;
         r_vert_req2 <= r_vert_req;

         r_debug_states(t_list_state'pos(r_list_state)) <= '1';

         -- TODO: sort this out to reduce logic and document
         if r_horz_ack /= r_horz_req2 then
            r_line_armed <= '0';
            r_horz_ack <= r_horz_req2;

            if r_vert_req2 /= r_vert_ack then
               r_vert_armed <= '0';
               r_list_ptr <= r_listinit_ptr;
               r_debug_ctr2 <= r_debug_ctr2 + 1;
               if r_list_en = '1' then
                  r_debug_ctr <= r_debug_ctr + 1;
                  r_list_state <= start;
               else
                  r_list_state <= idle;
               end if;
               r_debug_states_prev <= r_debug_states;
               r_debug_states <= (others => '0');
               r_vert_ack <= r_vert_req2;
               r_vert_act <= '0';
               r_load_data_ptr <= '1';    --- always load for first in list
            elsif vert_ctr_i = r_vert_start and r_vert_start /= 0 and r_vert_armed = '1' then
               r_vert_act <= '1';
            elsif vert_ctr_i = r_vert_stop and r_vert_act = '1' then
               r_vert_act <= '0';               
               if r_list_cont = '1' then
                  r_list_state <= ctl;
               else
                  r_list_state <= idle;
               end if;
            elsif r_list_state = start and vert_ctr_i = to_unsigned(4, vert_ctr_i'length) then
               r_list_state <= ctl;
            end if;

         end if;

         if SEQ_A_i(3 downto 2) = "01" and SEQ_wren_i = '1' then
            r_line_armed <= '0';
         elsif SEQ_A_i = "0011" and SEQ_wren_i = '1' then
            r_line_armed <= '1';
         end if;
         if CPU_A_i(3 downto 2) = "01" and CPU_wren_i = '1' then
            r_line_armed <= '0';
         elsif CPU_A_i = "0011" and CPU_wren_i = '1' then
            r_line_armed <= '1';
         end if;

         
         if SEQ_A_i = "0111" and SEQ_wren_i = '1' then
            -- ctl write
            r_load_data_ptr <= SEQ_D_i(6);      -- TODO: move this to other process or merge processes
            if r_load_data_ptr = '1' then    -- NB: this is from the previous control word in list!
               r_list_state <= dataptr;
            else
               r_list_state <= data;
            end if;
            r_vert_armed <= '1';
         elsif SEQ_A_i = "1011" and SEQ_wren_i = '1' then
            -- dataptr write
            r_list_state <= data;
         end if;

         if CPU_A_i = "0111" and CPU_wren_i = '1' then
            -- ctl write
            r_vert_armed <= '1';
         end if;

         if (SEQ_A_i(3 downto 2) = "01" or SEQ_A_i(3 downto 2) = "10") and SEQ_wren_i = '1' then
            r_list_ptr <= r_list_ptr(23 downto 16) & std_logic_vector(unsigned(r_list_ptr(15 downto 0)) + 1);        
         end if;

      end if;
   end process;

   SEQ_DATAPTR_A_o <= r_list_ptr when r_list_state = ctl or r_list_state = dataptr else
                      r_data_ptr;

   SEQ_A_pre_o <=    "01" when r_list_state = ctl else
               "10" when r_list_state = dataptr else
               "00";
   SEQ_DATAPTR_act_o 
           <=  '1' when r_list_state = ctl else
               '1' when r_list_state = dataptr else
               r_vert_act;

   p_regs:process(clk_i, rst_i, clken_i)
   variable v_cur_wren  : boolean;
   variable v_cur_A     : unsigned(SEQ_A_i'high downto SEQ_A_i'low);
   variable v_cur_D     : std_logic_vector(7 downto 0);
   variable v_wr_dptr   : boolean;
   variable v_wr_dptr2  : boolean;
   variable v_inc_dptr  : boolean;
   begin
      if rst_i = '1' then
         r_horz_start <= (others => '0');
         r_vert_start <= (others => '0');
         r_vert_stop  <= (others => '0');
         r_attach <= '0';
         r_spr_data <= (others => '0');
         r_lat_data_ptr <= (others => '0');
         r_data_ptr <= (others => '0');
         r_lat_list_ptr <= (others => '0');
         r_listinit_ptr <= (others => '0');
         r_list_cont <= '0';
         CPU_wr_ack_o <= '0';
      elsif rising_edge(clk_i) and clken_i = '1' then
         
         CPU_wr_ack_o <= '0';
         v_inc_dptr := false;
         v_cur_wren := false;
         if SEQ_wren_i = '1' then
            v_cur_wren := true;
            v_cur_A := SEQ_A_i;
            v_cur_D := SEQ_D_i;
            if v_cur_A(3 downto 2) = "00" then
               v_inc_dptr := true;
            end if;
         elsif CPU_wren_i = '1' then
            v_cur_wren := true;
            v_cur_A := CPU_A_i;
            v_cur_D := CPU_D_i;
            CPU_wr_ack_o <= '1';
         end if;

         v_wr_dptr := false;
         v_wr_dptr2 := false;
         if v_cur_wren then
            case to_integer(v_cur_A) is
               -- data - note pixel data is left aligned, low byte first, planar (not like Amiga?)
               when 0   => r_spr_data(31 downto 24) <= v_cur_D;
               when 1   => r_spr_data(23 downto 16) <= v_cur_D;
               when 2   => r_spr_data(15 downto 8)  <= v_cur_D;
               when 3   => r_spr_data( 7 downto 0)  <= v_cur_D;
               -- control / pos different to Amiga!
               when 4   => r_horz_start(7 downto 0) <= unsigned(v_cur_D);
               when 5   => r_vert_start(7 downto 0) <= unsigned(v_cur_D);
               when 6   => r_vert_stop(7 downto 0)  <= unsigned(v_cur_D);
               when 7   =>
                  -- TODO: latch h/v/etc starts until this written?!?
                  r_horz_start(8) <= v_cur_D(0);
                  r_vert_start(8) <= v_cur_D(1);
                  r_vert_stop(8)  <= v_cur_D(2);
                  r_list_cont     <= v_cur_D(5);
                  r_attach        <= v_cur_D(7);
               -- little endian data pointer (todo - CPU access in Big Endian as well?)
               when 8   => 
                  r_lat_data_ptr(7 downto 0)          <= v_cur_D;
               when 9   => 
                  r_lat_data_ptr(15 downto 8)         <= v_cur_D;
               when 10  => 
                  v_wr_dptr := true;               
               when 12  => 
                  r_lat_list_ptr(7 downto 0)          <= v_cur_D;
               when 13  => 
                  r_lat_list_ptr(15 downto 8)         <= v_cur_D;
               when 14  => 
                  v_wr_dptr2 := true;              
               when others => 
                  null;
            end case;
         end if;

         if v_wr_dptr then
            r_data_ptr <= v_cur_D & r_lat_data_ptr;
         elsif v_inc_dptr then
            r_data_ptr <= r_data_ptr(23 downto 16) & std_logic_vector(unsigned(r_data_ptr(15 downto 0)) + 1);        
         end if;

         if v_wr_dptr2 then
            r_listinit_ptr <= v_cur_D & r_lat_list_ptr;
            r_list_en <= or_reduce(v_cur_D & r_lat_list_ptr);
         end if;

      end if;
   end process;


   p_cpu_d_rd:process(rst_i, clk_i)
   begin
      if rst_i = '1' then
         CPU_D_o <= (others => '0');
         CPU_rd_ack_o <= '0';
      elsif rising_edge(clk_i) then
         if clken_i = '1' then
            CPU_D_o <=
               r_spr_data(31 downto 24)      when CPU_A_i(3 downto 0) = x"0" else
               r_spr_data(23 downto 16)      when CPU_A_i(3 downto 0) = x"1" else
               r_spr_data(15 downto 8)       when CPU_A_i(3 downto 0) = x"2" else
               r_spr_data(7 downto 0)        when CPU_A_i(3 downto 0) = x"3" else
               std_logic_vector(r_horz_start(7 downto 0))
                                             when CPU_A_i(3 downto 0) = x"4" else
               std_logic_vector(r_vert_start(7 downto 0))
                                             when CPU_A_i(3 downto 0) = x"5" else
               std_logic_vector(r_vert_stop(7 downto 0))
                                             when CPU_A_i(3 downto 0) = x"6" else
               r_attach & "0" & r_list_cont & "00" & std_logic(r_vert_stop(8)) & std_logic(r_vert_start(8)) & std_logic(r_horz_start(8))
                                             when CPU_A_i(3 downto 0) = x"7" else
               r_data_ptr(7 downto 0)        when CPU_A_i(3 downto 0) = x"8" else
               r_data_ptr(15 downto 8)       when CPU_A_i(3 downto 0) = x"9" else
               r_listinit_ptr(7 downto 0)    when CPU_A_i(3 downto 0) = x"C" else
               r_listinit_ptr(15 downto 8)   when CPU_A_i(3 downto 0) = x"D" else
               -- debug
               std_logic_vector(r_debug_ctr2)
                                             when CPU_A_i(3 downto 0) = x"A" else
               r_debug_states_prev
                                             when CPU_A_i(3 downto 0) = x"E" else
               std_logic_vector(r_debug_ctr)
                                             when CPU_A_i(3 downto 0) = x"F" else
               (others => '0');
            CPU_rd_ack_o <= CPU_rden_i;
         end if;
      end if;
   end process;


   p_shr:process(pixel_clk_i, rst_i, pixel_clken_i)
   begin
      if rst_i = '1' then
         r_spr_serial <= (others => '0');
      elsif rising_edge(pixel_clk_i) and pixel_clken_i = '1' then
         
         if r_line_armed = '1' and i_horz_eq = '1' then
            -- hit horizontal pos and we're armed
            r_spr_serial <= r_spr_data;
         else
            r_spr_serial <= r_spr_serial(r_spr_serial'high-2 downto 0) & "00";
         end if;
      end if;
   end process;

end rtl;
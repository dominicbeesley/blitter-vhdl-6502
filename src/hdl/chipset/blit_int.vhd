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
--TODO: uses ack, could maybe use rdy_ctdn?

----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	3/7/2017 
-- Design Name: 
-- Module Name:    	blit internal - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		blitter chip internal 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Revision 0.02 - line mode 
-- Additional Comments: 
-- 
----------------------------------------------------------------------------------

--               .     .     .     .     .     .     .     .     .     .     .     .
--               .     .     .     .     .     .     .     .     .     .     .     .
--               .     .     .     .     .     .     .     .     .     .     .     .
--               .     .     .     .     .     .     .     .     .     .     .     .
--               .     .     .     .     .     .     .     .     .     .     .     .
--               .     .     .     .     .     .     .     .     .     .     .     .
--               .     .     .     .     .     .     .     .     .     .     .     .
--               .     .     .     .     .     .     .     .     .     .     .     .
--   sNext  strt><AAAAAAAAAA><CCCCCCCCCC><BBBBBBBBBB><DDDDD><fin ><idle===============
--   sCur   idle><strt======><AAAAAAAAAA><CCCCCCCCCC><BBBBB><DDDD><fin ><idle=========
--   sExec  
--               .     .     .     .     .     .     .     .     .     .     .     .
--   Ck8   	^^___^^^___^^^___^^^___^^^___^^^___^^^___^^^___^^^___^^^___^^^___^^^___^^^
--               .     .     .     .     .     .     .     .     .     .     .     .
--   A 		XXXX><aaaaaaaaaa><cccccccccc><bbbbbbbbbb><ddddd>--------------------------
--               .     .     .     .     .     .     .     .     .     .     .     .
--   RnW		^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^____________^^^^^^^^^^^^^^^^^^^^^
--               .     .     .     .     .     .     .     .     .     .     .     .
--   req   	_____^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^_____________________
--               .     .     .     .     .     .     .     .     .     .     .     .
--   ack   	_____________^^^^^______^^^^^_______^^^^^__ ^^^^__________________________
--               .     .     .     .     .     .     .     .     .     .     .     .
--   exec	____________________^^^^_______^^^^^________^^^^_^^^^_
--               .     .     .     .     .     .     .     .     .     .     .     .
--   Din  	??????????????????<aaaaaa>XX<ccccccc>XXX<bbbbbbb>XXXXXXXXXXXXXXXXXXXXXXXXX  
--               .     .     .     .     .     .     .     .     .     .     .     .
--   Dout   XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX<dddd>XXXXXXXXXXXXXXXXXXXX
-- 
-- 
-- 
-- 
-- 
-- 
-- 
-- 
-- 
-- 
-- 

-- TODO: naming of sMEM* states and execX regis is confusing as D execs an sMemAccD cycle even
-- if execD is clear but it doesnt access mem, consider renaming!

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_MISC.ALL;

library work;
use work.fishbone.all;
use work.blit_types.ALL;

entity fb_dmac_blit is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up	
		G_STRIDE_HIGH						: integer := 11
	);
   Port (
		-- fishbone signals		
		fb_syscon_i							: in		fb_syscon_t;

		-- peripheral interface (control registers)
		fb_per_c2p_i						: in		fb_con_o_per_i_t;
		fb_per_p2c_o						: out		fb_con_i_per_o_t;

		-- controller interface (dma)
		fb_con_c2p_o						: out		fb_con_o_per_i_t;
		fb_con_p2c_i						: in		fb_con_i_per_o_t;

		cpu_halt_o							: out		std_logic;
		blit_halt_i							: in		std_logic
	);

   -- note addresses are odd to cater for extended registers at $A0 and baseic at $60

	constant	A_BLTCON 		: integer := 16#60#;
	constant	A_FUNCGEN 		: integer := 16#61#;
	constant	A_WIDTH	 		: integer := 16#62#;
	constant	A_HEIGHT 		: integer := 16#63#;
	constant	A_SHIFT			: integer := 16#64#;
	constant	A_MASK_FIRST	: integer := 16#65#;
	constant	A_MASK_LAST 	: integer := 16#66#;
	constant	A_DATA_A 		: integer := 16#67#;
	constant	A_ADDR_A 		: integer := 16#68#;
	constant	A_DATA_B 		: integer := 16#6B#;
	constant	A_ADDR_B 		: integer := 16#6C#;
	constant	A_ADDR_C 		: integer := 16#6F#;
	constant	A_ADDR_D 		: integer := 16#72#;
	constant	A_ADDR_E 		: integer := 16#75#;
	constant	A_STRIDE_A		: integer := 16#78#;
	constant	A_STRIDE_B		: integer := 16#7A#;
	constant	A_STRIDE_C		: integer := 16#7C#;
	constant	A_STRIDE_D		: integer := 16#7E#;
	constant A_ADDR_D_MIN	: integer := 16#A0#;
	constant A_ADDR_D_MAX	: integer := 16#A3#;

	-- NEW ABI: cater for little-endian pokes and 4 byte aligned access for ARM
	constant	A_N_BLTCON 		: integer := 16#200#;
	constant	A_N_FUNCGEN 	: integer := 16#201#;
	constant	A_N_MASK_FIRST	: integer := 16#202#;
	constant	A_N_MASK_LAST 	: integer := 16#203#;
	constant	A_N_WIDTH	 	: integer := 16#204#;
	constant	A_N_HEIGHT 		: integer := 16#205#;
	constant	A_N_SHIFT_A		: integer := 16#206#;
	constant	A_N_SHIFT_B		: integer := 16#207#;
	constant	A_N_STRIDE_A	: integer := 16#208#;
	constant	A_N_STRIDE_B	: integer := 16#20A#;
	constant	A_N_STRIDE_C	: integer := 16#20C#;
	constant	A_N_STRIDE_D	: integer := 16#20E#;
	constant	A_N_ADDR_A 		: integer := 16#210#;
	constant	A_N_DATA_A 		: integer := 16#213#;
	constant	A_N_ADDR_B 		: integer := 16#214#;
	constant	A_N_DATA_B 		: integer := 16#217#;
	constant	A_N_ADDR_C 		: integer := 16#218#;
	constant	A_N_DATA_C 		: integer := 16#21B#;
	constant	A_N_ADDR_D 		: integer := 16#21C#;
	constant	A_N_ADDR_E 		: integer := 16#220#;
	constant A_N_ADDR_D_MIN	: integer := 16#224#;
	constant A_N_ADDR_D_MAX	: integer := 16#228#;


end fb_dmac_blit;

architecture Behavioral of fb_dmac_blit is

	function max(LEFT, RIGHT: INTEGER) return INTEGER is
	begin
  		if LEFT > RIGHT then return LEFT;
  		else return RIGHT;
    	end if;
	end;


	TYPE 		state_type 			IS (
		sIdle						-- waiting for act to be set
	,	sStart					-- dummy cycle before starting (TODO: get rid?)
	,	sLineCalc				-- when drawing lines calculate what needs to happen for/after this pixel
	,	sMemAccA					-- get channel A
	,	sMemAccB					-- get channel B
	,	sMemAccC					-- get channel C data
	,	sMemAccD					-- write channel D data
	,	sMemAccC_min			-- line only - second C exec to move minor axis
	,	sMemAccD_min			-- line only - second D exec to move minor axis
	,	sMemAccE					-- channel E write
	,  sFinish
	);
	TYPE 		state_cha_A 		IS (sMemAccA, sShiftA1, sShiftA2, sShiftA3, sShiftA4, sShiftA5, sShiftA6, sShiftA7);

	-- peripheral interface sigs
	type		per_state_t			is (idle, wait_d_stb, rd);

	signal	r_per_state				: per_state_t;
	signal	r_per_addr				: std_logic_vector(9 downto 0);
	signal 	i_per_D_rd				: std_logic_vector(7 downto 0);
	signal	r_per_D_wr				: std_logic_vector(7 downto 0);
	signal	r_per_D_wr_stb			: std_logic;
	signal 	r_per_ack				: std_logic;

	-- controller cycle sigs
	type		con_state_type is (idle, waitack);
	signal	r_con_state				: con_state_type;


	-- registers
	signal r_blit_state				: state_type;
	signal r_accA_state_cur			: state_cha_A;
	signal i_accA_state_next		: state_cha_A;									-- depending on mode have extra non-memory acessing cycles

	--BLTCON/act

	signal r_BLTCON_act				: std_logic;								-- bit 7	-- write as 1
	signal r_BLTCON_cell				: std_logic;								-- bit 6 channels C,D are in CELL addressing mode
	signal r_BLTCON_mode				: std_logic_vector(1 downto 0);		-- bit 5,4 00 = 1bpp , 01 = 2bpp, 10 = 4bpp, 11 = 8bpp
	signal r_BLTCON_line				: std_logic;								-- bit 3 - when set line drawing is active
	signal r_BLTCON_collision		: std_logic;								-- bit 2 - reset if any non-zero D is detected
	signal r_BLTCON_wrap				: std_logic;								-- bit 1 - wrap C/D addresses

	--BLTCON/CFG
																						-- bit 7 -- write as 0
	signal r_BLTCON_execE			: std_logic;								-- bit 4
	signal r_BLTCON_execD			: std_logic;								-- bit 3
	signal r_BLTCON_execC			: std_logic;								-- bit 2
	signal r_BLTCON_execB			: std_logic;								-- bit 1
	signal r_BLTCON_execA			: std_logic;								-- bit 0
	
	signal r_FUNCGEN					: std_logic_vector(7 downto 0);

	signal r_width						: unsigned(7 downto 0);
	signal r_height					: unsigned(7 downto 0);

	signal r_cha_A_data				: std_logic_vector(7 downto 0);
	signal r_cha_A_data_pre			: std_logic_vector(6 downto 0);
	signal r_cha_B_data				: std_logic_vector(7 downto 0);
	signal r_cha_B_data_pre			: std_logic_vector(6 downto 0);		-- previous data
	signal r_cha_C_data				: std_logic_vector(7 downto 0);
	signal i_cha_D_data				: std_logic_vector(7 downto 0);		-- note not a register
	signal r_cha_A_addr				: std_logic_vector(23 downto 0);
	signal r_cha_B_addr				: std_logic_vector(23 downto 0);
	signal r_cha_C_addr				: std_logic_vector(23 downto 0);
	signal r_cha_D_addr				: std_logic_vector(23 downto 0);
	signal r_cha_D_addr_min			: std_logic_vector(23 downto 0);
	signal r_cha_D_addr_max			: std_logic_vector(23 downto 0);
	signal r_cha_E_addr				: std_logic_vector(23 downto 0);
	signal r_cha_A_stride			: std_logic_vector(MAX(15,G_STRIDE_HIGH) downto 0); -- stride A needs to be at least 16 bit for line slopes
	signal r_cha_B_stride			: std_logic_vector(G_STRIDE_HIGH	downto 0);
	signal r_cha_C_stride			: std_logic_vector(G_STRIDE_HIGH	downto 0);
	signal r_cha_D_stride			: std_logic_vector(G_STRIDE_HIGH	downto 0);
	signal r_shift_A					: std_logic_vector(2 downto 0);
	signal r_shift_B					: std_logic_vector(2 downto 0);
	signal r_mask_first				: std_logic_vector(7 downto 0);
	signal r_mask_last				: std_logic_vector(7 downto 0);

	signal r_row_countdn				: unsigned(7 downto 0);						-- counts down from width(-1) to 0
	signal r_y_count					: unsigned(7 downto 0);
--	signal i_reg_main_first			: boolean;										-- true during the 1st byte access of a row for regs B,C,D
	signal r_cha_A_first				: boolean;										-- true during the 1st byte access of a row for reg A and apply 1st mask	
	signal i_main_last				: boolean;										-- true during the last byte access of a row for regs B,C,D, will trigger a line change
	signal i_cha_A_last				: boolean;										-- true during the last byte access of a row for reg A, will trigger a line change 
	signal i_cha_A_last_mask		: boolean;										-- true during the last byte access of a row for reg A, will apply last mask - this is set _after_ the last mask is loaded
	
	--next state signals
	signal i_state_next				: state_type;
		
	signal i_cha_A_width				: unsigned(7 downto 0); 					-- number of byte in A width (divided down to suite mode)
	signal i_cur_stride				: signed(G_STRIDE_HIGH					 downto 0);
	signal i_cur_addr					: std_logic_vector(15 downto 0);
	signal i_next_addr_blit			: std_logic_vector(15 downto 0);
	signal i_next_addr_ready		: std_logic;
	signal i_cur_mode_cell			: boolean;
	signal i_cur_width				: unsigned(7 downto 0);
	signal i_cur_direction			: blit_addr_direction;
	signal i_cur_wrap					: std_logic;
	signal i_cur_min					: std_logic_vector(15 downto 0);
	signal i_cur_max					: std_logic_vector(15 downto 0);
	signal r_clken_addr_calc_start: std_logic;
	
	signal i_cha_B_data_shifted	: std_logic_vector(7 downto 0);
	signal i_cha_A_data_masked 	: std_logic_vector(7 downto 0);
	signal i_cha_A_data_shifted2	: std_logic_vector(7 downto 0);			-- select pixels based on mode
	signal i_cha_A_data_shifted1	: std_logic_vector(7 downto 0);		-- user specified shift of all mask bits
	signal i_cha_A_data_explode	: std_logic_vector(7 downto 0);			-- 1bpp mask exploded for mode
	
	signal r_reg_line_minor			: std_logic;
	signal r_reg_line_pxmaskcur	: std_logic_vector(7 downto 0);

	function BANK8(x : std_logic_vector(23 downto 16))
	return std_logic_vector is
		variable tmp:std_logic_vector(24 downto 16);
		variable ret:std_logic_vector(7 downto 0);
	begin
		tmp := (24 downto 23 + 1 => '0') & x;
		ret := tmp(23 downto 16);
		return ret;
	end;

begin

	p_addr_mux:process(r_blit_state
		, r_cha_A_addr, r_cha_A_stride
		, r_cha_B_addr, r_cha_B_stride
		, r_cha_C_addr, r_cha_C_stride
		, r_cha_D_addr, r_cha_D_stride
		, r_cha_E_addr
		, r_BLTCON_cell
		, i_cha_A_last, i_main_last
		, i_cha_A_width
		, r_width
		, r_bltcon_line
		, r_bltcon_mode
		, r_cha_a_data
		, r_BLTCON_wrap, r_cha_D_addr_min, r_cha_D_addr_max
		)
		
		impure function fnDirection(
				spr_last:boolean;
				line_major:boolean 
				) 
			return blit_addr_direction is
		variable v_ret:blit_addr_direction;
		begin
			if r_BLTCON_line = '1' then
				v_ret := NONE;

				if line_major then
					case r_BLTCON_mode(0) is
						when '0' =>
							v_ret := PLOT_RIGHT;
						when '1' =>
							v_ret := PLOT_UP;
						when others =>
							v_ret := NONE;
					end case;
				else
					case r_BLTCON_mode is
						when "00" =>
							v_ret := PLOT_DOWN;
						when "01" => 
							v_ret := PLOT_RIGHT;
						when "10" =>
							v_ret := PLOT_UP;
						when "11" =>
							v_ret := PLOT_LEFT;
						when others =>
							v_ret := NONE;
					end case;
				end if;

				if V_ret = PLOT_RIGHT and r_cha_A_data(7) = '0' then					
					v_ret := NONE;
				end if;

				if v_ret = PLOT_LEFT and r_cha_A_data(0) = '0' then
					v_ret := NONE;
				end if;

				return v_ret;
			else
				if spr_last then
					return SPR_WRAP;
				else
					return PLOT_RIGHT;
				end if;
			end if;
				
		end function;
	begin
		case r_blit_state is
			when sMemAccA =>
				i_cur_stride <= signed(r_cha_A_stride(G_STRIDE_HIGH					 downto 0));
				i_cur_addr <= r_cha_A_addr(15 downto 0);
				i_cur_direction <= fnDirection(i_cha_A_last,false);
				i_cur_mode_cell <= false;
				i_cur_width <= i_cha_A_width;
				i_cur_wrap <= '0';
				i_cur_min <= (others => '-');
				i_cur_max <= (others => '-');
			when sMemAccB =>
				i_cur_stride <= signed(r_cha_B_stride);
				i_cur_addr <= r_cha_B_addr(15 downto 0);
				i_cur_mode_cell <= false;
				i_cur_direction <= fnDirection(i_main_last,false);
				i_cur_width <= r_width;
				i_cur_wrap <= '0';
				i_cur_min <= (others => '-');
				i_cur_max <= (others => '-');
			when sMemAccC | sMemAccC_min =>
				i_cur_stride <= signed(r_cha_C_stride);
				i_cur_addr <= r_cha_C_addr(15 downto 0);
				i_cur_mode_cell <= r_BLTCON_cell = '1';
				i_cur_direction <= fnDirection(i_main_last, r_blit_state = sMemAccC);
				i_cur_width <= r_width;
				i_cur_wrap <= r_BLTCON_wrap;
				i_cur_min <= r_cha_D_addr_min(15 downto 0);
				i_cur_max <= r_cha_D_addr_max(15 downto 0);
			when sMemAccD | sMemAccD_min =>
				i_cur_stride <= signed(r_cha_D_stride);
				i_cur_addr <= r_cha_D_addr(15 downto 0);
				i_cur_mode_cell <= r_BLTCON_cell = '1';
				i_cur_direction <= fnDirection(i_main_last, r_blit_state = sMemAccD);
				i_cur_width <= r_width;
				i_cur_wrap <= r_BLTCON_wrap;
				i_cur_min <= r_cha_D_addr_min(15 downto 0);
				i_cur_max <= r_cha_D_addr_max(15 downto 0);
			when sMemAccE =>
				i_cur_stride <= (others => 'X');					-- don't care
				i_cur_addr <= r_cha_E_addr(15 downto 0);
				i_cur_mode_cell <= false;
				i_cur_direction <= CHA_E;
				i_cur_width <= r_width;
				i_cur_wrap <= '0';
				i_cur_min <= (others => '-');
				i_cur_max <= (others => '-');
			when others =>
				i_cur_stride <= (others => '0');
				i_cur_addr <= (others => '0');
				i_cur_mode_cell <= false;
				i_cur_direction <= NONE;
				i_cur_width <= r_width;
				i_cur_wrap <= '0';
				i_cur_min <= (others => '-');
				i_cur_max <= (others => '-');
		end case;
	end process;

	addr_gen: entity work.blit_addr
	generic map (
		ram_A_hi => 15,
		width_hi => 7,
		stride_hi => G_STRIDE_HIGH					
	)
	port map (
		rst => fb_syscon_i.rst,
		clk => fb_syscon_i.clk,
		clk_en_start => r_clken_addr_calc_start,
		mode_cell => i_cur_mode_cell,
		addr_in => i_cur_addr,
		addr_out => i_next_addr_blit,
		addr_ready => i_next_addr_ready,
		bytes_stride => i_cur_stride,
		width => i_cur_width,
		direction => i_cur_direction,
		wrap => i_cur_wrap,
		addr_min => i_cur_min,
		addr_max => i_cur_max
	); 
	

	p_cha_A_shift1: process(r_cha_A_data_pre, r_cha_A_data, r_shift_A)
	begin
		case r_shift_A is
			when "001" =>
				i_cha_A_data_shifted1 <= r_cha_A_data_pre(0)				& r_cha_A_data(7 downto 1);
			when "010" =>
				i_cha_A_data_shifted1 <= r_cha_A_data_pre(1 downto 0)	& r_cha_A_data(7 downto 2);
			when "011" =>
				i_cha_A_data_shifted1 <= r_cha_A_data_pre(2 downto 0)	& r_cha_A_data(7 downto 3);
			when "100" =>
				i_cha_A_data_shifted1 <= r_cha_A_data_pre(3 downto 0)	& r_cha_A_data(7 downto 4);
			when "101" =>
				i_cha_A_data_shifted1 <= r_cha_A_data_pre(4 downto 0)	& r_cha_A_data(7 downto 5);
			when "110" =>
				i_cha_A_data_shifted1 <= r_cha_A_data_pre(5 downto 0)	& r_cha_A_data(7 downto 6);
			when "111" =>
				i_cha_A_data_shifted1 <= r_cha_A_data_pre(6 downto 0)	& r_cha_A_data(7 downto 7);
			when others =>
				i_cha_A_data_shifted1 <= r_cha_A_data;
		end case;
	end process;

	i_cha_A_data_masked <= 	i_cha_A_data_shifted1 and r_mask_last and r_mask_first when i_cha_A_last_mask and r_cha_A_first else
									i_cha_A_data_shifted1 and r_mask_last 						 when i_cha_A_last_mask else
									i_cha_A_data_shifted1 and r_mask_first 					 when r_cha_A_first else
									i_cha_A_data_shifted1 ;

	p_cha_A_shift2: process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			case r_accA_state_cur is
				when sShiftA1 =>
					i_cha_A_data_shifted2 <= i_cha_A_data_masked(6 downto 0) & "-";
				when sShiftA2 =>
					i_cha_A_data_shifted2 <= i_cha_A_data_masked(5 downto 0) & "--";
				when sShiftA3 =>
					i_cha_A_data_shifted2 <= i_cha_A_data_masked(4 downto 0) & "---";
				when sShiftA4 =>
					i_cha_A_data_shifted2 <= i_cha_A_data_masked(3 downto 0) & "----";
				when sShiftA5 =>
					i_cha_A_data_shifted2 <= i_cha_A_data_masked(2 downto 0) & "-----";
				when sShiftA6 =>
					i_cha_A_data_shifted2 <= i_cha_A_data_masked(1 downto 0) & "------";
				when sShiftA7 =>
					i_cha_A_data_shifted2 <= i_cha_A_data_masked(0) 			& "-------";
				when others =>
					i_cha_A_data_shifted2 <= i_cha_A_data_masked;
			end case;
		end if;
	end process;

	p_cha_A_explode: process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			if r_BLTCON_line = '1' then
				i_cha_A_data_explode <= r_reg_line_pxmaskcur;
			else
				case r_BLTCON_mode is
					when "00" =>
						i_cha_A_data_explode <= i_cha_A_data_shifted2;
					when "01" =>
						i_cha_A_data_explode <= i_cha_A_data_shifted2(7 downto 4) & i_cha_A_data_shifted2(7 downto 4);
					when "10" =>
						i_cha_A_data_explode <= i_cha_A_data_shifted2(7 downto 6) & i_cha_A_data_shifted2(7 downto 6) & i_cha_A_data_shifted2(7 downto 6) & i_cha_A_data_shifted2(7 downto 6);
					when "11" =>
						i_cha_A_data_explode <= (others => i_cha_A_data_shifted2(7));
					when others =>
						i_cha_A_data_explode <= i_cha_A_data_shifted2;						
				end case;
			end if;
		end if;
	end process;

	p_cha_A_width: process(r_width, r_BLTCON_mode)
	begin
		case r_BLTCON_mode is
			when "00" =>
				i_cha_A_width <= r_width;
			when "01" =>
				i_cha_A_width <= "0" & r_width(7 downto 1);
			when "10" =>
				i_cha_A_width <= "00" & r_width(7 downto 2);
			when "11" =>
				i_cha_A_width <= "000" & r_width(7 downto 3);
			when others =>
				i_cha_A_width <= r_width;
		end case;		
	end process;

	p_funcgen : process(r_FUNCGEN, i_cha_B_data_shifted, r_cha_C_data, i_cha_A_data_explode)
	variable rb : std_logic;
	variable mtb : std_logic_vector(2 downto 0);
	begin
	
	
		for i in 0 to 7 loop	-- loop over bits in RAM_D
			rb := '0';
			for mt in 0 to 7 loop -- loop over minterms
				mtb := std_logic_vector(to_unsigned(mt,3));
				rb := rb or
				(
					r_FUNCGEN(mt) and
					(i_cha_A_data_explode(i) xor not(mtb(2))) and 
					(i_cha_B_data_shifted(i) xor not(mtb(1))) and
					(r_cha_C_data(i) xor not(mtb(0)))
				);
			end loop;
			i_cha_D_data(i) <= rb;
		end loop;
	end process;
	
	p_b_shift: process (r_cha_B_data, r_cha_B_data_pre, r_BLTCON_mode, r_shift_B)
	variable m0tmp : std_logic_vector(15 downto 0);
	begin
		if r_BLTCON_mode = "00" then
			case r_shift_B is
				when "001" =>
					i_cha_B_data_shifted <= r_cha_B_data_pre(0) & r_cha_B_data(7 downto 1);
				when "010" =>
					i_cha_B_data_shifted <= r_cha_B_data_pre(1 downto 0) & r_cha_B_data(7 downto 2);
				when "011" =>
					i_cha_B_data_shifted <= r_cha_B_data_pre(2 downto 0) & r_cha_B_data(7 downto 3);
				when "100" =>
					i_cha_B_data_shifted <= r_cha_B_data_pre(3 downto 0) & r_cha_B_data(7 downto 4);
				when "101" =>
					i_cha_B_data_shifted <= r_cha_B_data_pre(4 downto 0) & r_cha_B_data(7 downto 5);
				when "110" =>
					i_cha_B_data_shifted <= r_cha_B_data_pre(5 downto 0) & r_cha_B_data(7 downto 6);
				when "111" =>
					i_cha_B_data_shifted <= r_cha_B_data_pre(6 downto 0) & r_cha_B_data(7);
				when others =>
					i_cha_B_data_shifted <= r_cha_B_data;
			end case;
		elsif r_BLTCON_mode = "01" then
			case r_shift_B(1 downto 0) is
				when "01" =>
					i_cha_B_data_shifted <= r_cha_B_data_pre(4) & r_cha_B_data(7 downto 5) & r_cha_B_data_pre(0) & r_cha_B_data(3 downto 1);
				when "10" =>
					i_cha_B_data_shifted <= r_cha_B_data_pre(5 downto 4) & r_cha_B_data(7 downto 6) & r_cha_B_data_pre(1 downto 0) & r_cha_B_data(3 downto 2);
				when "11" =>
					i_cha_B_data_shifted <= r_cha_B_data_pre(6 downto 4) & r_cha_B_data(7) & r_cha_B_data_pre(2 downto 0) & r_cha_B_data(3);
				when others =>
					i_cha_B_data_shifted <= r_cha_B_data;
			end case;
		elsif r_BLTCON_mode = "10" and r_shift_B(0) = '1' then					-- 4 bpp, can only shift 1
				i_cha_B_data_shifted <= 
					r_cha_B_data_pre(6) & r_cha_B_data(7) &
					r_cha_B_data_pre(4) & r_cha_B_data(5) &
					r_cha_B_data_pre(2) & r_cha_B_data(3) &
					r_cha_B_data_pre(0) & r_cha_B_data(1);
		else
				i_cha_B_data_shifted <= r_cha_B_data;
		end if;
	end process;
		
	p_blit_state: process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_blit_state <= sIdle;
			r_clken_addr_calc_start <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			r_clken_addr_calc_start <= '0';
			case r_blit_state is
				when sMemAccA|sMemAccB|sMemAccC|sMemAccE|sMemAccD => --|sMemAccD_min|sMemAccC_min =>
					-- memory access states - wait for controller ack, special case for memaccd when not actually execing
					if (r_con_state = waitack and fb_con_p2c_i.ack = '1') or (r_blit_state = sMemAccD and r_BLTCON_execD = '0') then 
						r_accA_state_cur <= i_accA_state_next;
						r_blit_state <= i_state_next;
						r_clken_addr_calc_start <= '1';
					end if;
				when others =>
					-- others just take one fast cycle
					-- TODO: make this more realistic? an 8MHz cycle?
					-- TODO: check timings / SDC
					if i_next_addr_ready = '1' then
						r_accA_state_cur <= i_accA_state_next;
						r_blit_state <= i_state_next;
						r_clken_addr_calc_start <= '1';
					end if;
			end case;
		end if;
	end process;

	-- note the order of cycles is now A,C,B,D to better interleave cycles to system ram on BBC micro
	p_next_blit_state: process (
		i_main_last, r_y_count, r_blit_state, r_BLTCON_execA
		, r_BLTCON_execB, r_BLTCON_execC, i_accA_state_next
		, r_BLTCON_act, r_BLTCON_execE
		, r_BLTCON_line, r_reg_line_minor
		, r_width
		)
	begin
		case r_blit_state is
			when sStart =>
				if r_BLTCON_line = '1' then
					i_state_next <= sLineCalc;
				elsif r_BLTCON_execA = '1' then
					i_state_next <= sMemAccA;
				elsif r_BLTCON_execC = '1' then
					i_state_next <= sMemAccC;
				elsif r_BLTCON_execB = '1' then
					i_state_next <= sMemAccB;
				elsif r_BLTCON_execE = '1' then
					i_state_next <= sMemAccE;
				else
					i_state_next <= sMemAccD;
				end if;
			when sLineCalc =>
				if r_BLTCON_execC = '1' then
					i_state_next <= sMemAccC;				
				elsif r_BLTCON_execE = '1' then
					i_state_next <= sMemAccE;
				else
					i_state_next <= sMemAccD;
				end if;
			when sMemAccD =>
				if r_BLTCON_line = '1' then
					if r_width(7) = '1' then -- width overflowed!
						i_state_next <= sFinish;
					elsif r_reg_line_minor = '1' then
						if r_BLTCON_execC = '1' then
							i_state_next <= sMemAccC_min;
						else
							i_state_next <= sMemAccD_min;
						end if;
					else
						i_state_next <= sLineCalc;
					end if;
				elsif r_y_count = 0 and i_main_last then
					i_state_next <= sFinish;
				elsif r_BLTCON_execA = '1' and (i_accA_state_next = sMemAccA or i_main_last) then		--TODO: is i_main_last needed here!
					i_state_next <= sMemAccA;
				elsif r_BLTCON_execC = '1' then
					i_state_next <= sMemAccC;
				elsif r_BLTCON_execB = '1' then
					i_state_next <= sMemAccB;
				elsif r_BLTCON_execE = '1' then
					i_state_next <= sMemAccE;
				else
					i_state_next <= sMemAccD;
				end if;	
			when sMemAccD_min =>
				i_state_next <= sLineCalc;
			when sMemAccE =>
				i_state_next <= sMemAccD;
			when sFinish =>
				i_state_next <= sIdle;
			when sIdle =>
				if r_BLTCON_act = '1' then
					i_state_next <= sStart;
				else
					i_state_next <= sIdle;
				end if;
			when sMemAccA =>
				if r_BLTCON_execC = '1' then
					i_state_next <= sMemAccC;
				elsif r_BLTCON_execB = '1' then
					i_state_next <= sMemAccB;
				elsif r_BLTCON_execE = '1' then
					i_state_next <= sMemAccE;
				else
					i_state_next <= sMemAccD;
				end if;
			when sMemAccC =>
				if r_BLTCON_execB = '1' and r_BLTCON_line = '0' then
					i_state_next <= sMemAccB;
				elsif r_BLTCON_execE = '1' then
					i_state_next <= sMemAccE;
				else
					i_state_next <= sMemAccD; 
				end if;
			when sMemAccC_min =>
				i_state_next <= sMemAccD_min;
			when sMemAccB =>
				if r_BLTCON_execE = '1' then
					i_state_next <= sMemAccE;
				else
					i_state_next <= sMemAccD;
				end if;				
			when others =>
				i_state_next <= sFinish;		-- finish
		end case;
		
	end process;

	-- state machine for channel a accesses depending on mode
	p_next_state_A: process(r_accA_state_cur, r_BLTCON_mode, r_blit_state, i_main_last)
	begin
		i_accA_state_next <= r_accA_state_cur;
		if r_blit_state = sMemAccA or r_blit_state = sStart then
			i_accA_state_next <= sMemAccA;
		elsif r_blit_state = sMemAccD then
			if i_main_last then
				i_accA_state_next <= sMemAccA;	-- reset at end of line!
			elsif r_BLTCON_mode = "00" then
				i_accA_state_next <= sMemAccA;
			elsif r_BLTCON_mode = "01" then
				if r_accA_state_cur = sMemAccA then
					i_accA_state_next <= sShiftA4;
				else
					i_accA_state_next <= sMemAccA;
				end if;
			elsif r_BLTCON_mode = "10" then
				if r_accA_state_cur = sMemAccA then
					i_accA_state_next <= sShiftA2;
				elsif r_accA_state_cur = sShiftA2 then
					i_accA_state_next <= sShiftA4;
				elsif r_accA_state_cur = sShiftA4 then
					i_accA_state_next <= sShiftA6;
				else
					i_accA_state_next <= sMemAccA;
				end if;
			else --if r_BLTCON_mode = "11" then
				if r_accA_state_cur = sMemAccA then
					i_accA_state_next <= sShiftA1;
				elsif r_accA_state_cur = sShiftA1 then
					i_accA_state_next <= sShiftA2;
				elsif r_accA_state_cur = sShiftA2 then
					i_accA_state_next <= sShiftA3;
				elsif r_accA_state_cur = sShiftA3 then
					i_accA_state_next <= sShiftA4;
				elsif r_accA_state_cur = sShiftA4 then
					i_accA_state_next <= sShiftA5;
				elsif r_accA_state_cur = sShiftA5 then
					i_accA_state_next <= sShiftA6;
				elsif r_accA_state_cur = sShiftA6 then
					i_accA_state_next <= sShiftA7;
				else
					i_accA_state_next <= sMemAccA;
				end if;
			end if;
		end if;
	end process;

	i_cha_A_last <= 
		(r_row_countdn(7 downto 3) = 0) when r_BLTCON_mode = "11" else
		(r_row_countdn(7 downto 2) = 0) when r_BLTCON_mode = "10" else
		(r_row_countdn(7 downto 1) = 0) when r_BLTCON_mode = "01" else
		(r_row_countdn = 0);

	i_main_last <= 
		(r_row_countdn = 0);

	p_ctl:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_row_countdn <= (others => '0');
			r_y_count <= (others => '0');
			cpu_halt_o <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			if r_blit_state = sStart then
				r_row_countdn <= unsigned(r_width); 				
				r_y_count <= unsigned(r_height);
				r_cha_A_first <= true;
				cpu_halt_o <= '1';
			elsif (fb_con_p2c_i.ack = '1' or r_BLTCON_execD = '0') and r_blit_state = sMemAccD then
				if r_row_countdn = 0 then
					r_row_countdn <= unsigned(r_width);
					r_cha_A_first <= true;
					r_y_count <= r_y_count - 1;
				else					
					r_row_countdn <= r_row_countdn - 1;
					if i_accA_state_next = sMemAccA then -- note this must happen even if not actual memAccA
						r_cha_A_first <= false;
					end if;
				end if;
			elsif r_blit_state = sFinish then
				cpu_halt_o <= '0';		
			elsif (fb_con_p2c_i.ack = '1' and r_blit_state = sMemAccA) or (i_accA_state_next = sMemAccA and r_BLTCON_execA = '0') then
				i_cha_A_last_mask <= i_cha_A_last;	
			end if;
		end if;
	end process;
		
		
	p_regs_wr : process(fb_syscon_i)
	variable v_major_ctr: unsigned(15 downto 0);
	variable v_reg_line_minor: std_logic;
	variable v_err_acc:signed(15 downto 0);
	begin

		if fb_syscon_i.rst = '1' then
			r_cha_A_data <= (others => '0');
			r_cha_A_data_pre <= (others => '0');
			r_cha_B_data <= (others => '0');
			r_cha_B_data_pre <= (others => '0');
			r_cha_C_data <= (others => '0');
			r_cha_A_addr <= (others => '0');
			r_cha_B_addr <= (others => '0');
			r_cha_C_addr <= (others => '0');
			r_cha_D_addr <= (others => '0');
			r_cha_E_addr <= (others => '0');
			r_BLTCON_act <= '0';
			r_BLTCON_execA <= '0';
			r_BLTCON_execB <= '0';
			r_BLTCON_execC <= '0';
			r_BLTCON_execD <= '0';
			r_BLTCON_execE <= '0';
			r_BLTCON_mode <= (others => '0');
			r_BLTCON_cell <= '0';
			r_BLTCON_line <= '0';
			r_BLTCON_collision <= '0';
			r_shift_A <= (others => '0');
			r_shift_B <= (others => '0');
			r_width <= (others => '0');
			r_height <= (others => '0');
			r_FUNCGEN <= (others => '0');		
			r_mask_first <= (others => '0');	
			r_mask_last <= (others => '0');		
			v_reg_line_minor := '0';
		elsif rising_edge(fb_syscon_i.clk) then
						
			if r_blit_state = sFinish then
				r_BLTCON_act <= '0';
			end if;

			--TODO: 8MHz?
			if r_blit_state = sLineCalc and i_next_addr_ready = '1' then --and fb_syscon_i.cpu_clks(FB_CPUCLKINDEX(G_SPEED)).cpu_clken = '1' then
				-- count down major axis
				v_major_ctr := unsigned(unsigned'(r_width & r_height)) - 1;
				r_width <= v_major_ctr(15 downto 8);
				r_height <= v_major_ctr(7 downto 0);

				-- save this as the current pixel's mask
				r_reg_line_pxmaskcur <= r_cha_A_data;

				v_err_acc := signed(r_cha_A_addr(15 downto 0)) - signed(r_cha_A_stride(15 downto 0));
				v_reg_line_minor := '0';
				if (v_err_acc(15) = '1') then
					v_reg_line_minor := '1';
					v_err_acc := v_err_acc + signed(r_cha_B_addr(15 downto 0));
				end if;


				-- rotate the pixel mask if we need to
				if r_BLTCON_mode(0) = '0'	or (v_reg_line_minor = '1' and r_BLTCON_mode(1) = '0') then
					r_cha_A_data <= r_cha_A_data(0) & r_cha_A_data(7 downto 1);	-- roll right
				elsif r_BLTCON_mode = "11" and v_reg_line_minor = '1' then
					r_cha_A_data <= r_cha_A_data(6 downto 0) & r_cha_A_data(7);	-- roll left
				end if;

				r_cha_A_addr(15 downto 0) <= std_logic_vector(v_err_acc);
				r_reg_line_minor <= v_reg_line_minor;

			end if;


			--TODO: 8MHz
			if (r_con_state = waitack and fb_con_p2c_i.ack = '1') 
			or ((r_blit_state = sMemAccC_min or r_blit_state = sMemAccD_min) and
				 i_next_addr_ready = '1'
				) then
				-- update addresses after a memory access
				case r_blit_state is
					when sMemAccA =>
						r_cha_A_addr(15 downto 0) <= i_next_addr_blit;
					when sMemAccB =>
						r_cha_B_addr(15 downto 0) <= i_next_addr_blit;
					when sMemAccC | sMemAccC_min =>
						r_cha_C_addr(15 downto 0) <= i_next_addr_blit;
					when sMemAccD | sMemAccD_min => 
						r_cha_D_addr(15 downto 0) <= i_next_addr_blit;
					when sMemAccE => 
						r_cha_E_addr(15 downto 0) <= i_next_addr_blit;
					when others => null;
				end case;

				-- update previous/next data after a memory access
				case r_blit_state is
					when sMemAccA =>
						r_cha_A_data_pre <= r_cha_A_data(6 downto 0);			
						r_cha_A_data <= fb_con_p2c_i.D_rd;
					when sMemAccB =>
						r_cha_B_data_pre <= r_cha_B_data(6 downto 0);			
						r_cha_B_data <= fb_con_p2c_i.D_rd;
					when sMemAccC | sMemAccC_min =>
						r_cha_C_data <= fb_con_p2c_i.D_rd;
					when others => null;
				end case;
			end if;
			
			if (r_blit_state = sMemAccD) and (or_reduce(i_cha_D_data) /= '0') then
				r_BLTCON_collision <= '0';
			end if;

			if r_per_D_wr_stb = '1' then -- register write from peripheral port
				case to_integer(unsigned(r_per_addr)) is
					when A_BLTCON | A_N_BLTCON =>
						if r_per_d_wr(7) = '1' then
							r_BLTCON_act <= '1';
							r_BLTCON_cell <= r_per_D_wr(6);
							r_BLTCON_mode <= r_per_D_wr(5 downto 4);
							r_BLTCON_line <= r_per_D_wr(3);
							r_BLTCON_collision <= r_per_D_wr(2);
							r_BLTCON_wrap <= r_per_D_wr(1);
						else
							r_BLTCON_execA <= r_per_D_wr(0);
							r_BLTCON_execB <= r_per_D_wr(1);
							r_BLTCON_execC <= r_per_D_wr(2);
							r_BLTCON_execD <= r_per_D_wr(3);
							r_BLTCON_execE <= r_per_D_wr(4);
						end if;
					when A_FUNCGEN | A_N_FUNCGEN =>
						r_FUNCGEN <= r_per_d_wr;
					when A_WIDTH | A_N_WIDTH =>
						r_width(7 downto 0) <= unsigned(r_per_d_wr);
					when A_HEIGHT | A_N_HEIGHT =>
						r_height(7 downto 0) <= unsigned(r_per_d_wr);
					when A_SHIFT => -- TODO: maybe split to two addresses to make calcs easier?
						r_shift_A <= r_per_d_wr(2 downto 0);
						r_shift_B <= r_per_d_wr(6 downto 4);
					when A_N_SHIFT_A =>
						r_shift_A <= r_per_d_wr(2 downto 0);
						r_shift_B <= r_per_d_wr(2 downto 0);				-- convenience poke
					when A_N_SHIFT_B => 
						r_shift_B <= r_per_d_wr(2 downto 0);
					when A_MASK_FIRST | A_N_MASK_FIRST=>
						r_mask_first <= r_per_d_wr;
					when A_MASK_LAST | A_N_MASK_LAST=>
						r_mask_last <= r_per_d_wr;
					when A_DATA_A | A_N_DATA_A=>
						r_cha_A_data_pre <= r_per_d_wr(6 downto 0);
						r_cha_A_data <= r_per_d_wr;

					when A_ADDR_A + 0 | A_N_ADDR_A + 2 =>
						r_cha_A_addr(23 downto 16) <= r_per_d_wr;
					when A_ADDR_A + 1 | A_N_ADDR_A + 1 =>
						r_cha_A_addr(15 downto 8) <= r_per_d_wr;			
					when A_ADDR_A + 2 | A_N_ADDR_A + 0 =>
						r_cha_A_addr(7 downto 0) <= r_per_d_wr;			
					when A_DATA_B | A_N_DATA_B=>
						r_cha_B_data_pre <= r_per_d_wr(6 downto 0);
						r_cha_B_data <= r_per_d_wr;
					when A_ADDR_B + 0 | A_N_ADDR_B + 2 =>
						r_cha_B_addr(23 downto 16) <= r_per_d_wr;
					when A_ADDR_B + 1 | A_N_ADDR_B + 1 =>
						r_cha_B_addr(15 downto 8) <= r_per_d_wr;			
					when A_ADDR_B + 2 | A_N_ADDR_B + 0 =>
						r_cha_B_addr(7 downto 0) <= r_per_d_wr;	
					when A_N_DATA_C =>
						r_cha_C_data <= r_per_d_wr;
					when A_ADDR_C + 0 =>
						r_cha_C_addr(23 downto 16) <= r_per_d_wr;
					when A_ADDR_C + 1 =>
						r_cha_C_addr(15 downto 8) <= r_per_d_wr;			
					when A_ADDR_C + 2 =>
						r_cha_C_addr(7 downto 0) <= r_per_d_wr;			

					when A_N_ADDR_C + 0 =>
						r_cha_C_addr(7 downto 0) <= r_per_d_wr;			
						r_cha_D_addr(7 downto 0) <= r_per_d_wr;			-- convenience
					when A_N_ADDR_C + 1 =>
						r_cha_C_addr(15 downto 8) <= r_per_d_wr;			
						r_cha_D_addr(15 downto 8) <= r_per_d_wr;			-- convenience
					when A_N_ADDR_C + 2 =>
						r_cha_C_addr(23 downto 16) <= r_per_d_wr;			
						r_cha_D_addr(23 downto 16) <= r_per_d_wr;			-- convenience

					when A_ADDR_D + 0 | A_N_ADDR_D + 2 =>
						r_cha_D_addr(23 downto 16) <= r_per_d_wr;
					when A_ADDR_D + 1 | A_N_ADDR_D + 1 =>
						r_cha_D_addr(15 downto 8) <= r_per_d_wr;			
					when A_ADDR_D + 2 | A_N_ADDR_D + 0 =>
						r_cha_D_addr(7 downto 0) <= r_per_d_wr;			
					when A_ADDR_E + 0 | A_N_ADDR_E + 2 =>
						r_cha_E_addr(23 downto 16) <= r_per_d_wr;
					when A_ADDR_E + 1 | A_N_ADDR_E + 1 =>
						r_cha_E_addr(15 downto 8) <= r_per_d_wr;			
					when A_ADDR_E + 2 | A_N_ADDR_E + 0 =>
						r_cha_E_addr(7 downto 0) <= r_per_d_wr;			
					when A_STRIDE_A + 0| A_N_STRIDE_A + 1 =>
						r_cha_A_stride(15 downto 8) <= r_per_d_wr; -- note 16 bits for line mode
					when A_STRIDE_A + 1 | A_N_STRIDE_A + 0 =>
						r_cha_A_stride(7 downto 0) <= r_per_d_wr;
					when A_STRIDE_B + 0 | A_N_STRIDE_B + 1 =>
						r_cha_B_stride(G_STRIDE_HIGH downto 8) <= r_per_d_wr(G_STRIDE_HIGH - 8 downto 0);
					when A_STRIDE_B + 1 | A_N_STRIDE_B + 0 =>
						r_cha_B_stride(7 downto 0) <= r_per_d_wr;
					when A_STRIDE_C + 0 =>
						r_cha_C_stride(G_STRIDE_HIGH downto 8) <= r_per_d_wr(G_STRIDE_HIGH - 8 downto 0);
					when A_STRIDE_C + 1  =>
						r_cha_C_stride(7 downto 0) <= r_per_d_wr;

					when A_N_STRIDE_C + 0 =>
						r_cha_C_stride(7 downto 0) <= r_per_d_wr;
						r_cha_D_stride(7 downto 0) <= r_per_d_wr; -- convenience
					when A_N_STRIDE_C + 1  =>
						r_cha_C_stride(G_STRIDE_HIGH downto 8) <= r_per_d_wr(G_STRIDE_HIGH - 8 downto 0);
						r_cha_D_stride(G_STRIDE_HIGH downto 8) <= r_per_d_wr(G_STRIDE_HIGH - 8 downto 0); -- convenience

					when A_STRIDE_D + 0 | A_N_STRIDE_D + 1 =>
						r_cha_D_stride(G_STRIDE_HIGH downto 8) <= r_per_d_wr(G_STRIDE_HIGH - 8 downto 0);
					when A_STRIDE_D + 1 | A_N_STRIDE_D + 0 =>
						r_cha_D_stride(7 downto 0) <= r_per_d_wr;

					when A_ADDR_D_MIN + 0 | A_N_ADDR_D_MIN + 2 => 
						r_cha_D_addr_min(23 downto 16) <= r_per_d_wr;
					when A_ADDR_D_MIN + 1 | A_N_ADDR_D_MIN + 1 => 
						r_cha_D_addr_min(15 downto 8) <= r_per_d_wr;
					when A_ADDR_D_MIN + 2 | A_N_ADDR_D_MIN + 0 => 
						r_cha_D_addr_min(7 downto 0) <= r_per_d_wr;

					when A_ADDR_D_MAX + 0 | A_N_ADDR_D_MAX + 2 => 
						r_cha_D_addr_max(23 downto 16) <= r_per_d_wr;
					when A_ADDR_D_MAX + 1 | A_N_ADDR_D_MAX + 1 => 
						r_cha_D_addr_max(15 downto 8) <= r_per_d_wr;
					when A_ADDR_D_MAX + 2 | A_N_ADDR_D_MAX + 0 => 
						r_cha_D_addr_max(7 downto 0) <= r_per_d_wr;

					when others => null;
				end case;
			end if;
		end if;
	end process;


	p_regs_rd: process(r_per_addr, r_BLTCON_act,
		r_FUNCGEN, 
		r_mask_first, r_mask_last,
		r_width, r_height, r_shift_A, r_shift_B,
		r_cha_A_addr, r_cha_A_data, r_cha_A_stride,
		r_cha_B_addr, r_cha_B_data, r_cha_B_stride,
		r_cha_C_addr, r_cha_C_stride,
		r_cha_D_addr, r_cha_D_stride,
		r_cha_E_addr,
		r_BLTCON_cell,
		r_BLTCON_mode,
		r_BLTCON_line,
		r_BLTCON_collision,
		r_BLTCON_wrap, r_cha_D_addr_min, r_cha_D_addr_max
		)
	begin
		case to_integer(unsigned(r_per_addr)) is
			when A_BLTCON | A_N_BLTCON =>
				i_per_D_rd <= r_BLTCON_act 
							& r_BLTCON_cell
							& r_BLTCON_mode
							& r_BLTCON_line
							& r_BLTCON_collision
							& r_BLTCON_wrap
							& "0";
			when A_FUNCGEN | A_N_FUNCGEN =>
				i_per_D_rd <= r_FUNCGEN;
			when A_WIDTH | A_N_WIDTH =>
				i_per_D_rd <= std_logic_vector(r_width);
			when A_HEIGHT | A_N_HEIGHT =>			
				i_per_D_rd <= std_logic_vector(r_height);
			when A_SHIFT => 
				i_per_D_rd <= "0" & r_shift_B & "0" & r_shift_A;
			when A_N_SHIFT_A => 
				i_per_D_rd <= "00000" & r_shift_A;
			when A_N_SHIFT_B => 
				i_per_D_rd <= "00000" & r_shift_B;
			when A_MASK_FIRST | A_N_MASK_FIRST =>
				i_per_D_rd <= r_mask_first;
			when A_MASK_LAST | A_N_MASK_LAST =>
				i_per_D_rd <= r_mask_last;
			when A_DATA_A | A_N_DATA_A =>
				i_per_D_rd <= r_cha_A_data;
			when A_ADDR_A + 0 | A_N_ADDR_A + 2 =>				
				i_per_D_rd <= BANK8(r_cha_A_addr(23 downto 16));
			when A_ADDR_A + 1 | A_N_ADDR_A + 1 =>
				i_per_D_rd <= r_cha_A_addr(15 downto 8);
			when A_ADDR_A + 2 | A_N_ADDR_A + 0 =>
				i_per_D_rd <= r_cha_A_addr(7 downto 0);
			when A_DATA_B | A_N_DATA_B =>
				i_per_D_rd <= r_cha_B_data;
			when A_ADDR_B + 0 | A_N_ADDR_B + 2 =>
				i_per_D_rd <= BANK8(r_cha_B_addr(23 downto 16));
			when A_ADDR_B + 1 | A_N_ADDR_B + 1 =>
				i_per_D_rd <= r_cha_B_addr(15 downto 8);
			when A_ADDR_B + 2 | A_N_ADDR_B + 0 =>
				i_per_D_rd <= r_cha_B_addr(7 downto 0);
			when A_N_DATA_C =>
				i_per_D_rd <= r_cha_C_data;
			when A_ADDR_C + 0 | A_N_ADDR_C + 2 =>
				i_per_D_rd <= BANK8(r_cha_C_addr(23 downto 16));
			when A_ADDR_C + 1 | A_N_ADDR_C + 1 =>
				i_per_D_rd <= r_cha_C_addr(15 downto 8);
			when A_ADDR_C + 2 | A_N_ADDR_C + 0 =>
				i_per_D_rd <= r_cha_C_addr(7 downto 0);
			when A_ADDR_D + 0 | A_N_ADDR_D + 2 =>
				i_per_D_rd <= BANK8(r_cha_D_addr(23 downto 16));
			when A_ADDR_D + 1 | A_N_ADDR_D + 1 =>
				i_per_D_rd <= r_cha_D_addr(15 downto 8);
			when A_ADDR_D + 2 | A_N_ADDR_D + 0 =>
				i_per_D_rd <= r_cha_D_addr(7 downto 0);
			when A_ADDR_E + 0 | A_N_ADDR_E + 2 =>
				i_per_D_rd <= BANK8(r_cha_E_addr(23 downto 16));
			when A_ADDR_E + 1 | A_N_ADDR_E + 1 =>
				i_per_D_rd <= r_cha_E_addr(15 downto 8);
			when A_ADDR_E + 2 | A_N_ADDR_E + 0 =>
				i_per_D_rd <= r_cha_E_addr(7 downto 0);
			when A_STRIDE_A + 0 | A_N_STRIDE_A + 1 =>
				i_per_D_rd <= std_logic_vector(resize(signed(r_cha_A_stride(15 downto 8)), 8));
			when A_STRIDE_A + 1 | A_N_STRIDE_A + 0 =>
				i_per_D_rd <= r_cha_A_stride(7 downto 0);
			when A_STRIDE_B + 0 | A_N_STRIDE_B + 1 =>
				i_per_D_rd <= std_logic_vector(resize(signed(r_cha_B_stride(G_STRIDE_HIGH					 downto 8)), 8));
			when A_STRIDE_B + 1 | A_N_STRIDE_B + 0 =>
				i_per_D_rd <= r_cha_B_stride(7 downto 0);
			when A_STRIDE_C + 0 | A_N_STRIDE_C + 1 =>
				i_per_D_rd <= std_logic_vector(resize(signed(r_cha_C_stride(G_STRIDE_HIGH					 downto 8)), 8));
			when A_STRIDE_C + 1 | A_N_STRIDE_C + 0 =>
				i_per_D_rd <= r_cha_C_stride(7 downto 0);
			when A_STRIDE_D + 0 | A_N_STRIDE_D + 1 =>
				i_per_D_rd <= std_logic_vector(resize(signed(r_cha_D_stride(G_STRIDE_HIGH					 downto 8)), 8));
			when A_STRIDE_D + 1 | A_N_STRIDE_D + 0 =>
				i_per_D_rd <= r_cha_D_stride(7 downto 0);		

			when A_ADDR_D_MIN + 0 | A_N_ADDR_D_MIN + 2 =>
				i_per_D_rd <= BANK8(r_cha_D_addr_min(23 downto 16));
			when A_ADDR_D_MIN + 1 | A_N_ADDR_D_MIN + 1 =>
				i_per_D_rd <= r_cha_D_addr_min(15 downto 8);
			when A_ADDR_D_MIN + 2 | A_N_ADDR_D_MIN + 0 =>
				i_per_D_rd <= r_cha_D_addr_min(7 downto 0);

			when A_ADDR_D_MAX + 0 | A_N_ADDR_D_MAX + 2 =>
				i_per_D_rd <= BANK8(r_cha_D_addr_max(23 downto 16));
			when A_ADDR_D_MAX + 1 | A_N_ADDR_D_MAX + 1 =>
				i_per_D_rd <= r_cha_D_addr_max(15 downto 8);
			when A_ADDR_D_MAX + 2 | A_N_ADDR_D_MAX + 0 =>
				i_per_D_rd <= r_cha_D_addr_max(7 downto 0);

			when others =>
				i_per_D_rd <= (others => '1');
		end case;
	end process;

	p_con_state: process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_con_state <= idle;
			fb_con_c2p_o <= (
				cyc => '0',
				we => '0',
				A => (others => '-'),
				A_stb => '0',
				D_wr => (others => '-'),
				D_wr_stb => '0',
				rdy_ctdn => RDY_CTDN_MIN
				);
		else
			if rising_edge(fb_syscon_i.clk) then
				case r_con_state is
					when idle => 
						if blit_halt_i = '0' then
						   case r_blit_state is
						   	when sMemAccA =>
									r_con_state <= waitack;
									fb_con_c2p_o <= (
										cyc => '1',
										we => '0',
										A => std_logic_vector(r_cha_A_addr),
										A_stb => '1',
										D_wr => (others => '-'),
										D_wr_stb => '0',
										rdy_ctdn => RDY_CTDN_MIN
										);
						   	when sMemAccB =>
									r_con_state <= waitack;
									fb_con_c2p_o <= (
										cyc => '1',
										we => '0',
										A => std_logic_vector(r_cha_B_addr),
										A_stb => '1',
										D_wr => (others => '-'),
										D_wr_stb => '0',
										rdy_ctdn => RDY_CTDN_MIN
										);
						   	when sMemAccC => -- |sMemAccC_min =>
									r_con_state <= waitack;
									fb_con_c2p_o <= (
										cyc => '1',
										we => '0',
										A => std_logic_vector(r_cha_C_addr),
										A_stb => '1',
										D_wr => (others => '-'),
										D_wr_stb => '0',
										rdy_ctdn => RDY_CTDN_MIN
										);
						   	when sMemAccD => --|sMemAccD_min =>
						   		if r_BLTCON_execD = '1' then
										r_con_state <= waitack;
										fb_con_c2p_o <= (
											cyc => '1',
											we => '1',
											A => std_logic_vector(r_cha_D_addr),
											A_stb => '1',
											D_wr => i_cha_D_data,
											D_wr_stb => '1',
											rdy_ctdn => RDY_CTDN_MIN
											);
									end if;
						   	when sMemAccE =>
									r_con_state <= waitack;
									fb_con_c2p_o <= (
										cyc => '1',
										we => '1',
										A => std_logic_vector(r_cha_E_addr),
										A_stb => '1',
										D_wr => r_cha_C_data,
										D_wr_stb => '1',
										rdy_ctdn => RDY_CTDN_MIN
										);
								when others => null;
							end case;
						end if;
					when waitack =>
						if fb_con_p2c_i.stall = '0' then
							fb_con_c2p_o.a_stb <= '0';
							fb_con_c2p_o.d_wr_stb <= '0';
						end if;
					when others => 
						r_con_state <= idle;
						fb_con_c2p_o <= (
							cyc => '0',
							we => '0',
							A => (others => '-'),
							A_stb => '0',
							D_wr => (others => '-'),
							D_wr_stb => '0',
							rdy_ctdn => RDY_CTDN_MIN
							);
				end case;

				if fb_con_p2c_i.ack = '1' then
					r_con_state <= idle;
					fb_con_c2p_o.cyc <= '0';
				end if;


			end if;
		end if;
	end process;


	p_per_state:process(fb_syscon_i, fb_per_c2p_i)
	variable v_write:boolean;
	begin
		if fb_syscon_i.rst = '1' then
			r_per_state <= idle;
			r_per_ack <= '0';
			r_per_addr <= (others => '0');
			r_per_D_wr <= (others => '0');
			r_per_D_wr_stb <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
			r_per_ack <= '0';
			r_per_D_wr_stb <= '0';
			v_write := false;
			case r_per_state is
				when idle =>
					if fb_per_c2p_i.cyc = '1' and fb_per_c2p_i.a_stb = '1' then
						r_per_addr <= fb_per_c2p_i.A(9) & '0' & fb_per_c2p_i.A(7 downto 0);
						if fb_per_c2p_i.we = '0' then
							r_per_state <= rd;
						else
							v_write := true;
						end if;
					end if;
				when wait_d_stb =>
					v_write := true;
				when rd =>
					fb_per_p2c_o.D_rd <= i_per_D_rd;
					if fb_per_c2p_i.we = '0' or fb_per_c2p_i.D_wr_stb = '1' then
						r_per_state <= idle;
						r_per_ack <= '1';
					end if;
				when others => null;
			end case;

			if v_write then
				if fb_per_c2p_i.D_wr_stb = '1' then
					r_per_D_wr <= fb_per_c2p_i.D_wr;
					r_per_D_wr_stb <= '1';
					r_per_state <= idle;
					r_per_ack <= '1';
				else
					r_per_state <= wait_d_stb;
				end if;
			end if;

			if fb_per_c2p_i.cyc = '0' then
				r_per_state <= idle;
			end if;

		end if;
	end process;

	fb_per_p2c_o.rdy <= r_per_ack;
	fb_per_p2c_o.ack <= r_per_ack;
	fb_per_p2c_o.stall <= '0' when r_per_state = idle else '1';

end Behavioral;



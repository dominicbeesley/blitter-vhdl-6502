-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	6/10/2023
-- Design Name: 
-- Module Name:    	vidmem_sequencer
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Control accesses to video memory
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.common.all;
use work.fishbone.all;
use work.sprites_pack.all;

entity vidmem_sequencer is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		G_N_SPRITES							: natural
	);
	port(

		clk_i									: in	std_logic;
		rst_i									: in  std_logic;
		
		-- motherboard signals in
		scroll_latch_c_i					: in		std_logic_vector(1 downto 0);
		ttxmode_i							: in		std_logic;

		-- CRTC input signals

		crtc_mem_clken_i					: in 	std_logic;
		crtc_MA_i							: in 	std_logic_vector(13 downto 0);
		crtc_RA_i							: in 	std_logic_vector(4 downto 0);

		-- SEQ registers in
		SEQ_alphamode_i					: in	std_logic;
		SEQ_font_addr_A					: in	std_logic_vector(7 downto 0);

		-- sprite registers in
		SEQ_SPR_DATA_req_i				: in  std_logic;
		SEQ_SPR_DATAPTR_A_i				: in	t_spr_addr_array(G_N_SPRITES-1 downto 0);
		SEQ_SPR_DATAPTR_act_i			: in  std_logic_vector(G_N_SPRITES-1 downto 0);

		-- sprite registers out
		SEQ_SPR_wren_o						: out	std_logic;
		SEQ_SPR_A_o							: out unsigned(numbits(G_N_SPRITES) + 3 downto 0);
		SEQ_SPR_D_o							: out std_logic_vector(7 downto 0);

		-- RAM input/output

		RAM_D_i								: in	std_logic_vector(7 downto 0);
		RAM_A_o								: out	std_logic_vector(16 downto 0);

		-- vidproc output data
		RAMD_PLANE0_o						: out	std_logic_vector(7 downto 0);
		RAMD_PLANE1_o						: out	std_logic_vector(7 downto 0)

	);
end vidmem_sequencer;


architecture rtl of vidmem_sequencer is

	signal	r_RAM_A			: std_logic_vector(16 downto 0);

	signal 	i_aa				: unsigned(3 downto 0);

	signal 	i_RAMA_PLANE0	: std_logic_vector(16 downto 0);
	signal 	r_RAMD_PLANE0	: std_logic_vector(7 downto 0);
	signal 	i_RAMA_PLANE1	: std_logic_vector(16 downto 0);
	signal 	r_RAMD_PLANE1	: std_logic_vector(7 downto 0);
	signal 	i_RAMA_FONT		: std_logic_vector(16 downto 0);
	signal 	r_RAMD_FONT		: std_logic_vector(7 downto 0);

	signal 	r_SEQ_SPR_wren				: std_logic;
	signal 	r_SEQ_SPR_A					: unsigned(numbits(G_N_SPRITES) + 3 downto 0);


	signal 	r_SPR_DATA_ack	: std_logic;
	signal   r_main_seq:unsigned(3 downto 0);
	signal   r_spr_seq:unsigned(1 downto 0);
	signal   r_spr_ix :unsigned(numbits(G_N_SPRITES) - 1 downto 0);
	signal   r_doing_spr:boolean;

begin
--====================================================================
-- Screen address calculations and other "sequencer stuff" - TODO: move to separate mo
--====================================================================

-- TODO: improve teletext detect (out from vidproc or keep MA13?)
-- TODO: mode 15/80 cols teletext

-- TODO: remove register and have go direct via multiplexer
	RAM_A_o 					<= r_RAM_A;
	RAMD_PLANE0_o 			<= 	r_RAMD_FONT when SEQ_alphamode_i = '1' else
										r_RAMD_PLANE0;

	SEQ_SPR_wren_o 		<= r_SEQ_SPR_wren;
	SEQ_SPR_A_o				<= r_SEQ_SPR_A;
	SEQ_SPR_D_o				<= r_RAMD_PLANE0;

	-- Address translation logic for calculation of display address
	i_aa <= unsigned(crtc_ma_i(11 downto 8)) when crtc_ma_i(12) = '0' else
			  unsigned(crtc_ma_i(11 downto 8)) + 8 when scroll_latch_c_i = "00" else
			  unsigned(crtc_ma_i(11 downto 8)) + 12 when scroll_latch_c_i = "01" else
			  unsigned(crtc_ma_i(11 downto 8)) + 6 when scroll_latch_c_i = "10" else
			  unsigned(crtc_ma_i(11 downto 8)) + 11;

	i_RAMA_PLANE0 <= 	"0011111" & crtc_ma_i(9 downto 0) when ttxmode_i = '1' else
							"00111" & crtc_ma_i(10 downto 0) & '0' when SEQ_alphamode_i = '1' else
							"00" & std_logic_vector(i_aa(3 downto 0)) & crtc_ma_i(7 downto 0) & crtc_ra_i(2 downto 0);			

	i_RAMA_PLANE1 <= 	(others => '1') when ttxmode_i = '1' else
							"00111" & crtc_ma_i(10 downto 0) & '1' when SEQ_alphamode_i = '1' else
							(others => '1');


	-- in alpha mode the address of the next set of pixels looked up from font loaded at 3000
	i_RAMA_FONT <= SEQ_font_addr_A(4 downto 0) & r_RAMD_PLANE0 & crtc_ra_i(3 downto 0);


	p_seq:process(clk_i)
	begin
		if rst_i = '1' then
			r_main_seq 		<= (others => '0');
			r_SPR_DATA_ack <= '0';
			r_spr_seq 		<= (others => '0');
			r_spr_ix  		<= (others => '0');
		elsif rising_edge(clk_i) then

			r_SEQ_SPR_wren <= '0';
			case to_integer(r_main_seq) is
				when 1 =>
					if r_SPR_DATA_ack /= SEQ_SPR_DATA_req_i then				
						r_ram_A <= SEQ_SPR_DATAPTR_A_i(to_integer(r_spr_ix))(16 downto 0);
						r_doing_spr <= true;
					else
						r_ram_A <= i_RAMA_PLANE0;
						r_doing_spr <= false;
					end if;				
				when 2 =>
					r_SEQ_SPR_A <= r_spr_ix & "00" & r_spr_seq;
				when 4 =>
					r_RAMD_PLANE0 <= RAM_D_i;
					r_RAM_A <= i_RAMA_PLANE1;
					if r_doing_spr then
						if SEQ_SPR_DATAPTR_act_i(to_integer(r_spr_ix)) = '1' then
							r_SEQ_SPR_wren <= '1';
						end if;
					end if;
				when 5 =>
					if r_doing_spr then
						if r_spr_seq = 3 then
							if to_integer(r_spr_ix) = G_N_SPRITES-1  then
								r_SPR_DATA_ack <= SEQ_SPR_DATA_req_i;
								r_spr_ix <= (others => '0');
							else
								r_spr_ix <= r_spr_ix + 1;
							end if;
						end if;
						r_spr_seq <= r_spr_seq + 1;
					end if;
				when 6 =>
					r_RAM_A <= i_RAMA_FONT;
					r_RAMD_PLANE1 <= RAM_D_i;
				when 8 =>
					r_RAMD_FONT <= RAM_D_i;
				when others =>
					null;
			end case;

			if crtc_mem_clken_i = '1' then
				r_main_seq <= (others => '0');
			elsif r_main_seq /= "1111" then
				r_main_seq <= r_main_seq + 1;
			end if;

		end if;					
	end process;


end rtl;
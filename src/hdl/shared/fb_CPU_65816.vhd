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

-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	9/8/2020
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - 65816
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.board_config_pack.all;
use work.fb_cpu_pack.all;
use work.fb_cpu_exp_pack.all;

entity fb_cpu_65816 is
		generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: positive
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;				-- 1 when this cpu is the current one
		fb_syscon_i								: in	fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i;

		-- CPU expansion signals
		wrap_exp_o								: out t_cpu_wrap_exp_o;
		wrap_exp_i								: in t_cpu_wrap_exp_i;

		-- 65816 specific signals

		boot_65816_i							: in		std_logic;

		debug_vma_o								: out		std_logic

);
end fb_cpu_65816;

architecture rtl of fb_cpu_65816 is
	signal r_prev_A0			: std_logic;

	signal r_PHI0				: std_logic;
	signal r_PHI0_dly			: std_logic_vector(3 downto 0);

	type t_state is (
		phi1,
		phi2
		);

	signal r_state				: t_state;

	subtype t_substate is unsigned(4 downto 0); -- divide down by a max of 64/2

	signal r_substate			: t_substate := (others => '1');	
	signal r_rdy_ctup			: t_substate := (others => '1'); -- this counts up since data was ready


	--TODO: sort this all out to be more intuitive 
	--TODO: test phi0 to phi2 skew during boot and adjust?

	constant SUBSTATEMAX_8	: t_substate := to_unsigned(7, t_substate'length);

	-- address latch state:
	constant SUBSTATE_A_8	: t_substate := SUBSTATEMAX_8 - to_unsigned(6, t_substate'length);

	constant SUBSTATE_D_8	: t_substate := to_unsigned(1, t_substate'length);

	constant SUBSTATE_D_WR_8: t_substate := SUBSTATEMAX_8 - to_unsigned(5, t_substate'length);


	signal r_cpu_hlt			: std_logic;	-- need to register this at the start of the cycle following
														-- halt being asserted to stop that cycle from starting
	signal r_cpu_res			: std_logic;

	signal r_boot_65816_dly	: std_logic_vector(2 downto 0) := (others => '1');
	signal i_boot				: std_logic;
															-- this should be before A/CYC

	signal i_vma				: std_logic;		-- '1' if VPA or VDA
	signal r_a_stb				: std_logic;		-- '1' for 1 cycle at start of a controller cycle
	signal r_D_WR_stb			: std_logic;
	signal r_inihib			: std_logic;		-- '1' throughout an inhibited cycle

	signal r_log_A				: std_logic_vector(23 downto 0);

	signal i_ack				: std_logic;

	signal r_fbreset_prev	: std_logic := '0';

	signal r_throttle			: std_logic;
	signal r_had_sys_phi2 	: std_logic;


	-- port b
	signal i_CPUSKT_BE_o		: std_logic;		-- note only for the WDC 's' parts
	signal i_CPUSKT_PHI0_o	: std_logic;
	signal i_CPUSKT_RDY_o	: std_logic;
	signal i_CPUSKT_nIRQ_o	: std_logic;
	signal i_CPUSKT_nNMI_o	: std_logic;
	signal i_CPUSKT_nRES_o	: std_logic;
	signal i_CPU_D_RnW_o		: std_logic;

	-- port d

	signal i_CPUSKT_6E_i		: std_logic;
	signal i_CPUSKT_RnW_i	: std_logic;
	signal i_CPUSKT_VDA_i	: std_logic;
	signal i_CPUSKT_VPA_i	: std_logic;
	signal i_CPUSKT_VPB_i	: std_logic;

	signal i_CPUSKT_D_i		: std_logic_vector(7 downto 0);
	signal i_CPUSKT_A_i		: std_logic_vector(15 downto 0);



begin

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity error;

	e_pinmap:entity work.fb_cpu_65816_exp_pins
	port map(
		-- cpu wrapper signals
		wrap_exp_o => wrap_exp_o,
		wrap_exp_i => wrap_exp_i,

		-- local 65816 wrapper signals to/from CPU expansion port 

		CPUSKT_BE_i			=> i_CPUSKT_BE_o,
		CPUSKT_PHI0_i		=> i_CPUSKT_PHI0_o,
		CPUSKT_RDY_i		=> i_CPUSKT_RDY_o,
		CPUSKT_nIRQ_i		=> i_CPUSKT_nIRQ_o,
		CPUSKT_nNMI_i		=> i_CPUSKT_nNMI_o,
		CPUSKT_nRES_i		=> i_CPUSKT_nRES_o,

		CPUSKT_6E_o			=>	i_CPUSKT_6E_i,
		CPUSKT_RnW_o		=> i_CPUSKT_RnW_i,
		CPUSKT_VDA_o		=> i_CPUSKT_VDA_i,
		CPUSKT_VPA_o		=> i_CPUSKT_VPA_i,
		CPUSKT_VPB_o		=> i_CPUSKT_VPB_i,

		-- shared per CPU signals
		CPU_D_RnW_i			=> i_CPU_D_RnW_o,

		CPUSKT_A_o			=> i_CPUSKT_A_i,
		CPUSKT_D_o			=> i_CPUSKT_D_i

	);



	debug_vma_o <= i_vma;



	i_CPU_D_RnW_o <= 	'1' 	when i_CPUSKT_RnW_i = '1' 					-- we need to make sure that
										and r_PHI0_dly(r_PHI0_dly'high) = '1' 	-- read data into the CPU from the
										and r_PHI0_dly(0) = '1' 					-- board doesn't crash into the bank
										else												-- bank address so hold is short
																							-- and setup late														
							'0';

	wrap_o.A_log 			<= r_log_A;
	wrap_o.cyc	 			<= ( 0 => r_a_stb, others => '0');
	wrap_o.we	  			<= not(i_CPUSKT_RnW_i);
	wrap_o.D_wr				<=	i_CPUSKT_D_i;	
	wrap_o.D_wr_stb		<= r_D_WR_stb;
	wrap_o.ack				<= i_ack;

	p_phi0_dly:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_PHI0_dly <= (others => '0');
		elsif rising_edge(fb_syscon_i.clk) then
			r_PHI0_dly <= r_PHI0_dly(r_PHI0_dly'high-1 downto 0) & r_PHI0;
		end if;
	end process;

	p_state:process(fb_syscon_i)
	variable v_ctupnext : t_substate;	
	begin
		if rising_edge(fb_syscon_i.clk) then
			r_a_stb <= '0';
			r_D_WR_stb <= '0';

			if wrap_i.rdy_ctdn = RDY_CTDN_MIN then
				v_ctupnext := r_rdy_ctup + 1;
				if v_ctupnext /= 0 then
					r_rdy_ctup <= v_ctupnext;
				end if;
			end if;

			if wrap_i.cpu_2MHz_phi2_clken = '1' then
				r_had_sys_phi2 <= '1';
			end if;

			case r_state is
				when phi1 =>
					if r_substate = SUBSTATE_A_8 then

						if r_cpu_hlt = '0' then
							if i_boot = '1' then
								if i_CPUSKT_D_i(7 downto 0) = x"00" then -- bank 0 map to FF, special treatment for native vector pulls
									if i_CPUSKT_VPB_i = '0' and i_CPUSKT_6E_i = '0' then
										-- vector pull in Native mode - get from 008Fxx
										r_log_A <= x"008F" & i_CPUSKT_A_i(7 downto 0);
									else
										-- bank 0 maps to FF in boot mode
										r_log_A <= x"FF" & i_CPUSKT_A_i;
									end if;
								else
									-- not bank 0 map direct
									r_log_A <= i_CPUSKT_D_i(7 downto 0) & i_CPUSKT_A_i;	
								end if;
							else
								-- not boot mode map direct
								r_log_A <= i_CPUSKT_D_i(7 downto 0) & i_CPUSKT_A_i;
							end if;
						end if;


						if  wrap_i.noice_debug_inhibit_cpu = '0' and
						 	fb_syscon_i.rst = '0' and
						 	wrap_i.cpu_halt = '0' and
						 	i_vma = '1' then
							r_a_stb <= '1';
								r_D_WR_stb <= '0';
								r_rdy_ctup <= (others => '0');
							r_inihib <= '0';
						else
							r_inihib <= '1';
						end if;

						if fb_syscon_i.rst = '1' or cpu_en_i = '0' then
							r_cpu_hlt <= '0';
							r_cpu_res <= '1';
						else
							r_cpu_hlt <= wrap_i.cpu_halt;
							r_cpu_res <= '0';					
						end if;
					end if;

					if r_substate = 0 then

						r_state <= phi2;
						r_PHI0 <= '1';
						r_substate <= SUBSTATEMAX_8;
					else
						r_substate <= r_substate - 1;
					end if;

					r_had_sys_phi2 <= '0';
					r_throttle <= wrap_i.throttle_cpu_2MHz;


				when phi2 =>

					if r_substate = SUBSTATE_D_WR_8 then
						r_D_WR_stb <= '1';
					end if;

					if r_substate = 0 then

						if i_ack then
							r_state <= phi1;
							r_PHI0 <= '0';
							r_substate <= SUBSTATEMAX_8;
						end if;
					else
						r_substate <= r_substate - 1;
					end if;

				when others =>
					r_state <= phi1;
					r_substate <= SUBSTATEMAX_8;
					r_PHI0 <= '0';
			end case;


			-- bodge for reset - need to better work out the state machine!
			if r_fbreset_prev = '0' and fb_syscon_i.rst = '1' then
				r_state <= phi1;
				r_substate <= SUBSTATEMAX_8;
				r_PHI0 <= '0';				
				r_throttle <= wrap_i.throttle_cpu_2MHz;
			end if;
			r_fbreset_prev <= fb_syscon_i.rst;


		end if;
	end process;

	i_ack <= '1' when
		r_state = phi2 and
		r_substate = 0 and
		(
			r_inihib = '1' or
			r_cpu_res = '1' or
				(r_rdy_ctup >= SUBSTATE_D_8) 
		) and
		(r_throttle = '0' or wrap_i.cpu_2MHz_phi2_clken = '1' or r_had_sys_phi2 = '1')

			else
				'0';



	i_vma <= i_CPUSKT_VPA_i or i_CPUSKT_VDA_i;

	i_CPUSKT_BE_o <= cpu_en_i;
	
	i_CPUSKT_PHI0_o <= r_PHI0;
	
	i_CPUSKT_nRES_o <= not r_cpu_res;
	
	i_CPUSKT_nNMI_o <= wrap_i.noice_debug_nmi_n and wrap_i.nmi_n;
  	
	i_CPUSKT_nIRQ_o <=  wrap_i.irq_n;

  	i_CPUSKT_RDY_o <= 	'0' when r_cpu_hlt = '1' else
  											'1';

--=======================================================================================
-- 65816 "boot" mode, in boot mode all accesses are to bank FF
--=======================================================================================

	-- the boot signal is delayed such that it doesn't take effect until the next instruction
	-- fetch after the subsequent instruction to allow a long jump from the boot bank after
	-- the boot flag is removed

	p_boot_65816_dly:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_boot_65816_dly <= (others => '1');
		elsif rising_edge(fb_syscon_i.clk) then
			if r_state = phi2 and r_substate = 0 and i_CPUSKT_VPA_i = '1' and i_CPUSKT_VDA_i = '1' then
				r_boot_65816_dly <= r_boot_65816_dly(r_boot_65816_dly'high-1 downto 0) & boot_65816_i;
			end if;
		end if;

	end process;

	-- boot (or not boot) is taken one cpu cycle early when instruction fetch
	i_boot <= r_boot_65816_dly(1) when i_CPUSKT_VPA_i = '1' and i_CPUSKT_VDA_i = '1' else
				 r_boot_65816_dly(2);


--=======================================================================================
-- NoIce stuff
--=======================================================================================

   p_prev_a0:process(fb_syscon_i) 
  	begin
  		if fb_syscon_i.rst = '1' then
  			r_prev_A0 <= '0';
  		elsif rising_edge(fb_syscon_i.clk) then
  			if r_state = phi2 and r_substate = 0 then
  				r_prev_A0 <= i_CPUSKT_A_i(0);
  			end if;
  		end if;
  	end process;


	wrap_o.noice_debug_A0_tgl <= r_prev_A0 xor i_CPUSKT_A_i(0);

  	wrap_o.noice_debug_cpu_clken <= '1' when r_state = phi2 and r_substate = 0 and i_ack = '1' else '0';
  	
  	wrap_o.noice_debug_5c	 <= '0';

  	wrap_o.noice_debug_opfetch <= i_CPUSKT_VPA_i and i_CPUSKT_VDA_i and not r_cpu_hlt;






end rtl;
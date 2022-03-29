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
-- Create Date:    	9/8/2020
-- Design Name: 
-- Module Name:    	fishbone bus - CPU wrapper component - 65c02, w65c02s, 65c102 etc
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

--TODO: no effort is made here to register the 2MHz part to the system clock
-- due to the jitter on some SYS clock cycles which are not exactly 2MHz the 
-- CPU may miss some cycles!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;
use work.mk3blit_pack.all;
use work.fb_cpu_pack.all;

entity fb_cpu_65c02 is
		generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED							: natural;
		G_BYTELANES							: positive	:= 1
	);
	port(

		-- configuration
		cpu_en_i									: in std_logic;									-- 1 when this cpu is the current one
		cpu_speed_i								: in std_logic_vector(2 downto 0);			
		fb_syscon_i								: in fb_syscon_t;

		-- state machine signals
		wrap_o									: out t_cpu_wrap_o;
		wrap_i									: in t_cpu_wrap_i

);
end fb_cpu_65c02;

architecture rtl of fb_cpu_65c02 is
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

	constant SUBSTATEMAX_2	: t_substate := to_unsigned(31, t_substate'length);
	constant SUBSTATEMAX_8	: t_substate := to_unsigned(7, t_substate'length);

	-- address latch state:
	constant SUBSTATE_A_2	: t_substate := SUBSTATEMAX_2 - to_unsigned(6, t_substate'length);		-- TODO: this is too fast for a 2MHz part!
	constant SUBSTATE_A_8	: t_substate := SUBSTATEMAX_8 - to_unsigned(6, t_substate'length);

	constant SUBSTATE_D_2	: t_substate := to_unsigned(2, t_substate'length);		-- TODO: this is too fast for a 2MHz part!
	constant SUBSTATE_D_8	: t_substate := to_unsigned(1, t_substate'length);

	constant SUBSTATE_D_WR_2: t_substate := SUBSTATEMAX_2 - to_unsigned(7, t_substate'length);		-- TODO: this is too fast for a 2MHz part!
	constant SUBSTATE_D_WR_8: t_substate := SUBSTATEMAX_8 - to_unsigned(6, t_substate'length);


	signal r_cpu_hlt			: std_logic;	-- need to register this at the start of the cycle following
														-- halt being asserted to stop that cycle from starting
	signal r_cpu_res			: std_logic;

	signal r_boot_65816_dly	: std_logic_vector(2 downto 0) := (others => '1');
	signal r_a_stb				: std_logic;		-- '1' for 1 cycle at start of a controller cycle
	signal r_D_WR_stb			: std_logic;
	signal r_inihib			: std_logic;		-- '1' throughout an inhibited cycle

	signal r_log_A				: std_logic_vector(23 downto 0);

	signal i_ack				: std_logic;

	signal r_fbreset_prev	: std_logic := '0';

	signal r_throttle_cpu_2MHz : std_logic;


	-- port b
	signal i_CPUSKT_BE_o		: std_logic;
	signal i_CPUSKT_PHI0_o	: std_logic;
	signal i_CPUSKT_RDY_o	: std_logic;
	signal i_CPUSKT_nIRQ_o	: std_logic;
	signal i_CPUSKT_nNMI_o	: std_logic;
	signal i_CPUSKT_nRES_o	: std_logic;

	-- port d

	signal i_CPUSKT_RnW_i	: std_logic;
	signal i_CPUSKT_SYNC_i	: std_logic;

	signal r_cfg_8Mhz			: std_logic;

begin
	p_cfg:process(fb_syscon_i)
	begin
		if rising_edge(fb_syscon_i.clk) then
			if fb_syscon_i.prerun(2) = '1' then
				r_cfg_8MHz <= cpu_speed_i(2);
			end if;
		end if;

	end process;

	wrap_o.exp_PORTB(0) <= i_CPUSKT_BE_o;
	wrap_o.exp_PORTB(1) <= '1';
	wrap_o.exp_PORTB(2) <= i_CPUSKT_PHI0_o;
	wrap_o.exp_PORTB(3) <= i_CPUSKT_RDY_o;
	wrap_o.exp_PORTB(4) <= i_CPUSKT_nIRQ_o;
	wrap_o.exp_PORTB(5) <= i_CPUSKT_nNMI_o;
	wrap_o.exp_PORTB(6) <= i_CPUSKT_nRES_o;
	wrap_o.exp_PORTB(7) <= '1';


	i_CPUSKT_RnW_i			<= wrap_i.exp_PORTD(1);
	i_CPUSKT_SYNC_i		<= wrap_i.exp_PORTD(4);


	wrap_o.exp_PORTD <= (
		others => '1'
		);

	wrap_o.exp_PORTD_o_en <= (
		others => '0'
		);

	wrap_o.exp_PORTE_nOE <= '0';
	wrap_o.exp_PORTF_nOE <= '1';

	assert CLOCKSPEED = 128 report "CLOCKSPEED must be 128" severity error;


	wrap_o.CPU_D_RnW <= 	'1' 	when i_CPUSKT_RnW_i = '1' 					
										and (r_PHI0_dly(r_PHI0_dly'high) = '1' 	
										or r_PHI0_dly(0) = '1')
										else												
							'0';


	wrap_o.A_log 			<= r_log_A;
	wrap_o.cyc	 			<= ( 0 => r_a_stb, others => '0');
	wrap_o.we	  			<= not(i_CPUSKT_RnW_i);
	wrap_o.D_wr				<=	wrap_i.CPUSKT_D(7 downto 0);	
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

			case r_state is
				when phi1 =>
					if (r_substate = SUBSTATE_A_2 and r_cfg_8MHz = '0') or
						(r_substate = SUBSTATE_A_8 and r_cfg_8MHz = '1') then
	
						if r_cpu_hlt = '0' then
							-- not boot mode map direct
							r_log_A <= x"FF" & wrap_i.CPUSKT_A(15 downto 0);
						end if;


						if  wrap_i.noice_debug_inhibit_cpu = '0' and
							 fb_syscon_i.rst = '0' and
							 wrap_i.cpu_halt = '0' then
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
						if r_cfg_8MHz = '0' then
							r_substate <= SUBSTATEMAX_2;
						else
							r_substate <= SUBSTATEMAX_8;
						end if;
					else
						r_substate <= r_substate - 1;
					end if;

				when phi2 =>

					if (r_substate = SUBSTATE_D_WR_2 and r_cfg_8MHz = '0') or
						(r_substate = SUBSTATE_D_WR_8 and r_cfg_8MHz = '1') then
						r_D_WR_stb <= '1';
					end if;

					if r_substate = 0 then

						if i_ack then
							r_state <= phi1;
							r_PHI0 <= '0';
							r_throttle_cpu_2MHz <= wrap_i.throttle_cpu_2MHz;
							if r_cfg_8MHz = '0' then
								r_substate <= SUBSTATEMAX_2;
							else
								r_substate <= SUBSTATEMAX_8;
							end if;
						end if;
					else
						r_substate <= r_substate - 1;
					end if;

				when others =>
					r_state <= phi1;
					r_substate <= SUBSTATEMAX_2;
					r_PHI0 <= '0';
			end case;


			-- bodge for reset - need to better work out the state machine!
			if r_fbreset_prev = '0' and fb_syscon_i.rst = '1' then
				r_state <= phi1;
				r_substate <= SUBSTATEMAX_2;
				r_PHI0 <= '0';				
				r_throttle_cpu_2MHz <= wrap_i.throttle_cpu_2MHz;
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
			(r_rdy_ctup >= SUBSTATE_D_2 and r_cfg_8MHz = '0') or
			(r_rdy_ctup >= SUBSTATE_D_8 and r_cfg_8MHz = '1') 
		) and
		(r_throttle_cpu_2MHz = '0' or wrap_i.cpu_2MHz_phi2_clken = '1')

			else
				'0';



	i_CPUSKT_BE_o <= cpu_en_i;
	
	i_CPUSKT_PHI0_o <= r_PHI0;
	
	i_CPUSKT_nRES_o <= not r_cpu_res;
	
	i_CPUSKT_nNMI_o <= wrap_i.noice_debug_nmi_n and wrap_i.nmi_n;
	
	i_CPUSKT_nIRQ_o <=  wrap_i.irq_n;
  	
  	i_CPUSKT_RDY_o <= 	'0' when r_cpu_hlt = '1' else
  											'1';						


--=======================================================================================
-- NoIce stuff
--=======================================================================================

   p_prev_a0:process(fb_syscon_i) 
  	begin
  		if fb_syscon_i.rst = '1' then
  			r_prev_A0 <= '0';
  		elsif rising_edge(fb_syscon_i.clk) then
  			if r_state = phi2 and r_substate = 0 then
  				r_prev_A0 <= wrap_i.CPUSKT_A(0);
  			end if;
  		end if;
  	end process;


	wrap_o.noice_debug_A0_tgl <= r_prev_A0 xor wrap_i.CPUSKT_A(0);

  	wrap_o.noice_debug_cpu_clken <= '1' when r_state = phi2 and r_substate = 0 else '0';

  	wrap_o.noice_debug_5c	 <= '1' when 
  										i_CPUSKT_SYNC_i = '1' 
  										and wrap_i.CPUSKT_D(7 downto 0) = x"5C" else
  								'0';

  	wrap_o.noice_debug_opfetch <= i_CPUSKT_SYNC_i and not r_cpu_hlt;



end rtl;
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	22/9/2021
-- Design Name: 
-- Module Name:      fb_HDMI_vidproc
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the C20K/blitter/cpu board's secondary screen VIDPROC
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
----------------------------------------------------------------------------------

--TODO: lose latched D - not really much point?


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;

entity fb_HDMI_vidproc is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up

	);
	port(

		-- fishbone signals for cpu/dma port

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;

		-- fishbone to 48m timing signals
		reset48_o							: out    std_logic;

		-- rest of signals are in the 48M domain
		CLK_48M_i							: in 		std_logic;

		-- Clock enable output to CRTC
		CLKEN_CRTC_o						:	out	std_logic;
		
		-- Clock enable output for sprite data fetches (always at 2MHz)
		CLKEN_SPR_o						:	out	std_logic;

		-- Display RAM data bus (for display data fetch)
		RAM_D0_i								:	in	std_logic_vector(7 downto 0);
		RAM_D1_i								:	in	std_logic_vector(7 downto 0);
		
		-- Control interface
		nINVERT_i							:	in	std_logic;
		DISEN_i								:	in	std_logic;
		DISEN_U_i							:	in	std_logic;
		CURSOR_i								:	in	std_logic;
		
		-- Teletext enabled
		TTX_o									:  out std_logic;

		-- Teletext or RobC attribute enabled
		MHZ12_o								:  out std_logic;

		-- 80 col telexted
		TTX80_i								:  in std_logic;

		-- Model B/C attribute in
		MODE_ATTR_i							:  in  std_logic;

		-- Model B/C sprites out
		SPR_PX_CLKEN						: out  std_logic;

		-- Model B/C sprites in 
		SPR_PX_ACT							: in   std_logic;
		SPR_PX_DAT  						: in   std_logic_vector(3 downto 0);

		-- Video in (teletext mode)
		R_TTX_i								:	in	std_logic;
		G_TTX_i								:	in	std_logic;
		B_TTX_i								:	in	std_logic;
		PIXDE_TTX_i							:  in std_logic;
		PIXCLKEN_TTX_i						:  in std_logic;

		-- Video out
		R_o									:	out	std_logic_vector(3 downto 0);
		G_o									:	out	std_logic_vector(3 downto 0);
		B_o									:	out	std_logic_vector(3 downto 0);
		PIXDE_o								:  out   std_logic;
		PIXCLKEN_o							:  out   std_logic

	);
end fb_HDMI_vidproc;

-- Clock crossing (fishbone clock, 128 MHz, and CLK_48M_i)
--
-- The board .sdc declares the two clocks asynchronous, so none of the paths
-- between them are timed. The crossing is made safe by design instead:
--   * each strobe crosses through a 2-register synchroniser (metadelay):
--     r_vid_fb_req -> i_req_48 and r_vid_48_done -> i_done_fb;
--   * the data (r_A, r_D_wr)
--     is held stable from before its strobe toggles until after it is used.
--     It is only sampled once the toggle has come through the synchroniser,
--     so it has been stable for at least 2 destination clocks, far longer
--     than any routing delay. No multicycle or other .sdc rules are needed.
--
-- Handshake: r_vid_fb_req toggles to start an access. The 48 MHz side sees
-- the toggle on i_req_48, copies the bus values and pulses the 6845 ENABLE;
-- on that same edge DO is updated and r_vid_48_done toggles to match. The
-- fishbone side only accepts a new cycle when i_done_fb matches
-- r_vid_fb_req (nothing in flight), and a read completes on that match, not
-- on a pulse, so a read can't be completed by a previous access.
-- Writes are acknowledged as soon as the data is taken (posted).

architecture rtl of fb_HDMI_vidproc is

   type     t_per_state is (idle, act_rd, act_wr);

   signal   r_per_state       : t_per_state;

   -- fishbone (128 MHz) side NOTE: no reads!
   signal   r_A_ack           : std_logic;
   signal   r_D_ack           : std_logic;
   signal   r_A               : std_logic_vector(1 downto 0);  -- held while an access is in flight
   signal   r_D_wr            : std_logic_vector(7 downto 0);  -- held while an access is in flight
   signal   r_vid_fb_req      : std_logic;                     -- toggles to start an access
   signal   i_done_fb         : std_logic;                     -- r_vid_48_done synchronised to the fishbone clock

   -- 48 MHz side
   signal   i_req_48          : std_logic;                     -- r_vid_fb_req synchronised to the 48 MHz clock
   signal   r_vid_48_ack      : std_logic;                     -- follows i_req_48 when the access is started
   signal   r_vid_48_done     : std_logic;                     -- follows r_vid_48_ack as DO is updated
   signal   r_vid_48_clken    : std_logic;                     -- 6845 ENABLE
   signal   r_A_48            : std_logic_vector(1 downto 0);
   signal   r_D_wr_48         : std_logic_vector(7 downto 0);

	-- VIDPROC generated signals
	signal	r_CLKEN16_DIV				: unsigned(1 downto 0);
	signal	r_CLKEN16					: std_logic;

	signal 	i_R							: std_logic_vector(3 downto 0);
	signal 	i_G							: std_logic_vector(3 downto 0);
	signal 	i_B							: std_logic_vector(3 downto 0);

	signal   r_reset_48					: std_logic := '1';
	signal   r_reset_48_hard			: std_logic := '1';

begin
	
	reset48_o <= r_reset_48;

	R_o <= i_R;
	G_o <= i_G;
	B_o <= i_B;


	e_vidproc:entity work.vidproc
	port map(
		PIXCLK			=> CLK_48M_i,


		CLOCK				=> CLK_48M_i,
		CLKEN				=> r_CLKEN16,				

		nRESET			=> not r_reset_48_hard,
		
		CLKEN_CRTC		=> CLKEN_CRTC_o,
		CLKEN_SPR		=> CLKEN_SPR_o,
		
		CPUCLKEN			=> '1',
      ENABLE         => r_vid_48_clken,
		A					=> r_A_48,
		DI_CPU			=> r_d_wr_48,
		DI_RAM_0			=> RAM_D0_i,
		DI_RAM_1			=> RAM_D1_i,
		nINVERT			=> nINVERT_i,
		DISEN				=> DISEN_i,
		DISEN_U			=> DISEN_U_i,
		CURSOR			=> CURSOR_i,
		R_IN				=> R_TTX_i,
		G_IN				=> G_TTX_i,
		B_IN				=> B_TTX_i,
		PIXDE_IN			=> PIXDE_TTX_i,
		PIXCLKEN_IN		=> PIXCLKEN_TTX_i,
		R					=> i_R,
		G					=> i_G,
		B					=> i_B,
      PIXCLKEN     	=> PIXCLKEN_o,
      PIXDE        	=> PIXDE_o,

		TTXT80			=> TTX80_i,

		TTXT				=> TTX_o,

		MODE_ATTR		=> MODE_ATTR_i,
		SPR_PX_CLKEN	=> SPR_PX_CLKEN,
		SPR_PX_ACT		=> SPR_PX_ACT,
		SPR_PX_DAT		=> SPR_PX_DAT
	);

	p_rst_48:process(fb_syscon_i.rst, CLK_48M_i)
	begin
		if rising_edge(CLK_48M_i) then
			if fb_syscon_i.rst = '1' then
				r_reset_48 <= '1';
				if fb_syscon_i.rst_state = resetfull or fb_syscon_i.rst_state = powerup then
					r_reset_48_hard <= '1';
				end if;
			else
				r_reset_48 <= '0';
				r_reset_48_hard <= '0';
			end if;
		end if;
	end process;


	--register reset
	--divide down by 3 48 -> 16 MHz
	p_reg32:process(r_reset_48, CLK_48M_i)
	begin
		if r_reset_48 = '1' then
			r_CLKEN16_DIV <= (others => '0');
			r_CLKEN16 <= '0';
		elsif rising_edge(CLK_48M_i) then
			r_CLKEN16 <= '0';
			r_CLKEN16_DIV <= r_CLKEN16_DIV + 1;
			if r_CLKEN16_DIV = "10" then
				r_CLKEN16 <= '1';
				r_CLKEN16_DIV <= (others => '0');
			end if;
		end if;
	end process;


		-- FISHBONE wrapper for CPU/DMA access
   fb_p2c_o.A_ack <= r_A_ack;
   fb_p2c_o.D_ack <= r_D_ack;
   fb_p2c_o.rdy   <= r_D_ack;
   fb_p2c_o.D_rd  <= x"FF";      --TODO: maybe a generic for this, I think Beeb normally reads back FE due to bus hold

   e_sync_req:entity work.metadelay
   generic map (
      N           => 2
   )
   port map (
      clk         => CLK_48M_i,
      i           => r_vid_fb_req,
      o           => i_req_48
   );

   e_sync_done:entity work.metadelay
   generic map (
      N           => 2
   )
   port map (
      clk         => fb_syscon_i.clk,
      i           => r_vid_48_done,
      o           => i_done_fb
   );

   p_req_ack:process(r_reset_48, CLK_48M_i)
   begin
      if r_reset_48 = '1' then
         r_vid_48_ack      <= '0';
         r_vid_48_done     <= '0';
         r_vid_48_clken    <= '0';
         r_A_48            <= (others => '0');
         r_D_wr_48         <= (others => '0');
      elsif rising_edge(CLK_48M_i) then
         r_vid_48_clken    <= '0';

         if i_req_48 /= r_vid_48_ack then
            r_vid_48_clken <= '1';
            r_vid_48_ack   <= i_req_48;
            r_A_48         <= r_A;
            r_D_wr_48      <= r_D_wr;
         end if;

         if r_vid_48_clken = '1' then
            r_vid_48_done <= r_vid_48_ack;
         end if;
      end if;
   end process;

   -- fishbone side
	p_per_state:process(fb_syscon_i)
	begin
		if fb_syscon_i.rst = '1' then
			r_per_state <= idle;
         r_A_ack     <= '0';
         r_D_ack     <= '0';
			r_A <= (others => '0');
         r_D_wr      <= (others => '0');
         r_vid_fb_req<= '0';
		elsif rising_edge(fb_syscon_i.clk) then
         r_A_ack <= '0';
         r_D_ack <= '0';

			case r_per_state is
				when idle =>
               -- only start when the previous access has finished, so that
               -- r_A and r_D_wr stay put while it's in flight
               if fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' and r_A_ack = '0'
                  and i_done_fb = r_vid_fb_req then
						r_A <= fb_c2p_i.A(1 downto 0);
                  r_A_ack <= '1';
						if fb_c2p_i.we = '1' then
                     r_per_state <= act_wr;
						else
                     r_per_state <= act_rd;                     
						end if;
					end if;
            when act_wr =>
               if fb_c2p_i.D_wr_stb = '1' and r_D_ack = '0' then
                  r_D_wr         <= fb_c2p_i.D_wr;
                  r_vid_fb_req   <= not r_vid_fb_req;
                  r_D_ack        <= '1';
						r_per_state <= idle;
					end if;
            when act_rd  =>
               -- this kept as dummy read for now we may need to check reads 
               -- in later builds but for now it's write only
               r_D_ack <= '1';
					r_per_state <= idle;	
				when others =>
					r_per_state <= idle;
			end case;

         -- abort: an access already started still completes on the 48 MHz
         -- side; the guard in idle waits for it
         if fb_c2p_i.cyc = '0' then
            r_per_state <= idle;
            r_A_ack <= '0';
            r_D_ack <= '0';
         end if;
   
		end if;
	end process;





end rtl;
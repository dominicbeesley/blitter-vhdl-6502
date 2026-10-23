-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	22/9/2021
-- Design Name: 
-- Module Name:    	fishbone bus - HDMI dual head CRTC wrapper
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the blitter/cpu board's secondary screen CRTC
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

--TODO: lose latched D - not really much point?


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;

entity fb_HDMI_crtc is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up
	);
	port(

		-- fishbone signals for cpu/dma port

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;

		-- fishbone to 48m timing signals
		reset48_i							: in     std_logic;
	
		-- Clock enable output to CRTC
		CLOCK_48_i							:  in    std_logic;
		CLKEN_CRTC_i						:	in		std_logic;
		
		-- Display interface
		VSYNC_o								:	out	std_logic;
		HSYNC_o								:	out	std_logic;
		DE_o									:	out	std_logic;
		CURSOR_o								:	out	std_logic;
		LPSTB_i								:	in		std_logic;
		
		-- Memory interface
		MA_o									:	out	std_logic_vector(13 downto 0);
		RA_o									:	out	std_logic_vector(4 downto 0);

		ILACE_o								:  out	std_logic

	);
end fb_HDMI_crtc;

-- Clock crossing (fishbone clock, 128 MHz, and CLOCK_48_i)
--
-- The board .sdc declares the two clocks asynchronous, so none of the paths
-- between them are timed. The crossing is made safe by design instead:
--   * each strobe crosses through a 2-register synchroniser (metadelay):
--     r_fb_req -> i_req_48 and r_vid_48_done -> i_done_fb;
--   * the data (r_A, r_D_wr, r_rnw one way, the 6845 DO the other)
--     is held stable from before its strobe toggles until after it is used.
--     It is only sampled once the toggle has come through the synchroniser,
--     so it has been stable for at least 2 destination clocks, far longer
--     than any routing delay. No multicycle or other .sdc rules are needed.
--
-- Handshake: r_fb_req toggles to start an access. The 48 MHz side sees
-- the toggle on i_req_48, copies the bus values and pulses the 6845 ENABLE;
-- on that same edge DO is updated and r_vid_48_done toggles to match. The
-- fishbone side only accepts a new cycle when i_done_fb matches
-- r_fb_req (nothing in flight), and a read completes on that match, not
-- on a pulse, so a read can't be completed by a previous access.
-- Writes are acknowledged as soon as the data is taken (posted).

architecture rtl of fb_HDMI_crtc is

   type     t_per_state is (idle, act_rd, act_wr);

	signal	r_per_state : t_per_state;

   -- fishbone (128 MHz) side
   signal   r_A_ack           : std_logic;
   signal   r_D_ack           : std_logic;
   signal   r_D_rd            : std_logic_vector(7 downto 0);
   signal   r_A               : std_logic;                     -- held while an access is in flight
   signal   r_D_wr            : std_logic_vector(7 downto 0);  -- held while an access is in flight
   signal   r_rnw             : std_logic;                     -- held while an access is in flight
   signal   r_fb_req          : std_logic;                     -- toggles to start an access
   signal   i_done_fb         : std_logic;                     -- r_vid_48_done synchronised to the fishbone clock

   -- 48 MHz side
   signal   i_req_48          : std_logic;                     -- r_fb_req synchronised to the 48 MHz clock
   signal   r_vid_48_ack      : std_logic;                     -- follows i_req_48 when the access is started
   signal   r_vid_48_done     : std_logic;                     -- follows r_vid_48_ack as DO is updated
   signal   r_vid_48_clken    : std_logic;                     -- 6845 ENABLE
	signal	r_A_48				: std_logic;
	signal	r_D_wr_48			: std_logic_vector(7 downto 0);
   signal   r_rnw_48          : std_logic;
	signal   i_d_rd_48			: std_logic_vector(7 downto 0);

begin

	e_crtc:entity work.mc6845
	port map (
		CLOCK			=> CLOCK_48_i,
		CLKEN			=> CLKEN_CRTC_i,
		CLKEN_CPU	=> '1',
		nRESET		=> not reset48_i,

		-- Bus interface
		ENABLE	=> r_vid_48_clken,
      R_nW        => r_rnw_48,
		RS			=> r_A_48,
      DI          => r_D_wr_48,
		DO			=> i_d_rd_48,

		-- Display interface
		VSYNC		=> VSYNC_o,
		HSYNC		=> HSYNC_o,
		DE			=> DE_o,
		CURSOR	=> CURSOR_o,
		LPSTB		=> LPSTB_i,
		
		-- Memory interface
		MA			=> MA_o,
		RA			=> RA_o,

		VGA		=> '0',

		ILACE		=> ILACE_o
	);


	-- FISHBONE wrapper for CPU/DMA access
   fb_p2c_o.A_ack <= r_A_ack;
   fb_p2c_o.D_ack <= r_D_ack;
   fb_p2c_o.rdy   <= r_D_ack;
   fb_p2c_o.D_rd  <= r_D_rd;


   e_sync_req:entity work.metadelay
   generic map (
      N           => 2
   )
   port map (
      clk         => CLOCK_48_i,
      i           => r_fb_req,
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


   -- 48 MHz side. If only the fishbone side is reset, this side follows
   -- r_fb_req back with one access using the reset values (a read).
	p_req_ack:process(reset48_i, CLOCK_48_i)
	begin
		if reset48_i = '1' then
			r_vid_48_ack <= '0';
         r_vid_48_done     <= '0';
			r_vid_48_clken <= '0';
         r_A_48            <= '0';
         r_D_wr_48         <= (others => '0');
         r_rnw_48 <= '1';
		elsif rising_edge(CLOCK_48_i) then
			r_vid_48_clken <= '0';

         if i_req_48 /= r_vid_48_ack then
				r_vid_48_clken <= '1';
            r_vid_48_ack      <= i_req_48;
				r_A_48 <= r_A;
				r_D_wr_48 <= r_D_wr;
            r_rnw_48 <= r_rnw;
         end if;

         -- the 6845 updates DO on this edge too; DO is still held for
         -- the 2 fishbone clocks it takes done to come through e_sync_done
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
         r_A_ack        <= '0';
         r_D_ack <= '0';
         r_D_rd <= (others => '0');
			r_A <= '0';
         r_D_wr         <= (others => '0');
         r_rnw   <= '1';
         r_fb_req   <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
         r_A_ack <= '0';
         r_D_ack <= '0';

			case r_per_state is
				when idle =>
               -- only start when the previous access has finished, so that
               -- r_A, r_D_wr and r_rnw stay put while it's in flight
               if fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' and r_A_ack = '0'
                  and i_done_fb = r_fb_req then
						r_A <= fb_c2p_i.A(0);
                  r_rnw <= not fb_c2p_i.we;
                  r_A_ack <= '1';
						if fb_c2p_i.we = '1' then
                     r_per_state <= act_wr;
						else
                     r_fb_req   <= not r_fb_req;
                     r_per_state <= act_rd;                     
						end if;
					end if;
            when act_wr =>
               if fb_c2p_i.D_wr_stb = '1' and r_D_ack = '0' then
                  r_D_wr         <= fb_c2p_i.D_wr;
                  r_fb_req   <= not r_fb_req;
                  r_D_ack        <= '1';
						r_per_state <= idle;
					end if;
            when act_rd  =>
               if i_done_fb = r_fb_req then
                  r_D_rd <= i_d_rd_48;
                  r_D_ack <= '1';
						r_per_state <= idle;
					end if;
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

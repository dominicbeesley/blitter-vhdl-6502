-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	22/9/2021
-- Design Name: 
-- Module Name:    	fb_sprites
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		fishbone bus - sprites control wrapper
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
use work.common.all;
use work.sprites_pack.all;
use work.fishbone.all;

entity fb_sprites is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		G_N_SPRITES							: positive := 8
	);
	port(

		-- fishbone signals for cpu/dma port

		fb_syscon_i							: in		fb_syscon_t;
		fb_c2p_i								: in		fb_con_o_per_i_t;
		fb_p2c_o								: out		fb_con_i_per_o_t;

		-- clock in for all non regs, should be a multiple of pixel rate and < 2*fb clock (i.e. 48 vs 128 is enough)
		clk_48M_i							: in		std_logic;							-- clock in video domain (48MHz)
		reset48_i							: in     std_logic;							-- reset in video domain

		-- data interface, from sequencer
		SEQ_D_i								: in	std_logic_vector(7 downto 0);
		SEQ_wren_i							: in	std_logic;
		SEQ_A_i								: in	unsigned(numbits(G_N_SPRITES) + 3 downto 0);			
																								-- sprite data A..D, pos/ctl, ptr, lst (see below in p_regs)
		-- addresses out to sequencer
		SEQ_DATAPTR_A_o					: out t_spr_addr_array(G_N_SPRITES-1 downto 0);
		SEQ_DATAPTR_act_o					: out std_logic_vector(G_N_SPRITES-1 downto 0);		-- indicates a request for this address
		SEQ_DATA_REQ_o						: out std_logic;							-- toggles once per line to inform sequencer to redo data
		SEQ_A_pre_o							: out t_spr_pre_array(G_N_SPRITES-1 downto 0);

		-- vidproc / crtc signals in

		pixel_clken_i						: in		std_logic;							-- 8MHz@64uS line (512 per line) pixel clock should be aligned with fb clock
		vsync_i								: in		std_logic;
		hsync_i								: in		std_logic;
		disen_i								: in		std_logic;
		
		-- pixels out
		pixel_act_o							: out		std_logic;
		pixel_o								: out		std_logic_vector(3 downto 0)
	

	);
end fb_sprites;

-- Clock crossing (fishbone clock, 128 MHz, and clk_48M_i)
--
-- As in fb_HDMI_crtc: the board .sdc declares the two clocks asynchronous,
-- and the crossing is made safe by design:
--   * each strobe crosses through a 2-register synchroniser (metadelay):
--     r_fb_req -> i_req_48 and r_vid_48_done -> i_done_fb;
--   * the data (r_A, r_D_wr, r_rnw one way, r_D_rd_48 the other) is held
--     stable from before its strobe toggles until after it is used, so it
--     has been stable for at least 2 destination clocks when it's sampled.
--
-- Unlike the 6845, the sprites core can take several 48 MHz clocks to
-- respond (the sequencer has priority for writes), so the 48 MHz side holds
-- CPU_wren_i / CPU_rden_i until the core's ack:
--   * write: r_d_wr_req_48 is held until i_wr_ack_48. The core repeats the
--     same write while wren is held, which is harmless (as before).
--   * read: r_d_rd_req_48 is held until i_rd_ack_48; the data comes with
--     the ack and is captured in r_D_rd_48 on that edge.
--   * reads of the local debug registers (A(7) = '1') also go through the
--     core for the ack, and r_D_rd_48 takes the local value instead; local
--     writes are ignored and complete at once.
-- r_vid_48_done toggles to match when the access is finished. A new request
-- is only started once both acks are low again, so a late ack from the
-- previous access can't complete the next one.
--
-- The fishbone side only accepts a new cycle when i_done_fb matches r_fb_req
-- (nothing in flight). A read completes on that match. Writes are
-- acknowledged as soon as the data is taken (posted); a following access
-- waits behind the guard, so ordering is kept.

architecture rtl of fb_sprites is
	
	constant C_A_SIZE						: natural := numbits(G_N_SPRITES) + 4;

   type     t_per_state is (idle, act_rd, act_wr);

   signal   r_per_state       : t_per_state;

   -- fishbone (128 MHz) side
   signal   r_A_ack           : std_logic;
   signal   r_D_ack           : std_logic;
   signal   r_D_rd            : std_logic_vector(7 downto 0);
   signal   r_A               : std_logic_vector(7 downto 0);  -- held while an access is in flight
   signal   r_D_wr            : std_logic_vector(7 downto 0);  -- held while an access is in flight
   signal   r_rnw             : std_logic;                     -- held while an access is in flight
   signal   r_fb_req          : std_logic;                     -- toggles to start an access
   signal   i_done_fb         : std_logic;                     -- r_vid_48_done synchronised to the fishbone clock

   -- 48 MHz side
   signal   i_req_48          : std_logic;                     -- r_fb_req synchronised to the 48 MHz clock
   signal   r_vid_48_ack      : std_logic;                     -- follows i_req_48 when the access is started
   signal   r_vid_48_done     : std_logic;                     -- follows r_vid_48_ack when the access is finished
   signal   r_d_rd_req_48     : std_logic;                     -- CPU_rden_i, held until i_rd_ack_48
   signal   r_d_wr_req_48     : std_logic;                     -- CPU_wren_i, held until i_wr_ack_48
   signal   r_A_48            : std_logic_vector(7 downto 0);
   signal   r_D_wr_48         : std_logic_vector(7 downto 0);
   signal   r_rnw_48          : std_logic;
   signal   i_d_rd_48         : std_logic_vector(7 downto 0);
   signal   i_d_rd_local_48   : std_logic_vector(7 downto 0);
   signal   i_d_rd_sprites_48 : std_logic_vector(7 downto 0);
   signal   r_D_rd_48         : std_logic_vector(7 downto 0);  -- read data, captured with the core's ack
   signal   i_wr_ack_48       : std_logic;
   signal   i_rd_ack_48       : std_logic;

   signal   i_horz_ctr        : unsigned(8 downto 0);
   signal   i_vert_ctr        : unsigned(8 downto 0);

begin

	-- read local debug signals
	i_D_rd_local_48 
		<= std_logic_vector(i_horz_ctr(7 downto 0)) when r_A_48(3 downto 0) = x"0" else
			"0000000" & std_logic(i_horz_ctr(8)) 			when r_A_48(3 downto 0) = x"1" else
			std_logic_vector(i_vert_ctr(7 downto 0)) 		when r_A_48(3 downto 0) = x"2" else
			"0000000" & std_logic(i_vert_ctr(8)) 			when r_A_48(3 downto 0) = x"3" else
			(others => '1');


	assert C_A_SIZE <= 7 report "C_A_SIZE must be <= 7: A(7) selects the local debug registers" severity error;
	i_d_rd_48 <= 	i_D_rd_local_48 when r_A_48(7) = '1' else
					i_d_rd_sprites_48;


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
      clk         => clk_48M_i,
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


   -- 48 MHz side
   p_req_ack:process(reset48_i, clk_48M_i)
   begin
      if reset48_i = '1' then
         r_vid_48_ack 		<= '0';
         r_vid_48_done     <= '0';
         r_d_rd_req_48     <= '0';
         r_d_wr_req_48     <= '0';
         r_A_48            <= (others => '0');
         r_D_wr_48         <= (others => '0');
         r_rnw_48 			<= '1';
         r_D_rd_48         <= (others => '0');
      elsif rising_edge(clk_48M_i) then

         if r_d_wr_req_48 = '1' then
            -- write in progress: hold wren until the core has done it
            if i_wr_ack_48 = '1' then
               r_d_wr_req_48  <= '0';
               r_vid_48_done  <= r_vid_48_ack;
            end if;
         elsif r_d_rd_req_48 = '1' then
            -- read in progress: hold rden until the core's data is valid
            if i_rd_ack_48 = '1' then
               r_d_rd_req_48  <= '0';
               r_D_rd_48      <= i_d_rd_48;
               r_vid_48_done  <= r_vid_48_ack;
            end if;
         elsif i_req_48 /= r_vid_48_ack and i_wr_ack_48 = '0' and i_rd_ack_48 = '0' then
            -- new access (and the previous one's acks have gone)
            r_vid_48_ack   <= i_req_48;
            r_A_48 			<= r_A;
            r_D_wr_48 		<= r_D_wr;
            r_rnw_48 		<= r_rnw;
            if r_rnw = '1' then
               r_d_rd_req_48  <= '1';           -- local reads too, for the ack
            elsif r_A(7) = '0' then
               r_d_wr_req_48  <= '1';
            else
               r_vid_48_done  <= i_req_48;      -- local write: ignored
            end if;
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
         r_D_rd      <= (others => '0');
			r_A <= (others => '0');
         r_D_wr      <= (others => '0');
         r_rnw       <= '1';
         r_fb_req    <= '0';
		elsif rising_edge(fb_syscon_i.clk) then
         r_A_ack <= '0';
         r_D_ack <= '0';

			case r_per_state is
				when idle =>
               -- only start when the previous access has finished, so that
               -- r_A, r_D_wr and r_rnw stay put while it's in flight
               if fb_c2p_i.cyc = '1' and fb_c2p_i.A_stb = '1' and r_A_ack = '0'
                  and i_done_fb = r_fb_req then
                  r_A      <= fb_c2p_i.A(7 downto 0);
                  r_rnw    <= not fb_c2p_i.we;
                  r_A_ack  <= '1';
						if fb_c2p_i.we = '1' then
                     r_per_state <= act_wr;
						else
                     r_fb_req    <= not r_fb_req;
                     r_per_state <= act_rd;
						end if;
					end if;
            when act_wr =>
               if fb_c2p_i.D_wr_stb = '1' and r_D_ack = '0' then
                  r_D_wr      <= fb_c2p_i.D_wr;
                  r_fb_req    <= not r_fb_req;
                  r_D_ack     <= '1';
						r_per_state <= idle;
					end if;
            when act_rd =>
               if i_done_fb = r_fb_req then
                  r_D_rd      <= r_D_rd_48;
                  r_D_ack     <= '1';
					r_per_state <= idle;	
					end if;
				when others =>
					r_per_state <= idle;
			end case;

         -- abort: an access already started still completes on the 48 MHz
         -- side; the guard in idle waits for it
         if fb_c2p_i.cyc = '0' then
            r_per_state <= idle;
            r_A_ack     <= '0';
            r_D_ack     <= '0';
         end if;

		end if;
	end process;


e_sprites:entity work.sprites
	generic map (
		SIM							=> SIM,
		G_N_SPRITES					=> G_N_SPRITES
	)
	port map(

		clk_48M_i					=> clk_48M_i,
		rst_i							=> reset48_i,

		-- data interface, from sequencer
		SEQ_D_i						=> SEQ_D_i,
		SEQ_wren_i					=> SEQ_wren_i,
		SEQ_A_i						=> SEQ_A_i,
																								-- sprite data A..D, pos/ctl, ptr, lst (see below in p_regs)
		-- addresses out to sequencer
		SEQ_DATAPTR_A_o			=> SEQ_DATAPTR_A_o,
		SEQ_DATAPTR_act_o			=> SEQ_DATAPTR_act_o,
		SEQ_DATA_req_o				=> SEQ_DATA_req_o,
		SEQ_A_pre_o					=> SEQ_A_pre_o,

		-- data interface, from CPU
		CPU_D_i						=> r_D_wr_48,
		CPU_rden_i					=> r_d_rd_req_48,
		CPU_wren_i					=> r_d_wr_req_48,
		CPU_A_i						=> unsigned(r_A_48(C_A_SIZE-1 downto 0)),
		CPU_D_o						=> i_d_rd_sprites_48,
		CPU_wr_ack_o				=> i_wr_ack_48,
		CPU_rd_ack_o				=> i_rd_ack_48,

		-- vidproc / crtc signals in
		pixel_clken_i				=> pixel_clken_i,
		vsync_i						=> vsync_i,
		hsync_i						=> hsync_i,
		disen_i						=> disen_i,


		-- pixels out
		pixel_act_o					=> pixel_act_o,
		pixel_o						=> pixel_o,

		--debug out

		horz_ctr_o					=> i_horz_ctr,
		vert_ctr_o					=> i_vert_ctr

	);



end rtl;

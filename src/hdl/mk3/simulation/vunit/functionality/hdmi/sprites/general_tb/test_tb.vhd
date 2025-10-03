library vunit_lib;
context vunit_lib.vunit_context;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;

entity test_tb is
	generic (runner_cfg : string);
end test_tb;

architecture rtl of test_tb is

	procedure sim_wait_reset 
	(
		signal c2p 		: out	fb_con_o_per_i_t;
		signal syscon 	: in   fb_syscon_t
	) is
	variable i:natural;
	begin

		c2p <= fb_c2p_unsel;

		if syscon.rst /= '1' then
			wait until syscon.rst = '1';
		end if;

		wait until syscon.rst = '0';

		for i in 0 to 3 loop
			wait until rising_edge(syscon.clk);
		end loop;

	end sim_wait_reset;


	procedure single_read(
			A			: in 	std_logic_vector(23 downto 0);
		signal syscon 	: in 	fb_syscon_t;
		signal c2p		: out	fb_con_o_per_i_t;
		signal p2c		: in	fb_con_i_per_o_t;
			D    		: out 	std_logic_vector(7 downto 0);

			A_stb_dl : natural := 0	-- no of cycles to delay a_stb after cyc
	) is
	variable v_iter: natural;
	variable v_ret : std_logic_vector(7 downto 0);
	begin

		wait until rising_edge(syscon.clk);

		if (A_stb_dl = 0) then
			c2p <= (
				cyc			=> '1',
				we				=> '0',
				A				=> A,
				A_stb			=> '1',
				D_wr			=> x"00",
				D_wr_stb		=> '0',
				rdy_ctdn		=> RDY_CTDN_MIN
			);
		else
			c2p <= (
				cyc			=> '1',
				we				=> '0',
				A				=> (others => '-'),
				A_stb			=> '0',
				D_wr			=> x"00",
				D_wr_stb		=> '0',
				rdy_ctdn		=> RDY_CTDN_MIN
			);
			for i in 1 to A_stb_dl loop
				wait until rising_edge(syscon.clk);
			end loop;

			c2p.A_stb <= '1';
			c2p.A <= A;
		end if;

		wait until rising_edge(syscon.clk);

		-- wait for stall

		v_iter := 0;
		while p2c.stall /= '0' loop
			wait until rising_edge(syscon.clk);
			v_iter := v_iter + 1;
			if v_iter > 100000 then
				report "Failed waiting for stall" severity error;
			end if;
		end loop;

		c2p.a_stb <= '0';
		c2p.a <= (others => '-');

		wait until rising_edge(syscon.clk);
		-- wait for ack

		v_iter := 0;
		while p2c.ack /= '1' loop
			wait until rising_edge(syscon.clk);
			v_iter := v_iter + 1;
			if v_iter > 100000 then
				report "Failed waiting for ack" severity error;
			end if;
		end loop;

		D := p2c.D_rd;

		wait until rising_edge(syscon.clk);

		c2p <= fb_c2p_unsel;

		wait until rising_edge(syscon.clk);
		

	end single_read;

	procedure single_write(
			A			: in 	std_logic_vector(23 downto 0);
		signal syscon 	: in 	fb_syscon_t;		
		signal c2p		: out	fb_con_o_per_i_t;
		signal p2c		: in	fb_con_i_per_o_t;
			D    		: in 	std_logic_vector(7 downto 0);

			A_stb_dl : natural := 0;-- no of cycles to delay a_stb after cyc
			D_stb_dl : natural := 0	-- no of cycles to delay d_stb after a_stb
	) is
	variable v_iter: natural;
	variable v_ret : std_logic_vector(7 downto 0);
	variable I : natural;
	begin

		wait until rising_edge(syscon.clk);
			c2p <= (
				cyc			=> '1',
				we				=> '1',
				A				=> (others => '-'),
				A_stb			=> '0',
				D_wr			=> x"00",
				D_wr_stb		=> '0',
				rdy_ctdn		=> RDY_CTDN_MIN
			);

		while I <= A_stb_dl + D_stb_dl loop
			c2p.A_stb <= '0';
			c2p.D_wr_stb <= '0';
			if I = A_stb_dl then
				c2p.A <= A;
				c2p.A_stb <= '1';
			end if;
			if I = A_stb_dl+D_stb_dl then
				c2p.D_wr <= D;
				c2p.D_wr_stb <= '1';
			end if;

			wait until rising_edge(syscon.clk);
			if I /=	 A_stb_dl or p2c.stall = '0' then
				I := I + 1;
			end if;
		end loop;

	

		-- wait for stall

		v_iter := 0;
		while p2c.stall /= '0' loop
			wait until rising_edge(syscon.clk);
			v_iter := v_iter + 1;
			if v_iter > 100000 then
				report "Failed waiting for stall" severity error;
			end if;
		end loop;

		c2p.a_stb <= '0';
		c2p.a <= (others => '-');

		wait until rising_edge(syscon.clk);
		-- wait for ack

		v_iter := 0;
		while p2c.ack /= '1' loop
			wait until rising_edge(syscon.clk);
			v_iter := v_iter + 1;
			if v_iter > 100000 then
				report "Failed waiting for ack" severity error;
			end if;
		end loop;

		wait until rising_edge(syscon.clk);

		c2p <= fb_c2p_unsel;

		wait until rising_edge(syscon.clk);
		

	end single_write;

	constant FB_CLOCKSPEED : natural := 128;
	constant FB_CLOCK_PER : time := (1000000/FB_CLOCKSPEED) * 1 ps;
	constant CLOCK48_PER : time := (1000000/48) * 1 ps;

	signal i_fb_clk		: std_logic;
	signal i_48_clk		: std_logic;
	signal i_SUP_RESn	: std_logic;

	signal i_fb_syscon			: fb_syscon_t;							-- shared bus signals


	signal i_fb_c2p	: fb_con_o_per_i_t;
	signal i_fb_p2c	: fb_con_i_per_o_t;


	signal i_HDMI_SCL	: std_logic;
	signal i_HDMI_SDA	: std_logic;
begin
	p_syscon_clk:process
	begin
		i_fb_clk <= '1';
		wait for FB_CLOCK_PER / 2;
		i_fb_clk <= '0';
		wait for FB_CLOCK_PER / 2;
	end process;

	p_48_clk:process
	begin
		i_48_clk <= '1';
		wait for CLOCK48_PER / 2;
		i_48_clk <= '0';
		wait for CLOCK48_PER / 2;
	end process;

	p_main:process
	variable v_time:time;
		procedure W(A:std_logic_vector(23 downto 0); D:std_logic_vector(7 downto 0)) is
		begin
			single_write(A => A,D => D,	c2p => i_fb_c2p,p2c => i_fb_p2c,syscon => i_fb_syscon);
		end procedure;

		-- big endian write of data for sprite
		procedure W32B(A:std_logic_vector(23 downto 0); D:std_logic_vector(31 downto 0)) is
		variable AA :unsigned(23 downto 0);
		begin
			AA := unsigned(A);
			single_write(
				A => std_logic_vector(AA), 
				D => D(31 downto 24), 
				c2p => i_fb_c2p,
				p2c => i_fb_p2c,
				syscon => i_fb_syscon
			);
			AA := AA + 1;
			single_write(
				A => std_logic_vector(AA), 
				D => D(23 downto 16), 
				c2p => i_fb_c2p,
				p2c => i_fb_p2c,
				syscon => i_fb_syscon
			);
			AA := AA + 1;
			single_write(
				A => std_logic_vector(AA), 
				D => D(15 downto 8), 
				c2p => i_fb_c2p,
				p2c => i_fb_p2c,
				syscon => i_fb_syscon
			);
			AA := AA + 1;
			single_write(
				A => std_logic_vector(AA), 
				D => D(7 downto 0), 
				c2p => i_fb_c2p,
				p2c => i_fb_p2c,
				syscon => i_fb_syscon
			);
		end procedure;

		-- little endian write of long register
		procedure W32(A:std_logic_vector(23 downto 0); D:std_logic_vector(31 downto 0)) is
		variable AA :unsigned(23 downto 0);
		begin
			AA := unsigned(A);
			single_write(
				A => std_logic_vector(AA), 
				D => D(7 downto 0), 
				c2p => i_fb_c2p,
				p2c => i_fb_p2c,
				syscon => i_fb_syscon
			);
			AA := AA + 1;
			single_write(
				A => std_logic_vector(AA), 
				D => D(15 downto 8), 
				c2p => i_fb_c2p,
				p2c => i_fb_p2c,
				syscon => i_fb_syscon
			);
			AA := AA + 1;
			single_write(
				A => std_logic_vector(AA), 
				D => D(23 downto 16), 
				c2p => i_fb_c2p,
				p2c => i_fb_p2c,
				syscon => i_fb_syscon
			);
			AA := AA + 1;
			single_write(
				A => std_logic_vector(AA), 
				D => D(31 downto 24), 
				c2p => i_fb_c2p,
				p2c => i_fb_p2c,
				syscon => i_fb_syscon
			);
		end procedure;

		-- little endian write of long register
		procedure W24(A:std_logic_vector(23 downto 0); D:std_logic_vector(31 downto 0)) is
		variable AA :unsigned(23 downto 0);
		begin
			AA := unsigned(A);
			single_write(
				A => std_logic_vector(AA), 
				D => D(7 downto 0), 
				c2p => i_fb_c2p,
				p2c => i_fb_p2c,
				syscon => i_fb_syscon
			);
			AA := AA + 1;
			single_write(
				A => std_logic_vector(AA), 
				D => D(15 downto 8), 
				c2p => i_fb_c2p,
				p2c => i_fb_p2c,
				syscon => i_fb_syscon
			);
			AA := AA + 1;
			single_write(
				A => std_logic_vector(AA), 
				D => D(23 downto 16), 
				c2p => i_fb_c2p,
				p2c => i_fb_p2c,
				syscon => i_fb_syscon
			);
		end procedure;

		procedure CRTCW(IX:natural; D:std_logic_vector(7 downto 0)) is
		begin
			W(x"FBFE00", std_logic_vector(to_unsigned(IX,8)));
			W(x"FBFE01", D);
		end procedure;

		procedure INIT_SCREEN is
		begin
						-- make a tiny screen 
				CRTCW(0,  x"39"); --	 0 Horizontal Total	 		=58
				CRTCW(1,  x"0A"); --	 1 Horizontal Displayed 	=10
				CRTCW(2,  x"1C"); --	 2 Horizontal Sync	 		=28
				CRTCW(3,  x"38"); --	 3 HSync Width+VSync	 	=&18  VSync=3, HSync Width=8
				CRTCW(4,  x"08"); --	 4 Vertical Total	 		=8
				CRTCW(5,  x"00"); --	 5 Vertial Adjust	 		=0
				CRTCW(6,  x"05"); --	 6 Vertical Displayed	 	=5
				CRTCW(7,  x"05"); --	 7 VSync Position	 		=5
				CRTCW(8,  x"00"); --	 8 Interlace+Cursor	 		=&00  Cursor=0, Display=0, Interlace=Off
				CRTCW(9,  x"07"); --	 9 Scan Lines/Character 	=8
				CRTCW(10, x"6D"); --	 10 Cursor Start Line	  	=&67	Blink=On, Speed=1/32, Line=13
				CRTCW(11, x"0F"); --	 11 Cursor End Line	  		=8

				CRTCW(12, x"06"); --	 11 Cursor End Line	  		=8
				CRTCW(13, x"00"); --	 11 Cursor End Line	  		=8

				CRTCW(14, x"06"); --	 11 Cursor End Line	  		=8
				CRTCW(15, x"00"); --	 11 Cursor End Line	  		=8

								-- mode 2 (test multiple quick writes)
				W(x"FBFE20", x"F4");

				-- simple palette
				W(x"FBFE21", x"07");
				W(x"FBFE21", x"16");
				W(x"FBFE21", x"25");
				W(x"FBFE21", x"34");
				W(x"FBFE21", x"43");
				W(x"FBFE21", x"52");
				W(x"FBFE21", x"61");
				W(x"FBFE21", x"70");

				W(x"FBFE21", x"8F");
				W(x"FBFE21", x"9E");
				W(x"FBFE21", x"AD");
				W(x"FBFE21", x"BC");
				W(x"FBFE21", x"CB");
				W(x"FBFE21", x"DA");
				W(x"FBFE21", x"E9");
				W(x"FBFE21", x"F8");

				W(x"FA3018", "00000000");
				W(x"FA3020", "00000110");
				W(x"FA3028", "00100000");
				W(x"FA3030", "11111111");
				W(x"FA3038", "00000011");
				W(x"FA3040", "00001100");
				W(x"FA3048", "00110000");


		end procedure;

		procedure SPRITE_DATA is
		begin
				-- sprite data setup
				W32B(x"FA2000", "00011011000000010000000011100100");
				W32B(x"FA2004", "00011011000001110100000011100100");
				W32B(x"FA2008", "00011011000111001101000011100100");
				W32B(x"FA2010", "00011011011100100011010011100100");
				W32B(x"FA2014", "00011011011100100011010011100100");
				W32B(x"FA2018", "00011011000111001101000011100100");
				W32B(x"FA2020", "00011011000001110100000011100100");
				W32B(x"FA2024", "00011011000000010000000011100100");


		end procedure;

	begin

		test_runner_setup(runner, runner_cfg);


		while test_suite loop

			if run("single sprite") then

				i_SUP_RESn <= '0';
				wait for 69 us; -- must be > pll lock time
				i_SUP_RESn <= '1';

				sim_wait_reset(
					c2p => i_fb_c2p,
					syscon => i_fb_syscon
				);

				INIT_SCREEN;	
				SPRITE_DATA;			

				-- setup sprite 0

				W(x"FBFF08", x"00");
				W(x"FBFF09", x"20");
				W(x"FBFF0A", x"00");		-- sprite data at 0x2000


				W(x"FBFF04", x"77");		-- horz = 119
				W(x"FBFF05", x"0A");		-- vert = 10
				W(x"FBFF06", x"11");		-- vert end = 17
				W(x"FBFF07", x"00");		-- no high bits, no attach, latch 

				-- force horizontal arm
				W32B(x"FBFF00", "10100011111001001010010101011010");



				wait for 10000 us;

			elsif run("2 in a list") then

				i_SUP_RESn <= '0';
				wait for 69 us; -- must be > pll lock time
				i_SUP_RESn <= '1';

				sim_wait_reset(
					c2p => i_fb_c2p,
					syscon => i_fb_syscon
				);

				INIT_SCREEN;	
				SPRITE_DATA;			

				-- setup sprite list 0

				W32(x"FA2080", x"200E0A77"); -- 119x10-14  cont list
				W32(x"FA2084", x"00FA2000"); -- sprite dataptr
				W32(x"FA2088", x"00161270"); -- 112x18-24 end of list
				
				W32(x"FBFF0C", x"00FA2080"); -- list start address
				
				wait for 10000 us;

			end if;

		end loop;

		wait for 3 us;

		test_runner_cleanup(runner); -- Simulation ends here
	end process;


	e_hdmi:entity work.fb_HDMI
	generic map (
		SIM				=> true,
		SIM_NODVI		=> true,
		CLOCKSPEED		=> FB_CLOCKSPEED
	)
	port map (

		CLK_48M_i			=> i_48_clk,

		-- fishbone signals

		fb_syscon_i			=> i_fb_syscon,
		fb_c2p_i			=> i_fb_c2p,
		fb_p2c_o			=> i_fb_p2c,

		HDMI_SCL_io			=> i_HDMI_SCL,
		HDMI_SDA_io			=> i_HDMI_SDA,
		HDMI_HPD_i			=> '0',
		HDMI_CK_o			=> open,
		HDMI_R_o			=> open,
		HDMI_G_o			=> open,
		HDMI_B_o			=> open,

		-- analogue video	

		VGA_R_o				=> open,
		VGA_G_o				=> open,
		VGA_B_o				=> open,
		VGA_HS_o			=> open,
		VGA_VS_o			=> open,
		VGA_BLANK_o			=> open,

		-- retimed analogue video
		VGA27_R_o			=> open,
		VGA27_G_o			=> open,
		VGA27_B_o			=> open,
		VGA27_HS_o			=> open,
		VGA27_VS_o			=> open,
		VGA27_BLANK_o		=> open,

		-- sysvia scroll registers
		scroll_latch_c_i	=> "00",


		PCM_L_i				=> (others => '0'),

		debug_vsync_det_o	=> open,
		debug_hsync_det_o	=> open,
		debug_hsync_crtc_o	=> open,
		debug_odd_o			=> open


	);

	e_fb_syscon: entity work.fb_syscon
	generic map (
		SIM => true,
		CLOCKSPEED => FB_CLOCKSPEED
	)
	port map (
		fb_syscon_o							=> i_fb_syscon,

		EXT_nRESET_i						=> i_SUP_RESn,

		clk_fish_i							=> i_fb_clk,
		clk_lock_i							=> '1',
		sys_dll_lock_i						=> '1'

	);	

	i_HDMI_SCL <= 'Z';
	i_HDMI_SDA <= 'Z';

end rtl;
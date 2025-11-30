library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;
use work.fishbone.all;

package fb_intcon_pack is

component fb_intcon_shared is
	generic (
		SIM								: boolean := false;
		G_CONTROLLER_COUNT			: POSITIVE;
		G_PERIPHERAL_COUNT			: POSITIVE;
		G_ARB_ROUND_ROBIN 			: boolean := false;
		G_REGISTER_CONTROLLER_P2C	: boolean := false;
		G_REGISTER_PERIPHERAL_C2P	: boolean := false
	);
	port (

		fb_syscon_i				: in	fb_syscon_t;

		-- peripheral port connect to controllers
		fb_con_c2p_i			: in	fb_con_o_per_i_arr(G_CONTROLLER_COUNT-1 downto 0);
		fb_con_p2c_o			: out	fb_con_i_per_o_arr(G_CONTROLLER_COUNT-1 downto 0);

		-- controller port connecto to peripherals
		fb_per_c2p_o			: out fb_con_o_per_i_arr(G_PERIPHERAL_COUNT-1 downto 0);
		fb_per_p2c_i			: in 	fb_con_i_per_o_arr(G_PERIPHERAL_COUNT-1 downto 0);

		-- peripheral select interface -- note, testing shows that having both one hot and index is faster _and_ uses fewer resources
		peripheral_sel_addr_o		: out	fb_arr_std_logic_vector(G_CONTROLLER_COUNT-1 downto 0)(23 downto 0);
		peripheral_sel_we_o		   : out	std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);
		peripheral_sel_i				: in fb_arr_unsigned(G_CONTROLLER_COUNT-1 downto 0)(numbits(G_PERIPHERAL_COUNT)-1 downto 0);  -- address decoded selected peripheral
		peripheral_sel_oh_i			: in fb_arr_std_logic_vector(G_CONTROLLER_COUNT-1 downto 0)(G_PERIPHERAL_COUNT-1 downto 0)		-- address decoded selected peripherals as one-hot

	);
end component;

component fb_intcon_one_to_many is
	generic (
		SIM					: boolean := false;
		G_PERIPHERAL_COUNT		: POSITIVE;
		G_ARB_ROUND_ROBIN : boolean := false;
		G_ADDRESS_WIDTH	: POSITIVE 						-- width of the address that we care about
	);
	port (

		fb_syscon_i				: in	fb_syscon_t;

		-- peripheral port connect to controllers
		fb_con_c2p_i			: in	fb_con_o_per_i_t;
		fb_con_p2c_o			: out	fb_con_i_per_o_t;

		-- controller port connecto to peripherals
		fb_per_c2p_o			: out fb_con_o_per_i_arr(G_PERIPHERAL_COUNT-1 downto 0);
		fb_per_p2c_i			: in 	fb_con_i_per_o_arr(G_PERIPHERAL_COUNT-1 downto 0);

		-- peripheral select interface -- note, testing shows that having both one hot and index is faster _and_ uses fewer resources
		peripheral_sel_addr_o		: out	std_logic_vector(G_ADDRESS_WIDTH-1 downto 0);
		peripheral_sel_we_o		   : out	std_logic;
		peripheral_sel_i				: in unsigned(numbits(G_PERIPHERAL_COUNT)-1 downto 0);  -- address decoded selected peripheral
		peripheral_sel_oh_i			: in std_logic_vector(G_PERIPHERAL_COUNT-1 downto 0)		-- address decoded selected peripherals as one-hot

	);
end component;


component fb_intcon_many_to_one is
	generic (
		SIM					: boolean := false;
		G_CONTROLLER_COUNT		: POSITIVE;
		G_ARB_ROUND_ROBIN : boolean := false
	);
	port (

		fb_syscon_i				: in	fb_syscon_t;

		-- peripheral port connect to controllers
		fb_con_c2p_i			: in	fb_con_o_per_i_arr(G_CONTROLLER_COUNT-1 downto 0);
		fb_con_p2c_o			: out	fb_con_i_per_o_arr(G_CONTROLLER_COUNT-1 downto 0);

		-- controller port connecto to peripherals
		fb_per_c2p_o			: out fb_con_o_per_i_t;
		fb_per_p2c_i			: in 	fb_con_i_per_o_t

	);
end component;

component fb_intcon_crossbar is
	generic (
		G_CONTROLLER_COUNT		: POSITIVE;
		G_PERIPHERAL_COUNT		: POSITIVE
	);
	port (

		fb_syscon_i				: in	fb_syscon_t;

		-- peripheral port connect to controllers
		fb_con_c2p_i			: in	fb_con_o_per_i_arr(G_CONTROLLER_COUNT-1 downto 0);
		fb_con_p2c_o			: out	fb_con_i_per_o_arr(G_CONTROLLER_COUNT-1 downto 0);

		-- controller port connecto to peripherals
		fb_per_c2p_o			: out fb_con_o_per_i_arr(G_PERIPHERAL_COUNT-1 downto 0);
		fb_per_p2c_i			: in 	fb_con_i_per_o_arr(G_PERIPHERAL_COUNT-1 downto 0);


		-- the addresses to be mapped
		map_addr_to_map_o		: out	fb_std_logic_2d(G_CONTROLLER_COUNT-1 downto 0, 23 downto 0);	
		-- possibly translated address
		map_addr_mapped_i		: in	fb_std_logic_2d(G_CONTROLLER_COUNT-1 downto 0, 23 downto 0);					
		-- a set of unsigned values indicating which peripheral (if any) is selected
		map_peripheral_sel_i		: in	fb_std_logic_2d(G_CONTROLLER_COUNT-1 downto 0, numbits(G_PERIPHERAL_COUNT)-1 downto 0);
		-- set if a peripheral should be selected
		map_addr_matched_i   : in  std_logic_vector(G_CONTROLLER_COUNT-1 downto 0)


	);
end component;



end fb_intcon_pack;
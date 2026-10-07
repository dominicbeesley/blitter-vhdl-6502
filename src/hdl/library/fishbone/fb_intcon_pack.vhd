library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;
use work.fishbone.all;

package fb_intcon_pack is

-- -----------------------------------------------------------------------------
-- Peripheral select (address decoder) interface
-- -----------------------------------------------------------------------------
-- Interconnects with peripheral_sel_* ports do not decode addresses
-- themselves. The decoder is a separate, purely combinatorial block so that
-- different address maps can be plugged in (one set of ports per controller
-- on many-controller interconnects):
--
--   peripheral_sel_addr_o : address of the current A_stb
--   peripheral_sel_we_o   : we of the current A_stb, so that reads and writes
--                           of the same address may select different
--                           peripherals
--   peripheral_sel_i      : selected peripheral index,
--                           numbits(G_PERIPHERAL_COUNT) bits
--   peripheral_sel_oh_i   : the same selection as a one-hot
--
-- The decoder returns both in the same clock. Testing suggests having both may
-- be faster and use fewer resources: the decoder can produce each directly
-- from the address, and the interconnect uses the one-hot to steer strobes
-- and mux returned signals and the index for comparisons. To keep this
-- benefit a decoder should not derive one from the other.
--
-- The decoder must:
--   * map every address to a valid peripheral (index < G_PERIPHERAL_COUNT)
--   * set exactly one bit of the one-hot, agreeing with the index
--
-- Interconnects also rely on these rules from the Fishbone spec:
--   * a peripheral returns exactly one D_ack per A_ack'd transaction
--   * a peripheral ignores D_wr_stb unless it has an accepted write still
--     waiting for its data; this lets a D_wr_stb belonging to a write that is
--     still blocked for another peripheral sit harmlessly on the current one
-- -----------------------------------------------------------------------------

component fb_intcon_shared is
   generic (
      SIM                        : boolean := false;
      G_CONTROLLER_COUNT         : POSITIVE;
      G_PERIPHERAL_COUNT         : POSITIVE;
      G_ARB_ROUND_ROBIN          : boolean := false;
      G_REGISTER_CONTROLLER_P2C  : boolean := false;
      G_REGISTER_CONTROLLER_P2C_BEFORE_MUX : boolean := false;
      G_REGISTER_PERIPHERAL_C2P  : boolean := false
   );
   port (

      fb_syscon_i          : in  fb_syscon_t;

      -- peripheral port connect to controllers
      fb_con_c2p_i         : in  fb_con_o_per_i_arr(G_CONTROLLER_COUNT-1 downto 0);
      fb_con_p2c_o         : out fb_con_i_per_o_arr(G_CONTROLLER_COUNT-1 downto 0);

      -- controller port connecto to peripherals
      fb_per_c2p_o         : out fb_con_o_per_i_arr(G_PERIPHERAL_COUNT-1 downto 0);
      fb_per_p2c_i         : in  fb_con_i_per_o_arr(G_PERIPHERAL_COUNT-1 downto 0);

      -- peripheral select interface -- note, testing shows that having both one hot and index is faster _and_ uses fewer resources
      peripheral_sel_addr_o      : out fb_arr_std_logic_vector(G_CONTROLLER_COUNT-1 downto 0)(23 downto 0);
      peripheral_sel_we_o        : out std_logic_vector(G_CONTROLLER_COUNT-1 downto 0);
      peripheral_sel_i           : in fb_arr_unsigned(G_CONTROLLER_COUNT-1 downto 0)(numbits(G_PERIPHERAL_COUNT)-1 downto 0);  -- address decoded selected peripheral
      peripheral_sel_oh_i        : in fb_arr_std_logic_vector(G_CONTROLLER_COUNT-1 downto 0)(G_PERIPHERAL_COUNT-1 downto 0)      -- address decoded selected peripherals as one-hot

   );
end component;

component fb_intcon_one_to_many is
   generic (
      G_PERIPHERAL_COUNT   : positive := 4;     -- number of peripherals
      G_MAXOUT             : positive := 15     -- max outstanding transactions
   );
   port (

      fb_syscon_i          : in  fb_syscon_t;

      -- peripheral port connect to controller
      fb_up_c2p_i          : in  fb_con_o_per_i_t;
      fb_up_p2c_o          : out fb_con_i_per_o_t;

      -- controller port connect to peripherals
      fb_dn_c2p_o          : out fb_con_o_per_i_arr(G_PERIPHERAL_COUNT-1 downto 0);
      fb_dn_p2c_i          : in  fb_con_i_per_o_arr(G_PERIPHERAL_COUNT-1 downto 0);

      -- peripheral select interface (see above)
      peripheral_sel_addr_o   : out std_logic_vector(23 downto 0);
      peripheral_sel_we_o     : out std_logic;
      peripheral_sel_i        : in  unsigned(numbits(G_PERIPHERAL_COUNT)-1 downto 0);  -- selected peripheral index
      peripheral_sel_oh_i     : in  std_logic_vector(G_PERIPHERAL_COUNT-1 downto 0)    -- selected peripheral one-hot

   );
end component;


component fb_intcon_many_to_one is
   generic (
      SIM               : boolean := false;
      G_CONTROLLER_COUNT      : POSITIVE;
      G_ARB_ROUND_ROBIN : boolean := false
   );
   port (

      fb_syscon_i          : in  fb_syscon_t;

      -- peripheral port connect to controllers
      fb_con_c2p_i         : in  fb_con_o_per_i_arr(G_CONTROLLER_COUNT-1 downto 0);
      fb_con_p2c_o         : out fb_con_i_per_o_arr(G_CONTROLLER_COUNT-1 downto 0);

      -- controller port connecto to peripherals
      fb_per_c2p_o         : out fb_con_o_per_i_t;
      fb_per_p2c_i         : in  fb_con_i_per_o_t

   );
end component;

component fb_intcon_crossbar is
   generic (
      G_CONTROLLER_COUNT      : POSITIVE;
      G_PERIPHERAL_COUNT      : POSITIVE
   );
   port (

      fb_syscon_i          : in  fb_syscon_t;

      -- peripheral port connect to controllers
      fb_con_c2p_i         : in  fb_con_o_per_i_arr(G_CONTROLLER_COUNT-1 downto 0);
      fb_con_p2c_o         : out fb_con_i_per_o_arr(G_CONTROLLER_COUNT-1 downto 0);

      -- controller port connecto to peripherals
      fb_per_c2p_o         : out fb_con_o_per_i_arr(G_PERIPHERAL_COUNT-1 downto 0);
      fb_per_p2c_i         : in  fb_con_i_per_o_arr(G_PERIPHERAL_COUNT-1 downto 0);


      -- the addresses to be mapped
      map_addr_to_map_o    : out fb_std_logic_2d(G_CONTROLLER_COUNT-1 downto 0, 23 downto 0);   
      -- possibly translated address
      map_addr_mapped_i    : in  fb_std_logic_2d(G_CONTROLLER_COUNT-1 downto 0, 23 downto 0);               
      -- a set of unsigned values indicating which peripheral (if any) is selected
      map_peripheral_sel_i : in  fb_std_logic_2d(G_CONTROLLER_COUNT-1 downto 0, numbits(G_PERIPHERAL_COUNT)-1 downto 0);
      -- set if a peripheral should be selected
      map_addr_matched_i   : in  std_logic_vector(G_CONTROLLER_COUNT-1 downto 0)


   );
end component;


component fb_intcon_buffer is
   generic (
      G_REG_C2P            : boolean; -- insert a set of registers to the c2p signals
      G_REG_P2C            : boolean  -- insert a set of registers in the p2c signals
   );
   port(

      fb_syscon_i          : in  fb_syscon_t;

      -- upstream peripheral port connect to controller
      fb_up_c2p_i          : in  fb_con_o_per_i_t;
      fb_up_p2c_o          : out fb_con_i_per_o_t;

      -- downstream controller port connect to peripheral
      fb_dn_c2p_o          : out fb_con_o_per_i_t;
      fb_dn_p2c_i          : in  fb_con_i_per_o_t

   );
end component;


end fb_intcon_pack;
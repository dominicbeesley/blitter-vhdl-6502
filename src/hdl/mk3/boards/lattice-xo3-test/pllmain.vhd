-- wrapper for Lattice pll to appear same as Intel


LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY pllmain IS
	PORT
	(
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC ;
		c1		: OUT STD_LOGIC ;
		locked		: OUT STD_LOGIC 
	);
END pllmain;

ARCHITECTURE SYN OF pllmain IS

BEGIN
	e_pll_int:entity work.pllmain_int
	port map (
        CLKI	=> inclk0,
        CLKOP	=> c0,
        CLKOS	=> c1,
        LOCK	=>locked
	);

END SYN;
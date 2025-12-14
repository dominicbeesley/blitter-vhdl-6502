--Copyright (C)2014-2024 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.11 (64-bit)
--Part Number: GW2A-LV18PG256C8/I7
--Device: GW2A-18
--Device Version: C
--Created Time: Sun Jun 29 15:25:18 2025

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component pll_pal_sc
    port (
        clkout: out std_logic;
        clkoutd3: out std_logic;
        clkin: in std_logic
    );
end component;

your_instance_name: pll_pal_sc
    port map (
        clkout => clkout,
        clkoutd3 => clkoutd3,
        clkin => clkin
    );

----------Copy end-------------------

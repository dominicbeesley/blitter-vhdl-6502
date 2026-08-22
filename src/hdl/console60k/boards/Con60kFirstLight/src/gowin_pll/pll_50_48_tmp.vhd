--Copyright (C)2014-2024 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.10 (64-bit)
--Part Number: GW5AT-LV60PG484AC1/I0
--Device: GW5AT-60
--Device Version: B
--Created Time: Sat Dec 27 01:47:18 2025

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component pll_50_48
    port (
        clkout0: out std_logic;
        clkin: in std_logic
    );
end component;

your_instance_name: pll_50_48
    port map (
        clkout0 => clkout0,
        clkin => clkin
    );

----------Copy end-------------------

--Copyright (C)2014-2025 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.12 (64-bit)
--Part Number: GW2A-LV18PG256C8/I7
--Device: GW2A-18
--Device Version: C
--Created Time: Tue Jan  6 13:14:36 2026

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component pll_27_360
    port (
        clkout: out std_logic;
        clkin: in std_logic
    );
end component;

your_instance_name: pll_27_360
    port map (
        clkout => clkout,
        clkin => clkin
    );

----------Copy end-------------------

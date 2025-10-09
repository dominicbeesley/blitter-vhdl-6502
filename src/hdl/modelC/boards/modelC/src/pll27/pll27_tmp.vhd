--Copyright (C)2014-2023 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--GOWIN Version: V1.9.8.11 Education
--Part Number: GW2A-LV18PG256C8/I7
--Device: GW2A-18
--Device Version: C
--Created Time: Fri Aug 18 10:08:04 2023

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component pll27
    port (
        clkout: out std_logic;
        clkin: in std_logic
    );
end component;

your_instance_name: pll27
    port map (
        clkout => clkout_o,
        clkin => clkin_i
    );

----------Copy end-------------------

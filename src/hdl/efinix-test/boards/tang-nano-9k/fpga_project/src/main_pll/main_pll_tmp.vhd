--Copyright (C)2014-2022 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--GOWIN Version: V1.9.8.09 Education
--Part Number: GW1NR-LV9QN88PC6/I5
--Device: GW1NR-9C
--Created Time: Sat May 06 16:12:01 2023

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component main_pll
    port (
        clkout: out std_logic;
        clkin: in std_logic
    );
end component;

your_instance_name: main_pll
    port map (
        clkout => clkout_o,
        clkin => clkin_i
    );

----------Copy end-------------------

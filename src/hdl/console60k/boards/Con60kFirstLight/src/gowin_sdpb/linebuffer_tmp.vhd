--Copyright (C)2014-2024 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.10 (64-bit)
--Part Number: GW5AT-LV60PG484AC1/I0
--Device: GW5AT-60
--Device Version: B
--Created Time: Sat Dec 27 02:08:10 2025

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component linebuffer
    port (
        dout: out std_logic_vector(0 downto 0);
        clka: in std_logic;
        cea: in std_logic;
        clkb: in std_logic;
        ceb: in std_logic;
        oce: in std_logic;
        reset: in std_logic;
        ada: in std_logic_vector(10 downto 0);
        din: in std_logic_vector(0 downto 0);
        adb: in std_logic_vector(10 downto 0)
    );
end component;

your_instance_name: linebuffer
    port map (
        dout => dout,
        clka => clka,
        cea => cea,
        clkb => clkb,
        ceb => ceb,
        oce => oce,
        reset => reset,
        ada => ada,
        din => din,
        adb => adb
    );

----------Copy end-------------------

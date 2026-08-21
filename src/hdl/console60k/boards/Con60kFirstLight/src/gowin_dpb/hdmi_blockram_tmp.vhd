--Copyright (C)2014-2024 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.10 (64-bit)
--Part Number: GW5AT-LV60PG484AC1/I0
--Device: GW5AT-60
--Device Version: B
--Created Time: Sat Dec 27 02:18:49 2025

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component hdmi_blockram
    port (
        douta: out std_logic_vector(7 downto 0);
        doutb: out std_logic_vector(7 downto 0);
        clka: in std_logic;
        ocea: in std_logic;
        cea: in std_logic;
        reseta: in std_logic;
        wrea: in std_logic;
        clkb: in std_logic;
        oceb: in std_logic;
        ceb: in std_logic;
        resetb: in std_logic;
        wreb: in std_logic;
        ada: in std_logic_vector(14 downto 0);
        dina: in std_logic_vector(7 downto 0);
        adb: in std_logic_vector(14 downto 0);
        dinb: in std_logic_vector(7 downto 0)
    );
end component;

your_instance_name: hdmi_blockram
    port map (
        douta => douta,
        doutb => doutb,
        clka => clka,
        ocea => ocea,
        cea => cea,
        reseta => reseta,
        wrea => wrea,
        clkb => clkb,
        oceb => oceb,
        ceb => ceb,
        resetb => resetb,
        wreb => wreb,
        ada => ada,
        dina => dina,
        adb => adb,
        dinb => dinb
    );

----------Copy end-------------------

-- megafunction wizard: %ALTDDIO_OUT%
-- GENERATION: STANDARD
-- VERSION: WM1.0
-- MODULE: ALTDDIO_OUT 

-- ============================================================
-- File Name: dd_out.vhd
-- Megafunction Name(s):
-- 			ALTDDIO_OUT
--
-- Simulation Library Files(s):
-- 			altera_mf
-- ============================================================
-- ************************************************************
-- THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
--
-- 20.1.1 Build 720 11/11/2020 SJ Lite Edition
-- ************************************************************


--Copyright (C) 2020  Intel Corporation. All rights reserved.
--Your use of Intel Corporation's design tools, logic functions 
--and other software and tools, and any partner logic 
--functions, and any output files from any of the foregoing 
--(including device programming or simulation files), and any 
--associated documentation or information are expressly subject 
--to the terms and conditions of the Intel Program License 
--Subscription Agreement, the Intel Quartus Prime License Agreement,
--the Intel FPGA IP License Agreement, or other applicable license
--agreement, including, without limitation, that your use is for
--the sole purpose of programming logic devices manufactured by
--Intel and sold by Intel or its authorized distributors.  Please
--refer to the applicable agreement for further details, at
--https://fpgasoftware.intel.com/eula.


LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

ENTITY dd_out IS
	PORT
	(
		datain_h		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		datain_l		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		outclock		: IN STD_LOGIC ;
		dataout		: OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
	);
END dd_out;


ARCHITECTURE SYN OF dd_out IS

	SIGNAL sub_wire0	: STD_LOGIC_VECTOR (3 DOWNTO 0);

BEGIN
	dataout    <= sub_wire0(3 DOWNTO 0);

	ALTDDIO_OUT_component : ALTDDIO_OUT
	GENERIC MAP (
		extend_oe_disable => "OFF",
		intended_device_family => "Cyclone V",
		invert_output => "OFF",
		lpm_hint => "UNUSED",
		lpm_type => "altddio_out",
		oe_reg => "UNREGISTERED",
		power_up_high => "OFF",
		width => 4
	)
	PORT MAP (
		datain_h => datain_h,
		datain_l => datain_l,
		outclock => outclock,
		dataout => sub_wire0
	);



END SYN;

-- ============================================================
-- CNX file retrieval info
-- ============================================================
-- Retrieval info: LIBRARY: altera_mf altera_mf.altera_mf_components.all
-- Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Cyclone V"
-- Retrieval info: CONSTANT: EXTEND_OE_DISABLE STRING "OFF"
-- Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Cyclone V"
-- Retrieval info: CONSTANT: INVERT_OUTPUT STRING "OFF"
-- Retrieval info: CONSTANT: LPM_HINT STRING "UNUSED"
-- Retrieval info: CONSTANT: LPM_TYPE STRING "altddio_out"
-- Retrieval info: CONSTANT: OE_REG STRING "UNREGISTERED"
-- Retrieval info: CONSTANT: POWER_UP_HIGH STRING "OFF"
-- Retrieval info: CONSTANT: WIDTH NUMERIC "4"
-- Retrieval info: USED_PORT: datain_h 0 0 4 0 INPUT NODEFVAL "datain_h[3..0]"
-- Retrieval info: CONNECT: @datain_h 0 0 4 0 datain_h 0 0 4 0
-- Retrieval info: USED_PORT: datain_l 0 0 4 0 INPUT NODEFVAL "datain_l[3..0]"
-- Retrieval info: CONNECT: @datain_l 0 0 4 0 datain_l 0 0 4 0
-- Retrieval info: USED_PORT: dataout 0 0 4 0 OUTPUT NODEFVAL "dataout[3..0]"
-- Retrieval info: CONNECT: dataout 0 0 4 0 @dataout 0 0 4 0
-- Retrieval info: USED_PORT: outclock 0 0 0 0 INPUT_CLK_EXT NODEFVAL "outclock"
-- Retrieval info: CONNECT: @outclock 0 0 0 0 outclock 0 0 0 0
-- Retrieval info: GEN_FILE: TYPE_NORMAL dd_out.vhd TRUE FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL dd_out.qip TRUE FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL dd_out.bsf TRUE TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL dd_out_inst.vhd TRUE TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL dd_out.inc TRUE TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL dd_out.cmp TRUE TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL dd_out.ppf TRUE FALSE
-- Retrieval info: LIB_FILE: altera_mf

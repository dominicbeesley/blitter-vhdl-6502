//altlvds_tx CBX_DECLARE_ALL_CONNECTED_PORTS="OFF" CBX_SINGLE_OUTPUT_FILE="ON" COMMON_RX_TX_PLL="OFF" CORECLOCK_DIVIDE_BY=2 DATA_RATE="720.0 Mbps" DESERIALIZATION_FACTOR=10 DEVICE_FAMILY="MAX 10" DIFFERENTIAL_DRIVE=0 ENABLE_CLK_LATENCY="OFF" IMPLEMENT_IN_LES="ON" INCLOCK_BOOST=0 INCLOCK_DATA_ALIGNMENT="EDGE_ALIGNED" INCLOCK_PERIOD=5000 INCLOCK_PHASE_SHIFT=0 MULTI_CLOCK="OFF" NUMBER_OF_CHANNELS=3 OUTCLOCK_ALIGNMENT="EDGE_ALIGNED" OUTCLOCK_DIVIDE_BY=10 OUTCLOCK_DUTY_CYCLE=50 OUTCLOCK_MULTIPLY_BY=2 OUTCLOCK_PHASE_SHIFT=0 OUTCLOCK_RESOURCE="AUTO" OUTPUT_DATA_RATE=720 PLL_COMPENSATION_MODE="AUTO" PLL_SELF_RESET_ON_LOSS_LOCK="OFF" PREEMPHASIS_SETTING=0 REGISTERED_INPUT="OFF" USE_EXTERNAL_PLL="ON" USE_NO_PHASE_SHIFT="ON" VOD_SETTING=0 tx_coreclock tx_in tx_inclock tx_locked tx_out tx_outclock tx_syncclock CARRY_CHAIN="MANUAL" CARRY_CHAIN_LENGTH=48
//VERSION_BEGIN 20.1 cbx_altaccumulate 2020:11:11:17:06:45:SJ cbx_altclkbuf 2020:11:11:17:06:45:SJ cbx_altddio_in 2020:11:11:17:06:45:SJ cbx_altddio_out 2020:11:11:17:06:45:SJ cbx_altera_syncram_nd_impl 2020:11:11:17:06:45:SJ cbx_altiobuf_bidir 2020:11:11:17:06:45:SJ cbx_altiobuf_in 2020:11:11:17:06:45:SJ cbx_altiobuf_out 2020:11:11:17:06:45:SJ cbx_altlvds_tx 2020:11:11:17:06:45:SJ cbx_altpll 2020:11:11:17:06:45:SJ cbx_altsyncram 2020:11:11:17:06:45:SJ cbx_arriav 2020:11:11:17:06:43:SJ cbx_cyclone 2020:11:11:17:06:45:SJ cbx_cycloneii 2020:11:11:17:06:45:SJ cbx_lpm_add_sub 2020:11:11:17:06:45:SJ cbx_lpm_compare 2020:11:11:17:06:45:SJ cbx_lpm_counter 2020:11:11:17:06:45:SJ cbx_lpm_decode 2020:11:11:17:06:45:SJ cbx_lpm_mux 2020:11:11:17:06:45:SJ cbx_lpm_shiftreg 2020:11:11:17:06:45:SJ cbx_maxii 2020:11:11:17:06:46:SJ cbx_mgl 2020:11:11:17:08:38:SJ cbx_nadder 2020:11:11:17:06:46:SJ cbx_stratix 2020:11:11:17:06:46:SJ cbx_stratixii 2020:11:11:17:06:46:SJ cbx_stratixiii 2020:11:11:17:06:46:SJ cbx_stratixv 2020:11:11:17:06:46:SJ cbx_util_mgl 2020:11:11:17:06:46:SJ  VERSION_END
// synthesis VERILOG_INPUT_VERSION VERILOG_2001
// altera message_off 10463



// Copyright (C) 2020  Intel Corporation. All rights reserved.
//  Your use of Intel Corporation's design tools, logic functions 
//  and other software and tools, and any partner logic 
//  functions, and any output files from any of the foregoing 
//  (including device programming or simulation files), and any 
//  associated documentation or information are expressly subject 
//  to the terms and conditions of the Intel Program License 
//  Subscription Agreement, the Intel Quartus Prime License Agreement,
//  the Intel FPGA IP License Agreement, or other applicable license
//  agreement, including, without limitation, that your use is for
//  the sole purpose of programming logic devices manufactured by
//  Intel and sold by Intel or its authorized distributors.  Please
//  refer to the applicable agreement for further details, at
//  https://fpgasoftware.intel.com/eula.




//altddio_out CBX_DECLARE_ALL_CONNECTED_PORTS="OFF" CBX_SINGLE_OUTPUT_FILE="ON" DEVICE_FAMILY="MAX 10" WIDTH=3 datain_h datain_l dataout outclock
//VERSION_BEGIN 20.1 cbx_altddio_out 2020:11:11:17:06:45:SJ cbx_cycloneii 2020:11:11:17:06:45:SJ cbx_maxii 2020:11:11:17:06:46:SJ cbx_mgl 2020:11:11:17:08:38:SJ cbx_stratix 2020:11:11:17:06:46:SJ cbx_stratixii 2020:11:11:17:06:46:SJ cbx_stratixiii 2020:11:11:17:06:46:SJ cbx_stratixv 2020:11:11:17:06:46:SJ cbx_util_mgl 2020:11:11:17:06:46:SJ  VERSION_END

//synthesis_resources = IO 3 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
(* ALTERA_ATTRIBUTE = {"ANALYZE_METASTABILITY=OFF;ADV_NETLIST_OPT_ALLOWED=DEFAULT"} *)
module  altera_soft_lvds_tx_sbRNZ_ddio_out_vbd
	( 
	datain_h,
	datain_l,
	dataout,
	outclock) /* synthesis synthesis_clearbox=1 */;
	input   [2:0]  datain_h;
	input   [2:0]  datain_l;
	output   [2:0]  dataout;
	input   outclock;

	wire  [2:0]   wire_ddio_outa_datainhi;
	wire  [2:0]   wire_ddio_outa_datainlo;
	wire  [2:0]   wire_ddio_outa_dataout;

	fiftyfivenm_ddio_out   ddio_outa_0
	( 
	.clkhi(outclock),
	.clklo(outclock),
	.datainhi(wire_ddio_outa_datainhi[0:0]),
	.datainlo(wire_ddio_outa_datainlo[0:0]),
	.dataout(wire_ddio_outa_dataout[0:0]),
	.muxsel(outclock)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.areset(1'b0),
	.clk(1'b0),
	.ena(1'b1),
	.sreset(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1),
	.dffhi(),
	.dfflo()
	// synopsys translate_on
	);
	defparam
		ddio_outa_0.async_mode = "none",
		ddio_outa_0.power_up = "low",
		ddio_outa_0.sync_mode = "none",
		ddio_outa_0.use_new_clocking_model = "true",
		ddio_outa_0.lpm_type = "fiftyfivenm_ddio_out";
	fiftyfivenm_ddio_out   ddio_outa_1
	( 
	.clkhi(outclock),
	.clklo(outclock),
	.datainhi(wire_ddio_outa_datainhi[1:1]),
	.datainlo(wire_ddio_outa_datainlo[1:1]),
	.dataout(wire_ddio_outa_dataout[1:1]),
	.muxsel(outclock)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.areset(1'b0),
	.clk(1'b0),
	.ena(1'b1),
	.sreset(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1),
	.dffhi(),
	.dfflo()
	// synopsys translate_on
	);
	defparam
		ddio_outa_1.async_mode = "none",
		ddio_outa_1.power_up = "low",
		ddio_outa_1.sync_mode = "none",
		ddio_outa_1.use_new_clocking_model = "true",
		ddio_outa_1.lpm_type = "fiftyfivenm_ddio_out";
	fiftyfivenm_ddio_out   ddio_outa_2
	( 
	.clkhi(outclock),
	.clklo(outclock),
	.datainhi(wire_ddio_outa_datainhi[2:2]),
	.datainlo(wire_ddio_outa_datainlo[2:2]),
	.dataout(wire_ddio_outa_dataout[2:2]),
	.muxsel(outclock)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.areset(1'b0),
	.clk(1'b0),
	.ena(1'b1),
	.sreset(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1),
	.dffhi(),
	.dfflo()
	// synopsys translate_on
	);
	defparam
		ddio_outa_2.async_mode = "none",
		ddio_outa_2.power_up = "low",
		ddio_outa_2.sync_mode = "none",
		ddio_outa_2.use_new_clocking_model = "true",
		ddio_outa_2.lpm_type = "fiftyfivenm_ddio_out";
	assign
		wire_ddio_outa_datainhi = datain_h,
		wire_ddio_outa_datainlo = datain_l;
	assign
		dataout = wire_ddio_outa_dataout;
endmodule //altera_soft_lvds_tx_sbRNZ_ddio_out_vbd


//lpm_compare CBX_DECLARE_ALL_CONNECTED_PORTS="OFF" CBX_SINGLE_OUTPUT_FILE="ON" DEVICE_FAMILY="MAX 10" LPM_WIDTH=3 aeb dataa datab
//VERSION_BEGIN 20.1 cbx_cycloneii 2020:11:11:17:06:45:SJ cbx_lpm_add_sub 2020:11:11:17:06:45:SJ cbx_lpm_compare 2020:11:11:17:06:45:SJ cbx_mgl 2020:11:11:17:08:38:SJ cbx_nadder 2020:11:11:17:06:46:SJ cbx_stratix 2020:11:11:17:06:46:SJ cbx_stratixii 2020:11:11:17:06:46:SJ  VERSION_END

//synthesis_resources = 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
module  altera_soft_lvds_tx_sbRNZ_cmpr_jqb
	( 
	aeb,
	dataa,
	datab) /* synthesis synthesis_clearbox=1 */;
	output   aeb;
	input   [2:0]  dataa;
	input   [2:0]  datab;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0   [2:0]  dataa;
	tri0   [2:0]  datab;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire  [0:0]  aeb_result_wire;
	wire  [0:0]  aneb_result_wire;
	wire  [7:0]  data_wire;
	wire  eq_wire;

	assign
		aeb = eq_wire,
		aeb_result_wire = (~ aneb_result_wire),
		aneb_result_wire = (data_wire[0] | data_wire[1]),
		data_wire = {datab[2], dataa[2], datab[1], dataa[1], datab[0], dataa[0], (data_wire[6] ^ data_wire[7]), ((data_wire[2] ^ data_wire[3]) | (data_wire[4] ^ data_wire[5]))},
		eq_wire = aeb_result_wire;
endmodule //altera_soft_lvds_tx_sbRNZ_cmpr_jqb


//lpm_counter CBX_DECLARE_ALL_CONNECTED_PORTS="OFF" CBX_SINGLE_OUTPUT_FILE="ON" DEVICE_FAMILY="MAX 10" lpm_modulus=5 lpm_width=3 clock q updown
//VERSION_BEGIN 20.1 cbx_cycloneii 2020:11:11:17:06:45:SJ cbx_lpm_add_sub 2020:11:11:17:06:45:SJ cbx_lpm_compare 2020:11:11:17:06:45:SJ cbx_lpm_counter 2020:11:11:17:06:45:SJ cbx_lpm_decode 2020:11:11:17:06:45:SJ cbx_mgl 2020:11:11:17:08:38:SJ cbx_nadder 2020:11:11:17:06:46:SJ cbx_stratix 2020:11:11:17:06:46:SJ cbx_stratixii 2020:11:11:17:06:46:SJ  VERSION_END


//lpm_compare CBX_DECLARE_ALL_CONNECTED_PORTS="OFF" CBX_SINGLE_OUTPUT_FILE="ON" DEVICE_FAMILY="MAX 10" LPM_WIDTH=3 ONE_INPUT_IS_CONSTANT="YES" aeb dataa datab
//VERSION_BEGIN 20.1 cbx_cycloneii 2020:11:11:17:06:45:SJ cbx_lpm_add_sub 2020:11:11:17:06:45:SJ cbx_lpm_compare 2020:11:11:17:06:45:SJ cbx_mgl 2020:11:11:17:08:38:SJ cbx_nadder 2020:11:11:17:06:46:SJ cbx_stratix 2020:11:11:17:06:46:SJ cbx_stratixii 2020:11:11:17:06:46:SJ  VERSION_END

//synthesis_resources = 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
module  altera_soft_lvds_tx_sbRNZ_cmpr_qge
	( 
	aeb,
	dataa,
	datab) /* synthesis synthesis_clearbox=1 */;
	output   aeb;
	input   [2:0]  dataa;
	input   [2:0]  datab;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0   [2:0]  dataa;
	tri0   [2:0]  datab;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire  [0:0]  aeb_result_wire;
	wire  [0:0]  aneb_result_wire;
	wire  [7:0]  data_wire;
	wire  eq_wire;

	assign
		aeb = eq_wire,
		aeb_result_wire = (~ aneb_result_wire),
		aneb_result_wire = (data_wire[0] | data_wire[1]),
		data_wire = {datab[2], dataa[2], datab[1], dataa[1], datab[0], dataa[0], (data_wire[6] ^ data_wire[7]), ((data_wire[2] ^ data_wire[3]) | (data_wire[4] ^ data_wire[5]))},
		eq_wire = aeb_result_wire;
endmodule //altera_soft_lvds_tx_sbRNZ_cmpr_qge

//synthesis_resources = lut 3 reg 3 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
module  altera_soft_lvds_tx_sbRNZ_cntr_a5d
	( 
	clock,
	q,
	updown) /* synthesis synthesis_clearbox=1 */;
	input   clock;
	output   [2:0]  q;
	input   updown;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri1   updown;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire  [0:0]   wire_counter_comb_bita_0combout;
	wire  [0:0]   wire_counter_comb_bita_1combout;
	wire  [0:0]   wire_counter_comb_bita_2combout;
	wire  [0:0]   wire_counter_comb_bita_0cout;
	wire  [0:0]   wire_counter_comb_bita_1cout;
	wire  [0:0]   wire_counter_comb_bita_2cout;
	wire	[2:0]	wire_counter_reg_bit_d;
	wire	[2:0]	wire_counter_reg_bit_asdata;
	reg	[2:0]	counter_reg_bit;
	wire	[2:0]	wire_counter_reg_bit_ena;
	wire	[2:0]	wire_counter_reg_bit_sload;
	wire  wire_cmpr18_aeb;
	wire  aclr_actual;
	wire clk_en;
	wire cnt_en;
	wire  compare_result;
	wire  cout_actual;
	wire [2:0]  data;
	wire  external_cin;
	wire  [2:0]  modulus_bus;
	wire  modulus_trigger;
	wire  [2:0]  s_val;
	wire  [2:0]  safe_q;
	wire sclr;
	wire sload;
	wire sset;
	wire  time_to_clear;
	wire  updown_dir;

	fiftyfivenm_lcell_comb   counter_comb_bita_0
	( 
	.cin(external_cin),
	.combout(wire_counter_comb_bita_0combout[0:0]),
	.cout(wire_counter_comb_bita_0cout[0:0]),
	.dataa(counter_reg_bit[0]),
	.datab(updown_dir),
	.datad(1'b1),
	.datac(1'b0)
	);
	defparam
		counter_comb_bita_0.lut_mask = 16'h5A90,
		counter_comb_bita_0.sum_lutc_input = "cin",
		counter_comb_bita_0.lpm_type = "fiftyfivenm_lcell_comb";
	fiftyfivenm_lcell_comb   counter_comb_bita_1
	( 
	.cin(wire_counter_comb_bita_0cout[0:0]),
	.combout(wire_counter_comb_bita_1combout[0:0]),
	.cout(wire_counter_comb_bita_1cout[0:0]),
	.dataa(counter_reg_bit[1]),
	.datab(updown_dir),
	.datad(1'b1),
	.datac(1'b0)
	);
	defparam
		counter_comb_bita_1.lut_mask = 16'h5A90,
		counter_comb_bita_1.sum_lutc_input = "cin",
		counter_comb_bita_1.lpm_type = "fiftyfivenm_lcell_comb";
	fiftyfivenm_lcell_comb   counter_comb_bita_2
	( 
	.cin(wire_counter_comb_bita_1cout[0:0]),
	.combout(wire_counter_comb_bita_2combout[0:0]),
	.cout(wire_counter_comb_bita_2cout[0:0]),
	.dataa(counter_reg_bit[2]),
	.datab(updown_dir),
	.datad(1'b1),
	.datac(1'b0)
	);
	defparam
		counter_comb_bita_2.lut_mask = 16'h5A90,
		counter_comb_bita_2.sum_lutc_input = "cin",
		counter_comb_bita_2.lpm_type = "fiftyfivenm_lcell_comb";
	// synopsys translate_off
	initial
		counter_reg_bit[0:0] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr_actual)
		if (aclr_actual == 1'b1) counter_reg_bit[0:0] <= 1'b0;
		else if  (wire_counter_reg_bit_ena[0:0] == 1'b1) 
			if (wire_counter_reg_bit_sload[0:0] == 1'b1) counter_reg_bit[0:0] <= wire_counter_reg_bit_asdata[0:0];
			else  counter_reg_bit[0:0] <= wire_counter_reg_bit_d[0:0];
	// synopsys translate_off
	initial
		counter_reg_bit[1:1] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr_actual)
		if (aclr_actual == 1'b1) counter_reg_bit[1:1] <= 1'b0;
		else if  (wire_counter_reg_bit_ena[1:1] == 1'b1) 
			if (wire_counter_reg_bit_sload[1:1] == 1'b1) counter_reg_bit[1:1] <= wire_counter_reg_bit_asdata[1:1];
			else  counter_reg_bit[1:1] <= wire_counter_reg_bit_d[1:1];
	// synopsys translate_off
	initial
		counter_reg_bit[2:2] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr_actual)
		if (aclr_actual == 1'b1) counter_reg_bit[2:2] <= 1'b0;
		else if  (wire_counter_reg_bit_ena[2:2] == 1'b1) 
			if (wire_counter_reg_bit_sload[2:2] == 1'b1) counter_reg_bit[2:2] <= wire_counter_reg_bit_asdata[2:2];
			else  counter_reg_bit[2:2] <= wire_counter_reg_bit_d[2:2];
	assign
		wire_counter_reg_bit_asdata = ({3{(~ sclr)}} & (({3{sset}} & s_val) | ({3{(~ sset)}} & (({3{sload}} & data) | (({3{(~ sload)}} & modulus_bus) & {3{(~ updown_dir)}}))))),
		wire_counter_reg_bit_d = {wire_counter_comb_bita_2combout[0:0], wire_counter_comb_bita_1combout[0:0], wire_counter_comb_bita_0combout[0:0]};
	assign
		wire_counter_reg_bit_ena = {3{(clk_en & (((sclr | sset) | sload) | cnt_en))}},
		wire_counter_reg_bit_sload = {3{(((sclr | sset) | sload) | modulus_trigger)}};
	altera_soft_lvds_tx_sbRNZ_cmpr_qge   cmpr18
	( 
	.aeb(wire_cmpr18_aeb),
	.dataa(safe_q),
	.datab(modulus_bus));
	assign
		aclr_actual = 1'b0,
		clk_en = 1'b1,
		cnt_en = 1'b1,
		compare_result = wire_cmpr18_aeb,
		cout_actual = (wire_counter_comb_bita_2cout[0:0] | (time_to_clear & updown_dir)),
		data = {3{1'b0}},
		external_cin = 1'b1,
		modulus_bus = 3'b100,
		modulus_trigger = cout_actual,
		q = safe_q,
		s_val = {3{1'b1}},
		safe_q = counter_reg_bit,
		sclr = 1'b0,
		sload = 1'b0,
		sset = 1'b0,
		time_to_clear = compare_result,
		updown_dir = updown;
endmodule //altera_soft_lvds_tx_sbRNZ_cntr_a5d


//lpm_shiftreg CBX_DECLARE_ALL_CONNECTED_PORTS="OFF" CBX_SINGLE_OUTPUT_FILE="ON" LPM_DIRECTION="RIGHT" LPM_WIDTH=5 clock data load shiftin shiftout
//VERSION_BEGIN 20.1 cbx_lpm_shiftreg 2020:11:11:17:06:45:SJ cbx_mgl 2020:11:11:17:08:38:SJ  VERSION_END

//synthesis_resources = reg 5 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
module  altera_soft_lvds_tx_sbRNZ_shift_reg_bod
	( 
	clock,
	data,
	load,
	shiftin,
	shiftout) /* synthesis synthesis_clearbox=1 */;
	input   clock;
	input   [4:0]  data;
	input   load;
	input   shiftin;
	output   shiftout;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0   [4:0]  data;
	tri0   load;
	tri1   shiftin;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	reg	[4:0]	shift_reg;
	wire  [4:0]  shift_node;

	// synopsys translate_off
	initial
		shift_reg = 0;
	// synopsys translate_on
	always @ ( posedge clock)
		
			if (load == 1'b1) shift_reg <= data;
			else  shift_reg <= shift_node;
	assign
		shift_node = {shiftin, shift_reg[4:1]},
		shiftout = shift_reg[0];
endmodule //altera_soft_lvds_tx_sbRNZ_shift_reg_bod

//synthesis_resources = IO 3 lut 3 reg 53 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
module  altera_soft_lvds_tx_sbRNZ
	( 
	tx_coreclock,
	tx_in,
	tx_inclock,
	tx_locked,
	tx_out,
	tx_outclock,
	tx_syncclock) /* synthesis synthesis_clearbox=1 */;
	output   tx_coreclock;
	input   [29:0]  tx_in;
	input   tx_inclock;
	output   tx_locked;
	output   [2:0]  tx_out;
	output   tx_outclock;
	input   tx_syncclock;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0   tx_syncclock;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire  [2:0]   wire_ddio_out_dataout;
	reg	dffe11;
	reg	[2:0]	dffe3a;
	reg	[2:0]	dffe4a;
	reg	[2:0]	dffe5a;
	reg	[2:0]	dffe6a;
	reg	[2:0]	dffe7a;
	reg	[2:0]	dffe8a;
	reg	sync_dffe1a;
	wire  wire_cmpr10_aeb;
	wire  wire_cmpr9_aeb;
	wire  [2:0]   wire_cntr2_q;
	wire  wire_shift_reg12_shiftout;
	wire  wire_shift_reg13_shiftout;
	wire  wire_shift_reg14_shiftout;
	wire  wire_shift_reg15_shiftout;
	wire  wire_shift_reg16_shiftout;
	wire  wire_shift_reg17_shiftout;
	wire  fast_clock;
	wire  [2:0]  h_input;
	wire  [2:0]  l_input;
	wire  load_signal;
	wire  slow_clock;
	wire  [29:0]  tx_in_wire;

	altera_soft_lvds_tx_sbRNZ_ddio_out_vbd   ddio_out
	( 
	.datain_h(l_input),
	.datain_l(h_input),
	.dataout(wire_ddio_out_dataout),
	.outclock(fast_clock));
	// synopsys translate_off
	initial
		dffe11 = 0;
	// synopsys translate_on
	always @ ( posedge fast_clock)
		  dffe11 <= ((wire_cmpr9_aeb & sync_dffe1a) | (wire_cmpr10_aeb & (~ sync_dffe1a)));
	// synopsys translate_off
	initial
		dffe3a = 0;
	// synopsys translate_on
	always @ ( posedge fast_clock)
		if (sync_dffe1a == 1'b1)   dffe3a <= wire_cntr2_q;
	// synopsys translate_off
	initial
		dffe4a = 0;
	// synopsys translate_on
	always @ ( posedge fast_clock)
		if (sync_dffe1a == 1'b0)   dffe4a <= wire_cntr2_q;
	// synopsys translate_off
	initial
		dffe5a = 0;
	// synopsys translate_on
	always @ ( posedge fast_clock)
		if (sync_dffe1a == 1'b1)   dffe5a <= dffe3a;
	// synopsys translate_off
	initial
		dffe6a = 0;
	// synopsys translate_on
	always @ ( posedge fast_clock)
		if (sync_dffe1a == 1'b0)   dffe6a <= dffe4a;
	// synopsys translate_off
	initial
		dffe7a = 0;
	// synopsys translate_on
	always @ ( posedge fast_clock)
		if (sync_dffe1a == 1'b0)   dffe7a <= dffe5a;
	// synopsys translate_off
	initial
		dffe8a = 0;
	// synopsys translate_on
	always @ ( posedge fast_clock)
		if (sync_dffe1a == 1'b1)   dffe8a <= dffe6a;
	// synopsys translate_off
	initial
		sync_dffe1a = 0;
	// synopsys translate_on
	always @ ( posedge slow_clock)
		  sync_dffe1a <= (~ sync_dffe1a);
	altera_soft_lvds_tx_sbRNZ_cmpr_jqb   cmpr10
	( 
	.aeb(wire_cmpr10_aeb),
	.dataa(dffe4a),
	.datab(dffe8a));
	altera_soft_lvds_tx_sbRNZ_cmpr_jqb   cmpr9
	( 
	.aeb(wire_cmpr9_aeb),
	.dataa(dffe3a),
	.datab(dffe7a));
	altera_soft_lvds_tx_sbRNZ_cntr_a5d   cntr2
	( 
	.clock(fast_clock),
	.q(wire_cntr2_q),
	.updown(sync_dffe1a));
	altera_soft_lvds_tx_sbRNZ_shift_reg_bod   shift_reg12
	( 
	.clock(fast_clock),
	.data({tx_in_wire[1], tx_in_wire[3], tx_in_wire[5], tx_in_wire[7], tx_in_wire[9]}),
	.load(load_signal),
	.shiftin(1'b0),
	.shiftout(wire_shift_reg12_shiftout));
	altera_soft_lvds_tx_sbRNZ_shift_reg_bod   shift_reg13
	( 
	.clock(fast_clock),
	.data({tx_in_wire[0], tx_in_wire[2], tx_in_wire[4], tx_in_wire[6], tx_in_wire[8]}),
	.load(load_signal),
	.shiftin(1'b0),
	.shiftout(wire_shift_reg13_shiftout));
	altera_soft_lvds_tx_sbRNZ_shift_reg_bod   shift_reg14
	( 
	.clock(fast_clock),
	.data({tx_in_wire[11], tx_in_wire[13], tx_in_wire[15], tx_in_wire[17], tx_in_wire[19]}),
	.load(load_signal),
	.shiftin(1'b0),
	.shiftout(wire_shift_reg14_shiftout));
	altera_soft_lvds_tx_sbRNZ_shift_reg_bod   shift_reg15
	( 
	.clock(fast_clock),
	.data({tx_in_wire[10], tx_in_wire[12], tx_in_wire[14], tx_in_wire[16], tx_in_wire[18]}),
	.load(load_signal),
	.shiftin(1'b0),
	.shiftout(wire_shift_reg15_shiftout));
	altera_soft_lvds_tx_sbRNZ_shift_reg_bod   shift_reg16
	( 
	.clock(fast_clock),
	.data({tx_in_wire[21], tx_in_wire[23], tx_in_wire[25], tx_in_wire[27], tx_in_wire[29]}),
	.load(load_signal),
	.shiftin(1'b0),
	.shiftout(wire_shift_reg16_shiftout));
	altera_soft_lvds_tx_sbRNZ_shift_reg_bod   shift_reg17
	( 
	.clock(fast_clock),
	.data({tx_in_wire[20], tx_in_wire[22], tx_in_wire[24], tx_in_wire[26], tx_in_wire[28]}),
	.load(load_signal),
	.shiftin(1'b0),
	.shiftout(wire_shift_reg17_shiftout));
	assign
		fast_clock = tx_inclock,
		h_input = {wire_shift_reg17_shiftout, wire_shift_reg15_shiftout, wire_shift_reg13_shiftout},
		l_input = {wire_shift_reg16_shiftout, wire_shift_reg14_shiftout, wire_shift_reg12_shiftout},
		load_signal = dffe11,
		slow_clock = tx_syncclock,
		tx_in_wire = tx_in,
		tx_out = wire_ddio_out_dataout;
endmodule //altera_soft_lvds_tx_sbRNZ
//VALID FILE

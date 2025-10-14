
// contains a cut down interface to ease interfacing with VHDL for tricky types

module hazard3_cpu_1port_dom 
//#(
//parameter RESET_VECTOR        = 32'h00000000,
//parameter MTVEC_INIT          = 32'h00000000,
//parameter EXTENSION_A         = 1,
//parameter EXTENSION_C         = 1,
//parameter EXTENSION_M         = 1,
//parameter EXTENSION_ZBA       = 0,
//parameter EXTENSION_ZBB       = 0,
//parameter EXTENSION_ZBC       = 0,
//parameter EXTENSION_ZBS       = 0,
//parameter EXTENSION_ZBKB      = 0,
//parameter EXTENSION_ZCB       = 0,
//parameter EXTENSION_ZCMP      = 0,
//parameter EXTENSION_ZIFENCEI  = 0,
//parameter EXTENSION_XH3BEXTM  = 0,
//parameter EXTENSION_XH3IRQ    = 0,
//parameter EXTENSION_XH3PMPM   = 0,
//parameter EXTENSION_XH3POWER  = 0,
//parameter CSR_M_MANDATORY     = 1,
//parameter CSR_M_TRAP          = 1,
//parameter CSR_COUNTER         = 0,
//parameter U_MODE              = 0,
//
////PMP regions ignored
//
//parameter DEBUG_SUPPORT       = 0,
//parameter BREAKPOINT_TRIGGERS = 0,
//parameter NUM_IRQS            = 1,
//parameter IRQ_PRIORITY_BITS   = 0,
//
////IRQ_INPUT_BYPASS ignored
//parameter IRQ_INPUT_BYPASS    = {(NUM_IRQS > 0 ? NUM_IRQS : 1){1'b0}},
//
////ID registers ignored
//
//parameter REDUCED_BYPASS      = 0,
//parameter MULDIV_UNROLL       = 1,
//parameter MUL_FAST            = 0,
//parameter MUL_FASTER          = 0,
//parameter MULH_FAST           = 0,
//parameter FAST_BRANCHCMP      = 1,
//parameter RESET_REGFILE       = 0,
//parameter BRANCH_PREDICTOR    = 0,
//parameter MTVEC_WMASK         = 32'hfffffffd,
//

//) (
(
	// Global signals
	input wire                clk,
	input wire                clk_always_on,
	input wire                rst_n,

	// Power control signals
	output wire               pwrup_req,
	input  wire               pwrup_ack,
	output wire               clk_en,
	output wire               unblock_out,
	input  wire               unblock_in,

	// AHB5 Master port
	output reg  [31:0]  haddr,
	output reg                hwrite,
	output reg  [1:0]         htrans,
	output reg  [2:0]         hsize,
	output wire [2:0]         hburst,
	output reg  [3:0]         hprot,
	output wire               hmastlock,
	output reg  [7:0]         hmaster,
	output reg                hexcl,
	input  wire               hready,
	input  wire               hresp,
	input  wire               hexokay,
	output wire [31:0]  hwdata,
	input  wire [31:0]  hrdata,

	// Debugger run/halt control
	input  wire               dbg_req_halt,
	input  wire               dbg_req_halt_on_reset,
	input  wire               dbg_req_resume,
	output wire               dbg_halted,
	output wire               dbg_running,
	// Debugger access to data0 CSR
	input  wire [31:0]  dbg_data0_rdata,
	output wire [31:0]  dbg_data0_wdata,
	output wire               dbg_data0_wen,
	// Debugger instruction injection
	input  wire [31:0]  dbg_instr_data,
	input  wire               dbg_instr_data_vld,
	output wire               dbg_instr_data_rdy,
	output wire               dbg_instr_caught_exception,
	output wire               dbg_instr_caught_ebreak,

	// Optional debug system bus access patch-through
	input  wire [31:0]  dbg_sbus_addr,
	input  wire               dbg_sbus_write,
	input  wire [1:0]         dbg_sbus_size,
	input  wire               dbg_sbus_vld,
	output wire               dbg_sbus_rdy,
	output wire               dbg_sbus_err,
	input  wire [31:0]  dbg_sbus_wdata,
	output wire [31:0]  dbg_sbus_rdata,

	// Level-sensitive interrupt sources
	input wire [2:0] irq,       // -> mip.meip
	input wire                soft_irq,  // -> mip.msip
	input wire                timer_irq  // -> mip.mtip
);


endmodule


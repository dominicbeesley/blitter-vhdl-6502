## Generated SDC file "mk2blit.out.sdc"

## Copyright (C) 2018  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel FPGA IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Intel and sold by Intel or its authorized distributors.  Please
## refer to the applicable agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 18.1.0 Build 625 09/12/2018 SJ Lite Edition"

## DATE    "Mon Apr 29 16:55:28 2019"

##
## DEVICE  "EP4CE10F17C8"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {CLK_48M} -period 20.833 -waveform { 0.000 10.416 } [get_ports {CLK_48M_i}]


#**************************************************************
# Create Generated Clock
#**************************************************************


set MAINPLL {e_top|e_fb_clocks|\g_not_sim_pll:e_pll|altpll_component|auto_generated|pll1}
create_generated_clock -name {main_pll} -duty_cycle 50/1 -multiply_by 8 -divide_by 3 \
	-source [get_pins "$MAINPLL|inclk[0]"] \
	-master_clock {CLK_48M} \
	[get_pins "$MAINPLL|clk[0]"] 

create_generated_clock -name {snd_pll} -duty_cycle 50/1 -multiply_by 80 -divide_by 1083 \
	-source [get_pins "$MAINPLL|inclk[0]"] \
	-master_clock {CLK_48M} \
	[get_pins "$MAINPLL|clk[1]"] 



#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

derive_clock_uncertainty


#**************************************************************
# Set Input Delay
#**************************************************************

set_input_delay -source_latency_included -clock [get_clocks {main_pll}]  5.500 [get_ports {MEM_D_io*}]


#**************************************************************
# Set Output Delay
#**************************************************************

set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -max 3.500 [get_ports {MEM_A_o*}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -max 3.500 [get_ports {MEM_D_io*}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -max 3.500 [get_ports {MEM_nOE_o}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -max 3.500 [get_ports {MEM_nWE_o}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -max 3.500 [get_ports {MEM_FL_nCE_o}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -max 3.500 [get_ports {MEM_RAM_nCE_o*}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -min 0.000 [get_ports {MEM_A_o*}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -min 0.000 [get_ports {MEM_D_io*}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -min 0.000 [get_ports {MEM_nOE_o}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -min 0.000 [get_ports {MEM_nWE_o}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -min 0.000 [get_ports {MEM_FL_nCE_o}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -min 0.000 [get_ports {MEM_RAM_nCE_o*}]



#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

#set_false_path -from [get_keepers {*flancter*rst_flop}] -to [get_keepers {*flancter*set_flop}]
#set_false_path -from [get_keepers {*flancter*set_flop}] -to [get_keepers {*flancter*flag_out}]
#set_false_path -from [get_keepers {*flancter*set_flop}] -to [get_keepers {*flancter*rst_flop}]
#set_false_path -from {fb_syscon:e_fb_syscon|r_rst_state.run} -to [get_keepers {*flancter*rst_flop}]
#set_false_path -from {fb_syscon:e_fb_syscon|r_rst_state.run} -to [get_keepers {*flancter*set_flop}]

set_false_path -from [get_registers {e_top|e_fb_cpu|r_cpu_en_t65} ]
set_false_path -from [get_registers {e_top|e_fb_cpu|r_cpu_en_6x09} ]
#set_false_path -from [get_registers {e_top|e_fb_cpu|r_cpu_en_z80} ]
#set_false_path -from [get_registers {e_top|e_fb_cpu|r_cpu_en_68k} ]
#set_false_path -from [get_registers {e_top|e_fb_cpu|r_cpu_en_6502} ]
#set_false_path -from [get_registers {e_top|e_fb_cpu|r_cpu_en_65c02} ]
set_false_path -from [get_registers {e_top|e_fb_cpu|r_cpu_en_6800} ]
set_false_path -from [get_registers {e_top|e_fb_cpu|r_cpu_en_65816} ]
set_false_path -from [get_registers {e_top|e_fb_cpu|r_cpu_en_t65} ]
set_false_path -from [get_registers {e_top|e_fb_cpu|r_cfg_cpubits*} ]
set_false_path -from [get_registers {e_top|e_fb_cpu|r_cfg_hard_cpu_type.*} ]
set_false_path -from [get_registers {e_top|e_fb_cpu|r_cpu_run_ix*} ]

#**************************************************************
# Set Multicycle Path
#**************************************************************

#cpu multi-cycles
set t65paths [ get_pins {e_top|e_fb_cpu|\gt65:e_t65|e_cpu|*|*} ]
set t65regs  [ get_pins {e_top|e_fb_cpu|\gt65:e_t65|e_cpu|*|*} ]

set_multicycle_path -setup -end -from  $t65paths  -to  $t65paths 2
set_multicycle_path -hold -end -from  $t65paths   -to  $t65paths 1

set_multicycle_path -setup -end -from  $t65regs 2
set_multicycle_path -hold -end -from  $t65regs 1

## #blitter addr calcs multi-cycles
## 
## set blitpaths [ get_pins {e_top|\GCHIPSET:GBLIT:e_fb_blit|addr_gen|*|*} ]
## set blitpaths2 [ get_registers {e_top|\GCHIPSET:GBLIT:e_fb_blit|*} ]
## 
## set_multicycle_path -setup -end -from  $blitpaths  -to  $blitpaths 2
## set_multicycle_path -hold -end -from  $blitpaths  -to  $blitpaths 1
## 
## set_multicycle_path -setup -end -from  $blitpaths2  -to  $blitpaths 2
## set_multicycle_path -hold -end -from  $blitpaths2  -to  $blitpaths 1
## 
## 
## #aeris - not thoroughly checked!
## 
## set aeris {e_top|\GCHIPSET:GAERIS:e_fb_aeris}
## set aeris_src_regs [get_registers "$aeris|r_op*"] 
## set aeris_ptr_regs [get_registers "$aeris|r_pointers*"]
## set aeris_ctr_regs [get_registers "$aeris|r_counters*"]
## 
## set_multicycle_path -setup -end -from  $aeris_src_regs  -to  $aeris_ptr_regs 2
## set_multicycle_path -hold -end -from  $aeris_src_regs  -to  $aeris_ptr_regs 1
## 
## set_multicycle_path -setup -end -from  $aeris_src_regs  -to  $aeris_ctr_regs 2
## set_multicycle_path -hold -end -from  $aeris_src_regs  -to  $aeris_ctr_regs 1
## 
## set_multicycle_path -setup -end -from  $aeris_ptr_regs  -to  $aeris_ptr_regs 2
## set_multicycle_path -hold -end -from  $aeris_ptr_regs  -to  $aeris_ptr_regs 1
## 
## set_multicycle_path -setup -end -from  $aeris_ctr_regs  -to  $aeris_ctr_regs 2
## set_multicycle_path -hold -end -from  $aeris_ctr_regs  -to  $aeris_ctr_regs 1


#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************


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

### foreach_in_collection x [get_registers {fb_cpu:e_fb_cpu|r_cpu_en_t65}] { puts [get_register_info -name $x] }


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {CLK_50M} -period 20.000 -waveform { 0.000 10.000 } [get_ports {CLK_50M_i}]


#**************************************************************
# Create Generated Clock
#**************************************************************


create_generated_clock -name {main_pll} -source [get_pins {e_fb_clocks|\g_not_sim_pll:e_pll|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50/1 -multiply_by 64 -divide_by 25 -master_clock {CLK_50M} [get_pins {e_fb_clocks|\g_not_sim_pll:e_pll|altpll_component|auto_generated|pll1|clk[0]}] 
create_generated_clock -name {snd_pll} -source [get_pins {e_fb_clocks|\g_not_sim_pll:e_pll|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50/1 -multiply_by 128 -divide_by 1805 -master_clock {CLK_50M} [get_pins {e_fb_clocks|\g_not_sim_pll:e_pll|altpll_component|auto_generated|pll1|clk[1]}] 


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



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

set_false_path -from [get_clocks {snd_pll}] -to [get_clocks {main_pll}]

#set_false_path -from [get_keepers {*flancter*rst_flop}] -to [get_keepers {*flancter*set_flop}]
#set_false_path -from [get_keepers {*flancter*set_flop}] -to [get_keepers {*flancter*flag_out}]
#set_false_path -from [get_keepers {*flancter*set_flop}] -to [get_keepers {*flancter*rst_flop}]
#set_false_path -from {fb_syscon:e_fb_syscon|r_rst_state.run} -to [get_keepers {*flancter*rst_flop}]
#set_false_path -from {fb_syscon:e_fb_syscon|r_rst_state.run} -to [get_keepers {*flancter*set_flop}]

set_false_path -from [get_registers {fb_cpu:*|r_cpu_en_*} ]
set_false_path -from [get_registers {fb_cpu:*|r_hard_cpu_en} ]
set_false_path -from [get_registers {fb_cpu:*|r_do_sys_via_block} ]
set_false_path -from [get_registers {fb_cpu:*|r_cpu_run_ix*} ]

#**************************************************************
# Set Multicycle Path
#**************************************************************

#cpu multi-cycles
#set t65paths [ get_pins {e_top|e_fb_cpu|\gt65:e_t65|e_cpu|*|*} ]
set t65regs  [ get_registers {*|T65:e_cpu|*} ]

#set_multicycle_path -setup -end -from  $t65paths  -to  $t65paths 2
#set_multicycle_path -hold -end -from  $t65paths   -to  $t65paths 1

set_multicycle_path -setup -end -from  $t65regs 2
set_multicycle_path -hold -end -from  $t65regs 1

#blitter addr calcs multi-cycles

set blitpaths [ get_registers {*|blit_addr:addr_gen|r_addr_out*} ]

set_multicycle_path -setup -end -to  $blitpaths 2
set_multicycle_path -hold -end -to  $blitpaths 1


#aeris - not thoroughly checked!

set aeris {e_top|\GCHIPSET:GAERIS:e_fb_aeris}
set aeris_src_regs [get_registers "$aeris|r_op*"] 
set aeris_ptr_regs [get_registers "$aeris|r_pointers*"]
set aeris_ctr_regs [get_registers "$aeris|r_counters*"]

set_multicycle_path -setup -end -from  $aeris_src_regs  -to  $aeris_ptr_regs 2
set_multicycle_path -hold -end -from  $aeris_src_regs  -to  $aeris_ptr_regs 1

set_multicycle_path -setup -end -from  $aeris_src_regs  -to  $aeris_ctr_regs 2
set_multicycle_path -hold -end -from  $aeris_src_regs  -to  $aeris_ctr_regs 1

set_multicycle_path -setup -end -from  $aeris_ptr_regs  -to  $aeris_ptr_regs 2
set_multicycle_path -hold -end -from  $aeris_ptr_regs  -to  $aeris_ptr_regs 1

set_multicycle_path -setup -end -from  $aeris_ctr_regs  -to  $aeris_ctr_regs 2
set_multicycle_path -hold -end -from  $aeris_ctr_regs  -to  $aeris_ctr_regs 1


#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************


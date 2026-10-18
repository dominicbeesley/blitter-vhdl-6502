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

set MAINPLL {e_fb_clocks|\g_not_sim_pll:e_pll|altpll_component|auto_generated|pll1}
create_generated_clock -name {main_pll} -duty_cycle 50/1 -multiply_by 8 -divide_by 3 \
	-source [get_pins "$MAINPLL|inclk[0]"] \
	-master_clock {CLK_48M} \
	[get_pins "$MAINPLL|clk[0]"] 

create_generated_clock -name {snd_pll} -duty_cycle 50/1 -multiply_by 80 -divide_by 1083 \
	-source [get_pins "$MAINPLL|inclk[0]"] \
	-master_clock {CLK_48M} \
	[get_pins "$MAINPLL|clk[1]"] 

set HDMIPLL {fb_HDMI:\G_HDMI:e_fb_HDMI|vid15tohdmi:e_vid15tohdmi|pll_hdmi:\g_not_sim_pll:e_pll_hdmi|altpll:altpll_component|pll_hdmi_altpll:auto_generated|pll1}
create_generated_clock -name {hdmi_tmds} -duty_cycle 50/1 -multiply_by 45 -divide_by 8 \
	-source [get_pins "$HDMIPLL|inclk[0]"] \
	-master_clock {CLK_48M} \
	[get_pins "$HDMIPLL|clk[0]"] 
create_generated_clock -name {hdmi_pixel} -duty_cycle 50/1 -multiply_by 9 -divide_by 8 \
	-source [get_pins "$HDMIPLL|inclk[0]"] \
	-master_clock {CLK_48M} \
	[get_pins "$HDMIPLL|clk[1]"] 


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

derive_clock_uncertainty

#**************************************************************
# Fitter-only over-constraint
#**************************************************************
# The fitter stops improving a path once it meets its constraint. This makes
# the fitter (only) see main_pll as slightly faster, so it keeps working on
# paths just past zero slack. quartus_sta, and so the Makefile timing check,
# doesn't run this block and signs off against the real period.
# Must come after main_pll is created. Comment out to switch off.

if { $::TimeQuestInfo(nameofexecutable) eq "quartus_fit" } {
   set_clock_uncertainty -add -setup 0.3 -from [get_clocks {main_pll}] -to [get_clocks {main_pll}]
}


#**************************************************************
# Set Input Delay
#**************************************************************

set_input_delay -source_latency_included -clock [get_clocks {main_pll}]  5.000 [get_ports {MEM_D_io*}]


#**************************************************************
# Set Output Delay
#**************************************************************

set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -max 2.000 [get_ports {MEM_A_o*}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -max 2.000 [get_ports {MEM_D_io*}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -max 2.000 [get_ports {MEM_nOE_o}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -max 2.000 [get_ports {MEM_nWE_o}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -max 2.000 [get_ports {MEM_FL_nCE_o}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -max 2.000 [get_ports {MEM_RAM_nCE_o*}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -min 0.000 [get_ports {MEM_A_o*}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -min 0.000 [get_ports {MEM_D_io*}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -min 0.000 [get_ports {MEM_nOE_o}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -min 0.000 [get_ports {MEM_nWE_o}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -min 0.000 [get_ports {MEM_FL_nCE_o}]
set_output_delay -source_latency_included -clock [get_clocks {main_pll}] -min 0.000 [get_ports {MEM_RAM_nCE_o*}]



#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group [get_clocks {main_pll}] -group [get_clocks {CLK_48M}] 
set_clock_groups -asynchronous -group [get_clocks {main_pll}] -group [get_clocks {hdmi_pixel}] 
set_clock_groups -asynchronous -group [get_clocks {CLK_48M}] -group [get_clocks {hdmi_pixel}] 


#**************************************************************
# Set False Path
#**************************************************************

set_false_path -from [get_clocks {snd_pll}] -to [get_clocks {main_pll}]

#set_false_path -from [get_keepers {*flancter*rst_flop}] -to [get_keepers {*flancter*set_flop}]
#set_false_path -from [get_keepers {*flancter*set_flop}] -to [get_keepers {*flancter*flag_out}]
#set_false_path -from [get_keepers {*flancter*set_flop}] -to [get_keepers {*flancter*rst_flop}]
#set_false_path -from {fb_syscon:e_fb_syscon|r_rst_state.run} -to [get_keepers {*flancter*rst_flop}]
#set_false_path -from {fb_syscon:e_fb_syscon|r_rst_state.run} -to [get_keepers {*flancter*set_flop}]


set_false_path -from [get_registers {r_cfg_swromx} ]
set_false_path -from [get_registers {r_cfg_mosram} ]
set_false_path -from [get_registers {r_cfg_swram_enable} ]
set_false_path -from [get_registers {r_cfg_cpu_use_t65} ]
set_false_path -from [get_registers {r_cfg_mk2_cpubits*} ]
set_false_path -from [get_registers {r_cfg_cpu_type.*} ]
set_false_path -from [get_registers {r_cfg_cpu_speed_opt.*} ]

set_false_path -from [get_registers {e_fb_cpu|r_cpu_en_*} ]
set_false_path -from [get_registers {e_fb_cpu|r_cpu_run_ix*} ]


#**************************************************************
# Set Multicycle Path
#**************************************************************

#cpu multi-cycles
set t65regs  [ get_registers {e_fb_cpu|\gt65:e_t65|e_cpu|*} ]

# cross-check these against the setting in fb_CPU/fb_CPU_t65
set_multicycle_path -setup -end -from  $t65regs  -to  $t65regs 4
set_multicycle_path -hold -end -from  $t65regs   -to  $t65regs 3

#blitter addr calcs multi-cycles

set blit {fb_chipset:\GCHIPSET:e_chipset|fb_dmac_blit:\GBLIT:e_fb_blit}

# Register reads: r_per_addr is loaded on A_stb, act_rd0 waits a clock, and
# r_per_D_rd only captures in act_rd, so the read mux has 2 clocks.
set blit_rd [get_registers "$blit|r_per_D_rd*"]
set_multicycle_path -setup -end -from [get_registers "$blit|*"] -to $blit_rd 2
set_multicycle_path -hold  -end -from [get_registers "$blit|*"] -to $blit_rd 1

# Address calc: the inputs (r_blit_state, channel address/stride/width regs)
# change in the same edge as r_clken_addr_calc_start; blit_addr goes to calc
# a clock later and loads r_addr_out from i_addr_next the clock after that.
# Excludes the start strobe itself and blit_addr's own state, which act each clock.
set blit_addr_src [remove_from_collection [get_registers "$blit|r_*"] \
                                          [get_registers "$blit|r_clken_addr_calc_start"]]
set blit_addr_out [get_registers "$blit|blit_addr:addr_gen|r_addr_out*"]
set_multicycle_path -setup -end -from $blit_addr_src -to $blit_addr_out 2
set_multicycle_path -hold  -end -from $blit_addr_src -to $blit_addr_out 1


# NOTE: the Aeries no longer needs multi_cycle_paths!


#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************


//Copyright (C)2014-2025 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11 (64-bit) 
//Created Time: 2025-06-03 13:02:33
create_clock -name CLK_27M -period 37.037 -waveform {0 18.518} [get_ports {brd_clk_27M_i}]

create_generated_clock -name CLOCK_48M -source [get_ports {brd_clk_27M_i}] -master_clock CLK_27M -divide_by 9 -multiply_by 16 [get_nets {i_clk_pll_48M}]
create_generated_clock -name CLOCK_128M -source [get_nets {i_clk_pll_48M}] -master_clock CLOCK_48M -divide_by 3 -multiply_by 8 [get_nets {i_clk_pll_128M}]

create_generated_clock -name CLOCK_TMDS_HDMI -source [get_nets {i_clk_pll_48M}] -master_clock CLOCK_48M -divide_by 16 -multiply_by 90 [get_nets {G_HDMI.e_fb_HDMI/e_vid15tohdmi/i_clk_hdmi_tmds}]
create_generated_clock -name CLOCK_PIXEL_HDMI -source [get_nets {G_HDMI.e_fb_HDMI/e_vid15tohdmi/i_clk_hdmi_tmds}] -master_clock CLOCK_TMDS_HDMI -divide_by 5 -multiply_by 1 [get_nets {G_HDMI.e_fb_HDMI/e_vid15tohdmi/i_clk_hdmi_pixel}]

create_generated_clock -name CLOCK_360M  -source [get_nets {i_clk_pll_128M}] -master_clock CLOCK_128M -divide_by 16 -multiply_by 45 [get_nets {i_clk_pll_360M}]

create_generated_clock -name CLOCK_72M  -source [get_nets {i_clk_pll_360M}] -master_clock CLOCK_360M -divide_by 5 -multiply_by 1 [get_nets {i_clk_div_72M}]

## actually generated but div/mul too large
##TODO: reenable for real chroma
create_clock -name CLOCK_CHROMA -period 56.387347 -waveform {0 28.19367} [get_nets {G_DO1BIT_DAC_VIDEO.e_chroma_gen/i_clk_chroma_x4}]

##TODO: bodge for no chroma
#create_generated_clock -name CLOCK_SOUND -source [get_nets {i_clk_pll_128M}] -master_clock CLOCK_128M -divide_by 64000 -multiply_by 3547 [get_nets {i_clk_snd}]

#**************************************************************
# Set Clock Groups
#**************************************************************

#set_clock_groups -asynchronous -group [get_clocks {CLOCK_128M}] -group [get_clocks {CLOCK_48M}] 
set_clock_groups -asynchronous -group [get_clocks {CLOCK_128M}] -group [get_clocks {CLOCK_PIXEL_HDMI}] 
set_clock_groups -asynchronous -group [get_clocks {CLOCK_48M}] -group [get_clocks {CLOCK_PIXEL_HDMI}] 

#set_clock_groups -asynchronous -group [get_clocks {CLOCK_SOUND}] -group [get_clocks {CLOCK_128M}] 
set_clock_groups -asynchronous -group [get_clocks {CLOCK_48M}] -group [get_clocks {CLOCK_CHROMA}] 

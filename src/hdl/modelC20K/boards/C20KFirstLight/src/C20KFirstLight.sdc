
set_operating_conditions -grade c -model slow -speed 8 -setup
set_operating_conditions -grade c -model fast -speed 8 -hold

# board clock @ 27M
create_clock -name CLOCK_27M -period 37.037 -waveform {0 18.518} [get_ports {brd_clk_27M_i}]

create_generated_clock -name CLOCK_360M -source [get_ports {brd_clk_27M_i}] -master_clock CLOCK_27M -divide_by 3 -multiply_by 40 [get_nets {i_clk_pll_360M}]

create_generated_clock -name CLOCK_384M -source [get_nets {i_clk_pll_360M}] -master_clock CLOCK_360M -divide_by 15 -multiply_by 16 [get_nets {i_clk_pll_384M}]
create_generated_clock -name CLOCK_128M -source [get_nets {i_clk_pll_360M}] -master_clock CLOCK_360M -divide_by 45 -multiply_by 16 [get_nets {i_clk_pll_128M}]

create_generated_clock -name CLOCK_96M -source [get_nets {i_clk_pll_384M}] -master_clock CLOCK_384M -divide_by 4 -multiply_by 1 [get_nets {i_clk_div_96M}]
create_generated_clock -name CLOCK_48M -source [get_nets {i_clk_div_96M}] -master_clock CLOCK_96M -divide_by 2 -multiply_by 1 [get_nets {i_clk_div_48M}]


create_generated_clock -name CLOCK_TMDS_HDMI -source [get_nets {i_clk_div_48M}] -master_clock CLOCK_48M -divide_by 16 -multiply_by 45 [get_nets {G_HDMI.e_fb_HDMI/e_vid15tohdmi/i_clk_hdmi_tmds}]
create_generated_clock -name CLOCK_PIXEL_HDMI -source [get_nets {G_HDMI.e_fb_HDMI/e_vid15tohdmi/i_clk_hdmi_tmds}] -master_clock CLOCK_TMDS_HDMI -divide_by 5 -multiply_by 1 [get_nets {G_HDMI.e_fb_HDMI/e_vid15tohdmi/i_clk_hdmi_pixel}]

create_generated_clock -name CLOCK_72M  -source [get_nets {i_clk_pll_360M}] -master_clock CLOCK_360M -divide_by 5 -multiply_by 1 [get_nets {i_clk_div_72M}]

## actually generated but div/mul too large
##TODO: reenable for real chroma
create_clock -name CLOCK_CHROMA_x4_jitter -period 56.387347 -waveform {0 28.19367} [get_nets {i_clk_chroma_x4_jitter}]
create_generated_clock -name CLOCK_SOUND -source [get_nets {i_clk_chroma_x4_jitter}] -master_clock CLOCK_CHROMA_x4_jitter -divide_by 5 -multiply_by 1 [get_nets {i_clk_snd}]
# chroma DAC clocks (from pll_pal_sc and its CLKDIVs), as in C20K.sdc
create_generated_clock -name CLOCK_CHROMA_x60 -source [get_nets {i_clk_chroma_x4_jitter}] -master_clock CLOCK_CHROMA_x4_jitter -divide_by 1 -multiply_by 15 [get_nets {i_clk_chroma_x60_dac}]
create_generated_clock -name CLOCK_CHROMA_x20 -source [get_nets {i_clk_chroma_x4_jitter}] -master_clock CLOCK_CHROMA_x4_jitter -divide_by 1 -multiply_by 5 [get_nets {i_clk_chroma_x20_dac}]
create_generated_clock -name CLOCK_CHROMA_x12 -source [get_nets {i_clk_chroma_x60_dac}] -master_clock CLOCK_CHROMA_x60 -divide_by 5 -multiply_by 1 [get_nets {i_clk_chroma_x12_px}]
create_generated_clock -name CLOCK_CHROMA_x4 -source [get_nets {i_clk_chroma_x20_dac}] -master_clock CLOCK_CHROMA_x20 -divide_by 5 -multiply_by 1 [get_nets {i_clk_chroma_x4}]


##TODO: bodge for no chroma
#create_generated_clock -name CLOCK_SOUND -source [get_nets {i_clk_pll_128M}] -master_clock CLOCK_128M -divide_by 64000 -multiply_by 3547 [get_nets {i_clk_snd}]

#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group [get_clocks {CLOCK_128M}] -group [get_clocks {CLOCK_48M}] 
set_clock_groups -asynchronous -group [get_clocks {CLOCK_128M}] -group [get_clocks {CLOCK_PIXEL_HDMI}] 
set_clock_groups -asynchronous -group [get_clocks {CLOCK_48M}] -group [get_clocks {CLOCK_PIXEL_HDMI}] 

#set_clock_groups -asynchronous -group [get_clocks {CLOCK_SOUND}] -group [get_clocks {CLOCK_128M}] 
set_clock_groups -asynchronous -group [get_clocks {CLOCK_48M}] -group [get_clocks {CLOCK_CHROMA_x4_jitter}] 
set_clock_groups -asynchronous -group [get_clocks {CLOCK_48M}] -group [get_clocks {CLOCK_CHROMA_x4}] 

# 1-bit mono DACs (dac1_oserx2): r_pattern (48M) -> r_pat0..2 (72M). The
# frequencies are locked (2:3) but the phase between the 384M/4/2 and the
# 360M/5 CLKDIVs is set by start-up, so a synchronous analysis is fiction.
# TODO (clock-group review): the crossing itself is not phase-safe.
set_clock_groups -asynchronous -group [get_clocks {CLOCK_48M}] -group [get_clocks {CLOCK_72M}] 

set_multicycle_path -from [get_regs {e_fb_cpu_t65only/e_t65/e_cpu/*}] -to [get_regs {e_fb_cpu_t65only/e_t65/e_cpu/*}]  -setup -end 4
set_multicycle_path -from [get_regs {e_fb_cpu_t65only/e_t65/e_cpu/*}] -to [get_regs {e_fb_cpu_t65only/e_t65/e_cpu/*}]  -hold -end 3

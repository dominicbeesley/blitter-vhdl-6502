//Board clock
create_clock -name sys_clk_50 -period 20 [get_nets {sys_clk_50_i}]       // 50 Mhz
create_generated_clock -name CLOCK_48M -source [get_ports {sys_clk_50_i}] -master_clock sys_clk_50 -divide_by 25 -multiply_by 24 [get_nets {i_clk_pll_48M}]
create_generated_clock -name CLOCK_128M -source [get_nets {i_clk_pll_48M}] -master_clock CLOCK_48M -divide_by 3 -multiply_by 8 [get_nets {i_clk_pll_128M}]

create_generated_clock -name CLOCK_TMDS_HDMI -source [get_nets {i_clk_pll_48M}] -master_clock CLOCK_48M -divide_by 16 -multiply_by 90 [get_nets {G_HDMI.e_fb_HDMI/e_vid15tohdmi/i_clk_hdmi_tmds}]
create_generated_clock -name CLOCK_PIXEL_HDMI -source [get_nets {G_HDMI.e_fb_HDMI/e_vid15tohdmi/i_clk_hdmi_tmds}] -master_clock CLOCK_TMDS_HDMI -divide_by 5 -multiply_by 1 [get_nets {G_HDMI.e_fb_HDMI/e_vid15tohdmi/i_clk_hdmi_pixel}]
#**************************************************************
# Set Clock Groups
#**************************************************************

#set_clock_groups -asynchronous -group [get_clocks {CLOCK_128M}] -group [get_clocks {CLOCK_48M}] 
set_clock_groups -asynchronous -group [get_clocks {CLOCK_128M}] -group [get_clocks {CLOCK_PIXEL_HDMI}] 
set_clock_groups -asynchronous -group [get_clocks {CLOCK_48M}] -group [get_clocks {CLOCK_PIXEL_HDMI}] 


set_multicycle_path -from [get_regs {e_fb_cpu_t65only/e_t65/e_cpu/*}] -to [get_regs {e_fb_cpu_t65only/e_t65/e_cpu/*}]  -setup -end 4
set_multicycle_path -from [get_regs {e_fb_cpu_t65only/e_t65/e_cpu/*}] -to [get_regs {e_fb_cpu_t65only/e_t65/e_cpu/*}]  -hold -end 3

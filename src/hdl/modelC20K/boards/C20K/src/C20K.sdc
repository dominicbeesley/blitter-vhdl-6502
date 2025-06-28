
set_operating_conditions -grade c -model fast -speed 8

# board clock @ 27M
create_clock -name CLK_27M -period 37.037 -waveform {0 18.518} [get_ports {brd_clk_27M_i}]

create_generated_clock -name CLOCK_48M -source [get_ports {brd_clk_27M_i}] -master_clock CLK_27M -divide_by 9 -multiply_by 16 [get_nets {i_clk_pll_48M}]
create_generated_clock -name CLOCK_128M -source [get_nets {i_clk_pll_48M}] -master_clock CLOCK_48M -divide_by 3 -multiply_by 8 [get_nets {i_fb_syscon.clk}]

create_generated_clock -name CLOCK_135M_HDMI -source [get_nets {i_clk_pll_48M}] -master_clock CLOCK_48M -divide_by 16 -multiply_by 45 [get_nets {G_HDMI.e_fb_HDMI/i_clk_hdmi_tmds}]
create_generated_clock -name CLOCK_27M_HDMI -source [get_nets {G_HDMI.e_fb_HDMI/i_clk_hdmi_tmds}] -master_clock CLOCK_135M_HDMI -divide_by 5 -multiply_by 1 [get_nets {G_HDMI.e_fb_HDMI/i_clk_hdmi_pixel}]


#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group [get_clocks {CLOCK_128M}] -group [get_clocks {CLOCK_48M}] 
set_clock_groups -asynchronous -group [get_clocks {CLOCK_128M}] -group [get_clocks {CLOCK_27M_HDMI}] 
set_clock_groups -asynchronous -group [get_clocks {CLOCK_48M}] -group [get_clocks {CLOCK_27M_HDMI}] 

set_multicycle_path -from [get_regs {e_fb_cpu_t65only/e_t65/e_cpu/*}] -to [get_regs {e_fb_cpu_t65only/e_t65/e_cpu/*}]  -setup 2
set_multicycle_path -from [get_regs {e_fb_cpu_t65only/e_t65/e_cpu/*}] -to [get_regs {e_fb_cpu_t65only/e_t65/e_cpu/*}]  -hold 1


set_multicycle_path -from [get_regs {GCHIPSET.e_chipset/GBLIT.e_fb_blit/*}] -to [get_regs {GCHIPSET.e_chipset/GBLIT.e_fb_blit/*}] -setup 2
set_multicycle_path -from [get_regs {GCHIPSET.e_chipset/GBLIT.e_fb_blit/addr_gen/*}] -to [get_regs {GCHIPSET.e_chipset/GBLIT.e_fb_blit/*}] -setup 2
set_multicycle_path -from [get_regs {GCHIPSET.e_chipset/GBLIT.e_fb_blit/*}] -to [get_regs {GCHIPSET.e_chipset/GBLIT.e_fb_blit/addr_gen/*}] -setup 2
set_multicycle_path -from [get_regs {GCHIPSET.e_chipset/GBLIT.e_fb_blit/addr_gen/*}] -to [get_regs {GCHIPSET.e_chipset/GBLIT.e_fb_blit/addr_gen/*}] -setup 2

set_multicycle_path -from [get_regs {GCHIPSET.e_chipset/GBLIT.e_fb_blit/*}] -to [get_regs {GCHIPSET.e_chipset/GBLIT.e_fb_blit/*}] -hold 1
set_multicycle_path -from [get_regs {GCHIPSET.e_chipset/GBLIT.e_fb_blit/addr_gen/*}] -to [get_regs {GCHIPSET.e_chipset/GBLIT.e_fb_blit/*}] -hold 1
set_multicycle_path -from [get_regs {GCHIPSET.e_chipset/GBLIT.e_fb_blit/*}] -to [get_regs {GCHIPSET.e_chipset/GBLIT.e_fb_blit/addr_gen/*}] -hold 1
set_multicycle_path -from [get_regs {GCHIPSET.e_chipset/GBLIT.e_fb_blit/addr_gen/*}] -to [get_regs {GCHIPSET.e_chipset/GBLIT.e_fb_blit/addr_gen/*}] -hold 1



report_timing -setup -max_paths 1000 -max_common_paths 1

#report_timing -setup -from_clock [get_clocks {CLOCK_128M}] -to_clock [get_clocks {CLOCK_128M}] -from [get_pins {g_intcon_shared.e_fb_intcon/ir_p2c_ack_0_s0/Q}] -to [get_pins {GCHIPSET.e_chipset/GAERIS.e_fb_aeris/r_pointers_r_pointers_RAMREG_3_G[10]_s0/CE}]

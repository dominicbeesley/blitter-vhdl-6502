//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.09 Education
//Created Time: 2023-04-29 19:28:56
create_clock -name brd_clk -period 37.037 -waveform {0 18.518} [get_ports {clk_27_i}]
create_generated_clock -name main_pll -source [get_ports {clk_27_i}] -master_clock brd_clk -divide_by 4 -multiply_by 19 [get_nets {i_clk_pll128}]

create_generated_clock -name baud16 -source [get_nets {i_clk_pll128}] -master_clock main_pll -divide_by 6666 [get_nets {e_xylon/r_clk_baud16_4}]

create_generated_clock -name baud16tx -source [get_nets {e_xylon/r_clk_baud16_4}] -master_clock baud16 -divide_by 16 [get_nets {e_xylon/e_fb_uart/r_clk_div[3]}]

set_multicycle_path -from [get_regs {e_xylon/e_fb_cpu_t65only/e_t65/e_cpu/*}] -to [get_regs {e_xylon/e_fb_cpu_t65only/e_t65/e_cpu/*}]  -setup -end 2
set_multicycle_path -from [get_regs {e_xylon/e_fb_cpu_t65only/e_t65/e_cpu/*}] -to [get_regs {e_xylon/e_fb_cpu_t65only/e_t65/e_cpu/*}]  -hold -end 1


set_false_path -from [get_clocks {main_pll}] -to [get_clocks {baud16}]
set_false_path -from [get_clocks {main_pll}] -to [get_clocks {baud16tx}]
set_false_path -from [get_clocks {baud16}] -to [get_clocks {main_pll}]
set_false_path -from [get_clocks {baud16tx}] -to [get_clocks {main_pll}]

set_operating_conditions -grade c -model fast -speed 6

//Copyright (C)2014-2025 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11 (64-bit) 
//Created Time: 2025-06-03 13:02:33
create_clock -name CLK_27M -period 37.037 -waveform {0 18.518} [get_ports {brd_clk_27M_i}]

create_generated_clock -name CLOCK_48M -source [get_ports {brd_clk_27M_i}] -master_clock CLK_27M -divide_by 9 -multiply_by 16 [get_nets {i_clk_pll_48M}]
create_generated_clock -name CLOCK_128M -source [get_nets {i_clk_pll_48M}] -master_clock CLOCK_48M -divide_by 3 -multiply_by 8 [get_nets {i_fb_syscon.clk}]

set_multicycle_path -from [get_regs {e_fb_cpu_t65only/e_t65/e_cpu/*}] -to [get_regs {e_fb_cpu_t65only/e_t65/e_cpu/*}]  -setup -end 2
set_multicycle_path -from [get_regs {e_fb_cpu_t65only/e_t65/e_cpu/*}] -to [get_regs {e_fb_cpu_t65only/e_t65/e_cpu/*}]  -hold -end 1

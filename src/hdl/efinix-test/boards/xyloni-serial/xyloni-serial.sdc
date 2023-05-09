#create_clock -period 7.8125 -name fb_clk [get_ports clk_128_pll_i]

#TESTING: ACTUALLY 64MHz (runs ok but doesn't meet timing closure)
create_clock -period 15.625 -name fb_clk [get_ports clk_128_pll_i]

create_generated_clock -source clk_128_pll_i -divide_by 6666 -name baud16 r_clk_baud16

set_false_path -from [get_clocks fb_clk] -to [get_clocks baud16]
set_false_path -from [get_clocks baud16] -to [get_clocks fb_clk]


set t65regs  [ get_pins {e_fb_cpu_t65only/e_t65/e_cpu*|*} ] [ get_pins {e_fb_cpu_t65only/e_t65/i_t65_RnW*} ]

set_multicycle_path -setup -end -from  $t65regs  -to  $t65regs 2
set_multicycle_path -hold -end -from  $t65regs   -to  $t65regs 1

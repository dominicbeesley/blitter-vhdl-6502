onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_SYS/SYS_A_i
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_SYS/SYS_D_io
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/MEM_A_o
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/MEM_D_io
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/MEM_FL_nCE_o
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/MEM_nOE_o
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/MEM_nWE_o
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/MEM_RAM_nCE_o
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/i_wrap_A_log
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/i_wrap_phys_A
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_cpu/A
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_cpu/D
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_cpu/PHI2
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_cpu/RnW
add wave -noupdate /sim_65816_tb/e_cpu/VDA
add wave -noupdate /sim_65816_tb/e_cpu/VPA
add wave -noupdate /sim_65816_tb/e_cpu/VPB
add wave -noupdate /sim_65816_tb/e_cpu/e_t65816cput/Sync
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/i_wrap_ack
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/i_wrap_cyc
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/i_wrap_D_rd
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/i_wrap_D_WR
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/i_wrap_we
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/r_acked
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/r_D_rd
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/r_iorb_block
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/r_iorb_block_ctdn
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/r_iorb_cs
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/r_iorb_resetctr
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/r_nmi
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/r_nmi_meta
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/r_state
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/r_wrap_cyc
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/r_wrap_D_WR
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/r_wrap_D_WR_stb
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/r_wrap_phys_A
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_daughter/e_top/e_fb_cpu/r_wrap_we
add wave -noupdate /sim_65816_tb/e_SYS/G_BBC_CK/e_bbc_clk_gen/e_IC34A/clk
add wave -noupdate /sim_65816_tb/e_SYS/G_BBC_CK/e_bbc_clk_gen/e_IC34A/clr
add wave -noupdate /sim_65816_tb/e_SYS/G_BBC_CK/e_bbc_clk_gen/e_IC34A/d
add wave -noupdate /sim_65816_tb/e_SYS/G_BBC_CK/e_bbc_clk_gen/e_IC34A/nq
add wave -noupdate /sim_65816_tb/e_SYS/G_BBC_CK/e_bbc_clk_gen/e_IC34A/pre
add wave -noupdate /sim_65816_tb/e_SYS/G_BBC_CK/e_bbc_clk_gen/e_IC34A/q
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_blit_rom_512/A
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_blit_rom_512/D
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_blit_rom_512/i_A_DLY
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_blit_rom_512/i_A_nCS_DLY
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_blit_rom_512/i_D
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_blit_rom_512/i_D_in_dly
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_blit_rom_512/i_data
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_blit_rom_512/i_nCS_OE_dly
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_blit_rom_512/i_nOE_dly
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_blit_rom_512/i_nWE_dly
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_blit_rom_512/nCS
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_blit_rom_512/nOE
add wave -noupdate -radix hexadecimal /sim_65816_tb/e_blit_rom_512/nWE
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {324264659 ps} 0} {{Cursor 2} {110919354 ps} 0}
quietly wave cursor active 2
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {110695478 ps} {112159792 ps}

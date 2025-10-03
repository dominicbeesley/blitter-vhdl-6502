from vunit import VUnit

GOWIN = "C:/Gowin/Gowin_V1.9.11_x64/IDE/simlib/gw2a"

def encode(tb_cfg):
    return ", ".join(["%s:%s" % (key, str(tb_cfg[key])) for key in tb_cfg])

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib = vu.add_library("lib")

#lib.add_source_files(GOWIN + "/prim_sim.vhd")

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("./*.vhd")
lib.add_source_files("../../board/*.vhd")
lib.add_source_files("../../../shared/c20k_peripheral_mux_ctl.vhd")
lib.add_source_files("../../../shared/fb_SYS_c20k.vhd")
lib.add_source_files("../../../../library/bbc/*.vhd")
lib.add_source_files("../../../../library/simulation/hct574.vhd")
lib.add_source_files("../../../../library/simulation/ac245.vhd")
lib.add_source_files("../../../../library/simulation/cy74FCT2543.vhd")
lib.add_source_files("../../../../library/simulation/ls74245.vhd")
lib.add_source_files("../../../../library/simulation/real65816_tb.vhd")
lib.add_source_files("../../../../library/common.vhd")
lib.add_source_files("../../../../library/fishbone/fishbone_pack.vhd")
lib.add_source_files("../../../../simulation_shared/fb_tester_pack.vhd")

lib.add_source_files("../../../boards/C20kFirstLight816/src/address_decode_C20KFirstLight.vhd")
lib.add_source_files("../../../boards/C20kFirstLight816/src/board_config_pack.vhd")
lib.add_source_files("../../../boards/C20kFirstLight816/src/C20KFirstLight816.vhd")
lib.add_source_files("../../../boards/C20kFirstLight816/src/fb_CPU_log2phys_C20KFirstLight.vhd")
lib.add_source_files("../../../boards/C20kFirstLight816/src/fb_c20k_mem_cpu_65816.vhd")
lib.add_source_files("../../../boards/C20kFirstLight816/src/fb_P20K_MEM.vhd")
lib.add_source_files("../../../shared/ws2812_pack.vhd")
lib.add_source_files("../../../shared/ws2812.vhd")
lib.add_source_files("../../../shared/fb_ws2812.vhd")

lib.add_source_files("../../../../shared/fb_CPU_pack.vhd")
lib.add_source_files("../../../../shared/fb_CPU_t65.vhd")

lib.add_source_files("../../../../shared/fb_CPU_con_burst.vhd")

lib.add_source_files("../../../../library/bbc/bbc_slow_cyc.vhd")
lib.add_source_files("../../../../library/fishbone/fb_syscon.vhd")

lib.add_source_files("../../../../library/fishbone/fishbone_pack.vhd")
lib.add_source_files("../../../../library/fishbone/fb_intcon_one_to_many.vhd")
lib.add_source_files("../../../../library/fishbone/fb_null.vhd")

lib.add_source_files("../../../../library/clockreg.vhd")
lib.add_source_files("../../../../library/common.vhd")
lib.add_source_files("../../../../shared/fb_SYS_pack.vhd")
lib.add_source_files("../../../../shared/fb_SYS_VIA_blocker.vhd")

lib.add_source_files("../../../../library/3rdparty/MikeStirling/m6522.vhd")
lib.add_source_files("../../../../library/3rdparty/MikeStirling/sn76489.vhd")
lib.add_source_files("../../../../library/fishbone/fb_intcon_pack.vhd")
lib.add_source_files("../../../../shared/fb_uart.vhd")

lib.add_source_files("../../../../library/uart_tx.vhd")
lib.add_source_files("../../../../library/uart_rx.vhd")

lib.add_source_files("../../../../library/simulation/ram_tb.vhd")
lib.add_source_files("../../../../library/simulation/rom_tb.vhd")
lib.add_source_files("../../../../library/3rdparty/P65C816/*.vhd")


fmf = vu.add_library("fmf")

fmf.add_source_files("../../../../library/3rdparty/fmf/*.vhd")

vu.set_sim_option("disable_ieee_warnings",1)

# Run vunit function
vu.main()

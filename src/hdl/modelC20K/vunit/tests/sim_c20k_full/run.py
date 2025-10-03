from vunit import VUnit

GOWIN = "C:/Gowin/Gowin_V1.9.12_x64/IDE/simlib/gw2a"

def encode(tb_cfg):
    return ", ".join(["%s:%s" % (key, str(tb_cfg[key])) for key in tb_cfg])

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib = vu.add_library("lib")

lib.add_source_files(GOWIN + "/prim_sim.vhd")

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
lib.add_source_files("../../../../library/common.vhd")
lib.add_source_files("../../../../library/fishbone/fishbone_pack.vhd")
lib.add_source_files("../../../../simulation_shared/fb_tester_pack.vhd")

lib.add_source_files("../../../boards/C20k/version.vhd")
lib.add_source_files("../../../boards/C20k/src/C20K.vhd") 
lib.add_source_files("../../../boards/C20k/src/gowin_dpb/hdmi_blockram.vhd")
lib.add_source_files("../../../boards/C20k/src/gowin_rpll/pll_27_48.vhd")
lib.add_source_files("../../../boards/C20k/src/gowin_rpll/pll_48_128.vhd")
lib.add_source_files("../../../boards/C20k/src/gowin_rpll/pll_hdmi.vhd") 
lib.add_source_files("../../../boards/C20k/src/gowin_sdpb/linebuffer.vhd")
lib.add_source_files("../../../boards/C20k/src/board_config_pack.vhd")
lib.add_source_files("../../../boards/C20k/src/gowin_rpll/pll_pal_sc.vhd")
lib.add_source_files("../../../boards/C20k/src/gowin_rpll/pll_rgb_dac.vhd")
lib.add_source_files("../../../boards/C20k/src/fb_CPU_t65only.vhd")
lib.add_source_files("../../../shared/ws2812_pack.vhd")
lib.add_source_files("../../../shared/ws2812.vhd")
lib.add_source_files("../../../shared/fb_ws2812.vhd")

lib.add_source_files("../../../shared/1bitvid/dac1_oser.vhd")
lib.add_source_files("../../../shared/1bitvid/dac1_oserx2.vhd")
lib.add_source_files("../../../shared/1bitvid/dossy_chroma.vhd")

lib.add_source_files("../../../../shared/firmware_info_pack.vhd")
lib.add_source_files("../../../../shared/fb_CPU_pack.vhd")
lib.add_source_files("../../../../shared/fb_CPU_t65.vhd")

lib.add_source_files("../../../../shared/fb_cpu_log2phys.vhd")
lib.add_source_files("../../../../shared/fb_CPU_con_burst.vhd")
lib.add_source_files("../../../../shared/log2phys.vhd")
lib.add_source_files("../../../../shared/address_decode.vhd")
lib.add_source_files("../../../../shared/fb_i2c.vhd")
lib.add_source_files("../../../../mk3/shared/fb_MEM.vhd")
lib.add_source_files("../../../../shared/fb_memctl.vhd")

lib.add_source_files("../../../../shared/address_decode_chipset.vhd")
lib.add_source_files("../../../../chipset/fb_chipset_pack.vhd")
lib.add_source_files("../../../../chipset/fb_chipset.vhd")
lib.add_source_files("../../../../chipset/blit_types.vhd")
lib.add_source_files("../../../../chipset/blit_int.vhd")
lib.add_source_files("../../../../chipset/blit_addr.vhd")
lib.add_source_files("../../../../chipset/aeris.vhd")
lib.add_source_files("../../../../chipset/dmac_int_sound.vhd")
lib.add_source_files("../../../../chipset/dmac_int_sound_cha.vhd")
lib.add_source_files("../../../../chipset/dac_1bit.vhd")
lib.add_source_files("../../../../chipset/dmac_int_dma.vhd")
lib.add_source_files("../../../../chipset/dmac_int_dma_cha.vhd")

lib.add_source_files("../../../../library/bbc/bbc_slow_cyc.vhd")
lib.add_source_files("../../../../library/fishbone/fb_syscon.vhd")

lib.add_source_files("../../../../library/fishbone/fishbone_pack.vhd")
lib.add_source_files("../../../../library/fishbone/fb_intcon_many_to_one.vhd")
lib.add_source_files("../../../../library/fishbone/fb_intcon_one_to_many.vhd")
lib.add_source_files("../../../../library/fishbone/fb_arbiter_prior.vhd")
lib.add_source_files("../../../../library/fishbone/fb_arbiter_roundrobin.vhd")
lib.add_source_files("../../../../library/fishbone/fb_intcon_shared.vhd")
lib.add_source_files("../../../../library/fishbone/fb_null.vhd")

lib.add_source_files("../../../../library/clockreg.vhd")
lib.add_source_files("../../../../library/common.vhd")
lib.add_source_files("../../../../library/3rdparty/T6502/T65.vhd")
lib.add_source_files("../../../../library/3rdparty/T6502/T65_MCode.vhd")
lib.add_source_files("../../../../library/3rdparty/T6502/T65_ALU.vhd")
lib.add_source_files("../../../../library/3rdparty/T6502/T65_Pack.vhd")
lib.add_source_files("../../../../shared/fb_SYS_pack.vhd")
lib.add_source_files("../../../../shared/fb_SYS_VIA_blocker.vhd")
lib.add_source_files("../../../../shared/fb_VERSION.vhd")

lib.add_source_files("../../../../library/3rdparty/MikeStirling/m6522.vhd")
lib.add_source_files("../../../../library/3rdparty/MikeStirling/sn76489.vhd")
lib.add_source_files("../../../../library/3rdparty/MikeStirling/serialula.vhd")
lib.add_source_files("../../../../library/3rdparty/MikeStirling/acia6850.vhd")
lib.add_source_files("../../../../library/fishbone/fb_intcon_pack.vhd")
lib.add_source_files("../../../../shared/fb_uart.vhd")

lib.add_source_files("../../../../library/uart_tx.vhd")
lib.add_source_files("../../../../library/uart_rx.vhd")

lib.add_source_files("../../../../library/3rdparty/hdmi_alexey_spirkov/encoder.vhd")
lib.add_source_files("../../../../library/3rdparty/hdmi_alexey_spirkov/hdmi.vhd")
lib.add_source_files("../../../../library/3rdparty/hdmi_alexey_spirkov/hdmidataencoder.v")
lib.add_source_files("../../../../library/3rdparty/hdmi_alexey_spirkov/hdmidelay.vhd")
lib.add_source_files("../../../shared/hdmi//hdmi_out_gowin_2A.vhd")

lib.add_source_files("../../../shared/hdmi/dvi_synchro.vhd")
lib.add_source_files("../../../../library/3rdparty/MikeStirling/mc6845.vhd")
lib.add_source_files("../../../shared/hdmi/fb_HDMI_crtc.vhd")
lib.add_source_files("../../../../library/3rdparty/MikeStirling/vidproc_model_bc.vhd")
lib.add_source_files("../../../../library/3rdparty/MikeStirling/saa5050.vhd")
lib.add_source_files("../../../../library/3rdparty/MikeStirling/saa5050_rom_dual_port_dom.vhd")
lib.add_source_files("../../../shared/hdmi/fb_HDMI_vidproc.vhd")
lib.add_source_files("../../../shared/hdmi/fb_HDMI_ram.vhd")
lib.add_source_files("../../../shared/hdmi/HDMI_pack.vhd")
lib.add_source_files("../../../shared/hdmi/fb_HDMI_enabled.vhd")
lib.add_source_files("../../../shared/hdmi/fb_HDMI_ctl.vhd")
lib.add_source_files("../../../shared/hdmi/fb_HDMI_seq_ctl.vhd")
lib.add_source_files("../../../shared/hdmi/sprites/sprites_pack.vhd")
lib.add_source_files("../../../shared/hdmi/sprites/fb_sprites.vhd")
lib.add_source_files("../../../shared/hdmi/sprites/sprites.vhd")
lib.add_source_files("../../../shared/hdmi/sprites/sprite_int.vhd")
lib.add_source_files("../../../shared/hdmi/vidmem_sequencer.vhd")
lib.add_source_files("../../../shared/hdmi/vid15tohdmi.vhd")

lib.add_source_files("../../../../library/simulation/ram_tb.vhd")
lib.add_source_files("../../../../library/simulation/rom_tb.vhd")

fmf = vu.add_library("fmf")

fmf.add_source_files("../../../../library/3rdparty/fmf/*.vhd")

lib816 = vu.add_library("lib816")
lib816.add_source_files("../../../../library/3rdparty/P65C816/*.vhd")
lib816.add_source_files("../../../../library/simulation/real65816_tb.vhd")

vu.set_sim_option("disable_ieee_warnings",1)

# Run vunit function
vu.main()

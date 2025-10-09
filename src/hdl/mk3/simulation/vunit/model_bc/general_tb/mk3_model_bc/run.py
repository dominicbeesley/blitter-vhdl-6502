from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib = vu.add_library("lib")

# Add all files ending in .vhd in current working directory to library

root = "../../../../../../"

# Board specific files

lib.add_source_file(root + "mk3/boards/cpu-16-model-bc/board_config_pack.vhd")
lib.add_source_file(root + "mk3/boards/cpu-16-model-bc/version.vhd")
lib.add_source_file(root + "mk3/boards/cpu-16-model-bc/pllmain.vhd")
lib.add_source_file(root + "mk3/boards/cpu-16-model-bc/fb_SYS_model_BC.vhd")
lib.add_source_file(root + "mk3/boards/cpu-16-model-bc/log2phys_model_BC.vhd")
lib.add_source_file(root + "mk3/boards/cpu-16-model-bc/mk3blit_model_BC.vhd")


# video / HDMI stuff

lib.add_source_file(root + "mk3/shared/hdmi/dd_out.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/dvi_synchro.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/fb_HDMI_crtc.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/fb_HDMI_ctl.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/fb_HDMI_enabled.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/fb_HDMI_ram.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/fb_HDMI_seq_ctl.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/fb_HDMI_vidproc.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/hdmi_blockram.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/HDMI_pack.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/linebuffer.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/pll_hdmi.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/sprites/fb_sprites.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/sprites/sprites.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/sprites/sprites_pack.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/sprites/sprite_int.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/vidmem_sequencer.vhd")

lib.add_source_file(root + "library/3rdparty/MikeStirling/vidproc_model_bc.vhd")
lib.add_source_file(root + "library/3rdparty/MikeStirling/mc6845.vhd")
lib.add_source_file(root + "library/3rdparty/MikeStirling/saa5050.vhd")
lib.add_source_file(root + "library/3rdparty/MikeStirling/saa5050_rom_dual_port_dom.vhd")


# Base project files

lib.add_source_file(root + "mk3/shared/hdmi/HDMI_pack.vhd")
lib.add_source_file(root + "shared/firmware_info_pack.vhd")
lib.add_source_file(root + "library/fishbone/fishbone_pack.vhd")
lib.add_source_file(root + "library/fishbone/fb_syscon.vhd")
lib.add_source_file(root + "library/fishbone/fb_intcon_pack.vhd")
lib.add_source_file(root + "library/common.vhd")
lib.add_source_file(root + "library/fishbone/fb_intcon_many_to_one.vhd")
lib.add_source_file(root + "library/fishbone/fb_intcon_one_to_many.vhd")
lib.add_source_file(root + "library/fishbone/fb_arbiter_prior.vhd")
lib.add_source_file(root + "library/fishbone/fb_arbiter_roundrobin.vhd")
lib.add_source_file(root + "library/fishbone/fb_intcon_shared.vhd")
lib.add_source_file(root + "library/fishbone/fb_null.vhd")
lib.add_source_file(root + "library/metadelay.vhd")
lib.add_source_file(root + "library/clockreg.vhd")
lib.add_source_file(root + "library/bbc/bbc_slow_cyc.vhd")
lib.add_source_file(root + "library/3rdparty/T6502/T65_Pack.vhd")
lib.add_source_file(root + "library/3rdparty/T6502/T65_MCode.vhd")
lib.add_source_file(root + "library/3rdparty/T6502/T65_ALU.vhd")
lib.add_source_file(root + "library/3rdparty/T6502/T65.vhd")
lib.add_source_file(root + "shared/fb_SYS_pack.vhd")


lib.add_source_file(root + "shared/fb_SYS_phigen.vhd")
lib.add_source_file(root + "shared/fb_SYS_VIA_blocker.vhd")
lib.add_source_file(root + "shared/fb_SYS_clock_dll.vhd")
lib.add_source_file(root + "shared/fb_VERSION.vhd")
lib.add_source_file(root + "mk3/shared/fb_CPU_exp_pack.vhd")
lib.add_source_file(root + "shared/fb_CPU_pack.vhd")
lib.add_source_file(root + "shared/fb_CPU_t65.vhd")
lib.add_source_file(root + "mk3/shared/fb_CPU_6x09_exp_pins.vhd")
lib.add_source_file(root + "shared/fb_CPU_6x09.vhd")
lib.add_source_file(root + "mk3/shared/fb_CPU_65816_exp_pins.vhd")
lib.add_source_file(root + "shared/fb_CPU_65816.vhd")
lib.add_source_file(root + "mk3/shared/fb_CPU_65C02_exp_pins.vhd")
lib.add_source_file(root + "shared/fb_CPU_65C02.vhd")
lib.add_source_file(root + "mk3/shared/fb_CPU_680x0_exp_pins.vhd")
lib.add_source_file(root + "shared/fb_CPU_680x0.vhd")
lib.add_source_file(root + "mk3/shared/fb_CPU_arm2_exp_pins.vhd")
lib.add_source_file(root + "shared/fb_CPU_arm2.vhd")
lib.add_source_file(root + "mk3/shared/fb_CPU_z180_exp_pins.vhd")
lib.add_source_file(root + "shared/fb_CPU_z180.vhd")
lib.add_source_file(root + "mk3/shared/fb_CPU_6800_exp_pins.vhd")
lib.add_source_file(root + "shared/fb_CPU_6800.vhd")
lib.add_source_file(root + "mk3/shared/fb_CPU_80188_exp_pins.vhd")
lib.add_source_file(root + "shared/fb_CPU_80188.vhd")
lib.add_source_file(root + "shared/fb_cpu_con_burst.vhd")
lib.add_source_file(root + "shared/fb_CPU.vhd")
lib.add_source_file(root + "shared/fb_CPU_log2phys.vhd")
lib.add_source_file(root + "shared/address_decode.vhd")
lib.add_source_file(root + "mk3/shared/clocks_pll.vhd")
lib.add_source_file(root + "shared/fb_i2c.vhd")
lib.add_source_file(root + "mk3/shared/fb_MEM.vhd")
lib.add_source_file(root + "shared/fb_memctl.vhd")
lib.add_source_file(root + "shared/address_decode_chipset.vhd")
lib.add_source_file(root + "chipset/fb_chipset_pack.vhd")
lib.add_source_file(root + "chipset/fb_chipset.vhd")
lib.add_source_file(root + "chipset/dmac_int_sound.vhd")
lib.add_source_file(root + "chipset/dmac_int_sound_cha.vhd")
lib.add_source_file(root + "chipset/dac_1bit.vhd")
lib.add_source_file(root + "chipset/dmac_int_dma.vhd")
lib.add_source_file(root + "chipset/dmac_int_dma_cha.vhd")
lib.add_source_file(root + "chipset/aeris.vhd")
lib.add_source_file(root + "chipset/blit_addr.vhd")
lib.add_source_file(root + "chipset/blit_int.vhd")
lib.add_source_file(root + "chipset/blit_types.vhd")


# Sim files
lib.add_source_file(root + "library/common.vhd")
lib.add_source_file(root + "library/simulation/rom_tb.vhd")
lib.add_source_file(root + "library/simulation/ram_tb.vhd")
lib.add_source_file(root + "library/simulation/ls02.vhd")
lib.add_source_file(root + "library/simulation/ls04.vhd")
lib.add_source_file(root + "library/simulation/ls32.vhd")
lib.add_source_file(root + "library/simulation/ls51.vhd")
lib.add_source_file(root + "library/simulation/ls74.vhd")
lib.add_source_file(root + "library/simulation/bbc/bbc_clock_gen.vhd")
lib.add_source_file(root + "library/bbc/bbc_slow_cyc.vhd")
lib.add_source_file(root + "library/simulation/bbc/elk_clock_gen.vhd")
lib.add_source_file(root + "library/bbc/elk_slow_cyc.vhd")
lib.add_source_file(root + "simulation_shared/sim_SYS_pack.vhd")
lib.add_source_file(root + "simulation_shared/sim_SYS_tb.vhd")
lib.add_source_file(root + "library/3rdparty/MikeStirling/m6522.vhd")

lib.add_source_file(root + "mk3/simulation/sim_tb/sim_t65_model_bc_tb.vhd")

tb = lib.test_bench("sim_t65_model_bc_tb")
tb.set_generic("G_MOSROMFILE","../../" + root + "../sim_asm/test_asm_model_BC/build/model_bc.rom")


tb.set_sim_option("vhdl_assert_stop_level", "failure")
tb.set_sim_option("disable_ieee_warnings", True)

# Run vunit function
vu.main()
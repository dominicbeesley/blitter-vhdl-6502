from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib = vu.add_library("lib")

# Add all files ending in .vhd in current working directory to library

root = "../../../../../../../"


# Base project files
lib.add_source_file(root + "mk3/shared/hdmi/HDMI_pack.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/fb_HDMI_enabled.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/sprites/sprites_pack.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/sprites/sprites.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/sprites/sprite_int.vhd")

lib.add_source_file(root + "mk3/shared/hdmi/pll_hdmi.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/fb_hdmi_vidproc.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/fb_hdmi_crtc.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/fb_hdmi_ram.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/fb_hdmi_ctl.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/fb_hdmi_seq_ctl.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/dvi_synchro.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/linebuffer.vhd")
lib.add_source_file(root + "mk3/shared/hdmi/hdmi_blockram.vhd")

lib.add_source_file(root + "shared/fb_i2c.vhd")

lib.add_source_file(root + "library/3rdparty/MikeStirling/mc6845.vhd")
lib.add_source_file(root + "library/3rdparty/MikeStirling/saa5050.vhd")
lib.add_source_file(root + "library/3rdparty/MikeStirling/saa5050_rom_dual_port_dom.vhd")
lib.add_source_file(root + "library/3rdparty/MikeStirling/vidproc_model_bc.vhd")

lib.add_source_file(root + "library/fishbone/fishbone_pack.vhd")
lib.add_source_file(root + "library/fishbone/fb_intcon_one_to_many.vhd")
lib.add_source_file(root + "library/fishbone/fb_syscon.vhd")
lib.add_source_file(root + "library/common.vhd")
lib.add_source_file(root + "library/clockreg.vhd")
lib.add_source_file(root + "library/fishbone/fb_null.vhd")

# Sim files
lib.add_source_file("test_tb.vhd")

tb = lib.test_bench("test_tb")
#tb.set_generic("G_MOSROMFILE","../../" + root + "../sim_asm/test_asm_model_BC/build/model_bc.rom")


tb.set_sim_option("vhdl_assert_stop_level", "failure")
tb.set_sim_option("disable_ieee_warnings", True)

# Run vunit function
vu.main()
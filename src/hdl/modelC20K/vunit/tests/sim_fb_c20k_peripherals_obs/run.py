from vunit import VUnit


def encode(tb_cfg):
    return ", ".join(["%s:%s" % (key, str(tb_cfg[key])) for key in tb_cfg])

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib = vu.add_library("lib")

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("./*.vhd")
lib.add_source_files("../../board/*.vhd")
lib.add_source_files("../../../shared/c20k_peripheral_mux_ctl.vhd")
lib.add_source_files("../../../shared/fb_SYS_c20k.vhd")
lib.add_source_files("../../../../library/bbc/*.vhd")
lib.add_source_files("../../../../library/simulation/hct574.vhd")
lib.add_source_files("../../../../library/simulation/cy74FCT2543.vhd")
lib.add_source_files("../../../../library/simulation/ls74245.vhd")
lib.add_source_files("../../../../library/common.vhd")
lib.add_source_files("../../../../library/fishbone/fishbone_pack.vhd")
lib.add_source_files("../../../../simulation_shared/fb_tester_pack.vhd")

fmf = vu.add_library("fmf")

fmf.add_source_files("../../../../library/3rdparty/fmf/*.vhd")

vu.set_sim_option("disable_ieee_warnings",1)

# Run vunit function
vu.main()

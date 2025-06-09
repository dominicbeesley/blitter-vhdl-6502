from vunit import VUnit


def encode(tb_cfg):
    return ", ".join(["%s:%s" % (key, str(tb_cfg[key])) for key in tb_cfg])

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib = vu.add_library("lib")

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("./*.vhd")
lib.add_source_files("../../board/sim_peripherals_csel.vhd")
lib.add_source_files("../../library/*.vhd")

fmf = vu.add_library("fmf")

fmf.add_source_files("../../library/fmf/*.vhd")

vu.set_sim_option("disable_ieee_warnings",1)

# Run vunit function
vu.main()

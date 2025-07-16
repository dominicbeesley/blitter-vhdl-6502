from vunit import VUnit


def encode(tb_cfg):
    return ", ".join(["%s:%s" % (key, str(tb_cfg[key])) for key in tb_cfg])

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib = vu.add_library("lib")

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("./*.vhd")
lib.add_source_files("../../board/sim_cpu_mem.vhd")
lib.add_source_files("../../../../library/bbc/*.vhd")
lib.add_source_files("../../../../library/simulation/ac245.vhd")
lib.add_source_files("../../../../library/common.vhd")
lib.add_source_files("../../../../library/simulation/real65816_tb.vhd")
lib.add_source_files("../../../../library/simulation/rom_tb.vhd")
lib.add_source_files("../../../../library/simulation/ram_tb.vhd")
lib.add_source_files("../../../../library/3rdparty/Missing/P65C816/*.vhd")


fmf = vu.add_library("fmf")

fmf.add_source_files("../../../../library/3rdparty/fmf/*.vhd")

vu.set_sim_option("disable_ieee_warnings",1)

# Run vunit function
vu.main()

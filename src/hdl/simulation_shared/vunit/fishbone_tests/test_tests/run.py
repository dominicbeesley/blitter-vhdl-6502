from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib = vu.add_library("lib")

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("./*.vhd")
lib.add_source_files("../../../../library/fishbone/fishbone_pack.vhd")
lib.add_source_files("../../../../library/common.vhd")
lib.add_source_files("../../../../simulation_shared/sim_fb_per_mem.vhd")
lib.add_source_files("../../../fb_tester_pack.vhd")

# Run vunit function
vu.set_sim_option("modelsim.vsim_flags", ["-voptargs=+acc"])
vu.set_sim_option("disable_ieee_warnings",1)
vu.main()
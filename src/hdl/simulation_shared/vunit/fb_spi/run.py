from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib = vu.add_library("lib")

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("./*.vhd")
lib.add_source_files("../../../library/fishbone/fishbone_pack.vhd")
lib.add_source_files("../../../library/common.vhd")
lib.add_source_files("../../../shared/fb_spi.vhd")

# Run vunit function
vu.main()
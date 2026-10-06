from pathlib import Path
from vunit import VUnit

# paths are relative to this script so it can be run from anywhere
HERE = Path(__file__).resolve().parent
HDL = HERE / "../../../.."

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib = vu.add_library("lib")

# Add all files ending in .vhd in this directory to library
lib.add_source_files(str(HERE / "*.vhd"))
lib.add_source_files(str(HDL / "library/fishbone/fishbone_pack.vhd"))
lib.add_source_files(str(HDL / "library/fishbone/fb_intcon_one_to_many.vhd"))
lib.add_source_files(str(HDL / "library/common.vhd"))
lib.add_source_files(str(HDL / "simulation_shared/sim_fb_per_mem.vhd"))
lib.add_source_files(str(HDL / "simulation_shared/fb_tester_pack.vhd"))

# Run vunit function
vu.main()

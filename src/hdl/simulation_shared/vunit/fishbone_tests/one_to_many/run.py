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
lib.add_source_files(str(HDL / "library/fishbone/fb_intcon_buffer.vhd"))
lib.add_source_files(str(HDL / "library/common.vhd"))
lib.add_source_files(str(HDL / "simulation_shared/sim_fb_per_mem.vhd"))
lib.add_source_files(str(HDL / "simulation_shared/sim_fb_per_mem_pipe.vhd"))
lib.add_source_files(str(HDL / "simulation_shared/fb_tester_pack.vhd"))

# Buffer settings (G_REG_C2P, G_REG_P2C), applied to both buffers: the one
# between the controller and the interconnect, and the one in front of
# peripheral 1. "nobuf" checks that the buffers collapse to a pass-through.
BUFFERS = {
    "nobuf": (False, False),
    "c2p":   (True,  False),
    "p2c":   (False, True),
    "both":  (True,  True),
}

# cross_read and cross_write fill peripheral 1's queue, so they are also run
# with the interconnect's G_MAXOUT both above G_DEPTH (the peripheral limits
# the outstanding transactions) and below it (the interconnect limits them).
MAXOUTS = {
    "cross_read":  (15, 2),
    "cross_write": (15, 2),
}

# Adding a configuration removes a test's default one, so every test gets
# one configuration per buffer setting (and per G_MAXOUT where listed).
tb = lib.test_bench("test_tb")

for test in tb.get_tests():
    maxouts = MAXOUTS.get(test.name, (15,))
    for buf_name, (reg_c2p, reg_p2c) in BUFFERS.items():
        for maxout in maxouts:
            name = buf_name if len(maxouts) == 1 else f"{buf_name}_maxout{maxout}"
            test.add_config(
                name=name,
                generics=dict(
                    G_MAXOUT=maxout,
                    G_CON_REG_C2P=reg_c2p,
                    G_CON_REG_P2C=reg_p2c,
                    G_PER_REG_C2P=reg_c2p,
                    G_PER_REG_P2C=reg_p2c,
                ),
            )

# Run vunit function
vu.set_sim_option("modelsim.vsim_flags", ["-voptargs=+acc"])
vu.set_sim_option("disable_ieee_warnings",1)
vu.main()

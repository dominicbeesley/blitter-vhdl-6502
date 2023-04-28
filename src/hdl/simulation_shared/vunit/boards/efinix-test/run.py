from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib = vu.add_library("lib")

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("./*.vhd")
lib.add_source_files("../../../../library/clockreg.vhd")
lib.add_source_files("../../../../library/fishbone/fishbone_pack.vhd")
lib.add_source_files("../../../../library/fishbone/fb_intcon_pack.vhd")
lib.add_source_files("../../../../library/fishbone/fb_intcon_one_to_many.vhd")
lib.add_source_files("../../../../library/fishbone/fb_syscon.vhd")
lib.add_source_files("../../../../library/3rdparty/T6502/*.vhd")
lib.add_source_files("../../../../library/common.vhd")
lib.add_source_files("../../../../library/uart_tx.vhd")
lib.add_source_files("../../../../shared/fb_CPU_t65.vhd")
lib.add_source_files("../../../../shared/fb_uart.vhd")
lib.add_source_files("../../../../shared/fb_CPU_pack.vhd")
lib.add_source_files("../../../../shared/fb_CPU_con_burst.vhd")
lib.add_source_files("../../../../efinix-test/shared/*.vhd")
lib.add_source_files("../../../../efinix-test/boards/xyloni-serial/*.vhd")

# Run vunit function
vu.main()
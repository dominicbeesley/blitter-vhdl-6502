AS=vasmm68k_mot
ASFLAGS=-m68008 -spaces -ldots -I ../includes -D MACH_BEEB=1 -D MACH_CHIPKIT=0
BUILD=./build/

X:=$(shell mkdir -p $(BUILD))

TARGETS=$(BUILD)boot68008_testbench_mos.bin

all:: $(TARGETS)

$(BUILD)boot68008_testbench_mos.bin: boot68008_testbench_mos.asm
	$(AS) $(ASFLAGS) -Fbin -o $@ -L $(basename $@).lst $<

clean::
	-rm $(BUILD)* 

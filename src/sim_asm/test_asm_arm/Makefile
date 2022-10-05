AS=vasmarm_std.exe
ASFLAGS=-m2 -little -Fvobj

LD=vlink

BUILD=./build/

X:=$(shell mkdir -p $(BUILD))

TARGETS=$(BUILD)boot_arm_testbench_mos.bin
OBJECTS=boot_arm_testbench_mos.o
OBJECTS2=$(addprefix $(BUILD), $(OBJECTS))


all:: $(TARGETS)

$(BUILD)boot_arm_testbench_mos.bin: $(OBJECTS2)
	$(LD) -b rawbin1 -T boot_arm_testbench_mos.lnk.txt -o $@ $^

$(BUILD)%.o: %.asm
	$(AS) $(ASFLAGS) -o $@ -L $(basename $@).lst $<

clean::
	-rm $(BUILD)* 

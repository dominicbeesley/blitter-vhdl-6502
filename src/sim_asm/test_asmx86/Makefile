AS=nasm.exe
ASFLAGS=

TARGETS=bootx86_testbench_mos.rom

OBJS=bootx86_testbench_mos.o
OBJS2=$(addprefix obj/, $(OBJS))

BUILD=./build/

X:=$(shell mkdir -p $(BUILD))

all:: $(addprefix $(BUILD), $(TARGETS))


$(BUILD)bootx86_testbench_mos.rom: bootx86_testbench_mos.asm
	$(AS) $(ASFLAGS) -fbin -o $@ -l $(basename $@).lst $<

clean::
	-rm $(BUILD)
	
AS=vasmm68k_mot.exe
ASFLAGS=-m68008 -spaces -ldots -I ../includes -D MACH_BEEB=1 -D MACH_CHIPKIT=0

TARGETS=boot68008_testbench_mos.bin

OBJS=boot68008_testbench_mos.o
OBJS2=$(addprefix obj/, $(OBJS))
BUILD=./build

X:=$(shell mkdir -p $(BUILD))

all:: $(addprefix $(BUILD)/, $(TARGETS))


$(BUILD)/boot68008_testbench_mos.bin: boot68008_testbench_mos.asm
	$(AS) $(ASFLAGS) -Fbin -o $@ -L $(basename $@).lst $<

clean::
	-rm $(BUILD)/*
	
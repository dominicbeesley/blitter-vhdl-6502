AS=vasm6800_std_win32.exe
ASFLAGS=-m6800 

TARGETS=boot6800_testbench_mos.rom

OBJS=boot6800_testbench_mos.o
OBJS2=$(addprefix obj/, $(OBJS))
BUILD=./build

X:=$(shell mkdir -p $(BUILD))

all:: $(addprefix $(BUILD)/, $(TARGETS))


$(BUILD)/boot6800_testbench_mos.rom: boot6800_testbench_mos.asm
	$(AS) $(ASFLAGS) -Fbin -o $@ -L $(basename $@).lst $<

clean::
	-rm $(BUILD)/*
	
ASFLAGS=-v
AS=asm6809
DEPS=includes/hardware.inc includes/common.inc includes/mosrom.inc includes/oslib.inc
BUILD=./build

X:=$(shell mkdir -p $(BUILD))

all::	$(BUILD)/test_rom0.bin

$(BUILD)/%.bin:	%.asm $(DEPS)
	$(AS) $(ASFLAGS) -B -o $@ -l $(basename $@).lst $<

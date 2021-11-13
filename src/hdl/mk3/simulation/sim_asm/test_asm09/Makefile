ASFLAGS=-v
AS=asm6809
DEPS=includes/hardware.inc includes/common.inc includes/mosrom.inc includes/oslib.inc

all::	test_rom0.bin

%.bin:	%.asm $(DEPS)
	$(AS) $(ASFLAGS) -B -o $@ -l $(basename $@).lst $<

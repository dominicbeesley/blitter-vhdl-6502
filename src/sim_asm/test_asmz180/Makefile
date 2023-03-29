AS=asz80
ASFLAGS=-ols
LD=aslink
LDFLAGS=
BUILD=./build/
TARGETS=z180_rom.bin

X:=$(shell mkdir -p $(BUILD))

all:: $(addprefix $(BUILD),$(TARGETS))

$(BUILD)%.rel: %.asm
	$(AS) $(ASFLAGS) $@ $<

$(BUILD)z180_rom.ihx: $(BUILD)z180_rom.rel $(BUILD)font_data.rel z180_rom.lnk
	$(LD) $(LDFLAGS) -f $(basename z180_rom)

$(BUILD)z180_rom.bin: $(BUILD)z180_rom.ihx
	hex2bin 0xC000 $< $@

clean:
	-rm $(BUILD)*.s19
	-rm $(BUILD)*.ihx
	-rm $(BUILD)*.lst
	-rm $(BUILD)*.rel
	-rm $(BUILD)*.sym
	-rm $(BUILD)*.noi
	-rm $(BUILD)*.bin
	-rm $(BUILD)*.map
	-rm $(BUILD)*.hlr

.PHONY: all clean
	


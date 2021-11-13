AS=asz80
ASFLAGS=-ols
LD=aslink
LDFLAGS=

all:: z80_rom.bin z80_chipram.bin


%.rel: %.asm
	$(AS) $(ASFLAGS) $@ $<

z80_rom.ihx: z80_rom.rel z80_rom.lnk
	$(LD) $(LDFLAGS) -f $(basename z80_rom)

z80_chipram.ihx: z80_chipram.rel font_data.rel z80_chipram.lnk
	$(LD) $(LDFLAGS) -f $(basename z80_chipram)


z80_rom.bin: z80_rom.ihx
	hex2bin 0xC000 $< $@

z80_chipram.bin: z80_chipram.ihx
	hex2bin 0x0000 $< $@


clean:
	-rm *.s19
	-rm *.ihx
	-rm *.lst
	-rm *.rel
	-rm *.sym
	-rm *.noi
	-rm *.bin
	-rm *.map
	-rm *.hlr

.PHONY: all clean
	


	include ../Makefile.defs


AS=ca65 -I $(TOP)/includes 
LD=ld65

OBJS=C20KBareMON
TARGETS=	C20KBareMON.hex

OBJS_O=$(addprefix $(BUILD)/, $(addsuffix .o, $(OBJS)))
TARGETS_O=$(addprefix $(BUILD)/, $(TARGETS))



all: $(TARGETS_O)

$(BUILD)/%.hex: $(BUILD)/%.bin
		bin2hex 0x1000 $< $@

$(BUILD)/C20KBareMON.bin : $(OBJS_O) C20KBareMON.cfg
		$(LD) -vm -Ln $(basename $@).sy2 -m $(basename $@).map --dbgfile $(basename $@).dbg -o $@ -C $(notdir $(basename $@)).cfg $(OBJS_O)
		$(SCRIPTS)/perl/getsymbols.pl <$(basename $@).sy2 >$(basename $@).sym.noi
		da65 -S 0x1000 --comments 4 $(basename $@).bin >$(basename $@).da.s
		$(SCRIPTS)/perl/ca65lstupdate.pl $(basename $@).dbg $(BUILD)


$(BUILD)/%.o: 	%.asm $(DEPS)
		$(AS) -g -l $(basename $@).lst -o $@ $<



clean:		
		-rm -f $(OBJS_O)
		-rm -f $(TARGETS_O)
		-rm -f $(patsubst %.hex, %.bin, $(TARGETS_O))	
		-rm -f $(patsubst %.hex, %.map, $(TARGETS_O))
		-rm -f $(patsubst %.hex, %.sy2, $(TARGETS_O))
		-rm -f $(patsubst %.hex, %.da.s, $(TARGETS_O))
		-rm -f $(patsubst %.hex, %.sym.noi, $(TARGETS_O))
		-rm -f $(patsubst %.hex, %.vec, $(TARGETS_O))
		-rm -f $(patsubst %.o, %.lst, $(OBJS_O))

	include ../Makefile.defs


AS=ca65 -I $(TOP)/includes 
LD=ld65

OBJS=C20KBareMON
TARGETS=	C20KBareMON.vec C20KBareMON-test.mot

OBJS_O=$(addprefix $(BUILD)/, $(addsuffix .o, $(OBJS)))
TARGETS_O=$(addprefix $(BUILD)/, $(TARGETS))



all: $(TARGETS_O)

$(BUILD)/%.mot: $(BUILD)/%.bin
		srec_cat $< -binary -offset 0x1000 -o $@ -motorola -address-length=2

$(BUILD)/%.vec: $(BUILD)/%.rom
		$(SCRIPTS)/perl/bin2bitvector.pl $< >$@


# link to load as boot ROM at F000
$(BUILD)/C20KBareMON.rom : $(OBJS_O) C20KBareMON.cfg
		$(LD) -vm -Ln $(basename $@).sy2 -m $(basename $@).map --dbgfile $(basename $@).dbg -o $@ -C $(notdir $(basename $@)).cfg $(OBJS_O)
		$(SCRIPTS)/perl/getsymbols.pl <$(basename $@).sy2 >$(basename $@).sym.noi
		da65 -S 0xF000 --comments 4 $@ >$(basename $@).da.s
		$(SCRIPTS)/perl/ca65lstupdate.pl $(basename $@).dbg $(BUILD)

# link to load as program under NoICE at 1000
$(BUILD)/C20KBareMON-test.bin : $(OBJS_O) C20KBareMON-test.cfg
		$(LD) -vm -Ln $(basename $@).sy2 -m $(basename $@).map --dbgfile $(basename $@).dbg -o $@ -C $(notdir $(basename $@)).cfg $(OBJS_O)
		$(SCRIPTS)/perl/getsymbols.pl <$(basename $@).sy2 >$(basename $@).sym.noi
		da65 -S 0x1000 --comments 4 $@ >$(basename $@).da.s
		$(SCRIPTS)/perl/ca65lstupdate.pl $(basename $@).dbg $(BUILD)

$(BUILD)/%.o: 	%.asm $(DEPS)
		$(AS) -g -l $(basename $@).lst -o $@ $<



clean:		
		-rm -f $(OBJS_O)
		-rm -f $(TARGETS_O)
		-rm -f $(patsubst %.mot, %.map, $(TARGETS_O))
		-rm -f $(patsubst %.mot, %.sy2, $(TARGETS_O))
		-rm -f $(patsubst %.mot, %.da.s, $(TARGETS_O))
		-rm -f $(patsubst %.mot, %.sym.noi, $(TARGETS_O))
		-rm -f $(patsubst %.mot, %.bin, $(TARGETS_O))
		-rm -f $(patsubst %.mot, %.dbg, $(TARGETS_O))
		-rm -f $(patsubst %.vec, %.map, $(TARGETS_O))
		-rm -f $(patsubst %.vec, %.sy2, $(TARGETS_O))
		-rm -f $(patsubst %.vec, %.da.s, $(TARGETS_O))
		-rm -f $(patsubst %.vec, %.sym.noi, $(TARGETS_O))
		-rm -f $(patsubst %.vec, %.dbg, $(TARGETS_O))
		-rm -f $(patsubst %.vec, %.rom, $(TARGETS_O))
		-rm -f $(patsubst %.o, %.lst, $(OBJS_O))
		-rm -f $(patsubst %.o, %.lst.rel, $(OBJS_O))

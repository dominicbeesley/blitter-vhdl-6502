	include ../Makefile.defs

AS=ca65 -I $(TOP)/includes 
LD=ld65

OBJS=C20KTestMOS-sound
TARGETS=C20KTestMOS-sound.rom

OBJS_O=$(addprefix $(BUILD)/, $(addsuffix .o, $(OBJS)))
TARGETS_O=$(addprefix $(BUILD)/, $(TARGETS))

all:	$(TARGETS_O)


$(BUILD)/C20KTestMOS-sound.rom : $(OBJS_O) C20KTestMOS-sound.cfg
		$(LD) -vm -Ln $(basename $@).sy2 -m $(basename $@).map -o $@ -C $(notdir $(basename $@)).cfg $(OBJS_O)
		$(SCRIPTS)/perl/getsymbols.pl <$(basename $@).sy2 >$(basename $@).sym.noi
		da65 -S 0xC000 --comments 4 $(basename $@).rom >$(basename $@).da.s
		$(SCRIPTS)/perl/bin2bitvector.pl $@ >$(basename $@).vec


$(BUILD)/%.o:	%.asm
		$(AS) -g -l $(basename $@).lst -o $@ $<


clean:		
		-rm -f $(OBJS_O)
		-rm -f $(TARGETS_O)
		-rm -f $(patsubst %.rom, %.map, $(TARGETS_O))
		-rm -f $(patsubst %.rom, %.sy2, $(TARGETS_O))
		-rm -f $(patsubst %.rom, %.da.s, $(TARGETS_O))
		-rm -f $(patsubst %.rom, %.sym.noi, $(TARGETS_O))
		-rm -f $(patsubst %.rom, %.vec, $(TARGETS_O))
		-rm -f $(patsubst %.o, %.lst, $(OBJS_O))




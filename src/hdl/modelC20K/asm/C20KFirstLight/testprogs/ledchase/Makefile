	include ../../Makefile.defs


AS=ca65 -I $(TOP)/includes 
LD=ld65

OBJS=ledchase
TARGETS=	ledchase.mot

OBJS_O=$(addprefix $(BUILD)/, $(addsuffix .o, $(OBJS)))
TARGETS_O=$(addprefix $(BUILD)/, $(TARGETS))



all: $(TARGETS_O)

$(BUILD)/%.mot: $(BUILD)/%.bin
		srec_cat $< -binary -offset 0x400 -o $@ -motorola -address-length=2

$(BUILD)/ledchase.bin : $(OBJS_O) ledchase.cfg
		$(LD) -vm -Ln $(basename $@).sy2 -m $(basename $@).map --dbgfile $(basename $@).dbg -o $@ -C $(notdir $(basename $@)).cfg $(OBJS_O)
		$(SCRIPTS)/perl/getsymbols.pl <$(basename $@).sy2 >$(basename $@).sym.noi
		da65 -S 0x0300 --comments 4 $(basename $@).bin >$(basename $@).da.s
		$(SCRIPTS)/perl/ca65lstupdate.pl $(basename $@).dbg $(BUILD)


$(BUILD)/%.o: 	%.asm $(DEPS)
		$(AS) -g -l $(basename $@).lst -o $@ $<



clean:		
		-rm -f $(OBJS_O)
		-rm -f $(TARGETS_O)
		-rm -f $(patsubst %.mot, %.bin, $(TARGETS_O))
		-rm -f $(patsubst %.mot, %.map, $(TARGETS_O))
		-rm -f $(patsubst %.mot, %.sy2, $(TARGETS_O))
		-rm -f $(patsubst %.mot, %.da.s, $(TARGETS_O))
		-rm -f $(patsubst %.mot, %.sym.noi, $(TARGETS_O))
		-rm -f $(patsubst %.mot, %.dbg, $(TARGETS_O))
		-rm -f $(patsubst %.o, %.lst.rel, $(OBJS_O))
		-rm -f $(patsubst %.o, %.lst, $(OBJS_O))

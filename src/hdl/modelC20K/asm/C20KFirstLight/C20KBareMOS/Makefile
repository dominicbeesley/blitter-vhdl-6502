.PHONY:		all clean

ASMTARGETS=	C20K-boot-rom.rom 
TARGETS=	$(ASMTARGETS) 

INCS=../includes		
LIBS=		
SCRIPTS=../../../../../scripts
BUILD=./build

AS=ca65
LD=ld65
DEPS=
AR=ar65

OBJS=C20K-boot-rom noice
OBJS_O=$(addsuffix .o, $(OBJS))
OBJS_B=$(addprefix $(BUILD)/, $(OBJS_O))

.PRECIOUS:	$(BUILD)/%.o

X:=$(shell mkdir -p build)

all:		$(addprefix $(BUILD)/, $(TARGETS))


$(BUILD)/C20K-boot-rom.rom : $(OBJS_B) $(LIBS) C20K-boot-rom.cfg
		$(LD) -vm -Ln $(basename $@).sy2 -m $(basename $@).map -o $@ -C $(notdir $(basename $@)).cfg $(OBJS_B) $(LIBS)
		$(SCRIPTS)/perl/getsymbols.pl <$(basename $@).sy2 >$(basename $@).sym.noi
		da65 -S 0xE000 --comments 4 $(basename $@).rom >$(basename $@).da.s
		$(SCRIPTS)/perl/bin2bitvector.pl $@ >$(basename $@).vec


$(BUILD)/%.o:	%.asm $(DEPS) $(INCS)
		$(AS) -g -l $(basename $@).lst -I $(INCS) -o $@ $<


clean:		
		-rm -f $(BUILD)/*




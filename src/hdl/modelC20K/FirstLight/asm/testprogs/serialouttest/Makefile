.PHONY:		all clean

ASMTARGETS=	test-serialout.bin 
TARGETS=	$(ASMTARGETS) 

INCS=		
LIBS=		
SCRIPTS=../../../../../../scripts
BUILD=./build

AS=ca65
LD=ld65
DEPS=p20k.inc
AR=ar65

OBJS=test-serialout
OBJS_O=$(addsuffix .o, $(OBJS))
OBJS_B=$(addprefix $(BUILD)/, $(OBJS_O))

.PRECIOUS:	$(BUILD)/%.o

X:=$(shell mkdir -p build)

all:		$(addprefix $(BUILD)/, $(TARGETS))


$(BUILD)/test-serialout.bin : $(OBJS_B) $(LIBS) test-serialout.cfg
		$(LD) -vm -Ln $(basename $@).sy2 -m $(basename $@).map -o $@ -C $(notdir $(basename $@)).cfg $(OBJS_B) $(LIBS)
		$(SCRIPTS)/perl/getsymbols.pl <$(basename $@).sy2 >$(basename $@).sym.noi
		da65 -S 0x1000 --comments 4 $(basename $@).bin >$(basename $@).da.s


$(BUILD)/%.o:	%.asm $(DEPS) $(INCS)
		$(AS) -g -l $(basename $@).lst -o $@ $<


clean:		
		-rm -f $(BUILD)/*




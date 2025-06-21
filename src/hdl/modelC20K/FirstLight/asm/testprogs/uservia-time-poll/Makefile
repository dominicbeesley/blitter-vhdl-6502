.PHONY:		all clean

ASMTARGETS=	uservia-time.hex
TARGETS=	$(ASMTARGETS) 

INCS=../../includes/
LIBS=		
SCRIPTS=../../../../../../scripts
BUILD=./build

AS=ca65
LD=ld65
DEPS=
AR=ar65

OBJS=uservia-time
OBJS_O=$(addsuffix .o, $(OBJS))
OBJS_B=$(addprefix $(BUILD)/, $(OBJS_O))

.PRECIOUS:	$(BUILD)/%.o

X:=$(shell mkdir -p build)

all:		$(addprefix $(BUILD)/, $(TARGETS))


$(BUILD)/%.hex: $(BUILD)/%.bin
		bin2hex 0x300 $< $@

$(BUILD)/uservia-time.bin : $(OBJS_B) $(LIBS) uservia-time.cfg
		$(LD) -vm -Ln $(basename $@).sy2 -m $(basename $@).map -o $@ -C $(notdir $(basename $@)).cfg $(OBJS_B) $(LIBS)
		$(SCRIPTS)/perl/getsymbols.pl <$(basename $@).sy2 >$(basename $@).sym.noi
		da65 -S 0x1000 --comments 4 $(basename $@).bin >$(basename $@).da.s


$(BUILD)/%.o:	%.asm $(DEPS) $(INCS)
		$(AS) -g -l $(basename $@).lst -I $(INCS) -o $@ $<


clean:		
		-rm -f $(BUILD)/*




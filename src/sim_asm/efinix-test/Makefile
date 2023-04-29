.PHONY:		all clean

ASMTARGETS=	efinix-boot-rom.rom 
TARGETS=	$(ASMTARGETS) 

INCS=		
LIBS=		
SCRIPTS=../../scripts
BUILD=./build

#BLIT_LIB_OBJS=	blit_lib.o blit_lib_ctl_full.o blit_lib_copy.o blit_lib__rd_bloc_be.o blit_lib_plot.o

AS=ca65
LD=ld65
DEPS=
AR=ar65

.PRECIOUS:	$(BUILD)/%.o

X:=$(shell mkdir -p build)

all:		$(addprefix $(BUILD)/, $(TARGETS))

$(BUILD)/%rom:	%.cfg

#blit.lib:	$(BLIT_LIB_OBJS)
#		rm -f blit.lib
#		$(AR) r blit.lib $(BLIT_LIB_OBJS)


$(BUILD)/%.rom:	$(BUILD)/%.o $(LIBS)
		$(LD) -vm -Ln $(basename $@).sy2 -m $(basename $@).map -o $@ -C $(notdir $(basename $@)).cfg $< $(LIBS)
		$(SCRIPTS)/perl/getsymbols.pl <$(basename $@).sy2 >$(basename $@).sym.noi
		da65 -S 0xE000 --comments 4 $(basename $@).rom >$(basename $@).da.s
		$(SCRIPTS)/perl/bin2bitvector.pl $@ >$(basename $@).vec


$(BUILD)/%.o:	%.asm $(DEPS) $(INCS)
		$(AS) -g -l $(basename $@).lst -o $@ $<


clean:		
		-rm -f $(BUILD)/*




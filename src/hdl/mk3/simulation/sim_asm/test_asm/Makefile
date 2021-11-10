.PHONY:		all clean

ASMTARGETS=	blit-bringup2-rom0.rom 
TARGETS=	$(ASMTARGETS) 

INCS=		hw.inc common.inc os.inc
LIBS=		

#BLIT_LIB_OBJS=	blit_lib.o blit_lib_ctl_full.o blit_lib_copy.o blit_lib__rd_bloc_be.o blit_lib_plot.o

AS=ca65
LD=ld65
DEPS=hw.inc common.inc
AR=ar65

.PRECIOUS:	%.o

all:		$(TARGETS)

%rom:	%.cfg

#blit.lib:	$(BLIT_LIB_OBJS)
#		rm -f blit.lib
#		$(AR) r blit.lib $(BLIT_LIB_OBJS)


%.rom:		%.o $(LIBS)
		$(LD) -vm -Ln $(basename $@).sy2 -m $(basename $@).map -o $@ -C $(basename $@).cfg $< $(LIBS)
		../../../../scripts/getsymbols.pl <$(basename $@).sy2 >$(basename $@).sym.noi
		da65 -S 0xC000 --comments 4 $(basename $@).rom >$(basename $@).da.s


%.o:		%.asm $(DEPS) $(INCS)
		$(AS) -g -l $(basename $@).lst $<


clean:		$(clean_extra)
		$(foreach cln,$(TARGETS), \
		rm -f $(cln) $(basename $(cln)).lst $(basename $(cln)).sym $(basename $(cln)).map $(basename $(cln)).hex $(basename $(cln)).o $(basename $(cln)).da.s \
		)
		rm -f *.o
		rm -f test.ssd
		rm -f blit.lib
		rm -f *.rom
		rm -f *.bin




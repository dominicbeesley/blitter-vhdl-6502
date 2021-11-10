AS=vasmm68k_mot.exe
ASFLAGS=-m68008 -spaces -ldots -I ../includes -D MACH_BEEB=1 -D MACH_CHIPKIT=0

TARGETS=boot68008_testbench_mos.bin

OBJS=boot68008_testbench_mos.o
OBJS2=$(addprefix obj/, $(OBJS))

all:: $(TARGETS)

#boot68008_testbench_mos.bin: $(OBJS2)
#	vlink -M -T boot68008_testbench_mos.lnk.txt -b rawbin1 -o $@ $^ > boot68008_testbench_mos.sym

#obj/%.o: %.asm
#	$(AS) $(ASFLAGS) -Fvobj -o $@ -L $(basename $@).lst $<

boot68008_testbench_mos.bin: boot68008_testbench_mos.asm
	$(AS) $(ASFLAGS) -Fbin -o $@ -L $(basename $@).lst $<

clean::
	-rm $(TARGETS) 
	-rm $(OBJS2) 
	-rm $(addprefix obj/, $(addsuffix .lst, $(basename $(OBJS))))
	-rm $(addsuffix .sym, $(basename $(TARGETS)))
	
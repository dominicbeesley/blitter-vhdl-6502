AS=vasm6800_std_win32.exe
ASFLAGS=-m6800 

TARGETS=boot6800_testbench_mos.rom

OBJS=boot6800_testbench_mos.o
OBJS2=$(addprefix obj/, $(OBJS))

all:: $(TARGETS)

#boot68008_testbench_mos.bin: $(OBJS2)
#	vlink -M -T boot68008_testbench_mos.lnk.txt -b rawbin1 -o $@ $^ > boot68008_testbench_mos.sym

#obj/%.o: %.asm
#	$(AS) $(ASFLAGS) -Fvobj -o $@ -L $(basename $@).lst $<

boot6800_testbench_mos.rom: boot6800_testbench_mos.asm
	$(AS) $(ASFLAGS) -Fbin -o $@ -L $(basename $@).lst $<

clean::
	-rm $(TARGETS) 
	-rm $(OBJS2) 
	-rm $(addprefix obj/, $(addsuffix .lst, $(basename $(OBJS))))
	-rm $(addsuffix .sym, $(basename $(TARGETS)))
	
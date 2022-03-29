AS=nasm.exe
ASFLAGS=

TARGETS=bootx86_testbench_mos.rom

OBJS=bootx86_testbench_mos.o
OBJS2=$(addprefix obj/, $(OBJS))

all:: $(TARGETS)

#bootx86_testbench_mos.bin: $(OBJS2)
#	vlink -M -T bootx86_testbench_mos.lnk.txt -b rawbin1 -o $@ $^ > bootx86_testbench_mos.sym

#obj/%.o: %.asm
#	$(AS) $(ASFLAGS) -Fvobj -o $@ -L $(basename $@).lst $<

bootx86_testbench_mos.rom: bootx86_testbench_mos.asm
	$(AS) $(ASFLAGS) -fbin -o $@ -l $(basename $@).lst $<

clean::
	-rm $(TARGETS) 
	-rm $(OBJS2) 
	-rm $(addprefix obj/, $(addsuffix .lst, $(basename $(OBJS))))
	-rm $(addsuffix .sym, $(basename $(TARGETS)))
	
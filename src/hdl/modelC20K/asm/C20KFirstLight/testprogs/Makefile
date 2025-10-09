	include ../Makefile.defs

SUBDIRSWIMAKE:= ledchase memtest serialouttest uservia-time-poll uservia-time-irq flashinfo \
				sysvia-time-poll sysvia-time-irq kbtest-scan flashprog

$(TOPTARGETS): $(SUBDIRSWIMAKE)

$(SUBDIRSWIMAKE): 
	$(MAKE) -C $@ $(MAKECMDGOALS)

.PHONY:		$(TOPTARGETS) $(SUBDIRSWIMAKE)
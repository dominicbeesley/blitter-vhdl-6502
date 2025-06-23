
SUBDIRSWIMAKE:= ledchase memtest serialouttest uservia-time-poll uservia-time-irq flashinfo \
				sysvia-time-poll sysvia-time-irq kbtest-scan

all:$(SUBDIRSWIMAKE)
clean:$(SUBDIRSWIMAKE)


$(SUBDIRSWIMAKE):
	$(MAKE) -C $@ $(MAKECMDGOALS)


.PHONY:		$(SUBDIRSWIMAKE)

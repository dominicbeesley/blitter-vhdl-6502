
SUBDIRSWIMAKE:=ledchase memtest serialouttest uservia-time-poll uservia-time-irq

all:$(SUBDIRSWIMAKE)
clean:$(SUBDIRSWIMAKE)


$(SUBDIRSWIMAKE):
	$(MAKE) -C $@ $(MAKECMDGOALS)


.PHONY:		$(SUBDIRSWIMAKE)

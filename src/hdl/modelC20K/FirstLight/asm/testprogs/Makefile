
SUBDIRSWIMAKE:=ledchase memtest serialouttest uservia-time

all:$(SUBDIRSWIMAKE)
clean:$(SUBDIRSWIMAKE)


$(SUBDIRSWIMAKE):
	$(MAKE) -C $@ $(MAKECMDGOALS)


.PHONY:		$(SUBDIRSWIMAKE)

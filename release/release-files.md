# blitter 6502 vhdl release files

This release bundle contains a number of demonstration programs, ROMs and 
utilities for the Blitter board wit various CPU configurations

# T65, 65C02, 65816

## roms65.ssd

This SSD contains ROMS for use with the Blitter board.

|Filename   | Description
|-----------|-------------------------
| BLTUTIL   | Blitter Utility ROM load to slot F
| BAS432	| 65c02, 65816 only BASIC 4.32 from the Master 
| BASIC2    | Regular BASIC2 ROM - load to a sideways RAM slot for faster execution
| M.OSTEST	| Tricky's test ROM can be loaded to slot 8/9 in bank 1 and used with SWMOS/SWROMX
| M.MOS120  | MOS120 load to slot 8/9 for hard-cpu / bank 1
| SWMMFS	| A sideways RAM version of MMFS for use with a User-port MMC, load to an even numbered sideways RAM slot
| BLMMFS    | Auto-Hazel MMFS PAGE=E00
| ADFSH30   | Auto-Hazel ADFS PAGE=E00

https://github.com/dominicbeesley/blitter-65xx-code/tree/main/src/roms/bltutil

## tools65.ssd 

A set of tools for testing the on-board devices of the Blitter

|Filename   | Description
|-----------|-------------------------
| MEMSZ		| Check ChipRAM and report size
| JIMTEST	| *JIMTES D1 200000 - tests memory
| I2CDUMP	| Dump I2C EEPROM contents
| FLSHTST	| Test and report on board Flash ROM
| CLOCKSP	| Test BASIC speed
| CLOCKDP	| Enhanced dp11 Test BASIC speed

https://github.com/dominicbeesley/blitter-65xx-code/tree/main/src/tools65

## paula.ssd

Demo ProTracker player shift-break to start

Unpack to ADFS or other large FS and copy more 4-channel trackers, rename to M.*

https://github.com/dominicbeesley/blitter-65xx-code/tree/main/src/demos/modplayer

## demo65.ssd

A scroller demo shift-break or \*EXEC !BOOT to run

https://github.com/dominicbeesley/blitter-65xx-code/tree/main/src/demos/scroll1

## adventure.ssd

A demo game using the Blitter - best played with an analogue joystick start with !BOOT
after loading R.CLIB to slot #1

	\*SRLOAD R.CLIB 1

After game has run press Break then F1 for a demo mode of multiple sprites <> increase/decrease sprites

https://github.com/dominicbeesley/blitter-65xx-code/tree/main/src/demos/adventure

## bigfonts.ssd

A scroller demo with large fonts that uses Aeries (ensure jump leads fitted)

	\*SRLOAD R.CLIB 1

Then shift-break

## examblit.ssd

A set of BASIC programs that demonstrate how to program the blitter. These are
suitable for running in 6502 BASIC.

https://github.com/dominicbeesley/blitter-65xx-code/tree/main/src/demos/bigfonts

## bas816

An experimental port of the Acorn Communictor BASIC to the Blitter. The OS 
shims and exception handlers are only partly finished.

shift-break to load and start communicator BASIC

	>REPORT
	>P. HIMEM-PAGE
	>CH."CLOCKSP"

# 6809/6309

https://github.com/dominicbeesley/beeb6809

## roms69.ssd

ROMs for use with 6809E/6309E cpu

|Filename   | Description
|-----------|-------------------------
| R.UTILS09 | Blitter utility ROM for 6x09
| M.MOS6809 | MOS for 6x09
| M.MOS6309 | MOS for 6309 only in emulation mode
| M.MOS630N | MOS for 6309 only in native mode
| R.HOSTFS  | HOSTFS filing system
| R.HOSTFSM | HOSTFS filing system for Myelin serial board
| R.BASIC   | BASIC ROM for 6x09
| R.BAS6368 | BASIC ROM for 6309 only with smaller 6809 assembler
| R.BAS6309 | BASIC ROM for 6309 with 6309 assembler (experimental)

# Z80.ssd

Some test MOS roms display a banner. The supplied ssd when booted from T65 mode will load
the test ROM to bank 1 slot 9 and prompt to press break.

Note: you should remove the T65 jumper and fit the MOSRAM jumper before pressing break

https://github.com/dominicbeesley/blitter-z80-code


# 68k.ssd

TBC




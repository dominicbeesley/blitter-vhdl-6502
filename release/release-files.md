# blitter 6502 vhdl release files

This release bundle contains a number of demonstration programs, ROMs and 
utilities for the Blitter board with various CPU configurations

# "Preboot"

The preboot image should be burned to the FPGA Configuration ROM and gives
a simple way to de-brick your Blitter/C20K board should you load a bad ROM
or MOS image.

You will also need to burn a new (March 2026) main firmware to your board
with the latest preboot facility

For more information about the preboot process please read the documentation
at [Preboot readme](https://github.com/dominicbeesley/blitter-65xx-code/blob/main/src/roms/preboot/readme.md)

## Mk.2

The mk2-image.jic file contains a file suitable for programming the mk2 Blitter 
using the Altera programming tool. This will load both the preboot2 program and
the romsets to the SPI FPGA configuration memory.

## C20K Preboot prep

The c20k folder contains a preeboot2-c20k.bin file and a romset-c20k.bin file. These
should be programmed to the Primer 20K's configuration SPI Flash using the commands 
below

GoWin:
```
	> [full path to gowin programmer]/programmer_cli --device GW2A-18C --run 39 --spiaddr 0x300000 --mcuFile [full path...]/preboot2-c20k.bin
	> [full path to gowin programmer]/programmer_cli --device GW2A-18C --run 39 --spiaddr 0x320000 --mcuFile [full path...]/romset-c20k.bin
```

openFPGAloader:
```
	> openFPGALoader --verbose-level 2 --cable ft2232 --write-flash -o 0x300000 --bitstream [full path...]/preboot2-c20k.bin
	>openFPGALoader --verbose-level 2 --cable ft2232 --write-flash -o 0x320000 --bitstream [full path...]//romset-c20k.bin
```

# CPU: T65, 65C02, 65816

## roms65.ssd

This SSD contains ROMS for use with the Blitter board.

|Filename   | Description
|-----------|-------------------------
| BLTUTIL   | Blitter Utility ROM load to slot F
| E.BLTUTIL | Blitter Utility ROM load to slot F - for Electron testing
| BLTTEST   | Test ROM - do not load
| BAS432	| 65c02, 65816 only BASIC 4.32 from the Master 
| BASIC2    | Regular BASIC2 ROM - load to a sideways RAM slot for faster execution
| M.OSTEST	| Tricky's test ROM can be loaded to slot 8/9 in bank 1 and used with SWMOS/SWROMX
| M.MOS120  | MOS120 load to slot 8/9 for hard-cpu / bank 1
| SWMMFS	| A sideways RAM version of MMFS for use with a User-port MMC, load to an even numbered sideways RAM slot
| BBLMMFS   | Auto-Hazel MMFS PAGE=E00 - mk.3 / c20k extra SD card port
| UBLMMFS   | Auto-Hazel MMFS PAGE=E00 - mk.2 user port SD card
| ADFSH30   | Auto-Hazel ADFS PAGE=E00 - 1MHz bus SCSI / WD1770

https://github.com/dominicbeesley/blitter-65xx-code/tree/main/src/roms/bltutil

## tools65.ssd 

A set of tools for testing the on-board devices of the Blitter

|Filename   | Description
|-----------|-------------------------
| OS99TS2   | OSWORD 99 test program
| OS99TST   | OSWORD 99 test program
| CLOCKDP	| Enhanced dp11 Test BASIC speed
| CLOCKSP	| Test BASIC speed
| XFDUMP    | Dump the contents of FPGA configuration SPI Flash
| TST1306   | Test i2c connector on mk.3 / c20k with attached OLED
| MEMSZ		| Check ChipRAM and report size
| RTCDUMP   | Query mk.3 / c20k real time clock
| I2CDUMP   | Query i2c devices / eeprom
| JIMTEST	| *JIMTES D1 200000 - tests memory
| I2CDUMP	| Dump I2C EEPROM contents
| FLSHTST	| Test and report on board Flash EEPROM

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

# CPU: 6809/6309

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




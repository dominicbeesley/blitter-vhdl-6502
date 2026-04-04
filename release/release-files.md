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

## Mk.2 prep

The preboot-mk2.jic file contains a file suitable for programming the preboot
program code and ROM sets to the mk2 Blitter using the Altera programming tool. 
This will load both the preboot2 program and the romsets to the SPI FPGA 
configuration memory.

You can use the gui programmer tool or the command line
```
	$ quartus_pgm --no_banner --mode=jtag -o "IP;[...path...]/preboot-mk2.jic"
```

## Mk.2 Romsets

The default romsets available for the mk.2 blitter are:

#### Standard Mk.2 6502 Guide

|slot # | ROM      | Notes
|-------|----------|---------------------------------------------------------
| B     | BASIC2   | Model B BASIC 2
| D     | UBLMMFS  | User port MMFS with Hazel extension - PAGE = E00
| F     | BLTUTIL  | Blitter Utility ROM
| MOS   | M.OS120  | Model B MOS 1.20

This should correspond to the ROMs loaded in the getting started guide.

#### Big Mk.2 6502 Dom

|slot # | ROM      | Notes
|-------|----------|---------------------------------------------------------
| 2     | HFSTFSM  | HOSTFS for Myelin serial with Fast transfers
| 3     | BASIC2   | Model B BASIC 2
| B     | NFS360JGH| Econet networking 3.60 JGH special version - PAGE = 1200
| C     | ADFSH30  | SCSI ADFS for Model B with Hazel extensions PAGE = E00
| D     | UBLMMFS  | User port MMFS with Hazel extension - PAGE = E00
| F     | BLTUTIL  | Blitter Utility ROM
| MOS   | M.OS120  | Model B MOS 1.20

You may wish to erase ROM B to put page back to E00 if Econet is not required.

#### Tricky OS Test

|slot # | ROM      | Notes
|-------|----------|---------------------------------------------------------
| MOS   | M.OSTEST | Tricky's OS Test ROM

Good for trouble shooting - note the MOS cannot be ovewritten on Map 0 to
use Tricky's test ROM load to MAP 1 and fit the SWROMX jumper.

#### 6809 Standard

|slot # | ROM      | Notes
|-------|----------|---------------------------------------------------------
| 1     | R.BASIC  | 6809 BBC BASIC 
| B     | R.HOSTFSM| HOSTFS for Myelin serial for 6809
| F     | R.UTILS09| BLTUTIL 6809 version
| MOS   | M.MOS6809| 6809 MOS

#### 6309 Standard

|slot # | ROM      | Notes
|-------|----------|---------------------------------------------------------
| 1     | R.BASIC  | 6809 BBC BASIC 6309 enhancements, 6809 assembler
| B     | R.HOSTFSM| HOSTFS for Myelin serial for 6809
| F     | R.UTILS09| BLTUTIL 6809 version
| MOS   | M.MOS6809| 6309 MOS with 6309 enhancements

#### 6309 Native Mode

|slot # | ROM      | Notes
|-------|----------|---------------------------------------------------------
| 1     | R.BASIC  | 6809 BBC BASIC 6309 enhancements, 6809 assembler
| B     | R.HOSTFSM| HOSTFS for Myelin serial for 6809
| F     | R.UTILS09| BLTUTIL 6809 version
| MOS   | M.MOS680N| 6309 MOS with 6309 enhancements running in Native mode 25% speed boost.


## C20K Preboot prep

The c20k folder contains a preeboot2-c20k.bin file and a romset-c20k.bin file. These
should be programmed to the Primer 20K's configuration SPI Flash using the commands 
below

GoWin:
```
	> [full path to gowin programmer]/programmer_cli --device GW2A-18C --run 32 --spiaddr 0x300000 --mcuFile "[full path...]/preboot2-c20k.bin"
	> [full path to gowin programmer]/programmer_cli --device GW2A-18C --run 32 --spiaddr 0x320000 --mcuFile "[full path...]/romset-c20k.bin"
```

openFPGAloader:
```
	> openFPGALoader --verbose-level 2 --cable ft2232 --write-flash -o 0x300000 --bitstream [full path...]/preboot2-c20k.bin
	> openFPGALoader --verbose-level 2 --cable ft2232 --write-flash -o 0x320000 --bitstream [full path...]//romset-c20k.bin
```

NOTE: As of 31/3/2026 both openFPGALoader (running under WSL) and the 
programmer_cli tool fail to program the Primer 20K. For openFPGA loader
there is a well-known "Error: ftdi_read_data in mpsse_read" which still
seems to not be resolved on WSL under Windows. The gowin programmer_cli
fails with "Error: Flsh format error". For this reason under Windows it
is recommended to use the Gowin Windows Programmer app in 
"exFlash C Bin Erase, Program thru GAO-Bridge", being careful to set the
correct SPI base addresses 0x300000 and 0x320000

### C20K Romsets

#### Standard C20K 6502 Guide

|slot # | ROM      | Notes
|-------|----------|---------------------------------------------------------
| B     | BASIC2   | Model B BASIC 2
| D     | BBLMMFS  | SOM SDCARD MMFS with Hazel extension - PAGE = E00
| F     | BLTUTIL  | Blitter Utility ROM
| MOS   | M.OS120  | Model B MOS 1.20

This should correspond to the ROMs loaded in the getting started guide.

#### Big C20K 6502 Dom

|slot # | ROM      | Notes
|-------|----------|---------------------------------------------------------
| 2     | HFSTFSM  | HOSTFS for Myelin serial with Fast transfers
| 3     | BASIC2   | Model B BASIC 2
| B     | NFS360JGH| Econet networking 3.60 JGH special version - PAGE = 1200
| C     | ADFSH30  | SCSI ADFS for Model B with Hazel extensions PAGE = E00
| D     | BBLMMFS  | SOM SDCARD MMFS with Hazel extension - PAGE = E00
| F     | BLTUTIL  | Blitter Utility ROM
| MOS   | M.OS120  | Model B MOS 1.20

You may wish to erase ROM B to put page back to E00 if Econet is not required.

#### Tricky OS Test

|slot # | ROM      | Notes
|-------|----------|---------------------------------------------------------
| MOS   | M.OSTEST | Tricky's OS Test ROM

Good for trouble shooting - on the C20K this can be loaded to either map.

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




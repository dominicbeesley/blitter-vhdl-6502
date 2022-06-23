
# Introduction

The Paula and Blitter expansion boards expose a number of hardware 
registers. Most of the hardware registers are in the JIM page-wide except
where those registers enhance or reimplement a well-known mechanism, i.e.
the ROM paging register.

The addresses listed below are "physical" addresses in the form "AA BBCC"
i.e. FF FE30. Logical addresses are prefixed with "L" i.e. LFE30


# Physical memory map

The Blitter firmware has the concept of Physical and Logical memory maps. This
is to cater for the fact that the Blitter board needs a relatively large (24 bit)
memory map to cater for the large amount of memory available and the large number
of peripheral registers. However, each of the supported CPUs has differing 
capabilities in terms of the size of address that they natively support.

The section on [Logical to Physical Mapping] below describes how each CPU can 
access the physical address map.

## Physcial memory map overview


The physical memory map is separated in to the broad areas in the table
below. The following sections describe these in more detail.

    +--------------------------+-----------------------+ 
    | Physical address         | hardware item         |
    +--------------------------+-----------------------+
    | $00 0000 - $7F FFFF      | ChipRAM               | 
    +--------------------------+-----------------------+
    | $80 0000 - $BF FFFF      | Flash EEPROM repeats  | 
    +--------------------------+-----------------------+ 
    |       ---- undefined ---- do not use ----        |
    +--------------------------+-----------------------+ 
    | $FA 0000 - $FB FDFF      | HDMI memory           | 
    +--------------------------+-----------------------+ 
    | $FB FE00 - $FB FFFF      | HDMI registers        | 
    +--------------------------+-----------------------+ 
    | $FC 0000 - $FC FFFF      | Debug/Version info    | 
    +--------------------------+-----------------------+ 
    | $FE FC00 - $FE FCFF      | Chipset registers     | 
    +--------------------------+-----------------------+
    | $FF 0000 - $FF FFFF      | Motherboard           |
    +--------------------------------------------------+

The Physical memory map is used when:
 - accessing devices or memory via the JIM page-wide interface
 - programming Chipset registers

### ChipRAM

ChipRAM is the extra RAM that is present on the Blitter/Paula board the amount
and arrangement of RAM will depend on which revision and level of board.

When accessing ChipRAM on a MOS compatible system it is advised that the memory
layout be divined using the OSWORD 99 calls available through the Utility ROM
wherever possible.

#### Paula

On the Paula there is 512KB of Fast 10ns RAM. This RAM will repeatedly alias
to fill the banks 00..7F. There is no battery backed RAM

#### Mk.2 Blitter

The Mk.2 contains a single 2MB CMOS SRAM which is usually battery backed. This
RAM will repeatedly alias to fill the banks 00..7F

### Mk.3 Blitter

#### Mk.3 Fast RAM

The Mk.3 Blitter can contain up to 3x2MB fast 10ns RAM in the range 00..5F these
RAMs may be smaller than 2MB in which case they will each alias within a range of 
banks that is &20 banks long. There may be no fast RAM in which case whatever chip
is in socket 3 (battery backed) will alias in the same way as the Mk.2 Blitter. 
Conversely if there is no Battery Backed RAM the ChipRAM will also alias in the 
60..7F range.

#### Mk.3 Battery backed RAM
The Mk.3 Blitter may contain up to 2MB of 45ns CMOS static battery backed RAM 
which will appear in the range 60..7F. If there is no Fast RAM the battery backed
RAM will also appear in the lower portion of ChipRAM address space 00..5F


### Flash EEPROM

The Mk.2 and Mk.3 Blitters contain upto 512KB of Flash EEPROM at $80 0000 onwards
the Paula board contains an alias of RAM in this range.

The Flash EEPROM is an SST39VFxxx-55 compatible device upto (and usually) 512KB in
size. The main use is to provide sideways ROMS however there is usually unused 
capacity toward the borrom of the ROM which may be used for other applications.

### HDMI memory / registers

Optionally on the Mk.3 boards there may be a HDMI framebuffer of up to 128K and
some associated registers in this area.

### Debug / Version info

The firmware places a ROM in these pages for the purpose of identifying the firmware
and capabilities of the board.

### Chipset Registers

The Blitter, Paula Sound, DMA, Aeris registers are in this address range

### Motherboard

The whole of the BBC Micro's or Electron's address space appears in bank FF 
The following points should be noted:
- There is no re-mapping of the sideways ROM/RAM area and the sideways ROM/RAM
  selected on the Blitter board will not be accessed, instead the underlying
  motherboard mapping will apply.
- Writing the ROM select register (BBC/Master at FF FE30, Elk at FE05) will
  also write the Blitter's copy, thus updating the mapping in the logical 
  to physical mapping (see below)
- Writing device select register at FF FCFF with the value D1 (blitter) or
  D0 (1M Paula) will enable Blitter JIM access, any other value will disable
- Reading or Writing the JIM paging registers at FF FCFD..FCFE when the
  when Blitter JIM access is enabled will *only* read or write the Blitter's
  copy of the paging registers


# Logical to Physical Mapping

There is a layer of address remapping between the currently running CPU and
the hardware resources of the board. This allows for:

 - different CPUs require ROM at different locations
 - 8, 16, 32 bit CPU requirements
 - providing enhanced Sideways ROM/RAM

In the following sections the various logical mappings are described. 
Addresses of the form LXXXX refer to logical addresses as seen by the CPU,
addressed of the XX XXXX refer to physical addresses

## MOS Compatible memory Map

In general most 8-bit CPUs use a "MOS compatible" memory map such that RAM
appears at 0-7FFF, Sideways ROM/RAM at 8000-BFFF and MOS ROM at C000-FFFF with
a "hole" for hardware register access at FC00-FEFF.

The default mappings for 6502, 65c02, 65816, 6809, 6309 and 6800 all use a 
similar mapping.

At boot time the RAM at 0000-7FFF is mapped to motherboard memory on 65xx systems
this will allow most games and demos to run without and modification. The motherboard
memory has a maximum speed of 2MHz and this will tend to throttle any faster
CPU to 2MHz by default when running code from, or accessing data in the 
motherboard RAM.

If a MOS compatible CPU wishes to access a physical address it can either
use a chipset device (such as the DMA device) or use the JIM page-wide
address expansion mechanism see [Using JIM](#using-jim)

### Shadow/Turbo memory

TODO


### Sideways ROM/RAM

One of the most powerful features of the BBC micro series is the idea of 
sideways ROM (or sideways RAM). However, on the BBC Micro there are only
a limited number (4) of ROM slots on the motherboard. The Blitter board
can be used to expand this up to two sets of 16.

As the Blitter boards can be either run with an emulated 6502A (T65) CPU
or a variety of different hard CPUs it is useful to be able to have two
sets of ROM mappings for what might be two very different CPUs. There are
currently two maps called Map 0 and Map 1. 

Map 0 is usually in force when the T65 CPU is in use and will "punch through" 
various motherboard ROMs (depending on host machine).
Map 1 is usually in force then a hard CPU is in use.

It is possible to swap the above mapping by fitting the SWROMX jumper or
to disable Blitter ROMs altogether by fitting the MEMI jumper (see
the relevant jumper documentation for your board).

The mapping of which slots are mapped to motherboard ROM slots and which
to either RAM or ROM is dependent upon which type of host machine is in use.

The following sections outline how the mappings are performed.

Note: where "RAM" is specified in the tables below it will depend on which
mark of board and what level of RAM is fitted as to whether the RAM is 
battery backed or not.

As these mappings are quite complex and subject to change it is strongly
advised that the OSWORD 99 API be used to query these mappings in software.

#### BBC B

TODO: This may well need to change!? Any thoughts?


MAP 0
-----

  | # | Type      | Physical address   | Notes                                 
  |---|-----------|--------------------|---------------------------------------
  | 0 | BB RAM    | 9E 0000 - 7E 3FFF  |                                       
  | 1 | EEPROM    | 8E 0000 - 9E 3FFF  |                                       
  | 2 | BB RAM    | 9E 4000 - 7E 7FFF  |                                       
  | 3 | EEPROM    | 8E 4000 - 9E 7FFF  |                                       
  | 4 | SYS IC 52 | FF 8000 - FF BFFF  |                                       
  | 5 | SYS IC 88 | FF 8000 - FF BFFF  |                                       
  | 6 | SYS IC 100| FF 8000 - FF BFFF  |                                       
  | 7 | SYS IC 101| FF 8000 - FF BFFF  |                                       
  | 8 | BB RAM    | 7F 0000 - 7F 3FFF  | NB: also used as the MOS ROM when MOSRAM in effect
  | 9 | EEPROM    | 9F 0000 - 9F 3FFF  |                                       
  | A | BB RAM    | 7F 4000 - 7F 7FFF  |                                       
  | B | EEPROM    | 9F 4000 - 9F 7FFF  |                                       
  | C | BB RAM    | 7F 8000 - 7F BFFF  |                                       
  | D | EEPROM    | 9F 8000 - 9F BFFF  |                                       
  | E | BB RAM    | 7F C000 - 7F FFFF  |                                       
  | F | EEPROM    | 9F C000 - 9F FFFF  | NB: also used as the NoIce debug bank

MAP 1
-----


  | # | Type      | Physical address   | Notes                                 
  |---|-----------|--------------------|---------------------------------------
  | 0 | BB RAM    | 7C 0000 - 7C 3FFF  |
  | 1 | EEPROM    | 9C 0000 - 9C 3FFF  |
  | 2 | BB RAM    | 7C 4000 - 7C 7FFF  |
  | 3 | EEPROM    | 9C 4000 - 9C 7FFF  |
  | 4 | BB RAM    | 7C 8000 - 7C BFFF  |
  | 5 | EEPROM    | 9C 8000 - 9C BFFF  |
  | 6 | BB RAM    | 7C C000 - 7C FFFF  |
  | 7 | EEPROM    | 9C C000 - 9C FFFF  |
  | 8 | BB RAM    | 7D 0000 - 7D 3FFF  | NB: also used as the MOS ROM when MOSRAM in effect
  | 9 | EEPROM    | 9D 0000 - 9D 3FFF  | NB: also used for MOS in Map 1 (not when MOSRAM in effect)
  | A | BB RAM    | 7D 4000 - 7D 7FFF  |
  | B | EEPROM    | 9D 4000 - 9D 7FFF  |
  | C | BB RAM    | 7D 8000 - 7D BFFF  |
  | D | EEPROM    | 9D 8000 - 9D BFFF  |
  | E | BB RAM    | 7D C000 - 7D FFFF  |
  | F | EEPROM    | 9D C000 - 9D FFFF  | NB: also used as the NoIce debug bank



#### Electron

MAP 0
-----

  | # | Type      | Physical address   | Notes                                 
  |---|-----------|--------------------|---------------------------------------
  | 0 | BB RAM    | 7F 8000 - 7F BFFF  |                                       
  | 1 | EEPROM    | 8F 8000 - 8F BFFF  |                                       
  | 2 | BB RAM    | 7F C000 - 7F FFFF  |                                       
  | 3 | EEPROM    | 8F C000 - 8F FFFF  | NB: also used as the NoIce debug bank
  | 4 | BB RAM    | 7F 0000 - 7F 3FFF  | NB: also used as the MOS ROM when MOSRAM in effect
  | 5 | EEPROM    | 8F 0000 - 8F 3FFF  |                                       
  | 6 | BB RAM    | 7F 4000 - 7F 7FFF  |                                       
  | 7 | EEPROM    | 8F 4000 - 8F 7FFF  |                                       
  | 8 | SYS       | FF 8000 - FF BFFF  | Keyboard
  | 9 | SYS       | FF 8000 - FF BFFF  | Keyboard                                      
  | A | SYS       | FF 8000 - FF BFFF  |                                       
  | B | SYS       | FF 8000 - FF BFFF  |                                       
  | C | BB RAM    | 7E 0000 - 7E 3FFF  |                                       
  | D | EEPROM    | 8E 0000 - 8E 3FFF  |                                       
  | E | BB RAM    | 7E 4000 - 7E 7FFF  |                                       
  | F | EEPROM    | 8E 4000 - 8E 7FFF  |                                       

MAP 1
-----


  | # | Type      | Physical address   | Notes                                 
  |---|-----------|--------------------|---------------------------------------
  | 0 | BB RAM    | 7D 8000 - 7D BFFF  |
  | 1 | EEPROM    | 8D 8000 - 8D BFFF  |
  | 2 | BB RAM    | 7D C000 - 7D FFFF  |
  | 3 | EEPROM    | 8D C000 - 8D FFFF  | NB: also used as the NoIce debug bank
  | 4 | BB RAM    | 7D 0000 - 7D 3FFF  | NB: also used as the MOS ROM when MOSRAM in effect
  | 5 | EEPROM    | 8D 0000 - 8D 3FFF  | NB: also used for MOS in Map 1 (not when MOSRAM in effect)
  | 6 | BB RAM    | 7D 4000 - 7D 7FFF  |
  | 7 | EEPROM    | 8D 4000 - 8D 7FFF  |
  | 8 | SYS       | FF 8000 - FF BFFF  | Keyboard
  | 9 | SYS       | FF 8000 - FF BFFF  | Keyboard                                      
  | A | SYS       | FF 8000 - FF BFFF  |                                       
  | B | SYS       | FF 8000 - FF BFFF  |                                       
  | C | BB RAM    | 7C 0000 - 7C 3FFF  |
  | D | EEPROM    | 8C 0000 - 8C 3FFF  |
  | E | BB RAM    | 7C 4000 - 7C 7FFF  |
  | F | EEPROM    | 8C 4000 - 8C 7FFF  |

NOTE:TODO: for NoIce to work correctly the utility ROM should be loaded in banks 3 and F on the Electron!

NOTE: the Electron mappings are similar to those for the BBC micro except that 
the ROM paging register is exclusive or'd with 0x0C and the SYS roms punch through in both maps

#### Master

TBC

### MOS in Map 1

When a Map 1 is in force the MOS at LC000..LFFFF is taken from Map 1's 
slot #9.

### MOSRAM

When either the MOSRAM jumper is fitted or a '1' has has been written to the 
MOSRAM bit of the SWMOS_CTL register the MOS at LC000-LFFFF will be taken
from slot #8 of the current map. 

This is useful for debugging the MOS ROM using NoIce and is also used to 
make a "flat" 64K RAM map for running non-MOS operating systems such as 
Flex for the 6800, 6809 or 6309.

TODO: remove FLEX shadow from vhdl
TODO: rename SWMOS_SHADOW to MOSRAM throughout vhdl/docs

### NoIce Debugger mappings

## 6809/6309 extras

The 6x09 CPUs have similar hardware reset and interrupt vectors to the
6502 and appear like the 6502 at the end of the 64K memory map. There 
are however more of them and these clash with "well known" MOS entry 
points. For this reason there is an extra logical mapping applied to 
6x09 series CPU whereby if a vector is being read, detected by the CPU
BA and BS pins being 0 and 1 respectively, then bit 11 of the address
is toggles such that vectors normally at LFFF0..F will actually be
read from LF7F0..F

## 65816 extras

The firmware for the 65816 CPU will normally boot in a MOS compatible mode such
that the 65816's logical bank 0 will map in the same way as a normal 6502
and the CPU will start in "emulation" mode. In this way the 65816 will
behave more or less identically to a 6502 except it may run faster. This is
known as "65816 boot mode".

The 65816 also has a "native" mode which unlocks some of its extended
functions but also requires a new set of hardware vectors. However, these
would clash with locations in the 6502 MOS and so there is an extra
logical mapping which redirects these vectors to chip RAM such that 
the vectors in native mode are fetched from L00FFxx to 00 8Fxx in ChipRAM. 
This is an experimental feature but has been used with some success in 
getting Communicator 65816 BASIC to run in native mode on an unmodified MOS.

Each time the hardware is reset the logical to physical mapping will
revert to this "boot mode". However it is possible to remap the 

It is possible to remap the 65816 to use a "flatter" memory map where
the bank register maps directly to the Physical bank *except* for bank
FF which will go through a MOS compatible logical to physical mapping. This
has not been widely used and may change in future. To exit boot mode
write a 0 to bit 5 of FF FE31 (L00FE31 in boot mode) see [below](#ff-fe31)


## 68008

TODO, get from old doco

## 68000

TODO


# Using JIM

The BBC Micro series feature a "page-wide" address expansion mechanism
that allows hardware to appear outside the normal memory map. This is
useful where there is a limited address space, such as on 8-bit CPUs 
limited to 64K of memory. 

The Blitter and Paula use 3 registers to control access to the JIM memory
map. These appear in the FRED page of memory - which can be accessed 
direct by 8-bit CPUs. [where Physical Addresses start FF they can be 
accessed direct on 8-bit CPUs]



 | Phys Address | Contents                         
 |--------------|----------------------------------
 | FF FCFE      | JIM paging register low byte
 | FF FCFD      | JIM paging register low byte
 | FF FCFF      | JIM device register

Note: when the device register is read back, if the Blitter/Paula device
is selected the complement of the devices number will be read back

The Paula and Blitter use the device select mechanism described at
[https://stardot.org.uk/forums/viewtopic.php?f=3&t=17222] 

Paula uses a device number of $D0 and the Blitter $D1. If the device
is detected/selected the complement $2F, $2E respectively will be read
back.

In addition the Blitter support ROM for 6502/6809 the zero-page location 
$EE to store the current device number. This should be set to the desired
device number *before* the device register is written as during interrupts
this value may be used by the support ROM to restore the device number.

It is necessary to first set the 

i.e. to access the Blitter from BASIC:

```
        10  A_JIM%=&FD00:A_DEV%=&FCFF:A_PAGH%=&FCFD:A_PAGL%=&FCFE:A_DEVSAVE%=&EE:DEVNO%=&D1
        ...
        100 REM Poke a value to physical address 12 3456
        110 ?A_DEVSAVE%=DEVNO%:?A_DEV%=DEVNO%
        120 ?A_PAGH%=&12:?A_PAGL%=&34:A_JIM%?&56=X%
```

Or in assembler to write the contents of Y to a 24 bit physical address 
stored in little-endian format in zeropage address &80

```
        
        LDA #&D1:STA &EE:STA &FCFF                      \ select device
        LDA &82:STA &FCFD:LDA &81:STA &FCFE             \ set paging registers
        LDX &80:TYA:STA &FD00,X                         \ write value
```

Note: on the Blitter the board will NOT output any access to the page 
select registers to the motherboard when the Blitter is selected as the current
device. However, on the Paula 1MHz bus device all accesses will be sent to all 
hardware. Care should be taken if there are devices on the 1MHz bus that might
respond to these accesses (such as an unmodified RetroClinic DataCentre)

## Saving device registers

In general when coding as the "current application" it is not necessary to
worry about saving device state but if coding an interrupt routine or a 
ROM it is necessary to restore the state of the device select and register
state after changing them so as not to disturb the foreground application.

```
        
        LDA &EE:PHA                                     \ save "current device"        
        LDA #&D1:STA &EE:STA &FCFF                      \ select device
        LDA &FCFD:PHA:LDA &FCFE:PHA                     \ save current paging register values
        LDA &82:STA &FCFD:LDA &81:STA &FCFE             \ set paging registers
        LDX &80:TYA:STA &FD00,X                         \ write value
        PLA:STA &FCFE:PLA:STA &FCFD                     \ restore paging registers
        PLA:STA &EE:STA &FCFF                           \ reselect original device
```

## Detecting Blitter / Paula

The presence of the Paula and Blitter can be confirmed by first writing the
device number to the Device Select register and then reading back that register
if the device is selected can be read back and the complement of the device
number will read back.

```
        LDA &EE:PHA                                     \ save "current device"        
        LDA #&D1:STA &EE:STA &FCFF                      \ select device
        LDA &FCFF:EOR #&D1:TAX                          \ exclusive or with #&FF
        PLA:STA &EE:STA &FCFF                           \ reselect original device
        INX:BEQ present                                 \ branch if 0 for present
        \ do something here for blitter not present
```



# Register Reference

## FF xxxx

The entire memory map of the BBC micro appears in bank FF. When accessed 
via the JIM mechanism of an 8-bit CPU this is just like addressing direct
to a normal 16bit address. On a 16 or 32 bit CPU the motherboard resources
can be accessed here. 

For more information see (Logical to Physical Mapping)[#logical-to-physical-mapping]

Note: when reading through to the motherboard via JIM the Blitter
sideways ROM/RAM mapping is NOT performed therefore it is possible to
access all ROMS on the motherboard by using this mechanism as the ROM
select register is always written to both the Blitter copy AND the 
motherboard.


 | Phys Address | Contents                                             
 |--------------|------------------------------------------------------
 | FF FCFD..FF  | JIM device and paging
 | FF FE05      | Electron ROM paging            
 | FF FE30      | ROM paging register            
 | FF FE31      | Sideways MOS/NoIce control
 | FF FE32      | Sideways MOS/NoIce restore
 | FF FE35      | Debug register 
 | FF FE36      | Memory aux control 1      
 | FF FE37      | "Low Mem Turbo" register.
 | FF FE3E..3F  | Mk.2 config registers (deprecated)



Note: the registers at FE3x may be moved to a different location in future
firmware releases to minimize incompatibilities with other memory expansion
hardware. For this reason caution should be exercised when using these
registers. If there is a reason to access these directly please contact
the firmware authors to register an interest. It may be possible to 
add an OSWORD call to the utility ROM to support your needs.


### FF FCFD..FCFF - JIM paging registers

See the section [Using JIM](#using-jim) for information on these registers

### FF FE30 ROMSEL

This register is kept in sync with the same register on the motherboard.
It is used to control the selection of sideways ROM/RAM in the logical
address space FF 8000..BFFF

When enabled sideways RAM/ROM accesses are mapped to Flash and ChipRAM
as outlined in the [Logical to Physical Mapping](#logical-to-physical)
section above. 

Note: this register is effectively ignored if the SWROM inhibit jumper
is fitted.


### FF FE31

### FF FE32
TODO: move from hardware overview documents to here and rewrite


### FF FE36 Throttle CPU

Bit 7
-----
When set any 65xx/T65/6x09 CPU will be throttled to 2MHz and synchronized 
with the motherboard phi2 clock. This can be useful to ensure that games
and demos run correctly. See \*BLTURBO command


### FF FE37 Low Memory Turbo

This register controls the mapping of the "low" portion of memory in the
65xx, T65, 6809 and 6800 CPUs logical to physical mappings. [Note: Z80
addresses are mapped differently]

Any bit that is set it in this register will cause a 4K chunk of memory
visible to an 8-bit cpu in the range 0-7FFF to be mapped to ChipRAM instead 
of the motherboard memory. This is used by the \*BLTURBO command 'L' option 
to accelerate programs on CPUs that run at >2MHz

i.e. ?&FE37 = &81 will cause addresses 0..0FFF and 7000-7FFF to come from
ChipRam when performing logical to physical address mapping.

The mapping causes logical addresses FF xxxx to become 00 xxxx. The first
32k of ChipRAM is generally reserved for this purpose.

Note: setting this at run time will likely crash the machine unless the 
current contents of the relevant memory are copied to chipRam first.

### FF FE3E..3F - Old Mk.2 firmware config registers

NOTE: these registers are now deprecated. On firmwares after May 2022 the 
configuration MUST be read using the mechanisms outlined in the 
[Boot Time Configuration](#boot-time-configuration) section.

Information about the old registers is contained in the [Old Mk.2 Firmware
Documentaton.md] file.




## Boot Time Configuration 

**Blitter only**

This section describes a set of read-only registers that describe the 
firmware that is currently programmed to the Blitter. 

### Build version and configuration

The version and configuration page in physical page FC 00xx contains 
information about the static build information for the current firmware.

Locations FC 0000 to FC 0080 contain a set of strings delimited by 0 bytes
and terminated by two zero bytes:

```
 | index        | Contents                                             |
 |--------------|------------------------------------------------------|
 | 0            | Repo version:                                        |
 |              | - G:<hash>[M] - Git Version hash                     |
 |              | - S:<number>[M] - Svn version number                 |
 |              | trailing 'M' indicates modified from the given no.   |
 |--------------|------------------------------------------------------|
 | 1            | YYYY-MM-DD:HH:MM:SS                                  |
 |              | build start time                                     |
 |--------------|------------------------------------------------------|
 | 2            | Board name - a short name for the configuration      |
 |--------------|------------------------------------------------------|
 | 3            | branch:repo                                          |
 |              | the repo name is shortened and the format should not |
 |              | be relied on and may change                          |
 |--------------|------------------------------------------------------|
```

More strings may be added in future

### Configuration switches

The boot-time configuration is read from the on-board configuration switches
(or build time options for firmware versions that do not support the function)
and presented in page FC 0080 onwards

```
 | address      | Contents                                             |
 |--------------|------------------------------------------------------|
 | FC 0080      | API Level                                            |
 |              | If this byte is 0 or FF then the firmware is older   |
 |              | and the rest of the information in this page is not  |
 |              | valid. Current Value = 1                             | 
 |--------------|------------------------------------------------------|
 | FC 0081      | Board/firmware level                                 |
 |              | - 0 - 1MHz Paula                                     |
 |              | - 1 - Mk.1 Blitter                                   |
 |              | - 2 - Mk.2 Blitter                                   |
 |              | - 3 - Mk.3 Blitter                                   |
 |--------------|------------------------------------------------------|
 | FC 0082      | API Sub level (usually 0)                            |
 |--------------|------------------------------------------------------|
 | FC 0083      | - reserved -                                         |
 |--------------|------------------------------------------------------|
 | FC 0084..87  | Configuration bits in force, see table below         | [1]
 |--------------|------------------------------------------------------|
 | FC 0088..8F  | Capabilities, see table below                        |
 |--------------|------------------------------------------------------|
```

[1] The configuration bits are read at boot time. Unused bits should be masked out
as future firmwares will likely utilize these bits

#### Configuration bits

FC 0084..FC 0087

The configuration bits are mapped differently for each board level:

##### Paula

???

##### Mk.1

???

##### Mk.2

 | address      | hardware                          |
 |--------------|-----------------------------------|
 | FC 0084      | configuration header bits  [7..0] |
 | FC 0085      | configuration header bits [15..8] |
 | FC 0086      | - unused -                        |
 | FC 0087      | - unused -                        |

##### Mk.3

 | address      | hardware                          |
 |--------------|-----------------------------------|
 | FC 0084      | PORTG[7..0]                       |
 | FC 0085      | PORTF[3..0] & PORTG[11..8]        |
 | FC 0086      | - unused -                        |
 | FC 0087      | - unused -                        |

### Blitter Capabilities

FC 0088..FC 008F

The capabilities of the current firmware build are exposed in API>0 at these 
locations the capabilities describe which devices and functions are available
in the current build

 | address     | bit # | descriptions                   |
 |-------------|-------|--------------------------------|
 | FC 0088     | 0     | Chipset                        |
 |             | 1     | DMA                            |
 |             | 2     | Blitter                        |
 |             | 3     | Aeris                          |
 |             | 4     | i2c                            |
 |             | 5     | Paula sound                    |
 |             | 6     | HDMI framebuffer               |
 |             | 7     | T65 soft CPU                   |
 | FC 0089     | 0     | 65C02 hard CPU                 |
 |             | 1     | 6800 hard CPU                  |
 |             | 2     | 80188 hard CPU                 |
 |             | 3     | 65816 hard CPU                 |
 |             | 4     | 6x09 hard CPU                  |
 |             | 5     | Z80 hard CPU                   |
 |             | 6     | 68008 hard CPU                 |
 |             | 7     | 680x0 hard CPU                 |
 | FC 008A..8F | *     | - reserved - all bits read 0   |
 |-------------|-------|--------------------------------|



# Introduction

The Paula and Blitter expansion boards expose a number of hardware 
registers. Most of the hardware registers are in the JIM page-wide except
where those registers enhance or reimplement a well-known mechanism, i.e.
the ROM paging register.

The addresses listed below are "physical" addresses in the form "AA BBCC"
for 65xx and 6x09 CPUs in with a 64k memory address space any registers
marked FF xxxx can be accessed directly. 




# Overview


Note: some of the registers below may be aliased in "unused" areas of the 
Physical 24-bit memory map. The use of aliased registers is discouraged
as these unused areas may be repurposed in future firmware releases.

```
    +--------------------------+-----------------------+ 
    | Physical address range   | hardware item         |
    +--------------------------+-----------------------+
    | $00 0000 - $1F FFFF      | SRAM                * | 
    +--------------------------+-----------------------+
    | $20 0000 - $5F FFFF      | SRAM repeats        * | 
    +--------------------------+-----------------------+
    | $60 0000 - $7F FFFF      | BB SRAM repeats     * | (if disabled then SRAM will appear here)
    +--------------------------+-----------------------+
    | $80 0000 - $BF FFFF      | EEPROM repeats        | (256/512Kb onboard Flash on mk.2)**
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
    |  "system" (except for SWRAM/SWMOS)               |
    | $FF 0000 - $FF 7FFF      | SYS RAM               |
    | $FF 8000 - $FF BFFF      | SYS ROM / SWRAM       |
    | $FF C000 - $FF FBFF      | SYS MOS / SWMOS       |
    | $FF FC00 - $FF FEFF      | SYS HARDWARE          |
    | $FF FF00 - $FF FFFF      | SYS MOS / SWMOS       |
    +--------------------------------------------------+
```

* On Mk.2 board the entirety of the range 00 0000 to 7F FFFF is served by
a single battery backed RAM. On the Mk.3 various combinations of normal
and battery backed RAM may be mapped to the area.


# Using JIM

The BBC Micro series feature a "page-wide" address expansion mechanism
that allows hardware to appear outside the normal memory map. This is
useful where there is a limited address space, such as on 8-bit CPU's 
limited to 64K of memory. 

The Blitter and Paula use 3 registers to control access to the JIM memory
map. These appear in the FRED page of memory - which can be accessed 
direct by 8-bit CPUs. [where Physical Addresses start FF they can be 
accessed direct on 8-bit CPUs]



```
 | Phys Address | Contents                                             |
 |--------------|------------------------------------------------------|
 | FF FCFE      | JIM paging register low byte                         |
 |--------------|------------------------------------------------------|
 | FF FCFD      | JIM paging register low byte                         |
 |--------------|------------------------------------------------------|
 | FF FCFF      | JIM device register                                  |
 |              | note: when read back, if the device is selected the  |
 |              | complement of the devices number will be read back   | 
 |--------------|------------------------------------------------------|
```


The Paula and Blitter use the device select mechanism described at
[https://stardot.org.uk/forums/viewtopic.php?f=3&t=17222] 

Paula uses a device number of $D0 and the Blitter $D1

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


# Logical to Physical Mapping

There is a layer of address remapping between the currently running CPU and
the hardware resources of the board. This allows for:

 - different CPU's require ROM at different locations
 - 8, 16, 32 bit CPU requirements
 - providing enhanced Sideways ROM/RAM


## MOS Compatible memory Map

In general most 8-bit CPUs use a "MOS compatible" memory map such that RAM
appears at 0-7FFF, Sideways ROM/RAM at 8000-BFFF and MOS ROM at C000-FFFF with
a "hole" for hardware register access at FC00-FEFF.

The default mappings for 6502, 65c02, 65816, 6809, 6309 and 6800 all use a 
similar mapping.


TODO: rom / ram mappings here


At boot time the RAM at 0000-7FFF is mapped to motherboard memory on 65xx systems
this will allow most games and demos to run without and modification. 

The motherboard memory has a maximum speed 

### Sideways ROM/RAM



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


```
 | Phys Address | Contents                                             |
 |--------------|------------------------------------------------------|
 | FF FCFD..FF  | JIM device and paging registers
 |--------------|------------------------------------------------------|
 | FF FE05      | Electron ROM paging register - note: experimental    |
 |--------------|------------------------------------------------------|
 | FF FE30      | ROM paging register                                  |
 |              | The blitter retains its own copy of the ROM paging   |
 |              | register for mapping Sideways RAM/ROM from ChipRAM   |
 |--------------|------------------------------------------------------|
 | FF FE31      | Sideways MOS/NoIce control                           |
 |--------------|------------------------------------------------------|
 | FF FE32      | Sideways MOS/NoIce restore                           |
 |--------------|------------------------------------------------------|
 | FF FE35      | Debug register                                       |
 |              | This register is used to debug firmware and should   |
 |              | not be accessed                                      |
 |--------------|------------------------------------------------------|
 | FF FE36      | Memory aux control 1                                 |
 |              | Bit 7 - 2MHz throttle                                |
 |--------------|------------------------------------------------------|
 | FF FE37      | "Low Mem Turbo" register.                            |
 |--------------|------------------------------------------------------|
 | FF FE3E..3F  | Mk.2 config registers (deprecated)                   |
 |              | Reads back configuration registers for older Mk.2    |
 |              | firmware                                             |

```


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


### FF FE31, 32
TODO: move from hardware overview documents to here and rewrite


### FF FE36 Throttle CPU

Bit 7
-----
When set any 65xx/T65/6x09 CPU will be throttled to 2MHz and synchronized 
with the motherboard phi2 clock. This can be useful to ensure that games
and demos run correctly. See \*BLTURBO command


### FF FE37 Low Memory Turbo

This register controls the mapping of the "low" portion of memory in the
65xx, T65, 6809 and 6800 CPU's logical to physical mappings. [Note: Z80
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

 | address | bit # | descriptions                   |
 |---------|-------|--------------------------------|
 | FC 0088 | 0     | Chipset                        |
 |         | 1     | DMA                            |
 |         | 2     | Blitter                        |
 |         | 3     | Aeris                          |
 |         | 4     | i2c                            |
 |         | 5     | Paula sound                    |
 |         | 6     | HDMI framebuffer               |
 |         | 7     | T65 soft CPU                   |
 |---------|-------|--------------------------------|
 | FC 0089 | 0     | 65C02 hard CPU                 |
 |         | 1     | 6800 hard CPU                  |
 |         | 2     | 80188 hard CPU                 |
 |         | 3     | 65816 hard CPU                 |
 |         | 4     | 6x09 hard CPU                  |
 |         | 5     | Z80 hard CPU                   |
 |         | 6     | 68008 hard CPU                 |
 |         | 7     | 680x0 hard CPU                 |
 |---------|-------|--------------------------------|
 | FC 008A | *     | - reserved - all bits read 0   |
 |   to    |       |                                |
 | FC 008F |       |                                |
 |---------|-------|--------------------------------|



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



        
        FA      HDMI
        FB      HDMI

 | FF FE31      | Debug mem control
 | FF FE32      | Debug mem control backup
 | FF FE35      | Debug reg
 | FF FE36      | Aux mem control
 | FF FE37      | BLTURBO "Low Turbo"
 | FF FE3E..3F  | Mk.2 configuratio bits (deprecated)



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




# Register Reference

## FF xxxx

The entire memory map of the BBC micro appears in bank FF. When accessed 
via the JIM mechanism of an 8-bit CPU this is just like addressing direct
to a normal 160bit address. On a 16 or 32 bit CPU the motherboard resources
can be accessed here. Note however that "special". 

Note: when reading through to the motherboard in this way the Blitter
sideways ROM/RAM mapping is NOT performed therefore it is possible to
access all ROMS on the motherboard by using this mechanism as the ROM
select register is always written to both the Blitter copy AND the 
motherboard.


```
 | Phys Address | Contents                                             |
 |--------------|------------------------------------------------------|
 | FF FE35      | Debug register                                       |
 |              | This register is used to debug firmware and should   |
 |              | not be accessed                                      |
 |--------------|------------------------------------------------------|
 | FF FE36      | Memory aux control 1                                 |
 |              | Bit 7 - 2MHz throttle                                |
 |              |    when set any 65xx/T65/6x09 CPU will be throttled  |
 |              |    to 2MHz and synchronized with the motherboard phi2| 
 |              |    clock.                                            |
 |--------------|------------------------------------------------------|
 | FF FE37      | "Low Turbo" register.                                |
 |              | Any bit that is set it in this                       |
 |              | register will cause a 4K chunk of memory visiuble to |
 |              | an 8-bit cpu in the range 0-7FFF to be mapped to     |
 |              | ChipRAM instead of the motherboard memory. This is   |
 |              | used by the *BLTURBO command 'L' option to accelerate|
 |              | programs on CPUs that run at >2MHz                   |
 |--------------|------------------------------------------------------|
 | FF FE3E..3F  | Mk.2 config registers (deprecated)                   |
 |              | Reads back configuration registers for older Mk.2    |
 |              | firmware                                             |

```

### FF FE3E..3F - Old Mk.2 firmware config registers

NOTE: these registers are now deprecated. On firmwares after May 2022 the 
configuration MUST be read using the mechanisms outlined in the 
[Boot Time Configuration](#boot-time-configuration) section



Note: the registers at FE3x may be moved to a different location in future
firmware releases to minimize incompatibilities with other memory expansion
hardware. For this reason caution should be exercised when using these
registers. If there is a reason to access these directly please contact
the firmware authors to register an interest. It may be possible to 
add an OSWORD call to the utility ROM to support your needs.


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


# 0. Introduction
-----------------


This document describes the firmware for the mk.2 board which is no longer supported
For the latest mk.3 board see
        -       [Mk.3 overview](hardware-overview-mk3.md)



# 1. BEEB Blitter and CPU card Mk.2 Hardware Overview
-----------------------------------------------------

The Dossytronics CPU development board includes an EP4CE10 mezzanine board, 
up to 2Mb of SRAM, 256K of FlashEEPROM, an optional crystal oscillator, 
optional cpu sockets for 6502A, 65c02, 65816, 6809, 6309, Z80, MC68008 
processors.

An optional super-capacitor and charging circuit are provided which can back up 
the SRAM.

The board plugs into a BBC micro CPU socket and is powered either by the cpu 
socket or via an auxilliary +5V regulated supply.

Simplified Diagram
---------------------

```
                         +------------+
                         |Onboard CPU |
                         |65x02, 6x09 |
                         |65816, z80  |
                         |or 68008    |
                         +------------+
                              | |      
                              | | CPU bus
        +-----------+    +------------+          +----------------+
        |           |    |            |          |                |
        |   CHIP    |    |  FPGA      |          |   BBC Micro    |
        |   RAM     |    |            |          |  motherboard   |
        |   2Mb     |    | +--------+ |          |                |
        +-----------+    | |DMAC    | |          |                |
           | |           | +--------+ |          +--+             |
           | | MEM bus   | |BLIT    | | SYS bus  | s|             |
           | +-----------| +--------+ |----------|Co|             |
           | +-----------| |SOUND   | |----------|Pc|------...    |
           | |           | +--------+ |          |Uk|------...    |
           | |           | |MEM CTL | |          | e| system bus  |
        +-----------+    | +--------+ |          | t|             |
        |           |    | |BUS CTL | |          +--+             |
        | Flash     |    | +--------+ |          |                |
        | EEPROM    |    | |AERIS   | |          |                |
        | 256K/512K |    | +--------+ |          |                |
        +-----------+    +------------+          +----------------+
                              | |
                         +------------+
                         | i2c config |
                         | eeprom     |
                         +------------+
```

[This description is based around how the current firmware accesses hardware
you may of course replace the firmware and completely replace the contents
of the FPGA.]
                                                                            
The CPU board contains three level shifting biderectional buffers to match the
5V signals of the SYS and CPU busses to the 3.3V LVTTL levels of the FPGA. 
In additions some cpu lines are buffered using a 74LS07 chip to give a larger 
voltage swing for the clock signals and some other signals.

The MEM bus operates on 3.3V signals and so is not buffered. 

[The Mk1 board shared the CPU and SYS which made the board less complex and 
used fewer FPGA pins but this precluded having the CPU run in the background
whilst a system to memory blit or DMA transfer happened.]

# 2. Jumpers
------------

This information is provisional as of 1/10/2020.
All jumpers marked nc should be left unconnected as they may be debug outputs

* **J1** VPB/Gnd

 [located NW of cpu sockets]

 This link should be fitted for 6502A processors and left off for all others it
 connects pin 1 of the 65x02/65816 processor sockets firect to 0V.

* **J2** SYS CPU Gnd

 [located above system cpu header area]

 This link should be normally fitted it connects pin 1 of the SYS connector to 
 ground

* **J3** Sound output, **J4** ground loop
 [located buttom middle of board]

        +-------+
        | # o o |
        +-------+
          L R G
              n
              d
              A

  J3 pins provide sound output from the chipset, the sound is filtered for a 
  nominal load impedance of 10k, however a wide range of load impedances will
  be tolerated without adverse effect (lower impedances will give lower output
  voltages).

  J4 can be used to connect GndA (the filter capacitors) to the local ground
  in most cases this pin should be left unconnected and the ground of the 
  amplifying device connected to pin 3 of J3 to provide a local ground for 
  minimum noise.

  TODO: measure voltages / impedances

  If the sound is to be fed and mixed via the on-board sound circuits of the 
  host computer the "mono" configuration should be set and flying leads fitted
  from the L pin and the GndA pins connected as follows


 BBC Model A/B
 -------------

 J4 should be left open

 J3 pin 3 should be connected to the east end of R29 on a Model B (audio ground)

 J4 pin 1 should be connected to the north end of R172 on a Model B (1Mhz audio)


 External sound
 --------------

 Alternatively the output(s) can be connected to the line in of an amplifer
 normally this required J4 to be left open and the Left, Right and Ground inputs
 of the amplifer connected to J3 pins 1, 2 and 3 respectively.

* **J5** System config

 [located on north-east corner above Mezzanine board]


 TODO: stereo / mono selector

 A set of headers are supplied on J5 for general IO or to be used for 
 configuration. On the current firmware they have the following uses:

        <--- W (system)
        
             |
        <---(N)- as marked on breakout board
             |
        
                  G G G G G G G G G G G G G G G G G G G G
                  n n n n n n n n n n n n n n n n n n n n
                  d d d d d d d d d d d d d d d d d d d d
                +-----------------------------------------+
             J5 | o o o o o o o o o o o o o o o o o o o o |
                | # o o o o o o o o o o o o o o o o o o o |
                +-----------------------------------------+
         cfg#         0 1 2 3 4 5 6 7 8 9 A B C D E F

                  S S t c c c s m n b m b s s s n V H 3 3
                  n n 6 p p p w o c u e u y y y c S S v v
                  d d 5 u u u r s   g m g s s s   Y Y 3 3
                  L R   0 1 2 o r   b i o 0 1 2   N N
                              m a   t   u         C C
                              x m   n   t
                                  
  * snd L/R: Sound 1 bit DAC / pwm output unfiltered
    sound output as 1 bit DAC values can be used to feed into more elaborate
    filtering circuitry if desired

  * t65 - enable internal t65 6502 emulation and disable any hard cpu.

  * cpu[] - these jumpers should be set to the correct configuration for the 
    fitted cpu: (o = open, + = closed). It is important to set these correctly
    even if the T65 core is being used.

  * sys[] - these jumpers should be set to the correct configuration for the 
    fitted type of host computer (o = open, + = closed). It is important to set 
    these correctly

```
| cpu[0]  | cpu[1]  | cpu[2]  | processor   | speed max
|---------|---------|---------|-------------|-----------
|    o    |    o    |    o    | 6502A       |     2 MHz
|    o    |    o    |    +    | R65C02      |     4
|    o    |    +    |    o    | W65C02S     |     8
|    o    |    +    |    +    | 65C816      |     8
|    +    |    o    |    o    | 6809E/6309E |     2
|    +    |    o    |    +    | 6309E       |     4
|    +    |    +    |    o    | Z80A        |     8
|    +    |    +    |    +    | 68008       |     8
```    

```
| sys[0]  | sys[1]  | sys[2]  | host/SYS    |
|---------|---------|---------|-------------|
|    o    |    o    |    o    | Model B     |
|    +    |    o    |    o    | Electron    |
|    o    |    +    |    o    | Model B+    |
|    +    |    +    |    o    | Master 128  |
```
all other settings are reserved

          


  * **swromx** when fitted ROM sets are swapped.
    When this jumper is open the T65 core will see ROM set 0
    and the hard cpu will see rom set 1. When fitted the 
    opposite will be true - see the section below on ROM sets    
  * **mosram** when fitted the bank 1 mos is taken from 
      bank 1 bank #8 instead of #9, this is provided to allow
      debugging of a MOS with breakpoints, normally it will
      be desirable to map the MOS into a Flash bank to avoid
      it becoming corrupted.
      In addition this jumper will cause the 68008 cpu to boot from   
      RAM at 7D xxxx instead of 8D xxxx and to map memory instead
      of rom (see [M68k Mapping](#m68kmap) below).
  * **bugbtn** a debug switch can be fitted to ground this
        input, which will cause an NMI, on the 6809 the
        CPU nNMI input is dedicated to this pin, 
        
        *New 4/9/2018*: For 65x02/T65 processors a falling edge
        on this input will (after 16 8MHz cycles) perform
        the following:
        - set bits 0 and 2 in the FE31 SWMOS register to
          map in the debug memory and ROM #8 into the MOS 
          workspace
        - cause an NMI 
        Bit 3 of SWMOS must be set to enable this behaviour
  
        Pre 4/9/2018
        [on other processors CPU nNMI will be asserted 
        if _either_ this pin or the SYS nNMI is asserted.
        There is a simple delay on this circuit, the
        signal must be low for 16 8MHz cycles to trigger 
        to avoid noise pickup and glitches from a remote
        switch.]
  
  * **memi** fit jumper to inhibit on-board SWROM/RAM in 
        which case SYStem sockets appear repeated as
        usual for BBC (useful if a bad ROM needs to
        be expunged)
        NOTE: this disables all SWROM/MOS including the
        NoIce debugger!

  * **bugout*** writing to bit 7 of FEFF sets this bit
  
  **Any nc jumpers or positions marked * must not be 
  jumpered as these may be outputs**


* **J6** CPU test pins

  [Located N of cpu sockets]

  Various marked CPU test pins, these are handy for 
  connecting a Hoglet decoder to a 65(c)02 direct
  [GitHub](https://github.com/hoglet67/6502Decoder)



* **P6** CPU voltage [incorrectly labelled should be J7]
  [located W near top cpu sockets ]

    +---+
  1 | # |  +5V
  2 | o |  --- vcc cpu
  3 | o |  +3.3V
    +---+

  This header allows the cpu voltage to be set to either
  5V or 3.3V. A jumper should be fitted as follows:

  1-2 [N] - 5V    [6502, 6x09, 65c02, 65816, Z80, 68008]
  2-3 [S] - 3.3V  [65C02, 65816] (slower, uses less power)


# 3. Memory Map Overview

    +--------------------------+-----------------------+ 
    |  logical/physical addr   | hardware item         |
    +--------------------------+-----------------------+
    | $00 0000 - $1F FFFF      | SRAM                  | (2Mb onboard SRAM on mk.2)
    +--------------------------+-----------------------+
    | $20 0000 - $7F FFFF      | SRAM repeats          | (may contain ram in future)
    +--------------------------+-----------------------+
    | $80 0000 - $BF FFFF      | EEPROM repeats        | (256/512Kb onboard Flash on mk.2)**
    +--------------------------+-----------------------+ 
    |       ---- undefined ---- do not use ----        |
    +--------------------------+-----------------------+ 
    | $FA 0000 - $FA FFFF      | HDMI registers        | 
    +--------------------------+-----------------------+ 
    | $FB 0000 - $FB FFFF      | HDMI memory           | 
    +--------------------------+-----------------------+ 
    | $FB 0000 - $FB FFFF      | Debug info            | 
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

    **TODO: check this 1/10/2020 mapping has changed, need to rework 68008 mappings?**

    NOTE: The address selection logic is simplified such that the SYS and chipset registers repeat:
      - Any bank with both top bits set will select either SYS or Chipset/Debug info
      - Odd banks will be SYS in this area (A(16) set)
      - Even banks will be Chipset registers A(17) clear or debug info A(17) set in this area
      - It is advised to not use any addresses other than the official ones for accessing
        devices as chip select logic may be changed

Note: the EEPROM is repeated at 80 0000, 90 0000 so that the same base address of
90 0000 can be used for both the mk.1 and mk.2 boards

The addresses above are not valid in all situations:
- JIM accesses can now access the entire memory space including SYS which 
  may be useful for accessing screen memory in 64k memory modes such as Flex
  etc
- 64k CPU directly accesses the "system area only" i.e bank $FF for 8bit cpus 
- BLIT/SOUND/DMAC can access all addresses, i.e. to  blit to / from SYStem memory/peripherals appear at
  addresses $FF xxxx

## 3.1 Sideways RAM/ROM mappings to physical memory

NOTE: Sideways ROM/RAM is enabled only while a MOS compatible map is in effect i.e. in Flex mode it has no effect.
NOTE: Sideways ROM/RAM is only visible to the CPU to access these addresses via DMA the physical address of the ROM/RAM slot needs to be used which can be obtained by OSBYTE xx TODO: OSBYTE to map rom/ram/etc to physical address. Accessing FF 8000 - FF BFFF will always access the roms on the motherboard, Acessing FF C000 - FF FBFF, FF FF00 - FF FFFF will always access the mos rom on the motherboard.
NOTE: if the "memi" jumper is fitted all these settings are ignored

Sideways ROM/RAM SETs:
----------------------

There are two sideways rom SETs that allow for having roms switch between the hard and soft CPU sets.
Map 0 is in effect if the t65 jumper is fitted 
Map 1 is in effect for hard processors
If SWROMx is fitted the above mappings are swapped


```

MAP 0
-----


    0   BB RAM      $ 7E 0000 - 7E 3FFF
    1   EEPROM      $ 8E 0000 - 8E 3FFF
    2   BB RAM      $ 7E 4000 - 7E 7FFF
    3   EEPROM      $ 8E 4000 - 8E 7FFF
    4   SYS IC 52
    5   SYS IC 88
    6   SYS IC 100
    7   SYS IC 101
    8   BB RAM      $ 7F 0000 - 7F 3FFF NB: also used as the SW MOS/FLEX bank
    9   EEPROM      $ 8F 0000 - 8F 3FFF 
    A   BB RAM      $ 7F 4000 - 7F 7FFF
    B   EEPROM      $ 8F 4000 - 8F 7FFF
    C   BB RAM      $ 7F 8000 - 7F BFFF
    D   EEPROM      $ 8F 8000 - 8F BFFF
    E   BB RAM      $ 7F C000 - 7F FFFF
    F   EEPROM      $ 8F C000 - 8F FFFF NB: also used as the SW MOS debug bank
                                        This slot will normally contain a copy
                                        of the bltutils rom

MAP 1
-----


    0   BB RAM      $ 7C 0000 - 7C 3FFF
    1   EEPROM      $ 8C 0000 - 8C 3FFF
    2   BB RAM      $ 7C 4000 - 7C 7FFF
    3   EEPROM      $ 8C 4000 - 8C 7FFF
    4   BB RAM      $ 7C 8000 - 7C BFFF
    5   EEPROM      $ 8C 8000 - 8C BFFF
    6   BB RAM      $ 7C C000 - 7C FFFF
    7   EEPROM      $ 8C C000 - 8C FFFF
    8   BB RAM      $ 7D 0000 - 7D 3FFF NB: also used as the SW MOS/FLEX bank
    9   EEPROM      $ 8D 0000 - 8D 3FFF NB: also used for MOS in Map 1 (not when mosram fitted)
    A   BB RAM      $ 7D 4000 - 7D 7FFF
    B   EEPROM      $ 8D 4000 - 8D 7FFF
    C   BB RAM      $ 7D 8000 - 7D BFFF
    D   EEPROM      $ 8D 8000 - 8D BFFF
    E   BB RAM      $ 7D C000 - 7D FFFF
    F   EEPROM      $ 8D C000 - 8D FFFF NB: also used as the SW MOS debug bank
                                        This slot will normally contain a copy
                                        of the bltutils rom

    In addition in when Map 1 is in effect the default mapping for the MOS rom 
    (when flex is not active) is from EEPROM #9 at 8C 0000 unless mosram is fitted when 
    it comes from SWRAM #8

```


M68008 address mapping oddities{#m68kmap}
===============================
  The M68k can address only 1MB of memory space which is remapped as follows to allow
  access to both ROM and RAMS

    The 68k processor has a special memory mapping: when the top bit(19) of the address is set:
    +--------------+------------------------------------------+------+
    | Top nibble   | Mapping                                  | Bank |
    | (A16..A19)   |                                          |      |
    +--------------+------------------------------------------+------+
    | F            | The system bank                          |   FF |
    +--------------+------------------------------------------+------+
    | E            | The Chipset registers bank               |   FE |
    +--------------+------------------------------------------+------+
    | D            | Current MOS - when mosram not fitted     |   8D |
    |              |  -- "" --   - when mosram is fitted      |   7D |
    +--------------+------------------------------------------+------+
    | others       | Map to RAM                               |00..0C|
    +--------------+------------------------------------------+------+

  Also when the 68008 first boots it needs its vectors to appear at 0 0000 to 0 00FF but
  that would normally map to RAM. A facility is provided such that a boot ROM can appear
  at 8D 3F00 (or 7D 3F00 if mosram is fitted) and it will be remapped to appear to the 
  cpu to be at 0 0000, for reads only. This mapping will remain in effect until the first 
  access of the JIM device register. The normal boot action of an OS ROM should be:

```
    ; copy rom vectors to low memory
    lea     $D0000,A6
    movea   #0, A0
    move.w  $FF, D0
.lp:move.l  (A6)+,(A0)+       ; note during "boot" writes to RAM pass through but reads from the bottom
                              ; page of RAM map to the boot rom 
    dbf     D0,.lp

    ; switch maps by temporarily selecting blitter device
    move.b  #$D1,$FFCFF       ; set jim device number
```

  i.e. copy the vectors to RAM and then 



Additional mappings:
====================
  Noice debug shadow ram gets mapped in at $C000-CFFF from 
    $ 7E 8000 - 7E FFFF (unused from slot #4 in map 0)
  When Map 1 is in effect the default mapping for the MOS rom (when flex is not active) 
    is from EEPROM #9 at 8D 0000 
  When Map 1 is in effect the default mapping for the MOS rom (when flex is not active) 
    is from EEPROM #9 at 8D 0000 
  

**CONFIG registers**

  **$FE3E,F** this register pair can be used to read back the current values
  on the configuration pins, the values are inverted and give a '1' where a 
  jumper is fitted. Writing to this register is reserved for future uses and
  should be avoided.

  $FE3E:

  Bit(s) | Value | Meaning
  -------|-------|--------------------------------------
   0    *|   1   | t65 core in operation
         |   0   | hard cput in operation
   3..1 *|  000  | 6502A @ 2 MHz
         |  100  | 65C02 @4Mhz
         |  010  | 65C02 @8Mhz          --currently 4Mhz
         |  110  | 65C816 @8Mhz         --currently 4Mhz
         |  001  | 6809E/6309E @2Mhz
         |  101  | 6309E @4Mhz
         |  011  | Z80A @8Mhz
         |  111  | 68008 @8Mhz
   4    *|   1   | swromx not fitted 
         |   0   | swromx fitted
   5     |   ?   | ?
   6     |   ?   | ?
   7     |   1   | bugbtn pressed         

  $FE3F:

  Bit(s) | Value | Meaning
  -------|-------|--------------------------------------
   0    *|   1   | memi jumper fitted i.e. chip swrom/ram disabled
         |   0   | normal
   1     |   X   | inverted bugout signal
   7..2  |   ?   | ?

NOTE: bits marked * are latched at reset time and do not reflect the active state
of the config pins
NOTE: bits marked ? should be masked out and ignored as these are used for various
debugging and test purposes which is likely to change with firmware updates


**SWROM/RAM registers**

Sideways RAM at $FF 8000 - $FF BFFF can be mapped into local chip RAM/EEPROM
by using the following registers:

**SWROM registers**

  **$FE30** this is a shadow copy of the BBC micro's own ROM select register, if 
  the value is in the range 4-7 then accesses to the memory at $FF 8000 to 
  $FF BFFF will access the SYS ROM sockets. Otherwise even numbered values 
  will map to chip SRAM (in the  battery backed portion) and odd numbered values
  will map to the EEPROM

[NOTE: (if the memory inhibit jumper is fitted then the BBC micro ROM sockets
  will be mapped as normal)]


## 3.2 Onboard Memory

The onboard SRAM and Flash EEPROM can be addressed by the CPU either through 
the JIM interface or as sideways ROM/RAM or via DMA.

## 3.3 The JIM interace

The entire address map $00 0000 to $FF FFFF can be accessed as a set of 256
byte pages of memory mapped into a single memory window at $FF FD00 and 
accessible to the CPU (not DMAC/BLIT/SOUND via JIM)

**JIM device select latch**

**$FCFF** JIM device select latch

To enable the local JIM interface the JIM device select latch must be set to &D1 
see the 2019 JIM protocol for details of the behaviour of the JIM interface

For compatibility with other devices zero page register EE should also be set
_before_ the latch is set to allow interrupt routines for other devices to also
use JIM. c.f. &F4 the paging shadow register.

Reading back the JIM latch after it has been set to &D1 will return the 
complement of the device number i.e. &2E. This can be used as a simple check for the presence of the Blitter/CPU card.

NOTE: by design only the cpu may set the jim device select latch. The paging registers can however be updated via DMA. Accessing FF FCFF via DMA will always be ignored by the chipset and will be passed to the SYS. Possibly leaving the system in a conflicted state with two different devices selected at once.

**JIM extended paging registers**

**$FCFD** JIM paging register (hi)  
**$FCFE** JIM paging register (lo)

When local JIM is enabled (using the JIM latch above) these registers 
become active. Writing values to these registers will set the page that is 
mapped in to appear in the JIM page at $FF FD00

Data can then be read/written to board SRAM, EEPROM, Chipset Registers or SYS via JIM.

Data can be written to the FlashEEPROM. However valid programming sequences must be sent before a write is attempted. See the source code for the UTILS ROM for an example.

The JIM extended paging registers can read back so long as the JIM
latch has been set.

## 3.4 Sideways MOS

The memory area at $FF C000 to $FF FBFF and $FF FF00 to $FF FFFF can be mapped to a sideways RAM bank (#9 or #8) with the use of the SWMOS reg

**SWMOS reg**

[Note: this is likely to change in the near future to make it more compatible
with Master/BBC B+]

**$FE31** this register controls whether the MOS ROM is in a system slot or 
alternatively mapped into sideways ram slot #9. Also this register enables or
disables the on-board JIM registers.

```
Bit     Purpose
===     =======
0  #    SWMOS_EN
        When set to 1 the MOS will execute from sideways bank #8 this bit is
        not normally reset when the break key is pressed a full reset 
		    is needed to return to executing from the SYS socket should the #8 
		    socket become corrupted*
1       '0'
2  #    SWMOS_DEBUG
        65x02, 6x09 only
        When set to 1 bit 0 (above) will map the MOS to sideways bank #F
        this is used on the 65x02 modes along with the debug / NMI button
        Additional memory areas will be swapped as outlined DEBUG MEMORY MAP
        below*
3       SWMOS_DEBUG_EN
        65x02, 6x09 only
        Debug enable, like bit 0 this requires a slow reset to clear. Once
        set the BUGBTN header pin as desribed will cause a "debug nmi" (see
        below)
4       FLEX shadow - when this bit is set the CPU sees memory at 0000-7FFF 
        taken from the chip RAM at $0D 8000 to $0D FFFF
5       65816 boot - 65816 only 
        In 65816 mode when this bit is set then the 65816 accesses to bank 0
        will have the same mapping applied as the 64k address space of the
        65x02 processors, accesses to bank FF are passed through direct to
        the motherboard (without BLTURBO mapping, but with ROM mapping).
        When clear bank FF will be mapped as per the 6502's mapping and
        bank 0 will access ChipRAM.

        This bit is reset to '1' on reset
6       SWMOS_DEBUG_5C
        65x02 only
        read only
        DEBUG becoming active was caused by a $5C NOP instruction being executed
        [Note: 6809 uses SWI instruction]
7       SWMOS_DEBUG_ACT
        65x02, 6x09 only
        read only
        DEBUG active, the debug memory mapping is in force*
```

Note*: Holding BREAK/nRESET low (or powering down the main board with the FPGA 
powered) for approx 3 seconds will also clear bit 0,7

### 3.5.1 DEBUG MEMORY MAP [65x02 only]

When the debug memory map is enabled (bit 0 and 2 of $FE31 SMOS are both set)
the MOS area of memory i.e. C000-FBFF and FF00 to FFFF will be mapped as follows:
```
C000-CFFF   = physical RAM 7E 8000 to 7E 8FFF this can be used by the 
              debugger as scratch memory, buffer space, etc
              [this is the SWRAM memory for ROM #4 which is always obscured by
              the SYS ROM]
D000-FBFF 
and
FF00-FFFF   = the top portion of SWROM #F (i.e. $ 8F D000 - 8F FFFF)
```

DEBUG NMI [65x02 only]
======================
A debug switch can be fitted to ground the bugbtn header pin input, which will 
cause an NMI [ on the 6809 the CPU nNMI input is dedicated to this pin]
      
A falling edge on this input will (after 16 8MHz cycles) perform the following:
  - save existing bits 0, 1 and 2 in FE31, these will be readable from FE32 
  - cause an NMI 
  - wait for the next NMI fetch and set bits 0 and 2 in the FE31 SWMOS register 
    to map in the debug memory and ROM #8 into the MOS workspace

This behaviour will be inhibited by holding the CPU nNMI low until $FE32 is 
next written to restore $FE31, this is to stop spurious multiple NMIs being 
generated from the debug button.

A consequence of these behaviours is that real NMI's will be lost whilst the
debugger is active.

Bit 3 of SWMOS must be set to enable this behaviour

DEBUG NOP [65x02 only]
======================
On the 6502A and 65c02 processors the opcode $5C is a NOP, when bit 3 of SWMOS
is set executing this instuction will cause the following behaviour:

  - save existing bits 0, 1 and 2 in FE31, these will be readable from FE32 
  - wait for the next vector fetch and set bits 0 and 2 in the FE31 SWMOS 
    register to map in the debug memory and ROM #8 into the MOS workspace
    [if an IRQ is pending this will be processed first]
  - cause and hold and nmi (as debug button)
This will effectively cause a BRK instruction to appear to have been executed
3 bytes after the 5C instruction (the 5C nop takes 2 bytes as arguments).

This is used by the NoICE debugger as its break point instruction, leaving the 
BRK instruction to be used as the regular MOS error mechanism.

Bit 3 of SWMOS must be set to enable this behaviour

WRITING BITs 2/3 of SWMOS
================================================ 
Writing a '1' to bits 2 and 3 of the SWMOS register will enter the noice debug 
memory map after the next instruction, saving the to the $FE32 register as above
this allows the debugger memory to be entered with an instruction sequence 
as below (example for 6809)

    ldx   #<address of entry routine in debugger memory>
    pshs  X
    lda   #$0C
    ora   $FE31
    sta   $FE31
    rts

the final rts will pull the debugger entry address from the stack in the 
_current_ map and set the PC to that address. The memory map will then be
swapped ready for the next instruction.


SWMOS debug save (65x02 only)
-----------------------------
**$FE32**


    (READ)
    0  #    SWMOS_EN
            *CURRENT*
            BIT 0 of SWMOS 
    1  #    BLIT_JIM_EN
            *CURRENT*, not saved BIT 1 of SWMOS
    2  #    SAVED_SWMOS_DEBUG
            BIT 2 of SWMOS when the debug NMI/5C was executed
    3  #    SWMOS_DEBUG_EN
            *CURRENT*, not saved BIT 3 of SWMOS
    4       FLEX 
            *CURRENT*, not saved BIT 4 of SWMOS
    5       '0'
    6       SWMOS_DEBUG_5C
            *CURRENT*, not saved BIT 5 of SWMOS
    7       SWMOS_DEBUG_ACT
            *CURRENT*, not saved BIT 7 of SWMOS


[Note: this is likely to change to along with SWMOS register]

When a debug NMI occurs on a 65x02 machine the SWMOS register will be saved
here prior to setting the SWMOS bits 0, 1 and 2 can be read by the debugger
to check the machine state before a debug NMI and to restore the state when
exiting the NMI

Any write to this register is a special case. A state machine will wait until
after the next CPU sync that before writing the data contained in this register
to $FE31. This for an exit from a debug NMI of the form

    .nmi_exit_to_sys
      pla
      tax
      pla
      tay
      pla
      sta $FE32
      rti                 ; at this point the old SWMOS state will be restored 
                          ; from the contents of $FE32

The current values of FE31 are returned in FE32 to allow code such as below to 
access the memory map as it stood when the debug nmi / 5C occurred.

    .get_byte
      lda $FE31
      pha
      lda $FE32
      sta $FE31
      lda ($00),Y
      tax
      pla
      sta $FE31
      rts

This code would need to be executed from memory other than C000-FFFF as the 
act of setting FE31 would likely page out the current code!


### 3.6 Flex Shadow RAM (6809)

When flexmode is set the whole 32k 0000-7FFF is taken from chip RAM at
$ 0D 8000 - 0D FFFF - this has to be manually paged out to get screen writes
The memory at 8000-BFFF is mapped as usual using SWROM
The memory at C000-FFFF is mapped as usual using SWMOS



# 4. 6809 peculiarities
-----------------------

## 4.1 A11 adress remapping
---------------------------

The 6809 processor has more hardware vectors than the 6502 processor and this
means that these would overlap with the familiar OSXXX system calls of the 
Acorn MOS.

To simplify software porting and help maintain compatibility in BASIC programs
the hardware vectors are remapped from FFF* to F7F* by setting A11 low during
vector fetches.

## 4.2 NMI to FIRQ
------------------

The NMI response of the 6809 is to stack all registers before proceeding to the
interrupt vector. This may be too slow for some hardware devices and so the NMI
line is remapped to the FIRQ line on the 6809 processor. The MOS is being 
updated to support this for disc and Econet accesses.

# 5. The Chipset

## 5.1 DMAC - the dma controller
--------------------------------

BEEB Base address: **$FE FC90**

The DMAC or DMA controller is a simple device for reading/writing bytes to/from
hardware registers or devices.

There are four DMA channels [currently only one can be used at a time]

For user applications it is recommended only to use channel 0 and to always
set FE FC9F=0 before any operation. 

The source and destination registers are programmed with starting addresses,
a count register is set to indicate the number of bytes to transfer and the control register set to increment or decrement the source/destination after each
cycle. 

| Address   |Purpose
|-----------|--------------------------------------------------------
|  +0       | Control register - this should be set last, setting this register with bit 7 set will start the transfer.
|  +1/2/3   | Source address (big endian 24 bit address)
|  +4/5/6   | Destination address (big endian 24 bit address)
|  +7/8     | Count - 1
|  +9       | Data (may be read after a transfer) [deprecated : For 16 bit transfers returns the MSB ]
|  +A       | Control 2 register - this should be set before the main control register
|  +B       | Pause value
| ...       |
|  +F       | Channel select, setting this register maps in the lower 0-9  registers for the selected channel. When setting this register unused bits (2-7) should be 0, when reading this register future firmwares may set other bits.

**Control register bits**

```
  7   -   ACT : (set this bit to 1 to initiate/test for completion)
  6   -   n/a : always set as 0
  5   -   EXT : enable extended functions in control register 2
  4   -   HLT : If set the CPU is halted whilst the transfer proceeds
  3   \
  2   _\  SS  : source step (up/down/none)
  1   \
  0   _\  DS  : Dest step (up/down/none)
```


**Control2 register bits**
[ bits marked * are only obeyed if the EXT bit is set in CTL, this to allow
  fewer writes to set up for simple memory moves]

```
  7   -   IF  : Interrupt flag - any write to control or control2 clears the 
                interrupt flag
  6   -   n/a : set as 0
  5   -   n/a : set as 0
  4   -   n/a : set as 0
  3   -   \   
  2   -   _\  : word/step size - see below
  1   -   IE  : Interrupt enable, when set the IF flag (set on completion)
                causes an interrupt
* 0   - PAUSE : the value in pause val register will be used to insert that
                many 8MHz wait states after each source read. This is useful
                to add a small delay for slower hardware where a normal cpu
                based delay would be too big a delay
```

[Note: The current firmware does not support polled or background transfers. 
All transfers should have the HLT flag set]

**Step values**

```
  "00" - none : The address will not be incremented (to write repeatedly to a
                single register)
  "01" -   up : The address will be incremented
  "10" - down : The address will be decremented
  "11" - nop  : The address is not incremented, nor is the read/write performed
                useful for memory fills or draining a register
                - note writing to the data register writes both upper and lower
                  bytes so 16 bit fills are possible so long as ls and ms bytes
                  are the same.
```
 
For example to transfer the entire screen memory to the chip ram at $00 0000
reversing all bytes:
  
```
  [6809 code]
  lda   #$D1
  sta   $EE
  sta   $FCFF     ; select jim device
  ldd   #$FEFC    ; set jim page
  std   $FCFD
  clr   $FD9F     ; set channel 0  
  lda   #$FF
  sta   $FD91     ; src system bank
  ldd   #$3000    ; screen base
  std   $FD92     ; src addr
  clr   $FD94     ; dest bank = 0
  clr   $FD95     ; dest addr hi
  clr   $FD96     ; dest addr lo
  ldd   #$4FFF
  std   $FD97     ; count - 1
  lda   #$96      ; Act, HLT, SS=up, DS=down
  sta   $FD90
```

This should transfer the whole 20K screen to chip ram in just over 10ms i.e.
1 system cycle per byte.

**Word Size values**

```
"00" - byte : (default bytewise) 
              a byte will be read from source then written to dest
"01" - word : (16 bit register) 
              two bytes will be read from source, source + 1 then written to 
              destination, destination + 1 - useful for reading from/writing 
              to a 16 bit register. 
"10" - wordswapdest: (16 bit register, reverse bytes at dest) 
              two bytes will be read from source, source+1 then written to 
              dest+1, dest i.e. swapping byte order at dest
"11" - wordswapsrc: (16 bit register, reverse bytes at src) 
              two bytes will be read from source+1, source then written to 
              dest, dest+1 i.e. swapping byte order at src
```
  Note: count is number of 16 bit words in non-byte cases
  Note: when transfering 16 bits and moving dowwards the first bytes will be
  at start_addr+0/1 then start_addr is decremented by 2

Chip ram to chip ram transfers can operate faster (currently at 8MHz so 4MB/s).

If sound samples are playing then these will steal cycles from the DMAC and 
will slow down the transfer accordingly. 



## 5.2 the BLITTER chip
-----------------------

Dataflow overview
-----------------

```
                          +-----------+      +-----------+      +-----------+
                          |® A data   |      |® B data   |      |® C data   |
                          |           |      |           |      |           |
                          +-----------+      +-----------+      +-----------+
                             |     |            |     |               |
                             |     |            |     |               |
                         +---v---+ |        +---v---+ |               |
                         |® prev | |        |® prev | |               |
 +------------+          |A      | |        |B      | |               |
 |®shift B    +--+       +-------+ |        +-------+ |               |
 +------------+  |           |     |            |     |               |
                 +-----------|-----|------+     |     |               |
                             |     |      |     |     |               |
 +------------+           +--v-----v--+   |  +--v-----v--+            |
 |®shift A    +-----------+» shift A  |   +--+» shift B  |            |
 +------------+           |      top8 |      |      top8 |            |
                          +-----------+      +-----------+            |
                                   |                  |               |
 +------------+                 +--+                  |     +---------+
 |®1st mask   +--------+        |                     |     |         |
 +------------+        |  +-----v-----+               |     |         |
 |§1st mask   +------+ +-->   Apply   |               |     |         |
 +------------+      +---->   Masks   |               |     |         |
                     +---->           |               |     |         |
 +------------+      | +-->           |           +---v-----v---+     |
 |®last mask  +------+ |  +-----------+           |             |     |
 +------------+        |        |                 |             |     |
 |§last mask  +--------+        |        +-------->  Function   |     |
 +------------+                 |        |        |  Generator  |     |
                                |        |        |             |     |
 +------------+           +-----v-----+  |        |             |     |
 |§slice#     +----------->   Slice   |  |        +-------------+     |
 +------------+           |   Mask    |  |               |            |
                          +-----------+  |               |            |
                                |        |               |            |
                                |        |               |            |
 +------------+           +-----v-----+  |          +----v----+  +----v----+
 |®mode bpp   +-----------> 1bpp +^ X |  |          | D data  |  | E data  |
 +------------+           | mode      |  |          | out     |  | out     |
                          | exploder  +--+          +---------+  +---------+
                          +-----------+
```



Line Drawing Mode
=================

In the line drawing mode the blitter uses a state machine to implement a Bresenham line drawing
routine.

I will not fully elaborate on Bresenham here as it is well documented elsewhere. Suffice to say 
that a line is modeled as a major axis (the longest) and a minor axis and a slope which is 
major/minor.

In the blitter the coordinates need to be swapped such that the major axis is going either up
the screen or to the right. 

When the major axis is going up then the minor axis can either be to the left or to the right,
when the major axis is going right then the minor axis can either be up or down. 

Bits are set in the control register to select line drawing mode and the major and minor
directions.

The Bresenham algorithm works on the idea of an error register which contains how far from the 
major axis the next pixel will be. For each pixel plotted the minor axis magnitude (DMINOR) will
be subtracted from the error register and if the error register overflows (goes negative) then
the next pixel will move 1 pixel in the minor direction and the major axis magnitude (DMAJOR)
will be added to the error register. In this way the line's slope is accurately modelled.

Each pixel is plotted by first reading the screen and then setting the relevant pixel and writing
back to the screen. The writing is done using the FUNCGEN register such that effects (OR AND XOR SET)
can be achieved as with the normal blitter mode.

The pixel within a character cell that is to be plotted is generated by using the value in DATA_A 
as a mask - data are NOT passed through the EXPLODER! When moving left/right to decide whether to 
move to the next character cell the left/right-most bit of DATA_A is checked. In line mode DATA_A 
is always shifted by 1 bit in line mode (SHIFTA/B is ignored).



```
SPRITE MODE                             LINE MODE
-----------------------------------------------------------
DATA_B                                  PXFORECOL     8
DATA_A                                  PXMASK        8
WIDTH|HEIGHT                            CMAJOR        10
ADDR_A                                  ERRACC        15  
ADDR_B                                  DMAJOR        15
STRIDE_A                                DMINOR        15
BLTCON:MODE(0) 1-UP,0-RIGHT             DIRMAJ        1
BLTCON:MODE(1) 1-LEFT/UP,0-RIGHT/DN     DIRMIN        1   ; when set to 1 effectively makes minor axis CCW wrt major 
FIRST_A                                 PXMASK_NEXT   8   ; used internally
```



Aeris
-----

The Aeris chipset performs a function analogous to the copper chip in the Amiga
Copper chip but with its functionality tweaked to better suit the BBC Micro and
its 8 bittedness {hopefully}


Horizontal ticks are 1/32nd of a PAL line i.e. 500kHz measured from the start of HS

Vertical ticks are raster lines after VS


Registers
---------

FE FCB0 +

      0     Control Register
              bit 7 - act, when set will start program at next vsync
              bit 6 - interrupt, may be used to cause an interrupt
              bit 3..0 - may be used to pass data from Aeris program to CPU

      1     Base Address, 24 bit memory address of program.



The chip is idle until the Control Register's top bit is set at which point it 
will wait for the next VSYNC and then start executing the program. Subsequent 
VSYNCS will restart the program immediately.

A program consists of simple instructions as outlined below. These can be stored
either in SYStem memory in which case the program will execute at roughly 1MHz
when sharing cycles with the CPU or 2MHz otherwise; in chip RAM it will run at 
either 4MHz when sharing with the CPU or 8MHz otherwise.

During blits there may be further slow downs due to cycle sharing, the proposed
SYNC/UNSYNC instructions might be used to mitigate this


Operations
==========

[Items marked * are not yet implemented]


WAIT
----

Waits for a specific scan line and or horizontal position

opcode    arg0      arg1      arg2

7654 3210 7654 3210 7654 3210 7654 3210 

0000 mmmm mmmm mnnn nnVV VVVV VVVH HHHH

m mmmm mmmm - mask for raster line
V VVVV VVVV - raster line
n nnnn      - mask for line counter
H HHHH      - line counter

SKIP
----

skip next instruction if masked counters are >= arguments

opcode    arg0      arg1      arg2

0001 mmmm mmmm mnnn nnVV VVVV VVVH HHHH

m mmmm mmmm - mask for raster line
V VVVV VVVV - raster line
n nnnn      - mask for line counter
H HHHH      - line counter

MOVE16I
-------

move to hardware register

opcode    arg0      arg1      arg2

0010 bbbb hhhh hhhh DDDD DDDD DDDD DDDD

move data to "hardware register" h in bank b (see below), two bytes are moved
in order to _incrementing_ hardware register. Suitable i.e. for writes to 
CRTC FE00


MOVE16
------

move to hardware register

opcode    arg0      arg1      arg2

0011 bbbb hhhh hhhh DDDD DDDD DDDD DDDD

move data to "hardware register" h in bank b (see below), two bytes are moved
in order to _the same_ hardware register. Suitable i.e. for writes to NULA FE23

MOVE
----

move to hardware register

opcode    arg1      arg2

0100 bbbb hhhh hhhh DDDD DDDD

move data to "hardware register" h in bank b (see below)

BRANCH
------

opcode    arg1      arg2

0101 0--- dddd dddd dddd dddd

branch by 16 bit signed displacement. Displacement is added to the PC after it
has been incremented i.e. when pointing at next instruction.

BRANCH link 
-----------

opcode    arg1      arg2

0101 1ppp dddd dddd dddd dddd

branch by 16 bit signed displacement. Displacement is added to the PC after it
has been incremented i.e. when pointing at next instruction. The register p is 
loaded with the current PC before it changes and can be used as a return address
from a subroutine


MOVEP
-----

Move address to pointer register.

opcode    arg1      arg2

0111 -ppp dddd dddd dddd dddd

Sets the pointer register ppp to the address given by adding the signed
displacement to the PC. Displacement is added to the PC after it
has been incremented i.e. when pointing at next instruction.

MOVEC
-----

Move number to counter register

opcode    arg2

1000 -ccc nnnn nnnn

The 8 bit value following the opcode is moved to the counter register ccc.

PLAY
----

Execute move commands from pointer.

opcode    arg2

1001 0ppp nnnn nnnn

nnnn nnnn 16 bit words at pointer register ppp are executed as if they were
move instructions. The pointer is incremented after each item is executed.

PLAY16
----

Execute move16 commands from pointer.

opcode    arg2

1001 1ppp nnnn nnnn

nnnn nnnn 16 bit words at pointer register ppp are executed as if they were
move instructions. The pointer is incremented after each item is executed.


ADDC
----

Add to counter register

opcode    arg2

1010 0ccc ssss ssss

The signed displacement is added to the counter register.

ADDP
----

Add to pointer register

opcode    arg2

1010 1ppp ssss ssss

The signed displacement is added to the pointer register.

MOVECC
------

Move counter to counter

opcode    arg2

1011 0--0 -aaa -bbb move counter b to counter a

MOVEPP
------

Move pointer to pointer

opcode    arg2

1011 0--0 -aaa -bbb move pointer b to pointer a


SYNC
----

opcode

1100 0--1

halt the blitter and cpu and wait for the next horizontal region to allow 
finer control of timing

UNSYNC
------

opcode

1100 1--0

restart blitter and cpu

RET
---

return from subroutine

opcode

1101 1ppp

loads the PC from pointer ppp


DSZ
----

Decrement and Skip if Zero.

opcode    

1110 -ccc 

Decrements the given counter and skips the next instruction if it becomes zero


WAITH
-----

Wait for HSYNC

opcode

FFFF 0000

Waits until next hsync is received

24bit addresses
===============

All pointers and the program counter are treated as 16 bit values within the
bank of the prog-base register. Any branches, adds etc that go outside this
area will wrap around.

POINTERS
========

Pointers can be used to point at data or instructions embedded within a program.
There are 8 pointers that can be used for any purpose. The pointers are held
as 16 bit values which the top 8 bits of the prog_base register is used to set
the memory area.

COUNTERS
========

Counters can hold an 8 bit value. There are 8 counters.

HARDWARE REGISTER ADDRESSES
===========================

a register address is in the form
bbbb rrrr rrrr

the bbbb part maps to a bank of register memory:

bbbb  description
0000  FF FCxx i.e. FRED
0001  FF FDxx i.e. JIM
0010  FF FExx i.e. SHEILA
0011  FF FFxx ROM - not much use!
0100  FE F4xx
..
1100  FE FCxx DMAC page
..
1111  FE FFxx


Do not use banks other than 0,1,2 and C as these are likely to be reassigned in
future.


op code
+-----------+-----------+-----------+-----------+----------------------------+
| 0000 mmmm | mmmm mnnn | nnVV VVVV | VVVH HHHH | WAIT                     I |
+-----------+-----------+-----------+-----------+----------------------------+
| 0001 mmmm | mmmm mnnn | nnVV VVVV | VVVH HHHH | SKIP                       |
+-----------+-----------+-----------+-----------+----------------------------+
| 0010 bbbb | hhhh hhhh | DDDD DDDD | DDDD DDDD | MOVE16I                    |
+-----------+-----------+-----------+-----------+----------------------------+
| 0011 bbbb | hhhh hhhh | DDDD DDDD | DDDD DDDD | MOVE16                     |
+-----------+-----------+-----------+-----------+----------------------------+
| 0100 bbbb | hhhh hhhh | DDDD DDDD |           | MOVE                       |
+-----------+-----------+-----------+-----------+----------------------------+
| 0101 0--- | dddd dddd | dddd dddd |           | BRANCH                     |
+-----------+-----------+-----------+-----------+----------------------------+
| 0101 1ppp | dddd dddd | dddd dddd |           | BRANCH link                |
+-----------+-----------+-----------+-----------+----------------------------+
| 0110 ---- | ---- ---- | ---- ---- |           | --                         |
+-----------+-----------+-----------+-----------+----------------------------+
| 0111 -ppp | dddd dddd | dddd dddd |           | MOVEP                      |
+-----------+-----------+-----------+-----------+----------------------------+
| 1000 -ccc | nnnn nnnn |           |           | MOVEC                      |
+-----------+-----------+-----------+-----------+----------------------------+
| 1001 0ppp | nnnn nnnn |           |           | PLAY                     I |
+-----------+-----------+-----------+-----------+----------------------------+
| 1001 1ppp | nnnn nnnn |           |           | PLAY16                   I |
+-----------+-----------+-----------+-----------+----------------------------+
| 1010 0ccc | ssss ssss |           |           | ADDC                       |
+-----------+-----------+-----------+-----------+----------------------------+
| 1010 1ppp | ssss ssss |           |           | ADDP                       |
+-----------+-----------+-----------+-----------+----------------------------+
| 1011 0--0 | -aaa -bbb |           |           | MOVECC                     |
+-----------+-----------+-----------+-----------+----------------------------+
| 1011 0--1 | -aaa -bbb |           |           | MOVEPP                     |
+-----------+-----------+-----------+-----------+----------------------------+
| 1011 1--- |           |           |           | -                          |
+-----------+-----------+-----------+-----------+----------------------------+
| 1100 0001 |           |           |           | SYNC                       |
+-----------+-----------+-----------+-----------+----------------------------+
| 1100 0000 |           |           |           | UNSYNC                     |
+-----------+-----------+-----------+-----------+----------------------------+
| 1101 -ppp |           |           |           | RET                        |
+-----------+-----------+-----------+-----------+----------------------------+
| 1110 -ccc |           |           |           | DSZ                        |
+-----------+-----------+-----------+-----------+----------------------------+
| 1111 0000 |           |           |           | WAITH                      |
+-----------+-----------+-----------+-----------+----------------------------+
| 1111 ---- |           |           |           | -                          |
+-----------+-----------+-----------+-----------+----------------------------+

Operations marked with an "I" in the right column can be interrupted by a vsync
all other ops will only check for a vsync during a fetch. This ensures that
16 bit moves etc do not terminate in the middle of a move which might leave
hardware registers in an undefined state. PLAY will only terminate while 
fetching the first byte of the move data.













# 0. Introduction
-----------------


This document describes the firmware for the mk.1 board which is no longer supported
For the latest mk.3 board see
        -       [Mk.3 overview](hardware-overview-mk3.md)



### Changes

* 25/4/2018 - SYStem board nNMI now maps to CPU nFIRQ for 6809 processors (nNMI 
  for all others)


##Known issues

* dmac accesses to system hardware untested and subject to timing issues 
  - requires an extra wait state to allow address bus to be set at start
    of phi1 where follows a chip-ram access
* occassional failure to boot - have to press CTRL-BREAK
  multiple times to clear. Suspect bugs in MOS startup 
  code.



===============================================================================
1. BEEB 6809 Hardware Overview
===============================================================================

The Dossytronics CPU development board includes a MachXO2 mezzanine board, 
1MB of SRAM, 512K of FlashEEPROM, a crystal oscillator, optional cpu sockets.
A super-capacitor and charging circuit are provided which will back up the 
top 512K of SRAM.

The board plugs into a BBC micro CPU socket and is powered by a USB lead 
connected to the mezzanine board.

Simplified Diagram
---------------------
```
+-----------+    +------------+   +------------+          +----------------+
|           |    |            |   |Onboard CPU |          |                |
|   CHIP    |    |  FPGA      |   |65x02,6x09  |          |   BBC Micro    |
|   RAM     |    |            |   |65816       |          |  motherboard   |
|           |    | +--------+ |   +------------+          |                |
+-----------+    | |DMAC    | |        \ /                |                |
   | |           | +--------+ |---------^ A               +--+             |
   | | mem bus   | |BLIT    | |        / \           B    | s|             |
   | +-----------| +--------+ |--------+ +----------\ /---|Co|             |
   | +-----------| |SOUND   | |---------------------/ \---|Pc|------...    |
   | |           | +--------+ |      local bus       |    |Uk|------...    |
   | |           | |MEM CTL | |----------------------+    | e| system bus  |
+-----------+    | +--------+ |                           | t|             |
|           |    | |BUS CTL | |                           +--+             |
| Flash     |    | +--------+ |                           |                |
| EEPROM    |    |            |                           |                |
|           |    |            |                           |                |
+-----------+    +------------+                           +----------------+
```

[This description is based around how the current firmware accesses hardware
you may of course replace the firmware and completely replace the contents
of the FPGA. For instance the CPU buffer could be left disconnected and a
soft-core cpu implemented in the FPGA.]
                                                                            
The CPU board contains three level shifting biderectional buffers. Two of these
buffers (A,B) can be used to isolate the CPU or the SYS (main board) from the 
local bus. 

The CPU can be disconnected from the local bus, this is mainly used where the 
CPU is halted and the DMAC/BLIT/SOUND hardware wish to directly address the 
SYStem memory/hardware.

The SYS socket can also be disconnected, when the CPU wishes to directly address
the local DMAC/BLIT/SOUND etc hardware, or when the CPU is accessing the local
"chip ram", either through the JIM interface or as sideways RAM. When the CPU is
disconnected the SYStem address lines will be pulled into a known state to free 
the BBC micro bus.

All other signals to/from the CPU and SYS to the FPGA pass through a third
buffer (not shown for simplicity) which is always enabled and merely translates
the 5V TTL signals of the SYS/CPU to the LVTTL signals required by the FPGA.

Prior to the SYS buffer being disconnected the BUS CTL circuit will "blip" the
local bus (by briefly disconnecting the CPU buffer and pulling all address
lines high) after which point pull-up resistors on the address bus hold the 
system bus at $FFFF.

===============================================================================
2. Jumpers
===============================================================================

This information is accurate as of 4/4/2018.
All jumpers marked nc should be left unconnected as they may be debug outputs

* **J1** VPB/Gnd

 [located W of cpu sockets]

 This link should be fitted for 6502A processors and left off for all others

* **J2** SYS CPU Gnd

 [located above system cpu header area]

 This link should be fitted on the BBC ModelB it connects
 Pin 1 of the cpu header to ground


* **J3** Sound output

        +---+
        | # | sound out (filtered)
        | o | sound ground
        +---+

 The south pin 2 should normally be connected to the 
 east end of R29 on a Model B

 The north pin 1 should normall be connected to the 
 north end of R172 on a Model B

 Alternatively the output can be connected to the line
 in of an amplifer.

* **J4** local audio ground

 The audio output filter is normally grounded via the 
 flying leads to whatever amplifier is connected however
 it is possible to ground the filter locally by adding 
 this link, however this tends to be more noisy.

* **J5** System config

 [located on north-east corner above Mezzanine board]

 A set of headers are supplied on J5 for general IO or to be used for 
 configuration. On the current firmware they have the following uses:

        <--- W (system)
        
             |
        <---(N)- as marked on breakout board
             |
        
                  G G G G G G G G G G G G G G 
                  n n n n n n n n n n n n n n 
                  d d d d d d d d d d d d d d 
                +-----------------------------+
             J5 | o o o o o o o o o o o o o o |
                | # o o o o o o o o o o o o o |
                +-----------------------------+
                  S c c c n n b n b b m A 3 3
                  n p p p c c u c u u e 1 v v
                  d u u u     g   s g m 1 3 3
                    0 1 2     o   p b i 
                              u   u t
                              t   l n
                                  
  * **snd** Sound 1 bit dac / pwm output unfiltered

  * **cpu[]** these jumpers should be set to the correct
    configuration for the fitted cpu:
  
        | cpu[0]  | cpu[1]  | cpu[2]  | processor   |
        |---------|---------|---------|-------------|
        | open    | open    |       X | 6502A       |
        | open    | closed  |    open | 65C02       |
        | open    | closed  |  closed | 65C816      |
        | closed  | X       |       X | 6809E/6309E |
          
  * **bugout*** writing to bit 7 of FEFF sets this bit
  
  * **buspul*** set to 0 when the cpu is not accessing the system
        bus, which pulls the address lines to a known state
        (currently FEFF, however this will change.)
  
  * **bugbtn** a debug switch can be fitted to ground this
        input, which will cause an NMI, on the 6809 the
        CPU nNMI input is dedicated to this pin, 
        
        *New 4/9/2018*: For 65x02 processors a falling edge
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
  * **A11*** local A11 with translation (used internally
        for 6x09/65816 vector address translation)
  
        *Do not add a jumper to this position!*
  
  **Any nc jumpers or positions marked * must not be 
  jumpered as these are outputs**


* **J6** CPU test pins

  [Located N of cpu sockets]

  Various marked CPU test pins, these are handy for 
  connecting a Hoglet decoder to a 65(c)02 direct
  [GitHub](https://github.com/hoglet67/6502Decoder)


~~* **J7** Sound pull up down~~
~~ ~~
~~  [located W to E above sound output]~~
~~  ~~
~~  This header should be left unlinked, it may be set to ~~
~~  either middle to E or middle to W if sound quality~~
~~  problems are encountered.~~

* **J7** CPU voltage
  [located W to E above sound output]~~

  This header allows the cpu voltage to be set to either
  5V or 3.3V. It is necessary to run the W65C02 and 
  65816 cpus at 3.3V as their clock (and some other) 
  inputs run at CMOS levels but the FPGA only outputs
  LVTTL levels which leads to unstable operation.

  W - 5V    [6502, 6x09]
  W - 3.3V  [65C02, 65816]


===============================================================================
3. Memory Map Overview
===============================================================================

    +--------------------------+-----------------------+ 
    |  logical/physical addr   | hardware item         |
    +--------------------------+-----------------------+
    |  $00 0000 - $07 FFFF     | SRAM 0                |
    +--------------------------+-----------------------+
    |  $08 0000 - $0F FFFF     | SRAM 1 (battery back) |
    +--------------------------+-----------------------+
    |  $10 0000 - $17 FFFF     | EEPROM                |
    +--------------------------+-----------------------+
    |  $18 0000 - $1F FFFF     | - blank -             |
    +--------------------------+-----------------------+
    | ...                                              |
    | above  ..... repeats until system ...............|
    | ...                                              |
    +--------------------------+-----------------------+
    |  "system" (except for SWRAM/SWMOS)               |
    | $FF 0000 - $FF 7FFF      | SYS RAM               |
    | $FF 8000 - $FF BFFF      | SYS ROM / SWRAM       |
    | $FF C000 - $FF FBFF      | SYS MOS / SWMOS       |
    | $FF FC00 - $FF FEFF      | SYS HARDWARE          |
    | $FF FF00 - $FF FFFF      | SYS MOS / SWMOS       |
    +--------------------------------------------------+

The addresses above are not valid in all situations:
- JIM accesses will just access the memory $00 0000 to
  $1F FFFF 
- CPU directly accesses the "system area only" i.e 
  bank $FF
- BLIT/SOUND/DMAC can access all addresses, i.e. to
  blit to / from SYStem memory address as $FF xxxx

### 3.1 Sideways RAM/ROM mappings to physical memory

Sideways ROM/RAM Map to following:

```
    0   BB RAM      $ 0E 0000 - 0E 3FFF
    1   EEPROM      $ 16 0000 - 16 3FFF
    2   BB RAM      $ 0E 4000 - 0E 7FFF
    3   EEPROM      $ 16 4000 - 16 7FFF
    4   SYS IC 52
    5   SYS IC 88
    6   SYS IC 100
    7   SYS IC 101
    8   BB RAM      $ 0F 0000 - 0F 3FFF NB: also used as the SW MOS/FLEX bank
    9   EEPROM      $ 17 0000 - 17 3FFF 
    A   BB RAM      $ 0F 4000 - 0F 7FFF
    B   EEPROM      $ 17 4000 - 17 7FFF
    C   BB RAM      $ 0F 8000 - 0F BFFF
    D   EEPROM      $ 17 8000 - 17 BFFF
    E   BB RAM      $ 0F C000 - 0F FFFF
    F   EEPROM      $ 17 C000 - 17 FFFF NB: also used as the SW MOS debug bank
                                        This slot will normally contain a copy
                                        of the bltutils rom
```

Old mapping:

    0   EEPROM      $ 16 0000 - 16 3FFF
    1   BB RAM      $ 0E 0000 - 0E 3FFF
    2   EEPROM      $ 16 4000 - 16 7FFF
    3   BB RAM      $ 0E 4000 - 0E 7FFF
    4   SYS IC 52
    5   SYS IC 88
    6   SYS IC 100
    7   SYS IC 101
    8   EEPROM      $ 17 0000 - 17 3FFF NB: also used as the SW MOS debug bank
    9   BB RAM      $ 0F 0000 - 0F 3FFF NB: also used as the SW MOS/FLEX bank
    A   EEPROM      $ 17 4000 - 17 7FFF
    B   BB RAM      $ 0F 4000 - 0F 7FFF
    C   EEPROM      $ 17 8000 - 17 BFFF
    D   BB RAM      $ 0F 8000 - 0F BFFF
    E   EEPROM      $ 17 C000 - 17 FFFF
    F   BB RAM      $ 0F C000 - 0F FFFF

Sideways RAM at $FF 8000 - $FF BFFF can be mapped into local chip RAM/EEPROM
by using the following registers:

**SWROM reg**

  **$FE30** this is a shadow copy of the BBC micro's own ROM select register, if 
  the value is in the range 4-7 then accesses to the memory at $FF 8000 to 
  $FF BFFF will access the SYS ROM sockets. Otherwise even numbered values 
  will map to chip SRAM (in the  battery backed portion) and odd numbered values
  will map to the EEPROM

[NOTE: (if the memory inhibit jumper is fitted then the BBC micro ROM sockets
  will be mapped as normal)]


### 3.2 Onboard Memory

The onboard SRAM and Flash EEPROM can be addressed by the CPU either through 
the JIM interface or as sideways ROM/RAM.

#### 3.3 The JIM interace

The onboard memory $00 0000 to $1F 0000 can be accessed as a set of 8192 256
byte pages of memory mapped into a single memory window at $FF FD00 and 
accessible to the CPU (not DMAC/BLIT/SOUND via JIM)

To enable the local JIM interface the SWMOS control register bit 1 should be 
set (See SWMOS reg below). If this bit is not set the paging registers and JIM
are passed on to the 1MHz bus as usual to allow memory mapped hardware to be
accessed.

**JIM Paging registers**

* **$FCFE** JIM paging register (hi)
* **$FCFF** JIM paging register (lo)

When local JIM is enabled (using the SWMOS register above) these registers 
become active. Writing values to these registers will set the page that is 
mapped in to appear in the JIM page at $FF FD00

Data can then be read/written to RAM via JIM.

Data can also be written to the FlashEEPROM. However valid programming 
sequences must be sent before a write is attempted. See the source code for the
UTILS ROM for an example.


### 3.4 Sideways MOS

Additionally the memory area at $FF C000 to $FF FBFF and $FF FF00 to $FF FFFF
can be mapped to a sideways RAM bank (#9 or #8) with the use of the SWMOS reg

SWMOS reg
---------

[Note: this is likely to change in the near future to make it more compatible
with Master/BBC B+]

$FE31 - this register controls whether the MOS ROM is in a system slot or 
alternatively mapped into sideways ram slot #9. Also this register enables or
disables the on-board JIM registers.

Bit     Purpose
===     =======
0  #    SWMOS_EN
        When set to 1 the MOS will execute from sideways bank #9 this bit is
        not normally reset when the break key is pressed a full reset 
		    is needed to return to executing from the SYS socket should the #9 
		    socket become corrupted*
1  #    BLIT_JIM_EN
        When set to 1 the local JIM paging registers (below) will become active
        and cpu accesses to the page $FF FD00 will be intercepted to read chip
        memory
2  #    SWMOS_DEBUG
        65x02 only
        When set to 1 bit 0 (above) will map the MOS to sideways bank #F
        this is used on the 65x02 modes along with the debug / NMI button
        Additional memory areas will be swapped as outlined DEBUG MEMORY MAP
        below*
3       SWMOS_DEBUG_EN
        65x02 only
        Debug enable, like bit 0 this requires a slow reset to clear. Once
        set the BUGBTN header pin as desribed will cause a "debug nmi" (see
        below)
4       FLEX shadow - when this bit is set the CPU sees memory at 0000-7FFF 
        taken from the chip RAM at $0D 8000 to $0D FFFF
5       '0'
6       SWMOS_DEBUG_5C
        65x02 only
        read only
        DEBUG becoming active was caused by a $5C NOP instruction being executed
7       SWMOS_DEBUG_ACT
        65x02 only
        read only
        DEBUG active, the debug memory mapping is in force*

Note*: Holding BREAK/nRESET low (or powering down the main board with the FPGA 
powered) for approx 3 seconds will also clear bit 0,7

#### 3.5.1 DEBUG MEMORY MAP [65x02 only]

When the debug memory map is enabled (bit 0 and 2 of $FE31 SMOS are both set)
the MOS area of memory i.e. C000-FBFF and FF00 to FFFF will be mapped as follows:
C000-CFFF   = physical memory 0D F000 to 0D FFFF this can be used by the 
            debugger as scratch memory, buffer space, etc
D000-FBFF 
and
FF00-FFFF   = the top portion of SWROM #F (i.e. $ 17 D000 - 17 FFFF)


DEBUG NMI [65x02 only]
======================
A debug switch can be fitted to ground the bugbtn header pin input, which will 
cause an NMI [ on the 6809 the CPU nNMI input is dedicated to this pin]
      
A falling edge on this input will (after 16 8MHz cycles) perform the following:
  - save existing bits 0, 1 and 2 in FE31, these will be readable from FE32 
  - set bits 0 and 2 in the FE31 SWMOS register to
    map in the debug memory and ROM #8 into the MOS 
    workspace
  - cause an NMI 

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
  - set bits 0 and 2 in the FE31 SWMOS register to map in the debug memory and 
    ROM #8 into the MOS workspace
  - cause and hold and nmi (as debug button)
This will effectively cause a BRK instruction to appear to have been executed
3 bytes after the 5C instruction (the 5C nop takes 2 bytes as arguments).

This is used by the NoICE debugger as its break point instruction, leaving the 
BRK instruction to be used as the regular MOS error mechanism.

Bit 3 of SWMOS must be set to enable this behaviour


SWMOS debug save (65x02 only)
-----------------------------
$FE32
(READ)
0  #    SAVED_SWMOS_EN
        BIT 0 of SWMOS when the debug NMI/5C was executed
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
  rti                 ; at this point the old SWMOS state will be restored from
                      ; the contents of $FE32

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


### 3.2 Flex Shadow RAM (6809)

When flexmode is set the whole 32k 0000-7FFF is taken from chip RAM at
$ 0D 8000 - 0D FFFF - this has to be manually paged out to get screen writes
The memory at 8000-BFFF is mapped as usual using SWROM
The memory at C000-FFFF is mapped as usual using SWMOS



6809 peculiarities
==================

A11 adress remapping
--------------------

The 6809 processor has more hardware vectors than the 6502 processor and this
means that these would overlap with the familiar OSXXX system calls of the 
Acorn MOS.

To simplify software porting and help maintain compatibility in BASIC programs
the hardware vectors are remapped from FFF* to F7F* by setting A11 low during
vector fetches.

NMI to FIRQ
-----------

The NMI response of the 6809 is to stack all registers before proceeding to the
interrupt vector. This may be too slow for some hardware devices and so the NMI
line is remapped to the FIRQ line on the 6809 processor. The MOS is being 
updated to support this for disc and Econet accesses.

===============================================================================
DMAC - the dma controller
===============================================================================

BEEB Base address: $FF FC90 
[subject to change - may be relocated to sheila]

The DMAC or DMA controller is a simple device for reading/writing bytes to/from
hardware registers or devices.

There are four DMA channels, however currently only one can be used at a time.

For user applications it is recommended only to use channel 0 and to always
set FC9F=0 before any operation. 

The source and destination registers are programmed with starting addresses,
a count register is set to indicate the number of bytes to transfer the control 
register set to increment or decrement the source/destination after each
cycle. 

  Address       Purpose
  -------       -------
  BASE + 0      Control register - this should be set last, setting this register
                with bit 7 set will start the transfer.
  BASE + 1/2/3  Source address (big endian 24 bit address)
  BASE + 4/5/6  Destination address (big endian 24 bit address)
  BASE + 7/8    Count - 1
  BASE + 9      Data (may be read after a transfer) [deprecated]
                For 16 bit transfers returns the MSB
  BASE + A      Control 2 register - this should be set before the main control
                register
  BASE + B      Pause value
  ...
  BASE + F      Channel select, setting this register maps in the lower 0-9 
                registers for the selected channel. When setting this register
                unused bits (2-7) should be 0, when reading this register
                future firmwares may set other bits.

  Control register bits
  ---------------------

  7   -   ACT : (set this bit to 1 to initiate/test for completion)
  6   -   n/a : always set as 0
  5   -   EXT : enable extended functions in control register 2
  4   -   HLT : If set the CPU is halted whilst the transfer proceeds
  3   \
  2   _\  SS  : source step (up/down/none)
  1   \
  0   _\  DS  : Dest step (up/down/none)

  Control2 register bits
  ----------------------

  [ bits marked * are only obeyed if the EXT bit is set in CTL, this to allow
    fewer writes to set up for simple memory moves]

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


[Note: The current firmware does not support polled or background transfers. 
All transfers should have the HLT flag set]

  Step values
  -----------
  "00" - none : The address will not be incremented (to write repeatedly to a
                single register)
  "01" -   up : The address will be incremented
  "10" - down : The address will be decremented
  "11" - resv : Reserved - do not use

 
For example to transfer the entire screen memory to the chip ram at $00 0000
reversing all bytes:
  
  
  clr   $FC9F     ; set channel 0  
  lda   #$FF
  sta   $FC91     ; src system bank
  ldx   #$3000    ; screen base
  stx   $FC92     ; src addr
  clr   $FC94     ; dest bank = 0
  ldx   #$4FFF
  stx   $FC95     ; dest addr
  stx   $FC97     ; count - 1
  lda   #$96      ; Act, HLT, SS=up, DS=down

This should transfer the whole 20K screen to chip ram in just over 10ms i.e.
2 system cycles per byte.

 Word Size values
  ----------------

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

  Note: count is number of 16 bit words in non-byte cases
  Note: when transfering 16 bits and moving dowwards the first bytes will be
  at start_addr+0/1 then start_addr is decremented by 2

Chip ram to chip ram transfers can operate faster (currently at 4MHz so 2MB/s).

If sound samples are playing then these will steal cycles from the DMAC and 
will slow down the transfer accordingly. 

It is intended that in future these may be improved to run at 8MHz except where
accessing SYStem resources.

===============================================================================
the SOUND chip
===============================================================================

BEEB Base address: $FF FC80
[subject to change - may be relocated to sheila]

The sound processor appears as a 4 channel PCM + mixer device, loosely modelled
on the Amiga's Paula chip.

Each channel can be set to output a static value by setting its data register
(complex generated sounds can be generated by setting this register in a tight
loop) or can be programmed to play a sound sample from memory using DMA 
techniques

  Address       Purpose
  -------       -------
  BASE + 0      Sound data read/write current sample
  BASE + 1/2/3  Source base address (big endian 24 bit address)
  BASE + 4/5    Sample "period" - see below
  BASE + 6/7    Length - 1
  BASE + 8      Status/Control
  BASE + 9      Volume 
  BASE + 10/11  Repeat offset
  BASE + 12     Peak 
  BASE + F      Channel select, setting this register maps in the lower 0-9 
                registers for the selected channel. When setting this register
                unused bits (2-7) should be 0, when reading this register
                future firmwares may set other bits.

  Control register bits
  ---------------------

  7   -   ACT : (set this bit to 1 to initiate/test for completion)
  6   -   n/a
  5   -   n/a
  4   -   n/a
  3   -   n/a
  2   -   n/a
  1   -   n/a
  0   -   RPT  : Repeat

  [All n/a bits should be set to 0 on write, expect non-zero on read back]

  ACT, setting this bit will initiate playing a sample using DMA
  RPT, setting this bit will cause the sample to repeat, the sample will
       be repeated beginning at the offset in BASE+10/11

The clock for playing samples is a nominal 3,546,895Hz (as on a PAL Amiga). 
The "period" describes the number of PAL clocks that should pass between each
sample being loaded (via DMA)

For example, this program sets up a sample of 32 bytes length in chip RAM
and sets channel 0 to repeatedly play the sound

    5 REM BLIT SOUND
   10 snd%=&FC80
   20 SL%=32:SR%=1000:SP%=3546895/(SR%*SL%):REM calculate period
   30 BUF%=&FD00:?&FE31=(?&FE31)OR2:?&FCFE=0:?&FCFF=0:REM enable JIM, set addr=0
   40 FORI%=0TOSL%-1:BUF%?I%=127*SIN(2*PI*I%/SL%):NEXT
   50 snd%?&F=0:snd%?&E=255:REM cha=0,master vol=255
   60 snd%?&1=0:snd%?&2=0:snd%?&3=0:REM sample address
   70 snd%?&4=SP%DIV256:snd%?&5=SP%:REM sound "period"
   80 snd%?&6=(SL%-1)/256:snd%?&7=SL%-1:REM sample len-1
   90 snd%?&9=255:REM channel vol max
  100 snd%?&A=0:snd%?&B=0:REM repeat from start of sample
  100 snd%?&8=&81:REM play, repeat
  ...
Line 20   : Set parameters and calulate the note "period" i.e. 1KHz with 32 
            samples divided into the clock, i.e. 110
            [Note this is quite a fast sample rate > 32KHz a shorter sample 
            length is recommended to reduce system overhead]
Line 30   : Enable JIM and point the paging registers at the base of chip RAM
Line 40   : Write a 32 byte sample to JIM
Line 50   : Set channel number and master volume
Line 60   : Set up sample base address at $00 0000
Line 70   : Set sound "period" calculated above
Line 80   : Set length of sample (subtract 1)
Line 90   : Set Channel volume to max
Line 100  : Set repeat offset to 0
Line 110  : Set ACT and RPT, play sound indefinitely

To stop a sound playing it is a simple of matter of selecting the channel and
setting the control register to 0

  200 REM stop sound
  210 snd%?&F=0:REM select channel 0
  100 snd%?&8=0:REM stop





Known issues
------------
 - the master volume control does not work, it is recommended to set it to 255
 - there is no provision for interrupt drive sound, this may be included in
   future


===============================================================================
the BLITTER chip
===============================================================================




Dataflow overview
-----------------

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




Line Drawing Mode
=================

SPRITE MODE                             LINE MODE
-----------------------------------------------------------
DATA_B                                  PXFORECOL     8
DATA_A                                  PXMASK        8
WIDHT|HEIGHT                            CMAJOR        10
ADDR_A                                  ERRACC        15  
ADDR_B                                  DMAJOR        15
STRIDE_A                                DMINOR        15
BLTCON:MODE(0) 1-UP,0-RIGHT             DIRMAJ        1
BLTCON:MODE(1) 1-LEFT/UP,0-RIGHT/DN     DIRMIN        1
FIRST_A                                 PXMASK_NEXT   8   ; used internally
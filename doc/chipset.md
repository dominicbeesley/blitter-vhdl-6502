
This document provides provisional information on the operation of the 
enhanced chipset functions on the Blitter boards. Not all builds of
the Blitter will include all these facilities. The Configuration 
registers [see API](API.md) should be checked for capabilities.

# Chipset trips and traps

Note: all chipset addresses registers are big-endian unless specified otherwise
Note: all chipset addresses registers work with *physical adddresses* care should be taken
      when copy from/to bank FF as this might no be the same as the logical bank FF or 
      what the CPU sees!


# The DMAC

Physical Base address: **FE FC90**

The DMAC or DMA controller is a simple device for reading/writing bytes 
from/to hardware registers or memory at high speed or tied to certain
events.

There are four DMA channels.

For user applications it is recommended only to use channel 0 and to always
set FE FC9F=0 before any operation. 

The source and destination registers are programmed with starting addresses,
a count register is set to indicate the number of bytes to transfer and the
control register set to increment or decrement the source/destination after 
each cycle. 

| Offset   | Name             
|----------|------------------
|  0       | Control          
|  1..3    | Source physical address
|  4..6    | Destination physical address
|  7..8    | Count - 1
|  9       | Data 
|  A       | Control 2 register - this should be set before the main control register
|  B       | Pause value
|  C..E    | - reserved -
|  +F      | Channel select, setting this register maps in the lower 0-9  registers for the selected channel. When setting this register unused bits (2-7) should be 0, when reading this register future firmwares may set other bits.

## DMAC Control register

Offset 0

This register is usually set last as setting bit 7 will initiate the currently
defined operation

| bit  | name | Notes
|------|------|------------------------------------------------------
| 7    | ACT  | (set this bit to 1 to initiate/test for completion)
| 6    | n/a  | always set as 0
| 5    | EXT  | enable extended functions in control register 2
| 4    | HLT  | If set the CPU is halted whilst the transfer proceeds
| 3..2 | SS   | source step (up/down/none)
| 1..0 | DS   | Dest step (up/down/none)


**Step values**


| bits | name | action
|------|------|----------------------------------------------------------------
| 00   | none | The address will not be changed
| 01   | up   | The address will be incremented
| 10   | down | The address will be decremented
| 11   | nop  | The address is not incremented, nor is the read/write performed

 * **none** the address is not be incremented but the read/write is
   performed - useful for transferring to/from a single hardware register such
   as a disk controller
 * **up** the address is incremented after the transfer
 * **down** the address is decremented after the transfer
 * **nop** the read/write is not performed and the address is not changed, this
   can be used to do a quick memory fill by setting source to nop and dest to
   up/down


## DMAC count register

This register should be set to the number of *transfers* (bytes or words) to perform minus 1. 
i.e. setting this register to 0 will copy 65536 items

## DMAC data register

Offset 9

Useful for memory fills note writing to the data register writes both upper 
and lower bytes so 16 bit fills are possible so long as ls and ms bytes
are the same.

## DMAC control register 2

Offset A

[ bits marked * are only obeyed if the EXT bit is set in CTL, this to allow
  fewer writes to set up for simple memory moves]

| bits | name  | Name
|------|-------|--------------------------------------------------
| 7    | IF    | Interrupt flag (read only)
| 6    | -     |
| 5    | -     |
| 4    | -     |
| 3..2 | SIZE  | word/step size
| 1    | IE    | Interrupt enable, when set the IF flag (set on completion) causes an interrupt
| 0    | PAUSE | : the value in pause val register will be used to insert that
                many 8MHz wait states after each source read. This is useful
                to add a small delay for slower hardware where a normal cpu
                based delay would be too big a delay

 * **IF** set when a transfer has completed, any write to control or control2
   clears the interrupt flag
 * **SIZE** the data size and endianness - see below
 * **IE** if set then an IRQ will be generated when IF is set.
 * **PAUSE** when set this indicates that a pause should be inserted between transfers (see 
   Pauseval register below)


**Word Size values**

| bits | name        | action
|------|-------------|----------------------------------------------------------------
| 00   | byte        | a byte will be read from source then written to dest for each of count cycles
| 01   | word        | two bytes will be read from source, source + 1 then written to destination, destination + 1 - useful for reading from/writing to a 16 bit register. 
| 10   | wordswapdest| two bytes will be read from source, source+1 then written to dest+1, dest i.e. swapping byte order at dest
| 11   | wordswapsrc | two bytes will be read from source+1, source then written to dest, dest+1 i.e. swapping byte order at src


Note: count is number of 16 bit words in non-byte cases
Note: when transfering 16 bits and moving dowwards the first word will be at start_addr+0/1 then start_addr is decremented by 2

## DMAC Pause 

It is possible to insert a pause between transfers by setting this register
and the PAUSE bit in the Control2 register. 

The pause value should be in 8ths of a microsecond. The DMAC controller may however be
interrupted by other higher priority devices (Paula, Aeris) so this value is just a 
minimum pause

[Note: this currently doesn't work properly and the pause is in 128ths of a microsecond]
 

## Example DMAC code

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


Chip ram to chip ram transfers can operate much faster (depends on type of
memory).

If sound samples are playing or the Aeris is in operation then these may steal 
cycles from the DMAC and will slow down the transfer accordingly. 



# The BLITTER
-------------

A Blitter is a device for quickly transferring and manipulating bitmap 
graphics.

The Blitter described here is based closely on the Amiga Original Chipset
Blitter. Before reading the following descriptions it is strongly recommended
that you become familiar with the [Blitter Section of the Amiga Developer Docs](https://amigadev.elowar.com/read/ADCD_2.1/Hardware_Manual_guide/node0118.html).

The Blitter operates in a very similar fashion to the Amiga Blitter but there
are some differences:

## Caveats and warnings

This is preliminary documentation and the Blitter registers are subject to
change. It is likely that future versions of the firmware may change the
register definitions.

In particular feedback would be welcomed on the ordering and adjacency of the
registers for ease of updating.

Likely changes:
 - merge ADDR C/D registers - there is little point in having both
 - add a data C register to allow fast VDU 4 text plotting using the blitter

With changes likely it is recommended that developers write code in such
a way that it will be easy to change the register layout with the minimum of
upheaval.


## Main differences

### Planar vs Packed

The Amiga video memory is arranged as a number of bit-planes where each pixel
is represented by 1 bit in each plane. Several planes can be used together to
give multiple colours. On the BBC Micro colours are represented by packing 
several pixels into each byte of memory. It is assumed that the reader is 
familiar with the layout of pixel data with in a byte in each BBC screen mode.
The Blitter has facilities, not present on the Amiga, for "exploding" the mask
data such that 1 bit per pixel masks can be used with 1,2 or 4 bits per pixel 
bitmap data.

### Linear vs 6845

The Amiga's bit-planes are linear and are read left to right, top to bottom
with increasing address. The BBC Micro uses a more convoluted memory scheme
imposed by the MC6845 CRTC. The Blitter can be configured to plot either in
a linear fashion or to generate addresses for the C and D channels that 
proceed in a left to right, top to bottom manner whilst catering for the 
8 byte character cells used on the BBC Micro. Not source bitmaps and masks
are always stored in a linear layout.

### Extra E channel

The Blitter contains an extra E channel which can be configured to save the 
previous contents of the screen or destination bitmap as it is read in via 
the C channel. This can be used to plot then un-plot BOBs

### Collision detection

A feature for collision detection has been added which detects any non-zero
data destined for channel D (even when channel D is not enabled). This is an
experimental feature, its main use being to detect overlap between two 
shifted bit masks.

### Temporal interleaving

On the Amiga there is a strict ordering of reads/writes to/from each channel
and these may be interleaved as the Amiga Blitter is pipelined. The Blitter
described here in general proceeds in an A-C-B-D or A-C-B-E-D manner, though
the A channel will be only read as it is needed i.e. in a 4 bits per pixel 
mode it will only be accessed for every 4th cycle as channel A data are
always 1bpp.


## Dataflow overview

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

In general data flows as on the Amiga, masks are read from channel A, bitmap
data are read from channel B, existing screen/destination bitmap data from
channel C and combined destination data written back on channel D. The extra
channel E can be configured to save channel C data as it is read.


## Registers

Base Address : $FE FC60, $FE FCA0

The Blitter is accessed either using a 24 bit address capable CPU (i.e. 65816) 
or by using the JIM paging interface.

NOTE: all addresses are in Big-Endian form. i.e. the most-significant byte first

### FE FC60 - BLITCON

The BLITCON register is used to start the Blitter's operation and is written
twice, the first time with the top-bit clear is used to configure which of the
5 channels will participate in the action. And the second write with the top
bit set will start the Blit action and configure the bit-per-pixel mode and the
collision, wrap and line mode settings. (Line mode is detailed further on in this
document).

#### Writing BLITCON

For the 1st write with top bit clear:

| Bits  | description
|-------|----------------------------------------------------
| 7     | 0 - to configure channels / line axes
| 6     | unused, set to 0
| 5     | unused, set to 0      line mode CCW
| 4     | Use channel E
| 3     | Use channel D
| 2     | Use channel C
| 1     | Use channel B
| 0     | Use channel A

For the 2nd write (and reads back)

| Bits  | description
|-------|----------------------------------------------------
| 7     | 1 - start blit
| 6     | Cell mode - CRTC character cell addressing on channels C, D
| 5..4  | Bits per pixel (see below)
| 3     | Line mode (set to 0 for Blit)
| 2     | Collision set to 0, will get set to 1 for non-zero channel D data
| 1     | Wrap - when set the extended registers for MIN/MAX addresses will be applied to channels C,D
| 0     | unused - set to 0 (IRQ?)

Bits per pixel

| 5..4  | Mode
|-------|----------------------------
| 00    | 1 bpp - 2 colour 
| 01    | 2 bpp - 4 colour
| 10    | 4 bpp - 16 colour
| 11    | 8 bpp - 256 colour (future)

The BPP setting is used to "explode" the data as they are read from the A 
register. This allows masks to be always stored in 1bpp mode.

#### Reading BLITCON

Once the Blit has started the cpu should poll for the blit being finished by 
reading back BLITCON and checking bit 7


### FE FC61 - FUNCGEN

The function generator controls how the data from channels A, B and C are 
combined before being written to channel D. 

The Blitter's FUNCGEN works on channels in the same way as the Amiga except 
mask data are "exploded" i.e. each bit is repeated BPP times.

The function generator is described in detail in the [Amiga Reference Manual](https://amigadev.elowar.com/read/ADCD_2.1/Hardware_Manual_guide/node011C.html). The [Venn Diagram](https://amigadev.elowar.com/read/ADCD_2.1/Hardware_Manual_guide/node011E.html) description is helpful.

### FE FC62 - WIDTH

Width in bytes of the sprite minus 1

### FE FC63 - HEIGHT

Height in pixels of the sprite minus 1

### FE FC64 - SHIFT

The Blitter can shift the data read into the A and B registers to the right
by a number of bits to allow sprites to be plotted at any pixel location. 

For non-zero shifts the sprite's width should be set to 1 byte wider and the
edges masked off with the MASK FIRST and MASK LAST registers.

There are two shifts that are specified one for the A register (which is always
1 bpp) and another for the B register which may be 1,2,4 or 8 bpp.

Bits 2..0 specify the A channel shift
Bits 6..4 specify the B channel shift

### FE FC65 - MASK FIRST

This value is anded with the shifted channel A data on the first byte read in
each line is used to mask out unwanted left-hand bits. If not needed set to
$FF

### FE FC66 - MASK 

This value is anded with the shifted channel A data on the last byte read in
each line is used to mask out unwanted left-hand bits. If not needed set to
$FF

### FE FC67 - DATA A 

If the EXEC A flag is not set this register can be set to apply a mask pattern
to the plotted bitmap, otherwise this register will be updated by the Blitter
as it reads the mask from memory

### FE FC68..A - ADDR A

The Big-Endian start address of the mask data

### FE FC6B - DATA B 

If the EXEC B flag is not set this register can be set to plot a solid colour
through the mask

### FE FC6C..E - ADDR B

The Big-Endian start address of the channel B bitmap data

### FE FC6F..71 - ADDR C

The Big-Endian start address of the channel C bitmap data

### FE FC72..74 - ADDR D

The Big-Endian start address of the channel D bitmap data

### FE FC75..77 - ADDR E

The Big-Endian start address of the channel E bitmap data

### FE FC78..9 STRIDE A

The "stride" of the bitmap is the number of mask bytes per line of the source
data

### FE FC7A..B STRIDE B

The "stride" of the bitmap is the number of bitmap data bytes per line of the
source data

### FE FC7C..D STRIDE C

The "stride" of the bitmap is the number of bytes in a line of bitmap data
on the screen

In cell mode this stride is only applied at the end of a character row and 
should be set to the character row width in bytes.

### FE FC7E..F STRIDE D

The "stride" of the bitmap is the number of bytes in a line of bitmap data
on the screen

In cell mode this stride is only applied at the end of a character row and 
should be set to the character row width in bytes.

### FE FCA0..2 ADDR C/D MIN

In WRAP mode, if the C or D addresses are incremented above the MAX address
then they will wrap to this MIN address

### FE FCA3..5 ADDR C/D MAX

In WRAP mode, if the C or D addresses are incremented above this MAX address
then they will wrap to the MIN address



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



# The Aeris

The Aeris chipset performs a function analogous to the copper chip in the Amiga
Copper chip but with its functionality tweaked to better suit the BBC Micro and
its 8-bit nature.


Horizontal ticks are 1/32nd of a PAL line i.e. 500kHz measured from the start of HS

Vertical ticks are raster lines after VS


## Aeris Registers

FE FCB0 +

      0     Control Register
              bit 7 - act, when set will start program at next vsync
              bit 6 - interrupt, may be used to cause an interrupt
              bit 3..0 - may be used to pass data from Aeris program to CPU

      1..3  Base Address, 24 bit memory address of program.



The chip is idle until the Control Register's top bit is set at which point it 
will wait for the next VSYNC and then start executing the program. Subsequent 
VSYNCS will restart the program immediately.

A program consists of simple instructions as outlined below. These can be stored
either in SYStem memory in which case the program will execute at roughly 1MHz
when sharing cycles with the CPU or 2MHz otherwise; in chip RAM it will much 
faster [TODO: table of speeds]

During blits there may be further slow downs due to cycle sharing, the proposed
SYNC/UNSYNC instructions might be used to mitigate this


## Operations
==========

[Items marked * are not yet implemented]


WAIT
----

Waits for a specific scan line and or horizontal position

    opcode      arg0        arg1        arg2   
    0000 mmmm   mmmm mnnn   nnVV VVVV   VVVH HHHH


    m mmmm mmmm - mask for raster line
    V VVVV VVVV - raster line
    n nnnn      - mask for line counter
    H HHHH      - line counter

SKIP
----

skip next instruction if masked counters are >= arguments

    opcode      arg0        arg1        arg2
    0001 mmmm   mmmm mnnn   nnVV VVVV   VVVH HHHH

    m mmmm mmmm - mask for raster line
    V VVVV VVVV - raster line
    n nnnn      - mask for line counter
    H HHHH      - line counter

MOVE16I
-------

move to hardware register

    opcode      arg0        arg1        arg2
    0010 bbbb   hhhh hhhh   DDDD DDDD   DDDD DDDD

move data to "hardware register" h in bank b (see below), two bytes are moved
in order to _incrementing_ hardware register. Suitable i.e. for writes to 
CRTC FE00


MOVE16
------

move to hardware register

    opcode      arg0        arg1        arg2
    0011 bbbb   hhhh hhhh   DDDD DDDD   DDDD DDDD

move data to "hardware register" h in bank b (see below), two bytes are moved
in order to _the same_ hardware register. Suitable i.e. for writes to NULA FE23

MOVE
----

move to hardware register

    opcode      arg1        arg2
    0100 bbbb   hhhh hhhh   DDDD DDDD

move data to "hardware register" h in bank b (see below)

BRANCH
------

    opcode      arg1        arg2
    0101 0---   dddd dddd   dddd dddd

branch by 16 bit signed displacement. Displacement is added to the PC after it
has been incremented i.e. when pointing at next instruction.

BRANCH link 
-----------

    opcode      arg1        arg2
    0101 1ppp   dddd dddd   dddd dddd

branch by 16 bit signed displacement. Displacement is added to the PC after it
has been incremented i.e. when pointing at next instruction. The register p is 
loaded with the current PC before it changes and can be used as a return address
from a subroutine


MOVEP
-----

Move address to pointer register.

    opcode      arg1        arg2
    0111 -ppp   dddd dddd   dddd dddd

Sets the pointer register ppp to the address given by adding the signed
displacement to the PC. Displacement is added to the PC after it
has been incremented i.e. when pointing at next instruction.

MOVEC
-----

Move number to counter register

    opcode      arg2
    1000 -ccc   nnnn nnnn

The 8 bit value following the opcode is moved to the counter register ccc.

PLAY
----

Execute move commands from pointer.

    opcode      arg2
    1001 0ppp   nnnn nnn

nnnn nnnn 16 bit words at pointer register ppp are executed as if they were
move instructions. The pointer is incremented after each item is executed.

PLAY16
----

Execute move16 commands from pointer.

    opcode      arg2
    1001 1ppp   nnnn nnnn

nnnn nnnn 16 bit words at pointer register ppp are executed as if they were
move instructions. The pointer is incremented after each item is executed.


ADDC
----

Add to counter register

    opcode      arg2
    1010 0ccc   ssss ssss

The signed displacement is added to the counter register.

ADDP
----

Add to pointer register

    opcode      arg2
    1010 1ppp   ssss ssss

The signed displacement is added to the pointer register.

MOVECC
------

Move counter to counter

    opcode      arg2
    1011 0--0   -aaa -bbb 

move counter b to counter a

MOVEPP
------

Move pointer to pointer

    opcode      arg2
    1011 0--0   -aaa -bbb 

move pointer b to pointer a


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

# The i2c controller

The i2c controller is mainly used to control the on-board eeprom and/or rtc where fitted
on the Mk.3 board there is also a header to which other i2c peripherals may be attached.

## registers

Physical Base address: **FE FC70**


STATUS/CONTROL register is at offset + $0

Address  | Direction    | Bit | Name | Description
---------+--------------+-----+-------------------------------------------------------------------
STAT=0   |  Read        |     |      | Status register:
         |              |  7  | BUSY | flag, when set a shift is in operation
         |              |  6  | ACK  | 0 if previous operation was ack'd either by controller or peripheral
CTL=0    |  Write       |  7  | BUSY | 1 start a new operation or abort a current op\*
         |              |  6  | ACK  | if 0 and operation is a read acknowledge it afterwards
         |              |  2  | STOP | send a stop condition after this operation
         |              |  1  | START| send a start condition before this operation
         |              |  0  | RnW  | 1 read a byte, 0 write
---------+--------------+-----+------+------------------------------------------------------------
DAT=1    | Read         |     |      | Read received data
         | Write        |     |      | Write data latch 

\* Writing 0 to BUSY during an operation a stop condition will be generated as soon as the clock is released by the peripheral, any pending operation will be terminated


## example: probe address exists
```
    DAT = <addr> << 1 & "1"
    STAT = "10000110"                            ; BUSY+START+STOP+WRITE
    WHILE STAT(BUSY) = "0":WEND
    RETURN (STAT(ACK) = "0")
```

## example: write 1,2,3 to addres 0x23
```
    DAT = x"46"
    CTL = "10000010"
   
    WHILE STAT(BUSY) = "0":WEND
   
    IF STAT(ACK) = "1" RETURN
   
    DAT = x"01"
    STAT = "10000000"
    WHILE STAT(BUSY) = "0":WEND
   
    IF STAT(ACK) = "1" RETURN
   
    DAT = x"01"
    STAT = "10000000"
    WHILE STAT(BUSY) = "0":WEND
   
    IF STAT(ACK) = "1" RETURN
   
    DAT = x"03"
    STAT = "10000100"
    WHILE STAT(BUSY) = "0":WEND
```
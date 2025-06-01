# 0. Introduction
-----------------


This document describes the firmware for the mk.3 rev 3 board. For earlier
boards see:
        -       [Mk.1 overview](hardware-overview.md)
        -       [Mk.2 overview](hardware-overview-mk2.md)


# 1. BEEB Blitter and CPU card Mk.3 Hardware Overview
-----------------------------------------------------

The Dossytronics CPU development board includes an Intel Max 10 FPGA, 
up to 6MB of main SRAM, up to 1MB of battery backed RAM, 512K of 
FlashEEPROM, a crystal oscillator, HDMI port, SD card slot, optional RTC,
optional configuration EEPROM, and optional cpu plug-in cards for additional
CPU cards i.e. 6502/65c02, 65816, 6809, 6309, Z80, MC68008, MC68000 etc 
processors.

[Schematic](blit-cpu-mk2.pdf)

The board can be configured to plug into any 6502 or 65816 socket but it is 
primarily designed for the BBC micro, Electron or Master CPU socket and is
powered either by the cpu socket or via an auxilliary +5V regulated supply.

Simplified Diagram
---------------------

```
                         +------------+
                         |plug-in CPU |
                         |65x02, 6x09 |
                         |65816, z80  |
                         |68K etc     |
                         +------------+
                              | |      
                              | | CPU bus
        +-----------+    +------------+          +----------------+
        |Fast RAM   |    |FPGA        |          |                |
        |  0..6MB   |    | +--------+ |          |   BBC Micro    |
        |BB RAM     |    | |T65 core| |          |  motherboard   |
        |  0..1MB   |    | +--------+ |          |                |
        +-----------+    | |DMAC    | |          |                |
           | |           | +--------+ |          +--+             |
           | | MEM bus   | |BLIT    | | SYS bus  | s|             |
           | +-----------| +--------+ |----------|Co|             |
           | +-----------| |SOUND   | |----------|Pc|------...    |
           | |           | +--------+ |          |Uk|------...    |
           | |           | |MEM CTL | |          | e| system bus  |
        +-----------+    | +--------+ |          | t|             |
        |           |    | |BUS CTL | |          +--+             |
        | Flash     |    | +--------+ |=====+    |                |
        | EEPROM    |    | |AERIS   | |==+  |    |                |
        | 256K/512K |    | +--------+ |  |  |    |                |
        +-----------+    +------------+  |  |    +----------------+
                              | | i2c    |  |
                         +------------+  |  |
                         | i2c config |  |  +===>HDMI                        
                         | eeprom     |  |
                         +------------+  +======>SDCARD
                         | RTC        |
                         +------------+
                         | Header     |
                         +------------+

```

[This description is based around how the current firmware accesses hardware
you may of course replace the firmware and completely replace the contents
of the FPGA.]
                                                                            
The CPU board contains level shifting buffers to match the 5V signals of the 
SYS and CPU busses to the 3.3V LVTTL levels of the FPGA. 
Some lines are buffered using Texas Instruments 74CB3T series buffers which
allow fast bi-directional operation without steering. These pins are not
suitable for driving CMOS devices directly. Other lines are buffered using
74LVC4245 devices which provide full CMOS drive

The MEM bus operates on 3.3V signals and so is not buffered. 

[The Mk1 board shared the CPU and SYS which made the board less complex and 
used fewer FPGA pins but this precluded having the CPU run in the background
whilst a system to memory blit or DMA transfer happened.]

# 2. Jumpers
------------

This information is provisional as of 29/9/2021

## J11 SYS pin 5
----------------

This jumper selects the connection for the #5 pin on the motherboard
CPU plug. In the North position pin #5 will be connected to the SYS_AUX_o1
pin of the J16 and may be used to provide a Memory Lock signal as provided
by the 65816 and some CMOS 65Cx2 devices. For a motherboard expecting the
G65SC12 the jumper may be fitted South. Under normal circumstances in a
BBC MicroA/B/B+/Electron/Master this jumper should not be fitted.


    +-+
    | |
    |#| 
    | | N - pin5 -> SYS_AUX_o1
    |o| 
    | | 
    |o| S - pin5 -> GND
    | |
    +-+

## J12 SYS pin 1
----------------
This jumper selects the connection for the #1 pin on the motherboard
CPU plug. In the North position pin #1 will be connected to the SYS_AUX_o0
pin of the J16 and may be used to provide a Vector Pull signal as provided
by the 65816 and some CMOS 65Cx2 devices. Under normal circumstances in a
BBC MicroA/B/B+/Electron/Master this jumper should not be South which will
ground pin 1.


    +-+
    | |
    |#| 
    | | N - pin1 -> SYS_AUX_o0
    |o| 
    | | 
    |o| S - pin1 -> GND
    | |
    +-+

## J13 SYS pin 3
----------------
This jumper selects the connection for the #3 pin on the motherboard
CPU plug. In the North position pin #3 will be connected to the internally
generated PHI1 signal for the motherboard this will be expected on the 
BBC A/B and Electron. 

For the Master and Model B+ this jumper should not be fitted

On custom firmwares this may be used to monitor the nABORT signal on 65816
based motherboards by fitting in the South position.


    +-+
    | |
    |#| 
    | | N - pin3 -> PHI1 out
    |o| 
    | | 
    |o| S - pin3 -> PHI1/nABORT in
    | |
    +-+

## J14 SYS pins 35,38
---------------------


This header gives access to pins 35 and 38 from the motherboard and may 
be used in custom firmwares by connecting to spare AUX_io pins.


    +-+
    | |
    |#| pin 38 -> 6502 nSO, 65816 M/X
    | | 
    |o| pin 35 -> G65SC102/G65SC112 OSC, 65816 E
    | |
    +-+


## J16 SYS Aux connector

This header gives a number of spare fpga connections which may be used to
connect various signals from the motherboard, either using the jumpers above
or as flying leads. The "io" pins are bidirectional 5V tolerant LVTTL 
and the "o" signals are 5V CMOS level outputs.

```
                Label       SYS           Firmware
        +---+
        |   |
   GND  |# o|   AUX_o0      J12 pin#1
        |   |
   GND  |o o|   AUX_o1      J11 pin#5
        |   |
   GND  |o o|   AUX_o2 
        |   |
   GND  |o o|   AUX_o3
        |   |
   GND  |o o|   AUX_io0
        |   |
   GND  |o o|   AUX_io1     J13 pin#3
        |   |
   GND  |o o|   AUX_io2
        |   |
   GND  |o o|   AUX_io2
        |   |
   GND  |o o|   AUX_io3
        |   |
   GND  |o o|   AUX_io4                   AERIS Hsync
        |   |
   GND  |o o|   AUX_io5                   AERIS Vsync
        |   |
   GND  |o o|   AUX_io6                   Debug button
        |   |
        +---+
```

If using a firware with the AERIS function enabled it the AUX_io4 and 5 pins 
should be connected with flying leads to pins 39 and 40 respectively of the 
MC6845 CRTC controller to provide synchronisation.

## J32 sound output
-------------------

This connector outputs the low-pass filtered audio. The level is
suitable for connecting to the line-in inputs of an amplifier or 
may be connected directly to the 1MHz bus analogue input via flying
leads (details below).


    +-+
    | |
    |o| Left filtered audio
    | | 
    |o| Right filtered audio
    | | 
    |o| Analogue ground
    | |
    +-+

The analogue ground is usually left floating at the blitter board end
unless LK32 (groundloop) is made (see below). The ground reference for
the filters will usually be provided by the device connected to this
header to avoid ground loops. If you find there is excessive noise or
hum then making LK32 may help.

Flying leads on the BBC Model B may be connected from the Left filtered
output to the top of R172 (near the 1MHz bus connector under the 
keyboard) and the analogue ground connected to the bottom of R171. This
will allow the sound to be played out through the BBC Micro's speaker 
and mixed with the sound from the motherboard.




## J33 sound raw
----------------

This header gives acceess to the unfiltered pwm/pcm sound output. 
In normal operation the J32 header should be used.

    +-+
    | |
    |#| Left raw audio 
    | | 
    |o| Right raw audio
    | | 
    |o| Digital/board ground
    | |
    +-+

## J44 i2c connector
--------------------

This header gives access to the local i2c bus. See documentation for the
i2c firmware. Note this is connected direct to the FPGA and is *NOT* 5V
tolerant, level shifters must be used if 5V devices are to be connected

    +---------+
    | # o o o |
    +---------+
      S S 3 G
      D C v N
      A L 3 D


## J56 PORTG configuration options
----------------------------------

This header gives access to signals PORTG[8..0], these signals in the 
normal firmware are read as configuration options at boot time and are
used to configure various aspects of the firmware.

      G G G G G G G G G
      8 7 6 5 4 3 2 1 0
    +-------------------+
    | o o o o o o o o # |
    | o o o o o o o o o |
    +-------------------+
      G G G G G G G G G 
      N N N N N N N N N
      D D D D D D D D D

Either jumpers or external switches may be fitted to pull these signals
low to enable functions of the firmware. The PORTG[8..0] lines are pulled
high by weak pull-ups in the FPGA and are briefly read by the firmware at
boot time while the reset line is low.

The tables below lists the current firmware settings that are controlled
by this header.


### PORTG[2..0] - X means link fitted
-------------------------------------
  
These pins configure the firmware to support different motherboard
configurations. Any configuration set here must be matched by the correct
settings on jumpers J11, J12, J13 and J14

    G G G
    2 1 0   Motherboard model
    -----   --------------------
    - - -   BBC Model A/B (default)
    - - X   Acorn Electron
    - X -   BBC Model B+
    - X X   BBC Master 128

All other settings are reserved for future use

### PORTG other settings

    G#      Function when fitted
    --      --------------------
    3       T65 - when fitted the T65 core will be the processor at boot
            when not fitted the firmware will expect a "hard CPU" to be 
            fitted and will infer the type and speed of CPU by reading 
            the cpu configuration pins from the CPU headers
    4       SWROMX - when fitted the sets of Sideways ROM and RAM will 
            be exchanged: normally the T65 core will access set #0 and 
            the hard cpu will access set #1. See the section on sideways
            ROM/RAM below
    5       MOSRAM - when fitted the boot ROM (MOS) when running from 
            ROM set #1 will be taken from set #1's ROM #8 which is in 
            battery backed RAM when fitted. When not fitted the (default)
            boot ROM (MOS) will be taken from set #1's ROM#9
            (see the section on Sideways memory below)
    6       MEMI - when fitted in ROM set #0 all ROMs will be read from the
            motherboard and the on board sideways memory
            will be ignored. 
    7,8     RESERVED for future expansion



## J81 JTAG programming port
----------------------------

This port may be used to (re)program the FPGA using an Intel USB Blaster
device or other JTAG programming kit.


      T   T T T
      D n M D C
      I c S O K  
    +-----------+
    | o o o o # |
    | o o o o o |
    +-----------+
      G n n 3 G
      N c c v N
      D     3 D




## J82 configuration select
---------------------------

The MAX10 fpga supports dual-boot ability. This jumper when fitted
will select the secondary firmware on power-up or by pressing the 
CONFIG button. This is an advanced feature - usually this jumper should
not be fitted.




## J91 power select
-------------------

This header selects the power source. When fitted in the North position
5V power will be fed in via the J92 Aux Power connector, when fitted
in the South position power will be taken from the motherboard connector
pin #8.

    +-+
    | |
    |o|  
    | | N - aux power 
    |o| 
    | | S - motherboard power  
    |#|
    | |
    +-+

## J92 auxiliary power
----------------------

This jumper may be used to power the board using an external supply (it
is not normally necessary). The connections should be made as below.
Great care must be taken not to accidentally reverse the polarity or
severe damage may be inflicted on both Blitter board, and any connected
devices!


    +-+
    | |
    |#| +5V regulated 
    | | 
    |o| 0V / Ground
    | |  
    |o| 0V / Ground
    | |
    |o| Not connected
    | |
    +-+




# 3. Solder bridges
-------------------

These solder bridges are usually set at build time and should not normally
be changed by the user

## LK21 RAM0PWR
---------------

This link allows the BBRAM (U22) to be powered direct from the 3v3 line 
instead of from the supercapacitor circuit. Normally there will be no need
to edit this. This link is on the back of the circuit board.

    +-+
    | |
    |#|  
    | | N - battery backup power
    |o| 
    | | S - 3v3 power
    |o|
    | |
    +-+

## LF34 audio ground loop
-------------------------

In most situations the best audio will be obtained by leaving this connection
open. However, when connecting to some non-earthed appliances it may be 
necessary to close this bridge.

## LK90 STM795 bypass
---------------------

This solder pad will be bridged if the optional STM795 supervisor IC is not
fitted, it connects the supercapacitor direct to the 3.3V battery backup
power trace.

## LK92 TPS3808 bypass
----------------------

This solder pad will be bridged if the TPS3808 IC is not fitted it connects
the reset signals from the stm795 and motherboard connector direct to the 
fpga RESET input.























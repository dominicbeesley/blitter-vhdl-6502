# 0. Introduction
-----------------


This document describes the firmware for the mk.2 board, for the latest mk.3 board see
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


```
                         +------------+
                         |"Hard" CPU  |
                         |65x02, 6x09 |
                         |65816, z80  |
                         |or 68008    |
                         +------------+
                              | |      
                              | | CPU bus
        +-----------+    +------------+          +----------------+
        |           |    | FPGA       |          |                |
        |   CHIP    |    | +--------+ |          |   BBC Micro    |
        |   RAM     |    | |T65 CPU | |          |  motherboard   |
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

# Jumpers

All jumpers marked nc should be left unconnected as they may be debug outputs

## J1 VPB/Gnd

 [located NW of cpu sockets]

 This link may be fitted for 6502A to provide an extra ground to the CPU. It must be removed fro other processors. It connects pin 1 of the 65x02/65816 processor sockets firect to 0V. 
 [In practice this may be left off all the time]

## J2 SYS CPU Gnd

 [located above system cpu header area]

 This link should be normally fitted it connects pin 1 of the SYS connector to 
 ground

## J3 Sound output, **J4** ground loop
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
  be tolerated without adverse effects (lower impedances will give lower output
  voltages).

  J4 can be used to connect GndA (the filter capacitors) to the local ground
  in most cases this pin should be left unconnected and the ground of the 
  amplifying device connected to pin 3 of J3 to provide a local ground for 
  minimum noise.

  If the sound is to be fed and mixed via the on-board sound circuits of the 
  host computer the "mono" configuration should be set and flying leads fitted
  from the L pin and the GndA pins connected as follows


### BBC Model A/B

  * J4 should be left open
  * J3 pin 3 should be connected to the east end of R29 on a Model B (audio ground)
  * J4 pin 1 should be connected to the north end of R172 on a Model B (1Mhz audio)

### Elk, Master TODO?


### External sound

 Alternatively the sound output(s) can be connected to the line in of an amplifer
 normally this required J4 to be left open and the Left, Right and Ground inputs
 of the amplifer connected to J3 pins 1, 2 and 3 respectively.

## J5 System config

 [located on north-east corner above Mezzanine board]

 A set of headers are supplied on J5 for general IO or to be used for 
 configuration. On the current firmware they have the following uses:

        <--- W (system on BBC micro/Electron)
        
        
                  G G G G G G G G G G G G G G G G G G G G
                  n n n n n n n n n n n n n n n n n n n n
                  d d d d d d d d d d d d d d d d d d d d
                +-----------------------------------------+
             J5 | o o o o o o o o o o o o o o o o o o o o |
                | # o o o o o o o o o o o o o o o o o o o |
                +-----------------------------------------+
         cfg#         0 1 2 3 4 5 6 7 8 9 A B C D E F

                  S S t c c c s m n b m b n s s s V H 3 3
                  n n 6 p p p w o c u e u c y y y S S v v
                  d d 5 u u u r s   g m g   s s s Y Y 3 3
                  L R   0 1 2 o r   b i o   0 1 2 N N
                              m a   t   u         C C
                              x m   n   t
                                  
  * **snd L/R** Sound 1 bit DAC / pwm output unfiltered
    sound output as 1 bit DAC values can be used to feed into more elaborate
    filtering circuitry if desired

  * **t65** enable internal t65 6502 emulation and disable any hard cpu.

  * **cpu[]** - these jumpers should be set to the correct configuration for the 
    fitted cpu: (o = open, + = closed). It is important to set these correctly
    even if the T65 core is being used.

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


  * **sys[]** - these jumpers should be set to the correct configuration for the 
    fitted type of host computer (o = open, + = closed). It is important to set 
    these correctly
    
    | sys[0]  | sys[1]  | sys[2]  | host/SYS    |
    |---------|---------|---------|-------------|
    |    o    |    o    |    o    | Model B     |
    |    +    |    o    |    o    | Electron    |
    |    o    |    +    |    o    | Model B+    |
    |    +    |    +    |    o    | Master 128  |

    all other settings are reserved    

  * **swromx** when fitted ROM sets are swapped.
    When this jumper is open the T65 core will see ROM set 0
    and the hard cpu will see rom set 1. When fitted the 
    opposite will be true - see the section below on ROM sets    
  * **mosram** when fitted the bank 1 mos is taken from ROM #8 of the current
    map to allow debugging of a MOS with breakpoints. In normall use it is
    desirable to map the MOS into a Flash bank to avoid it becoming corrupted.
    In addition this jumper will cause the 68008 cpu to boot from   
    RAM at 7D xxxx instead of ROM at 9D xxxx and to map memory instead.
    see the API document form more information.
      
  * **bugbtn** a debug switch can be fitted to ground this input, 
    which if NoIce debugging is active will cause an NMI and enter the debugger

  * **memi** fit jumper to inhibit on-board sideways RAM/ROM, instead the
    ROMs on the motherboard will be accessed *in both maps*. This is useful
    if a ROM loaded to the Blitter becomes corrupted or is causing crashes.

  * **bugout*** this may be used in firmware debugging - its exact function
    is undefined
  
  * **VSYNC/HSYNC** these inputs should be connected using flying leads
    to the VSYNC(40) and HSYNC(39) pins of the 6845 and are used by the 
    Aeris Chipset function.

  **Any nc jumpers or positions marked nc must not be jumpered as these may 
  be outputs**


## J6 CPU test pins

[Located N of cpu sockets]

Various marked CPU test pins, these are handy for connecting a Hoglet 
decoder to a 65xx or 6x09 CPU

* [GitHub 6502](https://github.com/hoglet67/6502Decoder)
* [GitHub 6809](https://github.com/hoglet67/6809Decoder)


## P6 CPU voltage 
  [incorrectly labelled should be J7]
  [located W near top cpu sockets ]

    +---+
  1 | # |  +5V
  2 | o |  --- vcc cpu
  3 | o |  +3.3V
    +---+

This header allows the cpu voltage to be set to either 5V or 3.3V. A jumper 
should be fitted as follows:

  1-2 [N] - 5V    [6502, 6x09, 65c02, 65816, Z80, 68008]
  2-3 [S] - 3.3V  [65C02, 65816] (slower, uses less power)


Note: the 65C816S although rated for 5V should be run at 3.3V - this is due
to the fact that the level shifters/FPGA on the board do not drive the 
voltage for the databus high enough for the 816's CMOS level inputs.


## J8 power select

This jumper can select between taking power from the SYS/CPU socket header
(normal operation) or from the P11 AUX POWER connector (programming when not
fitted in a machine). This jumper should nearly always be in the East position
marked "SYS"

# C20KFirstLight builds

## C20KFirstLight

This can be run on a Primer 20K Core lite board or a bare-bones C-20K.

This build does not require on-board RAM or ROM but can be used to load
RAM and or ROM with the utilities in the ../../asm/C20KFirstLight/testprogs
folder.

Connect via the debug port UART using NoICE @ 19200 baud no flow control.

Typically used to load flash data on a new or bricked board

NOTE: the debug button and NMI are disconnected from the CPU to allow
the system to be brought up without most of the chips fitted.

NOTE: until the peripheral multiplexer chip U4 is fitted it is inadvisable to 
enable interrupts as the interrupt line will be effectively floating.


# MEMORY MAP

Both builds share the same memory map.

The 6502 cpu's 16 bit "logical" addresses are mapped to bank FF by default
except where noted in the tables below. Physical addresses are those after
the FF has been prepended to the CPU's 16 bit address.

Accesses via the FF FD00 JIM window follow the same conventions as the BBC
micro. i.e. there are paging registers and a device select register in FRED.
For more information [see JIM page wide access.](https://github.com/dominicbeesley/DataCentre/blob/master/jim-spec-2019.txt)

The device number for these firmware builds is D2. After D2 has been poked
to FCFF to select local JIM the paging registers at FCFD/FCFE (HIGH/LOW) can
be used to select the physical address that the JIM page-wide window will address

When the device number is unset or not D2 then JIM accesses will be directed
to the 1MHz bus port.

```


                00 0000         +-----------------------------+ 
                                | SRAM         - U22 10ns     |
                20 0000         +-----------------------------+
                                | SRAM         - U23 10ns     |
                40 0000         +-----------------------------+
                                | SRAM         - U24 10ns     |
                60 0000         +-----------------------------+
                                | BBSRAM       - U21 45ns     |
                80 0000         +-----------------------------+
                                | Flash EEPROM - U25 55ns     |
                F0 0000         +-----------------------------+
                                | RGB LEDS                    |
                F1 0000         +-----------------------------+
                                | reserved - do not use       |
                FF 0000         +---------CPU DIRECT----------+
                                | FPGA block ram memory       | Always available even on bare FPGA
                FF 8000         +-----------------------------+
                                | Maps to bank 00 0000 U22    |
                FF F000         +-----------------------------+
                                | FPGA Boot ROM               | Loaded as part of FPGA 
                FF FC00         +-----------------------------+ always available
                                | Hardware Registers / JIM    |
                FF FF00         +-----------------------------+
                                | FPGA Boot ROM               | Loaded as part of FPGA 
                FF FFFF         +-----------------------------+ always available
```

## Hardware registers

All hardware registers in the range FF FC00 - FEFF are passed to the 1MHz bus
except for:
    - the UART, JIM and JIM paging registers as listed below.
    - the SYS VIA is emulated on the FPGA
    - ACIA FE08-FE0F
    - SERPROC FE10-FE17 (writes)
    - NETINT FE20 (reads)
    - NETINT/STATIS FE18 - FE1F

## UART 

Address FF FC1x

The UART provided 19,200 baud serial access on the RV debugger port. The serial 
format is 8n1, there is no error or overrun detection.

```
    FF FC10     STATUS      
                (7) - rx data full i.e. data available, read data to clear
                (6) - tx data full i.e. you should wait to write data data, 
                            when a char is being xmitted
                (0) - framing error
    FF FC11     DATA READ/ WRITE
```

## FPGA Configuration SPI Flash

Address FF FC2x

An SPI read/write core is provided which can be used to read and write the
SPI flash on the SOM. 

```

Address  |  Direction   |   Description
---------+--------------+-------------------------------------------------------------------------
FF FC20  |              |
STAT     |   Read       |   Status register:
         |              |   Bit 7 : BUSY    flag, when set a shift is in operation the shift register
         |              |                   contents should not be read whilst this flag is set but
         |              |                   you may start one more write operation which will be 
         |              |                   latched and carried out after the current one.
CTL      |  Write       |       7 : LSB     0 = MSB first, 1 = LSB first
         |              |    5..6 :          Unused-set to 0's
         |              |    2..4 : CS      The chip select index (this chip select will be activated)
         |              |       1 : CPOL    The SPI clock polarity
         |              |       0 : CPHA    The SPI clock / data phase
---------+--------------+-------------------------------------------------------------------------
FF FC21  |              |
DIV      |  Write       |  Clock divider - 1 default = 0 i.e. 256
---------+--------------+-------------------------------------------------------------------------
FF FC22  |              |
SHIFT    |  Read        |  Read current shift register value, do not start another shift
WRITE    |  Write       |  Write data latch, start a shift and reset CS after the shift 
---------+--------------+-------------------------------------------------------------------------
FF FC23  |              |
READ_O   |  Read        |  Read current shift register value, and shift out data in data latch, 
         |              |  leave CS active after the shift is completed
WRITEO   |   Write      |  Write data latch, start a shift, leave CS active after the shift is 
         |              |  complete
```


## LED ARRAY

Address F0 xxxx

The LED array appears as a block of 4 bit registers, each triplet represents 
the Red, Green, Blue values in the low nibble of each byte

F0 0000     LED 0 RED
F0 0001     LED 0 GREEN
F0 0002     LED 0 BLUE

F0 0004     LED 1 RED
F0 0005     LED 1 GREEN
F0 0006     LED 1 BLUE

...

F0 001C     LED 7 RED
F0 001D     LED 7 GREEN
F0 001E     LED 7 BLUE


# Firware memory usage

The Firmware for NoIce and the monitor reserves the following logical 
addresses

00E0 - 00FF Zero page pointers
0100 - 01FF Shared stack
0200 - 0220 Vectors
0200 - 02FF Communications buffer and saved registers
0300 - 03FF Reserved

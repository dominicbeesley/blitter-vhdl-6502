# C20KBareMON

A small monitor program that is loaded to the OS ROM area at F000 and provides
the facility to read and write memory and start programs running.

There is an alternate build which can be run under NoICE running at FF 0100

## Logical vs Physical addresses

The "logical" addresses are 16 bit addresses as seen by the CPU - these are
mapped to bank FF in the physical address space. See the memory map details
[here](../../../boards/C20KFirstLight/README.MD)

# The monitor

The monitor is a simple program to allow data and programs to the system for
performing simple tests and priming the Flash EEPROM.

When the monitor starts a brief help message is printed, at any time this
message can be accessed by sending a ? command (see below).

The monitor prompts for input by displaying ":" prompt:
```?```

If the previous command was not recognised the prompt may be preceded by a "?"
```?:```

Alternatively a longer error message may be given

## COMMAND:?
```:?```

The ? command will display the help text

## COMMAND:READ
R \<p-addr> \<len>

This command will read out from memory as a set of motorola srec hex records

```R FF0100 100```
The example above will dump the CPU's stack area

```R 9D0000 4000```
The example above will dump 16k from the Flash EEPROM

## COMMAND:DUMP
D \<p-addr> \<len>

This command will read out from memory as a human-readable hex dump

```D FF0100 100```
The example above will dump the CPU's stack area

```D 9D0000 4000```
The example above will dump 16k from the Flash EEPROM

## COMMAND:ERASE
E \<p-addr> \<len>

This command is will erase Flash EEPROM in the range specified. The flash 
EERPOM in the C20K has 4Kbyte sectors and whole sectors will be erased.

## COMMAND:PROGRAM

P \<p-addr> \<len>

This command is will transfer \<len> bytes of data to physical RAM or Flash 
EEPROM at the specified address. Up to 0x4000 bytes can be transferred from 
the logical buffer at 4000 (physical FF4000).

Note: Flash needs to be erased before it can be programmed.

## COMMAND:GO
G \<l-addr>

This command can be used to execute a program loaded to logical memory. The
CPU will start executing from \<l-addr> with interrupts disabled.

## COMMAND:FPGA READ
FR \<f-addr> \<len>

This command can be used to read data from the FPGA Configuration serial Flash
ROM. Data are dumped out as Motorola SREC hex records.

## COMMAND:FPGA DUMP
FD \<f-addr> \<len>

This command can be used to read data from the FPGA Configuration serial Flash
ROM. Data are dumped out as human readable hex dump

## COMMAND:SREC load
S1...
S2...

Motorola SREC hex records can be loaded to memory using S1 or S2 lines. 16 bit
address S1 records will be loaded to logical addresses i.e. at FFaaaa
24 bit S2 records will be loaded to physical addresses.

Note: you should check that all lines have loaded and there are no ? or error
messages output.

Note: a delay of at least 50ms should be allowed after each SREC line is sent.
Terminal programs often have options to add a delay after each line of a file
as it is sent (see notes on minicom for a Linux example).


# Examples

## Example 1: load vidtest and execute

Reset the board (with SW4) and obtain a ":" prompt (press return repeatedly)

Send the asm/C20KFirstLight/build/testprogs/vidtest.mot file as ascii to the
monitor (you should have set line delays of at least 50ms)

```ctrl-a, S, ascii, select file```

```
:S12308604C4D4E4F205051525320545556572058595A5B205C5D5E5F2060616263206465B7
:S123088066672068696A6B206C6D6E6F207071727320747576772078797A7B207C7D7EFF73
... 
:S113092000000000000000000000000000000000C3
:S503002AD2
```                            

The S1 and S2 lines of hex should show with no ?'s or error messages, other
lines may show errors.

You should now inspect memory to see that the file has loaded:
```
:d ff0400 200

FF0400 : AD 17 05 8D 20 FE A0 0B A2 0B BD 24 05 8C 00 FE  : .... ......$....
FF0410 : 8D 01 FE CA 88 10 F3 A0 0C 8C 00 FE A9 20 8D 01  : ............. ..
FF0420 : FE A0 0D 8C 00 FE A9 00 8D 01 FE A9 7C 85 01 A9  : ............|...
FF0430 : 00 85 00 A9 05 85 03 A9 30 85 02 A0 00 B1 02 91  : ........0.......
...  
FF0590 : 47 49 4E 45 45 52 49 4E 47 20 92 9C 8C 9E 73 95  : GINEERING ....s.
FF05A0 : 8E 91 8F 94 8F 87 30 32 97 9E 8F 73 93 9A 96 9E  : ......02...s....
FF05B0 : 9F 98 84 8D 9D 83 45 4E 47 49 4E 45 45 52 49 4E  : ......ENGINEERIN
FF05C0 : 47 20 92 9C 8C 9E 73 95 8E 91 8F 94 8F 87 30 33  : G ....s.......03
FF05D0 : 7E FF 7E FF 7E FF 7E FF 7E FF 7E FF 7E FF 7E FF  : ~.~.~.~.~.~.~.~.
FF05E0 : 7E FF 7E FF 7E FF 7E FF 7E FF 7E FF 7E FF 7E FF  : ~.~.~.~.~.~.~.~.
FF05F0 : 7E FF 7E FF 7E FF 30 34 94 9A 9E 73 91 99 95 80  : ~.~.~.04...s....
```

You should now be able to run the program:

```
:G 400
```

If you have a HDMI TV or 50Hz capable monitor an engineering test page should
be shown, if you have fitted U19 then you can also see video on the analogue
video ports.

The other .mot programs may be loaded in the same way see the 
[testprogs readme](../testprogs/readme.md)
for details of the other programs.

# Connection notes:

## minicom

Minicom needs to be set to add some delay after newlines to allow processing to 
proceed

```ctrl-a T, D``` to access line delay - set to 50ms

```ctrl-a O, File transfer settings, I ascii,``` change to:
```	ascii	ascii-xfr -dsv -l 50```

To send hex files

```ctrl-a S, ascii```


If after transfer the file has "?" markers appearing after each line then try
increasing the inter-line delay


### connect from Windows using WSL2

To connect the windows usb port to WSL2 first install usbipd then in 
powershell:

```C:\> usbipd list```

to find the device

```C:\> usbipd attach --wsl --busid=10-1```

to attach in WSL2 - the device should show as /dev/ttyUSBx I had to then run
```$ sudo stty -F /dev/ttyUSB1``` before the device would behave.




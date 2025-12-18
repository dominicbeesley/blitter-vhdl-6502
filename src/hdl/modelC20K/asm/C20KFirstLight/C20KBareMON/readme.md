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




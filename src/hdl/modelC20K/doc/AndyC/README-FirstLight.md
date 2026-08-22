# Notes from bringing up FirstLight firmware.

## Board requirements

- SOM module fitted
- Bridge JP8 on rear of board near USB socket to bypass supervisor IC
- Fit Reset switch SW4 (near USB-C)
- Fit IRQ board hacks

We may need to fit more pull-ups as the firstlight firmware has nmi and
irq wired up to missing chips but in practice it seems to work ok.

## Install NoIce

Download from https://www.noicedebugger.com/download.html

## Build NoIce monitor ROM

Requirements: gcc, make, cc65, perl, srec_cat

~~bin2hex is one of mine - https://github.com/dominicbeesley/hexutils give me a
shout when / if the autotools stuff turns out to be broken...I've never got 
it to check into git then build nicely...~~
I've removed the need for bin2hex and it all now uses Motorola format hex and
uses the more common tool srec_cat to produce it.


```
$ cd src/hdl/modelC20K/asm
$ make
```

This should run through ok on Linux, but let me know if GitHub has buggered
up line-endings. It seems to periodically lose the right settings.

## Build Gowin Project

/src/hdl/modelC20K/boards/C20KFirstLight/C20KFirstLight.gprj

## Load to SOM

This is a good base-line to programmed in to flash as it shouldn't do 
harm when you've got a half-built board.

I have been having bother programming the flash on my SOM - I think this
might be a problem with this particular SOM.

In programmer Operation: Access Mode: External Flash Mode; exFlash Erase,
Program thru GAO-Bridge fails with a "Operation failed" when erasing flash.

If I chose Operation: exFlash Background Erase, Program it seems to work
fine though.

Once you've programmed the flash if you connect a terminal to the UART
port of the RV debugger when you power-up or press the SW4 reset button
you should get something that looks like this:

```
NoIce Monitor MOS
ABC▒
    ▒▒4S▒r

```

Disconnect your terminal program and see if you can get NoIce to connect 
when running it in a VM or Wine.

Fire up NoIce 65(c)02 client
It will probably complain first time you start it about COM ports and might
sit trying to connect for a while beeping away to itself.
Once it is responsive then from main menu Options->Target Communications

Interface: NoIce Serial
Select serial
Select com port, parity none, stop 1, rts off, dtr off

It should hopefully connect...if not then we will need to do some debugging

## Run a program in NoICE

In the /src/hdl/modelC20K/asm/C20KFirstLight/testprogs folder there are a
number of test programs that can be used when debugging the build.

These programs can be loaded using NoIce to the memory then run.

Reset board with SW4
File->Load, pick a .mot file
It should upload after a second or two
Run->Go From : 0400

## Run a program in MONITOR firmware

The C20KFirstLightMon firmware, boots to a simple monitor console that 
can be used to load and run code, load data to memory, program the 
FlashEEPROM (U25) and access the FPGA configuration SPI Flash.

For details of the monitor [see](../../asm/C20KFirstLight/C20KBareMON/readme.md) 

The monitor can be used to load motorola SREC records to memory, when
loading SREC it can be sent direct to the ":" prompt. However, because
the rv-debugger UART has no flow-control and is polled by the monitor 
there needs to be a 50ms delay after each line is sent to allow processing
this should be set in the terminal software.

Once the file is loaded it should be possible to view it using the 'D'ump
command or execute it using the 'G'o command i.e. 

```
:G 400
```

### test-serialout.mot

This is a good first test of Noice as it will run with the SOM only.
It should output test messages to the console (Output tab at bottom of 
screen in Noice).

### ledschase.mot

This will light up the debug LEDS D9-D16 with patterns.

NOTE: the LEDs are horribly bright, I would recommend covering them with
black insulation tape or, I made a little hat out of black opaque packaging
with small 0.5mm holes plucked through for each LED and some double-sided
sticky-tape paper double-sided sticky-tape sandwich which give a less 
eye-watering experience!

### videotest.mot

This will display a mode 7 for 15 seconds then mode 2 test card then exit 
back to monitor.

This should always display over HDMI port given a suitable monitor that
supports 50Hz screen modes.

If IC's U28, U19 and C43 are fitted then all the analogue video ports should
work too.

On the current firmware there may be some patterning at the far right of the
screen and the mode 7 display is narrow and left-justified on some HDMI 
monitors.

### sysvia-time-irq.mot

This program will check that emulated System VIA is working. It should count 
up in seconds. 

# Memory

Fit IC U25 (Flash), U21 (CMOS 45ns SRAM), U22 (10ns fast SRAM)

You should now start up with either the NoICE or Monitor firmware and run the 
following programs

### flashinfo.mot 

This should print the manufacturer and ID of the Flash ROM

If not double check soldering around the flash and other memory chips.

### memtest.mot

This program will test main memory from 0-200000

If not double check soldering around the flash and other memory chips.

# Multiplexer and keyboard tests

Fit U2-4, U6-9, U11, U19-20

You should now start up with either the NoICE or Monitor firmware and run the 
following programs

## Prime the Flash EEPROM

You should now follow the [PrimeFlashNoICE](PrimeFlashNoICE.md) guide to 
prepare the Flash EEPROM with ROM images.

### sysvia-time-irq.mot

This program will check that the IRQ signals are working and not jammed. It 
should count up in second. If not or if there is no display check that the
IRQ line board fixes are correct.

### kbtest-scan.mot

With a keyboard connected to P1 this program should show the key codes of 
pressed keys. If not or if the behaviour is erratic check soldering of the 
multiplexer pins.

# User VIA

Fit the User VIA U5. [This is not strictly necessary but quite a few games
that rely on the User VIA's timers will not run without this fitted.]

### uservia-poll.mot

This program will test the user via timer/counters. It should show a count
that increments every second

### uservia-irq.mot

This program will test the user via timer/counters. It should show a count
that increments every second. This program uses interrupts on the motherboard
if it is erratic or doesn't count up check that the IRQ line mods have been
made correctly.

# Boot the system

The system should now be ready for its first proper boot. You can program the
boards/C20K firmware to the fpga and the system should boot. If the system 
fails to boot you could try flashing the Tricky OS test ROM to 9F0000 and 
see if that will start.

When the Break key is held down then at first one or two LEDs should be lit.
The first one may be red or unlit and the second green. After Break has been
held down for a couple of seconds the second LED should go out and the 3rd
led should light green.

If you get no activity try disconnecting from HDMI or removing FB4 which will
stop the HDMI system from being back-powered from the monitor.

# Fit extra buttons and connectors

You may now fit the extra connectors and associtated buffer ICs for the 1MHz
bus, User port, Floppy disc, Econet headers and serial port though these are 
all optional.

You may fit the components for the analogue port though this is not yet 
supported in the firmware.

It is recommended that the U39,40 and a 65816 socket are fitted at this point.

IT IS recommended however that you at a minimum fit switches SW0-SW4 as these
are useful for debugging and switching between different ROM sets.

# Sound circuitry

This guide will assume that you are fitting the optional PT8211 DAC and that 
the firmware you are loading will have that enabled. If you don't wish to fit
a PT8211 you may skip the first step and change the board_config_pack file of
the firmware to not include i2s sound.

## Fit PT8211

The optional PT8211 chip improves the sound quality available from the C20K
and is now the default option in the firmware.

JP5 and JP6 near U29 should have their traces between the middle pad and 
pad 1 (arrowed) should be cut with a scalpel. Then the opposite pads should
be bridged to the middle pad.

Fit resistors R133-R135

You may also remove R92 and R93 though it is recommended to leave these in
place as they do not affect the operation of the DAC and enable you to 
experiment with the 1-bit sound DACs in future should you wish simply by 
moving the solder bridges on JP5, JP6

## Fit U32, U33, J23, C56, C58

These op-amps are essential for all sound output. J23 provides line-level
sound output suitable for driving and external amplifier

C56 and C58 should be fitted, otherwise the filters will not operate 
correctly.

Once these are fitted you are recommended to connect an amplifier or low
power headphones to the line out jack and check that there is a boo-bip when
the C20K firmware starts / or CTRL-G is pressed

## Optionally fit U34, C61, C62, J11, J25, J26, RV1

U34 is a power and headphone amplifier chip.

Note: both speakers must be fitted for either of them to work 5W, 4-16 ohm 
speakers are recommended.

## Optionally fit RV2

RV2 should be fitted if you intend to add 1MHz bus devices that send sound
back to the machine. It is recommended not to fit this unless you intend
to use 1MHz bus sound devices as it will likely induce noise from the 1MHz
bus.


# Config EEPROM

The BLTUTIL utility ROM has the ability to record and store configuration
information in small 64kbit CMOS flash eeprom much like on the BBC Master.
It is recommended that you fit this ROM otherwise the system will always 
start in Mode 0.

You should now fit U41

# RTC

There is a facility for a Real-Time-Clock chip, you may fit this now though
it is recommended not to as:
a) The battery backup circuitry is faulty and only lasts a few hours
b) The support ROM is not finished

# Next steps

Once the system is booting then please follow the [C20K-getting-started](C20K-getting-started.md)
guide.

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

Requirements: gcc, make, cc65, perl, bin2hex

bin2hex is one of mine - https://github.com/dominicbeesley/hexutils give me a
shout when / if the autotools stuff turns out to be broken...I've never got 
it to check into git then build nicely...


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

## Run a program

In the /src/hdl/modelC20K/asm/C20KFirstLight/testprogs folder there are a
number of test programs that can be used when debugging the build.

These programs can be loaded using NoIce to the memory then run.

Reset board with SW4
File->Load, pick a hex file
It should upload after a second or two
Run->Go From : 0300

### test-serialout

This is a good first test of Noice as it will run with the SOM only.
It should output test messages to the console (Output tab at bottom of 
screen in Noice).

### ledschase

This will light up the debug LEDS D9-D16 with patterns.

NOTE: the LEDs are horribly bright, I would recommend covering them with
black insulation tape or, I made a little hat out of black opaque packaging
with small 0.5mm holes plucked through for each LED and some double-sided
sticky-tape paper double-sided sticky-tape sandwich which give a less 
eye-watering experience!






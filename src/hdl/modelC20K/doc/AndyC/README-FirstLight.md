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

Requirements: cc65, perl, ???

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




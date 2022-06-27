Getting Started - BBC Model B
=============================

Parts list:
 - Blitter board
 - BLTUTILs EEPROM
 - 6809ROMS.ssd
 - 6502ROMS.ssd
 - spare 74LS245
 - spare 74HCT245



# Preparing the base machine

Before inserting the card in a model B for the frst time it is recommended 
that you should:

 * remove any other sideways ROM/RAM expansions, you will hopefully not need
   these anyway
 * remove any 1MHz bus devices whilst doing initial setup and testing
 * remove any TUBE devices whilst doing initial setup and testing
 * remove expansion ROMS but keep BASIC and whatever filing system you wish
   to use to load ROMs ([see Choosing a filing system](#choosing-a-filing-system))
 * remove the 6502 CPU
 * place the supplied 6502 BLTUTILs ROM in the right-most (highest priority
   ROM slot)
 * VideoNULA is recommended but not required

Your machine should now look like this:

<img src="assets/getting-started/empty-mb.jpg" width="80%" />

## Choosing a filing system

The Blitter in 6502 mode should work with most filing systems *except* for 
unmodified RetroClinic DataCentre board which take over the 1MHz bus JIM 
interface in such a way that is not compatible with the Blitter. An updated
[firmware and ROM is available for the DataCentre](https://github.com/dominicbeesley/DataCentre)

In this example a simple user-port MMFS solution is used. Other options
that have been widely tested are:
 * ADFS (Disc and Winchester)
 * 1770 DFS
 * 8271 DFS
 * HOSTFS


## Strip down the Blitter to a minimal configuration

**Mk.2**

* remove all hard CPUs
* remove all jumpers except:
  - P6 CPU voltage set to 3.3V (south)
  - J5 configuration jumper on position marked "0" (3rd from left) - selects T65 internal CPU
  - J2 SYS CPU Gnd - additional ground taken from motherboard
  - J8 Power Select - East - take power from motherboard

<img src="assets/getting-started/mk2-first-boot-jumpers.jpg" width="80%" />


[See Hardware Overview](hardware-overview-mk2.md) for more information about
jumpers

**Mk.3**

TODO


## Insert the Blitter into the motherboard

Take great care when fitting the board as it is very easy to bend/break pins
on the riser plug. 

### Raising the blitter

If you need to use a Watford Electronics or RetroClinic 1770/2 daughter board
with the Mk.2 blitter you may need to add about 1.5cm of height to the Blitter
this can be achieved by piggybacking 5 turned-pin 40pin dip sockets on the
end of Blitter to CPU socket riser plug.


When fitted the board should look like this:


**Mk.2**

<img src="assets/getting-started/mk2-first-boot-fitted.jpg" width="80%" />


**Mk.3**

TODO


Double check by looking under the board as best you can that the pins of the 
riser are correctly aligned with the motherboard CPU socket.


# First boot

You should now be able to power on the machine and should get a boot screen 
like this:

<img src="assets/getting-started/mk2-first-boot.jpg" width="80%" />

If the machine doesn't boot then switch off and work through the 
[Troubleshooting](#troubleshooting) section.

You should then be able type type

    *ROMS

at the command prompt and receive a display of the ROMS in the machine thus:

<img src="assets/getting-started/empty-roms.jpg" width="80%" />

The ROMS that show through in slots #4-#7 should correspond to those fitted
in the motherboard. 

The following sections will discuss loading up the default set of ROMs
you may have been supplied with a board which is pre-loaded with ROMs in 
which case you may want to skip all or part of the following sections.

# Loading other ROMs

This section will guide you through loading some ROMs to the slots provided
by the Blitter card.

When following these examples the syntax of the BLTUTIL ROM utilities can
be found on the [GitHub Wiki](https://github.com/dominicbeesley/blitter-vhdl-6502/wiki/BLTUTIL-Star-Commands)

## Load BLTUTILS to slot \#F (15)

It is desirable to have the utility ROM be in the highest slot:
 * the NoIce debugger only works in slot F
 * holding down "£" at boot can be used to "catch" corrupted ROMs (see 
   [Troubleshooting](#troubleshooting))


Please use the ROMS65.SSD file with your filing system. In this example it
is on MMFS

    \*DIN 0 ROMS65
    \*SRLOAD BLTUTIL F

This will load the ROM in slot F of the current map. You should get the 
following:

<img src="assets/getting-started/srload-output.jpg" size="80%" />

You should now press CTRL-BREAK to refresh the MOS ROM table. Typing:

    \*ROMS

Should now show

<img src="assets/getting-started/srload-2.jpg" size="80%" />

The OS has now disabled the ROM at #7 as it is identical to the one in 
slot #F. However, if you loaded a different version of the BLTUTIL ROM to the
one in the socket on the motherboard you may see both showing in the \*ROMS 
list and also see two Blitter boot messages. 

Note: if you attempt to overwrite the current BLTUTIL rom at any time
the load should work but you will not be returned to the command prompt, 
instead the machine will hang after the "...OK" message. This is deliberate
you will need to press CTRL-BREAK to get the MOS to reload the ROMS table.

You can at any time add a parameter "A" to the \*ROMS command and it will
show all the ROMS, even those ignored by the MOS

    \*ROMS A

<img src="assets/getting-started/roms-a.jpg" size="80%" />

There are also options 

  * "V" to show more verbose ROM titles (including version)
  * "C" to show a CRC for each ROM

<img src="assets/getting-started/roms-vac.jpg" size="80%" />

I can be useful to keep a note of ROM CRCs when they are first loaded,
especially to sideways RAM to check for corruption. Here you can see that
the ROMS at #7 and #F have the same CRC.





# Troubleshooting


## NOTES/Q's for Hoglet

### Default Turbo

Currently the 65xx and 6x09 CPUs by default boot in a trim that allows them
to go as fast as the memory they are accessing will allow. This is usually
not a problem for games as by default they'll run from normal motherboard 
memory at 2MHz but ROMs may run faster which may cause problems (see MMFS
below). Would it be better to boot in "Throttled" mode where these CPUs 
boot strictly limited to 2MHz unless explicitly unlocked?

### 65C02 "soft" CPU

The default fall-back mode is to run with a T65 FPGA core configured as a 
NMOS 6502. This gives maximum compatibility for Elk/BBC. Would it be desirable
to be able to be able to configure the T65 as CMOS - this would allow 
running BASIC 4, etc and possibly other Master compatible stuff but at the 
expense of loss of compatibility.

### MMFS

However, on one machine which otherwise seemed to work OK MMFS returned 
corrupt directories listings and the games menu would crash. Swapping the 
74LS245 (IC14) with and HCT device from another machine solved the problem. 
The swapped out 74LS245 worked ok in the original machine!?!

I've not got MMFS to work when loaded into the Blitterboard sideways ROM or 
RAM but I suspect that is because T65 will try to run at full speed and MMFS
is doing timing loops? If this proves troublesome I have planned but not 
started a facility to mark which ROMs should be allowed to run full speed.
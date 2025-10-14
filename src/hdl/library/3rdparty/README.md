# 3rd party libraries used in the Blitter projects

## Amber

https://opencores.org/projects/amber

Arm compatible core - used for simulation of the external ARM processor module

## HamsterWorks

Some HDMI stuff lifted from the now defunct website https://web.archive.org/web/20190115080828/http://hamsterworks.co.nz/mediawiki/index.php/Main_Page

Not currently used in this project but kept might be used in future HDMI 
options

## Hazard3

https://github.com/Wren6991/Hazard3 @787da13

Hazard3 RiscV core used as a soft cpu option

## hdmi_alexey_spirakov

Alexey Spirakov
Davor Jadrijevic

A suite of hdmi/tmds ouput encoders etc taken from BeebFPGA repository

TODO: Licencing - possibly rewrite/replace

Contains various bodges and fixes to work with differing output serializer 
fabric on the MAX10

May also contain Hoglet fixes? (https://github.com/hoglet67/BeebFpga)

Used in experimental hdmi output builds for Mk.3 boards

## I2C_Minion

https://github.com/oetr/FPGA-I2C-Minion

A simple I2C port peripheral used to interface with config EEPROM and external
devices on Mk.3

## MikeSterling

Many of the video generation parts of MikeSterling's BeebFPGA now migrated to
Hoglets more capable https://github.com/hoglet67/BeebFpga

TODO: This may contain stuff tweaked for this project - in particular sprite
handling on sprite branches and teletext graphics collapsed to smaller memory
footprint - need to bring together all branches and enable with generics.

## Missing 

Contains 3rd party libraries with licenses that preclude them being included
in source form. see README for more details

These are mainly used for simulation of external processors.

## picoRV32

https://github.com/YosysHQ/picorv32 @87c89acc

RiscV core used as a soft cpu option - experimental

## T80

https://github.com/mist-devel/T80 - ancient version

An old snapshot of the T80 core - used for external processor simulation

## T6502

https://github.com/mist-devel/T65

Used for T65 soft-core CPU in most builds - important. This version seems to 
cover most of the necessary "undocumented" instructions

## T6502_816

A heavily frigged version of the above to attempt to simulate the bus behaviours
of the 816 (but not the instructions or extensions)

TODO: remove and migrate to another proper core.

## TG68 

https://opencores.org/projects/tg68

This is a hacked old snapshot to throw together a simulation of basic 68K 
behaviour

Also includes a 68008 wrapper which mimics the 68008 8 bit bus.


## FMF

https://freemodelfoundry.com/

Models taken and adapted from Free Model Foundry for various components for
simulation


# P65816 core

Developed by [@pgate1](http://pgate1.at-ninja.jp/SNES_on_FPGA/index.html#release) and used in the [Mister SNES Core](https://github.com/MiSTer-devel/SNES_MiSTer)

Edited to expose the E, X, M flags
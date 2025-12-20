# Prime U25 Flash EEPROM using NoICE

This process notes how to ready the Flash EEPROM U25 by loading enough
ROMS to boot a full C20K or C20K816 firmware. This typically only needs to 
be done once, or if an accidental corruption of the BLTUTIL or MOS rom has
occurred. If other ROMS are corrupted typically it is possible to use the
"NUKE" facility of the BLTUTIL ROM by holding down the "£" key at boot.

The C20K firmware has two "rom sets" set 0 is typically used by the t65 
soft-core NMOS 6502 set 1 is used either by the 65816 or other alternate
soft-core CPU such as RiscV. 

## flashinfo.mot

To check that the Flash EEPROM is recognised you should run the flashinfo.mot
program in NoIce (GO 400).

This should report the type and size of Flash chip installed.

## flashprog.mot

The flashprog.mot program can be used to erase and program the Flash chip.

This program provides a simple user-interface to erase sectors on the Flash
EEPROM and to copy data from the CPU's logical address area to any location in
the physical memory map, including Flash. When programming Flash a special
programming sequence must be implemented by the monitor to unlock and program
the flash.

See [METHOD 1](#method-1-flash-using-flashprog)

# What to Load

See [Rom's zip](setuproms.zip)

The following ROM images should be loaded to allow the system to be brought up
to the point where further ROMS can be installed using the normal \*SRLOAD 
facilities of the BLTUTIL rom

| Image         | Slot  | Addr   | Notes                                 |
|:--------------|------:|-------:|:--------------------------------------|
| M.MOS120      |     9 | 9F0000 | The Acorn 1.20 MOS for the BBC Micro  |
| BASIC2        |     B | 9F4000 | The Acorn BASIC from for the BBC      |
| BBLMMFS       |     D | 9F8000 | The MMFS filing system E00            |
| BLTUTIL       |     F | 9FC000 | The C20K/Blitter Utility ROM          |

This should allow you to boot the system. 

The MMFS rom will give an MMFS filing system using the microSD card slot on
the SOM module.

# OS Test ROM

If you are having problems booting you can also try loading Tricky's OS Test
rom to slot 9

| Image         | Slot  | Addr   | Notes                                 |
|:--------------|------:|-------:|:--------------------------------------|
| M.MOS120      |     9 | 9F0000 | The Acorn 1.20 MOS for the BBC Micro  |


# METHOD 1: Flash using flashprog

1. Reset the NoICE monitor

2. Load the binary to memory at FF4000
```
    File->Load
    Choose binary MOS / ROM FILE
    Address or Offset: 4000
    Load as binary image
```
    [Alternatively you can load as a hex file but the hex file must be set to
    load at address 4000 or FF4000]

3. Start the FlashProg.mot program
```
    File->Load
    Choose binary testprogrs/flashprog.mot
    Run->Go From: 0400
```

4. Erase the ROM slot
```
    E <addr> 4000
```

Replace \<addr> with the address from the ROM Address Table below.

If you are loading multiple ROMS it is often wise to clear the entirety of
the flash chip.

To Erase the whole of map 0:
```
    E 9E0000 20000
```

To Erase the whole of map 0:
```
    E 9C0000 20000
```

5. Program the ROM slot
```
    P <addr> 4000
```

You can check that the data have been loaded correctly to the Flash by reading
back out using the 'R' command
i.e. to read back the MOS slot:
```
    R 9F0000 4000
```
You can then decode the results using the srec_cat utility and compare with the
original files.

# ROM SLOT ADDRESS TABLE

For further details see the [API](../../../../../doc/API.md) document and the 

## MAP 0

  | # | Type      | Physical address   | Notes                                 
  |---|-----------|--------------------|---------------------------------------
  | 0 | BB RAM    | 7E 0000 - 7E 3FFF  |                                       
  | 1 | EEPROM    | 9E 0000 - 9E 3FFF  |                                       
  | 2 | BB RAM    | 7E 4000 - 7E 7FFF  |                                       
  | 3 | EEPROM    | 9E 4000 - 9E 7FFF  |                    
  | 4 | BB        | 7E 8000 - 7E BFFF  | 
  | 5 | EEPROM    | 9E 8000 - 9E BFFF  | 
  | 6 | BB        | 7E C000 - 7E FFFF  | 
  | 7 | EEPROM    | 9E C000 - 9E FFFF  | 
  | 8 | BB RAM    | 7F 0000 - 7F 3FFF  | also used as the MOS ROM when MOSRAM in effect
  | 9 | EEPROM    | 9F 0000 - 9F 3FFF  | used as the MOS on C20K (not when MOSRAM in effect)
  | A | BB RAM    | 7F 4000 - 7F 7FFF  |                                       
  | B | EEPROM    | 9F 4000 - 9F 7FFF  |                                       
  | C | BB RAM    | 7F 8000 - 7F BFFF  |                                       
  | D | EEPROM    | 9F 8000 - 9F BFFF  |                                       
  | E | BB RAM    | 7F C000 - 7F FFFF  |                                       
  | F | EEPROM    | 9F C000 - 9F FFFF  | 


## BBC MAP 1

  | # | Type      | Physical address   | Notes                                 
  |---|-----------|--------------------|---------------------------------------
  | 0 | BB RAM    | 7C 0000 - 7C 3FFF  |
  | 1 | EEPROM    | 9C 0000 - 9C 3FFF  |
  | 2 | BB RAM    | 7C 4000 - 7C 7FFF  |
  | 3 | EEPROM    | 9C 4000 - 9C 7FFF  |
  | 4 | BB RAM    | 7C 8000 - 7C BFFF  |
  | 5 | EEPROM    | 9C 8000 - 9C BFFF  |
  | 6 | BB RAM    | 7C C000 - 7C FFFF  |
  | 7 | EEPROM    | 9C C000 - 9C FFFF  |
  | 8 | BB RAM    | 7D 0000 - 7D 3FFF  | also used as the MOS ROM when MOSRAM in effect
  | 9 | EEPROM    | 9D 0000 - 9D 3FFF  | used for MOS in Map 1 (not when MOSRAM in effect)
  | A | BB RAM    | 7D 4000 - 7D 7FFF  |
  | B | EEPROM    | 9D 4000 - 9D 7FFF  |
  | C | BB RAM    | 7D 8000 - 7D BFFF  |
  | D | EEPROM    | 9D 8000 - 9D BFFF  |
  | E | BB RAM    | 7D C000 - 7D FFFF  |
  | F | EEPROM    | 9D C000 - 9D FFFF  | NB: also used as the NoIce debug bank

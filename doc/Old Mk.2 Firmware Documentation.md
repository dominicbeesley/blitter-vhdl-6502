This document contains information about deprecated and removed features
of the old Mk.2 firmware.

Items marked "deprecated" are still functional as of June 2022.
Items marked "obsolete" are no longer present.


# Old Mk.2 configuration registers

FF FE3E/F
---------

  **$FE3E,F** this register pair can be used to read back the current values
  on the configuration pins, the values are inverted and give a '1' where a 
  jumper is fitted. Writing to this register is reserved for future uses and
  should be avoided.

  $FE3E:

  Bit(s) | Value | Meaning
  -------|-------|--------------------------------------
   0    *|   1   | t65 core in operation
         |   0   | hard cput in operation
   3..1 *|  000  | 6502A @ 2 MHz
         |  100  | 65C02 @4Mhz
         |  010  | 65C02 @8Mhz          --currently 4Mhz
         |  110  | 65C816 @8Mhz         --currently 4Mhz
         |  001  | 6809E/6309E @2Mhz
         |  101  | 6309E @4Mhz
         |  011  | Z80A @8Mhz
         |  111  | 68008 @8Mhz
   4    *|   1   | swromx not fitted 
         |   0   | swromx fitted
   5     |   ?   | ?
   6     |   ?   | ?
   7     |   1   | bugbtn pressed         

  $FE3F:

  Bit(s) | Value | Meaning
  -------|-------|--------------------------------------
   0    *|   1   | memi jumper fitted i.e. chip swrom/ram disabled
         |   0   | normal
   1     |   X   | inverted bugout signal
   7..2  |   ?   | ?

NOTE: bits marked * are latched at reset time and do not reflect the active state
of the config pins
NOTE: bits marked ? should be masked out and ignored as these are used for various
debugging and test purposes which is likely to change with firmware updates

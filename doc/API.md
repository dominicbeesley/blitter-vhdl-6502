

### Build version and configuration

The version and configuration page in physical page FC 0000 contains 
information about the static build information for the current firmware.

Locations FC 0000 to FC 0080 contain a set of strings delimited by 0 bytes
and terminated by two zero bytes:

```
 | string index | Contents                                             |
 |--------------|------------------------------------------------------|
 | 0            | Repo version:                                        |
 |              | - G:<hash>[M] - Git Version hash                     |
 |              | - S:<number>[M] - Svn version number                 |
 |              | trailing 'M' indicates modified from the given no.   |
 |--------------|------------------------------------------------------|
 | 1            | YYYY-MM-DD:HH:MM:SS                                  |
 |              | build start time                                     |
 |--------------|------------------------------------------------------|
 | 2            | Board name - a short name for the configuration      |
 |--------------|------------------------------------------------------|
 | 3            | branch:repo                                          |
 |              | the repo name is shortened and the format should not |
 |              | be relied on and may change                          |
 |--------------|------------------------------------------------------|
```

More strings may be added in future

### Configuration switches

The boot-time configuration is read from the on-board configuration switches
(or build time options for firmware versions that do not support the function)
and presented in page FC 0100

 | index        | Contents                                             |
 |--------------|------------------------------------------------------|
 | FC 0000      | API Level                                            |
 |              | If this byte is 0 or FF then the firmware is older   |
 |              | and the rest of the information in this page is not  |
 |              | valid. Current Value = 1                             | 
 |--------------|------------------------------------------------------|
 | FC 0001      | Board/firmware level                                 |
 |              | - 0 - 1MHz Paula                                     |
 |              | - 1 - Mk.1 Blitter                                   |
 |              | - 0 - Mk.2 Blitter                                   |
 |              | - 0 - Mk.3 Blitter                                   |
 |--------------|------------------------------------------------------|
 | FC 0002      | API Sub level (usually 0)                            |
 |--------------|------------------------------------------------------|
 | FC 0003      | - reserved -                                         |
 |--------------|------------------------------------------------------|
 | FC 0004      | Hard CPU type (ABI/Instruction Set)                  |
 |              |    65xx series                                      
 |              | 00 6502A                                             |
 |              | 01 65C02/65SC02/W65C02 (no CE or Rockwell ext.s)     |
 |              | 03 R65C02 (Rockwell ext.s)                           |
 |              | 07 W65C02S (Rockwell + WDC STP/WAI)                  |
 |              | 09 65CE02 (CE extensions)                            |
 |              | 15 65816 (65816 and STP/WAI)                         |
 |              |                                                      |
 |              |                                                      |
 |              |                                                      |
 |              |                                                      |
 |              |                                                      |
 

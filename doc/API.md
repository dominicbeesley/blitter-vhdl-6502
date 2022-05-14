

### Build version and configuration

The version and configuration page in physical page FC 00xx contains 
information about the static build information for the current firmware.

Locations FC 0000 to FC 0080 contain a set of strings delimited by 0 bytes
and terminated by two zero bytes:

```
 | index        | Contents                                             |
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
and presented in page FC 0080 onwards

```
 | address      | Contents                                             |
 |--------------|------------------------------------------------------|
 | FC 0080      | API Level                                            |
 |              | If this byte is 0 or FF then the firmware is older   |
 |              | and the rest of the information in this page is not  |
 |              | valid. Current Value = 1                             | 
 |--------------|------------------------------------------------------|
 | FC 0081      | Board/firmware level                                 |
 |              | - 0 - 1MHz Paula                                     |
 |              | - 1 - Mk.1 Blitter                                   |
 |              | - 2 - Mk.2 Blitter                                   |
 |              | - 3 - Mk.3 Blitter                                   |
 |--------------|------------------------------------------------------|
 | FC 0082      | API Sub level (usually 0)                            |
 |--------------|------------------------------------------------------|
 | FC 0083      | - reserved -                                         |
 |--------------|------------------------------------------------------|
 | FC 0084..87  | Configuration bits in force, see table below         | [1]
 |--------------|------------------------------------------------------|
 | FC 0088..8F  | Capabilities, see table below                        |
 |--------------|------------------------------------------------------|
```

[1] The configuration bits are read at boot time. Unused bits should be masked out
as future firmwares will likely utilize these bits

#### Configuration bits

FC 0084..FC 0087

The configuration bits are mapped differently for each board level:

##### Paula

???

##### Mk.1

???

##### Mk.2

 | address      | hardware                          |
 |--------------|-----------------------------------|
 | FC 0084      | configuration header bits  [7..0] |
 | FC 0085      | configuration header bits [15..8] |
 | FC 0086      | - unused -                        |
 | FC 0087      | - unused -                        |

##### Mk.3

 | address      | hardware                          |
 |--------------|-----------------------------------|
 | FC 0084      | PORTG[7..0]                       |
 | FC 0085      | PORTF[3..0] & PORTG[11..8]        |
 | FC 0086      | - unused -                        |
 | FC 0087      | - unused -                        |

### Blitter Capabilities

FC 0088..FC 008F

The capabilities of the current firmware build are exposed in API>0 at these 
locations the capabilities describe which devices and functions are available
in the current build

 | address | bit # | descriptions                   |
 |---------|-------|--------------------------------|
 | FC 0088 | 0     | Chipset                        |
 |         | 1     | DMA                            |
 |         | 2     | Blitter                        |
 |         | 3     | Aeris                          |
 |         | 4     | i2c                            |
 |         | 5     | Paula sound                    |
 |         | 6     | HDMI framebuffer               |
 |         | 7     | T65 soft CPU                   |
 |---------|-------|--------------------------------|
 | FC 0089 | 0     | 65C02 hard CPU                 |
 |         | 1     | 6800 hard CPU                  |
 |         | 2     | 80188 hard CPU                 |
 |         | 3     | 65816 hard CPU                 |
 |         | 4     | 6x09 hard CPU                  |
 |         | 5     | Z80 hard CPU                   |
 |         | 6     | 68008 hard CPU                 |
 |         | 7     | 680x0 hard CPU                 |
 |---------|-------|--------------------------------|
 | FC 008A | *     | - reserved - all bits read 0   |
 |   to    |       |                                |
 | FC 008F |       |                                |
 |---------|-------|--------------------------------|


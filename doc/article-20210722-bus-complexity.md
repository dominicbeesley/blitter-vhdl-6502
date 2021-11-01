[u]Firmware Architecture Deep Dive[/u]
[super]After reading this, do not operate heavy machinery[/super]

The reason that the T65 soft CPU (and when I get round to it the hard processors) are running relatively slowly compared to say BigEd/Revaldhino's beeb816 is down to my desire to allow for multiple Bus Masters and to allow those Bus Masters to claim the bus Arbitrarily. 

In a normal Model B/Master/Elk there is a single Bus Master and that is the CPU, more or less everything is directed by the CPU all the time. In this project though there are a number of processors all vying for the use of the bus:
- Blitter, when working may be reading / writing to ChipRAM or System Memory
- Paula Sound, reading samples "occasionally" from either ChipRAM or System Memory
- Aeries, reading its program or writing to hardware registers "occasionally"
- DMA, bursts of reads/writes to/from ChipRAM/SystemRAM/Hardware
- CPU more or less always reading/writing but could be any of the ChipRAM/System Memory/Hardware Registers

```
                         +------------+
                         |Onboard CPU |
                         |65x02, 6x09 |
                         |65816, z80  |
                         |or 68008   *|
                         +------------+
                              | |      
                              | | CPU bus
        +-----------+    +------------+          +----------------+
        |           |    |FPGA        |          |                |
        |   CHIP    |    | +--------+ |          |   BBC Micro    |
        |   RAM     |    | |T65    *| |          |  motherboard   |
        |   2Mb     |    | +--------+ |          |                |
        +-----------+    | |DMA    *| |          |                |
           | |           | +--------+ |          +--+             |
           | | MEM bus   | |BLIT   *| | SYS bus  | s|             |
           | +-----------| +--------+ |----------|Co|             |
           | +-----------| |SOUND  *| |----------|Pc|------...    |
           | |           | +--------+ |          |Uk|------...    |
           | |           | |MEM CTL | |          | e| system bus  |
        +-----------+    | +--------+ |          | t|             |
        |           |    | |VERSION | |          +--+             |
        | Flash     |    | +--------+ |          |                |
        | EEPROM    |    | |AERIS  *| |          |                |
        | 256K/512K |    | +--------+ |          |                |
        +-----------+    +------------+          +----------------+
                              | |
                         +------------+
                         | i2c config |
                         | eeprom     |
                         +------------+
Items marked * are potential Bus Masters
Note: some details omitted
```

In the diagram above there are 5 Masters and 9 Slaves:

Masters:
        - CPU (either T65 core or a real CPU)
        - DMA
        - BLIT
        - SOUND
        - AERIS
Slaves:
        - Chip/Flash RAM
        - SYS (BBC Micro motherboard)
        - DMA control regs
        - BLIT control regs
        - SOUND control regs
        - MEM CTL control regs
        - VERSION information pages
        - AERIS control regs
        - i2c bus

There are various ways to arbitrate between the competing needs. Below are some of the ones I've tried: 

*Time Slicing*
For instance the Amiga only lets its sound system access memory once every 1/15000th or so of a second for a few cycles. I ruled that out as being viable fairly quickly - especially when accessing the BBC's main memory for updating graphics the CPU and Blitter need to be able to not only go full speed but preferably be able to be writing to the Screen Memory at 2MHz whilst doing one or more reads from ChipRAM at a faster rate - doing this allows us to copy a whole screen full of data in roughly 10ms and still leave the CPU/Sound/etc running at a slightly reduced speed)

*Bus Request/Acknowledge*
The other option is to have a slow, simple arbitration process where a Master claims the system and then does what it needs to do then relinquishes the system. This is relatively simple to implement but doesn't necessarily allow things to proceed that quickly. For instance copying the screen takes 10ms out of 20 so the cpu would be halted 50% of the time in games. Also there are usually lost cycles when handing over.

*Per cycle arbitration and Crossbar*
The third option which I tried was to use a big cross-bar interconnect and arbitrate [i]every cycle[i]. This allows multiple masters to operate in parallel without any lost cycles so long as the two masters are accessing different resources. Otherwise they are queued up behind each other. This though has some down sides - the arbitration process is fairly slow and takes up a lot of fpga fabric. 


```
*Big Crossbar*
                     +----------------------+
                     |                      |=====>ChipRAM
                     |                      |=====>SYS
        CPU=========>|                      |=====>DMA
        DMA=========>|                      |=====>BLIT
        BLIT========>|   CROSS BAR SWITCH   |=====>SOUND
        SOUND=======>|                      |=====>MEMCTL
        AERIS=======>|                      |=====>VERSION
                     |                      |=====>AERIS
                     |                      |=====>i2C
                     +----------------------+

```

The crossbar switch is very nice in that it lets stuff happen in parallel but it is resource intensive and tends to create a lot of combinatorial logic for muxes - these take up space and create timing issues. The number of muxes needed is roughly proportional to the number of Masters multiplies by the number of Slaves.

Arbitration for the Cross bar switch is also quite costly and complicated. There are a number of things that need to happen at the start of a cycle

- Master asserts it wants to access something (sets address and CYC flag)
- Address decoding logic decides which slave is being requested (this is quite complex and needs at least one fast cycle)
- Arbitration logic works out if there is another Master using or requesting the same slave
- If there is decide which Master wins (round robin or simple priority)
- Send the request on to the Slave
- Wait for slave
- Return data from the slave to the master

*Smaller Crossbar with multiplexed chipset*
The fourth option is to have a smaller crossbar which arbitrates between two masters "chipset" which covers all masters other than the cpu (another level of arbitration sorts out which of the blitter/sound/aeris/dma is currently in charge).



```
*Simplified?*
                     
                     
                                                 +-----------+
                     +-------------+             |           |
        DMA=========>| Many Master |             |   CROSS   |============>VERSION
        BLIT========>| to one slave|="CHIPSET"==>|           |============>SYS
        SOUND=======>| priority    |             |           |============>CHIPRAM/FLASH
        AERIS=======>| switch      |             |    BAR    |============>MEMCTL
                     +-------------+             |           |
                                                 |           |             +------------+
        CPU=====================================>|   SWITCH  |="CHIPSET"==>| One master |====>DMA
                                                 |           |             | to many    |====>BLIT
                                                 +-----------+             | slave      |====>SOUND
                                                                           |            |====>AERIS
                                                                           |            |====>i2c
                                                                           +------------+
```

This at first glance looks as if it would be more complex as there are now three switches. However, it solves several problems. 

- Cross bar is now much smaller
- Chipset can operate in parallel with CPU though Chipset has to fight it out internally
- Arbitration logic is simplified
- Address selection logic at the cross bar is much simpler

The main win though, is that the CPU to SYS and CPU top ChipRAM paths, which are the most critical, can now be optimised with a simpler crossbar. For Hard CPUs to access the BBC motherboard all the arbitration and address setup needs to happen within roughly 150ns of phi2 - if it doesn't the 1MHz stretch circuitry in the Model B starts to play up. For the T65 core this is less of a problem but for the slower 8 bit cpus (6502A, 6809, etc) they take quite a long time to set up their address so squeeze the time available for bus arbitration and complex address decoding etc. The CPU to ChipRAM path defines the maximum CPU speed for faster CPUs (t65, 65C02, 65816, etc)

*Shared bus instead of crossbar*
The fifth option is which I'm using now to try and get timing closure (and maximum CPU speed) is to use a simpler priority switch in the middle



```
*Simplified?*
                     
                     
                                                 +-----------+
                     +-------------+             |           |
        DMA=========>| Many Master |             | PRIORITY  |============>VERSION
        BLIT========>| to one slave|="CHIPSET"==>| /ROUND-   |============>SYS
        SOUND=======>| priority    |             | ROBIN     |============>CHIPRAM/FLASH
        AERIS=======>| switch      |             | SWITCH    |============>MEMCTL
                     +-------------+             |           |
                                                 |           |             +------------+
        CPU=====================================>|           |="CHIPSET"==>| One master |====>DMA
                                                 |           |             | to many    |====>BLIT
                                                 +-----------+             | slave      |====>SOUND
                                                                           |            |====>AERIS
                                                                           |            |====>i2c
                                                                           +------------+
```


The switch that arbitrates between the CPU/CHIPSET now only allows a single Master to be active at a time. In priority mode the switch will prefer the CHIPSET over the CPU if they are both requesting at the same time. In round-robin mode they will be allowed to work roughly in turns*. This saves on resources and helps with timing but I'd really like to go back to a cross-bar setup if that can be made fast enough.

[*This doesn't quite work in practice as the cpu tends to relinquish the bus for several fast cycles while a "hard cpu" makes its address available the chipset tends to get more than a fair go!]
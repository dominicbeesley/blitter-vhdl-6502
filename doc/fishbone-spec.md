New rules:

- d_wr_stb may be asserted after a_stb
- d_wr_stb must be asserted for every we cycle unless cyc is dropped
- d_wr_stb for cycle n - may be asserted after a_stb for n+i - TODO: check, if not then assert stall must *should* be asserted until d_wr_stb?


what are rules when cyc is dropped early - must all items support it?
- must negate ack/rdy instantly?
- ack/rdy should be qualified by cyc i.e. must be deasserted as soon as cyc dropped
- ack will be active for exactly one cycle
- rdy may be active for one ore more cycles before ack 
- rdy must be asserted when ack is asserted
- rdy must not be asserted after ack is deasserted

Masters must handle slaves that ack a write cycle *before* d_wr_stb has been asserted (where a write is inappropriate for example)


# Introduction

This documentation describes the bus architecture that is used to connect the various devices and 
sub-systems within the Blitter Board Firmware. This specification will be of interest to those wishing
to understand the internals of the Firmware. It is not necessary to understand this specification to 
use the Firmware as a programmer.

It is recommended to have some familiarity with the 
[Wishbone Specification](https://en.wikipedia.org/wiki/Wishbone_(computer_bus)) before reading this document.


The Fishbone bus (loosely inspired by the Wishbone bus) is an FPGA internal bus system to allow the various
components of the blitter chipset to communicate within the FPGA. 

The the Fishbone bus is an FPGA targetted bus specification it needs to carry signals to allow it to be
interfaced asynchronous devices and buses. For example some CPUs (68k, Z80) require a data ready signal
to be asserted some time ahead of data being actually ready. To that end the Fishbone bus carries a 
rdy_ctdn signal which indicates in how many clocks data will be available.

## Terminology 

As of 2021 the terms Master/Slave are being phased out and replaced with the terms Controller/Peripheral

Master => Controller
Slave => Peripheral

i.e. a CPU is a Controller, Memory would be a Peripheral

# Bus Clock Speed

The bus clock speed for the Fishbone bus is generally much faster than that of the devices attached to 
the bus. The speed is generally chosen to:

* provide enough timing granularity
* not consume excessive power
* allow timing closure

In general the clock speed is 128MHz, as of November 2021 many of the Blitter components are coded to
expect a 128MHz bus.


# Bus signals

## Syscon Signals

The syscon signals provide system-wide control and clocking signals that keep all devices synchronised.

        
        +-------------+----------------------------+------------------------------------------------------+
        | Signal      | VHDL type                  | Description                                          |
        +-------------+----------------------------+------------------------------------------------------+
        | clk         | std_logic                  | The system clock - generally at 128MHz. Other signals|
        |             |                            | are generally registered on the rising_edge of this  |
        |             |                            | clock.                                               |
        |             |                            |                                                      |
        +-------------+----------------------------+------------------------------------------------------+
        | rst         | std_logic                  | System-wide reset signal. This signal is registered  |
        |             | (+)                        | by the clk signal                                    |
        +-------------+----------------------------+------------------------------------------------------+
        | rst_state   | fb_rst_state_t             | Qualifies the reset signal:                          |
        |             |                            | * powerup                                            |
        |             |                            | * reset                                              |
        |             |                            | * resetfull                                          |
        |             |                            | * prerun                                             |
        |             |                            | * run                                                |
        |             |                            | * lockloss                                           |
        +-------------+----------------------------+------------------------------------------------------+

During reset the different rst_state signals can be used to perform different/seqeunced resets depending
on the type / stage of the reset.

### rst_state = powerup

This reset type is asserted initially at power-up/fpga reconfiguration before any other. It lasts for
10 fast cycles.

### rst_state = reset

This is a normal reset and will follow a powerup reset or be triggered directly by a user pressing the
BREAK key normally.

### rst_state = resetfull

This is a "strong" reset and is triggered by a user holding the BREAK key down for several seconds it 
can be used to reset operating conditions that might cause a machine to become unusable under fault
conditions but that would should normally survive a reset. For example in the 6809 cpu mode it is possible
to enter a Flex Mode where the normal Sideways ROM/RAM is disabled. If the system becomes corrupted a 
long BREAK can be used to return to the MOS ROM mode.

### rst_state = prerun

This occurs briefly before the run state is entered - this may be removed in a future release.

### rst_state = run

There is no reset asserted

### rst_state = lockloss

The main pll or the BBC Micro System peripheral clock have become unlocked. The system will hang
and the LEDS flash. This state can only be exited by a power-cycle or by a full reset (holding down
BREAK for several seconds).

## Controller to Peripheral sigals

These signals are asserted by a controller to control a bus cycle

        +-------------+----------------------------+------------------------------------------------------+
        | Signal      | VHDL type                  | Description                                          |
        +-------------+----------------------------+------------------------------------------------------+
        | cyc         | std_logic                  | A cycle is being requested. This signal must remain  |
        |             | (+)                        | asserted for the duration of a cycle                 |
        |             |                            |                                                      |
        +-------------+----------------------------+------------------------------------------------------+
        | A_stb       | std_logic                  | The A and we signals are valid. The A_stb signal     |
        |             | (+)                        | should normally remain asserted for the entirety of  |
        |             |                            | a cycle and once asserted A and we must not change   |
        +-------------+----------------------------+------------------------------------------------------+
        | A           | std_logic_vector           | The system address that is being requested.          |
        |             | (23 downto 0)              | All peripherals accept a 24 bit address even if they |
        |             |                            | only decode a subset of these addresses. The cyc     |
        |             |                            | and a_stb signals are used to qualify the address and|
        |             |                            | indicate that a peripheral access is required.       |
        |             |                            |                                                      |
        +-------------+----------------------------+------------------------------------------------------+
        | we          | std_logic                  | Write Enable. The current cycle will be a write      |
        |             | (+)                        | cycle. This signal must be valid when A_stb is       |
        |             |                            | asserted and must not change during a cycle          |
        +-------------+----------------------------+------------------------------------------------------+
        | D_wr        | std_logic_vector           | Write Data. The data to be written in a write cycle  |
        |             | (7 downto 0)               | the write data must remain stable whilst D_wr_stb    |
        |             |                            | is asserted                                          |
        +-------------+----------------------------+------------------------------------------------------+
        | D_wr_stb    | std_logic                  | Write Data Strobe. The D_wr signal is valid.         |
        |             | (+)                        | This may be some time after a cycle has started. For |
        |             |                            | instance on a 6502 hard processor the write data is  |
        |             |                            | not ready until some time after the start of the phi2|
        |             |                            | part of the cycle but a SYS cycle must be started    |
        |             |                            | during the phi1 cycle                                |
        +-------------+----------------------------+------------------------------------------------------+


## Peripheral to Controller signals

These signals are returned from a peripheral to a controller

        +-------------+----------------------------+------------------------------------------------------+
        | Signal      | VHDL type                  | Description                                          |
        +-------------+----------------------------+------------------------------------------------------+
        | D_rd        | std_logic_vector           | Data returned to a controller from a peripheral in a |
        |             | (7 downto 0)               | read cycle. This data should not be read until the   |
        |             |                            | ack and/or rdy_ctdn=0 is/are asserted                |
        +-------------+----------------------------+------------------------------------------------------+
        | rdy_ctdn    | unsigned                   | This signal gives an indication of how many fast     |
        |             | (RDY_CTDN_LEN-1 downto 0   | clock cycles remain until the data will be ready.    |
        |             |                            | When a cycle starts or when no cycle is in progress  |
        |             |                            | this signal will be set to RDY_CTDN_MAX. During a    |
        |             |                            | cycle this value may decrement by more than one each |
        |             |                            | clock but must never increment except when a cycle   |
        |             |                            | is released.                                         |
        |             |                            | This signal is used to give an indication of when    |
        |             |                            | data will become available for CPUs such as the M68K |
        |             |                            | and Z80 which require a DTACK/WAIT signal a signi-   |
        |             |                            | ficant time ahead of data actually being available   |
        |             |                            | For write signals this countdown is usally asserted  |
        |             |                            | 0 as soon as D_wr_stb is asserted. However for slow  |
        |             |                            | devices this might not be the case so any controller |
        |             |                            | must respect this count (or ack) during write cycles |
        +-------------+----------------------------+------------------------------------------------------+
        | ack         | std_logic                  | This must be asserted when rdy_ctdn is 0 and         |
        |             | (+)                        | indicates that the peripheral has finished or has    |
        |             |                            | enough data to finish a cycle and that the controller|
        |             |                            | should terminate the cycle. Note: during write cycles|
        |             |                            | a peripheral may latch the D_wr data as soon as      |
        |             |                            | D_wr_stb is asserted and assert this signal even if  |
        |             |                            | the data have not yet been written for example to a  |
        |             |                            | slow device/memory. The controller should contain a  |
        |             |                            | state machine and interlock logic to ensure that     |
        |             |                            | another cycle is not serviced and data lost until    |
        |             |                            | ready                                                |
        +-------------+----------------------------+------------------------------------------------------+
        | nul         | std_logic                  | Null cycle. This indicates a bus error and that      |
        |             | (+)                        | the current ack/rdy_ctdn=0 state is being asserted   |
        |             |                            | due to an error                                      |
        +-------------+----------------------------+------------------------------------------------------+


# Bus Cycle

A bus cycle may take many clocks to service or may be over in a minimum of 2 clocks. A bus cycle can
be thought of as a trnsaction that takes place between a controller and a peripheral.


# Examples

Note in the following cycles the rdy_ctdn signal has a maximum value of 7 and width of 3 - in the actual firmware this is 127/7. The bus clock speed is actually 16MHz to allow a cycle to fit on a line!

## Simple registered fast read
                             A   B   C   D

        clk             _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|

        cyc             ______¯¯¯¯¯¯¯¯__________
        a_stb           ______¯¯¯¯¯¯¯¯__________
        A               XXXXX<========>XXXXXXXXX
        we              XXXXXX00000000XXXXXXXXXX
        D_wr            XXXXXXXXXXXXXXXXXXXXXXXX
        D_wr_stb        XXXXXXXXXXXXXXXXXXXXXXXX

        D_rd            XXXXXXXXXX<======>XXXXXX
        rdy_ctdn        777777777700000000XXXXXX
        ack             __________¯¯¯¯¯¯¯¯______
        nul             ________________________

At:
* A the controller has started the read cycle
* B the peripheral has registered the cycle and instantly returned data asserting ack/rdy_ctdn=0
* C the controller has registered the ack and instanly drops cyc/a_stb 
* D the peripheral deasserts the ack/ctdn signals

Here all signals are registered, this is the simplest way to get timing closure however it is possible 
to reduce the cycle by making rdy_ctdn/ack combinatorial however this is likely to introduces timing
closure difficulties.

## Simple combinatorial super-fast read
                             A   B       

        clk             _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|

        cyc             ______¯¯¯¯______________
        a_stb           ______¯¯¯¯______________
        A               XXXXX<===>XXXXXXXXXXXXXX
        we              XXXXXX0000XXXXXXXXXXXXXX
        D_wr            XXXXXXXXXXXXXXXXXXXXXXXX
        D_wr_stb        XXXXXXXXXXXXXXXXXXXXXXXX

        D_rd            XXXXXXX<==>XXXXXXXXXXXXX
        rdy_ctdn        77777700000XXXXXXXXXXXXX
        ack             _______¯¯¯¯_____________
        nul             ________________________

At:
* A the controller has started the read cycle, the peripheral has tied ack/rdy_ctdn = 0 to ```cyc and a_stb``` combinatorially
* B controller ends cycle 

Here all signals are registered, this is the simplest way to get timing closure however it is possible 
to reduce the cycle by making rdy_ctdn/ack combinatorial however this is likely to introduces timing
closure difficulties.

## Long read cycle (e.g. BBC Motherboard / SYS)

                                         

        clk             _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|

        cyc             __¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯______________
        a_stb           __¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯______________
        A               X<============================>XXXXXXXXXXXXX
        we              XX0000000000000000000000000000XXXXXXXXXXXXXX
        D_wr            XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
        D_wr_stb        XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

        D_rd            XXXXXXXXXXXXXXXXXXXXXXXXXX>===<XXXXXXXXXXXXX
        rdy_ctdn        7777775555444433332222111100000XXXXXXXXXXXXX
        ack             __________________________¯¯¯¯¯_____________
        nul             ____________________________________________

        BBC phi2        ¯________________¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯___________
        BBC A           XXXX>============================<XXXXXXXXXX
        BBC D           XXXXXXXXXXXXXXXXXXXXXXXXXX>======<XXXXXXXXXX

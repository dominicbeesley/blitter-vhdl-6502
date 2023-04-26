New rules:

- d_wr_stb may be asserted after a_stb
- d_wr_stb must be asserted for every we cycle unless cyc is dropped
- d_wr_stb for cycle n - may be asserted after a_stb for n+i - TODO: check, if not then assert stall must *should* be asserted until d_wr_stb?



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

## Pipelining

As of October 2022 the bus specification has been updated to to support the 
concept of pipelining - this allows further transactions to be initiated
at a controller without having to wait for a response for earlier transactions.
In this way, a CPU with a wide (16bit, 32bit) databus can request multiple 
bytes be read or written in a burst shortening bus latency considerably.

# Bus Clock Speed

The bus clock speed for the Fishbone bus is generally much faster than that of the devices attached to 
the bus. The speed is generally chosen to:

* provide enough timing granularity
* not consume excessive power
* allow timing closure

In general the clock speed is 128MHz, as of November 2021 many of the Blitter components are coded to
expect a 128MHz bus.

# Bus signals

Signals annotated (p) have changed to support pipelining - please see the notes in each section.

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
        |             |                            | asserted for the duration of a cycle in a multiple   |
        |             |                            | transaction burst cyc must remain asserted throughout|
        +-------------+----------------------------+------------------------------------------------------+
        | A_stb (p)   | std_logic                  | The A and we signals are valid. The A_stb signal     |
        |             |                            | should be asserted for one clock period for each     |
        |             |                            | address in a burst. The A_stb signal qualifies A and |
        |             |                            | we. If the A_stb signal is asserted for multiple     |
        |             |                            | clock cycles then multiple transactions will occur   |
        |             |                            | **except** when the stall signal is asserted by the  |
        |             |                            | peripheral, in which case the a_stb signal **must**  |
        |             |                            | be repeated!
        +-------------+----------------------------+------------------------------------------------------+
        | A (p)       | std_logic_vector           | The system address that is being requested.          |
        |             | (23 downto 0)              | All peripherals accept a 24 bit address even if they |
        |             |                            | only decode a subset of these addresses. The cyc     |
        |             |                            | and a_stb signals are used to qualify the address.   |
        |             |                            | The address must be registered in devices as it may  |
        |             |                            | change once the A_stb is de-asserted                 |
        +-------------+----------------------------+------------------------------------------------------+
        | we          | std_logic                  | Write Enable. The current cycle will be a write      |
        |             |                            | cycle. This signal must be valid when A_stb is       |
        |             |                            | asserted                                             |
        +-------------+----------------------------+------------------------------------------------------+
        | D_wr        | std_logic_vector           | Write Data. The data to be written in a write cycle  |
        |             | (7 downto 0)               | the write data must be valid when  D_wr_stb is       |
        |             |                            | asserted                                             |
        +-------------+----------------------------+------------------------------------------------------+
        | D_wr_stb (p)| std_logic                  | Write Data Strobe. The D_wr signal is valid.         |
        |             |                            | This may be some time after a cycle has started*.    |
        |             |                            | The d_wr_stb signal must be asserted for the same    |
        |             |                            | clock that the D_Wr signal is valid. There must be   |
        |             |                            | the same number of valid D_wr_stb signals as there   |
        |             |                            | in a burst. See below for a discussion of "valid"    |
        +-------------+----------------------------+------------------------------------------------------+
        | rdy_ctdn (p)| unsigned(<>)               | The number of cycles before "ack" is ready that rdy  |
        |             |                            | should be asserted. Note: this is currently not      |
        |             |                            | expected to change during a cycle and therefore is   |
        |             |                            | not registerd by A_stb                               |
        +-------------+----------------------------+------------------------------------------------------+


### Pipelining notes (p)

In previous incarnations of the spec the A_stb signal was normally asserted with cyc throughout a cycle
and A had to remain stable for the entire cycle after A_stb was asserted. Similarly D_wr had to remain
stable after D_wr_stb had been asserted. 

In pipelined mode the A_stb and D_stb are only asserted for a single cycle during which the peripheral
or interconnect device should register the A/we or D_wr signals. Note: however that the stall signal from
the peripheral/interconnect can be used to stretch these strobes (see below)

### Pipeline Transactions

In the non-pipelined mode there was one transaction per cycle in pipelined mode a cycle can contain multiple
transactions. Usually but not necessarily at consecutive addresses. This is particularly useful when 
interfacing a CPU with a databus width greater than 8 bits.

### Stall

The signal back from the peripheral or interconnect device may be used to indicate to a controller that
the connected peripheral is not yet ready to receive another transaction. The controller should continue
to assert the strobe until the stall line is de-asserted. 

The stall signal *only* stretches the d_wr_stb signal where it is coincident with the cycle whose a_stb
is being stretched i.e. if the d_wr_stb is for a previously pipelined cycle it should not be stretched.

### D_wr_stb notes

The D_wr_stb signal is not always coincident with the a_stb signal in many cases. For instance on a 6502 
hard processor the write data is not ready until some time after the start of the phi2 part of it's cycle.
It may appear that it would be possible, for writes to just delay a_stb until both the address and data to
write are ready but that would mean that a bus transaction would not reach the SYS (motherboard) wrapper
peripheral until far too late in the cycle (it must appear early in phi1) and each cpu write access of the 
motherboard would then skip a cycle. Fishbone's complexity is down, in the main to this problem - the
older asynchronous buses of the CPUs and the BBC's motherboard require the address to be asserted a long
time before the data are available.

### Cyc before A_stb

The cyc signal may be asserted before the first A_stb is ready for a set of grouped transaction. This may
be used in a multi-controller system to request the arbitration logic to make the requesting controller
take precedence before transactions are ready. This should be used sparingly and may be ignored by an 
arbitrator.

## Peripheral to Controller signals

These signals are returned from a peripheral to a controller

        +-------------+----------------------------+------------------------------------------------------+
        | Signal      | VHDL type                  | Description                                          |
        +-------------+----------------------------+------------------------------------------------------+
        | D_rd        | std_logic_vector           | Data returned to a controller from a peripheral in a |
        |             | (7 downto 0)               | read cycle. This data should not be read until the   |
        |             |                            | ack and/or rdy_ctdn=0 is/are asserted                |
        +-------------+----------------------------+------------------------------------------------------+
        | rdy (p)     | unsigned                   | This signal gives an indication of how many fast     |
        |             |                            | clock cycles remain until the data will be ready.    |
        |             |                            | The controller should setup the rdy_ctdn signal to   |
        |             |                            | indicate how many clocks before ack rdy ctdn may be  |
        |             |                            | asserted                                             |             
        +-------------+----------------------------+------------------------------------------------------+
        | ack (p)     | std_logic                  | This signal must be asserted exactly once per        |
        |             |                            | transaction (unless cyc is dropped in which case no  |
        |             |                            | more acks should be generated                        |
        +-------------+----------------------------+------------------------------------------------------+

### rdy / rdy_ctdn (p)

These signals have changed with pipelining, the number of clock cycles remaining until ack would be returned
from the peripheral to the controller. Now the controller indicates how "early" rdy should be asserted.

This signal is used to give an indication of when data will become available for CPUs such as the M68K and 
Z80 which require a DTACK/WAIT signal a significant time ahead of data actually being available. For write 
transactions rdy is usually asserted coincidentally with ack and writes are acknowledged before they are 
actually carried out on slow devices

The rdy signal should be qualified by cyc and ack's must not be generated after cyc has been de-asserted for
a bus transaction

rdy may be active for zero or more cycles before ack 

rdy must be asserted when ack is asserted

rdy must not be asserted for a transaction after that transaction's ack is deasserted


### ack (p)

The ack signal should be asserted once per cycle to indicated that either the read data is valid in D_rd
or that a write has occurred / has been queued.

The ack signal should be qualified by cyc and ack's must not be generated after cyc has been de-asserted for
a bus transaction

ack should be active for exactly one cycle per transaction



# Bus Cycle

A bus cycle may take many clocks to service or may be over in a minimum of 2 clocks. A bus cycle can
be thought of as one or more transactions that take place in a group between a controller and a peripheral.

It may be tempting to continuously assert cyc. Wowever, to do so would be counter-productive in a multi-controller
environment where it could mean that the controller arbitration logic favoured a single controller indefinitely.


# Examples

Note in the following cycles the rdy_ctdn signal has a maximum value of 7 and width of 3 - in the actual firmware this is 127/7. The bus clock speed is actually 16MHz to allow a cycle to fit on a line!

## Simple fast read
                             A   B   C   D

        clk             _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|

        cyc             ______¯¯¯¯¯¯¯¯__________
        a_stb           ______¯¯¯¯______________
        A               ------<A0>--------------
        we              ------____--------------
        D_wr            ------------------------
        D_wr_stb        ------------------------
        rdy_ctdn        ------<  00  >----------

        stall           ________________________
        D_rd            ----------<D0>----------
        rdy             __________¯¯¯¯__________
        ack             __________¯¯¯¯__________

At:
* A the controller starts the read cycle, asserting cyc, a_stb, we, rdy_ctdn, stall is 0 so no stretch is necessary
* B the peripheral registers the cycle and instantly returned data asserting ack/rdy, the peripheral optionally asserts stall
* C the controller has registered the ack and instanly drops cyc
* D the peripheral deasserts the ack/ctdn signals

## Simple fast multibyte read
                             A   B   C   D

        clk             _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|

        cyc             ______¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯__
        a_stb           ______¯¯¯¯¯¯¯¯¯¯¯¯______
        A               ------<A0><A1><A2>------
        we              ------____________------
        D_wr            ------------------------
        D_wr_stb        ------------------------
        rdy_ctdn        ------<    00        >--

        stall           ________________________
        D_rd            ----------<D0><D1><D2>--
        rdy             __________¯¯¯¯¯¯¯¯¯¯¯¯__
        ack             __________¯¯¯¯¯¯¯¯¯¯¯¯__

The peripheral in this case has not asserted stall so that transactions are sent back - to back with no gaps between a_stb's though there could have been if the controller desired

## Simple stalled multibyte read

        clk             _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|

        cyc             ______¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯__
        a_stb           ______¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯______
        A               ------<A0><  A1  ><  A2  >------
        we              ------____________________------
        D_wr            --------------------------------
        D_wr_stb        --------------------------------
        rdy_ctdn        ------<          00          >--

        stall           __________¯¯¯¯____¯¯¯¯____¯¯¯¯__
        D_rd            ----------<D0>----<D1>----<D2>--
        rdy             __________¯¯¯¯____¯¯¯¯____¯¯¯¯__
        ack             __________¯¯¯¯____¯¯¯¯____¯¯¯¯__

Here is the typical case in a multi-byte transaction where a peripheral can only handle a single transaction at a time, it asserts
the stall signal which causes the controller to stretch the a_stb of transactions A1 and A2



## Long read cycle (e.g. BBC Motherboard / SYS)

        clk             _|¯|_|¯|_|¯|_|¯| ~~ _|¯|_|¯|_|¯|_|¯|

        cyc             ______¯¯¯¯¯¯¯¯¯¯ ~~ ¯¯¯¯¯¯¯¯¯¯¯¯¯¯__
        a_stb           ______¯¯¯¯______ ~~ ________________
        A               ------<A0>------ ~~ ----------------
        we              ------____------ ~~ ----------------
        D_wr            ---------------- ~~ ----------------
        D_wr_stb        ---------------- ~~ ----------------
        rdy_ctdn        ------<          ~~  02          >--

        stall           __________¯¯¯¯¯¯ ~~ ¯¯¯¯¯¯¯¯¯¯¯¯¯¯__
        D_rd            ---------------- ~~ ----------<D0>--
        rdy             ________________ ~~ __¯¯¯¯¯¯¯¯¯¯¯¯__
        ack             ________________ ~~ __________¯¯¯¯__


note: rdy_ctdn is 2 meaning rdy is asserted early, SYS knows when the data will be ready.

## Simple fast multibyte write


        clk             _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|

        cyc             ______¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯__
        a_stb           ______¯¯¯¯¯¯¯¯¯¯¯¯______
        A               ------<A0><A1><A2>------
        we              ------____________------
        D_wr            ------<D0><D1><D2>------
        D_wr_stb        ------¯¯¯¯¯¯¯¯¯¯¯¯------
        rdy_ctdn        ------<    00        >--

        stall           ________________________
        D_rd            ------------------------
        rdy             __________¯¯¯¯¯¯¯¯¯¯¯¯__
        ack             __________¯¯¯¯¯¯¯¯¯¯¯¯__


D_wr/d_wr_stb coincident with a_stb, no stall

## Simple stalled multibyte write


        clk             _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|

        cyc             ______¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯__
        a_stb           ______¯¯¯¯¯¯¯¯¯¯¯¯______
        A               ------<A0><  A1  ><  A2  >------
        we              ------____________________------
        D_wr            ------<D0><  D1  ><  D2  >------
        D_wr_stb        ------¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯------
        rdy_ctdn        ------<        00            >--

        stall           __________¯¯¯¯____¯¯¯¯__________
        D_rd            --------------------------------
        rdy             __________¯¯¯¯____¯¯¯¯____¯¯¯¯__
        ack             __________¯¯¯¯____¯¯¯¯____¯¯¯¯__

Note: here the D_wr_stb's are stretched

## Simple stalled multibyte write, D_wr_stb delayed

        clk             _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|

        cyc             ______¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯__
        a_stb           ______¯¯¯¯¯¯¯¯¯¯¯¯______
        A               ------<A0><  A1  ><  A2  >----------
        we              ------____________________----------
        D_wr            ----------<D0>----<D1>----<D2>------
        D_wr_stb        ------____¯¯¯¯____¯¯¯¯____¯¯¯¯------
        rdy_ctdn        ------<          00              >--

        stall           __________¯¯¯¯____¯¯¯¯______________
        D_rd            ------------------------------------
        rdy             ______________¯¯¯¯____¯¯¯¯____¯¯¯¯__
        ack             ______________¯¯¯¯____¯¯¯¯____¯¯¯¯__

Here the D_wr_stb's are not stretched as they are not coincident with their respective a_stb
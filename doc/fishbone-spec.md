New rules 2022:

- d_wr_stb may be asserted after a_stb or coincident with it
- d_wr_stb must be asserted for every we cycle unless cyc is dropped
- to allow ack signals to be generated using registered logic the associated 
  stb should be ignored during the ack and not start a new cycle

Extra rules Oct 2026:

- stall removed
- stall replaced with A_ack
- d_ack added to acknowledge receipt of a D_wr_stb or D_rd is ready
- d_ack must be coincident with or after A_ack
- A_stb is at least two cycles A, we, must remain stabled from the
  first cycle's A_stb to the A_ack back from the peripheral
- rdy_ctdn - should stay constant for the entirety if cyc and need not be
  registered


# Introduction

This documentation describes the bus architecture that is used to connect the 
various devices and sub-systems within the Blitter Board Firmware. This 
specification will be of interest to those wishing to understand the internals
of the Firmware. It is not necessary to understand this specification to use 
the Firmware as a programmer.

It is recommended to have some familiarity with the 
[Wishbone Specification](https://en.wikipedia.org/wiki/Wishbone_(computer_bus))
before reading this document.

The Fishbone bus (loosely inspired by the Wishbone bus) is an FPGA internal
bus system to allow the various components of the blitter chipset to 
communicate within the FPGA. 

The the Fishbone bus is an FPGA targetted bus specification it needs to carry
signals to allow it to be interfaced asynchronous devices and buses. For 
example some CPUs (68k, Z80) require a data ready signal to be asserted some 
time ahead of data being actually ready. To that end the Fishbone bus carries a 
rdy_ctdn signal which indicates in how many clocks data will be available.

## Terminology 

As of 2021 the terms Master/Slave are being phased out and replaced with the 
terms Controller/Peripheral

Master => Controller
Slave => Peripheral

i.e. a CPU is a Controller, Memory would be a Peripheral

## Pipelining

As of October 2022 the bus specification has been updated to to support the 
concept of pipelining - this allows further transactions to be initiated
at a controller without having to wait for a response for earlier transactions.
In this way, a CPU with a wide (16bit, 32bit) databus can request multiple 
bytes be read or written in a burst shortening bus latency considerably.

As of October 2026 the bus specification has been updated to remove stall and
instead have separate A_ack and D_ack signal from the peripheral to the 
controller. These are always registered

# Bus Clock Speed

The bus clock speed for the Fishbone bus is generally much faster than that of 
the devices attached to the bus. The speed is generally chosen to:

* provide enough timing granularity
* not consume excessive power
* allow timing closure

In general the clock speed is 128MHz, as of November 2021 many of the Blitter 
components are coded to expect a 128MHz bus.

# Bus signals

Signals annotated (p) have changed to support pipelining - please see the notes
in each section.

## Syscon Signals

The syscon signals provide system-wide control and clocking signals that keep 
all devices synchronised.

        
        +-------------+----------------------------+------------------------------------------------------+
        | Signal      | VHDL type                  | Description                                          |
        +-------------+----------------------------+------------------------------------------------------+
        | clk         | std_logic                  | The system clock - generally at 128MHz. Other signals|
        |             |                            | are generally registered on the rising_edge of this  |
        |             |                            | clock.                                               |
        |             |                            |                                                      |
        +-------------+----------------------------+------------------------------------------------------+
        | rst         | std_logic                  | System-wide reset signal. This signal is registered  |
        |             |                            | by the clk signal                                    |
        +-------------+----------------------------+------------------------------------------------------+
        | rst_state   | fb_rst_state_t             | Qualifies the reset signal:                          |
        |             |                            | * powerup                                            |
        |             |                            | * reset                                              |
        |             |                            | * resetfull                                          |
        |             |                            | * prerun                                             |
        |             |                            | * run                                                |
        |             |                            | * lockloss                                           |
        +-------------+----------------------------+------------------------------------------------------+
        | prerun      | std_logic_vector           | A one-hot that sequences from 0001 to 1000 during the|
        |             | (3 downto 0)               | prerun state                                         |
        +-------------+----------------------------+------------------------------------------------------+
During reset the different rst_state signals can be used to perform 
different/seqeunced resets depending on the type / stage of the reset.

### rst_state = powerup

This reset type is asserted initially at power-up/fpga reconfiguration before 
any other. It lasts for 10 fast cycles.

### rst_state = reset

This is a normal reset and will follow a powerup reset or be triggered directly
by a user pressing the BREAK key normally.

### rst_state = resetfull

This is a "strong" reset and is triggered by a user holding the BREAK key down
for several seconds it can be used to reset operating conditions that might 
cause a machine to become unusable under fault conditions but that would should
normally survive a reset. For example in the 6809 cpu mode it is possible to 
enter a Flex Mode where the normal Sideways ROM/RAM is disabled. If the system
becomes corrupted a long BREAK can be used to return to the MOS ROM mode.

### rst_state = prerun

This occurs briefly before the run state is entered - this is further 
subdivided by the prerun one-hot.

### rst_state = run

There is no reset asserted

### rst_state = lockloss

The main pll or the BBC Micro System peripheral clock have become unlocked. The
system will hang and the LEDS flash. This state can only be exited by a power-
cycle or by a full reset (holding down BREAK for several seconds).

## Controller to Peripheral sigals

These signals are asserted by a controller to control a bus cycle

        +-------------+----------------------------+------------------------------------------------------+
        | Signal      | VHDL type                  | Description                                          |
        +-------------+----------------------------+------------------------------------------------------+
        | cyc         | std_logic                  | A cycle is being requested. This signal must remain  |
        |             |                            | asserted for the duration of a cycle in a multiple   |
        |             |                            | transaction burst cyc must remain asserted throughout|
        +-------------+----------------------------+------------------------------------------------------+
        | A_stb (p)   | std_logic                  | The A and we signals are valid. A_stb should be      |
        |             |                            | asserted for at least two clock periods for each     |
        |             |                            | address in a burst. The A_stb signal qualifies A and |
        |             |                            | we. The A_stb signal and A and we are held steady    |
        |             |                            | until an A_ack is received from the peripheral.      |
        +-------------+----------------------------+------------------------------------------------------+
        | A (p)       | std_logic_vector           | The system address that is being requested.          |
        |             | (23 downto 0)              | All peripherals accept a 24 bit address even if they |
        |             |                            | only decode a subset of these addresses. The cyc     |
        |             |                            | and a_stb signals are used to qualify the address.   |
        |             |                            | The address must be registered in periphaerals as it |
        |             |                            | wil change once the A_stb is de-asserted             |
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
        |             |                            | the same number of valid D_wr_stb signals as writes  |
        |             |                            | in a burst. See below for a discussion of "valid"    |
        |             |                            | like A_stb above the D_wr_stb is acknowledged by a   |
        |             |                            | peripheral with D_ack. The D_wr_stb and D_wr must be |
        |             |                            | steady during D_wr_stb. A peripheral must ignore     |
        |             |                            | D_wr_stb in the clock after it asserts D_ack: the    |
        |             |                            | strobe still showing then belongs to the write just  |
        |             |                            | acknowledged (see "Stale D_wr_stb hazard" below)     |
        +-------------+----------------------------+------------------------------------------------------+
        | rdy_ctdn (p)| unsigned(<>)               | The number of cycles before "d_ack" that rdy         |
        |             |                            | should be asserted. Note: this is currently not      |
        |             |                            | expected to change during a cycle and therefore is   |
        |             |                            | not registerd by A_stb                               |
        +-------------+----------------------------+------------------------------------------------------+


### Pipelining notes (p)

In previous incarnations of the spec the A_stb signal was normally asserted 
with cyc throughout a cycle and A had to remain stable for the entire cycle 
after A_stb was asserted. Similarly D_wr had to remain stable after D_wr_stb 
had been asserted. 

In pipelined mode the A_stb and D_wr_stb are only asserted until the are acked
by the peripheral or interconnect device should register the A, we or D_wr 
signals. 

### Pipeline Transactions

In the non-pipelined mode there was one transaction per cycle in pipelined mode 
a cycle can contain multiple transactions. Usually but not necessarily at 
consecutive addresses. This is particularly useful when interfacing a CPU with 
a databus width greater than 8 bits.

### Stall (removed)

In the 2022 protcol there was a stall signal back from the peripheral that 
could support back-pressure on a_stb's. This has now changed to a registered
A_ack signal back from the peripheral. This should make timing closure simpler.

### A_ack

This signal replaced the stall signal and acknowledges an A_stb. A_stb, A, we
must be held constant until explicitly acknowledged. This means that A_stb is
at least two cycles long, the first cycle where it is registered by the 
peripheral and the second whilst it is acknowledged - this second cycle is 
usually ignored unless the A_ack is to be delayed.

### D_wr_stb notes

The D_wr_stb signal is not always coincident with the a_stb signal in many 
cases. For instance on a 6502 hard processor the write data is not ready until
some time after the start of the phi2 part of it's cycle. It may appear that it
would be possible, for writes to just delay a_stb until both the address and 
data to write are ready but that would mean that a bus transaction would not 
reach the SYS (motherboard) peripheral until far too late in the cycle 
(it must appear early in phi1) and each cpu write access of the motherboard 
would then skip a cycle. Fishbone's complexity is down, in the main to this 
problem - the older asynchronous buses of the CPUs and the BBC's motherboard 
require the address to be asserted a long time before the data are available.

Write data is supplied in transaction order: the n-th D_wr_stb in a cycle 
carries the data for the n-th write transaction of that cycle. D_wr_stb for a 
write may therefore be asserted after A_stb for later transactions.

A peripheral must only accept D_wr_stb when it has accepted (A_ack'd, or is 
currently A_ack'ing) a write transaction whose data it has not yet received. 
At all other times it must ignore D_wr_stb.

Guard cycle: a peripheral must also ignore D_wr_stb in the clock after it 
has asserted D_ack, whether that D_ack was for a read or a write. D_ack is 
registered, so the controller only sees it at the end of that clock, and a 
D_wr_stb showing during it may still be the strobe (and data) of the write 
that has just been acknowledged. It is simpler to always skip this clock 
than to work out whether the strobe is stale, and it costs at most one 
clock. See "Stale D_wr_stb hazard" below.

Note: this allows an interconnect to present a D_wr_stb to a peripheral that 
has only reads outstanding, while the write it belongs to is still waiting 
for A_ack from a different peripheral. The controller holds D_wr_stb until it 
is D_ack'd, so the correct peripheral receives it once the write has been 
A_ack'd.

### Cyc before A_stb

The cyc signal may be asserted before the first A_stb is ready for a set of 
grouped transaction. This may be used in a multi-controller system to request 
the arbitration logic to make the requesting controller take precedence before
transactions are ready. This should be used sparingly and may be ignored by an 
arbitrator.

Cyc may be dropped at any point to abort any outstanding transactions.

## Peripheral to Controller signals

These signals are returned from a peripheral to a controller

        +-------------+----------------------------+------------------------------------------------------+
        | Signal      | VHDL type                  | Description                                          |
        +-------------+----------------------------+------------------------------------------------------+
        | A_ack       | std_logic                  | Acknowledge the receipt of A, we from the controller.|
        +-------------+----------------------------+------------------------------------------------------+
        | D_rd        | std_logic_vector           | Data returned to a controller from a peripheral in a |
        |             | (7 downto 0)               | read cycle. This data should not be read until the   |
        |             |                            | ack and/or rdy_ctdn=0 is/are asserted                |
        +-------------+----------------------------+------------------------------------------------------+
        | D_ack       | std_logic                  | Acknowledge the receipt of D_wr_stb, for writes or   |
        |             |                            | signal that D_rd is now valid for reads.             |        
        +-------------+----------------------------+------------------------------------------------------+
        | rdy (p)     | std_logic                  | Signals that data "will be" ready in rdy_ctdn cycles |
        |             |                            | this is used for CPUs such as the Z80 / 68000 that   |
        |             |                            | need to be signaled a head of time that data will be |
        |             |                            | available, for writes this is just generally asserted| 
        |             |                            | as D_wr_stb is. Ready should not be asserted before  |
        |             |                            | A_stb by a peripheral                                |
        +-------------+----------------------------+------------------------------------------------------+

### rdy / rdy_ctdn (p)

These signals have changed with pipelining, the number of clock cycles 
remaining until ack would be returned from the peripheral to the controller. 
Now the controller indicates how "early" rdy should be asserted.

This signal is used to give an indication of when data will become available 
for CPUs such as the M68K and Z80 which require a DTACK/WAIT signal a 
significant time ahead of data actually being available. For write transactions 
rdy is usually asserted coincidentally with ack and writes are acknowledged 
before they are actually carried out on slow devices

The rdy signal should be qualified by cyc and D_Ack must not be generated after
cyc has been de-asserted for a bus transaction

rdy may be active for zero or more cycles before D_ack 

rdy must be asserted when ack is asserted

rdy must not be asserted for a transaction after that transaction's ack is 
deasserted

Controllers that issue multiple transactions are responsible for counting them
and only responding to the final rdy if for instance a 32-bit CPU needs 4
bytes.

For many peripherals the rdy signal is a copy of the D_ack signal. Where the 
peripheral responds rapidly in a few cycles this is of no concern but for
slow devices (such as the SYS wrapper) it can severely reduce performance 
where an early RDY/WAIT/DTACK signal needs to be generated.

### D_ack (p)

The ack signal should be asserted once per transaction to indicated that either
the read data is valid in D_rd or that a write has occurred / has been queued.

The ack signal should be qualified by cyc and D_ack's must not be generated 
after cyc has been de-asserted for a bus transaction

D_ack should be active for exactly one cycle per transaction

D_ack may be asserted coincident with A_ack at the earliest (so long as 
D_wr_stb has been received for writes or D_rd is ready).

D_acks for successive transactions may be asserted on consecutive clocks,
for example when a pipelined peripheral returns queued data. Controllers
and interconnects must therefore count each clock in which D_ack is
asserted as one transaction, rather than looking for a rising edge. The
same applies to rdy, which may stay asserted across the consecutive
D_acks.

A peripheral must not generate the D_ack for a write from a D_wr_stb it 
sampled in its guard cycle, i.e. the clock after its previous D_ack (see 
"D_wr_stb notes" and "Stale D_wr_stb hazard"). This catches out blocking 
peripherals in particular, as the next write's A_stb is usually already 
waiting when they give a D_ack.

### Stale D_wr_stb hazard

A_stb and D_wr_stb are held by the controller until they are acknowledged, 
and A_ack and D_ack are registered. So in the clock after a peripheral 
asserts an ack, the controller has not yet seen it, and the strobe the 
peripheral samples is still the one it has just acknowledged. For A_stb this 
is covered by the A_ack rule (the second clock of A_stb is ignored); for 
D_wr_stb it is covered by the guard cycle.

The example below shows a blocking peripheral without the guard cycle, and 
a controller that issues the next write's A_stb as soon as the previous one 
is A_ack'd. Both writes have late data. Each column is the value the 
peripheral samples at that clock edge:

        sampled at edge       e1   e2   e3   e4   e5   e6   e7   e8
        ---------------------------------------------------------------
        A_stb                  1    1    1    1    1    1    0    0
        A                      W1   W1   W2   W2   W2   W2   -    -
        we                     1    1    1    1    1    1    -    -
        D_wr_stb               0    0    0    1    1    0    0    1
        D_wr                   -    -    -    D1   D1   -    -    D2
        ---------------------------------------------------------------
        A_ack (peripheral)     0    1    0    0    0    1    0    0
        D_ack (peripheral)     0    0    0    0    1    1*   0    0

At:
* e1 the peripheral accepts W1 and waits for its data
* e2 the controller sees A_ack and presents W2, which the peripheral holds
  off while it waits for W1's data
* e4 W1's data arrives and the peripheral asserts D_ack
* e5 the controller only now sees D_ack, so D_wr_stb is still asserted with
  D1. The peripheral is free again and W2 is waiting with we='1'. Without
  the guard cycle the peripheral takes D1 as W2's data and D_acks W2 (*)
* e6 the controller sees a D_ack for W2 before it has presented W2's data
* e8 the controller presents D2, which is never acknowledged: the bus
  hangs, and a memory would have written D1 to W2's address

With the guard cycle the peripheral ignores D_wr_stb at e5, A_acks W2 and 
waits for its data, and D_acks W2 when it samples D2 at e8.

Being non-pipelined does not protect a peripheral: it is the controller (or 
an interconnect) issuing the next A_stb early that sets this up, and a 
blocking peripheral releases the waiting A_stb in exactly the guard cycle.

The guard cycle never delays a write whose D_wr_stb follows the D_ack of 
the previous write, as the controller cannot present the next strobe until 
it has seen that D_ack. It only costs a clock when a write's D_wr_stb is 
already waiting behind the D_ack of a read.

# Bus Cycle

A bus cycle may take many clocks to service or may be over in a minimum of 2 
clocks. A bus cycle can be thought of as one or more transactions that take 
place in a group between a controller and a peripheral.

It may be tempting to continuously assert cyc. Wowever, to do so would be 
counter-productive in a multi-controller environment where it could mean that 
the controller arbitration logic favoured a single controller indefinitely.

# Pipelined

For a bus cycle to be truly pipelined the controller, peripheral and any 
intermediate interconnect devices should be pipelined. In general most devices
aren't pipelined which doesn't matter if they return data quickly or are 
infrequently used. The main purpose of pipelining in the supported systems is
for the 32- and 16-bit processors supported on the Mk.3 Blitter.

# Examples

Note in the following cycles the rdy_ctdn signal has a maximum value of 7 and 
width of 3 - in the actual firmware this is 127/7. The bus clock speed is 
actually 16MHz rather than 128MHz to allow a cycle to fit on a line!

## Simple fast read
                             A   B   C   D

        clk             _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|

        cyc             ______¯¯¯¯¯¯¯¯__________
        a_stb           ______¯¯¯¯¯¯¯¯__________
        A               ------<A0    >----------
        we              ------________----------
        D_wr            ------------------------
        D_wr_stb        ------------------------
        rdy_ctdn        ------<  00  >----------

        A_ack           __________¯¯¯¯__________
        D_rd            ----------<D0>----------
        rdy             __________¯¯¯¯__________
        D_ack           __________¯¯¯¯__________

At:
* A the controller starts the read cycle, asserting cyc, a_stb, we, rdy_ctdn
* B the peripheral registers the cycle, asserts A_ack and instantly returns 
  data asserting D_ack and rdy
* C the controller has registered the D_ack and instanly drops cyc and the 
  peripheral deasserts the ack/ctdn signals

## Simple fast multibyte read
                             A   B   C   D

        clk             _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|

        cyc             ______¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯______
        a_stb           ______¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯______
        A               ------<A0    ><A1    ><A2    >------
        we              ------________________________------
        D_wr            ------------------------------------
        D_wr_stb        ------------------------------------
        rdy_ctdn        ------<            00        >------

        A_ack           __________¯¯¯¯____¯¯¯¯____¯¯¯¯______
        D_rd            ----------<D0>----<D1>----<D2>------
        rdy             __________¯¯¯¯____¯¯¯¯____¯¯¯¯______
        D_ack           __________¯¯¯¯____¯¯¯¯____¯¯¯¯______

The peripheral in this case has immediately asserted A_ack, rdy and D_ack so 
the data is read out one byte per 2 clocks which is the fastest bus bandwidth
supported

## Simple stalled pipelined multibyte read

        clk             _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|

        cyc             ______¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯______
        a_stb           ______¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯______________
        A               ------<A0    ><  A1      ><  A2      >--------------
        we              ------____________________________------------------
        D_wr            ----------------------------------------------------
        D_wr_stb        ----------------------------------------------------
        rdy_ctdn        ------<          01                  >--------------

        A_ack           __________¯¯¯¯________¯¯¯¯________¯¯¯¯______________
        D_rd            ------------------<D0>--------<D1>--------<D2>------
        rdy             ______________¯¯¯¯¯¯¯¯____¯¯¯¯¯¯¯¯____¯¯¯¯¯¯¯¯______
        D_ack           __________________¯¯¯¯________¯¯¯¯________¯¯¯¯______

Here is the typical case in a multi-byte transaction where a peripheral can 
only handle a single transaction at a time, it doesn't assert the A_ack signal 
until it has completed the previous cycle which causes the controller to 
stretch the a_stb of transactions A1 and A2



## Long read cycle (e.g. BBC Motherboard / SYS)

        clk             _|¯|_|¯|_|¯|_|¯| ~~ _|¯|_|¯|_|¯|_|¯|_|¯|

        cyc             ______¯¯¯¯¯¯¯¯¯¯¯¯¯¯ ~~ ¯¯¯¯¯¯¯¯¯¯______
        a_stb           ______¯¯¯¯¯¯¯¯______ ~~ ________________
        A               ------<A0    >------ ~~ ----------------
        we              ------________------ ~~ ----------------
        D_wr            -------------------- ~~ ----------------
        D_wr_stb        -------------------- ~~ ----------------
        rdy_ctdn        ------<              ~~  02      >--

        A_ack           __________¯¯¯¯__ ~~ ____________________
        D_rd            ---------------- ~~ ----------<D0>------
        rdy             ________________ ~~ __¯¯¯¯¯¯¯¯¯¯¯¯______
        D_ack           ________________ ~~ __________¯¯¯¯______


note: rdy_ctdn is 2 meaning rdy is asserted early, the SYS peripheral knows 
when the data will be ready.

## Simple fast multibyte write

        clk             _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|

        cyc             ______¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯__________
        a_stb           ______¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯__________
        A               ------<A0    ><A1    ><A2    >----------
        we              ------________________________----------
        D_wr            ------<D0    ><D1    ><D2    >----------
        D_wr_stb        ------¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯----------
        rdy_ctdn        ------<            00        >----------

        A_ack           __________¯¯¯¯____¯¯¯¯____¯¯¯¯__________
        D_rd            ------------------------
        rdy             __________¯¯¯¯____¯¯¯¯____¯¯¯¯__________
        D_ack           __________¯¯¯¯____¯¯¯¯____¯¯¯¯__________


D_wr/d_wr_stb coincident with a_stb, A_ack, D_ack, rdy ASAP  

## Simple stalled/pipe-lined multibyte write with delayed D_wr_stb


        clk             _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|

        cyc             ______¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯__________________
        a_stb           ______¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯__________________
        A               ------<A0    ><A1            >------------------
        we              ------________________________------------------
        D_wr            --------------<D0    >------------<D1    >------
        D_wr_stb        --------------¯¯¯¯¯¯¯¯------------¯¯¯¯¯¯¯¯------
        rdy_ctdn        ------<            02        >------------------

        A_ack           __________¯¯¯¯____________¯¯¯¯__________________
        D_rd            ------------------------
        rdy             __________________¯¯¯¯________________¯¯¯¯______
        D_ack           __________________¯¯¯¯________________¯¯¯¯______


Note: this shows overlapped writes
not rdy_ctdn is ignored for writes and rdy is coincident with D_ack

# Code style

The following conventions are used in the Fishbone VHDL in this repository.

## Naming

From Oct 2026 use the following naming conventions. Old code may use older
conventions but should be updated where convenient.

        +--------------------+----------------------------------------------------------+
        | Pattern            | Meaning                                                  |
        +--------------------+----------------------------------------------------------+
        | fb_syscon_i        | Syscon record (fb_syscon_t)                              |
        +--------------------+----------------------------------------------------------+
        | fb_up_*            | Fishbone record ports facing the controller (the block   |
        |                    | acts as a peripheral there)                              |
        +--------------------+----------------------------------------------------------+
        | fb_dn_*            | Fishbone record ports facing the peripheral(s) (the      |
        |                    | block acts as a controller there)                        |
        +--------------------+----------------------------------------------------------+
        | *_c2p_*            | Controller to peripheral record (fb_con_o_per_i_t/_arr)  |
        +--------------------+----------------------------------------------------------+
        | *_p2c_*            | Peripheral to controller record (fb_con_i_per_o_t/_arr)  |
        +--------------------+----------------------------------------------------------+
        | peripheral_sel_*   | Ports to an external address decoder, see                |
        |                    | fb_intcon_pack.vhd                                       |
        +--------------------+----------------------------------------------------------+
        | *_i / *_o / *_io   | Port direction in / out / inout                          |
        +--------------------+----------------------------------------------------------+
        | i_*                | Internal combinatorial signal                            |
        +--------------------+----------------------------------------------------------+
        | r_*                | Register                                                 |
        +--------------------+----------------------------------------------------------+
        | v_*                | Process variable, assigned before use in each pass of    |
        |                    | the process (combinatorial)                              |
        +--------------------+----------------------------------------------------------+
        | vr_*               | Process variable whose value is kept and used in the     |
        |                    | next pass of the process (implemented as a register)     |
        +--------------------+----------------------------------------------------------+
        | G_*                | Generics, in upper case e.g. G_PERIPHERAL_COUNT          |
        +--------------------+----------------------------------------------------------+
        | C_*                | Immutable local constants                                |
        +--------------------+----------------------------------------------------------+

For example an interconnect has ports fb_up_c2p_i, fb_up_p2c_o, fb_dn_c2p_o 
and fb_dn_p2c_i.

Use the terms Controller/Peripheral, not Master/Slave.

Note: in the Blitter and C20k projects G_ has also been used (confusingly) for
global definitions coming from packages.

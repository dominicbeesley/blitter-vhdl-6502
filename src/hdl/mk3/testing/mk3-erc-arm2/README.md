# mk3-board-erc

This project can be used to buzz out a mk.3 board arm2 CPU expansion board

No CPU or other expansion (SD/HDMI/etc) should be fitted. The board should NOT be plugged into a machine's CPU socket and should be powered via the AUX connector. The arm2 expansion board should be fitted with no jumpers set and no CPU fitted


Input / output lines are set as outputs and each line continuously outputs a 4 character code to identify it. This can be used to check soldering.

* Bridged/shorted lines will output incorrect/low levels or garbled text
* High impedance/partially soldered lines should be loaded with ca. 1k resistor to ground and tested for level.

The lines should be tested at the CPU sockey pins

The 5432 latches are exercised by:
- D0-31 are output in 4 banks to PORTA and the Bl0-3 lines set in accordance
- the correct D0-D31 strings should be output on each of the data lines but there will be a 15 character gap between them


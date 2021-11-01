# mk3-board-erc

This project can be used to buzz out a mk.3 board. 

No CPU or other expansion (SD/HDMI/etc) should be fitted.

Input / output lines are set as outputs and each line continuously outputs a 4 character code to identify it. This can be used to check soldering.

* Bridged/shorted lines will output incorrect/low levels or garbled text
* High impedance/partially soldered lines should be loaded with ca. 1k resistor to ground and tested for level.




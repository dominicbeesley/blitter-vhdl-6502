# blitter-vhdl-6502

The "Blitter board" is a series of board for the Acorn 8-bit Microcomputers. These
boards are used to replace the CPU in an Acorn 8-bit computer such as the BBC Micro,
Electron or Master. 

As well as replacing the CPU the boards provide a set of enhancements to the machine:
- A blitter - a co-processor which can plot graphics to screen memory very quickly - roughly modelled on the Amiga's Blitter (Agnus)
- A sound chip - an enhanced sound card which provides 4 or more 8 bit PCM channels - roughly modelled on the Amiga's Paula sound chip
- A raster chaser - "Aeris" a co-processor which can update hardware registers at various points on the screen during screen scanning - analogous to but quite different to the Amiga's Copper
- Memory expansion:
	- Full Sideways ROM/RAM in various configurations (Flash EEPROM, Fast RAM, Battery Backed RAM)
	- Page-Wide expansion
	- For 16/32 bit CPUs a linear address space
- Soft or Hard CPUs with separate configurations
- Alternative CPU's. The main CPU can be replaced with either an FPGA IPCore CPU (T65) or with a plug-in cpu

# Further reading

*	[Wiki](https://github.com/dominicbeesley/blitter-vhdl-6502/wiki)
*	[Hardware Overview](doc/hardware-overview-mk3.md)
*	[Paula Chipset Hardware QuickStart](doc/sound.md)
*	[Blitter Support ROM](https://github.com/dominicbeesley/blitter-support-rom)

# Project Structure

	doc						Documentation
	src						Code
	  hdl						VHDL/Verilog projects and libraries
	    chipset					The Chipset (Blitter/Paula/Aeris/DMA etc) (used various revisions of board)
	    library					Shared by many projects
	      3rdparty					Code from other projects
	        T6502					The T65 core
	      fishbone					The Fishbone Bus basic components and definitions
	    mk3						Projects and files relevant to the Mk.3 board
	      testing					Projects for board testing and production
	        mk3-board-erc				A simple Project to perform board ERC  
	        mk3-erc-68000				Perform ERC on a 68000 plug-in cpu board
	      shared					HDL shared between all mk.3 builds
	      boards					contains individual builds
	      	cpu-16-max				MAX10 16000LE build with all options except HDMI
	      	

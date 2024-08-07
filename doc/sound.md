
### Paula SOUND chipset

Rough notes on accessing the Paula chipset hardware direct

~~~~
JIM Dev no: &D0 (Paula) &D1 (Blitter/cpu)
JIM Base address: $FE FC80 (Big Endian)
JIM Base address: $FE FE80 (Little Endian) - only on builds after Aug '24
~~~~

The Dossytronics CPU/Blitter and 1M Paula cards both use new jim space API for
access to both the on board ram  and the device registers. This saves on using
precious FRED space for the device registers.

For full details of the updated JIM spec please see [JIM spec](https://raw.githubusercontent.com/dominicbeesley/DataCentre/master/jim-spec-2019.txt)

The Hoglet/1M Paula card has 512Kb (and the Blitter 2Mb) of memory accessed 
through the JIM page-wide system. First the relevant device number should be
written to &FCFF (D0 for Paula D1 for Blitter/cpu). 

The chip memory for sample data* can then be paged into the FD00-FDFF slot by
using the paging registers at &FCFD (most significant) and &FCFE 
(least significant).

* on the blitter/cpu card system memory can also be used for samples though this 
is not recommended due to the fact that it will slow the system down more.

The registers for the sound chipset are accessed also through JIM by accessing 
the address space range at $FE FE80-FE8F in jim memory i.e. to write the 
channel select register in BASIC the following sequence should be used.

\[Note: the registers in this document are suitable for use on a little-endian
BASIC (6502, z80, etc) on big-endian systems you should substitute the registers
as appropriate\]

~~~~
10DEVNO=&D1:?&EE=DEVNO:?&FCFF=DEVNO:REM - access device and set shadow register
20?&FCFE=&FE:?&FCFD=&FE: REM - set jim page to $FE FExx - little endian
30?&FD8F=0: REM - select channel 0
~~~~

The sound processor appears as a 4 channel PCM + mixer device, loosely modelled
on the Amiga's Paula chip.

Each channel can be set to output a static value by setting its data register
(complex generated sounds can be generated by setting this register in a tight
loop) or can be programmed to play a sound sample from memory using DMA 
techniques


*Big Endian Register Addresses*
~~~
  Address       Purpose
  -------       -------
  FE FC80       Unused as of Aug '24
  FE FC81..3    Source base address (big endian 24 bit address)
  FE FC84..5    Sample "period" - see below
  FE FC86..7    Length - 1
  FE FC88       Status/Control
  FE FC89       Volume 
  FE FC8A..B    Repeat offset
  FE FC8C       Peak 
  FE FC8D       Read/Write current sample value
  FE FC8E       Overall volume control
  FE FC8F       Channel select
~~~

*Little Endian Register Addresses*
~~~
  Address       Purpose
  -------       -------
  FE FE80       Channel select
  FE FE81       Overall volume
  FE FE82       Read/Write current sample value
  FE FE83       Peak 
  FE FE84..5    Repeat offset
  FE FE86       Volume 
  FE FE87       Status/Control
  FE FE88..9    Length - 1
  FE FE8A..B    Sample "period" - see below
  FE FE8C..E    Source base address (big endian 24 bit address)
  FE FE8F       Unused
~~~


*Control register bits*
~~~
  7   -   ACT : (set this bit to 1 to initiate/test for completion)
  6   -   n/a
  5   -   n/a
  4   -   n/a
  3   -   n/a
  2   -   n/a
  1   -   n/a
  0   -   RPT  : Repeat

  [All n/a bits should be set to 0 on write, expect non-zero on read back]

  ACT, setting this bit will initiate playing a sample using DMA
  RPT, setting this bit will cause the sample to repeat, the sample will
       be repeated beginning at the offset in BASE+10/11
~~~~

*Channel select register*

The current 4-channel firmware only uses bits 1..0 you should leave the other
bits set to 0 except that you may set the channel select register to FF to
probe how many channels are available. The number available may then be read
back. Other writes with bits 7..2 set are reserved.

*Sample clock*

The clock for playing samples is a nominal 3,546,895Hz (as on a PAL Amiga). 
The "period" describes the number of PAL clocks that should pass between each
sample being loaded (via DMA)

For example, this program sets up a sample of 32 bytes length in chip RAM
and sets channel 0 to repeatedly play the sound

~~~~
   10 REM BLIT SOUND
   20 DEVNO%=&D1 : REM JIM device number for Blitter 
   30 snd%=&FD80:sndjim%=&FEFE:sambase%=&020000
   40 SL%=32:SR%=1000:SP%=3546895/(SR%*SL%):REM calculate period
   50 BUF%=&FD00:
   60 ?&EE=DEVNO%:?&FCFF=DEVNO%:REM enable JIM for 1m board
   70 ?&FCFD=sambase% DIV &10000:?&FCFE=sambase% DIV &100:REM set jim base addr to sample (assume page aligned)
   80 FORI%=0TOSL%-1:BUF%?I%=120*SIN(2*PI*I%/SL%):NEXT:REM sinewave in JIM
   85 REM JIM to point at sound device area
   86 ?&FCFD=sndjim% DIV 256:?&FCFE=sndjim%
   90 snd%?&0=0:snd%?&1=255:REM cha=0,master vol=255
  100 snd%!&C=sambase%
  110 snd%?&A=SP%:snd%?&B=SP%DIV&100:REM sound "period"
  120 snd%?&8=SL%-1:snd%?&9=(SL%-1)DIV&100:REM sample len-1
  130 snd%?&6=255:REM channel vol max
  140 snd%?&4=0:snd%?&5=0:REM repeat from start of sample
  150 snd%?&7=&81:REM play, repeat
~~~~

~~~~
Line 20..30 : set hardware parameters, for blitter change devno to &D1
Line 40:      calulate SP, number of 3.5ish MHz ticks to make a 32 sample 
              play at 1kHz
Line 60:      set dev no and shadow register (if you don't set this other 
              hardware drivers might interfere) and device select register
Line 70:      point at chip RAM at $010000 - it's best to avoid the 1st 64K
              as this is used by the CPU/blitter card for shadow memory and
              other utility functions
Line 80:      generate the sinewave into chip RAM
Line 86:      point the JIM page at $FE FCxx in the device's space where the
              hardware registers reside
Lines 90-150: Set up the hardware registers to play the sample
~~~~

To stop a sound playing it is a simple of matter of selecting the channel and
setting the control register to 0

~~~~
  200 REM stop sound
  210 snd%?&F=0:REM select channel 0
  100 snd%?&8=0:REM stop
~~~~

For information on using the high-level API for playing sounds please see
the document [SoundQuickstart.md](https://github.com/dominicbeesley/blitter-65xx-code/blob/main/doc/SoundQuickstart.md) 
in the 6502 support software repository.
# heavily edite version of https://github.com/mfischer/Altera-Makefile

###################################################################
# Project Configuration: 
# 
# Specify the name of the design (project) and the Quartus II
# Settings File (.qsf)
###################################################################

PROJECT = mk3_16_tiny
SCRIPTS = ../../../../scripts

###################################################################
# Main Targets
#
# all: build everything
# clean: remove output files and database
# program: program your device with the compiled design
###################################################################

all:: output_files/$(PROJECT).asm.rpt

clean:
	rm -rf *.rpt *.chg smart.log *.htm *.eqn *.pin *.pof db incremental_db
	rm output_files/mk2blit.sof
	rm output_files/mk2blit.pof


map: $(PROJECT).map.rpt
fit: $(PROJECT).fit.rpt
asm: $(PROJECT).asm.rpt
sta: $(PROJECT).sta.rpt

###################################################################
# Executable Configuration
###################################################################

MAP_ARGS = --read_settings_files=on

FIT_ARGS = --read_settings_files=on
ASM_ARGS =

###################################################################
# Target implementations
###################################################################

STAMP = echo done >

version.vhd: $(SCRIPTS)/tcl/get-version.tcl
	quartus_sh -t $(SCRIPTS)/tcl/get-version.tcl


output_files/$(PROJECT).map.rpt fit.chg: $(PROJECT).qsf 
	quartus_map $(MAP_ARGS) $(PROJECT)
	$(STAMP) fit.chg

output_files/$(PROJECT).fit.rpt asm.chg: $(PROJECT).qsf output_files/$(PROJECT).map.rpt fit.chg
	quartus_fit $(FIT_ARGS) $(PROJECT)
	$(STAMP) asm.chg

output_files/$(PROJECT).sof output_files/$(PROJECT).asm.rpt: $(PROJECT).qsf output_files/$(PROJECT).fit.rpt asm.chg
	quartus_asm $(ASM_ARGS) $(PROJECT)
	{ if [ -e version.tag ]; then cat version.tag; fi ; date +'_%Y%m%d_%H%M%S'; } | tr -d "\r\n" | tr ":" "_" > output_files/$(PROJECT).sof.ver
	cp output_files/$(PROJECT).sof output_files/$(PROJECT).$$(cat output_files/$(PROJECT).sof.ver).sof


###################################################################
# Programming the device
###################################################################

program: output_files/$(PROJECT).sof reprogram

reprogram:
	quartus_pgm --no_banner --mode=jtag -o "P;output_files/$(PROJECT).sof"

program-pof: $(PROJECT).pof
	quartus_pgm --no_banner --mode=jtag -o "BVP;$(PROJECT).pof"

program-perm:: output_files/$(PROJECT).pof
	quartus_pgm --no_banner --mode=jtag -o "P;output_files/$(PROJECT).pof"

output_files/$(PROJECT).pof: output_files/$(PROJECT).sof	
	quartus_cpf -c $(PROJECT).cof
	cp output_files/$(PROJECT).pof output_files/$(PROJECT).$$(cat output_files/$(PROJECT).sof.ver).pof



###################################################################
# Crude attempt at automatic dependencies
###################################################################


Makefile.deps: $(PROJECT).qsf
	perl $(SCRIPTS)/perl/getdeps.pl output_files/$(PROJECT).map.rpt VHDL_FILE QIP_FILE < $(PROJECT).qsf > Makefile.deps
	perl $(SCRIPTS)/perl/getdeps.pl output_files/$(PROJECT).fit.rpt SDC_FILE < $(PROJECT).qsf >> Makefile.deps
	perl $(SCRIPTS)/perl/getdeps.pl version.vhd VHDL_FILE QIP_FILE < $(PROJECT).qsf >> Makefile.deps

include Makefile.deps
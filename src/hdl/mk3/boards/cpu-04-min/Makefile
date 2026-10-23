# heavily edited version of https://github.com/mfischer/Altera-Makefile

	QUARTUS_SH=quartus_sh.exe
	QUARTUS_MAP=quartus_map.exe
	QUARTUS_FIT=quartus_fit.exe
	QUARTUS_ASM=quartus_asm.exe
	QUARTUS_PGM=quartus_pgm.exe
	QUARTUS_CPF=quartus_cpf.exe
	QUARTUS_STA=quartus_sta.exe


###################################################################
# Project Configuration: 
# 
# Specify the name of the design (project) and the Quartus II
# Settings File (.qsf)
###################################################################

PROJECT = mk3_04_min
SCRIPTS = ../../../../scripts

.PHONY: timing all program program-perm reprogram

###################################################################
# Main Targets
#
# all: build everything
# clean: remove output files and database
# program: program your device with the compiled design
###################################################################

all:: output_files/$(PROJECT).asm.rpt Makefile.deps timing

clean:
	-rm -rf *.rpt *.chg smart.log *.htm *.eqn *.pin *.pof db incremental_db
	-rm output_files/$(PROJECT).sof
	-rm output_files/$(PROJECT).pof
	-rm version.tag version.vhd version.tmp


map: $(PROJECT).map.rpt
fit: $(PROJECT).fit.rpt
asm: $(PROJECT).asm.rpt
sta: $(PROJECT).sta.rpt

###################################################################
# Executable Configuration
###################################################################

# --write_settings_files=off: by default each Quartus tool rewrites the .qsf
# (expanding the "source"d pin and simulation files into it). That makes the
# .qsf newer than map.rpt, so the next make reran everything from quartus_map.
MAP_ARGS = --read_settings_files=on --write_settings_files=off

FIT_ARGS = --read_settings_files=on --write_settings_files=off
ASM_ARGS = --write_settings_files=off

###################################################################
# Target implementations
###################################################################

STAMP = echo done >

version.vhd: $(SCRIPTS)/tcl/get-version.tcl
	$(QUARTUS_SH) -t $(SCRIPTS)/tcl/get-version.tcl


output_files/$(PROJECT).map.rpt fit.chg: $(PROJECT).qsf 
	$(QUARTUS_MAP) $(MAP_ARGS) $(PROJECT)
	$(STAMP) fit.chg

output_files/$(PROJECT).fit.rpt asm.chg: $(PROJECT).qsf output_files/$(PROJECT).map.rpt fit.chg
	$(QUARTUS_FIT) $(FIT_ARGS) $(PROJECT)
	$(STAMP) asm.chg

output_files/$(PROJECT).sof output_files/$(PROJECT).asm.rpt: $(PROJECT).qsf output_files/$(PROJECT).fit.rpt asm.chg
	$(QUARTUS_ASM) $(ASM_ARGS) $(PROJECT)
	{ if [ -e version.tag ]; then cat version.tag; fi ; date +'_%Y%m%d_%H%M%S'; } | tr -d "\r\n" | tr ":" "_" > output_files/$(PROJECT).sof.ver
	cp output_files/$(PROJECT).sof output_files/$(PROJECT).$$(cat output_files/$(PROJECT).sof.ver).sof


###################################################################
# Timing check (all corners) - reports pass/fail, doesn't stop the build
###################################################################

output_files/$(PROJECT).sta.summary: output_files/$(PROJECT).fit.rpt
	$(QUARTUS_STA) $(PROJECT) --multicorner=on

# any negative slack in the summary (setup, hold, recovery, removal, pulse
# width, every corner) is a fail. timing_fail.txt lists the failing summary
# lines (empty = pass) and timing_paths.txt the worst failing paths (only
# worked out on a fail). Both are files, so they're only redone after a new
# timing analysis; the "timing" target prints them every time it's made.
output_files/timing_fail.txt: output_files/$(PROJECT).sta.summary
	awk '/^Type/ {t=$$0} /^Slack/ {if ($$3+0 < 0) print t "  slack " $$3}' $< > $@

output_files/timing_paths.txt: output_files/timing_fail.txt
	if [ -s $< ]; then \
		$(QUARTUS_STA) -t $(SCRIPTS)/tcl/sta-fail-paths.tcl $(PROJECT) $@ > /dev/null; \
	else \
		: > $@; \
	fi

timing: output_files/timing_paths.txt
	@if [ -s output_files/timing_fail.txt ]; then \
		printf '\033[1;31m*** TIMING FAILED ***\033[0m\n'; \
		printf '\033[31m'; cat output_files/timing_fail.txt; printf '\033[0m'; \
		printf '\033[31m'; cat output_files/timing_paths.txt; printf '\033[0m\n'; \
	else \
		printf '\033[1;34m*** Timing passed, all corners ***\033[0m\n'; \
	fi

###################################################################
# Programming the device
###################################################################

program: output_files/$(PROJECT).sof timing reprogram

reprogram:
	$(QUARTUS_PGM) --no_banner --mode=jtag -o "P;output_files/$(PROJECT).sof"

program-perm: output_files/$(PROJECT).pof
	$(QUARTUS_PGM) --no_banner --mode=jtag -o "BVP;output_files/$(PROJECT).pof"

#program-perm:: output_files/$(PROJECT).jic
#	$(QUARTUS_PGM) --no_banner --mode=jtag -o "IP;output_files/$(PROJECT).jic"

output_files/$(PROJECT).pof: output_files/$(PROJECT).sof	
	$(QUARTUS_CPF) -c $(PROJECT).cof
	cp output_files/$(PROJECT).pof output_files/$(PROJECT).$$(cat output_files/$(PROJECT).sof.ver).pof



###################################################################
# Crude attempt at automatic dependencies
###################################################################


Makefile.deps: $(PROJECT).qsf
	perl $(SCRIPTS)/perl/getdeps.pl output_files/$(PROJECT).map.rpt VHDL_FILE QIP_FILE < $(PROJECT).qsf > Makefile.deps
	perl $(SCRIPTS)/perl/getdeps.pl output_files/$(PROJECT).fit.rpt SDC_FILE < $(PROJECT).qsf >> Makefile.deps
	perl $(SCRIPTS)/perl/getdeps.pl version.vhd VHDL_FILE QIP_FILE < $(PROJECT).qsf >> Makefile.deps

include Makefile.deps
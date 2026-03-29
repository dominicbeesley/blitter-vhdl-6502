#!/usr/bin/env bash

set -o pipefail
set -e

# make a release zip
# expects built items in following locations

BUILDDIR=./release

CODE65=../../blitter-65xx-code

HOSTFS=~/hostfs
SSD65DIR=${CODE65}/build/ssds

SSDS_65="roms65 tools65 demo65 adventure bigfonts examblit paula"
SSDS="z80 bas816 roms69"

PREBOOT=${CODE65}/build/roms/preboot

##ROMS65_SRC=${HOSTFS}/roms65
##ROMS65_ITEMS="ADFSH30.inf MOS120.M.inf BLMMFS.rom.inf BLTUTIL.inf OSTEST.M.inf basic2.rom.inf BASIC432.rom.inf SWMMFS.rom.inf"

##TOOLS65_SRC=${HOSTFS}/tools65
##TOOLS65_ITEMS="CLOCKDP.inf CLOCKSP.inf FLSHTST.inf I2CDUMP.inf JIMTEST.inf MEMSZ.inf"

##DEMO65_SRC=${HOSTFS}/demo65
##DEMO65_ITEMS="BACK.S.inf FONT.D.inf FONT.M.inf FONT.S.inf HDPAL.inf MENU.inf MODPLAY.inf TEST.inf TEST0.inf TEST1.inf TEST2.inf TEST3.inf TEST4.inf TEST5.inf _21BOOT.inf"
##DEMO65_OPT4=3

##ADVENT65_SRC=${HOSTFS}/advent65
##ADVENT65_ITEMS="CHARAC.T.inf CLIB.R.inf GAME.inf HOME.M.inf LOADER.inf MAIN.P.inf OBACK.T.inf OCOLL.T.inf OFRONT.T.inf OVER.M.inf WANDER.inf _21BOOT.inf"
##ADVENT65_OPT4=3

##BIGFONTS_SRC=${HOSTFS}/bigfonts
##BIGFONTS_ITEMS="CLIB.R.inf DEMO.inf FONT.T.inf LOADER.inf MAIN.P.inf OWL.T.inf _21BOOT.inf"
##BIGFONTS_OPT4=3

ROMS69_SRC=${HOSTFS}/roms69
ROMS69_ITEMS="BAS6309.R.inf BAS6368.R.inf BASIC.R.inf HOSTFS.R.inf HOSTFSM.R.inf MOS6309.M.inf MOS630N.M.inf MOS6809.M.inf UTILS09.R.inf"

#MODPLAY_SRC=${HOSTFS}/paula_demo
#MODPLAY_ITEMS="8BBAFOX.M.inf JAERP2K.M.inf MENU65.inf MODMENU.inf MODPLAY.inf ROOTYTO.M.inf THEFROG.M.inf WOUTERV.M.inf _21BOOT.inf"
#MODPLAY_OPT4=3

Z80_SRC=${HOSTFS}/testz80
Z80_ITEMS="FIRSTL.M.inf TEST.M.inf _21BOOT.inf _21FIRST.inf"

BAS816_SRC=${HOSTFS}/bas816_blit
BAS816_ITEMS="BAS816.inf CLOCKSP.inf RUNB816.inf _21BOOT.inf"
BAS816_OPT4=3

if [[ -d "${BUILDDIR}" ]]; then
	echo "Clear ${BUILDDIR}"
	rm -R ${BUILDDIR}
fi

mkdir -p "${BUILDDIR}"
mkdir -p "${BUILDDIR}/ssd"
mkdir -p "${BUILDDIR}/fpga"
mkdir -p "${BUILDDIR}/preboot"




for ssd in ${SSDS}; do
	echo "SSD: ${ssd}"
	_SSD=${BUILDDIR}/ssd/${ssd}.ssd
	_U=$(echo ${ssd} | tr '[:lower:]' '[:upper:]')
	_SRC_X=${_U}_SRC
	_SRC=${!_SRC_X}
	_ITEMS_X=${_U}_ITEMS
	_ITEMS=${!_ITEMS_X}
	_TITLE=${_U}
	_OPT4_X=${_U}_OPT4
	_OPT4=${!_OPT4_X}
	dfs form -80 ${_SSD}
	dfs title ${_SSD} "${_TITLE}"
	echo title:${_TITLE}
	if [ ! -z ${_OPT4} ]; then
		echo opt4,${_OPT4}
		dfs opt4 -${_OPT4} ${_SSD}
	fi
	for r in ${_ITEMS}; do
		echo " - ${r}"
		if [[ ! -e "${_SRC}/${r}" ]]; then
			echo "Missing file ${_SRC}/${r}" 1>&2;
		fi
		dfs add ${_SSD} ${_SRC}/${r}
	done;
done

for ssd in ${SSDS_65}; do

	cp ${SSD65DIR}/${ssd}.ssd ${BUILDDIR}/ssd/${ssd}.ssd

done;

for ssd in ${SSDS} ${SSDS_65}; do
	echo "SSD: ${ssd}"
	_SSD=${BUILDDIR}/ssd/${ssd}.ssd
	dfs info ${_SSD}
done;

cp release-files.md ${BUILDDIR}
cp ../src/hdl/mk2/boards/mk2/output_files/mk2blit.jic ${BUILDDIR}/fpga
cp ../src/hdl/mk3/boards/cpu-16-max/output_files/mk3_16_max.pof ${BUILDDIR}/fpga
cp ../src/hdl/modelC20K/boards/C20K/impl/pnr/C20K.fs ${BUILDDIR}/fpga
cp ../src/hdl/modelC20K/boards/C20K816only/impl/pnr/C20K816only.fs ${BUILDDIR}/fpga
cp ../src/hdl/modelC20K/boards/C20KFirstLight/impl/pnr/C20KFirstMON.fs ${BUILDDIR}/fpga
cp ../src/hdl/modelC20K/boards/C20KFirstLight/impl/pnr/C20KFirstNoICE.fs ${BUILDDIR}/fpga

chmod a+w ${BUILDDIR}/fpga/C20K.fs
chmod a+w ${BUILDDIR}/fpga/C20K816only.fs
chmod a+w ${BUILDDIR}/fpga/C20KFirstMON.fs
chmod a+w ${BUILDDIR}/fpga/C20KFirstNoICE.fs

cp ${PREBOOT}/romset-c20k.bin ${BUILDDIR}/preboot
cp ${PREBOOT}/preboot2/c20k/preboot2.bin ${BUILDDIR}/preboot/preboot2-c20k.bin
cp ${PREBOOT}/preboot-mk2.jic ${BUILDDIR}/preboot

tar -cvzf release-$(date +%Y-%m-%d).tgz ${BUILDDIR}/*

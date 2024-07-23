#!/usr/bin/env bash

# make a release zip
# expects built items in following locations

BUILDDIR=./release/ssd

mkdir -p ${BUILDDIR}

HOSTFS=~/hostfs

SSDS="roms65 tools65 demo65 advent65 bigfonts roms69 modplay z80 bas816"

ROMS65_SRC=${HOSTFS}/roms65
ROMS65_ITEMS="ADFSH30.inf MOS120.M.inf BLMMFS.rom.inf BLTUTIL.inf OSTEST.M.inf basic2.rom.inf BASIC432.rom.inf SWMMFS.rom.inf"

TOOLS65_SRC=${HOSTFS}/tools65
TOOLS65_ITEMS="CLOCKDP.inf CLOCKSP.inf FLSHTST.inf I2CDUMP.inf JIMTEST.inf MEMSZ.inf"

DEMO65_SRC=${HOSTFS}/demo65
DEMO65_ITEMS="BACK.S.inf FONT.D.inf FONT.M.inf FONT.S.inf HDPAL.inf MENU.inf MODPLAY.inf TEST.inf TEST0.inf TEST1.inf TEST2.inf TEST3.inf TEST4.inf TEST5.inf _21BOOT.inf"
DEMO65_OPT4=3

ADVENT65_SRC=${HOSTFS}/advent65
ADVENT65_ITEMS="CHARAC.T.inf CLIB.R.inf GAME.inf HOME.M.inf LOADER.inf MAIN.P.inf OBACK.T.inf OCOLL.T.inf OFRONT.T.inf OVER.M.inf WANDER.inf _21BOOT.inf"
ADVENT65_OPT4=3

BIGFONTS_SRC=${HOSTFS}/bigfonts
BIGFONTS_ITEMS="CLIB.R.inf DEMO.inf FONT.T.inf LOADER.inf MAIN.P.inf OWL.T.inf _21BOOT.inf"
BIGFONTS_OPT4=3

ROMS69_SRC=${HOSTFS}/roms69
ROMS69_ITEMS="6309BAS.bin.inf 6368BAS.bin.inf 6809BAS.bin.inf HOSTFS-myelin.bin.inf HOSTFS.bin.inf mosrom-6809.bin.inf mosrom-nat.bin.inf mosrom.bin.inf UTILS.bin.inf"

MODPLAY_SRC=${HOSTFS}/paula_demo
MODPLAY_ITEMS="8BBAFOX.M.inf JAERP2K.M.inf MENU65.inf MODMENU.inf MODPLAY.inf ROOTYTO.M.inf THEFROG.M.inf WOUTERV.M.inf _21BOOT.inf"
MODPLAY_OPT4=3

Z80_SRC=${HOSTFS}/testz80
Z80_ITEMS="FIRSTL.M.inf TEST.M.inf _21BOOT.inf _21FIRST.inf"

BAS816_SRC=${HOSTFS}/bas816_blit
BAS816_ITEMS="BAS816.inf CLOCKSP.inf RUNB816.inf _21BOOT.inf"
BAS816_OPT4=3


for ssd in ${SSDS}; do
	echo "SSD: ${ssd}"
	_SSD=${BUILDDIR}/${ssd}.ssd
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
		dfs add ${_SSD} ${_SRC}/${r}
	done;
done

for ssd in ${SSDS}; do
	echo "SSD: ${ssd}"
	_SSD=${BUILDDIR}/${ssd}.ssd
	dfs info ${_SSD}
done;

cp release-files.md ${BUILDDIR}

tar -cvzf release-$(date +%Y-%m-%d).tgz ${BUILDDIR}/*

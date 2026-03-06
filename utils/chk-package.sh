#!/bin/sh

pkg_list="\
musl,\
uclibc,\
busybox,\
alsa-utils,\
alsa-lib,\
coremark,\
ffmpeg,\
flac,\
mpd,\
ncmpc,\
libtraceevent,\
libtracefs,\
cifs-utils,\
dosfstools,\
e2fsprogs,\
exfat,\
brcmfmac_sdio-firmware-rpi,\
intel-firmware,\
linux-firmware,\
rpi-firmware,\
ethtool,\
fftw,\
fmt,\
json-for-modern-cpp,\
libid3tag,\
libmad,\
libmpdclient,\
libsamplerate,\
libsndfile,\
libsoxr,\
libzlib,\
libressl,\
libfuse3,\
libnfs,\
libcurl,\
libnl,\
libtirpc,\
libevent,\
ncurses,\
ntp,\
openssh,\
wireless-regdb,\
wpa_supplicant,\
util-linux,\
"

buildroot=~/buildroot
output=/tmp/pkg-list.html

pwd=$(pwd)
cd $buildroot
support/scripts/pkg-stats --html $output -p $pkg_list
cd $pwd

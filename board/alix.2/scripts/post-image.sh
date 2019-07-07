#!/bin/bash

set -e

BOARD_DIR="$(dirname $0)"
BOARD_NAME="$(basename $(dirname ${BOARD_DIR}))"
GENIMAGE_CFG="${BOARD_DIR}/genimage-${BOARD_NAME}.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

for arg in "$@"
do
	case "${arg}" in
		--add-config-dir)
		if [ ! -d "${BINARIES_DIR}/.config" ]; then
			echo "Creating config directory for image."
			mkdir -p ${BINARIES_DIR}/.config
		fi
		;;

		--add-syslinux-cfg)
		if [ ! -f "${BINARIES_DIR}/syslinux.cfg" ]; then
			echo "Creating syslinux.cfg file for image."
			cat << __EOF__ >> "${BINARIES_DIR}/syslinux.cfg"
SERIAL 0 38400

DEFAULT nabla
TIMEOUT 10
SAY Booting Nabla music player ... 

LABEL nabla
KERNEL /boot/bzImage
APPEND  console=ttyS0,38400n8
__EOF__
		fi
		;;
	esac

done

rm -rf "${GENIMAGE_TMP}"

genimage                           \
	--rootpath "${TARGET_DIR}"     \
	--tmppath "${GENIMAGE_TMP}"    \
	--inputpath "${BINARIES_DIR}"  \
	--outputpath "${BINARIES_DIR}" \
	--config "${GENIMAGE_CFG}"

# very ugly hack, uses syslinux from the host computer
syslinux -t 0x100000 -d boot/syslinux ${BINARIES_DIR}/sdcard.img

exit $?

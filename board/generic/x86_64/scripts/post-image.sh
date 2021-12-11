#!/bin/bash

set -e

BOARD_DIR="$(dirname $0)"
BOARD_NAME="$(basename $(dirname ${BOARD_DIR}))"
GENIMAGE_CFG="${BOARD_DIR}/genimage-${BOARD_NAME}.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
GENIMAGE_INC="${BR2_EXTERNAL_NABLA_PATH}/board/genimage.cfg"

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
DEFAULT nabla
PROMPT 0

LABEL nabla
  SAY Booting Nabla music player ...
  KERNEL /boot/bzImage
  APPEND isolcpus=1 rcu_nocbs=1 nohz_full=1 quiet
__EOF__
		fi
		;;
	esac

done

rm -rf "$GENIMAGE_TMP"

genimage \
	--rootpath "$TARGET_DIR" \
	--tmppath "$GENIMAGE_TMP" \
	--inputpath "$BINARIES_DIR" \
	--outputpath "$BINARIES_DIR" \
	--includepath "$GENIMAGE_INC:" \
	--config "$GENIMAGE_CFG"

# there is no host-syslinux, use the installation on the host machine, if present
if [ $(which syslinux) ]; then 
	syslinux -t 0x100000 -d boot/syslinux ${BINARIES_DIR}/sdcard.img
fi

exit $?

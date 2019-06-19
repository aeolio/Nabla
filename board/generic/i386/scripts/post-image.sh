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
DEFAULT nabla
PROMPT 0

LABEL nabla
  SAY Booting NABLA ...
  KERNEL /boot/bzImage
  APPEND loglevel=5 quiet
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

exit $?

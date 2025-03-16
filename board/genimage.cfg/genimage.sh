#!/bin/bash
# Common post-image script to generate a flashable image after build
# Originally derived from Buildroot Raspberry Pi post-image script
# Enhanced with x86 syslinux option
# This script needs to be (soft) linked as post-image.sh into the board directory

set -e

BOARD_DIR="$(dirname $0)"
BOARD_NAME="$(basename $(dirname ${BOARD_DIR}))"
GENIMAGE_CFG="${BOARD_DIR}/genimage-${BOARD_NAME}.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
GENIMAGE_INC="${BR2_EXTERNAL_NABLA_PATH}/board/genimage.cfg"

### bind function library
script_dir=$BR2_EXTERNAL_NABLA_PATH/scripts
[ -x "$script_dir/function_lib.sh" ] && . "$script_dir/function_lib.sh"

KERNEL_CONFIG=$(get_kernel_config)

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
		SYSLINUX=/usr/bin/syslinux
		if [ ! -f "${BINARIES_DIR}/syslinux.cfg" ]; then
			echo "Creating syslinux.cfg file for image."
			$HOST_DIR/bin/python $script_dir/syslinux.py \
				$BR2_CONFIG \
				$KERNEL_CONFIG \
				"${BINARIES_DIR}/syslinux.cfg"
		fi
		;;

		--genimage-cfg=*)
		# Use a custom genimage.cfg
		GENIMAGE_CFG=${arg#*=}
		;;
	esac

done

rm -rf "$GENIMAGE_TMP"

# Pass an empty rootpath. genimage makes a full copy of the given rootpath to
# ${GENIMAGE_TMP}/root so passing TARGET_DIR would be a waste of time and disk
# space. We don't rely on genimage to build the rootfs image, just to insert a
# pre-built one in the disk image.

trap 'rm -rf "${ROOTPATH_TMP}"' EXIT
ROOTPATH_TMP="$(mktemp -d)"

rm -rf "${GENIMAGE_TMP}"

genimage \
	--rootpath "${ROOTPATH_TMP}"   \
	--tmppath "$GENIMAGE_TMP" \
	--inputpath "$BINARIES_DIR" \
	--outputpath "$BINARIES_DIR" \
	--includepath "$GENIMAGE_INC:" \
	--config "$GENIMAGE_CFG"

# remove intermediate files
rm -fr $BINARIES_DIR/*.vfat

# there is no host-syslinux; use the installation on the host machine, if present
if [ -x "$SYSLINUX" ]; then 
	$SYSLINUX -t 0x100000 -d boot/syslinux ${BINARIES_DIR}/sdcard.img
fi

exit $?

